--!strict
-- On/off switch with a 56-unit touch area. Disabled toggles are greyed out and ignore taps.
--   Toggle.new({ Value, Parent, LayoutOrder, Enabled = true, OnChanged = fn(bool) })
--   toggle:Set(value), toggle:SetEnabled(bool)
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Toggle = {}
Toggle.__index = Toggle

local WIDTH, HEIGHT, KNOB = 84, 36, 30

export type Toggle = typeof(setmetatable({} :: {
	Instance: TextButton,
	Value: boolean,
	Enabled: boolean,
	_track: Frame,
	_knob: Frame,
}, Toggle))

function Toggle.new(props: { [string]: any }): Toggle
	local root = Instance.new("TextButton")
	root.Name = props.Name or "Toggle"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(WIDTH + 12, Theme.TOUCH)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	track.BorderSizePixel = 0
	Theme.round(track)
	Theme.stroke(track, Theme.Colors.Ink, 2)
	track.Parent = root
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(KNOB, KNOB)
	knob.BackgroundColor3 = Theme.Colors.Text
	knob.BorderSizePixel = 0
	Theme.round(knob)
	Theme.stroke(knob, Theme.Colors.Ink, 1.5)
	knob.Parent = track

	local self = setmetatable({ Instance = root, Value = props.Value == true, Enabled = props.Enabled ~= false, _track = track, _knob = knob }, Toggle)
	self:_paint(true)
	root.Activated:Connect(function()
		if self.Enabled then
			self:Set(not self.Value)
			if props.OnChanged then
				props.OnChanged(self.Value)
			end
		end
	end)
	root.Parent = props.Parent
	return self
end

function Toggle._paint(self: Toggle, instant: boolean?)
	local colors = Theme.Colors
	local color = if not self.Enabled then colors.DisabledDark elseif self.Value then colors.GoldLight else colors.SteelBase
	local position = if self.Value then UDim2.new(1, -KNOB - 3, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
	if instant then
		self._track.BackgroundColor3 = color
		self._knob.Position = position
	else
		local info = TweenInfo.new(0.12)
		TweenService:Create(self._track, info, { BackgroundColor3 = color }):Play()
		TweenService:Create(self._knob, info, { Position = position }):Play()
	end
	self._knob.BackgroundColor3 = if self.Enabled then colors.Text else colors.DisabledLight
end

function Toggle.Set(self: Toggle, value: boolean)
	self.Value = value
	self:_paint()
end

function Toggle.SetEnabled(self: Toggle, enabled: boolean)
	self.Enabled = enabled
	self:_paint(true)
end

return Toggle
