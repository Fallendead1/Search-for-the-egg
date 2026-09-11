-- Shared type documentation for the gameplay systems. This module has no
-- runtime behavior; it exists so server/client code can `export type` off of
-- one canonical shape when Luau type-checking is enabled.

local GameplayTypes = {}

export type RoundState =
	"Lobby"
	| "PartyForming"
	| "Loading"
	| "Active"
	| "Completing"
	| "Returning"
	| "Ended"

export type ToolOwnershipState = "Locked" | "RunOwned" | "PermanentOwned"

export type EggState = "Buried" | "Exposed" | "Available" | "Carried" | "TurnedIn"

export type PartyState = {
	PartyId: string,
	OwnerUserId: number,
	Members: { number },
	MaxSize: number,
	ChapterId: string,
	Difficulty: string,
	CanStart: boolean,
}

export type ToolState = {
	Ownership: ToolOwnershipState,
	AmountLevel: number,
	SpeedLevel: number,
	ExtraLevel: number, -- Dig depth / lucky blast / capacity depending on tool
}

export type PlayerRunState = {
	UserId: number,
	CashCents: number,
	BagCount: number,
	BagCapacity: number,
	BagLevel: number,
	HandHoldUnlocked: boolean,
	HandSpeedLevel: number,
	HandGraspLevel: number,
	RainbowInBag: number,
	CarryingEgg: boolean,
	Tools: { [string]: ToolState },
}

export type RunState = {
	RoundState: RoundState,
	PartyId: string,
	ChapterId: string,
	Difficulty: string,
	StartTime: number,
	EggState: EggState,
	EggCarrierUserId: number?,
	GoldenHarvestActive: boolean,
	GoldenHarvestEndsAt: number?,
}

return GameplayTypes
