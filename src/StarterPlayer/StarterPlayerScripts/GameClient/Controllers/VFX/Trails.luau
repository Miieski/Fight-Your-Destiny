--!strict
-- Weapon trails (OWNER: the VFX sub-agent; Config/CombatVFX Trail, Weapon, Swing). One Trail per equipped Tool,
-- cloned once from ReplicatedStorage.Assets.VFX.Shared_WeaponTrail between the Tool's BaseAttachment and
-- TipAttachment (found by name anywhere in the Tool, never by part names), colored by rarity (Colors.weapon) and
-- enabled only during the swing.
--   Trails.swing(tool, palette, onDelay, offDelay)   on at now + onDelay, off at now + offDelay (no trail for Common)
--   Trails.extend(character, seconds)                 a confirmed hit: keep the trail on through the hit-stop (once)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Runner = require(script.Parent.Runner)

local Trails = {}

type Rec = { [string]: any }

local records: { [Instance]: Rec } = setmetatable({}, { __mode = "k" }) :: any

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function off(rec: Rec)
	local trail = rec.trail
	if trail then
		trail.Enabled = false
	end
end

local function on(rec: Rec): boolean
	local trail = rec.trail
	if not trail or not trail.Parent then
		return false
	end
	trail:Clear()
	trail.Enabled = true
	return true
end

local function setup(tool: Instance): Rec
	local rec: Rec = Runner.track({ trail = false, palette = false, extended = false, done = off })
	records[tool] = rec
	local tip = tool:FindFirstChild("TipAttachment", true)
	local base = tool:FindFirstChild("BaseAttachment", true)
	local source = Runner.template("Shared_WeaponTrail")
	if not (tip and base and tip:IsA("Attachment") and base:IsA("Attachment") and tip.Parent and source) then
		return rec
	end
	local cfg = Config.Trail
	local trail = source:Clone() :: Trail
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = cfg.Lifetime
	trail.MinLength = cfg.MinLength
	trail.LightEmission = cfg.LightEmission
	trail.Brightness = cfg.Brightness
	trail.Transparency = seq(cfg.Transparency)
	trail.WidthScale = seq(cfg.WidthScale)
	trail.Enabled = false
	trail.Parent = tip.Parent
	rec.trail = trail
	return rec
end

function Trails.swing(tool: Instance?, palette: any, onDelay: number, offDelay: number)
	if not tool then
		return
	end
	local rec = records[tool] or setup(tool)
	local trail = rec.trail
	if not trail then
		return
	end
	if not palette.trail then
		Runner.stop(rec)
		return
	end
	if rec.palette ~= palette then
		rec.palette = palette
		trail.Color = palette.trail
	end
	if rec.slot ~= 0 and rec.begun then
		trail.Enabled = false
	end
	rec.extended = false
	Runner.run(rec, onDelay, math.max(0.02, offDelay - math.max(0, onDelay)), on, nil)
end

function Trails.extend(character: Model?, seconds: number)
	local tool = character and character:FindFirstChildOfClass("Tool")
	local rec = tool and records[tool]
	if rec and rec.slot ~= 0 and rec.begun and not rec.extended then
		rec.extended = true
		rec.endAt += seconds
	end
end

return Trails
