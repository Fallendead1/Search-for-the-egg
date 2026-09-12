--!strict
-- Presentation-only data for the Upgrade Book, Shop, Class, and Chest UIs.
--
-- Every numeric value below is sourced from the real shared config modules
-- (GameplayConfig/MetaConfig, owned by Agent 1/3) whenever they're present,
-- so there is exactly one source of truth for balancing numbers -- this
-- file only adds labels/descriptions/layout that those modules don't carry.
-- The literal fallback tables exist purely so the UI degrades gracefully
-- (instead of erroring) if a shared module is momentarily missing in
-- Studio; they mirror the real modules' values exactly and are never
-- preferred over them.
--
-- Canonical money representation: every *Cents field here is integer cents,
-- matching the server's authoritative RunPlayerStateService.CashCents (see
-- RoundService's header). Format.cash(cents) converts for display.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DisplayConfig = {}

local root = ReplicatedStorage:FindFirstChild("SearchForTheEgg")

local function findChild(...: string): ModuleScript?
	local node: Instance? = root
	for _, name in ipairs({ ... }) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	if node and node:IsA("ModuleScript") then
		return node :: ModuleScript
	end
	return nil
end

local function tryRequire(moduleScript: ModuleScript?): any?
	if not moduleScript then
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if ok then
		return result
	end
	warn(("[DisplayConfig] Failed to require '%s': %s"):format(moduleScript:GetFullName(), tostring(result)))
	return nil
end

local HandConfig = tryRequire(findChild("GameplayConfig", "HandConfig"))
local BagConfig = tryRequire(findChild("GameplayConfig", "BagConfig"))
local PitchforkConfig = tryRequire(findChild("GameplayConfig", "PitchforkConfig"))
local DynamiteConfig = tryRequire(findChild("GameplayConfig", "DynamiteConfig"))
local VacuumConfig = tryRequire(findChild("GameplayConfig", "VacuumConfig"))
local DroneConfig = tryRequire(findChild("GameplayConfig", "DroneConfig"))
local FeatherGrabberConfig = tryRequire(findChild("GameplayConfig", "FeatherGrabberConfig"))
local TornadoLauncherConfig = tryRequire(findChild("GameplayConfig", "TornadoLauncherConfig"))
local PackingBotConfig = tryRequire(findChild("GameplayConfig", "PackingBotConfig"))
local RunConfig = tryRequire(findChild("GameplayConfig", "RunConfig"))
local ChestConfig = tryRequire(findChild("MetaConfig", "ChestConfig"))
local ClassConfig = tryRequire(findChild("MetaConfig", "ClassConfig"))
local PermanentPerksConfig = tryRequire(findChild("MetaConfig", "PermanentPerksConfig"))
local MonetizationConfig = tryRequire(findChild("MetaConfig", "MonetizationConfig"))
local RewardConfig = tryRequire(findChild("MetaConfig", "RewardConfig"))

DisplayConfig.GameplayConfig = RunConfig
DisplayConfig.MetaConfig = ClassConfig
DisplayConfig.MonetizationConfig = MonetizationConfig

-- Builds { {Level, Value, CostCents}, ... } for levels 1..maxLevel from a
-- [0..maxLevel]-indexed shared config levels table (e.g. HandConfig.GRASP_LEVELS),
-- reading `valueField` as the display Value. Falls back to `fallback` if the
-- shared table isn't available.
local function buildLevels(levelsTable: any, maxLevel: number?, valueField: string, fallback: { { Level: number, Value: number, CostCents: number } })
	if not levelsTable then
		return fallback
	end
	local built = {}
	for level = 1, (maxLevel or 5) do
		local entry = levelsTable[level]
		if not entry then
			break
		end
		table.insert(built, { Level = level, Value = entry[valueField], CostCents = entry.CostCents })
	end
	return built
end

-- ============================================================
-- Bag capacity progression (barn counter upgrade, presented by client)
-- ============================================================
DisplayConfig.Bag = {
	Base = (BagConfig and BagConfig.LEVELS[0].Capacity) or 25,
	Levels = buildLevels(BagConfig and BagConfig.LEVELS, BagConfig and BagConfig.MAX_LEVEL, "Capacity", {
		{ Level = 1, Value = 50, CostCents = 100 },
		{ Level = 2, Value = 100, CostCents = 250 },
		{ Level = 3, Value = 150, CostCents = 500 },
		{ Level = 4, Value = 200, CostCents = 750 },
		{ Level = 5, Value = 250, CostCents = 1000 },
	}),
	MaxCapacity = (BagConfig and BagConfig.MAX_NORMAL_CAPACITY) or 250,
	InfiniteBagRobux = 16,
}
-- Capacity is also the field name UI reads directly (not "Value"); mirror it.
for _, entry in ipairs(DisplayConfig.Bag.Levels) do
	(entry :: any).Capacity = entry.Value
end

-- ============================================================
-- HAND
-- ============================================================
DisplayConfig.Hand = {
	Hold = {
		CostCents = (HandConfig and HandConfig.HOLD_UNLOCK_COST_CENTS) or 100,
		Description = "Hold to collect feathers continuously.",
	},
	Speed = {
		Base = (HandConfig and HandConfig.SPEED_LEVELS[0].IntervalSeconds) or 0.55,
		Description = "Collect feathers faster.",
		Levels = buildLevels(HandConfig and HandConfig.SPEED_LEVELS, HandConfig and HandConfig.MAX_LEVEL, "IntervalSeconds", {
			{ Level = 1, Value = 0.50, CostCents = 25 },
			{ Level = 2, Value = 0.45, CostCents = 50 },
			{ Level = 3, Value = 0.40, CostCents = 100 },
			{ Level = 4, Value = 0.35, CostCents = 250 },
			{ Level = 5, Value = 0.30, CostCents = 500 },
		}),
	},
	Grasp = {
		Base = (HandConfig and HandConfig.GRASP_LEVELS[0].Amount) or 1,
		Description = "Collect more feathers at once.",
		Levels = buildLevels(HandConfig and HandConfig.GRASP_LEVELS, HandConfig and HandConfig.MAX_LEVEL, "Amount", {
			{ Level = 1, Value = 2, CostCents = 25 },
			{ Level = 2, Value = 3, CostCents = 50 },
			{ Level = 3, Value = 4, CostCents = 100 },
			{ Level = 4, Value = 5, CostCents = 250 },
			{ Level = 5, Value = 6, CostCents = 500 },
		}),
	},
}

-- ============================================================
-- PITCHFORK
-- ============================================================
DisplayConfig.Pitchfork = {
	CashCostCents = (PitchforkConfig and PitchforkConfig.UNLOCK_COST_CENTS) or 800,
	OneRoundRobux = (PitchforkConfig and PitchforkConfig.ONE_ROUND_ROBUX) or 16,
	PermanentRobux = (PitchforkConfig and PitchforkConfig.PERMANENT_ROBUX) or 80,
	Description = "Stab the pile and haul out a whole forkful at once.",
	Identity = "Slower than hand. Removes much more. Digs deeper.",
	Sweep = { Base = (PitchforkConfig and PitchforkConfig.AMOUNT_LEVELS[0].Value) or 8,
		Levels = buildLevels(PitchforkConfig and PitchforkConfig.AMOUNT_LEVELS, PitchforkConfig and PitchforkConfig.MAX_LEVEL, "Value", {
			{ Level = 1, Value = 10, CostCents = 200 },
			{ Level = 2, Value = 12, CostCents = 400 },
			{ Level = 3, Value = 14, CostCents = 600 },
			{ Level = 4, Value = 16, CostCents = 800 },
			{ Level = 5, Value = 18, CostCents = 1000 },
		}) },
	Speed = { Base = (PitchforkConfig and PitchforkConfig.SPEED_LEVELS[0].IntervalSeconds) or 1.80,
		Levels = buildLevels(PitchforkConfig and PitchforkConfig.SPEED_LEVELS, PitchforkConfig and PitchforkConfig.MAX_LEVEL, "IntervalSeconds", {
			{ Level = 1, Value = 1.60, CostCents = 200 },
			{ Level = 2, Value = 1.40, CostCents = 400 },
			{ Level = 3, Value = 1.20, CostCents = 600 },
			{ Level = 4, Value = 1.00, CostCents = 800 },
			{ Level = 5, Value = 0.80, CostCents = 1000 },
		}) },
	Dig = { Base = (PitchforkConfig and PitchforkConfig.DIG_DEPTH_LEVELS[0].Multiplier) or 1.00,
		Levels = buildLevels(PitchforkConfig and PitchforkConfig.DIG_DEPTH_LEVELS, PitchforkConfig and PitchforkConfig.MAX_LEVEL, "Multiplier", {
			{ Level = 1, Value = 1.15, CostCents = 200 },
			{ Level = 2, Value = 1.30, CostCents = 400 },
			{ Level = 3, Value = 1.45, CostCents = 600 },
			{ Level = 4, Value = 1.60, CostCents = 800 },
			{ Level = 5, Value = 1.75, CostCents = 1000 },
		}) },
}

-- ============================================================
-- DYNAMITE
-- ============================================================
DisplayConfig.Dynamite = {
	CashCostCents = (DynamiteConfig and DynamiteConfig.UNLOCK_COST_CENTS) or 2500,
	OneRoundRobux = (DynamiteConfig and DynamiteConfig.ONE_ROUND_ROBUX) or 24,
	PermanentRobux = (DynamiteConfig and DynamiteConfig.PERMANENT_ROBUX) or 120,
	Description = "Blow a crater straight through the feather pile.",
	Power = { Base = (DynamiteConfig and DynamiteConfig.POWER_LEVELS[0].Radius) or 2.40,
		Levels = buildLevels(DynamiteConfig and DynamiteConfig.POWER_LEVELS, DynamiteConfig and DynamiteConfig.MAX_LEVEL, "Radius", {
			{ Level = 1, Value = 2.80, CostCents = 500 },
			{ Level = 2, Value = 3.20, CostCents = 1000 },
			{ Level = 3, Value = 3.60, CostCents = 1500 },
			{ Level = 4, Value = 4.00, CostCents = 2000 },
			{ Level = 5, Value = 4.80, CostCents = 2500 },
		}) },
	Speed = { Base = (DynamiteConfig and DynamiteConfig.SPEED_LEVELS[0].CooldownSeconds) or 12,
		Levels = buildLevels(DynamiteConfig and DynamiteConfig.SPEED_LEVELS, DynamiteConfig and DynamiteConfig.MAX_LEVEL, "CooldownSeconds", {
			{ Level = 1, Value = 11.5, CostCents = 500 },
			{ Level = 2, Value = 11, CostCents = 1000 },
			{ Level = 3, Value = 10, CostCents = 1500 },
			{ Level = 4, Value = 9, CostCents = 2000 },
			{ Level = 5, Value = 8.5, CostCents = 2500 },
		}) },
	LuckyBlast = { Base = (DynamiteConfig and DynamiteConfig.LUCKY_BLAST_LEVELS[0].Chance) or 0,
		Levels = buildLevels(DynamiteConfig and DynamiteConfig.LUCKY_BLAST_LEVELS, DynamiteConfig and DynamiteConfig.MAX_LEVEL, "Chance", {
			{ Level = 1, Value = 0.05, CostCents = 500 },
			{ Level = 2, Value = 0.10, CostCents = 1000 },
			{ Level = 3, Value = 0.15, CostCents = 1500 },
			{ Level = 4, Value = 0.20, CostCents = 2000 },
			{ Level = 5, Value = 0.25, CostCents = 2500 },
		}) },
}

-- ============================================================
-- VACUUM (no Cash unlock -- Robux-only, see VacuumConfig)
-- ============================================================
DisplayConfig.Vacuum = {
	OneRoundRobux = (VacuumConfig and VacuumConfig.ONE_ROUND_ROBUX) or 40,
	Power = { Base = (VacuumConfig and VacuumConfig.POWER_LEVELS[0].FeathersPerSecond) or 5,
		Levels = buildLevels(VacuumConfig and VacuumConfig.POWER_LEVELS, VacuumConfig and VacuumConfig.MAX_LEVEL, "FeathersPerSecond", {
			{ Level = 1, Value = 8, CostCents = 500 },
			{ Level = 2, Value = 11, CostCents = 1000 },
			{ Level = 3, Value = 14, CostCents = 1500 },
			{ Level = 4, Value = 17, CostCents = 2000 },
			{ Level = 5, Value = 20, CostCents = 2500 },
		}) },
	Cooling = { Base = (VacuumConfig and VacuumConfig.COOLING_LEVELS[0].RecoverySeconds) or 8,
		Levels = buildLevels(VacuumConfig and VacuumConfig.COOLING_LEVELS, VacuumConfig and VacuumConfig.MAX_LEVEL, "RecoverySeconds", {
			{ Level = 1, Value = 7, CostCents = 500 },
			{ Level = 2, Value = 6, CostCents = 1000 },
			{ Level = 3, Value = 5, CostCents = 1500 },
			{ Level = 4, Value = 4, CostCents = 2000 },
			{ Level = 5, Value = 3, CostCents = 2500 },
		}) },
	Runtime = { Base = (VacuumConfig and VacuumConfig.RUNTIME_LEVELS[0].RuntimeSeconds) or 4,
		Levels = buildLevels(VacuumConfig and VacuumConfig.RUNTIME_LEVELS, VacuumConfig and VacuumConfig.MAX_LEVEL, "RuntimeSeconds", {
			{ Level = 1, Value = 5, CostCents = 500 },
			{ Level = 2, Value = 6, CostCents = 1000 },
			{ Level = 3, Value = 7, CostCents = 1500 },
			{ Level = 4, Value = 8, CostCents = 2000 },
			{ Level = 5, Value = 10, CostCents = 2500 },
		}) },
}

-- ============================================================
-- DRONE (no Cash unlock -- Robux or Gems, see DroneConfig)
-- ============================================================
DisplayConfig.Drone = {
	OneRoundRobux = (DroneConfig and DroneConfig.ONE_ROUND_ROBUX) or 16,
	GemsCost = (DroneConfig and DroneConfig.ONE_ROUND_GEM_COST) or 40,
	PermanentRobux = (DroneConfig and DroneConfig.PERMANENT_ROBUX) or 104,
	Description = "Your automatic helper.",
	Speed = { Base = (DroneConfig and DroneConfig.SPEED_LEVELS[0].Multiplier) or 1.0,
		Levels = buildLevels(DroneConfig and DroneConfig.SPEED_LEVELS, DroneConfig and DroneConfig.MAX_LEVEL, "Multiplier", {
			{ Level = 1, Value = 1.2, CostCents = 500 },
			{ Level = 2, Value = 1.4, CostCents = 1000 },
			{ Level = 3, Value = 1.6, CostCents = 1500 },
			{ Level = 4, Value = 1.8, CostCents = 2000 },
			{ Level = 5, Value = 2.0, CostCents = 2500 },
		}) },
	Grasp = { Base = (DroneConfig and DroneConfig.GRASP_LEVELS[0].Amount) or 5,
		Levels = buildLevels(DroneConfig and DroneConfig.GRASP_LEVELS, DroneConfig and DroneConfig.MAX_LEVEL, "Amount", {
			{ Level = 1, Value = 10, CostCents = 500 },
			{ Level = 2, Value = 15, CostCents = 1000 },
			{ Level = 3, Value = 20, CostCents = 1500 },
			{ Level = 4, Value = 25, CostCents = 2000 },
			{ Level = 5, Value = 30, CostCents = 2500 },
		}) },
	Capacity = { Base = (DroneConfig and DroneConfig.CAPACITY_LEVELS[0].Capacity) or 25,
		Levels = buildLevels(DroneConfig and DroneConfig.CAPACITY_LEVELS, DroneConfig and DroneConfig.MAX_LEVEL, "Capacity", {
			{ Level = 1, Value = 50, CostCents = 500 },
			{ Level = 2, Value = 75, CostCents = 1000 },
			{ Level = 3, Value = 100, CostCents = 1500 },
			{ Level = 4, Value = 150, CostCents = 2000 },
			{ Level = 5, Value = 200, CostCents = 2500 },
		}) },
}

-- ============================================================
-- FEATHER GRABBER (new equipment, fixed stats -- no upgrade levels)
-- ============================================================
DisplayConfig.FeatherGrabber = {
	CashCostCents = (FeatherGrabberConfig and FeatherGrabberConfig.UNLOCK_COST_CENTS) or 600,
	OneRoundRobux = (FeatherGrabberConfig and FeatherGrabberConfig.ONE_ROUND_ROBUX) or 16,
	PermanentRobux = (FeatherGrabberConfig and FeatherGrabberConfig.PERMANENT_ROBUX) or 80,
	Description = "Grabs a big scoop of feathers at once.",
	GrabAmount = (FeatherGrabberConfig and FeatherGrabberConfig.GRAB_AMOUNT) or 16,
	ActionSeconds = (FeatherGrabberConfig and FeatherGrabberConfig.ACTION_SECONDS) or 2.0,
}

-- ============================================================
-- FEATHER TORNADO LAUNCHER (new equipment, fixed stats)
-- ============================================================
DisplayConfig.TornadoLauncher = {
	CashCostCents = (TornadoLauncherConfig and TornadoLauncherConfig.UNLOCK_COST_CENTS) or 7500,
	OneRoundRobux = (TornadoLauncherConfig and TornadoLauncherConfig.ONE_ROUND_ROBUX) or 64,
	PermanentRobux = (TornadoLauncherConfig and TornadoLauncherConfig.PERMANENT_ROBUX) or 224,
	Description = "Launches a swirling funnel that pulls a huge amount of feathers out of the pile at once.",
	MaxCollectAmount = (TornadoLauncherConfig and TornadoLauncherConfig.MAX_COLLECT_AMOUNT) or 150,
	CooldownSeconds = (TornadoLauncherConfig and TornadoLauncherConfig.COOLDOWN_SECONDS) or 6,
}

-- ============================================================
-- FEATHER PACKING BOT (new helper -- Gems or Robux, no Cash unlock, like Drone)
-- ============================================================
DisplayConfig.PackingBot = {
	OneRoundRobux = (PackingBotConfig and PackingBotConfig.ONE_ROUND_ROBUX) or 40,
	GemsCost = (PackingBotConfig and PackingBotConfig.ONE_ROUND_GEM_COST) or 45,
	PermanentRobux = (PackingBotConfig and PackingBotConfig.PERMANENT_ROBUX) or 144,
	Description = "Automatically collects feathers and sells them for you.",
	Capacity = (PackingBotConfig and PackingBotConfig.CAPACITY) or 15,
}

-- ============================================================
-- PERMANENT GEM SHOP
-- ============================================================
local function permanentPerkCost(perkId: string, fallback: number): number
	local perk = PermanentPerksConfig and PermanentPerksConfig.Perks[perkId]
	return (perk and perk.CostPerLevel) or fallback
end

-- Order matches the reference Shop's 2x2 reading order (top-left to
-- bottom-right): Bag Size, Hand Grasp, Feather Value, Gem Value.
DisplayConfig.PermanentPerks = {
	{ Id = "BagSize", Name = "BAG SIZE", GemCost = permanentPerkCost("BagSize", 25) },
	{ Id = "HandGrabAmount", Name = "HAND GRASP", GemCost = permanentPerkCost("HandGrabAmount", 50) },
	{ Id = "FeatherValue", Name = "FEATHER VALUE", GemCost = permanentPerkCost("FeatherValue", 20) },
	{ Id = "GemValue", Name = "GEM VALUE", GemCost = permanentPerkCost("GemValue", 150) },
}
DisplayConfig.PermanentPerkMaxLevel = (PermanentPerksConfig and PermanentPerksConfig.MaxLevel) or 5

DisplayConfig.GemPacks = {
	{ Id = "Gems100", Gems = 100, Robux = 24 },
	{ Id = "Gems400", Gems = 400, Robux = 72 },
}
DisplayConfig.DoubleGemsRobux = 160

-- ============================================================
-- CLASSES
-- ============================================================
local CLASS_DESCRIPTIONS = {
	Starter = "A simple start with no special bonuses. Every great Egg Hunter starts somewhere.",
	PackMule = "Carry more Feathers before you need to head back and sell.",
	FeatherMerchant = "Every Feather is worth more when you sell it.",
	Forkmaster = "Master the Pitchfork. Clear more Feathers and upgrade it for less.",
	Demolitionist = "Make room with bigger explosions. Your Dynamite clears a wider area and can split into mini charges.",
	Prospector = "A sharp eye for valuable finds. Discover more Gems and rare Diamond rewards while digging.",
	DroneSpecialist = "Your automated helpers work faster, carry more, and can swarm the pile.",
	UltimateFarmer = "The ultimate Egg Hunter. Receive the power of every other Class together.",
}

-- Exact stat-line wording/values per Sections 46-53 -- sourced from the
-- REAL modifiers in MetaConfig/ClassConfig, never the reference game's
-- numbers. Prospector has no numeric field configured (ProspectorEnabled
-- only), so its lines stay descriptive rather than inventing a percentage.
local CLASS_STAT_LINES = {
	Starter = { "NO PASSIVE BONUS" },
	PackMule = { "+35% BAG CAPACITY" },
	FeatherMerchant = { "+25% SALE CASH" },
	Forkmaster = { "+25% PITCHFORK YIELD", "25% CHEAPER PITCHFORK UPGRADES" },
	Demolitionist = { "+20% BLAST RADIUS", "10% MINI-CHARGE SPLIT" },
	Prospector = { "INCREASED GEM FINDS WHILE DIGGING", "CHANCE TO FIND RARE DIAMONDS" },
	DroneSpecialist = { "DRONE ALWAYS AVAILABLE", "+30% DRONE SPEED", "+40% DRONE CAPACITY", "3-DRONE SWARM CHANCE" },
	UltimateFarmer = { "ALL CLASS PASSIVES", "CHANCE FOR GOLDEN HARVEST" },
}

-- Rarity-style row coloring (Section 45) -- a hint alongside name/odds/state
-- text, never the only indicator.
local CLASS_RARITY_COLOR = {
	Starter = Color3.fromRGB(190, 190, 190),
	PackMule = Color3.fromRGB(110, 210, 120),
	FeatherMerchant = Color3.fromRGB(255, 214, 64),
	Forkmaster = Color3.fromRGB(90, 210, 180),
	Demolitionist = Color3.fromRGB(230, 90, 80),
	Prospector = Color3.fromRGB(90, 150, 240),
	DroneSpecialist = Color3.fromRGB(170, 210, 235),
	UltimateFarmer = Color3.fromRGB(220, 140, 240),
}

if ClassConfig then
	DisplayConfig.Classes = {}
	local totalWeight = 0
	for _, odd in ipairs(ClassConfig.Odds) do
		totalWeight += odd.Weight
	end
	for _, odd in ipairs(ClassConfig.Odds) do
		local classInfo = ClassConfig.Classes[odd.Id]
		table.insert(DisplayConfig.Classes, {
			Id = odd.Id,
			Name = (classInfo and classInfo.DisplayName) or odd.Id,
			Odds = totalWeight > 0 and (odd.Weight / totalWeight * 100) or 0,
			Description = CLASS_DESCRIPTIONS[odd.Id] or "",
			StatLines = CLASS_STAT_LINES[odd.Id] or {},
			RarityColor = CLASS_RARITY_COLOR[odd.Id] or Color3.fromRGB(190, 190, 190),
		})
	end
	DisplayConfig.ClassRollCostGems = ClassConfig.RollCostGems
else
	DisplayConfig.Classes = {
		{ Id = "Starter", Name = "Nestling", Odds = 35.0, Description = CLASS_DESCRIPTIONS.Starter, StatLines = CLASS_STAT_LINES.Starter, RarityColor = CLASS_RARITY_COLOR.Starter },
		{ Id = "PackMule", Name = "Feather Hauler", Odds = 25.0, Description = CLASS_DESCRIPTIONS.PackMule, StatLines = CLASS_STAT_LINES.PackMule, RarityColor = CLASS_RARITY_COLOR.PackMule },
		{ Id = "FeatherMerchant", Name = "Coop Trader", Odds = 16.0, Description = CLASS_DESCRIPTIONS.FeatherMerchant, StatLines = CLASS_STAT_LINES.FeatherMerchant, RarityColor = CLASS_RARITY_COLOR.FeatherMerchant },
		{ Id = "Forkmaster", Name = "Pile Raker", Odds = 11.0, Description = CLASS_DESCRIPTIONS.Forkmaster, StatLines = CLASS_STAT_LINES.Forkmaster, RarityColor = CLASS_RARITY_COLOR.Forkmaster },
		{ Id = "Demolitionist", Name = "Blast Keeper", Odds = 7.0, Description = CLASS_DESCRIPTIONS.Demolitionist, StatLines = CLASS_STAT_LINES.Demolitionist, RarityColor = CLASS_RARITY_COLOR.Demolitionist },
		{ Id = "Prospector", Name = "Gem Rooster", Odds = 4.0, Description = CLASS_DESCRIPTIONS.Prospector, StatLines = CLASS_STAT_LINES.Prospector, RarityColor = CLASS_RARITY_COLOR.Prospector },
		{ Id = "DroneSpecialist", Name = "Storm Builder", Odds = 1.7, Description = CLASS_DESCRIPTIONS.DroneSpecialist, StatLines = CLASS_STAT_LINES.DroneSpecialist, RarityColor = CLASS_RARITY_COLOR.DroneSpecialist },
		{ Id = "UltimateFarmer", Name = "Egg Oracle", Odds = 0.3, Description = CLASS_DESCRIPTIONS.UltimateFarmer, StatLines = CLASS_STAT_LINES.UltimateFarmer, RarityColor = CLASS_RARITY_COLOR.UltimateFarmer },
	}
	DisplayConfig.ClassRollCostGems = 40
end

DisplayConfig.ClassMonetization = {
	FastRollsRobux = 144,
	DoubleLuckRobux = 160,
	ExtraSlotRobux = 96,
}

-- ============================================================
-- ALIEN CHEST
-- ============================================================
local CHEST_LABELS = {
	GemsSmall = "Gems (25-75)",
	GemsLarge = "Gems (75-200)",
	AlienDynamite = "Alien Dynamite",
	AlienVacuum = "Alien Vacuum",
	AlienSquidfork = "Alien Squidfork",
	UFO = "UFO",
}
local CHEST_RARITY = {
	GemsSmall = "Common",
	GemsLarge = "Uncommon",
	AlienDynamite = "Rare",
	AlienVacuum = "Rare",
	AlienSquidfork = "Epic",
	UFO = "Legendary",
}

if ChestConfig then
	local totalWeight = 0
	for _, entry in ipairs(ChestConfig.Rewards) do
		totalWeight += entry.Weight
	end
	local odds = {}
	for _, entry in ipairs(ChestConfig.Rewards) do
		table.insert(odds, {
			Id = entry.Id,
			Label = CHEST_LABELS[entry.Id] or entry.Id,
			Chance = totalWeight > 0 and (entry.Weight / totalWeight * 100) or 0,
			Rarity = CHEST_RARITY[entry.Id] or "Common",
		})
	end
	DisplayConfig.AlienChest = {
		OpenTokenCost = ChestConfig.TokenCost,
		Odds = odds,
		MultiOpen = {
			{ Count = 3, Robux = 72 },
			{ Count = 5, Robux = 104 },
			{ Count = 10, Robux = 184 },
		},
	}
else
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
end

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
local function chapterRequiresWins(chapterId: string, fallback: number): number
	local chapter = RunConfig and RunConfig.CHAPTERS[chapterId]
	return (chapter and chapter.RequiresWins) or fallback
end
local function difficultyRequiresWins(difficultyId: string, fallback: number): number
	local difficulty = RunConfig and RunConfig.DIFFICULTY[difficultyId]
	return (difficulty and difficulty.RequiresWins) or fallback
end

DisplayConfig.Chapters = {
	{
		Id = "Chapter1",
		Name = "CHAPTER 1",
		Subtitle = "HENHOUSE",
		Difficulties = {
			{ Id = "Normal", Name = "NORMAL", RequiresWins = difficultyRequiresWins("Normal", 0) },
			{ Id = "Hard", Name = "HARD", RequiresWins = difficultyRequiresWins("Hard", 1) },
		},
	},
	{
		Id = "Chapter2",
		Name = "CHAPTER 2",
		Subtitle = "COMING SOON",
		RequiresWins = chapterRequiresWins("Chapter2", 1),
		Locked = true,
	},
}

-- The one source of truth for these amounts is MetaConfig/RewardConfig
-- .Chapters -- the same table RewardService/MetaProgressionService read
-- server-side to actually grant them.
local chapter1Rewards = RewardConfig and RewardConfig.Chapters.Chapter1
DisplayConfig.CompletionRewards = {
	Normal = (chapter1Rewards and chapter1Rewards.Normal) or { Gems = 40, AlienTokens = 10, Wins = 1 },
	Hard = (chapter1Rewards and chapter1Rewards.Hard) or { Gems = 60, AlienTokens = 20, Wins = 1 },
}

DisplayConfig.MaxPartySize = (RunConfig and RunConfig.PARTY_MAX_SIZE) or 4
DisplayConfig.BaseBagCapacity = DisplayConfig.Bag.Base

-- ============================================================
-- Monetization product/pass IDs.
-- No IDs were provided in the GDD; MonetizationConfig (owned by Agent 1)
-- is the only valid source. Until it's filled in every id resolves to nil
-- and purchase buttons using it are cleanly disabled rather than erroring.
-- ============================================================
function DisplayConfig.getProductId(key: string): number?
	local product = MonetizationConfig and MonetizationConfig.DeveloperProducts and MonetizationConfig.DeveloperProducts[key]
	if product and product.Id and product.Id ~= 0 then
		return product.Id
	end
	return nil
end

function DisplayConfig.getPassId(key: string): number?
	local pass = MonetizationConfig and MonetizationConfig.GamePasses and MonetizationConfig.GamePasses[key]
	if pass and pass.Id and pass.Id ~= 0 then
		return pass.Id
	end
	return nil
end

return DisplayConfig
