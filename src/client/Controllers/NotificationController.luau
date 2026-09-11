--!strict
-- Toast notification stack used for sell feedback, code results, reward
-- pickups, and generic server-driven notifications (Gameplay_Notification).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local NotificationController = {}

local container: Frame
local ACTIVE_DURATION = 3
local nextOrder = 0

function NotificationController.init(screenGui: ScreenGui)
	container = Instance.new("Frame")
	container.Name = "Notifications"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 90)
	container.Size = UDim2.new(0.9, 0, 0, 400)
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	Remotes.onClientEvent("Gameplay_Notification", function(payload: any)
		if type(payload) == "table" then
			NotificationController.push(payload.Text or "", payload.Kind)
		elseif type(payload) == "string" then
			NotificationController.push(payload)
		end
	end)
end

local KIND_COLORS = {
	Success = Theme.Colors.ButtonSecondary,
	Error = Theme.Colors.ButtonDanger,
	Info = Theme.Colors.ButtonPrimary,
}

function NotificationController.push(text: string, kind: string?)
	if not container then
		return
	end

	local card = Theme.newPanel("Toast", container)
	card.Size = UDim2.new(1, 0, 0, 44)
	card.BackgroundColor3 = KIND_COLORS[kind or "Info"] or Theme.Colors.ButtonPrimary
	nextOrder -= 1
	card.LayoutOrder = nextOrder

	Theme.newLabel({
		Name = "Text",
		Text = text,
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor = Theme.Colors.TextDark,
		Parent = card,
	})

	card.BackgroundTransparency = 1
	local children: { Instance } = card:GetChildren()
	for _, child in children do
		if child:IsA("TextLabel") then
			child.TextTransparency = 1
		end
	end

	local fadeIn = TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 0 })
	fadeIn:Play()
	for _, child in children do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		end
	end

	task.delay(ACTIVE_DURATION, function()
		if not card.Parent then
			return
		end
		local fadeOut = TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		fadeOut:Play()
		for _, child in card:GetChildren() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			end
		end
		fadeOut.Completed:Wait()
		card:Destroy()
	end)
end

return NotificationController
