# Night log - 2026-10-05 (overnight autonomous task)

Owner's overnight order: Part A (UI redo with 3D icons), Part B (teleport menu), Part C (96 weapons
in Blender). The owner is asleep: no waiting for approval, decisions are logged here.

## Status (newest first)

- 03:45 NIGHT FINISHED. Parts A, B and C are done and pushed. Studio left open in Edit mode (no Play running),
  local icon server stopped. Waiting for the owner: FBX Bulk Import, the missing Part B tablet screenshot,
  review of the 8 weapon lineups.

- 03:43 PART C DONE - WHIP & CHAIN category pushed: ALL 96 WEAPONS ARE MADE. Builders
  `tools/blender/fyd_weapon_whips.py` (handle + S-curved lash or chain, 6 studs; shared `path()`, `lash()`,
  `chain()` with alternating links; 952-1936 tris). Each whip checked on its preview; fixes: lashes 1.3x
  thicker, bigger leaves / flowers / vertebrae / segments, gold rings sized to the lash, bigger chain links
  (Frozen Chain was 2904 tris, now 1816), Soul Chain hook and Rift blade turned to face the camera.
  Lineup `Previews/Weapons/Whip_lineup.png`. All 96 icons uploaded; `Config/Weapons.luau` ICONS has 96/96
  (checked with a fresh require: no weapon without an icon). Manifest: 96 rows, every weapon within budget.
  Next: none for Part C - the FBX files wait for the owner's Bulk Import.

- 03:36 PART C - MAGIC category done and pushed (84/96). Builders `tools/blender/fyd_weapon_magic.py`
  (6 studs = 1.68 m staffs, head on top along +Z, origin at the grip; 1080-2126 tris of the 4000 budget).
  Each staff checked on its preview; fixes: shorter shaft for all staffs so the heads read at icon size,
  Apprentice orb, Sandstorm vortex thicker, Shaman totem head 1.4x, Blizzard saturated cyan glow,
  Eruption volcano bigger, Infernal Tome rebuilt as an OPEN book with runes, Lich skull + crown bigger,
  Void orb/orbits bigger. Lineup `Previews/Weapons/Magic_lineup.png`. Icons uploaded (84 ids). Next: Whip
  & Chain (`fyd_weapon_whips.py`, 6 studs handle part) - last category.

- 03:29 PART C - RANGED category done and pushed (72/96). Builders `tools/blender/fyd_weapon_ranged.py`
  (5 studs = 1.4 m; shared bow / crossbow / gun parts; 680-1486 tris). Conventions per type written in
  `Blender/Weapons/README.txt` (bows: limbs on Z, string -X; crossbows: bolt +Z, prod across X; guns: muzzle
  +Z, grip -X). Each one checked on its preview; fixes: bow limbs drawn 1.35x thicker + deeper curves (thin
  bows vanished in the icon), Blowgun feathers/vial bigger, Frostbite crystals, Plague Bow made distinct
  (bone hooks, rag, toxic drips), Flame Bow veins on the front, Dawn Bow scalloped wings, Bone Crossbow
  skull/prod, Harpoon Gun thicker + barnacles, Starfall Bow crystals. Lineup
  `Previews/Weapons/Ranged_lineup.png`. Icons uploaded (72 ids). Next: Magic (`fyd_weapon_magic.py`,
  6 studs, budget 4000).

- 03:21 PART C - GAUNTLET category done and pushed (60/96). Builders `tools/blender/fyd_weapon_gauntlets.py`
  (1.8 studs = 0.5 m, ONE right-hand gauntlet: origin = fist center, knuckles +Z, cuff -Z, back of the
  hand -Y; shared `fist()` / `cuff()` parts; 1104-1726 tris of the 4000 budget). Convention added to
  `Blender/Weapons/README.txt`. Each one checked on its preview; fixes: Leather Knuckles (no skin-tone
  fingers, darker leathers), Desert Wraps cloth fingers, Jaguar Claws rosettes, Mud Fists darker mud +
  lumps, Magma cracks, Angelic wings swept back (they were wider than the gauntlet was long).
  Lineup `Previews/Weapons/Gauntlet_lineup.png`. Icons uploaded (60 ids in `Config/Weapons.luau`).
  Next: Ranged (`fyd_weapon_ranged.py`, 5 studs).

- 03:15 PART C - DAGGER category done and pushed (48/96). Builders `tools/blender/fyd_weapon_daggers.py`
  (2 studs = 0.56 m, 0.16 m grip + ~0.3 m blade before scaling, 560-1340 tris). Each dagger checked on
  its preview; fixes: Hunter's Knife detail (was 328 tris, under the brief's 500 minimum), Venom Fang
  cream ivory, Ice Shard core visible + dark grip, Toad Tooth made distinct from the Venom Fang (barbs,
  slime, warty collar), Feather Dagger barbs/vane, Ghoul Fang (deeper serration, ribs, skull), Nano
  Dagger enriched for zone 11 (circuits, emitters, power cell). Lineup `Previews/Weapons/Dagger_lineup.png`.
  Icons uploaded, ids in `Config/Weapons.luau` (48 icons). Next: Gauntlet (`fyd_weapon_gauntlets.py`,
  1.8 studs, one hand, budget 4000).

- 03:09 PART C - HEAVY category done and pushed (36/96). Builders `tools/blender/fyd_weapon_heavy.py`
  (5 studs = 1.4 m, head centered 0.82 m above the grip before scaling, 764-1682 tris). Each weapon
  checked on its preview; fixes: Stone Hammer darker stone, Obelisk Hammer contrast (sandstone vs gold),
  Glacier Axe (dark haft, bearded blade, outer glow edge), Swamp Maul (moss, mushrooms, tones), Lava
  Hammer (rough obsidian, zig-zag cracks), Doom Axe horns, Judgment Hammer (feathered wings, gold core,
  halo), Gravedigger's Maul (chains, bigger skull/cross), Kraken Anchor (thicker), Hydraulic Hammer
  (bigger head, exhausts), Void Maul (bigger crystal head, tilted orbit). Lineup
  `Previews/Weapons/Heavy_lineup.png`. Icons uploaded, ids in `Config/Weapons.luau` (36 icons).
  HANDOFF.md now has a Part C section. Next: Dagger (`fyd_weapon_daggers.py`, 2 studs).

- 02:59 PART C - SPEAR category done and pushed (24/96). Builders `tools/blender/fyd_weapon_spears.py`
  (shared shaft/socket/ring/butt-cap/grip-wrap parts, 8 studs = 2.24 m, 694-1256 tris). Each spear
  checked on its preview; fixes: leaf head rebuilt (was a sliver), thicker shaft + 8 px outline so
  the long thin icons stay readable, Desert needle, Swamp head, Volcano lava rings, Hell crescent
  halberd, Heaven wider blade, Void rebuilt (faceted crystal blade + orbit ring). Lineup
  `Previews/Weapons/Spear_lineup.png`. Icons uploaded, ids added to `Config/Weapons.luau` ICONS.
  Next: Heavy (`fyd_weapon_heavy.py`, 5 studs).

- 02:49 PART C - SWORD category done and pushed (12/96). Pipeline `tools/blender/fyd_weapons.py`
  (build -> join -> triangulate -> Smart UV -> Cycles EMIT bakes of color/metalness/roughness 512 px
  packed -> 3-angle preview -> .blend -> FBX (Y up, meters, textures embedded) -> icon -> manifest).
  Pilot 01_plains_sword checked first (FBX re-import: 1.26 m, upright, 3 textures). Convention in
  `Blender/Weapons/README.txt`. Each sword checked on its preview before the next; fixes: Dead sword
  enriched, Abyss fuller removed. Lineup `Previews/Weapons/Sword_lineup.png`. Icons uploaded, ids in
  `Config/Weapons.luau` (ICONS table, `Weapons.ById[id].Icon`). Next: Spear.

- 02:40 PART B DONE and pushed. Teleport menu (page 1 list + preview, page 2 sub-zone cards, fade,
  toasts), server-validated `Teleport` request, hub portals open the menu, 60 zone/sub-zone diorama
  icons uploaded. Tested every state with admin commands at 1080p and phone. Next: Part C weapons
  (Sword pilot first).

- 02:08 PART A DONE and pushed. 50 icons uploaded (45 + Skull, Info, Warning, Crown, MenuLines so no
  flat placeholder is left in the HUD); ids in `Icons/asset_ids.json` and `UI/Kit/Icons.luau`.
  Kit restyled (menu tiles, badges, close button, touch buttons, currency icons, toasts).
  Tested at 1080p, phone, tablet; Output clean. Screenshots `docs/screenshots/ui_redo/`.
  Next: Part B (teleport menu).

- 01:55 Part A icons: all 45 rendered with the shared template (`Blender/Icons/_IconTemplate.blend`,
  sources `Blender/Icons/<Group>/<id>.blend`, PNG `Icons/<Group>/<id>.png`, sheet
  `Previews/Icons/PartA_all.png`). Gold coin pilot checked first, then groups checked on contact
  sheets; fixes made: shop awning, roof color, world light (washed-out reds), boot wing, spear,
  dagger taper, whip handle, magic orb. Next: upload, Icons.luau, Kit restyle.

- 01:25 Started. Read the briefs. Blender 5.2 connector OK (interactive, EEVEE). Studio upload tool
  takes image URLs, so icons are served from a local `http.server` on 127.0.0.1.

## Plan / resume pointer

1. Part A: icon pipeline (`tools/blender/fyd_icons.py`) -> template -> Gold coin pilot -> all A icons
   -> upload -> `Icons.luau` ids -> Kit/HUD/menu/pills restyle -> tests 1080/720/phone/tablet -> push.
2. Part B: Zones button + teleport window (page 1/2) + server `Teleport` + fade + 12 zone and 48
   sub-zone icons -> tests -> push.
3. Part C: weapons, category by category (Sword pilot first), manifest
   `Blender/Weapons/weapons_manifest.csv`, push after each category.
ALL THREE PARTS ARE DONE (96/96 weapons, 96/96 weapon icons). Nothing left to resume from this list.

## Decisions taken without the owner

- Phones: the shop shows wide short cards (icon left, texts right, Buy below) so a full row with its Buy buttons
  fits the ~380-unit-tall landscape screen; Gold and pity are one line under the tab row (the HUD Gold bar stays
  visible above the window). Every window on phones now puts its title banner beside its tabs.
- Reel tiles are picked with weights = odds^0.6: commons still dominate but rare tiles flash by now and then (pure
  odds would almost never show Divine/Secret tiles). The winning tile is tile 48 of 60, the stop lands at a random
  spot inside it.
- Rarity visuals on the held Tool: a PointLight in the rarity color from Uncommon, an outline (Highlight) from Epic.
- "Not enough Gold": the Buy button turns gray but stays pressable so the player gets the toast.
- Inventory: tapping a copy equips it (no separate details panel yet).
- The brief's menu icon "Training" is made as "Stats" (bar chart + rising arrow), because the owner
  renamed the Training window to Stats on 2026-10-05.
- Icon outline is done in post (alpha dilation 14 px + soft drop shadow) instead of Freestyle, so
  every icon gets the same thick dark outline regardless of the model.
- The Diamond keeps the game's cyan (DESIGN: Diamonds #5FD4FF), not the reference's purple.
- Zones button is an extra "Apart" button under the Settings gear (with a label) so the owner's 2 x 4
  grid stays as chosen.
- Zone and sub-zone icon ids live in `UI/Kit/Icons.luau` (Icons.Zones / Icons.SubZones) like every
  other icon id, not in Config/Zones (the two briefs disagreed; Part A says ids only in Icons.luau).
- Admins skip arena/combat/cooldown checks but NOT the unlock checks (so the owner can test locked
  states with an admin account; `lockAll` / `unlockZone` / `unlockAll` change the unlocks).
- Hub portals now open the teleport menu on their zone instead of teleporting directly (brief).
- Gauntlets are modeled as ONE right-hand piece (the brief says "pair, one per hand"): the left one is the
  same mesh mirrored in Studio, so the pair always matches and the file count stays 12 per category.
- Whip & Chain (brief: "6 studs, handle part") are modeled as the handle + a rigid S-curved lash/chain,
  6 studs in total, so the icon and the held weapon read as a whip; a physical rope/Beam can replace the
  lash in Studio later (written in Blender/Weapons/README.txt).
- Ranged: one convention per type (bow / crossbow / gun) instead of one for all, so each icon shows its
  best side (README). Long thin parts (bow limbs, lashes, spear shafts) are drawn thicker than real.
- Weapon icon outline width is per category (Sword 14 px, Spear 8, Heavy 11, Dagger 14, Gauntlet 14,
  Ranged 9, Magic 9, Whip 10): a 14 px outline swallowed the thin spear shafts at 512 px.

## Problems

- 02:35 Studio stopped receiving synthetic input and `screen_capture` times out (the PC display
  probably went to sleep). The Part B tablet screenshot is missing (desktop and phone are done).
  Studio and Blender still run scripts.

- 03:45 `screen_capture` still times out (second try after Part C), so the Part B TABLET screenshot was skipped
  (rule 4: failed twice). Desktop and phone screenshots of both teleport pages exist.
- Note for the next session: an `execute_luau` `require(module)` can return a cached copy; to check an edited
  config, require a temporary clone parented next to it (done for every Config/Weapons ICONS update).
- No UI shows weapon icons yet (Equipment still uses category icons); the ids are ready in
  `Weapons.ById[id].Icon` for the inventory/shop step.

# Weapon Shop task - 2026-10-05 (docs/weapon_shop_brief.txt)

## Status (newest first)

- 10:45 WEAPON SHOP TASK DONE and pushed. Client: `UI/Pages/WeaponShopPage` (Shop > Weapons: 8 category tabs left /
  scrolling row on phones, 12 cards per category in zone order, Gold + pity header, Odds panel, 3D preview with drag,
  locked cards = black silhouette + "?" + `???`, unlock flip animation), `UI/CaseOpening` (60-tile reel, one tween
  ease-out quint 6 s / 1.5 s Fast Open, tick sound with rising pitch, tile under the marker enlarged, Skip + tap to
  skip, reveal pop + rarity effects: quiet, sparkles, rays, screen glow for Divine/Secret; Equip / Open again /
  Close, "Better than equipped!"), `UI/Pages/InventoryPage` (Weapons tab grid with rarity borders, tap = equip),
  HUD weapon slot shows the weapon's own icon, Admin panel "Weapons" tab (force rarity, pity, reset, zone locks,
  Gold). `Kit/Window` phone layout: title banner beside the tabs (saves one row on phones, every window).
  Tested on desktop 1080p, iPhone 17 Pro (landscape) and iPad 10th gen: 28 screenshots in
  `docs/screenshots/weapon_shop/` (D = desktop, P = phone, T = tablet). Equip + respawn re-give, Fast Open, Skip,
  server timer ending an unclosed opening, refund path reviewed. Output: no errors or warnings (only the usual
  Studio DataStore notice).

- 10:40 PART 1 + SERVER + SIMULATION done (not pushed yet).
  * Configs: `Config/WeaponCategories` (mult, hits/s, range, shape/special), `Config/WeaponRarities` (8 tiers from
    Config/Rarities + pity rules + announcements), `Config/Weapons` entries now Id, Name, Category, Zone, ZoneId,
    Icon, Element + ByCategory / List / price(zone), `Util/Stats` (zone base x category x rarity), Settings
    `FastOpen`, Profile `PityLegendary`, Config/UI `WeaponShop` + `CaseOpening`.
  * 96 PLACEHOLDER Tools in `ReplicatedStorage.Assets.Weapons.<WeaponId>` (no FBX imported yet): one simple-parts
    design per category tinted per zone, Handle origin = grip, head +Y, Tip/Base (+Muzzle) attachments,
    attributes WeaponId/Category/Zone/Placeholder=true. `ServerStorage.DevTools.WeaponTools`: `placeholders()`,
    `fromImport(folder)` (turns the imported meshes into the real Tools, grip restored from
    `DevTools.WeaponBounds` = bounds of the 96 .blend meshes, `Blender/Weapons/weapons_bounds.json`).
    Grips measured in Play (R15): identity = head up out of the fist; bows / crossbows / guns / gauntlets turned.
  * Server: `ShopService` (BuyWeapon: validate, charge, roll odds+pity, item + Index, save, reply; opening lock;
    deferred toast / auto-equip / Mythic+ announcement until the reveal), `WeaponService` (EquipWeapon, Tool with
    Uid/Rarity + rarity light/outline, re-given on respawn), `DataService:Save`, admin `lockZone`, `giveWeapon`,
    `forceRarity`, `setPity`, `resetWeapons` (+ setGold/unlockZone existed).
  * Tested in Play: buy -> Gold 5000 -> 4000 -> 3000 (once per buy), not enough Gold refused with no charge,
    spam refused ("Too fast" / "Finish the current opening first"), locked zone refused, first weapon auto-equipped.
  * 100,000-roll simulation: `docs/weapon_roll_simulation.txt` (all tiers within 2.2 sd; pity exactly at 30/100).
  Next: client UI (shop page, case opening, inventory, admin weapons tab).

- 10:00 Started. Read the brief, DESIGN.md (1, 2, 6, 11), the weapon doc and the code. Backup
  `BackUP_Files/FightYourDestiny_2026-10-05_095919_before_weapon_shop_*`. No weapon FBX is imported in
  Studio yet (`ReplicatedStorage.Assets.Weapons` is empty), so Part 1 uses placeholder Tools.

## Decisions taken without the owner

- Pity follows the weapon doc literally: after 30 purchases without Epic+ (counter = 30) the NEXT one is
  guaranteed Epic+; same at 100 for Legendary+. Two counters (`PityCounter`, `PityLegendary`); each resets when
  its tier or better comes out, by luck or by pity. The guaranteed roll uses the normal odds among the allowed tiers.
- The "Obtained ..." toast, the auto-equip of a first weapon and the Mythic+ announcement are sent when the reveal
  shows (client `OpeningDone`, or the server timer), not with the reply, so nothing spoils the reel. The item and
  its auto-equip are saved before the reply, so leaving mid-animation keeps both.
- Announcements never reveal a locked weapon: players who have not unlocked that zone read "mystery weapon".
- Weapon names and the 96 Tools live where the brief puts them (Config/Weapons, ReplicatedStorage.Assets.Weapons),
  so a determined exploiter could read them; the UI never shows a locked weapon's name, stats or model.
- Weapons placeholders: one shape per category, colored with the zone palette, named `PLACEHOLDER_<id>` inside
  each Tool (attribute Placeholder = true). The FBX export turns Blender +X into Roblox -X (bow strings and
  gauntlet thumbs on +X); placeholders follow the real models.

## Problems / missing

- Not testable in Studio here: the server-wide Mythic+ announcement needs a second player (logic reviewed only),
  and the DataStore save before the reply (API Services off: Studio keeps profiles in memory). The item is written
  to the profile before the reply in both modes, so leaving mid-animation keeps it.
- No weapon FBX imported yet: all 96 Tools are placeholders (list: every weapon). Owner: import, then run
  `require(game.ServerStorage.DevTools.WeaponTools).fromImport(folder)` (see Blender/Weapons/README.txt).

# Menu systems task - 2026-10-05 (docs/menu_systems_brief.txt)

## Status (newest first)

- 15:05 OWNER FIX: the attribute info panel (Stats window, tap on an attribute name) could not be closed: the
  tooltip was never remembered as the open overlay, so tapping outside did nothing. Fixed, and the panel now has a
  red X close button (touch size) like the other panels; a tap outside or closing the window also closes it.
  Tested in Play: X closes, tap outside closes. Screenshot `docs/screenshots/menu_systems/A7_*`.

- 14:26 FINAL. Every part of the brief is done and pushed (portal rule, A, B, C, D1-D5). Last pass: phone and
  tablet screenshots for D2-D5 (`docs/screenshots/menus/*_P*`, `*_T*`), Daily / Gifts rows fitted to one line,
  "Show Armor" off checked through the real Settings toggle (armor parts removed, saved; on again = back), Output
  clean (only the expected API Services lines), HANDOFF.md updated, final backup `after_menu_systems`.
  FINAL REPORT
  * Finished: all of the brief; acceptance checks run with admin data (simulations, StatsTests 78/78, request
    validation, double-claim refusals, UTC-day logic via setDaily / addPlaytime).
  * Not finished / not testable alone: 2-player team flows; DataStore persistence (API Services off); Robux
    products (ids 0); combat-side effects of Regeneration, Boss Slayer, Loot / Diamond Luck, Trophy Value; trophies;
    skins; Index enemy art (placeholder skull / crown).
  * Decisions: see "Decisions taken without the owner" below.
  * Owner by hand: save the place (pet / egg models live in it), enable API Services to test saving, create the
    passes / products and put their ids in Config/Products, test teams with 2 clients, edit codes in Config/Codes.

- 14:50 PART D5 TEAM done and pushed. `Config/Teams` (max 5, invite 30 s, invite rate limit 1.5 s, nearby 120
  studs). `TeamService`: TeamCreate, TeamInvite(userId) (leader; inviting without a team creates one; target must
  exist, not be you, not be in a team; no duplicate pending invite; team not full), TeamRespond(inviteId, accept)
  (expiry, still valid, room left), TeamLeave (leader passes to the next member, empty team removed), TeamKick
  (leader), TeamDisband (leader); members get Net "Team" snapshots, the invited player Net "TeamInvite"; player
  attributes TeamId and Rebirths; `TeamService.getTeam(player)` for the boss gate. Client `UI/Team`: Team tab
  (headshot, name, crown, Rebirth, zone, Kick / Leave / Disband with confirms, Create Team), Invite tab (friends
  first, then by distance, status and Invite), invite popup (Accept / Decline, countdown, queue), HUD party list
  under the health bar while in a team. Also: services that react to `DataService.Loaded` now also handle profiles
  loaded before they started (Studio play solo: quests, followers, armor look, team attributes were late).
  Tests (one player): leave / disband / kick / invite-self / unknown user / bad invite refused, create, double
  create refused, leave clears TeamId, disband, invite popup shown and a bad answer refused. NOT tested: a real
  2-player invite / accept / kick (needs a multi-client test server). Screenshots `docs/screenshots/menus/D5_*`.

- 14:40 PART D4 QUESTS done and pushed. `Config/Quests` (G = 2000 x 10^(Z-1); pool of 10 kinds, 3 a day picked
  deterministically from the UTC day; targets in G / zone damage units; normal = 3 G, hard (mini-boss, boss,
  trophies) = 2 Diamonds; all 3 claimed = +5 Diamonds with the 3rd claim; 7-day streak table; 6 playtime gifts),
  `Config/Codes` (WELCOME 5 G + 5 Diamonds, DESTINY 10 Diamonds, BOSSKEY 10 G). `RewardService` rewritten:
  ClaimQuest(i), ClaimDaily, ClaimGift(i), RedeemCode(code) (also used by the Settings code box), play time counted
  on the server every 15 s, everything resets at 00:00 UTC; `RewardService.progress(player, kind, n)` is called by
  EnemyService (kills, Gold from enemies, damage, mini-boss, boss; plus Index discovery of enemies on kill),
  ZoneService (gate opened), PetService (hatches), ShopService (weapon bought), StatsService (Gold spent on
  attributes); trophies later. Window `UI/Pages/QuestsPage` (Quests with progress bars and reset timer, Daily Reward
  7 cards + claim / next-reward timer, Playtime Gifts with countdowns, Codes box). Menu badge = claimable quests +
  today's daily + reached gifts. Admin progressQuest, addPlaytime, setDaily(streak, daysAgo), resetQuests,
  simulateQuests(day). Tests: quest claims 6K / 6K / 2 + 5 Diamonds, second claim refused; daily: already claimed,
  day 7 = 16K Gold + 15 Diamonds, missed day -> day 1, day 5 = premium egg; gifts: too early refused, 5 min and
  45 min boost claimed, 60 min refused, twice refused; codes: lower case accepted, reuse refused, unknown refused.
  Screenshots `docs/screenshots/menus/D4_*`.

- 14:25 PART D3 INDEX done and pushed. `Config/IndexBook` (catalog: 96 weapons, 36 armor, 72 + 4 premium pets,
  168 enemies (11 + 2 minis + boss per zone), grouped by zone; best rarity, counts, rewards: 2 + zone Diamonds per
  zone of a tab, 100 per tab). `IndexService` ("ClaimIndexReward": complete, once, saved; `Discover`). Weapons now
  store their best rarity in the Index (was `true`; `true` still reads as discovered). Admin discover(entryId |
  Tab:Zone | Tab:All | All, rarity?) and clearIndex. Window `UI/Pages/IndexPage`: tab summary with progress bar and
  tab reward, zone sections (icon, x/y %, Claim), cells with 3D icon / weapon icon / enemy placeholder, rarity pips,
  undiscovered = black silhouette + "?" and no name; built on first view, rebuilt on change. Menu badge = claimable
  rewards. Tests: zone reward 3, again refused, incomplete zone / tab refused, unknown refused, Enemies:Desert 4,
  Armor:All 100 -> 107 Diamonds. Screenshots `docs/screenshots/menus/D3_*`.

- 14:18 PART D2 REBIRTH SHOP done and pushed. `RebirthShopService` ("BuyRebirthUpgrade": known id, below max,
  1 credit per level, credits and level change together, saved). Window `UI/Pages/RebirthShopPage`: credits, the 6
  upgrades with 3D icon, level pips, Lv x / max, current bonus, Buy / Max. Tests: unknown ids refused, Egg Luck to 6
  then "at its maximum", no credits refused, Health Boost 1 -> Max HP 110. Desktop screenshot
  `docs/screenshots/menus/D2_D1_rebirth_shop.jpg` (phone / tablet shots of D2-D5 come in one pass at the end).

- 14:12 PART D1 SHOP > DIAMONDS done and pushed. `UI/Pages/DiamondShopPage`: Diamonds + Get Diamonds (hub
  teleport confirm), Premium Eggs strip (12 zones, locked silhouettes, same purchase as the Pets window), Weapon
  Reroll (weapon list -> 5 + 2 x zone Diamonds -> case opening in reroll mode -> Keep new / Keep old; ShopService
  "RerollWeapon" + "RerollChoice", no pity, admin forceRarity applies), Gold Boost x2 packs 15 / 30 / 60 min for
  25 / 45 / 80 Diamonds (new `BoostService`: "BuyBoost", `Add` stacks time, max 24 h; `Config/Boosts.Packs`,
  `remaining`), Skins "Coming soon" silhouettes. HUD `UI/BoostTimer` (Gold x2 mm:ss, tap -> Shop > Diamonds; PC /
  tablet under the bars left of the admin crown, phones left of the Diamonds bar, clear of the action buttons).
  Admin giveBoost(id, seconds). Tests: reroll keep old (rarity kept), keep new (rarity changed), second answer
  refused, bad uid refused, Diamonds 300 -> 237 (45 + 9 + 9), boost 30 min; screenshots `docs/screenshots/menus/D1_*`.

- 13:55 PART C ARMOR & EQUIPMENT done and pushed. `Config/Armor` (36 pieces with the brief's names, slot shares
  .25/.45/.30, HP = 100 x 10^(Z-1) x share x rarityMult, Defense 3 x tier, Zone Boost in the piece's zone, full set
  +10% Max HP and +10% Zone Boost, storage 100, sell rarityMult x 200 x 10^(Z-1), C4 palettes; `totals` feeds
  Util/Stats). Server `ArmorService`: EquipArmor (replaces the old piece), UnequipArmor(slot | "All"), EquipBestArmor
  (pieceHP x (1 + Def/100) in the CURRENT zone), LockArmor, SellArmor (locked / worn refused), `GiveArmor` (auto-sell
  when full), Index best rarity, player attribute "ArmorLook". Admin giveArmor(id | zone, rarity, count?).
  Look: `Util/ArmorLook` builds procedural pieces on any R15 body (sizes from the body parts; helmet features per zone:
  crest, headwrap, tribal mask, fur, witch hat, horns, big horns, halo, skull, coral, visor; chest plate + pauldrons +
  belt; thigh plates + greaves + knee caps; rarity trims, neon from Epic, shimmer particles from Epic; head
  accessories hidden under a helmet). `Controllers/ArmorVisualsController` welds them to every character in 150
  studs; Settings "Show Armor" (default on). Inventory window (1080x620) tabs: Equipment (default), Weapons, Armor,
  Pets + Eggs (shortcuts to the Pets window), Trophies (placeholder). `UI/Pages/EquipmentPage`: scroll banner (name +
  Rebirths), the player's own avatar (posed copy of the character, AnimationConstraint / Motor6D joints solved to the
  rest pose) on a pedestal with the worn armor, slow turn / drag / tap to pause, Helmet-Chest-Legs slots (+HP, info
  button, picker), weapon slot, 5 pet slots (2 locked), stats summary (Max HP, Defense + reduction, Zone Boost per
  slot, set x/3, weapon damage), Equip Best Armor / Unequip All; phones: one screen + Stats drawer.
  `UI/Pages/ArmorPage`: grid with slot filter / sort / storage, detail panel (3D preview, HP / Defense with and
  without Zone Boost, sell value, Equip / Lock / Sell confirm) and the slot picker with green / red arrows.
  `Kit/ModelIcon.armor` (piece on an invisible body, mannequin head for helmets), `Kit/Overlay` (shared panels).
  Tests: StatsTests 78/78 (armor cases: Legendary Plains set in / out of Plains, Epic Desert chest in Desert);
  request validation (bad uid / slot / type), replace on equip, worn / locked sell refused, sell 200 Gold, Equip Best,
  Unequip All clears "ArmorLook"; Max HP 1,157 with the Plains set + pets (650 x 1.78). Screenshots
  `docs/screenshots/armor/` (D1-D5 desktop incl. armor in the world, P1-P3 phone, T1-T2 tablet).
  Next: Part D (other buttons).

- 13:40 PART B EGGS & PETS done and pushed. `Config/PetRarities` (main values 2..45 %, bonus 25 %, storage 30 eggs /
  60 pets, slots 3 + 2 pass, release / egg sell values, premium egg price 10 + 4Z, Equip Best weights, hatch timing,
  follower numbers) and `Config/Pets` (72 species with the brief's names and slot roles + 4 premium pets; body type,
  palette, scale, accessories; `ById`, `ByZone`, `mainValue`, `bonusValue`, `powerScore`, `releaseValue`,
  `eggSellValue`, `describe`). Server `PetService`: HatchEgg, HatchAll (rarest eggs first, stops when the pet storage
  is full), BuyPremiumEgg (Diamonds, shop odds via ShopService.rollTier, hatches at once), EquipPet, UnequipPet,
  LockPet, ReleasePet, EquipBestPets; `GiveEgg` (auto-sell + toast when 30 eggs), `GivePet`, `grantPremium(player, id)`;
  Egg Luck from the Rebirth Shop; Index[petId] = best rarity; player attribute "FollowPets"; the hub Egg Station
  prompt opens Pets > Eggs. Product ids `Products.PremiumPets` (0 = hidden). Admin: giveEgg(zone, rarity, count),
  givePet, clearPets, simulateEggs(n), setPass(name, on), setUpgrade(id, level).
  Models: `tools/PetModels.luau` (DevTools) builds 7 procedural body types from parts (Quadruped, Bird, Blob, Insect,
  Fish / Jelly, Biped, Mech) + 30 accessories -> `ReplicatedStorage.Assets.Pets` (76, ~21 parts each) and 12 zone
  eggs with patterns + a rarity ring -> `Assets.Eggs`. Client: `Kit/ModelIcon` (cached ViewportFrame icons, turntable),
  `Controllers/PetFollowController` (walkers hop, flyers bob, 80 studs view range, Low FX crowd rule, rarity light
  from Epic), `UI/Hatching` (wobble -> 3 cracks -> burst with the case-opening effects -> pet reveal; Hatch All
  summary grid; Fast Open), `UI/Pages/PetsPage` (Pets / Eggs / Premium Eggs tabs, slots, Equip Best, filters + sort,
  detail panel with 3D preview, values with Faith, Equip / Lock / Release confirm; phones: one header row + Filters
  popup, wide egg cards). HUD pet slots show the 3D pets.
  Tests: 100,000-egg simulation PASS (largest gap 2.5 sd; Egg Luck 5 / 15 / 30 % exact; docs/egg_simulation.txt);
  StatsTests 65/65 (3 new pet cases: values, Faith x1.54 + speed cap, premium golem); storage limits, auto-sell,
  release rules, premium release refused, wipeForRebirth keeps premium pets; screenshots `docs/screenshots/pets/`
  (D0-D8 desktop, P1-P6 phone, T1-T5 tablet).
  Also fixed: a click on an empty spot inside any window (or shop / pets overlay) fell through to the backdrop and
  closed it (Window frame and overlay panels now sink clicks).
  Next: Part C (armor and the Equipment screen).

- 12:54 PART A ATTRIBUTES done and pushed. `Config/Attributes` (8 attributes, 0..40, soft cap 20 -> Peff, cost
  round(100 x 10^(Z-1) x (1 + L/10)^1.5), RebirthPower, respec 5 + 2Z Diamonds, effects, hard caps, weapon scaling
  weights + grades), `Config/RebirthShop` (6 upgrades, rebirth Gold bonus), `Config/Boosts` (GoldX2), `Util/Stats.compute`
  (A4 formulas; pet and armor hooks ready for Parts B/C), Profile `Attributes` replaces `Stats`, `DataService.Changed`
  event. Server `StatsService`: Net "TrainAttributes" (keys, integers, caps, cost point by point, Gold, atomic, save),
  "RespecAttributes"; Max HP and walk speed applied to the Humanoid. Admin: setPoints, setRebirths, setCredits,
  runStatsTests (`DevTools/StatsTests`: 5 sample profiles + cost examples, 45/45 pass), wipeForRebirth (section 7).
  Window (Stats button, title "Attributes", `UI/Pages/AttributesPage`): 8 rows with bar + soft-cap marker, pending
  [-]/[+] with hold-to-repeat (and keyboard/gamepad), effects tooltip, 15 status lines before -> after in green/red,
  equipped weapon damage before -> after + grades, Confirm (cost) / Reset pending / Respec (confirm popup). Phones:
  buttons in the header row and a Points/Status switch. Tested: train 3 Vigor = 346 Gold, Max HP 112; 4 tampered
  requests rejected; not enough Gold refused; respec 7 Diamonds; wipeForRebirth. Screenshots
  `docs/screenshots/menu_systems/A1-A6` (desktop, phone, tablet).
  Next: Part B (eggs and pets).

- 12:43 SECTION 1 PORTAL RULE done and pushed. Hub portals: touch (client, Controllers/PortalController) ->
  Net "UsePortal" -> server checks (zone unlocked, coming soon, boss arena, damage in the last 5 s, 3 s cooldown
  shared with the Zones menu; admins skip arena/combat/cooldown) -> straight to the Entrance of sub-zone 1, with the
  Zones-menu fade (new Kit/Fade, also used by ZonesPage) and the PortalEnter sound. Locked portals are gray with a
  lock and a "Locked" sign for THIS player; a refused touch shows the requirements toast (at most every 2 s).
  "Coming soon" sign for Zones.NOT_BUILT (empty today). Server portal Touched -> OpenWindow removed. Tested in Play:
  Plains portal -> Plains_1, Desert locked -> toast "Desert locked: Needs the Golem key, 1 Rebirth and Plains
  redone", Desert unlocked by admin -> portal colored again -> Desert_1. Also (owner request): the Zone Sign
  setting is now OFF by default.
  Next: Part A (Attributes).

## Decisions taken without the owner

- The menu button stays "Stats" (owner's rename of 2026-10-05); its window is the brief's "Training" Attributes
  window, titled "Attributes".
- PointCost example: the brief prints 18,870 for L 319 (Z1); its own formula gives 18,870.9 -> round() = 18,871. The
  formula is kept (test expects 18,871).
- Max HP and walk speed from the attributes are applied to the Humanoid now (StatsService). HP regeneration, block,
  roll, crit, attack speed and the rest are computed and shown, and will be used by the combat step (no combat code
  in this task); the default Roblox health regeneration is unchanged for now.
- The owner mentioned a reference image for the Equipment screen, but none was attached to the message: Part C
  follows the brief's text (character in the middle, slots around) and docs/UI Fantesy like *.jpg.
- Premium egg (B1): buying one hatches it at once (the rarity is rolled at purchase with the shop odds, then Egg
  Luck); it never goes into the 30-egg storage. Refused when the pet storage is full.
- Premium pets cannot be released (bought with Robux; the brief only says they survive Rebirth).
- HatchAll with less room than eggs hatches the rarest eggs first and leaves the rest (toast with the count).
- `grantPremium` ignores the 60-pet storage limit (a Robux purchase must always be delivered).
- Pet models are ~0.6-1.2 studs as the brief says; followers are drawn at x1.4 (`PetRarities.Follow.Scale`) so they
  read next to a 5-stud avatar. Change that one number to resize every follower.
- Followers: up to 3 per player, offsets behind-left / behind-right / behind; flying = birds, fish, jellies, winged
  pets, glowing / flaming blobs, the drone.
- Pet Regeneration is computed (Util/Stats RegenFraction) but not applied yet: HP regeneration belongs to the combat
  step (it needs the "out of combat" delay); same for Boss Slayer, Crit Damage, Loot / Diamond Luck and Trophy Value.
- Index entries for pets store the best rarity (number); weapons still store `true` until D3 converts them.
- Baby Croc uses a long snout (new accessory) instead of the pig nose; the Sand Snake uses the Fish body.
- Armor storage full when a piece drops: the piece is sold at once with a toast (same rule as eggs).
- Inventory "Eggs" tab: a shortcut to Pets > Eggs like the "Pets" tab (the eggs are hatched there). Trophies tab:
  "Coming soon" (trophies come with combat loot).
- Equipment avatar = a posed copy of the player's current character (same skin and accessories as in the world)
  instead of CreateHumanoidModelFromDescription (server-only API); joints are solved to the rest pose.
- While a helmet is worn, head accessories (hats, hair, big-head accessories) are hidden on the character and on
  the Equipment avatar, so the helmet shows; they come back when the helmet is removed or Show Armor is off.
- The worn weapon and pets are not shown on the Equipment avatar (only the armor, as the brief says); the weapon
  is in its own slot.
- Equipping a piece never fails for storage reasons (equipping does not change the item count).
- Weapon Reroll: the reroll screen can only be closed with Keep new / Keep old; if the player leaves mid-reroll the
  old rarity stays (the brief: it is replaced only after the player confirms). The case opening shows Diamonds
  instead of Gold during a reroll.
- Gold Boost stacking is capped at 24 hours of remaining time.
- Index: the 4 premium pets are listed (own "Premium" group) but are not needed for the Pets tab reward (Robux
  only). Enemies have no models yet: skull icon (crown for bosses, red names for mini-bosses) until they exist.
- Quests: the all-done bonus (+5 Diamonds) is paid automatically with the claim of the 3rd quest (no extra
  button). "Earn G Gold" counts Gold from enemies only. Quest targets are fixed when the day's quests are made.
- Daily reward day 5 "premium egg" = an egg of the highest unlocked zone with a rarity rolled with the shop odds,
  added to the egg storage (auto-sold if full). Rewards in G use the player's G at claim time.
- Team: only the leader invites (and kicks / disbands); a player without a team who invites someone becomes the
  leader of a new team. The party list sits under the health bar (left), clear of the menu grid and the buttons.

## Problems / missing

- Studio's display went to sleep twice during the run, which stops rendering (screen_capture times out,
  RenderStepped stops). A keep-awake helper (SetThreadExecutionState) ran during the test passes; the first version
  had a signed-flag bug and did nothing.
- The Edit-mode command bar can return stale cached copies of config modules (StatsTests / IndexBook failed there);
  all tests were run in Play instead. `loadstring` was used as a compile check before each Play.
- One client syntax error reached Play once (ArmorPage `:: number <` cast) and blanked the HUD; fixed, and every
  later script was compile-checked first.
- Services that listen to DataService.Loaded in Init missed the player in Studio solo (profile loaded earlier):
  fixed with a catch-up loop in Pet, Armor, Reward and Team services.

# Enemies, NPCs, pets task - 2026-10-05 evening (docs/enemies_npcs_pets_brief.txt, zones 1-4 only)

## Status (newest first)

- 20:57 PART B (ENEMY SYSTEM) done and pushed.
  `Config/Enemies` extended for zones 1-4 (Part F list): Tier, Rig, Height, colors, WalkSpeed (rig defaults,
  mini / boss 10), Hover (flyers 4, fish and floaters lower), AggroRadius 30, AttackType (archers, bats, toxic frog,
  shaman and ice spirit shoot), AttackRange, AttackCooldown 2, Telegraph (0.4 melee / 0.5 ranged / 0.5 mini /
  1.0 boss), Loot (item, database type, kind Egg / Armor / Trophy), LootRarity (b = ceil(zone / 2) rule), AI
  constants, loot chances, trophy storage and value. New `EnemyService`: 10 per sub-zone (4/3/3, 5/5) on the
  Spawns points (random free spots in Area if a type has none), respawn 2 s later on a point 12+ studs from every
  player, pause at once when the sub-zone is empty and despawn after 15 s; 10 Hz AI Idle (wander) / Chase /
  Telegraph / Attack / Recover / Leash (60 studs, heal to full); movement = physics root moved by AlignPosition /
  AlignOrientation (server owner, smooth on clients), raycast ground snap, steering around obstacles, separation
  between enemies, PathfindingService only when stuck; melee cone hits, ranged shots (60 studs/s, range 40,
  dodgeable), mini-boss heavy attack (1 s telegraph, x1.5, 6 s cooldown); knockback (normal only), Heavy stagger
  (not bosses); top damage dealer (tie: last hit) gets Gold x Gold multiplier, quests, Index and the loot roll.
  New `LootService` (2% / 4% / 6% x Loot Luck; Egg -> egg, Armor/Weapon -> armor piece of the zone, others -> head
  trophy; Trophies storage 100 with auto-sell; SellTrophy / SellAllTrophies). New `Lib/EnemyRigs`: placeholder
  models per rig family (Quadruped, Biped, Bird, Serpent, Arachnid, Crustacean, Insect, Fish, Amphibian, Golem,
  Snowman, Floater, Gorilla, BossBiped) with Motor6D joints; imported models in `ServerStorage.Enemies.<id>` /
  `Bosses.<id>` replace them automatically. Client `EnemyController`: HP bars (tier colors, shown within 30
  studs or when hurt), white hit flash, red telegraph pulse (stronger with High-Contrast Telegraphs), procedural
  walk / attack / hit / death animation through the joints, spawn fade-in, death fade, "+N" Gold and coin pop.
  Inventory > Trophies tab (value, Sell, Sell All with confirm). Admin: spawnEnemy, killAll, validateEnemies,
  simulateKills, giveTrophy, dropLoot (+ godMode, enemyHit from Part A). `tools/gen_enemy_database.py` turns
  docs/enemy_database.txt into `ServerStorage.DevTools.EnemyDatabase` for validateEnemies.
  Tests (Play): validateEnemies 168 rows, 0 mismatches. simulateKills: boar 1.966% (2%), Cave Troll 3.988% (4%),
  Golem 6.034% (6%), Yeti with Loot Luck 3 2.437% (2.48%). Wolf: chase, telegraph, 5 damage per hit; kill -> +20
  Gold (wolf Gold), respawn after 2 s; bats hover 4 studs and shoot (40 per hit); trophies 25 x Gold x rarityMult
  (Djinn Rare 924K, Boar 400), Sell and Sell All clicked in the UI; dropLoot gives egg / armor / trophy with toasts.
  Lap of all 16 sub-zones of zones 1-4 (player at 4 points of each Area): 10 alive everywhere, 0 outside the Area,
  0 under the ground; empty sub-zones despawn. Output clean. Screenshots `2B_*`.
  Next: Part C (boss rooms).
- 20:27 PART A (PLAYER COMBAT) done and pushed.
  Server `CombatService` rewritten (the placeholder is gone): `Net.send("Attack", aimDir, aimPoint)` with the
  shapes of the new `Config/Combat` (Sword arc 120/6/3 targets, Spear line 10x3 pierce 4, Heavy arc 90/6 + slam 6
  with 0.3 s stagger, Dagger arc 60/4 single +20% crit, Gauntlet cone 90/5 with a 3-hit combo (3rd x2), Ranged
  projectile 120 studs/s range 60 first enemy, Magic AoE at the aim point clamped to 35 studs, radius 6 x (1 + Magic
  radius), Whip cone 100/12 up to 6). Rate = HitsPerSecond x (1 + attack speed), 18% tolerance. Damage = Stats
  WeaponDamage (no zone factor) x crit x (1 + Boss Slayer) on mini-bosses / bosses. Roll (cooldown from Stats,
  0.35 s i-frames) and Block (Stats block %, speed x0.5, no attacks) with server timestamps;
  `CombatService:DamagePlayer(player, raw)` for enemies (dodge / block / defense / god mode). Starter weapon: a
  player with no weapon gets a free Common sword of their current zone (Plains outside zones) on load, after a
  wipe or when the weapon list empties. Client `CombatController` rewritten: hold for melee, one press = one shot
  for Ranged / Magic, mouse aim on PC, nearest-enemy aim on touch / gamepad, swing animation through the tool
  (`toolanim` Slash / Lunge), shot trails and AoE discs (new Net events Projectile / Burst / Hurt), roll dash with
  fade, block bubble (also seen by other players), Dodge / blocked / hurt numbers, Auto-Attack HUD toggle (shown
  only with the pass; above the touch Attack button, right of the hotbar on PC). StatsService keeps the block
  slowdown. Admin: `godMode(on)`, `enemyHit(raw)`.
  Tests (Play, Desert Common weapons, base 100): Sword 100, Spear 120, Heavy 250 (+ slam burst), Dagger 40 (crit 80),
  Gauntlet 60/60/120, Whip 90, Ranged 80 at 25 studs (hit after 0.25 s), Magic 80 at 25 studs and nothing at 50
  (clamped to 35). 6 attacks sent at once = 1 hit; NaN / string inputs ignored, no errors. Block: 50 -> 20 and
  speed 16 -> 8 -> 16; roll: 0 + "Dodge", then 10 after the i-frames; god mode 0. Starter weapon: resetWeapons in
  the Hub -> Iron Shortsword, in Desert -> Sand Scimitar. Death: "You lost 35% of your Gold: -350" (1000 -> 650),
  respawn 2 studs from the Desert_1 Entrance. Auto-Attack with a bow: 3 hits in 3 s. Toolslash / toollunge play.
  Screenshots `docs/screenshots/enemies_task/2A_*` (PC block bubble + toggle, auto bow, phone buttons).
  Next: Part B (enemy system).
- 20:10 PART 1 (TWO RULE CHANGES) done and pushed.
  1A No spoilers: new `GameClient/UI/Kit/ZoneVisibility` (isRevealed, displayName, bossName, subZoneName,
  description, requirement, displayIcon, icon, applySilhouette / removeSilhouette, changed) and
  `Config/Zones.HIDDEN_NAME / HIDDEN_REQUIREMENT / HIDDEN_SHORT / isUnlocked`. A locked zone (not in profile.Zones)
  shows as a black silhouette with "?" and "???" in: hub portals (black filter on the portal and its frame, zone
  swirl effects off, dark swirl, nameplates "? ? ?", sign with the generic requirement; reveal on unlock = white
  flash + colors dissolving back + name), Zones menu (rows, preview, no sub-zone page for a hidden zone), weapon
  shop (zone row icon + name, locked tip), Index (zone group headers; refreshes on reveal), Pets / Premium eggs,
  Diamond shop eggs, armor / pet / hatch texts. Server refusals no longer name the zone (ZoneService UsePortal /
  Teleport, ShopService, PetService). Fix: `Icons.setFaded` no longer makes the "?" overlay opaque.
  1B Damage never depends on the zone. CAUSE found: the placeholder `CombatService` computed the hit as
  `Playtest.WeaponBaseDamage x 10^(currentZone - 1)` - the zone the player STOOD in - so walking from Plains into
  Desert multiplied damage by 10 (and by 100 in Jungle...). Second, smaller source: `Util/Stats.compute` added the
  weapon's Zone Boost in its home zone (and Config/Armor the armor Zone Boost). Now: the hit uses
  `Stats.compute(profile).WeaponDamage` (weapon's OWN zone base x category x rarity x attributes x pets x Rebirth
  Shop) and crits from Stats; new `Config/Balance.ZoneBoostEnabled = false` gates every Zone Boost (Stats, Armor);
  HUD Zone Boost badge, shop odds column, preview / case-opening / armor / equipment Zone Boost lines are hidden
  while it is false. Test: same loadout (Legendary Desert sword, Strength 10, Rebirth 1, Damage Boost 2, a pet, a
  Desert helmet) = 916.3 damage per hit and 650 Max HP in the Hub, Plains, Desert, Jungle and Tundra.
  StatsTests 78/78 (zone-boost cases follow the flag). Screenshots `docs/screenshots/enemies_task/1A_*`.
  Next: Part A (player combat).

## Decisions taken without the owner

- A hidden zone's row in the Zones menu does not open its sub-zone page (it would list the sub-zone names); a tap
  shows the generic requirement instead.
- Weapon silhouettes of locked zones stay as shapes (black, with "?"), like the existing shop rule; only names,
  colors, prices and zones are hidden.
- Attacks use `Net.send` (fire-and-forget) instead of `Net.request`: the server answers both the same way
  (`Net.handle`) and a melee hold loop must not wait for a round trip.
- Auto-Attack toggle on the HUD and the existing Settings > Controls > Auto-Attack are the same setting.
- Roll direction = the movement direction, or facing when standing still. While rolling the body fades (shows
  the i-frames).
- On PC the character turns toward the aim (mouse) when it attacks; on touch toward the nearest enemy in reach
  (+4 studs).
- Enemy config keeps the existing field names `MaxHP`, `Damage`, `Role` (used everywhere) and adds the brief's
  `Tier` ("normal" | "mini" | "boss"); HP / DMG of the brief = MaxHP / Damage.
- `profile.Trophies` is a map `[uid] = { id, rarity }` like the other inventories (DESIGN.md said array; updated),
  storage 100 (same as armor), a new trophy when full is sold at once with a toast. The trophy of an enemy is
  "<Enemy> Head" whatever the database item name (Corpse / Material / Trophy all become the head trophy, DESIGN 5).
- Trophy sales do not count for the "Earn Gold from enemies" quest (only kills do).
- Ranged enemies: archers, bats ("spit"), Toxic Frog (spit), Shaman (magic), Ice Spirit (ice shards). Flyers
  (seagull, bat, vulture, eagles) hover 4 studs; fish 1.5; djinn 1, ice spirit 1.5.
- Enemies do not collide with players (CanCollide off) so nobody gets stuck or pushed through walls; they keep
  apart from each other with a separation force.
- Mini-bosses are not knocked back but can be staggered by Heavy slams; bosses ignore both.
- Monsters chase only players inside their leash (60 studs from their spawn); a hit from farther away still pulls
  them, then they leash back if the attacker is out of range.

## Problems / missing

- The backup before Part A was forgotten; taken right after the Part A edits instead
  (`BackUP_Files/FightYourDestiny_2026-10-05_202520_partA_combat_*`). The scripts before Part A are in git commit
  67594b4, so nothing is lost.
