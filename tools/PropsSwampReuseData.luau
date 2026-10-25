--[[
	PropsSwampReuseData (dev tool data) - the 4 cursed swamp kits of the owner's "CURSED SWAMP PROP IMPROVEMENT - Objects
	reused from other biomes" (2026-10-25) as they were before the remake, read from the kits in
	ServerStorage.MapAssets.Swamp. Every copy is its kit at a Model scale. 4 Potion_Barrel copies have a purple Liquid
	(#AA50FF, Variant Purple). Rowboat_Sunk carries the model attribute SinkDepth = 1 (kept on the copies). Generated in
	Studio from the live parts. One row per part: { name, class, shape, sx, sy, sz, the 12 CFrame components (pivot
	space), hex, collide, transparency, material, query, parent ("" = the model, else the parent part's name), meshId,
	collision fidelity }. Source of truth: tools/PropsSwampReuseData.luau.
]]
local Data = {}

Data.Potion_Barrel = {
	{ "Body", "Part", "Cylinder", 4, 3, 3, 0, 2, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Belly", "Part", "Cylinder", 2, 3.4000001, 3.4000001, 0, 2, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Band", "Part", "Cylinder", 0.349999994, 3.45000005, 3.45000005, 0, 1, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Band", "Part", "Cylinder", 0.349999994, 3.45000005, 3.45000005, 0, 3, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "373a41", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Lid", "Part", "Cylinder", 0.100000001, 2.5999999, 2.5999999, 0, 4, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Liquid", "Part", "Cylinder", 0.200000003, 2.0999999, 2.0999999, 0, 4.07000017, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "8cff5a", false, 0, "Neon", true, "", "", "" },
}

Data.Scarecrow_Swamp = {
	{ "Pole", "Part", "Block", 0.600000024, 7, 0.600000024, 0, 3.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Arms", "Part", "Block", 7, 0.5, 0.5, 0, 5.4000001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Shirt", "Part", "Block", 2.5999999, 3, 1.39999998, 0, 4.69999981, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "622ca0", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Hay", "Part", "Block", 1.20000005, 0.899999976, 0.800000012, -3.39990234, 5.30000019, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Hay", "Part", "Block", 1.20000005, 0.899999976, 0.800000012, 3.39990234, 5.30000019, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Hay", "Part", "Block", 2.79999995, 0.699999988, 1.60000002, 0, 3.0999999, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "80783e", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Head", "Part", "Ball", 2.20000005, 2.20000005, 2.20000005, 0, 7.19999981, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ded6be", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "HatBrim", "Part", "Cylinder", 0.300000012, 3.5999999, 3.5999999, 0, 8, 0, -0.104528509, -0.994521916, 0, 0.994521916, -0.104528509, 0, 0, 0, 1, "1e1613", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "HatTop", "Part", "Cylinder", 1.29999995, 2, 2, -0.080078125, 8.69999981, 0, -0.104528509, -0.994521916, 0, 0.994521916, -0.104528509, 0, 0, 0, 1, "1e1613", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Eye", "Part", "Block", 0.300000012, 0.300000012, 0.200000003, -0.449951172, 7.4000001, -1.02000046, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ffe860", true, 0, "Neon", true, "", "", "" },
	{ "Eye", "Part", "Block", 0.300000012, 0.300000012, 0.200000003, 0.449951172, 7.4000001, -1.02000046, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ffe860", true, 0, "Neon", true, "", "", "" },
}

Data.Rowboat_Sunk = {
	{ "Bottom", "Part", "Block", 9, 0.600000024, 3.5999999, -0.519775391, 1.36673176, -0.0990428925, 0.997564077, -0.0697564706, 0, 0.0646770746, 0.924925327, 0.37460658, -0.0261312332, -0.373694062, 0.927183867, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Side", "Part", "Block", 9, 2.4000001, 0.5, -0.603515625, 1.68996835, -2.49456215, 0.997564077, -0.0676844046, -0.0168756172, 0.0646770746, 0.806825578, 0.587238848, -0.0261312332, -0.586899817, 0.809237719, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "SideBroken", "Part", "Block", 4.5, 2.4000001, 0.5, -2.84790039, 3.11779261, 1.45840645, 0.997564077, -0.0676844046, 0.0168756172, 0.0646770746, 0.988076627, 0.139719471, -0.0261312332, -0.138287663, 0.990047336, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "SideBroken", "Part", "Block", 2.20000005, 1.20000005, 0.5, 1.13427734, 2.78085089, 1.4866848, 0.978435993, -0.205859795, 0.0168756172, 0.201561347, 0.969459414, 0.139719471, -0.0451228544, -0.133305073, 0.990047336, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bow", "WedgePart", "", 2.5999999, 2.4000001, 4.5, 6.14404297, 2.2786994, -1.76174355, -0.0697564706, 0, -0.997564077, 0.924925327, -0.37460658, -0.0646770746, -0.373694062, -0.927183867, 0.0261312332, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bow", "WedgePart", "", 2.5999999, 2.4000001, 4.5, 6.14404297, 3.17775536, 0.463499069, 0.0697564706, 0, -0.997564077, -0.924925327, 0.37460658, -0.0646770746, 0.373694062, 0.927183867, 0.0261312332, "684c34", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Stern", "Part", "Block", 0.5, 2.5999999, 4.5999999, -5.28491211, 2.08016729, -0.387289047, 0.997564077, -0.0697564706, 0, 0.0646770746, 0.924925327, 0.37460658, -0.0261312332, -0.373694062, 0.927183867, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bench", "Part", "Block", 0.899999976, 0.400000006, 4, -2.61254883, 2.53227329, -0.569952011, 0.997564077, -0.0697564706, 0, 0.0646770746, 0.924925327, 0.37460658, -0.0261312332, -0.373694062, 0.927183867, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Bench", "Part", "Block", 0.899999976, 0.400000006, 4, 0.87890625, 2.75864291, -0.661411285, 0.997564077, -0.0697564706, 0, 0.0646770746, 0.924925327, 0.37460658, -0.0261312332, -0.373694062, 0.927183867, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "LoosePlank", "Part", "Block", 3.5999999, 0.400000006, 1, 2.5, 1.37159264, 4.5, 0.819152057, 0, 0.57357645, 0, 1, 0, -0.57357645, 0, 0.819152057, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Oar", "Part", "Cylinder", 7.56637287, 0.400000006, 0.400000006, -0.25, 1.42159271, -4.5, 0.991227865, 0, -0.132163689, 0, 1, 0, 0.132163674, 0, 0.991227984, "322620", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "OarBlade", "Part", "Block", 2, 0.25, 1, 4.19995117, 1.37159264, -3.89999962, 0.990268052, 0, -0.139173105, 0, 1, 0, 0.139173105, 0, 0.990268052, "816a52", true, 0, "SmoothPlastic", true, "", "", "" },
	{ "Moss", "Part", "Block", 4, 0.5, 3, 1, 2.20000005, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c823a", false, 0, "SmoothPlastic", false, "", "", "" },
}

Data.LilyPad_Swamp_A = {
	{ "Pad", "Part", "Cylinder", 0.25, 5.19999981, 5.19999981, 0, 0.129999995, 0, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "385a2e", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Pad", "Part", "Cylinder", 0.25, 3.20000005, 3.20000005, 3.4000001, 0.109999999, 1.79999995, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1, "5c823a", false, 0, "SmoothPlastic", false, "", "", "" },
	{ "Bloom", "Part", "Block", 1.29999995, 0.899999976, 1.29999995, 0.600000024, 0.649999976, -0.5, 0.707106769, 0, 0.707106769, 0, 1, 0, -0.707106769, 0, 0.707106769, "ded6be", false, 0, "SmoothPlastic", false, "", "", "" },
}

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
