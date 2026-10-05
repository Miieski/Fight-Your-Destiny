"""Prints the Luau ICONS table for Config/Weapons.luau from Icons/asset_ids.json (weapon icons)."""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
data = json.load(open(os.path.join(ROOT, "Icons", "asset_ids.json"), encoding="utf-8"))
rows = []
for path, asset in data.items():
    m = re.match(r"Icons/Weapons/\w+/\d\d_([a-z]+_[a-z]+)_icon\.png$", path)
    if m:
        rows.append((m.group(1), asset))
print("-- Weapon icons (Icons/Weapons/<Category>/<NN>_<id>_icon.png), filled in as each category is made.")
print("local ICONS: { [string]: string } = {")
for wid, asset in sorted(rows):
    print(f'\t{wid} = "{asset}",')
print("}")
