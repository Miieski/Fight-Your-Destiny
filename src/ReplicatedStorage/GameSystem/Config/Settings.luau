--!strict
-- Player settings: definitions, defaults and validation. Shared: the client builds the Settings
-- window from these definitions and the server validates every "SetSetting" request with them.
export type Definition = {
	Key: string,
	Type: string, -- "number" | "boolean" | "layout" | "keys"
	Section: string, -- Settings window tab
	Label: string,
	Default: any,
	Min: number?,
	Max: number?,
	Step: number?,
	Unit: string?, -- "%", "x", " studs"
	RequiresPass: string?, -- greyed out unless profile.Passes[RequiresPass]
	Hint: string?,
}

local Settings = {}

Settings.SECTIONS = { "Audio", "Display", "Controls", "Keys", "Other" }

Settings.Definitions = {
	{ Key = "MasterVolume", Type = "number", Section = "Audio", Label = "Master Volume", Default = 80, Min = 0, Max = 100, Step = 1, Unit = "%" },
	{ Key = "MusicVolume", Type = "number", Section = "Audio", Label = "Music Volume", Default = 60, Min = 0, Max = 100, Step = 1, Unit = "%" },
	{ Key = "PlayerFxVolume", Type = "number", Section = "Audio", Label = "Player FX Volume", Default = 80, Min = 0, Max = 100, Step = 1, Unit = "%" },
	{ Key = "EnemyFxVolume", Type = "number", Section = "Audio", Label = "Enemy & Boss FX Volume", Default = 80, Min = 0, Max = 100, Step = 1, Unit = "%" },
	{ Key = "UiVolume", Type = "number", Section = "Audio", Label = "UI Volume", Default = 70, Min = 0, Max = 100, Step = 1, Unit = "%" },
	{ Key = "AmbientVolume", Type = "number", Section = "Audio", Label = "Ambient Volume", Default = 60, Min = 0, Max = 100, Step = 1, Unit = "%" },

	{ Key = "LowFx", Type = "boolean", Section = "Display", Label = "Low FX", Default = false, Hint = "Fewer particles" },
	{ Key = "DamageNumbers", Type = "boolean", Section = "Display", Label = "Damage Numbers", Default = true },
	{ Key = "ScreenShake", Type = "boolean", Section = "Display", Label = "Screen Shake", Default = true },
	{ Key = "ShakeIntensity", Type = "number", Section = "Display", Label = "Shake Intensity", Default = 60, Min = 0, Max = 100, Step = 5, Unit = "%" },
	{ Key = "UiScale", Type = "number", Section = "Display", Label = "UI Scale", Default = 1, Min = 0.8, Max = 1.2, Step = 0.05, Unit = "x" },
	{ Key = "ZoneSign", Type = "boolean", Section = "Display", Label = "Zone Sign", Default = false, Hint = "Zone name sign at the top of the screen" },
	{ Key = "ShowArmor", Type = "boolean", Section = "Display", Label = "Show Armor", Default = true, Hint = "Armor on the characters (the stats stay)" },
	{ Key = "HighContrastTelegraphs", Type = "boolean", Section = "Display", Label = "High-Contrast Boss Telegraphs", Default = false },

	{ Key = "CameraZoom", Type = "number", Section = "Controls", Label = "Default Camera Zoom", Default = 18, Min = 8, Max = 40, Step = 1, Unit = " studs" },
	{ Key = "FirstPerson", Type = "boolean", Section = "Controls", Label = "First Person", Default = false, Hint = "Or zoom all the way in" },
	{ Key = "AutoAttack", Type = "boolean", Section = "Controls", Label = "Auto-Attack", Default = false, RequiresPass = "AutoAttack", Hint = "Needs the Auto-Attack pass" },
	{ Key = "ButtonLayout", Type = "layout", Section = "Controls", Label = "Mobile Buttons", Default = {} },

	{ Key = "KeyBindings", Type = "keys", Section = "Keys", Label = "Key Bindings", Default = {} },

	{ Key = "FastOpen", Type = "boolean", Section = "Other", Label = "Fast Open", Default = false, Hint = "Shorter case-opening spin (the reveal always plays)" },
} :: { Definition }

-- Mobile action buttons: position = center of the button as a fraction of the screen,
-- Size in UI design units (the HUD scale applies on top).
Settings.BUTTON_IDS = { "Attack", "Roll", "Block" }
Settings.BUTTON_LAYOUT_DEFAULT = {
	Attack = { X = 0.80, Y = 0.60, Size = 88 },
	Roll = { X = 0.74, Y = 0.86, Size = 64 },
	Block = { X = 0.93, Y = 0.48, Size = 64 },
}
Settings.BUTTON_SIZE = { Min = 56, Max = 140, Step = 8 }
Settings.BUTTON_POSITION_MARGIN = 0.03 -- keep button centers this far from the screen edges
Settings.SAVE_DEBOUNCE_SECONDS = 0.5 -- client waits this long after the last change before saving

-- Keyboard and mouse bindings (Settings > Keys). A binding is an Enum.KeyCode name, a mouse button
-- ("MouseButton1/2/3", only for actions with Mouse = true) or "None". Gamepad buttons stay fixed
-- (ControlsController). Window = the window the key opens and closes.
export type KeyAction = { Id: string, Label: string, Group: string, Default: string, Mouse: boolean?, Window: string? }
Settings.KEY_GROUPS = { "Combat", "Camera", "Menus" }
Settings.KEY_ACTIONS = {
	{ Id = "Attack", Label = "Attack", Group = "Combat", Default = "MouseButton1", Mouse = true },
	{ Id = "Block", Label = "Block (hold)", Group = "Combat", Default = "MouseButton2", Mouse = true },
	{ Id = "Roll", Label = "Roll", Group = "Combat", Default = "Q", Mouse = true },
	{ Id = "AutoAttack", Label = "Auto-Attack on / off", Group = "Combat", Default = "R" },
	{ Id = "FirstPerson", Label = "First Person on / off", Group = "Camera", Default = "V" },
	{ Id = "FreeCursor", Label = "Free the cursor (hold)", Group = "Camera", Default = "LeftAlt" },
	{ Id = "Inventory", Label = "Inventory", Group = "Menus", Default = "B", Window = "Inventory" },
	{ Id = "Stats", Label = "Stats", Group = "Menus", Default = "C", Window = "Stats" },
	{ Id = "Shop", Label = "Shop", Group = "Menus", Default = "G", Window = "Shop" },
	{ Id = "RebirthShop", Label = "Rebirth Shop", Group = "Menus", Default = "Y", Window = "RebirthShop" },
	{ Id = "Pets", Label = "Pets", Group = "Menus", Default = "P", Window = "Pets" },
	{ Id = "Index", Label = "Index", Group = "Menus", Default = "X", Window = "Index" },
	{ Id = "Quests", Label = "Quests", Group = "Menus", Default = "J", Window = "Quests" },
	{ Id = "Team", Label = "Team", Group = "Menus", Default = "T", Window = "Team" },
	{ Id = "Zones", Label = "Zones", Group = "Menus", Default = "M", Window = "Zones" },
	{ Id = "Settings", Label = "Settings", Group = "Menus", Default = "K", Window = "Settings" },
} :: { KeyAction }
Settings.MOUSE_BUTTONS = { MouseButton1 = true, MouseButton2 = true, MouseButton3 = true }
-- Keys Roblox or the game already use: movement and jump, prompts (E, F), camera zoom (I, O), Shift-Lock,
-- chat, menus, the admin panel (F2), the console (F9), full screen (F11).
Settings.KEY_RESERVED = {
	W = true, A = true, S = true, D = true, Up = true, Down = true, Left = true, Right = true, Space = true,
	E = true, F = true, I = true, O = true, LeftShift = true, RightShift = true,
	Escape = true, Tab = true, Slash = true, Backquote = true, Return = true, Menu = true,
	LeftSuper = true, RightSuper = true, LeftMeta = true, RightMeta = true,
	F2 = true, F9 = true, F10 = true, F11 = true, F12 = true, Unknown = true,
}
Settings.KEY_CAPTURE_SECONDS = 6 -- waiting for the new key gives up after this

Settings.ById = {} :: { [string]: Definition }
for _, definition in ipairs(Settings.Definitions) do
	Settings.ById[definition.Key] = definition
end

Settings.KeyById = {} :: { [string]: KeyAction }
for _, action in ipairs(Settings.KEY_ACTIONS) do
	Settings.KeyById[action.Id] = action
end

local KEYBOARD: { [string]: boolean } = {}
for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
	local name = item.Name
	-- gamepad, mouse and touch codes are not keyboard keys
	if not (string.find(name, "^Button") or string.find(name, "^DPad") or string.find(name, "^Thumbstick")
		or string.find(name, "^Mouse") or string.find(name, "^Touch") or string.find(name, "^Trackpad")) then
		KEYBOARD[name] = true
	end
end

function Settings.defaultKeys(): { [string]: string }
	local result = {}
	for _, action in ipairs(Settings.KEY_ACTIONS) do
		result[action.Id] = action.Default
	end
	return result
end

-- nil when `name` can be bound to the action, else the reason it cannot.
function Settings.keyProblem(action: KeyAction, name: any): string?
	if typeof(name) ~= "string" then
		return "Unknown key"
	elseif name == "None" then
		return nil
	elseif Settings.MOUSE_BUTTONS[name] then
		return if action.Mouse then nil else "Mouse buttons only work for Attack, Block and Roll"
	elseif not KEYBOARD[name] then
		return "Unknown key"
	elseif Settings.KEY_RESERVED[name] then
		return "This key is already used by Roblox or the game"
	end
	return nil
end

-- Every action gets a usable binding: a wrong one falls back to the default, and a key already taken by an
-- earlier action becomes "None", so one key never triggers two actions.
function Settings.cleanKeys(value: any): { [string]: string }
	local source = if typeof(value) == "table" then value else {}
	local result = {}
	local used = {}
	for _, action in ipairs(Settings.KEY_ACTIONS) do
		local name = source[action.Id]
		if Settings.keyProblem(action, name) then
			name = action.Default
		end
		if name ~= "None" and used[name] then
			name = "None"
		end
		used[name] = true
		result[action.Id] = name
	end
	return result
end

-- Binds `name` to the action. An action that already had this key takes the action's old key (or none
-- when it cannot use it). Returns true, newBindings or false, errorMessage.
function Settings.assignKey(bindings: { [string]: string }, actionId: string, name: string): (boolean, any)
	local action = Settings.KeyById[actionId]
	if not action then
		return false, "Unknown action"
	end
	local problem = Settings.keyProblem(action, name)
	if problem then
		return false, problem
	end
	local result = Settings.cleanKeys(bindings)
	local old = result[actionId]
	if name ~= "None" then
		for otherId, otherName in pairs(result) do
			if otherId ~= actionId and otherName == name then
				result[otherId] = if Settings.keyProblem(Settings.KeyById[otherId], old) == nil then old else "None"
			end
		end
	end
	result[actionId] = name
	return true, result
end

local function copyLayout(layout: { [string]: any }): { [string]: any }
	local result = {}
	for id, entry in pairs(layout) do
		result[id] = { X = entry.X, Y = entry.Y, Size = entry.Size }
	end
	return result
end

function Settings.defaultLayout(): { [string]: any }
	return copyLayout(Settings.BUTTON_LAYOUT_DEFAULT)
end

function Settings.defaults(): { [string]: any }
	local result = {}
	for _, definition in ipairs(Settings.Definitions) do
		result[definition.Key] = if definition.Type == "layout" then Settings.defaultLayout()
			elseif definition.Type == "keys" then Settings.defaultKeys()
			else definition.Default
	end
	return result
end

local function round(value: number, step: number, min: number): number
	return min + math.floor((value - min) / step + 0.5) * step
end

local function validateLayout(value: any): (boolean, any)
	if typeof(value) ~= "table" then
		return false, "Invalid layout"
	end
	local margin = Settings.BUTTON_POSITION_MARGIN
	local result = Settings.defaultLayout()
	for _, id in ipairs(Settings.BUTTON_IDS) do
		local entry = value[id]
		if typeof(entry) == "table" and typeof(entry.X) == "number" and typeof(entry.Y) == "number" and typeof(entry.Size) == "number"
			and entry.X == entry.X and entry.Y == entry.Y and entry.Size == entry.Size then
			result[id] = {
				X = math.clamp(entry.X, margin, 1 - margin),
				Y = math.clamp(entry.Y, margin, 1 - margin),
				Size = math.clamp(math.floor(entry.Size + 0.5), Settings.BUTTON_SIZE.Min, Settings.BUTTON_SIZE.Max),
			}
		end
	end
	return true, result
end

-- Returns true, cleanValue or false, errorMessage. passes = profile.Passes (for RequiresPass).
function Settings.validate(key: any, value: any, passes: { [string]: any }?): (boolean, any)
	local definition = if typeof(key) == "string" then Settings.ById[key] else nil
	if not definition then
		return false, "Unknown setting"
	end
	if definition.Type == "number" then
		if typeof(value) ~= "number" or value ~= value then
			return false, "Invalid value"
		end
		local min, max = definition.Min :: number, definition.Max :: number
		local clean = math.clamp(round(value, definition.Step or 1, min), min, max)
		return true, clean
	elseif definition.Type == "boolean" then
		if typeof(value) ~= "boolean" then
			return false, "Invalid value"
		end
		if value and definition.RequiresPass and not (passes and passes[definition.RequiresPass]) then
			return false, `Requires the {definition.RequiresPass} pass`
		end
		return true, value
	elseif definition.Type == "layout" then
		return validateLayout(value)
	elseif definition.Type == "keys" then
		if typeof(value) ~= "table" then
			return false, "Invalid key bindings"
		end
		return true, Settings.cleanKeys(value)
	end
	return false, "Invalid setting"
end

return Settings
