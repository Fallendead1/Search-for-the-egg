--[[
	Owns the per-player ephemeral run state: Cash, Bag, Hand levels, tool
	ownership/levels, and modifier snapshots. Reset every run. Persistent data
	(Gems, Alien Tokens, Wins, entitlements) always lives in Core; this module
	only ever reads it once at run start via CoreLocator.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local RunConfig = require(GameplayConfig.RunConfig)
local HandConfig = require(GameplayConfig.HandConfig)
local BagConfig = require(GameplayConfig.BagConfig)

local CoreLocator = require(script.Parent.CoreLocator)

local RunPlayerStateService = {}

local states: { [number]: any } = {}

local TOOL_NAMES = { "Pitchfork", "Dynamite", "Vacuum", "Drone", "FeatherGrabber", "TornadoLauncher", "PackingBot" }

local function freshToolState(): any
	return {
		Ownership = "Locked",
		AmountLevel = 0, -- Pitchfork/Dynamite power, Vacuum power, Drone grasp
		SpeedLevel = 0,
		ExtraLevel = 0, -- Pitchfork dig depth / Dynamite lucky blast / Vacuum runtime / Drone capacity
	}
end

function RunPlayerStateService.InitPlayer(player: Player, difficultyId: string)
	local metaProgression = CoreLocator.GetMetaProgressionService()
	local monetization = CoreLocator.GetMonetizationService()
	local modifiers = metaProgression.GetGameplayModifiers(player) or {}

	local state = {
		UserId = player.UserId,
		Difficulty = difficultyId,
		CashCents = 0,
		BagLevel = 0,
		BagCount = 0,
		RainbowInBag = 0,
		HandHoldUnlocked = false,
		HandSpeedLevel = 0,
		HandGraspLevel = 0,
		CarryingEgg = false,
		Modifiers = modifiers,
		Tools = {},
		LastCollectAt = {}, -- [toolName] = os.clock()
		FeathersCollected = 0,
		DiamondFinds = 0,
		AlienTokenFinds = 0,
	}

	for _, toolName in ipairs(TOOL_NAMES) do
		state.Tools[toolName] = freshToolState()

		local entitlementKey = RunConfig.ENTITLEMENTS[toolName .. "Permanent"]
		local ok, owned = pcall(function()
			return entitlementKey and monetization.OwnsEntitlement(player, entitlementKey)
		end)
		if ok and owned then
			state.Tools[toolName].Ownership = "PermanentOwned"
		end
	end

	-- Class modifier: Drone Specialist always owns a Drone.
	if modifiers.DroneAlwaysOwned and state.Tools.Drone.Ownership == "Locked" then
		state.Tools.Drone.Ownership = "RunOwned"
	end

	states[player.UserId] = state
	return state
end

function RunPlayerStateService.Get(player: Player)
	return states[player.UserId]
end

function RunPlayerStateService.GetByUserId(userId: number)
	return states[userId]
end

function RunPlayerStateService.Remove(player: Player)
	states[player.UserId] = nil
end

function RunPlayerStateService.EffectiveBagCapacity(state: any): number
	local modifiers = state.Modifiers or {}
	if modifiers.InfiniteBag then
		return math.huge
	end

	local level = BagConfig.LEVELS[state.BagLevel] or BagConfig.LEVELS[0]
	local capacity = level.Capacity + (modifiers.BagFlatBonus or 0)
	if modifiers.PackMule then
		capacity = math.floor(capacity * BagConfig.PACK_MULE_CAPACITY_MULTIPLIER)
	end
	return capacity
end

function RunPlayerStateService.EffectiveHandAmount(state: any): number
	local level = HandConfig.GRASP_LEVELS[state.HandGraspLevel] or HandConfig.GRASP_LEVELS[0]
	local modifiers = state.Modifiers or {}
	return level.Amount + (modifiers.HandGraspFlatBonus or 0)
end

function RunPlayerStateService.EffectiveHandInterval(state: any): number
	local level = HandConfig.SPEED_LEVELS[state.HandSpeedLevel] or HandConfig.SPEED_LEVELS[0]
	return level.IntervalSeconds
end

function RunPlayerStateService.AddCash(state: any, cents: number)
	state.CashCents += cents
end

function RunPlayerStateService.TrySpendCash(state: any, cents: number): boolean
	if state.CashCents < cents then
		return false
	end
	state.CashCents -= cents
	return true
end

-- Adds feathers to the bag, respecting capacity. Returns the amount actually
-- added (normal + rainbow may be partially rejected if the bag fills mid-add).
function RunPlayerStateService.AddToBag(state: any, normalCount: number, rainbowCount: number): (number, number)
	local capacity = RunPlayerStateService.EffectiveBagCapacity(state)
	local spaceLeft = capacity - state.BagCount
	if spaceLeft <= 0 then
		return 0, 0
	end

	local totalRequested = normalCount + rainbowCount
	local totalToAdd = math.min(totalRequested, spaceLeft)

	-- Prioritize rainbow feathers into the bag first (higher value shouldn't
	-- be the thing that overflows and gets lost).
	local rainbowAdded = math.min(rainbowCount, totalToAdd)
	local normalAdded = totalToAdd - rainbowAdded

	state.BagCount += totalToAdd
	state.RainbowInBag += rainbowAdded

	return normalAdded, rainbowAdded
end

-- Atomically empties the bag, returning what was collected for sale.
function RunPlayerStateService.ClearBag(state: any): (number, number)
	local rainbow = state.RainbowInBag
	local normal = state.BagCount - rainbow
	state.BagCount = 0
	state.RainbowInBag = 0
	return normal, rainbow
end

-- Canonical Gameplay_RunState "PlayerState" field set -- see RoundService
-- header for the full documented Gameplay_RunState contract. HandSpeed here
-- is the actual collection interval in seconds (what InputController's
-- client-side cadence gate reads), not a level index.
function RunPlayerStateService.SerializeForClient(state: any)
	return {
		CashCents = state.CashCents,
		BagCount = state.BagCount,
		BagCapacity = RunPlayerStateService.EffectiveBagCapacity(state),
		BagLevel = state.BagLevel,
		RainbowInBag = state.RainbowInBag,
		HandHoldUnlocked = state.HandHoldUnlocked,
		HandSpeed = RunPlayerStateService.EffectiveHandInterval(state),
		HandGrasp = RunPlayerStateService.EffectiveHandAmount(state),
		HandSpeedLevel = state.HandSpeedLevel,
		HandGraspLevel = state.HandGraspLevel,
		CarryingEgg = state.CarryingEgg,
		Tools = state.Tools,
	}
end

function RunPlayerStateService.ResetAll()
	for userId in pairs(states) do
		states[userId] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	RunPlayerStateService.Remove(player)
end)

return RunPlayerStateService
