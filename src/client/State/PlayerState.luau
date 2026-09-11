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
	OwnedClasses = {} :: { [string]: boolean },
	EquippedClass = nil :: string?,
	SecondClass = nil :: string?,
	SecondSlotUnlocked = false,
	OwnedTools = {} :: { [string]: boolean },
	ToolUpgradeLevels = {} :: { [string]: { [string]: number } },
	PermanentPerkLevels = {} :: { [string]: number },
	OwnedSkins = {} :: { [string]: boolean },
	EquippedSkins = {} :: { [string]: string },
	-- Persistent one-time Developer Product grants (Kind = "Entitlement" in
	-- MonetizationConfig): PitchforkPermanent, DynamitePermanent,
	-- VacuumPermanent, DronePermanent, FastRolls, ClassLuck2x,
	-- ExtraClassSlot, InfiniteBag, etc. From Core_ProfileUpdated's
	-- EntitlementSummary. NOT Game Pass ownership (see MonetizationController
	-- .ownsEntitlement vs .ownsGamePass).
	EntitlementSummary = {} :: { [string]: boolean },
}

PlayerState.Run = {
	InProgress = false,
	RunId = nil :: string?,
	CashCents = 0,
	BagCount = 0,
	BagCapacity = 25,
	BagLevel = 0,
	StartedAt = nil :: number?,
	ChapterId = nil :: string?,
	Difficulty = nil :: string?,
	HandHoldUnlocked = false,
	HandSpeed = 0.55,
	HandGrasp = 1,
	HandSpeedLevel = 0,
	HandGraspLevel = 0,
	CarryingEgg = false,
	VacuumHeat = 0,
	-- [toolName] = { Ownership: "Locked"|"RunOwned"|"PermanentOwned", AmountLevel, SpeedLevel, ExtraLevel }
	Tools = {} :: { [string]: any },
}

PlayerState.Party = {
	InParty = false,
	Members = {} :: { number },
	ChapterId = nil :: string?,
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

-- Tool ownership is run-scoped server state (PlayerState.Run.Tools, from the
-- Gameplay_RunState "PlayerState" message) -- never persistent profile data.
-- Hand is always available (the base tool, no ownership gate).
function PlayerState.isToolOwned(tool: string): boolean
	if tool == "Hand" then
		return true
	end
	local toolState = PlayerState.Run.Tools and PlayerState.Run.Tools[tool]
	return toolState ~= nil and toolState.Ownership ~= "Locked"
end

return PlayerState
