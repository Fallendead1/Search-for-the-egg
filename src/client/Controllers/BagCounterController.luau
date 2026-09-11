--!strict
-- Opens the Shop's BAG tab from a physical in-world Bag-upgrade counter,
-- instead of only the LEFT "SHOP" menu button. Purely a client-side UI
-- affordance (ProximityPrompt) -- the purchase itself still goes through
-- Gameplay_RequestBuyRunUpgrade and is fully server-validated, so there's
-- no trust concern in opening the panel locally.
--
-- Tag every physical Bag-upgrade counter Part/Model in Studio with
-- SFTE_BagUpgradeCounter. If none is tagged yet, the Shop's BAG tab stays
-- reachable via the LEFT "SHOP" button, so this is a safe no-op in Studio
-- before the map is tagged.

local CollectionService = game:GetService("CollectionService")

local BagCounterController = {}

local TAG = "SFTE_BagUpgradeCounter"

local ShopController

local function getAnchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance :: BasePart
	elseif instance:IsA("Model") then
		local model = instance :: Model
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function attachPrompt(instance: Instance)
	local part = getAnchorPart(instance)
	if not part or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BagUpgradePrompt"
	prompt.ActionText = "Upgrade Bag"
	prompt.ObjectText = "Bag Counter"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = part

	prompt.Triggered:Connect(function()
		ShopController.open("BAG")
	end)
end

function BagCounterController.init(shopController: any)
	ShopController = shopController

	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
		attachPrompt(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(attachPrompt)
end

return BagCounterController
