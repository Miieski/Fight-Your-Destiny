--!strict
-- Effects and small animations of the upgraded map props (docs/model_upgrade_brief.txt section 7). Client only:
-- GameClient/Controllers/PropFX reads this table and drives the props tagged "MapProp" (attribute MapPropId).
-- Effects run only near the local player (on within NEAR studs, off beyond FAR, checked CHECK_HZ times a second).
-- Low FX (Settings) turns off particles, sway and flicker; the static lights stay on.
--
-- Per propId (all optional; a part name matches "<Part>" or the Blender glow name "<Part>_Glow", searched in the
-- prop's descendants):
--   Lights    = { { Part, Color, Brightness, Range } }  static PointLights that the template carries (StudioProps /
--               DevTools.ApplyPropMeshes add them to the template; Shadows always false). Not created by the client.
--   Particles = { { Attachment, Color, Rate, Lifetime {min, max}, Size, Speed?, LightEmission? } } ParticleEmitters
--               that DevTools.ApplyPropMeshes puts (off) on the data attachments under the Root part of a Blender prop
--               ("PropFX_<Attachment>", default sparkle texture). List "Root" in Emitters so the client runs them.
--   Flicker   = { { Part, Amount, Hz } }                 the PointLight(s) under Part: brightness +-Amount at about Hz
--   Emitters  = { Part }                                  ParticleEmitters / Beams under Part: on near, off far / Low FX
--   Sway      = { { Part, Degrees, Seconds, Axis, Hinge } } gentle back-and-forth turn (+-Degrees, one period = Seconds)
--                                                        of every part named Part around its own Axis ("X" or "Z",
--                                                        default "Z"); Hinge "Top" turns it around its top edge
--                                                        (cloth hanging from a bar), Hinge "Pivot" around the part's
--                                                        pivot (Blender meshes: hinge / hat / straw pivots of the
--                                                        data). Parts listed with the same numbers move together.
-- A prop nested in another prop (for example the lantern of a lamp post) is its own MapProp: its effects come from
-- its own entry. Debug (client): workspace.CurrentCamera attributes PropFX_Tracked / _Active / _Flicker / _Sway /
-- _Emitting / _LowFx count what the controller drives right now.
local rgb = Color3.fromRGB

export type Light = { Part: string, Color: Color3, Brightness: number, Range: number }
export type Particle = { Attachment: string, Color: Color3, Rate: number, Lifetime: { number }, Size: number, Speed: number?, LightEmission: number? }
export type Flicker = { Part: string, Amount: number, Hz: number }
export type Sway = { Part: string, Degrees: number, Seconds: number, Axis: string?, Hinge: string? }
export type Entry = { Lights: { Light }?, Particles: { Particle }?, Flicker: { Flicker }?, Emitters: { string }?, Sway: { Sway }? }

local PropFX = {}

PropFX.NEAR = 80 -- studs: effects switch on within this distance of the local character
PropFX.FAR = 100 -- studs: and off beyond this one (the gap avoids on/off flapping)
PropFX.CHECK_HZ = 4 -- distance checks per second
PropFX.MAX_EMITTER_PROPS = 6 -- at most this many props with particles run at once (the nearest ones)

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
} :: { [string]: Entry }

return PropFX
