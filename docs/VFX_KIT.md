# VFX KIT - Fight Your Destiny (batch 1: Hub, Plains, Desert, Jungle)

Lighting presets, world/ambient VFX prefabs and the starter combat VFX set.
Everything here is data only: no scripts anywhere. Built by the VFX agent on 2026-10-03.

| What | Where |
|---|---|
| Lighting presets | `ReplicatedStorage.Assets.Lighting.<PresetName>` (Folder) |
| World / ambient prefabs (builders clone these into the map) | `ServerStorage.MapAssets.VFX.<Name>` |
| Combat / feedback prefabs (played by code later) | `ReplicatedStorage.Assets.VFX.<Name>` |
| Preview stage (one clone of everything, for QC) | `workspace._Staging.AssetPreview.VFX` at X = -3000, Z = 600 |

---

## 1. Lighting presets

Lighting is global, so a client script will switch presets when the player changes zone.

**Lookup rule for the code:** preset `"<ZoneId>_<n>"` if it exists, otherwise `"<ZoneId>"`; `"Hub"` in the hub.
(So `Plains_1` -> `Plains`, `Desert_1` and `Desert_2` -> `Desert`, `Jungle_1` and `Jungle_2` -> `Jungle`.)

**Format of a preset Folder**

* ATTRIBUTES named exactly like the `Lighting` properties to set: `Ambient`, `OutdoorAmbient`, `Brightness`,
  `ClockTime`, `GeographicLatitude`, `ColorShift_Top`, `ColorShift_Bottom`, `EnvironmentDiffuseScale`,
  `EnvironmentSpecularScale`, `ExposureCompensation`, `ShadowSoftness`, `GlobalShadows`. No other attributes,
  so `Lighting[name] = value` is safe for every attribute.
* CHILDREN to clone into `Lighting`: `Atmosphere`, `Sky`, `ColorCorrection` (ColorCorrectionEffect),
  `Bloom` (BloomEffect), `SunRays` (SunRaysEffect). No DepthOfField on purpose (gameplay readability).

### Apply-preset snippet (Edit mode, `execute_luau`)

```lua
local function applyLighting(name)
	local Lighting = game:GetService("Lighting")
	local preset = game.ReplicatedStorage.Assets.Lighting:FindFirstChild(name)
	assert(preset, "no lighting preset named " .. tostring(name))
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	for prop, value in pairs(preset:GetAttributes()) do
		Lighting[prop] = value
	end
	for _, child in ipairs(preset:GetChildren()) do
		child:Clone().Parent = Lighting
	end
end

applyLighting("Plains_3") -- any name from the table below
```

**Builders: Lighting is shared by every agent in this Studio. Preview the preset of the sub-zone you are
building, then re-apply `"Hub"` when you are done** (`applyLighting("Hub")`). Do not edit the presets or
the Lighting service yourself; report what looks wrong instead.

The runtime version (later) should tween the numeric / Color3 attributes and the Atmosphere and
ColorCorrection properties over about 1 s instead of snapping, and swap Sky / Bloom / SunRays at once.

### Presets

Sun direction: negative latitude puts the sun in the south (-Z), so the faces the player sees while
travelling toward +Z are lit and shadows fall away from the camera.

| Preset | Intent | ClockTime / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | ColorCorrection (Sat, Contrast, Tint) | ShadowSoftness | SunRays |
|---|---|---|---|---|---|---|---|---|
| `Hub` | Welcoming bright late morning, slightly warm, crisp | 10.5 / 0 | 2.1 / -0.05 | 90,94,106 / 132,136,148 | 0.26, 0.8, 206,228,255 | 0.12, 0.08, 255,250,240 | 0.2 | 0.05 |
| `Plains` | Sunny daytime, soft shadows, light distance haze, saturated greens | 13.6 / 0 | 2.0 / -0.05 | 86,96,104 / 128,138,144 | 0.30, 1.2, 200,230,255 | 0.15, 0.06, 255,254,246 | 0.4 | 0.04 |
| `Plains_2` (Beach) | Brighter, more cyan/white, strong high sun | 13.2 / 0 | 2.25 / -0.04 | 92,104,116 / 136,150,162 | 0.27, 1.4, 214,244,255 | 0.16, 0.07, 255,255,250 | 0.2 | 0.08 |
| `Plains_3` (Forest) | Slightly dimmer and greener, visible sun rays | 15.2 / -8 | 1.75 / -0.08 | 70,86,74 / 106,124,104 | 0.34, 1.3, 198,228,202 | 0.14, 0.08, 246,255,240 | 0.5 | 0.22 |
| `Plains_4` (Cave) | Dark blue-gray interior, readable, cool so cyan ore and torches pop | 13.6 / 0 | 1.2 / +0.30 | 130,146,176 (both) | 0.32, 1.5, 64,76,112 | 0.15, 0.06, 232,240,255 | 0.5 | 0 |
| `Desert` | Strong sun, warm tint, heat haze, long hard shadows | 15.6 / -12 | 2.6 / -0.02 | 108,94,78 / 148,130,110 | 0.30, 0.9, 255,232,196 | 0.10, 0.10, 255,244,224 | 0.08 | 0.10 |
| `Desert_3` (Canyon) | Warmer / redder, later afternoon, deep shadows | 16.1 / -14 | 2.9 / -0.04 | 102,78,66 / 140,106,88 | 0.32, 1.1, 255,208,168 | 0.12, 0.12, 255,234,214 | 0.06 | 0.14 |
| `Desert_4` (Pyramid interior) | Torch-lit warm gold darkness, readable | 15.6 / -12 | 1.2 / +0.30 | 170,146,112 (both) | 0.30, 1.4, 120,84,46 | 0.12, 0.06, 255,242,218 | 0.5 | 0 |
| `Jungle` | Filtered green-tinted light, humid mist | 14.4 / -6 | 1.85 / -0.06 | 68,92,76 / 100,128,100 | 0.35, 1.4, 190,228,192 | 0.16, 0.10, 240,255,236 | 0.55 | 0.14 |
| `Jungle_3` (Lost Temple) | A bit darker, mysterious, more mist | 15.7 / -10 | 1.6 / -0.08 | 60,84,74 / 86,112,96 | 0.41, 1.7, 160,206,180 | 0.14, 0.12, 226,250,232 | 0.6 | 0.18 |
| `Jungle_4` (Temple Heart interior) | Dim green-gold, glowing glyph mood, readable | 14.4 / -6 | 1.2 / +0.28 | 148,160,108 (both) | 0.33, 1.6, 76,108,70 | 0.12, 0.06, 246,255,224 | 0.5 | 0 |

All presets: `GlobalShadows = true`, `EnvironmentDiffuseScale` 0.2-0.45, `EnvironmentSpecularScale` 0.1-0.3,
Bloom intensity 0.3-0.45 outdoors (threshold 1.5-1.7) and 0.7-0.8 indoors (threshold about 1.1, so Neon ore,
glyphs and torches glow).

**Interior presets (`Plains_4`, `Desert_4`, `Jungle_4`)** rely on `Ambient` for the base light: the room must be
closed (walls + ceiling) so the sun does not get in. They were tuned in a closed 60 x 60 x 24 test room with one
torch light. Add the builders' torches / ore / glyph lights on top; never lower `Ambient` (readability rule).

**Sky:** every preset carries the same `Sky` (stylized blue sky with soft white clouds, Toolbox asset
594775459 by Content_Loaded, attributes `SourceAssetId` / `SourceCreator` on each Sky). `StarCount = 0`,
`SunAngularSize = 14`, sun shown. The zone mood comes from the Atmosphere and the color correction.

**Not set by the presets:** `Lighting.Technology` is not scriptable. The presets were tuned with the place's
current technology; the owner should check it is **Future** (Lighting properties > Technology). With ShadowMap
the interiors will look flatter and PointLights will not cast per-pixel light.

---

## 2. World / ambient prefabs - `ServerStorage.MapAssets.VFX`

**Format:** each prefab is one anchored invisible `Part` (Transparency 1, CanCollide / CanTouch / CanQuery false,
CastShadow false) that holds the ParticleEmitters / Beams / PointLights, either on Attachments (point effects)
or directly on the Part (area effects).

```lua
local Kit = require(game.ServerStorage.DevTools.BuildKit)
local fx = Kit.asset("VFX/Fire_Torch"):Clone()
fx.CFrame = CFrame.new(torch.FirePoint.WorldPosition)   -- point effect: just move it
fx.Parent = Kit.subZone("Plains", 1).Decor
```

* **Point effects** (size 1 x 1 x 1): the effect origin is the part's center. Move the part.
* **Area effects**: the Part IS the emission volume. Move it and **resize it** to change the coverage.
  The Rate does not change with the size, so a much bigger part looks sparser: place several prefabs rather
  than raising `Rate` (budget: Rate <= 20 per emitter).
* All particle textures are Roblox built-ins from `rbxasset://textures/particles/` (SquareParticle, sparkles,
  implosion soft dot, shockwave ring, forcefield vortex): flat, chunky, nothing to moderate or to fail loading.
* Lights: every PointLight has `Shadows = false`. They count toward the "20 lights per sub-zone" budget
  (delete the `Light` in the clone if you are over budget). Fire flicker will be scripted later; the light is
  always named `Light`.
* Particles only simulate while the camera looks at them. In Edit mode wait a few seconds before judging.

| Name | What it is | Size / coverage | How to place / recolor | Emitters (sum Rate) + beams + lights |
|---|---|---|---|---|
| `Fire_Torch` | Small flame of stacked diamonds, embers, glow | point; flame about 1 wide x 2 high | Part center = flame base (torch `FirePoint`). Light range 16 | 3 (22) + light |
| `Fire_Campfire` | Bigger flame, embers, 2 soft smoke puffs | point; about 2.5 wide x 4 high | Center = top of the logs. Light range 24 | 4 (31) + light |
| `Fire_Brazier` | Wide golden flame | point; about 2.5 wide x 3 high | Center = bowl rim. Light range 20 | 3 (27) + light |
| `Smoke_Chimney` | Soft white puffs drifting up and sideways | point; rises about 12 | Center = chimney top | 1 (4) |
| `Portal_Swirl` | Two counter-rotating swirls, glow, radiating motes | 10 x 10 x 1, portal plane = part XY plane | Align the part with the portal (thin axis = Z). Recolor: snippet below. For a bigger portal scale the `Size` sequences of the 3 swirl/glow emitters | 4 (16) + light |
| `Portal_Locked` | Dim gray, slow version (locked zones) | 10 x 10 x 1 | Same placement; no light | 4 (5) |
| `Waterfall_Sheet` | Cyan sheet (Beam) + white falling streaks | 12 wide; height 20 by default | Part = top lip (X = width). Height: move attachment `Bottom` down (keep `Top` at the lip) and set `Streaks.Lifetime = height / 14`. Width: change the part's X size and `Sheet.Width0/Width1`. The sheet faces the part's +Z / -Z | 1 (16) + 1 beam |
| `Waterfall_Mist` | White splash puffs + droplets | 12 x 1 x 3 strip | Put it on the water at the foot of the fall; resize X to the fall width | 2 (26) |
| `Water_Ripple` | Sparkle glints + flat expanding rings | 20 x 0.2 x 20 | Lay it on the water surface (part top = water top); resize to the pond | 2 (10) |
| `Waves_Foam` | Flat white foam patches + small spray | 30 x 0.2 x 3, long axis X | Lay it along the shoreline, on the water edge | 2 (28) |
| `Fireflies` | Yellow-green blinking glow dots, slow drift | 30 x 8 x 30 volume | Forest / jungle edges, 2-6 studs above ground. Keep out of the combat center | 1 (5) |
| `Butterflies` | Flapping pink / yellow / blue squares | 30 x 6 x 30 volume | They fly toward the part's +X then wander. Flower areas | 3 (3.6) |
| `Pollen_Motes` | Tiny pale-yellow drifting motes (Plains ambient) | 30 x 12 x 30 volume | Anywhere over grass | 1 (9) |
| `Leaves_Falling` | Green leaves tumbling down (Plains greens) | 30 x 1 x 30 plate; leaves fall about 13 studs | Put the plate at canopy height (13 above ground). Change `Leaf.Lifetime` for taller trees (speed about 2.4 studs/s) | 1 (5) |
| `Leaves_Falling_Jungle` | Same, bigger leaves, Jungle greens | 30 x 1 x 30 plate | Same | 1 (6) |
| `GodRay` | Soft light shaft (3 camera-facing beams) | about 40 long, 4-11 wide | Part = where the ray enters the canopy; move attachment `Bottom` to where it hits the ground (default offset -12, -37, -9). Match the preset's sun direction roughly | 3 beams |
| `Dust_Motes` | Pale floating dust (cave / interiors) | 30 x 12 x 30 volume | Near light sources and shafts | 1 (8) |
| `Cave_Drip` | A water drop + small ring splash | point; drop falls 15 studs | Part = ceiling point. Other height h: move attachment `Splash` to (0, -h, 0) and set `Drop.Lifetime = sqrt(h / 15)` | 2 (1.6) |
| `Sand_Wind` | Low blowing sand streaks + dust | 30 x 2 x 30 volume | Sits on the dune surface; blows toward the part's **+X** (rotate the part for the wind direction) | 2 (16) |
| `Heat_Haze_Dust` | Slow rising warm motes + faint haze | 30 x 6 x 30 volume | Over hot sand / rock | 2 (10) |
| `Sand_Vortex` | Small swirling sand column (Djinn alcove) | point; about 5 wide x 11 high | Part center = ground point under the lamp | 3 (29) |
| `Jungle_Mist` | Low flat ground mist | 30 x 2 x 30 volume | Part center about 1.5 above ground; water edges, temple floor. 2-4 per sub-zone is enough | 1 (3) |
| `Glyph_Glow` | Pulsing soft glow + rising motes, cyan-green | point; glow about 3 across | In front of a temple glyph. Light range 9 | 2 (3.4) + light |
| `Gold_Sparkle` | Gold star twinkles + rising motes | 4 x 3 x 4 volume | Over treasure / altar; resize to the pile | 2 (10) |
| `Ore_Sparkle` | Cyan crystal glints | 3 x 3 x 3 volume | Over an ore cluster; resize | 1 (4) |
| `Rune_Glow` | Pulsing cyan aura, ring and motes (Golem runes) | point; about 6 across | On the statue's chest. Light range 16 | 3 (4.8) + light |
| `Rune_Glow_Enraged` | Red, faster variant (enrage phase) | point; about 6 across | Code swaps it in at 50% HP | 3 (11.8) + light |
| `Altar_Aura` | Rising gold-white motes + column of light | 8 x 1 x 8 base, column 24 high | Part on the altar top. Column height: move attachment `Top`. Light range 20 | 2 (12.4) + 2 beams + light |
| `Diamond_Sparkle` | Blue-white twinkles + small rising gems | 5 x 4 x 5 volume | Over the diamond shop display | 2 (11) |
| `Egg_Glow` | Warm pulsing halo + sparkles around an egg | point; halo about 6 across | Part center = egg center. Light range 12 | 2 (6.4) + light |
| `AFK_Zone_Aura` | Circular ring of rising motes and soft glow, sparse twinkles inside | 30 x 1 x 30 (ring diameter = part X/Z) | Lay it on the ground under `Hub.AFKZone`; resize X and Z together | 3 (39) |
| `HubReturn_Pad` | Expanding ground ring, glow, rising motes (blue) | 8 x 1 x 8 | Lay it on the `HubReturn` pad; resize X/Z to the pad. Light range 12 | 3 (13.5) + light |
| `Gate_Barrier_Glow` | Magical shimmer: twinkles, soft veil, rising motes (light blue) | 24 x 16 x 1 | Give it the Barrier's CFrame and Size. Code deletes it when the gate opens | 3 (19) |

Emitter names are stable (for example `Fire.Flame`, `Fire.Light`, `Streaks`, `Leaf`, `Center.Motes`) so a later
script can find them.

### Recolor snippets

```lua
-- Portal_Swirl / Portal_Locked: one main color drives every emitter and the light.
local function recolorPortal(prefab: BasePart, color: Color3)
	local seq = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.55), color)
	for _, d in ipairs(prefab:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Color = seq
		elseif d:IsA("Light") then
			d.Color = color
		end
	end
	prefab:SetAttribute("MainColor", color)
end
-- Suggested zone colors: Plains 88,204,52 - Desert 244,208,124 - Jungle 40,150,66 (Kit.Palette), default 150,110,255.

-- Generic single-color effects (Glyph_Glow, Rune_Glow, HubReturn_Pad, Gate_Barrier_Glow, Egg_Glow,
-- ReplicatedStorage.Assets.VFX.Loot_Drop_Beam = rarity color):
local function recolor(prefab: Instance, color: Color3)
	for _, d in ipairs(prefab:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Color = ColorSequence.new(color)
		elseif d:IsA("Light") then
			d.Color = color
		end
	end
end
```

---

## 3. Combat / feedback prefabs - `ReplicatedStorage.Assets.VFX`

Same Part format. **One-shot emitters have `Enabled = false` and a number attribute `EmitCount`**; the code
clones the prefab at the hit position and fires every emitter once:

```lua
local function playBurst(prefab: BasePart, cframe: CFrame)
	local fx = prefab:Clone()
	fx.CFrame = cframe
	fx.Parent = workspace
	local longest = 0
	for _, e in ipairs(fx:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e:Emit(e:GetAttribute("EmitCount") or 0)
			longest = math.max(longest, e.Lifetime.Max)
		end
	end
	game:GetService("Debris"):AddItem(fx, longest + 0.1)
end
```

| Name | What it is | Size | Notes | Emitters (EmitCount) |
|---|---|---|---|---|
| `Hit_Spark` | White-yellow square sparks + star flash | about 4 across, 0.3 s | At the hit point | Sparks 10, Flash 1 |
| `Crit_Spark` | Bigger, gold, with a ring | about 8 across, 0.4 s | | Sparks 18, Flash 2, Ring 1 |
| `Block_Spark` | Steel-blue sparks in a cone + ring | about 4 across, 0.3 s | Sparks fly toward the part's front (-Z): face it at the attacker | Sparks 8, Ring 1, Flash 1 |
| `Roll_Dust` | Dust puffs + pebbles | about 5 across, 0.6 s | At the feet, part up = ground normal | Dust 6, Pebbles 4 |
| `Enemy_Death_Puff` | White puff cloud, bits, flash | about 9 across, 0.7 s | At the enemy's center; tint `Puff.Color` with the enemy color if wanted | Puff 12, Bits 10, Flash 1 |
| `Gold_Pickup` | Gold coins popping up + glints | about 4 across, 0.6 s | At the pickup position | Coins 8, Glint 3 |
| `Loot_Drop_Beam` | Vertical light beam + rising motes + base glow. **Persistent** (emitters enabled) | 18 high (attachment `Top`) | Color = rarity (default white, attribute `MainColor`): use `recolor` above with the rarity colors of DESIGN.md | Motes rate 6, Glow, 2 beams |
| `Unlock_Burst` | Gold shards, 2 big rings, flash, lingering sparkles | about 26 across, 1.3 s | At the gate Barrier center when it opens | Shards 30, Ring 2, Flash 1, Sparkle 14 |
| `Rebirth_Burst` | Rising column of diamonds, flat ground ring to 42 studs, flash, stars | 42 wide x 35 high, 1.6 s | At the player's feet / altar, part upright | Column 40, Ring 2, Flash 1, Stars 20 |
| `LevelUp_Burst` | Green-yellow rising diamonds, flat ring, stars | about 11 across, 1 s | At the player's feet (stat upgrade) | Rise 16, Ring 1, Stars 8 |

### Telegraph shapes (boss patterns, section 1 of the boss document)

Flat `Neon` red (255, 40, 40) parts, Transparency 0.4, 0.1 thick, anchored, no collision / touch / query,
no shadow. Sized to a "unit" so code scales them; the code animates the fill (for example tween Transparency
0.8 -> 0.3 or grow an inner copy during the telegraph time). Lay them 0.05 above the arena floor.

| Name | Class | Unit | How to scale |
|---|---|---|---|
| `Telegraph_Circle` | Part (Cylinder, axis vertical: keep the 90 degree Z rotation) | radius 1 (`Size = 0.1, 2, 2`, attribute `UnitRadius = 1`) | `Size = Vector3.new(0.1, 2 * r, 2 * r)`, `CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))` |
| `Telegraph_Line` | Part | 1 wide x 1 long (`Size = 1, 0.1, 1`); pivot on the start edge, extends along LookVector (-Z) | `Size = Vector3.new(width, 0.1, length)`, `PivotOffset = CFrame.new(0, 0, length / 2)`, then `:PivotTo(CFrame.lookAt(start, target))` |
| `Telegraph_Cone` | Model (12 wedges, 60 degree fan) | radius 10 (attributes `UnitRadius = 10`, `AngleDegrees = 60`); pivot at the apex, opens toward -Z | `:ScaleTo(r / 10)` then `:PivotTo(CFrame.lookAt(bossPos, targetPos))`. A 90 degree cone = two copies rotated +/-15 degrees, or 3 copies for 180 |
| `Telegraph_Ring` | Model (64 wedges, 16-sided) | outer radius 10, band width 2 (attributes `UnitRadius = 10`, `BandWidth = 2`); pivot at the center | `:ScaleTo(r / 10)` (the band scales too) then `:PivotTo(CFrame.new(center))` |

`Model:ScaleTo` also scales the 0.1 thickness, which is harmless.

---

## 4. Preview stage

`workspace._Staging.AssetPreview.VFX` (X = -3000, Z = 600), safe to delete before release:

* `Stage`: five ground strips in Kit.Palette colors (Plains grass, sand, canyon red, jungle leaf, stone) and dark walls.
* `LightTest`: palette blocks, a 5.5-stud figure, neon ore, gold, water (Z = 500). `Interior`: the closed test room
  for the interior presets (X = -2820, Z = 500).
* `WorldPrefabs`: one clone of each world prefab (point effects in two rows at Z = 560 and 600, area effects at
  Z = 640 and 700, waterfall and god ray against the back wall). `CombatPrefabs`: the burst prefabs at Z = 540
  (call `:Emit` on them to look) and the four telegraph shapes at Z = 510-520. `Props`: context blocks.
* `Toolbox.Sky_Content_Loaded`: the sanitized source Sky.
