-- Chapter/difficulty completion reward table. RewardService reads this;
-- MetaProgressionService.AwardRunCompletion is the only place these values
-- are ever applied to a profile.

local RewardConfig = {}

RewardConfig.Chapters = {
	Chapter1 = {
		Normal = { Wins = 1, Gems = 40, AlienTokens = 10 },
		Hard = { Wins = 1, Gems = 60, AlienTokens = 20 },
	},
}

return table.freeze(RewardConfig)
