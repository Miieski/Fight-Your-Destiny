--!strict
-- Procedural pet and egg models (docs/menu_systems_brief.txt B4): 7 low-poly body types built from parts
-- (Quadruped, Bird, Blob, Insect, Fish / Jelly, Biped, Mech), each species with its Config/Pets palette, scale
-- and accessories. No Blender needed. Run from the command bar in Edit mode:
--   require(game.ServerStorage.DevTools.PetModels).buildAll()
--       -> ReplicatedStorage.Assets.Pets.<PetId> (76) and ReplicatedStorage.Assets.Eggs.<zone lower> (12)
--   require(game.ServerStorage.DevTools.PetModels).pet("plains_pet1") / .egg("Plains") -> Model (not parented)
-- Model convention: PrimaryPart "Root" (invisible) at the feet, the pet looks toward -Z; every part is
-- Anchored with no collision / query / touch (followers and icons only move them with PivotTo).
-- Attributes: Flying (followers float instead of walking), Height (studs).
-- Eggs have a flat "Ring" part under them that the UI recolors with the egg's rarity (the glow ring).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)

local PetModels = {}

local hex = Color3.fromHex
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local BLACK = hex("#1A1418")
local WHITE = Color3.new(1, 1, 1)
local PINK = hex("#FF9EB5")
local BEAK = hex("#F5A623")
local HALF = math.pi / 2

type Anchors = {
	head: Vector3, -- head center
	r: number, -- head radius
	top: Vector3, -- top of the head
	back: Vector3, -- rear of the body
	body: Vector3, -- body center
	size: Vector3, -- body size
	face: Vector3, -- front of the face
	height: number,
}

local function shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(WHITE, amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

-- opts: shape = "ball" (ellipsoid), "cyl" (axis X), "wedge", "block"; material; transparency; noShadow
local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, opts: { [string]: any }?): BasePart
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
	p.CFrame = cf
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = not o.noShadow and size.Magnitude > 0.4
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

local function ball(model: Model, name: string, size: Vector3, pos: Vector3, color: Color3, opts: { [string]: any }?): BasePart
	local o = table.clone(opts or {})
	o.shape = "ball"
	return part(model, name, size, if o.cf then o.cf else CF(pos), color, o)
end

-- vertical cylinder of `length` and diameter `d` from `a` toward `b` (any direction)
local function stick(model: Model, name: string, a: Vector3, b: Vector3, d: number, color: Color3, opts: { [string]: any }?): BasePart
	local o = table.clone(opts or {})
	o.shape = "cyl"
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	-- the cylinder's axis is X: build a frame whose X axis points from a to b
	local look = CFrame.lookAt(mid, b) * ANG(0, HALF, 0)
	return part(model, name, V(length, d, d), look, color, o)
end

local function eyes(model: Model, a: Anchors, spread: number, size: number, color: Color3?, neon: boolean?)
	local c, r = a.head, a.r
	for _, side in ipairs({ -1, 1 }) do
		-- on the head's surface, a little above the middle
		local dir = V(side * spread, 0.18, -1).Unit
		local pos = c + dir * (r * 0.92)
		local eye = ball(model, "Eye", V(size, size * 1.15, size * 0.6), pos, color or BLACK, {
			cf = CFrame.lookAt(pos, pos + dir),
			material = if neon then Enum.Material.Neon else nil,
			noShadow = true,
		})
		if not neon then
			local shine = eye.Position + dir * (size * 0.22) + V(side * -size * 0.12, size * 0.2, 0)
			ball(model, "Shine", V(size * 0.35, size * 0.35, size * 0.2), shine, WHITE, { noShadow = true })
		end
	end
end

----------------------------------------------------------------------------------------------------
-- body types (unit size: about 1 stud tall before the species scale)
----------------------------------------------------------------------------------------------------
local BODIES = {}

function BODIES.Quadruped(m: Model, main: Color3, second: Color3): Anchors
	local body = V(0, 0.5, 0.12)
	local size = V(0.78, 0.6, 1.0)
	ball(m, "Body", size, body, main)
	ball(m, "Belly", V(0.56, 0.42, 0.78), body + V(0, -0.1, -0.04), second)
	local head = V(0, 0.86, -0.36)
	ball(m, "Head", V(0.72, 0.68, 0.68), head, main)
	ball(m, "Muzzle", V(0.38, 0.26, 0.26), head + V(0, -0.1, -0.29), second)
	ball(m, "Nose", V(0.12, 0.09, 0.08), head + V(0, -0.03, -0.42), BLACK, { noShadow = true })
	for _, x in ipairs({ -0.24, 0.24 }) do
		for _, z in ipairs({ -0.18, 0.4 }) do
			stick(m, "Leg", V(x, 0.34, z), V(x, 0.02, z), 0.2, shade(main, -0.12))
			ball(m, "Paw", V(0.22, 0.1, 0.25), V(x, 0.05, z - 0.03), second)
		end
	end
	local a = { head = head, r = 0.35, top = head + V(0, 0.33, 0), back = body + V(0, 0.08, 0.5), body = body, size = size, face = head + V(0, -0.05, -0.36), height = 1.2 }
	eyes(m, a, 0.42, 0.13)
	return a
end

function BODIES.Bird(m: Model, main: Color3, second: Color3): Anchors
	local body = V(0, 0.5, 0)
	local size = V(0.8, 0.82, 0.8)
	ball(m, "Body", size, body, main)
	ball(m, "Belly", V(0.56, 0.58, 0.3), body + V(0, -0.06, -0.27), second)
	for _, side in ipairs({ -1, 1 }) do
		ball(m, "Wing", V(0.14, 0.44, 0.52), body + V(side * 0.4, 0.02, 0.06), shade(main, -0.15), { cf = CF(body + V(side * 0.4, 0.02, 0.06)) * ANG(0.2, 0, side * 0.32) })
		ball(m, "Foot", V(0.14, 0.06, 0.2), V(side * 0.13, 0.06, -0.06), BEAK, { noShadow = true })
	end
	ball(m, "Beak", V(0.16, 0.11, 0.22), body + V(0, 0.06, -0.42), BEAK, { noShadow = true })
	part(m, "TailFeathers", V(0.32, 0.06, 0.26), CF(body + V(0, 0.05, 0.45)) * ANG(-0.5, 0, 0), shade(main, -0.15), { shape = "wedge" })
	ball(m, "Tuft", V(0.1, 0.2, 0.1), body + V(0, 0.45, -0.05), main, { cf = CF(body + V(0, 0.45, -0.05)) * ANG(-0.4, 0, 0) })
	local a = { head = body + V(0, 0.12, 0), r = 0.4, top = body + V(0, 0.42, 0), back = body + V(0, 0, 0.42), body = body, size = size, face = body + V(0, 0.08, -0.4), height = 0.95 }
	eyes(m, a, 0.36, 0.14)
	return a
end

function BODIES.Blob(m: Model, main: Color3, second: Color3, glow: boolean): Anchors
	local body = V(0, 0.4, 0)
	local size = V(0.95, 0.8, 0.9)
	ball(m, "Body", size, body, main, { material = if glow then Enum.Material.Neon else nil, transparency = if glow then 0.1 else 0 })
	ball(m, "Highlight", V(0.22, 0.14, 0.1), body + V(-0.22, 0.26, -0.3), WHITE, { transparency = 0.45, noShadow = true })
	ball(m, "Bottom", V(0.8, 0.12, 0.76), V(0, 0.05, 0), second, { transparency = if glow then 0.3 else 0 })
	ball(m, "Mouth", V(0.14, 0.06, 0.05), body + V(0, -0.08, -0.44), BLACK, { noShadow = true })
	for _, side in ipairs({ -1, 1 }) do
		ball(m, "Cheek", V(0.14, 0.08, 0.05), body + V(side * 0.27, -0.03, -0.38), PINK, { transparency = 0.25, noShadow = true })
	end
	local a = { head = body + V(0, 0.02, 0), r = 0.45, top = body + V(0, 0.4, 0), back = body + V(0, 0, 0.45), body = body, size = size, face = body + V(0, 0, -0.45), height = 0.8 }
	eyes(m, a, 0.4, 0.18)
	return a
end

function BODIES.Insect(m: Model, main: Color3, second: Color3): Anchors
	local body = V(0, 0.38, 0.08)
	local size = V(0.88, 0.46, 0.8)
	ball(m, "Body", size, body, main)
	ball(m, "Back", V(0.6, 0.2, 0.56), body + V(0, 0.16, 0.04), second)
	local head = V(0, 0.42, -0.36)
	ball(m, "Head", V(0.5, 0.4, 0.36), head, main)
	for _, side in ipairs({ -1, 1 }) do
		for i, z in ipairs({ -0.18, 0.08, 0.32 }) do
			local root = V(side * 0.34, 0.36, z)
			local knee = V(side * 0.62, 0.3, z + (i - 2) * 0.06)
			local foot = V(side * 0.72, 0.02, z + (i - 2) * 0.12)
			stick(m, "Leg", root, knee, 0.08, shade(main, -0.2), { noShadow = true })
			stick(m, "Leg", knee, foot, 0.07, shade(main, -0.2), { noShadow = true })
		end
	end
	local a = { head = head, r = 0.22, top = body + V(0, 0.24, 0), back = body + V(0, 0.05, 0.42), body = body, size = size, face = head + V(0, 0, -0.18), height = 0.62 }
	eyes(m, { head = head + V(0, 0.08, 0), r = 0.2, top = a.top, back = a.back, body = body, size = size, face = a.face, height = 0.62 }, 0.5, 0.13)
	return a
end

function BODIES.Fish(m: Model, main: Color3, second: Color3): Anchors
	local body = V(0, 0.6, 0)
	local size = V(0.55, 0.66, 1.0)
	ball(m, "Body", size, body, main)
	ball(m, "Belly", V(0.44, 0.38, 0.78), body + V(0, -0.14, -0.04), second)
	part(m, "TailFin", V(0.06, 0.5, 0.34), CF(body + V(0, 0, 0.6)) * ANG(0, 0, 0), second, { shape = "wedge" })
	part(m, "Dorsal", V(0.05, 0.22, 0.34), CF(body + V(0, 0.38, 0.06)), shade(main, -0.12), { shape = "wedge" })
	local a = { head = body + V(0, 0.06, -0.24), r = 0.3, top = body + V(0, 0.34, -0.1), back = body + V(0, 0, 0.5), body = body, size = size, face = body + V(0, 0, -0.5), height = 1.0 }
	-- eyes on the sides of the head
	for _, side in ipairs({ -1, 1 }) do
		local pos = body + V(side * 0.22, 0.1, -0.3)
		local dir = V(side, 0.1, -0.6).Unit
		ball(m, "Eye", V(0.15, 0.17, 0.08), pos, BLACK, { cf = CFrame.lookAt(pos, pos + dir), noShadow = true })
		ball(m, "Shine", V(0.05, 0.05, 0.03), pos + dir * 0.04 + V(0, 0.04, 0), WHITE, { noShadow = true })
	end
	ball(m, "Mouth", V(0.12, 0.05, 0.05), body + V(0, -0.04, -0.5), shade(main, -0.4), { noShadow = true })
	return a
end

function BODIES.Jelly(m: Model, main: Color3, second: Color3): Anchors
	local body = V(0, 0.82, 0)
	local size = V(0.8, 0.6, 0.8)
	ball(m, "Dome", size, body, main, { transparency = 0.15 })
	ball(m, "Rim", V(0.86, 0.16, 0.86), body + V(0, -0.22, 0), second, { transparency = 0.2 })
	ball(m, "Core", V(0.36, 0.28, 0.36), body + V(0, 0.02, 0), second, { material = Enum.Material.Neon, transparency = 0.35 })
	local a = { head = body, r = 0.38, top = body + V(0, 0.3, 0), back = body + V(0, 0, 0.4), body = body, size = size, face = body + V(0, 0, -0.4), height = 1.1 }
	eyes(m, a, 0.38, 0.13)
	return a
end

function BODIES.Biped(m: Model, main: Color3, second: Color3): Anchors
	local body = V(0, 0.42, 0)
	local size = V(0.56, 0.56, 0.46)
	ball(m, "Body", size, body, main)
	ball(m, "Belly", V(0.38, 0.38, 0.2), body + V(0, -0.02, -0.16), second)
	local head = V(0, 0.95, 0)
	ball(m, "Head", V(0.66, 0.62, 0.6), head, main)
	ball(m, "Face", V(0.42, 0.34, 0.2), head + V(0, -0.06, -0.22), second)
	for _, side in ipairs({ -1, 1 }) do
		stick(m, "Leg", V(side * 0.14, 0.24, 0), V(side * 0.14, 0.02, 0), 0.18, shade(main, -0.12))
		ball(m, "Foot", V(0.2, 0.09, 0.26), V(side * 0.14, 0.04, -0.04), second)
		ball(m, "Arm", V(0.15, 0.34, 0.15), body + V(side * 0.32, 0.02, 0), main, { cf = CF(body + V(side * 0.32, 0.02, 0)) * ANG(0, 0, side * 0.35) })
	end
	local a = { head = head, r = 0.31, top = head + V(0, 0.3, 0), back = body + V(0, 0.05, 0.24), body = body, size = size, face = head + V(0, -0.05, -0.3), height = 1.28 }
	eyes(m, a, 0.4, 0.13)
	return a
end

function BODIES.Mech(m: Model, main: Color3, second: Color3): Anchors
	local metal = { material = Enum.Material.Metal }
	local body = V(0, 0.46, 0)
	local size = V(0.7, 0.5, 0.7)
	part(m, "Body", size, CF(body), main, metal)
	part(m, "Plate", V(0.46, 0.3, 0.04), CF(body + V(0, 0, -0.36)), shade(main, -0.3), metal)
	local head = V(0, 0.92, 0)
	part(m, "Head", V(0.52, 0.4, 0.46), CF(head), shade(main, 0.08), metal)
	part(m, "Neck", V(0.2, 0.1, 0.2), CF(V(0, 0.73, 0)), shade(main, -0.35), metal)
	part(m, "Visor", V(0.42, 0.14, 0.03), CF(head + V(0, 0.02, -0.235)), BLACK)
	for _, side in ipairs({ -1, 1 }) do
		ball(m, "EyeLight", V(0.1, 0.1, 0.04), head + V(side * 0.1, 0.02, -0.25), second, { material = Enum.Material.Neon, noShadow = true })
		part(m, "Track", V(0.2, 0.22, 0.6), CF(V(side * 0.27, 0.11, 0)), shade(main, -0.5), metal)
		stick(m, "Bolt", body + V(side * 0.35, 0.1, 0), body + V(side * 0.38, 0.1, 0), 0.1, second, { material = Enum.Material.Neon, noShadow = true })
	end
	local a = { head = head, r = 0.26, top = head + V(0, 0.2, 0), back = body + V(0, 0, 0.36), body = body, size = size, face = head + V(0, 0, -0.24), height = 1.12 }
	return a
end

----------------------------------------------------------------------------------------------------
-- accessories
----------------------------------------------------------------------------------------------------
local ACC = {}

function ACC.Ears(m: Model, a: Anchors, main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.head + V(side * a.r * 0.55, a.r * 0.95, 0.02)
		part(m, "Ear", V(0.07, 0.24, 0.2), CF(pos) * ANG(0, side * HALF, side * -0.25), main, { shape = "wedge" })
		part(m, "EarInner", V(0.04, 0.16, 0.12), CF(pos + V(0, -0.02, -0.03)) * ANG(0, side * HALF, side * -0.25), second, { shape = "wedge", noShadow = true })
	end
end

function ACC.BigEars(m: Model, a: Anchors, main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.head + V(side * a.r * 0.5, a.r * 1.25, 0.04)
		local cf = CF(pos) * ANG(0, 0, side * -0.28)
		ball(m, "Ear", V(0.14, 0.5, 0.22), pos, main, { cf = cf })
		ball(m, "EarInner", V(0.08, 0.36, 0.08), pos, PINK, { cf = cf * CF(0, 0, -0.08), noShadow = true })
	end
end

function ACC.Horns(m: Model, a: Anchors, _main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.head + V(side * a.r * 0.5, a.r * 0.95, 0.05)
		part(m, "Horn", V(0.1, 0.3, 0.14), CF(pos) * ANG(0, side * HALF, side * -0.45), shade(second, 0.25), { shape = "wedge" })
	end
end

function ACC.Antlers(m: Model, a: Anchors)
	local brown = hex("#8A5A33")
	for _, side in ipairs({ -1, 1 }) do
		local base = a.head + V(side * a.r * 0.45, a.r * 0.9, 0.04)
		local tip = base + V(side * 0.14, 0.34, 0.04)
		stick(m, "Antler", base, tip, 0.06, brown, { noShadow = true })
		stick(m, "Antler", base + V(side * 0.07, 0.18, 0.02), base + V(side * 0.24, 0.26, -0.02), 0.05, brown, { noShadow = true })
	end
end

-- wings are flat toward the camera (spread on the back), so they read from the front and the back
function ACC.Wings(m: Model, a: Anchors, _main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.body + V(side * (a.size.X * 0.42 + 0.14), a.size.Y * 0.32, a.size.Z * 0.3)
		local cf = CF(pos) * ANG(0, side * 0.35, side * -0.45)
		ball(m, "Wing", V(0.46, 0.3, 0.05), pos, shade(second, 0.4), { cf = cf })
		ball(m, "Wing", V(0.32, 0.2, 0.06), pos, shade(second, 0.15), { cf = cf * CF(side * 0.08, -0.06, 0.01) })
	end
end

function ACC.BatWings(m: Model, a: Anchors, main: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.body + V(side * (a.size.X * 0.42 + 0.14), a.size.Y * 0.36, a.size.Z * 0.28)
		part(m, "BatWing", V(0.04, 0.3, 0.42), CF(pos) * ANG(0, side * 0.35, side * -0.3) * ANG(0, side * -HALF, 0), shade(main, -0.35), { shape = "wedge" })
	end
end

function ACC.LongSnout(m: Model, a: Anchors, main: Color3)
	local pos = a.face + V(0, -0.06, -0.12)
	ball(m, "Snout", V(0.34, 0.2, 0.42), pos, main)
	for _, side in ipairs({ -1, 1 }) do
		ball(m, "Nostril", V(0.04, 0.04, 0.03), pos + V(side * 0.06, 0.08, -0.17), BLACK, { noShadow = true })
		part(m, "Tooth", V(0.04, 0.06, 0.03), CF(pos + V(side * 0.12, -0.1, -0.1)) * ANG(math.pi, 0, 0), WHITE, { shape = "wedge", noShadow = true })
	end
end

function ACC.Antennae(m: Model, a: Anchors, _main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local base = a.top + V(side * 0.08, -0.02, 0)
		local tip = base + V(side * 0.1, 0.28, -0.06)
		stick(m, "Antenna", base, tip, 0.04, BLACK, { noShadow = true })
		ball(m, "AntennaTip", V(0.09, 0.09, 0.09), tip, second, { material = Enum.Material.Neon, noShadow = true })
	end
end

function ACC.Halo(m: Model, a: Anchors)
	local center = a.top + V(0, 0.16, 0)
	for i = 1, 12 do
		local t = i / 12 * math.pi * 2
		ball(m, "Halo", V(0.07, 0.05, 0.07), center + V(math.cos(t) * 0.2, 0, math.sin(t) * 0.2), hex("#FFE070"), { material = Enum.Material.Neon, noShadow = true })
	end
end

function ACC.Flame(m: Model, a: Anchors)
	local base = a.top + V(0, 0.05, 0.02)
	ball(m, "Flame", V(0.26, 0.34, 0.26), base + V(0, 0.08, 0), hex("#FF6A1F"), { material = Enum.Material.Neon, transparency = 0.15, noShadow = true })
	ball(m, "Flame", V(0.15, 0.24, 0.15), base + V(0, 0.2, 0), hex("#FFE070"), { material = Enum.Material.Neon, transparency = 0.1, noShadow = true })
	local holder = m:FindFirstChild("Flame") :: BasePart
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "FlameFx"
	fire.Color = ColorSequence.new(hex("#FFD040"), hex("#FF3A10"))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	fire.Transparency = NumberSequence.new(0.2, 1)
	fire.Lifetime = NumberRange.new(0.35, 0.6)
	fire.Rate = 14
	fire.Speed = NumberRange.new(0.8, 1.4)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = holder
end

function ACC.Spikes(m: Model, a: Anchors, main: Color3, second: Color3)
	for i = 0, 3 do
		local z = a.body.Z - a.size.Z * 0.3 + i * a.size.Z * 0.2
		local y = a.body.Y + a.size.Y * 0.47 - math.abs(i - 1.5) * 0.03
		part(m, "Spike", V(0.06, 0.16, 0.16), CF(V(0, y, z)) * ANG(0, 0, 0), shade(second, -0.1), { shape = "wedge", noShadow = true })
	end
end

function ACC.Tusks(m: Model, a: Anchors)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.face + V(side * 0.12, -0.12, 0.02)
		part(m, "Tusk", V(0.05, 0.14, 0.06), CF(pos) * ANG(0, side * HALF, side * 0.3), hex("#FFF6E0"), { shape = "wedge", noShadow = true })
	end
end

function ACC.Snout(m: Model, a: Anchors)
	local pos = a.face + V(0, -0.05, -0.04)
	stick(m, "Snout", pos + V(0, 0, 0.04), pos + V(0, 0, -0.06), 0.2, PINK)
	for _, side in ipairs({ -1, 1 }) do
		ball(m, "Nostril", V(0.04, 0.06, 0.02), pos + V(side * 0.04, 0, -0.065), shade(PINK, -0.5), { noShadow = true })
	end
end

function ACC.Claws(m: Model, a: Anchors, main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local arm = a.body + V(side * a.size.X * 0.45, -0.02, -a.size.Z * 0.42)
		local claw = arm + V(side * 0.08, 0.06, -0.2)
		stick(m, "ClawArm", arm, claw, 0.08, shade(main, -0.1), { noShadow = true })
		ball(m, "Claw", V(0.22, 0.17, 0.28), claw, main)
		part(m, "Pincer", V(0.06, 0.08, 0.14), CF(claw + V(side * 0.03, 0.08, -0.12)) * ANG(-0.4, 0, 0), second, { shape = "wedge", noShadow = true })
	end
end

function ACC.Stinger(m: Model, a: Anchors, main: Color3, second: Color3)
	local b = a.back
	local points = { b + V(0, 0.05, 0.02), b + V(0, 0.22, 0.12), b + V(0, 0.42, 0.12), b + V(0, 0.56, 0.0) }
	for i, p in ipairs(points) do
		ball(m, "Tail", V(0.16 - i * 0.015, 0.16 - i * 0.015, 0.16 - i * 0.015), p, main)
	end
	part(m, "Sting", V(0.05, 0.16, 0.12), CF(points[4] + V(0, 0.02, -0.12)) * ANG(0, 0, 0) * ANG(-2.2, 0, 0), second, { shape = "wedge", material = Enum.Material.Neon, noShadow = true })
end

function ACC.Crown(m: Model, a: Anchors)
	local gold = hex("#F1C40F")
	local base = a.top + V(0, 0.03, 0.02)
	stick(m, "Crown", base, base + V(0, 0.1, 0), 0.26, gold, { material = Enum.Material.Metal })
	for i = 1, 5 do
		local t = i / 5 * math.pi * 2
		ball(m, "CrownPoint", V(0.06, 0.1, 0.06), base + V(math.cos(t) * 0.11, 0.14, math.sin(t) * 0.11), gold, { material = Enum.Material.Metal, noShadow = true })
	end
	ball(m, "Jewel", V(0.06, 0.06, 0.03), base + V(0, 0.05, -0.13), hex("#E0302A"), { material = Enum.Material.Neon, noShadow = true })
end

function ACC.Spots(m: Model, a: Anchors, main: Color3, second: Color3, rng: Random)
	local color = if second == main then shade(main, -0.35) else shade(second, -0.2)
	for _ = 1, 5 do
		local t = rng:NextNumber(-1.2, 1.2)
		local y = rng:NextNumber(0.1, 0.42)
		local dir = V(math.sin(t), y, math.cos(t) * 0.8 + 0.3).Unit
		local pos = a.body + V(dir.X * a.size.X * 0.48, dir.Y * a.size.Y * 0.5, dir.Z * a.size.Z * 0.48)
		ball(m, "Spot", V(0.13, 0.13, 0.04), pos, color, { cf = CFrame.lookAt(pos, pos + dir), noShadow = true })
	end
end

function ACC.Tail(m: Model, a: Anchors, main: Color3, second: Color3)
	local base = a.back
	local tip = base + V(0, 0.3, 0.22)
	stick(m, "Tail", base, tip, 0.1, main)
	ball(m, "TailTip", V(0.15, 0.15, 0.15), tip, second)
end

function ACC.Tails(m: Model, a: Anchors, main: Color3, second: Color3)
	for i = -1, 1 do
		local base = a.back
		local dir = V(i * 0.5, 0.75, 0.6).Unit
		local mid = base + dir * 0.28
		ball(m, "Tail", V(0.16, 0.16, 0.5), mid, main, { cf = CFrame.lookAt(mid, mid + dir) })
		ball(m, "TailTip", V(0.12, 0.12, 0.16), base + dir * 0.52, second, { material = Enum.Material.Neon, noShadow = true })
	end
end

function ACC.Fins(m: Model, a: Anchors, _main: Color3, second: Color3)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.body + V(side * a.size.X * 0.5, -0.06, -0.02)
		ball(m, "Fin", V(0.04, 0.16, 0.28), pos, second, { cf = CF(pos) * ANG(0.3, 0, side * 0.5) })
	end
end

function ACC.Lure(m: Model, a: Anchors, _main: Color3, second: Color3)
	local base = a.top
	local bend = base + V(0, 0.2, -0.1)
	local tip = bend + V(0, 0.02, -0.24)
	stick(m, "Lure", base, bend, 0.04, BLACK, { noShadow = true })
	stick(m, "Lure", bend, tip, 0.04, BLACK, { noShadow = true })
	local light = ball(m, "LureLight", V(0.13, 0.13, 0.13), tip + V(0, -0.04, 0), second, { material = Enum.Material.Neon, noShadow = true })
	local glow = Instance.new("PointLight")
	glow.Color = second
	glow.Range = 4
	glow.Brightness = 1.2
	glow.Parent = light
end

function ACC.Leaves(m: Model, a: Anchors)
	local green = hex("#5ACB4A")
	for i, angle in ipairs({ -0.7, 0, 0.7 }) do
		local pos = a.top + V(math.sin(angle) * 0.1, 0.06 + (if i == 2 then 0.04 else 0), 0)
		ball(m, "Leaf", V(0.06, 0.12, 0.3), pos, shade(green, (i - 2) * 0.1), { cf = CF(pos) * ANG(0, 0, -angle) * ANG(0.9, 0, 0) * CF(0, 0, -0.1) })
	end
end

function ACC.Crystal(m: Model, a: Anchors, _main: Color3, second: Color3)
	for i, angle in ipairs({ -0.5, 0, 0.5 }) do
		local pos = a.body + V(math.sin(angle) * 0.18, a.size.Y * 0.45, 0.08 + (i - 2) * 0.02)
		part(m, "Crystal", V(0.1, 0.32 - math.abs(angle) * 0.12, 0.1), CF(pos) * ANG(0.25, 0, -angle) * ANG(0, math.pi / 4, 0), second, { material = Enum.Material.Neon, transparency = 0.2, noShadow = true })
	end
end

function ACC.Glow(m: Model, a: Anchors, _main: Color3, second: Color3)
	local body = m:FindFirstChild("Body") or m:FindFirstChild("Dome")
	if body then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = second
		light.Range = 5
		light.Brightness = 1.4
		light.Parent = body
	end
end

function ACC.Gear(m: Model, a: Anchors, _main: Color3, second: Color3)
	local center = a.body + V(a.size.X * 0.5 + 0.03, 0.04, 0.05)
	stick(m, "Gear", center - V(0.03, 0, 0), center + V(0.03, 0, 0), 0.34, second, { material = Enum.Material.Metal })
	for i = 1, 8 do
		local t = i / 8 * math.pi * 2
		part(m, "Tooth", V(0.06, 0.08, 0.08), CF(center + V(0, math.cos(t) * 0.19, math.sin(t) * 0.19)) * ANG(-t, 0, 0), second, { material = Enum.Material.Metal, noShadow = true })
	end
	stick(m, "Axle", center, center + V(0.06, 0, 0), 0.1, BLACK, { noShadow = true })
end

function ACC.Laser(m: Model, a: Anchors)
	local red = hex("#FF3030")
	local base = a.top + V(0, 0.04, 0)
	part(m, "LaserBase", V(0.2, 0.08, 0.2), CF(base), shade(red, -0.6), { material = Enum.Material.Metal })
	stick(m, "Cannon", base + V(0, 0.06, 0.04), base + V(0, 0.06, -0.26), 0.08, hex("#3A3F48"), { material = Enum.Material.Metal })
	ball(m, "Muzzle", V(0.07, 0.07, 0.04), base + V(0, 0.06, -0.27), red, { material = Enum.Material.Neon, noShadow = true })
end

function ACC.Teeth(m: Model, a: Anchors)
	for _, side in ipairs({ -1, 1 }) do
		local pos = a.face + V(side * 0.06, -0.1, -0.02)
		part(m, "Tooth", V(0.05, 0.08, 0.04), CF(pos) * ANG(math.pi, 0, 0), WHITE, { shape = "wedge", noShadow = true })
	end
end

function ACC.Tentacles(m: Model, a: Anchors, main: Color3, second: Color3)
	local count = 6
	local baseY = a.body.Y - a.size.Y * 0.32
	for i = 1, count do
		local t = i / count * math.pi * 2
		local top = V(a.body.X + math.cos(t) * a.size.X * 0.3, baseY, a.body.Z + math.sin(t) * a.size.Z * 0.3)
		local drop = baseY - 0.04
		-- floating bodies let them hang; a body on the ground spreads them around it
		local spread = if drop < 0.3 then 0.36 else 0.1
		local bottom = V(top.X + math.cos(t) * spread, math.max(0.04, baseY - 0.5), top.Z + math.sin(t) * spread)
		stick(m, "Tentacle", top, bottom, 0.07, if i % 2 == 0 then main else second, { transparency = 0.1, noShadow = true })
	end
end

function ACC.Shell(m: Model, a: Anchors, _main: Color3, second: Color3)
	ball(m, "Shell", V(a.size.X * 0.92, a.size.Y * 0.7, a.size.Z * 0.92), a.body + V(0, a.size.Y * 0.22, 0.03), second, { material = Enum.Material.SmoothPlastic })
	part(m, "ShellLine", V(0.03, a.size.Y * 0.36, a.size.Z * 0.85), CF(a.body + V(0, a.size.Y * 0.4, 0.03)), shade(second, -0.4), { noShadow = true })
end

function ACC.Mask(m: Model, a: Anchors, _main: Color3, second: Color3)
	local pos = a.face + V(0, 0.04, -0.03)
	part(m, "Mask", V(0.46, 0.5, 0.06), CF(pos), second, { material = Enum.Material.Wood })
	for _, side in ipairs({ -1, 1 }) do
		part(m, "MaskEye", V(0.12, 0.05, 0.02), CF(pos + V(side * 0.1, 0.06, -0.035)), hex("#FFE070"), { material = Enum.Material.Neon, noShadow = true })
	end
	part(m, "MaskMouth", V(0.2, 0.05, 0.02), CF(pos + V(0, -0.12, -0.035)), BLACK, { noShadow = true })
end

----------------------------------------------------------------------------------------------------
-- building
----------------------------------------------------------------------------------------------------
local function newModel(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.2, 0.2, 0.2)
	root.CFrame = CF(0, 0.1, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local function seedOf(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483647
	end
	return h
end

local function has(list: { string }, name: string): boolean
	return table.find(list, name) ~= nil
end

function PetModels.pet(petId: string): Model
	local species = Pets.ById[petId]
	assert(species, `unknown pet {petId}`)
	local main, second = species.Colors[1], species.Colors[2]
	local acc = species.Accessories
	local model = newModel(petId)
	local glow = has(acc, "Glow")
	local bodyType = species.Body
	if bodyType == "Fish" and has(acc, "Tentacles") then
		bodyType = "Jelly"
	end
	local anchors = (BODIES :: any)[bodyType](model, main, second, glow) :: Anchors
	local rng = Random.new(seedOf(petId))
	for _, name in ipairs(acc) do
		local fn = (ACC :: any)[name]
		if fn then
			fn(model, anchors, main, second, rng)
		else
			warn(`PetModels: unknown accessory {name} ({petId})`)
		end
	end
	local flying = bodyType == "Bird" or bodyType == "Fish" or bodyType == "Jelly" or has(acc, "Wings") or has(acc, "BatWings")
		or (bodyType == "Blob" and (glow or has(acc, "Flame"))) or (bodyType == "Mech" and has(acc, "Antennae"))
	model:SetAttribute("Flying", flying)
	model:SetAttribute("Body", bodyType)
	if species.Scale ~= 1 then
		model:ScaleTo(species.Scale)
	end
	local _, size = model:GetBoundingBox()
	model:SetAttribute("Height", math.round(size.Y * 100) / 100)
	return model
end

-- Egg looks per zone (docs/zone_design_document.txt palettes): base, pattern color, accent, pattern.
local EGGS = {
	Plains = { "#8CCB6A", "#EAD9A0", "#8AC8F0", "spots" },
	Desert = { "#E8C27A", "#E07A2E", "#1FA59A", "stripes" },
	Jungle = { "#2E7A3A", "#6E4A2A", "#E2B04A", "leaves" },
	Tundra = { "#F2F6FA", "#7CC8EE", "#C8B6F0", "crystals" },
	Swamp = { "#5A6E3A", "#3E2E20", "#E8D84A", "spots" },
	Volcano = { "#2A2224", "#FF6A1F", "#8A8A90", "cracks" },
	Hell = { "#B0201A", "#1A0E0E", "#FF8A2A", "horns" },
	Heaven = { "#FFFFFF", "#E8C25A", "#BFE6FF", "wings" },
	Dead = { "#8A8A96", "#EFE6CC", "#7CFFB0", "bones" },
	Abyss = { "#1FA59A", "#1F3A7A", "#5FFFF0", "glowspots" },
	Mechanical = { "#9AA4B2", "#3FE6FF", "#F1C40F", "bolts" },
	Void = { "#1E1428", "#B05BFF", "#F5EED8", "cracks" },
}
local EGG_R = V(0.5, 0.66, 0.5) -- semi-axes
local EGG_C = V(0, 0.72, 0)

local function eggSurface(theta: number, y: number): (Vector3, Vector3)
	-- y = -1 (bottom) .. 1 (top); returns a point on the egg and its outward direction
	local ring = math.sqrt(math.max(0, 1 - y * y))
	local p = V(math.cos(theta) * ring * EGG_R.X, y * EGG_R.Y, math.sin(theta) * ring * EGG_R.Z)
	local n = V(p.X / (EGG_R.X * EGG_R.X), p.Y / (EGG_R.Y * EGG_R.Y), p.Z / (EGG_R.Z * EGG_R.Z)).Unit
	return EGG_C + p, n
end

function PetModels.egg(zoneId: string): Model
	local look = EGGS[zoneId]
	assert(look, `unknown zone {zoneId}`)
	local base, pattern, accent, kind = hex(look[1]), hex(look[2]), hex(look[3]), look[4]
	local model = newModel(string.lower(zoneId))
	local rng = Random.new(seedOf(zoneId))
	local material = if zoneId == "Mechanical" then Enum.Material.Metal else Enum.Material.SmoothPlastic
	ball(model, "Shell", EGG_R * 2, EGG_C, base, { material = material })
	local ring = part(model, "Ring", V(0.05, 1.3, 1.3), CF(0, 0.03, 0) * ANG(0, 0, HALF), WHITE, { shape = "cyl", material = Enum.Material.Neon, transparency = 0.35, noShadow = true })
	ring:SetAttribute("RarityRing", true)

	local function band(y: number, thickness: number, color: Color3, neon: boolean?)
		local r = math.sqrt(math.max(0, 1 - y * y)) * EGG_R.X
		part(model, "Band", V(thickness, r * 2 + 0.03, r * 2 + 0.03), CF(EGG_C + V(0, y * EGG_R.Y, 0)) * ANG(0, 0, HALF), color, { shape = "cyl", material = if neon then Enum.Material.Neon else material, noShadow = true })
	end
	local function spot(theta: number, y: number, size: number, color: Color3, neon: boolean?)
		local p, n = eggSurface(theta, y)
		ball(model, "Spot", V(size, size, 0.05), p, color, { cf = CFrame.lookAt(p, p + n), material = if neon then Enum.Material.Neon else nil, noShadow = true })
	end

	if kind == "spots" or kind == "glowspots" or kind == "bones" then
		for i = 1, 9 do
			spot(i * 2.4 + rng:NextNumber(0, 0.6), rng:NextNumber(-0.55, 0.75), rng:NextNumber(0.14, 0.24), if i % 3 == 0 then accent else pattern, kind == "glowspots")
		end
		if kind == "bones" then
			band(-0.25, 0.06, accent, true)
		end
	elseif kind == "stripes" then
		for _, y in ipairs({ -0.35, 0.05, 0.45 }) do
			band(y, 0.1, pattern)
		end
		spot(-HALF, 0.25, 0.16, accent)
	elseif kind == "leaves" then
		for i = 1, 7 do
			local t = i / 7 * math.pi * 2
			local p, n = eggSurface(t, -0.62)
			ball(model, "Leaf", V(0.14, 0.42, 0.06), p + n * 0.02, if i % 2 == 0 then shade(base, 0.15) else pattern, { cf = CFrame.lookAt(p, p + n) * ANG(0.15, 0, 0) })
		end
		band(0.2, 0.07, accent)
	elseif kind == "crystals" then
		for i = 1, 5 do
			local t = i / 5 * math.pi * 2
			local p, n = eggSurface(t, -0.5)
			part(model, "Crystal", V(0.1, 0.34, 0.1), CFrame.lookAt(p, p + n) * ANG(-HALF + 0.5, 0, 0), if i % 2 == 0 then accent else pattern, { material = Enum.Material.Glass, transparency = 0.15, noShadow = true })
		end
		spot(0.4, 0.5, 0.16, pattern)
		spot(2.5, 0.3, 0.12, accent)
	elseif kind == "cracks" then
		for i = 1, 14 do
			local t = i / 14 * math.pi * 2
			local y = if i % 2 == 0 then 0.12 else -0.08
			local p, n = eggSurface(t, y)
			part(model, "Crack", V(0.05, 0.2, 0.04), CFrame.lookAt(p, p + n) * ANG(0, 0, if i % 2 == 0 then 0.7 else -0.7), pattern, { material = Enum.Material.Neon, noShadow = true })
		end
		for i = 1, 4 do
			spot(i * 1.7, 0.55 - i * 0.08, 0.08, accent, zoneId == "Void")
		end
	elseif kind == "horns" then
		for _, side in ipairs({ -1, 1 }) do
			local p = EGG_C + V(side * 0.22, EGG_R.Y * 0.78, 0)
			part(model, "Horn", V(0.1, 0.3, 0.16), CF(p) * ANG(0, side * HALF, side * -0.5), pattern, { shape = "wedge" })
		end
		band(-0.3, 0.08, pattern)
		spot(-HALF, 0.15, 0.14, accent, true)
	elseif kind == "wings" then
		for _, side in ipairs({ -1, 1 }) do
			local p = EGG_C + V(side * 0.54, 0.08, 0.08)
			ball(model, "Wing", V(0.06, 0.4, 0.3), p, accent, { cf = CF(p) * ANG(0.3, side * -0.4, side * -0.5) })
		end
		band(0, 0.08, pattern)
		for i = 1, 8 do
			local t = i / 8 * math.pi * 2
			ball(model, "Halo", V(0.06, 0.05, 0.06), EGG_C + V(math.cos(t) * 0.18, EGG_R.Y + 0.14, math.sin(t) * 0.18), hex("#FFE070"), { material = Enum.Material.Neon, noShadow = true })
		end
	elseif kind == "bolts" then
		band(0, 0.08, pattern, true)
		band(0.45, 0.05, shade(base, -0.4))
		for i = 1, 6 do
			spot(i / 6 * math.pi * 2, -0.3, 0.09, accent)
		end
	end
	model:SetAttribute("Height", EGG_C.Y + EGG_R.Y)
	return model
end

-- Builds every pet and egg into ReplicatedStorage.Assets (replaces old copies). Returns a summary.
function PetModels.buildAll(): string
	local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	local function folder(name: string): Folder
		local f = assets:FindFirstChild(name) :: Folder?
		if not f then
			local new = Instance.new("Folder")
			new.Name = name
			new.Parent = assets
			f = new
		end
		return f :: Folder
	end
	local petsFolder, eggsFolder = folder("Pets"), folder("Eggs")
	local parts, count = 0, 0
	for _, species in ipairs(Pets.List) do
		local old = petsFolder:FindFirstChild(species.Id)
		if old then
			old:Destroy()
		end
		local model = PetModels.pet(species.Id)
		parts += #model:GetChildren()
		count += 1
		model.Parent = petsFolder
	end
	for _, zone in ipairs(Zones.List) do
		local old = eggsFolder:FindFirstChild(string.lower(zone.Id))
		if old then
			old:Destroy()
		end
		PetModels.egg(zone.Id).Parent = eggsFolder
	end
	return `{count} pets ({math.round(parts / count)} parts on average), {#Zones.List} eggs`
end

return PetModels
