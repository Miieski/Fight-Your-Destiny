--!strict
-- Effects and small animations of the upgraded map props (docs/model_upgrade_brief.txt section 7). Client only:
-- GameClient/Controllers/PropFX reads this table and drives the props tagged "MapProp" (attribute MapPropId).
-- Effects run only near the local player (on within NEAR studs, off beyond FAR, checked CHECK_HZ times a second).
-- Low FX (Settings) turns off particles, sway and flicker; the static lights stay on.
--
-- Per propId (all optional; a part name matches "<Part>" or the Blender glow name "<Part>_Glow", searched in the
-- prop's descendants):
--   Lights    = { { Part | Attachment, Color, Brightness, Range } } static PointLights that the template carries
--               (StudioProps / DevTools.ApplyPropMeshes add them, on the part or on the named data Attachment;
--               Shadows always false). Not created by the client.
--   Particles = { { Attachment, Color, Rate, Lifetime {min, max}, Size, Speed? (number or {min, max}), SizeEnd?,
--               Transparency? {start, end}, Spread? (deg, default 180), Acceleration? {x, y, z}, Drag?, Texture?,
--               LightEmission?, LightInfluence?, RotSpeed? } } ParticleEmitters that DevTools.ApplyPropMeshes puts
--               (off) on the data attachments ("PropFX_<Attachment>", default sparkle texture) under the Root part of a
--               Blender prop (PiecesRoot for the stall pieces). List that part in Emitters so the client runs them.
--   Flicker   = { { Part | Attachment, Amount, Hz } }    the PointLight(s) under Part / the Attachment: brightness
--                                                        +-Amount at about Hz (a slow Hz = a soft pulse)
--   Emitters  = { Part }                                  ParticleEmitters / Beams under Part: on near, off far / Low FX
--   Sway      = { { Part, Degrees, Seconds, Axis, Hinge } } gentle back-and-forth turn (+-Degrees, one period = Seconds)
--                                                        of every part named Part around its own Axis ("X" or "Z",
--                                                        default "Z"); Hinge "Top" turns it around its top edge
--                                                        (cloth hanging from a bar), Hinge "Pivot" around the part's
--                                                        pivot (Blender meshes: hinge / hat / straw pivots of the
--                                                        data). Parts listed with the same numbers move together.
--   Spin      = { { Part, Seconds?, Bob?, BobSeconds? } } a slow full turn around the vertical axis through the part's
--                                                        centre (one turn = Seconds) and a float up by Bob studs and
--                                                        back to its place (one period = BobSeconds; never below its
--                                                        place); same numbers = in step
--   Scroll    = { { Part, U?, V? } }                      the Textures under Part (the "Ripples" water overlay) slide
--                                                        by U / V studs per second (falling streams: V)
-- Low FX also stops Spin and Scroll (static, like Sway).
-- A prop nested in another prop (for example the lantern of a lamp post) is its own MapProp: its effects come from
-- its own entry. Debug (client): workspace.CurrentCamera attributes PropFX_Tracked / _Active / _Flicker / _Sway /
-- _Emitting / _LowFx count what the controller drives right now.
local rgb = Color3.fromRGB

export type Light = { Part: string?, Attachment: string?, Color: Color3, Brightness: number, Range: number }
export type Particle = {
	Attachment: string, Color: Color3, Rate: number, Lifetime: { number }, Size: number, Speed: (number | { number })?,
	SizeEnd: number?, Transparency: { number }?, Spread: number?, Acceleration: { number }?, Drag: number?,
	Texture: string?, LightEmission: number?, LightInfluence: number?, RotSpeed: number?,
}
export type Flicker = { Part: string?, Attachment: string?, Amount: number, Hz: number }
export type Sway = { Part: string, Degrees: number, Seconds: number, Axis: string?, Hinge: string? }
export type Spin = { Part: string, Seconds: number?, Bob: number?, BobSeconds: number? }
export type Scroll = { Part: string, U: number?, V: number? }
export type Entry = {
	Lights: { Light }?, Particles: { Particle }?, Flicker: { Flicker }?, Emitters: { string }?, Sway: { Sway }?,
	Spin: { Spin }?, Scroll: { Scroll }?,
}

local PropFX = {}

PropFX.NEAR = 80 -- studs: effects switch on within this distance of the local character
PropFX.FAR = 100 -- studs: and off beyond this one (the gap avoids on/off flapping)
PropFX.CHECK_HZ = 4 -- distance checks per second
PropFX.MAX_EMITTER_PROPS = 6 -- at most this many props with particles run at once (the nearest ones)

-- Roblox built-in particle textures (no upload)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- a small still twinkle (the default sparkle texture)
local function glint(attachment: string, color: Color3, rate: number, size: number?): Particle
	return { Attachment = attachment, Color = color, Rate = rate, Lifetime = { 0.4, 0.8 }, Size = size or 0.45, Speed = 0 }
end

-- the fountain: soft mist where the 6 streams land, glints on the water
local fountainParticles: { Particle } = {}
for i = 1, 6 do
	table.insert(fountainParticles, {
		Attachment = "Mist" .. i, Color = rgb(225, 248, 255), Rate = 1.2, Lifetime = { 1.0, 1.6 }, Size = 1.2, SizeEnd = 2.6,
		Transparency = { 0.65, 1 }, Speed = { 0.8, 1.6 }, Spread = 35, Acceleration = { 0, 0.4, 0 }, Texture = SMOKE,
		LightEmission = 0.2, RotSpeed = 20,
	})
end
for i = 1, 3 do
	table.insert(fountainParticles, glint("Glint" .. i, rgb(230, 255, 255), 0.4, 0.5))
end

PropFX.Props = {
	crate = {}, -- no effect
	barrel = {}, -- no effect
	-- the warm lantern flame (also the lantern hanging from every lamp post)
	lantern = {
		Lights = { { Part = "Flame", Color = rgb(255, 210, 140), Brightness = 1.2, Range = 16 } },
		Flicker = { { Part = "Flame", Amount = 0.08, Hz = 6 } },
	},
	lamp_post = {}, -- its lantern is a nested "lantern" prop
	-- the three cloths of the drying rack, each a little out of step
	laundry_rack = {
		Sway = {
			{ Part = "ClothA", Degrees = 2.5, Seconds = 3.4, Axis = "X", Hinge = "Top" },
			{ Part = "ClothB", Degrees = 3.0, Seconds = 2.9, Axis = "X", Hinge = "Top" },
			{ Part = "ClothC", Degrees = 2.0, Seconds = 3.8, Axis = "X", Hinge = "Top" },
		},
	},
	-- batch 2 (Blender props: active once the owner imports them; checked with the Studio previews)
	-- the top valve opens and closes about 12 degrees on its hinge (6 s loop) and the pearl glints now and then
	clam_pearl = {
		Sway = {
			{ Part = "ShellTop", Degrees = 6, Seconds = 6, Axis = "X", Hinge = "Pivot" },
			{ Part = "ShellTopInner", Degrees = 6, Seconds = 6, Axis = "X", Hinge = "Pivot" },
		},
		Particles = { { Attachment = "PearlGlint", Color = rgb(255, 250, 240), Rate = 0.5, Lifetime = { 0.3, 0.6 }, Size = 0.45, Speed = 0 } },
		Emitters = { "Root" },
	},
	-- the hat (with its band) and the straw tufts move a little in the wind
	scarecrow = {
		Sway = {
			{ Part = "Hat", Degrees = 2.5, Seconds = 4.2, Axis = "Z", Hinge = "Pivot" },
			{ Part = "HatBand", Degrees = 2.5, Seconds = 4.2, Axis = "Z", Hinge = "Pivot" },
			{ Part = "StrawWristL", Degrees = 3, Seconds = 3.1, Axis = "Z", Hinge = "Pivot" },
			{ Part = "StrawWristR", Degrees = 3, Seconds = 3.5, Axis = "Z", Hinge = "Pivot" },
			{ Part = "StrawCollar", Degrees = 2, Seconds = 3.7, Axis = "X", Hinge = "Pivot" },
			{ Part = "StrawHem", Degrees = 2.5, Seconds = 3.9, Axis = "X", Hinge = "Pivot" },
		},
	},
	-- the ore crystals glow with a slow soft pulse
	minecart = {
		Lights = { { Part = "Crystals", Color = rgb(255, 196, 60), Brightness = 0.7, Range = 10 } },
		Flicker = { { Part = "Crystals", Amount = 0.25, Hz = 0.3 } },
	},
	-- a rare small gold sparkle on the lock / over the eggs
	chest = {
		Particles = { { Attachment = "Sparkle", Color = rgb(255, 214, 90), Rate = 0.25, Lifetime = { 0.5, 0.9 }, Size = 0.35, Speed = 0.4 } },
		Emitters = { "Root" },
	},
	egg_nest = {
		Particles = { { Attachment = "Sparkle", Color = rgb(255, 236, 170), Rate = 0.2, Lifetime = { 0.5, 0.9 }, Size = 0.4, Speed = 0.3 } },
		Emitters = { "Root" },
	},
	-- batch 3: the fountain keeps today's crystal light (moved to WaterPoint, the new crystal's centre); mist at the 6
	-- stream landings, glints, the water ripples slide and the streams run down
	fountain = {
		Lights = { { Attachment = "WaterPoint", Color = rgb(95, 212, 255), Brightness = 0.6, Range = 16 } },
		Particles = fountainParticles,
		Emitters = { "Root" },
		Scroll = {
			{ Part = "LowerWater", U = 0.25, V = 0.1 },
			{ Part = "UpperWater", U = -0.2, V = 0.15 },
			{ Part = "Stream", V = -3 },
		},
	},
	-- the forge (a sub-model of each weapon stall): today's Embers light (moved to ForgeLight) with a soft pulse, fire
	-- on the coals, sparks off the anvil face, a thin smoke from the chimney
	anvil_forge = {
		Lights = { { Attachment = "ForgeLight", Color = rgb(255, 140, 40), Brightness = 0.7, Range = 14 } },
		Flicker = { { Attachment = "ForgeLight", Amount = 0.18, Hz = 1.3 } },
		Particles = {
			{ Attachment = "Fire", Color = rgb(255, 150, 55), Rate = 7, Lifetime = { 0.4, 0.8 }, Size = 0.9, SizeEnd = 0.2,
				Transparency = { 0.25, 1 }, Speed = { 1.2, 2.2 }, Spread = 18, Acceleration = { 0, 1.5, 0 }, Texture = FIRE, LightEmission = 1 },
			{ Attachment = "Sparks", Color = rgb(255, 200, 90), Rate = 2.5, Lifetime = { 0.3, 0.6 }, Size = 0.14, SizeEnd = 0.05,
				Speed = { 4, 7 }, Spread = 55, Acceleration = { 0, -18, 0 }, LightEmission = 1 },
			{ Attachment = "Smoke", Color = rgb(95, 92, 96), Rate = 1.2, Lifetime = { 2.2, 3.2 }, Size = 0.7, SizeEnd = 2.4,
				Transparency = { 0.7, 1 }, Speed = { 1.2, 1.8 }, Spread = 10, Acceleration = { 0.3, 0.5, 0 }, Texture = SMOKE,
				LightEmission = 0, RotSpeed = 15 },
		},
		Emitters = { "Root" },
	},
	-- batch 4 (stall pieces; their effect attachments are under "PiecesRoot")
	weapon_stall = {
		Particles = { glint("ShieldGlint", rgb(255, 236, 170), 0.3) },
		Emitters = { "PiecesRoot" },
	},
	-- the crystal ball shimmers inside, the trophy glints now and then
	trophy_stall = {
		Particles = {
			{ Attachment = "BallShimmer", Color = rgb(190, 170, 255), Rate = 1.2, Lifetime = { 0.6, 1.2 }, Size = 0.3, Speed = 0.15, LightEmission = 1 },
			glint("TrophyGlint", rgb(255, 222, 120), 0.3),
		},
		Emitters = { "PiecesRoot" },
	},
	-- the diamond sign floats and turns slowly with a sparkle; the three gems glint
	diamond_shop = {
		Spin = {
			{ Part = "Diamond_Glow", Seconds = 14, Bob = 0.5, BobSeconds = 3.6 },
			{ Part = "DiamondRim_Glow", Seconds = 14, Bob = 0.5, BobSeconds = 3.6 },
		},
		Particles = {
			{ Attachment = "DiamondCenter", Color = rgb(170, 238, 255), Rate = 1, Lifetime = { 0.5, 1.0 }, Size = 0.5, Speed = 0.8, LightEmission = 1 },
			glint("SignGlint", rgb(255, 255, 255), 0.3, 0.6),
			glint("GemGlint1", rgb(95, 212, 255), 0.3),
			glint("GemGlint2", rgb(255, 196, 60), 0.3),
			glint("GemGlint3", rgb(95, 212, 255), 0.3),
		},
		Emitters = { "PiecesRoot" },
	},
} :: { [string]: Entry }

return PropFX
