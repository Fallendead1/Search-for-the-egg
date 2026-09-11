--!strict
-- Safe accessor for the shared remote contract.
--
-- Agent 1 (core-server) and Agent 3 (gameplay-systems) own the actual
-- RemoteEvent/RemoteFunction instances under
-- ReplicatedStorage.SearchForTheEgg.Remotes. This module never creates
-- remotes -- it only waits for them by the agreed contract name so this
-- client can keep developing in parallel before those instances exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local WAIT_TIMEOUT = 15
local cache: { [string]: RemoteEvent | RemoteFunction } = {}
local warned: { [string]: boolean } = {}

local function getRemotesFolder(): Instance?
	local root = ReplicatedStorage:FindFirstChild("SearchForTheEgg")
		or ReplicatedStorage:WaitForChild("SearchForTheEgg", WAIT_TIMEOUT)
	if not root then
		return nil
	end
	return root:FindFirstChild("Remotes") or root:WaitForChild("Remotes", WAIT_TIMEOUT)
end

local function resolve(name: string): (RemoteEvent | RemoteFunction)?
	local existing = cache[name]
	if existing then
		return existing
	end

	local folder = getRemotesFolder()
	if not folder then
		if not warned[name] then
			warn(("[Remotes] Could not find Remotes folder while resolving '%s'"):format(name))
			warned[name] = true
		end
		return nil
	end

	local instance = folder:FindFirstChild(name) :: (RemoteEvent | RemoteFunction)?
	if not instance then
		instance = folder:WaitForChild(name, WAIT_TIMEOUT) :: (RemoteEvent | RemoteFunction)?
	end

	if not instance then
		if not warned[name] then
			warn(("[Remotes] Remote '%s' not present yet -- another agent may not have created it."):format(name))
			warned[name] = true
		end
		return nil
	end

	cache[name] = instance
	return instance
end

-- Fire-and-forget a RemoteEvent to the server. Silently no-ops (with a single
-- warning) if the remote isn't present yet.
function Remotes.fireServer(name: string, ...: any)
	local remote = resolve(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(...)
	end
end

-- Connect a handler to a server->client RemoteEvent. Returns a disconnect
-- function; if the remote never resolves, returns a no-op disconnect.
function Remotes.onClientEvent(name: string, handler: (...any) -> ()): () -> ()
	local remote = resolve(name)
	if remote and remote:IsA("RemoteEvent") then
		local connection = remote.OnClientEvent:Connect(handler)
		return function()
			connection:Disconnect()
		end
	end

	task.spawn(function()
		local folder = getRemotesFolder()
		if not folder then
			return
		end
		local instance = folder:WaitForChild(name, WAIT_TIMEOUT)
		if instance and instance:IsA("RemoteEvent") then
			cache[name] = instance
		end
	end)

	return function() end
end

-- Invoke a RemoteFunction and return (ok, result). Never throws.
function Remotes.invokeServer(name: string, ...: any): (boolean, any)
	local remote = resolve(name)
	if not remote or not remote:IsA("RemoteFunction") then
		return false, nil
	end
	local ok, result = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	return ok, result
end

return Remotes
