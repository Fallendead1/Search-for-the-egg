--!strict
-- Shared "big centered panel with a title and an X button" shell used by
-- the Book, Inventory, Shop, Classes, Alien Chest, Codes, and Stats
-- overlays so they all open/close consistently on PC and mobile.

local Theme = require(script.Parent.Parent.Theme)

local Overlay = {}

export type OverlayHandle = {
	Frame: Frame,
	Body: Frame,
	CloseButton: TextButton,
}

function Overlay.new(title: string, size: UDim2?): OverlayHandle
	local frame = Instance.new("Frame")
	frame.Name = title .. "Overlay"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = size or UDim2.new(0.85, 0, 0.85, 0)
	frame.BackgroundColor3 = Theme.Colors.Background
	Theme.applyOutlineCorner(frame, 4)

	local titleBar = Theme.newPanel("TitleBar", frame)
	titleBar.Size = UDim2.new(1, 0, 0, 56)
	titleBar.BackgroundColor3 = Theme.Colors.ButtonPrimary

	Theme.newLabel({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	local closeButton = Theme.newButton({
		Name = "Close",
		Text = "X",
		Size = UDim2.new(0, 44, 0, 44),
		Position = UDim2.new(1, -50, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = Theme.Colors.ButtonDanger,
		Parent = titleBar,
	})

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 0, 0, 64)
	body.Size = UDim2.new(1, 0, 1, -72)
	body.Parent = frame

	return {
		Frame = frame,
		Body = body,
		CloseButton = closeButton,
	}
end

function Overlay.newScroll(parent: Instance, name: string?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name or "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 10
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = parent
	return scroll
end

return Overlay
