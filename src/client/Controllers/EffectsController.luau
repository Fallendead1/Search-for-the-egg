--!strict
-- Presentation dispatch for Gameplay_FX. Gameplay/world systems (Agent 3)
-- decide when something happens; this controller only reacts visually and
-- never mutates gameplay state (no pile removal, no reward selection).
--
-- Dispatches on payload.Type, matching the server's actual Gameplay_FX
-- senders exactly (CollectionService, DynamiteService, DroneService,
-- RoundService, UFOSecretService -- see each for its payload shape).
-- PileSnapshot/PileColumnsUpdated are handled by PileController, not here.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(script.Parent.Parent.Util.Signal)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)
local NotificationController = require(script.Parent.NotificationController)

local EffectsController = {}

EffectsController.GoldenHarvestChanged = Signal.new() :: Signal.Signal

local goldenHarvestHighlight: Highlight? = nil

local function playPointFlash(position: Vector3, color: Color3, startSize: number, endSize: number)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(startSize, startSize, startSize)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Position = position
	part.Parent = Workspace

	local tween = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(endSize, endSize, endSize),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		part:Destroy()
	end)
end

local function onCollectHit(payload: any)
	SoundController.play("Collect", 0.3)
	if typeof(payload.Position) == "Vector3" then
		playPointFlash(payload.Position, Color3.fromRGB(235, 225, 200), 0.6, 2)
	end
end

local function onDynamiteExplosion(payload: any)
	SoundController.play("Explosion")
	if typeof(payload.Position) == "Vector3" then
		local radius = typeof(payload.Radius) == "number" and payload.Radius or 3
		playPointFlash(payload.Position, Color3.fromRGB(255, 150, 60), 1, radius * 2)
	end
end

local function onDynamiteThrown(_payload: any)
	SoundController.play("DynamiteThrow", 0.5)
end

local function setGoldenHarvest(active: boolean)
	local character = game.Players.LocalPlayer.Character
	if not character then
		return
	end

	if active then
		if goldenHarvestHighlight then
			return
		end
		local highlight = Instance.new("Highlight")
		highlight.Name = "GoldenHarvest"
		highlight.FillColor = Color3.fromRGB(255, 215, 64)
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = Color3.fromRGB(255, 235, 150)
		highlight.Parent = character
		goldenHarvestHighlight = highlight
		NotificationController.push("Golden Harvest active!", "Success")
	else
		if goldenHarvestHighlight then
			goldenHarvestHighlight:Destroy()
			goldenHarvestHighlight = nil
		end
	end
	EffectsController.GoldenHarvestChanged:Fire(active)
end

local function onGoldenHarvest(payload: any)
	setGoldenHarvest(payload.Active == true)
end

local function onDroneState(payload: any)
	if payload.Phase == "FlyToPile" or payload.Phase == "FlyToSell" then
		SoundController.play("Drone", 0.25)
	end
end

local function onUfoSecretTriggered(_payload: any)
	SoundController.play("UfoEvent")
	CameraController.playUfoEmphasis()
	NotificationController.push("A UFO has abducted a chicken!", "Info")
end

local HANDLERS: { [string]: (any) -> () } = {
	CollectHit = onCollectHit,
	DynamiteExplosion = onDynamiteExplosion,
	DynamiteThrown = onDynamiteThrown,
	GoldenHarvest = onGoldenHarvest,
	DroneState = onDroneState,
	UFOSecretTriggered = onUfoSecretTriggered,
}

function EffectsController.init()
	Remotes.onClientEvent("Gameplay_FX", function(payload: any)
		if type(payload) ~= "table" or type(payload.Type) ~= "string" then
			return
		end
		local handler = HANDLERS[payload.Type]
		if handler then
			handler(payload)
		end
	end)
end

return EffectsController
