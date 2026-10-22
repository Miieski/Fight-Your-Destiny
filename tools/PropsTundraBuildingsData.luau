--[[
	PropsTundraBuildingsData (dev tool data) - the kits of the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Buildings and
	structures" (2026-10-22) as they were before the remake, read from ServerStorage.MapAssets.Tundra (the kits are
	replaced by the templates when synced), plus the game copies whose parts differ from their kit (<kit>_game: the
	Tundra_1 cabin, 0.05 .. 0.2 off; the 3 Tundra_3 bridges, side spans 0.1 wider). One row per part: { path, class,
	shape, sx, sy, sz, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, hex, collide, transparency, material [, meshId,
	collisionFidelity] }; the CFrame is in the kit's pivot space. The builders (DevTools.PropsTundraBuildings) place their
	details on these parts; the colliding rows become the invisible Collision parts (exact collisions).
	Source of truth: tools/PropsTundraBuildingsData.luau.
]]
local Data = {}

Data.Cabin_Broken = {
	{ "Chimney", "Part", "Block", 3.2, 17, 3.2, -5.5, 8.5, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "768096", true, 0, "SmoothPlastic" },
	{ "ChimneySnow", "Part", "Block", 3.8, 0.9, 3.8, -5.5, 17.3, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "Door", "Part", "Block", 4.6, 6.4, 0.4, -1.6, 3.1, -8.7, 0.8829, 0, 0.4695, -0.0815, 0.9848, 0.1533, -0.4623, -0.1736, 0.8695, "865c42", true, 0, "SmoothPlastic" },
	{ "DoorDark", "Part", "Block", 6, 6.5, 0.3, 0, 3.25, -7.2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", true, 0, "SmoothPlastic" },
	{ "Drift", "WedgePart", "", 14, 4.5, 6, -13, 2.25, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0, "cedef6", true, 0, "SmoothPlastic" },
	{ "Drift", "WedgePart", "", 9, 3.5, 5, -6.5, 1.75, -10.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "Drift", "WedgePart", "", 20, 4, 5, 0, 2, 10.5, -1, 0, 0, 0, 1, 0, 0, 0, -1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "Floor", "Part", "Block", 20, 0.6, 16, 0, 0.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Gable", "WedgePart", "", 1, 6, 10, -5, 12, -7.5, 0, 0, 1, 0, 1, 0, -1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "Gable", "WedgePart", "", 1, 6, 10, -5, 12, 7.5, 0, 0, 1, 0, 1, 0, -1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "Gable", "WedgePart", "", 1, 6, 10, 5, 12, 7.5, 0, 0, -1, 0, 1, 0, 1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "Lintel", "Part", "Block", 6, 2.5, 1, 0, 7.75, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 1.1, 0.25, 14.1, -9.5, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 1.1, 0.25, 14.1, -9.5, 6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 7.1, 0.25, 1.1, -6.5, 3, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 7.1, 0.25, 1.1, -6.5, 6, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 20.1, 0.25, 1.1, 0, 3, 7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 20.1, 0.25, 1.1, 0, 6, 7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 9.6, 1.6, 1.6, -9.5, 4.8, -7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 9.6, 1.6, 1.6, -9.5, 4.8, 7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 6.4, 1.6, 1.6, 9.5, 3.2, -7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 9.6, 1.6, 1.6, 9.5, 4.8, 7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Rafter", "Part", "Block", 9, 0.7, 0.7, 4, 12.3, -4, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "Ridge", "Part", "Cylinder", 18.6, 1.4, 1.4, 0, 15.2, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0, "5c4236", true, 0, "SmoothPlastic" },
	{ "Roof", "Part", "Block", 12.4, 0.8, 18, -5.2, 12.34, 0, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Roof", "Part", "Block", 7, 0.8, 7, 3.2, 13.54, 5.5, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "RoofFallen", "Part", "Block", 8, 0.8, 7, 5.6, 3.6, -2.5, 0.6097, 0.7803, 0.1392, -0.788, 0.6157, 0, -0.0857, -0.1097, 0.9903, "5c4236", true, 0, "SmoothPlastic" },
	{ "RoofSnow", "Part", "Block", 11.6, 1, 17.6, -5.6378, 13.0686, 0, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "RoofSnow", "Part", "Block", 6.4, 0.9, 6.6, 3.612, 14.2257, 5.5, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
	{ "SnowInside", "Part", "Block", 17, 1.2, 13, 1, 0.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
	{ "WallBack", "Part", "Block", 20, 9, 1, 0, 4.5, 7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallFrontL", "Part", "Block", 7, 9, 1, -6.5, 4.5, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallFrontR", "Part", "Block", 7, 5.5, 1, 6.5, 2.75, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallFrontRBroken", "WedgePart", "", 1, 3, 5, 5.5, 7, -7.5, 0, 0, -1, 0, 1, 0, 1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "WallLeft", "Part", "Block", 1, 9, 14, -9.5, 4.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallRight", "Part", "Block", 1, 5, 14, 9.5, 2.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallRightBroken", "WedgePart", "", 1, 3.5, 7, 9.5, 6.75, 3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "Window", "Part", "Block", 3, 3, 1.2, -6.5, 5, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", true, 0, "SmoothPlastic" },
	{ "WindowBar", "Part", "Block", 3.2, 0.3, 1.3, -6.5, 5, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "WindowBar", "Part", "Block", 0.3, 3.2, 1.3, -6.5, 5, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
}

-- the Tundra_1 copy (its walls, log lines and window pushed out by 0.05 .. 0.2 after an earlier z-fight fix): the colliders
Data.Cabin_Broken_game = {
	{ "Chimney", "Part", "Block", 3.2, 17, 3.2, -5.5, 8.5, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "768096", true, 0, "SmoothPlastic" },
	{ "ChimneySnow", "Part", "Block", 3.8, 0.9, 3.8, -5.5, 17.3, 5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "Door", "Part", "Block", 4.6, 6.4, 0.4, -1.6, 3.1, -8.7002, 0.8829, 0, 0.4695, -0.0815, 0.9848, 0.1533, -0.4623, -0.1736, 0.8695, "865c42", true, 0, "SmoothPlastic" },
	{ "DoorDark", "Part", "Block", 6, 6.5, 0.3, 0, 3.25, -7.2002, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", true, 0, "SmoothPlastic" },
	{ "Drift", "WedgePart", "", 14, 4.5, 6, -13, 2.25, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0, "cedef6", true, 0, "SmoothPlastic" },
	{ "Drift", "WedgePart", "", 9, 3.5, 5, -6.5, 1.75, -10.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "Drift", "WedgePart", "", 20, 4, 5, 0, 2, 10.5, -1, 0, 0, 0, 1, 0, 0, 0, -1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "Floor", "Part", "Block", 20, 0.6, 16, 0, 0.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Gable", "WedgePart", "", 1, 6, 10, -5, 12, -7.5, 0, 0, 1, 0, 1, 0, -1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "Gable", "WedgePart", "", 1, 6, 10, -5, 12, 7.5, 0, 0, 1, 0, 1, 0, -1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "Gable", "WedgePart", "", 1, 6, 10, 5, 12, 7.5, 0, 0, -1, 0, 1, 0, 1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "Lintel", "Part", "Block", 6, 2.5, 1, 0, 7.75, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 1.1, 0.25, 14.1, -9.55, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 1.1, 0.25, 14.1, -9.55, 6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 7.1, 0.25, 1.1, -6.55, 3, -7.5498, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 7.1, 0.25, 1.1, -6.55, 6, -7.5996, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 20.2, 0.25, 1.1, 0, 3, 7.5498, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "LogLine", "Part", "Block", 20.2, 0.25, 1.1, 0, 6, 7.5498, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 9.6, 1.6, 1.6, -9.5, 4.8, -7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 9.6, 1.6, 1.6, -9.5, 4.8, 7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 6.4, 1.6, 1.6, 9.5, 3.2, -7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Cylinder", 9.6, 1.6, 1.6, 9.5, 4.8, 7.5, 0, -1, 0, 1, 0, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Rafter", "Part", "Block", 9, 0.7, 0.7, 4, 12.3, -4, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "Ridge", "Part", "Cylinder", 18.6, 1.4, 1.4, 0, 15.2, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0, "5c4236", true, 0, "SmoothPlastic" },
	{ "Roof", "Part", "Block", 12.4, 0.8, 18, -5.2, 12.34, 0, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Roof", "Part", "Block", 7, 0.8, 7, 3.2, 13.54, 5.5, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "RoofFallen", "Part", "Block", 8, 0.8, 7, 5.6, 3.6, -2.5, 0.6097, 0.7803, 0.1392, -0.788, 0.6157, 0, -0.0857, -0.1097, 0.9903, "5c4236", true, 0, "SmoothPlastic" },
	{ "RoofSnow", "Part", "Block", 11.6, 1, 17.6, -5.6378, 13.0686, 0, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "RoofSnow", "Part", "Block", 6.4, 0.9, 6.6, 3.612, 14.2257, 5.5, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
	{ "SnowInside", "Part", "Block", 17, 1.2, 13, 1, 0.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
	{ "WallBack", "Part", "Block", 20.1, 9, 1, 0, 4.5, 7.5498, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallFrontL", "Part", "Block", 7, 9, 1, -6.55, 4.5, -7.5498, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallFrontR", "Part", "Block", 7, 5.5, 1, 6.55, 2.75, -7.5498, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallFrontRBroken", "WedgePart", "", 1, 3, 5, 5.5, 7, -7.5, 0, 0, -1, 0, 1, 0, 1, 0, 0, "865c42", true, 0, "SmoothPlastic" },
	{ "WallLeft", "Part", "Block", 1, 9, 14, -9.55, 4.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallRight", "Part", "Block", 1, 5, 14, 9.55, 2.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "WallRightBroken", "WedgePart", "", 1, 3.5, 7, 9.5, 6.75, 3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "Window", "Part", "Block", 3, 3, 1.2, -6.5, 5, -7.2998, 1, 0, 0, 0, 1, 0, 0, 0, 1, "1f222b", true, 0, "SmoothPlastic" },
	{ "WindowBar", "Part", "Block", 3.2, 0.3, 1.3, -6.5, 5, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "WindowBar", "Part", "Block", 0.3, 3.2, 1.3, -6.5, 5, -7.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
}

Data.Ice_Cave_Mouth = {
	{ "Back", "Part", "Block", 18, 14, 2, 0, 7, 3.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "4e566e", true, 0, "SmoothPlastic" },
	{ "Dark", "Part", "Block", 12, 11, 2, 0, 5.5, 1.8, 1, 0, 0, 0, 1, 0, 0, 0, 1, "0f1f36", true, 0, "SmoothPlastic" },
	{ "IceRock", "MeshPart", "", 8, 15, 9, -8, 7.2, 0, 0.8208, 0.0863, 0.5646, -0.1045, 0.9945, 0, -0.5615, -0.059, 0.8253, "54a0e8", true, 0, "SmoothPlastic", "rbxassetid://9420263160", "Hull" },
	{ "IceRock", "MeshPart", "", 23, 6, 10, 0, 13.4, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "768096", true, 0, "SmoothPlastic", "rbxassetid://7231644778", "Hull" },
	{ "IceRock", "MeshPart", "", 8, 14, 9, 8, 6.7, 0, -0.7334, 0.0771, 0.6755, 0.1045, 0.9945, 0, -0.6718, 0.0706, -0.7374, "96d6fa", true, 0.1, "SmoothPlastic", "rbxassetid://9420263160", "Hull" },
	{ "Icicle", "MeshPart", "", 1.2, 3, 1.1, -3.2, 9.7, -0.6, -0.5403, 0, 0.8415, 0, -1, 0, 0.8415, 0, 0.5403, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.2, 4.2, 1.1, 0.4, 9.1, -0.6, 0.4161, 0, 0.9093, 0, -1, 0, 0.9093, 0, -0.4161, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.2, 2.6, 1.1, 3.4, 9.9, -0.6, 0.99, 0, 0.1411, 0, -1, 0, 0.1411, 0, -0.99, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Snow", "MeshPart", "", 20.7, 6, 9, 0, 14.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", false, 0, "SmoothPlastic", "rbxassetid://7231644778", "Hull" },
}

Data.Wooden_Scaffold = {
	{ "Brace", "Part", "Block", 0.5, 0.5, 10.4, -7.4, 5, 0, 1, 0, 0, 0, 0.6157, -0.788, 0, 0.788, 0.6157, "865c42", false, 0, "SmoothPlastic" },
	{ "Brace", "Part", "Block", 17.4, 0.5, 0.5, 0, 5, -3.5, 0.8572, 0.515, 0, -0.515, 0.8572, 0, 0, 0, 1, "865c42", false, 0, "SmoothPlastic" },
	{ "Brace", "Part", "Block", 17.4, 0.5, 0.5, 0, 5, -3.4, 0.8572, -0.515, 0, 0.515, 0.8572, 0, 0, 0, 1, "865c42", false, 0, "SmoothPlastic" },
	{ "Brace", "Part", "Block", 0.5, 0.5, 10.4, 7.4, 5, 0, 1, 0, 0, 0, 0.6157, -0.788, 0, 0.788, 0.6157, "865c42", false, 0, "SmoothPlastic" },
	{ "Deck", "Part", "Block", 16, 0.8, 8, 0, 10.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "PlankLine", "Part", "Block", 16.05, 0.84, 0.15, 0, 10.4, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "PlankLine", "Part", "Block", 16.05, 0.84, 0.15, 0, 10.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "PlankLine", "Part", "Block", 16.05, 0.84, 0.15, 0, 10.4, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", false, 0, "SmoothPlastic" },
	{ "Post", "Part", "Block", 0.9, 10, 0.9, -7.4, 5, 3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Block", 0.9, 13.6, 0.9, -7.4, 6.8, -3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Block", 0.9, 10, 0.9, 7.4, 5, 3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Post", "Part", "Block", 0.9, 13.6, 0.9, 7.4, 6.8, -3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "5c4236", true, 0, "SmoothPlastic" },
	{ "Rail", "Part", "Block", 16, 0.5, 0.5, 0, 13.3, -3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1, "865c42", true, 0, "SmoothPlastic" },
	{ "Snow", "Part", "Block", 9, 0.5, 5, -2, 11, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", false, 0, "SmoothPlastic" },
	{ "Snow", "Part", "Block", 4, 0.4, 3, 5, 10.95, -1.5, 1, 0, 0, 0, 1, 0, 0, 0, 1, "cedef6", false, 0, "SmoothPlastic" },
}

Data.Snow_Bridge_Section = {
	{ "Icicle", "MeshPart", "", 1.4, 3, 1.3, -9, 0.9, -3, -0.5403, 0, 0.8415, 0, -1, 0, 0.8415, 0, 0.5403, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 4.6, 1.3, -4, 0.9, 2.5, 0.4161, 0, 0.9093, 0, -1, 0, 0.9093, 0, -0.4161, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 2.6, 1.3, 1, 1.9, -3, 0.99, 0, 0.1411, 0, -1, 0, 0.1411, 0, -0.99, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 5, 1.3, 6, 0.7, 2.5, 0.6536, 0, -0.7568, 0, -1, 0, -0.7568, 0, -0.6536, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 3.4, 1.3, 11, 0.7, -3, -0.2837, 0, -0.9589, 0, -1, 0, -0.9589, 0, 0.2837, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Span", "Part", "Block", 13, 4, 10, -13.6, 3.5, 0, 0.9744, -0.225, 0, 0.225, 0.9744, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic" },
	{ "Span", "Part", "Block", 16, 4, 10, 0, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic" },
	{ "Span", "Part", "Block", 13, 4, 10, 13.6, 3.5, 0, 0.9744, 0.225, 0, -0.225, 0.9744, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic" },
	{ "SpanSnow", "Part", "Block", 13.4, 1.2, 10.6, -14.1399, 5.8385, 0, 0.9744, -0.225, 0, 0.225, 0.9744, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
	{ "SpanSnow", "Part", "Block", 16.4, 1.2, 10.6, 0, 7.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "SpanSnow", "Part", "Block", 13.4, 1.2, 10.6, 14.1399, 5.8385, 0, 0.9744, 0.225, 0, -0.225, 0.9744, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
}

-- the 3 Tundra_3 copies (identical: the side Span / SpanSnow 0.1 wider in Z than the kit): the colliders
Data.Snow_Bridge_Section_game = {
	{ "Icicle", "MeshPart", "", 1.4, 3, 1.3, -9, 0.9, -3, -0.5403, 0, 0.8415, 0, -1, 0, 0.8415, 0, 0.5403, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 4.6, 1.3, -4, 0.9, 2.5, 0.4161, 0, 0.9093, 0, -1, 0, 0.9093, 0, -0.4161, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 2.6, 1.3, 1, 1.9, -3, 0.99, 0, 0.1411, 0, -1, 0, 0.1411, 0, -0.99, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 5, 1.3, 6, 0.7, 2.5, 0.6536, 0, -0.7568, 0, -1, 0, -0.7568, 0, -0.6536, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Icicle", "MeshPart", "", 1.4, 3.4, 1.3, 11, 0.7, -3, -0.2837, 0, -0.9589, 0, -1, 0, -0.9589, 0, 0.2837, "d6ecff", false, 0.15, "SmoothPlastic", "rbxassetid://100106311518324", "Hull" },
	{ "Span", "Part", "Block", 13, 4, 10.1, -13.6, 3.5, 0, 0.9744, -0.225, 0, 0.225, 0.9744, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic" },
	{ "Span", "Part", "Block", 16, 4, 10, 0, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "54a0e8", true, 0, "SmoothPlastic" },
	{ "Span", "Part", "Block", 13, 4, 10.1, 13.6, 3.5, 0, 0.9744, 0.225, 0, -0.225, 0.9744, 0, 0, 0, 1, "96d6fa", true, 0, "SmoothPlastic" },
	{ "SpanSnow", "Part", "Block", 13.4, 1.2, 10.7, -14.1399, 5.8385, 0, 0.9744, -0.225, 0, 0.225, 0.9744, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
	{ "SpanSnow", "Part", "Block", 16.4, 1.2, 10.6, 0, 7.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, "f4f8ff", true, 0, "SmoothPlastic" },
	{ "SpanSnow", "Part", "Block", 13.4, 1.2, 10.7, 14.1399, 5.8385, 0, 0.9744, 0.225, 0, -0.225, 0.9744, 0, 0, 0, 1, "cedef6", true, 0, "SmoothPlastic" },
}

-- a row as { name, class, shape, size, cf, color, collide, transparency, material, meshId, fidelity }
function Data.rows(kit: string): { any }
	local out = {}
	for _, t in ipairs(Data[kit]) do
		table.insert(out, { name = t[1], class = t[2], shape = t[3], size = Vector3.new(t[4], t[5], t[6]), cf = CFrame.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16], t[17], t[18]), color = Color3.fromHex(t[19]), collide = t[20], transparency = t[21], material = t[22], meshId = t[23], fidelity = t[24] })
	end
	return out
end

return Data
