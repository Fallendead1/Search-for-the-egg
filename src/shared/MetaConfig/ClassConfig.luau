-- Class system configuration: roll cost/odds and per-class passive
-- modifiers. Base odds here are canonical and must always total 100 -- luck
-- entitlements are applied as a reweighting transform inside ClassService,
-- never by editing these numbers.

local ClassConfig = {}

ClassConfig.RollCostGems = 40

ClassConfig.BaseRollCooldownSeconds = 1.5
ClassConfig.FastRollCooldownSeconds = 0.5

-- Sums to exactly 100. Weights match the final class-card art's baked odds
-- text exactly (see AssetConfig.ClassCards) -- ids/DisplayNames below were
-- updated to match that art too, so nothing here can drift out of sync with
-- what the image already shows.
ClassConfig.Odds = {
	{ Id = "Starter", Weight = 35 },
	{ Id = "PackMule", Weight = 25 },
	{ Id = "FeatherMerchant", Weight = 16 },
	{ Id = "Forkmaster", Weight = 11 },
	{ Id = "Demolitionist", Weight = 7 },
	{ Id = "Prospector", Weight = 4 },
	{ Id = "DroneSpecialist", Weight = 1.7 },
	{ Id = "UltimateFarmer", Weight = 0.3 },
}

-- Per-class passive modifiers, combined by
-- MetaProgressionService.GetGameplayModifiers via ClassService's
-- GetEffectiveClassModifiers. Fields left unset default to "no effect" in
-- ClassService's accumulator.
-- DisplayName is the only thing the final art pass changed here -- every
-- mechanical field (multipliers, flags) is untouched so backend/gameplay
-- logic stays exactly as it was, except the two bag/sale numbers below,
-- which were nudged to match the new card art's baked percentages exactly
-- (35%/25% Bag Capacity -- was 50% -- and 25% Feather Sell Value -- was
-- 20%) rather than leaving a number mismatch between the image and the
-- real modifier.
ClassConfig.Classes = {
	Starter = {
		DisplayName = "Nestling",
	},

	PackMule = {
		DisplayName = "Feather Hauler",
		BagCapacityMultiplier = 1.35,
	},

	FeatherMerchant = {
		DisplayName = "Coop Trader",
		SaleMultiplier = 1.25,
	},

	Forkmaster = {
		DisplayName = "Pile Raker",
		PitchforkYieldMultiplier = 1.25,
		PitchforkUpgradeCostMultiplier = 0.75,
	},

	Demolitionist = {
		DisplayName = "Blast Keeper",
		DynamiteRadiusMultiplier = 1.2,
		DynamiteMiniChargeChance = 0.1,
	},

	Prospector = {
		DisplayName = "Gem Rooster",
		ProspectorEnabled = true,
	},

	DroneSpecialist = {
		DisplayName = "Storm Builder",
		DroneAlwaysOwned = true,
		DroneSpeedMultiplier = 1.3,
		DroneCapacityMultiplier = 1.4,
		-- Not numerically specified by the GDD ("chance to invoke a swarm");
		-- configurable placeholder for balancing.
		DroneSwarmChance = 0.05,
	},

	UltimateFarmer = {
		DisplayName = "Egg Oracle",
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
-- are renormalized. Keeps ClassConfig.Odds itself untouched. 11 (not 10) so
-- Pile Raker (Forkmaster, weight 11 after the final-art odds update) still
-- qualifies -- the original design doubled exactly the 5 non-starter/
-- non-bag/non-sale classes, and this keeps that same set covered.
ClassConfig.LuckWeightThreshold = 11
ClassConfig.LuckMultiplier = 2

return table.freeze(ClassConfig)
