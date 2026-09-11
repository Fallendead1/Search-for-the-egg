-- Monetization catalog. NO real Roblox asset IDs are known yet -- every Id
-- below is a placeholder (0) and MUST be filled in with real Developer
-- Product / Game Pass IDs (created on roblox.com) before MonetizationService
-- can process real receipts. Robux prices are copied from the GDD for
-- reference/documentation only; the authoritative price is whatever is
-- configured on the product/pass itself.

local MonetizationConfig = {}

-- Kind = "Gems"           -> awards Amount Gems directly (CurrencyService.Award)
-- Kind = "Entitlement"    -> grants a permanent Entitlements[EntitlementKey] = true
-- Kind = "RunProduct"     -> invokes the callback registered via
--                            MonetizationService.RegisterRunProductGrant(ProductKey, ...)
--                            (the Gameplay agent owns granting the actual run effect)
-- Kind = "ChestMultiOpen" -> opens ChestCount Alien Chests at no Token cost
MonetizationConfig.DeveloperProducts = {
	Gems100 = { Id = 0, RobuxPrice = 24, Kind = "Gems", Amount = 100 },
	Gems400 = { Id = 0, RobuxPrice = 56, Kind = "Gems", Amount = 400 },

	FastRolls = { Id = 0, RobuxPrice = 144, Kind = "Entitlement", EntitlementKey = "FastRolls" },
	ClassLuck2x = { Id = 0, RobuxPrice = 160, Kind = "Entitlement", EntitlementKey = "ClassLuck2x" },
	ExtraClassSlot = { Id = 0, RobuxPrice = 96, Kind = "Entitlement", EntitlementKey = "ExtraClassSlot" },

	InfiniteBagRound = { Id = 0, RobuxPrice = 16, Kind = "RunProduct", ProductKey = "InfiniteBagRound" },
	-- Permanent Infinite Bag. Reuses InfiniteBagRound's existing GDD Robux
	-- price (16) rather than inventing a new one -- the authoritative price
	-- is whatever is configured on the product itself once Id is filled in.
	InfiniteBagPermanent = { Id = 0, RobuxPrice = 16, Kind = "Entitlement", EntitlementKey = "InfiniteBag" },

	PitchforkRound = { Id = 0, RobuxPrice = 16, Kind = "RunProduct", ProductKey = "PitchforkRound" },
	PitchforkPermanent = { Id = 0, RobuxPrice = 80, Kind = "Entitlement", EntitlementKey = "PitchforkPermanent" },

	DynamiteRound = { Id = 0, RobuxPrice = 24, Kind = "RunProduct", ProductKey = "DynamiteRound" },
	DynamitePermanent = { Id = 0, RobuxPrice = 120, Kind = "Entitlement", EntitlementKey = "DynamitePermanent" },

	VacuumRound = { Id = 0, RobuxPrice = 40, Kind = "RunProduct", ProductKey = "VacuumRound" },
	-- Price not specified in the GDD; left nil until supplied.
	VacuumPermanent = { Id = 0, RobuxPrice = nil, Kind = "Entitlement", EntitlementKey = "VacuumPermanent" },

	DroneRound = { Id = 0, RobuxPrice = 16, Kind = "RunProduct", ProductKey = "DroneRound" },
	DronePermanent = { Id = 0, RobuxPrice = 104, Kind = "Entitlement", EntitlementKey = "DronePermanent" },

	AlienChest3 = { Id = 0, RobuxPrice = 72, Kind = "ChestMultiOpen", ChestCount = 3 },
	AlienChest5 = { Id = 0, RobuxPrice = 104, Kind = "ChestMultiOpen", ChestCount = 5 },
	AlienChest10 = { Id = 0, RobuxPrice = 184, Kind = "ChestMultiOpen", ChestCount = 10 },
}

MonetizationConfig.GamePasses = {
	Gems2xPermanent = { Id = 0, RobuxPrice = 64, EntitlementKey = "Gems2xPermanent" },
}

-- Gem-alternative price for a Drone round, per GDD ("40 Gems alternative").
MonetizationConfig.DroneRoundGemPrice = 40

return table.freeze(MonetizationConfig)
