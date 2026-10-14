--!strict
-- Jump attack dive (OWNER: the VFX sub-agent; Config/CombatVFX AirSwing[category].Dive, combat V3): while a melee
-- jump attack's body dives to the ground, falling streaks run from where the dive started down to the body, a wind
-- ring bursts at the dive start and the weapon trail stays on for the whole dive; on landing the streaks' tails catch
-- up and the trail stops TrailOff s later. The dive is read from the body itself, so it works for every character: the
-- local one hangs a variable time (CombatController holds it until a dive can land on time), other players come
-- through replication. It starts when the root falls faster than MinFall studs / s and ends at Dives.land(character)
-- (VFX.land) or when the feet are within LandGap studs of the ground.
-- Asset (Shared_DiveLines): an invisible anchored Part with attachments A1..An / B1..Bn and beams Line1..n.
-- Spec: Asset, Count (halved with Low FX), Spread (studs around the body axis), Top { min, max } (studs above the dive
-- start where a streak begins), Bottom { min, max } (studs above the root where it ends), Width, Fade, MinFall,
-- LandGap, Timeout (s after the call), Color? (else the weapon palette), Solid = true (the color itself, else its
-- whitened core), Ring? (an Arcs spec laid flat at the dive start, RingHeight studs above the root), TrailOff.
--   Dives.play(spec, character, tool, palette, wait, color?)   wait = s before the dive may start (the hang); color =
--                                                       the zone style's dive color (solid streaks and ring)
--   Dives.land(character)                               the landing (VFX.land)
local Arcs = require(script.Parent.Arcs)
local Colors = require(script.Parent.Colors)
local Runner = require(script.Parent.Runner)
local Trails = require(script.Parent.Trails)

local Dives = {}

type Fx = Runner.Fx

local rng = Random.new()
local clamp = math.clamp
local TAU = math.pi * 2

local diving: { [Instance]: Fx } = setmetatable({}, { __mode = "k" }) :: any

local function setup(fx: Fx): boolean
	local child = fx.child
	local a, b, beams = {}, {}, {}
	local n = 0
	while child["A" .. (n + 1)] and child["B" .. (n + 1)] and child["Line" .. (n + 1)] do
		n += 1
		a[n], b[n], beams[n] = child["A" .. n], child["B" .. n], child["Line" .. n]
	end
	if n == 0 then
		return false
	end
	fx.n = n
	fx.a, fx.b, fx.beams = a, b, beams
	fx.ox = table.create(n, 0)
	fx.oz = table.create(n, 0)
	fx.top = table.create(n, 0)
	fx.bottom = table.create(n, 0)
	fx.wk = table.create(n, 0)
	fx.palette = false
	fx.dive = true -- (the Streaks hook may have set up the same clone too: its fields are unused here)
	return true
end

Runner.onMake(function(fx: Fx)
	if not fx.dive and fx.name == "Shared_DiveLines" and fx.child.A1 then
		setup(fx)
	end
end)

local function hideLines(fx: Fx)
	for i = 1, fx.n do
		local beam = fx.beams[i]
		beam.Width0, beam.Width1 = 0, 0
	end
end

-- Lines from the dive start (the part's origin, world axes) down to the body; k = how far the tails came down (0..1).
local function drawLines(fx: Fx, body: Vector3, k: number)
	local spec = fx.spec
	local rel = body - fx.start
	local width = spec.Width * (1 - k)
	for i = 1, fx.n do
		local beam = fx.beams[i]
		if i <= fx.count then
			local x, z = fx.ox[i], fx.oz[i]
			local yb = rel.Y + fx.bottom[i]
			local ya = fx.top[i]
			ya += (yb - ya) * k
			fx.a[i].Position = Vector3.new(x + rel.X * k, ya, z + rel.Z * k)
			fx.b[i].Position = Vector3.new(x + rel.X, yb, z + rel.Z)
			local w = width * fx.wk[i]
			beam.Width0, beam.Width1 = w * 0.15, w
		else
			beam.Width0, beam.Width1 = 0, 0
		end
	end
end

local function startDive(fx: Fx, at: Vector3)
	local spec = fx.spec
	fx.phase = 1
	fx.start = at
	fx.part.CFrame = CFrame.new(at)
	local count = math.min(fx.n, spec.Count or fx.n)
	if Runner.lowFx() then
		count = math.max(1, math.ceil(count / 2))
	end
	fx.count = count
	for i = 1, count do
		local a = TAU * (i - 1) / count + rng:NextNumber(-0.3, 0.3)
		local r = spec.Spread * rng:NextNumber(0.55, 1)
		fx.ox[i], fx.oz[i] = math.cos(a) * r, math.sin(a) * r
		fx.top[i] = rng:NextNumber(spec.Top[1], spec.Top[2])
		fx.bottom[i] = rng:NextNumber(spec.Bottom[1], spec.Bottom[2])
		fx.wk[i] = rng:NextNumber(0.6, 1)
	end
	local color = if fx.solid then fx.pal.arc else fx.pal.core
	if fx.palette ~= color then
		fx.palette = color
		for i = 1, fx.n do
			fx.beams[i].Color = color
		end
	end
	local ring = spec.Ring
	if ring then
		Arcs.playAt(ring, CFrame.new(at + Vector3.new(0, spec.RingHeight or 0, 0)), fx.pal, 0)
	end
	if fx.tool then
		Trails.swing(fx.tool, fx.weapon, 0, spec.Timeout)
	end
	drawLines(fx, at, 0)
end

local function landNow(fx: Fx, t: number, at: Vector3)
	fx.phase = 2
	fx.landT = t
	fx.finish = at
	if fx.tool then
		Trails.finish(fx.tool, fx.spec.TrailOff)
	end
end

local function step(fx: Fx, t: number): boolean
	local root = fx.root
	if not root.Parent then
		return false
	end
	local spec = fx.spec
	local pos = root.Position
	local dt = t - fx.lastT
	local vy = if dt > 1e-3 then (pos.Y - fx.lastY) / dt else 0
	fx.lastT, fx.lastY = t, pos.Y
	local phase = fx.phase
	if phase == 0 then
		-- waiting for the dive (the hang)
		if fx.landed or t > spec.Timeout then
			return false
		end
		if vy < -spec.MinFall then
			startDive(fx, pos)
		end
	elseif phase == 1 then
		local feet = fx.reach + spec.LandGap
		if fx.landed or t > spec.Timeout or (vy > -spec.MinFall and Runner.ground(pos, 0, feet) ~= nil) then
			landNow(fx, t, pos)
			drawLines(fx, pos, 0)
		else
			drawLines(fx, pos, 0)
		end
	else
		local k = (t - fx.landT) / spec.Fade
		if k >= 1 then
			return false
		end
		drawLines(fx, fx.finish, 1 - (1 - k) * (1 - k))
	end
	return true
end

local function begin(fx: Fx): boolean
	local root = fx.root
	if not root.Parent then
		return false
	end
	fx.phase = 0
	fx.lastT, fx.lastY = 0, root.Position.Y
	hideLines(fx)
	return true
end

local function done(fx: Fx)
	hideLines(fx)
	if diving[fx.character] == fx then
		diving[fx.character] = nil
	end
	if fx.phase == 1 and fx.tool then
		Trails.finish(fx.tool, 0)
	end
	fx.tool = false
end

function Dives.play(spec: any, character: Model, tool: Instance?, palette: Colors.Palette, wait: number, color: Color3?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local current = diving[character]
	if current and current.slot ~= 0 then
		Runner.stop(current)
	end
	local fx = Runner.acquire(spec.Asset)
	if not fx then
		return
	end
	if not fx.dive and not setup(fx) then
		Runner.release(fx)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	fx.reach = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y * 0.5
	fx.root, fx.character, fx.spec = root, character, spec
	fx.tool = if tool and tool.Parent == character then tool else false
	fx.weapon = palette
	-- the zone's dive color (zone styles) wins over the category's own
	local tone: Color3? = color or spec.Color
	fx.pal = if tone then Colors.flat(tone) else palette
	fx.solid = color ~= nil or spec.Solid == true
	fx.done = done
	fx.phase = 0
	fx.landed = false
	diving[character] = fx
	Runner.run(fx, math.max(0, wait * 0.5), spec.Timeout + spec.Fade + 0.1, begin, step)
end

function Dives.land(character: Instance)
	local fx = diving[character]
	if fx and fx.slot ~= 0 then
		fx.landed = true
	end
end

return Dives
