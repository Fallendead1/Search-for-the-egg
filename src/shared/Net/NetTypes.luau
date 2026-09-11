-- Shared Luau type definitions for Core_* remote payloads. These describe
-- the contract between the Core (server) and Client/Gameplay agents.

export type ClassRollResultPayload = {
	Success: boolean,
	Reason: string?,
	Result: {
		ClassId: string,
		IsNew: boolean,
		DisplayName: string,
	}?,
}

export type AlienChestReward = {
	Type: string, -- "Gems" | "Skin"
	Amount: number?,
	Category: string?,
	SkinId: string?,
}

export type AlienChestResultPayload = {
	Success: boolean,
	Reason: string?,
	Rewards: { AlienChestReward }?,
}

export type CodeResultPayload = {
	Success: boolean,
	Reason: string?,
	Result: {
		Code: string,
		Reward: { Gems: number?, AlienTokens: number? },
	}?,
}

export type RunCompletionRequest = {
	ChapterId: string,
	Difficulty: string,
	ElapsedSeconds: number,
	FeathersCollected: number,
}

export type RunCompletionSummary = {
	GemsAwarded: number,
	AlienTokensAwarded: number,
	Wins: number,
	IsNewRecord: boolean,
	BestTime: number?,
}

return {}
