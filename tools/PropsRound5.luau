--[[
	PropsRound5 (dev tool, Edit mode only) - owner prompt "ROUND 5" Task 2 / Task 3 template edits.
	Source of truth: tools/PropsRound5.luau (= ServerStorage.DevTools.PropsRound5).

	Usage (execute_luau, Edit):
		local P = require(game.ServerStorage.DevTools.PropsRound5:Clone())
		print(P.sarcophagus())        -- B: desert_landmark_sarcophagus = a big golden guardian + 4 carved pillars
		print(P.jungleGuards())       -- C: jungle_palisade_gate, only the 2 guards (+ their torch tops)
		print(P.iceThrone())          -- D: tundra_landmark_ice_throne = the finished small ice throne enlarged + steps
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

return P
