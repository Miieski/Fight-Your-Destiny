--[[
	JungleRound9 (dev tool, Edit mode only) - owner prompt "ROUND 9" part 9: one ground set for the whole jungle (images 13-16).
	Source of truth: tools/JungleRound9.luau (= ServerStorage.DevTools.JungleRound9). Images: tools/make_floor_textures.py --jungle. Recipe: docs/prop_texture_guide.md "Jungle ground".

		local J = require(game.ServerStorage.DevTools.JungleRound9:Clone())
		print(J.counts())        -- fringe panels and patches, per area
		print(J.skin(id))        -- ground, paths, clearings, corridor, plaza take the set
		print(J.blend(id))       -- the Fringe panels go, soft moss and dirt patches along every path edge, loose cobbles at the corridor ends
		print(J.details(id))     -- grass tufts, ferns and roots along the edges

	id = Jungle_1, Jungle_2, Jungle_3. Each step rebuilds its own pieces, same seed, same result. Nothing here collides; Paths, Plaza and Corridor.Path never did, only those get their height changed.
	Patches: Part Transparency 1 + Decal, in Decor.FloorDetail, CanCollide / CanTouch / CanQuery / CastShadow false, no script.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ground = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ground

local J = {}
local TEX, PATCH, FADE, FOLDER = "FloorTex", "GroundPatch", "CobbleFade", "FloorDetail"
local TOP, RIGHT = Enum.NormalId.Top, Enum.NormalId.Right
local MOSS_Y, DIRT_Y = 0.27, 0.25 -- over the paths (0.2), the cylinders (0.22), the curb feet (0.25)
local ALPHA = 0.12
local GREEN = Color3.fromHex("349c3c")
local UP = Vector3.yAxis
J.ZONES = { "Jungle_1", "Jungle_2", "Jungle_3" }

local function sub(id: string): any
	return (workspace.Zones :: any).Jungle[id]
end

local function wipe(part: BasePart)
	for _, t in ipairs(part:GetChildren()) do
		if t.Name == TEX then
			t:Destroy()
		end
	end
end

local function put(part: BasePart, face: Enum.NormalId, key: string, o: any?)
	local info = Ground[key]
	local t = Instance.new("Texture")
	t.Name = TEX
	t.Texture = info.Id
	t.Face = face
	t.StudsPerTileU, t.StudsPerTileV = info.Tile, info.Tile
	t.OffsetStudsU = (o and o.offset) or 0
	t.Color3 = (o and o.tint) or Color3.new(1, 1, 1)
	t.ZIndex = (o and o.z) or 1
	t.Transparency = (o and o.alpha) or 0
	t.Parent = part
end

local function isCylinder(p: BasePart): boolean
	return p:IsA("Part") and p.Shape == Enum.PartType.Cylinder
end

local function green(p: BasePart): boolean
	return p:GetAttribute("GreenClearing") == true or p.Color.G > p.Color.R
end

local function each(root: Instance?, fn: (BasePart) -> ())
	if root then
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") then
				fn(p)
			end
		end
	end
end

function J.skin(id: string): string
	local d = sub(id).Decor
	local n = 0
	local function ground(p: BasePart)
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Name == "Ground" then
			wipe(p)
			put(p, TOP, "jungle_moss", { alpha = ALPHA })
			n += 1
			if p.Size.X * p.Size.Z > 5000 then
				put(p, TOP, "macro_blotch", { z = 2, alpha = 0.45 })
				n += 1
			end
		end
	end
	each(d:FindFirstChild("Ground"), ground)
	local corridor = d:FindFirstChild("Corridor")
	if corridor then
		ground(corridor.Ground)
		wipe(corridor.Path)
		corridor.Path.Position = Vector3.new(corridor.Path.Position.X, 0.08, corridor.Path.Position.Z) -- under the path that overlaps its end: no coplanar faces
		put(corridor.Path, TOP, "jungle_dirt")
		n += 1
	end
	each(d:FindFirstChild("Paths"), function(p: BasePart)
		wipe(p)
		if p.Name == "Clearing" then
			if green(p) then
				p:SetAttribute("GreenClearing", true)
				p.Color = GREEN -- same green as the ground, so the disc has no rim
				put(p, RIGHT, "jungle_moss", { alpha = ALPHA })
			else
				put(p, RIGHT, "jungle_dirt")
			end
		elseif isCylinder(p) then
			p.Position = Vector3.new(p.Position.X, 0.12, p.Position.Z) -- 0.02 over the blocks: they used to share the top face
			put(p, RIGHT, "jungle_cobble")
		else
			put(p, TOP, "jungle_cobble")
			put(p, TOP, "leaf_litter", { z = 2, alpha = 0.45 })
			n += 1
		end
		n += 1
	end)
	local plaza = d:FindFirstChild("Plaza")
	if plaza then
		for _, p in ipairs(plaza:GetChildren()) do
			if p.Name == "Plaza" then
				wipe(p)
				put(p, TOP, "jungle_slab")
				put(p, TOP, "macro_blotch", { z = 2, alpha = 0.45 })
				n += 2
			end
		end
	end
	return `{id}: {n} textures`
end

---------------------------------------------------------------------
-- the outline of the paths
---------------------------------------------------------------------
local function rect(list: { any }, p: BasePart, grow: number?, closed: boolean?)
	local alongZ = p.Size.Z >= p.Size.X
	local dir = if alongZ then p.CFrame.LookVector else p.CFrame.RightVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	table.insert(list, {
		kind = "rect", pos = p.Position, dir = dir, side = dir:Cross(UP), closed = closed,
		long = (if alongZ then p.Size.Z else p.Size.X) + (grow or 0), wide = (if alongZ then p.Size.X else p.Size.Z) + (grow or 0),
	})
end

local function shapes(id: string): { any }
	local d = sub(id).Decor
	local list = {}
	each(d:FindFirstChild("Paths"), function(p: BasePart)
		if isCylinder(p) then
			if not (p.Name == "Clearing" and green(p)) then
				table.insert(list, { kind = "disc", pos = p.Position, r = p.Size.Y / 2, path = p.Name == "Path" })
			end
		else
			rect(list, p)
		end
	end)
	local corridor = d:FindFirstChild("Corridor")
	if corridor then
		rect(list, corridor.Path)
		list[#list].corridor = true
	end
	local plaza = d:FindFirstChild("Plaza")
	if plaza then
		for _, p in ipairs(plaza:GetChildren()) do
			if p.Name == "Plaza" then
				rect(list, p, 6, true)
			end
		end
	end
	return list
end

local function inside(list: { any }, pos: Vector3, margin: number, skip: any): boolean
	for _, s in ipairs(list) do
		if s ~= skip then
			local d = pos - s.pos
			d = Vector3.new(d.X, 0, d.Z)
			if s.kind == "disc" then
				if d.Magnitude < s.r - margin then
					return true
				end
			elseif math.abs(d:Dot(s.dir)) < s.long / 2 - margin and math.abs(d:Dot(s.side)) < s.wide / 2 - margin then
				return true
			end
		end
	end
	return false
end

local function rays(id: string): RaycastParams
	local d = sub(id).Decor
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = { d.Paths }
	for _, name in ipairs({ "Ground", "Corridor", "Plaza" }) do
		if d:FindFirstChild(name) then
			table.insert(list, d[name])
		end
	end
	params.FilterDescendantsInstances = list
	return params
end

-- the height of the walkable ground under a point, or nil over water or a bank
local function height(params: RaycastParams, pos: Vector3): number?
	local hit = workspace:Raycast(Vector3.new(pos.X, 30, pos.Z), Vector3.new(0, -40, 0), params)
	if hit and hit.Position.Y > -0.6 and hit.Position.Y < 0.5 and hit.Instance.Name ~= "Rock" and hit.Instance.Name ~= "Rock 1" then
		return hit.Position.Y
	end
	return nil
end

-- walks every open outline: fn(point on the edge, tangent, outward, shape)
local function walk(list: { any }, rng: Random, low: number, high: number, fn: (Vector3, Vector3, Vector3, any) -> ())
	local n = 0
	for _, s in ipairs(list) do
		if s.kind == "rect" then
			for side = -1, 1, 2 do
				local t = -s.long / 2 + rng:NextNumber(0, low)
				while t < s.long / 2 do
					fn(s.pos + s.dir * t + s.side * side * s.wide / 2, s.dir, s.side * side, s)
					t += rng:NextNumber(low, high)
				end
				if s.closed then
					local t2 = -s.wide / 2 + rng:NextNumber(0, low)
					while t2 < s.wide / 2 do
						fn(s.pos + s.side * t2 + s.dir * side * s.long / 2, s.side, s.dir * side, s)
						t2 += rng:NextNumber(low, high)
					end
				end
			end
		else
			local a = rng:NextNumber(0, 6.28)
			local stop = a + 6.28
			while a < stop do
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				fn(s.pos + out * s.r, out:Cross(UP), out, s)
				a += rng:NextNumber(low, high) / s.r
			end
		end
		n += 1
		if n % 4 == 0 then
			task.wait()
		end
	end
end

local added = 0
local function patch(folder: Instance, params: RaycastParams, pos: Vector3, dir: Vector3, long: number, wide: number, key: string): boolean
	local side = dir:Cross(UP)
	for _, o in ipairs({ { 0, 0 }, { 0.33, 0.33 }, { -0.33, 0.33 }, { 0.33, -0.33 }, { -0.33, -0.33 } }) do
		if not height(params, pos + dir * o[1] * long + side * o[2] * wide) then
			return false
		end
	end
	added += 1
	local y = (if key == "jungle_dirt_patch" then DIRT_Y else MOSS_Y) + (added % 4) * 0.003
	local p = Instance.new("Part")
	p.Name = PATCH
	p.Size = Vector3.new(long, 0.05, wide)
	p.CFrame = CFrame.fromMatrix(Vector3.new(pos.X, y - 0.025, pos.Z), dir, UP, side)
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local decal = Instance.new("Decal")
	decal.Texture = Ground[key].Id
	decal.Face = TOP
	decal.Parent = p
	p.Parent = folder
	return true
end

local function turned(dir: Vector3, a: number): Vector3
	return (CFrame.Angles(0, a, 0) * dir).Unit
end

-- the loose cobbles where a stone path ends on the dirt of a gate corridor
local function fades(id: string, folder: Instance): number
	local corridor = sub(id).Decor:FindFirstChild("Corridor")
	if not corridor then
		return 0
	end
	local discs = {}
	for _, z in ipairs(J.ZONES) do
		for _, s in ipairs(shapes(z)) do
			if s.kind == "disc" and s.path then
				table.insert(discs, s)
			end
		end
	end
	local path = corridor.Path
	local n = 0
	for e = -1, 1, 2 do
		local tip = path.Position + Vector3.new(0, 0, e * path.Size.Z / 2)
		local best, far = nil, 14
		for _, s in ipairs(discs) do
			local d = (s.pos - tip).Magnitude
			if d < far then
				best, far = s, d
			end
		end
		if best then
			local toward = Vector3.new(0, 0, -e)
			local at = best.pos + toward * (best.r + 3.5)
			local p = Instance.new("Part")
			p.Name = FADE
			p.Size = Vector3.new(17.4, 0.05, 11)
			p.CFrame = CFrame.lookAt(Vector3.new(at.X, 0.235, at.Z), Vector3.new(at.X, 0.235, at.Z) + toward)
			p.Anchored = true
			p.Transparency = 1
			p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
			local decal = Instance.new("Decal")
			decal.Texture = Ground.jungle_cobble_fade.Id
			decal.Face = TOP
			decal.Parent = p
			p.Parent = folder
			n += 1
		end
	end
	return n
end

function J.blend(id: string): string
	local d = sub(id).Decor
	local folder = d[FOLDER]
	local gone = 0
	for _, p in ipairs(folder:GetChildren()) do
		if p.Name == "Fringe" then
			gone += 1
			p:Destroy()
		elseif p.Name == PATCH or p.Name == FADE then
			p:Destroy()
		end
	end
	local list = shapes(id)
	local params = rays(id)
	local rng = Random.new(90900 + string.byte(id, -1))
	local moss, dirt, worn = 0, 0, 0
	walk(list, rng, 5.5, 7.5, function(edge: Vector3, tangent: Vector3, out: Vector3, s: any)
		local dir = turned(tangent, rng:NextNumber(-0.3, 0.3)) * (if rng:NextNumber() < 0.5 then 1 else -1)
		if inside(list, edge, 0.5, s) then
			-- the rim of a stone disc across a path: its cobbles do not line up with the path's, small patches break the arc
			if s.kind == "disc" and s.path and rng:NextNumber() < 0.6 then
				if patch(folder, params, edge + out * rng:NextNumber(-1.5, 1.5), dir, rng:NextNumber(5, 8), rng:NextNumber(3.5, 5.5), if rng:NextNumber() < 0.5 then "jungle_moss_a" else "jungle_moss_b") then
					worn += 1
				end
			end
			return
		end
		if rng:NextNumber() < 0.22 and patch(folder, params, edge + out * rng:NextNumber(-0.5, 2.5), dir, rng:NextNumber(10, 15), rng:NextNumber(7, 10), "jungle_dirt_patch") then
			dirt += 1
		end
		local key = if rng:NextNumber() < 0.5 then "jungle_moss_a" else "jungle_moss_b"
		if patch(folder, params, edge + out * rng:NextNumber(-1.2, 1.6), dir, rng:NextNumber(10, 15), rng:NextNumber(6.5, 9.5), key) then
			moss += 1
		end
		if s.kind == "rect" and not s.closed and rng:NextNumber() < 0.12 and patch(folder, params, edge - out * rng:NextNumber(2.5, 5), dir, rng:NextNumber(4, 6.5), rng:NextNumber(3, 5), key) then
			worn += 1
		end
	end)
	local loose = fades(id, folder)
	return `{id}: {gone} panels gone; {moss} moss, {dirt} dirt, {worn} worn patches, {loose} cobble ends, {#list} outlines`
end

local function copy(id: string, cf: CFrame, parent: Instance)
	local m = (ServerStorage.MapProps :: any)[id]:Clone() :: Model
	local variants = m:FindFirstChild("_Variants")
	if variants then
		variants:Destroy()
	end
	m:PivotTo(cf)
	m:SetAttribute("MapPropId", id)
	m:SetAttribute("Zone", "Jungle")
	m:SetAttribute("JungleBlend", true)
	CollectionService:AddTag(m, "MapProp")
	m.Parent = parent
end

function J.details(id: string): string
	local folder = sub(id).Decor[FOLDER]
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("JungleBlend") then
			m:Destroy()
		end
	end
	local list = shapes(id)
	local params = rays(id)
	local rng = Random.new(91900 + string.byte(id, -1))
	local tufts, ferns, roots = 0, 0, 0
	walk(list, rng, 13, 20, function(edge: Vector3, tangent: Vector3, out: Vector3, s: any)
		if inside(list, edge, 0.5, s) then
			return
		end
		local pos = edge + out * rng:NextNumber(0.4, 2.6)
		local y = height(params, pos)
		if not y or inside(list, pos, 0, nil) then
			return
		end
		local roll = rng:NextNumber()
		if roll < 0.66 then
			copy("jungle_ground_tuft", CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), folder)
			tufts += 1
		elseif roll < 0.84 then
			copy("jungle_ground_fern", CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), folder)
			ferns += 1
		else
			local at = Vector3.new(pos.X, y, pos.Z)
			copy("jungle_ground_root", CFrame.lookAt(at, at + turned(tangent, rng:NextNumber(-0.5, 0.5))), folder)
			roots += 1
		end
	end)
	return `{id}: {tufts} tufts, {ferns} ferns, {roots} roots`
end

-- curbs of Round 8 that ended up across a path, at a junction: they take the path's width for no reason
function J.curbs(id: string): string
	local list = shapes(id)
	local gone, total = 0, 0
	for _, m in ipairs(sub(id).Decor[FOLDER]:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("MapPropId") == "jungle_ground_curb" then
			total += 1
			if inside(list, m:GetPivot().Position, 1, nil) then
				gone += 1
				m:Destroy()
			end
		end
	end
	return `{id}: {gone} curbs across a path removed, {total - gone} left`
end

function J.counts(): string
	local lines = {}
	for _, id in ipairs({ "Jungle_1", "Jungle_2", "Jungle_3", "Jungle_4" }) do
		local panels, entrance, patches, loose = 0, 0, 0, 0
		for _, p in ipairs(sub(id):GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "Fringe" then
					panels += 1
					if p.Position.Z < -50 then
						entrance += 1
					end
				elseif p.Name == PATCH then
					patches += 1
				elseif p.Name == FADE then
					loose += 1
				end
			end
		end
		table.insert(lines, `{id}: {panels} panels ({entrance} at the entrance), {patches} patches, {loose} cobble ends`)
	end
	local boss = 0
	for _, p in ipairs(ServerStorage.BossArenas.Jungle:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "Fringe" then
			boss += 1
		end
	end
	table.insert(lines, `boss room: {boss} panels`)
	return table.concat(lines, "\n")
end

return J
