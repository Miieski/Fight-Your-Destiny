"""Hell_2_BurningTower - tall ruined gothic tower: spiked buttresses, glowing arched windows, broken crown, fire bowl."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

TILE, DARK, BORDER, BLACK, IRON = "Hell_Tile", "Hell_GroundDark", "Hell_TileBorder", "Hell_Black", "Hell_Iron"
WIN, FLAME, FLAME2 = "Neon_Hell_Orange", "Neon_Hell_LavaHot", "Neon_Hell_Lava"
C4 = math.cos(math.radians(45.0))
ARCH = [(-3.2, 0.0), (3.2, 0.0), (3.2, 7.0), (0.0, 11.5), (-3.2, 7.0)]


def hw(z):
    return lerp(11.5, 9.0, max(0.0, min(1.0, (z - 10.0) / 72.0)))


def build():
    M = Model("Hell_2_BurningTower", target=(44, 44, 110), seed=511)
    rng = random.Random(5)
    # --- plinth and shaft ------------------------------------------------------------------------------
    M.box(DARK, (31, 31, 5), base=True, taper=0.97)
    M.box(TILE, (26.5, 26.5, 5), loc=(0, 0, 5), base=True, taper=0.93)
    M.rings(TILE, [(10, hw(10) / C4), (82, hw(82) / C4)], n=4)
    for z in (33.0, 57.0):
        M.rings(BORDER, [(z, (hw(z) + 0.9) / C4), (z + 2.2, (hw(z + 2.2) + 0.9) / C4)], n=4)
    # --- windows on the four faces --------------------------------------------------------------------------
    for rz in (0, 90, 180, 270):
        with M.xf(rot=(0, 0, rz)):
            for k, z in enumerate((17.0, 41.0, 64.0)):
                y = -hw(z + 6.0) - 0.25
                s = 1.0 - 0.1 * k
                M.extrude(BLACK, [(x * 1.4 * s, (zz - 5.0) * 1.3 * s + 5.0) for x, zz in ARCH], 1.4, loc=(0, y, z))
                M.extrude(WIN, [(x * s, zz * s) for x, zz in ARCH], 2.2, loc=(0, y - 0.1, z + 0.6))
                M.box(BLACK, (0.6, 2.6, 10.0 * s), loc=(0, y - 0.2, z + 0.6), base=True)                  # mullion
    # --- crown: corbel, broken battlements, corner pinnacles ------------------------------------------------------
    M.rings(DARK, [(82, hw(82) / C4), (86, 13.5 / C4), (90, 13.5 / C4)], n=4)
    M.rings(BORDER, [(89.2, 14.2 / C4), (90.6, 14.2 / C4)], n=4)
    for rz in (0, 90, 180, 270):
        with M.xf(rot=(0, 0, rz)):
            for k, x in enumerate((-7.5, -2.5, 2.5, 7.5)):
                if rz == 90 and k >= 2 or rz == 180 and k == 0:
                    continue                                                                             # the broken corner
                h = rng.choice((6.0, 6.0, 4.0, 2.5))
                M.box(TILE, (3.4, 2.6, h), loc=(x, -12.6, 90.4), base=True, taper=(1.0, 1.0))
    for (sx, sy, h) in ((-1, -1, 11.0), (1, -1, 9.0), (-1, 1, 10.0)):
        M.box(DARK, (4.0, 4.0, 4.0), loc=(sx * 12.4, sy * 12.4, 90.4), base=True)
        M.cone(BLACK, 2.6, h, n=4, loc=(sx * 12.4, sy * 12.4, 94.4))
    M.block(DARK, (4.4, 4.0, 3.0), loc=(11.0, 11.5, 91.6), rot=(20, -15, 30), chamfer=0.2, seed=2)        # broken stump
    # --- fire bowl and flames -----------------------------------------------------------------------------------------
    M.rings(IRON, [(90.4, 4.2), (93.4, 3.2), (94.6, 9.6), (98.0, 11.0), (98.0, 9.6), (96.0, 8.2)], n=8)
    M.rings(FLAME2, [(96.5, 8.6), (98.6, 8.0)], n=8)
    M.spike(FLAME, (0, 0, 97.5), 4.6, 12.5, n=5, waist=0.28)
    for k in range(6):
        a = k * 60 + 20
        p = polar(5.0, a, 97.5)
        col = FLAME if k % 2 == 0 else FLAME2
        M.spike(col, tuple(p), 3.0, 7.0 + (k % 3) * 1.6, n=5, rot=(0, 16, a), waist=0.3)
    # --- corner piers with spikes + flying buttresses ---------------------------------------------------------------------
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.box(DARK, (6.0, 6.0, 30.0), loc=(sx * 19.0, sy * 19.0, 0), base=True, taper=0.82)
            M.box(BORDER, (5.6, 5.6, 1.4), loc=(sx * 19.0, sy * 19.0, 29.4), base=True)
            M.cone(BLACK, 3.3, 12.0, n=4, loc=(sx * 19.0, sy * 19.0, 30.8))
            M.tube(TILE, [(sx * 18.0, sy * 18.0, 25.0), (sx * 13.6, sy * 13.6, 44.0), (sx * 9.4, sy * 9.4, 57.0)], 2.1, n=4)
            M.cone(BLACK, 1.8, 6.0, n=4, loc=(sx * 13.6, sy * 13.6, 45.6))
    # --- chains: sagging between the piers, and hanging from the crown with cages ---------------------------------------------
    for rz in (0, 90, 180, 270):
        with M.xf(rot=(0, 0, rz)):
            M.tube(IRON, [(-19.0, -19.0, 28.5), (-9.5, -20.2, 22.5), (0.0, -20.6, 20.5), (9.5, -20.2, 22.5), (19.0, -19.0, 28.5)],
                   0.55, n=4)
    for (rz, x, L) in ((0, 6.5, 22.0), (180, -5.5, 16.0), (270, 4.0, 27.0)):
        with M.xf(rot=(0, 0, rz)):
            M.tube(IRON, [(x, -13.2, 89.0), (x + 0.4, -13.6, 89.0 - L * 0.5), (x, -13.4, 89.0 - L)], 0.45, n=4)
            M.rings(IRON, [(0, 0.6), (0.8, 2.2), (5.0, 2.2), (5.8, 0.6)], n=6, loc=(x, -13.4, 83.2 - L))                 # cage
            M.rings(FLAME2, [(1.6, 1.3), (3.6, 1.3)], n=5, loc=(x, -13.4, 83.2 - L))
    # --- rubble from the broken corner -------------------------------------------------------------------------------------------
    for i, (x, y, s) in enumerate(((16.5, 9.0, 4.0), (12.5, 16.0, 3.2), (8.0, 19.0, 2.4))):
        M.block(TILE, (s * 1.3, s, s * 0.8), loc=(x, y, s * 0.35), rot=(12 * i, 8, 25 * i), chamfer=0.2, seed=10 + i)
    M.ref_pos = (9.0, -24.0)
    M.view_dir = (0.8, -1.35, 0.42)
    return M


if __name__ == "__main__":
    run(build)
