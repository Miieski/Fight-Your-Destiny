--!strict
-- Weapon trails (OWNER: the VFX sub-agent; Config/CombatVFX Trail, Weapon, Swing). One Trail per equipped Tool,
-- cloned once from ReplicatedStorage.Assets.VFX.Shared_WeaponTrail between the Tool's BaseAttachment and
-- TipAttachment (found by name anywhere in the Tool, never by part names), colored by rarity (Colors.weapon) and
-- enabled only during the swing. Config Trail, with the Tool's category overrides from Config TrailByCategory.
--   Trails.swing(tool, palette, onDelay, offDelay)   on at now + onDelay, off at now + offDelay (no trail for Common)
--   Trails.finish(tool, seconds)                      a running trail stops at the latest seconds from now (the
--                                                     end of a jump attack's dive, Dives)
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
	local trail, second = rec.trail, rec.second
	if trail then
		trail.Enabled = false
	end
	if second then
		second.Enabled = false
	end
end

local function on(rec: Rec): boolean
	local trail = rec.trail
	if not trail or not trail.Parent then
		return false
	end
	trail:Clear()
	trail.Enabled = true
	local second = rec.second
	if second then
		second:Clear()
		second.Enabled = true
	end
	return true
end

local function setup(tool: Instance): Rec
	local rec: Rec = Runner.track({ trail = false, second = false, palette = false, done = off })
	records[tool] = rec
	local tip = tool:FindFirstChild("TipAttachment", true)
	local base = tool:FindFirstChild("BaseAttachment", true)
	local source = Runner.template("Shared_WeaponTrail")
	if not (tip and base and tip:IsA("Attachment") and base:IsA("Attachment") and tip.Parent and source) then
		return rec
	end
	local cfg = Config.Trail
	local category = tool:GetAttribute("Category")
	local over = if typeof(category) == "string" then Config.TrailByCategory[category] else nil
	local trail = source:Clone() :: Trail
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = if over and over.Lifetime then over.Lifetime else cfg.Lifetime
	trail.MinLength = cfg.MinLength
	trail.LightEmission = cfg.LightEmission
	trail.Brightness = cfg.Brightness
	trail.Transparency = seq(cfg.Transparency)
	trail.WidthScale = seq(cfg.WidthScale)
	trail.Enabled = false
	trail.Parent = tip.Parent
	rec.trail = trail
	-- a pair: the left copy trails too
	local offHand = tool:FindFirstChild("OffHand")
	local offTip = offHand and offHand:FindFirstChild("OffTipAttachment")
	local offBase = offHand and offHand:FindFirstChild("OffBaseAttachment")
	if offTip and offBase then
		local second = trail:Clone()
		second.Attachment0 = offBase
		second.Attachment1 = offTip
		second.Parent = offHand
		rec.second = second
	end
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
		if rec.second then
			rec.second.Color = palette.trail
		end
	end
	if rec.slot ~= 0 and rec.begun then
		trail.Enabled = false
	end
	Runner.run(rec, onDelay, math.max(0.02, offDelay - math.max(0, onDelay)), on, nil)
end

function Trails.finish(tool: Instance?, seconds: number)
	local rec = tool and records[tool]
	if rec and rec.slot ~= 0 then
		local at = Runner.now() + math.max(0, seconds)
		if at < rec.endAt then
			rec.endAt = at
		end
	end
end

return Trails
