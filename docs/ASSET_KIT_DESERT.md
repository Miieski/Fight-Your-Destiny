# ASSET KIT DESERT - zone 2 props and gates

Built by the DESERT ZONE BUILDER, 2026-10-04. 32 models in `ServerStorage.MapAssets.Desert` and 4 in
`ServerStorage.MapAssets.Gates`. One clone of each stands in the preview line-up at
`workspace._Staging.AssetPreview.Desert` (ground centered on X = -3000, Z = 1800).

Use: `local m = Kit.asset("Desert/Cactus_A"):Clone(); m:PivotTo(CFrame.new(groundPoint)); m.Parent = decorFolder`

Conventions are the same as `docs/ASSET_KIT_A.md`: every entry is a `Model`, pivot = bottom center, front = -Z,
all parts anchored, `SmoothPlastic` (`Neon` for small glow accents), colors from `Kit.Palette.Desert` / `Common`
(plus brightness shades of those), no scripts, no unions, no textures, no `PrimaryPart`. `Model:ScaleTo` works on all.
No new Toolbox asset was inserted: the organic pieces are recolored clones of kit A models (they keep their
`SourceAssetId` / `SourceCreator` attributes). Sizes are bounding boxes X x Y x Z in studs.

## Desert (32)

| Name | Size | Parts | Notes |
|---|---|---|---|
| Cactus_A | 7 x 12 x 2 | 7 | saguaro with two arms, red `Flower` |
| Cactus_B | 7 x 4 x 6 | 9 | three barrel cacti |
| Cactus_C | 7 x 8 x 3 | 6 | prickly pear pads |
| DeadTree_Desert_A | 9 x 22 x 7 | 1 | recolored Common/DeadTree_A (src 127731233099210) |
| DesertPalm_A | 26 x 28 x 27 | 9 | recolored Plains/PalmTree_A (src 10354687850); leaves do not collide |
| Skull_Animal | 9 x 4 x 5 | 8 | horned cattle skull |
| Ribcage_A | 7 x 5 x 11 | 11 | spine along Z + 5 rib pairs |
| SandRock_S | 4 x 2 x 4 | 1 | sandstone color, recolored Common/Rock_S_A (src 9682467046) |
| SandRock_M | 9 x 6 x 8 | 1 | canyon light red, recolored Common/Rock_M_A |
| SandRock_L | 25 x 14 x 22 | 2 | canyon red, recolored Common/Rock_L_A |
| Canyon_Cliff_A | 59 x 52 x 39 | 4 | faceted red cliff wall segment = Common/Boulder_Cliff_A recolored, stored at scale 1.3 (`ScaleTo(2)` gives about 90 x 80 x 59). Face toward -Z. Hull collision: sloped faces are climbable, put an invisible wall in front |
| Mesa_Strata_A | 42 x 54 x 25 | 18 | block-built mesa / buttress with horizontal strata bands, face toward -Z. Used for buttes, backdrop mesas, banded accents on cliff walls |
| NomadTent_A | 11 x 9 x 14 | 9 | red A-frame tent with gold trim (recolored Common/Tent_A), entrance on -Z |
| NomadTent_B | 14 x 13 x 14 | 19 | square pavilion, red/teal pyramid roof, open on -Z, rug inside |
| ClayHouse_A | 21 x 14 x 20 | 22 | flat-roofed clay house, walls 20 x 12 x 16, turquoise `Door` 6 x 9 on -Z (not enterable), vigas, awning |
| ClayHouse_B | 25 x 21 x 22 | 29 | two-level clay house with a white dome, door 6 x 9 on -Z |
| MarketStall_A | 12 x 10 x 8 | 23 | red/white striped awning, counter on -Z, jars and fruit |
| ClayJar_A | 2 x 4 x 2 | 3 | small terracotta jar |
| ClayJar_B | 4 x 5 x 4 | 7 | amphora with a turquoise band and two handles |
| Carpet_A | 9 x 0.2 x 13 | 6 | flat torn carpet, no collision; place it 0.03 above the ground |
| Brazier_A | 6 x 6 x 6 | 6 | gold bowl on a sandstone stem. Attachment `FirePoint` on the Neon `Embers` part. No light: add `VFX/Fire_Brazier` |
| Sandstone_Column | 6 x 25 x 6 | 7 | gold and lapis bands |
| Sandstone_Column_Broken | 16 x 12 x 12 | 6 | stump + two fallen drums |
| Sandstone_Wall_Ruin | 20 x 13 x 8 | 9 | stepped broken wall along X, one loose block in front |
| Sandstone_Block | 6 x 5 x 5 | 2 | two stacked blocks |
| Obelisk_A | 7 x 32 x 7 | 15 | gold pyramid tip, glyphs on -Z (one Neon) |
| JackalStatue | 8 x 20 x 11 | 34 | seated jackal-headed guard on a plinth (20 tall with the ears; `ScaleTo(0.8)` for about 16). Neon turquoise `Eye` parts |
| Hieroglyph_Panel | 12 x 10 x 0.7 | 22 | wall panel. Pivot = bottom center ON the wall plane, the panel sticks out toward -Z. 12 `Glyph` blocks, 3 of them Neon gold. No collision |
| GoldPile_A | 9 x 3 x 9 | 11 | coins, goblet, two Neon gems. Add `VFX/Gold_Sparkle` |
| Sarcophagus_Small | 5 x 5 x 10 | 12 | gold lid with lapis stripes, head toward -Z |
| Throne_Gold | 13 x 21 x 11 | 21 | on two steps, Neon `SunDisc`, Neon `ArmGem` parts |
| Lamp_Djinn | 13 x 7 x 4 | 12 | large oil lamp, spout toward -X, Attachment `SmokePoint` on `SpoutTip`. Float it over a pedestal |

`Dune_Ridge` (optional in the task) was not made: dunes are built in place with `Kit.heightfield`.

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from. `Barrier` and `PriceSign`
(12 x 4 x 0.5, Front face = -Z) are direct children. `Barrier.PivotOffset` is preset so the model pivot stays at the
bottom center after `Kit.finishGate`. Door decoration is parented under `Barrier` (attribute
`BarrierDecorIsChildOfBarrier = true`, all `CanCollide = false`): destroy `Barrier` to open the gate.

| Name | Size | Parts | Notes |
|---|---|---|---|
| EntryArch_Desert | 39 x 29 x 9 | 33 | sandstone arch, NO `Barrier`, NO `PriceSign`. `NameSign` 14 x 4 x 0.5 on top (Front = -Z). 2 Neon `Ember` bowls with a PointLight and an Attachment `FirePoint` each, two red pennants `Cloth` |
| Gate_Desert_2 | 64 x 28 x 13 | 50 | sandstone arch, `Barrier` = wooden palisade door 24 x 16 x 1.4. `PriceSign` on the lintel. Two Attachments `FirePoint` on the bowl embers (no light) |
| Gate_Desert_3 | 87 x 42 x 18 | 49 | two red rock pillars, `Barrier` = INVISIBLE collidable 24 x 16 x 2 part with the planks, chains and lock as children. `PriceSign` hangs from the beam between the pillars |
| Gate_Desert_4 | 80 x 40 x 15 | 81 | pylon facade with sloped towers, `Barrier` = sandstone slab 24 x 16 x 3 carved with glyphs (some Neon gold). `PriceSign` = tablet on the lintel under the winged sun disc |

## Where the zone uses things that are not kit models

* Landmark stand-ins are built in place (one `Landmark` Model each, pivot bottom center, attribute `LandmarkName`):
  `RockArch` (Desert_1, 91 x 71 x 30), `OasisWell` (Desert_2, 40 x 22 x 28), `StoneBridge` (Desert_3, 151 x 60 x 33),
  `Sarcophagus` (boss arena `Decor`, 26 x 24 x 40).
* `BossGate` (Desert_4) and the arena `Door` are built in place (gold double door between two dark pylons).
