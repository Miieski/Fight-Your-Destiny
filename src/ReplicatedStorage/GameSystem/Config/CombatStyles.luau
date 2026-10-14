--!strict
-- Zone fighting styles (owner 2026-10-14: "Create different animations according to the zone weapon. So plains weapon
-- will have a different animation than the void one." Answers: 12 fighting styles, effects and sounds too).
-- Every weapon of a zone fights in that zone's style, whatever its category (Sword ... Magic): the animations
-- (Config/CombatAnimations), the effects (Config/CombatVFX) and the sounds (Config/CombatSfx) read the style of the
-- held weapon here. The Tool's "Zone" attribute (1..12) / its weapon's ZoneId picks the style.
-- Per style (descriptions are the brief for the animation / VFX / SFX owners; numbers stay in their own configs):
--   Name     the style's name
--   Moves    how the body moves: stance, rhythm, swing size, idle
--   Finisher the signature move layered on the combo finishers
--   Jump     the signature of the jump attacks (hang, dive, landing)
--   Look     the extra visual flavor of trails, impacts and landings (on top of the element color)
--   Sound    the extra sound flavor of swings, impacts and landings
local Zones = require(script.Parent.Zones)

export type Style = { Id: string, Index: number, Name: string, Moves: string, Finisher: string, Jump: string, Look: string, Sound: string }

local CombatStyles = {}

CombatStyles.List = {
	{ Id = "Plains", Name = "Squire",
		Moves = "clean, balanced, textbook: the base clips as they are (the reference every other style departs from)",
		Finisher = "none (the plain finisher)",
		Jump = "a straight, honest plunge",
		Look = "leaves and grass blades in the trail, a little dirt on impacts",
		Sound = "plain steel whooshes, no extra layer" },
	{ Id = "Desert", Name = "Dune Dancer",
		Moves = "flowing and wide: long curved swings, extra torso twist, low sweeping steps, the body keeps turning through the combo; idle sways like heat haze",
		Finisher = "a full-body spin before the strike (a whirling dervish)",
		Jump = "a corkscrew in the air before the dive",
		Look = "sand swirls and spiral streaks, sand bursts on impacts",
		Sound = "a sandy hiss under the whoosh, a soft sand burst on impacts" },
	{ Id = "Jungle", Name = "Feral",
		Moves = "low crouched hunter: fast snappy wind-ups, animal lunges, hips loose, head forward; idle prowls (slow breathing, shoulders rolling)",
		Finisher = "a pouncing leap into the strike",
		Jump = "a pounce: arms spread like claws, lands on all fours",
		Look = "leaf bursts and toxic droplets, claw-like triple streaks",
		Sound = "a short growl-breath on finishers, leaf rustle in the whoosh" },
	{ Id = "Tundra", Name = "Glacier",
		Moves = "heavy and deliberate: wide low stance, a held anticipation (freeze) before each strike, then a hard sharp release; stiff upper body",
		Finisher = "a frozen pause at the top, then a crushing release",
		Jump = "a long frozen hang, then a straight drop like an icicle",
		Look = "frost shards and ice crystals, a frost ring on landings",
		Sound = "an icy crack at the release, crunching ice impacts" },
	{ Id = "Swamp", Name = "Hexblade",
		Moves = "loose and unsettling: off-beat sways, hunched back, wrist flicks and twirls of the weapon, slightly late follow-throughs; idle rocks like a witch",
		Finisher = "a twirl of the weapon in the hand before the hit",
		Jump = "a crooked, off-balance drop with a twist",
		Look = "curse smoke and purple wisps, bubbles on impacts",
		Sound = "a whispery curse layer, a bubbling pop on impacts" },
	{ Id = "Volcano", Name = "Berserker",
		Moves = "aggressive: big overhead swings, exaggerated amplitude with overshoot, forward lean, stomping steps; idle heaves (heavy breathing)",
		Finisher = "a roaring two-step charge into an overshooting smash",
		Jump = "a high, explosive leap and a meteor-like crash",
		Look = "embers and lava sparks, scorch marks on landings",
		Sound = "a fiery roar layer, lava hiss on impacts" },
	{ Id = "Hell", Name = "Demon",
		Moves = "brutal and menacing: hunched shoulders, heavy overshoot, savage follow-throughs, a head tilt; idle loomy and twitchy",
		Finisher = "a savage spin with a downward rip",
		Jump = "a demonic dive with arms flung wide, a crater landing",
		Look = "hellfire flames and black smoke, red-black cracks",
		Sound = "a deep demonic rumble, fire bursts on impacts" },
	{ Id = "Heaven", Name = "Seraph",
		Moves = "graceful and upright: smooth slow-in / fast-out, high flourishes, light feet, chin up; idle floats lightly (a soft hover bob)",
		Finisher = "a radiant overhead flourish (arms opening like wings) before the strike",
		Jump = "a gentle hover with a halo-like pause, then a beam-like strike",
		Look = "light feathers and golden rays, a halo ring on landings",
		Sound = "a bright chime layer, a choir-like shimmer on finishers" },
	{ Id = "Dead", Name = "Revenant",
		Moves = "ghostly: drifting slow idle, then stuttering jerky strikes (held frames, sudden snaps), hunched, head lolling",
		Finisher = "a stutter-step teleport-like lunge",
		Jump = "a slow ghostly drift, then a sudden fall",
		Look = "ghost wisps and soul flames (green-cyan), a soul burst on landings",
		Sound = "a ghostly moan layer, hollow bone impacts" },
	{ Id = "Abyss", Name = "Tidecaller",
		Moves = "fluid like water: rolling torso waves, continuous flowing swings that carry into each other, swaying arms; idle drifts like seaweed",
		Finisher = "a rolling wave motion (body ripples from feet to blade)",
		Jump = "a dive like a breaching whale, a splash landing",
		Look = "water arcs and bubbles, a splash ring on landings",
		Sound = "a watery swoosh, splashes on impacts" },
	{ Id = "Mechanical", Name = "Automaton",
		Moves = "robotic and precise: linear moves between held poses (stepped, no easing), sharp snaps, exact angles, a stiff upright idle with small servo ticks",
		Finisher = "a mechanical wind-up (ratchet steps) and a piston release",
		Jump = "a rigid locked pose in the air, a piston-straight drop",
		Look = "electric sparks and hard-edged arcs, bolts on impacts",
		Sound = "servo whirs and clicks, an electric zap on impacts" },
	{ Id = "Void", Name = "Voidwalker",
		Moves = "warped and floating: the idle hovers a little above the ground, elastic timing (slow-motion wind-ups, then a snap), extra spins",
		Finisher = "a slow-motion spin that snaps into the strike",
		Jump = "a weightless float with a full flip, then a gravity-crushing slam",
		Look = "dark purple distortion, stars and gravity rings, a black-hole ring on landings",
		Sound = "a warped / reversed whoosh, a deep gravity thump on landings" },
} :: { Style }

CombatStyles.ById = {} :: { [string]: Style }
for index, style in ipairs(CombatStyles.List) do
	style.Index = index
	CombatStyles.ById[style.Id] = style
	assert(Zones.ById[style.Id] and Zones.ById[style.Id].Index == index, `CombatStyles: {style.Id} is not zone {index}`)
end

-- The style of a zone (index 1..12 or zone id); nil for anything else.
function CombatStyles.get(zone: any): Style?
	if typeof(zone) == "number" then
		return CombatStyles.List[zone]
	elseif typeof(zone) == "string" then
		return CombatStyles.ById[zone]
	end
	return nil
end

-- The style of a held weapon Tool (its "Zone" attribute), or nil.
function CombatStyles.ofTool(tool: Instance?): Style?
	return if tool then CombatStyles.get(tool:GetAttribute("Zone")) else nil
end

return CombatStyles
