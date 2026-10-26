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

return P
