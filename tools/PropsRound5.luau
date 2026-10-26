--[[
	PropsRound5 (dev tool, Edit mode only) - owner prompt "ROUND 5" Task 2 / Task 3 template edits.
	Source of truth: tools/PropsRound5.luau (= ServerStorage.DevTools.PropsRound5).

	Usage (execute_luau, Edit):
		local P = require(game.ServerStorage.DevTools.PropsRound5:Clone())
		print(P.sarcophagus())        -- B: desert_landmark_sarcophagus = a big golden guardian + 4 carved pillars
		print(P.jungleGuards())       -- C: jungle_palisade_gate, only the 2 guards (+ their torch tops)
		print(P.iceThrone())          -- D: tundra_landmark_ice_throne = the finished small ice throne enlarged + steps
		print(P.ancientTree())        -- 03: plains_landmark_ancient_tree in the swamp / jungle tree recipe
		print(P.stoneBridge())        -- 04: desert_landmark_stone_bridge in the desert gate recipe
		print(P.rockArch())           -- 05: desert_landmark_rock_arch = faceted strata slabs, cracks, sand, scree
		print(P.desertArenaDoor())    -- 06: desert_gate_door (the Desert arena door) in the desert gate recipe
		print(P.desertBossGate())     -- 08: desert_gate_boss_gate in the desert gate recipe + studded door leaves
		print(P.oasisWell())          -- 09: desert_landmark_oasis_well = the improved plains well in sandstone + fountain water
		print(P.spear())              -- 10: desert_prop_spear = leaf blade, binding + tassel, grained shaft, butt cap
		print(P.jungleBossGate())     -- 11: jungle_gate_boss_gate in the jungle stone temple recipe + carved gold doors / face
		print(P.jungleArenaDoor())    -- 12: jungle_gate_door = the jungle stone door recipe on its outer face
		print(P.waterfallCliff())     -- 13: jungle_landmark_waterfall_cliff = faceted strata cliff + fountain-look waterfall + leafy vines
		print(P.goldenIdol())         -- 14: jungle_landmark_golden_idol = carved seated golden idol on cut stone
		print(P.stepPyramid())        -- 16: jungle_landmark_step_pyramid = cut stone tiers, carved doorway, gold finial, moss, vines, bushes
		print(P.ruinPillar())         -- 17: jungle_statue_ruin_pillar_a (x10) = carved drums, band, capital, moss top
		print(P.tundraBossGate())     -- 19: tundra_gate_boss_gate in the ice castle gate recipe + the crown emblem with depth
		print(P.tundraArenaDoor())    -- 20: tundra_gate_door = the ice castle door recipe on both faces
		then Sync.run({ only = { id } }) syncs the copies (map, arena, preview samples).
	Every builder works on a clone of the current template and installs it with P.install(): the old template goes to
	ServerStorage.MapProps._Previous (Sync.undoCapture(id) brings it back), the pivot stays at the origin.
]]
local ServerStorage = game:GetService("ServerStorage")

local P = {}

local function folder(): Folder
	return ServerStorage:FindFirstChild("MapProps") :: Folder
end

-- the new template replaces the old one (kept in _Previous)
function P.install(id: string, model: Model): Model
	local mapProps = folder()
	local old = mapProps:FindFirstChild(id)
	if old then
		local previous = mapProps:FindFirstChild("_Previous") or Instance.new("Folder")
		previous.Name = "_Previous"
		previous.Parent = mapProps
		local stale = previous:FindFirstChild(id)
		if stale then
			stale:Destroy()
		end
		old.Parent = previous
	end
	model.Name = id
	model:SetAttribute("MapPropId", id)
	model.Parent = mapProps
	return model
end

function P.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): Part
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.collide == true
	p.CanTouch = false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Parent = parent
	return p
end
local part = P.part

-- an invisible collision copy keeps a gameplay shape exactly (the visual parts above it do not collide)
local function toCollision(p: BasePart)
	p.Name = "Collision"
	p.Transparency = 1
	p.CastShadow = false
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
end

-- the pivot stays where it is when the PrimaryPart changes
local function setPrimary(model: Model, primary: BasePart)
	local pivot = model:GetPivot()
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot)
end

local rgb = Color3.fromRGB

---------------------------------------------------------------------
-- B) DESERT SARCOPHAGUS (image 07): a bigger golden guardian on today's stone plinth + 4 carved sandstone pillars
---------------------------------------------------------------------
-- a finished template, cleaned for use inside another one (no tags, no attributes, no collision copies)
local function cleanClone(id: string): Model
	local t = folder():FindFirstChild(id) :: Model
	assert(t, "template " .. id .. " missing")
	local c = t:Clone()
	for key in pairs(c:GetAttributes()) do
		c:SetAttribute(key, nil)
	end
	for _, tag in ipairs(c:GetTags()) do
		c:RemoveTag(tag)
	end
	local variants = c:FindFirstChild("_Variants")
	if variants then
		variants:Destroy()
	end
	return c
end
P.cleanClone = cleanClone

-- moves a model so that its real box (Model:GetBoundingBox, right for unions) has its bottom center at "at"
local function standAt(model: Model, at: Vector3)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (at - bottom))
end
P.standAt = standAt

function P.sarcophagus(): string
	local id = "desert_landmark_sarcophagus"
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local guardianTemplate = folder():FindFirstChild("golden_guardian") :: Model
	assert(guardianTemplate, "template golden_guardian missing")
	local m = old:Clone()
	local plinthTop = 6
	-- today's body (box, lid, stripes, effigy, nemes) and posts stay as invisible collision: the gameplay shape is exact
	local plinth = nil
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			if c.Name == "Plinth" then
				plinth = plinth or c
			elseif c.Name ~= "PostGem" then -- (the old eyes too: the guardian has its own glowing eyes, at the same place)
				toCollision(c)
			end
		end
	end
	setPrimary(m, plinth :: BasePart)
	-- the golden guardian, finished (round 2 desert treasures), scaled to the old body (10.1 long -> 33)
	local guardian = guardianTemplate:Clone()
	for _, c in ipairs(guardian:GetChildren()) do
		if c.Name == "Collision" then
			c:Destroy()
		end
	end
	for key in pairs(guardian:GetAttributes()) do
		guardian:SetAttribute(key, nil)
	end
	for _, t in ipairs(guardian:GetTags()) do
		guardian:RemoveTag(t)
	end
	local _, gsize = guardian:GetBoundingBox()
	local scale = 33 / gsize.Z -- (the old lid is 33.2 long)
	guardian:ScaleTo(scale)
	standAt(guardian, (m:GetPivot() * CFrame.new(0, plinthTop, 0)).Position)
	local holder = Instance.new("Model")
	holder.Name = "Guardian"
	for _, c in ipairs(guardian:GetChildren()) do
		if c:IsA("BasePart") then
			c.CanCollide = false
			c.CanTouch = false
			c.Parent = holder
		end
	end
	guardian:Destroy()
	holder.Parent = m
	-- 4 carved sandstone pillars on the old posts (each post: 3 x 14 x 3, center y 10 -> bottom 3, top 17): the finished
	-- desert_column (base, banded lapis / gold shaft, capital; round 2 desert monuments) scaled to the post, its own
	-- collision copies removed (the post stays as the collision); the cyan glowing tip (PostGem) is kept as it is
	local pillars = Instance.new("Model")
	pillars.Name = "Pillars"
	local count = 0
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c.Name == "Collision" and math.abs(c.Size.X - 3) < 0.01 and math.abs(c.Size.Y - 14) < 0.01 then
			local p = c.Position
			local column = cleanClone("desert_column")
			for _, d in ipairs(column:GetChildren()) do
				if d.Name == "Collision" then
					d:Destroy()
				end
			end
			local _, size = column:GetBoundingBox()
			column:ScaleTo(14 / size.Y)
			standAt(column, Vector3.new(p.X, p.Y - 7, p.Z))
			for _, d in ipairs(column:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			count += 1
			column.Name = "Pillar" .. count
			column.Parent = pillars
		end
	end
	pillars.Parent = m
	P.install(id, m)
	local parts = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return `{id}: golden guardian x{string.format("%.3f", scale)} on the plinth, {count} desert columns as pillars, {parts} parts in all (old template in _Previous)`
end

---------------------------------------------------------------------
-- C) JUNGLE PALISADE GATE (image 15): only the 2 little guards (and their torch tops) are remade. The old totem
-- stacks (3 TotemHead cubes + the Wing) stay as invisible collision, so the gameplay shape is exact; their eyes and
-- beaks go. Each guard: a low-mid poly tribal warrior on the same spot (x +-16.2, z -4.6, 0 .. 10.8 tall + feather),
-- facing the path (-Z), the inner arm holding the torch pole. The torch keeps its Ember (FirePoint) as it is; a cup and
-- a layered flame are added around it.
---------------------------------------------------------------------
local TRIBE = {
	skin = rgb(198, 132, 86), skinDark = rgb(166, 104, 66), red = rgb(196, 70, 50), teal = rgb(60, 170, 190),
	tan = rgb(214, 150, 92), gold = rgb(255, 201, 60), dark = rgb(74, 48, 34), bone = rgb(232, 226, 208),
	leather = rgb(112, 70, 40), iron = rgb(92, 98, 110),
}

local function octo(parent: Instance, name: string, w: number, h: number, d: number, cf: CFrame, color: Color3)
	-- an eight-sided block (a box and the same box turned 45 degrees, the turned one a little smaller): low-poly round
	part(parent, name, Vector3.new(w, h, d), cf, color)
	local k = math.min(w, d) * 0.83
	part(parent, name, Vector3.new(k, h, k), cf * CFrame.Angles(0, math.rad(45), 0), color)
end

local function tribalGuard(parent: Instance, base: CFrame, side: number)
	-- base: the feet center on the ground, facing -Z; side = +1 / -1 (the torch is on the inner side)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	-- feet, legs
	for _, lx in ipairs({ -0.75, 0.75 }) do
		part(parent, "Sandal", Vector3.new(1.25, 0.4, 1.7), at(lx, 0.2, -0.15), TRIBE.leather)
		octo(parent, "Leg", 1.05, 3.0, 1.15, at(lx, 1.9, 0), TRIBE.skin)
		part(parent, "LegBand", Vector3.new(1.2, 0.25, 1.3), at(lx, 1.2, 0), TRIBE.teal)
	end
	-- cloth skirt with a hem, front flap, belt and buckle
	octo(parent, "Skirt", 3.2, 1.9, 2.4, at(0, 3.95, 0), TRIBE.red)
	octo(parent, "SkirtHem", 3.35, 0.3, 2.55, at(0, 3.1, 0), TRIBE.gold)
	part(parent, "SkirtFlap", Vector3.new(1.2, 2.2, 0.2), at(0, 3.6, -1.32), TRIBE.tan)
	part(parent, "SkirtFlap", Vector3.new(0.9, 0.25, 0.22), at(0, 3.0, -1.34), TRIBE.teal)
	octo(parent, "Belt", 3.05, 0.5, 2.25, at(0, 5.05, 0), TRIBE.leather)
	part(parent, "Buckle", Vector3.new(0.75, 0.55, 0.2), at(0, 5.05, -1.2), TRIBE.gold)
	-- torso with chest paint
	octo(parent, "Torso", 2.8, 3.3, 1.9, at(0, 6.95, 0), TRIBE.skin)
	part(parent, "ChestPaint", Vector3.new(2.0, 0.28, 0.12), at(0, 7.6, -0.99), TRIBE.teal)
	part(parent, "ChestPaint", Vector3.new(1.4, 0.22, 0.12), at(0, 7.1, -0.99), TRIBE.bone)
	part(parent, "Necklace", Vector3.new(1.6, 0.3, 0.12), at(0, 8.25, -0.99), TRIBE.gold)
	-- shoulder pads (two layers, red trim) on both sides
	for _, sx in ipairs({ -1, 1 }) do
		part(parent, "ShoulderPad", Vector3.new(1.5, 0.55, 1.9), at(sx * 1.75, 8.45, 0) * CFrame.Angles(0, 0, math.rad(-sx * 18)), TRIBE.teal)
		part(parent, "ShoulderPad", Vector3.new(1.35, 0.3, 1.75), at(sx * 1.85, 8.1, 0) * CFrame.Angles(0, 0, math.rad(-sx * 18)), TRIBE.red)
	end
	-- the outer arm hangs down (a gold wrist band); the inner arm holds the torch (torchArm)
	local outerShoulder = at(side * 1.75, 8.1, 0)
	octo(parent, "Arm", 0.8, 3.4, 0.85, outerShoulder * CFrame.new(side * 0.15, -1.75, 0), TRIBE.skin)
	part(parent, "WristBand", Vector3.new(0.95, 0.3, 1.0), outerShoulder * CFrame.new(side * 0.15, -3.0, 0), TRIBE.gold)
	part(parent, "Hand", Vector3.new(0.8, 0.7, 0.85), outerShoulder * CFrame.new(side * 0.15, -3.6, 0), TRIBE.skinDark)
end

-- the inner arm: from the shoulder to the torch pole (world points), and the hand around the pole
local function torchArm(parent: Instance, shoulder: Vector3, hand: Vector3)
	local mid = (shoulder + hand) / 2
	local len = (hand - shoulder).Magnitude
	part(parent, "Arm", Vector3.new(0.8, 0.85, len), CFrame.lookAt(mid, hand), TRIBE.skin)
	part(parent, "WristBand", Vector3.new(0.98, 1.0, 0.3), CFrame.lookAt(hand:Lerp(shoulder, 0.18), hand), TRIBE.gold)
	part(parent, "Hand", Vector3.new(0.95, 0.9, 0.9), CFrame.new(hand), TRIBE.skinDark)
end

local function guardHead(parent: Instance, base: CFrame, side: number)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	part(parent, "Neck", Vector3.new(0.85, 0.5, 0.85), at(0, 8.85, 0), TRIBE.skinDark)
	octo(parent, "Head", 2.1, 1.75, 1.95, at(0, 9.95, 0), TRIBE.skin)
	octo(parent, "HeadTop", 1.6, 0.35, 1.5, at(0, 10.98, 0), TRIBE.dark) -- (hair)
	-- face: eyes, brows, nose, face paint (white and red stripes on the cheeks, a teal line on the chin)
	for _, ex in ipairs({ -0.42, 0.42 }) do
		part(parent, "Eye", Vector3.new(0.32, 0.3, 0.1), at(ex, 10.15, -0.98), TRIBE.dark)
		part(parent, "Brow", Vector3.new(0.45, 0.12, 0.1), at(ex, 10.45, -0.98), TRIBE.dark)
		part(parent, "FacePaint", Vector3.new(0.5, 0.14, 0.08), at(ex * 1.55, 9.85, -0.96), TRIBE.bone)
		part(parent, "FacePaint", Vector3.new(0.5, 0.14, 0.08), at(ex * 1.55, 9.6, -0.96), TRIBE.red)
	end
	part(parent, "Nose", Vector3.new(0.3, 0.45, 0.22), at(0, 9.85, -1.02), TRIBE.skinDark)
	part(parent, "Mouth", Vector3.new(0.6, 0.1, 0.08), at(0, 9.4, -0.98), TRIBE.dark)
	part(parent, "FacePaint", Vector3.new(0.9, 0.12, 0.08), at(0, 9.22, -0.97), TRIBE.teal)
	-- headband with a teal stripe and a feather on the outer side
	octo(parent, "Headband", 2.25, 0.36, 2.1, at(0, 10.55, 0), TRIBE.red)
	part(parent, "HeadbandStripe", Vector3.new(1.4, 0.14, 0.1), at(0, 10.55, -1.07), TRIBE.teal)
	local feather = at(side * 0.75, 11.25, 0.55) * CFrame.Angles(math.rad(-12), 0, math.rad(-side * 16))
	part(parent, "Feather", Vector3.new(0.18, 1.5, 0.55), feather, TRIBE.bone)
	part(parent, "FeatherTip", Vector3.new(0.2, 0.45, 0.6), feather * CFrame.new(0, 0.85, 0), TRIBE.red)
	part(parent, "FeatherQuill", Vector3.new(0.12, 0.4, 0.12), feather * CFrame.new(0, -0.9, 0), TRIBE.teal)
end

-- a better torch top around the kept Ember (1.3 x 0.5 x 1.3 Neon, FirePoint): an iron cup with a gold rim under it and a
-- layered flame above (orange, yellow, pale core), no collision, no shadow
local function torchTop(parent: Instance, ember: BasePart)
	local c = ember.CFrame
	local function glow(size: Vector3, cf: CFrame, color: Color3)
		part(parent, "Flame", size, cf, color, { material = Enum.Material.Neon, shadow = false })
	end
	part(parent, "TorchCup", Vector3.new(1.75, 0.6, 1.75), c * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, math.rad(45), 0), TRIBE.iron)
	part(parent, "TorchCup", Vector3.new(1.75, 0.6, 1.75), c * CFrame.new(0, -0.5, 0), TRIBE.iron)
	part(parent, "TorchCupRim", Vector3.new(1.95, 0.18, 1.95), c * CFrame.new(0, -0.17, 0), TRIBE.gold)
	glow(Vector3.new(1.0, 0.95, 1.0), c * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(255, 120, 30))
	glow(Vector3.new(0.7, 0.85, 0.7), c * CFrame.new(0.05, 1.2, 0), rgb(255, 176, 50))
	glow(Vector3.new(0.45, 0.7, 0.45), c * CFrame.new(-0.05, 1.68, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(255, 222, 110))
	glow(Vector3.new(0.22, 0.45, 0.22), c * CFrame.new(0, 2.06, 0), rgb(255, 246, 200))
end

function P.jungleGuards(): string
	local id = "jungle_palisade_gate"
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local pivot = m:GetPivot()
	local removed, collisions = 0, 0
	local embers = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local p = pivot:PointToObjectSpace(c.Position)
			local guardPart = math.abs(math.abs(p.X) - 16.2) < 1.0 and math.abs(p.Z + 4.4) < 3
			if guardPart and (c.Name == "TotemHead" or c.Name == "Wing") then
				toCollision(c)
				collisions += 1
			elseif guardPart and (c.Name == "Eye" or c.Name == "Beak") then
				c:Destroy()
				removed += 1
			elseif c.Name == "Ember" then
				table.insert(embers, c)
			end
		end
	end
	assert(collisions == 8 and removed == 10, `unexpected guard parts: {collisions} collision, {removed} removed`)
	for _, side in ipairs({ -1, 1 }) do
		local g = Instance.new("Model")
		g.Name = if side < 0 then "GuardL" else "GuardR"
		local base = pivot * CFrame.new(side * 16.2, 0, -4.6)
		tribalGuard(g, base, side)
		guardHead(g, base, side)
		-- the inner arm to this side's torch pole (the Ember sits on the pole top: the hand 2.6 below it)
		local ember = nil
		for _, e in ipairs(embers) do
			if math.sign(pivot:PointToObjectSpace(e.Position).X) == side then
				ember = e
			end
		end
		if ember then
			local shoulder = (base * CFrame.new(-side * 1.75, 8.1, 0)).Position
			local hand = ember.Position - Vector3.new(0, 2.6, 0)
			torchArm(g, shoulder, hand)
			torchTop(g, ember)
		end
		g.Parent = m
	end
	P.install(id, m)
	local parts = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return `{id}: 2 tribal guards + 2 torch tops, {collisions} old guard parts kept as collision, {removed} removed, {parts} parts in all`
end

---------------------------------------------------------------------
-- D) TUNDRA ICE THRONE (image 18): the finished tundra_ice_throne (tundra batch) enlarged to the landmark (x2.7, the
-- old top at 50) on the same spot and facing (-Z), ice steps over the old footstool and snow drifts. The old landmark
-- parts stay as invisible collision (footprint and collisions exact); its gem glow is the big throne's own.
---------------------------------------------------------------------
local FROST = { ice = rgb(176, 220, 240), iceDeep = rgb(120, 186, 222), snow = rgb(244, 248, 255) }

local function placed(id: string, scale: number, at: Vector3, yaw: number?): Model
	local c = cleanClone(id)
	for _, d in ipairs(c:GetChildren()) do
		if d.Name == "Collision" then
			d:Destroy()
		end
	end
	if math.abs(scale - 1) > 1e-4 then
		c:ScaleTo(scale)
	end
	if yaw then
		c:PivotTo(c:GetPivot() * CFrame.Angles(0, math.rad(yaw), 0))
	end
	standAt(c, at)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	return c
end

function P.iceThrone(): string
	local id = "tundra_landmark_ice_throne"
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local pivot = m:GetPivot()
	local back = nil
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			if c.Name == "Gem" then
				c:Destroy()
			else
				if c.Name == "Back" then
					back = c
				end
				toCollision(c)
			end
		end
	end
	setPrimary(m, back :: BasePart)
	local decor = Instance.new("Model")
	decor.Name = "Throne"
	-- the big throne (0 .. 50 tall), its box centred at x 0, z 1 (between the old footstool and the old back)
	local throne = placed("tundra_ice_throne", 1, Vector3.zero)
	local _, size = throne:GetBoundingBox()
	local scale = 50 / size.Y
	throne:ScaleTo(scale)
	standAt(throne, (pivot * CFrame.new(0, 0, 1)).Position)
	throne.Name = "IceThrone"
	throne.Parent = decor
	-- (no frost pillars / braziers: in the boss arena the frozen knight statues, the blue torches and the ice spikes
	-- already stand exactly at the throne's sides; the big throne carries its own crystals) - a snow drift by the steps
	-- on each side, everything inside the old footprint (front at z -14)
	for _, side in ipairs({ -1, 1 }) do
		part(decor, "SnowDrift", Vector3.new(7, 1.4, 4.5), pivot * CFrame.new(side * 12.5, 0.6, -11.5) * CFrame.Angles(0, math.rad(side * 14), 0), FROST.snow)
	end
	-- ice steps over the old footstool (12 x 2 x 5 at z -11.5): two treads with a snow lip
	part(decor, "Step", Vector3.new(16, 1, 6), pivot * CFrame.new(0, 0.5, -11), FROST.iceDeep)
	part(decor, "Step", Vector3.new(13, 1, 4.5), pivot * CFrame.new(0, 1.5, -10.25), FROST.ice)
	part(decor, "StepSnow", Vector3.new(16.4, 0.25, 0.7), pivot * CFrame.new(0, 1.1, -13.7), FROST.snow)
	part(decor, "StepSnow", Vector3.new(13.4, 0.25, 0.6), pivot * CFrame.new(0, 2.1, -12.3), FROST.snow)
	decor.Parent = m
	P.install(id, m)
	local parts = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return `{id}: tundra_ice_throne x{string.format("%.2f", scale)}, steps, snow drifts; {parts} parts in all`
end

---------------------------------------------------------------------
-- Task 3 shared: the recipe libraries of the earlier batches (loaded on first use: they are big)
---------------------------------------------------------------------
local LIB = nil
local function lib(): any
	if not LIB then
		local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any
		LIB = { ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()), H = SH.H, M = SH.M, TB = SH.TB, SH = SH }
	end
	return LIB
end
P.lib = lib

-- every non-empty list of U merged into one union per name (never one giant union); root = the PrimaryPart name
local function mergeAll(m: Model, U: any, opts: any?)
	local H = lib().H
	local names = {}
	for name, list in pairs(U) do
		if #list > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		H.merge(m, name, U[name], (opts and opts[name]) or {})
		task.wait()
	end
	H.setBevelSelf(false)
end
P.mergeAll = mergeAll

---------------------------------------------------------------------
-- 03 PLAINS ANCIENT TREE (plains_landmark_ancient_tree): the swamp / jungle tree recipe (PropsSwampTrees: twisted
-- 8-sided bark logs with winding grooves, faceted leaf clusters with a lit-top / dark-underside gradient, moss
-- cushions, leafy vines, ferns) in plains greens: a massive trunk (today's trunk collider, 24 across, 62 tall) with
-- bark ridges, 8 flared roots over today's root wedges (kept as invisible collision), branches into each of today's
-- 6 canopy discs, each disc a layer of soft leaf clusters (its size, place and colour), hanging vines and moss, a
-- root base with stones and grass. The NoClimb walls / roof and the trunk collider stay as they are.
---------------------------------------------------------------------
local PLAINS = { bark = rgb(107, 65, 40), barkLight = rgb(128, 78, 48), stone = rgb(150, 156, 168), grass = rgb(76, 168, 66) }

function P.ancientTree(): string
	local id = "plains_landmark_ancient_tree"
	local L = lib()
	local ST, H = L.ST, L.H
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local trunkCollider = m:FindFirstChild("TrunkCollision") :: BasePart
	assert(trunkCollider, "TrunkCollision missing")
	setPrimary(m, trunkCollider)
	local pivot = m:GetPivot()
	local discs, roots = {}, {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Canopy" then
				table.insert(discs, { c = pivot:PointToObjectSpace(d.ExtentsCFrame.Position), s = d.ExtentsSize, color = d.Color })
				d:Destroy()
			elseif d.Name == "Root" then
				table.insert(roots, { c = pivot:PointToObjectSpace(d.ExtentsCFrame.Position), s = d.ExtentsSize, color = d.Color })
				toCollision(d)
			elseif d.Name == "Trunk" or d.Name == "RootFlare" or d.Name == "Moss" then
				d:Destroy()
			end
		end
	end
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("Model") and #c:GetChildren() == 0 then
			c:Destroy() -- (the emptied Canopy group)
		end
	end
	H.setBevelSelf(true)
	local rng = Random.new(5503)
	local UP = Vector3.yAxis
	local function W(v: Vector3): Vector3
		return pivot:PointToWorldSpace(v)
	end
	local U: any = { Trunk = {}, Bark = {}, Roots = {}, Branches = {}, Twigs = {}, Moss = {}, Vines = {}, VineLeaves = {}, Stones = {}, Grass = {} }
	-- the trunk (r 12.6 -> 9.4 over 0 .. 58) and its crown stem into the top disc
	ST.twistedLog(U.Trunk, U.Bark, rng, W(Vector3.new(0, -0.4, 0)), W(Vector3.new(0, 58, 0)), 12.6, 9.4, PLAINS.bark, 0, math.rad(9))
	-- branches into the canopy discs (the highest disc gets the crown stem)
	table.sort(discs, function(a: any, b: any): boolean
		return a.c.Y > b.c.Y
	end)
	for i, d in ipairs(discs) do
		local target = d.c - Vector3.new(0, d.s.Y * 0.22, 0)
		local flat = Vector3.new(target.X, 0, target.Z)
		local out = if flat.Magnitude > 1 then flat.Unit else Vector3.xAxis
		local from = Vector3.new(0, if i == 1 then 54 else 44 + (i % 3) * 4, 0) + out * 6
		if i == 1 then
			ST.twistedLog(U.Trunk, U.Bark, rng, W(Vector3.new(0, 56, 0)), W(target), 9.4, 5.2, PLAINS.bark, 0.4, math.rad(9))
		else
			ST.gnarledBranch(U.Branches, U.Twigs, rng, W(from), W(target), 4.2, PLAINS.barkLight)
		end
	end
	-- flared roots over today's root wedges: from the trunk foot out to the wedge's outer end, tapering into the ground
	for _, r in ipairs(roots) do
		local flat = Vector3.new(r.c.X, 0, r.c.Z)
		local out = if flat.Magnitude > 0.5 then flat.Unit else Vector3.xAxis
		local reach = flat.Magnitude + math.max(r.s.X, r.s.Z) * 0.5
		local top = out * 9.5 + UP * 10
		local knee = out * (reach * 0.62) + UP * 3.2
		local foot = out * reach + UP * 0.2
		ST.twistedLog(U.Roots, nil, rng, W(top), W(knee), 4.6, 3.0, r.color, rng:NextNumber(0, 1), math.rad(12))
		ST.twistedLog(U.Roots, nil, rng, W(knee), W(foot), 3.0, 1.2, r.color, rng:NextNumber(0, 1), math.rad(12))
		ST.mossCushion(U.Moss, rng, H.frameY(W(knee + UP * 2.8), UP), 3.2)
		-- stones and grass where the root meets the ground
		local side = UP:Cross(out).Unit
		for k = 1, 2 do
			local at = foot + side * (k == 1 and 3.2 or -2.6) + out * rng:NextNumber(-2, 1.5)
			local s = rng:NextNumber(0.9, 1.6)
			ST.blob(U.Stones, rng, CFrame.new(W(at + UP * s * 0.35)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s * 1.2, s * 0.7, s, function(n: Vector3): Color3
				return H.scaled(PLAINS.stone, 0.78 + 0.3 * (n.Y + 1) / 2)
			end, s * 0.3)
		end
		ST.fern(U.Grass, rng, W(foot - out * 2.5 + side * 1.5 + UP * 0.1), 5, 2.6)
	end
	-- moss on the trunk
	for k = 1, 4 do
		local ang = k * 1.7
		local out = Vector3.new(math.cos(ang), 0.3, math.sin(ang)).Unit
		ST.mossCushion(U.Moss, rng, H.frameY(W(Vector3.new(0, 12 + k * 9, 0) + out * 11.8), out), 7)
	end
	-- the canopy: each disc a layer of many soft faceted clusters (a dark centre fill, an inner raised ring, an outer
	-- drooping ring and light top tufts), each cluster lit on top and dark underneath, tones varied cluster by cluster
	for i, d in ipairs(discs) do
		local list = {}
		U["Leaves" .. i] = list
		local Wd, Hh, Dd = d.s.X, d.s.Y, d.s.Z
		local base = H.scaled(d.color, 0.95)
		local c = d.c
		local function cluster(at: Vector3, out: Vector3?, a: number, b: number, cc: number, col: Color3, tilt: number?)
			local f = if out then CFrame.lookAt(W(at), W(at + out)) * CFrame.Angles(math.rad(tilt or -12), 0, 0)
				else CFrame.new(W(at)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			ST.blob(list, rng, f, a, b, cc, ST.leafTone(col))
		end
		cluster(c, nil, Wd * 0.25, Hh * 0.3, Dd * 0.25, H.scaled(base, 0.86))
		local a0 = rng:NextNumber(0, 6.28)
		local inner = 6
		for k = 1, inner do
			local ang = a0 + k * 2 * math.pi / inner + rng:NextNumber(-0.2, 0.2)
			local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = c + Vector3.new(out.X * Wd * 0.17, Hh * 0.14 + rng:NextNumber(-0.05, 0.05) * Hh, out.Z * Dd * 0.17)
			cluster(at, out, Wd * 0.13, Hh * 0.2, math.max(Wd, Dd) * 0.13, H.scaled(base, rng:NextNumber(0.98, 1.12)), -6)
		end
		local outer = math.clamp(math.round(Wd / 7), 8, 16)
		for k = 1, outer do
			local ang = a0 + (k + 0.5) * 2 * math.pi / outer + rng:NextNumber(-0.12, 0.12)
			local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = c + Vector3.new(out.X * Wd * 0.37, -Hh * 0.08 + rng:NextNumber(-0.08, 0.08) * Hh, out.Z * Dd * 0.37)
			cluster(at, out, Wd * 0.15, Hh * 0.2, math.max(Wd, Dd) * 0.15, H.scaled(base, rng:NextNumber(0.86, 1.06)), -16)
		end
		for k = 1, 3 do
			local ang = a0 + k * 2.1
			local at = c + Vector3.new(math.cos(ang) * Wd * 0.08, Hh * 0.32, math.sin(ang) * Dd * 0.08)
			cluster(at, nil, Wd * 0.1, Hh * 0.15, Dd * 0.1, H.scaled(base, 1.16))
		end
		-- hanging vines under the outer rim of the lower discs
		if c.Y < 90 then
			for k = 1, 2 do
				local ang = a0 + k * 2.4
				local top = c + Vector3.new(math.cos(ang) * Wd * 0.32, -Hh * 0.3, math.sin(ang) * Dd * 0.32)
				ST.leafyVine(U.Vines, U.VineLeaves, rng, W(top), 9 + rng:NextNumber(0, 7), 0.45, rgb(70, 120, 46))
			end
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U)
	P.install(id, m)
	local parts, unions = 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("UnionOperation") then
				unions += 1
			end
		end
	end
	local _, size = m:GetBoundingBox()
	return `{id}: {#discs} canopy layers, {#roots} roots, {unions} unions, {parts} parts, size {string.format("%.0f x %.0f x %.0f", size.X, size.Y, size.Z)}`
end

-- a list of parts built around z 0 (the coursed-wall helpers) moved by `by` (a CFrame applied in front)
local function moved(list: { BasePart }, from: number, by: CFrame)
	for k = from + 1, #list do
		list[k].CFrame = by * list[k].CFrame
	end
end

---------------------------------------------------------------------
-- 04 DESERT STONE BRIDGE (desert_landmark_stone_bridge, the large sandstone gateway with the bridge top): the desert
-- gate recipe (Egyptian arch / pylon gate: cut sandstone courses with joints, red and gold bands, lapis inlay, gold)
-- over today's shape: coursed piers on a slab footing with a red band carrying gold diamonds, stepped corbels,
-- chamfered voussoirs under the deck, a coursed deck fascia with today's red band (gold diamonds), a cornice, coursed
-- parapets with a crenellated top, obelisk-like posts with gold caps, coursed end towers with merlons and a gold band,
-- a carved glyph panel on each pier face. Every part of today stays as invisible collision (passage and collisions
-- exact); the arch haunches keep their own shape (visible).
---------------------------------------------------------------------
local SAND = { base = rgb(226, 190, 132), light = rgb(218, 183, 127), dark = rgb(184, 146, 98), red = rgb(204, 96, 62), gold = rgb(255, 201, 60), lapis = rgb(44, 92, 200), carve = rgb(150, 116, 72) }

function P.stoneBridge(): string
	local id = "desert_landmark_stone_bridge"
	local L = lib()
	local H = L.H
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local deck = m:FindFirstChild("Deck") :: BasePart
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(rows, { name = c.Name, cf = c.CFrame, size = c.Size, color = c.Color })
			if c.Name ~= "ArchHaunch" then
				toCollision(c)
			end
		end
	end
	setPrimary(m, deck)
	H.setBevelSelf(true)
	local rng = Random.new(4404)
	local U: any = { Stone = {}, StoneLight = {}, StoneDark = {}, Red = {}, Gold = {}, Inlay = {}, Carving = {} }
	local HT = 60
	local function rowsOf(name: string): { any }
		local t = {}
		for _, r in ipairs(rows) do
			if r.name == name then
				table.insert(t, r)
			end
		end
		return t
	end
	-- gold diamonds along a band face (x0 .. x1 at height y, on the plane z = zf, facing out)
	local function diamonds(x0: number, x1: number, y: number, zf: number, s: number, step: number)
		local n = math.floor((x1 - x0) / step)
		local start = (x0 + x1) / 2 - (n - 1) * step / 2
		for k = 0, n - 1 do
			local x = start + k * step
			table.insert(U.Gold, H.piece("Part", Vector3.new(s, s, 0.2), CFrame.new(x, y, zf) * CFrame.Angles(0, 0, math.rad(45)), SAND.gold))
		end
	end
	-- piers: footing slabs, a coursed lower pier, the red band with gold diamonds, a coursed upper pier, stepped corbels
	for _, r in ipairs(rowsOf("PierBase")) do
		local x = r.cf.X
		local n0 = #U.StoneDark
		H.slabs(U.StoneDark, rng, x - r.size.X / 2, x + r.size.X / 2, r.cf.Y - r.size.Y / 2, r.size.Y, r.size.Z, 5, SAND.dark, HT)
		moved(U.StoneDark, n0, CFrame.identity)
	end
	for _, r in ipairs(rowsOf("Pier")) do
		local x, y0 = r.cf.X, r.cf.Y - r.size.Y / 2
		local list = if r.color == SAND.base then U.Stone else U.StoneLight
		local below = nil
		local courses = math.max(2, math.round(r.size.Y / 3))
		local h = r.size.Y / courses
		for k = 0, courses - 1 do
			below = H.course(list, rng, { x0 = x - r.size.X / 2, x1 = x + r.size.X / 2, y = y0 + k * h, h = h, depth = r.size.Z + 0.1, color = r.color, H = HT, below = below, half = k % 2 == 1 })
		end
		-- a carved glyph panel on both faces of the upper pier
		if r.size.Y > 15 then
			for _, zs in ipairs({ -1, 1 }) do
				local zf = zs * (r.size.Z / 2 + 0.12)
				local yc = y0 + r.size.Y * 0.55
				table.insert(U.Carving, H.piece("Part", Vector3.new(14, 9, 0.25), CFrame.new(x, yc, zf), SAND.carve))
				table.insert(U.Gold, H.piece("Part", Vector3.new(14.6, 0.35, 0.3), CFrame.new(x, yc + 4.65, zf), SAND.gold))
				table.insert(U.Gold, H.piece("Part", Vector3.new(14.6, 0.35, 0.3), CFrame.new(x, yc - 4.65, zf), SAND.gold))
				for g = -2, 2 do
					local gx = x + g * 2.6
					table.insert(U.Inlay, H.piece("Part", Vector3.new(0.7, 4.5 - (g % 2) * 1.6, 0.3), CFrame.new(gx, yc + 0.6, zf + zs * 0.05), SAND.lapis))
					table.insert(U.Gold, H.piece("Part", Vector3.new(1.1, 1.1, 0.3), CFrame.new(gx, yc - 2.8, zf + zs * 0.05) * CFrame.Angles(0, 0, math.rad(45)), SAND.gold))
				end
			end
		end
	end
	for _, r in ipairs(rowsOf("PierBand")) do
		local x, y = r.cf.X, r.cf.Y
		table.insert(U.Red, H.chamfered(r.size + Vector3.new(0.2, 0, 0.2), r.cf, SAND.red, { "topFrontBack", "topSides" }, 0.2))
		for _, zs in ipairs({ -1, 1 }) do
			diamonds(x - r.size.X / 2 + 1, x + r.size.X / 2 - 1, y, zs * (r.size.Z / 2 + 0.2), 1.2, 3)
		end
	end
	for _, r in ipairs(rowsOf("Corbel")) do
		local x, y0 = r.cf.X, r.cf.Y - r.size.Y / 2
		local n0 = #U.StoneDark
		H.slabs(U.StoneDark, rng, x - r.size.X / 2 + 1.5, x + r.size.X / 2 - 1.5, y0, r.size.Y / 2, r.size.Z, 6, SAND.dark, HT)
		H.slabs(U.StoneDark, rng, x - r.size.X / 2, x + r.size.X / 2, y0 + r.size.Y / 2, r.size.Y / 2, r.size.Z + 0.6, 7, SAND.dark, HT)
	end
	-- voussoirs: chamfered blocks with a lapis key in the middle one
	for _, r in ipairs(rowsOf("Voussoir")) do
		table.insert(U.StoneDark, H.chamfered(r.size, r.cf, SAND.dark, { "vertical", "topFrontBack" }, 0.25))
		if math.abs(r.cf.X) < 0.5 then
			table.insert(U.Inlay, H.piece("Part", Vector3.new(2.2, 0.3, r.size.Z + 0.1), r.cf * CFrame.new(0, -r.size.Y / 2 - 0.1, 0), SAND.lapis))
		end
	end
	-- deck: a coursed fascia below and above today's red band (kept, with gold diamonds), a cornice on top
	local deckRow = rowsOf("Deck")[1]
	local band = rowsOf("DeckBand")[1]
	do
		local x0, x1 = -deckRow.size.X / 2, deckRow.size.X / 2
		local y0 = deckRow.cf.Y - deckRow.size.Y / 2
		local bandY0 = band.cf.Y - band.size.Y / 2
		local bandY1 = band.cf.Y + band.size.Y / 2
		local below = H.course(U.Stone, rng, { x0 = x0, x1 = x1, y = y0, h = bandY0 - y0, depth = deckRow.size.Z + 0.1, color = SAND.base, H = HT })
		H.course(U.Stone, rng, { x0 = x0, x1 = x1, y = bandY1, h = (y0 + deckRow.size.Y) - bandY1, depth = deckRow.size.Z + 0.1, color = SAND.base, H = HT, below = below, half = true })
		table.insert(U.Red, H.chamfered(band.size + Vector3.new(0, 0, 0.2), band.cf, SAND.red, { "topFrontBack" }, 0.15))
		for _, zs in ipairs({ -1, 1 }) do
			diamonds(x0 + 2, x1 - 2, band.cf.Y, zs * (band.size.Z / 2 + 0.15), 0.6, 2.4)
		end
		local top = y0 + deckRow.size.Y
		table.insert(U.StoneLight, H.chamfered(Vector3.new(deckRow.size.X + 0.8, 0.7, deckRow.size.Z + 1.4), CFrame.new(0, top + 0.35, 0), SAND.light, { "topFrontBack", "topSides" }, 0.25))
		table.insert(U.Gold, H.piece("Part", Vector3.new(deckRow.size.X + 0.9, 0.18, deckRow.size.Z + 1.5), CFrame.new(0, top + 0.05, 0), SAND.gold))
	end
	-- parapets: two courses and a crenellated top (merlons every 5 studs), on the deck edges
	for _, r in ipairs(rowsOf("Parapet")) do
		local z = r.cf.Z
		local y0 = r.cf.Y - r.size.Y / 2
		local n0 = #U.Stone
		local below = H.course(U.Stone, rng, { x0 = -r.size.X / 2, x1 = r.size.X / 2, y = y0, h = r.size.Y / 2, depth = r.size.Z + 0.1, color = SAND.base, H = HT })
		H.course(U.Stone, rng, { x0 = -r.size.X / 2, x1 = r.size.X / 2, y = y0 + r.size.Y / 2, h = r.size.Y / 2, depth = r.size.Z + 0.1, color = SAND.base, H = HT, below = below, half = true })
		moved(U.Stone, n0, CFrame.new(0, 0, z))
		local top = y0 + r.size.Y
		table.insert(U.StoneLight, H.chamfered(Vector3.new(r.size.X + 0.3, 0.35, r.size.Z + 0.4), CFrame.new(0, top + 0.17, z), SAND.light, { "topFrontBack", "topSides" }, 0.12))
		local n = math.floor(r.size.X / 5)
		for k = 0, n - 1 do
			local x = -r.size.X / 2 + 2.5 + k * 5
			if math.abs(math.abs(x) - 30) > 2.5 then -- (not on the posts)
				table.insert(U.StoneLight, H.chamfered(Vector3.new(2.4, 1.5, r.size.Z + 0.2), CFrame.new(x, top + 0.35 + 0.75, z), SAND.light, { "topFrontBack", "topSides", "vertical" }, 0.15))
			end
		end
	end
	-- posts: chamfered shafts with a lapis band and a gold pyramid cap
	for _, r in ipairs(rowsOf("Post")) do
		local y0 = r.cf.Y - r.size.Y / 2
		table.insert(U.Stone, H.chamfered(Vector3.new(r.size.X, r.size.Y - 1.2, r.size.Z), r.cf * CFrame.new(0, -0.6, 0), SAND.base, { "vertical" }, 0.3))
		table.insert(U.Inlay, H.piece("Part", Vector3.new(r.size.X + 0.12, 0.45, r.size.Z + 0.12), CFrame.new(r.cf.X, y0 + r.size.Y * 0.68, r.cf.Z), SAND.lapis))
		table.insert(U.Gold, H.piece("Part", Vector3.new(r.size.X + 0.2, 0.3, r.size.Z + 0.2), CFrame.new(r.cf.X, y0 + r.size.Y - 1.05, r.cf.Z), SAND.gold))
		local apex = Vector3.new(r.cf.X, y0 + r.size.Y + 0.4, r.cf.Z)
		local hw = r.size.X / 2 + 0.05
		local base = y0 + r.size.Y - 0.9
		for q = 0, 3 do
			local a1 = math.rad(45 + q * 90)
			local a2 = math.rad(135 + q * 90)
			local p1 = Vector3.new(r.cf.X + math.cos(a1) * hw * 1.414, base, r.cf.Z + math.sin(a1) * hw * 1.414)
			local p2 = Vector3.new(r.cf.X + math.cos(a2) * hw * 1.414, base, r.cf.Z + math.sin(a2) * hw * 1.414)
			H.triangleParts(U.Gold, p1, p2, apex, 0.1, CFrame.identity, SAND.gold)
		end
	end
	-- end towers: coursed along their length (Z), a gold band, today's cap dressed as a slab with merlons
	for _, r in ipairs(rowsOf("Tower")) do
		local x = r.cf.X
		local y0 = r.cf.Y - r.size.Y / 2
		local n0 = #U.Stone
		local below = nil
		for k = 0, 2 do
			below = H.course(U.Stone, rng, { x0 = -r.size.Z / 2, x1 = r.size.Z / 2, y = y0 + k * (r.size.Y - 1.6) / 3, h = (r.size.Y - 1.6) / 3, depth = r.size.X + 0.1, color = SAND.base, H = HT, below = below, half = k % 2 == 1 })
		end
		moved(U.Stone, n0, CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
		table.insert(U.Gold, H.piece("Part", Vector3.new(r.size.X + 0.25, 0.4, r.size.Z + 0.25), CFrame.new(x, y0 + r.size.Y * 0.55, 0), SAND.gold))
	end
	for _, r in ipairs(rowsOf("TowerCap")) do
		local x = r.cf.X
		table.insert(U.StoneDark, H.chamfered(r.size, r.cf, SAND.dark, { "topFrontBack", "topSides" }, 0.25))
		local top = r.cf.Y + r.size.Y / 2
		for k = -3, 3 do
			table.insert(U.StoneLight, H.chamfered(Vector3.new(r.size.X - 1, 1.6, 2.6), CFrame.new(x, top + 0.8, k * 4.8), SAND.light, { "topFrontBack", "topSides", "vertical" }, 0.15))
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U)
	P.install(id, m)
	local parts, unions = 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("UnionOperation") then
				unions += 1
			end
		end
	end
	return `{id}: dressed in the desert gate recipe, {unions} unions, {parts} parts`
end

-- a union clone fitted into a box (ExtentsCFrame / ExtentsSize of the part it replaces)
local function fitInto(src: BasePart, parent: Instance, box: CFrame, size: Vector3, name: string): BasePart
	local u = src:Clone()
	u.Parent = parent
	local s = u.ExtentsSize
	u.Size = Vector3.new(u.Size.X * size.X / s.X, u.Size.Y * size.Y / s.Y, u.Size.Z * size.Z / s.Z)
	local offset = u.ExtentsCFrame:ToObjectSpace(u.CFrame)
	u.CFrame = box * offset
	u.Name = name
	u.CanCollide = false
	u.CanTouch = false
	u.CanQuery = false
	return u
end
P.fitInto = fitInto

---------------------------------------------------------------------
-- 05 DESERT RED ROCK STACK (image 05 = desert_landmark_rock_arch, picked by look and place: the stacked red slabs
-- by the Desert / Jungle edge of the preview; the 3 hoodoos are already the improved faceted stacks): the desert red
-- rock recipe (mesa_strata: layered strata, facets, a lit top and a dark underside, cracks, scree / sand): every slab
-- of today becomes a faceted strata slab (a convex solid: its box with jittered bevels on all edges, tone by face),
-- every third slab a little proud or set back, dark cracks on a few faces, sand piles and scree at the feet. Today's
-- slabs stay as invisible collision (collisions exact); the nested sand rocks stay as they are.
---------------------------------------------------------------------
local function strataSlab(list: { BasePart }, rng: Random, cf: CFrame, size: Vector3, color: Color3)
	local TB, H = lib().TB, lib().H
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local planes = {}
	local function plane(n: Vector3, d: number)
		local j = Vector3.new(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.06, 0.06))
		table.insert(planes, { n = (n + j).Unit, d = d })
	end
	plane(Vector3.xAxis, hx)
	plane(-Vector3.xAxis, hx)
	plane(Vector3.zAxis, hz)
	plane(-Vector3.zAxis, hz)
	table.insert(planes, { n = Vector3.yAxis, d = hy })
	table.insert(planes, { n = -Vector3.yAxis, d = hy })
	-- vertical edge bevels (each corner cut back 25-45 % of the shorter half side) and top / bottom edge bevels
	-- (a weathered, rounded slab); a bevel plane through the two points c back from the corner along both faces
	local short = math.min(hx, hz)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local c = short * rng:NextNumber(0.25, 0.45)
			plane(Vector3.new(sx, 0, sz).Unit, (hx + hz - c) / math.sqrt(2))
		end
	end
	for _, sy in ipairs({ -1, 1 }) do
		for _, axis in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
			local half = if axis.X ~= 0 then hx else hz
			local c = math.min(hy * 0.6, 1.4) * rng:NextNumber(0.6, 1)
			plane((axis + Vector3.yAxis * sy).Unit, (half + hy - c) / math.sqrt(2))
		end
	end
	local function toneOf(n: Vector3): Color3
		if n.Y > 0.5 then
			return H.scaled(color, 1.12)
		elseif n.Y < -0.5 then
			return H.scaled(color, 0.72)
		end
		return H.scaled(color, 0.94 + 0.08 * math.abs(n.X))
	end
	local e = size * 0.75
	TB.solidOf(list, cf, -e, e, planes, toneOf)
end
P.strataSlab = strataSlab

function P.rockArch(): string
	local id = "desert_landmark_rock_arch"
	local H = lib().H
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(5505)
	local U: any = { Strata = {}, StrataDark = {}, Cracks = {}, Sand = {}, Scree = {} }
	local slabs = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c.Name == "Strata" then
			table.insert(slabs, { cf = c.CFrame, size = c.Size, color = c.Color })
			toCollision(c)
		end
	end
	H.setBevelSelf(true)
	table.sort(slabs, function(a: any, b: any): boolean
		return a.cf.Y < b.cf.Y
	end)
	for i, s in ipairs(slabs) do
		-- every third slab a little proud, the next one set back: the layered look of the mesa
		local k = (i % 3 == 0 and 1.04) or (i % 3 == 1 and 0.97) or 1
		local size = Vector3.new(s.size.X * k, s.size.Y, s.size.Z * k)
		strataSlab(if i % 2 == 0 then U.Strata else U.StrataDark, rng, s.cf, size, s.color)
		-- a dark crack down the front or back face of every other slab
		if i % 2 == 1 and s.size.Y > 4 then
			local zs = if i % 4 == 1 then -1 else 1
			local x = rng:NextNumber(-0.3, 0.3) * s.size.X
			local p0 = s.cf * Vector3.new(x, s.size.Y * 0.45, zs * (s.size.Z * k / 2 + 0.02))
			local p1 = s.cf * Vector3.new(x + rng:NextNumber(-1.5, 1.5), -s.size.Y * 0.3, zs * (s.size.Z * k / 2 + 0.02))
			table.insert(U.Cracks, H.bar(p0, p1, 0.35, H.scaled(s.color, 0.45)))
		end
	end
	-- sand piles and scree around the two feet (the legs stand at x -31.5 / +31.5)
	local sand = rgb(244, 208, 124)
	for _, x in ipairs({ -31.5, 31.5 }) do
		for k = 1, 4 do
			local ang = k * 1.57 + rng:NextNumber(-0.4, 0.4)
			local at = Vector3.new(x + math.cos(ang) * 16, 0.6, math.sin(ang) * 17)
			lib().ST.blob(U.Sand, rng, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 5.5, 1.6, 4, function(n: Vector3): Color3
				return H.scaled(sand, 0.85 + 0.2 * (n.Y + 1) / 2)
			end, 0.5)
			local sat = Vector3.new(x + math.cos(ang + 0.6) * 15.5, 0.6, math.sin(ang + 0.6) * 16)
			strataSlab(U.Scree, rng, CFrame.new(sat) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), Vector3.new(2.6, 1.4, 2.2), rgb(184, 84, 56))
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %d faceted strata slabs, cracks, sand and scree; %.1f x %.1f x %.1f", id, #slabs, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 06 DESERT ARENA DOOR (desert_gate_door: yellow lintel, brown pylons, blue band, yellow door panel; the Desert boss
-- arena's Door) and 08 DESERT BOSS GATE (desert_gate_boss_gate: the blue / gold double door with the two cyan squares
-- and the gold-and-cyan emblem): the desert gate recipe (Egyptian arch / pylon temple gate: coursed sandstone pylons on
-- plinths with grooves, lapis and gold bands with patterns, flared capitals, a coursed lintel with gold rules, a
-- two-tier gold cornice) and a proper door panel (two leaves with gold frames and studs round today's lapis panels and
-- glyphs, gold bezels round the cyan squares, a gold ring round the sun disc, feathered wings). Today's structural
-- parts stay as invisible collision; the glows (sun disc, seal, gems), panels, glyphs and wings stay as they are.
-- The arena door: BossService fades every part of the Door (and makes it walk-through) when it opens, the new parts
-- too (the old parts stay invisible); the boss gate's Interact prompt lives on the map copy and is kept by the sync.
---------------------------------------------------------------------
local EGY = { sand = rgb(214, 182, 128), sandDark = rgb(140, 104, 68), pylon = rgb(140, 104, 68), gold = rgb(255, 201, 60), lapis = rgb(44, 92, 200), groove = rgb(96, 70, 46), studs = rgb(232, 176, 44) }

local function dressEgyptGate(m: Model, rng: Random, doorName: string): any
	local H = lib().H
	local U: any = { Stone = {}, StoneDark = {}, Gold = {}, Inlay = {}, Groove = {} }
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(rows, { part = c, name = c.Name, cf = c.CFrame, size = c.Size, color = c.Color })
		end
	end
	-- the pylons' visible top: just under the lintel (the capital sits right below it)
	local lintelBottom = math.huge
	for _, r in ipairs(rows) do
		if r.name == "Lintel" then
			lintelBottom = math.min(lintelBottom, r.cf.Y - r.size.Y / 2)
		end
	end
	for _, r in ipairs(rows) do
		local n, cf, s = r.name, r.cf, r.size
		if n == "Pylon" then
			toCollision(r.part)
			local x0, x1 = cf.X - s.X / 2, cf.X + s.X / 2
			local y0 = cf.Y - s.Y / 2
			-- plinth
			table.insert(U.StoneDark, H.chamfered(Vector3.new(s.X + 1.2, 2.2, s.Z + 0.8), CFrame.new(cf.X, y0 + 1.1, cf.Z), EGY.sandDark, { "topFrontBack", "topSides", "vertical" }, 0.3))
			-- coursed shaft (pylon colour), courses about 3 tall, running bond
			local top = math.min(y0 + s.Y, lintelBottom) - 2.3
			local nC = math.max(2, math.round((top - (y0 + 2.2)) / 3))
			local h = (top - (y0 + 2.2)) / nC
			local below = nil
			local n0 = #U.Stone
			for k = 0, nC - 1 do
				below = H.course(U.Stone, rng, { x0 = x0, x1 = x1, y = y0 + 2.2 + k * h, h = h, depth = s.Z, color = r.color, H = 60, below = below, half = k % 2 == 1, minL = 1.2, maxL = 2.4 })
			end
			for k = n0 + 1, #U.Stone do
				U.Stone[k].CFrame = CFrame.new(0, 0, cf.Z) * U.Stone[k].CFrame
			end
			-- two carved grooves on both faces
			for _, zs in ipairs({ -1, 1 }) do
				for _, gx in ipairs({ -s.X * 0.22, s.X * 0.22 }) do
					table.insert(U.Groove, H.piece("Part", Vector3.new(0.45, (top - y0 - 2.2) * 0.62, 0.14), CFrame.new(cf.X + gx, (y0 + 2.2 + top) / 2, cf.Z + zs * (s.Z / 2 + 0.05)), EGY.groove))
				end
			end
			-- capital: a flared block and a gold rim
			table.insert(U.StoneDark, H.chamfered(Vector3.new(s.X + 0.5, 1.0, s.Z + 0.4), CFrame.new(cf.X, top + 0.5, cf.Z), EGY.sandDark, { "vertical" }, 0.2))
			table.insert(U.Stone, H.chamfered(Vector3.new(s.X + 1.1, 1.3, s.Z + 0.8), CFrame.new(cf.X, top + 1.65, cf.Z), EGY.sand, { "topFrontBack", "topSides" }, 0.35))
			table.insert(U.Gold, H.piece("Part", Vector3.new(s.X + 1.2, 0.2, s.Z + 0.9), CFrame.new(cf.X, top + 1.05, cf.Z), EGY.gold))
		elseif n == "PylonBand" then
			toCollision(r.part)
			local isGold = r.color.R > 0.8
			table.insert(if isGold then U.Gold else U.Inlay, H.chamfered(s + Vector3.new(0.15, 0, 0.15), cf, r.color, { "topFrontBack", "topSides" }, 0.18))
			for _, zs in ipairs({ -1, 1 }) do
				for k = -2, 2 do
					local p = CFrame.new(cf.X + k * s.X / 5.2, cf.Y, cf.Z + zs * (s.Z / 2 + 0.1))
					if isGold then
						table.insert(U.Inlay, H.piece("Part", Vector3.new(0.7, 0.7, 0.18), p, EGY.lapis))
					else
						table.insert(U.Gold, H.piece("Part", Vector3.new(0.75, 0.75, 0.18), p * CFrame.Angles(0, 0, math.rad(45)), EGY.gold))
					end
				end
			end
		elseif n == "Lintel" then
			toCollision(r.part)
			local y0 = cf.Y - s.Y / 2
			local n0 = #U.Stone
			local below = H.course(U.Stone, rng, { x0 = cf.X - s.X / 2, x1 = cf.X + s.X / 2, y = y0, h = s.Y / 2, depth = s.Z, color = r.color, H = 60 })
			H.course(U.Stone, rng, { x0 = cf.X - s.X / 2, x1 = cf.X + s.X / 2, y = y0 + s.Y / 2, h = s.Y / 2, depth = s.Z, color = r.color, H = 60, below = below, half = true })
			for k = n0 + 1, #U.Stone do
				U.Stone[k].CFrame = CFrame.new(0, 0, cf.Z) * U.Stone[k].CFrame
			end
			for _, zs in ipairs({ -1, 1 }) do
				for _, yy in ipairs({ y0 + 0.35, y0 + s.Y - 0.35 }) do
					table.insert(U.Gold, H.piece("Part", Vector3.new(s.X + 0.1, 0.3, 0.2), CFrame.new(cf.X, yy, cf.Z + zs * (s.Z / 2 + 0.08)), EGY.gold))
				end
			end
		elseif n == "Cornice" then
			toCollision(r.part)
			table.insert(U.Gold, H.chamfered(Vector3.new(s.X - 0.6, s.Y * 0.55, s.Z - 0.3), cf * CFrame.new(0, -s.Y * 0.2, 0), r.color, { "topFrontBack", "topSides" }, 0.2))
			table.insert(U.Gold, H.chamfered(Vector3.new(s.X + 0.6, s.Y * 0.5, s.Z + 0.8), cf * CFrame.new(0, s.Y * 0.27, 0), H.scaled(r.color, 1.04), { "topFrontBack", "topSides" }, 0.25))
		elseif n == doorName then
			-- the door panel: kept (it is the door itself) with a gold frame round each leaf, studs, a bevelled edge
			local hw, hh = s.X / 2, s.Y / 2
			for _, zs in ipairs({ -1, 1 }) do
				local zf = cf.Z + zs * (s.Z / 2 + 0.12)
				for _, side in ipairs({ -1, 1 }) do
					local lx = cf.X + side * hw / 2
					local lw = hw - 0.5
					-- leaf frame
					table.insert(U.Gold, H.piece("Part", Vector3.new(lw, 0.7, 0.25), CFrame.new(lx, cf.Y + hh - 0.6, zf), EGY.studs))
					table.insert(U.Gold, H.piece("Part", Vector3.new(lw, 0.7, 0.25), CFrame.new(lx, cf.Y - hh + 0.6, zf), EGY.studs))
					table.insert(U.Gold, H.piece("Part", Vector3.new(0.7, s.Y - 0.5, 0.25), CFrame.new(cf.X + side * (hw - 0.6), cf.Y, zf), EGY.studs))
					table.insert(U.Gold, H.piece("Part", Vector3.new(0.6, s.Y - 0.5, 0.25), CFrame.new(cf.X + side * 0.75, cf.Y, zf), EGY.studs))
					-- studs: two columns between the frame and today's panels
					for row = 0, 7 do
						local yy = cf.Y - hh + 2.2 + row * (s.Y - 4.4) / 7
						for _, cx in ipairs({ side * (hw - 1.55), side * 1.5 }) do
							table.insert(U.Gold, H.piece("Part", Vector3.new(0.45, 0.45, 0.32), CFrame.new(cf.X + cx, yy, zf), EGY.studs))
						end
					end
				end
			end
		elseif n == "Gem" then
			-- a gold bezel round each cyan square (the glow itself is kept)
			local zf = cf.Z
			for _, e in ipairs({ { 0, s.Y / 2 + 0.25, s.X + 1, 0.5 }, { 0, -s.Y / 2 - 0.25, s.X + 1, 0.5 }, { s.X / 2 + 0.25, 0, 0.5, s.Y }, { -s.X / 2 - 0.25, 0, 0.5, s.Y } }) do
				table.insert(U.Gold, H.piece("Part", Vector3.new(e[3], e[4], s.Z + 0.25), CFrame.new(cf.X + e[1], cf.Y + e[2], zf), EGY.gold))
			end
		elseif n == "SunDisc" then
			-- a gold ring round the sun disc (12 segments), in the disc's plane
			local r0 = s.Y / 2 + 0.55
			for k = 0, 11 do
				local a = k * math.pi / 6
				local p = cf.Position + Vector3.new(math.cos(a) * r0, math.sin(a) * r0, 0)
				table.insert(U.Gold, H.piece("Part", Vector3.new(2 * r0 * math.sin(math.pi / 12) + 0.15, 0.7, 0.5), CFrame.new(p) * CFrame.Angles(0, 0, a + math.pi / 2), EGY.gold))
			end
		elseif n == "Wing" then
			-- feathers under each wing bar: 3 tapering layers, lapis and gold
			local dir = if cf.X >= 0 then 1 else -1
			for k = 1, 3 do
				local len = s.X * (1 - 0.18 * k)
				local x = cf.X - dir * (s.X - len) / 2
				table.insert(if k % 2 == 1 then U.Gold else U.Inlay, H.piece("Part", Vector3.new(len, 0.7, 0.3), CFrame.new(x, cf.Y - s.Y / 2 - 0.35 - (k - 1) * 0.72, cf.Z), if k % 2 == 1 then EGY.gold else EGY.lapis))
			end
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	return U
end

function P.desertArenaDoor(): string
	local id = "desert_gate_door"
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	lib().H.setBevelSelf(true)
	local U = dressEgyptGate(m, Random.new(6606), "Slab")
	mergeAll(m, U)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: Egyptian gate recipe, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

function P.desertBossGate(): string
	local id = "desert_gate_boss_gate"
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	lib().H.setBevelSelf(true)
	local U = dressEgyptGate(m, Random.new(8808), "Door")
	mergeAll(m, U)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: Egyptian gate recipe, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 09 DESERT OASIS WELL (desert_landmark_oasis_well): the improved plains well (stone blocks, rim stones, timber
-- posts and winch, iron, rope coil, bucket, roof, rippled water) duplicated over today's well (scaled to its rim,
-- posts and roof: x / z 1.5, y 1.2) and recoloured to sandstone, the red awning colour kept on its roof; the dry
-- basin and the bowl get the fountain's rippled water; the broken columns stay (drum joints, a broken top, chamfered
-- bases / capitals / lintels); the paving becomes cut sandstone tiles. Today's well parts stay as invisible collision.
---------------------------------------------------------------------
local OASIS = { sand = rgb(226, 190, 132), sandDark = rgb(184, 146, 98), mortar = rgb(150, 118, 80), timber = rgb(150, 104, 64), awning = rgb(204, 96, 62), drift = rgb(236, 204, 140) }

function P.oasisWell(): string
	local id = "desert_landmark_oasis_well"
	local H = lib().H
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local well = folder():FindFirstChild("well") :: Model
	assert(well, "template well missing")
	local fountain = folder():FindFirstChild("fountain") :: Model
	assert(fountain, "template fountain missing")
	local m = old:Clone()
	local rng = Random.new(9909)
	H.setBevelSelf(true)
	local U: any = { Joints = {}, Stone = {}, StoneDark = {}, Tiles = {}, Rubble = {} }
	local wellAt = nil
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local n = c.Name
			if n == "WellWall" then
				wellAt = Vector3.new(c.Position.X, c.Position.Y - c.Size.X / 2, c.Position.Z)
				toCollision(c)
			elseif n == "WellRim" or n == "Post" or n == "Beam" or n == "WellRoof" or n == "Bucket" or n == "Rope" or n == "WellWater" then
				toCollision(c)
			elseif n == "FountainWater" then
				toCollision(c)
			elseif n == "Column" then
				-- drum joints every ~3.4 studs along the shaft (its X axis), a broken top on the short one
				local len = c.Size.X
				local k = math.floor(len / 3.4)
				for j = 1, k do
					local dx = -len / 2 + j * len / (k + 1)
					table.insert(U.Joints, H.piece("Part", Vector3.new(0.16, c.Size.Y + 0.08, c.Size.Z + 0.08), c.CFrame * CFrame.new(dx, 0, 0), H.scaled(c.Color, 0.84), { shape = Enum.PartType.Cylinder }))
				end
				if len < 12 then
					local e1, e2 = c.CFrame * CFrame.new(len / 2, 0, 0), c.CFrame * CFrame.new(-len / 2, 0, 0)
					local top = if e1.Y > e2.Y then e1 else e2
					for j = 1, 3 do
						local a = j * 2.1 + rng:NextNumber(-0.3, 0.3)
						local at = top.Position + Vector3.new(math.cos(a) * 0.7, 0.35 + rng:NextNumber(0, 0.5), math.sin(a) * 0.7)
						table.insert(U.Stone, H.chamfered(Vector3.new(1.3, 0.9 + rng:NextNumber(0, 0.6), 1.1), CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), c.Color, { "vertical", "topFrontBack", "topSides" }, 0.18))
					end
				end
			elseif n == "ColBase" or n == "Capital" or n == "Lintel" or n == "FallenLintel" then
				toCollision(c)
				table.insert(if n == "Lintel" or n == "FallenLintel" then U.Stone else U.StoneDark, H.chamfered(c.Size + Vector3.new(0.06, 0, 0.06), c.CFrame, c.Color, { "vertical", "topFrontBack", "topSides" }, 0.3))
			elseif n == "Rubble" then
				toCollision(c)
				local s = c.Size
				for j = 1, 3 do
					local off = Vector3.new(rng:NextNumber(-0.3, 0.3) * s.X, -s.Y * 0.25, rng:NextNumber(-0.3, 0.3) * s.Z)
					table.insert(U.Rubble, H.chamfered(Vector3.new(s.X * 0.55, s.Y * 0.6, s.Z * 0.55), CFrame.new(c.Position + off) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), H.scaled(c.Color, rng:NextNumber(0.9, 1.05)), { "vertical", "topFrontBack", "topSides" }, 0.25))
				end
			elseif n == "Paving" and c.Size.Y < 0.55 then
				-- the upper paving becomes the mortar bed of a grid of cut sandstone tiles
				local s = c.Size
				local nx, nz = 6, 4
				local w, d = s.X / nx, s.Z / nz
				for i = 0, nx - 1 do
					for j = 0, nz - 1 do
						local at = c.Position + Vector3.new(-s.X / 2 + (i + 0.5) * w, s.Y / 2 + 0.07 + rng:NextNumber(0, 0.03), -s.Z / 2 + (j + 0.5) * d)
						table.insert(U.Tiles, H.chamfered(Vector3.new(w - 0.18, 0.14, d - 0.18), CFrame.new(at), H.scaled(OASIS.sand, rng:NextNumber(0.94, 1.06)), { "topFrontBack", "topSides" }, 0.05))
					end
				end
				c.Color = OASIS.mortar
			end
		end
	end
	assert(wellAt, "WellWall missing")
	-- the improved plains well over today's well (its visual meshes only), scaled and recoloured to sandstone
	local sx, sy = 1.5, 1.2
	local colours = { Stones = OASIS.sand, RimStones = OASIS.sandDark, Mortar = OASIS.mortar, Moss = OASIS.drift, Timber = OASIS.timber, Roof = OASIS.awning }
	local origin = CFrame.new(wellAt)
	local wellPivot = well:GetPivot()
	for _, c in ipairs(well:GetChildren()) do
		if c:IsA("MeshPart") then
			local u = c:Clone()
			local rel = wellPivot:ToObjectSpace(c.CFrame)
			assert(math.abs(rel.UpVector.Y) > 0.999, "well mesh " .. c.Name .. " is tilted")
			local p = rel.Position
			local rot = rel - rel.Position
			-- local size axes: Y stays Y, X / Z (turned about Y) both scale by sx
			u.Size = Vector3.new(c.Size.X * sx, c.Size.Y * sy, c.Size.Z * sx)
			u.CFrame = origin * CFrame.new(p.X * sx, p.Y * sy, p.Z * sx) * rot
			u.Name = "Well" .. c.Name
			u.Color = colours[c.Name] or c.Color
			u.CanCollide = false
			u.CanTouch = false
			u.CanQuery = false
			u.Parent = m
		end
	end
	-- the fountain's rippled water in the dry basin and in the bowl
	local water = fountain:FindFirstChild("LowerWater") :: MeshPart
	assert(water, "fountain LowerWater missing")
	for _, spec in ipairs({ { "BasinRim", 16.8 }, { "Bowl", 7.6 } }) do
		local holder = m:FindFirstChild(spec[1]) :: BasePart
		if holder then
			local u = water:Clone()
			u.Size = Vector3.new(spec[2], u.Size.Y, spec[2])
			u.CFrame = CFrame.new(holder.Position + Vector3.new(0, holder.Size.X / 2 + 0.07, 0))
			u.Name = if spec[1] == "Bowl" then "BowlWater" else "BasinWater"
			u.CanCollide = false
			u.CanTouch = false
			u.CanQuery = false
			u.Parent = m
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: improved well (sandstone) + fountain water + column ruins, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 10 DESERT SPEAR (desert_prop_spear): a leaf-shaped gold blade with a bevel (one convex solid: flared base, widest
-- third of the way up, a long taper to the point, both faces bevelled to the edges, the ridge thinning to the point), a gold socket, a blue binding of
-- wraps with a hanging cloth tassel (gold knot), a round wooden shaft with grain lines and a small gold butt cap.
-- Today's parts stay as invisible collision.
---------------------------------------------------------------------
function P.spear(): string
	local id = "desert_prop_spear"
	local L = lib()
	local H, TB = L.H, L.TB
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local shaft = m:FindFirstChild("Shaft") :: BasePart
	assert(shaft, "Shaft missing")
	local y0 = shaft.Position.Y - shaft.Size.Y / 2
	local y1 = shaft.Position.Y + shaft.Size.Y / 2
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			toCollision(c)
		end
	end
	local GOLD, LAPIS, WOOD = rgb(255, 201, 60), rgb(44, 92, 200), rgb(150, 104, 64)
	local U: any = { Shaft = {}, Grain = {}, Gold = {}, Binding = {}, Tassel = {}, Blade = {} }
	local CYL = { shape = Enum.PartType.Cylinder }
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis (X) turned to Y
	-- shaft and grain
	local len = y1 - y0
	table.insert(U.Shaft, H.piece("Part", Vector3.new(len - 0.4, 0.46, 0.46), CFrame.new(0, y0 + 0.2 + (len - 0.4) / 2, 0) * up, WOOD, CYL))
	for k = 1, 4 do
		local a = k * math.pi / 2 + 0.4
		local gl = len * (0.45 + 0.1 * (k % 2))
		local gy = y0 + 1 + (k - 1) * 0.9 + gl / 2
		table.insert(U.Grain, H.piece("Part", Vector3.new(0.05, gl, 0.06), CFrame.Angles(0, a, 0) * CFrame.new(0, gy, 0.215) * CFrame.Angles(0, 0, math.rad(1.5)), H.scaled(WOOD, 0.72)))
	end
	for _, gy in ipairs({ y0 + len * 0.35, y0 + len * 0.62 }) do
		table.insert(U.Grain, H.piece("Part", Vector3.new(0.12, 0.5, 0.5), CFrame.new(0, gy, 0) * up, H.scaled(WOOD, 0.8), CYL))
	end
	-- butt cap
	table.insert(U.Gold, H.piece("Part", Vector3.new(0.5, 0.6, 0.6), CFrame.new(0, y0 + 0.25, 0) * up, H.scaled(GOLD, 0.85), CYL))
	table.insert(U.Gold, H.piece("Part", Vector3.new(0.12, 0.66, 0.66), CFrame.new(0, y0 + 0.55, 0) * up, GOLD, CYL))
	-- the blue binding under the socket: a core and 4 raised wraps
	local by = y1 - 0.9
	table.insert(U.Binding, H.piece("Part", Vector3.new(1.0, 0.56, 0.56), CFrame.new(0, by, 0) * up, LAPIS, CYL))
	for k = 0, 3 do
		table.insert(U.Binding, H.piece("Part", Vector3.new(0.14, 0.66, 0.66), CFrame.new(0, by - 0.39 + k * 0.26, 0) * up, H.scaled(LAPIS, 1.12), CYL))
	end
	-- the gold socket the blade sits in
	table.insert(U.Gold, H.piece("Part", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, y1 - 0.15, 0) * up, GOLD, CYL))
	table.insert(U.Gold, H.piece("Part", Vector3.new(0.1, 0.62, 0.62), CFrame.new(0, y1 - 0.38, 0) * up, H.scaled(GOLD, 0.9), CYL))
	-- the tassel: a gold knot and three cloth strips hanging from the binding
	local knot = Vector3.new(0.34, by - 0.45, 0)
	table.insert(U.Gold, H.piece("Part", Vector3.new(0.3, 0.3, 0.3), CFrame.new(knot), GOLD, { shape = Enum.PartType.Ball }))
	local cloth = { LAPIS, rgb(240, 232, 210), H.scaled(LAPIS, 1.2) }
	for k = 1, 3 do
		local l = 1.5 + 0.25 * k
		local tilt = math.rad(-6 + 6 * (k - 2) * 1.5)
		local f = CFrame.new(knot) * CFrame.Angles(0, math.rad(-20 + 20 * (k - 1)), tilt) * CFrame.new(0, -l / 2 - 0.1, 0)
		table.insert(U.Tassel, H.piece("Part", Vector3.new(0.06, l, 0.16), f, cloth[k]))
	end
	-- the blade: a convex leaf solid in the blade frame (y up from the socket, z across, x the thickness)
	local base, wide, tip, w0, w1, t = 0, 1.0, 3.0, 0.28, 0.9, 0.2
	local planes = {}
	local function plane(n: Vector3, p: Vector3)
		local u = n.Unit
		table.insert(planes, { n = u, d = u:Dot(p) })
	end
	plane(Vector3.new(0, -1, 0), Vector3.new(0, base, 0))
	for _, zs in ipairs({ -1, 1 }) do
		-- lower flare: through (y base, z w0) and (y wide, z w1)
		plane(Vector3.new(0, -(w1 - w0) / (wide - base), 1) * Vector3.new(1, 1, zs), Vector3.new(0, base, zs * w0))
		-- upper taper: through (y wide, z w1) and (y tip, z 0)
		plane(Vector3.new(0, w1 / (tip - wide), 1) * Vector3.new(1, 1, zs), Vector3.new(0, wide, zs * w1))
		-- bevels: the faces run from the central ridge (thickness t) to the edges
		for _, xs in ipairs({ -1, 1 }) do
			plane(Vector3.new(xs, 0, zs * (t / w1) * 0.95), Vector3.new(xs * t, 0, 0))
		end
	end
	-- the ridge thins to the point above the widest part
	for _, xs in ipairs({ -1, 1 }) do
		plane(Vector3.new(xs, t / (tip - wide), 0), Vector3.new(xs * t, wide, 0))
	end
	local frame = CFrame.new(0, y1 - 0.05, 0)
	TB.solidOf(U.Blade, frame, Vector3.new(-0.4, -0.1, -1.0), Vector3.new(0.4, tip + 0.1, 1.0), planes, function(n: Vector3): Color3
		if math.abs(n.Y) > 0.6 then
			return H.scaled(GOLD, 0.92)
		end
		return if n.X > 0 then H.scaled(GOLD, 1.06) else H.scaled(GOLD, 0.9)
	end)
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: leaf blade, binding + tassel, grained shaft, butt cap; %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- Task 3 jungle shared: the jungle buildings recipe (PropsJungleBuildings: cut stone faces in running bond with tone
-- steps and cracks, moss mounds and drapes, vine strands; the face temple gate and the stone head use it) and the
-- monuments helpers (frustumN for fangs, drums and bowls)
---------------------------------------------------------------------
local JLIB = nil
local function jlib(): any
	if not JLIB then
		JLIB = { J = require(ServerStorage.DevTools.PropsJungleBuildings:Clone()), M = require(ServerStorage.DevTools.PropsDesertMonuments:Clone()) }
	end
	return JLIB
end
P.jlib = jlib

local JUNGLE = { gold = rgb(255, 201, 60), goldDark = rgb(202, 154, 54), teeth = rgb(232, 226, 208) }

-- a diamond bezel round a square glow turned 45 degrees (`cf` = the glow's CFrame, s = its side)
local function diamondBezel(list: { BasePart }, cf: CFrame, s: number, w: number, depth: number, color: Color3)
	local H = lib().H
	for _, e in ipairs({ { 0, s / 2 + w / 2, s + 2 * w, w }, { 0, -s / 2 - w / 2, s + 2 * w, w }, { s / 2 + w / 2, 0, w, s }, { -s / 2 - w / 2, 0, w, s } }) do
		table.insert(list, H.piece("Part", Vector3.new(e[3], e[4], depth), cf * CFrame.new(e[1], e[2], 0), color))
	end
end

---------------------------------------------------------------------
-- 11 JUNGLE BOSS GATE (jungle_gate_boss_gate, Jungle_4: the golden double door with the fanged face, cyan eyes and
-- diamonds between stone pillars, the gold diamond sign on top): the jungle stone temple recipe (face_temple_gate):
-- the pillars and the lintel as cut stone blocks in running bond (both faces) with moss on the lintel, drapes over its
-- edge and vine strands down the pillars; the doors kept with carved depth (gold leaf frames, raised mouldings round
-- the panels, rivet rows on the bands, gold bezels round the glowing diamonds, real ring handles), the fanged face
-- carved (bevelled frame, angry brow halves, eye sockets, cheeks, a nose, lips, tapered fangs), the crest a bevelled
-- gold emblem on a stone plinth with a gold bezel round its glowing gem, braziers as stone drums with gold bowls, the
-- step as jointed slabs. Today's colliding parts stay as invisible collision (or stay as they are: the doors, the
-- jambs and lintel under their new stone faces); glows, the 2 nested stone heads and the map copy's prompt are kept.
---------------------------------------------------------------------
function P.jungleBossGate(): string
	local id = "jungle_gate_boss_gate"
	local H = lib().H
	local L = jlib()
	local J, M = L.J, L.M
	local PAL = J.PALETTE
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(1111)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Carving = {}, Gold = {}, GoldDark = {}, Moss = {}, Teeth = {} }
	local FRONT = Vector3.new(0, 0, -1)
	local function each(name: string): { BasePart }
		local t = {}
		for _, c in ipairs(m:GetChildren()) do
			if c:IsA("BasePart") and c.Name == name then
				table.insert(t, c)
			end
		end
		return t
	end
	-- pillars (jambs) and lintel: cut stone faces front and back over today's parts (kept as the core)
	for _, j in ipairs(each("Jamb")) do
		local x0, x1 = j.Position.X - j.Size.X / 2, j.Position.X + j.Size.X / 2
		local lintelBottom = 36
		J.stoneFace(U.Stone, rng, x0, x1, 0, lintelBottom, j.Position.Z - j.Size.Z / 2, true, 2.4, PAL.STONE, nil, 1, 1.4)
		J.stoneFace(U.Stone, rng, x0, x1, 0, lintelBottom, j.Position.Z + j.Size.Z / 2, false, 2.4, PAL.STONE, nil, 1, 1.4)
		-- a plinth course at the foot
		table.insert(U.Carving, H.chamfered(Vector3.new(j.Size.X + 0.8, 1.6, j.Size.Z + 0.8), CFrame.new(j.Position.X, 0.8, j.Position.Z), H.scaled(PAL.STONE_DARK, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.3))
	end
	local lintel = m:FindFirstChild("Lintel") :: BasePart
	do
		local c, s = lintel.Position, lintel.Size
		J.stoneFace(U.Stone, rng, c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z - s.Z / 2, true, 2.33, PAL.STONE, nil, 2, 1.8)
		J.stoneFace(U.Stone, rng, c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z + s.Z / 2, false, 2.33, PAL.STONE, nil, 1, 1.8)
		-- a cap course over the lintel top
		table.insert(U.Carving, H.chamfered(Vector3.new(s.X + 0.8, 0.8, s.Z + 0.8), CFrame.new(c.X, c.Y + s.Y / 2 + 0.3, c.Z), H.scaled(PAL.STONE_DARK, 1.08), { "vertical", "topFrontBack", "topSides" }, 0.25))
	end
	-- the crest: a bevelled gold emblem on a stone plinth, a gold bezel round the glowing gem, corner studs
	local crest = m:FindFirstChild("Crest") :: BasePart
	if crest then
		toCollision(crest)
		local c, s = crest.CFrame, crest.Size
		table.insert(U.Gold, H.chamfered(s, c, JUNGLE.gold, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.5))
		local capTop = lintel.Position.Y + lintel.Size.Y / 2 + 0.7
		table.insert(U.Carving, H.chamfered(Vector3.new(s.X + 2, 1.0, s.Z + 1.6), CFrame.new(c.X, capTop + 0.5, c.Z), PAL.STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.3))
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				table.insert(U.GoldDark, H.chamfered(Vector3.new(0.9, 0.9, 0.5), c * CFrame.new(sx * (s.X / 2 - 0.9), sy * (s.Y / 2 - 0.9), -s.Z / 2 - 0.15), JUNGLE.goldDark, { "frontFace" }, 0.2))
			end
			-- engraved side bars
			table.insert(U.GoldDark, H.piece("Part", Vector3.new(0.4, s.Y - 1.2, 0.3), c * CFrame.new(sx * (s.X / 2 - 2.3), 0, -s.Z / 2 - 0.1), JUNGLE.goldDark))
		end
	end
	local gem = m:FindFirstChild("CrestGem") :: BasePart
	if gem then
		diamondBezel(U.GoldDark, gem.CFrame * CFrame.new(0, 0, -0.05), gem.Size.X, 0.45, gem.Size.Z + 0.2, JUNGLE.goldDark)
	end
	-- the door leaves: gold frames round each leaf, rivet rows on the bands (front face)
	for _, d in ipairs(each("Door")) do
		local c, s = d.Position, d.Size
		local zf = c.Z - s.Z / 2 - 0.1
		local inner = if c.X > 0 then -1 else 1
		table.insert(U.GoldDark, H.chamfered(Vector3.new(s.X, 0.9, 0.3), CFrame.new(c.X, c.Y + s.Y / 2 - 0.45, zf), JUNGLE.goldDark, { "frontFace" }, 0.12))
		table.insert(U.GoldDark, H.chamfered(Vector3.new(s.X, 0.9, 0.3), CFrame.new(c.X, c.Y - s.Y / 2 + 0.45, zf), JUNGLE.goldDark, { "frontFace" }, 0.12))
		table.insert(U.GoldDark, H.chamfered(Vector3.new(0.9, s.Y - 1.8, 0.3), CFrame.new(c.X - inner * (s.X / 2 - 0.45), c.Y, zf), JUNGLE.goldDark, { "frontFace" }, 0.12))
	end
	for _, b in ipairs(each("DoorBand")) do
		local c, s = b.Position, b.Size
		for k = -2, 2 do
			local x = c.X + k * (s.X - 2) / 4
			if math.abs(x) > 1.2 then
				table.insert(U.Gold, H.chamfered(Vector3.new(0.55, 0.55, 0.35), CFrame.new(x, c.Y, c.Z - s.Z / 2 - 0.12), JUNGLE.gold, { "frontFace" }, 0.15))
			end
		end
	end
	-- raised mouldings round the door panels (the upper ones leave the side next to the face open)
	for _, p in ipairs(each("DoorPanel")) do
		local c, s = p.Position, p.Size
		local zf = c.Z - s.Z / 2 - 0.15
		local inner = if c.X > 0 then -1 else 1
		local upper = c.Y > 18
		-- (the upper bars stop short of the face's frame)
		local outer = c.X - inner * (s.X / 2 + 0.6)
		local xin = if upper then -inner * 5.8 else c.X + inner * (s.X / 2 + 0.6)
		local bw, bx = math.abs(outer - xin), (outer + xin) / 2
		table.insert(U.GoldDark, H.chamfered(Vector3.new(bw, 0.6, 0.4), CFrame.new(bx, c.Y + s.Y / 2 + 0.3, zf), JUNGLE.goldDark, { "frontFace" }, 0.15))
		table.insert(U.GoldDark, H.chamfered(Vector3.new(bw, 0.6, 0.4), CFrame.new(bx, c.Y - s.Y / 2 - 0.3, zf), JUNGLE.goldDark, { "frontFace" }, 0.15))
		table.insert(U.GoldDark, H.chamfered(Vector3.new(0.6, s.Y, 0.4), CFrame.new(c.X - inner * (s.X / 2 + 0.3), c.Y, zf), JUNGLE.goldDark, { "frontFace" }, 0.15))
		if not upper then
			table.insert(U.GoldDark, H.chamfered(Vector3.new(0.6, s.Y, 0.4), CFrame.new(c.X + inner * (s.X / 2 + 0.3), c.Y, zf), JUNGLE.goldDark, { "frontFace" }, 0.15))
		end
		-- a raised inner plate (the panel's depth)
		if not upper then
			table.insert(U.Gold, H.chamfered(Vector3.new(s.X - 2.4, s.Y - 2.4, 0.2), CFrame.new(c.X, c.Y, c.Z - s.Z / 2 + 0.1), H.scaled(JUNGLE.goldDark, 1.08), { "frontFace" }, 0.2))
		end
	end
	-- gold bezels round the glowing door diamonds (kept)
	for _, g in ipairs(each("DoorGlyph")) do
		diamondBezel(U.GoldDark, g.CFrame * CFrame.new(0, 0, -0.1), g.Size.X, 0.5, g.Size.Z + 0.25, JUNGLE.gold)
	end
	-- ring handles: a mount plate and a ring of 10 segments in place of today's ring blocks
	for _, r in ipairs(each("Ring")) do
		local c = r.Position
		r:Destroy()
		table.insert(U.GoldDark, H.chamfered(Vector3.new(1.6, 1.6, 0.4), CFrame.new(c.X, c.Y + 1.3, c.Z - 0.6), JUNGLE.goldDark, { "frontFace" }, 0.2))
		local r0 = 1.05
		for k = 0, 9 do
			local a = k * 2 * math.pi / 10
			local p = Vector3.new(c.X + math.cos(a) * r0, c.Y + math.sin(a) * r0, c.Z - 0.75)
			table.insert(U.Gold, H.piece("Part", Vector3.new(2 * r0 * math.sin(math.pi / 10) + 0.12, 0.3, 0.3), CFrame.new(p) * CFrame.Angles(0, 0, a + math.pi / 2), JUNGLE.gold))
		end
	end
	-- the fanged face, carved
	local face = m:FindFirstChild("IdolFace") :: BasePart
	if face then
		local c, s = face.Position, face.Size
		local zf = c.Z - s.Z / 2
		for _, e in ipairs({ { 0, s.Y / 2 + 0.3, s.X + 1.2, 0.6 }, { 0, -s.Y / 2 - 0.3, s.X + 1.2, 0.6 }, { s.X / 2 + 0.3, 0, 0.6, s.Y }, { -s.X / 2 - 0.3, 0, 0.6, s.Y } }) do
			table.insert(U.GoldDark, H.chamfered(Vector3.new(e[3], e[4], 0.7), CFrame.new(c.X + e[1], c.Y + e[2], zf - 0.2), JUNGLE.goldDark, { "frontFace" }, 0.2))
		end
		-- cheeks and a nose
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Gold, H.chamfered(Vector3.new(2.4, 2.6, 0.7), CFrame.new(c.X + sx * 3.4, c.Y - 0.6, zf - 0.3), H.scaled(JUNGLE.gold, 0.95), { "frontFace" }, 0.45))
		end
		table.insert(U.Gold, H.chamfered(Vector3.new(1.8, 2.6, 1.0), CFrame.new(c.X, c.Y + 0.2, zf - 0.45), H.scaled(JUNGLE.gold, 1.04), { "frontFace", "vertical" }, 0.4))
		-- crown band with gold studs over the brow
		table.insert(U.GoldDark, H.chamfered(Vector3.new(s.X + 1.2, 0.9, 0.9), CFrame.new(c.X, c.Y + s.Y / 2 + 0.95, zf - 0.25), JUNGLE.goldDark, { "frontFace" }, 0.2))
		for k = -2, 2 do
			table.insert(U.Gold, H.chamfered(Vector3.new(0.6, 0.6, 0.4), CFrame.new(c.X + k * 2.2, c.Y + s.Y / 2 + 0.95, zf - 0.85), JUNGLE.gold, { "frontFace" }, 0.15))
		end
	end
	local brow = m:FindFirstChild("IdolBrow") :: BasePart
	if brow then
		local c = brow.Position
		brow:Destroy()
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.GoldDark, H.chamfered(Vector3.new(4.8, 1.5, 0.9), CFrame.new(c.X + sx * 2.35, c.Y - 0.1, c.Z - 0.3) * CFrame.Angles(0, 0, math.rad(sx * 12)), JUNGLE.goldDark, { "frontFace" }, 0.3))
		end
	end
	for _, e in ipairs(each("IdolEye")) do
		table.insert(U.Carving, H.piece("Part", Vector3.new(e.Size.X + 0.8, e.Size.Y + 0.8, 0.3), CFrame.new(e.Position.X, e.Position.Y, e.Position.Z + 0.12), PAL.RECESS))
	end
	local mouth = m:FindFirstChild("IdolMouth") :: BasePart
	if mouth then
		local c, s = mouth.Position, mouth.Size
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(U.GoldDark, H.chamfered(Vector3.new(s.X + 0.8, 0.55, 0.6), CFrame.new(c.X, c.Y + sy * (s.Y / 2 + 0.25), c.Z - 0.15), JUNGLE.goldDark, { "frontFace" }, 0.2))
		end
	end
	for _, t in ipairs(each("Tusk")) do
		local c, s = t.Position, t.Size
		t:Destroy()
		table.insert(U.Teeth, M.frustumN(6, 0.08, s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, CFrame.new(c.X, 0, c.Z), { JUNGLE.teeth, H.scaled(JUNGLE.teeth, 0.92) }))
	end
	-- braziers: stone drums on a plinth, a gold band, a flared gold bowl with a rim (the embers kept)
	for _, st in ipairs(each("BrazierStem")) do
		toCollision(st)
		local c = st.Position
		local cf = CFrame.new(c.X, 0, c.Z)
		table.insert(U.Carving, H.chamfered(Vector3.new(3.2, 0.8, 3.2), CFrame.new(c.X, 0.4, c.Z), PAL.STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.25))
		table.insert(U.Stone, M.frustumN(8, 1.15, 0.95, 0.8, 4.6, cf, { PAL.STONE, PAL.STONE_MID }))
		table.insert(U.GoldDark, M.frustumN(8, 1.12, 1.12, 3.9, 4.4, cf, { JUNGLE.goldDark }))
	end
	for _, bw in ipairs(each("BrazierBowl")) do
		toCollision(bw)
		local c = bw.Position
		local cf = CFrame.new(c.X, 0, c.Z)
		table.insert(U.Gold, M.frustumN(8, 1.2, 2.3, 4.6, 6.2, cf, { JUNGLE.gold, H.scaled(JUNGLE.gold, 0.9) }))
		table.insert(U.GoldDark, M.frustumN(8, 2.4, 2.4, 6.05, 6.35, cf, { JUNGLE.goldDark }))
	end
	-- the step: jointed slabs
	local step = m:FindFirstChild("Step") :: BasePart
	if step then
		toCollision(step)
		local c, s = step.Position, step.Size
		local n = 5
		for k = 0, n - 1 do
			local w = s.X / n
			table.insert(U.Carving, H.chamfered(Vector3.new(w - 0.15, s.Y, s.Z), CFrame.new(c.X - s.X / 2 + (k + 0.5) * w, c.Y, c.Z), H.scaled(PAL.STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.15))
		end
	end
	-- moss on the lintel, drapes over its front edge, vine strands down the pillars, moss at the pillar feet
	local lt = lintel.Position.Y + lintel.Size.Y / 2 + 0.7
	local lz = lintel.Position.Z - lintel.Size.Z / 2 - 0.5
	J.mossPatch(U.Moss, rng, CFrame.new(-14, lt, lintel.Position.Z), 10, 4.5, 1.6)
	J.mossPatch(U.Moss, rng, CFrame.new(15, lt, lintel.Position.Z), 6, 3.5, 1.4)
	J.mossFacet(U, "C", Vector3.new(-15, lt, lz), FRONT, 2.4)
	J.mossFacet(U, "A", Vector3.new(14, lt, lz), FRONT, 2.0)
	J.vineFacets(U, Vector3.new(-19.5, 36, -3.4), FRONT, Vector3.xAxis, { 1.6, 1.1 })
	J.vineFacets(U, Vector3.new(19, 36, -3.4), FRONT, Vector3.xAxis, { 1.2, 1.7, 0.9 })
	for _, sx in ipairs({ -1, 1 }) do
		J.mossPatch(U.Moss, rng, CFrame.new(sx * 19.5, 1.6, -3.1), 5, 1.2, 1.2)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: jungle stone temple recipe + carved gold doors and face, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 12 JUNGLE ARENA DOOR (jungle_gate_door, ServerStorage.BossArenas.Jungle.Door; the preview shows its plain grey back):
-- the jungle stone door recipe on the outer face: a carved stone frame of quoins with joints, a lintel of voussoirs
-- with a small proud keystone (a carved diamond), a double stone door (two leaves with carved frame lines, a diamond and
-- a band, a dark seam), moss at the foot and on the top, drapes and vine hangings; on the arena face the jambs and
-- the lintel get cut stone faces and the gold bands rivets (the gold panel and its glowing glyphs kept). Every part of
-- today stays (no collision change); BossService fades / unblocks the new parts with the door.
---------------------------------------------------------------------
function P.jungleArenaDoor(): string
	local id = "jungle_gate_door"
	local H = lib().H
	local J = jlib().J
	local PAL = J.PALETTE
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(1212)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Carving = {}, Gold = {}, Moss = {} }
	local BACK = Vector3.new(0, 0, -1)
	local backing = m:FindFirstChild("Backing") :: BasePart
	assert(backing, "Backing missing")
	local bc, bs = backing.Position, backing.Size
	local x0, x1, y0, y1 = bc.X - bs.X / 2, bc.X + bs.X / 2, bc.Y - bs.Y / 2, bc.Y + bs.Y / 2
	local zf = bc.Z - bs.Z / 2 -- the outer face (looks -Z)
	local fw = 4 -- frame width
	-- the frame: quoins up both sides (alternating long / short), 9 courses
	local n = 9
	local ch = (y1 - 4 - y0) / n
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, n - 1 do
			local w = if k % 2 == 0 then fw else fw - 0.9
			local cx = if sx < 0 then x0 + w / 2 else x1 - w / 2
			table.insert(U.Stone, H.chamfered(Vector3.new(w - 0.1, ch - 0.1, 0.8), CFrame.new(cx, y0 + (k + 0.5) * ch, zf - 0.4), H.scaled(PAL.STONE, H.TONES[H.toneIndex(rng, nil)]), { "frontFace", "vertical" }, 0.18))
		end
	end
	-- the lintel: 5 voussoirs over the leaves and the corners, a proud keystone with a carved diamond
	local ly0 = y1 - 4
	local xs = { x0, x0 + 6, x0 + 12.4, x1 - 12.4, x1 - 6, x1 }
	for k = 1, 5 do
		local a, b = xs[k], xs[k + 1]
		if k ~= 3 then
			table.insert(U.Stone, H.chamfered(Vector3.new(b - a - 0.1, 3.9, 0.8), CFrame.new((a + b) / 2, ly0 + 2, zf - 0.4), H.scaled(PAL.STONE, H.TONES[H.toneIndex(rng, nil)]), { "frontFace", "vertical" }, 0.2))
		end
	end
	local kw = xs[4] - xs[3]
	table.insert(U.Carving, H.chamfered(Vector3.new(kw - 0.1, 4.6, 1.3), CFrame.new(0, ly0 + 2.1, zf - 0.65), H.scaled(PAL.STONE_DARK, 1.12), { "frontFace", "vertical", "topFrontBack" }, 0.25))
	table.insert(U.Carving, H.piece("Part", Vector3.new(1.3, 1.3, 0.12), CFrame.new(0, ly0 + 2.1, zf - 1.33) * CFrame.Angles(0, 0, math.rad(45)), PAL.RECESS))
	-- the double stone door: two leaves with carved lines, a dark seam
	local lx0, lx1 = x0 + fw, x1 - fw
	local mid = (lx0 + lx1) / 2
	for _, side in ipairs({ -1, 1 }) do
		local a, b = if side < 0 then lx0 else mid, if side < 0 then mid else lx1
		local w, h = b - a, ly0 - y0
		local cx, cy = (a + b) / 2, (y0 + ly0) / 2
		table.insert(U.Stone, H.chamfered(Vector3.new(w - 0.25, h - 0.2, 0.5), CFrame.new(cx, cy, zf - 0.25), H.scaled(PAL.STONE_MID, rng:NextNumber(0.97, 1.03)), { "frontFace" }, 0.25))
		local z = zf - 0.52
		local ins = 1.1
		local L = { { 0, h / 2 - ins, w - 2 * ins, 0.22 }, { 0, -h / 2 + ins, w - 2 * ins, 0.22 }, { w / 2 - ins, 0, 0.22, h - 2 * ins }, { -w / 2 + ins, 0, 0.22, h - 2 * ins }, { 0, -1.5, w - 2 * ins, 0.22 } }
		for _, e in ipairs(L) do
			table.insert(U.Carving, H.piece("Part", Vector3.new(e[3], e[4], 0.06), CFrame.new(cx + e[1], cy + e[2], z), PAL.RECESS))
		end
		-- a carved diamond in the upper field, a band of 3 small squares in the lower one
		local dc = CFrame.new(cx, cy + h / 4, z) * CFrame.Angles(0, 0, math.rad(45))
		for _, e in ipairs({ { 0, 1.4, 3.0, 0.2 }, { 0, -1.4, 3.0, 0.2 }, { 1.4, 0, 0.2, 3.0 }, { -1.4, 0, 0.2, 3.0 } }) do
			table.insert(U.Carving, H.piece("Part", Vector3.new(e[3], e[4], 0.06), dc * CFrame.new(e[1], e[2], 0), PAL.RECESS))
		end
		for k = -1, 1 do
			table.insert(U.Carving, H.chamfered(Vector3.new(1.2, 1.2, 0.2), CFrame.new(cx + k * 2.2, cy - h / 4 - 0.8, z - 0.05), H.scaled(PAL.STONE_DARK, 1.1), { "frontFace" }, 0.15))
		end
	end
	table.insert(U.Carving, H.piece("Part", Vector3.new(0.3, ly0 - y0, 0.1), CFrame.new(mid, (y0 + ly0) / 2, zf - 0.52), PAL.RECESS))
	-- moss and vines
	J.mossPatch(U.Moss, rng, CFrame.new(-6, y0 + 0.02, zf - 1.4), 6, 1.6, 1.0)
	J.mossPatch(U.Moss, rng, CFrame.new(9, y0 + 0.02, zf - 1.2), 4, 1.2, 0.9)
	J.mossPatch(U.Moss, rng, CFrame.new(-7, y1, bc.Z), 9, 3.2, 1.3)
	J.mossPatch(U.Moss, rng, CFrame.new(8, y1, bc.Z), 5, 2.8, 1.1)
	J.mossFacet(U, "B", Vector3.new(-8, y1, zf - 0.9), BACK, 1.6)
	J.mossFacet(U, "C", Vector3.new(9, y1, zf - 0.9), BACK, 1.3)
	J.vineFacets(U, Vector3.new(-12.6, y1, zf - 0.9), BACK, Vector3.xAxis, { 1.2, 0.8, 1.5 })
	J.vineFacets(U, Vector3.new(12.4, y1, zf - 0.9), BACK, Vector3.xAxis, { 0.9, 1.3 })
	-- the arena face: cut stone over the jambs and the lintel, rivets on the gold bands
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local p, s = c.Position, c.Size
			if c.Name == "Jamb" then
				J.stoneFace(U.Stone, rng, p.X - s.X / 2, p.X + s.X / 2, p.Y - s.Y / 2, 10.5, p.Z + s.Z / 2, false, 2.5, PAL.STONE, nil, 1, 1.2)
			elseif c.Name == "Lintel" then
				J.stoneFace(U.Stone, rng, p.X - s.X / 2, p.X + s.X / 2, p.Y - s.Y / 2, p.Y + s.Y / 2, p.Z + s.Z / 2, false, 2.5, PAL.STONE, nil, 1, 1.5)
			elseif c.Name == "Band" then
				for k = -1, 1 do
					table.insert(U.Gold, H.chamfered(Vector3.new(0.5, 0.5, 0.3), CFrame.new(p.X + k * 3.4, p.Y, p.Z + s.Z / 2 + 0.1), JUNGLE.gold, { "frontFace" }, 0.12))
				end
			end
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: jungle stone door recipe (outer face) + cut stone arena face, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 13 JUNGLE WATERFALL CLIFF (jungle_landmark_waterfall_cliff, Jungle_2): the jungle boulder recipe (natural facets,
-- layered strata, moss caps) for the cliff: every cliff rock becomes a stack of the improved jungle_rock_large boulder
-- (fitted to its box, tapering to the top, each one turned and offset), the ledges / lips / wet rock faceted slabs with moss
-- mounds and drapes; the waterfall in the fountain water look (rippled glassy water on the top pool, the sheet kept
-- with soft flow strands in front, a rounded lip of foam where it falls, foam and a rippled plunge pool at its foot);
-- the 6 flat vine bars become real leafy vines of the same length. Every colliding part of today stays as invisible
-- collision (the rock meshes keep their shapes); the canopies and the cliff core stay as they are.
---------------------------------------------------------------------
function P.waterfallCliff(): string
	local id = "jungle_landmark_waterfall_cliff"
	local H, ST = lib().H, lib().ST
	local J = jlib().J
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local fountain = folder():FindFirstChild("fountain") :: Model
	assert(fountain, "template fountain missing")
	local m = old:Clone()
	local rng = Random.new(1313)
	H.setBevelSelf(true)
	local U: any = { Ledges = {}, Moss = {}, VinesL = {}, VinesR = {}, Flow = {}, Foam = {} }
	local FRONT = Vector3.new(0, 0, -1)
	local rocks = {}
	-- the world half extents of a turned box
	local function half(cf: CFrame, s: Vector3): Vector3
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		return Vector3.new(math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z, math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z, math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
	end
	local sheet = nil
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local n = c.Name
			if n == "CliffRock" then
				table.insert(rocks, { cf = c.CFrame, size = c.Size, color = c.Color })
				toCollision(c)
			elseif n == "Ledge" or n == "Lip" or n == "WetRock" then
				local cf, s, col = c.CFrame, c.Size, c.Color
				toCollision(c)
				-- two faceted slabs (the lower one a little wider), moss on the ledges
				strataSlab(U.Ledges, rng, cf * CFrame.new(0, -s.Y * 0.22, 0), Vector3.new(s.X * 1.02, s.Y * 0.58, s.Z * 1.02), H.scaled(col, 0.95))
				strataSlab(U.Ledges, rng, cf * CFrame.new(0, s.Y * 0.28, 0), Vector3.new(s.X * 0.92, s.Y * 0.46, s.Z * 0.92), col)
				if n == "Ledge" then
					local e = half(cf, s)
					J.mossPatch(U.Moss, rng, CFrame.new(cf.Position + Vector3.new(0, e.Y + 0.05, 0)), e.X * 1.4, e.Z * 1.2, 2.4)
					J.mossFacet(U, "C", cf.Position + Vector3.new(0, e.Y, -e.Z + 0.6), FRONT, 2.6)
				end
			elseif n == "LedgeMoss" or n == "Vine" or n == "TopWater" then
				if n == "Vine" then
					local top = c.Position + Vector3.new(0, c.Size.Y / 2, 0)
					J.vine(if c.Position.X < 0 then U.VinesL else U.VinesR, rng, top, FRONT, c.Size.Y)
				elseif n == "TopWater" then
					-- the top pool in the fountain water (rippled glass)
					local w = (fountain:FindFirstChild("UpperWater") :: MeshPart):Clone()
					w.Size = Vector3.new(c.Size.X, w.Size.Y, c.Size.Z)
					w.CFrame = CFrame.new(c.Position + Vector3.new(0, c.Size.Y / 2 + 0.02, 0))
					w.Name = "TopWater"
					w.CanCollide, w.CanTouch, w.CanQuery = false, false, false
					w.Parent = m
				end
				c:Destroy()
			elseif n == "WaterSheet" then
				sheet = c
			elseif n == "CliffCore" then
				-- (the flat grey back slab showed above / beside the boulders: it stays the collider, unseen)
				c.Transparency = 1
				c.CastShadow = false
			end
		end
	end
	-- the cliff rocks: the improved jungle boulder (jungle_rock_large: faceted layered stone, a moss cap) duplicated
	-- and stacked in each rock's box (local Y = up), 3-5 per rock, each turned half a turn from the one below,
	-- tapering and a little offset; the top one carries the boulder's moss cap
	local boulder = folder():FindFirstChild("jungle_rock_large") :: Model
	assert(boulder, "template jungle_rock_large missing")
	local bStone = boulder:FindFirstChild("Stone") :: BasePart
	local bMoss = boulder:FindFirstChild("Moss") :: BasePart
	assert(bStone and bMoss, "jungle_rock_large Stone / Moss missing")
	local sBox, sSize = bStone.ExtentsCFrame, bStone.ExtentsSize
	local mRel = sBox:PointToObjectSpace(bMoss.ExtentsCFrame.Position)
	local mSize = bMoss.ExtentsSize
	table.sort(rocks, function(a: any, b: any): boolean
		return a.cf.X < b.cf.X
	end)
	for _, r in ipairs(rocks) do
		local s = r.size
		local n = math.clamp(math.round(s.Y / 20), 3, 5)
		local h = s.Y / n
		for layer = 0, n - 1 do
			local f = 0.98 - 0.16 * layer / (n - 1)
			local off = Vector3.new(rng:NextNumber(-0.05, 0.05) * s.X, -s.Y / 2 + (layer + 0.5) * h, rng:NextNumber(-0.05, 0.05) * s.Z)
			local box = r.cf * CFrame.new(off) * CFrame.Angles(0, (layer % 2) * math.pi + rng:NextNumber(-0.12, 0.12), 0)
			local size = Vector3.new(s.X * f * rng:NextNumber(0.95, 1.05), h * 1.12, s.Z * f * rng:NextNumber(0.95, 1.05))
			fitInto(bStone, m, box, size, "Rock")
			if layer == n - 1 then
				local k = Vector3.new(size.X / sSize.X, size.Y / sSize.Y, size.Z / sSize.Z)
				fitInto(bMoss, m, box * CFrame.new(mRel * k), mSize * k, "RockMoss")
			end
		end
	end
	-- the waterfall: the sheet kept, soft flow strands, a rounded foam lip at the top, foam and a plunge pool below
	if sheet then
		local c, s = sheet.Position, sheet.ExtentsSize
		local wide = math.max(s.X, s.Z)
		local zf = c.Z - math.min(s.X, s.Z) / 2
		local y0, y1 = c.Y - s.Y / 2, c.Y + s.Y / 2
		for j = 1, 6 do
			local w = rng:NextNumber(1.2, 2.6)
			local x = c.X + (j - 3.5) / 3 * (wide / 2 - 1.6) + rng:NextNumber(-0.4, 0.4)
			local top = y1 - rng:NextNumber(0, 2)
			table.insert(U.Flow, H.piece("Part", Vector3.new(w, top - y0, 0.25), CFrame.new(x, (top + y0) / 2, zf - 0.2 - (j % 3) * 0.12), rgb(206, 244, 248)))
		end
		table.insert(U.Foam, H.piece("Part", Vector3.new(wide + 1, 2.2, 2.2), CFrame.new(c.X, y1 - 0.6, zf - 0.4), rgb(245, 246, 250), { shape = Enum.PartType.Cylinder }))
		for j = 1, 7 do
			local a = (j - 4) * 0.42
			local at = Vector3.new(c.X + math.sin(a) * wide * 0.55, y0 + 0.5, zf - 2.6 - math.cos(a) * 2.2)
			ST.blob(U.Foam, rng, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(2.6, 4), rng:NextNumber(1.1, 1.8), rng:NextNumber(2.2, 3.2), function(_n: Vector3): Color3
				return rgb(245, 246, 250)
			end, 0.6)
		end
		local pool = (fountain:FindFirstChild("LowerWater") :: MeshPart):Clone()
		pool.Size = Vector3.new(wide + 8, pool.Size.Y, 11)
		pool.CFrame = CFrame.new(c.X, y0 + 0.2, zf - 5.6)
		pool.Name = "PlungePool"
		pool.CanCollide, pool.CanTouch, pool.CanQuery = false, false, false
		pool.Parent = m
	end
	for key, v in pairs(U) do
		if #v == 0 then
			U[key] = nil
		end
	end
	mergeAll(m, U, { Flow = { transparency = 0.5 }, Foam = { transparency = 0.15 }, Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: stacked improved jungle boulders, moss caps, leafy vines, fountain-look waterfall; %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 14 JUNGLE GOLDEN IDOL (jungle_landmark_golden_idol, the Jungle boss arena): the golden guardian / totem recipe
-- (rounded bevelled gold, dark-gold bands with studs, gems, carved stone): a seated idol with a rounded torso, a belly
-- plate, pectorals and a jewelled collar, a belt with a gem buckle, rounded pauldrons, octagonal arms bending down to
-- hands resting on the knees, rounded thighs with knee caps and feet, a rounded head with a heavy carved brow, a muzzle
-- with a nose, tapered fangs, eye sockets round the cyan eyes (kept), ears with gold rings, a jewelled crown band with
-- tapered spikes and a fan of feathers; the base as cut jungle stone with a bevelled gold trim and studs round the
-- glowing glyph (kept). Every colliding part of today stays as invisible collision (the old fists and straight arms
-- stay as colliders where the new arms bend to the knees).
---------------------------------------------------------------------
function P.goldenIdol(): string
	local id = "jungle_landmark_golden_idol"
	local H = lib().H
	local L = jlib()
	local J, M = L.J, L.M
	local PAL = J.PALETTE
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(1414)
	H.setBevelSelf(true)
	local GOLD, DARK, GEM, TEETH = JUNGLE.gold, JUNGLE.goldDark, rgb(64, 208, 196), JUNGLE.teeth
	local U: any = { Stone = {}, Carving = {}, Gold = {}, GoldDark = {}, Gems = {}, Teeth = {}, Feathers = {} }
	local ALL = { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }
	local P0: any = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			P0[c.Name] = P0[c.Name] or {}
			table.insert(P0[c.Name], { part = c, cf = c.CFrame, size = c.Size, pos = c.Position })
			if c.CanCollide then
				toCollision(c)
			end
		end
	end
	local function one(name: string): any
		return (P0[name] or {})[1]
	end
	local function limb(list: { BasePart }, a: Vector3, b: Vector3, r0: number, r1: number, colors: { Color3 })
		local d = b - a
		table.insert(list, M.frustumN(8, r0, r1, 0, d.Magnitude, H.frameY(a, d), colors))
	end
	-- the base: cut stone faces (the glyph left free), a bevelled core, a gold trim with studs
	local ped, trim, glyph = one("Pedestal"), one("PedestalTrim"), one("PedestalGlyph")
	if ped then
		local c, s = ped.pos, ped.size
		table.insert(U.Carving, H.chamfered(s - Vector3.new(0.2, 0, 0.2), ped.cf, PAL.STONE_DARK, { "vertical" }, 0.6))
		local gy = if glyph then glyph.pos.Y else -100
		local function skip(x: number, y: number): boolean
			return glyph ~= nil and math.abs(x - glyph.pos.X) < glyph.size.X / 2 + 1.2 and math.abs(y - gy) < glyph.size.Y / 2 + 0.9
		end
		J.stoneFace(U.Stone, rng, c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z - s.Z / 2, true, 2.0, PAL.STONE, skip, 2, 1.6)
		J.stoneFace(U.Stone, rng, c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z + s.Z / 2, false, 2.0, PAL.STONE, nil, 1, 1.6)
		if glyph then
			for _, e in ipairs({ { 0, glyph.size.Y / 2 + 0.35, glyph.size.X + 1.4, 0.7 }, { 0, -glyph.size.Y / 2 - 0.35, glyph.size.X + 1.4, 0.7 }, { glyph.size.X / 2 + 0.35, 0, 0.7, glyph.size.Y }, { -glyph.size.X / 2 - 0.35, 0, 0.7, glyph.size.Y } }) do
				table.insert(U.GoldDark, H.chamfered(Vector3.new(e[3], e[4], 0.6), CFrame.new(glyph.pos.X + e[1], gy + e[2], c.Z - s.Z / 2 - 0.15), DARK, { "frontFace" }, 0.2))
			end
		end
	end
	if trim then
		local c, s = trim.pos, trim.size
		table.insert(U.Gold, H.chamfered(s, trim.cf, GOLD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.4))
		for k = -6, 6 do
			table.insert(U.GoldDark, H.piece("Part", Vector3.new(0.7, 0.7, 0.3), CFrame.new(c.X + k * s.X / 13.5, c.Y, c.Z - s.Z / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(45)), DARK))
		end
	end
	-- the torso, belly, pectorals, collar and belt
	local torso = one("Torso")
	if torso then
		local c, s = torso.pos, torso.size
		table.insert(U.Gold, H.chamfered(s, torso.cf, GOLD, ALL, 3.0))
		-- belt with a gem buckle
		table.insert(U.GoldDark, H.chamfered(Vector3.new(s.X + 0.4, 1.8, s.Z + 0.4), CFrame.new(c.X, c.Y - s.Y / 2 + 1.6, c.Z), DARK, { "vertical" }, 2.8))
		table.insert(U.Gold, H.chamfered(Vector3.new(3.4, 3.0, 0.8), CFrame.new(c.X, c.Y - s.Y / 2 + 1.6, c.Z - s.Z / 2 - 0.3), GOLD, { "frontFace" }, 0.5))
		table.insert(U.Gems, H.piece("Part", Vector3.new(1.4, 1.4, 0.5), CFrame.new(c.X, c.Y - s.Y / 2 + 1.6, c.Z - s.Z / 2 - 0.65) * CFrame.Angles(0, 0, math.rad(45)), GEM))
		-- the collar: an arc of 7 dark-gold plates with gems under the neck
		for k = -3, 3 do
			local a = k * 0.32
			local p = Vector3.new(c.X + math.sin(a) * 7.5, c.Y + s.Y / 2 - 1.0 + (1 - math.cos(a)) * 0.8, c.Z - s.Z / 2 - 1.5 + (1 - math.cos(a)) * 1.4)
			table.insert(U.GoldDark, H.chamfered(Vector3.new(2.2, 2.4, 0.7), CFrame.new(p) * CFrame.Angles(0, -a * 0.6, a * 0.5), DARK, { "frontFace" }, 0.35))
			if k % 2 == 0 then
				table.insert(U.Gems, H.piece("Part", Vector3.new(0.8, 0.8, 0.4), CFrame.new(p + Vector3.new(0, -0.2, -0.45)) * CFrame.Angles(0, 0, math.rad(45)), GEM))
			end
		end
	end
	local belly = one("Belly")
	if belly then
		table.insert(U.GoldDark, H.chamfered(belly.size, belly.cf, DARK, ALL, 1.2))
		table.insert(U.Gold, H.chamfered(Vector3.new(belly.size.X - 4, 0.6, 0.6), belly.cf * CFrame.new(0, 0, -belly.size.Z / 2 - 0.1), GOLD, { "frontFace" }, 0.2))
	end
	for _, ch in ipairs(P0.Chest or {}) do
		table.insert(U.GoldDark, H.chamfered(ch.size, ch.cf, DARK, ALL, 0.6))
	end
	-- pauldrons with a studded band
	for _, sh in ipairs(P0.Shoulder or {}) do
		local c, s = sh.pos, sh.size
		table.insert(U.GoldDark, H.chamfered(s, sh.cf, DARK, ALL, 2.6))
		table.insert(U.Gold, H.chamfered(Vector3.new(s.X + 0.3, 1.2, s.Z + 0.3), CFrame.new(c.X, c.Y - s.Y / 2 + 1.4, c.Z), GOLD, { "vertical" }, 2.4))
		for k = -1, 1 do
			table.insert(U.Gems, H.piece("Part", Vector3.new(0.8, 0.8, 0.5), CFrame.new(c.X + k * 3, c.Y - s.Y / 2 + 1.4, c.Z - s.Z / 2 - 0.35) * CFrame.Angles(0, 0, math.rad(45)), GEM))
		end
	end
	-- the arms bend down to hands resting on the knees; thighs, knee caps and feet
	for _, sx in ipairs({ -1, 1 }) do
		local shoulder = Vector3.new(sx * 15.5, 27, 1.5)
		local elbow = Vector3.new(sx * 17.2, 18, -1)
		local wrist = Vector3.new(sx * 13.6, 16.2, -9)
		limb(U.Gold, shoulder, elbow, 3.7, 3.3, { GOLD, H.scaled(GOLD, 0.94) })
		limb(U.Gold, elbow, wrist, 3.2, 2.6, { GOLD, H.scaled(GOLD, 0.94) })
		table.insert(U.GoldDark, M.frustumN(8, 3.5, 3.5, -0.8, 0.8, H.frameY(elbow, wrist - elbow), { DARK }))
		table.insert(U.GoldDark, M.frustumN(8, 2.9, 2.9, 0, 1.4, H.frameY(wrist - (wrist - elbow).Unit * 2.6, wrist - elbow), { DARK }))
		-- the hand on the knee: a palm and 4 fingers over the knee's front
		table.insert(U.Gold, H.chamfered(Vector3.new(5.2, 2.2, 5.2), CFrame.new(sx * 12.8, 15.9, -11), GOLD, ALL, 0.7))
		for f = 0, 3 do
			table.insert(U.Gold, H.chamfered(Vector3.new(1.05, 1.5, 2.8), CFrame.new(sx * (11.0 + f * 1.2), 15.4, -14.1) * CFrame.Angles(math.rad(-25), 0, 0), H.scaled(GOLD, 0.96), ALL, 0.35))
		end
	end
	for _, leg in ipairs(P0.Leg or {}) do
		local c, s = leg.pos, leg.size
		table.insert(U.GoldDark, H.chamfered(s - Vector3.new(0.2, 0.2, 0.2), leg.cf, DARK, ALL, 2.4))
		table.insert(U.Gold, H.chamfered(Vector3.new(s.X + 0.4, s.Y + 0.4, 3.4), CFrame.new(c.X, c.Y, c.Z - s.Z / 2 + 1.2), GOLD, ALL, 1.4))
		table.insert(U.Gold, H.chamfered(Vector3.new(s.X + 0.5, 1.2, 1.4), CFrame.new(c.X, c.Y - s.Y / 2 + 1.6, c.Z - s.Z / 2 + 3.4), DARK, { "vertical" }, 0.5))
		-- a foot with 3 toes in front of the shin
		table.insert(U.Gold, H.chamfered(Vector3.new(6, 2.2, 3), CFrame.new(c.X, c.Y - s.Y / 2 + 1.1, c.Z - s.Z / 2 - 1.2), GOLD, ALL, 0.8))
		for t = -1, 1 do
			table.insert(U.Gold, H.chamfered(Vector3.new(1.6, 1.4, 1.2), CFrame.new(c.X + t * 1.8, c.Y - s.Y / 2 + 0.7, c.Z - s.Z / 2 - 3.1), H.scaled(GOLD, 0.95), ALL, 0.4))
		end
	end
	-- the head: rounded, a heavy carved brow, a muzzle with a nose, fangs, eye sockets, ears with rings
	local head = one("Head")
	if head then
		table.insert(U.Gold, H.chamfered(head.size, head.cf, GOLD, ALL, 2.6))
	end
	local brow = one("Brow")
	if brow then
		local c, s = brow.pos, brow.size
		table.insert(U.GoldDark, H.chamfered(s, brow.cf, DARK, ALL, 1.0))
		table.insert(U.Carving, H.piece("Part", Vector3.new(s.X - 2, 0.25, 0.2), CFrame.new(c.X, c.Y - 0.2, c.Z - s.Z / 2 - 0.05), PAL.RECESS))
		table.insert(U.Gems, H.piece("Part", Vector3.new(1.4, 1.4, 0.5), CFrame.new(c.X, c.Y + 0.4, c.Z - s.Z / 2 - 0.2) * CFrame.Angles(0, 0, math.rad(45)), GEM))
	end
	local muzzle = one("Muzzle")
	if muzzle then
		local c, s = muzzle.pos, muzzle.size
		table.insert(U.GoldDark, H.chamfered(s, muzzle.cf, DARK, ALL, 1.4))
		table.insert(U.GoldDark, H.chamfered(Vector3.new(3.2, 2.0, 1.6), CFrame.new(c.X, c.Y + 1.6, c.Z - s.Z / 2 - 0.4), H.scaled(DARK, 1.06), ALL, 0.6))
	end
	for _, f in ipairs(P0.Fang or {}) do
		local c, s = f.pos, f.size
		f.part:Destroy()
		table.insert(U.Teeth, M.frustumN(6, 0.08, s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, CFrame.new(c.X, 0, c.Z), { TEETH, H.scaled(TEETH, 0.92) }))
	end
	for _, e in ipairs(P0.Eye or {}) do
		table.insert(U.Carving, H.piece("Part", Vector3.new(e.size.X + 0.9, e.size.Y + 0.9, 0.3), CFrame.new(e.pos.X, e.pos.Y, e.pos.Z + 0.15), PAL.RECESS))
	end
	for _, ear in ipairs(P0.Ear or {}) do
		local c, s = ear.pos, ear.size
		table.insert(U.GoldDark, H.chamfered(s, ear.cf, DARK, ALL, 0.8))
		local sx = if c.X < 0 then -1 else 1
		table.insert(U.Gold, M.frustumN(8, 1.1, 1.1, -0.25, 0.25, CFrame.new(c.X + sx * (s.X / 2 + 0.3), c.Y - s.Y / 2 - 0.6, c.Z) * CFrame.Angles(0, 0, math.rad(90)), { GOLD }))
		table.insert(U.Gems, H.piece("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(c.X + sx * (s.X / 2 + 0.3), c.Y - s.Y / 2 - 1.7, c.Z) * CFrame.Angles(0, 0, math.rad(45)), GEM))
	end
	-- the headdress: a jewelled crown band, tapered spikes, a fan of feathers behind
	local crown = one("CrownBase")
	if crown then
		local c, s = crown.pos, crown.size
		table.insert(U.GoldDark, H.chamfered(s, crown.cf, DARK, ALL, 1.0))
		table.insert(U.Gold, H.chamfered(Vector3.new(s.X + 0.4, 0.8, s.Z + 0.4), CFrame.new(c.X, c.Y - s.Y / 2 + 0.5, c.Z), GOLD, { "vertical" }, 0.8))
		for k = -2, 2 do
			table.insert(U.Gems, H.piece("Part", Vector3.new(0.9, 0.9, 0.4), CFrame.new(c.X + k * 2.3, c.Y + 0.3, c.Z - s.Z / 2 - 0.15) * CFrame.Angles(0, 0, math.rad(45)), GEM))
		end
		for k = -3, 3 do
			local a = k * 0.36
			local len = 5.6 - math.abs(k) * 0.5
			local base = Vector3.new(c.X + math.sin(a) * 3, c.Y + 0.8, c.Z + s.Z / 2 - 1.2)
			local dir = Vector3.new(math.sin(a), math.cos(a), 0.18)
			table.insert(U.Feathers, M.frustumN(4, 1.0, 0.25, 0, len, H.frameY(base, dir), { if k % 2 == 0 then GEM else H.scaled(GEM, 0.8), GOLD }))
		end
	end
	for _, sp in ipairs(P0.CrownSpike or {}) do
		local c, s = sp.pos, sp.size
		table.insert(U.Gold, M.frustumN(4, s.X / 2 * 1.2, 0.15, c.Y - s.Y / 2, c.Y + s.Y / 2, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, math.rad(45), 0), { GOLD, H.scaled(GOLD, 0.92) }))
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: carved seated golden idol on cut stone, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 16 JUNGLE STEP PYRAMID (jungle_landmark_step_pyramid, Jungle_3): the jungle temple recipe (PropsJungleBuildings cut
-- stone): every tier faced with cut stone blocks in running bond (front, sides and back; the tier itself the dark
-- mortar core), bevelled cap stones on every step, the shrine faced too with a carved doorway (jambs, lintel and a
-- carved glyph stone round the dark door), a carved roof comb, the gold diamond on it in a gold bezel with a gold
-- finial on top, stone frames round the glowing diamonds (kept), moss mounds and drapes where today's flat moss plates
-- were, leafy vines in place of the flat vine bars, improved flower bushes on the front step corners. The passage, the
-- tiers and every collider stay as they are (the caps as invisible collision under their bevelled copies).
---------------------------------------------------------------------
function P.stepPyramid(): string
	local id = "jungle_landmark_step_pyramid"
	local H = lib().H
	local J = jlib().J
	local PAL = J.PALETTE
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(1616)
	H.setBevelSelf(true)
	local U: any = { Caps = {}, Carving = {}, Gold = {}, Moss = {}, Vines = {} }
	local FRONT = Vector3.new(0, 0, -1)
	local ROT_PX, ROT_NX = CFrame.Angles(0, -math.pi / 2, 0), CFrame.Angles(0, math.pi / 2, 0)
	-- a cut stone face; rot turns a front face (looking -Z) to look +X / -X
	local function face(list: { BasePart }, x0: number, x1: number, y0: number, y1: number, zf: number, front: boolean, ch: number, color: Color3, cracks: number, lenMul: number, rot: CFrame?, skip: any?)
		local tmp = {}
		J.stoneFace(tmp, rng, x0, x1, y0, y1, zf, front, ch, color, skip, cracks, lenMul)
		for _, p in ipairs(tmp) do
			if rot then
				p.CFrame = rot * p.CFrame
			end
			table.insert(list, p)
		end
	end
	local tiers, mossPlates, vines, glyphs = {}, {}, {}, {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local n = c.Name
			if n == "Tier" or n == "Shrine" then
				table.insert(tiers, c)
			elseif n == "TierTrim" or n == "ShrineRoof" then
				local cf, s = c.CFrame, c.Size
				toCollision(c)
				table.insert(U.Caps, H.chamfered(s, cf, H.scaled(PAL.STONE_DARK, rng:NextNumber(0.98, 1.06)), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.4))
			elseif n == "Moss" then
				table.insert(mossPlates, { pos = c.Position, size = c.Size })
				c:Destroy()
			elseif n == "Vine" then
				table.insert(vines, { pos = c.Position, size = c.Size })
				c:Destroy()
			elseif n == "Glyph" then
				table.insert(glyphs, c)
			end
		end
	end
	table.sort(tiers, function(a: BasePart, b: BasePart): boolean
		if math.abs(a.Position.Y - b.Position.Y) > 0.5 then
			return a.Position.Y < b.Position.Y
		end
		return a.Position.X < b.Position.X
	end)
	local door = m:FindFirstChild("ShrineDoor") :: BasePart
	for i, t in ipairs(tiers) do
		local list = {}
		U["Stone" .. i] = list
		local c, s = t.Position, t.Size
		local x0, x1, y0, y1, z0, z1 = c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
		local color = t.Color
		t.Color = PAL.STONE_DARK -- (the core shows as mortar in the joints)
		local skip = nil
		if t.Name == "Shrine" and door then
			local dp, ds = door.Position, door.Size
			skip = function(x: number, y: number): boolean
				return math.abs(x - dp.X) < ds.X / 2 + 1.6 and y < dp.Y + ds.Y / 2 + 1.8
			end
		end
		face(list, x0, x1, y0, y1, z0, true, 2.8, color, 2, 2, nil, skip)
		face(list, x0, x1, y0, y1, z1, false, 4.6, color, 0, 3)
		-- the sides: both on a full tier, only the outer one on a half (the inner one is the passage wall)
		local half = math.abs(c.X) > 1
		if not half or c.X > 0 then
			face(list, z0, z1, y0, y1, -x1, true, 3.5, color, 1, 2.5, ROT_PX)
		end
		if not half or c.X < 0 then
			face(list, -z1, -z0, y0, y1, x0, true, 3.5, color, 1, 2.5, ROT_NX)
		end
		task.wait()
	end
	-- the shrine doorway: jambs, a lintel, a carved glyph stone
	if door then
		local dp, ds = door.Position, door.Size
		local zf = dp.Z - ds.Z / 2 - 0.3
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Carving, H.chamfered(Vector3.new(1.5, ds.Y + 0.6, 1.4), CFrame.new(dp.X + sx * (ds.X / 2 + 0.75), dp.Y + 0.3, zf), H.scaled(PAL.STONE_DARK, 1.1), { "frontFace", "vertical" }, 0.3))
		end
		table.insert(U.Carving, H.chamfered(Vector3.new(ds.X + 3.4, 1.6, 1.6), CFrame.new(dp.X, dp.Y + ds.Y / 2 + 1.2, zf - 0.1), H.scaled(PAL.STONE_DARK, 1.15), { "frontFace", "vertical", "topFrontBack" }, 0.35))
		table.insert(U.Carving, H.chamfered(Vector3.new(3.4, 1.4, 0.6), CFrame.new(dp.X, dp.Y + ds.Y / 2 + 2.6, zf + 0.2), H.scaled(PAL.STONE, 1.05), { "frontFace" }, 0.2))
		table.insert(U.Carving, H.piece("Part", Vector3.new(0.9, 0.9, 0.1), CFrame.new(dp.X, dp.Y + ds.Y / 2 + 2.6, zf - 0.12) * CFrame.Angles(0, 0, math.rad(45)), PAL.RECESS))
	end
	-- the roof comb carved, the gold diamond in a bezel, a gold finial on top
	local comb = m:FindFirstChild("RoofComb") :: BasePart
	if comb then
		local c, s = comb.Position, comb.Size
		table.insert(U.Caps, H.chamfered(s + Vector3.new(0.1, 0, 0.1), comb.CFrame, PAL.STONE, { "vertical", "topFrontBack", "topSides" }, 0.4))
		for k = -1, 1, 2 do
			table.insert(U.Carving, H.piece("Part", Vector3.new(1.2, 2.2, 0.12), CFrame.new(c.X + k * 4, c.Y, c.Z - s.Z / 2 - 0.08), PAL.RECESS))
		end
		local M = jlib().M
		table.insert(U.Gold, M.frustumN(4, 1.3, 0.15, c.Y + s.Y / 2, c.Y + s.Y / 2 + 1.6, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, math.rad(45), 0), { JUNGLE.gold, JUNGLE.goldDark }))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Gold, H.piece("Part", Vector3.new(1.2, 1.2, 1.2), CFrame.new(c.X + sx * (s.X / 2 - 0.6), c.Y + s.Y / 2 + 0.6, c.Z), JUNGLE.gold, { shape = Enum.PartType.Ball }))
		end
	end
	local cap = m:FindFirstChild("GoldCap") :: BasePart
	if cap then
		diamondBezel(U.Gold, cap.CFrame * CFrame.new(0, 0, -0.05), cap.Size.X, 0.5, cap.Size.Z + 0.2, JUNGLE.goldDark)
	end
	-- stone frames round the glowing diamonds (kept)
	for _, g in ipairs(glyphs) do
		diamondBezel(U.Carving, g.CFrame * CFrame.new(0, 0, -0.05), g.Size.X, 0.6, g.Size.Z + 0.3, H.scaled(PAL.STONE_DARK, 0.9))
	end
	-- moss where the flat plates were: mounds on the step above, a drape over the edge
	local variants = { "A", "B", "C" }
	for i, mp in ipairs(mossPlates) do
		local p, s = mp.pos, mp.size
		local edgeY, frontZ = p.Y + s.Y / 2, p.Z + 0.3
		for _, t in ipairs(tiers) do
			local tc, ts = t.Position, t.Size
			if math.abs((tc.Z - ts.Z / 2) - frontZ) < 0.8 and math.abs(p.X - tc.X) < ts.X / 2 then
				edgeY = tc.Y + ts.Y / 2 + 0.1
			end
		end
		J.mossPatch(U.Moss, rng, CFrame.new(p.X, edgeY, frontZ + 1.0), s.X, 3, 1.6)
		J.mossFacet(U, variants[i % 3 + 1], Vector3.new(p.X, edgeY, frontZ - 1.85), FRONT, math.clamp(s.X / 4, 1.6, 3.4))
	end
	for _, v in ipairs(vines) do
		local top = v.pos + Vector3.new(0, v.size.Y / 2, -0.25)
		J.vine(U.Vines, rng, top, FRONT, v.size.Y)
	end
	-- improved flower bushes on the front corners of the two lowest steps
	local bush = folder():FindFirstChild("jungle_flower_bush")
	if bush then
		for _, spot in ipairs({ Vector3.new(-57, 14.1, -55), Vector3.new(57, 14.1, -55), Vector3.new(-47, 28.1, -45), Vector3.new(47, 28.1, -45) }) do
			local b = cleanClone("jungle_flower_bush")
			b:ScaleTo(0.8)
			b:PivotTo(CFrame.new(b:GetPivot().Position) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			standAt(b, spot)
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
				end
			end
			b.Name = "Bush"
			b.Parent = m
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: cut stone tiers, carved doorway, gold finial, moss, vines, bushes; %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 17 JUNGLE RUIN PILLAR A (jungle_statue_ruin_pillar_a, x10 in Jungle_3): the improved jungle broken pillar recipe
-- (carved stone, bands, cracks, moss): a stepped bevelled plinth, an octagonal shaft of 3 drums (offset a little,
-- dark joints, zig-zag cracks), the carved band round the glowing glyph (kept, in a recessed frame), a flared capital
-- under a bevelled abacus, and the green top kept as a moss cap on the abacus with a drape and a vine over the front
-- where today's green plate was. Today's parts stay as invisible collision.
---------------------------------------------------------------------
function P.ruinPillar(): string
	local id = "jungle_statue_ruin_pillar_a"
	local H = lib().H
	local L = jlib()
	local J, M = L.J, L.M
	local PAL = J.PALETTE
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(1717)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Carving = {}, Moss = {} }
	local FRONT = Vector3.new(0, 0, -1)
	local R: any = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			R[c.Name] = { cf = c.CFrame, size = c.Size, pos = c.Position, color = c.Color, part = c }
			if c.CanCollide then
				toCollision(c)
			end
		end
	end
	local base, shaft, band, capital, top, moss, glyph = R.Base, R.Shaft, R.Band, R.Capital, R.Top, R.Moss, R.Glyph
	assert(base and shaft and band and capital and top, "pillar parts missing")
	-- the plinth: two bevelled steps
	do
		local c, s = base.pos, base.size
		table.insert(U.Carving, H.chamfered(Vector3.new(s.X, s.Y * 0.55, s.Z), CFrame.new(c.X, c.Y - s.Y * 0.225, c.Z), PAL.STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.25))
		table.insert(U.Carving, H.chamfered(Vector3.new(s.X - 0.6, s.Y * 0.47, s.Z - 0.6), CFrame.new(c.X, c.Y + s.Y * 0.265, c.Z), H.scaled(PAL.STONE_DARK, 1.08), { "vertical", "topFrontBack", "topSides" }, 0.2))
	end
	-- the shaft: 3 octagonal drums (below and above the band), dark joints, cracks
	local r = shaft.size.X / 2 * 1.06
	local TURN = CFrame.Angles(0, math.rad(22.5), 0) -- (a flat octagon face to the front, under the glyph)
	local y0, y1 = shaft.pos.Y - shaft.size.Y / 2, shaft.pos.Y + shaft.size.Y / 2
	local bandY0, bandY1 = band.pos.Y - band.size.Y / 2, band.pos.Y + band.size.Y / 2
	local cuts = { y0, y0 + (bandY0 - y0) * 0.52, bandY0, bandY1, y1 }
	for k = 1, #cuts - 1 do
		local a, b = cuts[k], cuts[k + 1]
		if not (a == bandY0 and b == bandY1) then
			local off = CFrame.new(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0)
			local tone = H.scaled(shaft.color, rng:NextNumber(0.94, 1.04))
			table.insert(U.Stone, M.frustumN(8, r, r * 0.97, a + 0.06, b - 0.06, CFrame.new(shaft.pos.X, 0, shaft.pos.Z) * TURN * off, { tone, H.scaled(tone, 0.95) }))
			table.insert(U.Carving, M.frustumN(8, r * 0.93, r * 0.93, b - 0.1, b + 0.1, CFrame.new(shaft.pos.X, 0, shaft.pos.Z) * TURN, { PAL.RECESS }))
		end
	end
	for _ = 1, 2 do
		local x, y = rng:NextNumber(-1, 1), rng:NextNumber(y0 + 2, bandY0 - 1)
		local p = Vector2.new(x, y)
		for _ = 1, 3 do
			local q = p + Vector2.new(rng:NextNumber(-0.35, 0.35), -rng:NextNumber(0.4, 0.7))
			local mid, d = (p + q) / 2, q - p
			table.insert(U.Carving, H.piece("Part", Vector3.new(0.09, d.Magnitude + 0.06, 0.05), CFrame.new(shaft.pos.X + mid.X, mid.Y, shaft.pos.Z - r - 0.02) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)), PAL.RECESS))
			p = q
		end
	end
	-- the carved band: an octagonal ring with rims, a recessed frame round the glyph
	do
		local cf = CFrame.new(band.pos.X, 0, band.pos.Z) * TURN
		local rb = band.size.X / 2 * 1.06
		table.insert(U.Carving, M.frustumN(8, rb, rb, bandY0 + 0.25, bandY1 - 0.25, cf, { PAL.STONE_DARK, H.scaled(PAL.STONE_DARK, 1.06) }))
		table.insert(U.Stone, M.frustumN(8, rb + 0.15, rb + 0.15, bandY0, bandY0 + 0.3, cf, { H.scaled(PAL.STONE_DARK, 1.15) }))
		table.insert(U.Stone, M.frustumN(8, rb + 0.15, rb + 0.15, bandY1 - 0.3, bandY1, cf, { H.scaled(PAL.STONE_DARK, 1.15) }))
		if glyph then
			local g = glyph.pos
			for _, e in ipairs({ { 0, glyph.size.Y / 2 + 0.12, glyph.size.X + 0.5, 0.24 }, { 0, -glyph.size.Y / 2 - 0.12, glyph.size.X + 0.5, 0.24 }, { glyph.size.X / 2 + 0.12, 0, 0.24, glyph.size.Y }, { -glyph.size.X / 2 - 0.12, 0, 0.24, glyph.size.Y } }) do
				table.insert(U.Carving, H.piece("Part", Vector3.new(e[3], e[4], 0.3), CFrame.new(g.X + e[1], g.Y + e[2], g.Z + 0.02), PAL.RECESS))
			end
		end
	end
	-- the capital: a flared octagon under a bevelled abacus
	do
		local cy0, cy1 = capital.pos.Y - capital.size.Y / 2, capital.pos.Y + capital.size.Y / 2
		table.insert(U.Carving, M.frustumN(8, r * 1.02, capital.size.X / 2 * 1.08, cy0, cy1, CFrame.new(capital.pos.X, 0, capital.pos.Z) * TURN, { PAL.STONE_DARK, H.scaled(PAL.STONE_DARK, 1.08) }))
		table.insert(U.Stone, H.chamfered(top.size, top.cf, top.color, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.3))
	end
	-- the green top: a moss cap on the abacus, a drape and a vine over the front where today's plate was
	local topY = top.pos.Y + top.size.Y / 2
	J.mossPatch(U.Moss, rng, CFrame.new(top.pos.X, topY, top.pos.Z), top.size.X * 0.85, top.size.Z * 0.8, 1.1)
	local mx = if moss then moss.pos.X else 0
	J.mossFacet(U, "B", Vector3.new(mx, topY, top.pos.Z - top.size.Z / 2 - 0.25), FRONT, 1.3)
	if moss then
		local mp, ms = moss.pos, moss.size
		moss.part:Destroy()
		J.mossDrape(U.Moss, rng, CFrame.new(mp.X, mp.Y + ms.Y / 2 + 0.6, shaft.pos.Z - r - 0.05), ms.X * 0.9, 0.6, ms.Y * 0.9)
		J.vineFacets(U, Vector3.new(mp.X + ms.X / 2 - 0.3, topY - 0.6, top.pos.Z - top.size.Z / 2 - 0.1), FRONT, Vector3.xAxis, { 0.9 })
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: carved drums, band, capital, moss top; %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 19 TUNDRA BOSS GATE (tundra_gate_boss_gate, Tundra_4) and 20 TUNDRA ARENA DOOR (tundra_gate_door, the Tundra boss
-- arena): the improved tundra ice castle gate recipe (PropsTundraGates.iceFace: bevelled ice blocks in running bond over
-- a deep blue core; frosted-glass door frames, frosted panels with frost lines and corner frost, icicles, a faceted ice
-- setting for the gem): jambs and lintel faced with ice blocks, a bevelled ice cornice with icicles under it, the door
-- leaves with icy frames, frosted panels and ice ring handles; on the boss gate the crown emblem rebuilt with depth (a
-- bevelled gold band with rims, 5 faceted gold spikes, gold bezels round today's glowing cyan gems) and the dais as
-- jointed ice slabs; on the arena door a cyan gem handle on each leaf and a faceted ice setting round today's glowing
-- emblem. Every colliding part of today stays (the dais as invisible collision); the knights, torches and spires stay.
---------------------------------------------------------------------
local ICE = { frame = rgb(110, 176, 236), panel = rgb(120, 186, 240), frost = rgb(225, 240, 252), rime = rgb(240, 247, 255), cornice = rgb(150, 214, 250), deep = rgb(40, 96, 170), gem = rgb(96, 190, 255), setting = rgb(200, 232, 250) }
local TGLIB = nil
local function tglib(): any
	if not TGLIB then
		TGLIB = { TG = require(ServerStorage.DevTools.PropsTundraGates:Clone()), TB = require(ServerStorage.DevTools.PropsTundraBuildings:Clone()) }
	end
	return TGLIB
end

-- ice blocks on every listed face of a box part (faces: "front" -Z, "back" +Z, "left" -X, "right" +X)
local function iceBox(list: { BasePart }, rng: Random, p: BasePart, faces: { string }, y0: number, y1: number, ch: number, Ht: number)
	local TG = tglib().TG
	local c, s = p.Position, p.Size
	local frames = {
		front = { CFrame.new(c.X, 0, c.Z - s.Z / 2), s.X },
		back = { CFrame.new(c.X, 0, c.Z + s.Z / 2) * CFrame.Angles(0, math.pi, 0), s.X },
		left = { CFrame.new(c.X - s.X / 2, 0, c.Z) * CFrame.Angles(0, math.rad(-90), 0), s.Z },
		right = { CFrame.new(c.X + s.X / 2, 0, c.Z) * CFrame.Angles(0, math.rad(90), 0), s.Z },
	}
	for _, f in ipairs(faces) do
		local fr = frames[f]
		TG.iceFace(list, rng, fr[1], -fr[2] / 2, fr[2] / 2, y0, y1, ch, p.Color, Ht)
	end
end

-- a frosted door leaf face: an icy frame round the leaf, a frosted panel (two on a tall leaf) with frost lines and
-- corner frost; f = the face frame (X along the face, Y up, -Z out of the face), w x h the leaf
local function frostedLeaf(U: any, f: CFrame, w: number, h: number, panels: { { number } })
	local H = lib().H
	local fw = math.clamp(w * 0.08, 0.6, 1.2)
	for _, e in ipairs({ { 0, h / 2 - fw / 2, w, fw }, { 0, -h / 2 + fw / 2, w, fw }, { -w / 2 + fw / 2, 0, fw, h - 2 * fw }, { w / 2 - fw / 2, 0, fw, h - 2 * fw } }) do
		table.insert(U.DoorFrame, H.chamfered(Vector3.new(e[3], e[4], 0.35), f * CFrame.new(e[1], e[2], -0.17), ICE.frame, { "frontFace" }, 0.12))
	end
	for _, pn in ipairs(panels) do
		local y0, y1 = pn[1], pn[2]
		local pw, ph = w - 2 * fw - 1.2, y1 - y0
		local pc = f * CFrame.new(0, (y0 + y1) / 2, -0.12)
		table.insert(U.DoorPanel, H.chamfered(Vector3.new(pw, ph, 0.25), pc, ICE.panel, { "frontFace" }, 0.3))
		-- frost lines (a slim diamond lattice) and frost in the corners
		for _, sx in ipairs({ -1, 1 }) do
			local a = pc * Vector3.new(sx * pw * 0.32, -ph * 0.4, -0.15)
			local b = pc * Vector3.new(0, ph * 0.1, -0.15)
			table.insert(U.Frost, H.bar(a, b, 0.14, ICE.frost))
			local a2 = pc * Vector3.new(sx * pw * 0.32, ph * 0.4, -0.15)
			table.insert(U.Frost, H.bar(a2, b, 0.14, ICE.frost))
		end
		for _, cx in ipairs({ -1, 1 }) do
			for _, cy in ipairs({ -1, 1 }) do
				local corner = Vector3.new(cx * (pw / 2 - 0.05), cy * (ph / 2 - 0.05), -0.16)
				H.triangleParts(U.Frost, corner, corner - Vector3.new(cx * 1.4, 0, 0), corner - Vector3.new(0, cy * 1.2, 0), 0.04, pc, ICE.rime)
			end
		end
	end
end

-- a faceted gold spike (a 4-sided pyramid w wide, d deep, from y0 to y1) in frame cf
local function goldSpike(list: { BasePart }, cf: CFrame, w: number, d: number, y0: number, y1: number, color: Color3)
	local TB, H = lib().TB, lib().H
	local hgt = y1 - y0
	local apex = Vector3.new(0, y1, 0)
	local planes = { { n = Vector3.new(0, -1, 0), d = -y0 } }
	for _, n in ipairs({ Vector3.new(-hgt, w / 2, 0), Vector3.new(hgt, w / 2, 0), Vector3.new(0, d / 2, -hgt), Vector3.new(0, d / 2, hgt) }) do
		local u = n.Unit
		table.insert(planes, { n = u, d = u:Dot(apex) })
	end
	TB.solidOf(list, cf, Vector3.new(-w / 2, y0, -d / 2), Vector3.new(w / 2, y1, d / 2), planes, function(nv: Vector3): Color3
		if nv.Z < -0.3 then
			return H.scaled(color, 1.08)
		elseif math.abs(nv.X) > 0.5 then
			return H.scaled(color, 0.9)
		end
		return color
	end)
end

function P.tundraBossGate(): string
	local id = "tundra_gate_boss_gate"
	local H, TB = lib().H, tglib().TB
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(1919)
	H.setBevelSelf(true)
	local U: any = { IceBlocks = {}, IceBlocks2 = {}, IceTrim = {}, Icicles = {}, DoorFrame = {}, DoorPanel = {}, Frost = {}, Gold = {}, GoldDark = {} }
	local GOLD, DARK = rgb(255, 201, 60), rgb(202, 154, 54)
	local Ht = 53
	local lintel, crownBand
	local leaves, gems = {}, {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local n = c.Name
			if n == "Jamb" then
				iceBox(if c.Position.X < 0 then U.IceBlocks else U.IceBlocks2, rng, c, { "front", "back", if c.Position.X < 0 then "left" else "right" }, 0, 38, 2.5, Ht)
				c.Color = ICE.deep
			elseif n == "Lintel" then
				lintel = c
			elseif n == "Leaf" then
				table.insert(leaves, c)
			elseif n == "Trim" or n == "Facet" or n == "CrownPoint" then
				c:Destroy()
			elseif n == "CrownBand" then
				crownBand = c
			elseif n == "CrownGem" then
				table.insert(gems, c)
			elseif n == "Dais" then
				local cf, s = c.CFrame, c.Size
				toCollision(c)
				for k = 0, 3 do
					local w = s.X / 4
					table.insert(U.IceTrim, H.chamfered(Vector3.new(w - 0.12, s.Y, s.Z), cf * CFrame.new(-s.X / 2 + (k + 0.5) * w, 0, 0), H.scaled(ICE.cornice, rng:NextNumber(0.96, 1.04)), { "vertical", "topFrontBack", "topSides" }, 0.18))
				end
			end
		end
	end
	-- the lintel: ice blocks front and back, a bevelled ice cornice, icicles under its front over the door
	if lintel then
		local c, s = lintel.Position, lintel.Size
		iceBox(U.IceBlocks, rng, lintel, { "front", "back" }, c.Y - s.Y / 2, c.Y + s.Y / 2, 2.0, Ht)
		lintel.Color = ICE.deep
		table.insert(U.IceTrim, H.chamfered(Vector3.new(s.X + 1.2, 0.9, s.Z + 0.8), CFrame.new(c.X, c.Y + s.Y / 2 + 0.45, c.Z), ICE.cornice, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.3))
		for k = 0, 12 do
			local x = c.X - s.X / 2 + 1.4 + k * (s.X - 2.8) / 12
			table.insert(U.IceTrim, H.piece("Part", Vector3.new(0.8, 0.5, 0.4), CFrame.new(x, c.Y + s.Y / 2 - 0.25, c.Z - s.Z / 2 - 0.25), H.scaled(ICE.cornice, 0.9)))
		end
		for k = 0, 9 do
			local x = -14 + k * 28 / 9 + rng:NextNumber(-0.4, 0.4)
			TB.facetIcicle(U, "Icicles", Vector3.new(x, c.Y - s.Y / 2 - 0.05, c.Z - s.Z / 2 + 0.4), rng:NextNumber(0.25, 0.55), 0.7, rng:NextNumber(0, 6.28))
		end
	end
	-- the leaves: icy frames, frosted panels (under and over the crown), ice ring handles
	for _, lf in ipairs(leaves) do
		local c, s = lf.Position, lf.Size
		local f = CFrame.new(c.X, c.Y, c.Z - s.Z / 2)
		frostedLeaf(U, f, s.X, s.Y, { { -s.Y / 2 + 2.2, 4.0 }, { 13.4, s.Y / 2 - 1.8 } })
		local back = CFrame.new(c.X, c.Y, c.Z + s.Z / 2) * CFrame.Angles(0, math.pi, 0)
		frostedLeaf(U, back, s.X, s.Y, { { -s.Y / 2 + 2.2, s.Y / 2 - 2.2 } })
		local hx = if c.X < 0 then c.X + s.X / 2 - 2.0 else c.X - s.X / 2 + 2.0
		local M = jlib().M
		table.insert(U.IceTrim, M.frustumN(8, 0.9, 0.9, -0.2, 0.2, H.frameY(Vector3.new(hx, 15, c.Z - s.Z / 2 - 0.45), Vector3.new(0, 0, -1)), { ICE.setting, ICE.frame }))
	end
	-- the crown emblem with depth: a bevelled gold band with rims, 5 faceted spikes, gold bezels round the gems
	if crownBand then
		local c, s = crownBand.Position, crownBand.Size
		crownBand:Destroy() -- (a visual only: it did not collide)
		local bz = c.Z + 0.3 -- (the band and spikes sit back so today's gems stand proud of them)
		table.insert(U.Gold, H.chamfered(Vector3.new(s.X + 0.3, s.Y, 1.4), CFrame.new(c.X, c.Y, bz), GOLD, { "frontFace", "vertical" }, 0.35))
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(U.GoldDark, H.chamfered(Vector3.new(s.X + 0.8, 0.5, 1.7), CFrame.new(c.X, c.Y + sy * (s.Y / 2 + 0.05), bz), DARK, { "frontFace", "vertical" }, 0.18))
		end
		local base = c.Y + s.Y / 2 + 0.25
		for _, sp in ipairs({ { 0, 10.3 }, { -3.45, 7.6 }, { 3.45, 7.6 }, { -6.85, 5.7 }, { 6.85, 5.7 } }) do
			goldSpike(U.Gold, CFrame.new(c.X + sp[1], 0, bz), 3.3, 1.5, base - 0.2, base + sp[2] - 0.6, GOLD)
			table.insert(U.Gold, H.piece("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(c.X + sp[1], base + sp[2] - 0.55, bz), GOLD, { shape = Enum.PartType.Ball }))
		end
		for _, g in ipairs(gems) do
			diamondBezel(U.GoldDark, g.CFrame * CFrame.new(0, 0, -0.1), g.Size.X, 0.4, g.Size.Z + 0.4, DARK)
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Icicles = TB.ICICLE_OPTS, DoorFrame = { material = Enum.Material.Glass, transparency = 0.1 }, DoorPanel = { material = Enum.Material.Glass, transparency = 0.15 } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: ice castle gate recipe + deep crown emblem, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

function P.tundraArenaDoor(): string
	local id = "tundra_gate_door"
	local H, TB = lib().H, tglib().TB
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(2020)
	H.setBevelSelf(true)
	local U: any = { IceBlocks = {}, IceTrim = {}, Icicles = {}, DoorFrame = {}, DoorPanel = {}, Frost = {}, Glow = {} }
	local Ht = 33
	local slab, emblem
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local n = c.Name
			if n == "Jamb" then
				local cy0 = c.Position.Y - c.Size.Y / 2
				iceBox(U.IceBlocks, rng, c, { "front", "back", if c.Position.X < 0 then "left" else "right" }, cy0, 14, 2.4, Ht)
				c.Color = ICE.deep
			elseif n == "Lintel" then
				local cc, s = c.Position, c.Size
				iceBox(U.IceBlocks, rng, c, { "front", "back" }, cc.Y - s.Y / 2, cc.Y + s.Y / 2, 2.5, Ht)
				c.Color = ICE.deep
				table.insert(U.IceTrim, H.chamfered(Vector3.new(s.X + 0.8, 0.7, s.Z + 0.6), CFrame.new(cc.X, cc.Y + s.Y / 2 + 0.35, cc.Z), ICE.cornice, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.25))
				for k = 0, 6 do
					local x = -9 + k * 3 + rng:NextNumber(-0.3, 0.3)
					for _, zs in ipairs({ -1, 1 }) do
						TB.facetIcicle(U, "Icicles", Vector3.new(x, cc.Y - s.Y / 2 - 0.05, cc.Z + zs * (s.Z / 2 - 0.4)), rng:NextNumber(0.2, 0.4), 0.6, rng:NextNumber(0, 6.28))
					end
				end
			elseif n == "Slab" then
				slab = c
			elseif n == "Trim" then
				c:Destroy()
			elseif n == "Emblem" then
				emblem = c
			end
		end
	end
	-- the door: on both faces two leaves with icy frames and frosted panels
	if slab then
		local c, s = slab.Position, slab.Size
		for _, side in ipairs({ -1, 1 }) do
			local lx = c.X + side * s.X / 4
			local front = CFrame.new(lx, c.Y, c.Z - s.Z / 2)
			local back = CFrame.new(lx, c.Y, c.Z + s.Z / 2) * CFrame.Angles(0, math.pi, 0)
			frostedLeaf(U, front, s.X / 2 - 0.2, s.Y, { { -s.Y / 2 + 2, 3.0 }, { 5.5, s.Y / 2 - 2 } })
			frostedLeaf(U, back, s.X / 2 - 0.2, s.Y, { { -s.Y / 2 + 2, 2.0 }, { 9.5, s.Y / 2 - 2 } })
			-- the outer face: a cyan gem handle on each leaf (a faceted ice setting and a glowing gem)
			local hx = c.X + side * 1.8
			local M = jlib().M
			table.insert(U.IceTrim, M.frustumN(8, 0.75, 0.6, 0, 0.35, H.frameY(Vector3.new(hx, c.Y + 4.25, c.Z - s.Z / 2 - 0.3), Vector3.new(0, 0, -1)), { ICE.setting, ICE.frame }))
			table.insert(U.Glow, H.piece("Part", Vector3.new(0.75, 0.75, 0.4), CFrame.new(hx, c.Y + 4.25, c.Z - s.Z / 2 - 0.62) * CFrame.Angles(0, 0, math.rad(45)), ICE.gem))
		end
	end
	-- a faceted ice setting round today's glowing emblem (arena face)
	if emblem then
		local M = jlib().M
		local p = emblem.Position
		table.insert(U.IceTrim, M.frustumN(8, emblem.Size.X * 0.85, emblem.Size.X * 0.7, 0, 0.3, H.frameY(Vector3.new(p.X, p.Y, slab.Position.Z + slab.Size.Z / 2), Vector3.new(0, 0, 1)), { ICE.setting, ICE.frame }))
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, { Icicles = TB.ICICLE_OPTS, DoorFrame = { material = Enum.Material.Glass, transparency = 0.1 }, DoorPanel = { material = Enum.Material.Glass, transparency = 0.15 }, Glow = { material = Enum.Material.Neon } })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: ice castle door recipe on both faces, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

return P
