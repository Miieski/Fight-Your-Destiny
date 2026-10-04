"""Jungle_1_GiantTree - giant jungle tree: buttress roots, hanging vines, broad layered canopy, tribal mask sign."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

TRUNK, TRUNK_D = "Jungle_Trunk", "Jungle_TrunkDark"
LEAF, LEAF_D, LEAF_L, VINE = "Jungle_Leaf", "Jungle_LeafDark", "Jungle_LeafLight", "Jungle_Vine"
RED, TEAL = "Jungle_Totem", "Jungle_TotemAlt"


def trunk_r(z):
    tbl = [(0, 12.0), (6, 10.6), (20, 9.4), (50, 8.6), (78, 8.2), (92, 9.6), (100, 6.0)]
    for (z0, r0), (z1, r1) in zip(tbl[:-1], tbl[1:]):
        if z <= z1:
            return lerp(r0, r1, (z - z0) / (z1 - z0))
    return tbl[-1][1]


def build():
    M = Model("Jungle_1_GiantTree", target=(90, 90, 120), seed=101)
    M.clip_z = 0.0
    # --- trunk -------------------------------------------------------------------------------------
    M.rings(TRUNK, [(-1, 12.4), (6, 10.6), (20, 9.4, 9.4, 0.4, 0), (50, 8.6, 8.6, 1.0, 0.5), (78, 8.2, 8.2, 0.4, 1.0),
                    (92, 9.6, 9.6, 0, 0.4), (102, 5.5)], n=10, jit=0.07, seed=1)
    # --- buttress roots: tall thin fins, 7 around, gaps of ~14 studs at their tips ------------------------
    for i in range(7):
        a = -90 + 25 + i * 360.0 / 7 + (6 if i % 2 else -5)
        L = 25.0 + (i % 3) * 2.5
        H = 27.0 + (i % 2) * 6.0
        with M.xf(rot=(0, 0, a)):
            M.hull(TRUNK, [(7.0, -1.9, -1), (7.0, 1.9, -1), (7.0, -1.3, H), (7.0, 1.3, H), (9.0, 0, H + 1.5),
                           (14.5, -1.3, -1), (14.5, 1.3, -1), (14.5, -0.9, 9.0), (14.5, 0.9, 9.0)])
            M.hull(TRUNK, [(13.5, -1.4, -1), (13.5, 1.4, -1), (13.5, -1.0, 9.6), (13.5, 1.0, 9.6),
                           (L, -0.9, -1), (L, 0.9, -1), (L - 1.0, 0, 2.2), (L * 0.78, -0.8, 4.4), (L * 0.78, 0.8, 4.4)])
            M.hull(TRUNK_D, [(8.4, -1.0, 8), (8.4, 1.0, 8), (9.6, 0, H * 0.82), (11.0, 0, 13), (12.8, -0.6, 3), (12.8, 0.6, 3),
                             (8.4, 0, H * 0.9)], loc=(0.9, 2.1 if i % 2 else -2.1, 0))                # dark inner fold
    # --- limbs ---------------------------------------------------------------------------------------
    limbs = [(-70, 30, 90), (-15, 27, 93), (45, 31, 89), (105, 28, 92), (165, 30, 90), (225, 27, 93)]
    for i, (a, R, zt) in enumerate(limbs):
        M.tube(TRUNK, [polar(5.0, a, 82), polar(R * 0.5, a + 6, 88), polar(R, a + 10, zt)], [4.2, 3.2, 1.8], n=6,
               jit=0.06, seed=10 + i)
    # --- canopy: three broad flat layers --------------------------------------------------------------
    for i, (a, R, zt) in enumerate(limbs):
        p = polar(R - 3.5, a + 10, zt + 3.5)
        M.blob(LEAF, (19.5 + (i % 2) * 1.5, 18.5, 6.5), sub=2, jit=0.1, flat=0.45, loc=tuple(p), rot=(0, 0, a), seed=20 + i)
        q = polar(R - 9, a - 18, zt - 1.5)
        M.blob(LEAF_D, (15, 14, 4.5), sub=2, jit=0.1, flat=0.4, loc=tuple(q), seed=30 + i)
    for i, a in enumerate((20, 110, 200, 290)):
        p = polar(12.5, a, 104.5)
        M.blob(LEAF, (18, 17, 6.5), sub=2, jit=0.1, flat=0.45, loc=tuple(p), rot=(0, 0, a), seed=40 + i)
        t = polar(17, a + 30, 110.0)
        M.blob(LEAF_L, (9.5, 8.5, 3.2), sub=1, jit=0.1, flat=0.3, loc=tuple(t), seed=50 + i)
    M.blob(LEAF, (17, 17, 7.5), sub=2, jit=0.1, flat=0.45, loc=(0, 0, 112.8), seed=60)
    M.blob(LEAF_L, (11, 10.5, 3.6), sub=2, jit=0.1, flat=0.3, loc=(1, -1.5, 117.3), seed=61)
    for i, (a, R, zt) in enumerate(limbs):
        if i % 2 == 0:
            t = polar(R - 1, a + 20, zt + 8.6)
            M.blob(LEAF_L, (10.5, 9.5, 3.0), sub=1, jit=0.1, flat=0.3, loc=tuple(t), seed=70 + i)
    # --- hanging vines (all end well above head height) ----------------------------------------------------
    rng = random.Random(7)
    for i in range(11):
        a = i * 360.0 / 11 + rng.uniform(-8, 8)
        if abs(((a + 90) + 180) % 360 - 180) < 32:       # keep the front of the mask clear
            a += 64
        R = rng.uniform(26, 39)
        top = polar(R, a, 89.5)
        L = rng.uniform(26, 52)
        sway = V(rng.uniform(-2, 2), rng.uniform(-2, 2), 0)
        pts = [top, top + sway * 0.5 - V(0, 0, L * 0.4), top + sway - V(0, 0, L * 0.8), top + sway * 0.7 - V(0, 0, L)]
        M.tube(VINE, pts, [0.6, 0.55, 0.5, 0.35], n=4)
        M.blob(VINE, (1.8, 1.8, 2.4), sub=1, jit=0.1, loc=tuple(pts[-1] - V(0, 0, 1.2)))
        M.blob(VINE, (1.5, 1.5, 1.9), sub=1, jit=0.1, loc=tuple(pts[1] + V(0.6, 0, 0)))
    # vine spiralling up the trunk
    sp = [polar(trunk_r(z) + 0.5, 140 + z * 5.2, z) + V(0.5 * z / 50.0, 0.3 * z / 50.0, 0) for z in range(4, 80, 6)]
    M.tube(VINE, sp, 0.85, n=4)
    for k in (2, 5, 8, 11):
        M.blob(VINE, (2.4, 2.4, 1.6), sub=1, jit=0.1, loc=tuple(sp[k] * 1.06))
    # --- tribal mask sign on the front of the trunk ----------------------------------------------------------
    zc = 15.0
    yb = -(trunk_r(22) + 0.2)
    for z in (zc + 4.5, zc + 22.0):                                                 # rope bands round the trunk
        M.rings(TRUNK_D, [(z, trunk_r(z) + 0.55), (z + 1.3, trunk_r(z + 1.3) + 0.55)], n=10, jit=0.07, seed=1)
    with M.xf(loc=(0.4, yb - 1.6, zc), rot=(-3, 0, 0), scale=1.32):
        shield = [(-6.6, 6.5), (-7.2, 14.5), (-4.6, 20.5), (0, 22.5), (4.6, 20.5), (7.2, 14.5), (6.6, 6.5), (3.2, 0.5),
                  (0, -1.2), (-3.2, 0.5)]
        M.extrude(TEAL, [(x * 1.12, (z - 10.5) * 1.1 + 10.5) for x, z in shield], 1.2, loc=(0, 0.5, 0))    # teal rim
        M.extrude(RED, shield, 1.8)
        # brow, eyes, nose, mouth with teeth
        M.box(TRUNK_D, (11.5, 1.4, 1.5), loc=(0, -1.2, 16.6))
        for sx in (-1, 1):
            M.box(TEAL, (3.8, 1.2, 2.6), loc=(sx * 3.2, -1.1, 13.9), rot=(0, sx * 14, 0))
            M.box(TRUNK_D, (1.3, 1.5, 1.5), loc=(sx * 3.0, -1.2, 13.8))
            M.tube(TRUNK_D, [(sx * 5.4, -0.9, 5.2), (sx * 7.6, -2.2, 3.6), (sx * 8.4, -3.0, 6.4)], [0.9, 0.75, 0.0], n=4)  # tusks
            M.box(TEAL, (1.3, 1.1, 4.4), loc=(sx * 5.3, -1.0, 9.6), rot=(0, sx * -12, 0))                  # cheek marks
        M.extrude(RED, [(-1.5, 6.8), (1.5, 6.8), (0.9, 13.4), (-0.9, 13.4)], 2.8, loc=(0, -1.3, 0))        # nose
        M.box(TRUNK_D, (7.4, 1.3, 3.2), loc=(0, -1.0, 3.6))                                                # mouth
        for k in range(4):
            M.box(TEAL, (1.1, 1.5, 1.3), loc=(-2.4 + k * 1.6, -1.1, 4.5 if k % 2 == 0 else 2.7))           # teeth
        # feather crest
        for k, (ang, col, L) in enumerate(((-34, TEAL, 8.5), (-17, LEAF_L, 10.0), (0, RED, 11.5), (17, LEAF_L, 10.0), (34, TEAL, 8.5))):
            with M.xf(loc=(0, 0.2, 19.0), rot=(0, ang, 0)):
                M.extrude(col, [(-1.4, 2.5), (0, 0.5), (1.4, 2.5), (1.6, L - 2.5), (0, L), (-1.6, L - 2.5)], 0.8)
    M.ref_pos = (10.0, -27.0)
    return M


if __name__ == "__main__":
    run(build)
