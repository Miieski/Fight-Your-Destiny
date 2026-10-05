--!strict
-- Player settings: definitions, defaults and validation. Shared: the client builds the Settings
-- window from these definitions and the server validates every "SetSetting" request with them.
export type Definition = {
	Key: string,
	Type: string, -- "number" | "boolean" | "layout"
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

Settings.SECTIONS = { "Audio", "Display", "Controls", "Other" }

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
	{ Key = "ZoneSign", Type = "boolean", Section = "Display", Label = "Zone Sign", Default = true, Hint = "Zone name sign at the top of the screen" },
	{ Key = "HighContrastTelegraphs", Type = "boolean", Section = "Display", Label = "High-Contrast Boss Telegraphs", Default = false },

	{ Key = "CameraZoom", Type = "number", Section = "Controls", Label = "Default Camera Zoom", Default = 18, Min = 8, Max = 40, Step = 1, Unit = " studs" },
	{ Key = "AutoAttack", Type = "boolean", Section = "Controls", Label = "Auto-Attack", Default = false, RequiresPass = "AutoAttack", Hint = "Needs the Auto-Attack pass" },
	{ Key = "ButtonLayout", Type = "layout", Section = "Controls", Label = "Mobile Buttons", Default = {} },

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

Settings.ById = {} :: { [string]: Definition }
for _, definition in ipairs(Settings.Definitions) do
	Settings.ById[definition.Key] = definition
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
		result[definition.Key] = if definition.Type == "layout" then Settings.defaultLayout() else definition.Default
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
	end
	return false, "Invalid setting"
end

return Settings
