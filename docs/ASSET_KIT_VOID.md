# ASSET KIT - THE VOID (zone 12, id "Void")

Built by the Void zone builder on 2026-10-04. Data only: no scripts, everything anchored, parts + recolored
clones of existing kit meshes. No new Toolbox asset was inserted.

| What | Where |
|---|---|
| Kit models (29) | `ServerStorage.MapAssets.Void.<Name>` |
| Gates / entry arch | `ServerStorage.MapAssets.Gates.Gate_Void_2 / _3 / _4`, `EntryArch_Void` |
| Lighting presets | `ReplicatedStorage.Assets.Lighting.Void`, `Void_2`, `Void_3`, `Void_4` |
| VFX prefabs | `ServerStorage.MapAssets.VFX.Void_Particles_Rising`, `Star_Twinkle`, `Crystal_Hum`, `Rift_Swirl`, `Void_Lantern_Flame`, `Ender_Wisp` |
| Preview (one clone of everything + a readability test, safe to delete) | `workspace._Staging.AssetPreview.Void` at X = -3000, Z = 7800 |

Conventions: Model, pivot at the bottom center, front = -Z, anchored, `Kit.Palette.Void` / `Common` colors,
SmoothPlastic (Neon only for crystals, runes, lanterns and rifts). Exceptions are in the Notes column.

**Crystal shapes** are clones of the `Crystal` MeshPart of `Plains/Crystal_Cluster_A` (mesh 100106311518324,
source asset 9682467046 by Proudism); models that use it carry `SourceAssetId` / `SourceCreator`. That source
MeshPart has a PointLight child: every Void clone had it stripped (298 lights removed). If you clone that crystal
yourself, delete its `PointLight`.

## 1. Kit models

| Name | Parts | Size (about) | Notes |
|---|---|---|---|
| `Void_Island_Rock` | 72 | 58 x 53 x 61 | Faceted pale-stone island underside, darker purple toward the tip, 2 hanging Neon crystals. **Pivot = TOP center** (attribute `PivotAtTop`). No collision / query |
| `Floating_Rock_Void_S` / `_M` | 4 / 4 | 10 x 11 / 19 x 23 | Recolored `Heaven/Floating_Rock_*` + a small Neon crystal. Decor only |
| `Obsidian_Pillar_Tall` | 21 | 16 x 81 x 16 | End pillar: obsidian shaft with ribs, Neon crystal on top inside an iron cage, 2 runes. `ScaleTo(0.55-1.1)` = 45-90 tall |
| `Obsidian_Block_Cluster` | 6 | 18 x 14 x 14 | Stacked obsidian cubes + a magenta crystal |
| `Pale_Stone_Rock_S` / `_M` / `_L` | 1 / 1 / 2 | 4 / 8 / 25 | Recolored `Common/Rock_*_A` meshes |
| `Void_Cliff_A` | 6 | 50 x 46 x 33 | Recolored `Swamp/Swamp_Cliff_A` at scale 0.85 |
| `Crystal_Tree_A` / `_B` / `_C` | 10 / 9 / 9 | 41 / 44 / 26 tall | Purple crystal trees. Only the trunk collides (branches, canopy, roots: CanCollide and CanQuery false) |
| `Crystal_Shard_Floating` | 3 | 6 x 9 x 4 | Decor only, **pivot at the lowest point** (attribute `Height = 8`) |
| `Crystal_Cluster_Void` | 8 | 19 x 17 x 17 | Recolored `Plains/Crystal_Cluster_A` (obsidian rock, Neon crystals), its light removed: add `VFX/Crystal_Hum` if wanted |
| `Crystal_Spire_Large` | 5 | 18 x 21 x 12 | Big crystal formation on an obsidian rock |
| `Glow_Plant_Void` | 3 | 3 x 6 x 2 | Chorus-like stalk with Neon bulbs. Decor only |
| `Void_Rubble_Pile` | 4 | 7 x 4 x 5 | Decor only |
| `Voyager_Tower_Broken` | 12 | 24 x 57 x 20 | Broken pale tower, purple bands, Neon window slits |
| `Floating_Bridge_Section` | 11 | 28 x 24 x 20 | Walkable deck 24 wide between 1.5-wide parapets (27 total) x 20 long along Z. Pivot = bottom of the deck slab, **deck top = pivot Y + 2** (attributes `DeckTop = 2`, `WalkWidth = 24`). Diamond keel + hanging crystal below. Parapets are low: add invisible walls (the zone puts them at +/-12.75) |
| `Stairs_To_Nowhere` | 11 | 11 x 20 x 30 | Seven steps rising toward +Z to 10.5, then three floating broken steps |
| `Voyager_Statue` | 14 | 7 x 19 x 6 | Hooded traveller with a lantern staff, faces -Z |
| `Void_Lantern_Post` | 10 | 3 x 15 x 3 | Open cage on an obsidian post, Neon core. Part `Bowl` holds the Attachment **`FlamePoint`**: put `VFX/Void_Lantern_Flame` there. No light of its own |
| `Ruin_Wall_Void` | 7 | 20 x 13 x 7 | Broken wall with a rune |
| `Ruin_Arch_Void` | 12 | 38 x 34 x 14 | Clear passage 24 x 16 (piers at +/-14.5), broken on one side, Neon rune on the keystone. Fits over a bridge mouth |
| `Rune_Stone` | 6 | 5 x 13 x 4 | Tilted obsidian standing stone, three Neon runes on -Z |
| `Dragon_Altar` | 28 | 41 x 32 x 31 | Stepped obsidian altar, two dragon heads facing -Z (magenta eyes), big Neon crystal. Also the arena landmark stand-in |
| `Crystal_Pillar_Arena` | 15 | 12 x 54 x 12 | Obsidian pillar with a crystal cluster and 4 floating Neon runes (decor) |
| `Reaper_Altar` | 19 | 16 x 20 x 9 | Dark altar, magenta candle flames, skull, big scythe leaning on it |
| `Crystal_Cage` | 17 | 15 x 18 x 15 | Round obsidian base + ring, 8 crystal bars, 4 runes, floating crystal core (no collision) |

### Gates (`ServerStorage.MapAssets.Gates`)

Opening 24 wide x 16 high, `Barrier` fills it, `PriceSign` 12 x 4 x 0.5 with its Front toward -Z (arriving player).
`Barrier.PivotOffset` is preset so the model pivot stays at the bottom center after `Kit.finishGate`. Decorative
curtain / lattice / rift parts are **children of `Barrier`** (CanCollide false, attribute `BarrierDecorIsChildOfBarrier`):
destroying the Barrier removes them; a local fade must also hide `Barrier:GetDescendants()`.

| Name | Parts | What |
|---|---|---|
| `Gate_Void_2` | 30 | Two ribbed obsidian pillars with crystals, lintel + pediment with the sign. `Barrier` = ForceField-material purple energy curtain with 5 Neon strips, a veil and a `Gate_Barrier_Glow` (recolored, no light) |
| `Gate_Void_3` | 30 | Crystal lattice between two big pale rocks (rocks at X = +/-29 hang beside a 27-wide bridge: 92 wide overall, with diamond keels below). `Barrier` = faint glass pane (Transparency 0.82) carrying 8 crystal `LatticeBar`s, a center crystal and a `Gate_Barrier_Glow` |
| `Gate_Void_4` | 33 | Portal ring (11 pale stones with Neon runes, open at the bottom, on two obsidian feet). `Barrier` = dark rift pane + Neon `RiftDisc` (30 across) + a `Rift_Swirl` (1 light). The sign hangs inside the ring above the opening |
| `EntryArch_Void` | 19 | Pale piers with obsidian insets, obsidian beam, `NameSign` 14 x 4 x 0.5 (dark purple), floating crystals, crystal horns. No Barrier, no price |

## 2. Lighting presets

Format of `docs/VFX_KIT.md`. The Sky is the stock sky with `CelestialBodiesShown = false`; the sky color comes from
the Atmosphere (`Haze = 10`, `Glare = 0`), as in Hell and Dead. `EnvironmentDiffuseScale` / `SpecularScale` are 0,
`GlobalShadows` on, `ShadowSoftness` 0.5, latitude -14, Bloom size 28. Stars are not in the Sky: each sub-zone has
Neon star specks (radius 380-650) and `Star_Twinkle` emitters in `Decor.Backdrop` / `Decor.VFX`.

| Preset | Intent | Clock | Brightness / Exposure | Ambient / OutdoorAmbient / ColorShift_Top | Atmosphere (Density, Color / Decay) | Tint / Sat / Contrast | Bloom (I / Th) |
|---|---|---|---|---|---|---|---|
| `Void` | Void Island: violet sky, pale stone with shadows | 14.6 | 2.0 / 0.05 | 128,112,152 / 142,124,170 / 255,236,250 | 0.30, 170,50,160 / 100,24,120 | 250,240,255 / 0.10 / 0.14 | 0.45 / 1.25 |
| `Void_2` | Crystal Forest: more violet | 14.6 | 1.9 / 0.08 | 134,110,166 / 148,120,182 / 240,215,255 | 0.32, 185,60,200 / 110,30,140 | 246,232,255 / 0.12 / 0.14 | 0.50 / 1.20 |
| `Void_3` | Voyagers' City: cold blue-violet | 15.4 | 1.95 / 0.05 | 128,120,165 / 140,130,180 / 240,230,255 | 0.31, 150,70,200 / 80,34,130 | 242,236,255 / 0.06 / 0.14 | 0.48 / 1.20 |
| `Void_4` | Heart of the Void + boss arena: magenta-purple, most dramatic | 16.0 | 2.0 / 0.08 | 142,118,162 / 154,128,178 / 250,236,250 | 0.30, 220,50,170 / 140,20,120 | 250,240,252 / 0.14 / 0.14 | 0.50 / 1.20 |

Atmosphere colors render much bluer than they read: a (52,24,92) color gave a navy sky, hence the strong red
component. Readability checked in Edit (`AssetPreview.Void`): a blue 5.5-stud figure, a magenta 6-stud block and a
red Neon telegraph disc all stand out on the pale stone. Void_4's ambient was neutralised after the last capture
(the arena floor read pinkish); not re-captured.

## 3. VFX prefabs (`ServerStorage.MapAssets.VFX`)

Same format as the other world prefabs (one invisible anchored Part, built-in particle textures, every emitter Rate <= 14,
lights Shadows off, Brightness <= 1).

| Name | What | Size | Emitters (sum Rate) + light |
|---|---|---|---|
| `Void_Particles_Rising` | Slow rising lilac-magenta motes + soft purple glows (area) | 40 x 16 x 40, resize freely | `Mote`, `Glow` (15) |
| `Star_Twinkle` | Big far sparkles + specks for the sky (area) | 200 x 60 x 200; the zones use 300 x 160 x 300 parts 400+ studs away | `Twinkle`, `Speck` (18) |
| `Crystal_Hum` | Soft pulsing purple glow + sparkles around a crystal (point) | glow 3-6 across | Attachment `Hum`: `Pulse`, `Sparkle` (3.8) + `Light` (0.8, range 14) |
| `Rift_Swirl` | Purple-black vortex: magenta outer swirl, dark core, black eye, particles pulled inward (`Pull`, Disc shape, Inward) | 20 x 20 x 1, plane = part XY (like `Portal_Swirl`) | Attachment `Center`: `SwirlOuter`, `DarkCore`, `Eye`, `Glow` + part emitter `Pull` (18.6) + `Light` (1.0, range 22) |
| `Void_Lantern_Flame` | Purple flame, white core, magenta embers (point) | about 1 x 2 | Attachment `Fire`: `Flame`, `Core`, `Ember` (21) + `Light` (0.9, range 16) |
| `Ender_Wisp` | Dark drifting wisps with magenta specks (area, decor) | 30 x 10 x 30 | `Wisp`, `Trail`, `Spark` (16) |

Bigger rift (sky): resize the part, multiply every emitter's `Size` keypoints and `Speed` by the same factor k, delete
`Light`, and turn it to face down: `fx.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(-90), 0, 0)` (Void_4 uses
k = 6 at Y = 165, the arena k = 7 at Y = 150, each with a black Neon `VoidEye` disc, a `VoidHalo` and a ring of
Neon `AccretionArc`s in `Decor.SkyRift`).

## 4. Where things are in the world

Zone X = 24000. Every walkable top is at Y = 0 (bridge decks at 0.2), built from flat faceted wedges (`Facet`,
pale stone; Void_2 forest floor is dark `Ground`) over faceted undersides (no collision). Below: one 2400 x 2400
`AbyssPlane` per sub-zone at Y = -201..-205 (no collision), floating rocks, distant islands and stars. Every island
edge and bridge side has invisible walls 102 high in `Bounds` (flood-fill checked from each Entrance: no leaks, the
walkable area stops at the next gate's Barrier).

* `Void_1` Void Island: island about 232 x 236, paved path on X = 24000, three fight plazas (discs 46 across) at
  (23945, -15), (24058, -8), (24000, 68); obsidian pillars on the rim; `EntryArch` at Z = -84; `HubReturn` at
  (24022, -103) with `HubReturn_Pad` and a "Hub" signpost. `Decor.Landmark` = **`CrystalPillar`** (32 x 32 base,
  about 158 tall with its crystal, pivot 23858, -6, 119) on its own unreachable islet north-west.
* `Void_2` Crystal Forest: island about 236 across, dark crystal-forest floor, pale clearings. `Decor.Landmark` =
  **`CrystalTree`** (about 80 x 80 x 112, pivot 24000, 0, 300) in a pale clearing 124 across. **The path loops under
  its canopy** (branches from Y = 52 up, trunk 18 wide collides; roots do not collide). Fight clearings at
  (23922, 252), (24078, 252), (24000, 382).
* `Void_3` Voyagers' City: entrance islet (24000, 482), plaza islands W (23928, 556), E (24072, 556), N (24000, 655),
  each with a 70 x 70 tiled plaza; four `Floating_Bridge_Section` bridges (gaps 16-21 studs) with `Ruin_Arch_Void`
  on the plaza-side mouths. `Decor.Landmark` = **`FloatingTower`** (two tilted octagonal pieces with a gap, crystal
  beacon, its own island-rock base included below the pivot 23862, -24, 700), unreachable, beyond the north-west edge.
  Six ruin islets beyond the walls in `Decor.Backdrop`.
* `Void_4` Heart of the Void: landing islet (24000, 768) with the Entrance, a 30-wide bridge (Z 783..819), circular
  platform R 88 centered (24000, 895), ten obsidian pillars at R 77, floating stone ring above, `Decor.SkyRift`.
  `BossGate` at Z = 966 (obsidian towers, double door, dragon-eye emblem; `Interact` in front at Z = 959).
* Corridors: bridges on X = 24000 with `Gate` at Z = 145 / 435 / 725, built in the next sub-zone's `Decor.Corridor`
  and `Bounds` (`GateLid` from `Kit.finishGate`).
* Arena `workspace._Staging.BossArenas.Void`: `PrimaryPart` = `Floor` (central disc R 25, pivot at its top center
  24000, 0, -600). **`FloorSections`** = Models `Section1`..`Section8`, each a 45-degree slice of the ring R 25..75 with its
  own top, underside, rim curb and purple seams (attributes `StartAngle` / `EndAngle` in degrees from +X toward +Z,
  Section1 = 0..45, `InnerRadius` 25, `OuterRadius` 75). Section tops are at Y = -0.02, so `Floor` is the highest floor
  surface; seams top out at Y = 0.01, below telegraphs at 0.05. **`SafetyNet`** (direct child, 260 x 260, top at
  Y = -12, invisible, collidable). West alcove: `Reaper_Altar` + `MiniBossSpawn1` (void_reaper); east alcove:
  `Crystal_Cage` + `MiniBossSpawn2` (void_crystal_warden); `BossSpawn` (void_dragon) 45 north. South: static
  `DoorLanding` with the 5 `PlayerSpawns` (Z = -679) and the `Door` model (`PrimaryPart` = `DoorSlab`, Z = -689).
  `Decor.Landmark` = **`DragonAltar`** (clone of `Dragon_Altar`, pivot 24000, -2, -478) on its islet beyond the north
  edge. Eight `Crystal_Pillar_Arena` on floating plinths at R 86, invisible walls 102 high + `Ceiling` at Y = 100.
