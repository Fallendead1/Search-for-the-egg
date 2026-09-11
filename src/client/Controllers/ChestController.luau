--!strict
-- ALIEN CHEST overlay: odds display, token open, Robux multi-open
-- prompts, and the reward reveal sequence. The server chooses every
-- reward -- this controller only requests an open and presents whatever
-- Core_AlienChestResult reports back.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local MonetizationController = require(script.Parent.MonetizationController)
local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)

local UIController

local ChestController = {}

local RARITY_COLOR = {
	Common = Theme.Colors.RarityCommon,
	Uncommon = Theme.Colors.RarityUncommon,
	Rare = Theme.Colors.RarityRare,
	Epic = Theme.Colors.RarityEpic,
	Legendary = Theme.Colors.RarityLegendary,
}

local function oddsEntryById(id: string)
	for _, entry in ipairs(DisplayConfig.AlienChest.Odds) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

local revealHost: Frame? = nil
local openButton: TextButton? = nil
local opening = false

local function showRewardCard(reward: any, onDone: () -> ())
	if not revealHost then
		onDone()
		return
	end

	local entry = reward.Id and oddsEntryById(reward.Id)
	local rarity = entry and entry.Rarity or "Common"
	local color = RARITY_COLOR[rarity] or Theme.Colors.RarityCommon

	local card = Theme.newPanel("RewardCard", revealHost)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0, 0, 0, 0)
	card.BackgroundColor3 = color

	Theme.newLabel({
		Text = reward.Label or (entry and entry.Label) or tostring(reward.Id),
		Size = UDim2.new(1, -20, 0.5, 0),
		Position = UDim2.new(0.5, 0, 0.35, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = card,
	})
	Theme.newLabel({
		Text = rarity:upper(),
		Size = UDim2.new(1, -20, 0.3, 0),
		Position = UDim2.new(0.5, 0, 0.75, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor = Theme.Colors.TextDark,
		Font = Theme.FontBody,
		Parent = card,
	})

	CameraController.playChestRevealFraming()
	SoundController.play("AlienChestOpen")

	local grow = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.5, 0, 0.6, 0),
	})
	grow:Play()

	task.delay(1.6, function()
		local shrink = TweenService:Create(card, TweenInfo.new(0.25), { Size = UDim2.new(0, 0, 0, 0) })
		shrink:Play()
		shrink.Completed:Connect(function()
			card:Destroy()
			onDone()
		end)
	end)
end

local function presentRewards(rewards: { any })
	local index = 0
	local function next()
		index += 1
		local reward = rewards[index]
		if not reward then
			opening = false
			if openButton then
				Theme.setButtonEnabled(openButton, PlayerState.Profile.AlienTokens >= DisplayConfig.AlienChest.OpenTokenCost)
			end
			return
		end
		showRewardCard(reward, next)
	end
	next()
end

local function buildOddsList(parent: Instance)
	local scroll = Overlay.newScroll(parent)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, entry in ipairs(DisplayConfig.AlienChest.Odds) do
		local row = Theme.newPanel(entry.Id, scroll)
		row.Size = UDim2.new(1, 0, 0, 44)
		row.LayoutOrder = i
		row.BackgroundColor3 = RARITY_COLOR[entry.Rarity] or Theme.Colors.PanelFill

		Theme.newLabel({
			Text = entry.Label,
			Size = UDim2.new(0.7, 0, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.newLabel({
			Text = ("%s%%"):format(tostring(entry.Chance)),
			Size = UDim2.new(0.25, -10, 1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
end

function ChestController.open()
	local overlay = Overlay.new("ALIEN CHEST")
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	local oddsFrame = Instance.new("Frame")
	oddsFrame.BackgroundTransparency = 1
	oddsFrame.Size = UDim2.new(1, -20, 1, -180)
	oddsFrame.Position = UDim2.new(0.5, 0, 0, 8)
	oddsFrame.AnchorPoint = Vector2.new(0.5, 0)
	oddsFrame.Parent = overlay.Body
	buildOddsList(oddsFrame)

	revealHost = Instance.new("Frame")
	revealHost.BackgroundTransparency = 1
	revealHost.Size = UDim2.fromScale(1, 1)
	revealHost.ZIndex = 5
	revealHost.Parent = overlay.Body

	local buttonRow = Instance.new("Frame")
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.new(1, -20, 0, 96)
	buttonRow.Position = UDim2.new(0.5, 0, 1, -8)
	buttonRow.AnchorPoint = Vector2.new(0.5, 1)
	buttonRow.Parent = overlay.Body

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.24, -8, 0, 44)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.Parent = buttonRow

	openButton = Theme.newButton({
		Text = ("OPEN - %d TOKENS"):format(DisplayConfig.AlienChest.OpenTokenCost),
		LayoutOrder = 1,
		Parent = buttonRow,
	})
	Theme.setButtonEnabled(openButton, PlayerState.Profile.AlienTokens >= DisplayConfig.AlienChest.OpenTokenCost)
	openButton.Activated:Connect(function()
		if opening then
			return
		end
		opening = true
		Theme.setButtonEnabled(openButton, false)
		Remotes.fireServer("Core_RequestOpenAlienChest", { Count = 1, Method = "Tokens" })
	end)

	for i, multi in ipairs(DisplayConfig.AlienChest.MultiOpen) do
		local button = Theme.newButton({
			Text = ("%d CHESTS - %d R$"):format(multi.Count, multi.Robux),
			LayoutOrder = i + 1,
			Color = Theme.Colors.TextGold,
			Parent = buttonRow,
		})
		local productKey = "AlienChest" .. tostring(multi.Count)
		Theme.setButtonEnabled(button, MonetizationController.hasProduct(productKey))
		button.Activated:Connect(function()
			MonetizationController.promptProduct(productKey)
		end)
	end

	UIController.openOverlay("AlienChest", overlay.Frame, function()
		revealHost = nil
		openButton = nil
		opening = false
	end)
end

function ChestController.init(ui)
	UIController = ui

	Remotes.onClientEvent("Core_AlienChestResult", function(payload: any)
		if type(payload) ~= "table" then
			opening = false
			return
		end
		local rewards = payload.Rewards or { payload }
		presentRewards(rewards)
	end)
end

return ChestController
