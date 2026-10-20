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
