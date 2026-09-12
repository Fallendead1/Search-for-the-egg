--[[
	Gameplay_RequestBuyRunUpgrade is the ONE entry point for every CASH-based
	run upgrade/unlock purchase: Hand, Bag, Pitchfork, Dynamite, Vacuum,
	Drone. Gameplay_RequestToolAction (ToolService) is reserved for tool
	USE/action requests (Throw, Toggle, the Drone Gems one-round buy) --
	never for Cash purchasing. This keeps exactly one purchase pathway the
	client needs to know about for every Cash-cost upgrade/unlock.

	Payload: { Group = "Hand"|"Bag"|"Pitchfork"|"Dynamite"|"Vacuum"|"Drone",
	           UpgradeId = string }
		Hand:      Hold | Speed | Grasp
		Bag:       Upgrade
		Pitchfork: Unlock | Sweep | Speed | Dig
		Dynamite:  Unlock | Power | Speed | LuckyBlast
		Vacuum:    Power | Cooling | Runtime
		Drone:     Speed | Grasp | Capacity
	(Vacuum/Drone have no Cash "Unlock" -- they're acquired via Robux/Gems
	products handled entirely by MonetizationService/ToolService.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local HandConfig = require(GameplayConfig.HandConfig)
local BagConfig = require(GameplayConfig.BagConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local ToolService = require(script.Parent.ToolService)

local RunUpgradeService = {}

-- Every reason any handler below (or ToolService.BuyUnlock/BuyUpgrade, which
-- this delegates to) can return. A player who taps a purchase button and
-- gets nothing back has no way to tell a rejected buy from a dropped remote
-- -- always surface why.
local FAILURE_MESSAGES: { [string]: string } = {
	InsufficientCash = "Not enough Cash for that.",
	MaxLevel = "Already at max level.",
	AlreadyOwned = "Already unlocked.",
	InvalidUpgrade = "That upgrade isn't available.",
	InvalidTrack = "That upgrade isn't available.",
	NoCashUnlockForTool = "That tool can't be unlocked with Cash.",
	ToolNotOwned = "Unlock this tool first.",
	RoundNotActive = "Start a run first.",
	NoRunState = "Start a run first.",
}

-- ---- Hand (no ownership gate -- base tool) ----

local function buyHandHold(_player: Player, state: any)
	if state.HandHoldUnlocked then
		return false, "AlreadyOwned"
	end
	if not RunPlayerStateService.TrySpendCash(state, HandConfig.HOLD_UNLOCK_COST_CENTS) then
		return false, "InsufficientCash"
	end
	state.HandHoldUnlocked = true
	return true
end

local function buyHandSpeed(_player: Player, state: any)
	local nextLevel = state.HandSpeedLevel + 1
	if nextLevel > HandConfig.MAX_LEVEL then
		return false, "MaxLevel"
	end
	local cost = HandConfig.SPEED_LEVELS[nextLevel].CostCents
	if not RunPlayerStateService.TrySpendCash(state, cost) then
		return false, "InsufficientCash"
	end
	state.HandSpeedLevel = nextLevel
	return true
end

local function buyHandGrasp(_player: Player, state: any)
	local nextLevel = state.HandGraspLevel + 1
	if nextLevel > HandConfig.MAX_LEVEL then
		return false, "MaxLevel"
	end
	local cost = HandConfig.GRASP_LEVELS[nextLevel].CostCents
	if not RunPlayerStateService.TrySpendCash(state, cost) then
		return false, "InsufficientCash"
	end
	state.HandGraspLevel = nextLevel
	return true
end

-- ---- Bag (no ownership gate -- base tool) ----

local function buyBagLevel(_player: Player, state: any)
	local nextLevel = state.BagLevel + 1
	if nextLevel > BagConfig.MAX_LEVEL then
		return false, "MaxLevel"
	end
	local cost = BagConfig.LEVELS[nextLevel].CostCents
	if not RunPlayerStateService.TrySpendCash(state, cost) then
		return false, "InsufficientCash"
	end
	state.BagLevel = nextLevel
	return true
end

-- Handlers that own their own RunPlayerStateService mutation and don't
-- require existing tool ownership. Return (ok, reason?); RunUpgradeService
-- broadcasts player state itself on success.
local SIMPLE_HANDLERS = {
	Hand = { Hold = buyHandHold, Speed = buyHandSpeed, Grasp = buyHandGrasp },
	Bag = { Upgrade = buyBagLevel },
}

-- ---- Pitchfork / Dynamite / Vacuum / Drone: Cash unlock + leveled tracks.
-- These delegate to ToolService, which owns tool ownership/level state and
-- already broadcasts player state on success -- RunUpgradeService does not
-- broadcast again for this branch.

local CASH_UNLOCK_TOOLS = {
	Pitchfork = true,
	Dynamite = true,
	FeatherGrabber = true,
	TornadoLauncher = true,
}

local TOOL_UPGRADE_ID_TO_TRACK = {
	Pitchfork = { Sweep = "Amount", Speed = "Speed", Dig = "Extra" },
	Dynamite = { Power = "Amount", Speed = "Speed", LuckyBlast = "Extra" },
	Vacuum = { Power = "Amount", Cooling = "Speed", Runtime = "Extra" },
	Drone = { Speed = "Speed", Grasp = "Amount", Capacity = "Extra" },
}

function RunUpgradeService.RequestBuy(player: Player, group: string, upgradeId: string): (boolean, string?)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		return false, "NoRunState"
	end

	local ok, err = RunUpgradeService.tryBuy(player, state, group, upgradeId)
	if not ok and err then
		RoundService.SendNotification(player, FAILURE_MESSAGES[err] or "Purchase failed.", "Error")
	end
	return ok, err
end

function RunUpgradeService.tryBuy(player: Player, state: any, group: string, upgradeId: string): (boolean, string?)
	local simpleHandlers = SIMPLE_HANDLERS[group]
	local simpleHandler = simpleHandlers and simpleHandlers[upgradeId]
	if simpleHandler then
		local ok, err = simpleHandler(player, state)
		if ok then
			RoundService.BroadcastPlayerState(player)
		end
		return ok, err
	end

	if upgradeId == "Unlock" and CASH_UNLOCK_TOOLS[group] then
		return ToolService.BuyUnlock(player, group)
	end

	local trackMap = TOOL_UPGRADE_ID_TO_TRACK[group]
	local trackName = trackMap and trackMap[upgradeId]
	if trackName then
		return ToolService.BuyUpgrade(player, group, trackName)
	end

	return false, "InvalidUpgrade"
end

function RunUpgradeService.Init()
	local remote = RemotesLocator.Get("Gameplay_RequestBuyRunUpgrade")
	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.Group) ~= "string" or type(payload.UpgradeId) ~= "string" then
			return
		end
		RunUpgradeService.RequestBuy(player, payload.Group, payload.UpgradeId)
	end)
end

return RunUpgradeService
