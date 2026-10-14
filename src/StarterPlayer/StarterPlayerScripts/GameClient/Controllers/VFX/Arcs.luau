--!strict
-- Beam effects (OWNER: the VFX sub-agent; numbers in Config/CombatVFX Arc and the Swing / Impact / Magic / Slam specs):
-- slash arcs, rings and straight streaks from one asset type: an invisible anchored Part with attachments P0..Pn and
-- beams Outer1..n (palette color) / Core1..n (white core) between consecutive points; optional attachments Ground
-- (its emitters fire on the ground under the effect) and Center (emitters at the frame's origin).
-- Spec: Asset, Shape "Circle" (default: points on a circle in the frame's XZ plane from From to To, degrees, 0 = ahead,
-- +90 = right; Radius) or "Line" (points along the frame's forward axis from Start to Start + Length studs), Width,
-- Profile ("Crescent" | "Ring" | "Full" | "Spike" | "Spindle" | "Scallop"), Reveal (s, tail -> head), Hold, Fade, Grow
-- (circle: fraction of the radius; line: fraction of the length it moves forward; eased out), Core, Spin (degrees / s around the frame's
-- up), Ground = true; the frame: Anchors.frame (Anchor, Height, Offset, Yaw, Pitch, Roll).
--   Arcs.play(spec, character, direction, palette, delay, tool?, holdExtra?, tint?, mod?)   on the attacker, delay s
--                                         from now (at its begin the anchor is read: the pose of that moment);
--                                         holdExtra adds hold; tint recolors the asset's Config.Tint emitters
--   Arcs.playAt(spec, cframe, palette, delay, size?, tint?, mod?)   at a fixed frame; size scales Radius / Length
--                                         (area rings); tint recolors the asset's Config.Tint emitters
-- mod = a zone style's way of drawing (Config/CombatVFX Zones[zone].Arc, zone fighting styles): Hard (straight
-- segments), Spiral (Crescent / Ring: the radius grows along the arc), Wave (circles: a rolling ripple), Saw (every
-- other point thinner, not on Scallop), Stutter (s: the effect's clock advances in steps), CoreColor (a dark core, not
-- on effects with their own Color / Palette), Jag (Line: flickering sideways offsets: a bolt), WidthK, RadiusAdd.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Anchors = require(script.Parent.Anchors)
local Colors = require(script.Parent.Colors)
local Runner = require(script.Parent.Runner)

local Arcs = {}

local ARC = Config.Arc
local UP = Vector3.yAxis
local sin, cos, rad, clamp, abs = math.sin, math.cos, math.rad, math.clamp, math.abs
local IDENTITY = CFrame.identity
local TAU = math.pi * 2
local NOMOD = table.freeze({})
local WAVE_TURNS, WAVE_SPEED = 1.5, 14 -- Wave: ripples along the arc, radians / s
local JAG_EVERY = 0.045 -- s between two redraws of a jagged bolt
local rng = Random.new()

type Fx = Runner.Fx

-- Width along the effect (u: 0 = tail, 1 = head).
local function profile(kind: string, u: number): number
	if kind == "Ring" then
		return math.min(1, u * 3) * math.min(1, (1 - u) * 10)
	elseif kind == "Full" then
		return 1
	elseif kind == "Spike" then
		return math.min(1, u * 1.25) ^ 1.2 * math.min(1, (1 - u) * 6)
	elseif kind == "Spindle" then
		return sin(math.pi * u) ^ 0.8
	elseif kind == "Scallop" then
		return 0.55 + 0.45 * cos(u * math.pi * 12)
	end
	return sin(math.pi * u) ^ 0.6 * (0.5 + 0.5 * u)
end

-- Collect the points and beams of a clone once (when the pool makes it) and set the beams' look.
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
	fx.rk = table.create(n + 1, 1) -- radius factor per point (Spiral)
	fx.rr = table.create(n + 1, 0) -- radius per point this frame
	fx.jx = table.create(n + 1, 0) -- sideways offset per point (Jag)
	fx.palette = false
	fx.coreKey = false
	fx.coreDark = false
	fx.mod = NOMOD
	local over = Config.ArcLook[fx.name]
	fx.coreLook = over and over.Core or ARC.CoreLook
	for layer = 1, 2 do
		local look = if layer == 1 then (over and over.Outer or ARC.OuterLook) else (over and over.Core or ARC.CoreLook)
		local list = if layer == 1 then outer else core
		local tail, head = look.Transparency[1], look.Transparency[2]
		for i = 1, n do
			local b = list[i]
			b.LightEmission = look.LightEmission
			b.Brightness = look.Brightness
			b.LightInfluence = look.LightInfluence or 0
			b.Transparency = NumberSequence.new(tail + (head - tail) * (i - 1) / n, tail + (head - tail) * i / n)
		end
	end
	return true
end

Runner.onMake(function(fx: Fx)
	if not fx.pts and fx.child.P0 and fx.child.Outer1 then
		setup(fx)
	end
end)

local function step(fx: Fx, t: number): boolean
	local spec = fx.spec
	local mod = fx.mod
	local n = fx.n
	local stutter = mod.Stutter
	local tt = if stutter then t - t % stutter else t -- the effect's clock (in jerks with Stutter)
	local reveal, hold, fade, fadeIn = spec.Reveal or 0, fx.hold, spec.Fade or ARC.Fade, ARC.FadeIn
	local k = math.min(1, tt / fx.life)
	local grow = (spec.Grow or ARC.Grow) * (1 - (1 - k) * (1 - k))
	local width = spec.Width * (mod.WidthK or 1)
	local coreK = spec.Core or ARC.Core
	local pts, ang, prof, wid, rr = fx.pts, fx.ang, fx.prof, fx.wid, fx.rr
	local kk = 0
	if fx.line then
		local length = spec.Length * fx.size
		local start = (spec.Start or 0) + grow * length
		local jx = fx.jx
		local jag = fx.jag
		if jag then
			local s = t // JAG_EVERY
			if s ~= fx.jagStep then
				fx.jagStep = s
				for j = 2, n do
					jx[j] = rng:NextNumber(-jag, jag)
				end
			end
		end
		for j = 1, n + 1 do
			pts[j].Position = Vector3.new(jx[j], 0, -(start + length * (j - 1) / n))
			rr[j] = 0
		end
	else
		local radius = (spec.Radius * fx.size + (mod.RadiusAdd or 0)) * (1 + grow)
		kk = if mod.Hard then 0 else fx.kk
		local rk = fx.rk
		local wave = mod.Wave
		for j = 1, n + 1 do
			local angle = ang[j]
			local r = radius * rk[j]
			if wave then
				r *= 1 + wave * sin(TAU * WAVE_TURNS * (j - 1) / n - t * WAVE_SPEED)
			end
			rr[j] = r
			pts[j].Position = Vector3.new(r * sin(angle), 0, -r * cos(angle))
		end
	end
	for j = 1, n + 1 do
		local r = reveal * (j - 1) / n
		local a = clamp((tt - r) / fadeIn, 0, 1)
		local b = clamp((tt - r - hold) / fade, 0, 1)
		wid[j] = width * prof[j] * a * (1 - b * b)
	end
	local outer, core = fx.outer, fx.core
	for i = 1, n do
		local w0, w1 = wid[i], wid[i + 1]
		local c0, c1 = kk * rr[i], kk * rr[i + 1]
		local o, c = outer[i], core[i]
		o.Width0, o.Width1, o.CurveSize0, o.CurveSize1 = w0, w1, c0, c1
		c.Width0, c.Width1, c.CurveSize0, c.CurveSize1 = w0 * coreK, w1 * coreK, c0, c1
	end
	local spin = spec.Spin
	if spin then
		fx.part.CFrame = fx.frame * CFrame.Angles(0, rad(spin) * t, 0)
	end
	return true
end

local function begin(fx: Fx): boolean
	local spec = fx.spec
	local frame: CFrame
	local root = fx.root
	if root then
		if not root.Parent then
			return false
		end
		frame = Anchors.frame(spec, fx.character, root, fx.tool, fx.dir)
	else
		frame = fx.at
	end
	fx.frame = frame
	fx.part.CFrame = frame
	local n = fx.n
	local mod = fx.mod
	local kind = spec.Profile or "Crescent"
	local prof = fx.prof
	fx.line = spec.Shape == "Line"
	if fx.line then
		local jag = mod.Jag or false
		fx.jag = jag
		fx.jagStep = -1
		for j = 1, n + 1 do
			prof[j] = profile(kind, (j - 1) / n)
			fx.pts[j].CFrame = IDENTITY
			fx.jx[j] = 0
		end
	else
		local from, to = rad(spec.From or 0), rad(spec.To or 360)
		local sign = if to >= from then 1 else -1
		local spiral = if kind == "Crescent" or kind == "Ring" then mod.Spiral else nil
		for j = 1, n + 1 do
			local u = (j - 1) / n
			local angle = from + (to - from) * u
			fx.ang[j] = angle
			prof[j] = profile(kind, u)
			fx.rk[j] = if spiral then 1 + spiral * (2 * u - 1) else 1
			fx.pts[j].CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.new(cos(angle), 0, sin(angle)) * sign, UP)
		end
		-- cubic Bezier handle of a circular segment, per stud of radius
		fx.kk = 4 / 3 * math.tan(abs(to - from) / n / 4)
	end
	local saw = mod.Saw
	if saw and kind ~= "Scallop" then
		for j = 2, n + 1, 2 do
			prof[j] *= 1 - saw
		end
	end
	local palette = fx.pal
	if fx.palette ~= palette then
		fx.palette = palette
		for i = 1, n do
			fx.outer[i].Color = Colors.segment(palette, n, i)
		end
	end
	-- the core: the palette's whitened color, or the zone's dark core (not lit, not additive)
	local dark: Color3? = if spec.Color == nil and spec.Palette == nil then mod.CoreColor else nil
	local coreKey = dark or palette
	if fx.coreKey ~= coreKey then
		fx.coreKey = coreKey
		local sequence = if dark then Runner.sequence(dark) else palette.core
		local relook = fx.coreDark ~= (dark ~= nil)
		fx.coreDark = dark ~= nil
		local look = fx.coreLook
		for i = 1, n do
			local c = fx.core[i]
			c.Color = sequence
			if relook then
				c.LightEmission = if dark then 0 else look.LightEmission
				c.Brightness = if dark then 1 else look.Brightness
			end
		end
	end
	if #fx.emitters > 0 then
		local ground = fx.child.Ground
		if ground and spec.Ground then
			local base = frame.Position
			local feet = Runner.ground(base, 1, 10) or (base - Vector3.new(0, 3, 0))
			ground.WorldCFrame = CFrame.new(feet + Vector3.new(0, 0.15, 0))
		end
		Runner.emit(fx)
	end
	step(fx, 0)
	return true
end

local function lifeOf(spec: any, hold: number): number
	return (spec.Reveal or 0) + hold + (spec.Fade or ARC.Fade) + ARC.FadeIn
end

local function acquire(spec: any): Fx?
	local fx = Runner.acquire(spec.Asset)
	if fx and not fx.pts and not setup(fx) then
		Runner.release(fx)
		return nil
	end
	return fx
end

function Arcs.play(spec: any, character: Model, direction: Vector3, palette: Colors.Palette, delay: number, tool: Instance?, holdExtra: number?, tint: Color3?, mod: any?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local fx = acquire(spec)
	if not fx then
		return
	end
	Runner.tint(fx, tint)
	fx.mod = mod or NOMOD
	local flat = Vector3.new(direction.X, 0, direction.Z)
	fx.dir = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
	fx.root = root
	fx.character = character
	fx.tool = tool
	fx.spec = spec
	fx.pal = palette
	fx.size = 1
	fx.hold = (spec.Hold or ARC.Hold) + (holdExtra or 0)
	fx.life = lifeOf(spec, fx.hold)
	Runner.run(fx, delay, fx.life, begin, step)
end

function Arcs.playAt(spec: any, cframe: CFrame, palette: Colors.Palette, delay: number, size: number?, tint: Color3?, mod: any?)
	local fx = acquire(spec)
	if not fx then
		return
	end
	Runner.tint(fx, tint)
	fx.mod = mod or NOMOD
	fx.root = nil
	fx.character = nil
	fx.tool = nil
	fx.at = cframe
	fx.spec = spec
	fx.pal = palette
	fx.size = size or 1
	fx.hold = spec.Hold or ARC.Hold
	fx.life = lifeOf(spec, fx.hold)
	Runner.run(fx, delay, fx.life, begin, step)
end

return Arcs
