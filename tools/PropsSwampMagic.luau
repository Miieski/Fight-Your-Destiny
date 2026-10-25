--[[
	PropsSwampMagic (dev tool, Edit mode only) - the owner's "CURSED SWAMP PROP IMPROVEMENT - Magic props and decor"
	(2026-10-25): 01 the frog statue altar (Toad_Shrine), 02 the frog totem (Toad_Totem), 03 the skull on the frame
	(Skull_Knocker_Door), 04 the spellbook (Spellbook_Floating), 05 the potion bottle (Potion_Bottle_A, Variant Purple),
	06 the hanging lantern (Hanging_Lantern), 07 the cauldron (Cauldron_Small), 08 the potion bookshelf (Potion_Shelf),
	09 the raven (Crow_A in the swamp; the gate ravens are nested swamp_raven props), to the fountain / well quality in the
	cursed swamp look (docs/prop_texture_guide.md sections A and F), keeping each kit's size, glows, lights and copies.
	Source of truth: tools/PropsSwampMagic.luau. Data: tools/PropsSwampMagicData.luau (today's kit parts).
	Inventory: docs/prop_inventory.md "Swamp magic".

	Glows (Neon eyes, orbs, runes, liquids, bottles) are today's parts kept exactly; the carving goes round them. Lights
	live on the copies: SM.prepLights(propId) moves each copy's own lights (or none) onto invisible kept parts
	(KeptLight_<part>, MapPropKeep) in the old light's place, so the templates carry no light. Colliders: where every
	copy matches its kit (03-06, 09: nothing collides) the template keeps today's rows; 01 / 02 / 07 / 08 drift from
	their kits (0.0001 .. 0.19), so SM.prepColliders(propId) gives each copy its own today's colliding parts, invisible,
	in a KeptCollision folder (MapPropKeep) and those templates carry no collider. Both read the untagged before-stash
	ServerStorage._MagicOld_<propId>.

		local SM = require(game.ServerStorage.DevTools.PropsSwampMagic:Clone())
		print(SM.install("swamp_frog_altar"))
		print(SM.prepColliders("swamp_frog_altar"), SM.prepLights("swamp_frog_altar"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "swamp_frog_altar" } }), Sync.run({ only = { "swamp_frog_altar" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()) :: any
local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any
local TB, B2, H, M = SH.TB, SH.B2, SH.H, SH.M
local GD = require(ServerStorage.DevTools.PropsSwampMagicData:Clone()) :: any
local piece, chamfered = H.piece, H.chamfered
local scaled = H.scaled
local frustumN = M.frustumN
local C = SH.COLORS
local blob, leafTone, leaf = ST.blob, ST.leafTone, ST.leaf

local SM = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local STONE_CORE = rgb(52, 60, 64) -- #343C40 the dark mortar / core between stone blocks
local GLYPH = rgb(38, 44, 46) -- #262C2E carved lines
local MOSS, MOSS_MID, OLIVE = C.MOSS, C.MOSS_MID, C.OLIVE
local MOSS_TOP = MOSS:Lerp(OLIVE, 0.3)

---------------------------------------------------------------------
-- rows, exact parts, kept colliders and lights
---------------------------------------------------------------------
local function rows(kit: string, name: string?): { any }
	return GD.rows(kit, name)
end
SM.rows = rows

-- an exact copy of a row (class, shape, size, place, colour, material, transparency, flags)
local function exactRow(parent: Instance, r: any): BasePart
	local p = Instance.new(r.class) :: BasePart
	if r.shape ~= "" and p:IsA("Part") then
		p.Shape = (Enum.PartType :: any)[r.shape]
	end
	p.Name = r.name
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = r.color
	p.Material = (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.CanTouch = true
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
SM.exactRow = exactRow

-- an invisible "Collision" copy of a colliding row
local function collider(m: Model, r: any): BasePart
	local p = exactRow(m, r)
	p.Name = "Collision"
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	p.CastShadow = false
	return p
end
SM.collider = collider

local function stashOf(propId: string): Folder
	local f = ServerStorage:FindFirstChild("_MagicOld_" .. propId)
	assert(f, "PropsSwampMagic: no before-stash _MagicOld_" .. propId)
	return f :: Folder
end

local function oldOf(stash: Folder, m: Model): Model?
	for _, o in ipairs(stash:GetChildren()) do
		if ((o :: Model):GetPivot().Position - m:GetPivot().Position).Magnitude < 0.01 then
			return o :: Model
		end
	end
	return nil
end

-- every copy keeps today's own colliding parts, invisible, in a KeptCollision folder (MapPropKeep); run before the sync
function SM.prepColliders(propId: string): string
	local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
	local stash = stashOf(propId)
	local n, parts = 0, 0
	for _, m in ipairs(Sync.find(propId)) do
		local old = oldOf(stash, m)
		assert(old, "PropsSwampMagic: no stash copy for " .. m:GetFullName())
		local prev = m:FindFirstChild("KeptCollision")
		if prev then
			prev:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "KeptCollision"
		folder:SetAttribute("MapPropKeep", true)
		for _, p in ipairs(old:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				local q = p:Clone()
				q:ClearAllChildren()
				q.Name = "Collision"
				q.Transparency = 1
				q.CastShadow = false
				q.Parent = folder
				parts += 1
			end
		end
		folder.Parent = m
		n += 1
	end
	return `prepColliders {propId}: {n} copies, {parts} kept colliding parts`
end

-- every copy keeps today's own lights (or none): each on an invisible kept part KeptLight_<the old parent's name> in
-- the old parent part's place (MapPropKeep); run before the sync
function SM.prepLights(propId: string): string
	local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
	local stash = stashOf(propId)
	local n, lights = 0, 0
	for _, m in ipairs(Sync.find(propId)) do
		local old = oldOf(stash, m)
		assert(old, "PropsSwampMagic: no stash copy for " .. m:GetFullName())
		for _, c in ipairs(m:GetChildren()) do
			if string.sub(c.Name, 1, 10) == "KeptLight_" then
				c:Destroy()
			end
		end
		local had = false
		for _, l in ipairs(old:GetDescendants()) do
			if l:IsA("Light") and l.Parent and l.Parent:IsA("BasePart") then
				local src = l.Parent :: BasePart
				local name = "KeptLight_" .. src.Name
				local holder = m:FindFirstChild(name) :: BasePart?
				if not holder then
					local p = Instance.new("Part")
					p.Name = name
					p.Size = src.Size
					p.CFrame = src.CFrame
					p.Anchored = true
					p.Transparency = 1
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.CastShadow = false
					p:SetAttribute("MapPropKeep", true)
					p.Parent = m
					holder = p
				end
				l:Clone().Parent = holder
				lights += 1
				had = true
			end
		end
		if had then
			n += 1
		end
	end
	return `prepLights {propId}: {n} copies keep {lights} light(s)`
end

---------------------------------------------------------------------
-- shared pieces
---------------------------------------------------------------------
local function tone(rng: Random, c: Color3): Color3
	return scaled(c, H.TONES[H.toneIndex(rng, nil)])
end

local function stoneTone(base: Color3): (Vector3) -> Color3
	return function(n: Vector3): Color3
		return scaled(base, 0.84 + 0.22 * (n.Y + 1) / 2)
	end
end

-- a box (size, cf) as bevelled stone blocks nx x nz with 0.07 joints over a dark core; courses = horizontal courses
-- (stagger every other one by half a block); the top stays exactly at the box top
local function stoneBlocks(list: { BasePart }, rng: Random, size: Vector3, cf: CFrame, color: Color3, nx: number, nz: number, courses: number?)
	local nc = courses or 1
	local gap = 0.07
	table.insert(list, piece("Part", size - Vector3.new(0.12, 0.06, 0.12), cf * CFrame.new(0, -0.03, 0), STONE_CORE))
	local ch = size.Y / nc
	for k = 0, nc - 1 do
		local y = -size.Y / 2 + ch * (k + 0.5)
		local stagger = (k % 2 == 1)
		local bx = size.X / nx
		local xs = {}
		if stagger then
			table.insert(xs, { -size.X / 2 + bx / 4, bx / 2 })
			for i = 1, nx - 1 do
				table.insert(xs, { -size.X / 2 + bx / 2 + bx * (i - 0.5), bx })
			end
			table.insert(xs, { size.X / 2 - bx / 4, bx / 2 })
		else
			for i = 0, nx - 1 do
				table.insert(xs, { -size.X / 2 + bx * (i + 0.5), bx })
			end
		end
		for _, e in ipairs(xs) do
			for j = 0, nz - 1 do
				local bz = size.Z / nz
				local z = -size.Z / 2 + bz * (j + 0.5)
				local s = Vector3.new(e[2] - gap, ch - (if k == nc - 1 then 0 else gap), bz - gap)
				local yy = y + (if k == nc - 1 then 0 else -gap / 2)
				table.insert(list, chamfered(s, cf * CFrame.new(e[1], yy, z), tone(rng, color), { "vertical", "topFrontBack", "topSides" }, math.min(0.14, s.Y * 0.2)))
			end
		end
	end
end
SM.stoneBlocks = stoneBlocks

-- a rounded frog part: the box (size, cf) keeps a flat bottom, front and back (the kept mouth bar and eyes stay where
-- they are), and its top and sides are cut by the tangent planes of an ellipsoid (radii k x the half size, its centre
-- dy under the box centre) in 12 azimuths x 4 elevations: a domed head or back, rounded cheeks; front = -Z
local function roundSolid(list: { BasePart }, cf: CFrame, size: Vector3, toneOf: (Vector3) -> Color3, k: Vector3?, dy: number?, flatFront: boolean?)
	local half = size / 2
	local kk = k or Vector3.new(1.04, 1.0, 1.08)
	local rx, ry, rz = half.X * kk.X, half.Y * kk.Y, half.Z * kk.Z
	local c = Vector3.new(0, -(dy or 0.1) * half.Y, 0)
	local planes = {
		{ n = -UP, d = half.Y },
		{ n = Vector3.zAxis, d = half.Z },
	}
	if flatFront ~= false then
		table.insert(planes, { n = -Vector3.zAxis, d = half.Z })
	end
	for _, el in ipairs({ -0.15, 0.35, 0.75, 1.15 }) do
		for a = 0, 11 do
			local az = a * math.pi / 6
			local n = Vector3.new(math.cos(az) * math.cos(el), math.sin(el), math.sin(az) * math.cos(el)).Unit
			table.insert(planes, { n = n, d = n:Dot(c) + math.sqrt((rx * n.X) ^ 2 + (ry * n.Y) ^ 2 + (rz * n.Z) ^ 2) })
		end
	end
	table.insert(planes, { n = UP, d = c.Y + ry })
	local e = size * 0.8
	TB.solidOf(list, cf, -e, e, planes, toneOf)
end
SM.roundSolid = roundSolid

-- a wide grin round a kept mouth bar (r): an upper and a lower lip of 9 bevelled segments on a shallow arc (the corners
-- rise), the last segment at each end wrapping back round the cheek; and dark curled corners extending the slot
local function grin(list: { BasePart }, dark: { BasePart }, r: any, color: Color3, wrap: number)
	local w = r.size.X / 2 + 0.35
	for li, lip in ipairs({ { r.size.Y / 2 + 0.13, 0.24, 0.17, 1.08 }, { -r.size.Y / 2 - 0.14, 0.28, 0.09, 0.94 } }) do
		local prev = nil
		for s = -4, 4 do
			local t = s / 4
			local x = t * w
			local y = lip[1] + lip[3] * t * t
			local z = -0.06 + (if math.abs(s) == 4 then wrap else 0)
			local p = (r.cf * CFrame.new(x, y, z)).Position
			if prev then
				table.insert(list, chamfered(Vector3.new(lip[2], lip[2], (p - prev).Magnitude + lip[2] * 0.6), CFrame.lookAt((prev + p) / 2, p), scaled(color, lip[4]), { "topFrontBack" }, 0.06))
			end
			prev = p
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(dark, piece("Part", Vector3.new(0.45, r.size.Y * 0.8, r.size.Z * 0.9), r.cf * CFrame.new(sx * (r.size.X / 2 + 0.12), 0.12, 0.02) * CFrame.Angles(0, 0, rad(sx * 28)), r.color))
	end
end
SM.grin = grin

-- a pale rounded throat pouch under the jaw (centre p, half sizes a, b, c)
local function pouch(list: { BasePart }, rng: Random, p: Vector3, a: number, b: number, c: number, color: Color3)
	blob(list, rng, CFrame.new(p), a, b, c, function(n: Vector3): Color3
		return scaled(color, 0.92 + 0.16 * (1 - math.abs(n.Y)))
	end)
end
SM.pouch = pouch

-- a rounded front leg (an 8-sided column with a shoulder bulge) on splayed webbed toes: 3 toes fanned forward over a flat
-- web, each with a round tip; r = the leg row
local function roundLeg(list: { BasePart }, detail: { BasePart }, rng: Random, r: any, color: Color3)
	local top = r.cf.Position + Vector3.new(0, r.size.Y / 2, 0)
	local bottom = r.cf.Position - Vector3.new(0, r.size.Y / 2, 0)
	local rr = math.min(r.size.X, r.size.Z) / 2
	table.insert(list, frustumN(8, rr * 0.86, rr * 0.98, bottom.Y + 0.25, top.Y - 0.2, CFrame.new(bottom.X, 0, bottom.Z) * CFrame.Angles(0, rad(22.5), 0), { color, scaled(color, 1.06), scaled(color, 0.92) }))
	blob(list, rng, CFrame.new(top - Vector3.new(0, 0.45, 0)), rr * 1.15, 0.6, rr * 1.1, stoneTone(color))
	local foot = bottom + Vector3.new(0, 0.12, -rr * 0.6)
	blob(detail, rng, CFrame.new(foot + Vector3.new(0, 0.05, rr * 0.4)), rr * 0.9, 0.18, rr * 0.8, stoneTone(color), 0.12)
	leaf(detail, foot + Vector3.new(0, 0.02, 0.15), -Vector3.zAxis, rr * 1.35, rr * 1.9, scaled(color, 0.96), UP)
	for t = -1, 1 do
		local d = Vector3.new(math.sin(rad(t * 34)), 0, -math.cos(rad(t * 34)))
		local tip = foot + d * rr * 1.25
		table.insert(detail, H.bar(foot, tip, 0.17, scaled(color, 1.04)))
		blob(detail, rng, CFrame.new(tip + Vector3.new(0, 0.02, 0)), 0.14, 0.1, 0.14, stoneTone(scaled(color, 1.1)), 0.08)
	end
end
SM.roundLeg = roundLeg

-- a rounded low-poly solid (round 2): the convex hull of an ellipsoid's tangent planes (radii r in `frame`), nAz
-- azimuths on each elevation ring (every other ring turned half a step: staggered facets), a top plane, a bottom plane
-- `cut.bottom` under the centre (flat on its support) and an optional flat front plane `cut.front` ahead of it (-Z)
local function ellipsoidSolid(list: { BasePart }, frame: CFrame, r: Vector3, toneOf: (Vector3) -> Color3, nAz: number, els: { number }, cut: any?)
	local planes = {}
	for i, el in ipairs(els) do
		local off = (i % 2) * math.pi / nAz
		for a = 0, nAz - 1 do
			local az = a * 2 * math.pi / nAz + off
			local n = Vector3.new(math.cos(el) * math.cos(az), math.sin(el), math.cos(el) * math.sin(az))
			table.insert(planes, { n = n, d = math.sqrt((r.X * n.X) ^ 2 + (r.Y * n.Y) ^ 2 + (r.Z * n.Z) ^ 2) })
		end
	end
	table.insert(planes, { n = UP, d = r.Y })
	table.insert(planes, { n = -UP, d = if cut and cut.bottom then cut.bottom else r.Y })
	if cut and cut.front then
		table.insert(planes, { n = -Vector3.zAxis, d = cut.front })
	end
	TB.solidOf(list, frame, -r * 1.05, r * 1.05, planes, toneOf)
end
SM.ellipsoidSolid = ellipsoidSolid

---------------------------------------------------------------------
-- 01 FROG STATUE ALTAR (kit MapAssets.Swamp.Toad_Shrine: 3 pedestal steps, ToadBody, ToadHead, 2 front legs, 2 back
-- legs, 2 bowl cylinders (all collide), 2 Neon Eye balls and 2 Neon BowlGlow discs #8CFF5A, the dark mouth bar, a moss
-- slab; 14 x 10.85 x 12; 3 copies: test, kit, BossArenas.Swamp (scale 1.2, a PointLight under its ToadHead))
---------------------------------------------------------------------
-- From today's parts (round 2: rounder): the 3 steps as bevelled stone blocks with joints over a dark core (the plinth
-- in 2 staggered courses), 3 lily pads in relief with ripple rings carved on the plinth front and a wavy ripple line on
-- the middle step; the frog (ellipsoidSolid: faceted rounded solids, not boxes): a chunky rounded body sitting on the
-- plinth, a wide rounded head with a flat face, today's mouth bar kept exactly as the top of an open grin (a dark
-- crescent under it, lips, corners curling up into the cheeks, a pale throat), today's 2 glowing eyes kept exactly on
-- bulging mounds with lid rings, front
-- legs with webbed hands, back legs as big haunches with webbed feet, warts and cracks; moss on the head and
-- back; today's 2 bowls as carved stone bowls (a foot, a flared body, a rim of 8 segments, notches) round today's 2
-- glowing discs kept exactly; moss cushions and 2 leafy vines on the pedestal, ghost mushrooms at 2 corners.
-- Colliders: each copy keeps its own (KeptCollision); the light: each copy's own (KeptLight_ToadHead).
-- Parts: Pedestal (PrimaryPart), Frieze, Frog, FrogDetail, Bowls, Moss, Vines, VineLeaves, Mush, Eye x2, BowlGlow x2,
-- Part (the mouth)
function SM.swamp_frog_altar(): Model
	local kit = "Toad_Shrine"
	local m = Instance.new("Model")
	m.Name = "swamp_frog_altar"
	local rng = Random.new(20261201)
	H.setBevelSelf(true)
	local U: any = { Pedestal = {}, Frieze = {}, Frog = {}, FrogDetail = {}, Bowls = {}, Moss = {}, Vines = {}, VineLeaves = {}, Mush = {} }
	local steps, fronts, backs, bowls, mouth = {}, {}, {}, {}, nil
	for _, r in ipairs(rows(kit, "Part")) do
		if r.shape == "Cylinder" then
			table.insert(bowls, r)
		elseif r.color:ToHex() == "1e1613" then
			mouth = r
		elseif r.size.X >= 7 then
			table.insert(steps, r)
		elseif math.abs(r.size.Y - 3.2) < 0.01 then
			table.insert(fronts, r)
		else
			table.insert(backs, r)
		end
	end
	table.sort(steps, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	-- the pedestal
	stoneBlocks(U.Pedestal, rng, steps[1].size, steps[1].cf, steps[1].color, 4, 3)
	stoneBlocks(U.Pedestal, rng, steps[2].size, steps[2].cf, steps[2].color, 3, 2)
	stoneBlocks(U.Pedestal, rng, steps[3].size, steps[3].cf, steps[3].color, 3, 2, 2)
	-- the carved front (round 2): on the plinth 3 lily pads in raised relief (a notch and 2 veins each) with ripple rings
	-- under them, a groove above and below; on the middle step a wavy ripple line
	do
		local p = steps[3]
		local fz = p.cf.Z - p.size.Z / 2
		local relief = scaled(p.color, 1.16)
		for _, dy in ipairs({ p.size.Y * 0.4, -p.size.Y * 0.4 }) do
			table.insert(U.Frieze, piece("Part", Vector3.new(p.size.X - 0.5, 0.08, 0.04), CFrame.new(p.cf.X, p.cf.Y + dy, fz - 0.01), GLYPH))
		end
		for _, pad in ipairs({ { 0, 0.15, 0.72, 0.6 }, { -2.2, -0.05, 0.52, 2.4 }, { 2.2, -0.05, 0.52, -0.9 } }) do
			local c = Vector3.new(p.cf.X + pad[1], p.cf.Y + pad[2], fz)
			local face = CFrame.new(c) * CFrame.Angles(rad(-90), 0, 0) -- Y out of the face (-Z)
			table.insert(U.Frieze, frustumN(12, pad[3], pad[3] * 0.94, -0.01, 0.07, face, { relief, scaled(relief, 0.94) }))
			local nd = Vector3.new(math.cos(pad[4]), math.sin(pad[4]), 0)
			table.insert(U.Frieze, H.bar(c + Vector3.new(0, 0, -0.06), c + nd * pad[3] * 1.02 + Vector3.new(0, 0, -0.06), 0.09, GLYPH))
			for _, va in ipairs({ pad[4] + 2.1, pad[4] - 2.1 }) do
				local vd = Vector3.new(math.cos(va), math.sin(va), 0)
				table.insert(U.Frieze, H.bar(c + vd * 0.12 + Vector3.new(0, 0, -0.075), c + vd * pad[3] * 0.78 + Vector3.new(0, 0, -0.075), 0.05, scaled(relief, 0.86)))
			end
			for ring = 1, 2 do
				local R = pad[3] + 0.22 * ring
				local prev = nil
				for k = 0, 6 do
					local t = rad(200 + k * 140 / 6)
					local q = c + Vector3.new(math.cos(t) * R * 1.25, math.sin(t) * R * 0.75, -0.02)
					if prev then
						table.insert(U.Frieze, H.bar(prev, q, 0.06, GLYPH))
					end
					prev = q
				end
			end
		end
		local s2 = steps[2]
		local wz = s2.cf.Z - s2.size.Z / 2 - 0.02
		local prev = nil
		for k = 0, 12 do
			local x = -3.4 + k * 6.8 / 12
			local q = Vector3.new(s2.cf.X + x, s2.cf.Y + (if k % 2 == 0 then 0.1 else -0.1), wz)
			if prev then
				table.insert(U.Frieze, H.bar(prev, q, 0.07, GLYPH))
			end
			prev = q
		end
	end
	-- THE FROG (round 2, the owner: "a charming, rounded, chunky stone frog"): a faceted rounded body sitting on the
	-- plinth, a wide rounded head with a flat face front, today's mouth bar kept exactly as the top of an open grin (a dark
	-- crescent, lips, corners curling up into the cheeks) and a pale throat; today's 2 glowing eyes kept exactly on
	-- bulging mounds with lid rings; front legs (shoulder, forearm, a webbed hand of 3 splayed toes with round pads), back
	-- legs as big haunches with webbed feet; warts, cracks
	local stone = rows(kit, "ToadBody")[1]
	local head = rows(kit, "ToadHead")[1]
	local plinthTop = steps[3].cf.Y + steps[3].size.Y / 2
	local SKIN = stone.color
	local HEADC = scaled(head.color, 1.04)
	local PALE = scaled(head.color, 1.3)
	local bodyF = CFrame.new(0, plinthTop + 2.0, stone.cf.Z - 0.4) * CFrame.Angles(rad(-6), 0, 0)
	local bodyR = Vector3.new(3.05, 2.15, 2.75)
	ellipsoidSolid(U.Frog, bodyF, bodyR, stoneTone(SKIN), 10, { -0.55, -0.15, 0.25, 0.65, 1.05 }, { bottom = 2.0 })
	local hc = Vector3.new(0, head.cf.Y + 0.1, head.cf.Z - 0.05)
	local headR = Vector3.new(3.0, 1.45, 2.3)
	local FRONT = 1.6 -- the flat face front: z = hc.Z - 1.6
	ellipsoidSolid(U.Frog, CFrame.new(hc), headR, stoneTone(HEADC), 12, { -0.5, -0.15, 0.2, 0.55, 0.95 }, { bottom = 1.2, front = FRONT })
	-- the head surface z (in front) at (x, y)
	local function faceZ(x: number, y: number): number
		local u = 1 - ((x - hc.X) / headR.X) ^ 2 - ((y - hc.Y) / headR.Y) ^ 2
		local ez = hc.Z - headR.Z * math.sqrt(math.max(u, 0))
		return math.max(ez, hc.Z - FRONT)
	end
	if mouth then
		exactRow(m, mouth)
		local my = mouth.cf.Y
		local hx = mouth.size.X / 2
		local LIP = scaled(head.color, 1.12)
		-- the smile: dark corners curling up and back into the cheeks, a lip over the whole line
		for _, s in ipairs({ -1, 1 }) do
			local pts = { Vector3.new(s * (hx - 0.1), my, mouth.cf.Z) }
			for _, q in ipairs({ { 0.25, 0.18 }, { 0.5, 0.45 }, { 0.68, 0.8 } }) do
				local x, y = s * (hx + q[1]), my + q[2]
				table.insert(pts, Vector3.new(x, y, faceZ(x, y) - 0.06))
			end
			for i = 1, #pts - 1 do
				table.insert(U.FrogDetail, H.bar(pts[i], pts[i + 1], 0.27 - 0.04 * i, mouth.color))
				local a, b = pts[i] + Vector3.new(0, 0.24, -0.04), pts[i + 1] + Vector3.new(0, 0.22, -0.04)
				table.insert(U.FrogDetail, H.bar(a, b, 0.2, LIP))
			end
		end
		table.insert(U.FrogDetail, chamfered(Vector3.new(mouth.size.X - 0.1, 0.2, 0.26), CFrame.new(0, my + mouth.size.Y / 2 + 0.1, mouth.cf.Z - 0.06), LIP, { "topFrontBack" }, 0.06))
		-- the open grin: a dark crescent under the slot (deepest in the middle), a light lower lip following it, the pale
		-- throat under the chin
		local prevC, prevL = nil, nil
		for k = -4, 4 do
			local t = k / 4
			local x = t * (hx - 0.25)
			local y = my - 0.02 - 0.38 * (1 - t * t)
			local c = Vector3.new(x, y, faceZ(x, y) - 0.04)
			local l = Vector3.new(x, y - 0.22, faceZ(x, y - 0.22) - 0.05)
			if prevC then
				table.insert(U.FrogDetail, H.bar(prevC, c, 0.28, mouth.color))
				table.insert(U.FrogDetail, H.bar(prevL, l, 0.18, LIP))
			end
			prevC, prevL = c, l
		end
		blob(U.FrogDetail, rng, CFrame.new(0, hc.Y - headR.Y - 0.25, hc.Z - FRONT + 0.6), 1.7, 0.45, 0.75, function(n: Vector3): Color3
			return scaled(PALE, 0.94 + 0.12 * (1 - math.abs(n.Y)))
		end)
	end
	-- today's eyes exactly, on bulging mounds with a lid ring
	for _, r in ipairs(rows(kit, "Eye")) do
		exactRow(m, r)
		local ec = r.cf.Position
		local er = r.size.X / 2
		blob(U.Frog, rng, CFrame.new(ec.X, ec.Y - er * 0.55, ec.Z), er * 1.3, er * 0.75, er * 1.3, stoneTone(HEADC))
		table.insert(U.FrogDetail, frustumN(10, er * 1.16, er * 1.03, ec.Y - er * 0.5, ec.Y + er * 0.05, CFrame.new(ec.X, 0, ec.Z) * CFrame.Angles(0, rad(18), 0), { scaled(HEADC, 1.12), HEADC, scaled(HEADC, 0.92) }))
	end
	-- warts: bumps on the back and the head (on the solids' surfaces)
	for k = 1, 12 do
		local onHead = k <= 4
		local az = rng:NextNumber(0, 2 * math.pi)
		local el = rng:NextNumber(0.35, 1.0)
		local rr = if onHead then headR else bodyR
		local lp = Vector3.new(rr.X * math.cos(el) * math.cos(az), rr.Y * math.sin(el), rr.Z * math.cos(el) * math.sin(az))
		local wp = if onHead then hc + lp else bodyF * lp
		if onHead and wp.Z < hc.Z - FRONT + 0.4 then
			continue
		end
		local s = rng:NextNumber(0.16, 0.28)
		blob(U.FrogDetail, rng, CFrame.new(wp), s, s * 0.7, s, stoneTone(scaled(SKIN, rng:NextNumber(1.02, 1.15))))
	end
	-- cracks: 2 short zigzags on the body's sides
	for _, s in ipairs({ -1, 1 }) do
		local pts = {}
		for k = 0, 3 do
			local el = -0.1 + k * 0.22
			local az = (if s > 0 then 0.35 else math.pi - 0.35) + (if k % 2 == 0 then 0.06 else -0.06) * s
			table.insert(pts, bodyF * Vector3.new(bodyR.X * 1.01 * math.cos(el) * math.cos(az), bodyR.Y * 1.01 * math.sin(el), bodyR.Z * 1.01 * math.cos(el) * math.sin(az)))
		end
		for i = 1, #pts - 1 do
			table.insert(U.FrogDetail, H.bar(pts[i], pts[i + 1], 0.07, GLYPH))
		end
	end
	-- a webbed hand / foot on the plinth: a palm, 3 splayed toes (2 segments, the tips drooping `droop` over an edge)
	-- with round pads, a web between them
	local function webbedFoot(palm: Vector3, fwd: Vector3, size: number, color: Color3, droop: number)
		blob(U.FrogDetail, rng, CFrame.new(palm) * CFrame.Angles(0, math.atan2(-fwd.X, -fwd.Z), 0), 0.5 * size, 0.22 * size, 0.48 * size, stoneTone(color), 0.1)
		local side = fwd:Cross(UP).Unit
		for t = -1, 1 do
			local d = (fwd + side * t * 0.7).Unit
			local knuckle = palm + d * 0.5 * size
			local tip = knuckle + d * 0.15 * size + Vector3.new(0, -0.06 * size - droop, 0)
			table.insert(U.FrogDetail, H.bar(palm + d * 0.15, knuckle, 0.19 * size, scaled(color, 1.04)))
			table.insert(U.FrogDetail, H.bar(knuckle, tip, 0.17 * size, scaled(color, 1.04)))
			blob(U.FrogDetail, rng, CFrame.new(tip), 0.17 * size, 0.12 * size, 0.17 * size, stoneTone(scaled(color, 1.1)), 0.06)
		end
		leaf(U.FrogDetail, palm + Vector3.new(0, -0.1 * size, 0) + fwd * 0.1, (fwd - UP * droop * 0.4).Unit, 0.6 * size, 1.15 * size, scaled(color, 0.94), UP)
	end
	for _, r in ipairs(fronts) do
		local s = if r.cf.X < 0 then -1 else 1
		local p = r.cf.Position
		blob(U.Frog, rng, CFrame.new(p.X - s * 0.05, p.Y + 0.9, p.Z + 0.3), 0.92, 0.98, 0.95, stoneTone(SKIN))
		local elbow = Vector3.new(p.X, p.Y + 0.7, p.Z + 0.1)
		local wrist = Vector3.new(p.X + s * 0.15, plinthTop + 0.2, p.Z + 0.25)
		table.insert(U.Frog, frustumN(8, 0.5, 0.42, -0.1, (elbow - wrist).Magnitude + 0.1, H.frameY(wrist, elbow - wrist), { SKIN, scaled(SKIN, 1.08), scaled(SKIN, 0.92) }))
		-- the hands grip the plinth's front edge: the toe tips curl down over it
		webbedFoot(Vector3.new(wrist.X + s * 0.1, plinthTop + 0.14, wrist.Z), Vector3.new(s * 0.3, 0, -1).Unit, 1.0, SKIN, 0.42)
	end
	for _, r in ipairs(backs) do
		local s = if r.cf.X < 0 then -1 else 1
		local p = r.cf.Position
		blob(U.Frog, rng, CFrame.new(p.X - s * 0.25, p.Y + 0.2, p.Z - 0.1) * CFrame.Angles(0, rad(s * 12), 0), 1.15, 1.05, 1.55, stoneTone(SKIN))
		webbedFoot(Vector3.new(p.X - s * 0.35, plinthTop + 0.14, p.Z - 1.35), Vector3.new(s * 0.25, 0, -1).Unit, 0.9, SKIN, 0)
	end
	-- moss on the head and the back (today's moss slab's place first)
	for _, r in ipairs(rows(kit, "Moss")) do
		blob(U.Moss, rng, r.cf * CFrame.new(-0.6, 0, 0.2), r.size.X * 0.32, r.size.Y * 0.6, r.size.Z * 0.4, leafTone(r.color), 0.12)
		blob(U.Moss, rng, r.cf * CFrame.new(0.9, -0.05, 0.4), r.size.X * 0.22, r.size.Y * 0.5, r.size.Z * 0.32, leafTone(MOSS_TOP), 0.1)
	end
	ST.mossCushion(U.Moss, rng, H.frameY(stone.cf.Position + Vector3.new(0.8, stone.size.Y / 2 - 0.1, 1.2), UP), 1.6)
	-- the bowls: a foot, a flared body, a rim of 8 segments round today's glow disc, 4 notches; the discs kept exactly
	for _, r in ipairs(bowls) do
		local bc = r.cf.Position
		local h = r.size.X
		local R = r.size.Y / 2
		local y0, y1 = bc.Y - h / 2, bc.Y + h / 2
		local c = r.color
		local frame = CFrame.new(bc.X, 0, bc.Z)
		table.insert(U.Bowls, frustumN(8, R * 0.62, R * 0.52, y0, y0 + h * 0.3, frame, { c, scaled(c, 0.92) }))
		table.insert(U.Bowls, frustumN(8, R * 0.62, R * 1.0, y0 + h * 0.3, y1 - 0.02, frame * CFrame.Angles(0, rad(22.5), 0), { scaled(c, 1.05), c, scaled(c, 0.93) }))
		for k = 0, 7 do
			local a = k * math.pi / 4
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			table.insert(U.Bowls, chamfered(Vector3.new(0.34, 0.22, 2 * R * math.tan(math.pi / 8) * 1.04), CFrame.lookAt(Vector3.new(bc.X, y1 + 0.06, bc.Z) + d * (R - 0.08), Vector3.new(bc.X, y1 + 0.06, bc.Z) + d * (R + 1)) * CFrame.Angles(0, rad(90), 0), scaled(c, if k % 2 == 0 then 1.08 else 1.0), { "topFrontBack" }, 0.06))
		end
		for k = 0, 3 do
			local a = k * math.pi / 2 + rad(22.5)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			table.insert(U.Frieze, piece("Part", Vector3.new(0.08, h * 0.4, 0.05), CFrame.lookAt(Vector3.new(bc.X, y0 + h * 0.62, bc.Z) + d * (R * 0.85 + 0.02), Vector3.new(bc.X, y0 + h * 0.62, bc.Z) + d * 5), GLYPH))
		end
	end
	for _, r in ipairs(rows(kit, "BowlGlow")) do
		exactRow(m, r)
	end
	-- moss and vines on the pedestal; ghost mushrooms at 2 corners
	local s1, s3 = steps[1], steps[3]
	for _, e in ipairs({ { -1, -1 }, { 1, 1 }, { 1, -1 } }) do
		local p = s1.cf.Position + Vector3.new(e[1] * (s1.size.X / 2 - 0.9), s1.size.Y / 2, e[2] * (s1.size.Z / 2 - 0.9))
		ST.mossCushion(U.Moss, rng, H.frameY(p, UP), 1.5)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local top = s3.cf.Position + Vector3.new(sx * (s3.size.X / 2 - 0.15), s3.size.Y / 2 - 0.05, -s3.size.Z / 2 + 0.1)
		table.insert(U.Vines, frustumN(6, 0.28, 0.16, -0.12, 0.12, CFrame.new(top), { MOSS, scaled(MOSS, 0.85), MOSS_TOP }))
		ST.leafyVine(U.Vines, U.VineLeaves, rng, top, s3.size.Y - 0.2, 0.18, scaled(MOSS, 0.9))
	end
	for _, e in ipairs({ { 1, 1 }, { -1, 1 } }) do
		local p = s1.cf.Position + Vector3.new(e[1] * (s1.size.X / 2 - 0.6), s1.size.Y / 2, e[2] * (s1.size.Z / 2 - 0.5))
		ST.ghostMushrooms(U.Mush, rng, p, 3, 0.55)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_frog_altar", U, "Pedestal")
	return m
end

-- small helpers for the props below

-- a low-poly skull (round 2, the owner: "a rounded cranium, a brow, cheek bones, a nose cavity, upper teeth and a jaw")
-- round today's cranium row `cr` and jaw row `jaw` (front = -Z; today's sockets, eyes, nose and teeth line sit on its
-- flat face front at cr's front): a faceted rounded cranium (a flat face, a flat underside), the upper jaw (maxilla)
-- with 6 upper teeth, a rounded lower jaw with 5 teeth, a brow ridge arching over the sockets, cheekbones, a raised rim
-- round the nose cavity (`nose`: today's nose row, optional) and 2 hairline cracks on the crown
local function skullBone(list: { BasePart }, rng: Random, cr: any, jaw: any, nose: any?)
	local C, S = cr.cf.Position, cr.size
	local J, JS = jaw.cf.Position, jaw.size
	local bone = cr.color
	local face = C.Z - S.Z / 2
	local tone = function(c: Color3): (Vector3) -> Color3
		return function(n: Vector3): Color3
			return scaled(c, 0.84 + 0.2 * (n.Y + 1) / 2)
		end
	end
	local cc = Vector3.new(C.X, C.Y + 0.05, C.Z)
	local cr3 = Vector3.new(S.X / 2 + 0.02, S.Y / 2 + 0.08, S.Z / 2 + 0.05)
	ellipsoidSolid(list, CFrame.new(cc), cr3, tone(bone), 12, { -0.4, -0.05, 0.3, 0.65, 1.0 }, { bottom = S.Y / 2 - 0.3, front = cc.Z - face })
	-- the upper jaw under the face, its teeth just over today's teeth line
	local my = J.Y + JS.Y / 2 - 0.05
	local mc = Vector3.new(C.X, C.Y - S.Y * 0.36, C.Z - 0.05)
	local mr = Vector3.new(S.X * 0.36, S.Y * 0.25, S.Z * 0.45)
	ellipsoidSolid(list, CFrame.new(mc), mr, tone(scaled(bone, 0.97)), 10, { -0.3, 0.2, 0.7 }, { bottom = mc.Y - my, front = mc.Z - (face + 0.05) })
	for k = -2.5, 2.5 do
		table.insert(list, chamfered(Vector3.new(0.17, 0.22, 0.12), CFrame.new(C.X + k * 0.21, my + 0.1, face + 0.02), scaled(bone, 1.04), { "bottomFrontBack" }, 0.04))
	end
	-- the lower jaw, rounded, 5 teeth under the line
	local jc = Vector3.new(J.X, J.Y - 0.05, J.Z)
	local jr = Vector3.new(JS.X / 2 + 0.05, JS.Y / 2 + 0.02, JS.Z / 2 + 0.05)
	ellipsoidSolid(list, CFrame.new(jc), jr, tone(jaw.color), 10, { -0.5, -0.1, 0.35, 0.8 }, { front = JS.Z / 2 + 0.05 - 0.05 })
	for k = -2, 2 do
		table.insert(list, chamfered(Vector3.new(0.16, 0.2, 0.12), CFrame.new(J.X + k * 0.2, J.Y + JS.Y / 2 - 0.28, J.Z - JS.Z / 2 - 0.04), scaled(bone, 1.0), { "topFrontBack" }, 0.04))
	end
	-- the brow ridge over the sockets (2 arcs meeting over the nose)
	for _, sx in ipairs({ -1, 1 }) do
		local pts = {}
		for k = 0, 3 do
			local x = C.X + sx * (0.08 + k * S.X * 0.15)
			local y = C.Y + 0.48 + 0.1 * math.sin(k / 3 * math.pi)
			table.insert(pts, Vector3.new(x, y, face - 0.08 + 0.04 * k))
		end
		for i = 1, #pts - 1 do
			table.insert(list, H.bar(pts[i], pts[i + 1], 0.22, scaled(bone, 1.06)))
		end
		-- a cheekbone under and outside each socket
		blob(list, rng, CFrame.new(C.X + sx * S.X * 0.37, C.Y - 0.42, face + 0.04), 0.32, 0.2, 0.22, tone(scaled(bone, 1.04)))
	end
	-- the rim round the nose cavity (an inverted V)
	if nose then
		local n = nose.cf.Position
		local h = nose.size.Y / 2
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(list, H.bar(Vector3.new(n.X + sx * (nose.size.X / 2 + 0.08), n.Y - h, face - 0.06), Vector3.new(n.X, n.Y + h + 0.1, face - 0.06), 0.08, scaled(bone, 1.08)))
		end
	end
	-- 2 hairline cracks on the crown (on the cranium's surface)
	local function onCrown(x: number, y: number): Vector3
		local u = 1 - ((x - cc.X) / cr3.X) ^ 2 - ((y - cc.Y) / cr3.Y) ^ 2
		return Vector3.new(x, y, math.max(cc.Z - cr3.Z * math.sqrt(math.max(u, 0)), face) - 0.02)
	end
	for _, crk in ipairs({ { -0.75, 0.75, -0.55, 0.95, -0.35, 1.05 }, { 0.55, 0.85, 0.75, 0.62, 0.92, 0.7 } }) do
		local a, b, c = onCrown(C.X + crk[1], C.Y + crk[2]), onCrown(C.X + crk[3], C.Y + crk[4]), onCrown(C.X + crk[5], C.Y + crk[6])
		table.insert(list, H.bar(a, b, 0.05, GLYPH))
		table.insert(list, H.bar(b, c, 0.05, GLYPH))
	end
end
SM.skullBone = skullBone
local IRON = rgb(55, 58, 65) -- #373A41 today's dark iron
local IRON_LIGHT = rgb(84, 88, 98)
local GOLD = rgb(214, 170, 72) -- #D6AA48
local ROPE = rgb(150, 122, 80)
local BONE = C.BONE

-- a rivet head (a low 6-sided dome) at p on a face with normal n
local function rivet(list: { BasePart }, p: Vector3, n: Vector3, r: number?)
	local rr = r or 0.07
	table.insert(list, frustumN(6, rr, rr * 0.55, -0.02, rr * 0.8, H.frameY(p, n), { IRON_LIGHT, IRON }))
end
SM.rivet = rivet

-- a ring of n straight bar segments round `centre` in the plane with normal `axis`, radius R, bar thickness t
local function ring(list: { BasePart }, centre: Vector3, axis: Vector3, R: number, t: number, n: number, color: Color3)
	local u = (if math.abs(axis.Unit.Y) < 0.9 then UP else Vector3.xAxis):Cross(axis).Unit
	local v = axis.Unit:Cross(u)
	local prev = centre + u * R
	for k = 1, n do
		local a = k * 2 * math.pi / n
		local q = centre + (u * math.cos(a) + v * math.sin(a)) * R
		table.insert(list, H.bar(prev, q, t, if k % 2 == 0 then color else scaled(color, 1.12)))
		prev = q
	end
end
SM.ring = ring

-- a flat band of 4 iron straps round a box (cf at the band's centre height, size = the box at that height), rivets on
-- the front and the sides
local function boxBand(list: { BasePart }, cf: CFrame, size: Vector3, h: number, t: number)
	for _, e in ipairs({ { 0, -1, size.X }, { 0, 1, size.X }, { -1, 0, size.Z }, { 1, 0, size.Z } }) do
		local off = Vector3.new(e[1] * (size.X / 2 + t / 2), 0, e[2] * (size.Z / 2 + t / 2))
		local s = if e[1] == 0 then Vector3.new(e[3] + 2 * t, h, t) else Vector3.new(t, h, e[3] + 2 * t)
		table.insert(list, piece("Part", s, cf * CFrame.new(off), if e[2] == -1 then IRON_LIGHT else IRON))
	end
	for _, x in ipairs({ -size.X * 0.36, 0, size.X * 0.36 }) do
		rivet(list, (cf * CFrame.new(x, 0, -size.Z / 2 - t)).Position, cf.LookVector, h * 0.22)
	end
end
SM.boxBand = boxBand

---------------------------------------------------------------------
-- 02 FROG TOTEM (kit MapAssets.Swamp.Toad_Totem: a stone base, 3 stacked Toad blocks (#385A2E / #5C823A / #80783E),
-- each with a dark Mouth bar, 2 cream Eye balls, 2 Neon Pupils #8CFF5A and 2 Feet (base, toads and feet collide);
-- 6.8 x 16 x 6.4; 6 copies: test, kit, BossArenas.Swamp x4 at 1 / 0.85)
---------------------------------------------------------------------
-- Round 2 (the owner: "three rounded expressive frogs, each with a different face"): each toad is a faceted rounded
-- frog head (ellipsoidSolid: a flat bottom, a flat face front, a domed top) on a carved stone neck with an iron band
-- (a rope lashing on the top one); today's eyes and glowing pupils kept exactly on bulging lid rings, today's mouth bars
-- kept exactly; 3 faces: the bottom one SLEEPY (heavy half-closed lids, a calm little smile), the middle one GRINNING
-- (an open crescent grin curling up into the cheeks, slanted brows), the top one SURPRISED (a small oval "O" mouth under
-- the bar, high arched brows); warts; the 2 upper frogs hold the frog below with webbed hands (the toes curling over its
-- head), the bottom one sits on webbed feet; carved leaves on the stone base; moss. Colliders: each copy keeps its own
-- (KeptCollision). Parts: Base (PrimaryPart), Toads, ToadDetail, Lips, Feet, Bands, Rope, Moss, Mouth x3, Eye x6,
-- Pupil x6
function SM.swamp_frog_totem(): Model
	local kit = "Toad_Totem"
	local m = Instance.new("Model")
	m.Name = "swamp_frog_totem"
	local rng = Random.new(20261202)
	H.setBevelSelf(true)
	local U: any = { Base = {}, Toads = {}, ToadDetail = {}, Lips = {}, Feet = {}, Bands = {}, Rope = {}, Moss = {} }
	local base = rows(kit, "Part")[1]
	stoneBlocks(U.Base, rng, base.size, base.cf, base.color, 2, 2)
	-- carved leaves on the base front (relief, lighter)
	do
		local fz = base.cf.Z - base.size.Z / 2
		for _, lf in ipairs({ { -2.0, 0.2, 2.3 }, { -0.2, 0.15, 0.6 }, { 1.7, 0.2, -2.0 } }) do
			local at = Vector3.new(base.cf.X + lf[1], base.cf.Y - base.size.Y / 2 + 0.12, fz)
			local dir = Vector3.new(math.sin(lf[3] * 0.25), 1, 0).Unit
			leaf(U.Base, at, dir, base.size.Y * 0.78, 0.42, scaled(base.color, 1.15), Vector3.zAxis)
		end
	end
	local toads = rows(kit, "Toad")
	table.sort(toads, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	local mouths, eyes, feet = rows(kit, "Mouth"), rows(kit, "Eye"), rows(kit, "Foot")
	local FACES = { "sleepy", "grin", "surprised" }
	-- the toad (index) a row belongs to
	local function toadOf(y: number): number
		local best, bi = math.huge, 1
		for i, t in ipairs(toads) do
			local d = math.abs(t.cf.Y - y)
			if d < best then
				best, bi = d, i
			end
		end
		return bi
	end
	local shapes = {}
	for i, t in ipairs(toads) do
		local c = t.color
		local r = Vector3.new(t.size.X / 2 + 0.3, t.size.Y / 2 + 0.1, t.size.Z / 2 + 0.5)
		local front = t.size.Z / 2 - 0.15
		local frame = CFrame.new(t.cf.Position)
		shapes[i] = { c = t.cf.Position, r = r, front = front }
		ellipsoidSolid(U.Toads, frame, r, stoneTone(c), 12, { -0.45, -0.1, 0.25, 0.6, 1.0 }, { bottom = t.size.Y / 2, front = front })
		-- warts on the dome and the cheeks
		for k = 1, 6 do
			local az = rng:NextNumber(0.2, math.pi - 0.2) * (if k % 2 == 0 then 1 else -1) + math.pi / 2
			local el = rng:NextNumber(0.2, 0.9)
			local lp = Vector3.new(r.X * math.cos(el) * math.cos(az), r.Y * math.sin(el), r.Z * math.cos(el) * math.sin(az))
			if lp.Z > -front + 0.5 then
				local s = rng:NextNumber(0.15, 0.24)
				blob(U.ToadDetail, rng, CFrame.new(t.cf.Position + lp), s, s * 0.7, s, stoneTone(scaled(c, rng:NextNumber(0.88, 1.15))))
			end
		end
		-- moss on the back of the dome
		blob(U.Moss, rng, CFrame.new(t.cf.Position + Vector3.new(rng:NextNumber(-0.5, 0.5), r.Y * 0.88, r.Z * 0.35)), r.X * 0.36, 0.2, r.Z * 0.3, leafTone(MOSS), 0.06)
		-- the carved neck up to the next toad, with an iron band (a rope lashing round the top toad)
		local top = t.cf.Y + t.size.Y / 2
		if i < #toads then
			local nb = toads[i + 1].cf.Y - toads[i + 1].size.Y / 2
			local nr = math.min(r.X, r.Z) * 0.62
			table.insert(U.Toads, frustumN(10, nr, nr * 0.92, top - 0.6, nb + 0.15, CFrame.new(t.cf.X, 0, t.cf.Z) * CFrame.Angles(0, rad(i * 11), 0), { scaled(base.color, 0.95), base.color, scaled(base.color, 0.88) }))
			local by = (top + nb) / 2
			table.insert(U.Bands, frustumN(12, nr + 0.06, nr + 0.06, by - 0.16, by + 0.16, CFrame.new(t.cf.X, 0, t.cf.Z), { IRON, IRON_LIGHT }))
			for k = 0, 3 do
				local a = k * math.pi / 2 + rad(45)
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				rivet(U.Bands, Vector3.new(t.cf.X, by, t.cf.Z) + d * (nr + 0.12), d, 0.07)
			end
		else
			for k = 0, 1 do
				local y = t.cf.Y - t.size.Y * 0.1 + k * 0.26
				local f = math.sqrt(math.max(1 - ((y - t.cf.Y) / r.Y) ^ 2, 0))
				local ring = frustumN(12, math.min(r.X, r.Z) * f + 0.05, math.min(r.X, r.Z) * f + 0.05, y - 0.08, y + 0.08, CFrame.new(t.cf.X, 0, t.cf.Z) * CFrame.Angles(0, rad(15 * k), 0), { ROPE, scaled(ROPE, 0.86) })
				table.insert(U.Rope, ring)
			end
		end
	end
	-- the head surface z in front of toad i at (x, y)
	local function faceZ(i: number, x: number, y: number): number
		local s = shapes[i]
		local u = 1 - ((x - s.c.X) / s.r.X) ^ 2 - ((y - s.c.Y) / s.r.Y) ^ 2
		return math.max(s.c.Z - s.r.Z * math.sqrt(math.max(u, 0)), s.c.Z - s.front)
	end
	-- the mouths: today's bars exactly; the face's mouth round each
	for _, r in ipairs(mouths) do
		exactRow(m, r)
		local i = toadOf(r.cf.Y)
		local face = FACES[i] or "grin"
		local tc = toads[i].color
		local LIP = scaled(tc, 1.16)
		local my, hx = r.cf.Y, r.size.X / 2
		-- the upper lip over the whole bar
		table.insert(U.Lips, chamfered(Vector3.new(r.size.X - 0.1, 0.18, 0.24), CFrame.new(r.cf.X, my + r.size.Y / 2 + 0.09, r.cf.Z - 0.04), LIP, { "topFrontBack" }, 0.05))
		if face == "grin" then
			-- an open crescent grin, the corners curling up into the cheeks
			local prev = nil
			for k = -4, 4 do
				local tt = k / 4
				local x = r.cf.X + tt * (hx - 0.25)
				local y = my - 0.02 - 0.42 * (1 - tt * tt)
				local q = Vector3.new(x, y, faceZ(i, x, y) - 0.04)
				if prev then
					table.insert(U.Lips, H.bar(prev, q, 0.28, r.color))
				end
				prev = q
			end
			for _, s in ipairs({ -1, 1 }) do
				local pts = { Vector3.new(r.cf.X + s * (hx - 0.1), my, r.cf.Z) }
				for _, q in ipairs({ { 0.25, 0.2 }, { 0.48, 0.48 } }) do
					local x, y = r.cf.X + s * (hx + q[1]), my + q[2]
					table.insert(pts, Vector3.new(x, y, faceZ(i, x, y) - 0.05))
				end
				for k = 1, #pts - 1 do
					table.insert(U.Lips, H.bar(pts[k], pts[k + 1], 0.24, r.color))
				end
			end
		elseif face == "surprised" then
			-- a small oval "O" hanging from the middle of the bar
			local oc = Vector3.new(r.cf.X, my - 0.38, faceZ(i, r.cf.X, my - 0.38) - 0.02)
			blob(U.Lips, rng, CFrame.new(oc), 0.36, 0.42, 0.1, function(): Color3
				return r.color
			end)
		else
			-- sleepy: a calm, shallow smile
			local prev = nil
			for k = -3, 3 do
				local tt = k / 3
				local x = r.cf.X + tt * (hx - 0.4)
				local y = my - 0.1 - 0.16 * (1 - tt * tt)
				local q = Vector3.new(x, y, faceZ(i, x, y) - 0.04)
				if prev then
					table.insert(U.Lips, H.bar(prev, q, 0.16, r.color))
				end
				prev = q
			end
		end
		-- the pale throat under the chin
		local s = shapes[i]
		blob(U.ToadDetail, rng, CFrame.new(s.c.X, s.c.Y - s.r.Y * 0.62, s.c.Z - s.front + 0.55), s.r.X * 0.5, 0.42, 0.55, function(n: Vector3): Color3
			return scaled(tc, 1.3 + 0.1 * (1 - math.abs(n.Y)))
		end)
	end
	-- the eyes and pupils exactly, on bulging lid rings; the face's lids and brows
	for _, r in ipairs(eyes) do
		exactRow(m, r)
		local ec, er = r.cf.Position, r.size.X / 2
		local i = toadOf(ec.Y - 1.5)
		local face = FACES[i] or "grin"
		local tc = toads[i].color
		table.insert(U.ToadDetail, frustumN(10, er * 1.2, er * 1.02, ec.Y - er - 0.15, ec.Y - er * 0.25, CFrame.new(ec.X, 0, ec.Z), { scaled(tc, 1.1), tc, scaled(tc, 0.92) }))
		local sx = if ec.X < 0 then -1 else 1
		if face == "sleepy" then
			-- a heavy half-closed upper lid (a cap over the eye's top, the pupil's glow below it)
			ellipsoidSolid(U.ToadDetail, CFrame.new(ec), Vector3.new(er * 1.12, er * 1.12, er * 1.12), stoneTone(scaled(tc, 0.95)), 8, { 0.2, 0.7 }, { bottom = -er * 0.08 })
		elseif face == "surprised" then
			-- high arched brows
			local prev = nil
			for k = -2, 2 do
				local a = k * 0.42
				local q = Vector3.new(ec.X + math.sin(a) * er * 1.2, ec.Y + er * 1.25 + math.cos(a) * 0.22, ec.Z - er * 0.35 + math.abs(k) * 0.12)
				if prev then
					table.insert(U.ToadDetail, H.bar(prev, q, 0.16, scaled(tc, 0.72)))
				end
				prev = q
			end
		else
			-- slanted brows (cheeky), the inner ends lower
			local a = Vector3.new(ec.X - sx * er * 0.9, ec.Y + er * 0.95, ec.Z - er * 0.45)
			local b = Vector3.new(ec.X + sx * er * 0.8, ec.Y + er * 1.25, ec.Z - er * 0.25)
			table.insert(U.ToadDetail, H.bar(a, b, 0.2, scaled(tc, 0.75)))
		end
	end
	for _, r in ipairs(rows(kit, "Pupil")) do
		exactRow(m, r)
	end
	-- the hands and feet: webbed, 3 splayed toes with round pads; the upper frogs' hands hold the frog below
	for _, r in ipairs(feet) do
		local i = toadOf(r.cf.Y + 1.5)
		local p = r.cf.Position
		local sx = if p.X < 0 then -1 else 1
		local c = r.color
		local palm, fwd, droop
		if i == 1 then
			palm = Vector3.new(p.X, p.Y - r.size.Y / 2 + 0.12, p.Z - 0.2)
			fwd, droop = Vector3.new(sx * 0.3, 0, -1).Unit, 0
			blob(U.Toads, rng, CFrame.new(p.X - sx * 0.2, p.Y + 0.15, p.Z + 0.4), 0.8, 0.8, 0.9, stoneTone(c))
		else
			-- an arm from the shoulder down onto the head below
			local shoulder = Vector3.new(p.X - sx * 0.1, p.Y + 0.55, p.Z + 0.35)
			palm = Vector3.new(p.X + sx * 0.05, p.Y - r.size.Y / 2 + 0.2, p.Z - 0.35)
			table.insert(U.Toads, frustumN(8, 0.42, 0.36, -0.1, (shoulder - palm).Magnitude, H.frameY(palm, shoulder - palm), { c, scaled(c, 1.08), scaled(c, 0.92) }))
			blob(U.Toads, rng, CFrame.new(shoulder), 0.6, 0.62, 0.62, stoneTone(c))
			fwd, droop = Vector3.new(sx * 0.2, 0, -1).Unit, 0.35
		end
		blob(U.Feet, rng, CFrame.new(palm) * CFrame.Angles(0, math.atan2(-fwd.X, -fwd.Z), 0), 0.42, 0.18, 0.4, stoneTone(c), 0.08)
		local side = fwd:Cross(UP).Unit
		for t = -1, 1 do
			local d = (fwd + side * t * 0.7).Unit
			local knuckle = palm + d * 0.42
			local tip = knuckle + d * 0.14 + Vector3.new(0, -0.05 - droop, 0)
			table.insert(U.Feet, H.bar(palm + d * 0.12, knuckle, 0.16, scaled(c, 1.04)))
			table.insert(U.Feet, H.bar(knuckle, tip, 0.14, scaled(c, 1.04)))
			blob(U.Feet, rng, CFrame.new(tip), 0.13, 0.1, 0.13, stoneTone(scaled(c, 1.1)), 0.05)
		end
		leaf(U.Feet, palm + Vector3.new(0, -0.08, 0) + fwd * 0.08, (fwd - UP * droop * 0.4).Unit, 0.55, 0.95, scaled(c, 0.94), UP)
	end
	-- moss on the base corners
	for _, e in ipairs({ { -1, 1 }, { 1, -1 } }) do
		ST.mossCushion(U.Moss, rng, H.frameY(base.cf.Position + Vector3.new(e[1] * (base.size.X / 2 - 0.6), base.size.Y / 2, e[2] * (base.size.Z / 2 - 0.6)), UP), 1.2)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_frog_totem", U, "Base")
	return m
end

---------------------------------------------------------------------
-- 03 SKULL ON THE FRAME (kit MapAssets.Swamp.Skull_Knocker_Door: Cranium, Jaw, 2 dark Sockets with 2 Neon Eyes #AA50FF,
-- a dark nose and teeth line, a U frame of 3 iron Ring bars; nothing collides; 2.6 x 4.7 x 1.6; 3 copies: test, kit,
-- BossArenas.Swamp.Door (no script or prompt))
---------------------------------------------------------------------
-- From today's parts (round 2: SM.skullBone): today's cranium as a faceted rounded skull with a flat face, the upper
-- jaw with 6 teeth, a rounded lower jaw with 5 teeth, a brow ridge arching over the sockets, cheekbones, a rim round the
-- nose cavity, 2 hairline cracks; today's sockets, glowing eyes, nose and teeth line kept exactly; today's U frame as a
-- dark iron frame (bevelled bars, corner plates, rivets) with a hook over the skull's crown and a round knocker ring
-- hanging from the jaw; 2 small bones and 2 feathers tied to the frame's posts with cord. Nothing collides (as today).
-- Parts: Bone (PrimaryPart), Frame, Charms, Socket x2, Eye x2, Part x2
function SM.swamp_skull_knocker(): Model
	local kit = "Skull_Knocker_Door"
	local m = Instance.new("Model")
	m.Name = "swamp_skull_knocker"
	local rng = Random.new(20261203)
	H.setBevelSelf(true)
	local U: any = { Bone = {}, Frame = {}, Charms = {} }
	local cr = rows(kit, "Cranium")[1]
	local jaw = rows(kit, "Jaw")[1]
	local boneTone = function(c: Color3): (Vector3) -> Color3
		return function(n: Vector3): Color3
			return scaled(c, 0.86 + 0.18 * (n.Y + 1) / 2)
		end
	end
	-- the skull (round 2: SM.skullBone, shared with the skull palisade gate's emblem)
	local nose = nil
	for _, r in ipairs(rows(kit, "Part")) do
		if math.abs(r.size.Y - 0.5) < 0.01 then
			nose = r
		end
	end
	skullBone(U.Bone, rng, cr, jaw, nose)
	-- today's carved details exactly
	for _, nm in ipairs({ "Socket", "Eye", "Part" }) do
		for _, r in ipairs(rows(kit, nm)) do
			exactRow(m, r)
		end
	end
	-- the iron frame: today's 3 ring bars as bevelled iron, corner plates, rivets
	local bars = rows(kit, "Ring")
	for _, r in ipairs(bars) do
		table.insert(U.Frame, chamfered(r.size, r.cf, scaled(r.color, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.06))
		local long = if r.size.X > r.size.Y then Vector3.xAxis else UP
		local L = math.max(r.size.X, r.size.Y)
		for _, s in ipairs({ -0.35, 0.35 }) do
			rivet(U.Frame, r.cf.Position + long * s * L - Vector3.new(0, 0, r.size.Z / 2), -Vector3.zAxis, 0.07)
		end
	end
	local bottom, left, right = bars[1], bars[2], bars[3]
	for _, r in ipairs(bars) do
		if r.size.X > r.size.Y then
			bottom = r
		elseif r.cf.X < 0 then
			left = r
		else
			right = r
		end
	end
	for _, side in ipairs({ left, right }) do
		local corner = Vector3.new(side.cf.X, bottom.cf.Y, side.cf.Z)
		table.insert(U.Frame, chamfered(Vector3.new(0.5, 0.5, 0.12), CFrame.new(corner - Vector3.new(0, 0, 0.2)), IRON_LIGHT, { "frontFace" }, 0.05))
		-- the post's top: a bent finger that holds the skull's side
		local top = side.cf.Position + Vector3.new(0, side.size.Y / 2, 0)
		table.insert(U.Frame, H.bar(top, top + Vector3.new(-math.sign(side.cf.X) * 0.25, 0.22, 0), 0.16, IRON))
	end
	-- a hook over the crown (an iron strap over the top, bent down at the back)
	do
		local topY = cr.cf.Y + cr.size.Y / 2
		table.insert(U.Frame, piece("Part", Vector3.new(0.22, 0.12, cr.size.Z * 0.7), CFrame.new(cr.cf.X, topY + 0.04, cr.cf.Z + 0.05), IRON))
		table.insert(U.Frame, H.bar(Vector3.new(cr.cf.X, topY + 0.04, cr.cf.Z + cr.size.Z * 0.38), Vector3.new(cr.cf.X, topY + 0.16, cr.cf.Z + cr.size.Z * 0.45), 0.12, IRON))
		table.insert(U.Frame, H.bar(Vector3.new(cr.cf.X, topY + 0.16, cr.cf.Z + cr.size.Z * 0.45), Vector3.new(cr.cf.X, topY + 0.18, cr.cf.Z - 0.05), 0.12, IRON_LIGHT))
	end
	-- the round knocker ring hanging from the jaw
	do
		local c = Vector3.new(jaw.cf.X, jaw.cf.Y - jaw.size.Y / 2 - 0.55, jaw.cf.Z - jaw.size.Z / 2 - 0.12)
		ring(U.Frame, c, Vector3.zAxis, 0.5, 0.12, 12, IRON)
		table.insert(U.Frame, chamfered(Vector3.new(0.3, 0.3, 0.12), CFrame.new(c + Vector3.new(0, 0.55, 0.05)), IRON_LIGHT, { "frontFace" }, 0.04))
	end
	-- charms: a small bone on each post, 2 feathers, tied with cord
	for i, side in ipairs({ left, right }) do
		local p = side.cf.Position + Vector3.new(0, side.size.Y * 0.15, -side.size.Z / 2 - 0.1)
		table.insert(U.Charms, H.bar(p + Vector3.new(0, 0.12, 0), p - Vector3.new(0, 0.25, 0), 0.04, ROPE))
		if i == 1 then
			local b0 = p - Vector3.new(0.18, 0.45, 0)
			local b1 = p - Vector3.new(-0.18, 0.62, 0)
			table.insert(U.Charms, H.bar(b0, b1, 0.1, BONE))
			for _, e in ipairs({ b0, b1 }) do
				blob(U.Charms, rng, CFrame.new(e), 0.09, 0.09, 0.07, boneTone(BONE))
			end
		else
			for k = 0, 1 do
				local d = Vector3.new((k - 0.5) * 0.5, -1, 0).Unit
				leaf(U.Charms, p - Vector3.new(0, 0.25, 0), d, 0.75, 0.22, if k == 0 then rgb(40, 38, 48) else rgb(86, 40, 120), Vector3.zAxis)
			end
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_skull_knocker", U, "Bone")
	m.PrimaryPart.CanQuery = false
	return m
end

---------------------------------------------------------------------
-- 04 SPELLBOOK (kit MapAssets.Swamp.Spellbook_Floating: 2 purple Covers and 2 cream Pages open at 18 degrees, the Neon
-- Rune diamond #AA50FF; nothing collides; 5.2 x 1.3 x 3.7 (floating); 26 copies: test, kit, Swamp_3 x6, Swamp_4 x10,
-- BossArenas x8)
---------------------------------------------------------------------
-- From today's parts: today's 2 covers as thick bevelled purple boards with a rounded spine between them and gold corner
-- caps; today's 2 page blocks as page stacks (layer lines on their edges) with a curling top page, text lines and a
-- small drawn glyph on the left page; today's glowing rune kept exactly on the right page; a red ribbon bookmark from the
-- spine over the bottom edge. It floats as today (no stand: the height has no room). Parts: Covers (PrimaryPart), Pages,
-- Ink, Gold, Ribbon, Rune
local COVER = rgb(98, 44, 160) -- #622CA0
local INK = rgb(70, 52, 60)
function SM.swamp_spellbook(): Model
	local kit = "Spellbook_Floating"
	local m = Instance.new("Model")
	m.Name = "swamp_spellbook"
	local rng = Random.new(20261204)
	H.setBevelSelf(true)
	local U: any = { Covers = {}, Pages = {}, Ink = {}, Gold = {}, Ribbon = {} }
	local covers, pages = rows(kit, "Cover"), rows(kit, "Pages")
	-- (the kit stands at Model scale 1.6 and its rows are at scale 1: f scales the detail sizes, drawn at 1.6)
	local f = covers[1].size.Y / 0.24
	for _, r in ipairs(covers) do
		table.insert(U.Covers, chamfered(r.size, r.cf, r.color, { "vertical", "topFrontBack", "topSides" }, 0.06 * f))
		-- gold corner caps on the 2 outer corners
		local sx = if r.cf.X < 0 then -1 else 1
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(0.42 * f, r.size.Y + 0.04 * f, 0.42 * f), r.cf * CFrame.new(sx * (r.size.X / 2 - 0.19 * f), 0, sz * (r.size.Z / 2 - 0.19 * f)), GOLD))
		end
	end
	-- the spine: a rounded roll between the covers
	do
		local a, b = covers[1], covers[2]
		local mid = (a.cf.Position + b.cf.Position) / 2 - Vector3.new(0, 0.12 * f, 0)
		table.insert(U.Covers, frustumN(8, 0.2 * f, 0.2 * f, -a.size.Z / 2, a.size.Z / 2, CFrame.new(mid) * CFrame.Angles(rad(90), 0, 0), { scaled(COVER, 0.9), COVER }))
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Gold, frustumN(8, 0.23 * f, 0.23 * f, sz * a.size.Z / 2 - 0.08 * f, sz * a.size.Z / 2 + 0.02 * f, CFrame.new(mid) * CFrame.Angles(rad(90), 0, 0), { GOLD }))
		end
	end
	for i, r in ipairs(pages) do
		table.insert(U.Pages, chamfered(r.size, r.cf, r.color, { "topSides" }, 0.06 * f))
		-- the page edges: 2 darker layer lines round the outer sides
		local sx = if r.cf.X < 0 then -1 else 1
		for k = 1, 2 do
			local y = -r.size.Y / 2 + k * r.size.Y / 3
			table.insert(U.Ink, piece("Part", Vector3.new(0.02 * f, 0.02 * f, r.size.Z - 0.04 * f), r.cf * CFrame.new(sx * (r.size.X / 2 + 0.005 * f), y, 0), scaled(r.color, 0.8)))
		end
		-- the curling top page at the outer edge
		table.insert(U.Pages, piece("WedgePart", Vector3.new(r.size.Z * 0.96, 0.14 * f, 0.5 * f), r.cf * CFrame.new(sx * (r.size.X / 2 - 0.25 * f), r.size.Y / 2 + 0.07 * f, 0) * CFrame.Angles(0, rad(sx * 90), 0), scaled(r.color, 1.04)))
		-- text lines: the left page full, the right one round the rune
		local top = r.cf * CFrame.new(0, r.size.Y / 2 + 0.006 * f, 0)
		for k = 0, 7 do
			local z = -r.size.Z * 0.38 + k * r.size.Z * 0.105
			local w = r.size.X * (if k % 3 == 2 then 0.5 else 0.72)
			if i == 2 and math.abs(z) < 0.75 * f then
				continue
			end
			table.insert(U.Ink, piece("Part", Vector3.new(w, 0.012 * f, 0.05 * f), top * CFrame.new(-sx * 0.05 * f, 0, z), INK))
		end
		if sx < 0 then
			-- a small drawn frog-eye glyph on the left page
			table.insert(U.Ink, frustumN(8, 0.24 * f, 0.24 * f, 0, 0.012 * f, top * CFrame.new(0.1 * f, 0, 0.2 * f), { scaled(INK, 0.8) }))
		end
	end
	for _, r in ipairs(rows(kit, "Rune")) do
		exactRow(m, r)
	end
	-- the ribbon bookmark: from the spine's top end over the bottom edge, hanging a little
	do
		local a = covers[1]
		local mid = (covers[1].cf.Position + covers[2].cf.Position) / 2
		local p0 = mid + Vector3.new(0.05, 0.42, -a.size.Z * 0.2 / f) * f
		local p1 = mid + Vector3.new(0.12 * f, 0.38 * f, a.size.Z / 2 + 0.05 * f)
		local p2 = p1 + Vector3.new(0.05, -0.55, 0.12) * f
		table.insert(U.Ribbon, H.bar(p0, p1, 0.1 * f, rgb(160, 30, 40)))
		table.insert(U.Ribbon, piece("Part", Vector3.new(0.2 * f, (p2 - p1).Magnitude, 0.03 * f), CFrame.lookAt((p1 + p2) / 2, (p1 + p2) / 2 + Vector3.zAxis) * CFrame.Angles(rad(-12), 0, 0), rgb(140, 24, 34)))
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_spellbook", U, "Covers")
	m.PrimaryPart.CanQuery = false
	return m
end

---------------------------------------------------------------------
-- 05 POTION BOTTLE (kit MapAssets.Swamp.Potion_Bottle_A: the Neon Liquid ball #8CFF5A, a pale neck, a cork; nothing
-- collides; 1.3 x 2 x 1.3; 26 copies: test, kit, Swamp_3 x6, Swamp_4 x10, BossArenas x8; 12 with a purple liquid #AA50FF:
-- Variant Purple)
---------------------------------------------------------------------
-- From today's parts: today's glowing liquid ball kept exactly inside a round-bottom glass flask (a thin translucent
-- glass shell, a glass neck with a lip), today's cork as a tapered cork with a cord wound round the neck and a dangling
-- end, a tiny parchment label with a drawn mark on the flask's front. Variant Purple recolours the liquid as today.
-- Parts: Glass (PrimaryPart), Cork, Label, Liquid
function SM.swamp_potion_bottle(): Model
	local kit = "Potion_Bottle_A"
	local m = Instance.new("Model")
	m.Name = "swamp_potion_bottle"
	local rng = Random.new(20261205)
	H.setBevelSelf(true)
	local U: any = { Glass = {}, Cork = {}, Label = {} }
	local liquid = rows(kit, "Liquid")[1]
	local parts = rows(kit, "Part")
	local neck, cork = parts[1], parts[2]
	if neck.cf.Y > cork.cf.Y then
		neck, cork = cork, neck
	end
	local GLASS = rgb(199, 211, 192) -- #C7D3C0 today's pale neck
	local lc = liquid.cf.Position
	local R = liquid.size.X / 2
	-- the flask: a 12-sided glass bulb round the liquid ball (2 frustums), a glass neck, a lip
	table.insert(U.Glass, frustumN(12, R * 0.62, R * 1.02, lc.Y - R + 0.0, lc.Y, CFrame.new(lc.X, 0, lc.Z), { GLASS }))
	table.insert(U.Glass, frustumN(12, R * 1.02, neck.size.X * 0.5, lc.Y, lc.Y + R * 0.9, CFrame.new(lc.X, 0, lc.Z), { GLASS }))
	table.insert(U.Glass, frustumN(10, neck.size.X * 0.5, neck.size.X * 0.42, neck.cf.Y - neck.size.Y / 2 - 0.05, neck.cf.Y + neck.size.Y / 2 - 0.05, CFrame.new(neck.cf.X, 0, neck.cf.Z), { GLASS }))
	table.insert(U.Glass, frustumN(10, neck.size.X * 0.56, neck.size.X * 0.56, neck.cf.Y + neck.size.Y / 2 - 0.12, neck.cf.Y + neck.size.Y / 2 - 0.02, CFrame.new(neck.cf.X, 0, neck.cf.Z), { GLASS }))
	-- the cork: tapered, a cord round the neck with a dangling end
	local cc = cork.color
	table.insert(U.Cork, frustumN(8, cork.size.X * 0.44, cork.size.X * 0.5, cork.cf.Y - cork.size.Y / 2 - 0.08, cork.cf.Y + cork.size.Y / 2, CFrame.new(cork.cf.X, 0, cork.cf.Z), { cc, scaled(cc, 1.1), scaled(cc, 0.9) }))
	local cy = neck.cf.Y + 0.05
	ring(U.Cork, Vector3.new(neck.cf.X, cy, neck.cf.Z), UP, neck.size.X * 0.47, 0.05, 8, ROPE)
	table.insert(U.Cork, H.bar(Vector3.new(neck.cf.X + neck.size.X * 0.47, cy, neck.cf.Z), Vector3.new(neck.cf.X + neck.size.X * 0.62, cy - 0.32, neck.cf.Z - 0.08), 0.045, ROPE))
	-- the label: a small parchment tag on the flask's front with a drawn mark
	local front = Vector3.new(lc.X, lc.Y - R * 0.1, lc.Z - R * 1.0)
	table.insert(U.Label, piece("Part", Vector3.new(R * 0.85, R * 0.55, 0.03), CFrame.lookAt(front, front - Vector3.zAxis) * CFrame.Angles(rad(-6), 0, 0), rgb(222, 206, 160)))
	table.insert(U.Label, piece("Part", Vector3.new(R * 0.3, R * 0.3, 0.032), CFrame.lookAt(front, front - Vector3.zAxis) * CFrame.Angles(rad(-6), 0, rad(45)) * CFrame.new(0, 0, -0.005), rgb(90, 60, 50)))
	exactRow(m, liquid)
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_potion_bottle", U, "Glass", { Glass = { material = Enum.Material.Glass, transparency = 0.55 } })
	m.PrimaryPart.CanQuery = false
	-- Variant Purple: today's purple liquid
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	local cfg = Instance.new("Configuration")
	cfg.Name = "Purple"
	cfg:SetAttribute("Color_Liquid", Color3.fromHex("aa50ff"))
	cfg.Parent = folder
	folder.Parent = m
	return m
end

---------------------------------------------------------------------
-- 06 HANGING LANTERN (kit MapAssets.Swamp.Hanging_Lantern: a Chain, a top and a bottom cap, the Neon Lantern core
-- #FFC460; nothing collides; 1.5 x 5 x 1.5, hanging from its chain top at 5; attribute Height = 5; 46 copies: test, kit,
-- Swamp_1-4 x36, BossArenas x8; 36 carry a PointLight under the Lantern, 10 none: each keeps its own on KeptLight_Lantern)
---------------------------------------------------------------------
-- From today's parts: today's glowing core kept exactly in a dark iron frame (4 corner posts, glass panes on
-- the 4 sides); today's top cap as a bevelled plate under a 4-sided roof with a finial and a hanging ring; today's
-- bottom cap as a bevelled plate with a small drop finial; today's chain as 5 open links from the ring up to a ceiling
-- plate at the chain's top. Parts: Frame (PrimaryPart), Glass, Chain, Lantern
function SM.swamp_hanging_lantern(): Model
	local kit = "Hanging_Lantern"
	local m = Instance.new("Model")
	m.Name = "swamp_hanging_lantern"
	local rng = Random.new(20261206)
	H.setBevelSelf(true)
	local U: any = { Frame = {}, Glass = {}, Chain = {} }
	local core = rows(kit, "Lantern")[1]
	local chain = rows(kit, "Chain")[1]
	local caps = rows(kit, "Part")
	table.sort(caps, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	local bottom, top = caps[1], caps[2]
	exactRow(m, core)
	local c = core.cf.Position
	local hx, hz = core.size.X / 2, core.size.Z / 2
	local y0, y1 = bottom.cf.Y + bottom.size.Y / 2, top.cf.Y - top.size.Y / 2
	-- the frame: 4 corner posts, glass panes
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local p = Vector3.new(c.X + sx * (hx + 0.02), (y0 + y1) / 2, c.Z + sz * (hz + 0.02))
			table.insert(U.Frame, piece("Part", Vector3.new(0.16, y1 - y0 + 0.02, 0.16), CFrame.new(p), if sx * sz > 0 then IRON else IRON_LIGHT))
		end
	end
	for _, e in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local p = Vector3.new(c.X + e[1] * (hx + 0.04), (y0 + y1) / 2, c.Z + e[2] * (hz + 0.04))
		local s = if e[1] == 0 then Vector3.new(core.size.X - 0.1, y1 - y0, 0.04) else Vector3.new(0.04, y1 - y0, core.size.Z - 0.1)
		table.insert(U.Glass, piece("Part", s, CFrame.new(p), rgb(255, 226, 160)))
		-- a thin horizontal bar across each pane
		local bs = if e[1] == 0 then Vector3.new(core.size.X, 0.08, 0.08) else Vector3.new(0.08, 0.08, core.size.Z)
		table.insert(U.Frame, piece("Part", bs, CFrame.new(p + Vector3.new(e[1] * 0.03, 0, e[2] * 0.03)), IRON))
	end
	-- the caps: bevelled plates; a 4-sided roof with a finial and a ring; a drop finial under
	table.insert(U.Frame, chamfered(top.size, top.cf, top.color, { "vertical", "topFrontBack", "topSides" }, 0.06))
	table.insert(U.Frame, chamfered(bottom.size, bottom.cf, bottom.color, { "vertical", "bottomFrontBack", "bottomSides" }, 0.06))
	local ry = top.cf.Y + top.size.Y / 2
	table.insert(U.Frame, frustumN(4, top.size.X / 2 * 0.86, 0.12, ry - 0.02, ry + 0.45, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, rad(45), 0), { IRON, IRON_LIGHT, scaled(IRON, 0.9), IRON_LIGHT }))
	table.insert(U.Frame, frustumN(6, 0.1, 0.06, ry + 0.43, ry + 0.58, CFrame.new(c.X, 0, c.Z), { IRON_LIGHT }))
	local ringC = Vector3.new(c.X, ry + 0.75, c.Z)
	ring(U.Chain, ringC, Vector3.zAxis, 0.16, 0.06, 6, IRON)
	local by = bottom.cf.Y - bottom.size.Y / 2
	table.insert(U.Frame, frustumN(6, 0.18, 0.04, by - 0.18, by + 0.01, CFrame.new(c.X, 0, c.Z), { IRON, IRON_LIGHT }))
	-- the chain: open links from the ring up to the chain's top, a ceiling plate there
	local yTop = chain.cf.Y + chain.size.Y / 2
	local yStart = ringC.Y + 0.16
	local n = 5
	local L = (yTop - 0.06 - yStart) / n
	for k = 0, n - 1 do
		local ya, yb = yStart + k * L, yStart + (k + 1) * L
		local ax = if k % 2 == 0 then Vector3.xAxis else Vector3.zAxis
		local w = 0.09
		for _, s in ipairs({ -1, 1 }) do
			local off = ax * s * w
			table.insert(U.Chain, piece("Part", Vector3.new(0.035, L * 0.9, 0.035), CFrame.new(c.X, (ya + yb) / 2, c.Z) + off, if k % 2 == 0 then IRON else IRON_LIGHT))
		end
		table.insert(U.Chain, piece("Part", (ax * w * 2) + Vector3.new(0.035, 0.035, 0.035) - ax * 0.035, CFrame.new(c.X, yb - 0.03, c.Z), IRON))
	end
	table.insert(U.Chain, chamfered(Vector3.new(0.5, 0.06, 0.5), CFrame.new(c.X, yTop - 0.03, c.Z), IRON_LIGHT, { "vertical" }, 0.04))
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_hanging_lantern", U, "Frame", { Glass = { material = Enum.Material.Glass, transparency = 0.6, shadow = false } })
	m.PrimaryPart.CanQuery = false
	return m
end

---------------------------------------------------------------------
-- 07 CAULDRON (kit MapAssets.Swamp.Cauldron_Small: the Pot ball, the Rim, the Neon Liquid #8CFF5A with the SteamPoint
-- Attachment, 3 legs and 2 crossed logs (all but the liquid collide); 5.16 x 5.32 x 5.16; 8 copies: test, kit, Swamp_3
-- x4, Swamp_4 x2; 3 carry a PointLight under the Liquid (kept per copy on KeptLight_Liquid); no script or prompt)
---------------------------------------------------------------------
-- From today's parts: today's pot as a rounded cast iron belly (5 stacked 12-sided bands narrowing to a neck)
-- with a riveted band round the middle; today's rim as a thick lip ring of 12 segments round today's glowing liquid
-- (kept exactly, its SteamPoint Attachment kept) with 5 bubbles of the same glow on it; 2 ring handles on lugs; today's 3
-- legs as tapered iron legs with claw pads; today's 2 crossed logs as bark logs (8-sided, grooves, pale cut ends) with
-- emissive embers and dark coals under the pot (Neon only: no light, no script). Colliders: each copy keeps its own
-- (KeptCollision). Parts: Pot (PrimaryPart), Iron, Bubbles, Logs, Embers, Liquid
function SM.swamp_cauldron(): Model
	local kit = "Cauldron_Small"
	local m = Instance.new("Model")
	m.Name = "swamp_cauldron"
	local rng = Random.new(20261207)
	H.setBevelSelf(true)
	local U: any = { Pot = {}, Iron = {}, Bubbles = {}, Logs = {}, Embers = {} }
	local pot = rows(kit, "Pot")[1]
	local rim = rows(kit, "Rim")[1]
	local liquid = rows(kit, "Liquid")[1]
	local legs, logs = {}, {}
	for _, r in ipairs(rows(kit, "Part")) do
		table.insert(if r.size.Z > 3 then logs else legs, r)
	end
	local pc = pot.cf.Position
	local R = pot.size.X / 2
	local frame = CFrame.new(pc.X, 0, pc.Z)
	local iron = pot.color
	-- the belly: 5 bands, round at the bottom, narrowing to a neck under the rim
	local bands = { { pc.Y - R * 0.95, pc.Y - R * 0.7, R * 0.42, R * 0.74 }, { pc.Y - R * 0.7, pc.Y - R * 0.3, R * 0.74, R * 0.97 }, { pc.Y - R * 0.3, pc.Y + R * 0.25, R * 0.97, R * 0.97 }, { pc.Y + R * 0.25, pc.Y + R * 0.6, R * 0.97, R * 0.84 }, { pc.Y + R * 0.6, rim.cf.Y - rim.size.X / 2 + 0.05, R * 0.84, R * 0.78 } }
	for i, b in ipairs(bands) do
		local c = scaled(iron, 0.9 + 0.06 * i)
		table.insert(U.Pot, frustumN(12, b[3], b[4], b[1] - (if i > 1 then 0.02 else 0), b[2], frame * CFrame.Angles(0, rad(i * 7), 0), { c, scaled(c, 1.12), scaled(c, 0.9) }))
	end
	-- the band with rivets round the middle
	table.insert(U.Iron, frustumN(12, R * 0.99, R * 0.99, pc.Y - 0.14, pc.Y + 0.14, frame, { scaled(iron, 0.8) }))
	for k = 0, 11 do
		local a = k * math.pi / 6 + rad(15)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		rivet(U.Iron, Vector3.new(pc.X, pc.Y, pc.Z) + d * R * 1.0, d, 0.08)
	end
	-- the rim: a thick lip ring of 12 segments round the liquid
	local ry0, ry1 = rim.cf.Y - rim.size.X / 2, rim.cf.Y + rim.size.X / 2
	local Rr = rim.size.Y / 2
	local Rl = liquid.size.Y / 2
	table.insert(U.Pot, frustumN(12, Rr * 0.98, Rr, ry0, ry1 - 0.12, frame, { iron, scaled(iron, 1.1) }))
	for k = 0, 11 do
		local a = k * math.pi / 6
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Vector3.new(pc.X, ry1 - 0.02, pc.Z) + d * (Rl + (Rr - Rl) / 2 + 0.05)
		table.insert(U.Pot, chamfered(Vector3.new(Rr - Rl + 0.12, 0.3, 2 * (Rr + 0.1) * math.tan(math.pi / 12)), CFrame.lookAt(p, p + d) * CFrame.Angles(0, rad(90), 0), scaled(iron, if k % 2 == 0 then 1.15 else 1.05), { "topFrontBack" }, 0.07))
	end
	-- the liquid exactly (its SteamPoint too) and 5 bubbles of the same glow
	local lq = exactRow(m, liquid)
	local sp = Instance.new("Attachment")
	sp.Name = "SteamPoint"
	sp.Position = Vector3.new(GD.SteamPoint.x, GD.SteamPoint.y, GD.SteamPoint.z)
	sp.Parent = lq
	local ly = liquid.cf.Y + liquid.size.X / 2
	for k = 1, 5 do
		local a = k * 2.3
		local rr = Rl * (0.2 + 0.12 * k)
		local s = rng:NextNumber(0.16, 0.3)
		table.insert(U.Bubbles, frustumN(8, s, s * 0.3, ly - 0.05, ly + s * 0.7, CFrame.new(pc.X + math.cos(a) * rr, 0, pc.Z + math.sin(a) * rr), { liquid.color }))
	end
	-- 2 ring handles on lugs
	for _, sx in ipairs({ -1, 1 }) do
		local lug = Vector3.new(pc.X + sx * R * 0.86, pc.Y + R * 0.62, pc.Z)
		table.insert(U.Iron, chamfered(Vector3.new(0.3, 0.4, 0.5), CFrame.new(lug), scaled(iron, 1.1), { "vertical" }, 0.06))
		ring(U.Iron, lug + Vector3.new(sx * 0.2, -0.3, 0), Vector3.xAxis, 0.32, 0.09, 10, IRON_LIGHT)
	end
	-- the legs: tapered iron legs with claw pads
	for _, r in ipairs(legs) do
		local p = r.cf.Position
		local yb, yt = p.Y - r.size.Y / 2, p.Y + r.size.Y / 2
		table.insert(U.Iron, frustumN(6, r.size.X * 0.42, r.size.X * 0.56, yb + 0.12, yt + 0.2, CFrame.new(p.X, 0, p.Z), { iron, scaled(iron, 1.12) }))
		local out = Vector3.new(p.X - pc.X, 0, p.Z - pc.Z).Unit
		for t = -1, 1 do
			local d = (out + Vector3.new(-out.Z, 0, out.X) * t * 0.6).Unit
			table.insert(U.Iron, frustumN(4, 0.1, 0.03, 0, 0.36, H.frameY(Vector3.new(p.X, yb + 0.1, p.Z), (d - UP * 0.25).Unit), { IRON_LIGHT, IRON }))
		end
	end
	-- the logs: 8-sided bark logs with grooves and pale cut ends
	local LOG_END = rgb(170, 132, 92)
	for _, r in ipairs(logs) do
		local axis = r.cf.LookVector
		local a, b = r.cf.Position - axis * r.size.Z / 2, r.cf.Position + axis * r.size.Z / 2
		local lr = r.size.X / 2
		local cf = H.frameY(a, b - a) * CFrame.Angles(0, rng:NextNumber(0, 1), 0)
		table.insert(U.Logs, frustumN(8, lr, lr * 0.94, 0, r.size.Z, cf, { r.color, scaled(r.color, 1.1), scaled(r.color, 0.88) }))
		for _, e in ipairs({ 0, 1 }) do
			local p = a:Lerp(b, e)
			table.insert(U.Logs, frustumN(8, lr * 0.8, lr * 0.8, -0.02, 0.02, H.frameY(p, b - a), { LOG_END }))
		end
		for k = 0, 2 do
			local th = k * 2.1 + 0.4
			local off = (cf * CFrame.Angles(0, th, 0)).XVector * lr
			table.insert(U.Logs, H.bar(a + off + axis * 0.4, b + off - axis * 0.5 + axis * rng:NextNumber(-0.3, 0), 0.07, scaled(r.color, 0.6)))
		end
	end
	-- embers and coals under the pot (emissive only)
	for k = 1, 7 do
		local a = k * 0.9
		local rr = rng:NextNumber(0.3, 1.0)
		local p = Vector3.new(pc.X + math.cos(a) * rr, logs[1].cf.Y + logs[1].size.X / 2 - 0.02, pc.Z + math.sin(a) * rr)
		if k % 3 == 0 then
			blob(U.Logs, rng, CFrame.new(p), 0.22, 0.12, 0.2, function(): Color3
				return rgb(34, 30, 30)
			end, 0.1)
		else
			table.insert(U.Embers, frustumN(5, rng:NextNumber(0.1, 0.18), 0.04, 0, rng:NextNumber(0.12, 0.25), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), { if k % 2 == 0 then rgb(255, 122, 46) else rgb(255, 170, 60) }))
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_cauldron", U, "Pot", { Bubbles = { material = Enum.Material.Neon }, Embers = { material = Enum.Material.Neon } })
	return m
end

---------------------------------------------------------------------
-- 08 POTION BOOKSHELF (kit MapAssets.Swamp.Potion_Shelf: 2 side posts, a back panel, 3 shelves (all collide), 6 Bottle
-- blocks (3 Neon: #8CFF5A, #78FFD2, #622CA0; 3 plain); 6 x 7.25 x 1.6; 8 copies: test, kit, Swamp_3 x4, Swamp_4 x2)
---------------------------------------------------------------------
-- From today's parts: today's side posts as bevelled timbers with caps and feet; today's back panel as 6 vertical
-- planks with joints over a dark core; today's 3 shelves as 2 bevelled boards each with a front lip, held by bracket
-- wedges at both ends; today's 6 bottles kept exactly (the glow and colours) with glass necks, corks and tiny labels;
-- 5 books with spine bands and labels in the free places; thin cobweb strands in the 2 top corners. Colliders: each copy
-- keeps its own (KeptCollision). Parts: Posts (PrimaryPart), Panel, Shelves, Books, Glass, Corks, Web, Bottle x6
function SM.swamp_potion_shelf(): Model
	local kit = "Potion_Shelf"
	local m = Instance.new("Model")
	m.Name = "swamp_potion_shelf"
	local rng = Random.new(20261208)
	H.setBevelSelf(true)
	local U: any = { Posts = {}, Panel = {}, Shelves = {}, Books = {}, Glass = {}, Corks = {}, Web = {} }
	local posts, panel, shelves = {}, nil, {}
	for _, r in ipairs(rows(kit, "Part")) do
		if r.size.Y > 5 and r.size.X < 1 then
			table.insert(posts, r)
		elseif r.size.Y > 5 then
			panel = r
		else
			table.insert(shelves, r)
		end
	end
	table.sort(shelves, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	for _, r in ipairs(posts) do
		table.insert(U.Posts, chamfered(r.size, r.cf, r.color, { "vertical", "topFrontBack", "topSides" }, 0.08))
		local top = r.cf.Position + Vector3.new(0, r.size.Y / 2, 0)
		table.insert(U.Posts, chamfered(Vector3.new(r.size.X + 0.12, 0.16, r.size.Z + 0.1), CFrame.new(top + Vector3.new(0, 0.08, 0)), scaled(r.color, 1.1), { "vertical", "topFrontBack", "topSides" }, 0.05))
		table.insert(U.Posts, chamfered(Vector3.new(r.size.X + 0.1, 0.14, r.size.Z + 0.08), CFrame.new(r.cf.Position - Vector3.new(0, r.size.Y / 2 - 0.07, 0)), scaled(r.color, 0.9), { "vertical" }, 0.04))
	end
	-- the back panel: 6 vertical planks over a dark core
	if panel then
		table.insert(U.Panel, piece("Part", panel.size - Vector3.new(0.04, 0.04, 0.06), panel.cf * CFrame.new(0, 0, 0.02), rgb(40, 30, 24)))
		local n = 6
		local pw = panel.size.X / n
		for k = 0, n - 1 do
			local x = -panel.size.X / 2 + pw * (k + 0.5)
			table.insert(U.Panel, chamfered(Vector3.new(pw - 0.06, panel.size.Y - 0.02, panel.size.Z * 0.6), panel.cf * CFrame.new(x, 0, -panel.size.Z * 0.2), tone(rng, panel.color), { "vertical" }, 0.03))
		end
	end
	-- the shelves: 2 boards each with a front lip; bracket wedges at both ends
	for _, r in ipairs(shelves) do
		local hw = r.size.X / 2
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Shelves, chamfered(Vector3.new(hw - 0.04, r.size.Y, r.size.Z), r.cf * CFrame.new(sx * hw / 2, 0, 0), tone(rng, r.color), { "topFrontBack", "topSides" }, 0.04))
		end
		table.insert(U.Shelves, chamfered(Vector3.new(r.size.X, 0.12, 0.08), r.cf * CFrame.new(0, r.size.Y / 2 + 0.04, -r.size.Z / 2 + 0.04), scaled(r.color, 0.86), { "topFrontBack" }, 0.03))
		if r.cf.Y > 1 then
			for _, sx in ipairs({ -1, 1 }) do
				local p = r.cf * CFrame.new(sx * (hw - 0.22), -r.size.Y / 2 - 0.28, 0.1)
				table.insert(U.Shelves, piece("WedgePart", Vector3.new(0.16, 0.55, r.size.Z * 0.8), p * CFrame.Angles(0, 0, rad(180)), scaled(r.color, 0.85)))
			end
		end
	end
	-- the bottles exactly, with glass necks, corks and labels
	for _, r in ipairs(rows(kit, "Bottle")) do
		exactRow(m, r)
		local top = r.cf.Position + Vector3.new(0, r.size.Y / 2, 0)
		table.insert(U.Glass, frustumN(6, r.size.X * 0.28, r.size.X * 0.22, -0.02, 0.32, CFrame.new(top), { rgb(199, 211, 192) }))
		table.insert(U.Corks, frustumN(6, r.size.X * 0.2, r.size.X * 0.24, 0.3, 0.46, CFrame.new(top), { rgb(104, 76, 52), rgb(120, 90, 62) }))
		table.insert(U.Corks, piece("Part", Vector3.new(r.size.X * 0.7, r.size.Y * 0.35, 0.03), r.cf * CFrame.new(0, -r.size.Y * 0.08, -r.size.Z / 2 - 0.016), rgb(222, 206, 160)))
	end
	-- books in the free places: { shelf, x, width, height, depth, colour, tilt }
	local BOOKS = {
		{ 1, 1.55, 0.32, 1.05, 0.95, rgb(120, 44, 40), 0 }, { 1, 1.95, 0.28, 0.95, 0.9, rgb(46, 70, 110), 0 },
		{ 2, -2.05, 0.34, 1.1, 0.95, rgb(70, 90, 48), 0 }, { 2, -1.62, 0.26, 0.9, 0.85, rgb(110, 80, 40), rad(-12) },
		{ 3, -1.9, 0.36, 1.0, 0.9, rgb(84, 44, 110), 0 },
	}
	for _, b in ipairs(BOOKS) do
		local s = shelves[b[1]]
		local y = s.cf.Y + s.size.Y / 2 + b[4] / 2
		local cf = CFrame.new(s.cf.X + b[2], y, s.cf.Z + 0.1) * CFrame.Angles(0, 0, b[7])
		table.insert(U.Books, chamfered(Vector3.new(b[3], b[4], b[5]), cf, b[6], { "vertical" }, 0.03))
		for _, dy in ipairs({ -0.3, 0.3 }) do
			table.insert(U.Books, piece("Part", Vector3.new(b[3] + 0.02, 0.06, 0.03), cf * CFrame.new(0, dy * b[4], -b[5] / 2 - 0.01), GOLD))
		end
		table.insert(U.Books, piece("Part", Vector3.new(b[3] * 0.7, b[4] * 0.2, 0.03), cf * CFrame.new(0, 0.05, -b[5] / 2 - 0.012), rgb(222, 206, 160)))
	end
	-- cobwebs: thin strands in the 2 top corners (a fan of 4 and 2 cross threads)
	local topY = posts[1].cf.Y + posts[1].size.Y / 2 - 0.05
	local inner = math.abs(posts[1].cf.X) - posts[1].size.X / 2
	local webZ = if panel then panel.cf.Z - panel.size.Z / 2 - 0.04 else shelves[1].cf.Z
	for _, sx in ipairs({ -1, 1 }) do
		local corner = Vector3.new(sx * inner, topY, webZ)
		local ends = {}
		for k = 0, 3 do
			local a = rad(k * 30)
			local e = corner + Vector3.new(-sx * math.cos(a) * 0.9, -math.sin(a) * 0.9, 0)
			table.insert(U.Web, H.bar(corner, e, 0.02, rgb(220, 228, 224)))
			table.insert(ends, e)
		end
		for _, f in ipairs({ 0.45, 0.8 }) do
			for k = 1, 3 do
				table.insert(U.Web, H.bar(corner:Lerp(ends[k], f), corner:Lerp(ends[k + 1], f), 0.015, rgb(220, 228, 224)))
			end
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_potion_shelf", U, "Posts", { Glass = { material = Enum.Material.Glass, transparency = 0.4 }, Web = { transparency = 0.35, shadow = false } })
	return m
end

---------------------------------------------------------------------
-- 09 RAVEN (kit MapAssets.Swamp.Crow_A: body, head, beak, tail, 2 wings, 2 legs; nothing collides; 1.4 x 2.55 x 4.09,
-- perched on its feet at the pivot; 17 swamp copies (test, kit, Swamp_1 x4, Swamp_2 x10, Swamp_3 x1) and the 6 gate ravens
-- (nested in swamp_vine_arch / swamp_tree_gate at their old pose, scale 1.3); the Realm of the Dead crows stay as they are)
---------------------------------------------------------------------
-- From today's parts (same pose and size): a faceted blue-black body with a sheen on its top facets and a fuller chest;
-- a rounded head with a small crest, 2 black eyes with a white glint; a pointed 4-sided beak with a ridge; each wing as
-- 3 layered feathers (long to short, folded along the body); a tail fan of 4 feathers; 2 legs gripping with 3 toes
-- forward and 1 back. Parts: Body (PrimaryPart), Feathers, Beak, Eyes, Legs
local RAVEN = rgb(27, 29, 38) -- #1B1D26 blue-black
local SHEEN = rgb(52, 62, 84) -- #343E54
function SM.swamp_raven(): Model
	local kit = "Crow_A"
	local m = Instance.new("Model")
	m.Name = "swamp_raven"
	local rng = Random.new(20261209)
	H.setBevelSelf(true)
	local U: any = { Body = {}, Feathers = {}, Beak = {}, Eyes = {}, Legs = {} }
	local body, head, beak, tail, wings, legs = nil, nil, nil, nil, {}, {}
	for _, r in ipairs(rows(kit, "Part")) do
		local s = r.size
		if math.abs(s.Z - 2.2) < 0.01 then
			body = r
		elseif math.abs(s.X - 0.8) < 0.01 then
			head = r
		elseif math.abs(s.Z - 0.7) < 0.01 then
			beak = r
		elseif math.abs(s.Z - 1.3) < 0.01 then
			tail = r
		elseif math.abs(s.Z - 1.8) < 0.01 then
			table.insert(wings, r)
		else
			table.insert(legs, r)
		end
	end
	local sheen = function(n: Vector3): Color3
		local t = math.max(n.Y, 0)
		return RAVEN:Lerp(SHEEN, t * 0.85)
	end
	blob(U.Body, rng, body.cf, body.size.X * 0.5, body.size.Y * 0.5, body.size.Z * 0.5, sheen)
	blob(U.Body, rng, body.cf * CFrame.new(0, -0.08, -body.size.Z * 0.3), body.size.X * 0.46, body.size.Y * 0.44, body.size.Z * 0.24, sheen)
	blob(U.Body, rng, head.cf, head.size.X * 0.52, head.size.Y * 0.5, head.size.Z * 0.55, sheen)
	leaf(U.Feathers, head.cf.Position + Vector3.new(0, head.size.Y * 0.42, 0.1), Vector3.new(0, 0.5, 1).Unit, 0.4, 0.25, SHEEN, UP)
	-- the beak: a pointed 4-sided cone from the head's front, a ridge
	local bp = beak.cf.Position + Vector3.new(0, 0, beak.size.Z / 2)
	table.insert(U.Beak, frustumN(4, beak.size.X * 0.55, 0.015, 0, beak.size.Z + 0.08, H.frameY(bp, (-Vector3.zAxis - UP * 0.12).Unit) * CFrame.Angles(0, rad(45), 0), { rgb(58, 56, 52), rgb(78, 76, 70) }))
	-- the eyes: black, a white glint
	for _, sx in ipairs({ -1, 1 }) do
		local e = head.cf.Position + Vector3.new(sx * head.size.X * 0.47, head.size.Y * 0.12, -head.size.Z * 0.2)
		table.insert(U.Eyes, frustumN(6, 0.09, 0.07, -0.02, 0.05, H.frameY(e, Vector3.new(sx, 0, -0.3).Unit), { rgb(12, 12, 14) }))
		table.insert(U.Eyes, piece("Part", Vector3.new(0.035, 0.035, 0.035), CFrame.new(e + Vector3.new(sx * 0.055, 0.03, -0.03)), rgb(245, 245, 240)))
	end
	-- the wings: 3 layered feathers each, folded along the body
	for _, w in ipairs(wings) do
		local sx = if w.cf.X < 0 then -1 else 1
		local front = w.cf * CFrame.new(0, 0.15, -w.size.Z / 2 + 0.1)
		for k = 0, 2 do
			local len = w.size.Z * (1.05 - 0.18 * k)
			local at = (front * CFrame.new(sx * 0.02 * k, -0.12 * k, 0.05 * k)).Position
			local dir = (front.LookVector * -1 + front.UpVector * (-0.18 - 0.05 * k)).Unit
			leaf(U.Feathers, at, dir, len, w.size.Y * (0.95 - 0.12 * k), if k == 1 then SHEEN else scaled(RAVEN, 1 + 0.08 * k), Vector3.new(sx, 0, 0))
		end
	end
	-- the tail: a fan of 4 feathers
	do
		local base = tail.cf * CFrame.new(0, 0, -tail.size.Z / 2 + 0.05)
		for k = -1.5, 1.5 do
			local dir = (base.LookVector * -1 + base.RightVector * k * 0.16).Unit
			leaf(U.Feathers, base.Position + base.RightVector * k * 0.06, dir, tail.size.Z * (0.95 + 0.05 * (1.5 - math.abs(k))), tail.size.X * 0.42, if math.abs(k) < 1 then SHEEN else RAVEN, base.UpVector)
		end
	end
	-- the legs: thin, 3 toes forward and 1 back gripping the perch
	for _, r in ipairs(legs) do
		local p = r.cf.Position
		local yb, yt = p.Y - r.size.Y / 2, p.Y + r.size.Y / 2
		local LEG = rgb(58, 58, 54)
		table.insert(U.Legs, H.bar(Vector3.new(p.X, yb + 0.04, p.Z), Vector3.new(p.X, yt, p.Z + 0.05), r.size.X * 0.8, LEG))
		for t = -1, 1 do
			table.insert(U.Legs, H.bar(Vector3.new(p.X, yb + 0.04, p.Z), Vector3.new(p.X + t * 0.1, yb + 0.02, p.Z - 0.26), 0.06, LEG))
		end
		table.insert(U.Legs, H.bar(Vector3.new(p.X, yb + 0.04, p.Z), Vector3.new(p.X, yb + 0.02, p.Z + 0.2), 0.06, LEG))
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_raven", U, "Body")
	m.PrimaryPart.CanQuery = false
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
SM.BUILDERS = { swamp_frog_altar = true, swamp_frog_totem = true, swamp_skull_knocker = true, swamp_spellbook = true, swamp_potion_bottle = true, swamp_hanging_lantern = true, swamp_cauldron = true, swamp_potion_shelf = true, swamp_raven = true }
for id in pairs(SM.BUILDERS) do
	B2[id] = (SM :: any)[id]
	B2.BUILDERS[id] = true
end
SM.install = B2.install
SM.stats = B2.stats

return SM
