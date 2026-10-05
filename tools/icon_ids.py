"""Keeps Icons/asset_ids.json: uploaded icon path -> rbxassetid.

    python tools/icon_ids.py add '<json map from the upload tool>'
    python tools/icon_ids.py missing Icons/Menu Icons/Currency ...   (prints URLs not uploaded yet)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "Icons", "asset_ids.json")
PREFIX = "http://127.0.0.1:8765/"


def load():
    if os.path.exists(DB):
        with open(DB, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save(data):
    with open(DB, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(data.items())), f, indent=1)


if __name__ == "__main__":
    cmd = sys.argv[1]
    data = load()
    if cmd == "add":
        new = json.loads(sys.argv[2])
        for url, asset in new.items():
            data[url.replace(PREFIX, "")] = asset
        save(data)
        print(len(data), "ids stored")
    elif cmd == "missing":
        out = []
        for folder in sys.argv[2:]:
            for name in sorted(os.listdir(os.path.join(ROOT, folder))):
                rel = folder.replace("\\", "/") + "/" + name
                if name.endswith(".png") and rel not in data:
                    out.append(PREFIX + rel)
        print(json.dumps(out))
        print(len(out), "missing")
