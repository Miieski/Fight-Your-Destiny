--!strict
-- Weapon Tools (docs/weapon_shop_brief.txt part 1): ReplicatedStorage.Assets.Weapons.<WeaponId>.
--   local WT = require(game.ServerStorage.DevTools.WeaponTools)
--   WT.placeholders()      -- builds a placeholder Tool for every weapon that has no real model yet
--   WT.fromImport(folder)  -- turns the imported FBX meshes found in `folder` into the real Tools
--                            (see Blender/Weapons/README.txt); placeholders of the others stay
-- Convention (same as the Blender models): the Handle's origin is where the hand holds the weapon, the
-- blade / head points along the Handle's +Y, its front faces -Z. The FBX export (Y up, -Z forward) maps
-- Blender (x, y, z) to Roblox (-x, z, y)... i.e. Blender +X becomes -X: a bow string drawn on Blender -X is
-- on Roblox +X, a gauntlet's thumb on +X. Tool.Grip per category / ranged type: GRIPS below.
-- Every Tool: attributes WeaponId, Category, Zone (1..12), Placeholder; TipAttachment and BaseAttachment
-- on the Handle (+ MuzzleAttachment for Ranged and Magic); parts unanchored, CanCollide off, Massless.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio's command bar / plugins cache required modules: load the configs from fresh copies so an edited
-- config is always the one used.
local function fresh(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end
local Config = ReplicatedStorage.GameSystem.Config
local WeaponCategories = fresh(Config.WeaponCategories :: ModuleScript)
local Weapons = fresh(Config.Weapons :: ModuleScript)

local WeaponTools = {}

local DEVTOOLS = script.Parent -- kept: a command-bar copy of this module is gone after require

local rgb = Color3.fromRGB

-- Placeholder colors per zone: Blade (metal / head), Handle, Accent (neon glow).
local PALETTE = {
	Plains = { rgb(185, 193, 201), rgb(138, 90, 51), rgb(120, 200, 90) },
	Desert = { rgb(220, 208, 176), rgb(185, 139, 85), rgb(226, 176, 74) },
	Jungle = { rgb(154, 163, 159), rgb(110, 74, 42), rgb(60, 200, 80) },
	Tundra = { rgb(168, 221, 245), rgb(74, 93, 115), rgb(143, 232, 255) },
	Swamp = { rgb(111, 122, 90), rgb(74, 58, 42), rgb(124, 255, 74) },
	Volcano = { rgb(42, 34, 36), rgb(59, 43, 40), rgb(255, 106, 31) },
	Hell = { rgb(106, 26, 22), rgb(30, 20, 20), rgb(255, 48, 48) },
	Heaven = { rgb(255, 255, 255), rgb(232, 194, 90), rgb(255, 224, 112) },
	Dead = { rgb(230, 220, 192), rgb(58, 52, 64), rgb(124, 255, 176) },
	Abyss = { rgb(63, 181, 200), rgb(31, 63, 106), rgb(95, 255, 240) },
	Mechanical = { rgb(154, 164, 178), rgb(58, 63, 72), rgb(63, 230, 255) },
	Void = { rgb(58, 44, 85), rgb(42, 30, 61), rgb(176, 91, 255) },
}

-- Placeholder shapes per category, in studs, in Handle space (+Y = head). Each part:
-- { name, shape ("Block" | "Ball" | "Cyl" = cylinder along Y | "Diamond" = block turned 45 deg around Z),
--   size, position, color role (1 blade, 2 handle, 3 accent neon), z rotation in degrees? }
-- Tip / Base: attachment positions; Muzzle: Ranged / Magic only. Lengths match Config/Weapons sizes
-- of the real models (Sword 4.5, Spear 8, Heavy 5, Dagger 2, Gauntlet 1.8, Ranged 5, Magic 6, Whip 6).
local V = Vector3.new
local SHAPES = {
	Sword = {
		Parts = {
			{ "Grip", "Cyl", V(0.3, 1.0, 0.3), V(0, 0, 0), 2 },
			{ "Pommel", "Ball", V(0.36, 0.36, 0.36), V(0, -0.62, 0), 1 },
			{ "Guard", "Block", V(1.1, 0.22, 0.3), V(0, 0.6, 0), 1 },
			{ "Blade", "Block", V(0.36, 2.8, 0.08), V(0, 2.11, 0), 1 },
			{ "Tip", "Diamond", V(0.255, 0.255, 0.08), V(0, 3.51, 0), 1 },
			{ "Fuller", "Block", V(0.08, 2.2, 0.1), V(0, 1.95, 0), 3 },
		},
		Tip = V(0, 3.68, 0), Base = V(0, 0.72, 0),
	},
	Spear = {
		Parts = {
			{ "Shaft", "Cyl", V(0.22, 6.4, 0.22), V(0, 1.2, 0), 2 },
			{ "Butt", "Cyl", V(0.28, 0.25, 0.28), V(0, -2.0, 0), 1 },
			{ "Socket", "Cyl", V(0.3, 0.4, 0.3), V(0, 4.45, 0), 1 },
			{ "Head", "Block", V(0.42, 1.1, 0.1), V(0, 5.2, 0), 1 },
			{ "Point", "Diamond", V(0.3, 0.3, 0.1), V(0, 5.75, 0), 1 },
			{ "Ring", "Cyl", V(0.27, 0.12, 0.27), V(0, 4.15, 0), 3 },
		},
		Tip = V(0, 5.96, 0), Base = V(0, 4.65, 0),
	},
	Heavy = {
		Parts = {
			{ "Shaft", "Cyl", V(0.3, 4.4, 0.3), V(0, 1.0, 0), 2 },
			{ "Pommel", "Block", V(0.4, 0.25, 0.4), V(0, -1.25, 0), 1 },
			{ "Head", "Block", V(1.6, 0.9, 0.9), V(0, 3.25, 0), 1 },
			{ "Band", "Block", V(0.25, 0.92, 0.92), V(0, 3.25, 0), 3 },
		},
		Tip = V(0, 3.7, 0), Base = V(0, 2.8, 0),
	},
	Dagger = {
		Parts = {
			{ "Grip", "Cyl", V(0.22, 0.7, 0.22), V(0, 0, 0), 2 },
			{ "Pommel", "Ball", V(0.26, 0.26, 0.26), V(0, -0.42, 0), 1 },
			{ "Guard", "Block", V(0.6, 0.15, 0.18), V(0, 0.42, 0), 1 },
			{ "Blade", "Block", V(0.26, 0.95, 0.07), V(0, 0.97, 0), 1 },
			{ "Tip", "Diamond", V(0.184, 0.184, 0.07), V(0, 1.44, 0), 1 },
			{ "Fuller", "Block", V(0.06, 0.7, 0.09), V(0, 0.9, 0), 3 },
		},
		Tip = V(0, 1.57, 0), Base = V(0, 0.5, 0),
	},
	Gauntlet = { -- origin = fist center, knuckles +Y (one right-hand gauntlet, Blender/Weapons/README.txt)
		Parts = {
			{ "Fist", "Block", V(0.62, 0.6, 0.5), V(0, 0, 0), 1 },
			{ "Cuff", "Cyl", V(0.58, 1.1, 0.5), V(0, -0.8, 0), 2 },
			{ "Knuckles", "Block", V(0.66, 0.16, 0.54), V(0, 0.28, 0), 3 },
			{ "Thumb", "Block", V(0.16, 0.36, 0.3), V(0.36, 0.02, 0), 1 },
		},
		Tip = V(0, 0.36, 0), Base = V(0, -0.3, 0),
	},
	Ranged = { -- a bow: limbs along Y, string on +X, arrows fly towards -X (like the imported bows)
		Parts = {
			{ "Grip", "Cyl", V(0.26, 0.8, 0.26), V(0, 0, 0), 2 },
			{ "UpperLimb", "Block", V(0.16, 2.08, 0.16), V(0.25, 1.4, 0), 1, -14 },
			{ "LowerLimb", "Block", V(0.16, 2.08, 0.16), V(0.25, -1.4, 0), 1, 14 },
			{ "String", "Block", V(0.04, 4.8, 0.04), V(0.52, 0, 0), 3 },
		},
		Tip = V(0.5, 2.42, 0), Base = V(0, 0.45, 0), Muzzle = V(-0.2, 0.08, 0),
	},
	Magic = {
		Parts = {
			{ "Shaft", "Cyl", V(0.25, 5.3, 0.25), V(0, 0.65, 0), 2 },
			{ "Butt", "Cyl", V(0.3, 0.2, 0.3), V(0, -2.0, 0), 1 },
			{ "Cup", "Cyl", V(0.45, 0.3, 0.45), V(0, 3.35, 0), 1 },
			{ "ProngL", "Block", V(0.1, 0.7, 0.1), V(-0.3, 3.7, 0), 1, -20 },
			{ "ProngR", "Block", V(0.1, 0.7, 0.1), V(0.3, 3.7, 0), 1, 20 },
			{ "Orb", "Ball", V(0.75, 0.75, 0.75), V(0, 3.75, 0), 3 },
		},
		Tip = V(0, 4.13, 0), Base = V(0, 3.2, 0), Muzzle = V(0, 3.75, 0),
	},
	Whip = { -- handle + an S-curved lash rising along +Y
		Parts = {
			{ "Grip", "Cyl", V(0.28, 1.2, 0.28), V(0, 0, 0), 2 },
			{ "Pommel", "Ball", V(0.34, 0.34, 0.34), V(0, -0.68, 0), 1 },
			{ "Lash1", "Block", V(0.2, 1.2, 0.2), V(0.12, 1.15, 0), 1, -12 },
			{ "Lash2", "Block", V(0.17, 1.2, 0.17), V(0.24, 2.3, 0), 1, 6 },
			{ "Lash3", "Block", V(0.14, 1.2, 0.14), V(0.0, 3.4, 0), 1, 22 },
			{ "Lash4", "Block", V(0.11, 1.2, 0.11), V(-0.38, 4.45, 0), 1, 14 },
			{ "Cracker", "Ball", V(0.2, 0.2, 0.2), V(-0.55, 5.1, 0), 3 },
		},
		Tip = V(-0.55, 5.15, 0), Base = V(0, 0.62, 0),
	},
}

-- Tool.Grip: how the Handle sits in the hand (R15 RightGripAttachment, measured in Play on 2026-10-05).
-- Identity = the head points up out of the fist (arm forward, toolnone pose) with the front facing forward:
-- good for swords, spears, heavies, daggers, staffs and whips. The others turn the Handle in the hand:
local function turn(right: Vector3, up: Vector3, back: Vector3): CFrame
	-- the hand-space directions of the Handle's +X, +Y, +Z; Tool.Grip is the inverse of that rotation
	return CFrame.fromMatrix(Vector3.zero, right, up, back):Inverse()
end
local GRIP_TYPES = {
	Bow = turn(Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)), -- limbs up, string to the body, arrow forward
	Gun = turn(Vector3.new(0, -1, 0), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)), -- muzzle forward, pistol grip down
	Crossbow = turn(Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0)), -- bolt forward, prod flat, trigger down
	Fist = turn(Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0)), -- knuckles forward, back of the hand up
}
local GRIPS: { [string]: CFrame } = { -- per category (placeholders)
	Ranged = GRIP_TYPES.Bow,
	Gauntlet = GRIP_TYPES.Fist,
}
-- Real Ranged models are bows, crossbows or guns (Blender/Weapons/README.txt): per weapon.
local WEAPON_GRIPS: { [string]: CFrame } = {
	tundra_ranged = GRIP_TYPES.Crossbow, hell_ranged = GRIP_TYPES.Crossbow, dead_ranged = GRIP_TYPES.Crossbow,
	jungle_ranged = GRIP_TYPES.Gun, abyss_ranged = GRIP_TYPES.Gun, mechanical_ranged = GRIP_TYPES.Gun,
}

local function folder(): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets") :: Instance
	local weapons = assets:FindFirstChild("Weapons")
	if not weapons then
		weapons = Instance.new("Folder")
		weapons.Name = "Weapons"
		weapons.Parent = assets
	end
	return weapons :: Folder
end

local function prepare(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
end

local function attach(handle: BasePart, name: string, position: Vector3?)
	if position then
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = position
		attachment.Parent = handle
	end
end

local function finishTool(tool: Tool, weapon: any, placeholder: boolean)
	tool.Name = weapon.Id
	tool.ToolTip = weapon.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = (if placeholder then nil else WEAPON_GRIPS[weapon.Id]) or GRIPS[weapon.Category] or CFrame.new()
	tool:SetAttribute("WeaponId", weapon.Id)
	tool:SetAttribute("Category", weapon.Category)
	tool:SetAttribute("Zone", weapon.Zone)
	tool:SetAttribute("Placeholder", placeholder)
end

function WeaponTools.placeholder(weapon: any): Tool
	local shape = SHAPES[weapon.Category]
	local colors = PALETTE[weapon.ZoneId]
	local tool = Instance.new("Tool")
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.6, 0.3)
	handle.Transparency = 1
	handle.CFrame = CFrame.new()
	prepare(handle)
	handle.Parent = tool
	local model = Instance.new("Model")
	model.Name = "PLACEHOLDER_" .. weapon.Id
	model.Parent = tool
	for _, spec in ipairs(shape.Parts) do
		local name, kind, size, position, role, rotZ = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
		local part = Instance.new("Part")
		part.Name = name
		local cframe = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(rotZ or 0))
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
			part.Size = size
		elseif kind == "Cyl" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(size.Y, size.X, size.Z) -- a cylinder's axis is X: turn it onto Y
			cframe *= CFrame.Angles(0, 0, math.rad(90))
		elseif kind == "Diamond" then
			part.Size = size
			cframe *= CFrame.Angles(0, 0, math.rad(45))
		else
			part.Size = size
		end
		part.CFrame = cframe
		part.Color = colors[role]
		part.Material = if role == 3 then Enum.Material.Neon elseif role == 2 then Enum.Material.SmoothPlastic else Enum.Material.Metal
		if role == 1 and (weapon.ZoneId == "Tundra" or weapon.ZoneId == "Heaven") then
			part.Material = Enum.Material.SmoothPlastic
		end
		prepare(part)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	attach(handle, "TipAttachment", shape.Tip)
	attach(handle, "BaseAttachment", shape.Base)
	attach(handle, "MuzzleAttachment", if WeaponCategories.ById[weapon.Category].Muzzle then shape.Muzzle else nil)
	finishTool(tool, weapon, true)
	return tool
end

-- Builds a placeholder for every weapon without a Tool (or rebuilds all placeholders with rebuild = true).
-- Real Tools (Placeholder = false) are never touched. Returns the number of Tools built.
function WeaponTools.placeholders(rebuild: boolean?): number
	local weapons = folder()
	local count = 0
	for _, weapon in ipairs(Weapons.List) do
		local existing = weapons:FindFirstChild(weapon.Id)
		if existing and (existing:GetAttribute("Placeholder") == false or not rebuild) then
			continue
		end
		if existing then
			existing:Destroy()
		end
		WeaponTools.placeholder(weapon).Parent = weapons
		count += 1
	end
	return count
end

-- Sets Tool.Grip on every Tool of a category (used while tuning the grips in Play).
function WeaponTools.setGrip(category: string, grip: CFrame)
	GRIPS[category] = grip
	for _, tool in ipairs(folder():GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("Category") == category then
			tool.Grip = grip
		end
	end
end

-- Turns imported weapon models into the real Tools. `source` holds what Studio's importer produced
-- (Asset Manager -> Bulk Import of Blender_Exports/Weapons/<Category>/*.fbx, File Dimensions = Meters, then
-- the imported models dragged into one folder): one Model (or MeshPart) per file, named like the file
-- ("01_plains_sword") or like the weapon id. The biggest part becomes the Handle; the others are welded to it;
-- parts whose name contains "Glow" become Neon (the emissive "<id>_Glow" material). The importer recenters
-- meshes on their box, so the grip is put back with DevTools.WeaponBounds. Returns built, skipped.
function WeaponTools.fromImport(source: Instance): ({ string }, { string })
	local Bounds = fresh(DEVTOOLS:FindFirstChild("WeaponBounds") :: ModuleScript)
	local built, skipped = {}, {}
	for _, item in ipairs(source:GetChildren()) do
		local name = string.lower(item.Name)
		local id = string.match(name, "^%d%d_(.+)$") or name
		local weapon = Weapons.ById[id]
		local bounds = Bounds[id]
		local parts: { BasePart } = {}
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
		for _, d in ipairs(item:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		if not (weapon and bounds and #parts > 0) then
			table.insert(skipped, item.Name)
			continue
		end
		-- world box of the import = the Blender box; its center sits at origin + bounds center
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		local main = parts[1]
		for _, part in ipairs(parts) do
			local half = part.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
						low = low:Min(corner)
						high = high:Max(corner)
					end
				end
			end
			if part.Size.X * part.Size.Y * part.Size.Z > main.Size.X * main.Size.Y * main.Size.Z then
				main = part
			end
		end
		local size = high - low
		if math.abs(size.Y - bounds[2].Y) > 0.25 * bounds[2].Y then
			warn(`WeaponTools: {id} is {math.round(size.Y * 100) / 100} studs long, expected {bounds[2].Y} (import scale?)`)
		end
		local origin = (low + high) / 2 - bounds[1]
		local tool = Instance.new("Tool")
		local handle = main:Clone()
		handle.Name = "Handle"
		for _, child in ipairs(handle:GetChildren()) do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		prepare(handle)
		handle.Parent = tool
		for _, part in ipairs(parts) do
			if part ~= main then
				local copy = part:Clone()
				for _, child in ipairs(copy:GetChildren()) do
					if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
						child:Destroy()
					end
				end
				if string.find(string.lower(copy.Name), "glow") then
					copy.Material = Enum.Material.Neon
				end
				prepare(copy)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = copy
				weld.Parent = copy
				copy.Parent = tool
			end
		end
		local function local_(point: Vector3): Vector3
			return handle.CFrame:PointToObjectSpace(point)
		end
		local top = origin + Vector3.new(0, bounds[1].Y + bounds[2].Y / 2, 0)
		attach(handle, "TipAttachment", local_(top))
		attach(handle, "BaseAttachment", local_(origin:Lerp(top, 0.18)))
		if WeaponCategories.ById[weapon.Category].Muzzle then
			attach(handle, "MuzzleAttachment", local_(if weapon.Category == "Magic" then top else origin + Vector3.new(-0.3, 0.1, 0)))
		end
		finishTool(tool, weapon, false)
		-- the hand holds the true origin; the rotation part comes from the grip tables
		tool.Grip = CFrame.new(local_(origin)) * tool.Grip.Rotation
		local weapons = folder()
		local old = weapons:FindFirstChild(weapon.Id)
		if old then
			old:Destroy()
		end
		tool.Parent = weapons
		table.insert(built, weapon.Id)
	end
	return built, skipped
end

-- Lists the weapons that still use a placeholder.
function WeaponTools.missing(): { string }
	local list = {}
	for _, weapon in ipairs(Weapons.List) do
		local tool = folder():FindFirstChild(weapon.Id)
		if not tool or tool:GetAttribute("Placeholder") ~= false then
			table.insert(list, weapon.Id)
		end
	end
	return list
end

WeaponTools.SHAPES = SHAPES
WeaponTools.GRIPS = GRIPS
WeaponTools.GRIP_TYPES = GRIP_TYPES
WeaponTools.WEAPON_GRIPS = WEAPON_GRIPS
WeaponTools.finishTool = finishTool
WeaponTools.prepare = prepare
WeaponTools.attach = attach
WeaponTools.folder = folder

return WeaponTools
