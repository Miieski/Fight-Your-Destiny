--!strict
-- A real egg cracking for the hatch screen (owner 2026-10-18: "The egg skin should crack bit by bit and then break,
-- just like a real egg. However, keep the egg skins you've already created"). The zone egg's own mesh and skin
-- (ReplicatedStorage.Assets.Eggs) are read with EditableMesh. Dark crack lines grow over the skin: first a little
-- starburst where the egg is hit, then around the egg's middle in a zigzag, up between the shell pieces and around
-- the top cap. Then the shell splits along exactly those cracks: the cap pops off, the side shards fall away and the
-- bottom cup stays and fades. Every piece keeps the skin outside (same faces, UVs and texture) and is plain shell
-- white inside and on its broken rims. The pattern is new at every hatch.
-- The published game needs "Allow Mesh & Image APIs" (Experience Settings > Security): when the mesh cannot be loaded
-- or edited, EggCrack.new returns nil and the hatch screen keeps its flat 2D cracks.
--   EggCrack.new(eggPart, opts?) -> Shell?   eggPart = the egg MeshPart inside the hatch screen's ViewportFrame; the
--       cracks are an overlay mesh on it (same CFrame, child of the same model so the wobble moves it). Yields while
--       the mesh loads (cached per mesh). opts = { Camera: Camera?, Seed: number?, Low: boolean? }
--   shell:setCracks(p)   0..1: the cracks reached so far (only grows)
--   shell:open(f, glow?) 0..1: the cracks widen just before the break and light (glow colour) shines through them
--   shell:shatter(view)  the break: the pieces fly inside the ViewportFrame view; returns at once, cleans up itself
--   shell:destroy()
-- A device allows only a few EditableMeshes at once (8 on a Studio client): a shell uses 3 (the crack overlay, all
-- the pieces' outsides, all the pieces' insides). The pieces move by moving their own vertices.
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local EggCrack = {}
EggCrack.__index = EggCrack

local CRACK_COLOR = Color3.fromRGB(38, 26, 20)
local SHELL_INSIDE = Color3.fromRGB(246, 241, 228)
local SIDE_SHARDS = 5 -- pieces between the cup and the cap (Low FX: 3)
local CRACK_HALF_WIDTH = 0.0065 -- of the egg's height (mesh units), each side of a crack line
local CRACK_JAGGED = 0.16 -- sideways zigzag of a crack, of its mesh edge's length (each edge = 3 small segments)
local CRACK_LIFT = 0.0035 -- of the egg's height, above the skin
local SHELL_THICKNESS = 0.028 -- of the egg's height
local BOUNDS_MARGIN = 0.03 -- of the egg's height: room for the crack strips, so the copy never rescales
local STARBURST = 4 -- little cracks around the first hit (Low FX: 2)
local PIECE_SECONDS = 1.15 -- how long the pieces fly before they are gone
-- the pieces' meshes have fixed bounds that hold the whole flight (of the egg's height, around its centre)
local FLIGHT_SIDE, FLIGHT_UP, FLIGHT_DOWN = 3.4, 2.6, 4.6

type Face = { k: { number }, uv: { Vector2 }, n: { Vector3 } }
type Data = {
	faces: { Face },
	pos: { Vector3 }, -- welded vertex positions (mesh space)
	vnormal: { Vector3 }, -- outward vertex normals
	edgeFaces: { [number]: { number } }, -- edge key -> faces using it
	vertEdges: { [number]: { number } }, -- welded vertex -> edge keys
	min: Vector3,
	max: Vector3,
	winding: number, -- +1: a face's front is where (p2 - p1) x (p3 - p1) points, -1: the other side
}
type Strip = { ids: { number }, a: Vector3, b: Vector3, side: Vector3, lift: Vector3, ext: Vector3, w: number }
type Vert = { id: number, rest: Vector3 } -- a piece's vertex and where it sits around the piece's centre
type Piece = { cell: number, center: Vector3, outer: { Vert }, inner: { Vert }, outerColor: number, innerColor: number }
type Crack = { edge: number, at: number, w: number } -- w = width factor (the starburst tapers)

export type Shell = typeof(setmetatable({} :: {
	_data: Data,
	_egg: MeshPart,
	_part: MeshPart,
	_em: EditableMesh,
	_scale: Vector3,
	_height: number,
	_rng: Random,
	_cracks: { Crack },
	_next: number,
	_strips: { Strip },
	_pieces: { Piece },
	_meshes: { EditableMesh },
	_outer: EditableMesh?,
	_inner: EditableMesh?,
	_pieceParts: { MeshPart },
	_partOffset: CFrame,
	_bounds: { Vector3 },
	_shards: number,
	_dead: boolean,
	_conn: RBXScriptConnection?,
}, EggCrack))

local cache: { [string]: Data | false } = {}
local loading: { [string]: boolean } = {}

local function edgeKey(a: number, b: number): number
	if a > b then
		a, b = b, a
	end
	return a * 1048576 + b
end

local function edgeEnds(key: number): (number, number)
	local a = key // 1048576
	return a, key - a * 1048576
end

-- Reads a mesh once: welded positions, outward normals, per-face UVs / normals, edge adjacency.
local function load(meshId: string): Data?
	while loading[meshId] do
		task.wait()
	end
	local cached = cache[meshId]
	if cached ~= nil then
		return if cached then cached else nil
	end
	loading[meshId] = true
	local ok, result = pcall(function(): Data
		local src = AssetService:CreateEditableMeshAsync(Content.fromUri(meshId))
		local index: { [string]: number } = {}
		local pos: { Vector3 } = {}
		local faces: { Face } = {}
		local minv, maxv = Vector3.one * math.huge, -Vector3.one * math.huge
		local agree, disagree = 0, 0
		for _, f in ipairs(src:GetFaces()) do
			local vs = src:GetFaceVertices(f)
			local uvs = src:GetFaceUVs(f)
			local ns = src:GetFaceNormals(f)
			local face: Face = { k = {}, uv = {}, n = {} }
			for i = 1, 3 do
				local p = src:GetPosition(vs[i])
				local key = string.format("%d,%d,%d", math.round(p.X * 20000), math.round(p.Y * 20000), math.round(p.Z * 20000))
				local k = index[key]
				if not k then
					table.insert(pos, p)
					k = #pos
					index[key] = k
					minv, maxv = minv:Min(p), maxv:Max(p)
				end
				face.k[i] = k
				face.uv[i] = if uvs[i] then src:GetUV(uvs[i]) else Vector2.zero
				face.n[i] = if ns[i] then src:GetNormal(ns[i]) else Vector3.zero
			end
			if face.k[1] ~= face.k[2] and face.k[2] ~= face.k[3] and face.k[1] ~= face.k[3] then
				local p1, p2, p3 = pos[face.k[1]], pos[face.k[2]], pos[face.k[3]]
				if (p2 - p1):Cross(p3 - p1):Dot(face.n[1] + face.n[2] + face.n[3]) >= 0 then
					agree += 1
				else
					disagree += 1
				end
				table.insert(faces, face)
			end
		end
		src:Destroy()
		local center = (minv + maxv) / 2
		local sums: { Vector3 } = table.create(#pos, Vector3.zero)
		local edgeFaces: { [number]: { number } } = {}
		local vertEdges: { [number]: { number } } = {}
		for fi, face in ipairs(faces) do
			local p1, p2, p3 = pos[face.k[1]], pos[face.k[2]], pos[face.k[3]]
			local cross = (p2 - p1):Cross(p3 - p1)
			if cross:Dot((p1 + p2 + p3) / 3 - center) < 0 then
				cross = -cross
			end
			for i = 1, 3 do
				local k = face.k[i]
				sums[k] += cross
				local e = edgeKey(k, face.k[i % 3 + 1])
				local list = edgeFaces[e]
				if not list then
					list = {}
					edgeFaces[e] = list
					local a, b = edgeEnds(e)
					vertEdges[a] = vertEdges[a] or {}
					vertEdges[b] = vertEdges[b] or {}
					table.insert(vertEdges[a], e)
					table.insert(vertEdges[b], e)
				end
				table.insert(list, fi)
			end
		end
		local vnormal: { Vector3 } = {}
		for k, s in ipairs(sums) do
			vnormal[k] = if s.Magnitude > 1e-12 then s.Unit else (pos[k] - center).Unit
		end
		return {
			faces = faces,
			pos = pos,
			vnormal = vnormal,
			edgeFaces = edgeFaces,
			vertEdges = vertEdges,
			min = minv,
			max = maxv,
			winding = if agree >= disagree then 1 else -1,
		}
	end)
	loading[meshId] = nil
	if ok then
		cache[meshId] = result
		return result
	end
	warn("EggCrack: egg mesh not editable, flat cracks instead (" .. tostring(result) .. ")")
	cache[meshId] = false
	return nil
end

-- A triangle whose front side faces `out` (normals left to the engine).
local function orient(em: EditableMesh, winding: number, ids: { number }, ps: { Vector3 }, out: Vector3): number
	local a, b, c = ids[1], ids[2], ids[3]
	if (ps[2] - ps[1]):Cross(ps[3] - ps[1]):Dot(out) * winding < 0 then
		b, c = c, b
	end
	return em:AddTriangle(a, b, c)
end

-- The same, with that normal on its 3 corners (the crack strips, which never move).
local function triangle(em: EditableMesh, winding: number, ids: { number }, ps: { Vector3 }, out: Vector3): number
	local f = orient(em, winding, ids, ps, out)
	local n = em:AddNormal(if out.Magnitude > 1e-12 then out.Unit else Vector3.yAxis)
	em:SetFaceNormals(f, { n, n, n })
	return f
end

-- An empty EditableMesh, or an error when the device's budget is used up.
local function newMesh(): EditableMesh
	local em = AssetService:CreateEditableMesh({})
	if not em then
		error("EditableMesh budget reached")
	end
	return em
end

local function zig(x: number): number
	-- triangle wave in [-1, 1], period 2 pi
	local u = x / (2 * math.pi)
	return 4 * math.abs(u - math.floor(u + 0.5)) - 1
end

-- Which piece each face belongs to: 0 = bottom cup, 1..k = side shards, k + 1 = top cap.
local function cells(data: Data, rng: Random, k: number): { number }
	local minv, maxv = data.min, data.max
	local height = maxv.Y - minv.Y
	local center = (minv + maxv) / 2
	local equator = 0.5 + rng:NextNumber(-0.03, 0.03)
	local eqAmp = rng:NextNumber(0.035, 0.055)
	local eqTeeth = rng:NextInteger(7, 10)
	local eqPhase = rng:NextNumber(0, math.pi * 2)
	local capBase = rng:NextNumber(0.78, 0.83)
	local capPhase = rng:NextNumber(0, math.pi * 2)
	local turn = rng:NextNumber(0, math.pi * 2)
	local wob = rng:NextNumber(0, math.pi * 2)
	local out = table.create(#data.faces, 0)
	for fi, face in ipairs(data.faces) do
		local c = (data.pos[face.k[1]] + data.pos[face.k[2]] + data.pos[face.k[3]]) / 3
		local t = (c.Y - minv.Y) / height
		local angle = math.atan2(c.Z - center.Z, c.X - center.X)
		if t < equator + eqAmp * zig(angle * eqTeeth + eqPhase) then
			out[fi] = 0
		elseif t > capBase + 0.03 * zig(angle * 5 + capPhase) then
			out[fi] = k + 1
		else
			local a = (angle + turn + 0.28 * math.sin(t * 17 + wob)) % (2 * math.pi)
			out[fi] = math.floor(a / (2 * math.pi / k)) % k + 1
		end
	end
	return out
end

-- The cracks in the order they appear: a starburst at the hit, then along the piece borders by distance from it.
local function crackOrder(data: Data, cellOf: { number }, rng: Random, hitDir: Vector3, starburst: number): { Crack }
	local center = (data.min + data.max) / 2
	local isCrack: { [number]: boolean } = {}
	local graph: { [number]: { number } } = {}
	local equatorNodes: { [number]: boolean } = {}
	for e, faces in pairs(data.edgeFaces) do
		if #faces == 2 and cellOf[faces[1]] ~= cellOf[faces[2]] then
			isCrack[e] = true
			local a, b = edgeEnds(e)
			graph[a] = graph[a] or {}
			graph[b] = graph[b] or {}
			table.insert(graph[a], e)
			table.insert(graph[b], e)
			if cellOf[faces[1]] == 0 or cellOf[faces[2]] == 0 then
				equatorNodes[a], equatorNodes[b] = true, true
			end
		end
	end
	-- the first hit: the point of the middle crack that faces the camera
	local flat = Vector3.new(hitDir.X, 0, hitDir.Z)
	flat = if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(0, 0, -1)
	local start, best = nil, -math.huge
	for k in pairs(equatorNodes) do
		local d = data.pos[k] - center
		local score = Vector3.new(d.X, 0, d.Z).Unit:Dot(flat)
		if score > best then
			start, best = k, score
		end
	end
	if not start then
		return {}
	end
	-- distances along the cracks (Dijkstra on a small graph)
	local dist: { [number]: number } = { [start] = 0 }
	local done: { [number]: boolean } = {}
	local open: { number } = { start }
	while #open > 0 do
		local bi, bk, bd = 1, open[1], dist[open[1]]
		for i, k in ipairs(open) do
			if dist[k] < bd then
				bi, bk, bd = i, k, dist[k]
			end
		end
		table.remove(open, bi)
		if not done[bk] then
			done[bk] = true
			for _, e in ipairs(graph[bk] or {}) do
				local a, b = edgeEnds(e)
				local other = if a == bk then b else a
				local nd = bd + (data.pos[a] - data.pos[b]).Magnitude * rng:NextNumber(0.85, 1.15)
				if dist[other] == nil or nd < dist[other] then
					dist[other] = nd
					table.insert(open, other)
				end
			end
		end
	end
	local maxDist = 0
	for _, d in pairs(dist) do
		maxDist = math.max(maxDist, d)
	end
	local list: { Crack } = {}
	for e in pairs(isCrack) do
		local a, b = edgeEnds(e)
		local da, db = dist[a] or maxDist, dist[b] or maxDist
		table.insert(list, { edge = e, at = 0.12 + 0.88 * math.min(1, (math.max(da, db)) / math.max(maxDist, 1e-6)), w = rng:NextNumber(0.8, 1.2) })
	end
	-- the starburst: short walks over the mesh edges, away from the hit in a few directions
	local used: { [number]: boolean } = {}
	local startPos = data.pos[start]
	local normal = data.vnormal[start]
	local tangent = normal:Cross(Vector3.yAxis)
	tangent = if tangent.Magnitude > 1e-6 then tangent.Unit else Vector3.xAxis
	local bitangent = normal:Cross(tangent).Unit
	for branch = 1, starburst do
		local angle = (branch / starburst) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local want = tangent * math.cos(angle) + bitangent * math.sin(angle)
		local node = start
		local steps = rng:NextInteger(3, 6)
		for step = 1, steps do
			local pick, pickScore = nil, -math.huge
			for _, e in ipairs(data.vertEdges[node] or {}) do
				if not used[e] and not isCrack[e] then
					local a, b = edgeEnds(e)
					local other = if a == node then b else a
					local dir = data.pos[other] - data.pos[node]
					local away = (data.pos[other] - startPos).Magnitude - (data.pos[node] - startPos).Magnitude
					local score = (if dir.Magnitude > 1e-9 then dir.Unit:Dot(want) else -1) + away * 4 + rng:NextNumber(-0.35, 0.35)
					if score > pickScore then
						pick, pickScore = e, score
					end
				end
			end
			if not pick then
				break
			end
			used[pick] = true
			table.insert(list, { edge = pick, at = 0.02 + 0.1 * (step / steps) + rng:NextNumber(0, 0.02), w = 0.9 - 0.55 * (step / steps) })
			local a, b = edgeEnds(pick)
			node = if a == node then b else a
		end
	end
	table.sort(list, function(x, y)
		return x.at < y.at
	end)
	return list
end

local function boundsOf(points: { Vector3 }): (Vector3, Vector3)
	local minv, maxv = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(points) do
		minv, maxv = minv:Min(p), maxv:Max(p)
	end
	return minv, maxv
end

-- The broken pieces, all in two meshes (built before the break, shown at the break): the egg's own faces with their
-- UVs and texture outside, a plain shell-white inside with broken rims. Every piece has its own vertices.
local function buildPieces(self: Shell, cellOf: { number }, texture: Content)
	local data = self._data
	local h = self._height
	local thick = h * SHELL_THICKNESS
	local eggCenter = (data.min + data.max) / 2
	local outer, inner = newMesh(), newMesh()
	table.insert(self._meshes, outer)
	table.insert(self._meshes, inner)
	-- fixed bounds that hold the whole flight, so moving the pieces never rescales the parts
	local lo = eggCenter - Vector3.new(FLIGHT_SIDE, FLIGHT_DOWN, FLIGHT_SIDE) * h
	local hi = eggCenter + Vector3.new(FLIGHT_SIDE, FLIGHT_UP, FLIGHT_SIDE) * h
	for _, em in ipairs({ outer, inner }) do
		em:AddTriangle(em:AddVertex(lo), em:AddVertex(lo), em:AddVertex(lo))
		em:AddTriangle(em:AddVertex(hi), em:AddVertex(hi), em:AddVertex(hi))
	end
	for cell = 0, self._shards + 1 do
		local faceIds = {}
		for fi, c in ipairs(cellOf) do
			if c == cell then
				table.insert(faceIds, fi)
			end
		end
		if #faceIds == 0 then
			continue
		end
		local points = {}
		for _, fi in ipairs(faceIds) do
			for i = 1, 3 do
				table.insert(points, data.pos[data.faces[fi].k[i]])
			end
		end
		local pMin, pMax = boundsOf(points)
		local center = (pMin + pMax) / 2
		local piece: Piece = {
			cell = cell,
			center = center,
			outer = {},
			inner = {},
			outerColor = outer:AddColor(Color3.new(1, 1, 1), 1),
			innerColor = inner:AddColor(Color3.new(1, 1, 1), 1),
		}
		-- outside: the egg's own faces with their UVs
		local outerMap: { [number]: number } = {}
		local oc = piece.outerColor
		for _, fi in ipairs(faceIds) do
			local face = data.faces[fi]
			local ids = {}
			for i = 1, 3 do
				local k = face.k[i]
				if not outerMap[k] then
					outerMap[k] = outer:AddVertex(data.pos[k])
					table.insert(piece.outer, { id = outerMap[k], rest = data.pos[k] - center })
				end
				ids[i] = outerMap[k]
			end
			local f = outer:AddTriangle(ids[1], ids[2], ids[3])
			outer:SetFaceUVs(f, { outer:AddUV(face.uv[1]), outer:AddUV(face.uv[2]), outer:AddUV(face.uv[3]) })
			outer:SetFaceColors(f, { oc, oc, oc })
		end
		-- inside (the faces pushed in by the shell thickness, facing in) and the broken rims along the cracks
		local innerMap: { [number]: number } = {}
		local rimMap: { [number]: number } = {}
		local function vertex(map: { [number]: number }, k: number, p: Vector3): number
			if not map[k] then
				map[k] = inner:AddVertex(p)
				table.insert(piece.inner, { id = map[k], rest = p - center })
			end
			return map[k]
		end
		local ic = piece.innerColor
		for _, fi in ipairs(faceIds) do
			local face = data.faces[fi]
			local k1, k2, k3 = face.k[1], face.k[2], face.k[3]
			local p1, p2, p3 = data.pos[k1], data.pos[k2], data.pos[k3]
			local mid = (p1 + p2 + p3) / 3
			local outward = data.vnormal[k1] + data.vnormal[k2] + data.vnormal[k3]
			local q1, q2, q3 = p1 - data.vnormal[k1] * thick, p2 - data.vnormal[k2] * thick, p3 - data.vnormal[k3] * thick
			local f = orient(inner, data.winding, { vertex(innerMap, k1, q1), vertex(innerMap, k2, q2), vertex(innerMap, k3, q3) }, { q1, q2, q3 }, -outward)
			inner:SetFaceColors(f, { ic, ic, ic })
			for i = 1, 3 do
				local a, b = face.k[i], face.k[i % 3 + 1]
				local around = data.edgeFaces[edgeKey(a, b)]
				local border = #around < 2
				for _, other in ipairs(around) do
					if other ~= fi and cellOf[other] ~= cell then
						border = true
					end
				end
				if border then
					local pa, pb = data.pos[a], data.pos[b]
					local ia, ib = pa - data.vnormal[a] * thick, pb - data.vnormal[b] * thick
					local away = (pa + pb) / 2 - mid
					local oa, ob = vertex(rimMap, a, pa), vertex(rimMap, b, pb)
					local va, vb = vertex(innerMap, a, ia), vertex(innerMap, b, ib)
					local r1 = orient(inner, data.winding, { oa, ob, vb }, { pa, pb, ib }, away)
					local r2 = orient(inner, data.winding, { oa, vb, va }, { pa, ib, ia }, away)
					inner:SetFaceColors(r1, { ic, ic, ic })
					inner:SetFaceColors(r2, { ic, ic, ic })
				end
			end
		end
		table.insert(self._pieces, piece)
	end
	local scale = self._scale
	local outerPart = AssetService:CreateMeshPartAsync(Content.fromObject(outer))
	outerPart.Name = "ShellOutside"
	outerPart.TextureContent = texture
	local innerPart = AssetService:CreateMeshPartAsync(Content.fromObject(inner))
	innerPart.Name = "ShellInside"
	innerPart.Color = SHELL_INSIDE
	innerPart.Material = Enum.Material.SmoothPlastic
	for _, p in ipairs({ outerPart, innerPart }) do
		p.Size = (hi - lo) * scale
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
	end
	self._outer, self._inner = outer, inner
	self._pieceParts = { outerPart, innerPart }
	self._partOffset = CFrame.new(((lo + hi) / 2 - eggCenter) * scale)
	self._bounds = { lo, hi }
end

function EggCrack.new(eggPart: MeshPart, opts: { [string]: any }?): Shell?
	local o = opts or {}
	local data = load(eggPart.MeshId)
	if not data or not eggPart.Parent then
		return nil
	end
	local rng = Random.new(o.Seed or math.floor(os.clock() * 1000) % 1000000)
	local low = o.Low == true
	local height = data.max.Y - data.min.Y
	local scale = eggPart.Size / (data.max - data.min)
	local texture = if eggPart.TextureID ~= "" then Content.fromUri(eggPart.TextureID) else eggPart.TextureContent
	local self: Shell
	local ok, err = pcall(function()
		-- the cracks: an untextured overlay mesh on the egg; it starts empty and gets a strip per crack.
		-- Two invisible (zero-size) triangles fix its bounds a little outside the egg (centred on it, so the overlay
		-- sits exactly on the egg), and adding cracks never rescales it.
		local em = newMesh()
		local margin = Vector3.one * height * BOUNDS_MARGIN
		local lo, hi = data.min - margin, data.max + margin
		em:AddTriangle(em:AddVertex(lo), em:AddVertex(lo), em:AddVertex(lo))
		em:AddTriangle(em:AddVertex(hi), em:AddVertex(hi), em:AddVertex(hi))
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		part.Name = "Cracks"
		part.Size = (hi - lo) * scale
		part.CFrame = eggPart.CFrame
		part.Color = CRACK_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		self = setmetatable({
			_data = data,
			_egg = eggPart,
			_part = part,
			_em = em,
			_scale = scale,
			_height = height,
			_rng = rng,
			_cracks = {},
			_next = 1,
			_strips = {},
			_pieces = {},
			_meshes = { em },
			_outer = nil,
			_inner = nil,
			_pieceParts = {},
			_partOffset = CFrame.identity,
			_bounds = {},
			_shards = if low then 3 else SIDE_SHARDS,
			_dead = false,
			_conn = nil,
		}, EggCrack)
		local cellOf = cells(data, rng, self._shards)
		local hitDir = Vector3.new(0, 0, -1)
		local camera = o.Camera :: Camera?
		if camera then
			local d = eggPart.CFrame:VectorToObjectSpace(camera.CFrame.Position - eggPart.Position)
			hitDir = d / scale
		end
		self._cracks = crackOrder(data, cellOf, rng, hitDir, if low then 2 else STARBURST)
		buildPieces(self, cellOf, texture)
		part.Parent = eggPart.Parent
	end)
	if not ok then
		warn("EggCrack: could not build the cracks (" .. tostring(err) .. ")")
		if self then
			self:destroy()
		end
		return nil
	end
	return self
end

-- One crack: a thin dark zigzag (3 small strips) lying on the skin along a mesh edge. The edge's two ends stay
-- exactly on the mesh vertices, so neighbouring cracks always join.
function EggCrack._strip(self: Shell, edge: number, widthFactor: number)
	local data = self._data
	local a, b = edgeEnds(edge)
	local pa, pb = data.pos[a], data.pos[b]
	local length = (pb - pa).Magnitude
	if length < 1e-9 then
		return
	end
	local n = data.vnormal[a] + data.vnormal[b]
	n = if n.Magnitude > 1e-9 then n.Unit else Vector3.yAxis
	local across = (pb - pa).Unit:Cross(n)
	across = if across.Magnitude > 1e-9 then across.Unit else Vector3.xAxis
	local rng = self._rng
	local points = {
		pa,
		pa:Lerp(pb, 1 / 3) + across * length * CRACK_JAGGED * rng:NextNumber(-1, 1),
		pa:Lerp(pb, 2 / 3) + across * length * CRACK_JAGGED * rng:NextNumber(-1, 1),
		pb,
	}
	local lift = n * self._height * CRACK_LIFT
	local em = self._em
	for i = 1, 3 do
		local s0, s1 = points[i], points[i + 1]
		local dir = s1 - s0
		if dir.Magnitude < 1e-9 then
			continue
		end
		dir = dir.Unit
		local side = dir:Cross(n)
		side = if side.Magnitude > 1e-9 then side.Unit else across
		local w = self._height * CRACK_HALF_WIDTH * widthFactor * rng:NextNumber(0.8, 1.2)
		local strip: Strip = { ids = {}, a = s0, b = s1, side = side, lift = lift, ext = dir * w * 0.9, w = w }
		local corners = {
			s0 - strip.ext + side * w + lift,
			s0 - strip.ext - side * w + lift,
			s1 + strip.ext - side * w + lift,
			s1 + strip.ext + side * w + lift,
		}
		for c, p in ipairs(corners) do
			strip.ids[c] = em:AddVertex(p)
		end
		triangle(em, data.winding, { strip.ids[1], strip.ids[2], strip.ids[3] }, { corners[1], corners[2], corners[3] }, n)
		triangle(em, data.winding, { strip.ids[1], strip.ids[3], strip.ids[4] }, { corners[1], corners[3], corners[4] }, n)
		table.insert(self._strips, strip)
	end
end

function EggCrack.setCracks(self: Shell, p: number)
	if self._dead then
		return
	end
	local list = self._cracks
	while self._next <= #list and list[self._next].at <= p do
		self:_strip(list[self._next].edge, list[self._next].w)
		self._next += 1
	end
end

function EggCrack.open(self: Shell, f: number, glow: Color3?)
	if self._dead then
		return
	end
	f = math.clamp(f, 0, 1)
	local grow = 1 + 1.4 * f
	if glow then
		-- light from inside shines through the widening cracks
		self._part.Color = CRACK_COLOR:Lerp(glow, math.clamp(f * 1.6, 0, 1))
		self._part.Material = if f > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	local em = self._em
	for _, s in ipairs(self._strips) do
		local w = s.w * grow
		em:SetPosition(s.ids[1], s.a - s.ext + s.side * w + s.lift)
		em:SetPosition(s.ids[2], s.a - s.ext - s.side * w + s.lift)
		em:SetPosition(s.ids[3], s.b + s.ext - s.side * w + s.lift)
		em:SetPosition(s.ids[4], s.b + s.ext + s.side * w + s.lift)
	end
end

-- The break: the cracked egg is replaced by its pieces, which fly in the viewport. The motion is worked out in the
-- egg's mesh space and applied by moving each piece's vertices (about 0.5 ms per frame).
function EggCrack.shatter(self: Shell, view: ViewportFrame)
	local outer, inner = self._outer, self._inner
	if self._dead or self._conn or not outer or not inner then
		return
	end
	self:setCracks(1)
	local eggCF = self._egg.CFrame
	local h = self._height
	local rng = self._rng
	-- world up in mesh space (the wobble may have tilted the egg)
	local up = eggCF:VectorToObjectSpace(Vector3.yAxis) / self._scale
	up = if up.Magnitude > 1e-6 then up.Unit else Vector3.yAxis
	local eggCenter = (self._data.min + self._data.max) / 2
	type Flying = { piece: Piece, pos: Vector3, rot: CFrame, vel: Vector3, axis: Vector3, spin: number, fadeFrom: number, fadeTo: number, delay: number }
	local flying: { Flying } = {}
	for _, piece in ipairs(self._pieces) do
		local away = piece.center - eggCenter
		local outward = away - up * away:Dot(up)
		if outward.Magnitude < 1e-6 then
			outward = up:Cross(Vector3.new(rng:NextNumber(-1, 1), 0.1, rng:NextNumber(-1, 1)))
		end
		outward = outward.Unit
		local f: Flying = { piece = piece, pos = piece.center, rot = CFrame.identity, vel = Vector3.zero, axis = Vector3.xAxis, spin = 0, fadeFrom = 0.55, fadeTo = 1.0, delay = 0 }
		if piece.cell == 0 then
			-- the bottom cup stays, sinks a little and fades while the pet appears
			f.vel = -up * 0.25 * h
			f.fadeFrom, f.fadeTo = 0.2, 0.55
		elseif piece.cell == self._shards + 1 then
			-- the cap pops off first
			f.vel = up * rng:NextNumber(2.4, 2.9) * h + outward * rng:NextNumber(0.3, 0.7) * h
			f.axis = outward:Cross(up)
			f.axis = if f.axis.Magnitude > 1e-6 then f.axis.Unit else Vector3.xAxis
			f.spin = rng:NextNumber(5, 8)
		else
			-- the side shards tip outward and fall
			f.vel = outward * rng:NextNumber(1.5, 2.3) * h + up * rng:NextNumber(0.5, 1.1) * h
			f.axis = outward:Cross(up) + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3))
			f.axis = if f.axis.Magnitude > 1e-6 then f.axis.Unit else Vector3.zAxis
			f.spin = -rng:NextNumber(5, 10)
			f.delay = rng:NextNumber(0, 0.06)
		end
		table.insert(flying, f)
	end
	for _, part in ipairs(self._pieceParts) do
		part.CFrame = eggCF * self._partOffset
		part.Parent = view
	end
	self._part.Transparency = 1
	self._egg.Transparency = 1
	-- the rest of the egg's model (its rarity ring) fades with the cup
	local extras: { { part: BasePart, from: number } } = {}
	local model = self._egg.Parent
	if model then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= self._egg and d ~= self._part and d.Transparency < 1 then
				table.insert(extras, { part = d, from = d.Transparency })
			end
		end
	end
	local gravity = -up * 7 * h
	-- keep every piece inside the meshes' fixed bounds (a piece leaving them would rescale the whole part)
	local keepLo = self._bounds[1] + Vector3.one * 0.6 * h
	local keepHi = self._bounds[2] - Vector3.one * 0.6 * h
	local t = 0
	self._conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local cupFade = math.clamp((t - 0.2) / 0.35, 0, 1)
		for _, e in ipairs(extras) do
			e.part.Transparency = e.from + (1 - e.from) * cupFade
		end
		for _, f in ipairs(flying) do
			if t > f.delay then
				f.pos += f.vel * dt
				if f.piece.cell ~= 0 then
					f.vel += gravity * dt
				end
				if f.spin ~= 0 then
					f.rot = CFrame.fromAxisAngle(f.axis, f.spin * dt) * f.rot
				end
				f.pos = f.pos:Max(keepLo):Min(keepHi)
			end
			local cf = CFrame.new(f.pos) * f.rot
			for _, v in ipairs(f.piece.outer) do
				outer:SetPosition(v.id, cf * v.rest)
			end
			for _, v in ipairs(f.piece.inner) do
				inner:SetPosition(v.id, cf * v.rest)
			end
			local fade = math.clamp((t - f.fadeFrom) / (f.fadeTo - f.fadeFrom), 0, 1)
			outer:SetColorAlpha(f.piece.outerColor, 1 - fade)
			inner:SetColorAlpha(f.piece.innerColor, 1 - fade)
		end
		-- whatever the vertex alpha does on a device, everything is gone at the end
		local endFade = math.clamp((t - 0.8) / 0.3, 0, 1)
		for _, part in ipairs(self._pieceParts) do
			part.Transparency = endFade
		end
		if t >= PIECE_SECONDS then
			self:destroy()
		end
	end)
end

function EggCrack.destroy(self: Shell)
	if self._dead then
		return
	end
	self._dead = true
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	for _, part in ipairs(self._pieceParts) do
		part:Destroy()
	end
	if self._part then
		self._part:Destroy()
	end
	for _, em in ipairs(self._meshes) do
		em:Destroy()
	end
	table.clear(self._pieces)
	table.clear(self._pieceParts)
	table.clear(self._meshes)
	self._outer, self._inner = nil, nil
end

return EggCrack
