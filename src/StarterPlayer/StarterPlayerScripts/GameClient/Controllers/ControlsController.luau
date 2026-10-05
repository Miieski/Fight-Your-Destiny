--!strict
-- Player inputs. Keyboard, mouse and gamepad go through ContextActionService, with the keyboard and
-- mouse keys taken from the KeyBindings setting (Settings > Keys; gamepad buttons are fixed). Touch
-- screens get three movable buttons (Attack, Roll, Block) placed from the ButtonLayout setting, with
-- an editor opened from Settings > Controls. In first person or Shift-Lock the cursor is free while a
-- window is open (Window's Modal backdrop) or while the Free Cursor key is held.
--   Controls.Attack:Connect(fn(holding))  Controls.Roll:Connect(fn())  Controls.Block:Connect(fn(holding))
--   Controls.editLayout()  Controls.capture(fn(keyName?))  Controls.keyLabel(keyName)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SettingsConfig = require(ReplicatedStorage.GameSystem.Config.Settings)
local Settings = require(script.Parent.SettingsController)
local State = require(script.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.UI.Notifier)
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
-- Fixed gamepad buttons, bound next to the player's keyboard / mouse key.
local GAMEPAD = { Attack = Enum.KeyCode.ButtonR2, Roll = Enum.KeyCode.ButtonB, Block = Enum.KeyCode.ButtonL2 }
local MOUSE_LABELS = { MouseButton1 = "Left Click", MouseButton2 = "Right Click", MouseButton3 = "Middle Click" }
local KEY_LABELS = { LeftControl = "Left Ctrl", RightControl = "Right Ctrl", None = "None" }

local root: Frame
local toolbar: Frame
local cursorButton: TextButton
local buttons: { [string]: TextButton } = {}
local layout: { [string]: any } = SettingsConfig.defaultLayout()
local editing = false
local selected: string? = nil
local keys: { [string]: string } = SettingsConfig.defaultKeys()
local held: { [string]: boolean } = {} -- hold actions (Attack, Block) currently down
local capturing: (() -> ())? = nil -- cancels the key capture in progress
local swallowed: { [string]: boolean } = {} -- the key that ended a capture, ignored until released

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
	if id == "Attack" or id == "Block" then
		held[id] = if down then true else nil
	end
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

-- The binding name of an input ("Q", "MouseButton2"), or nil for gamepad / touch input.
local function nameOf(input: InputObject): string?
	if SettingsConfig.MOUSE_BUTTONS[input.UserInputType.Name] then
		return input.UserInputType.Name
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	end
	return nil
end

-- "Left Click", "Q" (the letter of the player's keyboard layout), "Left Alt", "None".
function Controls.keyLabel(name: string): string
	local fixed = MOUSE_LABELS[name] or KEY_LABELS[name]
	if fixed then
		return fixed
	end
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode((Enum.KeyCode :: any)[name])
	end)
	if ok and typeof(text) == "string" and #text == 1 and text ~= " " then
		return string.upper(text)
	end
	return (string.gsub(name, "(%l)(%u)", "%1 %2")) -- "LeftAlt" -> "Left Alt"
end

-- Waits for the next key or mouse button and calls done(name), or done(nil) on Escape / time-out. The
-- pressed key does not trigger its own action meanwhile.
function Controls.capture(done: (string?) -> ())
	if capturing then
		capturing()
	end
	local connection: RBXScriptConnection
	local function finish(name: string?)
		if not connection.Connected then
			return
		end
		connection:Disconnect()
		capturing = nil
		done(name)
	end
	connection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			finish(nil)
			return
		end
		local name = nameOf(input)
		if name then
			swallowed[name] = true
			finish(name)
		end
	end)
	capturing = function()
		finish(nil)
	end
	task.delay(SettingsConfig.KEY_CAPTURE_SECONDS, function()
		finish(nil)
	end)
end

local function setCursorFree(free: boolean)
	cursorButton.Visible = free
end

local function press(action: SettingsConfig.KeyAction)
	if action.Window then
		Window.toggle(action.Window)
	elseif action.Id == "FirstPerson" then
		Settings.set("FirstPerson", not (Settings.get("FirstPerson") == true))
	elseif action.Id == "AutoAttack" then
		local passes = State.get("Passes")
		if typeof(passes) == "table" and passes.AutoAttack == true then
			Settings.set("AutoAttack", not (Settings.get("AutoAttack") == true))
		else
			Notifier.push({ Kind = "error", Text = "Needs the Auto-Attack pass" })
		end
	end
end

local function handler(action: SettingsConfig.KeyAction)
	local id = action.Id
	return function(_, state: Enum.UserInputState, input: InputObject)
		local name = nameOf(input)
		if capturing or (name and swallowed[name]) then
			return Enum.ContextActionResult.Pass
		end
		local began = state == Enum.UserInputState.Begin
		local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
		if id == "Attack" or id == "Block" or id == "Roll" then
			if began and (id ~= "Roll" or not Window.isOpen()) then
				fire(id, true)
			elseif ended then
				fire(id, false)
			end
		elseif id == "FreeCursor" then
			if began or ended then
				setCursorFree(began)
			end
		elseif began then
			press(action)
		end
		return Enum.ContextActionResult.Pass
	end
end

-- (Re)binds every action to the player's key plus its fixed gamepad button.
local function bindAll()
	for id in pairs(held) do
		fire(id, false)
	end
	setCursorFree(false)
	for _, action in ipairs(SettingsConfig.KEY_ACTIONS) do
		local actionName = "FYD_" .. action.Id
		ContextActionService:UnbindAction(actionName)
		local inputs: { any } = {}
		local key = keys[action.Id]
		if key and key ~= "None" then
			table.insert(inputs, if SettingsConfig.MOUSE_BUTTONS[key] then (Enum.UserInputType :: any)[key] else (Enum.KeyCode :: any)[key])
		end
		if GAMEPAD[action.Id] then
			table.insert(inputs, GAMEPAD[action.Id])
		end
		if #inputs > 0 then
			ContextActionService:BindAction(actionName, handler(action), false, table.unpack(inputs))
		end
	end
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

	-- a visible Modal button frees the mouse in first person / Shift-Lock (1 px, invisible, never clicked)
	cursorButton = Instance.new("TextButton")
	cursorButton.Name = "FreeCursor"
	cursorButton.Text = ""
	cursorButton.BackgroundTransparency = 1
	cursorButton.Size = UDim2.fromOffset(1, 1)
	cursorButton.Selectable = false
	cursorButton.Modal = true
	cursorButton.Visible = false
	cursorButton.Parent = screenRoot

	UserInputService.InputEnded:Connect(function(input)
		local name = nameOf(input)
		if name then
			swallowed[name] = nil
		end
	end)
	local function loadKeys(value: any)
		keys = SettingsConfig.cleanKeys(value)
		bindAll()
	end
	loadKeys(Settings.get("KeyBindings"))
	Settings.changed("KeyBindings", loadKeys)
end

return Controls
