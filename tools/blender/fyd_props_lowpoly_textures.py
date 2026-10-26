r"""Fight Your Destiny - the LOW-POLY stylized overlay textures of the props (docs/prop_texture_guide.md section 5).

Python + numpy (Blender's bundled Python has numpy; no Blender scene needed):
    "C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe" tools/blender/fyd_props_lowpoly_textures.py

Writes Blender/Props/textures_lowpoly/<name>.png: 256 x 256 RGBA, tileable, 4 studs per tile (the prop UVs are
world-scale: 1 UV unit = 4 studs), a TRANSPARENT background with flat lines (no noise, no grain), so the part's
Color shows through and only the lines darken (or lighten) it. Keeps the uploaded asset ids of
lowpoly_textures.json (filled by: <same python> tools/blender/fyd_props_lowpoly_textures.py --ids name=id ...).
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import fyd_props_textures as T  # noqa: E402  (write_png, ROOT)

OUT_DIR = os.path.join(T.ROOT, "Blender", "Props", "textures_lowpoly")
INFO = os.path.join(OUT_DIR, "lowpoly_textures.json")
LUAU = os.path.join(T.ROOT, "src", "ReplicatedStorage", "GameSystem", "Config", "PropTextures.luau")
N = 256                       # pixels per tile
STUDS = 4.0                   # studs per tile
PX = N / STUDS                # pixels per stud


def _line_alpha(dist, half):
    """Anti-aliased line coverage from the distance to its centre (pixels)."""
    return np.clip(half + 0.5 - dist, 0.0, 1.0)


def _wrap_dist(a, b, period=N):
    d = np.abs(a - b) % period
    return np.minimum(d, period - d)


def stone_block_lines():
    """Running-bond block joints: courses 1 stud high, blocks 2 studs long, every other course offset 1 stud."""
    y, x = np.mgrid[0:N, 0:N].astype(float) + 0.5
    half = 2.0                                       # 4 px joints (0.06 stud)
    row_h, blk = PX * 1.0, PX * 2.0
    cov = _line_alpha(_wrap_dist(y % row_h, 0.0, row_h), half)
    course = np.floor(y / row_h).astype(int)
    off = np.where(course % 2 == 0, 0.0, blk / 2)
    cov = np.maximum(cov, _line_alpha(_wrap_dist((x + off) % blk, 0.0, blk), half))
    rgba = np.zeros((N, N, 4))
    rgba[..., 3] = cov * 0.30
    return rgba


def plank_lines():
    """Plank seams every stud along the grain (u = x), one butt joint per plank with two nail dots beside it."""
    y, x = np.mgrid[0:N, 0:N].astype(float) + 0.5
    half = 1.5                                       # 3 px seams
    row_h = PX * 1.0
    cov = _line_alpha(_wrap_dist(y % row_h, 0.0, row_h), half)
    plank = np.floor(y / row_h).astype(int)
    joints = np.array([0.16, 0.66, 0.41, 0.91]) * N  # a different joint position on each of the 4 planks
    jx = joints[plank % 4]
    cov = np.maximum(cov, _line_alpha(_wrap_dist(x, jx), half))
    for k in range(4):                               # nail dots: 2 per side of each joint
        for side in (-1, 1):
            for frac in (0.3, 0.7):
                cx, cy = (joints[k] + side * 7.0) % N, (k + frac) * row_h
                d = np.sqrt(_wrap_dist(x, cx) ** 2 + _wrap_dist(y, cy) ** 2)
                cov = np.maximum(cov, _line_alpha(d, 2.2))
    rgba = np.zeros((N, N, 4))
    rgba[..., 3] = cov * 0.35
    return rgba


def water_lines():
    """5 wavy dashed ripple lines, white: integer wave / dash counts per tile, so the tile repeats seamlessly."""
    y, x = np.mgrid[0:N, 0:N].astype(float) + 0.5
    cov = np.zeros((N, N))
    lines = [(0.1, 2, 0.0, 3, 0.4), (0.3, 3, 1.3, 4, 2.1), (0.5, 2, 2.6, 3, 4.0), (0.7, 3, 0.7, 5, 1.0),
             (0.9, 2, 4.1, 4, 3.0)]
    for v, waves, phase, dashes, dphase in lines:
        yc = v * N + 5.0 * np.sin(2 * math.pi * waves * x / N + phase)
        on = np.sin(2 * math.pi * dashes * x / N + dphase) > -0.25
        cov = np.maximum(cov, _line_alpha(_wrap_dist(y, yc), 1.5) * on)
    rgba = np.ones((N, N, 4))
    rgba[..., 3] = cov * 0.5
    return rgba


TEXTURES = {"stone_block_lines": stone_block_lines, "plank_lines": plank_lines, "water_lines": water_lines}


def load_info():
    if os.path.exists(INFO):
        with open(INFO, encoding="utf-8") as f:
            return json.load(f)
    return {"studsPerTile": STUDS, "size": N, "assetIds": {}}


def save_info(info):
    with open(INFO, "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1)


# Boss-room bricks (round 6): drawn by tools/textures/make_brick_textures.py, uploaded once; kept verbatim here so a
# re-run of this generator does not drop them.
BOSS_ROOM_BRICK = [
    "\t-- boss-room bricks (tools/textures/make_brick_textures.py, docs/prop_texture_guide.md \"Boss room brick\"):",
    "\t-- full-colour tiles 8 x 8 studs; the strips are 8 x 32 studs with one painted row (second Texture on the face)",
    "\tBossRoomBrick = {",
    "\t\tStudsPerTile = 8,",
    "\t\tStripStudsV = 32,",
    "\t\tdesert_brick = \"rbxassetid://103191534263698\",",
    "\t\tdesert_frieze_strip = \"rbxassetid://97451078325225\",",
    "\t\tjungle_brick = \"rbxassetid://96625564941177\",",
    "\t\tjungle_moss_strip = \"rbxassetid://81114154147595\",",
    "\t\tdesert_brick_light = \"rbxassetid://95750964449871\", -- owner fix: lighter walls (replaces desert_brick in the rooms)",
    "\t\tdesert_frieze_strip_light = \"rbxassetid://136050815206922\",",
    "\t\tdesert_marble_floor = \"rbxassetid://79394360532493\", -- 512 px = 28 x 28 studs (4 x 4 slabs of 7 studs)",
    "\t\tjungle_flagstone_floor = \"rbxassetid://75902858063767\", -- 512 px = 24 x 24 studs (rows of 6 studs)",
    "\t\ttundra_ice_brick = \"rbxassetid://81297179264826\", -- round 7: ice castle walls, 8 x 8 studs (blocks 4 x 2)",
    "\t\tswamp_wall_stone = \"rbxassetid://134953143438411\", -- round 7: swamp sub-zone 4 / boss room walls, 8 x 8 studs",
    "\t\tswamp_floor_mud_stone = \"rbxassetid://91459519881550\", -- round 7: swamp floors, 512 px = 24 x 24 studs",
    "\t},",
]


def write_luau(info):
    """src/ReplicatedStorage/GameSystem/Config/PropTextures.luau: the overlay ids by name."""
    ids = info.get("assetIds", {})
    lines = ["--!strict",
             "-- GENERATED by tools/blender/fyd_props_lowpoly_textures.py from Blender/Props/textures_lowpoly/",
             "-- lowpoly_textures.json. Do not edit by hand. Low-poly stylized OVERLAYS of the props",
             "-- (docs/prop_texture_guide.md section 5): 256 x 256 RGBA, tileable, StudsPerTile 4, transparent background with",
             "-- flat lines, so the part's Color shows through. MeshPart: TextureID = the id (or a SurfaceAppearance with this",
             "-- ColorMap only, AlphaMode Overlay); Part: a Texture per face, StudsPerTileU / V = 4; water: \"Ripples\"",
             "-- Textures (PropFX scrolls them).",
             "",
             "local PropTextures = {",
             "\tStudsPerTile = %d," % int(STUDS),
             "\tIds = {"]
    for name in TEXTURES:
        v = ids.get(name)
        lines.append("\t\t%s = %s," % (name, json.dumps("rbxassetid://%s" % v) if v else "nil"))
    lines += ["\t},"] + BOSS_ROOM_BRICK + ["}", "", "return PropTextures", ""]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main(argv):
    info = load_info()
    if "--ids" in argv:
        for pair in argv[argv.index("--ids") + 1:]:
            name, value = pair.split("=", 1)
            assert name in TEXTURES, name
            info.setdefault("assetIds", {})[name] = value.replace("rbxassetid://", "")
        save_info(info)
        write_luau(info)
        print("ids", info["assetIds"])
        return
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in TEXTURES.items():
        rgba = fn()
        T.write_png(os.path.join(OUT_DIR, name + ".png"), T.to_u8(rgba))
        print("wrote", name, "alpha max %.2f" % rgba[..., 3].max())
    info.update({"studsPerTile": STUDS, "size": N})
    info.setdefault("assetIds", {})
    save_info(info)
    write_luau(info)


if __name__ == "__main__":
    main(sys.argv[1:])
