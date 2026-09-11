--[[
	"DO NOT PRESS!" secret red button easter egg. No dedicated remote exists
	for this in the contract, and it doesn't need one: like the existing
	EggSpawner.server.luau pattern already in this repo, it's driven by a
	server-side .Touched connection on the tagged button part, so there's no
	client-trusted input at all. One activation per run, no economy/reward
	attached (flavor only), and it cleans itself up on round end.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local MapAnchors = require(script.Parent.MapAnchors)

local UFOSecretService = {}

local buttonConnection: RBXScriptConnection? = nil

local function tryActivate(run: any, player: Player?)
	if not run or run.UFOButtonUsed then
		return
	end
	run.UFOButtonUsed = true

	local chickens = MapAnchors.GetChickens()
	local target = chickens[math.random(1, math.max(1, #chickens))]

	local fx = RemotesLocator.Get("Gameplay_FX")
	fx:FireAllClients({
		Type = "UFOSecretTriggered",
		TriggeredByUserId = player and player.UserId or nil,
		TargetInstancePath = target and target:GetFullName() or nil,
		BeamDurationSeconds = RunConfig.UFO_SECRET.BEAM_DURATION_SECONDS,
		FlightDurationSeconds = RunConfig.UFO_SECRET.FLIGHT_DURATION_SECONDS,
	})

	for _, userId in ipairs(run.Members) do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			RoundService.SendNotification(member, "A UFO has abducted a chicken!", "Info")
		end
	end

	if target then
		local totalDelay = RunConfig.UFO_SECRET.BEAM_DURATION_SECONDS + RunConfig.UFO_SECRET.FLIGHT_DURATION_SECONDS
		Debris:AddItem(target, totalDelay)
	end
end

local function onButtonTouched(hit: BasePart)
	local run = RoundService.GetActiveRun()
	if not RoundService.IsActive(run) then
		return
	end
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not table.find(run.Members, player.UserId) then
		return
	end
	tryActivate(run, player)
end

function UFOSecretService.CleanupRun(_run: any)
	-- run.UFOButtonUsed lives on the run table itself, which RoundService
	-- discards after EndRun; nothing else to reset here.
end

function UFOSecretService.Init()
	RoundService.OnRunEnded(UFOSecretService.CleanupRun)

	local button = MapAnchors.GetRedButtonPart()
	if button then
		buttonConnection = button.Touched:Connect(onButtonTouched)
	end
end

return UFOSecretService
