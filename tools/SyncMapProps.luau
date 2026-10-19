--[[
	SyncMapProps (dev tool, Edit mode only) - single source of truth for the upgraded map props.
	docs/model_upgrade_brief.txt section 4B / 6, docs/prop_inventory.md. Source of truth: tools/SyncMapProps.luau.

	Templates  ServerStorage.MapProps.<propId>   Model with a PrimaryPart and attribute MapPropId. Optional child
	           Folder "_Variants" with one Configuration per variant; its attributes recolour the clone by part name:
	           Color_<PartName> (Color3), Material_<PartName> (string), MaterialVariant_<PartName> (string).
	Instances  every Model tagged "MapProp" with attribute MapPropId, in the test area
	           (workspace._Staging.AssetPreview.ModelsA.Lineup), the main map (workspace.Hub, workspace.Zones), the
	           kit copies (ServerStorage.MapAssets) and the boss-arena templates (ServerStorage.BossArenas).
	           Optional attribute Variant = "<name>" (a Configuration of the template's _Variants).

	Usage (execute_luau, Edit). require() caches modules: require a :Clone() after an update.
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run())                           -- every out-of-date instance -> fresh template clone
		print(Sync.run({ only = { "crate" } }))     -- some props only
		print(Sync.run({ dryRun = true }))          -- report, change nothing
		print(Sync.capture("crate", someInstance))  -- that instance becomes the template, then run (reverse direction)
		print(Sync.undoCapture("crate"))            -- the previous template comes back, then run
		print(Sync.check())                         -- counts, duplicates, out-of-date, waiting (no template yet)
		print(Sync.tagAll())                        -- tag every known instance (inventory rules), idempotent
		print(Sync.backup("old_props_2026-10-18_2330", { "crate" }))  -- serialize the current instances to the log,
		                                            -- then on disk: python tools/collect_backup.py --wait 60

	What run() keeps for each instance: pivot CFrame, scale (Model:GetScale), name, parent, attributes, tags,
	ModelStreamingMode, and the custom children (re-parented onto the new model, world position unchanged):
	children named Interact / NpcSpot / NPC, children with attribute MapPropKeep, children tagged MapProp
	(nested props), and children holding scripts, prompts, GUIs, sounds, click detectors or humanoids.
	A child is not kept when the template has a direct child with the same name and class (the template wins).
	Nested props a template carries (the lamp post's lantern) are synced too: a later pass updates the nested copies a
	replaced host brought, for every id that has a template (also outside opts.only). capture() keeps the nested
	tagged props in the new template.
	Idempotent: each instance stores MapPropVersion = <template fingerprint>|<variant>; up-to-date instances are
	left alone, so a second run changes nothing.
]]
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local SyncMapProps = {}

SyncMapProps.TAG = "MapProp"
local TAG = SyncMapProps.TAG
local FOLDER = "MapProps"
local PREVIOUS = "_Previous"
local VARIANTS = "_Variants"
local CHUNK = 800 -- backup log chunk (Studio log lines are cut at about 1020 characters)
local YIELD_EVERY = 25 -- replacements between two task.wait()

local KEEP_NAMES = { Interact = true, NpcSpot = true, NPC = true }
local KEEP_CLASSES = { "LuaSourceContainer", "ProximityPrompt", "LayerCollector", "Sound", "ClickDetector", "Humanoid" }

---------------------------------------------------------------------
-- Inventory rules (docs/prop_inventory.md)
---------------------------------------------------------------------
local function rgbOf(part: Instance?): (number, number, number)
	if part and part:IsA("BasePart") then
		return part.Color.R * 255, part.Color.G * 255, part.Color.B * 255
	end
	return -1, -1, -1
end

-- top-level models, matched by name inside the search roots (filter: an optional model -> boolean that limits a rule;
-- match: an optional model -> boolean that adds models with other names, e.g. renamed hub copies)
SyncMapProps.RULES = {
	{ propId = "crate", names = { "Crate_A" }, variant = function(m)
		local r = rgbOf(m:FindFirstChild("Body"))
		return if r >= 0 and r < 150 then "Sunken" else nil -- Abyss_2 dark recolour (body 92,71,59)
	end },
	{ propId = "barrel", names = { "Barrel_A" } },
	{ propId = "lamp_post", names = { "Lantern_Post" } },
	{ propId = "fountain", names = { "Fountain_A" } },
	{ propId = "egg_nest", names = { "SeagullNest_Rock" } },
	{ propId = "rowboat", names = { "Rowboat_Wreck" }, variant = function(m)
		local r = rgbOf(m:FindFirstChild("Bench"))
		return if r >= 0 and r < 150 then "Sunken" else nil -- Abyss_2 dark recolour
	end },
	{ propId = "minecart", names = { "Minecart_A" } },
	{ propId = "skull_bones", names = { "Bone_Pile_A" }, variant = function(m)
		local r = rgbOf(m:FindFirstChild("EyeSocket"))
		return if r > 150 then "Pale" else nil -- Abyss_3 pale grey-green recolour
	end },
	{ propId = "scarecrow", names = { "Scarecrow_A" } },
	{ propId = "clam_pearl", names = { "Shell_A" } },
	{ propId = "well", names = { "Well_A" } },
	{ propId = "chest", names = { "Chest_A" } },
	{ propId = "weapon_stall", names = { "Station_WeaponShop" }, hubNames = { "WeaponShop" } },
	{ propId = "trophy_stall", names = { "Station_TrophyMerchant" }, hubNames = { "TrophyMerchant" } },
	{ propId = "diamond_shop", names = { "Station_DiamondShop" }, hubNames = { "DiamondShop" } },
	-- Plains_1 farm (owner fix of 2026-10-19, StudioProps wheat_patch / hay_bale / cart). Cart_A is a Common kit model
	-- also placed in the hub harbour, Desert_2 / 3, Plains_4 and Volcano_1: the owner asked for the Plains_1 carts,
	-- so only the Plains_1 copy, the test-area copy and the kit copy are synced (filter)
	{ propId = "wheat_patch", names = { "WheatPatch_A" } },
	{ propId = "hay_bale", names = { "HayBale_A" } },
	-- props batch 2 (owner, 2026-10-19; DevTools.PropsBatch2): the portal frame of the test zone / kit, and the hub's
	-- 12 PortalFrame_<Zone> (Hub.Decor.PortalFrames; PortalController finds them by name), Variant = the zone id
	{ propId = "portal_frame", names = { "PortalFrame" }, match = function(m)
		local parent = m.Parent
		return parent ~= nil and parent.Name == "PortalFrames" and string.match(m.Name, "^PortalFrame_%w+$") ~= nil
	end, variant = function(m)
		return string.match(m.Name, "^PortalFrame_(%w+)$")
	end },
	-- props batch 2, batch A: 01 wall (test zone, kit, the hub's 4 Hub_Wall_Section), 08 stone arch (test zone and kit
	-- only: no game copy), 09 pillar (test zone, kit and the 12 x3-scaled pillars of the Plains boss arena, scale kept)
	{ propId = "hub_wall", names = { "Hub_Wall_Section" } },
	{ propId = "stone_arch", names = { "Stone_Arch_A" } },
	{ propId = "stone_pillar", names = { "Stone_Pillar_A" } },
	{ propId = "cart", names = { "Cart_A" }, filter = function(m)
		local zones = workspace:FindFirstChild("Zones")
		local plains = zones and zones:FindFirstChild("Plains")
		local plains1 = plains and plains:FindFirstChild("Plains_1")
		local staging = workspace:FindFirstChild("_Staging")
		local kit = ServerStorage:FindFirstChild("MapAssets")
		return (plains1 ~= nil and m:IsDescendantOf(plains1)) or (staging ~= nil and m:IsDescendantOf(staging)) or (kit ~= nil and m:IsDescendantOf(kit))
	end },
}

-- Embedded props (loose parts inside a bigger model). tagAll() wraps each group, in place, into a child Model
-- (no part moves; only their parent changes). The wrapper's scale is set while it is empty (Model:ScaleTo on an
-- empty model resizes nothing), so run() later scales the template clone to the old size.
-- REF = the template's size at scale 1 that the old group is matched to (keep the templates at these sizes).
SyncMapProps.REF = { crate = 4.0, barrel = 4.05, lantern = 1.5 } -- crate/barrel: height, lantern: glass height

local function partsNamed(host: Instance, names: { [string]: boolean }): { BasePart }
	local list = {}
	for _, child in ipairs(host:GetChildren()) do
		if child:IsA("BasePart") and names[child.Name] then
			table.insert(list, child)
		end
	end
	return list
end

local function upright(cf: CFrame): CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z):Cross(Vector3.yAxis)
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

-- bounds of parts in the rotation frame `rot` (a rotation-only CFrame): returns min, max in that frame
local function boundsIn(parts: { BasePart }, rot: CFrame): (Vector3, Vector3)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(parts) do
		local cf = rot:ToObjectSpace(p.CFrame)
		local h = p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local q = cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					mn, mx = mn:Min(q), mx:Max(q)
				end
			end
		end
	end
	return mn, mx
end

-- pivot at the bottom centre of `parts`, oriented like `rot`
local function bottomPivot(parts: { BasePart }, rot: CFrame): (CFrame, number)
	local mn, mx = boundsIn(parts, rot)
	local c = (mn + mx) / 2
	return rot * CFrame.new(c.X, mn.Y, c.Z), mx.Y - mn.Y
end

local function largest(parts: { BasePart }): BasePart
	local best, volume = parts[1], -1
	for _, p in ipairs(parts) do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > volume then
			best, volume = p, v
		end
	end
	return best
end

-- each rule returns a list of groups { parts = {...}, pivot = CFrame, scale = number } for one host model
SyncMapProps.EMBEDDED = {
	{ propId = "crate", wrapper = "Crate", hosts = { "HunterCamp" }, groups = function(host)
		local parts = partsNamed(host, { Crate = true })
		if #parts == 0 then
			return {}
		end
		local pivot, height = bottomPivot(parts, upright(largest(parts).CFrame))
		return { { parts = parts, pivot = pivot, scale = height / SyncMapProps.REF.crate } }
	end },
	{ propId = "barrel", wrapper = "Barrel", hosts = { "HunterCamp", "Market_Awning_A" }, groups = function(host)
		local parts = partsNamed(host, { Barrel = true, BarrelBand = true })
		if #parts == 0 then
			return {}
		end
		local pivot, height = bottomPivot(parts, upright(host:GetPivot()))
		return { { parts = parts, pivot = pivot, scale = height / SyncMapProps.REF.barrel } }
	end },
	{ propId = "laundry_rack", wrapper = "LaundryRack", hosts = { "HunterCamp" }, groups = function(host)
		local parts = partsNamed(host, { Rack = true, Hide = true })
		if #parts == 0 then
			return {}
		end
		local bar = parts[1]
		for _, p in ipairs(parts) do
			if p.Name == "Rack" and p.Size.X > bar.Size.X then
				bar = p -- the crossbar (8.4 long on its X axis)
			end
		end
		local pivot = bottomPivot(parts, upright(bar.CFrame))
		local ground = host:GetPivot().Y -- the legs dip 0.14 under the camp floor: pivot on the floor
		return { { parts = parts, pivot = pivot + Vector3.new(0, ground - pivot.Y, 0), scale = 1 } }
	end },
	{ propId = "anvil_forge", wrapper = "AnvilForge", hosts = { "Station_WeaponShop", "WeaponShop" }, groups = function(host)
		local parts = partsNamed(host, { Forge = true, Chimney = true, Embers = true, Stump = true, Anvil = true, AnvilHorn = true })
		if #parts == 0 then
			return {}
		end
		local pivot = bottomPivot(parts, upright(host:GetPivot()))
		return { { parts = parts, pivot = pivot, scale = 1 } }
	end },
	-- lantern units hosted by stalls and the Plains arch (the lamp_post template carries its own lantern: not wrapped
	-- there; the other zones' arches have zone-styled lanterns: not synced). Pivot = centre of the glass ("Lantern"),
	-- upright; scale = glass height / REF.lantern. Chains and arms stay in the host.
	{ propId = "lantern", wrapper = "Lantern", hosts = { "TutorialGuide", "Station_TutorialGuide", "EggStation", "Station_EggStation", "EntryArch", "EntryArch_Plains" }, hostFilter = function(host)
		local plains = workspace:FindFirstChild("Zones") and workspace.Zones:FindFirstChild("Plains")
		return host.Name ~= "EntryArch" or (plains ~= nil and host:IsDescendantOf(plains))
	end, groups = function(host)
		local groups = {}
		local trims = partsNamed(host, { LanternCap = true, LanternBase = true })
		for _, glass in ipairs(partsNamed(host, { Lantern = true })) do
			local parts = { glass }
			for _, trim in ipairs(trims) do
				local d = trim.Position - glass.Position
				if Vector2.new(d.X, d.Z).Magnitude < 1 and math.abs(d.Y) < 2 then
					table.insert(parts, trim)
				end
			end
			local rot = upright(host:GetPivot())
			table.insert(groups, { parts = parts, pivot = CFrame.new(glass.Position) * rot, scale = glass.Size.Y / SyncMapProps.REF.lantern })
		end
		return groups
	end },
}

-- extra models to include in backup() (embedded props inside bigger models)
local function hasChild(model: Instance, name: string): boolean
	local child = model:FindFirstChild(name)
	return child ~= nil and child:IsA("BasePart")
end
SyncMapProps.HOSTS = {
	lantern = function(m) return m.Name == "Lantern_Post" and hasChild(m, "Lantern") end, -- the lamp posts' own lanterns
}

local function searchRoots(): { Instance }
	local list = {}
	local function add(inst: Instance?)
		if inst then
			table.insert(list, inst)
		end
	end
	add(workspace:FindFirstChild("Hub"))
	add(workspace:FindFirstChild("Zones"))
	local staging = workspace:FindFirstChild("_Staging")
	local preview = staging and staging:FindFirstChild("AssetPreview")
	add(preview and preview:FindFirstChild("ModelsA"))
	add(ServerStorage:FindFirstChild("MapAssets"))
	add(ServerStorage:FindFirstChild("BossArenas"))
	return list
end

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function templateFolder(create: boolean?): Folder?
	local folder = ServerStorage:FindFirstChild(FOLDER)
	if not folder and create then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = ServerStorage
	end
	return folder :: Folder?
end

local function isTemplateArea(inst: Instance): boolean
	local folder = ServerStorage:FindFirstChild(FOLDER)
	return folder ~= nil and inst:IsDescendantOf(folder)
end

local function holdsKeepClass(inst: Instance): boolean
	for _, className in ipairs(KEEP_CLASSES) do
		if inst:IsA(className) then
			return true
		end
	end
	for _, d in ipairs(inst:GetDescendants()) do
		for _, className in ipairs(KEEP_CLASSES) do
			if d:IsA(className) then
				return true
			end
		end
	end
	return false
end

-- is this direct child of an instance a custom (functional) child to carry over?
local function isCustom(child: Instance, template: Instance?): boolean
	if child.Name == VARIANTS then
		return false
	end
	if template then
		local same = template:FindFirstChild(child.Name)
		if same and same.ClassName == child.ClassName then
			return false -- the template provides it
		end
	end
	return KEEP_NAMES[child.Name] == true
		or child:GetAttribute("MapPropKeep") ~= nil
		or child:HasTag(TAG)
		or holdsKeepClass(child)
end

local function round(n: number): string
	return string.format("%.3f", n)
end

local function v3(v: Vector3): string
	return round(v.X) .. "," .. round(v.Y) .. "," .. round(v.Z)
end

local function cf(c: CFrame): string
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
	return table.concat({ round(x), round(y), round(z), round(r00), round(r01), round(r02), round(r10), round(r11), round(r12), round(r20), round(r21), round(r22) }, ",")
end

local function attrs(inst: Instance): string
	local keys = {}
	for k, v in pairs(inst:GetAttributes()) do
		if k ~= "MapPropVersion" then
			table.insert(keys, k .. "=" .. tostring(v))
		end
	end
	table.sort(keys)
	return table.concat(keys, ";")
end

local PROPS = { "Color", "Material", "MaterialVariant", "Transparency", "Reflectance", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Brightness", "Range", "Enabled", "Shadows", "Shape", "MeshId", "TextureID", "CollisionFidelity", "Face", "Texture", "Rate", "Angle", "Spread", "LightEmission", "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "Width0", "Width1", "Attachment0", "Attachment1" }

-- content fingerprint of a template (structure, geometry, looks, attributes); 8 hex digits
local function fingerprint(model: Model): string
	local pivot = model:GetPivot()
	local lines = { model.PrimaryPart and model.PrimaryPart.Name or "-", attrs(model) }
	for _, d in ipairs(model:GetDescendants()) do
		local line = { d.ClassName, d:GetFullName():sub(#model:GetFullName() + 1), attrs(d) }
		if d:IsA("BasePart") then
			table.insert(line, v3(d.Size))
			table.insert(line, cf(pivot:ToObjectSpace(d.CFrame)))
		elseif d:IsA("Attachment") then
			table.insert(line, cf(d.CFrame))
		end
		for _, prop in ipairs(PROPS) do
			local ok, value = pcall(function()
				return (d :: any)[prop]
			end)
			if ok and value ~= nil then
				table.insert(line, prop .. "=" .. (if typeof(value) == "Instance" then value.Name else tostring(value)))
			end
		end
		table.insert(lines, table.concat(line, "|"))
	end
	table.sort(lines)
	local text = table.concat(lines, "\n")
	local h1, h2 = 5381, 52711
	for i = 1, #text do
		local b = string.byte(text, i)
		h1 = (h1 * 33 + b) % 4294967296
		h2 = (h2 * 31 + b * 7) % 4294967291
	end
	return string.format("%08x", bit32.bxor(h1, h2))
end
SyncMapProps.fingerprint = fingerprint

local function applyVariant(model: Model, template: Model, variant: string?): string?
	if not variant or variant == "" then
		return nil
	end
	local folder = template:FindFirstChild(VARIANTS)
	local config = folder and folder:FindFirstChild(variant)
	if not config then
		return `variant "{variant}" not defined in the template`
	end
	local attributes = config:GetAttributes()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local color = attributes["Color_" .. d.Name]
			if typeof(color) == "Color3" then
				d.Color = color
				-- a tinted SurfaceAppearance follows the recolour; the low-poly overlay SA ("Overlay", Color white) is
				-- left white (its lines darken the new Color)
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				if sa and sa.Name ~= "Overlay" then
					pcall(function()
						(sa :: any).Color = color
					end)
				end
			end
			local material = attributes["Material_" .. d.Name]
			if type(material) == "string" then
				pcall(function()
					d.Material = (Enum.Material :: any)[material]
				end)
			end
			local mv = attributes["MaterialVariant_" .. d.Name]
			if type(mv) == "string" then
				d.MaterialVariant = mv
			end
		end
	end
	return nil
end

local function versionOf(template: Model, variant: string?): string
	return (template:GetAttribute("MapPropVersion") or "?") .. "|" .. (variant or "")
end

local function templates(only: { string }?): { [string]: Model }
	local folder = templateFolder(false)
	local list = {}
	if not folder then
		return list
	end
	local wanted: { [string]: boolean }? = nil
	if only then
		wanted = {}
		for _, id in ipairs(only) do
			(wanted :: any)[id] = true
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child.Name ~= PREVIOUS and (not wanted or wanted[child.Name]) then
			list[child.Name] = child
		end
	end
	return list
end

local function instancesOf(propId: string): { Model }
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		if inst:IsA("Model") and inst:GetAttribute("MapPropId") == propId and inst:IsDescendantOf(game) and not isTemplateArea(inst) then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

local function shortPath(inst: Instance): string
	return (string.gsub(inst:GetFullName(), "^Workspace%._Staging%.AssetPreview%.ModelsA%.Lineup", "TEST"))
end

---------------------------------------------------------------------
-- replace one instance
---------------------------------------------------------------------
local function replace(old: Model, template: Model): (Model?, string?)
	local parent = old.Parent
	if not parent then
		return nil, "no parent"
	end
	local variant = old:GetAttribute("Variant")
	local pivot = old:GetPivot()
	local scale = old:GetScale()
	local new = template:Clone()
	local variants = new:FindFirstChild(VARIANTS)
	if variants then
		variants:Destroy()
	end
	local err = applyVariant(new, template, if type(variant) == "string" then variant else nil)
	if err then
		new:Destroy()
		return nil, err
	end
	for key in pairs(new:GetAttributes()) do
		new:SetAttribute(key, nil)
	end
	for key, value in pairs(old:GetAttributes()) do
		new:SetAttribute(key, value)
	end
	-- attributes the new model must not inherit (e.g. the Toolbox credit of a replaced mesh), comma separated
	local drop = template:GetAttribute("MapPropDropAttributes")
	if type(drop) == "string" then
		for _, key in ipairs(string.split(drop, ",")) do
			new:SetAttribute((string.gsub(key, "%s", "")), nil)
		end
	end
	new:SetAttribute("MapPropId", template.Name)
	new:SetAttribute("MapPropVersion", versionOf(template, if type(variant) == "string" then variant else nil))
	for _, tag in ipairs(new:GetTags()) do
		new:RemoveTag(tag)
	end
	for _, tag in ipairs(old:GetTags()) do
		new:AddTag(tag)
	end
	new:AddTag(TAG)
	new.Name = old.Name
	pcall(function()
		new.ModelStreamingMode = old.ModelStreamingMode
	end)
	for _, d in ipairs(new:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	if math.abs(scale - 1) > 1e-4 then
		new:ScaleTo(scale)
	end
	new:PivotTo(pivot)
	local kept = 0
	for _, child in ipairs(old:GetChildren()) do
		if isCustom(child, template) then
			child.Parent = new
			kept += 1
		end
	end
	-- signs: a SurfaceGui / BillboardGui on a part of the old model (a name plate, a price sign, a screen) moves onto
	-- the new model's part of the same name, replacing the template's GUI of that name (texts, sizes kept)
	local guis = 0
	for _, gui in ipairs(old:GetDescendants()) do
		local host = gui.Parent
		if gui:IsA("LayerCollector") and host and host:IsA("BasePart") and host.Parent == old then
			local target = new:FindFirstChild(host.Name)
			if target and target:IsA("BasePart") then
				local same = target:FindFirstChild(gui.Name)
				if same and same:IsA("LayerCollector") then
					same:Destroy()
				end
				gui.Parent = target
				guis += 1
			end
		end
	end
	new.Parent = parent
	old:Destroy()
	local notes = {}
	if kept > 0 then
		table.insert(notes, `kept {kept} custom child(ren)`)
	end
	if guis > 0 then
		table.insert(notes, `moved {guis} sign GUI(s)`)
	end
	return new, if #notes > 0 then table.concat(notes, ", ") else nil
end

---------------------------------------------------------------------
-- run
---------------------------------------------------------------------
function SyncMapProps.run(opts: any?): string
	opts = opts or {}
	local list = templates(opts.only)
	local stats = {}
	local order = {}
	for propId, template in pairs(list) do
		if not template.PrimaryPart then
			stats[propId] = { found = 0, replaced = 0, current = 0, skipped = { "template has no PrimaryPart" }, notes = {} }
		else
			template:SetAttribute("MapPropVersion", fingerprint(template))
			stats[propId] = { found = 0, replaced = 0, current = 0, skipped = {}, notes = {} }
		end
		table.insert(order, propId)
	end
	table.sort(order)
	-- a replaced host brings the nested props of its template (a lamp post's lantern): passes 2+ also sync those
	-- nested copies for every id that has a template, even outside opts.only
	local nestedIds = {}
	if opts.only then
		for propId, template in pairs(templates(nil)) do
			if not list[propId] and template.PrimaryPart then
				template:SetAttribute("MapPropVersion", fingerprint(template))
				list[propId] = template
				stats[propId] = { found = 0, replaced = 0, current = 0, skipped = {}, notes = {}, nested = true }
				table.insert(nestedIds, propId)
			end
		end
		table.sort(nestedIds)
	end
	local fresh: { [Instance]: boolean } = {} -- the instances replaced in this run
	local function insideFresh(inst: Instance): boolean
		local p = inst.Parent
		while p and p ~= game do
			if fresh[p] then
				return true
			end
			p = p.Parent
		end
		return false
	end
	local done = 0
	for pass = 1, 3 do -- a host prop may bring a nested prop instance: a later pass syncs it
		local changed = 0
		local ids = order
		if pass > 1 and #nestedIds > 0 then
			ids = table.clone(order)
			for _, id in ipairs(nestedIds) do
				table.insert(ids, id)
			end
		end
		for _, propId in ipairs(ids) do
			local template = list[propId]
			local s = stats[propId]
			if not template.PrimaryPart then
				continue
			end
			for _, inst in ipairs(instancesOf(propId)) do
				if s.nested and not insideFresh(inst) then
					continue -- (outside opts.only: only the nested copies a replaced host brought)
				end
				if pass == 1 then
					s.found += 1
				end
				local variant = inst:GetAttribute("Variant")
				local want = versionOf(template, if type(variant) == "string" then variant else nil)
				if inst:GetAttribute("MapPropVersion") == want and not opts.force then
					if pass == 1 then
						s.current += 1
					end
					continue
				end
				if opts.dryRun then
					if pass == 1 then
						s.replaced += 1
					end
					continue
				end
				local path = shortPath(inst)
				local new, note = replace(inst, template)
				if new then
					fresh[new] = true
					s.replaced += 1
					changed += 1
					if pass > 1 then
						s.found += 1
					end
					if note then
						table.insert(s.notes, `{path}: {note}`)
					end
				else
					table.insert(s.skipped, `{path}: {note}`)
				end
				done += 1
				if done % YIELD_EVERY == 0 then
					task.wait()
				end
			end
		end
		if changed == 0 or opts.dryRun or opts.force then
			break
		end
	end
	-- tagged instances waiting for a template
	local waiting = {}
	if not opts.only then
		for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
			local id = inst:GetAttribute("MapPropId")
			if type(id) == "string" and not list[id] and not isTemplateArea(inst) then
				waiting[id] = (waiting[id] or 0) + 1
			end
		end
	end
	local lines = { if opts.dryRun then "SyncMapProps.run (DRY RUN, nothing changed)" else "SyncMapProps.run" }
	local totalFound, totalReplaced, totalSkipped = 0, 0, 0
	for _, propId in ipairs(order) do
		local s = stats[propId]
		totalFound += s.found
		totalReplaced += s.replaced
		totalSkipped += #s.skipped
		table.insert(lines, `{propId} (version {list[propId]:GetAttribute("MapPropVersion") or "?"}): found {s.found}, replaced {s.replaced}, up to date {s.current}, skipped {#s.skipped}`)
		for _, why in ipairs(s.skipped) do
			table.insert(lines, "  SKIPPED " .. why)
		end
		if opts.verbose then
			for _, note in ipairs(s.notes) do
				table.insert(lines, "  " .. note)
			end
		elseif #s.notes > 0 then
			table.insert(lines, `  {#s.notes} instance(s) kept custom children`)
		end
	end
	for _, propId in ipairs(nestedIds) do
		local s = stats[propId]
		if s.replaced > 0 or #s.skipped > 0 then
			totalFound += s.found
			totalReplaced += s.replaced
			totalSkipped += #s.skipped
			table.insert(lines, `{propId} (version {list[propId]:GetAttribute("MapPropVersion") or "?"}): {s.replaced} nested cop(y/ies) brought by a replaced host synced`)
			for _, why in ipairs(s.skipped) do
				table.insert(lines, "  SKIPPED " .. why)
			end
		end
	end
	local waitList = {}
	for id, n in pairs(waiting) do
		table.insert(waitList, `{id} {n}`)
	end
	table.sort(waitList)
	if #waitList > 0 then
		table.insert(lines, "waiting for a template (tagged, not synced): " .. table.concat(waitList, ", "))
	end
	table.insert(lines, `TOTAL: {#order} template(s), found {totalFound}, replaced {totalReplaced}, skipped {totalSkipped}`)
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- capture (reverse direction) and undo
---------------------------------------------------------------------
function SyncMapProps.capture(propId: string, instance: Instance, opts: any?): string
	assert(type(propId) == "string" and propId ~= "", "capture(propId, instance): propId missing")
	assert(instance and instance:IsA("Model"), "capture(propId, instance): instance must be a Model")
	assert(not isTemplateArea(instance), "capture: the instance is already a template")
	local folder = templateFolder(true) :: Folder
	local warnings = {}
	if instance:GetAttribute("Variant") then
		table.insert(warnings, `warning: the captured instance has Variant "{instance:GetAttribute("Variant")}"; its variant colours are now the template's default`)
	end
	local copy = instance:Clone()
	local nested = 0
	for _, child in ipairs(copy:GetChildren()) do
		if child:HasTag(TAG) then
			nested += 1 -- a nested prop (a lamp post's lantern) stays part of the template; later runs keep it synced
		elseif isCustom(child, nil) then
			child:Destroy() -- functional children belong to the instances, not to the template
		end
	end
	for key in pairs(copy:GetAttributes()) do
		copy:SetAttribute(key, nil)
	end
	for _, tag in ipairs(copy:GetTags()) do
		copy:RemoveTag(tag)
	end
	if math.abs(copy:GetScale() - 1) > 1e-4 then
		copy:ScaleTo(1)
	end
	if not copy.PrimaryPart then
		local parts = {}
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		assert(#parts > 0, "capture: the instance has no parts")
		local pivot = copy:GetPivot()
		local primary = largest(parts)
		copy.PrimaryPart = primary
		primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot)
	end
	copy:PivotTo(CFrame.identity)
	copy.Name = propId
	copy:SetAttribute("MapPropId", propId)
	local old = folder:FindFirstChild(propId)
	if old then
		local oldVariants = old:FindFirstChild(VARIANTS)
		if oldVariants and not copy:FindFirstChild(VARIANTS) then
			oldVariants:Clone().Parent = copy
		end
		local previous = folder:FindFirstChild(PREVIOUS) or Instance.new("Folder")
		previous.Name = PREVIOUS
		previous.Parent = folder
		local stale = previous:FindFirstChild(propId)
		if stale then
			stale:Destroy()
		end
		old.Parent = previous
	end
	copy.Parent = folder
	local source = shortPath(instance) -- (before the run: the run replaces the captured instance too)
	local report = SyncMapProps.run({ only = { propId } })
	return (if #warnings > 0 then table.concat(warnings, "\n") .. "\n" else "") .. `captured {source} as ServerStorage.{FOLDER}.{propId}`
		.. (if nested > 0 then ` (with {nested} nested prop(s))` else "") .. "\n" .. report
end

function SyncMapProps.undoCapture(propId: string): string
	local folder = templateFolder(false)
	local previous = folder and folder:FindFirstChild(PREVIOUS)
	local old = previous and previous:FindFirstChild(propId)
	assert(old, `undoCapture: no previous template for {propId}`)
	local current = (folder :: Folder):FindFirstChild(propId)
	if current then
		current.Parent = previous
	end
	old.Parent = folder
	if current then
		current.Name = propId -- (kept as the new "previous", so undo can be undone)
	end
	return `restored the previous {propId} template\n` .. SyncMapProps.run({ only = { propId } })
end

---------------------------------------------------------------------
-- tagging (inventory rules) and checks
---------------------------------------------------------------------
local function tagModel(model: Model, propId: string, variant: string?): boolean
	if model:HasTag(TAG) and model:GetAttribute("MapPropId") == propId then
		return false
	end
	model:AddTag(TAG)
	model:SetAttribute("MapPropId", propId)
	if variant and model:GetAttribute("Variant") == nil then
		model:SetAttribute("Variant", variant)
	end
	return true
end

function SyncMapProps.find(propId: string, forBackup: boolean?): ({ Instance }, { Instance })
	-- returns (top-level instances matched by the rules, host models of the embedded groups;
	-- forBackup adds the HOSTS models)
	local names: { [string]: boolean } = {}
	local hubNames: { [string]: boolean } = {}
	local filter: ((Instance) -> boolean)? = nil
	local match: ((Instance) -> boolean)? = nil
	for _, rule in ipairs(SyncMapProps.RULES) do
		if rule.propId == propId then
			filter = rule.filter
			match = rule.match
			for _, n in ipairs(rule.names) do
				names[n] = true
			end
			for _, n in ipairs(rule.hubNames or {}) do
				hubNames[n] = true
			end
		end
	end
	local hostNames: { [string]: boolean } = {}
	local hostFilter = nil
	for _, rule in ipairs(SyncMapProps.EMBEDDED) do
		if rule.propId == propId then
			for _, n in ipairs(rule.hosts) do
				hostNames[n] = true
			end
			hostFilter = rule.hostFilter
		end
	end
	local hostTest = if forBackup then SyncMapProps.HOSTS[propId] else nil
	local found, hosts = {}, {}
	local hub = workspace:FindFirstChild("Hub")
	for _, root in ipairs(searchRoots()) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") then
				if (names[d.Name] and (filter == nil or filter(d))) or (hubNames[d.Name] and d.Parent == hub) or (match ~= nil and match(d)) then
					table.insert(found, d)
				elseif (hostNames[d.Name] and (not hostFilter or hostFilter(d))) or (hostTest and hostTest(d)) then
					table.insert(hosts, d)
				end
			end
		end
	end
	return found, hosts
end

function SyncMapProps.tagAll(opts: any?): string
	opts = opts or {}
	local wanted: { [string]: boolean }? = nil
	if opts.only then
		wanted = {}
		for _, id in ipairs(opts.only) do
			(wanted :: any)[id] = true
		end
	end
	local counts = {}
	local function bump(propId: string, key: string)
		counts[propId] = counts[propId] or { tagged = 0, already = 0, wrapped = 0 }
		counts[propId][key] += 1
	end
	for _, rule in ipairs(SyncMapProps.RULES) do
		if wanted and not wanted[rule.propId] then
			continue
		end
		local found = SyncMapProps.find(rule.propId)
		for _, model in ipairs(found) do
			if tagModel(model :: Model, rule.propId, if rule.variant then rule.variant(model) else nil) then
				bump(rule.propId, "tagged")
			else
				bump(rule.propId, "already")
			end
		end
		task.wait()
	end
	for _, rule in ipairs(SyncMapProps.EMBEDDED) do
		if wanted and not wanted[rule.propId] then
			continue
		end
		local _, hosts = SyncMapProps.find(rule.propId)
		for _, host in ipairs(hosts) do
			local existing = nil
			for _, child in ipairs(host:GetChildren()) do
				if child:IsA("Model") and child.Name == rule.wrapper and child:GetAttribute("MapPropId") == rule.propId then
					existing = child
				end
			end
			if existing then
				bump(rule.propId, "already")
				continue
			end
			for _, group in ipairs(rule.groups(host)) do
				local wrapper = Instance.new("Model")
				wrapper.Name = rule.wrapper
				if math.abs(group.scale - 1) > 1e-4 then
					wrapper:ScaleTo(group.scale) -- empty: resizes nothing, records the scale
				end
				wrapper.WorldPivot = group.pivot
				for _, part in ipairs(group.parts) do
					part.Parent = wrapper
				end
				wrapper.WorldPivot = group.pivot
				tagModel(wrapper, rule.propId, nil)
				wrapper:SetAttribute("MapPropEmbedded", true)
				wrapper.Parent = host
				bump(rule.propId, "wrapped")
			end
		end
	end
	local lines = { "SyncMapProps.tagAll" }
	local ids = {}
	for id in pairs(counts) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local c = counts[id]
		table.insert(lines, `{id}: newly tagged {c.tagged}, embedded wrapped+tagged {c.wrapped}, already tagged {c.already}`)
	end
	return table.concat(lines, "\n")
end

function SyncMapProps.check(): string
	local list = templates(nil)
	local prints = {}
	for id, template in pairs(list) do
		prints[id] = fingerprint(template)
	end
	local per = {}
	local seen = {}
	local lines = { "SyncMapProps.check" }
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		if isTemplateArea(inst) then
			if inst.Parent and inst.Parent.Name == FOLDER then -- (a nested prop inside a template is normal)
				table.insert(lines, "  WARNING tagged template: " .. inst:GetFullName())
			end
			continue
		end
		local id = inst:GetAttribute("MapPropId")
		if type(id) ~= "string" then
			table.insert(lines, "  WARNING tagged without MapPropId: " .. inst:GetFullName())
			continue
		end
		local p = per[id] or { n = 0, stale = 0, places = {} }
		per[id] = p
		p.n += 1
		if prints[id] then
			local variant = inst:GetAttribute("Variant")
			if inst:GetAttribute("MapPropVersion") ~= prints[id] .. "|" .. (if type(variant) == "string" then variant else "") then
				p.stale += 1
			end
		end
		local path = inst:GetFullName()
		local place = if string.find(path, "^Workspace%._Staging") then "test"
			elseif string.find(path, "^Workspace%.Hub") then "hub"
			elseif string.find(path, "^Workspace%.Zones") then "zones"
			else "storage"
		p.places[place] = (p.places[place] or 0) + 1
		if inst:IsA("Model") and inst.Parent then
			local pos = inst:GetPivot().Position
			local key = id .. "@" .. inst.Parent:GetFullName() .. "@" .. string.format("%.2f,%.2f,%.2f", pos.X, pos.Y, pos.Z)
			if seen[key] then
				table.insert(lines, "  WARNING possible duplicate: " .. path)
			end
			seen[key] = true
		end
	end
	local ids = {}
	for id in pairs(per) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local p = per[id]
		local places = {}
		for k, v in pairs(p.places) do
			table.insert(places, `{k} {v}`)
		end
		table.sort(places)
		local state = if list[id] then (if p.stale > 0 then `{p.stale} OUT OF DATE` else "all up to date") else "no template yet"
		table.insert(lines, `{id}: {p.n} tagged ({table.concat(places, ", ")}), {state}`)
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- per-model backup through the log (tools/collect_backup.py writes BackUP_Files/<folder>/<propId>.rbxm)
---------------------------------------------------------------------
function SyncMapProps.backup(folderName: string, propIds: { string }): string
	assert(string.match(folderName, "^[%w_%-]+$"), "backup: folder name must be letters, digits, _ or -")
	local report, manifest = {}, {}
	for _, propId in ipairs(propIds) do
		assert(string.match(propId, "^[%w_%-]+$"), "backup: bad propId " .. propId)
		local found, hosts = SyncMapProps.find(propId, true)
		local list = {}
		local seen = {}
		for _, inst in ipairs(found) do
			table.insert(list, inst)
			seen[inst] = true
		end
		for _, inst in ipairs(hosts) do
			if not seen[inst] then
				table.insert(list, inst)
			end
		end
		for _, inst in ipairs(instancesOf(propId)) do -- tagged ones (wrappers) not covered above
			local covered = seen[inst]
			for _, h in ipairs(hosts) do
				if inst:IsDescendantOf(h) then
					covered = true
				end
			end
			if not covered then
				table.insert(list, inst)
			end
		end
		if #list == 0 then
			table.insert(report, `{propId}: nothing found`)
			continue
		end
		table.insert(manifest, `## {propId} ({#list} instances, in file order)`)
		for i, inst in ipairs(list) do
			local p = (inst :: Model):GetPivot()
			local _, yaw = p:ToEulerAnglesYXZ()
			table.insert(manifest, string.format("%d. %s | pivot (%.3f, %.3f, %.3f) yaw %.1f | scale %.3f", i, inst:GetFullName(), p.X, p.Y, p.Z, math.deg(yaw), (inst :: Model):GetScale()))
		end
		local ok, result = pcall(function()
			return SerializationService:SerializeInstancesAsync(list)
		end)
		if not ok then
			table.insert(report, `FAILED {propId}: {result}`)
			continue
		end
		local id = `{folderName}/{propId}`
		local b64 = buffer.tostring(EncodingService:Base64Encode(result))
		local count = math.ceil(#b64 / CHUNK)
		print(`FYDBAK|{id}|HEAD|{count}|{#b64}|{buffer.len(result)}`)
		for i = 1, count do
			print(`FYDBAK|{id}|{i}|{string.sub(b64, (i - 1) * CHUNK + 1, i * CHUNK)}`)
			if i % 200 == 0 then
				task.wait()
			end
		end
		print(`FYDBAK|{id}|TAIL`)
		table.insert(report, `{id}.rbxm: {#list} instances, {buffer.len(result)} bytes, {count} chunks`)
		task.wait()
	end
	return table.concat(report, "\n") .. "\n\nMANIFEST\n" .. table.concat(manifest, "\n")
end

return SyncMapProps
