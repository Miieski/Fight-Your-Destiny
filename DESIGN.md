# FIGHT YOUR DESTINY - Design Contract (v1)

This file is the contract every module is written against. If it conflicts with an
older document in `docs/`, **this file wins** (see section 15 for the list of changes).
If your code needs something that is not here, add it to "Open questions" (section 16)
instead of inventing a parallel convention.

## 0. Pillars

* **Core loop:** kill NPCs in a sub-zone -> earn Gold -> upgrade stats, buy weapons ->
  pay Gold to open the next sub-zone -> reach the boss room -> beat the boss (coop, up to
  5 players) -> earn the boss key -> **Rebirth** -> redo the zone with bonuses -> the next
  zone opens.
* **12 zones x 4 sub-zones.** Sub-zone 4 is the boss room (2 normal enemies + 2 mini-bosses
  + the boss, see `docs/enemy_database.txt`).
* **Combat must feel good.** Hit sparks, damage numbers, short screen shake, readable boss
  telegraphs, roll and block that actually save you.
* **Mobile first.** Every feature must be playable with touch controls. If it does not work
  on a phone, it is not done.
* **Server authoritative.** Damage, drops, prices, rolls and rewards are decided on the
  server. The client only shows things and sends requests.
* **Flawless, not complex.** Simple systems done properly beat clever systems done 90%.
* **Everyone can play.** All ages, bright and readable, no gore.

## 1. Art direction

### World (low-poly)
* **Style:** low-poly, flat-shaded faceted shapes (trees, rocks, mountains, houses), clean
  silhouettes, minimal textures. Use `Material = SmoothPlastic` or `Plastic` with solid
  colors; avoid noisy PBR textures. Terrain can be smooth with bright flat colors.
* **Mood:** colorful, **heroic fantasy**. Bright saturated greens, cyan water, warm wood,
  blue skies with soft clouds. Each zone has its own palette and lighting (see
  `docs/zone_design_document.txt`).
* **Reference (provided by the owner):** the low-poly forest/lake scene (faceted pine trees,
  brown faceted mountains, cyan pond, wooden dock) and the low-poly island (colorful flags,
  mushrooms, wooden piers, blue faceted rocks) -> the look of Plains and the friendly zones.
* **Dark zones (Hell, Realm of the Dead, Void):** dark red/purple low-poly with fog, embers
  and floating tiled platforms with carved borders (reference: the two dark red screenshots).
  Keep it readable: enemies and telegraphs must stay visible against the dark background
  (bright rim colors, glowing red/white telegraph zones).
* **Lighting:** `Lighting.Technology = Future` when possible, soft bloom, color-corrected,
  per-zone `Atmosphere`. Never washed out, never pitch black.
* **Characters/NPCs:** chunky low-poly models with a clear silhouette and a distinct color per
  enemy type. Reuse a base mesh and change color/scale/accessories per zone.

### UI (fantasy wood)
* **Reference:** the wooden RPG UI kit (dark brown wood panels, ornate gold/silver borders,
  gem corners in ruby/sapphire/amethyst, red HP bar, blue bar, square item slots, gold primary
  buttons and gray metal secondary buttons).
* **Panels:** dark brown wood fill (`#4A3020` -> `#33200F` vertical gradient), 3-5 px border in
  gold (`#E8B44A` -> `#B07A22` gradient) with small gem accents in the corners, UICorner
  small (4-8 px, slightly squared, not bubbly), inner dark inset area for content.
* **Buttons:** primary = gold bevel with dark brown text; secondary = steel gray; danger = red
  with gold border; disabled = desaturated. 3D feel: darker base frame 3-4 px below the face,
  press = face moves down 2 px + scale 0.96 (tween 0.08 s).
* **Bars:** HP red (`#D93B3B`), segmented look; boss HP bar wide at the top with the boss name
  in a wooden banner; damage taken shows a lighter trailing segment.
* **Item slots:** square frames with a rarity-colored border; rarity glow for Epic and above.
* **Rarity colors:** Common `#C4CEDA`, Uncommon `#5BDC6E`, Rare `#3C96FF`, Epic `#AA50FF`,
  Legendary `#FFAA1E`, Mythic `#FF3C6E`, Divine = animated white/cyan/pink/gold gradient,
  Secret = animated rainbow with a dark core.
* **Currency colors:** Gold `#FFC93C`, Diamonds `#5FD4FF`.
* **Fonts (proposal, verify availability in Studio):** titles and buttons `Enum.Font.Fantasy`
  (or a gothic/serif fantasy font such as GrenzeGotisch if available in the font picker);
  body and numbers `Enum.Font.GothamMedium` or `Enum.Font.BuilderSans`. Always use a dark
  `UIStroke` (1.5-2 px) on text over bright backgrounds.
* **Smooth (vector-like) UI art, not pixel art.** The kit in the reference is pixel-art; we
  use its layout and ornament language but with smooth edges so it stays crisp on every
  screen size. (Assumption - see Open questions.)
* **Mobile rules:** all UI scales with a `UIScale` driven by the viewport; min touch target
  44 x 44 px; respect the safe area (`GuiService:GetGuiInset()` and notches); windows use at
  most 90% of the screen on phones; no hover-only information.
* **Windows:** open with a quick pop (scale 0.9 -> 1, Back Out 0.2 s) over a dimmed backdrop;
  a close (X) button in the top-right corner.

### Audio
Music per zone (calm in the hub and early zones, intense for bosses); short, punchy SFX for
hits, rolls, blocks, UI clicks, drops, rarity reveals. All sounds are played by name through a
shared `Sfx` module (names listed in section 10).

## 2. Controls & combat

### Camera
Third person by default, freely adjustable by the player: zoom from 8 to 40 studs, Shift-Lock
toggle on PC, free drag on mobile. A setting allows a more top-down angle.

### Input
| Action | PC | Mobile | Gamepad |
|---|---|---|---|
| Move | WASD | virtual joystick | left stick |
| Attack | mouse button 1 | big attack button (bottom right) | RT / R2 |
| Block | mouse button 2 (hold) | block button (hold) | LT / L2 (hold) |
| Roll/dodge | Q | roll button | B / Circle |
| Open menus | hotkeys + buttons | HUD buttons | D-pad / menu |

Use `ContextActionService` so actions map to touch buttons automatically. Buttons must be
big, semi-transparent and movable in settings (position + size).

### Attack rules
* **Melee categories** (Sword, Spear, Heavy, Dagger, Gauntlet, Whip & Chain): **hold** the
  attack input to attack continuously at the weapon's attack speed.
* **Ranged and Magic categories**: **one press = one shot** (click/tap). Holding does not
  auto-fire (unless the player owns the Auto-Attack pass).
* **Auto-Attack (paid game pass):** when enabled, the player automatically attacks the nearest
  enemy in range (melee) or fires at the nearest enemy (ranged/magic). Toggle button on the HUD.
* Weapon stats (damage, hits per second, range, shape) come from `docs/weapon_system_document.txt`.

### Defense
* **Roll:** 0.35 s of invulnerability, 12 studs, cooldown 1.5 s. Cannot roll while blocking.
* **Block (hold):** reduces incoming damage by 60% (plus Defense), movement speed -50%,
  cannot attack while blocking. A block animation + shield effect plays.
* Rolls and blocks are checked on the **server** (cooldowns, i-frame window).

### Damage model
* `PlayerDamage = weapon damage (see weapon doc) x (1 + Attack bonuses) x crit`
* `Crit` = x2 damage with the player's Crit chance (base 5%).
* `DamageTaken = raw x (1 - blockReduction) x (1 - Defense/(Defense + 100))`
* Enemies telegraph strong attacks (>= 0.4 s for normal enemies, >= 1 s for bosses).

### Death
* On death the player **loses 35% of their Gold**, no delay, no other penalty.
* Respawn: at the start of the current sub-zone (the sub-zone's `Entrance`).
* Boss arenas: see section 7 (defaults).

## 3. Player stats & armor

### Base stats (level 0, no XP, no player level)
| Stat | Id | Base | Effect |
|---|---|---|---|
| Max Health | `MaxHP` | 100 | survive hits |
| Attack | `Attack` | +0% | % bonus to all weapon damage |
| Defense | `Defense` | 0 | damage reduction = Defense / (Defense + 100) |
| Speed | `Speed` | 16 studs/s | walk speed |
| Crit Chance | `Crit` | 5% | chance for x2 damage |
| Gold Gain | `GoldGain` | +0% | % bonus to Gold earned |

### Upgrade menu ("Training")
* Opened from the HUD and from a trainer NPC in the hub. Each stat is bought with **Gold**
  level by level (max 100 levels each).
* Cost: `100 x 10^(zone - 1) x 1.15^level`, where `zone` is the highest zone the player has
  unlocked (so prices follow the economy).
* Effect per level: `base_per_level x (1 + 0.25 x rebirths)` - **each rebirth makes every
  purchase stronger.** Base per level: MaxHP +6%, Attack +4%, Defense +1 point, Speed +0.5%
  (cap +40%), Crit +0.3% (cap 60%), GoldGain +3%.
* All stat levels reset to 0 on Rebirth.

### Armor (3 slots)
* Slots: `Helmet`, `Chest` (plastron), `Legs` (jambieres).
* **36 pieces: 1 set of 3 per zone.** Each piece has a rarity (same 8 tiers as weapons).
* An armor piece gives **Max HP** and **Defense**:
  * Piece HP = `100 x 10^(zone-1) x slotShare x rarityMult`, with slotShare Helmet 0.25,
    Chest 0.45, Legs 0.30 and rarityMult from the weapon doc (1.0 ... 25.0).
  * Piece Defense points = `3 x rarityTier` (Common 3 ... Secret 24), not zone-scaled.
* **Zone Boost:** like weapons, armor from a zone gets the rarity's Zone Boost (+5% ... +120%)
  on its HP and Defense while the player is in that zone.
* Armor is obtained as **loot** (enemies, mini-bosses, bosses). It is **not** sold in the shop.
  Armor is lost on Rebirth.
* Equipping a piece in a slot replaces the previous one (the old one goes to the inventory).

## 4. Economy & progression

### Currencies
* **Gold:** from killing enemies, selling trophies, quests and rewards. Lost partially on death
  (35%) and entirely on Rebirth. Values scale x10 per zone.
* **Diamonds:** premium currency. Dropped ONLY by mini-bosses and bosses, and sold for Robux.
  **Kept on Rebirth.** Uses: weapon rarity reroll, premium eggs, Gold boosts, skins.
* **Rebirth Credits:** earned on Rebirth (3 each), spent in the Rebirth Shop.
* **Boss Keys:** one per boss (12). **Kept on Rebirth.**

### Sub-zone prices (x2.5 per sub-zone)
Sub-zone 1 of a zone is free once the zone is open. For sub-zones 2-4 in zone z:

    price(z, 2) =   500 x 10^(z-1)
    price(z, 3) = 1,250 x 10^(z-1)
    price(z, 4) = 3,125 x 10^(z-1)     (opens the boss room)

(About 25-40 kills of the previous sub-zone's enemies.) Sub-zone prices are paid again after
each Rebirth for the zone being redone (see below).

### Rebirth
* **Rebirth number r (r = 1..12)** is available when the player:
  1. owns the **key of the zone-r boss** (obtained the first time that boss is beaten),
  2. has `Rebirths == r - 1`,
  3. pays the Gold cost: `RebirthCost(r) = 10 x price(r, 4)` (default).
* The key is **not consumed**.
* **Reset:** Gold, weapons, armor, stat levels, eggs, non-premium pets, trophies, and the
  sub-zone unlocks of the current zone.
* **Kept:** Diamonds, keys, Rebirth count, Rebirth Credits and Rebirth Shop upgrades,
  premium pets (bought with Robux), game passes, boosts, Index/collection, settings,
  cosmetics (skins), access to lower zones.
* **Gold multiplier:** each Rebirth adds to the permanent Gold multiplier:
  `bonus(r) = 0.5 + 0.5 x (r - 1) / 11` -> +0.5 at Rebirth 1 rising to +1.0 at Rebirth 12.
  Total multiplier = `1 + sum of bonuses` (x10 after 12 Rebirths).
* **Credits:** +3 Rebirth Credits per Rebirth (36 in total).

### Rebirth Shop (spend credits, permanent)
Defaults (1 credit per level):
| Upgrade | Id | Effect per level | Max level |
|---|---|---|---|
| Gold Boost | `GoldBoost` | +10% Gold | 10 |
| Damage Boost | `DamageBoost` | +10% damage | 10 |
| Loot Luck | `LootLuck` | +8% loot drop chance | 8 |
| Egg Luck | `EggLuck` | +5% chance for a rarer pet | 6 |
| Health Boost | `HealthBoost` | +10% Max HP | 8 |
| Diamond Luck | `DiamondLuck` | +5% diamond drop chance from bosses | 6 |

### Zone unlock chain
To open **zone N+1** the player needs ALL of:
* the **key of boss N**,
* at least **N Rebirths**,
* to have **redone zone N since their last Rebirth** (opened its boss room again).

When zone N+1 opens (after the redo), the player has two choices:
1. fight the boss of zone N again (more drops, diamond chances), or
2. teleport directly to zone N+1.

Lower zones stay accessible by teleport (their sub-zones stay open). The zone being
redone after a Rebirth has its sub-zone prices reset.

### AFK zone & offline bonus
* **AFK zone** in the hub: while the player stands inside it (and is not moving much), they earn
  Gold at **10%** of their recent average Gold-per-minute (average over the last 10 minutes of
  active play).
* **Offline bonus:** when the player returns, they receive Gold at the same 10% rate for the time
  away, capped at 8 hours (12 with a game pass).

## 5. Enemies, loot, pets

### Enemies
* Stats come from `docs/enemy_database.txt` (HP, DMG, Gold reward). The "COINS" column in that
  file is **Gold**.
* **About 10 enemies are alive at once per sub-zone**, split across its 3 enemy types (boss
  room: the 2 normal enemy types, 2 mini-bosses, 1 boss).
* An enemy **respawns 2 seconds after it dies**.
* Enemies are shared by all players on the server in a sub-zone. The player who dealt the
  **most damage** to an enemy receives its Gold and its loot rolls.
* Simple AI: idle -> notice player within an aggro radius -> chase -> attack with a telegraph ->
  leash back if the target is too far. Do not run AI on the client.

### Loot
* **Drop chances (per kill, on top of Gold):** normal enemies 2%, mini-bosses 4%, bosses 6%
  (see `docs/enemy_database.txt`).
* **Loot types in this game:** **Egg**, **Armor piece**, **Head trophy**.
  Mapping from the item types written in `docs/enemy_database.txt`:
  * `Egg` -> Egg (same rarity)
  * `Armor`, `Weapon` -> an **Armor piece** of the zone (random slot) with the listed rarity
  * `Corpse`, `Material`, `Trophy` -> **Head trophy** of that enemy
  * Weapons no longer drop from enemies. They are bought in the shop and (later) player-traded.
* **Head trophy:** sold for Gold at a hub merchant. Value = `25 x enemy Gold reward x rarityMult`.
* **Egg:** hatch at the hub egg station into a **pet** from that zone's pet pool, with the egg's
  rarity (guaranteed). **Premium eggs** (bought with diamonds) give a random rarity using the
  shop odds table of the weapon doc.
* Rarity of loot follows the rule in `docs/enemy_database.txt` (stronger enemy = rarer loot).
* Rebirth Shop `LootLuck` multiplies the drop chances above (max +64%).

### Pets
* Pets are equipped (3 slots by default; extra slots via game pass or later upgrade).
* Each pet has a **rarity** (8 tiers) and **two main stats** chosen among `Gold, HP, Attack,
  Speed, Defense`, plus one **common bonus** unique to its species (examples: +% diamond drop,
  +% loot luck, +% crit, +% egg luck).
* Stat bonus per main stat by rarity:
  | Common | Uncommon | Rare | Epic | Legendary | Mythic | Divine | Secret |
  |---|---|---|---|---|---|---|---|
  | +2% | +4% | +7% | +11% | +16% | +23% | +32% | +45% |
* The common bonus uses 25% of the main-stat value of the same rarity (default).
* Pets are lost on Rebirth, **except premium pets bought with Robux**.
* A pet follows the player visually (small low-poly companion, no collision, light on
  performance: max 3 followers).
* The full pet list (suggested 6 per zone = 72 species) is still to be written.

## 6. Weapons (reference)
Full rules in `docs/weapon_system_document.txt`: 8 categories x 12 zones = 96 weapons, random
rarity on purchase, damage = zone base x category x rarity, Zone Boost in the home zone.
Changes for this design:
* Weapons are bought with **Gold** at the hub weapon shop.
* The diamond **rarity reroll** stays.
* **Weapons are lost on Rebirth.** A weapon whose rarity was improved with diamonds is also lost.
* No weapon level / no weapon upgrades.
* Weapons never drop from enemies.

## 7. Multiplayer

### Sub-zones
* Free-for-all: all players in a sub-zone fight the same shared set of about 10 enemies. Highest
  damage dealer wins the Gold/drops of that enemy (ties: last hit).
* Server size: default Roblox (up to 12-20 players, tuned later).

### Boss rooms (separate arenas)
* The boss is fought in a **separate arena**, away from the sub-zones, so anyone can fight it
  with their team or solo. Each group gets its **own copy** of the arena (one instance per
  group, **maximum 5 players**).
* Flow: in sub-zone 4's entrance a **boss gate** lets the player choose "Enter solo" or "Enter
  with team/friends". A team leader starts the fight; invited friends/teammates in the same
  server can join until the group has 5 players or the fight starts.
* Implementation default: arenas are cloned from `ServerStorage.BossArenas.<ZoneId>` into
  `workspace.BossArenas` far from the map (same place, same server). If the server limit
  becomes a problem, reserved servers via `TeleportService` are the planned alternative.
* The fight: 2 mini-bosses first (both must die), then the boss spawns. See
  `docs/boss_patterns_document.txt` (a clean telegraph for every damaging attack).
* **Boss HP scaling by group size (default):** `bossHP x (1 + 0.6 x (players - 1))`.
* **Rewards:** every player who dealt **at least 5% of the boss's total HP** receives their own
  Gold, loot rolls and diamond chance (rolled **separately per player**). The first time a
  player beats a boss, they also receive its **key** (guaranteed).
* **Death in a boss arena (default):** the player loses 35% Gold as usual and is removed from
  the fight (spectates until it ends), then returns to the hub. If everyone dies, the arena is
  destroyed and players go back to the hub.
* Arena is destroyed 15 seconds after the boss dies (players see the reward screen first).

### Social
* **Teams:** a player can create a team of up to 5 (invite from the friends list or nearby players).
* **Friends:** Roblox friends are shown first in invites.
* **Leaderboards:** Rebirths, Highest Zone, Boss Kills, Total Gold earned, Total Damage.
  (`OrderedDataStore`, refreshed every 2 minutes, displayed in the hub.)
* **Player marketplace (weapons and armor): planned for a later version** (not in v1).

## 8. Hub

The hub is the central safe area (no combat). Players spawn here on join.
* **Weapon Shop:** buy a weapon of a chosen zone; rarity is random (weapon doc).
* **Trainer:** stat upgrade menu.
* **Egg Station:** hatch eggs, open premium eggs (diamonds). **Pet Manager** (equip/delete).
* **Trophy Merchant:** sells head trophies.
* **Rebirth Altar** and **Rebirth Shop.**
* **Diamond Shop:** Robux packs, boosts, skins, game passes.
* **Zone Portals:** one per zone, grayed out when locked (shows requirements).
* **AFK Zone**, **Team Board**, **Leaderboards**, **Codes** board and the **Tutorial guide** NPC.
* **No player bases / plots in this game.**

### Tutorial
Starts on first join, **with a Skip button**. Steps: move -> attack -> roll -> block -> kill an
enemy -> open the Trainer -> buy a stat -> open the next sub-zone -> meet the boss gate.
`Tutorial = 99` means done.

## 9. Retention & monetization

### Retention features (v1)
* **Daily reward** (7-day streak cycle; Gold, diamonds, boosts, eggs).
* **Playtime gifts** (timers at 5 / 10 / 20 / 30 / 45 / 60 minutes per day).
* **Daily quests** (3 per day: kill X enemies, earn X Gold, open a sub-zone, hatch an egg, etc.).
* **Codes** (promo codes redeemed in the hub or settings).
* **Leaderboards**, **Pets**, **Index/collection** (weapons, armor, pets, enemies discovered;
  claimable rewards), **AFK Gold and offline bonus.**

### Monetization
* **Game passes:** Auto-Attack, 2x Gold, Extra Pet Slots (+2), VIP (bigger offline cap +
  chat tag), Exclusive weapon (a unique cosmetic-like weapon with fixed stats, to be designed).
* **Temporary boosts** (Robux or diamonds): Gold x2, Damage x1.5, Luck x2 for 15 / 30 / 60 min.
* **Diamond packs** (Developer Products).
* **Premium pets** (Robux) that **survive Rebirth.**
* Ids go in `Config/Products.luau` (0 = hidden). Receipts use `ProcessReceipt` with purchase-id
  idempotency stored in the profile.

## 10. Code layout (Rojo)

```
src/ReplicatedStorage/GameSystem/
  Net.luau                         all remotes (one module)
  Config/*.luau                    pure data (Zones, Enemies, Bosses, Weapons, Armor, Pets, Loot,
                                   Rebirth, Rewards, Products, Quests, Codes, Admins)
  Util/Format.luau                 number formatting (K, M, B, T, Qa)
  Util/Sfx.luau                    sounds by name
  Util/Stats.luau                  derived player stats (shared server + client)
  Util/Rarity.luau                 rarity tables and helpers
src/ServerScriptService/GameSystem/
  Main.server.luau                 loader
  Services/*.luau                  one module per service, auto-loaded
  Bosses/BossBase.luau, Bosses/<BossName>.luau
src/StarterPlayer/StarterPlayerScripts/GameClient/
  Main.client.luau                 loader
  State.luau                       client profile mirror
  Controllers/*.luau               input, camera, VFX, audio
  UI/*.luau                        HUD and windows; UI/Kit/ = wood UI kit + theme + icons
```

* `.server.luau` = Script, `.client.luau` = LocalScript, otherwise ModuleScript.
* Services/controllers return a table with optional `Init(self)`, `Start(self)`, `Priority`.
* Luau, tabs, `--!strict` where practical, `task.*` only (never `wait`), `warn` only for real problems.
* **All numbers live in `Config/*.luau`**, never hard-coded in gameplay scripts.
* **Never create RemoteEvents by hand**: add them to `Net.luau`.

### Services
`DataService` (profile, DataStore, session lock, autosave 90 s) - `StatsService` (derived stats) -
`CombatService` (player attacks, roll, block, validation) - `EnemyService` (spawn, AI, damage
tracking, drops) - `BossService` (arenas, groups, patterns, rewards) - `ZoneService` (unlocks,
gates, teleports, death respawn) - `ShopService` (weapons, training, premium eggs, rerolls) -
`LootService` (drops, trophies) - `PetService` - `ArmorService` - `RebirthService` -
`RewardService` (daily, playtime, quests, codes, boosts, AFK/offline) - `LeaderboardService` -
`TeamService` - `MarketService` (Robux products) - `TutorialService` - `AdminService`.

### Sound names (Sfx)
`SwordSwing, Hit, Crit, Block, Roll, Hurt, Death, EnemyDeath, BossRoar, TelegraphWarn,
GoldPickup, Purchase, Denied, Unlock, EggCrack, PetHatch, RarityReveal, RarityLegendary,
LevelUp, RebirthWhoosh, UIClick, UIOpen, UIClose, MusicHub, MusicZone, MusicBoss`.

## 11. Data model (profile)

```lua
{
  Version = 1,
  Gold = 0, Diamonds = 0,
  Rebirths = 0, RebirthCredits = 0, RebirthUpgrades = {},      -- [upgradeId] = level
  Keys = {},                           -- [zoneId] = true  (boss key, kept on Rebirth)
  Zones = { Plains = true },           -- zones unlocked (kept on Rebirth)
  SubZones = {},                       -- [subZoneId] = true  (reset on Rebirth for the zone being redone)
  RedoneSinceRebirth = {},             -- [zoneId] = true when the boss room was reopened after a Rebirth
  CurrentZone = "Plains",
  Stats = {},                          -- [statId] = level (reset on Rebirth)
  Weapons = {},                        -- [uid] = { id = "plains_sword", rarity = 1 }
  EquippedWeapon = nil,                -- uid
  Armor = {},                          -- [uid] = { id = "plains_helmet", slot = "Helmet", rarity = 1 }
  EquippedArmor = {},                  -- { Helmet = uid, Chest = uid, Legs = uid }
  Eggs = {},                           -- [uid] = { zone = "Plains", rarity = 1 }
  Pets = {},                           -- [uid] = { id = "plains_pet1", rarity = 1, premium = false }
  EquippedPets = {},                   -- array of uids
  Trophies = {},                       -- array of { enemyId = "plains_boar", rarity = 1 }
  Index = {},                          -- [entryId] = true (kept)
  IndexClaimed = {},
  Boosts = {},                         -- [boostId] = expiresAt (os.time)
  Passes = {},
  Purchases = {},                      -- receipt idempotency, capped at 50
  Daily = { Streak = 0, LastDay = 0 },
  Playtime = { Day = 0, Seconds = 0, Claimed = {} },   -- Claimed = array of indices
  Quests = { Day = 0, List = {} },
  Codes = {},
  Skins = {}, EquippedSkin = nil,
  Settings = { Music = true, Sfx = true, LowFx = false, ButtonLayout = {} },
  Stats_Lifetime = { TotalGold = 0, TotalDamage = 0, BossKills = 0, EnemyKills = 0, PlaySeconds = 0 },
  PityCounter = 0,                     -- weapon shop pity
  LastOnline = 0,
  Tutorial = 0,                        -- 99 = done
}
```
Replication: the server sends `Net "Data"` patches `{key = wholeValue}` for changed top-level
keys. The client reads data only through `State`. Use arrays (not sparse tables) in anything sent
through remotes or saved. Item uids use `HttpService:GenerateGUID(false)` on the server.

## 12. World markers (names the code relies on)

```
workspace.Hub                          Folder
  SpawnLocation                        spawn
  Portals/Portal_<ZoneId>              BasePart, attribute ZoneId
  WeaponShop, Trainer, EggStation, TrophyMerchant, RebirthAltar, RebirthShop, DiamondShop,
  TeamBoard, CodesBoard, TutorialGuide                Models (each with a ProximityPrompt part "Interact")
  AFKZone                              BasePart (invisible box, CanCollide false)
  Leaderboard_Rebirths / Leaderboard_Zone / Leaderboard_Bosses / Leaderboard_Gold / Leaderboard_Damage
workspace.Zones                        Folder
  <ZoneId>                             Folder (Plains, Desert, Jungle, Tundra, Swamp, Volcano, Hell,
                                       Heaven, Dead, Abyss, Mechanical, Void)
    <ZoneId>_<n>                       Folder for sub-zone n = 1..4
      Area         BasePart            invisible box covering the playable space
      Entrance     BasePart            respawn/arrival point
      Spawns       Folder of BaseParts enemy spawn points, attribute EnemyId (optional)
      Gate         Model               PrimaryPart "Barrier" = collidable wall; attribute SubZoneId;
                                       a price sign shows the price (none on sub-zone 1)
      BossGate     Model (only n = 4)  entry to the boss arena (solo / team prompts)
workspace.BossArenas                   runtime clones (one per group)
ServerStorage.BossArenas.<ZoneId>      arena templates:
                                       PlayerSpawns (Folder), BossSpawn, MiniBossSpawn1, MiniBossSpawn2, Door
ServerStorage.Enemies.<EnemyId>        enemy models (Humanoid or AnimationController)
ServerStorage.Bosses.<BossId>          boss and mini-boss models
ReplicatedStorage.Assets
  Weapons/<WeaponId>   Tools          Armor/<ArmorId> Models        Pets/<PetId> Models
  Eggs/<EggId> Models  VFX/<Boss>_<Pattern>_<Part>   Sounds/...
```

**Ids:** Zones `Plains, Desert, Jungle, Tundra, Swamp, Volcano, Hell, Heaven, Dead, Abyss,
Mechanical, Void`. Sub-zone `<ZoneId>_1.._4`. Weapons `<zoneId lower>_<category>` (for example
`plains_sword`, `void_whip`). Armor `<zoneId lower>_<helmet|chest|legs>`. Rarities (1..8):
`Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Secret`. Stats `MaxHP, Attack, Defense,
Speed, Crit, GoldGain`. Weapon categories `Sword, Spear, Heavy, Dagger, Gauntlet, Ranged, Magic, Whip`.

## 13. Admin panel (owner only)

* Opened with F2 or a small crown button, visible only to UserIds in `Config/Admins.luau`
  (**checked on the server for every command**; the client button is only cosmetic).
* Commands: set/give Gold and Diamonds, set Rebirths and give keys, unlock any zone/sub-zone,
  teleport to any zone or boss room, give any weapon/armor/pet at a chosen rarity, kill the
  current boss, heal / invincibility, spawn an enemy, force a boss pattern, toggle boosts,
  reset my data.
* Owner UserId: `<ADMIN_USER_ID>` (to be provided).

## 14. Tooling & rules

* **BACKUP FIRST:** before making ANY change, make a backup and put it in the `BackUP_Files/`
  folder (`File -> Save to File As -> BackUP_Files/FightYourDestiny_<YYYY-MM-DD_HHMM>.rbxl`,
  plus `.rbxm` serializations when possible). Never overwrite an old backup. `BackUP_Files/` is
  gitignored, so remind the owner to copy it to a cloud drive or external disk.
* **GITHUB LAST:** at the end of the work, ALL modifications (scripts, configs, docs) must be
  committed and pushed to https://github.com/Miieski/Fight-Your-Destiny (`main`).
* **Rojo** syncs `src/` into Studio (disk -> Studio only). Changes made in Studio must be copied
  back by hand. Workspace, Lighting, Terrain and ServerStorage models are not mapped.
* Repo: https://github.com/Miieski/Fight-Your-Destiny (scripts and docs only).
* **Toolbox first:** use the Toolbox for props and base models, **Blender** only when needed.
* **Mandatory sanitising of every Toolbox asset:** delete ALL scripts, remotes, values and
  GUIs inside it, check for `require(<number>)` and obfuscated code, anchor static props.
* **Sub-agents:** one per boss/system with strict file ownership, a reviewer sub-agent after each
  wave, at most about 2 at once, one agent controlling Studio at a time. Rules in
  `docs/AGENT_BRIEF.md` (to be written).
* VFX: use a VFX/particle plugin, save effects under `ReplicatedStorage/VFX`, play them through a
  RemoteEvent (server decides, clients show).
* Playtest with 1 and with 2-4 players, on PC and with the Studio mobile emulator. Check the
  DataStore with API Services enabled.

## 15. Release plan

* **Batches of 3 zones.** Batch 1: Hub + Plains, Desert, Jungle. Batch 2: Tundra, Swamp, Volcano.
  Batch 3: Hell, Heaven, Dead. Batch 4: Abyss, Mechanical, Void.
* **All 96 weapons and 36 armor pieces are built from the start** (config + models). Items of
  zones that are not released yet stay hidden from shops/loot until their batch ships.
* The full loop (kill -> unlock -> boss -> key -> Rebirth -> redo -> next zone) must work on
  Plains before building anything else.

### Changes versus earlier documents (this file wins)
* "Coins" -> **Gold** everywhere.
* `enemy_database.txt`: loot types remapped as in section 5; weapons no longer drop; only Gold
  and diamonds as currencies; mini-boss/boss diamond rules unchanged.
* `weapon_system_document.txt`: shop pays Gold; weapons and rerolled rarity are lost on Rebirth;
  no enemy weapon drops; no weapon level.
* `zone_design_document.txt`: no player bases; the hub is the only safe area; art direction is
  **low-poly fantasy** (palette per zone stays).
* `HANDOFF.md`: Rebirth now resets weapons and keeps keys and diamonds (see section 4).

## 16. Open questions (defaults used until confirmed)

1. **Stats section:** the answer to "base stats" mentioned "no bases, so no stats". Default used:
   the six stats of section 3 with the Gold upgrade menu (no XP). Confirm or correct.
2. **Gold sharing in sub-zones:** default = only the top damage dealer gets the Gold and drops.
   Alternative: everyone who dealt damage gets a share of the Gold.
3. **Rebirth cap:** default = 12 Rebirths (one per boss key); Rebirth r needs key r and
   `Rebirths == r - 1`. Is there anything after Rebirth 12?
4. **After a Rebirth,** sub-zone unlocks of the zone being redone reset, while lower zones stay open.
5. **Death inside a boss arena:** default = spectate then return to the hub (no respawn in the fight).
6. **Boss group scaling** (+60% HP per extra player) and the solo/team flow are defaults.
7. **UI art:** smooth vector-like wood UI instead of pixel art.
8. **Stat costs, per-level gains, Rebirth cost (10x boss-room price),** Rebirth Shop levels, pet
   percentages and pity timer are tuning defaults.
9. **Pet list:** number of species per zone and their common bonuses to be defined (suggested 6
   per zone).
10. **Exclusive weapon game pass:** design to be defined.
11. **Admin UserId** and the server size (players per server) to be provided.
12. **Player marketplace** (weapons/armor): later version, currency to be decided
    (Gold or Diamonds; never Robux between players).
