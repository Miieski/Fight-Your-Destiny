--[[
	LakeRound9 (dev tool, Edit mode only) - owner prompt "ROUND 9" part 10: the frozen lake of Tundra_2 (image 17).
	Source of truth: tools/LakeRound9.luau (= ServerStorage.DevTools.LakeRound9). Images: tools/make_floor_textures.py --tundra. Recipe: docs/prop_texture_guide.md "Frozen lake".

		local L = require(game.ServerStorage.DevTools.LakeRound9:Clone())
		print(L.depth())   -- the facets take a gradient from the shore to the centre, a very soft shine; shape and colliders unchanged
		print(L.ice())     -- strips with one shared tile over the whole lake: frost, deep cracks, fine white cracks, bubbles
		print(L.cracks())  -- the 123 old blue crack parts become thin white lines
		print(L.marks())   -- a few frost and bubble Decals
		print(L.shore())   -- slush Decals along the shore, ice shards at its edge

	Everything new goes in Decor.LakeSkin: CanCollide, CanTouch, CanQuery, CastShadow false, no script. Each step rebuilds its own pieces, same seed, same result.
	No gameplay reads the lake: fishing props, holes (OpenWater, HoleRim, RimIce) and the Ice_Chunk models are not touched.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ground = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ground

local L = {}
local CX, CZ = 8000, 291
local TOP_Y = 0.14 -- top of the facets
local STEP = 18 -- depth of one strip
local TOP = Enum.NormalId.Top
local HOLES = { Vector2.new(8030, 215), Vector2.new(7965, 365), Vector2.new(8080, 300), Vector2.new(7930, 300) } -- the fishing holes: no Decal on their water

local function lake(): any
	return (workspace.Zones :: any).Tundra.Tundra_2.Decor.Lake
end

local function holder(name: string): Instance
	local d = (workspace.Zones :: any).Tundra.Tundra_2.Decor
	local skin = d:FindFirstChild("LakeSkin")
	if not skin then
		skin = Instance.new("Folder")
		skin.Name = "LakeSkin"
		skin.Parent = d
	end
	local old = skin:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = skin
	return f
end

local function params(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	local list = {}
	for _, x in ipairs(lake():GetChildren()) do
		if x:IsA("WedgePart") then
			table.insert(list, x)
		end
	end
	p.FilterDescendantsInstances = list
	return p
end

local function onIce(p: RaycastParams, x: number, z: number): boolean
	return workspace:Raycast(Vector3.new(x, 5, z), Vector3.new(0, -8, 0), p) ~= nil
end

-- the shore, as the last point on the ice along each ray from the centre
local function shoreline(p: RaycastParams): { Vector3 }
	local out = {}
	for a = 0, 359, 3 do
		local d = Vector3.new(math.cos(math.rad(a)), 0, math.sin(math.rad(a)))
		local last = 60
		for r = 60, 170, 1.5 do
			local q = Vector3.new(CX, 0, CZ) + d * r
			if onIce(p, q.X, q.Z) then
				last = r
			end
		end
		table.insert(out, Vector3.new(CX, 0, CZ) + d * last)
	end
	return out
end

local function flat(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local q = Instance.new("Part")
	q.Name = name
	q.Size = size
	q.CFrame = cf
	q.Anchored = true
	q.Transparency = 1
	q.CanCollide, q.CanTouch, q.CanQuery, q.CastShadow = false, false, false, false
	q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	q.Parent = parent
	return q
end

local function decal(part: BasePart, key: string, transparency: number?)
	local d = Instance.new("Decal")
	d.Texture = Ground[key].Id
	d.Face = TOP
	d.Transparency = transparency or 0
	d.Parent = part
end

local SHORE, MID, DEEP = Color3.fromHex("cfeefc"), Color3.fromHex("8fcdf4"), Color3.fromHex("4c94dc")

function L.depth(): string
	local p = params()
	local shore = shoreline(p)
	local n = 0
	for _, f in ipairs(lake():GetChildren()) do
		if f:IsA("WedgePart") then
			if not f:GetAttribute("IceBase") then
				f:SetAttribute("IceBase", f.Color)
			end
			local base = f:GetAttribute("IceBase") :: Color3
			local best = math.huge
			for _, s in ipairs(shore) do
				best = math.min(best, (Vector3.new(f.Position.X, 0, f.Position.Z) - s).Magnitude)
			end
			local t = math.clamp(best / 80, 0, 1)
			t = t * t * (3 - 2 * t)
			local c = if t < 0.5 then SHORE:Lerp(MID, t * 2) else MID:Lerp(DEEP, t * 2 - 1)
			local shade = (base.R + base.G + base.B) / 3 / 0.8 -- the old facet tones stay as small steps, the low-poly look
			f.Color = Color3.new(math.clamp(c.R * shade, 0, 1), math.clamp(c.G * shade, 0, 1), math.clamp(c.B * shade, 0, 1))
			f.Reflectance = 0.06
			n += 1
			if n % 60 == 0 then
				task.wait()
			end
		end
	end
	return `{n} facets`
end

function L.ice(): string
	local folder = holder("Ice")
	local p = params()
	local info = Ground.lake_ice
	local z = 180
	local rows, area = 0, 0
	while z < 402 do
		local z2 = z + STEP
		-- the widest run of ice in this row, both rims on the ice
		local first, last = nil, nil
		for x = 7880, 8120, 3 do
			if onIce(p, x, z + 0.5) and onIce(p, x, z2 - 0.5) then
				first = first or x
				last = x
			end
		end
		if first then
			local function emit(x0: number, x1: number, z0: number, z1: number)
				if x1 - x0 < 0.5 or z1 - z0 < 0.5 then
					return
				end
				local part = flat(folder, "LakeIce", Vector3.new(x1 - x0, 0.05, z1 - z0), CFrame.new((x0 + x1) / 2, TOP_Y + 0.016 - 0.025, (z0 + z1) / 2)) -- top 0.156, under the Water of the fishing holes (0.17)
				local t = Instance.new("Texture")
				t.Name = "IceTex"
				t.Texture = info.Id
				t.Face = TOP
				t.StudsPerTileU, t.StudsPerTileV = info.Tile, info.Tile
				-- world aligned, so the cracks run on from one piece to the next. On a Top face a Texture starts at the +X +Z corner and runs towards -X -Z: tested
				t.OffsetStudsU = -x1 % info.Tile
				t.OffsetStudsV = -z1 % info.Tile
				t.Parent = part
				rows += 1
				area += (x1 - x0) * (z1 - z0)
			end
			-- the Water of a fishing hole is see-through, so the ice must not pass behind it: each hole gets a square gap, hidden by its Ice ring
			local cuts = {}
			for _, h in ipairs(HOLES) do
				if h.Y + 3.4 > z and h.Y - 3.4 < z2 and h.X > first and h.X < last then
					table.insert(cuts, h)
				end
			end
			table.sort(cuts, function(u, v)
				return u.X < v.X
			end)
			local x = first
			for _, h in ipairs(cuts) do
				emit(x, h.X - 3.4, z, z2)
				emit(h.X - 3.4, h.X + 3.4, z, h.Y - 3.4)
				emit(h.X - 3.4, h.X + 3.4, h.Y + 3.4, z2)
				x = h.X + 3.4
			end
			emit(x, last, z, z2)
		end
		z = z2
	end
	return `{rows} strips, {math.floor(area)} studs2`
end

function L.cracks(): string
	local n = 0
	for _, c in ipairs(lake():GetChildren()) do
		if c.Name == "Crack" and c:IsA("BasePart") then
			if not c:GetAttribute("OldWide") then
				c:SetAttribute("OldWide", c.Size.X)
			end
			c.Color = Color3.fromHex("eaf6ff")
			c.Size = Vector3.new(math.max(0.12, (c:GetAttribute("OldWide") :: number) * 0.55), c.Size.Y, c.Size.Z)
			c.Transparency = 0.2
			c.CastShadow = false
			n += 1
		end
	end
	return `{n} cracks`
end

function L.marks(): string
	local p = params()
	local folder = holder("Marks")
	local rng = Random.new(1010)
	local frost, bubbles = 0, 0
	local function spot(name: string, key: string, y: number, w: number, d: number, alpha: number): boolean
		for _ = 1, 30 do
			local x, z = CX + rng:NextNumber(-105, 105), CZ + rng:NextNumber(-105, 105)
			local dx = math.sqrt(w * w + d * d) * 0.36
			local clear = true
			for _, h in ipairs(HOLES) do
				clear = clear and (Vector2.new(x, z) - h).Magnitude > dx * 1.5 + 6
			end
			if clear and onIce(p, x, z) and onIce(p, x + dx, z) and onIce(p, x - dx, z) and onIce(p, x, z + dx) and onIce(p, x, z - dx) then
				local part = flat(folder, name, Vector3.new(w, 0.05, d), CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				decal(part, key, alpha)
				return true
			end
		end
		return false
	end
	for _ = 1, 14 do
		if spot("Frost", "lake_frost", TOP_Y + 0.04, rng:NextNumber(26, 48), rng:NextNumber(20, 36), 0.1) then
			frost += 1
		end
	end
	for _ = 1, 10 do
		if spot("Bubbles", "lake_bubbles", TOP_Y + 0.05, rng:NextNumber(9, 14), rng:NextNumber(7, 11), 0.05) then
			bubbles += 1
		end
	end
	return `{frost} frost, {bubbles} bubbles`
end

function L.shore(): string
	local p = params()
	local shore = shoreline(p)
	local folder = holder("Shore")
	local rng = Random.new(1011)
	local slush, shards = 0, 0
	local walked = 16
	for i, s in ipairs(shore) do
		local nxt = shore[i % #shore + 1]
		walked += (nxt - s).Magnitude
		if walked >= 15 then
			walked = rng:NextNumber(-2, 2)
			local tangent = (nxt - s).Unit
			local inward = (Vector3.new(CX, 0, CZ) - s).Unit
			local at = s + inward * rng:NextNumber(-1, 3)
			local dir = (CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0) * tangent).Unit
			local part = flat(folder, "Slush", Vector3.new(rng:NextNumber(26, 34), 0.05, rng:NextNumber(14, 20)), CFrame.fromMatrix(Vector3.new(at.X, TOP_Y + 0.06, at.Z), dir, Vector3.yAxis, dir:Cross(Vector3.yAxis)))
			decal(part, "lake_slush")
			slush += 1
		end
		if i % 3 == 0 then
			local inward = (Vector3.new(CX, 0, CZ) - s).Unit
			local at = s + inward * rng:NextNumber(2, 9) + (nxt - s).Unit * rng:NextNumber(-3, 3)
			local copy = (ServerStorage.MapProps :: any).tundra_lake_shards:Clone() :: Model
			local variants = copy:FindFirstChild("_Variants")
			if variants then
				variants:Destroy()
			end
			copy:PivotTo(CFrame.new(at.X, TOP_Y, at.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			copy:SetAttribute("MapPropId", "tundra_lake_shards")
			copy:SetAttribute("Zone", "Tundra")
			CollectionService:AddTag(copy, "MapProp")
			copy.Parent = folder
			shards += 1
		end
		if i % 30 == 0 then
			task.wait()
		end
	end
	return `{slush} slush, {shards} shards`
end

return L
