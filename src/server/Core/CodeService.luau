--[[
	Backend-only code redemption. No public launch codes are known yet -- add
	entries to CODES as they are announced.
]]

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local CodeService = {}

-- Example entry once a real code is announced:
-- LAUNCH = { Gems = 50, AlienTokens = 0 },
local CODES = {}

local function normalize(code: any): string?
	if type(code) ~= "string" then
		return nil
	end
	code = code:gsub("%s+", ""):upper()
	if #code == 0 or #code > 32 then
		return nil
	end
	return code
end

function CodeService.RedeemCode(player: Player, rawCode: any): (boolean, any)
	if not DataService.IsLoaded(player) then
		return false, "ProfileNotLoaded"
	end

	local code = normalize(rawCode)
	if not code then
		return false, "InvalidCode"
	end

	local reward = CODES[code]
	if not reward then
		return false, "UnknownCode"
	end

	local profile = DataService.GetProfile(player)
	if profile.CodesRedeemed[code] then
		return false, "AlreadyRedeemed"
	end

	profile.CodesRedeemed[code] = os.time()

	if reward.Gems and reward.Gems > 0 then
		CurrencyService.Award(player, "Gems", reward.Gems, "Code:" .. code, CurrencyService.Source.Earned)
	end
	if reward.AlienTokens and reward.AlienTokens > 0 then
		CurrencyService.Award(player, "AlienTokens", reward.AlienTokens, "Code:" .. code, CurrencyService.Source.Earned)
	end

	DataService.PushProfileUpdated(player)

	return true, { Code = code, Reward = reward }
end

return CodeService
