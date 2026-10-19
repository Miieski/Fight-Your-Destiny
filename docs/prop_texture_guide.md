# Prop texture guide: low-poly look (owner correction 2026-10-19)

Applies to every upgraded prop, both the Blender meshes (Agent A) and the Studio-built props (Agent B).
Owner rule (top of `docs/model_upgrade_brief.txt`): keep the new shapes, but make them look like the 20 reference
photos (`REMAKE OBJECT/Model_References/Model_References/`). That means clean flat-shaded, saturated solid colours,
soft gradients (lighter at the top, darker at the bottom) and only simple stylized details.

**Removed everywhere:**
- photo-like colour maps, normal / roughness / metalness maps, noise and grain;
- the FYD_* MaterialVariants;
- the PBR SurfaceAppearances.

Texture asset ids live in `src/ReplicatedStorage/GameSystem/Config/PropTextures.luau`. The per-mesh data of the
Blender props lives in `Blender_Exports/Props/PropMeshData.luau`. Its contract is in `Blender/Props/README.txt`.

## 1. Which colours: the real Part colours, not the photo pixels

The photos show today's parts after the hub's colour grading. The graded pixels are about +15 % brighter and more
saturated than `Part.Color`. For example, crate panel 214,150,92 shows as #EFAE58 in photo 03, posts 112,62,38 show
as #983C13 in photo 02, and grass 98,208,64 shows as #51E12B.

The new MeshParts and Parts are graded by the same lighting / ColorCorrection. So we set the **Part colours** (BuildKit
`Kit.Palette`, measured by Agent B in `docs/prop_inventory.md`), and the result looks like the photos. Typing the photo
hexes would grade them twice and make them too bright and too saturated.

The "photo" column below is for checking only.

## 2. Materials

| Use | Material | Notes |
|---|---|---|
| Every solid surface (wood, stone, iron, gold, cloth, straw, rope, bone, moss, plain) | **SmoothPlastic** | Today's parts are SmoothPlastic. Plastic is acceptable, but do not mix the two within one model. |
| Glowing parts and gems (lantern glass and flames, forge embers, crystals, diamond sign, gems, minecart crystals) | **Neon** | Colour = the glow colour; vertex colours white (no gradient). |
| Water (fountain basins, well, forge bucket) | **Glass**, Transparency **0.15** (today's) | Gets the `water_lines` overlay as "Ripples" Textures; PropFX scrolls them. |
| Falling water (fountain streams) | **Glass**, Transparency **0.3** | `water_lines` on the side faces. |
| Glass (crystal ball, lantern panes when they are not Neon) | **Glass**, Transparency **0.3** | |
| Foam rings | SmoothPlastic, Transparency 0.2, white | |
| Metal | **not used** | Owner: Metal only for glowing parts and gems, and those are Neon. Gold and iron are plain SmoothPlastic colours, as in the photos (sign bar, spout ring, trophy, bands). |

## 3. Palette per family (hex = the Part / MeshPart Color to set)

| Family | Name | Hex | RGB | Photo shows | Used for |
|---|---|---|---|---|---|
| Wood | WoodLight | #D6965C | 214,150,92 | #EFAE58 (crate panel, 03 / 12) | panels, counter tops, benches, oar blade, thwarts |
| | WoodMid | #A86238 | 168,98,56 | #D66A24 / #B95720 (crate frame, barrel 03 / 10) | frames, barrel staves, hull, chest base, stall panels |
| | WoodDark | #703E26 | 112,62,38 | #983C13 (posts 02), #6C3615 (counter 14) | posts, beams, lids, handles, grips, scarecrow pole |
| | WoodTrunk | #804E30 | 128,78,48 | #9C3813 (stump 13) | forge stump |
| | RoofRed | #C4403A | 196,64,58 | #E33B3F (well roof 16) | well roof shingles |
| | RoofRedDark | #9C302C | 156,48,44 | #B82729 (16) | ridge caps, shadow side |
| Metal (SmoothPlastic) | Iron | #5C626E | 92,98,110 | #646D94 / #35526F (minecart 06) | hoops, bands, frames, anvil, minecart |
| | IronWorn | #7A808C | 122,128,140 | #868087 (anvil 13) | blades, anvil face, worn faces |
| | Gold | #FFC93C | 255,201,60 | #EFE237 (spout ring 01) | bands, lock, trophy, guards, sign bar |
| | Brass | #C99A2E | 201,154,46 | #9F9A11 (chest 17, shaded) | rivets, hinges |
| Stone | Stone | #969CA8 | 150,156,168 | #B2B8B7 (fountain basin 01) | basin wall, well stones, forge |
| | StoneDark | #686E7C | 104,110,124 | #8597AD / #7E8B97 (rims 01) | step, rims, coping, capstones, chimney |
| | StonePale | #A3AAB7 | 163,170,183 | #CCD2D2 (column 01) | fountain upper column |
| | StoneMortar | #545864 | 84,88,100 | | dark wet bands, basin floor |
| | StoneBlue | #7080CC | 112,128,204 | #6E83A3 (rock 04) | blue rocks (egg nest) |
| | CaveRock | #605C6E | 96,92,110 | #877E8B (03) | ore loads |
| Moss | Moss | #68A848 | 104,168,72 | | moss pads |
| Cloth | ClothRed | #D4343C | 212,52,60 | #DE161E (19) | weapon stall stripes |
| | ClothCream | #E8E2D0 | 232,226,208 | #E3E2DD (18) | cream stripes |
| | ClothWhite | #F5F6FA | 245,246,250 | | diamond shop white stripes, rims |
| | ClothGreen | #287C3A | 40,124,58 | #118922 (18) | trophy stall stripes |
| | ClothBlue | #4078D4 | 64,120,212 | #1169D0 (20) | diamond shop stripes |
| | ClothBlueAlt | #4A6CDC | 74,108,220 | #2466DE (shirt 08), #254ABB (shield 14) | scarecrow shirt, cushions, shield |
| | ClothOrange / ClothTan | #D6965C / #C4A068 | | #E09242 / #D59F54 (11) | laundry hides |
| Straw / rope | Straw | #ECC860 | 236,200,96 | #CFC554 (08) | hay, straw |
| | StrawPale | #F4E2A0 | 244,226,160 | | burlap head |
| | Rope | #C4A068 | 196,160,104 | | ropes, nest ring |
| Bone | Bone | #F0E8D0 | 240,232,208 | #EAE8DC (07) | bones, skull |
| | BoneSocket | #3E3C4E | 62,60,78 | #1C274B (07) | eye sockets |
| Plain | ClamPink / ClamInner | #FF5C78 / #FF8AA3 | | #F9649D / #E75083 (09) | clam shells outside / inside |
| | Pearl | #F5F6FA | | #E6EAE7 (09) | pearl, eggs |
| Glow (Neon) | Lantern | #FFD678 | 255,214,120 | #FFFFB9 (02 / 15) | lantern glass |
| | Flame | #FFB648 | 255,182,72 | | flames (the part "Flame") |
| | Fire | #FF8C28 | 255,140,40 | (Neon clips to yellow, 13) | forge embers / coals |
| | Diamond | #5FD4FF | 95,212,255 | #76FFFD (20) | diamond sign, cyan gems, fountain crystal |
| | OreGold | #FFC43C | 255,196,60 | #FFFF03 (06) | minecart crystals, gold gem |
| Water (Glass) | Water | #34D6EC | 52,214,236 | #27E6EE (01) | all water |

The values live in `tools/blender/fyd_props.py` (PALETTE) and in the README palette table. A model keeps its
original main colours: the stall stripes, the clam pink and the cyan crystals stay exactly as today.

## 4. Gradient: lighter at the top, darker at the bottom

**Blender meshes (vertex colours, see section 6):** every corner of a solid mesh gets the grey multiplier

    g = (0.82 + 0.18 * smoothstep(t)) * down * tone,   t = clamp(y / H, 0, 1)

- **y** is the height in the prop's space (studs above the ground contact).
- **H** is the prop's height, i.e. today's bounding-box height (`StudioSize.y`; 11.11 for the three stalls, so their
  frames and pieces share one gradient).
- So the bottom of a prop is 18 % darker than its top, with a smooth S-curve in between.
- **down** = 0.88 on faces that point down (normal y < -0.6): undersides read darker.
- **tone** = the existing per-piece tone:
  - a random 0.93-1.0 per piece;
  - bevel faces +0.06 (a light edge highlight);
  - deliberate darker details: the sword fuller 0.5, the inside of the chest 0.6, the alternating boat strakes 0.83, the clam's hinge gradient.
- Neon, Glass, Water, Stream and Foam meshes keep white vertex colours (pure colour, no gradient).

**Studio-built Parts (no vertex colours): three bands by the height of the part's centre in the model:**

| Band | Color |
|---|---|
| lowest 25 % (feet, bases, plinths, legs) | Part colour x 0.90 |
| 25-60 % (bodies, counters) | x 0.96 |
| top 40 % (caps, roofs, awnings, signs) | the palette colour |

- Neon, Glass and water parts are not banded.
- This gives the same top-to-bottom ramp as the meshes, at zero cost.
- For a single part that spans most of the height (a post), use its centre band.

## 5. Stylized details

**Geometry first.** The new shapes already carry the details, and they keep doing so:
- planks (chest, crate, hull strakes, bottom boards);
- stone slabs and coping (fountain, well, egg-nest ledge);
- metal bands and rivets (chest, barrel, minecart, shield);
- cloth stripes (separate red / cream / green / blue / white meshes);
- roof shingles.

These need no texture.

**Overlay textures (only where the geometry is a plain surface).** All three are 256 x 256 RGBA, tileable, 4 studs
per tile (the Blender UVs are world-scale: 1 UV unit = 4 studs). They have a transparent background and flat lines,
with no noise:

| Name | Look | Blender meshes using it | Good on Studio Parts for |
|---|---|---|---|
| `stone_block_lines` | running-bond block joints, blocks 2 x 1 studs, 4 px black lines at 30 % alpha | fountain_Wall, anvil_forge_Hearth, anvil_forge_Upper | stone walls, plinths, the forge block |
| `plank_lines` | plank seams every 1 stud along the grain, one butt joint per plank with 2 nail dots, black at 35 % alpha | weapon_stall_ShieldFace | crate panels, counter tops, tables, the laundry rack board |
| `water_lines` | 5 wavy dashed ripple lines, white at 50 % alpha | every Water / Stream mesh (as "Ripples" Textures) | any water part |

How to apply them:
- **MeshParts:** set `MeshPart.TextureID` to the overlay. The Color shows through the transparent pixels and the lines
  darken it. Equivalent: a `SurfaceAppearance` with **ColorMap only** (no Normal / Roughness / Metalness map),
  `AlphaMode = Overlay`, `Color = white`. That is what ApplyPropMeshes' `surfaceFor` already builds when a family's
  `Set` has only a ColorMap.
- **Studio Parts:** a `Texture` per face that needs it, `StudsPerTileU = StudsPerTileV = 4`, Color3 white,
  Transparency 0.
- **Water:** `Texture` "Ripples" on the top face (on the 4 side faces for falling water), `StudsPerTile 4`; PropFX scrolls it.

Not used:
- no wood grain, stone noise or cloth weave (the photos have none);
- no metal reflections;
- no texture on Neon.

Everything else is a flat colour.

## 6. Vertex-colour convention (Blender meshes)

**The vertex colours are a GREY MULTIPLIER (white at the top, darker toward the bottom), and `MeshPart.Color` = the
family colour of section 3.** There is no SurfaceAppearance and no MaterialVariant. The material is section 2's.

Why this one renders right on a MeshPart without a SurfaceAppearance:
- **It renders correctly.** Roblox multiplies the mesh's vertex colours with `MeshPart.Color`. The batch 2/3/4
  previews showed this (EditableMesh with these grey colours + `MeshPart.Color` = ClamPink read pink, not grey).
- **It degrades safely.** If any path drops the vertex colours (importer setting, a SurfaceAppearance, a LOD), the
  part still shows the right flat colour; it only loses the soft ramp.
- **Recolours keep working.** The variants (Abyss_2 "Sunken" rowboats, skull_bones "Pale") still work by changing
  `Color` only.
- **The FBX matches.** Its material colour is the family colour too (materials named `<Material>_<RRGGBB>`), so a raw
  import already looks right.

The other option (full colour in the vertex colours with `MeshPart.Color` white) was rejected. It breaks the
recolours, and it turns every mesh white wherever the vertex colours are ignored.

## 7. Data (PropMeshData.luau, version 2)

Per mesh:
- `Family`, `Role`;
- `Color` (RGB list = the hex to set) and `Target` (the same hex);
- `Material` (Enum.Material name);
- `Transparency`;
- `Texture` (an overlay name of PropTextures, or nil);
- `Overlay` (`water_lines` for Water / Stream);
- `VertexColors = "multiplier"`;
- `CastShadow`, `Center`, `Size`, `Pivot`, `Anchor`, `Replaces` (unchanged).

`Families[name]` = `{ Material, Role, Transparency, Set = the overlay name or nil, Overlay }`.
`Textures[name]` = `{ ColorMap = "rbxassetid://..." }`.

There are no Variant, Metal, NormalMap, RoughnessMap or MetalnessMap fields any more.
