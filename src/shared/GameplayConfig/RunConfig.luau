-- Global gameplay tuning shared across all Chapter runs.
-- Values marked TUNING_REQUIRED were not specified in the design doc; conservative
-- rare defaults are used until design provides exact numbers.

local RunConfig = {}

RunConfig.PARTY_MAX_SIZE = 4

-- Feather economy (integer cents to avoid float drift).
RunConfig.FEATHER_VALUE_CENTS = 1
RunConfig.RAINBOW_FEATHER_VALUE_CENTS = 5

-- Chance a naturally-collected unit surfaces as a Rainbow Feather instead of normal.
RunConfig.RAINBOW_SPAWN_CHANCE = 0.015 -- TUNING_REQUIRED

-- Golden Harvest (Ultimate Farmer class ability).
RunConfig.GOLDEN_HARVEST = {
	CHECK_INTERVAL_SECONDS = 30, -- TUNING_REQUIRED
	TRIGGER_CHANCE = 0.10, -- TUNING_REQUIRED, rolled every CHECK_INTERVAL_SECONDS
	DURATION_SECONDS = 10,
	SELL_MULTIPLIER = 2,
}

-- Persistent Gem "Diamond" discovery while harvesting (Prospector improves this).
RunConfig.DIAMOND = {
	BASE_CHANCE = 0.0006, -- TUNING_REQUIRED, per logical unit removed
	PROSPECTOR_CHANCE_MULTIPLIER = 3, -- TUNING_REQUIRED
	GEM_REWARD_MIN = 1,
	GEM_REWARD_MAX = 3,
}

-- Rare Alien Token drops during harvesting (kept far below the 100-token chest cost).
RunConfig.ALIEN_TOKEN_DROP = {
	BASE_CHANCE = 0.0008, -- TUNING_REQUIRED, per logical unit removed
	REWARD_AMOUNT = 1,
}

-- Range validation (studs).
RunConfig.RANGE = {
	COLLECTION = 12,
	PITCHFORK = 12,
	DYNAMITE_THROW = 45,
	VACUUM = 16,
	EGG_PICKUP = 8,
	FARMER_TURN_IN = 9,
	SELL_STATION = 10,
	RED_BUTTON = 8,
	FEATHER_GRABBER = 12,
	TORNADO_LAUNCHER = 18,
}

RunConfig.COLLECTION_COOLDOWN_GRACE_SECONDS = 0.05

-- Difficulty configuration. Egg depth is expressed as a fraction (0-1) of a
-- column's max fill that must remain buried before the Egg can be revealed.
-- Completion reward AMOUNTS are not duplicated here -- MetaConfig/
-- RewardConfig.Chapters is the one place RewardService/MetaProgressionService
-- (and DisplayConfig, for the client) read them from.
RunConfig.DIFFICULTY = {
	Normal = {
		Id = "Normal",
		RequiresWins = 0,
		PileScale = 1.0,
		ColumnDepthMin = 6,
		ColumnDepthMax = 10,
		EggMinDepthFraction = 0.45,
		EggMaxDepthFraction = 0.85,
	},
	Hard = {
		Id = "Hard",
		RequiresWins = 1,
		PileScale = 1.5,
		ColumnDepthMin = 9,
		ColumnDepthMax = 15,
		EggMinDepthFraction = 0.65,
		EggMaxDepthFraction = 0.95,
	},
}

RunConfig.DIFFICULTY_ORDER = { "Normal", "Hard" }

-- Chapter 2 is referenced by the unlock-gate design but has no gameplay yet.
RunConfig.CHAPTERS = {
	Chapter1 = { Id = "Chapter1", RequiresWins = 0, Enabled = true },
	Chapter2 = { Id = "Chapter2", RequiresWins = 1, Enabled = false },
}

-- Feather pile grid (see FeatherPileService for usage).
RunConfig.PILE = {
	COLUMN_SIZE_STUDS = 4,
	GRID_RADIUS_COLUMNS = 16, -- produces a (2r+1) x (2r+1) column grid
}

-- MonetizationService:OwnsEntitlement() keys for permanent tool ownership /
-- perks. Exact key strings weren't specified by design; centralized here so
-- there's one place to reconcile with Agent 1's actual entitlement catalog.
RunConfig.ENTITLEMENTS = {
	PitchforkPermanent = "PitchforkPermanent",
	DynamitePermanent = "DynamitePermanent",
	VacuumPermanent = "VacuumPermanent",
	DronePermanent = "DronePermanent",
	InfiniteBag = "InfiniteBag",
	FeatherGrabberPermanent = "FeatherGrabberPermanent",
	TornadoLauncherPermanent = "TornadoLauncherPermanent",
	PackingBotPermanent = "PackingBotPermanent",
}

-- MonetizationService:RegisterRunProductGrant() keys, as named explicitly in
-- the design doc.
RunConfig.ONE_ROUND_PRODUCT_KEYS = {
	Pitchfork = "PitchforkOneRound",
	Dynamite = "DynamiteOneRound",
	Vacuum = "VacuumOneRound",
	Drone = "DroneOneRound",
	FeatherGrabber = "FeatherGrabberOneRound",
	TornadoLauncher = "TornadoLauncherOneRound",
	PackingBot = "PackingBotOneRound",
}

-- UFO secret red button easter egg.
RunConfig.UFO_SECRET = {
	FLIGHT_DURATION_SECONDS = 6,
	BEAM_DURATION_SECONDS = 2,
}

-- CollectionService tags used to discover Studio-built map objects without
-- hardcoding Workspace paths. If a tagged instance isn't found, services fall
-- back to a safe default and warn once, rather than erroring.
RunConfig.TAGS = {
	PileOrigin = "SFTE_PileOrigin",
	SellStation = "SFTE_SellStation",
	Farmer = "SFTE_Farmer",
	RedButton = "SFTE_RedButton",
	Chicken = "SFTE_Chicken",
	SafeEggFallback = "SFTE_EggFallbackSpot",
	-- Where a party's characters are moved when their run actually starts
	-- (see RoundService.startRunNow) -- the local same-server fallback has
	-- no other way to get a player from the Lobby into the gameplay map.
	ChapterSpawn = "SFTE_ChapterSpawn",
	-- Lobby world hookups (see PartyPadService / client BagCounterController).
	PartyPad = "SFTE_PartyPad",
	BagUpgradeCounter = "SFTE_BagUpgradeCounter",
	-- Physical Lobby NPC stands (see client LobbyPromptController).
	ShopCounter = "SFTE_ShopCounter",
	ClassCounter = "SFTE_ClassCounter",
	-- Map2 conveyor sell system (see ConveyorSellService/ConveyorVisualController).
	-- The deposit point is ALSO tagged SellStation above -- SellService's
	-- existing atomic bag->cash flow is reused unchanged; these two tags only
	-- tell the client where to render the crate/chicken cosmetics.
	ConveyorDeposit = "SFTE_ConveyorDeposit",
	ConveyorOutput = "SFTE_ConveyorOutput",
}

return RunConfig
