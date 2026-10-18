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

function StudioProps.materials(): string
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
	local parts = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
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
	return string.format("installed ServerStorage.MapProps.%s: %d parts, bbox %.2f x %.2f x %.2f", propId, parts, size.X, size.Y, size.Z)
end

return StudioProps
