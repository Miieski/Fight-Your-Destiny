# Prop inventory - model upgrade (docs/model_upgrade_brief.txt, step 4A)

## Implant status (OWNER CORRECTION, 2026-10-19, FINAL state after the owner's import, read from Studio)

Read by Agent B from the live place (Studio id ab74fac5..., Edit mode), not from notes. "Generated" = the files exist:
`Blender/Props/<id>.blend` + `Blender_Exports/Props/<id>.fbx` (Blender), `tools/StudioProps.luau` (Studio-built),
`Blender_Exports/NPC/Hub/<id>.fbx` (NPCs). "Imported" = the applied import kept in `ServerStorage.ImportedProps.<id>`
(props) / the rig in `ServerStorage.NPCs.<id>` (NPCs). "n/total" = copies whose MapPropVersion is the current
template's: test area (`workspace._Staging`), main map (`workspace.Hub` + `workspace.Zones`), storage (kit
`ServerStorage.MapAssets` + `ServerStorage.BossArenas`). "Low-poly" = docs/prop_texture_guide.md: every visible
template part SmoothPlastic / Neon / Glass, no MaterialVariant, no SurfaceAppearance except the ColorMap-only
"Overlay" ones. "MeshIds" = every MeshPart of every tagged copy (nested props excepted) uses a MeshId of its
template (0 mismatches everywhere; the 120 template MeshParts all have an uploaded MeshId, 0 EditableMesh parts).

| model | generated? | imported? | template (ServerStorage.MapProps) | test area n/total | main map n/total | storage n/total | low-poly textured? | MeshIds = template's | notes |
|---|---|---|---|---|---|---|---|---|---|
| fountain | yes, Blender | yes (ImportedProps.fountain) | yes, 12 meshes + 13 parts | 1/1 | 1/1 | 1/1 | yes (Wall stone_block_lines Overlay, water_lines Ripples) | yes | |
| lamp_post | yes, Studio-built | n/a | yes, 14 parts + nested lantern | 1/1 | 6/6 | 1/1 | yes (bands, Plinth stone_block_lines) | yes (no meshes) | |
| crate | yes, Studio-built | n/a | yes, 39 parts | 2/2 | 39/39 | 2/2 | yes (bands) | yes (no meshes) | Abyss "Sunken" variant |
| barrel | yes, Studio-built | n/a | yes, 13 parts | 3/3 | 33/33 | 4/4 | yes (bands) | yes (no meshes) | |
| egg_nest | yes, Blender | yes | yes, 10 meshes (incl. Hull collider) + 2 parts | 1/1 | 5/5 | 1/1 | yes | yes | |
| rowboat | yes, Blender | yes | yes, 7 meshes + 3 parts | 1/1 | 6/6 | 1/1 | yes; Abyss "Sunken" = Color only | yes | hub copy: a beach rock goes through the bow (placement, as before) |
| minecart | yes, Blender | yes | yes, 6 meshes + 3 parts | 1/1 | 2/2 | 1/1 | yes | yes | |
| skull_bones | yes, Blender | yes | yes, 3 meshes + 2 parts | 1/1 | 16/16 | 13/13 | yes; Abyss "Pale" = Color only | yes | storage = BossArenas 12 + MapAssets 1 |
| scarecrow | yes, Blender | yes | yes, 13 meshes + 5 parts | 1/1 | 1/1 | 1/1 | yes | yes | |
| clam_pearl | yes, Blender | yes | yes, 5 meshes + 1 part | 1/1 | 29/29 | 1/1 | yes | yes | 5 Plains_2 copies sit 0.2 stud low (old placement): the lower shell is half in the sand |
| laundry_rack | yes, Studio-built | n/a | yes, 22 parts | 1/1 | 1/1 | 1/1 | yes (bands) | yes (no meshes) | |
| anvil_forge | yes, Blender | yes | yes, 12 meshes + 8 parts | 1/1 | 1/1 | 1/1 | yes (Hearth / Upper stone_block_lines) | yes | nested in each weapon stall |
| weapon_stall | frame Studio-built + Blender pieces | yes (pieces) | yes, pieces on the low-poly frame: 21 meshes + 62 parts | 1/1 | 1/1 | 1/1 | yes (ShieldFace plank_lines, frame bands + plank_lines) | yes | NPC / NpcSpot / Interact / prompt kept |
| lantern | yes, Studio-built | n/a | yes, 14 parts | 5/5 | 10/10 | 5/5 | yes (bands, Neon glass / flame) | yes (no meshes) | main count includes the lamp-post lanterns |
| well | yes, Blender | yes | yes, 10 meshes + 9 parts (the new well) | 1/1 | 1/1 | 1/1 | yes | yes | |
| chest | yes, Blender | yes | yes, 5 meshes + 3 parts | 1/1 | 5/5 | 1/1 | yes | yes | |
| trophy_stall | frame Studio-built + Blender pieces | yes (pieces) | yes, 6 meshes + 66 parts | 1/1 | 1/1 | 1/1 | yes | yes | NPC / NpcSpot / Interact / prompt kept |
| diamond_shop | frame Studio-built + Blender pieces | yes (pieces) | yes, 10 meshes + 56 parts | 1/1 | 1/1 | 1/1 | yes | yes | diamond sign, gems, cushions in place |
| npc_blacksmith | yes, Blender_Exports/NPC/Hub | yes (ServerStorage.NPCs, scaled back x28 to 6 studs; import in ImportedProps) | n/a | no stand-in in the Station copies | hub WeaponShop: imported rig in place of the stand-in | n/a | palette texture | n/a | FIXED (main agent, EnemyModels.build drops the importer's nested child meshes; rebuilt: 7 parts, 6.0 studs tall, in Edit and at run time) |
| npc_trophy_merchant | yes, same | yes, same | n/a | same | hub TrophyMerchant: imported rig | n/a | same | n/a | FIXED, same (7 parts, 6.0 studs) |
| npc_gem_merchant | yes, same | yes, same | n/a | same | hub DiamondShop: imported rig | n/a | same | n/a | FIXED, same (8 parts, 6.0 studs) |

Totals: 18 props, 222 tagged copies all up to date (test 25, main map 159, storage 38); 13 Blender props imported
(ServerStorage.ImportedProps) + 5 Studio-built; every template low-poly; MeshIds match everywhere. The 3 hub NPCs
are built (ServerStorage.NPCs, 6 studs tall) and stand at their stalls. Their first build carried the raw import
pieces nested under the Torso; FIXED 2026-10-19 12:10 (EnemyModels.build drops the importer's nested child meshes,
the 3 rigs rebuilt; checked in Edit and at run time: 7-8 parts, 0 giant parts; screenshots `implanted/*_main.jpg`
and `hub_stalls_final.jpg` retaken after the fix, the `zz_BUG_*` shots show the state before it). Mallet: dropped
(brief).

### Plains_1 fix (owner, 2026-10-19): new Studio-built templates and the house windows

| model | built by | template | copies synced n/total | parts / triangles (template) | notes |
|---|---|---|---|---|---|
| wheat_patch (kit `WheatPatch_A`) | `StudioProps.wheat_patch` | yes | 8/8 (Plains_1 6, test 1, kit 1) | 5 unions / about 4,300 | furrowed soil union + 4 row unions (PropFX sway "WheatRowA..D"); no collision, as before |
| hay_bale (kit `HayBale_A`) | `StudioProps.hay_bale` | yes | 7/7 (Plains_1 5, test 1, kit 1) | 4 parts (1 union) / about 1,300 | Hay + 2 Bands collide as before |
| cart (kit `Cart_A`) | `StudioProps.cart` | yes | 3/3 (Plains_1 1, test 1, kit 1; rule filter) | 40 parts (2 wheel unions) / about 2,500 | the other 5 `Cart_A` copies (hub harbour, Desert_2, Desert_3, Plains_4, Volcano_1) keep the old cart (not asked) |
| FieldBorder (Plains_1 only) | `StudioProps.buildFieldBorder(Farm.FieldDirt)` | n/a (unique) | 1 | 4 unions / about 2,000 | low worn plank border, open at the barrels; no collision |
| FarmHouse, Cottage_A, Cottage_B windows | `StudioProps.fixWindows(model)` | n/a (kit models, fixed in place) | FarmHouse 3/3, Cottage_A 5/5, Cottage_B 4/4 | per window: 6 new parts (2 jambs, head, sill, 2 glazing bars), the 3 old trim parts removed; crossed beams cut in 2-3 | the beams stop at the new window frames; walls, door, roof unchanged |

### Props batch 2 (owner, 2026-10-19): inventory before the remake (read from Studio)

Test zone = `workspace._Staging.AssetPreview.ModelsA.Lineup.<Folder>.<Kit name>`; kit = `ServerStorage.MapAssets.<Folder>.<Kit name>`.
Game copies were found by name AND by part-name similarity (renamed hub markers / zone gates / landmarks). No MapProps
rule exists yet for any of them. Backups: `BackUP_Files/old_props_2026-10-19_pre_batch2/<nn>_<id>.rbxm` (test + kit +
every game copy). "Parts" = BaseParts of one copy (test / game).

| # | object | test zone (kit) | game copies | parts test / game | functional content to keep | notes |
|---|---|---|---|---|---|---|
| 01 | wall | Hub.Hub_Wall_Section (MapAssets.Hub) | Hub.Decor.Village.Hub_Wall_Section x4 | 8 / 8 | none | |
| 02 | portal_pink | Hub.PortalFrame (Hub) | Hub.Decor.PortalFrames.PortalFrame_<Zone> x12 | 17 / 16 | frame: NamePlate SurfaceGui "NameGui"/NameLabel; the glowing field is NOT in the frame in the game: Hub.Portals.Portal_<Zone> (Part, attrs ZoneId / ZoneColor, BillboardGui NameTag; ZoneService teleports) | the test frame has its own "Surface" (pink field). PortalController finds the frame by name and recolours EVERY BasePart of it (black filter on locked zones): a union with UsePartColor false ignores Color, so the controller must toggle UsePartColor (code change) |
| 03a | entrance arch | Gates.EntryArch_Plains (Gates) | Zones.Plains.Plains_1.EntryArch | 58 / 58 | attr ZoneId=Plains; NameSign SurfaceGuis NameGuiFront/Back; 2 nested `lantern` MapProps (PointLight in Flame) | other zones have their own EntryArch_<Zone> kits (out of scope) |
| 03b | palisade + wooden door | Gates.Gate_Plains_2 (Gates) | Zones.Plains.Plains_2.Gate | 51 / 51 | Gate: PrimaryPart "Barrier" (CanCollide wall) whose CHILDREN are the door decor (GateController hides them + no collision when open, attr BarrierDecorIsChildOfBarrier); attr SubZoneId; PriceSign SurfaceGuis (PriceLabel set by GateController); Ember FirePoint attachments | Gate_Tundra_2 is a separate kit (0.85 similar), not in scope |
| 04 | barricade | Gates.Gate_Plains_3 (Gates) | Zones.Plains.Plains_3.Gate | 36 / 36 | same Gate contract; Barrier invisible (T1) with Plank x4 / Post x2 / Rope x8 under it (vanish when opened) | Toolbox rock attrs SourceAssetId/SourceCreator (Cliff meshes) |
| 05 | mine door | Gates.Gate_Plains_4 (Gates) | Zones.Plains.Plains_4.Gate | 32 / 32 | same Gate contract; Barrier visible with Panel / Emblem / Rune / Moss / Seam under it | Toolbox attrs as 04 |
| 06 | golem | Plains.Golem_Statue (Plains) | ServerStorage.BossArenas.Plains.Decor.Golem_Statue | 44 / 44 | PointLight in "Rune"; no NPC, no script | decor of the Golem boss arena (runtime clones) |
| 07 | windmill | Plains.Windmill (Plains) | Zones.Plains.Plains_1.Decor.Landmark (LandmarkName=Windmill) | 94 / 111 | game copy: + NoClimb folder (WindmillWall x16 + WindmillRoof, attr NoClimb: invisible-wall fixes) | the sails do NOT rotate today (no script anywhere) |
| 08 | stone arch | Common.Stone_Arch_A (Common) | none | 11 / - | none | test zone + kit only |
| 09 | pillar | Common.Stone_Pillar_A (Common) | BossArenas.Plains.Decor.Stone_Pillar_A x12 | 6 / 6 | none | |
| 10a | egg station | Hub.Station_EggStation (Hub) | Hub.EggStation | 39 / 33 | Interact (ProximityPrompt + BillboardGui NameTag; PetService + NPCService egg keeper marker); DisplayEgg_desert / _plains / _jungle (Models, attrs PetV2 / Height: the real egg models, must be kept); nested `lantern` MapProp | kit has EggSpot x6 + Egg x6 placeholders where the hub has the 3 DisplayEgg models |
| 10b | moon gazebo | Hub.Station_RebirthShop (Hub) | Hub.RebirthShop | 39 / 57 | Interact (prompt + NameTag); NpcSpot; NPC stand-in (18); TentRoof sub-model; PointLight in CrystalBall | |
| 11 | fruit stall | Hub.Market_Awning_A (Hub) | Hub.Decor.Village.Market_Awning_A x2 | 48 / 66 | NPC stand-in villager (14) in each hub copy; nested `barrel` MapProp | owner: no NPC / no sign on the new one: the hub NPC stand-ins are kept as they are (custom children) unless the owner says otherwise |
| 12 | training area | Hub.Station_Trainer (Hub) | Hub.Trainer | 48 / 65 | Interact (prompt + NameTag); NpcSpot; NPC stand-in (17) | |
| 13 | boards | Hub.Leaderboard_Board, Station_CodesBoard, Station_TeamBoard (Hub) | Hub.Leaderboard_Rebirths / _Zone / _Bosses / _Gold / _Damage; Hub.CodesBoard; Hub.TeamBoard | 12 / 20 / 15 | leaderboards: SurfaceGui "BoardGui" on "Screen" (no code writes it today); CodesBoard / TeamBoard: Interact (prompt + NameTag), TeamBoard = quartermaster NPC marker | |
| 14a | bench | Hub.Bench_A (Hub; rustic) | none of Bench_A in the game; the hub has 11 "Bench" (the nice one: 61 parts, 2 Seats, attr BenchVersion=2; AFKCorner x3, PlazaFurniture x8) | 8 / - | BenchService: every Model in workspace.Hub holding Seat parts gets a Sit prompt | plan: test + kit Bench_A become exact copies of the hub Bench |
| 14b | street lamp | Hub.LampPost_A (Hub) | Hub.Decor.Props.Lamps.LampPost_A x8 | 7 / 7 | PointLight in "Lamp" (always on; no on / off script) | |
| 15 | ship | Plains.PirateShip_Wreck (Plains) | Zones.Plains.Plains_2.Decor.Landmark (PirateShip); Tundra_2.Decor.Landmark.Ship (FrozenShip recolour, + 10 ice parts with MapFixCollide); Abyss_2.Decor.Landmark.Hull (SunkenGalleon recolour, scale 1.12) | 74 / 74 | attr SinkDepth=10; walkable deck | the Tundra / Abyss copies are recoloured variants (frozen / sunken): sync as variants |
| 16 | rebirth altar | Hub.Station_RebirthAltar (Hub) | Hub.RebirthAltar | 34 / 34 | Interact (prompt + NameTag; NPCService priest marker "RebirthAltar" opens the Rebirth window); Crystal: Attachment EffectPoint + PointLight; Hub.Decor.VFX.Altar_Aura / Plaza.AltarDais / Props.AltarBackdrop are separate map parts | |

Hub part budget: 5,350 BaseParts today (0 unions) for a 6,000 budget. The batch 2 objects use 696 of them in the hub
(wall 32, portal frames 192, egg station 33, gazebo 57, fruit stalls 132, trainer 65, boards 95, lamps 56, altar 34).

#### Props batch 2 remake status

Built from parts in Studio (`DevTools.PropsBatch2`, disk `tools/PropsBatch2.luau`) and merged into a few unions per
colour / material group (each union = 1 part of the hub budget), synced by `DevTools.SyncMapProps`. Screenshots:
`docs/screenshots/props_batch2/<nn>_<object>_*_before.jpg` / `_after.jpg`.

| # | object | MapProps id (rule) | replaced (test + kit + game) | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 02 | portal frame | `portal_frame` (names `PortalFrame`; `match` = `Hub.Decor.PortalFrames.PortalFrame_<Zone>`; variant = the zone) | 14 / 14 (test 1, kit 1, hub 12); 2nd run 0 | test 17 -> 11 (10 + its own pink `Surface`, kept with MapPropKeep); hub 16 -> 10 (9 unions + the `NamePlate` Part); about 4,050 triangles per copy | stone steps, coursed pillars with chamfered blocks and capitals, segmental arch with 7 voussoirs (keystone under y 22.6 so the portal's floating `NameTag` stays visible), name plate in a wooden frame with iron corner plates, glowing gem settings (old yellow diamonds), moss at the foot. `_Variants`: 12 zones (`Color_Gem` + `Color_Keystone`). The NameGui on NamePlate is carried over (texts kept); `Hub.Portals` and the teleport untouched. PortalController: locked-zone black filter turns `UsePartColor` on for unions and gives it back on reveal |

| 01 | wall | `hub_wall` (names `Hub_Wall_Section`) | 6 / 6 (test 1, kit 1, hub 4); 2nd run 0 | 8 -> 5 (Base, Stones, Cap, Grilles, Moss); about 4,000 triangles | 4 courses of real blocks (running bond, 0.09 joints over a mortar core, both faces), a wider base step of slabs (tread 0.8), dark overhanging cap slabs, the end pier in coursed blocks with a proud top course and its cap; the 3 old "Brick" plates are now 3 stone-framed openings (dark sill, light lintel, iron grille) at the same places; moss on the base step. 20.7 x 7.9 x 4.8 (was 20.3 x 7.9 x 4.8) |
| 08 | stone arch | `stone_arch` (names `Stone_Arch_A`) | 2 / 2 (test 1, kit 1); no game copy exists; 2nd run 0 | 11 -> 4 (Steps, Piers, Arch, Moss); about 7,400 triangles | piers of 10 courses (two blocks a course, alternating), two-step slab plinths, bevelled capitals (carved band + impost), a round arch of 11 voussoirs with V-grooved radial joints and a proud wedge-shaped keystone, moss at the foot and on the upper step, 3 ivy strands on the piers. 37.7 x 27.9 x 6.5 (was 36.4 x 27.5 x 6.0) |
| 09 | pillar | `stone_pillar` (names `Stone_Pillar_A`) | 14 / 14 (test 1, kit 1, Plains boss arena 12 at scale 3, scale kept); 2nd run 0 | 6 -> 4 (Base, Shaft, Capital, Moss); about 1,550 triangles | plinth of 4 blocks, carved base (bevelled torus + 2 octagonal fillets), fluted octagonal shaft (4 drums, middle band, 2 astragals), carved capital (bevelled echinus + abacus), 3 moss cushions on the plinth. Same size 5.4 x 16.4 x 5.4; Base / Shaft / Capital collide (precise), as before. No script reads the arena pillars (BossService only uses the arena's PrimaryPart and `Door`) |

| 03a | entrance arch | `entry_arch` (names `EntryArch_Plains`; `match` = `Plains_1.EntryArch`) | 3 / 3 (test 1, kit 1, Plains_1 1); 2nd run 0 | 58 -> 36 (8 + the 2 nested `lantern` props, 14 each, kept); about 15,100 triangles | stone piers of coursed blocks with slab caps, octagonal logs with iron collars and riveted bands, chamfered main / lower beams with iron bands and pegs, braces, the name board in a framed timber surround (NameGuiFront / Back kept, "Plains"), 4 trusses + ridge beam under a roof of individual red shingles with a ridge cap and bargeboards, the 2 flags, iron lantern brackets, moss at the piers. The passage stays open (no part in the 24 x 15 opening); attr ZoneId kept. The lanterns are the synced `lantern` prop (iron frame, Neon glass, warm PointLight 16 studs) |
| 03b | palisade + wooden door | `gate_palisade` (names `Gate_Plains_2`; `match` = `Plains_2.Gate`) | 3 / 3 (test 1, kit 1, Plains_2 1); 2nd run 0 | 51 -> 13; about 17,700 triangles | towers of 4 octagonal logs (log ends) on stone block bases, riveted iron bands, the lintel with bands and pegs, the PriceSign ("500 Gold" kept) framed between 4 posts under a shingle gable, 2 wall torches (bracket, stick, brazier; the 2 `Ember` parts with their `FirePoint` kept). Door under `Barrier` (PrimaryPart, collides, hidden with its children when opened): planks with V-joints, Z-braces, strap hinges with knuckles, back bands, gold ring handles. SubZoneId, BarrierDecorIsChildOfBarrier kept |
| 04 | barricade | `gate_barricade` (names `Gate_Plains_3`; `match` = `Plains_3.Gate`) | 3 / 3 (test 1, kit 1, Plains_3 1); 2nd run 0 | 36 -> 16 (incl. the 6 Toolbox cliff / grass meshes, kept as they are); about 6,800 triangles + the meshes | plinths of 2 slabs, piers of 10 courses, impost caps, a round arch of 9 voussoirs with V-joints and a proud keystone, the PriceSign ("1.25K Gold" kept) in a frame hung on ropes from iron eyes. Barricade under the invisible `Barrier` (it keeps blocking until opened, the same way): 2 pointed posts, 6 chamfered planks in layers with nails, rope lines to iron rings on the piers, rope wraps |
| 05 | mine door | `gate_mine` (names `Gate_Plains_4`; `match` = `Plains_4.Gate`) | 3 / 3 (test 1, kit 1, Plains_4 1); 2nd run 0 | 32 -> 21 (incl. the 8 Toolbox rock / moss meshes, kept); about 8,200 triangles + the meshes | dark stone frame: slab plinths and caps, piers of 9 courses, cyan rune strips in dark plates, a flat-arch lintel of 5 blocks with fanned joints, capping slabs, the PriceSign ("3.12K Gold" kept) in a studded frame. Door under `Barrier` (collides, carries the gate prompt): leaves of big stone blocks with V-joints, studded iron border straps, emblems in iron rims with the glowing rune diamonds, ring pulls, moss at its foot |

| 16 | rebirth altar | `rebirth_altar` (names `Station_RebirthAltar`, hub `RebirthAltar`) | 3 / 3 (test 1, kit 1, hub 1); 2nd run 0 | 34 -> 10 (9 unions + the kept Interact); about 8,700 triangles | 3 tiers of cut blocks (radii 18 / 14 / 10, an inner ring of flags), 6 stair risers of 1.0 over the old 3 steps' run (walkable: tread tops 1 .. 6), 4 columns (carved base, 2 fluted drums with a band, carved capital, gold bowl with a static Neon pink flame: the old ones did not flicker), a carved octagonal pedestal (8 sunk panels), the engraved 16-sided gold ring, Agent A's 4 faceted crystals (facet JSON planes, "place" positions; the main one now stands on the ring), 6 Neon pink rune circles, light moss. Interact (prompt "Rebirth" + NameTag) kept; the main crystal keeps the PointLight (30, 966EFF) and the EffectPoint at (0, 21, 0) as before. 35.8 x 29.3 x 38.3 (was 36 x 29 x 38.4) |
| 10a | egg station | `egg_station` (names `Station_EggStation`, hub `EggStation`) | 3 / 3; 2nd run 0 | 33 -> 26 (5 unions + Interact + the 3 real zone eggs DisplayEgg_* 2 parts each, MapPropKeep + the nested lantern 14) | plinth of cut blocks on a darker rim step, a nest of 18 leaning staves with 2 rope bands, a rim of straw bundles, a straw bed with strands and twigs (top 3.38 under the eggs' feet 3.35), the thick arch (chamfered timbers, iron shoes, riveted iron plates, rope lashings), lantern hook and chain, the signboard with a painted egg. The test zone and kit had placeholder ball eggs: they now carry copies of the hub's real zone eggs (same places), like the game |
| 10b | moon gazebo | `moon_gazebo` (names `Station_RebirthShop`, hub `RebirthShop`) | 3 / 3; 2nd run 0 | hub 57 -> 32 (12 + Interact + NpcSpot + the NPC stand-in 18); test 39 -> 14 | hexagonal plank deck with a dark rim, the blue rug and its gold ring, 6 posts on carved bases with gold bands and carved caps, ring beam with knee braces, hip rafters, a roof of individual purple shingles (today's 150,110,255) with darker hip caps and a gold finial, gold fascia with hanging ornaments, the moon crest (purple medallion, gold rim, a cut gold crescent, stars), 3 folded drapes with gold valance rods and tassels, the octagonal table, a gold claw stand with the glowing crystal ball (today's PointLight 12 / 5FD4FF) and its core, 2 candles with drips and flames. Interact ("Rebirth Shop"), NpcSpot, NPC kept |
| 11 | fruit stall | `fruit_stall` (names `Market_Awning_A`) | 4 / 4 (test 1, kit 1, hub 2); 2nd run 0 | hub 66 -> 35 / 36 (4 unions + NpcSpot + the nested barrel prop 13 + the NPC stand-in); test 48 -> 18 | the sibling stalls' construction and wood colours (posts on stone feet, knee braces, planked side panels and rails, counter with core / 3 front planks / kick board / stiles / 2 top boards / lip, low back wall of boards), rafters under a yellow / white striped awning (today's slope) with a scalloped valance, 3 slatted crates of faceted fruit (green apples, oranges, red apples with stems and leaves, stacked) and loose fruit. No sign; NPC stand-ins kept |

| 12 | training area | `training_area` (names `Station_Trainer`, hub `Trainer`) | 3 / 3; 2nd run 0 | hub 65 -> 39 (7 unions + Interact + NpcSpot + the NPC stand-in 17 + the barrel prop 13); test 48 -> 22 | sand yard (same 22 x 18 footprint) inside a border of cut stones with moss, pebbles and darker patches; the back and right fences rebuilt (chamfered pointed posts on footing stones, nailed rails, same places); the weapon rack (uprights on cross feet, 2 bars, pegs) with 2 wooden swords, an iron sword, 2 spears, 2 riveted round shields; 2 dummies (cross feet, post, rope-tied burlap body with straw, painted target, arm bar with straw ends, sack head with stitched eyes); 2 archery targets on tripods (straw faces with painted rings, rope rim, arrows); the banner (stone foot, pole, gold finial, swallow-tail cloth with gold trim and emblem); 2 slatted crates; the synced `barrel` prop added on every copy (custom child). Interact ("Train" + NameTag), NpcSpot, NPC stand-in kept |
| 13a | leaderboards | `leaderboard` (names `Leaderboard_Board`; `match` = `Hub.Leaderboard_<Stat>`) | 7 / 7 (test 1, kit 1, hub 5); 2nd run 0 | 12 -> 6 (5 unions + the kept `Screen`); about 2,900 triangles | base of slabs on a step, thick chamfered posts with iron bands and pegs, beams running past the posts, a backing of planks, a moulding round the Screen, riveted iron corner brackets, a small gable of blue shingles with the gold trophy on the ridge. `Screen` keeps its place / size and the hub copies keep their `BoardGui` (titles kept: Top Rebirths, Highest Zone, Boss Kills, Total Gold, Total Damage; no script writes them yet) |
| 13b | codes board | `codes_board` (names `Station_CodesBoard`, hub `CodesBoard`) | 3 / 3; 2nd run 0 | hub 20 -> 8 (7 + the kept Interact) | notice frame (2-block stone footings, banded posts, top beam, rail, planked backing, moulded board, iron brackets), red shingle gable, 5 pinned papers of different shapes (folded corner, torn edge, small notes) with written lines and coloured pins, the gold scroll ornament on the ridge. Interact ("Redeem" + NameTag "Codes") kept |
| 13c | team board | `team_board` (names `Station_TeamBoard`, hub `TeamBoard`) | 3 / 3; 2nd run 0 | hub 15 -> 8 | the same notice frame with a blue shingle gable, the 2 team shields (blue / red, today's places) in riveted iron rims with white chevrons, crossed swords, 2 flag poles with pennants and gold finials. Interact ("Open" + NameTag "Teams", the Quartermaster's marker) kept |
| 14a | bench | `park_bench` (names `Bench_A`: test zone + kit only) | 2 / 2; 2nd run 0 | 8 -> 61 (an exact copy of the hub `Bench`, BenchVersion 2, 2 Seats) | the old rustic Bench_A of the test zone / kit is now the current hub bench (wood slats, blue-grey frame). The 11 hub benches are the reference and are not synced; BenchService adds their Sit prompt at run time as before |
| 14b | street lamp | `street_lamp` (names `LampPost_A`) | 10 / 10 (test 1, kit 1, hub 8 in `Hub.Decor.Props.Lamps`); 2nd run 0 | 7 -> 4 (Base, Iron, Glass, Lamp); about 2,400 triangles | stone base of blocks with a cap slab, dark wrought-iron pole (collars, rings, a twisted section), 4 scroll brackets, a glass lantern (base plate, corner posts, bars, pyramid roof, finial and ring, candle) with a Neon flame carrying today's PointLight (range 24, brightness 0.9, FFD678). Same 2.4 x 15.3 footprint and height; no script toggles these lights (always on, as before) |
| 06 | golem | `golem_statue` (names `Golem_Statue`) | 3 / 3 (test 1, kit 1, Plains boss arena 1); 2nd run 0 | 44 -> 5 (Plinth, Body, Core, Glow, Moss); about 9,000 triangles | same pose and size (42.4 x 37.6 x 37.0, was 43.8 x 39.1 x 36): torso, belly, arms and legs of layered stone plates (bands alternately lapping, all edges chamfered, a dark core in the joints), a pelvis belt of blocks with a loin plate, knee caps with bosses, fists of 4 knuckles and a thumb, feet with 3 toes, the head with a brow over deep sockets (glowing cyan eyes) and a grooved jaw; today's 6 runes inlaid in dark grooves on a bordered chest plate around Agent A's faceted Neon core crystal (`golem__core_crystal`: it replaces the centre rune and carries today's PointLight 12 / 0.6 / 5AE6FF); Agent A's faceted shoulder boulders and 3 rubble boulders (JSON "place" positions); 8 engraved zig-zag cracks (today's 6 places + 2); faceted moss caps on the shoulders and 2 rubbles, moss pads on the head, a foot, an elbow and the base; a carved round base of cut blocks (2 rings, a centre disc, 8 glowing rune tiles). Collisions as before: Plinth / Body / Core collide (precise), the moss and the flush inlays do not; attrs SourceAssetId / SourceCreator kept; nothing reads it (BossService uses the arena's PrimaryPart and `Door`) |
| 07 | windmill | `windmill` (names `Windmill`; `match` = a `Landmark` with LandmarkName Windmill) | 3 / 3 (test 1, kit 1, Plains_1 1); 2nd run 0 | test 94 -> 8 (Base, Tower, Timber, Roof, Glass, Iron, Sails, Moss); game 111 -> 25 (the 8 + the 17 NoClimb walls, kept 17 / 17 at the same places: MapPropKeep on the folder); about 27,300 triangles | the same tower, roof and sails (53.3 x 68.7 x 28.5, was 53.1 x 68.6 x 29.0): a tapered round base of 3 courses of cut blocks under an overhanging cap ring, a stone landing with 2 slabs at the door; the white plastered octagonal tower (today's taper, 3 storeys with a soft gradient) in a dark timber frame (8 corner posts, 4 rings of girts, 12 diagonal braces, 8 corbels under the eave); a planked door with strap hinges, a ring pull and a timber frame; the 3 windows framed (sill, cross bars), the front one with an open planked shutter on iron hinges; an octagonal roof of individual red shingles (today's red) with hip caps, a valance and a gold finial; static sails (no script, as today): bearing frame, axle with iron bands, a toothed brake wheel, the hub with iron bands and today's gold cap, 4 stocks with lattice frames (rail + 8 bars) and cream cloth panels; moss at the foot and on the cap ring. The sails do not collide (as the game copy), everything else does; LandmarkName kept. `convexSolid` now centres its cutting cubes on the solid (the roof and the upper tower, 45 studs up, were not cut whole); the earlier props are unchanged (same fingerprints) |
| 15 | ship | `pirate_ship` (names `PirateShip_Wreck`; `match` = Plains_2 `Landmark` (PirateShip), Tundra_2 `Landmark.Ship` (FrozenShip), Abyss_2 `Landmark.Hull` (SunkenGalleon); variant = Frozen / Sunken from the parent Landmark's LandmarkName) | 5 / 5 (test 1, kit 1, Plains_2 1, Tundra_2 1, Abyss_2 1 at scale 1.12, kept); 2nd run 0 | 74 -> 24 (23 unions + the lantern glass); about 24,600 triangles | same size, place, heel and sink (116.8 x 63.6 x 45.5, was 117.0 x 64.3 x 47.8): a clinker hull of 11 strakes a side (planks 9-15 long, butt joints, lower edges 0.15 proud) joined to Agent A's curved bow and stern facets on the same rows, the 2 holes opened in the port planks (dark hold behind, broken planks), 4 gun ports a side with lids, keel and bottom planks; main / fore / stern decks of 1.5-wide planks (the bow's deck planks clipped under a waterway board), the red rail cap and bulwark stanchions; the forecastle (board wall, small door, 3 steps up from the main deck, railings), the stern cabin (board walls, corner posts, 5 gold-framed windows with cross bars, planked door with strap hinges and ring, a lantern on an iron bracket, the stern deck with railings), the rudder; the foremast (topmast, iron bands, crow's nest of staves, 2 yards) with Agent A's torn main sail (fore side, under the upper yard) and remnant (aft side, under a new lower yard: moved off the main sail, which it overlapped), shrouds with ratlines, lifts, the forestay to the bowsprit, a skull-and-crossbones flag; the broken mainmast (splinters, collar, hanging ropes), the fallen mast and yard over the port side with Agent A's fallen sail on the rail; the anchor hanging on the port bow with its rope; 3 barrels, the crate, 2 rope coils. Every union is one colour (3 tone unions per wood colour), so the `_Variants` Frozen (today's Tundra colours: snowy decks, lavender rails and stripe, icy sails) and Sunken (today's Abyss browns, sails and emblem at transparency 0.12, the lantern glass unlit) recolour the copies by name; SyncMapProps' variants now also take `Transparency_<Part>`. Decks in the hull's frame: main 12.4 (0.4 lower than before, level with Agent A's bow), fore 17.25, stern 22.3; 417 rays: every deck point hits a deck plank at its height except real objects (masts, barrels, crate, steps, rails), no invisible blocker at knee / chest height. Hull, decks, cabin, cargo collide (precise); ropes, sails, flag, emblem and lantern glass do not; SinkDepth / LandmarkName kept |

Hub part budget after 02: 5,278 BaseParts (-72). After batch A: 5,266 (-12, the 4 walls). Batch B is in Plains (no hub
change). After batch C: 5,150 (-116; per copy: altar 10, egg station 26, gazebo 32, fruit stalls 35 / 36, all under
the targets 30 / 30 / 40 / 45). After batch D: 5,051 (-99; trainer 39, boards 6 / 8 / 8, lamps 4; targets 50 / 12 / 5). Batch E is outside the hub (Plains boss arena, Plains_1,
Plains_2, Tundra_2, Abyss_2): the hub stays at 5,051 BaseParts (budget 6,000). Batch B uses self-coloured bevels (the cut faces take the block's own colour x1.1; the pilot and batch A keep
their pale grey bevels).


#### Props batch 2: final status (all 16 objects)

| # | object | generated (MapProps id) | test zone | game copies replaced | n / total (test + kit + game) | matches the fountain / well quality |
|---|---|---|---|---|---|---|
| 01 | wall | yes (`hub_wall`) | yes | hub 4 / 4 | 6 / 6 | yes |
| 02 | portal frame | yes (`portal_frame`) | yes | hub 12 / 12 | 14 / 14 | yes |
| 03a | entrance arch | yes (`entry_arch`) | yes | Plains_1 1 / 1 | 3 / 3 | yes |
| 03b | palisade + wooden door | yes (`gate_palisade`) | yes | Plains_2 1 / 1 | 3 / 3 | yes |
| 04 | barricade | yes (`gate_barricade`) | yes | Plains_3 1 / 1 | 3 / 3 | yes |
| 05 | mine door | yes (`gate_mine`) | yes | Plains_4 1 / 1 | 3 / 3 | yes |
| 06 | golem | yes (`golem_statue`) | yes | Plains boss arena 1 / 1 | 3 / 3 | yes |
| 07 | windmill | yes (`windmill`) | yes | Plains_1 1 / 1 | 3 / 3 | yes |
| 08 | stone arch | yes (`stone_arch`) | yes | none exists | 2 / 2 | yes |
| 09 | pillar | yes (`stone_pillar`) | yes | Plains boss arena 12 / 12 | 14 / 14 | yes |
| 10a | egg station | yes (`egg_station`) | yes | hub 1 / 1 | 3 / 3 | yes |
| 10b | moon gazebo | yes (`moon_gazebo`) | yes | hub 1 / 1 | 3 / 3 | yes |
| 11 | fruit stall | yes (`fruit_stall`) | yes | hub 2 / 2 | 4 / 4 | yes |
| 12 | training area | yes (`training_area`) | yes | hub 1 / 1 | 3 / 3 | yes |
| 13a | leaderboards | yes (`leaderboard`) | yes | hub 5 / 5 | 7 / 7 | yes |
| 13b | codes board | yes (`codes_board`) | yes | hub 1 / 1 | 3 / 3 | yes |
| 13c | team board | yes (`team_board`) | yes | hub 1 / 1 | 3 / 3 | yes |
| 14a | bench | yes (`park_bench`: an exact copy of the hub bench) | yes | no Bench_A in the game (the 11 hub benches are the reference, not synced) | 2 / 2 | yes (the hub bench) |
| 14b | street lamp | yes (`street_lamp`) | yes | hub 8 / 8 | 10 / 10 | yes |
| 15 | ship | yes (`pirate_ship`, variants Frozen / Sunken) | yes | Plains_2, Tundra_2, Abyss_2 3 / 3 | 5 / 5 | yes |
| 16 | rebirth altar | yes (`rebirth_altar`) | yes | hub 1 / 1 | 3 / 3 | yes |

100 / 100 copies replaced. `SyncMapProps.check()` (2026-10-19, after batch E): 42 templates, 343 tagged instances, all
up to date; a full `run()` twice: 0 replaced both times. Hub: 5,051 BaseParts (5,350 before props batch 2).


### Desert buildings and shelters (owner, 2026-10-19): inventory before the remake (read from Studio)

Test zone = `workspace._Staging.AssetPreview.Desert.<Kit name>` (the desert test row, not the ModelsA lineup); kit =
`ServerStorage.MapAssets.Desert.<Kit name>`. Game copies found by name and by part-signature similarity (part name +
size, every model of workspace and the boss arenas): no renamed copy exists, the boss arenas hold none. All copies are
at scale 1, none is tagged MapProp yet, none has a prompt, script, GUI, light, NPC, interior or attribute (the house
walls are solid blocks: the doors are decor plates on the wall, no prompt). No script reads these names (src and tools
grep). Backups: `BackUP_Files/old_props_2026-10-19_pre_desert_buildings/<nn>_<object>_<kit>.rbxm` (test + kit + every
game copy; manifest with pivots in the session log). "Parts" = BaseParts of one copy (every copy is identical).

| # | object | test zone (kit) | game copies | parts | functional content to keep | notes |
|---|---|---|---|---|---|---|
| 01a | adobe house, single storey (red door frame / awning) | Desert.ClayHouse_A (MapAssets.Desert) | Zones.Desert.Desert_2.Decor.Village.ClayHouse_A x5 (yaw -90 / -50 / -180 / 35 / 150) | 22 | none (the turquoise Door 6 x 9 x 0.6 is a plate on the wall; keep its place and collision) | 21.0 x 14.2 x 19.8; all parts collide |
| 01b | adobe house, two storeys (dome, terrace, blue awning) | Desert.ClayHouse_B (MapAssets.Desert) | Desert_2.Decor.Village.ClayHouse_B x2 (yaw -90 / 0) | 29 | none (Door plate as 01a) | 25 x 21.2 x 21.5; its left window overlaps the door frame by 0.3 (fix in the remake) |
| 02 | market stall (red / linen stripes) | Desert.MarketStall_A (MapAssets.Desert) | Desert_2.Decor.Village.MarketStall_A x4 | 23 | none: no prompt, no NPC, no shop interaction on the stall or in it | 12.3 x 9.5 x 8.5 |
| 03 | canopy pavilion (red / blue roof, rug) | Desert.NomadTent_B (MapAssets.Desert) | Desert_1.Decor.Camps.NomadTent_B x1 | 19 | none | 14.3 x 13.1 x 14.3; 2 parts already non-colliding |
| 04 | tent (red / gold) | Desert.NomadTent_A (MapAssets.Desert) | Desert_1.Decor.Camps.NomadTent_A x2, Desert_3.Decor.Camp.NomadTent_A x1 | 9 | none | 11.1 x 8.6 x 14.0. The same 9-part model (same part names and sizes, other colours) is also Common.Tent_A (red / linen: test lineup, Hub.Decor.Props.AFKCorner, Plains_2.Decor.PirateCamp) and Volcano.Miner_Tent (dark: test Volcano row, Volcano_1.Decor.Camp x2): other kits: OUT of scope (coordinator 2026-10-19: different kits / colours, the owner asked for the desert tent only; backed up in `04_tent_lookalikes_Tent_A_Miner_Tent.rbxm`) |
| 05 | ruined wall (sandstone, plaques) | Desert.Sandstone_Wall_Ruin (MapAssets.Desert) | Desert_2.Decor.Village.Sandstone_Wall_Ruin x1, Desert_3.Decor.Ruins.Sandstone_Wall_Ruin x2 (on a raised floor, y 24.3 / 20.3) | 9 | none | 20.4 x 13 x 8 |

Copies to sync: 01a 7 (test, kit, 5 game), 01b 4 (test, kit, 2), 02 6, 03 3, 04 5, 05 5 = 30.

#### Desert buildings remake status

Built from parts in Studio (`DevTools.PropsDesert`, disk `tools/PropsDesert.luau`; it reuses PropsBatch2's helpers
through `PropsBatch2.H` and its `install()`), merged into a few unions per colour group, synced by
`DevTools.SyncMapProps` (its search roots now include the desert test row `workspace._Staging.AssetPreview.Desert`;
no other rule finds anything new there). Recipe: docs/prop_texture_guide.md sections A and B, today's colours kept.
Screenshots: `docs/screenshots/desert_buildings/<nn>_<object>_*_before.jpg` / `_after.jpg`.

| # | object | MapProps id (rule) | replaced (test + kit + game) | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 01a | adobe house, one storey | `adobe_house_a` (names `ClayHouse_A`) | 7 / 7 (test 1, kit 1, Desert_2 5); 2nd run 0 | 22 -> 17: 9 unions (Walls, Frames, Door, Wood, Shutters, Awning, Pots, Ladder, Details) + 8 invisible `Collision` boxes; about 8,200 triangles | 22.8 x 15.5 x 20.4 (was 21.0 x 14.2 x 19.8): 6 battered plaster layers (layer lines, alternate layers proud, chipped corners, 4 exposed sandstone patches) on a 0.5-wider footing of blocks, light plaster bands at the lintel and under the parapet, parapet with caps, corner merlons and a lower middle, 5 drain spouts, 5 + 5 vigas with 28-degree cut ends and socket rings; the turquoise door at today's place (planks, battens, gold studs, iron hinge straps, gold knob) in today's terracotta frame with a wooden lintel and a threshold step; 2 windows cut 0.3 deep with terracotta frames, wooden lintels, today's sills, turquoise shutters open; the red awning as pleated cloth with a tabbed valance, linen piping, struts and rope ties (raised 1 stud: it crossed the vigas); chimney with a cap and a dark flue; roof hatch with a ladder; 2 clay pots on the roof. Door: same x / width / face, planks from the footing top (1.4) to 9, collides (box). Not climbable (main agent's Play test of the first version: the sills, vigas, awnings, spouts and thresholds let players reach the roof): the visible unions no longer collide (except the Door and B's Dome); invisible `Collision` boxes rebuild today's envelope (footing, walls, parapets, chimney; B: upper storey, cap) with vertical sides, plus a box flush with the door above it (no ledge on its top). Edit check: downward rays every 0.2 around each copy (outside the walls, out to 4 studs) find no standable top between 1.45 and 11.5 |
| 01b | adobe house, two storeys | `adobe_house_b` (names `ClayHouse_B`) | 4 / 4 (test 1, kit 1, Desert_2 2); 2nd run 0 | 29 -> 18: 10 unions (+ Dome) + 8 invisible `Collision` boxes; about 12,400 triangles | 26.1 x 22.4 x 22.4 (was 25 x 21.2 x 21.5): the lower block (5 layers) and the upper storey in light plaster (5 layers) under today's terracotta cap (2 capped slabs), bands, patches, the terrace parapet (today's 3 runs) with merlons and 4 spouts; vigas 4 front (the 2 over the door, which crossed its lintel, removed) + 6 back + 3 + 3 upper; the turquoise plank door at today's place with a lintel beam, threshold and a new gold knob; the lower left window narrowed to 2.6 and moved 0.7 left (it overlapped the door frame by 0.3) with a grille, the 2 others with turquoise shutters; the blue awning as pleated cloth; the dome on a light-clay drum with a terracotta base ring, 8 ribs (a ball intersected with 4 slabs) and a 2.1 gold finial (ball, collar, spike); 3 pots on the terrace; a ladder from the terrace to the upper roof. No ground pots on either house: the village has its own jars by the doors. Collisions as 01a (envelope boxes, the door and the dome collide) |
| 02 | market stall | `market_stall` (names `MarketStall_A`) | 6 / 6 (test 1, kit 1, Desert_2 4); 2nd run 0 | 23 -> 4 (Wood, Cloth, Goods + the invisible `Collision`); about 5,500 triangles | 13.2 x 9.5 x 8.8 (was 12.3 x 9.5 x 8.5), today's colours: posts 0.8 on sandstone footing blocks, beams and 3 rafters, the 6 red / linen strips as cloth with a sag, a tabbed valance with gold tassels and a dark binding, gold post finials; a counter of 9 vertical planks over a dark core with kick board, top rail and end stiles, a top of 3 planks; a back wall of planks with battens, a plank shelf on brackets; today's 3 jars as clay pots with painted bands, a tray of faceted fruit, folded blue / gold cloth stacks and a blue cloth draped over the counter. No prompt / NPC / shop existed. Collision: one invisible precise union of today's posts, counter, top, awning, back and shelf (today's loose goods, which were steps onto the counter, are not in it) |
| 03 | canopy pavilion | `canopy_pavilion` (names `NomadTent_B`) | 3 / 3 (test 1, kit 1, Desert_1 1); 2nd run 0 | 19 -> 7 (Canopy, Trim, Curtains, Wood, Rug, Glass + `Collision`); about 7,900 triangles | 14.5 x 14.0 x 14.5 (was 14.3 x 13.1 x 14.3): a canopy of 8 gores (today's red / blue quarters) with gold hip piping and linen seam piping, a linen valance with gold trims and scalloped tabs, gold tassels at the corners, the centre pole with bands, a gold collar, ball and spike finial; 4 octagonal posts on base blocks with dark bands, rope wraps and carved caps; the red back wall and blue side walls as pleated curtains, the sides gathered with rope ties; the red rug with a gold border, a gold diamond with a red heart and fringes; 4 cushions; a small lantern (warm glass, PointLight 10 / 0.5) on a bracket. Walk-under space unchanged: collision = today's posts, roof, valance, walls and finial (invisible union) |
| 04 | tent | `desert_tent` (names `NomadTent_A`) | 5 / 5 (test 1, kit 1, Desert_1 2, Desert_3 1); 2nd run 0 | 9 -> 5 (Canvas, Lining, Wood, Ground + `Collision`); about 2,400 triangles | 12.1 x 9.1 x 14.9 (was 11.1 x 8.6 x 14; the stakes and guy ropes are outside, non-colliding): each side 4 canvas panels (today's red / darker red) with raised seams, a hem and a ridge fold; a back gable with a seam; the front: today's gold lining as the 2 flaps folded back, red bindings, rolled flap edges with rope ties around the dark doorway; dark poles with gold ball caps and the ridge pole; 8 guy ropes to wooden stakes; a striped rug at the doorway; a low sand drift along one side. The entrance is closed today (the flaps collide): collision kept exactly (invisible union of today's parts) |
| 05 | ruined wall | `ruined_wall` (names `Sandstone_Wall_Ruin`) | 5 / 5 (test 1, kit 1, Desert_2 1, Desert_3 2); 2nd run 0 | 9 -> 4 (Walls, Glyphs, Sand + `Collision`); about 5,300 triangles | 20.4 x 13.6 x 9.0 (was 20.4 x 13 x 8): footing slabs; the 3 pieces (12 / 8.5 / 5 high) in courses of cut sandstone blocks (running bond, 0.09 joints over a dark core, chamfers, tone steps), a broken top (the middle piece loses the end of its top course, the low piece a block, its last block turned and slid out), a cracked block per piece; today's cap broken off at one end; today's 2 loose blocks; 5 rubble blocks half in the sand; today's 2 plaques as carved glyph plaques (frame, recessed panel, raised eye with a lapis pupil, water lines, a bird, an ankh, a gold sun); sand drifts along the foot. As climbable as today: collision = today's parts (invisible union) |

Collision check of 02-05 (Edit, rays every 0.5 on one game copy each, the new `Collision` against today's parts rebuilt at the same place): downward rays tent 986 / ruin 990 / stall 682 / pavilion 1,156 with no height difference over 0.25 (the ruin has 7 extra hits at the edge of a loose block's precise hull); horizontal rays at 1 / 2.5 / 4 / 5.5 through every side: no difference (1 on the ruin). The visible unions never collide. After 02-05: `Sync.check()` 48 templates / 373 instances all up to date, full run twice 0 / 0; hub 5,051.


### Desert gates and entrances (owner, 2026-10-19): inventory before the remake (read from Studio)

Test zone = `workspace._Staging.AssetPreview.Desert.<Kit>`; kit = `ServerStorage.MapAssets.Gates.<Kit>`. One game copy
each (no renamed copy elsewhere). Backups: `BackUP_Files/old_props_2026-10-19_pre_desert_gates/<nn>_<object>_<kit>.rbxm`
(test + kit + game copy).

| # | object | test zone (kit) | game copy | parts | functional content to keep | what reads it |
|---|---|---|---|---|---|---|
| 01 | Egyptian arch | Desert.EntryArch_Desert (Gates) | Zones.Desert.Desert_1.EntryArch (attr ZoneId=Desert) | 33 | NameSign SurfaceGuis NameGuiFront / NameGuiBack ("Desert"); 2 `Ember` Neon parts with PointLight 14 / 1 / FFD678 and a FirePoint attachment | nothing reads the arch by name (src grep); the zone portals use their own ZoneId attribute |
| 02 | pylon temple gate | Desert.Gate_Desert_4 (Gates) | Zones.Desert.Desert_4.Gate (attr SubZoneId=Desert_4, PrimaryPart Barrier) | 81 | Barrier (attr BarrierDecorIsChildOfBarrier) with its children: 37 Glyph, 4 Border, Seam (the hieroglyph door, hidden with the Barrier when the gate opens); 10 more Glyph on the towers; PriceSign SurfaceGuis PriceGuiFront / Back | GateController (client): `gate.PrimaryPart or Barrier`, hides the Barrier and its children, writes the PriceSign label; ZoneService (server): `subZone.folder.Gate`, attr SubZoneId, the gate prompt in the Barrier. No glow script: the "glow" is Neon parts (SunDisc) |
| 03 | canyon barricade gate | Desert.Gate_Desert_3 (Gates) | Zones.Desert.Desert_3.Gate (SubZoneId=Desert_3, PrimaryPart Barrier) | 49 | Barrier (invisible, T 1) with Plank x5, Cross x2, Chain x6, Lock, Keyhole under it; PriceSign SurfaceGuis | same Gate contract (GateController / ZoneService) |
| 04 | sandstone wall gate (owner, added 2026-10-20) | Desert.Gate_Desert_2 (Gates) | Zones.Desert.Desert_2.Gate (SubZoneId=Desert_2, PrimaryPart Barrier) | 50 | Barrier (dark wood, attr BarrierDecorIsChildOfBarrier) with Plank x8, Band x2, Seam, Ring x2 under it; PriceSign SurfaceGuis; 2 Neon `Ember` with a FirePoint attachment (no light) | same Gate contract (GateController / ZoneService); backup `xx_not_in_scope_Gate_Desert_2.rbxm` |

#### Desert gates remake status

Builders in `DevTools.PropsDesert` (01, disk `tools/PropsDesert.luau`) and `DevTools.PropsDesertGates` (02, 03, disk
`tools/PropsDesertGates.luau`), recipe docs/prop_texture_guide.md sections A, B and B12, today's colours. Collision rule of the desert buildings: the visible unions never collide, one invisible union
`Collision` rebuilds today's colliding parts. Screenshots: `docs/screenshots/desert_gates/`.

| # | object | MapProps id (rule) | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 01 | Egyptian arch | `egyptian_arch` (names `EntryArch_Desert`; `match` = `Desert_1.EntryArch`) | 3 / 3 (test 1, kit 1, Desert_1 1); 2nd run 0 | 33 -> 12 (Stone, Inlay, Gold, Cloth, Iron, Glow, Sand, Ember x2, NameSign, SignRear + `Collision`); about 14,800 triangles | 38.5 x 28.6 x 9.5 (was 38.5 x 28.5 x 8.5), passage unchanged (24 wide, 18 high): stepped bases (4 footing slabs, a chamfered plinth), the 2 piers in courses of cut sandstone blocks (alternating joints, chamfers, tones) with today's gold band (lapis diamonds) and lapis band (gold squares, gold rules) and a turquoise capital band with an abacus; the lintel of 5 cut blocks with today's turquoise band (lapis diamonds, gold dots, gold rules); a 2-stud cavetto cornice (torus rolls, fillet, 3 cove slabs with wedges and reed grooves, top slab); today's gold pyramid tips on stepped plinths, the top 40 % Neon gold with a soft PointLight (8 / 0.4); the name board (lapis back, gold frame and corner studs, today's NameSign / SignRear plates, a gold cap with a small winged disc); the 2 red banners on gold rods (4 folds, gold edge trims, today's gold tail band, a pointed end with a tassel, a gold ankh); the lamps (iron bracket and scroll, brass bowl with a rim, a Neon flame `Ember` with today's PointLight and FirePoint); sand drifts at the bases. ZoneId kept; the NameGuiFront / Back ("Desert") moved onto the new NameSign. Collision check (rays every 0.5 on the Desert_1 copy against today's parts): 1,701 downward rays, 2 off (the pyramid tips' precise hull), 405 sideways rays at 1 / 3 / 6 / 10 / 15: no difference |
| 02 | pylon temple gate | `pylon_temple_gate` (names `Gate_Desert_4`; `match` = `Desert_4.Gate`) | 3 / 3 (test 1, kit 1, Desert_4 1); 2nd run 0 | 81 -> 68 (TowerL, TowerR, Stone, Carving, Inlay, Gold, Wings, Poles, Cloth, Sand, `Collision`; Barrier with DoorFrame, DoorGold and its 42 kept parts; PriceSign, SunDisc, 10 tower Glyph); about 50,600 triangles | 82.8 x 46.5 x 15.6 (the poles rise 6 above the cornices; footprint and opening unchanged, 24 wide, 16 high): each tower on a 2-step footing, a mortar core faced with 19 courses of cut blocks (staggered joints, tone steps, chamfered front edges), the batter slope in courses with joint lines on its 3 faces, torus rolls on the slope edges and inner corners banded lapis / gold, today's trims as inlay bands (gold lotus petals on lapis, a lapis chequer on gold, gold rules), a cavetto cornice (roll, fillet, 3 cove slabs, fill wedges with reed grooves, top slab); the carving panels in sunk relief (a raised face cut 0.2 deep around today's figure parts, lighter cut walls with a bevel, a darker floor, a stone frame); a niche, a cedar flag pole with gold bands, clamps and cap and a red banner (gold trims, forked tail, lapis eye) on each tower; the lintel in courses with a soffit and its own cavetto cornice; the stone door frame (jambs of 4 blocks with banded rolls, the header with a lapis inlay and gold rosettes); the door: a dark-wood frame front and back (stiles, rails, centre stiles at the Seam) with gold studs every 1.5 and 2 gold ring handles, all under the Barrier; the winged sun disk (today's SunDisc, a gold ring, 2 uraei, 3 feather rows per wing in today's places, a gold top edge); the price sign's gold back with a raised frame and lapis corners; sand drifts outside the opening. **Glyphs: 47 / 47 identical** (37 door Glyph + 10 tower figure Glyph; with the 4 Border, the Seam and the SunDisc 53 / 53) on every copy (test, kit, Desert_4, template), part by part against the game copy recorded before the sync and against docs B12: name, parent, class, size and position in pivot space to 0.001 stud, rotation to 0.1 degree, colour (exact hex), material (Neon / SmoothPlastic), transparency; their collision flags are today's (door glyphs CanCollide false, tower figures true). The kit and test copies take the game copy's 0.4-thick belt bars (they had 0.3). SubZoneId, PrimaryPart Barrier and BarrierDecorIsChildOfBarrier kept; PriceGuiFront / Back ("31.25K Gold") moved onto the new PriceSign. Collision check (Desert_4 and test copies against today's colliding parts): 8,325 downward rays every 0.5, 0 off (max 0.001); 1,363 rays through the opening (Barrier excluded): 0 blocked; the Barrier blocks 384 / 384 |
| 03 | canyon barricade gate | `canyon_barricade` (names `Gate_Desert_3`; `match` = `Desert_3.Gate`) | 3 / 3 (test 1, kit 1, Desert_3 1); 2nd run 0 | 49 -> 50 (PillarL, PillarR, RockL, RockR, Beam, Ropes, SignBoard, HangingSign, Anchors, Rubble, Sand, 32 invisible `Collision` parts; Barrier with Planks, Crosses, Straps, Lock, Keyhole; PriceSign); about 27,400 triangles | 87.4 x 42.6 x 22.6 (rubble and sand outside the rock): Agent A's 4 facet pieces (`Blender_Exports/Props/facets/canyon_gate__*.json`, placed at the pivot with no offset; a box per rectangle face, a wedge pair per triangle, Agent A's colours: 12 strata, grooves, ledges, cracks, the tilted cap; the side rocks in 6 strata); the inner faces stay flat at x +-13, the opening 26 wide. Under today's invisible Barrier (they vanish when it opens): today's 5 planks as chamfered boards (chipped top corner, grain lines, a knot), 2 battens behind, today's 2 cross boards with grain and 2 nails at every plank, today's 6 chains as riveted iron straps (same places and turns) with 2 hasp plates, the lock plate with 4 rivets, a padlock with its shackle, today's gold keyhole as an escutcheon with a dark key slot. Outside the Barrier: the beam as a timber with grain and 4 riveted iron bands, today's 2 ropes as twisted ropes lashed round the beam, the sign board of 3 nailed planks behind today's PriceSign, a small hanging warning plank (red X) on 2 short ropes, today's 6 anchors as iron eye bolts on riveted plates, rubble, broken plank ends, small rocks and sand drifts outside the opening. SubZoneId, PrimaryPart Barrier (invisible, colliding, BarrierDecorIsChildOfBarrier) kept; PriceGuiFront / Back ("12.5K Gold") moved onto the new PriceSign. Collision: today's 32 colliding boxes as separate invisible parts (one union's convex hull bridged the notches between the rotated rock boxes: 65 rays off, so not used); check on the Desert_3 and test copies: 8,325 downward rays, 0 off; 1,363 rays through the opening: 0 blocked; the Barrier blocks 384 / 384 |
| 04 | sandstone wall gate | `sandstone_wall_gate` (names `Gate_Desert_2`; `match` = `Desert_2.Gate`) | 3 / 3 (test 1, kit 1, Desert_2 1); 2nd run 0 | 50 -> 15 (Stone, Wall, Inlay, Gold, Iron, SignBoard, Sand, Ember x2, `Collision`; Barrier with Planks, Straps, DoorGold; PriceSign); about 21,700 triangles | 63.6 x 27.5 x 13.6, opening unchanged (24 x 16): the piers on stepped bases (4 footing slabs, a chamfered plinth) in courses of 2 cut sandstone blocks over a mortar core, today's turquoise band as an inlay band (gold rules, gold diamonds), a small cavetto cap, today's two-tone pyramid tips with joint lines; the side walls in courses of cut blocks (frontal chamfers) with a chamfered cap and a roll; the lintel in courses with a soffit, today's turquoise band as an inlay band (lapis diamonds, gold dots, gold rules), a cavetto cornice, today's 5 merlons as capped blocks; the sign board of 3 nailed planks with iron corner plates behind today's PriceSign; the 2 lamps (iron wall plate, brace, arm and scroll, iron bowl with a brass rim, a Neon flame `Ember` in today's colour with today's FirePoint). Door (under the Barrier, exact): today's 8 planks with their colours as chamfered boards (0.06 gaps, grain, knots, iron studs), today's 2 bands as riveted iron straps with hinge knuckles, today's seam as a riveted astragal, today's 2 gold rings as ring handles on bosses, 2 battens and 2 braces behind; sand drifts outside the opening. SubZoneId, PrimaryPart Barrier, BarrierDecorIsChildOfBarrier kept; PriceGuiFront / Back ("5K Gold") moved onto the new PriceSign. Collision check (Desert_2 and test copies against today's colliding parts): 4,521 downward rays, 114 off by at most 0.30 (the union's hull on today's corner-wedge pyramid tips, 23.5 .. 27.5 high), none new; the opening: 0 rays blocked except today's pier bases at x +-11.5, y <= 2 (8, as today); the Barrier blocks 384 / 384 |

Desert gates final (01-04 done): `Sync.check()` 52 templates / 385 instances, all up to date (no duplicate, nothing
waiting); a full `Sync.run()` replaces 0. 04 (`Gate_Desert_2`) added on the owner's request on 2026-10-20.

### Desert nature: rocks, ruins and nature (owner, 2026-10-20): inventory before the remake (read from Studio)

Images: `docs/Desert_Images/03_Rocks_Ruins_Nature/` (01-04 + overview). Kit = `ServerStorage.MapAssets.Desert.<Kit>`;
test zone = `workspace._Staging.AssetPreview.Desert.<Kit>`. Every copy was found by name in Workspace and ServerStorage,
and box rocks of the same kit inside other models were found by part name (`Strata` / `Talus`). No script reads any
of these models (src / tools grep). None has a tag, a PrimaryPart or an attribute, except the Desert_1 `Landmark`
(`LandmarkName=RockArch`). Backups (kit + test + every game copy):
`BackUP_Files/old_props_2026-10-20_pre_desert_nature/` (`01_red_rock_stack_Mesa_Strata_A` 12, `01b_red_rock_strata_Hoodoo_x5_Desert_1_Landmark` 6,
`02_sandstone_blocks_Sandstone_Block` 6, `03_ribs_and_bull_skull_Ribcage_A_Skull_Animal` 25, `04_cacti_Cactus_A_B_C` 73).

| # | object | kit (parts, size) | game copies (count, scale) | collision | notes |
|---|---|---|---|---|---|
| 01 | red rock stack | `Mesa_Strata_A`, 18 parts: 14 `Strata` boxes (2 columns at x -9 / +9, about 21-23 x 4-11 x 13-21, turned -4..+4 degrees), 2 `Cap` boxes, 2 `Talus` wedges; 42.4 x 54.0 x 24.7 | Desert_3 `Decor.Formations` 4 (scale 0.62 / 1.00 / 1.20 / 1.25, turned +-90 / 80: the canyon walls of Desert_3); Desert_1 `Decor.Backdrop.Mesas` 4 (scale 1.5-2.3) and Desert_2 `Decor.Backdrop.Mesas` 2 (scale 1.4 / 2.0): the far backdrop | Formations copies: every part collides (as the kit); backdrop copies: CanCollide / CanQuery / CastShadow false (a backdrop variant, same shapes) | no invisible wall belongs to the rock: the zones' `Bounds` walls (Transparency 1, 4 thick, 110 high) are separate parts and stay as they are |
| 01b | box rocks of the same kit inside other models | Desert_3 `Decor.Formations.Hoodoo` x5: 5 `Strata` + 1 `Cap` each (stacked, 11-15 wide, 23-40 high, turned); Desert_1 `Decor.Landmark` (`LandmarkName=RockArch`): 17 `Strata` boxes (2 legs of 7 boxes at x +-31 and 3 long boxes across the top, up to 88 x 9 x 27, top at 69) + 4 `SandRock_L` / 2 `SandRock_M` mesh rocks | 5 + 1 | all collide | same strata palette as the kit: red C25337 / CA5639 / C95639 / BC5035 / C65438 / C75538, orange DF7D4E / E17E4F / E48050 / E78251, dark 953D2F / 9A3F31 / 963E30 / 8E3B2D. `Canyon_Cliff_A` (4 Toolbox mesh rocks, 21 copies in Desert_3 `Decor.Cliffs` + 4 backdrop) is not a box rock: not in 01 |
| 02 | sandstone blocks | `Sandstone_Block`, 2 parts: `Block` 6 x 3 x 4 (E2BE84, turned 6), `Block` 3.4 x 2.4 x 3 on top (D5B37C, turned -18); 6.4 x 5.4 x 4.6 | Desert_3 `Decor.Ruins` 4 (scale 1.0) | both collide | |
| 03 | ribs + bull skull | `Ribcage_A`, 11 parts: `Spine` 1 x 1 x 11 at y 4.8, 10 `Rib` 0.7 x 4.4-5.4 x 0.7 at +-31 degrees (F0E8D0 / E3DBC4); 7.2 x 5.4 x 11.0. `Skull_Animal`, 8 parts: `Cranium` 2.4 x 1.8 x 2.6, `Snout`, 2 `Horn` bars + 2 horn tips, 2 dark `Eye` plates (533E28); 8.6 x 3.8 x 4.7 | Ribcage_A: Desert_1 `Decor.Bones` 3, Desert_3 `Decor.Plants` 5 (scale 1.0-1.5); Skull_Animal: Desert_1 `Decor.Bones` 8, Desert_2 `Decor.Rocks` 3, Desert_3 `Decor.Plants` 2 (scale 0.9-1.4) | every part collides | |
| 04 | cacti | `Cactus_A` (tall, 7 parts: `Trunk` 2.2 x 11 x 2.2, 4 `Arm` boxes, `Top`, red `Flower`; 7.3 x 12.4 x 2.2); `Cactus_B` (barrel cluster, 9 parts: 3 `Barrel` pairs (a box and a copy turned 45), 2 red + 1 yellow `Flower`; 7.0 x 3.8 x 5.7); `Cactus_C` (prickly pear, 6 parts: 4 `Pad` plates tilted, 2 red `Flower`; 7.1 x 7.5 x 2.7); greens 4CA454 / 55B85E, flowers D64A3E / FFC93C | Cactus_A: Desert_1 `Decor.Cacti` 19, Desert_2 `Decor.Cacti` 7, Desert_3 `Decor.Plants` 5 = 31; Cactus_B: Desert_1 6, Desert_2 6, Desert_3 6 = 18; Cactus_C: Desert_1 9, Desert_2 9 = 18 (scales 0.80-1.29, all the kit's shape) | every part collides | |

Scope decisions (coordinator / main agent, 2026-10-20): 01 = every `Mesa_Strata_A` copy (10 placed + kit + test) AND the
5 Desert_3 `Hoodoo` stacks, from Agent A's facets; the colliding copies keep today's boxes as invisible colliders, the
backdrop copies stay non-colliding. The Desert_1 `Landmark` (RockArch) and `Canyon_Cliff_A` (mesh rocks) are out of scope.

#### Desert nature remake status

Builders in `DevTools.PropsDesertNature` (disk `tools/PropsDesertNature.luau`), recipe docs/prop_texture_guide.md
section B, today's colours, places, scales and turns (SyncMapProps keeps each copy's pivot and scale). Collision: the
visible unions never collide; invisible `Collision` parts are today's colliding parts (separate parts where one union's
convex hull would fill a gap). Screenshots: `docs/screenshots/desert_nature/`.

| # | object | MapProps id (rule) | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 04 | cacti (pilot) | `cactus_tall` (names `Cactus_A`), `cactus_barrel` (`Cactus_B`), `cactus_pear` (`Cactus_C`) | 33 / 33, 20 / 20, 20 / 20 (test 1 + kit 1 + 31 / 18 / 18 in Desert_1-3); 2nd run 0 | 7 -> 11 (4 unions Body, Spines, Flower, Sand + 7 invisible Collision); 9 -> 13; 6 -> 10; about 4,500 / 3,000 / 2,200 triangles | tall: today's trunk and 2 arms as ribbed octagonal segments (soft joints, elbows, rounded domes), 8 ribs, spine dots, a dark-to-light green gradient, today's red flower as petals round a yellow heart; barrel: today's 3 barrels in place as ribbed octagons with rounded feet and crowns, ribs over the crown, spine dots, today's red / yellow / red flowers; prickly pear: today's 4 pads (same places, sizes, tilts) as bevelled ovals in 2 greens with rows of spine dots on both faces, today's 2 red flowers and 2 small fruits; each on a sand mound with pebbles. Collision check (all 70 placed copies, rays every 0.5 against today's parts at each copy's scale): 24,990 downward rays, 0 off |
| 02 | sandstone blocks | `sandstone_blocks` (names `Sandstone_Block`) | 6 / 6 (test 1, kit 1, Desert_3 4); 2nd run 0 | 2 -> 4 (Body, Sand + 2 invisible Collision); about 1,400 triangles | today's 2 blocks (6 x 3 x 4 turned 6, 3.4 x 2.4 x 3 turned -18) in today's 2 tones as cut blocks: chamfered edges, 2 chipped top corners each, a darker weathered foot, weathering lines on the 4 faces, carved joint lines (vertical and all round) on the big block, a faint carved ankh and eye on its front; sand drifts and pebbles at the foot |
| 03 | ribs + bull skull | `ribcage` (names `Ribcage_A`), `bull_skull` (`Skull_Animal`) | 10 / 10 (test 1, kit 1, Desert_1 3, Desert_3 5), 15 / 15 (test 1, kit 1, Desert_1 8, Desert_2 3, Desert_3 2); 2nd run 0 | 11 -> 13 (Body, Sand + 11 invisible Collision), about 3,200 triangles; 8 -> 10 (Body, Sand + 8), about 1,300 triangles | rib cage: today's spine as 9 vertebrae (spinous and side processes, darker discs), today's 10 ribs (same tops, feet and lengths) as curved tapering bones bowed outwards, the bone gradient (F0E8D0 / E3DBC4), hairline cracks, the rib feet half buried in sand piles on a low mound; bull skull: today's cranium with deep dark eye sockets, a brow ridge and a poll ridge, hairline cracks, a nose bridge, the snout with 2 dark nostrils and a row of teeth, today's horns as curved tapering segments out at today's angle and up to today's tips, darker to the point, half buried in a sand mound. Collision check (blocks, ribs, skulls: all 28 placed copies at their scale): 65,436 downward rays, 0 off (1 grazing an edge) |
| 01 | red rock stack | `mesa_strata` (names `Mesa_Strata_A`; `variant` = "Backdrop" for the copies in `Decor.Backdrop.Mesas`) | 12 / 12 (test 1, kit 1, Desert_3 Formations 4, Desert_1 backdrop 4, Desert_2 backdrop 2); 2nd run 0 | 18 -> 23 (5 unions RockLowerL, RockUpperL, RockLowerR, RockUpperR, Scree + 18 invisible Collision = today's boxes); about 65,000 triangles (5 unions of 11,600-14,100) | Agent A's v2 facets (`Blender_Exports/Props/facets/mesa_strata__*.json`, converted into `DevTools.PropsDesertNatureData` / `tools/PropsDesertNatureData.luau`, placed at the pivot with no offset): 2 columns of irregular strata (dark red / red / orange, sloped facets, crumbling ledges, alcoves, runnels), the 2 cap rocks, the talus as scree with a sand pile, small rocks and fallen blocks. Every copy keeps its pivot, turn and scale (0.62-2.3). The backdrop copies take the variant `Backdrop` (Collision CanCollide / CanQuery false, rock unions no shadow / no query: as today); SyncMapProps `_Variants` gained CanCollide_ / CanQuery_ / CastShadow_<PartName>. Collision check (5 colliding copies at their scale): 7,105 downward rays against today's boxes, 0 off. The visible rock stays within about 1 stud of the boxes sideways (Agent A: 0.8, bites to 1.6) |
| 01b | Desert_3 hoodoos | rebuilt in place by `PropsDesertNature.rebuildHoodoos()` (no kit / test copy, not a MapProp) | 5 / 5 | 6 -> 8 per hoodoo (today's 5 Strata + Cap kept as invisible `Collision`, same size and place; RockLower + RockUpper unions); about 22,000-24,000 triangles each | Agent A's v2 hoodoo, variants A / B alternating, scaled to each hoodoo (width 1.00-1.30, height 1.01-1.72 of the drawn one) and turned 0 / 72 / 144 / 216 / 288; idempotent (a second call rebuilds the 2 unions from the same numbers). Collision unchanged by construction (the same parts, renamed and made invisible) |
| - | Desert_1 `Landmark` (RockArch) | out of scope (main agent, 2026-10-20) | - | - | logged; untouched |

### Desert monuments: monuments, statues and columns (owner, 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/.../04_Monuments_Statues_Columns/PROMPT_04_Monuments_Statues_Columns.txt`. Images:
`docs/Desert_Images/04_Monuments_Statues_Columns/`. Kit = `ServerStorage.MapAssets.Desert.<Kit>`; test zone =
`workspace._Staging.AssetPreview.Desert.<Kit>`; BA = boss-arena templates `ServerStorage.BossArenas.Desert.Decor` (synced
too). Every copy was found by name; all copies match the kit (differences under 0.1 stud, rounding of scaled copies),
except the Jungle_4 altar noted below. No copy has a script, ProximityPrompt, GUI, light, tag, attribute or PrimaryPart;
no script in src reads any of these names. Glow = Neon parts only. Backups (kit + test + every copy):
`BackUP_Files/old_props_2026-10-20_pre_desert_monuments/<nn>_<object>_<Kit>.rbxm` (7 files).

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | column | `Sandstone_Column`: 7 parts (2 Base blocks, Shaft cylinder 3.6 x 20, gold Band at y 6.4 and lapis Band at y 19.4, 2 Capital blocks); 5.6 x 25 x 5.6 | 4: Desert_3 `Decor.Ruins` 2 (scale 0.8 / 1.0) | all collide | - |
| 02 | fallen columns | `Sandstone_Column_Broken`: 6 parts (2 Base blocks, a standing Shaft 7 long + a tilted broken Shaft, 2 fallen Drums 7 / 3 long); 15.8 x 11.6 x 11.8 | 5: Desert_2 `Decor.Village` 1, Desert_3 `Decor.Ruins` 2 (scale 0.8 / 1.0) | all collide | - |
| 03 | obelisk | `Obelisk_A`: 15 parts (2 Base steps, 3 tapering Shaft blocks, 4 gold CornerWedge Tip pieces, 6 front Glyph bars, ONE of them Neon gold at y 14.9 = "the glowing yellow mark"); 6.5 x 32 x 6.5 | 5: Desert_3 `Decor.Ruins` 1, Desert_4 `Decor.Props` 2 (scale 0.8) | all collide | no script reads the mark; it is kept as an exact Neon part (same size and place, see the status table) |
| 04 | Anubis statue | `JackalStatue`: 34 parts (stepped Plinth, Seat + SeatBack, seated body: thighs, shins, feet, arms, forearms, gold arm bands / anklets, torso, gold belt, lapis kilt, gold / lapis collar, neck, head, snout, gold nose, gold crown, 2 ears, 2 lapis nemes lappets, 2 Neon cyan eyes); 8 x 20.2 x 11 | 16: Desert_3 `Decor.Ruins` 2, Desert_4 `Decor.Props` 6, Desert_4 `BossGate` 2 (scale 1.5, children of the boss gate model), BA 4 (scale 1.25 / 1.5) | all collide | BossService finds the boss gate's `Interact` part by a recursive search in `BossGate`: the new statue must never contain a part named `Interact` |
| 05 | golden guardian | `Sarcophagus_Small`: 12 parts (Base, Box, 2 gold Lid layers, 4 lapis Stripes, gold Head, lapis Nemes, 2 Neon cyan Eyes); 5 x 5.1 x 10 | 6: Desert_4 `Decor.Props` 4 (scale 1.2) | all collide | glow = the 2 Neon eyes |
| 06 | hieroglyph tablet | `Hieroglyph_Panel`: 22 parts (Panel 12 x 10 x 0.5, 4 gold Borders, 17 Glyph parts forming the 12 symbols: 3 Neon gold - a circle, the diamond, a circle); 12 x 10 x 0.7 | 47: Desert_3 `Decor.Ruins` 1, Desert_4 `Decor.Props` 24, BA 20 (scale 1.0-1.4) | none collide (CanCollide false on every part) | the 12 symbols kept part by part (record in the status table) |
| 07 | golden pyramid altar | `GoldPile_A`: 11 parts (3 stepped gold Heaps, 5 Coins, 2 Neon Gems cyan / light blue, a Goblet); 9.4 x 3.3 x 8.9 | 23: Desert_4 `Decor.Props` 8, Jungle_4 `Decor.Props` 2, BA 11 (scale 1.0-1.6) | all collide | one Jungle_4 copy was resized part by part to 0.8 (scale attribute 1.0): after the sync it gets ScaleTo(0.8), so its size is unchanged |

### Desert monuments remake status (Agent B, 2026-10-20)

Builders: `tools/PropsDesertMonuments.luau` (`DevTools.PropsDesertMonuments`, registered into PropsDesert's PropsBatch2
table); Agent A's facet pieces converted into `tools/PropsDesertMonumentsData.luau` (`DevTools.PropsDesertMonumentsData`).
Recipe: docs/prop_texture_guide.md B13. Collision: the visible unions never collide; invisible `Collision` parts are
the kit's colliding parts (same shape, size and place; `Monuments.SHAPES`). Collision checks: downward rays every
0.25-0.4 over every placed copy at its scale, the new colliders against today's parts rebuilt at the copy's pivot.
Screenshots: `docs/screenshots/desert_monuments/`.

| # | object | MapProps id (rule) | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 01 | column (pilot) | `desert_column` (names `Sandstone_Column`) | 4 / 4 (test 1, kit 1, Desert_3 Ruins 2); 2nd run 0 | 7 -> 11 (Stone, Inlay, Gold, Sand + 7 invisible Collision); about 12,000 triangles; 6.08 x 25 x 6.08 | a carved square base (footing, a die with sunk panels and lapis diamonds, a top slab), a torus plinth; a fluted 16-sided shaft in tone-stepped drums with joints (taper 3.6 -> 3.5); today's gold band (y 6.4) with 12 lapis diamonds and lapis band (y 19.4) with 12 gold squares, gold rules; Agent A's `column__capital` facet as the papyrus bell in place of today's Capital block; today's top slab chamfered with a turquoise / lapis / gold frieze; sand drifts. Collision: 972 rays, 0 off |
| 02 | fallen columns | `fallen_columns` (names `Sandstone_Column_Broken`) | 5 / 5 (test 1, kit 1, Desert_2 Village 1, Desert_3 Ruins 2); 2nd run 0 | 6 -> 8 (Stone, Sand + 6 invisible Collision); about 7,700 triangles; 15.8 x 11.7 x 11.8 | today's 6 pieces in place: the lower base split into 2 slabs with a joint and chipped corners, the upper base chipped, a torus roll; the standing shaft and the 2 fallen drums fluted with drum joints every 3.5; Agent A's `fallen_columns__drum_broken_end` facet on the shaft top, both ends of the tilted piece and one end of each drum (recoloured to each drum's colour; the other drum end shows a flat bed); 5 rubble chips, sand drifts against the base and under the drums. Collision: 7,056 rays, 0 off |
| 03 | obelisk | `obelisk` (names `Obelisk_A`) | 5 / 5 (test 1, kit 1, Desert_3 Ruins 1, Desert_4 Props 2 at 0.8); 2nd run 0 | 15 -> 24 (Stone, Gold, Glow + PointLight, 6 Glyph parts, 15 invisible Collision); 7.15 x 32 x 7.15 | a 3-step base (new low step 7.1 x 0.6 + today's 2) with block joints every 2.5; today's 3 shaft blocks each tapering (3.8 -> 3.6, 3.3 -> 3.1, 2.8 -> 2.6) with joint beds; a carved glyph column (a shaded band 1.0 wide between raised lips) on the front, cartouche frames on the other faces; a 0.3 gold collar; the pyramidion gold with its top 40 % Neon gold and a PointLight #FFD678 range 10 brightness 1. **The 6 glyphs are kept as separate `Glyph` parts, exact:** checked on all 4 placed copies (position / scale, size, rotation, colour, material): 6 / 6 each; the Neon gold mark at y 14.9 is still the only glowing glyph. Collision: 4,356 rays, 0 off |
| 04 | Anubis statue | `anubis_statue` (names `JackalStatue`) | 16 / 16 (test 1, kit 1, Desert_3 Ruins 2, Desert_4 Props 6, Desert_4 BossGate 2 at 1.5, BA 4 at 1.25 / 1.5); 2nd run 0 | 34 -> 39 (Stone, Body, Inlay, Gold, Glow + 34 invisible Collision); about 12,500 triangles; 8 x 20.3 x 11.1 | today's seated pose, sizes and places: a 2-step plinth (chamfers, corner notches, a front inscription panel recessed with a gold frame and carved signs); the throne (seat with sunk side panels and a gold / lapis band, the back with a cornice); thighs with knee caps, shins tapering 1.6 -> 1.3, sandals (sole #966840 0.2, gold strap, toe grooves), gold anklets and arm bands with a lapis stripe, hands with finger grooves, pectorals, the gold belt with a buckle panel, the lapis pleated kilt (6 fanning pleats, gold hem), the nemes lappets with 4 gold stripes; Agent A's `anubis__head` (Neon eyes at today's places) and `anubis__collar` facets. No part named `Interact`: the Desert_4 BossGate still finds its own `BossGate.Interact`. Collision: 26,411 rays, 0 off |
| 05 | golden guardian (sphinx) | `golden_guardian` (names `Sarcophagus_Small`) | 6 / 6 (test 1, kit 1, Desert_4 Props 4 at 1.2); 2nd run 0 | 12 -> 16 (Stone, Gold, Inlay, Glow + 12 invisible Collision); about 9,400 triangles; 5.1 x 5.55 x 10.1 (today 5.1 tall: +8.9 %) | a lying sphinx on today's base: the base carved (chamfer, a lapis band 0.3, 4 corner blocks); the body block with sunk panels and a gold rule; the gold lid with today's 4 lapis stripes at the same z and gold plates 0.08 proud between them; the upper lid (the back) with gold plates and lapis inlay strips; Agent A's `sphinx__head` (gold face, Neon turquoise eyes at today's places, striped nemes, cobra badge; the nemes top does not hide the face) and `sphinx__paws` facets (the head scaled 0.96 in height about its base, so the top is 5.55, not 5.62). Collision: 10,125 rays, 0 off |
| 06 | hieroglyph tablet | `hieroglyph_tablet` (names `Hieroglyph_Panel`) | 47 / 47 (test 1, kit 1, Desert_3 1, Desert_4 24, BA 20); 2nd run 0 | 22 -> 21 (Stone, Carve, Gold, Inlay + 17 Glyph parts); about 2,400 triangles; 13.1 x 10.65 x 1.3 | the slab thickened to 1.0 backwards (the front stays at z -0.5), front chamfer 0.15; the gold frame in today's border places, chamfered, 0.15 proud, an inner bevel strip, gold corner rosettes with turquoise studs; each glyph carved with a dark sunk outline; a dark sandstone stand (a sill 13 x 0.6 x 1.2 under the slab, 2 side pilasters with capitals and joints). Nothing collides (as today). **The 12 symbols (17 glyph parts) are kept as separate `Glyph` parts, exact:** checked on all 47 copies (scales 1.0 x31, 1.3 x14, 1.4 x2): 17 / 17 each (position / scale, size, shape, rotation, colour, material) |
| 07 | golden pyramid altar | `golden_altar` (names `GoldPile_A`) | 23 / 23 (test 1, kit 1, Desert_4 8, Jungle_4 2, BA 11); 2nd run 0 | 11 -> 15 (Stone, Gold, Inlay, Glow + PointLight, 11 invisible Collision); about 4,700 triangles; 9.36 x 3.64 x 8.9 | today's 3 tiers (sizes and turns kept) as sandstone steps plated with gold (a gold top plate 0.2, a gold edge band 0.3, chamfers, sunk panels); 2 front risers 0.4; 4 gold corner pyramids 0.6; on the top tier Agent A's `altar__gem` (x0.75) in a gold cup with 4 prongs and a cyan PointLight range 8; today's 2 gems as smaller cut gems at their places (turquoise, light blue); today's 5 coins embossed; the goblet as foot, stem, cup with a lapis band. The Jungle_4 copy at (6014, 0, 953) had its parts resized to 0.8 with Model scale 1: the rule's `bakedScale` (bottom Heap width / 8, used by run() for copies never synced) builds it at 0.8; checked with a synthetic raw copy (built at 0.8) and a forced run (the Jungle copy stays 0.8, then 0 replaced). Collision: 19,404 rays, 0 off |


### Desert props: props, furniture and treasures (owner, 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/.../05_Props_Furniture_Treasures/PROMPT_05_Props_Furniture_Treasures.txt`. Images:
`docs/Desert_Images/05_Props_Furniture_Treasures/`. Recipe: docs/prop_texture_guide.md B14. Kit =
`ServerStorage.MapAssets.Desert.<Kit>`; test = `workspace._Staging.AssetPreview.Desert.<Kit>`; BA =
`ServerStorage.BossArenas.Desert.Decor`. Every copy found by name; every copy's parts match the kit at its Model scale
(no baked-scale copy). No copy has a script, ProximityPrompt, Seat, ClickDetector, GUI, light, tag or attribute; no
script in src names these kits. Functional children: the Attachments `FirePoint` (Brazier_A `Embers`, 24 copies) and
`SmokePoint` (Lamp_Djinn `SpoutTip`, 3 copies). The braziers' flames are separate VFX parts (`Decor.VFX.Fire_Brazier`
in Desert_2 x2 / Desert_4 x8 / BA x10, `GateBraziers.Fire_Brazier` x2 in Desert_3) standing at today's FirePoint: the
new stand keeps the embers top and FirePoint at the same place. The throne is BA decor (no Seat; the boss spawns at
(4000, 0.5, -563), 74 studs in front of it). Sync rules (SyncMapProps, added before the remake): `terracotta_jar`
(`ClayJar_A`), `amphora` (`ClayJar_B`), `desert_rug` (`Carpet_A`), `golden_stand` (`Brazier_A`), `pharaoh_throne`
(`Throne_Gold`), `golden_lamp` (`Lamp_Djinn`). Backups (kit + test + every copy, with a manifest of pivots and
scales in the log): `BackUP_Files/old_props_2026-10-20_pre_desert_props/<propId>.rbxm` (6 files); the main agent's full
backup `FightYourDestiny_2026-10-20_014933_before_desert_props_treasures`.

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | terracotta jar | `ClayJar_A`: 3 cylinders (Body 2.4 x 2.6, Neck 1.4 x 0.7, Rim 1.9 x 0.35); 2.4 x 3.65 x 2.4 | 41: Desert_1 Camps 3, Desert_2 Village 14, Desert_2 Rocks 18 (scale 0.85-1.39, some sunk / on rocks), Desert_4 Props 4 (1.2) | all collide | - |
| 02 | amphora | `ClayJar_B`: 7 parts (Foot, Body, turquoise Band, Neck, Rim, 2 block Handles); 3.5 x 5.2 x 3.5 | 19: Desert_2 Village 7, Desert_4 Props 6 (1.2), BA 4 (1.2) | all collide | - |
| 03 | rug | `Carpet_A`: 6 blocks (Carpet 8 x 0.15 x 10, 2 Stripes, Diamond, 2 Torn pieces); 8.5 x 0.2 x 13 | 13: Desert_1 Camps 3, Desert_2 Village 7, BA 1 (1.3) | none collide (all CanQuery) | - |
| 04 | golden stand | `Brazier_A`: 6 blocks (stone Base, Stem, 3 gold Bowl pieces, Neon Embers); 5.9 x 5.5 x 5.9 | 24: Desert_2 Village 2, Desert_3 GateBraziers 2 (1.3), Desert_4 Props 8 (1.4 / 1.5), BA 10 (1.2-1.5) | all collide | Attachment `FirePoint` on Embers (kept in place: the Fire_Brazier VFX stand on it) |
| 05 | throne | `Throne_Gold`: 21 parts (2 dais Steps, Seat, Cushion, Back, lapis Inlay, Neon SunDisc, 8 CornerWedge Spikes, 2 Arms, 2 ArmTops, 2 Neon ArmGems); 13 x 20.6 x 11 | 3: BA 1 (1.5) | all collide | decoration only, no Seat |
| 06 | golden lamp | `Lamp_Djinn`: 12 blocks (Foot, Stem, 2 Body, lapis Band, Lid, Neon Knob gem, Spout, SpoutTip, 3 Handle); 12.8 x 6.7 x 4.2 | 3: BA 1 (1.5, floating at y 9) | all collide | Attachment `SmokePoint` on SpoutTip (kept at the tip) |

### Desert props remake status (Agent B, 2026-10-20)

Builders: `tools/PropsDesertTreasures.luau` (`DevTools.PropsDesertTreasures`; it uses the monuments helpers); Agent A's
facet pieces converted into `tools/PropsDesertTreasuresData.luau` (`DevTools.PropsDesertTreasuresData`). Recipe:
docs/prop_texture_guide.md B14. Collision: invisible `Collision` parts = the kit's colliding parts; checked with
downward rays every 0.25 over every placed copy at its scale against today's parts. Triangle cost: the props with many
copies (jar 41, stand 24, amphora 19) are built from lathe segments on Agent A's profiles (14 / 16-sided frustums)
instead of the facet pieces (a facet jar was about 20,000 triangles a copy, the lathe jar about 900); the facet pieces
are used for the throne (lion armrests, paw feet) and the lamp (body, gem), 1 game copy each. Screenshots:
`docs/screenshots/desert_props/`.

| # | object | MapProps id (rule) | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 03 | rug (pilot) | `desert_rug` (names `Carpet_A`) | 13 / 13 (test 1, kit 1, Desert_1 Camps 3, Desert_2 Village 7, BA 1 at 1.3); 2nd run 0 | 6 -> 3 (Cloth, Pattern, Fringe); about 1,900 triangles; 8.66 x 0.31 x 14.16 | today's carpet, 2 torn pieces and 2 cross stripes kept (sizes, places, colours); turquoise border bands on the long sides with a gold chequer and linen lines; gold zigzag diamonds on the stripes; today's gold diamond with a linen outline and a red centre diamond; faint weave rows; linen fringes at the front end and on the torn pieces; the front-left corner folded back (darker underside, fold roll, its fringe). Nothing collides (as today) |
| 01 | terracotta jar | `terracotta_jar` (names `ClayJar_A`) | 41 / 41 (test 1, kit 1, Desert_1 3, Desert_2 Village 14, Desert_2 Rocks 18, Desert_4 4); 2nd run 0 | 3 -> 4 (Clay + 3 invisible Collision); about 900 triangles; 2.6 x 4.0 x 2.53 | Agent A's lathe profile (14 sides, 3 clay tones): foot ring, round belly, shoulder, neck, rolled rim with 2 chips, a dark painted band and a cream line; the lid with a cream line and a knob (new, top 4.0: +9.6 %). Collision: 9,000 rays, 0 off |
| 02 | amphora | `amphora` (names `ClayJar_B`) | 19 / 19 (test 1, kit 1, Desert_2 7, Desert_4 6, BA 4); 2nd run 0 | 7 -> 8 (Clay + 7 invisible Collision); about 1,100 triangles; 3.8 x 5.25 x 3.5 | Agent A's lathe profile: ring foot, waist, belly, shoulder, neck, rolled rim with 2 chips, a dark mouth; a dark line and today's turquoise band, a dark / cream chequer band on the shoulder; 2 curved loop handles (out 0.45 so the width stays within +10 %). Collision: 5,600 rays, 0 off |
| 04 | golden stand | `golden_stand` (names `Brazier_A`) | 24 / 24 (test 1, kit 1, Desert_2 2, Desert_3 GateBraziers 2, Desert_4 8, BA 10); 2nd run 0 | 6 -> 9 (Stone, Gold, Embers + 6 invisible Collision); about 1,100 triangles; 5.94 x 5.5 x 5.94 | 2-step stone base with joints, carved octagonal stem with 2 engraved rings and a gold collar; the gold lotus bowl on Agent A's profile (8 petals in 2 golds, engraved ring, lapis line, 8 petal tips curling out to today's 8 star corners); today's Neon embers (#FF8C28, same place) as a round bed with a dark floor; `Embers.FirePoint` kept at (0, 5.6, 0): all 12 Fire_Brazier VFX parts in Desert_2-4 sit exactly on a FirePoint (0.00 away); PointLight #FF8C28 range 10 brightness 0.8 (the "little glow"). Collision: 10,192 rays, 0 off |
| 05 | throne | `pharaoh_throne` (names `Throne_Gold`) | 3 / 3 (test 1, kit 1, BA 1 at 1.5); 2nd run 0 | 21 -> 26 (Stone, Gold, Inlay, Cloth, Glow + 21 invisible Collision); about 10,800 triangles; 13 x 20.9 x 11 | dais with chamfers, a lapis band and gold diamonds; the seat on 4 carved legs with Agent A's lion paw feet, a carved apron with lapis / turquoise inlays; today's red cushion with gold piping and 4 tassels; Agent A's lion armrests with today's Neon cyan arm gems at (+-4.2, 7.35, -1.8); the high back with today's lapis panel in a gold frame (0.15 proud) and 3 gold star inlays, side rolls; today's Neon sun disc with a gold ring and 2 uraei; today's 2 spikes as gold pyramids. Decoration only (no Seat; the boss spawns 74 studs in front of it). Collision (test copy): 3,249 rays, 0 off. Its only game copy is in the BossArenas template (ServerStorage), so the game shot is the test copy |
| 06 | golden lamp | `golden_lamp` (names `Lamp_Djinn`) | 3 / 3 (test 1, kit 1, BA 1 at 1.5); 2nd run 0 | 12 -> 15 (Gold, Glow, SpoutTip + 12 invisible Collision); about 19,500 triangles; 13.07 x 6.65 x 4.3 | today's foot (turned 45) and stem with gold / lapis mouldings; Agent A's genie lamp body (lathe stretched along X, today's lapis band, engraved rings, curved spout to today's tip, loop handle, domed lid, 4-prong setting) and cut turquoise Neon gem at today's knob place; an invisible `SpoutTip` part at today's place and turn keeps `SmokePoint` (checked: (-7.1, 4.9, 0) in the test copy and the BA copy). Collision (test copy): 3,249 rays, 0 off. Only game copy in the BossArenas template |


### Jungle buildings: buildings and temples (owner, jungle PROMPT_01, 2026-10-20): inventory before the remake

Prompt: `REMAKE OBJECT/Jungle_Images_By_Category/.../01_Buildings_and_Temples/PROMPT_01_Buildings_and_Temples.txt`.
Images: `docs/Jungle_Images/01_Buildings_and_Temples/`. Recipe: docs/prop_texture_guide.md section C. Test =
`workspace._Staging.AssetPreview.Jungle.<Kit>` (added to SyncMapProps' search roots for this task); BA =
`ServerStorage.BossArenas.Jungle.Decor.Props`. Every copy found by name (the gate by its zone: `Jungle_4.Gate`); every
copy's parts match its kit at its Model scale. Checked in Studio: no copy has a script, ProximityPrompt, ClickDetector,
light, tag or attribute, except the gate (below); no script in src names these kits. BossService finds the Jungle_4
boss gate's own `BossGate.Interact` (the 2 stone heads in BossGate must never hold a part named `Interact`). Sync rules
(added before the remake): `face_temple_gate` (names `Gate_Jungle_4`, match `Gate` in `Jungle_4`), `stone_head`
(`Carved_Face_Block`), `jungle_ruin_building` (`Ruin_Wall_A`), `six_slot_wall` (`ArrowTrap_Wall`), `stilt_hut`
(`TribalHut_A`). Backups (kit + test + every copy, manifest in the log):
`BackUP_Files/old_props_2026-10-20_pre_jungle_buildings/<propId>.rbxm` (5 files); the main agent's full backup
`FightYourDestiny_2026-10-20_084830_before_jungle_buildings`.

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | stone face temple | `MapAssets.Gates.Gate_Jungle_4`: 52 parts (face, forehead, crown, brows, sockets + Neon glyph eyes + pupils, nose, upper lip, cheeks, ears + gold earrings, fangs, gold gem, 4 moss, 4 vines, PriceSign, the Barrier with its children); 65.8 x 52.7 x 16.9 | 3: test, kit, `Zones.Jungle.Jungle_4.Gate` | as today (face parts and Barrier collide) | THE JUNGLE_4 GATE: the mouth is the `Barrier` 24 x 16 x 3 at (0, 8, 0) (attribute `BarrierDecorIsChildOfBarrier`), its children (11 teeth, MouthDark, 2 lips, Neon glyph) vanish when the gate opens; the game copy has `SubZoneId = "Jungle_4"` and the PriceSign's PriceGuiFront / PriceGuiBack -> PriceLabel (GateController) |
| 02 | stone head | `MapAssets.Jungle.Carved_Face_Block`: 21 parts; 12.6 x 15.6 x 7.1 | 17: Jungle_3 Ruins 5, Jungle_4 Props 4, Jungle_4 BossGate 2 (children of the boss gate model), BA 4 (scale 1.6) | Head, Brow, Ears, Headdress, Crest collide | - |
| 03 | ruined stone building | `MapAssets.Jungle.Ruin_Wall_A`: 10 parts; 20.8 x 13.2 x 4.4 | 6: Jungle_3 Ruins 4 | Wall, Base, Cap, 2 Merlons collide | - |
| 04 | stone wall, six slots | `MapAssets.Jungle.ArrowTrap_Wall`: 15 parts (6 Holes, 2 Arrows + 1 ArrowTip, Neon Glyph lamp); 12.6 x 10.95 x 6.7 | 10: Jungle_3 Ruins 4, Jungle_4 Props 4 | Wall and 2 Frames collide | no script: the 6 holes, 2 arrows and the lamp are decoration, kept exactly in place |
| 05 | stilt hut | `MapAssets.Jungle.TribalHut_A`: 14 parts; 16 x 19.9 x 18.3 | 6: Jungle_2 Props 3, BA 1 | stilts, platform, body, bands, roof, ridge, ladder collide; the door is a non-colliding dark slab (no opening) | - |

### Jungle buildings remake status (Agent B, 2026-10-20)

Builders: `tools/PropsJungleBuildings.luau` (`DevTools.PropsJungleBuildings`; it uses the desert monuments helpers);
Agent A's jungle facet pieces converted into `tools/PropsJungleBuildingsData.luau` (`DevTools.PropsJungleBuildingsData`:
face brow, face nose + lips, temple brow, temple nose, moss drapes A / B / C, vine strand, hut thatch). Recipe:
docs/prop_texture_guide.md section C. Collision: invisible `Collision` parts = the kit's colliding parts (the gate's
Barrier and PriceSign stay themselves); checked with downward rays over every placed copy at its scale against today's
parts. Moss (coordinator's rule): low mounds of 2-3 stacked rounded layers lying on caps and ledges, running together,
and Agent A's drapes hanging off the edges, where today's flat green slabs were, at about their size; no upright plates.
Screenshots: `docs/screenshots/jungle_buildings/`. Sync: `Sync.run` twice per object, the second run 0; `Sync.check()`
all up to date.

| # | object | MapProps id | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 03 | ruined stone building (pilot) | `jungle_ruin_building` | 6 / 6 (test, kit, Jungle_3 Ruins 4) | 10 -> 8 (Stone, Trim, Moss + 5 Collision); about 20,400 triangles; 21.2 x 13.64 x 4.79 | stone faces of cut blocks in running bond with joints, cracks and greener blocks; 2 framed dark slots, a glyph plaque; footing with plinth slabs; 5 chipped capstones with a drip course, 2 merlons; moss mounds on the cap and a merlon, 4 of Agent A's drapes, 2 vine groups. Collision: 28,125 rays, 0 off |
| 04 | stone wall, six slots | `six_slot_wall` | 10 / 10 (test, kit, Jungle_3 Ruins 4, Jungle_4 Props 4) | 15 -> 16 (Stone, Trim, Moss, 6 Hole, 2 Arrow, ArrowTip, Glyph + 3 Collision); about 14,000 triangles; 12.6 x 11.12 x 6.8 | today's 6 holes, 2 arrows + tip and the Neon lamp glyph kept exactly (names, sizes, places, turns, colours; checked on all 9 placed copies) in bevelled stone frames; the arrows get fletchings; the lamp sits in a stone bracket with a PointLight #78FFBE range 10; capstones, plinth, carved panel frame; moss mounds, 3 drapes, vines. Collision: 27,225 rays, 0 off |
| 01 | stone face temple (the Jungle_4 gate) | `face_temple_gate` | 3 / 3 (test, kit `Gates.Gate_Jungle_4`, `Zones.Jungle.Jungle_4.Gate`) | 52 -> 45 (Stone, Carving, Gold, Moss, Glow, Socket x2, GlyphEye x2, Pupil x2, PriceSign, Barrier (+ MouthDark, Glyph, 2 Lip, 11 Tooth) + 18 Collision); about 36,000 triangles (the Moss union is at Roblox's 20,000 cap); 66.3 x 53.66 x 16.8 | face and cheeks of large cut blocks (joints, cracks), forehead cornice of 6 stones with a drip moulding, stone-block crown with today's gold gem in a gold rim; Agent A's temple brows and nose; bevelled socket rims round today's sockets, Neon glyph eyes and pupils (kept exactly); upper lip with rolls; jointed cheek plinths; spiral rings on today's ears, chamfered gold earrings; tapered fangs; moss mounds on the forehead ledge, a CrownSide, the crown, the CrownTop, both brows and both cheek ledges, 8 large drapes (scale 2-3) over the forehead, crown and cheek / jaw corners; 10 vine strands at today's 4 vine places. THE GATE kept: `Barrier` 24 x 16 x 3 at (0, 8, 0), PrimaryPart, colliding, attribute `BarrierDecorIsChildOfBarrier`, its only children MouthDark, Neon Glyph, 2 Lips (rolls), 11 Teeth (chamfered); the game copy keeps `SubZoneId = "Jungle_4"`, PriceGuiFront / PriceGuiBack -> PriceLabel moved onto today's exact PriceSign (shows "312.5K Gold"). Collision: 9,248 rays, 0 off. Play check (gate closed / open) left to the main agent |
| 02 | stone head | `stone_head` | 17 / 17 (test, kit, Jungle_3 Ruins 5, Jungle_4 Props 4, Jungle_4 BossGate 2, BA 4 at 1.6) | 21 -> 15 (Stone, Carving, Gold, Moss, Socket x2, GlyphEye x2, Mouth, Tooth x4 + 6 Collision); about 20,400 triangles; 12.8 x 15.6 x 6.95 | cut stone blocks on all 4 sides; Agent A's brow and nose with lips; bevelled socket rims; today's sockets, Neon glyph eyes, mouth and 4 teeth kept exactly; ears with spiral rings, chamfered gold earrings; headdress with a carved row of diamonds, stepped crest, today's gold gem in a gold rim; moss mounds on the headdress and the brow, drapes over the headdress front and on the cheek (today's patch places), 2 vines. No part named `Interact` (BossGate.Interact still resolves to the boss gate's own part). Collision: 9,408 rays, 0 off |
| 05 | stilt hut | `stilt_hut` | 6 / 6 (test, kit, Jungle_2 Props 3, BA 1) | 14 -> 20 (Walls, Wood, Deck, Roof, Glow, Door, DoorMask + 12 Collision); about 14,900 triangles; 16 x 20.66 x 19.06 | 8-sided log stilts with rope ties and 4 cross braces; plank deck on rim beams with a low railing (open at the door); plank walls with corner posts; today's 2 bands as lashed beams; today's door and red mask kept exactly (not colliding, touchable as today) in a wooden frame with a rolled hide; Agent A's thatch over today's 2 roof wedges (kept as the core), lashed ridge; ladder with 2 rails and 6 rungs; 2 gourds, a hanging lantern (Neon + PointLight #FFB84A range 8), vines. Collision: 6,724 rays, 0 off |

### Jungle gates and entrances (owner, jungle PROMPT_02, 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/Jungle_Images_By_Category/.../02_Gates_and_Entrances/PROMPT_02_Gates_and_Entrances.txt`.
Images: `docs/Jungle_Images/02_Gates_and_Entrances/`. Recipe: docs/prop_texture_guide.md C3. Test =
`workspace._Staging.AssetPreview.Jungle.<Kit>`; BA = `ServerStorage.BossArenas.Jungle.Decor.Props`. Checked in Studio and
in src: no script, ProximityPrompt (the gates' `GatePrompt` is made at run time by ZoneService in the Barrier),
tag, Humanoid or teleport in any of the five. The existing SyncMapProps rules `entry_arch`, `gate_palisade`,
`gate_barricade` (and `gate_mine`) only catch the PLAINS gates (`EntryArch_Plains` / `Gate_Plains_*`, zones `Plains_*`):
not touched; 5 new rules added. Backups (kit + test + every copy, manifest in the log):
`BackUP_Files/old_props_2026-10-20_pre_jungle_gates/<propId>.rbxm` (5 files); the main agent's full backup
`..._before_jungle_gates`.

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | palisade gate with guards | `MapAssets.Gates.Gate_Jungle_2`: 70 parts (10 logs + LogTips, 4 bands, lintel + 2 rope wraps, sign + PriceSign, horned skull, 2 torches, 2 totem guards, the Barrier + 11 children); 58.4 x 27.8 x 10.5 | 3: test, kit, `Zones.Jungle.Jungle_2.Gate` | logs, tips, bands, lintel, SignBack, PriceSign, torch poles, the guards' heads and wings, the Barrier | THE JUNGLE_2 GATE: `Barrier` 24 x 16 x 1.4 (PrimaryPart in the game copy, `BarrierDecorIsChildOfBarrier`), its children (5 Seams, 2 CrossBands, Mask, 2 MaskEyes, MaskMouth) vanish when the gate opens; `SubZoneId = "Jungle_2"`, PriceSign GUIs; the 2 Embers hold `FirePoint` attachments. The "2 guard NPCs" are 2 totem stacks of 9 parts each (3 TotemHead cubes, 4 Eyes, a Beak, a Wing) at x +-16.2, z -4.6, not NPCs (no Humanoid) |
| 02 | stone vine barricade gate | `MapAssets.Gates.Gate_Jungle_3`: 54 parts; 56.5 x 29.4 x 9.6 | 3: test, kit, `Zones.Jungle.Jungle_3.Gate` | piers, bases, caps, 2 side roots, lintel, keystone, 2 upper courses, top root, SignBack, PriceSign, the Barrier | THE JUNGLE_3 GATE: `Barrier` 24 x 16 x 3 (children: 7 Roots, 2 RootCross, 4 Vines, 8 Leaves, 3 Flowers); `SubZoneId = "Jungle_3"`, PriceSign GUIs; 2 Neon glyphs |
| 03 | totem arch | `MapAssets.Gates.EntryArch_Jungle`: 54 parts; 46.1 x 30.4 x 7.5 | 3: test, kit, `Zones.Jungle.Jungle_1.EntryArch` | bases, 8 heads, 2 wings, beam, SignBack, NameSign | not a gate: `ZoneId = "Jungle"` on the model; NameSign with NameGuiFront / NameGuiBack -> NameLabel ("Jungle"); the 2 Embers hold `FirePoint` attachments; passage 26.4 x 19.1 |
| 04 | root arch | `MapAssets.Jungle.Root_Arch_A`: 19 parts; 45 x 26.9 x 8.6 | 6: Jungle_1 Props 2, Jungle_3 Ruins 2 | 9 roots, 2 root feet, 2 side roots | - (passage 25.5 wide at the ground, 19.3 tall) |
| 05 | rock cave entrance | `MapAssets.Jungle.Jaguar_Den_Rocks`: 9 parts (a Toolbox asset: 3 Rock, Roof and Moss MeshParts, Hull collision); 53 x 22.6 x 33.4 | 4: Jungle_3 Ruins 1, BA 1 (scale 0.74) | the 3 rocks and the roof (MeshParts) | - (the opening 14 x 11 = the dark Shadow part, front at z 2.5, not colliding) |

### Jungle gates remake status (Agent B, 2026-10-20)

Builders: `tools/PropsJungleGates.luau` (`DevTools.PropsJungleGates`; it uses the jungle buildings helpers); Agent A's
gate facet pieces converted into `tools/PropsJungleGatesData.luau` (`DevTools.PropsJungleGatesData`: root arch sides
and crown, cave rocks and slab, small and horned skulls, totem wings). Collision: invisible `Collision` parts = the
kit's colliding parts, checked part by part on every copy (place and size at the copy's scale); the cave's colliders
are today's own MeshParts (cloned from the kit, checked by mesh, size, place and fidelity). The gates' Barrier and its
children, PriceSign, NameSign, Embers + FirePoints and the palisade's 2 totem guards are exact parts. Screenshots:
`docs/screenshots/jungle_gates/`. Sync: `Sync.run` twice per object, the second run 0.

| # | object | MapProps id | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 04 | root arch (pilot) | `root_arch` | 6 / 6 (test, kit, Jungle_1 Props 2, Jungle_3 Ruins 2) | 19 -> 16 (Roots, Moss, Flora + 13 Collision); about 26,300 triangles; 46.4 x 27.1 x 8.85 | a main root along today's curve (radius 3.0 -> 2.2, 8-sided, bark tones as lines) with 2 thinner roots twisting round it, knots, 3 broken stubs with cut ends; 4 roots per foot sinking into the soil, today's 2 side roots tapered; moss mounds on the crown and shoulders, fuller leaf clusters on the crown, 2 of Agent A's drapes; part vines at today's 3 vines; mushrooms (#C44632, white dots) and flowers at the feet. Agent A's root facets were measured at about 39,000 triangles for the roots alone (6 copies): the part roots were kept (approved). Colliders: 78 / 78 exact |
| 01 | palisade gate with 2 totem guards | `jungle_palisade_gate` | 3 / 3 (test, kit `Gates.Gate_Jungle_2`, `Zones.Jungle.Jungle_2.Gate`) | 70 -> 62 (Logs, Wood, Iron, Rope, Bone, Barrier (+ DoorPlanks, DoorIron, MaskCarving, Mask, 2 MaskEye, MaskMouth), PriceSign, 2 Ember, the 18 guard parts + 28 Collision); about 17,800 triangles; 58.6 x 29.8 x 10.8 | octagonal sharpened logs (today's sizes and two-tone colours) with bark strips and knots, rope turns and iron straps with rivets on today's bands; octagonal lintel log with cut ends and rope lashings; torches with rope-wrapped poles, iron bowls and cages (Embers + FirePoints kept); sign planks and a carved frame round the PriceSign; Agent A's horned skull with crossed bones. THE DOOR (Barrier children only): plank leaves front and back, Z-braces, strap hinges, studs, today's teal Mask, gold MaskEyes and red MaskMouth with a raised rim, brows and teeth. THE 2 GUARDS: all 18 parts identical to today (name, class, size, place to 0.01, colour, material, flags, surfaces) on all 3 copies, not merged. Game copy: `SubZoneId = "Jungle_2"`, PrimaryPart Barrier, PriceGuis on the new PriceSign ("50K Gold"). Colliders: 84 / 84 exact |
| 02 | stone vine barricade | `jungle_barricade_gate` | 3 / 3 (test, kit `Gates.Gate_Jungle_3`, `Zones.Jungle.Jungle_3.Gate`) | 54 -> 25 (Stone, Trim, Wood, Moss, Barrier (+ BarricadeLogs, BarricadeGreen, BarricadeGems), PriceSign, 2 Glyph + 14 Collision); about 47,100 triangles (the Moss union at the 20,000 cap; 1 game copy); 56.5 x 29.5 x 9.8 | piers of cut stone courses on all 4 faces with jointed chamfered bases and caps, today's dark plates as carved panels, a carved diamond frame round today's Neon glyphs (kept); lintel of cut stone, chamfered keystone and jointed upper courses; octagonal top root with cut ends, knots and vine wraps; moss mounds and 4 of Agent A's drapes at today's moss places; vines on the piers; today's side roots as octagonal braced beams with rope ties; sign planks and a carved frame. THE BARRICADE (Barrier children only): today's 7 logs and 2 cross logs as octagonal logs with sawn light ends, rope lashings at every crossing, 4 of Agent A's vine strands, leaf clusters at today's 8 leaves, today's 3 flowers as 5-petal flowers, 3 small Neon gems. Game copy: `SubZoneId = "Jungle_3"`, PrimaryPart Barrier, PriceGuis ("125K Gold"). Colliders: 42 / 42 exact |
| 03 | totem arch | `jungle_totem_arch` | 3 / 3 (test, kit `Gates.EntryArch_Jungle`, `Zones.Jungle.Jungle_1.EntryArch`) | 54 -> 45 (Totems, Carving, Wood, Gold, Moss, 16 Eye, 4 Mouth, 2 Beak, 2 Ember, NameSign, Mask + 14 Collision); about 24,600 triangles; 49.75 x 31.1 x 7.5 | each of today's 8 heads (sizes and colours kept) carved: brow ridge, eye sockets round today's eyes (kept), nose (today's beaks kept), today's mouths (kept) with teeth, cheek plates, ear blocks, darker joint rings; Agent A's feathered wings (7.2 long, colliders kept at today's wing places); headdress plumes and a gold band; stepped plinths; the beam as 3 jointed timbers with pegs, vine turns at today's wraps, Agent A's vine strands, leaf clusters and today's 2 flowers; carved bowls with today's Embers + FirePoints; sign planks and a carved frame round the NameSign (kept: "Jungle"); today's gold Mask in a carved frame with gold studs. Game copy keeps `ZoneId = "Jungle"` and its name `EntryArch`. Passage 26.4 x 19.1 kept. Colliders: 42 / 42 exact |
| 05 | rock cave entrance | `rock_cave` | 4 / 4 (test, kit, Jungle_3 Ruins 1, BA 1 at 0.74) | 9 -> 10 (Rocks, Slab, Moss, Drapes, Bones, Rock (today's back rock), Shadow + 3 Collision MeshParts); about 38,800 triangles; 53 x 21.2 x 32.5 | Agent A's layered faceted side rocks with cracks and the layered top slab with a moss cap and grass tufts; a moss lip that follows the slab's real front outline (measured with rays on the slab) between x -11.5 and 11.5 (it stops before the front corners): 3 layered moss mats with grey rock between them (each a broad dark #589642 base patch 0.3-0.5 tall, a lighter #60C448 layer on 60-70 % of it and 2 small #78D246 highlights; each layer a run of overlapping low domes merged into one flat patch with a soft outline), lying on the bevel or rolling over the steep edge, <= 0.4 out of the rock; 4 of Agent A's drapes (0.65-1.3) and 2 thin part vines down the front, grass tufts on the crest (coordinator fixes); today's back rock and dark Shadow (the 14 x 11 opening) kept; a worn threshold stone; 3 bones with knuckle ends and Agent A's small skull at today's places. Colliders: today's 4 colliding MeshParts identical (mesh, size, place, Hull fidelity) on all 4 copies, the BA copy at its 0.74 scale |

### Jungle ruins (owner, jungle PROMPT_03 "Ruins and stonework", 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/Jungle_Images_By_Category/.../03_Ruins_and_Stonework/PROMPT_03_Ruins_and_Stonework.txt`.
Images: `docs/Jungle_Images/03_Ruins_and_Stonework/`. Recipe: docs/prop_texture_guide.md C4. Test =
`workspace._Staging.AssetPreview.Jungle.<Kit>`; BA = `ServerStorage.BossArenas.Jungle.Decor.FloorDecor`. Checked in
Studio and in src: no script, ProximityPrompt, tag, attribute (other than MapPropId), Humanoid or Touched handler in
any of the five (the only Touched handlers in the game are PortalController and ZoneService's HubReturn), so the
glowing pad has no step behaviour to keep: it is decoration. Copies whose parts were resized (not model-scaled) are
caught by the new `bakedFrom` helper in SyncMapProps (the copy's scale = the width of its named part / the kit's).
5 new rules. Backups (kit + test + every copy): `BackUP_Files/old_props_2026-10-20_pre_jungle_ruins/<propId>.rbxm`
(5 files).

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | stepped ruin block | `MapAssets.Jungle.Ruin_Wall_Broken`: 9 parts (Base, 3 stepped Walls 10 / 6.5 / 3.2 tall, 2 Rubble, 3 Moss); 20.8 x 10.4 x 8.7 | 8: test, kit, Jungle_3 Ruins 6 (1 baked at 0.8) | Base, 3 Walls, 2 Rubble | - |
| 02 | stone stairs | `MapAssets.Jungle.Ruin_Stairs`: 10 parts (5 Steps, 2 Cheeks, Rubble, 2 Moss); 20.7 x 7.7 x 15 | 3: test, kit, Jungle_3 Ruins 1 | 5 Steps, 2 Cheeks, Rubble | WALKABLE: treads at y 1.5 / 3 / 4.5 / 6 / 7.5, fronts z -7.5 / -4.5 / -1.5 / 1.5 / 4.5 (3 deep, risers 1.5); widths x -7..7 (steps 1-3), -7..5, -7..2; cheeks x -9..-7 (top 4.6) and x 7..9 (z -7.5..0.5, top 2.6) |
| 03 | broken pillar and blocks | `MapAssets.Jungle.Ruin_Pillar_Broken`: 6 parts (Base, Stump, Break wedge, fallen Drum, Chunk, Moss); 13.8 x 10.7 x 13 | 14: test, kit, Jungle_3 Ruins 6 (2 baked at 0.8), Jungle_4 Props 6 (all baked at 0.8) | Base, Stump, Break, Drum, Chunk | - |
| 04 | mossy slabs | `MapAssets.Jungle.SteppingStone_A`: 3 parts (Stone 6.4 x 1.6 x 6, the Skirt = a Toolbox MeshPart, Moss); 10.55 x 2.1 x 10.58 | 6: test, kit, Jungle_2 Crossings 4 (river stepping stones) | Stone, Skirt (MeshPart) | WALKABLE: the top at the pivot + 1.6 |
| 05 | glowing floor pad | `MapAssets.Jungle.Glyph_Tile`: 6 parts (Tile 8 x 0.3 x 8, 5 Neon #78FFBE Glyph parts: a frame of 4 bars and a diamond); 8 x 0.36 x 8 | 37: test, kit, Jungle_3 Ruins 7, Jungle_4 FloorDecor 19, BA 9 (1 baked at 1.6) | none (nothing collides, is queried, touched or casts a shadow) | decoration only (see above) |

### Jungle ruins remake status (Agent B, 2026-10-20)

Builders: `tools/PropsJungleRuins.luau` (`DevTools.PropsJungleRuins`; it uses the jungle gates and buildings helpers);
Agent A's ruins facet pieces converted into `tools/PropsJungleRuinsData.luau` (`DevTools.PropsJungleRuinsData`: pillar
break, upper and lower slab, 3 rubble stones, plant tuft, fern). The converter now splits a concave quad on the
diagonal that agrees with the face normal and drops slivers: one slab_top triangle had been flipped, which pushed a
0.4 sliver 0.4 above the walk top (found by the slab top raycast). Collision: invisible `Collision` parts = the kit's
colliding parts, checked part by part on every copy (place and size at the copy's scale, the baked copies included);
the slabs' Skirt collider is today's MeshPart (cloned from the kit). Walkability: a raycast grid against the colliders
of every placed copy, before and after (slabs 11,045 rays, stairs 14,450 rays): 0 different, worst 0.0004. The
stairs' visible treads (raycast on the visible stone): the top exactly at each tread top (0.0000 above), moss at
most 0.125 above. Screenshots (test + game, before + after): `docs/screenshots/jungle_ruins/`. Sync: `Sync.run` twice
per object, the second run 0.

| # | object | MapProps id | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 01 | stepped ruin block (pilot) | `jungle_ruin_block` | 8 / 8 | 9 -> 9 (Moss, Stone, Trim + 6 Collision); about 11,700 triangles; 22.6 x 11.0 x 8.7 | today's 3 stepped blocks as cut stone courses in running bond (a tone per block, a few greener blocks, chipped top corners, joints over a dark core, today's colours: the middle block lighter); today's base as 4 jointed chamfered plinth slabs; today's 2 rubble blocks as Agent A's chipped rubble on their exact places, a small rubble stone and 2 pebbles; soft layered moss mats (the cave recipe) on the 3 tops, Agent A's drape over the tall block's front edge and 2 thin vines; 2 tufts in the plinth joints and a fern. Colliders: 48 / 48 exact |
| 03 | broken pillar and blocks | `jungle_broken_pillar` | 14 / 14 | 6 -> 8 (Moss, Stone, Trim + 5 Collision); about 7,950 triangles; 15.3 x 11.4 x 12.9 | the stump as a shaft with 0.3-chamfered corners in 2 drums with a joint, 2 carved bands (a proud band between 2 dark grooves, carved notches on its 4 faces); Agent A's jagged octagonal break on top (its crack runs down the front; today's wedge kept as a hidden collider); a 2-tier chamfered plinth with 2 chipped corners; the fallen drum as an 8-sided drum (fluted tones) with a chamfered end, a carved band and a broken end (a lighter jagged stub); today's chunk as Agent A's rubble (scaled to today's box); a soft mat on the low side of the break with 2 part-built drapes, a mat and a drape on the plinth, a tuft and a fern. Agent A's facet drapes were measured at 2,500-3,800 triangles each and replaced here by the part-built drape (about 300) because of the 14 copies (16,600 -> 7,950). Colliders: 70 / 70 exact |
| 04 | mossy slabs | `mossy_slabs` | 6 / 6 | 3 -> 3 (Stone + 2 Collision: today's Stone box and today's Skirt MeshPart); about 5,450 triangles; 10.55 x 2.1 x 10.58 (the visible stone 9.4 x 9.5) | Agent A's upper slab (irregular chipped outline, 2 cracks, the FLAT top exactly at 1.6 with a 0.15 bevel, a soft 2-layer moss patch at most 0.16 proud) over Agent A's lower slab (today's Skirt); a small moss mat, 2 tufts and a small fern on the lower ledge, all under the walk top. Walk surface identical (above) |
| 05 | glowing floor pad | `glyph_floor_pad` | 37 / 37 | 6 -> 6 (Stone + today's 5 Glyph parts); about 990 triangles; 8 x 0.64 x 8.07 | a bevelled stone tile with a chipped corner and 2 hairline cracks; a darker groove under the glowing frame; a raised lighter setting (with a dark rim) round the diamond; soft moss in 2 corners and a tuft. Today's 5 Neon #78FFBE Glyph parts kept (names, sizes, places; the diamond 0.05 higher on its setting): 185 / 185 on the 37 copies. Nothing collides, is queried or touched; no shadows (as today). No PointLights (one template for all 37 copies) |
| 02 | stone stairs | `jungle_ruin_stairs` | 3 / 3 | 10 -> 11 (Moss, Stone, Trim + 8 Collision); about 8,750 triangles; 21.7 x 7.9 x 15.2 | each step a column of cut stone courses 1.5 tall (running bond, a tone per block, today's step colours, the lower courses darker) over a dark core; the top course is the tread, its top exactly at today's tread top, the nose (front-top edge) bevelled 0.15, 2 worn notches 0.4 x 0.15 per step; the 2 cheeks as coursed stone with chipped top corners; today's rubble as Agent A's rubble (scaled to today's box) and 2 loose stones; thin layered moss (at most 0.13) on the 3rd tread's left half and the 1st tread's left corner creeping over the nose and down the riser; a soft mat and 2 part-built drapes on the left cheek (today's moss); 3 tufts. Colliders: 24 / 24 exact. To check in Play: walking up and down |

Totals: 68 copies replaced (8 + 14 + 6 + 37 + 3); in the place about 300,000 triangles for these five (block 93k,
pillar 111k, slabs 33k, pads 36k, stairs 26k), of which the placed game copies (Jungle_2/3/4) are about 220,000.

### Jungle totems (owner, jungle PROMPT_04 "Totems, shrines and water", 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/Jungle_Images_By_Category/.../04_Totems_Shrines_Water/PROMPT_04_Totems_Shrines_Water.txt`.
Images: `docs/Jungle_Images/04_Totems_Shrines_Water/`. Recipe: docs/prop_texture_guide.md C5. Test =
`workspace._Staging.AssetPreview.Jungle.<Kit>`; BA = `ServerStorage.BossArenas.Jungle.Decor.Props`. Every model named
like a kit was searched in the whole place (Plains, hub, BossArenas included): the copies are only the ones below.
Checked in Studio and in src: no script, ProximityPrompt, ClickDetector, tag, attribute, Humanoid, Light or touch handler
in any of the four, and nothing in src names them (no heal / swim logic for props). The pool's water is a plain
non-colliding part (no terrain water in or under any copy): players walk through it. The Jungle_4 BossGate's
`Interact` prompt near the shrine belongs to the BossGate (not touched). The shrine is NOT the existing rule
`golden_altar` (the desert GoldPile_A, whose Jungle_4 copy stands next to it): 4 new rules with new propIds, names
that do not overlap (golden_altar still 23 / 23 after the work). Backups (kit + test + every copy):
`BackUP_Files/old_props_2026-10-20_pre_jungle_totems/<propId>.rbxm` (4 files); the main agent's full backup
`..._before_jungle_totems`.

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | tall totem pole | `MapAssets.Jungle.Totem_B`: 26 parts (Base, 5 Heads, eyes, mouths, 2 gold Ears, 2 Tusks, 3 Feathers); 7 x 21.6 x 5.0 | 6: test, kit, Jungle_1 Props 2, Jungle_2 Props 1, BA 1 | Base, 5 Heads, 2 Ears | - (heads bottom to top: blue 2.9, tan 6.3, red 9.7, brown 13.1, yellow 16.5) |
| 02 | totem figure | `MapAssets.Jungle.Totem_A`: 18 parts (Base, 3 Heads, Beak, eyes, mouth, 2 Wings, Brow, Crown, 2 Horns); 14.1 x 16.7 x 7.1 | 6: test, kit, Jungle_1 Props 3, Jungle_2 Props 1 | Base, 3 Heads, Brow, Crown, 2 Wings | - |
| 03 | golden shrine | `MapAssets.Jungle.Golden_Altar`: 13 parts (2 Steps, Table, GoldTop, Idol + IdolHead, 2 Bowls, 2 Neon Gems, 2 Trims, Neon Glyph); 12 x 9.05 x 8 | 3: test, kit, Jungle_4 Props 1 (part-resized x1.6) | 2 Steps, Table, GoldTop | - (no prompt or script) |
| 04 | water pool with gold corners | `MapAssets.Jungle.Temple_Pool`: 14 parts (4 Rims, 4 Posts, 4 PostCaps, Basin, Water); 24.6 x 3.1 x 24.6 | 5: test, kit, Jungle_3 Ruins 1, Jungle_4 Props 2 (both part-resized x1.2) | 4 Rims, 4 Posts | Water 20 x 0.5 x 20 #30C4BE T 0.25 (top y 0.8), Basin #1E8C96: neither collides, walk-through |

### Jungle totems remake status (Agent B, 2026-10-20)

Builders: `tools/PropsJungleTotems.luau` (`DevTools.PropsJungleTotems`; it uses the jungle ruins / gates / buildings
helpers); Agent A's facet pieces converted into `tools/PropsJungleTotemsData.luau` (`DevTools.PropsJungleTotemsData`:
feather crest, tusks, 2 face reliefs, horns, 2 wings, finial, gem setting, lily pad, lily flower; the face reliefs are
recoloured per head). Rules: `jungle_tall_totem`, `jungle_totem_figure`, `jungle_golden_shrine`, `jungle_temple_pool`
(bakedScale from Base / Step / Rim). New PropFX entry `jungle_temple_pool` (the ripples slide like the fountain's).
Collision: invisible `Collision` parts = the kit's colliding parts, checked part by part on every copy (the baked
copies at their scale). Screenshots (test + game, before + after): `docs/screenshots/jungle_totems/`. Sync: `Sync.run`
twice, the second run 0.

| # | object | MapProps id | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 04 | water pool (pilot) | `jungle_temple_pool` | 5 / 5 (2 at 1.2) | 14 -> 13 (Gold, Moss, Stone, Water, Basin + 8 Collision); about 18,400 triangles; 25.3 x 3.36 x 24.9 | rims of cut stone blocks over a dark core with a bevelled cap course (0.2 chamfer, 0.3 overhang over the water, 3 tone steps, chipped corners) and a wet band on the inner faces; carved corner posts (footing, carved band with 2 grooves, recessed panels, chamfered top) with a 2-level engraved gold cap and a pyramid knob; the water like the fountain / well (Glass T 0.15, #30C4BE, the water_lines Ripples texture, top 0.8 as today, not colliding / queried / touched) over today's Basin with stones on the floor; 5 of Agent A's lily pads (2 with his flower); moss mats on 2 cap corners, 2 facet + 3 part drapes, 2 tufts. Colliders: 40 / 40 exact |
| 01 | tall totem pole | `jungle_tall_totem` | 6 / 6 | 26 -> 15 (Faces, FacesUp, Gold, Heads, Moss, Stone, Wood + 8 Collision); about 26,300 triangles; 7 x 22.3 x 5.3 | 5 chamfered heads at today's sizes, colours and heights, each a different expression: blue grinning (2 rows of teeth, Agent A's curved tusks), tan calm (closed eyes under lids), red angry, brown open-mouthed (upper and lower teeth), yellow surprised (round eyes, an "O" mouth); Agent A's face reliefs (brows, nose, cheek plates) tinted to each head; eyes with dark sockets, 0.16 proud, pupils; rope and gold bands (with rivets) between the sections; today's gold ears as carved small arms with 3-finger hands; Agent A's feather crest in a gold band; a 2-step stone plinth round today's dark wood base (groove band, corner notches), moss on a corner. The faces are 2 unions (one would pass the 20,000 cap). Colliders: 48 / 48 exact |
| 02 | totem figure | `jungle_totem_figure` | 6 / 6 | 18 -> 15 (Faces, Gold, Heads, Moss, Stone, Wood + 8 Collision); about 16,400 triangles; 15.2 x 17.7 x 7.35 | the same family: red lower face stern (angry relief, sockets, teeth top and bottom); blue bird head (gold eyes in sockets, carved brow wedges, today's beak wedge with a lower jaw, a dark line and nostrils); tan head proud (arched relief, tall dark eyes in lighter sockets); Agent A's spread feathered wings (today's 2 wing boxes kept as colliders); the red hat: chamfered brim, a gold band with a stud round the crown, chamfered top, Agent A's curved horns; a rope and a gold band; the stone plinth round the carved dark base. Colliders: 48 / 48 exact |
| 03 | golden shrine | `jungle_golden_shrine` | 3 / 3 (1 at 1.6) | 13 -> 12 (Finial, Gold, Glow, Moss, Stone, 2 Gem, Glyph + 4 Collision); about 21,400 triangles; 12.5 x 9.9 x 8.2 | the 2 steps as bevelled jointed slabs (0.2 bevels, joints every 3-4, 3 tones) with 2 moss drapes and a mat in the back joint; the table as a carved front panel (a 0.2 frame, today's Neon glyph kept in a recessed dark groove, 2 carved side glyphs); today's 2 gold corner trims engraved; the gold top plated (raised rim, engraved lines, a key pattern on the front); Agent A's claw settings round today's 2 Neon gems (kept), each with a PointLight #78FFBE range 8 brightness 0.6; Agent A's finial with its small Neon tip (replacing the idol). Colliders: 12 / 12 exact |

Totals: 20 copies replaced (5 + 6 + 6 + 3); about 413,000 triangles in the place for these four (pool 92k, tall totem
158k, figure 99k, shrine 64k), of which the copies placed in the jungle zones are about 220,000.

### Jungle decor (owner, jungle PROMPT_05 "Props and decor", 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/Jungle_Images_By_Category/.../05_Props_and_Decor/PROMPT_05_Props_and_Decor.txt`.
Images: `docs/Jungle_Images/05_Props_and_Decor/`. Recipe: docs/prop_texture_guide.md C6. Test =
`workspace._Staging.AssetPreview.Jungle.<Kit>`; BA = `ServerStorage.BossArenas.Jungle.Decor.Props`. Every model named
like a kit was searched in the whole place (workspace, ServerStorage, ReplicatedStorage, Lighting): the copies are only
the ones below (none in the hub or the other zones). Checked in Studio and in src: no script, ProximityPrompt,
ClickDetector, Sound, tag, attribute or Light in any kit or copy, and nothing in src or the Studio scripts names them (no
drum sound or interaction exists). **The torch's fire and light are not in the torch:** 22 of the 24 torches have a
`Decor.VFX.Fire_Torch` part (invisible 1 x 1 x 1, Attachment `Fire`, ParticleEmitters Flame / Core / Ember, PointLight
`Light` #FFAA50 range 16 brightness 1) exactly on their `Ember.FirePoint` (pivot + (0, 8.2, 0)); the test and kit
copies have none. Backups (kit + test + every copy): `BackUP_Files/old_props_2026-10-20_pre_jungle_decor/<propId>.rbxm`
(4 files); the main agent's full backup `..._before_jungle_decor`.

| # | object | kit (parts, size) | copies (total incl. kit + test) | collision | functional / notes |
|---|---|---|---|---|---|
| 01 | standing torch | `MapAssets.Jungle.Tribal_Torch`: 6 parts (Foot, Pole, Wrap, Bowl, Skull = the owner's "white wrap", Neon Ember + Attachment FirePoint); 1.9 x 8.15 x 1.9 | 24: test, kit, Jungle_1 Props 4, Jungle_2 Props 6, Jungle_3 Props 10 (2 on a ledge at y 7.5), BA 2 | Foot, Pole, Wrap, Bowl | Ember Neon #FF8C28 1.2 x 0.5 x 1.2 at y 7.9, FirePoint at y 8.2 = where the zone's Fire_Torch VFX (fire + light) burns |
| 02 | drum | `MapAssets.Jungle.Drum_A`: 5 parts (Body, 2 Bands, Skin cylinders, Foot); 4.6 x 3.7 x 4.6 | 7: test, kit, Jungle_2 Props 2 (part-resized x1.2 / x0.8), BA 3 (x1.2 / x0.9 / x0.8) | all 5 | - (no sound, no prompt) |
| 03 | skull on a pole | `MapAssets.Jungle.SkullPike_A`: 5 parts (Pole leaning 3 deg, Skull, Jaw, 2 Eyes); 1.8 x 7.9 x 1.9 | 14: test, kit, Jungle_1 Props 3, Jungle_2 Props 4, BA 5 | Pole, Skull | - |
| 04 | war banner | `MapAssets.Jungle.WarBanner_A`: 8 parts (Pole, Crossbar, Cloth, ClothTail, Stripe, Emblem, Skull, Feather); 5.6 x 17.7 x 1.5 | 9: test, kit, Jungle_1 Props 1, Jungle_2 Props 2, BA 4 | Pole, Crossbar | - |

### Jungle decor remake status (Agent B, 2026-10-20)

Builders: `tools/PropsJungleDecor.luau` (`DevTools.PropsJungleDecor`; it uses the jungle totems / ruins / gates /
buildings helpers); Agent A's facet pieces converted into `tools/PropsJungleDecorData.luau` (`DevTools.PropsJungleDecorData`:
torch flame, torch cup, pike skull (the banner finial is the same skull at 0.83), banner cloth, feather). Rules:
`jungle_torch`, `jungle_drum`, `jungle_skull_pole`, `jungle_war_banner` (bakedScale from Foot / Foot / Pole / Crossbar;
only the drums need it). Collision: invisible `Collision` parts = the kit's colliding parts, checked part by part on
every copy and with ray grids (4 directions, 13 x 13) on every workspace copy, old vs new: 0 differences. Screenshots
(test + game, before + after): `docs/screenshots/jungle_decor/`. Sync: `Sync.run` twice per object, the second run 0.
Status: generated yes, test zone yes, game yes, fountain / well quality: per the main agent's review.

| # | object | MapProps id | replaced | parts per copy before -> after | notes |
|---|---|---|---|---|---|
| 02 | drum (pilot) | `jungle_drum` | 7 / 7 (5 baked at 0.8 / 0.9 / 1.2) | 5 -> 9 (Paint, Rope, Skin, Wood + 5 Collision); about 6,100 triangles; 4.72 x 3.74 x 4.62 | a 16-stave barrel (#A86238, 3 tones, V plank lines, grain lines) over a dark core; today's 2 red bands as painted bevelled hoops with 2 dark rules and a row of cream / gold diamonds; a rope lacing of 12 V's with a rope ring at each hoop; the skin (top at today's 3.7, a lighter centre, a painted red ring and gold diamond) pulled over the rim as a flap with 32 cross stitches and 16 iron tacks; the base as 4 chamfered planks with gaps on 2 battens, nail heads, 4 carved feet; a drumstick with a padded head and a small moss patch on the base. Colliders: 35 / 35 exact (Body, 2 Bands, Skin cylinders, Foot) |
| 01 | standing torch | `jungle_torch` | 24 / 24 | 6 -> 10 (Cloth, Flame, Iron, Stone, Wood, Ember + 4 Collision); about 5,600 triangles; 2.02 x 8.85 x 2.04 | a chamfered stone foot with a darker stepped collar, 2 cut lines and a moss tuft; an 8-sided pole (2 bark tones, bark lines, a knot); today's Wrap as a leather grip of 3 tilted bands crossed by a dark thong; today's white "Skull" as a linen wrap of 3 tilted bands with a hanging loose end; double rope rings at 4.75 / 5.65 / 5.8 / 6.8; a carved pole head (#68442C collar with notches, 4 wooden prongs); Agent A's iron cup (replacing the Bowl) and layered Neon flame (tip 8.85, no shadow). Today's Ember kept exactly (24 / 24) with its FirePoint at y 8.2: all 22 Fire_Torch VFX parts still sit exactly on a FirePoint; no light added in the torch (0 lights in 24 copies). A plain clone of `MapAssets.VFX.Fire_Torch` was added on the test torch's FirePoint (`AssetPreview.Jungle.Fire_Torch`) so the test zone burns like the game. Colliders: 96 / 96 exact |
| 03 | skull on a pole | `jungle_skull_pole` | 14 / 14 | 5 -> 6 (Bone, Rope, Stone, Wood + 2 Collision); about 4,400 triangles; 1.86 x 7.97 x 1.9 | Agent A's skull (cranium, cheekbones, brow ridge, deep sockets, nose hole, a lower jaw with 5 + 4 teeth) on today's Skull centre; today's leaning pole as an 8-sided pole with a bark line and a carved top (2 #68442C rings with a notched band); 2 rope rings, 2 strings of teal / red / gold / bone beads, 2 small feathers hanging under the jaw; a chamfered stone stand with 3 small stones and a moss tuft. Colliders: 28 / 28 exact |
| 04 | war banner | `jungle_war_banner` | 9 / 9 | 8 -> 7 (Bone, Cloth, Rope, Stone, Wood + 2 Collision); about 7,100 triangles; 5.66 x 17.61 x 1.62 | Agent A's cloth (pleats, darker sleeve hem, today's cyan stripe, a zigzag lower edge of 7 gold-trimmed teeth, the stitched emblem with today's gold diamond) named `Cloth`; today's crossbar as a chamfered beam with carved end knobs, a rope X-lashing on the pole and 5 rope loops holding the sleeve; an 8-sided pole with a carved collar under the finial and a 3-turn rope wrap; Agent A's skull finial (top 16.31) and feather (today's place and tilt); a chamfered stone collar with 2 stones and a moss tuft. Colliders: 18 / 18 exact |

Totals: 54 copies replaced (7 + 24 + 14 + 9); about 302,000 triangles in the place for these four (torch 134k, drum 43k,
skull pole 62k, banner 64k), of which the copies placed in the jungle zones (32) are about 176,000.

### Jungle nature (owner, jungle PROMPT_06 "Rocks and plants", 2026-10-20): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/Jungle_Images_By_Category/.../06_Rocks_and_Plants/PROMPT_06_Rocks_and_Plants.txt`.
Images: `docs/Jungle_Images/06_Rocks_and_Plants/`. Recipe: docs/prop_texture_guide.md C7. Test =
`workspace._Staging.AssetPreview.Jungle.<Kit>`; BA = `ServerStorage.BossArenas.Jungle.Decor.Props`. Every model named
like a kit was searched in the whole place: 465 copies in total (counts below include the kit and the test copy), none
in the hub or the other zones. No script, ProximityPrompt, ClickDetector, Sound, tag or Light in any kit or copy; the
lily "Bloom" cube is plain decor (no pickup). Almost every placed copy is the kit resized part by part with Model
scale 1 (bakedScale). Backups (kit + test + every copy): `BackUP_Files/old_props_2026-10-20_pre_jungle_nature/<propId>.rbxm`
(8 files); the main agent's full backup `..._before_jungle_nature`.

| # | object | kit | copies (total incl. kit + test) | collision | notes |
|---|---|---|---|---|---|
| 01 | large mossy rock | `MapAssets.Jungle.Mossy_Rock_L`: 2 Rock MeshParts (Toolbox meshes, Hull collision, 21 wide) + Moss | 15: Jungle_1 5, Jungle_2 4, Jungle_3 4 (scales 0.7 x6, 0.9 x5, 1.0) | the 2 Rocks; 2 Jungle_2 map-edge copies also had a colliding Moss | - |
| 02 | small mossy rock | `Mossy_Rock_S`: Rock MeshPart (4.6 wide) + Moss | 71: Jungle_1 22, Jungle_2 24, Jungle_3 22, BA 1 (0.8 .. 1.3) | Rock | - |
| 03 | round mossy rock | `Mossy_Rock_M`: Rock MeshPart (8 wide) + Moss | 39: Jungle_1 12, Jungle_2 12, Jungle_3 12, BA 1 (0.8 / 1.0 / 1.2) | Rock | the owner's "round" rock |
| 04 | rocks with the cyan block | `Waterfall_Rock_Set`: 2 Rocks, grey Step 8 x 4.6 x 8, cyan #30C4BE WaterTop (7.4 x 0.4 x 8.1 in the game copies) and WaterFall (T 0.15), Foam #F5F6FA (T 0.3) = the "pale slab" | 4: Jungle_2 2 | Step + the 2 Rocks; water and foam do not collide | a small decorative waterfall, nothing scripted |
| 05 | lily pads with the pink cube | `LilyPad_A`: 2 Pad cylinders (5.2 / 3.2 across, #289642 / #78D246) + the pink Bloom block 1.3 x 0.9 x 1.3 | 37: Jungle_2 30, Jungle_3 2, Jungle_4 3 (1.0 / 1.3 / 1.4) | none | Bloom = plain part, no pickup |
| 06 | bamboo cluster | `Bamboo_Cluster_A`: 5 Stalk cylinders (12 .. 21 tall, tilted) + 3 BambooLeaf blocks; 7.2 x 21 x 5.8 | 29: Jungle_1 12, Jungle_2 8, Jungle_3 7 (0.9 .. 1.3) | the 5 Stalks | - |
| 07 | thin bamboo | `Vine_Hanging_A`: 3 Vine sticks 0.5 square (14 / 9.5 / 12 long, tops all at 14, #46AA3C / #166438) + 3 VineLeaf blocks; attribute Height = 14 | 43: Jungle_4 20 (hanging from the ceilings at 48 / 24), BA 14 (hanging from the arena ceiling at 66), Jungle_3 7 (grounded: a raycast from above shows the stick feet 1.1 .. 1.5 under the ground or the ruin stone) (0.6 / 1.0 / 1.6 / 2.0) | none | - |
| 08 | flowering bush | `Bush_Jungle_A`: 2 Leaves MeshParts (mesh 9299837325, #289642 8.5 x 5 x 8 and #78D246 5.4 x 3.6 x 5.4, touchable) + the pink Flowers MeshPart 6.5 x 2.3 x 6.5; attributes SourceAssetId / SourceCreator | 227: Jungle_1 85, Jungle_2 70, Jungle_3 70 (0.8 x84, 1.0 x74, 1.3 x68) | none | - |

### Jungle nature remake status (Agent B, 2026-10-20)

Builders: `tools/PropsJungleNature.luau` (`DevTools.PropsJungleNature`); Agent A's C7 facets in
`tools/PropsJungleNatureData.luau`, and the rock / moss / waterfall-rock facets converted into convex solids (one per
connected shell, about 2 triangles per face) in `tools/PropsJungleNatureSolids.luau`. Rules in tools/SyncMapProps.luau
(bakedScale from Rock 21 / Rock 4.6 / Rock 8 / Step 8 / Bloom 1.3 / Stalk 21 / Vine 0.5 / Leaves 8.5); 07 has 2
templates (`jungle_thin_bamboo` hanging, `jungle_thin_bamboo_grounded` for Jungle_3 and a second test copy marked
`ThinBambooGrounded`). PropFX: `jungle_waterfall_rocks` scrolls the WaterTop and WaterFall ripples. Collision:
invisible `Collision` parts = the kit's colliding parts, checked part by part on every copy and with ray grids on every
workspace copy that collides, old vs new: 0 differences. Screenshots (test + game, before + after):
`docs/screenshots/jungle_nature/` (the 02 / 03 game "before" shots were rebuilt from the backup meshes after the sync).
Sync: `Sync.run` twice per object, the second run 0; a final dry run of the 9 templates: 466 copies, 0 to replace.
Triangles: visible triangles of the template (the invisible colliders not counted).

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| 01 | large mossy rock (pilot) | `jungle_rock_large` | 15 / 15 | 4,406 | Agent A's angular rock (stacked tilted strata, cracks) as convex solids, moss cushions + ledge mats on the top third, grass and pebbles at the foot; the 2 Rock meshes kept as invisible Hull colliders; the 2 Jungle_2 map-edge copies keep their Moss collider as `MossCollision` (MapPropKeep, MapFixCollide). Colliders 15 / 15 exact, ray grids 14 copies 0 differences |
| 02 | small mossy rock | `jungle_rock_small` | 71 / 71 | 1,262 | the same method; grass kept under 3.55 so the height stays. Colliders 71 / 71, ray grids 0 differences |
| 03 | round mossy rock | `jungle_rock_round` | 39 / 39 | 2,114 | the same method, 2 ledge mats. Colliders 39 / 39, ray grids 0 differences |
| 04 | rocks with the cyan block | `jungle_waterfall_rocks` | 4 / 4 | 3,326 | the rocks as convex solids; the Step as stone courses with a cap row; WaterTop, WaterFall and Foam at today's places, sizes, colours and transparency, the water bevelled with the Ripples texture scrolled by PropFX (like the fountain / well), a lip, foam line, streaks and foam blobs, a soft cyan PointLight; Foam stays pale. Colliders 4 / 4 (Step + 2 Rocks), ray grids 0 differences |
| 05 | lily pads | `jungle_lily_pads` | 37 / 37 | 1,008 | 2 round pads (today's places, sizes, greens) with a V notch, an upturned rim, a centre dome and lighter veins; Agent A's layered-petal pink lotus in the Bloom's box; nothing collides, is queried or touched |
| 06 | bamboo cluster | `jungle_bamboo` | 29 / 29 | 2,326 | today's 5 stalks as canes (2 segments in a green gradient, straw-tinted foot, darker node rings every 3.4); 2 leaf sprays at the top of the 3 tallest canes and a side spray on the 2 others; a small dark soil base with 5 roots and 2 grass tufts. The 5 Stalks are the colliders: 29 / 29 exact, ray grids 28 copies (9,072 rays) 0 differences |
| 07 | thin bamboo | `jungle_thin_bamboo` + `jungle_thin_bamboo_grounded` | 36 / 36 + 8 / 8 | 1,028 / 1,116 | today's 3 sticks as thin canes (places, lengths, tops at 14, colours kept; node rings; today's 3 leaf blocks as 3-leaf sprays on the same side, a 2-leaf spray lower on the outer canes). Hanging copies: no ground base. Grounded variant (Jungle_3 x7 + test): the 2 sticks that started in the air reach the ground line, a small root flare and 2 grass blades per cane. Height = 14 kept on every copy; nothing collides |
| 08 | flowering bush | `jungle_flower_bush` | 227 / 227 | 736 + today's 2 leaf meshes | today's 2 leaf clumps kept as they are (meshes, places, sizes, colours, touchable); the pink Flowers mesh replaced by 6 open flowers (5 diamond petals in 2 pinks round a gold centre, on short stems) and 3 closed buds, placed on the clump surfaces (a marker profile showed the mesh surface on the clump ellipsoid); Agent A's base leaves. SourceAssetId / SourceCreator kept; nothing collides |

Totals: 466 copies replaced (the 465 of the inventory and the new grounded test copy). Triangles in the place for the new geometry (all copies): about 569,000 (large rock 66k,
small rock 90k, round rock 82k, waterfall 13k, lily pads 37k, bamboo 67k, thin bamboo 46k, bush 167k), of which the
copies placed in the jungle zones are about 518,000 and the boss arena about 18,000. The old Toolbox meshes (rocks,
bush flowers) cannot be read (no EditableMesh permission), so their old triangle counts are unknown; the thin bamboo
was 72 triangles per copy (6 blocks).

### Batch 4 (owner, "HUB AND PLAINS BUILDINGS AND PROPS IMPROVEMENT - BATCH 4", 2026-10-21): inventory before the remake (read from Studio)

Prompt: `REMAKE OBJECT/Hub_Plains_Props_Batch4/Hub_Plains_Props_Batch4/PROMPT_Hub_Plains_Props_Batch4.txt`. Images:
`docs/Hub_Plains_Props_Batch4/{01_Buildings, 02_Tents, 03_Props}/`. Recipe: docs/prop_texture_guide.md section D (+ A).
Test = `workspace._Staging.AssetPreview.ModelsA.Lineup.<Common|Plains|Hub>.<Kit>`; BA = `ServerStorage.BossArenas`.
Every model named like a kit was searched in workspace, ServerStorage and ReplicatedStorage; counts include the kit and
the test copy. The kits as they were are kept as rows in `tools/PropsBatch4Data.luau` (the builders read them).
Backups (kit + test + every copy): `BackUP_Files/old_props_2026-10-21_pre_batch4/<propId>.rbxm` (17 files); the
main agent's full backup `..._before_batch4`.

| # | owner's object | kit | copies (total) | functional / notes |
|---|---|---|---|---|
| B01 | cottage, red roof, one window | `MapAssets.Plains.FarmHouse` (73 parts) | 3: test, kit, Plains_1.Decor.Farm | no NPC / prompt / script; every part collides except the window bars, frames and sills |
| B02 | cottage, red roof, two windows | `MapAssets.Hub.Cottage_A` (65) | 5: test, kit, Hub.Decor.Village x3 | as B01 |
| B03 | two-storey house, blue roof | `MapAssets.Hub.Cottage_B` (76) | 4: test, kit, Hub.Decor.Village x2 | as B01 |
| B04 | stone tower, blue roof | `MapAssets.Hub.Hub_Tower` (47) | 3: test, kit, Hub.Decor.Village | everything collides; the flag is a static wedge |
| T01 | tent red / white | `MapAssets.Common.Tent_A` (9, = NomadTent_A's parts) | 4: test, kit, Hub AFKCorner (linen + red), Plains_2 PirateCamp (all red) | static |
| T02 | green "transparent" tent | the 7 tent parts inside `MapAssets.Plains.HunterCamp` | 3 hosts: test, kit, Plains_3.Decor.HunterCamp | Transparency 0 everywhere: the #68A848 canvas is the grass colour |
| P01 | spiked mace | `MapAssets.Plains.Troll_Club` (12; 6 Spike MeshParts) | 3: test, kit, BossArenas Plains TrollDen | Toolbox attributes SourceAssetId / SourceCreator |
| P02 | barrel | the existing `barrel` template | 43: Barrel_A x33 + embedded (HunterCamp x3, Market_Awning_A x4, Station_Trainer x3) | the staves collide |
| P03 | ladder | `MapAssets.Common.Ladder_A` (8) | 3: test, kit, Plains_4 Mine | plain parts (no TrussPart, no script): rails at x +-1.4, rungs 2.6 x 0.3 every 1.5 |
| P04 | fence section | `MapAssets.Common.Fence_Section` (4) | 16: test, kit, Plains_1 Farm x14 | 8 long, laid end to end every 8 |
| P05 | sign board | `MapAssets.Common.Signpost_A` (4) | 10: test, kit, Hub AFKCorner ("AFK Zone"), the "Hub" return signs of Plains_1, Desert_1 (front + back), Jungle_1, Tundra_1, Volcano_1, Abyss_1, Void_1 | the texts are SurfaceGuis on the Board |
| P06 | wooden post | `MapAssets.Common.Fence_Post` (2) | 8: test, kit, Plains_1 Farm x6 (one an empty model, deleted) | |
| P07 | banner, red diamond | `MapAssets.Common.Banner_A` (8) | 11: test, kit, Hub Flags x6, AltarBackdrop x3 (1.5 / 1.5 / 1.9) | static |
| P08 | flagpole, red flag | `MapAssets.Common.Flag_Pole_A` (4) | 21: test, kit, Hub Flags x12, Islets x6 (2.2), Plains_2 PirateCamp | static |
| P09 | short lamp post | `MapAssets.Common.Torch_Standing` (4 + FirePoint + PointLight) | 21: test, kit, Hub Harbor x2 / AltarBackdrop x2 (no light), Plains_4 Cavern x5, Desert_3 Caves x4, BossArenas Plains x6 | each copy's light differs (16 / 0.7, 20 / 0.9, 28 / 1.2, none); a Decor.VFX Fire_Torch part stands on each game copy's FirePoint |
| P10 | "campfire or brazier parts" = a wall torch | `MapAssets.Common.Torch_Wall` (4 + FirePoint + PointLight) | 38: test, kit, Plains_4 Mine x4, Desert_4 x10, Jungle_4 x14 (parts resized x1.3), BossArenas Jungle x8 | 22 copies have no light |
| P11 | signpost + lectern + lantern platform | `MapAssets.Hub.Station_TutorialGuide`; hub copy `workspace.Hub.TutorialGuide` | 3: test, kit, Hub.TutorialGuide | the Guide NPC's marker: Interact (ProximityPrompt "Talk" / "Guide", BillboardGui NameTag), NpcSpot, the nested Lantern (`lantern` MapProp) |

### Batch 4 remake status (Agent B, 2026-10-21)

Builders: `tools/PropsBatch4.luau` (`DevTools.PropsBatch4`, on the earlier helpers); the kits as rows in
`tools/PropsBatch4Data.luau` (+ the game copies' colliders of the 3 houses: `<kit>_game`); Agent A's D6 facets in
`tools/PropsBatch4Facets.luau` (banner and flag cloth, cone roof, open book; the torch flame / cup and mace spike facets
were replaced by part-built pieces: about 3,500 triangles a torch on 59 torches, and a 600-wedge union for the spikes
that hung Studio's CSG). Rules: tools/SyncMapProps.luau (batch 4 block + the embedded `tent_green`). Collision:
invisible `Collision` parts = today's colliding parts, checked part by part on every copy before / after (`B4_check`).
Screenshots (test + game, before + after): `docs/screenshots/batch4/`. Sync: `Sync.run` twice per object, the second 0.

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| B01 | cottage, red roof, one window (pilot) | `cottage_one_window` | 3 / 3 | 20,700 | half-timbered recipe (guide D2): foundation of 2 stone courses, plaster in 2 bands, today's timbers as chamfered beams with pegs, a sole plate, diagonal braces in the free bays, gable collar beams; about 380 individual red tiles in half-offset rows with lifted butts (2 unions, no tile overlapping another in its union), ridge cap, fascia, bargeboards; a stone chimney with a cap and flue; a plank door with strap hinges and today's gold handle; a 3-block step with a worn middle; windows with cross muntins, plank shutters where there is room and a flower box under the front window; a wall lantern by the door; moss at the corners. Colliders: taken from the GAME copy (it differed from the kit by 0.06 .. 0.17 after an earlier window fix): the game copy exact, the test and kit copies within 0.17 |
| P02 | barrel (pilot) | `barrel` | 43 / 43 | 1,460 | 14 staves in 3 tilted thirds (bulging), plank gaps over a dark core, 3 iron hoops with rivets at today's heights, a planked lid with a bung hole 0.15 under the chime. Colliders 43 / 43 exact (the 3 stave cylinders); the embedded barrels (HunterCamp, fruit stalls, trainer) follow |
| B02 | cottage, red roof, two windows | `cottage_two_windows` | 5 / 5 | 17,400 | the same recipe; climbing vines on 2 corners. Colliders from the game copies (the 3 hub copies identical): the 3 game copies exact, test / kit within 0.13 |
| B03 | two-storey house, blue roof | `house_blue_roof` | 4 / 4 | 19,300 | the same recipe with blue tiles, joist ends and carved brackets along the floor rail (the jetty), a small tiled canopy over the door, flower boxes under the upper front windows too. Colliders from the first hub copy: it is exact; the second hub copy differs from it by 0.03 .. 0.045 (posts and step), test / kit within 0.09 |
| B04 | stone tower, blue roof | `stone_tower` | 3 / 3 | 19,500 | 24 courses of cut stone faces in running bond over a dark core (2 unions), a projecting dark band, a battered 2-course base, a corbel ring under the parapet, 2 courses of parapet blocks, 8 merlons with chamfered caps, the roof drum; Agent A's tiled cone roof (4 unions), the flag at 0.72 (static, like today), the pole with iron rings and the gold finial; a plank door under an arch of 7 voussoirs, a 2-course step; 3 windows with dark sills / lintels and small shutters; moss. Colliders 3 / 3 exact |
| T01 | tent red / white | `tent_red_white` + `tent_red` | 3 / 3 + 1 / 1 | 1,960 | the desert tent recipe (B6) in linen #E8E2D0 / #DCD5C2 with darker seams, red bindings and flap lining, rope ties, poles with gold caps, guy ropes and stakes, a red / linen rug, grass tufts. The Plains_2 PirateCamp copy (all red today) has its own template `tent_red` (red canvas, linen lining). Colliders 3 / 3 + 1 / 1 exact (today's 9 parts; the doorway stays closed as today) |
| T02 | green tent (HunterCamp) | `tent_green` (embedded, wrapper "Tent") | 3 / 3 | 2,120 | the same recipe at 0.92 in an opaque olive canvas #7A8A3C / #6E7E35 with #66752F seams and a light olive lining, linen bindings, a bedroll inside the open door; Transparency 0 everywhere (it was never transparent: #68A848 was the grass colour). Colliders 3 / 3 exact |
| P01 | spiked mace | `spiked_mace` | 3 / 3 | 1,390 | octagonal carved head with grooves, iron bands with rivets and raised rims, an iron end cap with a boss; 6 spikes after Agent A's design (collar, bevelled blade, pale tip) at today's places, part-built (the 32-face facet spikes made a 600-wedge union that hung CSG); an octagonal handle with a 6-band leather wrap and collar, an octagonal pommel with a ring. SourceAssetId / SourceCreator kept. Colliders 3 / 3 exact |
| P03 | ladder | `ladder` | 3 / 3 | 1,060 | bevelled rails (a crack on one), chamfered rungs at today's heights (the lowest lighter: worn), dark mortise plates and peg heads. Today's 8 parts are the exact colliders (no TrussPart today: the climbing is unchanged). 3 / 3 exact |
| P04 | fence section | `fence_section` | 16 / 16 | 770 | chamfered posts with pyramid caps, rails as 2 boards with a scarf joint and nails, a rope lashing, grass tufts; rail ends still at +-4, posts at +-3.5 (every line still joins). 16 / 16 exact |
| P05 | sign board | `sign_board` + `sign_board_dark` | 9 / 9 + 1 / 1 | 650 | 3 planks with gaps in a 4-trim frame, nails and iron corner plates, a chamfered post with a pyramid cap on a 2-block stone footing. An invisible part named `Board` at today's place carries the SurfaceGuis: all 9 texts kept (7 x "Hub" incl. Desert_1 front + back, "AFK Zone"), checked on screen. The Tundra_1 sign (dark wood today) has its own template. 10 / 10 exact |
| P06 | wooden post | `wooden_post` | 7 / 7 | 700 | chamfered post with cracks and nails, a bevelled cap with a low pyramid, a 3-turn rope wrap with a hanging end, a stone footing, grass tufts. The empty Plains_1 Fence_Post model (no parts, at (2020, 0, -50)) was deleted. 7 / 7 exact |
| P07 | banner, red diamond | `banner_diamond` | 11 / 11 | 3,250 | Agent A's cloth (folds, zigzag gold-trimmed edge, stitched gold diamond), a chamfered crossbar with carved knobs, rope X-lashing and 5 loops, an octagonal pole with carved rings, a faceted gold finial on a collar, a 2-step stone base. The cloth's red tones are single-colour unions: `_Variants` "Cloth_<hex>" keep the 6 blue / purple / gold copies in their colours (rule variant). 11 / 11 exact; static (no waving today) |
| P08 | flagpole, red flag | `flagpole` | 21 / 21 | 940 | a pole tapered in 3 octagonal sections, 3 iron rings, a cleat with the halyard, Agent A's flag (fold panels, hem, gold sleeve), a faceted gold finial, an octagonal 2-step stone plinth. 7 colour variants keep the 16 non-red flags' colours. 21 / 21 exact; static |
| P09 | short lamp post (Torch_Standing) | `standing_torch` | 21 / 21 | 420 | chamfered pole with iron bands and a collar, a glass lantern on today's Head (4 corner posts, 4 warm Glass panes, an OPEN crown with points), a layered Neon flame (3 bipyramids, part-built instead of the 2,200-triangle facet), an octagonal 2-tier stone base. Today's Ember and Head with the FirePoint kept: the 13 game FirePoints still sit on their Fire_Torch VFX parts. Each copy's own PointLight moved onto an invisible `TorchLight` part (MapPropKeep): 19 carried, the 2 without light still without. 21 / 21 exact |
| P10 | "campfire / brazier parts" = wall torch (Torch_Wall) | `wall_torch` | 38 / 38 | 700 | owner directive 2026-10-21: the bar flipped to lean "/" (foot at the back plate, top end in the cup's foot), an iron collar band carrying the cup, a ring holding the foot, a riveted back plate, a leather wrap and iron rings, an octagonal iron cup with a rim and 4 claws, a layered Neon flame; today's Ember, FirePoint (28 on their VFX parts), lights (16 carried by TorchLight parts, 22 without) and collider set unchanged. The 14 Jungle_4 copies (parts resized x1.3) keep their size (rule bakedScale from the Stick). 38 / 38 exact |
| P11 | signpost + lectern + lantern platform | `tutorial_guide` | 3 / 3 | 3,250 | the platform as rings of bevelled stone blocks (12 + a darker kerb of 16) around an inset disc with a 4-point compass star (walking surface still at 0.6), a chamfered signpost with a pyramid cap, iron bands and the faceted gold finial, today's 2 arrow boards as 2-plank boards with their tips, a lectern on a cross foot with rings, a slanted top with a lip and Agent A's open book. The Guide NPC is untouched: Interact (ProximityPrompt "Talk" / "Guide", range 12, key E, BillboardGui NameTag), NpcSpot, NPC and the nested Lantern are kept (the template has none of them). 3 / 3 exact |

Totals: 245 copies replaced (19 templates: the 17 objects + the red tent and the dark sign). Triangles of the new
geometry, all copies: about 494,000 (houses 62k / 87k / 77k, tower 59k, tents 14k, mace 4k, barrel 63k, ladder 3k,
fence 12k, signs 7k, posts 5k, banners 36k, flags 20k, lamp posts 9k, wall torches 27k, guide 10k), of which the copies
in the hub, zones and boss arenas (without the kits and test copies) about 298,000. The old parts were plain blocks (a
few hundred triangles per house).

### Tundra buildings (owner, "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Buildings and structures", 2026-10-22): inventory before the remake (read from Studio)

Images: `docs/Tundra_Images/01_Buildings_and_Structures/`. Recipe: docs/prop_texture_guide.md section E (+ A).
Test = `workspace._Staging.AssetPreview.Tundra.<Kit>` (the tundra test row, a SyncMapProps search root since this
task); kit = `ServerStorage.MapAssets.Tundra.<Kit>`. Every model named like a kit (and every cabin / cave / scaffold /
bridge name) was searched in workspace, ServerStorage and ReplicatedStorage. No copy has a script, prompt, NPC,
teleport, tag or attribute, and nothing functional stands within 40 studs of one. The kits as they were are kept as
rows in `tools/PropsTundraBuildingsData.luau` (+ the game copies that differ: `<kit>_game`). Backups (kit + test + every
copy): `BackUP_Files/old_props_2026-10-22_pre_tundra_buildings/<propId>.rbxm` (4 files); the main agent's full backup
`..._before_tundra_buildings`.

| # | owner's object | kit | copies (total) | functional / notes |
|---|---|---|---|---|
| 01 | wrecked wooden cabin | `Cabin_Broken` (40 parts, 26.3 x 18 x 26) | 3: test, kit, Tundra_1.Decor.Props | not enterable: the door is a colliding askew slab and the solid DoorDark closes the doorway; everything collides except the 6 LogLines and 2 WindowBars (32 colliders). The Tundra_1 copy differs from the kit by 0.05 .. 0.2 (walls, log lines and window pushed out) |
| 02 | ice cave entrance | `Ice_Cave_Mouth` (9 parts, 29 x 18.2 x 13) | 7: test, kit, Tundra_2 x4, BossArenas Tundra (Model scale 1.25) | closed niche: the solid Dark panel closes the opening (no teleport); colliders Back, Dark and 3 IceRock MeshParts (2 boulders, the slab rock); the Snow mesh and 3 Icicle meshes do not collide |
| 03 | wooden scaffold stand | `Wooden_Scaffold` (15 parts, 16 x 13.6 x 8) | 5: test, kit, Tundra_3 x3 | colliders 4 Posts, Deck (top y 10.8), Rail (top 13.55); braces, plank lines and 2 snow slabs do not collide |
| 04 | curved snow bridge slab | `Snow_Bridge_Section` (11 parts, 41.6 x 9.8 x 10.6) | 5: test, kit, Tundra_3 x3 | colliders 3 Span + 3 SpanSnow (middle top y 8.0; sides 13 deg, 7.93 -> 4.92); the 3 game copies' side parts are 0.1 deeper (10.1 / 10.7); they float along the Tundra_3 walls and connect to nothing |

### Tundra buildings remake status (Agent B, 2026-10-22)

Builders: `tools/PropsTundraBuildings.luau` (`DevTools.PropsTundraBuildings`, on the earlier helpers); the kits as rows
in `tools/PropsTundraBuildingsData.luau`; Agent A's E7 facet pieces as convex solids (one per closed shell) in
`tools/PropsTundraBuildingsSolids.luau`, written by `tools/tundra_facets_to_solids.py` from
`Blender_Exports/Props/facets/tundra_*.json` (the 2 cabin roof-snow pieces are left out: the cabin was approved before
the facets came). Rules: tools/SyncMapProps.luau (tundra block + the tundra test row as a search root). Collision:
invisible `Collision` parts = today's colliding parts (the cave's IceRock MeshParts keep mesh, size and fidelity),
checked part by part on every copy and with offset ray grids (5 directions, 0.5 step) on every workspace copy before /
after. Screenshots (test + game, before + after): `docs/screenshots/tundra_buildings/`. Sync: `Sync.run` twice per
object, the second 0.

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| 01 | wrecked wooden cabin (pilot) | `tundra_wrecked_cabin` | 3 / 3 | 16,700 | 8-sided round logs with saddle-notched corners running 0.6 past the walls with lighter cut ends, on a slate footing; the left half to the eaves, the right wall and the front right broken in jagged steps with splintered ends and 2 boards nailed across; log gables; a plank roof on rafters with fascia, bargeboards and nails under a soft thick snow cap with drooping lumps and 15 small icicles; the right roof remnant with broken boards, a fallen section inside, the bare splintered rafter, the log ridge; a stone chimney (17 courses in bond, cap, snow round the flue, icicles); the frozen cross-frame window (ice pane T 0.3, frost corners, snowy sill, drips); the plank door with iron straps hanging askew off its top hinge (bottom strap torn, empty pintle); snow inside, rounded drifts on today's 3 wedges, loose planks. Colliders from the GAME copy: exact there (32 / 32 part by part; ray grid 23,805 rays, 0 real differences: 22 rays grazing exact part edges, a ray shifted 0.03 gives the old value); test / kit within 0.2 (as the batch 4 houses). Size 28.4 x 18 x 26 (+8 %) |
| 02 | ice cave entrance | `tundra_ice_cave` | 7 / 7 | 7,100 | Agent A's 2 faceted glass boulders (Glass T 0.3, light chamfered edges, opaque deep cores), the 2-strata slate slab and its soft snow cap (5 front drips, 2 per end); today's 3 icicles at their x / z (roots on the slab underside, no tip under y 7.0) + 2 clusters; today's Back and Dark exactly as they are (the opening stays closed) with an inner slate frame (2 jambs, 5 voussoirs) lined in navy and a frozen stone lip (threshold, ice glaze, 3 stubs); 4 shard clusters, 2 capped ice blocks, soft drifts. Colliders 5 / 5 exact on all 7 (the arena copy at 1.25 too); ray grids 0 differences on the 5 workspace copies |
| 03 | wooden scaffold stand | `tundra_scaffold` | 5 / 5 | 7,500 | posts chamfered on slate footings with 2 iron bands, an ice glaze at the feet, capped front posts with snow caps; today's front X braces cross-lapped (iron strap, pegs) with rope lashings at the posts; the side diagonals strapped and nailed; 2 knee braces; the deck as 6 planks with gaps (top exactly y 10.8) over a dark board and 2 joists, nails, one plank shorter; today's rail chamfered + 2 side rails to 2 stub posts, rope ties, frost rime, a 0.15 snow line on the rail; today's 2 snow patches as soft caps (today's height, 0.45 over the deck, as today: no collider), 3 capped ice blocks, 3 icicle clusters, 2 low drifts at post feet. Colliders 6 / 6 exact on all 5; ray grids 0 differences. Size 16.5 x 14.2 x 8.7 (+9 %) |
| 04 | curved snow bridge slab | `tundra_snow_bridge` | 5 / 5 | 6,700 | Agent A's layered faceted ice undersides (3 strata, keels, light edges, Glass T 0.25 over opaque cores; the left side = the right piece turned 180) and soft snow whose tops are exactly the collider tops (lips and drips over the long edges and the ends); a soft snow roll over each joint (at most 0.1 over a walk top: checked analytically on the solids' planes over 4,968 columns, 0 columns more than 0.15 over); today's 5 icicles at their x / z + 16 small singles under the lips. Colliders from the GAME copies: 6 / 6 exact on the 3 game copies (ray grids 43,245 rays, 0 real differences: 2 edge-grazing rays); test / kit 0.05 deeper per side than before (the game copies' 10.1 / 10.7) |

Totals: 20 copies replaced (4 templates). Triangles of the new geometry, all copies: about 171,000 (cabin 50k, cave 50k,
scaffold 38k, bridge 34k), of which the copies in the zones and the boss arena (without the kits and test copies) about
95,000.

### Tundra gates (owner, "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Gates and entrances", 2026-10-22): inventory before the remake (read from Studio)

Images: `docs/Tundra_Images/02_Gates_and_Entrances/`. Recipe: docs/prop_texture_guide.md sections E and E8 (+ A).
Test = `workspace._Staging.AssetPreview.Tundra.<Kit>`, kit = `ServerStorage.MapAssets.Gates.<Kit>`. Each gate has exactly 3
copies (test, kit, game); no other copy anywhere, no boss-arena copy. The game copies' parts are kept as rows in
`tools/PropsTundraGatesData.luau` (the kits / test copies of 02 and 04 differ from them by 0.05 .. 0.15 on a few parts:
the colliders come from the game copies). Backups (3 copies each): `BackUP_Files/old_props_2026-10-22_pre_tundra_gates/<propId>.rbxm`
(4 files); the main agent's full backup `..._before_tundra_gates`.

| # | owner's object | kit -> game copy | contract / functional parts | notes |
|---|---|---|---|---|
| 01 | log torii arch with a blue sign | `EntryArch_Tundra` -> `Tundra_1.EntryArch` (37 parts) | ZoneId "Tundra", NameSign with NameGuiFront / Back; no Barrier | 2 slate bases, 4 round posts in pairs, 4 bindings, 2 round beams, the blue NameSign + SignFrame, 2 Neon lanterns #60BEFF with PointLight b0.8 r14 (already cold), 4 colliding Crystal MeshParts (Hull), snow parts, 6 icicle meshes |
| 02 | palisade gate | `Gate_Tundra_2` -> `Tundra_2.Gate` (60) | SubZoneId, PrimaryPart Barrier 24 x 16 x 1.4 (19 door children incl. 2 snow banks, 2 yellow handles, 2 bands), PriceSign "500K Gold" GUIs, 2 Embers + FirePoints; their lights are the zone's 2 Decor.VFX.Fire_Torch parts (warm b1 r16 #FFAA50) | the plains palisade kit recoloured with snow: 8 logs, 8 colliding snow discs, 2 slate bases, bindings, lintel, sign posts / frame, 2 SignRoof wedges (ridge z -0.4), 2 torch sticks, 4 colliding Drift wedges |
| 03 | ice rock gate | `Gate_Tundra_3` -> `Tundra_3.Gate` (32) | SubZoneId, invisible colliding Barrier 24 x 16 x 2 (12 ice blocks, the Neon Rune, top snow, snow bank under it), PriceSign "1.25M Gold" | 2 Pillar + 2 Rock MeshParts (Hull, colliding) with snow meshes, 2 jambs, a round beam, 2 ropes, sign frame |
| 04 | ice castle gate | `Gate_Tundra_4` -> `Tundra_4.Gate` (38) | SubZoneId, Glass Barrier 24 x 16 x 3 T 0.35 colliding (3 frames, seam, 4 facets, Neon Emblem under it), PriceSign "3.12M Gold" | 2 towers, 2 bands, 2 caps, wall, cornice, 4 crenels, 2 buttresses, 2 Neon slits, 2 Spire meshes (query only), sign frame, 5 icicle meshes, 2 colliding Drift wedges |

### Tundra gates remake status (Agent B, 2026-10-22)

Builders: `tools/PropsTundraGates.luau` (`DevTools.PropsTundraGates`, on DevTools.PropsTundraBuildings); 01 and 02 reuse the
PLAINS gate builders' parts (props batch 2 entry_arch / gate_palisade: `ringCourse` piers, octagonal logs, riveted straps,
the plank double door, the wall torch, `shingleRoof`; PropsBatch2 now exports `ringCourse` / `capSlabs`) re-proportioned
to the tundra kits; Agent A's E8 facets as convex solids in `tools/PropsTundraGatesSolids.luau` (written by
`tools/tundra_facets_to_solids.py <root> gates`). Rules: tools/SyncMapProps.luau (tundra gates block). Gate contract on
every copy: the Barrier is the PrimaryPart and collides (exact), every door piece and glow is under it, SubZoneId /
ZoneId and the model attribute BarrierDecorIsChildOfBarrier kept, the PriceSign / NameSign GUIs moved onto the exact new
signs (texts checked). Collision: invisible `Collision` parts = today's colliding parts (MeshParts with today's mesh and
Hull fidelity), checked part by part and with ray grids that respect CanCollide (a colliding Barrier's non-colliding
children are not hit). Screenshots (test + game, before + after): `docs/screenshots/tundra_gates/`. Run 2 = 0 for each.

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| 01 | log torii arch (pilot) | `tundra_log_arch` | 3 / 3 | 15,100 | from the plains entry arch: coursed blue-grey slate piers (ringCourse) under soft caps, today's paired posts and 2 beams as frosted 8-sided logs with cut ends, steel collars / rings, rime, domed post caps, Agent A's log snow on both beams (0.7-0.85 thick, drips), icicle groups; dark blue steel straps with rivets at today's binding heights; 2 struts; today's NameSign exactly (icy blue #4C8CD2, "Tundra" both faces) in a frosted frame with ice corners; the 2 hanging lanterns: today's Neon cores and PointLights (b0.8 r14 #60BEFF) in steel cages with frosted panes, capped roofs, chains, beam rings; Agent A's shards on today's 4 Crystal colliders; drifts. ZoneId kept. Colliders 18 / 18 exact (+ the NameSign); ray grids 0 real differences (the Crystal meshes must be cloned from a Hull-fidelity source: CollisionFidelity cannot be set by script) |
| 02 | palisade gate | `tundra_palisade_gate` | 3 / 3 | 22,100 | the plains gate_palisade almost 1:1: ringCourse slate bases with caps, the 8 octagonal frosted logs with domed caps on today's snow discs, riveted steel straps, the lintel with steel bands under Agent A's lintel snow (icicles end above y 16.2), the plains shingle roof in blue-grey tiles on today's SignRoof ridge (z -0.4) under Agent A's roof snow on both slopes, icicles; today's PriceSign exactly (icy blue, "500K Gold") in a frosted frame; the 2 wall torches (bar leaning "/" up into a steel cup, today's Ember + FirePoint exact, the flame cold #C8F0FF); drifts on today's 4 Drift wedges. Door under the Barrier (dark core): 10 frosted planks a leaf, rails and today's 2 diagonal braces, today's 2 bands as blue steel bands with rivets, strap hinges, today's yellow handles as gold grips (both faces), the 2 snow banks as soft drifts. Owner's cold light: the 2 Tundra_2 Decor.VFX.Fire_Torch parts recoloured (PointLight #C8F0FF, brightness 1 / range 16 kept; particles like Tundra_4's Fire_Torch_Blue). Colliders 36 / 36 exact; grid vs today's colliding rows 0 differences |
| 03 | ice rock gate | `tundra_ice_rock_gate` | 3 / 3 | 12,700 | Agent A's 2 layered blue ice-rock pillars and 2 side rocks with snow caps on today's Pillar / Rock Hull colliders; today's jambs as dark blue slate pillars (10 courses, capstone, snow, icicles); the beam as a frosted log with steel rings and Agent A's log snow, icicles; today's PriceSign exactly (icy blue, "1.25M Gold") in a frosted frame on 2 steel chains; stones and drifts outside the passage. Door under the invisible Barrier: today's 12 ice blocks as bevelled Glass bricks (T 0.25) over a frosty joint wall, an arch of 7 light ice voussoirs with a Neon cyan diamond keystone, today's Neon Rune kept, soft top snow and snow bank. Colliders 10 / 10 exact; grids 0 real differences (7 rays graze the Hull silhouettes) |
| 04 | ice castle gate | `tundra_ice_castle_gate` | 3 / 3 | 17,800 | bevelled ice-block masonry on the towers (front and sides) and the wall over the door, over deep blue cores; today's bands (studs) and caps (chamfered, snow, icicles); Agent A's crystal spires on the caps; today's Neon slits in ice frames; today's cornice with dentils and 4 merlons with snow; icicles under the cornice (today's 5 + 7 singles); today's buttresses as bevelled ice pilasters (base, 4 drums, capital, snow); today's PriceSign exactly ("3.12M Gold") in a frosted ice frame with corner gems; drifts on today's 2 wedges. Door: today's Glass Barrier exactly, under it lighter ice frames and seam, today's 4 facets as frosted lines, frost corners, today's Neon Emblem in a faceted ice setting with a cold PointLight (b0.6 r10, it goes out with the Barrier). Colliders 19 / 19 exact; game grid 0 differences (test / kit within 0.05: the game copy's parts) |

Totals: 12 copies replaced (4 templates). Triangles of the new geometry, all copies: about 203,000 (arch 45k, palisade
66k, ice rock 38k, castle 53k), of which the 4 game copies about 68,000.

### Tundra monuments (owner, "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Ice monuments, statues and shrines", 2026-10-22): inventory before the remake (read from Studio)

Images: `docs/Tundra_Images/03_Ice_Monuments_and_Statues/`. Test = `workspace._Staging.AssetPreview.Tundra.<Kit>`, kit =
`ServerStorage.MapAssets.Tundra.<Kit>`; the kits' parts are kept as rows in `tools/PropsTundraMonumentsData.luau`.
Backups: `BackUP_Files/old_props_2026-10-22_pre_tundra_monuments/<propId>.rbxm` (6 files, every copy); the main agent's
full backup `..._before_tundra_monuments`.

| # | owner's object | kit | copies | contract / functional parts |
|---|---|---|---|---|
| 01 | ice pillar | `Ice_Pillar` | 20: test, kit, Tundra_4.Decor.Props x10, ServerStorage BossArenas.Tundra.Decor.Props x8 | shaft, base and cap collide |
| 02 | ice knight in a glass case | `Frozen_Knight_Statue` | 12: test, kit, Tundra_4.Decor.Props x4 (1.15), Tundra_4.BossGate x2 (1.25), BossArenas.Tundra.Decor.Props x4 | the case collides; the 2 BossGate copies are nested in the BossGate (its Interact prompt "Enter / Frost King's Throne" stays on the BossGate) |
| 03 | ice throne | `Ice_Throne_Small` | 4: test, kit, Tundra_4.Decor.Props, BossArenas.Tundra.Decor.Props (1.1) | seat top y 3.6, back, arms collide |
| 04 | yellow dome pedestal | `Warm_Brazier` / `WarmBrazier` | 6: test, kit, ServerStorage BossArenas.Tundra.WarmSpots x4 (scale 1.3) | Embers + FirePoint; the 4 arena copies carry an extra `Fire` part (emitters + PointLight #FFB85A b0.9 r24) |
| 05 | glass frame with a checkmark | `Ice_Wall_Panel` | 10: test, kit, Tundra_4.Decor.Props x4, Tundra_4.Decor.Exterior x4 | the Exterior panels are zone wall panels: every collider exact |
| 06 | blue lamp post | `Blue_Torch_Standing` | 10: test, kit, Tundra_4.BossGate x2 (1.7), BossArenas.Tundra.Decor.Props x6 (1.5 .. 2.0) | Head (invisible), FirePoint, Ember; its lights are the zones' Fire_Torch_Blue VFX parts (not touched) |

### Tundra monuments remake status (Agent B, 2026-10-22)

Builders: `tools/PropsTundraMonuments.luau` (`DevTools.PropsTundraMonuments`, on DevTools.PropsTundraGates, which now
exports `TB` / `GS`); kit rows in `tools/PropsTundraMonumentsData.luau`. Agent A's monument facets
(`tundra_mon__pillar_shaft` / `knight_armor` / `brazier_dome`) were not used: all 6 are built from parts (the pillar
shaft as a bevelled 8-sided prism); the crystals reuse the gate 4 spire solid and the tundra shards.
Rules: tools/SyncMapProps.luau (6 monument rules; `Warm_Brazier` and `WarmBrazier`; AssetPreview.Tundra as a search
root). Collision: invisible `Collision` parts = today's colliding parts (MeshParts cloned from a source with the same
mesh and fidelity), checked part by part on every copy and with ray grids that respect CanCollide (position-tolerant
keys). Screenshots (test + game, before + after; the brazier test only): `docs/screenshots/tundra_monuments/`. Run 2 = 0.

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| 01 | ice pillar (pilot) | `tundra_ice_pillar` | 20 / 20 | 3,400 | Agent A's faceted fluted ice shaft with lighter edges, glowing cyan chevrons, a carved capital, a bevelled square base, frost crystals. Size 8.2 x 40.6 x 8.8 (within +10 %). Colliders exact on all 20 (part signatures, symmetric shafts within 0.04); 11 grids 0 differences |
| 02 | ice knight in a glass case | `tundra_ice_knight` | 12 / 12 | 4,100 | plate armour, pauldrons, a helmet with a glowing cyan visor and a plume, the gold belt with a green sash, a sword planted in front, a carved plinth; glass panes (T 0.5) in ice frames; a snow-white lid with a rim; spire crystals. Size 11.9 x 15.4 x 8.0. Colliders exact on 12; 7 grids 0 differences; the 2 BossGate copies synced, the BossGate (36 children) and its prompt unchanged |
| 03 | ice throne | `tundra_ice_throne` | 4 / 4 | 4,400 | crystal spikes, a tall back with a thin Neon diamond inlay, armrests, a pale blue cushion, a stepped base, frost. Seat top stays y 3.6. Size 13.2 x 18.5 x 8.5. Colliders exact on 4; 2 grids 0 differences |
| 04 | yellow dome pedestal | `tundra_dome_brazier` | 6 / 6 | 2,700 | a bevelled stone pedestal, a ribbed golden dome with a rim, framed warm-glow windows, snow on the rim; Embers + FirePoint exact; the 4 arena copies keep their `Fire` part and its light (b0.9 r24 #FFB85A) and their scale 1.3. Size 9.2 x 9.4 x 9.2. Colliders exact on 6; grid 0 differences |
| 05 | glass frame with a checkmark | `tundra_glass_frame` | 10 / 10 | 2,400 | today's posts as bevelled ice pilasters (inner bead, base, capital), the bottom rail as a base block, the top rail as a lintel with dentils, a soft snow cap and icicles; 4 corner bosses with diamond studs; the pane as ice glass (T 0.4) with 3 reflection streaks; the checkmark carved in raised light ice with a glowing cyan core line. Size 20.3 x 24.5 x 3.3. Colliders exact on 10 (the 4 Exterior wall panels too); 9 grids 0 differences |
| 06 | blue lamp post | `tundra_blue_lamp` | 10 / 10 | 1,400 | a bevelled 2-tier octagonal slate base with a snow ring, a slim octagonal post with 2 steel bands and 2 scroll brackets, a glass lantern (steel plate, 4 posts, 4 cyan glass panes, a pyramid roof with a ring and a snow cap, tiny icicles); Head, FirePoint (0 moved on all 10) and Ember exact; the Fire_Torch_Blue lights not touched. Size 1.8 x 7.1 x 1.8. Colliders exact on 10; 3 grids 0 differences |

Totals: 62 copies replaced (6 templates). Triangles of the new geometry, all copies: about 189,000 (pillar 68k, knight
49k, throne 18k, brazier 16k, frame 24k, lamp 14k), of which the copies in the zones, the BossGate and the boss arena
(without the kits and test copies) about 152,000.

### Tundra props (owner, "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Props and decor", 2026-10-22): inventory before the remake (read from Studio)

Images: `docs/Tundra_Images/04_Props_and_Decor/`. Recipe: docs/prop_texture_guide.md section E10. Test =
`workspace._Staging.AssetPreview.Tundra.<Kit>`, kit = `ServerStorage.MapAssets.Tundra.<Kit>`; the kits' parts are kept as
rows in `tools/PropsTundraPropsData.luau`. Every copy is the kit at a Model scale (checked part by part, within 0.001;
the 4 Tundra_4 racks' 2 Rails are 7.88 long instead of 7.8). No kit or copy has a script, prompt, ClickDetector, Seat,
light, tag, attribute or nested MapProp, and no script names them: **no function to keep** (no fishing prompt).
Backups (every copy): `BackUP_Files/old_props_2026-10-22_pre_tundra_props/<propId>.rbxm` (6 files); the main agent's full
backup `..._before_tundra_props`.

| # | owner's object | kit | copies | colliders today |
|---|---|---|---|---|
| 01 | frozen skeleton in ice | `Bone_Pile_Ice` (18 parts, 7.3 x 3.2 x 5.8) | 11: test, kit, Tundra_3 x3 (one at y 8 on a ledge), Tundra_4 x1, BossArenas.Tundra.Decor.Props x5 (1.5) | the 16 bone parts (Skull, Jaw, 2 EyeSocket, 3 Bone, 7 BoneEnd, 3 Rib); the Ice mesh only queries, the Snow mesh nothing |
| 02 | ice fishing hole | `FishingHole` (12, 9.1 x 4.1 x 7.4) | 6: test, kit, Tundra_2 x4 (on the frozen lake, y 0.14) | Seat, 3 Legs, Fork, Bucket (the owner's "barrel": a plain #5C626E cylinder, not the barrel MapProp); Rim, Water, Rod, Line, 2 Fish do not collide |
| 03 | sled | `Sled_A` (16, 3.6 x 2 x 10.4) | 5: test, kit, Tundra_1 / 2 / 3 x1 | 2 Runners, 2 RunnerTips, 4 Legs, 2 Cross, 5 Slats (not the Rope) |
| 04 | snowman with the gray hat | `Snowman_B` (11, 6.7 x 8 x 3.7; gray bucket hat #5C626E tilted 8 deg, purple scarf #BAAAEC) | 6: test, kit, Tundra_1 x3, Tundra_2 x1 | the 3 balls |
| 05 | snowman with the blue hat | `Snowman_A` (12, 8.4 x 10 x 4.5; top hat #4E566E, 2 buttons) | 6: test, kit, Tundra_1 x4 | the 3 balls |
| 06 | "ice drying rack" = a frozen weapon rack | `Weapon_Rack_Frozen` (16, 8 x 8.9 x 3.4; sword, axe, spear, 2 Ice meshes, 3 icicles) | 10: test, kit, Tundra_4 x4 (1.2), BossArenas x4 (1.3) | Base, 2 Posts, 2 Rails |

### Tundra props remake status (Agent B, 2026-10-22)

Builders: `tools/PropsTundraProps.luau` (`DevTools.PropsTundraProps`, on DevTools.PropsTundraGates); Agent A's E10 facets as
convex solids in `tools/PropsTundraPropsSolids.luau` (written by `tools/tundra_facets_to_solids.py <root> props`; the
buildings / gates outputs regenerate byte-identical). Rules: tools/SyncMapProps.luau (6 rules). Collision: invisible
`Collision` parts = today's colliding parts, checked part by part on every copy (corner difference 0 against the kit
rows) and with ray grids that respect CanCollide on every workspace copy (0 differences). Run 2 = 0 for each.
Before evidence: 04 / 05 test + game shots in `docs/screenshots/tundra_props/`; for 01 / 02 / 03 / 06 (synced while
screen captures were denied) the owner's reference images in `docs/Tundra_Images/04_Props_and_Decor/` (test zone) and
the per-object .rbxm backups (game). After shots of 01 / 02 / 03 / 06 (test + game) are still owed.

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| 01 | frozen skeleton in ice (redone on the owner's follow-up: the plains skull-and-bones duplicated, not remodelled) | `tundra_frozen_skeleton` | 11 / 11 | 3,600 (2,400 in unions + the 3 plains meshes) | the PLAINS `skull_bones` MapProp's 3 MeshParts (Bones: the skull with the sad face, 2 crossed bones with knobbed ends, the curved rib cage; Aged; Sockets: the dark eyes) cloned from its template, compacted x 0.76 round the ground point under today's skull (moved 0.15 right, 0.15 to the front) and frozen in Agent A's faceted translucent ice block (Glass T 0.4, light edges, darker inner facets), the block scaled x 1.2 / y 1.05 / z 1.15 and moved 1.0 left, 0.4 to the front to hold the pose (about 3 % of the meshes' vertices outside it); 5 thin glass ice lumps over the bits that stick out; 16 rime flakes on the bones' tops; 4 frost patches on the ice; a soft snow cap (0.25) toward the back; 3 small icicles under the block's upper edges; Agent A's shards at 2 feet. Size 6.58 x 3.48 x 6.00 (+8.75 % height, +3.4 % depth). Colliders: today's 16 bone parts exactly on all 11; 5 grids 0 differences; the meshes collide and query nothing |
| 02 | ice fishing hole | `tundra_fishing_hole` | 6 / 6 | 6,900 (+ the nested barrel) | 10 cut ice slabs (0.38, 3.0 -> 3.7) with a dark inside band; deep water (Glass T 0.15 #1E5FA8, water_lines Ripples, PropFX `tundra_fishing_hole` Scroll on `Water`) 0.35 under the rim top; snow round the outside and on 2 slabs; the stool as 3 round-cut planks with nails on 2 battens, 3 tapered legs, 2 rungs; the `barrel` MapProp nested at today's Bucket at scale 0.4 (the barrel rule now finds 49 barrels, 43 + 6, all up to date; its 3 colliders add 0.2 over today's 1.4 Bucket, which stays the invisible collider); a forked stick, a 2-piece rod with a ferrule, 3 guides and a reel; today's Line with a red / white bobber and a ripple ring; today's 2 fish as fish (belly, tail fin, eyes) on the slabs; 2 crossed planks with nails. Size 9.43 x 4.09 x 7.95 (+7 %). Colliders 6 / 6 exact; 5 grids 0 differences (the nested barrel set aside) |
| 03 | sled | `tundra_sled` | 5 / 5 | 4,700 | curved runners (straight runner + a 3-segment curl 35 / 70 / 110 deg to a scroll) with a dark-steel shoe up the curl and 4 rivets a side; a front dowel; chamfered legs; cross bars with notch lines and nails; an X brace a side; today's 5 slats (0.08 gaps, rounded ends) on 2 battens, 2 nails per slat per batten; today's rope as 2 twisted strands tied to the dowel with a knot, a frayed tuft; snow on the back of the slats and the curls. Size 3.82 x 2.15 x 10.59 (+7.5 % height). Colliders 15 / 15 exact; 4 grids 0 differences |
| 04 | snowman with the gray hat (pilot) | `tundra_snowman_gray` | 6 / 6 | 5,800 | Agent A's snowballs (the shaded one on the #CEDEF6 ball) with packed-snow collars, 2 drifts at the foot; a gray #5C626E top hat (crown 1.5, brim 2.3, #3E4C66 band, snow cap) at today's 8 deg tilt; a knitted scarf (2 rolled turns, #9A8ACC stripes, a knot, 2 striped tails with a fringe); Agent A's carrot (0.86), chunky coal eyes, a 5-pebble smile, 3 coal buttons; stick arms with 2 twigs and a fork. Size 6.70 x 8.06 x 3.72. Colliders 3 / 3 exact; 5 grids 0 differences |
| 05 | snowman with the blue hat | `tundra_snowman_blue` | 6 / 6 | 5,300 | the same recipe; today's #4E566E top hat with a blue #3468B4 band and a 0.1-proud brim edge; today's 2 buttons as coal lumps 0.4 and a third on the base ball (E10's y 3.6 is inside the base ball); no scarf (none today). Size 8.45 x 10.18 x 4.51. Colliders 3 / 3 exact; 5 grids 0 differences |
| 06 | frozen weapon rack ("ice drying rack") | `tundra_ice_rack` | 10 / 10 | 5,000 | chamfered posts with pyramid caps and snow; today's rails + a third crossbar at y 3.6 (no collider), 2 pegs and a rope tie at every joint; rime and a snow cap on the top rail; today's Base as 4 planks with nails on 2 battens, a snow strip; Agent A's 2 ice blocks; the spear (bevelled blue head on a socket) with a blue swallow-tail pennant tied under the head (the owner's "blue flag"); the axe (bevelled light edge) with a gray cloth wrapped under the head and hanging (the owner's "cloth"); the sword frozen in the ice (fuller lines, gold guard); today's 3 icicles + 4 and a small cluster. Size 8.54 x 8.56 x 2.96. Colliders 5 / 5 exact (from the kit: the 4 Tundra_4 copies' rails were 0.04 longer per end past the posts, now flush, as approved); 5 grids 0 differences |

Totals: 44 copies replaced (6 templates). Triangles of the new geometry, all copies: about 221,000 (skeleton 40k, fishing
hole 42k, sled 23k, gray snowman 35k, blue snowman 32k, rack 50k), of which the copies in the zones and the boss arena
(without the kits and test copies) about 158,000.

### Swamp huts (owner, "CURSED SWAMP PROP IMPROVEMENT - Buildings and huts", 2026-10-24): inventory before the remake (read from Studio)

Images: `docs/Swamp_Images/01_Buildings_and_Huts/`. Recipe: docs/prop_texture_guide.md section F. Test =
`workspace._Staging.AssetPreview.Swamp.<Kit>` (this row is now a SyncMapProps search root), kit =
`ServerStorage.MapAssets.Swamp.<Kit>`; the kits' parts are kept as rows in `tools/PropsSwampHuts.luau` (Data).

- **Copies:** every copy is the kit at Model scale 1. The village copies are renamed `Cabin_<n>`; the rules match them by
  number under `Swamp_3.Decor.Village`.
- **Functions:** no kit or copy has a script, prompt, ClickDetector, light, tag, attribute or nested MapProp, and no
  script names them. The glow points are the Neon `Window` and `Lantern` parts.
- **Ladders:** the rails and rungs are CanCollide and CanQuery false. The ladders are decorative today (not climbable)
  and stay that way.
- **Backups:** `BackUP_Files/old_props_2026-10-24_pre_swamp_huts/<propId>.rbxm` (2 files); the main agent's full backup
  `..._before_swamp_huts`.

| # | owner's object | kit | copies | colliders today |
|---|---|---|---|---|
| 01 | stilt hut, green roof | `Stilt_Cabin_A` (26 parts, 18 x 29.7 x 20.5; Window Neon #FFC460, Lantern Neon #FFC460) | 6: test, kit, `Zones.Swamp.Swamp_3.Decor.Village.Cabin_1 / 3 / 5 / 7` | 18: 4 Stilts, Deck, Body, Door, lintel, ridge, 2 Roof planes, 4 gable Facets (wedges), Chimney, Window, WindowFrame. On Cabin_1 / 5 / 7 the 2 Roof planes are 0.05 apart along Z (left z 0.95, right z 1.05); on Cabin_3 the right plane is 13.6 deep |
| 02 | witch hut, purple hat | `Stilt_Cabin_B` (24 parts, 14.3 x 36.7 x 18.7; Window Neon #AA50FF, Lantern Neon #FFC460) | 5: test, kit, `Village.Cabin_2 / 4 / 6` | 15: 4 Stilts, Deck, Body, Door, lintel, brim + 4 hat tiers (Roof), Window, WindowFrame. The front diagonal brace, the lantern and its bracket, and the ladder do not collide |

### Swamp huts remake status (Agent B, 2026-10-24)

- **Builder:** `tools/PropsSwampHuts.luau` (`DevTools.PropsSwampHuts`, on DevTools.PropsTundraBuildings). BASE = the jungle
  `stilt_hut` recipe (`tools/PropsJungleBuildings.luau`) and its vines.
- **Moss:** the mats and drapes were reworked on the main agent's request. They are soft rounded faceted lumps: a dark
  #3F7A2C base, a smaller and lighter #5B852D top layer, and thin drips.
- **Rules:** 2 in tools/SyncMapProps.luau, plus the swamp test row as a search root.
- **Collision:** invisible `Collision` parts are today's colliding parts. Checked part by part on every copy (worst
  corner 0.0016, the float drift of the old copies) and with CanCollide-respecting ray grids (6 directions, 0.5 step) on
  every workspace copy: 0 differences.
- **Glow:** today's Window and Lantern Neon in today's colours. No light was added (the main agent's decision). Run 2 = 0
  for both.
- **Shots:** `docs/screenshots/swamp_huts/<nn>_<name>_{test,game}_{before,after}.jpg` (game = Village.Cabin_7 / Cabin_6).

| # | object | MapProps id | replaced | triangles per copy | notes |
|---|---|---|---|---|---|
| 01 | stilt hut with the green roof (pilot) | `swamp_stilt_hut` | 6 / 6 | 34,400 | Today's 4 splayed stilts are thick 8-sided logs: an iron band, rope ties under the deck, an algae band and a mud collar at the water line, X braces with rope on 3 sides and a low front rail. The deck is rotten planks (2 broken, with splinters) on rim beams. The crooked body has rotten plank walls (cracks, damp darker feet, lichen) on a dark core, with corner posts, a sill, a top plate and a foundation beam. The 4 gable facets have board joints. The 2 roof planes carry overlapping shingles: 3 tones of today's greens, some mossy, a few crooked or missing, plus moss mats, a mushroom cluster, hanging moss and vines at the eaves. The ridge is a timber with 3 rope lashings; the chimney is stone courses with a cap, a flue and moss. The porthole keeps today's glow and frame inside an iron ring with rivets. The door is planked with 3 iron straps, pintles and a ring handle, in a chamfered frame. Also: today's lintel with nails, the lantern in an iron frame on today's bracket, ladder rails and round rungs with rope (not colliding, as today), and mushrooms at 2 stilt feet and on the deck. Size 18.39 x 30.01 x 20.74 (+2.2 / +1.2 / +1.4 %). Variants: Cabin_1 / 5 / 7 `RoofSplit`, Cabin_3 `RoofWide` (they switch the matching invisible roof colliders on). Colliders 18 / 18 on every copy; 5 grids 0 differences |
| 02 | witch hut with the purple hat | `swamp_witch_hut` | 5 / 5 | 29,000 | Same recipe: stilts, deck, plank body, strapped door, lantern (the hanging yellow tag), ladder. Today's front diagonal brace is a log with rope. The eye window keeps today's #AA50FF glow whole, in an iron ring under an arched wooden brow. The hat: today's brim as a rounded (octagonal) chamfered slab with moss and hanging moss; a dark band with a brass buckle round the crown; today's 4 crooked tiers clad in 3 rows of purple shingles (today's 2 purples, kicked-out butts, corner trims, a #7A2BC8 lip line, a shingled top); a bent tip of 3 tapering segments curling on from the top tier. Also 3 potion bottles and a straw broom on the deck, and mushrooms. Size 14.91 x 37.18 x 19.30 (+4.0 / +1.3 / +3.2 %). Colliders 15 / 15 on every copy; 4 grids 0 differences |

Totals: 11 copies replaced (2 templates). Triangles of the new geometry: about 351,000 over all copies, of which the 7
village copies about 225,000.

### Docks (owner, "PLAINS + CURSED SWAMP PROP IMPROVEMENT - Docks and platforms", 2026-10-24): inventory before the remake (read from Studio)

Images: `docs/Swamp_Images/02_Docks_and_Platforms/`. The 05 / 06 pictures were only in `REMAKE OBJECT/...`; they were
copied there. Recipe: docs/prop_texture_guide.md F3. The kits' parts are kept as rows in `tools/PropsDocks.luau`
(Data).

- **Rules:** no earlier rule claimed any of these kits; 6 rules were added.
- **Functions:** no kit or copy has a script, prompt, light, tag or attribute (only DevTools.MapAudit names them).
- **Scale:** every copy is Model scale 1.
- **Backups:** `BackUP_Files/old_props_2026-10-24_pre_docks/<propId>.rbxm` (6 files); the main agent's full backup
  `..._before_docks`.

| # | owner's object | kit | copies | walk top | notes |
|---|---|---|---|---|---|
| 06 | plains plank platform, round posts | `Common.Dock_Section` (16 parts) | 12: test, kit, Plains_1.Decor.Pond, Plains_2.Decor.Docks x5, Hub.Decor.Village `Dock_Harbor` x2 + `Dock_AFK` x2 (renamed) | y 5.0 | the 10 game copies raise 3 planks +0.06 each, in 7 different patterns |
| 05 | plains deck with rails | `Common.Bridge_Wood_Section` (15) | 2: test, kit | y 1.0 | |
| swamp 01 | large dock platform | `Swamp.Walkway_Section` (13) | 11: test, kit, Swamp_1.Decor.Walkways x9 | y 2.0 | the 9 game copies raise 2-5 planks and some stringers by +0.05 .. +0.15, in 8 patterns |
| swamp 02 | small dock platform | `Swamp.Walkway_Corner` (9) | 2: test, kit | y 2.0 | |
| swamp 03 | dock with the ramp | `Swamp.Stilt_Platform` (16) | 6: test, kit, Swamp_3.Decor.Village x4 | y 6.0 + the ramp | the village copies (15 parts) have no side rail where a rail dock joins them: 10034 / 9930 at x -7.4, 9966 / 10070 at x +7.4 |
| swamp 04 | dock with rails | `Swamp.Rope_Bridge_Swamp` (15, = Bridge_Wood_Section recoloured) | 4: test, kit, Village x2 (at y 5, joining the stilt platforms, top y 6.0) | y 1.0 | |

### Docks remake status (Agent B, 2026-10-24)

- **Builder:** `tools/PropsDocks.luau` (`DevTools.PropsDocks`, on DevTools.PropsSwampHuts, which now exports its TB / B2
  / H / M tables). One `build()`; the swamp pieces are the plains build in the swamp style.
- **Rules:** 6 in tools/SyncMapProps.luau. 06 also matches the hub's renamed Dock_Harbor / Dock_AFK. The ramp dock
  has a variant function `rampDockOpenSide`.
- **Per-copy walk colliders:** for 06 and swamp 01, `PD.prepWalk()` put each copy's own planks (and 01's stringers),
  invisible, into a `WalkCollision` folder (MapPropKeep) before the first sync. Sync keeps it on each copy; no template
  has one.
- **Ramp dock variants:** `OpenLeft` (Village 10034 / 9930) and `OpenRight` (9966 / 10070) hide that side's rail
  union (Transparency 1, no shadow) and switch its collider off.
- **Collisions:** CanCollide-respecting ray grids (6 directions, 0.5 step, incl. walk heights from above) on all 31
  workspace copies: **0 differences**.
  - The first sync of the ramp dock showed differences. A part-by-part check against the deserialized backup found
    the missing village side rails, so the variants were added and the dock re-synced.
- **Sync:** run 2 = 0 for all 6. Rebuilding all 6 templates from the final source gives the same fingerprints.
- **Shots:** `docs/screenshots/docks/` (05 and swamp 02 have only test shots: no game copy).

| # | object | MapProps id | replaced | triangles per copy | size (kit) | notes |
|---|---|---|---|---|---|---|
| 06 | plains plank platform (pilot) | `plains_plank_dock` | 12 / 12 | 5,600 | 12.88 x 6.58 x 20.12 (12.6 x 6.2 x 20.16) | boards with joints, nails, cracks and knots; round capped piles with rope and iron bands; bolted stringers; X braces with rope; grass. Walk colliders kept per copy |
| 05 | plains deck with rails | `plains_rail_deck` | 2 / 2 | 4,900 | 17.25 x 5.60 x 20.00 (16 x 5.35 x 20) | boards; capped square posts with iron bands; bevelled rails in iron U-brackets; grass along the edges |
| swamp 01 | large dock platform | `swamp_dock_large` | 11 / 11 | 9,800 | 15.00 x 4.93 x 20.01 (14.04 x 4.65 x 20.05) | 06's recipe in swamp style: rotten boards, cracks, algae stains, algae and mud at the post feet, moss, hanging moss, mushrooms. Walk colliders kept per copy |
| swamp 02 | small dock platform | `swamp_dock_small` | 2 / 2 | 7,400 | 15.02 x 4.50 x 12.70 (13.8 x 4.2 x 12.11) | as 01 |
| swamp 03 | dock with the ramp | `swamp_ramp_dock` | 6 / 6 | 10,500 | 17.39 x 11.47 x 29.70 (16.31 x 11.19 x 28.35) | round stilts with caps and rope; rails in brackets (side rails split for the variants); ramp boards flush with today's slope; 2 lantern hooks at the back; a flat mud patch at the ramp foot (0.1 max). Variants OpenLeft x2 / OpenRight x2 |
| swamp 04 | dock with rails | `swamp_rail_dock` | 4 / 4 | 5,500 | 17.31 x 5.52 x 20.00 (16 x 5.35 x 20) | 05's recipe in swamp style; 2 lantern hooks on the middle posts, pointing out sideways |

Totals: 37 copies replaced (6 templates). Hub parts 5,143 -> 5,175.

### Swamp gates (owner, "CURSED SWAMP PROP IMPROVEMENT - Gates and entrances", 2026-10-24): inventory before the remake (read from Studio)

Images: `docs/Swamp_Images/03_Gates_and_Entrances/`. The game copies' parts are kept as rows in
`tools/PropsSwampGatesData.luau` (`DevTools.PropsSwampGatesData`). Its `KitRows` hold the colliders where the kit and
test copies differ from the game copy.

- **Copies:** each gate has 3: the kit (`ServerStorage.MapAssets.Gates`), the test copy
  (`_Staging.AssetPreview.Swamp`) and the game copy (`Zones.Swamp.Swamp_1..4`). All are Model scale 1.
- **Rules:** no earlier rule claimed them; 4 rules were added.
- **Functions:**
  - no scripts or prompts in the models (ZoneService adds the GatePrompt at run time);
  - attributes: `ZoneId` (01), and `SubZoneId` + `BarrierDecorIsChildOfBarrier` (02-04);
  - 2 SurfaceGuis on each game copy (the NameSign / PriceSign);
  - 2 lantern PointLights on 01, 02 and 04.
- **Backups:** `BackUP_Files/old_props_2026-10-24_pre_swamp_gates/<propId>.rbxm` (4 files); the main agent's full
  backup `..._before_swamp_gates`.

| # | owner's object | kit | parts | colliding | glows (Neon / lights) | size | notes |
|---|---|---|---|---|---|---|---|
| 01 | mushroom vine arch | `EntryArch_Swamp` -> `Swamp_1.EntryArch` | 47 (4 meshes) | 15 | 4 / 2 | 41.92 x 28.19 x 9.97 | the raven = 8 "Part" rows; the kit and test left Beam is 1.8 thick (the game's 1.9) |
| 02 | wooden gate with dead trees | `Gate_Swamp_2` -> `Swamp_2.Gate` | 54 (6 meshes: 2 trees, mushrooms) | 15 | 4 / 2 | 56.97 x 37.05 x 12.11 | the door is the Barrier with 11 parts under it |
| 03 | rock barricade | `Gate_Swamp_3` -> `Swamp_3.Gate` | 52 (8 meshes: 4 rocks, 2 moss, mushrooms) | 12 | 6 / 0 | 113.71 x 42.15 x 30.58 | invisible Barrier; the barricade, incl. the 5 magenta Buds, sits under it and hides when the gate opens |
| 04 | skull palisade | `Gate_Swamp_4` -> `Swamp_4.Gate` | 49 | 18 | 12 / 2 | 64.41 x 32.49 x 13.54 | the door is the Barrier with 23 parts under it; the kit and test top Lintel sit at z 0 (the game's -0.05), and their 8 Trunks are tilted up to 0.0005 off the game's |

### Swamp gates remake status (Agent B, 2026-10-24)

- **Builder:** `tools/PropsSwampGates.luau` (`DevTools.PropsSwampGates`, built on DevTools.PropsSwampHuts' TB / B2 / H
  / M). It reuses the plains entry arch / palisade, the tundra palisade, and the jungle barricade + rock recipes.
- **Rules:** 4 in tools/SyncMapProps.luau (`EntryArch_Swamp`, `Gate_Swamp_2..4`, plus a match on the zone copies).
  01 and 04 have a variant function (`swampArchKit`, `swampGate4Kit`) that gives the kit and test copies Variant
  `Kit`, which switches to their own colliders.
- **Gate contract:**
  - the Barrier is the PrimaryPart and keeps its collision;
  - the door / barricade decor and any glow on the door sit under the Barrier;
  - `BarrierDecorIsChildOfBarrier` = true;
  - SubZoneId / ZoneId and the sign GUIs are kept.
- **Kept exactly:**
  - the 01 raven: 8 / 8 parts on all 3 copies;
  - the ghost mushroom meshes and their glow;
  - the lantern cores and PointLights;
  - the magenta glows: the 03 orbs, the 04 skull eyes and rune crosses;
  - the 04 Neon shelf mushrooms;
  - the signs.
- **Collisions:**
  - Visible pieces never collide.
  - Today's colliding parts are invisible "Collision" copies. The 02 tree meshes and 03 rock meshes collide through
    their own Hull mesh copies.
  - CanCollide-respecting ray grids (6 directions, 0.5 step), old vs new on every copy: **0 differences**.
  - On 04, an extra grid shifted off the 0.5 lattice was run against the deserialized backup. It found that the kit
    and test trunks are 0.0005 off the game's; Variant `Kit` now carries those 8 trunks too.
- **Sync:** run 2 = 0 for all 4. Full dry run: 154 templates / 1738 copies, 0 to replace.
- **Shots:** `docs/screenshots/swamp_gates/` (before / after, test and game, for each gate).

| # | object | MapProps id | replaced | triangles per copy | size (before) | notes |
|---|---|---|---|---|---|---|
| 01 | mushroom vine arch (pilot) | `swamp_vine_arch` | 3 / 3 | 17,300 | 41.92 x 29.02 x 9.97 (41.92 x 28.19 x 9.97) | rotten 8-sided logs with iron bands, rivets and rope at every joint; bent roots into mud bases; beams with moss mats and hanging moss; NameSign in a rotten frame; curtains of leafy vines; lanterns in iron frames with chain links. Variant Kit (left beam) |
| 02 | wooden gate with dead trees | `swamp_tree_gate` | 3 / 3 | 20,400 | 58.01 x 37.24 x 12.34 (56.97 x 37.05 x 12.11) | crooked stakes with points, iron bands, rope, mud; the dead trees keep today's meshes as trunks, with roots, bark shelves, twisted branches, hanging moss and vines placed on the probed trunk surface; plank double door with straps, strap hinges and ring handles under the Barrier |
| 03 | rock barricade | `swamp_rock_gate` | 3 / 3 | 19,000 | 113.71 x 40.96 x 30.58 (113.71 x 42.15 x 30.58) | 4 faceted convex rocks on the measured hulls of today's meshes, with moss caps and hanging moss; dark logs with rope; under the Barrier: crossed 8-sided branches lashed with rope, bone thorns, and the 5 orbs kept in iron rings. Blocking and opening unchanged |
| 04 | skull palisade | `swamp_skull_gate` | 3 / 3 | 13,000 | 64.61 x 33.28 x 14.71 (64.41 x 32.49 x 13.54) | crooked rotten planks with pointed tops, iron bands, rope; broken stubs; support beams with foot plates; door boards in place (the runes stay visible), iron bands, a rounded bone skull (brow, cheekbones, teeth; eyes kept) with a round iron ring. Variant Kit (lintel + 8 trunks) |

Totals: 12 copies replaced (4 templates).

### Swamp trees (owner, "CURSED SWAMP PROP IMPROVEMENT - Trees and nature", 2026-10-25): inventory before the remake (read from Studio)

Images: `docs/Swamp_Images/04_Trees_and_Nature/`. Today's kit parts are kept as rows in
`tools/PropsSwampTreesData.luau` (`DevTools.PropsSwampTreesData`), and the far form is read from its first copy.

- **Copies:** every copy is its kit at a Model scale (0.6 to 2.5). Their colliders equal the kit rows x scale exactly,
  except the 40 far mangroves, whose trunk blocks differ by up to 0.001 per copy.
- **Rules:** no earlier rule claimed these kits; 7 rules were added. SwampTree_A is split into near (`filter`) and far
  (`match`: `Swamp_1.Decor.Backdrop`).
- **Functions:** none. No script, prompt or touch handler; src/ never names these kits. PropFX has no Sway entry, so
  the vine curtain is static today and stays static.
  - Hanging_Moss_A has the attribute Height = 8 (kept).
  - One BossArenas Rotten_Trunk_Glow (scale 1.25) has a PointLight under its SapPool (#8CFF5A, range 30, brightness
    1.2, no shadows); the kit has none.
- **Odd copy:** one vine curtain (Swamp_4 Dressing at 10008.4, 25, 808) has one strand 0.3 thick and 0.025 higher. It
  is visual only and takes the template.
- **Ground:** at local y 0 to 0.5 under the near trees; the far trees sit 6.5 deep in the mud bed.
- **Backups:** `BackUP_Files/old_props_2026-10-25_pre_swamp_trees/<propId>.rbxm` (7 files); the main agent's full
  backup `..._before_swamp_trees`.

| # | owner's object | kit | copies | parts today | colliding | glow | size |
|---|---|---|---|---|---|---|---|
| 01 | mangrove tree A | `SwampTree_A` | 40: test, kit, Swamp_1 x25, Swamp_3 x13 | 12 (2 canopy meshes, 3 moss strips) | 7 (5 roots, 2 trunk) | - | 26 x 35.53 x 26 |
| 01 far | the same, far | `SwampTree_A` in `Swamp_1.Decor.Backdrop` | 40 (scale 1.5-2.4) | 4 (canopy + trunk, greyed colours) | 2 | - | 26 x 28 x 26 |
| 02 | mangrove tree B | `SwampTree_B` | 27: test, kit, Swamp_1 x16, Swamp_3 x9 | 16 (3 canopies, 4 strips) | 9 (6 roots, 3 trunk) | - | 35 x 42.13 x 30 |
| 03 | dead tree with a face | `TwistedTree_A` | 34: test, kit, Swamp_1 x2, Swamp_2 x20, Swamp_3 x10 | 14 (2 Eye, 2 Pupil, 2 Mouth) | 8 | 2 Neon Pupils #FFE860 | 18.68 x 28.16 x 5.28 |
| 04 | twisted dead tree, hollow | `TwistedTree_C` | 47: test, kit, Swamp_1 x8, Swamp_2 x29, Swamp_3 x7, BossArenas x1 | 9 (Knot = the hollow, 1 MossStrip) | 7 | - | 17.55 x 22.07 x 5.27 |
| 05 | hanging vines curtain | `Hanging_Moss_A` | 36: test, kit, Swamp_1-4 x25, BossArenas x9 | 6 (a bar, 5 strips) | 0 | - | 6.5 x 8.15 x 0.8 |
| 06 | hollow magic stump | `Rotten_Trunk_Glow` | 4: test, kit, BossArenas.Swamp x2 | 15 (Trunk mesh, 4 Root, 2 branches, 5 Sap, SapPool, 2 crystals) | 7 (mesh Hull, 4 roots, 2 branches) | 5 Sap + SapPool #8CFF5A, 2 crystals #78FFD2 (Neon) | 18.59 x 25.25 x 18.59 |

### Swamp trees remake status (Agent B, 2026-10-25)

- **Builder:** `tools/PropsSwampTrees.luau` (`DevTools.PropsSwampTrees`, built on DevTools.PropsSwampHuts' TB / B2 / H /
  M). Every piece is cheap: 8-, 6- and 5-sided logs, 18-plane faceted blobs, folded convex leaves and part vines. Each
  tree is a few unions, all under 100 pieces.
- **Rules:** 7 in tools/SyncMapProps.luau (helper `swampBackdrop`).
- **Collisions:** today's colliding parts are invisible "Collision" copies (the stump's trunk keeps its mesh and Hull);
  the visible pieces never collide.
  - Far mangroves: the template has no colliders. Each copy keeps its own 2 trunk blocks in a `TrunkCollision` folder
    (MapPropKeep; `ST.prepFarColliders()`), because their scaled trunks differ by up to 0.001 per copy.
  - Check: every copy against its before-stash or deserialized backup, collider corners worst 0.00000. Ray grids on
    and off the 0.5 lattice on 57 copies: 0 differences.
- **Kept exactly:**
  - the 03 eyes, Neon pupils and mouth (204 checks, worst 0.00000);
  - the 04 Knot;
  - the 06 Sap strips, SapPool and 2 crystals;
  - the vine curtain's Height attribute (36 / 36);
  - the BossArenas stump's PointLight, on an invisible `SapLight` part (MapPropKeep; `ST.prepStumpLight()`).
- **Sync:** run 2 = 0 for all 7. Full dry run: 161 templates / 1966 copies, 0 to replace. Every template rebuilds from
  the final source with the same union hashes.
- **Shots:** `docs/screenshots/swamp_trees/`. 06 has test shots only: its other copies are in ServerStorage.BossArenas.

| # | object | MapProps id | replaced | triangles per copy | size (kit) | notes |
|---|---|---|---|---|---|---|
| 01 | mangrove tree A (pilot) | `swamp_mangrove_a` | 40 / 40 | 4,500 | 25.87 x 35.17 x 26.02 (26 x 35.53 x 26) | twisted 8-sided bark trunk with winding grooves, knots, moss; 5 arching prop roots of different thicknesses with mud collars; 2 layers of faceted leaf clusters (lit tops, dark wet teal undersides) with drooping leaf tips; 3 leafy vines; ferns and ghost mushrooms |
| 01 far | mangrove A, far backdrop | `swamp_mangrove_a_far` | 40 / 40 | 1,150 | 24.86 x 28.00 x 25.37 (26 x 28 x 26) | the same trunk and canopy at low detail, today's greyed colours; own colliders per copy |
| 02 | mangrove tree B | `swamp_mangrove_b` | 27 / 27 | 5,200 | 33.86 x 42.16 x 31.39 (35 x 42.13 x 30) | as 01 with 3 trunk blocks and 3 canopy layers (6 roots, 4 vines); leaf tips on the widest layer, 1 fern |
| 03 | dead tree with a face | `swamp_face_tree` | 34 / 34 | 3,350 | 19.12 x 29.46 x 5.44 (18.68 x 28.16 x 5.28) | flat-fronted lower trunk; face kept exactly and carved round: brows, cheek knobs, knotted nose, lips, dark recesses; gnarled 6-sided branches with forked twigs (clipped at today's width); short roots; moss cushions and strands |
| 04 | twisted dead tree, hollow | `swamp_hollow_tree` | 47 / 47 | 2,400 | 18.44 x 23.33 x 5.27 (17.55 x 22.07 x 5.27) | today's Knot kept with a black shadow and a bevelled bark lip (the hollow with depth); gnarled branches with twigs; a leafy vine; roots and mud collars; moss |
| 05 | hanging vines curtain | `swamp_vine_curtain` | 36 / 36 | 950 | 6.51 x 8.41 x 0.78 (6.5 x 8.15 x 0.8) | bowed bark branch with 2 moss pads and 2 rope ties; 3 flat leafy vines and 2 moss strands in today's places, lengths and tones; static, nothing collides |
| 06 | hollow magic stump | `swamp_magic_stump` | 4 / 4 | 4,100 + today's mesh | 18.59 x 26.44 x 18.59 (18.59 x 25.25 x 18.59) | today's mesh kept as the stump with bark grooves and knots on its measured surface; a bark rim, dark liquid and faint mist on top; the 5 rune strips set in carved grooves with Neon rune ticks; crystal shards; arching rim roots, crooked branches with twigs; moss and ghost mushrooms |

Totals: 228 copies replaced (7 templates).

### Swamp magic (owner, "CURSED SWAMP PROP IMPROVEMENT - Magic props and decor", 2026-10-25): inventory before the remake (read from Studio)

Images: `docs/Swamp_Images/05_Magic_Props_and_Decor/`. Today's kit parts are kept as rows in
`tools/PropsSwampMagicData.luau` (`DevTools.PropsSwampMagicData`). The spellbook kit stands at Model scale 1.6, so its
rows are stored at scale 1.

- **Copies:** every copy is its kit at a Model scale (0.85 to 2.88). The kit copy lives in `MapAssets.Swamp`, the
  test copy in `Workspace._Staging.AssetPreview.Swamp`.
- **Rules:** no earlier rule claimed these kits; 9 rules were added. Crow_A is limited to the swamp (`filter`): the 10
  Realm of the Dead crows (another biome's prop, own colour) stay as they are. Potion_Bottle_A has a Variant Purple
  (its 12 purple-liquid copies).
- **Functions:** no script, prompt, click detector or touch handler on any of the 9 kits; src/ never names them.
  - Hanging_Lantern has the attribute Height = 5. 36 of its 46 copies carry a PointLight under the Lantern
    (#FFC460, range 20, brightness 1); 3 have the attribute MapFixMoved.
  - Cauldron_Small has a SteamPoint Attachment under the Liquid; 3 copies carry a PointLight under the Liquid.
  - One BossArenas Toad_Shrine carries a light under its head.
- **Colliders:** the cauldron's colliders differ by up to 0.04 per copy and the shelves were part-resized (some 0.1
  deeper), so 01, 02, 07 and 08 keep each copy's own colliders.
- **Ravens on the gates:** swamp_vine_arch and swamp_tree_gate each carried today's raven as 8 loose parts (Crow_A at
  scale 1.3). They become a nested swamp_raven at the same pose.
- **Backups:** `BackUP_Files/old_props_2026-10-25_pre_swamp_magic/<propId>.rbxm` (9 files, plus swamp_vine_arch and
  swamp_tree_gate).

| # | owner's object | kit | copies | parts today | colliding | glow | size |
|---|---|---|---|---|---|---|---|
| 01 | frog statue altar | `Toad_Shrine` | 3: test, kit, BossArenas x1 | 17 (2 Eye, 2 BowlGlow) | 11 | Eye, BowlGlow #8CFF5A | 14 x 10.85 x 12 |
| 02 | frog totem | `Toad_Totem` | 6: test, kit, BossArenas x4 | 25 (3 toads, Mouth, Eye, Pupil x3) | 10 | 6 Pupil #8CFF5A | 6.8 x 16 x 6.4 |
| 03 | skull on a frame | `Skull_Knocker_Door` | 3: test, kit, BossArenas x1 | 11 (2 Socket, 2 Eye) | 0 | 2 Eye #AA50FF | 2.6 x 4.7 x 1.6 |
| 04 | spellbook | `Spellbook_Floating` | 26: test, kit, Swamp_3 x6, Swamp_4 x10, BossArenas x8 | 5 (Covers, Rune) | 0 | Rune #AA50FF | 3.26 x 0.83 x 2.3 (at scale 1) |
| 05 | potion bottle | `Potion_Bottle_A` | 26: test, kit, Swamp_3 x6, Swamp_4 x10, BossArenas x8 | 3 (Liquid ball, neck, cork) | 0 | Liquid #8CFF5A (12 copies #AA50FF) | 1.3 x 1.97 x 1.3 |
| 06 | hanging lantern | `Hanging_Lantern` | 46: test, kit, Swamp_1 x7, Swamp_2 x1, Swamp_3 x19, Swamp_4 x9, BossArenas x8 | 4 (Chain, 2 caps, Lantern) | 0 | Lantern #FFC460 + PointLight (36 copies) | 1.5 x 5 x 1.5 |
| 07 | cauldron | `Cauldron_Small` | 8: test, kit, Swamp_3 x4, Swamp_4 x2 | 8 (Pot ball, Rim, Liquid, 3 legs, 2 logs) | 7 | Liquid #8CFF5A (3 copies with a PointLight) | 5.16 x 5.32 x 5.16 |
| 08 | potion bookshelf | `Potion_Shelf` | 8: test, kit, Swamp_3 x4, Swamp_4 x2 | 12 (2 posts, back, 3 shelves, 6 Bottle) | 6 | 3 Bottle Neon #8CFF5A, #78FFD2, #622CA0 | 6 x 7.25 x 1.6 |
| 09 | raven | `Crow_A` | 17: test, kit, Swamp_1 x4, Swamp_2 x10, Swamp_3 x1 (+ 1 in each swamp_vine_arch / swamp_tree_gate) | 8 (body, head, beak, tail, 2 wings, 2 legs) | 0 | - | 1.4 x 2.55 x 4.09 |

### Swamp magic remake status (Agent B, 2026-10-25)

- **Builder:** `tools/PropsSwampMagic.luau` (`DevTools.PropsSwampMagic`, on DevTools.PropsSwampHuts' TB / B2 / H / M and
  PropsSwampTrees' blob / leaf). The gate ravens: `nestRaven` in `tools/PropsSwampGates.luau`.
- **Rules:** 9 in tools/SyncMapProps.luau (helpers `swampPotionPurple`, `deadCrow`).
- **Collisions:**
  - 01, 02, 07 and 08 keep each copy's own colliding parts as invisible "Collision" parts in a KeptCollision folder
    (MapPropKeep; `SM.prepColliders`).
  - 03-06 and 09 never collided and still do not.
  - Check: every copy against its before-stash, collider corners worst 0.00000. Ray grids on and off the lattice
    (altar, totem, cauldron, shelf, both gates): 0 differences.
- **Kept exactly:** every glow part (the altar eyes / bowl glow / mouth, the totem mouths / eyes / pupils, the skull
  sockets / eyes, the rune, the liquids, the lantern cores, the 6 shelf bottles); the cauldron SteamPoint; the lantern
  Height and MapFixMoved attributes.
  - Lights: 36 lantern lights, 3 cauldron lights and the BossArenas altar light sit on invisible `KeptLight_<part>`
    parts (MapPropKeep; `SM.prepLights`).
- **Gates:** the 6 gate ravens are the nested swamp_raven at today's pose. All 8 old parts are matched (worst 0.0004).
  The gate colliders, Barrier, SubZoneId / ZoneId, BarrierDecorIsChildOfBarrier, GUIs and lights are unchanged.
- **Sync:** run 2 = 0 for all. Full dry run: 170 templates / 2115 copies, 0 to replace. Every template rebuilds from the
  final source with the same fingerprint.
- **Shots:** `docs/screenshots/swamp_magic/`. 01-03 have test shots only, because their other copies are in
  ServerStorage.BossArenas.

| # | object | MapProps id | replaced | triangles per copy | size (kit) | notes |
|---|---|---|---|---|---|---|
| 01 | frog statue altar (pilot) | `swamp_frog_altar` | 3 / 3 | 6,500 | about the kit (14 x 10.85 x 12) | stepped stone blocks with joints, a carved frog-glyph frieze; a rounded stone frog (domed head, wide curved grin, pale throat pouch, round legs with webbed toes, haunches, warts); eyes, bowls, glow and light kept; moss, vines, mushrooms |
| 02 | frog totem | `swamp_frog_totem` | 6 / 6 | 7,700 | about the kit (6.8 x 16 x 6.4) | 3 rounded frog faces with wide mouths, brows, warts, lips and webbed feet; rope and iron bands; moss; a stone block base |
| 03 | skull on a frame | `swamp_skull_knocker` | 3 / 3 | 1,600 | 2.6 x 5.04 x 1.6 (2.6 x 4.7 x 1.6) | carved skull round the kept sockets and magenta eyes; an iron frame with a ring and a hook; bones and feathers |
| 04 | spellbook | `swamp_spellbook` | 26 / 26 | 630 | within +10 % | thick purple cover, gold corners, page block with lines and a curl, a red ribbon; the rune kept |
| 05 | potion bottle | `swamp_potion_bottle` | 26 / 26 | 550 | about the kit (1.3 x 1.97 x 1.3) | round glass flask round the kept glowing liquid, neck and lip, a corded cork, a label; Variant Purple (12) |
| 06 | hanging lantern | `swamp_hanging_lantern` | 46 / 46 | 900 | 1.5 x 5.18 x 1.5 (1.5 x 5 x 1.5) | iron frame with posts and pane bars, glass panes over the kept core, a 4-sided roof with a finial and a ring, 5 chain links and a ceiling plate; lights kept per copy |
| 07 | cauldron | `swamp_cauldron` | 8 / 8 | 3,100 | 5.17 x 5.54 x 5.17 (5.16 x 5.32 x 5.16) | cast iron belly (5 bands) with a riveted band, a lip ring, ring handles, claw legs; the kept liquid with bubbles and its SteamPoint; crossed bark logs with pale ends; Neon embers and coals (no light, no script) |
| 08 | potion bookshelf | `swamp_potion_shelf` | 8 / 8 | 2,200 | 6.12 x 7.71 x 1.70 (6 x 7.25 x 1.6) | capped posts, a plank back with joints, double-board shelves with lips and brackets; the 6 kept bottles with necks, corks and labels; 5 books with gold bands; thin cobwebs |
| 09 | raven | `swamp_raven` | 17 / 17 + 6 nested | 830 | 1.28 x 2.68 x 4.19 (1.4 x 2.55 x 4.09) | blue-black faceted body with a sheen, a crest, a pointed beak, eyes with a white glint, 3 layered feathers per wing, a 4-feather tail fan, legs with toes; nothing collides |

Totals: 143 copies replaced (9 templates), plus the 2 gate templates re-synced.

---

Written by Agent B (Studio builder and sync) on 2026-10-18 from the live place (Studio, Edit mode).
All sizes in studs, colours as RGB 0-255. "Rel pivot" = offset in the model's pivot space (X right, Y up, -Z front).

## Test models area ("modeles tests")

`workspace._Staging.AssetPreview.ModelsA.Lineup` (folders `Common`, `Plains`, `Hub`, `Gates`), on the ground part
`workspace._Staging.AssetPreview.ModelsA.PreviewGround`, X -3160..-2846, Z -306..142. It is the lineup of the
BuildKit kit (`ServerStorage.MapAssets.<Common|Plains|Hub|Gates>`), one copy of each kit model, at X = -3000:
seen from the hub's main spawn (`workspace.Hub.SpawnLocation`, (0, 0.9, -50), facing +Z) it is to the right
(-X). The other zone lineups (`_Staging.AssetPreview.Desert`, `.Tundra`, ... `.Void`) continue along +Z.
Most of the 20 photos were taken in this lineup (green PreviewGround); photos 01, 03, 13, 14, 18, 19 and 20 in the hub.

## Summary table (one row per model id)

Counts: Hub = `workspace.Hub`, zones = `workspace.Zones.<Zone>.<Zone>_<n>`, TEST = test area, MA = the kit copy
`ServerStorage.MapAssets`, BA = boss-arena templates `ServerStorage.BossArenas`.

| id | photo | current model (kit path) | test-area path | main-map instances | notes |
|---|---|---|---|---|---|
| fountain | 01 | `MapAssets.Hub.Fountain_A` | `Lineup.Hub.Fountain_A` | Hub 1 (`Hub.Decor.Village.Fountain_A`) | MA 1. PointLight + Attachment `WaterPoint` in `TopCrystal`. VFX `Hub.Decor.VFX.Water_Ripple` sits on its basin (separate part, keep). |
| lamp_post | 02 | `MapAssets.Common.Lantern_Post` | `Lineup.Common.Lantern_Post` | Hub 1 (AFKCorner), Plains_1 1 (Farm), Plains_2 1 (Docks), Plains_3 3 (Props) = 6 | MA 1. PointLight in `Lantern`. The 8 grey iron plaza lamps `LampPost_A` (`Hub.Decor.Props.Lamps`) are a different model, not in the photos (see "Related, not in scope"). |
| crate | 03, 12 | `MapAssets.Common.Crate_A` | `Lineup.Common.Crate_A` | Hub 9 (AFKCorner 1, Harbor 8, two of them scale 0.80), Plains_1 1, Plains_2 7 (Docks 6, PirateCamp 1), Plains_4 4, Desert_1 3, Desert_2 3, Desert_3 2, Abyss_2 9 = 38 | MA 1. Variant "sunken" in Abyss_2 (9, recoloured). Embedded variant "lidded" inside `HunterCamp` (photo 12). |
| barrel | 03, 10 | `MapAssets.Common.Barrel_A` | `Lineup.Common.Barrel_A` | Hub 9 (AFKCorner 1, Harbor 8), Plains_1 2, Plains_2 6 (Docks 5, PirateCamp 1), Plains_4 3, Desert_1 3, Desert_2 5, Desert_3 1, Volcano_1 1 = 30 | MA 1, BA 1 (`BossArenas.Plains.Decor.TrollDen`). All identical. Embedded variant "one band" inside `HunterCamp` (photo 10) and `Market_Awning_A`. |
| mallet | 03 | none: it is the armrest of a hub `Bench` | - | - | Photo 03 = the AFK corner (`Hub.Decor.Props.AFKCorner`): Crate_A, Barrel_A and the end of `Bench` (grey `FrameArmPost` + brown rounded armrest). Benches are out of scope (brief section 3). See section 3 answers. |
| egg_nest | 04 | `MapAssets.Plains.SeagullNest_Rock` | `Lineup.Plains.SeagullNest_Rock` | Plains_2 5 (Rocks) | MA 1. Toolbox rock mesh (attrs `SourceAssetId` 9682467046, `SourceCreator` "Proudism": keep). |
| rowboat | 05 | `MapAssets.Plains.Rowboat_Wreck` | `Lineup.Plains.Rowboat_Wreck` | Hub 1 (Harbor), Plains_2 1 (Docks), Abyss_2 4 (scale 1.23-1.48, recoloured) = 6 | MA 1. Boat + oar are loose parts of ONE model (Oar, OarBlade). Hub/Plains copies have `Side` 9.1 long instead of 9.0 (negligible). |
| minecart | 06 | `MapAssets.Plains.Minecart_A` | `Lineup.Plains.Minecart_A` | Plains_4 2 (Mine) | MA 1. Toolbox meshes (attrs SourceAssetId/SourceCreator: keep). |
| skull_bones | 07 | `MapAssets.Plains.Bone_Pile_A` | `Lineup.Plains.Bone_Pile_A` | Plains_4 8 (Cavern), Abyss_3 8 (scale 1.54-2.34, recoloured) = 16 | MA 1, BA 12 (Plains TrollDen 7 scale 1.01-1.27, Jungle 3, Volcano 2 scale 1.2-1.3). |
| scarecrow | 08 | `MapAssets.Plains.Scarecrow_A` | `Lineup.Plains.Scarecrow_A` | Plains_1 1 (Farm) | MA 1. Swamp has its own `Scarecrow_Swamp` (different model, out of scope). |
| clam_pearl | 09 | `MapAssets.Plains.Shell_A` | `Lineup.Plains.Shell_A` | Hub 8 (`Hub.Decor.Nature.Beach`, scale 0.80-1.08), Plains_2 21 (Small, scale 0.80-1.29) = 29 | MA 1. All parts CanCollide false, no shadow. |
| laundry_rack | 11 | embedded in `MapAssets.Plains.HunterCamp` (parts `Rack` x5 + `Hide` x2) | `Lineup.Plains.HunterCamp` | Plains_3 1 (`Decor.HunterCamp.HunterCamp`) | MA 1. HunterCamp (Toolbox base, attrs kept) also holds the photo-12 crate, the photo-10 barrel, a tent and a campfire (PointLight + `FirePoint`; the Plains_3 copy has no PointLight). |
| anvil_forge | 13 | embedded in the weapon stall (`Hub.WeaponShop`: Forge x2, Chimney, Embers, Stump, Anvil x3, AnvilHorn) | `Lineup.Hub.Station_WeaponShop` | Hub 1 | MA 1 (`MapAssets.Hub.Station_WeaponShop`). `Embers` has PointLight + Attachment `FirePoint`; fire VFX = separate part `Hub.Decor.VFX.Fire_Torch` (attr StationFx) at (47.7, 4.0, -99.7). Volcano `Anvil_A` / `Dwarf_Forge` are other models. |
| weapon_stall | 14, 19 | `Hub.WeaponShop` (kit `MapAssets.Hub.Station_WeaponShop`) | `Lineup.Hub.Station_WeaponShop` | Hub 1 | Functional marker (DESIGN 12). Interact + ProximityPrompt "Open / Weapon Shop" + BillboardGui `NameTag`, `NpcSpot`, stand-in `NPC` (straw hat, green shirt, apron). NPC at runtime: `npc_blacksmith`. Kit/test copy has no NPC, no prompt. |
| lantern | 15 | embedded lantern unit (`Lantern` Neon + `LanternCap` + `LanternBase`) | `Lineup.Hub.Station_TutorialGuide` (photo 15), `Lineup.Common.Lantern_Post`, `Lineup.Hub.Station_EggStation`, `Lineup.Gates.EntryArch_Plains` (2) | Hub: TutorialGuide 1 (photo 15), EggStation 1 (hanging, no base), Lantern_Post 1; Plains_1 EntryArch 2; and inside every lamp_post (6) | No standalone lantern model exists. The photo-15 one is the ground lantern of `Hub.TutorialGuide`. |
| well | 16 | `MapAssets.Hub.Well_A` | `Lineup.Hub.Well_A` | Hub 1 (`Hub.Decor.Village.Well_A`) | MA 1. Desert_2 has its own desert well (loose parts WellWall/WellRim/WellRoof/WellWater, out of scope). |
| chest | 17 | `MapAssets.Common.Chest_A` | `Lineup.Common.Chest_A` | Hub 2 (Harbor), Plains_2 2 (Docks 1, PirateCamp 1), Plains_4 1 (Mine) = 5 | MA 1. The 5 placed copies have `Base` 4.5 wide, the kit 4.4 (negligible). Abyss `Chest_Sunken` is another model. |
| trophy_stall | 18 | `Hub.TrophyMerchant` (kit `MapAssets.Hub.Station_TrophyMerchant`) | `Lineup.Hub.Station_TrophyMerchant` | Hub 1 | Interact + prompt "Sell / Trophy Merchant" + NameTag, NpcSpot, stand-in NPC (blue shirt, red hair bun, skirt). Runtime NPC: `npc_trophy_merchant`. |
| diamond_shop | 20 | `Hub.DiamondShop` (kit `MapAssets.Hub.Station_DiamondShop`) | `Lineup.Hub.Station_DiamondShop` | Hub 1 | Interact + prompt "Open / Diamond Shop" + NameTag "Diamond Shop", NpcSpot, stand-in NPC (straw hat, green shirt), `Glow` PointLight. VFX `Hub.Decor.VFX.Diamond_Sparkle` (separate). Runtime NPC: `npc_gem_merchant`. |

Totals of placed main-map instances (Workspace, outside the test area): fountain 1, lamp_post 6, crate 38, barrel 30,
egg_nest 5, rowboat 6, minecart 2, skull_bones 16, scarecrow 1, clam_pearl 29, laundry_rack 1, anvil_forge 1,
weapon_stall 1, lantern 11 units (6 in lamp posts + 5 others), well 1, chest 5, trophy_stall 1, diamond_shop 1.
Every model exists in the test area. No model exists only in the main map, and none only in the test area.
None of these models has scripts, ProximityPrompts or values except the three stalls. No instance carries a
CollectionService tag yet. Existing attributes: `SourceAssetId` / `SourceCreator` on HunterCamp, Minecart_A,
SeagullNest_Rock (all copies); the stalls have none at model level.

## Answers to the questions of brief section 3

1. **Crate (photos 03 and 12)**: two different builds.
   * Photo 03 = `Crate_A` (4x4x4): light-orange body, dark-orange top/bottom slabs, 4 corner posts and 2
     diagonal braces (on the +-Z faces). Seen from the X side it reads as "dark frame + light panel".
   * Photo 12 = the crate inside `HunterCamp`: 2 loose parts, a 3.2 cube (214,150,92) and an overhanging lid
     3.5x0.4x3.5 (168,98,56), yaw 20. Same palette, smaller, no frame.
   * Decision: ONE improved `crate` template (it has an offset plank lid, so the lidded look is kept); the
     HunterCamp crate is an instance at scale 0.85 (same height 3.4). The 9 Abyss_2 copies keep their dark recolour
     through `Variant = "Sunken"`.
2. **Barrel (photos 03 and 10)**: two builds.
   * Photo 03 = `Barrel_A` (2 grey bands, darker lid, bulge part).
   * Photo 10 = the barrel inside `HunterCamp`: one cylinder 3.4 x 2.6 + ONE band near the top.
     `Hub.Decor.Village.Market_Awning_A` (x2) has the same one-band barrel (3.2 x 2.6).
   * Decision: ONE improved `barrel` template (3 hoops per the brief, height 4.05 like Barrel_A); the embedded ones
     are instances at their size (HunterCamp scale 0.84, Market_Awning_A 0.79).
3. **Mallet (photo 03)**: there is no mallet. The grey handle with a brown rounded head is the arm of the hub
   bench (`Bench`, AFK corner, `FrameArmPost` grey + brown armrest cap); the "orange disc" is the end of its
   seat slats. Checked with a screenshot from (-76, 4, -90) towards the AFK corner crate/barrel. Benches are out of
   scope (brief section 3) and were already polished ("sit-able benches"), so `mallet` has no instance to
   upgrade. Proposal for the main agent: drop `mallet` from the batches (18 models), or let the owner say if
   they want a real mallet prop added (that would be new content).
4. **Which NPC stands at which stall** (by hub names, `Config/NPCs.luau` + `NPCService`):
   `workspace.Hub.WeaponShop` -> `npc_blacksmith` ("Blacksmith", window Shop/Weapons);
   `workspace.Hub.TrophyMerchant` -> `npc_trophy_merchant` ("Trophy Merchant", Inventory/Trophies);
   `workspace.Hub.DiamondShop` -> `npc_gem_merchant` ("Gem Merchant", Shop/Diamonds).
   At run time NPCService destroys the stand-in `NPC` child of the marker and puts the NPC (from
   `ServerStorage.NPCs.<id>` if present - it does not exist yet - else a part-built placeholder) on the marker's
   `NpcSpot`, into `workspace.Hub.NPCs` (created at run time, not in Edit). So the stall templates must keep
   `NpcSpot`, `Interact` (prompt + `NameTag`) and the stand-in `NPC`.
5. **Photos 13, 14, 19**: the forge and anvil are loose parts of `Hub.WeaponShop` (right side, rel X 10.5); the
   counter, backboard, swords, shield, axe and tray are the stall. `anvil_forge` will become a sub-model of the
   stall.
6. **Photo 18 "glass ball"**: it is the part `CounterSkull` (Ball 1.5, ivory 240,232,208, no features) on the
   counter of `Hub.TrophyMerchant`. The back wall also has hunting trophies (BoarHead/Snout/Tusks, DeerHead +
   Antlers, horned Skull, 3 round Plaques). The brief asks for a crystal ball; since the stall sells monster head
   trophies, a real low-poly skull may fit better. Main agent / owner to choose (default: follow the brief).
7. **Labels overlap (photo 01)**: the portal labels and the "Egg Station" NameTag overlap seen from the fountain;
   not touched (brief section 6), reported only.

## Tagging (done 2026-10-18, `DevTools.SyncMapProps.tagAll()`, idempotent)

Every instance below carries the CollectionService tag `MapProp` and the attribute `MapPropId`; 214 tagged models.
Variants (attribute `Variant`): crate "Sunken" (Abyss_2 x9), rowboat "Sunken" (Abyss_2 x4), skull_bones "Pale"
(Abyss_3 x8). Templates live in `ServerStorage.MapProps.<propId>` and are never tagged.

| id | tagged | where (hub / zones / test / storage = MapAssets + BossArenas) |
|---|---|---|
| crate | 43 | 9 / 30 / 2 / 2 (incl. the 3 HunterCamp wrappers) |
| barrel | 40 | 11 / 22 / 3 / 4 (incl. 7 wrappers: HunterCamp x3, Market_Awning_A x4) |
| lamp_post | 8 | 1 / 5 / 1 / 1 |
| lantern | 12 | 2 / 2 / 4 / 4 (wrappers only, see below) |
| fountain, well, weapon_stall, trophy_stall, diamond_shop | 3 each | 1 / 0 / 1 / 1 |
| anvil_forge, laundry_rack | 3 each | wrappers in the stall / camp copies |
| egg_nest 7, rowboat 8, minecart 4, skull_bones 30, scarecrow 3, clam_pearl 31, chest 7 | | see the summary table |

## Embedded instances (parts inside a bigger model)

These are not Models of their own, so they cannot carry the `MapProp` tag. `tagAll()` wrapped their parts, in place,
into a child Model named after the prop (no part moved, rotated or changed - checked on 25,080 parts; only the
parent of those parts changed). No code references these parts (grep of src/ and tools/). The wrapper's scale is
recorded while it is empty, so `run()` sizes the template clone to the old group. Templates must keep the reference
size `SyncMapProps.REF` (crate height 4.0, barrel height 4.05, lantern glass height 1.5).

| prop | wrapper | host model (all copies: kit, test area, main map) | parts | pivot / scale |
|---|---|---|---|---|
| crate | `Crate` | HunterCamp (MA, TEST, Plains_3) | `Crate` x2 | bottom centre, yaw of the box, 0.85 |
| barrel | `Barrel` | HunterCamp (MA, TEST, Plains_3); Market_Awning_A (MA, TEST, Hub x2) | `Barrel` x2 / `Barrel` + `BarrelBand` | bottom centre, 0.84 / 0.79 |
| laundry_rack | `LaundryRack` | HunterCamp (MA, TEST, Plains_3) | `Rack` x5, `Hide` x2 | on the camp floor under the rack, along the crossbar, 1.0 |
| anvil_forge | `AnvilForge` | Station_WeaponShop (MA, TEST), Hub.WeaponShop | Forge x2, Chimney, Embers (+light, FirePoint), Stump, Anvil x3, AnvilHorn | bottom centre of the group, stall rotation, 1.0 |
| lantern | `Lantern` | Station_TutorialGuide / Hub.TutorialGuide, Station_EggStation / Hub.EggStation, EntryArch_Plains (MA.Gates, TEST) and Plains_1.EntryArch (2 each) | Lantern (+PointLight), LanternCap, LanternBase (Chain / LanternArm stay in the host) | centre of the glass, host rotation, glass height / 1.5 (0.8 guide, 1.2 egg station, 1.0 arch) |

Not wrapped: the lantern of each Lantern_Post (the lamp_post template will carry its own lantern as a nested
`lantern` prop) and the zone-styled lanterns of the other zones' EntryArch (Dead, Heaven, Swamp, Tundra, Volcano:
other colours and sizes, not in the photos).

Look-alikes NOT synced (single plain blocks that are part of a bigger landmark, not visible in any photo):
the cargo `Crate` (4x4x4 block) and `Barrel` (cylinder) on the deck of the PirateShip_Wreck (`MapAssets.Plains`,
TEST, Plains_2 `Decor.Landmark`), the 3 `GoodsCrate` boxes on each Market_Awning_A counter.

## Distinct variants, measured (for Agent A)

Pivot of every kit model = bottom centre on the ground (Y 0), front = -Z, unless noted. "bbox centre" is in pivot space.

### crate - `Crate_A` (base variant, 30 copies identical; Abyss "Sunken" = same geometry, other colours)
- bbox 4.00 x 4.00 x 4.00, centre (0, 2, 0). No PrimaryPart. 9 Parts (Block), SmoothPlastic, all CanCollide/CanQuery/CastShadow on.
- Body 3.7 cube (214,150,92); bottom and top slabs 4 x 0.5 x 4 (168,98,56); 4 corner posts 0.5 x 3 x 0.5 at (+-1.75, 2, +-1.75) (168,98,56); 2 diagonal braces 0.5 x 4.1 x 0.15 at z +-1.9, roll +-45 (168,98,56).
- Sunken (Abyss_2 x9): body (92,71,59), frame pieces each slightly different (79..112, 61..86, 51..72).
- Lidded (HunterCamp): body 3.2 cube (214,150,92) + lid 3.5 x 0.4 x 3.5 (168,98,56) on top (lid centre y 3.2), whole thing yaw 20; footprint 3.5 (4.49 diagonal bbox in camp space).
- Scales in use: 1.0 and 0.8 (Hub Harbor and Plains_2 Docks have 0.8 crates stacked on 1.0 crates at y +4.0).

### barrel - `Barrel_A` (32 identical incl. BossArenas)
- bbox 3.45 x 4.05 x 3.45, centre (0, 2.03, 0). 5 Parts (Cylinder), SmoothPlastic.
- Body cyl 4.0 high x 3.0 dia (168,98,56); Belly cyl 2.0 high x 3.4 dia (168,98,56); 2 Bands 0.35 x 3.45 dia at y 1.0 and 3.0 (92,98,110); Lid 0.1 x 2.6 dia at y 4.0 (112,62,38).
- OneBand (HunterCamp): cyl 3.4 high x 2.6 dia (168,98,56) + band 0.3 x 2.8 dia at y 2.6 (92,98,110). Market_Awning_A: cyl 3.2 x 2.6 + band 0.3 x 2.8 at y 2.4.

### lamp_post - `Lantern_Post`
- bbox 3.85 x 9.75 x 1.50, centre (1.22, 4.88, 0): pivot at the foot of the post, the arm reaches +X. 9 Parts (Block).
- Foot 1.4 x 0.6 x 1.4 (150,156,168); Post 0.8 x 9.5 x 0.8 at y 5 (112,62,38); Arm 3.2 x 0.5 x 0.5 at (1.2, 9.2) (112,62,38); Brace 0.5 x 2.0 x 0.5 at (0.9, 8.3) roll -45 (112,62,38); Chain 0.15 x 0.7 x 0.15 at (2.4, 8.65) (92,98,110); LanternCap 1.5 x 0.3 x 1.5 at (2.4, 8.2) (92,98,110); Lantern 1.2 x 1.5 x 1.2 at (2.4, 7.3) Neon (255,214,120) + PointLight (255,214,120) B0.7 R16 no shadows; LanternBase 1.5 x 0.3 x 1.5 at (2.4, 6.45) (92,98,110).

### lantern - lantern units (no model of their own)
- TutorialGuide ground lantern (photo 15): Lantern 1.0 x 1.2 x 1.0 Neon (255,214,120) + PointLight B0.6 R12; LanternCap and LanternBase 1.3 x 0.3 x 1.3 (92,98,110); unit bbox 1.3 x 1.8 x 1.3, bottom 0.6 above the stall pivot.
- Lantern_Post unit: 1.5 x 2.7 x 1.5 incl. chain (see lamp_post). EntryArch: Lantern 1.2 x 1.5 + LanternCap 1.5 x 0.3 + LanternArm 0.3 x 0.3 x 1.2 (to the arch).
- EggStation: Lantern 1.6 x 1.8 x 1.6 + LanternCap 2.0 x 0.4 x 2.0 + Chain 0.2 x 1.6 x 0.2, hanging at y 10.2 (B0.7 R16).

### fountain - `Fountain_A`
- bbox 30.00 x 22.30 x 30.00, centre (0, 11.15, 0); hub pivot (-46, 0.45, -70) yaw 0. 19 parts (18 Part, 1 MeshPart).
- Step cyl 1 x 30 dia (104,110,124); Basin cyl 3 x 26 at y 2.5 (150,156,168); BasinRim cyl 0.8 x 27 at y 4.2 (104,110,124); Water cyl 0.9 x 23 at y 4.22 (52,214,236) T0.15 CanCollide false; Pedestal cyl 5 x 7 at y 5.5 (150,156,168) and 4 x 5 at y 9.5 (163,170,183); UpperBowl cyl 1.6 x 13 at y 11.6 (104,110,124); upper Water cyl 0.7 x 11.4 at y 12.1 (52,214,236) T0.15; Spout cyl 4.4 x 3 at y 14.4 (150,156,168); SpoutRing cyl 0.8 x 4 at y 16.8 (255,201,60); TopCrystal MeshPart (rbxassetid://100106311518324, CollisionFidelity Box) 2.6 x 5.4 x 2.3 at y 19.6 Neon (95,212,255), CanCollide false, holds Attachment `WaterPoint` + PointLight (95,212,255) B0.6 R16.
- 4 WaterStream cyl 8 x 1 (52,214,236) T0.35 no collide no shadow, from the upper bowl lips at (+-4.31, 8, +-4.31) slanted 45 deg; 4 SpoutLip blocks 2 x 1.2 x 1.6 at (+-4.53, 11.8, +-4.53) (104,110,124).
- Collision: basin, rim, pedestals, bowl, spout are solid; waters and streams are not.

### well - `Well_A`
- bbox 11.40 x 13.20 x 9.60, centre (0, 6.6, 0); hub pivot (44, 0.4, -66) yaw 146 (on Plaza part `WellPad`); test pivot (-3012.08, 0, 92.19) yaw 0. 12 parts (10 Part, 2 WedgePart), SmoothPlastic, no lights, no children.
- Wall cyl 3.4 high x 9.0 dia at y 1.7 (150,156,168); Rim cyl 0.7 x 9.6 at y 3.5 (104,110,124); Water cyl 0.3 x 7.0 at y 3.72 (52,214,236) CanCollide false (top surface y 3.87, rim top 3.85).
- 2 Posts 0.9 x 9 x 0.9 at (+-4.2, 5.5, 0) (112,62,38); Crank cyl 9.6 long x 0.6 dia at y 8 along X (112,62,38); CrankHandle 0.4 x 1.6 x 0.4 at (5.2, 7.6) (92,98,110); Rope 0.2 x 2.6 x 0.2 at y 6.7 (196,160,104); Bucket cyl 1.6 x 1.6 dia at y 5.0 (168,98,56); BucketBand cyl 0.25 x 1.75 at y 5.2 (92,98,110).
- Roof: 2 WedgeParts 11.4 x 3.4 x 4.0 at (0, 11.5, +-2.0) (196,64,58) (gable along X, eaves at z +-4, ridge at y 13.2).
- Collision: everything solid except the water. The wall cylinder is solid up to y 3.4, so today a player can jump
  onto the 3.85-high rim and stand on the filled top (0.45 below the rim, inside the non-collide water) but cannot go
  down into the well.

### chest - `Chest_A`
- bbox 4.40 x 3.48 x 3.07 (placed copies 4.50 wide), centre (0, 1.73, -0.06). 7 Parts.
- Base 4.4 x 2.0 x 2.8 (168,98,56); Lid cyl 4.4 long x 2.8 dia along X at y 2.0 (half buried in the base = dome) (112,62,38); 2 straight Bands 0.5 x 2.05 x 2.95 at x +-1.7 and 2 round Bands cyl 0.5 x 2.95 at x +-1.7, y 2.0 (255,201,60); Lock 0.8 x 1.0 x 0.3 at (0, 1.9, -1.45) (255,201,60).

### egg_nest - `SeagullNest_Rock`
- bbox 12.29 x 10.95 x 12.29, centre (0, 5.47, 0). 6 parts: Rock MeshPart rbxassetid://9420263160 (Hull) 9 x 10 x 9 at y 5, yaw 30 (150,156,168); Nest cyl 1.0 x 5.0 dia at y 9.6 (196,160,104); NestInner cyl 1.1 x 3.4 at y 9.65 (112,62,38); 3 Egg balls 1.1/1.1/1.0 at y 10.4 (245,246,250) x2 and (232,226,208).

### rowboat - `Rowboat_Wreck`
- bbox 14.10 x 4.98 x 11.14, centre (1.43, 2.49, 0.37) - the boat lies tilted (roll 22 deg) with the oar beside it. 12 parts (10 Part, 2 WedgePart).
- Bottom 9 x 0.6 x 3.6 (112,62,38); Side 9.0 x 2.4 x 0.5 (168,98,56); 2 SideBroken 4.5 x 2.4 / 2.2 x 1.2 (168,98,56); 2 Bow wedges 2.6 x 2.4 x 4.5 at x 6.14 (168,98,56); Stern 0.5 x 2.6 x 4.6 (112,62,38); 2 Bench 0.9 x 0.4 x 4.0 (214,150,92); LoosePlank 3.6 x 0.4 x 1.0 (214,150,92); Oar cyl 7.57 x 0.4 (112,62,38); OarBlade 2.0 x 0.25 x 1.0 (214,150,92).
- Abyss_2 copies (x4, scale 1.23-1.48): same geometry, dark brown-grey colours (76..116, 58..89, 49..75) per part.
- Hub copy pivot y -2.3 (half in the harbour water).

### minecart - `Minecart_A`
- bbox 5.12 x 6.24 x 6.61, centre (0, 3.12, 0). 13 parts (10 Part, 3 MeshPart).
- Floor 3.6 x 0.5 x 5.6 at y 1.5; 2 Sides 0.4 x 3 x 6 at x +-2.1 rolled +-10; 2 Ends 4.6 x 3 x 0.4 at z +-2.9 pitched +-8 (all 92,98,110); 4 Wheels cyl 0.5 x 1.5 at (+-1.6, 0.75, +-1.8) (112,62,38); OreLoad block 3.6 x 1.6 x 5.2 (96,92,110) + OreLoad MeshPart rbxassetid://2557003083 3.2 x 1.6 x 3.0 (96,92,110); 2 OreNugget MeshParts rbxassetid://100106311518324 Neon (255,196,60).

### skull_bones - `Bone_Pile_A`
- bbox 6.44 x 2.88 x 5.76, centre (-0.30, 1.44, 0.46). 16 Parts, all (240,232,208) except EyeSockets (62,60,78).
- 3 Bones cyl 5.7 / 5.37 / 3.67 long x 0.5/0.5/0.4; 6 BoneEnd balls 0.85 / 0.68; Skull ball 2.4 at (0.3, 1.68, 0.2); Jaw 1.5 x 0.9 x 1.3; 2 EyeSockets 0.5 x 0.55 x 0.3 on the -Z face; 3 Ribs 0.3 x 2.2 x 0.3 at z -2.2 rolled 20/30/40.
- Abyss_3 (x8, scale 1.54-2.34): pale grey-green (205..223, 211..229, 205..223), eye sockets pale too.

### scarecrow - `Scarecrow_A`
- bbox 8.00 x 9.45 x 3.60, centre (0, 4.73, 0). 11 Parts.
- Pole 0.6 x 7 x 0.6 (112,62,38); Arms 7 x 0.5 x 0.5 at y 5.4 (112,62,38); Shirt 2.6 x 3 x 1.4 at y 4.7 (74,108,220); Hay hands 1.2 x 0.9 x 0.8 at x +-3.4 and Hay skirt 2.8 x 0.7 x 1.6 at y 3.1 (236,200,96); Head ball 2.2 at y 7.2 (244,226,160); HatBrim cyl 0.3 x 3.6 at y 8.0 and HatTop cyl 1.3 x 2.0 at y 8.7 (168,98,56), tilted 6 deg; 2 Eyes 0.3 x 0.3 x 0.2 (112,62,38).

### clam_pearl - `Shell_A`
- bbox 2.60 x 2.20 x 2.83, centre (0, 1.10, 0.12). 3 Parts, CanCollide false, CastShadow false.
- ShellBottom cyl 0.4 x 2.6 dia (255,92,120); ShellTop same, hinged open 42 deg at (0, 1.18, 0.43); Pearl ball 0.8 at (0, 0.65, 0.2) (245,246,250).

### laundry_rack - parts `Rack` x5 + `Hide` x2 of `HunterCamp`
- Subset bbox 8.48 x 6.88 x 7.23 at camp-space (9.0, 3.3, 4.0), bottom at y -0.14. The rack is yawed 30 deg in the camp.
- 4 legs 0.45 x 7 x 0.45 splayed (17 deg pitch, 8 deg roll) and 1 crossbar 8.4 x 0.45 x 0.45 at y 6.5 (112,62,38); Hide 2.2 x 3.2 x 0.2 (196,160,104) and Hide 1.8 x 2.6 x 0.2 (214,150,92) hanging from the bar.
- HunterCamp itself: bbox 27.26 x 8.34 x 24.71, 29 parts (TentCloth wedges (104,168,72), poles, 6 FireStone meshes, 3 FireLogs, Embers Neon + PointLight + FirePoint, SeatLog mesh, crate, barrel). Plains_3 pivot (1948, 0, 500) yaw -160.

### anvil_forge - parts of `Hub.WeaponShop` (stall pivot (54.59, 0, -90.86) yaw 149)
- Subset bbox 5.30 x 9.00 x 8.80 at stall-space (10.85, 4.5, 1.9).
- Forge block 4 x 3 x 4 at (10.5, 1.5, 4.0) (150,156,168) + Forge top 4.6 x 0.6 x 4.6 at y 3.1 (104,110,124); Embers 3 x 0.4 x 3 at y 3.5 Neon (255,140,40) CanCollide false + PointLight (255,140,40) B0.7 R14 + Attachment FirePoint; Chimney 2 x 6 x 2 at (11.6, 6.0, 5.2) (104,110,124).
- Stump cyl 2 high x 3 dia at (10.5, 1.0, -1.0) (128,78,48); Anvil 1.6 x 0.6 x 1.2 (y 2.3), 1.0 x 0.8 x 0.8 (y 3.0), 3.2 x 0.9 x 1.4 (y 3.85) (92,98,110); AnvilHorn wedge 1.4 x 0.9 x 1.4 at x 12.8 (92,98,110).

### weapon_stall / trophy_stall / diamond_shop - shared stall frame (same in all three)
- Frame (stall space, pivot at floor centre, front = -Z): 2 front Posts 0.9 x 8.4 x 0.9 at (+-6.55, 4.2, -3.55), 2 back Posts 0.9 x 10.4 x 0.9 at (+-6.55, 5.2, 3.55) (112,62,38); 2 SidePanels 0.6 x 3.2 x 6.4 at x +-6.55 (168,98,56); Counter 12.4 x 3.2 x 1.8 at (0, 1.6, -2.9) (168,98,56); CounterTop 14.4 x 0.5 x 2.6 at y 3.45 (214,150,92); BackWall 13 x 7.4 x 0.5 at (0, 5.6, 3.55) (168,98,56); BackBeam 14 x 0.6 x 0.6 at y 9.3 (112,62,38).
- Awning: 7 stripes 2.23 x 0.45 x 11.6 at y 9.6, pitch -13 deg + 7 fringe blocks 2.23 x 1.2 x 0.35 at (x, 7.75, -6.75). Colours: weapon red (212,52,60) / cream (232,226,208); trophy green (40,124,58) / cream (232,226,208); diamond blue (64,120,212) / white (245,246,250).
- Functional children (keep): `Interact` 6 x 6 x 6 at (0, 3, -8) T1 CanCollide false, with ProximityPrompt (dist 12, hold 0, no line of sight) and BillboardGui `NameTag` (12 x 2.4 studs, max 120); `NpcSpot` 2 x 0.2 x 2 at (0, 0.1, 1) T1; Model `NPC` (17-18 parts, about 4.3 x 6.6 x 2.6 at (0, 3.5, 1)).
- Weapon stall extras (bbox 21.30 x 11.11 x 17.30, 67 parts incl. NPC): 3 swords on the back wall (SwordBlade 0.5 x 4.4 x 0.2 (92,98,110), SwordGuard 1.6 x 0.35 x 0.35 (255,201,60), SwordGrip (112,62,38)), Shield cyl 0.4 x 2.6 (74,108,220) + ShieldBoss 1.0 (255,201,60), AxeHead 2 x 1.8 x 0.3 (92,98,110) + AxeHandle 0.4 x 5 x 0.4 (112,62,38), DisplaySword on the counter (blade 1.6 x 0.3 x 4.6 (92,98,110) = the "blue tray" of photo 14, guard 0.5 x 0.4 x 1.4 gold); plus the anvil_forge parts.
- Trophy stall extras (bbox 15.60 x 11.11 x 15.50, 63 parts): TrophyCup (3 gold cylinders, 255,201,60) at (-3.5, 3.9..5.5, -2.9), CounterSkull ball 1.5 (240,232,208) at (2.5, 4.4, -2.9), back wall: 3 Plaques cyl 0.4 x 3 (112,62,38), BoarHead/BoarSnout/2 Tusks, DeerHead + 4 Antlers, horned Skull (240,232,208).
- Diamond shop extras (bbox 18.95 x 20.20 x 15.50, 73 parts): sign = SignPost 0.8 x 4.4 x 0.8 and SignBar 9 x 0.6 x 0.6 (255,201,60) at y 12.2, Diamond (1 block 4.8 x 1.8 x 1.4 + 4 wedges) Neon (95,212,255) with DiamondGirdle 4.9 x 0.3 x 1.5 Neon (245,246,250) at y 16.3..19.3; 3 Cushions 2.2 x 0.5 x 1.6 (74,108,220) with 3 gems (5 Neon pieces each; cyan, gold, cyan) at x -4/0/4; Chest (3 parts) at x -9.4 beside the stall; `Glow` T1 with PointLight (95,212,255) B0.6 R14 at y 9.

## Upgrade status

| id | template | instances synced | notes |
|---|---|---|---|
| crate | `ServerStorage.MapProps.crate`, Studio-built (`DevTools.StudioProps.crate`), 39 parts, 4.13 x 4.00 x 4.26, version d63b54d7 | 43 / 43 (run 2: 0 replaced) | pilot 2026-10-18. MaterialVariants FYD_Wood / FYD_Iron (shared textures) tinted with the guide colours. Variant Sunken. Screenshots `docs/screenshots/prop_upgrade/crate_*` (the first built-in-Wood draft in `crate_builtin_wood_draft/`). |
| well | `ServerStorage.MapProps.well` = the CURRENT 12-part well (captured from Hub.Decor.Village.Well_A), version 64c4c2b6 | 3 / 3 | Blender well (Agent A) checked with a temporary EditableMesh preview (`ApplyPropMeshes.preview`), then `endPreview`: the place keeps today's well until the owner imports `Blender_Exports/Props/well.fbx` and runs ApplyPropMeshes. Screenshots `well_before_*`, `well_preview_*`, `well_restored_*`. |
| lantern | `MapProps.lantern`, Studio-built (`StudioProps.lantern`), 14 parts, 1.50 x 2.74 x 1.50 (glass 1.16 x 1.55), version 840b0578 | 20 / 20 (12 wrappers + 8 nested in the lamp posts) | batch 1, 2026-10-19. Pivot = centre of the old glass, glass height 1.5 = scale 1 (TutorialGuide 0.8, EggStation 1.2, Plains EntryArch 1.0). Iron frame (FYD_Iron), glowing cream panes (Neon T 0.5), candle, `Flame` + PointLight (255,210,140) B1.2 R16 no shadows. |
| lamp_post | `MapProps.lamp_post`, 14 parts + the nested `Lantern` (14) = 28, 3.90 x 9.92 x 1.50, version 2afca0d4 | 8 / 8 | batch 1. Stone plinth + iron collar, two-step post with an iron band, cap, arm with a carved end, brace, iron band, hanger, 2 chain links, the lantern template hanging at the old lantern's place. |
| barrel | `MapProps.barrel`, 13 parts, 3.46 x 4.05 x 3.46, version 7e489bad | 40 / 40 (incl. camp x3 at 0.84, market x4 at 0.79) | batch 1. Planks texture (FYD_Planks) staves in 3 stacked cylinders (bulge), 3 dark hoops with 6 rivets, plank lid. Same collision radius (1.5 / 1.69 / 1.5). |
| laundry_rack | `MapProps.laundry_rack`, 22 parts, 8.40 x 6.99 x 4.00, version ba24ab5e | 3 / 3 | batch 1. Round poles, rope lashings, round bar, 3 cloths (front fold + back flap, `ClothA/B/C` sway in PropFX), 6 pegs. |
| weapon_stall | `MapProps.weapon_stall` (frame rebuilt, awning / display items / AnvilForge unchanged), 67 parts in the template, version ffb64a2f | 3 / 3 | batch 4 Studio half, 2026-10-19. Frame 10 -> 38 parts (`StudioProps.stall`): posts on stone feet, front beam + knee braces, planked side panels with rails, counter of 3 front planks + kick board + stiles + 2 top boards + lip, backboard of 7 boards on a planked backing with a dark frame (posts, back beam, bottom rail, 2 back battens). Colliding parts stay inside the old solid boxes; all new trims are CanCollide false. Interact / NameTag / prompt / NpcSpot / NPC kept on each instance. |
| trophy_stall | `MapProps.trophy_stall`, 71 parts, version be167422 | 3 / 3 | same frame. |
| diamond_shop | `MapProps.diamond_shop`, 82 parts, version d7b4fff4 | 3 / 3 | same frame; Glow light, sign, gems, chest unchanged. |
| chest, rowboat, minecart, skull_bones, clam_pearl, egg_nest, scarecrow | none yet (batch 2 Blender meshes, waiting for the owner's FBX import) | 0 (today's models kept) | checked 2026-10-19 with temporary EditableMesh previews (`ApplyPropMeshes.preview`, originals held and put back by `endPreview`; place left with 0 EditableMesh parts). Screenshots `docs/screenshots/prop_upgrade/batch2_preview/` (before / after, test area + one map placement, layout overlays for rowboat and skull_bones). PropFX entries added (clam sway + glint, scarecrow sway, minecart glow, chest / egg_nest sparkle). |
| fountain, anvil_forge, Blender pieces of weapon_stall / trophy_stall / diamond_shop | unchanged (fountain / anvil_forge: no template; stalls: the Studio frame templates above) | 0 (today's models kept) | batch 3 + 4 checked 2026-10-19 with temporary previews (`ApplyPropMeshes.preview`; stall pieces built into a copy of the frame template with the README Anchor re-basing; anvil_forge synced as the nested AnvilForge of each weapon stall), then `endPreview` (0 EditableMesh parts). Screenshots `docs/screenshots/prop_upgrade/batch34_preview/`. Batch 2 fixes (rowboat, clam_pearl, egg_nest v2) re-previewed: `batch2_preview/*_v2_*`. |
| all others | - | tagged, waiting for a template | |

## Related, not in scope (reported only)

- `Hub.Decor.Props.Lamps.LampPost_A` x8 (grey iron plaza lamp, 2.4 x 15.3, Lamp Neon 1.6 x 2.0 + 2 caps): not in
  the photos. Two of them (at (30.2, 0.2, 73.0) and (-30.2, 0.2, 73.0)) have no PointLight (probably on purpose,
  light budget). If the owner wants the plaza lamps upgraded too, they can reuse the `lantern` head.
- Zone-specific look-alikes with their own models: Barrel_Sunken / Barrel_Toxic / Potion_Barrel, Crate_Metal /
  Crate_Swamp / Ore_Crate, Chest_Sunken, Rowboat_Sunk, Scarecrow_Swamp, Fountain_Marble, Anvil_A, Dwarf_Forge,
  Mine_Cart_Lava, Hanging_Lantern, Lantern_Iron, Lantern_Grave, Giant_Shell_A.
- `workspace._Staging.BenchWork.Bench_Smooth`: the already-improved bench.
