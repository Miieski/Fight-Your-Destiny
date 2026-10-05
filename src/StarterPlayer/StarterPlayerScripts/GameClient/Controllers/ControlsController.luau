--!strict
-- Player inputs. Keyboard, mouse and gamepad go through ContextActionService; touch screens get
-- three movable buttons (Attack, Roll, Block) placed from the ButtonLayout setting, with an
-- editor opened from Settings > Controls.
--   Controls.Attack:Connect(fn(holding))  Controls.Roll:Connect(fn())  Controls.Block:Connect(fn(holding))
--   Controls.editLayout()
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SettingsConfig = require(ReplicatedStorage.GameSystem.Config.Settings)
local Settings = require(script.Parent.SettingsController)
local Kit = script.Parent.Parent.UI.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local Controls = { Priority = 5 }

local attackEvent = Instance.new("BindableEvent")
local rollEvent = Instance.new("BindableEvent")
local blockEvent = Instance.new("BindableEvent")
Controls.Attack = attackEvent.Event
Controls.Roll = rollEvent.Event
Controls.Block = blockEvent.Event

local ICONS = { Attack = "Sword", Roll = "Speed", Block = "Defense" }
-- Layout editor toolbar: left part of the screen so it never covers the buttons being moved.
local EDITOR = { Width = 560, Height = 120, MaxWidthFraction = 0.56, CenterX = 0.3, Top = 70 }

local root: Frame
local toolbar: Frame
local buttons: { [string]: TextButton } = {}
local layout: { [string]: any } = SettingsConfig.defaultLayout()
local editing = false
local selected: string? = nil

local function place(id: string)
	local entry = layout[id]
	local button = buttons[id]
	if entry and button then
		button.Size = UDim2.fromOffset(entry.Size, entry.Size)
		button.Position = UDim2.fromScale(entry.X, entry.Y)
	end
end

local function refreshVisibility()
	root.Visible = UserInputService.TouchEnabled or editing
	toolbar.Visible = editing
	for id, button in pairs(buttons) do
		local stroke = button:FindFirstChild("Ring") :: UIStroke
		stroke.Color = if editing and id == selected then Theme.Colors.Diamond else Theme.Colors.GoldLight
		stroke.Thickness = if editing and id == selected then 5 else 3
	end
end

local function fire(id: string, down: boolean)
	if id == "Attack" then
		attackEvent:Fire(down)
	elseif id == "Block" then
		blockEvent:Fire(down)
	elseif id == "Roll" and down then
		rollEvent:Fire()
	end
end

local function makeButton(id: string)
	local button = Instance.new("TextButton")
	button.Name = id
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Theme.Colors.WoodTop
	button.BackgroundTransparency = 0.2
	Theme.round(button)
	local ring = Theme.stroke(button, Theme.Colors.GoldLight, 3)
	ring.Name = "Ring"
	Icons.create(ICONS[id], button, { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44) })
	Theme.text({ Font = "Button", Text = id, TextSize = 16, Color = Theme.Colors.Gold, Size = UDim2.fromScale(0.8, 0.22), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Parent = button })

	local dragInput: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if editing then
			selected = id
			dragInput = input
			refreshVisibility()
		else
			fire(id, true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not editing then
			fire(id, false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not (editing and dragInput) then
			return
		end
		local touchDrag = dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput
		local mouseDrag = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
		if touchDrag or mouseDrag then
			local size = root.AbsoluteSize
			local position = Vector2.new(input.Position.X, input.Position.Y) - root.AbsolutePosition
			local margin = SettingsConfig.BUTTON_POSITION_MARGIN
			layout[id].X = math.clamp(position.X / size.X, margin, 1 - margin)
			layout[id].Y = math.clamp(position.Y / size.Y, margin, 1 - margin)
			place(id)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragInput and (input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
			dragInput = nil
		end
	end)
	button.Parent = root
	buttons[id] = button
end

local function resize(delta: number)
	if not selected then
		return
	end
	local limits = SettingsConfig.BUTTON_SIZE
	layout[selected].Size = math.clamp(layout[selected].Size + delta, limits.Min, limits.Max)
	place(selected)
end

local function finishEditing()
	editing = false
	selected = nil
	Settings.set("ButtonLayout", layout)
	refreshVisibility()
end

-- Shows the buttons with a toolbar: drag to move, select + Smaller/Bigger to resize.
function Controls.editLayout()
	Window.close()
	editing = true
	selected = selected or "Attack"
	refreshVisibility()
end

local function copy(source: { [string]: any }): { [string]: any }
	local result = {}
	for id, entry in pairs(source) do
		result[id] = { X = entry.X, Y = entry.Y, Size = entry.Size }
	end
	return result
end

local function bind(name: string, id: string, ...: any)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			if id ~= "Roll" or not Window.isOpen() then
				fire(id, true)
			end
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			fire(id, false)
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end

function Controls:Start()
	local _, screenRoot = Theme.screen("Controls", 5)
	root = Instance.new("Frame")
	root.Name = "TouchButtons"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screenRoot
	for _, id in ipairs(SettingsConfig.BUTTON_IDS) do
		makeButton(id)
	end

	toolbar = Panel.new({ Name = "LayoutEditor", Size = UDim2.fromOffset(EDITOR.Width, EDITOR.Height), Position = UDim2.new(EDITOR.CenterX, 0, 0, EDITOR.Top), AnchorPoint = Vector2.new(0.5, 0), Parent = screenRoot })
	local function sizeToolbar()
		toolbar.Size = UDim2.fromOffset(math.min(EDITOR.Width, Theme.size().X * EDITOR.MaxWidthFraction), EDITOR.Height)
	end
	sizeToolbar()
	Theme.Changed:Connect(sizeToolbar)
	Theme.text({ Text = "Drag the buttons. Select one, then resize it.", TextSize = 20, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = toolbar })
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -20, 0, Theme.TOUCH)
	row.Position = UDim2.new(0.5, 0, 0, 48)
	row.AnchorPoint = Vector2.new(0.5, 0)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = toolbar
	local step = SettingsConfig.BUTTON_SIZE.Step
	Button.new({ Text = "Smaller", Style = "secondary", Size = UDim2.new(0.25, -6, 1, 0), LayoutOrder = 1, OnClick = function() resize(-step) end, Parent = row })
	Button.new({ Text = "Bigger", Style = "secondary", Size = UDim2.new(0.25, -6, 1, 0), LayoutOrder = 2, OnClick = function() resize(step) end, Parent = row })
	Button.new({ Text = "Reset", Style = "danger", Size = UDim2.new(0.25, -6, 1, 0), LayoutOrder = 3, OnClick = function()
		layout = SettingsConfig.defaultLayout()
		for _, id in ipairs(SettingsConfig.BUTTON_IDS) do
			place(id)
		end
	end, Parent = row })
	Button.new({ Text = "Done", Style = "primary", Size = UDim2.new(0.25, -6, 1, 0), LayoutOrder = 4, OnClick = finishEditing, Parent = row })

	local function load(value: any)
		if typeof(value) == "table" and not editing then
			layout = copy(value)
			for _, id in ipairs(SettingsConfig.BUTTON_IDS) do
				if not layout[id] then
					layout[id] = SettingsConfig.defaultLayout()[id]
				end
				place(id)
			end
		end
	end
	load(Settings.get("ButtonLayout"))
	Settings.changed("ButtonLayout", load)
	refreshVisibility()

	bind("FYD_Attack", "Attack", Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	bind("FYD_Roll", "Roll", Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	bind("FYD_Block", "Block", Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
end

return Controls
