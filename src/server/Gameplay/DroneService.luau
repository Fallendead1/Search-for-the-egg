--[[
	Drone: an automatic pile -> sell station -> pile loop that runs alongside
	the owning player's own collecting. Modeled as a lightweight timed state
	machine (FlyToPile -> Collecting -> FlyToSell -> Selling -> repeat) driven
	by task.delay chains rather than a per-frame loop, since only phase
	transitions matter for gameplay/economy -- the actual flight animation is
	a client (agent/client-ui) presentation concern. Each transition fires a
	Gameplay_FX event with enough info (drone id, phase, target position) for
	the client to animate between MapAnchors positions however it likes.

	Every scheduled step is guarded by `entry.Alive == token`, so a drone that
	gets deactivated, whose owner leaves, or whose round ends never fires a
	stale collect/sell after cleanup -- this is what keeps a Drone Specialist
	swarm (temporary extra drones) from leaking cargo/rewards past its
	duration or across a round reset.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local DroneConfig = require(GameplayConfig.DroneConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local ToolService = require(script.Parent.ToolService)
local SellService = require(script.Parent.SellService)
local RewardRolls = require(script.Parent.RewardRolls)
local MapAnchors = require(script.Parent.MapAnchors)

local DroneService = {}

-- [droneId] = { Id, OwnerUserId, IsSwarmMember, ExpiresAt, Alive }
local drones: { [string]: any } = {}
-- [userId] = droneId, for the player's own (non-swarm) drone
local mainDroneByOwner: { [number]: string } = {}

local function droneStats(state: any)
	local tool = state.Tools.Drone
	local modifiers = state.Modifiers or {}

	local speedMultiplier = DroneConfig.SPEED_LEVELS[tool.SpeedLevel].Multiplier
	local graspAmount = DroneConfig.GRASP_LEVELS[tool.AmountLevel].Amount
	local capacity = DroneConfig.CAPACITY_LEVELS[tool.ExtraLevel].Capacity

	if modifiers.DroneSpecialist then
		speedMultiplier *= 1 + DroneConfig.SPECIALIST_SPEED_BONUS
		capacity = math.floor(capacity * (1 + DroneConfig.SPECIALIST_CAPACITY_BONUS))
	end

	return speedMultiplier, graspAmount, capacity
end

local function fireDroneFx(entry: any, phase: string, position: Vector3)
	RemotesLocator.Get("Gameplay_FX"):FireAllClients({
		Type = "DroneState",
		DroneId = entry.Id,
		OwnerUserId = entry.OwnerUserId,
		Phase = phase,
		Position = position,
	})
end

local function stopDrone(droneId: string)
	local entry = drones[droneId]
	if not entry then
		return
	end
	entry.Alive = nil
	drones[droneId] = nil
	if mainDroneByOwner[entry.OwnerUserId] == droneId then
		mainDroneByOwner[entry.OwnerUserId] = nil
	end
end

local function maybeSpawnSwarm(ownerUserId: number, state: any)
	if not (state.Modifiers or {}).DroneSpecialist then
		return
	end
	if math.random() >= DroneConfig.SPECIALIST_SWARM_CHANCE_PER_CYCLE then
		return
	end

	local expiresAt = os.clock() + DroneConfig.SPECIALIST_SWARM_DURATION_SECONDS
	for _ = 1, DroneConfig.SPECIALIST_SWARM_COUNT - 1 do
		DroneService.SpawnDrone(ownerUserId, true, expiresAt)
	end
	local player = game.Players:GetPlayerByUserId(ownerUserId)
	if player then
		RoundService.SendNotification(player, "Drone Specialist swarm active!", "Success")
	end
end

local function runCycle(droneId: string)
	local entry = drones[droneId]
	if not entry then
		return
	end
	local token = entry.Alive

	local player = game.Players:GetPlayerByUserId(entry.OwnerUserId)
	if not player then
		stopDrone(droneId)
		return
	end
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		stopDrone(droneId)
		return
	end
	if entry.IsSwarmMember and os.clock() >= entry.ExpiresAt then
		stopDrone(droneId)
		return
	end

	local state = RunPlayerStateService.Get(player)
	if not state or not ToolService.IsOwned(state, "Drone") then
		stopDrone(droneId)
		return
	end

	local speedMultiplier, graspAmount, capacity = droneStats(state)
	local pilePosition = run.Pile.Origin
	local sellPosition = MapAnchors.GetSellStationPosition()

	fireDroneFx(entry, "FlyToPile", pilePosition)
	task.delay(DroneConfig.BASE_TRAVEL_TO_PILE_SECONDS / speedMultiplier, function()
		if entry.Alive ~= token or drones[droneId] ~= entry then
			return
		end

		fireDroneFx(entry, "Collecting", pilePosition)
		task.delay(DroneConfig.BASE_COLLECT_SECONDS / speedMultiplier, function()
			if entry.Alive ~= token or drones[droneId] ~= entry then
				return
			end
			if not RoundService.IsActive(RoundService.GetRunForPlayer(player)) then
				stopDrone(droneId)
				return
			end

			local amountToCollect = math.min(graspAmount * DroneConfig.BASE_COLLECT_SECONDS, capacity)
			local removed = FeatherPileService.RemoveNear(run.Pile, pilePosition, amountToCollect, 3)
			local normalCount, rainbowCount, diamondHits, alienTokenHits = RewardRolls.RollOutcomes(removed, state.Modifiers or {})
			RewardRolls.AwardRareFinds(player, diamondHits, alienTokenHits)

			fireDroneFx(entry, "FlyToSell", sellPosition)
			task.delay(DroneConfig.BASE_TRAVEL_TO_SELL_SECONDS / speedMultiplier, function()
				if entry.Alive ~= token or drones[droneId] ~= entry then
					return
				end

				fireDroneFx(entry, "Selling", sellPosition)
				task.delay(DroneConfig.BASE_SELL_SECONDS, function()
					if entry.Alive ~= token or drones[droneId] ~= entry then
						return
					end
					local currentRun = RoundService.GetRunForPlayer(player)
					if not RoundService.IsActive(currentRun) then
						stopDrone(droneId)
						return
					end

					if normalCount + rainbowCount > 0 then
						local saleCents = SellService.ComputeSaleCents(currentRun, state, normalCount, rainbowCount)
						RunPlayerStateService.AddCash(state, saleCents)
						RoundService.BroadcastPlayerState(player)
					end

					if not entry.IsSwarmMember then
						maybeSpawnSwarm(entry.OwnerUserId, state)
					end

					runCycle(droneId)
				end)
			end)
		end)
	end)
end

function DroneService.SpawnDrone(ownerUserId: number, isSwarmMember: boolean, expiresAt: number?)
	local droneId = HttpService:GenerateGUID(false)
	local entry = {
		Id = droneId,
		OwnerUserId = ownerUserId,
		IsSwarmMember = isSwarmMember or false,
		ExpiresAt = expiresAt or math.huge,
		Alive = droneId,
	}
	drones[droneId] = entry
	if not isSwarmMember then
		mainDroneByOwner[ownerUserId] = droneId
	end
	runCycle(droneId)
	return droneId
end

local function handleToggle(player: Player, payload: any)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return
	end
	local state = RunPlayerStateService.Get(player)
	if not state or not ToolService.IsOwned(state, "Drone") then
		return
	end

	local wantActive = payload.Active == true
	local existingId = mainDroneByOwner[player.UserId]

	if wantActive then
		if not existingId then
			DroneService.SpawnDrone(player.UserId, false)
		end
	else
		if existingId then
			stopDrone(existingId)
		end
	end
end

function DroneService.CleanupRun(_run: any)
	for droneId in pairs(drones) do
		stopDrone(droneId)
	end
end

function DroneService.Init()
	ToolService.RegisterActionHandler("Drone", "Toggle", handleToggle)
	RoundService.OnRunEnded(DroneService.CleanupRun)

	game.Players.PlayerRemoving:Connect(function(player)
		local droneId = mainDroneByOwner[player.UserId]
		if droneId then
			stopDrone(droneId)
		end
	end)
end

return DroneService
