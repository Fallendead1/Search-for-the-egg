--[[
	Receiving side of ChapterTeleportService's reserved-server teleport (see
	TeleportConfig's header for the full architecture). Completely inert
	unless BOTH are true: TeleportConfig.IsChapter1TeleportConfigured() AND
	this server's game.PlaceId is that Chapter1PlaceId -- on the ordinary
	Lobby/local-fallback path (Chapter1PlaceId unconfigured, which is the
	default) this module's Init() returns immediately and connects nothing.

	A player arriving via TeleportAsync carries whatever
	TeleportOptions:SetTeleportData() was set to in player:GetJoinData()
	.TeleportData. That data crossed a server boundary through Roblox's own
	teleport system, not a client-fired remote -- but it is still
	server-supplied data this server didn't produce itself, so every field
	is validated the same way any other untrusted-until-checked input is
	here, never assumed safe just because it came from "our own" Lobby
	server.

	Multiple party members can arrive across several ticks (or not at all,
	if their individual teleport failed even though the party's overall
	TeleportAsync call succeeded -- Roblox does not guarantee every member
	arrives together). This accumulates arrivals per PartyId and starts the
	run once every expected member has arrived, or after a grace period
	with however many actually made it -- never waits forever, and never
	starts with zero players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)
local TeleportConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.TeleportConfig)

local RoundService = require(script.Parent.RoundService)

local ChapterArrivalService = {}

local GRACE_PERIOD_SECONDS = 20

-- [PartyId] = { ChapterId, Difficulty, ExpectedCount, ArrivedMembers = {userId, ...}, Started }
local pendingArrivals: { [string]: any } = {}

-- Exposed (not local) so DebugTests can verify rejection of malformed
-- teleport data directly -- pure function, no Player/server state needed.
function ChapterArrivalService.IsValidTeleportData(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	if type(data.PartyId) ~= "string" or data.PartyId == "" then
		return false
	end
	if type(data.ChapterId) ~= "string" or not RunConfig.CHAPTERS[data.ChapterId] then
		return false
	end
	if type(data.Difficulty) ~= "string" or not RunConfig.DIFFICULTY[data.Difficulty] then
		return false
	end
	if type(data.Members) ~= "table" then
		return false
	end
	local count = #data.Members
	if count <= 0 or count > RunConfig.PARTY_MAX_SIZE then
		return false
	end
	for _, memberId in ipairs(data.Members) do
		if type(memberId) ~= "number" then
			return false
		end
	end
	return true
end

local function tryStartArrival(entry: any)
	if entry.Started then
		return
	end
	if #entry.ArrivedMembers == 0 then
		return
	end
	entry.Started = true

	-- A minimal party-shaped table -- this server never ran
	-- PartyService.CreateParty for these players (the real party was
	-- formed and already started back on the Lobby server); RoundService
	-- only needs these fields to build and start the run.
	local party = {
		PartyId = entry.PartyId,
		OwnerUserId = entry.ArrivedMembers[1],
		Members = table.clone(entry.ArrivedMembers),
		MaxSize = RunConfig.PARTY_MAX_SIZE,
		ChapterId = entry.ChapterId,
		Difficulty = entry.Difficulty,
		CanStart = true,
		Started = true,
	}

	RoundService.OnPartyStartRequested(party)
	pendingArrivals[entry.PartyId] = nil
end

local function onPlayerAdded(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok then
		return
	end

	local teleportData = joinData and joinData.TeleportData
	if not ChapterArrivalService.IsValidTeleportData(teleportData) then
		return
	end

	local partyId = teleportData.PartyId :: string
	local entry = pendingArrivals[partyId]
	if not entry then
		entry = {
			PartyId = partyId,
			ChapterId = teleportData.ChapterId,
			Difficulty = teleportData.Difficulty,
			ExpectedCount = #teleportData.Members,
			ArrivedMembers = {} :: { number },
			Started = false,
		}
		pendingArrivals[partyId] = entry

		-- Grace period: start with whoever has arrived even if not every
		-- expected member ever makes it (their individual teleport may
		-- have failed independently of the party's).
		task.delay(GRACE_PERIOD_SECONDS, function()
			if pendingArrivals[partyId] == entry then
				tryStartArrival(entry)
			end
		end)
	end

	if not table.find(entry.ArrivedMembers, player.UserId) then
		table.insert(entry.ArrivedMembers, player.UserId)
	end

	if #entry.ArrivedMembers >= entry.ExpectedCount then
		tryStartArrival(entry)
	end
end

function ChapterArrivalService.Init()
	if not TeleportConfig.IsChapter1TeleportConfigured() then
		return
	end
	if game.PlaceId ~= TeleportConfig.Chapter1PlaceId then
		return
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return ChapterArrivalService
