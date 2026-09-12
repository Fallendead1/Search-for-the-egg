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

-- workspace.StreamingEnabled is on, and it streams by PROXIMITY to the
-- player's character/camera, not by elapsed time -- a tagged NPC under the
-- (large) physical Lobby model may not stream in until the player actually
-- walks near it, whenever that happens to be. Confirmed live in Studio that
-- CollectionService:GetInstanceAddedSignal does NOT reliably fire for a tag
-- that was already present in the Edit-time data once that instance streams
-- in (that signal is really for tags added at runtime) -- both
-- ShopKeeperNPC's and ClassTrainerNPC's prompts silently never attached
-- even walking right up to them, while a fresh CollectionService:GetTagged()
-- poll at that same moment found them immediately. So: poll indefinitely
-- (not a bounded retry) instead of trusting that signal alone. attach() is
-- idempotent (attachPrompt no-ops once a prompt already exists), so
-- re-scanning already-attached instances every tick is harmless.
local POLL_INTERVAL_SECONDS = 2

local function initTag(tagName: string, actionText: string, objectText: string, onTriggered: () -> ())
	local function attach(instance: Instance)
		attachPrompt(instance, actionText, objectText, onTriggered)
	end

	CollectionService:GetInstanceAddedSignal(tagName):Connect(attach)

	task.spawn(function()
		while true do
			for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
				attach(instance)
			end
			task.wait(POLL_INTERVAL_SECONDS)
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
