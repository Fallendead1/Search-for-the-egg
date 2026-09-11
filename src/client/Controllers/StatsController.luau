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

local function buildStatRows(body: Instance)
	local player = Players.LocalPlayer
	local profile = PlayerState.Profile

	statRow(body, 1, "USERNAME", player.Name)
	statRow(body, 2, "CLASS", profile.EquippedClass or "Starter")
	statRow(body, 3, "TOTAL PLAYTIME", Format.time(profile.TotalPlaytime or 0))
	statRow(body, 4, "TIME RECORD", profile.TimeRecord and Format.time(profile.TimeRecord) or "--:--")
	statRow(body, 5, "TOTAL WINS", Format.integer(profile.TotalWins or 0))
	statRow(body, 6, "FEATHERS COLLECTED", Format.compactNumber(profile.FeathersCollected or 0))
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

	buildStatRows(overlay.Body)

	-- Every value here comes from PlayerState.Profile (Core_ProfileUpdated)
	-- -- rebuild in place if it changes while this overlay happens to be
	-- open (e.g. a run completion landing Wins/BestTime/Feathers) instead
	-- of only showing them stale until next open.
	local profileConnection = PlayerState.ProfileChanged:Connect(function()
		for _, child in ipairs(overlay.Body:GetChildren()) do
			if not (child:IsA("UILayout") or child:IsA("UIPadding")) then
				child:Destroy()
			end
		end
		buildStatRows(overlay.Body)
	end)

	UIController.openOverlay("Stats", overlay.Frame, function()
		profileConnection()
	end)
end

function StatsController.init(ui)
	UIController = ui
end

return StatsController
