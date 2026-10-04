# ASSET KIT - REALM OF THE DEAD (zone 9, id "Dead")

Built by the Dead zone builder on 2026-10-04. Data only: no scripts, everything anchored, parts + recolored
clones of existing kit meshes. No Toolbox assets were used.

| What | Where |
|---|---|
| Kit models (39) | `ServerStorage.MapAssets.Dead.<Name>` |
| Gates / entry arch | `ServerStorage.MapAssets.Gates.Gate_Dead_2 / _3 / _4`, `EntryArch_Dead` |
| Lighting presets | `ReplicatedStorage.Assets.Lighting.Dead`, `Dead_2`, `Dead_3`, `Dead_4` |
| VFX prefabs | `ServerStorage.MapAssets.VFX.Ghost_Fog`, `Ghost_Light`, `Green_Flame`, `Candle_Flame`, `Soul_Stream`, `Bats_Flutter` |
| Preview (one clone of everything, safe to delete) | `workspace._Staging.AssetPreview.Dead` at X = -3000, Z = 6000 |

Conventions: Model, pivot at the bottom center, front = -Z, anchored, `Kit.Palette.Dead` / `Common` colors,
SmoothPlastic (Neon only for ghost-green glow, candle flames, eyes, lantern panes; Glass only for the window
shards and the rose window). Exceptions are in the Notes column. Skulls, bones and coffins are stylized blocks.

## 1. Kit models

| Name | Parts | Size (about) | Notes |
|---|---|---|---|
| `Tombstone_A` / `_B` / `_C` | 3 / 3 / 4 | 4 x 5 | Round top / leaning pointed / block with a small cross |
| `Cross_Stone` | 4 | 4.6 x 8.8 | |
| `Open_Grave` | 10 | 10 x 4 x 11 | Dark pit plate (no collision), low rim, dirt mound, headstone, shovel |
| `Crypt_Small` | 16 | 13 x 17 x 15 | Small mausoleum, closed door 6 x 9 with a green slit, not enterable |
| `Iron_Fence_Dead` | 9 | 8 long x 5.6 | Posts at both ends (sections overlap by half a post) |
| `Iron_Gate_Arch` | 20 | passage 11.6 wide, 16 tall | Two stone posts, iron arch, two open leaves |
| `DeadTree_Grave_A` / `_B` | 2 / 1 | 13 x 28 / 9 x 22 | Recolored `Swamp/TwistedTree_B` and `Common/DeadTree_A` |
| `Dead_Rock_M` / `_L`, `Dead_Cliff_A`, `Dead_Grass_A` | 1 / 2 / 6 / 1 | 8 / 25 / 58 x 54 x 38 / 4 | Recolored `Common/Rock_*_A`, `Swamp/Swamp_Cliff_A`, `Common/GrassTuft_A` |
| `Crow_Perch` | 11 | 4 x 9 | Post + recolored `Swamp/Crow_A` |
| `Lantern_Grave` | 7 | 2.5 x 8 | Part `Lantern` (Neon) holds PointLight `Light` (0.8, range 18, no shadows); the arm points to +X |
| `Skull_Wall_Panel` | 28 | 12 x 10 x 1.6 | Six skulls on two shelves. Pivot in the backing plane: place it 0.5 in front of the wall |
| `Bone_Pile_Dead` | 13 | 4 x 3 | Scatter with decor = true |
| `Stone_Coffin` | 6 | 5 x 4 x 10 | |
| `Coffin_Niche` | 9 | 12 x 7 x 4 | Wall niche with a coffin; back at +2: place the pivot 2 studs in front of the wall. Dead_4 and the arena recolor the coffin to stone |
| `Candle_Cluster` | 7 | 2.6 x 3.3 | Neon flame tips, no light. Part `Wax` has the Attachment `FlamePoint` (for `Candle_Flame`) |
| `Cobweb_A` | 5 | 7 x 7 flat | Decor only, Transparency 0.55. **Pivot at the right-angle corner** (attribute `PivotAtCorner`): legs go +X and -Y |
| `Catacomb_Arch` | 12 | passage 24 x 16, 37 x 22 | Skull keystone with green eyes on the -Z side |
| `Bone_Chandelier` | 35 | 14 across | **Pivot at the lowest point**, attribute `Height` = 12 (scale it for other heights). Part `Chain` holds PointLight `Light` (0.9, range 24) |
| `Gothic_Window_Broken` | 13 | 10 x 28 x 2.6 | Frame + 7 Glass shards. Used at scale 1.5 in the cathedral walls |
| `Pew_A` / `Pew_Broken` | 4 / 6 | 10 long | |
| `Organ_Pipes` | 32 | 32 x 34 x 10 | Used at scale 1.3 |
| `Cathedral_Pillar` | 7 | 10 x 50 x 10 | |
| `Rubble_Pile_A` | 7 | 9 x 3 | |
| `Floating_Candle` | 3 | 1 x 3 | Decor only, pivot at the lowest point |
| `Chain_Skull_Lock` | 13 | 24 x 16 | Chains + lock + skull for a 24 x 16 door; pivot at the door's bottom center, sits on its -Z face |
| `Black_Pillar_GreenFlame` | 9 | 9 x 41 x 9 | Part `Bowl` has the Attachment `FirePoint` (put `Green_Flame` there) |
| `Royal_Carpet_Section` | 3 | 16 x 20 | Dark blue-purple with silver trim, decor only (no collision) |
| `War_Banner_Dead` | 10 | 7 x 17 | Standing banner; the cloth is the Part `Cloth` |
| `Armor_Stand_Dead` | 9 | 5 x 9.5 | Green visor |
| `Hanging_Cage_Dead` | 10 | 6 wide | Recolored `Hell/Hanging_Cage`: **pivot at the lowest point**, attribute `Height` = 24 |
| `Mirror_Standing` | 11 | 5.4 x 11 | Part `Pane` (Reflectance 0.4), three crack lines |
| `LoS_Pillar` | 7 | 12 x 30 x 12 (shaft 10 x 10) | Boss arena line-of-sight pillar, light stone so it reads in the dark room |

### Gates (`ServerStorage.MapAssets.Gates`)

Opening 24 wide x 16 high, `Barrier` fills it, `PriceSign` 12 x 4 x 0.5 with its Front toward -Z (arriving player).
The bars / bones / chains are **children of the `Barrier` part** (CanCollide false) so destroying the Barrier
removes them; if the gate code only hides the Barrier it must also hide its children.

| Name | Parts | What |
|---|---|---|
| `Gate_Dead_2` | 32 | Catacomb mouth: stone portal with a pediment and skull, iron grille (Barrier Transparency 0.6) |
| `Gate_Dead_3` | 34 | Collapsed tunnel exit: beams, boulders, bone barricade with skulls (Barrier is a dark veil, Transparency 0.35). The sign hangs on the barricade (y = 13.6) so it is readable inside the 18-high tunnel |
| `Gate_Dead_4` | 31 | Sealed door in a pointed stone frame, wrapped in silver chains with the skull lock (Barrier = the door) |
| `EntryArch_Dead` | 32 | Wrought-iron cemetery arch, two lanterns (lights 0.8 / 16), a crow, `NameSign` 14 x 4 x 0.5; no Barrier, no price |

## 2. Lighting presets

Format of `docs/VFX_KIT.md`. The Sky is the stock sky with `CelestialBodiesShown = false`; the night sky comes
from the Atmosphere (`Haze = 10`), as in Hell. `EnvironmentDiffuseScale` / `SpecularScale` are 0. The moon of
Dead_1 is a Neon disc in `Dead_1.Decor.Backdrop` (not a celestial body).

| Preset | Intent | Clock / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | Tint / Saturation | Bloom |
|---|---|---|---|---|---|---|---|
| `Dead` | Graveyard: moonlit night, readable | 14.6 / -14 | 1.35 / 0.15 | 126,134,158 / 138,148,174 (ColorShift_Top 196,210,240) | 0.30, 10, 44,56,94 | 228,236,252 / -0.08 | 0.45 / 1.25 |
| `Dead_2` | Catacombs: dim candle-warm on bone grey | 14.6 / -14 | 1.2 / 0.28 | 170,156,134 (both) | 0.30, 10, 62,52,40 | 255,240,220 / 0.08 | 0.70 / 1.10 |
| `Dead_3` | Haunted Cathedral: cold blue-green | 15.2 / -14 | 1.45 / 0.15 | 118,138,160 / 130,152,174 (ColorShift_Top 180,220,228) | 0.31, 10, 36,62,84 | 218,240,242 / -0.04 | 0.50 / 1.20 |
| `Dead_4` | Royal crypt + boss arena: dark blue-black, green glow | 14.6 / -14 | 1.2 / 0.28 | 140,162,182 (both) | 0.28, 10, 16,34,46 | 226,255,240 / 0.10 | 0.70 / 1.10 |

`Dead_2` and `Dead_4` are interior presets (closed rooms, light comes from Ambient). They were only looked at
in Edit mode, where interiors render flatter and darker than in Play: check them in Play before changing them.
The ghost-green Neon reads cyan-white under the blue tint and bloom.

## 3. VFX prefabs (`ServerStorage.MapAssets.VFX`)

Same format as the other world prefabs (one invisible anchored Part, built-in particle textures, Rate <= 16).

| Name | What | Size | Emitters (sum Rate) + lights |
|---|---|---|---|
| `Ghost_Fog` | Low pale blue ground fog with faint green wisps (area) | 40 x 2 x 40, center about 1.5 above the ground | `Fog`, `Wisp` (7) |
| `Ghost_Light` | Floating green ghost light (point) | glow about 3 across | Attachment `Ghost`: `Glow`, `Orb`, `Trail` (9.5) + `Light` (0.8, range 14) |
| `Green_Flame` | Green fire for braziers and pillars (point) | about 1.5 wide x 3 high | Attachment `Fire`: `Flame`, `Core`, `Ember` (25) + `Light` (1.0, range 22) |
| `Candle_Flame` | Tiny warm flame (point) | 0.3 wide x 0.6 high | Attachment `Fire`: `Flame`, `Core` (11), no light |
| `Soul_Stream` | Slow rising pale-green motes (area) | 20 x 2 x 20, resize freely | `Motes`, `Glow` (11) |
| `Bats_Flutter` | A few dark flapping specks, decor (area) | 30 x 8 x 30, put it 30+ above the ground | `Bat`, `BatFar` (2) |

All lights have `Shadows = false` and count toward the 20-per-sub-zone budget (delete `Light` in the clone
when over budget). `GodRay` clones in Dead_3 are recolored to 150,255,200.

## 4. Where things are in the world

* `workspace.Zones.Dead.Dead_1` Graveyard: `Decor.Landmark` = `GreatCrypt` (north-west, front facing south,
  not enterable), three lawns at (18055, -40), (17940, -30), (18060, 62), gravel path on X = 18000, `EntryArch`,
  `HubReturn`, cemetery wall, hills, `Decor.Backdrop.Moon`. The corridor to the catacombs is cut into the north hill.
* `Dead_2` Catacombs: vestibule (Z 165..205), central tunnel, two side halls 80 x 75 (ceiling 26) at X = 17930
  and 18070, Ossuary 100 x 90 (ceiling 45, Z 300..390). `Decor.Landmark` = `Ossuary` (the giant chandelier, lowest
  point at Y = 23, plus four skull pillars in the corners; the hall itself is in `Decor.Structure`).
* `Dead_3` Haunted Cathedral: forecourt (Z 455..500), `Decor.Landmark` = `Cathedral` (shell X 17907..18093,
  Z 497..728, nave 80 wide between two rows of pillars at X = 18000 +/- 44). **The player path goes through the
  landmark**: the north wall (Z 722..728) has the 24 x 16 door opening at X = 18000; `Dead_4.Gate` stands in
  front of it at Z = 719.
* `Dead_4` Royal Sarcophagus Room: corridor 30 x 24 (Z 728..790), hall 180 x 150 x 50 (Z 790..940), `BossGate`
  on the north wall.
* `workspace._Staging.BossArenas.Dead`: round arena (radius 75) around `Decor.Landmark` = `RoyalSarcophagus`
  (plinth 30 x 50, about 22 tall, head to the north), Folder `LoSPillars` with four `LoSPillar` models at
  (+/-31.8, +/-31.8) from the center, west alcove = Skeleton General (`MiniBossSpawn1`), east alcove = Banshee
  Queen (`MiniBossSpawn2`), `BossSpawn` 50 studs north, `Door` + `PlayerSpawns` at the south.
