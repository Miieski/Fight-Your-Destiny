--!strict
-- Item slot: square frame with a rarity-colored border; Epic and above get a glow (animated for
-- Divine / Secret). slot:Set({ Icon, Tier }) or slot:Clear(iconId?).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local Slot = {}
Slot.__index = Slot

export type Slot = typeof(setmetatable({} :: {
	Instance: TextButton,
	Box: Frame,
	Glow: Frame,
	Border: UIStroke,
	_icon: Frame?,
	_onClick: (() -> ())?,
}, Slot))

function Slot.new(props: { [string]: any }): Slot
	local size = props.Size or Theme.TOUCH
	local root = Instance.new("TextButton")
	root.Name = props.Name or "Slot"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(size, size)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.new(1, 14, 1, 14)
	glow.BackgroundTransparency = 0.55
	glow.BorderSizePixel = 0
	glow.Visible = false
	Theme.corner(glow, 10)
	glow.Parent = root

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Theme.Colors.WoodInset
	box.BorderSizePixel = 0
	Theme.corner(box, 6)
	Theme.gradient(box, Theme.Colors.WoodTop, Theme.Colors.WoodInset)
	local border = Theme.stroke(box, Theme.Colors.GoldDark, 3)
	box.Parent = root

	local self = setmetatable({ Instance = root, Box = box, Glow = glow, Border = border, _icon = nil, _onClick = props.OnClick }, Slot)
	root.Activated:Connect(function()
		if self._onClick then
			self._onClick()
		end
	end)
	root.Parent = props.Parent
	return self
end

function Slot._setIcon(self: Slot, id: string?)
	if self._icon then
		self._icon:Destroy()
		self._icon = nil
	end
	if id then
		self._icon = Icons.create(id, self.Box, { Size = UDim2.fromScale(0.72, 0.72) })
	end
end

function Slot.Set(self: Slot, item: { Icon: string, Tier: number })
	local rarity = Rarities.get(item.Tier)
	self:_setIcon(item.Icon)
	self.Border.Thickness = 3
	Theme.paintRarity(self.Border, rarity.Tier)
	self.Glow.Visible = rarity.Tier >= Rarities.GLOW_FROM
	if self.Glow.Visible then
		Theme.paintRarity(self.Glow, rarity.Tier)
	end
	self.Box.BackgroundColor3 = if rarity.Tier == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
end

function Slot.Clear(self: Slot, iconId: string?)
	self:_setIcon(iconId)
	local old = self.Border:FindFirstChild("RarityGradient")
	if old then
		old:Destroy()
	end
	self.Border.Color = Theme.Colors.GoldDark
	self.Border.Thickness = 2
	self.Glow.Visible = false
	self.Box.BackgroundColor3 = Theme.Colors.WoodInset
end

return Slot
