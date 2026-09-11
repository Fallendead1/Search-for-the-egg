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
}

local player = Players.LocalPlayer
local currentTool = "Hand"
local holding = false
local activeTouchPosition: Vector3? = nil
local lastCollectAt = 0
local MIN_COLLECT_INTERVAL_FLOOR = 0.15 -- absolute safety floor regardless of upgrades

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
	if tool == "Hand" then
		return true
	end
	return PlayerState.Profile.OwnedTools[tool] == true
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

function InputController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			requestCollect(getMouseTargetPosition())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			holding = true
			activeTouchPosition = input.Position
			requestCollect(getTouchTargetPosition(input.Position))
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
	-- this never spams the server every frame.
	game:GetService("RunService").Heartbeat:Connect(function()
		if not holding then
			return
		end
		if not PlayerState.Profile.HoldUnlocked then
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
