--[[
	Owns player profile load/save lifecycle. Self-initializes on first
	require: wires Players.PlayerAdded/PlayerRemoving and BindToClose, so any
	Core service can simply `require` this module to guarantee it is running.

	Public API:
		DataService.IsLoaded(player) -> boolean
		DataService.GetProfile(player) -> Profile? (mutable, server-only)
		DataService.GetPublicSnapshot(player) -> ClientProfileSnapshot?
		DataService.PushProfileUpdated(player) -- fires Core_ProfileUpdated
		DataService.ProfileLoaded -- Signal(player), fired after load
		DataService.ProfileReleasing -- Signal(player), fired just before release
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.DataSchema)
local RemoteNames = require(ReplicatedStorage.SearchForTheEgg.Net.RemoteNames)
local ProfileStore = require(script.Parent.ProfileStore)

local DataService = {}

local AUTOSAVE_INTERVAL_SECONDS = 120
local DATASTORE_NAME = "SearchForTheEgg_PlayerProfiles_v1"

local store = ProfileStore.new(DATASTORE_NAME, DataSchema.GetDefaultProfile, DataSchema.Reconcile)

local profileHandles = {} :: { [Player]: any }
local sessionStartClock = {} :: { [Player]: number }

local profileLoadedEvent = Instance.new("BindableEvent")
local profileReleasingEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = profileLoadedEvent.Event
DataService.ProfileReleasing = profileReleasingEvent.Event

local profileUpdatedRemote: RemoteEvent? = nil
local function getProfileUpdatedRemote(): RemoteEvent
	if not profileUpdatedRemote then
		profileUpdatedRemote = ReplicatedStorage
			:WaitForChild("SearchForTheEgg")
			:WaitForChild("Remotes")
			:WaitForChild(RemoteNames.Core_ProfileUpdated) :: RemoteEvent
	end
	return profileUpdatedRemote :: RemoteEvent
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function flushPlaytime(player: Player)
	local handle = profileHandles[player]
	local last = sessionStartClock[player]
	if not handle or not last then
		return
	end

	local now = os.clock()
	local elapsed = now - last
	if elapsed > 0 then
		handle.Data.Stats.TotalPlaytime += elapsed
	end
	sessionStartClock[player] = now
end

function DataService.IsLoaded(player: Player): boolean
	local handle = profileHandles[player]
	return handle ~= nil and handle.Active == true
end

function DataService.GetProfile(player: Player)
	local handle = profileHandles[player]
	if not handle then
		return nil
	end
	return handle.Data
end

local function cloneMapOfMaps(source: { [string]: { [string]: boolean } })
	local result = {}
	for key, inner in source do
		result[key] = table.clone(inner)
	end
	return result
end

function DataService.GetPublicSnapshot(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end

	return {
		Currencies = table.clone(profile.Currencies),
		Stats = table.clone(profile.Stats),
		PermanentPerks = table.clone(profile.PermanentPerks),
		Classes = {
			Owned = table.clone(profile.Classes.Owned),
			Equipped = table.clone(profile.Classes.Equipped),
			Slot2Unlocked = profile.Classes.Slot2Unlocked,
		},
		Inventory = {
			OwnedSkins = cloneMapOfMaps(profile.Inventory.OwnedSkins),
			SelectedSkins = table.clone(profile.Inventory.SelectedSkins),
		},
		EntitlementSummary = table.clone(profile.Entitlements),
	}
end

function DataService.PushProfileUpdated(player: Player)
	local snapshot = DataService.GetPublicSnapshot(player)
	if not snapshot then
		return
	end

	local ok, remote = pcall(getProfileUpdatedRemote)
	if ok and remote then
		remote:FireClient(player, snapshot)
	end
end

local function onPlayerAdded(player: Player)
	local handle = store:Load(keyFor(player))
	if not handle then
		warn(("DataService: failed to load profile for %s, kicking."):format(player.Name))
		player:Kick("Failed to load your save data. Please rejoin in a moment.")
		return
	end

	profileHandles[player] = handle
	sessionStartClock[player] = os.clock()

	DataService.PushProfileUpdated(player)
	profileLoadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	flushPlaytime(player)
	sessionStartClock[player] = nil

	local handle = profileHandles[player]
	profileHandles[player] = nil

	if handle then
		profileReleasingEvent:Fire(player)
		store:Save(handle)
		store:Release(handle)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for player, handle in profileHandles do
			flushPlaytime(player)
			store:Save(handle)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		onPlayerRemoving(player)
	end
	store:ReleaseAllSync(25)
end)

return DataService
