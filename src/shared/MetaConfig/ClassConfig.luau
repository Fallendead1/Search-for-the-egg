-- Class system configuration: roll cost/odds and per-class passive
-- modifiers. Base odds here are canonical and must always total 100 -- luck
-- entitlements are applied as a reweighting transform inside ClassService,
-- never by editing these numbers.

local ClassConfig = {}

ClassConfig.RollCostGems = 40

ClassConfig.BaseRollCooldownSeconds = 1.5
ClassConfig.FastRollCooldownSeconds = 0.5

-- Sums to exactly 100.
ClassConfig.Odds = {
	{ Id = "Starter", Weight = 40 },
	{ Id = "PackMule", Weight = 25 },
	{ Id = "FeatherMerchant", Weight = 14 },
	{ Id = "Forkmaster", Weight = 9 },
	{ Id = "Demolitionist", Weight = 7 },
	{ Id = "Prospector", Weight = 3.9 },
	{ Id = "DroneSpecialist", Weight = 1 },
	{ Id = "UltimateFarmer", Weight = 0.1 },
}

-- Per-class passive modifiers, combined by
-- MetaProgressionService.GetGameplayModifiers via ClassService's
-- GetEffectiveClassModifiers. Fields left unset default to "no effect" in
-- ClassService's accumulator.
ClassConfig.Classes = {
	Starter = {
		DisplayName = "Starter",
	},

	PackMule = {
		DisplayName = "Pack Mule",
		BagCapacityMultiplier = 1.5,
	},

	FeatherMerchant = {
		DisplayName = "Feather Merchant",
		SaleMultiplier = 1.2,
	},

	Forkmaster = {
		DisplayName = "Forkmaster",
		PitchforkYieldMultiplier = 1.25,
		PitchforkUpgradeCostMultiplier = 0.75,
	},

	Demolitionist = {
		DisplayName = "Demolitionist",
		DynamiteRadiusMultiplier = 1.2,
		DynamiteMiniChargeChance = 0.1,
	},

	Prospector = {
		DisplayName = "Prospector",
		ProspectorEnabled = true,
	},

	DroneSpecialist = {
		DisplayName = "Drone Specialist",
		DroneAlwaysOwned = true,
		DroneSpeedMultiplier = 1.3,
		DroneCapacityMultiplier = 1.4,
		-- Not numerically specified by the GDD ("chance to invoke a swarm");
		-- configurable placeholder for balancing.
		DroneSwarmChance = 0.05,
	},

	UltimateFarmer = {
		DisplayName = "Ultimate Farmer",
		UltimateFarmer = true,
		GoldenHarvestEnabled = true,
		-- Not numerically specified by the GDD ("can randomly activate");
		-- configurable placeholder for balancing.
		GoldenHarvestChance = 0.05,
	},
}

ClassConfig.GoldenHarvestDurationSeconds = 10
ClassConfig.GoldenHarvestSaleMultiplier = 2

-- 2x Class Luck reweighting: any class with base weight <= this threshold has
-- its weight multiplied by LuckMultiplier before the roll, then all weights
-- are renormalized. Keeps ClassConfig.Odds itself untouched.
ClassConfig.LuckWeightThreshold = 10
ClassConfig.LuckMultiplier = 2

return table.freeze(ClassConfig)
