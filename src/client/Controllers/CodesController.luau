--!strict
-- CODES overlay: text entry + redeem button. No live codes are invented
-- here -- the server is the sole authority on validity/rewards.

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local UIController

local CodesController = {}

local resultLabel: TextLabel? = nil
local redeemButton: TextButton? = nil
local pending = false

local function setResult(text: string, success: boolean)
	if not resultLabel then
		return
	end
	resultLabel.Text = text
	resultLabel.TextColor3 = success and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonDanger
end

function CodesController.open()
	local overlay = Overlay.new("CODES", UDim2.new(0.6, 0, 0.4, 0))
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	local textBox = Instance.new("TextBox")
	textBox.Name = "CodeInput"
	textBox.Size = UDim2.new(0.8, 0, 0, 56)
	textBox.Position = UDim2.new(0.5, 0, 0, 24)
	textBox.AnchorPoint = Vector2.new(0.5, 0)
	textBox.PlaceholderText = "Enter code..."
	textBox.Text = ""
	textBox.Font = Theme.FontBody
	textBox.TextScaled = true
	textBox.BackgroundColor3 = Theme.Colors.PanelFill
	textBox.ClearTextOnFocus = false
	Theme.applyOutlineCorner(textBox)
	textBox.Parent = overlay.Body

	local button = Theme.newButton({
		Name = "Redeem",
		Text = "REDEEM",
		Size = UDim2.new(0.5, 0, 0, 56),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Colors.ButtonSecondary,
		Parent = overlay.Body,
	})
	redeemButton = button

	resultLabel = Theme.newLabel({
		Name = "Result",
		Text = "",
		Size = UDim2.new(0.9, 0, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 168),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = overlay.Body,
	})

	button.Activated:Connect(function()
		if pending then
			return
		end
		local code = textBox.Text
		if code == "" then
			setResult("Enter a code first.", false)
			return
		end
		pending = true
		Theme.setButtonEnabled(button, false)
		Remotes.fireServer("Core_RequestRedeemCode", code)
	end)

	UIController.openOverlay("Codes", overlay.Frame, function()
		resultLabel = nil
		redeemButton = nil
	end)
end

function CodesController.init(ui)
	UIController = ui

	Remotes.onClientEvent("Core_CodeResult", function(payload: any)
		pending = false
		if redeemButton then
			Theme.setButtonEnabled(redeemButton, true)
		end
		if type(payload) ~= "table" then
			return
		end
		setResult(payload.Message or (payload.Success and "Code redeemed!" or "Invalid code."), payload.Success == true)
	end)
end

return CodesController
