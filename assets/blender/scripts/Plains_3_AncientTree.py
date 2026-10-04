"""Plains_3_AncientTree - huge ancient tree: twisted trunk, spreading roots with walkable gaps, layered canopy."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

TRUNK, BARK_D = "Plains_Trunk", "Plains_MountainDark"
LEAF, LEAF_D, LEAF_L = "Plains_Leaf", "Plains_LeafDark", "Plains_GrassLight"
MOSS, SHROOM = "Plains_Moss", "Plains_Mushroom"


def build():
    M = Model("Plains_3_AncientTree", target=(110, 110, 115), seed=41)
    M.clip_z = 0.0
    # --- trunk (10-sided, jittered, twisting) ------------------------------------------------
    M.rings(TRUNK, [(-1, 17.5, 17.5, 0, 0, 0), (3, 15.6, 15.6, 0, 0, 4), (9, 14.2, 14.0, 0.3, 0, 10),
                    (20, 13.0, 12.6, 1.0, -0.4, 22), (33, 12.2, 12.4, 1.8, 0.6, 36),
                    (45, 12.6, 12.2, 1.0, 1.6, 50), (54, 14.0, 13.6, 0, 0.8, 60), (62, 11.5, 11.5, -0.5, 0, 66),
                    (72, 7.0, 7.0, -1.0, -0.5, 70)], n=10, jit=0.1, seed=3)
    # bark ridges: darker strips spiralling with the trunk
    for a0 in (20, 150, 265):
        pts = []
        for z, r, tw in ((6, 14.9, 8), (18, 13.5, 20), (32, 12.9, 35), (46, 13.0, 51), (56, 14.2, 62)):
            pts.append(polar(r, a0 + tw, z))
        M.tube(BARK_D, pts, [0.9, 1.5, 1.6, 1.3, 0.6], n=4)
    # hollow at the foot of the trunk (front)
    M.rings(BARK_D, [(0, 4.2, 1.2), (9.5, 3.6, 1.2), (14.0, 0, 0)], n=6, loc=(1.5, -14.6, 0), rot=(-7, 0, 0))
    M.tube(TRUNK, [(-3.6, -15.2, 0), (-3.4, -15.0, 9.5), (1.5, -14.2, 15.5), (6.2, -15.0, 9.5), (6.6, -15.2, 0)],
           [1.5, 1.3, 1.2, 1.3, 1.5], n=5)
    # --- roots (gaps of 10+ studs between them) -----------------------------------------------
    roots = [(-78, 44, 12), (-28, 40, -14), (22, 46, 10), (75, 41, -10), (125, 45, 12), (176, 40, -12), (228, 46, 9)]
    for i, (a, L, bend) in enumerate(roots):
        pts = [polar(10.0, a, 9.0), polar(17.0, a + bend * 0.2, 5.2), polar(L * 0.58, a + bend * 0.6, 2.4),
               polar(L * 0.82, a + bend, 0.9), polar(L, a + bend * 1.5, -0.8)]
        M.tube(TRUNK, pts, [5.6, 4.6, 3.3, 2.2, 0.9], n=6, jit=0.1, seed=50 + i)
        if i % 2 == 0:                                            # side rootlet
            p = polar(L * 0.55, a + bend * 0.6, 2.0)
            q = polar(L * 0.86, a - bend * 1.4, -0.6)
            M.tube(TRUNK, [p, p.lerp(q, 0.5) + V(0, 0, 0.4), q], [2.2, 1.6, 0.7], n=5)
        if i in (1, 3, 4, 6):                                     # moss on top of the root
            M.blob(MOSS, (3.6, 2.6, 1.0), sub=1, loc=tuple(polar(L * 0.4, a + bend * 0.4, 4.9)), rot=(0, 0, a))
    # --- main limbs -----------------------------------------------------------------------------
    limbs = [(-60, 39, 77), (5, 36, 82), (70, 40, 76), (135, 37, 81), (200, 40, 75), (268, 34, 84)]
    for i, (a, R, zt) in enumerate(limbs):
        M.tube(TRUNK, [polar(6.0, a, 50), polar(R * 0.42, a + 8, 63), polar(R * 0.78, a + 14, zt - 5),
                       polar(R, a + 16, zt)], [6.4, 5.0, 3.6, 2.2], n=6, jit=0.08, seed=70 + i)
    # --- canopy: dark underside, main masses, light tops -------------------------------------------
    M.blob(LEAF, (36, 36, 21), sub=2, jit=0.13, flat=0.45, loc=(0, 0, 87), seed=1)
    for i, (a, R, zt) in enumerate(limbs):
        p = polar(R + 3, a + 16, zt + 4)
        M.blob(LEAF, (22 + (i % 3) * 2, 21 + (i % 2) * 3, 14), sub=2, jit=0.14, flat=0.5, loc=tuple(p), rot=(0, 0, a), seed=10 + i)
        q = polar(R - 6, a - 12, zt - 4)
        M.blob(LEAF_D, (17, 16, 9.5), sub=2, jit=0.14, flat=0.45, loc=tuple(q), seed=20 + i)
        t = polar(R - 2, a + 22, zt + 13.5)
        M.blob(LEAF_L, (13.5, 12.5, 6.0), sub=1, jit=0.12, flat=0.3, loc=tuple(t), rot=(0, 0, a), seed=30 + i)
    M.blob(LEAF, (25, 25, 15), sub=2, jit=0.13, flat=0.5, loc=(-4, 3, 102), seed=2)
    M.blob(LEAF_L, (17, 16, 7.5), sub=2, jit=0.12, flat=0.3, loc=(-1, -2, 110.5), seed=4)
    M.blob(LEAF_L, (12, 13, 6.5), sub=1, jit=0.12, flat=0.3, loc=(13, -17, 101), seed=5)
    M.blob(LEAF_D, (20, 20, 9), sub=2, jit=0.13, flat=0.4, loc=(0, 0, 72), seed=6)
    # --- moss + shelf mushrooms on the trunk ---------------------------------------------------------
    for (a, z, s) in ((-120, 14, 1.0), (60, 26, 1.2), (-40, 38, 0.9), (170, 20, 1.1)):
        M.blob(MOSS, (5.0 * s, 1.6, 4.0 * s), sub=1, jit=0.15, loc=tuple(polar(13.6, a, z)), rot=(0, 0, a + 90))
    for (a, z, s) in ((-100, 9.0, 1.0), (-106, 12.6, 0.75), (-93, 15.5, 0.6), (-45, 19, 0.9), (-52, 23, 0.65),
                      (40, 11, 1.0), (33, 14.5, 0.7)):
        M.blob(SHROOM, (3.4 * s, 3.4 * s, 0.9 * s), sub=1, jit=0.08, flat=0.3, loc=tuple(polar(15.0 - z * 0.08, a, z)))
    M.ref_pos = (24.0, -40.0)
    return M


if __name__ == "__main__":
    run(build)
