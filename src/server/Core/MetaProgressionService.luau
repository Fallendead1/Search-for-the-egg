--[[
	Orchestrates meta-progression: normalized gameplay modifiers (class +
	permanent perks combined), run-completion rewards, and permanent perk
	purchases. This is the main entry point the Gameplay agent calls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PermanentPerksConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.PermanentPerksConfig)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local StatsService = require(script.Parent.StatsService)
local ClassService = require(script.Parent.ClassService)
local RewardService = require(script.Parent.RewardService)

local MetaProgressionService = {}

local VALID_DIFFICULTIES = { Normal = true, Hard = true }

function MetaProgressionService.GetPermanentPerkLevel(player: Player, perkId: string): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	return profile.PermanentPerks[perkId] or 0
end

-- Normalized modifiers the Gameplay agent should apply during a run. Combines
-- equipped-class passives (ClassService) with permanent Gem-shop perks.
function MetaProgressionService.GetGameplayModifiers(player: Player)
	local classModifiers = ClassService.GetEffectiveClassModifiers(player)
	local profile = DataService.GetProfile(player)

	local perks = (profile and profile.PermanentPerks) or {
		BagSize = 0,
		HandGrabAmount = 0,
		GemValue = 0,
		FeatherValue = 0,
	}

	local bagSizeConfig = PermanentPerksConfig.Perks.BagSize
	local handGrabConfig = PermanentPerksConfig.Perks.HandGrabAmount
	local gemValueConfig = PermanentPerksConfig.Perks.GemValue
	local featherValueConfig = PermanentPerksConfig.Perks.FeatherValue

	local bagCapacityFlatBonus = perks.BagSize * bagSizeConfig.EffectPerLevel
	local handGraspFlatBonus = perks.HandGrabAmount * handGrabConfig.EffectPerLevel
	local gemRewardMultiplier = 1 + (perks.GemValue * gemValueConfig.EffectPerLevel)
	local featherValuePerkMultiplier = 1 + (perks.FeatherValue * featherValueConfig.EffectPerLevel)

	return {
		BagCapacityMultiplier = classModifiers.BagCapacityMultiplier,
		BagCapacityFlatBonus = bagCapacityFlatBonus,
		SaleMultiplier = classModifiers.SaleMultiplier,
		FeatherValueMultiplier = featherValuePerkMultiplier,
		HandGraspFlatBonus = handGraspFlatBonus,
		PitchforkYieldMultiplier = classModifiers.PitchforkYieldMultiplier,
		PitchforkUpgradeCostMultiplier = classModifiers.PitchforkUpgradeCostMultiplier,
		DynamiteRadiusMultiplier = classModifiers.DynamiteRadiusMultiplier,
		DynamiteMiniChargeChance = classModifiers.DynamiteMiniChargeChance,
		ProspectorEnabled = classModifiers.ProspectorEnabled,
		DroneAlwaysOwned = classModifiers.DroneAlwaysOwned,
		DroneSpeedMultiplier = classModifiers.DroneSpeedMultiplier,
		DroneCapacityMultiplier = classModifiers.DroneCapacityMultiplier,
		DroneSwarmChance = classModifiers.DroneSwarmChance,
		UltimateFarmer = classModifiers.UltimateFarmer,
		GoldenHarvestEnabled = classModifiers.GoldenHarvestEnabled,
		GoldenHarvestChance = classModifiers.GoldenHarvestChance,
		GemRewardMultiplier = gemRewardMultiplier,
	}
end

-- Called by the Gameplay agent on chapter completion. Reward AMOUNTS are
-- always looked up server-side via RewardService -- never accepted from the
-- caller. `result` = { ChapterId, Difficulty, ElapsedSeconds, FeathersCollected }.
function MetaProgressionService.AwardRunCompletion(player: Player, result: any)
	if not DataService.IsLoaded(player) then
		return nil
	end
	if type(result) ~= "table" then
		return nil
	end

	local chapterId = result.ChapterId
	local difficulty = result.Difficulty
	local elapsedSeconds = result.ElapsedSeconds
	local feathersCollected = tonumber(result.FeathersCollected) or 0

	if not VALID_DIFFICULTIES[difficulty] then
		warn(("MetaProgressionService: invalid difficulty %s"):format(tostring(difficulty)))
		return nil
	end

	local reward = RewardService.GetCompletionReward(chapterId, difficulty)
	if not reward then
		warn(("MetaProgressionService: unknown chapter/difficulty %s/%s"):format(tostring(chapterId), tostring(difficulty)))
		return nil
	end

	local modifiers = MetaProgressionService.GetGameplayModifiers(player)

	local gemsAwarded = math.floor(reward.Gems * modifiers.GemRewardMultiplier + 0.5)
	local tokensAwarded = reward.AlienTokens

	local _, actualGemsAwarded = CurrencyService.Award(player, "Gems", gemsAwarded, "RunCompletion:" .. tostring(chapterId))
	CurrencyService.Award(player, "AlienTokens", tokensAwarded, "RunCompletion:" .. tostring(chapterId))

	StatsService.IncrementWins(player, reward.Wins)

	local isNewRecord = false
	if type(elapsedSeconds) == "number" and elapsedSeconds > 0 then
		isNewRecord = StatsService.ReportRunTime(player, elapsedSeconds)
	end

	if feathersCollected > 0 then
		StatsService.AddFeathersCollected(player, feathersCollected)
	end

	DataService.PushProfileUpdated(player)

	local stats = StatsService.GetStats(player)

	return {
		GemsAwarded = actualGemsAwarded or gemsAwarded,
		AlienTokensAwarded = tokensAwarded,
		Wins = stats.Wins,
		IsNewRecord = isNewRecord,
		BestTime = stats.BestTime,
	}
end

function MetaProgressionService.BuyPermanentPerk(player: Player, perkId: string): (boolean, any)
	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end

	local perkConfig = PermanentPerksConfig.Perks[perkId]
	if not perkConfig then
		return false, "InvalidPerk"
	end

	local profile = DataService.GetProfile(player)
	local currentLevel = profile.PermanentPerks[perkId] or 0

	if currentLevel >= PermanentPerksConfig.MaxLevel then
		return false, "MaxLevel"
	end

	if not CurrencyService.TrySpend(player, "Gems", perkConfig.CostPerLevel, "PermanentPerk:" .. perkId) then
		return false, "InsufficientGems"
	end

	profile.PermanentPerks[perkId] = currentLevel + 1
	DataService.PushProfileUpdated(player)

	return true, { PerkId = perkId, NewLevel = currentLevel + 1 }
end

return MetaProgressionService
