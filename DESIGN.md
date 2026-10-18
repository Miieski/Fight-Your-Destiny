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

### UI for young players (owner 2026-10-13: "understandable for a 5 years old kid, avoid text, more visual")
* **Realistic wood:** panels, insets and light boards use tiling wood textures (Blender, `Icons/UiTex`:
  WoodPanel / WoodInset / WoodLight) with iron corner brackets (`Kit/Panel.wood`, `UI/WoodSkin` dresses every
  inset frame automatically); buttons have a glossy highlight. Same sizes as before.
* **Icons first:** every window title, tab and menu button has a picture (window titles and the small labels
  under the menu buttons stay). Sentences become pictures + numbers: `Kit/Chips` (heart 107, coin 6K,
  clock 7:57), check = done / equipped / owned, lock = closed, lock + skull + Rebirth = "beat the boss and
  Rebirth", gift = claim, grey gift = not yet, clock + time = wait, trash + coin price = sell / release,
  dice = odds, pin = teleport / you are here, star = best.
* **Details behind the (i):** full stat lists, odds, pity counters, rules and descriptions open from a blue
  (i) button (`Kit/Info`); tapping a quest's, attribute's or upgrade's picture shows what it does.
* **One funnel for filters:** every filter and sort of a list sits behind one funnel button (`Kit/Filter`)
  that opens rows of picture tiles (zone pictures, rarity colours, sort pictures); a red dot shows when a
  filter is on.
* **Stats:** the + button buys one point at once (price on the button; hold to repeat; quick taps are sent
  together); no confirm step.

### Audio
Music per zone (calm in the hub and early zones, intense for bosses); short, punchy SFX for
hits, rolls, blocks, UI clicks, drops, rarity reveals. All sounds are played by name through a
shared `Sfx` module (names listed in section 10).

## 2. Controls & combat

### Camera
Third person by default, freely adjustable by the player: zoom from 0.5 to 40 studs (all the
way in = first person), Shift-Lock toggle on PC, free drag on mobile. Settings > Controls has a
**First Person** switch (camera locked in the eyes; key V on PC by default). In first person or
Shift-Lock the cursor is free while a window is open, or while the Free Cursor key (Left Alt) is
held. A setting allows a more top-down angle.

### Input
| Action | PC | Mobile | Gamepad |
|---|---|---|---|
| Move | WASD | virtual joystick | left stick |
| Attack | mouse button 1 | big attack button (bottom right) | RT / R2 |
| Block | mouse button 2 (hold) | block button (hold) | LT / L2 (hold) |
| Roll/dodge | Q | roll button | B / Circle |
| Skills 1-3 | Z / X / C | 3 skill buttons around the attack button | LB / RB / Y |
| Open menus | hotkeys + buttons | HUD buttons | D-pad / menu |

Use `ContextActionService` so actions map to touch buttons automatically. Buttons must be
big, semi-transparent and movable in settings (position + size).

**Skill slots (framework, 2026-10-12):** the HUD shows 3 skill slots next to the equipped weapon
(the pet slots left the HUD; pets are equipped from the Pets window and the Equipment screen). Each
slot is ready for an icon, a cooldown sweep with the seconds left, a "not enough resource" shake and a
rarity / element frame; an empty slot shows a lock and the toast "Skills are coming soon". On touch
screens they are 3 round buttons around the attack button (movable like the others). The skills come
later: `Config/Skills` (empty list + schema), `SkillService` (`Net.request("UseSkill", slot)` answers
"not available"), profile `EquippedSkills`.

**Editable keys (PC):** every keyboard / mouse key is set in Settings > Keys (click a key, press
the new one; a key taken by another action swaps with it; Reset puts the defaults back). Defaults:
Attack left click, Block right click, Roll Q, Auto-Attack R, skills Z / X / C, First Person V, Free Cursor
Left Alt; menus Inventory B, Stats U, Shop G, Rebirth Y, Pets P, Index N, Quests J, Team T, Zones M,
Settings K. Mouse buttons only for Attack, Block and Roll. Keys Roblox or the game already use
(W A S D, arrows, Space, E, F, I, O, Shift, Escape, Tab, /, `, Enter, F2, F9-F12) are refused.
Gamepad buttons stay fixed. List and rules: `Config/Settings` KEY_ACTIONS.

### Attack rules
* **Melee categories** (Sword, Spear, Heavy, Dagger, Gauntlet): **hold** the
  attack input to attack continuously at the weapon's attack speed.
* **Ranged and Magic categories**: **one press = one shot** (click/tap). Holding does not
  auto-fire (unless the player owns the Auto-Attack pass).
* **Auto-Attack (paid game pass):** when enabled, the player automatically attacks the nearest
  enemy in range (melee) or fires at the nearest enemy (ranged/magic). Toggle button on the HUD.
* Weapon stats (damage, hits per second, range, shape) come from `docs/weapon_system_document.txt`.
* **Combos** (`Config/Combat` Combos): each attack is the next step of the category's combo (Sword 4, Spear 4, Heavy 3,
  Dagger 5, Gauntlet 3, Ranged 3, Magic 3 steps; the last one is a finisher). The average damage over a combo stays
  about x1 (the Gauntlet keeps its x2 third hit). The combo restarts after 0.8 s without attacking.
* **Jump attack** (combat V3, owner 2026-10-14: "a special animation when the character jump+attack"): attacking in the
  air (feet at least 1.2 studs above the ground) is the category's jump attack. Melee weapons hang a moment at the top,
  then dive so the body lands exactly at the hit: a shockwave circle around the landing point (Sword r 7, Spear 6.5,
  Heavy 9, Dagger 5, Gauntlet 7.5; x1.3 to x1.6 damage, knockback, stagger for Heavy / Gauntlet), counted as a finisher.
  Ranged: the body hovers and fires 3 arrows down at the nearest enemy (x0.6 each). Magic: hovers and drops a radius 9
  blast (x1.5). One jump attack per jump; the combo restarts after it. The server checks the player is airborne.
* **Dash strike** (Iron Soul style): an attack pressed during a roll or within 0.35 s after it is a long lunge out of
  the roll (6-8 studs; x1.2 to x1.4 damage), then the combo restarts.
* **Zone fighting styles** (owner 2026-10-14: "plains weapon will have a different animation than the void one"):
  every weapon moves in its zone's style, whatever its category (`Config/CombatStyles`): Plains Squire (the base),
  Desert Dune Dancer, Jungle Feral, Tundra Glacier, Swamp Hexblade, Volcano Berserker, Hell Demon, Heaven Seraph, Dead
  Revenant, Abyss Tidecaller, Mechanical Automaton, Void Voidwalker: own stance and idle, rhythm, swing size, a
  signature move on finishers and jump attacks, plus its own effect and sound accents. Styles never change the hit
  timing or the damage.

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
* **No death penalty** (owner 2026-10-13: "Remove the coin loss when you died"): no Gold or anything else is
  lost; the player just respawns.
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

### Upgrade menu ("Stats" button -> Attributes window)
* Superseded by the 8 attributes of `docs/menu_systems_brief.txt` Part A, **rebalanced 2026-10-12** (owner: "each
  attribute level should feel like a real upgrade; max only at the very end of the game"). Numbers in
  `Config/Attributes`; the window shows on each row what the NEXT point gives.
* 8 attributes x 40 points (attribute level L up to 320). Points above 20 in one attribute count half (soft cap).
* Price of the next point: `400 x 1.1 ^ L` Gold (x10 every ~24 levels). It does NOT depend on the zone: Gold income
  grows x10 per zone, so the affordable level grows with the zones - about 26 in zone 1, 160 in zone 6, 314 in zone
  12 when about one Rebirth cost of Gold (x the Rebirth Gold multiplier, x1.5 other bonuses) goes into attributes per
  zone. All 320 points only at the very end of the game.
* Per point (before the soft cap), x RebirthPower `1 + 0.25 x rebirths`: Vigor +10% Max HP, +0.1% HP/s regen; Mind
  +6% Gold, -1.2% roll cooldown; Endurance +2 Defense, +1 pt block, +0.8% move speed; weapon damage +8% x the weapon's
  scaling weight (Heavy / Ranged / Magic +9.6% for their S stat, Sword +4.8% each for Strength and Dexterity);
  Dexterity +0.5% attack speed; Intelligence +0.8 pt element proc, +1% magic radius; Faith +3% pet power and healing;
  Arcane +0.5 pt crit, +3% crit damage, +1% loot. Hard caps unchanged (block 85%, move +40%, attack speed +15%, proc
  +16 pts, radius +25%, crit 60%, roll 0.6 s).
* All attribute points reset to 0 on Rebirth. Respec (any time): 5 + 2 x zone Diamonds, and the Gold the points cost
  is given back (owner 2026-10-13; `Attributes.refundOf`: the price only depends on the level, so the refund is
  exactly what was paid).

### Armor (3 slots)
* Slots: `Helmet`, `Chest` (plastron), `Legs` (jambieres).
* **36 pieces: 1 set of 3 per zone.** Each piece has a rarity (same 8 tiers as weapons).
* An armor piece gives **Max HP** and **Defense**:
  * Piece HP = `100 x 10^(zone-1) x slotShare x rarityMult`, with slotShare Helmet 0.25,
    Chest 0.45, Legs 0.30 and rarityMult from the weapon doc (1.0 ... 25.0).
  * Piece Defense points = `3 x rarityTier` (Common 3 ... Secret 24), not zone-scaled.
* **Zone Boost:** like weapons, armor from a zone gets the rarity's Zone Boost (+5% ... +120%)
  on its HP and Defense while the player is in that zone.
* Armor is obtained as **loot** (enemies, mini-bosses, bosses) and, since 2026-10-15, in the **Shop > Armor**
  tab (owner: "a shop for Armors too, same as the weapon shop"): tabs Helmet / Chest / Legs, one card per zone,
  random rarity with the weapon shop's odds and pity rules but **its own pity counters** (`ArmorPityCounter`,
  `ArmorPityLegendary`), the same case opening. Price = **half the weapon price of the zone** (`Armor.price`,
  a full set = 1.5 weapons). A full armor storage (100) refuses the purchase. A piece bought for an empty slot
  is equipped when the opening ends. Armor is lost on Rebirth.
* Equipping a piece in a slot replaces the previous one (the old one goes to the inventory).

## 4. Economy & progression

### Currencies
* **Gold:** from killing enemies, selling trophies, quests and rewards. Never lost on death (since 2026-10-13);
  lost entirely on Rebirth. Values scale x10 per zone.
* **Diamonds:** premium currency. Dropped ONLY by mini-bosses and bosses, and sold for Robux.
  **Kept on Rebirth.** Uses: premium eggs, Gold boosts, skins (the weapon rarity reroll was removed on
  2026-10-13).
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
* **Where (built 2026-10-12):** the **Rebirth** menu button (hotkey Y) opens the Rebirth window: tab
  **Rebirth** (next Rebirth, requirements, rewards, what is lost / kept, Rebirth button + confirmation) and tab
  **Rebirth Shop**. The Priest at the Rebirth Altar opens the Rebirth tab. Refused inside a boss arena and within
  5 s of taking damage. After a Rebirth the player is sent to sub-zone 1 of zone r with a free Common sword of
  that zone (starter weapon rule); reopening zone r's boss room ("redone") opens zone r + 1 (zone unlock chain
  below). Rules in `Config/Rebirth`, server `RebirthService`, UI `UI/Pages/RebirthPage`.

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
* An enemy **respawns 6 seconds after it dies** (2 s until 2026-10-12; `Config/Enemies.RESPAWN_SECONDS`).
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
* **Pets V2 (owner 2026-10-12, inspired by the Roblox game Steal an Egg; `docs/pets_v2_plan.md`):**
  * 72 species (6 per zone, same stat roles per slot) + 4 premium, list in `Config/Pets` (zone 1: Puppy,
    Fox Kit, Bear Cub, Boar Piglet, Raccoon, Owl; Volcano mixes in baby dinosaurs; Abyss = sea animals).
  * Every egg hatch also rolls a **mutation** - Silver x1.2 (8%), Golden x1.5 (4%), Rainbow x2 (0.9%),
    Celestial x3 (0.1%) - and a **size** - Big x1.25 (9%), Huge x1.6 (1%), drawn 1.35x / 1.8x bigger.
    Both multiply the pet's main stats, bonus, Equip Best score and release value (`Config/PetMutations`).
    Premium pets never mutate. Shown on the hatch reveal, pet cards, details and the Index (best mutation).
  * Models: cartoon meshes from Studio's AI generator, rigged by `DevTools/PetRigBuilder` (pieces + joints),
    animated in code by `Util/PetMotion` (walk cycle, wings, swim, float, idle, happy jump on kills); mutation
    looks by `Util/PetLook` (see-through metal / gold / rainbow / glowing shells). 12 zone eggs in the same style.
  * **Bonus Stats (owner 2026-10-13, after a "Rare Celestial Axolotl" card):** every pet rolls 3 items at hatching
    (pets owned before get theirs once on join) - a **Crown**, an **Accessory** and an **Aura**. Each item has its
    own rarity (Common 50%, Uncommon 25%, Rare 13%, Epic 7%, Legendary 3.3%, Mythic 1.2%, Divine 0.4%, Secret
    0.1%) and one random stat: Damage, Max HP, Defense, Speed, Gold, Luck, Crit Damage or All (all six at once,
    smaller). Value = the stat's Common value (2% / 1.5% speed / 2.5% Gold / 3% crit / 0.7% All) x the rarity
    (x1 .. x14) x a roll of 0.8-1.2. So a pet's stats = its species and rarity + mutation / size + its items.
    The item IS the slot's item of that rarity (Leaf Crown .. Rainbow Crown, Bandana .. Star Pendant, Aura of
    Dust .. Cosmic Aura): the pet wears it (AI-made crowns / collars, particle auras, `Util/PetGear`), so the look
    tells the rarity. Items raise the release value ("Worth", +10% per tier above Common) and the "Power" score
    (Equip Best). Shown on the pet card (Power, Worth, 3 item cards like the reference), as rarity dots in the
    grid, and popping in one by one on the hatch reveal. Rules: `Config/PetTraits`.
  * **Hatching (big and flashy, 2026-10-13):** the egg drops in and bounces, shakes harder and harder while a
    glow and turning light rays build up (in the pet's rarity colour near the end), shell chips fly at each
    crack; then a white flash, the rarity burst, confetti (more for rarer pets), a screen shake from Legendary;
    the pet pops in with a hop and its items pop in. Tap to skip; Fast Open shortens it; Low FX drops the extras.
  * **Real cracking (owner 2026-10-18: "crack bit by bit and then break, just like a real egg", keep the egg skins):**
    `UI/EggCrack` reads the zone egg's own mesh (EditableMesh): thin dark cracks spread over the skin in 4 bursts
    (a starburst at the hit, a zigzag around the middle, up between the pieces, around the cap), widen and glow
    in the pet's rarity colour, then the shell breaks along exactly those cracks into skinned pieces (white inside):
    the cap pops off, 5 shards fall (3 with Low FX), the cup fades; a new pattern every hatch. Normal hatch 3.4 s
    (was 2.6). **Needs the place setting "Allow Mesh & Image APIs" (Game Settings > Security)**; without it the
    flat 2D cracks and flash are used.
* A pet follows the player visually (no collision, light on performance: max 3 followers).

## 6. Weapons (reference)
Full rules in `docs/weapon_system_document.txt`: 7 categories x 12 zones = 84 weapons, random
rarity on purchase, damage = zone base x category x rarity, Zone Boost in the home zone.
Changes for this design:
* Weapons are bought with **Gold** at the hub weapon shop.
* **No rarity reroll** (removed 2026-10-13). Instead a weapon can be **sold for Gold** (Inventory > Weapons, red
  trash button): 20% of its shop price x the rarity's damage multiplier (Common Plains 200, Rare 440). The
  equipped weapon cannot be sold; Epic and better ask first.
* **Inventory filters and multi-sell** (owner 2026-10-15): the Weapons, Armor and Trophies tabs have one funnel
  (Weapons: category, rarity, zone, sort; Armor: slot, rarity, zone, sort; Trophies: rarity, zone; the zone row
  only lists zones the player has items from) and a **select mode** (check button): taps tick items, "All" ticks
  every shown item, the trash button sells the ticked ones in one request after a confirm (it says how many are
  Epic or better). Equipped weapons, worn and locked armor are dimmed and never sold (also refused by the server:
  Net "SellWeapons" / "SellArmors" / "SellTrophies", max 300 uids). Ticked items hidden by a filter are unticked.
* **Weapons are lost on Rebirth.**
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
* **Death in a boss arena (default):** the player loses nothing (no death penalty) and is removed from
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
* **Weapon Shop:** buy a weapon of a chosen zone; rarity is random (weapon doc). The Shop window also has an
  **Armor** tab (same rules, half price, own pity counters).
* **Trainer:** stat upgrade menu.
* **Egg Station:** hatch eggs, open premium eggs (diamonds). **Pet Manager** (equip/delete). The nest shows the
  game's own Plains / Desert / Jungle zone eggs (`Assets.Eggs`, 2026-10-18).
* **Benches** (11, 2 seats each): one "Sit" prompt per bench (E / tap) seats the player on the nearest free seat;
  touching a bench never seats anyone; jump to stand up (`BenchService`).
* **Trophy Merchant:** sells head trophies.
* **Rebirth Altar** and **Rebirth Shop.**
* **Diamond Shop:** Robux packs, boosts, skins, game passes.
* **Zone Portals:** one per zone, grayed out when locked (shows requirements). Walking into an
  unlocked portal teleports the player **directly to sub-zone 1** of that zone (no sub-zone
  choice; the Zones menu in the HUD is where a sub-zone is chosen).
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
gates, teleports, death respawn) - `ShopService` (weapons, armor, training, premium eggs) -
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
  Pets = {},                           -- [uid] = { id = "plains_pet1", rarity = 1, premium = false, mutation?, size?,
                                       --   traits = { Crown = { rarity, stat, roll }, Accessory = {..}, Aura = {..} } }
  EquippedPets = {},                   -- array of uids
  EquippedSkills = {},                 -- [slot 1..3] = skill id (Config/Skills; empty for now)
  Trophies = {},                       -- [uid] = { id = "plains_boar", rarity = 1 } (head trophies, max 100)
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
  ArmorPityCounter = 0, ArmorPityLegendary = 0,   -- armor shop pity (same rules, own counters)
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
`plains_sword`, `void_magic`). Armor `<zoneId lower>_<helmet|chest|legs>`. Rarities (1..8):
`Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Secret`. Stats `MaxHP, Attack, Defense,
Speed, Crit, GoldGain`. Weapon categories `Sword, Spear, Heavy, Dagger, Gauntlet, Ranged, Magic` (Whip & Chain removed on 2026-10-12).

## 13. Admin panel (owner only)

* Opened with F2 or a small crown button, visible only to UserIds in `Config/Admins.luau`
  (**checked on the server for every command**; the client button is only cosmetic).
* Commands: set/give Gold and Diamonds, set Rebirths and give keys, unlock any zone/sub-zone,
  teleport to any zone or boss room, give any weapon/armor/pet at a chosen rarity, kill the
  current boss, heal / invincibility, spawn an enemy, force a boss pattern, toggle boosts,
  reset my data.
* **V2 (owner 2026-10-13: "I want to test every possibility in game").** `UI/AdminPanel`, 8 tabs (owner-only, so
  plain text labels): **Money** (Gold, Diamonds, Rebirth Credits, boss keys, Gold Boost, game passes on / off),
  **Swords** (any weapon by zone x category x rarity, a zone's 7, all 84, shop rarity / pity, reset), **Armor**
  (piece or set x rarity x count, every zone's set, clear), **Pets** (zone or Premium -> pet, rarity, mutation, size,
  Bonus Stats item rarity; zone's pets; new items for every pet; eggs; Equip best; egg simulation; clear),
  **Stats** (each attribute 0..40, all at once, Rebirths, Rebirth ready / wipe, Rebirth Shop levels), **World**
  (teleports, zone locks, any enemy of a zone: spawn / loot / trophies / kill simulation / kill all, god mode,
  heal, hits), **Gifts** (complete any quest - today's are green -, play time, daily streak states, Index),
  **Tests** (notifications, fake equipment, badges, checks, save now, reset to a new player). Pickers are rows of
  buttons (the chosen one is gold), live lines show the current values, risky commands ask first. Every command
  is still checked on the server (`AdminService`, `Net.request("Admin", cmd, ...)`).
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
* **All 84 weapons and 36 armor pieces are built from the start** (config + models). Items of
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
* Player stats (section 3) are replaced by **Elden Ring-style Attributes** (Vigor, Mind, Endurance,
  Strength, Dexterity, Intelligence, Faith, Arcane); full rules in `docs/menu_systems_brief.txt`.
  The profile field `Stats` becomes `Attributes`.
* Armor is equipped from the **Inventory -> Equipment** tab (character view with slots around it).
* **No spoilers:** locked zones (not in `profile.Zones`) appear as black "?" silhouettes with the name `???`
  in every UI and on the hub portals. Damage never depends on the player's current or highest zone;
  the Zone Boost is disabled by `Config.Balance.ZoneBoostEnabled = false` until the owner decides.
* Models are stored in `Blender/<Category>/<NN_Zone>/` (NPC, Mobs, MiniBosses, Bosses, Pets).

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
