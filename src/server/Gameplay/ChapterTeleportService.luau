--[[
	Reserves a private server on the Chapter 1 place (TeleportConfig) and
	teleports only the requesting party's members there, so their run is
	fully isolated from the Lobby and from every other party. Only used when
	TeleportConfig.IsChapter1TeleportConfigured() is true -- see that
	module's header for how to turn this on. Until then, RoundService runs
	Chapter 1 locally via its same-server run queue instead.
]]

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeleportConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.TeleportConfig)

local ChapterTeleportService = {}

-- Returns true if the party's members were successfully handed off to
-- TeleportService. Never yields the caller indefinitely and never throws.
function ChapterTeleportService.TeleportParty(party: any): boolean
	local members = {}
	for _, userId in ipairs(party.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(members, player)
		end
	end
	if #members == 0 then
		return false
	end

	local reserveOk, reservedAccessCodeOrErr = pcall(function()
		return TeleportService:ReserveServer(TeleportConfig.Chapter1PlaceId)
	end)
	if not reserveOk then
		warn(("[Gameplay] ChapterTeleportService: ReserveServer failed: %s"):format(tostring(reservedAccessCodeOrErr)))
		return false
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ReservedServerAccessCode = reservedAccessCodeOrErr
	teleportOptions:SetTeleportData({
		PartyId = party.PartyId,
		ChapterId = party.ChapterId,
		Difficulty = party.Difficulty,
		Members = party.Members,
	})

	local teleportOk, teleportErr = pcall(function()
		TeleportService:TeleportAsync(TeleportConfig.Chapter1PlaceId, members, teleportOptions)
	end)
	if not teleportOk then
		warn(("[Gameplay] ChapterTeleportService: TeleportAsync failed: %s"):format(tostring(teleportErr)))
		return false
	end

	return true
end

return ChapterTeleportService
