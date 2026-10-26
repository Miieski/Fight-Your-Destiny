# Prop texture guide: low-poly look (owner correction 2026-10-19) + fountain / well recipe + desert

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
| | shrine stone | #A5ACB9 / #969CA8 / #686E7C | 165,172,185 / 150,156,168 / 104,110,124 | the altar's real Tier / Step / Pillar colours (backup .rbxm). The lavender look in photo 16 comes from the pink Neon light. |
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
| | "pink" | #966EFF | 150,110,255 | the portal field and the altar crystals: Hub Portal. Read from the parts; as Neon it renders pink-lavender. |
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

## B. Desert: buildings and shelters (owner task 2026-10-19)

The same quality target as section A (the fountain and the well), applied to the 5 desert objects of
`docs/Desert_Images/01_Buildings_and_Shelters/`. Everything is built from parts and unions in Studio. The joint,
chamfer, cap, moss (none here), tone-step and gradient rules of section A apply unchanged. This section adds the
desert colours and the desert-specific pieces.

### B0. Today's kits (read from `BackUP_Files/FightYourDestiny_2026-10-19_212529_before_desert_buildings_*.rbxm`)

All parts are SmoothPlastic. The game copies have exactly the kit colours.

| # | Object | Kit (`ServerStorage.MapAssets.Desert.`) | Parts | Copies | Today's shape |
|---|---|---|---|---|---|
| 01 | adobe houses | `ClayHouse_A` | 22 | test + Desert_2 Village x5 | wall 20 x 12 x 16 on a footing 20.3 x 1.4 x 16.3, parapet 1.6 x 1.6, 5 vigas 0.9 dia (2.6 long, every 4.0), door 6 x 9 x 0.6 in a frame (posts 0.8 x 9 x 1, lintel 7.6 x 1 x 1), 2 windows 3 x 3.2 with sills 3.8 x 0.5 x 1, awning 8.4 x 0.4 x 3.4, chimney 3 x 2.2 x 3 |
| 01 | | `ClayHouse_B` | 29 | test + Desert_2 Village x2 | wall 24 x 11 x 18, upper storey 13 x 9 x 12 with cap 14 x 1.2 x 13, dome ball 8 + finial 0.6 x 1.6, 9 vigas, awning 7 x 0.4 x 3.2 |
| 02 | market stall | `MarketStall_A` | 23 | test + Desert_2 Village x4 | counter 11.6 x 3.2 x 2.2 + top 12.2 x 0.4 x 2.9, back 11.6 x 5 x 0.4, shelf, 4 posts 0.7 (7.4 front / 9.4 back), awning 6 strips 2.05 x 0.3 x 8.6 red / linen, 3 jars, fruit, cloths, tray |
| 03 | canopy pavilion | `NomadTent_B` | 19 | test + Desert_1 Camps | 4 roof wedges 7 x 5.2 x 7 (red / blue), 3 walls (red back, blue sides), 4 linen valances 14.2 x 1 x 0.3, 4 poles 0.7 x 7, centre pole 0.8 x 12.4, gold finial 0.9, rug 9 x 9 red + 5 x 5 gold |
| 04 | tent | `NomadTent_A` | 9 | test + Desert_1 Camps x2, Desert_3 Camp | 2 cloth wedges 12 x 8 x 5.5 (red / darker red), gold trim wedges at the front, entrance flaps, 2 poles 0.5 x 8.6, ridge pole 14 |
| 05 | ruined wall | `Sandstone_Wall_Ruin` | 9 | test + Desert_2 Village, Desert_3 Ruins x2 | 3 wall blocks 7 x 12 x 3 / 6 x 8.5 x 3 / 7 x 5 x 3, 2 loose blocks, cap 7.4 x 1 x 3.6, 2 flat glyph plaques (1 x 3, 3 x 2, 0.3 thick), footing 20.4 x 1.4 x 3.6 |

### B1. Desert palette

The owner's rule: **"keep each object's own main colors (they are the desert identity)"**. So the Color to set is
today's real part colour (BuildKit `Kit.Palette.Desert`, measured in the backups).

**Owner's example hexes, checked against the real colours.** All of them are close; use the real value:

| Owner's example | Real colour to use |
|---|---|
| sandstone #E8D59A / #CDB26E / #A88E55 | #E2BE84 / #D7B57E / #B89262 |
| canyon red #B84A2E / #D8703A / #8E2F22 | #C45438 / #E48050 / #963E30 |
| gold #F2C230 | #FFC93C |
| lapis #1E55C8 | #2C5CC8 |
| turquoise #2BD3C8 | #40D0C4 |
| linen #E9E6D6 | #E8E2D0 |
| terracotta #C8643A | #CC603E |
| cactus #2FA84F | #4CA454 |
| dark wood #4A2A1A | #533E28 for the window recesses; #703E26 for poles and tent wood |

Each colour below is given with its 3 tone steps (x1 / x0.93 / x0.86, section A1):

| Family | Name | x1 | x0.93 | x0.86 | Used by today |
|---|---|---|---|---|---|
| Adobe | clay wall | #DEA46E | #CE9966 | #BF8D5F | house walls (Desert Clay) |
| | light clay | #F2B378 | #E1A670 | #D09A67 | parapets, upper storey, chimney, plaster bands |
| | footing / dark sandstone | #B89262 | #AB885B | #9E7E54 | footings, caps, glyph plaques (SandstoneDark) |
| Sandstone | sandstone | #E2BE84 | #D2B17B | #C2A372 | ruin walls and blocks (Desert Sandstone) |
| | sandstone mid | #D7B57E | #C8A875 | #B99C6C | ruin centre wall |
| | sandstone block | #D2B17B | #C3A572 | #B5986A | loose blocks |
| Sand | sand / light / dark | #F4D07C / #FCE2A0 / #D6A860 | | | sand drifts (Desert Sand, SandLight, SandDark) |
| Canyon | red / light / dark | #C45438 / #E48050 / #963E30 | | | cliffs (accent only) |
| Trims | terracotta | #CC603E | #BE593A | #AF5335 | door frames, sills, caps (red door frame) |
| | turquoise | #40D0C4 | #3CC1B6 | #37B3A9 | doors, a stall jar (cyan door) |
| | desert blue | #3C96AA | #388C9E | #348192 | house B awning, pavilion roof / walls, stall cloth (TentAlt) |
| | lapis | #2C5CC8 | | | glyph inlays, pot bands (accent) |
| | gold | #FFC93C | #EDBB38 | #DBAD34 | knobs, finials, tent trim, rug centre, tassels |
| Cloth | tent red | #D64A3E | #C7453A | #B84035 | tent, awnings, stall stripes, pavilion roof (Desert Tent) |
| | tent red alt | #C14238 | #B33D34 | #A63930 | the tent's second side, darker panels |
| | rug red | #BC4136 | #AF3C32 | #A2382E | rugs |
| | linen | #E8E2D0 | #D8D2C1 | #C8C2B3 | stall stripes, valances, house B dome |
| Wood | trunk (vigas, posts) | #966840 | #8C613C | #815937 | vigas, stall / pavilion posts (Desert Trunk) |
| | dark wood | #703E26 | #683A23 | #603521 | tent poles, stall back, trays |
| | recess | #533E28 | | | window openings, door shadow |
| | counter | #A86238, top #D6965C | | | stall counter |
| Plants | cactus | #4CA454 | | | fruit, cactus accents |

Per object, the main colours that must stay:

| Object | Colours |
|---|---|
| Houses | clay #DEA46E, light clay #F2B378, footing #B89262, terracotta frames #CC603E, turquoise doors #40D0C4, awning red #D64A3E (A) / blue #3C96AA (B), vigas #966840, linen dome #E8E2D0 + gold finial |
| Stall | red #D64A3E / linen #E8E2D0 stripes, counter #A86238 / #D6965C, posts #966840, cloths #3C96AA / #FFC93C, jars terracotta / clay / turquoise |
| Pavilion | red #D64A3E / blue #3C96AA gores and walls, linen valance, gold finial, red rug #BC4136 with a gold centre |
| Tent | red #D64A3E / #C14238, gold trim #FFC93C, dark wood #703E26 |
| Ruin | sandstone #E2BE84 / #D7B57E / #D2B17B, dark sandstone #B89262 |

### B2. Adobe and plastered sandstone (houses)

| Rule | Value (studs) | How with parts |
|---|---|---|
| Wall batter | walls lean in: top 0.25-0.4 narrower than the base on each face | a thin wedge (0.3 x full height) along the bottom of each face, or slightly tilted face plates |
| Plaster layers | horizontal layer lines every **1.6-2.0** (6 layers on a 12 wall), **0.08** wide | each layer one face plate 0.1 thick in front of the core; alternate plates 0.04 proud / flush; tone step per layer (x1 / x0.93) |
| Exposed blocks | 2-4 patches per facade where the plaster fell off: 1.2-2.0 x 0.6-0.8 sandstone blocks, 0.05 proud, joints 0.08, in groups of 2-3 | sandstone #E2BE84 parts, a dark #B89262 plate 0.05 behind them |
| Base (wider) | footing 0.4-0.5 wider than the wall on every side (today 0.15), 1.2-1.4 tall, chamfered top 0.2, footing colour, joints every 2.5-3.5 | footing slabs as section A3 |
| Plaster band | a 0.35-0.4 tall band, 0.1 proud, light clay, at lintel height (top of the doors) and under the parapet | thin strips |
| Chipped corners | vertical corners chamfered 0.25-0.35; 2-3 notches per corner (0.4-0.8 tall, 0.2-0.35 deep) showing the darker block colour | CSG-subtract small wedges / blocks, or dark #B89262 inner blocks behind |
| Parapet | 1.2-1.6 tall x 1.2-1.6 thick (today 1.6 x 1.6), cap 0.25 thick overhanging 0.15, top edges chamfered 0.2 | corner merlons 0.5 higher and 2.0 long; a step down at the middle of long sides |
| Drain spouts (canales) | 0.5 wide x 0.4 tall x 1.4 long, sticking out 1.0 under the parapet, one every 6-8, sloping 10° down | trunk wood or terracotta, a dark inner strip on top |
| Chimney | keep today's 3 x 2.2 x 3; add a cap 0.25 overhang and a dark 1 x 1 opening | |

### B3. Vigas (round roof beams)

| Rule | Value (studs) |
|---|---|
| Diameter | **0.8-0.9** (today 0.9) |
| Spacing | **3.5-4.0** (today 4.0), all at one height just under the parapet, matching on the front and back |
| Overhang | sticks out **1.2-1.6** from the wall face (today about 1.9: shorten a little) |
| Carved end | the end cut at 25-30° (a CSG wedge subtract, top longer than the bottom), plus a darker end-grain disc 0.05 proud (#703E26, 0.7 dia), or a stepped end (a 0.7-dia, 0.25-long cylinder) |
| Colour | trunk #966840 with the 3 tone steps per viga |
| Support | a 0.15 terracotta or dark socket ring where it enters the wall (dia + 0.2) |

### B4. Doors, frames, shutters and windows

**Door** (today turquoise 6 x 9 x 0.6 in a terracotta frame):
- Recess the door 0.3 into the wall; the frame stands 0.2 proud of the plaster.
- Door = 4-5 vertical planks, 1.1-1.4 wide, 0.06 gaps, alternating tone steps.
- 2 horizontal battens 0.3 tall at 1/5 and 4/5 of the height, with 2-3 gold or iron studs (0.15 balls) on each.
- A gold ring or knob (today 0.5).

**Frame** (keep the terracotta posts 0.8 and lintel 1.0):
- A **wooden lintel beam** above the frame (trunk #966840, 0.5 x 0.5, 0.6 longer than the frame on each side), the adobe way.
- A threshold step 0.3 tall, 0.4 deep, footing colour.

**Windows** (today 3 x 3.2 dark recess, terracotta sill):
- Opening #533E28 recessed 0.3; a 0.3 terracotta frame around it.
- Sill and lintel each 0.6 longer than the opening (0.3 each side) and 0.3 proud.
- Optional grille: 3 vertical bars 0.12, dark wood.

**Shutters:** 2 leaves, each half the opening width, 0.15 thick, 3 planks, opened at 100-120° against the wall. Use a door colour (turquoise) or a blue (#3C96AA), with 2 small dark hinges each.

### B5. Cloth awnings and canopies (folds, trimmed / scalloped edge, tassels, ropes)

**House awning** (today a flat 8.4 x 0.4 x 3.4 red / 7 x 0.4 x 3.2 blue slab):
- 3-4 cloth panels 0.15 thick, pitched 15-20° down from the wall.
- Folds: alternate panels tilted ±3° and 0.05 offset (pleats).
- Front valance: 0.6-0.8 deep with scallops (half-discs: Cylinder parts 0.12 thick, 1.0-1.2 dia, one per panel) or zig-zag wedges, in the same colour or linen.
- Carried by 2 wall brackets (0.3 x 0.3 struts at 45°) or 2 thin poles 0.3.
- Rope ties 0.12 thick from the outer corners back to the wall, rope colour #C4A068.

**Stall awning** (today 6 strips 2.05 x 0.3 x 8.6, red / linen):
- Keep the 6 strips. Each strip is 2 parts with a 4-6° break at the middle (a sag).
- A front valance 0.8 deep with one scallop per strip, and a gold tassel (0.25 x 0.5) at each scallop point.
- A gold finial 0.5 on each front post; posts get a footing block 1.0 x 0.4 x 1.0.

**Pavilion canopy** (today 4 roof wedges red / blue, linen valance):
- 8 gores alternating red / blue (each gore a pair of wedges).
- Seams: 0.15 gold or linen piping strips along the 8 ridges.
- A scalloped linen valance (scallops 1.2 dia every 1.4), tassels at the 4 corners.
- Gold finial on a 0.4 collar.
- The blue side walls as tie-back curtains gathered at the poles with rope ties (2-3 thin bulging parts each).
- Rug with a 0.6 gold border band and a gold centre diamond (today 5 x 5).

**Cloth thickness:** 0.12-0.2. Never a 0.4 slab.

### B6. Tent canvas with stitched seams (tent)

- Each side is 3-4 canvas panels running from the ridge to the ground (3-4 wide), alternating tent red / red alt.
- **Seams:** raised strips 0.12 wide, 0.04 proud, in the darker red, along every panel joint.
- **Hem:** a 0.3 tall strip, one step darker, along the bottom edge.
- **Entrance:**
  - the 2 flaps folded back as triangles showing a gold lining (today's gold trim);
  - a rope tie on each flap.
- **Ridge pole:** 0.5, running 0.4 past the canvas at both ends with a gold cap 0.6.
- **Guy ropes:** 0.12 thick, from each pole top to a wooden stake (0.3 x 0.8, leaning out) 2.5-3 out from the tent at about 40°.
- A low sand drift (B8) along one side.

### B7. Dome with ribs and a finial (house B)

- **Drum:** a 0.8-tall cylinder, diameter = the dome's + 0.4, light clay, chamfered top.
- **Dome:** the upper half of a Ball 8 (today's size, linen #E8E2D0). CSG-subtract a block to cut off the lower half, or sink it into the drum.
- **Ribs:**
  - make 8 ribs: intersect a Ball 2 % bigger with 4 slabs 0.2 thick through the axis (at 0 / 45 / 90 / 135°), then union;
  - colour gold #FFC93C, or linen x0.86 for a quieter look.
- **Base ring:** 0.3 tall at the dome's foot, terracotta or gold.
- **Finial (gold), from the bottom up:** a 0.6 ball, a 0.3-tall collar, then a 1.2 spike or crescent. 2.0-2.4 total, today 1.6.

### B8. Ruins: broken top, glyph plaques with depth, rubble, sand drifts

- **Walls of real blocks** (section A2 with sandstone colours):
  - courses 1.2-1.5 tall on a 12-stud wall;
  - blocks 2-3.5 long, joints 0.08-0.10, a dark #B89262 core behind the joints;
  - chamfer 0.25.
- **Broken top edge:**
  - the top courses step down irregularly by 1-3 courses along the wall, with missing blocks;
  - the last blocks rotate 3-8° and slide 0.1-0.3 outward (loose);
  - 1-2 blocks are cracked: two parts with a 0.08 gap at an angle.
  - Keep the cap (#B89262) only on the tallest piece, broken off at one end.
- **Glyph plaques with depth** (today flat 3 x 2 x 0.3 and 1 x 3 x 0.3):
  - a frame border 0.25 wide, 0.15 proud;
  - the inner panel recessed 0.1;
  - glyphs as small raised parts 0.08 proud (an eye, an ankh, wavy water lines, a bird) in dark sandstone;
  - 1-2 lapis #2C5CC8 or gold inlay accents per plaque, 0.3-0.5 in size.
- **Rubble:** 4-8 fallen blocks at the base:
  - 0.8-2.0 in size, chamfered;
  - tilted 10-30° and half-buried (sunk 0.3-0.6);
  - the 3 sandstone tone steps.
- **Sand drifts:** wedges of sand colour against the wall base and between the rubble:
  - 2-4 long, 0.6-1.5 tall, slope 20-30°;
  - a rounded crest (a flattened Ball or a half cylinder on top);
  - sand #F4D07C at the crest, sand dark #D6A860 at the foot;
  - they hide the wall's bottom joint line.

### B9. Clay pots and a ladder

**Clay pots** (today's stall jars 1.4-2.0 terracotta / clay / turquoise):
- Body: a Ball scaled to width w (1.2-2.0) and height 0.9-1.4 x w.
- Neck: a cylinder 0.45 w across, 0.3 tall.
- Lip: a ring 0.55 w across, 0.12 tall.
- Foot: a ring 0.5 w across.
- One painted band at 60 % of the height: a 0.15 ring in a contrast colour (gold / turquoise / lapis / linen).
- Groups of 2-4 beside doors and walls; one may lie tipped over, half in a sand drift.

**Ladder** (adobe roof access, optional on house A):
- 2 trunk-wood rails 0.35 x 0.35, leaning 15° against the wall, ending 1.0 above the parapet.
- Rungs 0.25 across, every 1.0-1.2, with a dark 0.1 rope lashing ring at each end of each rung.

### B10. Gradient, materials, consistency

- Same as section A:
  - per-part gradient Color x (0.82 + 0.18 smoothstep(h / H));
  - the 3 tone steps per block / panel / plank;
  - SmoothPlastic everywhere;
  - Neon only for a lamp flame or glow;
  - no Metal, no textures with grain.
- The darkest parts are the recesses (#533E28) and the joint cores (#B89262). Joints in the plaster are finer (0.08) than in block walls.
- Minimum readable detail: 0.06 (a seam 0.04 proud is the one exception: it reads as a line along its length).

### B11. Do / don't (desert)

**Do:**
- Battered plaster walls with layer lines and a few exposed blocks.
- A wider, darker footing; chipped corners; a parapet with a cap and corner merlons; drain spouts.
- Vigas in a row with carved ends.
- Recessed plank doors in proud frames with a wooden lintel; deep-set windows with shutters.
- Cloth that sags and folds, with scalloped valances, tassels and ropes.
- Tents in stitched panels with guy ropes; a dome on a drum with ribs and a tall finial.
- Ruins of real blocks with a stepped broken top, deep glyph plaques, rubble and sand drifts.
- Every object keeps today's own colours.

**Don't:**
- One smooth box per wall (today's 20 x 12 x 16 Wall block).
- Flat 0.4 cloth slabs.
- Flush painted-looking doors.
- Equal blocks, or joints wider than 0.15.
- Moss in the desert: replace the moss of section A by sand drifts at the base.
- New colours that are not in the table.
- PBR, Metal or grain.

### B12. Desert gates and entrances (owner task 2026-10-19)

Images: `docs/Desert_Images/02_Gates_and_Entrances/`. Read from `BackUP_Files/FightYourDestiny_2026-10-19_224157_before_desert_gates_{ServerStorage,Workspace}.rbxm`. All parts are SmoothPlastic, the lamps and glyph lights Neon.

| # | Gate | Kit (`ServerStorage.MapAssets.Gates.`) | Parts | Copies | Notes |
|---|---|---|---|---|---|
| 01 | Egyptian arch | `EntryArch_Desert` | 33 | test `_Staging.AssetPreview.Desert.EntryArch_Desert`; game `Zones.Desert.Desert_1.EntryArch` | the game copy has 2 ClothTails 2.7 x 1 x 0.3 (kit 2.6 x 1 x 0.2) and its teal Band is 36.1 long |
| 02 | pylon temple gate | `Gate_Desert_4` | 81 | test; game `Zones.Desert.Desert_4.Gate` | Gate contract: the glyphs, borders and seam are children of `Barrier` and vanish when it opens; the game copy's two figure bars are 0.4 thick (kit 0.3) |
| 03 | canyon barricade gate | `Gate_Desert_3` | 49 | test; game `Zones.Desert.Desert_3.Gate` (identical) | Barrier invisible (T 1) with the planks / crosses / chains / lock under it. No boulder in the model: the boulder in the photo is a separate map rock. |

**Real colours** (keep them; tone steps as in B1):

| Gate | Part | Colour |
|---|---|---|
| Arch | piers | sandstone #E2BE84 |
| | pier bases, cornice | #B89262 |
| | lower pier band | gold #FFC93C |
| | upper pier band, SignBack | lapis #2C5CC8 |
| | lintel band | turquoise #40D0C4 |
| | cloth banners | red #D64A3E with gold tails |
| | bowl lamps | iron #5C626E with an Ember Neon #FFD678 |
| | pyramid tips, SignCap | gold #FFC93C |
| Pylon | towers, lintel | #CCA064 |
| | tower slopes | #C1985F |
| | carving panels | #D8AA6A |
| | cornices, footings, jambs, header, glyphs | #B89262 |
| | trim bands | lapis #2C5CC8 and gold #FFC93C |
| | door (Barrier) | sandstone #E2BE84 |
| | price sign | #F1CA8C on gold |
| | wings | gold, lapis, turquoise #40D0C4 |
| | sun disc | Neon gold |
| Canyon | pillar strata | red #C55438 / #C95639 / #C15237 / #C05236, orange #E88251 / #E48050 / #E78151, dark #9C4032 / #963E30 |
| | side rocks | #BE5136 / #C85539, #E58150, #913C2E |
| | planks | #A86238 / #703E26 |
| | crosses | #D6965C |
| | chains, anchors, lock | iron #5C626E |
| | keyhole | gold |
| | rope | #C4A068 |
| | beam | #703E26 |
| | sign | #D6965C on #703E26 |

**Parts rules** (sizes in studs; joints, chamfers, gradient as in section A):

- **Cavetto cornice** (the Egyptian gorge: a concave cove that flares out to a flat top):
  - **Profile, bottom to top:** a torus roll (below); a 0.3 fillet; the cove; a flat top slab.
  - **Cove:** 3-4 stacked slabs, each stepping out further than the one below: +0.15, +0.3, +0.5, +0.8 of the total projection, so the steps follow a concave curve. Each slab is 0.3-0.5 tall.
  - **Flat top slab:** 0.4 thick, stepping out 0.1 beyond the last cove slab.
  - **Total:** height about 0.6 x the cornice's projection; projection 1.0-1.6 on a 5-6 deep lintel. Today's single 38.5 x 1 x 6.8 slab becomes about 2.0 tall.
  - **Smoother cove:** fill each step with a WedgePart (the slope facing down and out).
  - **Colours:** #B89262; optional vertical reed grooves on the cove face, every 0.8 (0.1 wide, dark tone step).
- **Torus roll mouldings:** a horizontal Cylinder 0.5-0.6 across along every top edge under the cornice, plus vertical rolls on the outer corners of the pylon towers and piers (0.5 across, full height). Banded every 2-3 studs with a thin wrap ring 0.15 in lapis or gold.
- **Inlay bands** (lapis / turquoise / gold; today's plain 1.0 bands):
  - band 0.8-1.0 tall, 0.05-0.1 proud;
  - patterns:
    - **zigzag:** small wedges (0.5 x 0.5) alternating up and down;
    - **chequer:** squares 0.5, two colours;
    - **lotus:** a gold 0.6 x 0.9 petal (a wedge pair) every 1.2 on lapis;
  - a 0.12 gold rule line above and below each band.
- **Glowing gold pyramid tips** (arch, today 4 CornerWedges 2 x 3.4 x 2 per tip): keep the size.
  - Add a 0.3 stepped plinth under each tip.
  - Neon gold #FFC93C for the top 40 % of each tip; the lower 60 % stays SmoothPlastic gold.
  - Optional small PointLight (warm, range 8).
- **Cloth banners** (today 2.6 x 7 x 0.2 red):
  - 0.12-0.15 thick, hung from a gold rod 0.25 across, 0.6 longer than the banner;
  - 3-4 vertical folds: strips tilted ±4°;
  - gold trim 0.2 along both long edges and the bottom;
  - a pointed or forked tail, tassels 0.25 x 0.5 at the corners;
  - an emblem: a lapis eye or ankh 1.0, 0.05 proud.
- **Brass bowl lamps on iron brackets** (today an iron Bowl 2.2-2.4 x 0.7-0.8 on a 1 x 1.4-1.6 x 2-2.4 bracket):
  - bowl = a ring 0.3 tall on a cone (a Ball scaled 1 : 0.45), in brass #C99A2E with a 0.15 gold rim;
  - bracket = iron arm 0.3 x 0.3 with a 45° brace and a wall plate 0.8 x 1.2 x 0.1 with 4 rivets;
  - the Ember (Neon, #FFD678 or #FF8C28) is 0.2 below the rim; 3 small flame wedges above it.
- **Stepped bases** (piers, footings): 2-3 steps, each 0.4-0.6 tall and stepping in 0.3-0.5, chamfered 0.15. Today's 2-stud PierBase becomes 3 steps.
- **Tapered pylon towers** (today 20 x 38 x 12 boxes with side wedges):
  - **batter:** the front and sides lean in 1 per 10 of height (WedgeParts or tilted face plates);
  - **courses:** lines every 1.5-2.0, 0.08 wide, staggered vertical joints (blocks 3-5 long);
  - torus rolls on the outer corners; a cavetto cornice on top.
- **Carved relief figures WITH DEPTH:**
  - **sunk relief:** the figure is CUT INTO the panel 0.15-0.3 deep;
  - the inner edge has a bevel: a 0.1 chamfer strip around the cut, 1 tone step lighter;
  - the figure's floor is 1 tone step darker;
  - details (belt, collar, eye) are raised 0.05 inside the cut;
  - with parts: the panel (today's Carving 12 x 20 x 0.4 at z -4.1) as a frame of 4 strips, with the figure parts placed 0.2 deeper than the panel face (today they sit in front of it);
  - **keep each figure part's x / y and size exactly** (record below); only their depth and the bevel change.
- **Niches with flag poles and banners** (pylon):
  - a niche 1.5 wide x 10-14 tall x 0.6 deep, cut into the tower front;
  - a pole 0.5 across, rising 4-6 above the cornice, with a gold cap;
  - a banner 1.5 x 6 (rules above), hanging from the pole top.
- **Winged sun disk** (today a SunDisc 5 dia Neon gold + 3 pairs of Wing bars gold / lapis / turquoise):
  - **feathers:** each wing is 3 rows of feathers, 6-8 per row, each 0.8-1.2 long x 0.6, tips rounded or pointed (a wedge), alternating gold / lapis / turquoise per row as today;
  - **disc:** Neon gold 5 dia, keeping today's size and position, with a 0.3 gold ring;
  - **uraei:** 2 small cobras 1.2 tall on either side of the disc: an S of 2-3 tilted cylinders 0.3 across plus a 0.6 hood wedge, in gold.
- **Heavy dark-wood double door** (pylon Barrier, today a 24 x 16 x 3 sandstone slab with glyphs):
  - **keep the sandstone face and the glyphs exactly** (record below);
  - add the door construction AROUND the glyph field: a dark wood frame #703E26 0.8 wide;
  - 2 leaves, split by today's Seam (keep it);
  - gold studs, 0.3 balls every 1.5, on the frame;
  - 2 gold ring handles 1.0 (like the Gate_Desert_2 Rings).
  - (For Gate_Desert_2, wooden planks: 2.7 wide planks with 0.06 gaps, iron bands 0.9 tall at 1/4 and 3/4, studs every 1.5.)
- **Canyon rock strata** (03; facet data below):
  - horizontal layers 2.2-4.0 thick, in today's sequence from the ground up: red, orange, red, dark red, red, orange, then a tilted orange cap;
  - soft (orange or thin) layers recessed 0.3-0.6 to form erosion grooves; a lit ledge on top of every step;
  - cracks are dark strips 0.28 wide, 0.03 proud, zig-zagging down 1 layer;
  - each layer steps in 0.5-1.1 going up; the opening face stays flat.
- **Sand drifts** (all three gates): as B8, against the bases and the canyon rocks; never in the gate opening or on the door's path.

**Glyph record (keep EXACTLY).** Owner: "keep the hieroglyph symbols exactly as they are (same symbols, same positions: they may be a clue or a puzzle)".

Gate_Desert_4 kit space: the gate origin at ground centre; the Barrier is at (0, 8, 0), its front face at z -1.5.

**Barrier glyphs** (children of Barrier):
- 37 parts named `Glyph`, all at z -1.6, 0.3 thick.
- Size codes:
  - H = 2.0 x 0.6 (bar);
  - V = 0.6 x 2.2 (tall bar);
  - v = 0.6 x 1.5 (short bar);
  - D = 1.5 x 1.5 turned 45° about Z (diamond).
- Colour codes: g = Neon gold #FFC93C; s = SmoothPlastic #B89262.
- Listed per column x as y:code, bottom to top:

| Column x | Glyphs (y:code) |
|---|---|
| -9.4 | 3.5:Vs, 5.8:Hs, 7.2:Hs, 9.75:Ds, 12.0:Hg, 13.4:Hg |
| -6.0 | 2.7:Hg, 4.1:Hg, 6.6:Vs, 9.7:Vs, 12.45:vs, 13.5:Hs |
| -2.6 | 3.55:Ds, 6.6:Vg, 9.75:Ds, 12.45:vs, 13.5:Hs |
| 2.6 | 2.7:Hs, 4.1:Hs, 6.25:vg, 7.3:Hg, 9.75:Ds, 12.8:Vs |
| 6.0 | 2.7:Hg, 4.1:Hg, 6.25:vs, 7.3:Hs, 8.9:Hs, 10.3:Hs, 12.85:Ds |
| 9.4 | 3.5:Vs, 6.25:vs, 7.3:Hs, 8.9:Hs, 10.3:Hs, 12.45:vg, 13.5:Hg |

**Other Barrier parts:**
- 4 `Border` bars 10.6 x 0.6 x 0.3, gold SmoothPlastic, at (±6.0, 1.1) and (±6.0, 14.9), z -1.6;
- `Seam` 0.5 x 16 x 0.3, #B89262, at (0, 8, -1.6).

**Tower figures** (children of the gate model, z -4.4, 0.3 thick, on the Carving panels 12 x 20 x 0.4 #D8AA6A at (±22, 16, -4.1)):
- body 5 x 8 at (±22, 16.5);
- gold Neon belt bar 8 x 0.8 at (±22, 17.9) (0.4 thick in the game copy);
- head 3 x 3 at (±22, 22.5);
- 2 legs 2 x 5.5 at (±20.4, 9.75) and (±23.6, 9.75);
- the body, head and legs are #B89262.

After the rebuild, Agent B checks every glyph by name, x / y position, size and colour. Only the depth changes: sunk relief, if wanted, for the tower figures; the door glyphs stay raised on the Barrier.

**Canyon facet data (03):**
- Files `Blender_Exports/Props/facets/canyon_gate__{pillar_L, pillar_R, side_rock_L, side_rock_R}.json`, generated by `tools/blender/fyd_facets.py -- canyon_gate`.
- Origin = the gate pivot (kit space); place every piece with no offset.
- The pillars keep today's bounding box: x 13.0 .. 27.9, y 0 .. 42.1, z ±8.45. The inner face stays flat at x ±13.0, so the opening stays 26 wide.
- The side rocks keep x 28.5 .. 43.5, y 0 .. 23, z -5.5 .. 8.5.
- Preview: `Previews/Props/desert_canyon_gate_facets.png`.

### B13. Desert monuments, statues and columns (owner task 2026-10-20)

Images: `docs/Desert_Images/04_Monuments_Statues_Columns/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_005329_before_desert_monuments_{ServerStorage,Workspace}.rbxm`.

**Kits and copies.** All parts are SmoothPlastic; eyes, glyph lights and gems are Neon. Every copy is the kit at a
uniform scale; no copy has its own colours or glyph layout (checked part by part).

| # | Object | Kit (`MapAssets.Desert.`) | Parts | Copies (scale) |
|---|---|---|---|---|
| 01 | column | `Sandstone_Column` | 7 | test; Desert_3 Ruins x2 (1.0, 0.8) |
| 02 | fallen columns | `Sandstone_Column_Broken` | 6 | test; Desert_2 Village x1; Desert_3 Ruins x2 (one at 0.8) |
| 03 | obelisk | `Obelisk_A` | 15 | test; Desert_3 Ruins x1; Desert_4 Props x2 (0.8) |
| 04 | Anubis statue | `JackalStatue` | 34 | test; Desert_3 Ruins x2; Desert_4 Props x6; Desert_4 BossGate x2; BossArenas.Desert x4 (1.0 / 1.25 / 1.5) |
| 05 | golden guardian | `Sarcophagus_Small` | 12 | test; Desert_4 Props x4 (1.2) |
| 06 | hieroglyph tablet | `Hieroglyph_Panel` | 22 | test; Desert_3 Ruins x1; Desert_4 Props x24; BossArenas.Desert x20 (1.0 / 1.3 / 1.4) |
| 07 | golden pyramid altar | `GoldPile_A` | 11 | test; Desert_4 Props x8; Jungle_4 Props x2; BossArenas.Desert x11 (0.8 .. 1.6) |

**Real colours** (keep them; tone steps x1 / x0.93 / x0.86):

| Object | Colours |
|---|---|
| Column | base #B89262 + #E2BE84; shaft #E2BE84 (cylinder 3.6 dia, y 2.4..22.4); gold band #FFC93C at y 6.4; lapis band #2C5CC8 at y 19.4 (3.9 dia, 0.8 tall); capital 4.6 x 1 x 4.6 #E2BE84 + top slab 5.6 x 1.6 x 5.6 #B89262 (y 22.4..25.0) |
| Fallen columns | base as the column; standing shaft 7 tall #E2BE84 + broken piece 2.2 #D5B37C tilted 78°; 2 drums on the ground (3.0 and 7.0 long, 3.6 dia, #D5B37C / #E2BE84) |
| Obelisk | bases 6.5 x 1.5 #B89262 + 5 x 1.5 #E2BE84; 3 shaft blocks 3.8 / 3.3 / 2.8 square (#E2BE84 / #E9C488 / #E2BE84, y 3..29); pyramidion 4 gold CornerWedges 1.4 x 3 (y 29..32); 6 glyphs on the -Z face |
| Anubis | plinth #B89262 + #E2BE84; body / limbs #8C6844; head, snout, ears, feet #533E28; kilt, collar and nemes lappets lapis #2C5CC8; belt, collar, crown, nose, arm bands and anklets gold #FFC93C; eyes Neon turquoise #40D0C4; seat and back #E2BE84 |
| Guardian | base #B89262; box #E2BE84; lid gold #FFC93C + upper lid #EAB837; 4 lapis stripes; nemes lapis; head gold; eyes Neon #40D0C4 |
| Tablet | panel 12 x 10 x 0.5 #E2BE84; gold border #FFC93C; glyphs #B89262 or Neon gold |
| Altar | heaps #EAB837 / #FFC93C / #FFC93B (3 tiers 8 x 1 x 7.4, 5.6 x 1.1 x 5.2, 3.2 x 1.1 x 3.0); goblet #F2BE38; coins #FFC93B; gems Neon #5FD4FF and #40D0C4 (0.8 and 1.0 cubes) |

**Parts rules** (sizes in studs; joints, chamfers and the gradient as in sections A and B):

- **Column:**
  - **Carved square base:** 2-3 steps (5.4 / 4.6 as today), each with a 0.15 chamfer, plus a torus roll 0.4 at the shaft foot.
  - **Fluted shaft:** 16-20 shallow flutes: CSG-subtract cylinders 0.35 across, 0.1 deep, running full height; or a 16-sided prism with every other face 0.08 recessed.
  - **Drum joints:** every 4-5 studs of height, 0.08 wide.
  - **Bands:** keep the gold band at y 6.4 and the lapis band at y 19.4. Each band is 0.8 tall and 0.15 proud, carrying a pattern of 8-12 small elements:
    - chequer squares 0.4;
    - lotus petals 0.5 x 0.7 in gold on lapis;
    - zigzag wedges.
  - **Papyrus / lotus capital** (facet piece `column__capital`): a bell flaring from the shaft radius 1.8 to 2.6 over 3.2 studs. It has 12 petal ribs alternating x1 / x0.93, a gold rim ring 0.3 at the top, and lapis or turquoise petal tips. The 5.6 top slab (abacus) stays, with a 0.15 chamfer.
- **Fallen columns:**
  - The drums keep their size and place, with drum joints every 3.5 (0.08).
  - **Broken ends:** cap each break with the facet piece `fallen_columns__drum_broken_end`: a jagged break surface with darker crack strips, the rim chipped 0.1-0.3.
  - **Plinth:** chipped corners (notches 0.3-0.6), split into 2-3 slabs with joints.
  - **Ground:** 3-5 rubble chips (0.4-1.2) and sand drifts (B8) around the base and against the drums.
- **Obelisk:**
  - **Taper:** one monolith narrowing from 3.8 at the base to 2.6 under the pyramidion. Make each face a tilted plate, or keep the 3 blocks but make each block taper (a 0.25 wedge strip per face). Joints only between the 3 blocks (0.08).
  - **Glyph columns:**
    - a recessed band 1.0 wide, 0.1 deep, down the middle of the front (-Z) face;
    - glyphs inside it 0.05 proud;
    - optional side faces with plain cartouche frames 0.1 proud.
    - **Keep the 6 glyphs exactly** (record below).
  - **Pyramidion:** gold, 4 faces (today 4 CornerWedges, 2.8 square x 3), with a Neon gold top 40 % and a PointLight warm (#FFD678, range 10, brightness 1). A 0.3 gold collar ring under it.
  - **Stepped base:** today's 2 steps plus a third step 7.5 x 0.6; block joints every 2.5.
- **Anubis** (seated pose and sizes as today; facet pieces `anubis__head` and `anubis__collar`):
  - **Head:** a jackal skull block 2.8 wide, a long tapered snout to z -1.9 (tip 0.7 wide), a gold nose tip, a dark mouth line.
  - **Ears:** tall and pointed, 0.9 wide at the base, 2.8 tall, leaning out 6°, with a gold or lapis inner face.
  - **Eyes:** almond-shaped Neon turquoise faces at today's eye places (±0.7, 16.8, front of the head).
  - **Headdress:** a gold crown band around the top of the skull (today's Crown). Lapis nemes lappets (today 0.9 x 4.4 x 2.2, parts) with 3-4 gold stripe strips 0.15 wide.
  - **Collar (usekh):** a broad beaded collar of 3 rings (gold / lapis / turquoise), 0.35 wide each, over the shoulders; a bead row = alternating colour facets. Facet piece `anubis__collar`.
  - **Arms and legs:**
    - arm bands and anklets: gold rings 0.5 tall, 0.1 proud, with one lapis stripe;
    - strong legs: the shin tapers from 1.6 to 1.3 toward the ankle, with a knee cap 0.2 proud;
    - forearms resting on the thighs as today, with hands (a 1.0 block with 3 finger grooves 0.05).
  - **Kilt (shendyt):** pleats as 5-7 vertical strips 0.25 wide, alternating x1 / x0.93 lapis, fanning slightly; the gold belt 0.6 with a buckle panel.
  - **Sandals:** a 0.2 sole under each foot (WoodTrunk #966840), plus a gold strap 0.15 over the toes.
  - **Plinth:** 2 steps with a 0.15 chamfer, a front inscription panel (recessed 0.1, a gold frame 0.15), corner notches.
- **Golden guardian / sphinx** (lying, head toward -Z, inside today's 5 x 5.1 x 10 box; facet pieces `sphinx__head` and `sphinx__paws`):
  - **Nemes stripes:** alternating gold / lapis 0.3 wide.
  - **Face:** eyes Neon turquoise (today's places: ±0.6, 4.75, -4.4), a nose ridge, a smooth closed mouth.
  - **Cobra (uraeus) badge:** on the forehead, gold, 0.5 tall.
  - **Paws:** stretched forward on both sides of the head: 2 paws 0.9 x 0.6 x 3.4 with 4 toe grooves.
  - **Body:** gold plates on the lid as 4-6 transverse plates 0.08 proud with lapis inlay strips between them (today's 4 stripes stay at the same z).
  - **Base:** carved: a 0.15 chamfer, a lapis band 0.3 around it, corner blocks.
- **Hieroglyph tablet:**
  - **Slab:** 0.5 -> 1.0 thick, front face chamfered 0.15.
  - **Carved gold frame:** border 0.5 wide, 0.15 proud, with an inner bevel strip 0.1 and corner rosettes (gold discs 0.6).
  - **Stand:** 2 side posts 0.8 x 3 x 1.2 plus a stepped foot 13 x 0.6 x 2.0, in dark sandstone #B89262.
  - **Glyphs:** carved with depth. Each glyph is sunk 0.15 into the slab with a 0.05 bevel, or kept raised 0.05 with a dark outline. **Shapes, positions and sizes stay exactly as below.**
- **Golden pyramid altar** (GoldPile_A):
  - **Tiers:** sandstone steps (#E2BE84 / #B89262) plated with gold: each tier has a gold top plate 0.2 and a gold edge band 0.3, with carved edges (0.15 chamfer). Keep today's 3 tier sizes and their turns.
  - **Steps:** small steps on the front: 2 risers 0.4.
  - **Corner ornaments:** small gold pyramids 0.6 or lotus buds.
  - **Gem setting:** the cyan gem (facet piece `altar__gem`) sits in a gold claw setting of 4 prongs 0.15 x 0.6 and a ring 0.2; Neon #5FD4FF with a cyan PointLight (range 8).
  - Coins and goblet stay.

**Glyph record (keep EXACTLY; kit space, after scaling each copy by its scale).**

*Hieroglyph_Panel* (front = -Z):
- **Common to all glyphs:** on the panel front at z -0.6, 0.2 thick.
- **Parts:**
  - Bars are Blocks.
  - Circles are Cylinders 0.2 x 1.6 x 1.6, axis along Z (orientation (0, 90, 0)).
  - The diamond is a Block 1.3 x 1.3 x 0.2 turned 45° about Z.
- **Colours:** g = Neon #FFC93C; s = SmoothPlastic #B89262.
- **The 12 symbols:** 4 columns (x -3.9 / -1.3 / 1.3 / 3.9) x 3 rows. As in all front views, +X shows on the LEFT, so x 3.9 is the left column seen from the front.

| Symbol | Column x | Row | Shape | Parts |
|---|---|---|---|---|
| 1 | -3.9 | bottom | Π | legs 0.5 x 1.4 at (-4.55, 2.0) and (-3.25, 2.0) + bar 1.8 x 0.5 at (-3.9, 2.95), s |
| 2 | -1.3 | bottom | circle | at (-1.3, 2.3), **g** |
| 3 | 1.3 | bottom | circle | at (1.3, 2.3), s |
| 4 | 3.9 | bottom | Π | legs at (3.25, 2.0) and (4.55, 2.0) + bar at (3.9, 2.95), s |
| 5 | -3.9 | middle | circle | at (-3.9, 5.1), s |
| 6 | -1.3 | middle | circle | at (-1.3, 5.1), s |
| 7 | 1.3 | middle | diamond | at (1.3, 5.05), **g** |
| 8 | 3.9 | middle | vertical bar | 0.5 x 2.0 at (3.9, 5.1), s |
| 9 | -3.9 | top | ⊥ | bar 1.8 x 0.5 at (-3.9, 7.35) + stem 0.5 x 1.4 at (-3.9, 8.3), s |
| 10 | -1.3 | top | vertical bar | 0.5 x 2.0 at (-1.3, 7.9), s |
| 11 | 1.3 | top | vertical bar | 0.5 x 2.0 at (1.3, 7.9), s |
| 12 | 3.9 | top | circle | at (3.9, 7.9), **g** |

The 4 gold borders (12 x 0.5 at y 0.25 and 9.75; 0.5 x 9 at x ±5.75) also sit at z -0.6; the panel itself is 12 x 10 x 0.5 at (0, 5, -0.25).

*Obelisk_A* (front -Z; all glyphs are Blocks 0.3 thick on the shaft's front face):

| y | Size | z | Colour |
|---|---|---|---|
| 5.9 | 0.7 x 1.8 | -1.95 | s |
| 8.8 | 1.6 x 0.6 | -1.95 | s |
| **14.9** | 0.7 x 1.8 | -1.7 | **Neon gold #FFC93C: the glowing yellow mark** |
| 17.8 | 1.6 x 0.6 | -1.7 | s |
| 23.9 | 0.7 x 1.8 | -1.45 | s |
| 26.3 | 1.6 x 0.6 | -1.45 | s |

The glyphs are all at x 0. The same layout is on every copy.

After the rebuild, Agent B checks each glyph by position, size, shape and colour (x scale) on the test copy and one game copy.

### B14. Desert props, furniture and treasures (owner task 2026-10-20)

Images: `docs/Desert_Images/05_Props_Furniture_Treasures/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_014933_before_desert_props_treasures_{ServerStorage,Workspace}.rbxm`.
All parts are SmoothPlastic; embers and gems are Neon.

**Functional content:**
- **None of the 6 kits has a script, ProximityPrompt, Seat, ClickDetector, light or pickup.**
- Their only extra children are 2 Attachments:
  - `FirePoint`, under Brazier_A's `Embers`: the fire point, like the other desert lamps;
  - `SmokePoint`, under Lamp_Djinn's `SpoutTip`.
- Keep both attachments at the same place on the new flame / spout tip.
- The throne is decoration only (no Seat; BossArenas.Desert decor), and the lamp has no pickup.

**Kits and copies** (all in `MapAssets.Desert.`; test copy in `_Staging.AssetPreview.Desert`):

| # | Object | Kit | Parts | Copies |
|---|---|---|---|---|
| 01 | terracotta jar | `ClayJar_A` | 3 | Desert_1 Camps x3, Desert_2 Village x14, Desert_2 Rocks x18, Desert_4 Props x4 |
| 02 | amphora | `ClayJar_B` | 7 | Desert_2 Village x7, Desert_4 Props x6, BossArenas.Desert x4 |
| 03 | rug | `Carpet_A` | 6 | Desert_1 Camps x3, Desert_2 Village x7, BossArenas.Desert x1 |
| 04 | golden stand | `Brazier_A` | 6 | Desert_2 Village x2, Desert_3 GateBraziers x2, Desert_4 Props x8, BossArenas.Desert x10 |
| 05 | throne | `Throne_Gold` | 21 | BossArenas.Desert x1 (+ test) |
| 06 | golden lamp | `Lamp_Djinn` | 12 | BossArenas.Desert x1 (+ test) |

**Today's shapes and real colours** (keep the colours; tone steps x1 / x0.93 / x0.86):

| Object | Parts |
|---|---|
| Jar | body cylinder 2.4 dia x 2.6 (y 0..2.6) #CC603E; neck 1.4 dia x 0.7 #BC5839; rim 1.9 dia x 0.35 #CC603E (top y 3.65). The photo shows a lid; the kit has none (the rim reads as one). |
| Amphora | foot 2.0 dia x 0.8 #DEA46E; body 3.4 dia x 3.0 (y 0.8..3.8) #DEA46E; band turquoise #40D0C4 3.5 dia x 0.6 at y 2.3; neck 1.8 dia x 1.0 #CE9866; rim 2.4 x 0.4 #DEA46E (top y 5.2); 2 block handles 0.5 x 1.6 x 0.5 at x ±1.5, y 3.2..4.8 |
| Rug | carpet 8 x 0.15 x 10 #D64A3E at z -1; 2 torn pieces #D64A3E / #C14238 at z +5..6; 2 turquoise-blue stripes #3C96AA 8.1 x 1 at z -5.4 and 2.2; gold diamond 3.2 turned 45° at z -1.5 |
| Stand | stone base 3.2 x 1 #B89262; stem 1.5 x 2.8 #E2BE84 (y 1..3.8); gold bowl 3.2 x 0.6 (y 3.8..4.4) + 2 crossed 4.2 squares #FFC93C / #E5B435 (y 4.4..5.3); Embers Neon #FF8C28 3 x 0.4 at y 5.3 with FirePoint |
| Throne | dais steps 13 x 1.2 x 11 #B89262 + 11 x 1.2 x 9 #E2BE84; seat 7 x 2.6 x 6 #E5B435 (top y 5.0); arms 1.5 x 3.6 x 6.4 #FFC93C + arm tops #E5B435 (y 6.0..6.7); arm gems Neon #40D0C4 1.9 x 1.3 x 1.6 at (±4.2, 7.35, -1.8); red cushion #D64A3E 7.4 x 0.7 x 6.4 (top 5.7); back 8.4 x 15 x 1.6 #FFC93C (y 2.4..17.4) with a lapis inlay #2C5CC8 5 x 9; Neon gold sun disc 4.4 dia at y 18.4; 2 gold spikes (4 CornerWedges each) at x ±3.6 |
| Lamp | foot 3 x 0.8 turned 45° #E5B435; stem 1.4 #FFC93C; body 5.4 x 1.0 x 3.2 #E5B435 + 7 x 2.6 x 4 #FFC93C (y 1.8..4.4) with a lapis band #2C5CC8 0.5; spout 4.6 x 1.1 x 1.4 tilted 28° up toward -X, tip at (-7.1, 4.9) with SmokePoint; handle loop at +X (3 blocks, x 3.9..4.95, y 1.7..5.3); lid 5 x 0.9 x 3 #E5B435 (top 5.3); knob gem Neon #40D0C4 1.0 turned (y 5.8) |

**Parts rules** (sizes in studs; joints, chamfers and the gradient as in sections A and B):

- **Wheel-thrown jar / amphora** (facet pieces `jar__body`, `jar__lid`, `amphora__body`, `amphora__handles`):
  - **Profile:** foot ring → belly (widest at 40-50 % of the height) → shoulder → neck → rolled rim (a torus-like lip 0.15-0.2 thick).
  - **Facets:** lathe with 14 sides; rings every 0.3-0.5 of height.
  - **Painted bands:** 1-2 bands 0.25-0.6 tall as separate faces on the belly or shoulder: today's turquoise band on the amphora; a dark #533E28 band and a cream line on the jar.
  - **Chips:** 2-3 small notches 0.1-0.2 on the rim. Optional: a darker tone step on 1-2 facets.
  - **Amphora handles:** curved loops 0.35 thick from the shoulder to just under the rim, standing out 0.6.
  - **Base ring:** a small ring stand under round-bottomed amphorae, 0.3 tall.
- **Woven rug:**
  - **Footprint:** keep the 8 x 10 carpet and its 2 torn pieces, 0.15 thick.
  - **Border:** a 0.6 turquoise-blue band inset 0.3 from the edge, with a zigzag or chequer of 0.4 squares in gold; keep today's 2 cross stripes.
  - **Fringes:** at the 2 short ends (z ends): 12-16 strands 0.12 wide x 0.6 long, linen #E8E2D0.
  - **Folded corner:** one corner turned back, a triangle of 2 x 2 flipped over, showing a darker underside (x0.86).
  - **Slightly wavy surface:** 3-4 gentle humps 0.1 high across the width.
  - **Centre:** the gold diamond (keep size and place) with a red centre diamond 1.0 and a 0.15 linen outline.
- **Golden stand** (Brazier_A; facet piece `stand__lotus_bowl`):
  - **Stone base:** 2 steps (3.2 / 2.6, chamfer 0.15).
  - **Stem:** a carved stone stem (the 1.5 stem, octagonal, with 2 engraved rings 0.1 deep).
  - **Bowl:** a gold lotus bowl of 8 petals flaring from radius 0.8 to 2.1 over 1.5 (y 3.8..5.3), with petal tips curling out, 2 engraved gold bands and a lapis rim line.
  - **Embers:** Neon #FF8C28 inside the bowl at today's height, with FirePoint kept. "A little glow" = a PointLight #FF8C28 range 10, brightness 0.8.
- **Throne** (facet pieces `throne__armrest_lion`, `throne__paw_foot`):
  - **Armrests:** lion armrests replace the arm blocks, same footprint (1.5-1.8 wide x 6.8 long x 3.6 + 0.7 tall, y 2.4..6.7). Each lion: a body along the arm, the head at the front (z -2.4) with a mane ring, the arm gem as its forehead jewel or held between its paws.
  - **Keep** the Neon gems at today's place (±4.2, 7.35, -1.8).
  - **Back:** a high back with a gold frame 0.6 wide, 0.15 proud, around the lapis panel (keep 5 x 9), and 3-4 gold feather or star inlays 0.05 proud.
  - **Sun disc:** keep the glowing disc, add a 0.3 gold ring and 2 uraei 1.2 tall beside it.
  - **Cushion:** the red cushion (keep) with a 0.15 gold piping and 4 gold tassels 0.25 x 0.5 at the corners.
  - **Legs:** 4 carved legs ending in gold lion paw feet (facet piece), 0.9 wide, under the seat corners.
  - **Dais:** the 2 steps with a 0.15 chamfer and a lapis band 0.3 on the upper step.
- **Golden lamp** (facet pieces `lamp__body`, `lamp__gem`):
  - **Body:** a curved genie lamp: an ellipsoid of 7 x 2.6 x 4 (lathe stretched along X) on today's stem and foot.
  - **Spout:** a tapered tube curving up to today's spout tip (-7.1, 4.9); keep SmokePoint there.
  - **Handle:** a loop curling out to x 4.95.
  - **Lid:** a domed lid with a gold collar.
  - **Gem setting:** a 4-prong gold setting holding the Neon turquoise gem (keep it Neon, size 1.0, y 5.8).
  - **Bands:** engraved gold bands (0.1 deep lines) and today's lapis stripe as a ring around the belly.

The organic pieces (jar, lid, amphora, handles, lion armrest, paw foot, lamp body, gem, lotus bowl) are facet data in
`Blender_Exports/Props/facets/` (made by `tools/blender/fyd_facets.py -- props`). Each is in its kit's space: place it at
the kit pivot with no offset, at the copy's own scale.

## C. Jungle: buildings and temples (owner task 2026-10-20)

Images: `docs/Jungle_Images/01_Buildings_and_Temples/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_084830_before_jungle_buildings_{ServerStorage,Workspace}.rbxm`.
The same quality target as sections A and B (fountain / well): stone blocks with joints, capped edges, small
readable details, soft gradients, clean saturated colours, no PBR.

### C0. Today's kits

| # | Object | Kit | Parts | Copies | Today's shape |
|---|---|---|---|---|---|
| 01 | stone face temple | `MapAssets.Gates.Gate_Jungle_4` (a GATE) | 52 | test `_Staging.AssetPreview.Jungle.Gate_Jungle_4`; game `Zones.Jungle.Jungle_4.Gate` | 65.8 x 52.7 x 16.9; see notes below |
| 02 | stone head | `MapAssets.Jungle.Carved_Face_Block` | 21 | test; Jungle_3 Ruins x5, Jungle_4 Props x4, Jungle_4 BossGate x2, BossArenas.Jungle x4 | 12.6 x 15.6 x 7.1; see notes below |
| 03 | ruined stone building | `MapAssets.Jungle.Ruin_Wall_A` | 10 | test; Jungle_3 Ruins x4 | 20.8 x 13.2 x 4.4; see notes below |
| 04 | stone wall, six slots | `MapAssets.Jungle.ArrowTrap_Wall` | 15 | test; Jungle_3 Ruins x4, Jungle_4 Props x4 | 12.6 x 10.95 x 6.7; see notes below |
| 05 | stilt hut | `MapAssets.Jungle.TribalHut_A` | 14 | test; Jungle_2 Props x3, BossArenas.Jungle x1 | 16 x 19.9 x 18.3; see notes below |

**01 stone face temple** (Gate_Jungle_4):
- **Face:** Face 56 x 22 x 11 (y 18..40), Forehead 58 x 3.4, Crown 30 x 5.4 + CrownTop 14 x 4 + 2 CrownSides, a gold Gem 5 x 5 turned 45° at (0, 45.2, -3.2).
- **Brows and eyes:** Brows 13.5 x 2.6 x 3.4 tilted ±9°; eye Sockets 10 x 6 dark, with Neon GlyphEyes 7.4 x 3.4 #78FFBE and dark Pupils at (±13, 31).
- **Nose and upper lip:** Nose a Wedge 8 x 10 x 5 at (0, 26.5, -6.5); UpperLip 28 x 5 x 13.
- **Sides:** Cheeks 16 x 18 x 12 + CheekBases; Ears 5 x 15 x 8 + gold Earrings 3.6 at x ±30.4; 2 Fangs 2.2 x 5 x 2.2 at (±13.2, 13.2, -5.4).
- **Moss and vines:** 4 Moss slabs, 4 Vine sticks.
- **THE MOUTH IS THE GATE:** a `Barrier` 24 x 16 x 3 at (0, 8, 0), attribute `BarrierDecorIsChildOfBarrier = true`. Its CHILDREN vanish when the gate opens: the 11 Teeth 3.2 x 5.2 x 0.9 (2 rows at y 3.1 and 12.9), MouthDark 24 x 5, 2 Lips 24 x 0.8, and the Neon Glyph.
- **Game copy only:** the model has attribute `SubZoneId = "Jungle_4"`, and the PriceSign holds SurfaceGuis PriceGuiFront / PriceGuiBack, each with a PriceLabel set by GateController.
- **Keep** the opening 24 x 16, the Barrier and its children, the attributes, the PriceSign and the collisions exactly.

**02 stone head** (Carved_Face_Block):
- Head 10 x 12 x 5 (y 0..12); Headdress 11 x 2 x 5.6; Crest 4.4 x 1.8; gold Gem 1.3 turned 45° at (0, 12.9, -2.45).
- Brow 9 x 1.4 x 1.0 at y 8.9; Sockets 2.8 x 2 with Neon GlyphEyes 1.8 x 1.1 #78FFBE at (±2.3, 7.3).
- Nose a Wedge 1.9 x 3.4 x 1.7; Mouth 5.6 x 1.4 dark; 4 Teeth 0.8; Ears 1.4 x 4 x 3; gold Earrings 1.2; 2 Moss slabs.
- No script, attribute or prompt.

**03 ruined stone building** (Ruin_Wall_A): Wall 20 x 10 x 3.6, Base 20.8 x 1.6 x 4.4, Cap 20.6 x 1.4 x 4.2, 2 Merlons 4 x 1.8, 3 front Blocks (2 dark slots #555C55 / #555D55 and one #7B8174), 2 Moss slabs. Nothing functional.

**04 stone wall, six slots** (ArrowTrap_Wall):
- Wall 12 x 10 x 2.6 between 2 Frames 12.6 x 1.2 x 3.2; a dark Panel 9.4 x 6.2 x 0.4.
- **6 Holes** 1.2 x 1.2 x 0.3 #292D29 at x -3 / 0 / 3, y 3.8 and 6.6, z -1.45.
- **2 Arrows** 0.25 thick #D6965C (#5C626E tip): one in the hole at (-3, 3.8), 3.2 long, with an ArrowTip; one in the hole at (3, 6.6), 2.6 long.
- The "lamp" = a Neon Glyph 1.6 x 0.6 #78FFBE at (0, 8.9, -1.25). Moss slab on top.
- **No script, tag or prompt today; keep the 6 holes, the 2 arrows and the lamp at exactly these places.**

**05 stilt hut** (TribalHut_A):
- 4 Stilts 1.1 x 5 #703E26 at (±5.6, ±5.6); Platform 14 x 0.8 x 14 #A86238 (y 4.6..5.4); Body 11 x 7 x 11 #D6965C (y 5.4..12.4) with 2 Bands #703E26.
- Door 4 x 5.6 #4A3022 (a dark slab, no prompt), DoorMask red diamond #C44632 1.6 at (0, 11.2, -5.7); Ladder 3 x 7.4 tilted 28° at the front.
- Roof 2 Wedges 15.5 x 7 x 7.75 #C4A068 (eaves y 12.4, ridge y 19.4) + Ridge 16 x 0.8 x 1.2 #703E26.
- Nothing functional.

All parts are SmoothPlastic; the glyph eyes and lamps are Neon. No kit has a script, a ProximityPrompt or a tag. The
only functional content is 01's gate contract.

### C1. Jungle palette (owner's examples next to the real colours; use the REAL ones, tone steps x1 / x0.93 / x0.86)

| Role | Owner's example | Real colour (keep) | Used by |
|---|---|---|---|
| mossy stone light | #9DB1AB | #848A7C | faces, walls, cheeks, crown |
| mossy stone mid | #7F9690 | #7B8174 | blocks |
| mossy stone dark | #4E6764 | #5C645C | bases, caps, brows, frames, nose, headdress |
| stone darkest | | #555C55 | slots |
| recess / sockets / holes / mouth | | #292D29 | |
| moss green | #3FA84A | #589642 (moss), #46AA3C (vines) | |
| bright leaf | #7ED957 | #60C448 / #78D246 | light moss, vines, leaves |
| vine green | #2FA84F | #46AA3C / #289642 | |
| dark wood | #4A2A1A | #4A3022 (door), #703E26 (stilts, bands, ridge) | |
| wood | | #A86238 (platform, ladder) | |
| hut walls | | #D6965C | |
| thatch | #D8C080 | #C4A068 (roof) | |
| gold | #F2C230 | #FFC93C | gems, earrings |
| glow (eyes, lamp) | turquoise #2BD3C8 | Neon #78FFBE (mint-cyan: keep it, it is the jungle glyph colour) | |
| teeth / fangs | | #E8E2D0 | |
| totem red | #C8392B | #C44632 (door mask) | |
| totem blue | #1FA6C9 | #3CAABE (totems, gates 2 / entry arch) | |
| flower pink | #E84A9C | #FF508C (Gate_Jungle_3 flowers) | |
| bamboo | #9ED05A | | |

### C2. Part rules (studs; joints, chamfers, caps and the gradient exactly as section A)

**Mossy stone blocks:**
- Courses 1.0-1.5 tall; blocks 2-4 long in running bond; joints 0.08-0.1 over a dark #5C645C core.
- Chamfer 0.15-0.25.
- 3 tone steps of #848A7C per block. A few blocks are greener: mix 15 % #589642.
- **Cracks:** 2-4 per face, dark #292D29 strips 0.08 wide, zig-zagging over 1-2 blocks.
- **Chipped corners:** notches 0.3-0.6.
- **Wider base:** 0.4 each side, 1.2-1.6 tall, with a darker cap.

**Moss as SOFT LAYERED PATCHES** (owner: "not flat green rectangles"; facet pieces `moss__drape_A/B/C`):
- **Layers:** 2-3 stacked rounded layers, each one smaller (70 %) and lighter: #589642 -> #60C448 -> #78D246.
- **Shape:** each layer has an irregular rounded outline, 0.1-0.2 thick, and thins to nothing at its edge (no hard slab sides).
- **Placement:** the patch sits on a top edge and DRAPES over it, down the face by 0.8-1.6, with a fuller drip lip at the bottom.
- **Where:** on cornice / cap / parapet edges, in the corner at the foot of walls, on brows and crowns.
- **How many:** 1 patch per 4-6 studs of edge, never a full strip. Replace today's flat Moss slabs by 2-4 drape patches each.

**Hanging vines** (facet piece `vine__strand`):
- Tapering segmented strands: 0.18 -> 0.06 thick, 4-6 segments with a slight sway.
- Small leaves every 0.8-1.2 (0.5 x 0.3, alternating sides, #78D246 / #60C448), stem #46AA3C.
- Hang them from cornices and brows in groups of 2-3 of different lengths (3-13: scale the piece in Y). Replace today's straight Vine sticks.

**Carved temple face** (01 and 02 the same family; 01 is about 5 x the size of 02):
- **Brows:** heavy ridges, a curved bar with a rounded top bevel overhanging the sockets by 0.6 (02) / 3 (01); facet pieces `face__brow` and `temple__brow`.
- **Eye sockets:** deep, recessed 0.3 (02) / 1.5 (01), with a bevelled rim.
- **Eyes:** keep today's Neon #78FFBE glyph eyes at their places, with the dark pupils on 01.
- **Nose:** carved with a bridge, wings and 2 nostrils (02: `face__nose_lips` with the lips round today's mouth; 01: `temple__nose`).
- **Lips and teeth:**
  - lips as rounded rolls 0.4 (02) / 1.2 (01) proud;
  - teeth as individual blocks with depth (0.4-0.9 proud of the dark mouth), slightly different heights, chamfered tips;
  - fangs on 01 as tapered points.
  - **On 01 the lips, teeth, MouthDark and Glyph stay children of the Barrier**: build them as parts, not as one facet union with non-Barrier parts.
- **Cheek plates:** 2-3 stepped plates on each cheek with joints.
- **Crown:** a stone-block crown with joints and capped blocks; the gold gem keeps its size and turn, in a 0.3 gold rim setting.
- **Ears:** a carved spiral (a 0.2-proud ring) with today's gold earrings.

**Recessed panel and slot frames** (04):
- **Panel:** recessed 0.3 into the wall with a carved stone frame 0.6 wide, 0.2 proud.
- **Slots:** the 6 slots keep their size and place. Each gets a bevelled frame (4 strips 0.25 wide, 0.1 proud, 45° corners) and a dark #292D29 back 0.4 deep.
- **The 2 arrows (tools):** shaft #D6965C 0.25, a fletching of 2 small linen / red quads, the iron tip. Same positions and angles.
- **Lamp:** today's Neon glyph becomes a lamp in a stone bracket. A bracket 2.2 x 0.8 x 1.0 with a chamfered underside holds a Neon #78FFBE glow box 1.6 x 0.6 (keep today's size and place, y 8.9) behind 2 stone bars; add a PointLight #78FFBE, range 10, brightness 0.8.

**Stilt hut** (05):
- **Stilts:** 1.1 square (keep) with a 0.15 chamfer. X-shaped cross beams 0.4 between the stilts under the platform, with rope ties (#C4A068 rings 0.15) at the joints.
- **Platform:** planks 0.8-1.0 wide with 0.06 gaps along X; a railing 1.2 high of posts every 2.5 and a top rail 0.3 around the front and sides, open at the ladder.
- **Walls:** framed planks: vertical planks 0.9 wide, a frame 0.4 at the corners and under the roof (today's Bands).
- **Door:** today's opening, a hanging cloth (#C44632 with a #E8E2D0 stripe) in 2-3 folds; keep the red diamond mask above it.
- **Roof:** layered thatch: 4 rows of straw bundles per side, overlapping, with a jagged fringe (facet piece `hut__thatch_roof`); a ridge beam (keep) with a straw cap.
- **Hanging details:** 2 gourds (balls 0.6-0.8 #C4A068 / #A86238 on a 0.1 cord) and a small lantern (#4A3022 frame, Neon warm #FFD678 core 0.4) under the eaves.
- **Ladder:** today's angle, as 2 rails 0.3 plus rungs every 0.9.

### C3. Jungle gates and entrances (owner task 2026-10-20, PROMPT_02)

Images: `docs/Jungle_Images/02_Gates_and_Entrances/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_101002_before_jungle_gates_{ServerStorage,Workspace}.rbxm`.
Same quality target as A / B / C: joints, capped edges, rope and iron bindings, soft gradients, no PBR. The colour
roles and tone steps are those of C1; the moss and vine rules are those of C2 (reuse `moss__drape_*` and
`vine__strand`).

**Kits** (all kit pivots at the centre of the passage at ground level, front -Z):

| # | Object | Kit | Parts | Test zone | Game copies |
|---|---|---|---|---|---|
| 01 | palisade gate with guards | `MapAssets.Gates.Gate_Jungle_2` | 70 | `_Staging.AssetPreview.Jungle.Gate_Jungle_2` (-3070, 0, 2310) | `Zones.Jungle.Jungle_2.Gate` (6000, 0, 145) |
| 02 | stone vine barricade gate | `MapAssets.Gates.Gate_Jungle_3` | 54 | `..Jungle.Gate_Jungle_3` (-2985, 0, 2310) | `Zones.Jungle.Jungle_3.Gate` (6000, 0, 435) |
| 03 | totem arch | `MapAssets.Gates.EntryArch_Jungle` | 54 | `..Jungle.EntryArch_Jungle` | `Zones.Jungle.Jungle_1.EntryArch` (one Base at (5984.5, 0.75, -90): pivot near (6000, 0, -90)) |
| 04 | root arch | `MapAssets.Jungle.Root_Arch_A` | 19 | `..Jungle.Root_Arch_A` | Jungle_1 `Decor.Props` x2, Jungle_3 `Decor.Ruins` x2 |
| 05 | rock cave entrance | `MapAssets.Jungle.Jaguar_Den_Rocks` | 9 | `..Jungle.Jaguar_Den_Rocks` | Jungle_3 `Decor.Ruins` x1, `BossArenas.Jungle.Decor.Props` x1 |

**Not these gates: the SyncMapProps rules from props batch 2.** The existing rules `entry_arch`, `gate_palisade` and
`gate_barricade` (and `gate_mine`) belong to the PLAINS gates: `EntryArch_Plains` / `Plains_1.EntryArch`,
`Gate_Plains_2` / `Plains_2.Gate`, `Gate_Plains_3` / `Plains_3.Gate`. The jungle gates need NEW propIds, for example
`jungle_palisade_gate`, `jungle_barricade_gate`, `jungle_totem_arch`, `root_arch`, `rock_cave`. Match them like
`face_temple_gate`: `m.Name == "Gate"` with parent `Jungle_2` / `Jungle_3`, and `m.Name == "EntryArch"` with parent
`Jungle_1`.

**Gate contracts** (keep exactly, as for the Plains and desert gates):
- **01 and 02:**
  - a `Barrier` 24 x 16 at (0, 8, 0), CanCollide on, with attribute `BarrierDecorIsChildOfBarrier = true`;
  - everything parented to the Barrier vanishes when the gate opens, so the door / barricade decor must stay CHILDREN of the Barrier, and nothing else may be;
  - the game copies carry `SubZoneId = "Jungle_2"` / `"Jungle_3"` on the model and a `PriceSign` 12 x 4 x 0.5 with SurfaceGuis `PriceGuiFront` / `PriceGuiBack` -> `PriceLabel` (+ UIStroke).
- **03:** not a gate (no Barrier). The game copy has `ZoneId = "Jungle"` on the model and a `NameSign` 14 x 4 x 0.5 at (0, 24.6, -1) with SurfaceGuis `NameGuiFront` / `NameGuiBack` -> `NameLabel`.
- **Torches:** the `Ember` parts (Neon #FF8C28) of 01 and 03 each hold an `Attachment` named `FirePoint`; keep the names and the attachments.
- **04 and 05:** nothing functional.
  - 05's model has attributes `SourceAssetId` / `SourceCreator` (a Toolbox asset).
  - Its 3 Rocks, Roof and Moss are MeshParts.
- **No script, ProximityPrompt, tag, Humanoid or teleport** in any of the five (in the kits and in the game copies).

**THE 2 GUARDS OF 01 ARE NOT NPCs.** They are 2 totem stacks built into the Gate_Jungle_2 model (not under the Barrier):
- **Position:** each at x ±16.2, z -4.6.
- **Parts:**
  - 3 TotemHead cubes 3.6: red #C44632 at y 1.8 with white eyes, teal #3CAABE at y 5.4 with a yellow Beak wedge, tan #D6965C at y 9.0 with dark eyes;
  - a red Wing 8.4 x 2 x 0.7 at y 9.2.
- **9 parts each:** TotemHead x3, Eye x4, Beak, Wing.
- **Rule:** the owner says keep them as they are: copy these 18 parts unchanged, same positions, same colours.

**Today's shapes:**

01 (Gate_Jungle_2):
- **Logs:** 10 Logs 3 x 3 (heights 18-23, two colours per log #A15E35..#A96338 / #63412A..#714A30) at x ±14.6 / ±17.75 / ±20.9 / ±24.05 / ±27.2, each with a LogTip (a 2.1 square turned 45°).
- **Bands:** 4 Bands 16.6 x 1.2 at y 6 and 14.
- **Lintel:** 32 x 3 x 3.4 at y 17.5, with 2 RopeWraps #C4A068.
- **Door = the Barrier** 24 x 16 x 1.4 #A86238, with children: 5 Seams, 2 CrossBands #703E26, the teal Mask diamond 5 x 5 at z -0.9, 2 gold MaskEyes, a red MaskMouth.
- **Torches:** 2 TorchPoles 0.8 x 8 at (±13.4, 4, -7.4) + bowl + ember.
- **Sign:** SignBack 13.4 x 5.2 + PriceSign at y 21.7.
- **Skull:** 2.6 x 2.2 x 2.2 #E8E2D0 at (0, 25.4, -1), 2 dark SkullEyes, 2 Horns 0.7 x 3 tilted ±35°.

02 (Gate_Jungle_3):
- **Piers:** 2 Piers 12 x 20 x 8 #848A7C at x ±18.2 with PierBase 13 x 2 x 9 and PierCap 13 x 1.6 x 9 #5C645C. Dark Block plates, Neon #78FFBE Glyph diamonds 2 x 2 at (±18.2, 12.5, -4.1).
- **Top:** Lintel 26 x 5.6 x 7.6, Keystone, 2 UpperCourses, 4 flat Moss slabs.
- **Roots:** 2 big Roots 3 x 25 (support beams) at x ±24.6; a RootTop 34 x 2.6 #4A3022.
- **Barricade = the Barrier** 24 x 16 x 3 #4A3022, with children: 7 Roots 1.8-2.8 x 16 (tilted ±8..36°), 2 RootCross 22 x 2, 4 Vines, 8 Leaves 2.4 x 1.5, 3 Flowers (#FFAA28, #FF508C, #BE5AFF).
- **Sign:** PriceSign at (0, 19, -4.5) + SignBack.

03 (EntryArch_Jungle):
- **Totems:** 2 totems at x ±15.5 on a Base 6.2 x 1.5 #4A3022. 4 TotemHeads 4.3-4.6 stacked: red (white eyes), tan with a yellow Beak, teal with 2 Wings 5.4 x 2.6 tilted ±16°, brown with gold eyes. A Bowl + Ember on top.
- **Beam:** 37 x 3 x 3 #703E26 at y 20.6, 4 VineWraps, 4 Vine sticks, 2 Flowers, 2 LeafTufts. NameSign + SignBack at y 24.6, a gold Mask diamond 3 x 3 at (0, 28.3, -0.5).
- **Passage:** 26.4 wide (the totems' inner faces at x ±13.2) x 19.1 tall (under the Beam).

04 (Root_Arch_A):
- **Sides:** each side 4 Root blocks climbing in steps (y -2.1..8.1 at x ±15.75, then at y 10.25, 16.25, 20.25), a crown Root 12.2 x 4.4 (underside y 19.3), 2 diagonal RootSmall braces, 2 RootFoot wedges at x ±19.5.
- **Moss and vines:** 3 flat Moss slabs, 3 Vine sticks.
- **Colours:** #422B1E..#68442C, #4A3022.
- **Passage:** 25.5 wide at the ground (inner faces x ±12.75), about 17.6 at y 16, 19.3 tall in the middle.

05 (Jaguar_Den_Rocks):
- **Rocks:** left rock 17 x 15 x 16 #848A7C at (-15, 7, 3), right 17 x 13.5 x 16 #7D8376 at (15, 6.3, 3), back 15 x 18 x 14 #5C645C at (0, 8.5, 13).
- **Top:** Roof slab 36 x 7 x 20 #5C645C at (0, 16.5, 4) (underside about y 13), Moss 24 x 2.4 x 13 #589642 on top.
- **Opening:** the dark Shadow 14 x 11 x 6 #292D29 at (0, 5.5, 5.5), CanCollide off. The opening is 14 wide x 11 tall, its front at z 2.5.
- **Bones:** 2 Bones 3 / 2.4 x 0.5 and a Skull 1.5 x 1.3 x 1.6 in front (z -4.5..-7.5).

**Real colours** (keep): wood #A86238 / #703E26 / #4A3022 / #68442C, logs #A15E35..#A96338 and #63412A..#714A30, roots
#422B1E..#734B31, rope #C4A068, stone #848A7C / #7D8376 / #5C645C, recess #292D29, bone #E8E2D0, totem red #C44632,
totem teal #3CAABE, totem tan #D6965C, gold #FFC93C, glyph Neon #78FFBE, ember Neon #FF8C28, leaf #78D246 / #289642 /
#60C448, vine #46AA3C, moss #589642, flowers #FFAA28 / #FF508C / #BE5AFF.

**Part rules:**

**01 palisade gate:**
- **Logs:**
  - keep today's 10 logs, sizes and two-tone colours;
  - each log becomes an octagonal post (corner chamfers 0.5) with a sharpened point: 4 sloped facets meeting at the tip, 2.4 tall, replacing the turned LogTip;
  - bark lines: 2 dark strips 0.1 per visible face;
  - a few knots (0.5 discs, x0.86).
- **Bindings:**
  - rope lashings #C4A068: 3 turns of 0.25 rings at both band heights;
  - iron bands #5C626E 0.3 wide with 2 rivets (0.25 cubes) per log on today's Bands, which keep their y.
- **Door (all Barrier children):**
  - **Planks:** 2 leaves of vertical planks 1.9-2.1 wide with 0.08 gaps and 3 tone steps (the Seams become the gaps / the centre split).
  - **Frame:** a Z-brace per leaf (2 horizontal battens 0.6 + 1 diagonal) on the 2 CrossBands' heights.
  - **Hinges and studs:** 3 iron strap hinges per leaf (0.5 x 3.5 with a round end); iron studs.
  - **Emblem:** a carved teal face in a carved frame: today's Mask diamond 5 x 5 #3CAABE with a raised rim 0.3, brows, gold eyes (keep MaskEyes) and a red mouth (keep MaskMouth) with 3 teeth.
- **Torches:** 2 torches on today's poles: an iron cage bowl (4 bars), Neon ember (keep Ember + FirePoint), a rope wrap on the pole.
- **Sign:**
  - a carved frame round the PriceSign (4 strips 0.5, mitred);
  - the horned skull on top (facet piece `skull__horned`, replacing Skull, SkullEyes and Horns): long snout, deep dark sockets, nasal holes, curved ribbed horns;
  - 2 crossed bones (cylinders 0.4 with ball ends 0.6) behind it, a rope hanging.
- **Guards:** unchanged (see above).

**02 stone vine barricade:**
- **Piers:**
  - cut stone courses 1.6-2.0 tall, blocks 3-4 long, joints and chamfers as C2;
  - a carved diamond marker frame (0.3 proud, #5C645C) round each Neon glyph (keep it);
  - base and cap with chamfered edges;
  - moss drapes on the caps and the lintel instead of the slabs.
- **Barricade (all Barrier children):**
  - the 7 logs as octagonal logs with sawn, lighter end caps;
  - rope lashings at every crossing (2-3 turns of 0.25);
  - vine tangles: 2-3 `vine__strand` per side running over the logs, plus leaf clusters;
  - small glowing gems: Neon 0.5 diamonds #78FFBE / #BE5AFF on 2-3 logs;
  - flowers: 5 petals round a gold centre, the 3 colours.
- **Sign:** a carved frame round the PriceSign.
- **Support beams:** the 2 big side Roots become braced beams with rope ties.

**03 totem arch:**
- **Totems:**
  - each TotemHead becomes a carved figure head on today's cube (keep size and colour): a brow ridge, eyes in sockets (keep the white / dark / gold eyes), a carved nose or beak, a mouth with teeth, cheek plates, ear blocks;
  - the tan head keeps its Beak;
  - between heads a 0.3 darker joint ring.
- **Wings:** carved feathered wings (facet pieces `totem__wing_L/R`): 3 rows of feathers, each row shorter and lighter, with scalloped tips.
- **Headdress and plinth:** a headdress on the top head (3 feather plumes, gold band) under the bowl; a stepped base plinth (2 steps, chamfered).
- **Beam:**
  - jointed: 3 timbers with 2 visible joints and pegs;
  - rope / vine wraps (keep the 4 VineWraps' places);
  - 2-3 hanging `vine__strand` per side, the 2 flowers, leaf tufts as clusters;
  - the gold Mask diamond in a carved frame (gold emblem).
- **Keep** the NameSign + GUIs and the passage 26.4 x 19.1.

**04 root arch** (facet pieces `root_arch__side_L` / `side_R` / `crown`):
- **Roots:**
  - tapering twisted roots, grounded: each side has a main root (radius 3.0 -> 2.2) curving from a flared foot to the crown, with 2 thinner roots twisting round it;
  - small roots splay into the soil;
  - bark lines and knots on the main root.
- **Crown:** a thick root with a thinner root wrapped round it, and leaf clusters on top.
- **Moss and vines:** `moss__drape` patches on the top, 3-5 `vine__strand` hanging from the crown.
- **Base:** mushrooms (stem 0.3, cap 0.9 #C44632 with #E8E2D0 dots) and flowers at the base.
- **Keep** the passage 25.5 wide at the ground, 19.3 tall in the middle.

**05 rock cave** (facet pieces `cave__rock_L` / `rock_R` / `top_slab`):
- **Rocks:** faceted low-mid poly rocks made of stacked natural layers (each layer a little offset, 3 tone steps, darker at the bottom), with 2-3 dark cracks.
- **Top slab:** layered, with a soft moss cap (2 layers) and grass tufts (3-blade clusters #78D246 / #60C448), moss drapes over its front edge.
- **Opening:** the dark interior stays (keep the Shadow part) behind a stone lip: a low worn threshold stone 14 x 0.6 x 1.2 #5C645C at the front.
- **Bones:** 2-3 bones (cylinder 0.35 + ball ends) and a small skull (facet piece `skull__small`) at today's places.
- **Keep** the opening 14 x 11 at z 2.5 and the collisions (rocks collide, the Shadow does not).

### C4. Jungle ruins and stonework (owner task 2026-10-20, PROMPT_03)

Images: `docs/Jungle_Images/03_Ruins_and_Stonework/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_112644_before_jungle_ruins_{ServerStorage,Workspace}.rbxm`.
The C1 colours, C2 stone / moss / vine rules and the A recipe apply. These kits have MANY copies, so every detail
is cheap: parts first, facet pieces only for the shapes parts cannot do.

**Kits** (all in `MapAssets.Jungle`, pivot = bottom centre, front -Z, SmoothPlastic + Neon accents):

| # | Object | Kit | Parts | Copies (placed) | Notes |
|---|---|---|---|---|---|
| 01 | stepped ruin block | `Ruin_Wall_Broken` | 9 | test 1 + `Jungle_3.Decor.Ruins` 6 = **7** | one Jungle_3 copy has its parts resized to 0.8 (Model scale 1) |
| 02 | stone stairs | `Ruin_Stairs` | 10 | test 1 + `Jungle_3.Decor.Ruins` 1 = **2** | WALKABLE: tread heights below |
| 03 | broken pillar and blocks | `Ruin_Pillar_Broken` | 6 | test 1 + `Jungle_3.Decor.Ruins` 6 + `Jungle_4.Decor.Props` 6 = **13** | 8 copies resized to 0.8 (2 in Jungle_3, all 6 in Jungle_4) |
| 04 | mossy slabs | `SteppingStone_A` | 3 | test 1 + `Jungle_2.Decor.Crossings` 4 = **5** | WALKABLE stepping stones over the Jungle_2 water: flat top at pivot y + 1.6; Skirt is a Toolbox MeshPart (SourceAssetId) |
| 05 | glowing floor pad | `Glyph_Tile` | 6 | test 1 + `Jungle_3.Decor.Ruins` 7 + `Jungle_4.Decor.FloorDecor` 19 + `BossArenas.Jungle.Decor.FloorDecor` 9 = **36** | one BossArenas copy resized to 1.6 |

`Ruin_Pillar_A` (the whole pillar, 7 parts, 11 copies) is NOT in this prompt.

**What the kits do (checked):**
- No script, ProximityPrompt, tag, attribute (except 04's SourceAssetId / SourceCreator) or touch handler in any kit or copy. `src/` names none of them.
- **05 is decoration only, not a checkpoint or teleport.**
  - All 6 parts are CanCollide off: it lies on the floor.
  - The only touch pads in the code are the sub-zones' `HubReturn` BaseParts (ZoneService, `Touched` -> ToHub) and the hub portals (PortalController). Both are separate parts, not Glyph_Tile.
  - Keep the Neon glow.
- **SyncMapProps** already has the rules `jungle_ruin_block`, `jungle_ruin_stairs`, `jungle_broken_pillar`, `mossy_slabs` and `glyph_floor_pad`. Copies with part-resized sizes need a `bakedScale` like `golden_altar`: Ruin_Wall_Broken x1 at 0.8, Ruin_Pillar_Broken x8 at 0.8, Glyph_Tile x1 at 1.6.
- **Collisions to keep:**
  - 01: Base, Walls and Rubble collide; Moss doesn't.
  - 02: Steps, Cheeks and Rubble collide.
  - 03: Base, Stump, Break, Drum and Chunk collide.
  - 04: Skirt and Stone collide.
  - 05: nothing collides.

**Today's shapes:**

01 Ruin_Wall_Broken:
- **Base:** 20.8 x 1.2 x 4.4 #5C645C.
- **3 stepped Wall blocks, 3.6 deep:**
  - x 3..10, 3.2 tall, #848A7C;
  - x -3..3, 6.5 tall, #8D9384;
  - x -10..-3, 10 tall, #848A7C.
- **Moss:** flat slabs on the 2 lower tops and one on the tall block's front.
- **Rubble:** 2 tilted blocks 2.6 x 2 x 2.4 / 3 x 2.4 x 2.6 in front at (8.6, 0.9, -3.8) and (5, 1.1, -4.6).

02 Ruin_Stairs: climbs toward +Z. Tread tops and fronts are EXACT, keep them:

| Step | Tread top y | Front z | Depth | Width (x) | Colour |
|---|---|---|---|---|---|
| 1 | 1.5 | -7.5 | 3 (to -4.5) | -7..7 | #626A62 |
| 2 | 3.0 | -4.5 | 3 (to -1.5) | -7..7 | #83897B |
| 3 | 4.5 | -1.5 | 3 (to 1.5) | -7..7 | #575F57 |
| 4 | 6.0 | 1.5 | 3 (to 4.5) | -7..5 | #83897B |
| 5 | 7.5 | 4.5 | 3 (to 7.5) | -7..2 | #575F57 |

- **Risers:** all 1.5.
- **Cheeks (side walls) #5C645C:**
  - left x -9..-7, z -7.5..7.5, top 4.6;
  - right x 7..9, z -7.5..0.5, top 2.6.
- **Moss:** 2 flat slabs: on step 3 (6 x 0.3 x 2.6, top 4.8 = 0.15 proud of the tread) and on the left cheek.
- **Rubble:** 1 block 3 x 2.2 x 2.6 at (9.5, 1, 4.5).

03 Ruin_Pillar_Broken:
- **Base:** 6 x 1.6 x 6 #5C645C.
- **Stump:** 4.2 x 6.5 x 4.2 #848A7C (y 1.6..8.1).
- **Break:** a Wedge 4.2 x 2.6 x 4.2 on top (y 8.1..10.7), turned 35° = the slanted broken top.
- **Moss:** slab 4.6 x 0.5 x 3 at y 8.2.
- **Fallen pieces:**
  - Drum: a block 4.2 x 4.2 x 6 #808678 lying at (7.5, 2.1, 2), turned 30°;
  - Chunk: 3 x 2.4 x 3 #5C645C, tilted, at (4.5, 1.1, -5).

04 SteppingStone_A:
- **Stone:** 6.4 x 1.6 x 6 #848A7C (y 0..1.6), turned 18°.
- **Skirt:** MeshPart 7.6 x 1.5 x 7.4 #5C645C at y 0.4, turned 50° (the lower slab).
- **Moss:** 3.4 x 0.2 x 2.8 #589642 on top, turned 40°.

05 Glyph_Tile:
- **Tile:** 8 x 0.3 x 8 #5C645C.
- **Neon #78FFBE inlay, top y 0.36:** a square frame of 4 strips (5 x 0.6 at z ±2.2, 0.6 x 3.8 at x ±2.2), 0.1 thick, and a centre diamond 1.5 turned 45°.

**Real colours** (keep): stone #848A7C / #8D9384 / #83897B / #808678 light, #626A62 / #5C645C / #575F57 dark, moss #589642 /
#60C448, glyph Neon #78FFBE.

**Part rules:**

**01 stepped ruin block:**
- **Blocks:** each Wall block becomes cut blocks in courses 1.2-1.8 tall, 2-3.5 long, running bond, 0.08 joints over a dark core.
- **Tones:** a different tone per block: STEPS x mix of #848A7C / #8D9384, 1 in 5 greener (15 % #589642).
- **Edges:** chipped corners (0.3-0.6 notches) on the exposed ends, broken irregular tops (1-2 blocks missing or set lower on each step).
- **Base:** wider (keep 20.8 x 1.2 x 4.4) with a chamfered top edge.
- **Moss and vines:** `moss__drape_A/B` on every step edge instead of the flat slabs (1 per 3-4 studs); 1-2 short `vine__strand` (scale 0.5) on the tall block.
- **Rubble:** at the foot: today's 2 rubble blocks as chipped stones (`ruins__rubble_A/B/C`), plus 2-3 small ones (scale 0.4-0.6).
- **Keep** the footprint and collisions.

**02 stone stairs:**
- **Treads:**
  - keep every tread top and front exactly (table above);
  - each step is 2-3 blocks along x with joints;
  - a bevelled nose: a 0.15 chamfer on the front-top edge only (the tread top stays flat to within 0.15 of the front);
  - worn corners: the 2 front corners of each tread notched 0.4 x 0.15 high, never more;
  - tone per block.
- **Cheeks:** side walls with a capped top: a 0.3 cap 0.2 wider each side, joints every 3, chipped ends.
- **Moss:** soft moss in the joints: thin `moss__drape_B` patches (scale 0.5-0.7) at the back of 2-3 treads and on the cheek tops. Moss on a tread must not rise more than 0.15: the old Step-3 moss slab is replaced by a drape lying in the back corner.
- **Plants:** 3-4 small plants (`ruins__plant_tuft` / `fern`) in the corner between the treads and the cheeks, CanCollide off.
- **Collision:** keep it on the step parts. Detail parts (caps, chips, moss, plants) use CanCollide off, or are flush with the tread, so the walk surface does not change.

**03 broken pillar and blocks:**
- **Stump:** a 4.2 square shaft with 0.3 chamfered corners, 2 carved bands (0.25 proud, 0.6 tall, #5C645C) at y 3.0 and 6.3, a vertical crack.
- **Broken top:** the `Break` wedge becomes a jagged slanted break (facet piece `ruins__pillar_break`): rising from y 8.1 on one side to 10.7 on the other, with a jagged rim and 2-3 chips off the edge.
- **Plinth:** today's Base with a chamfered top edge and 2 chipped corners.
- **Fallen pieces:** the Drum as a cut block with chamfered edges and a broken end (keep size and place); the Chunk as `ruins__rubble_B`.
- **Moss and vines:** a moss drape on the break and on the plinth edge, 1 short vine.
- **Keep** the footprint and collisions.

**04 mossy slabs** (stepping stones):
- **Slabs:** 2 slabs of different sizes, offset and turned like today (facet pieces `ruins__slab_top`, on today's Stone, and `ruins__slab_low`, on today's Skirt). Irregular cut outlines with chipped corners, a 0.15 bevel on the top edge, 2 cracks.
- **Top:** keep the TOP SURFACE FLAT at y 1.6 (players hop on it).
- **Moss and plants:** moss as a soft 2-layer patch lying on top (0.1-0.15 thick) instead of the flat slab, tiny plants (`ruins__plant_tuft`, scale 0.4) in the gap between the slabs.

**05 glowing floor pad** (decoration, no collision):
- **Slab:** today's 8 x 8 tile, 0.3 thick, with a 0.12 bevel (4 sloped edge strips) and darker edge.
- **Grooves:** carved square grooves: the Neon frame sits in a groove (a darker #3E453E strip 0.9 wide, 0.05 lower) so it reads as an inlay.
- **Inlay:** keep the 4 Neon strips, the diamond, their places and #78FFBE.
- **Diamond:** the centre diamond in a raised stone setting (0.1 ring), with a PointLight #78FFBE, range 8, brightness 0.6, for the soft glow. Only on the test / Jungle_3 copies, or on 1 in 3 copies, to keep the light count low (36 copies).
- **Moss:** small moss tufts (`moss__drape_B` flattened or 2 small patches) on 2 opposite corners.

### C5. Jungle totems, shrines and water (owner task 2026-10-20, PROMPT_04)

Images: `docs/Jungle_Images/04_Totems_Shrines_Water/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_121735_before_jungle_totems_{ServerStorage,Workspace}.rbxm`.
The C1 colours, the C2 moss / vine rules and the A recipe apply; the totems are the same family as the C3 totem arch
(EntryArch_Jungle) and the palisade gate's guards.

**Kits** (all in `MapAssets.Jungle`, pivot = bottom centre, front -Z):

| # | Object | Kit | Parts | Placed copies |
|---|---|---|---|---|
| 01 | tall totem pole | `Totem_B` | 26 | **5**: test 1, `Jungle_1.Decor.Props` 2, `Jungle_2.Decor.Props` 1, `BossArenas.Jungle.Decor.Props` 1 |
| 02 | totem figure | `Totem_A` | 18 | **5**: test 1, `Jungle_1.Decor.Props` 3, `Jungle_2.Decor.Props` 1 |
| 03 | golden shrine | `Golden_Altar` | 13 | **2**: test 1, `Jungle_4.Decor.Props` 1 (part-resized x1.6, at (6000, 0, 950)) |
| 04 | water pool with gold corners | `Temple_Pool` | 14 | **4**: test 1, `Jungle_3.Decor.Ruins` 1, `Jungle_4.Decor.Props` 2 (both part-resized x1.2) |

**The golden shrine is NOT the desert "golden_altar".** The existing SyncMapProps rule `golden_altar` is the desert
golden pyramid altar `GoldPile_A`; its Jungle_4 copy stands next to this shrine at (6014, 0, 953). The jungle shrine
needs its own propId, e.g. `golden_shrine` (names `Golden_Altar`). Its Jungle_4 copy has its parts resized x1.6 with
Model scale 1, so it needs a `bakedScale`; the pool's 2 Jungle_4 copies need one too (x1.2).

**Functions (checked):**
- No script, ProximityPrompt, tag, attribute, ClickDetector or touch handler in any of the 4 kits or their copies.
- `src/` names none of them (no Temple_Pool / Totem / Shrine / Altar / heal / swim logic for props). "Heal" exists only as an admin-panel button, "Swim" only as a pet gait.
- The only prompt near the shrine is the Jungle_4 BossGate's own `Interact` ProximityPrompt ("Enter", "Ancestral Gorilla's Sanctum") at (6000, 4.6, 983.5), 33 studs away and part of the BossGate model, not of the shrine: do not touch it.
- **The pool's water is a part:**
  - `Water` 20 x 0.5 x 20 #30C4BE, Transparency 0.25, CanCollide off, top y 0.8;
  - over a `Basin` 20 x 0.2 #1E8C96, CanCollide off;
  - no terrain water in the kit; players walk through it.
  - Keep it non-colliding.
- **Collisions:**
  - totems: the Heads, Base, Ears, Wings, Brow and Crown collide (eyes, mouths, beak, tusks, feathers, horns do not);
  - shrine: the 2 Steps, Table and GoldTop collide;
  - pool: the 4 Rims and 4 Posts collide.

**Today's shapes:**

01 Totem_B (21.6 tall):
- **Base:** 4.8 x 1.2 #4A3022.
- **5 heads, bottom to top** (keep each colour and height):
  1. blue #3CAABE 3.4 cube at y 2.9 with white eyes, a dark mouth and 2 white Tusks 0.5 x 1.6 tilted forward;
  2. tan #D6965C 3.7 at y 6.3, dark eyes;
  3. red #C44632 3.4 at y 9.7, white eyes, 2 gold #FFC93C "Ears" 1.6 x 2.6 (the small arms);
  4. brown #68442C 3.7 at y 13.1, white eyes, a red mouth;
  5. yellow #FFC93C 3.4 at y 16.5, dark eyes.
- **Feathers on top:** #FFAA28 / #3CAABE / #C44632, 0.8 x 3-3.6, the side ones tilted ±18°.

02 Totem_A (16.7 tall):
- **Base:** 5.2 x 1.4 #4A3022.
- **Heads, bottom to top:**
  - red 4.0 head (white eyes, dark mouth);
  - blue 4.4 x 3.6 head with gold eyes and a yellow Beak wedge 1.6 x 1.8 x 2.4;
  - tan 4.0 x 3.6 head with dark tall eyes and 2 blue Wings 5 x 2.4 x 0.7 at (±4.3, 11.2) rising outward 18°.
- **Hat:** red Brow 4.6 x 0.7 (the hat brim) at y 12.6, red Crown 3 x 2.2 x 3, 2 white Horns 0.7 x 2.6 tilted ±20°.

03 Golden_Altar (9.05 tall):
- **Steps:** 12 x 1.4 x 8 #5C645C, then 10 x 1.4 x 6 #848A7C.
- **Table:** 8 x 2.2 x 4.4 #848A7C (the front panel). Neon #78FFBE Glyph 3 x 1 on its front (z -2.3), 2 gold Trims at the front corners.
- **Top:** GoldTop 8.6 x 0.6 x 5 #FFC93C at y 5.3, 2 gold Bowls 1.5 at x ±3 with Neon #78FFBE Gems 0.7 (turned).
- **Tower:** a gold Idol 1.8 x 2.4 x 1.4 + IdolHead 1.3 at the back centre (the "central tower").

04 Temple_Pool (24.6 x 3.1 x 24.6):
- **Rim:** 4 Rims 2 wide x 1.4 tall #848A7C round a 20 x 20 Water.
- **Posts:** 4 corner Posts 2.6 cube #5C645C at (±11, ±11) with gold PostCaps 1.5 x 0.5.

**Real colours** (keep): wood dark #4A3022, brown #68442C, tan #D6965C, totem red #C44632, totem blue #3CAABE, gold
#FFC93C, feather orange #FFAA28, bone #E8E2D0, stone #848A7C / #5C645C, glyph Neon #78FFBE, water #30C4BE (surface)
over #1E8C96 (basin), moss #589642 / #60C448, leaf #78D246.

**Part rules:**

**Totem faces (01 and 02):**
- **Heads:** each head keeps its cube, size, colour and place; the details are carved on it.
- **Eyes with depth:** a dark #4A3022 socket plate 0.15 recessed look (a darker frame 0.2 wide around today's eye), the eye itself 0.1 proud, a pupil 0.3 dark dot on the white eyes.
- **Brows:** a ridge (facet `totem__face_relief_A` angry / `_B` arched) or 2 tilted wedges 0.4 proud.
- **Nose:** carved, 0.5-0.8 proud with nostrils, in the relief piece or a wedge.
- **Mouth with teeth:** today's mouth slab, 3-5 white teeth 0.3 cubes along it, lips 0.2 proud in the head's darker tone.
- **A different expression per face:**
  - Totem_B: blue grinning with tusks, tan calm (closed eyes = 2 dark bars), red angry (brows in), brown open-mouthed, yellow surprised (round eyes);
  - Totem_A: red stern (teeth), blue bird (beak), tan proud (tall eyes).
- **Cheek plates:** cheek plates 0.15 proud; the head's edges chamfered 0.2.
- **Bands between sections:** a 0.3 rope band #C4A068 or a gold #FFC93C metal band 0.35 tall, 0.1 wider than the head, with 2 rivets on the front.
- **Small arms / wings between sections:** Totem_B's gold Ears become carved small arms (3 stepped blocks, a hand of 3 fingers) or small wings.
- **Feathers at the top:** Totem_B's crest = facet `totem__feather_crest` (5 feathers, quill + vane notches, in a gold band).
- **Tusks:** Totem_B's 2 tusks = facet `totem__tusks` (curved, tapering).
- **Plinth:** a stepped stone plinth (#5C645C, 2 steps 0.6, chamfered) under today's dark wood Base, with moss on one corner. The total height may grow by 0.6 at most; keep the faces' heights from the ground (raise nothing, sink the plinth into the ground if needed).

**Totem figure (02):**
- **Hat:** a band (gold #FFC93C 0.35) round the crown above the brim; the brim chamfered.
- **Horns:** curved tapering horns (facet `totem_figure__horns`, replacing the 2 Horn sticks).
- **Wings:** spread feathered wings like the totem arch (facet `totem_figure__wing_L/R`, the C3 wing design at this size).
- **Beak:** the Beak a 2-part hooked beak (upper wedge + a smaller lower jaw, a dark line between).
- **Faces and base:** the red lower face with teeth and an angry brow; a carved base (the dark Base with a 0.2 groove band and corner notches) on the stone plinth.

**Golden shrine (03):**
- **Base:** a stepped stone base with bevelled step edges (0.2), joints every 3-4, moss drapes on 2 corners and in the back joint.
- **Gold plating:** on the GoldTop and Trims, with engraved lines: 2 darker #E5B435 strips 0.08 along the edges, a key pattern on the front (0.1 blocks), a raised rim.
- **Gems in settings:** the 2 Neon gems (keep size, place, #78FFBE) in gold claw settings (facet `shrine__gem_setting`, replacing the Bowls), with a PointLight #78FFBE range 8 brightness 0.6 on each.
- **Central finial:** a detailed tower (facet `shrine__finial`, replacing Idol + IdolHead): a stepped gold base, a carved idol body with bands, a head with a crown, a spike with a small Neon tip.
- **Front panel:** the Table front becomes a carved panel: a 0.2 frame, the Neon glyph (keep 3 x 1 at its place) in a recessed groove as a soft glowing inlay, 2 small carved side glyphs (dark).
- **Keep** the collisions; there are no prompts to keep (see above).

**Water pool (04):**
- **Rim:** each rim side is cut blocks 3-4 long with joints, a bevelled cap (0.2 chamfer, a 0.3 overhang inward), 3 tone steps, chipped corners on 2-3 blocks.
- **Corner posts:** gold-capped carved posts: today's Post cube with a chamfered top, a carved band, and a gold cap stepped in 2 levels with a small pyramid knob (keep today's footprint 2.6).
- **Water:**
  - like the fountain / well (A8): Glass, Transparency 0.15, #30C4BE (the real jungle water colour), the `water_lines` Ripples texture, top 0.6 below the rim top (today's y 0.8);
  - a wet band 0.2 on the rim's inner faces above the waterline;
  - keep the Basin dark #1E8C96;
  - CanCollide off.
- **Lily pads and moss:** 4-6 lily pads (facet `pool__lily_pad`, 1-2 with a pink #FF508C flower) floating at y 0.82; `moss__drape_A/B` on 3-4 rim edges and at 2 posts.
- **Keep** the footprint 24.6 and the collisions.

### C6. Jungle props and decor (owner task 2026-10-20, PROMPT_05)

Images: `docs/Jungle_Images/05_Props_and_Decor/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_133614_before_jungle_decor_{ServerStorage,Workspace}.rbxm`.
The C1 colours, the C2 moss rules and the A recipe apply. These kits have MANY copies (the torch 24 with the kit), so
every detail is cheap: parts first, facet pieces only for the flame, the iron cup, the skull, the banner cloth and the
feather (preview `Previews/Props/jungle_decor_facets.png`).

**Kits** (all in `MapAssets.Jungle`, pivot = bottom centre, front -Z, all SmoothPlastic except the Neon Ember):

| # | Object | Kit | Parts | Placed copies | Notes |
|---|---|---|---|---|---|
| 01 | torch | `Tribal_Torch` | 6 + Attachment `FirePoint` | **23**: test 1, `Jungle_1.Decor.Props` 4, `Jungle_2.Decor.Props` 6, `Jungle_3.Decor.Props` 10, `BossArenas.Jungle.Decor.Props` 2 | all at scale 1; 2 Jungle_3 copies stand on a ledge (pivot y 7.5, at x 6092 / 6108, z 577) |
| 02 | drum | `Drum_A` | 5 | **6**: test 1, `Jungle_2.Decor.Props` 2, `BossArenas.Jungle.Decor.Props` 3 | **5 copies part-resized with Model scale 1**: Jungle_2 x0.8 and x1.2, BossArenas x0.8, x0.9, x1.2 -> `bakedScale` = `bakedFrom(m, "Foot", 4.6)` |
| 03 | skull on pole | `SkullPike_A` | 5 | **13**: test 1, `Jungle_1.Decor.Props` 3, `Jungle_2.Decor.Props` 4, `BossArenas.Jungle.Decor.Props` 5 | all at scale 1, various yaws |
| 04 | banner | `WarBanner_A` | 8 | **8**: test 1, `Jungle_1.Decor.Props` 1, `Jungle_2.Decor.Props` 2, `BossArenas.Jungle.Decor.Props` 4 | all at scale 1 (yaws 90 / -70 / 60) |

No copy in the hub. Suggested new propIds (none exists yet; the desert `bull_skull` / `skull_bones` rules are other
kits): `jungle_torch` (names `Tribal_Torch`), `jungle_drum` (`Drum_A`, with the bakedScale above), `jungle_skull_pike`
(`SkullPike_A`), `jungle_war_banner` (`WarBanner_A`).

**What the kits do (checked):**
- No script, ProximityPrompt, ClickDetector, Sound, tag or attribute in any kit or copy. `src/` names none of them
  (no drum sound or interaction exists: nothing to keep but the shape and collisions).
- **The torch's fire and light are NOT in the torch model.** Each game torch has a separate invisible part
  `Decor.VFX.Fire_Torch` (1 x 1 x 1, Transparency 1, CanCollide off) placed exactly on its FirePoint, i.e. at the torch
  pivot + (0, 8.2, 0): Attachment `Fire` with 3 ParticleEmitters (`Flame` rate 14, `Core` 5, `Ember` 3) and a PointLight
  `Light` (Brightness 1, Range 16, Color #FFAA50, Shadows off). This is the "flicker" (moving particle flames); there is
  no PropFX entry and no script flicker for these torches. Counts: Jungle_1 6 Fire_Torch (4 torches + 2 for the entry
  arch), Jungle_2 8 (6 + 2 gate), Jungle_3 10 (10 torches), BossArenas.Jungle 10 (2 torches + 8 Torch_Wall).
  **Keep:** the `Ember` part exactly (Neon #FF8C28 1.2 x 0.5 x 1.2 at y 7.9) with its child Attachment `FirePoint`
  (offset (0, 0.3, 0) -> world y 8.2), and do not move, copy or add lights: the VFX parts stay where they are, so the
  flame must stay at y 8.2. Do not add a PointLight to the torch (it would double today's light).
- **The test copy has no Fire_Torch part** (the nearest one is 1,870 studs away): in the test zone the torch shows no
  flame particles and no light today. To make the test copy look like the game, the main agent may clone
  `MapAssets.VFX.Fire_Torch` to the test torch's FirePoint (-2870, 8.2, 2420); that is the only light change allowed.
- **Collisions to keep** (invisible copies of today's parts, as in C3-C5):
  - torch: Foot, Pole, Wrap, Bowl collide; Skull and Ember do not;
  - drum: all 5 parts collide (Foot, 2 Bands, Body, Skin);
  - skull pike: Pole and Skull collide; Jaw and Eyes do not;
  - banner: Pole and Crossbar collide; Cloth, ClothTail, Stripe, Emblem, Skull, Feather do not.

**Today's shapes** (kit space, y 0 = the ground):

01 Tribal_Torch (1.9 x 8.15 x 1.9):
- Foot 1.7 x 0.5 x 1.7 #848A7C (y 0..0.5); Pole 0.7 x 7 x 0.7 #703E26 (y 0.1..7.1);
- Wrap 0.95 x 0.8 x 0.95 #C4A068 (y 4.8..5.6) = the tan wrap;
- Skull 0.9 x 0.9 x 0.5 #E8E2D0 at (0, 6.3, -0.55) on the pole front = what the owner reads as the "white wrap";
- Bowl 1.9 x 0.8 x 1.9 #68442C (y 6.9..7.7); Ember (Neon) 1.2 x 0.5 x 1.2 #FF8C28 (y 7.65..8.15), FirePoint at y 8.2.

02 Drum_A (4.6 x 3.7 x 4.6): Foot 4.6 x 0.3 x 4.6 #703E26 (y 0..0.3); Body a cylinder 4.0 across x 3.2 tall #A86238
(y 0.3..3.5); 2 red Bands cylinders 4.25 across x 0.45 #C44632 at y 0.75 and 3.1; Skin a disc 3.8 across x 0.2 #E8E2D0
(y 3.5..3.7).

03 SkullPike_A (7.9 tall): Pole 0.5 x 6.6 #703E26 centred at (0, 3.3), leaning 2.9 deg toward -X; Skull 1.8 x 1.6 x 1.8
#E8E2D0 at (0.15, 7.1, 0) (y 6.3..7.9); Jaw 1.3 x 0.5 x 1.2 at (0.15, 6.1, -0.2); 2 Eyes 0.45 x 0.45 x 0.2 #4A3022 at
(-0.27 / 0.57, 7.25, -0.92).

04 WarBanner_A (5.6 x 17.7 x 1.5):
- Pole 0.6 x 15 #703E26 (y 0..15); Crossbar 5.6 x 0.5 x 0.5 #703E26 at y 13.4 (13.15..13.65);
- Cloth 4.6 x 8 x 0.2 #C44632 at (0, 9.2, -0.4) (y 5.2..13.2) + ClothTail (a 3.3 square turned 45 deg at y 5.2: the
  point down to y 2.87); Stripe 4.6 x 1 x 0.26 #3CAABE at y 11.6; Emblem 2 x 2 x 0.3 #FFC93C turned 45 deg at (0, 8.8, -0.5);
- Skull 1.5 x 1.4 x 1.5 #E8E2D0 at (0, 15.6, 0) (y 14.9..16.3) on the pole top; Feather 0.5 x 2.2 x 0.2 #FFAA28 at
  (0.9, 16.6, 0.3) tilted 25 deg out to +X (its foot at (0.44, 15.6), its tip at (1.36, 17.6)).

**Real colours** (keep): wood #703E26 (poles, crossbar, drum foot), #68442C (torch bowl -> carved head), #A86238 (drum
body), #4A3022 (eyes, dark wood); rope / leather #C4A068; bone / skin / linen #E8E2D0; stone #848A7C / #5C645C; totem red
#C44632 (drum bands, banner); teal #3CAABE (stripe); gold #FFC93C (emblem); feather orange #FFAA28; ember Neon #FF8C28.
Added for the details: iron #5C626E (torch cup, drum tacks), flame Neon #FFB648 / #FFD678, hem red #9D3828 (x0.8),
emblem patch #8D3224, coal bed #3A2E2A, recess #292D29.

**Facet pieces** (`tools/blender/fyd_facets.py -- jungle_decor`, files `Blender_Exports/Props/facets/<piece>.json`):

| Piece | Faces (rect) | Origin | Replaces / adds | Copies x faces |
|---|---|---|---|---|
| `torch__flame` | 44 (0) | Tribal_Torch pivot | added on today's Ember (kept with FirePoint); Neon, no collision, CastShadow off | 24 x 44 |
| `torch__cup` | 39 (0) | Tribal_Torch pivot | the Bowl (keep an invisible Bowl for the collision) | 24 x 39 |
| `skull_pike__skull` | 74 (11) | SkullPike_A pivot | Skull, Jaw, 2 Eyes (keep an invisible Skull for the collision) | 14 x 74 |
| `banner__cloth` | 71 (35) | WarBanner_A pivot | Cloth, ClothTail, Stripe, Emblem | 9 x 71 |
| `banner__finial_skull` | 74 (11) | WarBanner_A pivot | the Skull finial (the same skull at 0.83) | 9 x 74 |
| `decor__feather` | 9 (0) | own anchor = the quill's foot, pointing +Y | the banner Feather (scale 1, orientation [0, 0, -25] at (0.44, 15.6, 0.3)); 2 small hanging feathers on each skull pike (scale 0.38-0.45) | 9 + 28 uses |

At about 16 triangles a face that is ~1.3k triangles per torch, ~1.5k per skull pike (with its 2 feathers), ~2.5k per banner. If the
budget is tight: the banner finial may be parts (a Ball cranium 1.3 + a face block + 2 dark sockets) and the torch
cup may be 3 stacked cylinders (1.0 / 1.5 / 1.9 across); the flame, the pike skull and the cloth should stay facets.
The drum has no facet: it is all parts (its lacing reads better as rope cylinders than as flat facet strips).

**Part rules:**

**01 torch** (keep 1.9 x 8.15 footprint and height; the flame tip goes to 8.85 = +8.6 %):
- **Stone base:** today's Foot as a chamfered stone block 1.7 x 0.35 x 1.7 (#848A7C, 0.1 chamfer on the top edges),
  a smaller stepped collar 1.15 x 0.2 x 1.15 #5C645C on it, 2 tiny cut lines (0.06 dark #292D29) on the front, and one
  soft moss tuft (2 squashed Balls 0.45 x 0.15 x 0.35, #589642 / #60C448) on one corner, never a flat green slab.
- **Pole:** today's 0.7 square as an octagon (2 blocks 0.7 x 7 crossed at 45 deg, or 0.15 corner chamfer), #703E26,
  2 thin bark lines (0.06, x0.86) and 1 knot (0.25 disc) on the lower half.
- **Leather / cloth wrap with rope:**
  - today's Wrap (#C4A068, y 4.8..5.6) = a leather grip: 3 overlapping bands 0.3 tall x 0.82 square, each tilted 6
    deg the other way, 3 tones of #C4A068;
  - today's white Skull part (y 5.85..6.75) = a linen wrap #E8E2D0 all round the pole: 3 bands 0.32 tall, tilted 8
    deg, 0.85 square, with a hanging loose end (0.25 x 0.6 x 0.05) on the front;
  - rope rings #C4A068 x0.86 (cylinders 0.92 across x 0.1, 2 turns each) at y 4.75, 5.65, 5.8 and 6.8;
  - a leather thong (#4A3022, 0.06) crossing the grip diagonally.
- **Carved pole head** (today's Bowl colour #68442C): an octagonal collar 1.0 x 0.25 at y 6.85..7.1 with 4 notches
  (0.1 cuts), from which 4 short wooden prongs (WedgeParts 0.2 x 0.45 x 0.25) rise against the cup at 45 / 135 / 225 /
  315 deg, so the cup sits IN the carved head, not on a plain box.
- **Iron cup:** `torch__cup` (8-sided iron bowl, 1.88 across the flats at the rim y 8.0, foot 0.84 at y 6.95, a darker
  forged band, a flat lip, a dark coal bed at y 7.95, 4 iron claws). If today's Ember corners poke through the rim, turn
  the Ember 45 deg about Y (the FirePoint stays at y 8.2).
- **Flame:** `torch__flame` (Neon, layered: a tall central tongue yellow #FFD678 -> #FFB648 -> #FF8C28 tip at y 8.85,
  3 shorter side tongues round it); CanCollide off, CastShadow off. Keep the Ember part and the FirePoint exactly.
- **Light:** unchanged (it lives on `Decor.VFX.Fire_Torch`, see above). No new light, no PropFX flicker entry.

**02 drum** (all parts; keep 4.6 x 3.7 x 4.6 and the collisions; bakedScale for 5 copies):
- **Barrel body:** 14 staves around today's Body (each a block 0.86 wide x 3.2 x 0.3, set on radius 1.85, 0.04 gaps),
  3 tones of #A86238 (x1 / x0.93 / x0.86, no two neighbours equal), a dark core cylinder 3.6 across #4A3022 inside so
  the gaps read dark; a slight bulge: the staves' middle third 0.06 further out (or 2 stacked blocks per stave).
- **Red painted bands with a pattern:** today's 2 Bands (#C44632 cylinders 4.25 x 0.45 at y 0.75 and 3.1) keep their
  size and place; on each, a pattern of 12 small cream #E8E2D0 diamonds (0.18 blocks turned 45 deg, 0.04 proud) with a
  thin gold #FFC93C line (0.06) along the band's upper and lower edge.
- **Rope lacing:** 12 V's round the body between the 2 bands: 24 rope cylinders #C4A068 (0.12 thick, 2.1 long) running
  diagonally from the top band to the bottom band and back (zigzag), touching the staves (0.06 off), with a small knot
  (Ball 0.18) at each turn on the bands.
- **Skin with a stitched edge:** today's Skin (#E8E2D0 disc 3.8 x 0.2) kept; a slightly darker rim ring (x0.9 cylinder
  3.95 x 0.1 under it), 16 stitches #703E26 (0.22 x 0.05 x 0.08 blocks, radial) round the edge, a soft lighter centre
  disc (2.0 x 0.02, x1.03) where it is beaten.
- **Small wooden base:** today's Foot (4.6 x 0.3) as 4 planks 1.1 wide with 0.05 gaps along X (#703E26 tones) on 2
  battens 0.25 x 0.25 (#4A3022) under them, 4 iron tacks (0.12, #5C626E) at the plank ends. Keep the top at y 0.3.
- Today's colours stay dominant: wood body, red bands, white skin, dark base.

**03 skull on pole** (keep 7.9 tall; collisions Pole + Skull):
- **Skull:** `skull_pike__skull` (cranium, cheekbones, brow ridge, deep eye sockets #4A3022 with darker hollows, nose
  hole, lower jaw, 5 + 4 teeth on dark gum lines), its cranium centre at today's Skull centre (0.15, 7.1, 0).
- **Pole:** today's 0.5 pole and lean, octagonal (0.1 chamfer), #703E26, bark line; a **carved top**: 2 rings 0.62
  across x 0.12 (#68442C) at y 5.4 and 5.7 with a notched band between, the pole tip entering the skull underside.
- **Rope ties:** 2 rope rings #C4A068 (0.6 across x 0.1) at y 5.25 and 5.85, and a rope from the ring hanging 0.6 with
  the beads.
- **Feathers and beads:** 2 `decor__feather` at scale 0.38-0.45 hanging from the jaw / ring (see place in the JSON),
  4-6 beads (Balls 0.16-0.2) on the hanging ropes: teal #3CAABE, red #C44632, gold #FFC93C, bone #E8E2D0.
- **Base:** a stone stand 1.4 x 0.4 x 1.4 #5C645C with a 0.1 chamfer and 2-3 small stones (0.4-0.6, #848A7C) round the
  pole foot, a tiny moss tuft on one; the pole foot stays at y 0.

**04 banner** (keep 5.6 x 17.7 x 1.5; collisions Pole + Crossbar):
- **Cloth:** `banner__cloth`: today's red cloth with a flat centre field (x -1.7 .. 1.7) and 2 pleats per side, a darker
  sleeve hem at the top, today's cyan stripe (y 11.1 .. 12.1) following the pleats, a zigzag lower edge of 7 teeth
  (centre point at y 2.9 = today's tail tip), gold #FFC93C trim along every tooth on both sides, the stitched emblem
  (patch, today's gold diamond, cyan centre, 12 cream stitches). Front at z -0.5 like today (the pole front is -0.3).
- **Crossbar with rope ties:** today's 5.6 x 0.5 bar as a chamfered beam (0.1) with carved end knobs (0.6 cubes with
  chamfers, #68442C); a rope X-lashing #C4A068 where it crosses the pole (2 crossed strips 0.12 + 2 rings 0.7 across);
  5 rope loops (rings 0.62 across x 0.1, tilted 10 deg) at x -2.0 / -1.0 / 0 / 1.0 / 2.0 holding the cloth's sleeve.
- **Pole:** octagonal, #703E26, a carved collar under the finial (2 rings 0.75 x 0.12 #68442C at y 14.5 and 14.85) and
  a rope wrap (3 turns) at y 2.0.
- **Finial and feather:** `banner__finial_skull` (the pike skull at 0.83, top at 16.31 = today) and `decor__feather`
  at scale 1 (today's Feather place and tilt).
- **Base:** a stone collar at the foot (1.5 x 0.35 x 1.5 #5C645C, chamfered) with 2 small stones; optional, it keeps the
  footprint inside 5.6 x 1.5.
- **Sway (optional, owner liked it on the stalls):** a PropFX `Sway` on the cloth piece (`Hinge = "Top"`, 1.5 deg, 3.5 s,
  Axis "X") would make the banner breathe; only if Agent B names the cloth part (e.g. `Cloth`). Not required.

### C7. Jungle rocks and plants (owner task 2026-10-20, PROMPT_06)

Images: `docs/Jungle_Images/06_Rocks_and_Plants/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-20_142011_before_jungle_nature_{ServerStorage,Workspace}.rbxm`.
The C1 colours, the C2 moss rules (soft layered patches, never flat slabs) and the A recipe apply. **These kits have
HUNDREDS of copies**: the cost per copy decides the method (budgets below). Facet pieces:
`tools/blender/fyd_facets.py -- jungle_nature`, preview `Previews/Props/jungle_nature_facets.png`.

**Kits** (all in `MapAssets.Jungle`, pivot = bottom centre, front -Z; no copy in the hub or in other zones):

| # | Object (owner's name) | Kit | Parts | Placed copies | Part-resized copies (Model scale 1) |
|---|---|---|---|---|---|
| 01 | large mossy rock | `Mossy_Rock_L` | 4 MeshParts (2 Rock, 2 Moss) | **14**: test 1, Jungle_1 5, Jungle_2 4, Jungle_3 4 | 0.7 x6, 0.9 x5 (only 3 at 1.0) |
| 02 | small mossy rock | `Mossy_Rock_S` | 2 MeshParts | **70**: test 1, Jungle_1 22, Jungle_2 24, Jungle_3 22, BossArenas 1 | 0.8 / 0.9 / 1.1 / 1.2 / 1.3 (almost all) |
| 03 | round mossy rock | `Mossy_Rock_M` | 2 MeshParts | **38**: test 1, Jungle_1 12, Jungle_2 12, Jungle_3 12, BossArenas 1 | 0.8 / 1.2 (19 copies) |
| 04 | rocks with cyan block | `Waterfall_Rock_Set` | 8 (2 Rock + 2 Moss MeshParts, Step, WaterTop, WaterFall, Foam) | **3**: test 1, `Jungle_2.Decor.Props` 2 | none |
| 05 | lily pads with pink cube | `LilyPad_A` | 3 (2 Pad cylinders, Bloom) | **36**: test 1, Jungle_2 30, Jungle_3 2, Jungle_4 3 | 1.3 / 1.4 (20 copies) |
| 06 | bamboo cluster | `Bamboo_Cluster_A` | 8 (5 Stalk cylinders, 3 BambooLeaf) | **28**: test 1, Jungle_1 12, Jungle_2 8, Jungle_3 7 | 0.9 / 1.15 / 1.3 (all 27 game copies) |
| 07 | thin bamboo | `Vine_Hanging_A` (!) | 6 (3 Vine sticks, 3 VineLeaf) | **42**: test 1, Jungle_3 7, Jungle_4 20, BossArenas 14 | 0.6 / 1.6 / 2.0 (34 copies) |
| 08 | flowering bush | `Bush_Jungle_A` | 3 MeshParts (2 Leaves, Flowers) | **226**: test 1, Jungle_1 85, Jungle_2 70, Jungle_3 70 | 0.8 / 1.3 (about 2/3) |

- **bakedScale for every kit** (`bakedFrom(m, part, kitWidth)`, Size.X of the kit part):
  - `Rock` 21 (L: the big Rock is the widest);
  - `Rock` 8 (M); `Rock` 4.6 (S);
  - `Pad` 0.25 (lily: the pads are cylinders turned upright, so Size.X is their 0.25 thickness);
  - `Stalk` 21 (bamboo: Size.X of a cylinder is its length, the longest stalk is 21);
  - `Vine` 0.5 (thin bamboo);
  - `Leaves` 8.5 (bush).
  - Mossy_Rock_S's moss and Bush_Jungle_A's clumps scale with them; the scales are uniform (checked on heights).
- **Suggested propIds** (none exists): `jungle_rock_large`, `jungle_rock_small`, `jungle_rock_round`, `jungle_waterfall_rocks`, `jungle_lily_pads`, `jungle_bamboo`, `jungle_thin_bamboo`, `jungle_flower_bush`. Not to be confused with the plains `Rock_*_A/B`, `RockBlue_*`, `Bush_A/B` (MapAssets.Common) or `LilyPad_Swamp_A` (Swamp_1 x90): other kits, out of scope.

**What the kits do (checked):**
- No script, ProximityPrompt, ClickDetector, Sound, tag or touch handler in any kit or copy; `src/` names none of them.
  - **The cyan block is NOT a water source, gem or pickup:** it is a small decorative waterfall. Step (stone 8 x 4.6 x 8), WaterTop (#30C4BE) on it, the WaterFall sheet (#30C4BE, T 0.15) down its front, and Foam (#F5F6FA, T 0.3) = the owner's "pale slab".
  - **The pink cube is NOT a pickup:** `Bloom` #FF508C 1.3 x 0.9 x 1.3, CanCollide off, no script.
- **Attributes to keep:**
  - rocks, waterfall and bush models carry `SourceAssetId`, `SourceCreator`, `Proudism` (Toolbox meshes);
  - Vine_Hanging_A carries `Height = 14` (on every copy, even the resized ones).
- **MapFixCollide:** the 2 Jungle_2 `Mossy_Rock_L` copies at (6123.8, 11.6, 260.7) and (6126.3, 11.6, 307.4) have their big `Moss` MeshPart CanCollide ON with attribute `MapFixCollide` (the map-edge fix that stops walking into the rock).
  - Keep it on those 2 copies: an invisible copy of the Moss collider with CanCollide on + the attribute.
  - A template cannot carry it for the 12 others: use a SyncMapProps `variant` or a post-sync fix-up.
- **Collisions** (keep today's MeshParts as invisible colliders, Transparency 1, CastShadow off):
  - rocks: the Rock MeshParts collide, Moss does not (except the 2 MapFixCollide copies);
  - waterfall: 2 Rocks + Step collide; the water, Foam, Moss do not;
  - lily pads, the thin bamboo (Vine_Hanging_A), the bush: nothing collides;
  - bamboo cluster: the 5 Stalks collide (keep 5 invisible cylinders or the new canes).
- **07 "thin bamboo" is `Vine_Hanging_A`**, and **34 of its 42 copies HANG in the air**: Jungle_4 x20 (bottoms y 15.6 / 25.6, 8-22 long), BossArenas x14 (bottom y 38, 28 long). Only the test copy and the 7 Jungle_3 copies stand on the ground (bottoms -6 .. 0, partly sunk).
  - Make the canes, nodes and leaves the same everywhere.
  - Put the base (roots + grass) ONLY on grounded copies, via a SyncMapProps `variant`: grounded when the model's bottom is within 1 stud of y 0.
  - Hanging copies get a small leaf cluster at the top instead.
  - Main agent: check what the Jungle_4 / BossArenas vines hang from before choosing.
- **Shared meshes** (all Toolbox):
  - rock A `rbxassetid://7231644778`: S Rock, the L big Rock, the waterfall right Rock, and every Moss (today's moss is that rock mesh squashed flat and painted green);
  - rock B `9420263160`: M Rock, the L small Rock, the waterfall left Rock;
  - bush leaves `9299837325` (both clumps);
  - bush flowers `73813981037663`.
  - Their triangle counts are not in the file: measure them in Studio (`AssetService:CreateEditableMeshAsync(Content.fromUri(id))`, count the faces) before choosing (a) or (b) below.

**Budgets per copy** (about 16 triangles per facet face, 12 per rectangle part, Roblox cylinders more):

| Kit | Copies | Facet faces (piece) | ~Triangles per copy | ~Total | Method |
|---|---|---|---|---|---|
| Mossy_Rock_S | 70 | body 42 + moss 36 | <= 1.3k | 90k | (a), or (b) if rock A is under ~300 triangles and the zone is heavy |
| Mossy_Rock_M | 38 | body 72 + moss 57 | <= 2.1k | 80k | (a) |
| Mossy_Rock_L | 14 | body 157 + moss 117 | <= 4.5k | 63k | (a) |
| Waterfall_Rock_Set | 3 | rocks 205 + water 14 + basin 58 | <= 5k | 15k | (a) |
| LilyPad_A | 36 | pads 55 + lotus 26 | <= 1.3k | 47k | facets |
| Bamboo_Cluster_A | 28 | 5-7 leaf sprays x 13 | <= 2.5k (parts canes) | 70k | parts + sprays |
| Vine_Hanging_A | 42 | 2-3 leaf sprays x 13 | <= 1k | 42k | parts + sprays |
| Bush_Jungle_A | 226 | flowers 30 + base leaves 10 | <= 650 added to today's 2 leaf meshes | 147k + meshes | (b)-style hybrid |

- **(a) vs (b) for the rocks.** Both keep today's Rock MeshParts as the colliders, so collisions are exact on every copy.
  - **(a)** hides the rock meshes and draws the facet bodies + facet moss (layered strata, cracks, gray-green tone steps, soft moss with tufts). It is the owner's request and the recommended route for L, M and the waterfall.
  - **(b)** keeps today's rock meshes visible (recoloured only) and replaces only the moss: about 600 triangles of moss + 2-3 pebble parts, but no strata or cracks.
  - For S (70 copies) choose by the measured mesh cost: (a) costs ~1.3k, (b) costs mesh + ~0.7k.
  - The facet bodies are fitted to the Rock boxes (same CFrame and size, about 92-96 % of the box), so the invisible meshes and the visible rocks match within a few tenths of a stud.
- **The bush (226 copies) must stay cheap:**
  - keep today's 2 leaf MeshParts (shared mesh, already low-poly facets; the 2 greens #289642 / #78D246 are the gradient);
  - optionally add a 3rd smaller copy of the same mesh (#46AA3C) low on the side for a third layer;
  - replace only the Flowers mesh with `bush__flowers`, and add `bush__base_leaves`.
  - The full facet clump (`bush__clump`, 30 faces) is there only if the leaf mesh turns out heavy; 3 clumps would cost ~1.4k per bush = 320k in total: no.

**Today's shapes** (kit space):
- **01 Mossy_Rock_L** (28 x 16 x 25):
  - big Rock 21 x 14.5 x 18 #848A7C at (0, 6.8, 0), yaw 20 deg;
  - small Rock 9 x 10.5 x 9 #5C645C at (8.5, 4.8, -5.5), tilted;
  - Moss 15.5 x 3.6 x 13 #589642 at (-0.5, 12.6, 0.5); Moss 6.5 x 2 x 6.5 #60C448 at (8.6, 9.6, -5.4).
- **02 Mossy_Rock_S**: Rock 4.6 x 3 x 4.6 #848A7C at (0, 1.3, 0) (y -0.2 .. 2.8); Moss 3.6 x 1.1 x 3.6 #589642 at (0.2, 2.5, 0).
- **03 Mossy_Rock_M**: Rock 8 x 8.5 x 8.4 #5C645C at (0, 4, 0), yaw 40 / tilt 8 deg; Moss 6.6 x 2 x 6.4 #589642 at (0.3, 7.6, 0).
- **04 Waterfall_Rock_Set** (28 x 9.7 x 13.7):
  - Rocks 8.5 x 8.5 x 10 #5C645C at (-7.5, 3.6, 0.5) and 9 x 7.4 x 10 #848A7C at (7.5, 3.2, 0.5), each with a Moss;
  - Step 8 x 4.6 x 8 #5C645C at (0, 2.3, 2);
  - WaterTop 7.4 x 0.4 x 8 #30C4BE at (0, 4.7, 2); WaterFall 7.2 x 5 x 0.6 #30C4BE T 0.15 at (0, 2.3, -2.2), tilted 6 deg;
  - Foam 8.4 x 0.3 x 3 #F5F6FA T 0.3 at (0, 0.2, -3.6).
- **05 LilyPad_A**:
  - Pad cylinder 5.2 across x 0.25 #289642 at (0, 0.13, 0); Pad 3.2 across #78D246 at (3.4, 0.11, 1.8);
  - Bloom #FF508C 1.3 x 0.9 x 1.3 at (0.6, 0.65, -0.5), turned 45 deg;
  - pads lie at the kit pivot height (the water surface: Jungle_2 at y -0.2, Jungle_3 / 4 at 0.8 / 0.9).
- **06 Bamboo_Cluster_A** (7.2 x 21 x 5.8):
  - 5 Stalks 0.9 across, 12 / 15 / 17 / 19 / 21 tall, #A2D856 / #9ACD52 / #91C14D / #9ACD52 / #93C44E, tilted 3-5 deg, bottoms sunk to y -0.2;
  - 3 BambooLeaf blocks 3.6 x 0.3 x 1.3 #78D246 (x2) / #289642 at y 15.2 / 17.5 / 19.8.
- **07 Vine_Hanging_A** (4.8 x 14 x 2.2): 3 Vine sticks 0.5 square, 14 / 12 / 9.5 long, #46AA3C x2 / #166438; 3 VineLeaf blocks 1.5 x 0.3 x 1 #78D246.
- **08 Bush_Jungle_A** (11.6 x 6.3 x 11.7):
  - Leaves mesh 8.5 x 5 x 8 #289642 at (0, 2.4, 0); Leaves 5.4 x 3.6 x 5.4 #78D246 at (1.6, 4.4, -1.2);
  - Flowers mesh 6.5 x 2.3 x 6.5 #FF508C at (-0.4, 4.5, 0.6).

**Real colours** (keep):
- stone #848A7C / #5C645C (+ tone steps), crack #292D29;
- moss #589642 -> #60C448 -> #78D246, grass #78D246 / #60C448;
- water #30C4BE, lighter streaks #7FE3DE, foam #F5F6FA, basin slab pale #D3D9CF;
- pads #289642 / #78D246 (veins = +22 % white, rims x0.86); lotus #FF508C / #FF8DB4, gold centre #FFC93C;
- bamboo #A2D856 / #9ACD52 / #93C44E / #91C14D; thin bamboo #46AA3C / #166438; leaves #78D246 / #60C448 / #289642;
- bush #289642 / #78D246 (+ #46AA3C), flowers #FF508C.

**Facet pieces** (origin = the kit pivot unless stated; the pieces carry `place` and `replaces` in their JSON):

| Piece | Faces (rect) | Origin / placement | Replaces |
|---|---|---|---|
| `rock_s__body` | 42 (0) | Mossy_Rock_S pivot | the Rock look (mesh kept invisible as collider) |
| `rock_s__moss` | 36 (0) | Mossy_Rock_S pivot, built on the body | Moss |
| `rock_m__body` | 72 (0) | Mossy_Rock_M pivot, in the Rock's tilted box | the Rock look |
| `rock_m__moss` | 57 (0) | Mossy_Rock_M pivot | Moss |
| `rock_l__body` | 157 (0) | Mossy_Rock_L pivot, both rocks | the 2 Rock looks |
| `rock_l__moss` | 117 (0) | Mossy_Rock_L pivot, both patches | 2 Moss |
| `waterfall__rocks` | 205 (0) | Waterfall_Rock_Set pivot, both rocks + moss | the 2 Rock looks + 2 Moss |
| `waterfall__water` | 14 (10) | Waterfall_Rock_Set pivot | WaterTop + WaterFall (no collision; T 0.15 on the sheet) |
| `waterfall__basin` | 58 (12) | Waterfall_Rock_Set pivot | Foam (no collision; T 0.3 on the foam faces) |
| `lily__pads` | 55 (0) | LilyPad_A pivot | the 2 Pads |
| `lily__lotus` | 26 (0) | LilyPad_A pivot, in the Bloom's box | Bloom |
| `bamboo__leaf_spray` | 13 (0) | own anchor = the twig base on a node, reaching +X | the BambooLeaf / VineLeaf blocks (2-3 per cane top, small ones on side branches) |
| `bush__flowers` | 30 (4) | Bush_Jungle_A pivot, on today's clumps | Flowers mesh |
| `bush__base_leaves` | 10 (0) | Bush_Jungle_A pivot | nothing (added) |
| `bush__clump` | 30 (0) | own anchor = bottom centre, 2 wide (optional) | the Leaves meshes, only if they prove heavy |

Reuse from earlier sections (no new cost):
- `ruins__plant_tuft` and `ruins__fern` (C4) for grass and plants at rock feet and bamboo bases;
- `moss__drape_B` (C2) where moss should run over a rock edge (L, waterfall), at scale 0.6-1.0.

**Part rules:**

**Rocks 01 / 02 / 03 (and the waterfall rocks):**
- **Bodies:** the facet bodies give the layered strata (2-4 stacked natural layers per rock, each offset, the middle one widest so the rock reads round), soft gray-green shading (darker low x0.8, lighter tops, 3 tone steps of #848A7C / #5C645C) and 1-4 dark cracks.
- **Moss:** soft blankets lying ON the rock facets, 2-3 layers each smaller, lighter and offset (#589642 -> #60C448 -> #78D246), with 2-4 grass tufts. They replace the flat green Moss meshes; never a flat slab.
- **Pebbles at the base:** 2-4 small pebbles per rock as parts: chamfered blocks or wedges 0.3-0.7 (S) / 0.5-1.2 (M, L), #5C645C / #848A7C tones, half sunk, never floating.
  - Add 1-2 `ruins__plant_tuft` (scale 0.5-0.8) at the foot.
  - CanCollide off on everything new.
- **Variation (owner: rotation / scale only):** each copy keeps its own CFrame and its own (baked) scale; if more variety is wanted, a per-copy yaw of +-15 deg and scale x0.95-1.05 is allowed (stays within +10 %).

**04 rocks with cyan block (a small waterfall):**
- **Composition:** keep it exactly: the 2 rocks either side (facet bodies + moss, colliders kept), the Step in the middle, the water on and over it, the pale slab in front.
- **Step:** cut stone blocks: 2 courses of 2.2-2.4 tall, blocks 2.5-4 long, 0.08 joints over a dark #3E453E core, 0.15 chamfers, a capstone row 0.3 proud under the water's back half. Keep its 8 x 4.6 x 8 box and its collision.
- **Water:** `waterfall__water`: the cyan block with bevels in today's #30C4BE and size (flat top, bevelled sides and back, a rounded lip over the front, the falling sheet with lighter streaks, a foam line on the lip).
  - "Glowing": an optional PointLight #7FE3DE, range 8, brightness 0.4, at (0, 3, -3).
  - Water T 0.15 on the sheet like today; CanCollide off.
- **Pale slab:** `waterfall__basin`: a chipped pale stone slab with a crack (today's Foam footprint 8.4 x 3, top y 0.35) with a white foam ring where the sheet lands; CanCollide off like today.
- No script or tag exists to keep (checked).

**05 lily pads and lotus:**
- **Pads:** `lily__pads`: round pads at today's 2 places, a V notch, a domed centre, an upturned curled rim, lighter veins; top at y ~0.25 like today.
- **Lotus:** `lily__lotus` in the Bloom's box: 6 outer + 5 inner petals folded on their midribs, gold centre.
- Nothing collides (as today).
- The copies float at different water heights: keep each copy's CFrame (the kit pivot is the water surface).

**06 bamboo cluster** (keep the 5 cane heights and places; CanCollide on the canes as today):
- **Canes:** each Stalk = 0.9 cylinders in segments 2.2-2.8 long; at every joint a node ring (cylinder 1.02 across x 0.14, one tone darker x0.86) and a 0.04 waist.
- **Gradient:** the segments step from x0.86 at the foot to x1.05 at the top of today's cane colour (#91C14D .. #A2D856), a yellowish tint (mix 10 % #D8C080) on the lowest segment.
  - Cheaper alternative if parts are tight: 3 long segments per cane + node rings only.
- **Leaves:**
  - top clusters: 2-3 `bamboo__leaf_spray` (scale 0.9-1.2) at the top node of each of the 3 tallest canes (replacing the 3 BambooLeaf blocks);
  - side branches: 1-2 small sprays (scale 0.45-0.6) on mid nodes, each on a 0.12 twig (part) 0.6 long.
- **Base:** a low mound (2 squashed Balls #4A3022 x 0.3 tall) with 4-6 short roots (WedgeParts 0.25 x 0.25 x 0.8, #68442C) splaying from the cane feet, 2 `ruins__plant_tuft` and 1 `ruins__fern` (scale 0.6). CanCollide off on the base.

**07 thin bamboo (`Vine_Hanging_A`)** (keep the 3 lengths 14 / 12 / 9.5 and the places; nothing collides):
- **Canes:** today's 3 Vine sticks become thin canes 0.5 across, segments 1.6-2.0 with node rings 0.6 x 0.1 (x0.82).
  - Colours: #46AA3C (2 canes) and the dark #166438 one, with the same light-to-dark gradient as 06.
- **Leaves:** today's 3 VineLeaf blocks become small `bamboo__leaf_spray` (scale 0.4-0.6) on 1-2 nodes per cane, plus a top cluster of 2 sprays on each cane.
- **Base:** roots + 2 grass tufts ONLY on the grounded variant (test zone + Jungle_3). Hanging copies (Jungle_4, BossArenas) get no base (see above).

**08 flowering bush** (keep the 11.6 x 6.3 x 11.7 size; nothing collides):
- **Leaf clumps:** today's 2 leaf MeshParts (the layered clumps, dark #289642 below, light #78D246 on top); optional 3rd small clump (same mesh, #46AA3C, 3.5 x 2.3 x 3.5 at about (-2.6, 1.4, 1.6)).
- **Flowers:** `bush__flowers` (4 open pink flowers with 5 petals and a gold centre, 2 buds) sitting on today's clump surfaces. Agent B should lay them onto the real mesh surface: the piece assumes ellipsoids at 92 % of the clump boxes, so move each flower along its normal until it touches the leaves.
- **Base:** `bush__base_leaves` (5 small leaves splayed on the ground at the foot).

## D. Hub and plains: batch 4 (owner task 2026-10-21)

Images: `docs/Hub_Plains_Props_Batch4/{01_Buildings, 02_Tents, 03_Props}/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-21_212207_before_batch4_{ServerStorage,Workspace}.rbxm`.
Same quality target and recipes as section A (fountain / well), the plains palette (A1, section 3), and the desert and
jungle work (the B6 tent, the C6 banner and torch flame). Everything is parts + unions unless a facet piece is named
(`tools/blender/fyd_facets.py -- batch4`, preview `Previews/Props/batch4_facets.png`).

### D0. Today's kits, copies and functions

All parts are SmoothPlastic (glass panes too); no kit has a script. Scale = Model:ScaleTo unless noted.

| # | Owner's name | Kit | Parts | Placed copies (test zone = `_Staging.AssetPreview.ModelsA.Lineup.*`) |
|---|---|---|---|---|
| B01 | cottage, red roof, one window | `MapAssets.Plains.FarmHouse` | 73 | **2**: test (Lineup.Plains), `Plains_1.Decor.Farm` |
| B02 | cottage, red roof, two windows | `MapAssets.Hub.Cottage_A` | 65 | **4**: test (Lineup.Hub), `Hub.Decor.Village` x3 |
| B03 | two-storey house, blue roof | `MapAssets.Hub.Cottage_B` | 76 | **3**: test, `Hub.Decor.Village` x2 |
| B04 | round stone tower | `MapAssets.Hub.Hub_Tower` | 47 (16 in a `RoofCone` model) | **2**: test, `Hub.Decor.Village` |
| T01 | tent red / white | `MapAssets.Common.Tent_A` | 9 | **3**: test (Lineup.Common, linen + red), `Hub.Decor.Props.AFKCorner` (linen + red), `Plains_2.Decor.PirateCamp` (**all red**: ClothL/R #D4343C) |
| T02 | green "transparent" tent | the tent INSIDE `MapAssets.Plains.HunterCamp` (TentCloth x2, TentEntrance x2, TentPole x3) | 7 of 92 | **2**: test (Lineup.Plains.HunterCamp), `Plains_3.Decor.HunterCamp.HunterCamp` |
| P01 | spiked mace | `MapAssets.Plains.Troll_Club` | 12 (6 Spike MeshParts `rbxassetid://100106311518324`) | **2**: test (Lineup.Plains), `BossArenas.Plains.Decor.TrollDen` |
| P02 | barrel | `MapAssets.Common.Barrel_A` = **existing propId `barrel`** | 13 | **39 placed**: 31 `Barrel_A` (Hub 9: Harbor 8, AFKCorner 1; Desert_1 3, Desert_2 5, Desert_3 1; Plains_1 2, Plains_2 6, Plains_4 3; Volcano_1 1; test 1) + BossArenas.Plains.TrollDen 1 + 7 nested `Barrel` (Hub Market_Awning_A x2, Hub.Trainer x1, Plains_3 HunterCamp x1, test x3; scale 0.79-0.84) |
| P03 | ladder | `MapAssets.Common.Ladder_A` | 8 | **2**: test, `Plains_4.Decor.Mine` |
| P04 | fence section | `MapAssets.Common.Fence_Section` | 4 | **15**: test, `Plains_1.Decor.Farm` x14 |
| P05 | sign board | `MapAssets.Common.Signpost_A` | 4 + GUI | **9**: test (no GUI), Hub AFKCorner ("AFK Zone"), `HubReturnDecor` of Plains_1 / Desert_1 / Jungle_1 / Tundra_1 / Abyss_1 ("Hub"), `Decor.Props` of Volcano_1 / Void_1 ("Hub") |
| P06 | wooden post | `MapAssets.Common.Fence_Post` | 2 | **7**: test, `Plains_1.Decor.Farm` x6 (**one of them is an EMPTY model with 0 parts**) |
| P07 | banner, red diamond | `MapAssets.Common.Banner_A` | 8 | **10**: test, Hub `Decor.Props.Flags` x6 (scale 1), `Decor.Props.AltarBackdrop` x3 (scale 1.5 / 1.5 / 1.9) |
| P08 | flagpole, red flag | `MapAssets.Common.Flag_Pole_A` | 4 | **20**: test, Hub `Decor.Props.Flags` x12 (4 at 1.0, 8 at 1.35), `Decor.Backdrop.Islets.Islet` x6 (2.2), `Plains_2.Decor.PirateCamp` x1 |
| P09 | short lamp post | `MapAssets.Common.Torch_Standing` (a standing TORCH) | 4 + FirePoint + PointLight | **20**: test, Hub AltarBackdrop x2 (1.4) / Harbor x2 (1.3), Desert_3 Caves x4, Plains_4 Cavern x5 (1.3), BossArenas.Plains x6 (1.4) |
| P10 | "campfire or brazier parts" | `MapAssets.Common.Torch_Wall` (a WALL TORCH) | 4 + FirePoint + PointLight | **37**: test, Desert_4 x10, Jungle_4 x14 (**parts resized x1.3, Model scale 1 -> bakedScale `bakedFrom(m, "Stick", 0.5)`**), Plains_4 Mine x4, BossArenas.Jungle x8 |
| P11 | signpost + lectern + lantern platform | `MapAssets.Hub.Station_TutorialGuide`; hub copy = `workspace.Hub.TutorialGuide` (renamed) | 21 + nested `Lantern` | **2**: test (Lineup.Hub.Station_TutorialGuide), `Hub.TutorialGuide` |

Only Torch_Wall has part-resized copies; every other scaled copy uses Model scale (kept by the sync).
**Not in this batch:** the existing templates `lamp_post` (Lantern_Post), `street_lamp` (LampPost_A) and `lantern` (the
nested lanterns) are other kits; the owner's "short lamp post" is Torch_Standing. `Volcano.Miner_Tent` is the same
9-part tent in grey (out of scope, like in the desert batch).

**Existing SyncMapProps rules:**
- **Already covered:** only the barrel (`barrel`: names `Barrel_A`, plus the nested `Barrel` wrapper groups in HunterCamp / Market_Awning_A; template version fddb6) and the platform's nested `lantern` (d23af38c, PointLight 1.2 / 16 / #FFD28C, kept).
- **No rule yet:** FarmHouse, Cottage_A / B, Hub_Tower, Tent_A, the HunterCamp tent, Troll_Club, Ladder_A, Fence_Section, Signpost_A, Fence_Post, Banner_A, Flag_Pole_A, Torch_Standing, Torch_Wall, Station_TutorialGuide.
- **Suggested propIds:**
  - buildings: `plains_farmhouse`, `hub_cottage_red`, `hub_house_blue`, `hub_tower`;
  - tents: `plains_tent` (Tent_A), `plains_tent_green` (nested, wrapper "Tent" in HunterCamp);
  - props: `troll_mace`, `ladder`, `fence_section`, `sign_board`, `wooden_post`, `hub_banner`, `flagpole`, `standing_torch`, `wall_torch`;
  - platform: `guide_platform` (names `Station_TutorialGuide`, hubNames `TutorialGuide`).

**Functions (checked in the data and `src/`):**
- **Buildings:** no prompt, script, NPC, door logic or tag; the doors are plain colliding slabs. Keep every colliding part's collision (Foundation, Walls, Roof, Gables, Chimney, Step, Door, frames; Hub_Tower everything).
- **T02 is NOT transparent:** TentCloth is #68A848, Transparency 0, SmoothPlastic, in every copy.
  - It reads as see-through because #68A848 is the plains grass green: the canvas melts into the ground behind it.
  - Fix: an opaque **olive canvas** clearly darker than the grass (D3).
- **P03 ladder:** plain Parts, NOT a TrussPart; no climb script.
  - 2 Rails 0.5 x 10 at x +-1.4, 6 Rungs 2.6 x 0.35 x 0.35 at y 1.3 / 2.8 / 4.3 / 5.8 / 7.3 / 8.8; everything collides.
  - Whatever climbing works today comes from this rung geometry: keep the rung heights, the 0.35 section and the rail positions exactly (exact invisible copies if the new look differs).
- **P04 fence:**
  - each section is 8 long: Rails 8 x 0.7 x 0.4 at y 1.4 and 3.0, Posts 0.9 x 4 x 0.9 at x +-3.5;
  - sections sit end to end at an 8-stud pitch along X (2 posts side by side at each joint), some overlap (4.5 / 1 pitch in places);
  - corners and ends use Fence_Post;
  - keep the rail ends at x +-4, the posts at +-3.5, the rail heights and the 0.4 depth so every line still joins.
- **P05 sign:** the text is a **SurfaceGui on the `Board` part** (Face Front; Desert_1 also a Back GUI). Names vary (`SignGui` / `SignLabel`, `SurfaceGui` / `TextLabel`, `HubGuiFront` / `HubGuiBack`); texts "Hub" (7) and "AFK Zone" (1).
  - **SyncMapProps hazard:** a child is kept only when the template has no direct child with the same name and class. A template part named `Board` would win and drop the GUIs.
  - Either the sync moves the SurfaceGuis from the old Board onto the new Board (same Face), or the template's panel gets another name and keeps today's `Board` part as the GUI carrier.
- **P07 / P08:** no PropFX entry, no script: **the flags and banners do not wave today**, so they stay static.
- **P09 / P10 torches:**
  - `Ember` = Neon #FF8C28 ball; FirePoint Attachment on `Head` (Torch_Standing (0.6, 0, 0) = 0.6 above the Head along its axis; Torch_Wall (0.39, 0, -0.37)).
  - In the game a separate invisible `Decor.VFX.Fire_Torch` part stands on EVERY copy's FirePoint (particles + its own PointLight 1 / 16 / #FFAA50), as for the jungle torch. The test copies have none.
  - Each copy's own PointLight on `Head` differs (Shadows off, #FFD678):

    | Copies | Light |
    |---|---|
    | kit, test, Hub Harbor, Desert_3, Desert_4 | 0.7 / range 16 |
    | Plains_4 (both kits) | 0.9 / 20 |
    | BossArenas.Plains | 1.2 / 28 |
    | Hub AltarBackdrop, Jungle_4, BossArenas.Jungle | NO light |

  - **No on / off logic** exists (no day-night script, no PropFX flicker).
  - Keep each copy's light values (a variant per light setting, or carry the copy's light onto the new Head) and the FirePoint world position (the VFX parts do not move).
- **P11 platform:** `Hub.TutorialGuide` is the **marker of the Guide NPC** (`Config/NPCs`: Marker "TutorialGuide", Window "Quests", tips).
  - NPCService stands the NPC on `NpcSpot` (2 x 0.2 x 2, invisible) and replaces the `NPC` stand-in model.
  - `Interact` (6 x 6 x 6, invisible) holds the ProximityPrompt (ActionText "Talk", ObjectText "Guide", range 12, key E, no hold) and the BillboardGui `NameTag` -> "Guide".
  - SyncMapProps keeps Interact / NpcSpot / NPC by name: the template must NOT contain parts with these names.
  - The nested `Lantern` is the `lantern` MapProp (kept, synced by its own rule).
  - No text on the signboards today.

### D1. Batch 4 palette (the real Part colours; tone steps x1 / x0.93 / x0.86)

| Role | Hex | Used by |
|---|---|---|
| plaster | #F0E4C8 | Walls, Gables |
| timber | #703E26 | Timber frame, DoorFrame, poles, rails, ladder rails, posts |
| wood light / mid | #D6965C / #A86238 | sign board, door, rungs, rails, lectern, cap |
| window frame / sill | #804E30 | |
| glass | #5FD4FF | windows (keep; SmoothPlastic, optionally Glass T 0.3 + a #2A6F8F back pane) |
| stone (blue-grey) | #969CA8 / #A3AAB7 light / #686E7C dark | foundations, tower body / parapet / base, chimney, steps, cap |
| roof red / ridge | #C4403A / #A53630 | FarmHouse, Cottage_A |
| roof blue / ridge | #4078D4 / #3666B5 (tower cone #3D74CD..#427CDC, rib #2F5CAA) | Cottage_B, Hub_Tower |
| gold | #FFC93C | handles, finials, emblem, flag sleeve |
| flag / banner / tent red | #D4343C | |
| linen canvas | #E8E2D0 | Tent_A |
| tent green (today) -> olive (new) | #68A848 -> #7A8A3C, seams #66752F | HunterCamp tent |
| iron | #5C626E, worn #969CA8 | mace bands / spikes, torch heads, brackets |
| ember / flame Neon | #FF8C28 / #FFB648 / #FFD678 | torches |
| flower box | #C4403A / #FFC93C flowers, #589642 leaves | |

### D2. Half-timbered houses (B01 FarmHouse, B02 Cottage_A, B03 Cottage_B)

One recipe for the 3 houses (same family); keep each footprint, height, door, window and chimney place.

**Today:**
- **FarmHouse:**
  - Walls 28 x 12 x 22 on a Foundation 29 x 1.6 x 23; Roof 2 slabs 31.6 x 1.2 x 18.06 at 45 deg; Ridge 32 x 1 x 1.4 at y 25.5;
  - door 6 x 9 at x -5 (Step 8 x 1.6 x 3 in front); windows 4 x 4: 1 front (x 6), 2 sides, 2 back;
  - chimney 3.2 x 16 at (8, 21.6, 5.5) with cap 3.9 x 1.
- **Cottage_A:** walls 22 x 11 x 18, foundation 23 x 19, roof 25.6 x 15.23, ridge at y 22.5, door centred, 2 front windows at x +-7, 1 per side, chimney at (-6, 19.6, 4.5).
- **Cottage_B:** walls 20 x 19 x 18 (2 storeys in one block), roof 23.6 x 15.95 at 48 deg (blue), ridge y 31.5, door at x -4, ground window at x 5, 2 upper front windows at y 16.1, 1 per side per floor, chimney at (6, 28.1, 4.5).
- **All three:** 19-23 Timber strips #703E26, window frames + bars + sills.

**Rules:**
- **Stone foundation:** today's plinth as cut blocks.
  - Courses 0.8 tall (2 courses on the 1.6 plinth), blocks 1.8-2.8 long, running bond, 0.08 joints over a #545864 core.
  - 0.15 chamfers, 3 tone steps of #969CA8, a 0.2 overhang, a darker #686E7C top course; moss tufts (A4) at 2-3 places at the foot.
- **Walls:**
  - **Plaster:** today's wall block stays as the white plaster core #F0E4C8 (gradient x0.92 at the foot).
  - **Timber frame**, 0.6-0.7 wide, 0.15 proud, #703E26 tones:
    - sole plate on the foundation, corner posts, a mid rail at the window-sill height, a top plate under the eaves;
    - posts at every wall end and either side of each opening;
    - diagonal braces (45 deg) in the wall bays without openings, 1-2 per side, crossing nothing;
    - every crossing a cross-lap: the beam runs 0.15 past it, 2 wooden pegs 0.15;
    - one-step-darker plates on the gables;
    - joints visible: a 0.05 gap where a brace meets a post.
  - **Jettied upper floor (Cottage_B only):** the upper storey (above y 11.1) steps out 0.6 on the front and sides. A row of 6-8 carved brackets (wedges 0.6 x 0.8 x 0.6, #703E26) under the jetty, the floor joist ends (0.4 squares, #804E30, every 1.4) visible along it. Height unchanged.
- **Roofs** (red #C4403A / blue #4078D4) with individual tiles per A5:
  - tiles 1.5 wide x 1.6 long x 0.1, 0.06 gaps, rows every 1.35 with a 0.25 overlap, half-offset rows, butts lifted 0.08, 3 tone steps, darker toward the eave;
  - on today's roof slab (it stays as the under-board and the collider);
  - ridge cap tiles (#A53630 / #3666B5) 0.62 each side, bargeboards 0.15 x 0.34 #703E26 on both gables;
  - eaves: keep today's 1.3-1.8 overhang, a fascia board 0.3 under the lowest row.
  - Cost: about 300-360 tile parts per house (2-4 copies each).
- **Chimney:** cut stone #969CA8 in courses 0.7 with joints, a #686E7C cap slab 3.9 x 0.4 with a 0.35 overhang, 2 dark flue openings on top, a lead flashing strip (#5C626E 0.1) where it meets the roof.
- **Windows** (keep each 4 x 4 opening and its glass):
  - frame 0.4 #804E30, 0.12 proud, cross mullion 0.2 (today's 2 WindowBars);
  - a sill 0.3 thick with a 0.2 drip lip;
  - 2 shutters (#A86238, 3 vertical planks 0.65 with 0.04 gaps, a Z-brace, 2 iron hinge straps) opened flat against the wall either side;
  - a flower box under the front windows: planter 4.4 x 0.6 x 0.7 #A86238 with 2 iron bands, 5-7 flowers (#C4403A / #FFC93C / #E84A9C, a 0.25 bloom on a stem) over a #589642 leaf mound.
- **Door** (keep 6 x 9, place and collision):
  - 5 vertical planks 1.1-1.3 with 0.05 V-gaps over a dark #4A3022 back, 2 battens and a Z-brace on the back;
  - 3 iron strap hinges (#5C626E, 0.3 x 2.6, round ends, 4 nails) on the hinge side; today's gold handle #FFC93C as a ring pull on a back plate 0.5;
  - the frame: 2 posts + a lintel 0.8 with chamfered edges, pegs;
  - a canopy over the door: 2 brackets (wedges) carrying a small tiled roof 7 x 0.2 x 2 in the roof colour.
- **Step:** today's 8 x 1.6 x 3 stone step as 2 blocks with a joint, a worn front edge (0.15 chamfer + 2 chips), darker #686E7C.
- **Small details (vary per house):**
  - a lantern by the door: reuse the `lantern` MapProp at 0.8 on an iron wall bracket, at 7.5 high;
  - B02: a barrel (`barrel` MapProp) by a side wall;
  - B01: a climbing vine (C2 `vine__strand`, 3 strands) on one corner;
  - B03: window boxes on both upper windows, or a small balcony (a 0.4 floor 4 x 1.2 on 2 brackets, a 1.0 railing of balusters 0.2 every 0.5).
- **Gradient:** walls and timbers x0.9 at the foot -> x1.0 under the eaves (A9).

### D3. Tents (T01 Tent_A, T02 the HunterCamp tent)

**T01 = the desert tent recoloured:**
- **Same model:** Tent_A has exactly NomadTent_A's 9 parts, names and sizes (ClothL/R wedges 12 x 8 x 5.5, Trim, Entrance, 2 Poles 0.5 x 8.6, RidgePole 14).
- **Build:** clone the `desert_tent` template (guide B6, `tools/PropsDesert.luau` 04 TENT) and recolour it:
  - canvas panels linen #E8E2D0 / alt #DCD5C2;
  - seams and hem darker linen #C9C1AC;
  - flaps folded back with a red #D4343C lining, red bindings and rope ties #C4A068;
  - poles #703E26 with gold ball caps #FFC93C; stakes and guy ropes as in B6;
  - a red / linen striped rug at the door; grass tufts instead of the sand drift.
- **Colour variant:** the Plains_2 PirateCamp copy is all red. Use a `variant` (ClothL colour): red canvas #D4343C / alt #BF2E36 with a linen lining.
- **Keep:** today's collision (the entrance is closed and collides, as on the desert tent).

**T02 = the green tent:**
- **Today:** inside HunterCamp, 2 TentCloth wedges 11 x 7.5 x 5 (#68A848, turned 65 deg in the camp), 2 TentEntrance wedges #703E26, 3 TentPoles (2 x 8.1 tall, ridge 13 long).
- **New look:** the same desert-tent recipe at this size (ridge 13, height 7.5-8.1), canvas **olive #7A8A3C** (alt #6E7E35, seams #66752F), linen #E8E2D0 bindings and lining, a bedroll (a rolled #A86238 / #E8E2D0 cylinder 0.6 x 2.4) inside the open door.
- **Opaque:** Transparency 0 everywhere.
- **Sync:** a nested prop like the camp's crate / barrel / laundry rack. Rule `plains_tent_green` (wrapper "Tent", host HunterCamp, group = TentCloth / TentEntrance / TentPole).
- **Keep:** the camp's collision.

### D4. Props

**P01 mace** (Troll_Club, 16.7 x 8.1 x 7.6, lying on the ground):
- **Head:** today's 2 Head cylinders (4.0 x 3.2 dia, 5.0 x 4.6 dia #A86238) as a carved wooden head.
  - Wood: 8-sided (or today's cylinders) with 6 shallow carved grooves along X, x0.86.
  - Bands: today's 2 Bands (0.8 x 4.9 #5C626E) as iron bands with 8 rivets each (0.2 domes) and a raised edge rim 0.1.
  - End: an iron end cap (#5C626E, 4.6 dia x 0.3) with a centre boss.
- **Spikes:** `b4_mace__spike` at today's 6 Spike CFrames exactly (8-sided collar, bevelled 4-sided blade, polished tip).
- **Handle:**
  - today's 8 x 1.7 handle (#703E26) with a leather wrap: 6 spiral bands #4A3022, 0.6 wide, tilted 12 deg, 0.05 proud, on the middle 4 studs, and a cord end;
  - a collar ring (#5C626E 2.0 x 0.4) where it enters the head;
  - today's Pommel (#5C626E 2.2 x 1.0) as a faceted iron pommel with a ring.
- Keep the Toolbox attributes (SourceAssetId / SourceCreator) on the model and today's collisions (Pommel, Handle, Heads, Bands).

**P02 barrel** (new template for the existing `barrel` rule; 3.46 x 4.05; ~45 parts, ~600 triangles, 43 instances):
- **Staves:** 14 staves, each 2 blocks (lower / upper half) tilted 3-4 deg so the middle bulges 0.2 (belly 3.4 dia, ends 3.0).
  - 0.04 gaps over a dark #4A3022 core cylinder; 3 tone steps of #A86238 / #955731 / #B96D3F.
- **Hoops:** 3 iron hoops (#474A56, 0.3 tall, 0.06 proud) at today's heights 1.05 / 3.0 / 3.72, 6 rivets each (0.14).
- **Lid:** 4 planks (#784329 tones, 0.06 gaps) inside a 0.1 chime rim, a round bung (0.35, #5C626E plug) on the side at y 2.0, and one lid plank with a pull ring.
- **Sync:** keep the nested `Barrel` wrapper scale (0.79-0.84) working (the template's footprint 3.46 is the REF) and the collision (staves collide).

**P03 ladder:**
- **Rails:** 2 rails 0.5 x 10 (#703E26) with bevelled tops (0.12) and a 0.06 chamfer on the long edges.
- **Rungs:** 6 rungs at today's heights (#A86238 tones), round-ish (chamfered 0.35 squares), each set into the rails: a darker 0.45 square "mortise" plate on the rail face + a 0.15 peg head on the outside.
- **Wear:** a lighter middle on the 3 lowest rungs (x1.06), 1 crack on a rail.
- **Collision:** the rung and rail positions exactly as today (climbing).

**P04 fence section:**
- **Posts:** today's 2 posts (0.9 x 4) with a pyramid cap (wedges, 0.15 overhang, #A86238), 2 nails (0.12) where each rail meets, a rope lashing #C4A068 (2 turns 0.15) on one post.
- **Rails:** today's 2 rails, each 2 split boards with a scarf joint at x 0 (0.06 step, 2 pegs), a 0.05 sag / tilt (+-1 deg) and 3 tone steps; the rail ends still at x +-4.
- **Base:** 2-3 grass tufts (`ruins__plant_tuft` scale 0.5) at the post feet, CanCollide off.

**P05 sign board** (Signpost_A):
- **Post:** today's post 0.8 x 6.5 with a chamfer and a pyramid cap, a stone footing (1.6 x 0.5 x 1.6 #969CA8, chamfered, 2 blocks).
- **Board:** today's Board 5.5 x 2.6 (#D6965C) as 3 horizontal planks 0.85 with 0.04 gaps, in a frame of 4 mitred trim strips 0.35 (#A86238, today's 2 trim Parts on top / bottom + 2 new sides), 8 nail heads (0.14, #5C626E), 2 iron L-plates on the corners.
- **GUIs:** keep the SurfaceGuis on the front face of a part named `Board` (see D0 for the sync hazard). The text area must stay flat 5.5 x 2.6.

**P06 wooden post** (Fence_Post):
- **Post:** today's 1.0 x 4.2 post with a bevelled cap (today's Cap 1.3 x 0.4 + a 0.2 pyramid), 2 vertical cracks (dark 0.06), 3 nails.
- **Rope:** a rope wrap #C4A068 (3 turns 0.12) at y 3.2 with a hanging end 0.8.
- **Footing:** a stone footing 1.5 x 0.4 x 1.5 #969CA8 with chamfers, 2 grass tufts.
- The empty Plains_1 Fence_Post model (0 parts) will become a full post after the sync: ask whether to delete it instead.

**P07 banner** (Banner_A):
- **Cloth:** `b4_banner__cloth` (the C6 banner in Banner_A red, gold trims, gold diamond emblem at today's y 9.2, tip at y 3.2).
- **Crossbar:** today's 5.6 x 0.5 bar as a chamfered beam with carved end knobs (#703E26), a rope X-lashing at the pole, 5 rope loops holding the sleeve.
- **Pole:** carved (2 rings #A86238 at y 11.0 and 12.9), today's gold Finial ball 0.9 on a small gold collar.
- **Base:** today's stone Foot (1.4 x 0.6) as a carved stone base: 2 steps, chamfered, 4 corner notches.
- **Collision:** Foot, Pole, Crossbar as today; the cloth CanCollide off unless a player can reach it.

**P08 flagpole** (Flag_Pole_A, 17.8 tall):
- **Pole:** today's 0.6 pole tapered (0.65 at the foot -> 0.45 at the top: 3 stacked cylinders), 3 iron rings (#5C626E 0.8 x 0.2) at y 4 / 9 / 13, a rope cleat at y 3 with the halyard (0.08 line) up to the flag.
- **Flag:** `b4_flag__cloth` (5 fold panels, hem, gold sleeve) at today's place; static.
- **Finial:** today's gold Finial ball 1.0 on a gold collar (0.6 x 0.3).
- **Base:** today's white-grey Foot (1.6 x 0.6) as a carved stone base: an octagonal 2-step plinth 2.0 / 1.4 with bevelled edges (#969CA8 / #A3AAB7 top).

**P09 short lamp post** (Torch_Standing, 6.55 tall):
- **Post:** today's 0.6 pole (iron-banded at 2 heights) on today's round stone Foot (1.8 x 0.5) as a bevelled octagonal stone base.
- **Bracket:** an iron collar (#5C626E) at the top carrying the lantern.
- **Lantern:** a glass lantern 1.3 wide around today's Ember, keeping the fire:
  - 4 iron corner posts 0.1, a base plate 1.4 and an OPEN crown 1.4 (a ring, not a lid), so the fire particles of the copy's VFX part rise out of it;
  - 4 glass panes Glass T 0.4 #FFE296 (like the hub lanterns);
  - the flame `b4_torch__flame` at 0.8 inside (anchor (0, 5.95, 0)).
- **Keep:** the Neon Ember + Attachment FirePoint (its world position: the VFX part does not move) and each copy's own PointLight on Head (or no light). Name the part holding the FirePoint `Head`.

**P10 wall torch** (Torch_Wall; pivot ON the wall plane, the torch sticks out to -Z; NOT a campfire):
- **Bracket:** an iron back plate (today's Bracket 0.9 x 1.4 x 0.3) with 4 rivets, a scroll arm.
- **Torch:** today's tilted Stick (0.5 x 3, 22 deg) with a leather wrap at the grip and 2 iron rings.
- **Cup and flame:** today's Head as `b4_torch__cup` (scale 0.58, anchor (0, 3.55, -1.6)) and `b4_torch__flame` (0.7, anchor (0, 3.35, -1.65)).
- **Keep:** Ember + FirePoint + each copy's light as for P09; bakedScale for the 14 Jungle_4 copies (x1.3).

**P11 guide platform** (Station_TutorialGuide / Hub.TutorialGuide):
- **Platform:** today's round platform (12 dia x 0.6, rim 13 dia) as 2 rings of bevelled stone blocks.
  - 10-12 wedge-shaped blocks per ring, 0.08 joints over a dark core, 0.15 top chamfer, 3 tone steps of #969CA8.
  - A darker #686E7C kerb ring of blocks on today's rim; a 1-step inset centre disc (radius 2.5) with a carved compass star (4 #686E7C points, 0.05 deep).
  - Keep the walking surface at y 0.6.
- **Signpost:** today's post 0.8 x 9 with a pyramid cap under today's gold Finial ball 1.0 (on a collar).
  - 2 carved arrow boards at today's places (Board 4.4 x 1.3 #D6965C pointing +X, ArrowBoard 4.0 x 1.2 #A86238 pointing -X): each 2 planks with a joint, a pointed tip (today's ArrowTip wedges merged into the board shape), a 0.12 frame groove, 2 iron bands at the post with nails.
  - Carved letters are optional (no text today).
- **Lectern:**
  - today's post 1.2 x 3.4 as a turned / chamfered post with 2 rings, on a foot cross (2 crossed boards 2.2 x 0.5);
  - a slanted top (15 deg toward the reader, front -Z) with a 0.15 lip;
  - `b4_guide__open_book` on it (2 curved page blocks, text lines, a framed picture, a red ribbon bookmark), replacing the 2 Book parts.
- **Lantern:** the nested `lantern` MapProp stays (synced by its own rule).
- **Keep exactly:**
  - `Interact` (+ ProximityPrompt + BillboardGui NameTag) and `NpcSpot`, their places and invisibility;
  - the NPC slot (NPCService places the Guide on NpcSpot and faces it to the plaza);
  - the collisions of the platform.
  - The template has no part named Interact, NpcSpot or NPC.

### D5. Round stone tower (B04 Hub_Tower, 22.6 x 60.65)

**Today:**
- Base cylinder 21 x 3 (#686E7C), Body 18 dia x 31 (#969CA8, y 3..34), Band 18.6 x 1.2 at y 15;
- ParapetRim 22.6 x 0.8 + Parapet 22 x 3.6 (#A3AAB7) + 8 Merlons 3.2 x 2 x 2.4;
- RoofDrum 15 x 2, RoofCone (16 wedges, r 10, y 37.6-53.6), FlagPole 0.5 x 7 (53.1-60.1), gold Finial, red Cloth flag 5.4 x 2.6;
- door 5 x 8 at z -8.7 in a frame, DoorStep 7 x 3 x 4; 3 windows 2.2 x 3.6 with frames.

**Rules:**
- **Body:** brick / stone rows: 24-28 curved block segments per course (wedge-ended blocks 2.0-2.6 long on the 9 radius), courses 1.0 tall, running bond, 0.08 joints over a #545864 core cylinder, 0.12 chamfers, 3 tone steps of #969CA8, x0.88 at the foot. (Or: today's Body cylinder as the core + a ring of 0.25-proud block faces per course; about 30 courses x 26 = 780 parts. A facet band per course is an alternative.)
- **Banded ring:** today's Band as a projecting ring of #686E7C blocks 0.3 proud with a chamfered top.
- **Parapet:** today's parapet as blocks with joints, the ParapetRim as a corbel ring (12-16 small brackets 0.6 under it); the 8 Merlons as capped crenellations (a #686E7C cap slab 0.25 with a 0.15 overhang, chamfered).
- **Cone roof:** `b4_tower__cone_roof` (8 rows of individual tiles, half-offset, lifted butts, 8 darker hip ribs, a gold apex collar, closed eave), on the RoofDrum as today.
- **Flag:** `b4_flag__cloth` at 0.72 on the FlagPole (static, like today), the pole with 2 iron rings, today's gold Finial.
- **Door** (keep 5 x 8 and the collision):
  - an arched frame of 7 voussoir blocks #686E7C over the door;
  - the door: 5 planks with V-gaps, 3 iron bands with nails (#5C626E 0.3) and ring handle;
  - today's DoorStep as 2 stone steps with chamfers.
- **Windows:** the 3 windows with stone surrounds (sill + lintel #686E7C), 2 small shutters each, today's glass.
- **Base:** today's Base as a battered (wider at the foot) plinth of large blocks with a chamfered top; moss tufts at the foot.

### D6. Facet pieces (batch4)

| Piece | Faces (rect) | Origin / placement | Replaces |
|---|---|---|---|
| `b4_torch__flame` | 44 (0) | own anchor = flame base; Torch_Standing (0, 5.95, 0) scale 0.8, Torch_Wall (0, 3.35, -1.65) scale 0.7 | nothing (added on the kept Ember) |
| `b4_torch__cup` | 39 (0) | own anchor = rim centre; Torch_Wall (0, 3.55, -1.6) scale 0.58 | the wall torch's Head look |
| `b4_banner__cloth` | 61 (25) | Banner_A pivot | Cloth, 2 ClothTail, Emblem |
| `b4_flag__cloth` | 14 (8) | own anchor = pole axis at the flag's bottom; Flag_Pole_A (0, 12.8, 0); Hub_Tower (0, 57.1, 0) scale 0.72 | the Cloth wedge |
| `b4_tower__cone_roof` | 136 (0) | Hub_Tower pivot | the RoofCone model |
| `b4_guide__open_book` | 27 (19) | own anchor = spine centre; lectern (-2.6, 4.4, -1.75), tilt [-15, 0, 0] | the 2 Book parts |
| `b4_mace__spike` | 32 (0) | own anchor = today's Spike box centre; today's 6 Spike CFrames | the 6 Spike MeshParts |

**Cost:**
- the torches: 83 faces = ~1.3k triangles on 57 torches, 74k in all: use the flame only (44) on the 37 wall torches if the zones get heavy (Jungle_4 has 14);
- the flags: 14 faces x 20;
- the banners: 61 x 10;
- the rest: only 2 copies each.

## E. Tundra: buildings and structures (owner task 2026-10-22)

Images: `docs/Tundra_Images/01_Buildings_and_Structures/` (4 objects + the overview sheet). Data read from
`BackUP_Files/FightYourDestiny_2026-10-22_130526_before_tundra_buildings_{ServerStorage,Workspace}.rbxm`.
Same quality target as section A (the well): low-mid poly, bevelled logs and planks with visible joints, capped
edges, thick timbers with joints and iron bands, rope, small readable details, soft gradients, clean saturated
colours, no PBR, no grain. Everything is parts + unions unless a facet piece is named
(`tools/blender/fyd_facets.py -- tundra_buildings`, preview `Previews/Props/tundra_buildings_facets.png`).

### E0. Today's kits, copies, functions and hazards

All kits are in `ServerStorage.MapAssets.Tundra` (pivot = bottom centre at the kit origin, front -Z, all
SmoothPlastic, no Neon, no union). Built by the zone builder on 2026-10-04 (`docs/ASSET_KIT_TUNDRA.md`).

| # | Owner's name | Kit | Parts | Placed copies (test zone = `_Staging.AssetPreview.Tundra.*`) |
|---|---|---|---|---|
| 01 | wrecked wooden cabin | `Cabin_Broken` (26.3 x 18 x 26 with the drifts; house 20 x 16) | 40 | **2**: test; `Zones.Tundra.Tundra_1.Decor.Props` at (7905, -0.2, 35), turned so the kit front (-Z) faces world +X |
| 02 | ice cave entrance | `Ice_Cave_Mouth` (29 x 18.2 x 13) | 9 (5 MeshParts) | **6**: test; `Tundra_2.Decor.Props` x4: (7884, 1, 248) and (7884, 1, 338) facing +X, (8116, 1, 228) facing -X, (7928, 0.5, 410) facing -Z; `ServerStorage.BossArenas.Tundra.Decor.Props` at (7884, 0, -600), **Model scale 1.25** |
| 03 | wooden scaffold stand | `Wooden_Scaffold` (16 x 13.6 x 8) | 15 | **4**: test; `Tundra_3.Decor.Props` x3: (8119, 0, 500), (7882, 0, 490), (7881, **8**, 580) (on the T2Body ground, deck top at world y 18.8) |
| 04 | curved snow bridge slab | `Snow_Bridge_Section` (41.6 x 9.8 x 10.6) | 11 (5 MeshParts) | **4**: test (on the ground, pivot y 0); `Tundra_3.Decor.Props` x3, all turned so kit +X = world -Z: A (8117, 30, 566), B (7884, 34, 548), C (7883, 36, 665) |

- **Scale:** Model scale 1 everywhere except the arena cave (Model scale 1.25, kept by the sync). **No part-resized
  copy**: no bakedScale needed.
- **Game copies that differ from their kit** (take the colliders from the game copies, as for the batch 4 houses):
  - Tundra_1 cabin: the walls and LogLines are pushed out 0.05 (WallBack 20.1 long at z 7.55, the back LogLines 20.2,
    WallLeft at x -9.55, WallFrontL / R at z -7.55, WallRight at x 9.55) and the Window sits at z -7.3 (the earlier
    "pane 0.12 out of the wall" fix, `HANDOFF.md`);
  - the 3 Tundra_3 bridges: both side `Span` parts are 10.1 deep and both side `SpanSnow` parts 10.7 (kit 10 / 10.6).
  - Every other copy is identical to its kit (part by part, 0.03 tolerance).
- **Shared Toolbox meshes:** cave `IceRock` L / R = rock B `rbxassetid://9420263160`; cave top `IceRock` (the slab)
  and `Snow` = rock A `7231644778` (the jungle rock meshes, recoloured); every `Icicle` (cave and bridge) =
  `100106311518324` (the mace spike mesh, flipped upside down).

**Functions (checked in the data and `src/`):**
- **Nothing functional in any kit or copy:** no script, ProximityPrompt, ClickDetector, Attachment, light, sound,
  attribute, tag or `Barrier`. `src/` names none of the 4 kits. The only ProximityPrompt in the Tundra zones is the
  Tundra_4 `BossGate.Interact` (not one of these kits).
- **No SyncMapProps rule** claims these kits (the Tundra entries of `tools/SyncMapProps.luau` are the Tundra_1 dark
  sign and the frozen ship). Suggested propIds: `tundra_cabin_wrecked`, `tundra_ice_cave`, `tundra_scaffold`,
  `tundra_snow_bridge`.
- **01 cabin: no door logic, no NPC.** The `Door` is a colliding slab hanging askew in front of the doorway
  (4.6 x 6.4 x 0.4 at (-1.6, 3.1, -8.7), orientation about (-8.8, 28.4, -4.7)); the doorway itself is closed by
  `DoorDark` (6 x 6.5 x 0.3, collides). The cabin is NOT enterable. Keep both, the Door's CFrame and the closed
  doorway.
- **02 cave: no prompt, no teleport.** `Dark` (12 x 11 x 2 at (0, 5.5, 1.8)) and `Back` (18 x 14 x 2 at (0, 7, 3.6))
  both collide: the recess is a closed niche 1.8 deep. Every game copy backs onto a zone `Bounds` wall or the
  Tundra_2 drift facets.
- **03 scaffold: decor stand, no ladder.** Deck top y **10.8** (Deck 16 x 0.8 x 8 at (0, 10.4, 0)), Rail on the front
  (-Z) 16 x 0.5 x 0.5 at (0, 13.3, -3.4).
- **04 bridge: the 3 game copies do NOT chain to anything.** No other bridge piece, ledge or cliff lies within 6
  studs of any end; they float 22-36 studs above the Tundra_3 ground along the east (A) and west (B, C) `Bounds`
  walls (nothing reaches them: B's west end is 20 studs above the scaffold deck at (7881, 18.8, 572..588)). The
  "connection" is the kit's own 3 spans; keep them exactly:

  | Surface (kit space) | Exact value |
  |---|---|
  | middle walk top (`SpanSnow` 16.4 x 1.2 x 10.6 at (0, 7.4, 0)) | flat y **8.0**, x -8.2..8.2, z -5.3..5.3 |
  | side walk tops (`SpanSnow` 13.4 x 1.2 x 10.6 at (+-14.14, 5.84, 0), roll -+13 deg) | planes falling 13 deg outward: (+-7.75, **7.93**) inner edge -> (+-20.80, **4.92**) outer edge; top centre (+-14.28, 6.43) |
  | joint middle / side | the middle top stands 0.07 (x +-7.75) .. 0.17 (x +-8.2) above the side top: today's small step, keep it |
  | ice bodies (`Span`) | middle 16 x 4 x 10 at (0, 5, 0) (y 3..7); sides 13 x 4 x 10 at (+-13.6, 3.5, 0), roll -+13 (top edge (+-7.72, 6.91) -> (+-20.38, 3.99)) |
  | world walk heights (game) | A: middle 38.0, ends 34.92 at world z 545.2 / 586.8 (x 8117); B: 42.0 / 38.92 at z 527.2 / 568.8 (x 7884); C: 44.0 / 40.92 at z 644.2 / 685.8 (x 7883) |

**Collisions to keep** (today's parts become invisible colliders, Transparency 1, CastShadow off, exact CFrame and size
of the game copy):

| Kit | Colliding today | Not colliding (CanCollide + CanQuery off, CastShadow off) |
|---|---|---|
| Cabin_Broken | everything except the 8 lines: Floor, SnowInside, 3 Drift wedges, WallBack / Left / Right / FrontL / FrontR, WallRightBroken, WallFrontRBroken, 4 Post cylinders, Lintel, Door, DoorDark, Window, 3 Gables, Rafter, RoofFallen, 2 Roof, 2 RoofSnow, Ridge, Chimney, ChimneySnow | 6 LogLine, 2 WindowBar |
| Ice_Cave_Mouth | Dark, Back, the 3 IceRock MeshParts (L, R and the top slab) | Snow, 3 Icicle |
| Wooden_Scaffold | 4 Post, Deck, Rail | 4 Brace, 3 PlankLine, 2 Snow |
| Snow_Bridge_Section | 3 Span, 3 SpanSnow | 5 Icicle |

**Today's shapes** (kit space):
- **01 Cabin_Broken:**
  - Floor 20 x 0.6 x 16 #5C4236; SnowInside 17 x 1.2 x 13 #CEDEF6 at (1, 0.9, 0) (top 1.5);
  - walls 1.0 thick #865C42: WallBack 20 x 9 (z 7.5), WallLeft 14 x 9 (x -9.5), WallFrontL 7 x 9 at x -6.5, WallFrontR 7 x 5.5 at x 6.5 (+ WallFrontRBroken wedge 5 x 3 on it), WallRight 14 x 5 at x 9.5 (+ WallRightBroken wedge 7 x 3.5 at z 3.5);
  - 4 corner Post cylinders 1.6 dia #5C4236 (3 x 9.6 tall, the front-right one 6.4); 6 LogLine strips 0.25 x 1.1 at y 3 and 6 (the only "logs" today);
  - doorway 6 x 6.5 at x 0 (DoorDark #1F222B, Lintel 6 x 2.5 x 1 #5C4236 above), the askew Door #865C42;
  - Window 3 x 3 x 1.2 #1F222B at (-6.5, 5, -7.5) with a cross of 2 WindowBars 0.3 #5C4236;
  - roof: the ridge runs along Z (Ridge cylinder 18.6 x 1.4 at y 15.2); the -X slope is whole: Roof board 12.4 x 0.8 x 18 at (-5.2, 12.34, 0), roll +31 deg, RoofSnow 11.6 x 1.0 x 17.6 #F4F8FF on it (eave at x -10.6, y 10.1); the +X slope survives only at the back: Roof 7 x 0.8 x 7 at (3.2, 13.54, 5.5), roll -31, RoofSnow 6.4 x 0.9 x 6.6 #CEDEF6; RoofFallen 8 x 0.8 x 7 lies inside at (5.6, 3.6, -2.5) tilted 52 deg; one Rafter 9 x 0.7 x 0.7 at (4, 12.3, -4);
  - 3 Gable wedges (the front-right one is missing); Chimney 3.2 x 17 x 3.2 #768096 at (-5.5, 8.5, 5) with ChimneySnow 3.8 x 0.9 x 3.8;
  - 3 Drift wedges: 9 x 3.5 x 5 #F4F8FF at (-6.5, 1.75, -10.5) against the front wall; 20 x 4 x 5 #F4F8FF at (0, 2, 10.5) against the back wall; 14 x 4.5 x 6 #CEDEF6 at (-13, 2.25, 0) against the left wall (each high side against its wall).
- **02 Ice_Cave_Mouth:**
  - IceRock L 8 x 15 x 9 #54A0E8 at (-8, 7.2, 0), yaw 34.4 roll -6; IceRock R 8 x 14 x 9 #96D6FA T 0.1 at (8, 6.7, 0), yaw 137.5 roll 6;
  - the slab = IceRock 23 x 6 x 10 #768096 at (0, 13.4, 0.5) (y 10.4..16.4); Snow 20.7 x 6 x 9 #F4F8FF at (0, 14.5, 0.5);
  - Dark 12 x 11 x 2 #0F1F36 at (0, 5.5, 1.8); Back 18 x 14 x 2 #4E566E at (0, 7, 3.6);
  - 3 Icicles #D6ECFF T 0.15 (1.2 x 4.2 / 3.0 / 2.6) hanging at x 0.4 / -3.2 / 3.4, z -0.6, tips at y 7.0 / 8.2 / 8.6.
  - The opening = the gap between the boulders' inner faces (about x -4..4) under the slab (y 10.4), Dark 1.8 behind the front.
- **03 Wooden_Scaffold:**
  - 4 Posts 0.9 square #5C4236: back (z 3.4) 10 tall, front (z -3.4) 13.6 tall (they carry the Rail), at x +-7.4;
  - 2 side Braces 0.5 x 10.4 at x +-7.4, pitched 52 deg (one diagonal per side); 2 front Braces 17.4 long at +-31 deg crossing in an X at z -3.4 / -3.5 (#865C42);
  - Deck 16 x 0.8 x 8 #865C42 (top 10.8) with 3 PlankLines #5C4236 (0.15 wide, at z -2 / 0 / 2);
  - 2 Snow slabs on the deck: 9 x 0.5 x 5 #F4F8FF at (-2, 11, 0.6), 4 x 0.4 x 3 #CEDEF6 at (5, 10.95, -1.5).
- **04 Snow_Bridge_Section:** 3 Spans (middle #54A0E8, sides #96D6FA) with their SpanSnow layers (middle #F4F8FF, sides #CEDEF6), see the table above; 5 Icicles #D6ECFF T 0.15 (1.4 wide, 2.6-5.0 long) at x -9 / -4 / 1 / 6 / 11, z -3 / 2.5 / -3 / 2.5 / -3, roots inside the spans, tips down to y -1.8.

### E1. Tundra palette (the owner's examples next to the real colours; use the REAL ones, tone steps x1 / x0.93 / x0.86)

The owner: "keep each object's own main colors". The real colours are `Kit.Palette.Tundra` (`tools/BuildKit.luau`).
The owner's examples that have no real counterpart become the NEW accent colours (edges, cores, gradients).

| Role | Owner's example | Real colour (keep) | Used by / rule |
|---|---|---|---|
| snow | #F2F6F8 | **#F4F8FF** (Snow) | RoofSnow (main slope), ChimneySnow, 2 Drifts, cave Snow, scaffold big Snow, bridge middle SpanSnow; the TOP faces of every snow cap |
| shaded snow | #D5E3EC | **#CEDEF6** (SnowShade) | SnowInside, the left Drift, the small RoofSnow, the small scaffold Snow, the bridge side SpanSnows; the UNDERSIDES and lips of every cap (a cap's sides = the mix #E1EBFA) |
| ice light | #BFE9F5 | new accent (+ today's #D6ECFF Frost on the icicles) | the light bevel EDGES of every ice piece; icicle facets alternate #D6ECFF / #BFE9F5, tips #F2F6F8 |
| ice mid | #6EC6EA | **#96D6FA** (Ice) | cave right boulder (T 0.1 today), bridge side spans; #6EC6EA = their deeper lower layer |
| ice deep | #1E7FD6 | **#54A0E8** (IceDeep) | cave left boulder, bridge middle span; #1E7FD6 = their deeper lower layer / the core of the light ice |
| navy | #234A8F | new accent (today's darks: cave Dark **#0F1F36**, cabin DoorDark / Window **#1F222B**) | the opaque CORE inside deep ice; the cave interior gradient #234A8F (rim) -> #0F1F36 (back) |
| slate stone | #4F6A86 | **#768096** (Rock), **#4E566E** (RockDark) | chimney, cave slab (#768096); cave Back, slab underside, chimney cap, mortar (#4E566E) |
| frosted dark wood | #4A2A1A | **#5C4236** (Trunk) | posts, floor, ridge, lintel, roof boards, window frame, plank lines, the cabin's dark logs |
| frosted wood | #6A3A22 | **#865C42** (Wood) | wall logs, gables, door, rafter, braces, deck planks, rail |
| cyan glow | #35E6F5 | none today (no Neon in these 4 kits) | optional only: a faint Neon glint deep in the cave (see E-cave); nothing else glows |
| gold | #F2C230 | none today (#FFC93C is the game gold) | not used by these kits |
| new details | | | iron #5C626E (straps, nails, bands, hinges); rope #C4A068; log ends #C49A6C with a #865C42 ring; frost on wood #E6EEF6; cut-wood splinters #A87A55 |

- **Ice** = faceted translucent crystal: Glass, **Transparency 0.25-0.35** on the body faces, 0.2 on the light edges;
  an opaque deeper core inside (the "inner colour gradient"). Neon only where something glows (nothing here).
- **Snow** = soft thick caps with an irregular edge (never a flat white box): flat top where people walk, a rounded
  bulging rim, drip lumps over edges.
- **Icicles** = small tapering 6-sided cones, Glass T 0.25.
- **Gradient (A9):** wood and stone x0.86 at the foot -> x1.0 at the top; ice deeper toward the bottom; snow
  lighter on top. Glass / ice faces are not darkened by the A9 formula (their gradient is built into the layers).

### E2. Part rules shared by the 4 objects (studs; joints, chamfers, caps and the gradient exactly as section A)

**Round logs** (cabin walls, corner crossings):
- One Cylinder per course and wall, **1.0-1.1 dia**, axis along the wall. The courses step **0.92** apart, so the
  logs overlap 0.1-0.15 and no light passes. 9 courses on a 9-tall wall (y 0.55, 1.47, ... 7.91, top log at about 8.4).
- **Chinking:** a dark #4A3022 strip, 0.18 tall, 0.1 behind the log faces, in every joint (the A2 mortar idea). A
  thin frost line #E6EEF6 (0.06 tall) lies on the top of 1 log in 3, on the outside only.
- **Tone:** 3 tone steps of #865C42 per log, never the same on 2 neighbours; the bottom 2 courses x0.86, the top ones
  x1.0 (A9). 1 log in 5 uses the dark #5C4236 (a replaced log).
- **Notched corners** (owner: "notched corners and visible log ends"):
  - the logs of the front / back walls sit on even courses, the side-wall logs on odd courses (offset by half a log, 0.46);
  - every log runs **0.7 past** the corner, so the corner is a stack of crossing log ends;
  - a saddle notch = a darker #5C4236 cylinder collar 1.15 dia x 0.3 where the 2 logs cross.
- **Log ends:** a disc on each end (Cylinder 0.06 proud, dia 0.92 x the log): #C49A6C. On it, a darker ring #865C42
  (dia 0.6, 0.02 proud), 1 radial crack (#5C4236, 0.06 wide); a snow pinch (`tundra_snow__cap` scale (0.7, 0.18, 0.4))
  on the top logs only.
- **Broken logs** (the collapsed corner, the broken walls): the log stops at a jagged end. 2-3 WedgeParts 0.3-0.5 long
  form splinter teeth, in the lighter cut-wood #A87A55, with 1 tooth longer; never a clean flat cut.

**Planks** (roof boards, deck, door, the fallen roof, loose planks):
- Planks are **1.1-1.4 wide, 0.2-0.25 thick**, with **0.05-0.08 gaps** over a dark #3A2A22 backing board (the A6 rule:
  no light through hollow boxes).
- **Nails:** heads 0.14 dia (Ball or Cylinder 0.05 proud) #5C626E, 2 per plank at every batten / beam, 0.25 in from
  the plank ends.
- **Splinters:** on broken plank ends, 2-3 thin wedges (0.15 x 0.08 x 0.4-0.7) in #A87A55; a lighter edge (x1.08) on
  the last 0.3 of a broken plank.
- **Tone:** 3 tone steps of the kit colour, slightly varied lengths (+-0.2) where the ends are free.

**Thick timbers with joints** (posts, braces, rails; A6):
- **Posts:** today's 0.9 square posts with a **0.18 chamfer** on the 4 long edges and a pyramid cap (wedges, 0.12
  overhang). A flat stone footing #4E566E (1.5 x 0.35 x 1.5, chamfered) under each grounded post.
- **Cross-lap joints:** where a brace crosses a post or another brace, it runs 0.2 past and is held by:
  - **rope:** #C4A068, 2-3 turns of 0.12 cylinders, tilted 8 deg, plus a hanging end 0.5;
  - **or iron:** a #5C626E strap 0.3 wide, 0.06 proud, wrapped over 3 faces, with 2 nails.
- **Metal bands:** on posts 0.3 wide, 0.06 proud (A7), 1/6 from the post ends.

**Snow caps** (owner: "soft thick caps with a slightly irregular edge, not flat white boxes"; facet pieces E7):
- **Walk surfaces:** where people walk (roofs, bridge decks), the visible snow TOP is exactly the kept collider's top
  plane (the pieces are built that way). Never lift it: the feet must not float.
- **Shape:** a rounded rim **bulging 0.15-0.5 past** the edge it covers, with lips that roll **0.6-1.2 down** over
  eaves and outer edges, plus drip lumps (0.9-1.5 wide, 0.6-0.8 tall) every 2-4 studs along the lips.
- **Thickness:** 0.6-1.0 on roofs and slabs, 0.35-0.5 on beams, posts and planks.
- **Colours:** snow #F4F8FF on top -> #E1EBFA on the sides -> #CEDEF6 on the undersides and lips. The shaded variant
  (#CEDEF6 objects): #CEDEF6 / #C2D5F0 / #B2C7E8.
- **Small caps** (posts, chimney, planks, log ends, ice blocks): `tundra_snow__cap` / `_shade` / `_drip`, scaled
  non-uniformly.
- **Placement:** snow only on tops and on the windward side (+X in kit space for the cabin roof's surviving piece). It
  is never on the vertical faces, except in drifts.
- **CanCollide off** on every visual cap: the kept parts collide.

**Snow drifts:** `tundra_snow__drift` / `_shade` fitted to today's Drift wedges (they stay as invisible colliders);
extra drifts with no collider go in corners and in the broken part.

**Icicles** (owner: "small tapering cones"):
- **Pieces:** `tundra_ice__icicle` (3.0 long, 0.9 at the root) and `tundra_ice__icicle_cluster` (4 cones under a
  frozen root lump).
- **Material:** Glass, Transparency 0.25; facets #D6ECFF / #BFE9F5, tips #D6EFF6.
- **Placement:**
  - roots touch the underside they hang from (eave lips, slab and span bottoms);
  - lengths vary 0.8-3.0 (scale 0.3-1.0) in irregular groups of 2-5;
  - the longest ones go at the corners and over doors, and they never block the cave opening below y 7.0 (today's
    lowest tip).
- **Collisions:** CanCollide / CanQuery / CastShadow off, as today.

**Faceted ice** (owner: "faceted translucent crystal, low-mid poly facets, lighter edges, slightly glassy, T 0.2-0.4"):
- **Pieces:** the facet pieces `tundra_cave__ice_left / _right`, `tundra_bridge__ice_mid / _side`, `tundra_ice__block`,
  `tundra_ice__shards`.
- **Each piece:** large flat facets in the object's own ice colour, every edge chamfered in a lighter colour
  (#BFE9F5, or #D3EEF6 on the light ice), Glass **Transparency 0.3** on the body faces and **0.2** on the edges.
- **Inner gradient:** an opaque deeper CORE shell inside (#234A8F in the deep ice, #1E7FD6 in the light ice). It
  shows through the glass as the inner colour gradient.
- **Neon:** none (nothing glows today). An emissive edge only if the owner asks for a glow.
- **Studio build:** each closed shell becomes ONE convex solid (the jungle-rock method, ~2 tris per face). Never one
  part per face (NIGHT_LOG 21:45: a 600-wedge union hung the CSG).

**Frost on wood:**
- **Rime:** thin #E6EEF6 strips 0.06-0.08 thick on the TOP edges of beams, rails, sills and frames (on 1/2 to 2/3 of
  their length, broken in 2-3 runs).
- **Ice glaze:** a #BFE9F5 Glass T 0.35 film (0.05) on the lowest 0.3 of posts that stand in snow.
- No white paint over whole faces.

### E3. 01 wrecked wooden cabin (Cabin_Broken; 2 copies)

Keep the 20 x 16 footprint, every height, the broken +X side and the askew door. Every colliding part of the game copy
stays an invisible collider; the test / kit copies take the same template.

- **Walls:** round logs (E2) on today's 5 walls, at today's heights.
  - Back wall: 9 courses, 20 long + 0.7 at each end.
  - Left wall: 9 courses.
  - Front-left wall: 9 courses, 7 long, with the window opening.
  - Front-right wall: 6 courses, broken. The top 2 logs stop at x 4.2 and 5.6 with splintered ends, following today's
    WallFrontRBroken wedge.
  - Right wall: 5 courses, plus 3-4 shortening broken logs on today's WallRightBroken wedge (z 0..7, up to y 8.5), each
    with a splintered free end.
  - Gables: horizontal logs, shortening to the roof line (today's 3 Gable wedges). The front-right gable stays missing.
- **Corners:** the 3 intact corners as notched log crossings (log ends 0.7 out). They replace the look of today's 4
  Post cylinders, which stay as invisible colliders. The broken front-right corner shows a short stack (5 courses)
  ending in a split log.
- **Floor and inside:**
  - Floor: today's Floor as planks (E2), visible only through the broken side.
  - SnowInside: a soft snow layer (keep the 1.5 top; `tundra_snow__drift_shade` mounds 0.6 tall in 2 corners).
  - 1 drift under the hole in the roof.
- **Roof** (plank roof with snow caps; owner):
  - Boards: today's Roof boards as planks running down the slope, 1.3 wide with 0.06 gaps, on 2 purlins (#5C4236
    0.5 square) under them.
  - Edges: a 0.3 x 0.35 bargeboard #5C4236 on the gable edges.
  - Ridge: today's Ridge log as a round log with 2 log ends and an iron band.
  - Snow: `tundra_cabin__roof_snow` and `tundra_cabin__roof_snow_small`, with icicles at their `icicleRoots` (6 + 2
    points: single icicles and clusters, scale 0.4-0.8).
  - The broken edge of the small roof: 3 board ends sticking out 0.4-1.1 past the snow, splintered, 1 hanging down 15 deg.
- **Collapsed part:**
  - RoofFallen: 5 planks (1.3 wide) in today's tilted box, held by 2 battens. Nails on the battens, splintered top end,
    a snow strip (`tundra_snow__cap` (1.0, 0.25, 6)) on its upper edge, 1 plank slid 0.6 down from the others.
  - Rafter: today's Rafter as a log 0.7 dia, its lower end split.
  - Debris inside: 2-3 short broken logs.
- **Chimney** (stone with a snow cap; owner):
  - Courses: today's 3.2 x 17 x 3.2 as cut slate courses 0.85 tall, 2 blocks per face per course (1.5-1.7 long,
    running bond), 0.08 joints over a #4E566E core, 0.15 chamfers, 3 tone steps of #768096, x0.86 at the foot.
  - Top: a #4E566E cap slab 3.8 x 0.35 (0.3 overhang), a dark flue #1F222B 1.6 square, 0.3 deep.
  - Snow: `tundra_snow__cap_drip` at (-5.5, 17.0, 5), scale (3.9, 0.8, 3.9), with 1 icicle. Keep ChimneySnow invisible.
- **Window** (cross frame, frozen frame; owner): keep the 3 x 3 opening (at z -7.3 in the game copy).
  - Frame: 0.35 #5C4236 (chamfered), the cross mullion 0.25 (today's 2 WindowBars).
  - Panes: 4 panes #BFE9F5, Glass T 0.35, over today's dark #1F222B back.
  - Frost: white #F2F6F8 frost triangles in each pane's outer corners (2 wedges, 0.5) and a frost rim on the frame top.
  - Sill: 3.6 x 0.25 x 0.5 with a 0.15 drip lip and a snow cap (`tundra_snow__cap` (3.7, 0.35, 0.6)), 2 icicles 0.4 under it.
- **Door** (hanging off one hinge with iron straps; owner):
  - Planks: at today's Door CFrame, 4 vertical planks 1.1 wide, 0.05 gaps, 2 battens + a Z-brace on the back.
  - Straps: 2 iron straps #5C626E (0.3 x 3.4, rounded ends, 4 nails each) on the hinge side, which is the door's local
    -X edge (it reaches the left jamb).
    - Top strap: still pinned to a hinge knuckle on a new left door post (0.6 x 6.5 #5C4236, the frame).
    - Bottom strap: torn off, bent 20 deg, its pin missing.
  - Handle: an iron ring.
  - Damage: 1 plank 0.5 shorter at the bottom with splinters; snow on its top edge (`tundra_snow__cap` (4.4, 0.25, 0.5)).
  - Keep the Door part (invisible) and DoorDark (the dark doorway stays closed and visible).
- **Doorway frame:** 2 posts 0.6 + today's Lintel as a chamfered beam with 2 nails each side. A worn threshold log.
- **Drifts:**
  - `tundra_snow__drift` on today's 2 white Drift wedges and `_drift_shade` on the left one (wedges kept as colliders).
  - 2 more, no collider: one against the right wall's outside (about (12.5, 0, 2), scale (6, 2.2, 3), yaw -90), one in
    the broken corner inside (about (6, 0.6, -5), scale (5, 1.6, 3)).
- **Scattered planks** (owner: "a few scattered planks"): 4 loose planks, no collision.
  - 2 lying flat in the snow by the broken corner (1.2 x 0.22 x 4.5 and 5.5, yaw 20 / -35, half sunk).
  - 1 leaning on the right wall (tilt 65 deg).
  - 1 broken in two near the door.
  - Each: 2 nails, a splintered end, a thin snow line on top.
- **Gradient:**
  - logs x0.86 at the foot -> x1.0 at the eaves (A9);
  - the inside faces one step darker (x0.86: the cabin interior is in shadow);
  - snow and ice not darkened.

### E4. 02 ice cave entrance (Ice_Cave_Mouth; 6 copies, the arena one at Model scale 1.25)

Keep the opening (between the boulders' inner faces, under the slab at y 10.3-10.4, Dark 1.8 behind), the 5
colliders (Dark, Back, 3 IceRock meshes, kept invisible) and the closed niche (no teleport exists).
- **Boulders:** `tundra_cave__ice_left` (#54A0E8, navy core) and `_ice_right` (#96D6FA, #1E7FD6 core): faceted
  translucent ice with light edges, at today's IceRock places. The feet sink 0.3 into the ground.
- **Slab:** `tundra_cave__slab` (2 strata: dark #4E566E under, #768096 above with a front overhang and a lighter top
  band) + `tundra_cave__slab_snow` (thick soft cap, top y 17.3, 5 front drips, 2 per end).
- **Icicles in the opening:**
  - today's 3 at their x / z with roots at the slab underside (y 10.35), lengths 4.2 / 3.0 / 2.6
    (`tundra_ice__icicle` Y scale 1.4 / 1.0 / 0.87);
  - 2 clusters along the slab front edge (z about -3.0, scale 0.7-0.8);
  - 2-3 short ones (scale 0.4) under each side overhang.
  - No tip below y 7.0 inside the opening.
- **Dark interior with a frozen stone lip:**
  - Gradient: today's Dark stays the far back (#0F1F36). In front of it, 1.0 behind the opening, an inner frame of
    slate blocks #4E566E (2 jambs 1.2 wide and an arch of 5 voussoir blocks under the slab, 0.08 joints).
  - Recess: a #234A8F navy band (0.8 deep, Transparency 0) lining the inside of that frame, so the recess reads deep:
    navy rim -> near-black back.
  - Lip: on the ground across the opening, a frozen stone lip. A threshold slab 9 x 0.5 x 1.6 #4E566E, chamfered, with
    an ice glaze #BFE9F5 Glass T 0.35 (0.08) over its front half and 3 small icicle stubs (scale 0.25) on its front
    edge.
  - Optional (owner: Neon only where it glows): 2-3 tiny Neon #35E6F5 glints (0.15 balls) deep in the recess,
    PointLight none.
- **Base:**
  - `tundra_ice__shards` at 4 places (in the piece's `place`), `tundra_ice__block` x2 (scale 1.0-1.2);
  - `tundra_snow__drift` mounds against both boulders' feet (scale about (7, 1.6, 3), yaw toward the boulder, no
    collider) and a low drift in front of each side.
  - CanCollide off on all of them.
- **Arena copy:** Model scale 1.25, kept by the sync (all pieces scale with it).

### E5. 03 wooden scaffold stand (Wooden_Scaffold; 4 copies)

Keep the 16 x 13.6 x 8 size, the deck top **y 10.8**, the Rail and the 6 colliders (4 Posts, Deck, Rail).
- **Posts:** today's 4 posts (back 10, front 13.6 tall):
  - E2 chamfers, a footing stone each;
  - the front posts end in a pyramid cap above the rail, with a snow cap (`tundra_snow__cap` (1.1, 0.4, 1.1));
  - an iron band 1/6 from the top and bottom;
  - frost rime on the top edges, an ice glaze at the feet.
- **Braces** (crossed, with joints and rope or iron ties; owner):
  - Today's front X: 2 braces 0.5 square, chamfered. They cross-lap at the centre (a 0.06 notch line, 2 pegs) with an
    iron strap; a rope lashing (E2) where each end meets a post.
  - The 2 side diagonals: iron straps and nails at the ends.
  - Add a short knee brace (45 deg, 2.0 long) under the deck at each front post.
- **Deck** (plank deck with gaps; owner):
  - today's Deck stays the invisible collider (top 10.8);
  - on it, 6 planks running along X (16.2 long, 1.25 wide, 0.06 gaps, top at exactly 10.8, 0.2 thick), over a dark
    #3A2A22 board 0.15 below;
  - 2 joists (#5C4236 0.5 square) under the deck along X at z +-2.5;
  - nails at the posts; 1 plank 0.3 shorter at one end.
- **Rail** (a small rail; owner):
  - today's Rail on the front;
  - 2 short side rails (0.4 square, 7 long along Z at y 13.0, from the front posts toward 2 new back stub posts 0.6 x
    2.6 on the deck corners);
  - a rope tie at each joint; snow on the rail top (`tundra_snow__cap` (16, 0.3, 0.6), or 3 shorter pieces).
- **On top** (snow patches and small ice blocks; owner):
  - today's 2 Snow slabs as caps `tundra_snow__cap` (8.6, 0.5, 4.6) at (-2, 10.8, 0.6) and `_cap_shade` (4, 0.4, 3)
    at (5, 10.8, -1.5), CanCollide off as today;
  - 3 `tundra_ice__block` (places in the piece) with small caps;
  - 2 icicle clusters (scale 0.45) under the deck front edge;
  - 1 under the rail.
- **Ground:** a low `tundra_snow__drift` (scale about (5, 1.2, 2.5)) against 2 post feet, no collider.

### E6. 04 curved snow bridge slab (Snow_Bridge_Section; 4 copies)

Keep the 6 colliders EXACTLY (the game copies' 10.1 / 10.7 deep side parts, invisible), so the walk tops of E0 do
not change: middle y 8.0, sides 7.93 -> 4.92 (13 deg), ends at x +-20.8. Nothing else connects to the bridge.
- **Ice underside** (owner: a visible layered blue ice underside with facets):
  - `tundra_bridge__ice_mid` and `tundra_bridge__ice_side` (the right span; yaw 180 for the left one);
  - 3 strata stepping inward going down, a faceted keel hanging 0.45 below each span;
  - light chamfered edges, Glass T 0.25, opaque cores.
- **Snow** (soft, irregular edge; owner):
  - `tundra_bridge__snow_mid` (#F4F8FF) and `tundra_bridge__snow_side` (#CEDEF6, yaw 180 for the left one);
  - their tops are EXACTLY the collider tops; lips over the long edges and the bridge ends, drip lumps.
- **Bevelled edge between the snow and the ice:** a slab rim. Each span gets a thin "stone / ice slab" lip: a
  chamfered band (0.3 tall, 0.15 proud, #BFE9F5 Glass T 0.3) along both long edges just under the snow lip.
  - Parts, or the light top chamfer of the strata, which already reads as it in the preview.
- **Icicles** (small icicles under it; owner):
  - today's 5 at their x / z as `tundra_ice__icicle` (Y scale = today's length / 3, roots inside the keel);
  - plus single icicles (scale 0.35-0.6) at 4-6 of the snow pieces' `icicleRoots` per side.
  - Singles, not clusters, on the bridge (cost, E7).
- **Joints:** the middle snow ends 0.07-0.17 above the side snow (today's step).
  - Hide the seam with a soft snow roll across the joint: `tundra_snow__cap` (0.9, 0.3, 10.8), yaw 0, sunk so its top
    is 0.1 above the middle top. It is visual only, and it does not change the colliders.
- **The test copy stands on the ground** (pivot y 0): the keels and today's icicle tips go into the ground there,
  as today.

### E7. Facet pieces (tundra_buildings)

`tools/blender/fyd_facets.py -- tundra_buildings` writes `Blender_Exports/Props/facets/tundra_*.json` and
`Previews/Props/tundra_buildings_facets.png`.
- **Shells:** every piece is made of **closed convex shells** (convex hulls; separate shells share no vertex).
  `faceCount` <= 300, quads planar, checked.
- **Placement:** each piece's JSON `place` gives its placement; the roof and bridge snow pieces also give
  `icicleRoots` (kit space).
- **Materials:** Glass faces = the ice (Transparency in the notes: 0.3 body / 0.2 edges; icicles 0.25); everything
  else SmoothPlastic.

| Piece | Faces (shells) | Origin / placement | Replaces |
|---|---|---|---|
| `tundra_cabin__roof_snow` | 259 (10) | Cabin_Broken pivot; flat top = the main RoofSnow top plane; 6 icicleRoots under the eave | the main RoofSnow look (kept invisible, collides) |
| `tundra_cabin__roof_snow_small` | 163 (6) | Cabin_Broken pivot; top = the small RoofSnow top; 2 icicleRoots | the small RoofSnow look |
| `tundra_cave__ice_left` | 190 (2) | Ice_Cave_Mouth pivot; 95 % of the IceRock box, foot at y -0.3 | the left IceRock look (mesh kept invisible) |
| `tundra_cave__ice_right` | 206 (2) | same, right IceRock | the right IceRock look |
| `tundra_cave__slab` | 99 (2) | Ice_Cave_Mouth pivot; y 10.3..15.3 | the slab IceRock look (mesh kept invisible) |
| `tundra_cave__slab_snow` | 240 (10) | Ice_Cave_Mouth pivot; top y 17.3 | the Snow mesh |
| `tundra_bridge__ice_mid` | 247 (4) | Snow_Bridge_Section pivot | the middle Span look (kept invisible) |
| `tundra_bridge__ice_side` | 250 (4) | Snow_Bridge_Section pivot, right span; [0, 180, 0] for the left | the side Span looks |
| `tundra_bridge__snow_mid` | 236 (9) | Snow_Bridge_Section pivot; top exactly y 8.0; 6 icicleRoots | the middle SpanSnow look |
| `tundra_bridge__snow_side` | 234 (9) | Snow_Bridge_Section pivot, right; yaw 180 left; top on the tilted collider plane; 5 icicleRoots | the side SpanSnow looks |
| `tundra_snow__cap` / `_cap_shade` | 65 (1) each | own anchor = bottom centre, NORMALIZED 1 x 1 x 1: scale non-uniformly | ChimneySnow look, scaffold Snow slabs; added caps |
| `tundra_snow__cap_drip` | 113 (4) | same + 3 drips over -Z | chimney cap, sills, beam ends |
| `tundra_snow__drift` / `_drift_shade` | 63 / 53 (1) | NORMALIZED WedgePart box (high side +Z): the wedge's bottom centre, rotation, size as scale | the 3 cabin Drift looks (wedges kept invisible); added drifts |
| `tundra_ice__icicle` | 20 (1) | own anchor = root centre, hangs 3.0 along -Y | the Icicle MeshParts (3 per cave, 5 per bridge) |
| `tundra_ice__icicle_cluster` | 100 (5) | own anchor = root lump centre, row along X | nothing (added at eaves, lips) |
| `tundra_ice__block` | 48 (1) | own anchor = bottom centre, 1.6 x 1.2 x 1.4 | nothing (scaffold top, cave foot) |
| `tundra_ice__shards` | 85 (5) | own anchor = cluster centre on the ground | nothing (cave foot) |

**Cost** (~2 tris per face once the shells are convex solids):

| Copy | Facet faces | ~Tris | Copies | ~Total |
|---|---|---|---|---|
| cabin: 2 roof snows, 3 drifts + 2 extra, chimney cap, ~6 icicles + 3 clusters, small caps | ~1.3k | ~2.6k | 2 | 5k |
| cave: 2 boulders, slab, slab snow, 4 shard clusters, 3 + ~5 icicles, 2 clusters, 2 blocks | ~1.7k | ~3.4k | 6 | 20k |
| scaffold: 3 blocks, ~6 caps, 3 clusters (scale 0.45) | ~0.8k | ~1.6k | 4 | 6k |
| bridge: 2 ice + 2 snow bodies (sides twice), ~15 single icicles | ~2.0k | ~4.0k | 4 | 16k |

- **Total:** about 47k triangles over 16 copies, plus the parts.
- **Cheaper options:**
  - The icicle clusters are the expensive accent (100 faces): use singles (20) wherever a row is long.
  - On the 2 cave sides away from the camera (the backs face Bounds walls), the shards can be dropped.

### E8. Tundra gates and entrances (owner task 2026-10-22)

Images: `docs/Tundra_Images/02_Gates_and_Entrances/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-22_143631_before_tundra_gates_{ServerStorage,Workspace}.rbxm`.
Same target and palette as E1-E2 (faceted translucent ice T 0.2-0.4, soft irregular snow caps, tapering icicles).

**Owner's token rule:** 01 and 02 are NOT rebuilt from zero. They DUPLICATE the finished plains templates and change
only what the snow biome needs:
- `entry_arch`: `PropsBatch2.entry_arch`, `tools/PropsBatch2.luau:1298`, version bac9bca5;
- `gate_palisade`: `PropsBatch2.gate_palisade`, `:1430`, version b00e5eb3;
- test copies: `_Staging.AssetPreview.ModelsA.Lineup.Gates.EntryArch_Plains` / `Gate_Plains_2`.

03 and 04 are new.

**E8.0 Kits, copies, contracts** (all in `ServerStorage.MapAssets.Gates`, pivot = bottom centre at the origin, front
-Z, SmoothPlastic unless noted; no script in any kit):

| # | Owner's name | Kit (parts, bbox) | Copies | Contract (keep exactly) |
|---|---|---|---|---|
| 01 | log torii arch, blue sign | `EntryArch_Tundra` (37; 47.5 x 27.2 x 9.3) | **3**: kit, test `_Staging.AssetPreview.Tundra`, game `Zones.Tundra.Tundra_1.EntryArch` (8000, 0, -88) | NOT a gate: no Barrier, no PriceSign. Model attr `ZoneId = "Tundra"`. `NameSign` (14 x 4 x 0.5 #3468B4 at (0, 22.2, -0.6)) holds SurfaceGuis `NameGuiFront` / `NameGuiBack` -> `NameLabel` "Tundra" (+ UIStroke); the game copy's name stays `EntryArch` |
| 02 | palisade gate | `Gate_Tundra_2` (60; 47 x 27.2 x 17.9 with the drifts) | **3**: kit, test, game `Zones.Tundra.Tundra_2.Gate` (8000, 0, 145) | Sub-zone gate. Model attrs `SubZoneId = "Tundra_2"` (game copy), `BarrierDecorIsChildOfBarrier = true`; `PriceSign` GUIs `PriceGuiFront` / `PriceGuiBack` -> `PriceLabel` ("500K Gold"); 2 `Ember` (Neon #FF8C28 0.9 balls at (+-15.6, 12.6, -2.2)) each with Attachment `FirePoint` |
| 03 | ice rock gate | `Gate_Tundra_3` (32; 77.2 x 39 x 22.1) | **3**: kit, test, game `Zones.Tundra.Tundra_3.Gate` (8000, 0, 435) | Sub-zone gate: `SubZoneId = "Tundra_3"`, `BarrierDecorIsChildOfBarrier`; PriceLabel "1.25M Gold" |
| 04 | ice castle gate | `Gate_Tundra_4` (38; 56 x 60.5 x 19) | **3**: kit, test, game `Zones.Tundra.Tundra_4.Gate` (8000, 0, 725) | Sub-zone gate: `SubZoneId = "Tundra_4"`, `BarrierDecorIsChildOfBarrier`; PriceLabel "3.12M Gold". (`Tundra_4.BossGate` at (8000, 0, 938) is another model, out of scope) |

**How the gates work** (`src/.../ZoneService.luau` 225-245, `GateController.luau` 17-42):
- **Prompt:** ZoneService finds the model named **`Gate`** in the sub-zone folder. It needs `gate.PrimaryPart`, and
  creates the ProximityPrompt **`GatePrompt`** in it at run time ("Open (<price> Gold)", hold 0.4, range 18).
  **PrimaryPart = `Barrier` is mandatory** (the kits have no PrimaryPart; the game copies must keep theirs).
- **Opening:** GateController takes `gate.PrimaryPart or FindFirstChild("Barrier", true)`.
  - On open it turns off CanCollide and sets LocalTransparencyModifier 1 on the Barrier AND every BasePart under it,
    and disables every light, emitter, beam and prompt under it.
  - So anything that must vanish with the door is a CHILD of `Barrier`; anything that must stay is not.
  - A light added to a door gem (04) goes under the Barrier and switches off by itself when the gate opens.
- **Price:** every `TextLabel` named `PriceLabel` in the model gets the price or "OPEN".
- **Sync:** the existing SyncMapProps rules `entry_arch` / `gate_palisade` only match `EntryArch_Plains` /
  `Gate_Plains_2` (zones Plains_*). The tundra duplicates need NEW rules: suggested `tundra_entry_arch`,
  `tundra_gate_palisade`, `tundra_gate_ice_rock`, `tundra_gate_ice_castle`.
  - They keep the game-copy names (`EntryArch` / `Gate`), the attributes, the GUIs moved onto the new
    NameSign / PriceSign, the Embers + FirePoints and PrimaryPart = Barrier, as the plains rules do.
- **Copy differences:** the game copies match their kits except 0.05 shifts:
  - 02: the 2 Bands are 24.1 long, the 10 PlankLines at y 8.05;
  - 03: TopSnow at z +0.05;
  - 04: the Frames / Seam at +0.05, the top Frame 24.1 long, the Buttresses at x +-13.95.
  - Take the colliders from the game copies (as for batch 4).

**Colliders** (today's parts kept as invisible colliders, exact game-copy CFrame and size; Barrier children keep their
own flags):

| Gate | Colliding today | Not colliding |
|---|---|---|
| 01 | 2 Base, **4 Crystal meshes**, 4 Binding, 4 Post cylinders, 2 Beam cylinders, SignFrame, NameSign | 2 BaseSnow, 4 PostSnow, BeamSnow, 2 Lantern, 2 LanternCap, 2 Chain, 6 Icicles |
| 02 | 2 TowerBase, **4 Drift wedges**, 4 Binding, Barrier, 8 Log, 2 TorchStick, Lintel, **8 LogEnd snow discs (0.8 x 2.8)**, 2 SignPost, SignFrame, PriceSign, 2 SignRoof wedges | 2 BaseSnow, LintelSnow, 2 Ember; under Barrier (CanCollide off, CanQuery on): 2 SnowBank, 2 Band, Seam, 10 PlankLine, 2 Handle, 2 Brace |
| 03 | 2 Pillar meshes, 2 Rock meshes, 2 Jamb, Beam cylinder, SignFrame, PriceSign, the INVISIBLE Barrier (T 1) | 4 Snow meshes, BeamSnow, 2 Rope; under Barrier: 12 IceBlock (T 0.12, CanQuery on), Rune, TopSnow, SnowBank |
| 04 | 2 Drift wedges, Barrier (Glass T 0.35), 2 Buttress, 2 Tower, Wall, 2 TowerBand, Cornice, 4 Crenel, 2 TowerCap, SignFrame, PriceSign | 2 Spire meshes (CanQuery on), 2 Slit, 6 Icicles; under Barrier: Seam, 3 Frame, 4 Facet, Emblem |

**Lights and fire today:**
- **01:** each `Lantern` (Neon #60BEFF 1.4 x 1.8 at (+-9.5, 14.4, 0), hanging on a `Chain` from the main beam under a
  `LanternCap`) holds a PointLight #60BEFF, Brightness 0.8, Range 14, Shadows off.
- **02:** the Embers carry no light. The zone has 2 separate parts `Tundra_2.Decor.VFX.Fire_Torch` exactly on the 2
  FirePoints (world (7984.4 / 8015.6, 12.8, 142.8)), each with 3 emitters (Flame, Ember, Core) and a WARM PointLight
  #FFAA50, 1 / 16.
  - They are outside the gate model: the sync does not touch them.
  - For the owner's "cold light", the main agent replaces them by clones of `MapAssets.VFX.Fire_Torch_Blue` at the same
    CFrame, with the light recoloured pale cyan-white #CFF4FF (Brightness 1, Range 16).
  - Keep the Ember + FirePoint positions exact.
- **03 / 04:** Neon glows only (03 Rune #60BEFF; 04 Emblem, 2 Slits #60BEFF), no lights.

**E8.1 Real colours** (keep; tone steps x1 / x0.93 / x0.86) and the owner's changes:

| Role | Real today | Owner's change -> use |
|---|---|---|
| logs light / mid | #997660 / #865C42 (01 posts, 02 logs) | "frosted wood, darker, slightly desaturated": keep these two (already darker and greyer than the plains #D6965C / #A86238); frost rime #E6EEF6 on the top edges (E2) |
| dark wood | #5C4236 (bindings, beams, lintel, sign frames / posts) | keep |
| stone | #768096 (01 / 02 bases), #4E566E (03 jambs, 03 pillar R, 02 none) | "blue-grey slate with snow on top": the plains templates' #969CA8 / #686E7C stone -> #768096 / #4E566E, mortar #3E4558 |
| iron | #5C626E (02 bands, 01 lantern caps / chains) | "dark blue steel": #3E4C66, rivets / edges #56688A |
| roof (02) | the SignRoof wedges are plain white #F4F8FF | "snow-covered tiles, blue-grey under the snow": the template's shingles recoloured #5E6E86, ridge cap #4A5870, under `tundra_gate2__roof_snow` |
| sign board | 01 NameSign #3468B4; 02 / 03 PriceSign #997660 (wood); 04 PriceSign #3468B4 | "icy blue sign with a frosted frame": board #3468B4 on all 4 (the GUI text stays readable); frame #D6ECFF with a #F2F6F8 rime strip on its top, 4 small #BFE9F5 Glass T 0.3 corner plates |
| lantern / torch light | 01 #60BEFF Neon + light #60BEFF; 02 Ember #FF8C28 (warm VFX) | "cold light, pale cyan-white": lantern glass #D8F6FF Neon (T 0.4), flames / Ember #D8F6FF Neon, PointLights #CFF4FF (keep each copy's Brightness / Range: 01 0.8 / 14) |
| ice | #96D6FA, #54A0E8, #D6ECFF (crystals, icicles, ice blocks, 04 towers) | faceted Glass ice with light edges (E2) |
| ice-castle accents | #3468B4 (04 bands, caps, cornice), #60BEFF Neon glows | keep; the cyan glows may move to #35E6F5 (the owner's cyan glow) |
| snow | #F4F8FF / #CEDEF6 | caps, drifts (E2) |
| gold | 02 Handles #FFC93C | keep (the template's gold ring handles) |

**E8.2 01 log torii arch (duplicate `entry_arch`, refit to the tundra proportions)**

The plains template does not fit 1:1:

| | plains `entry_arch` | tundra `EntryArch_Tundra` (keep) |
|---|---|---|
| bases | stone pier 8 x 8 x 5 + cap 8.8 x 1 (top 6) at x +-16 | slate base 8 x 3 x 7 (top 3) + BaseSnow |
| posts | octagonal logs 3.0, from y 6: inner x +-14.2 (to 19), outer +-17.6 (to 17) | round logs from the ground: inner 2.6 at x +-14.6 (to 23), outer 2.4 at x +-17.4 (to 18) |
| beams | main box 40 x 2.6 x 3.4 at y 20.3, lower 30 x 1.6 at 17.2 | round: main 38 x 2.4 at y 18.5, top 32 x 2.0 at y 25.6 |
| sign | NameSign 14 x 4 x 3.4 at (0, 23.9, 0) | 14 x 4 x 0.5 at (0, 22.2, -0.6) in a 15.4 x 5.2 frame |
| lanterns | `lantern` props at (+-13.4, 12.3, -2.3) on wall brackets | Neon lanterns at (+-9.5, 14.4, 0) hanging on chains from the main beam |
| top | shingle roof y 26.4-29.6, 2 flags | no roof, no flags; the snowy top beam is the torii top |
| feet | moss | 4 ice crystals (colliding meshes) |

- **Size:** about 50 x 29.6 x 9 (plains) vs 47.5 x 27.2 x 9.3 (tundra).
- **Build:** duplicate the builder, not the model. Same helpers (`ringCourse`, `capSlabs`, `octagon`, `band`,
  `rivet`, `timber`, the sign frame with iron corners, BEVEL_SELF), at the tundra numbers. The torii keeps its own
  look: round logs in pairs, small bands, snow on the beams, the blue sign, hanging ice lanterns, crystals at the feet.
- **Bases:** 2 courses of 1.5 slate blocks (#768096, 8 x 7), a #4E566E cap slab 0.4 with 0.3 overhang, then
  `tundra_snow__cap` (8.6, 0.6, 7.6) on top (replaces BaseSnow) and a `tundra_snow__drift` (6, 1.6, 3) against the
  outer and front faces.
- **Posts:**
  - today's 4 round posts as 8-sided logs (the template's `octagon`) at today's x, diameter and height;
  - 2 dark-steel collars (#3E4C66, 0.6 tall) at the base top;
  - today's 4 Bindings (6 x 1 x 3 at y 8 and 14.5) as the template's riveted `band`s round each pair (#3E4C66,
    rivets #56688A), with a rope lashing #C4A068 under the upper one;
  - log ends #C49A6C on the outer post tops (y 18) under a `tundra_snow__cap` (2.7, 0.6, 2.7); the same on the inner
    tops (y 23), replacing the PostSnow discs.
- **Beams:** today's 2 round beams as 8-sided logs (#5C4236 tones) with log ends at both ends.
  - Over each post: 2 steel bands with rivets and a wooden peg pair (the template's beam bands, at x +-11.6 / +-18.6
    -> +-13.3 / +-18.8).
  - `tundra_snow__log_cap` segments on both beams (place in the piece), replacing BeamSnow.
  - Icicles under the main beam: today's 6 (`tundra_ice__icicle`, Y scale = today's length / 3) plus 4-6 singles
    (scale 0.3-0.6). None below y 13 inside the 26.6-wide passage.
- **Sign:**
  - today's NameSign 14 x 4 x 0.5 at (0, 22.2, -0.6) in #3468B4 (keep: it carries the GUIs);
  - the frame as the template's framed timber surround (4 strips 0.5, #5C4236) frosted: a #D6ECFF inner bead 0.15, a
    rime strip on the top bar, 4 steel corner plates with rivets;
  - 2 short king posts (0.6 square) from the main beam to the frame, as the template's sign mounts;
  - a small `tundra_snow__cap` (15, 0.4, 0.9) on the frame top.
- **Lanterns** (keep today's place, chain and light):
  - the template's lantern design (iron frame, 4 glass panes, cap, roof, handle) at (+-9.5, 14.4, 0), 1.4 x 1.8,
    in dark steel #3E4C66 with #D8F6FF Neon panes T 0.4 and a cold flame #D8F6FF;
  - the PointLight moves from the old Lantern part to the new glass part, recoloured #CFF4FF (0.8 / 14);
  - the Chain as 4 links (0.25 rings) from a steel eye on the beam;
  - a small icicle under each lantern base, `tundra_snow__cap` (1.9, 0.25, 1.9) on each cap.
- **Crystals at the feet:** `tundra_gate4__spire` at the 4 Crystal places (scale 0.48 / 0.3, leaning away from the
  passage), today's 4 Crystal meshes kept invisible as colliders.

**E8.3 02 palisade gate (duplicate `gate_palisade`: same geometry)**

- **Fit:** `Gate_Tundra_2` IS the old Gate_Plains_2 kit recoloured: every log, base, binding, band, lintel, sign post,
  door part, torch stick and Ember is at the same place and size, plus 9 snow parts. So the `gate_palisade` template
  drops in 1:1: duplicate it as `tundra_gate_palisade` and change only the following.
- **Differences to absorb:**
  - today's PriceSign is 12 x 4 x **0.5 at z -1.25** (the template's own is 1.2 thick at z 0; keep the template's,
    the GUIs move onto it);
  - the SignRoof wedges' ridge is at **z -0.4** (the template roof is centred on z 0);
  - the 8 LogEnd snow discs are 0.8 x 2.8 and COLLIDE (the log tops stand 0.7 higher than the template's log ends);
  - 4 colliding Drift wedges stand in front of and behind the towers.
  - Overall about 44.6 x 27.2 x 7.65 (template) vs 47 x 27.2 x 17.9 (with the drifts). Every one of these stays an
    invisible collider.
- **Recolour:**
  - logs #997660 / #865C42 with 3 tones, the dark wood #5C4236;
  - the template's stone bases to slate #768096 / #4E566E;
  - all iron (bands, rivets, hinges, door bands, torch brackets and cups) to dark steel #3E4C66 / #56688A;
  - the gold ring handles stay #FFC93C.
- **Snow:**
  - `tundra_gate2__roof_snow` on both roof slopes (yaw 180 for the back), the shingles under it in blue-grey
    #5E6E86 / ridge #4A5870, visible in a 0.3-0.6 band at the eaves;
  - `tundra_gate2__lintel_snow` on the lintel (replaces LintelSnow);
  - `tundra_snow__cap` (2.9, 0.7, 2.9) on the 8 log tops (replaces the LogEnd discs' look; the discs stay as invisible
    colliders);
  - `tundra_snow__cap` (11, 0.6, 8) on the bases (replaces BaseSnow).
- **Drifts** (owner: "snow drifts instead of the white boxes in front"): `tundra_snow__drift` on the 4 Drift wedges
  (front (+-17.5, 0, -6.4), scale (12, 5.5, 6); back (+-17.5, 0, 6.0), yaw 180, scale (12, 4.5, 5)), wedges kept as
  invisible colliders.
- **Door foot:** the 2 SnowBank wedges stay Barrier children, as soft drifts (`tundra_snow__drift` (24, 3.2, 3.4)
  yaw 180 at the back, (24, 4.6, 4.4) at the front). Parent them under Barrier: they vanish with the door, as today.
- **Icicles:**
  - under the roof eaves: the `icicleRoots` of the roof snow (front and mirrored back), scale 0.35-0.6;
  - under the lintel front: its `icicleRoots`, scale 0.3-0.45 (tips above y 16.2, the door top);
  - 1-2 under each torch cup ring.
- **Torches:**
  - the template's wall torch (bracket on the log, the stick rising up and OUT toward -Z, the cup sitting ON the
    stick's upper end: the owner's "/" directive) in dark steel;
  - the Ember recoloured cold #D8F6FF (Neon, same 0.9 ball, same place) with its FirePoint;
  - the zone's Fire_Torch VFX swapped for the cold version (see E8.0).
- **Sign:** board #3468B4, frame frosted (E8.1), a snow line on the frame top.

**E8.4 03 ice rock gate (new)**

Keep the passage (Barrier 24 x 16 x 2 at (0, 8, 0), between the Jambs' inner faces x +-12.0), the colliders and the
behaviour: the Barrier stays INVISIBLE (T 1) and collides; everything that must vanish on open is under it.
- **Big boulders:** `tundra_gate3__boulder_left` / `_right` (faceted rock-ice in 3 layered blue strata + a thick snow
  cap over the top third) at today's Pillar places; the 2 Pillar meshes stay as invisible colliders, the 2 Snow
  meshes go.
- **Side rocks:** `tundra_gate3__rock_left` / `_right` (2 strata + snow cap) at today's Rock places; the Rock meshes
  stay invisible colliders.
- **Dark blue stone pillars with caps** (today's Jambs 3.4 x 19 x 6 #4E566E at x +-13.7):
  - courses of slate blocks 1.2 tall (2 blocks per course on the front, running bond, 0.08 joints over #3E4558, 0.15
    chamfers, 3 tones of #4E566E, x0.86 at the foot);
  - a plinth course 0.4 wider; a #3468B4-tinted cap slab 4.0 x 0.5 x 6.6 (0.3 overhang, chamfered);
  - `tundra_snow__cap_drip` (4.1, 0.6, 6.7) on it, 2 icicles under the cap front.
- **Thick wooden beam** (today's Beam 34 x 2.2 at y 22.6):
  - an 8-sided log #5C4236 with log ends;
  - 2 dark-steel bands where it rests on the boulders;
  - `tundra_snow__log_cap` x3 (scale 0.92, place in the piece);
  - 4-6 small icicles under it (outside the sign).
- **Frosted sign:**
  - today's PriceSign (keep its CFrame: GUIs) in #3468B4 with the E8.1 frosted frame;
  - today's 2 Ropes as rope lines #C4A068 (2 cylinders 0.2 with a knot ball) from 2 steel eyes on the beam;
  - a snow line on the frame top.
- **Small ice-brick arch with a glowing cyan diamond key** (the door, ALL under the invisible Barrier):
  - today's 12 IceBlocks as bevelled ice bricks: each block with a 0.15 chamfer, #96D6FA / #54A0E8 / #D6ECFF as today,
    Glass T 0.25, light #BFE9F5 edges, 0.12 joints showing the dark #234A8F backing (a thin backing slab, also under
    the Barrier);
  - the top row cut as a flat arch: 5 voussoir bricks fanning around the centre;
  - the keystone = today's Neon Rune diamond (1.8, #60BEFF, or #35E6F5) in a bevelled ice setting with 4 small facets,
    glowing;
  - an optional PointLight #35E6F5 0.6 / 8 under the Barrier (it switches off when the gate opens);
  - TopSnow / SnowBank as a `tundra_snow__cap` strip and a drift (Barrier children).
- **Ground:**
  - `tundra_snow__drift` (scale about (8, 2, 4)) against each boulder's front and the jamb feet;
  - 4-6 small rocks (chamfered #4E566E / #768096 blocks 0.6-1.4, half sunk);
  - 2 `tundra_ice__shards` at the jamb feet.
  - CanCollide off on the additions.

**E8.5 04 ice castle gate (new)**

Keep the opening (Barrier 24 x 16 x 3 at (0, 8, 1)), the door behaviour (Barrier Glass T 0.35 collides; Seam, Frames,
Facets, Emblem under it vanish on open), the colliders and the PriceSign.
- **Towers of bevelled ice blocks** (today's 2 Towers 15 x 40 x 12 #54A0E8 at x +-19.5, z 2):
  - courses 2.5 tall of blocks 3.5-5 long (running bond), 0.12 joints over a darker #3468B4 core, 0.25 chamfers
    with light #96D6FA edge strips, 3 tones of #54A0E8, x0.88 at the foot;
  - only the visible faces need blocks (front, sides, back where seen);
  - today's TowerBand (y 30) as a projecting band course of #3468B4 blocks with a chamfered top, plus a second thin
    band at y 15;
  - today's 2 Neon Slits as arrow slits: a recessed #234A8F frame 1.3 x 5 with the Neon #60BEFF strip inside.
- **Caps and spires:**
  - today's TowerCaps as corbelled caps: a row of 0.6 corbels under a chamfered #3468B4 slab, a snow layer
    (`tundra_snow__cap` (17.4, 0.7, 14.4)) and icicles at the corners;
  - `tundra_gate4__spire` on each cap at (+-19.5, 43, 2), yaw -+57: big faceted crystal spires, Glass T 0.3, light
    edges, opaque core. The Spire meshes go (they did not collide).
- **Wall and crenellations with icicles:**
  - today's Wall (24.2 x 20 x 8) in the same ice-block courses;
  - the Cornice as a 2-step corbelled cornice #3468B4;
  - today's 4 Crenels as capped merlons (#96D6FA ice blocks, a #3468B4 cap slab 0.3 with 0.15 overhang, a small
    snow cap each);
  - icicles: today's 6 at their places + 6-8 smaller ones along the cornice front (`tundra_ice__icicle` /
    `_cluster`, roots at y 36, the cornice underside).
- **Framed name sign:** today's PriceSign (12 x 4 #3468B4 at (0, 20, -2.35), GUIs) in today's frame #D6ECFF made a
  raised ice frame: 4 bevelled strips 0.7, light edges, 4 corner studs #96D6FA, a snow line on top.
- **Frosted-glass double door with ice frames and a glowing cyan gem** (everything under the Barrier):
  - today's Barrier as the frosted pane (Glass T 0.35 #96D6FA, keep);
  - today's 3 Frames as bevelled ice frames (#54A0E8 with #96D6FA edges), plus a centre mullion = today's Seam;
  - today's 4 Facets as raised frost ribs (#D6ECFF, 0.15 proud) in a diamond pattern on each leaf;
  - the Emblem as a faceted gem (an 8-facet diamond, Neon #60BEFF or #35E6F5) in a #3468B4 setting with 4 claws;
  - an optional PointLight #35E6F5 0.8 / 10 inside the Emblem (it switches off when the gate opens).
- **Pilasters** (today's 2 Buttresses 4 x 22 x 3 #96D6FA at (+-14, 11, -5)): ice-block pilasters with a base block and
  a capital (chamfered), light edges; snow on the capital.
- **Base:**
  - `tundra_snow__drift` on today's 2 Drift wedges (15 x 6 x 6, kept as colliders);
  - `tundra_snow__cap` strips along the tower feet;
  - 2 `tundra_ice__shards` by the pilasters.

**E8.6 Facet pieces (tundra_gates; plus the reused tundra_snow__* / tundra_ice__* of E7)**

`tools/blender/fyd_facets.py -- tundra_gates` -> `Blender_Exports/Props/facets/` and
`Previews/Props/tundra_gates_facets.png`. Closed convex shells, <= 300 faces, checked.

| Piece | Faces (shells) | Origin / placement | Replaces |
|---|---|---|---|
| `tundra_snow__log_cap` | 194 (7) | own anchor = the axis of a 2.4 round log, 12-stud segment along X; scale = diameter / 2.4; 3 segments per beam (01 main: x -12.5 / 0 / 12.5 at y 18.5; 01 top: x -10.5 / 0 / 10.5 at y 25.6, scale 0.83; 03: x -11 / 0 / 11 at y 22.6, scale 0.92), yaw 0 / 180 alternately | 01 / 03 BeamSnow |
| `tundra_gate2__roof_snow` | 213 (8) | Gate_Tundra_2 pivot; the template roof's front slope; yaw 180 = back slope; 4 icicleRoots | the white SignRoof look (wedges kept as colliders) |
| `tundra_gate2__lintel_snow` | 196 (7) | Gate_Tundra_2 pivot; top y 19.2; 4 icicleRoots | LintelSnow |
| `tundra_gate3__boulder_left` / `_right` | 119 / 117 (4 each) | Gate_Tundra_3 pivot; 95 % of the Pillar boxes, foot y -0.5 | the 2 Pillar looks + their Snow meshes (Pillars kept as colliders) |
| `tundra_gate3__rock_left` / `_right` | 80 / 76 (3 each) | Gate_Tundra_3 pivot; 95 % of the Rock boxes | the 2 Rock looks + their Snow meshes (Rocks kept as colliders) |
| `tundra_gate4__spire` | 186 (4) | own anchor = bottom centre, 10 x 18 x 10; 04 at (+-19.5, 43, 2) yaw -+57; 01 feet at scale 0.48 / 0.3 | the 2 Spire meshes (04); the 4 Crystal looks (01, meshes kept as colliders) |

**Cost:**
- 01: 6 log caps + 4 crystals + caps + icicles = about 2.1k faces (about 4.2k tris);
- 02: 2 roof snows + lintel + 8 caps + 4 drifts + icicles = about 1.7k;
- 03: boulders + rocks + 3 log caps + caps = about 1.2k;
- 04: 2 spires + caps + icicles = about 0.8k.
- Total about 11.6k tris per set; 3 copies of each set (kit, test, game) = about 35k, plus the parts.
- If 01 is heavy, use 2 log-cap segments per beam at scale 1.2.

### E9. Tundra ice monuments, statues and shrines (owner task 2026-10-22)

Images: `docs/Tundra_Images/03_Ice_Monuments_and_Statues/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-22_171819_before_tundra_monuments_{ServerStorage,Workspace}.rbxm`.
Same target and palette as E1-E2. Facet pieces: `tools/blender/fyd_facets.py -- tundra_monuments`, preview
`Previews/Props/tundra_monuments_facets.png`.

**E9.0 Kits, copies, functions**

All kits are in `ServerStorage.MapAssets.Tundra` (pivot = bottom centre at the origin, front -Z, SmoothPlastic unless
noted). Every scaled copy uses Model scale (checked part by part against kit x scale: 0 differences). **No bakedScale
is needed.**

| # | Owner's name | Kit (parts, bbox) | Placed copies (test = `_Staging.AssetPreview.Tundra`) | Total |
|---|---|---|---|---|
| 01 | ice pillar | `Ice_Pillar` (8; 8 x 40 x 8) | test; `Tundra_4.Decor.Props` x10 (scale 1.2); `ServerStorage.BossArenas.Tundra.Decor.Props` x8 (1.5) | 20 with the kit |
| 02 | ice knight in glass case | `Frozen_Knight_Statue` (19; 11 x 14.7 x 8.6) | test; `Tundra_4.Decor.Props` x4 (1.15); **nested in `Tundra_4.BossGate`** x2 (1.25, at (7964 / 8036, 0, 932)); BossArenas x4 (2 at 1.0, 2 at 1.2 standing at y 1.5) | 12 |
| 03 | ice throne | `Ice_Throne_Small` (12; 13 x 18.4 x 8.5) | test; `Tundra_4.Decor.Props` x1 (7930, 0, 932) scale 1.0; BossArenas x1 (8115, 0, -600) scale 1.1 | 4 |
| 04 | "yellow dome pedestal" | **`Warm_Brazier`** (10; 8.6 x 8.75 x 8.6) | test; **BossArenas `WarmSpots` x4, renamed `WarmBrazier`** (scale 1.3, + an 11th part `Fire`) | 6 |
| 05 | "glass frame with checkmark" | **`Ice_Wall_Panel`** (7; 20 x 24 x 3) | test; `Tundra_4.Decor.Exterior` x4 (scale 1.0, pivots y 3 at x 7907 / 7937 / 8063 / 8093, z 724.4: the zone wall either side of the Tundra_4 gate); `Tundra_4.Decor.Props` x4 (1.2, y 4) | 10 |
| 06 | blue lamp post | **`Blue_Torch_Standing`** (4; 1.8 x 6.55 x 1.8) | test; **nested in `Tundra_4.BossGate`** x2 (1.7); BossArenas x6 (1.5 x2, 1.7 x2, 2.0 x2) | 10 |

- **Nested copies:** the BossGate holds 2 knights and 2 torches. The sync rules must find those nested copies (as the
  nested barrels / lanterns did) and keep the BossGate's own parts and its `Interact` ProximityPrompt untouched.
- **No hub copies; no SyncMapProps rule yet.** Suggested propIds: `tundra_ice_pillar`, `tundra_ice_knight`,
  `tundra_ice_throne`, `tundra_warm_brazier` (names `Warm_Brazier` + `WarmBrazier`), `tundra_ice_panel`,
  `tundra_blue_lamp`.

**What 04 and 05 are** (checked in the data and in `src/`):
- **Nothing to keep beyond decoration:**
  - `src/` names none of the 6 kits, nor "Warm", "WarmSpot", "Brazier", "Checkpoint", "Quest", "Heater" or "Throne"
    as logic. The only Seat logic is BenchService, for `workspace.Hub` benches.
  - No kit or copy has a script, ProximityPrompt, ClickDetector, Seat, tag or attribute.
- **04 = `Warm_Brazier`, a fire brazier.**
  - The "yellow dome" is today's `EmberGlow`: a Neon #FF8C28 ball 4.6 across at (0, 6.45, 0), which renders
    yellow-orange.
  - The "small dark windows" are the ends of the 3 `Log` blocks (#703E26) poking out of it.
  - The "golden rim" is `Rim` (#FFC93C 8.6 dia at y 5.9) on an iron `Bowl` (#5C626E 8 x 1.6) and `Stem`, on a slate
    `Step` #768096 and `Base` #4E566E.
  - The 4 arena copies are the boss arena's "warm safe spots" (`BossArenas.Tundra.WarmSpots`, design intent from
    `docs/ASSET_KIT_TUNDRA.md`). Each holds a child Part **`Fire`** (invisible 0.77 ball, CanCollide off, at the
    FirePoint (0, 6.55, 0) x 1.3) with Attachment `Fire`, 3 ParticleEmitters (Flame, Ember, Core) and a PointLight
    **#FFB85A, Brightness 0.9, Range 24**, Shadows off.
  - No script reads them (no warmth or cold mechanic in `src/`).
  - **Keep:** the `Embers` part with its `FirePoint`, and the arena copies' `Fire` part, emitters and light exactly
    (a MapPropKeep carrier, as for the batch 4 torch lights).
- **05 = `Ice_Wall_Panel`, an ice wall panel.**
  - A Glass `Pane` (#96D6FA T 0.45, 15.2 x 19.6 x 1.2) between 2 `Post`s 2.4 x 24 x 3 (#54A0E8) on a `Rail` #3468B4
    (bottom), under a `Rail` #54A0E8 (top).
  - The "checkmark" is its 2 `Facet` strips (#D6ECFF, 0.3 x 11 / 15, tilted -32 / +24 deg at x 3.4 / -2.5), which
    form a V.
  - Not a portal, quest marker or mirror.
  - The 4 `Decor.Exterior` copies are **walls**: their Pane, Posts and Rails collide and close the zone either side
    of the gate. Their collisions must stay exact.
- **03 throne:** the `Seat` is a plain Part, not a Seat: nobody can sit. It is not a boss or NPC spot (the boss
  stands at the `IceThrone` landmark). Keep the seat top at y 3.6 (kit) and the collisions.
- **06 lamp:** no light inside the model.
  - The light is a separate `Decor.VFX.Fire_Torch_Blue` part on each FirePoint (Tundra_4 BossGate x2, BossArenas x6),
    with a PointLight **#96D7FF, Brightness 0.9, Range 24**, Shadows off, plus blue fire emitters. The test and kit
    copies have none.
  - There is no on/off logic.
  - Keep the `Head` + `FirePoint` world position (the VFX parts do not move) and the Neon `Ember` (#60BEFF 0.9 ball
    at y 6.1).

**Colliders** (today's parts kept as invisible colliders at the copy's scale):

| Kit | Colliding | Not colliding |
|---|---|---|
| Ice_Pillar | Base, Plinth, 2 Shaft, Capital, Top | 2 Glow |
| Frozen_Knight_Statue | Plinth, IceBlock (the glass case, Glass T 0.55) | everything inside (legs, torso, arms, belt, guard, blade, grip, head, visor, plume, shoulders), 2 Shard meshes, SnowCap |
| Ice_Throne_Small | 2 Step, Seat, 2 ArmRest, Back, 2 Crystal meshes | Gem, 3 Spike meshes (CanQuery on) |
| Warm_Brazier | Base, Step, Stem, Bowl, Rim | Embers, EmberGlow, 3 Log (and `Fire`) |
| Ice_Wall_Panel | 2 Rail, Pane, 2 Post | 2 Facet |
| Blue_Torch_Standing | Foot, Pole, Head | Ember |

**Today's shapes and real colours** (kit space; keep the main colours):
- **01 pillar** (8 x 40 x 8):
  - Base 8 x 3 x 8 #3468B4, Plinth 6.4 x 2 #54A0E8;
  - Glow Neon #60BEFF 5.6 x 0.4 turned 45 deg at y 6.4 and 33.6;
  - 2 crossed Shafts (4.6 square #96D6FA + 4.5 square #54A0E8 turned 45 deg, y 5..35);
  - Capital 6.4 x 2 #54A0E8 at y 36, Top 8 x 3 #3468B4 (y 37..40).
- **02 knight:**
  - Plinth 8 x 2 x 8 #3468B4;
  - Legs 1.5 x 4 #5C626E; Torso 4 x 4.2 x 2.2 #686E7C; Arms 1.2 x 3.6 #686E7C (tilted 20 deg);
  - Shoulders 1.8 x 1.4 x 2.4 #5C626E; Head 2 x 2 x 2 #5C626E with the Neon Visor #60BEFF 1.4 x 0.3 at (0, 11.3, -1.02);
  - Plume 0.5 x 1.2 x 1.8 #BAAAEC;
  - Belt 4.2 x 0.7 #FFC93C;
  - sword planted in front: Blade #F5F6FA 0.5 x 6.6 at (0, 5.4, -1.7), Guard #FFC93C, Grip #703E26;
  - the case `IceBlock` 7.4 x 12.2 x 6 Glass #96D6FA T 0.55 at (0, 8.1, -0.2), SnowCap 7.8 x 0.6 x 6.4 #F4F8FF on top;
  - 2 Shards (spike meshes #96D6FA / #D6ECFF T 0.15) at the plinth's front corners.
  - **The owner's "green sash" is the gold belt seen through the cyan glass.** Keep it gold #FFC93C (a cloth sash
    #FFC93C / #C99A2E hanging from it reads as the owner's sash).
- **03 throne:**
  - Steps 9 x 1 x 8 #3468B4 and 7.5 x 1 x 6 #54A0E8;
  - Seat 5 x 1.6 x 4.4 #96D6FA (top y 3.6); ArmRests 1.2 x 2.4 x 4.2 #96D6FA;
  - Back 5.4 x 9 x 1.4 #54A0E8 (y 2.8..11.8, z 2.7); Gem Neon #60BEFF 0.9 diamond at (0, 9.6, 1.9);
  - 3 Spikes behind the top (#D6ECFF / #96D6FA, 5 / 7 tall, from y 11.1);
  - 2 Crystals at the sides (2.4 x 7.5, colliding).
- **04 brazier:** see above. Kit colours: #4E566E, #768096, #5C626E, gold #FFC93C, Neon #FF8C28, logs #703E26.
- **05 panel:** see above.
- **06 lamp:**
  - Foot cylinder 1.8 x 0.5 #3468B4; Pole 0.6 x 5.2 #4E566E;
  - Head cylinder 1.3 x 0.9 #5C626E (FirePoint at (0, 6.2, 0) in kit space);
  - Ember Neon #60BEFF.

**E9.1 Part rules**

**01 ice pillar** (same size; collisions = today's 6 parts):
- **Shaft:** `tundra_mon__pillar_shaft`, an 8-sided faceted ice shaft with entasis.
  - Faces alternate today's #96D6FA / #54A0E8 (they read as flutes), light chamfered edges, Glass T 0.15 over a
    #3468B4 core.
- **Glowing cyan chevrons:** on each of the 4 broad faces, 2 chevrons (V shapes) near the foot (y 6.5-8) and under the
  capital (y 32-33.5).
  - Each = 2 Neon #60BEFF strips 0.25 x 1.6 x 0.08 at +-35 deg, set 0.04 proud.
  - Today's 2 Glow rings stay as thin Neon bands under the chevrons (or go).
- **Capital** (carved; today's Capital 6.4 x 2 + Top 8 x 3):
  - an echinus band (8-sided, 6.2 -> 7.0, #54A0E8) under a chamfered abacus (today's Top, #3468B4, 0.25 chamfers);
  - 4 small corner volutes (cylinders 0.6 x 0.4 #96D6FA) at the abacus corners;
  - a `tundra_snow__cap` (8.3, 0.8, 8.3) on the Top, 4 icicles (scale 0.3-0.5) under the abacus corners.
- **Base:** today's Base + Plinth as a bevelled square base.
  - 2 stepped slabs with 0.25 chamfers and a 0.08 joint ring, 4 corner blocks.
  - Tiny frost crystals at the foot: `tundra_ice__shards` scale 0.35-0.5 at 2 corners, `tundra_snow__drift` small
    (3, 0.6, 1.5) on 1-2 sides.

**02 ice knight in glass case** (keep the size, the plinth and the case collider; nothing inside collides):
- **Armour:**
  - `tundra_mon__knight_armor` (great helm with a flat front for today's Neon visor, 2 pauldrons of 2 plates,
    4-segment plume in today's #BAAAEC);
  - the torso as a breastplate: today's Torso + a 0.2-proud chest plate with a centre ridge (2 wedges) and 3 #7A808C
    lames over the stomach;
  - plate legs: greaves (0.1-proud plates) and knee cops (0.5 cubes turned 45 deg);
  - the arms with couters (elbow plates) and gauntlets (1.3 blocks, #5C626E) resting on the sword pommel.
- **Belt and sword:**
  - today's gold Belt with a buckle, plus a sash: 2 hanging cloth panels 0.6 x 2.2 #FFC93C / #C99A2E (see above);
  - the sword planted in front: today's Blade with a fuller line (#D6ECFF), today's gold Guard (with 2 small end
    knobs), the Grip with a leather wrap and a gold pommel ball.
- **Carved plinth:** today's Plinth (8 x 2 x 8) with a 0.25 chamfered top edge and a carved frieze.
  - The frieze: a recessed band 0.3 tall, 0.08 deep, with 4 small Neon #60BEFF diamonds, one per face.
  - A darker #234A8F foot course.
- **Glass case:**
  - today's IceBlock stays the visible pane volume: Glass #96D6FA, T 0.55 -> 0.6;
  - 4 metal-like ice frame posts at the corners (0.45 square, #54A0E8 with #D6ECFF edge strips), a bottom frame and a
    top frame;
  - the lid: today's SnowCap as a white #F4F8FF lid slab 7.8 x 0.5 x 6.4 with a 0.15 rim lip and a
    `tundra_snow__cap` mound (7.6, 0.5, 6.2);
  - 2-3 icicles under the lid's front edge;
  - 2 faint reflection streaks per front / side pane: thin #F2F6F8 strips at 45 deg, 0.05 proud, T 0.5.
- **Shards:** the 2 Shards as `tundra_gate4__spire` scale 0.22 / 0.28 at today's places.

**03 ice throne** (keep the seat top y 3.6, the footprint and the colliders):
- **Stepped base:** today's 2 Steps as bevelled block courses: blocks 2-3 long, 0.08 joints, 0.15 chamfers, #3468B4 /
  #54A0E8 tones, and a frost line #E6EEF6 on the step noses.
- **Seat and armrests:**
  - a pale blue cushion on today's Seat: a soft convex pad 4.6 x 0.5 x 4.0 #D6ECFF, tufted with 4 small #BFE9F5
    buttons; the Seat itself stays #96D6FA;
  - armrests: today's ArmRests with a rounded front scroll (a cylinder 1.2 x 1.2 across the front end) and a chamfered top.
- **Back panel:** today's Back, tall, with a bevelled #3468B4 frame strip round its front face.
  - Inlay: today's Neon Gem as a glowing cyan diamond inlay in a recessed diamond frame (#234A8F 1.5, 0.1 deep, 4
    facets #96D6FA).
- **Crystal spikes:** `tundra_gate4__spire` instead of the 5 spike meshes. The 2 Crystal meshes stay invisible as
  colliders.
  - behind the top: (0, 11.1, 2.7) scale 0.4 yaw 90; (+-2.0, 11.1, 2.7) scale 0.29, leaning outward;
  - at the sides: (+-4.8, 0, 2.6) scale 0.43.
- **Frost:** a `tundra_snow__cap_shade` (5.6, 0.35, 1.6) on the back's top behind the crystals, and 2 small icicles
  under each armrest front.

**04 warm brazier, the "yellow dome pedestal"** (keep the size, the colliders, Embers + FirePoint, and the arena
`Fire` part with its emitters and light exactly):
- **Stone pedestal:** today's Base (#4E566E 7 x 1.2 x 7) and Step (#768096 5 x 1 x 5) as bevelled slate blocks.
  - 4 blocks per course, 0.08 joints over #3E4558, 0.15 chamfers, a 0.3 plinth lip;
  - `tundra_snow__cap` strips (scale (7.2, 0.35, 1.0)) on 2 sides of the Base top.
- **Stem and bowl:** today's iron Stem and Bowl in dark steel #3E4C66 with 2 riveted bands (#56688A).
- **Rim:** today's gold Rim with 16 small studs, and a `tundra_snow__cap` arc piece (2 of (3, 0.3, 0.8)) on the rim's
  back half, away from the fire.
- **Dome:** `tundra_mon__brazier_dome`, a warm glowing glass dome (Neon #FFB648, T 0.35) in a cage of 8 gold ribs and
  a brass crown ring.
  - The panels between the ribs are the owner's "small windows with frames and a warm glow".
  - Today's EmberGlow goes. Today's Embers disc (Neon #FF8C28) stays under the dome; the 3 Logs stay inside as the
    burning wood.
- **Light:** the arena copies keep their `Fire` (warm light #FFB85A 0.9 / 24 + emitters, at the FirePoint).
  - Add nothing to the kit / test copies (they had no light).
  - Optional, for the look without the VFX: a PointLight #FFB648 0.6 / 10 under the dome, only if the owner asks.

**05 ice wall panel with a checkmark** (keep the size and EVERY collider: 4 of the copies are the zone wall):
- **Frame:** thick bevelled ice-blue stone.
  - Today's 2 Posts and 2 Rails as frame members with 0.3 chamfers, a 0.2-proud inner bead (#96D6FA) round the pane;
  - 4 corner blocks (2.6 x 2.6, #3468B4) with a raised diamond stud each.
  - Base block: today's bottom Rail as a 2-step base (#3468B4 / #234A8F), with snow on its top front
    (`tundra_snow__cap` (15, 0.35, 0.8)).
- **Pane:** today's Pane, Glass #96D6FA T 0.45, with 3 subtle reflection lines (#F2F6F8, 0.08 wide, T 0.5, at 50 deg,
  0.03 proud, on the front face only).
- **Checkmark:** today's 2 Facets as a carved glowing check.
  - Each stroke = a bevelled bar (0.6 wide, 0.3 proud, #D6ECFF, chamfered) with a Neon #60BEFF inlay strip 0.15 wide
    along its middle.
  - Same angles and lengths as today; the 2 strokes meet in a mitred point.
- **Top:** a `tundra_snow__cap_drip` (15.5, 0.6, 3.2) on the top Rail, 4-6 icicles under it.

**06 blue lamp post** (keep the FirePoint world position, the Ember, and the VFX lights #96D7FF 0.9 / 24 on their
parts):
- **Base:** today's Foot as a bevelled octagonal slate base (#3468B4 -> #4E566E, 2 steps) with a
  `tundra_snow__cap_shade` (2.0, 0.3, 2.0) on it.
- **Post:** today's Pole as a slim chamfered post (#4E566E) with 3 dark-steel bands (#3E4C66, 0.15 proud) and frost
  rime on the top 1/3.
- **Lantern:** a bracket collar under the Head, then a small glass lantern round today's Ember.
  - Frame: 4 corner rods 0.08, base plate 1.3, an open crown ring (the VFX particles rise through it).
  - Panes: 4 glass panes #BFE9F5 Glass T 0.4.
  - Today's Neon Ember inside (keep it and its colour #60BEFF, or the cyan #35E6F5).
  - Today's Head = the lantern base, holding the FirePoint at its place.
- **Icicles:** 3-4 tiny icicles (`tundra_ice__icicle` scale 0.15-0.25) under the crown ring, and a tiny snow cap on it.

**E9.2 Facet pieces (tundra_monuments; plus the reused pieces of E7 / E8)**

| Piece | Faces (shells) | Origin / placement | Replaces |
|---|---|---|---|
| `tundra_mon__pillar_shaft` | 164 (2) | Ice_Pillar pivot; copy's Model scale | the 2 Shaft looks (kept as colliders) |
| `tundra_mon__knight_armor` | 159 (9) | Frozen_Knight_Statue pivot; copy's Model scale; inside the case (max x 3.65) | Head, 2 Shoulders, Plume (none collide) |
| `tundra_mon__brazier_dome` | 263 (33) | Warm_Brazier pivot (also the renamed `WarmBrazier`); copy's Model scale | EmberGlow |
| `tundra_gate4__spire` (E8) | 186 (4) | throne: 5 places (E9.1); knight shards: scale 0.22 / 0.28 | the throne's 3 Spikes + 2 Crystal looks, the knight's 2 Shards |
| `tundra_snow__cap*`, `tundra_ice__icicle`, `tundra_ice__shards`, `tundra_snow__drift` (E7) | | as listed in E9.1 | |

**Cost** (about 2 tris per facet face):

| Piece use | ~Tris per copy | Copies | ~Total |
|---|---|---|---|
| pillar shaft | 330 | 20 | 6.6k |
| knight armour | 320 | 12 | 3.8k |
| brazier dome | 530 | 6 | 3.2k |
| throne spires (5) | ~1.9k | 4 | 7.4k |

The caps and icicles come on top. On the 20 pillars, if needed, drop the shaft's bevel: 8 plain faces + the core =
about 40 tris.

### E10. Tundra props and decor (owner task 2026-10-22)

Images: `docs/Tundra_Images/04_Props_and_Decor/`. Data read from
`BackUP_Files/FightYourDestiny_2026-10-22_181154_before_tundra_props_{ServerStorage,Workspace}.rbxm`.
Same target and palette as E1-E2. Facet pieces: `tools/blender/fyd_facets.py -- tundra_props`, preview
`Previews/Props/tundra_props_facets.png`.

**E10.0 Kits, copies, functions**

All kits are in `ServerStorage.MapAssets.Tundra` (pivot = bottom centre, front -Z, SmoothPlastic). Every scaled copy uses
Model scale (checked part by part): **no bakedScale**. No hub copies.

| # | Owner's name | Kit (parts, bbox) | Placed copies (test = `_Staging.AssetPreview.Tundra`) | Total |
|---|---|---|---|---|
| 01 | frozen skeleton in ice | `Bone_Pile_Ice` (18; 7.3 x 3.2 x 5.8) | test; `Tundra_3.Decor.Props` x3 (one at (8030, **8**, 600) on a ledge); `Tundra_4.Decor.Props` x1; `BossArenas.Tundra.Decor.Props` x5 (scale 1.5) | 11 with the kit |
| 02 | ice fishing hole | `FishingHole` (12; 9.1 x 4.1 x 7.4) | test; `Tundra_2.Decor.Props` x4 (y 0.1, on the frozen lake) | 6 |
| 03 | sled | `Sled_A` (16; 3.6 x 2 x 10.4) | test; Tundra_1, Tundra_2, Tundra_3 x1 each | 5 |
| 04 | snowman, gray hat, purple scarf | **`Snowman_B`** (11; 6.7 x 8 x 3.7) | test; Tundra_1 x3; Tundra_2 x1 | 6 |
| 05 | snowman, blue hat | **`Snowman_A`** (12; 8.4 x 10 x 4.5) | test; Tundra_1 x4 | 6 |
| 06 | "ice drying rack" | **`Weapon_Rack_Frozen`** (16; 8 x 8.9 x 3.4) | test; `Tundra_4.Decor.Props` x4 (1.2); BossArenas x4 (1.3) | 10 |

- **Functions: none.**
  - No kit or copy has a script, ProximityPrompt, ClickDetector, Seat, tag or attribute.
  - `src/` has no fishing, sled, snowman or rack logic: "Fish" / "Snowman" there are only enemy rig families
    (`tundra_cursed_snowman`, `tundra_swordfish`).
  - **No fishing prompt exists.** The stool's `Seat` is a plain Part.
- **Game copies:** identical to their kits, except the 4 Tundra_4 racks: both Rails are 7.88 long (kit 7.8), and the
  Handle and SpearTip are shifted 0.04. Take their colliders from the game copies.
- **No nested MapProp in any kit:**
  - **02's "barrel" is NOT the `barrel` MapProp.** It is a plain `Bucket` cylinder (#5C626E iron, 1.4 x 1.4, collides)
    at (4.6, 0.7, -2.4).
  - The owner asks for "a wooden barrel with metal bands (same as the new barrel)": nest the existing `barrel` MapProp
    there as a keg at scale **0.4** (3.46 -> 1.38 wide, 1.62 tall), like the nested `Barrel` wrappers of the HunterCamp
    (the `barrel` rule already handles nested wrappers and their scale). Today's Bucket stays as the invisible collider.
- **What the owner's words map to:**
  - 02 "planks on the ice": the 2 blue `Fish` blocks (#4696D6 / #54A0E8) next to the hole.
  - 04 / 05: the GRAY-hat snowman with the purple scarf is `Snowman_B` (a tilted `Bucket` hat #5C626E); the BLUE-hat
    one is `Snowman_A` (top hat #4E566E).
  - 06 "ice drying rack": `Weapon_Rack_Frozen`, a frozen weapon rack.
    - The "blue flag" is the spear's `SpearTip` (#7080CC, 0.6 x 1.3 x 0.2) on its long `Shaft`.
    - The "cloth hanging" is the `AxeHead` (#5C626E 1.7 x 1.5 x 0.3) on its `Handle`.
    - The "faceted ice block" is the `Ice` mesh frozen round the `Blade` + gold `Guard` (a sword), and the "ice block
      base" is the lower `Ice` mesh.
    - Keep it a weapon rack, and add what the owner sees (E10.1).
- **Suggested propIds:** `tundra_bone_ice`, `tundra_fishing_hole`, `tundra_sled`, `tundra_snowman_gray` (Snowman_B),
  `tundra_snowman_blue` (Snowman_A), `tundra_weapon_rack`.

**Colliders** (today's parts kept invisible at the copy's scale):

| Kit | Colliding | Not colliding |
|---|---|---|
| Bone_Pile_Ice | every bone: Skull, 2 EyeSocket, Jaw, 3 Bone, 7 BoneEnd, 3 Rib | Ice mesh (CanQuery on), Snow mesh |
| FishingHole | Bucket, 3 Leg, Fork, Seat (the stool) | Rim, Water, 2 Fish, Rod, Line (the hole is flat and walkable) |
| Sled_A | 2 Runner, 2 RunnerTip, 4 Leg, 2 Cross, 5 Slat | Rope |
| Snowman_A / B | Base, Body, Head (Ball parts) | hat(s), eyes, nose, buttons, arms, scarf |
| Weapon_Rack_Frozen | Base, 2 Post, 2 Rail | 2 Ice meshes (CanQuery on), weapons, 3 Icicles |

**Today's shapes and real colours** (kit space; keep the main colours):
- **01 skeleton:**
  - `Ice` 6 x 3 x 5.5 #96D6FA T 0.4 at (0.6, 1.2, 0.4) (the rock mesh 7231644778);
  - `Skull` ball 2.4 #F0E8D0 at (0.3, 1.68, 0.2) with 2 `EyeSocket` blocks #3E3C4E at (-0.2 / 0.8, 1.88, -0.95);
  - `Jaw` 1.5 x 0.9 x 1.3; 3 Bones (cylinders 0.4-0.5, 3.7-5.7 long); 7 BoneEnds (balls 0.68-0.85);
  - 3 Ribs 0.3 x 2.2 at x -3 / -2.2 / -1.4, z -2.2 (they stick out of the ice);
  - `Snow` mesh 3.4 x 1.4 x 3 #F4F8FF at (-2, 0.4, 1.6).
- **02 fishing hole:**
  - Rim disc 7.4 #D6ECFF, Water disc 6.0 #3468B4 (both 0.24-0.3 thick at ground level);
  - stool: Seat disc 2.0 x 0.4 #865C42 at (4.4, 1.7, 0.5) on 3 Legs 0.3 x 1.6 #5C4236;
  - `Fork` post 0.3 x 2.2 at (2.9, 1.1, 0) holding the `Rod` (6 x 0.2, #865C42, tilted 25 deg); `Line` 0.08 x 3.8 #F5F6FA
    hanging at x -1.1 into the water;
  - Bucket, 2 Fish.
- **03 sled:**
  - 2 Runners 0.4 x 0.5 x 7 #5C4236 + RunnerTips (35 deg up at the front, -Z);
  - 4 Legs 0.4 x 1.2, 2 Cross bars 3.6 x 0.35 x 0.6 #5C4236;
  - 5 Slats 0.6 x 0.3 x 6.4 alternating #865C42 / #D6965C;
  - Rope 0.15 x 3.2 #C4A068 trailing from the front.
- **05 Snowman_A:**
  - balls Base 4.4 #F4F8FF (y 1.9), Body 3.3 #CEDEF6 (4.7), Head 2.4 #F4F8FF (6.9);
  - top hat: Hat 1.8 x 1.6 + HatBrim 2.7 x 0.3, #4E566E;
  - 2 coal Buttons 0.4 #1F222B; Eyes 0.35 #1F222B; Nose 0.4 x 1.4 #FF8C28;
  - 2 stick Arms 3.2 x 0.3 #5C4236 at +-25 deg.
- **04 Snowman_B:**
  - balls Base 3.6 #CEDEF6 (1.5), Body 2.7 #F4F8FF (3.8, x 0.15), Head 2.0 #F4F8FF (5.6, x 0.35) (a slight lean);
  - Scarf ring 2.1 x 0.5 + ScarfTail 0.6 x 1.6 #BAAAEC;
  - "Bucket" hat 1.7 x 1.3 #5C626E tilted 8 deg;
  - Eyes, Nose 0.35 x 1.2, 2 Arms 2.6 x 0.25 (-15 / -40 deg); no buttons.
- **06 weapon rack:**
  - Base 8 x 0.5 x 2.4 #5C4236; 2 Posts 0.6 x 6 #5C4236; 2 Rails 7.8 x 0.4 #865C42 (y 2.2 and 5.0, z 0.6);
  - Ice lump 7 x 3.2 x 3.4 #96D6FA T 0.4 at (0.5, 1.3, 0); Ice block 3 x 4 x 2.6 #D6ECFF T 0.4 at (-2.4, 4, 0.3);
  - sword (Blade #F5F6FA, Guard #FFC93C) inside it; axe (Handle #703E26, AxeHead #5C626E);
  - spear (Shaft #703E26 7.4 long, SpearTip #7080CC); all leaning 9 deg;
  - 3 Icicles #D6ECFF T 0.15 under the top rail.

**E10.1 Part rules**

**01 frozen skeleton in ice** (keep the size and every bone collider):
- **Ice block:** `tundra_props__skeleton_ice`, a faceted translucent block with light edges, Glass T 0.4, no core.
  Today's Ice mesh goes (it did not collide).
- **Skull:** `tundra_props__skull` (the C6 skull at scale 1.32 in today's bone colour, with today's socket colour
  #3E3C4E) on today's Skull / Jaw places. Today's 3 parts stay as invisible colliders.
- **Bones:**
  - today's 3 Bones as 8-sided shafts tapering slightly to the middle, with knobbed ends (2 overlapping balls per end,
    0.15 apart) at today's BoneEnds;
  - the 3 Ribs as curved ribs: 2 segments each, bent 20 deg, tapered, ending in the ice;
  - add 1 bone arm inside the ice: humerus + forearm (2 shafts 0.35, 1.8 / 1.5 long) and a hand of 4 finger bones
    (0.12), reaching toward the front face.
- **Frost:** 3-4 frost patches on the ice surface (thin #F2F6F8 quads, T 0.3, 0.03 proud, irregular 5-sided);
  `tundra_ice__shards` scale 0.3 at one foot.
- **Snow cap:** `tundra_snow__cap` (2.8, 0.35, 2.2) on the ice top, toward the back (+Z), so the skull stays visible.
  It replaces the Snow mesh.

**02 ice fishing hole** (keep every position and the stool / bucket colliders; no prompt to keep):
- **Hole:** today's Water disc as deep water like the fountain / well (A8): Glass #3468B4 -> a deep #1E5FA8 disc, T 0.15,
  plus the `water_lines` "Ripples" Texture; 0.35 below the rim top.
  - A darker #234A8F ring 0.3 wide on the inside wall.
- **Ice rim of cut slabs:** today's Rim as 10 cut ice slabs.
  - Each slab: an annular sector 0.35 thick, 0.7 wide, #D6ECFF tones, 0.08 joints, 0.1 top chamfer, light #BFE9F5
    edge; outer radius 3.7, inner 3.0.
  - A thin snow ring outside (`tundra_snow__cap` strips, 0.15 thick).
- **Stool:**
  - today's Seat disc as 3 planks (0.06 gaps) in a round outline, with 2 nails each;
  - 3 Legs as tapered, chamfered legs with cross braces (2 rungs 0.15 at y 0.6);
  - a small snow cap on the seat edge.
- **Barrel:** the `barrel` MapProp nested at the Bucket's place (4.6, 0, -2.4), scale 0.4 (the new barrel: staves,
  3 riveted hoops, lid). The Bucket stays an invisible collider.
- **Fishing pole:**
  - today's Rod as a tapered 2-piece rod (#865C42 -> #A86238) with 3 line guides (0.08 rings), a reel (#5C626E
    cylinder 0.35 + handle) near the butt;
  - the Fork as a forked stick (2 short prongs);
  - today's Line (keep its place) ending in a bobber: a red / white ball 0.3 (#D4343C top, #F5F6FA bottom) at the
    water surface, with a small Neon-free ripple ring (#BFE9F5, T 0.4, 0.6 across).
- **On the ice:** today's 2 Fish as fish (a body wedge pair + a tail fin, #4696D6 / #54A0E8, a lighter belly, a dark
  eye dot), plus 2 loose planks (#865C42, 0.8 x 0.15 x 2.4 and 2.0, crossed, a nail each) between the stool and the
  hole: the owner's "planks on the ice".
- **Snow:** 2 light snow patches (`tundra_snow__cap` (2, 0.15, 1.2)) on the ice; CanCollide off on everything new.

**03 sled** (keep the size and colliders):
- **Runners:** today's Runners + RunnerTips as one curved runner per side.
  - The tip: 3 segments curling up and back (35 / 70 / 110 deg), ending in a scroll.
  - A dark-steel edge strip (#3E4C66, 0.1 thick) along the underside and up the curl, with 4 rivets per side.
- **Bench:**
  - the 4 Legs with chamfers, the 2 Cross bars with a notch joint and 2 nails each;
  - 2 diagonal cross braces (0.2 x 0.2) between the legs on each side.
- **Slats:** today's 5 Slats with 0.08 gaps (as today) over 2 under-battens; 2 nails per slat per batten; ends
  rounded with a 0.1 chamfer; today's alternating #865C42 / #D6965C.
- **Rope:** today's Rope as a twisted rope.
  - 2 tilted 0.12 cylinders spiralling, #C4A068 / #A88A55;
  - tied to a front cross bar with a knot ball, ending in a frayed tuft (3 thin wedges).
- **Snow dusting:** `tundra_snow__cap` (3.4, 0.15, 5.6) over the back half of the slats, a pinch on each runner curl.

**04 / 05 snowmen** (keep the sizes and colours; ONE recipe for both, so they match):
- **Balls:** `tundra_props__snowball` / `_snowball_shade` at each Ball's centre and diameter (see the piece's place:
  white or shaded by today's ball colour), each turned a different yaw. The Ball parts stay as invisible colliders.
- **Hats:**
  - 04 (Snowman_B): a top hat in today's gray #5C626E, replacing the "Bucket": crown 1.5 x 1.3, brim 2.3 x 0.15, a
    band #3E4C66 0.25, tilted 8 deg like today.
  - 05 (Snowman_A): today's #4E566E top hat with a BLUE band #3468B4 0.3 and a 0.1-proud brim edge.
  - Both: a small snow cap on the crown (`tundra_snow__cap` (1.5, 0.2, 1.5)).
- **Scarf (04):** today's purple #BAAAEC as a knitted scarf.
  - The ring as 2 thick rolled turns (0.45) with 3 darker stripes #9A8ACC (0.15 bands);
  - a knot (a 0.5 ball) at the front left;
  - today's ScarfTail as 2 hanging ends with stripes and a fringe (4 thin wedges 0.15).
  - 05 gets no scarf (it has none today), or a blue one only if the owner wants them identical.
- **Face:**
  - `tundra_props__carrot` at today's Nose (A scale 1.0, B 0.86);
  - coal eyes as 5-sided chunky lumps 0.35 (#1F222B), 0.1 proud;
  - a smile of 5 coal pebbles 0.18 under the nose.
- **Buttons:** 05 keeps its 2 buttons as coal lumps 0.4 and adds a third (y 3.6); 04 gets 3 coal buttons 0.32 on the
  Body (owner: "coal eyes and buttons").
- **Arms:** today's stick Arms as 8-sided sticks (#5C4236) tapering to the tip, each with 2 twigs (0.08, 0.6 long,
  at 35 deg) and a fork at the end.
- **Base:** a low `tundra_snow__drift` ring (2 small drifts (2.4, 0.5, 1.2)) at the foot.

**06 frozen weapon rack, the owner's "ice drying rack"** (keep the size and colliders):
- **Frame:**
  - today's 2 Posts and 2 Rails as a sturdy frame: chamfered posts with pyramid caps, the rails cross-lapped into
    the posts with 2 pegs each;
  - a third crossbar at y 3.6 (no collider), rope ties (#C4A068, E2) at every rail-post joint;
  - frost rime on the top rail, a snow cap on each post cap and on the top rail (`tundra_snow__cap` (7.6, 0.3, 0.6)).
- **Plank base:** today's Base as 4 planks along X (0.06 gaps, nails), on 2 cross battens, a snow strip at the back.
- **Ice:** `tundra_props__rack_ice` (the faceted lump on the base + the faceted block round the sword).
- **Weapons:** today's places and angles.
  - Spear: the blue SpearTip as a bevelled spear head, plus a small blue pennant (#7080CC, 2 triangles 0.8 long)
    tied under it with a cord: the owner's "blue flag".
  - Axe: the AxeHead with an edge bevel and a cloth strip wrapped round the handle under it, hanging 1.2 (#7080CC or
    #E8E2D0): the owner's "cloth hanging".
  - Sword: the frozen sword kept as it is inside the block (blade with a fuller line, gold guard).
- **Icicles:** today's 3 + 3-4 more (`tundra_ice__icicle` scale 0.3-0.6) under the rails, a small icicle cluster under
  the top rail's middle.

**E10.2 Facet pieces (tundra_props; plus the reused pieces of E7)**

| Piece | Faces (shells) | Origin / placement | Replaces |
|---|---|---|---|
| `tundra_props__skeleton_ice` | 225 (1) | Bone_Pile_Ice pivot; copy's Model scale | the Ice mesh (no collision) |
| `tundra_props__skull` | 74 (2 hulls + detail faces) | Bone_Pile_Ice pivot; skull centre (0.3, 1.85, 0.2), scale 1.32 built in | Skull, 2 EyeSocket, Jaw looks (kept as colliders) |
| `tundra_props__snowball` / `_snowball_shade` | 78 (1) each | own anchor = ball centre, diameter 2; scale = Ball diameter / 2 | the 3 Ball looks per snowman (kept as colliders) |
| `tundra_props__carrot` | 26 (1) | own anchor = the thick end's centre, points -Z, 1.4 long; A (0, 6.9, -0.9) scale 1, B (0.35, 5.6, -0.7) scale 0.86 | Nose |
| `tundra_props__rack_ice` | 295 (2) | Weapon_Rack_Frozen pivot; copy's Model scale | the 2 Ice meshes (no collision) |

**Cost:**
- snowballs 3 x ~160 tris x 12 snowmen = 5.8k;
- skeleton ice + skull ~600 x 11 = 6.6k;
- rack ice ~590 x 10 = 5.9k;
- carrots 52 x 12.
- About 19k triangles in all, plus the parts and the reused caps, icicles and the 6 nested barrels.

## F. Cursed Swamp (owner task 2026-10-24, "Buildings and huts")

Images: `docs/Swamp_Images/01_Buildings_and_Huts/`. Same quality target as section A (the well): low-mid poly,
bevelled planks and blocks with visible joints, thick timber with rope and iron bands, small readable details, soft
gradients, clean saturated colours; no PBR, no grain. Mood: dark, damp, a little creepy but cartoon and readable (all
ages): moss and lichen, dripping vines, rotten and cracked wood, small mushrooms, no gore. Parts + unions only.

### F0. Kits, copies, functions

Kits in `ServerStorage.MapAssets.Swamp` (pivot = ground centre, front -Z, SmoothPlastic, no union, no tag).

| # | Owner's object | Kit | Parts | Copies (test = `_Staging.AssetPreview.Swamp.*`) |
|---|---|---|---|---|
| 01 | stilt hut, green roof | `Stilt_Cabin_A` (18 x 29.7 x 20.5) | 26 | 6: test, kit, `Zones.Swamp.Swamp_3.Decor.Village.Cabin_1 / 3 / 5 / 7` |
| 02 | witch hut, purple hat | `Stilt_Cabin_B` (14.3 x 36.7 x 18.7) | 24 | 5: test, kit, `Village.Cabin_2 / 4 / 6` |

- **Functions:** none scripted. No script, prompt, ClickDetector, light, tag or attribute in a kit, a copy or within
  22 studs; no script names them. The village copies are renamed `Cabin_<n>` (Model scale 1).
- **Glow points:** Neon `Window` (01 #FFC460, 02 #AA50FF) and Neon `Lantern` #FFC460. There is no PointLight today.
- **Collisions:** stilts, deck, body, door, lintel, window and frame, roof planes / hat tiers, ridge, gable facets,
  chimney collide. Lantern, its bracket, the 02 brace, the ladder rails and rungs do not.
- **Ladders:** the rails and rungs are CanCollide AND CanQuery false. They are decorative today (not climbable), and
  they stay that way.
- **01 roof:** its 2 Roof planes are 0.05 apart along Z on Cabin_1 / 5 / 7, and Cabin_3's right plane is 13.6 deep.
  Variants switch the matching invisible roof colliders on.

### F1. Palette (the owner's examples next to the real kit colours; keep the REAL ones, tones x1 / x0.93 / x0.86)

| Role | Owner | Real colour (keep) | Used by |
|---|---|---|---|
| swamp mud | #5A4128 | **#684C34** (Deck, Rung) | deck planks, ladder rungs, mud at the stilt feet |
| dark mud | #3A2A1C | new accent | the wet band at the water line, deck underside, joints |
| rotten wood | #4A2A1A | **#5E4531** / **#57402E** (Body), **#58412F** (gable facets), **#4E3A2C** (Stilt) | wall planks, gables, stilts |
| near-black wood | #2A1E1A | **#322620** (Stilt, Door, frames, ridge, rails, hat brim) | posts, door, window ring backing, beams, brim |
| roof green | (moss #3F7A2C) | **#354027 / #3C4D2A** (01 Roof) | 01 shingles in 3 tones; moss on them in #3F7A2C |
| moss | #3F7A2C | new accent | moss patches, hanging moss, algae |
| olive | #8E9A2E | new accent | lichen spots, the lighter top layer of moss, vine leaves |
| purple hat | (magic purple #7A2BC8) | **#472859 / #532D6D** (02 hat tiers) | 02 hat shingles; #7A2BC8 only as a thin highlight on tier lips |
| toxic glow | #C8E83A | new accent (Neon only on a glow point) | the inner ring of 01's porthole glow |
| magenta glow | #E83AE8 | new accent | the pupil of 02's eye window (inside the #AA50FF glow) |
| warm glow | (keep) | **#FFC460** (Window 01, Lanterns) | porthole, lanterns, the hanging tag |
| ghost mushroom | #BFF5F0 | new accent (not Neon: they do not glow today) | mushroom caps; stems bone #F2E4C0 |
| bone | #F2E4C0 | new accent | mushroom stems, potion corks |
| dark water | #1E4A4F | new accent | algae band and wet stains at the stilt feet |
| iron | (A7) #5C626E | **#373A41** (lantern bracket) | straps, porthole ring, hinges, buckle |

### F2. Part rules

- **Rot / cracks:**
  - planks 0.9-1.1 wide, 0.16-0.2 thick, with 0.05 gaps over a dark core, tones x1 / x0.93 / x0.86;
  - 1 plank in 4 is shorter (a broken end with 2 splinters) or tilted 2-4 degrees;
  - cracks are thin dark #2A1E1A strips (0.06 wide, 0.02 proud) in 2-3 zig-zag segments;
  - the bottom 0.6 of every wall plank and stilt is x0.8 darker (damp).
- **Moss and lichen:**
  - **Moss:** soft layered mats (the jungle mossPatch / mossDrape recipe, recoloured #3F7A2C -> #4C8A33 -> #8E9A2E),
    2-3 stacked rounded layers, never a flat green box. It lies on tops, roof shingles, sills and the deck edge.
  - **Lichen:** small olive #8E9A2E discs (0.3-0.6, 0.04 thick) in groups of 2-4 on the walls.
- **Dripping vines and hanging moss:**
  - **Vines:** the jungle vine recipe (tapering stems, alternating leaves) in #3F7A2C / #8E9A2E, 1.5-3.5 long, from
    eaves and the deck edge.
  - **Hanging moss:** thin strands (0.12-0.2 wide, 1-2.5 long) in 2 tones, with a drip ball at the tip (dark water
    #1E4A4F).
- **Water line / algae:** a #1E4A4F -> #3F7A2C band 0.5 tall around each stilt at the foot, with a mud collar #3A2A1C.
- **Mushrooms:** in clusters of 2-4 at a stilt foot, on the deck or on a ledge:
  - stem: bone #F2E4C0, 0.12-0.25 wide;
  - cap: a flattened ball, cyan-white #BFF5F0 with a #8FD8D0 underside, 0.3-0.8 wide;
  - SmoothPlastic, not Neon.
- **Glow:** Neon only on today's glow points (window, lantern). Keep the glow colour. An inner accent ring may use
  #C8E83A (01) or #E83AE8 (02). No PointLight is added (none exists today; the main agent's decision).
- **Iron:** straps 0.3 wide, 0.06 proud, #5C626E, with rivets #7A808C. Porthole ring: 0.35 wide, 8 rivets.
- **Collisions:** every visible union has CanCollide false. Invisible `Collision` parts are exact copies of today's
  colliding parts. The ladder stays non-colliding as today.

### F3. Docks and platforms (owner task 2026-10-24: plains + swamp, one recipe)

One recipe, `tools/PropsDocks.luau` `build()`. The plains pieces are built first; each swamp piece is the same build
run with the swamp style.

| Piece | Kit | Derived from |
|---|---|---|
| 06 plains plank platform | `Common.Dock_Section` | (plains base) |
| 05 plains deck with rails | `Common.Bridge_Wood_Section` | (plains base) |
| swamp 01 large dock | `Swamp.Walkway_Section` | 06 |
| swamp 02 small dock | `Swamp.Walkway_Corner` | 06 |
| swamp 03 ramp dock | `Swamp.Stilt_Platform` | the same plank / rail recipe |
| swamp 04 rail dock | `Swamp.Rope_Bridge_Swamp` (= 05 recoloured) | 05 |

- **Walk surfaces are sacred.**
  - Each kit plank becomes boards about 0.95 wide (0.06 gaps over a dark core, 3 tones, chamfered top edges, butt
    joints on boards over 9 long).
  - The board TOPS are exactly the kit plank's top.
  - Only these may stand above a walk top: nail heads (0.04), crack lines and knots (0.015), and the swamp's flat
    algae stains (0.016). Nothing else, so no moss mats, mushrooms or mud on a walk surface.
  - No missing or broken planks: use cracks instead (main agent).
- **Posts:**
  - Piles and platform posts are round 8-sided logs with a cap disc and a low dome, a rope wrap above or below the
    deck, and an iron band.
  - Rail posts are chamfered timbers with a 4-sided pyramid cap and an iron band.
- **Under the deck:** stringers are chamfered timbers with bolts. X braces with a rope lashing go between neighbouring
  supports on the long sides, on their inner faces, below the stringers (so the piece keeps its size).
- **Rails:** bevelled-top timbers, each held to every post it crosses by an iron U-bracket (top strap, 2 side straps,
  2 rivets).
- **Plains:** grass tufts (thin wedge blades #54AA3A / #6CBE46 / #468E32) at the feet, on the inner sides, and along
  the long edges of a deck lying on the ground.
- **Swamp:**
  - colours: the kits' own darker colours, a rotten board now and then (x #3A2A1C), more cracks;
  - water line: algae (#1E4A4F -> #3F7A2C rings) and a mud collar at the post feet;
  - moss: hanging moss under raised decks and on a rail, moss on one cap;
  - ghost mushrooms at post feet (never on a deck);
  - rusty-iron lantern HOOKS (no lamp, no light), pointing away from every walk-over.
- **Per-copy walk colliders:** the game copies of 06 and swamp 01 have their own plank heights (+0.05 .. +0.15).
  - Their planks (and 01's stringers) are not in the template.
  - Each copy keeps its own, invisible, in a `WalkCollision` folder (MapPropKeep).
- **Open-side variants:** the 4 village ramp docks miss the side rail where a rail dock joins them. Variants
  `OpenLeft` / `OpenRight` hide that side's rail union and switch its collider off.

### F4. Gates and entrances (owner task 2026-10-24)

`tools/PropsSwampGates.luau`, one builder per gate. Each builder starts from the parts of today's gate (rows in
`tools/PropsSwampGatesData.luau`) and reuses the finished recipes:

| Gate | Base recipe | Swamp touches |
|---|---|---|
| 01 mushroom vine arch | plains entry arch | rotten 8-sided logs, mud bases, moss mats and hanging moss, curtains of leafy vines |
| 02 wooden gate, dead trees | plains / tundra palisade | today's tree meshes kept as trunks; roots, bark shelves and bare branches placed on the probed trunk surface |
| 03 rock barricade | jungle barricade + jungle rock (convex hull of today's mesh) | moss caps that follow the facets, bone thorns, orbs in iron rings |
| 04 skull palisade | plains / tundra palisade | 2 crooked planks per trunk, broken stubs, a rounded bone skull with a round iron ring |

- **The gate contract** (as for the jungle and tundra gates):
  - the Barrier stays the PrimaryPart and keeps its collision;
  - everything on the door or barricade, glows included, goes under the Barrier, so it hides when the gate opens.
- **Glows are kept part for part:** the ghost mushroom meshes, the lantern cores and lights, the magenta orbs / eyes /
  crosses, and the shelf mushrooms. Only their frames are new.
- **Meshes that collide today** (the trees and rocks) keep a Hull copy of the mesh as their collider. The visible new
  pieces never collide.
- **Kit vs game differences:** when a kit's colliders differ from the game copy even slightly (0.0005 is enough to move
  grazing rays), give the kit its own colliders and switch them with a Variant. Check with an off-lattice ray grid
  against the deserialized backup.

### F5. Trees and nature (owner task 2026-10-25)

`tools/PropsSwampTrees.luau`. These kits are scattered by the dozen (36-80 copies), so every piece is cheap and the
budget per copy decides the recipe.

| Piece | Recipe | About |
|---|---|---|
| Trunk | 8-sided log segments about 3.6 long, each turned 17 degrees further, a tone step each; 2 dark bark grooves per segment winding with it; a knuckle at each bend | 30-50 tris a segment |
| Prop root / rim root | a quadratic arch from today's top to today's foot, 3 tapering 5-sided segments; a 7-sided mud collar where it meets the ground | 100 a root |
| Leaf cluster | an 18-plane faceted blob, faces toned by their normal: lit top x1.12, dark underside x0.62 leaning to the wet teal #1E4A4F | 45-60 |
| Canopy | per canopy disc of today: a centre cluster and a ring of 5-9 flatter clusters tipped down 14 degrees; 2 drooping leaf tips under each ring cluster | 600-1300 |
| Leaf | a folded convex rhombus: a mid-rib ridge, lighter and darker halves, a dark back | 12 |
| Vine | non-overlapping square stem segments 1.2-1.5 long, a leaf at every joint on alternating sides, a tip leaf; flat mode for a thin curtain | 100-150 |
| Moss | one 18-plane cushion (#3F7A2C, top #5B852D); strands of 4 bars with a wet drip | 45 / 70 |
| Mushroom | a 5-sided bone stem and a 6-sided ghost cap #BFF5F0 (no Cylinder: about 200 triangles in a union) | 30 |

- **Costs:** TB.lump (26 planes) is about 90 triangles. Overlapping pieces in one union add the cost of their
  intersection, so stems and strands are built end to end.
- **Glows:** faces, runes, pools and crystals are kept part for part; the carving goes round them (brows, lips,
  grooves, rims).
- **Far copies:** a far-away form gets its own propId and a low-detail template. Copies whose colliders differ from each
  other by float noise keep their own colliders in a MapPropKeep folder.

### F6. Magic props and decor (owner task 2026-10-25)

`tools/PropsSwampMagic.luau`. Small props in many copies: each one keeps its glowing parts exactly and is carved round
them.

| Piece | Recipe | About |
|---|---|---|
| Rounded stone body / head | `roundSolid`: the kit box with a flat bottom, back and front (the kept eye and mouth bars stay put); top and sides cut by an ellipsoid's tangent planes (12 azimuths x 4 elevations) | 150-250 |
| Frog grin | `grin`: an upper and a lower lip of 9 bevelled segments on a shallow arc, the end ones wrapping round the cheeks; dark curled corners extend the kept mouth bar | 200 |
| Frog leg | `roundLeg`: an 8-sided column, a shoulder blob, a flat web leaf and 3 splayed toe bars with round tips | 250 |
| Iron | #373A41, light #545862; rivets as 6-sided studs; ring handles as bar rings (6-10 segments) | 24 a rivet |
| Glass | Glass material, transparency 0.4-0.6, pale #C7D3C0 (bottles) or warm #FFE2A0 (lantern panes) | - |
| Cauldron belly | 5 stacked 12-sided frustum bands: a round bottom, a straight middle, a neck under the rim lip | 600 |
| Raven | 18-plane blobs toned blue-black #1B1D26 to a sheen #343E54 on the lit faces; feathers are folded convex leaves (3 per wing, 4 in the tail) | 830 a bird |

- **Kept per copy:** colliders that drift between copies (a KeptCollision folder, `SM.prepColliders`) and lights (an
  invisible `KeptLight_<part>` holding today's light, `SM.prepLights`). Both are MapPropKeep and are taken from the
  untagged before-stash before the sync.
- **Nested props:** a prop that sits on another prop's template (the raven on the 2 swamp gates) is the tagged
  template itself, scaled and placed at the old pose. The sync's later pass keeps it current.
- **Budget:** the many-copy kits stay under 1,000 triangles (lantern 900, raven 830, bottle 550, spellbook 630).

### F7. Objects reused from other biomes (owner task 2026-10-25)

`tools/PropsSwampReuse.luau`. When a finished version exists in another biome, duplicate it and only adjust it.

- **Recipes** (barrel, lily pads): copy the builder's recipe and change only the colours and the swamp extras.
- **MeshParts** (the plains scarecrow and rowboat): clone them from the template (`SR.baseCopy`), recolour, and leave
  out the parts the swamp look replaces (the button eyes, the straw hat).
- **Swamp extras:** moss cushions, algae and mud bands along a measured surface, slime drips, torn cloth, a nested
  swamp_raven.
- **Placement on a mesh:** measure the mesh surface first (PreciseConvexDecomposition on a preview clone, then
  raycasts). Store the samples in the builder; never guess.
- **Colliders:** always the swamp kit's own parts, never the base's simplified colliders. Keep them per copy when the
  copies differ.
- **Glass:** Glass material mirrors the sky (blue). For a wet sheen use a translucent SmoothPlastic film with
  Reflectance 0.2.

### F8. Round 2: rounder, integrated (owner task 2026-10-25)

- **Rounded solids:** `SM.ellipsoidSolid(list, frame, radii, toneOf, nAz, elevations, { bottom, front })`: the tangent
  planes of an ellipsoid, the rings staggered, a flat bottom (sits on its support) and an optional flat front (a face
  that keeps kept bars proud). Frog bodies and heads, totem heads, the skull. About 150-300 triangles each.
- **Faces:** keep the kit's glowing / dark parts exactly and build the expression round them: an open crescent under a
  kept mouth bar reads as a grin; lid caps cut from an ellipsoid make sleepy eyes; a small dark oval reads as surprise.
- **Carved into, not floating:** a strip that must glow (runes) sits in a dark channel between 2 raised bark ridges
  that follow its own lean, so it reads as carved.
- **Dead-tree recipe:** `ST.deadTrunk` (tapered 8-sided segments, wobble and twist, raised ridges and dark grooves,
  knuckles; a skip sector for a face) and `ST.fineBranch` (70 % limbs, more twigs). Shared by the face tree and the
  wooden gate's trees.
- **Nesting:** an emblem that is another prop is that prop's template nested at the measured scale (the gate skull is
  the knocker x 1.9), so both stay in sync.
- **Random streams:** additions get their own `Random` so the rest of a builder (mud, moss) is drawn exactly as before
  and the bounding box does not grow.

### F9. The big landmarks (owner task 2026-10-25, round 3)

`tools/PropsSwampLandmarks.luau`. Map-only stand-ins become MapProps first (`capture()`), then a builder remakes them.

- **Capture:** a rule that matches `Landmark` + LandmarkName, tagAll, then `Sync.capture(propId, instance)`. The map
  instance is re-placed by an identical template copy; check every part afterwards (here all within 0.001).
- **Data at full precision:** write the rows with `%.9g`. Six digits drift colliders by 0.0001, and ray grids then
  show grazing differences on coplanar faces.
- **Pivots:** capture can leave a 1e-7 rotation noise on the instance pivot; put the original pivot back.
- **Timber-frame walls:** per face, vertical planks in 3 tones with gaps over a dark core, cut round the openings
  (each opening's rectangle in the face's (along, up) coordinates), corner posts, a beam at the foot and the top, a
  brace on faces without an opening. One union per wall tier.
- **Witch hat:** per tilted tier, a 12-sided core frustum and 2 rows of 12 overlapping shingle plates tangent to it;
  the last tier curls to a point; a drooping 16-sided brim; a dark band with a gold buckle facing the door.
- **Big faces:** a rounded face mound (`SM.ellipsoidSolid` with a flat front at the kept face parts), brows of 5 lumps
  per eye, a dark recess and a shadow ring per socket, a long tapered nose, crooked lips and a few teeth; keep roots
  and branches out of the face.
- **Nested props:** rebuild from their templates at the recorded poses and scales; a nested lantern that carried its
  own light gets a `KeptLight_Lantern` part (MapPropKeep) with that light.

### F10. Round 5 recipes (owner task 2026-10-26, "ROUND 5" Task 2 / Task 3)

`tools/PropsRound5.luau`. Each builder clones today's template, turns today's visible colliding parts into invisible
`Collision` parts of the same shape, adds the new visuals (CanCollide false) and merges them into one union per name.

- **Reuse first (PRIORITY RULE):** an improved template is duplicated and fitted (`P.fitInto`: a union clone scaled
  into a box via ExtentsCFrame / ExtentsSize; or the template's MeshParts scaled per axis, recoloured): the oasis well
  is the plains well in sandstone (x / z 1.5, y 1.2); the waterfall cliff stacks 3-5 jungle_rock_large boulders per
  rock (half-turned, tapering, the boulder's moss cap on the top one); water is the fountain's rippled LowerWater /
  UpperWater mesh resized.
- **Egyptian gate recipe (desert):** coursed pylons (H.course, 3-stud courses, running bond) on dark plinths with
  2 carved grooves per face, flared capital + gold rim, chamfered gold / lapis bands with lapis squares / gold
  diamonds, a 2-course lintel with gold rules, a 2-tier gold cornice, gold leaf frames with 2 stud columns per leaf,
  gold bezels round gems, a 12-segment gold ring round a sun disc, feather layers under wings.
- **Strata slab (red rock):** `P.strataSlab` = a convex solid (TB.solidOf) of the slab's box with jittered bevel
  planes on every edge, tone by face (top x1.12, underside x0.72); every third slab proud / set back.
- **Jungle stone (gates, idol base, pyramid, door):** `PropsJungleBuildings.stoneFace` on each exposed face (for
  X-facing faces build it as a front face and turn the pieces by +-90 degrees about Y), the part itself darkened to
  STONE_DARK as the mortar core; mossPatch / mossFacet / vineFacets / vine for moss and vines; frustumN for fangs,
  drums, bowls and octagonal columns (turn 22.5 degrees to put a flat face under a front glyph).
- **Seated idol:** chamfered blocks with large chamfers (2.4-3.0) read as rounded gold; limbs as octagonal frustums
  along a segment (H.frameY); faceted 4-sided feathers / spikes; gems as non-neon teal diamonds (the eyes stay the
  only glow).
- **Ice castle door (tundra):** `PropsTundraGates.iceFace` blocks over a deep blue core; per leaf face an icy Glass
  frame (T 0.1), frosted Glass panels (T 0.15) with a slim frost lattice and rime triangles in the corners; faceted
  gold spikes as 4-plane pyramids (TB.solidOf) so a crown emblem has depth; today's gems kept proud of the new band.
- **Hidden backing:** a big flat collider that shows behind new detail (the waterfall cliff's CliffCore) stays the
  collider with Transparency 1.

## G. Boss room brick (owner task 2026-10-26, round 6 Task B: Desert / Jungle sub-zone 4 + boss arenas)

Texture only: a `Texture` per inner face of the existing walls, floor and ceiling parts (no new geometry, no change
to Size, CFrame, collisions, scripts or attributes). Images drawn by `tools/textures/make_brick_textures.py`
(procedural, deterministic): flat bevelled bricks (2-step light top / left, dark bottom / right bevel, soft vertical
gradient), 4 px darker joints, per-brick colour pick plus a +-6 % jitter, a few thin cracks and chipped corners, no
photo or PBR noise. Ids in `Config/PropTextures.luau` -> `BossRoomBrick`.

| image | size | covers | id |
|---|---|---|---|
| desert_brick | 256 x 256 | 8 x 8 studs, 4 rows of 4 x 2 stud bricks, running bond | rbxassetid://103191534263698 |
| desert_frieze_strip | 256 x 1024, alpha | 8 x 32 studs, ONE row of alternating blue / gold bricks (row 2 from the top) | rbxassetid://97451078325225 |
| jungle_brick | 256 x 256 | 8 x 8 studs, same layout | rbxassetid://96625564941177 |
| jungle_moss_strip | 256 x 1024, alpha | 8 x 32 studs, ONE row of moss-tinted stone (row 15 of 16) | rbxassetid://81114154147595 |

Colours read from the door / gate templates (`DevTools` histogram by part volume, 2026-10-26):
- **Desert** (pylon_temple_gate, desert_gate_door, desert_gate_boss_gate): sandstone bricks #9D7C53, #9A7A52,
  #8E714B, #A6845A, #B58E59; joints #6A4A2E (the gate's dark trim #703E26, softened); frieze blue #2C5CC8 and gold
  #FFC93C (the door panels and inlays).
- **Jungle** (face_temple_gate, jungle_gate_boss_gate, jungle_gate_door): stone #5C645C, #606960, #686D62, #71766A,
  #6A7266; joints #3E453E (darker green-grey); moss #5B9C44 / #579441 mixed 35-65 % into the stone for the moss row.

Settings:
- Walls: brick Texture, StudsPerTileU = V = 8, Color3 white (the colours are in the image).
- Floor: the same image, Color3 about #D0D0D0 (slightly darker than the walls); ceiling Color3 about #B8B8B8.
- Frieze (desert) / moss row (jungle): a second Texture on the same wall face with the strip image,
  StudsPerTileU = 8, StudsPerTileV = 32, and OffsetStudsV chosen per face so the row lands near the top (frieze) or the
  bottom (moss) on a brick row of the base texture. Faces taller than 32 studs get one extra row every 32 studs; where
  a wall already has a separate frieze / base-band part, that part gets the strip colours instead.
- Part Material stays SmoothPlastic so no Roblox material pattern fights the bricks.

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
