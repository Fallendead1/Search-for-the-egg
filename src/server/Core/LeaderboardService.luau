--[[
	Lobby leaderboards (Time Record, Total Wins, Feathers Collected) backed by
	OrderedDataStores. Writes are bounded to player join/leave and a periodic
	interval, never per-frame.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

local LeaderboardService = {}

local UPDATE_INTERVAL_SECONDS = 180

-- BestTime is stored as (CEILING - BestTime) so a larger stored score means a
-- FASTER (better) time. This lets GetSortedAsync(false, ...) (descending --
-- same direction used for Wins/Feathers) return the best times first instead
-- of needing an ascending-sorted read for this one board only.
local BEST_TIME_SCORE_CEILING = 999999

local winsStore = DataStoreService:GetOrderedDataStore("SearchForTheEgg_Leaderboard_Wins_v1")
local feathersStore = DataStoreService:GetOrderedDataStore("SearchForTheEgg_Leaderboard_Feathers_v1")
local bestTimeStore = DataStoreService:GetOrderedDataStore("SearchForTheEgg_Leaderboard_BestTime_v1")

local function safeSet(store: OrderedDataStore, key: string, value: number)
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(key, value)
		end)
		if not ok then
			warn(("LeaderboardService: failed to update %s: %s"):format(key, tostring(err)))
		end
	end)
end

function LeaderboardService.SubmitPlayer(player: Player)
	local stats = StatsService.GetStats(player)
	if not stats then
		return
	end

	local key = tostring(player.UserId)
	safeSet(winsStore, key, stats.Wins)
	safeSet(feathersStore, key, stats.TotalFeathersCollected)

	if stats.BestTime then
		local score = math.floor(BEST_TIME_SCORE_CEILING - stats.BestTime)
		if score > 0 then
			safeSet(bestTimeStore, key, score)
		end
	end
end

function LeaderboardService.GetTopWins(count: number?)
	local ok, pages = pcall(function()
		return winsStore:GetSortedAsync(false, count or 10)
	end)
	if not ok then
		return {}
	end
	return pages:GetCurrentPage()
end

function LeaderboardService.GetTopFeathers(count: number?)
	local ok, pages = pcall(function()
		return feathersStore:GetSortedAsync(false, count or 10)
	end)
	if not ok then
		return {}
	end
	return pages:GetCurrentPage()
end

-- Returns { key, value } entries where `value` is the actual best time in
-- seconds (converted back from the inverted stored score).
function LeaderboardService.GetTopBestTimes(count: number?)
	local ok, pages = pcall(function()
		return bestTimeStore:GetSortedAsync(false, count or 10)
	end)
	if not ok then
		return {}
	end

	local page = pages:GetCurrentPage()
	local results = {}
	for _, entry in page do
		table.insert(results, { key = entry.key, value = BEST_TIME_SCORE_CEILING - entry.value })
	end
	return results
end

DataService.ProfileLoaded:Connect(function(player)
	LeaderboardService.SubmitPlayer(player)
end)

DataService.ProfileReleasing:Connect(function(player)
	LeaderboardService.SubmitPlayer(player)
end)

task.spawn(function()
	while true do
		task.wait(UPDATE_INTERVAL_SECONDS)
		for _, player in Players:GetPlayers() do
			LeaderboardService.SubmitPlayer(player)
		end
	end
end)

return LeaderboardService
