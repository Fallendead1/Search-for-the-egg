--[[
	Handles Gameplay_RequestBuyRunUpgrade for Hand (Hold/Speed/Grasp) and Bag
	level purchases. Pitchfork/Dynamite/Vacuum/Drone upgrades go through
	ToolService via Gameplay_RequestToolAction instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local HandConfig = require(GameplayConfig.HandConfig)
local BagConfig = require(GameplayConfig.BagConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)

local RunUpgradeService = {}

local function buyHandHold(player: Player, state: any)
	if state.HandHoldUnlocked then
		return false, "AlreadyOwned"
	end
	if not RunPlayerStateService.TrySpendCash(state, HandConfig.HOLD_UNLOCK_COST_CENTS) then
		return false, "InsufficientCash"
	end
	state.HandHoldUnlocked = true
	return true
end

local function buyHandSpeed(player: Player, state: any)
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

local function buyHandGrasp(player: Player, state: any)
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

local function buyBagLevel(player: Player, state: any)
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

local HANDLERS = {
	Hand = {
		Hold = buyHandHold,
		Speed = buyHandSpeed,
		Grasp = buyHandGrasp,
	},
	Bag = {
		Level = buyBagLevel,
	},
}

function RunUpgradeService.RequestBuy(player: Player, category: string, track: string)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		return false, "NoRunState"
	end

	local categoryHandlers = HANDLERS[category]
	local handler = categoryHandlers and categoryHandlers[track]
	if not handler then
		return false, "InvalidUpgrade"
	end

	local ok, err = handler(player, state)
	if ok then
		RoundService.BroadcastPlayerState(player)
	end
	return ok, err
end

function RunUpgradeService.Init()
	local remote = RemotesLocator.Get("Gameplay_RequestBuyRunUpgrade")
	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.Category) ~= "string" or type(payload.Track) ~= "string" then
			return
		end
		RunUpgradeService.RequestBuy(player, payload.Category, payload.Track)
	end)
end

return RunUpgradeService
