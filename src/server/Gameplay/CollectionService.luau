--[[
	Handles Gameplay_RequestCollect for the Hand and Pitchfork (Vacuum has its
	own centralized loop in VacuumService; Drone collects autonomously in
	DroneService). The client only ever sends {Tool, TargetPosition} -- amount,
	rarity rolls, and rewards are entirely server-computed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local RunConfig = require(GameplayConfig.RunConfig)
local HandConfig = require(GameplayConfig.HandConfig)
local PitchforkConfig = require(GameplayConfig.PitchforkConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local ToolService = require(script.Parent.ToolService)
local RewardRolls = require(script.Parent.RewardRolls)

local CollectionService = {}

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

-- A NaN/Infinity component would make every downstream `> rangeLimit`
-- comparison silently false (NaN/Inf comparisons never behave like a
-- normal number), bypassing the range check entirely. Never trust a
-- client-supplied Vector3 without this.
local function isFiniteVector3(v: Vector3): boolean
	local x, y, z = v.X, v.Y, v.Z
	return x == x and y == y and z == z and x ~= math.huge and x ~= -math.huge and y ~= math.huge and y ~= -math.huge and z ~= math.huge and z ~= -math.huge
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

local bagFullNoticeAt: { [number]: number } = {}
local function notifyBagFull(player: Player)
	local now = os.clock()
	if bagFullNoticeAt[player.UserId] and now - bagFullNoticeAt[player.UserId] < 4 then
		return
	end
	bagFullNoticeAt[player.UserId] = now
	RoundService.SendNotification(player, "Your bag is full! Go sell.", "Warning")
end

local function fireFxHit(player: Player, tool: string, position: Vector3, amount: number)
	RemotesLocator.Get("Gameplay_FX"):FireAllClients({
		Type = "CollectHit",
		UserId = player.UserId,
		Tool = tool,
		Position = position,
		Amount = amount,
	})
end

local function handToolStats(state: any)
	local interval = HandConfig.SPEED_LEVELS[state.HandSpeedLevel].IntervalSeconds
	local amount = RunPlayerStateService.EffectiveHandAmount(state)
	return interval, amount, 1
end

local function pitchforkToolStats(state: any)
	local tool = state.Tools.Pitchfork
	local interval = PitchforkConfig.SPEED_LEVELS[tool.SpeedLevel].IntervalSeconds
	local amount = PitchforkConfig.AMOUNT_LEVELS[tool.AmountLevel].Value
	if state.Modifiers and state.Modifiers.Forkmaster then
		amount = math.floor(amount * (1 + PitchforkConfig.FORKMASTER_YIELD_BONUS))
	end
	local depthMultiplier = PitchforkConfig.DIG_DEPTH_LEVELS[tool.ExtraLevel].Multiplier
	local searchRadius = math.max(1, math.floor(1 + (depthMultiplier - 1) * 2))
	return interval, amount, searchRadius
end

function CollectionService.RequestCollect(player: Player, toolName: string, targetPosition: Vector3)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return
	end

	local state = RunPlayerStateService.Get(player)
	if not state then
		return
	end

	local interval, baseAmount, searchRadius, rangeLimit
	if toolName == "Hand" then
		interval, baseAmount, searchRadius = handToolStats(state)
		rangeLimit = RunConfig.RANGE.COLLECTION
	elseif toolName == "Pitchfork" then
		if not ToolService.IsOwned(state, "Pitchfork") then
			return
		end
		interval, baseAmount, searchRadius = pitchforkToolStats(state)
		rangeLimit = RunConfig.RANGE.PITCHFORK
	else
		return
	end

	local now = os.clock()
	local lastCollect = state.LastCollectAt[toolName]
	if lastCollect and now - lastCollect < interval - RunConfig.COLLECTION_COOLDOWN_GRACE_SECONDS then
		return
	end

	local characterPosition = getCharacterPosition(player)
	if not characterPosition then
		return
	end
	if distance(characterPosition, targetPosition) > rangeLimit then
		return
	end
	if distance(characterPosition, run.Pile.Origin) > rangeLimit + run.Pile.GridRadius * run.Pile.ColumnSize then
		return
	end

	local capacity = RunPlayerStateService.EffectiveBagCapacity(state)
	if state.BagCount >= capacity then
		notifyBagFull(player)
		return
	end

	state.LastCollectAt[toolName] = now

	local removed = FeatherPileService.RemoveNear(run.Pile, targetPosition, baseAmount, searchRadius)
	if removed <= 0 then
		return
	end

	local normalCount, rainbowCount, diamondHits, alienTokenHits = RewardRolls.RollOutcomes(removed, state.Modifiers or {})

	local normalAdded, rainbowAdded = RunPlayerStateService.AddToBag(state, normalCount, rainbowCount)
	state.FeathersCollected += normalAdded + rainbowAdded

	RewardRolls.AwardRareFinds(player, diamondHits, alienTokenHits)

	if normalAdded + rainbowAdded < normalCount + rainbowCount then
		notifyBagFull(player)
	end

	fireFxHit(player, toolName, targetPosition, removed)
	RoundService.BroadcastPlayerState(player)
end

function CollectionService.Init()
	local remote = RemotesLocator.Get("Gameplay_RequestCollect")
	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" then
			return
		end
		local tool = payload.Tool
		local targetPosition = payload.TargetPosition
		if type(tool) ~= "string" or typeof(targetPosition) ~= "Vector3" then
			return
		end
		if not isFiniteVector3(targetPosition) then
			return
		end
		CollectionService.RequestCollect(player, tool, targetPosition)
	end)

	Players.PlayerRemoving:Connect(function(player)
		bagFullNoticeAt[player.UserId] = nil
	end)
end

return CollectionService
