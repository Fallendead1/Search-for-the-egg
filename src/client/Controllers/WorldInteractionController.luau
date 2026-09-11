--!strict
-- Sell Station / Farmer turn-in interactions (ProximityPrompt on tagged
-- world parts) and Egg pickup (a proximity auto-trigger, since the Egg has
-- no fixed Studio part -- its position is procedural within the pile each
-- run; see EggService.SpawnForRun/AssignEggColumn). Without this controller
-- nothing client-side ever fires Gameplay_RequestSell /
-- Gameplay_RequestEggPickup / Gameplay_RequestEggTurnIn -- the server
-- already fully validates range/state for all three, so this is purely the
-- missing client-side trigger.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local WorldInteractionController = {}

local player = Players.LocalPlayer

local function getAnchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance :: BasePart
	elseif instance:IsA("Model") then
		local model = instance :: Model
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function attachPrompt(instance: Instance, actionText: string, objectText: string, onTriggered: () -> ()): ProximityPrompt?
	local part = getAnchorPart(instance)
	if not part or part:FindFirstChildOfClass("ProximityPrompt") then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(onTriggered)
	return prompt
end

local function initSellStations()
	local function attach(instance: Instance)
		attachPrompt(instance, "Sell", "Sell Station", function()
			Remotes.fireServer("Gameplay_RequestSell")
		end)
	end
	for _, instance in ipairs(CollectionService:GetTagged(RunConfig.TAGS.SellStation)) do
		attach(instance)
	end
	CollectionService:GetInstanceAddedSignal(RunConfig.TAGS.SellStation):Connect(attach)
end

local function initFarmer()
	local function attach(instance: Instance)
		local prompt = attachPrompt(instance, "Give Egg", "Farmer", function()
			Remotes.fireServer("Gameplay_RequestEggTurnIn")
		end)
		if not prompt then
			return
		end
		prompt.Enabled = PlayerState.Run.CarryingEgg == true
		PlayerState.RunChanged:Connect(function(run)
			prompt.Enabled = run.CarryingEgg == true
		end)
	end
	for _, instance in ipairs(CollectionService:GetTagged(RunConfig.TAGS.Farmer)) do
		attach(instance)
	end
	CollectionService:GetInstanceAddedSignal(RunConfig.TAGS.Farmer):Connect(attach)
end

local lastEggPickupAttempt = 0
local EGG_PICKUP_RETRY_SECONDS = 1

local function tickEggPickup()
	local run = PlayerState.Run
	if not run.InProgress or run.EggState ~= "Available" then
		return
	end
	if run.CarryingEgg or run.EggCarrierUserId then
		return
	end
	local eggPosition = run.EggPosition
	if typeof(eggPosition) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - eggPosition).Magnitude > RunConfig.RANGE.EGG_PICKUP then
		return
	end

	local now = os.clock()
	if now - lastEggPickupAttempt < EGG_PICKUP_RETRY_SECONDS then
		return
	end
	lastEggPickupAttempt = now
	Remotes.fireServer("Gameplay_RequestEggPickup")
end

function WorldInteractionController.init()
	initSellStations()
	initFarmer()
	RunService.Heartbeat:Connect(tickEggPickup)
end

return WorldInteractionController
