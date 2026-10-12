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
	-- frogs: their splayed legs were split wrong 3 times; one "legs" piece riding on the body (the frog hops whole)
	Frog = { Parts = "head, body, legs", Size = Vector3.new(2, 1.8, 2.2), Pose = "sitting on its folded legs" },
}

-- [petId] = { kind, gait, description, yaw? }  (gait: Walk | Hop | Fly | Swim | Float | Slither, Util/PetMotion;
-- yaw = degrees to turn a model the generator made facing sideways, checked on the lineup)
PetRigBuilder.SPECS = {
	plains_pet1 = { "Quad", "Walk", "baby puppy dog, golden tan fur, white chest and white muzzle, floppy ears, small tail" },
	plains_pet2 = { "Quad", "Walk", "baby fox, bright orange fur, white chest, white muzzle and white fluffy tail tip, black paws" },
	plains_pet3 = { "Biped", "Walk", "baby brown bear cub, chocolate brown fur, light tan muzzle and belly, round ears, tiny tail" },
	plains_pet4 = { "Quad", "Walk", "baby wild boar, brown fur with light stripes, round nose, two little white teeth, curly tail" }, -- "tusks" / "snout" failed moderation
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
	jungle_pet4 = { "Quad", "Walk", "baby crocodile, long low body, green scaly skin, light yellow belly, long nose with little round teeth, ridged tail" },
	jungle_pet5 = { "Bird", "Fly", "baby toucan, black feathers, white chest, huge bright orange and yellow beak" },
	jungle_pet6 = { "Quad", "Walk", "baby chameleon, bright green skin with yellow and teal stripes, curled tail, big round eyes" },
	tundra_pet1 = { "Biped", "Walk", "baby penguin, black back, white belly, small orange beak, orange feet, little flipper arms" },
	tundra_pet2 = { "Quad", "Walk", "baby sabertooth tiger cub, light tan fur with brown spots, two long white fangs, white belly" },
	tundra_pet3 = { "Biped", "Walk", "baby polar bear cub, white fluffy fur, black nose, small round ears" },
	tundra_pet4 = { "Quad", "Walk", "baby woolly mammoth, shaggy brown fur, long trunk, big floppy ears, little white horns" },
	tundra_pet5 = { "Quad", "Hop", "baby snow hare bunny, white fluffy fur, long ears with pink inside, pink nose, puffy tail" },
	tundra_pet6 = { "Biped", "Walk", "baby yeti, white shaggy fur, light blue face and hands, two small horns" },
	swamp_pet1 = { "Bird", "Walk", "baby duckling, fluffy yellow feathers, orange beak and orange feet" },
	swamp_pet2 = { "Frog", "Hop", "baby frog, bright green skin, yellow belly, big round eyes on top of the head, wide smile" },
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
	dead_pet4 = { "Biped", "Walk", "zombie teddy bear, pale green fur, stitches, one button eye" },
	dead_pet5 = { "Bird", "Fly", "baby raven, black feathers with purple shine, small black beak" },
	dead_pet6 = { "Quad", "Walk", "baby ghost deer fawn, pale blue glowing see-through body, glowing green antlers" },
	abyss_pet1 = { "Fish", "Swim", "baby clownfish, bright orange with three white stripes edged in black" },
	abyss_pet2 = { "Fish", "Swim", "baby swordfish, blue back, silver belly, long pointy sword nose" },
	abyss_pet3 = { "Fish", "Swim", "baby pufferfish, round yellow body with small spikes, white belly" },
	abyss_pet4 = { "Fish", "Swim", "baby shark, grey blue skin, white belly, smiling with small teeth" },
	abyss_pet5 = { "Fish", "Swim", "baby orca killer whale, black and white skin, white eye patch", 75 },
	abyss_pet6 = { "Jelly", "Float", "baby kraken octopus, purple skin with pink spots, round head, eight curly tentacles" },
	mechanical_pet1 = { "Quad", "Walk", "robot puppy, silver metal body, glowing cyan eyes, antenna ears, small tail" },
	mechanical_pet2 = { "Spider", "Walk", "clockwork spider, brass bronze body with gears, eight thin metal legs, glowing eyes" },
	mechanical_pet3 = { "Biped", "Walk", "little steam golem robot, copper and iron plates, small chimney on its back, glowing eyes" },
	mechanical_pet4 = { "BipedTail", "Walk", "robot t-rex dinosaur, grey metal plates, red glowing eyes, tiny arms" },
	mechanical_pet5 = { "Drone", "Fly", "little flying drone robot, round silver body, one big glowing cyan eye, two propellers", 50 },
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

-- The generated pieces: the generator nests each MeshPart in a Model named after the piece.
type Piece = { part: MeshPart, label: string, role: string? }
local function pieceList(source: Model): { Piece }
	local pieces: { Piece } = {}
	for _, item in ipairs(source:GetDescendants()) do
		if item:IsA("MeshPart") then
			local parent = item.Parent
			local label = if parent and parent ~= source and parent:IsA("Model") then parent.Name else item.Name
			table.insert(pieces, { part = item, label = label, role = PetRigBuilder.roleOf(label) })
		end
	end
	return pieces
end

local function findRole(pieces: { Piece }, role: string): MeshPart?
	for _, p in ipairs(pieces) do
		if p.role == role then
			return p.part
		end
	end
	return nil
end

-- average center of the pieces with these roles, in `frame` space
local function centerOf(pieces: { Piece }, roles: { string }, frame: CFrame): Vector3?
	local sum, n = Vector3.zero, 0
	for _, p in ipairs(pieces) do
		if p.role and table.find(roles, p.role) then
			sum += frame:PointToObjectSpace(p.part.Position)
			n += 1
		end
	end
	return if n > 0 then sum / n else nil
end

-- The generator faces its pivot's -Z. Turned around only when the head (vs the body) and the front legs (vs the
-- back legs) say the front is +Z: a mislabelled piece (a "tail" that is really the chest) must not flip it.
local function facingFrame(source: Model, pieces: { Piece }): CFrame
	local frame = source:GetPivot().Rotation
	local _, size = source:GetBoundingBox()
	local tol = 0.08 * math.max(size.X, size.Z)
	local votes = 0
	local head, body = centerOf(pieces, { "Head" }, frame), centerOf(pieces, { "Body" }, frame)
	if head and body and math.abs(head.Z - body.Z) > tol then
		votes += if head.Z > body.Z then 1 else -1
	end
	local front = centerOf(pieces, { "LegFL", "LegFR", "LegsF" }, frame)
	local back = centerOf(pieces, { "LegBL", "LegBR", "LegsB" }, frame)
	if front and back and math.abs(front.Z - back.Z) > tol then
		votes += if front.Z > back.Z then 1 else -1
	end
	return if votes > 0 then frame * CFrame.Angles(0, math.pi, 0) else frame
end

-- Upright creatures: the generator often stands a four-legged animal up like a toy (front paws off the ground,
-- like the teddy bear cubs). Then the front legs become arms and the back legs become legs (two-legged rig).
-- Returns true when it remapped the roles.
local function uprightRemap(source: Model, pieces: { Piece }): boolean
	local frame = CFrame.new((source:GetBoundingBox()).Position) * source:GetPivot().Rotation
	local function bottom(part: BasePart): number
		local lo = boxIn(frame, part)
		return lo.Y
	end
	local minY = math.huge
	for _, p in ipairs(pieces) do
		minY = math.min(minY, bottom(p.part))
	end
	local _, size = source:GetBoundingBox()
	local function up(part: BasePart?): boolean
		return part ~= nil and bottom(part) > minY + 0.12 * size.Y
	end
	local function down(part: BasePart?): boolean
		return part ~= nil and bottom(part) < minY + 0.08 * size.Y
	end
	local fl, fr, bl, br = findRole(pieces, "LegFL"), findRole(pieces, "LegFR"), findRole(pieces, "LegBL"), findRole(pieces, "LegBR")
	local map: { [string]: string }? = nil
	if fl and fr and bl and br and up(fl) and up(fr) and down(bl) and down(br) then
		map = { LegFL = "ArmL", LegFR = "ArmR", LegBL = "LegL", LegBR = "LegR" }
	elseif up(findRole(pieces, "LegsF")) and down(findRole(pieces, "LegsB")) then
		-- winged pets with paired legs (dragons, griffin): the front paws ride on the body
		map = { LegsF = "" }
	end
	if not map then
		return false
	end
	for _, p in ipairs(pieces) do
		local to = p.role and map[p.role]
		if to then
			p.role = if to == "" then nil else to
		end
	end
	return true
end

local PAIRS = { { "LegFL", "LegFR" }, { "LegBL", "LegBR" }, { "LegL", "LegR" }, { "ArmL", "ArmR" }, { "WingL", "WingR" }, { "FinL", "FinR" }, { "ClawL", "ClawR" } }
local LEGS = { "LegFL", "LegFR", "LegBL", "LegBR", "LegsF", "LegsB", "LegL", "LegR" }

-- Sanity check of a generated model before it becomes a pet: every asked piece is there, left / right pieces
-- mirror each other, legs hang under the body, front legs are in front, the tail is behind. Returns the
-- problems ({} = good). The generator sometimes mislabels or splits pieces (half a tail named "back right leg"):
-- such a model is generated again rather than animated wrong.
function PetRigBuilder.check(source: Model, petId: string): { string }
	local spec = PetRigBuilder.SPECS[petId]
	assert(spec, `no spec for {petId}`)
	local kind = spec[1]
	local pieces = pieceList(source)
	uprightRemap(source, pieces)
	local issues = {}
	for name in string.gmatch(PetRigBuilder.KINDS[kind].Parts, "[^,]+") do
		local wanted = string.lower((string.gsub(name, "^%s+", "")))
		local ok = false
		for _, p in ipairs(pieces) do
			if string.lower((string.gsub(p.label, "_geom$", ""))) == wanted then
				ok = true
			end
		end
		if not ok then
			table.insert(issues, `missing piece "{wanted}"`)
		end
	end
	-- measured from the model's center, in its facing frame
	local frame = CFrame.new((source:GetBoundingBox()).Position) * facingFrame(source, pieces)
	local _, size = source:GetBoundingBox()
	local w = math.max(size.X, size.Y, size.Z)
	local function c(role: string): Vector3?
		return centerOf(pieces, { role }, frame)
	end
	local function volume(role: string): number
		local part = findRole(pieces, role)
		return if part then part.Size.X * part.Size.Y * part.Size.Z else 0
	end
	for _, pair in ipairs(PAIRS) do
		local a, b = c(pair[1]), c(pair[2])
		if a and b then
			if math.abs(a.X + b.X) > 0.15 * w or math.abs(a.Y - b.Y) > 0.12 * w or math.abs(a.Z - b.Z) > 0.15 * w then
				table.insert(issues, `{pair[1]} / {pair[2]} not mirrored`)
			end
			local va, vb = volume(pair[1]), volume(pair[2])
			if math.max(va, vb) > 2.5 * math.max(math.min(va, vb), 1e-4) then
				table.insert(issues, `{pair[1]} / {pair[2]} sizes differ`)
			end
		end
	end
	local body = c("Body")
	if body then
		for _, role in ipairs(LEGS) do
			local leg = c(role)
			if leg and leg.Y > body.Y then
				table.insert(issues, `{role} above the body center`)
			end
		end
		local tail = c("Tail")
		if tail and kind ~= "Snake" and tail.Z < body.Z - 0.05 * w then
			table.insert(issues, "tail in front of the body")
		end
		local head = c("Head")
		if head and head.Y < body.Y - 0.1 * w and kind ~= "Snake" then
			table.insert(issues, "head below the body")
		end
	end
	local front = centerOf(pieces, { "LegFL", "LegFR", "LegsF" }, frame)
	local back = centerOf(pieces, { "LegBL", "LegBR", "LegsB" }, frame)
	if front and back and front.Z > back.Z - 0.05 * w then
		table.insert(issues, "front legs not in front of the back legs")
	end
	return issues
end

-- The rig of one generated model (not parented). petId gives the scale and the gait.
function PetRigBuilder.build(source: Model, petId: string): Model
	local species = Pets.ById[petId]
	local spec = PetRigBuilder.SPECS[petId]
	assert(species and spec, `unknown pet {petId}`)
	local pieces = pieceList(source)
	assert(#pieces > 0, `{source.Name}: no MeshPart`)
	local upright = uprightRemap(source, pieces)
	local frame = facingFrame(source, pieces)
	if spec[4] then
		frame = frame * CFrame.Angles(0, math.rad(spec[4]), 0)
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
	model:SetAttribute("Upright", upright) -- a four-legged animal the generator stood up (front legs = arms)
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

-- Installs every AI-generated model lying in Workspace whose name starts like a pet's description
-- (generate_mesh names the model after its prompt) and passes check(). One report line per model.
function PetRigBuilder.installGenerated(): string
	local lines = {}
	local done: { [string]: boolean } = {}
	for _, item in ipairs(workspace:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("RBX_AI_GENERATED") then
			local found: string? = nil
			for petId, spec in pairs(PetRigBuilder.SPECS) do
				local text = spec[3]
				local n = math.min(#text, #item.Name, 60)
				if n >= 20 and string.sub(item.Name, 1, n) == string.sub(text, 1, n) then
					found = petId
					break
				end
			end
			if not found then
				table.insert(lines, "no pet for: " .. item.Name)
				continue
			end
			local issues = PetRigBuilder.check(item, found)
			if #issues > 0 then
				-- kept aside (ServerStorage._PetRejects) and generated again; install() forces one anyway
				local rejects = folder(ServerStorage, "_PetRejects")
				item.Name = `{found}_{#rejects:GetChildren() + 1}`
				item.Parent = rejects
				table.insert(lines, `REJECTED {found}: {table.concat(issues, "; ")}`)
			elseif done[found] then
				-- a second good candidate of the same pet: kept as a spare (ServerStorage._PetSpares)
				local spares = folder(ServerStorage, "_PetSpares")
				item.Name = `{found}_{#spares:GetChildren() + 1}`
				item.Parent = spares
				table.insert(lines, `spare {found}`)
			else
				done[found] = true
				table.insert(lines, PetRigBuilder.install(item, found))
			end
		end
	end
	return table.concat(lines, "\n")
end

-- Checks the rejected models again (after a rule change) and installs the first good one of every pet that is
-- still on its placeholder. One report line per installed pet.
function PetRigBuilder.retryRejects(): string
	local lines = {}
	local rejects = ServerStorage:FindFirstChild("_PetRejects")
	local pets = ReplicatedStorage.Assets.Pets
	for _, item in ipairs(if rejects then rejects:GetChildren() else {}) do
		local petId = string.match(item.Name, "^(.-)_%d+$")
		local current = petId and pets:FindFirstChild(petId)
		if petId and PetRigBuilder.SPECS[petId] and item:IsA("Model") and not (current and current:GetAttribute("PetV2")) then
			if #PetRigBuilder.check(item, petId) == 0 then
				table.insert(lines, PetRigBuilder.install(item, petId))
			end
		end
	end
	return table.concat(lines, "\n")
end

-- A row of a zone's pets ("Plains"... or "Premium") on a stand high above the map, for screenshots.
-- Returns the camera position and the point to look at; PetRigBuilder.clearLineup() removes it.
function PetRigBuilder.lineup(zoneId: string): (Vector3, Vector3)
	PetRigBuilder.clearLineup()
	local list = if zoneId == "Premium" then Pets.Premium else Pets.ByZone[zoneId]
	assert(list, `unknown zone {zoneId}`)
	local holder = Instance.new("Model")
	holder.Name = "_PetLineup"
	local base = Vector3.new(0, 400, 0)
	local stand = Instance.new("Part")
	stand.Anchored = true
	stand.Size = Vector3.new(3.2 * #list + 2, 0.4, 5)
	stand.CFrame = CFrame.new(base - Vector3.new(0, 0.2, 0))
	stand.Color = Color3.fromRGB(205, 196, 178)
	stand.Material = Enum.Material.SmoothPlastic
	stand.Parent = holder
	for i, species in ipairs(list) do
		local source = ReplicatedStorage.Assets.Pets:FindFirstChild(species.Id)
		if source then
			local model = source:Clone()
			model:ScaleTo(1.4)
			model:PivotTo(CFrame.new(base + Vector3.new((i - (#list + 1) / 2) * 3.2, 0, 0)) * CFrame.Angles(0, math.rad(200), 0))
			model.Parent = holder
		end
	end
	holder.Parent = workspace
	return base + Vector3.new(0, 2.2, 3.2 * #list * 0.62 + 3), base + Vector3.new(0, 1, 0)
end

function PetRigBuilder.clearLineup()
	local old = workspace:FindFirstChild("_PetLineup")
	if old then
		old:Destroy()
	end
end

-- Zone eggs (Pets V2): one AI mesh per zone (segmentation none), same convention as the procedural eggs of
-- DevTools/PetModels - Root at the bottom, the rarity Ring kept from the old egg, 1.3 studs tall.
PetRigBuilder.EGG_STYLE = "pet egg for a Roblox simulator game, smooth glossy stylized toy look, hand-painted texture"
PetRigBuilder.EGGS = {
	Plains = "green and cream egg with a leaf and flower pattern",
	Desert = "sandy gold egg with blue hieroglyph stripes",
	Jungle = "jungle green egg with leafy vines and yellow spots",
	Tundra = "icy blue and white egg with a snowflake pattern",
	Swamp = "murky green egg with lily pads and mud spots",
	Volcano = "dark rock egg with glowing orange lava cracks",
	Hell = "crimson red egg with black flame patterns",
	Heaven = "white egg with a golden feather pattern",
	Dead = "pale grey egg with green ghost swirls",
	Abyss = "deep blue egg with coral and bubble patterns",
	Mechanical = "silver metal egg with brass gears and rivets",
	Void = "dark purple egg with glowing stars and galaxy swirls",
}

function PetRigBuilder.eggPrompt(zoneId: string): string
	local theme = PetRigBuilder.EGGS[zoneId]
	assert(theme, `no egg for {zoneId}`)
	return `{theme}, {PetRigBuilder.EGG_STYLE}`
end

function PetRigBuilder.installEgg(source: Model, zoneId: string): string
	local eggs = folder(folder(ReplicatedStorage, "Assets"), "Eggs")
	local name = string.lower(zoneId)
	local old = eggs:FindFirstChild(name)
	local mesh = source:FindFirstChildWhichIsA("MeshPart", true)
	assert(mesh, `{source.Name}: no MeshPart`)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root
	local ring = old and old:FindFirstChild("Ring")
	if ring then
		ring:Clone().Parent = model
	end
	local shell = mesh:Clone()
	shell:ClearAllChildren()
	for attr in pairs(shell:GetAttributes()) do
		shell:SetAttribute(attr, nil)
	end
	shell.Name = "Egg"
	local s = 1.3 / math.max(mesh.Size.Y, 0.01)
	shell.Size = mesh.Size * s
	shell.CFrame = CFrame.new(0, 0.06 + shell.Size.Y / 2, 0) * mesh.CFrame.Rotation
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Parent = model
	model:SetAttribute("Height", math.round((0.06 + shell.Size.Y) * 100) / 100)
	model:SetAttribute("PetV2", true)
	if old then
		old:Destroy()
	end
	model.Parent = eggs
	local sources = folder(ServerStorage, "EggSources")
	local oldSource = sources:FindFirstChild(name)
	if oldSource and oldSource ~= source then
		oldSource:Destroy()
	end
	source.Name = name
	source.Parent = sources
	return `egg {name}: {math.round(shell.Size.Y * 100) / 100} studs`
end

-- Installs every generated egg lying in Workspace (matched on the egg theme text).
function PetRigBuilder.installGeneratedEggs(): string
	local lines = {}
	for _, item in ipairs(workspace:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("RBX_AI_GENERATED") then
			for zoneId, theme in pairs(PetRigBuilder.EGGS) do
				local n = math.min(#theme, #item.Name, 60)
				if n >= 20 and string.sub(item.Name, 1, n) == string.sub(theme, 1, n) then
					table.insert(lines, PetRigBuilder.installEgg(item, zoneId))
					break
				end
			end
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
