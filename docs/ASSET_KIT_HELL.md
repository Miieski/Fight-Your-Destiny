# ASSET KIT - HELL (zone 7)

Built by the Hell zone builder on 2026-10-04. Data only: no scripts, everything anchored, parts + recolored
clones of existing kit meshes. No Toolbox assets were used.

| What | Where |
|---|---|
| Kit models (31) | `ServerStorage.MapAssets.Hell.<Name>` |
| Gates / entry arch | `ServerStorage.MapAssets.Gates.Gate_Hell_2 / _3 / _4`, `EntryArch_Hell` |
| Lighting presets | `ReplicatedStorage.Assets.Lighting.Hell`, `Hell_2`, `Hell_3`, `Hell_4` |
| VFX prefabs | `ServerStorage.MapAssets.VFX.Hell_Embers`, `Hell_Fog`, `Hellfire`, `Soul_Wisp`, `Lava_Glow_Red` |
| Preview (one clone of everything, safe to delete) | `workspace._Staging.AssetPreview.Hell` at X = -3000, Z = 4800 |

Conventions: Model, pivot at the bottom center, front = -Z, anchored, `Kit.Palette.Hell` / `Common` colors,
SmoothPlastic (Neon only for lava, eyes, runes, windows, embers). Exceptions are listed in the Notes column.

## 1. Kit models

| Name | Parts | Size (about) | Notes |
|---|---|---|---|
| `Tiled_Platform_A` | 34 | 60 x 60 walkable, 50 deep | Signature floating platform: 4 x 4 dark tiles, TileBorder rim, 4 chunky corner blocks, tapering rock underside. **Pivot = top center of the walkable floor** (attribute `PivotAtTop`) |
| `Tiled_Platform_Small` | 27 | 30 x 30 walkable | Same, 3 x 3 tiles. Pivot at the top center |
| `Bone_Tree_A` / `_B` | 9 / 10 | 19 / 23 tall | Trees made of bones (rib branches) |
| `Dead_Bush_Hell` | 3 | 4 tall | Scatter with `decor = true` |
| `Hell_Rock_S` / `_M` / `_L` | 1 / 1 / 2 | 3 / 8 / 18 | Recolored `Common/Rock_*_A` meshes |
| `Hell_Cliff_A` | 6 | 59 wide x 54 tall x 38 deep | Recolored `Swamp/Swamp_Cliff_A` (wider than the 40 asked: scale it) |
| `Obsidian_Island` | 4 | 26 x 22, top 5 above the pivot | Decor for lava lakes; pivot = lava surface |
| `Skull_Rock_Small` | 6 | 8 x 9 x 8 | Stylized skull boulder |
| `Rib_Arch` | 19 | passage 24 x 16, 29 tall | Two pairs of giant ribs + a spine on top |
| `Lava_Crack_Hell` | 4 | 10 x 8 flat | Decor only (no collision), thin Neon crack. Edges only, never on fight floors |
| `Spiked_Building_A` | 25 | 24 x 24 footprint, 48 tall | Gabled gothic house, glowing orange window, not enterable |
| `Spiked_Building_B` | 22 | 24 x 24 footprint, 68 tall | Tower house, purple + orange windows |
| `Gothic_Arch` | 26 | passage 24 x 16, 40 tall, 34 wide | Pointed arch with spikes and a purple keystone |
| `Demon_Banner` | 8 | 7 x 16 | Standing banner; the cloth is the Part named `Cloth` |
| `Hanging_Cage` | 10 | 6 wide | **Pivot at the lowest point**, attribute `Height` = 24 (cage + chain) |
| `Brazier_Hell` | 9 | 4.4 x 5 | Part `Bowl` has the Attachment `FirePoint` (put `Hellfire` there: pivot + (0, 5, 0)) |
| `Iron_Fence_Spiked` | 14 | 12 long x 5.5 | |
| `Street_Lamp_Hell` | 5 | 13.5 tall | Part `Lantern` holds a PointLight `Light` (0.8, range 18, no shadows) |
| `Demon_Statue` | 20 | 14 x 21 | Winged horned guardian with a sword, Neon red eyes |
| `Spike_Row` | 11 | 12 long x 8 | |
| `Guard_Tower` | 18 | 18 x 18 x 66 | Neon window slits |
| `Drawbridge_Section` | 13 | 24 wide x 20 long | Walkable top at +2 (attribute `TopY`): pivot at Y = -2 for a flush deck |
| `Chain_Hanging` | 8 | 20 long | Decor only. **Pivot at the top** (hang point), attribute `Length` = 20 |
| `Face_Pillar` | 17 | 10.5 x 40 | Carved demon face on the front, Neon orange eyes |
| `Wall_Torch_Hell` | 4 | 1.5 x 3 | **Pivot on the wall plate**, the torch sticks out toward -Z. Part `Cup` has `FirePoint` |
| `Throne_Hell_Small` | 11 | 9 x 8 x 19 | |
| `Kennel_Bones` | 20 | 14 x 20 x 13 | Hound kennel + clean stylized bones and a bowl (Hellhound Alpha alcove) |
| `Execution_Block` | 16 | 16 x 19 x 20 | Platform, block, giant axe, chains (Infernal Executioner alcove). No gore |

### Gates (`ServerStorage.MapAssets.Gates`)

Opening 24 wide x 16 high, `Barrier` fills it, `PriceSign` 12 x 4 x 0.5 with its Front toward -Z (arriving player).
The decorative bars / door details are **children of the `Barrier` part** (CanCollide false) so that destroying
the Barrier removes them too; if the gate code only hides the Barrier it must also hide its children.

| Name | Parts | What |
|---|---|---|
| `Gate_Hell_2` | 47 | Wall of giant ribs, two skull pillars, bone lintel, bone portcullis (Barrier is a dark veil, Transparency 0.25) |
| `Gate_Hell_3` | 55 | City gate: spiked iron doors between two dark towers |
| `Gate_Hell_4` | 61 | Castle door with red rune eyes, hung on chains, flanked by two `Demon_Statue` (the Barrier is the door) |
| `EntryArch_Hell` | 19 | Two stone piers with giant horns, `NameSign` 14 x 4 x 0.5; no Barrier, no price |

## 2. Lighting presets

Format of `docs/VFX_KIT.md` (attributes = Lighting properties; children Atmosphere, Sky, ColorCorrection, Bloom).
The Sky is the stock sky of the other presets with `CelestialBodiesShown = false`; the red sky comes from the
Atmosphere (`Haze = 10` covers the whole sky dome with the Atmosphere color). A Sky made of black textures was
tried first and rendered pitch black with no haze, so it was dropped.
`EnvironmentDiffuseScale` and `EnvironmentSpecularScale` are 0 so the blue sky texture never tints the scene.

| Preset | Intent | Clock / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | Tint | Bloom |
|---|---|---|---|---|---|---|---|
| `Hell` | Plains + lava lake: dark red sky, readable ground | 14.6 / -14 | 2.0 / 0.20 | 165,120,130 / 180,128,134 | 0.33, 10, 160,24,22 | 255,205,200 | 0.40 / 1.30 |
| `Hell_2` | City: darker, purple sky, brazier light | 14.6 / -14 | 1.7 / 0.30 | 168,128,162 / 178,134,168 | 0.36, 10, 150,30,70 | 250,200,215 | 0.45 / 1.25 |
| `Hell_3` | Castle entrance: brighter orange-red sky glow | 15.4 / -14 | 1.9 / 0.20 | 162,118,126 / 176,124,128 | 0.34, 10, 190,38,20 | 255,205,195 | 0.45 / 1.25 |
| `Hell_4` | Throne room interior + boss arena: dark red-purple | 16.2 / -14 | 1.2 / 0.28 | 156,108,132 (both) | 0.28, 10, 110,24,44 | 255,232,236 | 0.70 / 1.10 |

Edit-mode captures of the closed throne room showed the walls blue-grey (unconverged interior lighting right
after a camera jump); check `Hell_4` in Play.

## 3. VFX prefabs (`ServerStorage.MapAssets.VFX`)

Same format as the other world prefabs (one invisible anchored Part, built-in particle textures, Rate <= 18).

| Name | What | Size | Emitters (sum Rate) + lights |
|---|---|---|---|
| `Hell_Embers` | Drifting red-orange embers (area) | 40 x 16 x 40 volume, resize freely | `Ember`, `Spark` (18) |
| `Hell_Fog` | Low dark red ground fog (area) | 40 x 2 x 40, center about 1.5 above the ground / lava | `Fog`, `Wisp` (5) |
| `Hellfire` | Red-black flame for braziers and torches (point) | flame about 1.5 wide x 3 high | Attachment `Fire`: `Flame`, `Dark`, `Core`, `Ember` (33) + PointLight `Light` (1.0, range 20, no shadows) |
| `Soul_Wisp` | Small pale drifting soul light (point) | glow about 2 across | Attachment `Soul`: `Glow`, `Trail` (7) + `Light` (0.6, range 10) |
| `Lava_Glow_Red` | Soft red light + rising sparks over lava | 8 x 1 x 8 | `Sparks`, `Glow` (9) + `Center.Light` (1.0, range 24) |

Lights count toward the 20-per-sub-zone budget: delete `Light` in the clone when over budget.

## 4. Where things are in the world

* `workspace.Zones.Hell.Hell_1` Hellish Plains: `Decor.Landmark` = `SkullRock` (in the lava lake, west), stone bridge
  over the lava arm at Z = 10..40, `EntryArch`, `HubReturn`.
* `Hell_2` Hell City: 11 x 11 grid of 24-stud cells around `Decor.Landmark` = `BurningTower`; three tiled squares.
* `Hell_3` Castle Entrance: forecourt, lava moat (Z = 633..677), drawbridge, `Decor.Landmark` = `HornedCastle`
  (front wall at Z = 720; the door opening is 34 wide x 23 high and is filled by `Hell_4.Gate`, net 24 x 16).
* `Hell_4` Throne Room: corridor Z = 730..795, hall Z = 795..945, `BossGate` on the north wall.
* `workspace._Staging.BossArenas.Hell`: floating circular arena, `Decor.Landmark` = `DemonThrone`.
