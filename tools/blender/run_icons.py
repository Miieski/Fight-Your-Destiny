"""Headless batch runner for the UI icons (opened on the icon template so camera, lights and world are set):

    blender --background Blender/Icons/_IconTemplate.blend --python tools/blender/run_icons.py -- Ui
    blender --background Blender/Icons/_IconTemplate.blend --python tools/blender/run_icons.py -- Ui Clock Gift

Recipes: fyd_icon_recipes3.RECIPES (group "Ui"). Writes Icons/<group>/<id>.png, Blender/Icons/<group>/<id>.blend
and a contact sheet Previews/Icons/<group>_sheet.png; prints "RUN_RESULTS <json>".
"""
import json
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import fyd_icons as I  # noqa: E402
import fyd_icon_recipes3 as R3  # noqa: E402


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    group = args[0] if args else "Ui"
    recipes = R3.RECIPES[group]
    ids = args[1:] or list(recipes.keys())
    results, pngs = [], []
    for icon_id in ids:
        try:
            out = I.make_icon(group, icon_id, recipes[icon_id])
            pngs.append(out["png"])
            results.append({"id": icon_id, "png": out["png"]})
        except Exception as exc:
            results.append({"id": icon_id, "error": str(exc), "trace": traceback.format_exc()[-1500:]})
    if pngs:
        sheet = os.path.join(I.ROOT, "Previews", "Icons", f"{group}_sheet.png")
        os.makedirs(os.path.dirname(sheet), exist_ok=True)
        I.make_sheet(pngs, sheet, cols=6)
        results.append({"sheet": sheet})
    print("RUN_RESULTS " + json.dumps(results))


main()
