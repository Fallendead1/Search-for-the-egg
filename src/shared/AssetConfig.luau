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

--[[
	Final-art pass (Open Cloud uploads under the game's Group creator,
	506801379) from the local UI pack at
	C:/Users/mali7/OneDrive/Desktop/RobloxAssetFactory/output/search-for-the-egg-ui.
	IMPORTANT: every id below is the DECAL'S TEXTURE id, not the outer Decal
	asset id Open Cloud returns from the upload -- uploading with
	assetType="Decal" creates a Decal wrapper Instance whose OWN id is not a
	directly-renderable Image source; only its .Texture id is (confirmed live
	in Studio: the wrapper id's ImageLabel.IsLoaded stayed false forever,
	while its resolved .Texture id loaded immediately). Every Universe also
	needed an explicit "Use" grant via the Open Cloud asset-permissions-api
	(PATCH /asset-permissions-api/v1/assets/permissions, subjectType
	"Universe") before any of these would load at all -- uploads default to
	private. Ids intentionally left at 0 either have no source art yet
	(07-party's Hard difficulty / Create / Cancel / Friends Only /
	Matchmaking / party-member, and every 08-hud/09-reusable/10-icons entry
	-- those folders don't exist yet) or were uploaded but not wired in
	because the art bakes in numbers/wording that don't match the real
	config (e.g. Gem packs of 25/1000 that have no real Developer Product, or
	class description text for a mismatched mechanic) -- see the UI
	integration report for the full list.
]]

-- Daily Rewards: one full card background (day number + icon + amount
-- already baked in, matching DailyRewardController.DAYS exactly) per day,
-- plus the 3 claim-state button faces.
AssetConfig.DailyRewardCards = {
	Day1 = 110694398782296,
	Day2 = 107618861902597,
	Day3 = 78771389657288,
	Day4 = 110907082963287,
	Day5 = 111758620442943,
	Day6 = 125672920031347,
	Day7 = 75702668620712,
	Day8 = 84512152272082,
}
AssetConfig.DailyRewardStates = {
	Claim = 137940131265943,
	Locked = 80840224347103,
	Claimed = 70809168236905,
}

-- Left-side Lobby menu tiles (icon + label baked into one image each).
AssetConfig.SideMenuCards = {
	SHOP = 137580890850863,
	CLASSES = 82158825887690,
	STATS = 105424859298603,
}

-- Shop's permanent Gem-cost perk cards (DisplayConfig.PermanentPerks ids).
AssetConfig.ShopPerkCards = {
	BagSize = 125920442415879,
	HandGrabAmount = 101314875100434,
	FeatherValue = 130801486542925,
	GemValue = 92545935308812,
}

-- Real Robux Gem pack cards (DisplayConfig.GemPacks ids) -- only Gems100/
-- Gems400 exist as real Developer Products (see MonetizationConfig), so
-- that's the only 2 wired in even though the source pack also included
-- 25/1000 art with no matching product.
AssetConfig.GemPackCards = {
	Gems100 = 74293309710160,
	Gems400 = 111174548280746,
}

-- Class list row cards (icon + name + odds baked in -- ClassConfig.Odds/
-- DisplayName were updated to match these exactly) and the OWNED/EQUIPPED/
-- LOCKED state badges, keyed by the real ClassConfig id (never renamed --
-- see ClassConfig.luau's header comment).
AssetConfig.ClassCards = {
	Starter = 133331072009589, -- Nestling
	PackMule = 85160439271284, -- Feather Hauler
	FeatherMerchant = 135200030011637, -- Coop Trader
	Forkmaster = 96368449729534, -- Pile Raker
	Demolitionist = 130240483545771, -- Blast Keeper
	Prospector = 112092237242398, -- Gem Rooster
	DroneSpecialist = 133179085379580, -- Storm Builder
	UltimateFarmer = 78063768485226, -- Egg Oracle
}
AssetConfig.ClassStates = {
	Owned = 117020703499082,
	Equipped = 78218535440474,
	Locked = 96300817345071,
}
-- Class description-panel backgrounds: only for the 4 classes whose baked
-- bonus text is exactly accurate for the real (unrenamed) mechanic behind
-- them. Forkmaster/Demolitionist/Prospector/DroneSpecialist keep the plain
-- dynamic text panel because their baked art describes a DIFFERENT bonus
-- (Grabber/two-stat-Dynamite/flat-Gems%/Tornado-cooldown) than what those
-- classes actually do server-side -- using it would show players an
-- inaccurate description.
AssetConfig.ClassDescriptionCards = {
	Starter = 80823149042529,
	PackMule = 107571127955962,
	FeatherMerchant = 94681684634176,
	UltimateFarmer = 113216481082440,
}

-- Party map preview (Chapter1 only -- Chapter2 has no released map yet) and
-- difficulty-button faces. The real game only has Normal/Hard difficulties
-- (see DisplayConfig.Chapters) -- there is no "Easy" difficulty at all, so
-- 07-party/difficulty-easy.png is uploaded but deliberately NOT wired in
-- here (it would show a selectable difficulty that doesn't exist). Hard has
-- no source art yet, so it keeps the plain text button.
AssetConfig.PartyMapPreviews = {
	Chapter1 = 124899936153163,
}
AssetConfig.PartyDifficultyButtons = {
	Normal = 136829264329931,
}

return AssetConfig
