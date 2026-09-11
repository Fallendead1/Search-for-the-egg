local VacuumConfig = {}

-- No Cash unlock price was specified for the Vacuum (Pitchfork/Dynamite both have
-- one; Vacuum only lists Robux prices). Treat it as Robux-only until design says
-- otherwise.
VacuumConfig.UNLOCK_COST_CENTS = nil -- TUNING_REQUIRED (Robux-only unlock assumed)
VacuumConfig.ONE_ROUND_ROBUX = 40
VacuumConfig.PERMANENT_ROBUX = 160

VacuumConfig.MAX_LEVEL = 5

VacuumConfig.CENTRAL_TICK_SECONDS = 0.2
VacuumConfig.STATE_REPLICATION_INTERVAL_SECONDS = 0.5

VacuumConfig.POWER_LEVELS = {
	[0] = { FeathersPerSecond = 5, CostCents = 0 },
	[1] = { FeathersPerSecond = 8, CostCents = 500 },
	[2] = { FeathersPerSecond = 11, CostCents = 1000 },
	[3] = { FeathersPerSecond = 14, CostCents = 1500 },
	[4] = { FeathersPerSecond = 17, CostCents = 2000 },
	[5] = { FeathersPerSecond = 20, CostCents = 2500 },
}

VacuumConfig.COOLING_LEVELS = {
	[0] = { RecoverySeconds = 8, CostCents = 0 },
	[1] = { RecoverySeconds = 7, CostCents = 500 },
	[2] = { RecoverySeconds = 6, CostCents = 1000 },
	[3] = { RecoverySeconds = 5, CostCents = 1500 },
	[4] = { RecoverySeconds = 4, CostCents = 2000 },
	[5] = { RecoverySeconds = 3, CostCents = 2500 },
}

VacuumConfig.RUNTIME_LEVELS = {
	[0] = { RuntimeSeconds = 4, CostCents = 0 },
	[1] = { RuntimeSeconds = 5, CostCents = 500 },
	[2] = { RuntimeSeconds = 6, CostCents = 1000 },
	[3] = { RuntimeSeconds = 7, CostCents = 1500 },
	[4] = { RuntimeSeconds = 8, CostCents = 2000 },
	[5] = { RuntimeSeconds = 10, CostCents = 2500 },
}

return VacuumConfig
