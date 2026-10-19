--!strict
-- Turns the creature FBX files of Blender_Exports/ (imported by the owner) into game-ready rigs
-- (Blender/README.txt, docs/enemies_npcs_pets_brief.txt Part E).
--   require(game.ServerStorage.DevTools.EnemyModels).fromImport(folder) -> built, skipped
--     folder: where the imported Models are (any place, e.g. workspace.ImportedCreatures); each Model is named by its
--     id (plains_boar, desert_cursed_pharaoh, plains_pet1, npc_guide...).
--   require(...).missing() -> ids of zones 1-4 enemies that still use a placeholder
-- The FBX object names carry the rig: "<Part>__<Parent>__<jx>_<jy>_<jz>" (joint in studs from the feet center),
-- "Root__<cx>_<cy>_<cz>__<sx>_<sy>_<sz>" (hitbox), "<Name>_Glow__<Parent>__<hex>" (Neon piece). The result:
-- an invisible "Root" hitbox (PrimaryPart, RootAttachment), every MeshPart joined to its parent by a Motor6D named
-- after it (the AnimPlayer joint names), glow parts Neon, attributes Rig / HalfHeight / Imported, saved to
--   enemies / mini-bosses: ServerStorage.Enemies.<id>   bosses: ServerStorage.Bosses.<id>
--   pets: ReplicatedStorage.Assets.Pets.<id>          NPCs: ServerStorage.NPCs.<id>
-- EnemyService uses ServerStorage.Enemies / Bosses automatically (placeholders otherwise).
-- Import unit: the files are written in metres, but any Scale Unit works: the Root box's imported size is compared
-- with the size written in its name (studs; the height decides) and the whole model is scaled back uniformly
-- (attribute ImportScaleFixed = the factor found); a Root narrower than its name, or far wider, is refused.
--   require(...).buildOne(importedModel) -> ok, id or reason, note: one import -> its destination (used by
--   DevTools.ApplyPropMeshes.run() for the npc_* imports, so the props and the NPCs share one command)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)

local EnemyModels = {}

local function vec(text: string): Vector3?
	local x, y, z = string.match(text, "^(%-?[%d%.]+)_(%-?[%d%.]+)_(%-?[%d%.]+)$")
	if not x then
		return nil
	end
	return Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)
end

type Piece = { part: BasePart, name: string, parent: string, joint: Vector3?, glow: Color3? }

local function parse(model: Instance): (BasePart?, Vector3?, Vector3?, { Piece })
	local root, center, size = nil, nil, nil
	local pieces = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local fields = string.split(d.Name, "__")
			if fields[1] == "Root" and #fields == 3 then
				root, center, size = d, vec(fields[2]), vec(fields[3])
			elseif #fields == 3 then
				local name = fields[1]
				if string.sub(name, -5) == "_Glow" then
					local hex = fields[3]
					local ok, color = pcall(Color3.fromHex, hex)
					table.insert(pieces, { part = d, name = name, parent = fields[2], joint = nil, glow = if ok then color else Color3.new(1, 1, 1) })
				else
					table.insert(pieces, { part = d, name = name, parent = fields[2], joint = vec(fields[3]), glow = nil })
				end
			end
		end
	end
	return root, center, size, pieces
end

local function destination(id: string): (Instance, string)
	local def = Enemies.ById[id]
	if def then
		local folderName = if def.Tier == "boss" then "Bosses" else "Enemies"
		local folder = ServerStorage:FindFirstChild(folderName) or Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = ServerStorage
		return folder, def.Rig or "Biped"
	elseif string.match(id, "^npc_") then
		local folder = ServerStorage:FindFirstChild("NPCs") or Instance.new("Folder")
		folder.Name = "NPCs"
		folder.Parent = ServerStorage
		return folder, "Biped"
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	local pets = assets:FindFirstChild("Pets") or Instance.new("Folder")
	pets.Name = "Pets"
	pets.Parent = assets
	return pets, "Pet"
end

-- One imported Model -> rig. Returns the new Model or nil + reason.
function EnemyModels.build(imported: Instance, id: string?): (Model?, string?)
	local rid = id or imported.Name
	local rootSource, center, size, pieces = parse(imported)
	if not (rootSource and center and size) then
		return nil, "no Root__ part (was it exported by tools/blender/fyd_creatures.py?)"
	end
	-- import unit: k = imported Root height / the height in its name; every piece is scaled back by 1/k around the feet.
	-- The 3D Importer can bring the Root mesh in wider than its name (seen 2026-10-19 on the hub NPCs: 4.03 x 6 x 3.93
	-- for a 3.05 x 6 x 2.77 box, a x28 import), never narrower: the height decides, the width only has to be plausible
	local rs = rootSource.Size
	local kx, ky, kz = rs.X / size.X, rs.Y / size.Y, rs.Z / size.Z
	if ky <= 0 or kx < ky * 0.97 or kz < ky * 0.97 or kx > ky * 1.6 or kz > ky * 1.6 then
		return nil, string.format("the Root box (%.3f, %.3f, %.3f) is not its named size (%.3f, %.3f, %.3f) scaled evenly: distorted or turned import", rs.X, rs.Y, rs.Z, size.X, size.Y, size.Z)
	end
	local k = ky
	if math.abs(k - 1) <= 0.01 then
		k = 1
	end
	-- feet center: the imported Model's pivot when the importer put it at the scene origin (Set Pivot to Scene Origin:
	-- on the model's bottom face, inside its footprint); otherwise from the Root box
	local origin = rootSource.Position - center * k
	if imported:IsA("Model") then
		local pivot = imported:GetPivot().Position
		local boxCF, boxSize = imported:GetBoundingBox()
		local rel = boxCF:PointToObjectSpace(pivot)
		if math.abs(rel.Y + boxSize.Y / 2) <= 0.02 * boxSize.Y and math.abs(rel.X) <= boxSize.X / 2 and math.abs(rel.Z) <= boxSize.Z / 2 then
			origin = pivot
		end
	end
	local model = Instance.new("Model")
	model.Name = rid
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = CFrame.new(origin + center)
	root.Transparency = 1
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, true
	root.Anchored = false
	root.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	local parts: { [string]: BasePart } = { Root = root }
	for _, piece in ipairs(pieces) do
		local part = piece.part:Clone()
		-- the importer nests child meshes under their parent mesh (ArmL under Torso...): every piece is cloned on its
		-- own, so the raw copies of its children must not come along
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("BasePart") then
				child:Destroy()
			end
		end
		if k ~= 1 then
			part.Size = part.Size / k
			part.CFrame = CFrame.new(origin + (part.Position - origin) / k) * part.CFrame.Rotation
		end
		part.Name = piece.name
		part.Anchored = false
		part.CanCollide, part.CanTouch = false, false
		part.CanQuery = true
		part.Massless = true
		if piece.glow then
			part.Material = Enum.Material.Neon
			part.Color = piece.glow
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
		end
		part.Parent = model
		parts[piece.name] = part
	end
	for _, piece in ipairs(pieces) do
		local part = parts[piece.name]
		local parent = parts[piece.parent] or root
		local joint = if piece.joint then CFrame.new(origin + piece.joint) else CFrame.new(part.Position)
		local motor = Instance.new("Motor6D")
		motor.Name = piece.name
		motor.Part0 = parent
		motor.Part1 = part
		motor.C0 = parent.CFrame:Inverse() * joint
		motor.C1 = part.CFrame:Inverse() * joint
		motor.Parent = part
	end
	model.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse() * CFrame.new(origin)
	model:SetAttribute("HalfHeight", size.Y / 2)
	model:SetAttribute("Imported", true)
	if k ~= 1 then
		model:SetAttribute("ImportScaleFixed", math.round(k * 1000) / 1000)
	end
	return model, nil
end

-- one imported Model -> its destination (the old rig of that id is replaced). Returns ok, id (or the reason) and a
-- note (the scale fix, if any)
function EnemyModels.buildOne(imported: Instance): (boolean, string, string?)
	local id = (string.gsub(imported.Name, "%.fbx$", ""))
	local model, reason = EnemyModels.build(imported, id)
	if not model then
		return false, `{imported.Name}: {reason}`, nil
	end
	local target, rig = destination(id)
	model:SetAttribute("Rig", rig)
	local old = target:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	model.Parent = target
	local k = model:GetAttribute("ImportScaleFixed")
	return true, id, if k then `import unit off by x{k}: scaled back to {model:GetAttribute("HalfHeight") * 2} studs tall` else nil
end

function EnemyModels.fromImport(folder: Instance): ({ string }, { string })
	local built, skipped = {}, {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			local ok, idOrReason, note = EnemyModels.buildOne(child)
			if ok then
				table.insert(built, idOrReason .. (if note then ` ({note})` else ""))
			else
				table.insert(skipped, idOrReason)
				warn(`EnemyModels: skipped - {idOrReason}`)
			end
		end
	end
	print(`EnemyModels.fromImport: {#built} built, {#skipped} skipped`)
	return built, skipped
end

function EnemyModels.missing(): { string }
	local list = {}
	for id, def in pairs(Enemies.ById) do
		if def.Rig then
			local folder = ServerStorage:FindFirstChild(if def.Tier == "boss" then "Bosses" else "Enemies")
			if not (folder and folder:FindFirstChild(id)) then
				table.insert(list, id)
			end
		end
	end
	table.sort(list)
	return list
end

return EnemyModels
