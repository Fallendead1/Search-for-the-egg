local PitchforkConfig = {}

PitchforkConfig.UNLOCK_COST_CENTS = 800
PitchforkConfig.ONE_ROUND_ROBUX = 16
PitchforkConfig.PERMANENT_ROBUX = 80

PitchforkConfig.MAX_LEVEL = 5

PitchforkConfig.AMOUNT_LEVELS = {
	[0] = { Value = 8, CostCents = 0 },
	[1] = { Value = 10, CostCents = 200 },
	[2] = { Value = 12, CostCents = 400 },
	[3] = { Value = 14, CostCents = 600 },
	[4] = { Value = 16, CostCents = 800 },
	[5] = { Value = 18, CostCents = 1000 },
}

PitchforkConfig.SPEED_LEVELS = {
	[0] = { IntervalSeconds = 1.80, CostCents = 0 },
	[1] = { IntervalSeconds = 1.60, CostCents = 200 },
	[2] = { IntervalSeconds = 1.40, CostCents = 400 },
	[3] = { IntervalSeconds = 1.20, CostCents = 600 },
	[4] = { IntervalSeconds = 1.00, CostCents = 800 },
	[5] = { IntervalSeconds = 0.80, CostCents = 1000 },
}

PitchforkConfig.DIG_DEPTH_LEVELS = {
	[0] = { Multiplier = 1.00, CostCents = 0 },
	[1] = { Multiplier = 1.15, CostCents = 200 },
	[2] = { Multiplier = 1.30, CostCents = 400 },
	[3] = { Multiplier = 1.45, CostCents = 600 },
	[4] = { Multiplier = 1.60, CostCents = 800 },
	[5] = { Multiplier = 1.75, CostCents = 1000 },
}

-- Forkmaster class perk.
PitchforkConfig.FORKMASTER_YIELD_BONUS = 0.25
PitchforkConfig.FORKMASTER_COST_MULTIPLIER = 0.75

return PitchforkConfig
