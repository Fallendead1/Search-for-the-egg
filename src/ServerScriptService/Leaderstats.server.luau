local Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local eggsFound = Instance.new("IntValue")
	eggsFound.Name = "Eggs Found"
	eggsFound.Value = 0
	eggsFound.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
