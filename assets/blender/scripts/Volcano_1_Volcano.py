"""Volcano_1_Volcano - distant backdrop volcano: banded cone, cracked crater rim, two lava streams (big, under 5k tris)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

BASALT, DARK, LIGHT, ASH, ASH_L = "Volcano_Basalt", "Volcano_BasaltDark", "Volcano_BasaltLight", "Volcano_Ash", "Volcano_AshLight"
LAVA, HOT, CRUST = "Neon_Volcano_Lava", "Neon_Volcano_LavaHot", "Volcano_LavaCrust"

PROFILE = [(0, 156), (30, 124), (62, 97), (98, 73), (138, 53), (172, 41), (198, 35), (208, 36)]


def R(z):
    for (z0, r0), (z1, r1) in zip(PROFILE[:-1], PROFILE[1:]):
        if z <= z1:
            return lerp(r0, r1, (z - z0) / (z1 - z0))
    return PROFILE[-1][1]


def build():
    M = Model("Volcano_1_Volcano", target=(320, 320, 220), seed=401)
    M.clip_z = 0.0
    rng = random.Random(2)
    # --- banded cone (same jitter seed on every band so the facets line up) -----------------------------
    bands = [DARK, BASALT, ASH, BASALT, ASH_L, BASALT, DARK]
    for i, col in enumerate(bands):
        (z0, r0), (z1, r1) = PROFILE[i], PROFILE[i + 1]
        g = 1.0 + (0.012 if i % 2 == 0 else -0.004)
        M.rings(col, [(z0, r0 * g), (z1, r1 * g)], n=16, jit=0.04, seed=5)
    # --- cracked crater rim + lava lake ----------------------------------------------------------------------
    hs = [216, 221, 213, 219, 211, 0, 215, 220, 214, 218, 0, 212, 219, 222, 215, 220]
    M.ring_wall(DARK, 23.0, 37.5, 200.0, 214.0, n=16, gap=1.2, skip={5, 10}, heights=hs, phase=-118.0, seed=3)
    M.ring_wall(BASALT, 21.0, 29.0, 200.0, 210.0, n=11, gap=2.0, phase=10.0, jit=2.0, seed=4)
    M.rings(LAVA, [(203.0, 30.0), (207.4, 28.5)], n=16, jit=0.05, seed=6)
    M.rings(HOT, [(207.0, 13.0), (208.4, 11.0)], n=9, jit=0.1, seed=7)
    for k in range(7):                                                   # glowing cracks running down from the rim
        a = -160 + k * 47 + rng.uniform(-8, 8)
        pts = [polar(R(z) * 1.04 + 1.5, a + rng.uniform(-3, 3), z) for z in (206, 196, 184, 170 - rng.uniform(0, 14))]
        M.tube(LAVA, pts, [2.2, 1.8, 1.3, 0.0], n=3)
    # --- two lava streams (flat ribbons on the flank, with a darker crust bed) and their pools ------------------
    for a0, wig, fork in ((-118.0, 1.0, True), (-38.0, -1.0, False)):
        zs = [209, 196, 176, 152, 126, 98, 70, 44, 20, -2]
        ang = [a0 + wig * (9 * math.sin(i * 1.1) + i * 1.6) for i in range(len(zs))]
        def on(z, a, lift=0.0):                       # a point just above the faceted flank
            return polar(R(z) * 1.045 + 2.0 + lift, a, z)
        path = [on(z, ang[i]) for i, z in enumerate(zs)]
        wid = [4.5, 5.0, 5.5, 6.5, 7.5, 8.5, 9.5, 11.0, 13.0, 15.0]
        M.tube(CRUST, [on(z, ang[i], -1.5) for i, z in enumerate(zs)], [w * 1.6 for w in wid], n=6, squash=0.3)
        M.tube(LAVA, path, wid, n=6, squash=0.4)
        M.tube(HOT, [on(z, ang[i], 1.2) for i, z in enumerate(zs[:7])], [w * 0.36 for w in wid[:7]], n=4, squash=0.5)
        end = polar(R(0) - 8, ang[-1], 0)
        M.blob(CRUST, (25, 19, 4.0), sub=2, jit=0.08, flat=0.05, loc=(end.x, end.y, 0.2), rot=(0, 0, ang[-1] + 90))
        M.blob(LAVA, (19, 14, 4.6), sub=2, jit=0.08, flat=0.05, loc=(end.x, end.y, 0.3), rot=(0, 0, ang[-1] + 90))
        if fork:
            fa = [(98, ang[5]), (70, ang[6] + 14), (40, ang[7] + 24), (12, ang[8] + 30), (-2, ang[9] + 33)]
            M.tube(CRUST, [on(z, a, -1.5) for z, a in fa], [9, 10, 11, 13, 15], n=6, squash=0.3)
            M.tube(LAVA, [on(z, a) for z, a in fa], [5, 6, 7, 8.5, 10], n=6, squash=0.4)
    # --- ridges, a parasitic cone and boulders for the silhouette ----------------------------------------------
    for k, a in enumerate((10, 60, 105, 150, 195)):
        zt = 110 + (k % 3) * 20
        pts = [polar(R(zt) - 2, a, zt), polar(R(zt * 0.6) + 1, a + 4, zt * 0.6), polar(R(zt * 0.25) + 2, a + 9, zt * 0.25),
               polar(R(0) - 4, a + 12, -4)]
        M.tube(LIGHT if k % 2 else BASALT, pts, [3, 8, 13, 17], n=5, jit=0.1, seed=20 + k)
    c = polar(118, 64, 0)
    M.rings(BASALT, [(0, 34, 34, c.x, c.y), (26, 15, 15, c.x, c.y), (38, 8.5, 8.5, c.x, c.y)], n=9, jit=0.1, seed=30)
    M.rings(DARK, [(36, 10.5, 10.5, c.x, c.y), (42, 8.0, 8.0, c.x, c.y)], n=9, jit=0.1, seed=30)
    M.rings(LAVA, [(40, 6.5, 6.5, c.x, c.y), (43, 5.5, 5.5, c.x, c.y)], n=7)
    for k in range(9):
        a = k * 40 + rng.uniform(-10, 10)
        s = rng.uniform(16, 28)
        M.rock(DARK if k % 2 else LIGHT, (s, s * 0.9, s * 0.7), loc=tuple(polar(R(0) - 12 + rng.uniform(0, 6), a, 0)), seed=40 + k)
    M.notes = "Backdrop piece, meant to sit far outside the play area. Lava = objects Neon_Volcano_Lava and Neon_Volcano_LavaHot."
    M.ref_pos = (60.0, -175.0)
    M.view_dir = (0.45, -1.5, 0.5)
    return M


if __name__ == "__main__":
    run(build)
