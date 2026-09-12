--!strict
-- Visual for the one Egg per run. EggService/FarmerService only ever track
-- Egg state as data (run.EggState/EggPosition/EggCarrierUserId -- see
-- EggService.luau's header: "no destructible pile presence of its own"), and
-- nothing client-side ever rendered it before this. Reacts to the existing
-- Gameplay_RunState "RoundMeta" broadcast (already sent to every party
-- member, not just the carrier) rather than adding any new remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerState = require(script.Parent.Parent.State.PlayerState)

local EggVisualController = {}

local eggTemplate: MeshPart = ReplicatedStorage:WaitForChild("SFTE_Assets"):WaitForChild("Egg") :: MeshPart

-- Held slightly in front of/above the carrier's HumanoidRootPart -- there is
-- no hand-bone rig requirement here (spec: "visually carried by the player",
-- no animation required), so a RootPart weld with a fixed offset is enough.
local CARRY_OFFSET = CFrame.new(0, 1.7, -1.4)

local eggPart: MeshPart? = nil
local weld: WeldConstraint? = nil
local carrierCharacterConnection: RBXScriptConnection? = nil
local currentCarrierUserId: number? = nil
local lastSignature: string? = nil

local function ensureEggPart(): MeshPart
	if not eggPart then
		local clone = eggTemplate:Clone()
		clone.Name = "EggVisual"
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Parent = Workspace
		eggPart = clone
	end
	return eggPart :: MeshPart
end

local function clearWeld()
	if weld then
		weld:Destroy()
		weld = nil
	end
	if carrierCharacterConnection then
		carrierCharacterConnection:Disconnect()
		carrierCharacterConnection = nil
	end
	currentCarrierUserId = nil
end

local function hideEgg()
	clearWeld()
	if eggPart then
		eggPart.Transparency = 1
		eggPart.Anchored = true
	end
end

local function attachToCarrier(userId: number)
	local part = ensureEggPart()
	clearWeld()
	currentCarrierUserId = userId

	local function weldTo(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		part.Anchored = false
		part.Transparency = 0
		part.CFrame = root.CFrame * CARRY_OFFSET
		local constraint = Instance.new("WeldConstraint")
		constraint.Part0 = part
		constraint.Part1 = root :: BasePart
		constraint.Parent = part
		weld = constraint
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	if player.Character then
		weldTo(player.Character)
	end
	carrierCharacterConnection = player.CharacterAdded:Connect(function(character)
		if currentCarrierUserId == userId then
			weldTo(character)
		end
	end)
end

local function showAtWorldPosition(position: Vector3)
	clearWeld()
	local part = ensureEggPart()
	part.Anchored = true
	part.Transparency = 0
	part.CFrame = CFrame.new(position)
end

local function refresh(run: any)
	if run.InProgress == false then
		if lastSignature ~= nil then
			hideEgg()
			lastSignature = nil
		end
		return
	end

	local eggState = run.EggState
	local signature = tostring(eggState) .. "|" .. tostring(run.EggCarrierUserId) .. "|" .. tostring(run.EggPosition)
	if signature == lastSignature then
		return
	end
	lastSignature = signature

	if eggState == "Carried" and run.EggCarrierUserId then
		attachToCarrier(run.EggCarrierUserId)
	elseif eggState == "Available" or eggState == "Buried" then
		if typeof(run.EggPosition) == "Vector3" then
			showAtWorldPosition(run.EggPosition)
		end
	else
		hideEgg()
	end
end

function EggVisualController.init()
	PlayerState.RunChanged:Connect(refresh)
end

return EggVisualController
