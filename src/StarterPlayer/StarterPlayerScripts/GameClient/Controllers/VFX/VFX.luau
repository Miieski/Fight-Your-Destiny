--!strict
-- Combat visual effects (docs/weapons_combat_brief.txt 4C, contract in docs/COMBAT_CONTRACTS.md).
-- OWNER: the VFX sub-agent (this folder, Config/CombatVFX, ReplicatedStorage.Assets.VFX). CombatController calls only
-- the functions below; keep their names and arguments. Effects are client-only and never decide damage.
--   VFX.play(name, cframe, options?)        one pooled effect from ReplicatedStorage.Assets.VFX.<name>: its emitters
--                                           Emit once. options: Color (Color3: recolors the Config.Tint emitters),
--                                           Emit (count multiplier), Delay (s), Life (s the clone stays; default: its
--                                           longest particle)
--   VFX.swing(ctx)        ctx = { Character, Tool?, Category, Step, Finisher, Direction, Rarity?, Element?, Speed, IsLocal, Position? }
--   VFX.impact(ctx)       ctx = { Position, Category?, Crit, Finisher, Element?, IsLocal }
--   VFX.shot(ctx)         ctx = { Origin, Direction, Speed, Distance, Style }      (Net "Projectile": Ranged, enemies)
--   VFX.burst(ctx)        ctx = { Position, Radius, Style }                         (Net "Burst": Magic area, Heavy slam)
--   VFX.roll(ctx)         ctx = { Character, Direction, IsLocal }
--   VFX.block(ctx)        ctx = { Character, On }
--   VFX.blockHit(ctx)     ctx = { Character, Position? }
--   VFX.damageNumber(position, text, kind)   kind = "normal" | "crit" | "hurt" | "block" | "dodge"
-- Swing: the weapon Trail (Trails, rarity color + element tint) from the end of the wind-up to the end of the
-- follow-through, and the category's arc (Arcs) at the hit = Combat.Combos[category][step].Impact / speed after the
-- call (Config/CombatVFX Swing). Impact: sparks on the enemy's body toward the camera (crit burst, finisher beam ring); a
-- confirmed local hit keeps the trail on through the hit-stop. Block: a shield bubble following the character.
-- Roll: dust puff + afterimages (Ghosts; none with Low FX). Enemy death: a dissolve (workspace.Enemies "Dead").
-- Everything is pooled (Runner) under workspace.VFX; Low FX halves the Emit counts.
-- Dev hook (Play, Client command bar), plays an effect on the local character:
--   workspace.VFX:SetAttribute("Test", "swing:<step>:<rarity>[:<element>]" | "impact:normal|crit|finisher" | "roll"
--     | "block:on|off" | "blockhit" | "number:<kind>")   (append "#n" to send the same command again)
-- Runner has the Freeze and Profile hooks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)

local Runner = require(script.Parent.Runner)
local Colors = require(script.Parent.Colors)
local Trails = require(script.Parent.Trails)
local Arcs = require(script.Parent.Arcs)
local Numbers = require(script.Parent.Numbers)
local Ghosts = require(script.Parent.Ghosts)

local VFX = {}

type Fx = Runner.Fx

local player = Players.LocalPlayer
local UP = Vector3.yAxis

local function rootOf(character: any): BasePart?
	local root = if typeof(character) == "Instance" then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function flat(v: any): Vector3?
	if typeof(v) ~= "Vector3" then
		return nil
	end
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

-- ------------------------------------------------------------------------------------------------
-- One-shot effects
-- ------------------------------------------------------------------------------------------------
local function playBegin(fx: Fx): boolean
	local part = fx.part
	if part then
		part.CFrame = fx.cf
	elseif fx.inst:IsA("Model") then
		(fx.inst :: Model):PivotTo(fx.cf)
	end
	Runner.emit(fx, fx.emitK)
	return true
end

local function playEffect(name: string, cframe: CFrame, color: Color3?, emit: number?, delay: number?, life: number?)
	if not Runner.near(cframe.Position) then
		return
	end
	local fx = Runner.acquire(name)
	if not fx then
		return
	end
	Runner.tint(fx, color)
	fx.cf = cframe
	fx.emitK = emit or 1
	Runner.run(fx, delay or 0, life or fx.particleLife + 0.05, playBegin, nil)
end

function VFX.play(name: string, cframe: CFrame, options: { [string]: any }?)
	local started = os.clock()
	if typeof(name) == "string" and typeof(cframe) == "CFrame" then
		local o = options or {}
		playEffect(
			name,
			cframe,
			if typeof(o.Color) == "Color3" then o.Color else nil,
			if typeof(o.Emit) == "number" then o.Emit else nil,
			if typeof(o.Delay) == "number" then o.Delay else nil,
			if typeof(o.Life) == "number" then o.Life else nil
		)
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Swing: trail + arc
-- ------------------------------------------------------------------------------------------------
function VFX.swing(ctx: { [string]: any })
	local started = os.clock()
	local character = ctx.Character
	local root = rootOf(character)
	local category = ctx.Category
	local combo = Combat.Combos[category]
	if root and combo and Runner.near(root.Position) then
		local stepIndex = if typeof(ctx.Step) == "number" then ctx.Step else 1
		local steps = Config.Swing[category]
		local info = WeaponCategories.ById[category]
		local spec = if steps then steps[stepIndex] or steps[1] elseif info and info.Melee then Config.Swing.Default else nil
		if spec then
			local speed = if typeof(ctx.Speed) == "number" and ctx.Speed > 0 then ctx.Speed else 1
			local def = combo[stepIndex] or combo[1]
			local impact = (if def and typeof(def.Impact) == "number" then def.Impact else 0.15) / speed
			local palette = Colors.weapon(ctx.Rarity, ctx.Element)
			local tool = ctx.Tool or character:FindFirstChildOfClass("Tool")
			Trails.swing(tool, palette, impact * spec.TrailOn, impact + spec.TrailOff / speed)
			if spec.Arc then
				Arcs.play(spec.Arc, character, flat(ctx.Direction) or root.CFrame.LookVector, palette, impact)
			end
		end
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Impact: sparks on the enemy body (toward the camera), crit burst, finisher ring
-- ------------------------------------------------------------------------------------------------
-- The hit position is sent above the enemy's head: put the spark on the matching enemy's body instead.
local function impactPoint(position: Vector3): Vector3
	local cfg = Config.Impact
	local enemies = workspace:FindFirstChild("Enemies")
	local best: BasePart? = nil
	local bestDistance = cfg.EnemyMatch
	if enemies then
		for _, model in ipairs(enemies:GetChildren()) do
			if model:IsA("Model") then
				local root = model.PrimaryPart or model:FindFirstChild("Root")
				if root and root:IsA("BasePart") then
					local p = root.Position
					local dy = position.Y - p.Y
					local d = Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude
					if d < bestDistance and dy > -2 and dy < 30 then
						best, bestDistance = root, d
					end
				end
			end
		end
	end
	if not best then
		return position - Vector3.new(0, cfg.FallbackDrop, 0)
	end
	local p = best.Position
	local camera = workspace.CurrentCamera
	local toward = flat(if camera then camera.CFrame.Position - p else nil)
	if toward then
		p += toward * (math.max(best.Size.X, best.Size.Z) * 0.5 * cfg.TowardCamera)
	end
	return p
end

local ringWindow, ringCount = -math.huge, 0

function VFX.impact(ctx: { [string]: any })
	local started = os.clock()
	local position = ctx.Position
	if typeof(position) == "Vector3" and Runner.near(position) then
		local cfg = Config.Impact
		local cf = CFrame.new(impactPoint(position))
		local tint = Colors.weapon(1, ctx.Element).spark
		if ctx.Finisher then
			if started - ringWindow > cfg.FinisherWindow then
				ringWindow, ringCount = started, 0
			end
			ringCount += 1
			if ringCount <= cfg.FinisherMax then
				local ring = cfg.Finisher
				local element: Color3? = Combat.StyleColors[ctx.Element]
				Arcs.playAt(ring, cf, Colors.flat(if element then ring.Color:Lerp(element, ring.Tint) else ring.Color), 0)
			end
		end
		playEffect(if ctx.Crit then cfg.Crit else cfg.Normal, cf, tint)
		if ctx.IsLocal then
			local hitStop = Combat.Feel.HitStop
			Trails.extend(player.Character, if ctx.Finisher then hitStop.Finisher elseif ctx.Category == "Heavy" then hitStop.Heavy else hitStop.Normal)
		end
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Shots (projectile + trail, spark on arrival) and bursts (ground disc)
-- ------------------------------------------------------------------------------------------------
local function shotBegin(fx: Fx): boolean
	local part = fx.part
	part.CFrame = CFrame.new(fx.origin)
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
		fx.part.Position = fx.origin + fx.dir * (fx.speed * t)
	else
		fx.arrived = true
		fx.part.Position = fx.finish
		fx.part.Transparency = 1
		local trail = fx.child.Trail
		if trail then
			trail.Enabled = false
		end
		playEffect(Config.Shot.Spark, CFrame.new(fx.finish), fx.color)
	end
	return true
end

local function shotDone(fx: Fx)
	local trail = fx.child.Trail
	if trail then
		trail.Enabled = false
	end
end

function VFX.shot(ctx: { [string]: any })
	local started = os.clock()
	local origin, dir, speed, distance = ctx.Origin, ctx.Direction, ctx.Speed, ctx.Distance
	if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and typeof(speed) == "number" and typeof(distance) == "number" and speed > 0 and dir.Magnitude > 1e-3 then
		local cfg = Config.Shot
		local unit = dir.Unit
		local finish = origin + unit * distance
		if Runner.near(origin) or Runner.near(finish) then
			local fx = Runner.acquire(cfg.Asset)
			if fx and fx.part then
				local color = Colors.style(ctx.Style)
				local size = if ctx.Style == "Enemy" then cfg.EnemySize else cfg.Size
				fx.part.Size = Vector3.new(size, size, size)
				fx.part.Color = color
				local trail = fx.child.Trail
				if trail then
					trail.Color = Runner.sequence(color)
				end
				fx.origin, fx.dir, fx.speed, fx.finish, fx.color = origin, unit, speed, finish, color
				fx.travel = math.max(cfg.MinTime, distance / speed)
				fx.done = shotDone
				Runner.run(fx, 0, fx.travel + cfg.TrailLife, shotBegin, shotStep)
			elseif fx then
				Runner.release(fx)
			end
		end
	end
	Runner.measure(started)
end

local function burstBegin(fx: Fx): boolean
	local part = fx.part
	part.CFrame = CFrame.new(fx.center) * CFrame.Angles(0, 0, math.pi / 2)
	part.Size = Vector3.new(0.2, 1, 1)
	part.Transparency = Config.Burst.Transparency
	return true
end

local function burstStep(fx: Fx, t: number): boolean
	local cfg = Config.Burst
	if t < cfg.Grow then
		local k = t / cfg.Grow
		k = 1 - (1 - k) * (1 - k)
		local d = 1 + (fx.radius * 2 - 1) * k
		fx.part.Size = Vector3.new(0.2, d, d)
	else
		local d = fx.radius * 2
		fx.part.Size = Vector3.new(0.2, d, d)
		fx.part.Transparency = cfg.Transparency + (1 - cfg.Transparency) * math.min(1, (t - cfg.Grow) / cfg.Fade)
	end
	return true
end

function VFX.burst(ctx: { [string]: any })
	local started = os.clock()
	local position, radius = ctx.Position, ctx.Radius
	if typeof(position) == "Vector3" and typeof(radius) == "number" and Runner.near(position) then
		local cfg = Config.Burst
		local ground = Runner.ground(position, 4, 20) or position
		local color = Colors.style(ctx.Style)
		local fx = Runner.acquire(cfg.Asset)
		if fx and fx.part then
			fx.part.Color = color
			fx.radius = math.max(0.5, radius)
			fx.center = ground + Vector3.new(0, 0.15, 0)
			Runner.run(fx, 0, cfg.Grow + cfg.Fade, burstBegin, burstStep)
		elseif fx then
			Runner.release(fx)
		end
		playEffect(cfg.Spark, CFrame.new(ground + UP), color)
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Block: shield bubble (pop in, follows the character, pulses on a blocked hit, shrinks away)
-- ------------------------------------------------------------------------------------------------
local bubbles: { [Instance]: Fx } = {}

local function bubbleStep(fx: Fx, t: number): boolean
	local root = fx.root
	if not root.Parent then
		return false
	end
	local cfg = Config.Block
	local part, flash = fx.part, fx.flash
	local s
	if fx.closing then
		local c = (t - fx.closeAt) / cfg.OffTime
		if c >= 1 then
			return false
		end
		s = 1 - 0.25 * c
		part.Transparency = c
		if flash then
			flash.Transparency = 1
		end
	else
		local p = math.min(1, t / cfg.PopTime) - 1
		s = cfg.PopFrom + (1 - cfg.PopFrom) * (1 + 2.7 * p * p * p + 1.7 * p * p)
		local h = t - fx.hitAt
		if fx.hitAt >= 0 and h < cfg.HitPulseTime then
			s *= 1 + (cfg.HitPulse - 1) * (1 - h / cfg.HitPulseTime)
		end
		if flash then
			flash.Transparency = cfg.FlashFrom + (1 - cfg.FlashFrom) * math.min(1, (t - fx.flashAt) / cfg.FlashTime)
		end
	end
	local d = cfg.Size * s
	local size = Vector3.new(d, d, d)
	local at = root.Position + Vector3.new(0, cfg.Height, 0)
	part.Size = size
	part.Position = at
	if flash then
		flash.Size = size
		flash.Position = at
	end
	return true
end

local function bubbleBegin(fx: Fx): boolean
	fx.part.Transparency = 0
	return bubbleStep(fx, 0)
end

local function bubbleDone(fx: Fx)
	if fx.owner and bubbles[fx.owner] == fx then
		bubbles[fx.owner] = nil
	end
end

function VFX.block(ctx: { [string]: any })
	local started = os.clock()
	local character = ctx.Character
	local current = if typeof(character) == "Instance" then bubbles[character] else nil
	if ctx.On then
		local root = rootOf(character)
		if current and current.slot ~= 0 then
			if current.closing then
				current.closing = false
				current.hitAt = -1
				current.flashAt = 0
				Runner.run(current, 0, 1e6, bubbleBegin, bubbleStep)
			end
		elseif root and Runner.near(root.Position) then
			local fx = Runner.acquire(Config.Block.Asset)
			if fx and fx.part then
				fx.root = root
				fx.flash = fx.child.Flash
				fx.owner = character
				fx.closing = false
				fx.hitAt = -1
				fx.flashAt = 0
				fx.done = bubbleDone
				bubbles[character] = fx
				Runner.run(fx, 0, 1e6, bubbleBegin, bubbleStep)
			elseif fx then
				Runner.release(fx)
			end
		end
	elseif current and current.slot ~= 0 and not current.closing then
		current.closing = true
		current.closeAt = Runner.now() - current.startAt
	end
	Runner.measure(started)
end

-- Direction from the character to the nearest living enemy within range (flat), or nil.
local function enemyDirection(from: Vector3, range: number): Vector3?
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	local best: Vector3? = nil
	local bestDistance = range
	for _, model in ipairs(enemies:GetChildren()) do
		if model:IsA("Model") and not model:GetAttribute("Dead") then
			local offset = model:GetPivot().Position - from
			local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if d < bestDistance and d > 0.1 then
				best, bestDistance = offset, d
			end
		end
	end
	return flat(best)
end

function VFX.blockHit(ctx: { [string]: any })
	local started = os.clock()
	local character = ctx.Character
	local root = rootOf(character)
	local cfg = Config.Block
	if root and Runner.near(root.Position) then
		local dir = enemyDirection(root.Position, cfg.EnemyRange) or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
		local at = root.Position + Vector3.new(0, cfg.Height, 0) + dir * (cfg.Size * 0.5)
		playEffect(cfg.HitAsset, CFrame.lookAt(at, at + dir))
		local bubble = bubbles[character]
		if bubble and bubble.slot ~= 0 and bubble.begun and not bubble.closing then
			local t = Runner.now() - bubble.startAt
			bubble.hitAt = t
			bubble.flashAt = t
		end
	elseif typeof(ctx.Position) == "Vector3" then
		playEffect(cfg.HitAsset, CFrame.new(ctx.Position))
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Roll: dust puff kicked backward + afterimages
-- ------------------------------------------------------------------------------------------------
function VFX.roll(ctx: { [string]: any })
	local started = os.clock()
	local character = ctx.Character
	local root = rootOf(character)
	if root and Runner.near(root.Position) then
		local dir = flat(ctx.Direction) or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
		local feet = Runner.ground(root.Position, 0.5, 8) or (root.Position - Vector3.new(0, Config.Roll.FeetDrop, 0))
		feet += Vector3.new(0, 0.2, 0)
		playEffect(Config.Roll.Dust, CFrame.lookAt(feet, feet - dir))
		Ghosts.play(character :: Model)
	end
	Runner.measure(started)
end

function VFX.damageNumber(position: Vector3, text: string, kind: string)
	local started = os.clock()
	Numbers.show(position, text, kind)
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Enemy death dissolve (on top of EnemyController's fade), from workspace.Enemies "Dead"
-- ------------------------------------------------------------------------------------------------
local deathConns: { [Instance]: RBXScriptConnection } = {}

local function dissolve(model: Model)
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok or not Runner.near(cf.Position) then
		return
	end
	local cfg = Config.Death
	local fx = Runner.acquire(cfg.Asset)
	if not fx then
		return
	end
	if not fx.part then
		Runner.release(fx)
		return
	end
	fx.part.Size = Vector3.new(math.min(size.X, cfg.MaxSize), math.min(size.Y, cfg.MaxSize), math.min(size.Z, cfg.MaxSize))
	Runner.tint(fx, nil)
	fx.cf = cf
	fx.emitK = 1
	Runner.run(fx, cfg.Delay, fx.particleLife + 0.1, playBegin, nil)
end

local function watchEnemy(model: Instance)
	if not model:IsA("Model") or deathConns[model] then
		return
	end
	deathConns[model] = model:GetAttributeChangedSignal("Dead"):Connect(function()
		if model:GetAttribute("Dead") then
			dissolve(model)
		end
	end)
end

-- ------------------------------------------------------------------------------------------------
-- Dev hook
-- ------------------------------------------------------------------------------------------------
local function test(command: string)
	local character = player.Character
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	local args = string.split(string.split(command, "#")[1], ":")
	local what = args[1]
	local look = root.CFrame.LookVector
	local front = root.Position + look * 5
	if what == "swing" then
		local tool = character:FindFirstChildOfClass("Tool")
		local category = tool and tool:GetAttribute("Category") or "Sword"
		local stepIndex = tonumber(args[2]) or 1
		local combo = Combat.Combos[category]
		VFX.swing({
			Character = character, Tool = tool, Category = category, Step = stepIndex,
			Finisher = combo ~= nil and combo[stepIndex] ~= nil and combo[stepIndex].Finisher == true,
			Direction = look, Rarity = tonumber(args[3]) or (tool and tool:GetAttribute("Rarity")) or 1,
			Element = if args[4] and args[4] ~= "" then args[4] else nil, Speed = 1, IsLocal = true,
		})
	elseif what == "impact" then
		VFX.impact({ Position = front + Vector3.new(0, 3, 0), Crit = args[2] == "crit", Finisher = args[2] == "finisher", Element = args[3], IsLocal = false })
	elseif what == "roll" then
		VFX.roll({ Character = character, Direction = look, IsLocal = true })
	elseif what == "block" then
		VFX.block({ Character = character, On = args[2] ~= "off" })
	elseif what == "blockhit" then
		VFX.blockHit({ Character = character, Position = root.Position + Vector3.new(0, 3, 0) })
	elseif what == "number" then
		local kind = args[2] or "normal"
		VFX.damageNumber(front + Vector3.new(0, 3, 0), if kind == "crit" then "1,234!" else "567", kind)
	end
end

-- ------------------------------------------------------------------------------------------------
-- Start (runs once, when CombatController requires this module)
-- ------------------------------------------------------------------------------------------------
Runner.start()
task.spawn(Numbers.prewarm)
do
	local f = Runner.folder()
	f:GetAttributeChangedSignal("Test"):Connect(function()
		local command = f:GetAttribute("Test")
		if typeof(command) == "string" and command ~= "" then
			test(command)
		end
	end)
end
task.spawn(function()
	local enemies = workspace:WaitForChild("Enemies", 60)
	if not enemies then
		return
	end
	for _, model in ipairs(enemies:GetChildren()) do
		watchEnemy(model)
	end
	enemies.ChildAdded:Connect(watchEnemy)
	enemies.ChildRemoved:Connect(function(model)
		local conn = deathConns[model]
		if conn then
			conn:Disconnect()
			deathConns[model] = nil
		end
	end)
end)
-- the local character's afterimages are made ahead of its first roll
local function prepare(character: Model)
	task.delay(1, Ghosts.prepare, character)
end
player.CharacterAppearanceLoaded:Connect(prepare)
if player.Character and player:HasAppearanceLoaded() then
	prepare(player.Character)
end

return VFX
