--!strict
-- Shared visual language for SearchForTheEgg's UI: bright cartoon-farm
-- palette, chunky thick-outline buttons, and a few layout constants used
-- across every controller so screens feel like one game.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(255, 248, 220),
	PanelFill = Color3.fromRGB(255, 253, 245),
	PanelOutline = Color3.fromRGB(92, 64, 32),

	ButtonPrimary = Color3.fromRGB(255, 189, 46),
	ButtonPrimaryPressed = Color3.fromRGB(224, 158, 24),
	ButtonSecondary = Color3.fromRGB(120, 200, 90),
	ButtonSecondaryPressed = Color3.fromRGB(92, 168, 66),
	ButtonDanger = Color3.fromRGB(230, 90, 80),
	ButtonDisabled = Color3.fromRGB(170, 170, 170),

	TextDark = Color3.fromRGB(58, 40, 20),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextGold = Color3.fromRGB(255, 214, 64),

	Gems = Color3.fromRGB(90, 220, 210),
	AlienTokens = Color3.fromRGB(150, 230, 90),
	Cash = Color3.fromRGB(90, 210, 110),

	Locked = Color3.fromRGB(80, 80, 90),

	RarityCommon = Color3.fromRGB(190, 190, 190),
	RarityUncommon = Color3.fromRGB(120, 200, 120),
	RarityRare = Color3.fromRGB(90, 150, 240),
	RarityEpic = Color3.fromRGB(190, 110, 240),
	RarityLegendary = Color3.fromRGB(255, 180, 60),
}

Theme.Font = Enum.Font.FredokaOne
Theme.FontBody = Enum.Font.GothamBold

Theme.CornerRadius = UDim.new(0, 14)
Theme.OutlineThickness = 3

function Theme.applyOutlineCorner(instance: Instance, thickness: number?, cornerRadius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = cornerRadius or Theme.CornerRadius
	corner.Parent = instance

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or Theme.OutlineThickness
	stroke.Color = Theme.Colors.PanelOutline
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance

	return corner, stroke
end

function Theme.newPanel(name: string, parent: Instance?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.Colors.PanelFill
	frame.BorderSizePixel = 0
	Theme.applyOutlineCorner(frame)
	if parent then
		frame.Parent = parent
	end
	return frame
end

function Theme.newButton(config: {
	Name: string?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	TextColor: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}): TextButton
	local button = Instance.new("TextButton")
	button.Name = config.Name or "Button"
	button.Size = config.Size or UDim2.new(0, 160, 0, 56)
	button.Position = config.Position or UDim2.new(0, 0, 0, 0)
	button.AnchorPoint = config.AnchorPoint or Vector2.new(0, 0)
	button.BackgroundColor3 = config.Color or Theme.Colors.ButtonPrimary
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Font = Theme.Font
	button.Text = config.Text or ""
	button.TextColor3 = config.TextColor or Theme.Colors.TextDark
	button.TextScaled = true
	if config.LayoutOrder then
		button.LayoutOrder = config.LayoutOrder
	end

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 28
	sizeConstraint.MinTextSize = 10
	sizeConstraint.Parent = button

	Theme.applyOutlineCorner(button)

	local baseColor = button.BackgroundColor3
	local pressedColor = Color3.new(baseColor.R * 0.85, baseColor.G * 0.85, baseColor.B * 0.85)

	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = pressedColor
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = baseColor
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = baseColor
	end)

	if config.Parent then
		button.Parent = config.Parent
	end

	return button
end

function Theme.setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	if enabled then
		button.BackgroundTransparency = 0
		button.TextTransparency = 0
	else
		button.BackgroundColor3 = Theme.Colors.ButtonDisabled
		button.TextTransparency = 0.2
	end
end

function Theme.newLabel(config: {
	Name: string?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextColor: Color3?,
	TextXAlignment: Enum.TextXAlignment?,
	Font: Enum.Font?,
	LayoutOrder: number?,
	Parent: Instance?,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = config.Name or "Label"
	label.Size = config.Size or UDim2.new(1, 0, 0, 32)
	label.Position = config.Position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = config.AnchorPoint or Vector2.new(0, 0)
	label.BackgroundTransparency = 1
	label.Font = config.Font or Theme.Font
	label.Text = config.Text or ""
	label.TextColor3 = config.TextColor or Theme.Colors.TextDark
	label.TextScaled = true
	label.TextXAlignment = config.TextXAlignment or Enum.TextXAlignment.Center
	if config.LayoutOrder then
		label.LayoutOrder = config.LayoutOrder
	end

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 26
	sizeConstraint.MinTextSize = 8
	sizeConstraint.Parent = label

	if config.Parent then
		label.Parent = config.Parent
	end

	return label
end

return Theme
