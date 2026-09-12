-- Monetization catalog. Every Id below is the real Roblox Developer
-- Product / Game Pass ID (created via Open Cloud). Robux prices mirror
-- what's actually configured on the product/pass itself, kept here for
-- reference/documentation -- the authoritative price is whatever Roblox
-- has on file for the Id.

local MonetizationConfig = {}

-- Kind = "Gems"           -> awards Amount Gems directly (CurrencyService.Award)
-- Kind = "RunProduct"     -> invokes the callback registered via
--                            MonetizationService.RegisterRunProductGrant(ProductKey, ...)
--                            (the Gameplay agent owns granting the actual run effect).
--                            ProductKey must match a RunConfig.ONE_ROUND_PRODUCT_KEYS
--                            value -- that's what ToolService.Init() actually registers.
-- Kind = "ChestMultiOpen" -> opens ChestCount Alien Chests at no Token cost
--
-- Permanent tool/perk unlocks are NOT Developer Products -- Roblox never
-- sends a receipt for a Game Pass purchase, so a permanent unlock can only
-- ever be resolved by checking live Game Pass ownership (see GamePasses
-- below and MonetizationService.OwnsEntitlement).
MonetizationConfig.DeveloperProducts = {
	Gems100 = { Id = 3712387142, RobuxPrice = 24, Kind = "Gems", Amount = 100 },
	Gems400 = { Id = 3712387144, RobuxPrice = 72, Kind = "Gems", Amount = 400 },

	PitchforkRound = { Id = 3712387131, RobuxPrice = 16, Kind = "RunProduct", ProductKey = "PitchforkOneRound" },
	DynamiteRound = { Id = 3712387134, RobuxPrice = 24, Kind = "RunProduct", ProductKey = "DynamiteOneRound" },
	VacuumRound = { Id = 3712387136, RobuxPrice = 40, Kind = "RunProduct", ProductKey = "VacuumOneRound" },
	DroneRound = { Id = 3712387138, RobuxPrice = 16, Kind = "RunProduct", ProductKey = "DroneOneRound" },

	-- NEW this milestone (MAJOR GAMEPLAY/WORLD INTEGRATION UPDATE). Id = 0 is
	-- a deliberate placeholder -- do NOT create these via Open Cloud yet; see
	-- the final report for the exact items still needing manual approval.
	FeatherGrabberRound = { Id = 0, RobuxPrice = 16, Kind = "RunProduct", ProductKey = "FeatherGrabberOneRound" },
	TornadoLauncherRound = { Id = 0, RobuxPrice = 64, Kind = "RunProduct", ProductKey = "TornadoLauncherOneRound" },
	PackingBotRound = { Id = 0, RobuxPrice = 40, Kind = "RunProduct", ProductKey = "PackingBotOneRound" },

	AlienChest3 = { Id = 3712387145, RobuxPrice = 72, Kind = "ChestMultiOpen", ChestCount = 3 },
	AlienChest5 = { Id = 3712387148, RobuxPrice = 104, Kind = "ChestMultiOpen", ChestCount = 5 },
	AlienChest10 = { Id = 3712387151, RobuxPrice = 184, Kind = "ChestMultiOpen", ChestCount = 10 },
}

-- Permanent, one-time ownership purchases. Never processed via
-- ProcessReceipt -- ownership is resolved live via
-- MarketplaceService:UserOwnsGamePassAsync (see
-- MonetizationService.OwnsGamePass / OwnsEntitlement). EntitlementKey is
-- the key every other system (RunConfig.ENTITLEMENTS, ToolService,
-- RunPlayerStateService, MetaProgressionService, client
-- MonetizationController.ownsEntitlement) already reads/writes -- unchanged
-- by this catalog mapping.
MonetizationConfig.GamePasses = {
	InfiniteBagPermanent = { Id = 1978778684, RobuxPrice = 16, EntitlementKey = "InfiniteBag" },
	PitchforkPermanent = { Id = 1978832709, RobuxPrice = 80, EntitlementKey = "PitchforkPermanent" },
	DynamitePermanent = { Id = 1979624607, RobuxPrice = 120, EntitlementKey = "DynamitePermanent" },
	VacuumPermanent = { Id = 1978760699, RobuxPrice = 160, EntitlementKey = "VacuumPermanent" },
	DronePermanent = { Id = 1979624608, RobuxPrice = 104, EntitlementKey = "DronePermanent" },
	Gems2xPermanent = { Id = 1977380893, RobuxPrice = 160, EntitlementKey = "Gems2xPermanent" },
	ClassLuck2x = { Id = 1979546654, RobuxPrice = 160, EntitlementKey = "ClassLuck2x" },
	FastRolls = { Id = 1980020399, RobuxPrice = 144, EntitlementKey = "FastRolls" },
	ExtraClassSlot = { Id = 1976402936, RobuxPrice = 96, EntitlementKey = "ExtraClassSlot" },

	-- NEW this milestone. Id = 0 placeholder -- see FeatherGrabberRound above.
	FeatherGrabberPermanent = { Id = 0, RobuxPrice = 80, EntitlementKey = "FeatherGrabberPermanent" },
	TornadoLauncherPermanent = { Id = 0, RobuxPrice = 224, EntitlementKey = "TornadoLauncherPermanent" },
	PackingBotPermanent = { Id = 0, RobuxPrice = 144, EntitlementKey = "PackingBotPermanent" },
}

-- Gem-alternative price for a Drone round, per GDD ("40 Gems alternative").
MonetizationConfig.DroneRoundGemPrice = 40

return table.freeze(MonetizationConfig)
