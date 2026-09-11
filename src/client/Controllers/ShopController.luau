--!strict
-- SHOP overlay: BAG capacity progression (barn counter presentation) and
-- the permanent GEMS shop (Gem-cost perks + Robux Gem packs + the
-- permanent 2x Gems promo). Tool unlock/upgrade purchase presentation
-- lives in UpgradeBookController since those are run-scoped Cash
-- purchases made mid-run.

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local MonetizationController = require(script.Parent.MonetizationController)
local Format = require(script.Parent.Parent.Util.Format)

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

local function buildGemsTab(body: Instance)
	local scroll = Overlay.newScroll(body)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	Theme.newLabel({
		Text = "PERMANENT PERKS",
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 0,
		Parent = scroll,
	})

	for i, perk in ipairs(DisplayConfig.PermanentPerks) do
		local level = PlayerState.Profile.PermanentPerkLevels[perk.Id] or 0
		local row = Theme.newPanel(perk.Id, scroll)
		row.Size = UDim2.new(1, 0, 0, 56)
		row.LayoutOrder = i

		Theme.newLabel({
			Text = ("%s (Lvl %d/5)"):format(perk.Name, level),
			Size = UDim2.new(0.55, 0, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		if level >= 5 then
			Theme.newLabel({
				Text = "MAX",
				Size = UDim2.new(0.35, -10, 1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				TextColor = Theme.Colors.ButtonSecondary,
				Parent = row,
			})
		else
			local affordable = PlayerState.Profile.Gems >= perk.GemCost
			local buyButton = Theme.newButton({
				Text = ("%d GEMS"):format(perk.GemCost),
				Size = UDim2.new(0, 140, 0, 44),
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = Theme.Colors.Gems,
				Parent = row,
			})
			Theme.setButtonEnabled(buyButton, affordable)
			buyButton.Activated:Connect(function()
				-- CoreBootstrap's handler reads this as a raw perkId string.
				Remotes.fireServer("Core_RequestBuyPermanentPerk", perk.Id)
			end)
		end
	end

	Theme.newLabel({
		Text = "GEMS",
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 100,
		Parent = scroll,
	})

	for i, pack in ipairs(DisplayConfig.GemPacks) do
		local row = Theme.newPanel(pack.Id, scroll)
		row.Size = UDim2.new(1, 0, 0, 56)
		row.LayoutOrder = 100 + i

		Theme.newLabel({
			Text = ("%d GEMS"):format(pack.Gems),
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local buyButton = Theme.newButton({
			Text = ("%d R$"):format(pack.Robux),
			Size = UDim2.new(0, 120, 0, 44),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = Theme.Colors.TextGold,
			Parent = row,
		})
		local hasProduct = MonetizationController.hasProduct(pack.Id)
		Theme.setButtonEnabled(buyButton, hasProduct)
		buyButton.Activated:Connect(function()
			MonetizationController.promptProduct(pack.Id)
		end)
	end

	local promoRow = Theme.newPanel("DoubleGemsPromo", scroll)
	promoRow.Size = UDim2.new(1, 0, 0, 56)
	promoRow.LayoutOrder = 200
	promoRow.BackgroundColor3 = Theme.Colors.TextGold

	Theme.newLabel({
		Text = "2x GEMS [PERMANENT]",
		Size = UDim2.new(0.55, 0, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = promoRow,
	})

	local promoButton = Theme.newButton({
		Text = ("%d R$"):format(DisplayConfig.DoubleGemsRobux),
		Size = UDim2.new(0, 120, 0, 44),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = promoRow,
	})
	local hasDoubleGems = MonetizationController.hasGamePass("Gems2xPermanent")
	Theme.setButtonEnabled(promoButton, hasDoubleGems)
	promoButton.Activated:Connect(function()
		MonetizationController.promptGamePass("Gems2xPermanent")
	end)
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
