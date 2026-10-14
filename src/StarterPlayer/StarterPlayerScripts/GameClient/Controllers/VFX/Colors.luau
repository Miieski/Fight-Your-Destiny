--!strict
-- Weapon colors of the VFX (OWNER: the VFX sub-agent): trail / arc colors by rarity tier (Config/Rarities: Common
-- none, Uncommon green ... Divine and Secret gradients) with a subtle zone-element tint (Config/Combat StyleColors),
-- per Config/CombatVFX Weapon. Cached per (tier, element): no allocation after the first use.
--   Colors.weapon(tier?, element?) -> Palette
--     .trail     ColorSequence for the weapon Trail (nil = no trail: Common)
--     .arc       ColorSequence of the arc's outer beams      .core   of its white core
--     .gradient  the rarity's ColorSequence (Divine / Secret) or nil; Colors.segment(palette, n, i) slices it per beam
--     .spark     Color3 tint of the impact shards (nil = white)
--     .glow      Color3: the weapon color lightened toward white (landing flash sparks)
--   Colors.flat(color) -> Palette   one color (rings, special arcs), cached
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)

local Colors = {}

export type Palette = {
	tier: number,
	trail: ColorSequence?,
	arc: ColorSequence,
	core: ColorSequence,
	gradient: ColorSequence?,
	spark: Color3?,
	glow: Color3,
	segments: { [number]: { ColorSequence } },
}

local WHITE = Color3.new(1, 1, 1)
local cache: { [number]: { [string]: Palette } } = {}

-- Color of a ColorSequence at time u (0..1).
local function sample(sequence: ColorSequence, u: number): Color3
	local points = sequence.Keypoints
	for i = 2, #points do
		local b = points[i]
		if u <= b.Time then
			local a = points[i - 1]
			local span = b.Time - a.Time
			return if span > 1e-4 then a.Value:Lerp(b.Value, (u - a.Time) / span) else b.Value
		end
	end
	return points[#points].Value
end

local function build(tier: number, element: string): Palette
	local weapon = Config.Weapon
	local rarity = Rarities.get(tier)
	local elementColor: Color3? = Combat.StyleColors[element]
	local hasTrail = tier >= weapon.TrailFromTier
	local base = if hasTrail then rarity.Color else weapon.CommonColor
	if hasTrail and elementColor and not rarity.Gradient then
		base = base:Lerp(elementColor, weapon.ElementTint)
	end
	local trail: ColorSequence? = nil
	if hasTrail then
		trail = rarity.Gradient or ColorSequence.new({
			ColorSequenceKeypoint.new(0, base:Lerp(WHITE, weapon.HeadWhite)),
			ColorSequenceKeypoint.new(0.3, base),
			ColorSequenceKeypoint.new(1, base),
		})
	end
	return {
		tier = tier,
		trail = trail,
		arc = ColorSequence.new(base),
		core = ColorSequence.new(base:Lerp(WHITE, weapon.CoreWhite)),
		gradient = if hasTrail then rarity.Gradient else nil,
		spark = if elementColor then WHITE:Lerp(elementColor, weapon.SparkTint) else nil,
		glow = base:Lerp(WHITE, weapon.GlowWhite),
		segments = {},
	}
end

function Colors.weapon(tier: number?, element: string?): Palette
	local t = math.clamp(math.floor(tonumber(tier) or 1), 1, #Rarities.List)
	local key = if typeof(element) == "string" then element else ""
	local byElement = cache[t]
	if not byElement then
		byElement = {}
		cache[t] = byElement
	end
	local palette = byElement[key]
	if not palette then
		palette = build(t, key)
		byElement[key] = palette
	end
	return palette
end

-- The outer-beam color of segment i of an n-segment arc: the rarity gradient sliced along the arc, or the arc color.
function Colors.segment(palette: Palette, n: number, i: number): ColorSequence
	local gradient = palette.gradient
	if not gradient then
		return palette.arc
	end
	local list = palette.segments[n]
	if not list then
		list = {}
		for k = 1, n do
			list[k] = ColorSequence.new(sample(gradient, (k - 1) / n), sample(gradient, k / n))
		end
		palette.segments[n] = list
	end
	return list[i]
end

local flatCache: { [number]: Palette } = {}

function Colors.flat(color: Color3): Palette
	local key = math.floor(color.R * 255 + 0.5) * 65536 + math.floor(color.G * 255 + 0.5) * 256 + math.floor(color.B * 255 + 0.5)
	local palette = flatCache[key]
	if not palette then
		palette = {
			tier = 0,
			trail = nil,
			arc = ColorSequence.new(color),
			core = ColorSequence.new(color:Lerp(WHITE, Config.Weapon.CoreWhite)),
			gradient = nil,
			spark = nil,
			glow = color:Lerp(WHITE, Config.Weapon.GlowWhite),
			segments = {},
		}
		flatCache[key] = palette
	end
	return palette
end

-- Color3 of an element / shot style (Config/Combat StyleColors), Physical when unknown.
function Colors.style(style: any): Color3
	return Combat.StyleColors[style] or Combat.StyleColors.Physical
end

return Colors
