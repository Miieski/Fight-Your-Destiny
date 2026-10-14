--!strict
-- Zone fighting styles (OWNER: the VFX sub-agent; numbers in Config/CombatVFX Zones + ZoneTiming, the brief is the Look
-- line of Config/CombatStyles; docs/COMBAT_CONTRACTS.md section 9). Every weapon adds its zone's accent on top of the
-- rarity color and element tint: VFX.swing / impact / land read the zone here (ctx.Zone, 1..12).
--   Styles.look(zone) -> Look?    the zone's entry of Config Zones (zone = 1..12 or a zone id; nil when unknown).
--                                 Dev hook: workspace.VFX attribute "Zone" (a zone id or index) forces that zone for
--                                 every effect (Play, Client command bar), e.g. to stage the 12 looks with one weapon
--   Styles.shed(tool, look, onDelay, offDelay)   the zone's Shed emitter (cloned once per Tool onto its TipAttachment)
--                                 emits from now + onDelay to now + offDelay
--   Styles.release(look) -> spec  the Flash spec of the zone's Release burst at the muzzle (Ranged / Magic), cached
--   Styles.beatTime(category, at, impact, air, late) -> number?   seconds (at x1) from the attack call to a signature
--                                 beat at overlay time `at` (finisher: the hit at 0.5; jump: dive 0.35, landing 0.6),
--                                 as the animation times its Style_<Zone>_Finisher / _Jump overlay on the clip; nil =
--                                 a melee jump beat after the dive starts (Dives / VFX.land draw those)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local CombatStyles = require(ReplicatedStorage.GameSystem.Config.CombatStyles)
local Anchors = require(script.Parent.Anchors)
local Runner = require(script.Parent.Runner)

local Styles = {}

type Fx = Runner.Fx

local FIN_HIT = 0.5 -- the overlays' markers (Config/CombatAnimations FIN / JUMP)
local JUMP_DIVE, JUMP_HIT = 0.35, 0.6

local records: { [Instance]: Fx } = setmetatable({}, { __mode = "k" }) :: any
local releases: { [any]: any } = {}

function Styles.look(zone: any): any?
	local forced = Runner.folder():GetAttribute("Zone")
	if forced ~= nil and forced ~= "" then
		zone = forced
	end
	local style = CombatStyles.get(zone)
	return if style then Config.Zones[style.Id] else nil
end

local function off(rec: Fx)
	local emitter = rec.emitter
	if emitter then
		emitter.Enabled = false
	end
end

local function on(rec: Fx): boolean
	local emitter = rec.emitter
	if not emitter or not emitter.Parent then
		return false
	end
	emitter.Enabled = true
	return true
end

function Styles.shed(tool: Instance?, look: any, onDelay: number, offDelay: number)
	if not tool or not look.Shed then
		return
	end
	local rec = records[tool]
	if not rec then
		-- emitters = the list Runner's Freeze hook pauses
		rec = Runner.track({ emitter = false, look = false, emitters = {}, done = off })
		records[tool] = rec
	end
	if rec.look ~= look then
		-- first swing of this Tool (or the dev Zone hook changed the zone): its zone's emitter on the tip
		rec.look = look
		if rec.emitter then
			rec.emitter:Destroy()
		end
		rec.emitter = false
		table.clear(rec.emitters)
		local tip = Anchors.attachment(tool, "TipAttachment")
		local source = Runner.template(look.Shed)
		if tip and source and source:IsA("ParticleEmitter") then
			local emitter = source:Clone()
			emitter.Enabled = false
			emitter.Parent = tip
			rec.emitter = emitter
			rec.emitters[1] = emitter
		end
	end
	if not rec.emitter then
		return
	end
	if rec.slot ~= 0 and rec.begun then
		rec.emitter.Enabled = false
	end
	Runner.run(rec, onDelay, math.max(0.02, offDelay - math.max(0, onDelay)), on, nil)
end

function Styles.release(look: any): any
	local spec = releases[look]
	if not spec then
		spec = { Kind = "Flash", Asset = look.Asset, Anchor = "Muzzle", Emitters = look.Release }
		releases[look] = spec
	end
	return spec
end

function Styles.beatTime(category: string, at: number, impact: number, air: boolean, late: boolean): number?
	local timing = Config.ZoneTiming
	if air then
		local dive = timing.JumpDive[category]
		if dive then
			-- melee: the hang [0, Dive]; the dive and the landing are drawn by Dives and VFX.land
			return if at <= JUMP_DIVE then at / JUMP_DIVE * dive else nil
		end
		-- Ranged / Magic hover: [0, Hit] then the recovery
		local length = timing.JumpLength[category] or impact * 2
		if at <= JUMP_HIT then
			return at / JUMP_HIT * impact
		end
		return impact + (at - JUMP_HIT) / (1 - JUMP_HIT) * math.max(0, length - impact)
	end
	local span = math.max(0, (timing.FinisherLength[category] or impact * 2) - impact)
	if late then
		-- the whole signature in the recovery: its wind-up part over the first LateSplit of it
		local split = timing.LateSplit
		if at <= FIN_HIT then
			return impact + at / FIN_HIT * split * span
		end
		return impact + (split + (at - FIN_HIT) / (1 - FIN_HIT) * (1 - split)) * span
	end
	if at <= FIN_HIT then
		return at / FIN_HIT * impact
	end
	return impact + (at - FIN_HIT) / (1 - FIN_HIT) * span
end

return Styles
