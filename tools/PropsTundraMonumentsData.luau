--[[
	PropsTundraMonumentsData (dev tool data) - the 6 kits of the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Ice
	monuments, statues and shrines" (2026-10-22) as they were before the remake, read from ServerStorage.MapAssets.Tundra (every
	copy is the kit at a Model scale). One row per part: { name, class, shape, sx, sy, sz, x, y, z, r00, r01, r02, r10, r11,
	r12, r20, r21, r22, hex, collide, transparency, material, query [, meshId, collisionFidelity] }; the CFrame is in the
	kit's pivot space. The builders (DevTools.PropsTundraMonuments) place their details on these parts; the colliding rows
	become the invisible Collision parts (exact collisions). Source of truth: tools/PropsTundraMonumentsData.luau.
]]
local Data = {}

Data.Ice_Pillar = {
	{ "Base", "Part", "Block", 8, 3, 8, 0, 1.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3468b4", true, 0, "SmoothPlastic", true },
	{ "Capital", "Part", "Block", 6.4, 2, 6.4, 0, 36, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
	{ "Glow", "Part", "Block", 5.6, 0.4, 5.6, 0, 6.4, 0, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071, "60beff", false, 0, "Neon", false },
	{ "Glow", "Part", "Block", 5.6, 0.4, 5.6, 0, 33.6, 0, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071, "60beff", false, 0, "Neon", false },
	{ "Plinth", "Part", "Block", 6.4, 2, 6.4, 0, 4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
	{ "Shaft", "Part", "Block", 4.6, 30, 4.6, 0, 20, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic", true },
	{ "Shaft", "Part", "Block", 4.5, 30, 4.5, 0, 20, 0, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071, "54a0e8", true, 0, "SmoothPlastic", true },
	{ "Top", "Part", "Block", 8, 3, 8, 0, 38.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3468b4", true, 0, "SmoothPlastic", true },
}

Data.Frozen_Knight_Statue = {
	{ "Arm", "Part", "Block", 1.2, 3.6, 1.4, -2.7, 7.4, -0.5, 1, 0, 0, 0, 0.9397, -0.342, 0, 0.342, 0.9397, "686e7c", false, 0, "SmoothPlastic", false },
	{ "Arm", "Part", "Block", 1.2, 3.6, 1.4, 2.7, 7.4, -0.5, 1, 0, 0, 0, 0.9397, -0.342, 0, 0.342, 0.9397, "686e7c", false, 0, "SmoothPlastic", false },
	{ "Belt", "Part", "Block", 4.2, 0.7, 2.4, 0, 6.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ffc93c", false, 0, "SmoothPlastic", false },
	{ "Blade", "Part", "Block", 0.5, 6.6, 0.25, 0, 5.4, -1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f5f6fa", false, 0, "SmoothPlastic", false },
	{ "Grip", "Part", "Block", 0.4, 1.2, 0.4, 0, 9.6, -1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1, "703e26", false, 0, "SmoothPlastic", false },
	{ "Guard", "Part", "Block", 2.4, 0.4, 0.5, 0, 8.8, -1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ffc93c", false, 0, "SmoothPlastic", false },
	{ "Head", "Part", "Block", 2, 2, 2, 0, 11.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c626e", false, 0, "SmoothPlastic", false },
	{ "IceBlock", "Part", "Block", 7.4, 12.2, 6, 0, 8.1, -0.2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", true, 0.55, "Glass", true },
	{ "Leg", "Part", "Block", 1.5, 4, 1.6, -1, 4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c626e", false, 0, "SmoothPlastic", false },
	{ "Leg", "Part", "Block", 1.5, 4, 1.6, 1, 4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c626e", false, 0, "SmoothPlastic", false },
	{ "Plinth", "Part", "Block", 8, 2, 8, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3468b4", true, 0, "SmoothPlastic", true },
	{ "Plume", "Part", "Block", 0.5, 1.2, 1.8, 0, 12.6, 0.2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "baaaec", false, 0, "SmoothPlastic", false },
	{ "Shard", "MeshPart", "", 2.2, 5, 2, -4, 3.8, -2.6, 0.5243, -0.1307, 0.8415, 0.2419, 0.9703, 0, -0.8165, 0.2036, 0.5403, "d6ecff", false, 0.15, "SmoothPlastic", false, "rbxassetid://100106311518324", "Hull" },
	{ "Shard", "MeshPart", "", 1.8, 3.6, 1.6, 4, 3.2, -2.4, -0.4, -0.1147, 0.9093, -0.2756, 0.9613, 0, -0.8741, -0.2506, -0.4161, "96d6fa", false, 0.15, "SmoothPlastic", false, "rbxassetid://100106311518324", "Hull" },
	{ "Shoulder", "Part", "Block", 1.8, 1.4, 2.4, -2.7, 9.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c626e", false, 0, "SmoothPlastic", false },
	{ "Shoulder", "Part", "Block", 1.8, 1.4, 2.4, 2.7, 9.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c626e", false, 0, "SmoothPlastic", false },
	{ "SnowCap", "Part", "Block", 7.8, 0.6, 6.4, 0, 14.4, -0.2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", false, 0, "SmoothPlastic", false },
	{ "Torso", "Part", "Block", 4, 4.2, 2.2, 0, 8.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "686e7c", false, 0, "SmoothPlastic", false },
	{ "Visor", "Part", "Block", 1.4, 0.3, 0.2, 0, 11.3, -1.02, 1, 0, 0, 0, 1, 0, 0, 0, 1, "60beff", false, 0, "Neon", false },
}

Data.Ice_Throne_Small = {
	{ "ArmRest", "Part", "Block", 1.2, 2.4, 4.2, -3, 3.8, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic", true },
	{ "ArmRest", "Part", "Block", 1.2, 2.4, 4.2, 3, 3.8, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic", true },
	{ "Back", "Part", "Block", 5.4, 9, 1.4, 0, 7.3, 2.7, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
	{ "Crystal", "MeshPart", "", 2.4, 7.5, 2.2, -4.8, 3.6, 2.6, 0.0697, -0.0123, 0.9975, 0.1736, 0.9848, 0, -0.9823, 0.1732, 0.0707, "96d6fa", true, 0.15, "SmoothPlastic", true, "rbxassetid://100106311518324", "Hull" },
	{ "Crystal", "MeshPart", "", 2.4, 7.5, 2.2, 4.8, 3.6, 2.6, 0.9071, 0.1599, 0.3894, -0.1736, 0.9848, 0, -0.3835, -0.0676, 0.9211, "96d6fa", true, 0.15, "SmoothPlastic", true, "rbxassetid://100106311518324", "Hull" },
	{ "Gem", "Part", "Block", 0.9, 0.9, 0.5, 0, 9.6, 1.9, 0.7071, -0.7071, 0, 0.7071, 0.7071, 0, 0, 0, 1, "60beff", false, 0, "Neon", false },
	{ "Seat", "Part", "Block", 5, 1.6, 4.4, 0, 2.8, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic", true },
	{ "Spike", "MeshPart", "", 1.8, 5, 1.6, -2, 13.6, 2.7, 0.5403, 0, 0.8415, 0, 1, 0, -0.8415, 0, 0.5403, "d6ecff", false, 0, "SmoothPlastic", true, "rbxassetid://100106311518324", "Hull" },
	{ "Spike", "MeshPart", "", 2, 7, 1.8, 0, 14.6, 2.7, -0.4161, 0, 0.9093, 0, 1, 0, -0.9093, 0, -0.4161, "96d6fa", false, 0, "SmoothPlastic", true, "rbxassetid://100106311518324", "Hull" },
	{ "Spike", "MeshPart", "", 1.8, 5, 1.6, 2, 13.6, 2.7, -0.99, 0, 0.1411, 0, 1, 0, -0.1411, 0, -0.99, "d6ecff", false, 0, "SmoothPlastic", true, "rbxassetid://100106311518324", "Hull" },
	{ "Step", "Part", "Block", 9, 1, 8, 0, 0.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3468b4", true, 0, "SmoothPlastic", true },
	{ "Step", "Part", "Block", 7.5, 1, 6, 0, 1.5, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
}

Data.Warm_Brazier = {
	{ "Base", "Part", "Block", 7, 1.2, 7, 0, 0.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e566e", true, 0, "SmoothPlastic", true },
	{ "Bowl", "Part", "Cylinder", 1.6, 8, 8, 0, 5, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c626e", true, 0, "SmoothPlastic", true },
	{ "EmberGlow", "Part", "Ball", 4.6, 4.6, 4.6, 0, 6.45, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ff8c28", false, 0, "Neon", false },
	{ "Embers", "Part", "Cylinder", 0.5, 7, 7, 0, 6.05, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "ff8c28", false, 0, "Neon", false },
	{ "Log", "Part", "Block", 4.6, 0.8, 0.8, 0, 6.5, 0, 0.9903, -0.1392, 0, 0.1392, 0.9903, 0, 0, 0, 1, "703e26", false, 0, "SmoothPlastic", false },
	{ "Log", "Part", "Block", 4.6, 0.8, 0.8, 0, 6.5, 0, -0.4951, 0.0696, 0.866, 0.1392, 0.9903, 0, -0.8576, 0.1205, -0.5, "703e26", false, 0, "SmoothPlastic", false },
	{ "Log", "Part", "Block", 4.6, 0.8, 0.8, 0, 6.5, 0, 0.4951, -0.0696, 0.866, 0.1392, 0.9903, 0, -0.8576, 0.1205, 0.5, "703e26", false, 0, "SmoothPlastic", false },
	{ "Rim", "Part", "Cylinder", 0.5, 8.6, 8.6, 0, 5.9, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "ffc93c", true, 0, "SmoothPlastic", true },
	{ "Stem", "Part", "Cylinder", 2.2, 2.4, 2.4, 0, 3.3, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c626e", true, 0, "SmoothPlastic", true },
	{ "Step", "Part", "Block", 5, 1, 5, 0, 1.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "768096", true, 0, "SmoothPlastic", true },
}

Data.Ice_Wall_Panel = {
	{ "Facet", "Part", "Block", 0.3, 15, 1.3, -2.5, 12, 0, 0.9135, -0.4067, 0, 0.4067, 0.9135, 0, 0, 0, 1, "d6ecff", false, 0, "SmoothPlastic", false },
	{ "Facet", "Part", "Block", 0.3, 11, 1.3, 3.4, 9.5, 0, 0.848, 0.5299, 0, -0.5299, 0.848, 0, 0, 0, 1, "d6ecff", false, 0, "SmoothPlastic", false },
	{ "Pane", "Part", "Block", 15.2, 19.6, 1.2, 0, 11.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", true, 0.45, "Glass", true },
	{ "Post", "Part", "Block", 2.4, 24, 3, -8.8, 12, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
	{ "Post", "Part", "Block", 2.4, 24, 3, 8.8, 12, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
	{ "Rail", "Part", "Block", 15.2, 2, 3, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3468b4", true, 0, "SmoothPlastic", true },
	{ "Rail", "Part", "Block", 15.2, 2.4, 3, 0, 22.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic", true },
}

Data.Blue_Torch_Standing = {
	{ "Ember", "Part", "Ball", 0.9, 0.9, 0.9, 0, 6.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "60beff", false, 0, "Neon", true },
	{ "Foot", "Part", "Cylinder", 0.5, 1.8, 1.8, 0, 0.25, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "3468b4", true, 0, "SmoothPlastic", true },
	{ "Head", "Part", "Cylinder", 0.9, 1.3, 1.3, 0, 5.6, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c626e", true, 0, "SmoothPlastic", true },
	{ "Pole", "Part", "Block", 0.6, 5.2, 0.6, 0, 2.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e566e", true, 0, "SmoothPlastic", true },
}

-- a row as { name, class, shape, size, cf, color, collide, transparency, material, query, meshId, fidelity }
function Data.rows(kit: string): { any }
	local out = {}
	for _, t in ipairs(Data[kit]) do
		table.insert(out, { name = t[1], class = t[2], shape = t[3], size = Vector3.new(t[4], t[5], t[6]), cf = CFrame.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16], t[17], t[18]), color = Color3.fromHex(t[19]), collide = t[20], transparency = t[21], material = t[22], query = t[23], meshId = t[24], fidelity = t[25] })
	end
	return out
end

return Data
