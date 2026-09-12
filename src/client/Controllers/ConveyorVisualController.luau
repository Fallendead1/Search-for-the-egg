--!strict
-- Cosmetic conveyor-crate animation for a completed Feather sale. SellService
-- already does the ENTIRE authoritative transaction (empty Bag -> compute
-- sale -> credit Cash) before firing Gameplay_FX "ConveyorSale" -- this
-- controller only plays a crate traveling from the deposit point
-- (SFTE_ConveyorDeposit / same part as SFTE_SellStation) to the output point
-- (SFTE_ConveyorOutput) with a chicken "peck" at the end. Purely presentation:
-- if this never ran, or the map isn't tagged yet, no Cash/Bag state would be
-- different in any way.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local ConveyorVisualController = {}

local assetsFolder = ReplicatedStorage:WaitForChild("SFTE_Assets")
local crateTemplate = assetsFolder:FindFirstChild("SellCrate")

local TRAVEL_SECONDS = 2.2
local LIFT_STUDS = 1
local POOL_SIZE = 3

-- Small reusable pool (Section 6: "pool/reuse crate objects... do not spawn
-- unlimited abandoned crates") -- cycled round-robin, so at most POOL_SIZE
-- crates ever exist regardless of how many sales happen.
local pool: { BasePart | Model } = {}
local nextPoolIndex = 1

local function getAnchorPosition(tagName: string): Vector3?
	local tagged = CollectionService:GetTagged(tagName)
	local instance = tagged[1]
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function getCrate(): (BasePart | Model)?
	if not crateTemplate then
		return nil
	end
	if #pool < POOL_SIZE then
		local clone = crateTemplate:Clone()
		clone.Name = "SellCrateVisual"
		clone.Parent = Workspace
		table.insert(pool, clone)
		return clone
	end
	local crate = pool[nextPoolIndex]
	nextPoolIndex = (nextPoolIndex % POOL_SIZE) + 1
	return crate
end

local function setCrateVisible(crate: BasePart | Model, visible: boolean)
	if crate:IsA("BasePart") then
		crate.Transparency = visible and 0 or 1
	else
		for _, part in ipairs(crate:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = visible and 0 or 1
			end
		end
	end
end

local function pivotCrate(crate: BasePart | Model, cframe: CFrame)
	if crate:IsA("BasePart") then
		crate.CFrame = cframe
	else
		crate:PivotTo(cframe)
	end
end

local function peckNearestChicken(atPosition: Vector3)
	local nearest, nearestDistance = nil, math.huge
	for _, chicken in ipairs(CollectionService:GetTagged(RunConfig.TAGS.Chicken)) do
		if chicken:IsA("Model") then
			local d = (chicken:GetPivot().Position - atPosition).Magnitude
			if d < nearestDistance then
				nearest, nearestDistance = chicken, d
			end
		end
	end
	if not nearest then
		return
	end

	local basePivot = nearest:GetPivot()
	local dipped = basePivot * CFrame.new(0, -0.6, 0.3)
	local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true)

	local proxy = Instance.new("CFrameValue")
	proxy.Value = basePivot
	local connection = proxy:GetPropertyChangedSignal("Value"):Connect(function()
		nearest:PivotTo(proxy.Value)
	end)
	local tween = TweenService:Create(proxy, tweenInfo, { Value = dipped })
	tween.Completed:Connect(function()
		connection:Disconnect()
		nearest:PivotTo(basePivot)
		proxy:Destroy()
	end)
	tween:Play()
end

local function onConveyorSale(_payload: any)
	local depositPosition = getAnchorPosition(RunConfig.TAGS.SellStation)
	local outputPosition = getAnchorPosition(RunConfig.TAGS.ConveyorOutput)
	if not depositPosition or not outputPosition then
		return
	end

	local crate = getCrate()
	if not crate then
		return
	end

	local startCFrame = CFrame.new(depositPosition + Vector3.new(0, LIFT_STUDS, 0))
	local endCFrame = CFrame.new(outputPosition + Vector3.new(0, LIFT_STUDS, 0))

	setCrateVisible(crate, true)
	pivotCrate(crate, startCFrame)

	local startTime = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.clamp((os.clock() - startTime) / TRAVEL_SECONDS, 0, 1)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
		pivotCrate(crate, startCFrame:Lerp(endCFrame, eased))
		if alpha >= 1 then
			connection:Disconnect()
			setCrateVisible(crate, false)
			peckNearestChicken(outputPosition)
		end
	end)
end

function ConveyorVisualController.init()
	if not crateTemplate then
		return
	end
	Remotes.onClientEvent("Gameplay_FX", function(payload: any)
		if type(payload) == "table" and payload.Type == "ConveyorSale" then
			onConveyorSale(payload)
		end
	end)
end

return ConveyorVisualController
