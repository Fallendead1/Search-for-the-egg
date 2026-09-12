--!strict
-- Client-side visual bridge for FeatherPileService's server-authoritative
-- logical pile. The server tracks a grid of integer "column fill" counts
-- with NO physical Feather instances at all (see FeatherPileService's
-- header) -- this controller is what actually makes that grid visible: one
-- pooled, anchored, non-collidable Part PER COLUMN (never per Feather),
-- built once from the initial PileSnapshot FX event and then resized in
-- place from batched PileColumnsUpdated deltas. A Hard-mode pile is on the
-- order of ~1700 columns; a one-time pooled build plus in-place property
-- writes on already-existing Parts is cheap relative to per-Feather
-- instancing, which is explicitly the thing this design avoids.
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

-- Real Feather asset (see ReplicatedStorage.SFTE_Assets -- a sibling of the
-- Rojo-owned SearchForTheEgg tree, never synced/deleted by Rojo) replaces
-- the old plain colored block. Still exactly one pooled instance per column,
-- never per Feather -- see the header above for why that budget is fixed.
local featherTemplate: MeshPart = ReplicatedStorage:WaitForChild("SFTE_Assets"):WaitForChild("Feather") :: MeshPart
local FEATHER_NATURAL_SIZE = featherTemplate.Size

-- A small, deterministic-per-column fraction rendered as a rare shimmering
-- variant purely for pile ambience/flavor -- there is no per-unit "this
-- Feather is Rainbow" state anywhere on the server (Rainbow Feather rewards
-- are a plain count added to the bag on collection, see DynamiteService/
-- VacuumService), so this never affects and is never driven by the actual
-- Rainbow Feather economy roll.
local RAINBOW_VISUAL_CHANCE = 0.04
local RAINBOW_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(140, 200, 255),
	Color3.fromRGB(190, 140, 255),
	Color3.fromRGB(255, 210, 120),
}

local container: Folder? = nil
local columnParts: { [string]: MeshPart } = {}
-- Per-column cosmetic jitter, rolled once when a column's Part is first
-- created and reused on every later resize so a column's Feather doesn't
-- re-randomize (and visibly snap/spin) every time its fill changes.
local columnJitter: { [string]: { Yaw: number, Tilt: number, OffsetX: number, OffsetZ: number, ScaleJitter: number, Rainbow: boolean } } = {}
local pileOrigin: Vector3? = nil
local pileColumnSize = 4
local currentPileRunId: string? = nil

local function columnKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

local function rollJitter(footprint: number)
	return {
		Yaw = math.random() * 360,
		Tilt = (math.random() - 0.5) * 30,
		OffsetX = (math.random() - 0.5) * footprint * 0.5,
		OffsetZ = (math.random() - 0.5) * footprint * 0.5,
		ScaleJitter = 0.85 + math.random() * 0.3,
		Rainbow = math.random() < RAINBOW_VISUAL_CHANCE,
	}
end

local function destroyPile()
	if container then
		container:Destroy()
		container = nil
	end
	columnParts = {}
	columnJitter = {}
	pileOrigin = nil
	currentPileRunId = nil
end

local function columnCFrame(cx: number, cz: number, height: number, jitter): CFrame
	local origin = pileOrigin :: Vector3
	local worldX = origin.X + cx * pileColumnSize + jitter.OffsetX
	local worldZ = origin.Z + cz * pileColumnSize + jitter.OffsetZ
	return CFrame.new(worldX, origin.Y + height / 2, worldZ)
		* CFrame.Angles(math.rad(jitter.Tilt), math.rad(jitter.Yaw), 0)
end

local function applyColumn(cx: number, cz: number, fill: number)
	local key = columnKey(cx, cz)
	local part = columnParts[key]

	if fill <= 0 then
		if part then
			part.Transparency = 1
			part.CanCollide = false
		end
		return
	end

	local height = math.max(0.05, fill * HEIGHT_PER_UNIT)
	local footprint = pileColumnSize * COLUMN_FOOTPRINT_SCALE

	local jitter = columnJitter[key]
	if not jitter then
		jitter = rollJitter(footprint)
		columnJitter[key] = jitter
	end

	if not part then
		part = featherTemplate:Clone()
		part.Name = key
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if jitter.Rainbow then
			part.Color = RAINBOW_COLORS[math.random(1, #RAINBOW_COLORS)]
			part.Material = Enum.Material.Neon
			local sparkle = Instance.new("Sparkles")
			sparkle.SparkleColor = part.Color
			sparkle.Parent = part
		end
		part.Parent = container
		columnParts[key] = part
	end

	-- Scale the Feather's own proportions up with pile height instead of
	-- independently stretching X/Z/Y to fill the column footprint -- keeps
	-- it reading as "a feather", never a squashed slab, while still growing
	-- visibly denser/taller as the column fills.
	local scale = math.clamp(0.6 + height / 6, 0.6, 2.4) * jitter.ScaleJitter
	part.Transparency = 0
	part.Size = FEATHER_NATURAL_SIZE * scale
	part.CFrame = columnCFrame(cx, cz, height, jitter)
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
		applyColumn(column.CX, column.CZ, column.Fill)
	end
end

local function onPileColumnsUpdated(payload: any)
	if not container or payload.RunId ~= currentPileRunId then
		return
	end
	for _, column in ipairs(payload.Columns or {}) do
		applyColumn(column.CX, column.CZ, column.Fill)
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
