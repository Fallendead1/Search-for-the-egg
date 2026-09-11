--!strict
-- In-run HUD: currency/timer readouts, bag, tool hotbar, Egg objective
-- banner, and the run-completion presentation. All numbers are rendered
-- from PlayerState.Run / PlayerState.Profile, which are only ever written
-- by authoritative server pushes (Gameplay_RunState, Core_ProfileUpdated,
-- Gameplay_Completion).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local Format = require(script.Parent.Parent.Util.Format)
local InputController = require(script.Parent.InputController)
local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)
local EffectsController = require(script.Parent.EffectsController)

local UIController, UpgradeBookController

local RunHUDController = {}

local TOOL_SLOTS = { "Hand", "Pitchfork", "Dynamite", "Drone", "Vacuum" }

local cashLabel: TextLabel
local bagLabel: TextLabel
local gemsLabel: TextLabel
local tokensLabel: TextLabel
local timerLabel: TextLabel
local eggBanner: TextLabel
local goldenHarvestPanel: Frame
local hotbarButtons: { [string]: TextButton } = {}

local syncedElapsed = 0
local syncedAt = os.clock()
local timerRunning = false

local function resyncTimer()
	local run = PlayerState.Run
	if run.StartedAt then
		local serverNow = workspace:GetServerTimeNow()
		syncedElapsed = math.max(0, serverNow - run.StartedAt)
	else
		syncedElapsed = 0
	end
	syncedAt = os.clock()
	timerRunning = run.InProgress == true
end

local function buildLeftCluster(parent: Instance)
	local panel = Instance.new("Frame")
	panel.Name = "LeftCluster"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0, 16, 0, 16)
	panel.Size = UDim2.new(0, 220, 0, 170)
	panel.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = panel

	local cashPanel = Theme.newPanel("Cash", panel)
	cashPanel.Size = UDim2.new(1, 0, 0, 48)
	cashPanel.BackgroundColor3 = Theme.Colors.Cash
	cashLabel = Theme.newLabel({ Text = "$0.00", Size = UDim2.fromScale(1, 1), Parent = cashPanel })

	local bagPanel = Theme.newPanel("Bag", panel)
	bagPanel.Size = UDim2.new(1, 0, 0, 40)
	bagLabel = Theme.newLabel({ Text = "BAG 0/25", Size = UDim2.fromScale(1, 1), Parent = bagPanel })

	local promo = Theme.newPanel("DoubleGemsPromo", panel)
	promo.Size = UDim2.new(1, 0, 0, 56)
	promo.BackgroundColor3 = Theme.Colors.TextGold
	Theme.newLabel({ Text = "2x GEMS [PERMANENT]", Size = UDim2.fromScale(1, 1), Parent = promo })
end

local function buildRightCluster(parent: Instance)
	local panel = Instance.new("Frame")
	panel.Name = "RightCluster"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 16)
	panel.Size = UDim2.new(0, 200, 0, 170)
	panel.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = panel

	local tokensPanel = Theme.newPanel("AlienTokens", panel)
	tokensPanel.Size = UDim2.new(1, 0, 0, 40)
	tokensPanel.BackgroundColor3 = Theme.Colors.AlienTokens
	tokensLabel = Theme.newLabel({ Text = "0 TOKENS", Size = UDim2.fromScale(1, 1), Parent = tokensPanel })

	local gemsPanel = Theme.newPanel("Gems", panel)
	gemsPanel.Size = UDim2.new(1, 0, 0, 40)
	gemsPanel.BackgroundColor3 = Theme.Colors.Gems
	gemsLabel = Theme.newLabel({ Text = "0 GEMS", Size = UDim2.fromScale(1, 1), Parent = gemsPanel })

	local timerPanel = Theme.newPanel("Timer", panel)
	timerPanel.Size = UDim2.new(1, 0, 0, 48)
	timerLabel = Theme.newLabel({ Text = "00:00", Size = UDim2.fromScale(1, 1), Parent = timerPanel })

	local goldenPanel = Theme.newPanel("GoldenHarvest", panel)
	goldenPanel.Size = UDim2.new(1, 0, 0, 32)
	goldenPanel.BackgroundColor3 = Color3.fromRGB(255, 215, 64)
	goldenPanel.Visible = false
	Theme.newLabel({ Text = "GOLDEN HARVEST!", Size = UDim2.fromScale(1, 1), Parent = goldenPanel })
	goldenHarvestPanel = goldenPanel
end

local function buildHotbar(parent: Instance)
	local hotbar = Instance.new("Frame")
	hotbar.Name = "Hotbar"
	hotbar.BackgroundTransparency = 1
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -16)
	hotbar.Size = UDim2.new(0, 380, 0, 76)
	hotbar.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = hotbar

	for _, tool in ipairs(TOOL_SLOTS) do
		local button = Theme.newButton({
			Text = tool:sub(1, 1),
			Size = UDim2.new(0, 64, 0, 64),
			Parent = hotbar,
		})
		hotbarButtons[tool] = button
		button.Activated:Connect(function()
			InputController.selectTool(tool)
			if tool == "Vacuum" or tool == "Drone" then
				InputController.toggleAutoTool(tool)
			end
		end)
	end
end

local function buildBookButton(parent: Instance)
	if not UIController.IsMobile then
		return
	end
	local button = Theme.newButton({
		Text = "BOOK",
		Size = UDim2.new(0, 90, 0, 60),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -100),
		Parent = parent,
	})
	button.Activated:Connect(function()
		UpgradeBookController.toggle()
	end)
end

local function buildEggBanner(parent: Instance)
	eggBanner = Theme.newLabel({
		Text = "",
		Size = UDim2.new(0, 500, 0, 44),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		TextColor = Theme.Colors.TextGold,
		Font = Theme.Font,
		Parent = parent,
	})
	eggBanner.Visible = false
end

local function refreshHotbarStates()
	local current = InputController.getCurrentTool()
	for tool, button in pairs(hotbarButtons) do
		local owned = PlayerState.isToolOwned(tool)
		Theme.setButtonEnabled(button, true)
		if not owned then
			button.BackgroundColor3 = Theme.Colors.Locked
		elseif (tool == "Vacuum" or tool == "Drone") and InputController.isAutoToolActive(tool) then
			button.BackgroundColor3 = Theme.Colors.ButtonDanger
		elseif tool == current then
			button.BackgroundColor3 = Theme.Colors.ButtonSecondary
		else
			button.BackgroundColor3 = Theme.Colors.ButtonPrimary
		end
	end
end

local function refreshHud()
	local run = PlayerState.Run
	local profile = PlayerState.Profile

	if cashLabel then
		cashLabel.Text = Format.cash(run.CashCents or 0)
	end
	if bagLabel then
		bagLabel.Text = ("BAG %d/%d"):format(run.BagCount or 0, run.BagCapacity or DisplayConfig.BaseBagCapacity)
	end
	if gemsLabel then
		gemsLabel.Text = Format.compactNumber(profile.Gems or 0) .. " GEMS"
	end
	if tokensLabel then
		tokensLabel.Text = Format.compactNumber(profile.AlienTokens or 0) .. " TOKENS"
	end

	if eggBanner then
		local localUserId = Players.LocalPlayer.UserId
		local carrierId = run.EggCarrierUserId
		if carrierId == localUserId then
			eggBanner.Text = "BRING THE EGG TO THE FARMER!"
			eggBanner.Visible = true
		elseif carrierId then
			eggBanner.Text = "A TEAMMATE HAS THE EGG!"
			eggBanner.Visible = true
		else
			eggBanner.Visible = false
		end
	end

	refreshHotbarStates()
	resyncTimer()
end

local function showCompletionOverlay(payload: any)
	timerRunning = false

	local frame = Instance.new("Frame")
	frame.Name = "CompletionOverlay"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.5, 0, 0.55, 0)
	frame.BackgroundColor3 = Theme.Colors.Background
	Theme.applyOutlineCorner(frame, 4)

	Theme.newLabel({
		Text = "RUN COMPLETE",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0, 16),
		Parent = frame,
	})

	local statsList = Instance.new("Frame")
	statsList.BackgroundTransparency = 1
	statsList.Position = UDim2.new(0.5, 0, 0, 88)
	statsList.AnchorPoint = Vector2.new(0.5, 0)
	statsList.Size = UDim2.new(1, -60, 0, 180)
	statsList.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = statsList

	local function row(text: string)
		Theme.newLabel({
			Text = text,
			Size = UDim2.new(1, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = statsList,
		})
	end

	row(("Time: %s"):format(Format.time(payload.Time or 0)))
	if payload.NewRecord then
		row("NEW RECORD!")
	end
	row("+1 WIN")
	row(("Gems Awarded: %d"):format(payload.Gems or 0))
	row(("Alien Tokens Awarded: %d"):format(payload.AlienTokens or 0))

	local returnButton = Theme.newButton({
		Text = "RETURN TO LOBBY",
		Size = UDim2.new(0, 220, 0, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Color = Theme.Colors.ButtonSecondary,
		Parent = frame,
	})
	returnButton.Activated:Connect(function()
		UIController.closeOverlay()
		UIController.showLobby()
		CameraController.restore()
	end)

	SoundController.play("Completion")
	CameraController.playCompletionSequence()
	UIController.openOverlay("Completion", frame)
end

function RunHUDController.build(root: Frame)
	buildLeftCluster(root)
	buildRightCluster(root)
	buildHotbar(root)
	buildBookButton(root)
	buildEggBanner(root)
	refreshHud()

	RunService.Heartbeat:Connect(function()
		if not timerLabel then
			return
		end
		if timerRunning then
			local elapsed = syncedElapsed + (os.clock() - syncedAt)
			timerLabel.Text = Format.time(elapsed)
		end
	end)
end

function RunHUDController.init(dependencies: { UIController: any, UpgradeBookController: any })
	UIController = dependencies.UIController
	UpgradeBookController = dependencies.UpgradeBookController

	PlayerState.RunChanged:Connect(refreshHud)
	PlayerState.ProfileChanged:Connect(refreshHud)
	InputController.ToolChanged:Connect(refreshHotbarStates)
	EffectsController.GoldenHarvestChanged:Connect(function(active: boolean)
		if goldenHarvestPanel then
			goldenHarvestPanel.Visible = active
		end
	end)
	InputController.ToolLocked:Connect(function(tool: string)
		UpgradeBookController.openPage(tool:upper())
	end)

	Remotes.onClientEvent("Gameplay_RunState", function(state: any)
		if type(state) ~= "table" then
			return
		end
		PlayerState.applyRunState(state)
		if state.InProgress then
			UIController.showHud()
		end
	end)

	Remotes.onClientEvent("Gameplay_Completion", function(payload: any)
		if type(payload) ~= "table" then
			payload = {}
		end
		showCompletionOverlay(payload)
	end)
end

return RunHUDController
