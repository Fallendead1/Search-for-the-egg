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
-- Applies uniformly to every Gems award (earned or purchased) for a simple,
-- predictable "every Gems credit is doubled" mental model.
local function applyGemsMultiplier(player: Player, currencyName: string, amount: number): number
	if currencyName ~= "Gems" then
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

function CurrencyService.Award(player: Player, currencyName: string, amount: number, reason: string?): (boolean, number?)
	if not VALID_CURRENCIES[currencyName] then
		warn(("CurrencyService.Award: invalid currency %s"):format(tostring(currencyName)))
		return false
	end
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return false
	end

	local currencies = getCurrencies(player)
	if not currencies then
		return false
	end

	local finalAmount = applyGemsMultiplier(player, currencyName, amount)
	currencies[currencyName] += finalAmount

	return true, finalAmount
end

return CurrencyService
