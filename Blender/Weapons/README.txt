FIGHT YOUR DESTINY - WEAPON MODELS (Blender sources)
====================================================
Made with tools/blender/fyd_weapons.py (pipeline) + fyd_weapon_parts.py + one builder module per
category (fyd_weapon_swords.py, ...). Every .blend here is the SOURCE OF TRUTH: if the axis/scale
convention below needs a fix after the first import in Studio, change export_fbx() in
fyd_weapons.py and re-export every FBX in one pass from these .blend files (the "Weapon" object).

AXIS / SCALE CONVENTION (pilot: Sword/01_plains_sword, 2026-10-05, not yet tested in Studio)
- Built in METERS at real scale, then every weapon is scaled so its longest side is exactly the
  category length of the brief (1 stud = 0.28 m):
    Sword 4.5 | Spear 8 | Heavy 5 | Dagger 2 | Gauntlet 1.8 (one hand) | Ranged 5 | Magic 6 | Whip 6 studs
- ORIGIN = grip center (where the hand holds the weapon).
- In Blender the blade / head points along +Z (up) and the front of the weapon faces -Y.
- FBX export: Y up, -Z forward (Blender defaults), apply unit scale, scale 1.0, textures embedded.
  -> In Roblox the blade points along +Y (up), the origin is the grip.
- IMPORT (owner): Studio > Asset Manager > Bulk Import (or 3D Importer), choose FILE DIMENSIONS =
  METERS (or check that the Sword is ~4.5 studs long). If it comes in 100x too big/small, choose
  Centimeters/Meters accordingly - the source .blend files do not need to change.
- Tool setup in Studio (gameplay step): Handle = the MeshPart, Tool.Grip so the hand holds the origin;
  the blade goes up the hand's axis. Glow parts are the "_Glow" material (make them Neon or add a
  SurfaceAppearance/Emissive + PointLight in Studio; rarity glow and particles are added in Studio).

ONE .blend PER WEAPON
- Sword/01_plains_sword.blend ... 12_void_sword.blend (same pattern in every category folder).
- Contains: the "Weapon" mesh (triangulated, applied transforms, clean normals, Smart-UV unwrapped,
  no overlapping islands), material "<id>_Main" with 3 baked 512 px maps PACKED in the file
  (<id>_color sRGB, <id>_metalness and <id>_roughness Non-Color), optional "<id>_Glow" (emissive
  parts, one color per weapon), and the icon render rig (collection "IconRig").
- FBX: Blender_Exports/Weapons/<Category>/<NN>_<id>.fbx (textures embedded).
- Icon: Icons/Weapons/<Category>/<NN>_<id>_icon.png (512 px, transparent, diagonal pose, outline).
- Previews: Previews/Weapons/<Category>/<NN>_<id>_preview.png (3 angles) and <Category>_lineup.png.
- weapons_manifest.csv: id, category, zone, display name, triangles, budget, length, glow, status.

BUDGETS: 500-3,000 triangles (Gauntlet and Magic up to 4,000). Rarity is NOT modeled.
