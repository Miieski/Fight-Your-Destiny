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
