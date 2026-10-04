--!strict
-- Wood panel: dark brown gradient, gold border, gem accents in the corners, optional inner inset.
--   Panel.new({ Size, Position, AnchorPoint, Parent, Name, Gems = true, Inset = false,
--               InsetPadding = 8, ZIndex }) -> frame, inset?
local Theme = require(script.Parent.Theme)

local Panel = {}

local GEMS = { { 0, 0, "Ruby" }, { 1, 0, "Sapphire" }, { 0, 1, "Amethyst" }, { 1, 1, "Ruby" } }

function Panel.new(props: { [string]: any }): (Frame, Frame?)
	local colors = Theme.Colors
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.Size = props.Size or UDim2.fromOffset(300, 200)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.ZIndex = props.ZIndex or 1
	if props.LayoutOrder then
		frame.LayoutOrder = props.LayoutOrder
	end
	Theme.gradient(frame, colors.WoodTop, colors.WoodBottom)
	Theme.corner(frame, props.Corner or Theme.CORNER)
	local border = Theme.stroke(frame, colors.GoldLight, props.BorderThickness or Theme.BORDER)
	Theme.gradient(border, colors.GoldLight, colors.GoldDark)

	if props.Gems ~= false then
		for _, gem in ipairs(GEMS) do
			local stone = Instance.new("Frame")
			stone.Name = "Gem"
			stone.AnchorPoint = Vector2.new(0.5, 0.5)
			stone.Position = UDim2.fromScale(gem[1], gem[2])
			stone.Size = UDim2.fromOffset(props.GemSize or 11, props.GemSize or 11)
			stone.Rotation = 45
			stone.BackgroundColor3 = colors[gem[3]]
			stone.BorderSizePixel = 0
			stone.ZIndex = frame.ZIndex + 2
			Theme.corner(stone, 2)
			Theme.stroke(stone, colors.GoldDark, 1.5)
			stone.Parent = frame
		end
	end

	local inset: Frame? = nil
	if props.Inset then
		local pad = props.InsetPadding or 8
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.Position = UDim2.fromOffset(pad, props.InsetTop or pad)
		content.Size = UDim2.new(1, -2 * pad, 1, -(props.InsetTop or pad) - pad)
		content.BackgroundColor3 = colors.WoodInset
		content.BorderSizePixel = 0
		content.ZIndex = frame.ZIndex
		Theme.corner(content, 4)
		Theme.stroke(content, colors.WoodLine, 1.5)
		content.Parent = frame
		inset = content
	end
	frame.Parent = props.Parent
	return frame, inset
end

return Panel
