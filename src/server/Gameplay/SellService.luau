--[[
	Sell station (chicken coop): reads the authoritative bag, empties it
	atomically, computes payout server-side, and credits run Cash. Golden
	Harvest and Core modifiers (SaleMultiplier/FeatherValueMultiplier) are
	applied here so every sell path (manual + Drone auto-sell) can reuse
	ComputeSaleCents.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local CoreLocator = require(script.Parent.CoreLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local MapAnchors = require(script.Parent.MapAnchors)

local SellService = {}

local sellingLock: { [number]: boolean } = {}

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

local function getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position
end

-- Shared by the manual sell remote and Drone auto-sell. Does not touch the
-- bag -- caller passes explicit counts (e.g. Drone cargo isn't the player's
-- bag) and this just prices them.
function SellService.ComputeSaleCents(run: any, state: any, normalCount: number, rainbowCount: number): number
	local baseCents = normalCount * RunConfig.FEATHER_VALUE_CENTS + rainbowCount * RunConfig.RAINBOW_FEATHER_VALUE_CENTS

	local modifiers = state.Modifiers or {}
	local multiplier = (modifiers.SaleMultiplier or 1) * (modifiers.FeatherValueMultiplier or 1)
	if run.GoldenHarvestActive then
		multiplier *= RunConfig.GOLDEN_HARVEST.SELL_MULTIPLIER
	end

	return math.floor(baseCents * multiplier + 0.5)
end

function SellService.RequestSell(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end

	if sellingLock[player.UserId] then
		return false, "SellInProgress"
	end
	sellingLock[player.UserId] = true

	local ok, resultOrErr = pcall(function()
		local state = RunPlayerStateService.Get(player)
		if not state then
			error("NoRunState")
		end

		local characterPosition = getCharacterPosition(player)
		if not characterPosition then
			error("NoCharacter")
		end
		local sellStationPosition = MapAnchors.GetSellStationPosition()
		if distance(characterPosition, sellStationPosition) > RunConfig.RANGE.SELL_STATION then
			error("OutOfRange")
		end

		if state.BagCount <= 0 then
			error("BagEmpty")
		end

		-- Atomic: pull the bag contents out before computing/paying so a
		-- concurrent collect can't be double-counted or lost.
		local normalCount, rainbowCount = RunPlayerStateService.ClearBag(state)
		local totalSold = normalCount + rainbowCount
		local saleCents = SellService.ComputeSaleCents(run, state, normalCount, rainbowCount)
		RunPlayerStateService.AddCash(state, saleCents)

		RoundService.SendNotification(
			player,
			("Sold %d feathers for $%.2f!"):format(totalSold, saleCents / 100),
			"Success"
		)
		RoundService.BroadcastPlayerState(player)

		return true
	end)

	sellingLock[player.UserId] = nil

	if not ok then
		return false, resultOrErr
	end
	return resultOrErr
end

function SellService.Init()
	local remote = RemotesLocator.Get("Gameplay_RequestSell")
	remote.OnServerEvent:Connect(function(player: Player)
		SellService.RequestSell(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		sellingLock[player.UserId] = nil
	end)
end

return SellService
