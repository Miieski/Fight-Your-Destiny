--[[
	PropsSwampMagicData (dev tool data) - the 9 cursed swamp magic props and decor kits of the owner's "CURSED SWAMP PROP
	IMPROVEMENT - Magic props and decor" (2026-10-25) as they were before the remake, read from the kits in
	ServerStorage.MapAssets.Swamp. The copies are Model-scaled kits, but the colliders of Toad_Shrine, Toad_Totem,
	Cauldron_Small and Potion_Shelf drift from the kit (0.0001 .. 0.19, part-resized shelves): those copies keep their own
	colliders. 12 Potion_Bottle_A copies have a purple Liquid (#AA50FF, Variant Purple); the 10 Crow_A of the Realm of the
	Dead (#181820) are not part of this prop. Lights live on the copies (kept per copy), not here. The Spellbook_Floating
	kit stands at Model scale 1.6: its rows are stored at scale 1. Generated in Studio from the live parts. One row per part: { name, class, shape, sx, sy, sz, the 12 CFrame components (pivot space), hex,
	collide, transparency, material, query, parent ("" = the model, else the parent part's name), meshId, collision
	fidelity }. Source of truth: tools/PropsSwampMagicData.luau.
]]
local Data = {}

Data.Toad_Shrine = {
	{ "Part", "Part", "Block", 14, 1.20000005, 12, 0, 0.600000024, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 10, 1.20000005, 8, 0, 1.79999995, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "849487", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 7, 2.5999999, 5, 0, 3.70000005, 1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "ToadBody", "Part", "Block", 6, 3.4000001, 5, 0, 6.5, 1.70000005, 1, 0, 0, 0, 0.978147626, -0.2079117, 0, 0.2079117, 0.978147626, "849487", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "ToadHead", "Part", "Block", 5, 2.20000005, 3.4000001, 0, 8.69999981, -0.400000006, 1, 0, 0, 0, 1, 0, 0, 0, 1, "849487", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Eye", "Part", "Ball", 1.5, 1.5, 1.5, -1.60000002, 10.1000004, -0.600000024, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
	{ "Part", "Part", "Block", 1.29999995, 3.20000005, 1.29999995, -2.5999999, 6.30000019, -0.899999976, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 1.79999995, 1.79999995, 3, -3.29999995, 5.9000001, 2.5999999, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Cylinder", 0.800000012, 2.20000005, 2.20000005, -5, 1.60000002, -3.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "849487", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "BowlGlow", "Part", "Cylinder", 0.200000003, 1.60000002, 1.60000002, -5, 2.05999994, -3.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
	{ "Eye", "Part", "Ball", 1.5, 1.5, 1.5, 1.60000002, 10.1000004, -0.600000024, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
	{ "Part", "Part", "Block", 1.29999995, 3.20000005, 1.29999995, 2.5999999, 6.30000019, -0.899999976, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 1.79999995, 1.79999995, 3, 3.29999995, 5.9000001, 2.5999999, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Cylinder", 0.800000012, 2.20000005, 2.20000005, 5, 1.60000002, -3.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "849487", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "BowlGlow", "Part", "Cylinder", 0.200000003, 1.60000002, 1.60000002, 5, 2.05999994, -3.5, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
	{ "Part", "Part", "Block", 4.19999981, 0.349999994, 0.400000006, 0, 8.19999981, -2.0999999, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Moss", "Part", "Block", 4, 0.400000006, 2.5999999, 0, 9.94999981, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c823a", false, 0, "SmoothPlastic", false, "", "", "" },
}

Data.Toad_Totem = {
	{ "Part", "Part", "Block", 6.4000001, 1, 6.4000001, 0, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "596864", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Toad", "Part", "Block", 5.4000001, 4.19999981, 4.80000019, 0, 3.0999999, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "385a2e", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Mouth", "Part", "Block", 4.32000017, 0.449999988, 0.400000006, 0, 2.70000005, -2.4000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Eye", "Part", "Ball", 1.60000002, 1.60000002, 1.60000002, -1.62, 5.19999981, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Pupil", "Part", "Block", 0.449999988, 0.699999988, 0.300000012, -1.62, 5.30000019, -2.27999997, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Foot", "Part", "Block", 1.39999998, 1.29999995, 1.79999995, -2.70000005, 1.64999998, -1.89999998, 1, 0, 0, 0, 1, 0, 0, 0, 1, "364d2a", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Eye", "Part", "Ball", 1.60000002, 1.60000002, 1.60000002, 1.62, 5.19999981, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Pupil", "Part", "Block", 0.449999988, 0.699999988, 0.300000012, 1.62, 5.30000019, -2.27999997, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Foot", "Part", "Block", 1.39999998, 1.29999995, 1.79999995, 2.70000005, 1.64999998, -1.89999998, 1, 0, 0, 0, 1, 0, 0, 0, 1, "364d2a", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Toad", "Part", "Block", 4.9000001, 4.19999981, 4.4000001, 0, 8.10000038, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c823a", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Mouth", "Part", "Block", 3.92000008, 0.449999988, 0.400000006, 0, 7.69999981, -2.20000005, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Eye", "Part", "Ball", 1.60000002, 1.60000002, 1.60000002, -1.47000003, 10.1999998, -1.29999995, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Pupil", "Part", "Block", 0.449999988, 0.699999988, 0.300000012, -1.47000003, 10.3000002, -2.07999992, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Foot", "Part", "Block", 1.39999998, 1.29999995, 1.79999995, -2.45000005, 6.6500001, -1.70000005, 1, 0, 0, 0, 1, 0, 0, 0, 1, "516b33", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Eye", "Part", "Ball", 1.60000002, 1.60000002, 1.60000002, 1.47000003, 10.1999998, -1.29999995, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Pupil", "Part", "Block", 0.449999988, 0.699999988, 0.300000012, 1.47000003, 10.3000002, -2.07999992, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Foot", "Part", "Block", 1.39999998, 1.29999995, 1.79999995, 2.45000005, 6.6500001, -1.70000005, 1, 0, 0, 0, 1, 0, 0, 0, 1, "516b33", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Toad", "Part", "Block", 4.4000001, 4.19999981, 4, 0, 13.1000004, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Mouth", "Part", "Block", 3.51999998, 0.449999988, 0.400000006, 0, 12.6999998, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Eye", "Part", "Ball", 1.60000002, 1.60000002, 1.60000002, -1.32000005, 15.1999998, -1.10000002, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Pupil", "Part", "Block", 0.449999988, 0.699999988, 0.300000012, -1.32000005, 15.3000002, -1.88, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Foot", "Part", "Block", 1.39999998, 1.29999995, 1.79999995, -2.20000005, 11.6499996, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "6c6336", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Eye", "Part", "Ball", 1.60000002, 1.60000002, 1.60000002, 1.32000005, 15.1999998, -1.10000002, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Pupil", "Part", "Block", 0.449999988, 0.699999988, 0.300000012, 1.32000005, 15.3000002, -1.88, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Foot", "Part", "Block", 1.39999998, 1.29999995, 1.79999995, 2.20000005, 11.6499996, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "6c6336", true, 0, "SmoothPlastic", true, "", "", "" },
}

Data.Skull_Knocker_Door = {
	{ "Cranium", "Part", "Block", 2.5999999, 2.20000005, 1.39999998, 0, 3.5999999, -0.699999988, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Jaw", "Part", "Block", 1.79999995, 0.899999976, 1.10000002, 0, 2.20000005, -0.600000024, 1, 0, 0, 0, 1, 0, 0, 0, 1, "bdb39b", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Socket", "Part", "Block", 0.800000012, 0.800000012, 0.300000012, -0.649999976, 3.70000005, -1.36000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Eye", "Part", "Block", 0.400000006, 0.400000006, 0.300000012, -0.649999976, 3.70000005, -1.45000005, 1, 0, 0, 0, 1, 0, 0, 0, 1, "aa50ff", false, 0, "Neon", false, "", "", "" },
	{ "Socket", "Part", "Block", 0.800000012, 0.800000012, 0.300000012, 0.649999976, 3.70000005, -1.36000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Eye", "Part", "Block", 0.400000006, 0.400000006, 0.300000012, 0.649999976, 3.70000005, -1.45000005, 1, 0, 0, 0, 1, 0, 0, 0, 1, "aa50ff", false, 0, "Neon", false, "", "", "" },
	{ "Part", "Part", "Block", 0.349999994, 0.5, 0.300000012, 0, 2.95000005, -1.36000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 1.39999998, 0.300000012, 0.200000003, 0, 2.45000005, -1.12, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Ring", "Part", "Block", 2.20000005, 0.300000012, 0.300000012, 0, 0.150000006, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Ring", "Part", "Block", 0.300000012, 1.89999998, 0.300000012, -1.10000002, 1, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Ring", "Part", "Block", 0.300000012, 1.89999998, 0.300000012, 1.10000002, 1, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false, "", "", "" },
}

Data.Spellbook_Floating = { -- (the kit is at Model scale 1.6: rows at scale 1)
	{ "Cover", "Part", "Block", 1.69999999, 0.150000004, 2.30000001, -0.813807386, 0.104505083, 0, 0.95105654, 0.309017003, 0, -0.309017003, 0.95105654, 0, 0, 0, 1, "622ca0", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Pages", "Part", "Block", 1.50000004, 0.200000011, 2.0999999, -0.793807346, 0.274505034, 0, 0.95105654, 0.309017003, 0, -0.309017003, 0.95105654, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Cover", "Part", "Block", 1.69999999, 0.150000004, 2.30000001, 0.786192852, 0.104505046, 0, 0.9510566, -0.309017062, 0, 0.309017062, 0.9510566, 0, 0, 0, 1, "622ca0", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Pages", "Part", "Block", 1.50000004, 0.200000011, 2.0999999, 0.766192812, 0.274505052, 0, 0.9510566, -0.309017062, 0, 0.309017062, 0.9510566, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Rune", "Part", "Block", 0.600000015, 0.0599999996, 0.600000015, 0.766192812, 0.414505148, 0, 0.9510566, -0.309017062, 0, 0.309017062, 0.9510566, 0, 0, 0, 1, "aa50ff", false, 0, "Neon", false, "", "", "" },
}

Data.Potion_Bottle_A = {
	{ "Liquid", "Part", "Ball", 1.29999995, 1.29999995, 1.29999995, 0, 0.649999976, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", false, "", "", "" },
	{ "Part", "Part", "Block", 0.449999988, 0.600000024, 0.449999988, 0, 1.45000005, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "c7d3c0", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.550000012, 0.25, 0.550000012, 0, 1.85000002, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", false, 0, "SmoothPlastic", false, "", "", "" },
}

Data.Hanging_Lantern = {
	{ "Chain", "Part", "Block", 0.150000006, 2.9000001, 0.150000006, 0, 3.54999995, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 1.5, 0.300000012, 1.5, 0, 1.95000005, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 1.5, 0.300000012, 1.5, 0, 0.150000006, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Lantern", "Part", "Block", 1.20000005, 1.5, 1.20000005, 0, 1.04999995, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ffc460", false, 0, "Neon", false, "", "", "" },
}

Data.Cauldron_Small = {
	{ "Pot", "Part", "Ball", 4.4000001, 4.4000001, 4.4000001, 0, 2.9000001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Rim", "Part", "Cylinder", 0.600000024, 4.19999981, 4.19999981, 0, 4.9000001, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Liquid", "Part", "Cylinder", 0.200000003, 3.5, 3.5, 0, 5.21999979, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
	{ "Part", "Part", "Block", 0.5, 1.39999998, 0.5, 1.39999998, 0.699999988, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 0.5, 1.39999998, 0.5, -0.699999988, 0.699999988, 1.2124356, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 0.5, 1.39999998, 0.5, -0.699999988, 0.699999988, -1.2124356, 1, 0, 0, 0, 1, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 0.600000024, 0.600000024, 5.23964405, 0, 0.349999994, 0, -0.316227764, 0, -0.948683321, 0, 1, -0, 0.948683321, 0, -0.316227764, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 0.600000024, 0.600000024, 5.23964405, 0, 0.349999994, 0, 0.948683321, 0, -0.316227764, 0, 1, 0, 0.316227764, 0, 0.948683321, "4e3a2c", true, 0, "SmoothPlastic", true, "", "", "" },
}

Data.Potion_Shelf = {
	{ "Part", "Part", "Block", 0.400000006, 7, 1.60000002, 2.79999995, 3.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 0.400000006, 7, 1.60000002, -2.79999995, 3.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 5.5999999, 7, 0.200000003, 0, 3.5, 0.699999988, 1, 0, 0, 0, 1, 0, 0, 0, 1, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 5.5999999, 0.300000012, 1.60000002, 0, 0.600000024, 0, 0.999657333, 0.02617695, 0, -0.02617695, 0.999657333, 0, 0, 0, 1, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bottle", "Part", "Block", 0.699999988, 1.10000002, 0.699999988, -1.5, 1.29999995, -0.100000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
	{ "Bottle", "Part", "Block", 0.699999988, 1.29999995, 0.699999988, 0.5, 1.39999998, -0.100000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "aa50ff", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Part", "Part", "Block", 5.5999999, 0.300000012, 1.60000002, 0, 3.20000005, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bottle", "Part", "Block", 0.699999988, 1.10000002, 0.699999988, -1, 3.9000001, -0.100000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ffc460", false, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bottle", "Part", "Block", 0.699999988, 1.29999995, 0.699999988, 1, 4, -0.100000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "78ffd2", false, 0, "Neon", true, "", "", "" },
	{ "Part", "Part", "Block", 5.5999999, 0.300000012, 1.60000002, 0, 5.80000019, 0, 0.999657333, -0.02617695, 0, 0.02617695, 0.999657333, 0, 0, 0, 1, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bottle", "Part", "Block", 0.699999988, 1.10000002, 0.699999988, -0.5, 6.5, -0.100000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "622ca0", false, 0, "Neon", true, "", "", "" },
	{ "Bottle", "Part", "Block", 0.699999988, 1.29999995, 0.699999988, 1.5, 6.5999999, -0.100000001, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", false, 0, "SmoothPlastic", true, "", "", "" },
}

Data.Crow_A = {
	{ "Part", "Part", "Block", 1, 1.10000002, 2.20000005, 0, 1.29999995, 0, 1, 0, 0, 0, 0.939692616, -0.342020124, 0, 0.342020124, 0.939692616, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.800000012, 0.800000012, 0.800000012, 0, 2.1500001, -0.899999976, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.25, 0.25, 0.699999988, 0, 2.04999995, -1.60000002, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.699999988, 0.25, 1.29999995, 0, 0.850000024, 1.5, 1, 0, 0, 0, 0.906307757, -0.42261827, 0, 0.42261827, 0.906307757, "1e1613", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.200000003, 0.800000012, 1.79999995, 0.600000024, 1.39999998, 0.200000003, 1, 0, 0, 0, 0.939692616, -0.342020124, 0, 0.342020124, 0.939692616, "322620", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.200000003, 0.800000012, 1.79999995, -0.600000024, 1.39999998, 0.200000003, 1, 0, 0, 0, 0.939692616, -0.342020124, 0, 0.342020124, 0.939692616, "322620", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.119999997, 0.699999988, 0.119999997, 0.25, 0.349999994, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Part", "Part", "Block", 0.119999997, 0.699999988, 0.119999997, -0.25, 0.349999994, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", false, 0, "SmoothPlastic", false, "", "", "" },
}

-- the cauldron's SteamPoint Attachment (under the Liquid part; position in the Liquid's frame)
Data.SteamPoint = { parent = "Liquid", x = 0, y = 0, z = 0 }

-- a row as { name, class, shape, size, cf, color, collide, transparency, material, query, parent, meshId, fidelity }
function Data.rowOf(t: { any }): any
	return { name = t[1], class = t[2], shape = t[3], size = Vector3.new(t[4], t[5], t[6]), cf = CFrame.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16], t[17], t[18]), color = Color3.fromHex(t[19]), collide = t[20], transparency = t[21], material = t[22], query = t[23], parent = t[24], meshId = t[25], fidelity = t[26] }
end

-- the rows of a kit (all, or those named `name`), in the table's order
function Data.rows(kit: string, name: string?): { any }
	local out = {}
	for _, t in ipairs(Data[kit]) do
		if name == nil or t[1] == name then
			table.insert(out, Data.rowOf(t))
		end
	end
	return out
end

return Data
