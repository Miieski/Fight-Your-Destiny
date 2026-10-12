--!strict
-- Damage numbers (OWNER: the VFX sub-agent; Config/CombatVFX Numbers). Pooled BillboardGuis (template
-- ReplicatedStorage.Assets.VFX.Shared_DamageNumber) adorned to pooled Attachments in workspace.Terrain (parked with
-- Parent = nil when unused): pop scale-in with an overshoot, rise, fade; crits bigger, yellow and shaking.
--   Numbers.show(position, text, kind)   kind = "normal" | "crit" | "hurt" | "block" | "dodge"
--   Numbers.prewarm()                    makes Config Numbers.Prewarm of them up front
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Runner = require(script.Parent.Runner)

local Numbers = {}

type Rec = { [string]: any }

local CFG = Config.Numbers
local all: { Rec } = {}
local freeList: { Rec } = {}
local guiFolder: Folder? = nil
local rng = Random.new()

local function park(rec: Rec)
	rec.gui.Enabled = false
	rec.anchor.Parent = nil
	freeList[#freeList + 1] = rec
end

local function step(rec: Rec, t: number): boolean
	local life = CFG.Life
	local k = t / life
	-- pop: PopFrom -> overshoot -> 1 (back-out ease)
	local p = math.min(1, t / CFG.PopTime) - 1
	local c1 = CFG.Overshoot * rec.over
	local back = 1 + (c1 + 1) * p * p * p + c1 * p * p
	rec.pop.Scale = rec.size * (CFG.PopFrom + (1 - CFG.PopFrom) * back)
	-- rise (quad out)
	local q = 1 - (1 - k) * (1 - k)
	rec.anchor.WorldPosition = rec.base + Vector3.new(0, CFG.Rise * q, 0)
	-- fade
	local fade = if k > CFG.FadeFrom then (k - CFG.FadeFrom) / (1 - CFG.FadeFrom) else 0
	rec.label.TextTransparency = fade
	rec.stroke.Transparency = fade
	-- crit shake
	if rec.shake and t < CFG.ShakeTime then
		local a = CFG.Shake * (1 - t / CFG.ShakeTime)
		rec.gui.StudsOffsetWorldSpace = Vector3.new(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a))
	elseif rec.shook then
		rec.shook = false
		rec.gui.StudsOffsetWorldSpace = Vector3.zero
	end
	if rec.shake then
		rec.shook = true
	end
	return true
end

local function folder(): Folder
	local f = guiFolder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "DamageNumbers"
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	guiFolder = made
	return made
end

local function make(): Rec?
	local template = Runner.template(CFG.Template)
	if not template then
		return nil
	end
	local gui = template:Clone() :: BillboardGui
	local label = gui:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		return nil
	end
	local pop = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	pop.Parent = label
	local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Parent = label
	local anchor = Instance.new("Attachment")
	anchor.Name = "DamageNumber"
	gui.Adornee = anchor
	gui.ClipsDescendants = false
	gui.Enabled = false
	gui.Parent = folder()
	local rec: Rec = Runner.track({ gui = gui, label = label, pop = pop, stroke = stroke, anchor = anchor, base = Vector3.zero, size = 1, over = 1, shake = false, shook = false, done = park })
	table.insert(all, rec)
	return rec
end

local function take(): Rec?
	local n = #freeList
	if n > 0 then
		local rec = freeList[n]
		freeList[n] = nil
		return rec
	end
	if #all < CFG.Max then
		return make()
	end
	-- all busy: reuse the oldest
	local oldest: Rec? = nil
	for _, rec in ipairs(all) do
		if not oldest or rec.startAt < oldest.startAt then
			oldest = rec
		end
	end
	if oldest then
		-- stop it without parking it: it is reused at once
		oldest.done = false
		Runner.stop(oldest)
		oldest.done = park
	end
	return oldest
end

function Numbers.prewarm()
	for _ = #all + 1, CFG.Prewarm do
		local rec = make()
		if not rec then
			return
		end
		freeList[#freeList + 1] = rec
	end
end

function Numbers.show(position: Vector3, text: string, kind: string)
	if typeof(position) ~= "Vector3" or not Runner.near(position) then
		return
	end
	local rec = take()
	if not rec then
		return
	end
	local crit = kind == "crit"
	rec.label.Text = text
	rec.label.TextColor3 = CFG.Colors[kind] or CFG.Colors.normal
	rec.label.TextTransparency = 0
	rec.stroke.Transparency = 0
	rec.size = CFG.Scale[kind] or 1
	rec.over = if crit then 1.5 else 1
	rec.shake = crit
	rec.shook = true
	local s = CFG.Spread
	rec.base = position + Vector3.new(rng:NextNumber(-s, s), 0, rng:NextNumber(-s, s))
	rec.anchor.Parent = workspace.Terrain
	rec.anchor.WorldPosition = rec.base
	rec.pop.Scale = rec.size * CFG.PopFrom
	rec.gui.Enabled = true
	Runner.run(rec, 0, CFG.Life, nil, step)
end

return Numbers
