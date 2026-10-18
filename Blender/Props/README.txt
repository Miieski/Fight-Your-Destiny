FIGHT YOUR DESTINY - PROPS (Blender sources) + PROP STYLE GUIDE
=================================================================
Brief: docs/model_upgrade_brief.txt (19 -> 18 hub / world props "a bit more realistic, low-poly fantasy kept").
Inventory of the current models (sizes, colours, places): docs/prop_inventory.md (Agent B).
Every prop of the upgrade follows THIS guide so the 18 models look like one family. Written 2026-10-18 (Agent A).

TOOLS (headless Blender 5.2, or the same code from the Blender MCP; it then works in its own scene "FYD_Props")
  tools/blender/fyd_props_textures.py   the shared tileable textures (numpy, built-in PNG writer) -> textures/
  tools/blender/fyd_props.py            the pipeline: helpers, materials, previews, .blend, FBX, data, manifest
  tools/blender/fyd_props_recipes.py    one recipe (Python function) per prop id (RECIPES = {id: fn})
  tools/blender/fyd_props_run.py        batch runner:
      "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup ^
          --python tools/blender/fyd_props_run.py -- well chest
      ... -- --lineup Batch2 chest rowboat ...   lineup Previews/Props/<name>_lineup.png (real relative scale)
      ... -- --luau                               regenerate Blender_Exports/Props/PropMeshData.luau only
      ... -- --init-manifest                      add the missing rows of props_manifest.csv
      ... -- --sample                             throwaway end-to-end test prop "zz_sample" (delete its outputs)
  tools/blender/fyd_props_check.py      re-imports an exported FBX + reopens its .blend in a clean Blender and
                                        compares names / triangles / raw size / vertex colours with the JSON
  The .blend files are the SOURCE OF TRUTH; to change a convention, change fyd_props.py and re-run the recipes
  (a prop rebuilds in a few seconds).

=================================================================
1. STYLE (brief section 2)
=================================================================
- Between low-poly and realistic: believable shapes and proportions (planked wood, riveted metal, cut stone,
  woven straw, folded cloth), clean faceted geometry, light bevels. Not photoreal, not noisy, not cartoon-flat.
- Keep every model's MAIN colours (table below = today's Part colours). Variation is subtle: a per-piece tone,
  lighter bevelled edges, darker ground contact (vertex colours), plus the texture detail. Never recolour the world.
- Faceted: flat shading on blocks, stones, planks; smooth shading only on the round sides of posts, axles,
  ropes, buckets (the pipeline does it per primitive).
- Silhouette and footprint: bounding box within +10 % of the current one (docs/prop_inventory.md), same pivot,
  same front, same ground contact. Nothing deeper than 0.06 studs under the ground contact (the pipeline flattens
  half-buried lumps there).

=================================================================
2. PALETTE (hex = the colour the part must LOOK like = today's Part.Color)
=================================================================
Source: the current models use the BuildKit palette (tools/BuildKit.luau Kit.Palette Common / Hub / Plains),
measured on every model by Agent B. The reference photos were sampled too (Model_References, median of lit
faces): they show the same colours after the hub's colour grading (about +15 % brightness and saturation, e.g.
crate panel 214,150,92 -> #EFAE58 in photo 03, posts 112,62,38 -> #983C13 in photo 02, grass 98,208,64 ->
#51E12B), so the real Part colours are used. Shades marked * are derived (darker crevices / worn variants).

"Tint" = the value to put in SurfaceAppearance.Color (imported MeshParts) or BasePart.Color (Studio Parts
with a MaterialVariant): the tint MULTIPLIES the near-white ColorMap, so tint = hex / ColorMap mean, scaled
uniformly so no channel passes 255 (the hue is kept; Gold, the light cloths and straws render a few % darker).
PropMeshData.luau already holds the tint of every mesh ("Color") next to its target hex ("Target").

  Name          Hex       RGB            Family (texture)      Tint (RGB)       Used for (today's parts)
  -- wood -------------------------------------------------------------------------------------------------
  WoodLight     #D6965C   214,150, 92    Wood  (wood_grain)    238,167,102      crate panels, counter tops, benches, oar blade
  WoodMid       #A86238   168, 98, 56    Wood                  187,109, 62      crate frame, barrel, bucket, chest base, stall panels/counters
  WoodDark      #703E26   112, 62, 38    Wood                  124, 69, 42      posts, beams, lids, crank, scarecrow pole, rack
  WoodTrunk     #804E30   128, 78, 48    Wood                  142, 87, 53      forge stump (Plains Trunk)
  RoofRed       #C4403A   196, 64, 58    Wood                  218, 71, 64      well roof shingles (Hub Roof)
  RoofRedDark*  #9C302C   156, 48, 44    Wood                  173, 53, 49      ridge caps, roof shadow side
  -- metal ------------------------------------------------------------------------------------------------
  Iron          #5C626E    92, 98,110    Iron  (metal_iron)    105,111,125      hoops, bands, lantern frames, anvil, crank, minecart
  IronWorn*     #7A808C   122,128,140    Iron                  139,145,159      worn faces, anvil face, blade edges
  Gold          #FFC93C   255,201, 60    Gold  (iron + polished roughness) 255,201,60   chest bands/lock, trophy, guards, sign bar
  Brass*        #C99A2E   201,154, 46    Gold                  228,175, 52      rivets, hinges, worn gold
  -- stone ------------------------------------------------------------------------------------------------
  Stone         #969CA8   150,156,168    Stone (stone_rough)   170,177,191      fountain basin, well stones, lamp foot, forge
  StoneDark     #686E7C   104,110,124    Stone                 118,125,141      rims, steps, capstones, chimney
  StoneMortar*  #545864    84, 88,100    Stone                  95,100,114      mortar joints, dark shaft bottoms
  StonePale     #A3AAB7   163,170,183    Stone                 185,193,208      fountain upper pedestal
  StoneBlue     #7080CC   112,128,204    Stone                 127,145,232      blue rocks (Plains RockBlue)
  CaveRock      #605C6E    96, 92,110    Stone                 109,105,125      ore loads
  -- moss -------------------------------------------------------------------------------------------------
  Moss          #68A848   104,168, 72    Moss  (stone_rough)   118,191, 82      moss on stones (Plains Moss)
  MossDark*     #4A8A3C    74,138, 60    Moss                   84,157, 68      shaded moss
  -- cloth ------------------------------------------------------------------------------------------------
  ClothRed      #D4343C   212, 52, 60    Cloth (cloth_canvas)  236, 58, 67      weapon stall stripes (Hub Banner)
  ClothCream    #E8E2D0   232,226,208    Cloth                 255,248,229      cream stripes (weapon / trophy stall)
  ClothWhite    #F5F6FA   245,246,250    Cloth                 250,251,255      white stripes (diamond shop)
  ClothGreen    #287C3A    40,124, 58    Cloth                  44,138, 64      trophy stall stripes
  ClothBlue     #4078D4    64,120,212    Cloth                  71,133,236      diamond shop stripes (Hub RoofBlue)
  ClothBlueAlt  #4A6CDC    74,108,220    Cloth                  82,120,244      scarecrow shirt, cushions, shield (Hub BannerAlt)
  ClothOrange   #D6965C   214,150, 92    Cloth                 238,167,102      laundry cloth (light hide)
  ClothTan      #C4A068   196,160,104    Cloth                 218,178,116      laundry cloth (tan hide)
  -- straw / rope / bone ------------------------------------------------------------------------------------
  Straw         #ECC860   236,200, 96    Straw (straw_woven)   255,216,104      scarecrow hay (LogEnd)
  StrawPale     #F4E2A0   244,226,160    Straw                 255,236,167      scarecrow burlap head, pale straw
  Rope          #C4A068   196,160,104    Rope  (straw_woven)   223,182,118      ropes, nest ring (Common Rope)
  Bone          #F0E8D0   240,232,208    Bone  (bone_ivory)    252,244,219      bones, skulls (Desert Bone)
  BoneAged*     #D9CDA8   217,205,168    Bone                  228,215,176      yellowed ends, cracks
  BoneSocket    #3E3C4E    62, 60, 78    Bone                   65, 63, 82      eye sockets (CaveRockDark)
  ClamPink      #FF5C78   255, 92,120    Bone                  255, 92,120      clam shell (Plains Flower1)
  -- untextured (no ColorMap: tint = hex) --------------------------------------------------------------------
  Water         #34D6EC    52,214,236    Water (Glass, T 0.35)                  fountain / well water (Hub Water)
  Lantern       #FFD678   255,214,120    Glow (Neon)                            lantern glass, flames
  Fire          #FF8C28   255,140, 40    Glow                                   forge embers
  Diamond       #5FD4FF    95,212,255    Glow                                   diamond sign, cyan gems, fountain crystal
  OreGold       #FFC43C   255,196, 60    Glow                                   minecart crystals, yellow gem
  Pearl         #F5F6FA   245,246,250    Plain / Bone                           pearl, eggs
  The values live in fyd_props.py (PALETTE); a recipe names a palette key or gives a hex.

=================================================================
3. BEVEL
=================================================================
- ONE ratio: bevel width = 2.5 % of the prop's smallest overall dimension (the current Studio bounding box;
  the well 9.6 deep -> 0.24 studs), clamped per piece to 25 % of that piece's own smallest dimension (thin planks
  keep a visible but small chamfer), skipped below 0.02 studs. One segment (a chamfer): it catches the light and
  costs little. Beams and posts bevel only their long edges ("long"); stones bevel their outer face edges; small
  pieces (shingles, staves, rafters, nails) are not bevelled.
- Bevel faces get a slightly lighter vertex colour (worn edges).

=================================================================
4. SHARED TILEABLE TEXTURES (textures/, 512 x 512, seamless, uploaded 2026-10-18)
=================================================================
- ONE TILE = 4 x 4 STUDS for every set (MaterialVariant.StudsPerTile = 4; on the meshes 1 UV unit = 4 studs).
- ColorMaps are near-white NEUTRAL GRAYSCALE (mean about 0.9, detail darker than white) so they can be tinted per
  part. Normal maps: OpenGL tangent space (green = +V, the only format Roblox reads). Roughness / Metalness: gray.
- textures.json holds the file list, each ColorMap mean (used for the tint), and the asset ids below.
- Contact sheet: Previews/Props/textures_sheet.png (each set tinted with a family colour, 2 x 2 tiles).

  Set (family)                     ColorMap            NormalMap           RoughnessMap        MetalnessMap        mean
  wood_grain (Wood)                89740758642776      108234637428586     135239950193027     -                   0.900
  wood_planks (Planks: 1-stud boards, seams, butt joints, nails)
                                   116360752066242     75585161149742      78473445851411      -                   0.965
  metal_iron (Iron; Gold uses its Color/Normal/Metalness + metal_polished_roughness 76471974811432)
                                   135731262793033     95603986153332      131380756886210     111789210470609     0.880
  metal_riveted (Riveted: 2-stud plates, rivet rows, rust streaks running down -V)
                                   136831119633013     73927252058016      106383785359918     129055189097432     0.904
  stone_rough (Stone, Moss: natural / rough-cut stone surface)
                                   113595820216745     118192687069902     131523483608455     -                   0.880
  stone_blocks (StoneBlocks: cut-stone courses of 1 stud, blocks 1.5-2.5 studs, recessed mortar)
                                   112829619167917     80658067793442      104665814749700     -                   0.909
  cloth_canvas (Cloth: plain weave)
                                   112531479292946     135306887519638     107308943025432     -                   0.900
  straw_woven (Straw, Rope: woven strips 1/8 stud)
                                   90752857691370      73615548184266      81926772986745      -                   0.880
  bone_ivory (Bone: pores, hairline cracks)
                                   129326962762155     123401090557220     116742375558344     -                   0.952
  water_ripple (overlay)           130488259194169 (RGBA: white caustic lines, alpha 0-0.6) - a Texture on the Top face of
                                   a water part, StudsPerTileU/V = 4, scrolled by PropFX (ripples); not a SurfaceAppearance
  (all ids are rbxassetid://<id>, uploaded with the Studio MCP upload_image to the owner's account)

- In Studio (Agent B): one MaterialVariant per family for Studio-built Parts, StudsPerTile 4:
    FYD_Wood (BaseMaterial Wood), FYD_Planks (WoodPlanks), FYD_Iron (Metal), FYD_Gold (Metal), FYD_Riveted (Metal),
    FYD_Stone (Slate), FYD_StoneBlocks (Cobblestone), FYD_Moss (Grass, stone_rough maps), FYD_Cloth (Fabric),
    FYD_Straw (Fabric; also used by Rope), FYD_Bone (SmoothPlastic). BasePart.Color = the tint column.
  and one SurfaceAppearance per family for imported MeshParts (same maps), cloned per MeshPart with
    SurfaceAppearance.Color = the mesh's tint (PropMeshData "Color"); AlphaMode Overlay (the maps have no alpha).
- Regenerate: blender -b --factory-startup --python tools/blender/fyd_props_textures.py (deterministic seeds; it
  keeps the asset ids in textures.json - re-upload and replace an id only when that map really changes).

=================================================================
5. AXES / SCALE / PIVOT (adapted from Blender/Weapons/README.txt and the creatures)
=================================================================
- Recipes are written in ROBLOX MODEL SPACE in STUDS: x right, y up, z back. The prop FACES -Z (Roblox
  LookVector) = the side a player normally sees (stall counters, the well's front slope, the chest's lock).
- ORIGIN = the prop's pivot at GROUND CONTACT: the current Studio pivot projected to the ground (bottom centre
  for the kit props). "PivotY" in the data = height of the Studio pivot above that point (0 for the kit props).
- The pipeline converts to Blender (X = -x, Y = z, Z = y; the prop faces Blender -Y) and to METRES
  (1 stud = 0.28 m): the .blend files are real scale.
- FBX export: Y up, -Z forward (Blender defaults, like the weapons/creatures: Roblox X = -Blender X,
  Y = Blender Z, Z = Blender Y), no animation, NO textures, global scale 1/28 so THE FBX NUMBERS ARE STUDS
  (Blender writes centimetres; Studio's "Studio Default" import preset reads raw FBX numbers as studs - the weapon
  lesson of 2026-10-13, 28x too big). Checked by fyd_props_check.py (raw size == studs for every mesh).
- Transforms applied (rotation 0, scale 1). Object origin = the mesh's pivot: the prop origin, or the hinge of a
  piece that moves (clam lid, sign): "Pivot" in the data.

=================================================================
6. UVs AND VERTEX COLOURS
=================================================================
- WORLD-SCALE UVs: 1 UV unit = 4 studs = one texture tile, so every texture tiles at the same density on every
  prop. Box projection per face in each piece's own frame with the grain along the piece's long axis (planks,
  posts, staves), cylindrical on round pieces, along the length on ropes/tubes; a random offset per piece.
  Islands overlap modulo 1 on purpose (tiling); there is no unique per-prop map. UVs go outside 0..1
  (ASSUMPTION to confirm on the pilot import: SurfaceAppearance textures wrap/repeat).
- Vertex colours: attribute "Col" (byte, corner, sRGB), grayscale multipliers 0.7-1.0: per-piece tone, lighter
  bevels, darker ground contact and down-facing faces. Roblox imports FBX vertex colours (3D Importer, object
  setting "Ignore Vertex Colors" off by default) and the Roblox Blender guide shows vertex paint combined with a
  SurfaceAppearance; not yet verified in THIS place, so they carry only subtle variation. Every important colour
  change (stripes, gold bands, red roof vs dark posts, darker rim) is a SEPARATE MESH with its own tint.

=================================================================
7. NAMING CONTRACT (what tools/ApplyPropMeshes.luau relies on)
=================================================================
- One FBX per prop: Blender_Exports/Props/<propId>.fbx -> Studio imports it as a Model named <propId>.
- Render meshes: <propId>_<Part> (Part = PascalCase, unique in the prop), one per material family + tint, e.g.
  well_Stones, well_RimStones, well_Timber, well_Roof. Role suffixes:
    <propId>_<Part>_Glow     emissive: Material Neon, Color = its colour, no SurfaceAppearance, CastShadow false
    <propId>_<Part>_Water    water: Transparency 0.35 (Glass / SmoothPlastic), no SA, optional water_ripple Texture
    <propId>_<Part>_Glass    glass panes: Transparency 0.3
  (a part already named after its role is not suffixed twice: well_Water)
- Mesh colliders (convex shapes only): <propId>_Collider or <propId>_Collider_<Name> -> Transparency 1,
  CanCollide true, CollisionFidelity Hull, CastShadow false, CanQuery true, no SA. Simple colliders are DATA
  (Colliders list: Name, Shape Block | Cylinder | Wedge, Center, Size, Rotation in degrees; Roblox Part
  conventions: a Cylinder's axis is its X, rotation (0, 0, 90) stands it up) -> invisible anchored Parts.
- The family / tint / material of each mesh are NOT parsed from names: they are in
  Blender_Exports/Props/PropMeshData.luau (generated; paste it into ServerStorage.DevTools.PropMeshData):
    Textures[set] = { ColorMap, NormalMap, RoughnessMap, MetalnessMap, ColorMean }
    Families[family] = { Set, Material, Variant, Role, Metal, Transparency, Overlay, RoughnessMap (Gold) }
    Props[propId] = { Fbx, Triangles, Budget, PivotY, Bounds {Center, Size, Min, Max}, StudioSize,
                      Meshes[name] = { Family, Role, Color {r,g,b} (tint), Target "#hex", Material, Variant,
                                       Transparency, CastShadow, Center, Size, Pivot, Triangles, Overlay },
                      Colliders = { ... }, Attachments[name] = {x, y, z} }
  All positions: studs, prop space, relative to the origin (ground contact under the pivot).
- What ApplyPropMeshes must do per mesh (whatever the importer did): find the MeshPart by name; check its Size
  against "Size" (if it is ~28x / 100x / 0.036x off, the import unit was wrong: resize to "Size"); place it at
  template pivot * CFrame.new(Center) (identity rotation); PivotOffset = CFrame.new(Pivot - Center); Anchored,
  CanCollide false, CanTouch false, CanQuery false, CollisionFidelity Box, CastShadow from the data; replace any
  imported SurfaceAppearance by the family's shared one with SA.Color = Color; Material = Material. Template =
  Model <propId> with an invisible Root Part (Bounds) as PrimaryPart and WorldPivot at (0, PivotY, 0); the
  Attachments go under Root.

=================================================================
8. BUDGETS AND FILES PER PROP (brief section 5)
=================================================================
- Triangles: small props 300-1,500 | medium 1,500-4,000 | large (fountain, stalls, well, forge) up to 8,000;
  per-model targets of section 9 (well 3,500, chest 1,500, clam 800, ...) win. <= 4 texture families per model
  (+ untextured Water / Glow / Glass). Studio-built props: <= 40 parts (stall frames <= 80).
- Files of one prop:
    Blender/Props/<propId>.blend               source of truth (scene with the meshes, preview materials, the
                                               preview rig; textures referenced relatively from textures/)
    Blender_Exports/Props/<propId>.fbx         for the owner's import (Blender_Exports/Props/PROPS_IMPORT.md)
    Blender_Exports/Props/<propId>.json        the prop's data (merged into PropMeshData.luau)
    Previews/Props/<propId>_before_after.png   reference photo | render from the photo's angle | other side
    Previews/Props/<Batch>_lineup.png          the batch side by side at real relative scale
    Blender/Props/props_manifest.csv           propId, photo, tool, triangles/parts, budget, status, instances
                                               updated, notes (the pipeline updates its own columns only)
- Triangulated (no n-gons), closed or culled-safe meshes: Roblox MeshParts are single-sided, so a face may only be
  removed where nothing can see its back (shingle undersides on the board, stone bottoms on the ground).

=================================================================
9. COLLISION (brief section 6)
=================================================================
- Render meshes never collide (CanCollide false). Collision = simple invisible Parts (data Colliders) or convex
  <propId>_Collider meshes (Hull); never the render mesh, never PreciseConvexDecomposition on big meshes.
- Solid stays solid, walk-through stays walk-through, nobody climbs into the fountain or the well if they could
  not before (Agent B compares with today's colliders).

=================================================================
10. PER PROP CHECKLIST
=================================================================
 [ ] recipe sizes from docs/prop_inventory.md      [ ] bbox <= +10 %, same pivot / front / ground contact
 [ ] main colours = palette (tint in the data)      [ ] triangles within budget, <= 4 texture families
 [ ] previews looked at (before/after + close-ups)  [ ] fyd_props_check.py: no problems
 [ ] .blend + FBX + JSON + PropMeshData.luau        [ ] manifest row
 [ ] colliders / attachments for PropFX in the data

=================================================================
11. PREVIEW IMAGES (Studio preview channel, before the owner's import)
=================================================================
Studio cannot read our files, so each Blender prop is also encoded into a PNG, uploaded with upload_image, read
back by Agent B with EditableImage and rebuilt with EditableMesh as a TEMPORARY preview (never saved). It shows
scale, UV tiling, vertex colours and the shared SurfaceAppearances in Studio before any import.
- Written by fyd_props.make() at every build, or from a saved .blend:
      blender -b --factory-startup --python tools/blender/fyd_props_run.py -- --preview-png well chest
  -> Blender_Exports/Props/preview/<propId>_mesh.png (the runner decodes it back and compares: round trip).
- FORMAT (exact; Agent B's decoder relies on it):
  * PNG, RGBA 8-bit, width 1024, height = as many rows as needed (<= 1024). Alpha = 255 on every pixel. The
    payload is in R, G, B only (3 bytes per pixel), row-major from the TOP-LEFT pixel, padded with zeros.
  * Bytes 0-3 ASCII "FYDM"; bytes 4-7 JSON byte length (uint32 little-endian); bytes 8-11 Adler-32 of the JSON
    bytes (uint32 little-endian); bytes 12.. the UTF-8 JSON (compact, no spaces).
  * JSON = {"prop":"well","version":1,"meshes":[{"name":"well_Stones","v":[x,y,z,...],"n":[nx,ny,nz,...],
    "uv":[u,v,...],"c":[r,g,b,...],"t":[i0,i1,i2,...]}, ...]}
      v  = positions in STUDS, Roblox prop space (x right, y up, front -Z, origin = ground contact under the pivot),
           i.e. where the imported MeshPart's vertices end up once placed; 4 decimals.
      n  = per-vertex normals (unit, 3 decimals): flat faces carry their face normal, round sides smooth normals.
      uv = per-vertex, ROBLOX convention (v = 0 at the TOP of the image = 1 - Blender v), 4 decimals; world-scale
           (1 UV unit = 4 studs), so values go outside 0..1 on purpose (tiling).
      c  = per-vertex colour 0..255 (the exported vertex colours "Col", sRGB; 255,255,255 when none).
      t  = zero-based triangle indices, COUNTER-CLOCKWISE seen from the front (EditableMesh's front-face rule;
           the Blender -> Roblox axis change is a proper rotation, so Blender's CCW order is kept). Checked: every
           triangle's CCW normal agrees with its vertex normals.
      Every render mesh of the FBX is included (same names), colliders excluded; vertices are split wherever the
      normal, UV or colour differs (a corner = one vertex).
  * More than one image only if a prop does not fit 1024 x 1024 x 3 bytes: <propId>_mesh_1.png, _2.png, ... each
    with the same header and complete meshes.
- Uploaded ids (also in Blender_Exports/Props/preview/preview_ids.json):
    propId          asset id(s)                         size        meshes / vertices / triangles
    well            rbxassetid://80102529524931         1024 x 163  10 / 7,108 / 3,106

=================================================================
12. PROPS DONE
=================================================================
- well (pilot, 2026-10-18): 3,106 tris / 10 meshes (Stones, RimStones, Mortar, Moss, Water, Timber, Roof, Bucket,
  Iron, Rope), bbox 12.29 x 13.25 x 9.52 (today 11.40 x 13.20 x 9.60: x1.08 / x1.00 / x0.99). 3 courses of 12
  irregular stones in a running bond over a dark mortar core, 10 darker capstones (gaps where the posts rise),
  moss cushions at the foot; water 0.4 below the capstones; posts 0.88 square on footing stones just outside the
  ring (x +-4.75, today +-4.2 inside the wall), tie beams, king posts, rafters, ridge beam, bargeboards; boarded
  gable roof with 4 rows of red shingles per side and a ridge cap; winch: axle through iron bearing plates, drum
  with 5 rope coils, iron crank + wooden grip at +X (as today); bucket of 10 flared staves, 2 iron hoops, iron
  bail, rope. Colliders = today's solids (wall, rim, roof wedges, bucket) with the posts and axle where they are
  now. Attachments WaterSurface (0, 3.45, 0), BucketBottom, WinchAxis (0, 8, 0).
