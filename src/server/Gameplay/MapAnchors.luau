--[[
	Discovers Studio-built map objects (pile origin, sell station, Farmer,
	red button, chickens) via CollectionService tags instead of hardcoded
	Workspace paths, so this system never has to remap or delete
	Studio-authored map assets. Falls back to a safe default (and warns once)
	when a tag isn't present yet, so the loop is still testable before the
	real map is tagged.
]]

local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local MapAnchors = {}

local warned = {}
local function warnOnce(tagName: string, fallbackDescription: string)
	if warned[tagName] then
		return
	end
	warned[tagName] = true
	warn(("[Gameplay] No instance tagged '%s' found; using fallback (%s)."):format(tagName, fallbackDescription))
end

local function firstTagged(tagName: string): Instance?
	local tagged = CollectionService:GetTagged(tagName)
	return tagged[1]
end

function MapAnchors.GetPilePosition(): Vector3
	local anchor = firstTagged(RunConfig.TAGS.PileOrigin)
	if anchor and anchor:IsA("BasePart") then
		return anchor.Position
	end
	warnOnce(RunConfig.TAGS.PileOrigin, "Vector3.new(0, 0, 0)")
	return Vector3.new(0, 0, 0)
end

function MapAnchors.GetSellStationPosition(): Vector3
	local anchor = firstTagged(RunConfig.TAGS.SellStation)
	if anchor and anchor:IsA("BasePart") then
		return anchor.Position
	end
	warnOnce(RunConfig.TAGS.SellStation, "Vector3.new(20, 0, 0)")
	return Vector3.new(20, 0, 0)
end

function MapAnchors.GetFarmerPosition(): Vector3
	local anchor = firstTagged(RunConfig.TAGS.Farmer)
	if anchor then
		if anchor:IsA("BasePart") then
			return anchor.Position
		elseif anchor:IsA("Model") and anchor.PrimaryPart then
			return anchor.PrimaryPart.Position
		end
	end
	warnOnce(RunConfig.TAGS.Farmer, "Vector3.new(-20, 0, 0)")
	return Vector3.new(-20, 0, 0)
end

function MapAnchors.GetRedButtonPart(): BasePart?
	local anchor = firstTagged(RunConfig.TAGS.RedButton)
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end
	warnOnce(RunConfig.TAGS.RedButton, "secret button disabled until tagged")
	return nil
end

function MapAnchors.GetChickens(): { Instance }
	return CollectionService:GetTagged(RunConfig.TAGS.Chicken)
end

-- Every tagged Lobby party pad (SFTE_PartyPad), in no particular order. See
-- PartyPadService for how these are turned into create/join touch zones.
function MapAnchors.GetPartyPads(): { Instance }
	local tagged = CollectionService:GetTagged(RunConfig.TAGS.PartyPad)
	if #tagged == 0 then
		warnOnce(RunConfig.TAGS.PartyPad, "no physical party pads -- only the fallback UI create button will work")
	end
	return tagged
end

-- Every tagged Bag-upgrade counter (SFTE_BagUpgradeCounter). See the client
-- BagCounterController for how these open the Shop's BAG tab.
function MapAnchors.GetBagUpgradeCounters(): { Instance }
	local tagged = CollectionService:GetTagged(RunConfig.TAGS.BagUpgradeCounter)
	if #tagged == 0 then
		warnOnce(RunConfig.TAGS.BagUpgradeCounter, "Bag upgrade stays reachable only via the Shop button")
	end
	return tagged
end

function MapAnchors.GetSafeEggFallbackPosition(): Vector3
	local anchor = firstTagged(RunConfig.TAGS.SafeEggFallback)
	if anchor and anchor:IsA("BasePart") then
		return anchor.Position
	end
	return MapAnchors.GetPilePosition()
end

return MapAnchors
