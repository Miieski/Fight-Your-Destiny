# Rebirth Protection prices

Generated from `Config/RebirthProtection.luau`. The game computes the price on the server at purchase time.

Price (Diamonds) = ceil(RarityBase[rarity] x ValueFactor x CategoryMultiplier[category]), ValueFactor = 1 + 0.15 x (zone - 1).

The game has 8 rarities, so the proposed curve (x2.5 per step) goes on to Divine 1,200 and Secret 3,000. Pets from the 4 Robux species
count as zone 1. CategoryMultiplier is 1 for weapons, armor and pets today, so one table covers the three; to tune a category, change
its multiplier: the price is this table times the multiplier, rounded up.

| zone | Common | Uncommon | Rare | Epic | Legendary | Mythic | Divine | Secret |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 5 | 12 | 30 | 75 | 190 | 475 | 1,200 | 3,000 |
| 2 | 6 | 14 | 35 | 87 | 219 | 547 | 1,380 | 3,450 |
| 3 | 7 | 16 | 39 | 98 | 247 | 618 | 1,560 | 3,900 |
| 4 | 8 | 18 | 44 | 109 | 276 | 689 | 1,740 | 4,350 |
| 5 | 8 | 20 | 48 | 120 | 304 | 760 | 1,920 | 4,800 |
| 6 | 9 | 21 | 53 | 132 | 333 | 832 | 2,100 | 5,250 |
| 7 | 10 | 23 | 57 | 143 | 361 | 903 | 2,280 | 5,700 |
| 8 | 11 | 25 | 62 | 154 | 390 | 974 | 2,460 | 6,150 |
| 9 | 11 | 27 | 66 | 165 | 418 | 1,045 | 2,640 | 6,600 |
| 10 | 12 | 29 | 71 | 177 | 447 | 1,117 | 2,820 | 7,050 |
| 11 | 13 | 30 | 75 | 188 | 475 | 1,188 | 3,000 | 7,500 |
| 12 | 14 | 32 | 80 | 199 | 504 | 1,259 | 3,180 | 7,950 |
