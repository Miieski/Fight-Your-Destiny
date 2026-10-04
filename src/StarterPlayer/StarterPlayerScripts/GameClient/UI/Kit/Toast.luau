--!strict
-- One notification card (UI/Notifier stacks them). Kinds: loot, reward, error, info, death.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local Toast = {}

local KIND_ICON = { loot = "Gift", reward = "Gold", error = "Warning", info = "Info", death = "Skull" }

local function kindColors(kind: string): (Color3, Color3, Color3)
	local c = Theme.Colors
	if kind == "error" then
		return c.DangerDark, c.DangerBase, c.GoldLight
	elseif kind == "death" then
		return Color3.fromRGB(70, 18, 22), Color3.fromRGB(34, 8, 10), c.DangerLight
	elseif kind == "reward" then
		return c.WoodTop, c.WoodBottom, c.Gold
	end
	return c.WoodTop, c.WoodBottom, c.GoldLight
end

-- Returns the card frame and its text label (the Notifier updates the text when toasts merge).
function Toast.create(data: { [string]: any }, width: number): (Frame, TextLabel)
	local kind = data.Kind or "info"
	local top, bottom, border = kindColors(kind)
	-- Transparent holder: the glow must sit behind the body, and children always draw over their parent.
	local card = Instance.new("Frame")
	card.Name = "Toast"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(width, UIConfig.Toast.Height)
	card.BackgroundTransparency = 1
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.BorderSizePixel = 0
	body.ZIndex = 2
	Theme.gradient(body, top, bottom)
	Theme.corner(body, 6)
	local stroke = Theme.stroke(body, border, 3)
	body.Parent = card
	if data.Rarity and kind == "loot" then
		Theme.paintRarity(stroke, data.Rarity)
		if Rarities.get(data.Rarity).Tier >= Rarities.GLOW_FROM then
			local glow = Instance.new("Frame")
			glow.Name = "Glow"
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.fromScale(0.5, 0.5)
			glow.Size = UDim2.new(1, 12, 1, 12)
			glow.BackgroundTransparency = 0.6
			glow.BorderSizePixel = 0
			glow.ZIndex = 1
			Theme.corner(glow, 10)
			Theme.paintRarity(glow, data.Rarity)
			glow.Parent = card
		end
	end
	Icons.create(data.Icon or KIND_ICON[kind] or "Info", body, { Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local label = Theme.text({
		Name = "Message",
		Text = data.Text or "",
		TextSize = 20,
		Wrapped = true,
		Align = "Left",
		Size = UDim2.new(1, -66, 1, -10),
		Position = UDim2.new(0, 56, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 3,
		Parent = body,
	})
	if data.Rarity and kind == "loot" then
		local rarity = Rarities.get(data.Rarity)
		if not rarity.Gradient then
			label.TextColor3 = rarity.Color
		end
	end
	return card, label
end

return Toast
