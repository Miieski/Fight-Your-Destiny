--[[
	PropsRound8 (dev tool, Edit mode only) - owner prompt "ROUND 8" part 2: the teleport point, the spawn disc, the round
	planter, the rail end (docs/Round8_Fixes_Doors_Floors/PROMPT_Round8_Fixes_Doors_Floors.txt).
	Source of truth: tools/PropsRound8.luau (= ServerStorage.DevTools.PropsRound8).

		local R8 = require(game.ServerStorage.DevTools.PropsRound8:Clone())
		print(R8.build("hub_return_pad"))  -- also hub_spawn_pad, hub_furniture_planter, hub_furniture_planter_v2,
		                                   -- plains_rail_buffer, plains_bridge_rail_section
		print(R8.placePads(), R8.placeSpawn(), R8.placeBuffer())  -- the copies of the new templates (idempotent)
		then Sync.run({ only = { ids } }).

	Every visible piece is decor (no collision, no query). The functional parts stay what they were: HubReturn (its Touched
	teleport, now invisible: the Surface of the template shows), HubReturn_Pad (the sparkles), the SpawnLocation, the old
	colliders (invisible, same size and place).
]]
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local R6 = require(ServerStorage.DevTools.PropsRound6:Clone()) :: any
local L = R6.lib()
local H, M = L.H, L.M
local ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()) :: any
local piece, scaled = H.piece, H.scaled

local R8 = {}

local rgb = Color3.fromRGB
local hex = Color3.fromHex
local rad = math.rad
local TAU = 2 * math.pi

local function bar(list: { BasePart }, a: Vector3, b: Vector3, w: number, h: number, color: Color3)
	local up = if math.abs((b - a).Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	table.insert(list, piece("Part", Vector3.new(w, h, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, up), color))
end

local function polar(r: number, a: number, y: number): Vector3
	return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

-- splits what ringBlocks made: the n blocks in two single-colour groups (so a variant can recolour them); its mortar
-- core is a full disc, which would cover the middle of an open ring: it goes
local function ringSplit(a: { BasePart }, b: { BasePart }, rng: Random, o: any)
	local list = {}
	H.ringBlocks(list, rng, o)
	for i, p in ipairs(list) do
		if i > o.n then
			p:Destroy()
		else
			table.insert(if i % 2 == 0 then a else b, p)
		end
	end
end

-- a soft flat patch of moss (or sand, snow: the variants recolour it)
local function moss(list: { BasePart }, rng: Random, pos: Vector3, size: number)
	ST.blob(list, rng, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), size * 0.5, 0.07, size * rng:NextNumber(0.3, 0.42), function(n: Vector3): Color3
		return if n.Y > 0.4 then hex("5aa646") else hex("3f8a38")
	end, 0.05)
end

local function moveAll(U: any, frame: CFrame)
	for _, list in pairs(U) do
		for _, p in ipairs(list) do
			p.CFrame = frame * p.CFrame
		end
	end
end

local function addLight(m: Model, name: string, y: number, color: Color3, brightness: number, range: number)
	local p = H.plain(m, name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, y, 0), color, { shadow = false }) :: Part
	p.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, false
	light.Parent = p
end

---------------------------------------------------------------------
-- 02 TELEPORT POINT (12 zones, one template, one Variant per zone)
---------------------------------------------------------------------
-- rimA, rimB, core, blockA, blockB, moss, carve, rune, crystal (the Surface takes each zone's HubReturn colour)
local PAD_ZONES: { [string]: { string } } = {
	Plains = { "a8b2c2", "969ca8", "545864", "6f7686", "5f6572", "4c9a3c", "545864", "c8ecff", "8fd8ff" },
	Desert = { "d8b988", "c9a774", "8a6a44", "e2be84", "2c5cc8", "c9a774", "8a6a44", "ffe9b0", "ffd24a" },
	Jungle = { "848a7c", "737a6c", "4c5046", "6b7262", "5f6658", "4c9a3c", "4c5046", "b6ffe0", "7fe8a8" },
	Tundra = { "b9d4ea", "a4c4de", "5a7c9c", "3468b4", "4a80c8", "eaf6ff", "5a7c9c", "e0f6ff", "a8e4ff" },
	Swamp = { "5a6a58", "4e5c4c", "343e34", "46523f", "3c4838", "5e8a3a", "343e34", "b6f4ff", "7fe0d0" },
	Volcano = { "4a4044", "3c3438", "241e22", "2e282c", "38302e", "6a3a2a", "241e22", "ffd9a8", "ff9a3c" },
	Hell = { "5a2e2e", "4a2424", "2a1414", "3a1c1c", "442020", "7a3a2a", "2a1414", "ffd0c0", "ff5c3c" },
	Heaven = { "f0ecdc", "e4dec8", "b8ae90", "d8cfae", "c8bf9e", "ffe9a8", "b8ae90", "e8f8ff", "ffe48a" },
	Dead = { "5c5a66", "4e4c58", "302e38", "3e3c48", "46444f", "6a7a5a", "302e38", "d0e8ff", "9fc8ff" },
	Abyss = { "3a5a6a", "2e4c5c", "18303c", "24404e", "2a4a58", "3cd8d2", "18303c", "c0fff8", "3cd8d2" },
	Mechanical = { "6a7078", "5a6068", "363a42", "4a5058", "525860", "c08a3a", "363a42", "c8f0ff", "5fd4ff" },
	Void = { "3e3450", "322a44", "1c1628", "261f36", "2e2640", "7a5ad0", "1c1628", "d8c8ff", "a07aff" },
}
R8.PAD_ZONES = PAD_ZONES

local function padVariants(m: Model)
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for zone, c in pairs(PAD_ZONES) do
		local v = Instance.new("Configuration")
		v.Name = zone
		for i, name in ipairs({ "RimA", "RimB", "Core", "BlockA", "BlockB", "Moss", "Carve", "Runes", "Crystals" }) do
			v:SetAttribute("Color_" .. name, hex(c[i]))
		end
		v:SetAttribute("Color_Glyphs", hex(c[8]))
		v:SetAttribute("Color_Ripple", hex(c[8]))
		local h = workspace.Zones[zone][zone .. "_1"].HubReturn :: BasePart
		v:SetAttribute("Color_Surface", h.Color)
		v:SetAttribute("Color_SurfaceCore", h.Color:Lerp(Color3.new(1, 1, 1), 0.45))
		v.Parent = folder
	end
	folder.Parent = m
end

function R8.hub_return_pad(): Model
	local m = Instance.new("Model")
	m.Name = "hub_return_pad"
	local rng = Random.new(20261108)
	H.setBevelSelf(true)
	local c = PAD_ZONES.Plains
	local U: any = { RimA = {}, RimB = {}, Core = {}, BlockA = {}, BlockB = {}, Moss = {}, Carve = {}, Runes = {}, Glyphs = {}, Ripple = {}, Crystals = {} }
	-- the ring of cut stone: 14 bevelled blocks low outside, 12 on top a step in
	ringSplit(U.RimA, U.RimB, rng, { n = 14, ro = 5.45, ri = 4.45, y0 = -0.05, h = 0.42, c = 0.1, color = hex(c[2]), H = 1 })
	ringSplit(U.RimA, U.RimB, rng, { n = 12, a0 = 0.13, ro = 4.95, ri = 3.98, y0 = 0.37, h = 0.27, c = 0.1, color = hex(c[1]), H = 1 })
	H.disc16(U.Core, 10.6, 0.16, CFrame.new(0, 0.03, 0), hex(c[3])) -- seen through the joints
	-- carved chevrons on the top of the upper course
	for i = 0, 11 do
		local a = (i + 0.5) * TAU / 12 + 0.13
		local y = 0.65
		bar(U.Carve, polar(4.25, a - 0.09, y), polar(4.62, a, y), 0.09, 0.06, hex(c[7]))
		bar(U.Carve, polar(4.25, a + 0.09, y), polar(4.62, a, y), 0.09, 0.06, hex(c[7]))
	end
	-- the six weathered blocks, on the old stones' places, each with a rune cut in its outer face
	for i = 0, 5 do
		local a = i * TAU / 6
		local pos = polar(5.25, a, 0.62)
		local frame = CFrame.lookAt(pos, Vector3.new(pos.X * 3, 0.62, pos.Z * 3)) * CFrame.Angles(0, rng:NextNumber(-0.14, 0.14), rng:NextNumber(-0.04, 0.04))
		local size = Vector3.new(rng:NextNumber(1.65, 1.85), rng:NextNumber(1.25, 1.45), rng:NextNumber(1.6, 1.75))
		local chip = piece("Part", Vector3.new(0.7, 0.55, 0.7), frame * CFrame.new(size.X / 2, size.Y / 2, rng:NextNumber(-0.7, 0.7)) * CFrame.Angles(0.6, 0.5, 0.3), hex(c[4]))
		local block = H.chamfered(size, frame, hex(c[4]), { "vertical", "topFrontBack", "topSides" }, 0.17, { chip })
		table.insert(if i % 2 == 0 then U.BlockA else U.BlockB, block)
		local z = -size.Z / 2 - 0.01
		local function glyph(x0: number, y0: number, x1: number, y1: number)
			bar(U.Glyphs, (frame * CFrame.new(x0, y0, z)).Position, (frame * CFrame.new(x1, y1, z)).Position, 0.1, 0.06, hex(c[8]))
		end
		glyph(-0.3, -0.3, -0.3, 0.32)
		glyph(-0.3, 0.32, 0.3, 0.05)
		glyph(0.3, 0.05, -0.3, -0.05)
		if i % 2 == 0 then
			glyph(-0.05, -0.1, 0.3, -0.35)
		end
		moss(U.Moss, rng, (frame * CFrame.new(rng:NextNumber(-0.25, 0.25), size.Y / 2 - 0.02, rng:NextNumber(-0.25, 0.25))).Position, rng:NextNumber(0.8, 1.15))
		moss(U.Moss, rng, polar(5.3, a + 0.28, 0.44), rng:NextNumber(0.9, 1.3))
		-- a small crystal cluster at the foot of every second block
		if i % 2 == 1 then
			for k = 0, 2 do
				local p = polar(4.72 + 0.1 * k, a + 0.3 + 0.13 * k, 0.48)
				table.insert(U.Crystals, M.frustumN(6, 0.13 - 0.02 * k, 0.03, 0, 0.75 - 0.16 * k, CFrame.new(p) * CFrame.Angles(0.14 * (k - 1), a, -0.16), { hex(c[9]), hex(c[9]) }))
			end
		end
	end
	-- the rune circle (turns slowly, PropFX): a thin 40-sided line, 8 cut signs inside it
	for i = 0, 39 do
		local a0, a1 = i * TAU / 40, (i + 1.02) * TAU / 40
		bar(U.Runes, polar(3.55, a0, 0.56), polar(3.55, a1, 0.56), 0.1, 0.04, hex(c[8]))
	end
	for i = 0, 7 do
		local a = i * TAU / 8
		local r0, r1 = 2.75, 3.3
		local y = 0.56
		bar(U.Runes, polar(r0, a, y), polar(r1, a, y), 0.09, 0.04, hex(c[8]))
		bar(U.Runes, polar(r1 - 0.12, a, y), polar(r0 + 0.12, a + 0.14 * (if i % 2 == 0 then 1 else -1), y), 0.08, 0.04, hex(c[8]))
		bar(U.Runes, polar(r0 + 0.12, a, y), polar(r1 - 0.2, a - 0.13, y), 0.08, 0.04, hex(c[8]))
	end
	-- ripple lines of the energy disc
	for _, ring in ipairs({ 1.45, 2.3 }) do
		for i = 0, 27 do
			if i % 7 ~= 3 then
				bar(U.Ripple, polar(ring, i * TAU / 28, 0.535), polar(ring, (i + 1.02) * TAU / 28, 0.535), 0.05, 0.03, hex(c[8]))
			end
		end
	end
	H.setBevelSelf(false)
	-- the disc: dark basin, Neon surface (a little transparent, as today's), pale heart
	local basin = H.plain(m, "Basin", Vector3.new(0.12, 8.2, 8.2), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, rad(90)), rgb(34, 58, 130), { shadow = false }) :: Part
	basin.Shape = Enum.PartType.Cylinder
	local surface = H.plain(m, "Surface", Vector3.new(0.1, 8.1, 8.1), CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, rad(90)), hex("4a6cdc"), { material = Enum.Material.Neon, shadow = false }) :: Part
	surface.Shape = Enum.PartType.Cylinder
	surface.Transparency = 0.12
	local core = H.plain(m, "SurfaceCore", Vector3.new(0.06, 3.4, 3.4), CFrame.new(0, 0.53, 0) * CFrame.Angles(0, 0, rad(90)), hex("4a6cdc"):Lerp(Color3.new(1, 1, 1), 0.45), { material = Enum.Material.Neon, shadow = false }) :: Part
	core.Shape = Enum.PartType.Cylinder
	core.Transparency = 0.55
	M.finish(m, "hub_return_pad", U, "RimA", {
		RimA = { single = hex(c[1]) }, RimB = { single = hex(c[2]) }, Core = { single = hex(c[3]) },
		BlockA = { single = hex(c[4]) }, BlockB = { single = hex(c[5]) }, Moss = { single = hex(c[6]), shadow = false },
		Carve = { single = hex(c[7]), shadow = false },
		Runes = { single = hex(c[8]), material = Enum.Material.Neon, shadow = false },
		Glyphs = { single = hex(c[8]), material = Enum.Material.Neon, shadow = false },
		Ripple = { single = hex(c[8]), material = Enum.Material.Neon, transparency = 0.45, shadow = false },
		Crystals = { single = hex(c[9]), material = Enum.Material.Neon, shadow = false },
	})
	padVariants(m)
	return m
end

---------------------------------------------------------------------
-- 03 SPAWN DISC
---------------------------------------------------------------------
-- a sun / compass ray: a flat triangle from radius r0 (half width w) to its tip at radius r, at angle a
local function ray(list: { BasePart }, a: number, r0: number, r: number, w: number, y0: number, y1: number, color: Color3)
	local cf = CFrame.Angles(0, -a, 0)
	local dx = r - r0
	local n = Vector3.new(w, 0, dx).Unit
	local planes = { { -1, 0, 0, -r0 }, { n.X, 0, n.Z, n.X * r }, { n.X, 0, -n.Z, n.X * r } }
	table.insert(list, H.convexSolid(Vector3.new(r0 - 0.02, y0, -w - 0.02), Vector3.new(r + 0.02, y1, w + 0.02), cf, color, planes))
end

function R8.hub_spawn_pad(): Model
	local m = Instance.new("Model")
	m.Name = "hub_spawn_pad"
	local rng = Random.new(20261109)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Top = {}, Carve = {}, Iron = {}, Gold = {}, GoldGlow = {} }
	local dark, mid, light = hex("686e7c"), hex("969ca8"), hex("a3aab7")
	-- double rim: the outer course of cut blocks, a lighter inner one a step higher
	H.ringBlocks(U.Stone, rng, { n = 16, ro = 7.75, ri = 6.35, y0 = -0.2, h = 0.72, c = 0.14, color = dark, H = 1 })
	H.ringBlocks(U.Stone, rng, { n = 12, a0 = 0.2, ro = 6.45, ri = 4.75, y0 = -0.2, h = 0.8, c = 0.12, color = mid, H = 1 })
	-- the centre stone, carved: 12 radial lines, a ring
	H.disc16(U.Top, 9.6, 0.82, CFrame.new(0, 0.21, 0), light)
	for i = 0, 11 do
		local a = (i + 0.5) * TAU / 12
		bar(U.Carve, polar(2.25, a, 0.62), polar(4.72, a, 0.62), 0.07, 0.05, dark)
	end
	for i = 0, 31 do
		bar(U.Carve, polar(3.4, i * TAU / 32, 0.625), polar(3.4, (i + 1.03) * TAU / 32, 0.625), 0.08, 0.05, dark)
	end
	-- 16 ticks on the inner rim, 4 studs on the outer one
	for i = 0, 15 do
		local a = i * TAU / 16 + 0.1
		bar(U.Carve, polar(5.45, a, 0.59), polar(6.1, a, 0.59), 0.08, 0.05, dark)
	end
	for i = 0, 3 do
		local p = polar(7.05, (i + 0.5) * TAU / 4, 0.5)
		table.insert(U.Iron, M.frustumN(8, 0.42, 0.36, -0.03, 0.1, CFrame.new(p), { hex("5c626e"), scaled(hex("5c626e"), 0.9) }))
		table.insert(U.Gold, M.frustumN(8, 0.2, 0.13, 0.09, 0.17, CFrame.new(p), { hex("e2a93a"), hex("c88f2c") }))
	end
	-- the gold emblem, today's size (3.2) and top (0.7), the rays reach a little past it: a sun and a compass
	H.disc16(U.Gold, 3.3, 0.1, CFrame.new(0, 0.64, 0), hex("c88f2c"))
	H.disc16(U.Gold, 3.0, 0.1, CFrame.new(0, 0.67, 0), hex("ffc93c"))
	H.disc16(U.Gold, 1.5, 0.1, CFrame.new(0, 0.7, 0), hex("c88f2c"))
	for i = 0, 7 do
		local long = i % 2 == 0
		ray(U.Gold, i * TAU / 8 + rad(22.5), 0.45, if long then 2.15 else 1.65, if long then 0.32 else 0.26, 0.68, 0.76, if long then hex("ffd84a") else hex("e2a93a"))
	end
	H.disc16(U.GoldGlow, 1.05, 0.08, CFrame.new(0, 0.77, 0), hex("ffe68a"))
	H.setBevelSelf(false)
	M.finish(m, "hub_spawn_pad", U, "Stone", { Carve = { shadow = false }, Iron = { shadow = false }, Gold = { shadow = false }, GoldGlow = { material = Enum.Material.Neon, single = hex("ffe68a"), shadow = false } })
	addLight(m, "GlowLight", 1.2, hex("ffd884"), 0.6, 9)
	return m
end

---------------------------------------------------------------------
-- 04 ROUND PLANTER (two designs; today's Rim and Soil stay as invisible colliders)
---------------------------------------------------------------------
-- The templates' local X is up (the copies stand on a Cylinder's axis): built Y-up from the ground, then turned.
local PLANTER_FRAME = CFrame.Angles(0, 0, rad(-90)) * CFrame.new(0, -2.1, 0)

-- a real bush: round leaf clusters in 3 layers (dark at the foot, light on top), single leaves standing out of them
local function bush(U: any, rng: Random, center: Vector3, radius: number, height: number)
	local function cluster(pos: Vector3, r: number, base: Color3)
		L.TB.lump(U.Leaves, rng, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), r, r * 0.78, r * rng:NextNumber(0.85, 1), function(n: Vector3): Color3
			local k = if n.Y > 0.5 then 1.12 elseif n.Y > -0.1 then 1 else 0.82
			return scaled(base, k * rng:NextNumber(0.96, 1.03))
		end, r * 0.6)
	end
	local n = math.max(5, math.round(radius * 3.4))
	for i = 0, n - 1 do
		local a = i * TAU / n + rng:NextNumber(-0.2, 0.2)
		cluster(center + polar(radius * 0.78, a, height * 0.3 + rng:NextNumber(-0.06, 0.06)), radius * rng:NextNumber(0.44, 0.52), hex("2f8a30"))
	end
	local m2 = math.max(3, n - 2)
	for i = 0, m2 - 1 do
		local a = i * TAU / m2 + 0.5 + rng:NextNumber(-0.2, 0.2)
		cluster(center + polar(radius * 0.46, a, height * 0.62 + rng:NextNumber(-0.06, 0.06)), radius * rng:NextNumber(0.4, 0.48), hex("3fa33a"))
	end
	cluster(center + Vector3.new(rng:NextNumber(-0.1, 0.1), height * 0.92, rng:NextNumber(-0.1, 0.1)), radius * 0.46, hex("5cc04a"))
	for _ = 1, math.round(radius * 8) do
		local a = rng:NextNumber(0, TAU)
		local t = rng:NextNumber(0.2, 1)
		local pos = center + polar(radius * (1.1 - 0.75 * t), a, height * t + 0.1)
		ST.blob(U.Stems, rng, CFrame.new(pos) * CFrame.Angles(0, -a, rng:NextNumber(0.2, 0.7)), 0.3, 0.06, 0.15, function(v: Vector3): Color3
			return if v.Y > 0 then hex("74d054") else hex("4aa83c")
		end)
	end
end

local function flower(U: any, rng: Random, base: Vector3, height: number, color: Color3)
	local top = base + Vector3.new(rng:NextNumber(-0.14, 0.14), height, rng:NextNumber(-0.14, 0.14))
	bar(U.Stems, base, top, 0.09, 0.09, hex("3f9e36"))
	local a = rng:NextNumber(0, TAU)
	local tilt = CFrame.new(top) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), a, rng:NextNumber(-0.25, 0.25))
	table.insert(U.Blooms, M.frustumN(5, 0.42, 0.2, -0.05, 0.1, tilt, { color, scaled(color, 0.88) }))
	table.insert(U.Blooms, M.frustumN(5, 0.2, 0.34, -0.2, -0.05, tilt, { scaled(color, 0.8), scaled(color, 0.72) }))
	table.insert(U.Blooms, M.frustumN(6, 0.13, 0.06, 0.09, 0.17, tilt, { hex("ffe07a"), hex("e8b83c") }))
	for k = 1, 2 do
		local b = a + k * 2.4
		local leafBase = base + (top - base) * (0.3 + 0.18 * k)
		ST.blob(U.Stems, rng, CFrame.new(leafBase + Vector3.new(math.cos(b) * 0.24, 0.05, math.sin(b) * 0.24)) * CFrame.Angles(0, -b, 0.35), 0.32, 0.07, 0.13, function(n: Vector3): Color3
			return if n.Y > 0 then hex("55b846") else hex("3f9e36")
		end)
	end
end

local function tuft(U: any, rng: Random, base: Vector3)
	for k = 0, 3 do
		local a = rng:NextNumber(0, TAU)
		local h = rng:NextNumber(0.5, 0.85)
		table.insert(U.Grass, piece("WedgePart", Vector3.new(0.05, h, 0.26), CFrame.new(base + Vector3.new(math.cos(a) * 0.12, h / 2, math.sin(a) * 0.12)) * CFrame.Angles(0, a + k, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.2, 0.2)), if k % 2 == 0 then hex("63c64a") else hex("4aa83c")))
	end
end

local function pebble(U: any, rng: Random, pos: Vector3)
	local k = rng:NextNumber(0.17, 0.3)
	ST.blob(U.Pebbles, rng, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), k, k * 0.7, k * rng:NextNumber(0.8, 1.1), function(n: Vector3): Color3
		return if n.Y > 0.3 then hex("a3aab7") else hex("7c8290")
	end, k * 0.3)
end

local function planter(id: string, seed: number, plant: (any, Random, number) -> ()): Model
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(seed)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Soil = {}, Leaves = {}, Stems = {}, Blooms = {}, Grass = {}, Pebbles = {} }
	-- darker base course, the wall of cut blocks, a bevelled cap
	H.ringBlocks(U.Stone, rng, { n = 10, ro = 4.56, ri = 3.5, y0 = 0, h = 0.36, c = 0.12, color = hex("5f6572"), H = 2 })
	H.ringBlocks(U.Stone, rng, { n = 11, a0 = 0.2, ro = 4.42, ri = 3.5, y0 = 0.36, h = 0.82, c = 0.05, color = hex("969ca8"), H = 2 })
	H.ringBlocks(U.Stone, rng, { n = 12, a0 = 0.1, ro = 4.66, ri = 3.42, y0 = 1.18, h = 0.44, c = 0.14, color = hex("a3aab7"), H = 2 })
	-- rich soil, a little mounded
	local soilTop = 1.72
	H.disc16(U.Soil, 7.1, 0.5, CFrame.new(0, soilTop - 0.25, 0), hex("4a3424"))
	for _ = 1, 7 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(0.8, 3)
		local k = rng:NextNumber(0.55, 0.95)
		ST.blob(U.Soil, rng, CFrame.new(polar(r, a, soilTop)), k, 0.16, k, function(n: Vector3): Color3
			return if n.Y > 0.4 then hex("5c4130") else hex("4a3424")
		end, 0.05)
	end
	plant(U, rng, soilTop)
	for _ = 1, 6 do
		pebble(U, rng, polar(rng:NextNumber(2.2, 3.2), rng:NextNumber(0, TAU), soilTop + 0.04))
	end
	for _ = 1, 6 do
		tuft(U, rng, polar(rng:NextNumber(2.2, 3.25), rng:NextNumber(0, TAU), soilTop))
	end
	moveAll(U, PLANTER_FRAME)
	H.setBevelSelf(false)
	-- today's two cylinders, invisible, same size and place: the collisions do not change
	local old = ServerStorage.MapProps:FindFirstChild(id) or (ServerStorage.MapProps:FindFirstChild("_Previous") :: any):FindFirstChild(id)
	for _, name in ipairs({ "Rim", "Soil" }) do
		local src = old:FindFirstChild("Collision" .. name) or old:FindFirstChild(name)
		if src and src:IsA("PartOperation") then -- a rebuild after the broken one: the original is in _Previous or gone
			error("planter: the original " .. name .. " is missing")
		end
		local copy = src:Clone() :: BasePart
		copy.Name = "Collision" .. name
		copy.Transparency = 1
		copy.CastShadow = false
		copy.Parent = m
	end
	M.finish(m, id, U, "Stone", { Pebbles = { shadow = false }, Grass = { shadow = false }, Stems = { shadow = false } })
	return m
end

-- a real bush in the middle, 7 flowers around it
function R8.hub_furniture_planter(): Model
	return planter("hub_furniture_planter", 20261110, function(U: any, rng: Random, y: number)
		bush(U, rng, Vector3.new(0, y, 0), 1.5, 1.95)
		local colors = { "ffd646", "ff5c78", "a06eff", "ffd646", "ff5c78", "a06eff", "ff5c78" }
		for i, c in ipairs(colors) do
			local a = i * TAU / #colors + rng:NextNumber(-0.15, 0.15)
			flower(U, rng, polar(rng:NextNumber(2.6, 3.1), a, y), rng:NextNumber(1.1, 1.75), hex(c))
		end
	end)
end

-- two low bushes either side, a taller bed of flowers between them
function R8.hub_furniture_planter_v2(): Model
	return planter("hub_furniture_planter_v2", 20261111, function(U: any, rng: Random, y: number)
		for _, side in ipairs({ { -1.55, 0.5, 1 }, { 1.6, -0.5, 0.94 } }) do
			bush(U, rng, Vector3.new(side[1], y, side[2]), 1.25, 1.35)
		end
		local colors = { "a06eff", "ffd646", "a06eff", "ff5c78", "ffd646", "a06eff", "ff5c78", "ffd646" }
		for i, c in ipairs(colors) do
			local t = (i - 1) / (#colors - 1)
			flower(U, rng, Vector3.new(rng:NextNumber(-0.5, 0.5), y, -2.7 + t * 5.4), rng:NextNumber(1.3, 2.05), hex(c))
		end
	end)
end

---------------------------------------------------------------------
-- 05 RAIL END + THE MINE RAILS
---------------------------------------------------------------------
local WOOD, WOOD_LIGHT = hex("703e26"), hex("a86238")
local IRON, RUST = hex("5c626e"), hex("9a5230")

-- a bolt head + washer on a face (normal n)
local function bolt(U: any, pos: Vector3, n: Vector3)
	local cf = CFrame.lookAt(pos, pos + n) * CFrame.Angles(rad(-90), 0, 0)
	table.insert(U.Iron, M.frustumN(6, 0.13, 0.1, -0.02, 0.1, cf, { IRON, scaled(IRON, 0.85) }))
end

-- Front of the stop = local -Z (the rails come from there), back = +Z. Today's block is 6 x 3 x 1.5, y 0..3.
function R8.plains_rail_buffer(): Model
	local m = Instance.new("Model")
	m.Name = "plains_rail_buffer"
	local rng = Random.new(20261112)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Rust = {}, Stone = {}, Pebbles = {} }
	local function beam(size: Vector3, cf: CFrame, color: Color3)
		table.insert(U.Wood, H.chamfered(size, cf, color, { "vertical", "topFrontBack", "bottomFrontBack", "topSides" }, 0.1))
	end
	-- the thick end beam (a plank below it), two posts behind, braces down to two stone blocks
	beam(Vector3.new(6.3, 1.25, 1.35), CFrame.new(0, 2.25, 0), WOOD)
	beam(Vector3.new(5.5, 0.72, 1.1), CFrame.new(0, 1.25, 0.05), scaled(WOOD_LIGHT, 0.82))
	for _, x in ipairs({ -2.15, 2.15 }) do
		beam(Vector3.new(1, 3.25, 1), CFrame.new(x, 1.6, 1.1) * CFrame.Angles(0, x * 0.02, 0), scaled(WOOD_LIGHT, 0.9))
		beam(Vector3.new(0.62, 0.62, 2.7), CFrame.new(x, 1.2, 2.08) * CFrame.Angles(rad(52), 0, 0), WOOD)
		table.insert(U.Stone, H.chamfered(Vector3.new(1.6, 0.72, 1.5), CFrame.new(x, 0.32, 2.75) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), hex("7c8290"), { "vertical", "topFrontBack", "topSides" }, 0.13))
		-- bracket: a strap round the beam and the post, 4 bolts
		table.insert(U.Iron, piece("Part", Vector3.new(0.72, 1.5, 0.08), CFrame.new(x, 2.25, -0.72), IRON))
		table.insert(U.Iron, piece("Part", Vector3.new(0.72, 0.08, 2.1), CFrame.new(x, 2.92, 0.3), IRON))
		table.insert(U.Iron, piece("Part", Vector3.new(0.72, 0.08, 2.1), CFrame.new(x, 1.58, 0.3), IRON))
		for _, y in ipairs({ 1.8, 2.7 }) do
			bolt(U, Vector3.new(x - 0.22, y, -0.76), -Vector3.zAxis)
			bolt(U, Vector3.new(x + 0.22, y, -0.76), -Vector3.zAxis)
		end
		table.insert(U.Rust, piece("Part", Vector3.new(0.36, 0.5, 0.04), CFrame.new(x + 0.12, 1.86, -0.77) * CFrame.Angles(0, 0, 0.3), RUST))
		table.insert(U.Rust, piece("Part", Vector3.new(0.3, 0.05, 0.6), CFrame.new(x - 0.1, 2.97, 0.1) * CFrame.Angles(0, 0.4, 0), RUST))
		-- the spring buffer in front of the beam, on the rail line: a rod, 3 coils, a round plate
		local cx = x * 0.72
		local axis = CFrame.new(cx, 2.2, -0.68) * CFrame.Angles(rad(-90), 0, 0)
		table.insert(U.Iron, M.frustumN(8, 0.14, 0.14, 0, 0.74, axis, { IRON, scaled(IRON, 0.9) }))
		for k = 0, 2 do
			table.insert(U.Rust, M.frustumN(8, 0.3, 0.3, 0.08 + 0.2 * k, 0.17 + 0.2 * k, axis, { scaled(RUST, 0.9), scaled(RUST, 0.75) }))
		end
		table.insert(U.Iron, M.frustumN(8, 0.52, 0.46, 0.66, 0.8, axis, { IRON, scaled(IRON, 0.85) }))
	end
	-- a dark iron band along the beam, wear marks on the front
	table.insert(U.Iron, piece("Part", Vector3.new(6.36, 0.14, 1.42), CFrame.new(0, 2.25, 0), scaled(IRON, 0.8)))
	for _ = 1, 4 do
		local x = rng:NextNumber(-2.6, 2.6)
		table.insert(U.Rust, piece("Part", Vector3.new(rng:NextNumber(0.3, 0.7), 0.06, 0.04), CFrame.new(x, rng:NextNumber(1.8, 2.7), -0.69) * CFrame.Angles(0, 0, rng:NextNumber(-0.3, 0.3)), scaled(WOOD, 0.62)))
	end
	for _ = 1, 8 do
		local k = rng:NextNumber(0.13, 0.26)
		ST.blob(U.Pebbles, rng, CFrame.new(rng:NextNumber(-3, 3), 0.06, rng:NextNumber(-1.1, 2.9)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), k, k * 0.65, k, function(n: Vector3): Color3
			return if n.Y > 0.3 then hex("868c9a") else hex("646a76")
		end, k * 0.2)
	end
	H.setBevelSelf(false)
	M.finish(m, "plains_rail_buffer", U, "Wood", { Rust = { shadow = false }, Pebbles = { shadow = false } })
	-- the old block's collision, invisible
	local c = H.plain(m, "Collision", Vector3.new(6, 3, 1.5), CFrame.new(0, 1.5, 0), rgb(163, 162, 165), { collide = true, shadow = false }) :: Part
	c.Transparency = 1
	return m
end

-- Same sleepers (places, sizes), same rail line and top: worn ties, rails with foot / web / head, plates and spikes.
function R8.plains_bridge_rail_section(): Model
	local m = Instance.new("Model")
	m.Name = "plains_bridge_rail_section"
	local rng = Random.new(20261113)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Rust = {} }
	for i, z in ipairs({ -8.6, -5.73, -2.86, 0.01, 2.88, 5.75, 8.62 }) do
		local color = if i % 3 == 2 then WOOD_LIGHT else WOOD
		local cf = CFrame.new(rng:NextNumber(-0.06, 0.06), 0.25, z) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0)
		local crack = piece("Part", Vector3.new(rng:NextNumber(0.9, 1.6), 0.2, 0.1), cf * CFrame.new(rng:NextNumber(-1.8, 1.8), 0.24, rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0), scaled(color, 0.6))
		table.insert(U.Wood, H.chamfered(Vector3.new(5.2, 0.5, 1.3), cf, scaled(color, rng:NextNumber(0.9, 1.04)), { "vertical", "topFrontBack", "topSides" }, 0.07, { crack }))
		for _, x in ipairs({ -1.6, 1.6 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(1.05, 0.05, 0.72), CFrame.new(x, 0.52, z), scaled(IRON, 0.82)))
			for _, side in ipairs({ -1, 1 }) do
				table.insert(U.Iron, M.frustumN(4, 0.08, 0.06, 0.53, 0.62, CFrame.new(x + side * 0.38, 0, z + side * 0.2), { IRON, scaled(IRON, 0.8) }))
			end
			if rng:NextNumber() < 0.45 then
				table.insert(U.Rust, piece("Part", Vector3.new(0.3, 0.02, 0.4), CFrame.new(x + rng:NextNumber(-0.32, 0.32), 0.555, z + rng:NextNumber(-0.14, 0.14)), RUST))
			end
		end
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		table.insert(U.Iron, piece("Part", Vector3.new(0.45, 0.09, 20), CFrame.new(x, 0.59, 0), scaled(IRON, 0.9)))
		table.insert(U.Iron, piece("Part", Vector3.new(0.14, 0.27, 20), CFrame.new(x, 0.77, 0), scaled(IRON, 0.8)))
		table.insert(U.Iron, piece("Part", Vector3.new(0.3, 0.14, 20), CFrame.new(x, 0.93, 0), IRON))
		-- the fish plate at the joint (mid-length), 4 bolts, rust along the head
		for _, side in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.05, 0.22, 1.5), CFrame.new(x + side * 0.1, 0.77, 0), scaled(IRON, 0.7)))
			for _, z in ipairs({ -0.5, 0.5 }) do
				bolt(U, Vector3.new(x + side * 0.13, 0.77, z), Vector3.xAxis * side)
			end
		end
		for _ = 1, 3 do
			table.insert(U.Rust, piece("Part", Vector3.new(0.17, 0.02, rng:NextNumber(0.9, 2.4)), CFrame.new(x, 0.81, rng:NextNumber(-8, 8)), RUST))
		end
	end
	H.setBevelSelf(false)
	M.finish(m, "plains_bridge_rail_section", U, "Iron", { Rust = { shadow = false } })
	return m
end

function R8.build(id: string): string
	local model = (R8 :: any)[id]() :: Model
	R6.install(id, model)
	local tris = 0
	local parts = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("PartOperation") then
				tris += d.TriangleCount
			end
		end
	end
	return `{id}: {parts} parts, {tris} union triangles, {model:GetExtentsSize()}`
end

---------------------------------------------------------------------
-- COPIES
---------------------------------------------------------------------
local function copyOf(id: string, name: string, parent: Instance, cf: CFrame, variant: string?, zone: string): Model
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = (ServerStorage.MapProps :: any)[id]:Clone() :: Model
	m.Name = name
	local variants = m:FindFirstChild("_Variants")
	if variants then
		variants:Destroy()
	end
	m:PivotTo(cf)
	m:SetAttribute("MapPropId", id)
	m:SetAttribute("Zone", zone)
	if variant then
		m:SetAttribute("Variant", variant)
	end
	CollectionService:AddTag(m, "MapProp")
	m.Parent = parent
	return m
end

-- one copy on each HubReturn; the old stones and base stay as invisible colliders, the old rims go
function R8.placePads(): string
	local n, hidden, removed = 0, 0, 0
	for zone in pairs(PAD_ZONES) do
		local sub = workspace.Zones[zone][zone .. "_1"]
		local h = sub.HubReturn :: BasePart
		local decor = sub:FindFirstChild("Decor")
		local parent = decor:FindFirstChild("HubReturnDecor") or decor
		local ground = h.Position.Y - h.Size.X / 2
		copyOf("hub_return_pad", "HubReturn_Point", parent, CFrame.new(h.Position.X, ground, h.Position.Z), zone, zone)
		h.Transparency = 1
		n += 1
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("BasePart") then
				if c.Name == "PadStone" or c.Name == "PadBase" then
					c.Transparency = 1
					c.CastShadow = false
					c.Name = "PadCollision"
					hidden += 1
				elseif c.Name == "PadRim" or c.Name == "PadRing" then
					c:Destroy()
					removed += 1
				end
			end
		end
	end
	return `pads: {n} placed, {hidden} old parts now invisible colliders, {removed} old rims removed`
end

function R8.placeSpawn(): string
	local plaza = workspace.Hub.Decor.Plaza
	for _, name in ipairs({ "SpawnPadBase", "SpawnPadTop", "SpawnPadGem" }) do
		local p = plaza[name] :: BasePart
		p.Transparency = 1
		p.CastShadow = false
	end
	copyOf("hub_spawn_pad", "SpawnPad", plaza, CFrame.new(0, 0, -50), nil, "Hub")
	return "spawn pad placed"
end

function R8.placeBuffer(): string
	local mine = workspace.Zones.Plains.Plains_4.Decor.Mine
	local old = mine:FindFirstChild("RailBuffer")
	if old and old:IsA("BasePart") then
		old:Destroy()
	end
	copyOf("plains_rail_buffer", "RailBuffer", mine, CFrame.new(2000, 0, 871.5), nil, "Plains")
	return "rail buffer placed"
end

return R8
