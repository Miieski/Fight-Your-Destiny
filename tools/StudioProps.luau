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
