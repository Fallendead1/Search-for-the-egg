--[[
	Feather Packing Bot: a NEW, separately-owned automated helper (MAJOR
	GAMEPLAY/WORLD INTEGRATION UPDATE). Reuses DroneService's overall shape
	-- a purely logical state machine (no server-side Instance), toggled via
	ToolService's "Toggle" action, broadcasting the same Gameplay_FX
	"DroneState" {DroneId, OwnerUserId, Phase, Position, AssetName} event
	DroneVisualController already renders -- but with fixed stats (no
	upgrade levels) and its own PILE/COLLECT/SELL/RETURN pacing driven by
	real travel distance at PackingBotConfig.TRAVEL_STUDS_PER_SECOND, rather
	than Drone's tunable speed multiplier.

	Does NOT replace or modify DroneService; Packing Bot is its own
	ownership-gated equipment item (state.Tools.PackingBot).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local PackingBotConfig = require(GameplayConfig.PackingBotConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local ToolService = require(script.Parent.ToolService)
local SellService = require(script.Parent.SellService)
local RewardRolls = require(script.Parent.RewardRolls)
local MapAnchors = require(script.Parent.MapAnchors)

local PackingBotService = {}

local bots: { [string]: any } = {}
local mainBotByOwner: { [number]: string } = {}

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

local function travelSeconds(from: Vector3, to: Vector3): number
	return math.max(0.5, distance(from, to) / PackingBotConfig.TRAVEL_STUDS_PER_SECOND)
end

local function fireBotFx(entry: any, phase: string, position: Vector3)
	RemotesLocator.Get("Gameplay_FX"):FireAllClients({
		Type = "DroneState",
		DroneId = entry.Id,
		OwnerUserId = entry.OwnerUserId,
		Phase = phase,
		Position = position,
		AssetName = "PackingBot",
	})
end

local function stopBot(botId: string)
	local entry = bots[botId]
	if not entry then
		return
	end
	entry.Alive = nil
	bots[botId] = nil
	if mainBotByOwner[entry.OwnerUserId] == botId then
		mainBotByOwner[entry.OwnerUserId] = nil
	end
end

local function runCycle(botId: string)
	local entry = bots[botId]
	if not entry then
		return
	end
	local token = entry.Alive

	local player = game.Players:GetPlayerByUserId(entry.OwnerUserId)
	if not player then
		stopBot(botId)
		return
	end
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		stopBot(botId)
		return
	end
	local state = RunPlayerStateService.Get(player)
	if not state or not ToolService.IsOwned(state, "PackingBot") then
		stopBot(botId)
		return
	end

	local pilePosition = run.Pile.Origin
	local sellPosition = MapAnchors.GetSellStationPosition()

	fireBotFx(entry, "FlyToPile", pilePosition)
	task.delay(travelSeconds(entry.LastPosition, pilePosition), function()
		if entry.Alive ~= token or bots[botId] ~= entry then
			return
		end
		entry.LastPosition = pilePosition

		fireBotFx(entry, "Collecting", pilePosition)
		local collected = 0
		local ticksNeeded = math.ceil(PackingBotConfig.CAPACITY / PackingBotConfig.COLLECT_PER_CYCLE)
		local function collectTick(remainingTicks: number)
			if entry.Alive ~= token or bots[botId] ~= entry then
				return
			end
			if not RoundService.IsActive(RoundService.GetRunForPlayer(player)) then
				stopBot(botId)
				return
			end
			if remainingTicks <= 0 or collected >= PackingBotConfig.CAPACITY then
				local normalCount, rainbowCount, diamondHits, alienTokenHits = RewardRolls.RollOutcomes(collected, state.Modifiers or {})
				RewardRolls.AwardRareFinds(player, diamondHits, alienTokenHits)

				fireBotFx(entry, "FlyToSell", sellPosition)
				task.delay(travelSeconds(pilePosition, sellPosition), function()
					if entry.Alive ~= token or bots[botId] ~= entry then
						return
					end
					entry.LastPosition = sellPosition

					fireBotFx(entry, "Selling", sellPosition)
					task.delay(PackingBotConfig.SELL_SECONDS, function()
						if entry.Alive ~= token or bots[botId] ~= entry then
							return
						end
						local currentRun = RoundService.GetRunForPlayer(player)
						if not RoundService.IsActive(currentRun) then
							stopBot(botId)
							return
						end

						if normalCount + rainbowCount > 0 then
							local saleCents = SellService.ComputeSaleCents(currentRun, state, normalCount, rainbowCount)
							RunPlayerStateService.AddCash(state, saleCents)
							RoundService.BroadcastPlayerState(player)
						end

						runCycle(botId)
					end)
				end)
				return
			end

			local amount = math.min(PackingBotConfig.COLLECT_PER_CYCLE, PackingBotConfig.CAPACITY - collected)
			local removed = FeatherPileService.RemoveNear(run.Pile, pilePosition, amount, 3)
			collected += removed

			task.delay(PackingBotConfig.COLLECT_TICK_SECONDS, function()
				collectTick(remainingTicks - 1)
			end)
		end
		collectTick(ticksNeeded)
	end)
end

function PackingBotService.SpawnBot(ownerUserId: number)
	local HttpService = game:GetService("HttpService")
	local botId = HttpService:GenerateGUID(false)
	local entry = {
		Id = botId,
		OwnerUserId = ownerUserId,
		Alive = botId,
		LastPosition = MapAnchors.GetSellStationPosition(),
	}
	bots[botId] = entry
	mainBotByOwner[ownerUserId] = botId
	runCycle(botId)
	return botId
end

local function handleToggle(player: Player, payload: any)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return
	end
	local state = RunPlayerStateService.Get(player)
	if not state or not ToolService.IsOwned(state, "PackingBot") then
		return
	end

	local wantActive = payload.Active == true
	local existingId = mainBotByOwner[player.UserId]

	if wantActive then
		if not existingId then
			PackingBotService.SpawnBot(player.UserId)
		end
	else
		if existingId then
			stopBot(existingId)
		end
	end
end

function PackingBotService.CleanupRun(_run: any)
	for botId in pairs(bots) do
		stopBot(botId)
	end
end

function PackingBotService.Init()
	ToolService.RegisterActionHandler("PackingBot", "Toggle", handleToggle)
	RoundService.OnRunEnded(PackingBotService.CleanupRun)

	game.Players.PlayerRemoving:Connect(function(player)
		local botId = mainBotByOwner[player.UserId]
		if botId then
			stopBot(botId)
		end
	end)
end

return PackingBotService
