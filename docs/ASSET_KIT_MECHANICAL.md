# ASSET KIT - MECHANICAL CITY (zone 11, id "Mechanical")

Built by the Mechanical zone builder on 2026-10-04. Data only: no scripts, everything anchored, all models built
from parts (no Toolbox assets). Colors are `Kit.Palette.Mechanical` (+ blends of two palette colors: `Rust`+`Steel`
for rusty steel, `Floor`+`SteelLight` for the light floors, `Warning`+`Rust` for the dirty barrel yellow).

| What | Where |
|---|---|
| Kit models (33) | `ServerStorage.MapAssets.Mechanical.<Name>` |
| Gates / entry arch | `ServerStorage.MapAssets.Gates.Gate_Mechanical_2 / _3 / _4`, `EntryArch_Mechanical` |
| Lighting presets | `ReplicatedStorage.Assets.Lighting.Mechanical`, `Mechanical_2`, `Mechanical_3`, `Mechanical_4` |
| VFX prefabs | `ServerStorage.MapAssets.VFX.Sparks_Burst`, `Steam_Jet`, `Sludge_Bubbles`, `Hologram_Glow`, `Alarm_Light`, `Energy_Arc` |
| Preview (one clone of everything, safe to delete) | `workspace._Staging.AssetPreview.Mechanical` at X = -3000, Z = 7200 |

Conventions: Model, pivot at the bottom center, front = -Z, SmoothPlastic (DiamondPlate on a few decks and
floor plates, Glass on partitions / pods, Neon only for lights, screens, energy, sludge and warning lamps).

## 1. Kit models

| Name | Parts | Size (about) | Notes |
|---|---|---|---|
| `Conveyor_Belt_Section` | 18 | 10 x 3 x 21 | Runs along Z, tiles every 20. Walkable, attribute `TopHeight = 3` |
| `Giant_Gear` | 22 | 30 x 30 x 5 | Upright, face toward +-Z (yaw 90 to lay it against an X wall). Attribute `Diameter`. Sink it a few studs |
| `Gear_Stack` | 27 | 18 x 6 x 12 | Three flat meshing gears on a base |
| `Pipe_Straight` | 6 | 5 x 6 x 20 | Along Z on two saddles, axis at y 3.2 |
| `Pipe_Elbow` | 7 | 5 x 18 x 11 | Horizontal toward -Z, then up to 18 |
| `Pipe_Cluster` | 11 | 13 x 29 x 8 | Three vertical pipes (steel, copper, light) |
| `Crate_Metal` | 7 | 4 x 4 x 4 | Stackable |
| `Barrel_Toxic` | 6 | 3 x 4.4 x 3 | Dirty yellow, Neon green goo on the lid |
| `Broken_Machine_A` / `_B` | 10 / 9 | 12 x 12 x 7 / 8 x 12 x 5 | Attachment `SparkPoint` (put `VFX/Sparks_Burst` there) |
| `Robot_Arm_Static` | 10 | 6 x 14 x 11 | Yellow assembly arm reaching toward -Z; part `Wrist` = tool point |
| `Cable_Hanging` | 3 | 15 long | Decor only, **pivot at the top**, attribute `Length = 15` |
| `Catwalk_Section` | 19 | 10 x 16 x 20 | Deck 10 wide x 20 long at `DeckTop = 12`, railings on the X sides, open ends (tile along Z) |
| `Lamp_Industrial` | 4 | 4 x 11 x 4 | Decor only, **pivot at the lowest point**, attribute `Height = 10.6`; PointLight `Light` on `Bulb` (0.8, range 22) |
| `Warning_Barrier` | 10 | 8 x 3 x 2 | Yellow / black boards |
| `Sludge_Channel_Section` | 14 | 22 x 7 x 20 | Channel 12 wide along Z, Neon sludge at `SludgeTop = 2`, walkways + railings at `WalkTop = 3`. The zone sinks it 2 studs (walkways 1 above the floor) and keeps it behind invisible walls |
| `Big_Pipe_Wall` | 17 | 24 x 30 x 11 | Wall section with 2 horizontal + 2 vertical copper pipes on the -Z face |
| `Valve_Wheel` | 13 | 4 x 6 x 3 | Red wheel facing -Z on a pipe stub |
| `Metal_Walkway_Section` | 5 | 24 x 0.8 x 20 | Walkable grating, `TopHeight = 0.8` (zone sinks it 0.7) |
| `Sewer_Grate` | 6 | 6 x 0.4 x 6 | Decor only |
| `Screen_Wall` | 15 | 24 x 16 x 2 | 6 Neon screens on the -Z face |
| `Server_Rack` | 12 | 4 x 9 x 3 | Neon LEDs on the -Z face |
| `Console_Desk` | 7 | 8 x 6 x 3 | Operator side = -Z, two screens facing -Z |
| `Glass_Partition` | 5 | 12 x 10 x 1 | Glass 0.55 transparent |
| `Laser_Grid` | 8 | 12 x 11 x 1 | Decor only (no collision, no query), red Neon lines. Never on fight floors |
| `Hologram_Table` | 6 | 9 x 10 x 9 | Translucent cyan globe (no collision). Add `VFX/Hologram_Glow` at y 7 for light |
| `Security_Door_Frame` | 8 | 15 x 14 x 3 | Closed 10 x 12 door, decor |
| `Energy_Pillar` | 8 | 9 x 42 x 9 | Neon bands, `Coil` ball with Attachment `ArcPoint` (attribute `ArcHeight = 40.4`). Put `VFX/Energy_Arc` between two `ArcPoint`s |
| `Reactor_Core` | 31 | 30 x 48 x 30 | Neon cyan core in a black cage; PointLight `Light` on `Core` (1.0, range 26) |
| `Catwalk_Ring_Section` | 7 | 18 x 11 x 8 | Chord of a ring: deck at the pivot (struts hang 7 below), railing on the -Z (room) side. 24 at `Radius = 70` make a ring |
| `Warning_Sign` | 5 | 5 x 9 x 1 | Yellow diamond on a post, face toward -Z |
| `Hangar_Weapon_Rack` | 21 | 25 x 18 x 5 | Giant gatling + cannon on a rack (weapons on the -Z side) |
| `Charging_Station` | 10 | 12 x 18 x 12 | Glass pod (no collision) with cyan energy tubes behind it, back plate on +Z |

### Gates (`ServerStorage.MapAssets.Gates`)

Opening 24 wide x 16 high, `Barrier` fills it, `PriceSign` 12 x 4 x 0.5 with its Front toward -Z (arriving player).
Decor on the door (slats, hatch, wheel, laser lines) are **children of the `Barrier` part** (no collision, attribute
`BarrierDecorIsChildOfBarrier`): destroying the Barrier removes them; code that only hides it must hide its children too.

| Name | Parts | What |
|---|---|---|
| `Gate_Mechanical_2` | 31 | Rolling shutter (Barrier = steel shutter with slats) in a 60 x 31 factory wall, warning-striped jambs and lintel, roll housing, two Neon orange lamps |
| `Gate_Mechanical_3` | 43 | Round bulkhead: 12-block pipe ring (inner radius 15) around the opening, Barrier = dark slab with a round hatch, red wheel and two lock bars; wall 60 x 36 |
| `Gate_Mechanical_4` | 30 | Security door: Barrier = light steel door panel, 6 red Neon laser lines in front of it (children), black emitter strips on the jambs, keypad on the right wall, alarm lamps; wall 60 x 28 |
| `EntryArch_Mechanical` | 40 | Steel lattice gantry (opening 29 wide x 24 high), striped girder, Neon beacons, crane hook, `NameSign` 14 x 4 x 0.5 |

## 2. Lighting presets

Format of `docs/VFX_KIT.md`. Sky = the stock sky. Only looked at in Edit mode.

| Preset | Intent | Clock / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | Tint / Saturation | Bloom (Int / Thr) | SunRays |
|---|---|---|---|---|---|---|---|---|
| `Mechanical` | Abandoned Factory: dim warm work light, grey haze, sky through the broken roof | 14.8 / -14 | 1.7 / 0.05 | 146,132,112 / 160,152,134 | 0.30, 1, 190,190,192 | 255,218,182 / -0.08 | 0.40 / 1.3 | 0.05 |
| `Mechanical_2` | Industrial Sewers: dark teal, toxic green glow | 14.6 / -14 | 1.0 / 0.30 | 118,156,146 (both) | 0.34, 3, 40,92,80 | 222,255,240 / 0.10 | 0.70 / 1.1 | - |
| `Mechanical_3` | Control Center: clean cool blue, screens glow | 14.6 / -14 | 1.1 / 0.28 | 138,148,166 (both) | 0.28, 1, 56,76,100 | 232,242,255 / -0.04 | 0.70 / 1.1 | - |
| `Mechanical_4` | Reactor Core + boss arena: dark steel, cyan glow, red alarms | 14.6 / -14 | 1.1 / 0.26 | 142,146,158 (both) | 0.30, 1.2, 44,54,68 | 236,244,255 / -0.04 | 0.75 / 1.1 | - |

Lesson: with the stock blue sky, a warm Atmosphere color plus Haze 3-5 turned the whole factory teal-green (blue sky
+ yellow haze). Keep Haze about 1 in presets where the sky is visible and get warmth from the ColorCorrection tint.

## 3. VFX prefabs (`ServerStorage.MapAssets.VFX`)

Same format as the other world prefabs (one Part, built-in particle textures, Rate <= 16).

| Name | What | Size | Emitters (Rate) + beams + lights |
|---|---|---|---|
| `Sparks_Burst` | Short white-orange electric sparks falling + cyan flash | 2 x 2 x 2 volume (resize for an area) | `Spark` (14), `Flash` (3) |
| `Steam_Jet` | White jet blowing toward the part's **front (-Z)** + slow wisps | point, Attachment `Nozzle`; jet about 15 long | `Jet` (16), `Wisp` (4) |
| `Sludge_Bubbles` | Green bubbles, pops and drops (recolored `Swamp_Bubbles`) | 12 x 0.4 x 12 plate on the sludge, resize | `Bubble` (8), `Pop` (3), `Drop` (3) |
| `Hologram_Glow` | Cyan flickering motes + soft halo | point, Attachment `Glow` | `Flicker` (10), `Halo` (1) + `Light` (0.8, range 14) |
| `Alarm_Light` | **Visible** red Neon beacon (the root part itself, 1.4 x 1 x 1.4, no collision) + soft glow; no rotation script | point | `Glow` (2) + `Light` (0.9, range 18, red) |
| `Energy_Arc` | Three bright cyan shimmering Beams between Attachments `A` (part center) and `B` (default +20 X) + sparks at both ends | move the part to the first `ArcPoint`, set `B.WorldPosition` to the second | 3 beams `Arc1-3`, `Spark` (6) x 2 |

## 4. Where things are in the world

* `Mechanical_1` Abandoned Factory: hall 242 x 242 inside 40-high walls, rusty floor tiles, three DiamondPlate work
  floors (50 x 50) at (21950, -40), (22030, 20), (21960, 75); trusses at Y 40-46 every 25 (two broken in the middle),
  roof panels only on the west and east 60-stud strips (middle open to the sky). `Decor.Landmark` = `AssemblyMachine`
  on the east side (X 22073..22113, Z -40..80, 50 tall, pivot (22093, 0, 20)): no path through it. West conveyor line
  with four robot arms, two giant gears on the west wall, catwalk east of the entrance. `EntryArch` at Z = -86,
  `HubReturn` at (22020, -106) with a "Hub" sign. North door 24 x 20 into a roofed corridor to `Mechanical_2.Gate`
  (Z 145). Backdrop: 60 dark towers + 8 chimneys outside |X - 22000| > 150.
* `Mechanical_2` Industrial Sewers (fully enclosed): entry tunnel 30 wide (Z 147..200, ceiling 26), chamber A
  180 x 85 (Z 200..285, ceiling 34), chambers B (X 21880..21960) and C (X 22040..22120) 80 x 93 (Z 291..384,
  ceiling 30), cross tunnel 22-26 wide along the north (ceiling 26), exit corridor at X 22000. Sludge channels at the
  edges behind invisible walls (A south strip, B west, C east). `Decor.Landmark` = `PipeJunction` in a 54-high shaft
  on A's north wall (X 21970..22030, Z 282..322, pivot (22000, 0, 302)) with the sludge fall into a pool behind a
  railing + invisible wall. Groups at (22000, 245), (21926, 337), (22075, 337).
* `Mechanical_3` Control Center (fully enclosed): lobby 40 wide (Z 437..500, ceiling 24), operations hall 200 x 200
  (Z 500..700, ceiling 36) with console / screen / server strips 22 wide along the west and east walls (cyan line
  on the floor marks them), 8 columns at X = 22000 +- 75, decor laser grids on the side walls only. `Decor.Landmark`
  = `HologramMap` (platform 32 across, hologram up to Y 30) at (22000, 0, 655), north part of the hall; players walk
  around it to the exit door (24 wide) behind it. Groups at (21945, 560), (22055, 560), (21948, 645).
* `Mechanical_4` Reactor Core: corridor 30 wide x 24 high (Z 727..812), elliptical hall 180 x 150 (center (22000, 875),
  walls 52 high, flat ceiling at 52), catwalks at Y 20 along the wall (decor), six energy pillars with four arcs,
  six alarm lights. `BossGate` on the north wall at Z = 940 (armored blast door 30 x 36, cyan core emblem,
  `Interact` = the Neon screen on a pedestal 14 studs in front). Groups at (21962, 862), (22025, 885).
* Gates: `Mechanical_2.Gate` at Z = 145, `Mechanical_3.Gate` at Z = 435, `Mechanical_4.Gate` at Z = 725.
* `workspace._Staging.BossArenas.Mechanical`: `Floor` = disc 160 across (PrimaryPart, pivot at its top center
  (22000, 0, -600)), thin cyan seams, ring wall 70 high at radius 78 with a catwalk ring at Y 30, eight energy pillars
  in wall recesses (radius 81) with four arcs, flat ceiling at 70. North niche: `Decor.Landmark` = `ReactorCore`
  (Reactor_Core at scale 1.35, about 40 across x 65 tall, at Z +102) behind warning barriers + an invisible wall
  (Folder `Bounds`). West alcove (45 x 43, ceiling 40) = War Mech hangar with `Hangar_Weapon_Rack`
  (`MiniBossSpawn1` at X -95); east alcove = Sentinel Prime's `Charging_Station` (`MiniBossSpawn2` at X +95).
  `BossSpawn` at Z +60, `Door` (PrimaryPart `DoorPanel`, 24 x 20) at Z -76, `PlayerSpawns` at Z -64.
