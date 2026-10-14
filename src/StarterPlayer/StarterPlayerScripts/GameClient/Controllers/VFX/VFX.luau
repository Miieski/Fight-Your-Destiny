--!strict
-- Combat visual effects (docs/weapons_combat_brief.txt 4C, contract in docs/COMBAT_CONTRACTS.md).
-- OWNER: the VFX sub-agent (this folder, Config/CombatVFX, ReplicatedStorage.Assets.VFX). CombatController calls only
-- the functions below; keep their names and arguments. Effects are client-only and never decide damage.
--   VFX.play(name, cframe, options?)        one pooled effect from ReplicatedStorage.Assets.VFX.<name>: its emitters
--                                           Emit once. options: Color (Color3: recolors the Config.Tint emitters),
--                                           Emit (count multiplier), Delay (s), Life (s the clone stays; default: its
--                                           longest particle)
--   VFX.swing(ctx)        ctx = { Character, Tool?, Category, Step, Variant?, Finisher, Direction, Rarity?, Element?, Zone?, Speed, IsLocal, Position? }
--                         Variant = nil (combo step) | "Air" (jump attack) | "Dash" (dash strike)
--   VFX.land(ctx)         ctx = { Character?, Tool?, Category, Position, Radius, Rarity?, Element?, Zone?, IsLocal }
--                         (a melee jump attack hits the ground: local landing, or Net "AirSlam")
--   VFX.impact(ctx)       ctx = { Position, Category?, Crit, Finisher, Element?, Zone?, IsLocal }
--                         Zone = the weapon's zone 1..12 (zone fighting styles: the zone's accent, Styles)
--   VFX.shot(ctx)         ctx = { Origin, Direction, Speed, Distance, Style }      (Net "Projectile": Ranged, enemies)
--   VFX.burst(ctx)        ctx = { Position, Radius, Style }                         (Net "Burst": Magic area, Heavy slam)
--   VFX.roll(ctx)         ctx = { Character, Direction, IsLocal }
--   VFX.block(ctx)        ctx = { Character, On }
--   VFX.blockHit(ctx)     ctx = { Character, Position? }
--   VFX.damageNumber(position, text, kind)   kind = "normal" | "crit" | "hurt" | "block" | "dodge"
-- Swing (Config/CombatVFX Swing[category][step]; jump attacks AirSwing[category] timed on Combat.AirAttacks, dash
-- strikes DashSwing[category] timed on Combat.DashAttacks): the weapon Trail (Trails: rarity color + element tint) from
-- TrailOn x the time to the hit to TrailOff s after it, and the step's Effects, each timed on a hit of the step (Hit 0
-- = the call, 1 = Impact, 2 = the first of Hits) + Delay, all divided by the speed (a jump attack's Dive: Dives):
--   Kind "Arc" (Arcs: arcs, rings, straight streaks), "Lines" (Streaks: speed lines), "Ground" (Ground: cracks +
--   chunks), "Flash" (Shots.flash: muzzle flash by weapon type), "Charge" (Casts.charge: the Magic orb). Effects sit on
--   anchors (Anchors: root, feet, hand, Tool Tip / Muzzle / Impact attachments) read at their start, so they follow
--   the animation's pose at the hit. Magic casts are remembered (Casts) so the area burst follows the release.
-- Land (Config Land[category]): the landing shockwave of a melee jump attack at the ground point, sized by the hit
-- radius: flat rings, flash, dust (ground colored), debris, cracks (Heavy, Gauntlet), Spear spike, Dagger shadow.
-- Impact: sparks on the enemy's body toward the camera (crit burst, finisher beam ring, Dagger crit cross); a
-- confirmed local hit keeps the trail on through the hit-stop. Shot: Shots (arrow / bolt / bullet / orb by the
-- shooter's weapon). Burst: "Slam" = Heavy shockwave ring + dust ring, "Enemy" = disc, an element / "Arcane" = Magic
-- area (Casts). Block: a shield bubble following the character. Roll: a dust puff tinted by the ground + afterimages
-- (Ghosts: kept above the ground, no Neon; none with Low FX).
-- Zone styles (zone fighting styles, Styles + Config Zones; ctx.Zone = the weapon's zone 1..12): on top of the element
-- tint, each zone sheds its particles from the blade during melee swings (sand, leaves, embers, feathers...), draws its
-- arcs its way (Arcs modifiers: spiral, claws, serrated, rippling, stuttering, hard-edged, bolts, dark core), bursts its
-- particles at the Ranged / Magic release and on impacts (+ rings / bolts), colors the jump attack's dive, adds its own
-- landing, and plays signature beats timed on the animation's Style_<Zone>_Finisher / _Jump overlays.
-- Enemy death: a dissolve (workspace.Enemies "Dead"). Everything is pooled (Runner) under workspace.VFX; Low FX halves
-- the Emit counts, speed lines and chunks.
-- Dev hook (Play, Client command bar), plays an effect on the local character:
--   workspace.VFX:SetAttribute("Test", "swing:<step>:<rarity>[:<element>[:Air|Dash]]" (the equipped Tool's category)
--     | "land[:<category>[:<radius>]]" (at the feet; default: the equipped Tool's category and its jump attack radius)
--     | "impact:normal|crit|finisher[:<element>[:<category>]]" | "shot[:<style>]" | "burst:<style>" | "roll"
--     | "block:on|off" | "blockhit" | "number:<kind>")   (append "#n" to send the same command again)
--   (swing / land / impact use the equipped Tool's zone; workspace.VFX "Zone" = a zone id forces one, Styles)
-- Runner has the Freeze, Profile and LowFx hooks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)

local Runner = require(script.Parent.Runner)
local Colors = require(script.Parent.Colors)
local Trails = require(script.Parent.Trails)
local Arcs = require(script.Parent.Arcs)
local Streaks = require(script.Parent.Streaks)
local Ground = require(script.Parent.Ground)
local Shots = require(script.Parent.Shots)
local Casts = require(script.Parent.Casts)
local Numbers = require(script.Parent.Numbers)
local Ghosts = require(script.Parent.Ghosts)
local Dives = require(script.Parent.Dives)
local Styles = require(script.Parent.Styles)

local VFX = {}

type Fx = Runner.Fx

local player = Players.LocalPlayer
local UP = Vector3.yAxis
local NONE = table.freeze({})

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

-- Dust color: a base dust color mixed with the ground's color (Runner.ground), quantized so the tint cache stays small.
local function dustColor(groundColor: Color3?, base: Color3?, k: number?): Color3
	local c = base or Config.Roll.DustColor
	if groundColor then
		c = c:Lerp(groundColor, k or Config.Roll.DustGroundTint)
	end
	local function q(x: number): number
		return math.min(255, math.floor(x * 255 / 8 + 0.5) * 8)
	end
	return Color3.fromRGB(q(c.R), q(c.G), q(c.B))
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
	Runner.emit(fx, fx.emitK, fx.emitCounts or nil)
	return true
end

-- counts = { emitter name = Emit count } (only those emitters; the zone styles' bursts), else the asset's own counts
local function playEffect(name: string, cframe: CFrame, color: Color3?, emit: number?, delay: number?, life: number?, counts: { [string]: number }?)
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
	fx.emitCounts = counts or false
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
-- Swing: trail + the step's effects
-- ------------------------------------------------------------------------------------------------
local function paletteOf(effect: any, weapon: Colors.Palette, element: string?): Colors.Palette
	if effect.Palette == "Element" then
		return Colors.flat(Colors.style(element or "Arcane"))
	elseif effect.Color then
		return Colors.flat(effect.Color)
	end
	return weapon
end

-- One effect of a swing (or a zone signature beat) starting delay s from now; impact = s from now to the hit; mod = the
-- zone's Arc modifiers (Arcs; Claws add thinner copies of the Crescent slashes).
local function swingEffect(effect: any, delay: number, impact: number, speed: number, character: Model, dir: Vector3, palette: Colors.Palette, element: string?, tool: Instance?, mod: any?)
	local kind = effect.Kind or "Arc"
	if kind == "Arc" then
		local extra = if effect.HoldToHit then math.max(0, impact - delay) else 0
		local tint = if effect.Palette == "Element" then Colors.style(element or "Arcane") else nil
		local look = paletteOf(effect, palette, element)
		Arcs.play(effect, character, dir, look, delay, tool, extra, tint, mod)
		local claws = mod and mod.Claws
		if claws and effect.Shape ~= "Line" and (effect.Profile or "Crescent") == "Crescent" then
			for _, claw in ipairs(claws) do
				Arcs.play(effect, character, dir, look, delay + (claw.Delay or 0) / speed, tool, extra, tint, claw)
			end
		end
	elseif kind == "Lines" then
		Streaks.play(effect, character, dir, paletteOf(effect, palette, element), delay, tool)
	elseif kind == "Ground" then
		Ground.play(effect, character, dir, delay, tool)
	elseif kind == "Flash" then
		Shots.flash(effect, character, dir, delay, tool)
	elseif kind == "Charge" then
		Casts.charge(effect, character, tool, Colors.style(element or "Arcane"), math.max(0, impact - delay))
	end
end

function VFX.swing(ctx: { [string]: any })
	local started = os.clock()
	local character = ctx.Character
	local root = rootOf(character)
	local category = ctx.Category
	local combo = Combat.Combos[category]
	if root and combo and Runner.near(root.Position) then
		local stepIndex = if typeof(ctx.Step) == "number" then ctx.Step else 1
		local variant = if ctx.Variant == "Air" or ctx.Variant == "Dash" then ctx.Variant else nil
		local steps = Config.Swing[category]
		local info = WeaponCategories.ById[category]
		local def: { [string]: any }? = nil
		local spec: { [string]: any }? = nil
		if variant then
			def = (if variant == "Air" then Combat.AirAttacks else Combat.DashAttacks)[category]
			spec = (if variant == "Air" then Config.AirSwing else Config.DashSwing)[category]
		end
		def = def or combo[stepIndex] or combo[1]
		spec = spec or (if steps then steps[stepIndex] or steps[1] elseif info and info.Melee then Config.Swing.Default else nil)
		if spec then
			local speed = if typeof(ctx.Speed) == "number" and ctx.Speed > 0 then ctx.Speed else 1
			local impact1 = if def and typeof(def.Impact) == "number" then def.Impact else 0.15
			local impact = impact1 / speed
			local palette = Colors.weapon(ctx.Rarity, ctx.Element)
			local tool = ctx.Tool or character:FindFirstChildOfClass("Tool")
			local dir = flat(ctx.Direction) or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
			local element = if typeof(ctx.Element) == "string" then ctx.Element else nil
			local look = Styles.look(ctx.Zone)
			local mod = look and look.Arc
			if spec.TrailOn then
				Trails.swing(tool, palette, impact * spec.TrailOn, impact + spec.TrailOff / speed)
				if look then
					Styles.shed(tool, look, impact * spec.TrailOn, impact + spec.TrailOff / speed)
				end
			elseif look and look.Release and (category == "Ranged" or category == "Magic") then
				Shots.flash(Styles.release(look), character, dir, impact, tool)
			end
			local dive = spec.Dive
			if dive and variant == "Air" then
				Dives.play(dive, character, tool, palette, (if def and typeof(def.Hang) == "number" then def.Hang else 0) / speed, look and look.DiveColor)
			end
			local effects = spec.Effects
			if effects then
				local hits = def and def.Hits
				for _, effect in ipairs(effects) do
					local hit = effect.Hit or 1
					local at = impact
					if hit == 0 then
						at = 0
					elseif hit >= 2 and hits and hits[hit - 1] then
						at = hits[hit - 1] / speed
					end
					swingEffect(effect, math.max(0, at + (effect.Delay or 0) / speed), impact, speed, character, dir, palette, element, tool, mod)
				end
			end
			-- the zone's signature beats (finishers: Style_<Zone>_Finisher, jump attacks: the hang of Style_<Zone>_Jump)
			if look then
				local beats = nil
				local late = false
				if variant == "Air" then
					if not (look.JumpSkip and look.JumpSkip[category]) then
						beats = look.Jump
					end
				elseif variant == nil and ctx.Finisher then
					beats = look.Finisher
					late = look.LateOk == true and impact < Config.ZoneTiming.LateWindup
				end
				if beats then
					for _, beat in ipairs(beats) do
						local at = Styles.beatTime(category, beat.At or 0, impact1, variant == "Air", late)
						if at then
							swingEffect(beat, at / speed, impact, speed, character, dir, palette, element, tool, mod)
						end
					end
				end
			end
			if category == "Ranged" then
				-- the arrows of this shot (Net "Projectile", sent at the request) leave at the release
				Shots.record(character, impact)
			end
			if category == "Magic" and variant ~= "Dash" then
				-- the server's Burst of this cast is drawn from the release (BlinkBlast sends none: its blast is an effect)
				Casts.record(character, tool, impact, Colors.style(element or "Arcane"), spec.Grand == true, spec.Hand)
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
local zoneWindow, zoneCount = -math.huge, 0
local rng = Random.new()
local TAU = math.pi * 2
local PITCH90 = CFrame.Angles(math.rad(90), 0, 0)
local YAW90 = CFrame.Angles(0, math.rad(90), 0)

-- The zone's accent on a hit (zone styles): its particles (Impact counts) and its ImpactArcs, at most ZoneMax per
-- ZoneWindow s (a spin through a crowd).
local function zoneImpact(look: any, at: Vector3, cf: CFrame, category: string?, crit: boolean, started: number)
	local cfg = Config.Impact
	if started - zoneWindow > cfg.ZoneWindow then
		zoneWindow, zoneCount = started, 0
	end
	zoneCount += 1
	if zoneCount > cfg.ZoneMax then
		return
	end
	if look.Impact then
		playEffect(look.Asset, cf, nil, (cfg.CategoryEmit[category] or 1) * (if crit then cfg.ZoneCritK else 1), 0, nil, look.Impact)
	end
	local arcs = look.ImpactArcs
	local camera = workspace.CurrentCamera
	if arcs and camera then
		local face = CFrame.lookAt(at, camera.CFrame.Position)
		for _, arc in ipairs(arcs) do
			local palette = Colors.flat(arc.Color)
			if arc.Face == "Radial" then
				-- lines from the hit across the view, in random directions
				for _ = 1, arc.Count or 1 do
					Arcs.playAt(arc, face * CFrame.Angles(0, 0, rng:NextNumber(0, TAU)) * YAW90, palette, 0, nil, nil, look.Arc)
				end
			else
				Arcs.playAt(arc, face * PITCH90, palette, 0, nil, nil, look.Arc)
			end
		end
	end
end

function VFX.impact(ctx: { [string]: any })
	local started = os.clock()
	local position = ctx.Position
	if typeof(position) == "Vector3" and Runner.near(position) then
		local cfg = Config.Impact
		local at = impactPoint(position)
		local cf = CFrame.new(at)
		local tint = Colors.weapon(1, ctx.Element).spark
		local category = ctx.Category
		local look = Styles.look(ctx.Zone)
		if look then
			zoneImpact(look, at, cf, category, ctx.Crit == true, started)
		end
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
		if ctx.Crit then
			playEffect(cfg.Crit, cf, tint, cfg.CritEmit[category] or 1)
			local cross = cfg.CritCross[category]
			local camera = workspace.CurrentCamera
			if cross and camera then
				-- a quick X slash mark facing the camera
				local face = CFrame.lookAt(at, camera.CFrame.Position)
				local palette = Colors.flat(cfg.CritCrossColor)
				Arcs.playAt(cross, face * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(90), 0, 0), palette, 0)
				Arcs.playAt(cross, face * CFrame.Angles(0, 0, math.rad(-45)) * CFrame.Angles(math.rad(90), 0, 0), palette, cross.Second)
			end
		else
			playEffect(cfg.Normal, cf, tint, cfg.CategoryEmit[category] or 1)
		end
		if ctx.IsLocal then
			local hitStop = Combat.Feel.HitStop
			Trails.extend(player.Character, if ctx.Finisher then hitStop.Finisher elseif category == "Heavy" then hitStop.Heavy else hitStop.Normal)
		end
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Land: a melee jump attack hits the ground (combat V3)
-- ------------------------------------------------------------------------------------------------
-- The frame of a landing effect: the ground point looking along the attacker's facing, + Offset { right, up, back }
-- and Lift (world up), turned by Yaw / Pitch / Roll (degrees, as Anchors.frame).
local function landFrame(effect: any, ground: Vector3, dir: Vector3): CFrame
	local frame = CFrame.lookAt(ground, ground + dir)
	local o = effect.Offset
	if o then
		frame += frame:VectorToWorldSpace(Vector3.new(o[1], o[2], o[3]))
	end
	if effect.Lift then
		frame += Vector3.new(0, effect.Lift, 0)
	end
	if effect.Yaw or effect.Pitch or effect.Roll then
		frame *= CFrame.fromEulerAnglesYXZ(math.rad(effect.Pitch or 0), math.rad(effect.Yaw or 0), math.rad(effect.Roll or 0))
	end
	return frame
end

function VFX.land(ctx: { [string]: any })
	local started = os.clock()
	local character = ctx.Character
	if typeof(character) == "Instance" then
		Dives.land(character)
	end
	local position = ctx.Position
	if typeof(position) == "Vector3" and Runner.near(position) then
		local cfg = Config.Land
		local spec = cfg[ctx.Category] or cfg.Default
		local radius = if typeof(ctx.Radius) == "number" and ctx.Radius > 0 then ctx.Radius else cfg.DefaultRadius
		local hit, groundColor = Runner.ground(position, cfg.Probe, cfg.Probe)
		local ground = hit or position
		local root = rootOf(character)
		local dir = (if root then flat(root.CFrame.LookVector) else nil) or Vector3.new(0, 0, -1)
		local element = if typeof(ctx.Element) == "string" then ctx.Element else nil
		local palette = Colors.weapon(ctx.Rarity, element)
		local dust = dustColor(groundColor, cfg.DustColor, cfg.GroundTint)
		local earth: Colors.Palette? = nil -- the dust rings' palette (darker: beams are brightened)
		local scale = math.clamp(radius / cfg.RadiusRef, cfg.EmitScale[1], cfg.EmitScale[2])
		local look = Styles.look(ctx.Zone)
		local mod = look and look.Arc
		-- the category's landing, then the zone's (zone styles: its rings drawn its way, its particles)
		for pass = 1, 2 do
			local effects = if pass == 1 then spec.Effects elseif look then look.Land else nil
			for _, effect in ipairs(effects or NONE) do
				local kind = effect.Kind or "Ring"
				local delay = effect.Delay or 0
				local frame = landFrame(effect, ground, dir)
				if kind == "Ring" or kind == "Line" then
					local tone
					if effect.Palette == "Ground" then
						earth = earth or Colors.flat(dustColor(groundColor, cfg.RingColor, cfg.GroundTint))
						tone = earth
					else
						tone = paletteOf(effect, palette, element)
					end
					Arcs.playAt(effect, frame, tone, delay, if effect.Scale then radius else 1, nil, mod)
				elseif kind == "Burst" then
					local tint: Color3? = nil
					if effect.Tint == "Ground" then
						tint = dust
					elseif effect.Tint == "Weapon" then
						tint = palette.glow
					end
					playEffect(effect.Asset, frame, tint, (effect.Emit or 1) * (if effect.Fixed then 1 else scale), delay, nil, effect.Emitters)
				elseif kind == "Ground" then
					Ground.playAt(effect, frame.Position, dir, delay)
				end
			end
		end
	end
	Runner.measure(started)
end

-- ------------------------------------------------------------------------------------------------
-- Shots and bursts
-- ------------------------------------------------------------------------------------------------
function VFX.shot(ctx: { [string]: any })
	local started = os.clock()
	Shots.shot(ctx)
	Runner.measure(started)
end

local function discBegin(fx: Fx): boolean
	local part = fx.part
	part.CFrame = CFrame.new(fx.center) * CFrame.Angles(0, 0, math.pi / 2)
	part.Size = Vector3.new(0.2, 1, 1)
	part.Transparency = Config.Burst.Transparency
	return true
end

local function discStep(fx: Fx, t: number): boolean
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
	local position, radius, style = ctx.Position, ctx.Radius, ctx.Style
	if typeof(position) == "Vector3" and typeof(radius) == "number" and Runner.near(position) then
		local hit, groundColor = Runner.ground(position, 4, 20)
		local ground = hit or position
		if style == "Slam" then
			-- Heavy slam: the shockwave ring over the slam area + a dust ring sized to it (cracks and chunks come with the
			-- swing)
			local slam = Config.Slam
			Arcs.playAt(slam.Ring, CFrame.new(ground + Vector3.new(0, slam.Lift, 0)), Colors.flat(slam.Color), 0, radius)
			if slam.Dust then
				local land = Config.Land
				playEffect(slam.Dust, CFrame.new(ground + Vector3.new(0, slam.Lift, 0)), dustColor(groundColor, land.DustColor, land.GroundTint), math.clamp(radius / slam.DustRadius, 0.5, 1.5))
			end
		elseif style == "Enemy" then
			local cfg = Config.Burst
			local fx = Runner.acquire(cfg.Asset)
			if fx and fx.part then
				fx.part.Color = Colors.style(style)
				fx.radius = math.max(0.5, radius)
				fx.center = ground + Vector3.new(0, 0.15, 0)
				Runner.run(fx, 0, cfg.Grow + cfg.Fade, discBegin, discStep)
			elseif fx then
				Runner.release(fx)
			end
			playEffect(cfg.Spark, CFrame.new(ground + UP), Colors.style(style))
		elseif not Casts.burst(position, radius, style) then
			-- a Magic area without a known cast: at once
			Casts.area(ground, radius, Colors.style(style or "Arcane"), 0)
		end
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
		local cfg = Config.Roll
		local dir = flat(ctx.Direction) or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
		local hit, groundColor = Runner.ground(root.Position, 0.5, 8)
		local feet = (hit or (root.Position - Vector3.new(0, cfg.FeetDrop, 0))) + Vector3.new(0, cfg.DustLift, 0)
		playEffect(cfg.Dust, CFrame.lookAt(feet, feet - dir), dustColor(groundColor))
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
	fx.emitCounts = false
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
	local look = flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local front = root.Position + look * 5
	local tool = character:FindFirstChildOfClass("Tool")
	local zone = tool and tool:GetAttribute("Zone") -- (workspace.VFX "Zone" forces another one)
	if what == "swing" then
		local category = tool and tool:GetAttribute("Category") or "Sword"
		local stepIndex = tonumber(args[2]) or 1
		local combo = Combat.Combos[category]
		local variant = if args[5] == "Air" or args[5] == "Dash" then args[5] else nil
		VFX.swing({
			Character = character, Tool = tool, Category = category, Step = if variant then 1 else stepIndex, Variant = variant,
			Finisher = variant == "Air" or (variant == nil and combo ~= nil and combo[stepIndex] ~= nil and combo[stepIndex].Finisher == true),
			Direction = look, Rarity = tonumber(args[3]) or (tool and tool:GetAttribute("Rarity")) or 1,
			Element = if args[4] and args[4] ~= "" then args[4] else nil, Zone = zone, Speed = 1, IsLocal = true,
		})
	elseif what == "land" then
		local category = if args[2] and args[2] ~= "" then args[2] else (tool and tool:GetAttribute("Category") or "Sword")
		local air = Combat.AirAttacks[category]
		local feet = Runner.ground(root.Position, 0.5, 8) or (root.Position - Vector3.new(0, 3, 0))
		VFX.land({
			Character = character, Tool = tool, Category = category, Position = feet,
			Radius = tonumber(args[3]) or (air and air.Shape and air.Shape.Radius) or 6,
			Rarity = tool and tool:GetAttribute("Rarity") or 1, Element = nil, Zone = zone, IsLocal = true,
		})
	elseif what == "impact" then
		VFX.impact({ Position = front + Vector3.new(0, 3, 0), Crit = args[2] == "crit", Finisher = args[2] == "finisher", Element = args[3], Category = args[4], Zone = zone, IsLocal = false })
	elseif what == "shot" then
		VFX.shot({ Origin = root.Position + Vector3.new(0, 1.2, 0) + look * 1.5, Direction = look, Speed = 120, Distance = 30, Style = args[2] or "Nature" })
	elseif what == "burst" then
		VFX.burst({ Position = root.Position + look * 10, Radius = 6, Style = args[2] or "Arcane" })
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
-- every player's afterimages are made ahead of their first roll (nearby characters, spread over frames)
Ghosts.start()

return VFX
