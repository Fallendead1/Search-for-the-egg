--[[
	Party lifecycle: create, join, selection, start, leave, and disconnect
	cleanup. One player belongs to at most one party at a time.

	NOTE ON SCOPE: the contract lists Gameplay_RequestCreateParty /
	SetPartySelection / StartParty / LeaveParty but no explicit "join" remote,
	even though parties are described as 1-4 players. This module adds
	Gameplay_RequestJoinParty (created idempotently via RemotesLocator, same
	as every other remote here) since a multi-member party is unusable without
	one. Flagged in the handoff for Agent 1 to fold into their remote
	inventory / rename if they'd already planned a different mechanism (e.g.
	an invite/UI-only flow).
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local RunConfig = require(game:GetService("ReplicatedStorage").SearchForTheEgg.GameplayConfig.RunConfig)
local RemotesLocator = require(script.Parent.RemotesLocator)
local HardModeService = require(script.Parent.HardModeService)

local PartyService = {}

local parties: { [string]: any } = {}
local playerPartyId: { [number]: string } = {}

local onPartyChanged: (party: any) -> () = function() end
local onPartyStartRequested: (party: any) -> () = function() end

function PartyService.SetOnPartyChanged(callback)
	onPartyChanged = callback
end

function PartyService.SetOnPartyStartRequested(callback)
	onPartyStartRequested = callback
end

local function difficultyUnlocked(player: Player, difficultyId: string): boolean
	return HardModeService.DifficultyUnlocked(player, difficultyId)
end

local function chapterUnlocked(player: Player, chapterId: string): boolean
	return HardModeService.ChapterUnlocked(player, chapterId)
end

local function serializeParty(party: any)
	return {
		PartyId = party.PartyId,
		OwnerUserId = party.OwnerUserId,
		Members = table.clone(party.Members),
		MaxSize = party.MaxSize,
		ChapterId = party.ChapterId,
		Difficulty = party.Difficulty,
		CanStart = party.CanStart,
		Started = party.Started,
	}
end

local function broadcastParty(party: any)
	local remote = RemotesLocator.Get("Gameplay_PartyState")
	local payload = serializeParty(party)
	for _, userId in ipairs(party.Members) do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			remote:FireClient(member, payload)
		end
	end
	onPartyChanged(party)
end

local function recomputeCanStart(party: any)
	if party.Started then
		party.CanStart = false
		return
	end
	if #party.Members < 1 or #party.Members > party.MaxSize then
		party.CanStart = false
		return
	end
	local owner = Players:GetPlayerByUserId(party.OwnerUserId)
	if not owner then
		party.CanStart = false
		return
	end
	party.CanStart = chapterUnlocked(owner, party.ChapterId) and difficultyUnlocked(owner, party.Difficulty)
end

function PartyService.GetParty(partyId: string)
	return parties[partyId]
end

function PartyService.GetPlayerParty(player: Player)
	local partyId = playerPartyId[player.UserId]
	return partyId and parties[partyId]
end

local function removeMember(party: any, userId: number)
	local index = table.find(party.Members, userId)
	if index then
		table.remove(party.Members, index)
	end
	playerPartyId[userId] = nil
end

local function destroyParty(party: any)
	parties[party.PartyId] = nil
end

local function leaveCurrentParty(player: Player)
	local party = PartyService.GetPlayerParty(player)
	if not party then
		return
	end

	removeMember(party, player.UserId)

	if #party.Members == 0 then
		destroyParty(party)
		return
	end

	if party.OwnerUserId == player.UserId then
		party.OwnerUserId = party.Members[1]
	end

	recomputeCanStart(party)
	broadcastParty(party)
end

function PartyService.CreateParty(player: Player)
	if PartyService.GetPlayerParty(player) then
		return nil, "AlreadyInParty"
	end

	local party = {
		PartyId = HttpService:GenerateGUID(false),
		OwnerUserId = player.UserId,
		Members = { player.UserId },
		MaxSize = RunConfig.PARTY_MAX_SIZE,
		ChapterId = "Chapter1",
		Difficulty = "Normal",
		CanStart = false,
		Started = false,
	}

	parties[party.PartyId] = party
	playerPartyId[player.UserId] = party.PartyId

	recomputeCanStart(party)
	broadcastParty(party)

	return party
end

function PartyService.JoinParty(player: Player, partyId: string)
	if PartyService.GetPlayerParty(player) then
		return false, "AlreadyInParty"
	end

	local party = parties[partyId]
	if not party then
		return false, "PartyNotFound"
	end
	if party.Started then
		return false, "PartyAlreadyStarted"
	end
	if #party.Members >= party.MaxSize then
		return false, "PartyFull"
	end

	table.insert(party.Members, player.UserId)
	playerPartyId[player.UserId] = party.PartyId

	recomputeCanStart(party)
	broadcastParty(party)

	return true
end

function PartyService.SetSelection(player: Player, chapterId: string, difficultyId: string)
	local party = PartyService.GetPlayerParty(player)
	if not party then
		return false, "NotInParty"
	end
	if party.OwnerUserId ~= player.UserId then
		return false, "NotOwner"
	end
	if party.Started then
		return false, "PartyAlreadyStarted"
	end
	if not RunConfig.CHAPTERS[chapterId] then
		return false, "InvalidChapter"
	end
	if not RunConfig.DIFFICULTY[difficultyId] then
		return false, "InvalidDifficulty"
	end
	if not chapterUnlocked(player, chapterId) then
		return false, "ChapterLocked"
	end
	if not difficultyUnlocked(player, difficultyId) then
		return false, "DifficultyLocked"
	end

	party.ChapterId = chapterId
	party.Difficulty = difficultyId

	recomputeCanStart(party)
	broadcastParty(party)

	return true
end

function PartyService.RequestStart(player: Player)
	local party = PartyService.GetPlayerParty(player)
	if not party then
		return false, "NotInParty"
	end
	if party.OwnerUserId ~= player.UserId then
		return false, "NotOwner"
	end
	if party.Started then
		return false, "PartyAlreadyStarted"
	end

	recomputeCanStart(party)
	if not party.CanStart then
		return false, "CannotStart"
	end

	party.Started = true
	broadcastParty(party)
	onPartyStartRequested(party)

	return true
end

function PartyService.LeaveParty(player: Player)
	local party = PartyService.GetPlayerParty(player)
	if not party then
		return false, "NotInParty"
	end
	leaveCurrentParty(player)
	return true
end

-- Called by RoundService once a run ends, so members can form/join a new party.
function PartyService.ReleasePartyAfterRun(party: any)
	for _, userId in ipairs(table.clone(party.Members)) do
		playerPartyId[userId] = nil
	end
	destroyParty(party)
end

function PartyService.Init()
	local remotes = {
		CreateParty = RemotesLocator.Get("Gameplay_RequestCreateParty"),
		Join = RemotesLocator.Get("Gameplay_RequestJoinParty"),
		SetSelection = RemotesLocator.Get("Gameplay_RequestSetPartySelection"),
		Start = RemotesLocator.Get("Gameplay_RequestStartParty"),
		Leave = RemotesLocator.Get("Gameplay_RequestLeaveParty"),
	}

	remotes.CreateParty.OnServerEvent:Connect(function(player: Player)
		PartyService.CreateParty(player)
	end)

	remotes.Join.OnServerEvent:Connect(function(player: Player, partyId)
		if type(partyId) ~= "string" then
			return
		end
		PartyService.JoinParty(player, partyId)
	end)

	remotes.SetSelection.OnServerEvent:Connect(function(player: Player, chapterId, difficultyId)
		if type(chapterId) ~= "string" or type(difficultyId) ~= "string" then
			return
		end
		PartyService.SetSelection(player, chapterId, difficultyId)
	end)

	remotes.Start.OnServerEvent:Connect(function(player: Player)
		PartyService.RequestStart(player)
	end)

	remotes.Leave.OnServerEvent:Connect(function(player: Player)
		PartyService.LeaveParty(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		leaveCurrentParty(player)
	end)
end

return PartyService
