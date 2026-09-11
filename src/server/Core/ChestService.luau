--[[
	Alien Chest RNG and rewards. All reward RNG is server-side only; the
	client receives a result only after the award has already been committed
	to the profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChestConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.ChestConfig)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local ChestService = {}

local TOTAL_WEIGHT = 0
for _, entry in ChestConfig.Rewards do
	TOTAL_WEIGHT += entry.Weight
end

local function rollReward()
	local roll = math.random() * TOTAL_WEIGHT
	local cursor = 0
	for _, entry in ChestConfig.Rewards do
		cursor += entry.Weight
		if roll <= cursor then
			return entry
		end
	end
	return ChestConfig.Rewards[1]
end

local function grantReward(player: Player, entry)
	if entry.Type == "Gems" then
		local amount = math.random(entry.Min, entry.Max)
		CurrencyService.Award(player, "Gems", amount, "AlienChest")
		return { Type = "Gems", Amount = amount }
	elseif entry.Type == "Skin" then
		InventoryService.GrantSkin(player, entry.Category, entry.SkinId, "AlienChest")
		return { Type = "Skin", Category = entry.Category, SkinId = entry.SkinId }
	end
	return { Type = "Unknown" }
end

-- Normal opening path: subtracts `count` * TokenCost Alien Tokens and rolls.
function ChestService.OpenWithTokens(player: Player, count: number?): (boolean, any)
	count = count or 1
	if type(count) ~= "number" or count < 1 or count > ChestConfig.MaxTokenOpenCount or count % 1 ~= 0 then
		return false, "InvalidCount"
	end

	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end

	local totalCost = ChestConfig.TokenCost * count
	if not CurrencyService.TrySpend(player, "AlienTokens", totalCost, "AlienChestOpen") then
		return false, "InsufficientTokens"
	end

	local rewards = {}
	for _ = 1, count do
		table.insert(rewards, grantReward(player, rollReward()))
	end

	DataService.PushProfileUpdated(player)

	return true, { Rewards = rewards }
end

-- Opens `count` chests already paid for via a Robux receipt (no Token cost).
-- `count` here is server-controlled (comes from MonetizationConfig, never
-- from the client) so it does not need the same bounds validation.
function ChestService.OpenPaidBatch(player: Player, count: number): (boolean, any)
	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end
	if type(count) ~= "number" or count < 1 then
		return false, "InvalidCount"
	end

	local rewards = {}
	for _ = 1, count do
		table.insert(rewards, grantReward(player, rollReward()))
	end

	DataService.PushProfileUpdated(player)

	return true, { Rewards = rewards }
end

return ChestService
