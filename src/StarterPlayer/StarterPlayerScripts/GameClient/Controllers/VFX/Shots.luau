--!strict
-- Projectiles and muzzle flashes (OWNER: the VFX sub-agent; Config/CombatVFX Shot, Ranged, Magic.Bolt).
--   Shots.shot(ctx)    VFX.shot = Net "Projectile" { Origin, Direction, Speed, Distance, Style, Shooter? } (Ranged
--                      shots, enemy shots). The shooter = ctx.Shooter (the Player; nil for enemy shots), else (older
--                      callers) the player whose root matches the server muzzle (root + 1.2 up + 1.5 along the aim):
--                      its Tool gives the look (Config.Ranged.Kinds by WeaponId: Bow -> arrow,
--                      Crossbow -> bolt, Gun -> bullet; a Magic Tool -> orb) and the flight starts at the Tool's
--                      MuzzleAttachment; enemy shots ("Enemy") and unknown shooters fly the orb. Spark on arrival.
--                      A player's shot waits for the release of its swing (Shots.record, at most Config Shot.MaxHold s):
--                      the server sends it at the request, its hit lands at the release + the flight.
--   Shots.record(character, release)   VFX.swing (Ranged): the release is release s from now
--   Shots.kind(tool) -> "Bow" | "Crossbow" | "Gun" | "Orb"
--   Shots.flash(spec, character, direction, delay, tool?)   the muzzle flash (spec Kind = "Flash": Asset, Anchor,
--                      Counts[kind] = emit counts per weapon type, Emit = count multiplier); any particle asset
--                      works (e.g. a dust kick at the feet), played with its own colors; Emitters = { name = count }
--                      emits only those emitters (the zone styles' bursts)
--   Shots.fire(look, from, finish, travel, color, delay, character?, tool?, arrive?, origin?)   a cosmetic projectile
--                      (Magic release): from = a point, or the Tool's MuzzleAttachment at launch when character +
--                      tool are given, or origin (an Attachment, e.g. the left hand's) at launch; arrive(finish) is
--                      called on arrival
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Anchors = require(script.Parent.Anchors)
local Colors = require(script.Parent.Colors)
local Runner = require(script.Parent.Runner)

local Shots = {}

type Fx = Runner.Fx

local SHOOTER_LIFT = Vector3.new(0, 1.2, 0)

local releases: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

function Shots.record(character: Instance, release: number)
	releases[character] = os.clock() + release
end

function Shots.kind(tool: Instance?): string
	if not tool then
		return "Orb"
	end
	if tool:GetAttribute("Category") == "Magic" then
		return "Fireball"
	end
	local id = tool:GetAttribute("WeaponId")
	return if typeof(id) == "string" and Config.Ranged.Kinds[id] then Config.Ranged.Kinds[id] else Config.Ranged.Default
end

-- The player whose server muzzle (root + 1.2 up + 1.5 along the aim) is this origin.
local function shooter(origin: Vector3, dir: Vector3): (Model?, Instance?)
	local base = origin - dir * 1.5 - SHOOTER_LIFT
	local best: Model? = nil
	local bestDistance = Config.Ranged.ShooterRange
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local d = (root.Position - base).Magnitude
			if d < bestDistance then
				best, bestDistance = character, d
			end
		end
	end
	return best, if best then best:FindFirstChildOfClass("Tool") else nil
end

local function shotBegin(fx: Fx): boolean
	local from = fx.from
	local muzzle = fx.muzzle
	if muzzle and muzzle.Parent then
		from = muzzle.WorldPosition
	end
	local offset = fx.finish - from
	local distance = offset.Magnitude
	local unit = if distance > 1e-3 then offset / distance else Vector3.zAxis
	fx.origin, fx.unit, fx.distance = from, unit, distance
	local part = fx.part
	part.CFrame = CFrame.lookAt(from, from + unit)
	part.Transparency = 0
	local trail = fx.child.Trail
	if trail then
		trail:Clear()
		trail.Enabled = true
	end
	fx.arrived = false
	return true
end

local function shotStep(fx: Fx, t: number): boolean
	if fx.arrived then
		return true
	end
	if t < fx.travel then
		fx.part.Position = fx.origin + fx.unit * (fx.distance * t / fx.travel)
	else
		fx.arrived = true
		fx.part.Position = fx.finish
		fx.part.Transparency = if fx.stuck then 0 else 1 -- an arrow that hit a wall stays in it a moment
		local trail = fx.child.Trail
		if trail then
			trail.Enabled = false
		end
		local spark = fx.look.Spark
		if spark then
			local s = Runner.acquire(spark)
			if s then
				Runner.tint(s, fx.color)
				s.cf = CFrame.new(fx.finish)
				s.emitK = fx.look.SparkEmit or 1
				Runner.run(s, 0, s.particleLife + 0.05, Shots.sparkBegin, nil)
			end
		end
		local arrive = fx.arrive
		if arrive then
			fx.arrive = false
			arrive(fx.finish)
		end
	end
	return true
end

local function shotDone(fx: Fx)
	local trail = fx.child.Trail
	if trail then
		trail.Enabled = false
	end
	fx.arrive = false
	fx.muzzle = false
end

function Shots.sparkBegin(fx: Fx): boolean
	if fx.part then
		fx.part.CFrame = fx.cf
	end
	Runner.emit(fx, fx.emitK)
	return true
end

local function launch(look: any, from: Vector3, muzzle: Attachment?, finish: Vector3, travel: number, color: Color3, delay: number, arrive: any?, stuck: boolean?, scale: number?)
	local fx = Runner.acquire(look.Asset)
	if not fx or not fx.part then
		if fx then
			Runner.release(fx)
		end
		return
	end
	local part = fx.part
	if look.Size then
		local size = look.Size * (scale or 1)
		part.Size = Vector3.new(size, size, size)
	end
	part.Color = if look.Color then look.Color else color
	local trail = fx.child.Trail
	if trail then
		trail.Color = Runner.sequence(color)
	end
	fx.look, fx.from, fx.muzzle, fx.finish, fx.color = look, from, muzzle or false, finish, color
	fx.travel = math.max(Config.Shot.MinTime, travel)
	fx.arrive = arrive or false
	fx.done = shotDone
	fx.stuck = stuck == true
	Runner.run(fx, delay, fx.travel + (if stuck then Config.Shot.StuckSeconds else Config.Shot.TrailLife), shotBegin, shotStep)
end

function Shots.shot(ctx: { [string]: any })
	local origin, dir, speed, distance = ctx.Origin, ctx.Direction, ctx.Speed, ctx.Distance
	if not (typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and typeof(speed) == "number" and typeof(distance) == "number" and speed > 0 and dir.Magnitude > 1e-3) then
		return
	end
	local unit = dir.Unit
	local finish = origin + unit * distance
	if not (Runner.near(origin) or Runner.near(finish)) then
		return
	end
	local style = ctx.Style
	local looks = Config.Ranged.Looks
	local look, muzzle = looks.Enemy, nil
	local delay = 0
	if style ~= "Enemy" then
		local character: Model?, tool: Instance? = nil, nil
		local from = ctx.Shooter
		if typeof(from) == "Instance" and from:IsA("Player") then
			character = from.Character
			tool = if character then character:FindFirstChildOfClass("Tool") else nil
		else
			character, tool = shooter(origin, unit)
		end
		look = looks[Shots.kind(tool)] or looks.Orb
		if character and tool then
			muzzle = Anchors.attachment(tool, "MuzzleAttachment")
		end
		local releaseAt = if character then releases[character] else nil
		if releaseAt then
			local wait = releaseAt - os.clock()
			if wait > 0 and wait <= Config.Shot.MaxHold then
				delay = wait
			end
		end
	end
	launch(look, origin, muzzle, finish, distance / speed, Colors.style(style), delay, nil, ctx.Stuck, ctx.Size)
end

function Shots.fire(look: any, from: Vector3, finish: Vector3, travel: number, color: Color3, delay: number, character: Model?, tool: Instance?, arrive: any?, origin: Attachment?)
	local muzzle = if origin then origin elseif character and tool and tool.Parent == character then Anchors.attachment(tool, "MuzzleAttachment") else nil
	launch(look, from, muzzle, finish, travel, color, delay, arrive)
end

local function flashBegin(fx: Fx): boolean
	local root = fx.root
	if not root.Parent then
		return false
	end
	fx.part.CFrame = Anchors.frame(fx.spec, fx.character, root, fx.tool, fx.dir)
	Runner.emit(fx, fx.spec.Emit or 1, fx.flashCounts or nil)
	return true
end

function Shots.flash(spec: any, character: Model, direction: Vector3, delay: number, tool: Instance?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local fx = Runner.acquire(spec.Asset)
	if not fx then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	fx.dir = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
	fx.root, fx.character, fx.tool, fx.spec = root, character, tool, spec
	fx.flashCounts = if spec.Emitters then spec.Emitters elseif spec.Counts then spec.Counts[Shots.kind(tool)] or false else false
	Runner.tint(fx, nil)
	Runner.run(fx, delay, fx.particleLife + 0.05, flashBegin, nil)
end

return Shots
