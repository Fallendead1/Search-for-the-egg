--[[
	Owns the round state machine and every run currently in flight.

	PRODUCTION ARCHITECTURE (see TeleportConfig.luau): when
	TeleportConfig.IsChapter1TeleportConfigured() is true, a party that
	starts is handed off to ChapterTeleportService, which reserves a private
	server on Chapter 1's own Place and teleports only that party there --
	every party gets a fully isolated pile/Egg/Farmer instance, and this
	(Lobby) server is never blocked no matter how many parties are mid-run
	elsewhere.

	LOCAL FALLBACK (default, since Chapter1PlaceId starts unconfigured):
	there is currently only one physical map (one MapAnchors pile/sell
	station/Farmer), so this server can only ever host ONE party's run at a
	time. Rather than reject a second party's start request outright (which
	would block the whole Lobby from ever progressing, an explicitly
	rejected design), every started party is admitted immediately into a
	RunId-keyed FIFO queue: `runsById`/`playerRunId` track every run object
	that exists right now (queued or actually running), and `runQueue`
	orders the ones still waiting for the shared pile. The moment the
	physically active run ends, the next queued run is built and started
	automatically. Parties are never blocked from forming/selecting/starting
	in the Lobby; they just wait their turn for the one shared map. Once
	Chapter1PlaceId is configured, this local queue is never exercised --
	every party gets its own server instead.

	State machine: Queued -> Active -> Completing -> Returning -> Ended. Only
	PartyService/EggService/FarmerService drive transitions; every gameplay
	action validates against RoundService.IsActive(run).

	Gameplay_RunState canonical contract (all three sub-messages share one
	remote; fields merge flatly into the client's PlayerState.Run so field
	names must never collide across message types):
		{ Type = "RoundMeta", RunId, InProgress, RoundState, ChapterId,
		  Difficulty, StartedAt, QueuePosition, EggState, EggCarrierUserId,
		  EggPosition, GoldenHarvestActive, GoldenHarvestEndsAt }
		{ Type = "PlayerState", UserId, CashCents, BagCount, BagCapacity,
		  BagLevel, RainbowInBag, HandHoldUnlocked, HandSpeed, HandGrasp,
		  HandSpeedLevel, HandGraspLevel, CarryingEgg, Tools }
		{ Type = "VacuumHeat", VacuumHeat, Active, Overheated, RuntimeElapsed }
	StartedAt is stamped from workspace:GetServerTimeNow() (NOT os.time())
	so it shares a clock domain with the client's own GetServerTimeNow() timer
	sync in RunHUDController.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)
local TeleportConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.TeleportConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local CoreLocator = require(script.Parent.CoreLocator)
local PartyService = require(script.Parent.PartyService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local MapAnchors = require(script.Parent.MapAnchors)

local RoundService = {}

-- Every run that currently exists (queued or active), keyed by RunId.
local runsById: { [string]: any } = {}
-- userId -> RunId, for O(1) GetRunForPlayer/GetRunForUserId lookups.
local playerRunId: { [number]: string } = {}
-- RunIds waiting for the one shared local pile, in start order.
local runQueue: { string } = {}
-- The RunId currently occupying the shared local pile, if any.
local physicallyActiveRunId: string? = nil

-- Safety valve, NOT a GDD timer/mechanic: on the local (unconfigured
-- Chapter1PlaceId) fallback, one run occupies the ONLY shared pile, so an
-- abandoned run (every member still connected but AFK, or genuinely stuck)
-- would otherwise block every other party in the Lobby from ever getting a
-- turn. Nothing about the pace of a normal run comes anywhere close to
-- this ceiling. Never used once Chapter1PlaceId is configured -- each
-- reserved server only ever hosts the one party that teleported there, so
-- there is no queue for a stuck run to block.
local MAX_RUN_DURATION_SECONDS = 1800

local onRunCreatedCallbacks: { (run: any) -> () } = {}
local onRunEndedCallbacks: { (run: any) -> () } = {}

function RoundService.OnRunCreated(callback)
	table.insert(onRunCreatedCallbacks, callback)
end

function RoundService.OnRunEnded(callback)
	table.insert(onRunEndedCallbacks, callback)
end

function RoundService.IsActive(run: any): boolean
	return run ~= nil and run.State == "Active"
end

function RoundService.GetRunForUserId(userId: number)
	local runId = playerRunId[userId]
	return runId and runsById[runId]
end

function RoundService.GetRunForPlayer(player: Player)
	return RoundService.GetRunForUserId(player.UserId)
end

local function broadcastMeta(run: any)
	local remote = RemotesLocator.Get("Gameplay_RunState")
	local queueIndex = table.find(runQueue, run.RunId)
	local payload = {
		Type = "RoundMeta",
		RunId = run.RunId,
		InProgress = run.State == "Active",
		RoundState = run.State,
		ChapterId = run.ChapterId,
		Difficulty = run.Difficulty,
		StartedAt = run.StartedAt,
		QueuePosition = queueIndex,
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

-- Recomputes and (re)broadcasts QueuePosition for every run still waiting,
-- so queued parties see their position tick down rather than looking stuck.
local function broadcastQueuePositions()
	for _, runId in ipairs(runQueue) do
		local run = runsById[runId]
		if run then
			broadcastMeta(run)
		end
	end
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
	local payload = RunPlayerStateService.SerializeForClient(state)
	payload.Type = "PlayerState"
	payload.UserId = player.UserId
	remote:FireClient(player, payload)
end

local function sendNotification(player: Player, message: string, kind: string?)
	-- Guards the fake (plain-table, not a real Player Instance) callers
	-- DebugTests exercises this through -- FireClient requires a real
	-- Instance, so this would otherwise error instead of gracefully
	-- degrading the way every other service touched by those tests does.
	if typeof(player) ~= "Instance" then
		return
	end
	RemotesLocator.Get("Gameplay_Notification"):FireClient(player, {
		Text = message,
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
		State = "Queued",
		StartedAt = nil,
		EggState = "Buried",
		EggCarrierUserId = nil,
		GoldenHarvestActive = false,
		GoldenHarvestEndsAt = nil,
		CompletionGuard = false,
	}
	return run
end

-- The local same-server fallback (Chapter1PlaceId unconfigured) has no
-- TeleportAsync to move a player anywhere -- without this, a run going
-- Active never actually gets its party from the Lobby into the gameplay
-- map at all. Also runs (harmlessly) after a real cross-place teleport, so
-- arriving players land exactly on the map's intended spawn rather than
-- wherever the receiving place's default spawn happens to be.
local function moveCharacterTo(userId: number, position: Vector3)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	end
end

local tryAdvanceQueue

-- Actually builds the pile and flips a queued run to Active. Only ever
-- called for the one run allowed to occupy the shared local pile.
local function startRunNow(run: any)
	physicallyActiveRunId = run.RunId

	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RunPlayerStateService.InitPlayer(player, run.Difficulty)
		end
	end

	local chapterSpawnPosition = MapAnchors.GetChapterSpawnPosition()
	for _, userId in ipairs(run.Members) do
		moveCharacterTo(userId, chapterSpawnPosition)
	end

	FeatherPileService.BuildForRun(run, run.Difficulty)
	FeatherPileService.BroadcastSnapshot(run.Pile)

	run.State = "Active"
	run.StartedAt = Workspace:GetServerTimeNow()

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

	-- Abandoned-run safety valve (see MAX_RUN_DURATION_SECONDS above) --
	-- only actually matters on the local fallback path, but harmless
	-- either way since it only fires if the run is somehow still Active.
	task.delay(MAX_RUN_DURATION_SECONDS, function()
		if run.State == "Active" then
			for _, userId in ipairs(run.Members) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					sendNotification(player, "This run took too long and was ended automatically.", "Error")
				end
			end
			RoundService.EndRun(run)
		end
	end)
end

tryAdvanceQueue = function()
	if physicallyActiveRunId ~= nil then
		return
	end
	local nextRunId = table.remove(runQueue, 1)
	if not nextRunId then
		return
	end
	local run = runsById[nextRunId]
	if not run or run.State ~= "Queued" then
		tryAdvanceQueue()
		return
	end
	startRunNow(run)
	broadcastQueuePositions()
end

function RoundService.OnPartyStartRequested(party: any)
	if TeleportConfig.IsChapter1TeleportConfigured() and game.PlaceId ~= TeleportConfig.Chapter1PlaceId then
		local ChapterTeleportService = require(script.Parent.ChapterTeleportService)
		if not ChapterTeleportService.TeleportParty(party) then
			-- Production teleport failure: PartyService already flipped
			-- Started = true before calling us (RequestStart), so without
			-- this the party would be permanently stuck -- RequestStart
			-- rejects with "PartyAlreadyStarted" forever and there is no
			-- other way to clear that flag. Reset it and tell every member,
			-- not just the owner, so everyone sees why nothing happened and
			-- the owner can immediately retry.
			PartyService.NotifyStartFailed(party.PartyId)
			for _, userId in ipairs(party.Members) do
				local member = Players:GetPlayerByUserId(userId)
				if member then
					sendNotification(member, "Could not start your run right now. Please try again.", "Error")
				end
			end
		end
		return
	end

	local run = createRunFromParty(party)
	runsById[run.RunId] = run
	for _, userId in ipairs(run.Members) do
		playerRunId[userId] = run.RunId
	end

	table.insert(runQueue, run.RunId)
	broadcastMeta(run)

	if #runQueue > 1 then
		for _, userId in ipairs(run.Members) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				sendNotification(player, "Chapter 1 is busy -- your party will start automatically.", "Info")
			end
		end
	end

	tryAdvanceQueue()
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
	local elapsedSeconds = Workspace:GetServerTimeNow() - (run.StartedAt or Workspace:GetServerTimeNow())

	local summaries = {}
	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local state = RunPlayerStateService.Get(player)
			local ok, result = pcall(function()
				return metaProgression.AwardRunCompletion(player, {
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
				summaries[userId] = { GemsAwarded = 0, AlienTokensAwarded = 0, Wins = 0 }
			end
		end
	end

	local completionRemote = RemotesLocator.Get("Gameplay_Completion")
	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local summary = summaries[userId] or {}
			completionRemote:FireClient(player, {
				RunId = run.RunId,
				ChapterId = run.ChapterId,
				Difficulty = run.Difficulty,
				Time = elapsedSeconds,
				WinningUserId = winningUserId,
				Gems = summary.GemsAwarded or 0,
				AlienTokens = summary.AlienTokensAwarded or 0,
				Wins = summary.Wins or 0,
				NewRecord = summary.IsNewRecord or false,
				BestTime = summary.BestTime,
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

	if run.Pile then
		FeatherPileService.Destroy(run.Pile)
	end

	-- Only meaningful on the local same-server fallback -- once
	-- Chapter1PlaceId is configured, "returning to the Lobby" is a real
	-- cross-place teleport this module doesn't own, not a local CFrame move.
	if not TeleportConfig.IsChapter1TeleportConfigured() then
		local lobby = Workspace:FindFirstChild("SearchForTheEgg_Lobby")
		local lobbySpawn = lobby and lobby:FindFirstChild("LobbySpawn")
		if lobbySpawn then
			for _, userId in ipairs(run.Members) do
				moveCharacterTo(userId, lobbySpawn.Position)
			end
		end
	end

	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RunPlayerStateService.Remove(player)
		end
		if playerRunId[userId] == run.RunId then
			playerRunId[userId] = nil
		end
	end

	local party = PartyService.GetParty(run.PartyId)
	if party then
		PartyService.ReleasePartyAfterRun(party)
	end

	runsById[run.RunId] = nil
	if physicallyActiveRunId == run.RunId then
		physicallyActiveRunId = nil
		tryAdvanceQueue()
	end
end

-- Drops a run that was still Queued (never occupied the pile, nothing to
-- tear down) when it loses every member before its turn comes up.
local function dropQueuedRun(run: any)
	runsById[run.RunId] = nil
	local index = table.find(runQueue, run.RunId)
	if index then
		table.remove(runQueue, index)
	end
	for _, userId in ipairs(run.Members) do
		if playerRunId[userId] == run.RunId then
			playerRunId[userId] = nil
		end
	end
	local party = PartyService.GetParty(run.PartyId)
	if party then
		PartyService.ReleasePartyAfterRun(party)
	end
end

-- Handles a member disconnecting or leaving mid-run/queue: if it was the
-- last present member, end (or drop) the run early instead of leaking it.
local function handlePlayerRemoving(player: Player)
	local runId = playerRunId[player.UserId]
	if not runId then
		return
	end
	local run = runsById[runId]
	if not run then
		playerRunId[player.UserId] = nil
		return
	end

	local anyoneLeft = false
	for _, userId in ipairs(run.Members) do
		if userId ~= player.UserId and Players:GetPlayerByUserId(userId) then
			anyoneLeft = true
			break
		end
	end
	if anyoneLeft then
		return
	end

	if run.State == "Queued" then
		dropQueuedRun(run)
	elseif run.State ~= "Ended" then
		RoundService.EndRun(run)
	end
end

function RoundService.Init()
	PartyService.SetOnPartyStartRequested(RoundService.OnPartyStartRequested)
	Players.PlayerRemoving:Connect(handlePlayerRemoving)
end

return RoundService
