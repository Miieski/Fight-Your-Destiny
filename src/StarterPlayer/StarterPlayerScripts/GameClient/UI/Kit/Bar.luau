--!strict
-- Segmented bar (HP, progress). The fill tweens; when the value drops, a lighter trailing segment
-- shows the lost part for a moment.
--   local bar = Bar.new({ Size, Position, AnchorPoint, Parent, Color, TrailColor, Segments, ShowText })
--   bar:Set(current, max, instant?)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Theme = require(script.Parent.Theme)

local Bar = {}
Bar.__index = Bar

export type Bar = typeof(setmetatable({} :: {
	Instance: Frame,
	Fill: Frame,
	Trail: Frame,
	Text: TextLabel?,
	_fraction: number,
	_fillTween: Tween?,
	_trailTween: Tween?,
	_token: number,
}, Bar))

function Bar.new(props: { [string]: any }): Bar
	local colors = Theme.Colors
	local track = Instance.new("Frame")
	track.Name = props.Name or "Bar"
	track.Size = props.Size or UDim2.fromOffset(240, 24)
	track.Position = props.Position or UDim2.new()
	track.AnchorPoint = props.AnchorPoint or Vector2.zero
	track.BackgroundColor3 = colors.WoodInset
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	Theme.corner(track, 4)
	Theme.stroke(track, colors.Ink, 2)

	local trail = Instance.new("Frame")
	trail.Name = "Trail"
	trail.Size = UDim2.fromScale(1, 1)
	trail.BackgroundColor3 = props.TrailColor or colors.HealthTrail
	trail.BorderSizePixel = 0
	Theme.corner(trail, 4)
	trail.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	Theme.corner(fill, 4)
	local color: Color3 = props.Color or colors.Health
	local h, s, v = color:ToHSV()
	Theme.gradient(fill, Color3.fromHSV(h, s * 0.8, math.min(1, v * 1.2)), Color3.fromHSV(h, s, v * 0.75))
	fill.Parent = track

	local segments = props.Segments or UIConfig.Hud.HealthSegments
	for i = 1, segments - 1 do
		local line = Instance.new("Frame")
		line.Name = "Segment"
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.fromScale(i / segments, 0)
		line.Size = UDim2.new(0, 2, 1, 0)
		line.BackgroundColor3 = colors.Ink
		line.BackgroundTransparency = 0.45
		line.BorderSizePixel = 0
		line.ZIndex = 2
		line.Parent = track
	end

	local text: TextLabel? = nil
	if props.ShowText ~= false then
		text = Theme.text({ Name = "Value", Font = "Number", TextSize = props.TextSize or 18, Size = UDim2.fromScale(0.96, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = track })
	end
	track.Parent = props.Parent
	return setmetatable({ Instance = track, Fill = fill, Trail = trail, Text = text, _fraction = 1, _token = 0 }, Bar)
end

function Bar.Set(self: Bar, current: number, max: number, instant: boolean?)
	local fraction = if max > 0 then math.clamp(current / max, 0, 1) else 0
	if self.Text then
		self.Text.Text = Format.number(math.max(0, current)) .. " / " .. Format.number(max)
	end
	local hud = UIConfig.Hud
	local previous = self._fraction
	self._fraction = fraction
	if self._fillTween then
		self._fillTween:Cancel()
	end
	if self._trailTween then
		self._trailTween:Cancel()
	end
	if instant then
		self.Fill.Size = UDim2.fromScale(fraction, 1)
		self.Trail.Size = UDim2.fromScale(fraction, 1)
		return
	end
	self._fillTween = TweenService:Create(self.Fill, TweenInfo.new(hud.HealthTweenSeconds, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) })
	self._fillTween:Play()
	if fraction >= previous then
		self.Trail.Size = UDim2.fromScale(fraction, 1)
		return
	end
	self._token += 1
	local token = self._token
	task.delay(hud.TrailDelaySeconds, function()
		if token == self._token and self.Trail.Parent then
			self._trailTween = TweenService:Create(self.Trail, TweenInfo.new(hud.TrailTweenSeconds, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) })
			self._trailTween:Play()
		end
	end)
end

return Bar
