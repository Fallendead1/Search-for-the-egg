--[[
	Strict accessor for Gameplay's RemoteEvents.

	Ownership: Core (agent 1) is the ONE canonical remote creator. RemoteNames
	(ReplicatedStorage.SearchForTheEgg.Net.RemoteNames) lists every remote in
	the game, and RemoteBootstrap.Init() (ServerScriptService.SearchForTheEgg
	.Core.RemoteBootstrap) creates each one exactly once. This module never
	creates a RemoteEvent itself.

	RemoteBootstrap.Init() is idempotent (a boolean flag makes every call
	after the first a no-op that returns the same table), so it is safe to
	call from here too even though CoreBootstrap.server.luau also calls it --
	Core and Gameplay are separate Script instances with no guaranteed run
	order, and whichever one runs first performs the actual creation.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local RemoteBootstrap = require(ServerScriptService.SearchForTheEgg.Core.RemoteBootstrap)

local RemotesLocator = {}

function RemotesLocator.Init()
	return RemoteBootstrap.Init()
end

function RemotesLocator.Get(name: string): RemoteEvent
	local remote = RemoteBootstrap.Get(name)
	assert(remote, ("[Gameplay] Remote '%s' is not in the canonical RemoteNames registry"):format(name))
	return remote
end

return RemotesLocator
