"""Batch runner for the V2 weapon models (headless Blender 5.x, opened on the icon template so the camera, lights
and world are the icons' own):

    blender --background Blender/Icons/_IconTemplate.blend --python tools/blender/run_weapons2.py -- Sword 1
    blender --background Blender/Icons/_IconTemplate.blend --python tools/blender/run_weapons2.py -- Sword 1 2 3
    blender --background Blender/Icons/_IconTemplate.blend --python tools/blender/run_weapons2.py -- --lineup Sword

Builder modules: fyd_w2_<category lower>.py with BUILDERS = [zone 1 builder, ..., zone 12 builder].
Results are written to tools/blender/_last_run.json and printed after "RUN_RESULTS ".
"""
import importlib
import json
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import fyd_weapons2 as W2  # noqa: E402

MODULES = {"Sword": "fyd_w2_swords", "Spear": "fyd_w2_spears", "Heavy": "fyd_w2_heavy", "Dagger": "fyd_w2_daggers",
           "Ranged": "fyd_w2_ranged", "Magic": "fyd_w2_magic"}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    results = []
    if args and args[0] == "--lineup":
        for category in args[1:]:
            results.append({"lineup": W2.lineup(category)})
    elif args:
        category = args[0]
        module = importlib.import_module(MODULES[category])
        for zone in [int(a) for a in args[1:]]:
            try:
                build = module.BUILDERS[zone - 1]
                results.append(W2.make_weapon(category, zone, build, notes=getattr(build, "notes", "")))
            except Exception as exc:  # one failure must not stop the batch (brief: log, skip, continue)
                results.append({"id": f"{category} {zone}", "error": f"{exc}", "trace": traceback.format_exc()[-2000:]})
    with open(os.path.join(HERE, "_last_run.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, indent=1, default=str)
    print("RUN_RESULTS " + json.dumps(results, default=str))


main()
