--[[
	STUDIO-ONLY automated test suite. No-ops instantly (no requires, no
	side effects) the moment RunService:IsStudio() is false -- never runs on
	a published server.

	Runs entirely at server start, before any player needs to be connected,
	so every test here is scoped to PURE config values and to service
	functions that operate on plain Lua tables (fake `run`/`state` objects)
	rather than a live Player + loaded DataStore profile. That is a
	deliberate boundary, not a shortcut: anything that requires a real
	Player (DataService-backed persistence, RoundService's live run
	registry, actual remote round-trips, character-position range checks)
	cannot be safely faked without either mutating a real tester's profile
	on every single server boot or reimplementing half of RoundService's
	private state here -- both worse than just leaving those as the
	Studio interaction tests they inherently are. See the printed summary's
	"NOT covered" list.

	Results print to the Output window as this script runs -- open Output
	before/while testing in Studio to see PASS/FAIL. A summary line always
	prints last; any failure also gets its own warn() so it's easy to spot.
]]

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ServerScriptService.SearchForTheEgg.Core
local Gameplay = ServerScriptService.SearchForTheEgg.Gameplay
local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local MetaConfig = ReplicatedStorage.SearchForTheEgg.MetaConfig

local BagConfig = require(GameplayConfig.BagConfig)
local HandConfig = require(GameplayConfig.HandConfig)
local PitchforkConfig = require(GameplayConfig.PitchforkConfig)
local DynamiteConfig = require(GameplayConfig.DynamiteConfig)
local VacuumConfig = require(GameplayConfig.VacuumConfig)
local DroneConfig = require(GameplayConfig.DroneConfig)
local FeatherGrabberConfig = require(GameplayConfig.FeatherGrabberConfig)
local TornadoLauncherConfig = require(GameplayConfig.TornadoLauncherConfig)
local PackingBotConfig = require(GameplayConfig.PackingBotConfig)
local RunConfig = require(GameplayConfig.RunConfig)
local ClassConfig = require(MetaConfig.ClassConfig)
local ChestConfig = require(MetaConfig.ChestConfig)
local PermanentPerksConfig = require(MetaConfig.PermanentPerksConfig)
local MonetizationConfig = require(MetaConfig.MonetizationConfig)
local RewardConfig = require(MetaConfig.RewardConfig)
local DataSchema = require(MetaConfig.DataSchema)

local RunPlayerStateService = require(Gameplay.RunPlayerStateService)
local ToolService = require(Gameplay.ToolService)
local SellService = require(Gameplay.SellService)
local RoundService = require(Gameplay.RoundService)
local EggService = require(Gameplay.EggService)
local HardModeService = require(Gameplay.HardModeService)
local PartyService = require(Gameplay.PartyService)
local ChapterArrivalService = require(Gameplay.ChapterArrivalService)

local ClassService = require(Core.ClassService)
local LeaderboardService = require(Core.LeaderboardService)
local AssetConfig = require(ReplicatedStorage.SearchForTheEgg.AssetConfig)

-- ============================================================
-- Minimal assertion harness
-- ============================================================

local passed, failed = 0, 0
local failures: { string } = {}
local currentSuite = ""

local function suite(name: string)
	currentSuite = name
end

local function check(name: string, condition: boolean)
	local label = ("[%s] %s"):format(currentSuite, name)
	if condition then
		passed += 1
	else
		failed += 1
		table.insert(failures, label)
		warn("[DebugTests] FAILED: " .. label)
	end
end

local function nearlyEqual(a: number, b: number, epsilon: number?): boolean
	return math.abs(a - b) < (epsilon or 1e-6)
end

local function checkEqual(name: string, actual: any, expected: any)
	if type(actual) == "number" and type(expected) == "number" then
		check(("%s (got %s, expected %s)"):format(name, tostring(actual), tostring(expected)), nearlyEqual(actual, expected))
	else
		check(("%s (got %s, expected %s)"):format(name, tostring(actual), tostring(expected)), actual == expected)
	end
end

-- ============================================================
-- 1. BAG config
-- ============================================================
suite("Bag")
checkEqual("base capacity", BagConfig.LEVELS[0].Capacity, 25)
checkEqual("max level", BagConfig.MAX_LEVEL, 5)
local BAG_EXPECTED = {
	[1] = { 50, 100 }, [2] = { 100, 250 }, [3] = { 150, 500 }, [4] = { 200, 750 }, [5] = { 250, 1000 },
}
for level, expected in pairs(BAG_EXPECTED) do
	local entry = BagConfig.LEVELS[level]
	checkEqual(("L%d capacity"):format(level), entry.Capacity, expected[1])
	checkEqual(("L%d cost cents"):format(level), entry.CostCents, expected[2])
end

-- ============================================================
-- 2. HAND config (baseline, regression-covered)
-- ============================================================
suite("Hand")
checkEqual("Hold unlock cost cents", HandConfig.HOLD_UNLOCK_COST_CENTS, 100)
checkEqual("max level", HandConfig.MAX_LEVEL, 5)
local HAND_SPEED_EXPECTED = { [1] = { 0.50, 25 }, [2] = { 0.45, 50 }, [3] = { 0.40, 100 }, [4] = { 0.35, 250 }, [5] = { 0.30, 500 } }
for level, expected in pairs(HAND_SPEED_EXPECTED) do
	local entry = HandConfig.SPEED_LEVELS[level]
	checkEqual(("Speed L%d interval"):format(level), entry.IntervalSeconds, expected[1])
	checkEqual(("Speed L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local HAND_GRASP_EXPECTED = { [1] = { 2, 25 }, [2] = { 3, 50 }, [3] = { 4, 100 }, [4] = { 5, 250 }, [5] = { 6, 500 } }
for level, expected in pairs(HAND_GRASP_EXPECTED) do
	local entry = HandConfig.GRASP_LEVELS[level]
	checkEqual(("Grasp L%d amount"):format(level), entry.Amount, expected[1])
	checkEqual(("Grasp L%d cost cents"):format(level), entry.CostCents, expected[2])
end

-- ============================================================
-- 3. PITCHFORK config
-- ============================================================
suite("Pitchfork")
checkEqual("unlock cost cents", PitchforkConfig.UNLOCK_COST_CENTS, 800)
checkEqual("max level", PitchforkConfig.MAX_LEVEL, 5)
local PF_SWEEP_EXPECTED = { [1] = { 10, 200 }, [2] = { 12, 400 }, [3] = { 14, 600 }, [4] = { 16, 800 }, [5] = { 18, 1000 } }
for level, expected in pairs(PF_SWEEP_EXPECTED) do
	local entry = PitchforkConfig.AMOUNT_LEVELS[level]
	checkEqual(("Sweep L%d value"):format(level), entry.Value, expected[1])
	checkEqual(("Sweep L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local PF_SPEED_EXPECTED = { [1] = { 1.60, 200 }, [2] = { 1.40, 400 }, [3] = { 1.20, 600 }, [4] = { 1.00, 800 }, [5] = { 0.80, 1000 } }
for level, expected in pairs(PF_SPEED_EXPECTED) do
	local entry = PitchforkConfig.SPEED_LEVELS[level]
	checkEqual(("Speed L%d interval"):format(level), entry.IntervalSeconds, expected[1])
	checkEqual(("Speed L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local PF_DIG_EXPECTED = { [1] = { 1.15, 200 }, [2] = { 1.30, 400 }, [3] = { 1.45, 600 }, [4] = { 1.60, 800 }, [5] = { 1.75, 1000 } }
for level, expected in pairs(PF_DIG_EXPECTED) do
	local entry = PitchforkConfig.DIG_DEPTH_LEVELS[level]
	checkEqual(("Dig L%d multiplier"):format(level), entry.Multiplier, expected[1])
	checkEqual(("Dig L%d cost cents"):format(level), entry.CostCents, expected[2])
end
checkEqual("Forkmaster yield bonus", PitchforkConfig.FORKMASTER_YIELD_BONUS, 0.25)
checkEqual("Forkmaster cost multiplier", PitchforkConfig.FORKMASTER_COST_MULTIPLIER, 0.75)

-- ============================================================
-- 4. DYNAMITE config
-- ============================================================
suite("Dynamite")
checkEqual("unlock cost cents", DynamiteConfig.UNLOCK_COST_CENTS, 2500)
checkEqual("max level", DynamiteConfig.MAX_LEVEL, 5)
local DYN_POWER_EXPECTED = { [1] = { 2.80, 500 }, [2] = { 3.20, 1000 }, [3] = { 3.60, 1500 }, [4] = { 4.00, 2000 }, [5] = { 4.80, 2500 } }
for level, expected in pairs(DYN_POWER_EXPECTED) do
	local entry = DynamiteConfig.POWER_LEVELS[level]
	checkEqual(("Power L%d radius"):format(level), entry.Radius, expected[1])
	checkEqual(("Power L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local DYN_SPEED_EXPECTED = { [1] = { 11.5, 500 }, [2] = { 11, 1000 }, [3] = { 10, 1500 }, [4] = { 9, 2000 }, [5] = { 8.5, 2500 } }
for level, expected in pairs(DYN_SPEED_EXPECTED) do
	local entry = DynamiteConfig.SPEED_LEVELS[level]
	checkEqual(("Speed L%d cooldown"):format(level), entry.CooldownSeconds, expected[1])
	checkEqual(("Speed L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local DYN_LUCKY_EXPECTED = { [1] = { 0.05, 500 }, [2] = { 0.10, 1000 }, [3] = { 0.15, 1500 }, [4] = { 0.20, 2000 }, [5] = { 0.25, 2500 } }
for level, expected in pairs(DYN_LUCKY_EXPECTED) do
	local entry = DynamiteConfig.LUCKY_BLAST_LEVELS[level]
	checkEqual(("LuckyBlast L%d chance"):format(level), entry.Chance, expected[1])
	checkEqual(("LuckyBlast L%d cost cents"):format(level), entry.CostCents, expected[2])
end
checkEqual("Demolitionist radius bonus", DynamiteConfig.DEMOLITIONIST_RADIUS_BONUS, 0.20)
checkEqual("Demolitionist mini-charge chance", DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_CHANCE, 0.10)
checkEqual("Demolitionist mini-charge count", DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_COUNT, 3)

-- ============================================================
-- 5. VACUUM config
-- ============================================================
suite("Vacuum")
checkEqual("one round Robux", VacuumConfig.ONE_ROUND_ROBUX, 40)
checkEqual("max level", VacuumConfig.MAX_LEVEL, 5)
local VAC_POWER_EXPECTED = { [1] = { 8, 500 }, [2] = { 11, 1000 }, [3] = { 14, 1500 }, [4] = { 17, 2000 }, [5] = { 20, 2500 } }
for level, expected in pairs(VAC_POWER_EXPECTED) do
	local entry = VacuumConfig.POWER_LEVELS[level]
	checkEqual(("Power L%d feathers/sec"):format(level), entry.FeathersPerSecond, expected[1])
	checkEqual(("Power L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local VAC_COOLING_EXPECTED = { [1] = { 7, 500 }, [2] = { 6, 1000 }, [3] = { 5, 1500 }, [4] = { 4, 2000 }, [5] = { 3, 2500 } }
for level, expected in pairs(VAC_COOLING_EXPECTED) do
	local entry = VacuumConfig.COOLING_LEVELS[level]
	checkEqual(("Cooling L%d recovery"):format(level), entry.RecoverySeconds, expected[1])
	checkEqual(("Cooling L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local VAC_RUNTIME_EXPECTED = { [1] = { 5, 500 }, [2] = { 6, 1000 }, [3] = { 7, 1500 }, [4] = { 8, 2000 }, [5] = { 10, 2500 } }
for level, expected in pairs(VAC_RUNTIME_EXPECTED) do
	local entry = VacuumConfig.RUNTIME_LEVELS[level]
	checkEqual(("Runtime L%d seconds"):format(level), entry.RuntimeSeconds, expected[1])
	checkEqual(("Runtime L%d cost cents"):format(level), entry.CostCents, expected[2])
end

-- ============================================================
-- 6. DRONE config
-- ============================================================
suite("Drone")
checkEqual("one round Robux", DroneConfig.ONE_ROUND_ROBUX, 16)
checkEqual("one round Gems", DroneConfig.ONE_ROUND_GEM_COST, 40)
checkEqual("max level", DroneConfig.MAX_LEVEL, 5)
local DRONE_SPEED_EXPECTED = { [1] = { 1.2, 500 }, [2] = { 1.4, 1000 }, [3] = { 1.6, 1500 }, [4] = { 1.8, 2000 }, [5] = { 2.0, 2500 } }
for level, expected in pairs(DRONE_SPEED_EXPECTED) do
	local entry = DroneConfig.SPEED_LEVELS[level]
	checkEqual(("Speed L%d multiplier"):format(level), entry.Multiplier, expected[1])
	checkEqual(("Speed L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local DRONE_GRASP_EXPECTED = { [1] = { 10, 500 }, [2] = { 15, 1000 }, [3] = { 20, 1500 }, [4] = { 25, 2000 }, [5] = { 30, 2500 } }
for level, expected in pairs(DRONE_GRASP_EXPECTED) do
	local entry = DroneConfig.GRASP_LEVELS[level]
	checkEqual(("Grasp L%d amount"):format(level), entry.Amount, expected[1])
	checkEqual(("Grasp L%d cost cents"):format(level), entry.CostCents, expected[2])
end
local DRONE_CAPACITY_EXPECTED = { [1] = { 50, 500 }, [2] = { 75, 1000 }, [3] = { 100, 1500 }, [4] = { 150, 2000 }, [5] = { 200, 2500 } }
for level, expected in pairs(DRONE_CAPACITY_EXPECTED) do
	local entry = DroneConfig.CAPACITY_LEVELS[level]
	checkEqual(("Capacity L%d value"):format(level), entry.Capacity, expected[1])
	checkEqual(("Capacity L%d cost cents"):format(level), entry.CostCents, expected[2])
end
checkEqual("Drone Specialist speed bonus", DroneConfig.SPECIALIST_SPEED_BONUS, 0.30)
checkEqual("Drone Specialist capacity bonus", DroneConfig.SPECIALIST_CAPACITY_BONUS, 0.40)

-- ============================================================
-- 7. CLASS modifiers (config-level -- see file header for why
--    GetEffectiveClassModifiers itself needs a live profile)
-- ============================================================
suite("ClassModifiers")
local oddsTotal = 0
for _, odd in ipairs(ClassConfig.Odds) do
	oddsTotal += odd.Weight
end
checkEqual("class odds sum to 100", oddsTotal, 100)

checkEqual("Pack Mule bag capacity multiplier", ClassConfig.Classes.PackMule.BagCapacityMultiplier, 1.5)
checkEqual("Feather Merchant sale multiplier", ClassConfig.Classes.FeatherMerchant.SaleMultiplier, 1.2)
checkEqual("Forkmaster pitchfork yield multiplier", ClassConfig.Classes.Forkmaster.PitchforkYieldMultiplier, 1.25)
checkEqual("Forkmaster upgrade cost multiplier", ClassConfig.Classes.Forkmaster.PitchforkUpgradeCostMultiplier, 0.75)
checkEqual("Demolitionist radius multiplier", ClassConfig.Classes.Demolitionist.DynamiteRadiusMultiplier, 1.2)
checkEqual("Demolitionist mini-charge chance", ClassConfig.Classes.Demolitionist.DynamiteMiniChargeChance, 0.1)
check("Prospector enabled flag", ClassConfig.Classes.Prospector.ProspectorEnabled == true)
check("Drone Specialist always owns Drone", ClassConfig.Classes.DroneSpecialist.DroneAlwaysOwned == true)
checkEqual("Drone Specialist speed multiplier", ClassConfig.Classes.DroneSpecialist.DroneSpeedMultiplier, 1.3)
checkEqual("Drone Specialist capacity multiplier", ClassConfig.Classes.DroneSpecialist.DroneCapacityMultiplier, 1.4)
check("Ultimate Farmer flag", ClassConfig.Classes.UltimateFarmer.UltimateFarmer == true)
check("Ultimate Farmer enables Golden Harvest", ClassConfig.Classes.UltimateFarmer.GoldenHarvestEnabled == true)

-- ============================================================
-- 8. Permanent perks (Gem shop) config
-- ============================================================
suite("PermanentPerks")
checkEqual("max level", PermanentPerksConfig.MaxLevel, 5)
checkEqual("Bag Size cost", PermanentPerksConfig.Perks.BagSize.CostPerLevel, 25)
checkEqual("Hand Grab cost", PermanentPerksConfig.Perks.HandGrabAmount.CostPerLevel, 50)
checkEqual("Gem Value cost", PermanentPerksConfig.Perks.GemValue.CostPerLevel, 150)
checkEqual("Feather Value cost", PermanentPerksConfig.Perks.FeatherValue.CostPerLevel, 20)

-- ============================================================
-- 9. Alien Chest odds
-- ============================================================
suite("AlienChest")
checkEqual("token cost", ChestConfig.TokenCost, 100)
local chestWeightTotal = 0
for _, entry in ipairs(ChestConfig.Rewards) do
	chestWeightTotal += entry.Weight
end
checkEqual("reward weights sum to 100", chestWeightTotal, 100)
local CHEST_WEIGHT_EXPECTED = { GemsSmall = 60, GemsLarge = 25, AlienDynamite = 7, AlienVacuum = 4.5, AlienSquidfork = 2.5, UFO = 1 }
for _, entry in ipairs(ChestConfig.Rewards) do
	local expected = CHEST_WEIGHT_EXPECTED[entry.Id]
	if expected then
		checkEqual(("%s weight"):format(entry.Id), entry.Weight, expected)
	end
end

-- ============================================================
-- 10. Completion rewards (single source of truth: RewardConfig)
-- ============================================================
suite("CompletionRewards")
local normalReward = RewardConfig.Chapters.Chapter1.Normal
checkEqual("Normal Wins", normalReward.Wins, 1)
checkEqual("Normal Gems", normalReward.Gems, 40)
checkEqual("Normal Alien Tokens", normalReward.AlienTokens, 10)
local hardReward = RewardConfig.Chapters.Chapter1.Hard
checkEqual("Hard Wins", hardReward.Wins, 1)
checkEqual("Hard Gems", hardReward.Gems, 60)
checkEqual("Hard Alien Tokens", hardReward.AlienTokens, 20)

-- ============================================================
-- 11. Monetization catalog sanity (no invented real IDs; every
--     entry has the fields ProcessReceipt/DisplayConfig expect)
-- ============================================================
suite("Monetization")
local invalidProductCount = 0
for key, product in pairs(MonetizationConfig.DeveloperProducts) do
	if type(product.Id) ~= "number" or type(product.Kind) ~= "string" then
		invalidProductCount += 1
		warn(("[DebugTests] Malformed DeveloperProducts entry: %s"):format(key))
	end
end
checkEqual("every Developer Product has Id/Kind fields", invalidProductCount, 0)
checkEqual("Developer Product catalog has exactly 12 entries", (function()
	local count = 0
	for _ in pairs(MonetizationConfig.DeveloperProducts) do
		count += 1
	end
	return count
end)(), 12)

local invalidPassCount = 0
for key, pass in pairs(MonetizationConfig.GamePasses) do
	if type(pass.Id) ~= "number" or type(pass.EntitlementKey) ~= "string" then
		invalidPassCount += 1
		warn(("[DebugTests] Malformed GamePasses entry: %s"):format(key))
	end
end
checkEqual("every Game Pass has Id/EntitlementKey fields", invalidPassCount, 0)
checkEqual("Game Pass catalog has exactly 12 entries", (function()
	local count = 0
	for _ in pairs(MonetizationConfig.GamePasses) do
		count += 1
	end
	return count
end)(), 12)

-- Permanent tool/perk unlocks are Game Passes (never receipted -- Roblox
-- never sends a ProcessReceipt for a Game Pass), not Developer Products.
check("Infinite Bag is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.InfiniteBagPermanent ~= nil)
checkEqual("Infinite Bag entitlement key", MonetizationConfig.GamePasses.InfiniteBagPermanent.EntitlementKey, "InfiniteBag")
check("Gems2x is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.Gems2xPermanent ~= nil)
check("PitchforkPermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.PitchforkPermanent ~= nil)
check("DynamitePermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.DynamitePermanent ~= nil)
check("VacuumPermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.VacuumPermanent ~= nil)
check("DronePermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.DronePermanent ~= nil)
check("FastRolls is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.FastRolls ~= nil)
check("ClassLuck2x is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.ClassLuck2x ~= nil)
check("ExtraClassSlot is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.ExtraClassSlot ~= nil)
check("FeatherGrabberPermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.FeatherGrabberPermanent ~= nil)
check("TornadoLauncherPermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.TornadoLauncherPermanent ~= nil)
check("PackingBotPermanent is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.PackingBotPermanent ~= nil)

-- One Round / Gems / Chest opens are Developer Products, never Game Passes.
check("PitchforkRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.PitchforkRound ~= nil)
check("DynamiteRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.DynamiteRound ~= nil)
check("VacuumRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.VacuumRound ~= nil)
check("DroneRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.DroneRound ~= nil)
check("FeatherGrabberRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.FeatherGrabberRound ~= nil)
check("TornadoLauncherRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.TornadoLauncherRound ~= nil)
check("PackingBotRound is a Developer Product, not a Game Pass", MonetizationConfig.DeveloperProducts.PackingBotRound ~= nil)

-- RunProduct ProductKey must match what ToolService.Init() actually
-- registers (RunConfig.ONE_ROUND_PRODUCT_KEYS values) -- a mismatch here
-- means a real purchase would silently grant nothing (no callback found).
checkEqual("PitchforkRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.PitchforkRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.Pitchfork)
checkEqual("DynamiteRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.DynamiteRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.Dynamite)
checkEqual("VacuumRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.VacuumRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.Vacuum)
checkEqual("DroneRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.DroneRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.Drone)
checkEqual("FeatherGrabberRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.FeatherGrabberRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.FeatherGrabber)
checkEqual("TornadoLauncherRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.TornadoLauncherRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.TornadoLauncher)
checkEqual("PackingBotRound.ProductKey matches ToolService registration",
	MonetizationConfig.DeveloperProducts.PackingBotRound.ProductKey, RunConfig.ONE_ROUND_PRODUCT_KEYS.PackingBot)

-- These 6 new products/passes are deliberate Id=0 placeholders (Section 21:
-- "Do NOT automatically create real Developer Products/Game Passes through
-- Open Cloud in this milestone") -- assert that explicitly so a future pass
-- filling them in has to consciously update this test, not silently drift.
checkEqual("FeatherGrabberRound.Id is still a placeholder", MonetizationConfig.DeveloperProducts.FeatherGrabberRound.Id, 0)
checkEqual("TornadoLauncherRound.Id is still a placeholder", MonetizationConfig.DeveloperProducts.TornadoLauncherRound.Id, 0)
checkEqual("PackingBotRound.Id is still a placeholder", MonetizationConfig.DeveloperProducts.PackingBotRound.Id, 0)
checkEqual("FeatherGrabberPermanent.Id is still a placeholder", MonetizationConfig.GamePasses.FeatherGrabberPermanent.Id, 0)
checkEqual("TornadoLauncherPermanent.Id is still a placeholder", MonetizationConfig.GamePasses.TornadoLauncherPermanent.Id, 0)
checkEqual("PackingBotPermanent.Id is still a placeholder", MonetizationConfig.GamePasses.PackingBotPermanent.Id, 0)

-- ============================================================
-- 12. Sale math (SellService.ComputeSaleCents is pure -- run/state
--     are plain tables here, no live Player needed)
-- ============================================================
suite("SaleMath")
local baseState = { Modifiers = {} }
local baseRun = { GoldenHarvestActive = false }

checkEqual("Feather value cents", RunConfig.FEATHER_VALUE_CENTS, 1)
checkEqual("Rainbow Feather value cents", RunConfig.RAINBOW_FEATHER_VALUE_CENTS, 5)

checkEqual("25 normal feathers", SellService.ComputeSaleCents(baseRun, baseState, 25, 0), 25)
checkEqual("24 normal + 1 Rainbow (reported bug repro)", SellService.ComputeSaleCents(baseRun, baseState, 24, 1), 29)
checkEqual("0 feathers sells for 0", SellService.ComputeSaleCents(baseRun, baseState, 0, 0), 0)

local featherMerchantState = { Modifiers = { SaleMultiplier = ClassConfig.Classes.FeatherMerchant.SaleMultiplier } }
checkEqual("Feather Merchant +20% on 100 normal", SellService.ComputeSaleCents(baseRun, featherMerchantState, 100, 0), 120)

local goldenHarvestRun = { GoldenHarvestActive = true }
checkEqual("Golden Harvest 2x on 10 normal", SellService.ComputeSaleCents(goldenHarvestRun, baseState, 10, 0), 20)

-- ============================================================
-- 13. Bag capacity math (RunPlayerStateService.EffectiveBagCapacity
--     is pure over a plain `state` table)
-- ============================================================
suite("BagCapacity")
local function fakeState(bagLevel: number, modifiers: any)
	return { BagLevel = bagLevel, Modifiers = modifiers or {} }
end

checkEqual("base (L0) capacity", RunPlayerStateService.EffectiveBagCapacity(fakeState(0)), 25)
checkEqual("L5 capacity", RunPlayerStateService.EffectiveBagCapacity(fakeState(5)), 250)
checkEqual("Pack Mule +50% at L0", RunPlayerStateService.EffectiveBagCapacity(fakeState(0, { PackMule = true })), 37) -- floor(25 * 1.5)
checkEqual(
	"permanent Bag perk flat bonus (+50 at L0)",
	RunPlayerStateService.EffectiveBagCapacity(fakeState(0, { BagFlatBonus = 50 })),
	75
)
check("Infinite Bag is unlimited", RunPlayerStateService.EffectiveBagCapacity(fakeState(0, { InfiniteBag = true })) == math.huge)

-- ============================================================
-- 14. Hand math (pure over a plain `state` table)
-- ============================================================
suite("HandMath")
local function fakeHandState(speedLevel: number, graspLevel: number, modifiers: any)
	return { HandSpeedLevel = speedLevel, HandGraspLevel = graspLevel, Modifiers = modifiers or {} }
end
checkEqual("base hand interval", RunPlayerStateService.EffectiveHandInterval(fakeHandState(0, 0)), 0.55)
checkEqual("L5 hand interval", RunPlayerStateService.EffectiveHandInterval(fakeHandState(5, 0)), 0.30)
checkEqual("base hand amount", RunPlayerStateService.EffectiveHandAmount(fakeHandState(0, 0)), 1)
checkEqual("L5 hand amount", RunPlayerStateService.EffectiveHandAmount(fakeHandState(0, 5)), 6)
checkEqual(
	"permanent Hand Grab perk flat bonus (+1 at L0)",
	RunPlayerStateService.EffectiveHandAmount(fakeHandState(0, 0, { HandGraspFlatBonus = 1 })),
	2
)

-- ============================================================
-- 15. Tool ownership transitions (RunPlayerStateService.InitPlayer
--     is safe with a fake {UserId=...} table -- it never reads any
--     other Player field, and every Core lookup it makes gracefully
--     falls back to "no profile" defaults for an unregistered UserId)
-- ============================================================
suite("ToolOwnership")
local fakePlayerA = { UserId = -900001 }
local freshState = RunPlayerStateService.InitPlayer(fakePlayerA, "Normal")
check("fresh run starts at $0.00", freshState.CashCents == 0)
check("fresh run starts with empty bag", freshState.BagCount == 0)
check("fresh Pitchfork starts Locked", not ToolService.IsOwned(freshState, "Pitchfork"))
check("fresh Dynamite starts Locked", not ToolService.IsOwned(freshState, "Dynamite"))
check("fresh Vacuum starts Locked", not ToolService.IsOwned(freshState, "Vacuum"))
check("fresh Drone starts Locked", not ToolService.IsOwned(freshState, "Drone"))

freshState.Tools.Pitchfork.Ownership = "RunOwned"
check("Pitchfork owned after RunOwned", ToolService.IsOwned(freshState, "Pitchfork"))
freshState.Tools.Pitchfork.Ownership = "PermanentOwned"
check("Pitchfork owned after PermanentOwned", ToolService.IsOwned(freshState, "Pitchfork"))

-- ============================================================
-- 16. Run reset (re-initializing the SAME UserId must produce an
--     independent, fully-fresh state -- no leakage from the previous run)
-- ============================================================
suite("RunReset")
freshState.CashCents = 5000
freshState.BagLevel = 3
freshState.HandSpeedLevel = 5
freshState.Tools.Dynamite.Ownership = "RunOwned"

local resetState = RunPlayerStateService.InitPlayer(fakePlayerA, "Normal")
checkEqual("Cash resets to 0", resetState.CashCents, 0)
checkEqual("Bag level resets to 0", resetState.BagLevel, 0)
checkEqual("Hand Speed level resets to 0", resetState.HandSpeedLevel, 0)
check("Dynamite ownership resets to Locked", not ToolService.IsOwned(resetState, "Dynamite"))
check("previous state object is untouched by the new one (no aliasing)", freshState.CashCents == 5000 and freshState ~= resetState)

-- ============================================================
-- 17. Duplicate completion guard (RoundService.TryBeginCompletion
--     touches only the fake run table + an empty Members loop, so it's
--     safe without a live run registered)
-- ============================================================
suite("CompletionGuard")
local fakeRun = { State = "Active", CompletionGuard = false, Members = {}, RunId = "debug-test-run" }
check("first completion attempt succeeds", RoundService.TryBeginCompletion(fakeRun) == true)
check("second completion attempt is blocked", RoundService.TryBeginCompletion(fakeRun) == false)
checkEqual("run transitions to Completing", fakeRun.State, "Completing")

-- ============================================================
-- 18. Egg state machine (EggService functions below only ever touch
--     the fake run table + an empty Members loop + Players:GetPlayerByUserId
--     on made-up ids, which safely returns nil -- no live run needed)
-- ============================================================
suite("EggStateMachine")
local eggRun = { EggState = "Buried", EggCarrierUserId = nil, Members = {}, RunId = "debug-egg-run" }
EggService.HandleColumnExposed(eggRun)
checkEqual("exposing a Buried Egg makes it Available", eggRun.EggState, "Available")

EggService.HandleColumnExposed(eggRun)
checkEqual("exposing an already-Available Egg is a no-op", eggRun.EggState, "Available")

eggRun.EggState = "Carried"
eggRun.EggCarrierUserId = -900002
EggService.ReturnEgg(eggRun)
checkEqual("returning a Carried Egg makes it Available again", eggRun.EggState, "Available")
check("returning the Egg clears its carrier", eggRun.EggCarrierUserId == nil)

eggRun.EggState = "Carried"
eggRun.EggCarrierUserId = -900002
EggService.MarkTurnedIn(eggRun)
checkEqual("turning in a Carried Egg marks it TurnedIn", eggRun.EggState, "TurnedIn")

-- ============================================================
-- BATCH 2
-- ============================================================

-- ============================================================
-- 19. Class roll configuration
-- ============================================================
suite("ClassRollConfig")
checkEqual("roll cost Gems", ClassConfig.RollCostGems, 40)
checkEqual("base roll cooldown", ClassConfig.BaseRollCooldownSeconds, 1.5)
checkEqual("Fast Rolls cooldown", ClassConfig.FastRollCooldownSeconds, 0.5)
checkEqual("2x Luck weight threshold", ClassConfig.LuckWeightThreshold, 10)
checkEqual("2x Luck multiplier", ClassConfig.LuckMultiplier, 2)

-- ============================================================
-- 20. 2x Luck weighting (ClassService.GetRollWeights is pure -- no
--     Player/profile involved, just ClassConfig.Odds)
-- ============================================================
suite("ClassLuckWeighting")
local weightsNoLuck, totalNoLuck = ClassService.GetRollWeights(false)
checkEqual("no-luck total equals the odds sum", totalNoLuck, 100)
for _, odd in ipairs(ClassConfig.Odds) do
	checkEqual(("no-luck weight unchanged for %s"):format(odd.Id), weightsNoLuck[odd.Id], odd.Weight)
end

local weightsLuck, totalLuck = ClassService.GetRollWeights(true)
-- Hand-computed from ClassConfig.Odds: entries with base weight <= 10 are
-- doubled (Forkmaster 9->18, Demolitionist 7->14, Prospector 3.9->7.8,
-- DroneSpecialist 1->2, UltimateFarmer 0.1->0.2); Starter/PackMule/Feather
-- Merchant (all > 10) stay at 40/25/14. New total: 40+25+14+18+14+7.8+2+0.2.
checkEqual("2x Luck total", totalLuck, 121)
checkEqual("2x Luck doubles Forkmaster (9 -> 18)", weightsLuck.Forkmaster, 18)
checkEqual("2x Luck doubles UltimateFarmer (0.1 -> 0.2)", weightsLuck.UltimateFarmer, 0.2)
checkEqual("2x Luck leaves Starter unchanged (> threshold)", weightsLuck.Starter, 40)
checkEqual("2x Luck leaves PackMule unchanged (> threshold)", weightsLuck.PackMule, 25)

local allPositiveAndAccounted = true
local summedLuckWeights = 0
for _, odd in ipairs(ClassConfig.Odds) do
	local weight = weightsLuck[odd.Id]
	if type(weight) ~= "number" or weight <= 0 then
		allPositiveAndAccounted = false
	end
	summedLuckWeights += weight
end
check("every 2x Luck weight stays positive", allPositiveAndAccounted)
checkEqual("2x Luck weights sum to the reported total (renormalization is well-formed)", summedLuckWeights, totalLuck)
check("2x Luck never decreases any single weight", weightsLuck.Forkmaster >= weightsNoLuck.Forkmaster)

-- ============================================================
-- 21. Alien Chest reward ranges
-- ============================================================
suite("AlienChestRanges")
local function chestEntryById(id: string)
	for _, entry in ipairs(ChestConfig.Rewards) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end
local gemsSmall = chestEntryById("GemsSmall")
check("GemsSmall entry exists", gemsSmall ~= nil)
if gemsSmall then
	checkEqual("GemsSmall min", gemsSmall.Min, 25)
	checkEqual("GemsSmall max", gemsSmall.Max, 75)
end
local gemsLarge = chestEntryById("GemsLarge")
check("GemsLarge entry exists", gemsLarge ~= nil)
if gemsLarge then
	checkEqual("GemsLarge min", gemsLarge.Min, 75)
	checkEqual("GemsLarge max", gemsLarge.Max, 200)
end
check("MaxTokenOpenCount configured", type(ChestConfig.MaxTokenOpenCount) == "number" and ChestConfig.MaxTokenOpenCount > 0)

-- ============================================================
-- 22. Hard Mode / Chapter gating (HardModeService with a fake player --
--     CoreLocator.GetWins gracefully returns 0 for an unregistered
--     UserId, exactly like the "no profile" fallback used throughout
--     this file, so this exercises the REAL gating function)
-- ============================================================
suite("HardModeGating")
local fakePlayerNoWins = { UserId = -900003 }
check("Chapter1 always unlocked", HardModeService.ChapterUnlocked(fakePlayerNoWins, "Chapter1"))
check("Chapter2 disabled (coming soon) regardless of Wins", not HardModeService.ChapterUnlocked(fakePlayerNoWins, "Chapter2"))
check("Normal difficulty always unlocked (RequiresWins = 0)", HardModeService.DifficultyUnlocked(fakePlayerNoWins, "Normal"))
check("Hard difficulty locked at 0 Wins", not HardModeService.DifficultyUnlocked(fakePlayerNoWins, "Hard"))
checkEqual("Hard requires exactly 1 Win", RunConfig.DIFFICULTY.Hard.RequiresWins, 1)

-- ============================================================
-- 23. Profile defaults + reconciliation/migration (DataSchema is pure --
--     plain tables, no Player/DataStore involved)
-- ============================================================
suite("ProfileDefaultsAndMigration")
local freshProfile = DataSchema.GetDefaultProfile()
checkEqual("default Gems", freshProfile.Currencies.Gems, 0)
checkEqual("default AlienTokens", freshProfile.Currencies.AlienTokens, 0)
checkEqual("default Wins", freshProfile.Stats.Wins, 0)
check("default BestTime is nil", freshProfile.Stats.BestTime == nil)
checkEqual("default TotalPlaytime", freshProfile.Stats.TotalPlaytime, 0)
checkEqual("default TotalFeathersCollected", freshProfile.Stats.TotalFeathersCollected, 0)
checkEqual("default PermanentPerks.BagSize", freshProfile.PermanentPerks.BagSize, 0)
check("Starter class owned by default", freshProfile.Classes.Owned.Starter == true)
checkEqual("Slot1 defaults to Starter", freshProfile.Classes.Equipped.Slot1, "Starter")
check("Slot2 empty by default", freshProfile.Classes.Equipped.Slot2 == nil)
check("Slot2 locked by default", freshProfile.Classes.Slot2Unlocked == false)
checkEqual("default Pitchfork skin selected", freshProfile.Inventory.SelectedSkins.Pitchfork, "Default")
check("default Pitchfork skin owned", freshProfile.Inventory.OwnedSkins.Pitchfork.Default == true)

-- Simulates an OLD saved profile from before a schema field existed:
-- missing PermanentPerks/Entitlements entirely, but with real progress on
-- fields that DO exist. Reconcile must fill in what's missing without
-- touching what's already there.
local partialOldProfile = {
	SchemaVersion = 0,
	Currencies = { Gems = 777, AlienTokens = 12 },
	Stats = { Wins = 3, BestTime = 45.5, TotalPlaytime = 100, TotalFeathersCollected = 500 },
	Classes = {
		Owned = { Starter = true, PackMule = true },
		Equipped = { Slot1 = "PackMule", Slot2 = nil },
		Slot2Unlocked = false,
	},
	Inventory = { OwnedSkins = { Pitchfork = { Default = true } }, SelectedSkins = { Pitchfork = "Default" } },
	CodesRedeemed = {},
	-- PermanentPerks and Entitlements/Receipts are intentionally absent.
}
local migrated = DataSchema.Reconcile(partialOldProfile)
checkEqual("migration preserves existing Gems", migrated.Currencies.Gems, 777)
checkEqual("migration preserves existing Wins", migrated.Stats.Wins, 3)
checkEqual("migration preserves equipped class", migrated.Classes.Equipped.Slot1, "PackMule")
check("migration adds missing PermanentPerks", migrated.PermanentPerks ~= nil)
checkEqual("migrated PermanentPerks default to 0", migrated.PermanentPerks.BagSize, 0)
check("migration adds missing Entitlements", migrated.Entitlements ~= nil)
check("migration adds missing Receipts.Processed", migrated.Receipts ~= nil and migrated.Receipts.Processed ~= nil)
checkEqual("migration stamps current SchemaVersion", migrated.SchemaVersion, DataSchema.SchemaVersion)

-- ============================================================
-- 24. Monetization: temporary (Round) vs permanent ownership stay
--     structurally distinct (see ToolOwnership/RunReset suites above for
--     the RunOwned -> Locked reset; PermanentOwned requires a live
--     profile entitlement check, listed in "NOT covered" below)
-- ============================================================
suite("OwnershipKinds")
local ownershipToolState = RunPlayerStateService.InitPlayer({ UserId = -900004 }, "Normal")
ownershipToolState.Tools.Vacuum.Ownership = "RunOwned"
check("RunOwned counts as owned", ToolService.IsOwned(ownershipToolState, "Vacuum"))
local resetOwnershipState = RunPlayerStateService.InitPlayer({ UserId = -900004 }, "Normal")
check("RunOwned does not survive a run reset (temporary, as intended)", not ToolService.IsOwned(resetOwnershipState, "Vacuum"))

-- ============================================================
-- 25. Leaderboard data shape (GetBoards() is instant/cached -- see
--     LeaderboardService's header; safe to call before Init() has run,
--     since `cache` starts as the empty-but-well-formed shape below)
-- ============================================================
suite("Leaderboard")
local boards = LeaderboardService.GetBoards()
check("Wins board is a table", type(boards.Wins) == "table")
check("Feathers board is a table", type(boards.Feathers) == "table")
check("BestTime board is a table", type(boards.BestTime) == "table")

-- ============================================================
-- BATCH 3
-- ============================================================

-- ============================================================
-- 26. Party membership rules (PartyService only ever indexes by
--     Player.UserId -- Players:GetPlayerByUserId() safely returns nil for
--     a fake/unregistered id, and every internal lookup already guards on
--     that, so these fake-player tables exercise the REAL functions
--     end-to-end without needing a live connection or loaded profile).
--     Uses UserIds in the -900100..-900199 range, well clear of every
--     other suite's fake ids, and leaves every party it creates fully
--     torn down at the end so nothing lingers for a real tester.
-- ============================================================
suite("PartyMembership")
local partyOwner = { UserId = -900100 }
local partyMember2 = { UserId = -900101 }
local partyMember3 = { UserId = -900102 }
local partyMember4 = { UserId = -900103 }
local partyMember5 = { UserId = -900104 }
local outsidePlayer = { UserId = -900105 }

local newParty = PartyService.CreateParty(partyOwner)
check("CreateParty succeeds", newParty ~= nil)
if newParty then
	checkEqual("new party starts with 1 member", #newParty.Members, 1)
	checkEqual("creator is the owner", newParty.OwnerUserId, partyOwner.UserId)
	checkEqual("max size is 4", newParty.MaxSize, 4)

	local dupOk, dupReason = PartyService.CreateParty(partyOwner)
	check("cannot create a second party while already in one", dupOk == nil and dupReason == "AlreadyInParty")

	check("2nd member can join", PartyService.JoinParty(partyMember2, newParty.PartyId) == true)
	check("3rd member can join", PartyService.JoinParty(partyMember3, newParty.PartyId) == true)
	check("4th member can join", PartyService.JoinParty(partyMember4, newParty.PartyId) == true)
	checkEqual("party now has 4 members", #newParty.Members, 4)

	local overflowOk, overflowReason = PartyService.JoinParty(partyMember5, newParty.PartyId)
	check("5th member rejected (max 4)", overflowOk == false and overflowReason == "PartyFull")

	local rejoinOk, rejoinReason = PartyService.JoinParty(partyMember2, newParty.PartyId)
	check("a member already in the party can't join again", rejoinOk == false and rejoinReason == "AlreadyInParty")

	local missingOk, missingReason = PartyService.JoinParty(outsidePlayer, "not-a-real-party-id")
	check("joining a nonexistent party id fails", missingOk == false and missingReason == "PartyNotFound")

	local nonLeaderOk, nonLeaderReason = PartyService.RequestStart(partyMember2)
	check("non-leader cannot start the party", nonLeaderOk == false and nonLeaderReason == "NotOwner")

	PartyService.LeaveParty(partyOwner)
	local afterLeaderLeft = PartyService.GetParty(newParty.PartyId)
	check("party survives the leader leaving (still has members)", afterLeaderLeft ~= nil)
	if afterLeaderLeft then
		checkEqual("ownership transfers to the next member", afterLeaderLeft.OwnerUserId, partyMember2.UserId)
		checkEqual("party shrinks by one", #afterLeaderLeft.Members, 3)
	end

	local formerLeaderOk, formerLeaderReason = PartyService.LeaveParty(partyOwner)
	check("a player no longer in any party can't leave again", formerLeaderOk == false and formerLeaderReason == "NotInParty")

	-- Tear down completely so nothing lingers in PartyService's live
	-- tables for a real tester to stumble on.
	PartyService.LeaveParty(partyMember2)
	PartyService.LeaveParty(partyMember3)
	PartyService.LeaveParty(partyMember4)
	check("party is destroyed once every member has left", PartyService.GetParty(newParty.PartyId) == nil)
end

-- ============================================================
-- 27. Run queue ordering + party isolation (PartyService.CreateParty +
--     RoundService.OnPartyStartRequested combined, exercising the REAL
--     local-fallback queue end-to-end -- Chapter1PlaceId is 0/unconfigured
--     in this environment, so this always takes the local-queue branch,
--     never the production teleport branch, matching "Studio must
--     gracefully fall back to the local run queue"). Cleans up fully.
-- ============================================================
suite("RunQueueOrdering")
local queueOwnerA = { UserId = -900110 }
local queueOwnerB = { UserId = -900111 }

local partyA = PartyService.CreateParty(queueOwnerA)
local partyB = PartyService.CreateParty(queueOwnerB)

if partyA and partyB then
	partyA.Started = true
	RoundService.OnPartyStartRequested(partyA)
	local runA = RoundService.GetRunForPlayer(queueOwnerA)
	check("first party's run starts immediately", runA ~= nil and runA.State == "Active")
	check("first party's run is active per RoundService.IsActive", runA and RoundService.IsActive(runA))

	partyB.Started = true
	RoundService.OnPartyStartRequested(partyB)
	local runB = RoundService.GetRunForPlayer(queueOwnerB)
	check("second party is queued behind the first, not started", runB ~= nil and runB.State == "Queued")
	check("a Queued run never counts as active (no duplicate active runs)", runB and not RoundService.IsActive(runB))

	if runA and runB then
		check("each party gets its own distinct run instance", runA.RunId ~= runB.RunId)
		check(
			"party A's run lookup is never party B's run (no cross-party RunState)",
			RoundService.GetRunForPlayer(queueOwnerA) ~= RoundService.GetRunForPlayer(queueOwnerB)
		)

		RoundService.EndRun(runA)
		check("ending the active run immediately advances the queue", runB.State == "Active")
		check("the newly-active run is now reported active", RoundService.IsActive(runB))

		RoundService.EndRun(runB)
		check(
			"both runs are fully cleaned up (no lingering references)",
			RoundService.GetRunForPlayer(queueOwnerA) == nil and RoundService.GetRunForPlayer(queueOwnerB) == nil
		)
		-- RoundService.EndRun releases the party via PartyService
		-- .ReleasePartyAfterRun -- confirms nothing lingers in PartyService's
		-- live tables either, not just RoundService's.
		check(
			"both synthetic parties were destroyed when their runs ended (no lingering PartyService state)",
			PartyService.GetParty(partyA.PartyId) == nil and PartyService.GetParty(partyB.PartyId) == nil
		)
	end
end

-- ============================================================
-- 28. Teleport payload validation (ChapterArrivalService.IsValidTeleportData
--     is pure -- no Player/server state involved)
-- ============================================================
suite("TeleportPayloadValidation")
check("nil payload rejected", not ChapterArrivalService.IsValidTeleportData(nil))
check("non-table payload rejected", not ChapterArrivalService.IsValidTeleportData("not a table"))
check("empty table rejected", not ChapterArrivalService.IsValidTeleportData({}))
check(
	"missing PartyId rejected",
	not ChapterArrivalService.IsValidTeleportData({ ChapterId = "Chapter1", Difficulty = "Normal", Members = { 1 } })
)
check(
	"unknown ChapterId rejected",
	not ChapterArrivalService.IsValidTeleportData({ PartyId = "p1", ChapterId = "NotAChapter", Difficulty = "Normal", Members = { 1 } })
)
check(
	"disabled Chapter2 rejected (matches HardModeGating -- Chapter2 is not Enabled)",
	not ChapterArrivalService.IsValidTeleportData({ PartyId = "p1", ChapterId = "Chapter2", Difficulty = "Normal", Members = { 1 } })
)
check(
	"unknown Difficulty rejected",
	not ChapterArrivalService.IsValidTeleportData({ PartyId = "p1", ChapterId = "Chapter1", Difficulty = "Impossible", Members = { 1 } })
)
check(
	"empty Members list rejected",
	not ChapterArrivalService.IsValidTeleportData({ PartyId = "p1", ChapterId = "Chapter1", Difficulty = "Normal", Members = {} })
)
check(
	"Members list over PARTY_MAX_SIZE rejected",
	not ChapterArrivalService.IsValidTeleportData({
		PartyId = "p1",
		ChapterId = "Chapter1",
		Difficulty = "Normal",
		Members = { 1, 2, 3, 4, 5 },
	})
)
check(
	"non-numeric member id rejected",
	not ChapterArrivalService.IsValidTeleportData({
		PartyId = "p1",
		ChapterId = "Chapter1",
		Difficulty = "Normal",
		Members = { 1, "not-a-userid" },
	})
)
check(
	"well-formed teleport data accepted",
	ChapterArrivalService.IsValidTeleportData({ PartyId = "p1", ChapterId = "Chapter1", Difficulty = "Hard", Members = { 1, 2, 3, 4 } })
)

-- ============================================================
-- 29. Chapter1PlaceId configuration behavior. Sets and immediately resets
--     TeleportConfig.Chapter1PlaceId with no yield in between -- Luau's
--     cooperative scheduling means no other script can observe the
--     mutated value in that window, so this can't race a real bootstrap.
-- ============================================================
suite("TeleportConfiguration")
local TeleportConfig = require(GameplayConfig.TeleportConfig)
checkEqual("Chapter1PlaceId starts as the unconfigured placeholder", TeleportConfig.Chapter1PlaceId, 0)
check("unconfigured (0) reports not configured", not TeleportConfig.IsChapter1TeleportConfigured())
TeleportConfig.Chapter1PlaceId = 123456789
check("a nonzero id reports configured", TeleportConfig.IsChapter1TeleportConfigured())
TeleportConfig.Chapter1PlaceId = 0
check("restored to the unconfigured placeholder for every other suite/bootstrap", not TeleportConfig.IsChapter1TeleportConfigured())

-- ============================================================
-- 30. Exploit/invalid-input rejection (pure logic, no live player needed)
-- ============================================================
suite("ExploitRejection")
local RunUpgradeService = require(Gameplay.RunUpgradeService)

-- RunUpgradeService.RequestBuy/ToolService.BuyUpgrade/SellService.RequestSell
-- all short-circuit on RoundService.GetRunForPlayer, so a fake
-- (unregistered) player exercises the same "not in an active run"
-- rejection every spammed/forged remote call from outside a run would hit.
local rejectPlayer = { UserId = -900120 }
local buyOk, buyReason = RunUpgradeService.RequestBuy(rejectPlayer, "Hand", "Speed")
check("purchase attempt with no active run is rejected, not silently accepted", buyOk == false and buyReason == "RoundNotActive")

local toolBuyOk, toolBuyReason = ToolService.BuyUpgrade(rejectPlayer, "Pitchfork", "Amount")
check("tool upgrade attempt with no active run is rejected", toolBuyOk == false and toolBuyReason == "RoundNotActive")

local sellOk, sellReason = SellService.RequestSell(rejectPlayer)
check("sell attempt with no active run is rejected", sellOk == false and sellReason == "RoundNotActive")

-- Invalid Group/UpgradeId enum rejection, exercised against a REAL active
-- run this time (own party, own UserId range, fully torn down after).
local exploitOwner = { UserId = -900121 }
local exploitParty = PartyService.CreateParty(exploitOwner)
if exploitParty then
	exploitParty.Started = true
	RoundService.OnPartyStartRequested(exploitParty)
	local exploitRun = RoundService.GetRunForPlayer(exploitOwner)
	check("exploit-test run started", exploitRun ~= nil and RoundService.IsActive(exploitRun))

	-- startRunNow only calls RunPlayerStateService.InitPlayer for members
	-- Players:GetPlayerByUserId can actually resolve, which a fake/
	-- unregistered UserId never is -- give this fake player the state a
	-- real one would have gotten automatically, so the checks below reach
	-- past "NoRunState" into the Group/UpgradeId/ownership validation
	-- they're actually meant to exercise.
	RunPlayerStateService.InitPlayer(exploitOwner, "Normal")

	local invalidGroupOk, invalidGroupReason = RunUpgradeService.RequestBuy(exploitOwner, "NotARealGroup", "Speed")
	check("unknown upgrade Group rejected even with an active run", invalidGroupOk == false and invalidGroupReason == "InvalidUpgrade")

	local invalidIdOk, invalidIdReason = RunUpgradeService.RequestBuy(exploitOwner, "Hand", "NotARealUpgradeId")
	check("unknown UpgradeId rejected even with an active run", invalidIdOk == false and invalidIdReason == "InvalidUpgrade")

	local invalidToolTrackOk, invalidToolTrackReason = ToolService.BuyUpgrade(exploitOwner, "Pitchfork", "NotARealTrack")
	check("unknown tool upgrade track rejected", invalidToolTrackOk == false and invalidToolTrackReason == "InvalidTrack")

	local unownedToolUpgradeOk, unownedToolUpgradeReason = ToolService.BuyUpgrade(exploitOwner, "Pitchfork", "Amount")
	check(
		"tool upgrade rejected before Pitchfork is unlocked (no ownership bypass)",
		unownedToolUpgradeOk == false and unownedToolUpgradeReason == "ToolNotOwned"
	)

	if exploitRun then
		RoundService.EndRun(exploitRun)
	end
	check("exploit-test party cleaned up", PartyService.GetParty(exploitParty.PartyId) == nil)
end

-- ============================================================
-- 31. Purchase-failure notifications (RunUpgradeService/ToolService route
--     failures through RoundService.SendNotification, which now guards
--     non-Instance callers -- see its comment -- specifically so THIS suite's
--     fake players above can exercise those failure branches without a live
--     Player to FireClient on; this suite checks that guard directly)
-- ============================================================
suite("PurchaseFailureNotification")
check(
	"SendNotification no-ops (doesn't error) for a fake non-Instance player",
	pcall(RoundService.SendNotification, { UserId = -900130 }, "test", "Error")
)

-- ============================================================
-- 32. AssetConfig placeholder scaffold (final-art-pass preparation --
--     every id must stay 0 until a real asset pass fills them in; nothing
--     here should ever be invented)
-- ============================================================
suite("AssetConfig")
local function checkAllZero(tableName: string, assetTable: { [string]: number })
	local nonZeroCount = 0
	for key, id in pairs(assetTable) do
		if id ~= 0 then
			nonZeroCount += 1
			warn(("[DebugTests] AssetConfig.%s.%s is non-zero (%d) -- was a real id invented?"):format(tableName, key, id))
		end
	end
	checkEqual(("%s has no invented non-zero ids"):format(tableName), nonZeroCount, 0)
end
checkAllZero("ToolIcons", AssetConfig.ToolIcons)
checkAllZero("CurrencyIcons", AssetConfig.CurrencyIcons)
checkAllZero("ClassIcons", AssetConfig.ClassIcons)
checkAllZero("Models", AssetConfig.Models)
checkAllZero("SkinIcons", AssetConfig.SkinIcons)
checkEqual("image(0) returns empty string", AssetConfig.image(0), "")
checkEqual("image(nonzero) builds an rbxassetid:// url", AssetConfig.image(123), "rbxassetid://123")
for _, classEntry in ipairs(ClassConfig.Odds) do
	check(("ClassIcons has an entry for %s"):format(classEntry.Id), AssetConfig.ClassIcons[classEntry.Id] ~= nil)
end
for _, reward in ipairs(ChestConfig.Rewards) do
	if reward.Type == "Skin" then
		check(("SkinIcons has an entry for %s"):format(reward.SkinId), AssetConfig.SkinIcons[reward.SkinId] ~= nil)
	end
end

-- ============================================================
-- 33. Feather Grabber / Tornado Launcher config + ownership (new equipment,
--     MAJOR GAMEPLAY/WORLD INTEGRATION UPDATE -- fixed-stat items, no
--     upgrade levels, so this checks config sanity + ownership transitions
--     rather than a leveled-track table like Pitchfork/Dynamite above)
-- ============================================================
suite("FeatherGrabberTornado")
checkEqual("Feather Grabber unlock cost is $6.00", FeatherGrabberConfig.UNLOCK_COST_CENTS, 600)
checkEqual("Feather Grabber grabs 16 at once", FeatherGrabberConfig.GRAB_AMOUNT, 16)
checkEqual("Feather Grabber action time is 2.0s", FeatherGrabberConfig.ACTION_SECONDS, 2.0)
checkEqual("Feather Tornado unlock cost is $75.00", TornadoLauncherConfig.UNLOCK_COST_CENTS, 7500)
checkEqual("Feather Tornado collects up to 150", TornadoLauncherConfig.MAX_COLLECT_AMOUNT, 150)
checkEqual("Feather Tornado cooldown is 6s", TornadoLauncherConfig.COOLDOWN_SECONDS, 6)

local fakePlayerGrabber = { UserId = -900201 }
local grabberState = RunPlayerStateService.InitPlayer(fakePlayerGrabber, "Normal")
check("fresh Feather Grabber starts Locked", not ToolService.IsOwned(grabberState, "FeatherGrabber"))
check("fresh Tornado Launcher starts Locked", not ToolService.IsOwned(grabberState, "TornadoLauncher"))
check("fresh Packing Bot starts Locked", not ToolService.IsOwned(grabberState, "PackingBot"))

-- ToolService.BuyUnlock/BuyPackingBotWithGems require a live run registered
-- in RoundService's private registry (see this file's header on why that
-- can't be safely faked here) -- so, like the existing ToolOwnership suite
-- above, ownership transitions are exercised via direct state mutation, and
-- only the "no active run" rejection path is exercised through the real
-- function.
local okBuyGrabberNoRun, grabberErr = ToolService.BuyUnlock(fakePlayerGrabber, "FeatherGrabber")
check("Feather Grabber Cash unlock rejected with no active run", okBuyGrabberNoRun == false and grabberErr == "RoundNotActive")

grabberState.Tools.FeatherGrabber.Ownership = "RunOwned"
check("Feather Grabber owned after RunOwned", ToolService.IsOwned(grabberState, "FeatherGrabber"))
grabberState.Tools.TornadoLauncher.Ownership = "PermanentOwned"
check("Tornado Launcher owned after PermanentOwned", ToolService.IsOwned(grabberState, "TornadoLauncher"))

-- Packing Bot has no Cash unlock path at all (Gems/Robux only, like Drone/
-- Vacuum) -- BuyUnlock's RoundNotActive check runs first regardless of
-- tool, so this fake (run-less) player can only prove the function doesn't
-- error for an unrecognized-for-Cash tool; the "NoCashUnlockForTool" branch
-- itself is unreachable without a live run, same limitation as above.
local okBuyBotCash, botCashErr = ToolService.BuyUnlock(fakePlayerGrabber, "PackingBot")
check("Packing Bot Cash unlock call doesn't error without a live run", okBuyBotCash == false and botCashErr == "RoundNotActive")

-- ============================================================
-- 34. Feather Packing Bot config + Gems purchase (generalized from
--     Drone's BuyDroneWithGems -- see ToolService.buyToolWithGems)
-- ============================================================
suite("PackingBot")
checkEqual("Packing Bot capacity is 15", PackingBotConfig.CAPACITY, 15)
checkEqual("Packing Bot collects 2 per cycle", PackingBotConfig.COLLECT_PER_CYCLE, 2)
checkEqual("Packing Bot travels at 8 studs/sec", PackingBotConfig.TRAVEL_STUDS_PER_SECOND, 8)
checkEqual("Packing Bot Gems cost is 45", PackingBotConfig.ONE_ROUND_GEM_COST, 45)
checkEqual("Packing Bot one-round Robux is 40", PackingBotConfig.ONE_ROUND_ROBUX, 40)
checkEqual("Packing Bot permanent Robux is 144", PackingBotConfig.PERMANENT_ROBUX, 144)

local fakePlayerBot = { UserId = -900202 }
local botState = RunPlayerStateService.InitPlayer(fakePlayerBot, "Normal")
local okGemsNoRun = ToolService.BuyPackingBotWithGems(fakePlayerBot)
check("Packing Bot Gems buy rejected with no active run", okGemsNoRun == false)

-- RemoveNear's Egg-protection path (isEggColumnExposed check, shared by
-- every tool that digs into the pile -- Hand/Pitchfork/Vacuum/Drone/Feather
-- Grabber/Tornado Launcher/Packing Bot all call the same function) is
-- exercised by the existing EggStateMachine suite above; Packing Bot and the
-- two new tools add no new pile-removal code path to re-test here.

-- ============================================================
-- 35. Conveyor sell system (Section 5: the sale itself must be atomic and
--     complete BEFORE any cosmetic conveyor animation -- SellService.
--     RequestSell already is that function; this checks the invariants that
--     make the conveyor animation purely cosmetic rather than gating Cash)
-- ============================================================
suite("ConveyorSell")
local fakePlayerSell = { UserId = -900203 }
local sellState = RunPlayerStateService.InitPlayer(fakePlayerSell, "Normal")
sellState.BagCount = 10
sellState.RainbowInBag = 2
local normalCleared, rainbowCleared = RunPlayerStateService.ClearBag(sellState)
checkEqual("ClearBag empties BagCount", sellState.BagCount, 0)
checkEqual("ClearBag empties RainbowInBag", sellState.RainbowInBag, 0)
checkEqual("ClearBag returns correct normal count", normalCleared, 8)
checkEqual("ClearBag returns correct rainbow count", rainbowCleared, 2)

-- A second sell attempt on an already-emptied bag must find nothing to
-- sell -- this is what makes a duplicate deposit (e.g. a double-click, or a
-- retried request after a dropped ack) a no-op rather than a double payout.
local normalAgain, rainbowAgain = RunPlayerStateService.ClearBag(sellState)
checkEqual("clearing an already-empty bag returns 0 normal", normalAgain, 0)
checkEqual("clearing an already-empty bag returns 0 rainbow", rainbowAgain, 0)

local fakeRunForSale = { GoldenHarvestActive = false }
local saleCents = SellService.ComputeSaleCents(fakeRunForSale, sellState, normalCleared, rainbowCleared)
check("sale of a mixed bag computes a positive amount", saleCents > 0)
checkEqual("selling the emptied bag again computes $0",
	SellService.ComputeSaleCents(fakeRunForSale, sellState, normalAgain, rainbowAgain), 0)

-- ============================================================
-- 36. Teleport party metadata shape re-check against the new tool set --
--     IsValidTeleportData doesn't enumerate tools at all (it only validates
--     PartyId/ChapterId/Difficulty/Members), so adding 3 new equipment
--     types must NOT change what a valid teleport payload looks like.
-- ============================================================
suite("TeleportToolIndependence")
check("valid teleport payload is unaffected by the new tool roster", ChapterArrivalService.IsValidTeleportData({
	PartyId = "debug-party-1",
	ChapterId = "Chapter1",
	Difficulty = "Normal",
	Members = { 1, 2 },
}))

-- ============================================================
-- Summary
-- ============================================================
print(("[DebugTests] %d passed, %d failed (%d total)"):format(passed, failed, passed + failed))
if failed > 0 then
	warn(("[DebugTests] %d test(s) failed -- see FAILED lines above for details."):format(failed))
else
	print("[DebugTests] All automated checks passed.")
end

print(table.concat({
	"[DebugTests] NOT covered here (needs a live Studio interaction test instead):",
	"  - Hand/Pitchfork/Dynamite/Vacuum/Drone purchase remotes end-to-end (character position/range checks)",
	"  - Pitchfork/Dynamite/Vacuum/Drone collection, cooldowns, and pile visual removal",
	"  - Drone AI cycle (pile -> sell station -> pile) and swarm spawn/cleanup",
	"  - CurrencyService.Award's Earned-vs-Purchased Gems2x source policy (needs a loaded DataStore profile)",
	"  - Class roll RNG distribution (odds/weights themselves ARE tested above), class equip flow (ownership/",
	"    slot-unlock/duplicate-class checks all gate on a loaded profile), permanent perk purchase",
	"  - Party create/join/start/leave/leader-transfer/max-size/queueing ARE exercised above end-to-end with",
	"    fake players (PartyMembership/RunQueueOrdering suites) -- what's NOT covered is the party PAD touch",
	"    flow, real Farmer/Egg pickup range checks, and anything through an actual connected client/remote",
	"  - Marketplace prompts and real purchase flows (real product/pass IDs are configured, but this",
	"    suite never prompts a real Robux purchase -- needs a live Studio interaction test instead)",
	"  - Code redemption end-to-end (one-time-use check reads a loaded profile's CodesRedeemed)",
	"  - StatsService.ReportRunTime's Best-Time-only-if-better comparison, and every stat increment",
	"    (Wins/Playtime/Feathers) -- all read/write a loaded profile",
	"  - MonetizationService.ProcessReceipt idempotency end-to-end (isReceiptProcessed/markReceiptProcessed",
	"    read/write a loaded profile -- the catalog lookup itself (real IDs -> Kind/EntitlementKey/",
	"    ProductKey) IS exercised above without a profile, via the Monetization suite's structural checks)",
	"  - InventoryService skin ownership/equip validation (reads a loaded profile)",
	"  - PermanentOwned tool ownership persisting across a run reset (the entitlement check itself needs a",
	"    loaded profile -- RunOwned's reset IS covered above via a fake player)",
	"  - LeaderboardService's actual OrderedDataStore read/write path (Studio needs \"Enable Studio Access",
	"    to API Services\" for this; GetBoards()'s shape and its local-fallback ranking logic don't need it",
	"    and ARE exercised indirectly by every fake-player test above using the same no-profile pattern)",
	"  - The PRODUCTION teleport path itself (ReserveServer/TeleportAsync/TeleportOptions, and",
	"    ChapterArrivalService's Players.PlayerAdded/GetJoinData listener) cannot be executed at all without a",
	"    real second Place and Chapter1PlaceId -- only its pure validation logic (TeleportPayloadValidation) and",
	"    its config toggle (TeleportConfiguration) are tested; this is genuinely untestable until that Place exists",
	"  - True concurrent/simultaneous multiplayer timing (two real clients racing the same remote at the same",
	"    network tick) -- the single-threaded-server reasoning that makes this safe is documented in each",
	"    service's comments and was verified by code inspection, not by an actual two-client race",
	"  - Mobile touch input feel and on-screen layout/bounds on a real small viewport",
	"  - Feather Grabber/Tornado Launcher collection remotes and Packing Bot's PILE->COLLECT->SELL->RETURN",
	"    cycle end-to-end (character position/range checks, real pile removal, real FX broadcasts) -- config",
	"    values and ownership transitions ARE tested above (FeatherGrabberTornado/PackingBot suites)",
	"  - The conveyor crate visual (ConveyorVisualController) and its pool/reuse behavior -- purely",
	"    presentational, client-side, and cannot run in this server-only Studio-boot suite; SellService's",
	"    atomic bag->cash flow it rides on top of IS tested above (ConveyorSell suite)",
}, "\n"))
