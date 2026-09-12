--!strict
-- Small reusable 3D item preview: clones a SFTE_Assets template into its own
-- ViewportFrame, frames it automatically from its bounding size, and slowly
-- rotates it. Used by the Upgrade Book's tool pages (Section 5/9: "reusable
-- item preview / view system") -- purely cosmetic, never touches gameplay
-- state or purchase logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)

local ItemPreview = {}

local assetsFolder = ReplicatedStorage:WaitForChild("SFTE_Assets")
local ROTATE_RADIANS_PER_SECOND = 0.6

local function boundsOf(inst: Instance): (CFrame, Vector3)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		return inst.CFrame, inst.Size
	end
	return CFrame.new(), Vector3.new(1, 1, 1)
end

-- Returns the ViewportFrame (parented into `parent`), or nil if the named
-- template doesn't exist (caller should fall back to the emoji/text icon
-- already used elsewhere rather than leaving a blank hole).
function ItemPreview.new(parent: Instance, templateName: string, size: UDim2, position: UDim2?): ViewportFrame?
	local template = assetsFolder:FindFirstChild(templateName)
	if not template then
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundColor3 = Theme.Colors.PanelFill
	viewport.BackgroundTransparency = 0
	viewport.Size = size
	if position then
		viewport.Position = position
	end
	Theme.applyOutlineCorner(viewport, 2)
	viewport.Parent = parent

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local clone = template:Clone()
	clone.Parent = worldModel

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local centerCFrame, boundsSize = boundsOf(clone)
	local radius = math.max(boundsSize.Magnitude, 1)
	local center = centerCFrame.Position

	local connection: RBXScriptConnection
	local angle = 0
	connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			connection:Disconnect()
			return
		end
		angle += dt * ROTATE_RADIANS_PER_SECOND
		local offset = Vector3.new(math.cos(angle), 0.45, math.sin(angle)) * radius * 0.9
		camera.CFrame = CFrame.new(center + offset, center)
	end)
	viewport.Destroying:Connect(function()
		if connection.Connected then
			connection:Disconnect()
		end
	end)

	return viewport
end

return ItemPreview
