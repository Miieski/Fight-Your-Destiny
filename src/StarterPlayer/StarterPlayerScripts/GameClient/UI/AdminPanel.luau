--!strict
-- Admin panel (DESIGN.md section 13), money commands only for now. Opened with F2 or the ADMIN
-- button. It is only built for players flagged IsAdmin by the server, and the server re-checks
-- every command, so this UI grants nothing by itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Admins = require(ReplicatedStorage.GameSystem.Config.Admins)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)

local AdminPanel = { Priority = 20 }

local WOOD = Color3.fromRGB(74, 48, 32)
local WOOD_DARK = Color3.fromRGB(51, 32, 15)
local GOLD = Color3.fromRGB(255, 201, 60)
local GOLD_BORDER = Color3.fromRGB(232, 180, 74)
local DIAMOND = Color3.fromRGB(95, 212, 255)
local STEEL = Color3.fromRGB(150, 156, 168)
local DANGER = Color3.fromRGB(217, 59, 59)
local INK = Color3.fromRGB(40, 24, 12)
local BASE_HEIGHT = 720
local WINDOW = Vector2.new(440, 412)
local MARGIN, GAP, ROW = 18, 6, 44
local OPEN_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function outline(parent: Instance, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function text(parent: Instance, className: string, props: { [string]: any }): any
	local item = Instance.new(className) :: any
	item.Font = Enum.Font.Fantasy
	item.TextSize = 20
	item.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props) do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function button(parent: Instance, label: string, color: Color3, x: number, y: number, width: number, onClick: () -> ()): TextButton
	local item = text(parent, "TextButton", {
		Name = label, Text = label, BackgroundColor3 = color, TextColor3 = INK,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, ROW),
	}) :: TextButton
	round(item, 6)
	outline(item, INK, 2)
	item.Activated:Connect(function()
		Sfx.play("UIClick")
		onClick()
	end)
	return item
end

-- One currency block: title, preset "+amount" buttons, "Set 0", and a custom amount box.
local function section(parent: Instance, y: number, title: string, color: Color3, addCommand: string, setCommand: string, presets: { number })
	text(parent, "TextLabel", {
		Text = title, TextColor3 = color, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(MARGIN, y), Size = UDim2.fromOffset(200, 24),
	})
	local function send(command: string, amount: number)
		Net.event("Admin"):FireServer(command, amount)
	end
	local inner = WINDOW.X - MARGIN * 2
	local count = #presets + 1
	local width = math.floor((inner - GAP * (count - 1)) / count)
	local top = y + 28
	for i, amount in ipairs(presets) do
		button(parent, "+" .. Format.number(amount), color, MARGIN + (i - 1) * (width + GAP), top, width, function()
			send(addCommand, amount)
		end)
	end
	button(parent, "Set 0", DANGER, MARGIN + (count - 1) * (width + GAP), top, width, function()
		send(setCommand, 0)
	end).TextColor3 = Color3.new(1, 1, 1)

	local boxWidth = inner - 2 * (86 + GAP)
	local box = text(parent, "TextBox", {
		Text = "", PlaceholderText = "Amount (2500, 2.5M, 1T...)", ClearTextOnFocus = false,
		BackgroundColor3 = WOOD_DARK, PlaceholderColor3 = STEEL,
		Position = UDim2.fromOffset(MARGIN, top + ROW + GAP), Size = UDim2.fromOffset(boxWidth, ROW),
	}) :: TextBox
	round(box, 6)
	outline(box, GOLD_BORDER, 2)
	local function custom(command: string)
		local amount = Format.parse(box.Text)
		if amount and amount <= Admins.MaxAmount then
			send(command, amount)
		else
			Sfx.play("Denied")
			box.Text = ""
		end
	end
	button(parent, "Add", color, MARGIN + boxWidth + GAP, top + ROW + GAP, 86, function()
		custom(addCommand)
	end)
	button(parent, "Set", STEEL, MARGIN + boxWidth + GAP + 86 + GAP, top + ROW + GAP, 86, function()
		custom(setCommand)
	end)
end

local function build(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function rescale()
		scale.Scale = math.clamp(camera.ViewportSize.Y / BASE_HEIGHT, 0.6, 1.5)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Position = UDim2.fromScale(-1, -1)
	backdrop.Size = UDim2.fromScale(4, 4)
	backdrop.Visible = false
	backdrop.Parent = gui

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(WINDOW.X, WINDOW.Y)
	window.BackgroundColor3 = WOOD
	window.Visible = false
	window.Active = true
	round(window, 8)
	outline(window, GOLD_BORDER, 4)
	local pop = Instance.new("UIScale")
	pop.Parent = window
	window.Parent = gui

	text(window, "TextLabel", {
		Text = "Admin", TextSize = 26, TextColor3 = GOLD, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, 10), Size = UDim2.fromOffset(300, 32), TextXAlignment = Enum.TextXAlignment.Left,
	})
	section(window, 52, "Gold", GOLD, "AddGold", "SetGold", Admins.GoldButtons)
	section(window, 192, "Diamonds", DIAMOND, "AddDiamonds", "SetDiamonds", Admins.DiamondButtons)
	text(window, "TextLabel", {
		Text = "World", BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(MARGIN, 322), Size = UDim2.fromOffset(200, 24),
	})
	button(window, "Unlock all gates", STEEL, MARGIN, 350, WINDOW.X - MARGIN * 2, function()
		Net.event("Admin"):FireServer("UnlockAll", 0)
	end)

	local open = false
	local function setOpen(value: boolean)
		open = value
		backdrop.Visible = value
		window.Visible = value
		if value then
			Sfx.play("UIOpen")
			pop.Scale = 0.9
			TweenService:Create(pop, OPEN_TWEEN, { Scale = 1 }):Play()
		else
			Sfx.play("UIClose")
		end
	end
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	local close = button(window, "X", DANGER, WINDOW.X - MARGIN - ROW, 8, ROW, function()
		setOpen(false)
	end)
	close.TextColor3 = Color3.new(1, 1, 1)

	local toggle = text(gui, "TextButton", {
		Name = "Toggle", Text = "ADMIN", TextSize = 18, TextColor3 = INK, BackgroundColor3 = GOLD,
		Position = UDim2.fromOffset(12, 124), Size = UDim2.fromOffset(96, ROW),
	}) :: TextButton
	round(toggle, 6)
	outline(toggle, INK, 2)
	toggle.Activated:Connect(function()
		setOpen(not open)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F2 then
			setOpen(not open)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function AdminPanel:Start()
	local player = Players.LocalPlayer
	if player:GetAttribute("IsAdmin") == nil then
		player:GetAttributeChangedSignal("IsAdmin"):Wait()
	end
	if player:GetAttribute("IsAdmin") then
		build(player)
	end
end

return AdminPanel
