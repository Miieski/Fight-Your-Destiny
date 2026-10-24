--[[
	PropsDocks (dev tool, Edit mode only) - the owner's "PLAINS + CURSED SWAMP PROP IMPROVEMENT - Docks and platforms"
	(2026-10-24): ONE plank / post / rail recipe for 6 walkable pieces (docs/prop_texture_guide.md sections A, F, F3).
	Source of truth: tools/PropsDocks.luau. Inventory: docs/prop_inventory.md "Docks".
		06 plains plank platform with round posts  plains_plank_dock  (Common.Dock_Section)
		05 plains deck with rails                   plains_rail_deck   (Common.Bridge_Wood_Section)
		swamp 01 large dock platform                swamp_dock_large   (Swamp.Walkway_Section)     derived from 06
		swamp 02 small dock platform                swamp_dock_small   (Swamp.Walkway_Corner)      derived from 06
		swamp 03 dock with the ramp                 swamp_ramp_dock    (Swamp.Stilt_Platform)      the same recipe
		swamp 04 dock with rails                    swamp_rail_dock    (Swamp.Rope_Bridge_Swamp)   derived from 05
	The swamp pieces are the plains build (build()) run with the swamp style: the kits' own darker colours, more cracks,
	flat algae stains on the boards, algae and mud at the water line, hanging moss under the edges, moss on the caps,
	ghost mushrooms and iron lantern hooks (no lamp, no light). No missing or broken planks (main agent: cracks instead).

	The recipe: each kit plank is split into boards ~0.95 wide (3 tones, 0.06 gaps over a dark core, chamfered top
	edges, butt joints on long boards, nails at the ends and over every stringer, cracks, knots); the board TOPS are
	exactly the kit plank's top (walk surfaces unchanged, only the 0.04 nail heads stand above them). Posts and piles are
	round 8-sided logs with a capped top (a cap disc and a low dome), a rope wrap and an iron band; square rail posts
	are chamfered timbers with a pyramid cap and an iron band; stringers are chamfered timbers with bolts; rails are
	timbers with bevelled tops held to every post by an iron U-bracket with rivets; X braces under the deck between
	the supports; plains grass tufts at the feet (outside the walk surface).

	Collision: the visible unions never collide; every colliding kit row is an invisible "Collision" part (exact class,
	shape, size, place). The game copies of 06 and swamp 01 have their own small plank heights (+0.05 .. +0.15): their
	planks (and 01's stringers) are not in the template; each copy keeps its own as invisible parts in a "WalkCollision"
	folder (MapPropKeep; prepWalk() makes it once, before the first sync). The kit copy keeps the kit's.

		local PD = require(game.ServerStorage.DevTools.PropsDocks:Clone())
		print(PD.prepWalk("plains_plank_dock"), PD.install("plains_plank_dock"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "plains_plank_dock" } }), Sync.run({ only = { "plains_plank_dock" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any -- the swamp moss, mushrooms, hanging moss
local TB, B2, H, M = SH.TB, SH.B2, SH.H, SH.M
local piece, chamfered = H.piece, H.chamfered
local scaled = H.scaled
local frustumN = M.frustumN
local lump, lashing = TB.lump, TB.lashing

local PD = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local IRON = rgb(92, 98, 110) -- #5C626E
local IRON_RUST = rgb(104, 88, 76) -- swamp iron
local NAIL = rgb(70, 74, 84)
local CRACK = rgb(52, 34, 24)
local GRASS = { rgb(84, 170, 58), rgb(108, 190, 70), rgb(70, 142, 50) }
local MOSS = SH.COLORS.MOSS
local WATER = SH.COLORS.WATER
local MUD_DARK = SH.COLORS.MUD_DARK

---------------------------------------------------------------------
-- the kits as they were before the remake (read 2026-10-24; the test and kit copies are these exactly, the game copies of
-- Dock_Section / Walkway_Section raise some planks 0.05 .. 0.15). One row per part: { name, class, shape, sx, sy, sz, the
-- 12 CFrame components (kit pivot space), hex, collide }; rows sorted by name, then X, Y, Z
---------------------------------------------------------------------
local Data = {}

Data.Dock_Section = {
	{ "Pile", "Part", "Cylinder", 6.19999981, 1.39999998, 1.39999998, -5.60009766, 3.0999999, -8.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "703e26", true },
	{ "Pile", "Part", "Cylinder", 6.19999981, 1.39999998, 1.39999998, -5.60009766, 3.0999999, 8.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "703e26", true },
	{ "Pile", "Part", "Cylinder", 6.19999981, 1.39999998, 1.39999998, 5.60009766, 3.0999999, -8.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "703e26", true },
	{ "Pile", "Part", "Cylinder", 6.19999981, 1.39999998, 1.39999998, 5.60009766, 3.0999999, 8.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "703e26", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, -9, 0.999657333, 0, -0.02617695, 0, 1, 0, 0.02617695, 0, 0.999657333, "a86238", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, -7, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, -5, 0.999657333, 0, 0.02617695, 0, 1, 0, -0.02617695, 0, 0.999657333, "703e26", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, -3, 0.999657333, 0, -0.02617695, 0, 1, 0, 0.02617695, 0, 0.999657333, "a86238", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, 1, 0.999657333, 0, 0.02617695, 0, 1, 0, -0.02617695, 0, 0.999657333, "a86238", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, 3, 0.999657333, 0, -0.02617695, 0, 1, 0, 0.02617695, 0, 0.999657333, "703e26", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, 7, 0.999657333, 0, 0.02617695, 0, 1, 0, -0.02617695, 0, 0.999657333, "a86238", true },
	{ "Plank", "Part", "Block", 12, 0.699999988, 1.85000002, 0, 4.6500001, 9, 0.999657333, 0, -0.02617695, 0, 1, 0, 0.02617695, 0, 0.999657333, "d6965c", true },
	{ "Stringer", "Part", "Block", 0.899999976, 0.899999976, 20, -4.5, 3.9000001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Stringer", "Part", "Block", 0.899999976, 0.899999976, 20, 4.5, 3.9000001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
}

Data.Bridge_Wood_Section = {
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, -8, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, -4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, 4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, 8, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -7.5, 3.0999999, -9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -7.5, 3.0999999, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -7.5, 3.0999999, 9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 7.5, 3.0999999, -9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 7.5, 3.0999999, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 7.5, 3.0999999, 9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", true },
	{ "Rail", "Part", "Block", 0.5, 0.5, 20, -7.5, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
	{ "Rail", "Part", "Block", 0.699999988, 0.699999988, 20, -7.5, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
	{ "Rail", "Part", "Block", 0.5, 0.5, 20, 7.5, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
	{ "Rail", "Part", "Block", 0.699999988, 0.699999988, 20, 7.5, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "a86238", true },
}

Data.Walkway_Section = {
	{ "Part", "Part", "Block", 0.800000012, 0.600000024, 20, -4.5, 1.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Part", "Part", "Block", 0.800000012, 0.600000024, 20, 4.5, 1.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.79999995, 0, 1.75, -8, 0.999780655, 0, 0.0209424198, 0, 1, 0, -0.0209424198, 0, 0.999780655, "684c34", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.79999995, 0, 1.75, -4, 0.9997015, 0, -0.0244321786, 0, 1, 0, 0.0244321786, 0, 0.9997015, "816a52", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.79999995, 0, 1.75, 0, 0.999780655, 0, 0.0209424198, 0, 1, 0, -0.0209424198, 0, 0.999780655, "684c34", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.79999995, 0, 1.75, 4, 0.9997015, 0, -0.0244321786, 0, 1, 0, 0.0244321786, 0, 0.9997015, "816a52", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.79999995, 0, 1.75, 8, 0.999780655, 0, 0.0209424198, 0, 1, 0, -0.0209424198, 0, 0.999780655, "684c34", true },
	{ "Post", "Part", "Block", 1, 3.79999995, 1, -6.4000001, 0.699999988, -9, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -6.4000001, 0.899999976, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.5999999, 1, -6.4000001, 1.10000002, 9, 0.99862951, 0.0523359589, 0, -0.0523359589, 0.99862951, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 3.79999995, 1, 6.4000001, 0.699999988, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 6.4000001, 0.899999976, 9, 0.99862951, -0.0523359589, 0, 0.0523359589, 0.99862951, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.5999999, 1, 6.4000001, 1.10000002, -9, 0.99862951, 0.0523359589, 0, -0.0523359589, 0.99862951, 0, 0, 0, 1, "4e3a2c", true },
}

Data.Walkway_Corner = {
	{ "Part", "Part", "Block", 0.800000012, 0.600000024, 12, -4.5, 1.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Part", "Part", "Block", 0.800000012, 0.600000024, 12, 4.5, 1.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.9000001, 0, 1.75, -4, 0.99984771, 0, -0.0174524058, 0, 1, 0, 0.0174524058, 0, 0.99984771, "816a52", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.9000001, 0, 1.75, 0, 0.999657333, 0, 0.02617695, 0, 1, 0, -0.02617695, 0, 0.999657333, "684c34", true },
	{ "Plank", "Part", "Block", 12, 0.5, 3.9000001, 0, 1.75, 4, 0.99984771, 0, -0.0174524058, 0, 1, 0, 0.0174524058, 0, 0.99984771, "816a52", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -6.4000001, 0.899999976, -5.4000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -6.4000001, 0.899999976, 5.4000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 6.4000001, 0.899999976, -5.4000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 6.4000001, 0.899999976, 5.4000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
}

Data.Stilt_Platform = {
	{ "Part", "Part", "Block", 0.5, 0.5, 15, -7.4000001, 8.60000038, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Part", "Part", "Block", 0.899999976, 0.800000012, 16, -6, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Part", "Part", "Block", 0.800000012, 3.4000001, 0.800000012, -3.29999995, 1, -14, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Part", "Part", "Block", 15, 0.5, 0.5, 0, 8.60000038, 7.4000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Part", "Part", "Block", 0.800000012, 3.4000001, 0.800000012, 3.29999995, 1, -14, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e3a2c", true },
	{ "Part", "Part", "Block", 0.899999976, 0.800000012, 16, 6, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Part", "Part", "Block", 0.5, 0.5, 15, 7.4000001, 8.60000038, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Plank", "Part", "Block", 16, 0.600000024, 3.9000001, 0, 5.69999981, -6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true },
	{ "Plank", "Part", "Block", 16, 0.600000024, 3.9000001, 0, 5.69999981, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "816a52", true },
	{ "Plank", "Part", "Block", 16, 0.600000024, 3.9000001, 0, 5.69999981, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true },
	{ "Plank", "Part", "Block", 16, 0.600000024, 3.9000001, 0, 5.69999981, 6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "816a52", true },
	{ "Ramp", "Part", "Block", 6, 0.5, 13.6000004, 0, 2.75, -14, -1, 0, 0, 0, 0.89442718, -0.44721359, 0, -0.44721359, -0.89442718, "816a52", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.1383305, -7.44999981, 3.9000001, -7.44999981, 0, 0.999614716, -0.027756298, 0.0277669989, -0.0277455971, -0.999229252, -0.999614477, -0.00077070907, -0.027756298, "4e3a2c", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.1383305, -7.44999981, 3.9000001, 7.44999981, 0, 0.999614716, -0.027756298, -0.0277669989, -0.0277455971, -0.999229252, -0.999614477, 0.00077070907, 0.027756298, "4e3a2c", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.1383305, 7.44999981, 3.9000001, -7.44999981, 0, 0.999614716, 0.027756298, 0.0277669989, 0.0277455971, -0.999229252, -0.999614477, 0.00077070907, -0.027756298, "4e3a2c", true },
	{ "Stilt", "Part", "Block", 1.10000002, 1.10000002, 11.1383305, 7.44999981, 3.9000001, 7.44999981, 0, 0.999614716, 0.027756298, -0.0277669989, 0.0277455971, -0.999229252, -0.999614477, -0.00077070907, 0.027756298, "4e3a2c", true },
}

Data.Rope_Bridge_Swamp = {
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, -8, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, -4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "816a52", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, 4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "816a52", true },
	{ "Plank", "Part", "Block", 16, 1, 3.9000001, 0, 0.5, 8, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -7.5, 3.0999999, -9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -7.5, 3.0999999, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, -7.5, 3.0999999, 9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 7.5, 3.0999999, -9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 7.5, 3.0999999, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Post", "Part", "Block", 1, 4.19999981, 1, 7.5, 3.0999999, 9.40000153, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true },
	{ "Rail", "Part", "Block", 0.5, 0.5, 20, -7.5, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "957a4f", true },
	{ "Rail", "Part", "Block", 0.699999988, 0.699999988, 20, -7.5, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "957a4f", true },
	{ "Rail", "Part", "Block", 0.5, 0.5, 20, 7.5, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "957a4f", true },
	{ "Rail", "Part", "Block", 0.699999988, 0.699999988, 20, 7.5, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "957a4f", true },
}

local function rows(kit: string): { any }
	local out = {}
	for _, t in ipairs(Data[kit]) do
		table.insert(out, { name = t[1], class = t[2], shape = t[3], size = Vector3.new(t[4], t[5], t[6]), cf = CFrame.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16], t[17], t[18]), color = Color3.fromHex(t[19]), collide = t[20] })
	end
	return out
end
PD.Data, PD.rows = Data, rows

-- the 6 pieces: kit, style (swamp), round posts, the rows each game copy keeps as its own walk colliders
PD.STYLES = {
	plains_plank_dock = { kit = "Dock_Section", folder = "Common", swamp = false, roundPosts = true, walkKeep = { Plank = true } },
	plains_rail_deck = { kit = "Bridge_Wood_Section", folder = "Common", swamp = false, roundPosts = false },
	swamp_dock_large = { kit = "Walkway_Section", folder = "Swamp", swamp = true, roundPosts = true, walkKeep = { Plank = true, Part = true } },
	swamp_dock_small = { kit = "Walkway_Corner", folder = "Swamp", swamp = true, roundPosts = true },
	swamp_ramp_dock = { kit = "Stilt_Platform", folder = "Swamp", swamp = true, roundPosts = true, splitRails = true, hook = "+Z" },
	swamp_rail_dock = { kit = "Rope_Bridge_Swamp", folder = "Swamp", swamp = true, roundPosts = false, hook = "X" },
}
-- splitRails: the 4 Swamp_3 village copies of Stilt_Platform have no side rail where a rail dock joins them (Village
-- 10034 / 9930: none at x -7.4, 9966 / 10070: none at x +7.4). Each side rail is its own union (RailLeft / RailRight)
-- with its own collider (CollisionRailLeft / CollisionRailRight); the variants OpenLeft / OpenRight switch one side off
-- (Transparency 1, no collision, no query, no shadow), so the walk-over to the rail dock stays open as today.
-- hook: the lantern hooks point outward along X (the rail dock's sides) or +Z (the ramp dock's back), never over a
-- walk-over
PD.VARIANTS = {
	swamp_ramp_dock = {
		OpenLeft = { Transparency_RailLeft = 1, CastShadow_RailLeft = false, CanCollide_CollisionRailLeft = false, CanQuery_CollisionRailLeft = false },
		OpenRight = { Transparency_RailRight = 1, CastShadow_RailRight = false, CanCollide_CollisionRailRight = false, CanQuery_CollisionRailRight = false },
	},
}

---------------------------------------------------------------------
-- the shared recipe
---------------------------------------------------------------------
local function tone(rng: Random, c: Color3, prev: { number }?): Color3
	local i = H.toneIndex(rng, prev and prev[1] or nil)
	if prev then
		prev[1] = i
	end
	return scaled(c, H.TONES[i])
end

-- an invisible "Collision" part exactly like a kit row
local function collider(parent: Instance, r: any, name: string?): BasePart
	local p = Instance.new(r.class) :: BasePart
	if r.shape ~= "" and p:IsA("Part") then
		p.Shape = (Enum.PartType :: any)[r.shape]
	end
	p.Name = name or "Collision"
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = r.color
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p.CastShadow = false
	p.Transparency = 1
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- the boards of one kit plank / ramp row (boards along its local X, side by side along its local Z; local Y up): a dark
-- core 0.06 under the top, boards ~0.95 wide with 0.06 gaps and chamfered top edges whose TOPS are the row's top,
-- butt joints on boards over 9 long, nails at both ends and at every `nailX` (local X), cracks and knots; swamp: more
-- cracks, a rotten darker board now and then, flat algae stains at the ends (0.015 proud)
local function boards(U: any, rng: Random, r: any, nailX: { number }, swamp: boolean)
	local s, cf = r.size, r.cf
	local t = math.min(0.28, s.Y * 0.6)
	table.insert(U.Core, piece("Part", Vector3.new(s.X - 0.04, s.Y - 0.06, s.Z - 0.04), cf * CFrame.new(0, -0.03, 0), scaled(r.color, 0.45)))
	local n = math.max(1, math.floor(s.Z / 0.95 + 0.5))
	local bw = s.Z / n
	local prev = { 0 }
	for i = 0, n - 1 do
		local z = -s.Z / 2 + (i + 0.5) * bw
		local col = tone(rng, r.color, prev)
		if swamp and rng:NextNumber() < 0.15 then
			col = col:Lerp(MUD_DARK, 0.35)
		end
		local trim0, trim1 = rng:NextNumber(0, 0.1), rng:NextNumber(0, 0.1)
		local x0, x1 = -s.X / 2 + trim0, s.X / 2 - trim1
		local pieces = { { x0, x1 } }
		if s.X > 9 then
			local j = (if i % 2 == 0 then -1 else 1) * s.X * rng:NextNumber(0.12, 0.28)
			pieces = { { x0, j - 0.03 }, { j + 0.03, x1 } }
		end
		for _, pc in ipairs(pieces) do
			local len = pc[2] - pc[1]
			local c = if #pieces > 1 then tone(rng, col, nil) else col
			local bcf = cf * CFrame.new((pc[1] + pc[2]) / 2, s.Y / 2 - t / 2, z)
			table.insert(U.Deck, chamfered(Vector3.new(len, t, bw - 0.06), bcf, c, { "topFrontBack" }, 0.04))
			-- a nail at each end of each piece
			for _, x in ipairs({ pc[1] + 0.3, pc[2] - 0.3 }) do
				table.insert(U.Nails, piece("Part", Vector3.new(0.12, 0.05, 0.12), cf * CFrame.new(x, s.Y / 2 + 0.02, z + rng:NextNumber(-0.08, 0.08)), NAIL))
			end
		end
		for _, x in ipairs(nailX) do
			if x > -s.X / 2 + 0.6 and x < s.X / 2 - 0.6 then
				table.insert(U.Nails, piece("Part", Vector3.new(0.12, 0.05, 0.12), cf * CFrame.new(x, s.Y / 2 + 0.02, z), NAIL))
			end
		end
		-- a crack (a thin dark line along the board) and a knot
		if rng:NextNumber() < (if swamp then 0.55 else 0.3) then
			local len = rng:NextNumber(1.0, 2.4)
			local x = rng:NextNumber(x0 + len / 2 + 0.4, x1 - len / 2 - 0.4)
			table.insert(U.Wear, piece("Part", Vector3.new(len, 0.02, 0.05), cf * CFrame.new(x, s.Y / 2 + 0.005, z + rng:NextNumber(-bw * 0.2, bw * 0.2)) * CFrame.Angles(0, rad(rng:NextNumber(-3, 3)), 0), CRACK))
		end
		if rng:NextNumber() < 0.3 then
			table.insert(U.Wear, piece("Part", Vector3.new(0.02, 0.28, 0.2), cf * CFrame.new(rng:NextNumber(x0 + 1, x1 - 1), s.Y / 2 + 0.005, z) * CFrame.Angles(0, 0, rad(90)), scaled(col, 0.7), { shape = Enum.PartType.Cylinder }))
		end
		if swamp and rng:NextNumber() < 0.45 then
			local e = if rng:NextNumber() < 0.5 then x0 + 0.5 else x1 - 0.5
			table.insert(U.Stain, piece("Part", Vector3.new(rng:NextNumber(0.6, 1.1), 0.02, bw * rng:NextNumber(0.5, 0.8)), cf * CFrame.new(e, s.Y / 2 + 0.006, z) * CFrame.Angles(0, rad(rng:NextNumber(-12, 12)), 0), scaled(MOSS, rng:NextNumber(0.8, 1.0))))
		end
	end
end
PD.boards = boards

-- the axis ends of a row's long axis (bottom, top for a vertical-ish one)
local function ends(r: any, axis: string): (Vector3, Vector3)
	local v = if axis == "X" then r.cf.XVector * r.size.X else if axis == "Y" then r.cf.YVector * r.size.Y else r.cf.ZVector * r.size.Z
	local a, b = r.cf.Position - v / 2, r.cf.Position + v / 2
	if a.Y > b.Y then
		a, b = b, a
	end
	return a, b
end
local function longAxis(r: any): string
	local s = r.size
	if s.X >= s.Y and s.X >= s.Z then
		return "X"
	elseif s.Y >= s.Z then
		return "Y"
	end
	return "Z"
end
local function atY(a: Vector3, b: Vector3, y: number): Vector3
	return a:Lerp(b, math.clamp((y - a.Y) / (b.Y - a.Y), 0, 1))
end

-- a plains grass tuft (4-6 thin blades) at `base`
local function grass(list: { BasePart }, rng: Random, base: Vector3, s: number)
	for _ = 1, rng:NextInteger(4, 6) do
		local h = rng:NextNumber(0.5, 1.0) * s
		local cf = CFrame.new(base + Vector3.new(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(rad(rng:NextNumber(-14, 14)), 0, rad(rng:NextNumber(-14, 14)))
		table.insert(list, piece("WedgePart", Vector3.new(0.05, h, 0.22 * s), cf * CFrame.new(0, h / 2 - 0.05, 0), GRASS[rng:NextInteger(1, 3)]))
	end
end
PD.grass = grass

-- a round 8-sided log post from `a` (bottom) to `b` (top), r across the flats: a cap disc and a low dome on top (`cap`),
-- an iron band, a rope wrap at ropeY; plains grass at the foot, swamp algae + mud at the foot
local function roundPost(U: any, rng: Random, a: Vector3, b: Vector3, r: number, color: Color3, o: any)
	local axis = (b - a).Unit
	local L = (b - a).Magnitude
	local F = H.frameY(a, axis) * CFrame.Angles(0, rad(22.5), 0)
	table.insert(U.Wood, frustumN(8, r, r * 0.95, 0, L, F, { color, scaled(color, 1.1), scaled(color, 0.9), scaled(color, 1.04) }))
	if o.cap then
		table.insert(U.Wood, frustumN(8, r + 0.07, r + 0.05, L, L + 0.13, F, { scaled(color, 0.82), scaled(color, 0.9) }))
		table.insert(U.Wood, frustumN(8, r * 0.78, r * 0.3, L + 0.13, L + 0.3, F, { scaled(color, 1.12), scaled(color, 1.0) }))
	end
	if o.bandY then
		table.insert(U.Iron, frustumN(8, r + 0.05, r + 0.05, -0.13, 0.13, H.frameY(atY(a, b, o.bandY), axis) * CFrame.Angles(0, rad(22.5), 0), { o.iron, scaled(o.iron, 0.85) }))
	end
	if o.ropeY then
		lashing(U.Rope, atY(a, b, o.ropeY), axis, r, 3, rng)
	end
	if o.swamp then
		table.insert(U.Moss, frustumN(8, r + 0.06, r + 0.05, -0.2, 0.2, H.frameY(atY(a, b, a.Y + 0.35), axis) * CFrame.Angles(0, rad(22.5), 0), { WATER, scaled(WATER, 1.15) }))
		table.insert(U.Moss, frustumN(8, r + 0.05, r + 0.02, -0.18, 0.18, H.frameY(atY(a, b, a.Y + 0.72), axis) * CFrame.Angles(0, rad(22.5), 0), { MOSS, scaled(MOSS, 1.12) }))
		lump(U.Mud, rng, CFrame.new(a.X, a.Y + 0.08, a.Z), r + 0.45, 0.28, r + 0.4, function(n: Vector3): Color3
			return if n.Y > 0.5 then scaled(MUD_DARK, 1.15) else MUD_DARK
		end, 0.08)
	elseif o.grass then
		-- on the inner sides (the piece keeps its size)
		grass(U.Grass, rng, a + Vector3.new(-math.sign(a.X) * (r + 0.2), 0, 0.1), 1)
		grass(U.Grass, rng, a + Vector3.new(-0.2, 0, -math.sign(a.Z) * (r + 0.2)), 0.8)
	end
end
PD.roundPost = roundPost

-- a square post (a kit row, vertical): a chamfered timber, a pyramid cap, an iron band
local function squarePost(U: any, rng: Random, r: any, o: any)
	table.insert(U.Wood, chamfered(r.size, r.cf, tone(rng, r.color), { "vertical" }, 0.1))
	local top = r.cf * CFrame.new(0, r.size.Y / 2, 0)
	table.insert(U.Wood, frustumN(4, r.size.X / 2 + 0.07, 0.1, 0, 0.32, top * CFrame.Angles(0, rad(45), 0), { scaled(r.color, 1.1), scaled(r.color, 0.92) }))
	table.insert(U.Iron, piece("Part", Vector3.new(r.size.X + 0.1, 0.24, r.size.Z + 0.1), r.cf * CFrame.new(0, -r.size.Y * 0.12, 0), o.iron))
	local a = (r.cf * CFrame.new(0, -r.size.Y / 2, 0)).Position
	if o.swamp and a.Y < o.deckBottom then
		table.insert(U.Moss, piece("Part", Vector3.new(r.size.X + 0.1, 0.4, r.size.Z + 0.1), CFrame.new(a + Vector3.new(0, 0.35, 0)) * (r.cf - r.cf.Position), WATER))
	end
end

-- a timber row (stringer / rail): chamfered, bevelled top (rails), 3 bolts (stringers)
local function timberRow(U: any, rng: Random, r: any, isRail: boolean, o: any)
	local ax = longAxis(r)
	local sets = if ax == "Z" then { "topSides", "bottomSides" } else { "topFrontBack", "bottomFrontBack" }
	table.insert(U.Wood, chamfered(r.size, r.cf, tone(rng, r.color), sets, math.min(r.size.X, r.size.Y, r.size.Z) * (if isRail then 0.3 else 0.18)))
	if not isRail then
		local len = if ax == "Z" then r.size.Z else r.size.X
		for _, f in ipairs({ -0.35, 0, 0.35 }) do
			local off = if ax == "Z" then Vector3.new(r.size.X / 2 + 0.02, 0, f * len) else Vector3.new(f * len, 0, r.size.Z / 2 + 0.02)
			H.rivet(U.Iron, (r.cf * CFrame.new(off)).Position, 0.13)
			H.rivet(U.Iron, (r.cf * CFrame.new(-off)).Position, 0.13)
		end
	end
end

-- an iron U-bracket holding a rail (row) to a post at world point p: 3 straps round the rail section, 2 rivets
local function bracket(U: any, rail: any, p: Vector3, o: any)
	local ax = longAxis(rail)
	local local0 = rail.cf:PointToObjectSpace(p)
	local s = rail.size
	local at = if ax == "Z" then CFrame.new(0, 0, local0.Z) else CFrame.new(local0.X, 0, 0)
	local w = 0.26
	if ax == "Z" then
		table.insert(U.Iron, piece("Part", Vector3.new(s.X + 0.12, 0.06, w), rail.cf * at * CFrame.new(0, s.Y / 2 + 0.03, 0), o.iron))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.06, s.Y + 0.4, w), rail.cf * at * CFrame.new(sx * (s.X / 2 + 0.03), -0.17, 0), o.iron))
			H.rivet(U.Iron, (rail.cf * at * CFrame.new(sx * (s.X / 2 + 0.07), -s.Y / 2 - 0.12, 0)).Position, 0.11)
		end
	else
		table.insert(U.Iron, piece("Part", Vector3.new(w, 0.06, s.Z + 0.12), rail.cf * at * CFrame.new(0, s.Y / 2 + 0.03, 0), o.iron))
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(w, s.Y + 0.4, 0.06), rail.cf * at * CFrame.new(0, -0.17, sz * (s.Z / 2 + 0.03)), o.iron))
			H.rivet(U.Iron, (rail.cf * at * CFrame.new(0, -s.Y / 2 - 0.12, sz * (s.Z / 2 + 0.07))).Position, 0.11)
		end
	end
end

-- an iron lantern hook (no lamp, no light) on a post: an arm out along `out` near the post top and an S-hook
local function hook(U: any, top: Vector3, out: Vector3, o: any)
	local d = Vector3.new(out.X, 0, out.Z).Unit
	local a = top + d * 0.3
	local b = top + d * 0.92
	table.insert(U.Iron, H.bar(a, b, 0.12, o.iron))
	table.insert(U.Iron, H.bar(a - Vector3.new(0, 0.5, 0), a + d * 0.45, 0.08, o.iron))
	table.insert(U.Iron, H.bar(b, b - Vector3.new(0, 0.35, 0), 0.06, o.iron))
	table.insert(U.Iron, H.bar(b - Vector3.new(0, 0.35, 0), b - Vector3.new(0, 0.42, 0) + d * 0.16, 0.06, o.iron))
	table.insert(U.Iron, H.bar(b - Vector3.new(0, 0.42, 0) + d * 0.16, b - Vector3.new(0, 0.28, 0) + d * 0.2, 0.06, o.iron))
end

---------------------------------------------------------------------
-- the build: one recipe for the 6 pieces
---------------------------------------------------------------------
function PD.build(propId: string): Model
	local st = PD.STYLES[propId]
	local kit = st.kit
	local m = Instance.new("Model")
	m.Name = propId
	local rng = Random.new(20261024 + #propId * 7)
	H.setBevelSelf(true)
	local U: any = { Core = {}, Deck = {}, Nails = {}, Wear = {}, Wood = {}, Rope = {}, Iron = {}, Grass = {}, Moss = {}, Stain = {}, Mud = {}, Mush = {}, Hang = {}, RailLeft = {}, RailRight = {} }
	-- the lists a rail (its timber, brackets, moss) goes into: a split side rail gets its own union
	local function railList(r: any): any
		if st.splitRails and longAxis(r) == "Z" then
			local L = U[if r.cf.X < 0 then "RailLeft" else "RailRight"]
			return { Wood = L, Iron = L, Hang = L }
		end
		return U
	end
	local R = rows(kit)
	local planks, stringers, rails, posts, supports = {}, {}, {}, {}, {}
	local deckTop, deckBottom = -math.huge, math.huge
	for _, r in ipairs(R) do
		if r.name == "Plank" then
			table.insert(planks, r)
			deckTop = math.max(deckTop, r.cf.Y + r.size.Y / 2)
			deckBottom = math.min(deckBottom, r.cf.Y - r.size.Y / 2)
		end
	end
	local o = { swamp = st.swamp, iron = if st.swamp then IRON_RUST else IRON, deckBottom = deckBottom }
	for _, r in ipairs(R) do
		if r.name == "Rail" or (r.name == "Part" and r.size.Y < 2 and r.cf.Y > deckTop) then
			table.insert(rails, r)
		elseif r.name == "Stringer" or (r.name == "Part" and r.size.Y < 2) then
			table.insert(stringers, r)
		elseif r.name == "Post" or r.name == "Pile" or r.name == "Stilt" or (r.name == "Part" and r.size.Y >= 2) then
			table.insert(posts, r)
		end
	end
	-- the deck boards (nails over every stringer)
	for _, r in ipairs(planks) do
		local nx = {}
		for _, sr in ipairs(stringers) do
			if longAxis(sr) == "Z" then
				table.insert(nx, r.cf:PointToObjectSpace(Vector3.new(sr.cf.X, r.cf.Y, r.cf.Z)).X)
			end
		end
		boards(U, rng, r, nx, st.swamp)
	end
	local ramp = nil
	for _, r in ipairs(R) do
		if r.name == "Ramp" then
			ramp = r
			boards(U, rng, r, { -2.2, 2.2 }, st.swamp)
		end
	end
	for _, r in ipairs(stringers) do
		timberRow(U, rng, r, false, o)
	end
	for _, r in ipairs(rails) do
		timberRow(railList(r), rng, r, true, o)
	end
	-- posts: round logs (piles, stilts, the platforms' posts) or square capped posts (the rail decks), plus the ramp's
	-- square supports
	local centre = Vector3.new(0, deckTop, 0)
	for k, r in ipairs(posts) do
		local square = (not st.roundPosts) or (r.name == "Part")
		if square then
			squarePost(U, rng, r, o)
			local a = (r.cf * CFrame.new(0, -r.size.Y / 2, 0)).Position
			table.insert(supports, { a = a, b = (r.cf * CFrame.new(0, r.size.Y / 2, 0)).Position, r = r.size.X / 2, square = true, color = r.color })
			if not st.swamp and a.Y <= 0.05 then
				grass(U.Grass, rng, a + Vector3.new(r.size.X / 2 + 0.2, 0, 0), 0.9)
			end
		else
			local a, b = ends(r, longAxis(r))
			local rr = math.min(r.size.X, r.size.Y, r.size.Z) / 2 + 0.02
			local over = b.Y > deckTop + 0.3
			roundPost(U, rng, a, b, rr, r.color, {
				cap = true, iron = o.iron, swamp = st.swamp, grass = not st.swamp,
				bandY = a.Y + (math.min(b.Y, deckBottom) - a.Y) * 0.45,
				ropeY = if over then deckTop + math.min(0.45, (b.Y - deckTop) * 0.5) else deckBottom - 0.35,
			})
			table.insert(supports, { a = a, b = b, r = rr, color = r.color })
		end
		-- swamp: mushrooms at 2 feet, moss on a cap, a lantern hook on 2 posts that stand over the deck
		if st.swamp then
			local sup = supports[#supports]
			if k == 1 or k == #posts then
				-- (not at a post standing on the deck: never on the walk surface)
				if sup.a.Y < deckTop - 0.1 then
					SH.mushrooms(U.Mush, rng, sup.a + Vector3.new(0.75, 0.25, 0.2), 3, 0.45)
				end
			end
			if k == 2 then
				SH.mossPatch(U.Moss, rng, CFrame.new(sup.b + Vector3.new(0, 0.12, 0)), 0.9, 0.9, 0.5)
			end
			if st.hook and sup.b.Y > deckTop + 1.2 and (if st.hook == "X" then math.abs(sup.b.Z - centre.Z) < 1 else sup.b.Z - centre.Z > 1) then
				local out = if st.hook == "X" then Vector3.new(math.sign(sup.b.X - centre.X), 0, 0) else Vector3.zAxis
				hook(U, sup.b - Vector3.new(0, 0.55, 0), out, o)
			end
		end
	end
	-- rails held by iron U-brackets at every post they cross
	for _, rl in ipairs(rails) do
		local ax = longAxis(rl)
		for _, sp in ipairs(supports) do
			if sp.b.Y > rl.cf.Y and sp.a.Y < rl.cf.Y then
				local p = atY(sp.a, sp.b, rl.cf.Y)
				local lp = rl.cf:PointToObjectSpace(p)
				local half = if ax == "Z" then rl.size.Z / 2 else rl.size.X / 2
				local along = if ax == "Z" then lp.Z else lp.X
				local across = if ax == "Z" then lp.X else lp.Z
				if math.abs(across) < 1.0 and math.abs(along) < half - 0.2 then
					bracket(railList(rl), rl, p, o)
				end
			end
		end
	end
	-- X braces between neighbouring supports on the long sides, on their inner faces, under the deck and the stringers
	local braceTop = deckBottom
	for _, sr in ipairs(stringers) do
		braceTop = math.min(braceTop, sr.cf.Y - sr.size.Y / 2)
	end
	for i = 1, #supports do
		for j = i + 1, #supports do
			local s1, s2 = supports[i], supports[j]
			local d = Vector3.new(s2.a.X - s1.a.X, 0, s2.a.Z - s1.a.Z)
			local yLo, yHi = math.max(s1.a.Y, s2.a.Y) + 0.5, braceTop - 0.2
			local between = false
			for k, s3 in ipairs(supports) do
				if k ~= i and k ~= j and math.abs(s3.a.X - s1.a.X) < 1.5 and (s3.a.Z - s1.a.Z) * (s3.a.Z - s2.a.Z) < 0 then
					between = true
				end
			end
			if not between and not s1.square and not s2.square and yHi - yLo > 1.2 and math.abs(s1.a.X - s2.a.X) < 1.5 and d.Magnitude < 18 and d.Magnitude > 4 then
				local out = Vector3.new(-math.sign(s1.a.X), 0, 0)
				local p1, q1 = atY(s1.a, s1.b, yLo) + out * (s1.r + 0.18), atY(s2.a, s2.b, yHi) + out * (s2.r + 0.18)
				local p2, q2 = atY(s2.a, s2.b, yLo) + out * (s2.r + 0.42), atY(s1.a, s1.b, yHi) + out * (s1.r + 0.42)
				table.insert(U.Wood, H.bar(p1, q1, 0.28, tone(rng, scaled(s1.color, 1.08))))
				table.insert(U.Wood, H.bar(p2, q2, 0.28, tone(rng, scaled(s2.color, 1.08))))
				lashing(U.Rope, (p1 + q1 + p2 + q2) / 4 + out * 0.12, (q1 - p1).Unit, 0.18, 2, rng)
			end
		end
	end
	-- swamp: hanging moss under the deck's long edges, a few strands from the rails
	if st.swamp then
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, r in ipairs(planks) do
			minX, maxX = math.min(minX, r.cf.X - r.size.X / 2), math.max(maxX, r.cf.X + r.size.X / 2)
			minZ, maxZ = math.min(minZ, r.cf.Z - r.size.Z / 2), math.max(maxZ, r.cf.Z + r.size.Z / 2)
		end
		-- (not under a deck lying on its pivot level: the strands would add to its height)
		for _, q in ipairs(if deckBottom > 1 then { { -1, -0.3, 1.3 }, { -1, 0.25, 0.9 }, { 1, -0.1, 1.5 }, { 1, 0.35, 1.0 } } else {}) do
			local x = if q[1] < 0 then minX + 0.15 else maxX - 0.15
			SH.hangingMoss(U.Hang, rng, Vector3.new(x, deckBottom + 0.05, q[2] * (maxZ - minZ)), q[3])
		end
		if #rails > 0 then
			local rl = rails[#rails]
			SH.hangingMoss(railList(rl).Hang, rng, (rl.cf * CFrame.new(0, -rl.size.Y / 2, 0)).Position, 0.9)
		end
	end
	if not st.swamp and deckBottom <= 0.05 then
		for _, r in ipairs(planks) do
			for _, sx in ipairs({ -1, 1 }) do
				if rng:NextNumber() < 0.7 then
					grass(U.Grass, rng, (r.cf * CFrame.new(sx * (r.size.X / 2 + 0.22), -r.size.Y / 2, rng:NextNumber(-1, 1))).Position, rng:NextNumber(0.7, 1.0))
				end
			end
		end
	end
	if ramp then
		-- the ramp's foot in a flat mud patch (0.1 tall at most: players walk onto the ramp over it)
		local foot = (ramp.cf * CFrame.new(0, 0, ramp.size.Z / 2)).Position
		lump(U.Mud, rng, CFrame.new(foot.X, -0.02, foot.Z), 3.2, 0.12, 0.9, function(): Color3
			return MUD_DARK
		end, 0.05)
	end

	TB.finishTB(m, propId, U, "Deck", {})
	-- collisions: every colliding kit row, except the rows each game copy keeps as its own walk colliders
	for _, r in ipairs(R) do
		if r.collide and not (st.walkKeep and st.walkKeep[r.name]) then
			local split = st.splitRails and r.name == "Part" and r.size.Y < 2 and r.cf.Y > deckTop and longAxis(r) == "Z"
			collider(m, r, if split then (if r.cf.X < 0 then "CollisionRailLeft" else "CollisionRailRight") else nil)
		end
	end
	-- the variants (Configuration attributes by part name, applied by SyncMapProps to the copies with that Variant)
	if PD.VARIANTS[propId] then
		local folder = Instance.new("Folder")
		folder.Name = "_Variants"
		for name, attrs in pairs(PD.VARIANTS[propId]) do
			local config = Instance.new("Configuration")
			config.Name = name
			for key, value in pairs(attrs) do
				config:SetAttribute(key, value)
			end
			config.Parent = folder
		end
		folder.Parent = m
	end
	return m
end

-- before the first sync of a piece with walkKeep rows: on every copy found (test, kit, game) its own rows of those names
-- become invisible colliders in a folder "WalkCollision" (MapPropKeep): today's exact walk surface stays on each copy
function PD.prepWalk(propId: string): string
	local st = PD.STYLES[propId]
	if not st.walkKeep then
		return propId .. ": no walk rows to keep"
	end
	local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
	local made, already, parts = 0, 0, 0
	for _, m in ipairs(Sync.find(propId)) do
		if m:FindFirstChild("WalkCollision") or m:GetAttribute("MapPropVersion") ~= nil then
			already += 1
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = "WalkCollision"
		folder:SetAttribute("MapPropKeep", true)
		for _, c in ipairs(m:GetChildren()) do
			if c:IsA("BasePart") and st.walkKeep[c.Name] then
				c.Name = "Collision"
				c.Transparency = 1
				c.CastShadow = false
				c.Parent = folder
				parts += 1
			end
		end
		folder.Parent = m
		made += 1
	end
	return string.format("%s: WalkCollision made on %d copies (%d parts), %d already", propId, made, parts, already)
end

---------------------------------------------------------------------
-- registration: the 6 builders go into the same PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
PD.BUILDERS = {}
for id in pairs(PD.STYLES) do
	PD.BUILDERS[id] = true
	B2[id] = function(): Model
		return PD.build(id)
	end
	B2.BUILDERS[id] = true
end
PD.install = B2.install
PD.stats = B2.stats

return PD
