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
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Nature.BUILDERS = { cactus_tall = true, cactus_barrel = true, cactus_pear = true }
for id in pairs(Nature.BUILDERS) do
	B2[id] = (Nature :: any)[id]
	B2.BUILDERS[id] = true
end
Nature.install = B2.install
Nature.stats = B2.stats
Nature.ENVELOPES = D.ENVELOPES -- for the collision checks

return Nature
