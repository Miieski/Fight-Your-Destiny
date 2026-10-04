# Blender_Exports - landmark meshes (batch 1: Hub + Plains, Desert, Jungle)

13 low-poly, flat-shaded landmark models made in Blender 5.2 (headless). One FBX per landmark, plus a
preview picture in `previews/` (the gray figure in the pictures is a 5.5-stud player for scale; it is
not in the FBX). No textures: every object is one solid color and is recolored after import from its name.

## How to import in Roblox Studio (by hand)

1. Studio: **File > Import 3D** (or **Avatar tab > Import 3D**), pick one `.fbx` from this folder.
2. In the import window:
   * import it as **one Model** and **keep the separate meshes** (do NOT merge / do not tick "Merge meshes");
   * **Anchored = on**;
   * leave the **scale at the default** value and leave the up/forward axis settings alone
     (the orchestrator rescales each model to the size listed below and recolors it afterwards);
   * "Insert in workspace" may stay on or off, the destination below is what matters.
3. **Keep the file name as the Model name** (for example `Plains_1_Windmill`) and do not rename the
   MeshParts inside: the part names (`<File>__<Set>_<Key>`) tell the recolor script which
   `Kit.Palette` color each part gets. `Neon_` in a name means the part must be Neon material.
4. Put the 13 Models in **ServerStorage > MapAssets > Blender** (create the folder `Blender` if needed).
5. Repeat for the 13 files. If the importer shows a warning about missing textures or UVs, ignore it
   (there are none on purpose).

## Files

Sizes are in studs as the model should measure in Studio: **X (width) x Y (height) x Z (depth)**.
Triangles are totals for the file; no single object is above 1,500 triangles (limit 9,000).

| File | Size in Studio (X x Y x Z) | Objects / colors | Triangles | Where it goes | Notes |
|---|---|---|---|---|---|
| `Hub_RebirthAltar.fbx` | 43.6 x 34.0 x 43.6 | 8: Hub_Plaza, Hub_PlazaDark, Common_Stone, Common_StoneDark, Common_StoneBlue, Common_Gold, Neon_Common_Diamond, Neon_Hub_Portal | 2,440 | Hub, center (rebirth altar) | Round dais with three 1.2-stud steps all around, four pillars, rune altar, floating crystal. |
| `Plains_1_Windmill.fbx` | 46.3 x 71.9 x 34.1 | 8: Common_Stone, Common_StoneDark, Hub_Wall, Hub_Timber, Hub_Roof, Common_Wood + blades `Plains_1_Windmill_Blades__Common_Wood`, `Plains_1_Windmill_Blades__Common_Cloth` | 2,174 | Plains 1 (Plains), on the hill | The two `_Blades` objects are the 4 blades + hub. Spin them together about the Studio Z axis through the point X 0, Y 48.8, Z +10.4 measured from the model's bottom center. Width is the blade span (tower base is 31 wide). |
| `Plains_2_PirateShip.fbx` | 112.0 x 61.4 x 37.9 | 8: Common_Wood, Common_WoodDark, Common_WoodLight, Common_Cloth, Common_Iron, Common_Gold, Common_Rope, Hub_Banner | 3,408 | Plains 2 (Beach), in the shallow water / on the sand | Bow up 15 degrees, stern sunk; the hull is cut flat at ground level (closed underneath). Hull breach + loose planks on the front side. |
| `Plains_3_AncientTree.fbx` | 118.2 x 117.6 x 126.6 | 7: Plains_Trunk, Plains_MountainDark, Plains_Leaf, Plains_LeafDark, Plains_GrassLight, Plains_Moss, Plains_Mushroom | 2,900 | Plains 3 (Forest), center | Trunk about 28 wide, 7 roots with walkable gaps, canopy starts about 60 studs up. A little larger than the 110 asked: scale x0.93 for 110 wide. |
| `Plains_4_GolemStatue.fbx` | 33.6 x 36.6 x 26.7 | 5: Plains_Rock, Plains_CaveRock, Plains_CaveRockDark, Plains_Moss, Neon_Plains_Ore | 1,392 | Plains 4 (Cave) boss arena | Kneeling golem on a low plinth; glowing chest runes and eyes are the `Neon_Plains_Ore` object. |
| `Desert_1_RockArch.fbx` | 90.9 x 71.0 x 29.7 | 4: Desert_CanyonRed, Desert_CanyonLight, Desert_CanyonDark, Desert_Sand | 1,080 | Desert 1 (Dunes) | Passage under the arch: 41 wide at the ground, 32 wide at 30 high, 43 high. Nothing stands in the passage. |
| `Desert_2_OasisWell.fbx` | 40.5 x 22.0 x 28.3 | 8: Desert_Sandstone, Desert_SandstoneDark, Desert_Water, Desert_Sand, Desert_Terracotta, Common_Wood, Common_Rope, Common_Iron | 1,914 | Desert 2 (Oasis), village square | Well (left) + ruined fountain with fallen column (right). `Desert_Water` = well water, bucket water, fountain puddle. |
| `Desert_3_StoneBridge.fbx` | 151.1 x 60.1 x 31.5 | 6: Desert_CanyonRed, Desert_CanyonLight, Desert_CanyonDark, Desert_Sandstone, Desert_SandstoneDark, Desert_Sand | 1,996 | Desert 3 (Canyon), across the canyon | Flat deck, top at Y = 50.1 above the model bottom, 150 long, 24 clear between the parapets (parapets have gaps). Arch underneath: 80 wide x 38 high. Both ends are flat so they butt against the canyon walls. Add an invisible walk part on the deck if mesh collision is not precise enough. |
| `Desert_4_Sarcophagus.fbx` | 26.0 x 23.6 x 40.0 | 6: Desert_Gold, Desert_Lapis, Desert_Turquoise, Desert_Sandstone, Desert_SandstoneDark, Desert_PyramidDark | 1,572 | Desert 4 (Pyramid) boss arena, center | Lies flat, feet toward the front, lid slid aside (dark gap). One static mesh set: the lid is not a separate object. |
| `Jungle_1_GiantTree.fbx` | 90.3 x 121.0 x 87.1 | 8: Jungle_Trunk, Jungle_TrunkDark, Jungle_Leaf, Jungle_LeafDark, Jungle_LeafLight, Jungle_Vine, Jungle_Totem, Jungle_TotemAlt | 3,618 | Jungle 1 (Jungle Edge) | Buttress roots, tribal mask on the front of the trunk. Hanging vines end 35+ studs above the ground; turn collisions off on the `Jungle_Vine` part. |
| `Jungle_2_WaterfallCliff.fbx` | 121.6 x 89.8 x 50.6 | 6: Jungle_Stone, Jungle_StoneDark, Jungle_Moss, Jungle_Leaf, Jungle_Vine, `Jungle_2_WaterfallCliff__Jungle_Water` | 3,240 | Jungle 2 (River), against the map edge | Three rock steps with a 16-wide channel in the middle. The `Jungle_Water` object is the flat water sheet (12.3 wide): top channel at Y 75.6, ledge pool at Y 49.1, then down to a round pool on the ground. Make it transparent / replace it with animated water in Studio. Back side is flat. |
| `Jungle_3_StepPyramid.fbx` | 124.0 x 80.0 x 119.7 | 7: Jungle_Stone, Jungle_StoneDark, Jungle_Moss, Jungle_Trunk, Jungle_Leaf, Jungle_Gold, Neon_Jungle_Glyph | 3,976 | Jungle 3 (Lost Temple) | 6 tiers, front stair 19.4 wide with 24 steps (2.35 high x 2.0 deep, steep: add an invisible ramp), top platform at Y 56.4, shrine with a doorway about 9 wide x 9.4 high. |
| `Jungle_4_GoldenIdol.fbx` | 40.0 x 50.5 x 36.0 | 6: Jungle_Gold, Jungle_Flower2 (darker gold accents), Jungle_Stone, Jungle_StoneDark, Jungle_Moss, Neon_Jungle_Glyph | 1,764 | Jungle 4 (Temple Heart) boss arena | Seated gorilla, arms on knees, glowing eyes / belly glyph / pedestal carvings in the `Neon_Jungle_Glyph` object. |

## Orientation and pivot

* 1 Blender unit = 1 stud. Every model stands on the ground plane and is centered on its bounding box
  (pivot = bottom center after `Model:PivotTo` on the bounding box bottom).
* Axis mapping with the export settings used: Studio X = Blender X, Studio Y = Blender Z (up),
  Studio Z = minus Blender Y. The models were built with their **front toward Blender -Y, so the front
  faces Studio +Z after import**. If a landmark must face the players arriving from -Z, rotate the
  Model 180 degrees around Y.
* All faces are triangles, flat-shaded (faceted), single material per object, no UVs, no rig, no animation.

## Rebuilding

Sources: `assets/blender/<Name>.blend` (collection `<Name>` = the exported meshes, collection
`PreviewOnly` = camera, sun, ground and the reference figure). Generator scripts:
`assets/blender/scripts/<Name>.py` + shared helpers in `assets/blender/scripts/fyd_common.py`
(palette copied from `tools/BuildKit.luau`). Re-run one or more landmarks from the repo root:

```
bash assets/blender/scripts/run.sh Plains_1_Windmill Desert_1_RockArch
```

Each run rewrites the FBX, the preview PNG, the `.blend` and `assets/blender/stats/<Name>.json`
(sizes, triangle counts per object, anchor points).
