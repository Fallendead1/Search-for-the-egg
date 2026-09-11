--!strict
-- Single place that prompts Robux purchases. All product/pass ids come from
-- the shared MonetizationConfig (owned by Agent 1); when an id isn't
-- configured yet, calls here are no-ops and callers should disable the
-- triggering button via Theme.setButtonEnabled instead of erroring.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)

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
