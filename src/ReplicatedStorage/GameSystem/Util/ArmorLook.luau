--!strict
-- Procedural armor on an R15 body (docs/menu_systems_brief.txt C4). Placeholders until the 36 Blender models:
-- low-poly shapes in the zone palette (Config/Armor Palette), trims and glow lines in the rarity color, a soft
-- shimmer from Epic. Every size comes from the body part it covers, so any avatar scale fits.
--   ArmorLook.apply(model, { Helmet = { id, tier }?, Chest = ..., Legs = ... }, { Weld = true?, LowFx = bool? })
--       Weld = true: welded to the moving body (live characters); otherwise anchored where the body stands
--       (static models: the Equipment screen avatar, item icons). Returns the "ArmorLook" folder.
--   ArmorLook.clear(model)
-- While a helmet is worn, the accessories attached to the head (hats, hair, big-head accessories) are hidden
-- (their transparency comes back on clear), so the helmet is not buried inside them.
--   ArmorLook.parse("Helmet=id:tier;Chest=id:tier") -> the table above (player attribute "ArmorLook")
--   ArmorLook.dummy() -> a static R15-sized body (invisible parts) for item icons
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)

local ArmorLook = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local HALF = math.pi / 2
local FOLDER = "ArmorLook"

type Item = { id: string, tier: number }
type Ctx = { folder: Folder, weld: boolean, palette: any, tier: number, trim: Color3, neonTrim: boolean, metal: boolean }

local function make(ctx: Ctx, body: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, opts: { [string]: any }?): BasePart
	local o = opts or {}
	local p: BasePart
	if o.shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		local plain = Instance.new("Part")
		if o.shape == "cyl" then
			plain.Shape = Enum.PartType.Cylinder
		end
		p = plain
	end
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = o.material or (if ctx.metal then Enum.Material.Metal else Enum.Material.SmoothPlastic)
	p.Transparency = o.transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = size.Magnitude > 0.6
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = body.CFrame * offset
	if ctx.weld then
		p.Anchored = false
		local weld = Instance.new("Weld")
		weld.Part0 = body
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = ctx.folder
	return p
end

local function trim(ctx: Ctx, body: BasePart, name: string, size: Vector3, offset: CFrame, opts: { [string]: any }?): BasePart
	local o = table.clone(opts or {})
	if ctx.neonTrim then
		o.material = Enum.Material.Neon
	end
	return make(ctx, body, name, size, offset, ctx.trim, o)
end

local function accent(ctx: Ctx, body: BasePart, name: string, size: Vector3, offset: CFrame, opts: { [string]: any }?): BasePart
	local o = table.clone(opts or {})
	if ctx.palette.Glow then
		o.material = Enum.Material.Neon
	end
	return make(ctx, body, name, size, offset, ctx.palette.Accent, o)
end

----------------------------------------------------------------------------------------------------
-- helmet features
----------------------------------------------------------------------------------------------------
local FEATURES = {}

function FEATURES.Crest(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Crest", V(h.X * 0.12, h.Y * 0.3, h.Z * 0.95), CF(0, h.Y * 0.6, 0.02), ctx.palette.Second)
	accent(ctx, head, "CrestGem", V(h.X * 0.14, h.X * 0.14, h.X * 0.08), CF(0, h.Y * 0.3, -h.Z * 0.56), { shape = "ball" })
end

function FEATURES.Wrap(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Tail", V(h.X * 0.45, h.Y * 0.7, h.Z * 0.08), CF(0, -h.Y * 0.15, h.Z * 0.55) * ANG(0.15, 0, 0), ctx.palette.Main)
	accent(ctx, head, "Gem", V(h.X * 0.16, h.X * 0.16, h.X * 0.08), CF(0, h.Y * 0.14, -h.Z * 0.58), { shape = "ball" })
end

function FEATURES.Mask(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Mask", V(h.X * 0.84, h.Y * 0.72, h.Z * 0.1), CF(0, -h.Y * 0.04, -h.Z * 0.56), ctx.palette.Second, { material = Enum.Material.Wood })
	for _, side in ipairs({ -1, 1 }) do
		make(ctx, head, "MaskEye", V(h.X * 0.18, h.Y * 0.08, 0.04), CF(side * h.X * 0.18, h.Y * 0.06, -h.Z * 0.62), Color3.fromRGB(255, 224, 112), { material = Enum.Material.Neon })
		accent(ctx, head, "BoneHorn", V(h.X * 0.1, h.Y * 0.36, h.Z * 0.16), CF(side * h.X * 0.32, h.Y * 0.62, 0) * ANG(0, side * HALF, side * -0.4), { shape = "wedge" })
	end
end

function FEATURES.Fur(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Fur", V(h.X * 1.26, h.Y * 0.26, h.Z * 1.26), CF(0, h.Y * 0.04, 0), ctx.palette.Second, { shape = "ball", material = Enum.Material.SmoothPlastic })
	accent(ctx, head, "IceSpike", V(h.X * 0.12, h.Y * 0.32, h.Z * 0.12), CF(0, h.Y * 0.66, 0) * ANG(0, math.pi / 4, 0), { material = Enum.Material.Glass, transparency = 0.2 })
end

function FEATURES.Hat(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Brim", V(h.Y * 0.08, h.X * 1.8, h.X * 1.8), CF(0, h.Y * 0.4, 0) * ANG(0, 0, HALF), ctx.palette.Main, { shape = "cyl" })
	local y = h.Y * 0.4
	for i, d in ipairs({ 0.95, 0.66, 0.38 }) do
		local height = h.Y * 0.32
		y += height * 0.85
		make(ctx, head, "HatCone", V(height, h.X * d, h.X * d), CF(i * h.X * 0.05, y, i * h.Z * 0.04) * ANG(0, 0, HALF) * ANG(0, 0, -i * 0.08), if i == 1 then ctx.palette.Second else ctx.palette.Main, { shape = "cyl" })
	end
	accent(ctx, head, "Buckle", V(h.X * 0.18, h.Y * 0.16, 0.05), CF(0, h.Y * 0.62, -h.X * 0.47))
end

function FEATURES.Horns(ctx: Ctx, head: BasePart, h: Vector3)
	for _, side in ipairs({ -1, 1 }) do
		make(ctx, head, "Horn", V(h.X * 0.12, h.Y * 0.38, h.Z * 0.18), CF(side * h.X * 0.4, h.Y * 0.62, 0) * ANG(0, side * HALF, side * -0.5), ctx.palette.Second, { shape = "wedge" })
		accent(ctx, head, "Lava", V(h.X * 0.06, h.Y * 0.4, 0.04), CF(side * h.X * 0.25, h.Y * 0.3, -h.Z * 0.56) * ANG(0, 0, side * 0.5))
	end
end

function FEATURES.BigHorns(ctx: Ctx, head: BasePart, h: Vector3)
	for _, side in ipairs({ -1, 1 }) do
		local base = CF(side * h.X * 0.5, h.Y * 0.45, 0)
		make(ctx, head, "Horn", V(h.X * 0.22, h.X * 0.22, h.Y * 0.4), base * ANG(-0.2, side * 1.2, 0) * CF(0, 0, -h.Y * 0.15), ctx.palette.Second, { shape = "ball" })
		make(ctx, head, "HornTip", V(h.X * 0.14, h.Y * 0.42, h.Z * 0.18), base * CF(side * h.X * 0.32, h.Y * 0.3, 0) * ANG(0, side * HALF, side * -0.35), ctx.palette.Second, { shape = "wedge" })
	end
	accent(ctx, head, "Eye", V(h.X * 0.5, h.Y * 0.08, 0.04), CF(0, h.Y * 0.06, -h.Z * 0.58))
end

function FEATURES.Halo(ctx: Ctx, head: BasePart, h: Vector3)
	for i = 1, 14 do
		local t = i / 14 * math.pi * 2
		make(ctx, head, "Halo", V(h.X * 0.1, h.X * 0.07, h.X * 0.1), CF(math.cos(t) * h.X * 0.42, h.Y * 0.95, math.sin(t) * h.Z * 0.42), ctx.palette.Accent, { shape = "ball", material = Enum.Material.Neon })
	end
	for _, side in ipairs({ -1, 1 }) do
		make(ctx, head, "Wing", V(h.X * 0.06, h.Y * 0.4, h.Z * 0.5), CF(side * h.X * 0.6, h.Y * 0.25, h.Z * 0.1) * ANG(0, 0, side * -0.4), ctx.palette.Second, { shape = "ball" })
	end
end

function FEATURES.Skull(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Face", V(h.X * 0.8, h.Y * 0.62, h.Z * 0.12), CF(0, -h.Y * 0.04, -h.Z * 0.56), ctx.palette.Main)
	for _, side in ipairs({ -1, 1 }) do
		make(ctx, head, "Socket", V(h.X * 0.22, h.Y * 0.18, 0.05), CF(side * h.X * 0.18, h.Y * 0.06, -h.Z * 0.63), Color3.fromRGB(20, 18, 24))
		accent(ctx, head, "EyeGlow", V(h.X * 0.1, h.Y * 0.08, 0.04), CF(side * h.X * 0.18, h.Y * 0.06, -h.Z * 0.66), { shape = "ball" })
	end
	make(ctx, head, "Teeth", V(h.X * 0.4, h.Y * 0.08, 0.05), CF(0, -h.Y * 0.24, -h.Z * 0.63), Color3.fromRGB(240, 232, 210))
end

function FEATURES.Coral(ctx: Ctx, head: BasePart, h: Vector3)
	for i = 1, 5 do
		local t = (i - 3) * 0.45
		local base = CF(math.sin(t) * h.X * 0.4, h.Y * 0.55, -math.cos(t) * h.Z * 0.25)
		make(ctx, head, "Coral", V(h.Y * 0.4, h.X * 0.1, h.X * 0.1), base * ANG(0, 0, HALF + t * 0.6) * CF(h.Y * 0.18, 0, 0), ctx.palette.Second, { shape = "cyl" })
		make(ctx, head, "CoralTip", V(h.X * 0.13, h.X * 0.13, h.X * 0.13), base * CF(-math.sin(t) * h.Y * 0.1, h.Y * 0.38, 0), ctx.palette.Accent, { shape = "ball", material = Enum.Material.Neon })
	end
end

function FEATURES.Visor(ctx: Ctx, head: BasePart, h: Vector3)
	make(ctx, head, "Visor", V(h.X * 0.9, h.Y * 0.2, h.Z * 0.1), CF(0, h.Y * 0.06, -h.Z * 0.55), ctx.palette.Accent, { material = Enum.Material.Neon })
	make(ctx, head, "Antenna", V(h.Y * 0.5, h.X * 0.05, h.X * 0.05), CF(h.X * 0.38, h.Y * 0.7, h.Z * 0.1) * ANG(0, 0, HALF - 0.2), ctx.palette.Second, { shape = "cyl" })
	accent(ctx, head, "AntennaTip", V(h.X * 0.1, h.X * 0.1, h.X * 0.1), CF(h.X * 0.43, h.Y * 0.95, h.Z * 0.1), { shape = "ball" })
end

----------------------------------------------------------------------------------------------------
-- slots
----------------------------------------------------------------------------------------------------
local function helmet(ctx: Ctx, body: { [string]: BasePart })
	local head = body.Head
	if not head then
		return
	end
	local h = head.Size
	make(ctx, head, "Dome", V(h.X * 1.14, h.Y * 0.74, h.Z * 1.14), CF(0, h.Y * 0.2, 0.02), ctx.palette.Main, { shape = "ball" })
	trim(ctx, head, "Band", V(h.Y * 0.14, h.X * 1.17, h.Z * 1.17), CF(0, h.Y * 0.06, 0.02) * ANG(0, 0, HALF), { shape = "cyl" })
	local feature = FEATURES[ctx.palette.Helmet]
	if feature then
		feature(ctx, head, h)
	end
end

local function chest(ctx: Ctx, body: { [string]: BasePart }): BasePart?
	local torso = body.UpperTorso
	if not torso then
		return nil
	end
	local u = torso.Size
	local plate = make(ctx, torso, "Plate", V(u.X * 1.08, u.Y * 0.9, u.Z * 1.22), CF(0, u.Y * 0.03, 0), ctx.palette.Main)
	make(ctx, torso, "Collar", V(u.X * 0.74, u.Y * 0.14, u.Z * 1.0), CF(0, u.Y * 0.47, 0), ctx.palette.Second)
	trim(ctx, torso, "Stripe", V(u.X * 0.16, u.Y * 0.78, 0.06), CF(0, u.Y * 0.02, -u.Z * 0.62))
	if ctx.palette.Glow then
		for _, y in ipairs({ 0.22, -0.18 }) do
			accent(ctx, torso, "GlowLine", V(u.X * 0.9, u.Y * 0.05, 0.05), CF(0, u.Y * y, -u.Z * 0.62))
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm" }) do
		local arm = body[name]
		if arm then
			local a = arm.Size
			make(ctx, arm, "Pauldron", V(a.X * 1.55, a.Y * 0.42, a.Z * 1.55), CF(0, a.Y * 0.36, 0), ctx.palette.Second, { shape = "ball" })
			trim(ctx, arm, "PauldronTrim", V(a.Y * 0.08, a.X * 1.3, a.Z * 1.3), CF(0, a.Y * 0.2, 0) * ANG(0, 0, HALF), { shape = "cyl" })
		end
	end
	local lower = body.LowerTorso
	if lower then
		local l = lower.Size
		make(ctx, lower, "Belt", V(l.X * 1.1, l.Y * 0.8, l.Z * 1.24), CF(0, 0, 0), ctx.palette.Second)
		trim(ctx, lower, "Buckle", V(l.X * 0.2, l.Y * 0.6, 0.08), CF(0, 0, -l.Z * 0.64))
	end
	return plate
end

local function legs(ctx: Ctx, body: { [string]: BasePart }): BasePart?
	local first: BasePart? = nil
	for _, side in ipairs({ "Left", "Right" }) do
		local upper, lower = body[side .. "UpperLeg"], body[side .. "LowerLeg"]
		if upper then
			local u = upper.Size
			make(ctx, upper, "Thigh", V(u.X * 1.14, u.Y * 0.7, u.Z * 1.16), CF(0, u.Y * 0.06, 0), ctx.palette.Second)
		end
		if lower then
			local l = lower.Size
			local greave = make(ctx, lower, "Greave", V(l.X * 1.16, l.Y * 0.86, l.Z * 1.22), CF(0, -l.Y * 0.04, 0), ctx.palette.Main)
			first = first or greave
			trim(ctx, lower, "Knee", V(l.X * 0.7, l.X * 0.7, l.Z * 0.3), CF(0, l.Y * 0.44, -l.Z * 0.56), { shape = "ball" })
			if ctx.palette.Glow then
				accent(ctx, lower, "GlowLine", V(l.X * 0.1, l.Y * 0.6, 0.05), CF(0, -l.Y * 0.08, -l.Z * 0.62))
			end
		end
	end
	return first
end

local function shimmer(part: BasePart, tier: number)
	local rarity = Rarities.get(tier)
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "Shimmer"
	fx.Color = rarity.Gradient or ColorSequence.new(rarity.Color)
	fx.LightEmission = 1
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.16), NumberSequenceKeypoint.new(1, 0) })
	fx.Transparency = NumberSequence.new(0.2, 1)
	fx.Lifetime = NumberRange.new(0.6, 1.1)
	fx.Rate = 2 + (tier - Armor.ShimmerFrom) * 2
	fx.Speed = NumberRange.new(0.2, 0.6)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.LockedToPart = true
	fx.Parent = part
end

local BODY_PARTS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }

local HIDDEN = "ArmorHiddenTransparency"

local function headAccessories(model: Instance, hide: boolean)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	for _, accessory in ipairs(model:GetChildren()) do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local onHead = false
			for _, attachment in ipairs(handle:GetChildren()) do
				if attachment:IsA("Attachment") and head:FindFirstChild(attachment.Name) then
					onHead = true
					break
				end
			end
			if onHead then
				local saved = handle:GetAttribute(HIDDEN)
				if hide then
					if saved == nil then
						handle:SetAttribute(HIDDEN, handle.Transparency)
					end
					handle.Transparency = 1
				elseif typeof(saved) == "number" then
					handle.Transparency = saved
					handle:SetAttribute(HIDDEN, nil)
				end
			end
		end
	end
end

function ArmorLook.clear(model: Instance)
	local old = model:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	headAccessories(model, false)
end

function ArmorLook.apply(model: Instance, items: { [string]: Item }, opts: { [string]: any }?): Folder?
	ArmorLook.clear(model)
	local o = opts or {}
	local body: { [string]: BasePart } = {}
	for _, name in ipairs(BODY_PARTS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			body[name] = part
		end
	end
	if not body.UpperTorso and not body.Head then
		return nil -- not an R15 body
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, slot in ipairs(Armor.SLOTS) do
		local item = items[slot]
		local piece = item and Armor.ById[item.id]
		if piece then
			local rarity = Rarities.get(item.tier)
			local ctx: Ctx = {
				folder = folder,
				weld = o.Weld == true,
				palette = piece.Palette,
				tier = rarity.Tier,
				trim = rarity.Color,
				neonTrim = rarity.Tier >= Armor.ShimmerFrom,
				metal = piece.ZoneId == "Plains" or piece.ZoneId == "Mechanical" or piece.ZoneId == "Tundra",
			}
			local main: BasePart? = nil
			if slot == "Helmet" then
				helmet(ctx, body)
				main = folder:FindFirstChild("Dome") :: BasePart?
			elseif slot == "Chest" then
				main = chest(ctx, body)
			else
				main = legs(ctx, body)
			end
			if main and rarity.Tier >= Armor.ShimmerFrom and not o.LowFx then
				shimmer(main, rarity.Tier)
			end
		end
	end
	folder.Parent = model
	if items.Helmet and Armor.ById[items.Helmet.id] and o.KeepHats ~= true then
		headAccessories(model, true)
	end
	return folder
end

-- "Helmet=plains_helmet:3;Chest=desert_chest:5" -> { Helmet = { id, tier }, ... }
function ArmorLook.parse(text: any): { [string]: Item }
	local items = {}
	if typeof(text) ~= "string" then
		return items
	end
	for slot, id, tier in string.gmatch(text, "(%a+)=([%w_]+):(%d+)") do
		if Armor.ById[id] and Armor.ById[id].Slot == slot then
			items[slot] = { id = id, tier = tonumber(tier) or 1 }
		end
	end
	return items
end

function ArmorLook.encode(items: { [string]: Item }): string
	local parts = {}
	for _, slot in ipairs(Armor.SLOTS) do
		local item = items[slot]
		if item then
			table.insert(parts, `{slot}={item.id}:{item.tier}`)
		end
	end
	return table.concat(parts, ";")
end

-- A static, invisible R15 body (default sizes) to build armor icons on.
local DUMMY = {
	Head = { V(1.2, 1.2, 1.2), V(0, 4.55, 0) },
	UpperTorso = { V(2, 1.6, 1), V(0, 3.15, 0) },
	LowerTorso = { V(2, 0.4, 1), V(0, 2.15, 0) },
	LeftUpperArm = { V(1, 1.2, 1), V(-1.5, 3.35, 0) },
	RightUpperArm = { V(1, 1.2, 1), V(1.5, 3.35, 0) },
	LeftUpperLeg = { V(1, 1.2, 1), V(-0.5, 1.4, 0) },
	RightUpperLeg = { V(1, 1.2, 1), V(0.5, 1.4, 0) },
	LeftLowerLeg = { V(1, 1, 1), V(-0.5, 0.5, 0) },
	RightLowerLeg = { V(1, 1, 1), V(0.5, 0.5, 0) },
}
function ArmorLook.dummy(): Model
	local model = Instance.new("Model")
	model.Name = "ArmorDummy"
	for name, def in pairs(DUMMY) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = def[1]
		part.CFrame = CF(def[2])
		part.Anchored = true
		part.Transparency = 1
		part.CanCollide = false
		part.Parent = model
	end
	model.WorldPivot = CFrame.new() -- the feet
	return model
end

return ArmorLook
