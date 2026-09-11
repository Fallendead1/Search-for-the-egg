--[[
	Creates every remote listed in RemoteNames exactly once, under
	ReplicatedStorage/SearchForTheEgg/Remotes. Reuses the existing "Remotes"
	folder (already synced in via src/shared/Remotes.model.json) rather than
	creating a duplicate container.

	Every remote is a RemoteEvent -- request/response pairs (e.g.
	Core_RequestClassRoll / Core_ClassRollResult) are two separate
	RemoteEvents, never a RemoteFunction, so a slow/misbehaving client can
	never block a server-side yield.

	Gameplay_* remotes are created here (this module owns remote creation)
	but their handlers belong entirely to the Gameplay agent -- Core never
	connects to a Gameplay_* remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.SearchForTheEgg.Net.RemoteNames)

local RemoteBootstrap = {}

local remotes = {} :: { [string]: RemoteEvent }
local initialized = false

function RemoteBootstrap.Init()
	if initialized then
		return remotes
	end
	initialized = true

	local rootFolder = ReplicatedStorage:WaitForChild("SearchForTheEgg")

	local remotesFolder = rootFolder:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = rootFolder
	end

	for _, name in RemoteNames do
		local existing = remotesFolder:FindFirstChild(name)
		if existing then
			if existing:IsA("RemoteEvent") then
				remotes[name] = existing
			else
				warn(("RemoteBootstrap: %s already exists but is not a RemoteEvent"):format(name))
			end
		else
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = name
			remoteEvent.Parent = remotesFolder
			remotes[name] = remoteEvent
		end
	end

	return remotes
end

function RemoteBootstrap.Get(name: string): RemoteEvent?
	return remotes[name]
end

return RemoteBootstrap
