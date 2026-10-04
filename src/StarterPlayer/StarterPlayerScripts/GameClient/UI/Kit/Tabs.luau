--!strict
-- Row of tab buttons; the selected one is gold, the others steel.
--   local tabs = Tabs.new({ Tabs = { "A", "B" }, Parent, Size, Position, OnSelect = function(name) end })
--   tabs:Select(name, silent?)
local Button = require(script.Parent.Button)
local Theme = require(script.Parent.Theme)

local Tabs = {}
Tabs.__index = Tabs

export type Tabs = typeof(setmetatable({} :: { Instance: Frame, Selected: string?, _buttons: { [string]: any }, _onSelect: ((string) -> ())? }, Tabs))

function Tabs.new(props: { [string]: any }): Tabs
	local row = Instance.new("Frame")
	row.Name = "Tabs"
	row.BackgroundTransparency = 1
	row.Size = props.Size or UDim2.new(1, 0, 0, Theme.TOUCH)
	row.Position = props.Position or UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local self = setmetatable({ Instance = row, Selected = nil, _buttons = {}, _onSelect = props.OnSelect }, Tabs)
	local count = #props.Tabs
	for i, name in ipairs(props.Tabs) do
		self._buttons[name] = Button.new({
			Name = name,
			Text = name,
			Style = "secondary",
			TextSize = 22,
			LayoutOrder = i,
			Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0),
			OnClick = function()
				self:Select(name)
			end,
			Parent = row,
		})
	end
	row.Parent = props.Parent
	return self
end

function Tabs.Select(self: Tabs, name: string, silent: boolean?)
	if not self._buttons[name] then
		return
	end
	self.Selected = name
	for tabName, button in pairs(self._buttons) do
		button:SetStyle(if tabName == name then "primary" else "secondary")
	end
	if not silent and self._onSelect then
		self._onSelect(name)
	end
end

return Tabs
