--!strict
-- Root screen manager: owns the single ScreenGui, the Lobby/HUD swap, and
-- the modal overlay stack (Book, Inventory, Shop, Classes, Chest, Codes,
-- Stats). Individual feature controllers ask this for a place to render
-- rather than creating their own ScreenGuis.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local lobbyRoot: Frame
local hudRoot: Frame
local overlayRoot: Frame
local overlayBackdrop: TextButton

local currentOverlay: { name: string, frame: Frame, onClose: (() -> ())? }? = nil

UIController.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

function UIController.getScreenGui(): ScreenGui
	return screenGui
end

function UIController.getLobbyRoot(): Frame
	return lobbyRoot
end

function UIController.getHudRoot(): Frame
	return hudRoot
end

function UIController.showLobby()
	lobbyRoot.Visible = true
	hudRoot.Visible = false
end

function UIController.showHud()
	lobbyRoot.Visible = false
	hudRoot.Visible = true
end

-- Opens a modal overlay frame (already built by the caller, parented to
-- nothing) full-screen-centered above everything else. Closes any
-- previously open overlay first.
function UIController.openOverlay(name: string, frame: Frame, onClose: (() -> ())?)
	UIController.closeOverlay()

	frame.Parent = overlayRoot
	overlayBackdrop.Visible = true
	overlayRoot.Visible = true
	currentOverlay = { name = name, frame = frame, onClose = onClose }
end

function UIController.closeOverlay()
	if not currentOverlay then
		return
	end
	local closing = currentOverlay
	currentOverlay = nil
	overlayBackdrop.Visible = false
	overlayRoot.Visible = false
	if closing.onClose then
		closing.onClose()
	end
	closing.frame:Destroy()
end

function UIController.isOverlayOpen(name: string?): boolean
	if not currentOverlay then
		return false
	end
	if name then
		return currentOverlay.name == name
	end
	return true
end

function UIController.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SearchForTheEggUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	lobbyRoot = Instance.new("Frame")
	lobbyRoot.Name = "LobbyRoot"
	lobbyRoot.BackgroundTransparency = 1
	lobbyRoot.Size = UDim2.fromScale(1, 1)
	lobbyRoot.Visible = false
	lobbyRoot.Parent = screenGui

	hudRoot = Instance.new("Frame")
	hudRoot.Name = "HudRoot"
	hudRoot.BackgroundTransparency = 1
	hudRoot.Size = UDim2.fromScale(1, 1)
	hudRoot.Visible = false
	hudRoot.Parent = screenGui

	overlayBackdrop = Instance.new("TextButton")
	overlayBackdrop.Name = "OverlayBackdrop"
	overlayBackdrop.AutoButtonColor = false
	overlayBackdrop.Text = ""
	overlayBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	overlayBackdrop.BackgroundTransparency = 0.45
	overlayBackdrop.Size = UDim2.fromScale(1, 1)
	overlayBackdrop.ZIndex = 100
	overlayBackdrop.Visible = false
	overlayBackdrop.Parent = screenGui
	overlayBackdrop.Activated:Connect(function()
		UIController.closeOverlay()
	end)

	overlayRoot = Instance.new("Frame")
	overlayRoot.Name = "OverlayRoot"
	overlayRoot.BackgroundTransparency = 1
	overlayRoot.Size = UDim2.fromScale(1, 1)
	overlayRoot.ZIndex = 101
	overlayRoot.Visible = false
	overlayRoot.Parent = screenGui

	return screenGui
end

return UIController
