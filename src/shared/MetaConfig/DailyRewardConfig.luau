-- Daily login reward ladder. 8 days, then wraps back to Day 1 on the next
-- eligible claim. Every amount is Gems, awarded through the existing
-- CurrencyService (Source.Earned -- see DailyRewardService), so the
-- existing Gems2xPermanent policy applies to these the same as any other
-- earned Gems.

local DailyRewardConfig = {}

DailyRewardConfig.ClaimIntervalSeconds = 24 * 60 * 60

DailyRewardConfig.Days = {
	{ Day = 1, Gems = 25 },
	{ Day = 2, Gems = 50, Milestone = true },
	{ Day = 3, Gems = 25 },
	{ Day = 4, Gems = 35 },
	{ Day = 5, Gems = 75, Milestone = true },
	{ Day = 6, Gems = 40 },
	{ Day = 7, Gems = 50 },
	{ Day = 8, Gems = 100, Milestone = true, Premium = true },
}

DailyRewardConfig.TotalDays = #DailyRewardConfig.Days

return table.freeze(DailyRewardConfig)
