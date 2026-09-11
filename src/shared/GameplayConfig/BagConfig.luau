local BagConfig = {}

BagConfig.MAX_LEVEL = 5
BagConfig.MAX_NORMAL_CAPACITY = 250

-- index 0 = base tier (no cost)
BagConfig.LEVELS = {
	[0] = { Capacity = 25, CostCents = 0 },
	[1] = { Capacity = 50, CostCents = 100 },
	[2] = { Capacity = 100, CostCents = 250 },
	[3] = { Capacity = 150, CostCents = 500 },
	[4] = { Capacity = 200, CostCents = 750 },
	[5] = { Capacity = 250, CostCents = 1000 },
}

-- Class/permanent modifiers applied on top of the level capacity.
BagConfig.PACK_MULE_CAPACITY_MULTIPLIER = 1.5

return BagConfig
