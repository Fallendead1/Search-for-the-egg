--!strict
-- Single place that prompts Robux purchases. All product/pass ids come from
-- the shared MonetizationConfig (owned by Agent 1); when an id isn't
-- configured yet, calls here are no-ops and callers should disable the
-- triggering button via Theme.setButtonEnabled instead of erroring.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local MonetizationController = {}

local player = Players.LocalPlayer

function MonetizationController.promptProduct(key: string)
	local productId = DisplayConfig.getProductId(key)
	if not productId then
		warn(("[MonetizationController] Product '%s' has no configured id yet."):format(key))
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

function MonetizationController.promptGamePass(key: string)
	local passId = DisplayConfig.getPassId(key)
	if not passId then
		warn(("[MonetizationController] Game pass '%s' has no configured id yet."):format(key))
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, passId)
end

function MonetizationController.hasProduct(key: string): boolean
	return DisplayConfig.getProductId(key) ~= nil
end

function MonetizationController.hasGamePass(key: string): boolean
	return DisplayConfig.getPassId(key) ~= nil
end

-- Ownership of a one-time Developer Product grant (Kind = "Entitlement" in
-- MonetizationConfig, e.g. PitchforkPermanent/FastRolls/ClassLuck2x/
-- ExtraClassSlot). Unlike a Game Pass, Roblox has no client-queryable
-- ownership API for these -- the only source of truth is the server's own
-- profile, mirrored into PlayerState.Profile.EntitlementSummary via
-- Core_ProfileUpdated.
function MonetizationController.ownsEntitlement(key: string): boolean
	return PlayerState.Profile.EntitlementSummary[key] == true
end

function MonetizationController.ownsGamePass(key: string): boolean
	local passId = DisplayConfig.getPassId(key)
	if not passId then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns == true
end

function MonetizationController.init() end

return MonetizationController
