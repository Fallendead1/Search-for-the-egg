--!strict
-- CLASSES overlay: odds list, spin, roll reveal animation, two class
-- slots, and Auto Roll. Every roll result comes from the server -- this
-- controller only requests rolls and renders whatever comes back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Theme)
local Overlay = require(script.Parent.Parent.UI.Components.Overlay)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)
local MonetizationController = require(script.Parent.MonetizationController)
local AssetConfig = require(ReplicatedStorage.SearchForTheEgg.AssetConfig)

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
local selectedClassId = "Starter"

-- Temporary placeholder concepts (Section 61) -- centralized here so a
-- future AssetConfig.ClassIcons image swap is the only change needed later.
local CLASS_ICON_TEXT: { [string]: string } = {
	Starter = "✋",
	PackMule = "🎒",
	FeatherMerchant = "🪙",
	Forkmaster = "🍴",
	Demolitionist = "🧨",
	Prospector = "💎",
	DroneSpecialist = "🚁",
	UltimateFarmer = "🥚",
}

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

-- Compact left-list row: rarity-colored accent bar, icon, name, odds%, and
-- an OWNED/EQUIPPED/LOCKED state badge (Section 59). Clicking any row
-- (owned or not) selects it for the center/right panels -- selecting an
-- unowned class does NOT grant it; only Spin/RollClass can do that.
local function buildClassRow(parent: Instance, class: any, layoutOrder: number, onSelect: (string) -> ())
	local owned = PlayerState.Profile.OwnedClasses[class.Id] == true
	local equipped = PlayerState.Profile.EquippedClass == class.Id
		or (PlayerState.Profile.SecondSlotUnlocked and PlayerState.Profile.SecondClass == class.Id)

	local row = Theme.newPanel(class.Id, parent)
	row.Size = UDim2.new(1, 0, 0, 60)
	row.LayoutOrder = layoutOrder

	-- Final art (icon + name + odds all baked in, matching ClassConfig.Odds/
	-- DisplayName exactly) when available; falls back to the old flat panel
	-- + accent bar + emoji + text row otherwise.
	local cardArtId = AssetConfig.ClassCards[class.Id] or 0
	if cardArtId ~= 0 then
		row.BackgroundTransparency = 1
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Size = UDim2.fromScale(1, 1)
		art.Image = AssetConfig.image(cardArtId)
		art.ScaleType = Enum.ScaleType.Stretch
		art.Parent = row

		if class.Id == selectedClassId then
			local stroke = row:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Theme.Colors.TextGold
				stroke.Thickness = 3
			end
		end
	else
		if class.Id == selectedClassId then
			row.BackgroundColor3 = Theme.Colors.Background
		end

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = class.RarityColor
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 6, 1, -8)
		accent.Position = UDim2.new(0, 4, 0, 4)
		accent.Parent = row
		Theme.applyOutlineCorner(accent, 0, UDim.new(0, 3))

		Theme.newLabel({
			Text = CLASS_ICON_TEXT[class.Id] or "?",
			Size = UDim2.new(0, 34, 0, 34),
			Position = UDim2.new(0, 16, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Font = Theme.Font,
			Parent = row,
		})

		Theme.newLabel({
			Text = class.Name,
			Size = UDim2.new(1, -180, 0, 24),
			Position = UDim2.new(0, 58, 0, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.FontBody,
			Parent = row,
		})
		Theme.newLabel({
			Text = ("%.1f%%"):format(class.Odds),
			Size = UDim2.new(1, -180, 0, 20),
			Position = UDim2.new(0, 58, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor = Theme.Colors.TextDark,
			Font = Theme.FontBody,
			Parent = row,
		})
	end

	-- State badge: real art overlay (owned/equipped/locked) when available,
	-- else the old text badge. Always the dynamic part, regardless of which
	-- branch above ran.
	local stateAssetId = equipped and AssetConfig.ClassStates.Equipped
		or (owned and AssetConfig.ClassStates.Owned or AssetConfig.ClassStates.Locked)
	if stateAssetId ~= 0 then
		local badge = Instance.new("ImageLabel")
		badge.Name = "StateBadge"
		badge.BackgroundTransparency = 1
		badge.Size = UDim2.new(0, 110, 0, 26)
		badge.Position = UDim2.new(1, -10, 0.5, 0)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Image = AssetConfig.image(stateAssetId)
		badge.ScaleType = Enum.ScaleType.Fit
		badge.Parent = row
	else
		local badgeText = equipped and "EQUIPPED" or (owned and "OWNED" or "LOCKED")
		Theme.newLabel({
			Text = badgeText,
			Size = UDim2.new(0, 110, 0, 26),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextColor = equipped and Theme.Colors.ButtonSecondary or (owned and Theme.Colors.TextGold or Theme.Colors.Locked),
			Font = Theme.FontBody,
			Parent = row,
		})
	end

	local hitButton = Instance.new("TextButton")
	hitButton.BackgroundTransparency = 1
	hitButton.Text = ""
	hitButton.Size = UDim2.fromScale(1, 1)
	hitButton.Parent = row
	hitButton.Activated:Connect(function()
		onSelect(class.Id)
	end)
end

local function buildClassList(parent: Instance, onSelect: (string) -> ())
	local scroll = Overlay.newScroll(parent)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, class in ipairs(DisplayConfig.Classes) do
		buildClassRow(scroll, class, i, onSelect)
	end
end

-- Center preview -- a themed icon plate standing in for a full 3D
-- character/class-model preview (Section 60: no custom Class models are
-- required yet, and reusing the player's own character with a themed
-- surrounding icon is an explicitly acceptable substitute).
local function buildPreview(parent: Instance, class: any)
	local plate = Theme.newPanel("Preview", parent)
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = class.RarityColor

	local inner = Theme.newPanel("Inner", plate)
	inner.Size = UDim2.new(1, -16, 1, -16)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)

	Theme.newLabel({
		Text = CLASS_ICON_TEXT[class.Id] or "?",
		Size = UDim2.new(1, 0, 0.55, 0),
		Position = UDim2.new(0.5, 0, 0.08, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Font,
		Parent = inner,
	})
	Theme.newLabel({
		Text = class.Name,
		Size = UDim2.new(1, -12, 0, 34),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.FontBody,
		Parent = inner,
	})
end

-- Right description card: name, description, gold stat lines, and either
-- EQUIP SLOT 1/2 controls (owned) or a ROLL TO GET prompt (not owned) --
-- Sections 46-53/56.
-- Only 4 of the 8 classes have description art wired in (see AssetConfig.
-- ClassDescriptionCards' comment) -- for those, the image already bakes in
-- name/description/stat-lines exactly, so this just anchors the same
-- ROLL TO GET / EQUIP SLOT controls to the card's bottom "footer well"
-- instead of rebuilding the (now redundant) text scroll.
local function buildDescriptionCardFromArt(card: Instance, class: any, descArtId: number)
	card.BackgroundTransparency = 1
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Image = AssetConfig.image(descArtId)
	art.ScaleType = Enum.ScaleType.Fit
	art.Parent = card

	local owned = PlayerState.Profile.OwnedClasses[class.Id] == true
	if not owned then
		Theme.newButton({
			Text = "ROLL TO GET",
			Size = UDim2.new(1, -24, 0, 44),
			Position = UDim2.new(0.5, 0, 1, -14),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Theme.Colors.ButtonDisabled,
			Parent = card,
		}).Active = false
		return
	end

	local equippedSlot1 = PlayerState.Profile.EquippedClass == class.Id
	local equippedSlot2 = PlayerState.Profile.SecondSlotUnlocked and PlayerState.Profile.SecondClass == class.Id

	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, -24, 0, PlayerState.Profile.SecondSlotUnlocked and 92 or 44)
	footer.Position = UDim2.new(0.5, 0, 1, -14)
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Parent = card

	local footerLayout = Instance.new("UIListLayout")
	footerLayout.Padding = UDim.new(0, 8)
	footerLayout.Parent = footer

	local slot1Button = Theme.newButton({
		Text = equippedSlot1 and "SLOT 1: EQUIPPED" or "EQUIP SLOT 1",
		Size = UDim2.new(1, 0, 0, 40),
		Color = equippedSlot1 and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
		LayoutOrder = 1,
		Parent = footer,
	})
	Theme.setButtonEnabled(slot1Button, not equippedSlot1 and not equippedSlot2)
	slot1Button.Activated:Connect(function()
		requestEquip(1, class.Id)
	end)

	if PlayerState.Profile.SecondSlotUnlocked then
		local slot2Button = Theme.newButton({
			Text = equippedSlot2 and "SLOT 2: EQUIPPED" or "EQUIP SLOT 2",
			Size = UDim2.new(1, 0, 0, 40),
			Color = equippedSlot2 and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
			LayoutOrder = 2,
			Parent = footer,
		})
		Theme.setButtonEnabled(slot2Button, not equippedSlot2 and not equippedSlot1)
		slot2Button.Activated:Connect(function()
			requestEquip(2, class.Id)
		end)
	end
end

local function buildDescriptionCard(parent: Instance, class: any)
	local card = Theme.newPanel("Description", parent)
	card.Size = UDim2.fromScale(1, 1)

	local descArtId = AssetConfig.ClassDescriptionCards[class.Id] or 0
	if descArtId ~= 0 then
		buildDescriptionCardFromArt(card, class, descArtId)
		return
	end

	card.BackgroundColor3 = Color3.fromRGB(30, 28, 40)

	local scroll = Overlay.newScroll(card)
	scroll.Size = UDim2.new(1, -20, 1, -20)
	scroll.Position = UDim2.fromScale(0.5, 0.5)
	scroll.AnchorPoint = Vector2.new(0.5, 0.5)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	Theme.newLabel({
		Text = class.Name,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Theme.Font,
		TextColor = Theme.Colors.TextLight,
		LayoutOrder = 1,
		Parent = scroll,
	})
	Theme.newLabel({
		Text = class.Description,
		Size = UDim2.new(1, 0, 0, 60),
		Font = Theme.FontBody,
		TextColor = Theme.Colors.TextLight,
		LayoutOrder = 2,
		Parent = scroll,
	})

	for i, line in ipairs(class.StatLines) do
		Theme.newLabel({
			Text = line,
			Size = UDim2.new(1, 0, 0, 26),
			Font = Theme.FontBody,
			TextColor = Theme.Colors.TextGold,
			LayoutOrder = 2 + i,
			Parent = scroll,
		})
	end

	local owned = PlayerState.Profile.OwnedClasses[class.Id] == true
	if not owned then
		Theme.newButton({
			Text = "ROLL TO GET",
			Size = UDim2.new(1, 0, 0, 44),
			Color = Theme.Colors.ButtonDisabled,
			LayoutOrder = 100,
			Parent = scroll,
		}).Active = false
		return
	end

	local equippedSlot1 = PlayerState.Profile.EquippedClass == class.Id
	local equippedSlot2 = PlayerState.Profile.SecondSlotUnlocked and PlayerState.Profile.SecondClass == class.Id

	local slot1Button = Theme.newButton({
		Text = equippedSlot1 and "SLOT 1: EQUIPPED" or "EQUIP SLOT 1",
		Size = UDim2.new(1, 0, 0, 40),
		Color = equippedSlot1 and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
		LayoutOrder = 101,
		Parent = scroll,
	})
	Theme.setButtonEnabled(slot1Button, not equippedSlot1 and not equippedSlot2)
	slot1Button.Activated:Connect(function()
		requestEquip(1, class.Id)
	end)

	if PlayerState.Profile.SecondSlotUnlocked then
		local slot2Button = Theme.newButton({
			Text = equippedSlot2 and "SLOT 2: EQUIPPED" or "EQUIP SLOT 2",
			Size = UDim2.new(1, 0, 0, 40),
			Color = equippedSlot2 and Theme.Colors.ButtonSecondary or Theme.Colors.ButtonPrimary,
			LayoutOrder = 102,
			Parent = scroll,
		})
		Theme.setButtonEnabled(slot2Button, not equippedSlot2 and not equippedSlot1)
		slot2Button.Activated:Connect(function()
			requestEquip(2, class.Id)
		end)
	else
		Theme.newLabel({
			Text = "SLOT 2 LOCKED",
			Size = UDim2.new(1, 0, 0, 30),
			TextColor = Theme.Colors.Locked,
			Font = Theme.FontBody,
			LayoutOrder = 102,
			Parent = scroll,
		})
	end
end

-- Top-right equipped-slot summary (Section 54) -- compact, distinct from
-- the description card's full equip CONTROLS for the selected class.
local function buildTopSlots(parent: Instance)
	local slot1 = Theme.newPanel("Slot1", parent)
	slot1.Size = UDim2.new(0.48, 0, 1, 0)
	slot1.Position = UDim2.new(0, 0, 0, 0)

	local equippedClass = classById(PlayerState.Profile.EquippedClass or "Starter")
	Theme.newLabel({
		Text = (equippedClass and equippedClass.Name or "Starter") .. "\n[SELECTED]",
		Size = UDim2.fromScale(1, 1),
		Font = Theme.FontBody,
		Parent = slot1,
	})

	local slot2 = Theme.newPanel("Slot2", parent)
	slot2.Size = UDim2.new(0.48, 0, 1, 0)
	slot2.Position = UDim2.new(0.52, 0, 0, 0)

	if PlayerState.Profile.SecondSlotUnlocked then
		local secondClass = PlayerState.Profile.SecondClass and classById(PlayerState.Profile.SecondClass)
		Theme.newLabel({
			Text = secondClass and (secondClass.Name .. "\n[SELECTED]") or "EMPTY",
			TextColor = secondClass and Theme.Colors.TextDark or Theme.Colors.Locked,
			Size = UDim2.fromScale(1, 1),
			Font = Theme.FontBody,
			Parent = slot2,
		})
	else
		local unlockButton = Theme.newButton({
			Text = ("+1 SLOT\n%d R$"):format(DisplayConfig.ClassMonetization.ExtraSlotRobux),
			Size = UDim2.fromScale(1, 1),
			Color = Theme.Colors.ButtonPurchase,
			TextColor = Theme.Colors.TextLight,
			Parent = slot2,
		})
		unlockButton.Activated:Connect(function()
			MonetizationController.promptGamePass("ExtraClassSlot")
		end)
	end
end

-- Rebuilds every panel in place. Called on open and again whenever
-- Core_ProfileUpdated changes PlayerState.Profile (equip confirmations, new
-- rolls, Slot 2 unlock) while the overlay is open.
local function refreshClassesPanels(slotsFrame: Instance, listFrame: Instance, previewFrame: Instance, descriptionFrame: Instance)
	for _, child in ipairs(slotsFrame:GetChildren()) do
		child:Destroy()
	end
	buildTopSlots(slotsFrame)

	local function selectClass(classId: string)
		selectedClassId = classId
		refreshClassesPanels(slotsFrame, listFrame, previewFrame, descriptionFrame)
	end

	for _, child in ipairs(listFrame:GetChildren()) do
		child:Destroy()
	end
	buildClassList(listFrame, selectClass)

	local selected = classById(selectedClassId) or classById("Starter")
	if selected then
		for _, child in ipairs(previewFrame:GetChildren()) do
			child:Destroy()
		end
		buildPreview(previewFrame, selected)

		for _, child in ipairs(descriptionFrame:GetChildren()) do
			child:Destroy()
		end
		buildDescriptionCard(descriptionFrame, selected)
	end
end

function ClassController.open()
	stopAutoRoll()

	local overlay = Overlay.new("CLASSES", UDim2.new(0.94, 0, 0.9, 0))
	overlay.CloseButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	-- Slots panel, top-right (leaving room for the title bar's X).
	local slotsFrame = Instance.new("Frame")
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.Size = UDim2.new(0.34, 0, 0, 64)
	slotsFrame.Position = UDim2.new(1, -12, 0, 6)
	slotsFrame.AnchorPoint = Vector2.new(1, 0)
	slotsFrame.Parent = overlay.Body

	-- Main 3-column band: list / preview / description.
	local mainBand = Instance.new("Frame")
	mainBand.BackgroundTransparency = 1
	-- Must end above resultLabel/controlsRow/bottomRow's reserved band
	-- (152px from the bottom -- see their Position offsets below) or the
	-- preview/description panels visually collide with the Spin controls.
	mainBand.Size = UDim2.new(1, -20, 1, -228)
	mainBand.Position = UDim2.new(0.5, 0, 0, 76)
	mainBand.AnchorPoint = Vector2.new(0.5, 0)
	mainBand.Parent = overlay.Body

	local listFrame = Instance.new("Frame")
	listFrame.BackgroundTransparency = 1
	listFrame.Size = UDim2.new(0.3, -8, 1, 0)
	listFrame.Position = UDim2.new(0, 0, 0, 0)
	listFrame.Parent = mainBand

	local previewFrame = Instance.new("Frame")
	previewFrame.BackgroundTransparency = 1
	previewFrame.Size = UDim2.new(0.28, -8, 1, 0)
	previewFrame.Position = UDim2.new(0.3, 8, 0, 0)
	previewFrame.Parent = mainBand

	local descriptionFrame = Instance.new("Frame")
	descriptionFrame.BackgroundTransparency = 1
	descriptionFrame.Size = UDim2.new(0.42, -8, 1, 0)
	descriptionFrame.Position = UDim2.new(0.58, 8, 0, 0)
	descriptionFrame.Parent = mainBand

	resultLabel = Theme.newLabel({
		Text = "",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.new(0.5, 0, 1, -152),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = overlay.Body,
	})

	-- Bottom controls: Spin / Auto Roll / Stop-at, then Fast Rolls / 2x
	-- Luck / BACK on the row below.
	local controlsRow = Instance.new("Frame")
	controlsRow.BackgroundTransparency = 1
	controlsRow.Size = UDim2.new(1, -20, 0, 56)
	controlsRow.Position = UDim2.new(0.5, 0, 1, -70)
	controlsRow.AnchorPoint = Vector2.new(0.5, 1)
	controlsRow.Parent = overlay.Body

	spinButton = Theme.newButton({
		Text = ("SPIN CLASS - %d 💎"):format(DisplayConfig.ClassRollCostGems),
		Size = UDim2.new(0.34, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Colors.ButtonSecondary,
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
		Size = UDim2.new(0.33, 0, 1, 0),
		Position = UDim2.new(0.345, 0, 0, 0),
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

	-- Circular-arrow Auto Roll toggle (Section 58).
	autoRollButton = Theme.newButton({
		Text = "🔄 AUTO - OFF",
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(0.69, 0, 0, 0),
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
			autoRollButton.Text = "🔄 AUTO - ON"
			autoRollButton.BackgroundColor3 = Theme.Colors.ButtonDanger
		end
		task.spawn(runAutoRollLoop, generation)
	end)

	local bottomRow = Instance.new("Frame")
	bottomRow.BackgroundTransparency = 1
	bottomRow.Size = UDim2.new(1, -20, 0, 48)
	bottomRow.Position = UDim2.new(0.5, 0, 1, -8)
	bottomRow.AnchorPoint = Vector2.new(0.5, 1)
	bottomRow.Parent = overlay.Body

	local bottomLayout = Instance.new("UIListLayout")
	bottomLayout.FillDirection = Enum.FillDirection.Horizontal
	bottomLayout.Padding = UDim.new(0, 8)
	bottomLayout.Parent = bottomRow

	local fastRolls = Theme.newButton({
		Text = MonetizationController.ownsGamePass("FastRolls") and "FAST ROLLS: OWNED"
			or ("FAST ROLLS - %d R$"):format(DisplayConfig.ClassMonetization.FastRollsRobux),
		Size = UDim2.new(0, 180, 1, 0),
		Parent = bottomRow,
	})
	fastRolls.Activated:Connect(function()
		MonetizationController.promptGamePass("FastRolls")
	end)

	local doubleLuck = Theme.newButton({
		Text = MonetizationController.ownsGamePass("ClassLuck2x") and "2x LUCK: OWNED"
			or ("2x LUCK - %d R$"):format(DisplayConfig.ClassMonetization.DoubleLuckRobux),
		Size = UDim2.new(0, 180, 1, 0),
		Color = Theme.Colors.ButtonPurchase,
		TextColor = Theme.Colors.TextLight,
		Parent = bottomRow,
	})
	doubleLuck.Activated:Connect(function()
		MonetizationController.promptGamePass("ClassLuck2x")
	end)

	-- Large red BACK button (Section 43/63), in addition to the title bar's X.
	local backButton = Theme.newButton({
		Text = "BACK",
		Size = UDim2.new(0, 180, 1, 0),
		Color = Theme.Colors.ButtonDanger,
		TextColor = Theme.Colors.TextLight,
		Parent = bottomRow,
	})
	backButton.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	refreshClassesPanels(slotsFrame, listFrame, previewFrame, descriptionFrame)

	local profileConnection = PlayerState.ProfileChanged:Connect(function()
		refreshClassesPanels(slotsFrame, listFrame, previewFrame, descriptionFrame)
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
