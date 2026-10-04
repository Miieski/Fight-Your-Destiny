"""Tundra_1_FrozenTree - lone huge dead tree on a snow mound, bare twisted branches with snow caps and icicles."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

TRUNK, DARK = "Tundra_Trunk", "Tundra_RockDark"
SNOW, SHADE, ICE, ICE_D = "Tundra_Snow", "Tundra_SnowShade", "Tundra_Ice", "Tundra_IceDeep"


def build():
    M = Model("Tundra_1_FrozenTree", target=(60, 60, 75), seed=201)
    M.clip_z = 0.0
    M.stack[0] = TRS(scale=(0.81, 0.79, 0.95))      # fit the spread crown into about 60 x 60 x 75
    # --- snow mound + drifts -------------------------------------------------------------------------
    M.blob(SNOW, (27, 25, 6.5), sub=2, jit=0.06, flat=0.12, loc=(0, 0, 0.6), seed=1)
    for i, (a, r) in enumerate(((20, 22), (130, 21), (250, 23))):
        M.blob(SHADE, (8.5, 6.0, 2.6), sub=1, jit=0.1, flat=0.15, loc=tuple(polar(r, a, 0.5)), rot=(0, 0, a + 90), seed=10 + i)
    # --- trunk (twisted) + roots ------------------------------------------------------------------------
    M.rings(TRUNK, [(2, 9.0), (7, 7.2, 7.2, 0, 0, 8), (17, 6.0, 6.0, 0.6, 0, 22), (28, 5.4, 5.4, 1.6, 0.5, 38),
                    (38, 4.8, 4.8, 1.0, 1.6, 54), (47, 3.6, 3.6, 0, 2.0, 66)], n=8, jit=0.1, seed=2)
    for i, a in enumerate((-70, 0, 75, 150, 215)):
        M.tube(TRUNK, [polar(5.5, a, 9.0), polar(10.5, a + 8, 6.4), polar(16.0, a + 14, 4.4)], [3.0, 2.2, 0.9], n=5)
    M.rings(DARK, [(0, 2.4, 0.8), (6.5, 2.0, 0.8), (9.5, 0, 0)], n=6, loc=(0.8, -6.4, 10.5), rot=(-6, 0, 0))   # hollow
    # ice sheath round the foot of the trunk
    for i, a in enumerate((-110, -35, 40, 120, 185)):
        M.spike(ICE_D if i % 2 else ICE, tuple(polar(8.6 + (i % 2), a, 4.6)), 2.0, 7.5 + 2 * (i % 3), n=5, rot=(0, 0, a))
    # --- branches -----------------------------------------------------------------------------------------
    rng = random.Random(7)
    out = []
    starts = [(-25, 29, 25, 3.3, 0.22), (55, 33, 23, 3.0, 0.3), (135, 30, 25, 3.2, 0.2), (210, 36, 23, 2.9, 0.3),
              (285, 40, 22, 2.8, 0.38)]
    for a, z, L, r, up in starts:
        M.branch(TRUNK, (1.0, 1.0, z), polar(1.0, a, up), L, r, 2, rng, out, bend=0.3, lift=(-0.05, 0.4))
    M.branch(TRUNK, (0, 2.0, 46), (0.1, 0.0, 1.0), 15, 3.2, 2, rng, out, bend=0.25, lift=(0.2, 0.6))
    # --- snow caps and icicles -------------------------------------------------------------------------------
    for pts, rad, depth in out:
        for i in range(1, len(pts)):
            p = pts[i]
            rr = max(rad[i], 0.7)
            if depth >= 1:
                M.blob(SNOW, (rr * 2.3, rr * 2.0, rr * 1.0), sub=1, jit=0.1, flat=0.35, loc=(p.x, p.y, p.z + rr * 0.9))
            for q in (p, pts[i - 1].lerp(p, 0.5)):
                if rng.random() < (0.85 if depth >= 1 else 0.6):
                    h = rng.uniform(4.0, 9.5) if depth >= 1 else rng.uniform(2.0, 5.0)
                    col = ICE if rng.random() < 0.7 else ICE_D
                    M.icicle(col, (q.x, q.y, q.z - rr * 0.5), rng.uniform(0.6, 1.0), h, n=4)
    M.ref_pos = (14.0, -24.0)
    return M


if __name__ == "__main__":
    run(build)
