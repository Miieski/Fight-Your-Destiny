"""Batch runner: build creature models by id (headless Blender 5.x).

    blender --background --python tools/blender/run_creatures.py -- plains_boar plains_wild_wolf
    blender --background --python tools/blender/run_creatures.py -- --lineup Mobs 1 plains_boar plains_wild_wolf

Every recipe module (fyd_recipes_*.py) exposes RECIPES = {id: function() -> fyd_creatures.Model}.
Results (triangles, status, preview paths, errors) are written to tools/blender/_last_run.json.
"""
import glob
import importlib
import json
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import fyd_creatures as K  # noqa: E402


def registry():
    recipes = {}
    for path in sorted(glob.glob(os.path.join(HERE, "fyd_recipes_*.py"))):
        name = os.path.splitext(os.path.basename(path))[0]
        module = importlib.import_module(name)
        recipes.update(getattr(module, "RECIPES", {}))
    return recipes


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    results = []
    if args and args[0] == "--lineup":
        category, zone, ids = args[1], int(args[2]), args[3:]
        out = K.lineup(category, zone, ids)
        results.append({"lineup": out})
    else:
        recipes = registry()
        if args == ["--all"]:
            args = list(recipes.keys())
        for mid in args:
            try:
                model = recipes[mid]()
                results.append(K.make(model))
            except Exception as exc:  # one failure must not stop the batch (brief: log, skip, continue)
                results.append({"id": mid, "error": f"{exc}", "trace": traceback.format_exc()[-1500:]})
    with open(os.path.join(HERE, "_last_run.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, indent=1)
    print("RUN_RESULTS " + json.dumps(results))


main()
