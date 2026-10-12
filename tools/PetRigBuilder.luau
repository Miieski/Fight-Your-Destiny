--!strict
-- Pets V2 (docs/pets_v2_plan.md): turns an AI-generated pet (Studio MCP generate_mesh, split into named pieces)
-- into a pet rig for Util/PetMotion and puts it where the game looks for it. Command bar, Edit mode:
--   local B = require(game.ServerStorage.DevTools.PetRigBuilder)
--   B.install(workspace["<generated model>"], "plains_pet2")   -- rig -> ReplicatedStorage.Assets.Pets.plains_pet2,
--                                                               -- raw model kept in ServerStorage.PetSources
--   B.rebuild("plains_pet2") / B.rebuildAll()                   -- re-rig from ServerStorage.PetSources
--   B.prompt("plains_pet2") -> text prompt, part names, size     -- what to pass to generate_mesh
--   B.missing() -> ids still on the procedural placeholders
-- Rig: PrimaryPart "Root" (invisible) at the feet, looking -Z; one MeshPart per piece named by its role (Body,
-- Head, Tail, LegFL...; Util/PetMotion), each with an Attachment "Joint" at its pivot; the model is scaled to
-- HEIGHT x the species' Scale. Attributes: Gait, Flying, Body, Height, PetV2.
-- The generator faces the model's pivot -Z; the head / tail positions double-check it (turned when the head is
-- behind or beside the body).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)

local PetRigBuilder = {}

PetRigBuilder.HEIGHT = 1.4 -- studs at species Scale 1 (followers are drawn x1.4: ~2 studs)
PetRigBuilder.STYLE = "cute chibi pet for a Roblox simulator game, smooth stylized toy look, big head, big shiny eyes, hand-painted texture"

-- Piece lists (max 8) and generation boxes per kind.
PetRigBuilder.KINDS = {
	Quad = { Parts = "head, body, tail, front left leg, front right leg, back left leg, back right leg", Size = Vector3.new(2, 2.2, 2.8), Pose = "standing on four short legs" },
	QuadNoTail = { Parts = "head, body, front left leg, front right leg, back left leg, back right leg", Size = Vector3.new(2, 2, 2.4), Pose = "standing on four short legs" },
	QuadWings = { Parts = "head, body, tail, left wing, right wing, front legs, back legs", Size = Vector3.new(2.8, 2.4, 2.8), Pose = "standing on four short legs, small wings folded up" },
	Biped = { Parts = "head, body, left arm, right arm, left leg, right leg", Size = Vector3.new(2, 2.6, 1.8), Pose = "standing upright on two short legs" },
	BipedTail = { Parts = "head, body, left arm, right arm, left leg, right leg, tail", Size = Vector3.new(2, 2.6, 2.4), Pose = "standing upright on two short legs" },
	BipedWings = { Parts = "head, body, left arm, right arm, left leg, right leg, left wing, right wing", Size = Vector3.new(2.8, 2.6, 2), Pose = "standing upright, small wings spread" },
	Bird = { Parts = "head, body, left wing, right wing, tail, legs", Size = Vector3.new(2.6, 2.2, 2.2), Pose = "wings slightly spread" },
	Fish = { Parts = "body, tail fin, left fin, right fin, top fin", Size = Vector3.new(1.6, 1.8, 2.8), Pose = "side fins and a big tail fin" },
	Snake = { Parts = "head, body, tail", Size = Vector3.new(2, 1.8, 2.8), Pose = "coiled, head raised" },
	Bug = { Parts = "head, body, tail, left claw, right claw, legs", Size = Vector3.new(2.4, 1.6, 2.6), Pose = "standing on its legs" },
	Spider = { Parts = "head, body, legs", Size = Vector3.new(2.6, 1.6, 2.4), Pose = "standing on eight legs" },
	Flyer = { Parts = "head, body, left wing, right wing", Size = Vector3.new(2.4, 1.8, 2), Pose = "hovering, wings spread" },
	Ghost = { Parts = "body, left arm, right arm", Size = Vector3.new(1.8, 2.2, 1.6), Pose = "floating" },
	Jelly = { Parts = "body, tentacles", Size = Vector3.new(2, 2.4, 2), Pose = "floating, tentacles hanging below" },
	Drone = { Parts = "body, left propeller, right propeller", Size = Vector3.new(2.4, 1.6, 2), Pose = "hovering" },
	Cerberus = { Parts = "body, middle head, left head, right head, tail, front legs, back legs", Size = Vector3.new(2.6, 2.4, 2.8), Pose = "standing on four short legs" },
}

-- [petId] = { kind, gait, description }  (gait: Walk | Hop | Fly | Swim | Float | Slither, Util/PetMotion)
PetRigBuilder.SPECS = {
	plains_pet1 = { "Quad", "Walk", "baby puppy dog, golden tan fur, white chest and white muzzle, floppy ears, small tail" },
	plains_pet2 = { "Quad", "Walk", "baby fox, bright orange fur, white chest, white muzzle and white fluffy tail tip, black paws" },
	plains_pet3 = { "Quad", "Walk", "baby brown bear cub, chocolate brown fur, light tan muzzle and belly, round ears, tiny tail" },
	plains_pet4 = { "Quad", "Walk", "baby boar piglet, pink brown fur with darker stripes, small white tusks, pig snout, tiny curly tail" },
	plains_pet5 = { "Quad", "Walk", "baby raccoon, grey fur, black eye mask, bushy tail with black rings" },
	plains_pet6 = { "Bird", "Fly", "baby owl, round fluffy brown and cream feathers, big round eyes, small ear tufts, tiny orange beak" },
	desert_pet1 = { "Quad", "Walk", "baby fennec fox, pale sand fur, huge ears with pink inside, cream chest, bushy tail with a black tip" },
	desert_pet2 = { "Bug", "Walk", "baby scorpion, amber orange shell, big round pincers, curled tail with a small stinger, six little legs" },
	desert_pet3 = { "Quad", "Walk", "baby camel, light sand brown fur, one round hump, long neck, sleepy eyes, tassel tail" },
	desert_pet4 = { "Snake", "Slither", "baby snake, sandy yellow scales with brown diamond pattern, big round head" },
	desert_pet5 = { "Quad", "Hop", "baby jerboa, sandy fur, huge ears, big hind feet, very long thin tail with a white tuft" },
	desert_pet6 = { "Quad", "Walk", "baby royal sphinx cat, golden fur, blue and gold striped pharaoh headdress, gold collar" },
	jungle_pet1 = { "BipedTail", "Walk", "baby monkey, brown fur, peach face and belly, big ears, long curly tail" },
	jungle_pet2 = { "Quad", "Walk", "baby tiger cub, orange fur with black stripes, white belly and muzzle, striped tail" },
	jungle_pet3 = { "Biped", "Walk", "baby gorilla, dark grey black fur, grey face and chest, long strong arms" },
	jungle_pet4 = { "Quad", "Walk", "baby crocodile, green scaly skin, light yellow belly, long snout with little teeth, ridged tail" },
	jungle_pet5 = { "Bird", "Fly", "baby toucan, black feathers, white chest, huge bright orange and yellow beak" },
	jungle_pet6 = { "Quad", "Walk", "baby chameleon, bright green skin with yellow and teal stripes, curled tail, big round eyes" },
	tundra_pet1 = { "Biped", "Walk", "baby penguin, black back, white belly, small orange beak, orange feet, little flipper arms" },
	tundra_pet2 = { "Quad", "Walk", "baby sabertooth tiger cub, light tan fur with brown spots, two long white fangs, white belly" },
	tundra_pet3 = { "Quad", "Walk", "baby polar bear cub, white fluffy fur, black nose, small round ears" },
	tundra_pet4 = { "Quad", "Walk", "baby woolly mammoth, shaggy brown fur, curled white tusks, long trunk, big floppy ears" },
	tundra_pet5 = { "Quad", "Hop", "baby snow hare bunny, white fluffy fur, long ears with pink inside, pink nose, puffy tail" },
	tundra_pet6 = { "Biped", "Walk", "baby yeti, white shaggy fur, light blue face and hands, two small horns" },
	swamp_pet1 = { "Bird", "Walk", "baby duckling, fluffy yellow feathers, orange beak and orange feet" },
	swamp_pet2 = { "QuadNoTail", "Hop", "baby frog, bright green skin, yellow belly, big round eyes on top of the head, wide smile" },
	swamp_pet3 = { "Quad", "Walk", "baby turtle, green skin, brown hexagon patterned shell, stubby legs" },
	swamp_pet4 = { "Fish", "Swim", "baby catfish, grey green skin, long whiskers, wide mouth, pale belly" },
	swamp_pet5 = { "Flyer", "Fly", "baby firefly bug, dark body, glowing yellow green light on its tail, clear wings, little antennae" },
	swamp_pet6 = { "Quad", "Walk", "baby axolotl, pink skin, frilly pink gills on the head, wide smile, long fin tail" },
	volcano_pet1 = { "QuadNoTail", "Hop", "baby lava frog, dark charcoal skin with glowing orange lava cracks and spots, big eyes" },
	volcano_pet2 = { "Quad", "Walk", "baby lava gecko lizard, red orange skin with glowing yellow spots, curled tail" },
	volcano_pet3 = { "Quad", "Walk", "baby triceratops dinosaur, green skin, beige frill and belly, three small horns" },
	volcano_pet4 = { "BipedTail", "Walk", "baby t-rex dinosaur, green skin, light belly, tiny arms, big head with little teeth, thick tail" },
	volcano_pet5 = { "Bird", "Fly", "baby pterodactyl, orange brown leathery wings, long beak, crest on the head" },
	volcano_pet6 = { "Bird", "Fly", "baby phoenix chick, red orange and gold flame feathers, flame shaped tail and crest" },
	hell_pet1 = { "BipedWings", "Fly", "baby imp demon, red skin, small black horns, little bat wings, pointy tail" },
	hell_pet2 = { "Quad", "Walk", "baby hellhound puppy, black fur, glowing red eyes, small horns, flame tipped tail" },
	hell_pet3 = { "BipedWings", "Walk", "baby gargoyle, grey stone skin, small horns, stone bat wings" },
	hell_pet4 = { "Quad", "Walk", "baby bull calf, dark red fur, big curved horns, burning flame mane, flame tail" },
	hell_pet5 = { "Flyer", "Fly", "baby bat, dark brown fur, big ears, orange flame colored bat wings" },
	hell_pet6 = { "Cerberus", "Walk", "baby cerberus puppy with three heads, black fur, red eyes, spiked collar" },
	heaven_pet1 = { "Quad", "Hop", "baby white bunny, fluffy white fur, long ears with pink inside, golden halo above the head" },
	heaven_pet2 = { "QuadWings", "Walk", "baby griffin, eagle head with white feathers and yellow beak, golden lion body, feathered wings" },
	heaven_pet3 = { "Quad", "Walk", "baby lamb made of fluffy white clouds, light blue face and legs" },
	heaven_pet4 = { "QuadWings", "Walk", "baby pegasus horse foal, white coat, light blue mane and tail, white feathered wings" },
	heaven_pet5 = { "Bird", "Fly", "baby swan, white feathers, long curved neck, orange beak" },
	heaven_pet6 = { "Quad", "Walk", "baby unicorn foal, white coat, pastel rainbow mane and tail, golden spiral horn" },
	dead_pet1 = { "Ghost", "Float", "little ghost, white glowing sheet body, round black eyes, tiny arms, wavy bottom edge" },
	dead_pet2 = { "Quad", "Walk", "skeleton puppy made of white bones, glowing green eyes" },
	dead_pet3 = { "Quad", "Walk", "mummy cat wrapped in beige bandages, one glowing green eye" },
	dead_pet4 = { "Quad", "Walk", "zombie teddy bear, pale green fur, stitches, one button eye" },
	dead_pet5 = { "Bird", "Fly", "baby raven, black feathers with purple shine, small black beak" },
	dead_pet6 = { "Quad", "Walk", "baby ghost deer fawn, pale blue glowing see-through body, glowing green antlers" },
	abyss_pet1 = { "Fish", "Swim", "baby clownfish, bright orange with three white stripes edged in black" },
	abyss_pet2 = { "Fish", "Swim", "baby swordfish, blue back, silver belly, long pointy sword nose" },
	abyss_pet3 = { "Fish", "Swim", "baby pufferfish, round yellow body with small spikes, white belly" },
	abyss_pet4 = { "Fish", "Swim", "baby shark, grey blue skin, white belly, smiling with small teeth" },
	abyss_pet5 = { "Fish", "Swim", "baby orca killer whale, black and white skin, white eye patch" },
	abyss_pet6 = { "Jelly", "Float", "baby kraken octopus, purple skin with pink spots, round head, eight curly tentacles" },
	mechanical_pet1 = { "Quad", "Walk", "robot puppy, silver metal body, glowing cyan eyes, antenna ears, small tail" },
	mechanical_pet2 = { "Spider", "Walk", "clockwork spider, brass bronze body with gears, eight thin metal legs, glowing eyes" },
	mechanical_pet3 = { "Biped", "Walk", "little steam golem robot, copper and iron plates, small chimney on its back, glowing eyes" },
	mechanical_pet4 = { "BipedTail", "Walk", "robot t-rex dinosaur, grey metal plates, red glowing eyes, tiny arms" },
	mechanical_pet5 = { "Drone", "Fly", "little flying drone robot, round silver body, one big glowing cyan eye, two propellers" },
	mechanical_pet6 = { "Quad", "Walk", "robot cat, gold brass metal body with gears, glowing green eyes" },
	void_pet1 = { "Quad", "Walk", "baby cat with galaxy fur, dark purple and blue with pink stars, glowing paws" },
	void_pet2 = { "Quad", "Walk", "baby shadow panther, black purple fur, glowing violet eyes, spikes along the back" },
	void_pet3 = { "Biped", "Walk", "baby gorilla, dark navy fur with glowing cyan star patterns" },
	void_pet4 = { "Quad", "Walk", "baby gecko, deep purple skin with glowing cyan constellation spots" },
	void_pet5 = { "Jelly", "Float", "jellyfish, see-through purple and cyan glowing dome, long ribbon tentacles" },
	void_pet6 = { "QuadWings", "Walk", "baby dragon, dark purple scales, glowing violet belly, small horns, bat wings" },
	premium_dragonling = { "QuadWings", "Walk", "baby dragon, shiny golden scales, cream belly, small horns, golden wings" },
	premium_phoenix = { "Bird", "Fly", "baby phoenix, rainbow fire feathers, long flame tail" },
	premium_golem = { "Biped", "Walk", "little crystal golem made of shiny light blue diamond crystals, glowing eyes" },
	premium_kitsune = { "Quad", "Walk", "baby kitsune fox, white fur with pink markings, nine fluffy tails, golden bell collar" },
}

local FLYING_GAITS = { Fly = true, Swim = true, Float = true }

-- What to pass to generate_mesh for a pet: textPrompt, partNames, size.
function PetRigBuilder.prompt(petId: string): (string, string, Vector3)
	local spec = PetRigBuilder.SPECS[petId]
	assert(spec, `no spec for {petId}`)
	local kind = PetRigBuilder.KINDS[spec[1]]
	return `{spec[3]}, {kind.Pose}, {PetRigBuilder.STYLE}`, kind.Parts, kind.Size
end

-- Role of a generated piece from its name ("front left leg", "tail fin", "left wing_geom"...); nil = extra.
function PetRigBuilder.roleOf(name: string): string?
	local n = string.lower(name):gsub("_geom$", "")
	local left = string.find(n, "left") ~= nil
	local right = string.find(n, "right") ~= nil
	local front = string.find(n, "front") ~= nil or string.find(n, "fore") ~= nil
	local back = string.find(n, "back") ~= nil or string.find(n, "hind") ~= nil or string.find(n, "rear") ~= nil
	if string.find(n, "head") then
		return if left or right then nil else "Head"
	elseif string.find(n, "body") or string.find(n, "torso") then
		return "Body"
	elseif string.find(n, "tail") then
		return "Tail"
	elseif string.find(n, "leg") or string.find(n, "foot") or string.find(n, "feet") or string.find(n, "paw") then
		if front and left then
			return "LegFL"
		elseif front and right then
			return "LegFR"
		elseif back and left then
			return "LegBL"
		elseif back and right then
			return "LegBR"
		elseif front then
			return "LegsF"
		elseif back then
			return "LegsB"
		elseif left then
			return "LegL"
		elseif right then
			return "LegR"
		end
		return nil
	elseif string.find(n, "arm") or string.find(n, "hand") or string.find(n, "flipper") then
		return if left then "ArmL" elseif right then "ArmR" else nil
	elseif string.find(n, "wing") then
		return if left then "WingL" elseif right then "WingR" else nil
	elseif string.find(n, "fin") then
		return if left then "FinL" elseif right then "FinR" else "FinTop"
	elseif string.find(n, "claw") or string.find(n, "pincer") then
		return if left then "ClawL" elseif right then "ClawR" else nil
	elseif string.find(n, "tentacle") then
		return "Tentacles"
	end
	return nil
end

local function corners(cf: CFrame, size: Vector3): { Vector3 }
	local h = size / 2
	local list = {}
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				table.insert(list, (cf * CFrame.new(h.X * x, h.Y * y, h.Z * z)).Position)
			end
		end
	end
	return list
end

-- axis-aligned box of a part in `frame` space
local function boxIn(frame: CFrame, part: BasePart): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in ipairs(corners(part.CFrame, part.Size)) do
		local q = frame:PointToObjectSpace(p)
		lo = lo:Min(q)
		hi = hi:Max(q)
	end
	return lo, hi
end

local function closestInBox(lo: Vector3, hi: Vector3, point: Vector3): Vector3
	return point:Max(lo):Min(hi)
end

-- The rig of one generated model (not parented). petId gives the scale and the gait.
function PetRigBuilder.build(source: Model, petId: string): Model
	local species = Pets.ById[petId]
	local spec = PetRigBuilder.SPECS[petId]
	assert(species and spec, `unknown pet {petId}`)
	-- pieces: the generator nests each MeshPart in a Model named after the piece
	local pieces: { { part: MeshPart, label: string, role: string? } } = {}
	for _, item in ipairs(source:GetDescendants()) do
		if item:IsA("MeshPart") then
			local parent = item.Parent
			local label = if parent and parent ~= source and parent:IsA("Model") then parent.Name else item.Name
			table.insert(pieces, { part = item, label = label, role = PetRigBuilder.roleOf(label) })
		end
	end
	assert(#pieces > 0, `{source.Name}: no MeshPart`)
	local function find(role: string): MeshPart?
		for _, p in ipairs(pieces) do
			if p.role == role then
				return p.part
			end
		end
		return nil
	end

	-- facing: the generator looks along its pivot's -Z; turn when the head is clearly behind or beside the body
	local frame = source:GetPivot().Rotation
	local head, body, tail = find("Head"), find("Body"), find("Tail")
	local from = tail or body
	if head and from then
		local rel = frame:VectorToObjectSpace(head.Position - from.Position)
		if math.abs(rel.X) > math.abs(rel.Z) * 1.5 and math.abs(rel.X) > 0.15 then
			frame = frame * CFrame.Angles(0, if rel.X > 0 then -math.pi / 2 else math.pi / 2, 0)
		elseif rel.Z > 0.15 and rel.Z > math.abs(rel.X) then
			frame = frame * CFrame.Angles(0, math.pi, 0)
		end
	end

	-- bounds in that frame -> Root at the bottom center, scale to the wanted height
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in ipairs(pieces) do
		local a, b = boxIn(frame, p.part)
		lo, hi = lo:Min(a), hi:Max(b)
	end
	local rootFrame = frame * CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local height = PetRigBuilder.HEIGHT * species.Scale
	local s = height / math.max(hi.Y - lo.Y, 0.01)

	local model = Instance.new("Model")
	model.Name = petId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	local used: { [string]: number } = {}
	local placed: { { part: MeshPart, role: string?, label: string } } = {}
	for _, p in ipairs(pieces) do
		local part = p.part:Clone()
		part:ClearAllChildren()
		for name in pairs(part:GetAttributes()) do
			part:SetAttribute(name, nil)
		end
		local rel = rootFrame:ToObjectSpace(p.part.CFrame)
		part.Size = p.part.Size * s
		part.CFrame = CFrame.new(rel.Position * s) * rel.Rotation
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		local role = p.role
		local name = role or ("Extra_" .. string.gsub(p.label, "%s+", "_"))
		used[name] = (used[name] or 0) + 1
		if used[name] > 1 then
			-- a second head (Cerberus) or a second piece with the same role rides on the body
			name ..= tostring(used[name])
			role = nil
		end
		part.Name = name
		if not role and (string.find(string.lower(p.label), "ear") or string.find(string.lower(p.label), "horn")
			or string.find(string.lower(p.label), "halo") or string.find(string.lower(p.label), "crown")) then
			part:SetAttribute("Rides", "Head")
		end
		part.Parent = model
		table.insert(placed, { part = part, role = role, label = p.label })
	end

	-- joints (root space = world space here: Root is at the origin)
	local bodyPart = model:FindFirstChild("Body") :: BasePart?
	local _, size = model:GetBoundingBox()
	local bodyCenter = if bodyPart then bodyPart.Position else Vector3.new(0, size.Y * 0.45, 0)
	for _, p in ipairs(placed) do
		local a, b = boxIn(CFrame.identity, p.part)
		local center = (a + b) / 2
		local joint: Vector3
		local role = p.role
		if role == "Body" then
			joint = Vector3.new(center.X, a.Y + (b.Y - a.Y) * 0.35, center.Z)
		elseif role and (string.sub(role, 1, 3) == "Leg" or string.sub(role, 1, 3) == "Arm") then
			joint = Vector3.new(center.X, b.Y - (b.Y - a.Y) * 0.1, center.Z) -- hip / shoulder: the top
		elseif role == "Head" or role == "Tail" or role == "Tentacles" or (role and (string.sub(role, 1, 4) == "Wing" or string.sub(role, 1, 3) == "Fin" or string.sub(role, 1, 4) == "Claw")) then
			joint = closestInBox(a, b, bodyCenter) -- where it meets the body
		else
			joint = center
		end
		local att = Instance.new("Attachment")
		att.Name = "Joint"
		att.Parent = p.part
		att.WorldPosition = joint
	end

	local gait = spec[2]
	model:SetAttribute("PetV2", true)
	model:SetAttribute("Gait", gait)
	model:SetAttribute("Flying", FLYING_GAITS[gait] == true)
	model:SetAttribute("Body", species.Body)
	model:SetAttribute("Height", math.round(size.Y * 100) / 100)
	model.WorldPivot = CFrame.identity
	return model
end

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

-- Rig `source` as petId, replace ReplicatedStorage.Assets.Pets.<petId>, keep the raw model in
-- ServerStorage.PetSources.<petId>. Returns a short report.
function PetRigBuilder.install(source: Model, petId: string): string
	local rig = PetRigBuilder.build(source, petId)
	local sources = folder(ServerStorage, "PetSources")
	if source.Parent ~= sources then
		local old = sources:FindFirstChild(petId)
		if old and old ~= source then
			old:Destroy()
		end
		source.Name = petId
		source.Parent = sources
	end
	local pets = folder(folder(ReplicatedStorage, "Assets"), "Pets")
	local old = pets:FindFirstChild(petId)
	if old then
		old:Destroy()
	end
	rig.Parent = pets
	local roles = {}
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "Root" then
			table.insert(roles, child.Name)
		end
	end
	table.sort(roles)
	return `{petId} ({Pets.ById[petId].Name}): {rig:GetAttribute("Gait")}, height {rig:GetAttribute("Height")}, {table.concat(roles, " ")}`
end

function PetRigBuilder.rebuild(petId: string): string
	local source = ServerStorage:FindFirstChild("PetSources") and ServerStorage.PetSources:FindFirstChild(petId)
	assert(source and source:IsA("Model"), `no source for {petId}`)
	return PetRigBuilder.install(source, petId)
end

function PetRigBuilder.rebuildAll(): string
	local lines = {}
	local sources = ServerStorage:FindFirstChild("PetSources")
	for _, source in ipairs(if sources then sources:GetChildren() else {}) do
		if source:IsA("Model") and Pets.ById[source.Name] then
			table.insert(lines, PetRigBuilder.install(source, source.Name))
		end
	end
	return table.concat(lines, "\n")
end

function PetRigBuilder.missing(): { string }
	local list = {}
	local pets = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Pets")
	for _, species in ipairs(Pets.List) do
		local model = pets and pets:FindFirstChild(species.Id)
		if not (model and model:GetAttribute("PetV2")) then
			table.insert(list, species.Id)
		end
	end
	return list
end

return PetRigBuilder
