--[[
	Locates Agent 1's (core-server) persistence/economy services.

	ASSUMPTION (undocumented at time of writing — core-server had not landed
	any code yet): Core services are ModuleScripts under
	ServerScriptService.SearchForTheEgg.Core.<ServiceName>, returning a table
	with the methods listed in the shared architecture contract. If Core lands
	them at a different path, update CORE_CONTAINER_PATH below (single choke
	point) or drop the modules directly at that path.

	Until Core exists, every method falls back to an in-memory mock so
	Gameplay systems remain independently testable in Studio. Mocks log a
	single warning per service the first time they're used.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CoreLocator = {}

local CORE_CONTAINER_PATH = { "SearchForTheEgg", "Core" }

local warnedServices = {}
local function warnOnce(serviceName: string)
	if warnedServices[serviceName] then
		return
	end
	warnedServices[serviceName] = true
	warn(("[Gameplay] Core service '%s' not found; using mock fallback."):format(serviceName))
end

local function findCoreContainer(): Instance?
	local node: Instance = ServerScriptService
	for _, name in ipairs(CORE_CONTAINER_PATH) do
		local child = node:FindFirstChild(name)
		if not child then
			return nil
		end
		node = child
	end
	return node
end

local function tryRequireService(serviceName: string): any?
	local container = findCoreContainer()
	if not container then
		return nil
	end
	local moduleScript = container:FindFirstChild(serviceName)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn(("[Gameplay] Failed to require Core service '%s': %s"):format(serviceName, tostring(result)))
		return nil
	end
	return result
end

-- Mock currency ledger keyed by [player][currencyName] = amount.
local mockCurrency = setmetatable({}, { __mode = "k" })
local function getMockPlayerLedger(player: Player)
	local ledger = mockCurrency[player]
	if not ledger then
		ledger = {}
		mockCurrency[player] = ledger
	end
	return ledger
end

local MockCurrencyService = {
	Get = function(_self, player, currencyName)
		return getMockPlayerLedger(player)[currencyName] or 0
	end,
	CanAfford = function(_self, player, currencyName, amount)
		return (getMockPlayerLedger(player)[currencyName] or 0) >= amount
	end,
	TrySpend = function(_self, player, currencyName, amount, _reason)
		local ledger = getMockPlayerLedger(player)
		local current = ledger[currencyName] or 0
		if current < amount then
			return false
		end
		ledger[currencyName] = current - amount
		return true
	end,
	Award = function(_self, player, currencyName, amount, _reason)
		local ledger = getMockPlayerLedger(player)
		ledger[currencyName] = (ledger[currencyName] or 0) + amount
		return true
	end,
}

local MockMetaProgressionService = {
	GetGameplayModifiers = function(_self, _player)
		return {
			SaleMultiplier = 1,
			FeatherValueMultiplier = 1,
			HandGraspFlatBonus = 0,
			BagFlatBonus = 0,
			PackMule = false,
			InfiniteBag = false,
			Forkmaster = false,
			Demolitionist = false,
			DroneSpecialist = false,
			Prospector = false,
			UltimateFarmer = false,
			DroneAlwaysOwned = false,
			Wins = 0,
		}
	end,
	AwardRunCompletion = function(_self, _player, result)
		return {
			Gems = result.Gems or 0,
			AlienTokens = result.AlienTokens or 0,
			Wins = result.Wins or 0,
		}
	end,
	GetWins = function(_self, _player)
		return 0
	end,
}

local MockInventoryService = {
	GetSelectedSkin = function(_self, _player, _category)
		return "Default"
	end,
}

local mockEntitlements = setmetatable({}, { __mode = "k" })
local mockRunProductGrants = {}

local MockMonetizationService = {
	OwnsEntitlement = function(_self, player, entitlementKey)
		local set = mockEntitlements[player]
		return set ~= nil and set[entitlementKey] == true
	end,
	RegisterRunProductGrant = function(_self, productKey, callback)
		mockRunProductGrants[productKey] = callback
	end,
}

local services = {}

function CoreLocator.GetCurrencyService()
	if not services.Currency then
		services.Currency = tryRequireService("CurrencyService")
		if not services.Currency then
			warnOnce("CurrencyService")
			services.Currency = MockCurrencyService
		end
	end
	return services.Currency
end

function CoreLocator.GetMetaProgressionService()
	if not services.MetaProgression then
		services.MetaProgression = tryRequireService("MetaProgressionService")
		if not services.MetaProgression then
			warnOnce("MetaProgressionService")
			services.MetaProgression = MockMetaProgressionService
		end
	end
	return services.MetaProgression
end

function CoreLocator.GetInventoryService()
	if not services.Inventory then
		services.Inventory = tryRequireService("InventoryService")
		if not services.Inventory then
			warnOnce("InventoryService")
			services.Inventory = MockInventoryService
		end
	end
	return services.Inventory
end

function CoreLocator.GetMonetizationService()
	if not services.Monetization then
		services.Monetization = tryRequireService("MonetizationService")
		if not services.Monetization then
			warnOnce("MonetizationService")
			services.Monetization = MockMonetizationService
		end
	end
	return services.Monetization
end

-- Best-effort Wins lookup: the contract doesn't list an explicit accessor, so
-- try a couple of plausible shapes before falling back to modifiers/0.
function CoreLocator.GetWins(player: Player): number
	local meta = CoreLocator.GetMetaProgressionService()
	if meta.GetWins then
		local ok, wins = pcall(function()
			return meta:GetWins(player)
		end)
		if ok and type(wins) == "number" then
			return wins
		end
	end
	local modifiers = meta:GetGameplayModifiers(player)
	if type(modifiers) == "table" and type(modifiers.Wins) == "number" then
		return modifiers.Wins
	end
	return 0
end

return CoreLocator
