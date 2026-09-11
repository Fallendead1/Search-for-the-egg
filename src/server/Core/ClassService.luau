--[[
	Server-authoritative class rolling, equipping, and passive-modifier
	aggregation. The client never submits a chosen roll result -- RNG always
	happens here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.ClassConfig)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local ClassService = {}

local lastRollAtClock = {} :: { [Player]: number }

local function getRollCooldownSeconds(player: Player): number
	local MonetizationService = require(script.Parent.MonetizationService)
	if MonetizationService.OwnsEntitlement(player, "FastRolls") then
		return ClassConfig.FastRollCooldownSeconds
	end
	return ClassConfig.BaseRollCooldownSeconds
end

local function hasClassLuck2x(player: Player): boolean
	local MonetizationService = require(script.Parent.MonetizationService)
	return MonetizationService.OwnsEntitlement(player, "ClassLuck2x")
end

local function rollWeighted(hasLuck: boolean): string
	local weights = {}
	local total = 0

	for _, entry in ClassConfig.Odds do
		local weight = entry.Weight
		if hasLuck and weight <= ClassConfig.LuckWeightThreshold then
			weight *= ClassConfig.LuckMultiplier
		end
		weights[entry.Id] = weight
		total += weight
	end

	local roll = math.random() * total
	local cursor = 0
	for _, entry in ClassConfig.Odds do
		cursor += weights[entry.Id]
		if roll <= cursor then
			return entry.Id
		end
	end

	return ClassConfig.Odds[1].Id
end

function ClassService.RollClass(player: Player): (boolean, any)
	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end

	local now = os.clock()
	local cooldown = getRollCooldownSeconds(player)
	local last = lastRollAtClock[player]
	if last and (now - last) < cooldown then
		return false, "Cooldown"
	end

	if not CurrencyService.TrySpend(player, "Gems", ClassConfig.RollCostGems, "ClassRoll") then
		return false, "InsufficientGems"
	end

	lastRollAtClock[player] = now

	local classId = rollWeighted(hasClassLuck2x(player))

	local profile = DataService.GetProfile(player)
	local isNew = not profile.Classes.Owned[classId]
	profile.Classes.Owned[classId] = true

	DataService.PushProfileUpdated(player)

	return true, {
		ClassId = classId,
		IsNew = isNew,
		DisplayName = ClassConfig.Classes[classId].DisplayName,
	}
end

function ClassService.EquipClass(player: Player, slotIndex: number, classId: string): (boolean, string?)
	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end
	if slotIndex ~= 1 and slotIndex ~= 2 then
		return false, "InvalidSlot"
	end
	if not ClassConfig.Classes[classId] then
		return false, "InvalidClass"
	end

	local profile = DataService.GetProfile(player)

	if not profile.Classes.Owned[classId] then
		return false, "NotOwned"
	end

	if slotIndex == 2 and not profile.Classes.Slot2Unlocked then
		return false, "Slot2Locked"
	end

	local otherSlotClass = (slotIndex == 1) and profile.Classes.Equipped.Slot2 or profile.Classes.Equipped.Slot1
	if otherSlotClass == classId then
		return false, "DuplicateClass"
	end

	if slotIndex == 1 then
		profile.Classes.Equipped.Slot1 = classId
	else
		profile.Classes.Equipped.Slot2 = classId
	end

	DataService.PushProfileUpdated(player)
	return true
end

function ClassService.UnlockSlot2(player: Player): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	if not profile.Classes.Slot2Unlocked then
		profile.Classes.Slot2Unlocked = true
		DataService.PushProfileUpdated(player)
	end
	return true
end

local function applyClassModifiers(modifiers, def)
	if def.BagCapacityMultiplier then
		modifiers.BagCapacityMultiplier *= def.BagCapacityMultiplier
	end
	if def.SaleMultiplier then
		modifiers.SaleMultiplier *= def.SaleMultiplier
	end
	if def.PitchforkYieldMultiplier then
		modifiers.PitchforkYieldMultiplier *= def.PitchforkYieldMultiplier
	end
	if def.PitchforkUpgradeCostMultiplier then
		modifiers.PitchforkUpgradeCostMultiplier *= def.PitchforkUpgradeCostMultiplier
	end
	if def.DynamiteRadiusMultiplier then
		modifiers.DynamiteRadiusMultiplier *= def.DynamiteRadiusMultiplier
	end
	if def.DynamiteMiniChargeChance then
		modifiers.DynamiteMiniChargeChance = math.max(modifiers.DynamiteMiniChargeChance, def.DynamiteMiniChargeChance)
	end
	if def.ProspectorEnabled then
		modifiers.ProspectorEnabled = true
	end
	if def.DroneAlwaysOwned then
		modifiers.DroneAlwaysOwned = true
	end
	if def.DroneSpeedMultiplier then
		modifiers.DroneSpeedMultiplier *= def.DroneSpeedMultiplier
	end
	if def.DroneCapacityMultiplier then
		modifiers.DroneCapacityMultiplier *= def.DroneCapacityMultiplier
	end
	if def.DroneSwarmChance then
		modifiers.DroneSwarmChance = math.max(modifiers.DroneSwarmChance, def.DroneSwarmChance)
	end
	if def.UltimateFarmer then
		modifiers.UltimateFarmer = true
	end
	if def.GoldenHarvestEnabled then
		modifiers.GoldenHarvestEnabled = true
	end
	if def.GoldenHarvestChance then
		modifiers.GoldenHarvestChance = math.max(modifiers.GoldenHarvestChance, def.GoldenHarvestChance)
	end
end

local function freshModifiers()
	return {
		BagCapacityMultiplier = 1,
		SaleMultiplier = 1,
		PitchforkYieldMultiplier = 1,
		PitchforkUpgradeCostMultiplier = 1,
		DynamiteRadiusMultiplier = 1,
		DynamiteMiniChargeChance = 0,
		ProspectorEnabled = false,
		DroneAlwaysOwned = false,
		DroneSpeedMultiplier = 1,
		DroneCapacityMultiplier = 1,
		DroneSwarmChance = 0,
		UltimateFarmer = false,
		GoldenHarvestEnabled = false,
		GoldenHarvestChance = 0,
	}
end

-- Raw, unnormalized modifiers contributed by equipped class passives only
-- (no permanent perks). MetaProgressionService.GetGameplayModifiers folds
-- these together with perk-derived modifiers for the final normalized table.
function ClassService.GetEffectiveClassModifiers(player: Player)
	local modifiers = freshModifiers()

	local profile = DataService.GetProfile(player)
	if not profile then
		return modifiers
	end

	local equippedIds = { profile.Classes.Equipped.Slot1, profile.Classes.Equipped.Slot2 }

	local hasUltimateFarmer = false
	for _, id in equippedIds do
		if id == "UltimateFarmer" then
			hasUltimateFarmer = true
		end
	end

	if hasUltimateFarmer then
		-- Ultimate Farmer already represents every base class's passives, so
		-- apply each base class once (not stacked with any other equipped
		-- class) rather than double-applying overlapping bonuses.
		for classId, def in ClassConfig.Classes do
			if classId ~= "UltimateFarmer" then
				applyClassModifiers(modifiers, def)
			end
		end
		applyClassModifiers(modifiers, ClassConfig.Classes.UltimateFarmer)
		return modifiers
	end

	for _, id in equippedIds do
		if id and ClassConfig.Classes[id] then
			applyClassModifiers(modifiers, ClassConfig.Classes[id])
		end
	end

	return modifiers
end

local Players = game:GetService("Players")
Players.PlayerRemoving:Connect(function(player)
	lastRollAtClock[player] = nil
end)

return ClassService
