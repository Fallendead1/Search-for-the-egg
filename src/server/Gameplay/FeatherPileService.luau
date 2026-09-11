--[[
	Server-authoritative logical Feather pile.

	Performance model (see mission brief "DO NOT create one Script per
	Feather"): the pile is NOT thousands of individual Feather instances or
	Heartbeat loops. It's a 2D grid of "columns" (one Lua table each, no
	Instances, no per-column scripts/connections), each holding an integer
	Fill count representing how many logical Feather units remain stacked in
	that column. Digging removes units from a column (and, if that isn't
	enough, spills into neighboring columns), giving the "dig inward/downward"
	feel without simulating individual Feathers.

	Visual presentation is intentionally NOT built here. This service emits
	batched column-delta events over Gameplay_FX; the client (owned by
	agent/client-ui) is responsible for turning those into the actual pooled,
	dense-looking pile render. See the payload shapes below.

	Egg burial: EggService assigns one column as the Egg's column plus a
	depth fraction (0-1) of that column's max fill that must be cleared
	before the Egg exposes. This service only tracks the column's remaining
	Fill and calls back into EggService when the threshold is crossed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local RemotesLocator = require(script.Parent.RemotesLocator)
local MapAnchors = require(script.Parent.MapAnchors)

local FeatherPileService = {}

local FX_BATCH_INTERVAL_SECONDS = 0.15

local function columnKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

local function randomColumnMaxFill(difficulty): number
	return math.random(difficulty.ColumnDepthMin, difficulty.ColumnDepthMax)
end

-- Builds a fresh pile for a run. `run` just needs to be a stable table we can
-- attach `.Pile` to; RoundService owns the run's lifetime.
function FeatherPileService.BuildForRun(run: any, difficultyId: string)
	local difficulty = RunConfig.DIFFICULTY[difficultyId]
	assert(difficulty, "Unknown difficulty: " .. tostring(difficultyId))

	local gridRadius = math.floor(RunConfig.PILE.GRID_RADIUS_COLUMNS * math.sqrt(difficulty.PileScale) + 0.5)
	local origin = MapAnchors.GetPilePosition()

	local pile = {
		Run = run,
		Difficulty = difficulty,
		Origin = origin,
		ColumnSize = RunConfig.PILE.COLUMN_SIZE_STUDS,
		GridRadius = gridRadius,
		Columns = {}, -- [key] = { CX, CZ, MaxFill, Fill }
		EggColumnKey = nil,
		EggDepthFraction = nil,
		PendingDeltas = {}, -- [key] = column (batched for the next FX flush)
		FlushScheduled = false,
	}

	for cx = -gridRadius, gridRadius do
		for cz = -gridRadius, gridRadius do
			local maxFill = randomColumnMaxFill(difficulty)
			pile.Columns[columnKey(cx, cz)] = {
				CX = cx,
				CZ = cz,
				MaxFill = maxFill,
				Fill = maxFill,
			}
		end
	end

	run.Pile = pile
	return pile
end

function FeatherPileService.ColumnToWorldCenter(pile: any, cx: number, cz: number): Vector3
	return pile.Origin + Vector3.new(cx * pile.ColumnSize, 0, cz * pile.ColumnSize)
end

function FeatherPileService.WorldToColumnCoords(pile: any, worldPosition: Vector3): (number, number)
	local relative = worldPosition - pile.Origin
	local cx = math.round(relative.X / pile.ColumnSize)
	local cz = math.round(relative.Z / pile.ColumnSize)
	cx = math.clamp(cx, -pile.GridRadius, pile.GridRadius)
	cz = math.clamp(cz, -pile.GridRadius, pile.GridRadius)
	return cx, cz
end

function FeatherPileService.GetColumn(pile: any, cx: number, cz: number)
	return pile.Columns[columnKey(cx, cz)]
end

-- Assigns the Egg to a column, biased toward the interior of the grid so it
-- can never be exposed by a single edge dig. Returns the world position the
-- Egg should visually sit at.
function FeatherPileService.AssignEggColumn(pile: any): (Vector3, number, number)
	local difficulty = pile.Difficulty
	local margin = math.max(2, math.floor(pile.GridRadius * 0.25))
	local innerRadius = math.max(1, pile.GridRadius - margin)

	local cx = math.random(-innerRadius, innerRadius)
	local cz = math.random(-innerRadius, innerRadius)

	pile.EggColumnKey = columnKey(cx, cz)
	pile.EggDepthFraction = difficulty.EggMinDepthFraction
		+ math.random() * (difficulty.EggMaxDepthFraction - difficulty.EggMinDepthFraction)

	local worldPosition = FeatherPileService.ColumnToWorldCenter(pile, cx, cz)
	return worldPosition, cx, cz
end

local function isEggColumnExposed(pile: any): boolean
	if not pile.EggColumnKey then
		return false
	end
	local column = pile.Columns[pile.EggColumnKey]
	if not column then
		return false
	end
	local threshold = column.MaxFill * (1 - pile.EggDepthFraction)
	return column.Fill <= threshold
end

local onEggColumnCrossedThreshold: (run: any) -> () = function() end
function FeatherPileService.SetOnEggColumnExposed(callback)
	onEggColumnCrossedThreshold = callback
end

local function queueDelta(pile: any, column: any)
	pile.PendingDeltas[columnKey(column.CX, column.CZ)] = column
	if pile.FlushScheduled then
		return
	end
	pile.FlushScheduled = true
	task.delay(FX_BATCH_INTERVAL_SECONDS, function()
		FeatherPileService.FlushDeltas(pile)
	end)
end

function FeatherPileService.FlushDeltas(pile: any)
	pile.FlushScheduled = false
	if next(pile.PendingDeltas) == nil then
		return
	end

	local batch = {}
	for _, column in pairs(pile.PendingDeltas) do
		table.insert(batch, {
			CX = column.CX,
			CZ = column.CZ,
			Fill = column.Fill,
			MaxFill = column.MaxFill,
		})
	end
	pile.PendingDeltas = {}

	local remote = RemotesLocator.Get("Gameplay_FX")
	remote:FireAllClients({
		Type = "PileColumnsUpdated",
		RunId = pile.Run and pile.Run.RunId,
		Columns = batch,
	})
end

-- Removes up to `amount` units starting at the column nearest `targetPosition`,
-- spilling into a small neighborhood if that column runs out. Returns the
-- number of units actually removed and the list of touched columns (for
-- reward rolls by the caller).
function FeatherPileService.RemoveNear(pile: any, targetPosition: Vector3, amount: number, searchRadiusColumns: number?)
	local searchRadius = searchRadiusColumns or 1
	local originCx, originCz = FeatherPileService.WorldToColumnCoords(pile, targetPosition)

	local remaining = amount
	local touchedColumns = {}

	-- Spiral outward in small rings so we prefer the closest material first.
	for ring = 0, searchRadius do
		if remaining <= 0 then
			break
		end
		for dx = -ring, ring do
			for dz = -ring, ring do
				if math.max(math.abs(dx), math.abs(dz)) == ring then
					if remaining <= 0 then
						break
					end
					local cx, cz = originCx + dx, originCz + dz
					if cx >= -pile.GridRadius and cx <= pile.GridRadius and cz >= -pile.GridRadius and cz <= pile.GridRadius then
						local column = pile.Columns[columnKey(cx, cz)]
						if column and column.Fill > 0 then
							local take = math.min(column.Fill, remaining)
							column.Fill -= take
							remaining -= take
							table.insert(touchedColumns, column)
							queueDelta(pile, column)

							if pile.EggColumnKey == columnKey(cx, cz) and isEggColumnExposed(pile) then
								onEggColumnCrossedThreshold(pile.Run)
							end
						end
					end
				end
			end
		end
	end

	return amount - remaining, touchedColumns
end

-- Fully clears every column within `radius` studs of `centerPosition` (a
-- Dynamite crater). Returns total units cleared.
function FeatherPileService.AreaRemove(pile: any, centerPosition: Vector3, radius: number)
	local centerCx, centerCz = FeatherPileService.WorldToColumnCoords(pile, centerPosition)
	local columnRadius = math.ceil(radius / pile.ColumnSize)

	local totalCleared = 0
	local touchedColumns = {}

	for dx = -columnRadius, columnRadius do
		for dz = -columnRadius, columnRadius do
			local cx, cz = centerCx + dx, centerCz + dz
			if cx >= -pile.GridRadius and cx <= pile.GridRadius and cz >= -pile.GridRadius and cz <= pile.GridRadius then
				local worldCenter = FeatherPileService.ColumnToWorldCenter(pile, cx, cz)
				if (worldCenter - centerPosition).Magnitude <= radius then
					local column = pile.Columns[columnKey(cx, cz)]
					if column and column.Fill > 0 then
						totalCleared += column.Fill
						column.Fill = 0
						table.insert(touchedColumns, column)
						queueDelta(pile, column)

						if pile.EggColumnKey == columnKey(cx, cz) and isEggColumnExposed(pile) then
							onEggColumnCrossedThreshold(pile.Run)
						end
					end
				end
			end
		end
	end

	return totalCleared, touchedColumns
end

function FeatherPileService.GetEggWorldPosition(pile: any): Vector3?
	if not pile.EggColumnKey then
		return nil
	end
	local column = pile.Columns[pile.EggColumnKey]
	if not column then
		return nil
	end
	return FeatherPileService.ColumnToWorldCenter(pile, column.CX, column.CZ)
end

-- Full snapshot for a client that just joined an in-progress run.
function FeatherPileService.SerializeSnapshot(pile: any)
	local columns = {}
	for _, column in pairs(pile.Columns) do
		table.insert(columns, {
			CX = column.CX,
			CZ = column.CZ,
			Fill = column.Fill,
			MaxFill = column.MaxFill,
		})
	end
	return {
		Origin = pile.Origin,
		ColumnSize = pile.ColumnSize,
		GridRadius = pile.GridRadius,
		Columns = columns,
	}
end

-- Fires the one-time full-grid snapshot every run member's client needs to
-- build its pooled pile visualization (see the client PileController). Must
-- be called once, right after BuildForRun, before any RemoveNear/AreaRemove
-- delta ever fires -- otherwise a client could apply a delta to columns it
-- hasn't rendered yet.
function FeatherPileService.BroadcastSnapshot(pile: any)
	local snapshot = FeatherPileService.SerializeSnapshot(pile)
	local remote = RemotesLocator.Get("Gameplay_FX")
	remote:FireAllClients({
		Type = "PileSnapshot",
		RunId = pile.Run and pile.Run.RunId,
		Origin = snapshot.Origin,
		ColumnSize = snapshot.ColumnSize,
		GridRadius = snapshot.GridRadius,
		Columns = snapshot.Columns,
	})
end

function FeatherPileService.Destroy(pile: any)
	if not pile then
		return
	end
	pile.PendingDeltas = {}
	pile.Columns = {}
end

return FeatherPileService
