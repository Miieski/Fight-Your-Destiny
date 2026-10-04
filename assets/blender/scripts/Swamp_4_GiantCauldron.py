"""Swamp_4_GiantCauldron - gigantic iron cauldron on stone supports over logs, bubbling toxic surface, rune band, ladle."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

IRON, BAND, STONE, WOOD, CHAR = "Common_Iron", "Common_StoneDark", "Common_Stone", "Swamp_Wood", "Swamp_BarkDark"
FIRE, TOXIC, RUNE = "Neon_Common_Fire", "Neon_Swamp_Toxic", "Neon_Swamp_Magic"


def build():
    M = Model("Swamp_4_GiantCauldron", target=(50, 50, 34), seed=331)
    rng = random.Random(6)
    # --- ash bed, logs and flames ------------------------------------------------------------------
    M.rings(CHAR, [(0, 19.0), (0.7, 17.5)], n=12, jit=0.06, seed=1)
    for k in range(9):
        a = 20 + k * 40 + rng.uniform(-6, 6)
        p0, p1 = polar(4.5, a, 1.8), polar(20.5 + rng.uniform(-1.5, 1.5), a + rng.uniform(-10, 10), 1.9)
        M.tube(WOOD, [p0, p1], 1.9, n=6)
        M.rings(CHAR, [(0, 1.5), (0.3, 1.3)], n=6, loc=tuple(p1 + (p1 - p0).normalized() * 0.05),
                rot=(0, 90, math.degrees(math.atan2(p1.y - p0.y, p1.x - p0.x))))
    for k in range(10):
        a = k * 36 + rng.uniform(-8, 8)
        r = rng.uniform(9.5, 16.5)
        h = rng.uniform(4.0, 7.5) if r > 13 else rng.uniform(3.0, 5.0)
        M.rings(FIRE, [(0, 1.6), (h * 0.35, 1.9, 1.9, 0.3, 0), (h, 0, 0, -0.5, 0.4)], n=5, loc=tuple(polar(r, a, 1.2)), rot=(0, 0, a))
    # --- three stone supports --------------------------------------------------------------------------
    for k, a in enumerate((90, 210, 330)):
        with M.xf(rot=(0, 0, a)):
            M.block(STONE, (8.5, 9.5, 6.0), loc=(15.5, 0, 0), base=True, chamfer=0.16, jit=0.04, seed=10 + k)
            M.block(STONE, (7.0, 8.0, 5.2), loc=(14.6, 0, 5.6), base=True, chamfer=0.18, jit=0.04, taper=0.9, seed=20 + k)
    # --- the cauldron ----------------------------------------------------------------------------------------
    M.rings(IRON, [(7.6, 8.5), (9.6, 15.0), (14.0, 19.6), (20.0, 21.4), (25.5, 20.4), (28.6, 19.0), (30.0, 19.8),
                   (31.6, 21.0), (31.6, 18.6), (29.4, 18.2)], n=12)
    M.ring_wall(BAND, 19.2, 21.9, 30.2, 32.2, n=12, phase=-75)                                        # rim band (open ring)
    M.rings(BAND, [(18.6, 21.75), (20.6, 21.85)], n=12)                                               # belly band
    M.rings(TOXIC, [(29.0, 18.4), (31.2, 19.0)], n=12)                                                # liquid surface
    for (x, y, r) in ((-7, 4, 3.6), (5, -6, 2.8), (9, 7, 3.2), (-3, -10, 2.2), (-11, -6, 2.0), (1, 11, 1.8)):
        M.blob(TOXIC, (r, r, r * 0.9), sub=1, jit=0.06, loc=(x, y, 31.1 + r * 0.15))
    M.blob(TOXIC, 1.2, sub=1, jit=0.05, loc=(-6.0, 5.0, 35.6))                                        # popped-off bubbles
    M.blob(TOXIC, 0.9, sub=1, jit=0.05, loc=(6.4, -5.0, 34.6))
    for k, a in enumerate((35, 150, 265)):                                                            # drips over the rim
        with M.xf(rot=(0, 0, a)):
            M.box(TOXIC, (3.4, 1.4, 1.2), loc=(20.6, 0, 31.9), rot=(0, 0, 90))
            M.box(TOXIC, (1.0, 2.6, 6.0 + 2 * k), loc=(21.9, 0, 29.2 - k), taper=(1.0, 0.4), rot=(180, 0, 0))
    # rune band under the rim
    for k in range(16):
        a = k * 22.5 + 11.25
        shape = ((2.0, 3.0), (2.8, 1.6), (1.2, 3.2), (2.4, 2.4))[k % 4]
        M.box(RUNE, (0.9, shape[0], shape[1]), loc=tuple(polar(20.75, a, 24.6)), rot=(0, 0, a))
    # ring handles on both sides
    for sx in (-1, 1):
        M.box(BAND, (2.6, 3.0, 2.6), loc=(sx * 21.6, 0, 26.0))
        with M.xf(loc=(sx * 23.3, 0, 23.0), rot=(0, sx * 12, 0)):
            M.tube(BAND, [(0, 3.2 * math.cos(math.radians(45 * i)), 3.2 * math.sin(math.radians(45 * i))) for i in range(8)],
                   0.75, n=4, closed=True, up=(1, 0, 0))
    # --- giant ladle leaning in the brew ---------------------------------------------------------------------
    M.tube(WOOD, [(3.0, -2.5, 31.4), (13.5, -12.5, 33.0), (22.5, -21.0, 34.2)], [1.1, 1.0, 0.9], n=6)
    M.rings(BAND, [(0, 1.3), (1.6, 1.3)], n=6, loc=(21.4, -20.0, 34.1), rot=(0, 86, -43))
    M.blob(IRON, (3.6, 3.6, 2.6), sub=1, jit=0.04, flat=0.1, loc=(2.2, -1.8, 31.2), rot=(180, 0, 0))
    M.ref_pos = (27.0, -16.0)
    M.view_dir = (0.6, -1.4, 0.75)
    return M


if __name__ == "__main__":
    run(build)
