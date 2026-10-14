--!strict
-- Ground impact (OWNER: the VFX sub-agent; spec in Config/CombatVFX Swing, Kind = "Ground"): cracks that run out from
-- the striking point, chunks of the ground thrown up (ballistic, in the ground's color) and dust, at the ground under
-- the anchor. Asset (Heavy_GroundCrack): an invisible anchored Part with child Parts Crack1..2N (two segments per
-- crack), Chunk1..M, and an attachment Center with emitters (Dust, Pebbles).
-- Spec: Asset, the anchor (Anchors.frame: Anchor, Height, Offset), Cracks, CrackLength { min, max }, CrackWidth, Grow,
-- Hold, Fade, CrackColor, Chunks (halved with Low FX), ChunkSize { min, max }, ChunkUp { min, max },
-- ChunkOut { min, max }, Gravity, ChunkLife, CrackMaterial? (Enum.Material: Neon = glowing lava cracks; else the
-- asset's own).
--   Ground.play(spec, character, direction, delay, tool?)
--   Ground.playAt(spec, position, direction, delay)    at a fixed point (the ground under it): jump attack landings
local Anchors = require(script.Parent.Anchors)
local Runner = require(script.Parent.Runner)

local Ground = {}

type Fx = Runner.Fx

local rng = Random.new()
local TAU = math.pi * 2
local cos, sin, clamp = math.cos, math.sin, math.clamp
local HIDDEN = Vector3.new(0, -1e4, 0)
local DEFAULT_GROUND = Color3.fromRGB(120, 110, 95)

local function setup(fx: Fx): boolean
	local child = fx.child
	local cracks, chunks = {}, {}
	while child["Crack" .. (#cracks + 1)] do
		table.insert(cracks, child["Crack" .. (#cracks + 1)])
	end
	while child["Chunk" .. (#chunks + 1)] do
		table.insert(chunks, child["Chunk" .. (#chunks + 1)])
	end
	if #cracks < 2 then
		return false
	end
	fx.cracks, fx.chunks = cracks, chunks
	fx.baseMaterial = cracks[1].Material
	fx.mat = fx.baseMaterial
	local nc, nk = #cracks, #chunks
	-- per crack segment: start point, direction, length; per chunk: velocity, spin, size
	fx.cs = table.create(nc, Vector3.zero)
	fx.cd = table.create(nc, Vector3.zero)
	fx.cl = table.create(nc, 0)
	fx.kv = table.create(nk, Vector3.zero)
	fx.kw = table.create(nk, Vector3.zero)
	fx.ks = table.create(nk, 0)
	return true
end

Runner.onMake(function(fx: Fx)
	if not fx.cracks and fx.child.Crack1 and fx.child.Chunk1 then
		setup(fx)
	end
end)

local function step(fx: Fx, t: number): boolean
	local spec = fx.spec
	local grow = clamp(t / spec.Grow, 0, 1)
	local fade = clamp((t - spec.Grow - spec.Hold) / spec.Fade, 0, 1)
	local cracks = fx.cracks
	local width = spec.CrackWidth
	for i = 1, fx.used * 2 do
		local part = cracks[i]
		-- first segments grow during the first half, the kinked ones during the second
		local first = i % 2 == 1
		local k = if first then clamp(grow * 2, 0, 1) else clamp(grow * 2 - 1, 0, 1)
		local len = fx.cl[i] * k
		if len < 0.02 then
			part.Position = HIDDEN
		else
			local s, d = fx.cs[i], fx.cd[i]
			part.Size = Vector3.new(if first then width else width * 0.6, 0.06, len)
			part.CFrame = CFrame.lookAt(s + d * (len * 0.5), s + d * len)
			part.Transparency = 0.15 + 0.85 * fade
		end
	end
	local chunks = fx.chunks
	local life = spec.ChunkLife
	local g = spec.Gravity
	local origin = fx.center
	for i = 1, fx.chunkCount do
		local part = chunks[i]
		if t < life then
			local p = origin + fx.kv[i] * t + Vector3.new(0, -0.5 * g * t * t, 0)
			local w = fx.kw[i] * t
			part.CFrame = CFrame.new(p) * CFrame.fromEulerAnglesXYZ(w.X, w.Y, w.Z)
			local s = fx.ks[i] * clamp((life - t) / (life * 0.3), 0, 1)
			part.Size = Vector3.new(s, s, s)
		else
			part.Position = HIDDEN
		end
	end
	return true
end

local function begin(fx: Fx): boolean
	local spec = fx.spec
	local probe: Vector3
	local root = fx.root
	if root then
		if not root.Parent then
			return false
		end
		probe = Anchors.frame(spec, fx.character, root, fx.tool, fx.dir).Position
	else
		probe = fx.at
	end
	local hit, color = Runner.ground(probe, 2, 10)
	local center = (hit or (probe - Vector3.new(0, 2.5, 0))) + Vector3.new(0, 0.05, 0)
	fx.center = center
	fx.part.CFrame = CFrame.new(center)
	-- cracks around the striking point, the first one toward the attack direction
	local cracks = fx.cracks
	local used = math.min(spec.Cracks, math.floor(#cracks / 2))
	fx.used = used
	local material = spec.CrackMaterial or fx.baseMaterial
	if fx.mat ~= material then
		-- glowing lava / hellfire cracks (zone styles), else the asset's own material
		fx.mat = material
		for i = 1, #cracks do
			cracks[i].Material = material
		end
	end
	local base = math.atan2(-fx.dir.X, -fx.dir.Z)
	for c = 1, used do
		local a = base + TAU * (c - 1) / used + rng:NextNumber(-0.35, 0.35)
		local d1 = Vector3.new(-sin(a), 0, -cos(a))
		local kink = a + rng:NextNumber(-0.6, 0.6)
		local d2 = Vector3.new(-sin(kink), 0, -cos(kink))
		local length = rng:NextNumber(spec.CrackLength[1], spec.CrackLength[2])
		local l1 = length * rng:NextNumber(0.45, 0.6)
		fx.cs[2 * c - 1], fx.cd[2 * c - 1], fx.cl[2 * c - 1] = center + d1 * 0.3, d1, l1
		fx.cs[2 * c], fx.cd[2 * c], fx.cl[2 * c] = center + d1 * (0.3 + l1), d2, length - l1
		cracks[2 * c - 1].Color = spec.CrackColor
		cracks[2 * c].Color = spec.CrackColor
	end
	for i = used * 2 + 1, #cracks do
		cracks[i].Position = HIDDEN
	end
	-- chunks of the ground
	local chunks = fx.chunks
	local count = math.min(#chunks, spec.Chunks)
	if Runner.lowFx() then
		count = math.ceil(count / 2)
	end
	fx.chunkCount = count
	local chunkColor = (color or DEFAULT_GROUND):Lerp(Color3.new(0, 0, 0), 0.15)
	for i = 1, #chunks do
		local part = chunks[i]
		if i <= count then
			local a = rng:NextNumber(0, TAU)
			local out = rng:NextNumber(spec.ChunkOut[1], spec.ChunkOut[2])
			fx.kv[i] = Vector3.new(cos(a) * out, rng:NextNumber(spec.ChunkUp[1], spec.ChunkUp[2]), sin(a) * out)
			fx.kw[i] = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
			fx.ks[i] = rng:NextNumber(spec.ChunkSize[1], spec.ChunkSize[2])
			part.Color = chunkColor
		else
			part.Position = HIDDEN
		end
	end
	Runner.emit(fx)
	step(fx, 0)
	return true
end

function Ground.play(spec: any, character: Model, direction: Vector3, delay: number, tool: Instance?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local fx = Runner.acquire(spec.Asset)
	if not fx then
		return
	end
	if not fx.cracks and not setup(fx) then
		Runner.release(fx)
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	fx.dir = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
	fx.root, fx.character, fx.tool, fx.spec = root, character, tool, spec
	Runner.run(fx, delay, math.max(spec.Grow + spec.Hold + spec.Fade, spec.ChunkLife, fx.particleLife), begin, step)
end

function Ground.playAt(spec: any, position: Vector3, direction: Vector3, delay: number)
	local fx = Runner.acquire(spec.Asset)
	if not fx then
		return
	end
	if not fx.cracks and not setup(fx) then
		Runner.release(fx)
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	fx.dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	fx.root, fx.character, fx.tool, fx.spec, fx.at = nil, nil, nil, spec, position
	Runner.run(fx, delay, math.max(spec.Grow + spec.Hold + spec.Fade, spec.ChunkLife, fx.particleLife), begin, step)
end

return Ground
