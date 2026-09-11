--[[
	Shared rare-find rolling used by both CollectionService (Hand/Pitchfork)
	and VacuumService, so the Diamond/Alien Token/Rainbow probabilities live
	in exactly one place.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local CoreLocator = require(script.Parent.CoreLocator)
local RoundService = require(script.Parent.RoundService)

local RewardRolls = {}

-- Rolls rarity outcomes for `count` freshly-removed units. Returns
-- normalCount, rainbowCount, diamondHits, alienTokenHits.
function RewardRolls.RollOutcomes(count: number, modifiers: any): (number, number, number, number)
	local normalCount, rainbowCount, diamondHits, alienTokenHits = 0, 0, 0, 0

	local diamondChance = RunConfig.DIAMOND.BASE_CHANCE
	if modifiers.Prospector then
		diamondChance *= RunConfig.DIAMOND.PROSPECTOR_CHANCE_MULTIPLIER
	end
	local alienChance = RunConfig.ALIEN_TOKEN_DROP.BASE_CHANCE

	for _ = 1, count do
		local roll = math.random()
		if roll < diamondChance then
			diamondHits += 1
		elseif roll < diamondChance + alienChance then
			alienTokenHits += 1
		elseif roll < diamondChance + alienChance + RunConfig.RAINBOW_SPAWN_CHANCE then
			rainbowCount += 1
		else
			normalCount += 1
		end
	end

	return normalCount, rainbowCount, diamondHits, alienTokenHits
end

function RewardRolls.AwardRareFinds(player: Player, diamondHits: number, alienTokenHits: number)
	if diamondHits <= 0 and alienTokenHits <= 0 then
		return
	end
	local currency = CoreLocator.GetCurrencyService()

	for _ = 1, diamondHits do
		local amount = math.random(RunConfig.DIAMOND.GEM_REWARD_MIN, RunConfig.DIAMOND.GEM_REWARD_MAX)
		currency:Award(player, "Gems", amount, "PileDiamond", currency.Source.Earned)
	end
	if diamondHits > 0 then
		RoundService.SendNotification(player, "You found a Diamond in the pile!", "Success")
	end

	for _ = 1, alienTokenHits do
		currency:Award(player, "AlienTokens", RunConfig.ALIEN_TOKEN_DROP.REWARD_AMOUNT, "PileAlienToken", currency.Source.Earned)
	end
	if alienTokenHits > 0 then
		RoundService.SendNotification(player, "You found an Alien Token!", "Success")
	end
end

return RewardRolls
