--!strict
-- INVENTORY overlay: Pitchfork/Dynamite/Vacuum/Drone skin categories, each
-- with variant cards showing locked/owned/equipped state. Selection is
-- only visually finalized once Core_ProfileUpdated confirms it.

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local UIController

local InventoryController = {}

local function isOwned(categoryId: string, variantId: string): boolean
	if variantId == "Default" then
		return true
	end
	local key = categoryId .. "_" .. variantId
	return PlayerState.Profile.OwnedSkins[key] == true
end

local function isEquipped(categoryId: string, variantId: string): boolean
	return PlayerState.Profile.EquippedSkins[categoryId] == variantId
		or (variantId == "Default" and PlayerState.Profile.EquippedSkins[categoryId] == nil)
end

local function buildVariantCard(parent: Instance, categoryId: string, variant: { Id: string, Name: string })
	local card = Theme.newPanel(variant.Id, parent)
	card.Size = UDim2.new(0, 160, 0, 140)

	local owned = isOwned(categoryId, variant.Id)
	local equipped = isEquipped(categoryId, variant.Id)

	Theme.newLabel({
		Text = variant.Name,
		Size = UDim2.new(1, -12, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = card,
	})

	if not owned then
		Theme.newLabel({
			Text = "LOCKED",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0.5, 0, 0, 56),
			AnchorPoint = Vector2.new(0.5, 0),
			TextColor = Theme.Colors.Locked,
			Parent = card,
		})
		return
	end

	local selectButton = Theme.newButton({
		Text = equipped and "EQUIPPED" or "SELECT",
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = equipped and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
		Parent = card,
	})

	if equipped then
		Theme.setButtonEnabled(selectButton, false)
	end

	selectButton.Activated:Connect(function()
		if equipped then
			return
		end
		Remotes.fireServer("Core_RequestSelectSkin", {
			Category = categoryId,
			Variant = variant.Id,
		})
	end)
end

function InventoryController.open()
	local overlay = Overlay.new("INVENTORY")
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	local scroll = Overlay.newScroll(overlay.Body)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for orderIndex, category in ipairs(DisplayConfig.InventoryCategories) do
		local section = Instance.new("Frame")
		section.Name = category.Id
		section.BackgroundTransparency = 1
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Size = UDim2.new(1, 0, 0, 0)
		section.LayoutOrder = orderIndex
		section.Parent = scroll

		Theme.newLabel({
			Text = category.Name,
			Size = UDim2.new(1, 0, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = section,
		})

		local grid = Instance.new("Frame")
		grid.Name = "Variants"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.new(0, 0, 0, 36)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.Parent = section

		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.new(0, 160, 0, 140)
		gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
		gridLayout.Parent = grid

		for _, variant in ipairs(category.Variants) do
			buildVariantCard(grid, category.Id, variant)
		end
	end

	UIController.openOverlay("Inventory", overlay.Frame)
end

function InventoryController.init(ui)
	UIController = ui
end

return InventoryController
