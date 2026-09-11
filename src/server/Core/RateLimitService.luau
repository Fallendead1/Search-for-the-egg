--[[
	Generic per-player, per-action remote rate limiter. This is a spam floor,
	not the real gameplay cooldown -- e.g. ClassRoll's real cooldown (with
	Fast Rolls entitlement support) lives in ClassService; this just stops a
	client from flooding the remote faster than any legitimate cooldown.
]]

local Players = game:GetService("Players")

local RateLimitService = {}

local buckets = {} :: { [Player]: { [string]: number } }

local DEFAULT_COOLDOWNS = {
	ClassRoll = 0.2,
	BuyPermanentPerk = 0.25,
	OpenAlienChest = 0.5,
	SelectSkin = 0.25,
	RedeemCode = 1,
	EquipClass = 0.25,
	ProfileSnapshot = 0.5,
	RequestLeaderboard = 2,
}

function RateLimitService.CheckAndStamp(player: Player, action: string, cooldownOverride: number?): boolean
	local cooldown = cooldownOverride or DEFAULT_COOLDOWNS[action] or 0.25

	local playerBucket = buckets[player]
	if not playerBucket then
		playerBucket = {}
		buckets[player] = playerBucket
	end

	local now = os.clock()
	local last = playerBucket[action]
	if last and (now - last) < cooldown then
		return false
	end

	playerBucket[action] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimitService
