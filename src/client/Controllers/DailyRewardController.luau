--!strict
-- DAILY REWARDS overlay: 8-day ladder, 2 rows of 4 cards. Server
-- (DailyRewardService) is the only source of truth for CurrentDay/
-- NextClaimAt/CanClaim -- this only requests a claim and renders whatever
-- Core_ProfileUpdated reflects back afterward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local AssetConfig = require(ReplicatedStorage.SearchForTheEgg.AssetConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local UIController

local DailyRewardController = {}

-- Mirrors MetaConfig/DailyRewardConfig.Days -- kept here (not required
-- directly) since the client only ever needs Day/Gems/Milestone/Premium for
-- display; CurrentDay/NextClaimAt/eligibility always come from the server.
local DAYS = {
	{ Day = 1, Gems = 25 },
	{ Day = 2, Gems = 50, Milestone = true },
	{ Day = 3, Gems = 25 },
	{ Day = 4, Gems = 35 },
	{ Day = 5, Gems = 75, Milestone = true },
	{ Day = 6, Gems = 40 },
	{ Day = 7, Gems = 50 },
	{ Day = 8, Gems = 100, Milestone = true, Premium = true },
}

local hasAutoOpened = false
local cardRefreshers: { () -> () } = {}

local function cardColors(day: number, entry: any)
	if entry.Premium then
		return Color3.fromRGB(120, 210, 235), Color3.fromRGB(40, 130, 160)
	elseif entry.Milestone then
		return Color3.fromRGB(255, 224, 120), Color3.fromRGB(200, 160, 40)
	end
	return Theme.Colors.PanelFill, Theme.Colors.PanelOutline
end

local function buildCard(parent: Instance, entry: any, layoutOrder: number)
	local currentDay = PlayerState.Profile.DailyRewardDay or 1
	local nextClaimAt = PlayerState.Profile.DailyRewardNextClaimAt or 0
	local canClaimNow = os.time() >= nextClaimAt

	-- A day is "claimed" (already behind us in the ladder) if the current
	-- day has moved past it in this cycle; "available" only if it's exactly
	-- today's day AND the server says we're eligible; everything else Locked.
	local isToday = entry.Day == currentDay
	local isAvailable = isToday and canClaimNow
	local isClaimed = not isToday and entry.Day < currentDay

	local bgColor, outlineColor = cardColors(entry.Day, entry)

	local card = Instance.new("Frame")
	card.Name = "Day" .. entry.Day
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = isClaimed and Color3.fromRGB(120, 120, 120) or bgColor
	card.BorderSizePixel = 0
	local corner, stroke = Theme.applyOutlineCorner(card, 3)
	stroke.Color = outlineColor
	card.Parent = parent

	Theme.newLabel({
		Text = "DAY " .. entry.Day,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 6),
		Parent = card,
	})

	local iconArea = Instance.new("Frame")
	iconArea.BackgroundTransparency = 1
	iconArea.Size = UDim2.new(0.7, 0, 0, 60)
	iconArea.Position = UDim2.new(0.5, 0, 0, 36)
	iconArea.AnchorPoint = Vector2.new(0.5, 0)
	iconArea.Parent = card

	-- Ready for a future asset id (AssetConfig.DailyRewardIcons) -- blank
	-- until then, with a text glyph fallback so the card never looks empty.
	local iconId = entry.Premium and AssetConfig.DailyRewardIcons.PremiumChest
		or entry.Milestone and AssetConfig.DailyRewardIcons.Chest
		or AssetConfig.DailyRewardIcons.Gem
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Image = AssetConfig.image(iconId)
	icon.Parent = iconArea

	Theme.newLabel({
		Text = entry.Milestone and "🎁" or "💎",
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font,
		Parent = iconArea,
	})

	Theme.newLabel({
		Text = ("+%d Gems"):format(entry.Gems),
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 100),
		TextColor = isClaimed and Theme.Colors.TextLight or Theme.Colors.TextDark,
		Parent = card,
	})

	local button = Theme.newButton({
		Text = isClaimed and "CLAIMED" or (isAvailable and "CLAIM" or "LOCKED"),
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Theme.Colors.ButtonSecondary,
		Parent = card,
	})
	Theme.setButtonEnabled(button, isAvailable)
	if isClaimed then
		-- Checkmark-style completed state -- distinct from "locked" even
		-- though both render as a disabled button.
		button.Text = "CLAIMED  ✓"
		button.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		button.Active = false
	end
	button.Activated:Connect(function()
		if not isAvailable then
			return
		end
		Remotes.fireServer("Core_RequestClaimDailyReward")
	end)

	return card
end

local function buildGrid(body: Instance)
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -24, 1, -16)
	grid.Position = UDim2.fromScale(0.5, 0.5)
	grid.AnchorPoint = Vector2.new(0.5, 0.5)
	grid.Parent = body

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.new(0, 10, 0, 10)
	layout.CellSize = UDim2.new(0.235, 0, 0.46, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, entry in ipairs(DAYS) do
		buildCard(grid, entry, i)
	end
end

local function refresh(body: Instance)
	for _, child in ipairs(body:GetChildren()) do
		child:Destroy()
	end
	buildGrid(body)
end

function DailyRewardController.open()
	local overlay = Overlay.new("DAILY REWARDS", UDim2.new(0.8, 0, 0.7, 0))
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	buildGrid(overlay.Body)

	local profileConnection = PlayerState.ProfileChanged:Connect(function()
		refresh(overlay.Body)
	end)

	UIController.openOverlay("DailyRewards", overlay.Frame, function()
		profileConnection()
	end)
end

-- Reusable hook (Section 40: "provide a reusable Rewards button/hook so it
-- can be reopened later") -- anything (side menu, a Lobby prompt) can call
-- this directly instead of duplicating the open() logic.
function DailyRewardController.openIfAvailable()
	local nextClaimAt = PlayerState.Profile.DailyRewardNextClaimAt or 0
	if os.time() >= nextClaimAt then
		DailyRewardController.open()
		return true
	end
	return false
end

function DailyRewardController.init(ui)
	UIController = ui

	-- Auto-open once per session, the first time we learn a reward is ready
	-- (the initial Core_ProfileUpdated after Core_RequestProfileSnapshot, or
	-- whichever one first reflects an available claim).
	PlayerState.ProfileChanged:Connect(function()
		if hasAutoOpened then
			return
		end
		if UIController.isOverlayOpen() then
			return
		end
		local nextClaimAt = PlayerState.Profile.DailyRewardNextClaimAt or 0
		if os.time() >= nextClaimAt then
			hasAutoOpened = true
			DailyRewardController.open()
		end
	end)
end

return DailyRewardController
