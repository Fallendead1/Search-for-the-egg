--!strict
-- Opens the Shop / Classes panels from the physical Lobby NPC stands
-- (ShopKeeperNPC / ClassTrainerNPC under Workspace.SearchForTheEgg_Lobby),
-- same pattern as BagCounterController's physical Bag-upgrade counter.
-- Purely a client-side UI affordance (ProximityPrompt) -- both panels'
-- actual purchases/requests still go through their existing, fully
-- server-validated remotes, so there's no trust concern in opening a panel
-- locally.
--
-- Tag every physical shop stand Part/Model in Studio with
-- RunConfig.TAGS.ShopCounter / ClassCounter. If nothing is tagged yet, both
-- panels stay reachable via their LEFT-menu buttons, so this is a safe
-- no-op before the map is tagged.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local LobbyPromptController = {}

local ShopController
local ClassController

local function getAnchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance :: BasePart
	elseif instance:IsA("Model") then
		local model = instance :: Model
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function attachPrompt(instance: Instance, actionText: string, objectText: string, onTriggered: () -> ())
	local part = getAnchorPart(instance)
	if not part or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(onTriggered)
end

-- Workspace streaming means a tagged NPC under the (large) physical Lobby
-- model isn't guaranteed to have streamed in yet by the time this
-- LocalScript's first pass runs, and GetInstanceAddedSignal isn't a reliable
-- catch-all for tag-carrying content that streams in afterward. A short
-- bounded retry (instead of a single scan) covers that gap without needing
-- a hardcoded path to the Lobby model.
local RETRY_INTERVAL_SECONDS = 1
local RETRY_ATTEMPTS = 15

local function initTag(tagName: string, actionText: string, objectText: string, onTriggered: () -> ())
	local function attach(instance: Instance)
		attachPrompt(instance, actionText, objectText, onTriggered)
	end

	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		attach(instance)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(attach)

	task.spawn(function()
		for _ = 1, RETRY_ATTEMPTS do
			if #CollectionService:GetTagged(tagName) > 0 then
				for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
					attach(instance)
				end
				return
			end
			task.wait(RETRY_INTERVAL_SECONDS)
		end
	end)
end

local function initShopCounters()
	initTag(RunConfig.TAGS.ShopCounter, "Shop", "Shop Keeper", function()
		ShopController.open()
	end)
end

local function initClassCounters()
	initTag(RunConfig.TAGS.ClassCounter, "Classes", "Class Trainer", function()
		ClassController.open()
	end)
end

function LobbyPromptController.init(shopController: any, classController: any)
	ShopController = shopController
	ClassController = classController

	initShopCounters()
	initClassCounters()
end

return LobbyPromptController
