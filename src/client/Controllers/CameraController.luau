--!strict
-- Short, self-recovering camera sequences for class rolls, chest reveals,
-- the Egg completion beat, and UFO event emphasis. Every sequence restores
-- the player's normal camera even if interrupted, so closing a UI, dying,
-- or teleporting never leaves the camera stuck.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local player = Players.LocalPlayer
local activeSequenceId = 0

local function restoreCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid") or camera.CameraSubject
end

-- Runs `body(camera)` as a scoped camera sequence. Cancels cleanly and
-- restores the default camera if a newer sequence starts or duration
-- elapses, and always restores on error.
local function runSequence(duration: number, body: (Camera) -> ())
	activeSequenceId += 1
	local sequenceId = activeSequenceId

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local ok, err = pcall(body, camera)
	if not ok then
		warn("[CameraController] sequence error: " .. tostring(err))
	end

	task.delay(duration, function()
		if sequenceId == activeSequenceId then
			restoreCamera()
		end
	end)
end

function CameraController.playClassRollFraming()
	runSequence(2.5, function(camera)
		camera.CameraType = Enum.CameraType.Scriptable
		-- Framing target is presentation-only; falls back to a no-op if no
		-- dedicated class-roll camera part exists in the current map.
		local focusPart = Workspace:FindFirstChild("ClassRollCameraPoint", true)
		if focusPart and focusPart:IsA("BasePart") then
			camera.CFrame = focusPart.CFrame
		end
	end)
end

function CameraController.playChestRevealFraming()
	runSequence(2.0, function(camera)
		camera.CameraType = Enum.CameraType.Scriptable
		local focusPart = Workspace:FindFirstChild("ChestCameraPoint", true)
		if focusPart and focusPart:IsA("BasePart") then
			camera.CFrame = focusPart.CFrame
		end
	end)
end

function CameraController.playCompletionSequence()
	runSequence(3.0, function(camera)
		camera.CameraType = Enum.CameraType.Scriptable
		local focusPart = Workspace:FindFirstChild("CompletionCameraPoint", true)
		if focusPart and focusPart:IsA("BasePart") then
			camera.CFrame = focusPart.CFrame
		end
	end)
end

function CameraController.playUfoEmphasis()
	runSequence(2.5, function(camera)
		local ufoPart = Workspace:FindFirstChild("UFO", true)
		if ufoPart and ufoPart:IsA("BasePart") then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, ufoPart.Position)
		end
	end)
end

function CameraController.restore()
	activeSequenceId += 1
	restoreCamera()
end

function CameraController.init()
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		restoreCamera()
	end)
end

return CameraController
