--[[
	PropsTundraPropsData (dev tool data) - the 6 kits of the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Props and
	decor" (2026-10-22) as they were before the remake, read from ServerStorage.MapAssets.Tundra (every copy is the kit at a
	Model scale). One row per part: { name, class, shape, sx, sy, sz, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22,
	hex, collide, transparency, material, query [, meshId, collisionFidelity] }; the CFrame is in the kit's pivot space.
	The builders (DevTools.PropsTundraProps) place their details on these parts; the colliding rows become the invisible
	Collision parts (exact collisions). Source of truth: tools/PropsTundraPropsData.luau.
]]
local Data = {}

Data.Bone_Pile_Ice = {
	{ "Bone", "Part", "Cylinder", 3.6729, 0.4, 0.4, -1, 0.935, 2, 0.8168, 0.1586, -0.5547, -0.1906, 0.9817, 0, 0.5445, 0.1057, 0.8321, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Bone", "Part", "Cylinder", 5.3749, 0.5, 0.5, 0.25, 1.085, 0, 0.6512, -0.098, 0.7526, 0.1488, 0.9889, 0, -0.7442, 0.112, 0.6585, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Bone", "Part", "Cylinder", 5.7018, 0.5, 0.5, -0.25, 0.635, -0.25, 0.9646, -0.0169, -0.2631, 0.0175, 0.9998, 0, 0.2631, -0.0046, 0.9648, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "BoneEnd", "Part", "Ball", 0.68, 0.68, 0.68, -2.5, 1.285, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "BoneEnd", "Part", "Ball", 0.68, 0.68, 0.68, 0.5, 0.585, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "BoneEnd", "Part", "Ball", 0.85, 0.85, 0.85, -1.5, 0.685, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "BoneEnd", "Part", "Ball", 0.85, 0.85, 0.85, -3, 0.585, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "BoneEnd", "Part", "Ball", 0.85, 0.85, 0.85, 2, 1.485, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "BoneEnd", "Part", "Ball", 0.85, 0.85, 0.85, 2.5, 0.685, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "EyeSocket", "Part", "Block", 0.5, 0.55, 0.3, -0.2, 1.885, -0.95, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3e3c4e", true, 0, "SmoothPlastic", true },
	{ "EyeSocket", "Part", "Block", 0.5, 0.55, 0.3, 0.8, 1.885, -0.95, 1, 0, 0, 0, 1, 0, 0, 0, 1, "3e3c4e", true, 0, "SmoothPlastic", true },
	{ "Ice", "MeshPart", "", 6, 3, 5.5, 0.6, 1.2, 0.4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", false, 0.4, "SmoothPlastic", true, "rbxassetid://7231644778", "Hull" },
	{ "Jaw", "Part", "Block", 1.5, 0.9, 1.3, 0.3, 0.785, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Rib", "Part", "Block", 0.3, 2.2, 0.3, -1.3999, 1.085, -2.2, 0.766, -0.6428, 0, 0.6428, 0.766, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Rib", "Part", "Block", 0.3, 2.2, 0.3, -2.2, 1.085, -2.2, 0.866, -0.5, 0, 0.5, 0.866, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Rib", "Part", "Block", 0.3, 2.2, 0.3, -3, 1.085, -2.2, 0.9397, -0.342, 0, 0.342, 0.9397, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Skull", "Part", "Ball", 2.4, 2.4, 2.4, 0.3, 1.685, 0.2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f0e8d0", true, 0, "SmoothPlastic", true },
	{ "Snow", "MeshPart", "", 3.4, 1.4, 3, -2, 0.4, 1.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", false, 0, "SmoothPlastic", false, "rbxassetid://2557003083", "Box" },
}

Data.FishingHole = {
	{ "Bucket", "Part", "Cylinder", 1.4, 1.4, 1.4, 4.6, 0.7, -2.4, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c626e", true, 0, "SmoothPlastic", true },
	{ "Fish", "Part", "Block", 1.3, 0.3, 0.5, 2.9, 0.2, -1.6, 0.9211, 0, -0.3894, 0, 1, 0, 0.3894, 0, 0.9211, "54a0e8", false, 0, "SmoothPlastic", false },
	{ "Fish", "Part", "Block", 1.6, 0.35, 0.6, 2.5, 0.2, -2.6, 0.8776, 0, 0.4794, 0, 1, 0, -0.4794, 0, 0.8776, "4696d6", false, 0, "SmoothPlastic", false },
	{ "Fork", "Part", "Block", 0.3, 2.2, 0.3, 2.9, 1.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.3, 1.6, 0.3, 4.1, 0.8, -0.0196, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.3, 1.6, 0.3, 4.1, 0.8, 1.0196, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.3, 1.6, 0.3, 5, 0.8, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Line", "Part", "Block", 0.08, 3.8, 0.08, -1.1, 2.05, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f5f6fa", false, 0, "SmoothPlastic", false },
	{ "Rim", "Part", "Cylinder", 0.24, 7.4, 7.4, 0, 0.06, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "d6ecff", false, 0, "SmoothPlastic", false },
	{ "Rod", "Part", "Block", 6, 0.2, 0.2, 1.6, 2.7, 0, 0.9063, 0.4226, 0, -0.4226, 0.9063, 0, 0, 0, 1, "865c42", false, 0, "SmoothPlastic", false },
	{ "Seat", "Part", "Cylinder", 0.4, 2, 2, 4.4, 1.7, 0.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic", true },
	{ "Water", "Part", "Cylinder", 0.3, 6, 6, 0, 0.07, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "3468b4", false, 0, "SmoothPlastic", false },
}

Data.Sled_A = {
	{ "Cross", "Part", "Block", 3.6, 0.35, 0.6, 0, 1.55, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Cross", "Part", "Block", 3.6, 0.35, 0.6, 0, 1.55, 2.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.4, 1.2, 0.4, -1.5, 1, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.4, 1.2, 0.4, -1.5, 1, 2.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.4, 1.2, 0.4, 1.5, 1, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Leg", "Part", "Block", 0.4, 1.2, 0.4, 1.5, 1, 2.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Rope", "Part", "Block", 0.15, 0.15, 3.2, 0, 0.9, -4.8, 1, 0, 0, 0, 0.9781, 0.2079, 0, -0.2079, 0.9781, "c4a068", false, 0, "SmoothPlastic", false },
	{ "Runner", "Part", "Block", 0.4, 0.5, 7, -1.5, 0.25, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Runner", "Part", "Block", 0.4, 0.5, 7, 1.5, 0.25, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "RunnerTip", "Part", "Block", 0.4, 0.5, 1.9, -1.5, 0.72, -3.7, 1, 0, 0, 0, 0.8192, -0.5736, 0, 0.5736, 0.8192, "5c4236", true, 0, "SmoothPlastic", true },
	{ "RunnerTip", "Part", "Block", 0.4, 0.5, 1.9, 1.5, 0.72, -3.7, 1, 0, 0, 0, 0.8192, -0.5736, 0, 0.5736, 0.8192, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Slat", "Part", "Block", 0.6, 0.3, 6.4, -0.65, 1.85, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true, 0, "SmoothPlastic", true },
	{ "Slat", "Part", "Block", 0.6, 0.3, 6.4, -1.3, 1.85, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic", true },
	{ "Slat", "Part", "Block", 0.6, 0.3, 6.4, 0, 1.85, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic", true },
	{ "Slat", "Part", "Block", 0.6, 0.3, 6.4, 0.65, 1.85, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6965c", true, 0, "SmoothPlastic", true },
	{ "Slat", "Part", "Block", 0.6, 0.3, 6.4, 1.3, 1.85, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic", true },
}

Data.Snowman_B = {
	{ "Arm", "Part", "Block", 2.6, 0.25, 0.25, -2, 4.6, 0, 0.766, 0.6428, 0, -0.6428, 0.766, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic", false },
	{ "Arm", "Part", "Block", 2.6, 0.25, 0.25, 2.3, 3.9, 0, 0.9659, 0.2588, 0, -0.2588, 0.9659, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic", false },
	{ "Base", "Part", "Ball", 3.6, 3.6, 3.6, 0, 1.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic", true },
	{ "Body", "Part", "Ball", 2.7, 2.7, 2.7, 0.15, 3.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic", true },
	{ "Bucket", "Part", "Cylinder", 1.3, 1.7, 1.7, 0.45, 6.9, 0, 0.1392, -0.9903, 0, 0.9903, 0.1392, 0, 0, 0, 1, "5c626e", false, 0, "SmoothPlastic", false },
	{ "Eye", "Part", "Block", 0.3, 0.3, 0.3, -0.1, 6, -0.85, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", false, 0, "SmoothPlastic", false },
	{ "Eye", "Part", "Block", 0.3, 0.3, 0.3, 0.8, 6, -0.85, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", false, 0, "SmoothPlastic", false },
	{ "Head", "Part", "Ball", 2, 2, 2, 0.35, 5.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic", true },
	{ "Nose", "Part", "Block", 0.35, 0.35, 1.2, 0.35, 5.6, -1.3, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ff8c28", false, 0, "SmoothPlastic", false },
	{ "Scarf", "Part", "Cylinder", 0.5, 2.1, 2.1, 0.25, 4.85, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "baaaec", false, 0, "SmoothPlastic", false },
	{ "ScarfTail", "Part", "Block", 0.6, 1.6, 0.25, -0.5, 4.2, -1.2, 0.9781, -0.2079, 0, 0.2079, 0.9781, 0, 0, 0, 1, "baaaec", false, 0, "SmoothPlastic", false },
}

Data.Snowman_A = {
	{ "Arm", "Part", "Block", 3.2, 0.3, 0.3, -2.7, 5.4, 0, 0.9063, 0.4226, 0, -0.4226, 0.9063, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic", false },
	{ "Arm", "Part", "Block", 3.2, 0.3, 0.3, 2.7, 5.4, 0, 0.9063, -0.4226, 0, 0.4226, 0.9063, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic", false },
	{ "Base", "Part", "Ball", 4.4, 4.4, 4.4, 0, 1.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic", true },
	{ "Body", "Part", "Ball", 3.3, 3.3, 3.3, 0, 4.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic", true },
	{ "Button", "Part", "Block", 0.4, 0.4, 0.3, 0, 4.3, -1.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", false, 0, "SmoothPlastic", false },
	{ "Button", "Part", "Block", 0.4, 0.4, 0.3, 0, 5.2, -1.55, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", false, 0, "SmoothPlastic", false },
	{ "Eye", "Part", "Block", 0.35, 0.35, 0.3, -0.5, 7.35, -1.02, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", false, 0, "SmoothPlastic", false },
	{ "Eye", "Part", "Block", 0.35, 0.35, 0.3, 0.5, 7.35, -1.02, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", false, 0, "SmoothPlastic", false },
	{ "Hat", "Part", "Cylinder", 1.6, 1.8, 1.8, 0, 8.9, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "4e566e", false, 0, "SmoothPlastic", false },
	{ "HatBrim", "Part", "Cylinder", 0.3, 2.7, 2.7, 0, 8, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, "4e566e", false, 0, "SmoothPlastic", false },
	{ "Head", "Part", "Ball", 2.4, 2.4, 2.4, 0, 6.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic", true },
	{ "Nose", "Part", "Block", 0.4, 0.4, 1.4, 0, 6.9, -1.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "ff8c28", false, 0, "SmoothPlastic", false },
}

Data.Weapon_Rack_Frozen = {
	{ "AxeHead", "Part", "Block", 1.7, 1.5, 0.3, 0.7, 5.1, -0.2, 1, 0, 0, 0, 0.9877, 0.1564, 0, -0.1564, 0.9877, "5c626e", false, 0, "SmoothPlastic", false },
	{ "Base", "Part", "Block", 8, 0.5, 2.4, 0, 0.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Blade", "Part", "Block", 0.5, 4.4, 0.15, -2.2, 3.2, 0.1, 1, 0, 0, 0, 0.9877, 0.1564, 0, -0.1564, 0.9877, "f5f6fa", false, 0, "SmoothPlastic", false },
	{ "Guard", "Part", "Block", 1.6, 0.3, 0.4, -2.2, 0.95, 0.45, 1, 0, 0, 0, 0.9877, 0.1564, 0, -0.1564, 0.9877, "ffc93c", false, 0, "SmoothPlastic", false },
	{ "Handle", "Part", "Block", 0.3, 5.6, 0.3, 0, 3.1, 0.1, 1, 0, 0, 0, 0.9877, 0.1564, 0, -0.1564, 0.9877, "703e26", false, 0, "SmoothPlastic", false },
	{ "Ice", "MeshPart", "", 3, 4, 2.6, -2.4, 4, 0.3, 1, 0, 0, 0, 1, 0, 0, 0, 1, "d6ecff", false, 0.4, "SmoothPlastic", true, "rbxassetid://2557003083", "Box" },
	{ "Ice", "MeshPart", "", 7, 3.2, 3.4, 0.5, 1.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "96d6fa", false, 0.4, "SmoothPlastic", true, "rbxassetid://7231644778", "Hull" },
	{ "Icicle", "MeshPart", "", 0.6, 1.4, 0.6, 3, 4.1, 0.6, 0.99, 0, 0.1411, 0, -1, 0, 0.1411, 0, -0.99, "d6ecff", false, 0.15, "SmoothPlastic", false, "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 0.6, 1.6, 0.6, -1, 4, 0.6, -0.5403, 0, 0.8415, 0, -1, 0, 0.8415, 0, 0.5403, "d6ecff", false, 0.15, "SmoothPlastic", false, "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 0.6, 2.2, 0.6, 1.2, 3.7, 0.6, 0.4161, 0, 0.9093, 0, -1, 0, 0.9093, 0, -0.4161, "d6ecff", false, 0.15, "SmoothPlastic", false, "rbxassetid://100106311518324", "Hull" },
	{ "Post", "Part", "Block", 0.6, 6, 0.6, -3.6, 3, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Post", "Part", "Block", 0.6, 6, 0.6, 3.6, 3, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic", true },
	{ "Rail", "Part", "Block", 7.8, 0.4, 0.4, 0, 2.2, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic", true },
	{ "Rail", "Part", "Block", 7.8, 0.4, 0.4, 0, 5, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic", true },
	{ "Shaft", "Part", "Block", 0.25, 7.4, 0.25, 2.2, 3.9, 0.1, 1, 0, 0, 0, 0.9877, 0.1564, 0, -0.1564, 0.9877, "703e26", false, 0, "SmoothPlastic", false },
	{ "SpearTip", "Part", "Block", 0.6, 1.3, 0.2, 2.2, 7.9, -0.55, 1, 0, 0, 0, 0.9877, 0.1564, 0, -0.1564, 0.9877, "7080cc", false, 0, "SmoothPlastic", false },
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
