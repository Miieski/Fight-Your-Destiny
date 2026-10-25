--[[
	PropsSwampLandmarks (dev tool) - the owner's "CURSED SWAMP - ROUND 3" (2026-10-25, parts 1 and 2): the 3 big
	Cursed Swamp landmarks, captured from the map as MapProps (Part 1) and remade here (Part 2), low-mid poly at the
	fountain / well level (guide F, F9):
	01 swamp_witch_tower (Swamp_3 Decor.Landmark, LandmarkName WitchTower), 02 swamp_horror_tree (Swamp_2, SwingTree),
	03 swamp_hollow_log (Swamp_1, SunkenTrunk).

	Kept exactly: every colliding part as an invisible copy (names, attributes and the NoClimb folder too), every glow
	(Neon windows, pupils, mushroom caps), every light, the nested MapProps (lanterns with their own light, ravens, vine
	curtains) at their poses; the visible build goes round them. Today's parts are rows in
	DevTools.PropsSwampLandmarksData (tools/PropsSwampLandmarksData.luau).

	Usage (Studio command bar):
		local SL = require(game.ServerStorage.DevTools.PropsSwampLandmarks:Clone())
		print(SL.install("swamp_witch_tower"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "swamp_witch_tower" } }))
]]

local ServerStorage = game:GetService("ServerStorage")

local ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()) :: any
local SM = require(ServerStorage.DevTools.PropsSwampMagic:Clone()) :: any
local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any
local TB, B2, H, M = SH.TB, SH.B2, SH.H, SH.M
local GD = require(ServerStorage.DevTools.PropsSwampLandmarksData:Clone()) :: any
local piece, chamfered = H.piece, H.chamfered
local scaled = H.scaled
local frustumN = M.frustumN
local C = SH.COLORS
local blob, leaf, leafTone = ST.blob, ST.leaf, ST.leafTone

local SL = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local MOSS, MOSS_MID, OLIVE = C.MOSS, C.MOSS_MID, C.OLIVE
local MOSS_TOP = MOSS:Lerp(OLIVE, 0.3)
local IRON = rgb(55, 58, 65) -- #373A41
local IRON_LIGHT = rgb(84, 88, 98)
local GOLD = rgb(214, 170, 72)
local DARKWOOD = rgb(50, 38, 32) -- #322620
local CORE = rgb(30, 22, 18)
local GLYPH = rgb(30, 22, 18)

local function tone(rng: Random, c: Color3): Color3
	return scaled(c, H.TONES[H.toneIndex(rng, nil)])
end

local function rows(id: string, name: string?): { any }
	return GD.rows(id, name)
end
SL.rows = rows

-- an exact copy of a row (and its light)
local function exactRow(parent: Instance, r: any): BasePart
	local p = Instance.new(r.class) :: BasePart
	if r.shape ~= "" and p:IsA("Part") then
		p.Shape = (Enum.PartType :: any)[r.shape]
	end
	p.Name = r.name
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = r.color
	p.Material = (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.CanTouch = true
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if r.light then
		local l = Instance.new(r.light.k) :: any
		l.Color = Color3.fromHex(r.light.col)
		l.Range = r.light.r
		l.Brightness = r.light.b
		l.Shadows = r.light.sh
		l.Parent = p
	end
	p.Parent = parent
	return p
end
SL.exactRow = exactRow

-- an exact copy of a mesh row (today's GlowMushroom_B Caps / Stems): the mesh cloned from the kit
local function meshRow(parent: Instance, r: any): BasePart?
	local src = nil
	for _, d in ipairs(ServerStorage.MapAssets:GetDescendants()) do
		if d:IsA("MeshPart") and d.MeshId == r.meshId then
			src = d
			break
		end
	end
	if not src then
		return nil
	end
	local p = (src :: MeshPart):Clone()
	p:ClearAllChildren()
	p.Name = r.name
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = r.color
	p.Material = (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.Anchored = true
	p.Parent = parent
	return p
end

-- today's colliding parts, invisible, at their places (names and attributes kept for the NoClimb walls, which go back
-- into a NoClimb folder; the others are "Collision")
local function colliders(m: Model, id: string): number
	local n = 0
	local folders = {}
	for _, r in ipairs(rows(id)) do
		if r.collide then
			local p = Instance.new(r.class) :: BasePart
			if r.shape ~= "" and p:IsA("Part") then
				p.Shape = (Enum.PartType :: any)[r.shape]
			end
			local inFolder = r.parent ~= "" and not string.find(r.parent, "#", 1, true)
			p.Name = if inFolder then r.name else "Collision"
			p.Size = r.size
			p.CFrame = r.cf
			p.Anchored = true
			p.CanCollide = true
			p.CanQuery = r.query
			p.CastShadow = false
			p.Transparency = 1
			for k, v in pairs(r.attrs or {}) do
				p:SetAttribute(k, v)
			end
			if inFolder then
				local f = folders[r.parent]
				if not f then
					f = Instance.new("Folder")
					f.Name = r.parent
					f.Parent = m
					folders[r.parent] = f
				end
				p.Parent = f
			else
				p.Parent = m
			end
			n += 1
		end
	end
	return n
end
SL.colliders = colliders

-- today's nested MapProps at their poses (a lantern's own light on its kept part, as on the map)
local function nested(m: Model, id: string)
	for _, n in ipairs(GD[id].nested) do
		local t = ServerStorage.MapProps:FindFirstChild(n.id)
		assert(t, "PropsSwampLandmarks: ServerStorage.MapProps." .. n.id .. " missing")
		local c = t:Clone() :: Model
		c.Name = n.n
		c:ScaleTo(n.sc)
		c:PivotTo(CFrame.new(table.unpack(n.cf)))
		c:AddTag("MapProp")
		c:SetAttribute("MapPropId", n.id)
		c:SetAttribute("MapPropVersion", tostring(t:GetAttribute("MapPropVersion") or "?") .. "|")
		if n.light then
			local p = Instance.new("Part")
			p.Name = "KeptLight_Lantern"
			p.Size = Vector3.new(table.unpack(n.light.s))
			p.CFrame = CFrame.new(table.unpack(n.light.cf))
			p.Anchored = true
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p:SetAttribute("MapPropKeep", true)
			local l = Instance.new(n.light.k) :: any
			l.Color = Color3.fromHex(n.light.col)
			l.Range = n.light.r
			l.Brightness = n.light.b
			l.Shadows = n.light.sh
			l.Parent = p
			p.Parent = c
		end
		c.Parent = m
	end
end
SL.nested = nested

-- today's glowing mushroom models (GlowMushroom_B: Caps Neon + Stems meshes) exactly, each in its own model
local function mushrooms(m: Model, id: string)
	local models = {}
	for _, r in ipairs(rows(id)) do
		if string.find(r.parent, "GlowMushroom_B#", 1, true) then
			local mm = models[r.parent]
			if not mm then
				mm = Instance.new("Model")
				mm.Name = "GlowMushroom_B"
				mm.Parent = m
				models[r.parent] = mm
			end
			meshRow(mm, r)
		end
	end
end

-- an invisible root part over the whole model, the model's pivot kept at the origin (today's pivot)
local function rootOver(m: Model)
	local cf, size = m:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = cf
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.PivotOffset = cf:Inverse()
	root.Parent = m
	m.PrimaryPart = root
end

---------------------------------------------------------------------
-- 01 WITCH TOWER (Swamp_3 Decor.Landmark, LandmarkName WitchTower: a stone base 27 x 8 x 27 and a plinth 22 x 3, 5
-- steps, 3 wall tiers 20 / 17 / 14 (offset and tilted), 2 floors and a balcony with rails, 9 struts, a top block, a
-- brim and 5 tilted roof tiers (the bent witch hat), 5 round windows (Neon: 2 magenta, 2 yellow, 1 green; the big
-- magenta one carries a PointLight #AA50FF r40) in dark frames, the door and its lintel, a leaning chimney; nested:
-- a raven on the brim, 2 hanging lanterns (one with its own light), 3 vine curtains; 38.2 x 105.9 x 44.4; 1 copy)
---------------------------------------------------------------------
-- From today's parts: the base and the plinth as cut stone blocks in courses with joints over a dark core, the steps as
-- bevelled stone slabs, moss on the stone; each wall tier as a timber-frame wall: vertical planks in 3 tones with gaps
-- over a dark core (cut round the door and the windows), corner posts, a beam at the foot and the top, a diagonal brace
-- on the faces without an opening (today's offsets and tilts kept); the floors and the balcony as plank decks with an
-- edge beam, the balcony's rails as timber rails with balusters on today's posts; the struts as timber braces with iron
-- plates; the round windows kept exactly (glow and light) in iron rings with mullions, the yellow ones with open
-- shutters; the door as planks with 2 iron straps, rivets and a ring handle under today's lintel (a timber beam); the
-- chimney as a stone stack with a cap; THE HAT: today's brim as a wide drooping brim, the 5 tiers as cones of
-- overlapping purple shingles following today's bend to the tip, a dark band with a gold buckle; vines hanging from the
-- floors; the raven, lanterns and vine curtains nested as today. Colliders: today's 39 colliding parts (invisible).
function SL.swamp_witch_tower(): Model
	local id = "swamp_witch_tower"
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(20261601)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Steps = {}, Moss = {}, Deck = {}, Struts = {}, Iron = {}, Glass = {}, Door = {}, Chimney = {}, Brim = {}, Band = {}, Vines = {}, VineLeaves = {} }
	local all = rows(id)
	local function named(n: string): { any }
		local out = {}
		for _, r in ipairs(all) do
			if r.name == n then
				table.insert(out, r)
			end
		end
		return out
	end
	-- the stone: base and plinth in courses, the steps as slabs, moss
	for _, r in ipairs(named("Base")) do
		local big = r.size.Y > 5
		SM.stoneBlocks(U.Stone, rng, r.size, r.cf, r.color, if big then 4 else 4, if big then 4 else 4, if big then 3 else 1)
	end
	for i, r in ipairs(named("Step")) do
		table.insert(U.Steps, chamfered(r.size - Vector3.new(0.06, 0.06, 0.06), r.cf, tone(rng, r.color), { "vertical", "topFrontBack", "topSides" }, 0.14))
		if i % 2 == 0 then
			ST.mossCushion(U.Moss, rng, r.cf * CFrame.new(r.size.X * 0.36, r.size.Y / 2, 0), 1.0)
		end
	end
	do
		local b = named("Base")[1]
		for _, r in ipairs(named("Base")) do
			if r.size.X > b.size.X then
				b = r
			end
		end
		for _, e in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
			ST.mossCushion(U.Moss, rng, b.cf * CFrame.new(e[1] * (b.size.X / 2 - 1.6), b.size.Y / 2, e[2] * (b.size.Z / 2 - 1.6)), 2.2)
		end
	end
	-- the openings (door, windows) for cutting the planks
	local openings = {}
	for _, r in ipairs(all) do
		if r.name == "Door" or r.name == "Window" then
			table.insert(openings, r)
		end
	end
	-- a timber-frame wall tier round the box row r (its frame: today's offset and tilt)
	local function walls(key: string, r: any)
		local list = {}
		U[key] = list
		local cf, S = r.cf, r.size
		local wood = scaled(r.color, 1.22) -- (lit planks over the dark core: today's colour reads in the light)
		table.insert(list, piece("Part", S - Vector3.new(0.1, 0.1, 0.1), cf, CORE))
		for _, f in ipairs({ { Vector3.xAxis, Vector3.zAxis, S.X, S.Z }, { -Vector3.xAxis, -Vector3.zAxis, S.X, S.Z }, { Vector3.zAxis, -Vector3.xAxis, S.Z, S.X }, { -Vector3.zAxis, Vector3.xAxis, S.Z, S.X } }) do
			local n, t, D, W = f[1], f[2], f[3] / 2, f[4]
			-- this face's openings in (along t, y) coordinates
			local holes = {}
			for _, o in ipairs(openings) do
				local p = cf:PointToObjectSpace(o.cf.Position)
				if math.abs(p:Dot(n) - D) < 1.6 and math.abs(p:Dot(t)) < W / 2 + 1 and math.abs(p.Y) < S.Y / 2 + 1 then
					local hw = (if o.size.X > 1 then o.size.X else o.size.Z) / 2 + 0.35
					local hh = o.size.Y / 2 + 0.35
					table.insert(holes, { p:Dot(t), p.Y, hw, hh })
				end
			end
			local np = math.max(4, math.floor(W / 1.7 + 0.5))
			local pw = W / np
			local y0, y1 = -S.Y / 2 + 0.7, S.Y / 2 - 0.7
			for i = 0, np - 1 do
				local x0, x1 = -W / 2 + i * pw, -W / 2 + (i + 1) * pw
				local spans = { { y0, y1 } }
				for _, h in ipairs(holes) do
					if x1 > h[1] - h[3] and x0 < h[1] + h[3] then
						local nxt = {}
						for _, sp in ipairs(spans) do
							if sp[2] <= h[2] - h[4] or sp[1] >= h[2] + h[4] then
								table.insert(nxt, sp)
							else
								if sp[1] < h[2] - h[4] then
									table.insert(nxt, { sp[1], h[2] - h[4] })
								end
								if sp[2] > h[2] + h[4] then
									table.insert(nxt, { h[2] + h[4], sp[2] })
								end
							end
						end
						spans = nxt
					end
				end
				local c = tone(rng, wood)
				for _, sp in ipairs(spans) do
					if sp[2] - sp[1] > 0.3 then
						local pos = n * (D + 0.1) + t * ((x0 + x1) / 2) + UP * ((sp[1] + sp[2]) / 2)
						table.insert(list, piece("Part", (t * (pw - 0.1)):Abs() + UP * (sp[2] - sp[1]) + (n * 0.22):Abs(), cf * CFrame.new(pos), c))
					end
				end
			end
			-- the beams at the foot and the top, a brace on a face without an opening
			for _, y in ipairs({ -S.Y / 2 + 0.35, S.Y / 2 - 0.35 }) do
				local pos = n * (D + 0.28) + UP * y
				table.insert(list, piece("Part", (t * (W + 0.5)):Abs() + UP * 0.7 + (n * 0.36):Abs(), cf * CFrame.new(pos), DARKWOOD))
			end
			if #holes == 0 then
				local a = cf * (n * (D + 0.3) + t * (-W / 2 + 0.8) + UP * (-S.Y / 2 + 0.8))
				local b = cf * (n * (D + 0.3) + t * (W / 2 - 0.8) + UP * (S.Y / 2 - 0.8))
				table.insert(list, H.bar(a, b, 0.5, scaled(DARKWOOD, 1.1)))
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(list, chamfered(Vector3.new(0.9, S.Y + 0.1, 0.9), cf * CFrame.new(sx * (S.X / 2 + 0.1), 0, sz * (S.Z / 2 + 0.1)), DARKWOOD, { "vertical" }, 0.15))
			end
		end
	end
	local segs = named("Segment")
	table.sort(segs, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	for i, r in ipairs(segs) do
		walls("Walls" .. i, r)
	end
	-- the floors and the balcony: plank decks with an edge beam
	for _, r in ipairs(all) do
		if r.name == "Floor" or r.name == "Balcony" or (r.name == "Roof" and r.size.Y < 2) then
			if r.name ~= "Roof" then
				local nb = math.floor(r.size.X / 1.5 + 0.5)
				local bw = r.size.X / nb
				for i = 0, nb - 1 do
					table.insert(U.Deck, piece("Part", Vector3.new(bw - 0.07, r.size.Y - 0.2, r.size.Z - 0.6), r.cf * CFrame.new(-r.size.X / 2 + bw * (i + 0.5), 0.1, 0), tone(rng, scaled(r.color, 1.25))))
				end
				for _, e in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
					local along = if e[1] == 0 then Vector3.new(r.size.X + 0.2, 0.9, 0.4) else Vector3.new(0.4, 0.9, r.size.Z + 0.2)
					table.insert(U.Deck, piece("Part", along, r.cf * CFrame.new(e[1] * (r.size.X / 2 - 0.1), -0.15, e[2] * (r.size.Z / 2 - 0.1)), DARKWOOD))
				end
				-- vines hanging from 2 deck edges
				for k = 1, 2 do
					local a = rng:NextNumber(0, 2 * math.pi)
					local top = (r.cf * CFrame.new(math.cos(a) * r.size.X * 0.46, -0.5, math.sin(a) * r.size.Z * 0.46)).Position
					ST.leafyVine(U.Vines, U.VineLeaves, rng, top, rng:NextNumber(3, 6), 0.32, rgb(62, 92, 40))
				end
			end
		end
	end
	-- the balcony rails: timber rails with balusters, today's posts as capped posts
	for _, r in ipairs(named("RailPost")) do
		table.insert(U.Deck, chamfered(r.size, r.cf, r.color, { "vertical", "topFrontBack", "topSides" }, 0.12))
		table.insert(U.Deck, chamfered(Vector3.new(1.1, 0.3, 1.1), r.cf * CFrame.new(0, r.size.Y / 2 + 0.15, 0), scaled(r.color, 1.12), { "topFrontBack", "topSides" }, 0.08))
	end
	for _, r in ipairs(named("Rail")) do
		table.insert(U.Deck, chamfered(r.size + Vector3.new(0, 0.1, 0.1), r.cf, scaled(r.color, 1.08), { "topFrontBack" }, 0.08))
		local n = math.floor(r.size.X / 1.4)
		for k = 1, n - 1 do
			local x = -r.size.X / 2 + k * r.size.X / n
			table.insert(U.Deck, piece("Part", Vector3.new(0.25, 2.0, 0.25), r.cf * CFrame.new(x, -1.2, 0), scaled(r.color, 0.95)))
		end
	end
	-- the struts: timber braces with iron plates at both ends
	for _, r in ipairs(named("Bracket")) do
		table.insert(U.Struts, chamfered(r.size + Vector3.new(0.1, 0.1, 0), r.cf, tone(rng, r.color), { "vertical" }, 0.12))
		for _, s in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(1.2, 1.2, 0.2), r.cf * CFrame.new(0, 0, s * (r.size.Z / 2 - 0.4)), IRON))
		end
	end
	-- the round windows exactly (glow, light), their dark frames exactly, iron rings, mullions, shutters on the yellow ones
	for _, r in ipairs(all) do
		if r.name == "Window" or r.name == "WindowFrame" then
			exactRow(m, r)
		end
	end
	for _, r in ipairs(named("Window")) do
		local axis = r.cf.XVector
		local flat = Vector3.new(r.cf.X, 0, r.cf.Z)
		local out = if axis:Dot(flat) >= 0 then axis else -axis
		local R = r.size.Y / 2
		local c = r.cf.Position + out * 0.5
		SM.ring(U.Iron, c, out, R + 0.25, 0.32, 12, IRON)
		local up = r.cf.YVector
		local side = out:Cross(up).Unit
		table.insert(U.Iron, H.bar(c + out * 0.05 - up * R, c + out * 0.05 + up * R, 0.14, IRON))
		table.insert(U.Iron, H.bar(c + out * 0.05 - side * R, c + out * 0.05 + side * R, 0.14, IRON))
		if r.color:ToHex() == "ffc460" then
			for _, s in ipairs({ -1, 1 }) do
				local hinge = c + side * s * (R + 0.4)
				local pcf = CFrame.fromMatrix(hinge, side * s, up) * CFrame.Angles(0, rad(-35), 0) * CFrame.new(R * 0.55, 0, 0)
				for k = -1, 1 do
					table.insert(U.Door, piece("Part", Vector3.new(R * 0.36, R * 2 + 0.4, 0.16), pcf * CFrame.new(k * R * 0.37, 0, 0), tone(rng, rgb(84, 62, 44))))
				end
				table.insert(U.Iron, piece("Part", Vector3.new(R * 1.1, 0.16, 0.2), pcf * CFrame.new(0, R * 0.5, -0.1), IRON))
			end
		end
	end
	-- the door: planks, 2 iron straps with rivets, a ring handle; today's lintel as a timber beam
	for _, r in ipairs(named("Door")) do
		local np = 4
		for k = 0, np - 1 do
			local x = -r.size.X / 2 + (k + 0.5) * r.size.X / np
			table.insert(U.Door, chamfered(Vector3.new(r.size.X / np - 0.08, r.size.Y - 0.1, r.size.Z + 0.12), r.cf * CFrame.new(x, 0, 0), tone(rng, rgb(70, 50, 36)), { "vertical" }, 0.05))
		end
		for _, y in ipairs({ -r.size.Y * 0.3, r.size.Y * 0.3 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(r.size.X - 0.3, 0.45, 0.12), r.cf * CFrame.new(0, y, -r.size.Z / 2 - 0.1), IRON))
			for _, x in ipairs({ -r.size.X * 0.35, 0, r.size.X * 0.35 }) do
				SM.rivet(U.Iron, (r.cf * CFrame.new(x, y, -r.size.Z / 2 - 0.16)).Position, -r.cf.LookVector, 0.09)
			end
		end
		SM.ring(U.Iron, (r.cf * CFrame.new(r.size.X * 0.28, -0.4, -r.size.Z / 2 - 0.3)).Position, r.cf.LookVector, 0.42, 0.12, 10, IRON_LIGHT)
		for _, s in ipairs({ -1, 1 }) do
			table.insert(U.Door, chamfered(Vector3.new(0.6, r.size.Y + 0.3, 0.8), r.cf * CFrame.new(s * (r.size.X / 2 + 0.3), 0.15, -0.1), DARKWOOD, { "vertical" }, 0.1))
		end
	end
	for _, r in ipairs(all) do
		if r.name == "Part" and r.collide then
			table.insert(U.Door, chamfered(r.size + Vector3.new(0.2, 0.2, 0.2), r.cf, scaled(r.color, 0.8), { "vertical", "topFrontBack" }, 0.1))
		end
	end
	-- the chimney: a stone stack with 2 courses lines and a cap
	for _, r in ipairs(named("Chimney")) do
		table.insert(U.Chimney, chamfered(r.size + Vector3.new(0.3, 0.3, 0), r.cf, r.color, { "vertical" }, 0.15))
		for _, z in ipairs({ -r.size.Z * 0.15, r.size.Z * 0.2 }) do
			table.insert(U.Chimney, piece("Part", Vector3.new(r.size.X + 0.42, r.size.Y + 0.42, 0.3), r.cf * CFrame.new(0, 0, z), scaled(r.color, 0.8)))
		end
		local zTop = if (r.cf * CFrame.new(0, 0, r.size.Z / 2)).Y > (r.cf * CFrame.new(0, 0, -r.size.Z / 2)).Y then 1 else -1
		table.insert(U.Chimney, chamfered(Vector3.new(r.size.X + 0.8, r.size.Y + 0.8, 0.6), r.cf * CFrame.new(0, 0, zTop * (r.size.Z / 2 - 0.1)), scaled(r.color, 1.15), { "vertical" }, 0.15))
	end
	-- THE HAT: the brim, the shingled tiers along today's bend, the band and the buckle
	local roofs = {}
	local brim = nil
	for _, r in ipairs(named("Roof")) do
		if r.size.Y < 2 then
			brim = r
		else
			table.insert(roofs, r)
		end
	end
	table.sort(roofs, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	if brim then
		local R = brim.size.X / 2
		local bf = brim.cf * CFrame.new(0, -brim.size.Y / 2, 0)
		table.insert(U.Brim, frustumN(16, R * 0.72, R * 0.72, 0, brim.size.Y, bf, { rgb(62, 34, 84), rgb(52, 28, 72) }))
		table.insert(U.Brim, frustumN(16, R * 1.06, R * 0.72, -0.35, brim.size.Y * 0.6, bf, { rgb(70, 38, 94), rgb(58, 32, 80) }))
	end
	local PURPLE = { rgb(74, 41, 96), rgb(87, 46, 118) } -- #4A2960 / #572E76 today's
	for i, r in ipairs(roofs) do
		local f = r.cf
		local nxt = roofs[i + 1]
		local rb = r.size.X / 2 * 1.08
		local rt = if nxt then nxt.size.X / 2 * 1.08 else 0.12
		local h = r.size.Y
		local list = {}
		U["Hat" .. i] = list
		table.insert(list, frustumN(12, rb * 0.92, rt * 0.92, -h / 2 - 0.3, h / 2 + 0.5, f, { scaled(PURPLE[1], 0.8) }))
		-- 2 rows of 12 overlapping shingles (the lower row proud)
		if rt > 0.5 then
			for row = 0, 1 do
				local ya, yb = -h / 2 + row * h / 2 - 0.1, -h / 2 + (row + 1) * h / 2 + 0.25
				local ra, rbb = rb + (rt - rb) * (row / 2), rb + (rt - rb) * ((row + 1) / 2)
				for k = 0, 11 do
					local a = (k + 0.5 * row) * math.pi / 6
					local d = Vector3.new(math.cos(a), 0, math.sin(a))
					local p0 = d * ra + UP * ya
					local p1 = d * rbb + UP * yb
					local w = 2 * math.max(ra, rbb) * math.tan(math.pi / 12) * 1.12
					local upv = (p1 - p0).Unit
					local x = upv:Cross(d).Unit
					local out = x:Cross(upv)
					local mid = (p0 + p1) / 2 + out * (0.08 + 0.12 * (1 - row))
					local c = PURPLE[(k + row) % 2 + 1]
					table.insert(list, piece("Part", Vector3.new(w, (p1 - p0).Magnitude, 0.3), f * CFrame.fromMatrix(mid, x, upv), scaled(c, rng:NextNumber(0.92, 1.08))))
				end
			end
		else
			-- the bent tip: a last curl
			table.insert(list, frustumN(8, rb * 0.9, 0.05, -h / 2, h / 2 + 1.4, f * CFrame.Angles(0, 0, rad(-14)), { PURPLE[2], PURPLE[1] }))
		end
	end
	-- the band and the buckle on the lowest tier (the buckle facing the door)
	if roofs[1] then
		local r = roofs[1]
		local rb = r.size.X / 2 * 1.08
		local f = r.cf * CFrame.new(0, -r.size.Y / 2 + 0.9, 0)
		table.insert(U.Band, frustumN(16, rb * 0.99 + 0.05, rb * 0.97 + 0.05, -0.75, 0.75, f, { rgb(28, 20, 22), rgb(36, 26, 28) }))
		local door = named("Door")[1]
		local dir = if door then (Vector3.new(door.cf.X, 0, door.cf.Z) - Vector3.new(r.cf.X, 0, r.cf.Z)).Unit else -Vector3.zAxis
		local bpos = f.Position + dir * (rb + 0.15)
		local bcf = CFrame.lookAt(bpos, bpos + dir)
		for _, e in ipairs({ { 0, 0.85, 2.2, 0.35 }, { 0, -0.85, 2.2, 0.35 }, { 0.95, 0, 0.35, 2.0 }, { -0.95, 0, 0.35, 2.0 } }) do
			table.insert(U.Band, piece("Part", Vector3.new(e[3], e[4], 0.2), bcf * CFrame.new(e[1], e[2], -0.12), GOLD))
		end
		table.insert(U.Band, piece("Part", Vector3.new(0.25, 1.4, 0.24), bcf * CFrame.new(0.2, 0, -0.18), scaled(GOLD, 0.85)))
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, id, U, "Stone", { Glass = { material = Enum.Material.Glass, transparency = 0.5 } })
	nested(m, id)
	rootOver(m)
	colliders(m, id)
	return m
end

---------------------------------------------------------------------
-- 02 GIANT HORROR TREE (Swamp_2 Decor.Landmark, LandmarkName SwingTree: 5 trunk blocks 18 / 14 / 10 / 6 / 3 stacked
-- to 69, 18 branch blocks, 7 roots (the trunk, 3 limbs and the roots collide), the face (2 dark Eye blocks, 2 Neon
-- Pupils #FFE860, the dark Mouth), a swing (2 ropes and a seat on the west branch), 3 GlowMushroom_B (Neon caps), the
-- NoClimb folder (16 trunk walls, 7 root fins, a path-side wall, a roof disc: invisible); nested: a hanging lantern with
-- its own light, 3 ravens, 6 vine curtains; 82.5 x 78.4 x 84; 1 copy)
---------------------------------------------------------------------
-- THE DEAD-TREE RECIPE at landmark size: today's 5 trunk blocks as one tapered 8-sided bark trunk (deep ridges and
-- grooves, knuckles), a rounded face mound (ellipsoidSolid with a flat front where today's face sits) carved round
-- today's eyes, pupils and mouth (kept exactly): a heavy brow of bark lumps, deep sockets (a dark recess and a shadow
-- ring), cheek knobs, a long carved nose (a tapered 5-sided wedge), lips and 5 crooked pale teeth, a mossy beard;
-- today's 18 branches as gnarled arms (their thickness) with thick forks and finer twigs, hanging moss strands; today's
-- 7 roots as tapered 8-sided roots with buttress fins between them and mud collars where they meet the path; a small
-- framed window with a warm pane on the trunk over the lantern; a twig nest under the raven on the south branch;
-- today's swing as rope (6-sided) and a 2-board seat; today's 3 glowing mushrooms kept exactly and small ghost
-- mushrooms at the foot; moss. Colliders: today's colliding parts and the NoClimb folder (invisible, names and
-- attributes kept). Parts: Trunk (PrimaryPart), Bark, Face, Teeth, Branches, Twigs, Roots, Mud, Moss, Window, Nest,
-- WindowGlow (Neon), Swing, Mush, Eye x2, Pupil x2, Mouth, GlowMushroom_B x3, the nested props, Collision, NoClimb
function SL.swamp_horror_tree(): Model
	local id = "swamp_horror_tree"
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(20261602)
	H.setBevelSelf(true)
	local U: any = { Trunk = {}, Bark = {}, Face = {}, Teeth = {}, Branches = {}, Twigs = {}, Roots = {}, Mud = {}, Moss = {}, Window = {}, WindowGlow = {}, Nest = {}, Swing = {}, Mush = {} }
	local all = rows(id)
	local trunks, limbs, roots = {}, {}, {}
	for _, r in ipairs(all) do
		if r.name == "Limb" then
			local look = r.cf.LookVector
			if math.abs(look.Y) > 0.9 and r.size.X >= 3 then
				table.insert(trunks, r)
			else
				table.insert(limbs, r)
			end
		elseif r.name == "Root" then
			table.insert(roots, r)
		end
	end
	table.sort(trunks, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	local WOOD = trunks[1].color
	local eyes = rows(id, "Eye")
	local mouth = rows(id, "Mouth")[1]
	local faceZ = eyes[1].cf.Z + 0.1 -- the face's flat front: today's eye blocks stand half proud of it
	-- the trunk: control points through today's blocks, radii a little under today's (the face front stays clear)
	local P, Rr = {}, {}
	for i, r in ipairs(trunks) do
		local a, b = r.cf.Position - r.cf.LookVector * r.size.Z / 2, r.cf.Position + r.cf.LookVector * r.size.Z / 2
		if a.Y > b.Y then
			a, b = b, a
		end
		if i == 1 then
			table.insert(P, Vector3.new(a.X, -0.5, a.Z))
			table.insert(Rr, r.size.X / 2 * 0.86) -- (under the face's front: the face mound carries the width there)
		end
		table.insert(P, b)
		table.insert(Rr, (if trunks[i + 1] then trunks[i + 1].size.X / 2 * 1.05 else r.size.X / 2 * 0.45))
	end
	ST.deadTrunk(U.Trunk, U.Bark, rng, P, Rr, WOOD, 2, function(d: Vector3, y: number): boolean
		return d.Z < -0.6 and y < 17
	end)
	-- the face mound: rounded, its flat front at today's face
	do
		local fc = Vector3.new(0.8, 9.5, faceZ + 8.2)
		SM.ellipsoidSolid(U.Trunk, CFrame.new(fc), Vector3.new(9.4, 9.8, 8.6), function(n: Vector3): Color3
			return scaled(WOOD, 0.9 + 0.2 * math.max(n.Y, 0))
		end, 12, { -0.5, -0.15, 0.2, 0.55, 0.95 }, { bottom = 9.9, front = 8.2 })
	end
	-- the face: today's parts exactly, the carving round them
	for _, r in ipairs(eyes) do
		exactRow(m, r)
		local x, y = r.cf.X, r.cf.Y
		-- the deep socket: a dark recess and a shadow ring, a cheek knob under it
		table.insert(U.Face, piece("Part", Vector3.new(r.size.X + 1.0, r.size.Y + 1.0, 0.12), CFrame.new(x, y, faceZ - 0.02), rgb(18, 13, 11)))
		table.insert(U.Face, frustumN(10, r.size.Y * 0.78, r.size.Y * 0.74, -0.05, 0.12, H.frameY(Vector3.new(x, y, faceZ - 0.05), -Vector3.zAxis), { scaled(WOOD, 0.6) }))
		blob(U.Face, rng, CFrame.new(x, y - r.size.Y / 2 - 1.0, faceZ - 0.4), 1.5, 0.9, 0.7, function(n: Vector3): Color3
			return scaled(WOOD, 1.0 + 0.18 * math.max(n.Y, 0))
		end)
		-- the heavy brow: an arc of 5 bark lumps over the socket, lower at the inner end
		local inward = if x < 0.8 then 1 else -1
		for k = 0, 4 do
			local a = rad(160 - k * 35)
			local p = Vector3.new(x + math.cos(a) * 2.4, y + 1.5 + math.sin(a) * 1.0 - (if (math.cos(a) * inward) > 0 then 0.5 else 0), faceZ - 0.8)
			blob(U.Face, rng, CFrame.new(p), 1.0, 0.75, 0.75, function(n: Vector3): Color3
				return scaled(WOOD, 1.06 + 0.16 * math.max(n.Y, 0))
			end)
		end
	end
	for _, r in ipairs(rows(id, "Pupil")) do
		exactRow(m, r)
	end
	exactRow(m, mouth)
	do
		-- the long carved nose from between the eyes down to over the mouth
		local nx = (eyes[1].cf.X + eyes[2].cf.X) / 2
		local top = Vector3.new(nx, eyes[1].cf.Y + 0.8, faceZ - 0.2)
		local tip = Vector3.new(nx + 0.3, mouth.cf.Y + mouth.size.Y / 2 + 1.0, faceZ - 2.6)
		table.insert(U.Face, frustumN(5, 1.1, 0.55, 0, (tip - top).Magnitude, H.frameY(top, tip - top), { scaled(WOOD, 1.1), WOOD, scaled(WOOD, 0.92) }))
		blob(U.Face, rng, CFrame.new(tip), 0.8, 0.7, 0.7, function(n: Vector3): Color3
			return scaled(WOOD, 1.08 + 0.15 * math.max(n.Y, 0))
		end)
		-- crooked lips round today's mouth and 5 pale teeth
		local mcf = mouth.cf
		local LIP = scaled(WOOD, 1.12)
		table.insert(U.Face, H.bar((mcf * CFrame.new(-mouth.size.X / 2 - 0.3, mouth.size.Y / 2 + 0.25, -0.3)).Position, (mcf * CFrame.new(mouth.size.X / 2 + 0.3, mouth.size.Y / 2 + 0.55, -0.3)).Position, 0.7, LIP))
		table.insert(U.Face, H.bar((mcf * CFrame.new(-mouth.size.X / 2 - 0.1, -mouth.size.Y / 2 - 0.3, -0.3)).Position, (mcf * CFrame.new(mouth.size.X / 2 + 0.1, -mouth.size.Y / 2 - 0.05, -0.3)).Position, 0.75, scaled(LIP, 0.92)))
		for k, tx in ipairs({ -2.9, -1.4, 0.4, 2.2, 3.4 }) do
			local up = k % 2 == 1
			local ty = if up then mouth.size.Y / 2 - 0.35 else -mouth.size.Y / 2 + 0.35
			local tcf = mcf * CFrame.new(tx, ty, -0.55) * CFrame.Angles(0, 0, rad((k - 3) * 9))
			table.insert(U.Teeth, piece("WedgePart", Vector3.new(0.75, 0.95, 0.4), tcf * CFrame.Angles(if up then rad(180) else 0, 0, 0), rgb(214, 196, 150)))
		end
		-- the mossy beard under the chin
		for k = 0, 6 do
			local bx = mcf.X - 3.3 + k * 1.1
			ST.mossStrand(U.Moss, rng, Vector3.new(bx, mcf.Y - mouth.size.Y / 2 - 0.7, faceZ - 0.5), rng:NextNumber(1.6, 3.0), if k % 2 == 0 then MOSS_MID else MOSS)
		end
	end
	-- the branches: gnarled arms with thick forks and finer twigs, hanging moss strands
	for i, r in ipairs(limbs) do
		local a, b = r.cf.Position - r.cf.LookVector * r.size.Z / 2, r.cf.Position + r.cf.LookVector * r.size.Z / 2
		if (a - Vector3.new(0, a.Y, 0)).Magnitude > (b - Vector3.new(0, b.Y, 0)).Magnitude then
			a, b = b, a
		end
		ST.gnarledBranch(U.Branches, U.Twigs, rng, a, b, r.size.X / 2 * 0.98, tone(rng, r.color), nil)
		if i % 3 == 0 then
			ST.mossStrand(U.Moss, rng, a:Lerp(b, 0.55) - UP * r.size.X * 0.4, rng:NextNumber(2, 3.5))
		end
	end
	-- the roots: tapered 8-sided roots (today's), buttress fins between them and the trunk, mud collars, moss
	for i, r in ipairs(roots) do
		local a, b = r.cf.Position - r.cf.LookVector * r.size.Z / 2, r.cf.Position + r.cf.LookVector * r.size.Z / 2
		if a.Y < b.Y then
			a, b = b, a -- a: at the trunk (high), b: the foot
		end
		local rr = r.size.X / 2
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		if flat.Z < -0.9 then
			a = a:Lerp(b, 0.55) -- (the root under the face: it starts under the mouth, the face stays clear)
		end
		table.insert(U.Roots, frustumN(8, rr * 1.05, rr * 0.55, -1.5, (b - a).Magnitude + 0.5, H.frameY(a, b - a) * CFrame.Angles(0, i * 0.4, 0), { r.color, scaled(r.color, 1.1), scaled(r.color, 0.88) }))
		blob(U.Roots, rng, CFrame.lookAt(a - UP * 2 + flat * 2.5, a - UP * 2 + flat * 6) , 1.4, 4.2, 4.0, function(n: Vector3): Color3
			return scaled(r.color, 0.92 + 0.15 * math.max(n.Y, 0))
		end)
		ST.mudCollar(U.Mud, rng, Vector3.new(b.X, 0.1, b.Z), rr * 1.1)
		if i % 2 == 0 then
			ST.mossCushion(U.Moss, rng, CFrame.new(a:Lerp(b, 0.45) + UP * rr * 0.8), 2.0)
		end
	end
	-- the window over the lantern: a small arched frame, a warm pane, a sill
	do
		local y = 38
		local rz = math.max(Rr[3] or 5, 5) -- the trunk radius there
		local p = Vector3.new(-3.2, y, -rz - 0.1)
		local wcf = CFrame.lookAt(p, p - Vector3.zAxis)
		table.insert(U.WindowGlow, piece("Part", Vector3.new(2.8, 3.4, 0.3), wcf * CFrame.new(0, 0, 0.12), rgb(255, 196, 96)))
		for _, e in ipairs({ { -1.6, 0, 0.45, 4.2 }, { 1.6, 0, 0.45, 4.2 }, { 0, 2.05, 3.6, 0.45 }, { 0, -2.05, 3.8, 0.5 } }) do
			table.insert(U.Window, chamfered(Vector3.new(e[3], e[4], 0.6), wcf * CFrame.new(e[1], e[2], -0.1), DARKWOOD, { "vertical" }, 0.08))
		end
		table.insert(U.Window, piece("Part", Vector3.new(0.18, 3.3, 0.2), wcf * CFrame.new(0, 0, -0.08), DARKWOOD))
		table.insert(U.Window, piece("Part", Vector3.new(2.7, 0.18, 0.2), wcf * CFrame.new(0, 0.3, -0.08), DARKWOOD))
	end
	-- the nest under the raven on the south branch
	for _, n in ipairs(GD[id].nested) do
		local cf = CFrame.new(table.unpack(n.cf))
		if n.id == "swamp_raven" and cf.Z < -20 then
			local c = cf.Position
			for k = 0, 9 do
				local a0, a1 = k * math.pi / 5, (k + 1.3) * math.pi / 5
				table.insert(U.Nest, H.bar(c + Vector3.new(math.cos(a0) * 1.9, -0.2 + (k % 2) * 0.2, math.sin(a0) * 1.9), c + Vector3.new(math.cos(a1) * 1.9, -0.1, math.sin(a1) * 1.9), 0.3, tone(rng, rgb(104, 80, 54))))
			end
			table.insert(U.Nest, frustumN(8, 1.9, 1.1, -0.7, -0.05, CFrame.new(c), { rgb(84, 64, 44) }))
		end
	end
	-- the swing: today's ropes as rope, today's seat as 2 boards
	for _, r in ipairs(rows(id, "Rope")) do
		local a, b = r.cf.Position - r.cf.LookVector * r.size.Z / 2, r.cf.Position + r.cf.LookVector * r.size.Z / 2
		table.insert(U.Swing, frustumN(6, 0.22, 0.22, 0, (b - a).Magnitude, H.frameY(a, b - a), { rgb(154, 126, 82), rgb(132, 108, 70) }))
	end
	for _, r in ipairs(rows(id, "SwingSeat")) do
		for _, z in ipairs({ -0.65, 0.65 }) do
			table.insert(U.Swing, chamfered(Vector3.new(r.size.X, r.size.Y, r.size.Z / 2 - 0.06), r.cf * CFrame.new(0, 0, z), tone(rng, r.color), { "vertical", "topFrontBack" }, 0.08))
		end
	end
	-- the glowing mushrooms exactly, small ghost mushrooms and moss at the foot
	mushrooms(m, id)
	for _, gp in ipairs({ Vector3.new(-14, 0, 9), Vector3.new(14, 0, 11), Vector3.new(-4, 0, 14) }) do
		ST.ghostMushrooms(U.Mush, rng, gp, 3, 1.1)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, id, U, "Trunk", { WindowGlow = { material = Enum.Material.Neon } })
	nested(m, id)
	rootOver(m)
	colliders(m, id)
	return m
end

---------------------------------------------------------------------
-- 03 FALLEN HOLLOW LOG (Swamp_1 Decor.Landmark, LandmarkName SunkenTrunk: a hollow octagonal trunk of 7 bark slabs 4
-- thick (one side open, a shorter slab over it) about 100 long, lying in the marsh water (its foot under the water),
-- 5 roots at the -X end, 2 branch stubs (all collide; the hollow is walkable), 2 dark Knot discs on the south side (the
-- 2 holes), 2 moss pads, 3 GlowMushroom_B (Neon caps); nested: 3 vine curtains; 124.5 x 67.6 x 84.7; 1 copy)
---------------------------------------------------------------------
-- From today's parts: each bark slab as pale rotten heartwood inside (what players see in the hollow) under an outer
-- bark plate with 4 raised ridges and dark grooves along the trunk; THE BROKEN END (+X): each slab's end as pale end
-- grain with 2 growth-ring lines and splinters; today's 2 holes (the Knots, kept exactly) with a thick bark lip round
-- each so they read as holes; today's 2 stubs as thick branch stubs with broken, splintered tips; today's 5 roots as
-- gnarled roots with twigs at the -X end, mud collars; today's 2 moss pads as soft layered moss (cushions) and more moss
-- along the top; today's 3 glowing mushrooms kept exactly, small ghost mushrooms and ferns along the foot; 3 lily pads
-- (the swamp_lily_pads prop, nested) on the water by the log (the water is the marsh's own). Colliders: today's 14
-- colliding parts (invisible): the hollow stays exactly walkable. Parts: Bark, Heart, Ridges, EndGrain, Lips, Stubs,
-- Roots, Twigs, Mud, Moss, Mush, Ferns, Knot x2, GlowMushroom_B x3, the nested props, Collision
function SL.swamp_hollow_log(): Model
	local id = "swamp_hollow_log"
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(20261603)
	H.setBevelSelf(true)
	local U: any = { Heart = {}, Bark = {}, Ridges = {}, EndGrain = {}, Lips = {}, Stubs = {}, Roots = {}, Twigs = {}, Mud = {}, Moss = {}, Mush = {}, Ferns = {} }
	local all = rows(id)
	local HEART = rgb(122, 96, 70) -- #7A6046 pale rotten heartwood
	local ENDGRAIN = rgb(170, 132, 92)
	for _, r in ipairs(all) do
		if r.name == "Bark" then
			local cf, S = r.cf, r.size
			-- the slab's local Y points out of the trunk (the bark side), X along the trunk
			table.insert(U.Heart, piece("Part", S - Vector3.new(0.1, 1.0, 0.1), cf * CFrame.new(0, -0.5, 0), tone(rng, HEART)))
			table.insert(U.Bark, chamfered(Vector3.new(S.X - 0.2, 1.2, S.Z - 0.1), cf * CFrame.new(0, S.Y / 2 - 0.55, 0), tone(rng, r.color), { "topFrontBack", "topSides" }, 0.25))
			-- 5 bark ridges, each broken into 2-3 lengths of different width and height, dark grooves between
			for k = 0, 4 do
				local z = -S.Z / 2 + (k + 0.5) * S.Z / 5 + rng:NextNumber(-0.5, 0.5)
				local x0 = -S.X / 2 + rng:NextNumber(1, 6)
				local xEnd = S.X / 2 - rng:NextNumber(1, 6)
				while x0 < xEnd - 4 do
					local len = math.min(rng:NextNumber(14, 40), xEnd - x0)
					local w, h = rng:NextNumber(1.2, 2.3), rng:NextNumber(0.4, 0.95)
					table.insert(U.Ridges, chamfered(Vector3.new(len, h, w), cf * CFrame.new(x0 + len / 2, S.Y / 2 + h / 2 - 0.05, z + rng:NextNumber(-0.3, 0.3)), scaled(r.color, rng:NextNumber(1.05, 1.22)), { "topFrontBack", "topSides" }, math.min(0.3, h * 0.45)))
					x0 += len + rng:NextNumber(1.5, 4)
				end
				table.insert(U.Ridges, piece("Part", Vector3.new(S.X - 3, 0.3, 0.4), cf * CFrame.new(0, S.Y / 2 + 0.08, z + S.Z / 10), scaled(r.color, 0.5)))
			end
			-- the broken end (+X): end grain with growth rings and splinters; the -X end plain
			local e = cf * CFrame.new(S.X / 2 + 0.06, 0, 0)
			table.insert(U.EndGrain, piece("Part", Vector3.new(0.15, S.Y - 0.1, S.Z - 0.2), e, ENDGRAIN))
			for _, dy in ipairs({ -0.6, 0.7 }) do
				table.insert(U.EndGrain, piece("Part", Vector3.new(0.2, 0.18, S.Z * 0.7), e * CFrame.new(0.02, dy, rng:NextNumber(-1, 1)), scaled(ENDGRAIN, 0.7)))
			end
			for k = 1, 3 do
				local sp = e * CFrame.new(0.4, S.Y / 2 - 0.4, -S.Z / 2 + k * S.Z / 4)
				TB.splinters(U.EndGrain, rng, sp.Position, cf.XVector, 0.9, scaled(r.color, 1.1))
			end
		end
	end
	-- the holes: today's knots exactly, a thick bark lip round each
	for _, r in ipairs(rows(id, "Knot")) do
		exactRow(m, r)
		local axis = r.cf.XVector
		local R = r.size.Y / 2
		local out = if axis:Dot(Vector3.new(r.cf.X, 0, r.cf.Z)) >= 0 then axis else -axis
		SM.ring(U.Lips, r.cf.Position + out * 0.45, out, R + 0.45, 1.1, 12, rgb(84, 62, 44))
		SM.ring(U.Lips, r.cf.Position + out * 0.3, out, R + 1.3, 0.8, 14, rgb(70, 52, 38))
	end
	-- the stubs: thick branch stubs with broken, splintered tips
	for _, r in ipairs(rows(id, "Stub")) do
		local a, b = r.cf.Position - r.cf.LookVector * r.size.Z / 2, r.cf.Position + r.cf.LookVector * r.size.Z / 2
		if a.Y > b.Y then
			a, b = b, a
		end
		local rr = r.size.X / 2
		table.insert(U.Stubs, frustumN(8, rr * 1.04, rr * 0.86, -1, (b - a).Magnitude, H.frameY(a, b - a) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { r.color, scaled(r.color, 1.1), scaled(r.color, 0.88) }))
		table.insert(U.EndGrain, frustumN(8, rr * 0.7, rr * 0.7, -0.1, 0.12, H.frameY(b, b - a), { ENDGRAIN }))
		TB.splinters(U.Stubs, rng, b, (b - a).Unit, rr * 0.9, scaled(r.color, 1.15))
		ST.mossCushion(U.Moss, rng, CFrame.new(a:Lerp(b, 0.3) + UP * rr * 0.8), 2.2)
	end
	-- the roots: gnarled roots with twigs, mud collars
	for _, r in ipairs(rows(id, "Root")) do
		local a, b = r.cf.Position - r.cf.LookVector * r.size.Z / 2, r.cf.Position + r.cf.LookVector * r.size.Z / 2
		if (Vector3.new(a.X, 0, a.Z)).Magnitude > (Vector3.new(b.X, 0, b.Z)).Magnitude then
			a, b = b, a -- a: at the trunk
		end
		ST.gnarledBranch(U.Roots, U.Twigs, rng, a, b, r.size.X / 2 * 1.02, tone(rng, r.color), nil)
		if b.Y < 2 then
			ST.mudCollar(U.Mud, rng, Vector3.new(b.X, -0.3, b.Z), 2.4)
		end
	end
	-- the moss: today's 2 pads as layered cushions, more along the top
	for _, r in ipairs(rows(id, "Moss")) do
		for k = 0, 3 do
			local p = r.cf * CFrame.new((k - 1.5) * r.size.X * 0.24, 0.1, rng:NextNumber(-1.5, 1.5))
			ST.mossCushion(U.Moss, rng, p, r.size.Z * rng:NextNumber(0.35, 0.5))
		end
	end
	for _, r in ipairs(all) do
		if r.name == "Bark" and r.cf.YVector.Y > 0.6 then
			for k = 1, 6 do
				local p = r.cf * CFrame.new(-r.size.X / 2 + k * r.size.X / 7 + rng:NextNumber(-3, 3), r.size.Y / 2 + 0.6, rng:NextNumber(-4, 4))
				ST.mossCushion(U.Moss, rng, p, rng:NextNumber(3, 5))
				if k % 2 == 0 then
					local edge = r.cf * CFrame.new(-r.size.X / 2 + k * r.size.X / 7, r.size.Y / 2, (if k % 4 == 0 then 1 else -1) * (r.size.Z / 2 - 0.3))
					ST.mossStrand(U.Moss, rng, edge.Position, rng:NextNumber(1.5, 3))
				end
			end
		end
	end
	-- today's glowing mushrooms exactly; small ghost mushrooms and ferns along the foot
	mushrooms(m, id)
	for _, gp in ipairs({ Vector3.new(-2, -0.4, -22), Vector3.new(28, -0.4, -19), Vector3.new(-28, -0.4, -22), Vector3.new(20, -0.4, 22) }) do
		ST.ghostMushrooms(U.Mush, rng, gp, 3, 1.0)
		ST.fern(U.Ferns, rng, gp + Vector3.new(2.2, 0, 1.2), 5, 2.6)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, id, U, "Bark")
	nested(m, id)
	-- 3 lily pads (the swamp_lily_pads prop) on the water by the log
	local t = ServerStorage.MapProps:FindFirstChild("swamp_lily_pads")
	if t then
		for i, lp in ipairs({ { 30, -32, 0.4 }, { 40, -26, 2.1 }, { -40, -32, 4.0 } }) do
			local c = t:Clone() :: Model
			c.Name = "LilyPads"
			c:ScaleTo(1.0)
			c:PivotTo(CFrame.new(lp[1], -0.48, lp[2]) * CFrame.Angles(0, lp[3], 0))
			c:AddTag("MapProp")
			c:SetAttribute("MapPropId", "swamp_lily_pads")
			c:SetAttribute("MapPropVersion", tostring(t:GetAttribute("MapPropVersion") or "?") .. "|")
			c.Parent = m
		end
	end
	rootOver(m)
	colliders(m, id)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
SL.BUILDERS = { swamp_witch_tower = true, swamp_horror_tree = true, swamp_hollow_log = true }
for bid in pairs(SL.BUILDERS) do
	B2[bid] = (SL :: any)[bid]
	B2.BUILDERS[bid] = true
end
SL.install = B2.install
SL.stats = B2.stats

return SL
