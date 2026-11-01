# Boss rewards: diamonds for every victory

Owner prompt Round 9 part 6. Config: `src/ReplicatedStorage/GameSystem/Config/BossRewards.luau`. Paid by `BossService` (`rewardEnemy`).

Every victory over a mini-boss or a boss pays diamonds, not only the first one. Mini-boss: 3 x zone index. Boss: 10 x zone index. Each player who qualifies gets the full amount; it is never split.

| zone | index | mini-boss | boss | a whole fight (2 minis + boss) | can be fought today |
|---|---:|---:|---:|---:|---|
| Plains | 1 | 3 | 10 | 16 | yes |
| Desert | 2 | 6 | 20 | 32 | yes |
| Jungle | 3 | 9 | 30 | 48 | yes |
| Tundra | 4 | 12 | 40 | 64 | yes |
| Cursed Swamp | 5 | 15 | 50 | 80 | no |
| Volcano | 6 | 18 | 60 | 96 | no |
| Hell | 7 | 21 | 70 | 112 | no |
| Heaven | 8 | 24 | 80 | 128 | no |
| Realm of the Dead | 9 | 27 | 90 | 144 | no |
| Abyss | 10 | 30 | 100 | 160 | no |
| Mechanical City | 11 | 33 | 110 | 176 | no |
| The Void | 12 | 36 | 120 | 192 | no |

The table is built from `Config/Zones`, so zones 5 to 12 pay as soon as `Bosses.PLAYABLE_ZONES` opens them and their boss has a Rig. No code change.

## Who is paid

The rule is the one the Gold of the room already used, unchanged:

- A player is paid for an enemy if, when that enemy dies, they are still in the room and they dealt at least 5 % of its HP (`Bosses.REWARD_MIN_SHARE`).
- A player who died and is watching as a spectator is still in the room: paid, if they had dealt the 5 %. Enemy by enemy: a player who dealt 5 % of a mini-boss but under 5 % of the boss gets the mini-boss only.
- A player who left or disconnected is out of the room: paid for what died before they left, nothing after.
- Room wiped before the boss: what died before the wipe stays paid. Nothing is taken back.
- A team shares the fight, not the reward: 5 players can each get the full amount. The Boss has more HP with more players (x (1 + 0.6 x (players - 1))), so the 5 % is on that bigger total.

## Rules

- Server only. The client gets the Victory lines and the new count, it sends nothing.
- Once per enemy of the fight per player: `room.paid[enemy id][player]`, set by `BossRewards.settle`. If the death of an enemy were handled twice, the second pass gives nothing at all, Gold and rolls included. A new fight is a new room, so the 2nd, 3rd... victory pays again.
- Saved at once: the room's `DataService:Save(player)` that ends each enemy's reward. If it fails the autosave retries.
- Diamonds are not touched by Rebirth (`Config/Rebirth.Kept`, `RebirthService.planReset`).
- Gold, keys and item drops: unchanged.

## The old random drop stays

The room already had a random diamond drop: mini-boss 15 % (2 + z, 3 + z), boss 40 % (10 + 3z), chance x (1 + Diamond Luck). It is NOT removed: the brief said no change to drops, and the Diamond Luck upgrade of the Rebirth Shop and the pet bonus only act on it. It now reads "13 Bonus Diamonds (Golem)" on the Victory screen, on top of the fixed amount.

So a fight pays the table above plus sometimes a bonus. To remove the bonus: delete the `Enemies.DIAMONDS` roll in `rewardEnemy`, but then Diamond Luck does nothing.

## Victory screen

`UI/BossRoom.luau`. One line per enemy with the diamond icon, right after its Gold line: "10 Diamonds (Cursed Pharaoh)". The list holds 7 rows on PC, 5 on a phone, then it scrolls. Rare loot and the key come first, so they are never the hidden rows.

## Check

- `print(require(game.ReplicatedStorage.GameSystem.Config.BossRewards).selfCheck())`: all 12 zones, teams of 1 to 5 paid in full, a second payout empty, a retry pays only who was not paid.
- Sheet: `docs/before_after/R9-06_victory.png`. Test numbers: `docs/NIGHT_LOG.md`, Part 6.
- Not tested: a real fight with 2 players or more. See the log.
