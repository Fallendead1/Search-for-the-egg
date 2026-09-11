-- Hand tool stats/costs. Level 0 is the free base tier; levels are cumulative
-- (buying level N requires already owning level N-1).

local HandConfig = {}

HandConfig.BASE_AMOUNT = 1
HandConfig.BASE_INTERVAL_SECONDS = 0.55

HandConfig.HOLD_UNLOCK_COST_CENTS = 100

HandConfig.MAX_LEVEL = 5

-- index 0 = base tier (no cost)
HandConfig.SPEED_LEVELS = {
	[0] = { IntervalSeconds = 0.55, CostCents = 0 },
	[1] = { IntervalSeconds = 0.50, CostCents = 25 },
	[2] = { IntervalSeconds = 0.45, CostCents = 50 },
	[3] = { IntervalSeconds = 0.40, CostCents = 100 },
	[4] = { IntervalSeconds = 0.35, CostCents = 250 },
	[5] = { IntervalSeconds = 0.30, CostCents = 500 },
}

HandConfig.GRASP_LEVELS = {
	[0] = { Amount = 1, CostCents = 0 },
	[1] = { Amount = 2, CostCents = 25 },
	[2] = { Amount = 3, CostCents = 50 },
	[3] = { Amount = 4, CostCents = 100 },
	[4] = { Amount = 5, CostCents = 250 },
	[5] = { Amount = 6, CostCents = 500 },
}

return HandConfig
