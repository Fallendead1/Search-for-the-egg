--[[
	Persistent tool skin/variant ownership and selection. Categories are
	Pitchfork, Dynamite, Vacuum, Drone. Alien-chest variants are cosmetic
	skins only -- no special stats are defined for them.
]]

local DataService = require(script.Parent.DataService)

local InventoryService = {}

local VALID_CATEGORIES = {
	Pitchfork = true,
	Dynamite = true,
	Vacuum = true,
	Drone = true,
}

function InventoryService.OwnsSkin(player: Player, category: string, skinId: string): boolean
	if not VALID_CATEGORIES[category] then
		return false
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	local owned = profile.Inventory.OwnedSkins[category]
	return owned ~= nil and owned[skinId] == true
end

function InventoryService.GrantSkin(player: Player, category: string, skinId: string, reason: string?): boolean
	if not VALID_CATEGORIES[category] or type(skinId) ~= "string" then
		return false
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end

	local owned = profile.Inventory.OwnedSkins[category]
	if not owned then
		owned = {}
		profile.Inventory.OwnedSkins[category] = owned
	end

	owned[skinId] = true
	return true
end

function InventoryService.SetSelectedSkin(player: Player, category: string, skinId: string): (boolean, string?)
	if not VALID_CATEGORIES[category] then
		return false, "InvalidCategory"
	end
	if not InventoryService.OwnsSkin(player, category, skinId) then
		return false, "NotOwned"
	end

	local profile = DataService.GetProfile(player)
	profile.Inventory.SelectedSkins[category] = skinId

	DataService.PushProfileUpdated(player)
	return true
end

function InventoryService.GetSelectedSkin(player: Player, category: string): string?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	return profile.Inventory.SelectedSkins[category]
end

return InventoryService
