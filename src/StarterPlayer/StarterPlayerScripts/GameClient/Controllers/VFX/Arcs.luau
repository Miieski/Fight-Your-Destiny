--!strict
-- Slash arcs (OWNER: the VFX sub-agent; numbers in Config/CombatVFX Arc and Swing[category][step].Arc).
-- A crescent of beams on a circle around the attacker, in the swing's plane, revealed tail -> head and thinned out
-- tail first. Asset (ReplicatedStorage.Assets.VFX.<Category>_<Name>): an invisible anchored Part with attachments
-- P0..Pn, beams Outer1..n (rarity color) and Core1..n (white core) between consecutive points, and optionally an
-- attachment Ground (its emitters fire at the attacker's feet) and Center (emitters at the arc center).
--   Arcs.play(spec, character, direction, palette, delay)   the arc appears delay seconds from now (at the hit),
--                                                           around the character (spec.Height above its root)
--   Arcs.playAt(spec, cframe, palette, delay)                the same around a fixed frame (its XZ plane, 0 deg = look)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Colors = require(script.Parent.Colors)
local Runner = require(script.Parent.Runner)

local Arcs = {}

local ARC = Config.Arc
local UP = Vector3.yAxis
local sin, cos, rad, clamp = math.sin, math.cos, math.rad, math.clamp

type Fx = Runner.Fx

-- Width along the arc (u: 0 = tail, 1 = head).
local function profile(kind: string, u: number): number
	if kind == "Ring" then
		return math.min(1, u * 3) * math.min(1, (1 - u) * 10)
	elseif kind == "Full" then
		return 1
	end
	return sin(math.pi * u) ^ 0.6 * (0.5 + 0.5 * u)
end

-- Collect the points and beams of a clone once.
local function setup(fx: Fx): boolean
	local child = fx.child
	local pts, outer, core = {}, {}, {}
	local n = 0
	while child["P" .. (n + 1)] and child["Outer" .. (n + 1)] and child["Core" .. (n + 1)] do
		n += 1
	end
	if n == 0 or not child.P0 then
		return false
	end
	for j = 0, n do
		pts[j + 1] = child["P" .. j]
	end
	for i = 1, n do
		outer[i] = child["Outer" .. i]
		core[i] = child["Core" .. i]
	end
	fx.n = n
	fx.pts, fx.outer, fx.core = pts, outer, core
	fx.ang = table.create(n + 1, 0)
	fx.prof = table.create(n + 1, 0)
	fx.wid = table.create(n + 1, 0)
	fx.palette = false
	-- look of the beams (Config Arc OuterLook / CoreLook), set once per clone
	for layer = 1, 2 do
		local look = if layer == 1 then ARC.OuterLook else ARC.CoreLook
		local list = if layer == 1 then outer else core
		local tail, head = look.Transparency[1], look.Transparency[2]
		for i = 1, n do
			local b = list[i]
			b.LightEmission = look.LightEmission
			b.Brightness = look.Brightness
			b.Transparency = NumberSequence.new(tail + (head - tail) * (i - 1) / n, tail + (head - tail) * i / n)
		end
	end
	return true
end

-- set up arc clones when the pool makes them (prewarm), not at their first hit
Runner.onMake(function(fx: Fx)
	if not fx.pts and fx.child.P0 and fx.child.Outer1 then
		setup(fx)
	end
end)

local function lifeOf(spec: any): number
	return spec.Reveal + (spec.Hold or ARC.Hold) + (spec.Fade or ARC.Fade) + ARC.FadeIn
end

local function step(fx: Fx, t: number): boolean
	local spec = fx.spec
	local n = fx.n
	local reveal, hold, fade, fadeIn = spec.Reveal, spec.Hold or ARC.Hold, spec.Fade or ARC.Fade, ARC.FadeIn
	local radius = spec.Radius * (1 + (spec.Grow or ARC.Grow) * t / fx.life)
	local curve = fx.kk * radius
	local width = spec.Width
	local coreK = spec.Core or ARC.Core
	local pts, ang, prof, wid = fx.pts, fx.ang, fx.prof, fx.wid
	for j = 1, n + 1 do
		local r = reveal * (j - 1) / n
		local a = clamp((t - r) / fadeIn, 0, 1)
		local b = clamp((t - r - hold) / fade, 0, 1)
		wid[j] = width * prof[j] * a * (1 - b * b)
		local angle = ang[j]
		pts[j].Position = Vector3.new(radius * sin(angle), 0, -radius * cos(angle))
	end
	local outer, core = fx.outer, fx.core
	for i = 1, n do
		local w0, w1 = wid[i], wid[i + 1]
		local o, c = outer[i], core[i]
		o.Width0, o.Width1, o.CurveSize0, o.CurveSize1 = w0, w1, curve, curve
		c.Width0, c.Width1, c.CurveSize0, c.CurveSize1 = w0 * coreK, w1 * coreK, curve, curve
	end
	return true
end

local function begin(fx: Fx): boolean
	local spec = fx.spec
	local root = fx.root
	local frame: CFrame
	if root then
		if not root.Parent then
			return false
		end
		local center = root.Position + Vector3.new(0, spec.Height or 0, 0)
		frame = CFrame.lookAt(center, center + fx.dir)
	else
		frame = fx.at
	end
	local base = if root then root.Position else frame.Position
	fx.part.CFrame = frame * CFrame.Angles(0, 0, rad(spec.Roll or 0))
	local n = fx.n
	local from, to = rad(spec.From), rad(spec.To)
	local sign = if to >= from then 1 else -1
	local kind = spec.Profile or "Crescent"
	for j = 1, n + 1 do
		local u = (j - 1) / n
		local angle = from + (to - from) * u
		fx.ang[j] = angle
		fx.prof[j] = profile(kind, u)
		fx.pts[j].CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.new(cos(angle), 0, sin(angle)) * sign, UP)
	end
	-- cubic Bezier handle of a circular segment, per stud of radius
	fx.kk = 4 / 3 * math.tan(math.abs(to - from) / n / 4)
	local palette = fx.pal
	if fx.palette ~= palette then
		fx.palette = palette
		for i = 1, n do
			fx.outer[i].Color = Colors.segment(palette, n, i)
			fx.core[i].Color = palette.core
		end
	end
	if #fx.emitters > 0 then
		local ground = fx.child.Ground
		if ground and spec.Ground then
			local feet = Runner.ground(base, 0.5, 8) or (base - Vector3.new(0, 3, 0))
			ground.WorldCFrame = CFrame.new(feet + Vector3.new(0, 0.15, 0))
		end
		Runner.emit(fx)
	end
	step(fx, 0)
	return true
end

local function acquire(spec: any): Fx?
	local fx = Runner.acquire(spec.Asset)
	if fx and not fx.pts and not setup(fx) then
		Runner.release(fx)
		return nil
	end
	return fx
end

function Arcs.play(spec: any, character: Model, direction: Vector3, palette: Colors.Palette, delay: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local fx = acquire(spec)
	if not fx then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	fx.dir = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
	fx.root = root
	fx.spec = spec
	fx.pal = palette
	fx.life = lifeOf(spec)
	Runner.run(fx, delay, fx.life, begin, step)
end

function Arcs.playAt(spec: any, cframe: CFrame, palette: Colors.Palette, delay: number)
	local fx = acquire(spec)
	if not fx then
		return
	end
	fx.root = nil
	fx.at = cframe
	fx.spec = spec
	fx.pal = palette
	fx.life = lifeOf(spec)
	Runner.run(fx, delay, fx.life, begin, step)
end

return Arcs
