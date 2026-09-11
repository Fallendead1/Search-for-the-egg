--!strict
-- Local mirror of the authoritative state the server pushes down
-- (Core_ProfileUpdated snapshots, Gameplay_RunState deltas). Every field
-- here is read-only from the client's perspective -- controllers render
-- from it, never compute gameplay results into it.

local Signal = require(script.Parent.Parent.Util.Signal)

local PlayerState = {}

PlayerState.Profile = {
	Gems = 0,
	AlienTokens = 0,
	TotalWins = 0,
	TotalPlaytime = 0,
	FeathersCollected = 0,
	TimeRecord = nil :: number?,
	EquippedClass = nil :: string?,
	SecondClass = nil :: string?,
	SecondSlotUnlocked = false,
	OwnedTools = {} :: { [string]: boolean },
	ToolUpgradeLevels = {} :: { [string]: { [string]: number } },
	PermanentPerkLevels = {} :: { [string]: number },
	OwnedSkins = {} :: { [string]: boolean },
	EquippedSkins = {} :: { [string]: string },
	BagLevel = 0,
	InfiniteBag = false,
	HoldUnlocked = false,
}

PlayerState.Run = {
	InProgress = false,
	Cash = 0,
	BagCount = 0,
	BagCapacity = 25,
	StartedAt = nil :: number?,
	Chapter = nil :: string?,
	Difficulty = nil :: string?,
	HandSpeed = 0.55,
	HandGrasp = 1,
	CarryingEgg = false,
	VacuumHeat = 0,
}

PlayerState.Party = {
	InParty = false,
	Members = {} :: { number },
	Chapter = nil :: string?,
	Difficulty = nil :: string?,
	Started = false,
}

PlayerState.ProfileChanged = Signal.new()
PlayerState.RunChanged = Signal.new()
PlayerState.PartyChanged = Signal.new()

function PlayerState.applyProfileSnapshot(snapshot: { [string]: any })
	for key, value in pairs(snapshot) do
		PlayerState.Profile[key] = value
	end
	PlayerState.ProfileChanged:Fire(PlayerState.Profile)
end

function PlayerState.applyRunState(state: { [string]: any })
	for key, value in pairs(state) do
		PlayerState.Run[key] = value
	end
	PlayerState.RunChanged:Fire(PlayerState.Run)
end

function PlayerState.applyPartyState(state: { [string]: any })
	for key, value in pairs(state) do
		PlayerState.Party[key] = value
	end
	PlayerState.PartyChanged:Fire(PlayerState.Party)
end

return PlayerState
