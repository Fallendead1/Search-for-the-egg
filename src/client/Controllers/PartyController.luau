--!strict
-- Party pad + chapter/difficulty/size/friends-only selection. Lives inside
-- the Lobby. Locked difficulties/chapters are always rendered from
-- server-reported state (Gameplay_PartyState) -- this never locally decides
-- an unlock. Only the party OWNER can change any setting (server-enforced
-- in PartyService, "NotOwner" otherwise) -- non-owners see the same panel
-- with those controls disabled, and can only Leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Theme)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)
local AssetConfig = require(ReplicatedStorage.SearchForTheEgg.AssetConfig)

local PartyController = {}

local panel: Frame
local contentHost: Frame

local selectedChapter = "Chapter1"
local selectedDifficulty = "Normal"

-- Bumped on every render so a stale countdown-refresh loop from a previous
-- render can tell it's no longer current and stop updating a destroyed label.
local renderGeneration = 0

local renderInParty: () -> ()

local function clearContent()
	for _, child in ipairs(contentHost:GetChildren()) do
		child:Destroy()
	end
end

local function isOwner(): boolean
	return PlayerState.Party.OwnerUserId == Players.LocalPlayer.UserId
end

local function renderChapterSelection(ownerControls: boolean)
	local host = Instance.new("Frame")
	host.Name = "Chapters"
	host.BackgroundTransparency = 1
	host.Size = UDim2.new(1, 0, 0, 120)
	host.Position = UDim2.new(0, 0, 0, 40)
	host.Parent = contentHost

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = host

	for _, chapter in ipairs(DisplayConfig.Chapters) do
		local card = Theme.newPanel(chapter.Id, host)
		card.Size = UDim2.new(0, 220, 1, 0)

		-- Real map-preview art (Chapter1 only so far) sits behind everything
		-- else so the name/COMING SOON/difficulty controls below still read
		-- clearly on top of it.
		local mapArtId = AssetConfig.PartyMapPreviews[chapter.Id] or 0
		if mapArtId ~= 0 then
			local art = Instance.new("ImageLabel")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.Size = UDim2.fromScale(1, 1)
			art.Image = AssetConfig.image(mapArtId)
			art.ScaleType = Enum.ScaleType.Crop
			art.Parent = card

			local caption = Instance.new("Frame")
			caption.BackgroundColor3 = Color3.new(0, 0, 0)
			caption.BackgroundTransparency = 0.4
			caption.BorderSizePixel = 0
			caption.Size = UDim2.new(1, 0, 0, 44)
			caption.Parent = card
		end

		-- chapter.Locked is a permanent "not released yet" flag (only
		-- Chapter2 sets it, alongside Enabled = false server-side and no
		-- Difficulties table) -- entirely separate from the per-difficulty
		-- Wins gating below. Previously this ANDed in a Wins comparison, so
		-- Chapter2 would stop showing LOCKED (and look selectable, with
		-- nothing to actually select) the moment a player earned 1 Win.
		local chapterLocked = chapter.Locked == true

		Theme.newLabel({
			Text = chapter.Name .. "\n" .. chapter.Subtitle,
			Size = UDim2.new(1, 0, 0, 44),
			TextColor = chapterLocked and Theme.Colors.Locked or Theme.Colors.TextLight,
			Parent = card,
		})

		if chapterLocked then
			Theme.newLabel({
				Text = "COMING SOON",
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 1, -34),
				TextColor = Theme.Colors.Locked,
				Parent = card,
			})
			continue
		end

		if chapter.Difficulties then
			local diffRow = Instance.new("Frame")
			diffRow.BackgroundTransparency = 1
			diffRow.Size = UDim2.new(1, -10, 0, 40)
			diffRow.Position = UDim2.new(0.5, 0, 1, -46)
			diffRow.AnchorPoint = Vector2.new(0.5, 0)
			diffRow.Parent = card

			local diffLayout = Instance.new("UIListLayout")
			diffLayout.FillDirection = Enum.FillDirection.Horizontal
			diffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			diffLayout.Padding = UDim.new(0, 6)
			diffLayout.Parent = diffRow

			for _, difficulty in ipairs(chapter.Difficulties) do
				local difficultyLocked = (PlayerState.Profile.TotalWins or 0) < (difficulty.RequiresWins or 0)
				local isSelected = selectedChapter == chapter.Id and selectedDifficulty == difficulty.Id
				local clickable = ownerControls and not difficultyLocked

				-- Final art bakes the difficulty's own label in, so when it's
				-- available the button's text is cleared and LOCKED is shown
				-- as a dimmed image instead of appended "(LOCKED)" text.
				local diffArtId = AssetConfig.PartyDifficultyButtons[difficulty.Id] or 0
				local diffButton = Theme.newButton({
					Text = diffArtId ~= 0 and "" or (difficultyLocked and (difficulty.Name .. " (LOCKED)") or difficulty.Name),
					Size = UDim2.new(0, 90, 1, 0),
					Color = isSelected and Theme.Colors.ButtonSecondary
						or (difficultyLocked and Theme.Colors.ButtonDisabled or Theme.Colors.ButtonPrimary),
					Parent = diffRow,
				})
				if diffArtId ~= 0 then
					local art = Instance.new("ImageLabel")
					art.Name = "Art"
					art.BackgroundTransparency = 1
					art.Size = UDim2.fromScale(1, 1)
					art.Image = AssetConfig.image(diffArtId)
					art.ScaleType = Enum.ScaleType.Fit
					art.ImageTransparency = difficultyLocked and 0.6 or (ownerControls and 0 or 0.25)
					art.Parent = diffButton

					local stroke = diffButton:FindFirstChildOfClass("UIStroke")
					if stroke and isSelected then
						stroke.Color = Theme.Colors.TextGold
						stroke.Thickness = 3
					end
				end
				Theme.setButtonEnabled(diffButton, clickable)
				diffButton.Activated:Connect(function()
					if not clickable then
						return
					end
					selectedChapter = chapter.Id
					selectedDifficulty = difficulty.Id
					-- PartyService.Init's handler reads (player, chapterId, difficultyId) positionally.
					Remotes.fireServer("Gameplay_RequestSetPartySelection", chapter.Id, difficulty.Id)
					renderInParty()
				end)
			end
		end
	end
end

-- PARTY SIZE (-/count/+) and FRIENDS ONLY (checkbox) row -- both owner-only;
-- non-owners see the current values as plain read-only text/state.
local function renderSizeAndFriendsRow(ownerControls: boolean)
	local row = Instance.new("Frame")
	row.Name = "SizeAndFriends"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.new(0, 0, 0, 168)
	row.Parent = contentHost

	-- Party size: minus / count / plus
	local sizeGroup = Instance.new("Frame")
	sizeGroup.BackgroundTransparency = 1
	sizeGroup.Size = UDim2.new(0.5, -6, 1, 0)
	sizeGroup.Parent = row

	local sizeLayout = Instance.new("UIListLayout")
	sizeLayout.FillDirection = Enum.FillDirection.Horizontal
	sizeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	sizeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sizeLayout.Padding = UDim.new(0, 8)
	sizeLayout.Parent = sizeGroup

	local currentSize = PlayerState.Party.MaxSize or DisplayConfig.MaxPartySize

	local minusButton = Theme.newButton({
		Text = "-",
		Size = UDim2.new(0, 36, 1, 0),
		Color = Theme.Colors.ButtonDanger,
		LayoutOrder = 1,
		Parent = sizeGroup,
	})
	Theme.setButtonEnabled(minusButton, ownerControls and currentSize > 1)
	minusButton.Activated:Connect(function()
		if not ownerControls then
			return
		end
		Remotes.fireServer("Gameplay_RequestSetPartySize", math.max(1, currentSize - 1))
	end)

	Theme.newLabel({
		Text = "PARTY SIZE\n" .. tostring(currentSize),
		Size = UDim2.new(0, 90, 1, 0),
		Font = Theme.FontBody,
		LayoutOrder = 2,
		Parent = sizeGroup,
	})

	local plusButton = Theme.newButton({
		Text = "+",
		Size = UDim2.new(0, 36, 1, 0),
		Color = Theme.Colors.ButtonSecondary,
		LayoutOrder = 3,
		Parent = sizeGroup,
	})
	Theme.setButtonEnabled(plusButton, ownerControls and currentSize < DisplayConfig.MaxPartySize)
	plusButton.Activated:Connect(function()
		if not ownerControls then
			return
		end
		Remotes.fireServer("Gameplay_RequestSetPartySize", math.min(DisplayConfig.MaxPartySize, currentSize + 1))
	end)

	-- Friends Only checkbox
	local friendsGroup = Instance.new("Frame")
	friendsGroup.BackgroundTransparency = 1
	friendsGroup.Size = UDim2.new(0.5, -6, 1, 0)
	friendsGroup.Position = UDim2.new(0.5, 6, 0, 0)
	friendsGroup.Parent = row

	local friendsOnly = PlayerState.Party.FriendsOnly == true
	local checkButton = Theme.newButton({
		Text = friendsOnly and "\226\156\148 FRIENDS ONLY" or "FRIENDS ONLY",
		Size = UDim2.new(1, 0, 1, 0),
		Color = friendsOnly and Theme.Colors.ButtonSecondary or Theme.Colors.PanelFill,
		TextColor = friendsOnly and Theme.Colors.TextLight or Theme.Colors.TextDark,
		Parent = friendsGroup,
	})
	Theme.setButtonEnabled(checkButton, ownerControls)
	checkButton.Activated:Connect(function()
		if not ownerControls then
			return
		end
		Remotes.fireServer("Gameplay_RequestSetFriendsOnly", not friendsOnly)
	end)
end

renderInParty = function()
	clearContent()
	renderGeneration += 1
	local myGeneration = renderGeneration
	local ownerControls = isOwner()

	local memberCount = #PlayerState.Party.Members
	local targetSize = PlayerState.Party.MaxSize or DisplayConfig.MaxPartySize

	local headerLabel = Theme.newLabel({
		Text = ("%d/%d - %s / %s"):format(memberCount, targetSize, selectedChapter, selectedDifficulty),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = contentHost,
	})

	-- Live "starts in Xs" countdown -- server is the only clock that matters
	-- (StartsAt is an os.time() epoch second it will actually auto-start at);
	-- this just renders the difference every tick, stopping the moment the
	-- party actually starts or this panel gets rebuilt/closed.
	local countdownLabel = Theme.newLabel({
		Text = "",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 20),
		TextColor = Theme.Colors.TextGold,
		Font = Theme.FontBody,
		Parent = contentHost,
	})
	task.spawn(function()
		while renderGeneration == myGeneration and countdownLabel.Parent do
			local startsAt = PlayerState.Party.StartsAt
			if PlayerState.Party.Started or type(startsAt) ~= "number" then
				countdownLabel.Text = ""
			else
				local remaining = math.max(0, math.ceil(startsAt - os.time()))
				countdownLabel.Text = ("Auto-teleport in %ds"):format(remaining)
			end
			task.wait(1)
		end
	end)

	renderChapterSelection(ownerControls)
	renderSizeAndFriendsRow(ownerControls)

	local actionRow = Instance.new("Frame")
	actionRow.BackgroundTransparency = 1
	actionRow.Size = UDim2.new(1, 0, 0, 56)
	actionRow.Position = UDim2.new(0, 0, 1, -60)
	actionRow.Parent = contentHost

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = actionRow

	if ownerControls then
		local startButton = Theme.newButton({
			Text = "START NOW",
			Size = UDim2.new(0, 160, 1, 0),
			Color = Theme.Colors.ButtonSecondary,
			Parent = actionRow,
		})
		startButton.Activated:Connect(function()
			Remotes.fireServer("Gameplay_RequestStartParty")
		end)
	end

	local leaveButton = Theme.newButton({
		Text = "LEAVE",
		Size = UDim2.new(0, 160, 1, 0),
		Color = Theme.Colors.ButtonDanger,
		Parent = actionRow,
	})
	leaveButton.Activated:Connect(function()
		Remotes.fireServer("Gameplay_RequestLeaveParty")
	end)
end

-- The physical Lobby pads (PartyPadService, touch-to-create-or-join) are the
-- primary way to form a party -- their signs already show live queue state
-- in-world. This panel is party MANAGEMENT (chapter/difficulty/size/friends/
-- start/leave) for once you're actually in one; it has no reason to float
-- on screen for a player who hasn't touched a pad yet, so it stays hidden
-- until then.
local function render()
	if PlayerState.Party.InParty then
		panel.Visible = true
		renderInParty()
	else
		panel.Visible = false
		renderGeneration += 1
		clearContent()
	end
end

function PartyController.build(parent: Instance)
	panel = Theme.newPanel("PartyPad", parent)
	panel.Size = UDim2.new(0, 520, 0, 320)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)

	contentHost = Instance.new("Frame")
	contentHost.Name = "Content"
	contentHost.BackgroundTransparency = 1
	contentHost.Size = UDim2.new(1, -20, 1, -20)
	contentHost.Position = UDim2.new(0.5, 0, 0.5, 0)
	contentHost.AnchorPoint = Vector2.new(0.5, 0.5)
	contentHost.Parent = panel

	render()
end

function PartyController.init()
	Remotes.onClientEvent("Gameplay_PartyState", function(state: any)
		if type(state) ~= "table" then
			return
		end
		PlayerState.applyPartyState(state)
		if state.ChapterId then
			selectedChapter = state.ChapterId
		end
		if state.Difficulty then
			selectedDifficulty = state.Difficulty
		end
		if contentHost then
			render()
		end
	end)
end

return PartyController
