--!strict
-- Skill slot (docs/weapons_combat_brief.txt Phase 2): wood/gold square (or round touch button) with the skill
-- icon, or a 3D lock on a dark face when empty; a key label in the corner; a clockwise cooldown sweep with the
-- seconds left; a shake when the skill cannot be paid; a frame tinted by rarity or element.
--   local slot = SkillSlot.new({ Name, Size, Round?, Key?, LayoutOrder?, Position?, AnchorPoint?, Parent, OnActivate? })
--   slot:SetSkill(def?)  slot:SetFrame(color?)  slot:SetTier(tier?)  slot:SetKey(text?)
--   slot:StartCooldown(seconds)  slot:Shake()  slot:SetHighlight(on)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local SkillSlot = {}
SkillSlot.__index = SkillSlot

local SWEEP_COLOR = Color3.new(0, 0, 0)
local SWEEP_TRANSPARENCY = 0.35
local EMPTY_ICON_FADE = 0.35
local SHAKE = { Offset = 6, Steps = 6, StepSeconds = 0.035 }
local KEY_PILL = { Height = 0.36, MinWidth = 0.36, PerChar = 0.16, Pad = 0.1 } -- fractions of the slot size
local HIGHLIGHT_COLOR = Theme.Colors.Diamond

export type SkillSlot = typeof(setmetatable({} :: {
	Instance: TextButton,
	Box: Frame,
	Border: UIStroke,
	_icon: Frame?,
	_frameColor: Color3?,
	_tier: number?,
	_keyPill: Frame,
	_keyText: TextLabel,
	_halves: { UIGradient },
	_sweep: Frame,
	_seconds: TextLabel,
	_cooldownEnd: number,
	_cooldownTotal: number,
	_cooldownConn: RBXScriptConnection?,
	_shaking: boolean,
	_round: boolean,
}, SkillSlot))

-- One half of the sweep: a clipping frame holding a dark copy of the whole slot; its UIGradient (opaque on one
-- side of a line through the center) turns to show the right wedge.
local function sweepHalf(parent: Frame, left: boolean, round: boolean): UIGradient
	local clip = Instance.new("Frame")
	clip.Name = if left then "Left" else "Right"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(0.5, 1)
	clip.Position = UDim2.fromScale(if left then 0 else 0.5, 0)
	clip.ZIndex = parent.ZIndex
	local dark = Instance.new("Frame")
	dark.Name = "Dark"
	dark.BackgroundColor3 = SWEEP_COLOR
	dark.BackgroundTransparency = SWEEP_TRANSPARENCY
	dark.BorderSizePixel = 0
	dark.Size = UDim2.fromScale(2, 1)
	dark.Position = UDim2.fromScale(if left then 0 else -1, 0)
	dark.ZIndex = parent.ZIndex
	if round then
		Theme.round(dark)
	else
		Theme.corner(dark, Theme.CORNER)
	end
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = dark
	dark.Parent = clip
	clip.Parent = parent
	return gradient
end

function SkillSlot.new(props: { [string]: any }): SkillSlot
	local size = props.Size or Theme.TOUCH
	local round = props.Round == true
	local root = Instance.new("TextButton")
	root.Name = props.Name or "SkillSlot"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(size, size)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Theme.Colors.WoodInset
	box.BackgroundTransparency = if round then 0.15 else 0
	box.BorderSizePixel = 0
	if round then
		Theme.round(box)
	else
		Theme.corner(box, Theme.CORNER)
	end
	Theme.gradient(box, Theme.Colors.WoodTop, Theme.Colors.WoodInset)
	local border = Theme.stroke(box, Theme.Colors.GoldDark, 3)
	box.Parent = root

	-- cooldown sweep + seconds (above the icon)
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BackgroundTransparency = 1
	sweep.Size = UDim2.fromScale(1, 1)
	sweep.ZIndex = 3
	sweep.Visible = false
	local halves = { sweepHalf(sweep, false, round), sweepHalf(sweep, true, round) }
	sweep.Parent = box
	local seconds = Theme.text({ Name = "Seconds", Font = "Title", Text = "", TextSize = 30, Color = Theme.Colors.Text, Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = box })
	seconds.Visible = false

	-- key label (PC / gamepad), bottom-right corner
	local pill = Instance.new("Frame")
	pill.Name = "Key"
	pill.AnchorPoint = Vector2.new(1, 1)
	pill.Position = UDim2.new(1, 4, 1, 4)
	pill.Size = UDim2.fromScale(KEY_PILL.MinWidth, KEY_PILL.Height)
	pill.BackgroundColor3 = Theme.Colors.Ink
	pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0
	pill.ZIndex = 5
	Theme.corner(pill, 4)
	Theme.stroke(pill, Theme.Colors.GoldDark, 1.5)
	local keyText = Theme.text({ Name = "Text", Font = "Button", Text = "", TextSize = 22, Color = Theme.Colors.Gold, Size = UDim2.new(1, -4, 0.92, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Stroke = false, Parent = pill })
	pill.Visible = false
	pill.Parent = root

	local self = setmetatable({
		Instance = root,
		Box = box,
		Border = border,
		_icon = nil,
		_frameColor = nil,
		_tier = nil,
		_keyPill = pill,
		_keyText = keyText,
		_halves = halves,
		_sweep = sweep,
		_seconds = seconds,
		_cooldownEnd = 0,
		_cooldownTotal = 0,
		_cooldownConn = nil,
		_shaking = false,
		_round = round,
	}, SkillSlot)
	if props.OnActivate then
		root.Activated:Connect(props.OnActivate)
	end
	self:SetSkill(nil)
	self:SetKey(props.Key)
	root.Parent = props.Parent
	return self
end

-- def = a Config/Skills entry (Icon, Element) or nil for the empty look (3D lock on a dark face).
function SkillSlot.SetSkill(self: SkillSlot, def: { [string]: any }?)
	if self._icon then
		self._icon:Destroy()
		self._icon = nil
	end
	if def then
		self._icon = Icons.create(def.Icon or "Star", self.Box, { Size = UDim2.fromScale(0.74, 0.74), ZIndex = 2 })
		self.Box.BackgroundColor3 = Theme.Colors.WoodTop
	else
		local lock = Icons.create("Lock", self.Box, { Size = UDim2.fromScale(0.48, 0.48), ZIndex = 2 })
		Icons.setFaded(lock, EMPTY_ICON_FADE)
		self._icon = lock
		self.Box.BackgroundColor3 = Theme.Colors.WoodInset
	end
end

-- Frame tint: a rarity / element color, or nil for the default gold.
function SkillSlot.SetFrame(self: SkillSlot, color: Color3?)
	self._frameColor = color
	self._tier = nil
	local old = self.Border:FindFirstChild("RarityGradient")
	if old then
		old:Destroy()
	end
	self.Border.Color = color or Theme.Colors.GoldDark
	self.Border.Thickness = if color then 3.5 else 3
end

function SkillSlot.SetTier(self: SkillSlot, tier: number?)
	if not tier then
		self:SetFrame(nil)
		return
	end
	self._tier = tier
	self.Border.Thickness = 3.5
	Theme.paintRarity(self.Border, tier)
end

function SkillSlot.SetKey(self: SkillSlot, text: string?)
	local label = text or ""
	self._keyPill.Visible = label ~= ""
	self._keyText.Text = label
	-- the pill widens for long labels ("Left Alt"); the text scales inside it
	self._keyPill.Size = UDim2.fromScale(math.max(KEY_PILL.MinWidth, KEY_PILL.PerChar * #label + KEY_PILL.Pad), KEY_PILL.Height)
end

local function setSweep(self: SkillSlot, remaining: number)
	-- remaining fraction 1 -> 0: a dark wedge from 12 o'clock, clockwise over remaining x 360 degrees
	local angle = math.clamp(remaining, 0, 1) * 360
	self._halves[1].Rotation = math.min(angle, 180)
	self._halves[2].Rotation = math.max(angle, 180)
end

function SkillSlot.StartCooldown(self: SkillSlot, seconds: number)
	if self._cooldownConn then
		self._cooldownConn:Disconnect()
		self._cooldownConn = nil
	end
	if seconds <= 0 then
		self._sweep.Visible = false
		self._seconds.Visible = false
		return
	end
	self._cooldownTotal = seconds
	self._cooldownEnd = os.clock() + seconds
	self._sweep.Visible = true
	self._seconds.Visible = true
	local shown = -1
	self._cooldownConn = RunService.RenderStepped:Connect(function()
		local left = self._cooldownEnd - os.clock()
		if left <= 0 then
			if self._cooldownConn then
				self._cooldownConn:Disconnect()
				self._cooldownConn = nil
			end
			self._sweep.Visible = false
			self._seconds.Visible = false
			return
		end
		setSweep(self, left / self._cooldownTotal)
		-- tenths under 3 s, whole seconds above; the text only changes when the shown value changes
		local value = if left < 3 then math.ceil(left * 10) else math.ceil(left) * 10
		if value ~= shown then
			shown = value
			self._seconds.Text = if left < 3 then string.format("%.1f", value / 10) else tostring(value // 10)
		end
	end)
end

function SkillSlot.Shake(self: SkillSlot)
	if self._shaking then
		return
	end
	self._shaking = true
	local box = self.Box
	local info = TweenInfo.new(SHAKE.StepSeconds, Enum.EasingStyle.Sine)
	task.spawn(function()
		for step = 1, SHAKE.Steps do
			local offset = if step % 2 == 1 then SHAKE.Offset else -SHAKE.Offset
			if step == SHAKE.Steps then
				offset = 0
			end
			local tween = TweenService:Create(box, info, { Position = UDim2.new(0.5, offset, 0.5, 0) })
			tween:Play()
			tween.Completed:Wait()
		end
		box.Position = UDim2.fromScale(0.5, 0.5)
		self._shaking = false
	end)
end

-- Layout editor selection (touch buttons).
function SkillSlot.SetHighlight(self: SkillSlot, on: boolean)
	if on then
		local old = self.Border:FindFirstChild("RarityGradient")
		if old then
			old:Destroy()
		end
		self.Border.Color = HIGHLIGHT_COLOR
		self.Border.Thickness = 5
	elseif self._tier then
		self:SetTier(self._tier)
	else
		self:SetFrame(self._frameColor)
	end
end

return SkillSlot
