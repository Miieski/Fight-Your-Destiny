"""Desert_1_RockArch - tall wind-carved sandstone arch built from stacked strata (red / light / dark)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

RED, LIGHT, DARK, SAND = "Desert_CanyonRed", "Desert_CanyonLight", "Desert_CanyonDark", "Desert_Sand"
C8 = math.cos(math.radians(22.5))
CX, W_IN, H_IN = 1.5, 20.5, 43.0          # opening: 41 wide at the ground, 43 high, 32 wide at z = 30


def interp(z, tbl):
    if z <= tbl[0][0]:
        return tbl[0][1]
    for (z0, v0), (z1, v1) in zip(tbl[:-1], tbl[1:]):
        if z <= z1:
            return lerp(v0, v1, (z - z0) / (z1 - z0))
    return tbl[-1][1]


XL = [(0, -43), (10, -40), (24, -38.5), (36, -39.5), (48, -40), (56, -36), (62, -29), (67, -21)]
XR = [(0, 43), (12, 40), (26, 38), (40, 39), (50, 40), (57, 35), (62, 27), (67, 18)]
DY = [(0, 13.0), (14, 11.5), (30, 10.5), (46, 11.5), (58, 10.0), (67, 7.5)]


def w_in(z):
    if z >= H_IN:
        return 0.0
    return W_IN * math.sqrt(max(0.0, 1.0 - (z / H_IN) ** 3))


def build():
    M = Model("Desert_1_RockArch", target=(90, 30, 70), seed=61)
    zs = [0, 4, 9, 13, 19, 24, 30, 35, 39, 43, 47.5, 52, 56.5, 61, 64.5, 67]
    cols = [DARK, RED, LIGHT, RED, DARK, RED, LIGHT, RED, DARK, LIGHT, RED, DARK, RED, LIGHT, RED]
    grow = [1.05, 0.97, 1.03, 0.96, 1.04, 0.97, 1.03, 0.98, 1.03, 1.04, 0.97, 1.03, 0.96, 1.03, 0.95]
    for i, (z0, z1) in enumerate(zip(zs[:-1], zs[1:])):
        col, g = cols[i], grow[i]
        if z0 < H_IN:
            for side in (-1, 1):
                secs = []
                for z in (z0, z1):
                    inner = CX + side * w_in(z)
                    outer = interp(z, XL) if side < 0 else interp(z, XR)
                    half = abs(outer - inner) / 2.0
                    cx = (outer + inner) / 2.0 + side * half * (g - 1.0)       # grow outward only
                    secs.append((z, half * g / C8, interp(z, DY) * g / C8, cx, side * 0.6))
                M.rings(col, secs, n=8, jit=0.07, seed=100 + i * 2 + side)
        else:
            secs = []
            for z in (z0, z1):
                l, r = interp(z, XL), interp(z, XR)
                secs.append((z, (r - l) / 2.0 * g * 0.98, interp(z, DY) * g, (l + r) / 2.0, 0.0))
            M.rings(col, secs, n=10, jit=0.06, seed=200 + i, phase=18)
    # --- crown: balancing boulders and a broken fin -------------------------------------------------
    M.rock(LIGHT, (16, 11, 8.5), loc=(-11, 0.5, 62.5), npts=16, flat=0.9, seed=3)
    M.rock(RED, (10, 8, 6.5), loc=(7, -1, 63.0), npts=14, flat=0.9, seed=4)
    M.rock(DARK, (8, 7, 6), loc=(-26, 1, 57.5), npts=12, flat=0.9, seed=5)
    # --- hoodoo spire leaning on the right leg, rubble at the feet (outside the passage) --------------
    for k, (z0, z1, r0, r1, col) in enumerate(((0, 9, 7.5, 6.6, DARK), (9, 17, 6.9, 5.6, RED), (17, 22, 6.2, 5.6, LIGHT),
                                               (22, 29, 5.0, 3.4, RED), (29, 32, 4.6, 4.2, DARK))):
        M.rings(col, [(z0, r0, r0 * 0.9, 38.0, -7.5), (z1, r1, r1 * 0.9, 37.6, -7.0)], n=7, jit=0.08, seed=300 + k)
    M.rock(RED, (11, 9, 7), loc=(-38, -9.5, 0), seed=6)
    M.rock(DARK, (7, 6, 4.5), loc=(-29, -11.5, 0), seed=7)
    M.rock(LIGHT, (8, 7, 5), loc=(-38, 9.5, 0), seed=8)
    M.rock(RED, (9, 8, 6), loc=(34, 10, 0), seed=9)
    M.rock(DARK, (5, 5, 3.5), loc=(29.5, -11.5, 0), seed=10)
    # sand drifts against the legs
    for (x, y, rx, ry, s) in ((-31, -10.5, 8, 4.0, 11), (35, 9.5, 9, 4.5, 12), (-42, 2, 3.5, 8, 13), (42.5, 3, 3.5, 7, 14)):
        M.blob(SAND, (rx, ry, 2.2), sub=1, jit=0.1, flat=0.05, loc=(x, y, 0.1), seed=s)
    M.ref_pos = (10.0, -17.0)
    M.view_dir = (0.5, -1.5, 0.42)
    return M


if __name__ == "__main__":
    run(build)
