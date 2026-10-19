# Prop texture guide: low-poly look (owner correction 2026-10-19) + fountain / well recipe

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

## A. Fountain / well recipe (owner quality target 2026-10-19)

The owner loves the **fountain** and the **well** (Blender props, `Previews/Props/fountain_before_after.png`,
`well_before_after.png`, `LowPoly_lineup_1.png` / `_2.png`). His words:

> low-mid poly, beveled stone blocks with visible joints, capped edges, a bit of moss at the base, individual roof
> tiles / shingles, thick wooden beams with joints and metal bands, small readable details, soft gradients, clean
> saturated colors.

"More realistic" always means "like the well": more pieces, better proportions, real thickness. It never means photo
textures, PBR or grain.

Every number below is measured on those two recipes (`tools/blender/fyd_props_recipes.py` `well()`,
`fyd_props_recipes_large.py` `fountain()`; chest and stalls for metal). The numbers are in studs, and each rule is
written so it can be built from **Parts + CSG unions** in Studio. Scale the numbers with the object: a 2x bigger wall
gets about 1.5x bigger blocks, not 2x more of them.

### A1. Palette (Part colours; the same values as section 3, plus the variants this batch needs)

Each material has **3 tone steps** for piece-to-piece variation, picked at random per block / shingle / plank and
never the same on two neighbours:
- **base** = the palette hex;
- **x0.93**;
- **x0.86**.

The well uses tones 0.86-1.0 on stones, 0.88-1.0 on shingles and 0.85-1.0 on staves.

| Family | Role | Hex | RGB | Notes |
|---|---|---|---|---|
| Stone | light | #A3AAB7 | 163,170,183 | StonePale: columns, upper pieces, light trims |
| | mid (main) | #969CA8 | 150,156,168 | wall blocks, basin, well stones |
| | dark | #686E7C | 104,110,124 | caps / coping, steps, plinths, rims (always one step darker than the wall they cap) |
| | mortar | #545864 | 84,88,100 | the core seen through the joints, wet bands |
| | blue stone | #7080CC | 112,128,204 | blue rocks (Plains RockBlue) |
| | lavender (shrine) | #B4B8E6 / dark #8C90C8 | 180,184,230 / 140,144,200 | approximate: read the shrine's current part colours and keep them |
| Wood | light | #D6965C | 214,150,92 | planks, counter tops, boards, sail frames |
| | mid | #A86238 | 168,98,56 | boards, staves, doors, bodies |
| | dark (beams) | #703E26 | 112,62,38 | posts, beams, rafters, bargeboards, handles |
| | trunk / logs | #804E30 | 128,78,48 | logs, palisade, stumps |
| | log ends | #ECC860 | 236,200,96 | cut ends of logs (LogEnd) |
| Roof tiles / shingles | red | #C4403A, ridge / dark #9C302C | 196,64,58 / 156,48,44 | well roof, windmill cap |
| | blue | #4078D4, ridge / dark #2F5CAA | 64,120,212 / 47,92,170 | Hub RoofBlue |
| | purple | #8A5CD6, ridge / dark #6A44A8 | 138,92,214 / 106,68,168 | derived from Hub Portal 150,110,255 |
| Metal | iron | #5C626E | 92,98,110 | bands, hoops, hinges, plates, lamp frames |
| | iron worn | #7A808C | 122,128,140 | blades, anvil face, worn edges |
| | gold | #FFC93C | 255,201,60 | collars, chest bands, signs, trims |
| | brass | #C99A2E | 201,154,46 | rivets, hinges on gold work |
| Moss | moss | #68A848 | 104,168,72 | patches at the base |
| | moss dark | #4A8A3C | 74,138,60 | every other patch, shaded side |
| Water | water | #34D6EC | 52,214,236 | Glass T 0.15 + `water_lines` |
| Cloth | red / cream / white / green / blue / blue alt | #D4343C / #E8E2D0 / #F5F6FA / #287C3A / #4078D4 / #4A6CDC | | stripes, awnings, banners, sails |
| Glass | glass | #CDEBF5 | 205,235,245 | Glass T 0.3: lantern panes, crystal ball |
| Emissive (Neon) | cyan | #5FD4FF | 95,212,255 | crystals, diamond, cyan gems |
| | pink | #FF8CF0 | 255,140,240 | portal field, shrine crystal (approximate: keep the current part colour if it exists) |
| | warm lantern | #FFD678 | 255,214,120 | lantern glass |
| | flame | #FFB648 | 255,182,72 | flames |
| | fire | #FF8C28 | 255,140,40 | embers, coals |
| | gold glow | #FFC43C | 255,196,60 | ore, yellow gems |

### A2. Stone blocks (walls, rings, bases)

| Rule | Well / fountain value | For Studio parts |
|---|---|---|
| Course height | 1.05 (well: 3 courses for a 3.15 wall); 1.0 (fountain step slabs) | 1.0-1.05 for props up to about 4 tall; 1.2-1.5 for walls over 6 tall |
| Block length | 1.84-2.88 (well: 2.36 +-22 %); fountain slabs 4.7-5.9 on a 15 radius | 1.8-2.8 x the course height, +-20 % per block, never two equal neighbours |
| Wall thickness | 0.85 (well ring) | 0.85-1.0 for rings and low walls, 1.5-2 for big walls (only the faces show) |
| Bond | each course offset by half a block (15 deg of 30) +-4 deg | running bond: next course offset 0.5 block +-10 % |
| Vertical joint gap | 0.086 (well), 0.11-0.13 (fountain slabs), 0.14 (coping) | **0.08-0.10** on blocks up to 3 long, 0.12-0.14 on big slabs |
| Horizontal joint gap | 0.05 (0.025 off each block) | **0.05** |
| Mortar behind the joints | StoneMortar core, its face 0.26 behind the block face | a mortar Part (or union) 0.25 behind the face, so every joint reads dark |
| Face irregularity | each block's face -0.04 .. +0.07 off the wall plane, 0.03 corner jitter | shift each block out by 0 / 0.04 / 0.07 at random |
| Chamfer (bevel) | 0.21 on the well stones (0.85 deep), 0.25 on the fountain slabs, 0.17 on the capstones | **20-25 % of the block's smallest dimension, max 0.25**: about 0.2 on 1-stud blocks |
| Tone | 0.86-1.0 per block | the 3 tone steps of A1 |

How to build a chamfered block from parts:
1. **CSG (best):** a Part block (L x H x D) `SubtractAsync` four NegateOperation wedges of c x c (c = the chamfer, about
   0.2) along the 4 front edges (top, bottom, left, right). Optionally also chamfer the top-back edge, which shows on
   free-standing walls. Union the course's blocks into one union per course or per wall section. The gaps stay real.
2. **Additive (cheaper):** a core Part (L - 2c) x (H - 2c) flush with the face, a back Part (L x H x (D - c)) behind
   it, and 4 WedgeParts (length x c x c) filling the edges at 45 deg. Union them.
3. **Never** one big block with painted lines pretending to be blocks (the old well wall). The 2 x 1 overlay
   `stone_block_lines` is only for curved surfaces that cannot be split (fountain_Wall, a 26-stud ring).

### A3. Caps, coping, plinths ("capped edges")

| Rule | Well / fountain value | For Studio parts |
|---|---|---|
| Cap thickness | 0.7 on a 3.15 wall (well); 0.8 on a 2.8 wall (fountain coping) | **0.7-0.8**, about 0.25 x the wall height for low walls |
| Overhang | outward 0.3 (well) / 0.5 (fountain), inward 0.2 | **0.3-0.5 outward, 0.2 inward** on every exposed side |
| Cap stone length | 2.8 (well, 10 stones), 5.3 (fountain, 16 stones on r 13.5) | 1.2-2 x the wall block length; joints offset half a stone from the course below |
| Joint gap | 0.08 (well), 0.14 (fountain) | 0.08-0.14 |
| Colour | StoneDark on a Stone wall | **one step darker** than what it caps |
| Chamfer | top-outer and top-inner edges | top edges, 0.17-0.2 |
| Base step / plinth (fountain) | 1.0 thick slab ring, tread 2.0 beyond the wall, StoneDark, 16 slabs (radius 12.6-15) | 0.8-1.0 thick, 1.0-2.0 tread, darker, slabs with joints |
| Footing stones (well posts) | 1.3 x 0.32 x 1.25 under each post | a flat stone under every post or column |
| Carved bands (fountain pedestal) | rings 0.18 proud, 0.32 tall, at 1/3 and 2/3 of the pedestal; base chamfer 0.25-0.45 | a band = a thin cylinder or ring 0.15-0.2 proud, 0.3 tall |

### A4. Moss ("a bit of moss at the base")

- **Where:**
  - only at the base: on the ground line against the wall (well), on the step top in the corner with the wall (fountain);
  - plus 1-2 tiny tufts in a low horizontal joint.
- **Never** on tops, never overhanging an edge, never lying on the plaza. The first fountain version had loose flaps
  past the step edge; they were fixed.
- **How many:** one patch per 4-9 studs of base perimeter, spaced irregularly (well: 7 around a 28-stud ring;
  fountain: 10 around an 88-stud ring).
- **Sizes:**

  | Kind | Where it was used | Length | Depth | Height / visible | Detail |
  |---|---|---|---|---|---|
  | Cushion | well | 1.7-2.2 | 0.5-0.65 | 0.45, half sunk: 0.2 visible | |
  | Pad | fountain | 1.8-3.8 (along the wall) | 1.0-1.5 | 0.1-0.2 proud | |
  | Corner pad | fountain | as the pad | as the pad | as the pad | creeps 0.25 up the wall |
  | Tuft | well, in joints | 0.55 | 0.1 | 0.15 | |

- **Parts:** a squashed Ball (e.g. 2.0 x 0.4 x 0.6), sunk to half its height, rotated along the wall. Or 2-3
  overlapping thin wedges / cylinders for a pad.
- **Colour:** Moss or MossDark, alternating, tone 0.78-0.92.

### A5. Roof tiles / shingles ("individual roof tiles")

| Rule | Well value | For Studio parts |
|---|---|---|
| Pitch | 40 deg | 35-45 deg |
| Under-board | 0.12 thick, WoodDark-ish, full slope | a thin Part under the rows, so no light leaks between shingles |
| Shingle | 1.5 wide (along the ridge) x 1.6 long (down the slope) x 0.10 thick; gap 0.06 between neighbours | **1.4-1.6 wide, 1.5-1.7 long, 0.1 thick, 0.06 gap** |
| Row step / overlap | rows every 1.35 down the slope, so each row covers 0.25 (about 15 %) of the one below | overlap 0.2-0.3 |
| Row offset | odd rows shifted half a shingle (0.75), with half shingles at the gable ends | always half-offset |
| Butt lift | lower end of each shingle 0.07-0.11 off the board (tilted, so the butt edge casts a line) | tilt each shingle 3-4 deg, or raise its lower edge 0.08 |
| Rows | 4 per side on a 5.4 slope (top row 1.35 long, tucked under the ridge cap) | slope length / 1.35 rows |
| Ridge cap | 0.62 wide each side x 0.12, one step darker (#9C302C) | darker cap Parts along the ridge |
| Bargeboards | 0.15 x 0.34 along both gable edges, WoodDark | yes, on every gable |
| Eave overhang | the board runs 1.25 past the posts along the ridge; the first row 0.06 past the board | 1.0-1.5 overhang |
| Tone | 0.88-1.0 per shingle | the 3 tone steps of A1 |

### A6. Thick wooden beams with joints

| Rule | Well value | For Studio parts |
|---|---|---|
| Posts | 0.88 square for 9.65 tall (about height / 11), tapered to 93 % at the top | **height / 10-12, at least 0.6** |
| Tie beam | 0.5 x 0.45 over a 6.9 span (span / 14) | **span / 12-15, at least 0.35** |
| King post, ridge beam, rafters | 0.4, 0.4 (span 12), 0.35 (3.6 long) | |
| Joints | beams cross and overlap each other (cross-lap), never butt edge-to-edge with a gap; rafters sit under the board | let beams run 0.15-0.3 past the post they cross; a 0.06 iron plate (0.62 square) where an axle or pin goes through |
| Chamfer | 0.22 on the 0.88 posts (25 %), long edges only | 20-25 % of the beam thickness, long edges |
| Colour | WoodDark posts / beams, WoodMid boards and staves, WoodLight tops | |
| Plank gaps | 0.02 between chest planks; 0.03 between bucket staves | 0.02-0.04, with a dark fill behind if the box is hollow |

### A7. Metal bands, hoops, rivets

| Rule | Value from the props | For Studio parts |
|---|---|---|
| Band width | 0.14 (bucket hoops on a 1.5-tall bucket), 0.4 (chest straps on a 2-tall chest) | **height / 7-10 of the object** |
| Band thickness | 0.06-0.07 proud of the surface, sitting ON it (never sunk in, never floating) | 0.06-0.08 |
| Hoop placement | at 1/6 and 5/6 of the bucket height | near both ends, 1/6 in |
| Rivets | domes 0.12 across (r 0.06), every 0.6 along a strap, at least 0.15 from the band ends; 2 on each lid band | Ball parts 0.12-0.15, every 0.5-0.7 |
| Corner plates | L-plates 0.24 wide x 0.05 on the vertical edges (chest) | yes on boxes and doors |
| Colours | Iron bands on wood; Gold bands with Brass rivets on chests / signs | |

### A8. Water and wet details

- The water surface is 0.35-0.4 below the rim (fountain 0.35, well 0.4). It is Glass with Transparency 0.15 plus the
  `water_lines` "Ripples" Texture.
- A wet band (StoneMortar) 0.26 tall sits on the inner face just above the waterline. The basin floor is a dark
  StoneMortar disc seen through the water.
- Falling water: tubes 0.6 thick at the lip narrowing to 0.4, Glass T 0.3. A foam ring (white, T 0.2, about 1.1
  across) where each stream lands.

### A9. Gradient (soft, lighter top, darker base)

- Blender meshes use vertex colours (section 4 below):

      Color = palette x (0.82 + 0.18 x smoothstep(h / H))

  where h = the height of the piece and H = the object's height.
- **Studio parts use the same formula per Part**, with h = the height of the part's centre. A script can set it
  once per model; the palette colour stays the value at the top. If a script is not practical, use the 3 bands of
  section 4.
- Combined with the A1 tone steps, a well-like wall gets darker courses toward the ground, with every block a little
  different.
- Neon, Glass and water are never darkened.

### A10. Small readable details (what made the well "alive")

- Every working part is really there: winch axle (r 0.22) through iron bearing plates, drum (r 0.45) with 5 rope
  turns, iron crank with a wooden grip, bucket with 10 staves, 2 hoops and a bail. On the fountain: 6 carved spout
  lips, a gold collar, a hexagonal crystal with 2 small side crystals, foam rings.
- **Minimum readable size: 0.06** for a raised detail (rivet, hoop, band). Below that, drop it.
- Details come from geometry, not texture. Each one is a separate colour piece, so it reads at a distance.

### A11. Do / don't (from the well and the fountain)

**Do:**
- Irregular block lengths in a running bond, with a dark mortar core showing in 0.08-0.1 joints.
- A darker, overhanging cap with chamfered top edges, and a darker base step.
- Moss only at the base, in the corner with the ground or the step.
- Shingles in half-offset rows with lifted butts, a darker ridge cap, bargeboards.
- Beams with real thickness (span / 12-15) that cross at joints, a footing stone under each post, iron plates where
  something goes through.
- Bands sitting ON the wood.
- Every piece touching what carries it.

**Don't:**
- One smooth cylinder or block for a whole wall (the old well), or equal block lengths.
- Joints wider than 0.15, or no joints at all.
- Moss on tops or flapping past an edge (fountain v1).
- Hovering pieces: the first stall awning floated 0.2 over the posts; the egg-nest ring hovered.
- Pieces poking through each other: the axe handle through its head.
- Hollow boxes that show light through plank gaps (fill them dark, like the chest).
- Photo textures, grain, noise, PBR, Metal material, or tiny 0.02 details that turn into noise at distance.

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
