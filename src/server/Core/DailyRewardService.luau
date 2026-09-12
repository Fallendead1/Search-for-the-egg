--[[
	Server-authoritative Daily Reward claims. The client never tells this
	service which day it's claiming, how many Gems to receive, or whether a
	reward is unlocked -- GetStatus is the only thing exposed for display,
	and Claim re-derives everything itself from profile.DailyReward
	(CurrentDay, LastClaimAt) and DailyRewardConfig.

	One claim every ClaimIntervalSeconds (24h), using os.time() (real wall
	clock, not os.clock()) so eligibility survives a server restart/rejoin.
	A missed day never resets CurrentDay -- it only advances on a successful
	claim, and wraps from 8 back to 1.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.DailyRewardConfig)

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local DailyRewardService = {}

-- Per-player claim-in-progress guard: without this, two near-simultaneous
-- Core_RequestClaimDailyReward fires (double-click, retried dropped ack)
-- could both pass the eligibility check before either advances CurrentDay.
local claimLock: { [number]: boolean } = {}

local function dayConfig(day: number)
	return DailyRewardConfig.Days[day] or DailyRewardConfig.Days[1]
end

-- { Day, Gems, NextClaimAt, CanClaim } -- everything the client needs to
-- render the 8-card grid and its own countdown, without being trusted for
-- the actual claim.
function DailyRewardService.GetStatus(player: Player)
	if not DataService.IsLoaded(player) then
		return nil
	end
	local profile = DataService.GetProfile(player)
	local dailyReward = profile.DailyReward

	local nextClaimAt = 0
	if dailyReward.LastClaimAt then
		nextClaimAt = dailyReward.LastClaimAt + DailyRewardConfig.ClaimIntervalSeconds
	end
	local canClaim = os.time() >= nextClaimAt

	return {
		CurrentDay = dailyReward.CurrentDay,
		NextClaimAt = nextClaimAt,
		CanClaim = canClaim,
	}
end

function DailyRewardService.Claim(player: Player): (boolean, any)
	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end
	if claimLock[player.UserId] then
		return false, "ClaimInProgress"
	end
	claimLock[player.UserId] = true

	local ok, resultOrErr = pcall(function()
		local profile = DataService.GetProfile(player)
		local dailyReward = profile.DailyReward

		local nextClaimAt = dailyReward.LastClaimAt and (dailyReward.LastClaimAt + DailyRewardConfig.ClaimIntervalSeconds) or 0
		if os.time() < nextClaimAt then
			error("NotYetEligible")
		end

		local day = dailyReward.CurrentDay
		local reward = dayConfig(day)

		local awarded, finalAmount = CurrencyService.Award(player, "Gems", reward.Gems, "DailyReward:Day" .. tostring(day), CurrencyService.Source.Earned)
		if not awarded then
			error("AwardFailed")
		end

		dailyReward.LastClaimAt = os.time()
		dailyReward.CurrentDay = (day % DailyRewardConfig.TotalDays) + 1

		DataService.PushProfileUpdated(player)

		return { Day = day, GemsAwarded = finalAmount }
	end)

	claimLock[player.UserId] = nil

	if not ok then
		return false, resultOrErr
	end
	return true, resultOrErr
end

game.Players.PlayerRemoving:Connect(function(player)
	claimLock[player.UserId] = nil
end)

return DailyRewardService
