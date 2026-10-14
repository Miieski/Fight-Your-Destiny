--!strict
-- Speed lines (OWNER: the VFX sub-agent; specs in Config/CombatVFX Swing, Kind = "Lines"): thin streaks that shoot
-- forward along the attack and shrink from the back. Asset (<Category>_<Name>): an invisible anchored Part with
-- attachments A1..An / B1..Bn and beams Line1..n (A_i -> B_i).
-- Spec: Asset, the frame (Anchors.frame: Anchor, Height, Offset, Yaw, Pitch, Roll), Count (halved with Low FX),
-- Spread { x, y } (random offsets around the frame's axis), Start, Length (studs forward; each line 70-100 % of it),
-- Width, Extend (s: the head shoots out), Hold, Fade (the tail catches up), Jitter (random start delay per line),
-- Solid = true (the palette's color itself instead of its whitened core: dark shadow lines).
--   Streaks.play(spec, character, direction, palette, delay, tool?)
local Anchors = require(script.Parent.Anchors)
local Colors = require(script.Parent.Colors)
local Runner = require(script.Parent.Runner)

local Streaks = {}

type Fx = Runner.Fx

local rng = Random.new()
local clamp = math.clamp

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
	fx.oy = table.create(n, 0)
	fx.len = table.create(n, 0)
	fx.wait = table.create(n, 0)
	fx.palette = false
	return true
end

Runner.onMake(function(fx: Fx)
	if not fx.beams and fx.child.A1 and fx.child.Line1 then
		setup(fx)
	end
end)

local function step(fx: Fx, t: number): boolean
	local spec = fx.spec
	local start, extend, hold, fade, width = spec.Start or 0, spec.Extend, spec.Hold, spec.Fade, spec.Width
	local count = fx.count
	for i = 1, fx.n do
		local beam = fx.beams[i]
		if i <= count then
			local lt = t - fx.wait[i]
			local k = clamp(lt / extend, 0, 1)
			k = 1 - (1 - k) * (1 - k)
			local tail = clamp((lt - extend - hold) / fade, 0, 1)
			local len = fx.len[i]
			local x, y = fx.ox[i], fx.oy[i]
			fx.b[i].Position = Vector3.new(x, y, -(start + len * k))
			fx.a[i].Position = Vector3.new(x, y, -(start + len * k * tail))
			local w = if lt < 0 then 0 else width * (1 - tail)
			beam.Width0, beam.Width1 = w * 0.25, w
		else
			beam.Width0, beam.Width1 = 0, 0
		end
	end
	return true
end

local function begin(fx: Fx): boolean
	local root = fx.root
	if not root.Parent then
		return false
	end
	local spec = fx.spec
	fx.part.CFrame = Anchors.frame(spec, fx.character, root, fx.tool, fx.dir)
	local spread = spec.Spread
	local count = math.min(fx.n, spec.Count or fx.n)
	if Runner.lowFx() then
		count = math.max(1, math.ceil(count / 2))
	end
	fx.count = count
	for i = 1, count do
		fx.ox[i] = rng:NextNumber(-spread[1], spread[1])
		fx.oy[i] = rng:NextNumber(-spread[2], spread[2])
		fx.len[i] = spec.Length * rng:NextNumber(0.7, 1)
		fx.wait[i] = rng:NextNumber(0, spec.Jitter or 0)
	end
	local palette = fx.pal
	local color = if spec.Solid then palette.arc else palette.core
	if fx.palette ~= color then
		fx.palette = color
		for i = 1, fx.n do
			fx.beams[i].Color = color
		end
	end
	step(fx, 0)
	return true
end

function Streaks.play(spec: any, character: Model, direction: Vector3, palette: Colors.Palette, delay: number, tool: Instance?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local fx = Runner.acquire(spec.Asset)
	if not fx then
		return
	end
	if not fx.beams and not setup(fx) then
		Runner.release(fx)
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	fx.dir = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
	fx.root, fx.character, fx.tool, fx.spec, fx.pal = root, character, tool, spec, palette
	Runner.run(fx, delay, (spec.Jitter or 0) + spec.Extend + spec.Hold + spec.Fade, begin, step)
end

return Streaks
