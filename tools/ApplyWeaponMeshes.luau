--!strict
-- Weapon models V2 -> the game's weapon Tools (docs/weapons_combat_brief.txt Phase 3).
-- After the owner's Bulk Import of Blender_Exports/Weapons/<Category>/*.fbx (Asset Manager -> Bulk Import, File
-- Dimensions = Meters), with the imported models / MeshParts anywhere in the place (not rotated):
--   require(game.ServerStorage.DevTools.ApplyWeaponMeshes)(searchRoot?)   -- default: the whole place
-- For every weapon it finds the import named like its file ("01_plains_sword") or like its id ("plains_sword"),
-- then in ReplicatedStorage.Assets.Weapons.<WeaponId>:
--   - the biggest imported MeshPart becomes the Handle (its mesh, textures and SurfaceAppearance come along); the
--     other parts are welded to it, parts named "...Glow..." become Neon;
--   - the placeholder parts are removed; the Tool's attributes and its Grip rotation are kept, the Grip position moves
--     to the model's true origin (Studio recenters imported meshes on their box: DevTools.WeaponPoints gives the box);
--   - TipAttachment, BaseAttachment, MuzzleAttachment (Ranged / Magic) and ImpactAttachment (Heavy) are rebuilt at the
--     points measured in Blender; Placeholder = false, MeshVersion = 2.
-- It prints a report (applied / missing / wrong size) and returns { applied, missing, wrongSize }. A weapon whose
-- import has the wrong size (not imported in Meters) is reported and left untouched. The imports are not deleted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SIZE_TOLERANCE = 0.12 -- relative difference allowed on the longest side

-- Studio's command bar caches required modules: fresh copies so edited data is always the one used.
local function fresh(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

local DEVTOOLS = script.Parent

local function clearJoints(part: Instance)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("Attachment") then
			child:Destroy()
		end
	end
end

local function prepare(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
end

-- id -> the imported instance (a Model or a MeshPart), searched under root (outside the weapon Tools).
local function findImports(root: Instance, weaponsFolder: Instance, ids: { [string]: boolean }): { [string]: Instance }
	local found: { [string]: Instance } = {}
	for _, item in ipairs(root:GetDescendants()) do
		if (item:IsA("Model") or item:IsA("MeshPart")) and not item:IsDescendantOf(weaponsFolder) then
			local name = string.lower(item.Name)
			local id = string.match(name, "^%d%d_(.+)$") or name
			if ids[id] and not found[id] then
				found[id] = item
			end
		end
	end
	return found
end

local function partsOf(item: Instance): { BasePart }
	local parts: { BasePart } = {}
	if item:IsA("BasePart") then
		table.insert(parts, item)
	end
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function worldBox(parts: { BasePart }): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
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
	end
	return low, high
end

local function volume(part: BasePart): number
	return part.Size.X * part.Size.Y * part.Size.Z
end

return function(searchRoot: Instance?): { [string]: { string } }
	local Weapons = fresh(ReplicatedStorage.GameSystem.Config.Weapons :: ModuleScript)
	local Points = fresh(DEVTOOLS:FindFirstChild("WeaponPoints") :: ModuleScript)
	local WeaponTools = fresh(DEVTOOLS:FindFirstChild("WeaponTools") :: ModuleScript)
	local weaponsFolder = (ReplicatedStorage:FindFirstChild("Assets") :: Instance):FindFirstChild("Weapons") :: Instance
	local ids: { [string]: boolean } = {}
	for _, weapon in ipairs(Weapons.List) do
		ids[weapon.Id] = true
	end
	local imports: { [string]: Instance } = {}
	for _, root in ipairs(if searchRoot then { searchRoot } else { workspace, ServerStorage, ReplicatedStorage }) do
		for id, item in pairs(findImports(root, weaponsFolder, ids)) do
			imports[id] = imports[id] or item
		end
	end

	local applied, missing, wrongSize = {}, {}, {}
	for _, weapon in ipairs(Weapons.List) do
		local item = imports[weapon.Id]
		local data = Points[weapon.Id]
		local parts = if item then partsOf(item) else {}
		if not (item and data and #parts > 0) then
			table.insert(missing, weapon.Id)
			continue
		end
		local low, high = worldBox(parts)
		local size = high - low
		local expected = data.Size :: Vector3
		local longest = math.max(expected.X, expected.Y, expected.Z)
		local measured = math.max(size.X, size.Y, size.Z)
		if math.abs(measured - longest) > SIZE_TOLERANCE * longest then
			table.insert(wrongSize, `{weapon.Id} ({math.round(measured * 100) / 100} studs, expected {math.round(longest * 100) / 100})`)
			continue
		end
		local main = parts[1]
		for _, part in ipairs(parts) do
			if volume(part) > volume(main) then
				main = part
			end
		end
		-- the grip (origin) in the world: the import's box center minus the box center measured from the grip
		local origin = (low + high) / 2 - (data.Center :: Vector3)

		-- a real Tool keeps its (maybe hand-tuned) grip rotation; a placeholder gets the weapon's grip type
		local tool = weaponsFolder:FindFirstChild(weapon.Id) :: Tool?
		local tableGrip: CFrame = WeaponTools.WEAPON_GRIPS[weapon.Id] or WeaponTools.GRIPS[weapon.Category] or CFrame.new()
		local rotation = if tool and tool:GetAttribute("Placeholder") == false then tool.Grip.Rotation else tableGrip.Rotation
		if not tool then
			local newTool = Instance.new("Tool")
			WeaponTools.finishTool(newTool, weapon, false)
			newTool.Parent = weaponsFolder
			tool = newTool
		end
		local target = tool :: Tool
		for _, child in ipairs(target:GetChildren()) do
			if child:IsA("BasePart") or child:IsA("Model") then
				child:Destroy()
			end
		end
		local handle = main:Clone()
		handle.Name = "Handle"
		clearJoints(handle)
		prepare(handle)
		handle.Parent = target
		for _, part in ipairs(parts) do
			if part ~= main then
				local copy = part:Clone()
				clearJoints(copy)
				if string.find(string.lower(copy.Name), "glow") then
					copy.Material = Enum.Material.Neon
				end
				prepare(copy)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = copy
				weld.Parent = copy
				copy.Parent = target
			end
		end
		local function attach(name: string, point: Vector3?)
			if point then
				local attachment = Instance.new("Attachment")
				attachment.Name = name
				attachment.Position = handle.CFrame:PointToObjectSpace(origin + point)
				attachment.Parent = handle
			end
		end
		attach("TipAttachment", data.Tip)
		attach("BaseAttachment", data.Base)
		if weapon.Category == "Ranged" or weapon.Category == "Magic" then
			attach("MuzzleAttachment", data.Muzzle or data.Tip)
		end
		if weapon.Category == "Heavy" then
			attach("ImpactAttachment", data.Impact or data.Tip)
		end
		target.Grip = CFrame.new(handle.CFrame:PointToObjectSpace(origin)) * rotation
		target:SetAttribute("WeaponId", weapon.Id)
		target:SetAttribute("Category", weapon.Category)
		target:SetAttribute("Zone", weapon.Zone)
		target:SetAttribute("Placeholder", false)
		target:SetAttribute("MeshVersion", 2)
		table.insert(applied, weapon.Id)
	end

	print(`ApplyWeaponMeshes: {#applied} weapon(s) now use their V2 mesh, {#missing} not found, {#wrongSize} with a wrong size`)
	if #missing > 0 then
		print("  not found (still placeholders): " .. table.concat(missing, ", "))
	end
	if #wrongSize > 0 then
		warn("  wrong size, import again with File Dimensions = Meters: " .. table.concat(wrongSize, ", "))
	end
	return { applied = applied, missing = missing, wrongSize = wrongSize }
end
