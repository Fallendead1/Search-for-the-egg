--[[
	Central tool ownership + leveled-upgrade state for Pitchfork, Dynamite,
	Vacuum, and Drone. BuyUnlock/BuyUpgrade below are the mutation primitives;
	RunUpgradeService is the only caller reached from the network (via
	Gameplay_RequestBuyRunUpgrade -- see its header for the full Cash-upgrade
	contract), keeping exactly one purchase pathway for the client.

	Gameplay_RequestToolAction (handled here) is reserved for tool USE/action
	requests -- never purchasing: BuyDroneGems (the Drone's Gems, not Cash,
	one-round buy) is handled directly; tool-specific actions (Throw, Toggle)
	are dispatched to handlers that DynamiteService/VacuumService/DroneService
	register via RegisterActionHandler, so this module never has to require
	those leaf services back.

	One-round paid products are registered with Core's
	MonetizationService:RegisterRunProductGrant here; the receipt/backend flow
	itself remains owned by Agent 1.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local RunConfig = require(GameplayConfig.RunConfig)
local PitchforkConfig = require(GameplayConfig.PitchforkConfig)
local DynamiteConfig = require(GameplayConfig.DynamiteConfig)
local VacuumConfig = require(GameplayConfig.VacuumConfig)
local DroneConfig = require(GameplayConfig.DroneConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local CoreLocator = require(script.Parent.CoreLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)

local ToolService = {}

-- Maps state.Tools[toolName].{AmountLevel,SpeedLevel,ExtraLevel} to a config
-- level table, per tool.
local TOOL_TRACKS = {
	Pitchfork = {
		Amount = { Field = "AmountLevel", Levels = PitchforkConfig.AMOUNT_LEVELS, MaxLevel = PitchforkConfig.MAX_LEVEL },
		Speed = { Field = "SpeedLevel", Levels = PitchforkConfig.SPEED_LEVELS, MaxLevel = PitchforkConfig.MAX_LEVEL },
		Extra = { Field = "ExtraLevel", Levels = PitchforkConfig.DIG_DEPTH_LEVELS, MaxLevel = PitchforkConfig.MAX_LEVEL },
	},
	Dynamite = {
		Amount = { Field = "AmountLevel", Levels = DynamiteConfig.POWER_LEVELS, MaxLevel = DynamiteConfig.MAX_LEVEL },
		Speed = { Field = "SpeedLevel", Levels = DynamiteConfig.SPEED_LEVELS, MaxLevel = DynamiteConfig.MAX_LEVEL },
		Extra = { Field = "ExtraLevel", Levels = DynamiteConfig.LUCKY_BLAST_LEVELS, MaxLevel = DynamiteConfig.MAX_LEVEL },
	},
	Vacuum = {
		Amount = { Field = "AmountLevel", Levels = VacuumConfig.POWER_LEVELS, MaxLevel = VacuumConfig.MAX_LEVEL },
		Speed = { Field = "SpeedLevel", Levels = VacuumConfig.COOLING_LEVELS, MaxLevel = VacuumConfig.MAX_LEVEL },
		Extra = { Field = "ExtraLevel", Levels = VacuumConfig.RUNTIME_LEVELS, MaxLevel = VacuumConfig.MAX_LEVEL },
	},
	Drone = {
		Amount = { Field = "AmountLevel", Levels = DroneConfig.GRASP_LEVELS, MaxLevel = DroneConfig.MAX_LEVEL },
		Speed = { Field = "SpeedLevel", Levels = DroneConfig.SPEED_LEVELS, MaxLevel = DroneConfig.MAX_LEVEL },
		Extra = { Field = "ExtraLevel", Levels = DroneConfig.CAPACITY_LEVELS, MaxLevel = DroneConfig.MAX_LEVEL },
	},
}

local actionHandlers: { [string]: { [string]: (player: Player, payload: any) -> () } } = {}

function ToolService.RegisterActionHandler(toolName: string, actionName: string, handler: (player: Player, payload: any) -> ())
	actionHandlers[toolName] = actionHandlers[toolName] or {}
	actionHandlers[toolName][actionName] = handler
end

function ToolService.IsOwned(state: any, toolName: string): boolean
	local tool = state.Tools[toolName]
	return tool ~= nil and tool.Ownership ~= "Locked"
end

local function costForTrackLevel(toolName: string, track: any, level: number, modifiers: any): number
	local entry = track.Levels[level]
	if not entry then
		return math.huge
	end
	local cost = entry.CostCents
	if toolName == "Pitchfork" and modifiers.Forkmaster then
		cost = math.floor(cost * PitchforkConfig.FORKMASTER_COST_MULTIPLIER)
	end
	return cost
end

function ToolService.BuyUnlock(player: Player, toolName: string)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end

	local unlockCostCents
	if toolName == "Pitchfork" then
		unlockCostCents = PitchforkConfig.UNLOCK_COST_CENTS
	elseif toolName == "Dynamite" then
		unlockCostCents = DynamiteConfig.UNLOCK_COST_CENTS
	else
		return false, "NoCashUnlockForTool"
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		return false, "NoRunState"
	end
	local tool = state.Tools[toolName]
	if tool.Ownership ~= "Locked" then
		return false, "AlreadyOwned"
	end

	if not RunPlayerStateService.TrySpendCash(state, unlockCostCents) then
		return false, "InsufficientCash"
	end

	tool.Ownership = "RunOwned"
	RoundService.BroadcastPlayerState(player)
	RoundService.SendNotification(player, toolName .. " unlocked!", "Success")
	return true
end

function ToolService.BuyUpgrade(player: Player, toolName: string, trackName: string)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end

	local toolTracks = TOOL_TRACKS[toolName]
	local track = toolTracks and toolTracks[trackName]
	if not track then
		return false, "InvalidTrack"
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		return false, "NoRunState"
	end
	if not ToolService.IsOwned(state, toolName) then
		return false, "ToolNotOwned"
	end

	local tool = state.Tools[toolName]
	local currentLevel = tool[track.Field]
	local nextLevel = currentLevel + 1
	if nextLevel > track.MaxLevel then
		return false, "MaxLevel"
	end

	local cost = costForTrackLevel(toolName, track, nextLevel, state.Modifiers or {})
	if not RunPlayerStateService.TrySpendCash(state, cost) then
		return false, "InsufficientCash"
	end

	tool[track.Field] = nextLevel
	RoundService.BroadcastPlayerState(player)
	return true
end

-- Drone's alternate 40-Gem run-ownership purchase.
function ToolService.BuyDroneWithGems(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		return false, "NoRunState"
	end
	if ToolService.IsOwned(state, "Drone") then
		return false, "AlreadyOwned"
	end

	local currency = CoreLocator.GetCurrencyService()
	local spent = currency:TrySpend(player, "Gems", DroneConfig.ONE_ROUND_GEM_COST, "RunDrone")
	if not spent then
		return false, "InsufficientGems"
	end

	state.Tools.Drone.Ownership = "RunOwned"
	RoundService.BroadcastPlayerState(player)
	RoundService.SendNotification(player, "Drone deployed for this run!", "Success")
	return true
end

local function handleRunProductGrant(toolName: string)
	return function(player: Player)
		local run = RoundService.GetRunForPlayer(player)
		if not RoundService.IsActive(run) then
			return
		end
		local state = RunPlayerStateService.Get(player)
		if not state then
			return
		end
		local tool = state.Tools[toolName]
		if tool.Ownership == "Locked" then
			tool.Ownership = "RunOwned"
		end
		RoundService.BroadcastPlayerState(player)
		RoundService.SendNotification(player, toolName .. " granted for this round!", "Success")
	end
end

local function onToolActionRemote(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.Tool) ~= "string" or type(payload.Action) ~= "string" then
		return
	end

	local toolName, action = payload.Tool, payload.Action

	-- Drone's alternate one-round buy is a Gems (not Cash) transaction, so it
	-- stays here rather than under Gameplay_RequestBuyRunUpgrade.
	if action == "BuyDroneGems" and toolName == "Drone" then
		ToolService.BuyDroneWithGems(player)
		return
	end

	local handler = actionHandlers[toolName] and actionHandlers[toolName][action]
	if handler then
		handler(player, payload)
	end
end

function ToolService.Init()
	local remote = RemotesLocator.Get("Gameplay_RequestToolAction")
	remote.OnServerEvent:Connect(onToolActionRemote)

	local monetization = CoreLocator.GetMonetizationService()
	for toolName, productKey in pairs(RunConfig.ONE_ROUND_PRODUCT_KEYS) do
		local ok, err = pcall(function()
			monetization:RegisterRunProductGrant(productKey, handleRunProductGrant(toolName))
		end)
		if not ok then
			warn(("[Gameplay] Failed to register run product grant '%s': %s"):format(productKey, tostring(err)))
		end
	end
end

ToolService.TOOL_TRACKS = TOOL_TRACKS

return ToolService
