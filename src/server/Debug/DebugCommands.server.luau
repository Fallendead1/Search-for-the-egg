--[[
	STUDIO-ONLY test acceleration commands. This entire script is a no-op the
	instant RunService:IsStudio() is false -- it creates no remotes, connects
	no events, and is completely unreachable from a published/live server, so
	there is no debug surface for a live player to exploit. Everything it
	does still goes through the real, server-authoritative services (Currency
	Service, RunPlayerStateService, FeatherPileService, EggService) -- it
	never mutates client-trusted state directly.

	Usage: type a command into the in-game chat (Player.Chatted still fires
	even with the newer TextChatService chat UI) while testing solo or with a
	teammate in Studio:

		/debugcash <dollars>      Add Cash to your CURRENT run (e.g. /debugcash 20)
		/debuggems <amount>       Add Gems to your persistent profile
		/debugtokens <amount>     Add Alien Tokens to your persistent profile
		/debugexposeegg           Instantly exposes the Egg in your current run
		/debugclearpile           Clears a huge radius of your run's pile (also
		                          exposes the Egg if it's inside that radius)
		/debughelp                Lists these commands in the Output window

	All amounts are added via the real Core services (CurrencyService.Award
	with Source = Purchased, so debug grants never trigger the Gems2x perk
	and can't be mistaken for a real gameplay reward in analytics/telemetry),
	so persistence, profile snapshots, and run-state broadcasts all work
	exactly as they would for a real purchase/pickup -- this is a shortcut to
	reach a state, not a parallel/fake implementation of one.
]]

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = ServerScriptService.SearchForTheEgg.Core
local Gameplay = ServerScriptService.SearchForTheEgg.Gameplay

local CurrencyService = require(Core.CurrencyService)
local DataService = require(Core.DataService)
local RunPlayerStateService = require(Gameplay.RunPlayerStateService)
local RoundService = require(Gameplay.RoundService)
local FeatherPileService = require(Gameplay.FeatherPileService)
local EggService = require(Gameplay.EggService)

local HELP_LINES = {
	"[DEBUG] /debugcash <dollars> -- add Cash to your current run",
	"[DEBUG] /debuggems <amount> -- add Gems to your profile",
	"[DEBUG] /debugtokens <amount> -- add Alien Tokens to your profile",
	"[DEBUG] /debugexposeegg -- instantly expose your run's Egg",
	"[DEBUG] /debugclearpile -- clear a huge radius of your run's pile",
	"[DEBUG] /debughelp -- list these commands",
}

local function notify(player: Player, message: string)
	RoundService.SendNotification(player, message, "Info")
	print(("[DebugCommands] %s: %s"):format(player.Name, message))
end

local function handleGiveCash(player: Player, argument: string?)
	local dollars = tonumber(argument)
	if not dollars or dollars <= 0 then
		notify(player, "Usage: /debugcash <dollars, e.g. 20>")
		return
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		notify(player, "No active run -- join/start a Chapter 1 run first.")
		return
	end

	local cents = math.floor(dollars * 100 + 0.5)
	RunPlayerStateService.AddCash(state, cents)
	RoundService.BroadcastPlayerState(player)
	notify(player, ("+$%.2f debug Cash added to your run."):format(cents / 100))
end

local function handleGiveCurrency(player: Player, currencyName: string, argument: string?)
	local amount = tonumber(argument)
	if not amount or amount <= 0 or amount ~= math.floor(amount) then
		notify(player, ("Usage: /debug%s <whole number amount>"):format(currencyName:lower()))
		return
	end

	if not DataService.IsLoaded(player) then
		notify(player, "Profile not loaded yet -- try again in a moment.")
		return
	end

	local ok = CurrencyService.Award(player, currencyName, amount, "DebugGrant", CurrencyService.Source.Purchased)
	if not ok then
		notify(player, ("Failed to grant %s -- check server Output."):format(currencyName))
		return
	end

	DataService.PushProfileUpdated(player)
	notify(player, ("+%d %s added to your profile."):format(amount, currencyName))
end

local function handleExposeEgg(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		notify(player, "No active run.")
		return
	end
	if run.EggState ~= "Buried" then
		notify(player, ("Egg is already '%s', nothing to expose."):format(run.EggState))
		return
	end
	EggService.HandleColumnExposed(run)
	notify(player, "Egg forcibly exposed.")
end

local function handleClearPile(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		notify(player, "No active run.")
		return
	end
	local pile = run.Pile
	if not pile then
		notify(player, "Run has no pile yet.")
		return
	end

	local hugeRadius = (pile.GridRadius + 1) * pile.ColumnSize
	local cleared = FeatherPileService.AreaRemove(pile, pile.Origin, hugeRadius)
	notify(player, ("Cleared %d Feather units from the pile."):format(cleared))
end

local COMMANDS: { [string]: (player: Player, argument: string?) -> () } = {
	["/debugcash"] = handleGiveCash,
	["/debuggems"] = function(player, argument)
		handleGiveCurrency(player, "Gems", argument)
	end,
	["/debugtokens"] = function(player, argument)
		handleGiveCurrency(player, "AlienTokens", argument)
	end,
	["/debugexposeegg"] = function(player, _argument)
		handleExposeEgg(player)
	end,
	["/debugclearpile"] = function(player, _argument)
		handleClearPile(player)
	end,
	["/debughelp"] = function(player, _argument)
		for _, line in ipairs(HELP_LINES) do
			print(line)
		end
		notify(player, "Command list printed to server Output.")
	end,
}

local function onChatted(player: Player, message: string)
	local commandWord, argument = message:match("^(%S+)%s*(.*)$")
	if not commandWord then
		return
	end
	local handler = COMMANDS[commandWord:lower()]
	if not handler then
		return
	end
	handler(player, argument ~= "" and argument or nil)
end

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		onChatted(player, message)
	end)
	print(("[DebugCommands] Studio debug commands active for %s -- type /debughelp in chat."):format(player.Name))
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message: string)
		onChatted(player, message)
	end)
end

print("[DebugCommands] Studio-only test commands loaded (never runs on a published server).")
