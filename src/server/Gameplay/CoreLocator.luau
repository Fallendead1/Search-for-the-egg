--[[
	Strict accessor for Agent 1's (Core) persistence/economy services.

	Core services are ModuleScripts under
	ServerScriptService.SearchForTheEgg.Core.<ServiceName>. This module never
	falls back to fake/in-memory state: if a Core service isn't present or
	fails to require, every accessor errors immediately so a missing/broken
	Core dependency is a loud boot-time failure instead of silent fake
	persistence for real players.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local CoreLocator = {}

local CORE_CONTAINER_PATH = { "SearchForTheEgg", "Core" }

local function findCoreContainer(): Instance
	local node: Instance = ServerScriptService
	for _, name in ipairs(CORE_CONTAINER_PATH) do
		local child = node:FindFirstChild(name)
		if not child then
			error(
				("[Gameplay] Core container 'ServerScriptService.%s' not found -- the Core agent's code is missing."):format(
					table.concat(CORE_CONTAINER_PATH, ".")
				)
			)
		end
		node = child
	end
	return node
end

local function requireService(serviceName: string): any
	local container = findCoreContainer()
	local moduleScript = container:FindFirstChild(serviceName)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error(
			("[Gameplay] Core service '%s' not found at ServerScriptService.SearchForTheEgg.Core.%s"):format(
				serviceName,
				serviceName
			)
		)
	end
	local ok, result = pcall(require, moduleScript)
	if not ok then
		error(("[Gameplay] Failed to require Core service '%s': %s"):format(serviceName, tostring(result)))
	end
	return result
end

local services = {}
local function cached(serviceName: string): any
	if not services[serviceName] then
		services[serviceName] = requireService(serviceName)
	end
	return services[serviceName]
end

function CoreLocator.GetCurrencyService()
	return cached("CurrencyService")
end

function CoreLocator.GetMetaProgressionService()
	return cached("MetaProgressionService")
end

function CoreLocator.GetInventoryService()
	return cached("InventoryService")
end

function CoreLocator.GetMonetizationService()
	return cached("MonetizationService")
end

function CoreLocator.GetLeaderboardService()
	return cached("LeaderboardService")
end

function CoreLocator.GetWins(player: Player): number
	return CoreLocator.GetMetaProgressionService().GetWins(player)
end

return CoreLocator
