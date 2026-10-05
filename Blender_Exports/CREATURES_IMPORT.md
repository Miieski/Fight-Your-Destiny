# Creature FBX files to import (enemies, mini-bosses, bosses, pets, hub NPCs - zones 1-4)

Made by tools/blender/fyd_creatures.py (Blender/README.txt). 88 files. Until they are imported the game uses
part-built placeholders with the same joints and the same animations, so nothing is blocked.

## How to import (owner)

1. Studio > Asset Manager > **Bulk Import** (or File > Import 3D) and pick the `.fbx` files below.
   **File dimensions = Meters** (a 3-stud Boar must come in about 3 studs tall). One Model per file, keep the
   separate meshes (do NOT merge), keep the object names, textures on (each file embeds its 256 px palette).
2. Put every imported Model in one folder, for example `workspace.ImportedCreatures` (Model names = ids).
3. Command bar: `require(game.ServerStorage.DevTools.EnemyModels).fromImport(workspace.ImportedCreatures)`
   It rebuilds each model as a rig (Root hitbox, Motor6D joints from the object names, Neon glow parts) and puts
   it where the game looks for it (column "Goes to"). `require(...).missing()` lists enemies still on placeholders.
4. Delete `workspace.ImportedCreatures`, save the place.

Pets: after the import the pets of zones 1-4 replace the procedural pets of the menu task automatically
(ReplicatedStorage.Assets.Pets.<id>). NPCs: NPCService uses ServerStorage.NPCs.<id> at the next server start.

| File | Name | Rig | Size (studs) | Triangles | Goes to |
|---|---|---|---|---|---|
| `Blender_Exports/Mobs/01_Plains/plains_aggressive_seagull.fbx` | Aggressive Seagull | Bird | 3 tall | 338 | ServerStorage.Enemies.plains_aggressive_seagull |
| `Blender_Exports/Mobs/01_Plains/plains_bat.fbx` | Bat | Bird | 2.5 tall | 312 | ServerStorage.Enemies.plains_bat |
| `Blender_Exports/Mobs/01_Plains/plains_boar.fbx` | Boar | Quadruped | 3 tall | 482 | ServerStorage.Enemies.plains_boar |
| `Blender_Exports/Mobs/01_Plains/plains_brown_bear.fbx` | Brown Bear | Quadruped | 6 tall | 536 | ServerStorage.Enemies.plains_brown_bear |
| `Blender_Exports/Mobs/01_Plains/plains_field_bandit.fbx` | Field Bandit | Biped | 5.5 tall | 552 | ServerStorage.Enemies.plains_field_bandit |
| `Blender_Exports/Mobs/01_Plains/plains_forest_archer.fbx` | Forest Archer | Biped | 5.5 tall | 552 | ServerStorage.Enemies.plains_forest_archer |
| `Blender_Exports/Mobs/01_Plains/plains_giant_crab.fbx` | Giant Crab | Crustacean | 4 tall | 344 | ServerStorage.Enemies.plains_giant_crab |
| `Blender_Exports/Mobs/01_Plains/plains_giant_spider.fbx` | Giant Spider | Arachnid | 4.5 tall | 412 | ServerStorage.Enemies.plains_giant_spider |
| `Blender_Exports/Mobs/01_Plains/plains_miner_skeleton.fbx` | Miner Skeleton | Biped | 5.5 tall | 648 | ServerStorage.Enemies.plains_miner_skeleton |
| `Blender_Exports/Mobs/01_Plains/plains_shipwrecked_pirate.fbx` | Shipwrecked Pirate | Biped | 5.5 tall | 596 | ServerStorage.Enemies.plains_shipwrecked_pirate |
| `Blender_Exports/Mobs/01_Plains/plains_wild_wolf.fbx` | Wild Wolf | Quadruped | 4 tall | 508 | ServerStorage.Enemies.plains_wild_wolf |
| `Blender_Exports/Mobs/02_Desert/desert_cliff_bandit.fbx` | Cliff Bandit | Biped | 5.5 tall | 672 | ServerStorage.Enemies.desert_cliff_bandit |
| `Blender_Exports/Mobs/02_Desert/desert_crocodile.fbx` | Desert Crocodile | Quadruped | 7 long | 396 | ServerStorage.Enemies.desert_crocodile |
| `Blender_Exports/Mobs/02_Desert/desert_giant_scarab.fbx` | Giant Scarab | Insect | 4 tall | 302 | ServerStorage.Enemies.desert_giant_scarab |
| `Blender_Exports/Mobs/02_Desert/desert_jackal.fbx` | Jackal | Quadruped | 4 tall | 508 | ServerStorage.Enemies.desert_jackal |
| `Blender_Exports/Mobs/02_Desert/desert_mummy.fbx` | Mummy | Biped | 5.5 tall | 640 | ServerStorage.Enemies.desert_mummy |
| `Blender_Exports/Mobs/02_Desert/desert_nomad_bandit.fbx` | Nomad Bandit | Biped | 5.5 tall | 548 | ServerStorage.Enemies.desert_nomad_bandit |
| `Blender_Exports/Mobs/02_Desert/desert_royal_eagle.fbx` | Royal Eagle | Bird | 4 tall | 322 | ServerStorage.Enemies.desert_royal_eagle |
| `Blender_Exports/Mobs/02_Desert/desert_sand_snake.fbx` | Sand Snake | Serpent | 6 long | 392 | ServerStorage.Enemies.desert_sand_snake |
| `Blender_Exports/Mobs/02_Desert/desert_sandstone_golem.fbx` | Sandstone Golem | Golem | 8 tall | 314 | ServerStorage.Enemies.desert_sandstone_golem |
| `Blender_Exports/Mobs/02_Desert/desert_scorpion.fbx` | Scorpion | Arachnid | 3.5 tall | 646 | ServerStorage.Enemies.desert_scorpion |
| `Blender_Exports/Mobs/02_Desert/desert_vulture.fbx` | Vulture | Bird | 4 tall | 330 | ServerStorage.Enemies.desert_vulture |
| `Blender_Exports/Mobs/03_Jungle/jungle_animated_statue.fbx` | Animated Statue | Golem | 7 tall | 456 | ServerStorage.Enemies.jungle_animated_statue |
| `Blender_Exports/Mobs/03_Jungle/jungle_green_snake.fbx` | Green Snake | Serpent | 5 long | 384 | ServerStorage.Enemies.jungle_green_snake |
| `Blender_Exports/Mobs/03_Jungle/jungle_jaguar.fbx` | Jaguar | Quadruped | 5 tall | 736 | ServerStorage.Enemies.jungle_jaguar |
| `Blender_Exports/Mobs/03_Jungle/jungle_monkey.fbx` | Monkey | Biped | 3.5 tall | 608 | ServerStorage.Enemies.jungle_monkey |
| `Blender_Exports/Mobs/03_Jungle/jungle_piranha.fbx` | Piranha | Fish | 2.5 tall | 300 | ServerStorage.Enemies.jungle_piranha |
| `Blender_Exports/Mobs/03_Jungle/jungle_shaman.fbx` | Shaman | Biped | 6 tall | 572 | ServerStorage.Enemies.jungle_shaman |
| `Blender_Exports/Mobs/03_Jungle/jungle_temple_guard.fbx` | Temple Guard | Biped | 6.5 tall | 576 | ServerStorage.Enemies.jungle_temple_guard |
| `Blender_Exports/Mobs/03_Jungle/jungle_toxic_frog.fbx` | Toxic Frog | Amphibian | 3.5 tall | 424 | ServerStorage.Enemies.jungle_toxic_frog |
| `Blender_Exports/Mobs/03_Jungle/jungle_tribal_archer.fbx` | Tribal Archer | Biped | 5.5 tall | 512 | ServerStorage.Enemies.jungle_tribal_archer |
| `Blender_Exports/Mobs/03_Jungle/jungle_tribal_warrior.fbx` | Tribal Warrior | Biped | 5.5 tall | 526 | ServerStorage.Enemies.jungle_tribal_warrior |
| `Blender_Exports/Mobs/03_Jungle/jungle_venomous_spider.fbx` | Venomous Spider | Arachnid | 4 tall | 444 | ServerStorage.Enemies.jungle_venomous_spider |
| `Blender_Exports/Mobs/04_Tundra/tundra_arctic_fox.fbx` | Arctic Fox | Quadruped | 3 tall | 528 | ServerStorage.Enemies.tundra_arctic_fox |
| `Blender_Exports/Mobs/04_Tundra/tundra_cursed_snowman.fbx` | Cursed Snowman | Snowman | 5 tall | 500 | ServerStorage.Enemies.tundra_cursed_snowman |
| `Blender_Exports/Mobs/04_Tundra/tundra_frost_golem.fbx` | Frost Golem | Golem | 9 tall | 326 | ServerStorage.Enemies.tundra_frost_golem |
| `Blender_Exports/Mobs/04_Tundra/tundra_furious_ibex.fbx` | Furious Ibex | Quadruped | 5 tall | 568 | ServerStorage.Enemies.tundra_furious_ibex |
| `Blender_Exports/Mobs/04_Tundra/tundra_ice_eagle.fbx` | Ice Eagle | Bird | 4.5 tall | 302 | ServerStorage.Enemies.tundra_ice_eagle |
| `Blender_Exports/Mobs/04_Tundra/tundra_ice_knight.fbx` | Ice Knight | Biped | 6 tall | 598 | ServerStorage.Enemies.tundra_ice_knight |
| `Blender_Exports/Mobs/04_Tundra/tundra_ice_spirit.fbx` | Ice Spirit | Floater | 4 tall | 306 | ServerStorage.Enemies.tundra_ice_spirit |
| `Blender_Exports/Mobs/04_Tundra/tundra_polar_bear.fbx` | Polar Bear | Quadruped | 6.5 tall | 556 | ServerStorage.Enemies.tundra_polar_bear |
| `Blender_Exports/Mobs/04_Tundra/tundra_swordfish.fbx` | Swordfish | Fish | 4 tall | 320 | ServerStorage.Enemies.tundra_swordfish |
| `Blender_Exports/Mobs/04_Tundra/tundra_white_wolf.fbx` | White Wolf | Quadruped | 4 tall | 508 | ServerStorage.Enemies.tundra_white_wolf |
| `Blender_Exports/Mobs/04_Tundra/tundra_yeti.fbx` | Yeti | Biped | 8 tall | 558 | ServerStorage.Enemies.tundra_yeti |
| `Blender_Exports/MiniBosses/01_Plains/plains_cave_troll.fbx` | Cave Troll | Biped | 10 tall | 2216 | ServerStorage.Enemies.plains_cave_troll |
| `Blender_Exports/MiniBosses/01_Plains/plains_crystal_spider_matriarch.fbx` | Crystal Spider Matriarch | Arachnid | 9 tall | 2328 | ServerStorage.Enemies.plains_crystal_spider_matriarch |
| `Blender_Exports/MiniBosses/02_Desert/desert_anubis_guard.fbx` | Anubis Guard | Biped | 10 tall | 1686 | ServerStorage.Enemies.desert_anubis_guard |
| `Blender_Exports/MiniBosses/02_Desert/desert_sandstorm_djinn.fbx` | Sandstorm Djinn | Floater | 9 tall | 1528 | ServerStorage.Enemies.desert_sandstorm_djinn |
| `Blender_Exports/MiniBosses/03_Jungle/jungle_elder_jaguar.fbx` | Elder Jaguar | Quadruped | 10 tall | 1860 | ServerStorage.Enemies.jungle_elder_jaguar |
| `Blender_Exports/MiniBosses/03_Jungle/jungle_tribal_warlord.fbx` | Tribal Warlord | Biped | 10 tall | 2044 | ServerStorage.Enemies.jungle_tribal_warlord |
| `Blender_Exports/MiniBosses/04_Tundra/tundra_frost_wolf_alpha.fbx` | Frost Wolf Alpha | Quadruped | 10 tall | 1726 | ServerStorage.Enemies.tundra_frost_wolf_alpha |
| `Blender_Exports/MiniBosses/04_Tundra/tundra_ice_knight_captain.fbx` | Ice Knight Captain | Biped | 10 tall | 1680 | ServerStorage.Enemies.tundra_ice_knight_captain |
| `Blender_Exports/Bosses/01_Plains/plains_golem.fbx` | Golem | Golem | 18 tall | 5012 | ServerStorage.Bosses.plains_golem |
| `Blender_Exports/Bosses/02_Desert/desert_cursed_pharaoh.fbx` | Cursed Pharaoh | BossBiped | 17 tall | 3768 | ServerStorage.Bosses.desert_cursed_pharaoh |
| `Blender_Exports/Bosses/03_Jungle/jungle_ancestral_gorilla.fbx` | Ancestral Gorilla | Gorilla | 18 tall | 3164 | ServerStorage.Bosses.jungle_ancestral_gorilla |
| `Blender_Exports/Bosses/04_Tundra/tundra_frost_king.fbx` | Frost King | BossBiped | 18 tall | 3078 | ServerStorage.Bosses.tundra_frost_king |
| `Blender_Exports/Pets/01_Plains/plains_pet1.fbx` | Boar Piglet | Quadruped | 0.95 tall | 580 | ReplicatedStorage.Assets.Pets.plains_pet1 |
| `Blender_Exports/Pets/01_Plains/plains_pet2.fbx` | Wolf Pup | Quadruped | 0.95 tall | 560 | ReplicatedStorage.Assets.Pets.plains_pet2 |
| `Blender_Exports/Pets/01_Plains/plains_pet3.fbx` | Baby Bear | Quadruped | 1.045 tall | 544 | ReplicatedStorage.Assets.Pets.plains_pet3 |
| `Blender_Exports/Pets/01_Plains/plains_pet4.fbx` | Seagull Chick | Bird | 0.855 tall | 400 | ReplicatedStorage.Assets.Pets.plains_pet4 |
| `Blender_Exports/Pets/01_Plains/plains_pet5.fbx` | Crab Buddy | Crustacean | 0.855 tall | 432 | ReplicatedStorage.Assets.Pets.plains_pet5 |
| `Blender_Exports/Pets/01_Plains/plains_pet6.fbx` | Spider Hatchling | Arachnid | 0.8075 tall | 540 | ReplicatedStorage.Assets.Pets.plains_pet6 |
| `Blender_Exports/Pets/02_Desert/desert_pet1.fbx` | Jackal Pup | Quadruped | 0.95 tall | 560 | ReplicatedStorage.Assets.Pets.desert_pet1 |
| `Blender_Exports/Pets/02_Desert/desert_pet2.fbx` | Scorpion Cub | Arachnid | 0.9025 tall | 462 | ReplicatedStorage.Assets.Pets.desert_pet2 |
| `Blender_Exports/Pets/02_Desert/desert_pet3.fbx` | Baby Croc | Quadruped | 0.95 tall | 548 | ReplicatedStorage.Assets.Pets.desert_pet3 |
| `Blender_Exports/Pets/02_Desert/desert_pet4.fbx` | Desert Eaglet | Bird | 0.95 tall | 400 | ReplicatedStorage.Assets.Pets.desert_pet4 |
| `Blender_Exports/Pets/02_Desert/desert_pet5.fbx` | Scarab Beetle | Insect | 0.8075 tall | 388 | ReplicatedStorage.Assets.Pets.desert_pet5 |
| `Blender_Exports/Pets/02_Desert/desert_pet6.fbx` | Sand Snake | Serpent | 0.95 tall | 528 | ReplicatedStorage.Assets.Pets.desert_pet6 |
| `Blender_Exports/Pets/03_Jungle/jungle_pet1.fbx` | Monkey | Biped | 0.95 tall | 504 | ReplicatedStorage.Assets.Pets.jungle_pet1 |
| `Blender_Exports/Pets/03_Jungle/jungle_pet2.fbx` | Jaguar Cub | Quadruped | 0.95 tall | 656 | ReplicatedStorage.Assets.Pets.jungle_pet2 |
| `Blender_Exports/Pets/03_Jungle/jungle_pet3.fbx` | Frog Prince | Amphibian | 0.855 tall | 416 | ReplicatedStorage.Assets.Pets.jungle_pet3 |
| `Blender_Exports/Pets/03_Jungle/jungle_pet4.fbx` | Piranha Pal | Fish | 0.855 tall | 292 | ReplicatedStorage.Assets.Pets.jungle_pet4 |
| `Blender_Exports/Pets/03_Jungle/jungle_pet5.fbx` | Green Viper | Serpent | 0.95 tall | 528 | ReplicatedStorage.Assets.Pets.jungle_pet5 |
| `Blender_Exports/Pets/03_Jungle/jungle_pet6.fbx` | Totem Spirit | Biped | 0.95 tall | 504 | ReplicatedStorage.Assets.Pets.jungle_pet6 |
| `Blender_Exports/Pets/04_Tundra/tundra_pet1.fbx` | Snow Owl | Bird | 0.95 tall | 408 | ReplicatedStorage.Assets.Pets.tundra_pet1 |
| `Blender_Exports/Pets/04_Tundra/tundra_pet2.fbx` | Arctic Fox | Quadruped | 0.95 tall | 560 | ReplicatedStorage.Assets.Pets.tundra_pet2 |
| `Blender_Exports/Pets/04_Tundra/tundra_pet3.fbx` | Polar Bear Cub | Quadruped | 1.045 tall | 544 | ReplicatedStorage.Assets.Pets.tundra_pet3 |
| `Blender_Exports/Pets/04_Tundra/tundra_pet4.fbx` | Baby Yeti | Biped | 1.045 tall | 444 | ReplicatedStorage.Assets.Pets.tundra_pet4 |
| `Blender_Exports/Pets/04_Tundra/tundra_pet5.fbx` | Ice Eaglet | Bird | 0.95 tall | 406 | ReplicatedStorage.Assets.Pets.tundra_pet5 |
| `Blender_Exports/Pets/04_Tundra/tundra_pet6.fbx` | White Wolf Pup | Quadruped | 0.95 tall | 560 | ReplicatedStorage.Assets.Pets.tundra_pet6 |
| `Blender_Exports/NPC/Hub/npc_blacksmith.fbx` | Blacksmith | Biped | 6 tall | 1592 | ServerStorage.NPCs.npc_blacksmith |
| `Blender_Exports/NPC/Hub/npc_egg_keeper.fbx` | Egg Keeper | Biped | 6 tall | 1920 | ServerStorage.NPCs.npc_egg_keeper |
| `Blender_Exports/NPC/Hub/npc_gem_merchant.fbx` | Gem Merchant | Biped | 6 tall | 1712 | ServerStorage.NPCs.npc_gem_merchant |
| `Blender_Exports/NPC/Hub/npc_guide.fbx` | Guide | Biped | 6 tall | 1600 | ServerStorage.NPCs.npc_guide |
| `Blender_Exports/NPC/Hub/npc_priest.fbx` | Priest | Biped | 6 tall | 1820 | ServerStorage.NPCs.npc_priest |
| `Blender_Exports/NPC/Hub/npc_quartermaster.fbx` | Quartermaster | Biped | 6 tall | 1676 | ServerStorage.NPCs.npc_quartermaster |
| `Blender_Exports/NPC/Hub/npc_trainer.fbx` | Trainer | Biped | 6 tall | 1840 | ServerStorage.NPCs.npc_trainer |
| `Blender_Exports/NPC/Hub/npc_trophy_merchant.fbx` | Trophy Merchant | Biped | 6 tall | 1898 | ServerStorage.NPCs.npc_trophy_merchant |

Total: 88 files, 76,870 triangles.
