--[[
	CaveRound9 (dev tool, Edit mode only) - owner prompt "ROUND 9" part 3: the Plains_4 cave becomes a natural mine cavern.
	Source of truth: tools/CaveRound9.luau (= ServerStorage.DevTools.CaveRound9). Recipe: docs/prop_texture_guide.md "Mine cavern".

		local C = require(game.ServerStorage.DevTools.CaveRound9:Clone())
		print(C.walls())    -- strata colours on the shell facets, crack and ore overlay on 60 % of the lower ones
		print(C.tunnel())   -- rock facets around the tunnel; the 3 flat tunnel parts stay as invisible colliders
		print(C.relief())   -- buttresses in the cavern
		print(C.floor())    -- dirt and gravel, rail bed, flagstones, gravel, damp spots
		print(C.lights())   -- warm light pools at the torches, the gold ore and the minecart, 3 on the west side
		print(C.oreLights()) -- the 7 blue ore lights, 12 / 0.7; again after a Sync of that template
		print(C.foot())     -- old dark foot colours -> the new ones, on facets already placed (shell, rock, Plains boss room)
		print(C.crystals()) -- crystals scaled down to small accents: NOT idempotent, run it once
		print(C.variants()) -- Variant "Mine" of the rocks, then Sync.run({ only = ids })

	All new pieces are CanCollide / CanTouch / CanQuery false and go in Decor.MineRock or Decor.FloorDetail. Each step rebuilds its own pieces, same seed, same result.
	WARNING: Sync.run on these rocks resets CanCollide from the template. hub_rock_s_a and s_b of Plains_4 and the stalactites of Volcano_2 are copies with no collision: set them back.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(ServerStorage.DevTools.BuildKit:Clone()) :: any
local Ground = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ground

local C = {}
local hex = Color3.fromHex
local TEX = "RockTex"
local AXIS_X, AXIS_Z = 2000, 900 -- the centre of the cavern

-- bottom to top: dark damp foot, then brown and grey layers, a dark crown
local LAYERS = {
	{ top = 7, colors = { "4f4135", "574838", "4a3d32" } }, -- was 3f342b, 463a30, 3a3029: black where no lamp reaches, see C.foot()
	{ top = 13, colors = { "54463a", "5c4c3e" } },
	{ top = 19, colors = { "74604c", "6c5a48" } },
	{ top = 23, colors = { "7a746a", "6e685e" } },
	{ top = 31, colors = { "7c664e", "705c48" } },
	{ top = 35, colors = { "5a4c40", "544840" } },
	{ top = 44, colors = { "6f6a60", "79726a" } },
	{ top = 1e9, colors = { "4e443c", "564a40", "483e36" } },
}

local VARIANTS: { [string]: { [string]: string } } = {
	hub_rock_l_b = { Rock = "7a6650", RockB = "6a5846" }, -- RockB was "Rock 1": an attribute name cannot hold a space
	hub_rock_m_a = { Rock = "6a5846" },
	hub_rock_s_a = { Rock = "6a5846" },
	hub_rock_s_b = { Body = "75634e" },
	plains_rock_m_b = { RockB = "5a4a3c" },
	plains_rock_stalactite_a = { Spike = "6a5a4a" },
	plains_rock_stalagmite_a = { Spike = "6a5a4a" },
	plains_rock_stalagmite_b = { Spike = "6a5a4a" },
	plains_statue_cave_pillar_a = { Top = "54463a", Waist = "6e5c4a", Rubble = "54463a", Base = "6e5c4a" },
	plains_rock_ore_cluster_blue = { Rock = "54463a" },
	plains_rock_ore_cluster_gold = { Rock = "54463a" },
	plains_rock_crystal_cluster_a = { Rock = "54463a" },
}

local FOOT_REMAP = { ["3f342b"] = "4f4135", ["463a30"] = "574838", ["3a3029"] = "4a3d32" }
local WEST_POOLS = { Vector3.new(1947, 9, 938), Vector3.new(1925, 9, 922), Vector3.new(1946, 9, 900) } -- in front of the buttresses, or their faces stay black

local function zone()
	return workspace.Zones.Plains.Plains_4
end

local function pick(rng: Random, list: { any }): any
	return list[rng:NextInteger(1, #list)]
end

-- the layers tilt and wave a little, so they read as rock and not as stripes
local function strata(rng: Random, p: Vector3): Color3
	local a = math.atan2(p.Z - AXIS_Z, p.X - AXIS_X)
	local h = p.Y + 3.5 * math.sin(a * 2 + 0.7) + 2 * math.sin(a * 5) + 1.8 * math.sin(p.Z / 23)
	for _, layer in ipairs(LAYERS) do
		if h < layer.top then
			return hex(pick(rng, layer.colors))
		end
	end
	return hex(LAYERS[#LAYERS].colors[1])
end

local function overlay(w: BasePart, inward: Vector3, rng: Random)
	local info = Ground.mine_rock
	local t = Instance.new("Texture")
	t.Name = TEX
	t.Texture = info.Id
	t.Face = if w.CFrame.RightVector:Dot(inward) > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	t.StudsPerTileU, t.StudsPerTileV = info.Tile, info.Tile
	t.OffsetStudsU, t.OffsetStudsV = rng:NextNumber(0, info.Tile), rng:NextNumber(0, info.Tile)
	t.Parent = w
end

local function holder(name: string): Folder
	local decor = zone().Decor
	local root = decor:FindFirstChild("MineRock")
	if not root then
		root = Instance.new("Folder")
		root.Name = "MineRock"
		root.Parent = decor
	end
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function tri(folder: Instance, rng: Random, a: Vector3, b: Vector3, c: Vector3, inward: Vector3, textured: boolean)
	local mid = (a + b + c) / 3
	local w1, w2 = Kit.tri(a, b, c, folder, strata(rng, mid), 0.5, Enum.Material.SmoothPlastic)
	for _, w in ipairs({ w1, w2 }) do
		w.CanCollide, w.CanTouch, w.CanQuery, w.CastShadow = false, false, false, false
		if textured then
			overlay(w, inward, rng)
		end
	end
end

local function quad(folder: Instance, rng: Random, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inward: Vector3, flip: boolean, textured: boolean)
	if flip then
		tri(folder, rng, a, b, c, inward, textured)
		tri(folder, rng, b, d, c, inward, textured)
	else
		tri(folder, rng, a, b, d, inward, textured)
		tri(folder, rng, a, d, c, inward, textured)
	end
end

---------------------------------------------------------------------
-- WALLS: the shell keeps its shape and its colliders, only its colours change
---------------------------------------------------------------------
local function skinShell(shell: Instance, center: Vector3): string
	local rng = Random.new(9301)
	local groups: { [string]: { BasePart } } = {}
	for _, w in ipairs(shell:GetChildren()) do
		if w:IsA("WedgePart") then
			for _, old in ipairs(w:GetChildren()) do
				if old.Name == TEX then
					old:Destroy()
				end
			end
			-- the 2 wedges of a triangle share a plane
			local n = w.CFrame.RightVector
			if n.Y < 0 or (n.Y == 0 and n.X < 0) then
				n = -n
			end
			local key = string.format("%.2f,%.2f,%.2f,%.0f", n.X, n.Y, n.Z, n:Dot(w.Position) / 2)
			groups[key] = groups[key] or {}
			table.insert(groups[key], w)
		end
	end
	local textured, count = 0, 0
	for _, list in pairs(groups) do
		local mid = Vector3.zero
		for _, w in ipairs(list) do
			mid += w.Position
		end
		mid /= #list
		local color = strata(rng, mid)
		local skin = mid.Y < 40 and rng:NextNumber() < 0.6
		for _, w in ipairs(list) do
			w.Color = color
			count += 1
			if skin then
				overlay(w, center - w.Position, rng)
				textured += 1
			end
		end
	end
	local cap = shell:FindFirstChild("CapSlab")
	if cap then
		cap.Color = hex("3a3029")
	end
	return `walls: {count} facets recoloured, {textured} with the overlay`
end

function C.walls(): string
	return skinShell(zone().Decor.CaveShell, Vector3.new(AXIS_X, 20, AXIS_Z))
end

-- the boss room is the same mine: same shell colours, same rocks. Its Floor texture comes from EdgesRound9, plan BossRooms.
function C.arena(): string
	local room = ServerStorage.BossArenas.Plains
	local n = 0
	for _, d in ipairs(room:GetDescendants()) do
		if d:IsA("Model") and VARIANTS[d:GetAttribute("MapPropId") or ""] then
			d:SetAttribute("Variant", "Mine")
			n += 1
		end
	end
	return skinShell(room.CaveShell, Vector3.new(2000, 20, -600)) .. `, {n} rocks in Variant Mine`
end

---------------------------------------------------------------------
-- TUNNEL: rock around the corridor; its flat parts stay as invisible colliders
---------------------------------------------------------------------
local PROFILE = { { 15.5, -1.5 }, { 16.8, 5 }, { 16.2, 11 }, { 15.8, 17 }, { 12, 22.5 }, { 6, 25 }, { 0, 25.8 } }
local RINGS = { 733, 745, 756, 768, 779, 791, 802, 814, 824, 829.5 }
local FLARE = 12

local function ring(rng: Random, z: number, last: boolean): { Vector3 }
	local out = {}
	local n = #PROFILE
	for i = 1, 2 * n - 1 do
		local p = if i <= n then PROFILE[i] else PROFILE[2 * n - i]
		local side = if i <= n then -1 else 1
		local x = p[1] * side
		local y = p[2]
		if i > 1 and i < 2 * n - 1 then
			x += rng:NextNumber(0, 1.2) * side
			y += rng:NextNumber(-0.9, 0.9)
		end
		local zz = z
		if last then
			-- a rough collar, along the invisible walls that open into the cavern
			local h = p[1] + FLARE
			x = h * side
			y += 1.5
			zz = 828 + (h - 15) * 0.3
		elseif z > 738 then
			zz += rng:NextNumber(-1.5, 1.5)
		end
		out[i] = Vector3.new(AXIS_X + x, y, zz)
	end
	return out
end

function C.tunnel(): string
	local folder = holder("Tunnel")
	local rng = Random.new(9302)
	local grid = {}
	for i, z in ipairs(RINGS) do
		grid[i] = ring(rng, z, false)
	end
	table.insert(grid, ring(rng, 830, true))
	for i = 1, #grid - 1 do
		local a, b = grid[i], grid[i + 1]
		for j = 1, #a - 1 do
			local mid = (a[j] + b[j + 1]) / 2
			local inward = Vector3.new(AXIS_X, 8, mid.Z) - mid
			quad(folder, rng, a[j], a[j + 1], b[j], b[j + 1], inward, (i + j) % 2 == 0, (i + j) % 2 == 0)
		end
		task.wait()
	end
	local tunnel = zone().Decor.Tunnel
	for _, name in ipairs({ "TunnelWallE", "TunnelWallW", "TunnelCeiling" }) do
		local p = tunnel:FindFirstChild(name) :: BasePart
		p.Transparency = 1
		p.CastShadow = false
	end
	return `tunnel: {#folder:GetChildren()} wedges, 3 flat parts hidden (colliders kept)`
end

---------------------------------------------------------------------
-- RELIEF: buttresses, stuck on the shell. Long strata ledges were tried and read as floating planks: the layers are in the facet colours
---------------------------------------------------------------------
local function shellParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { zone().Decor.CaveShell }
	return params
end

local function surface(params: RaycastParams, degrees: number, y: number): Vector3?
	local a = math.rad(degrees)
	local origin = Vector3.new(AXIS_X, y, AXIS_Z)
	local hit = workspace:Raycast(origin, Vector3.new(math.cos(a), 0, math.sin(a)) * 130, params)
	return hit and hit.Position
end

local BUTTRESS_Y = { 2, 13, 25, 37, 47 }
local BUTTRESS_OUT = { 5.5, 6.5, 5, 3.5, 1.5 }
local BUTTRESS_ANGLES = { 8, 38, 142, 172, 208, 332 }

function C.relief(): string
	local params = shellParams()
	local rng = Random.new(9303)
	local ribs = holder("Buttresses")
	for _, angle in ipairs(BUTTRESS_ANGLES) do
		local rows = {}
		for i, y in ipairs(BUTTRESS_Y) do
			local half = 7.5 - i
			local left = surface(params, angle - half, y)
			local right = surface(params, angle + half, y)
			local mid = surface(params, angle + rng:NextNumber(-1, 1), y)
			if left and right and mid then
				local inward = (Vector3.new(AXIS_X, y, AXIS_Z) - mid).Unit
				table.insert(rows, { left + inward * 0.5, mid + inward * BUTTRESS_OUT[i] + Vector3.new(0, rng:NextNumber(-1.5, 1.5), 0), right + inward * 0.5 })
			end
		end
		for i = 1, #rows - 1 do
			for j = 1, 2 do
				local inward = Vector3.new(AXIS_X, 12, AXIS_Z) - rows[i][j]
				quad(ribs, rng, rows[i][j], rows[i][j + 1], rows[i + 1][j], rows[i + 1][j + 1], inward, j == 1, i % 2 == 1)
			end
		end
		task.wait()
	end
	return `relief: {#ribs:GetChildren()} buttress wedges`
end

---------------------------------------------------------------------
-- FLOOR
---------------------------------------------------------------------
local function detailPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
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

local function copy(id: string, cf: CFrame, parent: Instance)
	local m = (ServerStorage.MapProps :: any)[id]:Clone() :: Model
	local variants = m:FindFirstChild("_Variants")
	if variants then
		variants:Destroy()
	end
	m:PivotTo(cf)
	m:SetAttribute("MapPropId", id)
	m:SetAttribute("Zone", "Plains")
	CollectionService:AddTag(m, "MapProp")
	m.Parent = parent
end

local FLOOR_TILE = 30

function C.floor(): string
	local z = zone()
	local floor = z.Decor.Ground.CaveFloor
	floor.Color = hex("6e5a46")
	local main = floor:FindFirstChild("FloorTex") :: Texture
	main.Texture = Ground.mine_dirt.Id
	main.StudsPerTileU, main.StudsPerTileV = FLOOR_TILE, FLOOR_TILE
	main.Color3 = Color3.fromRGB(236, 232, 226)
	local macro = floor:FindFirstChild("FloorMacro") :: Texture?
	if not macro then
		local t = Instance.new("Texture")
		t.Name = "FloorMacro"
		t.Face = Enum.NormalId.Top
		t.ZIndex = 2
		t.Parent = floor
		macro = t
	end
	local m = macro :: Texture
	m.Texture = Ground.macro_blotch.Id
	m.StudsPerTileU, m.StudsPerTileV = Ground.macro_blotch.Tile, Ground.macro_blotch.Tile
	local old = z.Decor:FindFirstChild("FloorDetail")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FloorDetail"
	folder.Parent = z.Decor
	-- rail bed: a soft dark band under the sleepers (the rails run from z 750 to 872)
	local bed = detailPart(folder, "RailBed", Vector3.new(132, 0.04, 11), CFrame.new(AXIS_X, 0.01, 811) * CFrame.Angles(0, math.pi / 2, 0))
	local t = Instance.new("Texture")
	t.Name = "BedTex"
	t.Texture = Ground.mine_railbed.Id
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU, t.StudsPerTileV = Ground.mine_railbed.Tile, 11
	t.Parent = bed
	local rng = Random.new(9304)
	-- flagstones along the rails, gravel everywhere, damp spots
	local stones, gravel, damp = 0, 0, 0
	for zz = 752, 868, 13 do
		for _, side in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.7 then
				copy("mine_ground_flagstones", CFrame.new(AXIS_X + side * rng:NextNumber(6.5, 8.5), 0, zz + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), folder)
				stones += 1
			end
		end
	end
	for _ = 1, 44 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(8, 80)
		local p = if rng:NextNumber() < 0.25 then Vector3.new(AXIS_X + rng:NextNumber(-13, 13), 0, rng:NextNumber(742, 828)) else Vector3.new(AXIS_X + math.cos(a) * r * 1.02, 0, AXIS_Z + math.sin(a) * r * 0.88)
		copy("mine_ground_gravel", CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), folder)
		gravel += 1
	end
	local spots = { { 2010, 761, 7 }, { 1991, 795, 6 }, { 2012, 816, 8 }, { 1972, 862, 11 }, { 2036, 876, 13 }, { 1950, 905, 12 }, { 2062, 908, 10 }, { 2018, 925, 9 }, { 1978, 935, 8 } }
	for _, s in ipairs(spots) do
		local k = rng:NextNumber(0.75, 1)
		local p = detailPart(folder, "DampSpot", Vector3.new(s[3], 0.04, s[3] * k), CFrame.new(s[1], 0.015, s[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		local d = Instance.new("Decal")
		d.Name = "Damp"
		d.Texture = Ground.mine_puddle.Id
		d.Face = Enum.NormalId.Top
		d.Parent = p
		damp += 1
	end
	return `floor: {stones} flagstones, {gravel} gravel, {damp} damp spots, 1 rail bed`
end

---------------------------------------------------------------------
-- LIGHT POOLS: warm, next to a lantern or a torch that is already there
---------------------------------------------------------------------
function C.lights(): string
	local z = zone()
	local old = z.Decor.MineRock:FindFirstChild("LightPools")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "LightPools"
	folder.Parent = z.Decor.MineRock
	local function pool(p: Vector3, range: number, brightness: number)
		local part = detailPart(folder, "Pool", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p))
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 200, 142)
		l.Range, l.Brightness, l.Shadows = range, brightness, false
		l.Parent = part
	end
	local n = 0
	for _, m in ipairs(z.Decor.Cavern:GetChildren()) do
		if m.Name == "Torch_Standing" and m:GetPivot().Z < 945 then -- not the 2 at the portal: it has its own glow
			pool(m:GetPivot().Position + Vector3.new(0, 7, 0), 32, 0.75)
			n += 1
		end
	end
	for _, m in ipairs(z.Decor.Cavern:GetChildren()) do
		if m.Name == "Ore_Cluster_Gold" then
			pool(m:GetPivot().Position + Vector3.new(0, 8, 0), 34, 0.6)
			n += 1
		end
	end
	for _, m in ipairs(z.Decor.Mine:GetChildren()) do
		if m.Name == "Minecart_A" and m:GetPivot().Z > 850 then
			pool(m:GetPivot().Position + Vector3.new(0, 9, 0), 36, 0.6)
			n += 1
		end
		if m.Name == "Mine_Support" then
			pool(m:GetPivot().Position + Vector3.new(0, 13, 0), 18, 0.25) -- the tunnel is narrow: the wall torches already fill it
			n += 1
		end
	end
	-- the west side has no gold ore, so it had no pool: its foot read as black holes and its floor stayed dark
	for _, p in ipairs(WEST_POOLS) do
		pool(p, 36, 0.65)
		n += 1
	end
	return `lights: {n} warm pools`
end

-- Part 3 meant these 7 lights to be 12 / 0.7 too. At 26 / 1.5 they wash the west wall blue and fight the warm pools for the light budget.
-- Sync.run on plains_rock_ore_cluster_blue puts the template's 26 / 1.5 back: run this after it.
function C.oreLights(): string
	local n = 0
	for _, m in ipairs(zone().Decor.Cavern:GetChildren()) do
		if m.Name == "Ore_Cluster_Blue" then
			for _, l in ipairs(m:GetDescendants()) do
				if l:IsA("PointLight") then
					l.Range, l.Brightness = 12, 0.7
					n += 1
				end
			end
		end
	end
	return `ore lights: {n} set to 12 / 0.7`
end

-- Colours only, no shape and no collider: strata() is random, so re-running walls() would re-roll every facet.
function C.foot(): string
	local n = 0
	local function remap(root: Instance)
		for _, w in ipairs(root:GetDescendants()) do
			if w:IsA("WedgePart") then
				local new = FOOT_REMAP[w.Color:ToHex()]
				if new then
					w.Color = hex(new)
					n += 1
				end
			end
		end
	end
	remap(zone().Decor.CaveShell)
	remap(zone().Decor.MineRock)
	remap(ServerStorage.BossArenas.Plains.CaveShell)
	return `foot: {n} facets recoloured`
end

---------------------------------------------------------------------
-- CRYSTALS: small accents. Scaled where they stand; their colliders shrink with them.
---------------------------------------------------------------------
function C.crystals(): string
	local n = 0
	local z = zone()
	local function shrink(m: Model, k: number)
		m:ScaleTo(m:GetScale() * k)
		n += 1
	end
	for _, m in ipairs(z.Decor.Landmark:GetChildren()) do
		if m:IsA("Model") then
			shrink(m, 0.4)
		end
	end
	for _, m in ipairs(z.Decor.Cavern:GetChildren()) do
		if m.Name == "Crystal_Cluster_A" then
			shrink(m, 0.5)
		elseif m.Name == "Ore_Cluster_Blue" then
			shrink(m, 0.6)
		end
	end
	return `crystals: {n} scaled down`
end

---------------------------------------------------------------------
-- VARIANT "Mine": the same rocks in the palette of the mine; the templates keep their own colours for the rest of the map
---------------------------------------------------------------------
function C.variants(): { string }
	local ids = {}
	for id, colors in pairs(VARIANTS) do
		table.insert(ids, id)
		local template = (ServerStorage.MapProps :: any)[id]
		for _, d in ipairs(template:GetDescendants()) do
			if d.Name == "Rock 1" then
				d.Name = "RockB"
			end
		end
		local folder = template:FindFirstChild("_Variants")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "_Variants"
			folder.Parent = template
		end
		local config = folder:FindFirstChild("Mine")
		if not config then
			config = Instance.new("Configuration")
			config.Name = "Mine"
			config.Parent = folder
		end
		for part, color in pairs(colors) do
			config:SetAttribute("Color_" .. part, hex(color))
		end
	end
	for _, d in ipairs(zone().Decor:GetDescendants()) do
		if d:IsA("Model") and VARIANTS[d:GetAttribute("MapPropId") or ""] then
			d:SetAttribute("Variant", "Mine")
		end
	end
	return ids
end

return C
