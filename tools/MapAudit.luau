--[[
	MapAudit (dev tool, Edit mode only): finds and fixes map defects (hollow facet shells, gaps, floating
	pieces, z-fighting, stray shadow casters) and builds invisible no-climb collision shells.
	Source of truth: tools/MapAudit.luau in the repo (= ServerStorage.DevTools.MapAudit).

	Usage (execute_luau, Edit; require a Clone to dodge the require cache; long calls belong in a
	task.spawn that stores its result in _G, then poll):
		local A = require(game.ServerStorage.DevTools.MapAudit:Clone())
		local report = A.audit(workspace.Zones.Desert)            -- a zone, a sub-zone or workspace.Hub
		print(report.summary, A.describe(report, 20))
		-- 1) holes: close every exposed open facet edge (outer shells first), audit again, repeat
		A.autoClose(workspace.Zones.Desert, { k = 0.22, tag = "close",
			firstFolders = { Mountains = true, Backdrop = true, MountainShell = true, Cliffs = true, CorridorRidge = true } })
		-- 2) z-fighting and duplicates, 3) semi-transparent / invisible shadow casters
		for _, sub in ipairs(A.subZones(workspace.Zones.Desert)) do
			A.fixZFight(A.zfight(sub), { skip = function(p) return p.Transparency > 0.3 end })
			A.fixShadows(A.transparency(sub))
		end
		-- 4) no-climb shell around a landmark (16-sided prism + disc roof in <model>.NoClimb); roots that
		--    reach past the prism get "fins" so nobody walks up a root (run 2: Jungle_1 GiantTree)
		A.shell(model, { center = Vector3.new(x, 0, z), radius = 15, sides = 16, thickness = 2, bottom = 10, top = 78 })
		A.shell(model, { center = c, radius = 19.5, top = 124, boxes = { A.footprintBox(root, 1, -3, 27) } })

	Checks (report fields, each a list of records { inst, pos, text, kind? }):
		openEdges     boundary edges of "Facet" surfaces (WedgeParts made by BuildKit.tri) used by one triangle
		              only. classify() marks e.exposure = "player" (the hollow under it is seen from a walkable
		              spot / camera height in the zone), "outside" (only from the ring of outside viewpoints) or
		              nil (on / in the floor, filled by a solid part, or hidden behind
		              other geometry)
		floating      decor items with nothing under, above (hanging) or beside (wall-mounted) them
		zfight        coplanar overlapping faces facing the same way with different colours (+ exact duplicates)
		transparency  semi-transparent / invisible shadow casters, Glass / ForceField parts, selection adornments
		unanchored    unanchored parts
		singleSided   big single-sided MeshParts a player can walk into (CanCollide off, reachable)
		belowFloor    parts below y -20 (lost pieces; sky zones have parts there by design)

	Fixes (new parts go to <SubZone>.Decor.MapFix / Hub.Decor.MapFix with attribute Tag; shells to
	<model>.NoClimb with attribute NoClimb):
		A.close(edges, opts)     sloped low-poly closure facets from each edge down to the floor / sea bed
		A.autoClose(target, o)   audit + close loop (skips edges inside the playable Area and over paths,
		                         tunnels, spawns, entrances and gates: listed in result.skipped)
		A.skirt(edges, opts)     plain vertical walls instead of sloped closures
		A.fixZFight(list, o)     pushes the smaller part 0.05 stud out (or grows it), deletes exact duplicates
		A.fixShadows(list, o)    CastShadow off on semi-transparent / invisible parts
		A.fill(sub, cf, size, props, name, tag)   one support / gap-filler part
		A.shell(model, opts)     invisible collision shell (Transparency 1, CanCollide, no query / touch / shadow)
		A.footprintBox(part, pad, bottom, top)   vertical box around a part's footprint, e.g. shell "fins"
		                         over sloped roots: A.shell(m, { radius = r, boxes = { A.footprintBox(root, 1, -3, 27) } })
		A.undo(sub, tag?)        deletes MapFix parts (all, or one Tag)
]]

local MapAudit = {}

local EDGE_TOL = 0.3 -- studs: two edges match when both ends are this close to the other's line
local PARALLEL = 0.03 -- sin of the max angle between matching edges
local MIN_OPEN = 0.75 -- open pieces shorter than this are ignored
local CELL = 6 -- spatial hash cell (studs)

local IGNORE_FOLDERS = { VFX = true, Webs = true, Water = true, Foam = true, Landmark = true, MapFix = true }

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function fmt(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end
MapAudit.fmt = fmt

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Sub-zone folder (Zones.<Zone>.<Zone>_<n>) or the Hub containing inst, nil otherwise.
function MapAudit.subZoneOf(inst: Instance): Instance?
	local node = inst
	while node and node.Parent do
		if node.Parent.Parent == workspace:FindFirstChild("Zones") then
			return node
		end
		if node == workspace:FindFirstChild("Hub") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- The MapFix folder of a sub-zone / the Hub (created on demand).
function MapAudit.fixFolder(sub: Instance): Folder
	local decor = sub:FindFirstChild("Decor") or sub
	local f = decor:FindFirstChild("MapFix")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MapFix"
		f.Parent = decor
	end
	return f :: Folder
end

-- Every sub-zone folder under target (target itself when it is a sub-zone or the Hub).
function MapAudit.subZones(target: Instance): { Instance }
	if target == workspace:FindFirstChild("Hub") or (target.Parent and target.Parent.Parent == workspace:FindFirstChild("Zones")) then
		return { target }
	end
	local list = {}
	if target == workspace:FindFirstChild("Zones") then
		for _, zone in ipairs(target:GetChildren()) do
			for _, sub in ipairs(zone:GetChildren()) do
				table.insert(list, sub)
			end
		end
	else
		for _, sub in ipairs(target:GetChildren()) do
			if sub:IsA("Folder") and sub:FindFirstChild("Decor") then
				table.insert(list, sub)
			end
		end
	end
	return list
end

-- Parts that rays should pass through (water, invisible walls, markers). CanQuery = false only hides
-- a part from raycasts when CanCollide is false too, so the invisible Bounds walls must be listed.
local function seeThroughList(roots: { Instance }): { Instance }
	local list = {}
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency >= 0.3 and (d.CanQuery or d.CanCollide) then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function chunkWait(counter: { n: number }, every: number)
	counter.n += 1
	if counter.n % every == 0 then
		task.wait()
	end
end

---------------------------------------------------------------------
-- Facet surfaces
---------------------------------------------------------------------
--[[
	A BuildKit.tri triangle is two right-triangle WedgeParts. On the wedge's top face (the X face whose
	world normal points up), P1 = the end of the hypotenuse on the triangle's long edge, P2 = the right
	angle (foot of the altitude), P3 = the apex. Outer edges: P1-P3 (a triangle edge) and P1-P2 (half of
	the long edge). P2-P3 is the altitude, shared with the twin wedge.
]]
local function faceOf(p: BasePart, sx: number)
	local cf, s = p.CFrame, p.Size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	return {
		P1 = cf:PointToWorldSpace(Vector3.new(sx * hx, -hy, -hz)),
		P2 = cf:PointToWorldSpace(Vector3.new(sx * hx, -hy, hz)),
		P3 = cf:PointToWorldSpace(Vector3.new(sx * hx, hy, hz)),
		n = cf.RightVector * sx,
	}
end

function MapAudit.isFacet(p: Instance): boolean
	return p:IsA("WedgePart") and (p.Name == "Facet" or p:GetAttribute("MapFixFacet") == true)
end

-- Facet records under roots. filter(part) -> boolean (optional).
function MapAudit.facets(roots: { Instance }, filter: ((BasePart) -> boolean)?)
	local recs = {}
	for _, root in ipairs(roots) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("WedgePart") and p.Name == "Facet" and (not filter or filter(p)) then
				local ry = p.CFrame.RightVector.Y
				local rec = { part = p }
				if math.abs(ry) < 1e-3 then
					-- Vertical triangle: the builder's side choice is lost in float noise, test both faces.
					rec.faces = { faceOf(p, 1), faceOf(p, -1) }
				else
					rec.faces = { faceOf(p, if ry >= 0 then 1 else -1) }
				end
				table.insert(recs, rec)
			end
		end
	end
	return recs
end

local function cellKey(x: number, y: number, z: number): number
	return ((math.floor(x / CELL) + 3000) * 6000 + (math.floor(y / CELL) + 3000)) * 6000 + (math.floor(z / CELL) + 3000)
end

--[[
	Open boundary edges of the facet surfaces under roots (an edge covered by one triangle only).
	Returns a list of { a, b, len, part, n (top normal), o (unit, away from the triangle), sub }.
]]
-- Default facet filter: terrain-like surfaces only (no landmark / VFX models; MapFix closures included).
function MapAudit.defaultFilter(p: Instance): boolean
	local node = p.Parent
	while node and node ~= workspace do
		if IGNORE_FOLDERS[node.Name] and node.Name ~= "MapFix" then
			return false
		end
		node = node.Parent
	end
	return true
end

function MapAudit.openEdges(roots: { Instance }, opts: { [string]: any }?)
	opts = opts or {}
	local recs = MapAudit.facets(roots, opts.filter or MapAudit.defaultFilter)
	local grid: { [number]: { any } } = {}
	local segs = {}
	local counter = { n = 0 }
	local function addSeg(a: Vector3, b: Vector3, rec, fi: number)
		local seg = { a = a, b = b, rec = rec, fi = fi }
		table.insert(segs, seg)
		local d = b - a
		local len = d.Magnitude
		local steps = math.max(1, math.ceil(len / (CELL * 0.5)))
		local seen = {}
		for i = 0, steps do
			local p = a + d * (i / steps)
			local k = cellKey(p.X, p.Y, p.Z)
			if not seen[k] then
				seen[k] = true
				local bucket = grid[k]
				if not bucket then
					bucket = {}
					grid[k] = bucket
				end
				table.insert(bucket, seg)
			end
		end
		return seg
	end
	for _, rec in ipairs(recs) do
		rec.segs = {}
		for fi, f in ipairs(rec.faces) do
			rec.segs[fi] = { addSeg(f.P1, f.P3, rec, fi), addSeg(f.P1, f.P2, rec, fi) }
		end
		chunkWait(counter, 2000)
	end

	-- Uncovered parts of segment s, as { {t0, t1} } in studs along s.
	local function uncovered(s)
		local a, b = s.a, s.b
		local d = b - a
		local len = d.Magnitude
		if len < 1e-3 then
			return {}, 0
		end
		local u = d / len
		local intervals = {}
		local tested = {}
		local steps = math.max(1, math.ceil(len / CELL))
		for i = 0, steps do
			local p = a + d * (i / steps)
			local cx, cy, cz = math.floor(p.X / CELL), math.floor(p.Y / CELL), math.floor(p.Z / CELL)
			for dx = -1, 1 do
				for dy = -1, 1 do
					for dz = -1, 1 do
						local bucket = grid[((cx + dx + 3000) * 6000 + (cy + dy + 3000)) * 6000 + (cz + dz + 3000)]
						if bucket then
							for _, t in ipairs(bucket) do
								if t ~= s and t.rec ~= s.rec and not tested[t] then
									tested[t] = true
									local td = t.b - t.a
									local tl = td.Magnitude
									if tl > 1e-3 and u:Cross(td / tl).Magnitude < PARALLEL
										and (t.a - a):Cross(u).Magnitude < EDGE_TOL
										and (t.b - a):Cross(u).Magnitude < EDGE_TOL then
										local s1, s2 = (t.a - a):Dot(u), (t.b - a):Dot(u)
										local lo, hi = math.max(0, math.min(s1, s2)), math.min(len, math.max(s1, s2))
										if hi - lo > 0.05 then
											table.insert(intervals, { lo, hi })
										end
									end
								end
							end
						end
					end
				end
			end
		end
		table.sort(intervals, function(x, y) return x[1] < y[1] end)
		local gaps, cursor, total = {}, 0, 0
		for _, iv in ipairs(intervals) do
			if iv[1] - cursor > MIN_OPEN then
				table.insert(gaps, { cursor, iv[1] })
				total += iv[1] - cursor
			end
			cursor = math.max(cursor, iv[2])
		end
		if len - cursor > MIN_OPEN then
			table.insert(gaps, { cursor, len })
			total += len - cursor
		end
		return gaps, total
	end

	local edges = {}
	for _, rec in ipairs(recs) do
		-- For vertical triangles keep the face whose edges are best covered by the neighbours.
		local bestFi, bestGaps, bestTotal = 1, nil, math.huge
		for fi, pair in ipairs(rec.segs) do
			local g1, t1 = uncovered(pair[1])
			local g2, t2 = uncovered(pair[2])
			if t1 + t2 < bestTotal then
				bestFi, bestTotal, bestGaps = fi, t1 + t2, { { pair[1], g1 }, { pair[2], g2 } }
			end
		end
		if bestGaps and bestTotal > 0 then
			local f = rec.faces[bestFi]
			local centroid = (f.P1 + f.P2 + f.P3) / 3
			for _, sg in ipairs(bestGaps) do
				local s, gaps = sg[1], sg[2]
				local u = (s.b - s.a).Unit
				for _, g in ipairs(gaps) do
					local a, b = s.a + u * g[1], s.a + u * g[2]
					local o = u:Cross(f.n)
					if o.Magnitude > 1e-3 then
						o = o.Unit
						if o:Dot(centroid - (a + b) / 2) > 0 then
							o = -o
						end
					else
						o = Vector3.zero
					end
					table.insert(edges, {
						a = a, b = b, len = (b - a).Magnitude, part = rec.part, n = f.n, o = o, c = centroid,
						sub = MapAudit.subZoneOf(rec.part),
					})
				end
			end
		end
		chunkWait(counter, 400)
	end
	return edges, #recs
end

---------------------------------------------------------------------
-- Exposure (is the space under an open edge visible?)
---------------------------------------------------------------------
local function groundParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

--[[
	Viewpoints for a list of sub-zones.
	player: eye (5 studs) and camera (18 and 35 studs) heights over walkable points: Entrance, Spawns,
	        Path parts and a 9 x 9 grid over Area kept only when a seed point (spawn / path) can see it.
	outside: a ring around the whole target (low, mid and high), the "outside edges" view.
]]
function MapAudit.viewpoints(subs: { Instance }, seeThrough: { Instance })
	local params = groundParams(seeThrough)
	local player, outside = {}, {}
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	local function ground(x: number, z: number, fromY: number): Vector3?
		local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -fromY - 60, 0), params)
		return hit and hit.Position
	end
	local function headroom(p: Vector3, up: number): number
		local hit = workspace:Raycast(p, Vector3.new(0, up, 0), params)
		return if hit then hit.Distance else up
	end
	for _, sub in ipairs(subs) do
		local area = sub:FindFirstChild("Area") :: BasePart?
		local seeds = {}
		local function addSeed(p: Vector3)
			local g = ground(p.X, p.Z, p.Y + 6)
			if g then
				table.insert(seeds, g + Vector3.new(0, 5, 0))
			end
		end
		local entrance = sub:FindFirstChild("Entrance") :: BasePart?
		if entrance then
			addSeed(entrance.Position)
		end
		local spawnFolder = sub:FindFirstChild("Spawns")
		if spawnFolder then
			for _, s in ipairs(spawnFolder:GetChildren()) do
				if s:IsA("BasePart") then
					addSeed(s.Position)
				end
			end
		end
		local decor = sub:FindFirstChild("Decor")
		local path = decor and decor:FindFirstChild("Path")
		if path then
			for _, p in ipairs(path:GetDescendants()) do
				if p:IsA("BasePart") then
					local long = if p.Size.X > p.Size.Z then p.CFrame.RightVector * p.Size.X else p.CFrame.LookVector * p.Size.Z
					local n = math.max(1, math.floor(long.Magnitude / 15))
					for i = 0, n do
						addSeed(p.Position + long * (i / n - 0.5))
					end
				end
			end
		end
		if sub.Name == "Hub" then
			local spawn = sub:FindFirstChild("SpawnLocation") :: BasePart?
			if spawn then
				addSeed(spawn.Position)
			end
			for _, portal in ipairs((sub:FindFirstChild("Portals") or sub):GetChildren()) do
				if portal:IsA("BasePart") then
					addSeed(portal.Position - portal.CFrame.LookVector * 8)
				end
			end
		end
		local pts = table.clone(seeds)
		local box: { Vector3 }? = if area then { area.Position, area.Size } else nil
		local bounds = sub:FindFirstChild("Bounds")
		if not box and bounds then
			-- No Area part (the Hub): use the extents of the invisible walls.
			local bmn, bmx = Vector3.one * 1e9, -Vector3.one * 1e9
			for _, b in ipairs(bounds:GetChildren()) do
				if b:IsA("BasePart") then
					bmn, bmx = bmn:Min(b.Position), bmx:Max(b.Position)
				end
			end
			if bmn.X < bmx.X then
				box = { (bmn + bmx) / 2 + Vector3.new(0, 30, 0), Vector3.new(bmx.X - bmn.X, 60, bmx.Z - bmn.Z) }
			end
		end
		if box then
			local c, s = box[1], box[2]
			for ix = 0, 8 do
				for iz = 0, 8 do
					local x = c.X + (ix / 8 - 0.5) * (s.X - 12)
					local z = c.Z + (iz / 8 - 0.5) * (s.Z - 12)
					local g = ground(x, z, math.min(c.Y + s.Y / 2, 30))
					if g then
						local eye = g + Vector3.new(0, 5, 0)
						for _, seed in ipairs(seeds) do
							local d = eye - seed
							if d.Magnitude < 1 or not workspace:Raycast(seed, d, params) then
								table.insert(pts, eye)
								break
							end
						end
					end
				end
			end
		end
		for _, p in ipairs(pts) do
			table.insert(player, p)
			local room = headroom(p, 40)
			if room > 16 then
				table.insert(player, p + Vector3.new(0, 13, 0))
			end
			if room > 34 then
				table.insert(player, p + Vector3.new(0, 30, 0))
			end
			mn, mx = mn:Min(p), mx:Max(p)
		end
		-- Extents of the visible map around this sub-zone (decor included) for the outside ring.
		for _, d in ipairs((decor or sub):GetDescendants()) do
			if d:IsA("BasePart") and d.Size.Magnitude > 4 and d.Position.Y > -30 then
				mn, mx = mn:Min(d.Position), mx:Max(d.Position)
			end
		end
	end
	if mn.X < mx.X then
		local pad = 60
		local x0, x1, z0, z1 = mn.X - pad, mx.X + pad, mn.Z - pad, mx.Z + pad
		for _, y in ipairs({ 3, 45, 140 }) do
			local stepX = math.max(60, (x1 - x0) / math.ceil((x1 - x0) / 120))
			local stepZ = math.max(60, (z1 - z0) / math.ceil((z1 - z0) / 120))
			for x = x0, x1 + 0.1, stepX do
				table.insert(outside, Vector3.new(x, y, z0))
				table.insert(outside, Vector3.new(x, y, z1))
			end
			for z = z0 + stepZ, z1 - stepZ + 0.1, stepZ do
				table.insert(outside, Vector3.new(x0, y, z))
				table.insert(outside, Vector3.new(x1, y, z))
			end
		end
	end
	return { player = player, outside = outside }
end

-- Points just under the surface next to the open edge (inside the "hollow").
local function probePoints(e): { Vector3 }
	local pts = {}
	local n = if e.len > 12 then 3 else (if e.len > 4 then 2 else 1)
	for i = 1, n do
		local q = e.a + (e.b - e.a) * (i / (n + 1))
		table.insert(pts, q - e.o * 0.8 - e.n * 2.6)
	end
	return pts
end

-- A ray from a viewpoint reaches the probe point, or stops on the underside / end of a facet right next
-- to it (the viewer looks at the hollow side of the shell; a hit on a top face means it does not).
local function visibleFrom(points: { Vector3 }, vps: { Vector3 }, params: RaycastParams, maxDist: number, e): boolean
	for _, h in ipairs(points) do
		local list = {}
		for _, v in ipairs(vps) do
			local d = (h - v).Magnitude
			if d < maxDist then
				table.insert(list, { v, d })
			end
		end
		table.sort(list, function(x, y) return x[2] < y[2] end)
		for i = 1, math.min(#list, 160) do
			local v = list[i][1]
			local dir = h - v
			local hit = workspace:Raycast(v, dir, params)
			local reached = not hit or hit.Distance > dir.Magnitude - 0.6
				or ((hit.Position - h).Magnitude < 3 and hit.Instance.Parent == e.part.Parent and hit.Normal:Dot(e.n) < 0.5)
			if reached then
				-- Depth test: a shallow pocket (another surface right behind the probe, e.g. a hill under a
				-- mountain's foot) looks natural; a deep look into the hollow / the void is the defect.
				local behind = workspace:Raycast(h, dir.Unit * 10, params)
				if not behind or behind.Instance.Parent == e.part.Parent then
					return true
				end
			end
		end
	end
	return false
end

-- p is inside a solid opaque block / wedge that is not a facet (a terrace body, a cabin wall, a
-- ramp): the space under the edge is filled, there is no hollow to see.
local function insideSolid(p: Vector3): boolean
	local op = OverlapParams.new()
	op.RespectCanCollide = false
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(p), Vector3.one * 0.2, op)) do
		local block = part:IsA("Part") and part.Shape == Enum.PartType.Block
		if part.Transparency < 0.3 and not MapAudit.isFacet(part) and (block or part:IsA("WedgePart")) then
			local l = part.CFrame:PointToObjectSpace(p)
			local h = part.Size / 2
			if math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
				and (block or (l.Y + h.Y) / (2 * h.Y) <= (l.Z + h.Z) / (2 * h.Z)) then
				return true
			end
		end
	end
	return false
end
MapAudit.insideSolid = insideSolid

-- Height of the floor (ground, sea bed, facets) under p, nil over the void.
function MapAudit.floorBelow(p: Vector3, params: RaycastParams?): number?
	local hit = workspace:Raycast(p, Vector3.new(0, -500, 0), params or groundParams({}))
	return hit and hit.Position.Y
end

--[[
	Marks each edge with e.exposure = "player" | "outside" | nil and e.floor (floor height under the
	edge, nil over the void). Edges at or under the floor are skipped (buried).
]]
function MapAudit.classify(edges, subs: { Instance }, opts: { [string]: any }?)
	opts = opts or {}
	local roots = { workspace:FindFirstChild("Zones") or workspace, workspace:FindFirstChild("Hub") or workspace }
	local see = seeThroughList(roots)
	local params = groundParams(see)
	local vps = opts.viewpoints or MapAudit.viewpoints(subs, see)
	local counter = { n = 0 }
	for _, e in ipairs(edges) do
		local mid = (e.a + e.b) / 2
		local fl = MapAudit.floorBelow(mid - e.n * 2.2 - e.o * 0.4, params)
		e.floor = fl
		local low = math.min(e.a.Y, e.b.Y)
		if fl and low <= fl + 0.4 and math.max(e.a.Y, e.b.Y) <= fl + 1.2 then
			e.exposure = nil -- resting on / buried in the floor
		elseif not fl and math.max(e.a.Y, e.b.Y) <= (opts.voidFloor or -9) + 0.5 then
			e.exposure = nil -- bottom of a closure over the void (the map's underside)
		else
			local pts = probePoints(e)
			local filled = true
			for _, q in ipairs(pts) do
				if not insideSolid(q) then
					filled = false
					break
				end
			end
			if filled then
				e.exposure = nil -- the hollow is filled by a solid part (terrace body, wall)
				e.filled = true
			elseif visibleFrom(pts, vps.player, params, opts.maxPlayerDist or 260, e) then
				e.exposure = "player"
			elseif visibleFrom(pts, vps.outside, params, opts.maxOutsideDist or 700, e) then
				e.exposure = "outside"
			end
		end
		chunkWait(counter, 25)
	end
	return vps
end

---------------------------------------------------------------------
-- Other checks
---------------------------------------------------------------------
local function decorItems(sub: Instance): { Instance }
	local items = {}
	local decor = sub:FindFirstChild("Decor")
	if not decor then
		return items
	end
	for _, folder in ipairs(decor:GetChildren()) do
		if not IGNORE_FOLDERS[folder.Name] and folder.Name ~= "Ground" then
			for _, item in ipairs(folder:GetChildren()) do
				if item:IsA("Model") or (item:IsA("BasePart") and item.Name ~= "Facet") then
					table.insert(items, item)
				elseif item:IsA("Folder") then
					for _, sub2 in ipairs(item:GetChildren()) do
						if sub2:IsA("Model") or (sub2:IsA("BasePart") and sub2.Name ~= "Facet") then
							table.insert(items, sub2)
						end
					end
				end
			end
		end
	end
	return items
end

-- Decor items with a gap under them (nothing within gapTol studs below their lowest point). Floors
-- (Ground, Sea, Path, Plaza folders, big flat slabs) are not items.
local FLOOR_FOLDERS = { Ground = true, Sea = true, Path = true, Plaza = true, Shore = true, Dunes = true }
function MapAudit.floating(sub: Instance, gapTol: number?)
	local out = {}
	local tol = gapTol or 1.5
	local see = seeThroughList({ sub })
	for _, item in ipairs(decorItems(sub)) do
		local folder = item.Parent
		while folder and folder.Parent and folder.Parent.Name ~= "Decor" do
			folder = folder.Parent
		end
		local cf, size
		if item:IsA("Model") then
			cf, size = item:GetBoundingBox()
		else
			cf, size = (item :: BasePart).CFrame, (item :: BasePart).Size
		end
		local floorLike = item:IsA("BasePart") and math.min(size.X, size.Y, size.Z) < 3 and size.X * size.Z > 300
		local visible = false
		for _, d in ipairs(if item:IsA("BasePart") then { item } else item:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				visible = true
				break
			end
		end
		if visible and not floorLike and not (folder and FLOOR_FOLDERS[folder.Name]) and size.Magnitude > 1 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local exclude = table.clone(see)
			table.insert(exclude, item)
			params.FilterDescendantsInstances = exclude
			params.IgnoreWater = true
			local top, bottom = cf.Position.Y + size.Y / 2, cf.Position.Y - size.Y / 2
			local supported = false
			local probes = { Vector3.zero, Vector3.new(size.X * 0.3, 0, 0), Vector3.new(-size.X * 0.3, 0, 0), Vector3.new(0, 0, size.Z * 0.3), Vector3.new(0, 0, -size.Z * 0.3) }
			for _, off in ipairs(probes) do
				local p = cf.Position + flat(cf:VectorToWorldSpace(off))
				local hit = workspace:Raycast(Vector3.new(p.X, top + 0.5, p.Z), Vector3.new(0, -(top - bottom) - tol - 0.5, 0), params)
				if hit then
					supported = true
					break
				end
			end
			-- Hanging (stalactite, lamp) or wall-mounted (torch, sign): something touches it above or beside.
			if not supported then
				local c = cf.Position
				local reach = math.max(size.X, size.Z) / 2 + tol
				for _, dir in ipairs({ Vector3.new(0, size.Y / 2 + tol, 0), Vector3.new(reach, 0, 0), Vector3.new(-reach, 0, 0), Vector3.new(0, 0, reach), Vector3.new(0, 0, -reach) }) do
					if workspace:Raycast(c, dir, params) then
						supported = true
						break
					end
				end
			end
			if not supported then
				local hit = workspace:Raycast(Vector3.new(cf.Position.X, bottom, cf.Position.Z), Vector3.new(0, -600, 0), params)
				table.insert(out, {
					inst = item, pos = cf.Position, gap = if hit then bottom - hit.Position.Y else math.huge,
					text = `{item:GetFullName()} at {fmt(cf.Position)} bottom {string.format("%.1f", bottom)} gap {if hit then string.format("%.1f", bottom - hit.Position.Y) else "void"}`,
				})
			end
		end
	end
	return out
end

-- Box faces of a Part as { n, d, c, u, v, hu, hv } (cylinders: only the two flat caps).
local function boxFaces(p: BasePart)
	local cf, s = p.CFrame, p.Size
	local faces = {}
	local axes = {
		{ cf.RightVector, s.X, cf.UpVector, s.Y, cf.LookVector, s.Z },
		{ cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z },
		{ cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y },
	}
	local isCyl = p:IsA("Part") and p.Shape == Enum.PartType.Cylinder
	for i, ax in ipairs(axes) do
		if not isCyl or i == 1 then
			for _, sign in ipairs({ 1, -1 }) do
				local n = ax[1] * sign
				local c = cf.Position + n * ax[2] / 2
				table.insert(faces, { n = n, d = n:Dot(c), c = c, u = ax[3], v = ax[5], hu = ax[4] / 2, hv = ax[6] / 2 })
			end
		end
	end
	return faces
end

local function rectOverlap(f1, f2): boolean
	-- 2D SAT between two rectangles lying in the same plane.
	local axes = { f1.u, f1.v, f2.u, f2.v }
	local d = f2.c - f1.c
	for _, ax in ipairs(axes) do
		local r1 = f1.hu * math.abs(f1.u:Dot(ax)) + f1.hv * math.abs(f1.v:Dot(ax))
		local r2 = f2.hu * math.abs(f2.u:Dot(ax)) + f2.hv * math.abs(f2.v:Dot(ax))
		if math.abs(d:Dot(ax)) >= r1 + r2 - 0.05 then
			return false
		end
	end
	return true
end

-- Coplanar overlapping faces facing the same way with a different colour / material (Block / Cylinder
-- parts; z-fighting flicker) and exact duplicate parts.
function MapAudit.zfight(sub: Instance)
	local out = {}
	local buckets = {}
	local dup = {}
	local counter = { n = 0 }
	for _, p in ipairs(sub:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			local key = string.format("%s|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.3f|%.3f|%.3f", p.ClassName, p.Position.X, p.Position.Y, p.Position.Z,
				p.Size.X, p.Size.Y, p.Size.Z, p.CFrame.LookVector.X, p.CFrame.LookVector.Y, p.CFrame.UpVector.X)
			if dup[key] and not (p:IsA("MeshPart") and (dup[key] :: any).MeshId ~= (p :: any).MeshId) then
				table.insert(out, { inst = p, other = dup[key], kind = "duplicate", pos = p.Position, text = `duplicate of {dup[key]:GetFullName()}: {p:GetFullName()}` })
			else
				dup[key] = p
			end
			if p:IsA("Part") and (p.Shape == Enum.PartType.Block or p.Shape == Enum.PartType.Cylinder) then
				for _, f in ipairs(boxFaces(p)) do
					local n = f.n
					if n.Y < -0.9 then
						continue -- undersides are not seen
					end
					local k = string.format("%.2f|%.2f|%.2f|%.1f", n.X, n.Y, n.Z, f.d)
					local list = buckets[k]
					if not list then
						list = {}
						buckets[k] = list
					end
					for _, other in ipairs(list) do
						-- Same colour and material on both faces: nothing flickers, skip.
						local differ = other.part.Color ~= p.Color or other.part.Material ~= p.Material
						if differ and other.part ~= p and math.abs(other.d - f.d) < 0.02 and rectOverlap(other, f) then
							table.insert(out, {
								inst = p, other = other.part, n = n, kind = "coplanar", pos = f.c,
								text = `coplanar faces: {p:GetFullName()} / {other.part:GetFullName()} at {fmt(f.c)}`,
							})
						end
					end
					f.part = p
					table.insert(list, f)
				end
			end
		end
		chunkWait(counter, 3000)
	end
	return out
end

-- Fixes z-fighting entries of MapAudit.zfight: an exact duplicate part is deleted; for coplanar faces
-- the smaller part is pushed opts.step (0.05) stud out along the shared face's normal, so its face wins
-- the depth test (nothing visibly moves; a part flush on both sides grows by 2 x step instead). opts.skip(part) -> true: that part never moves (the other one of
-- the pair is pushed back instead) and is never deleted.
-- Returns moved, deleted.
function MapAudit.fixZFight(list, opts: { [string]: any }?): (number, number)
	opts = opts or {}
	local step = opts.step or 0.05
	local moved, deleted = 0, 0
	local done = {}
	local function skipped(part: Instance): boolean
		return opts.skip ~= nil and opts.skip(part) == true
	end
	for _, r in ipairs(list) do
		if r.kind == "duplicate" then
			if r.inst.Parent and r.other and r.other.Parent and not skipped(r.inst) then
				r.inst:Destroy()
				deleted += 1
			end
		elseif r.kind == "coplanar" and r.inst.Parent and r.other and r.other.Parent then
			local a, b = r.inst :: BasePart, r.other :: BasePart
			local small, big = a, b
			local va, vb = a.Size.X * a.Size.Y * a.Size.Z, b.Size.X * b.Size.Y * b.Size.Z
			if va > vb + 1e-6 or (math.abs(va - vb) <= 1e-6 and a.Position:Dot(r.n) < b.Position:Dot(r.n)) then
				small, big = b, a -- equal sizes: always the same one of the pair moves (stable on reruns)
			end
			-- Move the smaller part out; if it must not move, move the bigger one back instead.
			local mover, dir = small, r.n
			if skipped(small) then
				mover, dir = big, -r.n
			end
			if not skipped(mover) then
				local key = string.format("%.2f|%.2f|%.2f", dir.X, dir.Y, dir.Z)
				done[mover] = done[mover] or {}
				done[mover][key] = dir
			end
		end
	end
	-- Apply: one push per direction; a part flush on both sides (+n and -n) grows instead of moving.
	for mover, dirs in pairs(done) do
		local list2 = {}
		for _, d in pairs(dirs) do
			table.insert(list2, d)
		end
		local used = {}
		for i, d in ipairs(list2) do
			if not used[i] then
				local opposite
				for j = i + 1, #list2 do
					if not used[j] and list2[j]:Dot(d) < -0.99 then
						opposite = j
						break
					end
				end
				if opposite then
					used[opposite] = true
					local cf = mover.CFrame
					local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
					local best, bestDot = 1, 0
					for k, ax in ipairs(axes) do
						if math.abs(ax:Dot(d)) > bestDot then
							best, bestDot = k, math.abs(ax:Dot(d))
						end
					end
					local grow = Vector3.new(if best == 1 then 1 else 0, if best == 2 then 1 else 0, if best == 3 then 1 else 0) * step * 2
					mover.Size += grow
					mover.CFrame = cf
				else
					mover.CFrame += d * step
				end
				moved += 1
			end
		end
	end
	return moved, deleted
end

-- Turns CastShadow off on the semi-transparent / invisible shadow casters of MapAudit.transparency
-- (opts.keep(part) -> true leaves one alone). Returns the number changed.
function MapAudit.fixShadows(list, opts: { [string]: any }?): number
	opts = opts or {}
	local n = 0
	for _, r in ipairs(list) do
		if (r.kind == "semiShadow" or r.kind == "invisibleShadow") and r.inst.Parent and not (opts.keep and opts.keep(r.inst)) then
			r.inst.CastShadow = false
			n += 1
		end
	end
	return n
end

-- Semi-transparent / invisible shadow casters, Glass / ForceField parts, selection adornments.
function MapAudit.transparency(sub: Instance)
	local out = {}
	for _, d in ipairs(sub:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Transparency > 0 and d.Transparency < 1 and d.CastShadow then
				table.insert(out, { inst = d, pos = d.Position, kind = "semiShadow", text = `semi-transparent shadow caster T={d.Transparency}: {d:GetFullName()}` })
			elseif d.Transparency >= 1 and d.CastShadow then
				table.insert(out, { inst = d, pos = d.Position, kind = "invisibleShadow", text = `invisible part with CastShadow: {d:GetFullName()}` })
			end
			if d.Material == Enum.Material.Glass or d.Material == Enum.Material.ForceField then
				table.insert(out, { inst = d, pos = d.Position, kind = "glass", text = `{d.Material.Name} part T={d.Transparency}: {d:GetFullName()}` })
			end
		elseif d:IsA("SelectionBox") or d:IsA("SelectionSphere") or d:IsA("Highlight") or d:IsA("HandleAdornment") or d:IsA("SurfaceSelection") then
			table.insert(out, { inst = d, pos = Vector3.zero, kind = "adornment", text = `{d.ClassName}: {d:GetFullName()}` })
		end
	end
	return out
end

function MapAudit.unanchored(sub: Instance)
	local out = {}
	for _, d in ipairs(sub:GetDescendants()) do
		if d:IsA("BasePart") and not d.Anchored then
			local root = d.AssemblyRootPart
			if not (root and root.Anchored) then
				table.insert(out, { inst = d, pos = d.Position, text = `unanchored: {d:GetFullName()}` })
			end
		end
	end
	return out
end

-- Big single-sided MeshParts a player can walk into (CanCollide off, low enough to reach): from inside,
-- their back faces are missing (see-through / black).
function MapAudit.singleSided(sub: Instance, minSize: number?)
	local out = {}
	for _, d in ipairs(sub:GetDescendants()) do
		if d:IsA("MeshPart") and not d.DoubleSided and not d.CanCollide and d.Transparency < 1
			and math.max(d.Size.X, d.Size.Y, d.Size.Z) >= (minSize or 15) and d.Position.Y - d.Size.Y / 2 < 12 then
			table.insert(out, { inst = d, pos = d.Position, text = `single-sided mesh {fmt(d.Size)}: {d:GetFullName()}` })
		end
	end
	return out
end

function MapAudit.belowFloor(sub: Instance, minY: number?)
	local out = {}
	for _, d in ipairs(sub:GetDescendants()) do
		if d:IsA("BasePart") and d.Position.Y < (minY or -20) then
			table.insert(out, { inst = d, pos = d.Position, text = `below the floor y={string.format("%.1f", d.Position.Y)}: {d:GetFullName()}` })
		end
	end
	return out
end

---------------------------------------------------------------------
-- Full audit
---------------------------------------------------------------------
--[[
	opts: exposure (default true), edges (default true), skipChecks = { name = true }
	Returns { openEdges, floating, zfight, transparency, unanchored, singleSided, belowFloor, summary, perSub }
]]
function MapAudit.audit(target: Instance, opts: { [string]: any }?)
	opts = opts or {}
	local subs = MapAudit.subZones(target)
	local report = { openEdges = {}, floating = {}, zfight = {}, transparency = {}, unanchored = {}, singleSided = {}, belowFloor = {}, perSub = {} }
	local skip = opts.skipChecks or {}
	if opts.edges ~= false then
		local edges, nFacets = MapAudit.openEdges(subs, { filter = opts.filter })
		report.nFacets = nFacets
		if opts.exposure ~= false then
			report.viewpoints = MapAudit.classify(edges, subs, opts)
		end
		report.openEdges = edges
	end
	for _, sub in ipairs(subs) do
		local s = {}
		if not skip.floating then s.floating = MapAudit.floating(sub) end
		if not skip.zfight then s.zfight = MapAudit.zfight(sub) end
		if not skip.transparency then s.transparency = MapAudit.transparency(sub) end
		if not skip.unanchored then s.unanchored = MapAudit.unanchored(sub) end
		if not skip.singleSided then s.singleSided = MapAudit.singleSided(sub) end
		if not skip.belowFloor then s.belowFloor = MapAudit.belowFloor(sub) end
		for k, list in pairs(s) do
			for _, r in ipairs(list) do
				table.insert(report[k], r)
			end
		end
		report.perSub[sub.Name] = s
		task.wait()
	end
	-- Summary
	local lines = {}
	local per = {}
	for _, e in ipairs(report.openEdges) do
		local name = if e.sub then e.sub.Name else "?"
		per[name] = per[name] or { open = 0, player = 0, outside = 0, len = 0 }
		per[name].open += 1
		if e.exposure then
			per[name][e.exposure] += 1
			per[name].len += e.len
		end
	end
	table.insert(lines, `facets {report.nFacets or 0}, open edges {#report.openEdges}`)
	for name, c in pairs(per) do
		table.insert(lines, `  {name}: open {c.open}, exposed to players {c.player}, outside only {c.outside}, exposed length {math.floor(c.len)}`)
	end
	for _, k in ipairs({ "floating", "zfight", "transparency", "unanchored", "singleSided", "belowFloor" }) do
		table.insert(lines, `{k}: {#report[k]}`)
	end
	report.summary = table.concat(lines, "\n")
	return report
end

-- Text list of report entries (for printing), at most limit lines per check.
function MapAudit.describe(report, limit: number?)
	local lines = {}
	for _, k in ipairs({ "floating", "zfight", "transparency", "unanchored", "singleSided", "belowFloor" }) do
		for i, r in ipairs(report[k]) do
			if i > (limit or 30) then
				table.insert(lines, `  ... {#report[k] - (limit or 30)} more {k}`)
				break
			end
			table.insert(lines, `[{k}] {r.text}`)
		end
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- Fixes
---------------------------------------------------------------------
local function newPart(className: string, props: { [string]: any }): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end
MapAudit.newPart = newPart

-- One fix part in <sub>.Decor.MapFix (support rock, cap, gap filler...). props may set any property.
function MapAudit.fill(sub: Instance, cf: CFrame, size: Vector3, props: { [string]: any }, name: string?, tag: string?): BasePart
	local p = newPart(props.ClassName or "Part", {})
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Name = name or "Fill"
	p.Size = size
	p.CFrame = cf
	if tag then
		p:SetAttribute("Tag", tag)
	end
	p.Parent = MapAudit.fixFolder(sub)
	return p
end

--[[
	Vertical skirt under one edge: a wall from the edge down to the floor (a block for the part under the
	lower end + a wedge for the slanted top). The wall is pushed 0.3 stud under the surface (no z-fight,
	the facet's lip hides the seam) and buried 1 stud in the floor.
	opts: thickness (1), inset (0.3), floorY (fallback when nothing is under the edge), tag
]]
function MapAudit.skirtEdge(e, parent: Instance, opts: { [string]: any }?): { BasePart }
	opts = opts or {}
	local made = {}
	local t = opts.thickness or 1
	local inset = opts.inset or 0.3
	local dirH = flat(e.b - e.a)
	local lh = dirH.Magnitude
	if lh < 0.3 then
		return made
	end
	dirH = dirH / lh
	local nw = Vector3.new(-dirH.Z, 0, dirH.X) -- horizontal normal of the wall
	local oh = flat(e.o)
	if oh.Magnitude > 1e-3 and nw:Dot(oh) < 0 then
		nw = -nw
	elseif oh.Magnitude <= 1e-3 and nw:Dot(flat(e.n)) > 0 then
		nw = -nw
	end
	-- Top of the wall: just under the facet plane, inset under the surface.
	local function topAt(q: Vector3): Vector3
		local p = q - nw * inset
		local y = q.Y
		if math.abs(e.n.Y) > 0.05 then
			local planeY = q.Y - (e.n.X * (p.X - q.X) + e.n.Z * (p.Z - q.Z)) / e.n.Y
			y = math.min(y, planeY)
		end
		return Vector3.new(p.X, y - 0.12, p.Z)
	end
	local A, B = topAt(e.a), topAt(e.b)
	local floorY = (e.floorY or e.floor or opts.floorY or -8) - 1
	local low = math.min(A.Y, B.Y)
	if low - floorY < 0.2 then
		floorY = low - 0.2
	end
	local color = opts.color or e.part.Color
	local material = opts.material or e.part.Material
	local mid = (A + B) / 2
	local center = Vector3.new(mid.X, 0, mid.Z) - nw * (t / 2)
	local common = {
		Color = color, Material = material, CastShadow = e.part.CastShadow,
		CanCollide = opts.canCollide ~= false, CanTouch = false, CanQuery = true, Parent = parent,
	}
	local h = low - floorY
	local rect = newPart("Part", common)
	rect.Name = "Skirt"
	rect.Size = Vector3.new(lh, h, t)
	rect.CFrame = CFrame.fromMatrix(center + Vector3.new(0, floorY + h / 2, 0), dirH, Vector3.yAxis)
	table.insert(made, rect)
	local dy = math.abs(A.Y - B.Y)
	if dy > 0.05 then
		local d = if B.Y > A.Y then dirH else -dirH
		local w = newPart("WedgePart", common)
		w.Name = "Skirt"
		w.Size = Vector3.new(t, dy, lh)
		w.CFrame = CFrame.fromMatrix(center + Vector3.new(0, low + dy / 2, 0), Vector3.new(d.Z, 0, -d.X), Vector3.yAxis)
		table.insert(made, w)
	end
	for _, p in ipairs(made) do
		if opts.tag then
			p:SetAttribute("Tag", opts.tag)
		end
	end
	return made
end

--[[
	Skirts every edge of the list (opts.only = "player" keeps the player-visible ones, "any" every exposed
	one). Edges are grouped per sub-zone into <sub>.Decor.MapFix.<opts.folder or "Skirts">.
	Returns the number of parts made.
]]
function MapAudit.skirt(edges, opts: { [string]: any }?): number
	opts = opts or {}
	local count = 0
	local counter = { n = 0 }
	local folders = {}
	for _, e in ipairs(edges) do
		local keep = if opts.only == "player" then e.exposure == "player" elseif opts.only == "all" then true else e.exposure ~= nil
		if keep and e.sub and (not opts.filter or opts.filter(e)) then
			local f = folders[e.sub]
			if not f then
				local fix = MapAudit.fixFolder(e.sub)
				f = fix:FindFirstChild(opts.folder or "Skirts")
				if not f then
					f = Instance.new("Folder")
					f.Name = opts.folder or "Skirts"
					f.Parent = fix
				end
				folders[e.sub] = f
			end
			count += #MapAudit.skirtEdge(e, f, opts)
			chunkWait(counter, 150)
		end
	end
	return count
end

--[[
	Invisible collision shell around a model: a vertical prism over a polygon (radius / sides / center)
	or over a list of boxes, plus a roof slab. Parts: Transparency 1, CanCollide, no query / touch /
	shadow, in <model>.NoClimb (or opts.parent).
	opts = {
		center = Vector3 (prism axis, default bbox center), radius = number, sides = number (default 12),
		bottom = number (Y), top = number (Y), thickness = number (wall, default 2),
		roof = boolean (default true), boxes = { { cframe, size } }? (extra / replacement parts),
		name = string?, parent = Instance?
	}
]]
function MapAudit.shell(model: Instance, opts: { [string]: any }): { BasePart }
	local made = {}
	local parent = opts.parent
	if not parent then
		parent = model:FindFirstChild("NoClimb")
		if not parent then
			parent = Instance.new("Folder")
			parent.Name = "NoClimb"
			parent.Parent = model
		end
	end
	local function wall(cf: CFrame, size: Vector3, name: string)
		local p = newPart("Part", {
			Name = name, Size = size, CFrame = cf, Transparency = 1, CanCollide = true, CanQuery = false,
			CanTouch = false, CastShadow = false, Parent = parent,
		})
		p:SetAttribute("NoClimb", true)
		table.insert(made, p)
		return p
	end
	if opts.radius then
		local sides = opts.sides or 12
		local t = opts.thickness or 2
		local c = opts.center
		local h = opts.top - opts.bottom
		-- Each wall's inner face is tangent at radius: walls overlap at the corners (no gap).
		local side = 2 * (opts.radius + t) * math.tan(math.pi / sides) + 0.2
		for i = 0, sides - 1 do
			local ang = (i + 0.5) * 2 * math.pi / sides + (opts.rotation or 0)
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local pos = Vector3.new(c.X, opts.bottom + h / 2, c.Z) + dir * (opts.radius + t / 2)
			wall(CFrame.lookAt(pos, pos + dir), Vector3.new(side, h, t), `{opts.name or "Shell"}Wall`)
		end
		if opts.roof ~= false then
			-- A flat disc (cylinder) over the prism, no corners sticking out.
			local r = (opts.radius + t) / math.cos(math.pi / sides)
			local roof = wall(CFrame.new(c.X, opts.top - t / 2, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(t, 2 * r, 2 * r), `{opts.name or "Shell"}Roof`)
			roof.Shape = Enum.PartType.Cylinder
		end
	end
	for i, b in ipairs(opts.boxes or {}) do
		wall(b[1], b[2], b[3] or `{opts.name or "Shell"}Box{i}`)
	end
	return made
end

--[=[
	Vertical box around a part's horizontal footprint (a root, a rock, a buttress), aligned with the
	part's longest horizontal axis, from Y = bottom to Y = top, padded by pad studs on each side. Used
	as a shell "fin": A.shell(model, { radius = ..., boxes = { A.footprintBox(root, 1, -3, 26) } })
	follows sloped roots closely, so nobody walks up a root onto the trunk.
	Returns { CFrame, Size }.
]=]
function MapAudit.footprintBox(part: BasePart, pad: number, bottom: number, top: number): { any }
	local cf, s = part.CFrame, part.Size / 2
	local corners = {}
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				table.insert(corners, cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z)))
			end
		end
	end
	-- Longest horizontal axis of the part.
	local axes = { cf.RightVector * part.Size.X, cf.UpVector * part.Size.Y, cf.LookVector * part.Size.Z }
	local best = flat(axes[1])
	for _, a in ipairs(axes) do
		if flat(a).Magnitude > best.Magnitude then
			best = flat(a)
		end
	end
	local u = if best.Magnitude > 1e-3 then best.Unit else Vector3.xAxis
	local v = Vector3.new(-u.Z, 0, u.X)
	local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
	for _, q in ipairs(corners) do
		local du, dv = q:Dot(u), q:Dot(v)
		u0, u1 = math.min(u0, du), math.max(u1, du)
		v0, v1 = math.min(v0, dv), math.max(v1, dv)
	end
	local center = u * (u0 + u1) / 2 + v * (v0 + v1) / 2 + Vector3.new(0, (bottom + top) / 2, 0)
	return { CFrame.fromMatrix(center, u, Vector3.yAxis), Vector3.new(u1 - u0 + 2 * pad, top - bottom, v1 - v0 + 2 * pad) }
end

-- Boxes (CFrame, Size) a fix must not cover: paths, spawns, entrance, hub return, gates, arches.
function MapAudit.keepClear(sub: Instance): { { any } }
	local boxes = {}
	local function addPart(p: BasePart, pad: number)
		table.insert(boxes, { p.CFrame, p.Size + Vector3.one * pad * 2 })
	end
	local decor = sub:FindFirstChild("Decor")
	for _, folderName in ipairs({ "Path", "Paths", "Tunnel", "Plaza", "Walkways" }) do
		local folder = decor and decor:FindFirstChild(folderName)
		if folder then
			for _, p in ipairs(folder:GetDescendants()) do
				if p:IsA("BasePart") then
					addPart(p, 3)
				end
			end
		end
	end
	-- Path strips that live in other folders (Swamp: Ground.Path, Jungle: Corridor.Path).
	for _, p in ipairs(if decor then decor:GetDescendants() else {}) do
		if p:IsA("BasePart") and (p.Name == "Path" or p.Name == "PathShore") and p.Size.Y < 3 then
			local f = p.Parent
			if not (f and (f.Name == "Path" or f.Name == "Paths")) then
				addPart(p, 3)
			end
		end
	end
	local spawns = sub:FindFirstChild("Spawns")
	if spawns then
		for _, p in ipairs(spawns:GetChildren()) do
			if p:IsA("BasePart") then
				table.insert(boxes, { p.CFrame, Vector3.new(12, 1, 12) })
			end
		end
	end
	for _, name in ipairs({ "Entrance", "HubReturn" }) do
		local p = sub:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(boxes, { p.CFrame, Vector3.new(20, 1, 20) })
		end
	end
	for _, name in ipairs({ "Gate", "BossGate", "EntryArch" }) do
		local m = sub:FindFirstChild(name)
		if m and m:IsA("Model") then
			local cf, size = m:GetBoundingBox()
			table.insert(boxes, { cf, size + Vector3.new(6, 0, 6) })
		end
	end
	return boxes
end

-- Is p inside the horizontal footprint of one of the boxes (tested at each box's centre height, so a
-- rotated part such as a flat cylinder works too)?
local function inBoxes2D(p: Vector3, boxes: { { any } }): boolean
	for _, b in ipairs(boxes) do
		local cf = b[1] :: CFrame
		local l = cf:PointToObjectSpace(Vector3.new(p.X, cf.Position.Y, p.Z))
		if math.abs(l.X) <= b[2].X / 2 and math.abs(l.Y) <= b[2].Y / 2 + 0.01 and math.abs(l.Z) <= b[2].Z / 2 then
			return true
		end
	end
	return false
end
MapAudit.inBoxes2D = inBoxes2D

-- Floor height under p: first solid, opaque, big part below (props and meshes are skipped).
local function floorUnder(p: Vector3, exclude: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignored = table.clone(exclude)
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignored
		local hit = workspace:Raycast(p, Vector3.new(0, -400, 0), params)
		if not hit then
			return nil
		end
		local inst = hit.Instance
		local big = math.max(inst.Size.X, inst.Size.Y, inst.Size.Z) >= 6
		if inst.Transparency < 0.3 and not inst:IsA("MeshPart") and big then
			return hit.Position.Y
		end
		table.insert(ignored, inst)
	end
	return nil
end

--[[
	Closes exposed open edges with sloped low-poly "closure" facets: from each edge down to the floor
	(ground, sea bed, or opts.voidFloor over the void), leaning outward by opts.k (run / rise, default
	0.3 = a 73 degree cliff), so a chain of open edges becomes a cliff face in the same style. Vertices
	shared by consecutive edges get one outward direction (no cracks). Colour of each triangle: the
	nearest facet of the same surface (snow stays at the top, rock below).
	Edges inside the playable box (Area) are skipped unless opts.inK is given (then the closure leans the
	other way, e.g. -0.6 = down and under the surface, hidden behind it): a new wall where players walk
	tends to look worse than the small seam it hides. Edges over keep-clear areas (paths, tunnel, spawns,
	entrance, gates) are skipped too. Skipped edges are listed in MapAudit.lastSkipped for a manual fix;
	a base that would land on a keep-clear area gets a vertical wall instead.
	opts: only ("player" | "any" (default) | "all"), filter(e), k, inK, voidFloor (-9), thickness (1),
	      split (drop above which a face gets a middle row, default 30), folder ("Closures"), tag
	Returns the number of parts made.
]]
function MapAudit.close(edges, opts: { [string]: any }?): number
	opts = opts or {}
	local Kit = require(game:GetService("ServerStorage").DevTools.BuildKit)
	local split = opts.split or 30
	local thickness = opts.thickness or 1
	local clearCache = {}
	local function clearFor(sub: Instance)
		local boxes = clearCache[sub]
		if not boxes then
			boxes = MapAudit.keepClear(sub)
			clearCache[sub] = boxes
		end
		return boxes
	end
	local function inAreaOf(sub: Instance, p: Vector3): boolean
		local area = sub:FindFirstChild("Area")
		return area ~= nil and area:IsA("BasePart") and inBoxes2D(p, { { area.CFrame, area.Size - Vector3.new(4, 0, 4) } })
	end
	local list, skipped = {}, {}
	for _, e in ipairs(edges) do
		local keep = if opts.only == "player" then e.exposure == "player" elseif opts.only == "all" then true else e.exposure ~= nil
		if keep and e.sub and (not opts.filter or opts.filter(e)) then
			local d = flat(e.b - e.a)
			if d.Magnitude > 0.3 then
				local perp = Vector3.new(-d.Z, 0, d.X).Unit
				if perp:Dot(flat(e.c - (e.a + e.b) / 2)) > 0 then
					perp = -perp
				end
				-- An edge over a path / tunnel / spawn / gate is left for a manual fix (a wall there would block it).
				local blocked = false
				for i = 0, 4 do
					if inBoxes2D(e.a:Lerp(e.b, i / 4), clearFor(e.sub)) then
						blocked = true
						break
					end
				end
				local inside = inAreaOf(e.sub, (e.a + e.b) / 2)
				if blocked or (inside and not opts.inK) then
					table.insert(skipped, e)
				else
					table.insert(list, { e = e, perp = perp, k = if inside then opts.inK else (opts.k or 0.3) })
				end
			end
		end
	end
	MapAudit.lastSkipped = skipped
	local function vkey(p: Vector3, kk: number): string
		return string.format("%d|%d|%d|%s", math.round(p.X * 2), math.round(p.Y * 2), math.round(p.Z * 2), if kk < 0 then "in" else "out")
	end
	local vsum = {}
	for _, it in ipairs(list) do
		for _, p in ipairs({ it.e.a, it.e.b }) do
			local key = vkey(p, it.k)
			vsum[key] = (vsum[key] or Vector3.zero) + it.perp
		end
	end
	local see = seeThroughList({ workspace:FindFirstChild("Zones") or workspace, workspace:FindFirstChild("Hub") or workspace })
	-- Floors are measured without the closures (earlier runs included): a vertex must reach the real floor.
	for _, root in ipairs({ workspace:FindFirstChild("Zones") or workspace, workspace:FindFirstChild("Hub") or workspace }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Folder") and d.Name == (opts.folder or "Closures") and d.Parent and d.Parent.Name == "MapFix" then
				table.insert(see, d)
			end
		end
	end
	local folderCache, colorCache, baseCache = {}, {}, {}
	local seeCache = {}
	local function base(p: Vector3, perp: Vector3, sub: Instance, surface: Instance?, kk: number): Vector3
		local key = vkey(p, kk)
		local cached = baseCache[key]
		if cached then
			return cached
		end
		local out = vsum[key] or perp
		out = if out.Magnitude > 0.3 then out.Unit else perp
		-- The edge's own surface is skipped: its slab pokes out under the edge and is not a floor.
		local exclude = see
		if surface then
			exclude = seeCache[surface]
			if not exclude then
				exclude = table.clone(see)
				table.insert(exclude, surface)
				seeCache[surface] = exclude
			end
		end
		local side = if kk < 0 then -1 else 1
		local fy = floorUnder(p + out * 0.6 * side - Vector3.new(0, 0.15, 0), exclude) or (opts.voidFloor or -9)
		fy = math.min(fy, p.Y)
		local drop = p.Y - fy
		local q = Vector3.new(p.X, fy - 1, p.Z) + out * kk * drop
		-- An outward base never lands in the playable box; no base lands on a keep-clear area.
		if (kk > 0 and inAreaOf(sub, p)) or inBoxes2D(q, clearFor(sub)) then
			q = Vector3.new(p.X, fy - 1, p.Z)
		end
		baseCache[key] = q
		return q
	end
	local function colorAt(e, c: Vector3): Color3
		local folder = e.part.Parent
		local facets = colorCache[folder]
		if not facets then
			facets = {}
			for _, f in ipairs(folder:GetChildren()) do
				if f:IsA("BasePart") then
					table.insert(facets, f)
				end
			end
			colorCache[folder] = facets
		end
		local best, bestD = e.part, math.huge
		for _, f in ipairs(facets) do
			local d = (f.Position - c).Magnitude
			if d < bestD then
				best, bestD = f, d
			end
		end
		return Kit.shade(best.Color, 0.03)
	end
	-- All bases first, so no floor ray lands on a closure built in this run.
	for _, it in ipairs(list) do
		base(it.e.a, it.perp, it.e.sub, it.e.part.Parent, it.k)
		base(it.e.b, it.perp, it.e.sub, it.e.part.Parent, it.k)
	end
	local count = 0
	local counter = { n = 0 }
	for _, it in ipairs(list) do
		local e = it.e
		local f = folderCache[e.sub]
		if not f then
			local fix = MapAudit.fixFolder(e.sub)
			f = fix:FindFirstChild(opts.folder or "Closures")
			if not f then
				f = Instance.new("Folder")
				f.Name = opts.folder or "Closures"
				f.Parent = fix
			end
			folderCache[e.sub] = f
		end
		local a, b = e.a, e.b
		local a2, b2 = base(a, it.perp, e.sub, nil, it.k), base(b, it.perp, e.sub, nil, it.k)
		local tris
		if math.max(a.Y - a2.Y, b.Y - b2.Y) > split then
			local am, bm = a:Lerp(a2, 0.5), b:Lerp(b2, 0.5)
			tris = { { a, b, bm }, { a, bm, am }, { am, bm, b2 }, { am, b2, a2 } }
		else
			tris = { { a, b, b2 }, { a, b2, a2 } }
		end
		for _, t in ipairs(tris) do
			local c = (t[1] + t[2] + t[3]) / 3
			local w1, w2 = Kit.tri(t[1], t[2], t[3], f, colorAt(e, c), thickness, e.part.Material)
			for _, w in ipairs({ w1, w2 }) do
				if w then
					w.CastShadow = e.part.CastShadow
					if opts.tag then
						w:SetAttribute("Tag", opts.tag)
					end
					count += 1
				end
			end
		end
		chunkWait(counter, 60)
	end
	return count
end

--[[
	Audit + close loop for a zone / sub-zone / the Hub: finds the open facet edges, classifies them and
	closes the exposed ones, then audits again (the closures' own ends can open new small gaps) until
	nothing exposed is left or maxPasses is reached.
	opts: maxPasses (4), firstFolders = { FolderName = true } (pass 1 only closes those surfaces: do the
	      big outer shells first, the hills behind them are often hidden once the shells are closed),
	      skipFolders = { FolderName = true }, k, tag, only, filter (facet filter), log (function(text))
	Returns { passes = { { open, exposed, parts } }, edges = last edge list, skipped = edges over keep-clear
	areas (paths, tunnel, spawns, gates) that were left for a manual fix }.
]]
function MapAudit.autoClose(target: Instance, opts: { [string]: any }?)
	opts = opts or {}
	local subs = MapAudit.subZones(target)
	local result = { passes = {}, skipped = {} }
	local done = {}
	local function key(e)
		return string.format("%d|%d|%d|%d|%d|%d", math.round(e.a.X * 4), math.round(e.a.Y * 4), math.round(e.a.Z * 4),
			math.round(e.b.X * 4), math.round(e.b.Y * 4), math.round(e.b.Z * 4))
	end
	for pass = 1, opts.maxPasses or 4 do
		local edges = MapAudit.openEdges(subs, { filter = opts.filter })
		MapAudit.classify(edges, subs, opts)
		local chosen = {}
		for _, e in ipairs(edges) do
			local folderName = e.part.Parent.Name
			local okFolder = not (opts.skipFolders and opts.skipFolders[folderName])
			if pass == 1 and opts.firstFolders then
				okFolder = okFolder and opts.firstFolders[folderName] == true
			end
			local keep = if opts.only == "player" then e.exposure == "player" else e.exposure ~= nil
			if keep and okFolder and not done[key(e)] then
				done[key(e)] = true
				table.insert(chosen, e)
			end
		end
		result.edges = edges
		local parts = 0
		if #chosen > 0 then
			parts = MapAudit.close(chosen, { k = opts.k, tag = opts.tag, only = "all", voidFloor = opts.voidFloor })
			for _, e in ipairs(MapAudit.lastSkipped or {}) do
				table.insert(result.skipped, e)
			end
		end
		table.insert(result.passes, { open = #edges, exposed = #chosen, parts = parts })
		if opts.log then
			opts.log(`pass {pass}: open {#edges}, closing {#chosen}, parts {parts}`)
		end
		if #chosen == 0 and (pass > 1 or not opts.firstFolders) then
			break
		end
	end
	return result
end

-- Deletes MapFix parts of a sub-zone (all, or only those with attribute Tag == tag).
function MapAudit.undo(sub: Instance, tag: string?): number
	local fix = (sub:FindFirstChild("Decor") or sub):FindFirstChild("MapFix")
	if not fix then
		return 0
	end
	local n = 0
	for _, d in ipairs(fix:GetDescendants()) do
		if d:IsA("BasePart") and (not tag or d:GetAttribute("Tag") == tag) then
			d:Destroy()
			n += 1
		end
	end
	return n
end

return MapAudit
