local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local eggFoundRemote = ReplicatedStorage:WaitForChild("SearchForTheEgg"):WaitForChild("Remotes"):WaitForChild("EggFound")

eggFoundRemote.OnClientEvent:Connect(function()
	StarterGui:SetCore("SendNotification", {
		Title = "Egg Found!",
		Text = "+1 egg",
		Duration = 3,
	})
end)
