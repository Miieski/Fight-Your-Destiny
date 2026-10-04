--!strict
-- Red notification dot with a count, in the top-right corner of its parent. Hidden at 0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Theme = require(script.Parent.Theme)

local Badge = {}
Badge.__index = Badge

export type Badge = typeof(setmetatable({} :: { Instance: Frame, Label: TextLabel }, Badge))

function Badge.new(parent: Instance, size: number?): Badge
	local dot = Instance.new("Frame")
	dot.Name = "Badge"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromOffset(size or 24, size or 24)
	dot.BackgroundColor3 = Theme.Colors.Badge
	dot.BorderSizePixel = 0
	dot.ZIndex = 10
	dot.Visible = false
	Theme.round(dot)
	Theme.stroke(dot, Theme.Colors.Text, 2)
	local label = Theme.text({ Name = "Count", Font = "Number", TextSize = 16, Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11, Parent = dot })
	dot.Parent = parent
	return setmetatable({ Instance = dot, Label = label }, Badge)
end

function Badge.Set(self: Badge, count: number?)
	local n = math.max(0, math.floor(count or 0))
	self.Instance.Visible = n > 0
	self.Label.Text = if n > UIConfig.BADGE_MAX_SHOWN then UIConfig.BADGE_MAX_SHOWN .. "+" else tostring(n)
end

return Badge
