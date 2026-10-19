--[[
	StudioProps (dev tool, Edit mode only) - builders of the Studio-made upgraded props
	(docs/model_upgrade_brief.txt sections 5 and 9, docs/prop_inventory.md). Source of truth: tools/StudioProps.luau.
	Each builder returns a template Model at the origin: pivot = bottom centre on Y 0, front = -Z, scale 1, the same
	footprint as the old kit model (+10% max), a PrimaryPart, every part Anchored and CanTouch false, CanQuery and
	CastShadow only on the parts that need them.

	Usage (execute_luau, Edit):
		local Props = require(game.ServerStorage.DevTools.StudioProps:Clone())
		print(Props.install("crate"))      -- (re)builds ServerStorage.MapProps.crate (the old template goes to _Previous)
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "crate" } }))
	Stalls after the Blender import (MapProps.<stall> has MapPropPieces): install() rebuilds the bare frame from and into
	MapProps._Base.<stall> and leaves the pieces template alone; then ApplyPropMeshes.run({ only = { "<stall>" } })
	puts the pieces on the new frame.
	Materials: the shared tileable textures of the Prop Style Guide (Blender/Props/README.txt section 4, Agent A) as
	MaterialVariants MaterialService.FYD_<Family> (StudsPerTile 4): print(Props.materials()) creates / updates them.
	A part using one has Material = the variant's BaseMaterial, MaterialVariant = "FYD_<Family>", and Color = the
	guide's TINT (target colour / ColorMap mean: the near-white ColorMap multiplies the colour).
]]
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local StudioProps = {}

local rgb = Color3.fromRGB

-- texture sets (asset ids from Blender/Props/textures/textures.json, uploaded by Agent A on 2026-10-18; strings:
-- a number this long could print in exponent form)
local TEXTURES = {
	wood_grain = { Color = "89740758642776", Normal = "108234637428586", Roughness = "135239950193027" },
	wood_planks = { Color = "116360752066242", Normal = "75585161149742", Roughness = "78473445851411" },
	metal_iron = { Color = "135731262793033", Normal = "95603986153332", Roughness = "131380756886210", Metalness = "111789210470609" },
	metal_riveted = { Color = "136831119633013", Normal = "73927252058016", Roughness = "106383785359918", Metalness = "129055189097432" },
	stone_rough = { Color = "113595820216745", Normal = "118192687069902", Roughness = "131523483608455" },
	stone_blocks = { Color = "112829619167917", Normal = "80658067793442", Roughness = "104665814749700" },
	cloth_canvas = { Color = "112531479292946", Normal = "135306887519638", Roughness = "107308943025432" },
	straw_woven = { Color = "90752857691370", Normal = "73615548184266", Roughness = "81926772986745" },
	bone_ivory = { Color = "129326962762155", Normal = "123401090557220", Roughness = "116742375558344" },
}
local POLISHED_ROUGHNESS = "76471974811432"

-- MaterialService.<name> = { base material, texture set, roughness override } (README section 4)
StudioProps.VARIANTS = {
	FYD_Wood = { Base = Enum.Material.Wood, Set = "wood_grain" },
	FYD_Planks = { Base = Enum.Material.WoodPlanks, Set = "wood_planks" },
	FYD_Iron = { Base = Enum.Material.Metal, Set = "metal_iron" },
	FYD_Gold = { Base = Enum.Material.Metal, Set = "metal_iron", Roughness = POLISHED_ROUGHNESS },
	FYD_Riveted = { Base = Enum.Material.Metal, Set = "metal_riveted" },
	FYD_Stone = { Base = Enum.Material.Slate, Set = "stone_rough" },
	FYD_StoneBlocks = { Base = Enum.Material.Cobblestone, Set = "stone_blocks" },
	FYD_Moss = { Base = Enum.Material.Grass, Set = "stone_rough" },
	FYD_Cloth = { Base = Enum.Material.Fabric, Set = "cloth_canvas" },
	FYD_Straw = { Base = Enum.Material.Fabric, Set = "straw_woven" },
	FYD_Bone = { Base = Enum.Material.SmoothPlastic, Set = "bone_ivory" },
}

---------------------------------------------------------------------
-- LOW-POLY (owner correction of 2026-10-19, docs/model_upgrade_brief.txt top block, docs/prop_texture_guide.md): no
-- realistic textures. install() runs lowPoly() on the built template:
--   - every part made with a FYD_* MaterialVariant becomes SmoothPlastic, no variant, Color = the palette colour it
--     must LOOK like (the variant's tint x the ColorMap mean; the clamped light tints by name);
--   - the guide's gradient on Parts: 3 bands by the height of the part's centre in the model (lowest 25 % x 0.90,
--     25-60 % x 0.96, top 40 % the palette colour; the stalls up to their roof); Neon, Glass and invisible parts are
--     not banded; nested props (the lamp post's lantern) keep their own template's look. The unbanded colour is kept
--     in the part's attribute LowPolyColor, so a rebuild of a stall from its current template does not darken it
--     twice;
--   - the _Variants recolours (Color_<Part>) get the same conversion;
--   - the stylized overlays (OVERLAYS below: plank_lines, stone_block_lines) as Texture instances, StudsPerTile 4,
--     once Config/PropTextures holds their ids.
---------------------------------------------------------------------
StudioProps.LOWPOLY = true
StudioProps.LOWPOLY_MATERIAL = Enum.Material.SmoothPlastic
-- ColorMap means of the texture sets (PropMeshData Textures.*.ColorMean); Gold's tint is its hex already
local MEAN = {
	FYD_Wood = 0.9, FYD_Planks = 0.965, FYD_Iron = 0.88, FYD_Gold = 1, FYD_Riveted = 0.904, FYD_Stone = 0.88,
	FYD_StoneBlocks = 0.909, FYD_Moss = 0.88, FYD_Cloth = 0.9, FYD_Straw = 0.88, FYD_Bone = 0.952,
}
-- the light tints the guide clamped at 255 (tint != hex / mean): their hex (Blender/Props/README.txt section 2)
local EXACT = {
	["228,175,52"] = rgb(201, 154, 46), ["255,248,229"] = rgb(232, 226, 208), ["250,251,255"] = rgb(245, 246, 250),
	["255,216,104"] = rgb(236, 200, 96), ["255,236,167"] = rgb(244, 226, 160), ["252,244,219"] = rgb(240, 232, 208),
}
-- (docs/prop_texture_guide.md section 3 = these hexes; a tint whose guide colour changes: "r,g,b" tint -> hex here)
StudioProps.PALETTE = {} :: { [string]: Color3 }

local function key(c: Color3): string
	return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

local function flat(color: Color3, variant: string): Color3
	local k = key(color)
	if StudioProps.PALETTE[k] then
		return StudioProps.PALETTE[k]
	end
	if EXACT[k] then
		return EXACT[k]
	end
	local m = MEAN[variant] or 1
	return Color3.fromRGB(math.round(math.min(color.R * m, 1) * 255), math.round(math.min(color.G * m, 1) * 255), math.round(math.min(color.B * m, 1) * 255))
end

local function scaled(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- the guide's band factor of a height fraction t (0 = the model's bottom, 1 = its top)
local function band(t: number): number
	return if t < 0.25 then 0.90 elseif t < 0.60 then 0.96 else 1
end

-- the 3 stalls are banded up to their roof (the top of the "Awning" parts), not to the top of the whole model: the
-- diamond shop's sign rises 9 studs above its roof and would otherwise put its counter and posts a band darker than
-- the same frame of the two other stalls
local BAND_TOP_PART = { weapon_stall = "Awning", trophy_stall = "Awning", diamond_shop = "Awning" }

local function topOf(part: BasePart): number
	local cf, s = part.CFrame, part.Size
	return cf.Position.Y + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
end

-- inside a nested prop of the model (the lamp post's lantern: it has its own template)
local function inNestedProp(d: Instance, model: Instance): boolean
	local p = d.Parent
	while p and p ~= model do
		if p:IsA("Model") and p:HasTag("MapProp") then
			return true
		end
		p = p.Parent
	end
	return false
end

-- stylized overlays on Studio parts (docs/prop_texture_guide.md section 5): propId -> { part name = overlay name }.
-- Only the plain surfaces: the parts already built as separate planks (the crate's sides and lid, the stalls' counter
-- front rows and back boards) get none (a Texture cannot turn, so plank_lines would cross those planks). The faces:
-- the two large faces of a board (its thinnest axis), the top of a counter top, the four sides of a plinth.
StudioProps.OVERLAYS = {
	lamp_post = { Plinth = "stone_block_lines" },
	weapon_stall = { CounterTop = "plank_lines", SidePanel = "plank_lines" },
	trophy_stall = { CounterTop = "plank_lines", SidePanel = "plank_lines" },
	diamond_shop = { CounterTop = "plank_lines", SidePanel = "plank_lines" },
}

-- the asset id of an overlay in Config/PropTextures (nil until Agent A uploads it)
local function overlayId(name: string): string?
	local config = game:GetService("ReplicatedStorage").GameSystem.Config:FindFirstChild("PropTextures")
	if not config then
		return nil
	end
	local copy = config:Clone()
	copy.Parent = config.Parent
	local ok, textures = pcall(require, copy)
	copy:Destroy()
	if not ok or type(textures) ~= "table" then
		return nil
	end
	local entry = (type(textures.Ids) == "table" and textures.Ids[name]) or textures[name] or (type(textures.Textures) == "table" and textures.Textures[name])
	local id = if type(entry) == "string" then entry elseif type(entry) == "table" then (entry.Id or entry.ColorMap or entry.Texture) else nil
	if type(id) == "number" then
		id = "rbxassetid://" .. tostring(id)
	end
	return if type(id) == "string" and id ~= "" then id else nil
end

local function faceList(part: BasePart, name: string): { Enum.NormalId }
	local s = part.Size
	if name == "CounterTop" then
		return { Enum.NormalId.Top }
	elseif name == "Plinth" then
		return { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	elseif s.X <= s.Y and s.X <= s.Z then
		return { Enum.NormalId.Left, Enum.NormalId.Right }
	elseif s.Z <= s.X and s.Z <= s.Y then
		return { Enum.NormalId.Front, Enum.NormalId.Back }
	end
	return { Enum.NormalId.Top, Enum.NormalId.Bottom }
end

-- the overlays of propId on its model (every old "Overlay" Texture of the model goes first: a part may have left
-- the table). Returns the count, or nil when an id is missing (Config/PropTextures not there yet; nothing changed)
local function addOverlays(model: Instance, propId: string): number?
	local spec = StudioProps.OVERLAYS[propId] or {}
	local ids = {}
	for _, overlay in pairs(spec) do
		ids[overlay] = ids[overlay] or overlayId(overlay)
		if not ids[overlay] then
			return nil
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		local parent = d.Parent
		if d:IsA("Texture") and d.Name == "Overlay" and parent and parent:IsA("BasePart") and not inNestedProp(parent, model) then
			d:Destroy()
		end
	end
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and spec[d.Name] and not inNestedProp(d, model) then
			for _, face in ipairs(faceList(d, d.Name)) do
				local tex = Instance.new("Texture")
				tex.Name = "Overlay"
				tex.Face = face
				tex.Texture = ids[spec[d.Name]]
				tex.StudsPerTileU = 4
				tex.StudsPerTileV = 4
				tex.Parent = d
				n += 1
			end
		end
	end
	return n
end

-- the low-poly look on a built template (see above). Returns the parts made flat, the parts banded and the overlay
-- count (nil = overlay ids missing)
function StudioProps.lowPoly(model: Model, propId: string?): (number, number, number?)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local height = math.max(size.Y, 0.01)
	local roofName = propId and BAND_TOP_PART[propId]
	if roofName then
		local roof = -math.huge
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == roofName then
				roof = math.max(roof, topOf(d))
			end
		end
		if roof > bottom then
			height = math.max(roof - bottom, 0.01)
		end
	end
	local flatParts, banded = 0, 0
	local variantOf: { [string]: string } = {}
	local bandOf: { [string]: number } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if not d:IsA("BasePart") or d:IsA("PartOperation") or inNestedProp(d, model) then
			continue -- (a union keeps the colours of its pieces: the builder shades them)
		end
		local fyd = string.sub(d.MaterialVariant, 1, 4) == "FYD_"
		local base = d:GetAttribute("LowPolyColor")
		if typeof(base) ~= "Color3" then
			base = if fyd then flat(d.Color, d.MaterialVariant) else d.Color
		end
		if fyd then
			variantOf[d.Name] = variantOf[d.Name] or d.MaterialVariant
			d.Material = StudioProps.LOWPOLY_MATERIAL
			d.MaterialVariant = ""
			flatParts += 1
		end
		local plain = d.Material ~= Enum.Material.Neon and d.Material ~= Enum.Material.Glass and d.Transparency < 1
		if plain then
			local f = band((d.Position.Y - bottom) / height)
			d:SetAttribute("LowPolyColor", base)
			d.Color = scaled(base :: Color3, f)
			bandOf[d.Name] = bandOf[d.Name] or f
			banded += 1
		elseif fyd then
			d.Color = base :: Color3
		end
	end
	-- the recolour variants of the parts made flat in this pass (fresh builds only)
	for _, folder in ipairs(model:GetDescendants()) do
		if folder:IsA("Folder") and folder.Name == "_Variants" then
			for _, config in ipairs(folder:GetChildren()) do
				for name, value in pairs(config:GetAttributes()) do
					local partName = string.match(name, "^Color_(.+)$")
					if partName and variantOf[partName] and typeof(value) == "Color3" then
						config:SetAttribute(name, scaled(flat(value, variantOf[partName]), bandOf[partName] or 1))
					end
				end
			end
		end
	end
	local overlays = if propId then addOverlays(model, propId) else 0
	return flatParts, banded, overlays
end

-- the overlays alone on the current template (and on the bare frame MapProps._Base.<propId> of a pieces stall), no
-- rebuild: MapProps._Previous keeps the template from before the low-poly pass. Then SyncMapProps.run()
function StudioProps.applyOverlays(propId: string): string
	local folder = ServerStorage:FindFirstChild("MapProps")
	local targets = {}
	for _, place in ipairs({ folder, folder and folder:FindFirstChild("_Base") }) do
		local model = place and place:FindFirstChild(propId)
		if model and model:IsA("Model") then
			table.insert(targets, model)
		end
	end
	if #targets == 0 then
		return `{propId}: no template`
	end
	local counts = {}
	for _, model in ipairs(targets) do
		local n = addOverlays(model, propId)
		if n == nil then
			return `{propId}: refused, an overlay id is missing in Config/PropTextures`
		end
		table.insert(counts, `{n} on {model:GetFullName()}`)
	end
	return `{propId}: overlay textures ` .. table.concat(counts, ", ")
end

-- the parts of the place that still use a FYD_* variant (outside MaterialService). The undo copies in
-- ServerStorage.MapProps._Previous (never in the game) are left out unless includePrevious; the second result is
-- their count
function StudioProps.realisticUsers(includePrevious: boolean?): ({ string }, number)
	local list, previousCount = {}, 0
	local maps = ServerStorage:FindFirstChild("MapProps")
	local previous = maps and maps:FindFirstChild("_Previous")
	local roots = { workspace, ServerStorage, game:GetService("ReplicatedStorage"), game:GetService("StarterPack"), game:GetService("StarterGui"), game:GetService("Lighting"), game:GetService("StarterPlayer"), game:GetService("ReplicatedFirst") }
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and StudioProps.VARIANTS[d.MaterialVariant] then
				if previous and d:IsDescendantOf(previous) then
					previousCount += 1
					if not includePrevious then
						continue
					end
				end
				table.insert(list, d:GetFullName())
			end
		end
	end
	return list, previousCount
end

-- deletes the FYD_* MaterialVariants once no part of the game uses them. The undo templates in MapProps._Previous
-- keep the variant names: restored, they show their base material until StudioProps.materials() (LOWPOLY = false)
-- makes the variants again from the same texture ids
function StudioProps.removeRealisticVariants(): string
	local users, previousCount = StudioProps.realisticUsers()
	if #users > 0 then
		return `refused: {#users} part(s) still use a FYD_* variant, e.g. {users[1]}`
	end
	local removed = {}
	for name in pairs(StudioProps.VARIANTS) do
		local mv = MaterialService:FindFirstChild(name)
		if mv and mv:IsA("MaterialVariant") then
			mv:Destroy()
			table.insert(removed, name)
		end
	end
	table.sort(removed)
	return `removed {#removed} MaterialVariant(s): {table.concat(removed, ", ")}` .. (if previousCount > 0 then ` ({previousCount} part(s) of the undo templates in MapProps._Previous still name them)` else "")
end

function StudioProps.materials(): string
	if StudioProps.LOWPOLY then
		return "refused: low-poly mode (StudioProps.LOWPOLY): the realistic FYD_* variants are not used any more"
	end
	local made, updated = 0, 0
	for name, spec in pairs(StudioProps.VARIANTS) do
		local set = TEXTURES[spec.Set]
		local mv = MaterialService:FindFirstChild(name)
		if mv and mv:IsA("MaterialVariant") then
			updated += 1
		else
			mv = Instance.new("MaterialVariant")
			mv.Name = name
			made += 1
		end
		local variant = mv :: MaterialVariant
		variant.BaseMaterial = spec.Base
		variant.StudsPerTile = 4
		variant.MaterialPattern = Enum.MaterialPattern.Regular
		variant.ColorMap = `rbxassetid://{set.Color}`
		variant.NormalMap = `rbxassetid://{set.Normal}`
		variant.RoughnessMap = `rbxassetid://{spec.Roughness or set.Roughness}`
		variant.MetalnessMap = if set.Metalness then `rbxassetid://{set.Metalness}` else ""
		variant.Parent = MaterialService
	end
	return `MaterialService: {made} MaterialVariant(s) created, {updated} updated`
end

-- one part; opts: name, size, cf, color, material, collide, query, shadow, shape, variant (MaterialVariant)
local function part(model: Model, opts: any): Part
	local p = Instance.new("Part")
	p.Name = opts.name
	p.Shape = opts.shape or Enum.PartType.Block
	p.Size = opts.size
	p.CFrame = opts.cf
	p.Color = opts.color
	p.Material = opts.material or Enum.Material.Wood
	if opts.variant then
		p.MaterialVariant = opts.variant
	end
	p.Anchored = true
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.query == true or opts.collide == true
	p.CanTouch = false
	p.CastShadow = opts.shadow == true
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function variants(model: Model, list: { [string]: { [string]: any } })
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for name, attributes in pairs(list) do
		local config = Instance.new("Configuration")
		config.Name = name
		for key, value in pairs(attributes) do
			config:SetAttribute(key, value)
		end
		config.Parent = folder
	end
	folder.Parent = model
end

---------------------------------------------------------------------
-- 03/12 CRATE  (old Crate_A: 4 x 4 x 4, 9 parts)
-- planks with gaps over a dark core, an edge frame (bottom board, corner posts, worn top rims), diagonal braces on
-- the +-Z faces (as before), iron corner caps, nails, a lid of 3 planks slightly offset. 39 parts.
---------------------------------------------------------------------
function StudioProps.crate(): Model
	local m = Instance.new("Model")
	m.Name = "crate"
	-- guide tints (README section 2): planks WoodLight 238,167,102, frame WoodMid 187,109,62, iron 105,111,125,
	-- with a small per-row / worn-edge variation
	local WOOD, IRONV = "FYD_Wood", "FYD_Iron"
	local FRAME, FRAME_DARK, WORN = rgb(187, 109, 62), rgb(176, 102, 58), rgb(204, 122, 72)
	local PLANK = { rgb(230, 160, 96), rgb(238, 167, 102), rgb(245, 175, 108) }
	local LID = { rgb(190, 111, 63), rgb(180, 104, 59), rgb(197, 117, 67) }
	local IRON, NAIL = rgb(122, 127, 139), rgb(88, 90, 98)

	local core = part(m, { name = "Core", size = Vector3.new(3.5, 3.2, 3.5), cf = CFrame.new(0, 2.0, 0), color = rgb(100, 56, 32), collide = true, shadow = true, variant = WOOD })
	part(m, { name = "Bottom", size = Vector3.new(4.0, 0.4, 4.0), cf = CFrame.new(0, 0.2, 0), color = FRAME_DARK, collide = true, variant = WOOD })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(m, { name = "Post", size = Vector3.new(0.5, 3.2, 0.5), cf = CFrame.new(1.75 * sx, 2.0, 1.75 * sz), color = FRAME, collide = true, variant = WOOD })
			part(m, { name = "Cap", size = Vector3.new(0.56, 0.44, 0.56), cf = CFrame.new(1.75 * sx, 3.36, 1.75 * sz), color = IRON, material = Enum.Material.Metal, variant = IRONV })
		end
	end
	-- top rims (lighter: worn where things are put down) and the planks of the four sides
	local rows = { 0.84, 1.80, 2.76 }
	local rowNames = { "PlankA", "PlankB", "PlankC" }
	for _, s in ipairs({ -1, 1 }) do
		part(m, { name = "Rim", size = Vector3.new(3.0, 0.4, 0.3), cf = CFrame.new(0, 3.4, 1.85 * s), color = WORN, collide = true, variant = WOOD })
		part(m, { name = "Rim", size = Vector3.new(0.3, 0.4, 3.0), cf = CFrame.new(1.85 * s, 3.4, 0), color = WORN, collide = true, variant = WOOD })
		for i, y in ipairs(rows) do -- the planks collide so the sides stay solid at 1.95 (old crate: 1.85-1.98)
			part(m, { name = rowNames[i], size = Vector3.new(3.0, 0.88, 0.2), cf = CFrame.new(0, y, 1.85 * s), color = PLANK[i], collide = true, variant = WOOD })
			part(m, { name = rowNames[i], size = Vector3.new(0.2, 0.88, 3.0), cf = CFrame.new(1.85 * s, y, 0), color = PLANK[i], collide = true, variant = WOOD })
		end
		-- diagonal brace across the +-Z face (mirrored), two nails at its ends
		local angle = math.rad(46.97) * -s
		local brace = CFrame.new(0, 1.8, 2.01 * s) * CFrame.Angles(0, 0, angle)
		part(m, { name = "Brace", size = Vector3.new(0.42, 4.0, 0.12), cf = brace, color = FRAME_DARK, variant = WOOD })
		for _, t in ipairs({ -1.7, 1.7 }) do
			local p = brace * Vector3.new(0, t, 0)
			part(m, { name = "Nail", size = Vector3.new(0.14, 0.14, 0.06), cf = CFrame.new(p.X, p.Y, 2.1 * s), color = NAIL, material = Enum.Material.Metal, variant = IRONV })
		end
		-- two nails holding the middle plank of the +-X face
		for _, z in ipairs({ -1.3, 1.3 }) do
			part(m, { name = "Nail", size = Vector3.new(0.06, 0.14, 0.14), cf = CFrame.new(1.98 * s, 1.8, z), color = NAIL, material = Enum.Material.Metal, variant = IRONV })
		end
	end
	-- lid: 3 planks, slightly shifted and turned (not quite closed straight)
	local lid = CFrame.new(0.08, 3.8, -0.06) * CFrame.Angles(0, math.rad(2), 0)
	for i, z in ipairs({ -1.33, 0, 1.33 }) do
		part(m, { name = ({ "LidA", "LidB", "LidC" })[i], size = Vector3.new(3.9, 0.4, 1.24), cf = lid * CFrame.new(0, 0, z), color = LID[i], collide = true, shadow = true, variant = WOOD })
	end
	m.PrimaryPart = core
	core.PivotOffset = CFrame.new(0, -2.0, 0) -- pivot at the bottom centre, like Crate_A
	m:SetAttribute("MapPropId", "crate")
	-- Abyss_2 recolour of the old crate (dark wet wood, greenish iron)
	variants(m, {
		Sunken = {
			Color_Core = rgb(44, 34, 29), Color_Bottom = rgb(84, 64, 54), Color_Post = rgb(79, 61, 51), Color_Rim = rgb(104, 81, 68),
			Color_PlankA = rgb(86, 66, 55), Color_PlankB = rgb(92, 71, 59), Color_PlankC = rgb(98, 76, 63), Color_Brace = rgb(82, 63, 53),
			Color_LidA = rgb(95, 73, 61), Color_LidB = rgb(87, 67, 56), Color_LidC = rgb(101, 78, 65),
			Color_Cap = rgb(66, 76, 76), Color_Nail = rgb(52, 58, 58),
		},
	})
	return m
end

-- a standing cylinder (Roblox cylinders run along X: turned 90 degrees about Z)
local UP = CFrame.Angles(0, 0, math.rad(90))
local function cylinder(model: Model, opts: any): Part
	opts.shape = Enum.PartType.Cylinder
	opts.size = Vector3.new(opts.height, opts.diameter, opts.diameter)
	opts.cf = (opts.cf or CFrame.new()) * UP
	return part(model, opts)
end

---------------------------------------------------------------------
-- 15 LANTERN  (old units: glass Neon 1.2 x 1.5 + caps; the template's PIVOT = the centre of the old glass,
-- glass height reference 1.5, see SyncMapProps.REF; the bottom at -1.125 keeps the TutorialGuide lantern (scale 0.8)
-- on its rim). Iron frame with 4 corner posts, glowing cream panes (Neon, T 0.5), a candle with a small Neon flame
-- ("Flame", PointLight of Config/PropFX), top plate, stepped roof and a ring handle. 14 parts.
---------------------------------------------------------------------
local function propFxLights(propId: string): { any }
	local module = game:GetService("ReplicatedStorage").GameSystem.Config.PropFX
	local copy = module:Clone() -- (require caches modules)
	copy.Parent = module.Parent
	local ok, config = pcall(require, copy)
	copy:Destroy()
	local entry = ok and config.Props[propId]
	return entry and entry.Lights or {}
end

function StudioProps.lantern(): Model
	local m = Instance.new("Model")
	m.Name = "lantern"
	local IRON, IRONV = rgb(105, 111, 125), "FYD_Iron"
	part(m, { name = "Base", size = Vector3.new(1.5, 0.26, 1.5), cf = CFrame.new(0, -0.995, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV, collide = true })
	-- the panes glow softly (Neon at T 0.5) so the lantern keeps the old cream glow; the candle and flame show through
	local glass = part(m, { name = "Glass", size = Vector3.new(1.16, 1.55, 1.16), cf = CFrame.new(0, -0.09, 0), color = rgb(255, 226, 150), material = Enum.Material.Neon, transparency = 0.5, collide = true })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(m, { name = "Frame", size = Vector3.new(0.14, 1.55, 0.14), cf = CFrame.new(0.6 * sx, -0.09, 0.6 * sz), color = IRON, material = Enum.Material.Metal, variant = IRONV })
		end
	end
	part(m, { name = "Top", size = Vector3.new(1.5, 0.22, 1.5), cf = CFrame.new(0, 0.795, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	part(m, { name = "Roof", size = Vector3.new(1.0, 0.2, 1.0), cf = CFrame.new(0, 1.005, 0) * CFrame.Angles(0, math.rad(45), 0), color = rgb(92, 98, 112), material = Enum.Material.Metal, variant = IRONV })
	part(m, { name = "RoofTop", size = Vector3.new(0.5, 0.16, 0.5), cf = CFrame.new(0, 1.185, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	for _, x in ipairs({ -0.2, 0.2 }) do
		part(m, { name = "Handle", size = Vector3.new(0.08, 0.32, 0.08), cf = CFrame.new(x, 1.42, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	end
	part(m, { name = "Handle", size = Vector3.new(0.48, 0.08, 0.08), cf = CFrame.new(0, 1.58, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	cylinder(m, { name = "Candle", height = 0.34, diameter = 0.3, cf = CFrame.new(0, -0.695, 0), color = rgb(240, 228, 196), material = Enum.Material.SmoothPlastic })
	local flame = part(m, { name = "Flame", size = Vector3.new(0.26, 0.26, 0.26), cf = CFrame.new(0, -0.38, 0), color = rgb(255, 186, 84), material = Enum.Material.Neon, shape = Enum.PartType.Ball })
	for _, spec in ipairs(propFxLights("lantern")) do
		if spec.Part == "Flame" then
			local light = Instance.new("PointLight")
			light.Color, light.Brightness, light.Range, light.Shadows = spec.Color, spec.Brightness, spec.Range, false
			light.Parent = flame
		end
	end
	m.PrimaryPart = glass
	glass.PivotOffset = CFrame.new(0, 0.09, 0) -- pivot = centre of the old glass
	m:SetAttribute("MapPropId", "lantern")
	return m
end

---------------------------------------------------------------------
-- 02 LAMP_POST  (old Lantern_Post: 3.85 x 9.75 x 1.50, 9 parts, pivot at the foot of the post, arm towards +X)
-- chipped stone plinth with an iron collar, a tapered post (lower / upper with an iron band), a cap, the arm with a
-- carved end and its brace, an iron bracket and hanger, a short chain, and the "lantern" template hanging from it
-- (a nested MapProp: it follows the lantern template). 13 parts + the lantern.
---------------------------------------------------------------------
function StudioProps.lamp_post(): Model
	local m = Instance.new("Model")
	m.Name = "lamp_post"
	local WOOD, WOODV = rgb(124, 69, 42), "FYD_Wood"
	local IRON, IRONV = rgb(105, 111, 125), "FYD_Iron"
	local STONE, STONEV = rgb(170, 177, 191), "FYD_Stone"
	part(m, { name = "Plinth", size = Vector3.new(1.5, 0.5, 1.5), cf = CFrame.new(0, 0.25, 0), color = STONE, material = Enum.Material.Slate, variant = STONEV, collide = true, shadow = true })
	part(m, { name = "PlinthTop", size = Vector3.new(1.0, 0.22, 1.0), cf = CFrame.new(0, 0.61, 0) * CFrame.Angles(0, math.rad(45), 0), color = rgb(150, 157, 172), material = Enum.Material.Slate, variant = STONEV, collide = true })
	part(m, { name = "Collar", size = Vector3.new(0.98, 0.4, 0.98), cf = CFrame.new(0, 0.92, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV, collide = true })
	local post = part(m, { name = "Post", size = Vector3.new(0.84, 4.9, 0.84), cf = CFrame.new(0, 3.17, 0), color = WOOD, variant = WOODV, collide = true, shadow = true })
	part(m, { name = "PostBand", size = Vector3.new(0.92, 0.22, 0.92), cf = CFrame.new(0, 5.62, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	part(m, { name = "PostTop", size = Vector3.new(0.74, 4.13, 0.74), cf = CFrame.new(0, 7.685, 0), color = rgb(132, 74, 45), variant = WOODV, collide = true, shadow = true })
	part(m, { name = "PostCap", size = Vector3.new(0.88, 0.2, 0.88), cf = CFrame.new(0, 9.82, 0), color = rgb(116, 64, 39), variant = WOODV })
	part(m, { name = "Arm", size = Vector3.new(2.95, 0.46, 0.46), cf = CFrame.new(1.1, 9.2, 0), color = WOOD, variant = WOODV, collide = true })
	part(m, { name = "ArmEnd", size = Vector3.new(0.38, 0.38, 0.46), cf = CFrame.new(2.72, 9.2, 0) * CFrame.Angles(0, 0, math.rad(45)), color = rgb(132, 74, 45), variant = WOODV })
	part(m, { name = "Brace", size = Vector3.new(0.42, 2.0, 0.42), cf = CFrame.new(0.9, 8.3, 0) * CFrame.Angles(0, 0, math.rad(-45)), color = WOOD, variant = WOODV })
	part(m, { name = "ArmBand", size = Vector3.new(0.82, 0.58, 0.82), cf = CFrame.new(0, 9.2, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	part(m, { name = "Hanger", size = Vector3.new(0.14, 0.32, 0.5), cf = CFrame.new(2.4, 8.82, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
	part(m, { name = "Chain", size = Vector3.new(0.1, 0.24, 0.06), cf = CFrame.new(2.4, 8.56, 0), color = rgb(80, 84, 96), material = Enum.Material.Metal, variant = IRONV })
	part(m, { name = "Chain", size = Vector3.new(0.06, 0.24, 0.1), cf = CFrame.new(2.4, 8.39, 0), color = rgb(80, 84, 96), material = Enum.Material.Metal, variant = IRONV })
	-- the improved lantern, hanging from the chain: glass centre 6.72 (handle top at 8.30)
	local maps = ServerStorage:FindFirstChild("MapProps")
	local source = maps and maps:FindFirstChild("lantern")
	assert(source, "lamp_post needs ServerStorage.MapProps.lantern: install the lantern first")
	local lantern = source:Clone()
	lantern.Name = "Lantern"
	lantern:PivotTo(CFrame.new(2.4, 6.72, 0))
	for key in pairs(lantern:GetAttributes()) do
		lantern:SetAttribute(key, nil)
	end
	lantern:SetAttribute("MapPropId", "lantern")
	lantern:SetAttribute("MapPropVersion", (source:GetAttribute("MapPropVersion") or "?") .. "|")
	lantern:AddTag("MapProp")
	lantern.Parent = m
	m.PrimaryPart = post
	post.PivotOffset = CFrame.new(0, -3.17, 0) -- pivot at the foot of the post, like Lantern_Post
	m:SetAttribute("MapPropId", "lamp_post")
	return m
end

---------------------------------------------------------------------
-- 03/10 BARREL  (old Barrel_A: 3.45 x 4.05 x 3.45, 5 parts; reference height 4.05 for the camp / market barrels)
-- staves: three stacked cylinders (worn bottom, bulging belly, top) in the shared planks texture, 3 dark-steel hoops
-- (two hide the belly steps) with rivets, a lid of planks. 13 parts. A truly faceted 12-16 stave barrel needs a
-- Blender mesh (part-built it costs about 28 parts x 11 copies in the hub).
---------------------------------------------------------------------
function StudioProps.barrel(): Model
	local m = Instance.new("Model")
	m.Name = "barrel"
	local PLANKS = "FYD_Planks"
	local IRON, IRONV = rgb(84, 89, 102), "FYD_Iron"
	cylinder(m, { name = "StaveLow", height = 1.05, diameter = 3.0, cf = CFrame.new(0, 0.525, 0), color = rgb(172, 100, 57), material = Enum.Material.WoodPlanks, variant = PLANKS, collide = true, shadow = true })
	local belly = cylinder(m, { name = "StaveBelly", height = 1.95, diameter = 3.38, cf = CFrame.new(0, 2.025, 0), color = rgb(187, 109, 62), material = Enum.Material.WoodPlanks, variant = PLANKS, collide = true, shadow = true })
	cylinder(m, { name = "StaveHigh", height = 1.02, diameter = 3.0, cf = CFrame.new(0, 3.51, 0), color = rgb(192, 113, 65), material = Enum.Material.WoodPlanks, variant = PLANKS, collide = true, shadow = true })
	cylinder(m, { name = "Lid", height = 0.05, diameter = 2.7, cf = CFrame.new(0, 4.025, 0), color = rgb(124, 69, 42), material = Enum.Material.WoodPlanks, variant = PLANKS })
	local hoops = { { y = 1.05, d = 3.46 }, { y = 3.0, d = 3.46 }, { y = 3.72, d = 3.08 } }
	for _, h in ipairs(hoops) do
		cylinder(m, { name = "Hoop", height = 0.3, diameter = h.d, cf = CFrame.new(0, h.y, 0), color = IRON, material = Enum.Material.Metal, variant = IRONV })
		for _, deg in ipairs({ 30, 210 }) do
			local a = math.rad(deg)
			local r = h.d / 2 + 0.02
			part(m, { name = "Rivet", size = Vector3.new(0.14, 0.14, 0.08), cf = CFrame.new(r * math.sin(a), h.y, r * math.cos(a)) * CFrame.Angles(0, a, 0), color = rgb(120, 124, 134), material = Enum.Material.Metal, variant = IRONV })
		end
	end
	m.PrimaryPart = belly
	belly.PivotOffset = (CFrame.new(0, 2.025, 0) * UP):ToObjectSpace(CFrame.new()) -- pivot at the bottom centre
	m:SetAttribute("MapPropId", "barrel")
	return m
end

---------------------------------------------------------------------
-- 11 LAUNDRY_RACK  (old: 4 square legs, a square crossbar, 2 hides; 8.4 x 6.9 x 4.05 in the rack's frame: X along
-- the crossbar, pivot on the camp floor under its middle)
-- round poles lashed with rope at the two apexes, a round crossbar, 3 cloths (orange, tan, light orange) draped over
-- the bar, each with a two-strip front (a fold) and a back flap ("ClothA/B/C": they sway, Config/PropFX), 6 pegs.
-- 22 parts.
---------------------------------------------------------------------
function StudioProps.laundry_rack(): Model
	local m = Instance.new("Model")
	m.Name = "laundry_rack"
	local WOOD, WOODV = rgb(124, 69, 42), "FYD_Wood"
	local ROPE, ROPEV = rgb(223, 182, 118), "FYD_Straw"
	local CLOTHV = "FYD_Cloth"
	for _, x in ipairs({ -3.5, 3.5 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- the old legs: centre (x, 3.3, 0.9 * sz), 7 long, tilted 15 degrees towards the bar
			local cf = CFrame.new(x, 3.3, 0.9 * sz) * CFrame.Angles(math.rad(-15 * sz), 0, 0)
			cylinder(m, { name = "Leg", height = 7.0, diameter = 0.4, cf = cf, color = rgb(118 + 8 * sz, 66 + 4 * sz, 40 + 2 * sz), variant = WOODV, collide = true, shadow = true })
		end
		part(m, { name = "Lashing", shape = Enum.PartType.Cylinder, size = Vector3.new(0.55, 0.62, 0.62), cf = CFrame.new(x, 6.55, 0), color = ROPE, material = Enum.Material.Fabric, variant = ROPEV })
	end
	local bar = part(m, { name = "Bar", shape = Enum.PartType.Cylinder, size = Vector3.new(8.4, 0.4, 0.4), cf = CFrame.new(0, 6.5, 0), color = WOOD, variant = WOODV, collide = true })
	-- cloths: x centre, width, length, tint (a saturated orange - the canvas weave washes ClothOrange out -, ClothTan,
	-- a lighter orange)
	local cloths = {
		{ name = "ClothA", x = -2.0, w = 2.2, h = 3.0, color = rgb(242, 146, 66) },
		{ name = "ClothB", x = 0.55, w = 1.7, h = 2.5, color = rgb(218, 178, 116) },
		{ name = "ClothC", x = 2.55, w = 1.3, h = 2.1, color = rgb(248, 178, 104) },
	}
	for _, c in ipairs(cloths) do
		local top = 6.5
		-- front: two strips meeting at a soft fold (each turned 7 degrees), hinged on the bar
		for _, side in ipairs({ -1, 1 }) do
			local strip = CFrame.new(c.x + side * c.w / 4, top - c.h / 2, -0.24) * CFrame.Angles(0, math.rad(7 * side), 0)
			part(m, { name = c.name, size = Vector3.new(c.w / 2, c.h, 0.07), cf = strip, color = if side < 0 then c.color else c.color:Lerp(Color3.new(0, 0, 0), 0.06), material = Enum.Material.Fabric, variant = CLOTHV, collide = true })
		end
		-- back flap over the bar
		part(m, { name = c.name, size = Vector3.new(c.w, c.h * 0.45, 0.07), cf = CFrame.new(c.x, top - c.h * 0.225, 0.24), color = c.color:Lerp(Color3.new(0, 0, 0), 0.12), material = Enum.Material.Fabric, variant = CLOTHV })
		-- two pegs on the bar
		for _, side in ipairs({ -1, 1 }) do
			part(m, { name = "Peg", size = Vector3.new(0.1, 0.42, 0.16), cf = CFrame.new(c.x + side * (c.w / 2 - 0.2), top + 0.1, -0.12), color = rgb(214, 170, 118), variant = WOODV })
		end
	end
	m.PrimaryPart = bar
	bar.PivotOffset = CFrame.new(0, -6.5, 0) -- pivot on the floor under the middle of the bar
	m:SetAttribute("MapPropId", "laundry_rack")
	return m
end

---------------------------------------------------------------------
-- 14/19 WEAPON_STALL, 18 TROPHY_STALL, 20 DIAMOND_SHOP: the Studio half (the FRAME). The awning, the display items
-- and the anvil_forge stay as they are (Blender, batches 3-4). Base = the current template, else the hub marker
-- (workspace.Hub.<Marker>) without its functional children (Interact + prompt + NameTag, NpcSpot, NPC, nested props:
-- they stay on each placed instance, SyncMapProps carries them over). The old frame (Post x4, SidePanel x2, Counter,
-- CounterTop, BackWall, BackBeam: 10 parts) is replaced by 38 parts with the SAME collision envelope: the parts
-- that collide fill exactly the old solid boxes (posts, side panels, counter + front planks + kick board, the 2
-- counter-top boards, backboard planks + backing, back beam); every new trim (front beam, knee braces, rails, stiles,
-- battens, post feet) is CanCollide false, so no new ledge to climb on. Stall space: pivot at the floor centre,
-- front = -Z, counter front at z -3.8, backboard front at z 3.3.
---------------------------------------------------------------------
local STALL_MARKERS = { weapon_stall = "WeaponShop", trophy_stall = "TrophyMerchant", diamond_shop = "DiamondShop" }
local FRAME_NAMES = {
	Post = true, SidePanel = true, Counter = true, CounterTop = true, BackWall = true, BackBeam = true, -- old + kept names
	PostFoot = true, FrontBeam = true, KneeBrace = true, SideRail = true, CounterPlank = true, CounterKick = true,
	CounterStile = true, CounterLip = true, BackBoard = true, BackRail = true, BackBatten = true,
}
local FUNCTIONAL = { Interact = true, NpcSpot = true, NPC = true }
local KEEP_CLASSES = { "LuaSourceContainer", "ProximityPrompt", "LayerCollector", "Sound", "ClickDetector", "Humanoid" }

local function functional(child: Instance): boolean
	if FUNCTIONAL[child.Name] or child:HasTag("MapProp") or child:GetAttribute("MapPropKeep") ~= nil then
		return true
	end
	for _, d in ipairs(child:GetDescendants()) do
		for _, className in ipairs(KEEP_CLASSES) do
			if d:IsA(className) then
				return true
			end
		end
	end
	return false
end

local function stallFrame(m: Model): Part
	local WOODV, PLANKSV, STONEV = "FYD_Wood", "FYD_Planks", "FYD_Stone"
	local POST, BEAM = rgb(124, 69, 42), rgb(108, 60, 36)
	local BOARD = { rgb(187, 109, 62), rgb(177, 102, 58), rgb(195, 116, 67) }
	local TOP = { rgb(238, 167, 102), rgb(229, 158, 95) }
	local function beamPart(name: string, size: Vector3, cf: CFrame)
		part(m, { name = name, size = size, cf = cf, color = BEAM, variant = WOODV })
	end
	-- posts (same boxes as before) on stone footings
	for _, sx in ipairs({ -1, 1 }) do
		part(m, { name = "Post", size = Vector3.new(0.9, 8.4, 0.9), cf = CFrame.new(6.55 * sx, 4.2, -3.55), color = POST, variant = WOODV, collide = true, shadow = true })
		part(m, { name = "Post", size = Vector3.new(0.9, 10.4, 0.9), cf = CFrame.new(6.55 * sx, 5.2, 3.55), color = POST, variant = WOODV, collide = true, shadow = true })
		for _, z in ipairs({ -3.55, 3.55 }) do
			part(m, { name = "PostFoot", size = Vector3.new(1.2, 0.3, 1.2), cf = CFrame.new(6.55 * sx, 0.15, z), color = rgb(118, 125, 141), material = Enum.Material.Slate, variant = STONEV })
		end
		-- knee brace from the front post up to the front beam
		beamPart("KneeBrace", Vector3.new(0.3, 1.7, 0.3), CFrame.new(5.62 * sx, 7.33, -3.55) * CFrame.Angles(0, 0, math.rad(45 * sx)))
		-- side panel (same box) with a top rail
		part(m, { name = "SidePanel", size = Vector3.new(0.6, 3.2, 6.4), cf = CFrame.new(6.55 * sx, 1.6, 0), color = BOARD[1], material = Enum.Material.WoodPlanks, variant = PLANKSV, collide = true, shadow = true })
		beamPart("SideRail", Vector3.new(0.76, 0.18, 6.5), CFrame.new(6.55 * sx, 3.29, 0))
	end
	beamPart("FrontBeam", Vector3.new(14.0, 0.5, 0.5), CFrame.new(0, 8.15, -3.55))
	-- counter: dark core + 3 rows of front planks + kick board (together the old 12.4 x 3.2 x 1.8 box), stiles, top
	local core = part(m, { name = "Counter", size = Vector3.new(12.4, 3.2, 1.6), cf = CFrame.new(0, 1.6, -2.8), color = rgb(100, 56, 32), variant = WOODV, collide = true, shadow = true })
	local PLANK = { rgb(195, 116, 67), rgb(170, 98, 55), rgb(188, 110, 63) }
	for i, y in ipairs({ 0.75, 1.74, 2.73 }) do
		part(m, { name = "CounterPlank", size = Vector3.new(12.0, 0.9, 0.2), cf = CFrame.new(0, y, -3.7), color = PLANK[i], variant = WOODV, collide = true })
	end
	part(m, { name = "CounterKick", size = Vector3.new(12.4, 0.3, 0.24), cf = CFrame.new(0, 0.15, -3.68), color = BEAM, variant = WOODV, collide = true })
	for _, x in ipairs({ -6.04, 0, 6.04 }) do
		beamPart("CounterStile", Vector3.new(0.32, 2.9, 0.12), CFrame.new(x, 1.75, -3.84))
	end
	for i, z in ipairs({ -3.565, -2.235 }) do
		part(m, { name = "CounterTop", size = Vector3.new(14.4, 0.5, 1.27), cf = CFrame.new(0, 3.45, z), color = TOP[i], variant = WOODV, collide = true, shadow = true })
	end
	beamPart("CounterLip", Vector3.new(14.4, 0.14, 0.1), CFrame.new(0, 3.13, -4.15))
	-- backboard: 7 vertical boards (front face at z 3.3, as the old wall) over a planked backing, a darker frame
	-- (posts, back beam, bottom rail) and two battens on the back
	part(m, { name = "BackWall", size = Vector3.new(13.0, 7.4, 0.2), cf = CFrame.new(0, 5.6, 3.7), color = rgb(150, 86, 49), material = Enum.Material.WoodPlanks, variant = PLANKSV, collide = true, shadow = true })
	for i = 0, 6 do
		part(m, { name = "BackBoard", size = Vector3.new(1.7, 7.1, 0.3), cf = CFrame.new(-5.25 + i * 1.75, 5.45, 3.45), color = BOARD[i % 3 + 1], variant = WOODV, collide = true, shadow = true })
	end
	beamPart("BackRail", Vector3.new(12.2, 0.36, 0.12), CFrame.new(0, 2.2, 3.24))
	part(m, { name = "BackBeam", size = Vector3.new(14.0, 0.6, 0.6), cf = CFrame.new(0, 9.3, 3.55), color = BEAM, variant = WOODV, collide = true, shadow = true })
	for _, y in ipairs({ 3.2, 7.8 }) do
		beamPart("BackBatten", Vector3.new(12.2, 0.4, 0.14), CFrame.new(0, y, 3.87))
	end
	return core
end

-- MapProps.<propId> holds the Blender pieces (ApplyPropMeshes PIECES mode): the frame must be rebuilt from the bare
-- frame kept in MapProps._Base.<propId>, never from the pieces template
local function piecesApplied(propId: string): boolean
	local maps = ServerStorage:FindFirstChild("MapProps")
	local current = maps and maps:FindFirstChild(propId)
	return current ~= nil and current:GetAttribute("MapPropPieces") ~= nil
end

local function stall(propId: string): Model
	local maps = ServerStorage:FindFirstChild("MapProps")
	local base = maps and maps:FindFirstChild(propId)
	if piecesApplied(propId) then
		local saved = maps:FindFirstChild("_Base") and maps._Base:FindFirstChild(propId)
		assert(saved and saved:IsA("Model"), `{propId}: refused - MapProps.{propId} holds the Blender pieces (MapPropPieces) and MapProps._Base.{propId} (the bare frame) is missing`)
		base = saved
	end
	local hub = workspace:FindFirstChild("Hub")
	base = base or (hub and hub:FindFirstChild(STALL_MARKERS[propId]))
	assert(base and base:IsA("Model"), `{propId}: no template and no workspace.Hub.{STALL_MARKERS[propId]}`)
	local pivot = (base :: Model):GetPivot()
	local m = base:Clone() :: Model
	m.PrimaryPart = nil
	for _, child in ipairs(m:GetChildren()) do
		if functional(child) or child.Name == "_Variants" or (child:IsA("BasePart") and FRAME_NAMES[child.Name]) then
			child:Destroy()
		end
	end
	for key in pairs(m:GetAttributes()) do
		m:SetAttribute(key, nil)
	end
	for _, tag in ipairs(m:GetTags()) do
		m:RemoveTag(tag)
	end
	m.WorldPivot = pivot
	m:PivotTo(CFrame.identity)
	local core = stallFrame(m)
	m.PrimaryPart = core
	core.PivotOffset = core.CFrame:Inverse() -- pivot at the floor centre (the origin)
	m.Name = propId
	m:SetAttribute("MapPropId", propId)
	return m
end

function StudioProps.weapon_stall(): Model
	return stall("weapon_stall")
end

function StudioProps.trophy_stall(): Model
	return stall("trophy_stall")
end

function StudioProps.diamond_shop(): Model
	return stall("diamond_shop")
end

---------------------------------------------------------------------
-- PLAINS_1 FARM (owner fix of 2026-10-19, docs/screenshots/plains1_fix): the wheat field, the cart and the hay
-- bales of the Plains sub-zone 1 farm, low-poly but a bit more realistic, palette colours (docs/prop_texture_guide.md
-- section 3), SmoothPlastic. Fine detail is merged with GeometryService:UnionAsync into a few UnionOperations
-- (each piece keeps its colour: UsePartColor false; RenderFidelity Automatic = distance LOD). The merged pieces never
-- collide: the old collisions stay on plain parts (or an invisible stand-in of the old part).
---------------------------------------------------------------------
local GeometryService = game:GetService("GeometryService")

-- an unparented piece for merge()
local function piece(className: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new(className) :: BasePart
	if shape and p:IsA("Part") then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- the pieces merged into one UnionOperation `name` in `model`; `pivot` (template space) = its PivotOffset target (the
-- PropFX Sway Hinge "Pivot" turns it there). opts: collide, shadow
local function merge(model: Model, name: string, pieces: { BasePart }, pivot: CFrame?, opts: any?): UnionOperation
	opts = opts or {}
	-- a short hash of the pieces (class, size, place, turn, colour) for the attribute MergeHash: a union's own
	-- properties do not show what is inside, and SyncMapProps' template fingerprint reads the attributes, so the
	-- copies are updated whenever the pieces change
	local h1, h2 = 5381, 52711
	for _, p in ipairs(pieces) do
		local rx, ry, rz = p.CFrame:ToOrientation()
		local line = string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.4f,%.4f,%.4f|%d,%d,%d;", p.ClassName, p.Size.X, p.Size.Y, p.Size.Z, p.Position.X, p.Position.Y, p.Position.Z, rx, ry, rz, math.round(p.Color.R * 255), math.round(p.Color.G * 255), math.round(p.Color.B * 255))
		for i = 1, #line do
			local b = string.byte(line, i)
			h1 = (h1 * 33 + b) % 4294967296
			h2 = (h2 * 31 + b * 7) % 4294967291
		end
	end
	local first = table.remove(pieces, 1) :: BasePart
	local result = GeometryService:UnionAsync(first, pieces, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Automatic,
		SplitApart = false,
	})
	first:Destroy()
	for _, p in ipairs(pieces) do
		p:Destroy()
	end
	local u = result[1] :: UnionOperation
	u.Name = name
	u:SetAttribute("MergeHash", string.format("%08x", bit32.bxor(h1, h2)))
	u.UsePartColor = false
	u.Material = Enum.Material.SmoothPlastic
	u.Anchored = true
	u.CanCollide = opts.collide == true
	u.CanQuery = opts.collide == true
	u.CanTouch = false
	u.CastShadow = opts.shadow == true
	if pivot then
		u.PivotOffset = u.CFrame:ToObjectSpace(pivot)
	end
	u.Parent = model
	return u
end

-- the props merged pieces in a template (and its triangle count), for the reports
function StudioProps.mergedStats(model: Instance): (number, number, number)
	local parts, unions, triangles = 0, 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("PartOperation") then
				unions += 1
				triangles += (d :: any).TriangleCount
			elseif d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
				triangles += 64 -- (about: a Roblox cylinder)
			elseif d:IsA("WedgePart") then
				triangles += 8
			else
				triangles += 12
			end
		end
	end
	return parts, unions, triangles
end

---------------------------------------------------------------------
-- WHEAT FIELD (old WheatPatch_A: 9 x 9, a soil slab + 4 flat yellow slabs; the Plains_1 field = 6 patches, + kit +
-- test area). Furrowed soil: 4 raised ridges (lighter tops), darker furrows, a ragged edge of clods and a few weeds =
-- one union "Soil" (PrimaryPart); per row one union "WheatRowA".."WheatRowD": clusters of 2-4 thin stalks (wedges)
-- with seed heads, varied heights, gold / yellow / pale / green tones, shorter at the row ends; its pivot = the row's
-- base (PropFX sway around X). Same footprint and pivot (bottom centre) as WheatPatch_A; no collision, like before.
---------------------------------------------------------------------
local SOIL_TOP, SOIL_SIDE, SOIL_FURROW = rgb(176, 124, 78), rgb(154, 107, 67), rgb(124, 86, 54)
local WEEDS = { rgb(104, 168, 72), rgb(86, 142, 60), rgb(120, 180, 80) }
local WHEAT = { -- { head, stalk, weight }: Straw, a warmer yellow, StrawPale, Gold, an unripe green
	{ rgb(236, 200, 96), rgb(196, 160, 74), 34 },
	{ rgb(248, 214, 112), rgb(206, 172, 82), 26 },
	{ rgb(244, 226, 160), rgb(200, 182, 118), 6 },
	{ rgb(255, 201, 60), rgb(208, 160, 56), 20 },
	{ rgb(186, 196, 92), rgb(128, 156, 68), 14 },
}
StudioProps.WHEAT_ROWS = { -3.3, -1.1, 1.1, 3.3 } -- the old slabs' rows (z)
StudioProps.WHEAT_ROW_NAMES = { "WheatRowA", "WheatRowB", "WheatRowC", "WheatRowD" }
local RIDGE_BASE, RIDGE_TOP = 0.22, 0.58 -- furrow floor, ridge crest

local function pickWheat(rng: Random): { any }
	local total = 0
	for _, w in ipairs(WHEAT) do
		total += w[3]
	end
	local r = rng:NextNumber(0, total)
	for _, w in ipairs(WHEAT) do
		r -= w[3]
		if r <= 0 then
			return w
		end
	end
	return WHEAT[1]
end

-- a weed tuft of 3 leaning blades at (x, z) on height y
local function weed(list: { BasePart }, rng: Random, x: number, y: number, z: number)
	local color = WEEDS[rng:NextInteger(1, #WEEDS)]
	for i = 1, 3 do
		local h = rng:NextNumber(0.45, 0.8)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw + i * 2.1, 0) * CFrame.Angles(math.rad(rng:NextNumber(12, 30)), 0, 0)
		table.insert(list, piece("WedgePart", Vector3.new(0.05, h, 0.22), cf * CFrame.new(0, h / 2, 0), color))
	end
end

function StudioProps.wheat_patch(): Model
	local m = Instance.new("Model")
	m.Name = "wheat_patch"
	local rng = Random.new(20261019)
	local soil: { BasePart } = {}
	-- the furrow floor (a bit inside the 9 x 9: the clods make the ragged edge)
	table.insert(soil, piece("Part", Vector3.new(8.6, RIDGE_BASE, 8.6), CFrame.new(0, RIDGE_BASE / 2, 0), SOIL_FURROW))
	for i = 1, 8 do
		local side = (i - 1) % 4
		local t = rng:NextNumber(-3.9, 3.9)
		local x = if side == 0 or side == 2 then t elseif side == 1 then 4.05 else -4.05
		local z = if side == 1 or side == 3 then t elseif side == 0 then -4.05 else 4.05
		local s = Vector3.new(rng:NextNumber(0.55, 0.9), rng:NextNumber(0.12, 0.24), rng:NextNumber(0.55, 0.9))
		local color = if rng:NextNumber() < 0.5 then SOIL_FURROW else SOIL_SIDE
		table.insert(soil, piece("Part", s, CFrame.new(x, s.Y / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), color))
	end
	-- the ridges under the rows: a body and two wedges (a peaked crest), slightly uneven lengths
	local ridgeEnds = {}
	for r, z in ipairs(StudioProps.WHEAT_ROWS) do
		local length = rng:NextNumber(7.7, 8.5)
		local x0 = rng:NextNumber(-0.25, 0.25)
		ridgeEnds[r] = { x0 - length / 2, x0 + length / 2 }
		local bodyH = 0.16
		table.insert(soil, piece("Part", Vector3.new(length, bodyH, 1.3), CFrame.new(x0, RIDGE_BASE + bodyH / 2, z), SOIL_SIDE))
		local crestH = RIDGE_TOP - RIDGE_BASE - bodyH
		local y = RIDGE_BASE + bodyH + crestH / 2
		table.insert(soil, piece("WedgePart", Vector3.new(length, crestH, 0.65), CFrame.new(x0, y, z - 0.325), SOIL_TOP))
		table.insert(soil, piece("WedgePart", Vector3.new(length, crestH, 0.65), CFrame.new(x0, y, z + 0.325) * CFrame.Angles(0, math.pi, 0), SOIL_TOP))
	end
	-- weeds: at the edges and in two furrows
	for _, at in ipairs({ { -4.0, -2.2 }, { 3.9, 2.4 }, { -2.3, 4.0 }, { 0.7, 0.0 } }) do
		weed(soil, rng, at[1] + rng:NextNumber(-0.3, 0.3), RIDGE_BASE, at[2] + rng:NextNumber(-0.15, 0.15))
	end
	local soilUnion = merge(m, "Soil", soil, nil, { shadow = false })
	-- the wheat rows
	for r, z in ipairs(StudioProps.WHEAT_ROWS) do
		-- first piece: a small axis-aligned block hidden in the ridge crest (a union takes the frame of its first
		-- piece: the row's axes stay the template's, so the sway turns it around X)
		local pieces: { BasePart } = { piece("Part", Vector3.new(0.1, 0.06, 0.1), CFrame.new(0, RIDGE_TOP - 0.12, z), SOIL_SIDE) }
		local x0, x1 = ridgeEnds[r][1] + rng:NextNumber(0.2, 0.5), ridgeEnds[r][2] - rng:NextNumber(0.2, 0.5)
		local x = x0
		local clusters = {}
		while x <= x1 do
			table.insert(clusters, x)
			x += rng:NextNumber(0.75, 0.95)
		end
		for c, cx in ipairs(clusters) do
			local tone = pickWheat(rng)
			local edge = c == 1 or c == #clusters or r == 1 or r == #StudioProps.WHEAT_ROWS
			local tall = rng:NextNumber(1.85, 2.45) * (if edge then 0.86 else 1)
			local roll = rng:NextNumber()
			local count = if roll < 0.2 then 2 elseif roll < 0.4 then 4 else 3
			local cz = z + rng:NextNumber(-0.18, 0.18)
			for _ = 1, count do
				local ox, oz = rng:NextNumber(-0.16, 0.16), rng:NextNumber(-0.12, 0.12)
				local h = tall * rng:NextNumber(0.88, 1.08)
				-- lean outward from the cluster centre, a little at random
				local lean = CFrame.Angles(math.rad(oz * 40 + rng:NextNumber(-5, 5)), rng:NextNumber(0, math.pi), math.rad(-ox * 40 + rng:NextNumber(-5, 5)))
				local base = CFrame.new(cx + ox, RIDGE_TOP - 0.12, cz + oz) * lean
				table.insert(pieces, piece("WedgePart", Vector3.new(0.09, h, 0.09), base * CFrame.new(0, h / 2, 0), tone[2]))
				local head = rng:NextNumber(0.6, 0.78)
				-- (the head starts just above the stalk: touching pieces would cut each other into more triangles)
				local top = base * CFrame.new(0, h + 0.02, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), math.rad(45), 0)
				table.insert(pieces, piece("Part", Vector3.new(0.17, head, 0.17), top * CFrame.new(0, head / 2, 0), tone[1]))
			end
		end
		merge(m, StudioProps.WHEAT_ROW_NAMES[r], pieces, CFrame.new(0, RIDGE_TOP - 0.12, z), { shadow = true })
	end
	m.PrimaryPart = soilUnion
	soilUnion.PivotOffset = soilUnion.CFrame:Inverse() -- pivot at the bottom centre (the origin)
	m:SetAttribute("MapPropId", "wheat_patch")
	return m
end

---------------------------------------------------------------------
-- THE PLAINS_1 FIELD'S EDGE (unique, not a kit model): buildFieldBorder(dirt) puts a Model "FieldBorder" next to the
-- field's dirt plate (Farm.FieldDirt, kept): a small worn wooden border of low planks on stakes along the plate's
-- edge (open where something stands on the line: the barrels, the way in from the farmhouse), a ragged line of dirt
-- clods and a few weeds just outside it. One union per side, no collision (like the field). An older FieldBorder is
-- replaced. Returns a short report.
---------------------------------------------------------------------
function StudioProps.buildFieldBorder(dirt: BasePart): string
	local rng = Random.new(7019)
	local PLANK = { rgb(168, 98, 56), rgb(156, 90, 52), rgb(178, 106, 61) }
	local STAKE = rgb(112, 62, 38)
	local CLOD = { rgb(176, 124, 78), rgb(154, 107, 67) }
	local half = dirt.Size / 2
	local top = half.Y -- the plate's top, in its own space
	local old = dirt.Parent and dirt.Parent:FindFirstChild("FieldBorder")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "FieldBorder"
	-- the four sides: { name, start, direction (plate space), length, outward normal }
	local sides = {
		{ "BorderSouth", Vector3.new(-half.X, 0, -half.Z + 0.15), Vector3.xAxis, 2 * half.X, -Vector3.zAxis },
		{ "BorderNorth", Vector3.new(-half.X, 0, half.Z - 0.15), Vector3.xAxis, 2 * half.X, Vector3.zAxis },
		{ "BorderWest", Vector3.new(-half.X + 0.15, 0, -half.Z), Vector3.zAxis, 2 * half.Z, -Vector3.xAxis },
		{ "BorderEast", Vector3.new(half.X - 0.15, 0, -half.Z), Vector3.zAxis, 2 * half.Z, Vector3.xAxis },
	}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { dirt }
	local report = {}
	for _, side in ipairs(sides) do
		local name, start, dir, length, out = side[1], side[2], side[3], side[4], side[5]
		-- what stands on the line (a barrel...): open the border there
		local gaps = {}
		local lineCenter = dirt.CFrame * (start + dir * length / 2 + Vector3.new(0, top + 0.6, 0))
		local lineSize = dir * length + (Vector3.one - dir) * 0.5 + Vector3.new(0, 0.7, 0)
		for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(lineCenter), Vector3.new(math.abs(lineSize.X), 0.8, math.abs(lineSize.Z)), params)) do
			if hit.Transparency < 1 and hit.Size.Magnitude < 40 then
				local local0 = dirt.CFrame:PointToObjectSpace(hit.Position)
				local along = (local0 - start):Dot(dir)
				local reach = math.abs(hit.CFrame.RightVector:Dot(dirt.CFrame:VectorToWorldSpace(dir))) * hit.Size.X / 2
					+ math.abs(hit.CFrame.UpVector:Dot(dirt.CFrame:VectorToWorldSpace(dir))) * hit.Size.Y / 2
					+ math.abs(hit.CFrame.LookVector:Dot(dirt.CFrame:VectorToWorldSpace(dir))) * hit.Size.Z / 2
				table.insert(gaps, { along - reach - 0.5, along + reach + 0.5 })
			end
		end
		local function blocked(a: number, b: number): boolean
			for _, g in ipairs(gaps) do
				if b > g[1] and a < g[2] then
					return true
				end
			end
			return false
		end
		local function world(p: Vector3): CFrame
			return dirt.CFrame * CFrame.new(p)
		end
		local yaw = math.atan2(-dir.Z, dir.X) -- turns X onto the side's direction
		local pieces: { BasePart } = { piece("Part", Vector3.new(0.05, 0.05, 0.05), world(start + Vector3.new(0, top - 0.04, 0)), STAKE) }
		local t, planks, stakes = 0, 0, 0
		local staked = {} -- (one stake per joint)
		while t < length - 0.5 do
			local len = math.min(rng:NextNumber(3.8, 5.2), length - t)
			if length - t - len < 1.5 then
				len = length - t
			end
			local a, b = t, t + len
			if not blocked(a, b) then
				local h = rng:NextNumber(0.42, 0.55)
				local mid = start + dir * ((a + b) / 2) + Vector3.new(0, top + h / 2 - 0.04, 0)
				local tilt = CFrame.Angles(0, yaw + math.rad(rng:NextNumber(-1.5, 1.5)), math.rad(rng:NextNumber(-2, 2)))
				table.insert(pieces, piece("Part", Vector3.new(len - 0.1, h, 0.18), world(mid) * tilt, PLANK[rng:NextInteger(1, #PLANK)]))
				planks += 1
				for _, at in ipairs({ a, b }) do
					if staked[math.round(at * 10)] then
						continue
					end
					staked[math.round(at * 10)] = true
					local stake = start + dir * at + out * 0.23 + Vector3.new(0, top + 0.32, 0) -- (just off the plank: fewer triangles)
					table.insert(pieces, piece("Part", Vector3.new(0.24, 0.85, 0.24), world(stake) * CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), yaw, math.rad(rng:NextNumber(-4, 4))), STAKE))
					stakes += 1
				end
			end
			t = b
		end
		-- the ragged dirt line and a few weeds just outside
		for _ = 1, math.floor(length / 5) do
			local along = rng:NextNumber(0.5, length - 0.5)
			if blocked(along - 0.6, along + 0.6) then
				continue
			end
			local s = Vector3.new(rng:NextNumber(0.5, 1.1), rng:NextNumber(0.12, 0.22), rng:NextNumber(0.4, 0.9))
			local p = start + dir * along + out * rng:NextNumber(0.4, 0.9) + Vector3.new(0, -half.Y + 0.1 + s.Y / 2 - 0.02, 0)
			table.insert(pieces, piece("Part", s, world(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), CLOD[rng:NextInteger(1, #CLOD)]))
		end
		for _ = 1, 2 do
			local along = rng:NextNumber(1, length - 1)
			local p = dirt.CFrame * (start + dir * along + out * rng:NextNumber(0.5, 1.0) + Vector3.new(0, -half.Y, 0))
			weed(pieces, rng, p.X, p.Y, p.Z)
		end
		merge(model, name, pieces, nil, { shadow = true })
		table.insert(report, `{name} {planks} plank(s) {stakes} stake(s){if #gaps > 0 then ` ({#gaps} gap(s))` else ""}`)
	end
	model.Parent = dirt.Parent
	local _, _, triangles = StudioProps.mergedStats(model)
	return `FieldBorder: ` .. table.concat(report, ", ") .. `; {#model:GetChildren()} unions, {triangles} triangles`
end

---------------------------------------------------------------------
-- HAY BALE (old HayBale_A: a 5 x 5 roll lying along X + 2 bands). The roll ("Hay", collides as before), the rolled
-- layers on both ends (rings of lighter / darker straw), straw strands over the round side, loose straw on the ground
-- around the base (one union "Straw"), two thin twine bands ("Band"). 5.2 x 5.08 x 5.08, pivot bottom centre.
---------------------------------------------------------------------
function StudioProps.hay_bale(): Model
	local m = Instance.new("Model")
	m.Name = "hay_bale"
	local rng = Random.new(1019)
	local STRAW, DARK, LIGHT, DEEP, TWINE = rgb(236, 200, 96), rgb(212, 176, 80), rgb(248, 220, 130), rgb(190, 152, 66), rgb(196, 160, 104)
	local R, AXIS = 2.5, CFrame.new(0, 2.5, 0)
	local hay = part(m, { name = "Hay", shape = Enum.PartType.Cylinder, size = Vector3.new(4.9, 2 * R, 2 * R), cf = AXIS, color = STRAW, material = Enum.Material.SmoothPlastic, collide = true, shadow = true })
	local straw: { BasePart } = {}
	-- the rolled layers: discs stepping out a little toward the centre, alternating tones
	local rings = { { 4.3, DARK }, { 2.9, LIGHT }, { 1.4, DEEP } }
	for _, s in ipairs({ -1, 1 }) do
		for i, ring in ipairs(rings) do
			local t = 0.05
			local x = s * (2.45 + (i - 0.5) * 0.03)
			table.insert(straw, piece("Part", Vector3.new(t, ring[1], ring[1]), AXIS * CFrame.new(x, 0, 0), ring[2], Enum.PartType.Cylinder))
		end
	end
	-- straw wrapped around the roll: short strands along the circumference (a slight spiral), the layers of the roll
	for i = 1, 24 do
		local length = rng:NextNumber(0.6, 1.1)
		local x = rng:NextNumber(-2.3, 2.3)
		local around = rng:NextNumber(-math.pi * 0.8, math.pi * 0.8) -- (not under the roll)
		local cf = AXIS * CFrame.Angles(around, 0, 0) * CFrame.new(x, R + 0.005, 0) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
		table.insert(straw, piece("Part", Vector3.new(0.12, 0.05, length), cf, if i % 2 == 0 then LIGHT else DARK))
	end
	-- loose straw on the ground along the base
	for i = 1, 10 do
		local length = rng:NextNumber(0.5, 1.3)
		local x = rng:NextNumber(-2.5, 2.5)
		local z = (if i % 2 == 0 then 1 else -1) * rng:NextNumber(0.9, 1.9)
		local cf = CFrame.new(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-6, 6)))
		table.insert(straw, piece("Part", Vector3.new(length, 0.05, 0.07), cf, ({ STRAW, LIGHT, DARK })[i % 3 + 1]))
	end
	merge(m, "Straw", straw, nil, { shadow = false })
	-- the twine bands
	for _, x in ipairs({ -1.3, 1.3 }) do
		part(m, { name = "Band", shape = Enum.PartType.Cylinder, size = Vector3.new(0.16, 2 * R + 0.08, 2 * R + 0.08), cf = AXIS * CFrame.new(x, 0, 0), color = TWINE, material = Enum.Material.SmoothPlastic, collide = true })
	end
	m.PrimaryPart = hay
	hay.PivotOffset = CFrame.new(0, -R, 0)
	m:SetAttribute("MapPropId", "hay_bale")
	return m
end

---------------------------------------------------------------------
-- CART (old Cart_A: 6.8 x 4.5 x 12.7; bed, 2 side panels + back panel, 2 solid wheels, axle, 2 handles, a leg). A
-- planked bed on two sills and cross bearers, side and back rails on stakes, a low front board, iron corner
-- brackets, an iron axle on bolsters, two spoked wheels (wooden felloes, iron rims, 8 spokes, hub, iron cap: one
-- union each, never colliding; an invisible "WheelCollider" cylinder keeps the old wheel collision), the shafts with
-- a cross bar, the prop leg. Slight wear: one shorter, lighter floor plank, a back rail a little askew, worn rail
-- tops. Same pivot (bottom centre), front (-Z = the shafts) and size as Cart_A.
---------------------------------------------------------------------
function StudioProps.cart(): Model
	local m = Instance.new("Model")
	m.Name = "cart"
	local MID, LIGHT, DARK, WORN = rgb(168, 98, 56), rgb(214, 150, 92), rgb(112, 62, 38), rgb(226, 166, 108)
	local IRON, IRONW = rgb(92, 98, 110), rgb(122, 128, 140)
	local PLANKS = { rgb(168, 98, 56), rgb(178, 106, 61), rgb(160, 93, 53), rgb(176, 104, 60), rgb(190, 124, 74) }
	local function wood(name: string, size: Vector3, cf: CFrame, color: Color3, collide: boolean?): Part
		return part(m, { name = name, size = size, cf = cf, color = color, material = Enum.Material.SmoothPlastic, collide = collide ~= false, shadow = true })
	end
	-- bed: sills, cross bearers, 5 floor planks (one shorter and lighter: worn)
	for _, x in ipairs({ -2.2, 2.2 }) do
		wood("Sill", Vector3.new(0.4, 0.35, 8.2), CFrame.new(x, 2.33, 0), DARK)
	end
	for _, z in ipairs({ -3.4, 0.5, 3.6 }) do
		wood("Bearer", Vector3.new(5.0, 0.28, 0.4), CFrame.new(0, 2.36, z), DARK)
	end
	local floor = nil
	for i = 1, 5 do
		local x = -2.0 + (i - 1) * 1.0
		local len = if i == 5 then 7.6 else 8.0
		local p = wood("Bed", Vector3.new(0.96, 0.22, len), CFrame.new(x, 2.61, (8.0 - len) / 2), PLANKS[i])
		if i == 3 then
			floor = p
		end
	end
	-- stakes and rails: sides (x +-2.45), back (z +3.95), a low front board (z -3.95)
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -3.75, -1.25, 1.25, 3.75 }) do
			wood("Stake", Vector3.new(0.3, 1.95, 0.3), CFrame.new(2.45 * sx, 3.55, z), DARK)
		end
		wood("Rail", Vector3.new(0.22, 0.48, 8.1), CFrame.new(2.5 * sx, 3.25, 0), LIGHT)
		wood("Rail", Vector3.new(0.24, 0.5, 8.1), CFrame.new(2.5 * sx, 4.2, 0), WORN)
		for _, z in ipairs({ -3.75, 3.75 }) do
			part(m, { name = "Bracket", size = Vector3.new(0.08, 0.6, 0.5), cf = CFrame.new(2.63 * sx, 4.2, z), color = IRON, material = Enum.Material.SmoothPlastic })
		end
	end
	wood("Rail", Vector3.new(5.1, 0.48, 0.22), CFrame.new(0, 3.25, 3.98), LIGHT)
	wood("Rail", Vector3.new(5.1, 0.5, 0.24), CFrame.new(0, 4.18, 3.98) * CFrame.Angles(0, 0, math.rad(1.5)), WORN)
	wood("Rail", Vector3.new(5.1, 0.42, 0.2), CFrame.new(0, 3.0, -3.98), LIGHT)
	-- axle on two bolsters
	part(m, { name = "Axle", shape = Enum.PartType.Cylinder, size = Vector3.new(6.3, 0.42, 0.42), cf = CFrame.new(0, 1.9, 0.5), color = IRON, material = Enum.Material.SmoothPlastic, collide = true })
	for _, x in ipairs({ -2.2, 2.2 }) do
		wood("Bolster", Vector3.new(0.45, 0.32, 0.7), CFrame.new(x, 2.0, 0.5), DARK)
	end
	-- the two spoked wheels (as the old ones: diameter 3.8, at x +-3.0, axle height 1.9, z 0.5)
	for _, sx in ipairs({ -1, 1 }) do
		local center = CFrame.new(3.0 * sx, 1.9, 0.5)
		local pieces: { BasePart } = {}
		for k = 0, 11 do
			local around = center * CFrame.Angles(k * math.pi / 6, 0, 0)
			table.insert(pieces, piece("Part", Vector3.new(0.46, 0.14, 1.04), around * CFrame.new(0, 1.83, 0), IRON))
			table.insert(pieces, piece("Part", Vector3.new(0.38, 0.34, 0.86), around * CFrame.new(0, 1.59, 0), if k % 2 == 0 then MID else rgb(156, 90, 52)))
		end
		for k = 0, 7 do
			local around = center * CFrame.Angles(k * math.pi / 4 + math.pi / 8, 0, 0)
			table.insert(pieces, piece("Part", Vector3.new(0.16, 1.12, 0.2), around * CFrame.new(0, 0.95, 0), DARK))
		end
		-- hub: an octagonal block pair (low-poly, few triangles) and a square iron cap
		table.insert(pieces, piece("Part", Vector3.new(0.62, 0.72, 0.72), center, DARK))
		table.insert(pieces, piece("Part", Vector3.new(0.62, 0.72, 0.72), center * CFrame.Angles(math.pi / 4, 0, 0), DARK))
		table.insert(pieces, piece("Part", Vector3.new(0.8, 0.4, 0.4), center * CFrame.Angles(math.pi / 8, 0, 0), IRONW))
		merge(m, "Wheel", pieces, center, { shadow = true })
		part(m, { name = "WheelCollider", shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, 3.8, 3.8), cf = center, color = DARK, material = Enum.Material.SmoothPlastic, collide = true, transparency = 1 })
	end
	-- shafts (as the old handles: x +-2, y 2.2, z -6, 8 degrees down to the front), a cross bar, the prop leg
	for _, sx in ipairs({ -1, 1 }) do
		wood("Handle", Vector3.new(0.34, 0.34, 5.0), CFrame.new(2.0 * sx, 2.2, -6.0) * CFrame.Angles(math.rad(-8), 0, 0), DARK)
	end
	wood("Crossbar", Vector3.new(4.1, 0.26, 0.28), CFrame.new(0, 2.32, -4.3), MID)
	wood("Leg", Vector3.new(0.42, 1.9, 0.42), CFrame.new(0, 0.95, -3.4), DARK)
	m.PrimaryPart = floor
	if floor then
		floor.PivotOffset = floor.CFrame:Inverse()
	end
	m:SetAttribute("MapPropId", "cart")
	return m
end

---------------------------------------------------------------------
-- HALF-TIMBER WINDOWS (kit FarmHouse / Cottage_A / Cottage_B and every copy): the timber beams crossed the glass.
-- fixWindows(model): every glass "Window" gets a proper frame (2 jambs, a head, a deeper sill: "WindowFrame" /
-- "WindowSill"), a thin cross of glazing bars ("WindowBar") just in front of the glass, the glass set just behind the
-- frame; the old trim ("Part" pieces touching the glass) goes, and every "Timber" beam that crossed the frame is cut
-- so it stops at the frame (the pieces keep the beam's name, colour and depth). Walls, door and roof are untouched.
-- Idempotent: a framed window (attribute WindowFramed) is left alone. Returns a short report.
---------------------------------------------------------------------
local FRAME_COLOR, SILL_COLOR = rgb(112, 62, 38), rgb(128, 78, 48)

local function boxOverlap(a: CFrame, sa: Vector3, b: CFrame, sb: Vector3): boolean
	local axesA = { a.RightVector, a.UpVector, a.LookVector }
	local axesB = { b.RightVector, b.UpVector, b.LookVector }
	local ha, hb = sa / 2, sb / 2
	local axes = table.clone(axesA)
	for _, v in ipairs(axesB) do
		table.insert(axes, v)
	end
	for i = 1, 3 do
		for j = 1, 3 do
			local c = axesA[i]:Cross(axesB[j])
			if c.Magnitude > 1e-4 then
				table.insert(axes, c.Unit)
			end
		end
	end
	local d = b.Position - a.Position
	for _, L in ipairs(axes) do
		local ra = math.abs(axesA[1]:Dot(L)) * ha.X + math.abs(axesA[2]:Dot(L)) * ha.Y + math.abs(axesA[3]:Dot(L)) * ha.Z
		local rb = math.abs(axesB[1]:Dot(L)) * hb.X + math.abs(axesB[2]:Dot(L)) * hb.Y + math.abs(axesB[3]:Dot(L)) * hb.Z
		if math.abs(d:Dot(L)) > ra + rb - 1e-3 then
			return false
		end
	end
	return true
end

-- half extent of a part's box along a world direction
local function extent(p: BasePart, dir: Vector3): number
	local cf, s = p.CFrame, p.Size
	return math.abs(cf.RightVector:Dot(dir)) * s.X / 2 + math.abs(cf.UpVector:Dot(dir)) * s.Y / 2 + math.abs(cf.LookVector:Dot(dir)) * s.Z / 2
end

-- the beam cut to keep only its parts outside [lo, hi] along the world direction `dir` (one of its own axes)
local function cutBeam(beam: BasePart, dir: Vector3, lo: number, hi: number): number
	local cf, s = beam.CFrame, beam.Size
	local axisName, axisVec = "X", cf.RightVector
	for _, pair in ipairs({ { "Y", cf.UpVector }, { "Z", cf.LookVector } }) do
		if math.abs(pair[2]:Dot(dir)) > math.abs(axisVec:Dot(dir)) then
			axisName, axisVec = pair[1], pair[2]
		end
	end
	local sign = if axisVec:Dot(dir) >= 0 then 1 else -1
	local half = (s :: any)[axisName] / 2
	local c = cf.Position:Dot(dir)
	local b0, b1 = c - half, c + half
	local made = 0
	for _, seg in ipairs({ { b0, math.min(b1, lo) }, { math.max(b0, hi), b1 } }) do
		local a, b = seg[1], seg[2]
		if b - a > 0.05 then
			local p = beam:Clone()
			local size = { X = s.X, Y = s.Y, Z = s.Z }
			size[axisName] = b - a
			p.Size = Vector3.new(size.X, size.Y, size.Z)
			p.CFrame = cf + axisVec * sign * ((a + b) / 2 - c)
			p.Parent = beam.Parent
			made += 1
		end
	end
	beam:Destroy()
	return made
end

function StudioProps.fixWindows(model: Model): string
	local walls = model:FindFirstChild("Walls")
	if not (walls and walls:IsA("BasePart")) then
		return `{model:GetFullName()}: no Walls part, skipped`
	end
	local framed, cut, trims, skipped = 0, 0, 0, 0
	for _, glass in ipairs(model:GetChildren()) do
		if not (glass:IsA("BasePart") and glass.Name == "Window") then
			continue
		end
		if glass:GetAttribute("WindowFramed") then
			skipped += 1
			continue
		end
		-- the glass's thin axis = the wall normal, outward (away from the walls' centre)
		local cf, s = glass.CFrame, glass.Size
		local normal, width, height = cf.LookVector, s.X, s.Y
		if s.X < s.Z and s.X < s.Y then
			normal, width = cf.RightVector, s.Z
		end
		if (glass.Position - walls.Position):Dot(normal) < 0 then
			normal = -normal
		end
		normal = Vector3.new(normal.X, 0, normal.Z).Unit
		local across = Vector3.yAxis:Cross(normal) -- horizontal, in the wall plane
		local face = walls.Position:Dot(normal) + extent(walls, normal) -- the wall surface
		local cu, cv = glass.Position:Dot(across), glass.Position.Y
		-- (across, up, normal) is an orthonormal frame: a point = across * u + up * v + normal * depth
		local function at(u: number, v: number, depth: number): CFrame
			return CFrame.fromMatrix(across * u + normal * depth + Vector3.new(0, v, 0), across, Vector3.yAxis)
		end
		-- the old trim: dark "Part" pieces touching the glass
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("BasePart") and d.Name == "Part" and math.min(d.Size.X, d.Size.Y, d.Size.Z) <= 0.7 and boxOverlap(cf, s + Vector3.new(1, 1, 1), d.CFrame, d.Size) then
				d:Destroy()
				trims += 1
			end
		end
		-- glass just behind the frame (front face 0.06 out of the wall)
		glass.Size = Vector3.new(width, height, 0.16)
		glass.CFrame = at(cu, cv, face - 0.02)
		local J, DEPTH = 0.4, 0.5 -- jamb width, frame depth (front face 0.36 out of the wall)
		local frameDepth = face + 0.36 - DEPTH / 2
		local function add(name: string, size: Vector3, c: CFrame, color: Color3)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = c
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = true
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = model
		end
		for _, side in ipairs({ -1, 1 }) do
			add("WindowFrame", Vector3.new(J, height, DEPTH), at(cu + side * (width / 2 + J / 2), cv, frameDepth), FRAME_COLOR)
		end
		add("WindowFrame", Vector3.new(width + 2 * J + 0.3, 0.42, DEPTH + 0.06), at(cu, cv + height / 2 + 0.21, frameDepth + 0.03), FRAME_COLOR)
		add("WindowSill", Vector3.new(width + 2 * J + 0.5, 0.3, 0.8), at(cu, cv - height / 2 - 0.15, face + 0.46 - 0.4), SILL_COLOR)
		add("WindowBar", Vector3.new(0.14, height, 0.1), at(cu, cv, face + 0.11), FRAME_COLOR)
		add("WindowBar", Vector3.new(width, 0.14, 0.1), at(cu, cv, face + 0.11), FRAME_COLOR)
		-- cut the beams that cross the frame (outer rectangle: jambs, head, sill)
		local u0, u1 = cu - width / 2 - J - 0.15, cu + width / 2 + J + 0.15
		local v0, v1 = cv - height / 2 - 0.3, cv + height / 2 + 0.42
		local zone = at((u0 + u1) / 2, (v0 + v1) / 2, face)
		local zoneSize = Vector3.new(u1 - u0, v1 - v0, 1.6)
		for _, beam in ipairs(model:GetChildren()) do
			if beam:IsA("BasePart") and beam.Name == "Timber" and boxOverlap(zone, zoneSize, beam.CFrame, beam.Size) then
				local du, dv = extent(beam, across), extent(beam, Vector3.yAxis)
				if du >= dv then
					cut += cutBeam(beam, across, u0 + 0.15, u1 - 0.15)
				else
					cut += cutBeam(beam, Vector3.yAxis, v0, v1)
				end
			end
		end
		glass:SetAttribute("WindowFramed", true)
		framed += 1
	end
	return `{model:GetFullName()}: {framed} window(s) framed, {trims} old trim piece(s) removed, {cut} beam piece(s) left after the cuts` .. (if skipped > 0 then `, {skipped} already framed` else "")
end

---------------------------------------------------------------------
-- install: build, replace ServerStorage.MapProps.<propId> (the old template is kept in MapProps._Previous)
---------------------------------------------------------------------
function StudioProps.install(propId: string): string
	local builder = StudioProps[propId]
	assert(type(builder) == "function" and propId ~= "install" and propId ~= "materials", `StudioProps: no builder for {propId}`)
	local folder = ServerStorage:FindFirstChild("MapProps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MapProps"
		folder.Parent = ServerStorage
	end
	local model = builder()
	model.Name = propId
	model:PivotTo(CFrame.identity)
	local lowNote = ""
	if StudioProps.LOWPOLY then
		local flatParts, banded, overlays = StudioProps.lowPoly(model, propId)
		lowNote = `; low-poly: {flatParts} part(s) made flat, {banded} banded, ` .. (if overlays then `{overlays} overlay texture(s)` else "overlays waiting for Config/PropTextures")
	end
	local parts = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	if STALL_MARKERS[propId] and piecesApplied(propId) then
		-- the frame goes to MapProps._Base (the pieces template stays in place until ApplyPropMeshes rebuilds it)
		local store = folder:FindFirstChild("_Base") :: Instance
		local oldBase = store:FindFirstChild(propId)
		if oldBase then
			local previous = folder:FindFirstChild("_Previous") or Instance.new("Folder")
			previous.Name = "_Previous"
			previous.Parent = folder
			local stale = previous:FindFirstChild(propId .. "_base")
			if stale then
				stale:Destroy()
			end
			oldBase.Name = propId .. "_base"
			oldBase.Parent = previous
		end
		model.Parent = store
		return string.format("rebuilt the bare frame into ServerStorage.MapProps._Base.%s (%d parts%s); MapProps.%s (the Blender pieces) is unchanged: run ApplyPropMeshes.run({ only = { \"%s\" } }) to put the pieces on the new frame", propId, parts, lowNote, propId, propId)
	end
	local old = folder:FindFirstChild(propId)
	if old then
		local previous = folder:FindFirstChild("_Previous") or Instance.new("Folder")
		previous.Name = "_Previous"
		previous.Parent = folder
		local stale = previous:FindFirstChild(propId)
		if stale then
			stale:Destroy()
		end
		old.Parent = previous
	end
	model.Parent = folder
	local _, size = model:GetBoundingBox()
	return string.format("installed ServerStorage.MapProps.%s: %d parts, bbox %.2f x %.2f x %.2f%s", propId, parts, size.X, size.Y, size.Z, lowNote)
end

return StudioProps
