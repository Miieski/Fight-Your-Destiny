# Pets V2 - plan (owner 2026-10-12: "draw inspiration from Steal an Egg - pets, textures, animations")

Owner's picks: redo all pet models, pet animations, mutations & sizes, new species list.
Reference: the Roblox game **Steal an Egg** (July 2026): animal + fantasy pets per biome (Forest, Lake, Desert,
Jungle, Snow, Volcano, Abyss Ocean, Prehistoric, Cosmic...), smooth cartoon look, mutations (Silver, Golden,
Rainbow...) and sizes that raise a pet's value. Inspiration only: every model is made new, nothing is copied from it.
Meme / "brainrot" characters of that game are left out (they do not fit a fantasy fighting game).

## 1. Models - how

* **Studio AI mesh generation** (Studio MCP `generate_mesh`): a textured cartoon mesh made from a text prompt,
  split into named pieces (head, body, tail, legs / wings / fins). Test: `docs/screenshots/pets_v2/test_fox_ai_mesh.jpg`
  (2 baby foxes, 7 pieces each, ~3-4 min per pet). The meshes are saved as assets on the Roblox account logged in
  to Studio, so they work in game with **no manual import**.
* A DevTools script turns each one into a pet rig: invisible root, Motor6D joints from the piece names, scale.
  Result in `ReplicatedStorage.Assets.Pets.<id>` (same ids as today, so owned pets keep working).
* The 24 Blender pets of 2026-10-05 were never imported (Studio still uses the part-built pets); they are replaced.
* Also new: the 12 zone eggs, in the same style.

## 2. Species (6 per zone, same ids and stat roles as today; rarity still comes from the egg)

| Zone (SaE biome) | Fortune (Gold, HP) | Hunter (Atk, Speed) | Guardian (HP, Def) | Berserker (Atk, Def) | Scout (Speed, Gold) | Lucky (Atk, Gold) |
|---|---|---|---|---|---|---|
| 1 Plains (Forest) | Puppy | Fox Kit | Bear Cub | Boar Piglet | Raccoon | Owl |
| 2 Desert | Fennec Fox | Scorpion | Baby Camel | Sand Snake | Jerboa | Royal Sphinx |
| 3 Jungle | Monkey | Tiger Cub | Baby Gorilla | Crocodile | Toucan | Chameleon |
| 4 Tundra (Snow) | Penguin | Sabertooth Cub | Polar Bear Cub | Baby Mammoth | Snow Hare | Baby Yeti |
| 5 Swamp (Lake) | Duckling | Frog | Turtle | Catfish | Firefly | Axolotl |
| 6 Volcano (+Prehistoric) | Lava Frog | Lava Gecko | Baby Triceratops | Baby T-Rex | Pterodactyl | Phoenix Chick |
| 7 Hell | Imp | Hellhound Pup | Gargoyle | Flaming Bull | Fire Bat | Baby Cerberus |
| 8 Heaven | Halo Bunny | Baby Griffin | Cloud Lamb | Pegasus Foal | Swan | Unicorn Foal |
| 9 Dead | Little Ghost | Bone Pup | Mummy Cat | Zombie Bear | Raven | Spectral Stag |
| 10 Abyss (Abyss Ocean) | Clownfish | Swordfish | Pufferfish | Baby Shark | Baby Orca | Baby Kraken |
| 11 Mechanical | Robo Pup | Clockwork Spider | Steam Golem | Mecha Rex | Mini Drone | Gear Cat |
| 12 Void (Cosmic) | Galaxy Cat | Void Stalker | Cosmic Gorilla | Cosmic Gecko | Nebula Jellyfish | Baby Void Dragon |

Premium (Robux, kept on Rebirth): Golden Dragonling, Rainbow Phoenix, Diamond Golem, Celestial Kitsune (restyled).

## 3. Mutations and sizes (new, rolled at every hatch, on top of the rarity)

| Mutation | Chance | Stats | Look |
|---|---|---|---|
| none | 87% | x1 | normal |
| Silver | 8% | x1.2 | silver metal tint, small sparkles |
| Golden | 4% | x1.5 | gold tint, shining glints |
| Rainbow | 0.9% | x2 | colors cycling, rainbow sparkles |
| Celestial | 0.1% | x3 | glowing, aura and stars |

| Size | Chance | Stats | Model |
|---|---|---|---|
| Normal | 90% | x1 | x1 |
| Big | 9% | x1.25 | x1.35 |
| Huge | 1% | x1.6 | x1.8 |

Both multiply the pet's two main stats and its bonus (and Equip Best, release value). Pets owned today = no
mutation, Normal size. Shown on the hatch reveal ("GOLDEN!", "HUGE!"), pet cards, details, Index.

## 4. Animations (code, no animation uploads)

* Walkers: walk cycle (legs swing with speed), body bounce, head bob, tail wag; idle breathing, looking around.
* Flyers: wing flaps, hovering, leaning into turns. Swimmers: floating, tail and fin waves. Blobs / ghosts: squash
  and stretch.
* Happy jump when the owner kills an enemy.
* Hatching: stronger egg shake, cracks, burst, the pet spins in, mutation / size callout.

## 5. Order of work

1. Code: species names, mutations & sizes (server + UI), rig builder + animation system (tested on the test fox).
2. Models zone by zone (6 pets + egg), backup + push after each zone; report after zone 1 for the owner's look.
3. Premium pets, final checks, screenshots, docs.
