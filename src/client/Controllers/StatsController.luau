--!strict
-- STATS overlay: avatar, username, and the sanitized Core profile snapshot
-- fields. Purely presentational -- never computes totals locally.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Format = require(script.Parent.Parent.Util.Format)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local UIController

local StatsController = {}

local function statRow(parent: Instance, order: number, label: string, value: string)
	local row = Instance.new("Frame")
	row.Name = label
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = order
	row.Parent = parent

	Theme.newLabel({
		Text = label,
		Size = UDim2.new(0.5, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	Theme.newLabel({
		Text = value,
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor = Theme.Colors.TextGold,
		Parent = row,
	})
end

function StatsController.open()
	local overlay = Overlay.new("STATS")
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = overlay.Body

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.PaddingTop = UDim.new(0, 16)
	padding.Parent = overlay.Body

	local player = Players.LocalPlayer
	local profile = PlayerState.Profile

	statRow(overlay.Body, 1, "USERNAME", player.Name)
	statRow(overlay.Body, 2, "CLASS", profile.EquippedClass or "Starter")
	statRow(overlay.Body, 3, "TOTAL PLAYTIME", Format.time(profile.TotalPlaytime or 0))
	statRow(overlay.Body, 4, "TIME RECORD", profile.TimeRecord and Format.time(profile.TimeRecord) or "--:--")
	statRow(overlay.Body, 5, "TOTAL WINS", tostring(profile.TotalWins or 0))
	statRow(overlay.Body, 6, "FEATHERS COLLECTED", Format.compactNumber(profile.FeathersCollected or 0))

	UIController.openOverlay("Stats", overlay.Frame)
end

function StatsController.init(ui)
	UIController = ui
end

return StatsController
