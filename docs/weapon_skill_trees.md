# Weapon skill trees

Data: `Config/WeaponSkillTrees.luau`, `Config/WeaponSpecials.luau`, `Config/WeaponMastery.luau`. One tree per weapon type, 25 nodes, 53 points for a
full tree, kept for life (a Rebirth never touches them).

- **Mastery XP:** 1 per hit, 6 per normal kill, 40 per mini-boss, 120 per boss, at most 900 per minute. XP to reach level L = 60 x L ^ 1.4. 1 point per
  level, max level 60. Points only go in the tree of the weapon type that earned them.
- **Free picks:** 3 for the whole profile, any node in any tree (prerequisites still count). A tree where one is used counts as opened.
- **Opening a tree (Gold, once):** Sword 0 (open), Spear 500, Dagger 1,500, Heavy 5,000, Ranged 15,000, Magic 50,000.
- **Respec:** free for 10 minutes after the first free pick, then 2,000 Gold per tree. Free picks come back.
- **Equipped special attacks:** at most 3 per weapon type, on keys X / C / T (Z stays the weapon's skill).
- **No stamina in the game:** cooldown nodes instead; mana nodes for the staff. Attack speed from nodes counts inside the +100% cap.

## Balance notes

- A full melee tree gives +20% damage, +9% attack speed (inside the +100% cap), +4% crit chance, +8% crit damage, -10% cooldowns, +33% finisher
  damage, +4% block and +8% reach (read on a real Play for the sword: damage 3.4 to 4.1, cooldown factor .90, finisher .33).
- Damage figures below are the move's Damage field, multiplied by the weapon as for the Z skill. Specials cost 9-14 s of cooldown, ultimates 22-26 s.
  These are first numbers: nothing was balanced in a real play session yet.
- Effects of a special attack come from its `Fx` (the look of the Z skill, the heavy, the dash or the jump attack) and a clip the weapon already has;
  there are no new clips.

## Shared map

Root -> three paths (A power, B speed, C technique). Each path: 1 -> 2 and 3 -> 4 (one of 2 / 3 is enough) -> 5 and 6. Then J1 (A6 or B5), J2 (B6 or C5),
M (J1 or J2), and the ultimates U1, U2, U3 (all need M). Cost: 1 for steps 1-3, 2 for steps 4-6, 3 for J, 4 for M, 5 for U.

## Sword

| node | name | effect | cost | needs |
|---|---|---|---:|---|
| Root | Damage 1 | +4% damage | 1 | - |
| A1 | Damage 2 | +4% damage | 1 | Root |
| A2 | Damage 3 | +4% damage | 1 | A1 |
| A3 | Crit damage 1 | +8% crit damage | 1 | A1 |
| A4 | Whirlwind | Special: Circle, Damage 3.2 x 2 hits, cooldown 10 s | 2 | A2 or A3 |
| A5 | Damage 4 | +4% damage | 2 | A4 |
| A6 | Finisher 1 | +8% finisher damage | 2 | A4 |
| B1 | Attack speed 1 | +3% attack speed | 1 | Root |
| B2 | Attack speed 2 | +3% attack speed | 1 | B1 |
| B3 | Cooldowns 1 | -5% skill cooldowns | 1 | B1 |
| B4 | Piercing Drive | Special: Line, Damage 7, cooldown 12 s | 2 | B2 or B3 |
| B5 | Crit chance 1 | +2% crit chance | 2 | B4 |
| B6 | Attack speed 3 | +3% attack speed | 2 | B4 |
| C1 | Guard 1 | +2% block | 1 | Root |
| C2 | Reach 1 | +4% attack reach | 1 | C1 |
| C3 | Guard 2 | +2% block | 1 | C1 |
| C4 | Cross Cut | Special: Arc, Damage 3.6 x 2 hits, cooldown 9 s | 2 | C2 or C3 |
| C5 | Reach 2 | +4% attack reach | 2 | C4 |
| C6 | Cooldowns 2 | -5% skill cooldowns | 2 | C4 |
| J1 | Damage 5 | +4% damage | 3 | A6 or B5 |
| J2 | Crit chance 2 | +2% crit chance | 3 | B6 or C5 |
| M | Rising Gale | Special: Circle, Damage 6, cooldown 14 s | 4 | J1 or J2 |
| U1 | Aura of Mastery | Passive: a glowing aura while this weapon type is in hand | 5 | M |
| U2 | Thousand Cuts | Ultimate special: Circle, Damage 3 x 6 hits, cooldown 24 s | 5 | M |
| U3 | Final Form | Passive: +25% finisher damage, a stronger last hit | 5 | M |

## Spear

| node | name | effect | cost | needs |
|---|---|---|---:|---|
| Root | Damage 1 | +4% damage | 1 | - |
| A1 | Damage 2 | +4% damage | 1 | Root |
| A2 | Damage 3 | +4% damage | 1 | A1 |
| A3 | Crit damage 1 | +8% crit damage | 1 | A1 |
| A4 | Javelin Burst | Special: Line, Damage 6, cooldown 10 s | 2 | A2 or A3 |
| A5 | Damage 4 | +4% damage | 2 | A4 |
| A6 | Finisher 1 | +8% finisher damage | 2 | A4 |
| B1 | Attack speed 1 | +3% attack speed | 1 | Root |
| B2 | Attack speed 2 | +3% attack speed | 1 | B1 |
| B3 | Cooldowns 1 | -5% skill cooldowns | 1 | B1 |
| B4 | Dragon Tail | Special: Circle, Damage 3.4 x 2 hits, cooldown 12 s | 2 | B2 or B3 |
| B5 | Crit chance 1 | +2% crit chance | 2 | B4 |
| B6 | Attack speed 3 | +3% attack speed | 2 | B4 |
| C1 | Guard 1 | +2% block | 1 | Root |
| C2 | Reach 1 | +4% attack reach | 1 | C1 |
| C3 | Guard 2 | +2% block | 1 | C1 |
| C4 | Phalanx Thrust | Special: Arc, Damage 2.4 x 3 hits, cooldown 9 s | 2 | C2 or C3 |
| C5 | Reach 2 | +4% attack reach | 2 | C4 |
| C6 | Cooldowns 2 | -5% skill cooldowns | 2 | C4 |
| J1 | Damage 5 | +4% damage | 3 | A6 or B5 |
| J2 | Crit chance 2 | +2% crit chance | 3 | B6 or C5 |
| M | Vault Strike | Special: Circle, Damage 6, cooldown 14 s | 4 | J1 or J2 |
| U1 | Aura of Mastery | Passive: a glowing aura while this weapon type is in hand | 5 | M |
| U2 | Heaven Piercer | Ultimate special: Line, Damage 9 x 2 hits, cooldown 24 s | 5 | M |
| U3 | Final Form | Passive: +25% finisher damage, a stronger last hit | 5 | M |

## Heavy (hammer)

| node | name | effect | cost | needs |
|---|---|---|---:|---|
| Root | Damage 1 | +4% damage | 1 | - |
| A1 | Damage 2 | +4% damage | 1 | Root |
| A2 | Damage 3 | +4% damage | 1 | A1 |
| A3 | Crit damage 1 | +8% crit damage | 1 | A1 |
| A4 | Quake | Special: Circle, Damage 5, cooldown 12 s | 2 | A2 or A3 |
| A5 | Damage 4 | +4% damage | 2 | A4 |
| A6 | Finisher 1 | +8% finisher damage | 2 | A4 |
| B1 | Attack speed 1 | +3% attack speed | 1 | Root |
| B2 | Attack speed 2 | +3% attack speed | 1 | B1 |
| B3 | Cooldowns 1 | -5% skill cooldowns | 1 | B1 |
| B4 | Hammer Spin | Special: Circle, Damage 2.6 x 3 hits, cooldown 11 s | 2 | B2 or B3 |
| B5 | Crit chance 1 | +2% crit chance | 2 | B4 |
| B6 | Attack speed 3 | +3% attack speed | 2 | B4 |
| C1 | Guard 1 | +2% block | 1 | Root |
| C2 | Reach 1 | +4% attack reach | 1 | C1 |
| C3 | Guard 2 | +2% block | 1 | C1 |
| C4 | Titan Drop | Special: Circle, Damage 7, cooldown 14 s | 2 | C2 or C3 |
| C5 | Reach 2 | +4% attack reach | 2 | C4 |
| C6 | Cooldowns 2 | -5% skill cooldowns | 2 | C4 |
| J1 | Damage 5 | +4% damage | 3 | A6 or B5 |
| J2 | Crit chance 2 | +2% crit chance | 3 | B6 or C5 |
| M | Shatter | Special: Arc, Damage 5.5, cooldown 10 s | 4 | J1 or J2 |
| U1 | Aura of Mastery | Passive: a glowing aura while this weapon type is in hand | 5 | M |
| U2 | World Breaker | Ultimate special: Circle, Damage 9 x 2 hits, cooldown 26 s | 5 | M |
| U3 | Final Form | Passive: +25% finisher damage, a stronger last hit | 5 | M |

## Dagger

| node | name | effect | cost | needs |
|---|---|---|---:|---|
| Root | Damage 1 | +4% damage | 1 | - |
| A1 | Damage 2 | +4% damage | 1 | Root |
| A2 | Damage 3 | +4% damage | 1 | A1 |
| A3 | Crit damage 1 | +8% crit damage | 1 | A1 |
| A4 | Shadow Step | Special: Line, Damage 5, cooldown 9 s | 2 | A2 or A3 |
| A5 | Damage 4 | +4% damage | 2 | A4 |
| A6 | Finisher 1 | +8% finisher damage | 2 | A4 |
| B1 | Attack speed 1 | +3% attack speed | 1 | Root |
| B2 | Attack speed 2 | +3% attack speed | 1 | B1 |
| B3 | Cooldowns 1 | -5% skill cooldowns | 1 | B1 |
| B4 | Viper Flurry | Special: Arc, Damage 1.5 x 5 hits, cooldown 10 s | 2 | B2 or B3 |
| B5 | Crit chance 1 | +2% crit chance | 2 | B4 |
| B6 | Attack speed 3 | +3% attack speed | 2 | B4 |
| C1 | Guard 1 | +2% block | 1 | Root |
| C2 | Reach 1 | +4% attack reach | 1 | C1 |
| C3 | Guard 2 | +2% block | 1 | C1 |
| C4 | Fan of Blades | Special: Circle, Damage 2.8 x 2 hits, cooldown 11 s | 2 | C2 or C3 |
| C5 | Reach 2 | +4% attack reach | 2 | C4 |
| C6 | Cooldowns 2 | -5% skill cooldowns | 2 | C4 |
| J1 | Damage 5 | +4% damage | 3 | A6 or B5 |
| J2 | Crit chance 2 | +2% crit chance | 3 | B6 or C5 |
| M | Backstab | Special: Line, Damage 8, cooldown 12 s | 4 | J1 or J2 |
| U1 | Aura of Mastery | Passive: a glowing aura while this weapon type is in hand | 5 | M |
| U2 | Death Lotus | Ultimate special: Circle, Damage 2.8 x 6 hits, cooldown 22 s | 5 | M |
| U3 | Final Form | Passive: +25% finisher damage, a stronger last hit | 5 | M |

## Ranged (bow)

| node | name | effect | cost | needs |
|---|---|---|---:|---|
| Root | Damage 1 | +4% damage | 1 | - |
| A1 | Damage 2 | +4% damage | 1 | Root |
| A2 | Damage 3 | +4% damage | 1 | A1 |
| A3 | Crit damage 1 | +8% crit damage | 1 | A1 |
| A4 | Scatter Shot | Special: Projectile, Damage 2 x 5 hits, cooldown 8 s | 2 | A2 or A3 |
| A5 | Damage 4 | +4% damage | 2 | A4 |
| A6 | Finisher 1 | +8% finisher damage | 2 | A4 |
| B1 | Attack speed 1 | +3% attack speed | 1 | Root |
| B2 | Attack speed 2 | +3% attack speed | 1 | B1 |
| B3 | Cooldowns 1 | -5% skill cooldowns | 1 | B1 |
| B4 | Piercing Arrow | Special: Projectile, Damage 6, cooldown 10 s | 2 | B2 or B3 |
| B5 | Crit chance 1 | +2% crit chance | 2 | B4 |
| B6 | Attack speed 3 | +3% attack speed | 2 | B4 |
| C1 | Arrow speed 1 | +8% projectile speed | 1 | Root |
| C2 | Arrow speed 2 | +8% projectile speed | 1 | C1 |
| C3 | Cooldowns 2 | -5% skill cooldowns | 1 | C1 |
| C4 | Snipe | Special: Projectile, Damage 12, cooldown 14 s | 2 | C2 or C3 |
| C5 | Crit chance 2 | +2% crit chance | 2 | C4 |
| C6 | Arrow speed 3 | +8% projectile speed | 2 | C4 |
| J1 | Damage 5 | +4% damage | 3 | A6 or B5 |
| J2 | Crit chance 3 | +2% crit chance | 3 | B6 or C5 |
| M | Arrow Rain | Special: AoE, Damage 2.6 x 3 hits, cooldown 13 s | 4 | J1 or J2 |
| U1 | Aura of Mastery | Passive: a glowing aura while this weapon type is in hand | 5 | M |
| U2 | Storm Volley | Ultimate special: Projectile, Damage 3.4 x 9 hits, cooldown 24 s | 5 | M |
| U3 | Final Form | Passive: +25% finisher damage, a stronger last hit | 5 | M |

## Magic (staff)

| node | name | effect | cost | needs |
|---|---|---|---:|---|
| Root | Damage 1 | +4% damage | 1 | - |
| A1 | Damage 2 | +4% damage | 1 | Root |
| A2 | Damage 3 | +4% damage | 1 | A1 |
| A3 | Crit damage 1 | +8% crit damage | 1 | A1 |
| A4 | Fire Wave | Special: Circle, Damage 4, cooldown 9 s, 20 mana | 2 | A2 or A3 |
| A5 | Damage 4 | +4% damage | 2 | A4 |
| A6 | Finisher 1 | +8% finisher damage | 2 | A4 |
| B1 | Attack speed 1 | +3% attack speed | 1 | Root |
| B2 | Attack speed 2 | +3% attack speed | 1 | B1 |
| B3 | Cooldowns 1 | -5% skill cooldowns | 1 | B1 |
| B4 | Meteor | Special: AoE, Damage 7, cooldown 12 s, 30 mana | 2 | B2 or B3 |
| B5 | Crit chance 1 | +2% crit chance | 2 | B4 |
| B6 | Attack speed 3 | +3% attack speed | 2 | B4 |
| C1 | Mana 1 | +8% max mana | 1 | Root |
| C2 | Mana flow 1 | +8% mana regen | 1 | C1 |
| C3 | Mana 2 | +8% max mana | 1 | C1 |
| C4 | Ember Barrage | Special: Fireball, Damage 2.2 x 5 hits, cooldown 10 s, 25 mana | 2 | C2 or C3 |
| C5 | Mana thrift 1 | -5% mana costs | 2 | C4 |
| C6 | Mana flow 2 | +8% mana regen | 2 | C4 |
| J1 | Damage 5 | +4% damage | 3 | A6 or B5 |
| J2 | Crit chance 2 | +2% crit chance | 3 | B6 or C5 |
| M | Phoenix Burst | Special: Circle, Damage 4 x 2 hits, cooldown 14 s, 35 mana | 4 | J1 or J2 |
| U1 | Aura of Mastery | Passive: a glowing aura while this weapon type is in hand | 5 | M |
| U2 | Inferno Storm | Ultimate special: AoE, Damage 5 x 3 hits, cooldown 24 s, 55 mana | 5 | M |
| U3 | Final Form | Passive: +25% finisher damage, a stronger last hit | 5 | M |
