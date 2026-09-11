--!strict
-- Centralized SFX hooks. No copyrighted sound ids are invented here -- every
-- entry starts empty and simply no-ops until real, owned asset ids are
-- filled in (reuse existing SoundService content if the project ever adds
-- any). Other controllers should only ever call SoundController.play(name),
-- never build their own Sound instances.

local SoundService = game:GetService("SoundService")

local SoundController = {}

local SOUND_IDS: { [string]: string } = {
	Collect = "",
	Sell = "",
	Upgrade = "",
	Purchase = "",
	PitchforkSwing = "",
	DynamiteThrow = "",
	Explosion = "",
	Vacuum = "",
	Drone = "",
	RainbowFeather = "",
	Gem = "",
	EggDiscovery = "",
	EggPickup = "",
	Completion = "",
	ClassRoll = "",
	AlienChestOpen = "",
	UfoEvent = "",
	ButtonClick = "",
	Locked = "",
}

local muted = false
local pool: { [string]: Sound } = {}

local function getSound(name: string): Sound?
	local id = SOUND_IDS[name]
	if not id or id == "" then
		return nil
	end
	local sound = pool[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Parent = SoundService
		pool[name] = sound
	end
	return sound
end

function SoundController.play(name: string, volume: number?)
	if muted then
		return
	end
	local sound = getSound(name)
	if not sound then
		return
	end
	sound.Volume = volume or 0.6
	sound:Play()
end

function SoundController.setMuted(isMuted: boolean)
	muted = isMuted
	SoundService.Volume = isMuted and 0 or 1
end

function SoundController.isMuted(): boolean
	return muted
end

function SoundController.toggleMuted(): boolean
	SoundController.setMuted(not muted)
	return muted
end

function SoundController.init()
	-- No persisted preference source is owned by this client yet; default
	-- to unmuted. LobbyController wires the visible toggle button.
end

return SoundController
