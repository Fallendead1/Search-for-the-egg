--[[
	Chapter run isolation configuration.

	Chapter1PlaceId = 0 is a PLACEHOLDER meaning "not yet configured": until a
	real Place ID is supplied, RoundService runs Chapter 1 locally (same
	server as the Lobby) via a FIFO run queue instead of teleporting parties
	to a reserved server. That keeps Studio/local testing fully playable
	without a published multi-place setup -- see RoundService's header for
	how the local queue works and why it's an honest (not silently broken)
	fallback rather than true per-party isolation.

	TO GO LIVE WITH FULLY ISOLATED PARTY SERVERS (recommended before launch):
	1. Publish Chapter 1 as its own Place within this experience (universe).
	2. Set Chapter1PlaceId below to that Place's numeric ID.
	3. RoundService will then reserve a private server per party
	   (ChapterTeleportService) and teleport only that party's members there
	   -- every party gets its own fully isolated pile/Egg/Farmer instance,
	   and the Lobby server is never blocked no matter how many parties are
	   mid-run simultaneously.
	4. The receiving Chapter 1 place must read each arriving player's
	   TeleportData (PartyId/ChapterId/Difficulty/Members, set by
	   ChapterTeleportService) and call into RoundService to start their run
	   immediately -- that join-data listener does not exist yet because
	   there is currently only one Place to test against; add it alongside
	   step 1-3 once Chapter 1 is actually split into its own Place.
]]

local TeleportConfig = {}

-- PLACEHOLDER. 0 = "no separate Chapter 1 Place configured yet -- use the
-- local same-server run queue." Do NOT invent a real numeric Place ID here.
TeleportConfig.Chapter1PlaceId = 0

function TeleportConfig.IsChapter1TeleportConfigured(): boolean
	return TeleportConfig.Chapter1PlaceId ~= 0
end

return TeleportConfig
