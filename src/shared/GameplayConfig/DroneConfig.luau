local DroneConfig = {}

DroneConfig.ONE_ROUND_ROBUX = 16
DroneConfig.ONE_ROUND_GEM_COST = 40
DroneConfig.PERMANENT_ROBUX = 104

DroneConfig.MAX_LEVEL = 5

DroneConfig.CENTRAL_TICK_SECONDS = 0.25

-- Base travel/work timings the AI state machine uses; scaled by SpeedMultiplier.
DroneConfig.BASE_TRAVEL_TO_PILE_SECONDS = 3
DroneConfig.BASE_COLLECT_SECONDS = 2.5
DroneConfig.BASE_TRAVEL_TO_SELL_SECONDS = 3
DroneConfig.BASE_SELL_SECONDS = 1

DroneConfig.SPEED_LEVELS = {
	[0] = { Multiplier = 1.0, CostCents = 0 },
	[1] = { Multiplier = 1.2, CostCents = 500 },
	[2] = { Multiplier = 1.4, CostCents = 1000 },
	[3] = { Multiplier = 1.6, CostCents = 1500 },
	[4] = { Multiplier = 1.8, CostCents = 2000 },
	[5] = { Multiplier = 2.0, CostCents = 2500 },
}

DroneConfig.GRASP_LEVELS = {
	[0] = { Amount = 5, CostCents = 0 },
	[1] = { Amount = 10, CostCents = 500 },
	[2] = { Amount = 15, CostCents = 1000 },
	[3] = { Amount = 20, CostCents = 1500 },
	[4] = { Amount = 25, CostCents = 2000 },
	[5] = { Amount = 30, CostCents = 2500 },
}

DroneConfig.CAPACITY_LEVELS = {
	[0] = { Capacity = 25, CostCents = 0 },
	[1] = { Capacity = 50, CostCents = 500 },
	[2] = { Capacity = 75, CostCents = 1000 },
	[3] = { Capacity = 100, CostCents = 1500 },
	[4] = { Capacity = 150, CostCents = 2000 },
	[5] = { Capacity = 200, CostCents = 2500 },
}

-- Drone Specialist class perk.
DroneConfig.SPECIALIST_SPEED_BONUS = 0.30
DroneConfig.SPECIALIST_CAPACITY_BONUS = 0.40
DroneConfig.SPECIALIST_SWARM_CHANCE_PER_CYCLE = 0.08 -- TUNING_REQUIRED
DroneConfig.SPECIALIST_SWARM_COUNT = 3
DroneConfig.SPECIALIST_SWARM_DURATION_SECONDS = 15 -- TUNING_REQUIRED

return DroneConfig
