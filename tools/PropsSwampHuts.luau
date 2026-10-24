--[[
	PropsSwampHuts (dev tool, Edit mode only) - the owner's "CURSED SWAMP PROP IMPROVEMENT - Buildings and huts"
	(2026-10-24): 01 the stilt hut with the green roof (kit MapAssets.Swamp.Stilt_Cabin_A) and 02 the witch hut with the
	purple hat (Stilt_Cabin_B) to the fountain / well quality in the cursed swamp look (docs/prop_texture_guide.md
	sections A and F), keeping each object's colours, glow points, place, size and collision. Source of truth:
	tools/PropsSwampHuts.luau. Inventory: docs/prop_inventory.md "Swamp huts".

	BASE: the jungle stilt hut (DevTools.PropsJungleBuildings, Jungle.stilt_hut): the same recipe (8-sided log stilts
	with rope ties and cross braces, a plank deck on rim beams, framed plank walls with corner posts and lashed bands, a
	planked door in a wooden frame, a railed ladder with round rungs, a framed lantern, moss and vines from the jungle
	helpers) fitted to the swamp kits' parts and turned swampy: darker rotten planks with cracks and damp feet, layered
	moss (soft rounded mats in #3F7A2C with a lighter #5B852D top layer and drips; the jungle vines recoloured),
	hanging moss, algae and mud at the water line, iron straps and rings, ghost mushrooms (#BFF5F0, not Neon).

	Collision: the visible unions never collide. Every part that collides today is an invisible "Collision" part (same
	class, shape, size and place, from the kit rows below). The ladders do not collide today (rails and rungs are
	CanCollide and CanQuery false) and they still do not. 01's 2 roof planes differ on 4 village copies: the template
	carries every roof collider the copies need and its _Variants (RoofSplit, RoofWide) switch the right ones on.
	Glow: Neon only on today's glow points (the window, the lantern) in today's colours; no light is added.

	It uses DevTools.PropsTundraBuildings (and through it the jungle helpers, finish() and frustumN) and registers its
	builders into the same PropsBatch2 table:
		local SH = require(game.ServerStorage.DevTools.PropsSwampHuts:Clone())
		print(SH.install("swamp_stilt_hut"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "swamp_stilt_hut" } }), Sync.run({ only = { "swamp_stilt_hut" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local TB = require(ServerStorage.DevTools.PropsTundraBuildings:Clone()) :: any
local B2, H, M = TB.B2, TB.H, TB.M
local J = TB.Nat.Dc.T.R.G.J -- DevTools.PropsJungleBuildings (the base stilt hut and its moss / vine helpers)
local piece, chamfered = H.piece, H.chamfered
local scaled = H.scaled
local frustumN = M.frustumN
local lump, lashing = TB.lump, TB.lashing

local SH = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

-- the swamp palette (guide F1): the kits' real colours are read from the rows; these are the new accents
local MUD_DARK = rgb(58, 42, 28) -- #3A2A1C dark mud
local BLACKWOOD = rgb(42, 30, 26) -- #2A1E1A near-black wood (cracks, cores)
local MOSS = rgb(63, 122, 44) -- #3F7A2C
local MOSS_MID = rgb(76, 138, 51) -- #4C8A33
local OLIVE = rgb(142, 154, 46) -- #8E9A2E
local VINE = rgb(58, 108, 40)
local WATER = rgb(30, 74, 79) -- #1E4A4F dark teal water
local BONE = rgb(242, 228, 192) -- #F2E4C0
local GHOST = rgb(191, 245, 240) -- #BFF5F0 ghost mushroom caps
local GHOST_UNDER = rgb(143, 216, 208)
local IRON = rgb(92, 98, 110) -- #5C626E
local MAGIC = rgb(122, 43, 200) -- #7A2BC8
local MAGENTA = rgb(232, 58, 232) -- #E83AE8
local BRASS = rgb(184, 150, 46)
local STRAW = rgb(184, 154, 90)
local HANDLE = rgb(122, 92, 60)

SH.COLORS = { MUD_DARK = MUD_DARK, BLACKWOOD = BLACKWOOD, MOSS = MOSS, MOSS_MID = MOSS_MID, OLIVE = OLIVE, WATER = WATER, BONE = BONE, GHOST = GHOST, IRON = IRON }

---------------------------------------------------------------------
-- the kits as they were before the remake (ServerStorage.MapAssets.Swamp, read 2026-10-24; every copy is the kit at
-- Model scale 1). One row per part: { name, class, shape, sx, sy, sz, the 12 CFrame components (kit pivot space), hex,
-- collide, transparency, material, query }; rows sorted by name, then X, Y, Z
---------------------------------------------------------------------
local Data = {}

Data.Stilt_Cabin_A = {
	{ "Body", "Part", "Block", 13, 10, 11, 0.0383202136, 12.793148, 1, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "5e4531", true, 0, "SmoothPlastic", true },
	{ "Chimney", "Part", "Block", 1.70000005, 1.70000005, 7.60718393, 3.50707412, 23.9900341, 4.19999981, 0, 0.994664788, -0.103159301, 0.0566627681, -0.102993563, -0.993066728, -0.998393357, -0.00584529154, -0.0563604608, "596864", true, 0, "SmoothPlastic", true },
	{ "Deck", "Part", "Block", 18, 0.800000012, 16, 0, 7.4000001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true, 0, "SmoothPlastic", true },
	{ "Door", "Part", "Block", 6, 9, 0.400000006, -1.93277097, 12.1891613, -4.5999999, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true },
	{ "Facet", "WedgePart", "", 0.600000024, 6.40000057, 6.50000095, -3.63638043, 20.8118172, -4.5, 0, -0.0523361824, 0.99862951, 0, 0.99862951, 0.0523361824, -1, 0, 0, "58412f", true, 0, "SmoothPlastic", true },
	{ "Facet", "WedgePart", "", 0.600000024, 6.40000057, 6.50000095, -3.63638043, 20.8118172, 5.89999962, 0, -0.0523361824, 0.99862951, 0, 0.99862951, 0.0523361824, -1, 0, 0, "58412f", true, 0, "SmoothPlastic", true },
	{ "Facet", "WedgePart", "", 0.600000024, 6.40000057, 6.49999809, 2.85471129, 21.1520023, -4.5, 0, -0.0523361824, -0.99862951, 0, 0.99862951, -0.0523361824, 1, 0, 0, "58412f", true, 0, "SmoothPlastic", true },
	{ "Facet", "WedgePart", "", 0.600000024, 6.40000057, 6.49999809, 2.85471129, 21.1520023, 5.89999962, 0, -0.0523361824, -0.99862951, 0, 0.99862951, -0.0523361824, 1, 0, 0, "58412f", true, 0, "SmoothPlastic", true },
	{ "LadderRail", "Part", "Block", 0.400000006, 0.400000006, 9.85087872, -2.9000001, 4.5, -10.1499996, -1, 0, 0, 0, 0.380232751, -0.924890757, 0, -0.924890757, -0.380232751, "322620", false, 0, "SmoothPlastic", false },
	{ "LadderRail", "Part", "Block", 0.400000006, 0.400000006, 9.85087872, -0.5, 4.5, -10.1499996, -1, 0, 0, 0, 0.380232751, -0.924890757, 0, -0.924890757, -0.380232751, "322620", false, 0, "SmoothPlastic", false },
	{ "Lantern", "Part", "Block", 0.899999976, 1.20000005, 0.899999976, 1.86810422, 16.0934334, -5.30000019, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "ffc460", false, 0, "Neon", true },
	{ "Part", "Part", "Block", 7, 0.600000024, 0.600000024, -2.18398356, 16.9825821, -4.6500001, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "816a52", true, 0, "SmoothPlastic", true },
	{ "Part", "Part", "Block", 0.899999976, 0.899999976, 14.5, -0.568776906, 24.3772507, 1, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true },
	{ "Part", "Part", "Block", 0.300000012, 0.300000012, 1.20000005, 1.82623529, 16.8923378, -4.9000001, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false },
	{ "Roof", "Part", "Block", 11, 0.800000012, 13.5, -4.2540884, 20.1786232, 1, 0.629320323, -0.777145982, 0, 0.777145982, 0.629320323, 0, 0, 0, 1, "354027", true, 0, "SmoothPlastic", true },
	{ "Roof", "Part", "Block", 11, 0.800000012, 13.5, 3.53522205, 20.5868416, 1, 0.707106769, 0.707106829, 0, -0.707106829, 0.707106769, 0, 0, 0, 1, "3c4d2a", true, 0, "SmoothPlastic", true },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, -1.70000005, 1.86000001, -11.2600002, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, -1.70000005, 3.42000008, -10.5200005, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, -1.70000005, 4.98000002, -9.77999973, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, -1.70000005, 6.53999996, -9.03999996, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Stilt", "Part", "Block", 1.20000005, 1.20000005, 9.15374756, -6.9000001, 2.8499999, -6, -0.624695122, -0.772544086, -0.113717154, 0, 0.145629019, -0.989339232, 0.780868769, -0.618035376, -0.0909737423, "322620", true, 0, "SmoothPlastic", true },
	{ "Stilt", "Part", "Block", 1.20000005, 1.20000005, 9.15374756, -6.9000001, 2.8499999, 6, 0.624695122, -0.772544086, -0.113717154, 0, 0.145629019, -0.989339232, 0.780868769, 0.618035376, 0.0909737423, "4e3a2c", true, 0, "SmoothPlastic", true },
	{ "Stilt", "Part", "Block", 1.20000005, 1.20000005, 9.15374756, 6.9000001, 2.8499999, -6, -0.624695122, 0.772544086, 0.113717154, 0, 0.145629019, -0.989339232, -0.780868769, -0.618035376, -0.0909737423, "4e3a2c", true, 0, "SmoothPlastic", true },
	{ "Stilt", "Part", "Block", 1.20000005, 1.20000005, 9.15374756, 6.9000001, 2.8499999, 6, 0.624695122, 0.772544086, 0.113717154, 0, 0.145629019, -0.989339232, -0.780868769, 0.618035376, 0.0909737423, "322620", true, 0, "SmoothPlastic", true },
	{ "Window", "Part", "Cylinder", 0.5, 3, 3, 3.78077626, 13.990654, -4.5999999, -4.36514824e-08, -0.0523359589, 0.99862951, -2.28767738e-09, 0.99862951, 0.0523359589, -1, 0, -4.37113883e-08, "ffc460", true, 0, "Neon", true },
	{ "WindowFrame", "Part", "Cylinder", 0.5, 3.79999995, 3.79999995, 3.78077626, 13.990654, -4.44999981, -4.36514824e-08, -0.0523359589, 0.99862951, -2.28767738e-09, 0.99862951, 0.0523359589, -1, 0, -4.37113883e-08, "322620", true, 0, "SmoothPlastic", true },
}

Data.Stilt_Cabin_B = {
	{ "Body", "Part", "Block", 10, 12, 9, 0.118538797, 15.7853851, 0.5, 0.997564077, 0.0697564706, 0, -0.0697564706, 0.997564077, 0, 0, 0, 1, "57402e", true, 0, "SmoothPlastic", true },
	{ "Deck", "Part", "Block", 14, 0.800000012, 14, 0, 9.39999962, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true, 0, "SmoothPlastic", true },
	{ "Door", "Part", "Block", 6, 9, 0.400000006, 0.0139040947, 14.2890387, -4.0999999, 0.997564077, 0.0697564706, 0, -0.0697564706, 0.997564077, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true },
	{ "LadderRail", "Part", "Block", 0.400000006, 0.400000006, 11.8945484, -1.20000005, 5.5, -9.39999962, -1, 0, 0, 0, 0.356701463, -0.934218407, 0, -0.934218407, -0.356701463, "322620", false, 0, "SmoothPlastic", false },
	{ "LadderRail", "Part", "Block", 0.400000006, 0.400000006, 11.8945484, 1.20000005, 5.5, -9.39999962, -1, 0, 0, 0, 0.356701463, -0.934218407, 0, -0.934218407, -0.356701463, "322620", false, 0, "SmoothPlastic", false },
	{ "Lantern", "Part", "Block", 0.899999976, 1.20000005, 0.899999976, -3.77405834, 17.4610004, -4.80000019, 0.997564077, 0.0697564706, 0, -0.0697564706, 0.997564077, 0, 0, 0, 1, "ffc460", false, 0, "Neon", true },
	{ "Part", "Part", "Block", 0.300000012, 0.300000012, 1.20000005, -3.71825314, 18.2590523, -4.4000001, 0.997564077, 0.0697564706, 0, -0.0697564706, 0.997564077, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false },
	{ "Part", "Part", "Block", 0.600000024, 0.600000024, 12.629899, -0.100000143, 4.5, -5.69999981, -0.0175411459, -0.401547939, -0.915670037, 0, 0.915811062, -0.401609689, 0.99984622, -0.00704469392, -0.0160643719, "322620", false, 0, "SmoothPlastic", false },
	{ "Part", "Part", "Block", 7, 0.600000024, 0.600000024, 0.348735154, 19.0773468, -4.1500001, 0.997564077, 0.0697564706, 0, -0.0697564706, 0.997564077, 0, 0, 0, 1, "816a52", true, 0, "SmoothPlastic", true },
	{ "Roof", "Part", "Block", 13.5, 0.800000012, 12.5, 0.564980209, 22.1697941, 0.5, 0.997564077, 0.0697564706, 0, -0.0697564706, 0.997564077, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true },
	{ "Roof", "Part", "Block", 9.5, 3.5999999, 8.60000038, 0.711468756, 24.264679, 0.5, 1.00000012, 0, 0, 0, 1.00000012, 0, 0, 0, 1, "472859", true, 0, "SmoothPlastic", true },
	{ "Roof", "Part", "Block", 6.80000019, 3.5999999, 6.19999981, 1.43347168, 27.4220085, 0.5, 0.978147626, 0.2079117, 0, -0.2079117, 0.978147626, 0, 0, 0, 1, "532d6d", true, 0, "SmoothPlastic", true },
	{ "Roof", "Part", "Block", 4.19999981, 3.5999999, 3.79999995, 2.54054856, 30.3519211, 0.5, 0.927183867, 0.374606609, 0, -0.374606609, 0.927183867, 0, 0, 0, 1, "472859", true, 0, "SmoothPlastic", true },
	{ "Roof", "Part", "Block", 2.20000005, 3.5999999, 2, 4.21826172, 32.84095, 0.5, 0.809017003, 0.587785244, 0, -0.587785244, 0.809017003, 0, 0, 0, 1, "532d6d", true, 0, "SmoothPlastic", true },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, 0, 2.25999999, -10.6599998, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, 0, 4.21999979, -9.81999969, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, 0, 6.17999983, -8.97999954, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Rung", "Part", "Block", 2.5999999, 0.300000012, 0.300000012, 0, 8.14000034, -8.14000034, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.0896463, -5.80000019, 3.8499999, -5.80000019, 0, 0.99723196, -0.0743518993, 0.0745582655, -0.0741449445, -0.99445641, -0.997216582, -0.00554354861, -0.0743518993, "4e3a2c", true, 0, "SmoothPlastic", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.0896463, -5.80000019, 3.8499999, 5.80000019, 0, 0.99723196, -0.0743518993, -0.0745582655, -0.0741449445, -0.99445641, -0.997216582, 0.00554354861, 0.0743518993, "322620", true, 0, "SmoothPlastic", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.0896463, 5.80000019, 3.8499999, -5.80000019, 0, 0.99723196, 0.0743518993, 0.0745582655, 0.0741449445, -0.99445641, -0.997216582, 0.00554354861, -0.0743518993, "322620", true, 0, "SmoothPlastic", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.0896463, 5.80000019, 3.8499999, 5.80000019, 0, 0.99723196, 0.0743518993, -0.0745582655, 0.0741449445, -0.99445641, -0.997216582, -0.00554354861, 0.0743518993, "4e3a2c", true, 0, "SmoothPlastic", true },
	{ "Window", "Part", "Cylinder", 0.5, 2.20000005, 2.20000005, 0.439418614, 20.3741798, -4.0999999, -4.36049099e-08, 0.0697564706, 0.997564077, 3.04915226e-09, 0.997564077, -0.0697564706, -1, 0, -4.37113883e-08, "aa50ff", true, 0, "Neon", true },
	{ "WindowFrame", "Part", "Cylinder", 0.5, 2.9000001, 2.9000001, 0.439418614, 20.3741798, -3.94999981, -4.36049099e-08, 0.0697564706, 0.997564077, 3.04915226e-09, 0.997564077, -0.0697564706, -1, 0, -4.37113883e-08, "322620", true, 0, "SmoothPlastic", true },
}

-- the 01 roof planes of the village copies whose roofs differ from the kit (Cabin_1 / 5 / 7: 0.05 apart along Z; Cabin_3:
-- the right plane 13.6 deep), same row format
Data.RoofVariants = {
	RoofL_Split = { "Roof", "Part", "Block", 11, 0.800000012, 13.5, -4.2540884, 20.1786232, 0.95, 0.629320323, -0.777145982, 0, 0.777145982, 0.629320323, 0, 0, 0, 1, "354027", true, 0, "SmoothPlastic", true },
	RoofR_Split = { "Roof", "Part", "Block", 11, 0.800000012, 13.5, 3.53522205, 20.5868416, 1.05, 0.707106769, 0.707106829, 0, -0.707106829, 0.707106769, 0, 0, 0, 1, "3c4d2a", true, 0, "SmoothPlastic", true },
	RoofR_Wide = { "Roof", "Part", "Block", 11, 0.800000012, 13.6, 3.53522205, 20.5868416, 1, 0.707106769, 0.707106829, 0, -0.707106829, 0.707106769, 0, 0, 0, 1, "3c4d2a", true, 0, "SmoothPlastic", true },
}

local function rowOf(t: { any }): any
	return { name = t[1], class = t[2], shape = t[3], size = Vector3.new(t[4], t[5], t[6]), cf = CFrame.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16], t[17], t[18]), color = Color3.fromHex(t[19]), collide = t[20], transparency = t[21], material = t[22], query = t[23] }
end

-- the rows of a kit named `name` (all rows when nil), in the table's order
local function rows(kit: string, name: string?): { any }
	local out = {}
	for _, t in ipairs(Data[kit]) do
		if name == nil or t[1] == name then
			table.insert(out, rowOf(t))
		end
	end
	return out
end
SH.Data, SH.rows, SH.rowOf = Data, rows, rowOf

-- an invisible "Collision" part exactly like a kit row
local function collider(m: Model, r: any, name: string?, on: boolean?): BasePart
	local p = Instance.new(r.class) :: BasePart
	if r.shape ~= "" and p:IsA("Part") then
		p.Shape = (Enum.PartType :: any)[r.shape]
	end
	p.Name = name or "Collision"
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = r.color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = on ~= false
	p.CanQuery = on ~= false
	p.CanTouch = true
	p.CastShadow = false
	p.Transparency = 1
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- every colliding row of `kit` as a Collision part (rename(row, k) may give a row another name); returns how many
local function collisionRows(m: Model, kit: string, rename: ((any, number) -> string?)?): number
	local n = 0
	for k, r in ipairs(rows(kit)) do
		if r.collide then
			collider(m, r, if rename then rename(r, k) else nil)
			n += 1
		end
	end
	return n
end
SH.collisionRows = collisionRows

---------------------------------------------------------------------
-- shared swamp helpers (guide F2)
---------------------------------------------------------------------
local function tone(rng: Random, c: Color3, prev: { number }?): Color3
	local i = H.toneIndex(rng, prev and prev[1] or nil)
	if prev then
		prev[1] = i
	end
	return scaled(c, H.TONES[i])
end

-- the jungle moss / vine colours -> the swamp ones (pieces from list[from] on; unions keep their recolour through
-- UsePartColor, the chamfer faces take the same colour)
local JUNGLE_TO_SWAMP = {
	{ rgb(88, 150, 66), MOSS }, { rgb(96, 196, 72), MOSS_MID }, { rgb(120, 210, 70), OLIVE:Lerp(MOSS, 0.45) }, { rgb(70, 170, 60), VINE },
}
local function swampify(list: { BasePart }, from: number)
	for i = from, #list do
		local p = list[i]
		local c = p.Color
		local best, bd = JUNGLE_TO_SWAMP[1], math.huge
		for _, e in ipairs(JUNGLE_TO_SWAMP) do
			local d = (c.R - e[1].R) ^ 2 + (c.G - e[1].G) ^ 2 + (c.B - e[1].B) ^ 2
			if d < bd then
				bd, best = d, e
			end
		end
		local f = (c.R + c.G + c.B) / (best[1].R + best[1].G + best[1].B)
		if p:IsA("PartOperation") then
			p.UsePartColor = true
		end
		p.Color = scaled(best[2], f)
	end
end
SH.swampify = swampify

-- the jungle vines in swamp colours
local function vines(list: { BasePart }, rng: Random, top: Vector3, out: Vector3, along: Vector3, lengths: { number })
	local from = #list + 1
	J.vineGroup(list, rng, top, out, along, lengths)
	swampify(list, from)
end
SH.vines = vines

-- a strand of hanging moss from `top`, `len` long: thin swaying segments (0.2 -> 0.09) in 2 greens, a drip at the tip
local function strand(list: { BasePart }, rng: Random, top: Vector3, len: number)
	local p = top
	local y = 0
	local phase = rng:NextNumber(0, 6.28)
	local k = 0
	while y < len - 0.05 do
		local step = math.min(rng:NextNumber(0.35, 0.55), len - y)
		local yy = y + step
		local q = top + Vector3.new(math.sin(yy * 2.1 + phase) * 0.09, -yy, math.cos(yy * 1.7 + phase) * 0.09)
		table.insert(list, H.bar(p, q, 0.2 - 0.11 * y / len, if k % 2 == 0 then MOSS else MOSS_MID))
		p, y, k = q, yy, k + 1
	end
	table.insert(list, piece("Part", Vector3.one * 0.13, CFrame.new(p - Vector3.new(0, 0.05, 0)) * CFrame.Angles(rad(45), rad(45), 0), scaled(WATER, 1.3)))
end
-- moss tones by a face's world normal: lit tops the colour, sides a step darker, undersides darker still
local function mossTone(base: Color3): (Vector3) -> Color3
	return function(n: Vector3): Color3
		if n.Y > 0.5 then
			return base
		elseif n.Y > -0.2 then
			return scaled(base, 0.86)
		end
		return scaled(base, 0.72)
	end
end
local MOSS_TOP = MOSS:Lerp(OLIVE, 0.3) -- the lighter top layer (#5B852D), never lime

-- a tuft of 2 strands from one root (a small rounded moss lump at the root; no Ball: it costs ~200 triangles in a union)
local function hangingMoss(list: { BasePart }, rng: Random, top: Vector3, len: number)
	lump(list, rng, CFrame.new(top) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), 0.2, 0.13, 0.2, mossTone(MOSS))
	for i = 1, 2 do
		local off = Vector3.new(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		strand(list, rng, top + off, len * (if i == 1 then 1 else rng:NextNumber(0.45, 0.8)))
	end
end
SH.strand, SH.hangingMoss = strand, hangingMoss

-- a soft moss mat lying ON a surface (frame at the surface centre, Y out of it) over w x d (guide F2): 2-4 low rounded
-- faceted lumps in the dark swamp moss #3F7A2C that run together (flat undersides on the surface), and a smaller,
-- lighter top layer (#5B852D) on each; hMul scales the height (0.24 .. 0.3 tall at 1)
local function mossPatch(list: { BasePart }, rng: Random, frame: CFrame, w: number, d: number, hMul: number?)
	local count = math.clamp(math.floor(w * d / 1.5) + 1, 2, 4)
	local bh = 0.13 * (hMul or 1) + 0.05
	for k = 1, count do
		local cx = -w / 2 + w * (k - 0.5) / count + rng:NextNumber(-0.12, 0.12) * w / count
		local cz = rng:NextNumber(-0.15, 0.15) * d
		local a, c = w / count * rng:NextNumber(0.62, 0.78), d * rng:NextNumber(0.34, 0.46)
		local yaw = rng:NextNumber(-0.5, 0.5)
		lump(list, rng, frame * CFrame.new(cx, 0, cz) * CFrame.Angles(0, yaw, 0), a, bh, c, mossTone(scaled(MOSS, rng:NextNumber(0.94, 1.04))), 0.02)
		lump(list, rng, frame * CFrame.new(cx + rng:NextNumber(-0.15, 0.15) * a, bh * 0.55, cz + rng:NextNumber(-0.15, 0.15) * c) * CFrame.Angles(0, yaw + rng:NextNumber(-0.4, 0.4), 0), a * 0.55, bh * 0.75, c * 0.55, mossTone(MOSS_TOP), 0.02)
	end
end
-- moss DRAPING over an edge (frame at the edge: X along it, Y up, the face below looks -Z): a mat going back over the
-- top, a low rounded roll over the edge, and 3-4 thin drips hanging down the face (the longest `drop`)
local function mossDrape(list: { BasePart }, rng: Random, frame: CFrame, w: number, depth: number, drop: number)
	mossPatch(list, rng, frame * CFrame.new(0, 0, depth / 2 - 0.05), w, depth)
	lump(list, rng, frame * CFrame.new(0, -0.05, -0.02), w * 0.45, 0.15, 0.16, mossTone(MOSS))
	local n = rng:NextInteger(3, 4)
	for k = 1, n do
		local x = -w / 2 + w * (k - 0.5) / n + rng:NextNumber(-0.1, 0.1)
		strand(list, rng, (frame * CFrame.new(x, -0.12, -0.12)).Position, drop * rng:NextNumber(0.45, 1.0))
	end
end
SH.mossPatch, SH.mossDrape = mossPatch, mossDrape

-- a ghost mushroom at `base` (up = the surface normal), s = its cap width: a bone stem, a low 8-sided cap #BFF5F0 with a
-- paler underside disc
local function mushroom(list: { BasePart }, rng: Random, base: Vector3, s: number, up: Vector3?)
	local h = s * rng:NextNumber(0.7, 1.1)
	local cf = H.frameY(base, up or UP) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2))
	table.insert(list, piece("Part", Vector3.new(h + 0.05, 0.22 * s, 0.22 * s), cf * CFrame.new(0, h / 2 - 0.05, 0) * CFrame.Angles(0, 0, rad(90)), BONE, { shape = Enum.PartType.Cylinder }))
	table.insert(list, piece("Part", Vector3.new(0.06, 0.92 * s, 0.92 * s), cf * CFrame.new(0, h, 0) * CFrame.Angles(0, 0, rad(90)), GHOST_UNDER, { shape = Enum.PartType.Cylinder }))
	table.insert(list, frustumN(8, 0.5 * s, 0.14 * s, 0, 0.36 * s, cf * CFrame.new(0, h, 0), { GHOST, scaled(GHOST, 0.95), scaled(GHOST, 0.9) }))
end
local function mushrooms(list: { BasePart }, rng: Random, base: Vector3, n: number, s: number, up: Vector3?)
	local u = (up or UP).Unit
	local side = if math.abs(u.Y) < 0.9 then UP:Cross(u).Unit else Vector3.xAxis
	local fwd = u:Cross(side).Unit
	for k = 1, n do
		local off = side * rng:NextNumber(-0.45, 0.45) + fwd * rng:NextNumber(-0.45, 0.45)
		mushroom(list, rng, base + (if k == 1 then Vector3.zero else off), s * (if k == 1 then 1 else rng:NextNumber(0.5, 0.85)), u)
	end
end
SH.mushroom, SH.mushrooms = mushroom, mushrooms

-- a few olive lichen discs on a face (F = the face frame, -Z out of the face) round (x, y)
local function lichen(list: { BasePart }, rng: Random, F: CFrame, x: number, y: number, zOut: number)
	for _ = 1, rng:NextInteger(2, 4) do
		local d = rng:NextNumber(0.28, 0.6)
		local c = if rng:NextNumber() < 0.5 then OLIVE else scaled(OLIVE, 0.85)
		table.insert(list, piece("Part", Vector3.new(0.04, d, d), F * CFrame.new(x + rng:NextNumber(-0.5, 0.5), y + rng:NextNumber(-0.4, 0.4), -zOut - 0.02) * CFrame.Angles(0, rad(90), 0), c, { shape = Enum.PartType.Cylinder }))
	end
end

-- a zig-zag crack (2-3 dark segments, 0.06 wide) going down from (x, y) on a face
local function crack(list: { BasePart }, rng: Random, F: CFrame, x: number, y: number, zOut: number)
	local p = Vector2.new(x, y)
	for _ = 1, rng:NextInteger(2, 3) do
		local q = p + Vector2.new(rng:NextNumber(-0.2, 0.2), -rng:NextNumber(0.35, 0.6))
		local mid, d = (p + q) / 2, q - p
		table.insert(list, piece("Part", Vector3.new(0.06, d.Magnitude + 0.04, 0.03), F * CFrame.new(mid.X, mid.Y, -zOut - 0.01) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)), BLACKWOOD))
		p = q
	end
end

-- rotten vertical planks on a face (F at the face centre, X along it, Y up, -Z out), w x h; holes = rectangles { x, y,
-- w, h } and circles { x, y, r } the planks stop at; planks ~0.95 wide, 0.18 thick, 0.07 gaps over the dark core,
-- 3 tones, 1 in 7 tilted 2-3 degrees, cracks, a damp darker foot (0.55) on each plank, lichen
local function plankFace(list: { BasePart }, rng: Random, F: CFrame, w: number, h: number, color: Color3, holes: { any }?)
	local n = math.max(1, math.floor(w / 0.95 + 0.5))
	local pw = w / n
	local prev = { 0 }
	for i = 0, n - 1 do
		local xc = -w / 2 + (i + 0.5) * pw
		local intervals = { { -h / 2, h / 2 } }
		for _, hole in ipairs(holes or {}) do
			local cut = nil
			if hole.r then
				local dx = math.max(math.abs(xc - hole.x) - pw / 2, 0)
				if dx < hole.r then
					local dy = math.sqrt(hole.r * hole.r - dx * dx)
					cut = { hole.y - dy, hole.y + dy }
				end
			elseif math.abs(xc - hole.x) < hole.w / 2 + pw / 2 - 0.1 then
				cut = { hole.y - hole.h / 2, hole.y + hole.h / 2 }
			end
			if cut then
				local nxt = {}
				for _, iv in ipairs(intervals) do
					if cut[2] <= iv[1] or cut[1] >= iv[2] then
						table.insert(nxt, iv)
					else
						if cut[1] > iv[1] then
							table.insert(nxt, { iv[1], cut[1] })
						end
						if cut[2] < iv[2] then
							table.insert(nxt, { cut[2], iv[2] })
						end
					end
				end
				intervals = nxt
			end
		end
		local c = tone(rng, color, prev)
		local tilt = if rng:NextNumber() < 0.14 then rad(rng:NextNumber(2, 3) * (if rng:NextNumber() < 0.5 then -1 else 1)) else 0
		for _, iv in ipairs(intervals) do
			local len = iv[2] - iv[1]
			if len > 0.25 then
				local yc = (iv[1] + iv[2]) / 2
				local cf = F * CFrame.new(xc, yc, -0.09) * CFrame.Angles(0, 0, tilt)
				table.insert(list, piece("Part", Vector3.new(pw - 0.07, len, 0.18), cf, c))
				if iv[1] <= -h / 2 + 0.01 then
					table.insert(list, piece("Part", Vector3.new(pw - 0.09, math.min(0.55, len), 0.03), F * CFrame.new(xc, iv[1] + math.min(0.55, len) / 2, -0.19) * CFrame.Angles(0, 0, tilt), scaled(c, 0.72)))
				end
				if len > 2.2 and rng:NextNumber() < 0.3 then
					crack(list, rng, F, xc + rng:NextNumber(-0.15, 0.15), yc + rng:NextNumber(0, len * 0.3), 0.18)
				end
			end
		end
	end
end
SH.plankFace = plankFace

-- the 4 plank faces of a body (row; the front face takes `holes`), a dark core, chamfered corner posts, a sill and a top
-- plate of timbers round it, a dark foundation beam under it (the body is tilted: no gap above the deck); lichen
local function plankBody(U: any, rng: Random, body: any, deckTop: number, holes: { any }, post: Color3)
	local s = body.size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	table.insert(U.Walls, piece("Part", s - Vector3.new(0.04, 0.02, 0.04), body.cf, scaled(body.color, 0.5)))
	local faces = {
		{ body.cf * CFrame.new(0, 0, -hz), s.X, holes },
		{ body.cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -hz), s.X, nil },
		{ body.cf * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -hx), s.Z, nil },
		{ body.cf * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, 0, -hx), s.Z, nil },
	}
	for i, f in ipairs(faces) do
		plankFace(U.Walls, rng, f[1], f[2], s.Y, body.color, f[3])
		local lx = if i == 1 then -f[2] * 0.36 else rng:NextNumber(-f[2] * 0.3, f[2] * 0.3)
		lichen(U.Moss, rng, f[1], lx, rng:NextNumber(-hy * 0.6, hy * 0.2), 0.18)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Wood, chamfered(Vector3.new(0.6, s.Y, 0.6), body.cf * CFrame.new(sx * hx, 0, sz * hz), tone(rng, post), { "vertical" }, 0.12))
		end
	end
	-- sill and top plate: 4 timbers each, 0.18 outside the planks
	for _, y in ipairs({ -hy + 0.25, hy - 0.25 }) do
		for side = 0, 3 do
			local half = if side % 2 == 0 then hz else hx
			local len = (if side % 2 == 0 then s.X else s.Z) + 0.2
			local frame = body.cf * CFrame.Angles(0, side * math.pi / 2, 0)
			table.insert(U.Wood, H.timber(Vector3.new(len, 0.45, 0.3), frame * CFrame.new(0, y, -half - 0.33), tone(rng, post), 0.08))
		end
	end
	-- the foundation beam: world-level, its top 0.3 over the deck, inside the body's footprint
	local bottom = body.cf.Position.Y - hy * body.cf.UpVector.Y
	local top = math.max(bottom, deckTop) + 0.3
	table.insert(U.Wood, piece("Part", Vector3.new(s.X - 0.6, top - deckTop + 0.1, s.Z - 0.3), CFrame.new(body.cf.Position.X, (top + deckTop - 0.1) / 2, body.cf.Position.Z), MUD_DARK))
end

-- a stilt row's two ends (bottom, top)
local function stiltEnds(r: any): (Vector3, Vector3)
	local a = r.cf.Position + r.cf.ZVector * r.size.Z / 2
	local b = r.cf.Position - r.cf.ZVector * r.size.Z / 2
	if a.Y > b.Y then
		a, b = b, a
	end
	return a, b
end
-- the point of the stilt axis a .. b at height y
local function atY(a: Vector3, b: Vector3, y: number): Vector3
	return a:Lerp(b, (y - a.Y) / (b.Y - a.Y))
end

-- today's stilts as thick 8-sided logs with an iron band, rope ties under the deck, algae and a mud collar at the water
-- line (y 0); X braces on 3 sides (rope at the crossing), a low rail in front; mushrooms at 2 feet
local function stilts(U: any, rng: Random, kit: string, deckBottom: number, front: boolean?)
	local ends = {}
	for _, r in ipairs(rows(kit, "Stilt")) do
		local a, b = stiltEnds(r)
		local rr = r.size.X / 2 + 0.06
		local axis = (b - a).Unit
		table.insert(U.Wood, frustumN(8, rr + 0.03, rr - 0.02, 0, (b - a).Magnitude, H.frameY(a, axis) * CFrame.Angles(0, rad(22.5), 0), { r.color, scaled(r.color, 1.12), scaled(r.color, 0.9), scaled(r.color, 1.04) }))
		table.insert(U.Iron, frustumN(8, rr + 0.08, rr + 0.08, -0.16, 0.16, H.frameY(atY(a, b, 3.2), axis) * CFrame.Angles(0, rad(22.5), 0), { IRON, scaled(IRON, 0.85) }))
		lashing(U.Rope, atY(a, b, deckBottom - 0.75), axis, rr, 3, rng)
		table.insert(U.Moss, frustumN(8, rr + 0.07, rr + 0.06, -0.22, 0.22, H.frameY(atY(a, b, 0.2), axis) * CFrame.Angles(0, rad(22.5), 0), { WATER, scaled(WATER, 1.15) }))
		table.insert(U.Moss, frustumN(8, rr + 0.06, rr + 0.03, -0.2, 0.2, H.frameY(atY(a, b, 0.6), axis) * CFrame.Angles(0, rad(22.5), 0), { MOSS, MOSS_MID }))
		local foot = atY(a, b, 0)
		lump(U.Mud, rng, CFrame.new(foot.X, 0.06, foot.Z), rr + 0.55, 0.32, rr + 0.5, function(n: Vector3): Color3
			return if n.Y > 0.5 then scaled(MUD_DARK, 1.15) else MUD_DARK
		end, 0.06)
		table.insert(ends, { a = a, b = b, r = rr, x = r.cf.Position.X, z = r.cf.Position.Z, color = r.color })
	end
	local function find(sx: number, sz: number): any
		for _, e in ipairs(ends) do
			if math.sign(e.x) == sx and math.sign(e.z) == sz then
				return e
			end
		end
		return nil
	end
	local BR = scaled(rows(kit, "Stilt")[2].color, 1.05)
	local function brace(e1: any, e2: any, out: Vector3)
		local y0, y1 = 0.9, deckBottom - 1.4
		local p1, q1 = atY(e1.a, e1.b, y0) + out * (e1.r + 0.2), atY(e2.a, e2.b, y1) + out * (e2.r + 0.2)
		local p2, q2 = atY(e2.a, e2.b, y0) + out * (e2.r + 0.2), atY(e1.a, e1.b, y1) + out * (e1.r + 0.2)
		table.insert(U.Wood, H.bar(p1, q1, 0.34, tone(rng, BR)))
		table.insert(U.Wood, H.bar(p2 + out * 0.3, q2 + out * 0.3, 0.34, tone(rng, BR)))
		lashing(U.Rope, (p1 + q1 + p2 + q2) / 4 + out * 0.15, (q1 - p1).Unit, 0.22, 2, rng)
	end
	brace(find(-1, -1), find(-1, 1), -Vector3.xAxis)
	brace(find(1, 1), find(1, -1), Vector3.xAxis)
	brace(find(-1, 1), find(1, 1), Vector3.zAxis)
	if front then
		local e1, e2 = find(-1, -1), find(1, -1)
		table.insert(U.Wood, H.bar(atY(e1.a, e1.b, 1.5) - Vector3.zAxis * (e1.r + 0.2), atY(e2.a, e2.b, 1.5) - Vector3.zAxis * (e2.r + 0.2), 0.34, tone(rng, BR)))
	end
	local e = find(-1, 1)
	mushrooms(U.Mush, rng, atY(e.a, e.b, 0) + Vector3.new(0.9, 0.25, -0.3), 3, 0.55)
	e = find(1, -1)
	mushrooms(U.Mush, rng, atY(e.a, e.b, 0) + Vector3.new(-0.5, 0.25, -0.9), 2, 0.45)
	return ends
end

-- today's deck as rotten planks along X over a dark mud-coloured bed: rim beams front and back, 2 broken planks with
-- splinters, mossy planks, moss drapes over the front edge, hanging moss and vines under the edges
local function deck(U: any, rng: Random, r: any)
	local s, c = r.size, r.cf.Position
	local top = c.Y + s.Y / 2
	table.insert(U.Deck, piece("Part", Vector3.new(s.X - 0.2, s.Y - 0.3, s.Z - 0.2), CFrame.new(c.X, c.Y - 0.15, c.Z), MUD_DARK))
	local n = math.floor(s.Z / 1.0 + 0.5)
	local pw = s.Z / n
	local prev = { 0 }
	local broken = { [rng:NextInteger(2, 4)] = true, [rng:NextInteger(n - 4, n - 2)] = true }
	for i = 0, n - 1 do
		local z = c.Z - s.Z / 2 + (i + 0.5) * pw
		local col = tone(rng, r.color, prev)
		if rng:NextNumber() < 0.18 then
			col = col:Lerp(MOSS, 0.25)
		end
		local len = s.X - rng:NextNumber(0, 0.35)
		local x0 = c.X - s.X / 2 + rng:NextNumber(0, s.X - len)
		if broken[i] then
			local gx = rng:NextNumber(-s.X * 0.25, s.X * 0.25)
			local gap = rng:NextNumber(0.35, 0.6)
			local a0, a1, b0, b1 = x0, c.X + gx - gap / 2, c.X + gx + gap / 2, x0 + len
			table.insert(U.Deck, piece("Part", Vector3.new(a1 - a0, 0.3, pw - 0.07), CFrame.new((a0 + a1) / 2, top - 0.15, z), col))
			table.insert(U.Deck, piece("Part", Vector3.new(b1 - b0, 0.3, pw - 0.07), CFrame.new((b0 + b1) / 2, top - 0.15, z) * CFrame.Angles(0, 0, rad(-1.5)), scaled(col, 0.9)))
			TB.splinters(U.Deck, rng, Vector3.new(a1, top - 0.15, z), Vector3.xAxis, 0.1, col)
			TB.splinters(U.Deck, rng, Vector3.new(b0, top - 0.15, z), -Vector3.xAxis, 0.1, col)
		else
			table.insert(U.Deck, piece("Part", Vector3.new(len, 0.3, pw - 0.07), CFrame.new(x0 + len / 2, top - 0.15, z), col))
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(s.X + 0.1, 0.55, 0.4), CFrame.new(c.X, c.Y - 0.32, c.Z + sz * (s.Z / 2 - 0.15)), scaled(r.color, 0.72), 0.08))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.4, 0.55, s.Z - 0.7), CFrame.new(c.X + sx * (s.X / 2 - 0.15), c.Y - 0.32, c.Z), scaled(r.color, 0.68), 0.08))
	end
	-- moss over the front edge and the left edge; hanging moss under the front and back edges
	mossDrape(U.Moss, rng, CFrame.new(c.X - s.X * 0.3, top, c.Z - s.Z / 2), 2.2, 0.7, 0.9)
	mossDrape(U.Moss, rng, CFrame.new(c.X + s.X * 0.33, top, c.Z - s.Z / 2), 1.6, 0.6, 0.7)
	mossDrape(U.Moss, rng, CFrame.new(c.X - s.X / 2, top, c.Z + s.Z * 0.2) * CFrame.Angles(0, rad(90), 0), 2.0, 0.6, 0.8)
	for _, q in ipairs({ { -0.15, -1, 1.6 }, { 0.12, -1, 1.1 }, { 0.42, -1, 2.0 }, { -0.35, 1, 1.4 }, { 0.3, 1, 1.8 } }) do
		hangingMoss(U.Hang, rng, Vector3.new(c.X + q[1] * s.X, c.Y - s.Y / 2 - 0.3, c.Z + q[2] * (s.Z / 2 - 0.05)), q[3])
	end
	vines(U.Moss, rng, Vector3.new(c.X - s.X / 2 + 0.6, c.Y - s.Y / 2 - 0.2, c.Z - s.Z / 2 - 0.25), -Vector3.zAxis, Vector3.xAxis, { 1.8, 2.8 })
	vines(U.Moss, rng, Vector3.new(c.X + s.X / 2 - 0.25, c.Y - s.Y / 2 - 0.2, c.Z + s.Z * 0.15), Vector3.xAxis, Vector3.zAxis, { 2.4 })
end

-- today's door as near-black boards over a darker core, 3 iron straps with rivets running into hinge pintles on the
-- left, a ring handle, a chamfered frame; today's lintel as a nailed timber with a moss tuft
local function door(U: any, rng: Random, d: any, lintel: any)
	local DF = d.cf
	local w, h = d.size.X, d.size.Y
	local fz = -d.size.Z / 2
	table.insert(U.Door, piece("Part", d.size - Vector3.new(0.1, 0.1, 0), DF, scaled(d.color, 0.6)))
	local n = 6
	local prev = { 0 }
	for i = 0, n - 1 do
		local bh = h - 0.1 - rng:NextNumber(0, 0.25)
		local x = -w / 2 + (i + 0.5) * w / n
		table.insert(U.Door, piece("Part", Vector3.new(w / n - 0.07, bh, 0.14), DF * CFrame.new(x, (h - 0.1) / 2 - bh / 2, fz - 0.07), scaled(tone(rng, d.color, prev), 1.12)))
	end
	for _, y in ipairs({ -h * 0.36, 0, h * 0.36 }) do
		table.insert(U.Iron, piece("Part", Vector3.new(w + 0.35, 0.3, 0.06), DF * CFrame.new(-0.18, y, fz - 0.17), IRON))
		for k = 0, 4 do
			H.rivet(U.Iron, (DF * CFrame.new(-w / 2 + 0.35 + k * (w - 0.7) / 4, y, fz - 0.21)).Position, 0.13)
		end
		table.insert(U.Iron, piece("Part", Vector3.new(0.5, 0.2, 0.2), DF * CFrame.new(-w / 2 - 0.3, y, fz - 0.05) * CFrame.Angles(0, 0, rad(90)), scaled(IRON, 0.8), { shape = Enum.PartType.Cylinder }))
	end
	-- the ring handle (8 short bars on a circle) on a round plate
	local hc = DF * CFrame.new(w / 2 - 0.85, -0.3, fz - 0.24)
	table.insert(U.Iron, piece("Part", Vector3.new(0.05, 0.5, 0.5), hc * CFrame.Angles(0, rad(90), 0), scaled(IRON, 0.9), { shape = Enum.PartType.Cylinder }))
	for k = 0, 7 do
		local a = k * math.pi / 4
		table.insert(U.Iron, piece("Part", Vector3.new(0.27, 0.07, 0.07), hc * CFrame.new(math.cos(a) * 0.32, -0.3 + math.sin(a) * 0.32, -0.05) * CFrame.Angles(0, 0, a + math.pi / 2), IRON))
	end
	-- the frame: 2 chamfered posts, a threshold
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.45, h + 0.3, 0.42), DF * CFrame.new(sx * (w / 2 + 0.22), 0.1, -0.02), tone(rng, d.color), { "vertical" }, 0.08))
	end
	table.insert(U.Wood, H.timber(Vector3.new(w + 0.9, 0.25, 0.5), DF * CFrame.new(0, -h / 2 - 0.1, -0.05), scaled(d.color, 0.9), 0.06))
	-- today's lintel (its size, colour and place) with 3 nails and a moss tuft on it
	table.insert(U.Wood, H.timber(lintel.size, lintel.cf, lintel.color, 0.1))
	for _, x in ipairs({ -2.6, 0, 2.6 }) do
		TB.nail(U.Iron, (lintel.cf * CFrame.new(x, 0, -lintel.size.Z / 2)).Position, -lintel.cf.ZVector)
	end
	mossPatch(U.Moss, rng, lintel.cf * CFrame.new(-lintel.size.X * 0.22, lintel.size.Y / 2, 0), 2.2, 0.5, 0.6)
	hangingMoss(U.Hang, rng, (lintel.cf * CFrame.new(-lintel.size.X * 0.3, -0.3, -0.2)).Position, 1.0)
end

-- today's lantern glow (smaller core, same colour, same place) in an iron frame (plates, 4 rods, a pyramid cap, a
-- hook), hanging from today's bracket (iron, thinner) on a wall plate
local function lantern(U: any, rng: Random, l: any, bracket: any)
	local LC = l.cf
	table.insert(U.Glow, piece("Part", Vector3.new(0.66, 0.92, 0.66), LC, l.color))
	local metal = bracket.color
	for _, y in ipairs({ -0.53, 0.53 }) do
		table.insert(U.Iron, chamfered(Vector3.new(0.96, 0.14, 0.96), LC * CFrame.new(0, y, 0), metal, { "vertical" }, 0.12))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.08, 0.94, 0.08), LC * CFrame.new(sx * 0.4, 0, sz * 0.4), metal))
		end
	end
	table.insert(U.Iron, frustumN(4, 0.44, 0.08, 0.6, 0.86, LC * CFrame.Angles(0, rad(45), 0), { metal, scaled(metal, 1.2) }))
	table.insert(U.Iron, piece("Part", Vector3.new(0.18, 0.1, 0.1), LC * CFrame.new(0, -0.68, 0), metal))
	local b = bracket.cf
	table.insert(U.Iron, piece("Part", Vector3.new(0.18, 0.18, bracket.size.Z), b, metal))
	-- the wall plate on the planks' face (0.18 behind the bracket's centre on both kits)
	table.insert(U.Iron, piece("Part", Vector3.new(0.5, 0.65, 0.08), b * CFrame.new(0, 0, 0.18), scaled(metal, 0.9)))
	H.rivet(U.Iron, (b * CFrame.new(0, 0.18, 0.12)).Position, 0.1)
	table.insert(U.Iron, piece("Part", Vector3.new(0.08, 0.3, 0.08), b * CFrame.new(0, 0.05, -bracket.size.Z / 2 + 0.05), scaled(metal, 1.2)))
	hangingMoss(U.Hang, rng, (b * CFrame.new(0, -0.1, 0)).Position, 0.6)
end

-- today's round window: the Neon glow exactly (its size, colour and place), today's wooden frame ring behind it, an iron
-- ring in front (16 segments, 8 rivets)
local function porthole(U: any, rng: Random, win: any, frame: any)
	table.insert(U.Glow, piece("Part", win.size, win.cf, win.color, { shape = Enum.PartType.Cylinder }))
	table.insert(U.Wood, piece("Part", frame.size, frame.cf, scaled(frame.color, 1.1), { shape = Enum.PartType.Cylinder }))
	local R = (win.size.Y + frame.size.Y) / 4 + 0.02
	local wr = (frame.size.Y - win.size.Y) / 2 + 0.06
	local WCF = win.cf
	local front = win.size.X / 2 + 0.06
	for k = 0, 15 do
		local a = k * math.pi / 8
		table.insert(U.Iron, piece("Part", Vector3.new(0.12, wr, 2 * math.pi * R / 16 + 0.06), WCF * CFrame.Angles(a, 0, 0) * CFrame.new(front, R, 0), if k % 2 == 0 then IRON else scaled(IRON, 0.9)))
	end
	for k = 0, 7 do
		H.rivet(U.Iron, (WCF * CFrame.Angles(k * math.pi / 4 + math.pi / 8, 0, 0) * CFrame.new(front + 0.07, R, 0)).Position, 0.12)
	end
end

-- today's ladder: chamfered rails (today's size and place), round rungs at today's places, rope lashings at every
-- rung end, mud at the feet; nothing collides (as today)
local function ladder(U: any, rng: Random, kit: string)
	local feet = {}
	for _, r in ipairs(rows(kit, "LadderRail")) do
		table.insert(U.Wood, H.timber(Vector3.new(0.36, 0.36, r.size.Z), r.cf, scaled(r.color, 1.25), 0.07))
		local a = r.cf.Position + r.cf.ZVector * r.size.Z / 2
		local b = r.cf.Position - r.cf.ZVector * r.size.Z / 2
		table.insert(feet, if a.Y < b.Y then a else b)
	end
	for _, r in ipairs(rows(kit, "Rung")) do
		table.insert(U.Wood, piece("Part", Vector3.new(r.size.X, 0.28, 0.28), r.cf, tone(rng, r.color), { shape = Enum.PartType.Cylinder }))
		for _, sx in ipairs({ -1, 1 }) do
			lashing(U.Rope, (r.cf * CFrame.new(sx * (r.size.X / 2 - 0.12), 0, 0)).Position, Vector3.xAxis, 0.15, 1, rng)
		end
	end
	for _, f in ipairs(feet) do
		lump(U.Mud, rng, CFrame.new(f.X, 0.05, f.Z), 0.5, 0.22, 0.45, function(): Color3
			return MUD_DARK
		end, 0.05)
	end
end

local GLOW_OPTS = { material = Enum.Material.Neon, shadow = false, query = true }

-- the template's roof-collider variants (01): Configuration attributes switch CanCollide / CanQuery by part name
local function variantsFolder(m: Model, list: { [string]: { [string]: boolean } })
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for name, flags in pairs(list) do
		local config = Instance.new("Configuration")
		config.Name = name
		for partName, on in pairs(flags) do
			config:SetAttribute("CanCollide_" .. partName, on)
			config:SetAttribute("CanQuery_" .. partName, on)
		end
		config.Parent = folder
	end
	folder.Parent = m
end

---------------------------------------------------------------------
-- 01 STILT HUT WITH THE GREEN ROOF (kit MapAssets.Swamp.Stilt_Cabin_A, 26 parts; test, kit, Swamp_3 Village x4)
---------------------------------------------------------------------
-- From the jungle stilt hut: today's 4 splayed stilts as thick 8-sided logs (iron band, rope ties, algae and mud at
-- the water line, X braces with rope on 3 sides, a low front rail); today's deck as rotten planks (2 broken) on rim
-- beams; today's crooked body as rotten plank walls (cracks, damp feet, lichen) on a dark core with corner posts, sill,
-- top plate and a foundation beam; today's 4 gable facets with board joints; today's 2 roof planes as overlapping mossy
-- shingles (3 tones of today's 2 greens, crooked and a few missing) with moss mats, a mushroom cluster, hanging moss
-- and vines at the eaves; today's ridge as a lashed timber; today's chimney as stone courses with a cap and moss; the
-- porthole (today's glow + frame) in an iron ring; the door with iron straps; the lantern; the ladder; mushrooms.
-- Parts: Deck, Door, Glow, Hang, Iron, Moss, Mud, Mush, RoofL, RoofR, Rope, Stone, Walls, Wood, Collision x18 (+ 3
-- variant roof colliders, off by default).
function SH.swamp_stilt_hut(): Model
	local kit = "Stilt_Cabin_A"
	local m = Instance.new("Model")
	m.Name = "swamp_stilt_hut"
	local rng = Random.new(20261024)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Rope = {}, Deck = {}, Walls = {}, Door = {}, RoofL = {}, RoofR = {}, Moss = {}, Hang = {}, Iron = {}, Stone = {}, Mud = {}, Mush = {}, Glow = {} }
	local body = rows(kit, "Body")[1]
	local deckRow = rows(kit, "Deck")[1]
	local deckTop = deckRow.cf.Y + deckRow.size.Y / 2
	local parts = rows(kit, "Part") -- lintel, ridge, lantern bracket (by X)
	local lintel, ridge, bracket = parts[1], parts[2], parts[3]
	local win, winFrame = rows(kit, "Window")[1], rows(kit, "WindowFrame")[1]
	local doorRow = rows(kit, "Door")[1]

	stilts(U, rng, kit, deckRow.cf.Y - deckRow.size.Y / 2, true)
	deck(U, rng, deckRow)

	-- the body: the front face's holes are the door and the porthole frame
	local F = body.cf * CFrame.new(0, 0, -body.size.Z / 2)
	local dp, wp = F:PointToObjectSpace(doorRow.cf.Position), F:PointToObjectSpace(win.cf.Position)
	plankBody(U, rng, body, deckTop, { { x = dp.X, y = dp.Y, w = doorRow.size.X + 0.9, h = doorRow.size.Y + 0.3 }, { x = wp.X, y = wp.Y, r = winFrame.size.Y / 2 + 0.05 } }, rows(kit, "Stilt")[1].color)
	door(U, rng, doorRow, lintel)
	porthole(U, rng, win, winFrame)
	lantern(U, rng, rows(kit, "Lantern")[1], bracket)

	-- the gables: today's 4 facets (darker gradient toward the eaves) with dark board joints every 0.7, cut at the
	-- roof undersides
	local roofs = rows(kit, "Roof")
	local RL, RR = roofs[1], roofs[2]
	local function underX(r: any, y: number): number
		local c, n = r.cf.Position, r.cf.UpVector
		return c.X + (-r.size.Y / 2 - (y - c.Y) * n.Y) / n.X
	end
	for _, f in ipairs(rows(kit, "Facet")) do
		table.insert(U.Walls, piece("WedgePart", f.size, f.cf, tone(rng, f.color)))
	end
	for _, zf in ipairs({ -4.5 - 0.3 - 0.02, 5.9 + 0.3 + 0.02 }) do
		local y = 18.2
		while y < 23.6 do
			local x0, x1 = underX(RL, y + 0.05) + 0.12, underX(RR, y + 0.05) - 0.12
			if x1 - x0 > 0.4 then
				table.insert(U.Walls, piece("Part", Vector3.new(x1 - x0, 0.07, 0.04), CFrame.new((x0 + x1) / 2, y, zf), BLACKWOOD))
			end
			y += 0.72
		end
		local vx = (underX(RL, 21.2) + underX(RR, 21.2)) / 2
		lichen(U.Moss, rng, CFrame.new(vx, 0, zf) * (if zf > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity), 0, 19.0, 0.02)
	end

	-- the roof: today's planes kept as a dark core (the soffit), overlapping shingles over their tops
	for idx, r in ipairs({ RL, RR }) do
		local list = if idx == 1 then U.RoofL else U.RoofR
		local RCF, s = r.cf, r.size
		-- local +X runs from the eave to the ridge on the left plane, from the ridge to the eave on the right one
		local dir = if idx == 1 then 1 else -1
		table.insert(list, piece("Part", s - Vector3.new(0.05, 0.05, 0.05), RCF, MUD_DARK))
		local prev = { 0 }
		local rowsN = math.ceil((s.X + 0.25) / 1.12)
		for k = 0, rowsN - 1 do
			local t = -0.25 + k * 1.12 -- the row's eave edge, from the plane's eave
			local len = math.min(1.45, s.X - t + 0.05)
			if len < 0.35 then
				continue
			end
			local xc = dir * (t + len / 2 - s.X / 2)
			local z = -s.Z / 2 - 0.15 - (if k % 2 == 1 then 0.72 else 0)
			while z < s.Z / 2 + 0.1 do
				local wdt = rng:NextNumber(1.25, 1.5)
				local a, b = math.max(z, -s.Z / 2 - 0.15), math.min(z + wdt, s.Z / 2 + 0.15)
				if b - a > 0.35 and rng:NextNumber() > 0.035 then
					local col = tone(rng, r.color, prev)
					if rng:NextNumber() < 0.22 then
						col = col:Lerp(MOSS, rng:NextNumber(0.25, 0.45))
					end
					local tilt = -dir * math.atan2(0.11, len)
					local crooked = if rng:NextNumber() < 0.12 then rad(rng:NextNumber(-5, 5)) else 0
					local cf = RCF * CFrame.new(xc, s.Y / 2 + 0.08 + k * 0.004, (a + b) / 2) * CFrame.Angles(crooked, rad(rng:NextNumber(-2.5, 2.5)), tilt)
					table.insert(list, piece("Part", Vector3.new(len, 0.12, b - a - 0.07), cf, col))
				end
				z += wdt + 0.07
			end
		end
		-- moss mats on the shingles, hanging moss at the eave
		for _, q in ipairs(if idx == 1 then { { -2.5, -3.6, 2.4, 1.6 }, { 1.2, 2.8, 2.0, 1.4 }, { -3.8, 4.9, 1.6, 1.2 } } else { { 2.6, 3.4, 2.2, 1.5 }, { -1.5, -4.2, 1.8, 1.3 } }) do
			mossPatch(U.Moss, rng, RCF * CFrame.new(dir * q[1], s.Y / 2 + 0.18, q[2]), q[3], q[4], 0.7)
		end
		for _, q in ipairs({ { -5.6, 1.6 }, { -3.1, 1.0 }, { 0.4, 2.2 }, { 3.2, 1.3 }, { 6.0, 1.9 } }) do
			hangingMoss(U.Hang, rng, (RCF * CFrame.new(-dir * (s.X / 2 - 0.15), -s.Y / 2 - 0.05, q[1])).Position, q[2])
		end
	end
	mushrooms(U.Mush, rng, (RL.cf * CFrame.new(-1.6, RL.size.Y / 2 + 0.2, 4.4)).Position, 3, 0.5, RL.cf.UpVector)
	vines(U.Moss, rng, (RR.cf * CFrame.new(RR.size.X / 2 - 0.2, -RR.size.Y / 2, -RR.size.Z / 2 + 0.4)).Position, -Vector3.zAxis, Vector3.zAxis, { 2.6, 1.7 })
	-- today's ridge as a chamfered timber with 3 rope lashings
	table.insert(U.Wood, H.timber(ridge.size, ridge.cf, ridge.color, 0.14))
	for _, z in ipairs({ -5.5, 0, 5.5 }) do
		lashing(U.Rope, (ridge.cf * CFrame.new(0, 0, z)).Position, ridge.cf.ZVector, 0.46, 3, rng)
	end

	-- today's chimney as stone courses (its axis = local Z, the top at -Z) over a dark core, a cap slab, a dark flue, moss
	local ch = rows(kit, "Chimney")[1]
	local C = ch.cf
	local L = ch.size.Z
	table.insert(U.Stone, piece("Part", ch.size - Vector3.new(0.12, 0.12, 0.05), C, scaled(ch.color, 0.55)))
	local nC = math.floor(L / 0.76)
	local prevS = { 0 }
	for k = 0, nC - 1 do
		local z = L / 2 - (k + 0.5) * L / nC
		local turn = if k % 2 == 0 then 0 else math.pi / 2
		table.insert(U.Stone, chamfered(Vector3.new(ch.size.X + 0.08, ch.size.Y + 0.08, L / nC - 0.08), C * CFrame.new(rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.03, 0.03), z) * CFrame.Angles(0, 0, turn), tone(rng, ch.color, prevS), { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.08))
	end
	table.insert(U.Stone, chamfered(Vector3.new(ch.size.X + 0.45, ch.size.Y + 0.45, 0.3), C * CFrame.new(0, 0, -L / 2 - 0.13), scaled(ch.color, 0.85), { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.08))
	table.insert(U.Stone, piece("Part", Vector3.new(0.9, 0.9, 0.06), C * CFrame.new(0, 0, -L / 2 - 0.29), rgb(26, 24, 24)))
	mossPatch(U.Moss, rng, C * CFrame.new(0.55, 0.2, -L / 2 - 0.27) * CFrame.Angles(rad(-90), 0, 0), 0.9, 1.4, 0.5)

	ladder(U, rng, kit)

	-- a mushroom cluster on the deck (back right) and a moss mat by the door
	mushrooms(U.Mush, rng, Vector3.new(7.6, deckTop, 6.6), 4, 0.6)
	mossPatch(U.Moss, rng, CFrame.new(-6.9, deckTop, -6.4), 1.6, 1.1, 0.5)

	TB.finishTB(m, "swamp_stilt_hut", U, "Walls", { Glow = GLOW_OPTS })

	-- collisions: today's colliding parts; the 2 roof planes by name, so the variants can swap them
	collisionRows(m, kit, function(r: any, _k: number): string?
		if r.name == "Roof" then
			return if r.cf.Position.X < 0 then "CollisionRoofL" else "CollisionRoofR"
		end
		return nil
	end)
	collider(m, rowOf(Data.RoofVariants.RoofL_Split), "CollisionRoofLSplit", false)
	collider(m, rowOf(Data.RoofVariants.RoofR_Split), "CollisionRoofRSplit", false)
	collider(m, rowOf(Data.RoofVariants.RoofR_Wide), "CollisionRoofRWide", false)
	variantsFolder(m, {
		RoofSplit = { CollisionRoofL = false, CollisionRoofR = false, CollisionRoofLSplit = true, CollisionRoofRSplit = true },
		RoofWide = { CollisionRoofR = false, CollisionRoofRWide = true },
	})
	return m
end

---------------------------------------------------------------------
-- 02 WITCH HUT WITH THE PURPLE HAT (kit MapAssets.Swamp.Stilt_Cabin_B, 24 parts; test, kit, Swamp_3 Village x3)
---------------------------------------------------------------------
-- The same recipe as 01 (stilts, deck, plank body, door, lantern = the hanging yellow tag, ladder) and today's front
-- diagonal brace as a log; today's eye window (the Neon glow exactly) in an iron ring under a wooden brow; the hat: today's brim as a rounded chamfered slab with moss and hanging moss, a dark band with a brass
-- buckle round the crown, today's 4 crooked tiers as cores clad in 3 rows of purple shingles (kicked-out butts, corner
-- trims, a #7A2BC8 lip line, a shingled top), a bent tip curling on from the top tier; potion bottles and a broom.
-- Parts: Broom, Deck, Door, Glow, Hang, Hat1, Hat2, Iron, Moss, Mud, Mush, Rope, Walls, Wood, Collision x15.
function SH.swamp_witch_hut(): Model
	local kit = "Stilt_Cabin_B"
	local m = Instance.new("Model")
	m.Name = "swamp_witch_hut"
	local rng = Random.new(20261025)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Rope = {}, Deck = {}, Walls = {}, Door = {}, Hat1 = {}, Hat2 = {}, Moss = {}, Hang = {}, Iron = {}, Mud = {}, Mush = {}, Broom = {}, Glow = {} }
	local body = rows(kit, "Body")[1]
	local deckRow = rows(kit, "Deck")[1]
	local deckTop = deckRow.cf.Y + deckRow.size.Y / 2
	local parts = rows(kit, "Part") -- lantern bracket, front brace, lintel (by X)
	local bracket, braceRow, lintel = parts[1], parts[2], parts[3]
	local win, winFrame = rows(kit, "Window")[1], rows(kit, "WindowFrame")[1]
	local doorRow = rows(kit, "Door")[1]

	stilts(U, rng, kit, deckRow.cf.Y - deckRow.size.Y / 2, false)
	-- today's front diagonal brace as a log with rope at both ends
	do
		local a = braceRow.cf.Position + braceRow.cf.ZVector * braceRow.size.Z / 2
		local b = braceRow.cf.Position - braceRow.cf.ZVector * braceRow.size.Z / 2
		table.insert(U.Wood, frustumN(8, 0.32, 0.29, 0, (b - a).Magnitude, H.frameY(a, b - a) * CFrame.Angles(0, rad(22.5), 0), { braceRow.color, scaled(braceRow.color, 1.15), scaled(braceRow.color, 0.92) }))
		for _, p in ipairs({ a:Lerp(b, 0.08), a:Lerp(b, 0.92) }) do
			lashing(U.Rope, p, (b - a).Unit, 0.3, 2, rng)
		end
	end
	deck(U, rng, deckRow)

	local F = body.cf * CFrame.new(0, 0, -body.size.Z / 2)
	local dp, wp = F:PointToObjectSpace(doorRow.cf.Position), F:PointToObjectSpace(win.cf.Position)
	plankBody(U, rng, body, deckTop, { { x = dp.X, y = dp.Y, w = doorRow.size.X + 0.9, h = doorRow.size.Y + 0.3 }, { x = wp.X, y = wp.Y, r = winFrame.size.Y / 2 + 0.05 } }, rows(kit, "Stilt")[2].color)
	door(U, rng, doorRow, lintel)
	porthole(U, rng, win, winFrame)
	-- the eye: a wooden brow of 5 short planks arching over the ring (the glow itself stays whole)
	for k = -2, 2 do
		local a = rad(90 + k * 22)
		local R = winFrame.size.Y / 2 + 0.3
		table.insert(U.Wood, piece("Part", Vector3.new(0.16, 0.26, 0.62), win.cf * CFrame.Angles(a - rad(90), 0, 0) * CFrame.new(win.size.X / 2 + 0.02, R, 0), tone(rng, winFrame.color)))
	end
	lantern(U, rng, rows(kit, "Lantern")[1], bracket)
	ladder(U, rng, kit)

	-- the hat
	local roofs = rows(kit, "Roof") -- brim, tier 1 .. 4 (by X)
	local brim = roofs[1]
	table.insert(U.Hat1, chamfered(brim.size - Vector3.new(0, 0.05, 0), brim.cf, brim.color, { "vertical" }, 1.6))
	table.insert(U.Hat1, chamfered(brim.size - Vector3.new(1.0, 0.0, 1.0), brim.cf * CFrame.new(0, 0.08, 0), scaled(brim.color, 1.12), { "vertical" }, 1.3))
	for _, q in ipairs({ { -5.2, -4.4, 1.8 }, { -3.0, -5.9, 1.1 }, { 3.6, -5.6, 2.1 }, { 6.4, -0.8, 1.5 }, { 5.4, 4.6, 1.2 }, { -6.3, 2.2, 1.9 }, { -2.5, 5.9, 1.4 } }) do
		hangingMoss(U.Hang, rng, (brim.cf * CFrame.new(q[1], -brim.size.Y / 2 - 0.05, q[2])).Position, q[3])
	end
	for _, q in ipairs({ { -4.8, -4.6, 2.0, 1.2 }, { 4.4, 4.2, 1.8, 1.3 } }) do
		mossPatch(U.Moss, rng, brim.cf * CFrame.new(q[1], brim.size.Y / 2, q[2]), q[3], q[4], 0.6)
	end
	-- tiers: a darker core, 3 rows of shingles on each of the 4 faces (upper rows over lower ones, butts kicked out
	-- 8 degrees), dark corner trims, a #7A2BC8 lip line at the foot, a shingled top
	for ti = 2, 5 do
		local r = roofs[ti]
		local list = if ti <= 3 then U.Hat1 else U.Hat2
		local s, TC = r.size, r.cf
		table.insert(list, piece("Part", s - Vector3.new(0.1, 0.02, 0.1), TC, scaled(r.color, 0.7)))
		local prev = { 0 }
		for side = 0, 3 do
			local half = if side % 2 == 0 then s.Z / 2 else s.X / 2
			local wide = if side % 2 == 0 then s.X else s.Z
			local FF = TC * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0, -half)
			for k = 0, 2 do
				local y = -s.Y / 2 + 0.1 + k * 1.08 + 0.68
				local n = math.max(2, math.floor(wide / 1.15 + 0.5))
				local sw = wide / n
				local off = if k % 2 == 1 then sw / 2 else 0
				for i = 0, n do
					local x0 = -wide / 2 + i * sw - off
					local a, b = math.max(x0, -wide / 2), math.min(x0 + sw, wide / 2)
					if b - a > 0.3 then
						table.insert(list, piece("Part", Vector3.new(b - a - 0.06, 1.36, 0.1), FF * CFrame.new((a + b) / 2, y, -0.1 - k * 0.05) * CFrame.Angles(rad(8), 0, rad(rng:NextNumber(-2, 2))), tone(rng, r.color, prev)))
					end
				end
			end
			table.insert(list, piece("Part", Vector3.new(wide + 0.25, 0.1, 0.12), FF * CFrame.new(0, -s.Y / 2 + 0.12, -0.24), MAGIC))
			table.insert(list, piece("Part", Vector3.new(0.26, s.Y, 0.26), FF * CFrame.new(-wide / 2 - 0.04, 0, -0.08), scaled(r.color, 0.62)))
		end
		table.insert(list, chamfered(Vector3.new(s.X + 0.1, 0.2, s.Z + 0.1), TC * CFrame.new(0, s.Y / 2 + 0.02, 0), scaled(r.color, 1.06), { "vertical", "topFrontBack", "topSides" }, 0.08))
	end
	-- the hat band (dark, round tier 1's foot) and a brass buckle in front
	do
		local t1 = roofs[2]
		local s = t1.size
		local y = -s.Y / 2 + 0.55
		for side = 0, 3 do
			local half = if side % 2 == 0 then s.Z / 2 else s.X / 2
			local wide = if side % 2 == 0 then s.X else s.Z
			table.insert(U.Hat1, piece("Part", Vector3.new(wide + 0.62, 0.8, 0.14), t1.cf * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, y, -half - 0.3), BLACKWOOD))
		end
		local B = t1.cf * CFrame.new(-0.8, y, -s.Z / 2 - 0.42)
		for _, e in ipairs({ { 0, 0.42, 1.3, 0.16 }, { 0, -0.42, 1.3, 0.16 }, { -0.57, 0, 0.16, 1.0 }, { 0.57, 0, 0.16, 1.0 } }) do
			table.insert(U.Iron, piece("Part", Vector3.new(e[3], e[4], 0.1), B * CFrame.new(e[1], e[2], 0), BRASS))
		end
		table.insert(U.Iron, piece("Part", Vector3.new(0.7, 0.1, 0.08), B * CFrame.new(-0.1, 0, -0.02), scaled(BRASS, 0.85)))
	end
	-- the bent tip: 3 tapering 8-sided segments curling on from the top tier, a small ball at the end
	do
		local t4 = roofs[5]
		local p = (t4.cf * CFrame.new(0, t4.size.Y / 2, 0)).Position
		local ang = math.atan2(t4.cf.UpVector.X, t4.cf.UpVector.Y)
		local radii = { 0.85, 0.62, 0.4, 0.2 }
		for k, len in ipairs({ 0.9, 0.8, 0.6 }) do
			ang += rad(20)
			local d = Vector3.new(math.sin(ang), math.cos(ang), 0)
			table.insert(U.Hat2, frustumN(8, radii[k], radii[k + 1], -0.08, len, H.frameY(p, d), { if k % 2 == 1 then roofs[4].color else roofs[5].color, scaled(roofs[5].color, 1.1) }))
			p += d * len
		end
		table.insert(U.Hat2, piece("Part", Vector3.one * 0.34, CFrame.new(p), MAGIC, { shape = Enum.PartType.Ball }))
	end

	-- potion bottles on the deck (front right) and a broom leaning by the door
	for i, q in ipairs({ { 5.2, -6.0, MAGIC, 0.62 }, { 5.9, -5.3, OLIVE, 0.5 }, { 4.6, -6.3, MAGENTA, 0.44 } }) do
		local base = Vector3.new(q[1], deckTop, q[2])
		local s = q[4]
		if i == 2 then
			table.insert(U.Mush, piece("Part", Vector3.new(s * 1.3, s, s), CFrame.new(base + Vector3.new(0, s * 0.65, 0)) * CFrame.Angles(0, 0, rad(90)), q[3], { shape = Enum.PartType.Cylinder }))
		else
			table.insert(U.Mush, piece("Part", Vector3.one * s * 1.2, CFrame.new(base + Vector3.new(0, s * 0.58, 0)), q[3], { shape = Enum.PartType.Ball }))
		end
		table.insert(U.Mush, piece("Part", Vector3.new(s * 0.6, s * 0.34, s * 0.34), CFrame.new(base + Vector3.new(0, s * 1.38, 0)) * CFrame.Angles(0, 0, rad(90)), scaled(q[3], 0.85), { shape = Enum.PartType.Cylinder }))
		table.insert(U.Mush, piece("Part", Vector3.new(s * 0.3, s * 0.28, s * 0.28), CFrame.new(base + Vector3.new(0, s * 1.8, 0)) * CFrame.Angles(0, 0, rad(90)), BONE, { shape = Enum.PartType.Cylinder }))
	end
	do
		local foot = Vector3.new(4.45, deckTop + 0.05, -4.75)
		local top = Vector3.new(3.75, deckTop + 5.6, -4.5)
		local d = (top - foot).Unit
		table.insert(U.Broom, frustumN(8, 0.1, 0.09, 1.2, (top - foot).Magnitude, H.frameY(foot, d), { HANDLE, scaled(HANDLE, 1.1) }))
		table.insert(U.Broom, frustumN(8, 0.45, 0.16, 0, 1.4, H.frameY(foot, d), { STRAW, scaled(STRAW, 0.9), scaled(STRAW, 1.08) }))
		for _, t in ipairs({ 1.15, 1.32 }) do
			table.insert(U.Broom, frustumN(8, 0.2, 0.18, t - 0.05, t + 0.05, H.frameY(foot, d), { rgb(110, 84, 52) }))
		end
	end
	mushrooms(U.Mush, rng, Vector3.new(-5.9, deckTop, 5.8), 3, 0.55)

	TB.finishTB(m, "swamp_witch_hut", U, "Walls", { Glow = GLOW_OPTS })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the earlier props; its install() builds them
---------------------------------------------------------------------
SH.BUILDERS = { swamp_stilt_hut = true, swamp_witch_hut = true }
for id in pairs(SH.BUILDERS) do
	B2[id] = (SH :: any)[id]
	B2.BUILDERS[id] = true
end
SH.install = B2.install
SH.stats = B2.stats
-- for the docks module (DevTools.PropsDocks): the same helper tables
SH.TB, SH.B2, SH.H, SH.M = TB, B2, H, M

return SH
