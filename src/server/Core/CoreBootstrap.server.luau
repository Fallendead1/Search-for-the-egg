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
local DailyRewardService = require(script.Parent.DailyRewardService)
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

local EQUIP_CLASS_FAILURE_MESSAGES: { [string]: string } = {
	ProfileNotLoaded = "Still loading your profile -- try again in a moment.",
	InvalidSlot = "That slot isn't available.",
	InvalidClass = "Unknown class.",
	NotOwned = "You don't own that class yet.",
	Slot2Locked = "Second class slot is locked.",
	DuplicateClass = "That class is already equipped in the other slot.",
}

remote(RemoteNames.Core_RequestEquipClass).OnServerEvent:Connect(function(player, slotIndex, classId)
	if not RateLimitService.CheckAndStamp(player, "EquipClass") then
		return
	end
	if type(slotIndex) ~= "number" or type(classId) ~= "string" then
		return
	end
	local ok, err = ClassService.EquipClass(player, slotIndex, classId)
	if not ok then
		remote(RemoteNames.Gameplay_Notification):FireClient(player, {
			Text = EQUIP_CLASS_FAILURE_MESSAGES[err] or "Couldn't equip that class.",
			Kind = "Error",
		})
	end
end)

local PERMANENT_PERK_FAILURE_MESSAGES: { [string]: string } = {
	ProfileNotLoaded = "Still loading your profile -- try again in a moment.",
	InvalidPerk = "That upgrade isn't available.",
	MaxLevel = "Already at max level.",
	InsufficientGems = "Not enough Gems for that.",
}

remote(RemoteNames.Core_RequestBuyPermanentPerk).OnServerEvent:Connect(function(player, perkId)
	if not RateLimitService.CheckAndStamp(player, "BuyPermanentPerk") then
		return
	end
	if type(perkId) ~= "string" then
		return
	end
	local ok, err = MetaProgressionService.BuyPermanentPerk(player, perkId)
	if not ok then
		remote(RemoteNames.Gameplay_Notification):FireClient(player, {
			Text = PERMANENT_PERK_FAILURE_MESSAGES[err] or "Purchase failed.",
			Kind = "Error",
		})
	end
end)

local DAILY_REWARD_FAILURE_MESSAGES: { [string]: string } = {
	ProfileNotLoaded = "Still loading your profile -- try again in a moment.",
	ClaimInProgress = "Hold on, already claiming.",
	NotYetEligible = "Come back later for your next reward.",
	AwardFailed = "Couldn't claim that reward right now.",
}

remote(RemoteNames.Core_RequestClaimDailyReward).OnServerEvent:Connect(function(player)
	if not RateLimitService.CheckAndStamp(player, "ClaimDailyReward") then
		return
	end
	local ok, err = DailyRewardService.Claim(player)
	if not ok then
		remote(RemoteNames.Gameplay_Notification):FireClient(player, {
			Text = DAILY_REWARD_FAILURE_MESSAGES[err] or "Couldn't claim that reward right now.",
			Kind = "Error",
		})
	end
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
