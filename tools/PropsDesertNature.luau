--[[
	PropsDesertNature (dev tool, Edit mode only) - the owner's "DESERT ZONE PROP IMPROVEMENT - Rocks, ruins and nature"
	(2026-10-20): the desert rocks, ruins, bones and cacti of docs/Desert_Images/03_Rocks_Ruins_Nature rebuilt in the
	desert recipe (docs/prop_texture_guide.md section B), keeping each object's colours, place and footprint. Source of
	truth: tools/PropsDesertNature.luau. Inventory: docs/prop_inventory.md "Desert nature".

	Collision: the visible unions never collide; invisible "Collision" parts (or one "Collision" union where its hull
	matches) rebuild the kit's colliding parts, so no copy is more (or less) solid than today.

	It uses DevTools.PropsDesert (its fresh PropsBatch2 table and helpers) and registers its builders there:
		local N = require(game.ServerStorage.DevTools.PropsDesertNature:Clone())
		print(N.install("cactus_tall"))   -- (re)builds ServerStorage.MapProps.cactus_tall
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "cactus_tall" } }), Sync.run({ only = { "cactus_tall" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local D = require(ServerStorage.DevTools.PropsDesert:Clone()) :: any
local B2 = D.B2
local H = B2.H
local L = D.lib
local C = D.PALETTE
local scaled = H.scaled
local piece, merge = H.piece, H.merge
local envelope = L.envelope
local Data = require(ServerStorage.DevTools.PropsDesertNatureData:Clone()) :: any -- Agent A's rock facets (01)

local Nature = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local SAND, SAND_DARK = rgb(244, 208, 124), rgb(214, 168, 96)
local PEBBLE = rgb(196, 160, 112)
local GREEN, GREEN_LIGHT = rgb(76, 164, 84), rgb(85, 184, 94)
local SPINE = rgb(246, 238, 196)
local FLOWER_RED, FLOWER_YELLOW = rgb(214, 74, 62), rgb(255, 201, 60)
local COS8 = math.cos(math.pi / 8)

-- the cactus green, darker at the foot and lighter at the top (y of a piece in a plant H tall)
local function green(y: number, Ht: number, light: boolean?): Color3
	return scaled(if light then GREEN_LIGHT else GREEN, 0.84 + 0.24 * math.clamp(y / Ht, 0, 1))
end

-- a frame whose Y axis runs from a to b
local function axisFrame(a: Vector3, b: Vector3): CFrame
	local dir = (b - a).Unit
	local side = if math.abs(dir.Y) > 0.9 then Vector3.xAxis else UP
	local vx = (side - dir * side:Dot(dir)).Unit
	return CFrame.fromMatrix((a + b) / 2, vx, dir)
end

-- a ring of n short bars (radius r, bar thickness t) around centre c in the plane of the unit vectors u, v
local function ring(list: { BasePart }, c: Vector3, u: Vector3, v: Vector3, r: number, t: number, n: number, color: Color3)
	local len = 2 * math.pi * r / n * 1.08
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local p = c + (u * math.cos(a) + v * math.sin(a)) * r
		local tangent = -u * math.sin(a) + v * math.cos(a)
		table.insert(list, piece("Part", Vector3.new(len, t, t), CFrame.fromMatrix(p, tangent, u:Cross(v)), color))
	end
end

-- a ribbed cactus segment from a to b, w across the flats: an octagonal body, 8 ribs on its edges, a spine dot every
-- `spacing` along each rib (into `spines`)
local function ribbed(body: { BasePart }, spines: { BasePart }, a: Vector3, b: Vector3, w: number, color: Color3, ribColor: Color3, spacing: number)
	local cf = axisFrame(a, b)
	local len = (b - a).Magnitude
	table.insert(body, H.octagon(w, len, cf, color))
	local rv = w / 2 / COS8
	for k = 0, 7 do
		local ang = rad(22.5 + 45 * k)
		local rib = cf * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -(rv - 0.06))
		table.insert(body, piece("Part", Vector3.new(0.2, len, 0.2), rib * CFrame.Angles(0, rad(45), 0), ribColor))
		local n = math.floor(len / spacing)
		for i = 1, n do
			local t = -len / 2 + (i - 0.5) * len / n
			local s = cf * CFrame.Angles(0, ang, 0) * CFrame.new(0, t + (if k % 2 == 0 then 0 else spacing / 2) * 0.5, -(rv + 0.06))
			table.insert(spines, piece("Part", Vector3.new(0.12, 0.12, 0.12), s * CFrame.Angles(rad(45), rad(45), 0), SPINE))
		end
	end
end

-- a rounded octagonal dome (apothem r0 at its foot, r1 at its top, h tall) on a ribbed segment ending at `top` along dir
local function dome(body: { BasePart }, top: Vector3, dir: Vector3, r0: number, r1: number, h: number, color: Color3)
	local cf = axisFrame(top, top + dir) * CFrame.new(0, -0.5, 0) -- origin at `top`, Y along dir
	table.insert(body, L.frustum8(r0, r1, 0, h, cf * CFrame.Angles(0, rad(22.5), 0), color))
end

-- a flower: 5 petals round a yellow heart at cf (its Y up), d across
local function flower(list: { BasePart }, cf: CFrame, d: number, color: Color3)
	for k = 0, 4 do
		local p = cf * CFrame.Angles(0, k * 2 * math.pi / 5, 0) * CFrame.new(0, 0.08, -d * 0.28) * CFrame.Angles(rad(-35), 0, 0)
		table.insert(list, piece("Part", Vector3.new(d * 0.32, 0.08, d * 0.5), p, scaled(color, if k % 2 == 0 then 1 else 0.9)))
	end
	local heart = if color == FLOWER_YELLOW then rgb(232, 120, 40) else FLOWER_YELLOW
	table.insert(list, piece("Part", Vector3.new(d * 0.24, d * 0.24, d * 0.24), cf * CFrame.new(0, 0.12, 0) * CFrame.Angles(rad(45), rad(45), 0), heart))
end

-- a low sand mound (an octagonal frustum) at (x, z), radius r, with a few pebbles
local function mound(list: { BasePart }, rng: Random, x: number, z: number, r: number, h: number)
	table.insert(list, L.frustum8(r, r * 0.62, 0, h, CFrame.new(x, -0.02, z), SAND))
	table.insert(list, L.frustum8(r * 1.18, r * 0.9, 0, h * 0.45, CFrame.new(x, -0.02, z) * CFrame.Angles(0, rad(22.5), 0), SAND_DARK))
	for _ = 1, 4 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(r * 0.75, r * 1.15)
		local s = rng:NextNumber(0.25, 0.45)
		table.insert(list, piece("Part", Vector3.new(s, s * 0.6, s * 0.9), CFrame.new(x + math.cos(a) * d, s * 0.25, z + math.sin(a) * d) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)), scaled(PEBBLE, rng:NextNumber(0.85, 1.05))))
	end
end

-- today's colliding parts as separate invisible "Collision" parts (one union's convex hull would fill the gaps between
-- a cactus's arms and trunk)
local function collisionParts(m: Model, propId: string)
	for _, e in ipairs(D.ENVELOPES[propId]) do
		local cf = CFrame.new(table.unpack(e[5])):Orthonormalize()
		local p = piece(if e[1] == "Block" then "Part" else e[1], Vector3.new(e[2], e[3], e[4]), cf, GREEN)
		p.Name = "Collision"
		p.Transparency = 1
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
	end
end

local function finish(m: Model, propId: string, U: any, separate: boolean?)
	if separate then
		collisionParts(m, propId)
	else
		envelope(m, propId)
	end
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		merge(m, name, U[name], { query = name == "Body", shadow = name ~= "Spines" })
		task.wait()
	end
	local root = m:FindFirstChild("Body") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", propId)
	H.setBevelSelf(false)
end

---------------------------------------------------------------------
-- 04 CACTI (kits MapAssets.Desert.Cactus_A / _B / _C; 31 / 18 / 18 game copies in Desert_1-3 Decor.Cacti / Plants)
---------------------------------------------------------------------
D.ENVELOPES.cactus_tall = { -- Cactus_A: every part collides today
	{ "Block", 2.2, 11, 2.2, { 0, 5.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Trunk
	{ "Block", 1.7, 0.9, 1.7, { 0, 11.45, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Top
	{ "Block", 3, 1.4, 1.4, { -2.3, 4.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Arm
	{ "Block", 1.4, 4.6, 1.4, { -3.1, 7.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Arm
	{ "Block", 2.6, 1.4, 1.4, { 2.2, 6.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Arm
	{ "Block", 1.4, 3.4, 1.4, { 2.8, 9.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Arm
	{ "Block", 0.9, 0.5, 0.9, { 0, 12.15, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Flower
}
D.ENVELOPES.cactus_barrel = { -- Cactus_B
	{ "Block", 3.2, 3.4, 3.2, { 0, 1.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Barrel
	{ "Block", 3.2, 3.25, 3.2, { 0, 1.625, 0, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071 } }, -- Barrel
	{ "Block", 0.8, 0.4, 0.8, { 0, 3.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Flower
	{ "Block", 2.2, 2.4, 2.2, { 2.6, 1.2, 0.8, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Barrel
	{ "Block", 2.2, 2.25, 2.2, { 2.6, 1.125, 0.8, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071 } }, -- Barrel
	{ "Block", 0.8, 0.4, 0.8, { 2.6, 2.6, 0.8, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Flower
	{ "Block", 1.8, 1.9, 1.8, { -1.6, 0.95, 2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Barrel
	{ "Block", 1.8, 1.75, 1.8, { -1.6, 0.875, 2.2, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071 } }, -- Barrel
	{ "Block", 0.8, 0.4, 0.8, { -1.6, 2.1, 2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Flower
}
D.ENVELOPES.cactus_pear = { -- Cactus_C
	{ "Block", 3, 3.6, 1, { 0, 1.8, 0, 0.9659, 0, 0.2588, 0, 1, 0, -0.2588, 0, 0.9659 } }, -- Pad
	{ "Block", 2.4, 3, 0.9, { -1.6, 4.3, 0.3, 0.8297, -0.4412, -0.342, 0.4695, 0.8829, 0, 0.302, -0.1606, 0.9397 } }, -- Pad
	{ "Block", 2.2, 2.8, 0.9, { 1.5, 4.4, -0.2, 0.7912, 0.3522, 0.5, -0.4067, 0.9135, 0, -0.4568, -0.2034, 0.866 } }, -- Pad
	{ "Block", 1.8, 2.2, 0.8, { -2.6, 6.1, 0.4, 0.8067, -0.5649, 0.1736, 0.5736, 0.8192, 0, -0.1422, 0.0996, 0.9848 } }, -- Pad
	{ "Block", 0.7, 0.5, 0.7, { 1.9, 5.95, -0.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Flower
	{ "Block", 0.7, 0.5, 0.7, { -3.4, 7.25, 0.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Flower
}

-- the tall cactus (Cactus_A, 7.3 x 12.4 x 2.2): today's trunk (2.2 across, 11 tall) and its 2 arms (left: out at y 4.9,
-- up to 10.2; right: out at y 6.9, up to 11) as ribbed octagonal segments with elbows and rounded tops, 8 ribs with
-- spine dots, the dark-to-light green gradient, today's red flower on top as petals round a yellow heart, a sand mound
-- with pebbles. Parts: Body, Spines, Flower, Sand, Collision x7 (x9 barrel, x6 pear).
function Nature.cactus_tall(): Model
	local m = Instance.new("Model")
	m.Name = "cactus_tall"
	H.setBevelSelf(true) -- the octagons' cut faces: the body colour x1.1 (a lighter rib face), not the default grey
	local rng = Random.new(20261201)
	local Ht = 12.4
	local U = { Body = {}, Spines = {}, Flower = {}, Sand = {} }
	-- the trunk in 3 segments with soft joints
	local cuts = { 0, 3.8, 7.5, 11.0 }
	for i = 1, 3 do
		local y0, y1 = cuts[i], cuts[i + 1]
		local w = 2.2 - (i - 1) * 0.04
		ribbed(U.Body, U.Spines, Vector3.new(0, y0, 0), Vector3.new(0, y1, 0), w, green((y0 + y1) / 2, Ht), green((y0 + y1) / 2, Ht, true), 0.9)
		if i > 1 then
			table.insert(U.Body, H.octagon(w + 0.08, 0.14, CFrame.new(0, y0, 0), scaled(GREEN, 0.78)))
		end
	end
	dome(U.Body, Vector3.new(0, 11.0, 0), UP, 1.06, 0.45, 0.9, green(11.4, Ht, true))
	-- the arms: out, an elbow, up, a rounded top
	for _, a in ipairs({ { -1, 4.9, 3.1, 10.2 }, { 1, 6.9, 2.8, 11.0 } }) do
		local sx, y, x, top = a[1], a[2], a[3], a[4]
		ribbed(U.Body, U.Spines, Vector3.new(sx * 0.9, y, 0), Vector3.new(sx * (x - 0.45), y, 0), 1.36, green(y, Ht), green(y, Ht, true), 0.8)
		ribbed(U.Body, U.Spines, Vector3.new(sx * (x - 0.55), y - 0.05, 0), Vector3.new(sx * (x + 0.02), y + 0.55, 0), 1.36, green(y, Ht), green(y, Ht, true), 0.8)
		ribbed(U.Body, U.Spines, Vector3.new(sx * x, y + 0.35, 0), Vector3.new(sx * x, top - 0.6, 0), 1.36, green((y + top) / 2, Ht), green((y + top) / 2, Ht, true), 0.8)
		dome(U.Body, Vector3.new(sx * x, top - 0.6, 0), UP, 0.66, 0.28, 0.6, green(top, Ht, true))
	end
	-- today's red flower on the top (y 11.9 .. 12.4)
	flower(U.Flower, CFrame.new(0, 11.88, 0), 0.95, FLOWER_RED)
	mound(U.Sand, rng, 0, 0, 1.9, 0.35)
	finish(m, "cactus_tall", U, true)
	return m
end

-- a barrel cactus at (x, z), w across, h tall: a ribbed octagonal body with a rounded foot and crown, ribs running over
-- the crown, spine dots, its flower on top
local function barrel(U: any, x: number, z: number, w: number, h: number, flowerColor: Color3)
	local base = CFrame.new(x, 0, z)
	local r = w / 2
	local rv = r / COS8
	table.insert(U.Body, L.frustum8(r * 0.8, r, 0, h * 0.22, base * CFrame.Angles(0, rad(22.5), 0), green(h * 0.1, 4, false)))
	ribbed(U.Body, U.Spines, Vector3.new(x, h * 0.22, z), Vector3.new(x, h * 0.68, z), w, green(h * 0.45, 4), green(h * 0.45, 4, true), 0.7)
	table.insert(U.Body, L.frustum8(r, r * 0.42, h * 0.68, h * 0.96, base * CFrame.Angles(0, rad(22.5), 0), green(h, 4, true)))
	for k = 0, 7 do
		local ang = rad(22.5 + 45 * k)
		local d = Vector3.new(math.sin(ang), 0, -math.cos(ang))
		local a = Vector3.new(x, h * 0.68, z) + d * (rv - 0.06)
		local b = Vector3.new(x, h * 0.95, z) + d * (rv * 0.42)
		table.insert(U.Body, H.bar(a, b, 0.18, green(h, 4, true)))
		table.insert(U.Spines, piece("Part", Vector3.new(0.12, 0.12, 0.12), CFrame.new((a + b) / 2 + Vector3.new(0, 0.08, 0)) * CFrame.Angles(rad(45), rad(45), 0), SPINE))
	end
	flower(U.Flower, CFrame.new(x, h * 0.95, z), math.min(0.85, w * 0.3), flowerColor)
end

-- the barrel cacti (Cactus_B, 7.0 x 3.8 x 5.7): today's 3 barrels (3.2 / 2.2 / 1.8 across, 3.4 / 2.4 / 1.9 tall) in
-- today's places with today's red / yellow / red flowers, on a sand mound with pebbles.
function Nature.cactus_barrel(): Model
	local m = Instance.new("Model")
	m.Name = "cactus_barrel"
	H.setBevelSelf(true)
	local rng = Random.new(20261202)
	local U = { Body = {}, Spines = {}, Flower = {}, Sand = {} }
	barrel(U, 0, 0, 3.2, 3.4, FLOWER_RED)
	barrel(U, 2.6, 0.8, 2.2, 2.4, FLOWER_YELLOW)
	barrel(U, -1.6, 2.2, 1.8, 1.9, FLOWER_RED)
	mound(U.Sand, rng, 0.4, 0.9, 3.0, 0.3)
	finish(m, "cactus_barrel", U, true)
	return m
end

-- a prickly-pear pad: a bevelled oval (an octagon on the ellipse a x b, t thick) at cf (its Z = the pad's normal)
local function pad(list: { BasePart }, cf: CFrame, a: number, b: number, t: number, color: Color3)
	local planes = { { 0, 0, 1, t / 2 }, { 0, 0, -1, t / 2 } }
	local e = t * 0.32
	local s = math.sqrt(0.5)
	for k = 0, 7 do
		local th = k * math.pi / 4
		local u = Vector3.new(math.cos(th), math.sin(th), 0)
		local ds = math.sqrt((a * u.X) ^ 2 + (b * u.Y) ^ 2)
		table.insert(planes, { u.X, u.Y, 0, ds })
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(planes, { u.X * s, u.Y * s, sz * s, (ds - e + t / 2) * s })
		end
	end
	table.insert(list, H.convexSolid(Vector3.new(-a - 0.05, -b - 0.05, -t / 2 - 0.02), Vector3.new(a + 0.05, b + 0.05, t / 2 + 0.02), cf, color, planes))
end

-- the prickly pear (Cactus_C, 7.1 x 7.5 x 2.7): today's 4 pads (same places, sizes and tilts) as bevelled ovals in two
-- greens with rows of spine dots on both faces, today's 2 red flowers, 2 small red fruits, a sand mound with pebbles.
function Nature.cactus_pear(): Model
	local m = Instance.new("Model")
	m.Name = "cactus_pear"
	H.setBevelSelf(true)
	local rng = Random.new(20261203)
	local U = { Body = {}, Spines = {}, Flower = {}, Sand = {} }
	local env = D.ENVELOPES.cactus_pear
	for i = 1, 4 do
		local e = env[i]
		local cf = CFrame.new(table.unpack(e[5])):Orthonormalize()
		local a, b, t = e[2] / 2, e[3] / 2, e[4]
		local col = green(cf.Y, 7.5, i % 2 == 0)
		pad(U.Body, cf, a, b, t, col)
		-- areoles: staggered rows of spine dots on both faces
		for row = -2, 2 do
			for colI = -2, 2 do
				local px = (colI + (if row % 2 == 0 then 0 else 0.5)) * a * 0.42
				local py = row * b * 0.36
				if (px / a) ^ 2 + (py / b) ^ 2 < 0.62 then
					for _, sz in ipairs({ -1, 1 }) do
						table.insert(U.Spines, piece("Part", Vector3.new(0.13, 0.13, 0.13), cf * CFrame.new(px, py, sz * (t / 2 + 0.02)) * CFrame.Angles(rad(45), rad(45), 0), SPINE))
					end
				end
			end
		end
	end
	-- today's 2 red flowers and 2 fruits on pad rims
	flower(U.Flower, CFrame.new(1.9, 5.75, -0.2), 0.8, FLOWER_RED)
	flower(U.Flower, CFrame.new(-3.4, 7.05, 0.4), 0.8, FLOWER_RED)
	for _, p in ipairs({ Vector3.new(-0.9, 5.75, 0.3), Vector3.new(0.6, 3.75, 0.05) }) do
		table.insert(U.Flower, L.frustum8(0.18, 0.24, 0, 0.42, CFrame.new(p), scaled(FLOWER_RED, 0.86)))
	end
	mound(U.Sand, rng, -0.2, 0.1, 1.9, 0.3)
	finish(m, "cactus_pear", U, true)
	return m
end

---------------------------------------------------------------------
-- 02 SANDSTONE BLOCKS (kit MapAssets.Desert.Sandstone_Block; 4 game copies in Desert_3 Decor.Ruins)
---------------------------------------------------------------------
D.ENVELOPES.sandstone_blocks = { -- Sandstone_Block: both blocks collide today
	{ "Block", 6, 3, 4, { 0, 1.5, 0, 0.9945, 0, 0.1045, 0, 1, 0, -0.1045, 0, 0.9945 } }, -- Block
	{ "Block", 3.4, 2.4, 3, { 1, 4.2, 0.2, 0.9511, 0, -0.309, 0, 1, 0, 0.309, 0, 0.9511 } }, -- Block
}

-- a cut sandstone block (size at cf): chamfered edges, 2 chipped top corners, a darker weathered foot, weathering lines
-- on its 4 sides; `joints` adds carved joint lines (one vertical on the long faces, one horizontal all round)
local function cutBlock(U: any, rng: Random, size: Vector3, cf: CFrame, color: Color3, joints: boolean)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local chips = {}
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	local first = rng:NextInteger(1, 4)
	for k = 0, 1 do
		local c = corners[(first + k * 2 - 1) % 4 + 1]
		local s = rng:NextNumber(0.7, 1.0)
		table.insert(chips, piece("Part", Vector3.new(s, s, s), cf * CFrame.new(c[1] * hx, hy, c[2] * hz) * CFrame.Angles(rad(45), rad(45 + rng:NextNumber(-15, 15)), 0), color))
	end
	table.insert(U.Body, H.chamfered(size, cf, color, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.12, chips))
	-- the weathered foot: a darker skirt 0.25 of the height
	table.insert(U.Body, piece("Part", Vector3.new(size.X - 0.2, size.Y * 0.22, size.Z + 0.04), cf * CFrame.new(0, -hy + size.Y * 0.11 + 0.02, 0), scaled(color, 0.88)))
	table.insert(U.Body, piece("Part", Vector3.new(size.X + 0.04, size.Y * 0.22, size.Z - 0.2), cf * CFrame.new(0, -hy + size.Y * 0.11 + 0.02, 0), scaled(color, 0.88)))
	-- weathering lines on the 4 faces (darker strips 0.06 tall, a hair proud)
	for face = 0, 3 do
		local along = if face % 2 == 0 then size.X else size.Z
		local depth = if face % 2 == 0 then hz else hx
		local turn = cf * CFrame.Angles(0, face * math.pi / 2, 0)
		for _ = 1, 2 do
			local len = along * rng:NextNumber(0.25, 0.6)
			local u = rng:NextNumber(-along / 2 + len / 2 + 0.2, along / 2 - len / 2 - 0.2)
			local y = rng:NextNumber(-hy * 0.4, hy * 0.7)
			table.insert(U.Body, piece("Part", Vector3.new(len, 0.06, 0.04), turn * CFrame.new(u, y, -depth - 0.01) * CFrame.Angles(0, 0, rad(rng:NextNumber(-4, 4))), scaled(color, 0.84)))
		end
	end
	if joints then
		local jx = size.X * 0.12
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Body, piece("Part", Vector3.new(0.08, size.Y - 0.3, 0.04), cf * CFrame.new(jx, 0, sz * (hz + 0.01)), scaled(color, 0.7)))
		end
		table.insert(U.Body, piece("Part", Vector3.new(size.X + 0.02, 0.08, size.Z + 0.02), cf * CFrame.new(0, hy * 0.1, 0), scaled(color, 0.72)))
	end
end

-- the sandstone blocks (Sandstone_Block, 6.4 x 5.4 x 4.6): today's 2 stacked blocks (6 x 3 x 4 turned 6, 3.4 x 2.4 x 3
-- turned -18, today's 2 tones) as cut blocks with chipped corners, a weathered foot, weathering lines, carved joint
-- lines on the big one, a faint carved ankh and eye on its front, sand drifts and pebbles at the foot.
-- Parts: Body, Sand, Collision x2.
function Nature.sandstone_blocks(): Model
	local m = Instance.new("Model")
	m.Name = "sandstone_blocks"
	local rng = Random.new(20261204)
	H.setBevelSelf(true)
	local U = { Body = {}, Sand = {} }
	local SAND1, SAND2 = C.Sandstone, rgb(213, 179, 124)
	local cf1 = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, rad(6), 0)
	local cf2 = CFrame.new(1, 4.2, 0.2) * CFrame.Angles(0, rad(-18), 0)
	cutBlock(U, rng, Vector3.new(6, 3, 4), cf1, SAND1, true)
	cutBlock(U, rng, Vector3.new(3.4, 2.4, 3), cf2, SAND2, false)
	-- the faint carved glyphs on the big block's front (z -2): an ankh and an eye, one tone darker, 0.03 proud
	local FAINT = scaled(SAND1, 0.82)
	local face = cf1 * CFrame.new(0, 0, -2.015)
	local ankh = face * CFrame.new(-1.6, 0.05, 0)
	ring(U.Body, (ankh * CFrame.new(0, 0.62, 0)).Position, (ankh.RightVector), UP, 0.26, 0.11, 8, FAINT)
	table.insert(U.Body, piece("Part", Vector3.new(0.12, 0.85, 0.03), ankh * CFrame.new(0, -0.1, 0), FAINT))
	table.insert(U.Body, piece("Part", Vector3.new(0.7, 0.12, 0.03), ankh * CFrame.new(0, 0.3, 0), FAINT))
	local eye = face * CFrame.new(1.3, 0.25, 0)
	table.insert(U.Body, piece("Part", Vector3.new(0.42, 0.42, 0.03), eye * CFrame.Angles(0, 0, rad(45)), FAINT))
	table.insert(U.Body, piece("Part", Vector3.new(0.16, 0.16, 0.04), eye * CFrame.new(0, 0, -0.01), scaled(SAND1, 0.7)))
	table.insert(U.Body, piece("Part", Vector3.new(0.9, 0.09, 0.03), eye * CFrame.new(0.05, 0.42, 0), FAINT))
	table.insert(U.Body, piece("Part", Vector3.new(0.09, 0.5, 0.03), eye * CFrame.new(0.05, -0.42, 0) * CFrame.Angles(0, 0, rad(15)), FAINT))
	-- sand drifts against the front and one side, pebbles
	table.insert(U.Sand, piece("WedgePart", Vector3.new(5.6, 0.6, 1.1), cf1 * CFrame.new(0, -1.2, -2.5), SAND))
	table.insert(U.Sand, piece("WedgePart", Vector3.new(3.6, 0.5, 0.9), cf1 * CFrame.new(-3.4, -1.25, 0) * CFrame.Angles(0, rad(90), 0), SAND))
	mound(U.Sand, rng, 2.6, 2.2, 1.1, 0.3)
	finish(m, "sandstone_blocks", U, true)
	return m
end

---------------------------------------------------------------------
-- 03 RIBS + BULL SKULL (kits MapAssets.Desert.Ribcage_A (8 game copies) and Skull_Animal (13 game copies))
---------------------------------------------------------------------
D.ENVELOPES.ribcage = { -- Ribcage_A: every part collides today
	{ "Block", 1, 1, 11, { 0, 4.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Spine
	{ "Block", 0.7, 4.4, 0.7, { -1.9, 2, -4.4, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.4, 0.7, { 1.9, 2, -4.4, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.9, 0.7, { -1.9, 2.25, -2.2, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.9, 0.7, { 1.9, 2.25, -2.2, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 5.4, 0.7, { -1.9, 2.5, 0, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 5.4, 0.7, { 1.9, 2.5, 0, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.9, 0.7, { -1.9, 2.25, 2.2, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.9, 0.7, { 1.9, 2.25, 2.2, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.4, 0.7, { -1.9, 2, 4.4, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
	{ "Block", 0.7, 4.4, 0.7, { 1.9, 2, 4.4, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1 } }, -- Rib
}
D.ENVELOPES.bull_skull = { -- Skull_Animal: every part collides today
	{ "Block", 2.4, 1.8, 2.6, { 0, 1, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Cranium
	{ "Block", 1.6, 1.2, 2.4, { 0, 0.6, -1.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Snout
	{ "Block", 3, 0.6, 0.6, { -2.4, 1.7, 0.8, 0.9272, 0.3746, 0, -0.3746, 0.9272, 0, 0, 0, 1 } }, -- Horn
	{ "Block", 0.5, 1.7, 0.5, { -3.9, 2.95, 0.8, 0.9848, -0.1736, 0, 0.1736, 0.9848, 0, 0, 0, 1 } }, -- Horn
	{ "Block", 0.7, 0.7, 0.3, { -0.7, 1.25, -0.72, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Eye
	{ "Block", 3, 0.6, 0.6, { 2.4, 1.7, 0.8, 0.9272, -0.3746, 0, 0.3746, 0.9272, 0, 0, 0, 1 } }, -- Horn
	{ "Block", 0.5, 1.7, 0.5, { 3.9, 2.95, 0.8, 0.9848, 0.1736, 0, -0.1736, 0.9848, 0, 0, 0, 1 } }, -- Horn
	{ "Block", 0.7, 0.7, 0.3, { 0.7, 1.25, -0.72, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Eye
}

local BONE, BONE_SHADE, HORN = rgb(240, 232, 208), rgb(227, 219, 196), rgb(219, 212, 190)
local SOCKET = rgb(83, 62, 40)

-- bone colour: the soft gradient, a little warmer and darker low down
local function bone(y: number, Ht: number): Color3
	return BONE_SHADE:Lerp(BONE, math.clamp(y / Ht, 0, 1))
end

-- a tapering chain of octagonal segments through the points (widths w0 -> w1)
local function chain(list: { BasePart }, pts: { Vector3 }, w0: number, w1: number, colorAt: any)
	for i = 1, #pts - 1 do
		local t = (i - 1) / math.max(1, #pts - 2)
		local w = w0 + (w1 - w0) * t
		local a, b = pts[i], pts[i + 1]
		table.insert(list, H.octagon(w, (b - a).Magnitude + w * 0.35, axisFrame(a, b), colorAt((a.Y + b.Y) / 2, t)))
	end
end

-- the rib cage (Ribcage_A, 7.2 x 5.4 x 11.0): today's spine (11 long at y 4.8) as 9 vertebrae with spinous and side
-- processes and darker discs, today's 10 ribs (same feet, tops and lengths) as curved tapering bones bowed outwards,
-- the bone gradient, hairline cracks, the rib feet half buried in sand piles along a low mound.
-- Parts: Body, Sand, Collision x11.
function Nature.ribcage(): Model
	local m = Instance.new("Model")
	m.Name = "ribcage"
	local rng = Random.new(20261205)
	H.setBevelSelf(true)
	local Ht = 5.4
	local U = { Body = {}, Sand = {} }
	-- the spine
	for i = 0, 8 do
		local z = -4.9 + i * 1.225
		local seg = CFrame.new(0, 4.8, z) * CFrame.Angles(rad(90), 0, 0)
		table.insert(U.Body, H.octagon(0.95, 1.0, seg, bone(4.9, Ht)))
		table.insert(U.Body, piece("WedgePart", Vector3.new(0.26, 0.55, 0.75), CFrame.new(0, 5.5, z + 0.1) * CFrame.Angles(0, math.pi, 0), bone(5.4, Ht)))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Body, piece("Part", Vector3.new(0.5, 0.2, 0.3), CFrame.new(sx * 0.6, 4.95, z) * CFrame.Angles(0, 0, sx * rad(12)), bone(4.9, Ht)))
		end
		if i < 8 then
			table.insert(U.Body, H.octagon(0.78, 0.22, CFrame.new(0, 4.8, z + 0.6125) * CFrame.Angles(rad(90), 0, 0), scaled(BONE_SHADE, 0.88)))
		end
	end
	-- the ribs: today's top and foot, bowed outwards on a curve of 5 points
	local data = { { -4.4, 4.4 }, { -2.2, 4.9 }, { 0, 5.4 }, { 2.2, 4.9 }, { 4.4, 4.4 } }
	for _, r in ipairs(data) do
		local z, len = r[1], r[2]
		for _, sx in ipairs({ -1, 1 }) do
			local c = Vector3.new(sx * 1.9, len / 2 - 0.2, z)
			local up = Vector3.new(-sx * 0.515, 0.857, 0)
			local out = Vector3.new(sx * 0.857, 0.515, 0)
			local top = Vector3.new(sx * 0.42, 4.6, z)
			local foot = c - up * len / 2
			local pts = {}
			for k = 0, 4 do
				local t = k / 4
				local p = top:Lerp(foot, t) + out * (math.sin(t * math.pi) * 0.55)
				table.insert(pts, p)
			end
			chain(U.Body, pts, 0.52, 0.38, function(y: number)
				return bone(y, Ht)
			end)
			table.insert(U.Sand, L.frustum8(0.55, 0.25, 0, 0.35, CFrame.new(foot.X, -0.02, foot.Z), SAND))
			if rng:NextNumber() < 0.35 then
				local p = pts[3]
				table.insert(U.Body, piece("Part", Vector3.new(0.05, 0.45, 0.04), CFrame.new(p + out * 0.27) * CFrame.Angles(0, 0, sx * rad(20)), scaled(BONE_SHADE, 0.7)))
			end
		end
	end
	-- the low sand mound along the cage
	for _, z in ipairs({ -3.6, 0, 3.6 }) do
		table.insert(U.Sand, L.frustum8(2.3, 1.6, 0, 0.3, CFrame.new(0, -0.02, z), SAND))
	end
	for _ = 1, 4 do
		local s = rng:NextNumber(0.25, 0.45)
		table.insert(U.Sand, piece("Part", Vector3.new(s, s * 0.6, s * 0.9), CFrame.new(rng:NextNumber(-3.2, 3.2), s * 0.25, rng:NextNumber(-5.5, 5.5)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), scaled(PEBBLE, rng:NextNumber(0.85, 1.05))))
	end
	finish(m, "ribcage", U, true)
	return m
end

-- the bull skull (Skull_Animal, 8.6 x 3.8 x 4.7): today's cranium, snout and horns in place; the cranium with deep
-- dark eye sockets, a brow ridge and a poll ridge between the horns, hairline cracks; a nose bridge sloping onto the
-- snout, 2 dark nostrils, a row of teeth; the horns as curved tapering octagonal segments (out at today's angle, then up
-- to today's tips), darker toward the point; half buried in a sand mound.
-- Parts: Body, Sand, Collision x8.
function Nature.bull_skull(): Model
	local m = Instance.new("Model")
	m.Name = "bull_skull"
	local rng = Random.new(20261206)
	H.setBevelSelf(true)
	local Ht = 3.8
	local U = { Body = {}, Sand = {} }
	-- the cranium with its eye sockets (cut, dark walls)
	local sockets = {}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(sockets, piece("Part", Vector3.new(0.66, 0.6, 1.0), CFrame.new(sx * 0.7, 1.25, -0.72) * CFrame.Angles(0, 0, sx * rad(-10)), SOCKET))
	end
	table.insert(U.Body, H.chamfered(Vector3.new(2.4, 1.8, 2.6), CFrame.new(0, 1, 0.6), bone(1, Ht), { "vertical", "topFrontBack", "topSides" }, 0.32, nil, sockets))
	table.insert(U.Body, piece("Part", Vector3.new(2.5, 0.28, 0.34), CFrame.new(0, 1.66, -0.62), bone(1.7, Ht)))
	table.insert(U.Body, H.chamfered(Vector3.new(2.7, 0.45, 0.7), CFrame.new(0, 1.92, 0.95), bone(1.9, Ht), { "topFrontBack", "topSides" }, 0.15))
	-- the nose bridge and the snout with its nostrils and teeth
	table.insert(U.Body, piece("WedgePart", Vector3.new(1.2, 0.45, 1.7), CFrame.new(0, 1.42, -1.25), bone(1.4, Ht)))
	local nostrils = {}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(nostrils, piece("Part", Vector3.new(0.22, 0.32, 0.5), CFrame.new(sx * 0.3, 0.78, -2.8), SOCKET))
	end
	table.insert(U.Body, H.chamfered(Vector3.new(1.6, 1.2, 2.4), CFrame.new(0, 0.6, -1.6), bone(0.6, Ht), { "vertical", "topFrontBack", "topSides" }, 0.22, nil, nostrils))
	for i = -2, 2 do
		table.insert(U.Body, piece("Part", Vector3.new(0.2, 0.22, 0.14), CFrame.new(i * 0.24, 0.2, -2.8), rgb(248, 242, 224)))
	end
	-- hairline cracks on the cranium top
	for _, c in ipairs({ { -0.4, 0.2, 25 }, { 0.3, 1.0, -30 }, { 0.6, 0.5, 70 } }) do
		table.insert(U.Body, piece("Part", Vector3.new(0.05, 0.03, 0.7), CFrame.new(c[1], 1.91, c[2]) * CFrame.Angles(0, rad(c[3]), 0), scaled(BONE_SHADE, 0.7)))
	end
	-- the horns: out from the cranium side at today's angle, curving up to today's tips
	for _, sx in ipairs({ -1, 1 }) do
		local pts = { Vector3.new(sx * 1.05, 1.35, 0.8), Vector3.new(sx * 2.3, 1.72, 0.8), Vector3.new(sx * 3.35, 2.15, 0.82), Vector3.new(sx * 3.85, 2.75, 0.85), Vector3.new(sx * 4.0, 3.45, 0.82) }
		chain(U.Body, pts, 0.66, 0.4, function(_y: number, t: number)
			return scaled(HORN, 1 - 0.14 * t)
		end)
		table.insert(U.Body, L.frustum8(0.2, 0.04, 0, 0.45, axisFrame(pts[5], pts[5] + Vector3.new(sx * 0.03, 1, 0)) * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, rad(22.5), 0), scaled(HORN, 0.8)))
		table.insert(U.Body, H.octagon(0.74, 0.22, axisFrame(pts[1], pts[2]) * CFrame.new(0, -0.35, 0), scaled(HORN, 0.9)))
	end
	-- half buried: a sand mound round the jaw and cranium, pebbles
	mound(U.Sand, rng, 0, -0.6, 2.2, 0.4)
	table.insert(U.Sand, L.frustum8(1.0, 0.6, 0, 0.35, CFrame.new(0, -0.02, -2.4), SAND))
	finish(m, "bull_skull", U, true)
	return m
end

---------------------------------------------------------------------
-- 01 RED ROCK STACK (kit MapAssets.Desert.Mesa_Strata_A: 4 game copies in Desert_3 Decor.Formations, 6 backdrop copies
-- in Desert_1 / Desert_2 Decor.Backdrop.Mesas) and the 5 Desert_3 hoodoos (Decor.Formations.Hoodoo, rebuilt in place)
---------------------------------------------------------------------
D.ENVELOPES.mesa_strata = { -- Mesa_Strata_A: every part collides today (the backdrop copies: none)
	{ "Block", 21.383, 9, 17.734, { -8.902, 4.5, 1.633, 0.99864, 0, 0.05206, 0, 1, 0, -0.05206, 0, 0.99864 } }, -- Strata
	{ "Block", 21.84, 9, 19.145, { 9.714, 4.5, 0.928, 0.99713, 0, 0.07565, 0, 1, 0, -0.07565, 0, 0.99713 } }, -- Strata
	{ "Block", 21.131, 4, 20.694, { -8.803, 11, 0.653, 0.99826, 0, -0.05888, 0, 1, 0, 0.05888, 0, 0.99826 } }, -- Strata
	{ "Block", 22.898, 4, 21.037, { 8.988, 11, 0.481, 0.99883, 0, 0.04845, 0, 1, 0, -0.04845, 0, 0.99883 } }, -- Strata
	{ "Block", 21.752, 11, 16.854, { -9.155, 18.5, 3.073, 0.99995, 0, -0.01035, 0, 1, 0, 0.01035, 0, 0.99995 } }, -- Strata
	{ "Block", 21.703, 11, 16.999, { 9.144, 18.5, 3, 0.9981, 0, -0.06166, 0, 1, 0, 0.06166, 0, 0.9981 } }, -- Strata
	{ "Block", 21.532, 4, 19.602, { -9.575, 26, 2.199, 0.99936, 0, -0.03569, 0, 1, 0, 0.03569, 0, 0.99936 } }, -- Strata
	{ "Block", 21.052, 4, 17.627, { 9.329, 26, 3.187, 0.99716, 0, 0.07525, 0, 1, 0, -0.07525, 0, 0.99716 } }, -- Strata
	{ "Block", 22.994, 11, 16.871, { -9.09, 33.5, 4.065, 0.99784, 0, -0.06568, 0, 1, 0, 0.06568, 0, 0.99784 } }, -- Strata
	{ "Block", 22.554, 11, 14.371, { 9.173, 33.5, 5.314, 1, 0, 0.00296, 0, 1, 0, -0.00296, 0, 1 } }, -- Strata
	{ "Block", 22.188, 4, 18.287, { -8.805, 41, 3.857, 0.99737, 0, -0.07251, 0, 1, 0, 0.07251, 0, 0.99737 } }, -- Strata
	{ "Block", 21.552, 4, 16.371, { 9.412, 41, 4.815, 0.9987, 0, -0.05097, 0, 1, 0, 0.05097, 0, 0.9987 } }, -- Strata
	{ "Block", 22.113, 7, 13.343, { -9.131, 46.5, 6.828, 0.99864, 0, -0.05215, 0, 1, 0, 0.05215, 0, 0.99864 } }, -- Strata
	{ "Block", 21.572, 7, 15.085, { 9.053, 46.5, 5.958, 0.99831, 0, 0.05806, 0, 1, 0, -0.05806, 0, 0.99831 } }, -- Strata
	{ "Block", 9, 6, 8, { -11, 51, 7, 0.93969, 0, 0.34202, 0, 1, 0, -0.34202, 0, 0.93969 } }, -- Cap
	{ "Block", 7, 4, 7, { 8, 51, 8, 0.96593, 0, -0.25882, 0, 1, 0, 0.25882, 0, 0.96593 } }, -- Cap
	{ "WedgePart", 14, 7, 8, { -8, 3.5, -3, 0.99027, 0, 0.13917, 0, 1, 0, -0.13917, 0, 0.99027 } }, -- Talus
	{ "WedgePart", 10, 5, 6, { 10, 2.5, -2.5, 0.98481, 0, -0.17365, 0, 1, 0, 0.17365, 0, 0.98481 } }, -- Talus
}

local MESA_PIECES = {
	{ "RockLowerL", "mesa_column_L_lower" },
	{ "RockUpperL", "mesa_column_L_upper" },
	{ "RockLowerR", "mesa_column_R_lower" },
	{ "RockUpperR", "mesa_column_R_upper" },
	{ "Scree", "mesa_base_scree" },
}

-- one of Agent A's facet pieces (DevTools.PropsDesertNatureData) as wedge pairs into `list`, scaled by sc (per axis) in
-- `frame`; t scales with the smallest axis
local function facetPiece(list: { BasePart }, data: any, sc: Vector3, frame: CFrame)
	local ts = math.min(sc.X, sc.Y, sc.Z)
	local colors = {}
	for i, hex in ipairs(data.palette) do
		colors[i] = Color3.fromHex(hex)
	end
	for _, t in ipairs(data.tris) do
		local a = Vector3.new(t[1], t[2], t[3]) * sc
		local b = Vector3.new(t[4], t[5], t[6]) * sc
		local c = Vector3.new(t[7], t[8], t[9]) * sc
		H.triangleParts(list, a, b, c, t[10] * ts, frame, colors[t[11]])
	end
end

-- the red rock stack (Mesa_Strata_A, 42.4 x 54 x 24.7): Agent A's v2 natural canyon rock (2 columns of irregular strata,
-- dark red / red / orange, sloped facets, crumbling ledges, alcoves, runnels, the 2 cap rocks, the talus as scree with a
-- sand pile, small rocks and fallen blocks), placed at the model pivot, in 5 unions under 20,000 triangles each; today's
-- 18 boxes as invisible colliders. The backdrop copies take the variant "Backdrop": no collision, no query, no shadow
-- (as today). Parts: RockLowerL, RockUpperL, RockLowerR, RockUpperR, Scree, Collision x18.
function Nature.mesa_strata(): Model
	local m = Instance.new("Model")
	m.Name = "mesa_strata"
	for _, p in ipairs(MESA_PIECES) do
		local list = {}
		facetPiece(list, Data[p[2]], Vector3.one, CFrame.identity)
		merge(m, p[1], list, { query = true })
		task.wait()
	end
	collisionParts(m, "mesa_strata")
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	local cfg = Instance.new("Configuration")
	cfg.Name = "Backdrop"
	cfg:SetAttribute("CanCollide_Collision", false)
	cfg:SetAttribute("CanQuery_Collision", false)
	for _, p in ipairs(MESA_PIECES) do
		cfg:SetAttribute("CastShadow_" .. p[1], false)
		cfg:SetAttribute("CanQuery_" .. p[1], false)
	end
	cfg.Parent = folder
	folder.Parent = m
	local root = m:FindFirstChild("RockLowerL") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "mesa_strata")
	return m
end

-- the 5 Desert_3 hoodoos, rebuilt in place (they have no kit or test copy): today's 5 Strata boxes and Cap become
-- invisible colliders ("Collision", same size and place); Agent A's v2 hoodoo (variant A / B alternating) is added as 2
-- non-colliding unions (RockLower, RockUpper), scaled to today's hoodoo (height: today's top / 23.2; width: today's
-- width / the smallest hoodoo's) and turned. Idempotent: a second call rebuilds the 2 unions from the same numbers.
function Nature.rebuildHoodoos(): string
	local formations = workspace:FindFirstChild("Zones") and workspace.Zones.Desert.Desert_3.Decor.Formations
	local hoodoos = {}
	for _, h in ipairs(formations:GetChildren()) do
		if h:IsA("Model") and h.Name == "Hoodoo" then
			table.insert(hoodoos, h)
		end
	end
	-- today's boxes (Strata / Cap, or the Collision parts of an earlier rebuild): size in the hoodoo's pivot space
	local function measure(h: Model): (number, number)
		local piv = h:GetPivot()
		local top, minX, maxX, minZ, maxZ = 0, math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(h:GetChildren()) do
			if p:IsA("BasePart") and (p.Name == "Strata" or p.Name == "Cap" or p.Name == "Collision") then
				local cf = piv:ToObjectSpace(p.CFrame)
				local s = p.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local q = cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z)
							top = math.max(top, q.Y)
							minX, maxX = math.min(minX, q.X), math.max(maxX, q.X)
							minZ, maxZ = math.min(minZ, q.Z), math.max(maxZ, q.Z)
						end
					end
				end
			end
		end
		return top, ((maxX - minX) + (maxZ - minZ)) / 2
	end
	table.sort(hoodoos, function(a, b)
		local ta = measure(a)
		local tb = measure(b)
		return ta < tb
	end)
	local _, baseWidth = measure(hoodoos[1])
	local report = {}
	local TURNS = { 0, 72, 144, 216, 288 }
	for i, h in ipairs(hoodoos) do
		local top, width = measure(h)
		local sy, sxz = top / 23.2, width / baseWidth
		for _, p in ipairs(h:GetChildren()) do
			if p:IsA("BasePart") and (p.Name == "Strata" or p.Name == "Cap") then
				p.Name = "Collision"
				p.Transparency = 1
				p.CastShadow = false
				p.CanTouch = false
			elseif p.Name == "RockLower" or p.Name == "RockUpper" then
				p:Destroy()
			end
		end
		local variant = if i % 2 == 1 then "A" else "B"
		local frame = h:GetPivot() * CFrame.Angles(0, rad(TURNS[i]), 0)
		for _, part in ipairs({ { "RockLower", "lower" }, { "RockUpper", "upper" } }) do
			local list = {}
			facetPiece(list, Data["hoodoo_" .. variant .. "_" .. part[2]], Vector3.new(sxz, sy, sxz), frame)
			local u = merge(h :: any, part[1], list, { query = true })
			u.Parent = h
			task.wait()
		end
		h:SetAttribute("HoodooVariant", variant)
		h:SetAttribute("HoodooScale", string.format("%.2f x %.2f", sxz, sy))
		table.insert(report, string.format("%s at %s: variant %s, scale %.2f wide x %.2f high, turned %d", h:GetFullName(), tostring(h:GetPivot().Position), variant, sxz, sy, TURNS[i]))
	end
	return table.concat(report, "\n")
end

---------------------------------------------------------------------
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Nature.BUILDERS = { cactus_tall = true, cactus_barrel = true, cactus_pear = true, sandstone_blocks = true, ribcage = true, bull_skull = true, mesa_strata = true }
for id in pairs(Nature.BUILDERS) do
	B2[id] = (Nature :: any)[id]
	B2.BUILDERS[id] = true
end
Nature.install = B2.install
Nature.stats = B2.stats
Nature.ENVELOPES = D.ENVELOPES -- for the collision checks

return Nature
