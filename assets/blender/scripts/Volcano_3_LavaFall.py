"""Volcano_3_LavaFall - tall basalt-column cliff with a wide channel, lava sheet (own object) and a pool at the base."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

BASALT, DARK, LIGHT, ASH = "Volcano_Basalt", "Volcano_BasaltDark", "Volcano_BasaltLight", "Volcano_Ash"
LAVA, CRUST, OBS = "Neon_Volcano_Lava", "Volcano_LavaCrust", "Volcano_Obsidian"
BACK = 25.0
CHW = 11.0                 # half width of the channel
Z_TOP, Z_LEDGE = 86.0, 34.0
Y_FALL1, Y_FALL2 = 10.0, -4.0
RC = 5.2                   # column radius (hexagon)


def build():
    M = Model("Volcano_3_LavaFall", target=(120, 50, 100), seed=421)
    rng = random.Random(11)
    SX, SY, SZ = 0.99, 0.9, 0.975                   # fit into 120 x 50 x 100
    M.stack[0] = TRS(scale=(SX, SY, SZ))
    # --- basalt columns on both sides: honeycomb rows, tall at the back, stepping down to the front -----------
    rows = [(20.0, 93.0), (11.0, 68.0), (2.0, 42.0), (-7.0, 22.0), (-16.0, 10.0)]
    for side in (-1, 1):
        for i in range(6):
            x = side * (CHW + RC + 0.3 + 7.8 * i)
            for ri, (y, h0) in enumerate(rows):
                if i == 0 and ri >= 3:
                    continue                                                    # leave room for the lava pool
                yy = y + (4.5 if i % 2 else 0.0)
                edge = 1.0 - 0.05 * i                                            # the cliff drops a little toward the ends
                h = h0 * edge + rng.uniform(-6.0, 6.0) + (7.0 if (i == 0 and ri < 2) else 0.0)
                h = max(4.0, h)
                col = rng.choice((BASALT, BASALT, BASALT, DARK, DARK, LIGHT))
                M.cyl(col, RC, h, n=6, loc=(x, yy, 0), r2=RC * 0.97)
                if rng.random() < 0.4:
                    M.cyl(ASH, RC * 0.9, 0.9, n=6, loc=(x, yy, h - 0.1), r2=RC * 0.7)   # ash settled on the top
                elif rng.random() < 0.3:
                    M.cyl(LIGHT, RC * 0.8, 1.6, n=6, loc=(x, yy, h - 0.1), r2=RC * 0.55)
    # --- channel: back wall and ledge ---------------------------------------------------------------------------
    M.block(DARK, (2 * CHW + 2, BACK - Y_FALL1, Z_TOP), loc=(0, (BACK + Y_FALL1) / 2.0, 0), base=True, chamfer=0.04, jit=0.01, seed=1)
    M.block(DARK, (2 * CHW + 2, Y_FALL1 - Y_FALL2 + 2, Z_LEDGE), loc=(0, (Y_FALL1 + Y_FALL2) / 2.0 + 1, 0), base=True, chamfer=0.05,
            jit=0.01, seed=2)
    for (y, z) in ((Y_FALL1, Z_TOP), (Y_FALL2, Z_LEDGE)):                    # crusted lips where the lava goes over
        for sx in (-1, 1):
            M.block(CRUST, (3.6, 4.6, 3.4), loc=(sx * (CHW - 1.0), y + 1.6, z + 0.8), chamfer=0.25, seed=3)
    # --- the lava: one object (top run, upper fall, ledge run, lower fall, pool) -----------------------------------
    WW = 18.0
    M.box(LAVA, (WW, BACK - Y_FALL1 + 0.9, 0.7), loc=(0, (BACK + Y_FALL1 - 0.9) / 2.0, Z_TOP + 0.1), base=True)
    M.box(LAVA, (WW, 0.9, Z_TOP - Z_LEDGE + 0.3), loc=(0, Y_FALL1 - 0.8, Z_LEDGE + 0.5), base=True)
    M.box(LAVA, (WW, Y_FALL1 - Y_FALL2 + 0.6, 0.7), loc=(0, (Y_FALL1 + Y_FALL2) / 2.0 - 0.6, Z_LEDGE + 0.1), base=True)
    M.box(LAVA, (WW, 0.9, Z_LEDGE + 0.6), loc=(0, Y_FALL2 - 0.8, 0), base=True)
    M.rings(LAVA, [(0, 16.5, 9.6, 0, -14.4), (0.6, 16.0, 9.2, 0, -14.4)], n=12, jit=0.05, seed=4)
    # --- crust rocks and obsidian shards round the pool --------------------------------------------------------------
    for k in range(9):
        a = 180 + 20 * k + rng.uniform(-6, 6)
        p = V(17.0 * math.cos(math.radians(a)), -14.4 + 10.0 * math.sin(math.radians(a)), 0)
        s = rng.uniform(3.5, 6.0)
        M.rock(CRUST if k % 3 else DARK, (s, s * 0.9, s * 0.55), loc=tuple(p), seed=30 + k)
    for (x, y, h, lean) in ((-20.5, -20.5, 9.0, -14), (-23.5, -17.5, 6.0, -24), (20.0, -21.0, 10.0, 12), (23.5, -18.0, 6.5, 22),
                            (-13.5, -1.5, 7.0 + Z_LEDGE * 0, -8), (14.0, -22.5, 5.0, 6)):
        M.spike(OBS, (x, y, 0), 2.0, h, n=5, rot=(0, lean, 0))
    M.rock(DARK, (6, 5, 3.4), loc=(-5.0, 3.0, Z_LEDGE - 0.2), seed=5)
    M.anchors["LavaTop"] = (0, BACK * SY, (Z_TOP + 0.8) * SZ)
    M.notes = ("Lava sheet = object ...__Neon_Volcano_Lava: %.0f wide, channel floor at Z %.0f, ledge at Z %.0f, pool on the ground "
               "in front. Back side is flat-ish." % (WW * SX, Z_TOP * SZ, Z_LEDGE * SZ))
    M.ref_pos = (26.0, -24.0)
    M.view_dir = (0.7, -1.45, 0.6)
    return M


if __name__ == "__main__":
    run(build)
