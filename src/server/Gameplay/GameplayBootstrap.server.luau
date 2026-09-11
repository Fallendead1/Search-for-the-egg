--[[
	Wires up every Gameplay service in dependency order:
	1. Remotes must exist before anything connects to them.
	2. Party/Round form the state-machine hub other services register against.
	3. Egg/Farmer/Tool/Collection/Sell/Upgrade/Vacuum/Drone/UFO are leaf
	   services that register callbacks with the hub rather than requiring
	   each other, so init order among them mostly doesn't matter -- they're
	   still listed in a readable dependency-ish order below.
]]

local Gameplay = script.Parent

local RemotesLocator = require(Gameplay.RemotesLocator)
local PartyService = require(Gameplay.PartyService)
local RoundService = require(Gameplay.RoundService)
local EggService = require(Gameplay.EggService)
local FarmerService = require(Gameplay.FarmerService)
local ToolService = require(Gameplay.ToolService)
local CollectionService = require(Gameplay.CollectionService)
local SellService = require(Gameplay.SellService)
local RunUpgradeService = require(Gameplay.RunUpgradeService)
local DynamiteService = require(Gameplay.DynamiteService)
local VacuumService = require(Gameplay.VacuumService)
local DroneService = require(Gameplay.DroneService)
local UFOSecretService = require(Gameplay.UFOSecretService)

RemotesLocator.Init()
PartyService.Init()
RoundService.Init()
EggService.Init()
FarmerService.Init()
ToolService.Init()
CollectionService.Init()
SellService.Init()
RunUpgradeService.Init()
DynamiteService.Init()
VacuumService.Init()
DroneService.Init()
UFOSecretService.Init()

print("[Gameplay] SearchForTheEgg gameplay systems initialized.")
