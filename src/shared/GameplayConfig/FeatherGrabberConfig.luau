-- New equipment (MAJOR GAMEPLAY/WORLD INTEGRATION UPDATE): grabs a big
-- single scoop of Feathers at once. Deliberately NOT leveled like Pitchfork/
-- Dynamite/Vacuum/Drone -- the reference equipment it's modeled on is a
-- fixed-stat item, and adding a 5-level upgrade track here would be scope
-- the milestone didn't ask for.

local FeatherGrabberConfig = {}

FeatherGrabberConfig.UNLOCK_COST_CENTS = 600 -- $6.00
FeatherGrabberConfig.ONE_ROUND_ROBUX = 16
FeatherGrabberConfig.PERMANENT_ROBUX = 80

FeatherGrabberConfig.GRAB_AMOUNT = 16
FeatherGrabberConfig.ACTION_SECONDS = 2.0
FeatherGrabberConfig.SEARCH_RADIUS_COLUMNS = 2

return FeatherGrabberConfig
