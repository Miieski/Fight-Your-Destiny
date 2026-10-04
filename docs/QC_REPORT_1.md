# QC REPORT 1 - Hub + Plains (zone 1)

Date: 2026-10-04. Reviewer: quality-check agent (read-only, Edit mode, no Play).
Scope: `workspace.Hub`, `workspace.Zones.Plains.Plains_1..4`, `ServerStorage.BossArenas.Plains`
(data only), 7 VFX prefabs. Desert and all scripts were not reviewed.

**Result: 0 blockers, 1 major, 15 minor.** The contract validators pass, the Hub and all four
sub-zones are closed, there are no holes, and every budget is respected.

Important limit of this review: while it ran, `game.Lighting` held the **Desert** preset
(ClockTime 15.6 then 16.1, Brightness 2.6-2.9, warm ambient), set by the Desert builder. Every
Hub / Plains screenshot was therefore taken under the wrong lighting. Shapes, layout, silhouettes
and signs could be judged; colour, brightness and shadow mood of the Hub and Plains under their own
presets (`ReplicatedStorage.Assets.Lighting.Hub / Plains / Plains_2 / Plains_3 / Plains_4`) could
not. See "Not checked".

## Summary

| Area | Blockers | Major | Minor |
|---|---|---|---|
| Hub | 0 | 0 | 4 |
| Plains_1 | 0 | 0 | 1 |
| Plains_2 | 0 | 0 | 2 |
| Plains_3 | 0 | 0 | 2 |
| Plains_4 | 0 | 1 | 3 |
| Boss arena (ServerStorage.BossArenas.Plains) | 0 | 0 | 0 |
| VFX prefabs | 0 | 0 | 1 |
| Cross-area / tooling | 0 | 0 | 2 |
| **Total** | **0** | **1** | **15** |

## Findings (most severe first)

### MAJOR

**QC1-01 - MAJOR - Plains_4 has no Landmark model**
* Where: `workspace.Zones.Plains.Plains_4.Decor` (children: MountainShell, Ground, Tunnel, CaveShell,
  VFX, Mine, Cavern). No child named `Landmark`, and no instance anywhere in Plains_4 carries a
  `LandmarkName` attribute. Plains_1..3 are correct (`Windmill` 69 studs tall, `PirateShip` 64,
  `AncientTree` 111; all three have a clear line of sight from the Entrance).
* Rule: AGENT_BRIEF section 4, "put each sub-zone's landmark in a Model named `Landmark` inside
  `Decor`, with attribute `LandmarkName`", and section 5, "each sub-zone has ONE large landmark
  visible from its entrance". `Kit.validateZone` does not test this, so it passed unnoticed.
* Fix: build or regroup one self-contained centrepiece Model `Decor.Landmark` (pivot at the bottom
  centre, 60+ studs, `LandmarkName` set, for example "CrystalPillars" or "GolemGateFacade") that is
  visible down the tunnel axis from the Entrance at (2000, 0, 765). The two `Cavern.Cave_Pillar_A`
  (64 studs tall, at (1948, 858) and (1924, 905)) are both on the west side and out of the entrance
  sight line, so they do not do the job as they are. Do not rename `BossGate` (contract model).

### MINOR

**QC1-02 - MINOR - Gates 2 and 3: nothing closes the opening above the 16-stud Barrier**
* Where: `Plains_2.Gate.Barrier` (2000, 8, 145) and `Plains_3.Gate.Barrier` (2000, 8, 435), both
  24 x 16. The corridor side walls (`Bounds.CorridorWest/East`) are 100 high, but between them the
  space above the Barrier is open from Y = 16 to 95 except where the lintel / arch happens to be
  (37 and 39 of 45 sample rays above the Barrier passed with no collidable part). Gate 4 is closed
  above (rock face).
* Not reachable today: the walk/jump flood (7.5-stud jump) finds no route over either Barrier. It
  becomes an escape as soon as anything raises jump height or adds a climbable prop in the corridor.
* Fix: add one invisible part per gate in the sub-zone's `Bounds` folder, 24 x 80 x 2, centred at
  (2000, 56, 145) and (2000, 56, 435). It starts at Y = 16, so it can stay in place when the gate
  opens.

**QC1-03 - MINOR - Plains_2: chest-deep water inside the playable area**
* Where: east strip X = 2075..2114, Z = 165..415. `Bounds.East` is at X = 2116, the water surface
  (`Decor.Water.Sea`) is at Y = -0.6 and the walkable seabed (`Decor.Shore` facets,
  `Decor.Ground.SeabedNear`) goes down to Y = -4.7 (lowest reachable point (2112, -4.7, 229)).
  Players and enemies can stand 4 studs under a 55 % opaque sheet: only the head is above water.
  The zone document asks for "shallow turquoise water".
* Fix: raise `SeabedNear` / the lower Shore rows so the reachable seabed is not below Y = -2.5, or
  move `Bounds.East` (and the ends of SouthE / NorthE) west to about X = 2080.

**QC1-04 - MINOR - Hub: players can walk under the sea next to the docks**
* Where: the two Bounds pockets around `Decor.Village.Dock_AFK` and `Dock_Harbor`. Reachable ground
  goes down to Y = -6..-8 (`Decor.Ground.Beach` facets, then `Decor.Sea.Seabed` at -7.5) in the
  areas X -120..-80, Z -160..-120 and X 40..80, Z -180..-140 (deepest reachable point
  (-102, -7.5, -152)), and to Y = -4 around (100, -120) and (140, -60); the water surface
  (`Decor.Sea.Water`, Transparency 0.2) is at Y = -3. A player there is almost fully hidden under the
  water sheet.
* Fix: pull the invisible walls in to the waterline (ground Y about -2) and keep only the dock
  decks walkable, or raise the seabed inside the pockets to Y = -4.5.

**QC1-05 - MINOR - Hub: the ten stations have no name sign**
* Where: `Hub.WeaponShop, Trainer, EggStation, TrophyMerchant, RebirthAltar, RebirthShop,
  DiamondShop, TeamBoard, CodesBoard, TutorialGuide`. The only texts in the Hub are the 12 portal
  name plates, the "AFK Zone" signpost and the 5 leaderboard titles. A station is identified only by
  its ProximityPrompt (12 studs).
* Fix: add a flat name board (about 12 x 3, SurfaceGui, Fantasy font, same style as the portal
  `NamePlate`) on each stall / building front, unless the UI layer is going to add BillboardGuis.

**QC1-06 - MINOR - Hub: 102 ParticleEmitters**
* Where: `workspace.Hub` (102 emitters, summed Rate 598/s; no emitter above Rate 20). Compare
  Plains_1 19, Plains_2 34, Plains_3 16, Plains_4 43, arena 33. Brief section 6: "Rate <= 20, keep
  the count low".
* Fix: drop the weakest layers of the repeated effects (for example one of the four emitters of each
  of the 12 portal swirls, ember layers on torches far from the plaza). Target about 60.

**QC1-07 - MINOR - Plains_2 Landmark pivot is not at the bottom centre**
* Where: `Plains_2.Decor.Landmark` (PirateShip). Pivot (2094.0, -13.6, 325.0); bounding-box centre
  (2081, 321). Offset 13.6 studs. Plains_1 and Plains_3 landmarks are correct.
* Fix: `Landmark.WorldPivot = CFrame.new(2081, -13.6, 321)` (keep the current orientation), so a
  Blender replacement drops in at the same place.

**QC1-08 - MINOR - Tooling: `Kit.ground` lands on top of the Bounds walls**
* Evidence: `Bounds.West` has CanCollide = true, CanQuery = false, and a default
  `workspace:Raycast` still hits it; `Kit.ground(1873, 0)` returns Y = 95.0 on
  `Plains_1.Bounds.West`. CanQuery = false has no effect while CanCollide is true, so the comment
  "Only parts with CanQuery = true are hit" in `tools/BuildKit.luau` is wrong for Bounds.
* Effect: any `Kit.scatter` or `Kit.ground` call made after the Bounds exist can put props on top of
  an invisible wall (Y = 95; Hub Y = 50) along the 2-4 stud wall strips. No such prop exists in the
  Hub or Plains (checked), but Desert and later zones are exposed.
* Fix (orchestrator, BuildKit): in `Kit.ground`, always add every `Bounds` folder (Hub, all zones,
  arenas) to the Exclude list, and correct the comment.

**QC1-09 - MINOR - Plains_4: narrow nooks beside the BossGate**
* Where: between `BossGate.PillarL` (1980, 964) and `Decor.Cavern.Rock_L_B` at (1964, 967), and
  between `PillarR` (2020, 964) and `Rock_L_B` at (2039, 966): floor pockets about 6 wide x 5 deep at
  (1968..1976, 960..968) and (2024..2038, 960..968), behind the 3.5-stud `BaseL` / `BaseR` blocks,
  with a rock overhang 3.4 to 7 studs above the floor on the east one.
* Risk: a player can get out by jumping (not a trap), but an enemy pushed or pathing in there can
  wedge. Fix: slide the two rocks 4 studs toward the pillars or fill the gap with a small rock.

**QC1-10 - MINOR - Hub: two prop intersections**
* `Hub.Decor.Props.AltarBackdrop.Bush_A` at (-31, 0, 100) sits inside
  `Decor.PortalFrames.PortalFrame_Hell.PillarBase`. Move it 4 studs away from the frame.
* `Hub.Decor.Props.AFKCorner.Bench_A` at (-83, 0, -98) is cut by `AFKCorner.Tent_A.ClothR` (the
  cloth passes through the bench 2.1 studs above the ground). Move the bench 3 studs out.

**QC1-11 - MINOR - Plains_1: trees growing through rocks / each other**
* `Decor.Trees.OakTree_B` at (1908, 0.4, -78) is inside `Decor.Rocks.Rock_L_A` (rock top 14 studs
  above the tree base).
* `Decor.Trees.OakTree_B` at (2101, 2.9, 81) intersects `Decor.Rocks.RockBlue_M_A`.
* `Decor.Trees.OakTree_A` at (2028, -0.6, 115) intersects the trunk of an `OakTree_C`.
* Fix: delete or move the three trees by 8-10 studs.

**QC1-12 - MINOR - Plains_3: trees growing through the giant fallen logs and rocks**
* `Decor.Props.FallenLog_Large` is 34 x 11 x 11 (twice the player's height). Trees intersect it at
  (1932, 640) OakTree_C, (2076, 556) OakTree_B, (2043, 480) OakTree_A, (2081, 594) OakTree_C.
  `OakTree_A` at (2067, 615) stands on `Props.Rock_M_A` (base 4.8 studs inside the rock) and
  `OakTree_B` at (2060, 554) intersects `Props.Rock_M_B`.
* The log at (2030, -0.6, 478) is the first thing on the right of the Entrance (13 studs from the
  path centre); it reads as a dark wall in the entrance view.
* Fix: move the six trees, and either scale `FallenLog_Large` down to about 0.6 or move the one at
  (2030, 478) at least 20 studs further from the Entrance.

**QC1-13 - MINOR - Plains_3: low canopies over two spawn groups**
* `plains_forest_archer` group (centre (1940, 0, 595)): an `OakTree_A` canopy hangs 7.1 studs above
  the ground inside the 36 x 36 fight area. `plains_giant_spider` group (centre (2055, 0, 660)): a
  `PineTree_B` leaf tier at 9.1. Brief section 5: nothing low-hanging over fight areas (camera at
  8-40 studs). The other groups are clear (lowest 11.2 in Plains_2, 12.2 for the bear group).
* Fix: move those two trees 10 studs out of the group radius.

**QC1-14 - MINOR - Plains_4: props buried in rocks**
* `Decor.Mine.Barrel_A` at (2012, 0, 798) is completely inside `Decor.Tunnel.Rock_M_B`.
* `Decor.Mine.Torch_Wall` at (1986, 7, 793) is inside `Decor.Tunnel.Rock_M_A` (the rock covers it
  up to Y = 10.3), so the torch and its flame are hidden.
* Overlapping clusters in the cavern: `Ore_Cluster_Blue` (1939, 943) with `Crystal_Cluster_A`;
  `Stalagmite_B` (1920, 885) and (2031, 841) with `Ore_Cluster_Blue`; `Ore_Cluster_Gold` (2061, 857)
  with a `Stalagmite_B`; `Mine.Chest_A` (1962, 842) with an `Ore_Cluster_Gold` crystal.
* Fix: move the barrel and the torch out of the rocks; separate the clusters by 4-6 studs.

**QC1-15 - MINOR - Plains_4 cavern is dim and low-contrast (judged under the Desert lighting)**
* View from (2000, 12, 834) toward the BossGate: the BossGate runes, crystals and bone piles read
  well, but floor, walls and stalactites are all the same dark blue-grey and the 20 PointLights
  barely show. This was seen under the Desert preset that was active in Studio, not under
  `Assets.Lighting.Plains_4` (Brightness 1.2, Exposure +0.3, blue ambient 0.51/0.57/0.69), which
  should be brighter.
* Fix: none requested yet. Re-check under the Plains_4 preset; if it is still flat, raise the torch
  PointLight Range/Brightness near the two spawn groups ((2042, 885) and (1958, 922)).

**QC1-16 - MINOR - VFX `Leaves_Falling_Jungle` reads as green bars, not leaves**
* Where: `ServerStorage.MapAssets.VFX.Leaves_Falling_Jungle.Leaf` (preview at (-2940, 13, 640)).
  Square texture with Squash keyframes down to -1.8: the particles are plain rectangles, several
  stretched into bars 2-3 studs long. Rate 6, lifetime 5-6.5 s, so about 35 on screen: fine.
* Fix: limit Squash to about +-0.8 and Size to 0.45, or use a simple leaf / diamond texture.

## Checked and fine

* **A. Contract:** `Kit.validateHub()` -> `hub: 4167 parts`; `Kit.validateZone("Plains")` ->
  Plains_1 2922 parts / 15 spawns, Plains_2 2669 / 15, Plains_3 2737 / 15, Plains_4 2010 / 10;
  `Kit.validateArena` -> `arena Plains: 1492 parts`. No FAIL line.
  Also verified: 12 portals with ZoneId and a name plate each; 10 stations with Interact +
  ProximityPrompt (MaxActivationDistance 12); HubReturn (Neon pad, Target = "Hub", 16 studs from the
  Entrance); EntryArch sign "Plains" visible from behind the Entrance; BossGate prompt
  "Enter / Golem's Lair", ZoneId = Plains; gate SubZoneId attributes and price signs (500 / 1.25K /
  3.12K Gold) facing south with a clear line of sight; one SpawnLocation only, facing the plaza.
* **B. Containment:**
  * Edge test Plains_1..3 (51 points per edge x heights 3 / 20 / 45, gate openings excluded): every
    sample is blocked by a Bounds part. The 10 "open" samples on the Plains_2 south / north edges at
    X = 2120 and 2125 are outside `Plains_2.Bounds.East` (X = 2116), so they are not leaks.
  * All 41 Plains Bounds parts: invisible, CanCollide, anchored, upright blocks, Y = -5..95 (cave
    walls -2..68).
  * Corridor sides (3 corridors, every 2 studs, 3 heights): closed.
  * Gate Barriers: each fills the whole 24 x 16 opening (384 samples per gate, 0 unfilled).
    Gate 3's Barrier is invisible on purpose; a visible rope-and-plank fence is parented to it.
  * Walk/jump flood fill from each Entrance (2-stud grid, 7.5-stud jump, any drop, rays that respect
    CanCollide): Plains_1 reaches X 1876..2124, Z -125..143; Plains_2 X 1876..2112, Z 147..433;
    Plains_3 X 1876..2124, Z 437..723; Plains_4 X 1914..2086, Z 727..969. No escape, no hole, no
    route over a Barrier. Highest standable point 38.5 (walls end at 95). The Plains_4 tunnel
    (Z 747..826) has no Bounds parts but its solid walls hold.
  * Hub: 49 Bounds walls, radial test at 0.5 degree steps x 3 heights has no open ray; flood fill
    from the SpawnLocation stays inside (X -150..148, Z -176..106), no hole, highest standable point
    14.4 against walls ending at Y = 50.
  * No real trap found (reverse-reachability on the flood graph; the only candidates were a
    3-stud-high space under `Dock_AFK` a character cannot enter, and the nooks of QC1-09).
* **C. Ground:** solid CanCollide ground under the Hub SpawnLocation, the 12 portals, the 10 station
  Interact parts, the BossGate Interact, HubReturn, the 4 Entrances and all 55 spawn points (gap
  under 1.5 everywhere). Path line X = 2000 from Z = -112 to 958 every 10 studs: no hole; the two
  anomalies are props on the axis (AncientTree root at Z = 598, the path goes round it; a minecart
  at Z = 797..803 in the tunnel with 17 studs free on the west and 7 on the east). No spawn point
  has a colliding part within 5 studs or anything above it; none is within 12 studs of an Area edge.
* **D. Combat space:** all 11 spawn groups have 5 points, spread 10, spacing 11.8, zero colliding
  parts taller than 3 studs within 18 studs, ground height range within 20 studs 0.0 to 1.1.
  Group-to-group distances 78..142 (minimum 78.1, Plains_1 bandit-boar). Entrance-to-group 75..201.
  Enemy ids match `Kit.Enemies`.
* **E. Budgets:** parts Hub 4167, Plains 2922 / 2669 / 2737 / 2010, arena 1492. Lights Hub 20,
  Plains 4 / 4 / 4 / 20, arena 15; no light has Shadows = true. No emitter above Rate 20. No
  unanchored part, script, union, constraint, value, remote, sound, decal or SurfaceAppearance.
  MeshParts 607 / 841 / 323 / 1302 / 328 / 203, all Box or Hull, none textured, no
  PreciseConvexDecomposition. Every visible part is SmoothPlastic or Neon; no Neon part larger than
  16 studs; no part colour further than 45 RGB units from a `Kit.Palette` colour (shading allowed).
  StreamingEnabled = true.
* **F. Floating / buried:** 2,272 top-level prop models found, 74 skipped by name (webs,
  stalactites, flags, VFX, water, lanterns, ropes), the rest tested. Nothing floats. The "floating"
  harbour barrels / crates in the Hub stand on the (rotated) dock decks; fence posts, half-buried
  rocks, dock piles and tunnel rocks are intended. Real intersections are listed in QC1-10..14.
* **Boss arena (data only):** floor = 150-stud cylinder, top at Y = 0, PrimaryPart set; 24 Bounds
  walls 80 high, radial test closed (95..127 studs); collidable ceiling over all 161 grid points of
  the floor; BossSpawn / MiniBossSpawn1 / MiniBossSpawn2 carry the right EnemyId and stand on solid
  ground (alcoves at X +-100); 5 PlayerSpawns in a row 66 studs south of the centre in front of the
  `Door` model (PrimaryPart `Slab`, 10 colliding parts); no colliding prop rises from the round
  floor within 68 studs of the centre.
* **Shadows under each zone's own preset** (computed with the preset sun direction, not seen):
  Plains_1 21 % of low ground in shadow (south strip and behind the hills; Entrance and all groups
  lit), Plains_2 4 %, Plains_3 31 % (mostly the AncientTree), Hub 3 %.
* **G. Visual (14 captures):** Hub from the spawn (altar, tower, portal ring and name plates
  readable, clean silhouettes) and from above (round plaza, stalls, docks, backdrop islets, no gap);
  Plains_1..3 from the Entrance and from above: low-poly faceted look consistent with the two
  reference pictures, landmark and exit gate both visible from each Entrance, open fight areas,
  path readable, no z-fighting, wall gap or prop through a wall seen. Plains_4 from inside the
  cavern. VFX: `Smoke_Chimney` (soft pale plume, fine) and `Dust_Motes` (sparse soft specks, fine).

## Not checked

* **Colour, brightness and atmosphere of the Hub and Plains under their own lighting presets.** All
  captures were made under the Desert preset. To redo once the Desert builder is finished: apply
  `Assets.Lighting.<Hub|Plains|Plains_2|Plains_3|Plains_4>` and retake the entrance views.
* **Boss arena visuals** (it is in ServerStorage and may not be moved). Data checks only.
* **Burst VFX `Hit_Spark`, `Block_Spark`, `Roll_Dust`, `Enemy_Death_Puff`**
  (`ReplicatedStorage.Assets.VFX`): their emitters are disabled with Rate 0 and an `EmitCount`
  attribute, so the previews at (-3075..-3015, 4, 540) show nothing in a still capture. Data only:
  2-3 emitters each, EmitCount 1-12, lifetimes 0.1-0.8 s, built-in Roblox particle textures, parts
  anchored / invisible / non-colliding, no script. They need a look in a play session.
* Anything that needs Play: real character movement and camera collision, StreamingEnabled pop-in,
  ProximityPrompt reach, enemy pathing, frame rate.
* Terrain voxels (rule 5) were not queried. Texture resolution: not applicable (no textured mesh).
* Desert, all scripts, `ServerStorage.MapAssets` kit models other than the three VFX prefabs.

## Method notes

* Nothing in the DataModel was created, changed, moved or deleted. The Studio edit camera was moved
  three times (10 s each) to let particle previews simulate and was put back afterwards.
* One capture landed on the Desert builder's view because both agents drive the same camera; it was
  discarded. A second one was taken before the particles had simulated and was retaken.
* The task note "Bounds have CanQuery = false, so test them geometrically" was followed (oriented
  box tests), then cross-checked with rays using `RaycastParams.RespectCanCollide`; see QC1-08.
