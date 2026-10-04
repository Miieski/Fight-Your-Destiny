--[[
	BuildKit - shared helpers for map building in Studio (dev tool, Edit mode only).
	Lives in the place at ServerStorage.DevTools.BuildKit; tools/BuildKit.luau is the source of truth.
	Usage (execute_luau, Edit):  local Kit = require(game.ServerStorage.DevTools.BuildKit)
	Rules and layout: docs/AGENT_BRIEF.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local EnemiesConfig = require(ReplicatedStorage.GameSystem.Config.Enemies)

local Kit = {}

local SMOOTH = Enum.SurfaceType.Smooth
local rgb = Color3.fromRGB

---------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------
Kit.SUBZONE_SIZE = 250
Kit.SUBZONE_PITCH = 290 -- 250 + 40 studs of gate corridor
Kit.Zones = Zones
Kit.ZONE_SPACING = 2000
Kit.ZONE_X = {} -- Plains 2000, Desert 4000, Jungle 6000 ... Void 24000
for _, zone in ipairs(Zones.List) do
	Kit.ZONE_X[zone.Id] = zone.Index * Kit.ZONE_SPACING
end
Kit.HUB_CENTER = Vector3.new(0, 0, 0)

-- Center of sub-zone n at ground level (Y = 0).
function Kit.center(zoneId: string, n: number): Vector3
	return Vector3.new(Kit.ZONE_X[zoneId], 0, (n - 1) * Kit.SUBZONE_PITCH)
end

function Kit.subZone(zoneId: string, n: number): Folder
	return workspace.Zones[zoneId][`{zoneId}_{n}`]
end

-- Staging position of a zone's boss arena (arena floor center) while it is being built.
function Kit.arenaCenter(zoneId: string): Vector3
	return Vector3.new(Kit.ZONE_X[zoneId], 0, -600)
end

-- Enemy ids per sub-zone and per boss room, from the game config.
Kit.Enemies = {}
for subZoneId, list in pairs(EnemiesConfig.BySubZone) do
	local ids = {}
	for _, enemy in ipairs(list) do
		table.insert(ids, enemy.Id)
	end
	Kit.Enemies[subZoneId] = ids
end
Kit.Bosses = {}
for zoneId, room in pairs(EnemiesConfig.BossRoom) do
	Kit.Bosses[zoneId] = { Boss = room.Boss.Id, Mini1 = room.Mini1.Id, Mini2 = room.Mini2.Id }
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }
local function abbreviate(value: number): string
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	return (string.gsub(string.format("%.2f", value), "%.?0+$", "")) .. SUFFIXES[index]
end
-- Placeholder sign text only; the game code overwrites it from Config.
Kit.GatePriceText = {}
for _, zone in ipairs(Zones.List) do
	for n = 2, Zones.SUBZONE_COUNT do
		Kit.GatePriceText[Zones.subZoneId(zone.Id, n)] = abbreviate(Zones.subZonePrice(zone.Id, n))
	end
end

---------------------------------------------------------------------
-- Palette (flat, saturated low-poly colors; see the reference images in docs/)
---------------------------------------------------------------------
Kit.Palette = {
	Common = {
		Wood = rgb(168, 98, 56), WoodDark = rgb(112, 62, 38), WoodLight = rgb(214, 150, 92),
		LogEnd = rgb(236, 200, 96), Stone = rgb(150, 156, 168), StoneDark = rgb(104, 110, 124),
		StoneBlue = rgb(112, 128, 204), Iron = rgb(92, 98, 110), Gold = rgb(255, 201, 60),
		Diamond = rgb(95, 212, 255), Cloth = rgb(232, 226, 208), White = rgb(245, 246, 250),
		Lantern = rgb(255, 214, 120), Fire = rgb(255, 140, 40), Rope = rgb(196, 160, 104),
	},
	Hub = {
		Grass = rgb(98, 208, 64), Path = rgb(226, 200, 150), Plaza = rgb(206, 196, 178),
		PlazaDark = rgb(160, 150, 136), Roof = rgb(196, 64, 58), RoofBlue = rgb(64, 120, 212),
		Wall = rgb(240, 228, 200), Timber = rgb(112, 62, 38), Water = rgb(52, 214, 236),
		Banner = rgb(212, 52, 60), BannerAlt = rgb(74, 108, 220), Portal = rgb(150, 110, 255),
	},
	Plains = {
		Grass = rgb(88, 204, 52), GrassDark = rgb(60, 168, 48), GrassLight = rgb(140, 224, 84),
		Dirt = rgb(176, 124, 78), Path = rgb(218, 184, 128), Sand = rgb(244, 226, 160),
		SandWet = rgb(222, 198, 132), Water = rgb(40, 216, 236), WaterDeep = rgb(30, 160, 214),
		Leaf = rgb(72, 176, 62), LeafDark = rgb(40, 124, 58), Pine = rgb(36, 104, 62),
		PineLight = rgb(64, 140, 78), Trunk = rgb(128, 78, 48), Palm = rgb(88, 190, 80),
		Mountain = rgb(150, 92, 66), MountainDark = rgb(116, 70, 54), Snow = rgb(244, 246, 250),
		Rock = rgb(150, 156, 168), RockBlue = rgb(112, 128, 204), Flower1 = rgb(255, 92, 120),
		Flower2 = rgb(255, 214, 70), Flower3 = rgb(160, 110, 255), Mushroom = rgb(232, 72, 72),
		CaveRock = rgb(96, 92, 110), CaveRockDark = rgb(62, 60, 78), Ore = rgb(90, 230, 255),
		OreGold = rgb(255, 196, 60), Moss = rgb(104, 168, 72), Web = rgb(232, 236, 240),
	},
	Desert = {
		Sand = rgb(244, 208, 124), SandLight = rgb(252, 226, 160), SandDark = rgb(214, 168, 96),
		Dune = rgb(236, 186, 104), Terracotta = rgb(204, 96, 62), CanyonRed = rgb(196, 84, 56),
		CanyonDark = rgb(150, 62, 48), CanyonLight = rgb(228, 128, 80), Sandstone = rgb(226, 190, 132),
		SandstoneDark = rgb(184, 146, 98), Clay = rgb(222, 164, 110), Water = rgb(48, 214, 208),
		Cactus = rgb(76, 164, 84), Palm = rgb(96, 186, 76), Trunk = rgb(150, 104, 64),
		DeadWood = rgb(158, 132, 104), Bone = rgb(240, 232, 208), Tent = rgb(214, 74, 62),
		TentAlt = rgb(60, 150, 170), Gold = rgb(255, 201, 60), Lapis = rgb(44, 92, 200),
		PyramidWall = rgb(204, 160, 100), PyramidDark = rgb(140, 104, 68), Turquoise = rgb(64, 208, 196),
	},
	Jungle = {
		Grass = rgb(52, 156, 60), GrassDark = rgb(32, 112, 54), GrassLight = rgb(96, 196, 72),
		Leaf = rgb(40, 150, 66), LeafDark = rgb(22, 100, 56), LeafLight = rgb(120, 210, 70),
		Trunk = rgb(104, 68, 44), TrunkDark = rgb(74, 48, 34), Vine = rgb(70, 170, 60),
		Dirt = rgb(128, 88, 56), Mud = rgb(98, 70, 48), Water = rgb(48, 196, 190),
		WaterDeep = rgb(30, 140, 150), Stone = rgb(132, 138, 124), StoneDark = rgb(92, 100, 92),
		Moss = rgb(88, 150, 66), Gold = rgb(255, 201, 60), Glyph = rgb(120, 255, 190),
		Flower1 = rgb(255, 80, 140), Flower2 = rgb(255, 170, 40), Flower3 = rgb(190, 90, 255),
		Bamboo = rgb(150, 200, 80), Totem = rgb(196, 70, 50), TotemAlt = rgb(60, 170, 190),
	},
}

Kit.Palette.Tundra = {
	Snow = rgb(244, 248, 255), SnowShade = rgb(206, 222, 246), Ice = rgb(150, 214, 250), IceDeep = rgb(84, 160, 232),
	IceDark = rgb(52, 104, 180), Frost = rgb(214, 236, 255), PalePurple = rgb(186, 170, 236), Pine = rgb(30, 86, 72),
	PineSnow = rgb(226, 238, 248), Trunk = rgb(92, 66, 54), Rock = rgb(118, 128, 150), RockDark = rgb(78, 86, 110),
	Wood = rgb(134, 92, 66), Aurora = rgb(110, 255, 200), BlueFlame = rgb(96, 190, 255), Water = rgb(70, 150, 214),
}
Kit.Palette.Swamp = {
	Mud = rgb(92, 76, 50), MudDark = rgb(64, 52, 38), Moss = rgb(92, 130, 58), MossDark = rgb(56, 90, 46),
	Water = rgb(78, 112, 70), WaterDeep = rgb(48, 78, 56), Bark = rgb(78, 58, 44), BarkDark = rgb(50, 38, 32),
	DeadLeaf = rgb(128, 120, 62), Reed = rgb(140, 150, 74), Magic = rgb(170, 80, 255), MagicDark = rgb(98, 44, 160),
	Firefly = rgb(255, 232, 96), Toxic = rgb(140, 255, 90), Wood = rgb(104, 76, 52), Lantern = rgb(255, 196, 96),
	MushroomGlow = rgb(120, 255, 210), Bone = rgb(222, 214, 190),
}
Kit.Palette.Volcano = {
	Basalt = rgb(52, 48, 54), BasaltDark = rgb(30, 28, 34), BasaltLight = rgb(84, 78, 84), Ash = rgb(128, 124, 126),
	AshLight = rgb(170, 164, 162), Lava = rgb(255, 120, 30), LavaHot = rgb(255, 208, 70), LavaCrust = rgb(150, 40, 20),
	RedGlow = rgb(255, 60, 40), Obsidian = rgb(24, 20, 34), Ember = rgb(255, 170, 60), DeadWood = rgb(70, 56, 50),
	Iron = rgb(98, 96, 104), Crystal = rgb(255, 70, 70), Wood = rgb(110, 72, 52), Steam = rgb(232, 232, 232),
}
Kit.Palette.Hell = {
	Ground = rgb(96, 28, 30), GroundDark = rgb(52, 16, 22), Black = rgb(26, 14, 18), Red = rgb(200, 36, 40),
	Blood = rgb(140, 20, 30), Lava = rgb(255, 110, 30), LavaHot = rgb(255, 200, 80), Orange = rgb(232, 96, 30),
	Bone = rgb(226, 214, 190), Obsidian = rgb(28, 20, 34), Purple = rgb(140, 60, 200), Tile = rgb(110, 34, 36),
	TileBorder = rgb(160, 48, 44), Iron = rgb(70, 60, 64), Banner = rgb(180, 24, 40), Ember = rgb(255, 150, 60),
}
Kit.Palette.Heaven = {
	Cloud = rgb(250, 250, 255), CloudShade = rgb(222, 232, 250), Marble = rgb(242, 240, 234), MarbleShade = rgb(214, 210, 204),
	Gold = rgb(255, 208, 84), GoldDark = rgb(214, 160, 50), SkyBlue = rgb(150, 208, 255), Pink = rgb(255, 196, 220),
	Grass = rgb(150, 226, 120), GrassLight = rgb(196, 240, 150), LeafGold = rgb(255, 232, 150), Trunk = rgb(236, 226, 206),
	Water = rgb(140, 224, 255), Light = rgb(255, 250, 220), Crystal = rgb(190, 240, 255), Banner = rgb(120, 170, 255),
}
Kit.Palette.Dead = {
	Ground = rgb(72, 78, 90), GroundDark = rgb(46, 50, 62), Stone = rgb(120, 126, 138), StoneDark = rgb(76, 80, 94),
	Bone = rgb(232, 226, 206), BoneShade = rgb(190, 184, 166), NightBlue = rgb(40, 56, 104), Ghost = rgb(120, 255, 190),
	GhostDim = rgb(70, 170, 140), DeadWood = rgb(64, 58, 60), Iron = rgb(58, 60, 70), Candle = rgb(255, 214, 140),
	Carpet = rgb(96, 30, 52), Black = rgb(24, 24, 32), Moss = rgb(74, 98, 78), Glass = rgb(110, 90, 200),
}
Kit.Palette.Abyss = {
	Sand = rgb(226, 214, 170), SandDeep = rgb(120, 140, 150), Turquoise = rgb(60, 216, 210), DeepBlue = rgb(24, 70, 150),
	Abyss = rgb(12, 22, 52), Black = rgb(8, 12, 26), Coral1 = rgb(255, 100, 130), Coral2 = rgb(255, 160, 60),
	Coral3 = rgb(180, 100, 255), Kelp = rgb(50, 150, 110), NeonCyan = rgb(60, 255, 250), NeonPink = rgb(255, 80, 200),
	WreckWood = rgb(96, 74, 62), Rust = rgb(150, 84, 54), Gold = rgb(255, 208, 84), PalaceStone = rgb(160, 196, 200),
	Rock = rgb(60, 84, 110), Bone = rgb(214, 220, 214),
}
Kit.Palette.Mechanical = {
	Steel = rgb(130, 138, 150), SteelDark = rgb(76, 82, 94), SteelLight = rgb(178, 186, 198), Black = rgb(26, 28, 34),
	Rust = rgb(156, 86, 50), NeonCyan = rgb(60, 240, 255), NeonOrange = rgb(255, 140, 40), Warning = rgb(255, 212, 40),
	Alarm = rgb(255, 50, 50), Sludge = rgb(110, 230, 60), SludgeDark = rgb(60, 140, 50), Glass = rgb(120, 200, 230),
	Copper = rgb(196, 120, 70), Floor = rgb(92, 96, 106), Belt = rgb(44, 46, 54), Screen = rgb(40, 120, 220),
}
Kit.Palette.Void = {
	Black = rgb(14, 10, 24), Obsidian = rgb(28, 20, 46), Purple = rgb(90, 40, 170), PurpleDeep = rgb(52, 24, 104),
	Magenta = rgb(255, 60, 220), MagentaDim = rgb(170, 50, 170), PaleStone = rgb(222, 214, 196), PaleStoneShade = rgb(176, 170, 164),
	Crystal = rgb(200, 120, 255), CrystalLight = rgb(236, 190, 255), Star = rgb(250, 244, 255), Ground = rgb(40, 30, 62),
	Lantern = rgb(210, 130, 255), Rift = rgb(120, 60, 255),
}

---------------------------------------------------------------------
-- Parts
---------------------------------------------------------------------
local function make(className: string, props: { [string]: any }?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

function Kit.part(props) return make("Part", props) end
function Kit.wedge(props) return make("WedgePart", props) end
function Kit.cornerWedge(props) return make("CornerWedgePart", props) end
function Kit.cyl(props)
	props.Shape = Enum.PartType.Cylinder
	return make("Part", props)
end
function Kit.ball(props)
	props.Shape = Enum.PartType.Ball
	return make("Part", props)
end

-- Small random brightness change so neighbouring facets read as separate faces.
function Kit.shade(color: Color3, amount: number?, rng: Random?): Color3
	local h, s, v = color:ToHSV()
	local d = (rng or Random.new()):NextNumber(-(amount or 0.06), amount or 0.06)
	return Color3.fromHSV(h, s, math.clamp(v + d, 0, 1))
end

-- Pure decoration: no collision, no queries, no shadow (cheap). Use for grass tufts, flowers, small props.
function Kit.decorOnly(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanTouch, d.CanQuery, d.CastShadow = false, false, false, false
		end
	end
	if inst:IsA("BasePart") then
		inst.CanCollide, inst.CanTouch, inst.CanQuery, inst.CastShadow = false, false, false, false
	end
end

-- Fills triangle abc with two wedges (faceted low-poly surface). The top face lies on the triangle.
function Kit.tri(a: Vector3, b: Vector3, c: Vector3, parent: Instance, color: Color3, thickness: number?, material: Enum.Material?)
	local t = thickness or 1
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-3 then
		return nil
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local normal = if right.Y < 0 then -right else right
	local offset = normal * (-t / 2)
	local w1 = Kit.wedge({
		Size = Vector3.new(t, height, math.abs(ab:Dot(back))),
		CFrame = CFrame.fromMatrix((a + b) / 2 + offset, right, up, back),
		Color = color, Material = material, Name = "Facet", Parent = parent,
	})
	local w2 = Kit.wedge({
		Size = Vector3.new(t, height, math.abs(ac:Dot(back))),
		CFrame = CFrame.fromMatrix((a + c) / 2 + offset, -right, up, -back),
		Color = color, Material = material, Name = "Facet", Parent = parent,
	})
	return w1, w2
end

--[[
	Faceted height field (hills, dunes, cliffs, mountains).
	opts = {
		origin = Vector3 (corner with the smallest X and Z; Y is the base height),
		cellsX = number, cellsZ = number, cell = number (studs per cell),
		height = function(ix, iz, x, z) -> number   (ix 0..cellsX, iz 0..cellsZ; height above origin.Y),
		color = Color3 | function(avgY, normalY) -> Color3,
		parent = Instance, thickness = number?, jitter = number? (0..0.4, fraction of a cell), seed = number?,
		shade = number? (default 0.05), material = Enum.Material?,
		skip = function(ix, iz) -> boolean?   (true = leave this cell empty)
	}
	Returns the number of parts created. A 10 x 10 field is about 400 wedges: use it for the hilly
	parts only and one large Part for flat ground.
]]
function Kit.heightfield(opts): number
	local rng = Random.new(opts.seed or 1)
	local cell, jitter = opts.cell, opts.jitter or 0
	local verts = {}
	for ix = 0, opts.cellsX do
		verts[ix] = {}
		for iz = 0, opts.cellsZ do
			local x, z = ix * cell, iz * cell
			local edge = ix == 0 or iz == 0 or ix == opts.cellsX or iz == opts.cellsZ
			if jitter > 0 and not edge then
				x += rng:NextNumber(-jitter, jitter) * cell
				z += rng:NextNumber(-jitter, jitter) * cell
			end
			local wx, wz = opts.origin.X + x, opts.origin.Z + z
			verts[ix][iz] = Vector3.new(wx, opts.origin.Y + opts.height(ix, iz, wx, wz), wz)
		end
	end
	local count = 0
	local function facet(a, b, c)
		local color = opts.color
		if typeof(color) == "function" then
			local n = (b - a):Cross(c - a)
			color = color((a.Y + b.Y + c.Y) / 3 - opts.origin.Y, if n.Magnitude > 0 then math.abs(n.Unit.Y) else 1)
		end
		if Kit.tri(a, b, c, opts.parent, Kit.shade(color, opts.shade or 0.05, rng), opts.thickness or 2, opts.material) then
			count += 2
		end
	end
	for ix = 0, opts.cellsX - 1 do
		for iz = 0, opts.cellsZ - 1 do
			if not (opts.skip and opts.skip(ix, iz)) then
				local v00, v10 = verts[ix][iz], verts[ix + 1][iz]
				local v01, v11 = verts[ix][iz + 1], verts[ix + 1][iz + 1]
				if (ix + iz) % 2 == 0 then
					facet(v00, v10, v11)
					facet(v00, v11, v01)
				else
					facet(v00, v10, v01)
					facet(v10, v11, v01)
				end
			end
		end
	end
	return count
end

---------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------
-- Ground hit below (x, z). Markers (no collision, CanQuery false) and invisible parts such as the
-- Bounds walls are skipped, so the result is the visible ground or prop.
function Kit.ground(x: number, z: number, ignore: { Instance }?, fromY: number?): (Vector3?, BasePart?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = table.clone(ignore or {})
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignored
		local hit = workspace:Raycast(Vector3.new(x, fromY or 300, z), Vector3.new(0, -700, 0), params)
		if not hit then
			return nil, nil
		end
		if hit.Instance.Transparency < 1 then
			return hit.Position, hit.Instance :: BasePart
		end
		table.insert(ignored, hit.Instance)
	end
	return nil, nil
end

-- Finds a kit asset: Kit.asset("Common/PineTree") -> ServerStorage.MapAssets.Common.PineTree
function Kit.asset(path: string): Instance
	local node: Instance = ServerStorage.MapAssets
	for _, name in ipairs(string.split(path, "/")) do
		local nextNode = node:FindFirstChild(name)
		assert(nextNode, `MapAssets/{path} not found (missing "{name}")`)
		node = nextNode
	end
	return node
end

--[[
	Scatters clones of kit models on the ground.
	opts = {
		templates = { Model | BasePart } (picked at random), parent = Instance, count = number,
		center = Vector3, size = Vector2 (X, Z extent) | radius = number,
		minSpacing = number?, scale = { min, max }?, sink = number? (studs pushed into the ground),
		avoid = { { pos = Vector3, radius = number } }?   (keep clear: Entrance, spawn groups, paths, gates),
		on = function(hitPart: BasePart, hitPos: Vector3) -> boolean?   (return false to reject the spot),
		seed = number?, yaw = boolean? (default true), decor = boolean? (true = Kit.decorOnly on each clone)
	}
	Returns the list of placed clones.
]]
function Kit.scatter(opts): { Instance }
	local rng = Random.new(opts.seed or 1)
	local placed, positions = {}, {}
	local tries = 0
	while #placed < opts.count and tries < opts.count * 30 do
		tries += 1
		local x, z
		if opts.radius then
			local r, a = opts.radius * math.sqrt(rng:NextNumber()), rng:NextNumber(0, math.pi * 2)
			x, z = opts.center.X + r * math.cos(a), opts.center.Z + r * math.sin(a)
		else
			x = opts.center.X + rng:NextNumber(-0.5, 0.5) * opts.size.X
			z = opts.center.Z + rng:NextNumber(-0.5, 0.5) * opts.size.Y
		end
		local ok = true
		for _, zone in ipairs(opts.avoid or {}) do
			if (Vector2.new(x - zone.pos.X, z - zone.pos.Z)).Magnitude < zone.radius then
				ok = false
				break
			end
		end
		if ok and opts.minSpacing then
			for _, p in ipairs(positions) do
				if (Vector2.new(x - p.X, z - p.Z)).Magnitude < opts.minSpacing then
					ok = false
					break
				end
			end
		end
		if ok then
			local pos, hitPart = Kit.ground(x, z, placed)
			if pos and hitPart and (not opts.on or opts.on(hitPart, pos) ~= false) then
				local clone = opts.templates[rng:NextInteger(1, #opts.templates)]:Clone()
				clone.Parent = opts.parent -- Model:ScaleTo only works once the model is in the DataModel
				if opts.scale and clone:IsA("Model") then
					clone:ScaleTo(rng:NextNumber(opts.scale[1], opts.scale[2]))
				elseif opts.scale and clone:IsA("BasePart") then
					clone.Size *= rng:NextNumber(opts.scale[1], opts.scale[2])
				end
				local yaw = if opts.yaw == false then 0 else rng:NextNumber(0, math.pi * 2)
				local at = CFrame.new(pos - Vector3.new(0, opts.sink or 0.3, 0)) * CFrame.Angles(0, yaw, 0)
				if clone:IsA("Model") then
					-- Kit models have their pivot at the bottom center.
					clone:PivotTo(at)
				else
					(clone :: BasePart).CFrame = at * CFrame.new(0, (clone :: BasePart).Size.Y / 2, 0)
				end
				if opts.decor then
					Kit.decorOnly(clone)
				end
				clone.Parent = opts.parent
				table.insert(placed, clone)
				table.insert(positions, Vector3.new(x, 0, z))
			end
		end
	end
	return placed
end

---------------------------------------------------------------------
-- Contract markers (DESIGN.md section 12)
---------------------------------------------------------------------
local function markerPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	return Kit.part({
		Name = name, Size = size, CFrame = cf, Transparency = 1, CanCollide = false,
		CanTouch = false, CanQuery = false, CastShadow = false, Parent = parent,
	}) :: Part
end
Kit.marker = markerPart

-- Enemy spawn point. Put it ON the ground (pos = ground surface). Names: Spawn_<enemyId>_<i>.
function Kit.spawn(zoneId: string, n: number, enemyId: string, pos: Vector3): Part
	local spawns = Kit.subZone(zoneId, n).Spawns
	local index = 1
	while spawns:FindFirstChild(`Spawn_{enemyId}_{index}`) do
		index += 1
	end
	local p = markerPart(`Spawn_{enemyId}_{index}`, Vector3.new(4, 1, 4), CFrame.new(pos + Vector3.new(0, 0.5, 0)), spawns)
	p:SetAttribute("EnemyId", enemyId)
	return p
end

--[[
	Turns a built gate Model into a contract Gate for sub-zone <zoneId>_<n> (n = 2..4).
	The model must contain a BasePart named "Barrier" (the collidable wall that blocks the passage).
	Adds/updates the price sign: a part named "PriceSign" gets a SurfaceGui with a TextLabel "PriceLabel".
]]
function Kit.finishGate(model: Model, zoneId: string, n: number)
	local id = `{zoneId}_{n}`
	local barrier = model:FindFirstChild("Barrier", true)
	assert(barrier and barrier:IsA("BasePart"), "Gate needs a BasePart named Barrier")
	barrier.Anchored, barrier.CanCollide = true, true
	model.Name = "Gate"
	model.PrimaryPart = barrier
	model:SetAttribute("SubZoneId", id)
	local sign = model:FindFirstChild("PriceSign", true)
	assert(sign and sign:IsA("BasePart"), "Gate needs a BasePart named PriceSign")
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local guiName = "PriceGui" .. face.Name
		local gui = sign:FindFirstChild(guiName) or Instance.new("SurfaceGui")
		gui.Name = guiName
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui:ClearAllChildren()
		local label = Instance.new("TextLabel")
		label.Name = "PriceLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fantasy
		label.TextScaled = true
		label.TextColor3 = Kit.Palette.Common.Gold
		label.Text = (Kit.GatePriceText[id] or "?") .. " Gold"
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = rgb(40, 24, 12)
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = sign
	end
	model.Parent = Kit.subZone(zoneId, n)
	-- Invisible lid above the Barrier: the opening stays closed whatever the jump height.
	local bounds = Kit.subZone(zoneId, n).Bounds
	local lid = bounds:FindFirstChild("GateLid") or Kit.part({ Name = "GateLid", Parent = bounds })
	lid.Size = Vector3.new(barrier.Size.X, 84, math.max(barrier.Size.Z, 2))
	lid.CFrame = barrier.CFrame * CFrame.new(0, barrier.Size.Y / 2 + 42, 0)
	lid.Transparency, lid.CanCollide, lid.CanTouch, lid.CastShadow = 1, true, false, false
end

--[[
	Decorative entrance arch of sub-zone 1 (free: no Barrier, no price). The model needs a BasePart
	named "NameSign"; it shows the zone name on both sides. Place the arch just north of the Entrance.
]]
function Kit.finishArch(model: Model, zoneId: string)
	local sign = model:FindFirstChild("NameSign", true)
	assert(sign and sign:IsA("BasePart"), "EntryArch needs a BasePart named NameSign")
	assert(not model:FindFirstChild("Barrier", true), "EntryArch must not have a Barrier")
	model.Name = "EntryArch"
	model:SetAttribute("ZoneId", zoneId)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local guiName = "NameGui" .. face.Name
		local gui = sign:FindFirstChild(guiName) or Instance.new("SurfaceGui")
		gui.Name = guiName
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui:ClearAllChildren()
		local label = Instance.new("TextLabel")
		label.Name = "NameLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fantasy
		label.TextScaled = true
		label.TextColor3 = Kit.Palette.Common.White
		label.Text = Zones.ById[zoneId].Name
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = rgb(40, 24, 12)
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = sign
	end
	model.Parent = Kit.subZone(zoneId, 1)
end

-- A Model with a BasePart "Interact" becomes an interactable station / boss gate (ProximityPrompt inside).
function Kit.addInteract(model: Model, actionText: string, objectText: string): ProximityPrompt
	local part = model:FindFirstChild("Interact", true)
	assert(part and part:IsA("BasePart"), "Model needs a BasePart named Interact")
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

---------------------------------------------------------------------
-- Toolbox hygiene (HANDOFF.md section 3)
---------------------------------------------------------------------
local STRIP = {
	"LuaSourceContainer", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent",
	"BindableFunction", "ValueBase", "LayerCollector", "ClickDetector", "ProximityPrompt", "Sound",
	"Tool", "Humanoid", "BodyMover", "Constraint", "TouchTransmitter", "Camera", "Explosion", "ForceField",
	"Animation", "AnimationController", "Animator", "PackageLink",
}
-- Removes everything that is not geometry/looks from an inserted Toolbox asset, anchors it and
-- returns a report. Suspicious script content is listed so it can be reported, then removed too.
function Kit.sanitize(root: Instance): string
	local removed, suspicious = {}, {}
	for _, d in ipairs(root:GetDescendants()) do
		for _, className in ipairs(STRIP) do
			if d:IsA(className) then
				if d:IsA("LuaSourceContainer") then
					local ok, source = pcall(function() return (d :: any).Source end)
					if ok and (string.find(source, "require%s*%(%s*%d") or string.find(source, "getfenv") or string.find(source, "loadstring") or string.find(source, "MarketplaceService")) then
						table.insert(suspicious, d:GetFullName())
					end
				end
				removed[d.ClassName] = (removed[d.ClassName] or 0) + 1
				d:Destroy()
				break
			end
		end
	end
	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			parts += 1
		end
	end
	if root:IsA("BasePart") then
		root.Anchored = true
	end
	local list = {}
	for className, n in pairs(removed) do
		table.insert(list, `{className} x{n}`)
	end
	return `sanitized {root.Name}: {parts} parts; removed [{table.concat(list, ", ")}]; suspicious scripts: [{table.concat(suspicious, ", ")}]`
end

---------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------
local function countParts(root: Instance): (number, number, number)
	local parts, unanchored, scripts = 0, 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if not d.Anchored then
				unanchored += 1
			end
		elseif d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	return parts, unanchored, scripts
end

-- Checks one zone against the world contract. Returns a text report; lines starting with FAIL must be fixed.
function Kit.validateZone(zoneId: string): string
	local out = {}
	local function fail(msg) table.insert(out, "FAIL " .. msg) end
	for n = 1, 4 do
		local id = `{zoneId}_{n}`
		local sf = workspace.Zones[zoneId]:FindFirstChild(id)
		if not sf then
			fail(id .. " folder missing")
			continue
		end
		local area, entrance, spawns = sf:FindFirstChild("Area"), sf:FindFirstChild("Entrance"), sf:FindFirstChild("Spawns")
		if not (area and area:IsA("BasePart")) then fail(id .. " Area missing") end
		if not (entrance and entrance:IsA("BasePart")) then
			fail(id .. " Entrance missing")
		else
			if entrance.CFrame.LookVector.Z < 0.9 then
				fail(id .. " Entrance must face +Z: CFrame.lookAt(pos, pos + Vector3.zAxis) (players arrive looking that way)")
			end
			local pos = Kit.ground(entrance.Position.X, entrance.Position.Z, nil, entrance.Position.Y + 3)
			if not pos then
				fail(id .. " Entrance has no ground under it")
			elseif math.abs(pos.Y - (entrance.Position.Y - 0.5)) > 1.5 then
				fail(`{id} Entrance is {entrance.Position.Y - 0.5 - pos.Y} studs above the ground`)
			end
		end
		local perEnemy = {}
		for _, s in ipairs(spawns and spawns:GetChildren() or {}) do
			local enemyId = s:GetAttribute("EnemyId")
			if not (s:IsA("BasePart") and enemyId and table.find(Kit.Enemies[id], enemyId)) then
				fail(`{id} spawn {s.Name} has a bad or missing EnemyId`)
			else
				perEnemy[enemyId] = (perEnemy[enemyId] or 0) + 1
				local pos = Kit.ground(s.Position.X, s.Position.Z, nil, s.Position.Y + 3)
				if not pos or math.abs(pos.Y - (s.Position.Y - 0.5)) > 1.5 then
					fail(`{id} spawn {s.Name} is not on the ground`)
				end
				if area and area:IsA("BasePart") then
					local rel = area.CFrame:PointToObjectSpace(s.Position)
					if math.abs(rel.X) > area.Size.X / 2 or math.abs(rel.Z) > area.Size.Z / 2 then
						fail(`{id} spawn {s.Name} is outside Area`)
					end
				end
			end
		end
		for _, enemyId in ipairs(Kit.Enemies[id]) do
			if (perEnemy[enemyId] or 0) < 4 then
				fail(`{id} needs at least 4 spawns for {enemyId} (has {perEnemy[enemyId] or 0})`)
			end
		end
		local gate = sf:FindFirstChild("Gate")
		if n >= 2 then
			if not (gate and gate:IsA("Model")) then
				fail(id .. " Gate model missing")
			else
				if not (gate.PrimaryPart and gate.PrimaryPart.Name == "Barrier" and gate.PrimaryPart.CanCollide) then
					fail(id .. " Gate.PrimaryPart must be a collidable part named Barrier")
				end
				if gate:GetAttribute("SubZoneId") ~= id then fail(id .. " Gate attribute SubZoneId wrong") end
				if not gate:FindFirstChild("PriceLabel", true) then fail(id .. " Gate has no PriceLabel") end
			end
		else
			if gate then
				fail(id .. " must not have a Gate (sub-zone 1 is free)")
			end
			local arch = sf:FindFirstChild("EntryArch")
			if not (arch and arch:IsA("Model") and arch:FindFirstChild("NameLabel", true)) then
				fail(id .. " EntryArch model (decorative arch with a NameSign, see Kit.finishArch) missing")
			elseif arch:FindFirstChild("Barrier", true) then
				fail(id .. " EntryArch must not have a Barrier")
			end
			local hubReturn = sf:FindFirstChild("HubReturn")
			if not (hubReturn and hubReturn:IsA("BasePart")) then
				fail(id .. " HubReturn pad missing")
			end
		end
		local bossGate = sf:FindFirstChild("BossGate")
		if n == 4 then
			local interact = bossGate and bossGate:FindFirstChild("Interact", true)
			if not (bossGate and bossGate:IsA("Model") and interact and interact:FindFirstChildOfClass("ProximityPrompt")) then
				fail(id .. " BossGate model with Interact part + ProximityPrompt missing")
			elseif bossGate:GetAttribute("ZoneId") ~= zoneId then
				fail(id .. " BossGate attribute ZoneId wrong")
			end
		end
		local parts, unanchored, scripts = countParts(sf)
		if unanchored > 0 then fail(`{id} has {unanchored} unanchored parts`) end
		if scripts > 0 then fail(`{id} contains {scripts} scripts`) end
		if parts > 6000 then fail(`{id} has {parts} parts (budget 6000)`) end
		table.insert(out, `{id}: {parts} parts, {#(spawns and spawns:GetChildren() or {})} spawns`)
	end
	return table.concat(out, "\n")
end

-- Checks a boss arena model (in workspace._Staging.BossArenas or ServerStorage.BossArenas).
function Kit.validateArena(arena: Instance, zoneId: string): string
	local out = {}
	local function fail(msg) table.insert(out, "FAIL " .. msg) end
	if not arena:IsA("Model") then fail("arena must be a Model") end
	if arena.Name ~= zoneId then fail("arena must be named " .. zoneId) end
	local spawns = arena:FindFirstChild("PlayerSpawns")
	if not (spawns and #spawns:GetChildren() >= 5) then fail("PlayerSpawns folder needs 5 parts") end
	for name, key in pairs({ BossSpawn = "Boss", MiniBossSpawn1 = "Mini1", MiniBossSpawn2 = "Mini2" }) do
		local p = arena:FindFirstChild(name)
		if not (p and p:IsA("BasePart")) then
			fail(name .. " part missing (direct child of the arena)")
		elseif p:GetAttribute("EnemyId") ~= Kit.Bosses[zoneId][key] then
			fail(name .. " attribute EnemyId must be " .. Kit.Bosses[zoneId][key])
		end
	end
	local door = arena:FindFirstChild("Door")
	if not door then fail("Door missing (direct child: BasePart or Model with PrimaryPart)") end
	if arena:IsA("Model") and not arena.PrimaryPart then fail("arena.PrimaryPart must be set (the floor center part)") end
	local parts, unanchored, scripts = countParts(arena)
	if unanchored > 0 then fail(`{unanchored} unanchored parts`) end
	if scripts > 0 then fail(`{scripts} scripts`) end
	if parts > 5000 then fail(`{parts} parts (budget 5000)`) end
	table.insert(out, `arena {zoneId}: {parts} parts`)
	return table.concat(out, "\n")
end

local HUB_STATIONS = {
	"WeaponShop", "Trainer", "EggStation", "TrophyMerchant", "RebirthAltar", "RebirthShop",
	"DiamondShop", "TeamBoard", "CodesBoard", "TutorialGuide",
}
local HUB_BOARDS = { "Leaderboard_Rebirths", "Leaderboard_Zone", "Leaderboard_Bosses", "Leaderboard_Gold", "Leaderboard_Damage" }
Kit.ALL_ZONES = { "Plains", "Desert", "Jungle", "Tundra", "Swamp", "Volcano", "Hell", "Heaven", "Dead", "Abyss", "Mechanical", "Void" }

function Kit.validateHub(): string
	local out = {}
	local function fail(msg) table.insert(out, "FAIL " .. msg) end
	local hub = workspace.Hub
	if not hub:FindFirstChildOfClass("SpawnLocation") then fail("SpawnLocation missing (direct child of Hub)") end
	for _, zoneId in ipairs(Kit.ALL_ZONES) do
		local p = hub.Portals:FindFirstChild("Portal_" .. zoneId)
		if not (p and p:IsA("BasePart") and p:GetAttribute("ZoneId") == zoneId) then
			fail(`Portals.Portal_{zoneId} missing or without attribute ZoneId`)
		end
	end
	for _, name in ipairs(HUB_STATIONS) do
		local m = hub:FindFirstChild(name)
		local interact = m and m:FindFirstChild("Interact", true)
		if not (m and m:IsA("Model") and interact and interact:FindFirstChildOfClass("ProximityPrompt")) then
			fail(name .. " model with Interact part + ProximityPrompt missing")
		end
	end
	for _, name in ipairs(HUB_BOARDS) do
		if not hub:FindFirstChild(name) then fail(name .. " missing") end
	end
	local afk = hub:FindFirstChild("AFKZone")
	if not (afk and afk:IsA("BasePart") and not afk.CanCollide) then fail("AFKZone invisible non-colliding part missing") end
	local parts, unanchored, scripts = countParts(hub)
	if unanchored > 0 then fail(`{unanchored} unanchored parts`) end
	if scripts > 0 then fail(`{scripts} scripts`) end
	table.insert(out, `hub: {parts} parts`)
	return table.concat(out, "\n")
end

return Kit
