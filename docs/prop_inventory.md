# Prop inventory - model upgrade (docs/model_upgrade_brief.txt, step 4A)

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
| all others | - | tagged, waiting for a template | |

## Related, not in scope (reported only)

- `Hub.Decor.Props.Lamps.LampPost_A` x8 (grey iron plaza lamp, 2.4 x 15.3, Lamp Neon 1.6 x 2.0 + 2 caps): not in
  the photos. Two of them (at (30.2, 0.2, 73.0) and (-30.2, 0.2, 73.0)) have no PointLight (probably on purpose,
  light budget). If the owner wants the plaza lamps upgraded too, they can reuse the `lantern` head.
- Zone-specific look-alikes with their own models: Barrel_Sunken / Barrel_Toxic / Potion_Barrel, Crate_Metal /
  Crate_Swamp / Ore_Crate, Chest_Sunken, Rowboat_Sunk, Scarecrow_Swamp, Fountain_Marble, Anvil_A, Dwarf_Forge,
  Mine_Cart_Lava, Hanging_Lantern, Lantern_Iron, Lantern_Grave, Giant_Shell_A.
- `workspace._Staging.BenchWork.Bench_Smooth`: the already-improved bench.
