# HANDOFF - Fight Your Destiny (for the next Claude)

Read this first, then `DESIGN.md` (the contract; it wins over older docs where they differ),
then the design documents in `docs/`:
- `docs/enemy_database.txt` - stats, rewards, loot and diamonds (source of truth for numbers)
- `docs/zone_design_document.txt` - look and layout of every zone
- `docs/boss_patterns_document.txt` - boss attack patterns, tools and workflow
- `docs/weapon_system_document.txt` - 96 weapons, rarity, zone damage scaling, zone boost, shop

## 1. What this is

Roblox game **"Fight Your Destiny"** (placeId `106749213017380`, universeId `10769126910`):
an NPC combat game with a zone-progression and rebirth loop.

* **Core loop:** kill NPCs -> earn coins -> pay coins to unlock the next sub-zone ->
  reach the boss room -> beat 2 mini-bosses and the boss -> **Rebirth** -> replay the zone
  (stronger, with bonuses) -> the next zone unlocks.
* **12 zones, 4 sub-zones each** (48 sub-zones). Sub-zone 4 is always the boss room.
  Order of progression: Plains, Desert, Jungle, Tundra, Cursed Swamp, Volcano, Hell,
  Heaven, Realm of the Dead, Abyss, Mechanical City, The Void.
  The original four zones (Plains, Hell, Heaven, Void) are inspired by Minecraft's
  Overworld, Nether, Aether and End.
* **Enemies:** 132 normal enemies (3 per sub-zone, 2 in the boss room), 24 mini-bosses
  (2 per boss room), 12 bosses. Each enemy has HP, damage and a base coin reward.
* **Boss fights:** every boss has at least 3 attack patterns with a telegraph of 1 second or
  more, plus an enrage phase at 50% HP. The Void Dragon has 4 patterns.
* **Currencies:**
  * **Coins** - dropped by every enemy; values grow x10 per zone.
  * **Diamonds** - premium currency; dropped ONLY by mini-bosses (15%) and bosses (40%),
    amounts grow slowly (+z per zone), and sold for Robux (Developer Products).
* **Loot:** each enemy has one possible loot item (corpse, egg, weapon, armor, material,
  trophy). Drop chance: 2% normal enemies (identical for all), 4% mini-bosses, 6% bosses.
  8 rarity tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Secret.
  Stronger enemy = rarer loot (see section 1 of `enemy_database.txt` for the exact rule).
* **Weapons:** 8 categories (Sword, Spear, Heavy, Dagger, Gauntlet, Ranged, Magic, Whip &
  Chain) x 12 zones = 96 weapons. Each weapon belongs to a zone; damage = zone base x category x
  rarity, plus a Zone Boost when used in its home zone. Bought in the shop with a RANDOM rarity.
* **Rebirth (superseded - see DESIGN.md section 4):** resets Gold, weapons, armor, stats, eggs
  and pets, keeps diamonds and boss keys (old text follows),
  and gives a permanent bonus (for example more coins). Unlocking the next zone depends
  on the number of rebirths.
* **Monetization (planned):** diamond packs via Robux, game passes (double coins, exclusive
  weapon), temporary boosts.

The owner wants: a clean, readable game with satisfying combat, strong feedback (particles,
screen shake, damage numbers), and long-term progression. The owner works in French but
design documents are in English.

**Repo:** https://github.com/Miieski/Fight-Your-Destiny (branch `main`). Git holds the
scripts and docs only. The world and assets live in the Roblox place itself.

## 2. Repo layout

```
src/ReplicatedStorage/GameSystem/            shared config (zones, enemies, bosses, loot) + profile data
src/ServerScriptService/GameSystem/          combat, enemy spawner, bosses, economy, rebirth, DataStore
src/StarterPlayer/StarterPlayerScripts/GameClient/   HUD, VFX, shop/inventory UI, boss health bar
docs/                                        design documents (see above)
backup/                                      place backups (*.rbxl is gitignored)
default.project.json                         Rojo mapping (only the three src branches)
```

Suggested module layout (create as needed):
```
GameSystem/Config/ZonesConfig.luau       zones, sub-zones, unlock prices, boss names
GameSystem/Config/EnemyConfig.luau       HP, DMG, coins, loot, drop chances
GameSystem/Config/BossConfig.luau        patterns, cooldowns, enrage rules
GameSystem/Config/LootConfig.luau        rarity tiers, item list, diamond drops
GameSystem/Config/Products.luau          Developer Product / game pass IDs (0 = hidden)
Server/Services/*.luau                   one service per system (auto-loaded)
Server/Bosses/BossBase.luau              shared boss state machine
Server/Bosses/<BossName>.luau            patterns for each boss
Client/Controllers/*.luau                VFX, UI, camera shake, damage numbers
```

Conventions: Luau, tabs, `--!strict` where practical, `task.*` only (never `wait`), all
gameplay logic on the **server**, the client only shows visuals and sends requests.
Keep ALL numbers in config modules, never hard-coded in gameplay scripts. All remotes go
through one shared `Net` module. The server validates every request (distance, cooldown,
ownership, price). Never trust the client for damage, money, or drops.

## 3. How to work on it (tooling - read carefully)

**Only the scripts are in git.** The Workspace map, terrain, lighting and the enemy/boss
models in `ServerStorage` live **only in the place file**. The owner saves from Studio
(Ctrl+S). Ask them to save before anything risky.

1. **Rojo:** run `rojo serve` in the repo folder, then Studio -> Plugins -> Rojo -> Connect.
   Rojo pushes disk -> Studio and overwrites what it maps. There is **no pull**: a change
   made directly in Studio must be copied back into `src/` by hand, or it is lost on the
   next connect. Workspace, Lighting, Terrain and ServerStorage are NOT mapped.
2. **Backups:** before big changes, save `File -> Save to File As -> backup/FightYourDestiny_<date>.rbxl`.
   These are gitignored (large); copy them to a cloud drive or external disk.
3. **Toolbox assets:** free models can contain hidden scripts (including purchase prompts and
   backdoors). Right after inserting any Toolbox asset:
   * delete EVERY script, remote, value and GUI inside it unless you wrote it,
   * check there is no `require(<number>)` or obfuscated code,
   * anchor static props (many Toolbox models arrive unanchored).
4. **Commits:** commit after every meaningful step with a short message
   (`git add -A && git commit -m "..." && git push`).
5. **Player data** lives in Roblox DataStores, not in git. Studio needs
   Game Settings -> Security -> **Enable Studio Access to API Services** to test DataStores.
   Use a session lock or a proven library pattern, save on leave and on a timer, and use
   `UpdateAsync` rather than `SetAsync` for anything important.

### Playtesting
* Test with **1 player and with 2-4 players** (use Test -> Clients and Servers). Boss rooms
  are multiplayer: each pattern must stay fair with several targets.
* Add a hidden **admin/debug command set** (owner only, check UserId on the server) to speed
  testing: set coins/diamonds, set rebirths, unlock zone N, teleport to a boss room, kill the
  current enemy, force a boss pattern.
* Studio has no real DataStore data unless API access is on; do not assume saves work in Studio
  without testing them.

## 4. Sub-agents (the owner explicitly wants them used)

Work boss by boss and system by system with sub-agents:

* One sub-agent per boss, all using the same brief (`docs/boss_patterns_document.txt` +
  `docs/enemy_database.txt` + the shared `BossBase` module). Each delivers its boss module, a
  list of VFX and animation names it expects, and test notes.
* A separate **reviewer** sub-agent checks every module against the rules (telegraph >= 1s,
  damage and cooldowns server-side, no hard-coded numbers, no unsafe remotes).
* Recommended lessons:
  * Run at most ~2 agents at the same time; too many parallel agents can hit usage limits and
    stop mid-task. Resuming an existing agent keeps its context and is cheaper than a new one.
  * Only one agent should control Studio at a time (Edit-mode actions fail while Play is running).
  * Give each agent a strict list of files/folders it owns and require a final report with the
    exact APIs it created.
  * Run a review pass and a playtest pass after each feature wave; verify visually yourself.
* Create a `docs/AGENT_BRIEF.md` with the rules every sub-agent must follow before launching them.

## 5. Current state (as of this handoff)

**Design is done; implementation has not started** (update this section as soon as code exists).

Done:
* Zone list, sub-zones, bosses and progression order.
* Full stat tables for all enemies, mini-bosses and bosses (`docs/enemy_database.txt`),
  including loot rarity rules and the diamond system.
* Zone look-and-feel document for all 12 zones (`docs/zone_design_document.txt`).
* Boss pattern document with tools and workflow (`docs/boss_patterns_document.txt`).
* GitHub README, Rojo project file and `.gitignore`.

Not done yet (suggested order):
1. **Phase 0-1 systems:** Rojo repo set up, `Net` module, DataStore profile (coins, diamonds,
   zone progress, rebirths, inventory), coin HUD.
2. **Combat:** weapon + damage + cooldown, enemy base class (HP, simple AI, death, rewards),
   enemy spawner with respawn, damage numbers.
3. **Zone progression:** sub-zone gates with coin prices, teleports, boss room entry/lock.
4. **Plains, fully playable:** map, 2-3 enemy types per sub-zone, 2 mini-bosses, Golem boss.
5. **Rebirth loop:** Rebirth button, bonuses, unlocking Desert, then test the full loop with friends.
6. **Loot and diamonds:** loot drops, inventory, diamond drops, Robux diamond shop.
7. **Remaining zones** one by one (Desert and Jungle first, then publish a first version).
8. **Balance pass:** pacing target of about 10-15 minutes per sub-zone and about 1 hour per zone.

### Known open questions / risks
* Numbers grow x10 per zone, so the late game reaches 10^15 (use `Format` helpers with
  K/M/B/T/Qa suffixes). Lua numbers are doubles (exact to about 9e15), so very late values may
  need a big-number approach later; consider capping or rebalancing growth.
* The player's HP and weapon damage must follow the same curve as enemy HP/damage, otherwise
  late zones are impossible. This still has to be designed (levels, weapon tiers, rebirth bonus).
* Abyss zone: swimming mechanics are complex; consider a dry "underwater dome" look instead.
* Sub-zone unlock prices are not defined yet (suggestion: about x2.5 per sub-zone).
* Rebirth bonus values and the diamond shop uses (eggs, pets, boosts, skins) are not defined.
* Diamond pack prices in `enemy_database.txt` are placeholders.

### Manual items for the owner (keep collecting, give at the very end)
* Save the place (Ctrl+S); map/assets live only in the place file.
* Game Settings -> Security -> enable **API Services** for Studio DataStore testing.
* Create the game passes and Developer Products, then put their IDs in `Config/Products.luau`.
* Set the admin UserId(s) in the admin config (owner account only).
* Copy `.rbxl` backups to a cloud drive or external disk.
* Remove any dev-only tools or test commands before publishing.
* Check that all Toolbox assets used are cleaned of scripts and are properly licensed.

## 6. Style of the owner

French-speaking; asks for documents and plans in English, and for explanations in French.
Direct and practical: wants step-by-step instructions and finished files rather than long theory.
Likes big, juicy combat feedback. Expects things to be tested before being called done. Keep
status updates short and concrete, and give the manual steps they must do themselves in a clear
list.
