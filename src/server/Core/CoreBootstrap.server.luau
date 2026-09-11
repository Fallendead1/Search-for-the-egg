--[[
	Entry point for all Core (persistent/server-authoritative) systems:
	creates remotes, then wires the Core_* remote handlers. Gameplay_* remotes
	are created (by RemoteBootstrap) but never handled here -- the Gameplay
	agent connects its own handlers to those.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.SearchForTheEgg.Net.RemoteNames)

local RemoteBootstrap = require(script.Parent.RemoteBootstrap)
RemoteBootstrap.Init()

local DataService = require(script.Parent.DataService)
local ClassService = require(script.Parent.ClassService)
local InventoryService = require(script.Parent.InventoryService)
local ChestService = require(script.Parent.ChestService)
local CodeService = require(script.Parent.CodeService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local MonetizationService = require(script.Parent.MonetizationService)
local RateLimitService = require(script.Parent.RateLimitService)
local LeaderboardService = require(script.Parent.LeaderboardService)

MonetizationService.Init()
LeaderboardService.Init()

local function remote(name: string): RemoteEvent
	local instance = RemoteBootstrap.Get(name)
	assert(instance, ("CoreBootstrap: remote %s was not created"):format(name))
	return instance
end

remote(RemoteNames.Core_RequestProfileSnapshot).OnServerEvent:Connect(function(player)
	if not RateLimitService.CheckAndStamp(player, "ProfileSnapshot") then
		return
	end
	if not DataService.IsLoaded(player) then
		return
	end
	DataService.PushProfileUpdated(player)
end)

remote(RemoteNames.Core_RequestClassRoll).OnServerEvent:Connect(function(player)
	if not RateLimitService.CheckAndStamp(player, "ClassRoll") then
		return
	end

	local ok, resultOrReason = ClassService.RollClass(player)
	local payload: any = { Success = ok }
	if ok then
		payload.ClassId = resultOrReason.ClassId
		payload.IsNew = resultOrReason.IsNew
		payload.DisplayName = resultOrReason.DisplayName
	else
		payload.Reason = resultOrReason
		payload.Message = resultOrReason
	end
	remote(RemoteNames.Core_ClassRollResult):FireClient(player, payload)
end)

remote(RemoteNames.Core_RequestEquipClass).OnServerEvent:Connect(function(player, slotIndex, classId)
	if not RateLimitService.CheckAndStamp(player, "EquipClass") then
		return
	end
	if type(slotIndex) ~= "number" or type(classId) ~= "string" then
		return
	end
	ClassService.EquipClass(player, slotIndex, classId)
end)

remote(RemoteNames.Core_RequestBuyPermanentPerk).OnServerEvent:Connect(function(player, perkId)
	if not RateLimitService.CheckAndStamp(player, "BuyPermanentPerk") then
		return
	end
	if type(perkId) ~= "string" then
		return
	end
	MetaProgressionService.BuyPermanentPerk(player, perkId)
end)

remote(RemoteNames.Core_RequestOpenAlienChest).OnServerEvent:Connect(function(player, count)
	if not RateLimitService.CheckAndStamp(player, "OpenAlienChest") then
		return
	end

	local ok, resultOrReason = ChestService.OpenWithTokens(player, count)
	remote(RemoteNames.Core_AlienChestResult):FireClient(player, {
		Success = ok,
		Reason = (not ok) and resultOrReason or nil,
		Rewards = ok and resultOrReason.Rewards or nil,
	})
end)

remote(RemoteNames.Core_RequestSelectSkin).OnServerEvent:Connect(function(player, category, skinId)
	if not RateLimitService.CheckAndStamp(player, "SelectSkin") then
		return
	end
	if type(category) ~= "string" or type(skinId) ~= "string" then
		return
	end
	InventoryService.SetSelectedSkin(player, category, skinId)
end)

remote(RemoteNames.Core_RequestRedeemCode).OnServerEvent:Connect(function(player, code)
	if not RateLimitService.CheckAndStamp(player, "RedeemCode") then
		return
	end

	local ok, resultOrReason = CodeService.RedeemCode(player, code)
	remote(RemoteNames.Core_CodeResult):FireClient(player, {
		Success = ok,
		Reason = (not ok) and resultOrReason or nil,
		Result = ok and resultOrReason or nil,
	})
end)

remote(RemoteNames.Core_RequestLeaderboard).OnServerEvent:Connect(function(player)
	if not RateLimitService.CheckAndStamp(player, "RequestLeaderboard") then
		return
	end
	-- Always the cached snapshot -- never a live DataStore read triggered
	-- by a client request (see LeaderboardService's header).
	local boards = LeaderboardService.GetBoards()
	remote(RemoteNames.Core_LeaderboardResult):FireClient(player, {
		Wins = boards.Wins,
		Feathers = boards.Feathers,
		BestTime = boards.BestTime,
	})
end)

print("[CoreBootstrap] SearchForTheEgg Core services initialized.")
