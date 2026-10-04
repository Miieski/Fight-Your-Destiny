"""Hub_RebirthAltar - hub centerpiece: round stepped dais, four pillars, rune altar, floating crystal."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

PLAZA, PLAZA_D = "Hub_Plaza", "Hub_PlazaDark"
STONE, STONE_D, BLUE = "Common_Stone", "Common_StoneDark", "Common_StoneBlue"
GOLD, CRYSTAL, RUNE = "Common_Gold", "Neon_Common_Diamond", "Neon_Hub_Portal"


def crystal(M, key, loc, r, h, n=6, rot=(0, 0, 0), waist=0.42):
    """Pointed bipyramid crystal, loc = bottom tip."""
    M.rings(key, [(0, 0), (h * waist, r), (h * (waist + 0.16), r * 0.92), (h, 0)], n=n, loc=loc, rot=rot,
            phase=0)


def build():
    M = Model("Hub_RebirthAltar", target=(44, 44, 34), seed=11)
    N = 16
    # --- dais: three round steps (1.2 high, 3 deep) ---------------------------------------
    M.rings(PLAZA_D, [(0, 22.0), (1.2, 21.7)], n=N)
    M.rings(PLAZA, [(1.2, 19.0), (2.4, 18.7)], n=N)
    M.rings(PLAZA_D, [(2.4, 16.0), (3.6, 15.7)], n=N)
    M.rings(PLAZA, [(3.6, 14.6), (3.85, 14.4)], n=N)           # top paving
    M.rings(BLUE, [(3.85, 8.2), (4.05, 8.0)], n=N)             # inner blue disc
    # rune ring on the floor (flush glowing tiles)
    M.ring_wall(RUNE, 10.2, 11.4, 3.85, 4.0, n=16, gap=9.0, phase=11.25)
    # cardinal inlay strips running down the steps (carpet-like)
    for a in (0, 90, 180, 270):
        with M.xf(rot=(0, 0, a)):
            M.box(BLUE, (4.0, 3.2, 0.16), loc=(0, -20.2, 1.2), base=True)
            M.box(BLUE, (4.0, 3.0, 0.16), loc=(0, -17.3, 2.4), base=True)
            M.box(BLUE, (4.0, 3.4, 0.16), loc=(0, -14.0, 3.6), base=True)
            M.box(RUNE, (1.2, 1.2, 0.2), loc=(0, -12.9, 3.85), rot=(0, 0, 45), base=True)

    # --- four pillars ---------------------------------------------------------------------
    for a in (45, 135, 225, 315):
        with M.xf(rot=(0, 0, a)):
            with M.xf(loc=(12.6, 0, 3.6)):
                M.block(STONE_D, (4.4, 4.4, 1.6), base=True, chamfer=0.12, jit=0.0)
                M.rings(STONE, [(1.6, 1.7), (2.4, 1.45), (13.6, 1.2), (14.2, 1.6)], n=8)
                M.box(RUNE, (0.5, 0.5, 5.0), loc=(-1.36, 0, 7.5))            # inward-facing rune slit
                M.block(STONE_D, (3.8, 3.8, 1.3), loc=(0, 0, 14.2), base=True, chamfer=0.14, jit=0.0)
                M.rings(GOLD, [(15.5, 1.5), (16.3, 1.9), (16.6, 1.9), (16.6, 1.2), (16.2, 1.0)], n=8)  # brazier bowl
                # gold claw leaning toward the crystal
                M.tube(GOLD, [(-1.2, 0, 15.6), (-3.2, 0, 17.6), (-4.4, 0, 20.4), (-4.6, 0, 22.6)],
                       [0.75, 0.65, 0.45, 0.0], n=4)
                crystal(M, CRYSTAL, (0, 0, 17.4), 0.95, 4.2)

    # --- altar ----------------------------------------------------------------------------
    M.stack.append(M.stack[-1] @ TRS(loc=(0, 0, 3.85 - 3.85 * 1.3), scale=1.3))
    z = 3.85
    M.box(STONE_D, (9.0, 6.6, 0.9), loc=(0, 0, z), base=True, taper=0.94)
    M.box(STONE, (7.0, 4.8, 3.0), loc=(0, 0, z + 0.9), base=True, taper=0.92)
    M.box(STONE_D, (8.6, 6.2, 0.9), loc=(0, 0, z + 3.9), base=True)
    M.box(GOLD, (9.0, 6.6, 0.3), loc=(0, 0, z + 4.2), base=True)                 # gold trim band
    M.box(STONE_D, (8.0, 5.6, 0.5), loc=(0, 0, z + 4.5), base=True, taper=0.9)
    top = z + 5.0
    # carved runes (glowing) on the four faces of the altar body
    for sy in (-1, 1):
        for i, x in enumerate((-2.2, -0.75, 0.75, 2.2)):
            h = (1.7, 1.1, 1.4, 0.9)[i]
            M.box(RUNE, (0.5, 0.3, h), loc=(x, sy * 2.38, z + 1.3 + (0.4 if i % 2 else 0)), base=True)
        M.box(RUNE, (3.4, 0.3, 0.3), loc=(0, sy * 2.42, z + 1.0), base=True)
    for sx in (-1, 1):
        M.box(RUNE, (0.3, 0.5, 1.6), loc=(sx * 3.42, -0.8, z + 1.3), base=True)
        M.box(RUNE, (0.3, 0.5, 1.0), loc=(sx * 3.42, 0.8, z + 1.7), base=True)
    # gold bowl on the altar + glowing core
    M.rings(GOLD, [(top, 1.2), (top + 0.5, 2.3), (top + 0.9, 2.5), (top + 0.9, 1.9), (top + 0.5, 1.6)], n=8)
    M.rings(RUNE, [(top + 0.5, 1.5), (top + 1.0, 1.2)], n=8)
    M.stack.pop()

    # --- big floating crystal + orbiting shards + gold ring --------------------------------
    crystal(M, CRYSTAL, (0, 0, 13.4), 4.6, 20.6, n=6, waist=0.5)
    for i, a in enumerate((20, 110, 200, 290)):
        p = polar(7.4, a, 18.0 + (i % 2) * 5.5)
        crystal(M, CRYSTAL, tuple(p), 0.95, 4.2, n=5, rot=(8 * (-1) ** i, 10, a))
    ring = [polar(6.6, 360.0 * i / 12, 0) for i in range(12)]
    with M.xf(loc=(0, 0, 21.5), rot=(16, 10, 0)):
        M.tube(GOLD, ring, 0.42, n=4, closed=True, up=(0, 0, 1))
    with M.xf(loc=(0, 0, 25.8), rot=(-12, -18, 40)):
        M.tube(GOLD, [p * 0.72 for p in ring], 0.32, n=4, closed=True, up=(0, 0, 1))
    M.ref_pos = (25.5, -6.0)
    M.view_dir = (0.35, -1.5, 0.6)
    return M


if __name__ == "__main__":
    run(build)
