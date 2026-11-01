--!strict
-- How each gate opens (Controllers/GateController, Round 8 part 3). Data only: a new door type = a new row in Types, a new
-- gate = a line in Doors (key: the gate's MapPropId). The door pieces are the descendants of the gate's Barrier.
--   Mode "Hinge"      two leaves turn on their outer edges (Angle degrees, towards the next sub-zone)
--        "Slide"      two leaves slide apart into the walls (Distance studs >= leaf width + frame + 0.5, see Travel)
--        "CrackSlide" a glowing crack for CrackSeconds, then Slide (Glow, Shards = the ice burst)
--        "Rise"       the door rises (Height studs >= door height + 0.5)
--        "Fall"       the pieces drop one after the other with a bounce and fade away (Drop studs)
--        "Retract"    the pieces pull up and aside and fade away (Height studs)
--        "Fade"       the door dissolves
-- Sound: a name of Assets.Sounds, existing sounds as placeholders until door sounds are made. Dust: { Color, Burst }.
-- Shake: studs of camera shake (big stone and ice doors), only within ShakeRange. After a Rebirth a door whose sub-zone
-- is locked again goes back shut, silently.
-- Round 9: a door in its open pose is hidden for this player, whatever its Mode, so a leaf can never show in a wall. FadeFrom = where in
-- the opening (0..1) the leaves start to fade. Travel = the doors whose frame is wider than the type's Distance allows.
local DoorAnimations = {}

export type DoorType = {
	Mode: string,
	Seconds: number,
	Angle: number?,
	Distance: number?,
	Height: number?,
	Drop: number?,
	FadeFrom: number?,
	CrackSeconds: number?,
	Glow: Color3?,
	Sound: string?,
	Dust: { Color: Color3, Burst: number }?,
	Shake: number?,
}

local rgb = Color3.fromRGB
local DUST = rgb(196, 176, 150)
local SAND = rgb(226, 196, 140)
local SNOW = rgb(214, 234, 248)
local LEAF = rgb(112, 150, 74)
local STONE_SOUND = "Combat_Shared_LandCrack1"
local ICE_SOUND = "Combat_Style_Tundra_Crack1"
local WOOD_SOUND = "Unlock"

DoorAnimations.ShakeRange = 70
DoorAnimations.ShakeSeconds = 0.45

DoorAnimations.Types = {
	WoodDouble = { Mode = "Hinge", Seconds = 1.6, Angle = 88, FadeFrom = 0.72, Sound = WOOD_SOUND, Dust = { Color = DUST, Burst = 14 } },
	StoneSlide = { Mode = "Slide", Seconds = 1.8, Distance = 16.5, FadeFrom = 0.8, Sound = STONE_SOUND, Dust = { Color = DUST, Burst = 26 }, Shake = 0.12 },
	SandSlide = { Mode = "Slide", Seconds = 1.8, Distance = 16.5, FadeFrom = 0.8, Sound = STONE_SOUND, Dust = { Color = SAND, Burst = 30 }, Shake = 0.12 },
	StoneRise = { Mode = "Rise", Seconds = 1.8, Height = 16.5, FadeFrom = 0.75, Sound = STONE_SOUND, Dust = { Color = DUST, Burst = 26 }, Shake = 0.12 },
	Portcullis = { Mode = "Rise", Seconds = 1.2, Height = 16.5, FadeFrom = 0.75, Sound = WOOD_SOUND, Dust = { Color = DUST, Burst = 8 } },
	Plank = { Mode = "Fall", Seconds = 1.4, Drop = 13, Sound = STONE_SOUND, Dust = { Color = DUST, Burst = 16 } },
	Vine = { Mode = "Retract", Seconds = 1.4, Height = 12, Sound = WOOD_SOUND, Dust = { Color = LEAF, Burst = 18 } },
	Ice = { Mode = "CrackSlide", CrackSeconds = 0.5, Seconds = 1.5, Distance = 16.5, FadeFrom = 0.8, Glow = rgb(150, 230, 255), Sound = ICE_SOUND, Dust = { Color = SNOW, Burst = 30 }, Shake = 0.14 },
	Energy = { Mode = "Fade", Seconds = 1.1, Sound = "PortalEnter", Dust = { Color = rgb(200, 180, 255), Burst = 12 } },
} :: { [string]: DoorType }

DoorAnimations.Default = "Energy"

DoorAnimations.Doors = {
	gate_palisade = "WoodDouble", gate_barricade = "Plank", gate_mine = "StoneSlide",
	sandstone_wall_gate = "WoodDouble", canyon_barricade = "Plank", pylon_temple_gate = "SandSlide",
	jungle_palisade_gate = "WoodDouble", jungle_barricade_gate = "Vine", face_temple_gate = "StoneRise",
	tundra_palisade_gate = "WoodDouble", tundra_ice_rock_gate = "Ice", tundra_ice_castle_gate = "Ice",
	swamp_tree_gate = "WoodDouble", swamp_rock_gate = "Vine", swamp_skull_gate = "WoodDouble",
	volcano_gate_2 = "Plank", volcano_gate_3 = "Portcullis", volcano_gate_4 = "StoneSlide",
	hell_gate_2 = "Portcullis", hell_gate_3 = "StoneSlide", hell_gate_4 = "StoneSlide",
	heaven_gate_2 = "Energy", heaven_gate_3 = "Portcullis", heaven_gate_4 = "StoneSlide",
	dead_gate_2 = "Energy", dead_gate_3 = "Energy", dead_gate_4 = "StoneSlide",
	abyss_gate_2 = "Energy", abyss_gate_3 = "Energy", abyss_gate_4 = "StoneSlide",
	mechanical_gate_2 = "Portcullis", mechanical_gate_3 = "StoneSlide", mechanical_gate_4 = "StoneSlide",
	void_gate_2 = "Energy", void_gate_3 = "Energy", void_gate_4 = "Energy",
} :: { [string]: string }

-- leaf width 12 + the door's frame + 0.5, where the frame is wider than the 4 studs of the types' Distance
DoorAnimations.Travel = { hell_gate_4 = 17.5, heaven_gate_4 = 19, dead_gate_4 = 19.5 } :: { [string]: number }

-- how far the leaves of this door slide
function DoorAnimations.distanceOf(propId: any): number
	local own = if typeof(propId) == "string" then DoorAnimations.Travel[propId] else nil
	return own or DoorAnimations.typeOf(propId).Distance or 16.5
end

function DoorAnimations.typeOf(propId: any): DoorType
	local name = if typeof(propId) == "string" then DoorAnimations.Doors[propId] else nil
	return DoorAnimations.Types[name or DoorAnimations.Default]
end

-- The boss door transition (Controllers/BossDoorController): the veil's colour, the particles' colour per zone.
DoorAnimations.BossVeil = {
	Seconds = 0.9, -- BossService teleports after this
	FadeAt = 0.6, -- the short fade starts here, hidden by the light
	FadeSeconds = 0.25,
	ArriveSeconds = 0.75, -- the camera eases back, the character walks out
	WalkStuds = 7,
	Watchdog = 5, -- everything restored, whatever happened
	DoorFrame = 6, -- a leaf of a boss gate slides its own width + this + 0.5, then it is hidden
	RiseZones = { Desert = true, Abyss = true, Swamp = true } :: { [string]: boolean }, -- one leaf across the whole door: it rises instead
	Tints = {
		Plains = { rgb(255, 244, 200), rgb(190, 214, 130) }, Desert = { rgb(255, 228, 160), SAND },
		Jungle = { rgb(214, 255, 190), LEAF }, Tundra = { rgb(216, 240, 255), SNOW },
		Swamp = { rgb(200, 240, 170), rgb(150, 190, 90) }, Volcano = { rgb(255, 200, 130), rgb(255, 130, 60) },
		Hell = { rgb(255, 170, 130), rgb(220, 70, 40) }, Heaven = { rgb(255, 250, 220), rgb(255, 236, 170) },
		Dead = { rgb(210, 220, 240), rgb(160, 170, 200) }, Abyss = { rgb(170, 245, 240), rgb(60, 200, 200) },
		Mechanical = { rgb(200, 235, 255), rgb(120, 200, 240) }, Void = { rgb(220, 200, 255), rgb(150, 110, 240) },
	} :: { [string]: { Color3 } },
}

return DoorAnimations
