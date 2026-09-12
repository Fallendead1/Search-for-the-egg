--!strict
-- Hand-equip visuals for Pitchfork/Dynamite/Vacuum/Feather Grabber/Feather
-- Tornado Launcher. InputController already tracks tool selection
-- (ToolChanged/getCurrentTool) but never had any visual attachment system --
-- purely additive, doesn't touch tool gameplay (collection/throw/vacuum
-- remotes all still fire exactly as before).
--
-- Imported/placeholder tool models are raw, unwelded building-part
-- assemblies (no Handle/Grip, no internal rig), so rather than trying to
-- weld a multi-part assembly onto a moving hand, each equipped clone stays
-- Anchored and is repositioned onto the hand every RenderStepped frame via
-- Model:PivotTo -- one lightweight per-frame CFrame write for at most one
-- locally-equipped clone at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InputController = require(script.Parent.InputController)

local ToolEquipController = {}

local assetsFolder = ReplicatedStorage:WaitForChild("SFTE_Assets")

local TOOL_TEMPLATES: { [string]: string } = {
	Pitchfork = "Pitchfork",
	Dynamite = "Dynamite",
	Vacuum = "Vacuum",
	-- Temporary Parts-built placeholders (no final imported asset yet for
	-- either -- see PackingBotService's header for why Packing Bot itself
	-- isn't hand-held and has no entry here).
	FeatherGrabber = "FeatherGrabber",
	TornadoLauncher = "TornadoLauncher",
}

-- Held roughly at hip/hand height, angled forward. Not motion-captured to a
-- real grip point (the source assets have none) -- close enough for "looks
-- correctly held", tunable here without touching gameplay.
local GRIP_OFFSET: { [string]: CFrame } = {
	Pitchfork = CFrame.new(0.6, -0.4, -1.1) * CFrame.Angles(math.rad(-70), 0, math.rad(10)),
	Dynamite = CFrame.new(0.5, -0.3, -0.8) * CFrame.Angles(math.rad(-20), 0, 0),
	Vacuum = CFrame.new(0.4, -0.9, -0.6) * CFrame.Angles(0, math.rad(180), 0),
	FeatherGrabber = CFrame.new(0.5, -0.5, -0.9),
	TornadoLauncher = CFrame.new(0.5, -0.5, -1.0) * CFrame.Angles(0, math.rad(90), 0),
}

local player = Players.LocalPlayer

local pooledClones: { [string]: Model | BasePart } = {}
local equippedTool: string? = nil
local followConnection: RBXScriptConnection? = nil

local function getHandPart(character: Model): BasePart?
	return (character:FindFirstChild("RightHand") :: BasePart?)
		or (character:FindFirstChild("Right Arm") :: BasePart?)
		or (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function setDescendantsAnchoredHidden(inst: Instance, hidden: boolean)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
		inst.Transparency = hidden and 1 or 0
	end
	for _, child in ipairs(inst:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
			child.Transparency = hidden and 1 or 0
		end
	end
end

local function getOrCreateClone(tool: string): (Model | BasePart)?
	local existing = pooledClones[tool]
	if existing then
		return existing
	end
	local templateName = TOOL_TEMPLATES[tool]
	local template = templateName and assetsFolder:FindFirstChild(templateName)
	if not template then
		return nil
	end
	local clone = template:Clone()
	clone.Name = "Held" .. tool
	setDescendantsAnchoredHidden(clone, true)
	clone.Parent = workspace
	pooledClones[tool] = clone
	return clone
end

local function pivotClone(clone: Model | BasePart, cframe: CFrame)
	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	end
end

local function stopFollowing()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
end

local function hideAllClones()
	for _, clone in pairs(pooledClones) do
		setDescendantsAnchoredHidden(clone, true)
	end
end

local function equip(tool: string)
	stopFollowing()
	hideAllClones()
	equippedTool = tool

	local offset = GRIP_OFFSET[tool]
	if not offset then
		return
	end
	local clone = getOrCreateClone(tool)
	if not clone then
		return
	end
	setDescendantsAnchoredHidden(clone, false)

	followConnection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local hand = character and getHandPart(character)
		if not hand then
			return
		end
		pivotClone(clone, hand.CFrame * offset)
	end)
end

local function unequip()
	stopFollowing()
	hideAllClones()
	equippedTool = nil
end

local function onToolChanged(tool: string)
	if GRIP_OFFSET[tool] then
		if equippedTool ~= tool then
			equip(tool)
		end
	elseif equippedTool ~= nil then
		unequip()
	end
end

-- A respawn mid-equip needs no special handling: the follow loop above
-- re-fetches player.Character every frame, so it just resumes onto whatever
-- character exists once RenderStepped ticks again.
function ToolEquipController.init()
	InputController.ToolChanged:Connect(onToolChanged)
end

return ToolEquipController
