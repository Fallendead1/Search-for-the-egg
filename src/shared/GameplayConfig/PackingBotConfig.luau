-- New automated helper (MAJOR GAMEPLAY/WORLD INTEGRATION UPDATE). Reuses
-- DroneService's exact PILE -> COLLECT -> SELL -> RETURN state-machine
-- shape (see PackingBotService.luau) but as its own separately owned/
-- configured equipment item with fixed stats -- not a Drone upgrade, and not
-- a replacement for the Drone.

local PackingBotConfig = {}

PackingBotConfig.ONE_ROUND_ROBUX = 40
PackingBotConfig.ONE_ROUND_GEM_COST = 45
PackingBotConfig.PERMANENT_ROBUX = 144

PackingBotConfig.CAPACITY = 15
PackingBotConfig.COLLECT_PER_CYCLE = 2
PackingBotConfig.TRAVEL_STUDS_PER_SECOND = 8
PackingBotConfig.COLLECT_TICK_SECONDS = 0.6
PackingBotConfig.SELL_SECONDS = 1

return PackingBotConfig
