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
