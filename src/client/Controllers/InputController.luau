--!strict
-- PC (click/hold, number keys) and mobile (tap/hold, touch hotbar) input
-- for feather collection and tool selection. Sends intent only -- Tool and
-- TargetPosition -- and never predicts or sends a collection amount.
-- Collection cadence is bounded by the player's current (server-reported)
-- hand speed; this never fires every RenderStepped frame.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local Signal = require(script.Parent.Parent.Util.Signal)
local SoundController = require(script.Parent.SoundController)

local InputController = {}

InputController.ToolLocked = Signal.new() :: Signal.Signal
InputController.ToolChanged = Signal.new() :: Signal.Signal

local TOOL_SLOTS: { [number]: string } = {
	[1] = "Hand",
	[2] = "Pitchfork",
	[3] = "Dynamite",
	[4] = "Drone",
	[5] = "Vacuum",
	[6] = "FeatherGrabber",
	[7] = "TornadoLauncher",
	[8] = "PackingBot",
}

local player = Players.LocalPlayer
local currentTool = "Hand"
local holding = false
local activeTouchPosition: Vector3? = nil
local lastCollectAt = 0
local MIN_COLLECT_INTERVAL_FLOOR = 0.15 -- absolute safety floor regardless of upgrades

local lastDynamiteThrowAt = 0
local DYNAMITE_CLIENT_DEBOUNCE_SECONDS = 0.2 -- light client-side debounce; DynamiteConfig's real cooldown is server-authoritative

-- Vacuum/Drone are activate-and-forget: toggled via their hotbar button
-- (InputController.toggleAutoTool), never by aiming/clicking the world.
-- This just mirrors what THIS client last requested for hotbar highlight
-- purposes -- the server (VacuumService/DroneService) is the only
-- authority on whether they're actually running.
local autoToolActive: { [string]: boolean } = { Vacuum = false, Drone = false, PackingBot = false }

local function getMouseTargetPosition(): Vector3?
	local mouse = player:GetMouse()
	return mouse.Hit and mouse.Hit.Position
end

local function getTouchTargetPosition(inputPosition: Vector3): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local viewportRay = camera:ViewportPointToRay(inputPosition.X, inputPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }
	local result = Workspace:Raycast(viewportRay.Origin, viewportRay.Direction * 500, raycastParams)
	if result then
		return result.Position
	end
	return nil
end

local function isToolOwned(tool: string): boolean
	return PlayerState.isToolOwned(tool)
end

local function requestCollect(targetPosition: Vector3?)
	if not targetPosition then
		return
	end
	if not PlayerState.Run.InProgress then
		return
	end

	local interval = math.max(PlayerState.Run.HandSpeed or 0.55, MIN_COLLECT_INTERVAL_FLOOR)
	local now = os.clock()
	if now - lastCollectAt < interval then
		return
	end
	lastCollectAt = now

	Remotes.fireServer("Gameplay_RequestCollect", {
		Tool = currentTool,
		TargetPosition = targetPosition,
	})
	SoundController.play("Collect", 0.35)
end

-- Dynamite has no Hold mechanic -- each click/tap is one throw attempt, not
-- a continuous action, so this is only ever called from InputBegan, never
-- from the Heartbeat hold-loop below.
local function requestDynamiteThrow(targetPosition: Vector3?)
	if not targetPosition then
		return
	end
	if not PlayerState.Run.InProgress then
		return
	end

	local now = os.clock()
	if now - lastDynamiteThrowAt < DYNAMITE_CLIENT_DEBOUNCE_SECONDS then
		return
	end
	lastDynamiteThrowAt = now

	Remotes.fireServer("Gameplay_RequestToolAction", {
		Tool = "Dynamite",
		Action = "Throw",
		TargetPosition = targetPosition,
	})
	SoundController.play("DynamiteThrow", 0.5)
end

-- Dispatches a world click/tap by the currently selected tool. Vacuum/Drone
-- intentionally do nothing here -- they're toggled via their hotbar button,
-- not aimed at the world.
local function dispatchPrimaryAction(targetPosition: Vector3?)
	if currentTool == "Hand" or currentTool == "Pitchfork" or currentTool == "FeatherGrabber" or currentTool == "TornadoLauncher" then
		requestCollect(targetPosition)
	elseif currentTool == "Dynamite" then
		requestDynamiteThrow(targetPosition)
	end
end

function InputController.selectTool(tool: string)
	if not TOOL_SLOTS[1] then
		return
	end
	if not isToolOwned(tool) then
		InputController.ToolLocked:Fire(tool)
		SoundController.play("Locked")
		return
	end
	currentTool = tool
	InputController.ToolChanged:Fire(tool)
end

function InputController.getCurrentTool(): string
	return currentTool
end

-- Vacuum/Drone activation. Server remains authoritative (VacuumService/
-- DroneService.handleToggle re-validate ownership/run state); this only
-- sends the request and flips a local "last requested" flag for hotbar
-- highlighting, mirroring the same server-authoritative pattern used
-- everywhere else in this client.
function InputController.toggleAutoTool(tool: string)
	if autoToolActive[tool] == nil then
		return
	end
	if not isToolOwned(tool) then
		InputController.ToolLocked:Fire(tool)
		SoundController.play("Locked")
		return
	end
	if not PlayerState.Run.InProgress then
		return
	end

	local newState = not autoToolActive[tool]
	autoToolActive[tool] = newState

	Remotes.fireServer("Gameplay_RequestToolAction", {
		Tool = tool,
		Action = "Toggle",
		Active = newState,
	})
	SoundController.play(newState and "Upgrade" or "ButtonClick")
	InputController.ToolChanged:Fire(tool)
end

function InputController.isAutoToolActive(tool: string): boolean
	return autoToolActive[tool] == true
end

function InputController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			dispatchPrimaryAction(getMouseTargetPosition())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			holding = true
			activeTouchPosition = input.Position
			dispatchPrimaryAction(getTouchTargetPosition(input.Position))
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and holding then
			activeTouchPosition = input.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = false
			activeTouchPosition = nil
		end
	end)

	local NUMBER_KEYS: { [Enum.KeyCode]: number } = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
	}

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local slot = NUMBER_KEYS[input.KeyCode]
		if slot and TOOL_SLOTS[slot] then
			InputController.selectTool(TOOL_SLOTS[slot])
		end
	end)

	-- Bounded continuous collection while holding, gated on the Hold
	-- upgrade being owned and a run being in progress. Runs on Heartbeat
	-- but requestCollect internally enforces the real cadence floor, so
	-- this never spams the server every frame. Only Hand/Pitchfork have a
	-- Hold mechanic -- Dynamite is a discrete one-throw-per-click action
	-- (see dispatchPrimaryAction/InputBegan), and Vacuum/Drone have no
	-- world-click gesture at all (toggled via their hotbar button instead).
	game:GetService("RunService").Heartbeat:Connect(function()
		if not holding then
			return
		end
		if currentTool ~= "Hand" and currentTool ~= "Pitchfork" then
			return
		end
		if not PlayerState.Run.HandHoldUnlocked then
			return
		end
		if activeTouchPosition then
			requestCollect(getTouchTargetPosition(activeTouchPosition))
		else
			requestCollect(getMouseTargetPosition())
		end
	end)
end

return InputController
