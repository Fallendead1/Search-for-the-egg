--!strict
-- Lobby screen: top currency/utility bar, right-side menu buttons, left
-- promo, left feature buttons, a lightweight leaderboard, and the party
-- pad (built by PartyController).

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.UI.Theme)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local Format = require(script.Parent.Parent.Util.Format)
local SoundController = require(script.Parent.SoundController)
local MonetizationController = require(script.Parent.MonetizationController)
local PartyController = require(script.Parent.PartyController)

local UIController, StatsController, InventoryController, CodesController, ShopController, ClassController, ChestController

local LobbyController = {}

local gemsLabel: TextLabel
local tokensLabel: TextLabel
local soundButton: TextButton

local function buildTopBar(parent: Instance)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundTransparency = 1
	topBar.Size = UDim2.new(1, -20, 0, 64)
	topBar.Position = UDim2.new(0.5, 0, 0, 10)
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = topBar

	local gemsPanel = Theme.newPanel("Gems", topBar)
	gemsPanel.Size = UDim2.new(0, 130, 1, 0)
	gemsPanel.BackgroundColor3 = Theme.Colors.Gems
	gemsLabel = Theme.newLabel({ Text = "0 GEMS", Size = UDim2.fromScale(1, 1), Parent = gemsPanel })

	local tokensPanel = Theme.newPanel("AlienTokens", topBar)
	tokensPanel.Size = UDim2.new(0, 150, 1, 0)
	tokensPanel.BackgroundColor3 = Theme.Colors.AlienTokens
	tokensLabel = Theme.newLabel({ Text = "0 TOKENS", Size = UDim2.fromScale(1, 1), Parent = tokensPanel })

	local inviteButton = Theme.newButton({ Text = "INVITE", Size = UDim2.new(0, 110, 1, 0), Parent = topBar })
	inviteButton.Activated:Connect(function()
		local ok = pcall(function()
			game:GetService("SocialService"):PromptGameInvite(Players.LocalPlayer)
		end)
		if not ok then
			warn("[LobbyController] Invite prompt unavailable in this context.")
		end
	end)

	soundButton = Theme.newButton({ Text = "SOUND: ON", Size = UDim2.new(0, 110, 1, 0), Parent = topBar })
	soundButton.Activated:Connect(function()
		local muted = SoundController.toggleMuted()
		soundButton.Text = muted and "SOUND: OFF" or "SOUND: ON"
	end)
end

local function buildRightButtons(parent: Instance)
	local column = Instance.new("Frame")
	column.Name = "RightButtons"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(0, 160, 0, 220)
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -16, 0.5, 0)
	column.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = column

	local codesButton = Theme.newButton({ Text = "CODES", Size = UDim2.new(1, 0, 0, 56), Parent = column })
	codesButton.Activated:Connect(function()
		CodesController.open()
	end)

	local statsButton = Theme.newButton({ Text = "STATS", Size = UDim2.new(1, 0, 0, 56), Parent = column })
	statsButton.Activated:Connect(function()
		StatsController.open()
	end)

	local inventoryButton = Theme.newButton({ Text = "INVENTORY", Size = UDim2.new(1, 0, 0, 56), Parent = column })
	inventoryButton.Activated:Connect(function()
		InventoryController.open()
	end)
end

local function buildLeftButtons(parent: Instance)
	local column = Instance.new("Frame")
	column.Name = "LeftButtons"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(0, 160, 0, 220)
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 16, 0.5, 0)
	column.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = column

	local shopButton = Theme.newButton({ Text = "SHOP", Size = UDim2.new(1, 0, 0, 56), Parent = column })
	shopButton.Activated:Connect(function()
		ShopController.open("BAG")
	end)

	local classesButton = Theme.newButton({ Text = "CLASSES", Size = UDim2.new(1, 0, 0, 56), Parent = column })
	classesButton.Activated:Connect(function()
		ClassController.open()
	end)

	local chestButton = Theme.newButton({ Text = "ALIEN CHEST", Size = UDim2.new(1, 0, 0, 56), Parent = column })
	chestButton.Activated:Connect(function()
		ChestController.open()
	end)
end

local function buildLeftPromo(parent: Instance)
	local promo = Theme.newPanel("DoubleGemsPromo", parent)
	promo.Size = UDim2.new(0, 200, 0, 110)
	promo.AnchorPoint = Vector2.new(0, 0)
	promo.Position = UDim2.new(0, 16, 0, 84)
	promo.BackgroundColor3 = Theme.Colors.TextGold

	Theme.newLabel({
		Text = "2x GEMS\n[PERMANENT]",
		Size = UDim2.new(1, 0, 0, 60),
		Parent = promo,
	})

	local buyButton = Theme.newButton({
		Text = ("%d R$"):format(DisplayConfig.DoubleGemsRobux),
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = promo,
	})
	Theme.setButtonEnabled(buyButton, MonetizationController.hasGamePass("DoubleGems"))
	buyButton.Activated:Connect(function()
		MonetizationController.promptGamePass("DoubleGems")
	end)
end

local function buildLeaderboard(parent: Instance)
	local panel = Theme.newPanel("Leaderboard", parent)
	panel.Size = UDim2.new(0, 220, 0, 220)
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0, 16, 0, 10)

	Theme.newLabel({
		Text = "TOP FARMERS",
		Size = UDim2.new(1, 0, 0, 32),
		Parent = panel,
	})

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 8, 0, 36)
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	local function refresh()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		local ranked = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local leaderstats = plr:FindFirstChild("leaderstats")
			local stat = leaderstats and (leaderstats:FindFirstChild("Wins") or leaderstats:FindFirstChildOfClass("IntValue"))
			table.insert(ranked, { Name = plr.Name, Value = stat and stat.Value or 0 })
		end
		table.sort(ranked, function(a, b)
			return a.Value > b.Value
		end)

		for i = 1, math.min(5, #ranked) do
			local entry = ranked[i]
			Theme.newLabel({
				Text = ("%d. %s - %d"):format(i, entry.Name, entry.Value),
				Size = UDim2.new(1, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.FontBody,
				Parent = list,
			})
		end

		if #ranked == 0 then
			Theme.newLabel({
				Text = "No data yet.",
				Size = UDim2.new(1, 0, 0, 22),
				Font = Theme.FontBody,
				Parent = list,
			})
		end
	end

	refresh()
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(refresh)
	task.spawn(function()
		while panel.Parent do
			task.wait(5)
			refresh()
		end
	end)
end

local function refreshCurrencyLabels()
	if gemsLabel then
		gemsLabel.Text = Format.compactNumber(PlayerState.Profile.Gems) .. " GEMS"
	end
	if tokensLabel then
		tokensLabel.Text = Format.compactNumber(PlayerState.Profile.AlienTokens) .. " TOKENS"
	end
end

function LobbyController.build(root: Frame)
	buildTopBar(root)
	buildRightButtons(root)
	buildLeftButtons(root)
	buildLeftPromo(root)
	buildLeaderboard(root)
	PartyController.build(root)
	refreshCurrencyLabels()
end

function LobbyController.init(dependencies: {
	UIController: any,
	StatsController: any,
	InventoryController: any,
	CodesController: any,
	ShopController: any,
	ClassController: any,
	ChestController: any,
})
	UIController = dependencies.UIController
	StatsController = dependencies.StatsController
	InventoryController = dependencies.InventoryController
	CodesController = dependencies.CodesController
	ShopController = dependencies.ShopController
	ClassController = dependencies.ClassController
	ChestController = dependencies.ChestController

	PlayerState.ProfileChanged:Connect(refreshCurrencyLabels)
end

return LobbyController
