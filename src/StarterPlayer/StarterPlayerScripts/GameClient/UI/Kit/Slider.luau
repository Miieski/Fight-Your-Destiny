--!strict
-- Horizontal slider with a 56-unit tall touch area. OnChanged fires live while dragging,
-- OnCommit when the finger / mouse is released.
--   Slider.new({ Min, Max, Step, Value, Parent, Size, LayoutOrder, Format = fn(v) -> string,
--                OnChanged = fn(v), OnCommit = fn(v) })   slider:Set(v)
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Slider = {}
Slider.__index = Slider

local VALUE_WIDTH = 88

export type Slider = typeof(setmetatable({} :: {
	Instance: TextButton,
	Value: number,
	_min: number,
	_max: number,
	_step: number,
	_track: Frame,
	_fill: Frame,
	_knob: Frame,
	_label: TextLabel,
	_format: (number) -> string,
}, Slider))

function Slider.new(props: { [string]: any }): Slider
	local colors = Theme.Colors
	local root = Instance.new("TextButton")
	root.Name = props.Name or "Slider"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = props.Size or UDim2.new(1, 0, 0, Theme.TOUCH)
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 14, 0.5, 0)
	track.Size = UDim2.new(1, -(VALUE_WIDTH + 28), 0, 12)
	track.BackgroundColor3 = colors.WoodLine
	track.BorderSizePixel = 0
	Theme.round(track)
	Theme.stroke(track, colors.GoldDark, 1.5)
	track.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	Theme.round(fill)
	Theme.gradient(fill, colors.GoldFace, colors.GoldDark)
	fill.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(28, 28)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	Theme.round(knob)
	Theme.gradient(knob, colors.GoldFace, colors.GoldDark)
	Theme.stroke(knob, colors.Ink, 2)
	knob.Parent = track

	local label = Theme.text({ Name = "ValueLabel", Font = "Number", TextSize = 20, Align = "Right", Size = UDim2.new(0, VALUE_WIDTH, 0.7, 0), Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = root })

	local self = setmetatable({
		Instance = root,
		Value = props.Value or props.Min,
		_min = props.Min,
		_max = props.Max,
		_step = props.Step or 1,
		_track = track,
		_fill = fill,
		_knob = knob,
		_label = label,
		_format = props.Format or function(v: number): string
			return tostring(v)
		end,
	}, Slider)
	self:Set(self.Value)

	local dragging: InputObject? = nil
	local function valueAt(x: number): number
		local width = track.AbsoluteSize.X
		local t = if width > 0 then math.clamp((x - track.AbsolutePosition.X) / width, 0, 1) else 0
		local raw = self._min + t * (self._max - self._min)
		local stepped = self._min + math.floor((raw - self._min) / self._step + 0.5) * self._step
		return math.clamp(stepped, self._min, self._max)
	end
	local function update(x: number)
		local value = valueAt(x)
		if value ~= self.Value then
			self:Set(value)
			if props.OnChanged then
				props.OnChanged(value)
			end
		end
	end
	local function finish()
		if dragging then
			dragging = nil
			if props.OnCommit then
				props.OnCommit(self.Value)
			end
		end
	end
	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			update(input.Position.X)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if (dragging.UserInputType == Enum.UserInputType.Touch and input == dragging)
			or (dragging.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			update(input.Position.X)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or (dragging.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
			finish()
		end
	end)
	root.Destroying:Connect(function()
		moved:Disconnect()
		ended:Disconnect()
	end)
	root.Parent = props.Parent
	return self
end

function Slider.Set(self: Slider, value: number)
	self.Value = math.clamp(value, self._min, self._max)
	local t = if self._max > self._min then (self.Value - self._min) / (self._max - self._min) else 0
	self._fill.Size = UDim2.fromScale(t, 1)
	self._knob.Position = UDim2.fromScale(t, 0.5)
	self._label.Text = self._format(self.Value)
end

return Slider
