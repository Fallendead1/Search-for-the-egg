--!strict
-- Entry point for the entire client UI/controller layer. Wires every
-- controller together and kicks off the initial state request. This is
-- the only LocalScript in src/client -- everything else is a
-- ModuleScript required from here (or from another controller).

local Remotes = require(script.Parent.Net.Remotes)
local PlayerState = require(script.Parent.State.PlayerState)

local UIController = require(script.Parent.Controllers.UIController)
local SoundController = require(script.Parent.Controllers.SoundController)
local CameraController = require(script.Parent.Controllers.CameraController)
local NotificationController = require(script.Parent.Controllers.NotificationController)
local EffectsController = require(script.Parent.Controllers.EffectsController)
local PileController = require(script.Parent.Controllers.PileController)
local MonetizationController = require(script.Parent.Controllers.MonetizationController)
local InputController = require(script.Parent.Controllers.InputController)
local WorldInteractionController = require(script.Parent.Controllers.WorldInteractionController)

local StatsController = require(script.Parent.Controllers.StatsController)
local CodesController = require(script.Parent.Controllers.CodesController)
local InventoryController = require(script.Parent.Controllers.InventoryController)
local ChestController = require(script.Parent.Controllers.ChestController)
local ClassController = require(script.Parent.Controllers.ClassController)
local ShopController = require(script.Parent.Controllers.ShopController)
local BagCounterController = require(script.Parent.Controllers.BagCounterController)
local UpgradeBookController = require(script.Parent.Controllers.UpgradeBookController)
local PartyController = require(script.Parent.Controllers.PartyController)
local LobbyController = require(script.Parent.Controllers.LobbyController)
local RunHUDController = require(script.Parent.Controllers.RunHUDController)

local screenGui = UIController.init()

SoundController.init()
CameraController.init()
NotificationController.init(screenGui)
EffectsController.init()
PileController.init()
MonetizationController.init()
InputController.init()
WorldInteractionController.init()

StatsController.init(UIController)
CodesController.init(UIController)
InventoryController.init(UIController)
ChestController.init(UIController)
ClassController.init(UIController)
ShopController.init(UIController)
BagCounterController.init(ShopController)
UpgradeBookController.init(UIController)
PartyController.init()

LobbyController.init({
	UIController = UIController,
	StatsController = StatsController,
	InventoryController = InventoryController,
	CodesController = CodesController,
	ShopController = ShopController,
	ClassController = ClassController,
	ChestController = ChestController,
})
LobbyController.build(UIController.getLobbyRoot())

RunHUDController.init({
	UIController = UIController,
	UpgradeBookController = UpgradeBookController,
})
RunHUDController.build(UIController.getHudRoot())

Remotes.onClientEvent("Core_ProfileUpdated", function(snapshot: any)
	if type(snapshot) == "table" then
		PlayerState.applyProfileSnapshot(snapshot)
	end
end)

UIController.showLobby()
Remotes.fireServer("Core_RequestProfileSnapshot")
