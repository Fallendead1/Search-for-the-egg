local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local eggFoundRemote = ReplicatedStorage:WaitForChild("SearchForTheEgg"):WaitForChild("Remotes"):WaitForChild("EggFound")

-- Roughly matches the default Studio baseplate footprint. Adjust once the
-- real map is built.
local SPAWN_RANGE = 200
local SPAWN_HEIGHT = 3

local egg: Part = nil

local function randomSpawnPosition(): Vector3
	local x = math.random(-SPAWN_RANGE, SPAWN_RANGE)
	local z = math.random(-SPAWN_RANGE, SPAWN_RANGE)
	return Vector3.new(x, SPAWN_HEIGHT, z)
end

local function onEggTouched(hit: BasePart)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local eggsFound = leaderstats and leaderstats:FindFirstChild("Eggs Found")
	if eggsFound then
		eggsFound.Value += 1
	end

	eggFoundRemote:FireClient(player)

	egg.Position = randomSpawnPosition()
end

local function createEgg()
	local part = Instance.new("Part")
	part.Name = "Egg"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2.5, 2)
	part.Color = Color3.fromRGB(255, 230, 150)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Position = randomSpawnPosition()
	part.Parent = Workspace

	part.Touched:Connect(onEggTouched)

	return part
end

egg = createEgg()
