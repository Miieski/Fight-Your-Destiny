--!strict
-- HUD 1: player health, top-left below the Roblox icons: the player's avatar portrait, exact
-- "current / max", a lighter trailing
-- segment on damage, pulse + red vignette under LowHealthFraction. Also hides the default
-- Roblox health bar and backpack hotbar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Kit = script.Parent.Kit
local Bar = require(Kit.Bar)
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)

local HealthBar = { Priority = 10 }

local VIGNETTE_DEPTH = 0.22 -- fraction of the screen covered by each red edge
local PULSE = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PORTRAIT = 1.12 -- portrait height relative to the panel (it overlaps the panel's left end)

local panel: Frame
local bar: any
local vignette: Frame
local edges: { Frame } = {}
local pulses: { Tween } = {}
local low = false
local connections: { RBXScriptConnection } = {}

local function setLow(value: boolean)
	if value == low then
		return
	end
	low = value
	for _, tween in ipairs(pulses) do
		tween:Cancel()
	end
	table.clear(pulses)
	vignette.Visible = value
	local border = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	if value then
		for _, edge in ipairs(edges) do
			edge.BackgroundTransparency = 0.55
			local tween = TweenService:Create(edge, PULSE, { BackgroundTransparency = 0.85 })
			tween:Play()
			table.insert(pulses, tween)
		end
		local tween = TweenService:Create(border, PULSE, { Color = Theme.Colors.Health })
		tween:Play()
		table.insert(pulses, tween)
	else
		border.Color = Theme.Colors.GoldLight
	end
end

local function bindCharacter(character: Model)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local function update(instant: boolean?)
		bar:Set(humanoid.Health, humanoid.MaxHealth, instant)
		setLow(humanoid.Health > 0 and humanoid.Health / math.max(1, humanoid.MaxHealth) < UIConfig.Hud.LowHealthFraction)
	end
	update(true)
	table.insert(connections, humanoid.HealthChanged:Connect(function()
		update()
	end))
	table.insert(connections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		update()
	end))
end

-- Full screen (ScreenInsets None) so the red edge has no seam under the Roblox top bar.
local function vignetteScreen(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vignette"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function makeVignette(root: Instance)
	vignette = Instance.new("Frame")
	vignette.Name = "LowHealth"
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Visible = false
	vignette.Parent = root
	-- { size, position, gradient rotation }: each edge fades from red to clear toward the center
	local sides = {
		{ UDim2.fromScale(1, VIGNETTE_DEPTH), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, VIGNETTE_DEPTH), UDim2.fromScale(0, 1 - VIGNETTE_DEPTH), -90 },
		{ UDim2.fromScale(VIGNETTE_DEPTH, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(VIGNETTE_DEPTH, 1), UDim2.fromScale(1 - VIGNETTE_DEPTH, 0), 180 },
	}
	for _, side in ipairs(sides) do
		local edge = Instance.new("Frame")
		edge.Size = side[1]
		edge.Position = side[2]
		edge.BackgroundColor3 = Theme.Colors.Health
		edge.BorderSizePixel = 0
		local fade = Instance.new("UIGradient")
		fade.Rotation = side[3]
		fade.Transparency = NumberSequence.new(0, 1)
		fade.Parent = edge
		edge.Parent = vignette
		table.insert(edges, edge)
	end
end

-- The player's avatar headshot in a gold ring over the panel's left end, like the currency icons.
-- Test players without a Roblox account (UserId <= 0, Studio local servers) get the heart instead.
local function makePortrait(parent: Instance)
	local ring = Instance.new("Frame")
	ring.Name = "Portrait"
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, -6, 0.5, 0)
	ring.Size = UDim2.fromScale(PORTRAIT, PORTRAIT)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ring.BackgroundColor3 = Color3.new(1, 1, 1)
	ring.ZIndex = 5
	Theme.gradient(ring, Theme.Colors.WoodLight, Theme.Colors.WoodInset)
	Theme.round(ring)
	Theme.stroke(ring, Theme.Colors.GoldLight, 3)
	local userId = Players.LocalPlayer.UserId
	if userId > 0 then
		local image = Instance.new("ImageLabel")
		image.Name = "Headshot"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
		image.ZIndex = 6
		Theme.round(image)
		image.Parent = ring
	else
		Icons.create("Heart", ring, { Size = UDim2.fromScale(0.8, 0.8), ZIndex = 6 })
	end
	ring.Parent = parent
end

local function layout()
	local size = if Theme.isCompact() then UIConfig.Hud.Health.Compact else UIConfig.Hud.Health.Normal
	panel.Size = UDim2.fromOffset(size.X, size.Y)
end

function HealthBar:Start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	makeVignette(vignetteScreen())
	local root = Screens.hud()
	panel = Panel.new({ Name = "Health", Position = UDim2.fromOffset(12, UIConfig.Hud.Health.Top), Gems = false, BorderThickness = 3, Parent = root })
	makePortrait(panel)
	bar = Bar.new({ Name = "HP", Size = UDim2.new(1, -68, 0.56, 0), Position = UDim2.new(0, 58, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = panel })
	layout()
	Theme.Changed:Connect(layout)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

return HealthBar
