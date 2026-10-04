# ASSET KIT HEAVEN - zone 8 props, gates, lighting presets and VFX

Built by the HEAVEN ZONE BUILDER, 2026-10-04. 31 models in `ServerStorage.MapAssets.Heaven`, 4 in
`ServerStorage.MapAssets.Gates`, 4 lighting presets, 6 world VFX prefabs. One clone of each model stands in the
preview line-up at `workspace._Staging.AssetPreview.Heaven` (ground centered on X = -3000, Z = 5420).

Use: `local m = Kit.asset("Heaven/GoldenTree_A"):Clone(); m.Parent = decorFolder; m:PivotTo(CFrame.new(groundPoint))`

Conventions are the same as `docs/ASSET_KIT_A.md`: every entry is a `Model`, pivot = bottom center (exceptions noted),
front = -Z, all parts anchored, `SmoothPlastic` (`Neon` for small light accents, `Glass` for stained glass, the crystal
tile, the light bridge deck and two gate barriers), colors from `Kit.Palette.Heaven` / `Common` and lerps between them,
no scripts, no unions, no textures, no `PrimaryPart`. `Model:ScaleTo` works on all. No new Toolbox asset was inserted:
organic pieces are recolored clones of kit A meshes and keep their `SourceAssetId` / `SourceCreator` attributes
(clouds and rocks are the kit A rock meshes resized, 9682467046 by Proudism). Sizes are bounding boxes X x Y x Z.

Derived colors used everywhere (lerps of palette entries): fight floor "pale gold stone" = `MarbleShade:Lerp(GoldDark, 0.22)`
(214, 199, 170) and a lighter tile; island rock = `Common.Stone:Lerp(MarbleShade, 0.5)` and `Common.Stone:Lerp(SkyBlue, 0.2)`;
storm cloud = `Common.StoneDark:Lerp(Banner, 0.3)`; light gold = `Gold:Lerp(Light, 0.4)`.

## Heaven (31)

| Name | Size | Parts | Notes |
|---|---|---|---|
| Sky_Island_Rock | 63 x 53 x 69 | 36 | faceted underside of a floating island, about 60 across, tapers down 40. **Pivot = TOP center** (attribute `PivotAtTop`): `PivotTo` the underside of the island top. No collision, no query |
| Floating_Rock_S | 10 x 8 x 9 | 3 | small floating rock with a grass cap, decor only |
| Floating_Rock_M | 19 x 16 x 19 | 3 | same, bigger |
| Cloud_Block_S | 18 x 7 x 12 | 3 | chunky faceted cloud, no collision / query / shadow |
| Cloud_Block_M | 37 x 11 x 19 | 4 | recolor it with the storm color for thunder clouds |
| Cloud_Block_L | 70 x 18 x 39 | 5 | |
| Cloud_Bridge_Section | 38 x 9 x 23 | 10 | walkable deck 24 wide x 20 long (along Z), cloud puffs on the sides and below. Pivot = bottom of the deck slab, **deck top = pivot Y + 2** (attribute `DeckTop`) |
| Light_Bridge_Section | 24 x 4 x 20 | 12 | translucent golden deck 24 x 20 with two Neon `RailLight` bars. Same pivot rule (`DeckTop = 2`). Rails are visual: add invisible walls |
| GoldenTree_A | 24 x 28 x 24 | 2 | Common/OakTree_A, white trunk, gold canopy (src 127731233099210). Canopy does not collide |
| GoldenTree_B | 19 x 34 x 18 | 2 | OakTree_B, pink-white canopy |
| GoldenTree_C | 21 x 27 x 26 | 3 | OakTree_C, pale gold canopy (src 9682467046) |
| GlowFlower_A | 3 x 5 x 2 | 2 | Neon light-gold `Bloom` (no light) |
| GlowFlower_B | 3 x 4 x 2 | 2 | Neon pink `Bloom` |
| Heaven_Bush_A | 7 x 4 x 6 | 3 | pale green bush with pink flowers, no collision |
| Waterfall_Edge_Rock | 28 x 6 x 13 | 5 | lip of a waterfall: water `Channel` 12 wide between rocks, falls toward -Z. Attachment `FallPoint` on `Channel` = where to put `VFX/Waterfall_Sheet` |
| Marble_Column | 8 x 40 x 8 | 8 | round shaft, gold bands. `ScaleTo(1.3)` = 52 tall |
| Marble_Column_Broken | 21 x 16 x 12 | 8 | stump + two fallen drums |
| Marble_Arch | 36 x 25 x 6 | 11 | clear passage 24 wide x 16 high (piers at +/-14.5) |
| Marble_Stairs_Section | 44 x 9 x 32 | 15 | 40 wide, rise 8 over 28 (16 degrees), ascends toward +Z. Pivot = bottom center of the 40 x 28 footprint. Invisible collidable `Ramp` wedge over the 8 steps (it starts 3.5 studs in front). Side `Cheek*` parts can be deleted to join sections |
| Marble_Wall_Section | 20 x 16 x 4 | 5 | |
| Golden_Gate_Post | 6 x 22 x 6 | 8 | marble pier, gold cap, Neon `Orb` (no light) |
| Angel_Statue | 18 x 18 x 7 | 20 | winged, sword point down, small Neon `Halo` |
| Heaven_Banner | 7 x 17 x 2 | 8 | Common/Banner_A in blue and gold, part `Cloth` |
| Fountain_Marble | 18 x 13 x 18 | 19 | Hub/Fountain_A in marble and gold at scale 0.6, no light. Attachment `WaterPoint` kept |
| Floating_Lantern | 2 x 5 x 2 | 10 | **pivot = lowest point**, attribute `Height = 5.1`. Neon `Glow` with PointLight `Light` (Brightness 0.8, Range 18, no shadows). Decor only |
| Stained_Glass_Window | 10 x 29 x 1 | 21 | gold frame, 8 colored `Pane` parts + pointed top (Glass, Transparency 0.25) over a pale `Backlight`. Put its back (+Z) on a wall. Decor only |
| Golden_Tower | 25 x 76 x 25 | 21 | round marble tower, gold 8-pointed pyramid roof (corner wedges) |
| Crystal_Floor_Tile | 20 x 1 x 20 | 5 | Glass `Pane` (Transparency 0.45) in a gold frame, walkable, **top = pivot Y + 0.6** |
| Golden_Armor_Stand | 6 x 9 x 3 | 12 | |
| Weapon_Rack_Gold | 8 x 9 x 3 | 13 | sword, spear, halberd; weapons face -Z |
| Griffin_Nest | 32 x 6 x 28 | 28 | golden branches, three eggs, four `StormTuft` blobs. Only `Bedding` collides |

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from. `Barrier` and `PriceSign`
(12 x 4 x 0.5, Front face = -Z) are direct children. `Barrier.PivotOffset` is preset so the model pivot stays at the
bottom center after `Kit.finishGate`. Door decoration is parented under `Barrier` (all `CanCollide = false`):
destroy `Barrier` to open the gate.

| Name | Size | Parts | Notes |
|---|---|---|---|
| EntryArch_Heaven | 37 x 36 x 6 | 31 | two marble columns, beam, blue `NameSign` 14 x 4 x 0.5 in a gold frame, two fans of wing blades, sun disc, two Neon `Lantern` cubes (no light). NO `Barrier`, NO `PriceSign` |
| Gate_Heaven_2 | 40 x 30 x 7 | 25 | marble arch with pediment. `Barrier` = translucent golden pane (Glass, Transparency 0.45) with seven Neon `LightStrip` children: the curtain of light |
| Gate_Heaven_3 | 48 x 33 x 14 | 30 | rough stone arch with floating stones above. `Barrier` = nearly invisible pane (Transparency 0.85) carrying 11 gilded `Bar` parts and two `CrossBar` |
| Gate_Heaven_4 | 40 x 31 x 10 | 28 | castle door frame: jambs, gold columns, cornice, pediment with a sun-and-wings emblem. `Barrier` = golden double doors 24 x 16 x 2 with a Neon `Seam`. Also used (without its sign) as the arena `Door` |

## Lighting presets - `ReplicatedStorage.Assets.Lighting`

Same format as `docs/VFX_KIT.md` (the Sky is a copy of the one in `Plains`). Lookup rule: `Heaven_1` -> `Heaven`.
Anti-glare limits respected in all four: ExposureCompensation <= 0, Bloom Intensity <= 0.35 with Threshold >= 1.4.

| Preset | Intent | ClockTime / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | ColorCorrection (Sat, Contrast, Tint) | ShadowSoftness | Bloom (I / Th) | SunRays |
|---|---|---|---|---|---|---|---|---|---|
| `Heaven` | High bright sun, golden-pink horizon haze, light blue shadows | 13.2 / -14 | 2.0 / -0.12 | 112,124,156 / 134,146,182 | 0.30, 1.5, 255,228,222 | 0.12, 0.08, 255,251,244 | 0.25 | 0.30 / 1.8 | 0.08 |
| `Heaven_2` (Cloud Bridge) | Cooler, hazier, more dramatic | 15.0 / -18 | 1.9 / -0.14 | 100,114,152 / 118,134,178 | 0.36, 2.0, 198,210,240 | 0.08, 0.10, 238,243,255 | 0.30 | 0.28 / 1.8 | 0.10 |
| `Heaven_3` (Castle Entrance) | Warm golden hour on marble | 16.5 / -24 | 2.0 / -0.12 | 124,114,118 / 150,138,142 | 0.32, 1.6, 255,224,184 | 0.12, 0.08, 255,245,228 | 0.20 | 0.30 / 1.7 | 0.12 |
| `Heaven_4` (Throne Room interior + boss arena) | Soft cool-white, gold accents, lit by `Ambient`; the hall is closed | 13.2 / -14 | 1.2 / -0.10 | 166,163,170 (both) | 0.22, 1.0, 206,216,240 | 0.08, 0.10, 246,248,255 | 0.5 | 0.35 / 1.4 | 0 |

## World VFX prefabs - `ServerStorage.MapAssets.VFX`

Same Part format as the other world prefabs (invisible anchored Part, built-in particle textures, every emitter
Rate <= 20, no lights, no scripts).

| Name | What it is | Size / coverage | How to place | Emitters (sum Rate) |
|---|---|---|---|---|
| `Light_Motes` | Slow rising golden motes + a few glints | 30 x 12 x 30 volume | Anywhere; resize the part | `Mote`, `Glint` (13) |
| `Cloud_Puff` | Soft low-alpha cloud wisps drifting toward the part's **+X** | 40 x 6 x 40 volume | Island edges, below bridges | `Puff` (3) |
| `Feathers_Falling` | A few white feathers tumbling down | 30 x 1 x 30 plate; they fall about 15 studs | Put the plate 15-20 above the ground | `Feather` (3) |
| `Halo_Glow` | Ring of soft light particles + sparkles (ring diameter = part X / Z) | 20 x 1 x 20 | Resize X and Z together (the arena halo uses 48) | `RingGlow`, `RingSpark` (24) |
| `Wind_Streaks` | Thin fast white streaks + faint wisps, blows toward the part's **+X** | 30 x 10 x 30 volume | Across bridges; rotate the part for the wind direction | `Streak`, `Wisp` (15) |
| `Storm_Cloud_Flash` | Dark cloud puffs with an occasional pale flash and bolt (particles only, no light) | 40 x 12 x 28 volume | Pair it with storm-colored `Cloud_Block` clones so the cloud has a body | `Cloud`, `Flash`, `Bolt` (7.85) |

## Where the zone uses things that are not kit models

* Zone X = 16000. Everything floats: island tops at Y = 0, a faceted cloud sea at Y = -60 (`Decor.Backdrop.CloudSea`
  in every sub-zone) over two flat `SeaBase` slabs at Y = -76 (Heaven_1 backdrop). Paths, bridges and gate landings
  have their top at Y = 0.2.
* Landmark stand-ins (one `Landmark` Model each in `Decor`, pivot bottom center, attribute `LandmarkName`):
  `TreeOfLight` (Heaven_1, 113 x 125 x 104, pivot 16107.5, 0, 107.5, on its own island north-east),
  `GoldenArch` (Heaven_2, 129 x 142 x 29, pivot 16000, -6, 285; **the central bridge passes under it**: legs at
  X = +/-50, clear opening 82 wide and about 70 high at X = 16000),
  `GoldenCastle` (Heaven_3, 243 x 163 x 83, pivot 16000, 16, 729, standing on the terrace at Y = 16; **the path passes
  THROUGH it**: a tunnel 24 wide x 16 high from Z = 700 to Z = 758 at X = 16000, Y = 16..32, closed at its south end by
  `Heaven_4.Gate`),
  `LuminousThrone` (boss arena `Decor`, 52 x 65 x 24, pivot 16000, 6, -500 on top of the dais).
* Heaven_3 rises in two stair flights (Y 0 -> 8 -> 16). **Heaven_4's floor is at Y = 16** and its `Entrance` marker
  was moved up to Y = 16.5 (Y only, still facing +Z).
* `BossGate` (Heaven_4, golden double doors with a sun-and-wings emblem, at Z = 975) and the arena `Door` are built in
  place.
* Arena: `workspace._Staging.BossArenas.Heaven`, `PrimaryPart` = `Floor` (the central 50-stud disc, pivot at the top
  center = 16000, 0, -600). The ring pattern is two wider discs 0.015 and 0.03 lower, so `Floor` is the highest floor
  surface and telegraphs laid 0.05 above the pivot clear everything. `Decor.Halo` (Model: 24 Neon gold segments, ring
  48 across at Y = 70, with a `Halo_Glow` child part). West alcove = armory (`MiniBossSpawn1`), east alcove = griffin
  nest (`MiniBossSpawn2`). Invisible walls 100 high on the circle and around the alcoves + an invisible ceiling in
  `Bounds`; the dais and the door porch are outside the walls.
