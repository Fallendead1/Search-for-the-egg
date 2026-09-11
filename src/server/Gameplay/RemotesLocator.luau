--[[
	Idempotent get-or-create accessor for the RemoteEvents this system needs.

	Ownership note: per the shared architecture contract, Agent 1 (core-server)
	is responsible for creating these RemoteEvents. At the time this module was
	written core-server had not landed any code, so GameplayBootstrap needs
	working remotes to be testable. This module FindFirstChild's before
	creating, so it never duplicates a RemoteEvent that core-server (or a
	previous run of this same script) already placed under
	ReplicatedStorage.SearchForTheEgg.Remotes. Once core-server adds these to
	Remotes.model.json, this module will simply attach to the existing
	instances instead of creating new ones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesLocator = {}

local INBOUND_REMOTE_NAMES = {
	"Gameplay_RequestCreateParty",
	-- Not in the original contract; added because a 1-4 player party is
	-- unusable without a join mechanism. See PartyService.luau header.
	"Gameplay_RequestJoinParty",
	"Gameplay_RequestSetPartySelection",
	"Gameplay_RequestStartParty",
	"Gameplay_RequestLeaveParty",
	"Gameplay_RequestCollect",
	"Gameplay_RequestSell",
	"Gameplay_RequestBuyRunUpgrade",
	"Gameplay_RequestToolAction",
	"Gameplay_RequestEggPickup",
	"Gameplay_RequestEggTurnIn",
}

local OUTBOUND_REMOTE_NAMES = {
	"Gameplay_PartyState",
	"Gameplay_RunState",
	"Gameplay_Notification",
	"Gameplay_FX",
	"Gameplay_Completion",
}

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotesCache: { [string]: RemoteEvent } = {}

function RemotesLocator.Init()
	local root = getOrCreateFolder(ReplicatedStorage, "SearchForTheEgg")
	local remotesFolder = getOrCreateFolder(root, "Remotes")

	for _, name in ipairs(INBOUND_REMOTE_NAMES) do
		remotesCache[name] = getOrCreateRemoteEvent(remotesFolder, name)
	end
	for _, name in ipairs(OUTBOUND_REMOTE_NAMES) do
		remotesCache[name] = getOrCreateRemoteEvent(remotesFolder, name)
	end

	return remotesCache
end

function RemotesLocator.Get(name: string): RemoteEvent
	local remote = remotesCache[name]
	assert(remote, ("[Gameplay] Remote '%s' was requested before RemotesLocator.Init()"):format(name))
	return remote
end

return RemotesLocator
