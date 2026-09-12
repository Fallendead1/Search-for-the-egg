--!strict
-- UPGRADE BOOK: TAB on PC, on-screen Book button on mobile. Pages for
-- HAND / PITCHFORK / DYNAMITE / VACUUM / DRONE / GRABBER (Feather Grabber) /
-- TORNADO (Feather Tornado Launcher) / BOT (Feather Packing Bot). Tool pages
-- show a purchase gate (Cash or Gems / One Round Robux / Permanent Robux)
-- until the server confirms ownership, then either upgrade-level tables
-- (Pitchfork/Dynamite/Vacuum/Drone) or a fixed-stat confirmation (the three
-- new equipment items, which have no upgrade tracks). All Cash-cost
-- purchases go through Gameplay_RequestBuyRunUpgrade and are never applied
-- locally before the server confirms.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local ItemPreview = require(script.Parent.Parent.UI.Components.ItemPreview)
local UpgradeRow = require(script.Parent.Parent.UI.Components.UpgradeRow)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local Format = require(script.Parent.Parent.Util.Format)
local MonetizationController = require(script.Parent.MonetizationController)
local SoundController = require(script.Parent.SoundController)

local UIController

local UpgradeBookController = {}

local PAGES = { "HAND", "PITCHFORK", "DYNAMITE", "VACUUM", "DRONE", "GRABBER", "TORNADO", "BOT" }
local currentPage = "HAND"

-- Maps the UpgradeId used on the wire (and in DisplayConfig's per-stat
-- tables) to the level field RunPlayerStateService actually stores on
-- PlayerState.Run.Tools[toolId] -- mirrors RunUpgradeService's server-side
-- TOOL_UPGRADE_ID_TO_TRACK exactly.
local TOOL_STAT_TO_LEVEL_FIELD: { [string]: { [string]: string } } = {
	Pitchfork = { Sweep = "AmountLevel", Speed = "SpeedLevel", Dig = "ExtraLevel" },
	Dynamite = { Power = "AmountLevel", Speed = "SpeedLevel", LuckyBlast = "ExtraLevel" },
	Vacuum = { Power = "AmountLevel", Cooling = "SpeedLevel", Runtime = "ExtraLevel" },
	Drone = { Speed = "SpeedLevel", Grasp = "AmountLevel", Capacity = "ExtraLevel" },
}

local function currentLevel(toolId: string, statId: string): number
	if toolId == "Hand" then
		if statId == "Speed" then
			return PlayerState.Run.HandSpeedLevel or 0
		elseif statId == "Grasp" then
			return PlayerState.Run.HandGraspLevel or 0
		end
		return 0
	end

	local toolState = PlayerState.Run.Tools and PlayerState.Run.Tools[toolId]
	local field = TOOL_STAT_TO_LEVEL_FIELD[toolId] and TOOL_STAT_TO_LEVEL_FIELD[toolId][statId]
	if not toolState or not field then
		return 0
	end
	return toolState[field] or 0
end

local function requestBuyUpgrade(group: string, upgradeId: string)
	Remotes.fireServer("Gameplay_RequestBuyRunUpgrade", {
		Group = group,
		UpgradeId = upgradeId,
	})
	SoundController.play("Upgrade")
end

local function buildPurchaseGate(body: Instance, toolId: string, cashCostCents: number?, oneRoundKey: string, permanentKey: string?, description: string, identity: string?)
	local panel = Instance.new("Frame")
	panel.BackgroundTransparency = 1
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = body

	-- "Large 3D item display" (Section 5/9) -- a live-rotating clone of the
	-- real SFTE_Assets model. Falls back to nothing (title/description just
	-- use the full width) if that tool has no template yet.
	local preview = ItemPreview.new(panel, toolId, UDim2.new(0, 90, 0, 90), UDim2.new(0, 0, 0, 0))
	local textIndent = preview and 100 or 0
	local textWidth = preview and -100 or 0

	Theme.newLabel({
		Text = toolId:upper(),
		Size = UDim2.new(1, textWidth - 20, 0, 30),
		Position = UDim2.new(0, textIndent, 0, 0),
		TextXAlignment = preview and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		Font = Theme.Font,
		Parent = panel,
	})
	Theme.newLabel({
		Text = description,
		Size = UDim2.new(1, textWidth - 20, 0, 60),
		Position = UDim2.new(0, textIndent, 0, 32),
		TextXAlignment = preview and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		Font = Theme.FontBody,
		Parent = panel,
	})
	if identity then
		Theme.newLabel({
			Text = identity,
			Size = UDim2.new(1, -20, 0, 26),
			Position = UDim2.new(0.5, 0, 0, 94),
			AnchorPoint = Vector2.new(0.5, 0),
			Font = Theme.FontBody,
			TextColor = Theme.Colors.TextDark,
			Parent = panel,
		})
	end

	local buttonRow = Instance.new("Frame")
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.new(1, -40, 0, 60)
	buttonRow.Position = UDim2.new(0.5, 0, 0, 140)
	buttonRow.AnchorPoint = Vector2.new(0.5, 0)
	buttonRow.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = buttonRow

	if cashCostCents and cashCostCents > 0 then
		local affordable = PlayerState.Run.InProgress and PlayerState.Run.CashCents >= cashCostCents
		local cashButton = Theme.newButton({
			Text = Format.cash(cashCostCents),
			Size = UDim2.new(0, 180, 1, 0),
			Color = affordable and Theme.Colors.ButtonPrimary or Theme.Colors.ButtonDisabled,
			Parent = buttonRow,
		})
		Theme.setButtonEnabled(cashButton, affordable)
		cashButton.Activated:Connect(function()
			requestBuyUpgrade(toolId, "Unlock")
		end)
	end

	local oneRoundRobux = DisplayConfig[toolId] and DisplayConfig[toolId].OneRoundRobux
	local hasOneRoundProduct = MonetizationController.hasProduct(oneRoundKey)
	local oneRoundButton = Theme.newButton({
		-- Id = 0 in MonetizationConfig means this product isn't configured in
		-- Roblox yet -- show COMING SOON instead of a fake price so players
		-- never see a purchase option that can't actually complete.
		Text = hasOneRoundProduct and oneRoundRobux and ("1 ROUND - %d R$"):format(oneRoundRobux)
			or (oneRoundRobux and "COMING SOON" or "1 ROUND"),
		Size = UDim2.new(0, 180, 1, 0),
		Color = Theme.Colors.ButtonSecondary,
		Parent = buttonRow,
	})
	Theme.setButtonEnabled(oneRoundButton, hasOneRoundProduct)
	oneRoundButton.Activated:Connect(function()
		MonetizationController.promptProduct(oneRoundKey)
	end)

	-- Drone/Packing Bot's alternate one-round buy: Gems instead of Robux (see
	-- ToolService.BuyDroneWithGems / BuyPackingBotWithGems).
	local GEMS_BUY_ACTION: { [string]: string } = { Drone = "BuyDroneGems", PackingBot = "BuyPackingBotGems" }
	if GEMS_BUY_ACTION[toolId] then
		local gemsCost = DisplayConfig[toolId].GemsCost
		local gemsAffordable = PlayerState.Run.InProgress and PlayerState.Profile.Gems >= gemsCost
		local gemsButton = Theme.newButton({
			Text = ("1 ROUND - %d GEMS"):format(gemsCost),
			Size = UDim2.new(0, 180, 1, 0),
			Color = gemsAffordable and Theme.Colors.Gems or Theme.Colors.ButtonDisabled,
			Parent = buttonRow,
		})
		Theme.setButtonEnabled(gemsButton, gemsAffordable)
		gemsButton.Activated:Connect(function()
			Remotes.fireServer("Gameplay_RequestToolAction", { Tool = toolId, Action = GEMS_BUY_ACTION[toolId] })
			SoundController.play("Upgrade")
		end)
	end

	if permanentKey then
		-- Permanent tool unlocks are Game Passes (see MonetizationConfig.GamePasses),
		-- resolved server-side via MonetizationService.OwnsEntitlement.
		local permanentRobux = DisplayConfig[toolId] and DisplayConfig[toolId].PermanentRobux
		local hasPermanentPass = MonetizationController.hasGamePass(permanentKey)
		local permanentButton = Theme.newButton({
			Text = hasPermanentPass and permanentRobux and ("PERMANENT - %d R$"):format(permanentRobux)
				or (permanentRobux and "COMING SOON" or "PERMANENT"),
			Size = UDim2.new(0, 180, 1, 0),
			Color = Theme.Colors.TextGold,
			Parent = buttonRow,
		})
		Theme.setButtonEnabled(permanentButton, hasPermanentPass)
		permanentButton.Activated:Connect(function()
			MonetizationController.promptGamePass(permanentKey)
		end)
	end
end

local function buildStatRows(scroll: Instance, toolId: string, stats: { { Id: string, Config: any, Format: ((number) -> string)? } })
	for i, stat in ipairs(stats) do
		local level = currentLevel(toolId, stat.Id)
		local nextCostCents = stat.Config.Levels[level + 1] and stat.Config.Levels[level + 1].CostCents or math.huge
		local affordable = PlayerState.Run.InProgress and PlayerState.Run.CashCents >= nextCostCents
		UpgradeRow.build({
			Parent = scroll,
			StatName = stat.Id:upper(),
			Base = stat.Config.Base,
			Levels = stat.Config.Levels,
			CurrentLevel = level,
			Affordable = affordable,
			ValueFormatter = stat.Format,
			LayoutOrder = i,
			OnBuy = function()
				requestBuyUpgrade(toolId, stat.Id)
			end,
		})
	end
end

local function buildHandPage(body: Instance)
	local scroll = Overlay.newScroll(body)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	if not PlayerState.Run.HandHoldUnlocked then
		local holdAffordable = PlayerState.Run.InProgress and PlayerState.Run.CashCents >= DisplayConfig.Hand.Hold.CostCents
		UpgradeRow.build({
			Parent = scroll,
			StatName = "HOLD",
			Description = DisplayConfig.Hand.Hold.Description,
			Base = 0,
			Levels = { { Level = 1, Value = 1, CostCents = DisplayConfig.Hand.Hold.CostCents } },
			CurrentLevel = 0,
			Affordable = holdAffordable,
			ValueFormatter = function()
				return "CLICK -> HOLD"
			end,
			LayoutOrder = 0,
			OnBuy = function()
				requestBuyUpgrade("Hand", "Hold")
			end,
		})
	end

	buildStatRows(scroll, "Hand", {
		{ Id = "Speed", Config = DisplayConfig.Hand.Speed, Format = function(v) return ("%.2fs"):format(v) end },
		{ Id = "Grasp", Config = DisplayConfig.Hand.Grasp, Format = function(v) return tostring(v) .. " Feather" end },
	})
end

local function buildToolPage(body: Instance, toolId: string, description: string, identity: string?, stats: { { Id: string, Config: any, Format: ((number) -> string)? } })
	if not PlayerState.isToolOwned(toolId) then
		buildPurchaseGate(body, toolId, DisplayConfig[toolId].CashCostCents, toolId .. "Round", toolId .. "Permanent", description, identity)
		return
	end

	local scroll = Overlay.newScroll(body)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	if #stats == 0 then
		-- Fixed-stat equipment (no upgrade tracks): confirm ownership instead
		-- of showing an empty scroll.
		Theme.newLabel({
			Text = "OWNED -- " .. description,
			Size = UDim2.new(1, -20, 0, 60),
			Font = Theme.FontBody,
			Parent = scroll,
		})
		return
	end

	buildStatRows(scroll, toolId, stats)
end

local function buildVacuumPage(body: Instance)
	if not PlayerState.isToolOwned("Vacuum") then
		buildPurchaseGate(body, "Vacuum", nil, "VacuumRound", "VacuumPermanent", "Auto-collect feathers while heat allows.")
		return
	end

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = body

	local heatBarBg = Theme.newPanel("HeatBarBg", container)
	heatBarBg.Size = UDim2.new(1, -40, 0, 30)
	heatBarBg.Position = UDim2.new(0.5, 0, 0, 8)
	heatBarBg.AnchorPoint = Vector2.new(0.5, 0)

	local heatFill = Instance.new("Frame")
	heatFill.Name = "Fill"
	heatFill.BackgroundColor3 = Theme.Colors.ButtonDanger
	heatFill.BorderSizePixel = 0
	heatFill.Size = UDim2.new(math.clamp(PlayerState.Run.VacuumHeat, 0, 1), 0, 1, 0)
	heatFill.Parent = heatBarBg
	Theme.applyOutlineCorner(heatFill, 0)

	local disconnectHeat = PlayerState.RunChanged:Connect(function(run)
		if heatFill.Parent then
			heatFill.Size = UDim2.new(math.clamp(run.VacuumHeat or 0, 0, 1), 0, 1, 0)
		end
	end)
	container.Destroying:Connect(disconnectHeat)

	local scroll = Overlay.newScroll(container)
	scroll.Position = UDim2.new(0, 0, 0, 46)
	scroll.Size = UDim2.new(1, 0, 1, -46)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	buildStatRows(scroll, "Vacuum", {
		{ Id = "Power", Config = DisplayConfig.Vacuum.Power, Format = function(v) return ("%d/sec"):format(v) end },
		{ Id = "Cooling", Config = DisplayConfig.Vacuum.Cooling, Format = function(v) return ("%ds"):format(v) end },
		{ Id = "Runtime", Config = DisplayConfig.Vacuum.Runtime, Format = function(v) return ("%ds"):format(v) end },
	})
end

-- Single dispatch used both for the initial build and for every refresh, so
-- a rebuilt page is always identical to a freshly-opened one.
local function buildPageInto(page: string, frame: Instance)
	if page == "HAND" then
		buildHandPage(frame)
	elseif page == "PITCHFORK" then
		buildToolPage(frame, "Pitchfork", DisplayConfig.Pitchfork.Description, DisplayConfig.Pitchfork.Identity, {
			{ Id = "Sweep", Config = DisplayConfig.Pitchfork.Sweep },
			{ Id = "Speed", Config = DisplayConfig.Pitchfork.Speed, Format = function(v) return ("%.2fs"):format(v) end },
			{ Id = "Dig", Config = DisplayConfig.Pitchfork.Dig, Format = function(v) return ("%.2fx"):format(v) end },
		})
	elseif page == "DYNAMITE" then
		buildToolPage(frame, "Dynamite", DisplayConfig.Dynamite.Description, nil, {
			{ Id = "Power", Config = DisplayConfig.Dynamite.Power, Format = function(v) return ("%.2fx"):format(v) end },
			{ Id = "Speed", Config = DisplayConfig.Dynamite.Speed, Format = function(v) return ("%.1fs"):format(v) end },
			{ Id = "LuckyBlast", Config = DisplayConfig.Dynamite.LuckyBlast, Format = function(v) return ("%.0f%%"):format(v * 100) end },
		})
	elseif page == "VACUUM" then
		buildVacuumPage(frame)
	elseif page == "DRONE" then
		buildToolPage(frame, "Drone", DisplayConfig.Drone.Description, "Pile -> collect -> return to Chicken sell station -> sell -> repeat.", {
			{ Id = "Speed", Config = DisplayConfig.Drone.Speed, Format = function(v) return ("%.1fx"):format(v) end },
			{ Id = "Grasp", Config = DisplayConfig.Drone.Grasp },
			{ Id = "Capacity", Config = DisplayConfig.Drone.Capacity },
		})
	elseif page == "GRABBER" then
		buildToolPage(frame, "FeatherGrabber", DisplayConfig.FeatherGrabber.Description,
			("Grabs %d feathers at once, about every %.1fs."):format(DisplayConfig.FeatherGrabber.GrabAmount, DisplayConfig.FeatherGrabber.ActionSeconds), {})
	elseif page == "TORNADO" then
		buildToolPage(frame, "TornadoLauncher", DisplayConfig.TornadoLauncher.Description,
			("Pulls up to %d feathers at once. %ds cooldown."):format(DisplayConfig.TornadoLauncher.MaxCollectAmount, DisplayConfig.TornadoLauncher.CooldownSeconds), {})
	elseif page == "BOT" then
		buildToolPage(frame, "PackingBot", DisplayConfig.PackingBot.Description,
			("Carries up to %d feathers per trip, then sells automatically."):format(DisplayConfig.PackingBot.Capacity), {})
	end
end

local pageFrames: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}

-- Rebuilds every page's content in place from current PlayerState, so
-- whichever page is visible (and every other, ready for its tab) always
-- reflects the latest authoritative server state -- never a client-side
-- optimistic update. Called on open and again on every Gameplay_RunState/
-- Core_ProfileUpdated while the Book stays open.
local function refreshAllPages()
	for page, frame in pairs(pageFrames) do
		for _, child in ipairs(frame:GetChildren()) do
			child:Destroy()
		end
		buildPageInto(page, frame)
	end
end

local function selectPage(page: string, body: Instance)
	currentPage = page
	for id, frame in pairs(pageFrames) do
		frame.Visible = id == page
	end
	for id, button in pairs(tabButtons) do
		button.BackgroundColor3 = id == page and Theme.Colors.ButtonPrimary or Theme.Colors.PanelFill
	end
end

function UpgradeBookController.open()
	if not PlayerState.Run.InProgress then
		return
	end

	local overlay = Overlay.new("UPGRADE BOOK")
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

	pageFrames = {}
	tabButtons = {}

	for _, page in ipairs(PAGES) do
		local pageFrame = Instance.new("Frame")
		pageFrame.Name = page
		pageFrame.BackgroundTransparency = 1
		pageFrame.Size = UDim2.fromScale(1, 1)
		pageFrame.Visible = false
		pageFrame.Parent = pagesHost
		pageFrames[page] = pageFrame

		buildPageInto(page, pageFrame)

		local tabButton = Theme.newButton({
			Text = page,
			-- Narrower than the original 130px now that there are 8 tabs
			-- instead of 5 -- keeps the whole row from overflowing the book.
			Size = UDim2.new(0, 95, 1, 0),
			Parent = tabRow,
		})
		tabButtons[page] = tabButton
		tabButton.Activated:Connect(function()
			selectPage(page, pagesHost)
		end)
	end

	selectPage(currentPage, pagesHost)

	-- Gameplay_RunState (Cash/HandSpeedLevel/HandGraspLevel/HandHoldUnlocked/
	-- Tools) and Core_ProfileUpdated (Gems, for Drone's Gems buy option) are
	-- the only two authoritative sources any row here reads from -- refresh
	-- on both so the open Book never shows a stale level/cost/affordability
	-- after a purchase confirms server-side.
	local runConnection = PlayerState.RunChanged:Connect(refreshAllPages)
	local profileConnection = PlayerState.ProfileChanged:Connect(refreshAllPages)

	UIController.openOverlay("Book", overlay.Frame, function()
		runConnection()
		profileConnection()
		pageFrames = {}
		tabButtons = {}
	end)
end

function UpgradeBookController.openPage(page: string)
	currentPage = page
	UpgradeBookController.open()
end

function UpgradeBookController.toggle()
	if UIController.isOverlayOpen("Book") then
		UIController.closeOverlay()
	else
		UpgradeBookController.open()
	end
end

function UpgradeBookController.init(ui)
	UIController = ui

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			UpgradeBookController.toggle()
		end
	end)
end

return UpgradeBookController
