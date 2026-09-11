--[[
	Dynamite: throw -> fuse -> explosion -> area pile clear -> optional Lucky
	Blast conversion to Rainbow Feathers. Dynamite itself never grants a
	direct reward from cleared material; only a successful Lucky Blast
	converts a fraction of the cleared units into Rainbow Feathers credited to
	the thrower's bag (see the DynamiteConfig header for why -- "expose
	buried material" reads as a utility/exposure tool, not free income).

	Demolitionist's mini-charge perk REPLACES the single blast with 3 smaller
	ones (not in addition to it) when its roll succeeds, and the throw
	cooldown is set at throw time (not at explosion time) so mini-charges
	can't be used to bypass or refresh cooldown.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = ReplicatedStorage.SearchForTheEgg.GameplayConfig
local RunConfig = require(GameplayConfig.RunConfig)
local DynamiteConfig = require(GameplayConfig.DynamiteConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local RoundService = require(script.Parent.RoundService)
local RunPlayerStateService = require(script.Parent.RunPlayerStateService)
local FeatherPileService = require(script.Parent.FeatherPileService)
local ToolService = require(script.Parent.ToolService)

local DynamiteService = {}

local COOLDOWN_KEY = "DynamiteThrow"

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

-- A NaN/Infinity component would make every downstream `> rangeLimit`
-- comparison silently false, bypassing the range check entirely. Never
-- trust a client-supplied Vector3 without this.
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

local function fireExplosionFx(position: Vector3, radius: number)
	RemotesLocator.Get("Gameplay_FX"):FireAllClients({
		Type = "DynamiteExplosion",
		Position = position,
		Radius = radius,
	})
end

local function resolveBlast(run: any, player: Player, state: any, position: Vector3, radius: number, luckyBlastChance: number)
	local totalCleared = FeatherPileService.AreaRemove(run.Pile, position, radius)
	fireExplosionFx(position, radius)

	if totalCleared <= 0 then
		return
	end

	if math.random() < luckyBlastChance then
		local rainbowCount = math.floor(totalCleared * DynamiteConfig.LUCKY_BLAST_CONVERSION_FRACTION)
		if rainbowCount > 0 then
			local _, rainbowAdded = RunPlayerStateService.AddToBag(state, 0, rainbowCount)
			if rainbowAdded > 0 then
				RoundService.SendNotification(
					player,
					("Lucky Blast! +%d Rainbow Feathers"):format(rainbowAdded),
					"Success"
				)
				RoundService.BroadcastPlayerState(player)
			end
		end
	end
end

local function handleThrow(player: Player, payload: any)
	local run = RoundService.GetRunForPlayer(player)
	if not RoundService.IsActive(run) then
		return
	end

	local targetPosition = payload.TargetPosition
	if typeof(targetPosition) ~= "Vector3" then
		return
	end
	if not isFiniteVector3(targetPosition) then
		return
	end

	local state = RunPlayerStateService.Get(player)
	if not state or not ToolService.IsOwned(state, "Dynamite") then
		return
	end

	local characterPosition = getCharacterPosition(player)
	if not characterPosition then
		return
	end
	if distance(characterPosition, targetPosition) > RunConfig.RANGE.DYNAMITE_THROW then
		return
	end

	local tool = state.Tools.Dynamite
	local cooldownSeconds = DynamiteConfig.SPEED_LEVELS[tool.SpeedLevel].CooldownSeconds
	local now = os.clock()
	local lastThrow = state.LastCollectAt[COOLDOWN_KEY]
	if lastThrow and now - lastThrow < cooldownSeconds then
		return
	end
	state.LastCollectAt[COOLDOWN_KEY] = now

	local modifiers = state.Modifiers or {}
	local radius = DynamiteConfig.POWER_LEVELS[tool.AmountLevel].Radius
	if modifiers.Demolitionist then
		radius *= 1 + DynamiteConfig.DEMOLITIONIST_RADIUS_BONUS
	end
	local luckyBlastChance = DynamiteConfig.LUCKY_BLAST_LEVELS[tool.ExtraLevel].Chance

	RemotesLocator.Get("Gameplay_FX"):FireAllClients({
		Type = "DynamiteThrown",
		UserId = player.UserId,
		Position = targetPosition,
		FuseSeconds = DynamiteConfig.FUSE_SECONDS,
	})

	task.delay(DynamiteConfig.FUSE_SECONDS, function()
		if not RoundService.IsActive(run) then
			return
		end

		local splitRoll = modifiers.Demolitionist and math.random() < DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_CHANCE
		if splitRoll then
			local miniRadius = radius * DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_RADIUS_MULTIPLIER
			for _ = 1, DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_COUNT do
				local scatter = DynamiteConfig.DEMOLITIONIST_MINI_CHARGE_SCATTER_STUDS
				local offset = Vector3.new(
					math.random(-scatter, scatter),
					0,
					math.random(-scatter, scatter)
				)
				resolveBlast(run, player, state, targetPosition + offset, miniRadius, luckyBlastChance)
			end
		else
			resolveBlast(run, player, state, targetPosition, radius, luckyBlastChance)
		end
	end)
end

function DynamiteService.Init()
	ToolService.RegisterActionHandler("Dynamite", "Throw", handleThrow)
end

return DynamiteService
