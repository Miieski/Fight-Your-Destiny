--!strict
-- Roll afterimages (OWNER: the VFX sub-agent; Config/CombatVFX Roll): Config.Roll.Ghosts snapshots of the
-- character's pose, one every Interval s from the start of the roll, each fading out over Fade s. A ghost = clones of
-- the character's body parts (the BaseParts directly in the character model), in the Material of
-- ReplicatedStorage.Assets.VFX.Shared_Afterimage (SmoothPlastic: no Neon bloom on the ground) and Config Roll
-- GhostColor / GhostFrom. None with Low FX.
-- Ground rule (combat V3 dodge fix): the roll clip curls the body down into the ground, so at each snapshot the ghost
-- is lifted until its lowest part sits GroundMargin studs above the ground plane under the body (at most MaxLift), and
-- any part still lower than HideBelow is hidden: no ghost part ever lies on or cuts through the ground (that tinted
-- the ground blue and made its texture flicker).
-- The ghosts of every player's character (local and others) are prepared ahead by a watcher: every PrepareEvery s, at
-- most one character within Config.CullDistance of the camera that is PrepareAfter s old (appearance loaded) and has
-- no ghosts yet (or its body parts changed) gets them, one ghost per frame. A roll of a character still without ghosts
-- builds them at once (fallback).
--   Ghosts.play(character)      Ghosts.prepare(character, spread?)      Ghosts.start()  (the watcher)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Runner = require(script.Parent.Runner)

local Ghosts = {}

type Rec = { [string]: any }
type Set = { ghosts: { Rec }, dirty: boolean, conns: { RBXScriptConnection } }

local sets: { [Instance]: Set } = {}
local building: { [Instance]: boolean } = {}
local firstSeen: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

local abs = math.abs

local function park(rec: Rec)
	rec.model.Parent = nil
end

-- World Y of the lowest corner of a part's box.
local function bottomOf(part: BasePart): number
	local cf, s = part.CFrame, part.Size
	return cf.Y - (abs(cf.XVector.Y) * s.X + abs(cf.YVector.Y) * s.Y + abs(cf.ZVector.Y) * s.Z) * 0.5
end

local function begin(rec: Rec): boolean
	local cfg = Config.Roll
	local parts, sources, live, rel = rec.parts, rec.sources, rec.live, rec.rel
	local from = rec.from
	-- the ground plane under the body at this snapshot (point + normal)
	local root = rec.root
	local floor: Vector3?, normal: Vector3? = nil, nil
	if root and root.Parent then
		local hit, _, n = Runner.ground(root.Position, 0.5, cfg.GroundProbe)
		floor, normal = hit, n
	end
	-- each part's bottom height above that plane, and the lowest one
	local lowest = math.huge
	for i = 1, #parts do
		local source = sources[i]
		if parts[i] and source.Parent then
			local h = bottomOf(source)
			if floor and normal then
				local p = source.Position
				h -= floor.Y - (normal.X * (p.X - floor.X) + normal.Z * (p.Z - floor.Z)) / math.max(normal.Y, 0.3)
			end
			rel[i] = h
			if h < lowest then
				lowest = h
			end
		end
	end
	local lift = 0
	if floor and lowest < cfg.GroundMargin then
		lift = math.min(cfg.GroundMargin - lowest, cfg.MaxLift)
	end
	local up = Vector3.new(0, lift, 0)
	for i = 1, #parts do
		local part = parts[i]
		local source = sources[i]
		if part then
			if source.Parent and (not floor or rel[i] + lift >= cfg.HideBelow) then
				part.CFrame = source.CFrame + up
				part.Transparency = from
				live[i] = true
			else
				part.Transparency = 1
				live[i] = false
			end
		end
	end
	rec.model.Parent = Runner.folder()
	return true
end

local function step(rec: Rec, t: number): boolean
	local a = rec.from + (1 - rec.from) * math.min(1, t / Config.Roll.Fade)
	local parts, live = rec.parts, rec.live
	for i = 1, #parts do
		local part = parts[i]
		if part and live[i] then
			part.Transparency = a
		end
	end
	return true
end

local function dispose(set: Set)
	for _, conn in ipairs(set.conns) do
		conn:Disconnect()
	end
	for _, rec in ipairs(set.ghosts) do
		Runner.stop(rec)
		rec.model:Destroy()
	end
end

local function clear(character: Instance)
	local set = sets[character]
	if set then
		sets[character] = nil
		dispose(set)
	end
end

local function ghostOf(sources: { BasePart }, look: BasePart, root: BasePart?): Rec
	local model = Instance.new("Model")
	model.Name = "Afterimage"
	local parts: { any } = table.create(#sources, false)
	for i, source in ipairs(sources) do
		local archivable = source.Archivable
		source.Archivable = true
		local ok, copy = pcall(source.Clone, source)
		source.Archivable = archivable
		if ok and copy then
			for _, d in ipairs(copy:GetChildren()) do
				if not d:IsA("DataModelMesh") then
					d:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide, copy.CanQuery, copy.CanTouch = false, false, false
			copy.CastShadow = false
			copy.Massless = true
			copy.Material = look.Material
			copy.Color = Config.Roll.GhostColor
			copy.Transparency = 1
			if copy:IsA("MeshPart") then
				pcall(function()
					copy.TextureID = ""
				end)
			end
			copy.Parent = model
			parts[i] = copy
		end
	end
	return Runner.track({
		capped = true, model = model, parts = parts, sources = sources, live = table.create(#sources, false),
		rel = table.create(#sources, 0), root = root or false, from = Config.Roll.GhostFrom, done = park,
	})
end

-- Builds the ghosts of a character (spread = one ghost per frame). Returns the set, or nil.
local function build(character: Model, spread: boolean?): Set?
	if building[character] then
		return nil
	end
	local look = Runner.template(Config.Roll.Ghost)
	if not (look and look:IsA("BasePart")) then
		return nil
	end
	local sources: { BasePart } = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 1 then
			table.insert(sources, child)
		end
	end
	if #sources == 0 then
		return nil
	end
	building[character] = true
	local set: Set = { ghosts = {}, dirty = false, conns = {} }
	local function changed(child: Instance)
		if child:IsA("BasePart") then
			set.dirty = true
		end
	end
	table.insert(set.conns, character.ChildAdded:Connect(changed))
	table.insert(set.conns, character.ChildRemoved:Connect(changed))
	table.insert(set.conns, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			clear(character)
		end
	end))
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local root: BasePart? = if hrp and hrp:IsA("BasePart") then hrp else nil
	for g = 1, Config.Roll.Ghosts do
		if spread and g > 1 then
			task.wait()
		end
		set.ghosts[g] = ghostOf(sources, look, root)
	end
	building[character] = nil
	if not character:IsDescendantOf(game) then
		dispose(set)
		return nil
	end
	clear(character)
	sets[character] = set
	return set
end

function Ghosts.prepare(character: Model, spread: boolean?)
	local set = sets[character]
	if character.Parent and (not set or set.dirty) then
		build(character, spread)
	end
end

function Ghosts.play(character: Model)
	if Runner.lowFx() and not Config.LowFx.Afterimages then
		return
	end
	local set = sets[character]
	if set and set.dirty then
		set = build(character) or set
	end
	set = set or build(character)
	if not set then
		return
	end
	local cfg = Config.Roll
	for g, rec in ipairs(set.ghosts) do
		Runner.run(rec, (g - 1) * cfg.Interval, cfg.Fade, begin, step)
	end
end

-- The watcher: prepares at most one nearby character per tick, spread over frames.
function Ghosts.start()
	task.spawn(function()
		local cfg = Config.Roll
		while true do
			task.wait(cfg.PrepareEvery)
			if not (Runner.lowFx() and not Config.LowFx.Afterimages) then
				local now = os.clock()
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if character and root and root:IsA("BasePart") then
						local seen = firstSeen[character]
						if not seen then
							firstSeen[character] = now
						elseif now - seen >= cfg.PrepareAfter and not building[character] then
							local set = sets[character]
							if (not set or set.dirty) and Runner.near(root.Position) then
								build(character, true)
								break -- one character per tick
							end
						end
					end
				end
			end
		end
	end)
end

return Ghosts
