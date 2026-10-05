FIGHT YOUR DESTINY - CREATURE MODELS (enemies, mini-bosses, bosses, pets, hub NPCs)
================================================================================
Brief: docs/enemies_npcs_pets_brief.txt Parts D / E / F. Made headless with Blender 5.2:
  tools/blender/fyd_creatures.py        the pipeline (build, palette, clips, previews, .blend, FBX, JSON, manifest)
  tools/blender/fyd_creature_clips.py   the animation clips of every rig family (the game plays the same data)
  tools/blender/fyd_recipes_*.py        one recipe (Python function) per model, zone by zone
  tools/blender/run_creatures.py        batch runner:
      "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup ^
          --python tools/blender/run_creatures.py -- plains_boar plains_wild_wolf
      ... -- --all                        every recipe
      ... -- --lineup Mobs 1 <ids...>     lineup picture of a zone / category (real relative scale)
  tools/blender/check_rig_clips.py      checksums of the clips (compare with Config/RigClips in Studio)
The .blend files are the SOURCE OF TRUTH of the meshes; to change the conventions, change fyd_creatures.py and
re-run the recipes (every file is rebuilt in a few seconds).

FOLDERS (category first, then zone)
  Blender/Rigs/                       README of the rig families (joint names, reference sizes)
  Blender/<Category>/<NN_Zone>/<id>.blend      Category = Mobs, MiniBosses, Bosses, Pets; NPC/Hub/ for the NPCs
  Blender/<Category>/<NN_Zone>/textures/<id>_palette.png   (also packed in the .blend and embedded in the FBX)
  Blender_Exports/<same>/<id>.fbx     mesh for Studio (owner import)
  Blender_Exports/<same>/<id>_rig.json   joints, parents, hitbox, colors (also encoded in the FBX object names)
  Blender_Exports/<same>/<id>_anims.json clips of the model (its family clips + its scale)
  Previews/<same>/<id>_preview.png    front 3/4, side, back, action pose
  Previews/<same>/<Category>_<NN_Zone>_lineup.png   every model of the zone side by side at relative scale
  Blender/models_manifest.csv         id, category, zone, rig, size, triangles, budget, parts, clips, status, files

AXES / SCALE / PIVOTS (pilot: Mobs/01_Plains/plains_boar, 2026-10-05; everything follows it)
- Recipes are written in ROBLOX model space in studs: x right, y up, z back; the creature FACES -Z (Roblox
  LookVector), feet center on the origin. The pipeline converts to Blender (X = -x, Y = z, Z = y; the creature
  faces -Y) and to METERS (1 stud = 0.28 m), and rescales the whole model so its height (or its length for the
  serpents and the crocodile) is exactly the size of the Part F list.
- FBX export like the weapons: Y up, -Z forward, apply unit scale, scale 1.0, textures embedded, NO animation
  (Blender -Y front -> Roblox -Z front, Blender +X -> Roblox -X).
- SEGMENTED RIG: one mesh object per joint (Body, Head, LegFL ... see Blender/Rigs/README.txt), its ORIGIN ON THE
  JOINT, parented to its parent part. Decorative pieces (tusks, ears, belts, weapons) are merged into the part they
  move with. Glowing pieces (eyes, crystals, runes) are separate "<Name>_Glow" objects -> Neon in Studio.
- One material "<id>_Palette": a 256 px palette texture (32 px swatches); every face is UV-mapped to its swatch.
  Flat shading, triangulated. Glow objects get "<id>_Glow" (emissive).
- "Root": invisible hitbox box (wireframe in Blender, not rendered) = the bounds of the model.

ANIMATION PIPELINE (decision taken with the pilot)
- Option 2 of the brief: the clips are DATA, not imported animations. Importing Roblox animations from FBX needs
  skinned rigs + the owner's manual Animation Editor steps, and even the meshes need the owner's import tonight.
- The clips of each rig family live in tools/blender/fyd_creature_clips.py (Roblox joint space: rotation in
  radians for CFrame.Angles, offsets in studs at the family reference size). The pipeline bakes them on the timeline
  of every .blend (24 fps, one marker per clip: "Idle_loop", "Walk_loop", "Attack1", ... the Impact time of an
  attack is in the JSON) and writes <id>_anims.json.
- The game plays the SAME clips: src/ReplicatedStorage/GameSystem/Config/RigClips.luau (Luau twin of the Python
  file; RigClips.checksum(family) == python tools/blender/check_rig_clips.py) + GameClient/Controllers/AnimPlayer
  (client, Motor6D.Transform; locomotion Idle / Walk / Run by speed, attacks stretched to land on the server
  telegraph, Hit, Death, Spawn, boss Intro / Enrage, NPC Wave / Talk). It runs today on the part-built
  placeholders (Lib/EnemyRigs, same joint names) and will run unchanged on the imported meshes.
- To change a clip: edit BOTH fyd_creature_clips.py and RigClips.luau, check the checksums, re-run the recipes.

CLIPS PER ROLE (brief Part E)
  normal enemies: Idle, Walk, Run (quadrupeds / bipeds), Attack1 (or Shoot for ranged), Hit, Death, Spawn
  mini-bosses:    + Attack2 (heavy), Roar
  bosses:         Intro (roar), Idle, Walk, Attack1, Hit, Death, Enrage
  pets:           Idle (the follow script adds the walking bob)
  NPCs:           Idle, Wave, Talk

IMPORT IN STUDIO (owner, once the files are ready)
1. Studio > Asset Manager > Bulk Import (or File > Import 3D), pick the .fbx files of Blender_Exports/<Category>/...
   FILE DIMENSIONS = METERS (a 3-stud Boar must come in ~3 studs tall). Import each file as ONE Model, keep the
   separate meshes (do NOT merge), keep the object names, textures on.
2. Put all the imported Models in one folder, e.g. workspace.ImportedCreatures (names = ids: plains_boar ...).
3. Command bar:  require(game.ServerStorage.DevTools.EnemyModels).fromImport(workspace.ImportedCreatures)
   It rebuilds each one as a rig (Root hitbox + Motor6D joints from the object names, Neon glow parts) into
   ServerStorage.Enemies / ServerStorage.Bosses / ReplicatedStorage.Assets.Pets / ServerStorage.NPCs.
   EnemyService uses them at once (placeholders otherwise). require(...).missing() lists what is still missing.
   Self-test done: a placeholder exported with the FBX naming and rebuilt by fromImport keeps every joint within
   0.007 studs.

PER MODEL CHECKLIST: readable at 128 px | triangle budget | pivots on the joints | clips present | .blend saved |
FBX + JSON exported | manifest row | preview rendered. Budgets: pets 200-800, normal 300-1,500, mini-bosses
1,500-3,000, bosses 3,000-6,000, NPCs 1,000-2,500 triangles.
