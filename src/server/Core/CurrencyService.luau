--[[
	Server-authoritative persistent currency mutations (Gems, AlienTokens).
	Cash and other run-scoped currency are NOT persistent and are owned by
	the Gameplay agent -- this service never touches them.

	Callers are responsible for calling DataService.PushProfileUpdated once
	after an action completes (possibly after several currency/stat/etc.
	mutations), to avoid firing Core_ProfileUpdated multiple times per action.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.MonetizationConfig)
local DataService = require(script.Parent.DataService)

local CurrencyService = {}

-- Explicit source policy for CurrencyService.Award -- callers must declare
-- whether an award is "Earned" (gameplay reward: completion, pile finds,
-- codes, alien chest opened with Tokens) or "Purchased" (paid for with real
-- money: developer product Gem packs, Robux-paid chest batches). Only
-- "Earned" Gems are eligible for the Gems2xPermanent multiplier -- doubling
-- a Robux purchase would mean players pay for 100 Gems and silently receive
-- 200, which is not what the game pass sells.
local CurrencySource = {
	Earned = "Earned",
	Purchased = "Purchased",
}
CurrencyService.Source = CurrencySource

local VALID_CURRENCIES = {
	Gems = true,
	AlienTokens = true,
}

local function getCurrencies(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	return profile.Currencies
end

function CurrencyService.Get(player: Player, currencyName: string): number
	if not VALID_CURRENCIES[currencyName] then
		return 0
	end
	local currencies = getCurrencies(player)
	if not currencies then
		return 0
	end
	return currencies[currencyName] or 0
end

function CurrencyService.CanAfford(player: Player, currencyName: string, amount: number): boolean
	if type(amount) ~= "number" or amount < 0 then
		return false
	end
	return CurrencyService.Get(player, currencyName) >= amount
end

function CurrencyService.TrySpend(player: Player, currencyName: string, amount: number, reason: string?): boolean
	if not VALID_CURRENCIES[currencyName] then
		warn(("CurrencyService.TrySpend: invalid currency %s"):format(tostring(currencyName)))
		return false
	end
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return false
	end

	local currencies = getCurrencies(player)
	if not currencies then
		return false
	end

	if currencies[currencyName] < amount then
		return false
	end

	currencies[currencyName] -= amount
	return true
end

-- Doubles Gems awards for players who own the Gems2xPermanent game pass.
-- Only applies to "Earned" awards -- see CurrencySource above. A "Purchased"
-- award (e.g. a 100/400 Gem developer product) is never doubled here.
local function applyGemsMultiplier(player: Player, currencyName: string, amount: number, source: string): number
	if currencyName ~= "Gems" then
		return amount
	end
	if source ~= CurrencySource.Earned then
		return amount
	end

	local gamePassId = MonetizationConfig.GamePasses.Gems2xPermanent.Id
	if gamePassId == 0 then
		return amount
	end

	local MonetizationService = require(script.Parent.MonetizationService)
	if MonetizationService.OwnsGamePass(player, gamePassId) then
		return amount * 2
	end

	return amount
end

-- `source` MUST be CurrencyService.Source.Earned or .Purchased. Defaults to
-- Purchased (never doubled) if omitted, so a caller that forgets to declare
-- a source fails safe instead of silently doubling an award.
function CurrencyService.Award(player: Player, currencyName: string, amount: number, reason: string?, source: string?): (boolean, number?)
	if not VALID_CURRENCIES[currencyName] then
		warn(("CurrencyService.Award: invalid currency %s"):format(tostring(currencyName)))
		return false
	end
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return false
	end

	source = source or CurrencySource.Purchased
	if source ~= CurrencySource.Earned and source ~= CurrencySource.Purchased then
		warn(("CurrencyService.Award: invalid source %s"):format(tostring(source)))
		return false
	end

	local currencies = getCurrencies(player)
	if not currencies then
		return false
	end

	local finalAmount = applyGemsMultiplier(player, currencyName, amount, source)
	currencies[currencyName] += finalAmount

	return true, finalAmount
end

return CurrencyService
