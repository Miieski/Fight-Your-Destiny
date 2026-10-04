# ASSET KIT JUNGLE - zone 3 props and gates

Built by the JUNGLE ZONE BUILDER, 2026-10-04. 39 models in `ServerStorage.MapAssets.Jungle` and 4 in
`ServerStorage.MapAssets.Gates`. One clone of each stands in the preview line-up at
`workspace._Staging.AssetPreview.Jungle` (ground centered on X = -3000, Z = 2400).

Use: `local m = Kit.asset("Jungle/JungleTree_A"):Clone(); m:PivotTo(CFrame.new(groundPoint)); m.Parent = decorFolder`

Conventions are the same as `docs/ASSET_KIT_A.md`: every entry is a `Model`, pivot = bottom center, front = -Z,
all parts anchored, `SmoothPlastic` (`Neon` for small glow accents), colors from `Kit.Palette.Jungle` / `Common`
(plus brightness shades of those), no scripts, no unions, no textures, no `PrimaryPart`.
No new Toolbox asset was inserted: the organic pieces reuse meshes of kit A models (oak trunk / canopy, rocks, bush,
tall grass, flowers) and keep their `SourceAssetId` / `SourceCreator` attributes. Sizes are bounding boxes
X x Y x Z in studs (rotated meshes are slightly over-estimated).

Scaling: `Model:ScaleTo` did nothing on clones that are not parented yet in this Studio session. Parent the clone
first, or scale part by part (size and offset from the pivot), which is what the zone build did.

## Jungle (39)

| Name | Size | Parts | Notes |
|---|---|---|---|
| JungleTree_A | 56 x 69 x 56 | 9 | tall forked `Trunk` (Hull), 3 `Buttress` wedges, 3 layered `Canopy` meshes starting about 37 up (no collision, no query), 2 `Vine`. src 127731233099210 |
| JungleTree_B | 58 x 56 x 58 | 8 | umbrella canopy, one low side branch. src 127731233099210 |
| JungleTree_C | 59 x 74 x 50 | 10 | tallest, 4 buttresses, 4 canopy clumps. src 127731233099210 |
| GiantLeafPlant_A | 14 x 8 x 10 | 9 | rosette of 4 big pointed leaves (2 wedges each). No collision |
| GiantLeafPlant_B | 19 x 12 x 20 | 11 | stalk with 3 top leaves and 2 lower ones. No collision |
| Fern_A | 10 x 6 x 10 | 1 | decor only. src 127731233099210 |
| Bush_Jungle_A | 12 x 6 x 12 | 3 | two leaf blobs + pink `Flowers`. No collision. src 9682467046 |
| Vine_Hanging_A | 5 x 14 x 2 | 6 | decor only. Pivot at the BOTTOM, attribute `Height = 14`: `PivotTo(CFrame.new(topPoint - Vector3.new(0, 14, 0)))` |
| Bamboo_Cluster_A | 7 x 21 x 6 | 8 | 5 `Stalk` cylinders (collide) + 3 leaves |
| LilyPad_A | 8 x 1 x 6 | 3 | two pads and a pink bloom; decor only; put the pivot on the water surface |
| Flower_Jungle_A | 8 x 8 x 4 | 2 | big pink flower (`Bloom`, `Stem`); decor only. src 127731233099210 |
| Flower_Jungle_B | 6 x 10 x 4 | 2 | orange. src 127731233099210 |
| Flower_Jungle_C | 6 x 8 x 4 | 2 | purple. src 127731233099210 |
| Mossy_Rock_S | 5 x 3 x 5 | 2 | `Rock` + `Moss` cap (no collision). src 9682467046 |
| Mossy_Rock_M | 12 x 10 x 12 | 2 | src 9682467046 |
| Mossy_Rock_L | 28 x 16 x 25 | 4 | src 9682467046 |
| Root_Arch_A | 45 x 27 x 9 | 19 | big root arching over a path; clear passage about 24 wide x 16 high along Z; feet at X = +-16..22 |
| Totem_A | 14 x 17 x 7 | 18 | three carved heads, wings, horns |
| Totem_B | 7 x 22 x 5 | 26 | five heads, feather crest |
| TribalHut_A | 16 x 21 x 18 | 14 | hut on stilts, thatch gable roof, door and ladder on -Z (not enterable) |
| WarBanner_A | 6 x 18 x 2 | 8 | red `Cloth`, gold `Emblem`, skull on top |
| SkullPike_A | 2 x 8 x 2 | 5 | |
| Drum_A | 5 x 4 x 5 | 5 | |
| Tribal_Torch | 2 x 8 x 2 | 6 | Attachment `FirePoint` on the Neon `Ember`. No light: add `VFX/Fire_Torch` |
| RopeBridge_Section | 16 x 6 x 20 | 21 | walkable deck 16 wide x 20 long (along Z), deck top at pivot Y + 1, posts and rope rails |
| SteppingStone_A | 11 x 2 x 11 | 3 | flat top at pivot Y + 1.6 (sink the pivot 1.5 into the water bed). src 9682467046 |
| FloatingDock_A | 12 x 7 x 16 | 15 | deck 12 x 16 (along Z) on two log floats, deck top at pivot Y + 2.7 |
| Waterfall_Rock_Set | 28 x 10 x 14 | 8 | two rocks, a stone step, water channel + small fall toward -Z. src 9682467046 |
| Ruin_Wall_A | 21 x 13 x 4 | 10 | mossy wall along X, face details on -Z |
| Ruin_Wall_Broken | 21 x 10 x 9 | 9 | stepped broken wall + 2 rubble blocks in front |
| Ruin_Pillar_A | 6 x 21 x 6 | 7 | one Neon `Glyph` on -Z |
| Ruin_Pillar_Broken | 14 x 11 x 13 | 6 | stump + fallen drum |
| Ruin_Stairs | 21 x 8 x 15 | 10 | 5 steps, 14 wide, climbing toward +Z to 7.5 high |
| Carved_Face_Block | 13 x 16 x 7 | 21 | stone face, 2 Neon `GlyphEye`, headdress (12 tall to the brow, 15.6 with the crest) |
| Glyph_Tile | 8 x 0.4 x 8 | 6 | floor tile with a Neon `Glyph` inlay; no collision; lay the pivot on the floor |
| ArrowTrap_Wall | 13 x 11 x 7 | 15 | visual only: 6 dark holes, 2 arrows, one Neon glyph, on -Z |
| Golden_Altar | 12 x 9 x 8 | 13 | two stone steps, gold top, idol, 2 Neon gems. Add `VFX/Gold_Sparkle` / `Altar_Aura` |
| Temple_Pool | 25 x 3 x 25 | 14 | square rim 1.4 high, water 0.7 deep (no collision), gold-capped corner posts |
| Jaguar_Den_Rocks | 53 x 23 x 33 | 9 | horseshoe of rocks with a roof slab, dark opening and bones on -Z. src 9682467046 |

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from. `Barrier` and `PriceSign`
(12 x 4 x 0.5, Front face = -Z) are direct children. `Barrier.PivotOffset` is preset so the model pivot stays at the
bottom center after `Kit.finishGate`. Door decoration is parented under `Barrier` (attribute
`BarrierDecorIsChildOfBarrier = true`, all `CanCollide = false`): destroy `Barrier` to open the gate.

| Name | Size | Parts | Notes |
|---|---|---|---|
| EntryArch_Jungle | 46 x 30 x 8 | 54 | two totem pillars and a vine-wrapped beam, NO `Barrier`, NO `PriceSign`. `NameSign` 14 x 4 x 0.5 on top (Front = -Z). 2 Neon `Ember` bowls with an Attachment `FirePoint` each (no light) |
| Gate_Jungle_2 | 58 x 28 x 11 | 70 | tribal palisade with two small totems (Jungle Edge -> River). `Barrier` = wooden double door 24 x 16 x 1.4 with a mask. `PriceSign` above the lintel under a horned skull. Two Attachments `FirePoint` on the torch embers (no light) |
| Gate_Jungle_3 | 56 x 29 x 10 | 54 | overgrown stone archway (River -> Lost Temple). `Barrier` = root wall 24 x 16 x 3 (dark backing, roots, vines, leaves and flowers as children). `PriceSign` on the lintel |
| Gate_Jungle_4 | 66 x 53 x 17 | 52 | giant carved stone face (Lost Temple -> Temple Heart). `Barrier` = the closed mouth, a stone slab 24 x 16 x 3 with two rows of teeth and a Neon glyph as children. `PriceSign` on the upper lip. Neon `GlyphEye` parts |

## Where the zone uses things that are not kit models

* Landmark stand-ins are built in place (one `Landmark` Model each, pivot bottom center, attribute `LandmarkName`):
  `GiantTree` (Jungle_1, at 6000, 0, 40), `WaterfallCliff` (Jungle_2, pivot 5900.5, 0, 300, front facing +X),
  `StepPyramid` (Jungle_3 Decor, pivot 6000, 0, 782), `GoldenIdol` (boss arena `Decor`, pivot 6000, 0, -542).
* `StepPyramid` has a tunnel 40 wide x 26 high along Z at ground level (tiers 1 and 2 are split in two halves, part
  `TunnelRoof` closes it at Y 26-28). The Jungle_4 entry corridor (walls, ceiling) sits inside that tunnel, so the
  Blender replacement needs the same opening, or no collision.
* `BossGate` (Jungle_4) and the arena `Door` are built in place (gold double doors in a stone frame).
* The Jungle_2 river: banks are `Ground` parts and wedges around a bed (`RiverBed`, top at Y = -0.8) and one flat
  `Water` part (top at Y = -0.2, no collision, no query).
