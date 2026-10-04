"""Volcano_4_StoneTitan - colossal stone titan rising from a lava pool: waist up, one arm raised, one fist on the ground."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

BASALT, LIGHT, DARK, OBS = "Volcano_Basalt", "Volcano_BasaltLight", "Volcano_BasaltDark", "Volcano_Obsidian"
LAVA, HOT, CRUST = "Neon_Volcano_Lava", "Neon_Volcano_LavaHot", "Volcano_LavaCrust"


def crack(M, pts, r=0.5):
    M.tube(LAVA, pts, [r * 0.5] + [r] * (len(pts) - 2) + [0.0], n=3)


def limb_crack(M, a, b, ra, rng):
    """Glowing zigzag along the front of a limb between a and b."""
    a, b = V(a), V(b)
    pts = []
    for i in range(5):
        t = 0.12 + 0.19 * i
        p = a.lerp(b, t)
        pts.append(p + V(rng.uniform(-1, 1) * ra * 0.35, -ra * 0.93, rng.uniform(-0.6, 0.6)))
    crack(M, pts, 0.55)


def build():
    M = Model("Volcano_4_StoneTitan", target=(60, 46, 70), seed=431)
    M.clip_z = 0.0
    rng = random.Random(13)
    # --- lava pool with a broken crust rim ----------------------------------------------------------
    M.rings(LAVA, [(0, 27.5, 20.5, 0, 0), (0.7, 26.8, 19.8, 0, 0)], n=14, jit=0.05, seed=1)
    for k in range(14):
        a = k * 360.0 / 14 + rng.uniform(-7, 7)
        s = rng.uniform(4.5, 8.0)
        p = V(27.5 * math.cos(math.radians(a)), 20.5 * math.sin(math.radians(a)), 0)
        M.rock(CRUST if k % 3 else DARK, (s, s * 0.85, s * 0.5), loc=tuple(p * 0.97), seed=20 + k)
    for (x, y, s) in ((-7, -12, 5.0), (9, -15, 4.0), (16, -3, 4.5), (-15, 11, 4.0)):        # crust plates floating on the pool
        M.block(CRUST, (s * 1.6, s, 1.0), loc=(x, y, 0.9), rot=(rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(0, 90)), chamfer=0.25)
    # --- torso, leaning forward ----------------------------------------------------------------------
    M.block(DARK, (23.0, 15.0, 15.0), loc=(0, 5.0, -1.0), base=True, chamfer=0.16, jit=0.04, seed=2)       # waist
    with M.xf(loc=(0, 5.0, 12.5), rot=(9, 0, 0)):
        M.block(BASALT, (31.0, 18.5, 20.0), loc=(0, 0, 0), base=True, chamfer=0.16, jit=0.03, taper=1.12, seed=3)   # chest
        M.block(BASALT, (37.0, 17.5, 8.0), loc=(0, 0.4, 18.4), base=True, chamfer=0.22, jit=0.03, seed=4)           # shoulder yoke
        M.rock(LIGHT, (20.0, 9.0, 14.0), loc=(0, 8.0, 12.0), base=False, seed=5)                                    # back hump
        yf = -9.6
        # glowing heart and cracks radiating from it
        M.box(DARK, (8.2, 0.8, 8.2), loc=(0, yf - 0.3, 11.5), rot=(0, 45, 0))
        M.box(HOT, (5.6, 1.2, 5.6), loc=(0, yf - 0.5, 11.5), rot=(0, 45, 0))
        crack(M, [(-3.6, yf - 0.4, 12.6), (-7.0, yf - 0.5, 15.0), (-9.0, yf - 0.6, 13.6), (-13.0, yf - 0.8, 17.4)], 0.6)
        crack(M, [(3.6, yf - 0.4, 12.6), (6.6, yf - 0.5, 16.0), (10.0, yf - 0.6, 14.8), (13.6, yf - 0.8, 18.6)], 0.6)
        crack(M, [(-1.0, yf - 0.3, 6.6), (-3.4, yf - 0.2, 3.6), (-2.0, yf - 0.1, 0.8), (-5.0, yf, -3.0)], 0.6)
        crack(M, [(2.4, yf - 0.3, 7.4), (5.6, yf - 0.2, 4.6), (4.6, yf - 0.1, 1.6), (8.0, yf, -2.0)], 0.55)
        crack(M, [(-6.0, yf - 0.9, 21.0), (-3.0, yf - 0.9, 23.0), (-4.2, yf - 0.9, 25.6)], 0.5)
        # --- head ------------------------------------------------------------------------------------------
        with M.xf(loc=(0, -2.6, 26.2), rot=(6, 0, 0)):
            M.block(BASALT, (12.5, 12.0, 11.5), base=True, chamfer=0.2, jit=0.03, seed=6)
            M.block(LIGHT, (13.6, 3.4, 2.8), loc=(0, -5.2, 7.6), chamfer=0.25, seed=7)                    # brow
            M.block(DARK, (8.6, 3.4, 4.0), loc=(0, -5.4, 1.6), chamfer=0.25, seed=8)                      # jaw
            M.box(LAVA, (6.4, 1.0, 1.1), loc=(0, -7.0, 2.6))                                              # mouth glow
            for sx in (-1, 1):
                M.box(HOT, (3.0, 1.0, 1.5), loc=(sx * 3.1, -6.15, 5.4), rot=(0, sx * 14, 0))              # eyes
                M.spike(OBS, (sx * 4.6, 1.0, 10.5), 1.9, 8.0, n=4, rot=(0, sx * 24, 0))                   # horns
            M.spike(OBS, (0, 2.6, 10.8), 1.6, 5.0, n=4, rot=(-14, 0, 0))
        # --- shoulders with obsidian plates ---------------------------------------------------------------------
        for sx in (-1, 1):
            M.rock(BASALT, (15.0, 15.5, 13.0), loc=(sx * 20.5, 0.6, 21.5), base=False, npts=14, seed=10 + sx)
            for k, (dx, lean, h) in enumerate(((-3.5, 6, 9.0), (1.0, 20, 11.5), (5.0, 36, 9.0))):
                M.spike(OBS, (sx * (20.5 + dx), 0.6 + (k - 1) * 2.4, 25.6), 2.9, h, n=4, rot=(0, sx * lean, 0), waist=0.25)
    # --- right arm (viewer's right, +X): raised fist --------------------------------------------------------
    sh, el, wr = V(20.5, 2.0, 35.5), V(25.5, -1.0, 49.0), V(21.5, -5.0, 60.0)
    M.chunk(LIGHT, sh, el, 5.2, 4.8, n=6, jit=0.08, seed=30)
    M.chunk(BASALT, el, wr, 5.4, 6.0, n=6, jit=0.08, seed=31)
    M.block(BASALT, (11.5, 11.0, 10.5), loc=(20.6, -6.2, 64.4), rot=(10, -10, 8), chamfer=0.22, jit=0.03, seed=32)   # fist
    M.block(DARK, (12.6, 12.0, 2.2), loc=(21.3, -5.3, 58.0), rot=(10, -10, 8), chamfer=0.2, seed=33)                 # wrist band
    limb_crack(M, el, wr, 5.6, rng)
    crack(M, [(17.0, -11.9, 66.5), (19.6, -12.0, 64.0), (21.6, -12.1, 66.0), (24.0, -12.0, 62.6)], 0.5)
    # --- left arm (-X): fist planted on the ground in front ---------------------------------------------------------
    sh, el, wr = V(-20.5, 2.0, 34.0), V(-25.0, -6.5, 20.5), V(-21.5, -13.0, 9.0)
    M.chunk(LIGHT, sh, el, 5.2, 4.8, n=6, jit=0.08, seed=34)
    M.chunk(BASALT, el, wr, 5.4, 6.2, n=6, jit=0.08, seed=35)
    M.block(BASALT, (12.5, 12.0, 11.0), loc=(-21.0, -15.5, -0.5), base=True, rot=(0, 0, -10), chamfer=0.22, jit=0.03, seed=36)   # fist
    M.block(DARK, (13.4, 13.0, 2.2), loc=(-21.4, -13.6, 11.2), rot=(18, 0, -10), chamfer=0.2, seed=37)
    limb_crack(M, el, wr, 5.8, rng)
    crack(M, [(-25.0, -21.7, 8.6), (-22.6, -21.8, 5.6), (-20.4, -21.8, 7.0), (-18.0, -21.7, 2.6)], 0.5)
    # lava dripping from the raised arm and running off the waist
    for (x, y, z, h) in ((24.0, -2.0, 46.0, 5.0), (27.0, 0.5, 44.5, 3.4), (-9.0, -3.2, 6.0, 4.0), (8.5, -3.0, 5.0, 3.4)):
        M.icicle(LAVA, (x, y, z), 0.9, h, n=4)
    M.ref_pos = (30.0, -20.0)
    M.view_dir = (0.5, -1.5, 0.45)
    return M


if __name__ == "__main__":
    run(build)
