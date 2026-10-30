--!strict
-- Magic casts (OWNER: the VFX sub-agent; Config/CombatVFX Magic, Swing.Magic). The cast circle under the caster is an
-- Arcs spec in Swing.Magic; this module draws the rest:
--   Casts.charge(spec, character, tool, color, release)   the charge orb at the staff's MuzzleAttachment (else the
--                        right hand; spec.Hand = "LeftHand": that hand) from now to the release (s): it grows and
--                        pulses, motes are drawn in
--   Casts.record(character, tool, release, color, grand?, hand?)   remembers the cast (VFX.swing, Magic); grand =
--                        the bigger area burst (Config Magic.Grand: GrandCast, MeteorDrop); hand = the bolt leaves
--                        that hand's grip attachment instead of the staff (Cast2: the left palm)
--   Casts.burst(position, radius, style) -> boolean        VFX.burst with an element / "Arcane" style (the server sends
--                        it at the cast start, the damage lands at the release): when a cast of the last LinkWindow s
--                        matches (caster within LinkRange), the bolt leaves the staff at the release and the area
--                        burst plays where it lands (true); false = no cast found
--   Casts.area(ground, radius, color, delay, grand?)       the area burst: a ring sized to the radius + flash, light
--                        column and motes (Magic_AreaBurst); grand adds Config Magic.Grand.Extra (more rings)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Anchors = require(script.Parent.Anchors)
local Arcs = require(script.Parent.Arcs)
local Colors = require(script.Parent.Colors)
local Runner = require(script.Parent.Runner)
local Shots = require(script.Parent.Shots)

local Casts = {}

type Fx = Runner.Fx
type Cast = { time: number, releaseAt: number, tool: Instance?, color: Color3, grand: boolean, hand: string? }

local casts: { [Instance]: Cast } = setmetatable({}, { __mode = "k" }) :: any
local UP = Vector3.yAxis

local function setContinuous(fx: Fx, on: boolean)
	local names = fx.spec.Continuous
	if not names then
		return
	end
	for i, e in ipairs(fx.emitters) do
		if names[fx.emitterNames[i]] then
			e.Enabled = on
		end
	end
end

local function chargePosition(fx: Fx): Vector3
	local hand = fx.hand
	if hand and hand.Parent then
		return hand.Position
	end
	local muzzle = fx.muzzle
	if muzzle and muzzle.Parent then
		return muzzle.WorldPosition
	end
	local root = fx.root
	return Anchors.position(fx.character, root, nil, "Hand")
end

local function chargeStep(fx: Fx, t: number): boolean
	local spec = fx.spec
	if not fx.root.Parent then
		return false
	end
	if t < fx.release then
		local k = t / fx.release
		local size = (spec.Size[1] + (spec.Size[2] - spec.Size[1]) * k) * (1 + spec.Pulse * math.sin(t * spec.PulseSpeed))
		local part = fx.part
		part.Size = Vector3.new(size, size, size)
		part.Position = chargePosition(fx)
	elseif not fx.released then
		fx.released = true
		fx.part.Transparency = 1
		setContinuous(fx, false)
	end
	return true
end

local function chargeBegin(fx: Fx): boolean
	if not fx.root.Parent then
		return false
	end
	fx.released = false
	local part = fx.part
	part.Color = fx.color
	part.Transparency = fx.spec.Transparency
	part.Position = chargePosition(fx)
	setContinuous(fx, true)
	return chargeStep(fx, 0)
end

local function chargeDone(fx: Fx)
	setContinuous(fx, false)
	fx.part.Transparency = 1
end

local running: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

function Casts.charge(spec: any, character: Model, tool: Instance?, color: Color3, release: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or release <= 0 then
		return
	end
	local fx = Runner.acquire(spec.Asset)
	if not fx or not fx.part then
		if fx then
			Runner.release(fx)
		end
		return
	end
	fx.spec, fx.root, fx.character, fx.color, fx.release = spec, root, character, color, release
	fx.muzzle = if tool and tool.Parent == character then Anchors.attachment(tool, "MuzzleAttachment") or false else false
	local hand = if spec.Hand then character:FindFirstChild(spec.Hand) else nil
	fx.hand = if hand and hand:IsA("BasePart") then hand else false
	fx.done = chargeDone
	Runner.tint(fx, color)
	Runner.run(fx, 0, release + spec.Linger, chargeBegin, chargeStep)
	running[character] = fx
end

-- A hold let go before its full charge: the flame goes out at once.
function Casts.stop(character: Model)
	local fx = running[character]
	if fx then
		running[character] = nil
		Runner.stop(fx)
	end
end

function Casts.record(character: Model, tool: Instance?, release: number, color: Color3, grand: boolean?, hand: string?)
	local cast = casts[character]
	if not cast then
		cast = { time = 0, releaseAt = 0, tool = nil, color = color, grand = false, hand = nil }
		casts[character] = cast
	end
	local now = os.clock()
	cast.time = now
	cast.releaseAt = now + release
	cast.tool = tool
	cast.color = color
	cast.grand = grand == true
	cast.hand = hand
end

function Casts.area(ground: Vector3, radius: number, color: Color3, delay: number, grand: boolean?)
	local spec = Config.Magic.Area
	local palette = Colors.flat(color)
	Arcs.playAt(spec, CFrame.new(ground + Vector3.new(0, spec.Lift, 0)), palette, delay, radius, color)
	if grand then
		for _, extra in ipairs(Config.Magic.Grand.Extra) do
			Arcs.playAt(extra, CFrame.new(ground + Vector3.new(0, extra.Lift or spec.Lift, 0)), palette, delay + (extra.Delay or 0), radius, color)
		end
	end
end

function Casts.burst(position: Vector3, radius: number, style: any): boolean
	local cfg = Config.Magic
	local now = os.clock()
	local caster: Instance? = nil
	local best: Cast? = nil
	for character, cast in pairs(casts) do
		if now - cast.time < cfg.LinkWindow and (not best or cast.time > best.time) then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = root.Position - position
				if Vector3.new(d.X, 0, d.Z).Magnitude <= cfg.LinkRange then
					caster, best = character, cast
				end
			end
		end
	end
	local ground = Runner.ground(position, 4, 20) or position
	local color = Colors.style(style)
	if not (caster and best) then
		return false
	end
	best.time = -math.huge -- one burst per cast
	local release = math.max(0, best.releaseAt - now)
	local root = caster:FindFirstChild("HumanoidRootPart") :: BasePart
	local from = root.Position + UP * 2
	local target = ground + UP * cfg.Bolt.Height
	local travel = math.clamp((target - from).Magnitude / cfg.Bolt.Speed, cfg.Bolt.MinTravel, cfg.Bolt.MaxTravel)
	local origin: Attachment? = nil
	if best.hand then
		local hand = caster:FindFirstChild(best.hand)
		local grip = hand and hand:FindFirstChild(best.hand == "LeftHand" and "LeftGripAttachment" or "RightGripAttachment")
		origin = if grip and grip:IsA("Attachment") then grip else nil
	end
	local grand = best.grand
	Shots.fire(cfg.Bolt, from, target, travel, color, release, caster :: Model, best.tool, function()
		Casts.area(ground, radius, color, 0, grand)
	end, origin)
	return true
end

return Casts
