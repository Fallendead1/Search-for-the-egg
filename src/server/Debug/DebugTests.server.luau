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

local Gameplay = ServerScriptService.SearchForTheEgg.Gameplay
local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local MetaConfig = ReplicatedStorage.SearchForTheEgg.MetaConfig

local BagConfig = require(GameplayConfig.BagConfig)
local HandConfig = require(GameplayConfig.HandConfig)
local PitchforkConfig = require(GameplayConfig.PitchforkConfig)
local DynamiteConfig = require(GameplayConfig.DynamiteConfig)
local VacuumConfig = require(GameplayConfig.VacuumConfig)
local DroneConfig = require(GameplayConfig.DroneConfig)
local RunConfig = require(GameplayConfig.RunConfig)
local ClassConfig = require(MetaConfig.ClassConfig)
local ChestConfig = require(MetaConfig.ChestConfig)
local PermanentPerksConfig = require(MetaConfig.PermanentPerksConfig)
local MonetizationConfig = require(MetaConfig.MonetizationConfig)
local RewardConfig = require(MetaConfig.RewardConfig)

local RunPlayerStateService = require(Gameplay.RunPlayerStateService)
local ToolService = require(Gameplay.ToolService)
local SellService = require(Gameplay.SellService)
local RoundService = require(Gameplay.RoundService)
local EggService = require(Gameplay.EggService)

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
check("Infinite Bag permanent entitlement configured", MonetizationConfig.DeveloperProducts.InfiniteBagPermanent ~= nil)
checkEqual("Infinite Bag entitlement key", MonetizationConfig.DeveloperProducts.InfiniteBagPermanent.EntitlementKey, "InfiniteBag")
check("Gems2x is a Game Pass, not a Developer Product", MonetizationConfig.GamePasses.Gems2xPermanent ~= nil)

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
	"  - Hand/Pitchfork/Dynamite/Vacuum/Drone purchase remotes end-to-end (character position/range checks, real RoundService run registry)",
	"  - Pitchfork/Dynamite/Vacuum/Drone collection, cooldowns, and pile visual removal",
	"  - Drone AI cycle (pile -> sell station -> pile) and swarm spawn/cleanup",
	"  - CurrencyService.Award's Earned-vs-Purchased Gems2x source policy (needs a loaded DataStore profile)",
	"  - Class roll RNG distribution, class equip flow, permanent perk purchase",
	"  - Party create/join/start, queueing, and Farmer/Egg pickup range checks",
	"  - Hard Mode unlock gating end-to-end (HardModeService reads live Wins via a loaded profile)",
	"  - Marketplace prompts (no real product/pass IDs exist yet -- see MonetizationConfig)",
}, "\n"))
