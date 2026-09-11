-- Permanent Gem-shop perk configuration. The GDD specifies cost per level
-- but not effect magnitudes, so magnitudes live entirely here so balancing
-- never requires touching service code.

local PermanentPerksConfig = {}

PermanentPerksConfig.MaxLevel = 5

PermanentPerksConfig.Perks = {
	BagSize = {
		CostPerLevel = 25,
		EffectPerLevel = 25, -- +25 permanent bag capacity per level
	},
	HandGrabAmount = {
		CostPerLevel = 50,
		EffectPerLevel = 1, -- +1 Feather per Hand collection per level
	},
	GemValue = {
		CostPerLevel = 150,
		EffectPerLevel = 0.10, -- +10% Gem rewards per level
	},
	FeatherValue = {
		CostPerLevel = 20,
		EffectPerLevel = 0.10, -- +10% Feather sell value per level
	},
}

return table.freeze(PermanentPerksConfig)
