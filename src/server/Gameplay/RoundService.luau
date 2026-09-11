--[[
	Owns the round state machine and the single active run.

	SCOPE DECISION: the design doc doesn't specify whether concurrent parties
	each get a fully separate physical instance of Chapter 1, or whether the
	map is one shared physical space. Since only one Studio map currently
	exists and instancing/teleporting parties into separate copies is a large
	additional system nobody asked for yet, this service supports exactly one
	Active run at a time server-wide; a party that tries to start while
	another run is in progress is rejected with "RoundInProgress". Internals
	are still organized around a `run` object (not bare globals) so upgrading
	to multiple concurrent runs later is a matter of keying by RunId instead
	of a single ActiveRun slot -- flagged for Agent 1/2 awareness.

	State machine: Lobby -> PartyForming -> Loading -> Active -> Completing
	-> Returning -> Ended. Only PartyService/EggService/FarmerService drive
	transitions; every gameplay action validates against RoundService.State.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local CoreLocator = require(script.Parent.CoreLocator)
local PartyService = require(script.Parent.PartyService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)

local RoundService = {}

local activeRun: any = nil

local onRunCreatedCallbacks: { (run: any) -> () } = {}
local onRunEndedCallbacks: { (run: any) -> () } = {}

function RoundService.OnRunCreated(callback)
	table.insert(onRunCreatedCallbacks, callback)
end

function RoundService.OnRunEnded(callback)
	table.insert(onRunEndedCallbacks, callback)
end

function RoundService.GetActiveRun()
	return activeRun
end

function RoundService.IsActive(run: any): boolean
	return run ~= nil and run == activeRun and run.State == "Active"
end

function RoundService.GetRunForPlayer(player: Player)
	if not activeRun then
		return nil
	end
	if table.find(activeRun.Members, player.UserId) then
		return activeRun
	end
	return nil
end

local function broadcastMeta(run: any)
	local remote = RemotesLocator.Get("Gameplay_RunState")
	local payload = {
		Type = "RoundMeta",
		RunId = run.RunId,
		RoundState = run.State,
		ChapterId = run.ChapterId,
		Difficulty = run.Difficulty,
		StartTime = run.StartTime,
		EggState = run.EggState,
		EggCarrierUserId = run.EggCarrierUserId,
		EggPosition = run.EggPosition,
		GoldenHarvestActive = run.GoldenHarvestActive,
		GoldenHarvestEndsAt = run.GoldenHarvestEndsAt,
	}
	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			remote:FireClient(player, payload)
		end
	end
end

function RoundService.BroadcastRunMeta(run: any)
	broadcastMeta(run)
end

function RoundService.BroadcastPlayerState(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not run then
		return
	end
	local state = RunPlayerStateService.Get(player)
	if not state then
		return
	end
	local remote = RemotesLocator.Get("Gameplay_RunState")
	remote:FireClient(player, {
		Type = "PlayerState",
		UserId = player.UserId,
		Data = RunPlayerStateService.SerializeForClient(state),
	})
end

local function sendNotification(player: Player, message: string, kind: string?)
	RemotesLocator.Get("Gameplay_Notification"):FireClient(player, {
		Message = message,
		Kind = kind or "Info",
	})
end
RoundService.SendNotification = sendNotification

-- Golden Harvest is a shared party buff (Ultimate Farmer class ability):
-- while any member carries the UltimateFarmer modifier, roll a chance every
-- CHECK_INTERVAL_SECONDS to grant the whole party 2x sell value for
-- DURATION_SECONDS. Guarded by run.GoldenHarvestActive so it can never stack.
local function startGoldenHarvestLoop(run: any)
	task.spawn(function()
		while run.State == "Active" do
			task.wait(RunConfig.GOLDEN_HARVEST.CHECK_INTERVAL_SECONDS)
			if run.State ~= "Active" or run.GoldenHarvestActive then
				continue
			end

			local anyUltimateFarmer = false
			for _, userId in ipairs(run.Members) do
				local player = Players:GetPlayerByUserId(userId)
				local state = player and RunPlayerStateService.Get(player)
				if state and state.Modifiers and state.Modifiers.UltimateFarmer then
					anyUltimateFarmer = true
					break
				end
			end
			if not anyUltimateFarmer then
				continue
			end
			if math.random() >= RunConfig.GOLDEN_HARVEST.TRIGGER_CHANCE then
				continue
			end

			run.GoldenHarvestActive = true
			run.GoldenHarvestEndsAt = os.time() + RunConfig.GOLDEN_HARVEST.DURATION_SECONDS
			broadcastMeta(run)
			RemotesLocator.Get("Gameplay_FX"):FireAllClients({
				Type = "GoldenHarvest",
				Active = true,
				DurationSeconds = RunConfig.GOLDEN_HARVEST.DURATION_SECONDS,
			})
			for _, userId in ipairs(run.Members) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					sendNotification(player, "Golden Harvest! 2x sell value for 10 seconds!", "Success")
				end
			end

			task.delay(RunConfig.GOLDEN_HARVEST.DURATION_SECONDS, function()
				if run.GoldenHarvestActive then
					run.GoldenHarvestActive = false
					run.GoldenHarvestEndsAt = nil
					broadcastMeta(run)
					RemotesLocator.Get("Gameplay_FX"):FireAllClients({ Type = "GoldenHarvest", Active = false })
				end
			end)
		end
	end)
end

local function createRunFromParty(party: any)
	local run = {
		RunId = HttpService:GenerateGUID(false),
		PartyId = party.PartyId,
		ChapterId = party.ChapterId,
		Difficulty = party.Difficulty,
		Members = table.clone(party.Members),
		State = "Loading",
		StartTime = 0,
		EggState = "Buried",
		EggCarrierUserId = nil,
		GoldenHarvestActive = false,
		GoldenHarvestEndsAt = nil,
		CompletionGuard = false,
	}
	return run
end

function RoundService.OnPartyStartRequested(party: any)
	if activeRun ~= nil then
		local owner = Players:GetPlayerByUserId(party.OwnerUserId)
		if owner then
			sendNotification(owner, "A round is already in progress. Try again shortly.", "Error")
		end
		return
	end

	local run = createRunFromParty(party)
	activeRun = run

	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RunPlayerStateService.InitPlayer(player, run.Difficulty)
		end
	end

	FeatherPileService.BuildForRun(run, run.Difficulty)

	run.State = "Active"
	run.StartTime = os.time()

	broadcastMeta(run)
	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RoundService.BroadcastPlayerState(player)
		end
	end

	for _, callback in ipairs(onRunCreatedCallbacks) do
		task.spawn(callback, run)
	end

	startGoldenHarvestLoop(run)
end

-- Atomically transitions Active -> Completing. Returns false if another
-- completion already won the race.
function RoundService.TryBeginCompletion(run: any): boolean
	if run.State ~= "Active" then
		return false
	end
	if run.CompletionGuard then
		return false
	end
	run.CompletionGuard = true
	run.State = "Completing"
	broadcastMeta(run)
	return true
end

-- Finalizes completion: awards each eligible member via Core, notifies, and
-- schedules cleanup. Must only be called after TryBeginCompletion succeeded.
function RoundService.FinalizeCompletion(run: any, winningUserId: number)
	local metaProgression = CoreLocator.GetMetaProgressionService()
	local difficulty = RunConfig.DIFFICULTY[run.Difficulty]
	local elapsedSeconds = os.time() - run.StartTime

	local summaries = {}
	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local state = RunPlayerStateService.Get(player)
			local ok, result = pcall(function()
				return metaProgression:AwardRunCompletion(player, {
					ChapterId = run.ChapterId,
					Difficulty = run.Difficulty,
					ElapsedSeconds = elapsedSeconds,
					FeathersCollected = state and state.FeathersCollected or 0,
				})
			end)
			if ok then
				summaries[userId] = result
			else
				warn(("[Gameplay] AwardRunCompletion failed for %d: %s"):format(userId, tostring(result)))
				summaries[userId] = { Gems = 0, AlienTokens = 0, Wins = 0 }
			end
		end
	end

	local completionRemote = RemotesLocator.Get("Gameplay_Completion")
	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			completionRemote:FireClient(player, {
				RunId = run.RunId,
				ChapterId = run.ChapterId,
				Difficulty = run.Difficulty,
				ElapsedSeconds = elapsedSeconds,
				WinningUserId = winningUserId,
				Reward = summaries[userId],
				ExpectedReward = difficulty and difficulty.CompletionReward or nil,
			})
		end
	end

	run.State = "Returning"
	broadcastMeta(run)

	task.delay(5, function()
		RoundService.EndRun(run)
	end)
end

function RoundService.EndRun(run: any)
	if run.State == "Ended" then
		return
	end
	run.State = "Ended"
	broadcastMeta(run)

	for _, callback in ipairs(onRunEndedCallbacks) do
		local ok, err = pcall(callback, run)
		if not ok then
			warn("[Gameplay] OnRunEnded callback failed: " .. tostring(err))
		end
	end

	FeatherPileService.Destroy(run.Pile)

	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RunPlayerStateService.Remove(player)
		end
	end

	local party = PartyService.GetParty(run.PartyId)
	if party then
		PartyService.ReleasePartyAfterRun(party)
	end

	if activeRun == run then
		activeRun = nil
	end
end

-- Handles a member disconnecting or leaving mid-run: if it was the last
-- present member, end the run early instead of leaking it forever.
local function handlePlayerRemoving(player: Player)
	if not activeRun then
		return
	end
	if not table.find(activeRun.Members, player.UserId) then
		return
	end
	local anyoneLeft = false
	for _, userId in ipairs(activeRun.Members) do
		if userId ~= player.UserId and Players:GetPlayerByUserId(userId) then
			anyoneLeft = true
			break
		end
	end
	if not anyoneLeft and activeRun.State ~= "Ended" then
		RoundService.EndRun(activeRun)
	end
end

function RoundService.Init()
	PartyService.SetOnPartyStartRequested(RoundService.OnPartyStartRequested)
	Players.PlayerRemoving:Connect(handlePlayerRemoving)
end

return RoundService
