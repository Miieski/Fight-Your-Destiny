"""Batch runner of the prop pipeline (headless Blender 5.x, or exec'd from the Blender MCP).

    blender --background --factory-startup --python tools/blender/fyd_props_run.py -- well chest
    ... -- --all                      every recipe of tools/blender/fyd_props_recipes*.py
    ... -- --lineup Pilot well        lineup picture Previews/Props/Pilot_lineup.png (real relative scale)
    ... -- --photo-lineup LowPoly_lineup_1 well chest
                                      the same with the reference photos in a strip underneath (same order)
    ... -- --init-manifest            create the missing rows of Blender/Props/props_manifest.csv
    ... -- --luau                     regenerate Blender_Exports/Props/PropMeshData.luau only
    ... -- --preview-png well chest   (re)write Blender_Exports/Props/preview/<id>_mesh.png from the saved .blend
                                      and decode it back (round-trip check); make() also writes it every build
    ... -- --sample                   throwaway end-to-end test prop "zz_sample" (delete its outputs afterwards)
    ... -- --lowpoly well chest | --lowpoly --all
                                      low-poly RE-MATERIAL of exported props, geometry untouched (fyd_props.rematerial:
                                      vertex colours + materials + .blend / FBX / PNG / JSON / previews / manifest)

Every recipe module (fyd_props_recipes*.py) exposes RECIPES = {propId: function() -> fyd_props.Prop}.
Results are written to Previews/Props/_tmp/props_last_run.json (git-ignored) and printed as one PROPS_RESULTS line.
"""
import glob
import importlib
import json
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import fyd_props as P  # noqa: E402

# initial manifest rows (docs/model_upgrade_brief.txt sections 3, 5, 9 and docs/prop_inventory.md)
MANIFEST_INIT = {
    "fountain": ("01_fountain.png", "Blender", "<= 6,000 tris (1024 textures allowed)", "main map 1 (Hub) + test 1"),
    "lamp_post": ("02_lamp_post.png", "Studio", "<= 40 parts", "main map 6 + test 1"),
    "crate": ("03_crate_barrel_mallet.png + 12_crate.png", "Studio", "<= 40 parts",
              "main map 38 + embedded HunterCamp (Lidded) + test"),
    "barrel": ("03_crate_barrel_mallet.png + 10_barrel.png", "Studio", "<= 40 parts",
               "main map 30 + BossArenas 1 + embedded OneBand (HunterCamp, Market_Awning_A) + test"),
    "mallet": ("03_crate_barrel_mallet.png", "-", "-", "-"),
    "egg_nest": ("04_egg_nest.png", "Blender", "<= 1,500 tris", "main map 5 + test 1"),
    "rowboat": ("05_rowboat.png", "Blender", "<= 2,500 tris", "main map 6 + test 1"),
    "minecart": ("06_minecart.png", "Blender", "<= 2,500 tris", "main map 2 + test 1"),
    "skull_bones": ("07_skull_and_bones.png", "Blender", "<= 1,500 tris", "main map 16 + BossArenas 12 + test 1"),
    "scarecrow": ("08_scarecrow.png", "Blender", "<= 3,000 tris", "main map 1 + test 1"),
    "clam_pearl": ("09_clam_pearl.png", "Blender", "<= 800 tris", "main map 29 + test 1"),
    "laundry_rack": ("11_laundry_rack.png", "Studio", "<= 40 parts", "embedded HunterCamp: main map 1 + test 1"),
    "anvil_forge": ("13_anvil_forge.png", "Blender", "<= 4,000 tris", "loose parts of Hub.WeaponShop: main map 1 + test 1"),
    "weapon_stall": ("14_weapon_counter.png + 19_weapon_stall.png", "Studio frame + Blender awning/items",
                     "<= 80 parts frame + Blender pieces (<= 8,000 tris)", "main map 1 (Hub.WeaponShop) + test 1"),
    "lantern": ("15_lantern.png", "Studio", "<= 20 parts", "11 units (6 in lamp posts) + test copies"),
    "well": ("16_well.png", "Blender", "<= 3,500 tris", "main map 1 (Hub.Decor.Village.Well_A) + test 1"),
    "chest": ("17_chest.png", "Blender", "<= 1,500 tris", "main map 5 + test 1"),
    "trophy_stall": ("18_trophy_stall.png", "Studio frame + Blender awning/items",
                     "<= 80 parts frame + Blender pieces (<= 8,000 tris)", "main map 1 (Hub.TrophyMerchant) + test 1"),
    "diamond_shop": ("20_diamond_shop.png", "Studio frame + Blender sign/awning/gems",
                     "<= 80 parts frame + Blender pieces (<= 8,000 tris)", "main map 1 (Hub.DiamondShop) + test 1"),
}


def init_manifest():
    rows = P.read_manifest()
    for pid in P.PROP_ORDER:
        if pid in rows:
            continue
        photo, tool, budget, where = MANIFEST_INIT[pid]
        row = {"propId": pid, "photo": photo, "tool": tool, "triangles/parts": "todo", "budget": budget,
               "status": "todo", "instances updated": f"todo ({where})", "notes": ""}
        if pid == "mallet":
            row.update({"triangles/parts": "-", "status": "dropped", "instances updated": "-",
                        "notes": "no mallet in the game: photo 03 shows the armrest of a hub Bench (benches are out "
                                 "of scope) - docs/prop_inventory.md; 18 models remain"})
        if pid in ("crate", "barrel", "laundry_rack", "lamp_post", "lantern"):
            row["notes"] = "Agent B (Studio-built); switch to Blender if it needs more parts than allowed"
        rows[pid] = row
    P.write_manifest(rows)
    return P.MANIFEST


def sample():
    """Throwaway end-to-end test: a bevelled plank box with iron straps, a glow gem, water, rope, stone, moss."""
    p = P.Prop("zz_sample", photo="12_crate.png", size=(4, 4, 4), budget=1500, view=(-30, 18))
    planks = p.mesh("Planks", "Wood", "WoodLight")
    for i in range(4):  # 4 planks per side face (front / back), with gaps
        for z in (-1.9, 1.9):
            planks.box((-1.5 + i, 2.0, z), (0.94, 3.4, 0.2), grain="y")
    frame = p.mesh("Frame", "Wood", "WoodMid")
    for x in (-1.85, 1.85):
        for z in (-1.85, 1.85):
            frame.beam((x, 0, z), (x, 4.0, z), 0.4, 0.4)
    frame.box((0, 3.9, 0), (4.0, 0.25, 4.0), grain="x")
    iron = p.mesh("Straps", "Iron", "Iron")
    iron.ring((0, 2, 0), 2.05, 2.15, 0.25, segs=4, faces=("outer", "top", "bottom"))
    iron.tube([(-1, 4.1, -1), (0, 4.6, -1), (1, 4.1, -1)], 0.06, segs=5)
    gem = p.mesh("Gem", "Glow", "Diamond", shadow=False)
    gem.ico((0, 4.4, 0.6), 0.35, sub=1, jit=0.05)
    water = p.mesh("Pool", "Water", "Water")
    water.cyl((2.8, 0.0, 0), (2.8, 0.1, 0), 0.6, segs=10, smooth=False, bevel=0)
    rope = p.mesh("Rope", "Rope", "Rope")
    rope.torus((0, 4.1, 0), 0.8, 0.07, segs=10, rsegs=4)
    stone = p.mesh("Stone", "Stone", "Stone")
    stone.arc_block(2.4, 3.0, 100, 140, 0.0, 0.6, segs=2, jit=0.02)
    moss = p.mesh("Moss", "Moss", "Moss")
    moss.ico((-2.6, 0.1, 0.8), 0.4, scale=(1.2, 0.4, 0.9), sub=1)
    p.collider("Block", center=(0, 2, 0), size=(4, 4, 4))
    p.attach("Top", (0, 4.2, 0))
    return p


def registry():
    recipes = {}
    for path in sorted(glob.glob(os.path.join(HERE, "fyd_props_recipes*.py"))):
        name = os.path.splitext(os.path.basename(path))[0]
        module = importlib.import_module(name)
        recipes.update(getattr(module, "RECIPES", {}))
    return recipes


def run(args):
    results = []
    if args and args[0] in ("--lineup", "--photo-lineup"):
        recipes = registry()
        contexts, photos = {}, []
        for pid in args[2:]:
            if pid in recipes:
                p = recipes[pid]()
                if p.context:
                    contexts[pid] = p.context
                if p.photo and p.photo not in photos:
                    photos.append(p.photo)
        results.append({"lineup": P.lineup(args[1], args[2:], contexts=contexts,
                                           photos=photos if args[0] == "--photo-lineup" else None)})
    elif args == ["--init-manifest"]:
        results.append({"manifest": init_manifest()})
    elif args == ["--luau"]:
        results.append({"luau": P.write_luau()})
    elif args == ["--sample"]:
        results.append(P.make(sample()))
    elif args and args[0] == "--lowpoly":
        recipes = registry()
        ids = args[1:]
        if ids == ["--all"]:
            ids = [pid for pid in recipes if os.path.exists(os.path.join(P.EXPORT_DIR, pid + ".json"))]
        for pid in ids:
            try:
                results.append(P.rematerial(recipes[pid]()))
            except Exception as exc:
                results.append({"id": pid, "error": f"{exc}", "trace": traceback.format_exc()[-1500:]})
    elif args and args[0] == "--preview-png":
        for pid in args[1:]:
            try:
                results.append(P.preview_png(pid))
            except Exception as exc:
                results.append({"id": pid, "error": f"{exc}", "trace": traceback.format_exc()[-1500:]})
    else:
        recipes = registry()
        if args == ["--all"]:
            args = list(recipes.keys())
        for pid in args:
            try:
                results.append(P.make(recipes[pid]()))
            except Exception as exc:  # one failure must not stop the batch (brief: log, skip, continue)
                results.append({"id": pid, "error": f"{exc}", "trace": traceback.format_exc()[-1500:]})
    log_dir = os.path.join(P.PREVIEW_DIR, "_tmp")  # git-ignored (Previews/**/_tmp/)
    os.makedirs(log_dir, exist_ok=True)
    with open(os.path.join(log_dir, "props_last_run.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(results, f, indent=1)
    print("PROPS_RESULTS " + json.dumps(results))
    return results


if __name__ == "__main__":
    run(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
