# Rebirth zone unlock prices

Generated from the real prices in `Config/Zones` by `Config/RebirthZoneUnlock.luau`.

To open the next zone after a Rebirth, a player needs the boss key of the previous zone and pays this Gold. The zone must also be
reachable: the previous zone is open and the player has at least (zone number - 1) Rebirths.

Price = (last sub-zone of the previous zone + 2nd sub-zone of this zone) / 2, floored to 2 significant digits.

| from | to | last sub-zone | 2nd sub-zone | average | price |
|---|---|---:|---:|---:|---:|
| Plains | Desert | 3,125 | 5,000 | 4,062.5 | 4,000 |
| Desert | Jungle | 31,250 | 50,000 | 40,625 | 40,000 |
| Jungle | Tundra | 312,500 | 500,000 | 406,250 | 400,000 |
| Tundra | Cursed Swamp | 3,125,000 | 5,000,000 | 4,062,500 | 4,000,000 |
| Cursed Swamp | Volcano | 31.25M | 50M | 40.625M | 40M |
| Volcano | Hell | 312.5M | 500M | 406.25M | 400M |
| Hell | Heaven | 3.125B | 5B | 4.0625B | 4B |
| Heaven | Realm of the Dead | 31.25B | 50B | 40.625B | 40B |
| Realm of the Dead | Abyss | 312.5B | 500B | 406.25B | 400B |
| Abyss | Mechanical City | 3.125T | 5T | 4.0625T | 4T |
| Mechanical City | The Void | 31.25T | 50T | 40.625T | 40T |

Zone 1 (Plains) is free. To change the rounding, edit `SignificantDigits`; the table in the game follows.
