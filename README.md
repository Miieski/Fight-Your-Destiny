
# Fight-Your-Destiny!# 

Source for the Roblox place **Fight Your Destiny** (placeId `106749213017380`).

NPC combat game: kill NPCs to earn coins, unlock the next sub-zone, reach the boss room, beat the boss, then **Rebirth** to unlock the next zone. 12 zones, 4 sub-zones each, 12 bosses, 24 mini-bosses.

Extracted from Studio on `<YYYY-MM-DD>`. Studio was the only authoritative copy before this repo existed.

## Layout

```
src/ReplicatedStorage/GameSystem/            shared config (zones, enemies, bosses, loot) + profile data
src/ServerScriptService/GameSystem/          combat, enemy spawner, bosses, economy, rebirth, world logic
src/StarterPlayer/StarterPlayerScripts/GameClient/   HUD, VFX, shop/inventory UI, boss health bar
docs/                                        design documents (enemies, zones, boss patterns)
```

`Bootstrap.server.luau` and `Main.client.luau` carry Rojo's `.server` / `.client` suffixes; everything else is a ModuleScript.

## Rojo

```
rojo serve
```

Then Studio -> Plugins -> Rojo -> Connect.

`default.project.json` maps only those three branches. Workspace, Lighting, Terrain and the ServerStorage models are **not** mapped, so syncing never touches the authored scene or the enemy/boss models.

Rojo pushes disk -> Studio and overwrites what it maps. There is no pull: a change made in Studio must be copied back here by hand, or it is lost on the next connect.

## Design documents

| File | Content |
|---|---|
| `docs/enemy_database.txt` | HP, damage, coin rewards, loot and diamond drops for every enemy, mini-boss and boss |
| `docs/zone_design_document.txt` | Look and layout of the 12 zones and 48 sub-zones |
| `docs/boss_patterns_document.txt` | Attack patterns, telegraphs and VFX notes for the 12 bosses |

The numbers in `enemy_database.txt` are the source of truth for the config modules in `src/ReplicatedStorage/GameSystem/`.

## World overview

The map is split into 12 zones, played in this order. Each zone has 4 sub-zones; sub-zone 4 is the boss room (2 normal enemies, 2 mini-bosses, 1 boss).

| # | Zone | Sub-zones | Boss |
|---|---|---|---|
| 1 | Plains | Plains, Beach, Forest, Cave | Golem |
| 2 | Desert | Dunes, Oasis, Canyon, Pyramid | Cursed Pharaoh |
| 3 | Jungle | Jungle Edge, River, Lost Temple, Temple Heart | Ancestral Gorilla |
| 4 | Tundra | Snowy Plains, Frozen Lake, Mountain, Ice Citadel | Frost King |
| 5 | Cursed Swamp | Marsh, Dead Forest, Witch Village, Giant Cauldron | Swamp Witch |
| 6 | Volcano | Volcano Foot, Magma Mine, Lava River, Crater | Magma Titan |
| 7 | Hell | Hellish Plains, Hell City, Castle Entrance, Throne Room | Supreme Demon |
| 8 | Heaven | Sky Island, Cloud Bridge, Castle Entrance, Throne Room | Supreme Angel |
| 9 | Realm of the Dead | Graveyard, Catacombs, Haunted Cathedral, Royal Sarcophagus Room | Lich King |
| 10 | Abyss | Coral Reef, Shipwreck, Abyssal Trench, Sunken Palace | Leviathan |
| 11 | Mechanical City | Abandoned Factory, Industrial Sewers, Control Center, Reactor Core | Colossal Robot |
| 12 | The Void | Void Island, Crystal Forest, Voyagers' City, Heart of the Void | Void Dragon |

Progression: kill NPCs for coins, pay coins to open the next sub-zone, beat the boss, then Rebirth. After a Rebirth the zone must be replayed and the next zone unlocks.

Currencies: **Coins** (dropped by every enemy) and **Diamonds** (dropped only by mini-bosses and bosses, also sold for Robux). Enemies can also drop loot (corpses, weapons, armor, eggs, materials, trophies) with 8 rarity tiers, from Common to Secret.

Totals: 132 normal enemies, 24 mini-bosses, 12 bosses.

### Workspace structure in Studio

Fill this in with the real structure of the place:

```
Workspace/
  Zones/
    <Zone name>/
      <Sub-zone name>/        enemy spawn points, gate, decor
  Hub/                        shop, rebirth altar, zone portals
ServerStorage/
  Enemies/                    NPC models
  Bosses/                     boss + mini-boss models
  Items/                      loot and weapon models
  MapAssets/                  reusable map pieces
```

## What this repo does not contain

Scripts and docs only. The world itself (Workspace geometry, Terrain, Lighting, `ServerStorage` enemy/boss models, VFX, animations) lives in the place file. Player data (coins, diamonds, rebirths, loot) lives in Roblox DataStores, not in Git. For a full backup, save the place from Studio:

```
File -> Save to File As... -> backup/FightYourDestiny_<date>.rbxl
```

`backup/*.rbxl` and `backup/*.rbxlx` are gitignored. Copy these backups to a cloud drive or an external disk.

## Workflow

1. Edit scripts in VS Code (or any editor) inside `src/`.
2. Run `rojo serve` and connect from Studio to test.
3. Commit small and often: `git add -A && git commit -m "..." && git push`.
4. Before big changes in Studio, save a dated `.rbxl` backup.
