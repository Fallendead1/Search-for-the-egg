--!strict
-- Party pad + chapter/difficulty selection. Lives inside the Lobby.
-- Locked difficulties/chapters are always rendered from server-reported
-- state (Gameplay_PartyState) -- this never locally decides an unlock.

local Theme = require(script.Parent.Parent.UI.Theme)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local DisplayConfig = require(script.Parent.Parent.Data.DisplayConfig)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local PartyController = {}

local panel: Frame
local contentHost: Frame

local selectedChapter = "Chapter1"
local selectedDifficulty = "Normal"

local renderInParty: () -> ()

local function clearContent()
	for _, child in ipairs(contentHost:GetChildren()) do
		child:Destroy()
	end
end

local function renderChapterSelection()
	local host = Instance.new("Frame")
	host.Name = "Chapters"
	host.BackgroundTransparency = 1
	host.Size = UDim2.new(1, 0, 0, 120)
	host.Position = UDim2.new(0, 0, 0, 96)
	host.Parent = contentHost

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = host

	for _, chapter in ipairs(DisplayConfig.Chapters) do
		local card = Theme.newPanel(chapter.Id, host)
		card.Size = UDim2.new(0, 220, 1, 0)

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
			TextColor = chapterLocked and Theme.Colors.Locked or Theme.Colors.TextDark,
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

				local diffButton = Theme.newButton({
					Text = difficultyLocked and (difficulty.Name .. " (LOCKED)") or difficulty.Name,
					Size = UDim2.new(0, 90, 1, 0),
					Color = isSelected and Theme.Colors.ButtonSecondary
						or (difficultyLocked and Theme.Colors.ButtonDisabled or Theme.Colors.ButtonPrimary),
					Parent = diffRow,
				})
				Theme.setButtonEnabled(diffButton, not difficultyLocked)
				diffButton.Activated:Connect(function()
					if difficultyLocked then
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

renderInParty = function()
	clearContent()

	local memberCount = #PlayerState.Party.Members
	Theme.newLabel({
		Text = ("%d/%d - %s / %s"):format(memberCount, DisplayConfig.MaxPartySize, selectedChapter, selectedDifficulty),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = contentHost,
	})

	renderChapterSelection()

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

	local startButton = Theme.newButton({
		Text = "START",
		Size = UDim2.new(0, 160, 1, 0),
		Color = Theme.Colors.ButtonSecondary,
		Parent = actionRow,
	})
	startButton.Activated:Connect(function()
		Remotes.fireServer("Gameplay_RequestStartParty")
	end)

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
-- in-world. This panel is party MANAGEMENT (chapter/difficulty/start/leave)
-- for once you're actually in one; it has no reason to float on screen for a
-- player who hasn't touched a pad yet, so it stays hidden until then.
local function render()
	if PlayerState.Party.InParty then
		panel.Visible = true
		renderInParty()
	else
		panel.Visible = false
		clearContent()
	end
end

function PartyController.build(parent: Instance)
	panel = Theme.newPanel("PartyPad", parent)
	panel.Size = UDim2.new(0, 480, 0, 260)
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
