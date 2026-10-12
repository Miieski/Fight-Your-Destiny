--!strict
-- Roll afterimages (OWNER: the VFX sub-agent; Config/CombatVFX Roll): Config.Roll.Ghosts snapshots of the
-- character's pose, one every Interval s from the start of the roll, each fading out over Fade s. A ghost = clones of
-- the character's body parts (the BaseParts directly in the character model), made once per character at its first
-- roll (or prepared when the local character's appearance loads), rebuilt when its parts change, in the Material
-- of ReplicatedStorage.Assets.VFX.Shared_Afterimage and Config Roll GhostColor / GhostFrom. None with Low FX.
--   Ghosts.play(character)      Ghosts.prepare(character)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Runner = require(script.Parent.Runner)

local Ghosts = {}

type Rec = { [string]: any }
type Set = { ghosts: { Rec }, dirty: boolean, conns: { RBXScriptConnection } }

local sets: { [Instance]: Set } = {}

local function park(rec: Rec)
	rec.model.Parent = nil
end

local function begin(rec: Rec): boolean
	local parts, sources, live = rec.parts, rec.sources, rec.live
	local from = rec.from
	for i = 1, #parts do
		local part = parts[i]
		local source = sources[i]
		if part then
			if source.Parent then
				part.CFrame = source.CFrame
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

local function clear(character: Instance)
	local set = sets[character]
	if not set then
		return
	end
	sets[character] = nil
	for _, conn in ipairs(set.conns) do
		conn:Disconnect()
	end
	for _, rec in ipairs(set.ghosts) do
		Runner.stop(rec)
		rec.model:Destroy()
	end
end

local function build(character: Model): Set?
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
	local set: Set = { ghosts = {}, dirty = false, conns = {} }
	for g = 1, Config.Roll.Ghosts do
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
		set.ghosts[g] = Runner.track({
			capped = true, model = model, parts = parts, sources = sources, live = table.create(#sources, false),
			from = Config.Roll.GhostFrom, done = park,
		})
	end
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
	sets[character] = set
	return set
end

function Ghosts.prepare(character: Model)
	if character.Parent and not sets[character] then
		build(character)
	end
end

function Ghosts.play(character: Model)
	if Runner.lowFx() and not Config.LowFx.Afterimages then
		return
	end
	local set = sets[character]
	if set and set.dirty then
		clear(character)
		set = nil
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

return Ghosts
