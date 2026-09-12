--[[
	Single centralized place to fill in real asset ids once the final art
	pass happens. Every id below is a placeholder (0 = unset, matching the
	same "configurable 0 placeholder" convention already used by
	TeleportConfig.Chapter1PlaceId and MonetizationConfig's product ids) --
	nothing here is a real Roblox asset id, and none should ever be invented.

	This module is deliberately NOT wired into every UI element: plain
	Roblox-native controls (buttons, panels, text) keep using Theme's solid
	colors/fonts and need no asset id at all. Only entries that will
	eventually need a real image/mesh/model id live here, so the future asset
	pass has one place to fill them in instead of hunting through every
	controller and service.

	AssetConfig.image(id) / AssetConfig.mesh(id) return "" for an unset (0)
	id -- callers should treat "" as "no icon yet, fall back to
	color/text-only presentation", never as an error.
]]

local AssetConfig = {}

function AssetConfig.image(id: number): string
	if id == 0 then
		return ""
	end
	return "rbxassetid://" .. tostring(id)
end
AssetConfig.mesh = AssetConfig.image

-- Tool hotbar / upgrade-book icons.
AssetConfig.ToolIcons = {
	Hand = 0,
	Bag = 0,
	Pitchfork = 0,
	Dynamite = 0,
	Vacuum = 0,
	Drone = 0,
	FeatherGrabber = 0,
	TornadoLauncher = 0,
	PackingBot = 0,
}

-- Currency icons (Cash/Gems/AlienTokens toast + HUD readouts).
AssetConfig.CurrencyIcons = {
	Cash = 0,
	Gems = 0,
	AlienTokens = 0,
}

-- One entry per ClassConfig class id (see MetaConfig/ClassConfig.luau) --
-- kept in sync manually since class ids rarely change.
AssetConfig.ClassIcons = {
	Starter = 0,
	PackMule = 0,
	FeatherMerchant = 0,
	Forkmaster = 0,
	Demolitionist = 0,
	Prospector = 0,
	DroneSpecialist = 0,
	UltimateFarmer = 0,
}

-- World/collectible models. These are placed in Studio directly today (see
-- RunConfig.TAGS for the map-tag contract) rather than spawned from an
-- asset id -- these entries exist for the future pass that replaces
-- placeholder geometry with real modeled/meshed instances.
AssetConfig.Models = {
	Egg = 0,
	Feather = 0,
	RainbowFeather = 0,
	Farmer = 0,
	Chicken = 0,
	SellStation = 0,
	EventChest = 0,
}

-- Alien Chest reward skins (see MetaConfig/ChestConfig.luau's Rewards list)
-- -- one icon/model id per SkinId.
AssetConfig.SkinIcons = {
	AlienDynamite = 0,
	AlienVacuum = 0,
	AlienSquidfork = 0,
	UFO = 0,
}

-- Seasonal/limited chest or model variants. Empty until an actual event is
-- designed -- add entries here (never invent ids) when one is.
AssetConfig.EventVariants = {}

-- Daily Rewards card icons (see MetaConfig/DailyRewardConfig + client
-- DailyRewardController). Gem = every normal day; Chest = a Milestone day
-- (2/5); PremiumChest = Day 8's premium-looking card.
AssetConfig.DailyRewardIcons = {
	Gem = 0,
	Chest = 0,
	PremiumChest = 0,
}

return AssetConfig
