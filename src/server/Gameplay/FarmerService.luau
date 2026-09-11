--[[
	Farmer NPC: final Egg turn-in trigger. Position discovered via the
	SFTE_Farmer CollectionService tag (see MapAnchors) so the Studio-built
	Farmer model doesn't need to be remapped into Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local EggService = require(script.Parent.EggService)
local MapAnchors = require(script.Parent.MapAnchors)

local FarmerService = {}

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

function FarmerService.RequestTurnIn(player: Player)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return false, "RoundNotActive"
	end
	if run.EggState ~= "Carried" or run.EggCarrierUserId ~= player.UserId then
		return false, "NotCarrier"
	end

	local characterPosition = getCharacterPosition(player)
	if not characterPosition then
		return false, "NoCharacter"
	end

	local farmerPosition = MapAnchors.GetFarmerPosition()
	if distance(characterPosition, farmerPosition) > RunConfig.RANGE.FARMER_TURN_IN then
		return false, "OutOfRange"
	end

	if not RoundService.TryBeginCompletion(run) then
		return false, "AlreadyCompleting"
	end

	EggService.MarkTurnedIn(run)
	RoundService.FinalizeCompletion(run, player.UserId)

	return true
end

function FarmerService.Init()
	local remote = RemotesLocator.Get("Gameplay_RequestEggTurnIn")
	remote.OnServerEvent:Connect(function(player: Player)
		FarmerService.RequestTurnIn(player)
	end)
end

return FarmerService
