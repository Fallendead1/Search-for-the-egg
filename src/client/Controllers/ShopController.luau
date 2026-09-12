--!strict
-- SHOP overlay: BAG capacity progression (barn counter presentation) and
-- the permanent GEMS shop (Gem-cost perks + Robux Gem packs + the
-- permanent 2x Gems promo). Tool unlock/upgrade purchase presentation
-- lives in UpgradeBookController since those are run-scoped Cash
-- purchases made mid-run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local MonetizationController = require(script.Parent.MonetizationController)
local Format = require(script.Parent.Parent.Util.Format)
local AssetConfig = require(ReplicatedStorage.SearchForTheEgg.AssetConfig)
local PermanentPerksConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.PermanentPerksConfig)

local UIController

local ShopController = {}

local TABS = { "BAG", "GEMS" }

local function buildBagTab(body: Instance)
	local scroll = Overlay.newScroll(body)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local level = PlayerState.Run.BagLevel or 0
	local maxLevel = #DisplayConfig.Bag.Levels

	Theme.newLabel({
		Text = ("LEVEL %d / %d"):format(level, maxLevel),
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 0,
		Parent = scroll,
	})

	for i, entry in ipairs(DisplayConfig.Bag.Levels) do
		local row = Theme.newPanel("Level" .. entry.Level, scroll)
		row.Size = UDim2.new(1, 0, 0, 56)
		row.LayoutOrder = i

		local owned = level >= entry.Level
		local isNext = level == entry.Level - 1
		local affordable = isNext and PlayerState.Run.InProgress and PlayerState.Run.CashCents >= entry.CostCents

		Theme.newLabel({
			Text = ("Capacity %d"):format(entry.Capacity),
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 0),
			Parent = row,
		})

		if owned then
			Theme.newLabel({
				Text = "OWNED",
				Size = UDim2.new(0.4, -10, 1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				TextColor = Theme.Colors.ButtonSecondary,
				Parent = row,
			})
		elseif isNext then
			local buyButton = Theme.newButton({
				Text = Format.cash(entry.CostCents),
				Size = UDim2.new(0, 120, 0, 44),
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = row,
			})
			Theme.setButtonEnabled(buyButton, affordable)
			buyButton.Activated:Connect(function()
				Remotes.fireServer("Gameplay_RequestBuyRunUpgrade", { Group = "Bag", UpgradeId = "Upgrade" })
			end)
		else
			Theme.newLabel({
				Text = "LOCKED",
				Size = UDim2.new(0.4, -10, 1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				TextColor = Theme.Colors.Locked,
				Parent = row,
			})
		end
	end

	local infiniteRow = Theme.newPanel("InfiniteBag", scroll)
	infiniteRow.Size = UDim2.new(1, 0, 0, 56)
	infiniteRow.LayoutOrder = maxLevel + 1

	Theme.newLabel({
		Text = "INFINITE BAG",
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = infiniteRow,
	})

	-- InfiniteBag is the Infinite Bag Game Pass's entitlement key -- ownership
	-- is server-authoritative via PlayerState.Profile.EntitlementSummary
	-- (Core_ProfileUpdated, mirroring MonetizationService.OwnsEntitlement's
	-- live Game Pass check), never derived from anything the client decides.
	if MonetizationController.ownsEntitlement("InfiniteBag") then
		Theme.newLabel({
			Text = "OWNED",
			Size = UDim2.new(0.4, -10, 1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			TextColor = Theme.Colors.ButtonSecondary,
			Parent = infiniteRow,
		})
	else
		local infiniteButton = Theme.newButton({
			Text = ("%d R$"):format(DisplayConfig.Bag.InfiniteBagRobux),
			Size = UDim2.new(0, 120, 0, 44),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = Theme.Colors.TextGold,
			Parent = infiniteRow,
		})
		local hasPass = MonetizationController.hasGamePass("InfiniteBagPermanent")
		Theme.setButtonEnabled(infiniteButton, hasPass)
		infiniteButton.Activated:Connect(function()
			MonetizationController.promptGamePass("InfiniteBagPermanent")
		end)
	end
end

-- 5 progress dots: dark navy for empty, bright green for purchased levels
-- (Section 41's "EMPTY -> dark/navy, PURCHASED -> green/bright").
local function buildProgressDots(parent: Instance, level: number, maxLevel: number, yOffset: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 16)
	row.Position = UDim2.new(0, 0, 0, yOffset)
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	for i = 1, maxLevel do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 16, 0, 16)
		dot.BackgroundColor3 = i <= level and Theme.Colors.ProgressDotFilled or Theme.Colors.ProgressDotEmpty
		dot.BorderSizePixel = 0
		Theme.applyOutlineCorner(dot, 1, UDim.new(1, 0))
		dot.Parent = row
	end
end

-- One 2x2-grid card per PermanentPerksConfig perk: icon placeholder, name,
-- progress dots, current level, and either the (flat, per PermanentPerksConfig)
-- Gem price or MAX.
local function buildPerkCard(parent: Instance, perk: any, layoutOrder: number)
	local level = PlayerState.Profile.PermanentPerkLevels[perk.Id] or 0
	local maxLevel = PermanentPerksConfig.MaxLevel

	local card = Theme.newPanel(perk.Id, parent)
	card.LayoutOrder = layoutOrder

	-- Final art (icon + title + 5 pip wells + UPGRADE footer baked in) when
	-- available; falls back to the plain icon-placeholder card otherwise.
	local cardArtId = AssetConfig.ShopPerkCards[perk.Id] or 0
	if cardArtId ~= 0 then
		card.BackgroundTransparency = 1
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Size = UDim2.fromScale(1, 1)
		art.Image = AssetConfig.image(cardArtId)
		art.ScaleType = Enum.ScaleType.Fit
		art.Parent = card
	else
		local iconArea = Instance.new("Frame")
		iconArea.BackgroundTransparency = 1
		iconArea.Size = UDim2.new(0, 48, 0, 48)
		iconArea.Position = UDim2.new(0.5, 0, 0, 8)
		iconArea.AnchorPoint = Vector2.new(0.5, 0)
		iconArea.Parent = card

		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.Image = AssetConfig.image(AssetConfig.ToolIcons.Bag)
		icon.Parent = iconArea
		Theme.newLabel({ Text = "⭐", Size = UDim2.fromScale(1, 1), Font = Theme.Font, Parent = iconArea })

		Theme.newLabel({
			Text = perk.Name,
			Size = UDim2.new(1, -8, 0, 24),
			Position = UDim2.new(0, 4, 0, 60),
			Font = Theme.FontBody,
			Parent = card,
		})
	end

	buildProgressDots(card, level, maxLevel, 88)

	Theme.newLabel({
		Text = ("LEVEL %d / %d"):format(level, maxLevel),
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 108),
		TextColor = Theme.Colors.TextDark,
		Font = Theme.FontBody,
		Parent = card,
	})

	if level >= maxLevel then
		Theme.newLabel({
			Text = "MAX",
			Size = UDim2.new(1, -20, 0, 32),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			TextColor = Theme.Colors.ButtonSecondary,
			Parent = card,
		})
	else
		local affordable = PlayerState.Profile.Gems >= perk.GemCost
		local buyButton = Theme.newButton({
			Text = ("%d GEMS"):format(perk.GemCost),
			Size = UDim2.new(1, -20, 0, 32),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Theme.Colors.ButtonPurchase,
			TextColor = Theme.Colors.TextLight,
			Parent = card,
		})
		Theme.setButtonEnabled(buyButton, affordable)
		buyButton.Activated:Connect(function()
			-- CoreBootstrap's handler reads this as a raw perkId string.
			Remotes.fireServer("Core_RequestBuyPermanentPerk", perk.Id)
		end)
	end
end

local function buildPerkGrid(parent: Instance)
	local grid = Instance.new("Frame")
	grid.Name = "PerkGrid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(0.62, -8, 1, 0)
	grid.Position = UDim2.new(0, 0, 0, 0)
	grid.Parent = parent

	Theme.newLabel({
		Text = "UPGRADES",
		Size = UDim2.new(1, 0, 0, 30),
		Parent = grid,
	})

	local gridContainer = Instance.new("Frame")
	gridContainer.BackgroundTransparency = 1
	gridContainer.Size = UDim2.new(1, 0, 1, -34)
	gridContainer.Position = UDim2.new(0, 0, 0, 34)
	gridContainer.Parent = grid

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.new(0, 10, 0, 10)
	layout.CellSize = UDim2.new(0.485, 0, 0.47, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gridContainer

	for i, perk in ipairs(DisplayConfig.PermanentPerks) do
		buildPerkCard(gridContainer, perk, i)
	end
end

-- Cyan/blue Gem purchase cards (Section 37/42) -- real configured Developer
-- Products only (DisplayConfig.GemPacks, sourced from MonetizationConfig),
-- never the reference game's numbers. Id == 0 disables the button rather
-- than firing an invalid Marketplace prompt (MonetizationController already
-- guards this centrally).
local function buildGemCards(parent: Instance)
	local column = Instance.new("Frame")
	column.Name = "GemCards"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(0.36, 0, 1, 0)
	column.Position = UDim2.new(1, 0, 0, 0)
	column.AnchorPoint = Vector2.new(1, 0)
	column.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column

	for i, pack in ipairs(DisplayConfig.GemPacks) do
		local card = Theme.newPanel(pack.Id, column)
		card.Size = UDim2.new(1, 0, 0, 92)
		card.LayoutOrder = i

		-- Final art (gem pile + count baked in, matching the real Gems100/
		-- Gems400 Developer Products exactly) when available.
		local cardArtId = AssetConfig.GemPackCards[pack.Id] or 0
		if cardArtId ~= 0 then
			card.BackgroundTransparency = 1
			local art = Instance.new("ImageLabel")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.Size = UDim2.fromScale(1, 1)
			art.Image = AssetConfig.image(cardArtId)
			art.ScaleType = Enum.ScaleType.Fit
			art.Parent = card
		else
			card.BackgroundColor3 = Theme.Colors.Gems
			Theme.newLabel({
				Text = ("%d GEMS"):format(pack.Gems),
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.new(0, 0, 0, 6),
				Parent = card,
			})
		end

		local hasProduct = MonetizationController.hasProduct(pack.Id)
		local buyButton = Theme.newButton({
			Text = hasProduct and ("%d R$"):format(pack.Robux) or "UNAVAILABLE",
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Theme.Colors.ButtonSecondary,
			Parent = card,
		})
		Theme.setButtonEnabled(buyButton, hasProduct)
		buyButton.Activated:Connect(function()
			if hasProduct then
				MonetizationController.promptProduct(pack.Id)
			end
		end)
	end

	local promoCard = Theme.newPanel("DoubleGemsPromo", column)
	promoCard.Size = UDim2.new(1, 0, 0, 92)
	promoCard.LayoutOrder = 100
	promoCard.BackgroundColor3 = Theme.Colors.TextGold

	Theme.newLabel({
		Text = "2x GEMS\n[PERMANENT]",
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.new(0, 0, 0, 4),
		Parent = promoCard,
	})

	local hasDoubleGems = MonetizationController.hasGamePass("Gems2xPermanent")
	local promoButton = Theme.newButton({
		Text = hasDoubleGems and "OWNED" or ("%d R$"):format(DisplayConfig.DoubleGemsRobux),
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = promoCard,
	})
	Theme.setButtonEnabled(promoButton, not hasDoubleGems)
	promoButton.Activated:Connect(function()
		if not hasDoubleGems then
			MonetizationController.promptGamePass("Gems2xPermanent")
		end
	end)
end

local function buildGemsTab(body: Instance)
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = body

	buildPerkGrid(container)
	buildGemCards(container)
end

function ShopController.open(defaultTab: string?)
	local overlay = Overlay.new("SHOP")
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.new(1, -20, 0, 44)
	tabRow.Position = UDim2.new(0.5, 0, 0, 4)
	tabRow.AnchorPoint = Vector2.new(0.5, 0)
	tabRow.Parent = overlay.Body

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabRow

	local pagesHost = Instance.new("Frame")
	pagesHost.BackgroundTransparency = 1
	pagesHost.Position = UDim2.new(0, 0, 0, 52)
	pagesHost.Size = UDim2.new(1, 0, 1, -52)
	pagesHost.Parent = overlay.Body

	local pageFrames: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}

	local function selectTab(tabName: string)
		for id, frame in pairs(pageFrames) do
			frame.Visible = id == tabName
		end
		for id, button in pairs(tabButtons) do
			button.BackgroundColor3 = id == tabName and Theme.Colors.ButtonPrimary or Theme.Colors.PanelFill
		end
	end

	for _, tabName in ipairs(TABS) do
		local pageFrame = Instance.new("Frame")
		pageFrame.Name = tabName
		pageFrame.BackgroundTransparency = 1
		pageFrame.Size = UDim2.fromScale(1, 1)
		pageFrame.Visible = false
		pageFrame.Parent = pagesHost
		pageFrames[tabName] = pageFrame

		if tabName == "BAG" then
			buildBagTab(pageFrame)
		else
			buildGemsTab(pageFrame)
		end

		local tabButton = Theme.newButton({
			Text = tabName,
			Size = UDim2.new(0, 130, 1, 0),
			Parent = tabRow,
		})
		tabButtons[tabName] = tabButton
		tabButton.Activated:Connect(function()
			selectTab(tabName)
		end)
	end

	selectTab(defaultTab or "BAG")

	-- Bag level/cost/affordability and InfiniteBag ownership are
	-- authoritative server state (Gameplay_RunState and Core_ProfileUpdated
	-- respectively) -- rebuild the BAG tab in place whenever either arrives
	-- so it never shows a stale level/cost after a purchase confirms.
	local function refreshBagTab()
		local frame = pageFrames.BAG
		if not frame then
			return
		end
		for _, child in ipairs(frame:GetChildren()) do
			child:Destroy()
		end
		buildBagTab(frame)
	end

	-- GEMS tab (permanent perk levels, Gems balance, Gems2x ownership) is
	-- entirely Core_ProfileUpdated-driven -- same staleness fix as BAG.
	local function refreshGemsTab()
		local frame = pageFrames.GEMS
		if not frame then
			return
		end
		for _, child in ipairs(frame:GetChildren()) do
			child:Destroy()
		end
		buildGemsTab(frame)
	end

	local runConnection = PlayerState.RunChanged:Connect(refreshBagTab)
	local profileConnection = PlayerState.ProfileChanged:Connect(function()
		refreshBagTab()
		refreshGemsTab()
	end)

	UIController.openOverlay("Shop", overlay.Frame, function()
		runConnection()
		profileConnection()
	end)
end

function ShopController.init(ui)
	UIController = ui
end

return ShopController
