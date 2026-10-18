--!strict
-- Effects and small animations of the upgraded map props (docs/model_upgrade_brief.txt section 7). Client only:
-- GameClient/Controllers/PropFX reads this table and drives the props tagged "MapProp" (attribute MapPropId).
-- Effects run only near the local player (on within NEAR studs, off beyond FAR, checked CHECK_HZ times a second).
-- Low FX (Settings) turns off particles, sway and flicker; the static lights stay on.
--
-- Per propId (all optional; part names are names inside the prop model, searched in its descendants):
--   Lights   = { { Part, Color, Brightness, Range } }  static PointLights that the template carries (StudioProps /
--              DevTools.ApplyPropMeshes add them to the template; Shadows always false). Not created by the client.
--   Flicker  = { { Part, Amount, Hz } }                 the PointLight(s) under Part: brightness +-Amount at about Hz
--   Emitters = { Part }                                  ParticleEmitters / Beams under Part: on near, off far / Low FX
--   Sway     = { { Part, Degrees, Seconds, Axis } }      gentle back-and-forth turn of Part around its own Axis ("X"
--                                                        or "Z", default "Z"), one looping tween per part
-- A prop nested in another prop (for example the lantern of a lamp post) is its own MapProp: its effects come from
-- its own entry.
local rgb = Color3.fromRGB

export type Light = { Part: string, Color: Color3, Brightness: number, Range: number }
export type Flicker = { Part: string, Amount: number, Hz: number }
export type Sway = { Part: string, Degrees: number, Seconds: number, Axis: string? }
export type Entry = { Lights: { Light }?, Flicker: { Flicker }?, Emitters: { string }?, Sway: { Sway }? }

local PropFX = {}

PropFX.NEAR = 80 -- studs: effects switch on within this distance of the local character
PropFX.FAR = 100 -- studs: and off beyond this one (the gap avoids on/off flapping)
PropFX.CHECK_HZ = 4 -- distance checks per second
PropFX.MAX_EMITTER_PROPS = 6 -- at most this many props with particles run at once (the nearest ones)

PropFX.Props = {
	crate = {}, -- no effect (pilot)
	-- batch 1 (ready): the warm lantern flame
	lantern = {
		Lights = { { Part = "Flame", Color = rgb(255, 210, 140), Brightness = 1.2, Range = 16 } },
		Flicker = { { Part = "Flame", Amount = 0.08, Hz = 6 } },
	},
	lamp_post = {}, -- its lantern is a nested "lantern" prop
} :: { [string]: Entry }

return PropFX
