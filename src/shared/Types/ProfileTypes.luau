-- Luau type definitions for the persistent player profile and its
-- client-facing snapshot. See MetaConfig/DataSchema for the runtime default
-- value and reconciliation logic.

export type Currencies = {
	Gems: number,
	AlienTokens: number,
}

export type Stats = {
	Wins: number,
	BestTime: number?,
	TotalPlaytime: number,
	TotalFeathersCollected: number,
}

export type PermanentPerks = {
	BagSize: number,
	HandGrabAmount: number,
	GemValue: number,
	FeatherValue: number,
}

export type EquippedClasses = {
	Slot1: string,
	Slot2: string?,
}

export type Classes = {
	Owned: { [string]: boolean },
	Equipped: EquippedClasses,
	Slot2Unlocked: boolean,
}

export type SkinOwnership = { [string]: boolean }

export type Inventory = {
	OwnedSkins: { [string]: SkinOwnership },
	SelectedSkins: { [string]: string },
}

-- Tracks processed Robux receipt PurchaseIds so MonetizationService.ProcessReceipt
-- stays idempotent across retries/restarts. Not part of the original GDD schema;
-- added because receipt idempotency is a hard MonetizationService requirement.
export type Receipts = {
	Processed: { [string]: boolean },
}

export type Profile = {
	SchemaVersion: number,
	Currencies: Currencies,
	Stats: Stats,
	PermanentPerks: PermanentPerks,
	Classes: Classes,
	Inventory: Inventory,
	CodesRedeemed: { [string]: number },
	Entitlements: { [string]: boolean },
	Receipts: Receipts,
}

-- Canonical Core_ProfileUpdated contract: a FLAT snapshot (see
-- DataService.GetPublicSnapshot) -- every client Controller reads these
-- exact top-level fields directly off PlayerState.Profile, never a nested
-- Currencies/Stats/Classes/Inventory sub-table.
export type ClientProfileSnapshot = {
	Gems: number,
	AlienTokens: number,
	TotalWins: number,
	TimeRecord: number?,
	TotalPlaytime: number,
	FeathersCollected: number,
	PermanentPerkLevels: { [string]: number },
	OwnedClasses: { [string]: boolean },
	EquippedClass: string?,
	SecondClass: string?,
	SecondSlotUnlocked: boolean,
	OwnedSkins: { [string]: boolean }, -- "Category_SkinId" -> true
	EquippedSkins: { [string]: string }, -- Category -> SkinId
	EntitlementSummary: { [string]: boolean },
}

return {}
