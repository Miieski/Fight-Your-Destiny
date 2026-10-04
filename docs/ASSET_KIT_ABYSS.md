# ASSET KIT - ABYSS (zone 10, id "Abyss")

Built by the Abyss zone builder on 2026-10-04. Data only: no scripts, everything anchored, parts + recolored
clones of existing kit meshes. No new Toolbox assets were inserted (the recolored meshes keep their original
`SourceAssetId` / `SourceCreator` attributes).

**Design decision: "dry underwater".** There is no swimming and no water volume. Players walk on the sea floor;
the underwater look comes from the lighting presets (blue-green Atmosphere + tint), a dark-blue "water ceiling"
part 141 studs up in every sub-zone (CanCollide / CanQuery false, CastShadow false), light shafts, bubbles,
drifting motes, kelp, coral and static fish.

| What | Where |
|---|---|
| Kit models (43) | `ServerStorage.MapAssets.Abyss.<Name>` |
| Gates / entry arch | `ServerStorage.MapAssets.Gates.Gate_Abyss_2 / _3 / _4`, `EntryArch_Abyss` |
| Lighting presets | `ReplicatedStorage.Assets.Lighting.Abyss`, `Abyss_2`, `Abyss_3`, `Abyss_4` |
| VFX prefabs | `ServerStorage.MapAssets.VFX.Bubbles_Rising`, `Bubbles_Area`, `Sea_Motes`, `Light_Shaft_Sea`, `Fish_School`, `Biolum_Glow`, `Current_Streaks` |
| Preview (one clone of everything, safe to delete) | `workspace._Staging.AssetPreview.Abyss` at X = -3000, Z = 6600 |

Conventions: Model, pivot at the bottom center, front = -Z, anchored, `Kit.Palette.Abyss` / `Common` colors,
SmoothPlastic (Neon only for bioluminescence, pearls, chest gold and small accents). Colors that are not in the
palette are blends of two palette colors (`Rock` + `SandDeep`, `Abyss` + `Rock`, `PalaceStone` + `Rock` / `DeepBlue`,
`Coral1` + `White` for shells, `Gold` + `Rust` for old gold).

## 1. Kit models

| Name | Parts | Size (about) | Notes |
|---|---|---|---|
| `Coral_Branch_A` / `_B` / `_C` | 7 / 5 / 6 | 6 x 10 / 10 x 8 / 5 x 10 | Pink staghorn (Coral1) / orange plates (Coral2) / purple fingers (Coral3). Collide. Used at scale 0.9-2.5 |
| `Coral_Fan_A` | 5 | 11 x 11 x 1 | Flat pink fan, decor only |
| `Coral_Brain_A` | 3 | 8 x 6 | Three balls |
| `Coral_Tube_Cluster` | 6 | 6 x 7 | Purple / turquoise tubes |
| `Sea_Anemone_A` | 8 | 4 x 4 | Decor only |
| `Kelp_Tall_A` / `_B` | 9 / 11 | 31 tall / 37 tall | Decor only (no collision, no query: scatter rays pass through) |
| `Sea_Grass_A` | 1 | 4 x 2 | Recolored `Common/GrassTuft_A`, decor only |
| `Reef_Rock_S` / `_M` / `_L` | 1 / 1 / 2 | 4 / 8 / 25 | Recolored `Common/Rock_*_A` |
| `Reef_Cliff_A` | 4 | 57 x 50 x 37 | Recolored `Common/Boulder_Cliff_A` at scale 1.25. Overlap by about 10 studs |
| `Trench_Cliff_A` | 6 | 73 x 66 x 47 | Extra: dark recolor of `Swamp/Swamp_Cliff_A` at scale 1.6 (backdrops) |
| `Giant_Shell_A` | 3 | 8 x 7 x 9 | `Plains/Shell_A` at scale 3, Neon pearl |
| `Starfish_Big` | 5 | 10 across | `Plains/Starfish_A` at scale 3, decor only (scattered at 0.35-0.8) |
| `Fish_Decor_A` | 3 | 3 long | Static fish, decor only; parts in order body / stripe / tail (recolored per group). Hang above 16 studs |
| `Wreck_Hull_Section` | 20 | 40 x 13 x 9 | Keel along X, seven ribs and planks leaning toward +Z |
| `Mast_Broken` | 6 | 9 x 24 x 14 | Leaning mast with a torn sail (sail and rope do not collide) |
| `Anchor_Giant` | 11 | 15 x 18 x 8 | Leaning |
| `Cannon_Rusted` | 8 | 4 x 5 x 8 | Muzzle toward -Z |
| `Chest_Sunken` | 8 | 6 x 7 x 5 | Half open, Neon gold inside, two Neon coins |
| `Barrel_Sunken` | 5 | 4 x 5 x 5 | Recolored `Common/Barrel_A` lying tilted |
| `Rope_Coil` | 4 | 5 x 2 | Decor only |
| `Net_Hanging` | 10 | 13 x 9 flat | Translucent, decor only; pivot at the bottom edge: place it at the hanging height |
| `Biolum_Plant_A` / `_B` | 7 / 9 | 4 x 7 / 4 x 4 | Neon cyan stalks / dark tubes with Neon pink tops. Decor only, no light |
| `Glow_Jelly_Decor` | 7 | 4 x 9 | Translucent bell, Neon core (a Ball: recolor it, add a PointLight there if wanted), Neon tentacles. Decor only, pivot at the lowest point |
| `Giant_Rib_Bone` | 5 | 14 x 38 x 3 | Curves toward -X |
| `Giant_Skull_Seabeast` | 19 | 23 x 17 x 31 | Snout toward -Z. Used at 1.8 in the landmark |
| `Trench_Rock_Spire` | 2 | 35 x 55 x 31 | Dark recolor of `Plains/Stalagmite_A` at scale 4.5 (so `ScaleTo(4.5 * k)` for k times this size) |
| `Vent_Chimney` | 5 | 10 x 13 x 9 | Attachment `VentPoint` on the top part (put `Bubbles_Rising` there) |
| `Palace_Column` | 11 | 11 x 40 x 10 | Gold band, three coral growths (no collision) |
| `Palace_Column_Broken` | 6 | 17 x 19 x 13 | With a fallen drum |
| `Golden_Dome_Small` | 5 | 17 x 19 | Drum + gold ball dome + finial |
| `Trident_Statue` | 16 | 9 x 19 x 8 | Triton on a plinth holding a gold trident |
| `Trident_Rack` | 20 | 11 x 12 x 4 | Three gold tridents |
| `Palace_Arch` | 15 | 42 x 26 x 7 | Passage 24 x 16 |
| `Palace_Wall_Section` | 5 | 24 x 54 x 6 | Tiles along X every 24 studs (the zone itself uses long custom walls with the same profile) |
| `Pearl_Lamp` | 4 | 3 x 8 | Neon part `Pearl` holds PointLight `Light` (0.9, range 20, no shadows) |
| `Mosaic_Tile` | 5 | 16 x 0.3 x 16 | Flat turquoise / gold / blue pattern, decor only (no collision) |
| `HighLedge` | 5 | 93 x 9 x 14 | Walkable top 30 x 14 at 9 studs (part `Top`), a 16-degree ramp at each end (`RampE`, `RampW`, 31.4 long). Attributes `TopHeight`, `RampLength`. Back = +Z |

### Gates (`ServerStorage.MapAssets.Gates`)

Opening 24 wide x 16 high, `Barrier` fills it, `PriceSign` 12 x 4 x 0.5 with its Front toward -Z (arriving player).
The curtain / chains / shell ribs are **children of the `Barrier` part** (CanCollide false, attribute
`BarrierDecorIsChildOfBarrier`): destroying the Barrier removes them; code that only hides it must hide its children too.

| Name | Parts | What |
|---|---|---|
| `Gate_Abyss_2` | 39 | Coral arch on two rock piers, closed by a kelp curtain and a net (Barrier = kelp green, Transparency 0.3) |
| `Gate_Abyss_3` | 34 | Gap between two wreck hull sections under a fallen mast, closed by iron chains and a rusted anchor (Barrier = dark veil, Transparency 0.5) |
| `Gate_Abyss_4` | 32 | Giant clam between dark rock piers: two ribbed shell halves, Neon `Pearl` in the seam with PointLight `Light` (0.9, range 18). Barrier 24 x 16 x 3 = the closed clam |
| `EntryArch_Abyss` | 28 | Coral-and-shell arch, `NameSign` 14 x 4 x 0.5; no Barrier, no price |

## 2. Lighting presets

Format of `docs/VFX_KIT.md`. The Sky is the stock sky (celestial bodies hidden in `Abyss_3` / `Abyss_4`).

| Preset | Intent | Clock / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | Tint / Saturation | Bloom (Int / Thr) | SunRays |
|---|---|---|---|---|---|---|---|---|
| `Abyss` | Coral Reef: bright turquoise, sunny | 12.6 / -10 | 2.0 / 0 | 124,140,150 / 136,160,170 | 0.30, 2.4, 64,190,214 | 226,248,255 / 0.22 | 0.40 / 1.4 | 0.12 |
| `Abyss_2` | Shipwreck: darker teal, murky | 13.4 / -12 | 1.5 / 0.08 | 92,130,146 / 100,142,160 | 0.34, 3, 40,120,140 | 190,235,245 / 0.08 | 0.40 / 1.3 | 0.05 |
| `Abyss_3` | Abyssal Trench: deep dark blue, Neon does the work | 14.6 / -14 | 1.1 / 0.25 | 116,136,198 / 122,142,204 | 0.42, 10, 12,26,70 | 200,215,255 / 0.12 | 0.70 / 1.1 | - |
| `Abyss_4` | Sunken Palace + boss arena: deep blue, gold glints | 14.6 / -14 | 1.2 / 0.22 | 128,146,190 / 132,150,194 | 0.38, 10, 22,54,112 | 225,232,255 / 0.12 | 0.65 / 1.15 | - |

Only looked at in Edit mode. A first version of `Abyss` with Density 0.42 / Haze 6 washed everything out to cyan
at 150 studs: keep the bright presets at Density about 0.3 and low Haze. A cyan Ambient turns coral orange into
yellow, which is why the `Abyss` Ambient is close to neutral.

## 3. VFX prefabs (`ServerStorage.MapAssets.VFX`)

Same format as the other world prefabs (one invisible anchored Part, built-in particle textures, Rate <= 12).

| Name | What | Size | Emitters (sum Rate) + beams + lights |
|---|---|---|---|
| `Bubbles_Rising` | Column of rising bubbles (point) | rises about 30 | Attachment `Bubbles`: `Bubble`, `Tiny` (16) |
| `Bubbles_Area` | Sparse bubbles over an area | 40 x 1 x 40 plate on the floor, resize freely | `Bubble` (6) |
| `Sea_Motes` | Slow drifting plankton specks | 40 x 16 x 40 volume | `Mote` (10) |
| `Light_Shaft_Sea` | Blue-white light shaft, like `GodRay` | about 60 long: attachments `Top` (0,0,0) and `Bottom` (-10,-60,-6); move `Bottom` for other lengths | 3 beams `Shaft_Wide / _Mid / _Core`; attribute `MainColor` |
| `Fish_School` | Small orange / yellow / blue flecks that swim out along the part's +X and curve back | 30 x 8 x 30 volume, put it 16+ above the ground | `Fish_Orange`, `Fish_Yellow`, `Fish_Blue` (4.5) |
| `Biolum_Glow` | Soft pulsing glow + motes (point) | glow about 4 across | Attachment `Glow`: `Pulse`, `Mote` (2.9) + `Light` (0.8, range 12); attribute `MainColor` (cyan; recolor with the generic `recolor` snippet of VFX_KIT.md) |
| `Current_Streaks` | Thin fast blue-white streaks + wisps | 40 x 12 x 40 volume, blows toward the part's **+X** | `Streak`, `Wisp` (15) |

## 4. Where things are in the world

* `Abyss_1` Coral Reef: sand floor, dunes and reef cliffs on the edges, 30 coral clusters, three sandy clearings at
  (19938, -35), (20062, -25), (20000, 82). `Decor.Landmark` = `CoralArch` at (20000, 0, 25): **the path passes UNDER
  it**, opening about 44 wide (checked clear for X 19980..20020) and 52 high under the crown (non-colliding hanging
  kelp down to Y 40), 30 deep. `EntryArch` at Z = -90, `HubReturn` at (20016, -108).
* `Abyss_2` Shipwreck: darker seabed, `Decor.Landmark` = `SunkenGalleon` on the west side (recolored
  `Plains/PirateShip_Wreck` at scale 1.12, bow to the north, covered in coral and kelp; no path through it),
  six hull sections, masts, anchors, nets. Clearings at (20050, 232), (20062, 335), (19985, 388).
* `Abyss_3` Abyssal Trench: canyon floor 150 wide between faceted walls about 85 high. `Decor.Landmark` =
  `SeaMonsterSkeleton`: eleven rib pairs every 15 studs from Z = 505 to 655 under a spine at Y 47. **The path passes
  THROUGH the rib tunnel** along X = 20000: clear passage at least 40 wide x 30 high (checked; ribs are about 46
  apart at the floor, spine underside at 44). Tail to the south-east (ends at (20050, 474)), skull beside the path at (20044, 668).
  Clearings in the side lanes at (19950, 522), (20050, 585), (19950, 648).
* `Abyss_4` Sunken Palace: colonnade (Z 746..798, walls at X = 20000 +/- 30), hall 180 x 150 (X +/- 90, Z 800..950),
  walls 56 high, `Decor.Landmark` = `SunkenPalaceDome` (broken gold dome ribs, radius 73, base at Y 60, apex 112,
  open to the water above). `BossGate` on the north wall at Z = 944.
* Gates: `Abyss_2.Gate` at Z = 145, `Abyss_3.Gate` at Z = 435, `Abyss_4.Gate` at Z = 725.
* `workspace._Staging.BossArenas.Abyss`: round floor (radius 75, PrimaryPart `Floor`, pivot at the top center).
  Folder `HighLedges` with two `HighLedge` models on the west and east rim (tops at Y 9, X = +/- 44.8..58.8,
  Z = +/- 15, ramps to Z = +/- 46.5; the solid block behind them up to the rim is `Decor.Structure.LedgeBack`).
  `Decor.Landmark` = `BrokenDome` (ten columns at radius 78 + rib stubs, about 174 across and 90 tall).
  North-west alcove = Kraken Spawn's cave (`MiniBossSpawn1`), north-east alcove = Triton Captain's guard post
  (`MiniBossSpawn2`), `BossSpawn` 60 studs north, `Door` + `PlayerSpawns` at the south. Invisible walls 100 high at
  radius 76 and a ceiling at Y 101 (Folder `Bounds`).
