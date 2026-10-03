# ASSET KIT A - Common / Plains / Gates / Hub

Built by the MODELS agent (set A), 2026-10-03. 104 models, 1,489 parts in total.
Templates live in `ServerStorage.MapAssets.<Set>`; one clone of each stands in the preview line-up at
`workspace._Staging.AssetPreview.ModelsA.Lineup.<Set>` (ground centered on X = -3000, Z -312..159).

Use: `local m = Kit.asset("Common/PineTree_A"):Clone(); m:PivotTo(CFrame.new(groundPoint)); m.Parent = decorFolder`

## Conventions (true for every model)

* Every entry is a `Model`. Pivot = bottom center, identity rotation, front = -Z. `PivotTo(CFrame.new(groundPoint))`
  puts it standing on the ground. No `PrimaryPart` is set (gates: see below).
* All parts anchored, `SmoothPlastic` (or `Neon` for glow accents), colors from `Kit.Palette`
  (a few facets use a brightness shade of a palette color, same as `Kit.shade`). No scripts, no unions, no textures.
* `Model:ScaleTo(k)` works on all of them (trees and rocks look fine from about 0.7 to 1.4).
* Toolbox-sourced models carry the attributes `SourceAssetId` / `SourceCreator`.
* Collision: tree canopies / palm leaves are `CanCollide = false, CanQuery = false` (so `Kit.scatter` rays go through
  them); bushes, mushroom caps, flowers and grass do not collide; big rocks and trunks use `Hull`, small props `Box`.
* Lights: `PointLight`, `Shadows = false`, Brightness <= 1. Count them against the 20-per-sub-zone budget.
* Sizes below are bounding boxes X x Y x Z in studs (rotated meshes are slightly over-estimated).

Toolbox sources (all free, all sanitized with `Kit.sanitize`, no scripts found):

| Asset id | Creator | Used for |
|---|---|---|
| 127731233099210 | Veedubmike1 | oak/maple trees, dead tree, bush, grass, flowers, mushrooms, log, stump, twig, reeds, spire rock |
| 9682467046 | Proudism | round tree, rocks (3 meshes reused everywhere), bush, palm B, big log |
| 8973577087 | spinmaster243 | the 3 pine trees |
| 10354687850 | LoucDu44 | palm A |

## Common (46)

| Name | Size | Parts | Notes |
|---|---|---|---|
| OakTree_A | 24 x 28 x 24 | 2 | `Trunk`, `Canopy`. src 127731233099210 |
| OakTree_B | 19 x 34 x 18 | 2 | darker canopy. src 127731233099210 |
| OakTree_C | 21 x 27 x 26 | 3 | two round canopies. src 9682467046 |
| PineTree_A | 16 x 30 x 18 | 2 | `Trunk`, `Leaves` (light pine). src 8973577087 |
| PineTree_B | 14 x 38 x 16 | 2 | src 8973577087 |
| PineTree_C | 16 x 44 x 18 | 2 | src 8973577087 |
| DeadTree_A | 9 x 22 x 7 | 1 | src 127731233099210 |
| Bush_A | 7 x 4 x 6 | 3 | pink flowers. No collision. src 127731233099210 |
| Bush_B | 7 x 3 x 7 | 1 | No collision. src 9682467046 |
| GrassTuft_A | 5 x 3 x 4 | 1 | decor only. src 127731233099210 |
| GrassTuft_B | 4 x 2 x 4 | 1 | decor only, light green. src 127731233099210 |
| Flower_Red | 4 x 4 x 2 | 2 | `Bloom`, `Stem`; decor only. src 127731233099210 |
| Flower_Yellow | 3 x 5 x 2 | 2 | decor only. src 127731233099210 |
| Flower_Purple | 3 x 4 x 2 | 2 | decor only. src 127731233099210 |
| Mushroom_A | 8 x 5 x 6 | 2 | big red fantasy mushrooms; recolor `Caps`. src 127731233099210 |
| Mushroom_B | 9 x 5 x 8 | 2 | purple; recolor `Caps`. src 127731233099210 |
| Log_A | 10 x 3 x 4 | 1 | src 127731233099210 |
| Stump_A | 5 x 3 x 5 | 1 | src 127731233099210 |
| Rock_S_A | 4 x 2 x 4 | 1 | gray. src 9682467046 |
| Rock_S_B | 5 x 2 x 4 | 1 | light gray. src 127731233099210 |
| Rock_M_A | 8 x 6 x 8 | 1 | src 9682467046 |
| Rock_M_B | 11 x 9 x 11 | 1 | dark gray, tall. src 9682467046 |
| Rock_L_A | 25 x 14 x 22 | 2 | src 9682467046 |
| Rock_L_B | 25 x 22 x 22 | 2 | src 9682467046 |
| RockBlue_M_A | 9 x 9 x 10 | 1 | periwinkle. src 9682467046 |
| RockBlue_L_A | 30 x 17 x 26 | 3 | periwinkle group. src 9682467046 |
| Boulder_Cliff_A | 45 x 40 x 30 | 4 | natural wall segment about 40 wide, 38 tall (Hull collision). Overlap them by ~8 studs. src 9682467046 |
| Fence_Section | 8 x 4 x 1 | 4 | runs along X, tiles every 8 studs |
| Fence_Post | 1 x 5 x 1 | 2 | |
| Crate_A | 4 x 4 x 4 | 9 | |
| Barrel_A | 3 x 4 x 3 | 5 | |
| Signpost_A | 6 x 7 x 1 | 4 | blank board part `Board` (5.5 x 2.6), Front face = -Z |
| Ladder_A | 3 x 10 x 0.5 | 8 | vertical; tilt it yourself |
| Cart_A | 7 x 4 x 13 | 12 | handles toward -Z |
| Chest_A | 4 x 3 x 3 | 7 | gold bands, lock on -Z |
| Torch_Standing | 2 x 7 x 2 | 4 | Attachment `FirePoint` (on `Head`), Neon `Ember`, 1 PointLight |
| Torch_Wall | 1 x 4 x 2 | 4 | pivot = bottom of the bracket ON the wall plane; torch sticks out toward -Z. Attachment `FirePoint`, 1 PointLight |
| Lantern_Post | 4 x 10 x 2 | 8 | Neon `Lantern` + 1 PointLight; arm toward +X |
| Campfire_A | 7 x 2 x 7 | 11 | Attachment `FirePoint` (on `Embers`), 1 PointLight. src 9682467046 (stones) |
| Tent_A | 11 x 9 x 14 | 9 | A-frame, entrance on -Z; recolor `ClothL`/`ClothR`/`Trim` |
| Bridge_Wood_Section | 16 x 5 x 20 | 15 | deck 16 wide x 20 long (along Z), deck top at pivot Y + 1, rails on both sides |
| Dock_Section | 13 x 6 x 20 | 16 | 12 wide x 20 long (along Z), deck top at pivot Y + 5, piles down to pivot Y (sink it in the water as needed) |
| Stone_Pillar_A | 5 x 16 x 5 | 6 | |
| Stone_Arch_A | 36 x 28 x 6 | 11 | opening 24 wide x 16 high (to the spring line; 23 under the keystone) |
| Flag_Pole_A | 8 x 18 x 2 | 4 | pennant part `Cloth` (recolor), flies toward +X |
| Banner_A | 6 x 14 x 1 | 8 | standing banner; recolor `Cloth` + `ClothTail`; gold `Emblem` |

## Plains (31)

| Name | Size | Parts | Notes |
|---|---|---|---|
| Windmill | 53 x 69 x 29 | 94 | LANDMARK. Child Model `Blades` (pivot at the hub, axis = Z): `Blades:PivotTo(Blades:GetPivot() * CFrame.Angles(0, 0, a))` to spin. Door on -Z |
| FarmHouse | 32 x 30 x 28 | 51 | timber-frame cottage, walls 28 x 22, door 6 x 9 on -Z (not enterable), chimney |
| HayBale_A | 5 x 5 x 5 | 3 | |
| Scarecrow_A | 8 x 9 x 4 | 11 | |
| WheatPatch_A | 9 x 3 x 9 | 5 | decor only (no collision) |
| PalmTree_A | 26 x 28 x 27 | 9 | `Trunk` + 8 `Leaf`. src 10354687850 |
| PalmTree_B | 30 x 31 x 30 | 3 | `Trunk`, `Leaves`, `Coconuts`. src 9682467046 |
| PirateShip_Wreck | 117 x 64 x 48 | 74 | LANDMARK. Long axis = X (bow toward +X), already rolled 14 deg toward -Z and pitched. Pivot = lowest point; attribute `SinkDepth = 10`: place it at `groundY - 10` for the half-sunk look |
| Rowboat_Wreck | 14 x 5 x 11 | 12 | tilted, with oar and loose plank |
| SeagullNest_Rock | 12 x 11 x 12 | 6 | rock + nest + 3 eggs. src 9682467046 |
| Starfish_A | 3 x 0.4 x 3 | 5 | decor only |
| Shell_A | 3 x 2 x 3 | 3 | open clam with pearl; decor only |
| Driftwood_A | 12 x 2 x 10 | 1 | src 127731233099210 |
| AncientTree | 131 x 111 x 128 | 20 | LANDMARK. Root flare about 40 wide, trunk about 26. Canopy (Model `Canopy`) starts about 45 studs up and does not collide. Invisible `TrunkCollision` cylinder (22 wide); roots are climbable wedges. src 127731233099210 |
| HunterCamp | 27 x 8 x 25 | 29 | tent + drying rack + campfire spot (Attachment `FirePoint`, 1 PointLight) + seat log, crate, barrel. src 9682467046 |
| SpiderWeb_A | 14 x 11 x 0.5 | 17 | flat web in the XY plane, anchor points `AnchorA`/`AnchorB` at X = -7 / +7, center 6.5 above the pivot. Translucent, no collision |
| FallenLog_Large | 34 x 11 x 11 | 3 | hollow log with moss, along X. src 9682467046 |
| TallGrass_A | 6 x 6 x 6 | 1 | decor only. src 127731233099210 |
| Mine_Support | 29 x 19 x 4 | 10 | wooden frame, clear opening 20 wide x 16 high |
| Rail_Section | 5 x 1 x 20 | 9 | runs along Z, tiles every 20 studs, rails at X = +-1.6 |
| Minecart_A | 5 x 6 x 7 | 13 | wheels match Rail_Section (set it 0.25 above the rail pivot); gold ore load. src 9682467046 |
| Ore_Cluster_Blue | 9 x 7 x 9 | 6 | Neon `Crystal` parts + 1 PointLight. src 9682467046 |
| Ore_Cluster_Gold | 9 x 7 x 9 | 6 | Neon `Crystal` parts + 1 PointLight. src 9682467046 |
| Crystal_Cluster_A | 19 x 17 x 17 | 8 | large cyan + purple crystals, 1 PointLight (spider nest). src 9682467046 |
| Stalagmite_A | 8 x 12 x 7 | 2 | attribute `Height`. src 127731233099210 |
| Stalagmite_B | 7 x 8 x 6 | 3 | attribute `Height`. src 127731233099210 |
| Stalactite_A | 8 x 12 x 6 | 3 | hangs down; pivot is at the BOTTOM tip, attribute `Height = 12.2`: `PivotTo(CFrame.new(ceilingPoint - Vector3.new(0, 12.2, 0)))`. src 127731233099210 |
| Cave_Pillar_A | 30 x 64 x 29 | 4 | floor-to-ceiling rock column about 62 tall. src 9682467046 |
| Bone_Pile_A | 6 x 3 x 6 | 16 | skull, bones, ribs |
| Troll_Club | 17 x 8 x 8 | 12 | lying along X, spiked head toward +X. src 127731233099210 |
| Golem_Statue | 44 x 39 x 36 | 44 | dormant golem, 36 tall, on a low round `Plinth` (1.5 high, removable). Neon parts named `Rune` on the chest (7), dark `Eye` parts (2), `Moss`, `Crack`. 1 PointLight on the center rune. src 9682467046 |

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from.

| Name | Size | Parts | Notes |
|---|---|---|---|
| Gate_Plains_2 | 45 x 27 x 8 | 51 | wooden palisade gate (Plains -> Beach). `Barrier` = closed double door 24 x 16 x 1.4. `PriceSign` 12 x 4 x 0.5 above the lintel under a small roof. Two Attachments `FirePoint` on the torch embers (no light: add VFX fire) |
| Gate_Plains_3 | 71 x 35 x 29 | 36 | stone arch between two cliff pieces (Beach -> Forest). `Barrier` = INVISIBLE collidable 24 x 16 x 2 part; the visible rope-and-plank barricade parts are its children. `PriceSign` hangs under the keystone. src 9682467046 |
| Gate_Plains_4 | 86 x 58 x 38 | 32 | mossy stone door in a rock face (Forest -> Cave). `Barrier` = stone slab 24 x 16 x 3 with panels, Neon runes and moss as children. `PriceSign` = stone tablet on the lintel. Rock mass extends about 20 studs behind (+Z). src 9682467046 |
| EntryArch_Plains | 50 x 30 x 9 | 34 | decorative arch for the entrance of sub-zone 1: NO `Barrier`, NO `PriceSign`. `NameSign` 14 x 4 x 0.5 on top (Front face = -Z) for the zone name. 2 lanterns (2 PointLights), two pennants `Cloth` |

Gate notes:
* `Barrier` and `PriceSign` are direct children; `PriceSign` Front face (-Z) looks at the arriving player. `Kit.finishGate` works as is.
* The templates have no `PrimaryPart`. `Barrier.PivotOffset` is preset so the model pivot stays at the bottom center
  after `Kit.finishGate` sets `PrimaryPart = Barrier` (checked: 0 shift).
* The door decoration (bands, planks, ropes, runes, moss) is parented UNDER `Barrier` (attribute
  `BarrierDecorIsChildOfBarrier = true`, all `CanCollide = false`). Code that opens a gate must hide/destroy
  `Barrier` together with its descendants (destroying `Barrier` is enough; for a local fade use `Barrier:GetDescendants()`).
* Side pieces are 8+ studs wide but the gate does not fill the whole 250-stud edge: close the rest with cliffs/Bounds.

## Hub (23)

Stations: each has an invisible `Interact` part (6 x 6 x 6, CanCollide false) where the player stands, in front (-Z).
Shops also have an invisible `NpcSpot` marker (2 x 0.2 x 2) where the shopkeeper NPC should stand, facing -Z.
The contract names in `workspace.Hub` have no `Station_` prefix: rename the clone (for example `Station_WeaponShop` -> `WeaponShop`)
and call `Kit.addInteract`.

| Name | Size | Parts | Notes |
|---|---|---|---|
| PortalFrame | 20 x 23 x 7 | 17 | stone doorway, inner opening 12 x 16. `Surface` (Neon, Transparency 0.25, 12 x 16 x 0.4, no collision) = portal trigger; `Keystone` (recolor per zone; also the 2 small Neon `Accent` gems); `NamePlate` 9.5 x 1.9 on -Z for the zone name |
| Station_WeaponShop | 21 x 11 x 13 | 50 | red/white stall, weapon rack, anvil + forge on the +X side (Attachment `FirePoint`, 1 PointLight). `Interact`, `NpcSpot` |
| Station_Trainer | 24 x 11 x 18 | 48 | training yard: dummy, archery target, sword rack, fence corner, banner (`Cloth`). `Interact`, `NpcSpot` |
| Station_EggStation | 19 x 13 x 17 | 27 | nest with 3 big eggs under a lantern arch (1 PointLight), small sign `Board`. `Interact` |
| Station_TrophyMerchant | 16 x 11 x 11 | 45 | green stall with mounted boar head, horned skull, antlers, gold cup. `Interact`, `NpcSpot` |
| Station_RebirthAltar | 36 x 29 x 38 | 34 | HUB LANDMARK. 3 round tiers, 4 pillars, Neon `Crystal` (Attachment `EffectPoint`, 1 PointLight), stairs on -Z. `Interact` sits on the top tier |
| Station_RebirthShop | 20 x 16 x 17 | 39 | purple mystic tent, crystal ball (1 PointLight), moon emblem. `Interact`, `NpcSpot` |
| Station_DiamondShop | 19 x 20 x 11 | 56 | blue/white stall with a big Neon diamond sign (`Diamond` parts), gems on the counter, 1 PointLight. `Interact`, `NpcSpot` |
| Station_TeamBoard | 20 x 13 x 4 | 15 | notice board, part `Board` 10 x 5.6 (Front = -Z), red + blue pennants. `Interact` |
| Station_CodesBoard | 13 x 12 x 4 | 20 | notice board with pinned papers, part `Board`. `Interact` |
| Station_TutorialGuide | 14 x 10 x 13 | 20 | round stone platform, lectern with book, arrow signpost (`Board`), lantern (1 PointLight). `Interact`, `NpcSpot` |
| NPC_Villager_A | 4 x 6.5 x 3 | 17 | static figure (no Humanoid), 5.7 to the top of the head, straw hat + apron, faces -Z |
| NPC_Villager_B | 4 x 6.7 x 2 | 18 | static figure, red hair bun, blue dress + apron |
| Leaderboard_Board | 14 x 20 x 3 | 12 | framed board; flat part `Screen` 10.2 x 12.6 (Front = -Z) for a SurfaceGui; gold trophy on top |
| Cottage_A | 26 x 27 x 24 | 47 | timber-frame house, red roof, walls 22 x 18, door on -Z |
| Cottage_B | 24 x 36 x 24 | 55 | two-storey timber-frame house, blue roof, walls 20 x 18 |
| Fountain_A | 30 x 22 x 30 | 19 | hub centerpiece candidate; Attachment `WaterPoint` at the top spout (for VFX), 1 PointLight |
| Bench_A | 8 x 5 x 3 | 8 | |
| LampPost_A | 2 x 15 x 2 | 7 | Neon `Lamp` + 1 PointLight |
| Market_Awning_A | 16 x 11 x 10 | 37 | yellow/white fruit stand with barrel. `NpcSpot` (no Interact) |
| Well_A | 11 x 13 x 10 | 12 | |
| Hub_Wall_Section | 20 x 8 x 5 | 8 | low stone wall along X, tiles every 20 studs (one pillar at the -X end) |
| Hub_Tower | 23 x 61 x 24 | 47 | round stone tower, blue cone roof (tip at 54), flag `Cloth` on top (60), door on -Z |

## Not delivered / deviations

* Nothing is missing from the requested list.
* `Stalactite_A` and `Torch_Wall` keep the "pivot at the bottom" rule even though they attach at the top / on a wall (see their notes).
* `Leaderboard_Board` is 14 x 17 (+ trophy) rather than 12 x 16; `Hub_Tower` is 54 to the roof tip (60 with the flag);
  `Cave_Pillar_A` is a thick column without a narrow waist.
* `PirateShip_Wreck` is delivered un-sunk (pivot at its lowest point) so that the pivot rule holds: use `SinkDepth`.
