--!strict
-- Shared "big centered panel with a title and an X button" shell used by
-- the Book, Inventory, Shop, Classes, Alien Chest, Codes, and Stats
-- overlays so they all open/close consistently on PC and mobile.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)

local Overlay = {}

export type OverlayHandle = {
	Frame: Frame,
	Body: Frame,
	CloseButton: TextButton,
}

export type BackgroundArt = {
	-- Final full-panel art (icon/title/border baked in) to use as the
	-- overlay's entire look instead of the flat Theme title bar. Image
	-- aspect ratio should match `size` reasonably closely or it'll letterbox
	-- (Fit) rather than distort.
	Image: number,
	-- Invisible hit-region over the art's own baked X button. Defaults to a
	-- reasonable top-right guess if omitted.
	CloseButtonPosition: UDim2?,
	CloseButtonSize: UDim2?,
	-- Where dynamic content should sit so it doesn't collide with the art's
	-- own baked header. Defaults to roughly "below a ~20% header band."
	BodyPosition: UDim2?,
	BodySize: UDim2?,
	-- Real pixel width/height of the source image -- locks the frame to that
	-- aspect ratio (via UIAspectRatioConstraint) so `size` just bounds the
	-- max footprint instead of stretching/squashing the art.
	AspectRatio: number?,
}

function Overlay.new(title: string, size: UDim2?, art: BackgroundArt?): OverlayHandle
	local targetSize = size or UDim2.new(0.85, 0, 0.85, 0)

	local frame = Instance.new("Frame")
	frame.Name = title .. "Overlay"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	-- Pop-in polish: start a touch smaller than the target size (same anchor
	-- point, so it scales from center) and tween up -- every overlay built on
	-- this shell (Shop/Classes/Stats/DailyRewards/etc) gets this for free.
	frame.Size = UDim2.new(targetSize.X.Scale * 0.88, targetSize.X.Offset * 0.88, targetSize.Y.Scale * 0.88, targetSize.Y.Offset * 0.88)
	-- Thicker gold-trim border (matching the final art's honey-gold rim
	-- style) instead of the old thin plain-brown outline, on every overlay
	-- that doesn't supply its own full-panel art.
	local _outerCorner, outerStroke = Theme.applyOutlineCorner(frame, 6, UDim.new(0, 22))
	if not (art and art.Image ~= 0) then
		outerStroke.Color = Theme.Colors.TextGold
	end

	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = targetSize,
	}):Play()

	local closeButton: TextButton
	local bodyPosition = UDim2.new(0, 0, 0, 64)
	local bodySize = UDim2.new(1, 0, 1, -72)

	if art and art.Image ~= 0 then
		-- Final art replaces the flat title bar entirely -- background
		-- transparent so only the art shows, real click target is an
		-- invisible button over the art's own baked X.
		frame.BackgroundTransparency = 1

		if art.AspectRatio then
			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.AspectRatio = art.AspectRatio
			aspect.DominantAxis = Enum.DominantAxis.Height
			aspect.Parent = frame
		end

		local artLabel = Instance.new("ImageLabel")
		artLabel.Name = "Art"
		artLabel.BackgroundTransparency = 1
		artLabel.Size = UDim2.fromScale(1, 1)
		artLabel.Image = "rbxassetid://" .. tostring(art.Image)
		artLabel.ScaleType = Enum.ScaleType.Fit
		artLabel.Parent = frame

		closeButton = Instance.new("TextButton")
		closeButton.Name = "Close"
		closeButton.BackgroundTransparency = 1
		closeButton.Text = ""
		closeButton.Size = art.CloseButtonSize or UDim2.new(0, 60, 0, 60)
		closeButton.Position = art.CloseButtonPosition or UDim2.new(1, -20, 0, 20)
		closeButton.AnchorPoint = Vector2.new(1, 0)
		closeButton.Parent = frame

		bodyPosition = art.BodyPosition or UDim2.new(0, 0, 0.22, 0)
		bodySize = art.BodySize or UDim2.new(1, 0, 0.76, 0)
	else
		frame.BackgroundColor3 = Theme.Colors.Background

		local titleBar = Instance.new("Frame")
		titleBar.Name = "TitleBar"
		titleBar.BackgroundColor3 = Theme.Colors.ButtonPrimary
		titleBar.BorderSizePixel = 0
		titleBar.Size = UDim2.new(1, 0, 0, 60)
		-- Rounded top corners only (a plain rectangle looked like a generic
		-- placeholder bar sitting inside the rounded outer frame) plus a
		-- gold underline to echo the final art's wood-sign-on-gold-rim look.
		Theme.applyOutlineCorner(titleBar, 0, UDim.new(0, 18))
		titleBar.Parent = frame

		local titleBarMask = Instance.new("Frame")
		titleBarMask.BackgroundColor3 = Theme.Colors.ButtonPrimary
		titleBarMask.BorderSizePixel = 0
		titleBarMask.Size = UDim2.new(1, 0, 0, 18)
		titleBarMask.Position = UDim2.new(0, 0, 1, -18)
		titleBarMask.ZIndex = titleBar.ZIndex
		titleBarMask.Parent = titleBar

		local underline = Instance.new("Frame")
		underline.BackgroundColor3 = Theme.Colors.TextGold
		underline.BorderSizePixel = 0
		underline.Size = UDim2.new(1, 0, 0, 4)
		underline.Position = UDim2.new(0, 0, 1, 0)
		underline.Parent = titleBar

		Theme.newLabel({
			Name = "Title",
			Text = title,
			Size = UDim2.new(1, -70, 1, 0),
			Position = UDim2.new(0, 16, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleBar,
		})

		closeButton = Theme.newButton({
			Name = "Close",
			Text = "X",
			Size = UDim2.new(0, 44, 0, 44),
			Position = UDim2.new(1, -50, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Color = Theme.Colors.ButtonDanger,
			Parent = titleBar,
		})
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = bodyPosition
	body.Size = bodySize
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
