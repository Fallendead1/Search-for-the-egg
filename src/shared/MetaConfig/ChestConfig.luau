-- Alien Chest configuration: Alien Token cost and reward table. Weights sum
-- to exactly 100.

local ChestConfig = {}

ChestConfig.TokenCost = 100

ChestConfig.Rewards = {
	{ Id = "GemsSmall", Type = "Gems", Weight = 60, Min = 25, Max = 75 },
	{ Id = "GemsLarge", Type = "Gems", Weight = 25, Min = 75, Max = 200 },
	{ Id = "AlienDynamite", Type = "Skin", Category = "Dynamite", SkinId = "AlienDynamite", Weight = 7 },
	{ Id = "AlienVacuum", Type = "Skin", Category = "Vacuum", SkinId = "AlienVacuum", Weight = 4.5 },
	{ Id = "AlienSquidfork", Type = "Skin", Category = "Pitchfork", SkinId = "AlienSquidfork", Weight = 2.5 },
	{ Id = "UFO", Type = "Skin", Category = "Drone", SkinId = "UFO", Weight = 1 },
}

-- Robux multi-open sizes; actual purchase handling lives in
-- MonetizationConfig.DeveloperProducts (Kind = "ChestMultiOpen").
ChestConfig.MultiOpenSizes = { 3, 5, 10 }

-- Sane ceiling for a single token-funded open request (see
-- ChestService.OpenWithTokens) to bound reward-array size/spam.
ChestConfig.MaxTokenOpenCount = 10

return table.freeze(ChestConfig)
