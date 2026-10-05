--!strict
-- The Settings window (docs/ui_hud_brief.txt section 6), built from Config/Settings definitions.
-- Every control applies at once and saves through SettingsController (debounced). The Keys tab lists
-- Config/Settings KEY_ACTIONS: click a key, then press the new key or mouse button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local SettingsConfig = require(ReplicatedStorage.GameSystem.Config.Settings)
local State = require(script.Parent.Parent.Parent.State)
local Controllers = script.Parent.Parent.Parent.Controllers
local Controls = require(Controllers.ControlsController)
local Settings = require(Controllers.SettingsController)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Slider = require(Kit.Slider)
local Theme = require(Kit.Theme)
local Toggle = require(Kit.Toggle)

local SettingsPage = {}

local ROW_HEIGHT = 66
local LABEL_WIDTH = 0.44
local HEADER_HEIGHT = 40
local KEY_BUTTON_WIDTH = 0.6 -- of the control area
local KEYS_HELP = "Click a key, then press the new key or mouse button (Escape cancels). Gamepad: RT attack, LT block, B roll."
local KEYS_NO_KEYBOARD = "Key bindings are for a keyboard and mouse. On a touch screen, move the buttons in Controls > Mobile Buttons."

local function formatValue(definition: any, value: number): string
	if definition.Unit == "x" then
		return string.format("x%.2f", value)
	end
	return tostring(math.floor(value + 0.5)) .. (definition.Unit or "")
end

local function row(page: Instance, order: number, label: string, hint: string?): Frame
	local frame = Instance.new("Frame")
	frame.Name = label
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.LayoutOrder = order
	Theme.text({ Name = "Label", Text = label, TextSize = 22, Align = "Left", Size = UDim2.new(LABEL_WIDTH, -8, if hint then 0.56 else 0.8, 0), Position = UDim2.new(0, 4, if hint then 0.06 else 0.1, 0), Parent = frame })
	if hint then
		Theme.text({ Name = "Hint", Text = hint, TextSize = 16, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(LABEL_WIDTH, -8, 0.34, 0), Position = UDim2.new(0, 4, 0.6, 0), Parent = frame })
	end
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundColor3 = Theme.Colors.WoodLine
	line.BorderSizePixel = 0
	line.Parent = frame
	frame.Parent = page
	return frame
end

local function control(frame: Frame): Frame
	local area = Instance.new("Frame")
	area.Name = "Control"
	area.BackgroundTransparency = 1
	area.AnchorPoint = Vector2.new(1, 0.5)
	area.Position = UDim2.fromScale(1, 0.5)
	area.Size = UDim2.new(1 - LABEL_WIDTH, 0, 0, Theme.TOUCH)
	area.Parent = frame
	return area
end

local function numberRow(page: Instance, order: number, definition: any)
	local area = control(row(page, order, definition.Label, definition.Hint))
	local slider = Slider.new({
		Min = definition.Min,
		Max = definition.Max,
		Step = definition.Step,
		Value = Settings.get(definition.Key),
		Format = function(v: number): string
			return formatValue(definition, v)
		end,
		OnChanged = function(v: number)
			Settings.set(definition.Key, v)
		end,
		Parent = area,
	})
	Settings.changed(definition.Key, function(value)
		if slider.Value ~= value then
			slider:Set(value)
		end
	end)
end

local function booleanRow(page: Instance, order: number, definition: any)
	local area = control(row(page, order, definition.Label, definition.Hint))
	local toggle = Toggle.new({
		Value = Settings.get(definition.Key) == true,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		OnChanged = function(value: boolean)
			local ok, result = Settings.set(definition.Key, value)
			if not ok then
				Notifier.push({ Kind = "error", Text = tostring(result) })
			end
		end,
		Parent = area,
	})
	Settings.changed(definition.Key, function(value)
		if toggle.Value ~= value then
			toggle:Set(value == true)
		end
	end)
	if definition.RequiresPass then
		State.observe("Passes", function(passes)
			local owned = typeof(passes) == "table" and passes[definition.RequiresPass] == true
			toggle:SetEnabled(owned)
		end)
	end
end

local function layoutRow(page: Instance, order: number)
	local area = control(row(page, order, "Mobile Buttons", "Move and resize Attack, Roll and Block"))
	Button.new({ Text = "Edit layout", Style = "secondary", Size = UDim2.new(1, -8, 1, 0), Parent = area, OnClick = Controls.editLayout })
end

local function textRow(page: Instance, order: number, text: string, height: number, title: boolean?)
	local frame = Instance.new("Frame")
	frame.Name = if title then text else "Help"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.LayoutOrder = order
	Theme.text({
		Font = if title then "Title" else nil,
		Text = text,
		TextSize = if title then 26 else 18,
		Color = if title then Theme.Colors.Gold else Theme.Colors.TextDim,
		Wrapped = not title,
		Align = "Left",
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		Parent = frame,
	})
	frame.Parent = page
end

local function keysPage(page: Instance)
	if not (UserInputService.KeyboardEnabled or UserInputService.MouseEnabled) then
		textRow(page, 1, KEYS_NO_KEYBOARD, ROW_HEIGHT)
		return
	end
	textRow(page, 1, KEYS_HELP, ROW_HEIGHT)
	local keyButtons: { [string]: any } = {}
	local waiting: string? = nil
	local function paint()
		local bindings = SettingsConfig.cleanKeys(Settings.get("KeyBindings"))
		for id, button in pairs(keyButtons) do
			if id ~= waiting then
				button:SetText(Controls.keyLabel(bindings[id]))
				button:SetStyle("secondary")
			end
		end
	end
	local order = 1
	for _, group in ipairs(SettingsConfig.KEY_GROUPS) do
		order += 1
		textRow(page, order, group, HEADER_HEIGHT, true)
		for _, action in ipairs(SettingsConfig.KEY_ACTIONS) do
			if action.Group == group then
				order += 1
				local area = control(row(page, order, action.Label))
				keyButtons[action.Id] = Button.new({ Name = action.Id, Text = "", Style = "secondary", Size = UDim2.new(KEY_BUTTON_WIDTH, 0, 1, 0), Parent = area, OnClick = function()
					waiting = action.Id
					paint()
					local button = keyButtons[action.Id]
					button:SetText("Press a key...")
					button:SetStyle("primary")
					Controls.capture(function(name: string?)
						if waiting == action.Id then
							waiting = nil
						end
						if name then
							local before = SettingsConfig.cleanKeys(Settings.get("KeyBindings"))
							local ok, result = SettingsConfig.assignKey(before, action.Id, name)
							if ok then
								Settings.set("KeyBindings", result)
								for _, other in ipairs(SettingsConfig.KEY_ACTIONS) do
									if other.Id ~= action.Id and result[other.Id] ~= before[other.Id] then
										Notifier.push({ Kind = "info", Text = `{other.Label}: {Controls.keyLabel(result[other.Id])}` })
									end
								end
							else
								Notifier.push({ Kind = "error", Text = tostring(result) })
							end
						end
						paint()
					end)
				end })
			end
		end
	end
	order += 1
	local resetArea = control(row(page, order, "Reset keys", "Every key back to default"))
	Button.new({ Text = "Reset", Style = "danger", Size = UDim2.new(KEY_BUTTON_WIDTH, 0, 1, 0), Parent = resetArea, OnClick = function()
		Settings.set("KeyBindings", SettingsConfig.defaultKeys())
		Notifier.push({ Kind = "info", Text = "Keys reset" })
	end })
	paint()
	Settings.changed("KeyBindings", paint)
end

local function otherPage(page: Instance)
	local codeRow = row(page, 1, "Redeem Code")
	local area = control(codeRow)
	local box = Instance.new("TextBox")
	box.Name = "Code"
	box.Size = UDim2.new(0.6, -8, 1, 0)
	box.BackgroundColor3 = Theme.Colors.WoodLine
	box.TextColor3 = Theme.Colors.Text
	box.PlaceholderColor3 = Theme.Colors.TextDim
	box.PlaceholderText = "Enter a code"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.FontFace = Theme.Fonts.Body
	box.TextScaled = true
	Theme.limit(box, 22)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = box
	Theme.corner(box, 6)
	Theme.stroke(box, Theme.Colors.GoldDark, 2)
	box.Parent = area
	Button.new({ Text = "Redeem", Style = "primary", Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Parent = area, OnClick = function()
		local ok, message = Net.request("RedeemCode", box.Text)
		Notifier.push({ Kind = if ok then "reward" else "error", Text = tostring(message or (if ok then "Code redeemed!" else "Invalid code")) })
	end })

	local resetArea = control(row(page, 2, "Reset UI layout", "UI Scale and mobile buttons back to default"))
	Button.new({ Text = "Reset", Style = "danger", Size = UDim2.new(1, -8, 1, 0), Parent = resetArea, OnClick = function()
		Settings.set("ButtonLayout", SettingsConfig.defaultLayout())
		Settings.set("UiScale", SettingsConfig.ById.UiScale.Default)
		Notifier.push({ Kind = "info", Text = "UI layout reset" })
	end })
end

function SettingsPage.build(ctx: any)
	local orders: { [string]: number } = {}
	for _, definition in ipairs(SettingsConfig.Definitions) do
		local page = ctx.Pages[definition.Section]
		if page then
			local order = (orders[definition.Section] or 0) + 1
			orders[definition.Section] = order
			if definition.Type == "number" then
				numberRow(page, order, definition)
			elseif definition.Type == "boolean" then
				booleanRow(page, order, definition)
			elseif definition.Type == "layout" then
				layoutRow(page, order)
			end
		end
	end
	keysPage(ctx.Pages.Keys)
	otherPage(ctx.Pages.Other)
end

return SettingsPage
