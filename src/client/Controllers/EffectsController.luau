--!strict
-- Presentation dispatch for Gameplay_FX. Gameplay/world systems (Agent 3)
-- decide when something happens; this controller only reacts visually and
-- never mutates gameplay state (no pile removal, no reward selection).

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

local function playPointFlash(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Position = position
	part.Parent = Workspace

	local tween = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(6, 6, 6),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		part:Destroy()
	end)
end

local function onExplosion(payload: any)
	SoundController.play("Explosion")
	local position = payload and payload.Position
	if typeof(position) == "Vector3" then
		playPointFlash(position, Color3.fromRGB(255, 150, 60))
	end
end

local function onRainbowFeather(payload: any)
	SoundController.play("RainbowFeather")
	local position = payload and payload.Position
	if typeof(position) == "Vector3" then
		playPointFlash(position, Color3.fromRGB(200, 120, 255))
	end
	NotificationController.push("Rainbow Feather found!", "Success")
end

local function onGemPickup(payload: any)
	SoundController.play("Gem")
	local position = payload and payload.Position
	if typeof(position) == "Vector3" then
		playPointFlash(position, Color3.fromRGB(90, 220, 210))
	end
end

local function onEggDiscovery()
	SoundController.play("EggDiscovery")
end

local function onEggPickup()
	SoundController.play("EggPickup")
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

local function onUfoEvent(payload: any)
	local phase = payload and payload.Phase
	SoundController.play("UfoEvent")
	if phase == "Arrival" or phase == nil then
		CameraController.playUfoEmphasis()
		NotificationController.push("A UFO has appeared!", "Info")
	elseif phase == "Departure" then
		NotificationController.push("The UFO has departed.", "Info")
	end
end

local HANDLERS: { [string]: (any) -> () } = {
	Explosion = onExplosion,
	RainbowFeather = onRainbowFeather,
	GemPickup = onGemPickup,
	DiamondPickup = onGemPickup,
	EggDiscovery = onEggDiscovery,
	EggPickup = onEggPickup,
	GoldenHarvestStart = function()
		setGoldenHarvest(true)
	end,
	GoldenHarvestEnd = function()
		setGoldenHarvest(false)
	end,
	UfoEvent = onUfoEvent,
}

function EffectsController.init()
	Remotes.onClientEvent("Gameplay_FX", function(payload: any)
		if type(payload) ~= "table" or type(payload.Kind) ~= "string" then
			return
		end
		local handler = HANDLERS[payload.Kind]
		if handler then
			handler(payload)
		end
	end)
end

return EffectsController
