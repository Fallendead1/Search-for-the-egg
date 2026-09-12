-- Canonical remote names for the entire game. RemoteBootstrap (server/Core)
-- creates exactly one RemoteEvent per entry under
-- ReplicatedStorage/SearchForTheEgg/Remotes. Client and server code should
-- always index this table rather than hardcoding string literals.

local RemoteNames = {
	-- Core: profile
	Core_RequestProfileSnapshot = "Core_RequestProfileSnapshot",
	Core_ProfileUpdated = "Core_ProfileUpdated",

	-- Core: classes
	Core_RequestClassRoll = "Core_RequestClassRoll",
	Core_ClassRollResult = "Core_ClassRollResult",
	Core_RequestEquipClass = "Core_RequestEquipClass",

	-- Core: permanent perks
	Core_RequestBuyPermanentPerk = "Core_RequestBuyPermanentPerk",

	-- Core: daily rewards
	Core_RequestClaimDailyReward = "Core_RequestClaimDailyReward",

	-- Core: alien chest
	Core_RequestOpenAlienChest = "Core_RequestOpenAlienChest",
	Core_AlienChestResult = "Core_AlienChestResult",

	-- Core: inventory
	Core_RequestSelectSkin = "Core_RequestSelectSkin",

	-- Core: codes
	Core_RequestRedeemCode = "Core_RequestRedeemCode",
	Core_CodeResult = "Core_CodeResult",

	-- Core: leaderboards
	Core_RequestLeaderboard = "Core_RequestLeaderboard",
	Core_LeaderboardResult = "Core_LeaderboardResult",

	-- Gameplay: party (owned/handled by the Gameplay agent)
	Gameplay_RequestCreateParty = "Gameplay_RequestCreateParty",
	Gameplay_RequestJoinParty = "Gameplay_RequestJoinParty",
	Gameplay_RequestSetPartySelection = "Gameplay_RequestSetPartySelection",
	Gameplay_RequestStartParty = "Gameplay_RequestStartParty",
	Gameplay_RequestLeaveParty = "Gameplay_RequestLeaveParty",
	Gameplay_PartyState = "Gameplay_PartyState",

	-- Gameplay: run (owned/handled by the Gameplay agent)
	Gameplay_RequestCollect = "Gameplay_RequestCollect",
	Gameplay_RequestSell = "Gameplay_RequestSell",
	Gameplay_RequestBuyRunUpgrade = "Gameplay_RequestBuyRunUpgrade",
	Gameplay_RequestToolAction = "Gameplay_RequestToolAction",
	Gameplay_RequestEggPickup = "Gameplay_RequestEggPickup",
	Gameplay_RequestEggTurnIn = "Gameplay_RequestEggTurnIn",
	Gameplay_RunState = "Gameplay_RunState",
	Gameplay_Notification = "Gameplay_Notification",
	Gameplay_FX = "Gameplay_FX",
	Gameplay_Completion = "Gameplay_Completion",
}

return table.freeze(RemoteNames)
