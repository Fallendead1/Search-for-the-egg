--[[
	Lobby leaderboards (Fastest Time, Total Wins, Feathers Collected) backed
	by OrderedDataStores. Writes are bounded to player join/leave and a
	periodic interval, never per-frame or per-request.

	Reads are cached and refreshed on the same periodic interval -- a client
	requesting the leaderboard (Core_RequestLeaderboard) always gets the
	cached snapshot instantly, never a live GetSortedAsync call, so nothing
	a client does can spam OrderedDataStore reads.

	Studio fallback: OrderedDataStores don't work in Studio unless "Enable
	Studio Access to API Services" is on, and even then a fresh Studio
	DataStore starts empty. GetBoards() falls back to ranking the players
	CURRENTLY on this server (from their already-loaded, authoritative
	StatsService data) whenever the global cache is empty, so the Lobby
	leaderboard is still testable/meaningful in Studio without any extra
	setup, while a live published server (many players, DataStore access
	on by default) uses the real cross-server data once the cache warms up.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

local LeaderboardService = {}

local UPDATE_INTERVAL_SECONDS = 180
local TOP_COUNT = 10

-- BestTime is stored as (CEILING - BestTime) so a larger stored score means a
-- FASTER (better) time. This lets GetSortedAsync(false, ...) (descending --
-- same direction used for Wins/Feathers) return the best times first instead
-- of needing an ascending-sorted read for this one board only.
local BEST_TIME_SCORE_CEILING = 999999

local winsStore = DataStoreService:GetOrderedDataStore("SearchForTheEgg_Leaderboard_Wins_v1")
local feathersStore = DataStoreService:GetOrderedDataStore("SearchForTheEgg_Leaderboard_Feathers_v1")
local bestTimeStore = DataStoreService:GetOrderedDataStore("SearchForTheEgg_Leaderboard_BestTime_v1")

-- Cached snapshot ({ {UserId, Value}, ... }, already sorted best-first) --
-- what Core_LeaderboardResult actually sends. Refreshed by refreshCache().
local cache = {
	Wins = {} :: { { UserId: number, Value: number } },
	Feathers = {} :: { { UserId: number, Value: number } },
	BestTime = {} :: { { UserId: number, Value: number } },
}

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

local function readSorted(store: OrderedDataStore, ascending: boolean, count: number)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(ascending, count)
	end)
	if not ok then
		return nil
	end
	local ok2, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 then
		return nil
	end
	return page
end

-- Ranks currently-connected players by their own live (already loaded,
-- authoritative) StatsService data. Only used when the global cache for a
-- board is empty (fresh Studio DataStore, or before the first refresh).
local function localFallbackBoard(statField: string, transform: ((number) -> number)?, ascendingIsBetter: boolean?)
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = StatsService.GetStats(player)
		local raw = stats and (stats :: any)[statField]
		if type(raw) == "number" then
			table.insert(rows, { UserId = player.UserId, Value = transform and transform(raw) or raw })
		end
	end
	table.sort(rows, function(a, b)
		if ascendingIsBetter then
			return a.Value < b.Value
		end
		return a.Value > b.Value
	end)
	return rows
end

local function refreshCache()
	local winsPage = readSorted(winsStore, false, TOP_COUNT)
	if winsPage and #winsPage > 0 then
		local rows = {}
		for _, entry in ipairs(winsPage) do
			table.insert(rows, { UserId = tonumber(entry.key) or 0, Value = entry.value })
		end
		cache.Wins = rows
	else
		cache.Wins = localFallbackBoard("Wins")
	end

	local feathersPage = readSorted(feathersStore, false, TOP_COUNT)
	if feathersPage and #feathersPage > 0 then
		local rows = {}
		for _, entry in ipairs(feathersPage) do
			table.insert(rows, { UserId = tonumber(entry.key) or 0, Value = entry.value })
		end
		cache.Feathers = rows
	else
		cache.Feathers = localFallbackBoard("TotalFeathersCollected")
	end

	local bestTimePage = readSorted(bestTimeStore, false, TOP_COUNT)
	if bestTimePage and #bestTimePage > 0 then
		local rows = {}
		for _, entry in ipairs(bestTimePage) do
			table.insert(rows, { UserId = tonumber(entry.key) or 0, Value = BEST_TIME_SCORE_CEILING - entry.value })
		end
		cache.BestTime = rows
	else
		-- Lower BestTime is better; ascending sort, and only players who
		-- actually have a recorded BestTime (nil is excluded by localFallbackBoard's
		-- `type(raw) == "number"` check).
		cache.BestTime = localFallbackBoard("BestTime", nil, true)
	end
end

-- Instant -- returns the cached snapshot, never touches a DataStore.
function LeaderboardService.GetBoards()
	return cache
end

function LeaderboardService.Init()
	refreshCache()

	DataService.ProfileLoaded:Connect(function(player)
		LeaderboardService.SubmitPlayer(player)
	end)

	DataService.ProfileReleasing:Connect(function(player)
		LeaderboardService.SubmitPlayer(player)
	end)

	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				LeaderboardService.SubmitPlayer(player)
			end
			-- Give the SetAsync calls above a moment to land before reading
			-- back -- best-effort; the next periodic refresh will still
			-- eventually reflect them even if this one is a beat early.
			task.wait(2)
			refreshCache()
		end
	end)
end

return LeaderboardService
