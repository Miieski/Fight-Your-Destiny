FIGHT YOUR DESTINY - WEAPON MODELS (Blender sources)
====================================================
Made with tools/blender/fyd_weapons.py (pipeline) + fyd_weapon_parts.py + one builder module per
category (fyd_weapon_swords.py, ...). Every .blend here is the SOURCE OF TRUTH: if the axis/scale
convention below needs a fix after the first import in Studio, change export_fbx() in
fyd_weapons.py and re-export every FBX in one pass from these .blend files (the "Weapon" object).

AXIS / SCALE CONVENTION (pilot: Sword/01_plains_sword, 2026-10-05; all 96 weapons follow it; not yet
imported in Studio by the owner)
- Built in METERS at real scale, then every weapon is scaled so its longest side is exactly the
  category length of the brief (1 stud = 0.28 m):
    Sword 4.5 | Spear 8 | Heavy 5 | Dagger 2 | Gauntlet 1.8 (one hand) | Ranged 5 | Magic 6 | Whip 6 studs
- ORIGIN = grip center (where the hand holds the weapon).
- In Blender the blade / head points along +Z (up) and the front of the weapon faces -Y.
- GAUNTLET exception: ONE right-hand gauntlet per zone (mirror it in Studio, scale X -1, for the left
  hand). Origin = fist center (where the hand is), knuckles along +Z, forearm cuff along -Z, back of the
  hand facing -Y, thumb on -X. Attach it to the RightHand/LeftHand rather than as a Tool grip.
- RANGED: origin = the hand grip, longest side along Z. Bows: limbs along Z, string on -X, arrows fly
  towards +X. Crossbows: bolt points +Z, prod spans X, trigger grip hangs towards +Y. Guns and the blowgun:
  muzzle +Z, pistol grip towards -X. Set Tool.Grip per weapon type in Studio.
- WHIP & CHAIN: origin = handle grip, handle along Z, then a stylized S-curved lash/chain rising along +Z
  (6 studs in total). It reads as a whip in icons and in the hand; for a moving lash in Studio, keep the
  handle and drive a rope/Beam from the handle tip instead of the rigid lash.
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

IN STUDIO (weapon Tools, 2026-10-05)
- Until the FBX files are imported, ReplicatedStorage.Assets.Weapons holds 96 PLACEHOLDER Tools (simple parts per
  category, zone colors, attribute Placeholder = true) so the shop, case opening and equipping already work.
- After the Bulk Import (File Dimensions = Meters), put the imported models in one folder (any place, e.g.
  workspace.ImportedWeapons) and run in the command bar:
      require(game.ServerStorage.DevTools.WeaponTools).fromImport(workspace.ImportedWeapons)
  It builds the real Tool for every model it recognises ("01_plains_sword" or "plains_sword"): biggest part =
  Handle, the others welded, "_Glow" parts made Neon, grip restored from DevTools.WeaponBounds (Studio recenters
  imported meshes), TipAttachment / BaseAttachment (+ MuzzleAttachment for Ranged and Magic), attributes WeaponId,
  Category, Zone, Placeholder = false. It returns (built, skipped) and warns when a model has the wrong length.
  require(...).missing() lists the weapons that still use a placeholder.
- Tool.Grip (R15, measured in Play): identity = the head points straight up out of the fist with the front facing
  forward (swords, spears, heavies, daggers, staffs, whips). Bows: limbs up, string toward the body. Crossbows
  (tundra, hell, dead) and guns / blowgun (jungle, abyss, mechanical): muzzle forward. Gauntlets: knuckles forward,
  back of the hand up. The FBX export maps Blender +X to Roblox -X (bow strings and gauntlet thumbs are on +X).
