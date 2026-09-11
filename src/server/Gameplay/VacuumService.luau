--[[
	Vacuum: continuous collection while toggled on, with Heat/Runtime/
	Overheat/Recovery. Uses ONE central RunService.Heartbeat connection for
	every active Vacuum user (bounded by party size, so at most 4 entries),
	not a per-player loop. State is pushed to clients on a throttled interval,
	not every tick.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local RunConfig = require(GameplayConfig.RunConfig)
local VacuumConfig = require(GameplayConfig.VacuumConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local ToolService = require(script.Parent.ToolService)
local RewardRolls = require(script.Parent.RewardRolls)

local VacuumService = {}

-- [userId] = { Player, State, RuntimeElapsed, Overheated, OverheatEndsAt, Carry, LastReplicateAt }
local activeVacuums: { [number]: any } = {}

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

local function getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position
end

-- VacuumHeat is normalized 0..1 (what the client's heat bar fill reads);
-- Active/Overheated/RuntimeElapsed are kept for any consumer that wants the
-- raw values.
local function replicateHeat(entry: any)
	local runtimeLimit = VacuumConfig.RUNTIME_LEVELS[entry.State.Tools.Vacuum.ExtraLevel].RuntimeSeconds
	local heatFraction = entry.Overheated and 1 or math.clamp(entry.RuntimeElapsed / runtimeLimit, 0, 1)

	local remote = RemotesLocator.Get("Gameplay_RunState")
	remote:FireClient(entry.Player, {
		Type = "VacuumHeat",
		VacuumHeat = heatFraction,
		Active = not entry.Overheated,
		Overheated = entry.Overheated,
		RuntimeElapsed = entry.RuntimeElapsed,
	})
end

local function deactivate(userId: number)
	activeVacuums[userId] = nil
end

local function handleToggle(player: Player, payload: any)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return
	end

	local state = RunPlayerStateService.Get(player)
	if not state or not ToolService.IsOwned(state, "Vacuum") then
		return
	end

	local wantActive = payload.Active == true

	if not wantActive then
		deactivate(player.UserId)
		return
	end

	local existing = activeVacuums[player.UserId]
	if existing and existing.Overheated then
		return
	end
	if existing then
		return
	end

	activeVacuums[player.UserId] = {
		Player = player,
		State = state,
		RuntimeElapsed = 0,
		Overheated = false,
		OverheatEndsAt = 0,
		Carry = 0,
		LastReplicateAt = 0,
	}
end

local function tick(deltaTime: number)
	local now = os.clock()

	for userId, entry in pairs(activeVacuums) do
		local player = entry.Player
		if not player or not player.Parent then
			deactivate(userId)
			continue
		end

		local run = RoundService.GetRunForPlayer(player)
		if not RoundService.IsActive(run) then
			deactivate(userId)
			continue
		end

		local state = entry.State
		local tool = state.Tools.Vacuum

		if entry.Overheated then
			if now >= entry.OverheatEndsAt then
				entry.Overheated = false
				entry.RuntimeElapsed = 0
				replicateHeat(entry)
			end
			continue
		end

		local characterPosition = getCharacterPosition(player)
		if not characterPosition or distance(characterPosition, run.Pile.Origin) > RunConfig.RANGE.VACUUM + run.Pile.GridRadius * run.Pile.ColumnSize then
			continue
		end

		local capacity = RunPlayerStateService.EffectiveBagCapacity(state)
		if state.BagCount < capacity then
			local powerPerSecond = VacuumConfig.POWER_LEVELS[tool.AmountLevel].FeathersPerSecond
			entry.Carry += powerPerSecond * deltaTime
			local wholeUnits = math.floor(entry.Carry)
			if wholeUnits > 0 then
				entry.Carry -= wholeUnits
				local removed = FeatherPileService.RemoveNear(run.Pile, characterPosition, wholeUnits, 2)
				if removed > 0 then
					local normalCount, rainbowCount, diamondHits, alienTokenHits =
						RewardRolls.RollOutcomes(removed, state.Modifiers or {})
					local normalAdded, rainbowAdded = RunPlayerStateService.AddToBag(state, normalCount, rainbowCount)
					state.FeathersCollected += normalAdded + rainbowAdded
					RewardRolls.AwardRareFinds(player, diamondHits, alienTokenHits)
				end
			end
		end

		entry.RuntimeElapsed += deltaTime
		local runtimeLimit = VacuumConfig.RUNTIME_LEVELS[tool.ExtraLevel].RuntimeSeconds
		if entry.RuntimeElapsed >= runtimeLimit then
			entry.Overheated = true
			local recoverySeconds = VacuumConfig.COOLING_LEVELS[tool.SpeedLevel].RecoverySeconds
			entry.OverheatEndsAt = now + recoverySeconds
			RoundService.SendNotification(player, "Vacuum overheated!", "Warning")
			replicateHeat(entry)
		elseif now - entry.LastReplicateAt >= VacuumConfig.STATE_REPLICATION_INTERVAL_SECONDS then
			entry.LastReplicateAt = now
			replicateHeat(entry)
			RoundService.BroadcastPlayerState(player)
		end
	end
end

function VacuumService.CleanupRun(_run: any)
	for userId in pairs(activeVacuums) do
		deactivate(userId)
	end
end

function VacuumService.Init()
	ToolService.RegisterActionHandler("Vacuum", "Toggle", handleToggle)
	RoundService.OnRunEnded(VacuumService.CleanupRun)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < VacuumConfig.CENTRAL_TICK_SECONDS then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		tick(elapsed)
	end)

	Players.PlayerRemoving:Connect(function(player)
		deactivate(player.UserId)
	end)
end

return VacuumService
