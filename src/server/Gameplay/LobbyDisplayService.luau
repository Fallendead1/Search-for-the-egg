--[[
	Drives the physical Lobby's queue signs and leaderboard boards from real
	game state (PartyService via PartyPadService, and Core's
	LeaderboardService) instead of a placeholder/local-only proxy. Purely a
	display -- it never creates parties, starts runs, or mutates any player
	state; PartyPadService (touch-to-join) and the existing party UI already
	own that.

	Entirely optional: if Workspace.SearchForTheEgg_Lobby (or its Queues /
	Leaderboards models) isn't present, this no-ops rather than erroring, so
	it's safe before the physical Lobby is built or in a place that doesn't
	have one.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PartyPadService = require(script.Parent.PartyPadService)
local CoreLocator = require(script.Parent.CoreLocator)

local LobbyDisplayService = {}

local QUEUE_REFRESH_SECONDS = 0.5
local BOARD_REFRESH_SECONDS = 5
local BOARD_ROWS = 5

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return ("%02d:%02d"):format(minutes, secs)
end

local function formatBoardValue(statName: string, value: number): string
	if statName == "BestTime" then
		return formatTime(value)
	end
	return tostring(value)
end

local function displayNameFor(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and name then
		return name
	end
	return "Player" .. tostring(userId)
end

local function updateQueueSigns(queues: Instance)
	for _, queue in ipairs(queues:GetChildren()) do
		local zone = queue:FindFirstChild("QueueZone")
		local sign = queue:FindFirstChild("QueueSign")
		local display = sign and sign:FindFirstChild("Display")
		local label = display and display:FindFirstChild("Text")
		if zone and label then
			local party = PartyPadService.GetPadParty(zone)
			if not party then
				label.Text = "Join Match\nEmpty"
			elseif party.Started then
				label.Text = "Match Starting\n" .. tostring(#party.Members) .. "/4"
			else
				label.Text = "Join Match\n" .. tostring(#party.Members) .. "/4"
			end
		end
	end
end

local function updateLeaderboards(leaderboards: Instance)
	local ok, boards = pcall(function()
		return CoreLocator.GetLeaderboardService().GetBoards()
	end)
	if not ok then
		return
	end

	for _, board in ipairs(leaderboards:GetChildren()) do
		local statNameValue = board:FindFirstChild("StatName")
		local statName = statNameValue and statNameValue.Value
		local rows = statName and boards[statName]
		if rows then
			for row = 1, BOARD_ROWS do
				local rowPart = board:FindFirstChild("Row" .. row)
				local label = rowPart and rowPart:FindFirstChild("Display") and rowPart.Display:FindFirstChild("Text")
				if label then
					local entry = rows[row]
					if entry then
						label.Text = ("%02d  %s   %s"):format(row, displayNameFor(entry.UserId), formatBoardValue(statName, entry.Value))
					else
						label.Text = ("%02d    --"):format(row)
					end
				end
			end
		end
	end
end

function LobbyDisplayService.Init()
	local lobby = Workspace:FindFirstChild("SearchForTheEgg_Lobby")
	if not lobby then
		return
	end

	local queues = lobby:FindFirstChild("Queues")
	local leaderboards = lobby:FindFirstChild("Leaderboards")
	if not queues and not leaderboards then
		return
	end

	task.spawn(function()
		while lobby.Parent do
			if queues then
				updateQueueSigns(queues)
			end
			task.wait(QUEUE_REFRESH_SECONDS)
		end
	end)

	if leaderboards then
		task.spawn(function()
			while lobby.Parent do
				updateLeaderboards(leaderboards)
				task.wait(BOARD_REFRESH_SECONDS)
			end
		end)
	end
end

return LobbyDisplayService
