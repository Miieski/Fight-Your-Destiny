--[[
	FloorsRound8 (dev tool, Edit mode only) - owner prompt "ROUND 8" part 7: better floors for the Hub, Plains, Desert, Jungle and Tundra.
	Source of truth: tools/FloorsRound8.luau (= ServerStorage.DevTools.FloorsRound8). Textures: tools/make_floor_textures.py, ids in Config/PropTextures.Ground.
	Recipes: docs/prop_texture_guide.md "Ground".

		local F = require(game.ServerStorage.DevTools.FloorsRound8:Clone())
		print(F.build("plains_ground_curb"))   -- one detail template (F.IDS lists them), then Sync.run({ only = { ids } })
		local before = F.snapshot()
		print(F.zone("Plains_1"))              -- textures, fringes, curbs, details of a zone; idempotent; F.clear(name) takes them away
		print(F.compare(before))               -- collisions, sizes, spawns: must be 0 changes

	Nothing here touches a part of the map: Textures are added on the ground and path parts, the rest goes in a new folder Decor.FloorDetail (or
	Hub.Decor.FloorDetail). All of it CanCollide / CanTouch / CanQuery / CastShadow false, no script.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local R6 = require(ServerStorage.DevTools.PropsRound6:Clone()) :: any
local L = R6.lib()
local H, M = L.H, L.M
local ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()) :: any
local piece = H.piece
local Tex = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ground

local F = {}
local hex = Color3.fromHex
local TAU = 2 * math.pi
local FOLDER = "FloorDetail"

---------------------------------------------------------------------
-- DETAIL TEMPLATES (one union each, 0 at the ground)
---------------------------------------------------------------------
local function finish(m: Model, id: string, list: { BasePart }): Model
	M.finish(m, id, { Stone = list }, "Stone", { Stone = { shadow = false } })
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanTouch, d.CanQuery, d.CastShadow = false, false, false, false
			d.Anchored = true
		end
	end
	return m
end

local function pick(rng: Random, list: { any }): any
	return list[rng:NextInteger(1, #list)]
end

-- a run of low edge stones, 9 studs long along Z. Round 9 part 1: in the palette of the ground they belong to, on a foot of that ground (moss, sand,
-- snow), with the ground's own texture on the union (edge = key, tint, alpha; docs/prop_texture_guide.md "Raised edges")
local function curb(id: string, seed: number, colors: { string }, wide: number?, foot: string?, edge: any?): Model
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(seed)
	local list = {}
	local z = -4.4
	while z < 4 do
		local long = rng:NextNumber(1.4, 2.4)
		local w = rng:NextNumber(0.8, 1.2) * (wide or 1)
		local h = rng:NextNumber(0.18, 0.32)
		table.insert(list, H.chamfered(Vector3.new(w, h + 0.2, long), CFrame.new(rng:NextNumber(-0.12, 0.12), (h - 0.2) / 2, z + long / 2) * CFrame.Angles(0, rng:NextNumber(-0.09, 0.09), 0), hex(pick(rng, colors)), { "topSides" }, 0.08))
		z += long + rng:NextNumber(0.08, 0.22)
	end
	if foot then
		for i = 1, 3 do
			local long = rng:NextNumber(3.2, 3.8)
			table.insert(list, H.chamfered(Vector3.new(rng:NextNumber(1.7, 2.3) * (wide or 1), 0.3, long), CFrame.new(rng:NextNumber(-0.12, 0.12), -0.1, (i - 2) * 3), hex(foot), { "topSides" }, 0.1))
		end
	end
	finish(m, id, list)
	if edge then
		local union = m:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		local info = Tex[edge.key]
		for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local t = Instance.new("Texture")
			t.Name = "EdgeTex"
			t.Texture = info.Id
			t.Face = face
			t.StudsPerTileU, t.StudsPerTileV = info.Tile, info.Tile
			t.OffsetStudsU = seed % info.Tile
			t.Color3 = if edge.tint then hex(edge.tint) else Color3.new(1, 1, 1)
			t.Transparency = edge.alpha
			t.Parent = union
		end
	end
	return m
end

local function pebbles(id: string, seed: number, top: string, side: string, count: number, radius: number): Model
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(seed)
	local list = {}
	for _ = 1, count do
		local k = rng:NextNumber(0.14, 0.42)
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(0, radius)
		ST.blob(list, rng, CFrame.new(math.cos(a) * r, k * 0.25, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), k, k * 0.62, k * rng:NextNumber(0.75, 1), function(n: Vector3): Color3
			return hex(if n.Y > 0.3 then top else side)
		end, k * 0.2)
	end
	return finish(m, id, list)
end

local function blades(list: { BasePart }, rng: Random, n: number, height: number, spread: number, colors: { string }, at: Vector3?)
	for _ = 1, n do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(0, spread)
		local h = height * rng:NextNumber(0.6, 1.2)
		local cf = CFrame.new((at or Vector3.zero) + Vector3.new(math.cos(a) * r, h / 2 - 0.04, math.sin(a) * r)) * CFrame.Angles(0, a, 0) * CFrame.Angles(rng:NextNumber(-0.32, 0.32), 0, rng:NextNumber(-0.25, 0.25))
		table.insert(list, piece("WedgePart", Vector3.new(0.07, h, 0.26), cf, hex(pick(rng, colors))))
	end
end

function F.plains_ground_tuft(): Model
	local m = Instance.new("Model")
	m.Name = "plains_ground_tuft"
	local list = {}
	blades(list, Random.new(801), 9, 0.95, 0.6, { "4f9e30", "6cbc3c", "86d04a", "3f8a2c" })
	return finish(m, "plains_ground_tuft", list)
end

function F.plains_ground_flowers(): Model
	local m = Instance.new("Model")
	m.Name = "plains_ground_flowers"
	local rng = Random.new(802)
	local list = {}
	blades(list, rng, 5, 0.7, 0.8, { "5aa836", "70c040" })
	for _ = 1, 6 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(0.1, 0.95)
		local h = rng:NextNumber(0.55, 0.9)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		table.insert(list, piece("Part", Vector3.new(0.05, h, 0.05), CFrame.new(p + Vector3.new(0, h / 2, 0)), hex("4c9a30")))
		table.insert(list, piece("Part", Vector3.new(0.24, 0.1, 0.24), CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), hex(pick(rng, { "ffd84a", "fff4e0", "ff9ec8", "c49cff" }))))
	end
	return finish(m, "plains_ground_flowers", list)
end

function F.desert_ground_ripple(): Model
	local m = Instance.new("Model")
	m.Name = "desert_ground_ripple"
	local rng = Random.new(803)
	local list = {}
	ST.blob(list, rng, CFrame.new(0, 0, 0), 2.6, 0.3, 1.3, function(n: Vector3): Color3
		return hex(if n.Z > 0.2 then "f6dea0" else "e6c684")
	end, 0.1)
	blades(list, rng, 4, 0.7, 0.5, { "c8b060", "a89a50", "d8c070" }, Vector3.new(0.8, 0.1, 0))
	return finish(m, "desert_ground_ripple", list)
end

function F.jungle_ground_fern(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_ground_fern"
	local rng = Random.new(804)
	local list = {}
	for i = 1, 5 do
		local a = (i + rng:NextNumber(-0.2, 0.2)) / 5 * TAU
		local base = CFrame.Angles(0, a, 0)
		table.insert(list, piece("Part", Vector3.new(0.42, 0.05, 1), base * CFrame.new(0, 0.38, -0.5) * CFrame.Angles(0.5, 0, 0), hex(pick(rng, { "3f9a3a", "4cae42", "358a34" }))))
		table.insert(list, piece("WedgePart", Vector3.new(0.34, 0.05, 0.9), base * CFrame.new(0, 0.3, -1.3) * CFrame.Angles(-0.28, 0, 0), hex(pick(rng, { "5abc48", "46a640" }))))
	end
	return finish(m, "jungle_ground_fern", list)
end

function F.jungle_ground_root(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_ground_root"
	local rng = Random.new(805)
	local list = {}
	for _ = 1, 2 do
		local p = Vector3.new(rng:NextNumber(-1, 1), 0.08, rng:NextNumber(-0.6, 0.6))
		local a = rng:NextNumber(0, TAU)
		for k = 1, 4 do
			local long = rng:NextNumber(1, 1.5)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local up = if k == 2 then 0.14 else (if k == 3 then -0.14 else 0)
			local q = p + d * long + Vector3.new(0, up, 0)
			table.insert(list, piece("Part", Vector3.new(0.3 - k * 0.04, 0.24 - k * 0.03, long + 0.15), CFrame.lookAt((p + q) / 2, q), hex(pick(rng, { "5c4a30", "6c583a", "4e3e2a" }))))
			p, a = q, a + rng:NextNumber(-0.6, 0.6)
		end
	end
	return finish(m, "jungle_ground_root", list)
end

-- Round 9 part 9: the grass of the jungle set, for the edges of its paths
function F.jungle_ground_tuft(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_ground_tuft"
	local list = {}
	blades(list, Random.new(824), 8, 0.9, 0.55, { "4a7a38", "5f8f3e", "3f6e36", "6e9e48" })
	return finish(m, "jungle_ground_tuft", list)
end

-- Round 9 part 10: small ice shards along the shore of the lake
function F.tundra_lake_shards(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_lake_shards"
	local rng = Random.new(826)
	local list = {}
	for _ = 1, 4 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(0.1, 0.8)
		local h = rng:NextNumber(0.6, 1.5)
		local cf = CFrame.new(math.cos(a) * r, h / 2 - 0.12, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		table.insert(list, piece("WedgePart", Vector3.new(rng:NextNumber(0.4, 0.8), h, rng:NextNumber(0.5, 1)), cf, hex(pick(rng, { "bfe4fa", "a8d8f6", "d6eefc", "8cc8f0" }))))
	end
	return finish(m, "tundra_lake_shards", list)
end

-- Round 9 part 11: the look of an ice ramp, no collision. Its origin is the centre of the Ramp wedge (16 x 8 x 26, high side on +Z), which stays as the collider, invisible, with its 2 RampSide rails
function F.tundra_ice_ramp(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_ramp"
	local rng = Random.new(827)
	local list = {}
	local n = Vector3.new(0, 26, -8).Unit
	local up = Vector3.new(0, 8, 26).Unit
	local function onSlope(t: number, lift: number): CFrame
		return CFrame.fromMatrix(up * t + n * lift, Vector3.xAxis, n, Vector3.xAxis:Cross(n))
	end
	local ice, snow = { "a8ccec", "8fb8e0", "7ca8d8", "bfe4fa" }, { "f0f6fe", "e2eefa" }
	for i = 1, 6 do -- ridges across the slope
		table.insert(list, H.chamfered(Vector3.new(15, 0.3, rng:NextNumber(0.5, 0.7)), onSlope(-11 + (i - 1) * 4.4 + rng:NextNumber(-0.3, 0.3), 0.17), hex("bcd6ee"), { "topSides" }, 0.08))
	end
	for side = -1, 1, 2 do
		table.insert(list, H.chamfered(Vector3.new(1, 0.18, 26.8), onSlope(0, 0.14) * CFrame.new(side * 7.4, 0, 0), hex("eaf2fc"), { "topSides" }, 0.07)) -- snow along the foot of the walls
		for i = 1, 6 do -- retaining wall: ice blocks stepping up with the rail they cover
			local long = 26 / 6
			local z = -13 + (i - 0.5) * long
			local top = z / 13 * 4 + 0.8 + rng:NextNumber(-0.1, 0.1)
			local bottom = -4.3
			table.insert(list, H.chamfered(Vector3.new(3.2, top - bottom, long - 0.1), CFrame.new(side * 9.6, (top + bottom) / 2, z), hex(pick(rng, ice)), { "topSides" }, 0.18))
			table.insert(list, H.chamfered(Vector3.new(3.5, 0.32, long + 0.05), CFrame.new(side * 9.6, top + 0.08, z), hex(pick(rng, snow)), { "topSides" }, 0.12))
			for k = 1, 2 do -- icicles under the cap, outside
				local len = rng:NextNumber(0.7, 1.6)
				table.insert(list, piece("WedgePart", Vector3.new(0.26, len, 0.42), CFrame.new(side * 11.3, top - 0.08 - len / 2, z + (k - 1.5) * 1.6 + rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(math.pi, 0, 0), hex(pick(rng, { "bfe4fa", "d6eefc" }))))
			end
		end
		ST.blob(list, rng, CFrame.new(side * 10.2, -3.9, -13.6), 1.5, 0.9, 1.2, function(v: Vector3): Color3 -- rim stones at the foot
			return hex(if v.Y > 0.4 then "eef4fc" else "768096")
		end, 0.2)
		ST.blob(list, rng, CFrame.new(side * 12, -3.95, -9), 1.1, 0.7, 1, function(v: Vector3): Color3
			return hex(if v.Y > 0.4 then "eef4fc" else "8a94aa")
		end, 0.15)
		ST.blob(list, rng, CFrame.new(side * 9.6, -3.7, -14.6), 3, 0.75, 1.8, function(v: Vector3): Color3 -- snow at the foot
			return hex(if v.Y > 0.5 then "f6faff" else "dce8f8")
		end, 0.1)
	end
	finish(m, "tundra_ice_ramp", list)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = true
		end
	end
	local plate = Instance.new("Part")
	plate.Name = "Slope"
	plate.Size = Vector3.new(16, 0.1, 27.3)
	plate.CFrame = onSlope(0, 0.05)
	plate.Color = hex("dce8f6")
	plate.Material = Enum.Material.SmoothPlastic
	plate.TopSurface, plate.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	plate.Anchored = true
	plate.CanCollide, plate.CanTouch, plate.CanQuery = false, false, false
	local t = Instance.new("Texture")
	t.Name = "SlopeTex"
	t.Texture = Tex.ramp_packed.Id
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU, t.StudsPerTileV = Tex.ramp_packed.Tile, Tex.ramp_packed.Tile
	t.Parent = plate
	plate.Parent = m
	return m
end

function F.tundra_ground_clump(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ground_clump"
	local rng = Random.new(806)
	local list = {}
	ST.blob(list, rng, CFrame.new(0, 0, 0), 2, 0.36, 1.25, function(n: Vector3): Color3
		return hex(if n.Y > 0.5 then "ffffff" else "dce8f8")
	end, 0.12)
	ST.blob(list, rng, CFrame.new(1.2, 0, 0.5), 1, 0.26, 0.8, function(n: Vector3): Color3
		return hex(if n.Y > 0.5 then "f6faff" else "d4e2f4")
	end, 0.08)
	return finish(m, "tundra_ground_clump", list)
end

-- Round 9 part 3: 3 worn flat stones, sunk in the dirt of the mine
function F.mine_ground_flagstones(): Model
	local m = Instance.new("Model")
	m.Name = "mine_ground_flagstones"
	local rng = Random.new(823)
	local list = {}
	for i = 1, 3 do
		local a = i / 3 * TAU + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(0.9, 1.5)
		local size = Vector3.new(rng:NextNumber(1.8, 2.8), 0.34, rng:NextNumber(1.5, 2.2))
		table.insert(list, H.chamfered(size, CFrame.new(math.cos(a) * r, -0.05, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), hex(pick(rng, { "6e6256", "625648", "786a5c" })), { "topSides" }, 0.1))
	end
	return finish(m, "mine_ground_flagstones", list)
end

local BUILD = {
	mine_ground_gravel = function() return pebbles("mine_ground_gravel", 822, "8a7a68", "5c4c3e", 5, 1.6) end,
	hub_ground_curb = function() return curb("hub_ground_curb", 811, { "c8bca8", "bdb09c", "d4c9b6", "b0a490" }, nil, "6fa84a", { key = "pavers", tint = "e8decc", alpha = 0.3 }) end,
	hub_ground_pebbles = function() return pebbles("hub_ground_pebbles", 812, "b8b0a0", "8c8478", 4, 1.4) end,
	plains_ground_curb = function() return curb("plains_ground_curb", 813, { "9c7c52", "b08a58", "8c6e48", "c09a68" }, nil, "4f8a34", { key = "dirt", tint = "e8d8c0", alpha = 0.3 }) end,
	beach_ground_curb = function() return curb("beach_ground_curb", 820, { "d8bc80", "e4cc94", "c8aa70", "f0dcaa" }, nil, "e4c278", { key = "sand", alpha = 0.3 }) end,
	plains_ground_pebbles = function() return pebbles("plains_ground_pebbles", 814, "a8a294", "7c766a", 4, 1.5) end,
	desert_ground_curb = function() return curb("desert_ground_curb", 815, { "d8b67a", "c8a468", "e4c690", "b89458" }, 1.2, "e0bc78", { key = "slabs", alpha = 0.3 }) end,
	canyon_ground_curb = function() return curb("canyon_ground_curb", 821, { "d8a878", "c89868", "e4b888", "b88858" }, 1.2, "dca878", { key = "slabs", tint = "f5d7af", alpha = 0.3 }) end,
	desert_ground_chips = function() return pebbles("desert_ground_chips", 816, "d8b67a", "a8824c", 4, 1.4) end,
	jungle_ground_curb = function() return curb("jungle_ground_curb", 817, { "6e7c62", "76826a", "667258", "5a7a48" }, nil, "4a7a38", { key = "jungle_mossy", alpha = 0.3 }) end,
	tundra_ground_curb = function() return curb("tundra_ground_curb", 818, { "c4d8ee", "d4e4f6", "b4cce6", "e8f2fc" }, 1.1, "eef4fc", { key = "frost_slabs", alpha = 0.3 }) end,
	tundra_ground_chips = function() return pebbles("tundra_ground_chips", 819, "bcd6f0", "86a8cc", 3, 1.3) end,
}
F.IDS = {
	"hub_ground_curb", "hub_ground_pebbles", "plains_ground_curb", "plains_ground_pebbles", "plains_ground_tuft", "plains_ground_flowers",
	"desert_ground_curb", "desert_ground_chips", "desert_ground_ripple", "jungle_ground_curb", "jungle_ground_fern", "jungle_ground_root", "jungle_ground_tuft",
	"tundra_ground_curb", "tundra_ground_chips", "tundra_ground_clump", "tundra_lake_shards", "tundra_ice_ramp", "beach_ground_curb", "canyon_ground_curb", "mine_ground_flagstones", "mine_ground_gravel",
}

function F.build(id: string): string
	local make = BUILD[id] or (F :: any)[id]
	local model = make() :: Model
	R6.install(id, model)
	local tris, parts = 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("PartOperation") then
				tris += d.TriangleCount
			end
		end
	end
	return `{id}: {parts} parts, {tris} tris`
end

---------------------------------------------------------------------
-- ZONES
---------------------------------------------------------------------
local PLAINS = {
	ground = "grass", alpha = 0.3, path = "dirt", fringe = "fringe_grass", width = 7, curb = "plains_ground_curb",
	details = { { "plains_ground_tuft", 70 }, { "plains_ground_flowers", 26 }, { "plains_ground_pebbles", 18 } },
}
local BEACH = {
	ground = "sand", alpha = 0.2, path = "dirt", fringe = "fringe_sand", width = 7, curb = "beach_ground_curb",
	details = { { "desert_ground_ripple", 30 }, { "plains_ground_pebbles", 18 }, { "plains_ground_tuft", 12 } },
}
local DESERT = {
	ground = "sand", alpha = 0.2, path = "slabs", overlay = "cracks", fringe = "fringe_sand", width = 8, curb = "desert_ground_curb",
	details = { { "desert_ground_ripple", 44 }, { "desert_ground_chips", 28 } },
}
local CANYON = {
	ground = "sand", tint = Color3.fromRGB(245, 205, 160), path = "slabs", pathTint = Color3.fromRGB(245, 215, 175), overlay = "cracks", fringe = "fringe_sand", fringeTint = Color3.fromRGB(245, 205, 160),
	width = 8, curb = "canyon_ground_curb", details = { { "desert_ground_chips", 40 }, { "desert_ground_ripple", 14 } },
}
local JUNGLE = {
	ground = "jungle_moss", alpha = 0.12, path = "jungle_cobble", overlay = "leaf_litter", curb = "jungle_ground_curb", -- round 9 part 9: no fringe, JungleRound9 lays soft patches; after F.zone run J.skin, J.blend, J.details
	details = { { "jungle_ground_fern", 46 }, { "jungle_ground_root", 18 }, { "plains_ground_pebbles", 12 } },
}
local TUNDRA = {
	facets = true, path = "frost_slabs", fringe = "fringe_snow", width = 8, curb = "tundra_ground_curb", prints = true,
	details = { { "tundra_ground_clump", 40 }, { "tundra_ground_chips", 18 } },
}
local ZONES: { [string]: any } = {
	Plains_1 = { biome = PLAINS, region = "Plains" }, Plains_2 = { biome = BEACH, region = "Plains" }, Plains_3 = { biome = PLAINS, region = "Plains" },
	Plains_4 = { biome = { cave = true }, region = "Plains" },
	Desert_1 = { biome = DESERT, region = "Desert" }, Desert_2 = { biome = DESERT, region = "Desert" }, Desert_3 = { biome = CANYON, region = "Desert" },
	Jungle_1 = { biome = JUNGLE, region = "Jungle" }, Jungle_2 = { biome = JUNGLE, region = "Jungle" }, Jungle_3 = { biome = JUNGLE, region = "Jungle" },
	Tundra_1 = { biome = TUNDRA, region = "Tundra" }, Tundra_2 = { biome = TUNDRA, region = "Tundra" }, Tundra_3 = { biome = TUNDRA, region = "Tundra" },
}
F.NAMES = { "Plains_1", "Plains_2", "Plains_3", "Plains_4", "Desert_1", "Desert_2", "Desert_3", "Jungle_1", "Jungle_2", "Jungle_3", "Tundra_1", "Tundra_2", "Tundra_3" }
local GROUND_NAMES = { Grass = true, Sand = true, BasePlane = true, CanyonFloor = true, Ground = true, T1FillTop = true }

local function texture(part: BasePart, face: Enum.NormalId, key: string, o: any?): Texture
	local info = Tex[key]
	local t = Instance.new("Texture")
	t.Name = "FloorTex"
	t.Texture = info.Id
	t.Face = face
	t.StudsPerTileU = (o and o.u) or info.Tile
	t.StudsPerTileV = (o and o.v) or info.Tile
	t.OffsetStudsU = (o and o.offset) or 0
	t.Color3 = (o and o.tint) or Color3.new(1, 1, 1)
	t.ZIndex = (o and o.z) or 1
	t.Transparency = (o and o.alpha) or 0
	t.Parent = part
	return t
end

local function decor(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local templates: { [string]: Model } = {}
local function copy(id: string, cf: CFrame, parent: Instance, region: string)
	local m = (templates[id] or (ServerStorage.MapProps :: any)[id]):Clone() :: Model
	templates[id] = (ServerStorage.MapProps :: any)[id]
	local variants = m:FindFirstChild("_Variants")
	if variants then
		variants:Destroy()
	end
	m:PivotTo(cf)
	m:SetAttribute("MapPropId", id)
	m:SetAttribute("Zone", region)
	CollectionService:AddTag(m, "MapProp")
	m.Parent = parent
end

-- the ground under a point when nothing stands on it: the height, or nil
local function probe(allowed: { [Instance]: boolean }, ignore: { Instance }, pos: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(Vector3.new(pos.X, 80, pos.Z), Vector3.new(0, -110, 0), params)
		if not hit then
			return nil
		end
		if hit.Instance.Transparency < 1 then
			return if allowed[hit.Instance] then hit.Position.Y else nil
		end
		table.insert(list, hit.Instance)
	end
	return nil
end

local function segment(p: BasePart): any
	local alongZ = p.Size.Z >= p.Size.X
	return {
		pos = p.Position, top = p.Position.Y + p.Size.Y / 2,
		dir = if alongZ then p.CFrame.LookVector else p.CFrame.RightVector,
		long = if alongZ then p.Size.Z else p.Size.X, wide = if alongZ then p.Size.X else p.Size.Z,
	}
end

local function sideOf(seg: any): Vector3
	return seg.dir:Cross(Vector3.yAxis).Unit
end

local function strip(folder: Instance, b: any, seg: any, side: number, index: number, rng: Random)
	local right = sideOf(seg)
	local w = b.width
	local pos = seg.pos + right * side * seg.wide / 2
	local y = seg.top + 0.04 + (index % 5) * 0.004
	local cf = CFrame.fromMatrix(Vector3.new(pos.X, y - 0.025, pos.Z), seg.dir, Vector3.yAxis, seg.dir:Cross(Vector3.yAxis))
	local p = decor(folder, "Fringe", Vector3.new(seg.long + 4, 0.05, w), cf)
	texture(p, Enum.NormalId.Top, b.fringe, { v = w, offset = rng:NextNumber(0, 26), tint = b.fringeTint or b.tint or Color3.fromRGB(232, 232, 232) })
end

local function nearPath(segs: { any }, pos: Vector3): number
	local best = math.huge
	for _, s in ipairs(segs) do
		local d = pos - s.pos
		d = Vector3.new(d.X, 0, d.Z)
		local along = math.abs(d:Dot(s.dir))
		local across = math.abs(d:Dot(sideOf(s))) - s.wide / 2
		local out = math.max(0, along - s.long / 2)
		local dist = math.sqrt(math.max(0, across) ^ 2 + out ^ 2)
		if across < 0 and out == 0 then
			dist = 0
		end
		best = math.min(best, dist)
	end
	return best
end

local function clearIn(root: Instance, decorFolder: Instance)
	local old = decorFolder:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Texture") and d.Name == "FloorTex" then
			d:Destroy()
		end
	end
end

function F.clear(name: string): string
	if name == "Hub" then
		clearIn(workspace.Hub.Decor, workspace.Hub.Decor)
	else
		local z = (workspace.Zones :: any)[ZONES[name].region][name]
		clearIn(z.Decor, z.Decor)
	end
	return "cleared " .. name
end

-- along the route where a zone has no path part: from the entrance to the gate, for the details only
local function route(z: Instance): { any }
	local entrance = z:FindFirstChild("Entrance") :: BasePart?
	local gate = z:FindFirstChild("Gate")
	if not (entrance and gate) then
		return {}
	end
	local a = entrance.Position
	local b = (gate :: Model):GetPivot().Position
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	return { { pos = Vector3.new((a.X + b.X) / 2, 0, (a.Z + b.Z) / 2), top = 0, dir = d.Unit, long = d.Magnitude, wide = 12, virtual = true } }
end

local function curbs(folder: Instance, b: any, segs: { any }, allowed: any, ignore: { Instance }, rng: Random, region: string): number
	local n = 0
	for _, s in ipairs(segs) do
		if not s.virtual then
			for _, side in ipairs({ -1, 1 }) do
				local t = -s.long / 2 + rng:NextNumber(3, 8)
				while t < s.long / 2 - 3 do
					if rng:NextNumber() < 0.72 then
						local pos = s.pos + s.dir * t + sideOf(s) * side * (s.wide / 2 + rng:NextNumber(-0.1, 0.5))
						local y = probe(allowed, ignore, pos)
						if y then
							local look = (s.dir + sideOf(s) * rng:NextNumber(-0.05, 0.05)).Unit
							local at = Vector3.new(pos.X, math.max(y, s.top), pos.Z) -- at the path's height: the fringe lies lower than the stones
							copy(b.curb, CFrame.lookAt(at, at + look), folder, region)
							n += 1
						end
					end
					t += rng:NextNumber(10, 15)
				end
			end
			task.wait()
		end
	end
	return n
end

local function scatter(folder: Instance, list: { any }, segs: { any }, area: BasePart, allowed: any, ignore: { Instance }, rng: Random, region: string): number
	local placed = 0
	local total = 0
	for _, s in ipairs(segs) do
		total += s.long
	end
	for _, entry in ipairs(list) do
		local id, want = entry[1], entry[2]
		local tries, done = 0, 0
		while done < want and tries < want * 12 do
			tries += 1
			local pos: Vector3
			if #segs > 0 and rng:NextNumber() < 0.78 then
				local at, s = rng:NextNumber(0, total), segs[1]
				for _, c in ipairs(segs) do
					s = c
					at -= c.long
					if at <= 0 then
						break
					end
				end
				local away = s.wide / 2 + 1.2 + rng:NextNumber() ^ 1.8 * 26
				pos = s.pos + s.dir * rng:NextNumber(-s.long / 2, s.long / 2) + sideOf(s) * away * (if rng:NextNumber() < 0.5 then -1 else 1)
			else
				pos = area.Position + Vector3.new(rng:NextNumber(-0.5, 0.5) * area.Size.X, 0, rng:NextNumber(-0.5, 0.5) * area.Size.Z)
			end
			local y = probe(allowed, ignore, pos)
			if y and math.abs(y) < 2.5 and nearPath(segs, pos) > 0.6 then
				copy(id, CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), folder, region)
				done += 1
				placed += 1
				if placed % 25 == 0 then
					task.wait()
				end
			end
		end
	end
	return placed
end

function F.zone(name: string): string
	local spec = ZONES[name]
	local b = spec.biome
	local z = (workspace.Zones :: any)[spec.region][name]
	local d = z.Decor
	clearIn(d, d)
	local rng = Random.new(#name * 1000 + string.byte(name, 1) + string.byte(name, -1) * 7)
	local allowed: { [Instance]: boolean } = {}
	local ground = d:FindFirstChild("Ground")
	if not ground then
		return name .. ": no ground"
	end
	local textured = 0
	if b.cave then
		for _, p in ipairs(ground:GetChildren()) do
			if p:IsA("BasePart") then
				texture(p, Enum.NormalId.Top, "cave_rock")
				textured += 1
			end
		end
		return `{name}: {textured} textures`
	end
	for _, p in ipairs(ground:GetDescendants()) do
		if p:IsA("BasePart") then
			if p:IsA("WedgePart") and b.facets and p.Name == "Facet" then
				local y = p.CFrame.RightVector.Y
				if math.abs(y) > 0.45 then
					texture(p, if y > 0 then Enum.NormalId.Right else Enum.NormalId.Left, "snow", { tint = p.Color })
					textured += 1
				end
				allowed[p] = true
			elseif p:IsA("Part") and p.Shape == Enum.PartType.Block and GROUND_NAMES[p.Name] then
				texture(p, Enum.NormalId.Top, b.ground or "snow", { tint = b.tint, alpha = b.alpha })
				textured += 1
				if p.Size.X * p.Size.Z > 5000 then
					texture(p, Enum.NormalId.Top, "macro_blotch", { z = 2, alpha = 0.45 })
					textured += 1
				end
				allowed[p] = true
			elseif p:IsA("WedgePart") then
				allowed[p] = true
			end
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = d
	local segs = {}
	local paths = d:FindFirstChild("Path") or d:FindFirstChild("Paths")
	local pieces = {}
	if paths then
		for _, p in ipairs(paths:GetDescendants()) do
			if p:IsA("Part") and p.Name ~= "Streak" then
				table.insert(pieces, p)
			end
		end
	end
	table.sort(pieces, function(x, y)
		return x:GetFullName() .. tostring(x.Position) < y:GetFullName() .. tostring(y.Position)
	end)
	for _, p in ipairs(pieces) do
		allowed[p] = true
		local tint = b.pathTint
		if p.Shape == Enum.PartType.Cylinder then
			if p.Name == "Clearing" and p.Color.G > p.Color.R then -- the green clearings of the jungle keep their ground
				texture(p, Enum.NormalId.Right, b.ground, { alpha = b.alpha })
			else
				texture(p, Enum.NormalId.Right, b.path, { tint = tint })
			end
			textured += 1
		elseif p.Shape == Enum.PartType.Block then
			texture(p, Enum.NormalId.Top, b.path, { tint = tint })
			textured += 1
			if b.overlay then
				texture(p, Enum.NormalId.Top, b.overlay, { z = 2, alpha = if b.overlay == "cracks" then 0.5 else 0 })
				textured += 1
			end
			if p.Size.X > 6 or p.Size.Z > 6 then
				table.insert(segs, segment(p))
			end
		end
	end
	for i, s in ipairs(segs) do
		if b.fringe then
			strip(folder, b, s, -1, i * 2, rng)
			strip(folder, b, s, 1, i * 2 + 1, rng)
		end
	end
	local fringes = if b.fringe then #segs * 2 else 0
	if b.prints then
		for i, s in ipairs(segs) do
			local right = sideOf(s)
			local pos = s.pos + right * (s.wide / 2 + 3.5) * (if i % 2 == 0 then 1 else -1)
			local cf = CFrame.fromMatrix(Vector3.new(pos.X, s.top + 0.03, pos.Z), s.dir, Vector3.yAxis, s.dir:Cross(Vector3.yAxis))
			local p = decor(folder, "Prints", Vector3.new(s.long - 6, 0.05, 4), cf)
			texture(p, Enum.NormalId.Top, "footprints", { v = 4, alpha = 0.25 })
		end
	end
	local ignore: { Instance } = { z:FindFirstChild("Bounds") :: Instance, folder }
	local area = z:FindFirstChild("Area") :: BasePart
	table.insert(ignore, area)
	local walk = if #segs > 0 then segs else route(z)
	local nCurb = curbs(folder, b, walk, allowed, ignore, rng, spec.region)
	local nDetail = scatter(folder, b.details, walk, area, allowed, ignore, rng, spec.region)
	return `{name}: {textured} textures, {fringes} fringes, {nCurb} curbs, {nDetail} details`
end

---------------------------------------------------------------------
-- HUB
---------------------------------------------------------------------
local BORDER = Color3.fromRGB(198, 192, 184)
local HUB_BORDER = { PlazaBorder = true, InnerRingDark = true, CenterRingDark = true, AltarDaisBorder = true, FountainSquareBorder = true, WellPad = true, PlazaRay = true }
local HUB_TINT = {
	PlazaFloor = Color3.fromRGB(245, 240, 232), InnerFloor = Color3.fromRGB(255, 244, 214), RingRoad = Color3.fromRGB(255, 240, 205), CenterRing = Color3.fromRGB(245, 240, 232),
	AltarDais = Color3.fromRGB(245, 240, 232), FountainSquare = Color3.fromRGB(245, 240, 232), PortalLane = Color3.fromRGB(245, 240, 232), DockLane = Color3.fromRGB(255, 240, 205),
}

function F.hub(): string
	local d = workspace.Hub.Decor
	clearIn(d, d)
	local rng = Random.new(7001)
	local allowed: { [Instance]: boolean } = {}
	local textured = 0
	for _, p in ipairs(d.Ground:GetChildren()) do
		if p:IsA("Part") then
			texture(p, Enum.NormalId.Right, "grass", { alpha = 0.3 })
			texture(p, Enum.NormalId.Right, "macro_blotch", { z = 2, alpha = 0.45 })
			textured += 2
			allowed[p] = true
		end
	end
	local lanes = {}
	for _, p in ipairs(d.Plaza:GetChildren()) do
		if p:IsA("Part") and HUB_TINT[p.Name] then
			texture(p, if p.Shape == Enum.PartType.Cylinder then Enum.NormalId.Right else Enum.NormalId.Top, "pavers", { tint = HUB_TINT[p.Name] })
			textured += 1
			if p.Name == "RingRoad" then
				allowed[p] = true
			elseif p.Name == "DockLane" then
				table.insert(lanes, p)
			end
		end
	end
	for _, p in ipairs(d.Plaza:GetChildren()) do
		if p:IsA("Part") and HUB_BORDER[p.Name] then
			texture(p, if p.Shape == Enum.PartType.Cylinder then Enum.NormalId.Right else Enum.NormalId.Top, "pavers", { tint = BORDER, u = 9, v = 9 })
			textured += 1
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = d
	-- the outer edge of the ring road: short straight fringes and low curbs round the circle
	local R, N = 99, 48
	local b = { fringe = "fringe_grass", width = 7 }
	local segs = {}
	for i = 1, N do
		local a = (i + 0.5) / N * TAU
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * R
		table.insert(segs, { pos = pos, top = 0.6, dir = Vector3.new(-math.sin(a), 0, math.cos(a)), long = TAU * R / N, wide = 0 })
	end
	for i, s in ipairs(segs) do
		strip(folder, b, s, 1, i, rng)
	end
	for _, p in ipairs(lanes) do
		local s = segment(p)
		s.top = p.Position.Y + p.Size.Y / 2
		strip(folder, b, s, -1, 3, rng)
		strip(folder, b, s, 1, 4, rng)
	end
	local ignore: { Instance } = { workspace.Hub.Bounds, folder, workspace.Hub:FindFirstChild("AFKZone") :: Instance }
	local nCurb = 0
	for i = 1, N, 2 do
		local a = (i + rng:NextNumber(0, 1)) / N * TAU
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (R + rng:NextNumber(-0.2, 0.4))
		local y = probe(allowed, ignore, pos)
		if y then
			copy("hub_ground_curb", CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) + Vector3.new(-math.sin(a), 0, math.cos(a))), folder, "Hub")
			nCurb += 1
		end
	end
	local nDetail = 0
	for _, entry in ipairs({ { "plains_ground_tuft", 110 }, { "plains_ground_flowers", 46 }, { "hub_ground_pebbles", 36 } }) do
		local done, tries = 0, 0
		while done < entry[2] and tries < entry[2] * 14 do
			tries += 1
			local a, r = rng:NextNumber(0, TAU), rng:NextNumber(100.5, 150)
			local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * r
			local y = probe(allowed, ignore, pos)
			if y then
				copy(entry[1], CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), folder, "Hub")
				done += 1
				nDetail += 1
				if nDetail % 25 == 0 then
					task.wait()
				end
			end
		end
	end
	return `Hub: {textured} textures, {N + #lanes * 2} fringes, {nCurb} curbs, {nDetail} details`
end

---------------------------------------------------------------------
-- CHECK: collisions, sizes, spawns
---------------------------------------------------------------------
function F.snapshot(): any
	local out = { count = 0, sum = 0, parts = {} }
	for _, root in ipairs({ workspace.Hub, workspace.Zones }) do
		local n = 0
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") and (p.CanCollide or string.find(p.Name, "Spawn", 1, true)) then
				out.count += 1
				local key = string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", p.Name, p.Position.X, p.Position.Y, p.Position.Z, p.Size.X, p.Size.Y, p.Size.Z)
				out.parts[key] = (out.parts[key] or 0) + 1
			end
			n += 1
			if n % 20000 == 0 then
				task.wait()
			end
		end
	end
	return out
end

function F.compare(before: any): string
	local now = F.snapshot()
	local changed = 0
	for k, v in pairs(before.parts) do
		if now.parts[k] ~= v then
			changed += 1
		end
	end
	for k, v in pairs(now.parts) do
		if before.parts[k] ~= v then
			changed += 1
		end
	end
	return `colliding or spawn parts {before.count} -> {now.count}, {changed} differences`
end

return F
