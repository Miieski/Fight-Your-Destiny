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
BackUP_Files/                                place backups (gitignored, kept locally)
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
2. **Backups:** before big changes, save `File -> Save to File As -> BackUP_Files/FightYourDestiny_<date>.rbxl` (see section 3b: backup before ANY change).
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

## 3b. MANDATORY RULES: backup first, GitHub last

1. **Before making ANY change (even a small one), make a backup and put it in the folder
   `BackUP_Files/`** at the root of the project:
   * Place backup: `File -> Save to File As... -> BackUP_Files/FightYourDestiny_<YYYY-MM-DD_HHMM>.rbxl`.
   * If the Studio MCP / SerializationService is available, also serialize the Workspace map and
     the assets into `.rbxm` files in `BackUP_Files/`.
   * Never overwrite an older backup; every backup has its own dated name.
   * If you cannot create the backup yourself, ask the owner to save the place first and
     wait for confirmation before changing anything.
2. **At the end of the work, ALL modifications (scripts, configs, docs) must be committed and
   pushed to GitHub: https://github.com/Miieski/Fight-Your-Destiny (branch `main`).**
   Use short clear commit messages, push, and tell the owner the result.
3. `BackUP_Files/` is gitignored (the files are large), so the backups stay on the owner's
   computer. Remind the owner to copy them to a cloud drive or an external disk.
4. If the backup step or the push fails, say so plainly and do not continue as if it worked.

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

**2026-10-05 (evening): ENEMIES / NPCs / PETS (`docs/enemies_npcs_pets_brief.txt`, zones 1-4) are DONE - rule
changes, Parts A-F, final checks. NEXT STEP: the boss patterns (`docs/boss_patterns_document.txt`).**
Log with every decision and test: `docs/NIGHT_LOG.md` ("Enemies, NPCs, pets task"). Screenshots
`docs/screenshots/enemies_task/`.
* **Rules:** locked zones are black "?" silhouettes everywhere (`UI/Kit/ZoneVisibility`, `PortalController`);
  damage never depends on the zone (`Config/Balance.ZoneBoostEnabled = false` gates every Zone Boost).
* **Combat:** `Config/Combat` (shapes per category), `CombatService` (Attack / Roll / Block, `DamagePlayer`, starter
  weapon), client `CombatController` (aim, swings, shots, roll dash, block bubble, Auto-Attack HUD toggle).
* **Enemies:** `Config/Enemies` (zones 1-4 looks, AI values, loot, trophy value), `EnemyService` (spawning 10 per
  sub-zone, 10 Hz AI, AlignPosition movement, rewards), `LootService` (2/4/6% loot, head trophies, SellTrophy),
  `Lib/EnemyRigs` (part-built placeholders), client `EnemyController` (HP bars, flashes, death) + `AnimPlayer`
  (plays `Config/RigClips` on the Motor6D joints), Inventory > Trophies tab. Admin: spawnEnemy, killAll,
  validateEnemies (vs `DevTools/EnemyDatabase`, generated by `tools/gen_enemy_database.py`), simulateKills,
  dropLoot, giveTrophy, godMode, enemyHit.
* **Boss rooms:** `Config/Bosses` (Patterns = {} hooks), `BossService` (gate E solo / F team, lobby, minis, boss intro,
  HP x (1 + 0.6 (n - 1)), rewards per player with the 5% rule, keys, spectators), `UI/BossRoom`.
* **Models:** 88 creatures in Blender (`Blender/`, pipeline `tools/blender/fyd_creatures.py`, conventions in
  `Blender/README.txt`, manifest `Blender/models_manifest.csv`, FBX + JSON in `Blender_Exports/`, previews and
  lineups in `Previews/`). NOT imported yet: see `Blender_Exports/CREATURES_IMPORT.md` (owner's Bulk Import, then
  `DevTools.EnemyModels.fromImport`).
* **Hub NPCs:** `Config/NPCs`, `NPCService` (placement on the markers, prompts open the windows), client
  `NPCController` (idle, wave within 15 studs, head turn, talk).

**2026-10-05 (afternoon): MENU SYSTEMS (`docs/menu_systems_brief.txt`) are DONE - every part, A to D5.**
Live log with every decision and test: `docs/NIGHT_LOG.md` ("Menu systems task"). Screenshots:
`docs/screenshots/menu_systems/` (portal, Attributes), `pets/`, `armor/`, `menus/` (D1-D5), desktop / phone / tablet.
* **Portal rule:** a hub portal teleports straight to sub-zone 1 (`PortalController` -> Net "UsePortal"); locked
  portals are gray with a lock for that player. Zone Sign setting is off by default.
* **A - Attributes** (Stats button, window "Attributes"): `Config/Attributes`, `Util/Stats.compute` (every derived
  stat, shared by server and UI), `StatsService` (TrainAttributes, RespecAttributes, Max HP / walk speed on the
  Humanoid), `DevTools/StatsTests` (78 checks incl. pets and armor; admin runStatsTests).
* **B - Eggs & pets:** `Config/Pets` (72 species + 4 premium), `Config/PetRarities`, `PetService` (hatch, Hatch All,
  premium eggs, equip / lock / release, Equip Best, auto-sell, `grantPremium`), procedural models built by
  `DevTools/PetModels.buildAll()` into `ReplicatedStorage.Assets.Pets` / `Assets.Eggs` (in the place, not in git),
  `Kit/ModelIcon` (cached 3D icons), `PetFollowController`, `UI/Hatching`, `UI/Pages/PetsPage`. Egg odds checked by
  `DevTools/EggSim` (docs/egg_simulation.txt).
* **C - Armor & Equipment:** `Config/Armor` (36 pieces), `ArmorService`, `Util/ArmorLook` (procedural pieces on R15,
  placeholders for the future Blender armor), `ArmorVisualsController` (Show Armor setting), Inventory tabs Equipment
  (own avatar on a pedestal, slots, picker with arrows, stats) / Weapons / Armor / Pets + Eggs shortcuts / Trophies.
* **D1 Shop > Diamonds:** premium eggs, Weapon Reroll (keep new / old), Gold Boost x2 packs (`BoostService`, HUD
  `UI/BoostTimer`), skins "Coming soon". **D2 Rebirth Shop** (`RebirthShopService`). **D3 Index** (`Config/IndexBook`,
  `IndexService`, rewards per zone and tab; weapons now store their best rarity). **D4 Quests** (`Config/Quests`,
  `Config/Codes`, `RewardService` with ClaimQuest / ClaimDaily / ClaimGift / RedeemCode and
  `RewardService.progress(player, kind, n)` hooks in EnemyService, ZoneService, PetService, ShopService,
  StatsService). **D5 Team** (`TeamService.getTeam(player)` for the boss gate, invites, HUD party list).
* Admin commands added (section 8 of the brief): giveEgg, givePet, giveArmor, giveBoost, discover, simulateEggs,
  simulateQuests, setUpgrade, setPass, progressQuest, addPlaytime, setDaily, resetQuests, clearPets, clearIndex.
* MCP tips added this session: `loadstring(source)` in the Edit command bar is a quick compile check;
  `require` there may return stale cached configs (test in Play instead); mouse x/y for `user_mouse_input` =
  screenshot y - 58 (top-bar inset); if `screen_capture` times out, the display went to sleep (RenderStepped stops).
* NOT done / not testable here: real 2-player team invites, DataStore persistence (API Services off), regeneration /
  boss slayer / loot luck / trophy effects (computed, applied by the future combat step), trophies, skins, Robux
  products (ids are 0), Extra Pet Slots pass purchase (admin setPass simulates it), enemy models for the Index.

**Updated 2026-10-05 (00:40). GAMEPLAY PHASE, STEP 1 (UI) IS DONE AND WAITING FOR THE OWNER'S
REVIEW. Brief: `docs/ui_hud_brief.txt`. Do NOT start CombatService (step 2 of the brief's section 8)
until the owner says go. Screenshots: `docs/screenshots/ui_phase/` (1080p, 720p, phone, tablet).**

**Night 2026-10-05 (owner asleep, `docs/NIGHT_LOG.md` is the live log): Part A of
`docs/ui_redo_teleport_brief.txt` is done - every UI icon is a chunky glossy 3D render.**
* Pipeline: `tools/blender/fyd_icons.py` (template: ortho 3/4 camera, 4 area lights, glossy coat
  materials, post-process 14 px dark outline + soft drop shadow, 512 px PNG) + recipes
  `fyd_icon_recipes.py` / `fyd_icon_recipes2.py`. Template `Blender/Icons/_IconTemplate.blend`,
  sources `Blender/Icons/<Group>/<id>.blend`, renders `Icons/<Group>/<id>.png`, sheets in `Previews/Icons/`.
  Run inside Blender (connector): `sys.path.insert(0, "<project>/tools/blender")`,
  `I.setup_template()`, `I.make_icon(group, id, recipe)`.
* 50 icons uploaded (Studio MCP `upload_image` reads URLs, so `python -m http.server 8765` serves the
  project; batches of 5, bigger batches time out). Ids: `Icons/asset_ids.json` (`tools/icon_ids.py`)
  and `GameClient/UI/Kit/Icons.luau` (`Icons.<Group>.<id>`, `Icons.asset(id)` with aliases for the
  old ids, `Icons.preload()` at startup, `Flat = true` forces the old flat shape).
* Kit: menu tiles = wooden button with a 6 px raised base, big bobbing 3D icon, squash on press,
  bold cream label with a thick stroke; chunkier badges; window close = wood button with the red 3D X;
  touch Roll/Block use the boot/shield icons. Screenshots: `docs/screenshots/ui_redo/`.

**Night 2026-10-05, Part B (teleport menu) is done:**
* Zones button = an `Apart` menu entry with a label, stacked under the Settings gear (PC/tablet) or
  beside it (phone), so the owner's 2 x 4 grid stays intact. Hub portals now open the same window on
  their zone (`Net "OpenWindow"` event) instead of teleporting directly.
* `UI/Pages/ZonesPage.luau`: page 1 = scrollable list (Hub + 12 zones, rows 72 design units = 57 px on
  phones, states here / unlocked / locked with short requirement + lock / coming soon) and a preview
  (big diorama, name, description, boss); page 2 = Back + header + 4 cards (Teleport `go` button,
  locked with gate price, "You are here", boss card with red accent and "Boss Gate" = boss-room
  entrance, never the arena). Fade to black 0.25 s, `PortalEnter` sound, toast with the server message.
* Server: `Net.request("Teleport", zoneId, n)` in ZoneService checks zone unlock
  (`Zones.requirementText`), gate unlock (price), boss arena, combat (damage in the last
  `Zones.TELEPORT.CombatSeconds` = 5 s, tracked from HealthChanged) and cooldown (3 s). Admins skip
  arena/combat/cooldown, NOT the unlocks. Admin commands added: `lockAll`, `unlockZone(zoneId, gates)`;
  `unlockAll` and `setZone` now also open `profile.Zones`.
* Config: `Zones.TELEPORT`, `Zones.NOT_BUILT` (empty: all 12 worlds are built), `Zones.Descriptions`.
* 60 diorama icons (12 zones + 48 sub-zones, recipes `tools/blender/fyd_zone_recipes.py`), ids in
  `Icons.Zones` / `Icons.SubZones`. Tested: unlocked, locked zone, locked gate, bad request, cooldown,
  combat, Hub, Boss Gate, portal open (first build too). Screenshots `docs/screenshots/ui_redo/B*`.

**Night 2026-10-05, Part C (96 weapons in Blender) is DONE: all 8 categories x 12 zones** (details and
fixes per category in `docs/NIGHT_LOG.md`, one row per weapon in `Blender/Weapons/weapons_manifest.csv`).
* Pipeline `tools/blender/fyd_weapons.py`: `make_weapon(category, zone_index, builder)` builds the parts
  (meters, origin = grip, head along +Z), joins, scales to the category length (`LENGTH_STUDS` x 0.28 m),
  triangulates, Smart-UV unwraps, Cycles-bakes color/metalness/roughness (512 px, packed), makes
  `<id>_Main` + optional `<id>_Glow` (emissive parts), renders the icon + 3-angle preview, saves
  `Blender/Weapons/<Cat>/<NN>_<id>.blend`, exports `Blender_Exports/Weapons/<Cat>/<NN>_<id>.fbx`
  (Y up, textures embedded) and updates the manifest. `lineup(category)` makes `Previews/Weapons/<Cat>_lineup.png`.
* Builders: one module per category, `fyd_weapon_swords.py`, `fyd_weapon_spears.py`, `fyd_weapon_heavy.py`,
  `fyd_weapon_daggers.py`, `fyd_weapon_gauntlets.py`, `fyd_weapon_ranged.py`,
  `fyd_weapon_magic.py`, `fyd_weapon_whips.py`
  (`BUILDERS[zone_index - 1]`), shared parts in `fyd_weapon_parts.py`. Convention in `Blender/Weapons/README.txt`.
* Icons uploaded; ids in `Config/Weapons.luau` between `-- ICONS BEGIN` / `-- ICONS END`
  (`Weapons.ById[id].Icon`). `tools/weapon_icon_table.py` prints the table from `Icons/asset_ids.json`.
* Per-type conventions (gauntlet = one right-hand piece, ranged bow/crossbow/gun, whip = handle + rigid lash)
  are in `Blender/Weapons/README.txt`. Lineups: `Previews/Weapons/<Category>_lineup.png`.
* The 96 FBX files are NOT imported in Studio yet (owner: Asset Manager -> Bulk Import, File Dimensions =
  Meters). After import: Tools under `ReplicatedStorage.Assets.Weapons.<WeaponId>` (gameplay step).

**Owner request 2026-10-05 (noon): "Zone Sign" setting (Settings > Display, default on) hides the top-center zone
banner (the Zone Boost badge takes its place; the title card when entering a sub-zone still shows). On PC (no touch
screen) the Zones button is a wide wooden button in the bottom-right corner (`Config/UI` `CornerButton`, menu entry
`PcCorner`); tablets and phones keep the square tile next to the Settings gear (their bottom-right holds the action
buttons). Screenshots `docs/screenshots/ui_redo/E1-E4`.**

**2026-10-05: WEAPON SHOP + CASE OPENING + WEAPONS IN-GAME (docs/weapon_shop_brief.txt) are done** (details,
decisions and tests in `docs/NIGHT_LOG.md`, screenshots `docs/screenshots/weapon_shop/`).
* Configs: `Config/WeaponCategories`, `Config/WeaponRarities` (8 tiers + pity 30/100 + announcements),
  `Config/Weapons` (Id, Name, Category, Zone, ZoneId, Icon, Element; ByCategory; price(zone) = 1000 x 10^(zone-1)),
  `Util/Stats` (zone base x category x rarity), Settings `FastOpen`, Profile `PityLegendary`, Config/UI `WeaponShop`
  and `CaseOpening`.
* Server: `ShopService` (Net "BuyWeapon": checks, Gold, roll with pity, item + Index, save, reply; one opening at a
  time; toast / auto-equip of a first weapon / Mythic+ announcement sent at the reveal via Net "OpeningDone" or a
  timer; full undo + refund on failure; `ShopService.roll` is pure), `WeaponService` (Net "EquipWeapon", Tool with
  Uid/Rarity + rarity light/outline, re-given on respawn). Admin: lockZone, giveWeapon, forceRarity, setPity,
  resetWeapons (+ an Admin panel "Weapons" tab).
* Client: `UI/Pages/WeaponShopPage`, `UI/CaseOpening`, `UI/Pages/InventoryPage`; Kit/Window has a phone layout.
* Tools: 96 PLACEHOLDER Tools in `ReplicatedStorage.Assets.Weapons` until the FBX import; then
  `require(game.ServerStorage.DevTools.WeaponTools).fromImport(folder)` (see Blender/Weapons/README.txt).
  `DevTools.WeaponRollSim` = the 100,000-roll check (`docs/weapon_roll_simulation.txt`).
* NOT done (not in this brief): damage/combat with the weapon, diamond reroll, salvage, weapon lock.

**Owner request 2026-10-05 (morning): the health bar shows the player's avatar headshot instead of the heart**
(`UI/HealthBar.luau` `makePortrait`: `rbxthumb://type=AvatarHeadShot`, round, gold ring, overlapping the panel's
left end like the currency icons). Test players without an account (UserId <= 0) keep the heart.
Screenshots `docs/screenshots/ui_redo/C1_desktop_health_portrait.jpg`, `C2_phone_health_portrait.jpg`.

**Owner decision 2026-10-05: the "Training" menu button and window are now "Stats". The Stats window
will hold the WHOLE RPG system (HP, Attack, Defense, Speed, Crit, Gold Gain, their upgrades and the
derived stats); see DESIGN.md section 3. Step 3 of the brief's plan is therefore "Stats window +
StatsService". For now the Stats window is a shell with an intro line (`Config/UI Windows.Stats`).**

What was built (all in `src/`, mirrored from Studio):
* **Plumbing.** `GameSystem/Net.luau`: one RemoteFunction `Request` and one RemoteEvent `Send`
  dispatched to `Net.handle(action, fn, minInterval)` handlers (per-player rate limit ->
  `false, "Too fast"`; unknown -> `false, "Unknown action"`; handler error -> `false, "Server error"`
  + warn); server -> client events `Net.EVENTS = { "Data", "Notify", "Hit" }` with
  `Net.fire / fireAll / on`. A second copy of Net (command bar) reuses the live remotes.
  `DataService`: profile from `Config/Profile.luau` (DESIGN section 11), session-locked UpdateAsync,
  autosave 90 s, save on leave + BindToClose; without API access it falls back to memory with ONE
  warn. Requests `GetProfile` and `SetSetting(key, value)` (validated by `Config/Settings.validate`).
  Client `State.luau`: `get`, `changed`, `observe`, `waitReady`. `AdminService` handles
  `Net.request("Admin", cmd, ...)` (setGold, addGold, setDiamonds, addDiamonds, notify, setZone,
  unlockAll, equipWeaponFake, equipArmorFake, equipPetFake, clearEquipment, damageSelf, heal, setBadge).
  `RewardService` is a stub (`RedeemCode` -> "Codes are not available yet").
* **New configs:** `Config/Rarities, Weapons (96), Economy, Products, Settings, Profile, Audio, UI`.
* **UI Kit** (`GameClient/UI/Kit/`): Theme (colors, fonts, screen scaling), Panel, Button, IconButton,
  Bar, Slot, Tabs, Slider, Toggle, Badge, Toast, Window, Icons (placeholder shapes; put image ids in
  `Icons.Assets`), Screens.
* **HUD** (`GameClient/UI/`): HealthBar (+ low-HP vignette, hides CoreGui Health/Backpack), Currencies
  (restyled 00:50 on the owner's reference image: Gold and Diamonds bars stacked at the top-right on
  every device, a big round icon over the left end of a dark wooden pill, white amount with a dark
  stroke that shrinks to fit, "+" end cap; Gold is longer (270 vs 200 design units) so "999.99Qa"
  fits; tapping a bar opens the Shop on its tab, Gold -> Weapons, Diamonds -> Diamonds; sizes and
  tabs in `Config/UI` `Currencies`; count-up, pop, and a +/- float left of the bar. On phones the
  Menu button and the admin crown moved under the health bar; screenshots 14-17), ZoneBanner (+ 2 s title card +
  Zone Boost badge "Weapon + n/3 Armor"), Equipment (weapon + 3 pet slots), MenuBar (owner's choice
  01:00, after a reference photo: 8 buttons in a 2-wide x 4-tall grid filled row by row on PC and
  tablets; Settings is `Apart = true` in `Config/UI Menu` and shows as a gear right of the health bar
  (health bar now 270 wide, `Config/UI Hud.Health`); phones keep the Menu pop-up, now the same 2 x 4
  grid, with the gear beside the Menu button; screenshots 18-20. Owner, 01:10: on PC (no touch) the
  tiles are 40% bigger (`MenuGrid.PcTile` 80) and the grid sits at the vertical middle of the left
  edge; screenshots 21-23. Owner, 01:20: tablets centered vertically too (tile size unchanged);
  screenshot 25), Notifier (queue, merge "x2", rarity glow, error shake), Windows (9 shells + Shop "Get
  diamonds" confirm -> GoToHub), Pages/SettingsPage (Audio, Display, Controls, Other), AdminPanel
  (crown button / F2: Money, Teleport, UI Test tabs).
* **Controllers:** SettingsController (applies locally, saves debounced via SetSetting; volumes go to
  the SoundGroups Master > Music/PlayerFX/EnemyFX/UI/Ambient), ControlsController (CAS binds + touch
  Attack/Roll/Block buttons + layout editor), FxController (LowFx, screen shake).

Phone top bar lift (owner, 01:20): in the compact layout the zone banner + Zone Boost badge and the
currency bars move up into the Roblox top bar strip, which is free right of the Roblox buttons
(`Theme.topbarLift(leftX)` reads `GuiService.TopbarInset`; it returns 0 when a piece would reach the
Roblox buttons). ZoneBanner publishes the bottom of its stack as the `TopCenterBottom` attribute on
the HUD root and the toasts stack under it. Finger taps reach the lifted bars (hit-testing checked),
but gamepad selection skips pieces that sit entirely in the strip (the Gold bar on phones), because
they are outside the HUD ScreenGui's bounds. Screenshot 24.

Scaling rule: every ScreenGui comes from `Theme.screen()`; its `Root` is in design units with a
UIScale `s = clamp(safeHeight/660, 0.6, 1.4) * UiScale` (min 0.8 on touch); compact (phone) layout
when the design height is under 520. UITextSizeConstraint sizes are screen pixels, so always create
them with `Theme.limit(label, max, min)` (it rescales them with the UI).

Tested 2026-10-05 in Studio Play (device simulator: HD 1080, HD 720, iPhone 17 Pro and iPad 10th gen,
landscape): no HUD overlaps (checked by code and by eye), touch targets >= 44 px, Format everywhere
(1.23Qa, 2.5B, 12.5K), gold/diamond animations, health bar + vignette with damageSelf, toast queue +
merge, badges, Zone Boost on/off, all 9 window shells, Settings (Master slider -> SoundGroup 0.4 live
and stored on the server; toggles; UI Scale live; layout editor Bigger + Done saved), Get diamonds ->
Hub. Output clean except the expected API Services warnings. NOT tested: persistence across rejoin
(API Services is off in Studio), real touch gestures (dragging the touch buttons; the simulator was
driven with GuiService.SelectedObject + Enter), gamepad.

MCP testing tips learned: `execute_luau` gets FRESH copies of ModuleScripts (State/Window/Notifier
state is not visible from it; read the GUI instances instead, or fire events from the Server
datamodel); `user_mouse_input` x/y are GUI coordinates (top-bar inset excluded) and clicks do not
reach GUI under the touch simulator; `screen_capture` can show a frame a few seconds old.

**Earlier (00:00). THE WORLD IS COMPLETE: Hub + all 12 zones are built, validated and
checked in Play, each with its kit catalog (`docs/ASSET_KIT_*.md`), lighting presets and a boss
arena in `ServerStorage.BossArenas` (12 arenas). Zone 12 (Void) was the last: 11,728 parts + arena
1,578; its arena floor is 8 pie sections (`FloorSections/Section1..8`) over an invisible `SafetyNet`
for the Void Collapse pattern. Next phases per the owner's plan: (1) real enemy and boss models
(Blender -> owner's 3D Importer), (2) full gameplay scripts. Open: owner review, Blender landmarks
for Heaven and zones 9-12, owner's landmark import, sounds never auditioned.**

**Earlier (22:55). Zone 11 (Mechanical City, id `Mechanical`) is built (4,756 parts +
arena 643), validated and checked in Play (all 4 sub-zones + arena readable; sub-zones 2-4 are
light on parts but clean, more dressing optional). The owner changed Claude and GitHub accounts
on 2026-10-04: pushes still go through the Miieski credential (fallback account: KodElse); the
Roblox_Studio MCP had to be re-added to the session. Remaining: zone 12 (Void).
Catalog: `docs/ASSET_KIT_MECHANICAL.md`.**

**Earlier (20:20). Zone 10 (Abyss) is built (10,854 parts + arena 611), validated and
checked in Play (Coral Reef, Abyssal Trench, boss arena: readable; Abyss_2 and Abyss_4 not seen in
Play). It is a DRY underwater zone: players walk, there is no water volume (per the zone doc's tip).
Remaining: Mechanical, then Void. Catalog: `docs/ASSET_KIT_ABYSS.md`.**

**Earlier (19:50). Zone 9 (Realm of the Dead, id `Dead`) is built (9,851 parts + arena
1,062), validated and checked in Play (Graveyard, Ossuary hall, boss arena: readable; Dead_3 and
Dead_4 not seen in Play). The owner said GO for zones 9-12 on 2026-10-04: remaining order is
Abyss, Mechanical, Void, one builder at a time, each followed by a Play check, this file, a backup
and a push. Catalog: `docs/ASSET_KIT_DEAD.md`.**

Earlier (19:10): Hub + zones 1-8 are built, validated (0 FAIL lines, 69,177 zone parts)
and walked in Play. Zones 6-8 (Volcano, Hell, Heaven) were walked on 2026-10-04 evening with the
admin teleport buttons: Volcano 1-3 + arena, Hell 1, 2, 4 + arena, Heaven 1, 3, 4 + arena all read
well in Play (no glare in Heaven, Hell dark but readable). NOT seen in Play: Volcano_4 itself,
Hell_3, Heaven_2. Fix made after the walk: placeholder enemy tints for Hell (bone white) and
Heaven (blue), which blended into their zones. WAITING for the owner's review: do not start
zones 9-12 until they say go. Zones 9-12 (Dead, Abyss,
Mechanical, Void) only have folders and markers and must NOT be started until the owner says go.
The admin panel also has teleport buttons for every zone (sub-zone 1-4 or the boss arena).
`Blender_Exports/` now has 29 FBX (Hub + zones 1-7); the 4 Heaven landmarks are not made yet.**

**Owner's working rules (2026-10-04):** only ONE builder agent at a time; after each finished zone
update this file, take a backup and push to GitHub; never press Play while a builder runs; after
Heaven, walk Volcano / Hell / Heaven in Play, fix, then stop and report.

Earlier note (afternoon of 2026-10-04): World build in progress: Hub + zones 1-5 (Plains, Desert, Jungle,
Tundra, Swamp) are built, validated and walked in Play; zones 6-12 (Volcano ... Void) only have
their folders and markers. Each built zone has its kit catalog (`docs/ASSET_KIT_*.md`), its boss
arena in `ServerStorage.BossArenas`, and lighting presets in `ReplicatedStorage.Assets.Lighting`.
An admin panel (F2 or the ADMIN button; `Config/Admins.luau`) adds/sets Gold and Diamonds and
unlocks all gates. `Blender_Exports/` holds 25 landmark FBX (Hub + zones 1-6) waiting for the
owner's import; the maps use part-built stand-ins (`Decor.Landmark`, attribute `LandmarkName`).
Known gaps: see `docs/QC_REPORT_1.md` (Hub + Plains only; zones 2-5 have had no QC agent pass),
boss-arena fights beyond entry are untested, sounds were never auditioned by ear.**

Earlier note (morning of 2026-10-04): Hub + Plains built and playtested.

Owner decisions (2026-10-03): build the world for all 12 zones first (maps, props, lighting, VFX,
sounds) with ONE placeholder dummy enemy; real enemy and boss models come after the 12 worlds;
the full gameplay scripts come last. Blender work is exported to `Blender_Exports/` and imported
by the owner with Studio's 3D Importer (landmarks first, then enemies and bosses).

In the place now:
* `workspace.Hub` (4,167 parts): spawn, 12 zone portals, 10 stations, 5 leaderboards, AFK zone.
* `workspace.Zones.Plains` (4 sub-zones, about 10,300 parts) and `ServerStorage.BossArenas.Plains`.
  The other 11 zones only have their folders and markers (`Area`, `Entrance`, `Spawns`, ...).
* `ServerStorage.MapAssets`: kit of 104 models (Common, Plains, Hub, Gates) + 33 VFX prefabs;
  `ReplicatedStorage.Assets`: 14 combat VFX and 11 lighting presets (Hub, Plains, Desert, Jungle).
  Catalogs: `docs/ASSET_KIT_A.md`, `docs/VFX_KIT.md`.
* Minimal playable layer (PLACEHOLDER, in `src/`): hub portals, return pads, per-player sub-zone
  gates paid with Gold, location tracking with pushback from locked areas, one dummy enemy tinted
  per zone with real HP/Gold, hold-to-attack test sword, lighting and music switching, Gold HUD,
  solo boss-arena visit. No DataStore (session memory only), no enemy AI, no real weapons.
  Playtested 2026-10-04 on Hub + Plains: portal, combat, Gold, the 3 gates, pushback, cave lighting
  and arena entry all work. NOT tested: mini-boss -> boss sequence, leaving by the arena door,
  death/respawn, mobile, 2+ players.
* `Blender_Exports/`: 13 landmark FBX (Hub + zones 1-3) waiting for the owner's import; see its README.

How the tooling works (read `docs/AGENT_BRIEF.md`):
* Backups: `require(game.ServerStorage.DevTools.Backup)("label")` in Studio, then
  `python tools/collect_backup.py --wait 15` -> verified `.rbxm` files in `BackUP_Files/`.
* Scripts are edited in Studio through the MCP and mirrored to disk with
  `require(game.ServerStorage.DevTools.ExportScripts)()` + `python tools/pull_scripts.py`.
  Rojo (`default.project.json`) pushes the other way: pull before you connect it.
* `ServerStorage.DevTools.BuildKit`: palettes for all 12 zones, faceted-terrain helpers, contract
  validators (`validateHub`, `validateZone`, `validateArena`).
* Sub-agents: at most 2 at a time. Three at once exhausted the owner's usage limit twice.

Earlier status (design phase), kept for reference:

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
* Create the game passes and Developer Products, then put their IDs in `Config/Products.luau`
  (Passes incl. ExtraPetSlots, DiamondPacks, PremiumPets) and wire the receipts to `PetService.grantPremium`.
* The pet / egg models (`ReplicatedStorage.Assets.Pets`, `Assets.Eggs`) only exist in the place: save it. To rebuild
  them: `require(game.ServerStorage.DevTools.PetModels).buildAll()` in the command bar (Edit mode).
* Test teams with 2+ players (Studio Test > Clients and Servers): invite, accept, kick, leader leaving; also a boss
  room with 2-5 players ("Enter with team", HP scaling, spectators, the 5% reward rule).
* Import the 88 creature FBX files: `Blender_Exports/CREATURES_IMPORT.md` (Bulk Import in meters, then
  `require(game.ServerStorage.DevTools.EnemyModels).fromImport(folder)`), then save the place.
* Codes live in `Config/Codes.luau` (WELCOME, DESTINY, BOSSKEY); add or remove codes there.
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
