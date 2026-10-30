# Weapon FBX files to import (Weapons V2, 6 categories x 12 zones = 72)

Made by tools/blender/fyd_weapons2.py (convention in Blender/Weapons/README.txt), rebuilt from each icon on
2026-10-12, all 72 re-checked against their icons on 2026-10-13 (side-by-side sheets: `Previews/Weapons/<Category>/<NN>_<id>_compare.png`). Until they are imported the
game uses the PLACEHOLDER Tools of `ReplicatedStorage.Assets.Weapons` (attribute Placeholder = true), so nothing
is blocked. The old V1 files are in `BackUP_Files/old_weapon_models_2026-10-12/`.

**STATUS 2026-10-13: IMPORTED AND APPLIED** (72/72 Tools on their real mesh, 68 with their glow mask). What the import
really gave, for the next time: one MeshPart + SurfaceAppearance per file (the `<id>_Glow` faces are merged into it:
`DevTools.WeaponGlow` gives them back as an emissive mask, called by ApplyWeaponMeshes), and the Studio Default
preset reads the files as centimeters (28x too big: ApplyWeaponMeshes scales them back). After a re-export of some
.blend files, re-run `tools/blender/weapon_emissive_masks.py` for them and upload the new masks.

## How to import (owner)

1. Studio > **File > Import 3D**. In the file browser open `Blender_Exports/Weapons_ALL_import/` (a flat copy of the
   72 files, not in git), press **Ctrl+A** and **Open**: the 72 files go into the importer's **import queue**.
2. In the queue, set **Scale Unit = Meters** (preset or per file; the Iron Shortsword must come in about 4.5 studs
   long). Keep the defaults otherwise: Import Only As Model ON, Merge Meshes OFF, Insert In Workspace ON, textures on.
   Do not rotate the imports. Click **Import** (all 72 boxes ticked) and wait until the 72 models are in the Workspace.
   If the Scale Unit was forgotten, nothing is lost: the next step scales each weapon back to its length.
3. Tell Claude, or run in the command bar: `require(game.ServerStorage.DevTools.ApplyWeaponMeshes)()` (or pass the
   folder: `require(game.ServerStorage.DevTools.ApplyWeaponMeshes)(workspace.ImportedWeapons)`).
   For each weapon it swaps the mesh into `ReplicatedStorage.Assets.Weapons.<WeaponId>.Handle` (biggest textured part =
   Handle, the others welded, `_Glow` parts Neon), keeps the Tool's attributes and grip rotation, moves the grip to
   the model's true origin, rebuilds `TipAttachment`, `BaseAttachment`, `MuzzleAttachment` (Ranged, Magic) and
   `ImpactAttachment` (Heavy) at the points measured in Blender (`DevTools.WeaponPoints`), sets Placeholder = false
   and prints a report: applied / not found / rescaled / wrong shape (a wrong shape is left untouched).
4. Check a few weapons in Play (grip, trail from Base to Tip), delete the imported models from the Workspace, save the
   place. `require(game.ServerStorage.DevTools.WeaponTools).missing()` lists the weapons still on placeholders.

(Use the 3D Importer rather than the Asset Manager's Bulk Import: its import queue takes the 72 files at once and
shows the embedded textures in its preview before importing.)

| File | Name | Category | Zone | Length (studs) | Triangles | Glow | Goes to |
|---|---|---|---|---|---|---|---|
| `Blender_Exports/Weapons/Sword/01_plains_sword.fbx` | Iron Shortsword | Sword | Plains | 4.5 | 1606 | no | ReplicatedStorage.Assets.Weapons.plains_sword |
| `Blender_Exports/Weapons/Sword/02_desert_sword.fbx` | Sand Scimitar | Sword | Desert | 4.5 | 1582 | no | ReplicatedStorage.Assets.Weapons.desert_sword |
| `Blender_Exports/Weapons/Sword/03_jungle_sword.fbx` | Jungle Machete | Sword | Jungle | 4.5 | 958 | no | ReplicatedStorage.Assets.Weapons.jungle_sword |
| `Blender_Exports/Weapons/Sword/04_tundra_sword.fbx` | Frostbrand Blade | Sword | Tundra | 4.5 | 1064 | yes | ReplicatedStorage.Assets.Weapons.tundra_sword |
| `Blender_Exports/Weapons/Sword/05_swamp_sword.fbx` | Rotwood Sword | Sword | Swamp | 4.5 | 866 | yes | ReplicatedStorage.Assets.Weapons.swamp_sword |
| `Blender_Exports/Weapons/Sword/06_volcano_sword.fbx` | Magma Blade | Sword | Volcano | 4.5 | 1218 | yes | ReplicatedStorage.Assets.Weapons.volcano_sword |
| `Blender_Exports/Weapons/Sword/07_hell_sword.fbx` | Demon Blade | Sword | Hell | 4.5 | 1394 | yes | ReplicatedStorage.Assets.Weapons.hell_sword |
| `Blender_Exports/Weapons/Sword/08_heaven_sword.fbx` | Radiant Longsword | Sword | Heaven | 4.5 | 1566 | yes | ReplicatedStorage.Assets.Weapons.heaven_sword |
| `Blender_Exports/Weapons/Sword/09_dead_sword.fbx` | Deathbringer Sword | Sword | Dead | 4.5 | 2538 | yes | ReplicatedStorage.Assets.Weapons.dead_sword |
| `Blender_Exports/Weapons/Sword/10_abyss_sword.fbx` | Tidal Sword | Sword | Abyss | 4.5 | 1662 | yes | ReplicatedStorage.Assets.Weapons.abyss_sword |
| `Blender_Exports/Weapons/Sword/11_mechanical_sword.fbx` | Plasma Sword | Sword | Mechanical | 4.5 | 1234 | yes | ReplicatedStorage.Assets.Weapons.mechanical_sword |
| `Blender_Exports/Weapons/Sword/12_void_sword.fbx` | Voidforged Blade | Sword | Void | 4.5 | 1360 | yes | ReplicatedStorage.Assets.Weapons.void_sword |
| `Blender_Exports/Weapons/Spear/01_plains_spear.fbx` | Hunter's Spear | Spear | Plains | 8 | 1368 | no | ReplicatedStorage.Assets.Weapons.plains_spear |
| `Blender_Exports/Weapons/Spear/02_desert_spear.fbx` | Nomad Pike | Spear | Desert | 8 | 1740 | no | ReplicatedStorage.Assets.Weapons.desert_spear |
| `Blender_Exports/Weapons/Spear/03_jungle_spear.fbx` | Tribal Spear | Spear | Jungle | 8 | 1414 | no | ReplicatedStorage.Assets.Weapons.jungle_spear |
| `Blender_Exports/Weapons/Spear/04_tundra_spear.fbx` | Icicle Lance | Spear | Tundra | 8 | 1384 | yes | ReplicatedStorage.Assets.Weapons.tundra_spear |
| `Blender_Exports/Weapons/Spear/05_swamp_spear.fbx` | Witch Hunter Spear | Spear | Swamp | 8 | 1614 | yes | ReplicatedStorage.Assets.Weapons.swamp_spear |
| `Blender_Exports/Weapons/Spear/06_volcano_spear.fbx` | Obsidian Spear | Spear | Volcano | 8 | 1776 | yes | ReplicatedStorage.Assets.Weapons.volcano_spear |
| `Blender_Exports/Weapons/Spear/07_hell_spear.fbx` | Infernal Halberd | Spear | Hell | 8 | 1640 | yes | ReplicatedStorage.Assets.Weapons.hell_spear |
| `Blender_Exports/Weapons/Spear/08_heaven_spear.fbx` | Celestial Lance | Spear | Heaven | 8 | 1996 | yes | ReplicatedStorage.Assets.Weapons.heaven_spear |
| `Blender_Exports/Weapons/Spear/09_dead_spear.fbx` | Grave Pike | Spear | Dead | 8 | 1578 | yes | ReplicatedStorage.Assets.Weapons.dead_spear |
| `Blender_Exports/Weapons/Spear/10_abyss_spear.fbx` | Deepsea Trident | Spear | Abyss | 8 | 1506 | yes | ReplicatedStorage.Assets.Weapons.abyss_spear |
| `Blender_Exports/Weapons/Spear/11_mechanical_spear.fbx` | Electro Lance | Spear | Mechanical | 8 | 1768 | yes | ReplicatedStorage.Assets.Weapons.mechanical_spear |
| `Blender_Exports/Weapons/Spear/12_void_spear.fbx` | Void Piercer | Spear | Void | 8 | 1624 | yes | ReplicatedStorage.Assets.Weapons.void_spear |
| `Blender_Exports/Weapons/Heavy/01_plains_heavy.fbx` | Stone Hammer | Heavy | Plains | 5 | 1358 | no | ReplicatedStorage.Assets.Weapons.plains_heavy |
| `Blender_Exports/Weapons/Heavy/02_desert_heavy.fbx` | Obelisk Hammer | Heavy | Desert | 5 | 1846 | no | ReplicatedStorage.Assets.Weapons.desert_heavy |
| `Blender_Exports/Weapons/Heavy/03_jungle_heavy.fbx` | Totem Club | Heavy | Jungle | 5 | 1618 | no | ReplicatedStorage.Assets.Weapons.jungle_heavy |
| `Blender_Exports/Weapons/Heavy/04_tundra_heavy.fbx` | Glacier Axe | Heavy | Tundra | 5 | 1534 | yes | ReplicatedStorage.Assets.Weapons.tundra_heavy |
| `Blender_Exports/Weapons/Heavy/05_swamp_heavy.fbx` | Swamp Maul | Heavy | Swamp | 5 | 1730 | yes | ReplicatedStorage.Assets.Weapons.swamp_heavy |
| `Blender_Exports/Weapons/Heavy/06_volcano_heavy.fbx` | Lava Hammer | Heavy | Volcano | 5 | 1782 | yes | ReplicatedStorage.Assets.Weapons.volcano_heavy |
| `Blender_Exports/Weapons/Heavy/07_hell_heavy.fbx` | Doom Axe | Heavy | Hell | 5 | 1760 | yes | ReplicatedStorage.Assets.Weapons.hell_heavy |
| `Blender_Exports/Weapons/Heavy/08_heaven_heavy.fbx` | Judgment Hammer | Heavy | Heaven | 5 | 2480 | yes | ReplicatedStorage.Assets.Weapons.heaven_heavy |
| `Blender_Exports/Weapons/Heavy/09_dead_heavy.fbx` | Gravedigger's Maul | Heavy | Dead | 5 | 2538 | yes | ReplicatedStorage.Assets.Weapons.dead_heavy |
| `Blender_Exports/Weapons/Heavy/10_abyss_heavy.fbx` | Kraken Anchor | Heavy | Abyss | 5 | 2270 | yes | ReplicatedStorage.Assets.Weapons.abyss_heavy |
| `Blender_Exports/Weapons/Heavy/11_mechanical_heavy.fbx` | Hydraulic Hammer | Heavy | Mechanical | 5 | 2270 | yes | ReplicatedStorage.Assets.Weapons.mechanical_heavy |
| `Blender_Exports/Weapons/Heavy/12_void_heavy.fbx` | Void Maul | Heavy | Void | 5 | 1584 | yes | ReplicatedStorage.Assets.Weapons.void_heavy |
| `Blender_Exports/Weapons/Dagger/01_plains_dagger.fbx` | Hunter's Knife | Dagger | Plains | 2 | 900 | no | ReplicatedStorage.Assets.Weapons.plains_dagger |
| `Blender_Exports/Weapons/Dagger/02_desert_dagger.fbx` | Scorpion Dagger | Dagger | Desert | 2 | 1220 | no | ReplicatedStorage.Assets.Weapons.desert_dagger |
| `Blender_Exports/Weapons/Dagger/03_jungle_dagger.fbx` | Venom Fang | Dagger | Jungle | 2 | 930 | yes | ReplicatedStorage.Assets.Weapons.jungle_dagger |
| `Blender_Exports/Weapons/Dagger/04_tundra_dagger.fbx` | Ice Shard Dagger | Dagger | Tundra | 2 | 810 | yes | ReplicatedStorage.Assets.Weapons.tundra_dagger |
| `Blender_Exports/Weapons/Dagger/05_swamp_dagger.fbx` | Toad Tooth Dagger | Dagger | Swamp | 2 | 968 | yes | ReplicatedStorage.Assets.Weapons.swamp_dagger |
| `Blender_Exports/Weapons/Dagger/06_volcano_dagger.fbx` | Ember Dagger | Dagger | Volcano | 2 | 1030 | yes | ReplicatedStorage.Assets.Weapons.volcano_dagger |
| `Blender_Exports/Weapons/Dagger/07_hell_dagger.fbx` | Imp Claw Dagger | Dagger | Hell | 2 | 1276 | yes | ReplicatedStorage.Assets.Weapons.hell_dagger |
| `Blender_Exports/Weapons/Dagger/08_heaven_dagger.fbx` | Feather Dagger | Dagger | Heaven | 2 | 1302 | yes | ReplicatedStorage.Assets.Weapons.heaven_dagger |
| `Blender_Exports/Weapons/Dagger/09_dead_dagger.fbx` | Ghoul Fang | Dagger | Dead | 2 | 1296 | yes | ReplicatedStorage.Assets.Weapons.dead_dagger |
| `Blender_Exports/Weapons/Dagger/10_abyss_dagger.fbx` | Angler Dagger | Dagger | Abyss | 2 | 1258 | yes | ReplicatedStorage.Assets.Weapons.abyss_dagger |
| `Blender_Exports/Weapons/Dagger/11_mechanical_dagger.fbx` | Nano Dagger | Dagger | Mechanical | 2 | 976 | yes | ReplicatedStorage.Assets.Weapons.mechanical_dagger |
| `Blender_Exports/Weapons/Dagger/12_void_dagger.fbx` | Rift Dagger | Dagger | Void | 2 | 1186 | yes | ReplicatedStorage.Assets.Weapons.void_dagger |
| `Blender_Exports/Weapons/Ranged/01_plains_ranged.fbx` | Hunting Bow | Ranged | Plains | 5 | 994 | no | ReplicatedStorage.Assets.Weapons.plains_ranged |
| `Blender_Exports/Weapons/Ranged/02_desert_ranged.fbx` | Desert Recurve Bow | Ranged | Desert | 5 | 1494 | no | ReplicatedStorage.Assets.Weapons.desert_ranged |
| `Blender_Exports/Weapons/Ranged/03_jungle_ranged.fbx` | Poison Blowgun | Ranged | Jungle | 5 | 1518 | yes | ReplicatedStorage.Assets.Weapons.jungle_ranged |
| `Blender_Exports/Weapons/Ranged/04_tundra_ranged.fbx` | Frostbite Crossbow | Ranged | Tundra | 5 | 1206 | yes | ReplicatedStorage.Assets.Weapons.tundra_ranged |
| `Blender_Exports/Weapons/Ranged/05_swamp_ranged.fbx` | Plague Bow | Ranged | Swamp | 5 | 1478 | yes | ReplicatedStorage.Assets.Weapons.swamp_ranged |
| `Blender_Exports/Weapons/Ranged/06_volcano_ranged.fbx` | Flame Bow | Ranged | Volcano | 5 | 1226 | yes | ReplicatedStorage.Assets.Weapons.volcano_ranged |
| `Blender_Exports/Weapons/Ranged/07_hell_ranged.fbx` | Soulfire Crossbow | Ranged | Hell | 5 | 1184 | yes | ReplicatedStorage.Assets.Weapons.hell_ranged |
| `Blender_Exports/Weapons/Ranged/08_heaven_ranged.fbx` | Dawn Bow | Ranged | Heaven | 5 | 1534 | yes | ReplicatedStorage.Assets.Weapons.heaven_ranged |
| `Blender_Exports/Weapons/Ranged/09_dead_ranged.fbx` | Bone Crossbow | Ranged | Dead | 5 | 1784 | yes | ReplicatedStorage.Assets.Weapons.dead_ranged |
| `Blender_Exports/Weapons/Ranged/10_abyss_ranged.fbx` | Harpoon Gun | Ranged | Abyss | 5 | 1594 | yes | ReplicatedStorage.Assets.Weapons.abyss_ranged |
| `Blender_Exports/Weapons/Ranged/11_mechanical_ranged.fbx` | Pulse Rifle | Ranged | Mechanical | 5 | 1416 | yes | ReplicatedStorage.Assets.Weapons.mechanical_ranged |
| `Blender_Exports/Weapons/Ranged/12_void_ranged.fbx` | Starfall Bow | Ranged | Void | 5 | 1744 | yes | ReplicatedStorage.Assets.Weapons.void_ranged |
| `Blender_Exports/Weapons/Magic/01_plains_magic.fbx` | Apprentice Staff | Magic | Plains | 6 | 1844 | yes | ReplicatedStorage.Assets.Weapons.plains_magic |
| `Blender_Exports/Weapons/Magic/02_desert_magic.fbx` | Sandstorm Staff | Magic | Desert | 6 | 3076 | yes | ReplicatedStorage.Assets.Weapons.desert_magic |
| `Blender_Exports/Weapons/Magic/03_jungle_magic.fbx` | Shaman Totem Staff | Magic | Jungle | 6 | 2576 | yes | ReplicatedStorage.Assets.Weapons.jungle_magic |
| `Blender_Exports/Weapons/Magic/04_tundra_magic.fbx` | Blizzard Staff | Magic | Tundra | 6 | 1726 | yes | ReplicatedStorage.Assets.Weapons.tundra_magic |
| `Blender_Exports/Weapons/Magic/05_swamp_magic.fbx` | Cauldron Staff | Magic | Swamp | 6 | 2182 | yes | ReplicatedStorage.Assets.Weapons.swamp_magic |
| `Blender_Exports/Weapons/Magic/06_volcano_magic.fbx` | Eruption Staff | Magic | Volcano | 6 | 2050 | yes | ReplicatedStorage.Assets.Weapons.volcano_magic |
| `Blender_Exports/Weapons/Magic/07_hell_magic.fbx` | Infernal Tome Staff | Magic | Hell | 6 | 2284 | yes | ReplicatedStorage.Assets.Weapons.hell_magic |
| `Blender_Exports/Weapons/Magic/08_heaven_magic.fbx` | Seraph Staff | Magic | Heaven | 6 | 2370 | yes | ReplicatedStorage.Assets.Weapons.heaven_magic |
| `Blender_Exports/Weapons/Magic/09_dead_magic.fbx` | Lich Staff | Magic | Dead | 6 | 3070 | yes | ReplicatedStorage.Assets.Weapons.dead_magic |
| `Blender_Exports/Weapons/Magic/10_abyss_magic.fbx` | Tidecaller Staff | Magic | Abyss | 6 | 2538 | yes | ReplicatedStorage.Assets.Weapons.abyss_magic |
| `Blender_Exports/Weapons/Magic/11_mechanical_magic.fbx` | Tesla Coil Staff | Magic | Mechanical | 6 | 2774 | yes | ReplicatedStorage.Assets.Weapons.mechanical_magic |
| `Blender_Exports/Weapons/Magic/12_void_magic.fbx` | Void Staff | Magic | Void | 6 | 2500 | yes | ReplicatedStorage.Assets.Weapons.void_magic |
