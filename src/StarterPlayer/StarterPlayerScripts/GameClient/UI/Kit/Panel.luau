--!strict
-- Wood panel (realistic wood, owner 2026-10-13): tiled walnut planks lit from above, gold border, iron corner
-- brackets, optional inner inset of dark-grain wood.
--   Panel.new({ Size, Position, AnchorPoint, Parent, Name, Gems = true (corner brackets), Inset = false,
--               InsetPadding = 8, ZIndex, Texture = "Panel" | "Light" | "Inset" }) -> frame, inset?
--   Panel.wood(frame, kind?, tile?, corner?) -> ImageLabel: the tiled texture behind any frame's content
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local Panel = {}

local BRACKET = 30 -- iron corner size (design units)
-- { x, y, rotation } of the four brackets (the image is the top-left one)
local CORNERS = { { 0, 0, 0 }, { 1, 0, 90 }, { 1, 1, 180 }, { 0, 1, 270 } }
local TILE = { Panel = 256, Inset = 256, Light = 200 }
local LIGHT_BOTTOM = Color3.fromRGB(176, 170, 164) -- the bottom of a panel is a bit darker (light from above)

-- A tiled wood texture under the frame's other children (ZIndex below them; children always draw above
-- their parent, so the frame itself stays behind).
function Panel.wood(frame: GuiObject, kind: string?, tile: number?, corner: number?): ImageLabel
	local name = kind or "Panel"
	local image = Instance.new("ImageLabel")
	image.Name = "WoodTexture"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Size = UDim2.fromScale(1, 1)
	image.Image = Icons.Tex["Wood" .. name] or Icons.Tex.WoodPanel
	image.ScaleType = Enum.ScaleType.Tile
	local size = tile or TILE[name] or 256
	image.TileSize = UDim2.fromOffset(size, size)
	image.ZIndex = frame.ZIndex - 1
	local light = Instance.new("UIGradient")
	light.Color = ColorSequence.new(Color3.new(1, 1, 1), LIGHT_BOTTOM)
	light.Rotation = 90
	light.Parent = image
	if (corner or Theme.CORNER) > 0 then
		Theme.corner(image, corner or Theme.CORNER)
	end
	image.Parent = frame
	return image
end

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
	-- the flat gradient stays under the texture (shows while the image loads)
	Theme.gradient(frame, colors.WoodTop, colors.WoodBottom)
	Theme.corner(frame, props.Corner or Theme.CORNER)
	Panel.wood(frame, props.Texture or "Panel", nil, props.Corner)
	local border = Theme.stroke(frame, colors.GoldLight, props.BorderThickness or Theme.BORDER)
	Theme.gradient(border, colors.GoldLight, colors.GoldDark)

	if props.Gems ~= false then
		local size = props.GemSize and props.GemSize * 2.6 or BRACKET
		for _, spot in ipairs(CORNERS) do
			local bracket = Instance.new("ImageLabel")
			bracket.Name = "Bracket"
			bracket.BackgroundTransparency = 1
			bracket.Image = Icons.Tex.IronCorner
			bracket.AnchorPoint = Vector2.new(0.5, 0.5)
			-- centered a little inside the corner so the bracket sits on the border
			bracket.Position = UDim2.new(spot[1], (if spot[1] == 0 then 1 else -1) * (size / 2 - 5), spot[2], (if spot[2] == 0 then 1 else -1) * (size / 2 - 5))
			bracket.Size = UDim2.fromOffset(size, size)
			bracket.Rotation = spot[3]
			bracket.ZIndex = frame.ZIndex + 2
			bracket.Parent = frame
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
