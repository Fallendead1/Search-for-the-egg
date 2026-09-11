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

local Remotes = require(script.Parent.Parent.Net.Remotes)
local PlayerState = require(script.Parent.Parent.State.PlayerState)

local PileController = {}

local HEIGHT_PER_UNIT = 1
local COLUMN_FOOTPRINT_SCALE = 0.9
local FEATHER_COLOR = Color3.fromRGB(235, 225, 200)

local container: Folder? = nil
local columnParts: { [string]: BasePart } = {}
local pileOrigin: Vector3? = nil
local pileColumnSize = 4
local currentPileRunId: string? = nil

local function columnKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

local function destroyPile()
	if container then
		container:Destroy()
		container = nil
	end
	columnParts = {}
	pileOrigin = nil
	currentPileRunId = nil
end

local function columnCFrame(cx: number, cz: number, height: number): CFrame
	local origin = pileOrigin :: Vector3
	local worldX = origin.X + cx * pileColumnSize
	local worldZ = origin.Z + cz * pileColumnSize
	return CFrame.new(worldX, origin.Y + height / 2, worldZ)
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

	if not part then
		part = Instance.new("Part")
		part.Name = key
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Fabric
		part.Color = FEATHER_COLOR
		part.Parent = container
		columnParts[key] = part
	end

	part.Transparency = 0
	part.Size = Vector3.new(footprint, height, footprint)
	part.CFrame = columnCFrame(cx, cz, height)
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
