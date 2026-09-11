--[[
	The one Egg per run: spawn (deep in the pile, harder = deeper), exposure
	when its pile column is dug out enough, pickup, single-carrier tracking,
	and recovery on death/disconnect/leave. Turn-in is FarmerService's job;
	this module just flips Egg state to TurnedIn when asked.

	The Egg has no destructible pile presence of its own -- it's tracked as a
	position + state, independent of column Fill, so no dig/blast path can
	ever delete it. Only FeatherPileService's exposure callback and this
	module's own state machine touch EggState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local MapAnchors = require(script.Parent.MapAnchors)

local EggService = {}

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

local function getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position
end

function EggService.SpawnForRun(run: any)
	local pile = run.Pile
	local worldPosition = FeatherPileService.AssignEggColumn(pile)
	run.EggPosition = worldPosition
	run.EggState = "Buried"
	run.EggCarrierUserId = nil
	RoundService.BroadcastRunMeta(run)
end

function EggService.HandleColumnExposed(run: any)
	if not run or run.EggState ~= "Buried" then
		return
	end
	run.EggState = "Available"
	RoundService.BroadcastRunMeta(run)

	for _, userId in ipairs(run.Members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RoundService.SendNotification(player, "The Egg has been uncovered!", "Success")
		end
	end
end

local function setCarrying(run: any, userId: number, carrying: boolean)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local state = RunPlayerStateService.Get(player)
	if state then
		state.CarryingEgg = carrying
	end
	RoundService.BroadcastPlayerState(player)
end

function EggService.RequestPickup(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end
	if run.EggState ~= "Available" then
		return false, "EggNotAvailable"
	end

	local characterPosition = getCharacterPosition(player)
	if not characterPosition then
		return false, "NoCharacter"
	end
	if not run.EggPosition or distance(characterPosition, run.EggPosition) > RunConfig.RANGE.EGG_PICKUP then
		return false, "OutOfRange"
	end

	run.EggState = "Carried"
	run.EggCarrierUserId = player.UserId
	setCarrying(run, player.UserId, true)
	RoundService.BroadcastRunMeta(run)

	for _, userId in ipairs(run.Members) do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			RoundService.SendNotification(member, player.Name .. " picked up the Egg!", "Info")
		end
	end

	return true
end

-- Returns the Egg to Available at its last exposed pile position, clearing
-- the carrier. Safe to call repeatedly / when there's no carrier.
function EggService.ReturnEgg(run: any)
	if not run or run.EggState ~= "Carried" then
		return
	end
	local previousCarrier = run.EggCarrierUserId
	run.EggState = "Available"
	run.EggCarrierUserId = nil

	if not run.EggPosition then
		run.EggPosition = MapAnchors.GetSafeEggFallbackPosition()
	end

	if previousCarrier then
		setCarrying(run, previousCarrier, false)
	end

	RoundService.BroadcastRunMeta(run)
end

function EggService.MarkTurnedIn(run: any)
	run.EggState = "TurnedIn"
	if run.EggCarrierUserId then
		setCarrying(run, run.EggCarrierUserId, false)
	end
end

local function handleCarrierLost(userId: number)
	local run = RoundService.GetRunForUserId(userId)
	if not run then
		return
	end
	if run.EggCarrierUserId == userId then
		EggService.ReturnEgg(run)
	end
end

function EggService.CleanupRun(_run: any)
	-- Nothing to clean up beyond what RoundService already clears (Pile is
	-- destroyed by RoundService; run itself is discarded after this).
end

function EggService.Init()
	local pickupRemote = RemotesLocator.Get("Gameplay_RequestEggPickup")
	pickupRemote.OnServerEvent:Connect(function(player: Player)
		EggService.RequestPickup(player)
	end)

	FeatherPileService.SetOnEggColumnExposed(EggService.HandleColumnExposed)

	RoundService.OnRunCreated(EggService.SpawnForRun)
	RoundService.OnRunEnded(EggService.CleanupRun)

	Players.PlayerRemoving:Connect(function(player: Player)
		handleCarrierLost(player.UserId)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					handleCarrierLost(player.UserId)
				end)
			end
		end)
	end)
end

return EggService
