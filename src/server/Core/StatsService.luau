--[[
	Low-level persistent stat mutation helpers. Orchestration (rewards,
	pushing profile updates) lives in MetaProgressionService.
]]

local DataService = require(script.Parent.DataService)

local StatsService = {}

function StatsService.IncrementWins(player: Player, amount: number?)
	amount = amount or 1
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.Stats.Wins += amount :: number
end

-- Returns true if this run's time is a new (lower) BestTime.
function StatsService.ReportRunTime(player: Player, elapsedSeconds: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	if type(elapsedSeconds) ~= "number" or elapsedSeconds <= 0 then
		return false
	end

	if profile.Stats.BestTime == nil or elapsedSeconds < profile.Stats.BestTime then
		profile.Stats.BestTime = elapsedSeconds
		return true
	end

	return false
end

function StatsService.AddFeathersCollected(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.Stats.TotalFeathersCollected += amount
end

function StatsService.GetStats(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	return profile.Stats
end

return StatsService
