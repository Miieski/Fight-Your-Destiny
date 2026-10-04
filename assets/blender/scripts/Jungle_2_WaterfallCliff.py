"""Jungle_2_WaterfallCliff - tall stepped rock cliff with a carved channel and a flat water sheet following it."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

STONE, STONE_D, MOSS = "Jungle_Stone", "Jungle_StoneDark", "Jungle_Moss"
WATER, LEAF, VINE = "Jungle_Water", "Jungle_Leaf", "Jungle_Vine"
BACK = 25.0
CH = 8.0                      # half width of the channel
# columns: x0, x1, then (front y, top z) for the three tiers
COLS = [(-60, -45, (-16, 26), (-2, 56), (12, 82)),
        (-45, -27, (-22, 31), (-7, 62), (8, 90)),
        (-27, -CH, (-24, 29), (-5, 59), (6, 86)),
        (CH, 25, (-23, 32), (-6, 61), (7, 88)),
        (25, 43, (-19, 27), (-8, 57), (10, 84)),
        (43, 60, (-14, 30), (-1, 60), (14, 79))]
Z_TOP, Z_POOL = 80.0, 52.0    # channel floor heights
Y_FALL1, Y_FALL2 = 9.0, -4.0  # where the water drops


def build():
    M = Model("Jungle_2_WaterfallCliff", target=(120, 50, 90), seed=111)
    rng = random.Random(5)
    SX, SY, SZ = 0.975, 0.96, 0.945                # squeeze the build into 120 x 50 x 90
    M.stack[0] = TRS(scale=(SX, SY, SZ))
    # --- rock columns, three steps -------------------------------------------------------------------
    for ci, (x0, x1, a, b, c) in enumerate(COLS):
        w = x1 - x0 + 1.6
        cx = (x0 + x1) / 2.0
        tiers = (a, b, c)
        for ti, (yf, top) in enumerate(tiers):
            z0 = 0.0 if ti == 0 else tiers[ti - 1][1] - 9.0
            col = STONE if (ci + ti) % 2 == 0 else STONE_D
            yaw = rng.uniform(-4.0, 4.0)
            M.block(col, (w, BACK - yf, top - z0), loc=(cx, (BACK + yf) / 2.0, z0), rot=(0, 0, yaw), base=True,
                    chamfer=0.14, jit=0.05, seed=10 + ci * 3 + ti)
            # moss cap on the exposed part of the top
            y_next = tiers[ti + 1][0] if ti < 2 else BACK
            d = (y_next - yf) + 2.5
            M.block(MOSS, (w + 0.8, d, 2.0), loc=(cx, yf + d / 2.0 - 0.9, top - 0.9), rot=(0, 0, yaw), chamfer=0.2, jit=0.03,
                    seed=40 + ci * 3 + ti)
            # moss drips over the front edge
            for k in range(2):
                dx = rng.uniform(-w * 0.36, w * 0.36)
                h = rng.uniform(2.5, 6.0)
                M.box(MOSS, (rng.uniform(2.0, 3.6), 1.0, h), loc=(cx + dx, yf - 0.9, top - h * 0.5 - 0.4), taper=(0.6, 1.0))
            # a darker strata band across the face of the lighter blocks
            if col == STONE:
                zb = z0 + (top - z0) * rng.uniform(0.35, 0.6) + (9 if ti else 0) * 0.5
                M.box(STONE_D, (w - 1.5, 1.2, 2.4), loc=(cx, yf + 0.3, zb))
    # --- channel: back walls + floors ---------------------------------------------------------------------
    M.block(STONE_D, (2 * CH + 2, BACK - Y_FALL1, Z_TOP - 40), loc=(0, (BACK + Y_FALL1) / 2.0, 40), base=True, chamfer=0.06, jit=0.01, seed=1)
    M.block(STONE_D, (2 * CH + 2, BACK - Y_FALL2, Z_POOL), loc=(0, (BACK + Y_FALL2) / 2.0, 0), base=True, chamfer=0.04, jit=0.01, seed=2)
    # lips where the water goes over the edge + stones in the channel
    for (y, z) in ((Y_FALL1, Z_TOP), (Y_FALL2, Z_POOL)):
        for sx in (-1, 1):
            M.block(STONE, (3.4, 4.0, 3.6), loc=(sx * (CH - 1.2), y + 1.6, z + 1.0), chamfer=0.22, seed=3)
    M.rock(STONE, (4.5, 4.0, 3.0), loc=(-4.6, 2.5, Z_POOL - 0.3), seed=4)
    M.rock(STONE, (5.5, 5.0, 3.6), loc=(6.4, -9.5, 0), seed=5)
    M.rock(STONE_D, (4.0, 3.6, 2.6), loc=(-6.8, -13.0, 0), seed=6)
    # --- water sheet: one object following the channel (replace / animate it in Studio) ----------------------
    WW = 12.6
    M.box(WATER, (WW, BACK - Y_FALL1 + 0.9, 0.6), loc=(0, (BACK + Y_FALL1 - 0.9) / 2.0, Z_TOP + 0.1), base=True)
    M.box(WATER, (WW, 0.7, Z_TOP - Z_POOL + 0.2), loc=(0, Y_FALL1 - 0.65, Z_POOL + 0.5), base=True)
    M.box(WATER, (WW, Y_FALL1 - Y_FALL2 + 0.6, 0.6), loc=(0, (Y_FALL1 + Y_FALL2) / 2.0 - 0.6, Z_POOL + 0.1), base=True)
    M.box(WATER, (WW, 0.7, Z_POOL + 0.5), loc=(0, Y_FALL2 - 0.65, 0), base=True)
    M.rings(WATER, [(0, 7.6, 9.0, 0, -13.0), (0.45, 7.3, 8.7, 0, -13.0)], n=10)                 # plunge pool
    # --- bushes, ferns and hanging vines --------------------------------------------------------------------
    spots = [(-52, -9, 26), (-36, -14, 31), (-18, -14, 29), (17, -15, 32), (35, -13, 27), (52, -7, 30),
             (-38, 1, 62), (-15, 0, 59), (16, 1, 61), (50, 6, 60), (-34, 15, 90), (34, 17, 84)]
    for i, (x, y, z) in enumerate(spots):
        r = 3.2 + (i % 3) * 0.9
        M.blob(LEAF, (r * 1.25, r, r * 0.8), sub=1, jit=0.14, flat=0.3, loc=(x, y, z + r * 0.45), seed=60 + i)
    vines = [(-50, -2, 56, 16), (-33, -7, 62, 22), (-12, -5, 59, 14), (20, -6, 61, 20), (38, -8, 57, 13), (55, -1, 60, 18),
             (-40, 8, 90, 20), (-20, 6, 86, 15), (14, 7, 88, 18), (48, 14, 79, 12), (-56, -16, 26, 11), (30, -19, 27, 12)]
    for i, (x, yf, top, L) in enumerate(vines):
        M.tube(VINE, [(x, yf - 0.7, top - 0.5), (x + 0.6, yf - 0.9, top - L * 0.5), (x - 0.3, yf - 0.8, top - L)],
               [0.75, 0.65, 0.4], n=4)
        M.blob(VINE, (1.5, 1.0, 1.5), sub=1, jit=0.1, loc=(x - 0.3, yf - 0.9, top - L))
    M.anchors["WaterTop"] = (0, BACK * SY, (Z_TOP + 0.7) * SZ)
    M.notes = ("Water sheet = object ...__Jungle_Water: runs along the top channel (Z %.1f), drops to a ledge pool (Z %.1f), "
               "then drops to the ground; %.1f wide. Back face is flat (put it against the map edge)."
               % (Z_TOP * SZ, Z_POOL * SZ, 12.6 * SX))
    M.ref_pos = (14.0, -27.0)
    M.view_dir = (0.7, -1.45, 0.6)
    return M


if __name__ == "__main__":
    run(build)
