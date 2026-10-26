--[[
	BuildAssetPreview (dev tool, Edit mode only; owner round 4, 2026-10-26) - every visible asset of the game in ONE
	place, the asset preview (workspace._Staging.AssetPreview.ByZone), sorted by zone like the game.
	Source of truth: tools/BuildAssetPreview.luau (= ServerStorage.DevTools.BuildAssetPreview).
	Settings: ReplicatedStorage.GameSystem.Config.AssetPreview (size thresholds, grouping tolerances, layout).

	Usage (execute_luau, Edit; require a Clone: require() caches modules):
		local B = require(game.ServerStorage.DevTools.BuildAssetPreview:Clone())
		print(B.audit())                  -- report only: assets per zone, new ones, exceptions (changes nothing)
		_G.before = B.snapshot("Hub")     -- map snapshot of a zone (geometry, looks, scripts, prompts, lights, sounds)
		print(B.tag("Hub"))               -- templates for the zone's new assets + tag / attributes on its map copies
		print(B.build("Hub"))             -- the zone's block in the preview (samples, labels, title)
		print(B.check("Hub"))             -- every visible asset has a template and a sample in the block
		print(B.compare("Hub", _G.before))-- map unchanged except the tag and the attributes
		print(B.index())                  -- the data of docs/asset_preview_index.json (read in chunks: B.chunk(i))
	Idempotent: a second tag() / build() changes nothing (copies already tagged, samples already in place).

	What it does (owner's steps 1-5):
	1. Walks each zone: workspace.Hub, workspace.Zones.<Id> (sub-zone folders) and the zone's boss arena
	   (ServerStorage.BossArenas.<Id>). Candidates are the Models found through folders (and the outermost models inside
	   an untagged candidate, which become nested props when they match an asset). Skipped: folders Spawns, Bounds,
	   VFX, MapFix, Portals, NoClimb, FloorSections (spawn points, invisible walls, emitters, map fixes, triggers, the
	   Void arena floor), characters
	   (a Humanoid inside), invisible / collision-only models; loose parts (terrain, ground, water, mountains, floors)
	   are map geometry, listed per folder in the report, never assets.
	2. Groups identical objects into one asset: MapPropId when tagged, otherwise the signature name (Landmark: its
	   LandmarkName, Gate: its SubZoneId) + part count + mesh ids, and a size that matches after ONE uniform factor
	   (Model scale or parts resized one by one, UNIFORM_TOLERANCE); a non-uniform spread up to SIZE_TOLERANCE is the
	   same asset (a size variant), above it a separate variant asset (_v2, _v3 ...).
	3. New templates are named <zone>_<category>_<name> (zone = the first zone in game order that uses it) and made with
	   SyncMapProps.capture(id, rep, { noRun = true }): the map copies are NEVER replaced, moved or changed; they only
	   get the tag MapProp and the attributes MapPropId, MapPropVersion (the sync stamp), Zone, SizeClass, and
	   MapPropScale when their parts were resized one by one (so a later sync keeps their size).
	4. Counts the copies per zone, classifies the size (largest dimension at the real size: Config SMALL_MAX /
	   MEDIUM_MAX).
	5. Builds one block per zone (Hub first, then Config/Zones order): a title sign (zone name and biome), rows SMALL /
	   MEDIUM / LARGE from left to right (sorted by category then name, spacing proportional to the size, wrapping
	   after ROW_MAX), one sample per asset at its real size (the median size of the zone's copies) and a floor label
	   (name, copies in the zone, quality). Samples are template clones tagged MapProp (a template edit + Sync.run()
	   updates them too) with IsPreviewSample = true, visual only (SyncMapProps.sanitizeSample: anchored, no
	   collisions, no scripts / prompts / sounds, emitters off). The game moves workspace._Staging out of the live
	   world at server start (ServerScriptService.GameSystem.Main), so no player can reach the preview.
]]
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
local Settings = require(ReplicatedStorage.GameSystem.Config.AssetPreview:Clone()) :: any
local ZonesConfig = require(ReplicatedStorage.GameSystem.Config.Zones) :: any

local B = {}

local TAG = "MapProp"
local ROOT_NAME = "ByZone"

local SKIP_FOLDERS = {
	Spawns = "spawn points",
	Bounds = "invisible walls",
	VFX = "effect emitters",
	MapFix = "map fixes (hole closures, foot skirts)",
	Portals = "portal triggers",
	NoClimb = "collision shells",
	FloorSections = "arena floor sections (zone floor)", -- the Void boss arena floor (Section1..8)
}

-- an asset that replaces another one in the map takes over its preview slot (round 5: the improved cart in the place of
-- the old hub cart samples)
B.SLOT_ALIAS = { cart = "hub_vehicle_cart_a" }

-- quality of the templates made before round 4 that are NOT finished (docs/prop_inventory.md); every other older
-- template is "improved", every template made by this tool is "old" (captured as it is in the map)
B.QUALITY = {
	-- round 5 (owner prompt "ROUND 5", Task 2 / Task 3): templates captured as "old" in round 4 and remade since
	desert_landmark_sarcophagus = "improved",
	tundra_landmark_ice_throne = "improved",
	plains_landmark_ancient_tree = "improved", -- 03
	desert_landmark_stone_bridge = "improved", -- 04
	desert_landmark_rock_arch = "improved", -- 05
	desert_gate_door = "improved", -- 06
	desert_gate_boss_gate = "improved", -- 08
	desert_landmark_oasis_well = "improved", -- 09
	desert_prop_spear = "improved", -- 10
}

---------------------------------------------------------------------
-- zones (Hub first, then the Config/Zones order)
---------------------------------------------------------------------
local HUB_BIOME = "Spawn island: village, plaza, harbour, beach"

function B.zones(): { any }
	local list = {
		{ id = "Hub", name = "Hub", order = 0, biome = HUB_BIOME },
	}
	local zones = table.clone(ZonesConfig.List or ZonesConfig.Zones or {})
	if #zones == 0 then
		for _, z in pairs(ZonesConfig.ById) do
			table.insert(zones, z)
		end
	end
	table.sort(zones, function(a, b)
		return a.Index < b.Index
	end)
	for _, z in ipairs(zones) do
		table.insert(list, {
			id = z.Id,
			name = z.Name,
			order = z.Index,
			biome = `{z.Element} biome: {table.concat(z.SubZones, ", ")}`,
		})
	end
	return list
end

local function zoneRoots(zoneId: string): { Instance }
	local roots = {}
	if zoneId == "Hub" then
		local hub = workspace:FindFirstChild("Hub")
		if hub then
			table.insert(roots, hub)
		end
	else
		local zones = workspace:FindFirstChild("Zones")
		local zone = zones and zones:FindFirstChild(zoneId)
		if zone then
			table.insert(roots, zone)
		end
		local arenas = ServerStorage:FindFirstChild("BossArenas")
		local arena = arenas and arenas:FindFirstChild(zoneId)
		if arena then
			table.insert(roots, arena)
		end
	end
	return roots
end
B.zoneRoots = zoneRoots

---------------------------------------------------------------------
-- names, categories
---------------------------------------------------------------------
local function snake(name: string): string
	local s = string.gsub(name, "(%l)(%u)", "%1_%2")
	s = string.gsub(s, "(%u)(%u%l)", "%1_%2")
	s = string.gsub(s, "(%a)(%d)", "%1_%2")
	s = string.lower(s)
	s = string.gsub(s, "[^%w]+", "_")
	s = string.gsub(s, "_+", "_")
	s = string.gsub(s, "^_", "")
	s = string.gsub(s, "_$", "")
	return s
end
B.snake = snake

-- (checked in this order; a name token equal to a keyword, or starting with a prefix keyword ending in "*")
local CATEGORIES = {
	{ "landmark", { "landmark" } }, -- (the <zone>_landmark_<name> ids of the round 4 templates)
	{ "light", { "lamp", "lantern", "torch", "brazier", "candle", "candles", "sconce", "chandelier", "campfire", "fire", "fireplace" } },
	{ "tree", { "tree", "palm", "pine", "oak", "willow", "mangrove", "trunk" } },
	{ "gate", { "gate", "arch", "door", "entry", "portal", "torii", "doorway" } },
	{ "bridge", { "bridge", "dock", "docks", "walkway", "catwalk", "stairs", "carpet", "rail", "platform", "ledge", "pier", "jetty", "ramp" } },
	{ "building", { "house", "cottage", "hut", "building", "tower", "chapel", "crypt", "castle", "temple", "dome", "tent", "shop", "stall", "mill", "windmill", "station", "pavilion", "camp", "ossuary", "cathedral", "hull", "forge", "cabin", "shack", "well", "elevator", "market" } },
	{ "vehicle", { "cart", "ship", "boat", "rowboat", "wagon", "minecart", "galleon", "anchor", "mast" } },
	{ "furniture", { "bench", "chair", "table", "pew", "stool", "desk", "seat", "rack", "stand", "shelf", "planter", "throne", "bed", "crate", "barrel", "chest", "coffin", "anvil", "bellows", "cauldron" } },
	{ "plant", { "bush", "flower", "grass", "fern", "reed", "kelp", "mushroom", "coral", "leaf", "plant", "cactus", "vine", "anemone", "lily", "moss", "tuft", "bamboo", "hedge", "shrub", "seaweed" } },
	{ "rock", { "rock", "boulder", "cliff", "crystal", "chunk", "spike", "stalactite", "stalagmite", "shard", "hoodoo", "mound", "drift", "island", "islet", "obsidian", "basalt", "ice", "icicle", "cloud", "ore", "stone", "rubble", "formation", "geode" } },
	{ "sign", { "sign", "banner", "board", "flag", "flags", "screen", "poster", "leaderboard", "noticeboard" } },
	{ "statue", { "statue", "totem", "altar", "skull", "bone", "bones", "idol", "monument", "column", "pillar", "obelisk", "fountain", "rune", "cross", "tomb", "tombstone", "grave", "sarcophagus", "shrine", "head", "face" } },
	{ "machine", { "pipe", "pipes", "gear", "machine", "robot", "console", "server", "valve", "vent", "cable", "conveyor", "hologram", "energy", "laser", "generator", "reactor", "chimney" } },
	{ "fence", { "fence", "wall", "barrier", "palisade", "border", "partition", "grate", "barricade", "railing" } },
}

local function categoryOf(id: string, landmark: boolean?): string
	if landmark then
		return "landmark"
	end
	local tokens = string.split(snake(id), "_")
	for _, entry in ipairs(CATEGORIES) do
		for _, word in ipairs(entry[2]) do
			for _, t in ipairs(tokens) do
				if t == word or t == word .. "s" then
					return entry[1]
				end
			end
		end
	end
	return "prop"
end
B.categoryOf = categoryOf

-- the signature name of an untagged model (landmarks by LandmarkName, gates by sub-zone)
local function displayName(m: Instance): (string, boolean)
	local landmark = m:GetAttribute("LandmarkName")
	if m.Name == "Landmark" and type(landmark) == "string" then
		return landmark, true
	end
	local sub = m:GetAttribute("SubZoneId")
	if m.Name == "Gate" and type(sub) == "string" then
		return "Gate_" .. sub, false
	end
	return m.Name, false
end

local function newId(zoneId: string, category: string, name: string, suffix: string, taken: { [string]: boolean }): string
	local zone = string.lower(zoneId)
	local tokens = {}
	for _, t in ipairs(string.split(snake(name), "_")) do
		if t ~= zone and t ~= "" then
			table.insert(tokens, t)
		end
	end
	if #tokens == 0 then
		tokens = string.split(snake(name), "_")
	end
	if tokens[1] == category and #tokens > 1 then
		table.remove(tokens, 1)
	end
	local base = zone .. "_" .. category .. "_" .. table.concat(tokens, "_") .. suffix
	local id = base
	local n = 2
	while taken[id] do
		id = base .. "_" .. n
		n += 1
	end
	taken[id] = true
	return id
end

---------------------------------------------------------------------
-- measuring and grouping
---------------------------------------------------------------------
local meshHashes: { [string]: number } = {}
local function strHash(s: string): number
	local cached = meshHashes[s]
	if cached then
		return cached
	end
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	meshHashes[s] = h
	return h
end

-- pivot-space bounds (studs, real size), part count, mesh-id hash and look hash of a model
local function measure(m: Instance): any
	local pivot = (m :: any):GetPivot()
	local inv = pivot:Inverse()
	local parts, meshSum, lookSum, visible = 0, 0, 0, false
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d.Transparency < 0.99 then
				visible = true
			end
			if d:IsA("MeshPart") then
				meshSum = (meshSum + strHash(d.MeshId)) % 4294967296
			end
			local c = d.Color
			local rgb = math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
			lookSum = (lookSum + (rgb * 2654435761 + d.Material.Value * 40503 + strHash(d.Name)) % 4294967296) % 4294967296
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = (inv * d.CFrame):GetComponents()
			local s = d.Size
			local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
			local ex = math.abs(r00) * hx + math.abs(r01) * hy + math.abs(r02) * hz
			local ey = math.abs(r10) * hx + math.abs(r11) * hy + math.abs(r12) * hz
			local ez = math.abs(r20) * hx + math.abs(r21) * hy + math.abs(r22) * hz
			x0, y0, z0 = math.min(x0, x - ex), math.min(y0, y - ey), math.min(z0, z - ez)
			x1, y1, z1 = math.max(x1, x + ex), math.max(y1, y + ey), math.max(z1, z + ez)
		elseif d:IsA("SpecialMesh") or d:IsA("FileMesh") then
			meshSum = (meshSum + strHash((d :: any).MeshId)) % 4294967296
		end
	end
	if parts == 0 then
		return { parts = 0, visible = false }
	end
	local scale = if m:IsA("Model") then m:GetScale() else 1
	local size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	return {
		parts = parts,
		meshes = meshSum,
		look = lookSum,
		visible = visible,
		scale = scale,
		size = size, -- real size (pivot space)
		nsize = size / scale, -- size at Model scale 1
		min = Vector3.new(x0, y0, z0),
		max = Vector3.new(x1, y1, z1),
	}
end
B.measure = measure

-- does size b match the reference a? returns (factor, kind) with kind "same" / "uniform" / "size", or nil
local function fit(a: Vector3, b: Vector3): (number?, string?)
	local function c(v: number): number
		return math.max(v, 0.05)
	end
	local rx, ry, rz = c(b.X) / c(a.X), c(b.Y) / c(a.Y), c(b.Z) / c(a.Z)
	local f = (rx * ry * rz) ^ (1 / 3)
	local nx, ny, nz = rx / f, ry / f, rz / f
	local hi, lo = math.max(nx, ny, nz), math.min(nx, ny, nz)
	if hi / lo <= 1 + Settings.UNIFORM_TOLERANCE then
		return f, if math.abs(f - 1) <= 0.002 then "same" else "uniform"
	end
	if hi <= 1 + Settings.SIZE_TOLERANCE and lo >= 1 - Settings.SIZE_TOLERANCE then
		return f, "size"
	end
	return nil, nil
end

local function vecAttr(v: Vector3): string
	return string.format("%.4f,%.4f,%.4f", v.X, v.Y, v.Z)
end
local function attrVec(s: any): Vector3?
	if typeof(s) == "Vector3" then
		return s
	end
	if type(s) ~= "string" then
		return nil
	end
	local x, y, z = string.match(s, "^([%d%.%-e]+),([%d%.%-e]+),([%d%.%-e]+)$")
	if not x then
		return nil
	end
	return Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)
end

local function sizeClass(largest: number): string
	if largest < Settings.SMALL_MAX then
		return "small"
	elseif largest <= Settings.MEDIUM_MAX then
		return "medium"
	end
	return "large"
end
B.sizeClass = sizeClass

local function median(list: { number }): number
	if #list == 0 then
		return 1
	end
	local t = table.clone(list)
	table.sort(t)
	return t[math.floor((#t + 1) / 2)]
end

local function templateFolder(): Folder
	return ServerStorage:FindFirstChild("MapProps") :: Folder
end

local function isVisualModel(m: Instance): string?
	if m:FindFirstChildOfClass("Humanoid") then
		return "character (Humanoid)"
	end
	return nil
end

---------------------------------------------------------------------
-- collect + plan (all zones: an asset shared by several zones is one asset)
---------------------------------------------------------------------
local function relPath(inst: Instance): string
	local path = inst:GetFullName()
	path = string.gsub(path, "^Workspace%.Zones%.", "")
	path = string.gsub(path, "^Workspace%.", "")
	path = string.gsub(path, "^ServerStorage%.BossArenas%.(%w+)", "%1.BossArena")
	return path
end
B.relPath = relPath

-- outermost models inside a model (not inside another model below it)
local function outerModels(host: Instance): { Model }
	local list = {}
	local function walk(inst: Instance)
		for _, c in ipairs(inst:GetChildren()) do
			if c:IsA("Model") then
				table.insert(list, c)
			else
				walk(c)
			end
		end
	end
	walk(host)
	return list
end

local function collect(zoneId: string): any
	local out = { top = {}, skipped = {}, loose = {} }
	local function walk(container: Instance)
		local loose = 0
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("Folder") then
				if SKIP_FOLDERS[c.Name] then
					local why = SKIP_FOLDERS[c.Name]
					out.skipped[why] = (out.skipped[why] or 0) + 1
				else
					walk(c)
				end
			elseif c:IsA("Model") then
				local why = isVisualModel(c)
				if why then
					out.skipped[why .. ": " .. c.Name] = (out.skipped[why .. ": " .. c.Name] or 0) + 1
				else
					table.insert(out.top, c)
				end
			elseif c:IsA("BasePart") then
				loose += 1
			end
		end
		if loose > 0 then
			out.loose[relPath(container)] = loose
		end
	end
	for _, root in ipairs(zoneRoots(zoneId)) do
		walk(root)
	end
	return out
end

-- the whole plan: assets (existing templates + new groups) and the copies of each zone
function B.plan(): any
	local folder = templateFolder()
	local taken: { [string]: boolean } = {}
	local refs: { [string]: { any } } = {} -- signature -> templates made by this tool
	for _, t in ipairs(folder:GetChildren()) do
		if t:IsA("Model") then
			taken[t.Name] = true
			local sig = t:GetAttribute("MapPropSignature")
			local size = attrVec(t:GetAttribute("MapPropRefSize"))
			-- a template replaced by another asset (attribute ReplacedBy, round 5: hub_vehicle_cart_a -> cart): a new copy
			-- of the old object becomes a copy of the replacement, left out of date so the next Sync.run() replaces it
			local by = t:GetAttribute("ReplacedBy")
			if type(sig) == "string" and size then
				refs[sig] = refs[sig] or {}
				table.insert(refs[sig], { propId = if type(by) == "string" then by else t.Name, nsize = size, replaced = type(by) == "string" })
			end
		end
	end
	local zones = B.zones()
	local plan = { zones = zones, assets = {}, order = {}, byZone = {}, exceptions = {}, skipped = {}, loose = {} }
	local function asset(propId: string): any
		local a = plan.assets[propId]
		if not a then
			local template = folder:FindFirstChild(propId)
			a = {
				id = propId,
				template = template,
				new = false,
				made = template ~= nil and template:GetAttribute("MapPropSignature") ~= nil,
				members = {},
				zones = {},
			}
			plan.assets[propId] = a
			table.insert(plan.order, propId)
		end
		return a
	end
	local function addMember(a: any, inst: Instance, zoneId: string, info: any, extra: any?)
		local m = { inst = inst, zone = zoneId, info = info, nested = extra and extra.nested or false, factor = extra and extra.factor or 1, kind = extra and extra.kind or "tagged" }
		table.insert(a.members, m)
		a.zones[zoneId] = (a.zones[zoneId] or 0) + 1
		return m
	end
	-- 1) walk every zone
	local pendingTop, pendingNested = {}, {}
	for _, z in ipairs(zones) do
		local c = collect(z.id)
		plan.skipped[z.id] = c.skipped
		plan.loose[z.id] = c.loose
		for _, inst in ipairs(c.top) do
			local id = inst:GetAttribute("MapPropId")
			if inst:HasTag(TAG) and type(id) == "string" then
				addMember(asset(id), inst, z.id, nil)
				for _, d in ipairs(inst:GetDescendants()) do
					local nid = d:GetAttribute("MapPropId")
					if d:IsA("Model") and d:HasTag(TAG) and type(nid) == "string" then
						addMember(asset(nid), d, z.id, nil, { nested = true, kind = "tagged" })
					end
				end
			else
				local info = measure(inst)
				if info.parts == 0 or not info.visible then
					local why = if info.parts == 0 then "empty model" else "invisible / collision only"
					plan.skipped[z.id][why .. ": " .. inst.Name] = (plan.skipped[z.id][why .. ": " .. inst.Name] or 0) + 1
					continue
				end
				local name, landmark = displayName(inst)
				info.name = name
				info.landmark = landmark
				info.sig = `{name}|{info.parts}|{info.meshes}`
				table.insert(pendingTop, { inst = inst, zone = z.id, info = info })
				for _, sub in ipairs(outerModels(inst)) do
					local sid = sub:GetAttribute("MapPropId")
					if sub:HasTag(TAG) and type(sid) == "string" then
						addMember(asset(sid), sub, z.id, nil, { nested = true, kind = "tagged" })
					else
						table.insert(pendingNested, { inst = sub, zone = z.id, host = inst })
					end
				end
			end
		end
	end
	-- 2) untagged copies: an existing template of this tool first, else groups (zone order)
	local groups: { [string]: { any } } = {}
	local function tryRefs(p: any): boolean
		for _, r in ipairs(refs[p.info.sig] or {}) do
			local f, kind = fit(r.nsize, p.info.nsize)
			if f then
				addMember(asset(r.propId), p.inst, p.zone, p.info, { factor = if r.replaced then 1 else f, kind = if r.replaced then "replaced" else kind, nested = p.nested })
				return true
			end
		end
		return false
	end
	for _, p in ipairs(pendingTop) do
		if tryRefs(p) then
			continue
		end
		local list = groups[p.info.sig] or {}
		groups[p.info.sig] = list
		local placed = false
		for _, g in ipairs(list) do
			if fit(g.ref, p.info.nsize) then
				table.insert(g.members, p)
				placed = true
				break
			end
		end
		if not placed then
			table.insert(list, { ref = p.info.nsize, members = { p }, sig = p.info.sig, name = p.info.name, landmark = p.info.landmark })
		end
	end
	-- 3) each group: representative = the copy of the first zone nearest the median size; members re-checked on it
	local finals = {}
	local sigs = {}
	for sig in pairs(groups) do
		table.insert(sigs, sig)
	end
	table.sort(sigs)
	for _, sig in ipairs(sigs) do
		local queue = groups[sig]
		local guard = 0
		while #queue > 0 and guard < 50 do
			guard += 1
			local g = table.remove(queue, 1)
			local home = g.members[1].zone
			local sizes = {}
			for _, p in ipairs(g.members) do
				if p.zone == home then
					table.insert(sizes, (fit(g.ref, p.info.nsize)) or 1)
				end
			end
			local med = median(sizes)
			local rep, best = nil, math.huge
			for _, p in ipairs(g.members) do
				if p.zone == home then
					local f = (fit(g.ref, p.info.nsize)) or 1
					local d = math.abs(math.log(f / med)) + (if math.abs(p.info.scale - 1) < 1e-4 then 0 else 1e-3)
					if d < best then
						best, rep = d, p
					end
				end
			end
			local keep, rest = {}, {}
			for _, p in ipairs(g.members) do
				local f, kind = fit(rep.info.nsize, p.info.nsize)
				if f then
					p.factor, p.kind = f, kind
					table.insert(keep, p)
				else
					table.insert(rest, p)
				end
			end
			table.insert(finals, { sig = sig, name = g.name, landmark = g.landmark, rep = rep, members = keep })
			if #rest > 0 then
				table.insert(queue, { ref = rest[1].info.nsize, members = rest, sig = sig, name = g.name, landmark = g.landmark })
			end
		end
	end
	-- variant suffixes: several groups with the same name first used in the same zone -> _v2, _v3 ... (the group with
	-- the most copies keeps the plain name)
	local zoneOrder = {}
	for _, z in ipairs(zones) do
		zoneOrder[z.id] = z.order
	end
	table.sort(finals, function(a, b)
		local za, zb = zoneOrder[a.members[1].zone], zoneOrder[b.members[1].zone]
		if za ~= zb then
			return za < zb
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return #a.members > #b.members
	end)
	local variantNo = {}
	for _, g in ipairs(finals) do
		local key = g.members[1].zone .. "|" .. g.name
		variantNo[key] = (variantNo[key] or 0) + 1
		local suffix = if variantNo[key] > 1 then "_v" .. variantNo[key] else ""
		local category = categoryOf(g.name, g.landmark)
		local id = newId(g.members[1].zone, category, g.name, suffix, taken)
		local a = asset(id)
		a.new = true
		a.made = true
		a.category = category
		a.rep = g.rep.inst
		a.repInfo = g.rep.info
		a.sig = g.sig
		for _, p in ipairs(g.members) do
			addMember(a, p.inst, p.zone, p.info, { factor = p.factor, kind = p.kind })
		end
		refs[g.sig] = refs[g.sig] or {}
		table.insert(refs[g.sig], { propId = id, nsize = g.rep.info.nsize })
	end
	-- 4) nested untagged models inside untagged hosts: copies of a known asset when they match one
	for _, p in ipairs(pendingNested) do
		local info = measure(p.inst)
		if info.parts == 0 or not info.visible then
			continue
		end
		local name = displayName(p.inst)
		info.name = name
		info.sig = `{name}|{info.parts}|{info.meshes}`
		p.info = info
		p.nested = true
		tryRefs(p)
	end
	-- 5) per asset: category, quality, sizes, host flag
	for _, id in ipairs(plan.order) do
		local a = plan.assets[id]
		a.category = a.category or categoryOf(id, false)
		if not a.template and not a.new then
			table.insert(plan.exceptions, `{id}: tagged in the map but no template in ServerStorage.MapProps`)
		end
		a.quality = B.QUALITY[id] or (if a.made then "old" else "improved")
		local reals = {}
		for _, m in ipairs(a.members) do
			if not m.info then
				m.info = measure(m.inst)
				local baked = m.inst:GetAttribute("MapPropScale")
				m.factor = if type(baked) == "number" then baked else 1
			end
			if m.info.size then
				table.insert(reals, math.max(m.info.size.X, m.info.size.Y, m.info.size.Z))
			end
		end
		a.largest = median(reals)
		a.sizeClass = sizeClass(a.largest)
		a.host = false
	end
	-- hosts: a new asset whose representative holds nested copies (tagged before its capture)
	plan.nested = {}
	for _, id in ipairs(plan.order) do
		for _, m in ipairs(plan.assets[id].members) do
			if m.nested then
				plan.nested[m.inst] = { asset = plan.assets[id], member = m }
			end
		end
	end
	for _, id in ipairs(plan.order) do
		local a = plan.assets[id]
		if a.new and a.rep then
			for _, d in ipairs(outerModels(a.rep)) do
				if plan.nested[d] then
					a.host = true
				end
			end
		end
	end
	-- 6) copies per zone
	for _, z in ipairs(zones) do
		plan.byZone[z.id] = {}
	end
	for _, id in ipairs(plan.order) do
		local a = plan.assets[id]
		for zid in pairs(a.zones) do
			table.insert(plan.byZone[zid], id)
		end
	end
	for _, list in pairs(plan.byZone) do
		table.sort(list, function(x, y)
			local a, b = plan.assets[x], plan.assets[y]
			if a.category ~= b.category then
				return a.category < b.category
			end
			return x < y
		end)
	end
	return plan
end

local function zoneScale(a: any, zoneId: string): number
	local list = {}
	for _, m in ipairs(a.members) do
		if m.zone == zoneId then
			local s = (if m.info and m.info.scale then m.info.scale else 1) * (m.factor or 1)
			table.insert(list, s)
		end
	end
	return median(list)
end

---------------------------------------------------------------------
-- audit (report only)
---------------------------------------------------------------------
function B.audit(plan: any?): string
	plan = plan or B.plan()
	local lines = { "BuildAssetPreview.audit (nothing changed)" }
	local totalAssets, totalNew = 0, 0
	for _, z in ipairs(plan.zones) do
		local ids = plan.byZone[z.id]
		local new, old, copies, untagged = 0, 0, 0, 0
		local counts = { small = 0, medium = 0, large = 0 }
		for _, id in ipairs(ids) do
			local a = plan.assets[id]
			counts[a.sizeClass] += 1
			if a.new then
				new += 1
			end
			if a.quality ~= "improved" then
				old += 1
			end
			for _, m in ipairs(a.members) do
				if m.zone == z.id then
					copies += 1
					if not m.inst:HasTag(TAG) then
						untagged += 1
					end
				end
			end
		end
		totalAssets += #ids
		totalNew += new
		table.insert(lines, string.format("%02d %s: %d assets (S %d / M %d / L %d), %d new templates, %d old, %d copies (%d untagged)", z.order, z.id, #ids, counts.small, counts.medium, counts.large, new, old, copies, untagged))
	end
	table.insert(lines, `TOTAL {totalAssets} zone assets, {#plan.order} distinct, {totalNew} new templates`)
	for _, e in ipairs(plan.exceptions) do
		table.insert(lines, "  EXCEPTION " .. e)
	end
	return table.concat(lines, "\n")
end

function B.describe(zoneId: string, plan: any?): string
	plan = plan or B.plan()
	local lines = {}
	for _, id in ipairs(plan.byZone[zoneId] or {}) do
		local a = plan.assets[id]
		local n, kinds = 0, {}
		for _, m in ipairs(a.members) do
			if m.zone == zoneId then
				n += 1
				kinds[m.kind] = (kinds[m.kind] or 0) + 1
			end
		end
		local k = {}
		for kind, c in pairs(kinds) do
			table.insert(k, kind .. " " .. c)
		end
		table.sort(k)
		table.insert(lines, string.format("%s [%s/%s/%s] x%d (%s)%s%s", id, a.category, a.sizeClass, a.quality, n, table.concat(k, ", "), if a.new then " NEW from " .. relPath(a.rep) else "", if a.host then " HOST" else ""))
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- tag: templates for the zone's new assets + tag / attributes on the zone's copies
---------------------------------------------------------------------
local function setAttr(inst: Instance, key: string, value: any): boolean
	if inst:GetAttribute(key) ~= value then
		inst:SetAttribute(key, value)
		return true
	end
	return false
end

function B.tag(zoneId: string, opts: any?): string
	opts = opts or {}
	local plan = B.plan()
	local ids = plan.byZone[zoneId]
	assert(ids, "unknown zone " .. tostring(zoneId))
	local lines = { `BuildAssetPreview.tag {zoneId}` }
	local made, tagged, attrs = 0, 0, 0
	local function tagMember(a: any, m: any)
		local inst = m.inst
		local template = templateFolder():FindFirstChild(a.id)
		if not inst:HasTag(TAG) then
			inst:AddTag(TAG)
			inst:SetAttribute("MapPropId", a.id)
			if m.kind ~= "replaced" then
				inst:SetAttribute("MapPropVersion", Sync.versionOf(template, nil))
			end
			if math.abs((m.factor or 1) - 1) > 0.002 then
				inst:SetAttribute("MapPropScale", math.floor(m.factor * 10000 + 0.5) / 10000)
			end
			tagged += 1
		end
		if setAttr(inst, "Zone", zoneId) then
			attrs += 1
		end
		if setAttr(inst, "SizeClass", a.sizeClass) then
			attrs += 1
		end
	end
	-- templates: leaves first, then hosts (their nested copies tagged before the capture)
	for pass = 1, 2 do
		for _, id in ipairs(ids) do
			local a = plan.assets[id]
			if not a.new or a.template or (pass == 1) == a.host then
				continue
			end
			if pass == 2 then
				-- nested copies inside the representative: tag them first so the template keeps them as nested props
				for _, d in ipairs(outerModels(a.rep)) do
					local n = plan.nested[d]
					if n and not d:HasTag(TAG) and templateFolder():FindFirstChild(n.asset.id) then
						tagMember(n.asset, n.member)
					end
				end
			end
			local report = Sync.capture(id, a.rep, {
				noRun = true,
				attributes = { MapPropSignature = a.sig, MapPropRefSize = vecAttr(a.repInfo.nsize) },
			})
			local template = templateFolder():FindFirstChild(id)
			-- nested props inside the new template: no zone attributes (the hosts of other zones get these copies)
			for _, d in ipairs(template:GetDescendants()) do
				if d:HasTag(TAG) then
					d:SetAttribute("Zone", nil)
					d:SetAttribute("SizeClass", nil)
				end
			end
			template:SetAttribute("MapPropVersion", Sync.fingerprint(template))
			a.template = template
			made += 1
			table.insert(lines, "  " .. string.gsub(report, "\n", " / "))
		end
	end
	-- every copy of the zone (tagged ones get Zone + SizeClass only)
	for _, id in ipairs(ids) do
		local a = plan.assets[id]
		if not templateFolder():FindFirstChild(id) then
			table.insert(lines, `  NO TEMPLATE {id}: copies left untagged`)
			continue
		end
		for _, m in ipairs(a.members) do
			if m.zone == zoneId then
				tagMember(a, m)
			end
		end
	end
	table.insert(lines, `{zoneId}: {#ids} assets, {made} new templates, {tagged} copies tagged, {attrs} attribute(s) set`)
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- build: the zone's block in the preview
---------------------------------------------------------------------
local QUALITY_COLOR = {
	improved = Color3.fromRGB(64, 150, 92),
	old = Color3.fromRGB(196, 128, 48),
	["to redo"] = Color3.fromRGB(186, 60, 60),
}

local function previewRoot(): Folder
	local staging = workspace:FindFirstChild("_Staging")
	assert(staging, "workspace._Staging missing")
	local preview = staging:FindFirstChild("AssetPreview")
	assert(preview, "workspace._Staging.AssetPreview missing")
	local root = preview:FindFirstChild(ROOT_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = ROOT_NAME
		root.Parent = preview
	end
	return root :: Folder
end

local function blockName(z: any): string
	return string.format("%02d_%s", z.order, z.id)
end

local function child(parent: Instance, name: string, class: string): Instance
	local c = parent:FindFirstChild(name)
	if c and c.ClassName ~= class then
		c:Destroy()
		c = nil
	end
	if not c then
		c = Instance.new(class)
		c.Name = name
		c.Parent = parent
	end
	return c :: Instance
end

local function plate(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, text: string, textSize: number?): Part
	local p = parent:FindFirstChild(name) :: Part?
	local fresh = false
	if not p or not p:IsA("Part") then
		if p then
			p:Destroy()
		end
		p = Instance.new("Part")
		p.Name = name
		fresh = true
	end
	local part = p :: Part
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	if fresh then
		-- (placed once: owner round 5, the existing blocks, labels and signs keep their positions; later builds only
		-- refresh the text and the colour)
		part.Size = size
		part.CFrame = cf
		part.Parent = parent
	end
	local gui = child(part, "Text", "SurfaceGui") :: SurfaceGui
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = child(gui, "Label", "TextLabel") :: TextLabel
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.Font = Enum.Font.GothamBold
	label.TextScaled = textSize == nil
	if textSize then
		label.TextSize = textSize
	end
	label.TextWrapped = true
	label.RichText = true
	label.Text = text
	return part
end

-- template bounds (pivot = identity) once turned by rot, at Model scale 1
local function templateBounds(template: Model, rot: CFrame): (Vector3, Vector3)
	local s = template:GetScale()
	local inv = template:GetPivot():Inverse()
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, d in ipairs(template:GetDescendants()) do
		if d:IsA("BasePart") then
			-- (ExtentsCFrame / ExtentsSize: the real box of a union or mesh; a union's CFrame is not its center)
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = (rot * inv * d.ExtentsCFrame):GetComponents()
			local hx, hy, hz = d.ExtentsSize.X / 2, d.ExtentsSize.Y / 2, d.ExtentsSize.Z / 2
			local ex = math.abs(r00) * hx + math.abs(r01) * hy + math.abs(r02) * hz
			local ey = math.abs(r10) * hx + math.abs(r11) * hy + math.abs(r12) * hz
			local ez = math.abs(r20) * hx + math.abs(r21) * hy + math.abs(r22) * hz
			x0, y0, z0 = math.min(x0, x - ex), math.min(y0, y - ey), math.min(z0, z - ez)
			x1, y1, z1 = math.max(x1, x + ex), math.max(y1, y + ey), math.max(z1, z + ez)
		end
	end
	return Vector3.new(x0, y0, z0) / s, Vector3.new(x1, y1, z1) / s
end

-- the sample stands like the zone's copies: when most of them are tilted (a pivot lying on its side, e.g. the Void
-- distant islands or the hub planters), the sample takes the rotation of the first tilted copy; otherwise upright
local function sampleRotation(a: any, zoneId: string): CFrame
	local n, tilted, first = 0, 0, nil
	for _, m in ipairs(a.members) do
		if m.zone == zoneId then
			n += 1
			local pivot = (m.inst :: any):GetPivot()
			if pivot.UpVector.Y < 0.9 then
				tilted += 1
				first = first or pivot.Rotation
			end
		end
	end
	return if first and tilted * 2 > n then first else CFrame.identity
end

local function blockStart(root: Folder, z: any, zones: { any }): number
	local prev = nil
	for _, other in ipairs(zones) do
		if other.order < z.order then
			local b = root:FindFirstChild(blockName(other))
			if b then
				prev = b
			end
		end
	end
	if prev then
		return (prev:GetAttribute("BlockEndZ") :: number) + Settings.BLOCK_GAP
	end
	return Settings.ORIGIN.Z
end

function B.build(zoneId: string, plan: any?): string
	plan = plan or B.plan()
	local zones = plan.zones
	local z = nil
	for _, other in ipairs(zones) do
		if other.id == zoneId then
			z = other
		end
	end
	assert(z, "unknown zone " .. tostring(zoneId))
	local root = previewRoot()
	local block = child(root, blockName(z), "Folder")
	local samples = child(block, "Samples", "Folder")
	local labels = child(block, "Labels", "Folder")
	local signs = child(block, "Signs", "Folder")
	-- (an existing block keeps its front: round 5, nothing moves; the start comes from the owner's ground)
	local ownGround = block:FindFirstChild("Ground")
	local z0 = if ownGround and ownGround:IsA("BasePart") then ownGround.Position.Z - ownGround.Size.Z / 2 + 5 else blockStart(root, z, zones)
	local x0 = Settings.ORIGIN.X
	local lines = { `BuildAssetPreview.build {zoneId} (block {block.Name}, front z {z0})` }
	local placed, moved, created, missing = 0, 0, 0, {}
	local wanted: { [string]: boolean } = {}
	local rowFront = z0 + 34 -- (the title sign stands in front)
	local minX = x0
	local oldCount = 0
	for _, class in ipairs({ "small", "medium", "large" }) do
		local items = {}
		for _, id in ipairs(plan.byZone[zoneId]) do
			local a = plan.assets[id]
			local template = templateFolder():FindFirstChild(id) :: Model?
			if a.sizeClass == class then
				if template then
					table.insert(items, { a = a, template = template })
				else
					table.insert(missing, id)
				end
			end
		end
		if #items == 0 then
			continue
		end
		-- row header
		local rowLabel = string.upper(class) .. (if class == "small" then ` (< {Settings.SMALL_MAX} studs)` elseif class == "medium" then ` ({Settings.SMALL_MAX}-{Settings.MEDIUM_MAX} studs)` else ` (> {Settings.MEDIUM_MAX} studs)`)
		plate(signs, "Row_" .. class, Vector3.new(14, 4, 0.4), CFrame.new(x0 + 9, 2.2, rowFront - 2) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(40, 44, 56), rowLabel)
		local cursor = x0
		local lineDepth = 0
		for _, it in ipairs(items) do
			local a, template = it.a, it.template
			local k = zoneScale(a, zoneId)
			local rot = sampleRotation(a, zoneId)
			local mn, mx = templateBounds(template, rot)
			local w, d = (mx.X - mn.X) * k, (mx.Z - mn.Z) * k
			local gap = math.clamp(0.3 * math.max(w, d), 4, 40)
			local slotW = math.max(w, 7)
			if cursor - slotW < x0 - Settings.ROW_MAX and cursor < x0 then
				rowFront += lineDepth + 16
				cursor = x0
				lineDepth = 0
			end
			local cx = cursor - slotW / 2
			local front = rowFront
			cursor -= slotW + gap
			minX = math.min(minX, cursor)
			lineDepth = math.max(lineDepth, d)
			-- an asset keeps its slot (its label's place), or takes over the slot of the asset it replaces
			local held = labels:FindFirstChild(a.id) or (B.SLOT_ALIAS[a.id] and labels:FindFirstChild(B.SLOT_ALIAS[a.id]))
			if held and held:IsA("BasePart") then
				cx = held:GetAttribute("SlotX") or held.Position.X
				front = held:GetAttribute("SlotFront") or (held.Position.Z + 2.5)
			end
			local cz = front + d / 2
			local center = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2) * k
			local pivot = CFrame.new(cx - center.X, -center.Y, cz - center.Z) * rot
			wanted[a.id] = true
			local want = Sync.versionOf(template, nil)
			local sample = nil
			for _, s in ipairs(samples:GetChildren()) do
				if s:GetAttribute("MapPropId") == a.id then
					if sample or s:GetAttribute("MapPropVersion") ~= want then
						s:Destroy() -- (a duplicate, or out of date: rebuilt below)
					else
						sample = s
					end
				end
			end
			if not sample then
				local s = template:Clone()
				local variants = s:FindFirstChild("_Variants")
				if variants then
					variants:Destroy()
				end
				for key in pairs(s:GetAttributes()) do
					s:SetAttribute(key, nil)
				end
				for _, t in ipairs(s:GetTags()) do
					s:RemoveTag(t)
				end
				s:SetAttribute("MapPropId", a.id)
				s:SetAttribute("MapPropVersion", want)
				s:SetAttribute("IsPreviewSample", true)
				s:SetAttribute("PlacedVersion", want)
				s:AddTag(TAG)
				s.Name = a.id
				if math.abs(k - 1) > 1e-4 then
					s:ScaleTo(k)
				end
				Sync.sanitizeSample(s)
				s:PivotTo(pivot)
				s.Parent = samples
				sample = s
				created += 1
			else
				-- an existing sample stays where it is (owner round 5) until its template changes (a Sync.run() replaced
				-- it in place): then it is centred again on its slot with the new shape
				local placedVersion = sample:GetAttribute("PlacedVersion")
				if placedVersion == nil then
					sample:SetAttribute("PlacedVersion", want)
				elseif placedVersion ~= want then
					if math.abs(sample:GetScale() - k) > 1e-4 then
						sample:ScaleTo(k)
					end
					sample:PivotTo(pivot)
					sample:SetAttribute("PlacedVersion", want)
					moved += 1
				end
			end
			sample:SetAttribute("Zone", zoneId)
			sample:SetAttribute("SizeClass", a.sizeClass)
			placed += 1
			if a.quality ~= "improved" then
				oldCount += 1
			end
			-- floor label
			local copies = a.zones[zoneId] or 0
			local lw = math.clamp(slotW, 7, 26)
			local text = `<b>{a.id}</b>\nx{copies} in zone - {a.quality}`
			local label = plate(labels, a.id, Vector3.new(lw, 2.4, 0.3), CFrame.new(cx, 1.4, front - 2.5) * CFrame.Angles(math.rad(25), 0, 0), QUALITY_COLOR[a.quality] or QUALITY_COLOR.old, text)
			label:SetAttribute("SlotX", cx)
			label:SetAttribute("SlotFront", front)
		end
		rowFront += lineDepth + 22
	end
	-- nested props inside the samples (a lamp post's lantern) older than their own template: synced like any copy
	-- (only when every out-of-date copy of that id is a preview copy; the map is never touched here)
	local staleIds, staleSet = {}, {}
	for _, d in ipairs(samples:GetDescendants()) do
		local nid = d:GetAttribute("MapPropId")
		if d:IsA("Model") and d.Parent ~= samples and d:HasTag(TAG) and type(nid) == "string" and not staleSet[nid] then
			local t = templateFolder():FindFirstChild(nid)
			local variant = d:GetAttribute("Variant")
			if t and d:GetAttribute("MapPropVersion") ~= Sync.versionOf(t, if type(variant) == "string" then variant else nil) then
				staleSet[nid] = true
				table.insert(staleIds, nid)
			end
		end
	end
	if #staleIds > 0 then
		local ok = true
		for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
			local nid = inst:GetAttribute("MapPropId")
			if staleSet[nid] and not inst:IsDescendantOf(templateFolder()) and not inst:IsDescendantOf(root) then
				local t = templateFolder():FindFirstChild(nid)
				local variant = inst:GetAttribute("Variant")
				if inst:GetAttribute("MapPropVersion") ~= Sync.versionOf(t, if type(variant) == "string" then variant else nil) then
					ok = false
					table.insert(lines, `  NOT synced: {nid} also has an out-of-date map copy {relPath(inst)}`)
				end
			end
		end
		if ok then
			Sync.run({ only = staleIds })
			table.insert(lines, `  nested props in samples synced: {table.concat(staleIds, ", ")}`)
		end
	end
	-- stale samples / labels
	local removed = 0
	for _, s in ipairs(samples:GetChildren()) do
		if not wanted[s:GetAttribute("MapPropId") or ""] then
			s:Destroy()
			removed += 1
		end
	end
	for _, l in ipairs(labels:GetChildren()) do
		if not wanted[l.Name] then
			l:Destroy()
		end
	end
	local zEnd = rowFront
	-- title sign + ground
	local title = `<b>{string.upper(z.name)}</b>\n{z.biome}\n{placed} assets - {oldCount} still old`
	plate(signs, "Title", Vector3.new(110, 30, 1), CFrame.new(x0 + 75, 16, z0 + 8), Color3.fromRGB(28, 32, 44), title)
	-- the ground is the owner's (round 5: he recoloured each block to match its zone, snapshot
	-- docs/preview_ground_snapshot.json): an existing ground part is never recreated, resized, moved or recoloured
	local gx0, gx1 = minX - 10, x0 + 140
	local ground = block:FindFirstChild("Ground")
	if not (ground and ground:IsA("BasePart")) then
		local g = Instance.new("Part")
		g.Name = "Ground"
		g.Anchored = true
		g.CanTouch = false
		g.CanCollide = true
		g.Material = Enum.Material.SmoothPlastic
		g.Color = if z.order % 2 == 0 then Color3.fromRGB(92, 96, 104) else Color3.fromRGB(104, 100, 94)
		g.Size = Vector3.new(gx1 - gx0, 1, zEnd - z0 + 10)
		g.CFrame = CFrame.new((gx0 + gx1) / 2, -0.5, (z0 - 5 + zEnd + 5) / 2)
		g.Parent = block
		ground = g
	end
	;(ground :: Instance):SetAttribute("OwnerLocked", true)
	block:SetAttribute("BlockStartZ", z0 - 5)
	block:SetAttribute("BlockEndZ", zEnd + 5)
	block:SetAttribute("Zone", zoneId)
	-- later blocks pushed back when this one grew (preview samples only; never map instances)
	local shift = 0
	local nextBlock = nil
	for _, other in ipairs(zones) do
		if other.order > z.order and not nextBlock then
			nextBlock = root:FindFirstChild(blockName(other))
		end
	end
	-- (round 5: blocks are never moved any more; a block that grew into the next one is only reported)
	if nextBlock then
		local need = (zEnd + 5 + Settings.BLOCK_GAP) - ((nextBlock:GetAttribute("BlockStartZ") :: number) + 5) -- (front z of the next block)
		if need > 0.01 then
			shift = need
			table.insert(lines, `  WARNING: this block now reaches {need} studs into the gap before {nextBlock.Name} (nothing moved)`)
		end
	end
	local parts = 0
	for _, d in ipairs(samples:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	table.insert(lines, `{placed} samples ({created} created, {moved} moved / rescaled, {removed} stale removed), {parts} sample parts, block z {z0 - 5}..{zEnd + 5}, x {gx0}..{gx1}` .. (if shift ~= 0 then `; overlap {shift}` else ""))
	if #missing > 0 then
		table.insert(lines, "  no template (no sample): " .. table.concat(missing, ", "))
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- characters (owner round 5): the zone's NPCs and enemies (normal, mini-bosses, boss) in an area on the LEFT of the
-- block, BEHIND the title sign. Models = what the game clones today: ServerStorage.NPCs / Enemies / Bosses.<id> when
-- imported, else the part-built rig of Lib/EnemyRigs (the NPCService / EnemyService fallbacks). Samples are inert.
---------------------------------------------------------------------
local CHAR_AREA = { left = 136, right = 24, frontGap = 70 } -- studs from the block origin x0 (+X = the viewer's left;
-- frontGap: far enough behind the 30-stud title sign to be seen over it from the front)

local function characterList(zoneId: string): { any }
	local list = {}
	local ok, EnemyRigs = pcall(function()
		return require(game:GetService("ServerScriptService").GameSystem.Lib.EnemyRigs) :: any
	end)
	assert(ok, "Lib/EnemyRigs not found")
	local function imported(folders: { string }, id: string): Model?
		for _, name in ipairs(folders) do
			local folder = ServerStorage:FindFirstChild(name)
			local model = folder and folder:FindFirstChild(id)
			if model and model:IsA("Model") and model.PrimaryPart then
				return model
			end
		end
		return nil
	end
	if zoneId == "Hub" then
		local NPCs = require(ReplicatedStorage.GameSystem.Config.NPCs) :: any
		for _, npc in ipairs(NPCs.List) do
			local model = imported({ "NPCs" }, npc.Id)
			table.insert(list, {
				id = npc.Id, name = npc.Name, role = "NPC", group = "npc",
				source = if model then "imported" else "placeholder",
				quality = if model then "improved" else "old",
				nextAction = if model then "none (imported Blender model)" else `import Blender_Exports/NPC/Hub/{npc.Id}.fbx (EnemyModels.fromImport)`,
				make = function(): Model
					if model then
						return model:Clone()
					end
					return EnemyRigs.build({
						Id = npc.Id, Rig = "Biped", Height = NPCs.HEIGHT, Color = npc.Color, Accent = npc.Accent,
						Eyes = Color3.fromRGB(20, 18, 24), Tier = "normal", AttackType = "melee",
					})
				end,
			})
		end
		return list
	end
	local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies) :: any
	local Zones = require(ReplicatedStorage.GameSystem.Config.Zones) :: any
	local zone = Zones.ById[zoneId]
	local defs = {}
	for n = 1, Zones.SUBZONE_COUNT do
		for _, def in ipairs(Enemies.BySubZone[Zones.subZoneId(zoneId, n)] or {}) do
			table.insert(defs, { def = def, group = "enemy" })
		end
	end
	local room = Enemies.BossRoom[zoneId]
	if room then
		table.insert(defs, { def = room.Mini1, group = "boss" })
		table.insert(defs, { def = room.Mini2, group = "boss" })
		table.insert(defs, { def = room.Boss, group = "boss" })
	end
	local kindFolder = { normal = "Mobs", mini = "MiniBosses", boss = "Bosses" }
	for _, entry in ipairs(defs) do
		local def = entry.def
		local model = imported({ "Enemies", "Bosses" }, def.Id)
		local quality, nextAction
		if model then
			quality, nextAction = "improved", "none (imported Blender model)"
		elseif def.Rig then
			quality = "old"
			nextAction = string.format("import Blender_Exports/%s/%02d_%s/%s.fbx (EnemyModels.fromImport)", kindFolder[def.Tier], zone.Index, zoneId, def.Id)
		else
			quality, nextAction = "to redo", "design + Blender model (zone not playable yet: generic placeholder rig)"
		end
		table.insert(list, {
			id = def.Id, name = def.Name, role = def.Role, group = entry.group, subZone = def.SubZone,
			source = if model then "imported" else "placeholder", quality = quality, nextAction = nextAction,
			make = function(): Model
				if model then
					return model:Clone()
				end
				return EnemyRigs.build(def)
			end,
		})
	end
	return list
end
B.characterList = characterList

-- visual only: no script, prompt, click detector, humanoid, animator / animation controller, joint, sound or emitter;
-- every part anchored, no collisions, no touches
local function sanitizeCharacter(model: Instance)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("Humanoid")
			or d:IsA("AnimationController") or d:IsA("Animator") or d:IsA("JointInstance") or d:IsA("Sound")
			or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke")
			or d:IsA("Sparkles") or d:IsA("Constraint") or d:IsA("AlignPosition") or d:IsA("AlignOrientation") then
			d:Destroy()
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
end

local function worldBounds(model: Instance): (Vector3, Vector3)
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.ExtentsCFrame:GetComponents()
			local hx, hy, hz = d.ExtentsSize.X / 2, d.ExtentsSize.Y / 2, d.ExtentsSize.Z / 2
			local ex = math.abs(r00) * hx + math.abs(r01) * hy + math.abs(r02) * hz
			local ey = math.abs(r10) * hx + math.abs(r11) * hy + math.abs(r12) * hz
			local ez = math.abs(r20) * hx + math.abs(r21) * hy + math.abs(r22) * hz
			x0, y0, z0 = math.min(x0, x - ex), math.min(y0, y - ey), math.min(z0, z - ez)
			x1, y1, z1 = math.max(x1, x + ex), math.max(y1, y + ey), math.max(z1, z + ez)
		end
	end
	return Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)
end

local ROLE_TEXT = { NPC = "NPC", Normal = "enemy", MiniBoss = "mini-boss", Boss = "BOSS" }

function B.buildCharacters(zoneId: string): string
	local z = nil
	for _, other in ipairs(B.zones()) do
		if other.id == zoneId then
			z = other
		end
	end
	assert(z, "unknown zone " .. tostring(zoneId))
	local root = previewRoot()
	local block = root:FindFirstChild(blockName(z))
	assert(block, `build the {zoneId} block first`)
	local z0 = (block:GetAttribute("BlockStartZ") :: number) + 5
	local zEndBlock = block:GetAttribute("BlockEndZ") :: number
	local x0 = Settings.ORIGIN.X
	local area = child(block, "Characters", "Folder")
	local samples = child(area, "Samples", "Folder")
	local labels = child(area, "Labels", "Folder")
	local signs = child(area, "Signs", "Folder")
	local list = characterList(zoneId)
	local lines = { `BuildAssetPreview.buildCharacters {zoneId}: {#list} characters` }
	local created, replaced, kept = 0, 0, 0
	local wanted = {}
	local xLeft, xRight = x0 + CHAR_AREA.left, x0 + CHAR_AREA.right
	local front = z0 + CHAR_AREA.frontGap
	local maxLeft = xLeft
	local groupNames = { npc = "NPCs", enemy = "ENEMIES", boss = "MINI-BOSSES + BOSS" }
	local lastGroup = nil
	local cursor, lineDepth = xLeft, 0
	for _, c in ipairs(list) do
		wanted[c.id] = true
		-- measure a fresh model (the sample itself when it is kept)
		local existing = samples:FindFirstChild(c.id)
		if existing and existing:GetAttribute("CharacterSource") ~= c.source then
			existing:Destroy()
			existing = nil
			replaced += 1
		end
		local model = existing or c.make()
		if not existing then
			sanitizeCharacter(model)
			local m0: any = model
			m0:PivotTo(CFrame.new())
		end
		local mn, mx = worldBounds(model)
		if existing then
			-- (size from the kept sample)
			local p = (existing :: any):GetPivot()
			mn, mx = mn - p.Position, mx - p.Position
		end
		local w, d = mx.X - mn.X, mx.Z - mn.Z
		local boss = c.group == "boss"
		local gap = if boss then math.max(8, 0.6 * math.max(w, d)) else math.clamp(0.4 * math.max(w, d), 3, 10)
		local slotW = math.max(w, 5)
		if c.group ~= lastGroup then
			if lastGroup ~= nil then
				front += lineDepth + 14
			end
			cursor, lineDepth = xLeft, 0
			lastGroup = c.group
			local count = 0
			for _, o in ipairs(list) do
				if o.group == c.group then
					count += 1
				end
			end
			plate(signs, "Group_" .. c.group, Vector3.new(16, 3.4, 0.4), CFrame.new(xLeft - 8, 2, front - 2) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(40, 44, 56), `{groupNames[c.group]} ({count})`)
			front += 6
		elseif cursor - slotW < xRight and cursor < xLeft then
			front += lineDepth + 12
			cursor, lineDepth = xLeft, 0
		end
		local cx = cursor - slotW / 2
		local rowFront = front
		cursor -= slotW + gap
		lineDepth = math.max(lineDepth, d)
		local label = labels:FindFirstChild(c.id)
		if label and label:IsA("BasePart") then
			cx = label:GetAttribute("SlotX") or label.Position.X
			rowFront = label:GetAttribute("SlotFront") or (label.Position.Z + 2.5)
		end
		local target = Vector3.new(cx - (mn.X + mx.X) / 2, -mn.Y, rowFront + d / 2 - (mn.Z + mx.Z) / 2)
		if existing then
			kept += 1
			local p = (existing :: any):GetPivot()
			if (p.Position - target).Magnitude > 0.01 then
				local e0: any = existing
				e0:PivotTo(CFrame.new(target) * p.Rotation)
			end
		else
			local m1: any = model
			m1:PivotTo(CFrame.new(target))
			model.Name = c.id
			for key in pairs(model:GetAttributes()) do
				model:SetAttribute(key, nil)
			end
			model:SetAttribute("CharacterId", c.id)
			model:SetAttribute("Role", c.role)
			model:SetAttribute("CharacterSource", c.source)
			model:SetAttribute("Zone", zoneId)
			model:SetAttribute("IsPreviewSample", true)
			model.Parent = samples
			created += 1
		end
		local lw = math.clamp(slotW, 6, 16)
		local text = `<b>{c.name}</b>\n{ROLE_TEXT[c.role] or c.role} - {c.quality}`
		local l = plate(labels, c.id, Vector3.new(lw, 2.2, 0.3), CFrame.new(cx, 1.3, rowFront - 2.5) * CFrame.Angles(math.rad(25), 0, 0), QUALITY_COLOR[c.quality] or QUALITY_COLOR.old, text)
		l:SetAttribute("SlotX", cx)
		l:SetAttribute("SlotFront", rowFront)
		maxLeft = math.max(maxLeft, cx + slotW / 2)
	end
	local zEnd = front + lineDepth + 6
	-- stale ones
	local removed = 0
	for _, s in ipairs(samples:GetChildren()) do
		if not wanted[s.Name] then
			s:Destroy()
			removed += 1
		end
	end
	for _, l in ipairs(labels:GetChildren()) do
		if not wanted[l.Name] then
			l:Destroy()
		end
	end
	-- more ground only when the area leaves the owner's ground: a NEW part in the block's colour (never resizing his)
	local ground = block:FindFirstChild("Ground") :: BasePart?
	local note = ""
	if ground then
		local gMaxZ = ground.Position.Z + ground.Size.Z / 2
		local gMaxX = ground.Position.X + ground.Size.X / 2
		if zEnd > gMaxZ - 2 or maxLeft > gMaxX - 2 then
			local extra = area:FindFirstChild("GroundExtra") :: BasePart?
			if not extra then
				local e = Instance.new("Part")
				e.Name = "GroundExtra"
				e.Anchored = true
				e.CanTouch = false
				e.Color = ground.Color
				e.Material = ground.Material
				e.Parent = area
				extra = e
			end
			local ex0, ex1 = xRight - 4, math.max(maxLeft + 6, gMaxX)
			local ez0, ez1 = z0 - 5, math.max(zEnd + 6, gMaxZ)
			;(extra :: BasePart).Size = Vector3.new(ex1 - ex0, 1, ez1 - ez0)
			;(extra :: BasePart).CFrame = CFrame.new((ex0 + ex1) / 2, -0.52, (ez0 + ez1) / 2)
			note = " (extra ground added in the block colour)"
		end
	end
	if zEnd > zEndBlock then
		table.insert(lines, `  WARNING: the character area ends at z {zEnd}, past the block end {zEndBlock}`)
	end
	table.insert(lines, `{created} created, {replaced} replaced, {kept} kept, {removed} stale removed; area x {xRight}..{maxLeft}, z {z0 + CHAR_AREA.frontGap}..{zEnd}{note}`)
	return table.concat(lines, "\n")
end

-- samples placed before round 5 used the CFrame / Size of union parts, which are not their real box: 145 of them
-- floated or sank. settle() puts each sample's visible bottom back on the block floor (y = 0), moving it ONLY up or
-- down (its place on the floor, its slot and its label do not change)
function B.settle(zoneId: string?): string
	local root = previewRoot()
	local fixed, worst, list = 0, 0, {}
	for _, block in ipairs(root:GetChildren()) do
		if zoneId and block:GetAttribute("Zone") ~= zoneId then
			continue
		end
		local samples = block:FindFirstChild("Samples")
		for _, s in ipairs(if samples then samples:GetChildren() else {}) do
			local lo = math.huge
			for _, d in ipairs(s:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 then
					local _, y, _, _, _, _, r10, r11, r12 = d.ExtentsCFrame:GetComponents()
					local e = d.ExtentsSize
					lo = math.min(lo, y - (math.abs(r10) * e.X + math.abs(r11) * e.Y + math.abs(r12) * e.Z) / 2)
				end
			end
			if lo < math.huge and math.abs(lo) > 0.05 then
				(s :: any):PivotTo((s :: any):GetPivot() - Vector3.new(0, lo, 0))
				fixed += 1
				worst = math.max(worst, math.abs(lo))
				if #list < 12 then
					table.insert(list, string.format("%s.%s %+.1f", block.Name, s.Name, -lo))
				end
			end
		end
	end
	return string.format("BuildAssetPreview.settle: %d samples put back on the floor (largest move %.1f studs)%s", fixed, worst, if #list > 0 then ": " .. table.concat(list, "; ") else "")
end

-- inert check of the character samples of a zone (or of every zone)
function B.checkCharacters(zoneId: string?): string
	local root = previewRoot()
	local problems, count = {}, 0
	for _, block in ipairs(root:GetChildren()) do
		if zoneId and block:GetAttribute("Zone") ~= zoneId then
			continue
		end
		local area = block:FindFirstChild("Characters")
		local samples = area and area:FindFirstChild("Samples")
		for _, s in ipairs(if samples then samples:GetChildren() else {}) do
			count += 1
			if s:GetAttribute("IsPreviewSample") ~= true then
				table.insert(problems, `{block.Name}.{s.Name}: IsPreviewSample missing`)
			end
			for _, d in ipairs(s:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("Humanoid")
					or d:IsA("AnimationController") or d:IsA("Animator") or d:IsA("Sound") or d:IsA("ParticleEmitter")
					or d:IsA("JointInstance") or d:IsA("Constraint") then
					table.insert(problems, `{block.Name}.{s.Name}: {d.ClassName} left`)
					break
				elseif d:IsA("BasePart") and (not d.Anchored or d.CanCollide or d.CanTouch) then
					table.insert(problems, `{block.Name}.{s.Name}: {d.Name} not inert`)
					break
				end
			end
		end
	end
	local lines = { `BuildAssetPreview.checkCharacters: {count} character samples, {#problems} problem(s)` }
	for i, p in ipairs(problems) do
		if i > 30 then
			break
		end
		table.insert(lines, "  " .. p)
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- check: every visible asset of the zone has a template and a sample; copies tagged with the zone attributes
---------------------------------------------------------------------
function B.check(zoneId: string, plan: any?): string
	plan = plan or B.plan()
	local z = nil
	for _, other in ipairs(plan.zones) do
		if other.id == zoneId then
			z = other
		end
	end
	assert(z, "unknown zone " .. tostring(zoneId))
	local block = previewRoot():FindFirstChild(blockName(z))
	local samples = block and block:FindFirstChild("Samples")
	local have = {}
	if samples then
		for _, s in ipairs(samples:GetChildren()) do
			local id = s:GetAttribute("MapPropId")
			if id then
				have[id] = (have[id] or 0) + 1
			end
		end
	end
	local problems = {}
	local copies = 0
	for _, id in ipairs(plan.byZone[zoneId]) do
		local a = plan.assets[id]
		if not templateFolder():FindFirstChild(id) then
			table.insert(problems, `{id}: no template`)
		end
		if have[id] ~= 1 then
			table.insert(problems, `{id}: {have[id] or 0} sample(s) in the block`)
		end
		for _, m in ipairs(a.members) do
			if m.zone == zoneId then
				copies += 1
				local inst = m.inst
				if not inst:HasTag(TAG) or inst:GetAttribute("MapPropId") ~= id then
					table.insert(problems, `{relPath(inst)}: not tagged as {id}`)
				elseif inst:GetAttribute("Zone") ~= zoneId or inst:GetAttribute("SizeClass") ~= a.sizeClass then
					table.insert(problems, `{relPath(inst)}: Zone / SizeClass attribute missing`)
				end
			end
		end
	end
	local samplesOk = 0
	if samples then
		for _, s in ipairs(samples:GetChildren()) do
			if s:GetAttribute("IsPreviewSample") ~= true then
				table.insert(problems, `sample {s.Name}: IsPreviewSample missing`)
			end
			for _, d in ipairs(s:GetDescendants()) do
				if d:IsA("BasePart") and (d.CanCollide or not d.Anchored) then
					table.insert(problems, `sample {s.Name}: {d.Name} collides or is unanchored`)
					break
				elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("Sound") or d:IsA("ClickDetector") then
					table.insert(problems, `sample {s.Name}: {d.ClassName} left`)
					break
				elseif (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and (d :: any).Enabled then
					table.insert(problems, `sample {s.Name}: emitter enabled`)
					break
				end
			end
			samplesOk += 1
		end
	end
	local lines = { `BuildAssetPreview.check {zoneId}: {#plan.byZone[zoneId]} assets, {copies} copies, {samplesOk} samples, {#problems} problem(s)` }
	for i, p in ipairs(problems) do
		if i > 40 then
			table.insert(lines, `  ... {#problems - 40} more`)
			break
		end
		table.insert(lines, "  " .. p)
	end
	-- exceptions (not assets, by the owner's rules)
	local sk = {}
	for why, n in pairs(plan.skipped[zoneId] or {}) do
		table.insert(sk, `{why} x{n}`)
	end
	table.sort(sk)
	if #sk > 0 then
		table.insert(lines, "  skipped: " .. table.concat(sk, "; "))
	end
	local lo = {}
	for path, n in pairs(plan.loose[zoneId] or {}) do
		table.insert(lo, `{path} {n}`)
	end
	table.sort(lo)
	if #lo > 0 then
		table.insert(lines, `  loose parts (map geometry, not models) in {#lo} folders`)
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- snapshot / compare: the map of a zone before and after (everything but attributes and tags)
---------------------------------------------------------------------
local function r3(n: number): string
	if math.abs(n) < 0.0005 then
		n = 0
	end
	return string.format("%.3f", n)
end

local function lineOf(d: Instance): string
	local parts = { d.ClassName, d.Name, tostring(#d:GetChildren()) }
	if d:IsA("BasePart") then
		local c = { d.CFrame:GetComponents() }
		for i = 1, 12 do
			c[i] = r3(c[i])
		end
		table.insert(parts, table.concat(c, ","))
		table.insert(parts, r3(d.Size.X) .. "," .. r3(d.Size.Y) .. "," .. r3(d.Size.Z))
		table.insert(parts, d.Color:ToHex() .. d.Material.Name .. r3(d.Transparency) .. tostring(d.CanCollide) .. tostring(d.CanQuery) .. tostring(d.CanTouch) .. tostring(d.Anchored))
		if d:IsA("MeshPart") then
			table.insert(parts, d.MeshId .. d.TextureID)
		end
	elseif d:IsA("LuaSourceContainer") then
		local ok, src = pcall(function()
			return (d :: any).Source
		end)
		table.insert(parts, if ok then tostring(#src) .. ":" .. tostring(strHash(src)) else "?")
		table.insert(parts, tostring((d :: any).Enabled))
	elseif d:IsA("ProximityPrompt") then
		table.insert(parts, d.ActionText .. "|" .. d.ObjectText .. "|" .. tostring(d.Enabled) .. "|" .. r3(d.MaxActivationDistance) .. "|" .. r3(d.HoldDuration))
	elseif d:IsA("Light") then
		table.insert(parts, tostring((d :: any).Enabled) .. r3((d :: any).Brightness) .. (d :: any).Color:ToHex())
	elseif d:IsA("Sound") then
		table.insert(parts, d.SoundId .. r3(d.Volume))
	elseif d:IsA("LayerCollector") then
		table.insert(parts, tostring(d.Enabled))
	elseif d:IsA("TextLabel") or d:IsA("TextButton") then
		table.insert(parts, (d :: any).Text)
	elseif d:IsA("Model") then
		table.insert(parts, tostring(d:GetScale()))
		local p = d.WorldPivot
		table.insert(parts, r3(p.X) .. "," .. r3(p.Y) .. "," .. r3(p.Z))
	end
	return table.concat(parts, "|")
end

function B.snapshot(zoneId: string): any
	local snap = { zone = zoneId, lines = {}, count = 0 }
	for _, root in ipairs(zoneRoots(zoneId)) do
		for _, d in ipairs(root:GetDescendants()) do
			snap.lines[d] = lineOf(d)
			snap.count += 1
		end
	end
	return snap
end

function B.compare(zoneId: string, before: any): string
	assert(before and before.zone == zoneId, "compare: pass the snapshot of the same zone")
	local examples = {}
	local nChanged, added, removed, count = 0, 0, 0, 0
	local seen = {}
	for _, root in ipairs(zoneRoots(zoneId)) do
		for _, d in ipairs(root:GetDescendants()) do
			count += 1
			seen[d] = true
			local old = before.lines[d]
			if old == nil then
				added += 1
				if #examples < 20 then
					table.insert(examples, "added " .. relPath(d))
				end
			elseif old ~= lineOf(d) then
				nChanged += 1
				if #examples < 20 then
					table.insert(examples, "changed " .. relPath(d))
				end
			end
		end
	end
	for d in pairs(before.lines) do
		if not seen[d] then
			removed += 1
		end
	end
	local lines = { `BuildAssetPreview.compare {zoneId}: {before.count} -> {count} instances, {nChanged} changed, {added} added, {removed} removed (attributes and tags not compared)` }
	for _, c in ipairs(examples) do
		table.insert(lines, "  " .. c)
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- index (docs/asset_preview_index.json)
---------------------------------------------------------------------
function B.index(plan: any?): string
	plan = plan or B.plan()
	local root = previewRoot()
	local data = { generated = os.date("!%Y-%m-%dT%H:%M:%SZ"), thresholds = { small_max = Settings.SMALL_MAX, medium_max = Settings.MEDIUM_MAX }, zones = {} }
	for _, z in ipairs(plan.zones) do
		local block = root:FindFirstChild(blockName(z))
		local samples = block and block:FindFirstChild("Samples")
		local entry = { id = z.id, name = z.name, order = z.order, biome = z.biome, assets = {}, skipped = {}, loose = {} }
		for _, id in ipairs(plan.byZone[z.id]) do
			local a = plan.assets[id]
			local inPreview = false
			if samples then
				for _, s in ipairs(samples:GetChildren()) do
					if s:GetAttribute("MapPropId") == id then
						inPreview = true
					end
				end
			end
			local kinds = { tagged = 0, same = 0, uniform = 0, size = 0 }
			local tint = 0
			for _, m in ipairs(a.members) do
				if m.zone == z.id then
					kinds[m.kind] = (kinds[m.kind] or 0) + 1
					if a.repInfo and m.info and m.info.look and m.info.look ~= a.repInfo.look then
						tint += 1
					end
				end
			end
			local zonesUsing = {}
			for zid in pairs(a.zones) do
				table.insert(zonesUsing, zid)
			end
			table.sort(zonesUsing)
			table.insert(entry.assets, {
				propId = id,
				category = a.category,
				sizeClass = a.sizeClass,
				largest = math.floor(a.largest * 10 + 0.5) / 10,
				instances = a.zones[z.id] or 0,
				totalInstances = #a.members,
				zones = zonesUsing,
				inPreview = inPreview,
				quality = a.quality,
				newTemplate = a.made,
				source = if a.rep then relPath(a.rep) else nil,
				ownTint = tint,
				sizeVariants = kinds.size or 0,
				resizedParts = kinds.uniform or 0,
			})
		end
		for why, n in pairs(plan.skipped[z.id] or {}) do
			table.insert(entry.skipped, { reason = why, count = n })
		end
		table.sort(entry.skipped, function(x, y)
			return x.reason < y.reason
		end)
		for path, n in pairs(plan.loose[z.id] or {}) do
			table.insert(entry.loose, { folder = path, parts = n })
		end
		table.sort(entry.loose, function(x, y)
			return x.folder < y.folder
		end)
		entry.characters = {}
		local okList, chars = pcall(characterList, z.id)
		local cblock = root:FindFirstChild(blockName(z))
		local carea = cblock and cblock:FindFirstChild("Characters")
		local csamples = carea and carea:FindFirstChild("Samples")
		for _, c in ipairs(if okList then chars else {}) do
			table.insert(entry.characters, {
				id = c.id, name = c.name, role = c.role, subZone = c.subZone, source = c.source,
				inPreview = csamples ~= nil and csamples:FindFirstChild(c.id) ~= nil,
				quality = c.quality, nextAction = c.nextAction,
			})
		end
		table.insert(data.zones, entry)
	end
	local json = HttpService:JSONEncode(data)
	_G.BuildAssetPreviewIndex = json
	return `index: {#json} characters in _G.BuildAssetPreviewIndex (read with B.chunk(i), 60000 per chunk)`
end

function B.chunk(i: number): string
	local json = _G.BuildAssetPreviewIndex or ""
	return string.sub(json, (i - 1) * 60000 + 1, i * 60000)
end

return B
