--[[
	Physical Lobby party pads: touch a pad to create a party on it, or to
	join the party already assigned to it -- the primary "join a party" flow
	(no internal party id typing required). Server-authoritative .Touched
	connection, same trusted-physical-interaction pattern as
	UFOSecretService's red button elsewhere in this codebase.

	Gameplay_RequestCreateParty (the client's "TOUCH TO CREATE A PARTY"
	fallback button) and Gameplay_RequestJoinParty remain available as manual
	entry points for a player who isn't standing on a physical pad, or for
	Studio testing before pads are tagged.

	Tag every physical party pad Part/Model in Studio with
	RunConfig.TAGS.PartyPad ("SFTE_PartyPad"). If no pad is tagged yet, this
	service simply has nothing to connect to -- the manual UI button still
	works.
]]

local Players = game:GetService("Players")

local MapAnchors = require(script.Parent.MapAnchors)
local PartyService = require(script.Parent.PartyService)

local PartyPadService = {}

local TOUCH_DEBOUNCE_SECONDS = 1

local padPartyId: { [Instance]: string } = {}
local partyPad: { [string]: Instance } = {}
local lastTouchAt: { [number]: number } = {}

local function getTouchPart(pad: Instance): BasePart?
	if pad:IsA("BasePart") then
		return pad
	elseif pad:IsA("Model") then
		return (pad :: Model).PrimaryPart or pad:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function freePad(party: any)
	local pad = partyPad[party.PartyId]
	if not pad then
		return
	end
	partyPad[party.PartyId] = nil
	padPartyId[pad] = nil
end

local function onPadTouched(pad: Instance, hit: BasePart)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	if lastTouchAt[player.UserId] and now - lastTouchAt[player.UserId] < TOUCH_DEBOUNCE_SECONDS then
		return
	end
	lastTouchAt[player.UserId] = now

	if PartyService.GetPlayerParty(player) then
		return
	end

	local existingPartyId = padPartyId[pad]
	if existingPartyId and PartyService.GetParty(existingPartyId) then
		PartyService.JoinParty(player, existingPartyId)
		return
	end

	local party = PartyService.CreateParty(player)
	if party then
		padPartyId[pad] = party.PartyId
		partyPad[party.PartyId] = pad
	end
end

-- Read-only: the party currently assigned to `pad` (from touching it), or
-- nil if the pad is free. Used by LobbyDisplayService to drive the physical
-- queue sign from real party state instead of a separate presence system.
function PartyPadService.GetPadParty(pad: Instance): any?
	local partyId = padPartyId[pad]
	return partyId and PartyService.GetParty(partyId)
end

function PartyPadService.Init()
	PartyService.SetOnPartyDestroyed(freePad)

	for _, pad in ipairs(MapAnchors.GetPartyPads()) do
		local touchPart = getTouchPart(pad)
		if touchPart then
			touchPart.Touched:Connect(function(hit)
				onPadTouched(pad, hit)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTouchAt[player.UserId] = nil
	end)
end

return PartyPadService
