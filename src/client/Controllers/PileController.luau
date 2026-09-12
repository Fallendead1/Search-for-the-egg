--!strict
-- Client-side visual bridge for FeatherPileService's server-authoritative
-- logical pile. The server tracks a grid of integer "column fill" counts
-- with NO physical Feather instances at all (see FeatherPileService's
-- header) -- this controller is what actually makes that grid visible.
--
-- Each column renders as a small stack of up to MAX_VISUAL_SLOTS_PER_COLUMN
-- individual, fixed-size Feather MeshParts spanning that column's current
-- height (never one part that continuously scales/shrinks -- collecting a
-- Feather must remove a WHOLE Feather instantly, not drain one part's size).
-- Columns are built once from the initial PileSnapshot FX event; a later
-- PileColumnsUpdated delta just hides the top N slots whose combined "batch"
-- of fill was just consumed. A Hard-mode pile has ~1,700 columns but most
-- taper to 1-2 slots near the rim (see FeatherPileService's dome profile),
-- keeping total instances in the same ballpark the one-part-per-column
-- design already budgeted for.
--
-- Pile FX (PileSnapshot/PileColumnsUpdated) are broadcast to every client on
-- the server, not just the owning run's members (see FeatherPileService),
-- so every payload carries RunId and this controller ignores anything that
-- isn't for the local player's own current run.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Parent.Net.Remotes)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local PileController = {}

local HEIGHT_PER_UNIT = 1
local COLUMN_FOOTPRINT_SCALE = 0.9
-- Near-1:1 unit-to-slot mapping (only the tallest center columns, above this
-- cap, ever batch multiple units into one visual Feather) -- the explicit
-- requirement is that collecting reads as immediate, so batching should be
-- the rare exception near the peak, not the default everywhere.
local MAX_VISUAL_SLOTS_PER_COLUMN = 8

-- Real Feather asset (see ReplicatedStorage.SFTE_Assets -- a sibling of the
-- Rojo-owned SearchForTheEgg tree, never synced/deleted by Rojo) replaces
-- the old plain colored block.
local featherTemplate: MeshPart = ReplicatedStorage:WaitForChild("SFTE_Assets"):WaitForChild("Feather") :: MeshPart
local FEATHER_NATURAL_SIZE = featherTemplate.Size

-- Rainbow Feathers are purely a pile-ambience visual (there is no per-unit
-- "this Feather is Rainbow" state anywhere on the server -- Rainbow Feather
-- reward rolls are a plain count added to the bag on collection, see
-- DynamiteService/VacuumService). Only rolled for columns tall enough to
-- read as "inside the mound" rather than out at the sparse rim.
local RAINBOW_VISUAL_CHANCE = 0.05
local RAINBOW_MIN_FILL = 6
local RAINBOW_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(140, 200, 255),
	Color3.fromRGB(190, 140, 255),
	Color3.fromRGB(255, 210, 120),
}

local container: Folder? = nil
-- columnEntries[key] = { Parts: {MeshPart}, SlotCount: number, MaxFill: number, ActiveCount: number }
local columnEntries: { [string]: any } = {}
local pileOrigin: Vector3? = nil
local pileColumnSize = 4
local currentPileRunId: string? = nil

local function columnKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

-- How many discrete, individually-removable Feather instances a column with
-- this MaxFill gets. Capped low (perf: this multiplies across ~1,700
-- columns) -- a full column's worth of fill is a "batch" per slot, per the
-- explicit "one visual Feather may represent a small logical batch, but
-- remove the WHOLE thing at once" allowance.
local function slotsForMaxFill(maxFill: number): number
	if maxFill <= 0 then
		return 0
	end
	return math.clamp(maxFill, 1, MAX_VISUAL_SLOTS_PER_COLUMN)
end

local function rollSlotJitter(footprint: number)
	return {
		Yaw = math.random() * 360,
		Tilt = (math.random() - 0.5) * 70,
		Roll = (math.random() - 0.5) * 40,
		OffsetX = (math.random() - 0.5) * footprint * 0.7,
		OffsetZ = (math.random() - 0.5) * footprint * 0.7,
		ScaleJitter = 0.8 + math.random() * 0.4,
	}
end

local function destroyPile()
	if container then
		container:Destroy()
		container = nil
	end
	columnEntries = {}
	pileOrigin = nil
	currentPileRunId = nil
end

-- Builds every slot Part for a column up front (pooled for the run's
-- lifetime -- later updates only ever toggle Transparency/CanCollide on
-- these, never resize or reposition them).
local function buildColumnEntry(cx: number, cz: number, maxFill: number)
	local slotCount = slotsForMaxFill(maxFill)
	if slotCount <= 0 then
		return
	end

	local origin = pileOrigin :: Vector3
	local footprint = pileColumnSize * COLUMN_FOOTPRINT_SCALE
	local totalHeight = maxFill * HEIGHT_PER_UNIT
	local bandHeight = totalHeight / slotCount
	local worldX = origin.X + cx * pileColumnSize
	local worldZ = origin.Z + cz * pileColumnSize

	local rainbowSlot = (maxFill >= RAINBOW_MIN_FILL and math.random() < RAINBOW_VISUAL_CHANCE) and math.random(1, slotCount) or nil

	local parts = table.create(slotCount)
	for i = 1, slotCount do
		local jitter = rollSlotJitter(footprint)
		local part = featherTemplate:Clone()
		part.Name = columnKey(cx, cz) .. "_" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false

		if i == rainbowSlot then
			part.Color = RAINBOW_COLORS[math.random(1, #RAINBOW_COLORS)]
			part.Material = Enum.Material.Neon
			local sparkle = Instance.new("Sparkles")
			sparkle.SparkleColor = part.Color
			sparkle.Parent = part
		end

		-- Scale relative to this slot's own band height (a shallow rim column
		-- with a small band still reads as feather-sized, not a sliver).
		local scale = math.clamp(bandHeight / FEATHER_NATURAL_SIZE.Y * 1.5, 0.55, 1.8) * jitter.ScaleJitter
		part.Size = FEATHER_NATURAL_SIZE * scale

		local bandCenter = (i - 0.5) * bandHeight
		part.CFrame = CFrame.new(worldX + jitter.OffsetX, origin.Y + bandCenter, worldZ + jitter.OffsetZ)
			* CFrame.Angles(math.rad(jitter.Tilt), math.rad(jitter.Yaw), math.rad(jitter.Roll))
		part.Parent = container
		parts[i] = part
	end

	columnEntries[columnKey(cx, cz)] = {
		Parts = parts,
		SlotCount = slotCount,
		MaxFill = maxFill,
		ActiveCount = slotCount,
	}
end

-- Applies a Fill update: hides exactly the slots whose batch was just
-- consumed, from the top down, instantly (no shrink/fade tween -- a
-- collected Feather is just gone, the same way EggService's pickup already
-- works).
local function applyColumn(cx: number, cz: number, fill: number, maxFill: number)
	local key = columnKey(cx, cz)
	local entry = columnEntries[key]

	if not entry then
		if maxFill > 0 and fill > 0 then
			buildColumnEntry(cx, cz, maxFill)
		end
		return
	end

	local targetActive = entry.MaxFill > 0 and math.ceil((fill / entry.MaxFill) * entry.SlotCount) or 0
	targetActive = math.clamp(targetActive, 0, entry.SlotCount)
	if targetActive == entry.ActiveCount then
		return
	end

	if targetActive < entry.ActiveCount then
		for i = entry.ActiveCount, targetActive + 1, -1 do
			local part = entry.Parts[i]
			if part then
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end

	entry.ActiveCount = targetActive
end

local function onPileSnapshot(payload: any)
	if payload.RunId ~= PlayerState.Run.RunId then
		return
	end

	destroyPile()
	currentPileRunId = payload.RunId
	pileOrigin = payload.Origin
	pileColumnSize = payload.ColumnSize or 4

	local folder = Instance.new("Folder")
	folder.Name = "FeatherPileVisual"
	folder.Parent = Workspace
	container = folder

	for _, column in ipairs(payload.Columns or {}) do
		applyColumn(column.CX, column.CZ, column.Fill, column.MaxFill)
	end
end

local function onPileColumnsUpdated(payload: any)
	if not container or payload.RunId ~= currentPileRunId then
		return
	end
	for _, column in ipairs(payload.Columns or {}) do
		applyColumn(column.CX, column.CZ, column.Fill, column.MaxFill)
	end
end

local HANDLERS: { [string]: (any) -> () } = {
	PileSnapshot = onPileSnapshot,
	PileColumnsUpdated = onPileColumnsUpdated,
}

function PileController.init()
	Remotes.onClientEvent("Gameplay_FX", function(payload: any)
		if type(payload) ~= "table" or type(payload.Type) ~= "string" then
			return
		end
		local handler = HANDLERS[payload.Type]
		if handler then
			handler(payload)
		end
	end)

	Remotes.onClientEvent("Gameplay_RunState", function(state: any)
		if type(state) == "table" and state.Type == "RoundMeta" and state.RoundState == "Ended" and state.RunId == currentPileRunId then
			destroyPile()
		end
	end)
end

return PileController
