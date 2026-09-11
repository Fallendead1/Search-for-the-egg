--!strict
-- CLASSES overlay: odds list, spin, roll reveal animation, two class
-- slots, and Auto Roll. Every roll result comes from the server -- this
-- controller only requests rolls and renders whatever comes back.

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)
local MonetizationController = require(script.Parent.MonetizationController)

local UIController

local ClassController = {}

local AUTO_ROLL_STOP_TARGETS = { "Forkmaster", "Demolitionist", "Prospector", "DroneSpecialist", "UltimateFarmer" }

local autoRollGeneration = 0
local autoRollActive = false
local pendingRollResolve: ((any) -> ())? = nil
local selectedStopTarget = "UltimateFarmer"

local spinButton: TextButton? = nil
local autoRollButton: TextButton? = nil
local resultLabel: TextLabel? = nil

local function classById(id: string)
	for _, class in ipairs(DisplayConfig.Classes) do
		if class.Id == id then
			return class
		end
	end
	return nil
end

local function awaitRollResult(timeoutSeconds: number): any?
	local resultBox = { value = nil, done = false }
	pendingRollResolve = function(payload)
		resultBox.value = payload
		resultBox.done = true
	end

	local elapsed = 0
	while not resultBox.done and elapsed < timeoutSeconds do
		task.wait(0.1)
		elapsed += 0.1
	end
	pendingRollResolve = nil
	return resultBox.value
end

local function setRolling(isRolling: boolean)
	if spinButton then
		Theme.setButtonEnabled(spinButton, not isRolling and PlayerState.Profile.Gems >= DisplayConfig.ClassRollCostGems)
	end
end

local function showResult(payload: any)
	if not resultLabel then
		return
	end
	if type(payload) ~= "table" or not payload.Success then
		resultLabel.Text = payload and payload.Message or "Roll failed."
		resultLabel.TextColor3 = Theme.Colors.ButtonDanger
		return
	end
	local class = classById(payload.ClassId)
	resultLabel.Text = "You rolled: " .. (class and class.Name or tostring(payload.ClassId))
	resultLabel.TextColor3 = Theme.Colors.TextGold
	SoundController.play("ClassRoll")
	CameraController.playClassRollFraming()
end

local function requestSingleRoll(): any?
	Remotes.fireServer("Core_RequestClassRoll")
	return awaitRollResult(10)
end

-- Server remains authoritative (ClassService.EquipClass re-validates
-- ownership/slot-unlock/duplicate-class); this only sends the request and
-- lets the next Core_ProfileUpdated (via PlayerState.ProfileChanged, see
-- ClassController.open) refresh what's actually equipped.
local function requestEquip(slotIndex: number, classId: string)
	Remotes.fireServer("Core_RequestEquipClass", slotIndex, classId)
	SoundController.play("ButtonClick")
end

local function stopAutoRoll()
	autoRollActive = false
	autoRollGeneration += 1
	if autoRollButton then
		autoRollButton.Text = "AUTO ROLL: OFF"
		autoRollButton.BackgroundColor3 = Theme.Colors.ButtonSecondary
	end
end

local function runAutoRollLoop(generation: number)
	while autoRollActive and generation == autoRollGeneration do
		if PlayerState.Profile.Gems < DisplayConfig.ClassRollCostGems then
			stopAutoRoll()
			break
		end

		setRolling(true)
		local result = requestSingleRoll()
		setRolling(false)

		if generation ~= autoRollGeneration then
			break
		end

		if type(result) ~= "table" or not result.Success then
			stopAutoRoll()
			break
		end

		showResult(result)

		if result.ClassId == selectedStopTarget then
			stopAutoRoll()
			break
		end

		local delay = MonetizationController.ownsGamePass("FastRolls") and 0.5 or 1.5
		task.wait(delay)
	end
end

-- Builds the SLOT 1 / SLOT 2 equip buttons for one owned class row. Slot 2
-- stays locked (no button, just a label) until SecondSlotUnlocked; either
-- button is disabled if that class is already equipped in the OTHER slot,
-- preventing the same class from stacking in both slots at once (the
-- server enforces this too -- see ClassService.EquipClass's DuplicateClass
-- check -- this is just matching UX).
local function buildEquipRow(parent: Instance, classId: string)
	local row = Instance.new("Frame")
	row.Name = "EquipRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -16, 0, 28)
	row.Position = UDim2.new(0, 8, 0, 64)
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local equippedSlot1 = PlayerState.Profile.EquippedClass == classId
	local equippedSlot2 = PlayerState.Profile.SecondSlotUnlocked and PlayerState.Profile.SecondClass == classId

	local slot1Button = Theme.newButton({
		Text = equippedSlot1 and "SLOT 1: EQUIPPED" or "EQUIP SLOT 1",
		Size = UDim2.new(0, 160, 1, 0),
		Color = equippedSlot1 and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
		Parent = row,
	})
	Theme.setButtonEnabled(slot1Button, not equippedSlot1 and not equippedSlot2)
	slot1Button.Activated:Connect(function()
		requestEquip(1, classId)
	end)

	if PlayerState.Profile.SecondSlotUnlocked then
		local slot2Button = Theme.newButton({
			Text = equippedSlot2 and "SLOT 2: EQUIPPED" or "EQUIP SLOT 2",
			Size = UDim2.new(0, 160, 1, 0),
			Color = equippedSlot2 and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
			Parent = row,
		})
		Theme.setButtonEnabled(slot2Button, not equippedSlot2 and not equippedSlot1)
		slot2Button.Activated:Connect(function()
			requestEquip(2, classId)
		end)
	else
		Theme.newLabel({
			Text = "SLOT 2 LOCKED",
			Size = UDim2.new(0, 160, 1, 0),
			TextColor = Theme.Colors.Locked,
			Font = Theme.FontBody,
			Parent = row,
		})
	end
end

local function buildOddsList(parent: Instance)
	local scroll = Overlay.newScroll(parent)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, class in ipairs(DisplayConfig.Classes) do
		local owned = PlayerState.Profile.OwnedClasses[class.Id] == true

		local row = Theme.newPanel(class.Id, scroll)
		row.Size = UDim2.new(1, 0, 0, owned and 96 or 64)
		row.LayoutOrder = i

		Theme.newLabel({
			Text = ("%s  (%s%%)"):format(class.Name, tostring(class.Odds)),
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.new(0, 8, 0, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.newLabel({
			Text = class.Description,
			Size = UDim2.new(1, -16, 0, 32),
			Position = UDim2.new(0, 8, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.FontBody,
			Parent = row,
		})

		if owned then
			buildEquipRow(row, class.Id)
		end
	end
end

local function buildSlots(parent: Instance)
	local slot1 = Theme.newPanel("Slot1", parent)
	slot1.Size = UDim2.new(0.48, 0, 0, 90)
	slot1.Position = UDim2.new(0, 0, 0, 0)

	local equippedClass = classById(PlayerState.Profile.EquippedClass or "Starter")
	Theme.newLabel({
		Text = "SLOT 1\n" .. (equippedClass and equippedClass.Name or "Starter"),
		Size = UDim2.fromScale(1, 1),
		Parent = slot1,
	})

	local slot2 = Theme.newPanel("Slot2", parent)
	slot2.Size = UDim2.new(0.48, 0, 0, 90)
	slot2.Position = UDim2.new(0.52, 0, 0, 0)

	if PlayerState.Profile.SecondSlotUnlocked then
		local secondClass = PlayerState.Profile.SecondClass and classById(PlayerState.Profile.SecondClass)
		Theme.newLabel({
			Text = "SLOT 2\n" .. (secondClass and secondClass.Name or "Empty"),
			Size = UDim2.fromScale(1, 1),
			Parent = slot2,
		})
	else
		Theme.newLabel({
			Text = "SLOT 2\nLOCKED",
			Size = UDim2.new(1, 0, 1, -40),
			TextColor = Theme.Colors.Locked,
			Parent = slot2,
		})
		local unlockButton = Theme.newButton({
			Text = ("+1 SLOT - %d R$"):format(DisplayConfig.ClassMonetization.ExtraSlotRobux),
			Size = UDim2.new(1, -12, 0, 32),
			Position = UDim2.new(0.5, 0, 1, -6),
			AnchorPoint = Vector2.new(0.5, 1),
			Parent = slot2,
		})
		unlockButton.Activated:Connect(function()
			MonetizationController.promptGamePass("ExtraClassSlot")
		end)
	end
end

-- Rebuilds the slots + owned-class/equip list in place. Called on open and
-- again whenever Core_ProfileUpdated changes PlayerState.Profile (equip
-- confirmations, new rolls, Slot 2 unlock) while the overlay is open.
local function refreshClassesPanels(slotsFrame: Instance, oddsFrame: Instance)
	for _, child in ipairs(slotsFrame:GetChildren()) do
		child:Destroy()
	end
	buildSlots(slotsFrame)

	for _, child in ipairs(oddsFrame:GetChildren()) do
		child:Destroy()
	end
	buildOddsList(oddsFrame)
end

local function buildMonetizationRow(parent: Instance)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 48)
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local fastRolls = Theme.newButton({
		Text = ("FAST ROLLS - %d R$"):format(DisplayConfig.ClassMonetization.FastRollsRobux),
		Size = UDim2.new(0, 180, 1, 0),
		Parent = row,
	})
	fastRolls.Activated:Connect(function()
		MonetizationController.promptGamePass("FastRolls")
	end)

	local doubleLuck = Theme.newButton({
		Text = ("2x LUCK - %d R$"):format(DisplayConfig.ClassMonetization.DoubleLuckRobux),
		Size = UDim2.new(0, 180, 1, 0),
		Parent = row,
	})
	doubleLuck.Activated:Connect(function()
		MonetizationController.promptGamePass("ClassLuck2x")
	end)
end

function ClassController.open()
	stopAutoRoll()

	local overlay = Overlay.new("CLASSES")
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	local slotsFrame = Instance.new("Frame")
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.Size = UDim2.new(1, -20, 0, 90)
	slotsFrame.Position = UDim2.new(0.5, 0, 0, 10)
	slotsFrame.AnchorPoint = Vector2.new(0.5, 0)
	slotsFrame.Parent = overlay.Body
	buildSlots(slotsFrame)

	local oddsFrame = Instance.new("Frame")
	oddsFrame.BackgroundTransparency = 1
	oddsFrame.Size = UDim2.new(1, -20, 1, -260)
	oddsFrame.Position = UDim2.new(0.5, 0, 0, 110)
	oddsFrame.AnchorPoint = Vector2.new(0.5, 0)
	oddsFrame.Parent = overlay.Body
	buildOddsList(oddsFrame)

	resultLabel = Theme.newLabel({
		Text = "",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0.5, 0, 1, -128),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = overlay.Body,
	})

	local monetizationRow = Instance.new("Frame")
	monetizationRow.BackgroundTransparency = 1
	monetizationRow.Size = UDim2.new(1, -20, 0, 48)
	monetizationRow.Position = UDim2.new(0.5, 0, 1, -92)
	monetizationRow.AnchorPoint = Vector2.new(0.5, 1)
	monetizationRow.Parent = overlay.Body
	buildMonetizationRow(monetizationRow)

	local controlsRow = Instance.new("Frame")
	controlsRow.BackgroundTransparency = 1
	controlsRow.Size = UDim2.new(1, -20, 0, 56)
	controlsRow.Position = UDim2.new(0.5, 0, 1, -8)
	controlsRow.AnchorPoint = Vector2.new(0.5, 1)
	controlsRow.Parent = overlay.Body

	spinButton = Theme.newButton({
		Text = ("SPIN - %d GEMS"):format(DisplayConfig.ClassRollCostGems),
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Colors.ButtonPrimary,
		Parent = controlsRow,
	})
	spinButton.Activated:Connect(function()
		if autoRollActive then
			return
		end
		setRolling(true)
		task.spawn(function()
			local result = requestSingleRoll()
			showResult(result)
			setRolling(false)
		end)
	end)

	local stopTargetButton = Theme.newButton({
		Text = "STOP AT: " .. (classById(selectedStopTarget) and classById(selectedStopTarget).Name or selectedStopTarget),
		Size = UDim2.new(0.35, 0, 1, 0),
		Position = UDim2.new(0.325, 0, 0, 0),
		Color = Theme.Colors.PanelFill,
		TextColor = Theme.Colors.TextDark,
		Parent = controlsRow,
	})
	local stopTargetIndex = 1
	for i, id in ipairs(AUTO_ROLL_STOP_TARGETS) do
		if id == selectedStopTarget then
			stopTargetIndex = i
		end
	end
	stopTargetButton.Activated:Connect(function()
		stopTargetIndex = (stopTargetIndex % #AUTO_ROLL_STOP_TARGETS) + 1
		selectedStopTarget = AUTO_ROLL_STOP_TARGETS[stopTargetIndex]
		local class = classById(selectedStopTarget)
		stopTargetButton.Text = "STOP AT: " .. (class and class.Name or selectedStopTarget)
	end)

	autoRollButton = Theme.newButton({
		Text = "AUTO ROLL: OFF",
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(0.7, 0, 0, 0),
		Color = Theme.Colors.ButtonSecondary,
		Parent = controlsRow,
	})
	autoRollButton.Activated:Connect(function()
		if autoRollActive then
			stopAutoRoll()
			return
		end
		if PlayerState.Profile.Gems < DisplayConfig.ClassRollCostGems then
			if resultLabel then
				resultLabel.Text = "Not enough Gems."
				resultLabel.TextColor3 = Theme.Colors.ButtonDanger
			end
			return
		end
		autoRollActive = true
		autoRollGeneration += 1
		local generation = autoRollGeneration
		if autoRollButton then
			autoRollButton.Text = "AUTO ROLL: ON"
			autoRollButton.BackgroundColor3 = Theme.Colors.ButtonDanger
		end
		task.spawn(runAutoRollLoop, generation)
	end)

	local profileConnection = PlayerState.ProfileChanged:Connect(function()
		refreshClassesPanels(slotsFrame, oddsFrame)
	end)

	UIController.openOverlay("Classes", overlay.Frame, function()
		stopAutoRoll()
		profileConnection()
		spinButton = nil
		autoRollButton = nil
		resultLabel = nil
	end)
end

function ClassController.init(ui)
	UIController = ui

	Remotes.onClientEvent("Core_ClassRollResult", function(payload: any)
		if pendingRollResolve then
			pendingRollResolve(payload)
		end
	end)
end

return ClassController
