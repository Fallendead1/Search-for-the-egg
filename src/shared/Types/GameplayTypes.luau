-- Shared type documentation for the gameplay systems. This module has no
-- runtime behavior; it exists so server/client code can `export type` off of
-- one canonical shape when Luau type-checking is enabled.

local GameplayTypes = {}

-- Matches RoundService's actual run.State state machine exactly: Queued
-- (waiting for the shared local pile, see RoundService's header) -> Active
-- -> Completing -> Returning -> Ended.
export type RoundState = "Queued" | "Active" | "Completing" | "Returning" | "Ended"

export type ToolOwnershipState = "Locked" | "RunOwned" | "PermanentOwned"

export type EggState = "Buried" | "Available" | "Carried" | "TurnedIn"

-- Matches PartyService's serializeParty exactly.
export type PartyState = {
	InParty: boolean,
	PartyId: string,
	OwnerUserId: number,
	Members: { number },
	MaxSize: number,
	ChapterId: string,
	Difficulty: string,
	CanStart: boolean,
	Started: boolean,
}

export type ToolState = {
	Ownership: ToolOwnershipState,
	AmountLevel: number,
	SpeedLevel: number,
	ExtraLevel: number, -- Dig depth / lucky blast / capacity depending on tool
}

-- Matches RunPlayerStateService.SerializeForClient exactly -- the
-- Gameplay_RunState "PlayerState" sub-message.
export type PlayerRunState = {
	CashCents: number,
	BagCount: number,
	BagCapacity: number,
	BagLevel: number,
	RainbowInBag: number,
	HandHoldUnlocked: boolean,
	HandSpeed: number, -- collection interval seconds
	HandGrasp: number, -- amount per collection
	HandSpeedLevel: number,
	HandGraspLevel: number,
	CarryingEgg: boolean,
	Tools: { [string]: ToolState },
}

-- Matches RoundService's broadcastMeta exactly -- the Gameplay_RunState
-- "RoundMeta" sub-message. See RoundService's header for the full
-- Gameplay_RunState contract (all three sub-message shapes).
export type RunMetaState = {
	RunId: string,
	InProgress: boolean,
	RoundState: RoundState,
	ChapterId: string,
	Difficulty: string,
	StartedAt: number?,
	QueuePosition: number?,
	EggState: EggState,
	EggCarrierUserId: number?,
	EggPosition: Vector3?,
	GoldenHarvestActive: boolean,
	GoldenHarvestEndsAt: number?,
}

return GameplayTypes
