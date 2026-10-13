--!strict
-- The Bonus Stats items on a pet model clone (Config/PetTraits, owner 2026-10-13). Client-side only.
--   PetGear.apply(model, gear, opts?)   gear = { Crown = tier, Accessory = tier, Aura = tier } (PetTraits.parseGearKey)
--                                       opts = { Static: boolean?, LowFx: boolean? }
-- The crown sits on top of the head, the accessory at the neck (rings around it, bows / medals in front), the aura
-- is a particle cloud around the body (not drawn when Static: ViewportFrames show no particles, or with Low FX).
-- Item models: ReplicatedStorage.Assets.PetGear.<item Id> (AI-generated, upright, front = -Z). Their parts become
-- children of the Head (or Body) piece, so Util/PetMotion and PivotTo move them with it; call it after
-- ScaleTo / PetLook.apply and before PetMotion.new.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetTraits = require(script.Parent.Parent.Config.PetTraits)

local PetGear = {}

-- accessories worn in front of the neck (the others are rings around it)
local FRONT = { BowTie = true, GoldMedal = true, StarPendant = true, Scarf = true }
-- crowns that sit lower on the head (share of their height inside it; default 0.25): the crescent is a hairband
local SINK = { HermitsCrescent = 0.6 }
local HALO_COLOR = Color3.fromRGB(255, 222, 110) -- the Angel Halo glows (neon, no texture)

-- aura particles per item: color(s), texture, size, rate, lifetime, speed, acceleration (y), light emission
local PARTICLES = "rbxasset://textures/particles/"
local AURAS: { [string]: { [string]: any } } = {
	DustAura = { Colors = { Color3.fromRGB(176, 150, 118), Color3.fromRGB(120, 104, 86) }, Texture = "smoke_main.dds", Size = 0.5, Rate = 5, Life = 1.4, Speed = 0.4, Rise = 0.3, Glow = 0 },
	LeafAura = { Colors = { Color3.fromRGB(120, 220, 90), Color3.fromRGB(60, 160, 60) }, Texture = "sparkles_main.dds", Size = 0.35, Rate = 5, Life = 1.6, Speed = 0.6, Rise = -0.4, Glow = 0.2 },
	BubbleAura = { Colors = { Color3.fromRGB(150, 220, 255), Color3.fromRGB(90, 170, 255) }, Texture = "sparkles_main.dds", Size = 0.35, Rate = 6, Life = 1.8, Speed = 0.3, Rise = 0.9, Glow = 0.3 },
	FrostAura = { Colors = { Color3.fromRGB(235, 250, 255), Color3.fromRGB(150, 210, 255) }, Texture = "sparkles_main.dds", Size = 0.4, Rate = 7, Life = 1.6, Speed = 0.5, Rise = -0.6, Glow = 0.4 },
	EmberAura = { Colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 90, 30) }, Texture = "fire_sparks_main.dds", Size = 0.35, Rate = 9, Life = 1.1, Speed = 0.8, Rise = 1.6, Glow = 0.7 },
	ThunderAura = { Colors = { Color3.fromRGB(255, 250, 150), Color3.fromRGB(120, 200, 255) }, Texture = "sparkles_main.dds", Size = 0.5, Rate = 12, Life = 0.35, Speed = 2.2, Rise = 0, Glow = 0.9 },
	HolyAura = { Colors = { Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 205, 90) }, Texture = "sparkles_main.dds", Size = 0.45, Rate = 10, Life = 1.8, Speed = 0.4, Rise = 1.0, Glow = 0.9, Light = Color3.fromRGB(255, 225, 150) },
	CosmicAura = { Colors = { Color3.fromRGB(255, 120, 220), Color3.fromRGB(140, 120, 255), Color3.fromRGB(110, 230, 255) }, Texture = "sparkles_main.dds", Size = 0.5, Rate = 12, Life = 2.0, Speed = 0.5, Rise = 0.4, Glow = 1, Light = Color3.fromRGB(190, 140, 255) },
}

-- the box of a part in the root's space: center, size (axis-aligned there)
local function boxIn(root: CFrame, part: BasePart): (Vector3, Vector3)
	local cf = root:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	local r, u, l = cf.RightVector * half.X, cf.UpVector * half.Y, cf.LookVector * half.Z
	local ext = Vector3.new(
		math.abs(r.X) + math.abs(u.X) + math.abs(l.X),
		math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y),
		math.abs(r.Z) + math.abs(u.Z) + math.abs(l.Z)
	)
	return cf.Position, ext * 2
end

local function piece(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- Clones an item model, scales it to `width` (its widest side across X / Z) but no taller than `maxHeight`, puts
-- its box center where `place` says (root space) and gives its parts to `holder`.
local function wear(itemId: string, holder: BasePart, root: CFrame, width: number, maxHeight: number, place: (size: Vector3) -> Vector3): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("PetGear")
	local source = folder and folder:FindFirstChild(itemId)
	if not (source and source:IsA("Model")) then
		return false
	end
	local clone = source:Clone()
	local _, size = clone:GetBoundingBox()
	local widest = math.max(size.X, size.Z, 0.01)
	local factor = math.min(width / widest, maxHeight / math.max(size.Y, 0.01))
	clone:ScaleTo(clone:GetScale() * factor)
	local box, scaled = clone:GetBoundingBox()
	local fromBox = box:ToObjectSpace(clone:GetPivot())
	clone:PivotTo(root * CFrame.new(place(scaled)) * fromBox)
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = holder.Anchored
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
			item.CastShadow = false
			item:SetAttribute("PetGear", itemId)
			if itemId == "AngelHalo" and item:IsA("MeshPart") then
				item.TextureID = ""
				item.Color = HALO_COLOR
				item.Material = Enum.Material.Neon
			end
			item.Parent = holder
		end
	end
	clone:Destroy()
	return true
end

local function aura(itemId: string, body: BasePart, tier: number)
	local style = AURAS[itemId]
	if not style then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PetAura"
	attachment.Parent = body
	local keypoints = {}
	for i, color in ipairs(style.Colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#style.Colors - 1, 1), color))
	end
	local scale = math.max(body.Size.X, body.Size.Z) * 0.6
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Texture = PARTICLES .. style.Texture
	emitter.Color = ColorSequence.new(keypoints)
	emitter.LightEmission = style.Glow
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, style.Size * scale), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(style.Life * 0.7, style.Life)
	emitter.Rate = style.Rate * (1 + (tier - 1) * 0.15)
	emitter.Speed = NumberRange.new(style.Speed * 0.5, style.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, style.Rise, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.LockedToPart = false
	emitter.Parent = attachment
	if style.Light then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = style.Light
		light.Range = 6
		light.Brightness = 0.8
		light.Parent = attachment
	end
end

-- a few sparkles on a Legendary or better crown / accessory
local function sparkle(holder: BasePart, tier: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "GearSparkle"
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = PARTICLES .. "sparkles_main.dds"
	emitter.Color = ColorSequence.new(PetTraits.rarity(tier).Color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = 3 + tier
	emitter.Speed = NumberRange.new(0.2, 0.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = attachment
end

function PetGear.apply(model: Model, gear: { [string]: number }?, opts: { Static: boolean?, LowFx: boolean? }?)
	if not gear then
		return
	end
	local static = opts ~= nil and opts.Static == true
	local lowFx = opts ~= nil and opts.LowFx == true
	local rootPart = model.PrimaryPart
	local head = piece(model, "Head")
	local body = piece(model, "Body") or head or rootPart
	if not (rootPart and body) then
		return
	end
	local top = head or body
	local root = rootPart.CFrame
	local center, size = boxIn(root, top)
	local width = math.max(size.X, size.Z)

	-- crown: on top of the head (the halo floats a little above it)
	local crownTier = gear.Crown
	if crownTier then
		local item = PetTraits.ITEMS.Crown[crownTier]
		if item then
			local halo = item.Id == "AngelHalo"
			local ok = wear(item.Id, top, root, width * (if halo then 0.55 else 0.56), size.Y * 0.6, function(s: Vector3): Vector3
				local y = center.Y + size.Y / 2 + (if halo then size.Y * 0.08 + s.Y / 2 else s.Y * (0.5 - (SINK[item.Id] or 0.25)))
				return Vector3.new(center.X, y, center.Z)
			end)
			if ok and crownTier >= 5 and not (static or lowFx) then
				sparkle(top, crownTier)
			end
		end
	end

	-- accessory: at the neck (where the head meets the body)
	local accessoryTier = gear.Accessory
	if accessoryTier then
		local item = PetTraits.ITEMS.Accessory[accessoryTier]
		if item then
			local front = FRONT[item.Id] == true
			local holder = head or body
			-- the bottom of the head box (bodies without a head: their upper part)
			local neckY = if head then center.Y - size.Y * 0.48 else center.Y + size.Y * 0.2
			local ok = wear(item.Id, holder, root, size.X * (if front then 0.42 else 0.78), size.Y * (if front then 0.45 else 0.32), function(s: Vector3): Vector3
				if front then
					-- -Z is the front: just under the chin
					return Vector3.new(center.X, neckY + s.Y * 0.1, center.Z - size.Z * 0.4 - s.Z * 0.3)
				end
				return Vector3.new(center.X, neckY, center.Z)
			end)
			if ok and accessoryTier >= 5 and not (static or lowFx) then
				sparkle(holder, accessoryTier)
			end
		end
	end

	-- aura: particles around the body
	local auraTier = gear.Aura
	if auraTier and not (static or lowFx) then
		local item = PetTraits.ITEMS.Aura[auraTier]
		if item then
			aura(item.Id, body, auraTier)
		end
	end
end

return PetGear
