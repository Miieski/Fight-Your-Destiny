# Prop FBX files to import (model upgrade: hub and world props)

Made by `tools/blender/fyd_props.py` (conventions: `Blender/Props/README.txt`, the Prop Style Guide). Until a prop is
imported, the current model stays in place, so nothing is blocked. Studio-built props (crate, barrel, lamp post,
lantern, laundry rack, stall frames) need no import.

What is in each file (designed around the weapon import of 2026-10-13):
- **One mesh per material family / colour / glowing part**, named `<propId>_<Part>` (`_Glow`, `_Water`, `_Glass`
  suffixes), so the importer cannot merge them into one textured part as long as **Merge Meshes stays OFF**.
- **Written in studs**: the "Studio Default" preset (Scale Unit = Studs) brings the well in at about 12.3 x 13.2 x
  9.5 studs. Nothing to change (the weapons came in 28x too big because their files were in metres/centimetres).
- **No textures inside**: the shared textures are already uploaded; the apply command puts them on every mesh
  with the right colour. No texture upload happens during the import.

## How to import (owner)

1. In Studio: **File > Import 3D** (the same importer as Asset Manager > Bulk Import; this is the route that worked
   for the 84 weapons).
2. In the file browser, open the folder `Blender_Exports\Props\` of the project, select the `.fbx` files of the table
   below (Ctrl+click, or Ctrl+A when they are the only FBX files) and click **Open**. They go into the **Import Queue**.
3. Settings: keep the preset **Studio Default** for every file (right-click a file > *Apply settings to all*).
   Check that these are as follows (they are the defaults):
   - File General: **Import Only As Model = ON**, Add Model To Inventory = ON, **Insert In Workspace = ON**,
     Insert Using Scene Position = OFF, Set Pivot to Scene Origin = ON. (Anchored = ON is welcome but optional.)
   - File Transform: World Forward = **Front**, World Up = **Top** (do not rotate anything).
   - File Geometry: **Scale Unit = Studs**, **Merge Meshes = OFF** (important), Invert Negative Faces = OFF.
   - Objects (if you open one): Use Imported Pivot = ON, **Ignore Vertex Colors = OFF**, Make Double Sided = OFF.
   - Size check in the preview: the well is about 12.3 wide, 13.2 high, 9.5 deep.
4. Click **Import** (all boxes ticked) and wait until the models are in the Workspace. Each Model is named after its
   file (`well`, ...) and holds one MeshPart per mesh of the table.
5. Optional: put them in a folder `workspace.ImportedProps` (the command also finds them anywhere in the Workspace by
   name).
6. Tell Claude, or run in the command bar the single command:

   `print(require(game.ServerStorage.DevTools.ApplyPropMeshes:Clone()).run())`

   (`ServerStorage.DevTools.PropMeshData` must hold the latest `Blender_Exports/Props/PropMeshData.luau`; Claude keeps it
   up to date.)

   For every imported prop it builds `ServerStorage.MapProps.<propId>` (shared textures and colours, glow, water,
   invisible colliders, effect points), then updates the test area and every copy in the map, and prints a report.
   If a scale setting was changed by mistake, nothing is lost: each mesh is resized to its size in the data.
7. Look at the test area and the hub, delete the imported models from the Workspace (the templates keep their own
   copies), and save the place (File > Save to File As).

## Files

| File | Prop | Meshes | Triangles | Size (studs, x y z) | Goes to |
|---|---|---|---|---|---|
| `Blender_Exports/Props/well.fbx` | well (photo 16) | 10: well_Stones, well_RimStones, well_Mortar, well_Moss, well_Water, well_Timber, well_Roof, well_Bucket, well_Iron, well_Rope | 3,106 | 12.29 x 13.25 x 9.52 | ServerStorage.MapProps.well -> Hub.Decor.Village.Well_A and the test area Lineup.Hub.Well_A |

Data for the apply command (paste into `ServerStorage.DevTools.PropMeshData`, ModuleScript):
`Blender_Exports/Props/PropMeshData.luau` (generated: texture ids, families, and per prop every mesh's family, colour,
position, size, pivot, colliders and effect points).
