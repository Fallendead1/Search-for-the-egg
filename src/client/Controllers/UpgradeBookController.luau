--!strict
-- UPGRADE BOOK: TAB on PC, on-screen Book button on mobile. Pages for
-- HAND / PITCHFORK / DYNAMITE / VACUUM / DRONE. Tool pages show a
-- purchase gate (Cash / One Round Robux / Permanent Robux) until the
-- server confirms ownership, then their upgrade-level tables. All
-- Cash-cost purchases go through Gameplay_RequestBuyRunUpgrade and are
-- never applied locally before the server confirms.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local UpgradeRow = require(script.Parent.Parent.UI.Components.UpgradeRow)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local MonetizationController = require(script.Parent.MonetizationController)
local SoundController = require(script.Parent.SoundController)

local UIController

local UpgradeBookController = {}

local PAGES = { "HAND", "PITCHFORK", "DYNAMITE", "VACUUM", "DRONE" }
local currentPage = "HAND"

local function currentLevel(toolId: string, statId: string): number
	local levels = PlayerState.Profile.ToolUpgradeLevels[toolId]
	return (levels and levels[statId]) or 0
end

local function requestBuyUpgrade(group: string, upgradeId: string)
	Remotes.fireServer("Gameplay_RequestBuyRunUpgrade", {
		Group = group,
		UpgradeId = upgradeId,
	})
	SoundController.play("Upgrade")
end

local function buildPurchaseGate(body: Instance, toolId: string, cashCost: number?, oneRoundKey: string, permanentKey: string?, description: string, identity: string?)
	local panel = Instance.new("Frame")
	panel.BackgroundTransparency = 1
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = body

	Theme.newLabel({
		Text = toolId:upper(),
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Font,
		Parent = panel,
	})
	Theme.newLabel({
		Text = description,
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 44),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.FontBody,
		Parent = panel,
	})
	if identity then
		Theme.newLabel({
			Text = identity,
			Size = UDim2.new(1, -40, 0, 30),
			Position = UDim2.new(0.5, 0, 0, 84),
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

	if cashCost and cashCost > 0 then
		local affordable = PlayerState.Run.InProgress and PlayerState.Run.Cash >= cashCost
		local cashButton = Theme.newButton({
			Text = ("BUY - $%.2f"):format(cashCost),
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
	local oneRoundButton = Theme.newButton({
		Text = oneRoundRobux and ("1 ROUND - %d R$"):format(oneRoundRobux) or "1 ROUND",
		Size = UDim2.new(0, 180, 1, 0),
		Color = Theme.Colors.ButtonSecondary,
		Parent = buttonRow,
	})
	local hasOneRoundProduct = MonetizationController.hasProduct(oneRoundKey)
	Theme.setButtonEnabled(oneRoundButton, hasOneRoundProduct)
	oneRoundButton.Activated:Connect(function()
		MonetizationController.promptProduct(oneRoundKey)
	end)

	if permanentKey then
		local permanentRobux = DisplayConfig[toolId] and DisplayConfig[toolId].PermanentRobux
		local permanentButton = Theme.newButton({
			Text = permanentRobux and ("PERMANENT - %d R$"):format(permanentRobux) or "PERMANENT",
			Size = UDim2.new(0, 180, 1, 0),
			Color = Theme.Colors.TextGold,
			Parent = buttonRow,
		})
		local hasPermanentPass = MonetizationController.hasGamePass(permanentKey)
		Theme.setButtonEnabled(permanentButton, hasPermanentPass)
		permanentButton.Activated:Connect(function()
			MonetizationController.promptGamePass(permanentKey)
		end)
	end
end

local function buildStatRows(scroll: Instance, toolId: string, stats: { { Id: string, Config: any, Format: ((number) -> string)? } })
	for i, stat in ipairs(stats) do
		local level = currentLevel(toolId, stat.Id)
		local nextCost = stat.Config.Levels[level + 1] and stat.Config.Levels[level + 1].Cost or math.huge
		local affordable = PlayerState.Run.InProgress and PlayerState.Run.Cash >= nextCost
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

	if not PlayerState.Profile.HoldUnlocked then
		local holdAffordable = PlayerState.Run.InProgress and PlayerState.Run.Cash >= DisplayConfig.Hand.Hold.Cost
		UpgradeRow.build({
			Parent = scroll,
			StatName = "HOLD",
			Description = DisplayConfig.Hand.Hold.Description,
			Base = 0,
			Levels = { { Level = 1, Value = 1, Cost = DisplayConfig.Hand.Hold.Cost } },
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
	if not PlayerState.Profile.OwnedTools[toolId] then
		buildPurchaseGate(body, toolId, DisplayConfig[toolId].CashCost, toolId .. "OneRound", toolId .. "Permanent", description, identity)
		return
	end

	local scroll = Overlay.newScroll(body)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	buildStatRows(scroll, toolId, stats)
end

local function buildVacuumPage(body: Instance)
	if not PlayerState.Profile.OwnedTools.Vacuum then
		buildPurchaseGate(body, "Vacuum", nil, "VacuumOneRound", nil, "Auto-collect feathers while heat allows.")
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

local pageFrames: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}

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

		if page == "HAND" then
			buildHandPage(pageFrame)
		elseif page == "PITCHFORK" then
			buildToolPage(pageFrame, "Pitchfork", DisplayConfig.Pitchfork.Description, DisplayConfig.Pitchfork.Identity, {
				{ Id = "Sweep", Config = DisplayConfig.Pitchfork.Sweep },
				{ Id = "Speed", Config = DisplayConfig.Pitchfork.Speed, Format = function(v) return ("%.2fs"):format(v) end },
				{ Id = "Dig", Config = DisplayConfig.Pitchfork.Dig, Format = function(v) return ("%.2fx"):format(v) end },
			})
		elseif page == "DYNAMITE" then
			buildToolPage(pageFrame, "Dynamite", DisplayConfig.Dynamite.Description, nil, {
				{ Id = "Power", Config = DisplayConfig.Dynamite.Power, Format = function(v) return ("%.2fx"):format(v) end },
				{ Id = "Speed", Config = DisplayConfig.Dynamite.Speed, Format = function(v) return ("%.1fs"):format(v) end },
				{ Id = "LuckyBlast", Config = DisplayConfig.Dynamite.LuckyBlast, Format = function(v) return ("%.0f%%"):format(v * 100) end },
			})
		elseif page == "VACUUM" then
			buildVacuumPage(pageFrame)
		elseif page == "DRONE" then
			buildToolPage(pageFrame, "Drone", DisplayConfig.Drone.Description, "Pile -> collect -> return to Chicken sell station -> sell -> repeat.", {
				{ Id = "Speed", Config = DisplayConfig.Drone.Speed, Format = function(v) return ("%.1fx"):format(v) end },
				{ Id = "Grasp", Config = DisplayConfig.Drone.Grasp },
				{ Id = "Capacity", Config = DisplayConfig.Drone.Capacity },
			})
		end

		local tabButton = Theme.newButton({
			Text = page,
			Size = UDim2.new(0, 130, 1, 0),
			Parent = tabRow,
		})
		tabButtons[page] = tabButton
		tabButton.Activated:Connect(function()
			selectPage(page, pagesHost)
		end)
	end

	selectPage(currentPage, pagesHost)

	UIController.openOverlay("Book", overlay.Frame, function()
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
