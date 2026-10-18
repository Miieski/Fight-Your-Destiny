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
   - Size check in the preview: the well is about 12.3 wide, 13.2 high, 9.5 deep (sizes of every file: table below).
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
| `Blender_Exports/Props/chest.fbx` | chest (photo 17) | 5: chest_Body, chest_Lid, chest_Bands, chest_Iron, chest_Keyhole | 1,170 | 4.50 x 3.53 x 3.04 | ServerStorage.MapProps.chest -> Hub Harbor 2, Plains_2 2, Plains_4 1; test Lineup.Common.Chest_A |
| `Blender_Exports/Props/rowboat.fbx` | rowboat (photo 05) | 7: rowboat_Hull, rowboat_Timber, rowboat_Thwarts, rowboat_Iron, rowboat_Rope, rowboat_Oar, rowboat_OarBlade | 1,676 | 14.09 x 4.95 x 10.41 | ServerStorage.MapProps.rowboat -> Hub Harbor 1, Plains_2 1, Abyss_2 4 (recoloured); test Lineup.Plains.Rowboat_Wreck |
| `Blender_Exports/Props/minecart.fbx` | minecart (photo 06) | 6: minecart_Body, minecart_Frame, minecart_Running, minecart_Hubs, minecart_Ore, minecart_Crystals_Glow | 1,736 | 4.90 x 6.60 x 7.04 | ServerStorage.MapProps.minecart -> Plains_4 Mine 2; test Lineup.Plains.Minecart_A |
| `Blender_Exports/Props/skull_bones.fbx` | skull_bones (photo 07) | 3: skull_bones_Bones, skull_bones_Aged, skull_bones_Sockets | 1,254 | 6.44 x 2.93 x 6.00 | ServerStorage.MapProps.skull_bones -> Plains_4 8, Abyss_3 8 (recoloured), BossArenas 12; test Lineup.Plains.Bone_Pile_A |
| `Blender_Exports/Props/clam_pearl.fbx` | clam_pearl (photo 09) | 5: clam_pearl_ShellBottom, clam_pearl_ShellBottomInner, clam_pearl_ShellTop, clam_pearl_ShellTopInner, clam_pearl_Pearl | 572 | 2.73 x 1.96 x 2.68 | ServerStorage.MapProps.clam_pearl -> Hub Beach 8, Plains_2 21; test Lineup.Plains.Shell_A |
| `Blender_Exports/Props/egg_nest.fbx` | egg_nest (photo 04) | 9: egg_nest_Rock, egg_nest_Cracks, egg_nest_Moss, egg_nest_NestRing, egg_nest_Twigs, egg_nest_Lining, egg_nest_Eggs, egg_nest_EggCream, egg_nest_Speckles + collider egg_nest_Collider_Rock | 1,245 | 12.02 x 10.81 x 9.91 | ServerStorage.MapProps.egg_nest -> Plains_2 Rocks 5; test Lineup.Plains.SeagullNest_Rock |
| `Blender_Exports/Props/scarecrow.fbx` | scarecrow (photo 08) | 13: scarecrow_Post, scarecrow_Shirt, scarecrow_Patches, scarecrow_Head, scarecrow_Buttons, scarecrow_Stitches, scarecrow_Rope, scarecrow_Hat, scarecrow_HatBand, scarecrow_StrawWristL, scarecrow_StrawWristR, scarecrow_StrawCollar, scarecrow_StrawHem | 1,848 | 7.64 x 9.39 x 3.72 | ServerStorage.MapProps.scarecrow -> Plains_1 Farm 1; test Lineup.Plains.Scarecrow_A |
| `Blender_Exports/Props/fountain.fbx` | fountain (photo 01) | 12: fountain_DarkStone, fountain_Wall, fountain_Pedestal, fountain_Column, fountain_Wet, fountain_Moss, fountain_Gold, fountain_Crystal_Glow, fountain_LowerWater, fountain_UpperWater, fountain_Stream, fountain_Foam | 5,018 | 30.70 x 22.36 x 30.21 | ServerStorage.MapProps.fountain -> Hub.Decor.Village.Fountain_A; test Lineup.Hub.Fountain_A |
| `Blender_Exports/Props/anvil_forge.fbx` | anvil_forge (photo 13) | 12: anvil_forge_Hearth, anvil_forge_Upper, anvil_forge_Soot, anvil_forge_Coal, anvil_forge_Coals_Glow, anvil_forge_Stump, anvil_forge_StumpTop, anvil_forge_Anvil, anvil_forge_AnvilFace, anvil_forge_Wood, anvil_forge_Leather, anvil_forge_Water | 1,950 | 5.57 x 9.33 x 9.23 | ServerStorage.MapProps.anvil_forge -> a sub-model of Hub.WeaponShop at stall-space (10.85, 0, 1.9), replacing Forge x2, Chimney, Embers, Stump, Anvil x3, AnvilHorn; test Lineup.Hub.Station_WeaponShop |
| `Blender_Exports/Props/weapon_stall.fbx` | weapon_stall (photo 14/19) | 21 (19 anchored): weapon_stall_AwningRed, weapon_stall_AwningCream, weapon_stall_Sword1Blade, weapon_stall_Sword1Gold, weapon_stall_Sword1Grip, weapon_stall_Sword2Blade, weapon_stall_Sword2Gold, weapon_stall_Sword2Grip, weapon_stall_Sword3Blade, weapon_stall_Sword3Gold, weapon_stall_Sword3Grip, weapon_stall_ShieldFace, weapon_stall_ShieldRim, weapon_stall_ShieldBoss, weapon_stall_AxeHandle, weapon_stall_AxeHead, weapon_stall_TrayWood, weapon_stall_TrayVelvet, weapon_stall_DaggerBlade, weapon_stall_DaggerGold, weapon_stall_DaggerGrip | 2,672 | 15.61 x 8.08 x 11.38 (pieces only) | pieces of Hub.WeaponShop: awning, 3 swords, shield, axe, counter tray (frame by Agent B) |
| `Blender_Exports/Props/trophy_stall.fbx` | trophy_stall (photo 18) | 6 (0 anchored): trophy_stall_AwningGreen, trophy_stall_AwningCream, trophy_stall_Gold, trophy_stall_Wood, trophy_stall_Ball_Glass, trophy_stall_BallCore_Glow | 2,246 | 15.60 x 7.22 x 11.38 (pieces only) | pieces of Hub.TrophyMerchant: awning, trophy cup, crystal ball (replaces CounterSkull) |
| `Blender_Exports/Props/diamond_shop.fbx` | diamond_shop (photo 20) | 10 (3 anchored): diamond_shop_AwningBlue, diamond_shop_AwningWhite, diamond_shop_Diamond_Glow, diamond_shop_DiamondRim_Glow, diamond_shop_SignGold, diamond_shop_Cushions, diamond_shop_Tassels, diamond_shop_GemsCyan_Glow, diamond_shop_GemGold_Glow, diamond_shop_GemRims_Glow | 2,656 | 15.60 x 15.68 x 11.38 (pieces only) | pieces of Hub.DiamondShop: awning, diamond sign + gold bar/post, 3 gems on cushions |

The three stall files hold only the Blender pieces (Agent B builds the frames in Studio). Some pieces carry an
`Anchor` in the data: they are re-based onto the Studio part they replace, so they land exactly where today's
parts are (Blender/Props/README.txt section 7).

Data for the apply command (paste into `ServerStorage.DevTools.PropMeshData`, ModuleScript):
`Blender_Exports/Props/PropMeshData.luau` (generated: texture ids, families, and per prop every mesh's family, colour,
position, size, pivot, colliders and effect points).
