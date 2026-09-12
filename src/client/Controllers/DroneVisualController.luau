--!strict
-- Visual for any "DroneState"-shaped Gameplay_FX broadcast: DroneService's
-- Drone (task.delay phase chain, see DroneService.luau's header: "the
-- actual flight animation is a client... presentation concern") and
-- PackingBotService's Packing Bot both fire the same event shape
-- ({DroneId, OwnerUserId, Phase, Position, AssetName}) rather than
-- duplicating a second visual controller (Section 17: reuse/generalize the
-- Drone concept). Neither ever spawns a server-side Instance and neither
-- fires an explicit "stopped" event, so visuals here are: (1) built/moved
-- from whatever events arrive, tweened rather than snapped so it reads as
-- movement without needing exact server phase timings, and (2) swept for
-- staleness, since a stopped entry gives no other signal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local DroneVisualController = {}

local assetsFolder = ReplicatedStorage:WaitForChild("SFTE_Assets")

-- No phase duration is sent down (server applies a per-player speed
-- multiplier the client doesn't know), so flights use one fixed, generally-
-- correct travel time rather than trying to match the server exactly.
local FLY_TWEEN_SECONDS = 1.4
local STALE_TIMEOUT_SECONDS = 6
local SWEEP_INTERVAL_SECONDS = 1

-- Drone flies; Packing Bot is a wheeled ground unit (temporary Parts model,
-- see ToolEquipController's header) -- each asset gets its own hover height.
local HOVER_HEIGHT_BY_ASSET: { [string]: number } = {
	Drone = 9,
	PackingBot = 1.5,
}

type DroneVisual = {
	Model: Model,
	LastSeen: number,
	AssetName: string,
	FollowConnection: RBXScriptConnection?,
}

local drones: { [string]: DroneVisual } = {}

local function hoverPosition(position: Vector3, phase: string, assetName: string): Vector3
	local hoverHeight = HOVER_HEIGHT_BY_ASSET[assetName] or HOVER_HEIGHT_BY_ASSET.Drone
	if phase == "FlyToPile" or phase == "FlyToSell" then
		return position + Vector3.new(0, hoverHeight, 0)
	end
	return position + Vector3.new(0, hoverHeight * 0.5, 0)
end

local function getOrCreateDrone(droneId: string, assetName: string): DroneVisual?
	local existing = drones[droneId]
	if existing then
		return existing
	end
	local template = assetsFolder:FindFirstChild(assetName)
	if not template then
		return nil
	end
	local clone = template:Clone()
	clone.Name = assetName .. "Visual_" .. droneId
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	clone.Parent = Workspace
	local visual: DroneVisual = { Model = clone, LastSeen = os.clock(), AssetName = assetName, FollowConnection = nil }
	drones[droneId] = visual
	return visual
end

local function destroyDrone(droneId: string)
	local visual = drones[droneId]
	if not visual then
		return
	end
	if visual.FollowConnection then
		visual.FollowConnection:Disconnect()
	end
	visual.Model:Destroy()
	drones[droneId] = nil
end

local function destroyAllDrones()
	for droneId in pairs(drones) do
		destroyDrone(droneId)
	end
end

-- Model:PivotTo has no TweenService-able property to target directly, so
-- flight is a small manual RenderStepped lerp -- one connection per active
-- drone (at most a handful, even with a Specialist swarm), auto-disconnecting
-- once it reaches the target.
local function onDroneState(payload: any)
	if type(payload.DroneId) ~= "string" or typeof(payload.Position) ~= "Vector3" then
		return
	end

	local assetName = type(payload.AssetName) == "string" and payload.AssetName or "Drone"
	local visual = getOrCreateDrone(payload.DroneId, assetName)
	if not visual then
		return
	end
	visual.LastSeen = os.clock()

	local targetPosition = hoverPosition(payload.Position, payload.Phase, assetName)
	local startCFrame = visual.Model:GetPivot()

	local travelDirection = targetPosition - startCFrame.Position
	local targetCFrame = if travelDirection.Magnitude > 0.05
		then CFrame.new(targetPosition, targetPosition + travelDirection)
		else startCFrame - startCFrame.Position + targetPosition

	if visual.FollowConnection then
		visual.FollowConnection:Disconnect()
	end

	local startTime = os.clock()
	visual.FollowConnection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - startTime) / FLY_TWEEN_SECONDS, 0, 1)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		visual.Model:PivotTo(startCFrame:Lerp(targetCFrame, eased))
		if alpha >= 1 and visual.FollowConnection then
			visual.FollowConnection:Disconnect()
			visual.FollowConnection = nil
		end
	end)
end

local function sweepStale()
	local now = os.clock()
	for droneId, visual in pairs(drones) do
		if now - visual.LastSeen > STALE_TIMEOUT_SECONDS then
			destroyDrone(droneId)
		end
	end
end

function DroneVisualController.init()
	Remotes.onClientEvent("Gameplay_FX", function(payload: any)
		if type(payload) == "table" and payload.Type == "DroneState" then
			onDroneState(payload)
		end
	end)

	Remotes.onClientEvent("Gameplay_RunState", function(state: any)
		if type(state) == "table" and state.Type == "RoundMeta" and state.RoundState == "Ended" then
			destroyAllDrones()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SWEEP_INTERVAL_SECONDS)
			sweepStale()
		end
	end)
end

return DroneVisualController
