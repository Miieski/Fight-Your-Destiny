--!strict
-- Plays the rig clips of Config/RigClips on a model's Motor6D joints (client only, through Motor6D.Transform).
-- Works the same on the part-built placeholders and on the imported Blender models: both use the joint names of
-- the clips (Body, Head, LegFL, ArmR, WingL, Seg2...). Two layers: locomotion (Idle / Walk / Run, cross-faded)
-- and one action on top (Attack1, Shoot, Attack2, Hit, Death, Spawn, Roar, Intro, Enrage, Wave, Talk).
--   local anim = AnimPlayer.new(model, family, size)   size = the model's height (length for serpents) in studs
--   anim:SetLocomotion(speed, walkSpeed)               each frame (studs / s)
--   anim:Action(name, { rate?, impactAt? (os.clock() time the clip's Impact must land), hold? })
--   anim:Update(dt)                                    each frame (writes the Transforms)
--   anim:Has(name)
-- When this module is not running, the joints stay in their rest pose.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RigClips = require(ReplicatedStorage.GameSystem.Config.RigClips)

local AnimPlayer = {}
AnimPlayer.__index = AnimPlayer

local FADE = 0.15
local ZERO = Vector3.zero

type Clip = { Length: number, Loop: boolean, Impact: number?, Tracks: { [string]: { r: { any }?, p: { any }? } } }
type Layer = { clip: Clip, name: string, time: number, rate: number, weight: number, target: number, impactAt: number?, startedAt: number, hold: boolean }

export type Player = typeof(setmetatable({} :: {
	joints: { [string]: Motor6D },
	clips: { [string]: Clip },
	scale: number,
	base: { [string]: Layer },
	baseName: string?,
	action: Layer?,
}, AnimPlayer))

-- Value of a key list at time t (smooth step between keys).
local function sample(keys: { any }, t: number): Vector3
	local n = #keys
	if n == 0 then
		return ZERO
	end
	local first = keys[1]
	if t <= first[1] then
		local v = first[2]
		return Vector3.new(v[1], v[2], v[3])
	end
	for i = 2, n do
		local b = keys[i]
		if t <= b[1] then
			local a = keys[i - 1]
			local span = b[1] - a[1]
			local k = if span > 0 then (t - a[1]) / span else 1
			k = k * k * (3 - 2 * k)
			local va, vb = a[2], b[2]
			return Vector3.new(va[1] + (vb[1] - va[1]) * k, va[2] + (vb[2] - va[2]) * k, va[3] + (vb[3] - va[3]) * k)
		end
	end
	local v = keys[n][2]
	return Vector3.new(v[1], v[2], v[3])
end

function AnimPlayer.new(model: Model, family: string, size: number?): Player
	local joints: { [string]: Motor6D } = {}
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part1 then
			joints[joint.Part1.Name] = joint
		end
	end
	local clips = (RigClips.Families :: any)[family] or {}
	local ref = (RigClips.RefSize :: any)[family] or size or 1
	local self = setmetatable({
		joints = joints,
		clips = clips,
		scale = (size or ref) / ref,
		base = {},
		baseName = nil,
		action = nil,
	}, AnimPlayer)
	return self
end

function AnimPlayer.Has(self: Player, name: string): boolean
	return self.clips[name] ~= nil
end

local function newLayer(clip: Clip, name: string, rate: number): Layer
	return { clip = clip, name = name, time = 0, rate = rate, weight = 0, target = 1, impactAt = nil, startedAt = os.clock(), hold = false }
end

-- Idle / Walk / Run from the current speed (the playback rate follows the speed).
function AnimPlayer.SetLocomotion(self: Player, speed: number, walkSpeed: number)
	local name = "Idle"
	local rate = 1
	if speed > 0.6 then
		if self.clips.Run and speed > walkSpeed * 0.75 then
			name, rate = "Run", math.clamp(speed / walkSpeed, 0.6, 1.6)
		elseif self.clips.Walk then
			name, rate = "Walk", math.clamp(speed / (walkSpeed * 0.55), 0.5, 1.8)
		end
	end
	if not self.clips[name] then
		name = "Idle"
	end
	local layer = self.base[name]
	if not layer and self.clips[name] then
		layer = newLayer(self.clips[name], name, rate)
		layer.weight = if next(self.base) == nil then 1 else 0
		self.base[name] = layer
	end
	for other, l in pairs(self.base) do
		l.target = if other == name then 1 else 0
	end
	if layer then
		layer.rate = rate
	end
	self.baseName = name
end

-- One action on top of the locomotion. opts.impactAt: os.clock() time the clip's Impact key must be reached
-- (the wind-up is stretched or squeezed to fit the server telegraph). opts.hold keeps the last frame (Death).
function AnimPlayer.Action(self: Player, name: string, opts: { [string]: any }?): boolean
	local clip = self.clips[name]
	if not clip then
		return false
	end
	local options = opts or {}
	local layer = newLayer(clip, name, options.rate or 1)
	layer.impactAt = options.impactAt
	layer.hold = options.hold == true
	layer.weight = if self.action then self.action.weight else 0
	self.action = layer
	return true
end

function AnimPlayer.ActionName(self: Player): string?
	return if self.action then self.action.name else nil
end

local function advance(layer: Layer, dt: number)
	local clip = layer.clip
	if layer.impactAt and clip.Impact then
		local now = os.clock()
		local windup = layer.impactAt - layer.startedAt
		if now < layer.impactAt and windup > 0 then
			layer.time = (now - layer.startedAt) / windup * clip.Impact
		else
			layer.time = clip.Impact + (now - layer.impactAt)
		end
	else
		layer.time += dt * layer.rate
	end
	if clip.Loop then
		layer.time %= clip.Length
	end
end

function AnimPlayer.Update(self: Player, dt: number)
	-- locomotion weights
	for name, layer in pairs(self.base) do
		advance(layer, dt)
		local step = dt / FADE
		layer.weight = if layer.target > layer.weight then math.min(layer.target, layer.weight + step) else math.max(layer.target, layer.weight - step)
		if layer.weight <= 0 and layer.target == 0 then
			self.base[name] = nil
		end
	end
	local action = self.action
	if action then
		advance(action, dt)
		local finished = not action.clip.Loop and action.time >= action.clip.Length
		if finished and not action.hold then
			action.target = 0
		end
		local step = dt / FADE
		action.weight = if action.target > action.weight then math.min(action.target, action.weight + step) else math.max(action.target, action.weight - step)
		if action.weight <= 0 and action.target == 0 then
			self.action = nil
			action = nil
		end
	end
	local scale = self.scale
	for name, joint in pairs(self.joints) do
		local rot, pos = ZERO, ZERO
		local total = 0
		for _, layer in pairs(self.base) do
			local track = layer.clip.Tracks[name]
			if layer.weight > 0 then
				total += layer.weight
				if track then
					if track.r then
						rot += sample(track.r, layer.time) * layer.weight
					end
					if track.p then
						pos += sample(track.p, layer.time) * layer.weight
					end
				end
			end
		end
		if total > 1 then
			rot /= total
			pos /= total
		end
		if action and action.weight > 0 then
			local track = action.clip.Tracks[name]
			local w = action.weight
			local t = math.min(action.time, action.clip.Length)
			local ar = if track and track.r then sample(track.r, t) else ZERO
			local ap = if track and track.p then sample(track.p, t) else ZERO
			rot = rot:Lerp(ar, w)
			pos = pos:Lerp(ap, w)
		end
		joint.Transform = CFrame.new(pos * scale) * CFrame.Angles(rot.X, rot.Y, rot.Z)
	end
end

return AnimPlayer
