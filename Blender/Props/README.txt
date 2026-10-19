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
  Builds are DETERMINISTIC since 2026-10-19 (same recipe -> same meshes, same preview PNG bytes; only the FBX
  timestamp changes). Props built before that fix (well ... trophy_stall) keep their files and uploads, which match;
  rebuilding one of them gives slightly different random jitter (same look): re-upload its preview PNG then.

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
measured on every model by Agent B. The reference photos ("REMAKE OBJECT/Model_References/Model_References/" at the
project root, 01_fountain.png ... 20_diamond_shop.png) were sampled too (median of lit
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
  ClamPink      #FF5C78   255, 92,120    Plain (no texture)    255, 92,120      clam shells, outside (Plains Flower1)
  ClamInner*    #FF8AA3   255,138,163    Plain (no texture)    255,138,163      clam insides (warm light pink; ClamCream
                                                                                 #F7B8B8 was too pale, 2026-10-19)
  -- untextured (no ColorMap: tint = hex) --------------------------------------------------------------------
  Water         #34D6EC    52,214,236    Water (Glass, T 0.35)                  fountain / well water (Hub Water)
  Lantern       #FFD678   255,214,120    Glow (Neon)                            lantern glass, flames
  Fire          #FF8C28   255,140, 40    Glow                                   forge embers
  Diamond       #5FD4FF    95,212,255    Glow                                   diamond sign, cyan gems, fountain crystal
  OreGold       #FFC43C   255,196, 60    Glow                                   minecart crystals, yellow gem
  Pearl         #F5F6FA   245,246,250    Plain / Bone                           pearl, eggs
  Flame*        #FFB648   255,182, 72    Glow (Neon)                            lantern / lamp flames ("Flame" part)
  Thread*       #3A2A20    58, 42, 32    Plain                                  stitches (scarecrow mouth)
  ButtonDark*   #2E2B33    46, 43, 51    Plain                                  button eyes
  Speckle*      #9C8A70   156,138,112    Plain                                  egg speckles
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
  water_ripple (overlay)           85261602329011 (v2, 2026-10-19; v1 130488259194169 showed faint square tiling at grazing
                                   angles) (RGBA: white caustic lines, alpha 0-0.6) - a Texture on the Top face of
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
    <propId>_<Part>_Stream   falling water (fountain): Transparency 0.45, Glass / SmoothPlastic, no SA, optional ripple
    <propId>_<Part>_Foam     foam rings: ClothWhite, Transparency 0.2, SmoothPlastic, no SA
  (a part already named after its role is not suffixed twice: well_Water)
- Mesh colliders (convex shapes only): <propId>_Collider or <propId>_Collider_<Name> -> Transparency 1,
  CanCollide true, CollisionFidelity Hull, CastShadow false, CanQuery true, no SA. Simple colliders are DATA
  (Colliders list: Name, Shape Block | Cylinder | Wedge | Ball, Center, Size, Rotation in degrees; Roblox Part
  conventions: a Cylinder's axis is its X, rotation (0, 0, 90) stands it up; Rotation is a Roblox Orientation;
  Ball = Part.Shape Ball) -> invisible anchored Parts. A collider mesh is in the FBX AND in the data (Role
  "Collider"); it is never in the preview PNG (first one: egg_nest_Collider_Rock, the rock's convex hull).
- Moving meshes carry their hinge / sway point as "Pivot" (also an attachment of the same name in the data):
  clam_pearl_ShellTop + ShellTopInner (Hinge, X axis), scarecrow_Hat + HatBand (HatPivot), scarecrow_Straw*
  (StrawWristL / StrawWristR / StrawCollar / StrawHem). Rotate them around Pivot; the other meshes stay put.
- PLACEMENT (prop level, optional): {Host, OriginInHost, RotationInHost, Replaces, Keep, Note}. anvil_forge is a
  sub-model of the weapon stall: OriginInHost = stall-space (10.85, 0, 1.9). The 3 stalls: origin = the stall pivot
  (floor centre), the FBX holds only the Blender pieces (frames are Studio-built by Agent B).
- REPLACES (per mesh): the current Studio part(s) the mesh takes over (names, or {What, Count, Size, At} for unnamed
  parts such as the awning stripes / fringe blocks); "(with the blade)" etc. = same group as the mesh before it.
- ANCHOR (per mesh, stall pieces whose position is not in the inventory): {Part, Pick "nearest", AssumedPosition,
  AssumedRotation (Roblox Orientation, deg), PartSize}. The mesh is modelled (and shown in the FBX / preview PNG)
  where that part is ASSUMED to be. ApplyPropMeshes finds the real part named Part (the copy nearest to
  AssumedPosition, in the host stall) and re-bases, all CFrames in world space:
      assumed = stallPivot * CFrame.new(AssumedPosition) * CFrame.Angles(rad(rx), rad(ry), rad(rz))
      MeshPart.CFrame = realPart.CFrame * assumed:Inverse() * (stallPivot * CFrame.new(Center))
  (the rotations used here are single-axis, so Orientation and CFrame.Angles agree).
  All meshes of one item share the same anchor (e.g. Sword1Blade / Sword1Gold / Sword1Grip -> one SwordBlade), so
  the item moves as a whole. Without an anchor a mesh is placed at stallPivot * CFrame.new(Center).
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
    chest           rbxassetid://91198421411858         1024 x 45   5 / 2,116 / 1,170
    rowboat         rbxassetid://76458477611449         1024 x 93   7 / 4,038 / 1,660
    minecart        rbxassetid://87079386271654         1024 x 78   6 / 3,496 / 1,736
    skull_bones     rbxassetid://86179103526619         1024 x 80   3 / 3,476 / 1,254
    clam_pearl      rbxassetid://122490022754803        1024 x 36   5 / 1,580 / 572
    egg_nest        rbxassetid://85105593530507         1024 x 73   9 / 3,167 / 1,245
    scarecrow       rbxassetid://119496532966562        1024 x 101  13 / 4,442 / 1,848
    fountain        rbxassetid://114916914245834        1024 x 253  12 / 11,023 / 5,018
    anvil_forge     rbxassetid://79286061632425         1024 x 98   12 / 4,434 / 1,950
    weapon_stall    rbxassetid://85117045354573         1024 x 139  21 / 6,239 / 2,672
    trophy_stall    rbxassetid://127684037913768        1024 x 126  6 / 5,592 / 2,246
    diamond_shop    rbxassetid://95984830780590         1024 x 146  10 / 6,512 / 2,776

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
BATCH 2 (2026-10-19; lineup Previews/Props/Batch2_lineup.png; sizes x y z vs today):
- chest: 1,170 tris / 5 meshes (Body WoodMid, Lid WoodDark, Bands Gold, Iron, Keyhole Plain dark); 4.50 x 3.53 x 3.04
  (today 4.40 x 3.48 x 3.07, placed copies 4.5 wide). 3 bevelled planks per wall, a lid of 7 staves + half-disc ends,
  gold bands sitting on the lid facets, riveted front straps, lock plate with keyhole and hasp, iron corner plates,
  2 back hinges; hidden dark fill inside (no light through the plank gaps). Colliders Base (Block) + Lid (Cylinder)
  as today. Attachments Sparkle (lock, 0, 1.72, -1.52), LidTop.
- rowboat: 1,644 tris / 7 meshes (Hull WoodMid, Timber WoodDark, Thwarts WoodLight, Iron, Rope = the boat;
  Oar WoodDark + OarBlade WoodLight = the second object); 13.39 x 4.67 x 10.07 (today 14.10 x 4.98 x 11.14).
  Clinker hull (4 overlapping strakes per side), flat bottom boards, transom, keel and stem, 4 ribs, gunwales,
  3 thwarts, 2 oarlocks, a rope coil, a broken gap in the near (-Z) side (the wreck), the loose plank behind;
  rolled 22 deg toward -Z, resting on its bilge; the oar lies on the -Z side, blade toward the bow (+X). LAYOUT
  REBUILT from the bbox + photo 05 (no per-part CFrames in the inventory): compare with the old model in Studio.
  Colliders Hull (Block, rotation (-22, 0, 0)) + Oar (Cylinder).
- minecart: 1,736 tris / 6 meshes (Body Riveted Iron, Frame IronWorn, Running Iron, Hubs WoodDark, Ore CaveRock,
  Crystals_Glow OreGold); 4.90 x 6.60 x 7.04 (today 5.12 x 6.24 x 6.61). Flared riveted box, rim, 2 bands, corner
  posts, flanged iron wheels with wooden hubs at today's centres (+-1.6, 0.75, +-1.8) so they still sit on the
  rails, axles, bearings, coupler at -Z, rubble load with 4 crystals (2 big as today). Colliders Body + Wheels
  (Blocks). Attachments CrystalGlow (0, 5.7, 0), Coupler.
- skull_bones: 1,254 tris / 3 meshes (Bones Bone, Aged BoneAged: knobs / jaw / teeth, Sockets BoneSocket);
  6.44 x 2.93 x 6.00 (today 6.44 x 2.88 x 5.76). Faceted cranium, brow arcs, cheekbones, tapered maxilla, dark
  sockets and nasal cavity, upper / lower teeth, U-shaped jaw; 3 long bones with knobbly condyles (2 crossed under
  the skull, 1 behind), 5 curved ribs at the front on -X leaning 16-40 deg. LAYOUT REBUILT from bbox + photo 07.
  Collider Skull (Ball 2.4, as today's ball). Recoloured copies (Abyss_3): set SA.Color per instance.
- clam_pearl: 572 tris / 5 meshes (ShellBottom + ShellTop ClamPink outer / rims, ShellBottomInner + ShellTopInner
  ClamCream #F7B8B8 insides, Pearl Plain); 2.73 x 2.21 x 2.68 (today 2.60 x 2.20 x 2.83). Fan-ribbed scallop valves
  (7 ribs, scalloped edge, hinge "ears"), hinge pin at the back, top valve open 42 deg as today. Decor only: no
  collider, no shadow. Animated: ShellTop + ShellTopInner around Hinge (0, 0.38, 1.25), X axis, about 12 deg;
  PearlGlint (0, 0.92, 0.2).
- egg_nest: 1,091 tris / 9 meshes (Rock Stone, Cracks StoneMortar, Moss, NestRing Straw/Rope, Twigs WoodMid, Lining
  Straw/WoodDark, Eggs Bone/Pearl x2, EggCream Bone/ClothCream, Speckles Plain #9C8A70) + collider mesh
  egg_nest_Collider_Rock (20 tris, Hull); 12.02 x 10.93 x 9.91 (today 12.29 x 10.95 x 12.29). Faceted rock with a flat
  ledge at y 9.05, 2 side boulders, cracks traced on the facets, moss cushions lying on the facets; woven ring,
  14 twigs, brown lining, 3 eggs of slightly different size / tilt / tint with speckles. The old rock was a Toolbox
  mesh (attributes SourceAssetId / SourceCreator): the new rock is ours. Colliders Rock (mesh, Hull) + Nest
  (Cylinder as today). Attachment Sparkle (0, 10.9, 0).
- scarecrow: 1,848 tris / 13 meshes (Post WoodDark, Shirt ClothBlueAlt, Patches ClothTan, Head StrawPale burlap,
  Buttons dark, Stitches Thread, Rope, Hat Straw/WoodMid, HatBand Cloth/WoodDark, StrawWristL / WristR / Collar /
  Hem Straw); 7.64 x 9.39 x 3.72 (today 8.00 x 9.45 x 3.60). Rough post and crossbar, elliptical shirt with drooping
  sleeves, folds and 2 patches, rope belt with knot, wrist and neck ties, sack head with button eyes and an
  X-stitched smile, wavy-brimmed straw hat with a band tilted 6 deg like today, straw cores at the wrists, a ruff
  at the collar, a straw band + long straws at the hem. Colliders Post, Arms, Shirt (Blocks) + Head (Ball) as
  today. Sway: Hat + HatBand around HatPivot (0, 8, 0), each Straw mesh around its own pivot.
FIXES AFTER AGENT B'S STUDIO PREVIEW (2026-10-19):
- rowboat (1,676 tris, 14.09 x 4.95 x 10.41): hull 13.7 long and 0.3 taller, its bbox placed like today's (x -5.61 ..
  8.47, centre z -0.64, top 4.89; today -5.62 .. 8.48 / -0.64 / 4.98); clinker laps 0.1 per strake + alternating strake
  tones (read from +Z too); the OAR now LEANS against the hull: grip end on the low (-Z) gunwale (y about 3.2), blade
  tip on the ground at (5.1, 0.08, -4.55), so only the tip comes near sloped ground; oar x -3.59 .. 5.11 inside today's
  -4.03 .. 5.26. Oar collider = a Cylinder along the shaft (Rotation is a Roblox Orientation: 70.97, -80.49, -90).
  (Oar moved again in FIXES 2: tip (2.75, 0.08, -4.6).)
- clam_pearl (572 tris): shells now Plain (SmoothPlastic like today) ClamPink #FF5C78 outside, ClamInner #FF8AA3
  (warm light pink) inside, vertex-colour gradient darker at the hinge; rest pose 34 deg (today 42).
- egg_nest (1,245 tris + 100-tri collider): rock centre raised to y 4.91 with a flat ledge stone (r 2.95, top 9.05) set
  into its top; ring, lining, eggs and twigs sunk 0.12 (ring bottom 8.95, 0.1 into the ledge all round) + a skirt of
  10 twigs; egg_nest_Collider_Rock = the true convex hull of the rock + both boulders (52 vertices, every rock vertex
  inside, top 9.05, x -5.65 .. 6.37, z -4.77 .. 5.14), CollisionFidelity Hull; nest collider centre y 9.48.
BATCH 3 (2026-10-19; lineup Previews/Props/Batch3_lineup.png):
- fountain: 5,018 tris / 12 meshes (DarkStone StoneDark: step slabs, coping, carved bands, upper bowl, spout lips;
  Wall StoneBlocks/Stone; Pedestal Stone; Column StonePale; Wet StoneMortar: wet bands + basin floor; Moss; Gold collar;
  Crystal_Glow Diamond; LowerWater + UpperWater (Water, T 0.35); Stream (new role Stream, T 0.45: the 6 falling
  streams); Foam (new role Foam, ClothWhite, T 0.2: rings where the streams land + round the spout)); 30.70 x 22.36 x
  30.21 (today 30.00 x 22.30 x 30.00). Three tiers kept: 16 step slabs, cut-stone wall, 16 chipped coping stones,
  wet band at the waterline, carved pedestal (3 bands), pale column flaring into an irregular-rimmed upper bowl with
  6 carved lips, spout column, gold collar, hexagonal crystal with 2 small ones (replaces TopCrystal: move its
  WaterPoint attachment + PointLight to the Crystal_Glow mesh / the WaterPoint point). Water 0.35 below the rims.
  Colliders = today's 8 full cylinders (Step, Basin, Rim, Pedestal, PedestalTop, UpperBowl, Spout, SpoutRing) + the
  4 SpoutLip blocks (FIXES 2): nobody climbs in more than today. Attachments WaterLower (0, 4.25, 0), WaterUpper
  (0, 12.3, 0), WaterPoint (0, 19.6, 0), Mist1-6 (stream landings), Glint1-3. Keep Hub.Decor.VFX.Water_Ripple
  (separate part).
- anvil_forge: 1,950 tris / 12 meshes (Hearth StoneBlocks/Stone, Upper StoneBlocks/StoneDark: voussoirs, fire-bed
  frame, chimney + cap; Soot + Coal Plain dark; Coals_Glow Fire; Stump WoodTrunk; StumpTop WoodLight rings; Anvil
  Iron (+ tongs, hoops, nozzle); AnvilFace IronWorn; Wood WoodMid (bucket staves, bellows boards); Leather Cloth/
  WoodDark; Water); 5.57 x 9.33 x 9.24 (today's parts 5.30 x 9.00 x 8.80). A SUB-MODEL of the weapon stall: data
  Placement.OriginInHost = stall-space (10.85, 0, 1.9), no rotation; replaces Forge x2, Chimney, Embers, Stump, Anvil
  x3, AnvilHorn (keep the Embers' PointLight + FirePoint: move them to ForgeLight / Fire). Hearth with an arched opening
  (5 voussoirs), stone frame round a coal bed (glowing + dark lumps, where today's Embers are), tapered chimney with cap
  and flue, anvil (feet, waist, body, heel + hardy hole, polished face, horn toward +X as today) on a ridged stump with
  growth rings and roots; extras: tongs, quench bucket with water, bellows on the hearth's -X side. Colliders: today's
  solids (+ bucket). Attachments Fire (FirePoint), ForgeLight, Sparks (anvil face), Smoke (chimney top).
BATCH 4, Blender half (2026-10-19; lineup Previews/Props/Batch4_lineup.png, frames drawn render-only):
- weapon_stall: 2,672 tris / 21 meshes. Awning (8 stripes per the brief: AwningRed ClothRed + AwningCream
  ClothCream; cloth sagging between the back beam and the front posts, drooping overhang, folds, dip along the front
  edge between the posts, scalloped valance) replacing today's 7 stripes + 7 fringe blocks; collider Awning (Block
  15.6 x 0.45 x 11.6 at (0, 9.6, -1.1), rotation (-13, 0, 0) = today's slab; y 9.45 since FIXES 2). Anchored items:
  3 swords (SwordNBlade Iron with a dark fuller, SwordNGold guard + ball quillons + pommel, SwordNGrip leather wrap;
  anchor SwordBlade, assumed x -0.6 / -2.2 / -3.8, y 6.4, z 3.2, tips up),
  ShieldFace (Planks, ClothBlueAlt) + ShieldRim (Iron, rim +
  8 rivets) + ShieldBoss (Gold, both sides) anchored to Shield (assumed (3.6, 6.3, 3.15), rotation (0, 90, 0)),
  AxeHandle + AxeHead (double-bit) both anchored to AxeHandle (FIXES 2) leaning -20 deg, TrayWood + TrayVelvet (Cloth,
  Iron tint = today's grey-blue) + a dagger (DaggerBlade / Gold / Grip) anchored to DisplaySword (the 1.6 x 0.3 x 4.6
  "blue tray", assumed (-3.6, 3.85, -2.9), rotation (0, 90, 0)). Attachment ShieldGlint.
- trophy_stall: 2,246 tris / 6 meshes, no anchors (positions from the inventory). Awning (7 stripes, AwningGreen
  ClothGreen + AwningCream). Gold (cup with 2 handles, knop and foot, plaque, ball stand + 3 claws) + Wood (plinth,
  stand base) replacing the TrophyCup's 3 gold cylinders at (-3.5, 3.7, -2.9); Ball_Glass (#CDEBF5, T 0.3) +
  BallCore_Glow (#B39DFF) at (2.5, 4.85, -2.9) replacing CounterSkull (the brief's crystal ball wins). Attachments
  BallShimmer, TrophyGlint.
- diamond_shop: 2,656 tris / 10 meshes (sign rebuilt in FIXES 2: 2,776 tris). Awning (7 stripes, AwningBlue
  ClothBlue + AwningWhite ClothWhite).
  Diamond_Glow (brilliant cut: crown, table, pavilion, culet; depth squashed to 1.5 like today) + DiamondRim_Glow
  (white girdle) with Pivot = the diamond's centre (0, 17.8, 1.0 assumed) for the float / spin, anchored to
  DiamondGirdle (assumed (0, 18.3, 1.0)), replacing Diamond (block + 4 wedges) + DiamondGirdle; SignGold (bar with
  finials + moulded post) anchored to SignBar (assumed (0, 12.2, 1.0)), replacing SignBar + SignPost. Cushions
  (pillows, ClothBlueAlt) + Tassels (Gold) + GemsCyan_Glow (x -4 / 4) + GemGold_Glow (x 0) + GemRims_Glow (white
  girdles) at today's x -4 / 0 / 4 on the counter (no anchor). Attachments DiamondCenter, SignGlint, GemGlint1-3.
  The "Diamond Shop" BillboardGui stays a Studio child.
FIXES 2 AFTER AGENT B'S STUDIO PREVIEW OF BATCH 3/4 (2026-10-19):
- diamond_shop (2,776 tris, 15.60 x 16.62 x 11.38): the sign is today's size. Diamond_Glow 7.76 x 6.0 x 1.46 + DiamondRim
  _Glow 8.0 x 0.4 x 1.5 = 8.0 x 6.0 x 1.5 overall, y 14.2 .. 20.2 (culet 14.2, girdle 18.22, table 20.2), Pivot = the
  centre (0, 17.2, 3.5) for the spin / float. The real SignBar and DiamondGirdle sit at z 3.5 (Studio check) and the
  girdle part at y ~18.4 (the first build, assumed 18.3, landed 0.10 higher), so the anchors assume DiamondGirdle
  (0, 18.4, 3.5) and SignBar (0, 12.2, 3.5); the meshes are modelled at their final place. SignGold: bar 8.8 + ball
  finials (9.77 overall, today's bar 9.0) at y 12.2, and a post from a foot on the awning (y 10.3, sheared to the
  cloth's pitch) through a sleeve on the bar up to a small cup at 14.3 holding the culet (the diamond floats 0.5 up
  from there and back).
- weapon_stall (2,672 tris): AxeHead anchored to AxeHandle like the handle (the head sits on the handle's top end);
  handle top end 0.04 proud of the head.
- awnings of weapon_stall / trophy_stall / diamond_shop (same cloth): lowered 0.15 (back edge y 10.75, front edge
  8.15). Cloth underside over the post tops (centre of the post / min .. max over the 0.9 square top): back posts
  (top 10.4) +0.04 .. +0.07 (-0.10 .. +0.18 across the top: the cloth is pitched), front posts (top 8.4) +0.39 ..
  +0.45; today's stripes: 0.05 / 0.44. The trophy and diamond awnings hovered the same 0.2 at the back, so they were
  lowered too. Awning collider follows the cloth: centre (0, 9.45, -1.1) (was 9.6), size / rotation unchanged.
- fountain (5,018 tris, 30.06 x 22.33 x 30.10): + 4 Block colliders fountain_Collider_SpoutLip1-4 = today's SpoutLip
  blocks exactly (2 x 1.2 x 1.6 with the 2.0 side TANGENTIAL like the lip mesh, centres (4.525, 11.8, 4.525) /
  (-4.525, 11.8, 4.525) / (-4.525, 11.8, -4.525) / (4.525, 11.8, -4.525), Rotation (0, -135 / 135 / 45 / -45, 0) =
  today's). Moss: 10 pads lying on the step top, bent along the ring (5 in the corner against
  the wall, creeping 0.25 up it, 5 smaller nearer the edge), r 12.89 .. 14.78 (step edge 14.95 .. 15.08), y 0.76 ..
  1.20, about 0.1 proud of the stone; none on the step's outer face or the plaza.
- rowboat (1,660 tris, 14.09 x 4.95 x 10.43): oar re-laid (still leaning on the near gunwale, grip at hull station
  0.18 + 1.05 overhang): blade tip (2.75, 0.08, -4.6), lowest blade point y 0.04 (rests on flat ground: Plains_2,
  test area, Abyss_2; sinks ~0.3 into the hub's sloping sand, accepted), oar 7.63 long, x -4.01 .. 2.76 (today's oar
  -4.03 .. 5.26), z -4.96 .. -2.90. Blade distance (plan) to the clams round the boat: hub (4.87, -5.64) 2.35, hub
  (6.81, 1.56) 7.09, Plains_2 Docks (8.73, -2.92) 6.13 and (-4.33, -10.04) 7.77 (all >= 1.8). Oar collider: Cylinder
  7.631 x 0.34 at (-0.611, 1.698, -3.799), Rotation (64.91, -76.6, -90). Knobs: OAR_TIP / OAR_REST_S / OAR_GRIP in
  fyd_props_recipes.py.

=================================================================
13. NOTES FOR THE STUDIO-BUILT PROPS (Agent B, batch 1) AND PIVOTS
=================================================================
PIVOT (confirmed for every prop of this guide): the data origin (0, 0, 0) = the ground contact point directly
under the current Studio pivot, and PivotY = 0 for all of them, because every kit pivot already sits on the
ground: bottom centre for well, chest, minecart, skull_bones, clam_pearl, egg_nest, scarecrow, fountain; the
kit pivot itself (on the ground, NOT under the bbox centre) for rowboat (bbox centre (1.43, 2.49, 0.37)) and
skull_bones (bbox centre (-0.30, 1.44, 0.46)); the foot of the post for lamp_post. So: template WorldPivot =
CFrame at the origin, and every mesh at pivot * CFrame.new(Center).

LANTERN / LAMP_POST (Studio-built; sizes = today, docs/prop_inventory.md; stay within +10 %)
- lamp_post (Lantern_Post): bbox 3.85 x 9.75 x 1.50 (max 4.24 x 10.7 x 1.65), pivot at the FOOT of the post
  (bbox centre (1.22, 4.88, 0)), the arm reaches +X; the lantern hangs at x 2.4: cap top y 8.35, lantern body
  y 6.55-8.05, base bottom y 6.3. Post (0.8 square, y 0.25-9.75), arm (3.2 long at y 9.2), brace, chain y 8.3-9.0.
- lantern units (no model of their own today):
    ground lantern of TutorialGuide (photo 15) 1.3 x 1.8 x 1.3 (body 1.0 x 1.2 x 1.0, caps 1.3 x 0.3 x 1.3)
    Lantern_Post unit 1.5 x 2.7 x 1.5 with its chain (body 1.2 x 1.5 x 1.2, cap / base 1.5 x 0.3 x 1.5)
    EntryArch unit body 1.2 x 1.5 + cap 1.5 x 0.3 + arm 0.3 x 0.3 x 1.2; EggStation (hanging) 1.6 x 1.8 x 1.6 +
    cap 2.0 x 0.4 + chain 1.6
- Part names for PropFX: the emissive flame is a part named exactly "Flame" (Neon, colour Flame #FFB648
  255,182,72) holding the PointLight (brief: 255,210,140, Brightness 1.2, Range 16, Shadows false; today
  255,214,120 B0.7 R16 on the post, B0.6 R12 on the ground lantern); glass panes "Glass" (Material Glass,
  Transparency 0.3, colour Lantern #FFD678 255,214,120 so the cream glow is kept); frame / caps / ring "Frame".
  (Blender props name their emissive meshes <propId>_<Part>_Glow; after ApplyPropMeshes strips the prefix they
  are "<Part>_Glow": a Blender flame would be "Flame_Glow", so PropFX should accept both.)

TINTS FOR THE STUDIO-BUILT PROPS (BasePart.Color with the FYD_* MaterialVariant = the tint column of section 2)
  crate         body WoodLight 238,167,102 (FYD_Wood or FYD_Planks 222,155,95) | frame, braces WoodMid 187,109,62 |
                nails Iron 105,111,125 (FYD_Iron)
  barrel        staves WoodMid 187,109,62 (FYD_Wood) | top planks WoodDark 124,69,42 | hoops, rivets Iron 105,111,125
  lamp_post     post, arm, brace WoodDark 124,69,42 (FYD_Wood) | stone foot Stone 165,172,185 (FYD_StoneBlocks,
                mean 0.909) or 170,177,191 (FYD_Stone) | bracket, chain, collar Iron 105,111,125 | lantern below
  lantern       frame, caps, ring Iron 105,111,125 (FYD_Iron) | Glass 255,214,120 (no variant, Glass, T 0.3) |
                Flame 255,182,72 (Neon)
  laundry_rack  poles WoodDark 124,69,42 (FYD_Wood) | cloths ClothOrange 238,167,102 (main), ClothTan 218,178,116,
                ClothCream 255,248,229 (FYD_Cloth) | rope Rope 223,182,118 (FYD_Straw) | pins WoodLight 238,167,102
  Untextured parts (Neon / Glass / SmoothPlastic without a variant) take the hex itself, not the tint.
