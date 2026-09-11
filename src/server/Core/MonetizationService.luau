--[[
	Gamepass/developer product processing, receipt handling, and entitlement
	storage. Real Roblox asset IDs are not yet known (see MonetizationConfig)
	so ProcessReceipt will not grant anything meaningful until they are
	filled in -- but the idempotency/validation machinery is fully wired.

	For "RunProduct" kind products (one-round grants), the Gameplay agent
	registers a callback via RegisterRunProductGrant; this service never
	grants a run effect itself.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.MonetizationConfig)
local RemoteNames = require(ReplicatedStorage.SearchForTheEgg.Net.RemoteNames)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local RemoteBootstrap = require(script.Parent.RemoteBootstrap)

local MonetizationService = {}

local runProductCallbacks = {} :: { [string]: (Player) -> () }

local productsById = {}
for key, product in MonetizationConfig.DeveloperProducts do
	if product.Id and product.Id ~= 0 then
		productsById[product.Id] = { Key = key, Config = product }
	end
end

-- Reverse lookup: EntitlementKey -> Game Pass Id. Every entry in
-- MonetizationConfig.GamePasses grants its entitlement purely through live
-- ownership (see OwnsEntitlement below) -- Game Passes are never receipted,
-- so there is no ProcessReceipt path that could ever grant these.
local passIdByEntitlementKey: { [string]: number } = {}
for _, pass in MonetizationConfig.GamePasses do
	if pass.EntitlementKey and pass.Id and pass.Id ~= 0 then
		passIdByEntitlementKey[pass.EntitlementKey] = pass.Id
	end
end

local passOwnershipCache = {} :: { [Player]: { [number]: { owns: boolean, checkedAt: number } } }
local PASS_CACHE_TTL_SECONDS = 300

function MonetizationService.RegisterRunProductGrant(productKey: string, callback: (Player) -> ())
	runProductCallbacks[productKey] = callback
end

local function grantEntitlement(player: Player, entitlementKey: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	profile.Entitlements[entitlementKey] = true
	if entitlementKey == "ExtraClassSlot" then
		local ClassService = require(script.Parent.ClassService)
		ClassService.UnlockSlot2(player)
	end
	return true
end

-- Server-authoritative entitlement check. Every current entitlement is
-- backed by a Game Pass (see MonetizationConfig.GamePasses), so this
-- resolves live ownership via Marketplace (cached by OwnsGamePass) and
-- caches the result on the profile so the client-visible
-- EntitlementSummary (Core_ProfileUpdated) stays in sync without an extra
-- Marketplace round trip on every check. The stored-flag fast path also
-- keeps this correct for any future receipt-granted entitlement.
function MonetizationService.OwnsEntitlement(player: Player, entitlementKey: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	if profile.Entitlements[entitlementKey] == true then
		return true
	end

	local passId = passIdByEntitlementKey[entitlementKey]
	if not passId then
		return false
	end

	if MonetizationService.OwnsGamePass(player, passId) then
		grantEntitlement(player, entitlementKey)
		return true
	end
	return false
end

-- Proactively resolves every Game-Pass-backed entitlement once per profile
-- load, so a returning owner's perks (permanent tools, 2x Gems, Slot 2,
-- etc.) apply immediately instead of waiting on whatever gameplay code
-- happens to call OwnsEntitlement first.
function MonetizationService.SyncGamePassEntitlements(player: Player)
	local changed = false
	for _, pass in MonetizationConfig.GamePasses do
		if pass.EntitlementKey and pass.Id and pass.Id ~= 0 then
			if MonetizationService.OwnsEntitlement(player, pass.EntitlementKey) then
				changed = true
			end
		end
	end
	if changed then
		DataService.PushProfileUpdated(player)
	end
end

-- Checks (and caches) game pass ownership. Returns cached/false on lookup
-- failure rather than yielding indefinitely or erroring the caller.
function MonetizationService.OwnsGamePass(player: Player, passId: number): boolean
	local cache = passOwnershipCache[player]
	if not cache then
		cache = {}
		passOwnershipCache[player] = cache
	end

	local entry = cache[passId]
	local now = os.clock()
	if entry and (now - entry.checkedAt) < PASS_CACHE_TTL_SECONDS then
		return entry.owns
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)

	if not ok then
		return (entry and entry.owns) or false
	end

	cache[passId] = { owns = owns, checkedAt = now }
	return owns
end

local function isReceiptProcessed(profile, purchaseId: string): boolean
	return profile.Receipts.Processed[purchaseId] == true
end

local function markReceiptProcessed(profile, purchaseId: string)
	profile.Receipts.Processed[purchaseId] = true
end

local function processProduct(player: Player, key: string, config, purchaseId: string)
	if config.Kind == "Gems" then
		CurrencyService.Award(player, "Gems", config.Amount, "Purchase:" .. key, CurrencyService.Source.Purchased)
	elseif config.Kind == "Entitlement" then
		-- No current Developer Product uses this Kind -- every permanent
		-- unlock in the approved catalog is a Game Pass, resolved live via
		-- OwnsEntitlement instead of a receipt. Kept for any future
		-- receipt-granted entitlement product.
		grantEntitlement(player, config.EntitlementKey)
	elseif config.Kind == "RunProduct" then
		local callback = runProductCallbacks[config.ProductKey]
		if callback then
			task.spawn(callback, player)
		else
			warn(("MonetizationService: no run product callback registered for %s"):format(config.ProductKey))
		end
	elseif config.Kind == "ChestMultiOpen" then
		local ChestService = require(script.Parent.ChestService)
		local ok, result = ChestService.OpenPaidBatch(player, config.ChestCount)
		if ok then
			-- Push the awarded rewards back to the owning client so the
			-- existing Alien Chest reveal UI (Core_AlienChestResult) shows
			-- them, same as a Token-funded open -- the client never chooses
			-- or predicts these; ChestService already rolled them
			-- server-side before this point.
			local remote = RemoteBootstrap.Get(RemoteNames.Core_AlienChestResult)
			if remote then
				remote:FireClient(player, { Success = true, Rewards = result.Rewards })
			end
		else
			warn(("MonetizationService: OpenPaidBatch failed for %s: %s"):format(key, tostring(result)))
		end
	else
		warn(("MonetizationService: unknown product kind %s for %s"):format(tostring(config.Kind), key))
	end
end

function MonetizationService.ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not DataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.GetProfile(player)

	if isReceiptProcessed(profile, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local entry = productsById[receiptInfo.ProductId]
	if not entry then
		-- Unknown ProductId (e.g. not yet wired into MonetizationConfig):
		-- log and safely acknowledge so Roblox stops retrying this receipt.
		warn(("MonetizationService: received receipt for unknown ProductId %d"):format(receiptInfo.ProductId))
		markReceiptProcessed(profile, receiptInfo.PurchaseId)
		DataService.PushProfileUpdated(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok = pcall(processProduct, player, entry.Key, entry.Config, receiptInfo.PurchaseId)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	markReceiptProcessed(profile, receiptInfo.PurchaseId)
	DataService.PushProfileUpdated(player)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(MonetizationService.SyncGamePassEntitlements, player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	passOwnershipCache[player] = nil
end)

return MonetizationService
