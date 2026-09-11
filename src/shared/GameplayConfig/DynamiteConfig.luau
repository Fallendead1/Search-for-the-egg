local DynamiteConfig = {}

DynamiteConfig.UNLOCK_COST_CENTS = 2500
DynamiteConfig.ONE_ROUND_ROBUX = 24
DynamiteConfig.PERMANENT_ROBUX = 120

DynamiteConfig.MAX_LEVEL = 5

DynamiteConfig.FUSE_SECONDS = 1.5 -- TUNING_REQUIRED

DynamiteConfig.POWER_LEVELS = {
	[0] = { Radius = 2.40, CostCents = 0 },
	[1] = { Radius = 2.80, CostCents = 500 },
	[2] = { Radius = 3.20, CostCents = 1000 },
	[3] = { Radius = 3.60, CostCents = 1500 },
	[4] = { Radius = 4.00, CostCents = 2000 },
	[5] = { Radius = 4.80, CostCents = 2500 },
}

DynamiteConfig.SPEED_LEVELS = {
	[0] = { CooldownSeconds = 12, CostCents = 0 },
	[1] = { CooldownSeconds = 11.5, CostCents = 500 },
	[2] = { CooldownSeconds = 11, CostCents = 1000 },
	[3] = { CooldownSeconds = 10, CostCents = 1500 },
	[4] = { CooldownSeconds = 9, CostCents = 2000 },
	[5] = { CooldownSeconds = 8.5, CostCents = 2500 },
}

-- Chance (0-1) that an explosion triggers a Lucky Blast conversion.
DynamiteConfig.LUCKY_BLAST_LEVELS = {
	[0] = { Chance = 0.00, CostCents = 0 },
	[1] = { Chance = 0.05, CostCents = 500 },
	[2] = { Chance = 0.10, CostCents = 1000 },
	[3] = { Chance = 0.15, CostCents = 1500 },
	[4] = { Chance = 0.20, CostCents = 2000 },
	[5] = { Chance = 0.25, CostCents = 2500 },
}

-- Fraction of affected units converted to Rainbow Feathers on a successful Lucky Blast.
DynamiteConfig.LUCKY_BLAST_CONVERSION_FRACTION = 0.5 -- TUNING_REQUIRED

-- Demolitionist class perk.
DynamiteConfig.DEMOLITIONIST_RADIUS_BONUS = 0.20
DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_CHANCE = 0.10
DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_COUNT = 3
DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_RADIUS_MULTIPLIER = 0.4 -- TUNING_REQUIRED
DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_SCATTER_STUDS = 6 -- TUNING_REQUIRED

return DynamiteConfig
