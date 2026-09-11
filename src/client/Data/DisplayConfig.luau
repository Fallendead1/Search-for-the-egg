--!strict
-- Presentation-only data for the Upgrade Book, Shop, Class, and Chest UIs.
--
-- These numbers mirror the game design doc so screens can render correctly
-- before the shared config modules exist. If Agent 1/3 publish
-- ReplicatedStorage.SearchForTheEgg.GameplayConfig / MetaConfig /
-- MonetizationConfig, this module prefers their values -- this file is
-- display copy only and never the source of truth for what the server
-- will actually charge or grant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DisplayConfig = {}

local function tryRequireShared(moduleName: string): any?
	local root = ReplicatedStorage:FindFirstChild("SearchForTheEgg")
	if not root then
		return nil
	end
	local mod = root:FindFirstChild(moduleName)
	if not mod or not mod:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, mod)
	if ok then
		return result
	end
	warn(("[DisplayConfig] Failed to require shared module '%s': %s"):format(moduleName, tostring(result)))
	return nil
end

DisplayConfig.GameplayConfig = tryRequireShared("GameplayConfig")
DisplayConfig.MetaConfig = tryRequireShared("MetaConfig")
DisplayConfig.MonetizationConfig = tryRequireShared("MonetizationConfig")

-- ============================================================
-- Bag capacity progression (barn counter upgrade, presented by client)
-- ============================================================
DisplayConfig.Bag = {
	Base = 25,
	Levels = {
		{ Level = 1, Capacity = 50, Cost = 1.00 },
		{ Level = 2, Capacity = 100, Cost = 2.50 },
		{ Level = 3, Capacity = 150, Cost = 5.00 },
		{ Level = 4, Capacity = 200, Cost = 7.50 },
		{ Level = 5, Capacity = 250, Cost = 10.00 },
	},
	MaxCapacity = 250,
	InfiniteBagRobux = 16,
}

-- ============================================================
-- HAND
-- ============================================================
DisplayConfig.Hand = {
	Hold = { Cost = 1.00, Description = "Hold to collect feathers continuously." },
	Speed = {
		Base = 0.55,
		Description = "Collect feathers faster.",
		Levels = {
			{ Level = 1, Value = 0.50, Cost = 0.25 },
			{ Level = 2, Value = 0.45, Cost = 0.50 },
			{ Level = 3, Value = 0.40, Cost = 1.00 },
			{ Level = 4, Value = 0.35, Cost = 2.50 },
			{ Level = 5, Value = 0.30, Cost = 5.00 },
		},
	},
	Grasp = {
		Base = 1,
		Description = "Collect more feathers at once.",
		Levels = {
			{ Level = 1, Value = 2, Cost = 0.25 },
			{ Level = 2, Value = 3, Cost = 0.50 },
			{ Level = 3, Value = 4, Cost = 1.00 },
			{ Level = 4, Value = 5, Cost = 2.50 },
			{ Level = 5, Value = 6, Cost = 5.00 },
		},
	},
}

-- ============================================================
-- PITCHFORK
-- ============================================================
DisplayConfig.Pitchfork = {
	CashCost = 8.00,
	OneRoundRobux = 16,
	PermanentRobux = 80,
	Description = "Stab the pile and haul out a whole forkful at once.",
	Identity = "Slower than hand. Removes much more. Digs deeper.",
	Sweep = {
		Base = 8,
		Levels = {
			{ Level = 1, Value = 10, Cost = 2 },
			{ Level = 2, Value = 12, Cost = 4 },
			{ Level = 3, Value = 14, Cost = 6 },
			{ Level = 4, Value = 16, Cost = 8 },
			{ Level = 5, Value = 18, Cost = 10 },
		},
	},
	Speed = {
		Base = 1.80,
		Levels = {
			{ Level = 1, Value = 1.60, Cost = 2 },
			{ Level = 2, Value = 1.40, Cost = 4 },
			{ Level = 3, Value = 1.20, Cost = 6 },
			{ Level = 4, Value = 1.00, Cost = 8 },
			{ Level = 5, Value = 0.80, Cost = 10 },
		},
	},
	Dig = {
		Base = 1.00,
		Levels = {
			{ Level = 1, Value = 1.15, Cost = 2 },
			{ Level = 2, Value = 1.30, Cost = 4 },
			{ Level = 3, Value = 1.45, Cost = 6 },
			{ Level = 4, Value = 1.60, Cost = 8 },
			{ Level = 5, Value = 1.75, Cost = 10 },
		},
	},
}

-- ============================================================
-- DYNAMITE
-- ============================================================
DisplayConfig.Dynamite = {
	CashCost = 25.00,
	OneRoundRobux = 24,
	PermanentRobux = 120,
	Description = "Blow a crater straight through the feather pile.",
	Power = {
		Base = 2.40,
		Levels = {
			{ Level = 1, Value = 2.80, Cost = 5 },
			{ Level = 2, Value = 3.20, Cost = 10 },
			{ Level = 3, Value = 3.60, Cost = 15 },
			{ Level = 4, Value = 4.00, Cost = 20 },
			{ Level = 5, Value = 4.80, Cost = 25 },
		},
	},
	Speed = {
		Base = 12,
		Levels = {
			{ Level = 1, Value = 11.5, Cost = 5 },
			{ Level = 2, Value = 11, Cost = 10 },
			{ Level = 3, Value = 10, Cost = 15 },
			{ Level = 4, Value = 9, Cost = 20 },
			{ Level = 5, Value = 8.5, Cost = 25 },
		},
	},
	LuckyBlast = {
		Base = 0,
		Levels = {
			{ Level = 1, Value = 0.05, Cost = 5 },
			{ Level = 2, Value = 0.10, Cost = 10 },
			{ Level = 3, Value = 0.15, Cost = 15 },
			{ Level = 4, Value = 0.20, Cost = 20 },
			{ Level = 5, Value = 0.25, Cost = 25 },
		},
	},
}

-- ============================================================
-- VACUUM
-- ============================================================
DisplayConfig.Vacuum = {
	OneRoundRobux = 40,
	Power = {
		Base = 5,
		Levels = {
			{ Level = 1, Value = 8, Cost = 5 },
			{ Level = 2, Value = 11, Cost = 10 },
			{ Level = 3, Value = 14, Cost = 15 },
			{ Level = 4, Value = 17, Cost = 20 },
			{ Level = 5, Value = 20, Cost = 25 },
		},
	},
	Cooling = {
		Base = 8,
		Levels = {
			{ Level = 1, Value = 7, Cost = 5 },
			{ Level = 2, Value = 6, Cost = 10 },
			{ Level = 3, Value = 5, Cost = 15 },
			{ Level = 4, Value = 4, Cost = 20 },
			{ Level = 5, Value = 3, Cost = 25 },
		},
	},
	Runtime = {
		Base = 4,
		Levels = {
			{ Level = 1, Value = 5, Cost = 5 },
			{ Level = 2, Value = 6, Cost = 10 },
			{ Level = 3, Value = 7, Cost = 15 },
			{ Level = 4, Value = 8, Cost = 20 },
			{ Level = 5, Value = 10, Cost = 25 },
		},
	},
}

-- ============================================================
-- DRONE
-- ============================================================
DisplayConfig.Drone = {
	OneRoundRobux = 16,
	GemsCost = 40,
	PermanentRobux = 104,
	Description = "Your automatic helper.",
	Speed = {
		Base = 1.0,
		Levels = {
			{ Level = 1, Value = 1.2, Cost = 5 },
			{ Level = 2, Value = 1.4, Cost = 10 },
			{ Level = 3, Value = 1.6, Cost = 15 },
			{ Level = 4, Value = 1.8, Cost = 20 },
			{ Level = 5, Value = 2.0, Cost = 25 },
		},
	},
	Grasp = {
		Base = 5,
		Levels = {
			{ Level = 1, Value = 10, Cost = 5 },
			{ Level = 2, Value = 15, Cost = 10 },
			{ Level = 3, Value = 20, Cost = 15 },
			{ Level = 4, Value = 25, Cost = 20 },
			{ Level = 5, Value = 30, Cost = 25 },
		},
	},
	Capacity = {
		Base = 25,
		Levels = {
			{ Level = 1, Value = 50, Cost = 5 },
			{ Level = 2, Value = 75, Cost = 10 },
			{ Level = 3, Value = 100, Cost = 15 },
			{ Level = 4, Value = 150, Cost = 20 },
			{ Level = 5, Value = 200, Cost = 25 },
		},
	},
}

-- ============================================================
-- PERMANENT GEM SHOP
-- ============================================================
DisplayConfig.PermanentPerks = {
	{ Id = "BagSize", Name = "BAG SIZE", GemCost = 25 },
	{ Id = "HandGrab", Name = "HAND GRAB AMOUNT", GemCost = 50 },
	{ Id = "GemValue", Name = "GEM VALUE", GemCost = 150 },
	{ Id = "FeatherValue", Name = "FEATHER VALUE", GemCost = 20 },
}

DisplayConfig.GemPacks = {
	{ Id = "Gems100", Gems = 100, Robux = 24 },
	{ Id = "Gems400", Gems = 400, Robux = 56 },
}
DisplayConfig.DoubleGemsRobux = 64

-- ============================================================
-- CLASSES
-- ============================================================
DisplayConfig.Classes = {
	{ Id = "Starter", Name = "Starter", Odds = 40.0, Description = "No bonuses. Every farmer starts somewhere." },
	{ Id = "PackMule", Name = "Pack Mule", Odds = 25.0, Description = "Carry 50% more feathers in every bag." },
	{ Id = "FeatherMerchant", Name = "Feather Merchant", Odds = 14.0, Description = "Earn 20% more money whenever you sell feathers." },
	{ Id = "Forkmaster", Name = "Forkmaster", Odds = 9.0, Description = "Pitchfork swings collect 25% more feathers, and pitchfork upgrades cost 25% less." },
	{ Id = "Demolitionist", Name = "Demolitionist", Odds = 7.0, Description = "Dynamite explosions have a 20% larger blast radius. 10% chance: TNT splits into 3 mini charges." },
	{ Id = "Prospector", Name = "Prospector", Odds = 3.9, Description = "Find extra gems while collecting feathers. Feathers can transform into a Diamond." },
	{ Id = "DroneSpecialist", Name = "Drone Specialist", Odds = 1.0, Description = "Always own a drone. It flies 30% faster and carries 40% more feathers. Chance to call in a 3-drone work swarm." },
	{ Id = "UltimateFarmer", Name = "Ultimate Farmer", Odds = 0.1, Description = "Receive every class's passive stat bonuses at once. Randomly activates Golden Harvest." },
}
DisplayConfig.ClassRollCostGems = 40

DisplayConfig.ClassMonetization = {
	FastRollsRobux = 144,
	DoubleLuckRobux = 160,
	ExtraSlotRobux = 96,
}

-- ============================================================
-- ALIEN CHEST
-- ============================================================
DisplayConfig.AlienChest = {
	OpenTokenCost = 100,
	Odds = {
		{ Id = "GemsSmall", Label = "Gems (25-75)", Chance = 60.0, Rarity = "Common" },
		{ Id = "GemsLarge", Label = "Gems (75-200)", Chance = 25.0, Rarity = "Uncommon" },
		{ Id = "AlienDynamite", Label = "Alien Dynamite", Chance = 7.0, Rarity = "Rare" },
		{ Id = "AlienVacuum", Label = "Alien Vacuum", Chance = 4.5, Rarity = "Rare" },
		{ Id = "AlienSquidfork", Label = "Alien Squidfork", Chance = 2.5, Rarity = "Epic" },
		{ Id = "UFO", Label = "UFO", Chance = 1.0, Rarity = "Legendary" },
	},
	MultiOpen = {
		{ Count = 3, Robux = 72 },
		{ Count = 5, Robux = 104 },
		{ Count = 10, Robux = 184 },
	},
}

-- ============================================================
-- INVENTORY VARIANTS
-- ============================================================
DisplayConfig.InventoryCategories = {
	{
		Id = "Pitchfork",
		Name = "PITCHFORK",
		Variants = { { Id = "Default", Name = "DEFAULT" }, { Id = "AlienSquidfork", Name = "ALIEN SQUIDFORK" } },
	},
	{
		Id = "Dynamite",
		Name = "DYNAMITE",
		Variants = { { Id = "Default", Name = "DEFAULT" }, { Id = "AlienDynamite", Name = "ALIEN DYNAMITE" } },
	},
	{
		Id = "Vacuum",
		Name = "VACUUM",
		Variants = { { Id = "Default", Name = "DEFAULT" }, { Id = "AlienVacuum", Name = "ALIEN VACUUM" } },
	},
	{
		Id = "Drone",
		Name = "DRONE",
		Variants = { { Id = "Default", Name = "DEFAULT" }, { Id = "UFO", Name = "UFO" } },
	},
}

-- ============================================================
-- CHAPTERS
-- ============================================================
DisplayConfig.Chapters = {
	{
		Id = "Chapter1",
		Name = "CHAPTER 1",
		Subtitle = "HENHOUSE",
		Difficulties = {
			{ Id = "Normal", Name = "NORMAL", RequiresWins = 0 },
			{ Id = "Hard", Name = "HARD", RequiresWins = 1 },
		},
	},
	{
		Id = "Chapter2",
		Name = "CHAPTER 2",
		Subtitle = "COMING SOON",
		RequiresWins = 1,
		Locked = true,
	},
}

DisplayConfig.CompletionRewards = {
	Normal = { Gems = 40, AlienTokens = 10 },
	Hard = { Gems = 60, AlienTokens = 20 },
}

DisplayConfig.MaxPartySize = 4
DisplayConfig.BaseBagCapacity = 25

-- ============================================================
-- Monetization product/pass IDs.
-- No IDs were provided in the GDD; MonetizationConfig (owned by Agent 1)
-- is the only valid source. Until it exists, every id resolves to nil and
-- purchase buttons using it are cleanly disabled rather than erroring.
-- ============================================================
function DisplayConfig.getProductId(key: string): number?
	local config = DisplayConfig.MonetizationConfig
	if config and config.Products and config.Products[key] then
		return config.Products[key]
	end
	return nil
end

function DisplayConfig.getPassId(key: string): number?
	local config = DisplayConfig.MonetizationConfig
	if config and config.GamePasses and config.GamePasses[key] then
		return config.GamePasses[key]
	end
	return nil
end

return DisplayConfig
