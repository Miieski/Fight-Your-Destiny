"""Swamp_3_WitchTower - tall crooked witch tower on stilts: leaning storeys, bent pointed roof, glowing round windows."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

WALL, BEAM, DARK, ROOF = "Swamp_Wood", "Swamp_Bark", "Swamp_BarkDark", "Swamp_MagicDark"
MAGIC, LANTERN, MOSS, IRON = "Neon_Swamp_Magic", "Neon_Swamp_Lantern", "Swamp_Moss", "Common_Iron"


def storey(M, w, h, window_z, door=False):
    """Walls + corner posts + overhanging floor slab on top; round glowing windows on the front and right walls."""
    M.box(WALL, (w, w, h), base=True, taper=1.04)
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.box(DARK, (1.5, 1.5, h + 0.4), loc=(sx * w / 2 * 1.01, sy * w / 2 * 1.01, 0), base=True)
    M.box(BEAM, (w + 4.0, w + 4.0, 1.3), loc=(0, 0, h), base=True)
    for k, rz in enumerate((0, 90)):
        with M.xf(rot=(0, 0, rz)):
            yf = -w / 2 * 1.02
            M.rings(DARK, [(0, 3.6), (0.9, 3.4)], n=8, loc=(0, yf + 0.2, window_z), rot=(90, 0, 0))
            M.rings(MAGIC, [(0, 2.6), (1.3, 2.3)], n=8, loc=(0, yf + 0.2, window_z), rot=(90, 0, 0))
            M.box(DARK, (0.5, 0.5, 5.4), loc=(0, yf - 1.2, window_z))
            M.box(DARK, (5.4, 0.5, 0.5), loc=(0, yf - 1.2, window_z))
    if door:
        M.box(DARK, (5.6, 1.0, 9.6), loc=(-4.4, -w / 2 - 0.1, 0), base=True)
        M.box(BEAM, (4.4, 1.3, 8.6), loc=(-4.4, -w / 2 - 0.1, 0), base=True)
        M.box(MAGIC, (0.7, 1.5, 0.7), loc=(-3.0, -w / 2 - 0.2, 4.4))


def build():
    M = Model("Swamp_3_WitchTower", target=(40, 40, 95), seed=321)
    rng = random.Random(8)
    SXY, SZ = 1.05, 0.935                           # fit into 40 x 40 x 95
    M.stack[0] = TRS(scale=(SXY, SXY, SZ))
    PZ = 24.0
    # --- crooked stilts with braces ------------------------------------------------------------------
    feet = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            foot = V(sx * (15.5 + rng.uniform(-1, 1)), sy * (15.0 + rng.uniform(-1, 1)), 0)
            knee = V(sx * (11.0 + rng.uniform(-1.5, 1.5)), sy * (12.5 + rng.uniform(-1.5, 1.5)), 12 + rng.uniform(-2, 2))
            top = V(sx * 10.0, sy * 10.0, PZ)
            M.tube(BEAM, [foot, knee, top], [1.9, 1.6, 1.5], n=5)
            feet.append((foot, knee, top))
    for i, j in ((0, 1), (2, 3), (0, 2), (1, 3)):
        M.tube(DARK, [feet[i][1], feet[j][2] - V(0, 0, 2.0)], 0.7, n=4)
        M.tube(DARK, [feet[j][1], feet[i][2] - V(0, 0, 2.0)], 0.7, n=4)
    # --- platform + railing (open at the top of the stairs) ----------------------------------------------
    M.box(BEAM, (27.0, 27.0, 1.5), loc=(0, 0, PZ), base=True)
    for k in range(-3, 4):
        M.box(DARK, (27.6, 0.5, 1.7), loc=(0, k * 3.8, PZ - 0.05), base=True)                  # plank gaps
    Z0 = PZ + 1.5
    for (x0, y0, x1, y1) in ((-13, 13, 13, 13), (13, -13, 13, 13), (-13, -13, -13, 13), (-2, -13, 13, -13)):
        M.tube(BEAM, [(x0, y0, Z0 + 3.4), (x1, y1, Z0 + 3.4 + rng.uniform(-0.4, 0.4))], 0.45, n=4)
        for t in (0.0, 0.33, 0.66, 1.0):
            M.box(BEAM, (0.8, 0.8, 3.5), loc=(lerp(x0, x1, t), lerp(y0, y1, t), Z0), base=True, rot=(rng.uniform(-5, 5), rng.uniform(-5, 5), 0))
    # --- three leaning storeys + crooked roof ----------------------------------------------------------------
    with M.xf(loc=(0.5, 1.0, Z0), rot=(2, -3, 4)):
        storey(M, 18.5, 15.5, 9.0, door=True)
        # lantern bracket on the front right corner
        M.tube(BEAM, [(8.6, -8.6, 13.0), (12.5, -13.5, 14.2)], 0.6, n=4)
        M.tube(IRON, [(12.3, -13.2, 14.0), (12.3, -13.2, 10.6)], 0.2, n=4)
        M.rings(IRON, [(0, 0.5), (0.5, 1.4), (0.9, 1.4)], n=6, loc=(12.3, -13.2, 9.7))
        M.rings(LANTERN, [(0, 0.9), (1.6, 1.2), (3.0, 0.9)], n=6, loc=(12.3, -13.2, 6.9))
        M.rings(IRON, [(0, 1.4), (0.5, 1.0)], n=6, loc=(12.3, -13.2, 6.4))
        with M.xf(loc=(1.3, 0.7, 16.8), rot=(-4, 4, -9)):
            storey(M, 15.5, 14.0, 8.0)
            M.tube(DARK, [(7.4, 3.0, 5.0), (10.2, 3.6, 8.0), (10.0, 3.2, 17.0), (11.2, 2.4, 22.0)], [1.6, 1.5, 1.3, 1.2], n=5)   # chimney
            M.rings(IRON, [(0, 1.7), (0.8, 1.7)], n=5, loc=(11.2, 2.4, 22.0))
            with M.xf(loc=(-0.8, -0.5, 15.3), rot=(5, -5, 13)):
                storey(M, 12.5, 12.5, 7.0)
                with M.xf(loc=(0, 0, 13.8)):
                    M.rings(ROOF, [(0, 11.8), (1.6, 10.0), (8.0, 6.2, 6.2, 1.0, 0.4), (15.0, 3.4, 3.4, 3.2, 1.0),
                                   (21.0, 1.6, 1.6, 6.4, 1.6), (25.0, 0.8, 0.8, 9.4, 1.4), (26.2, 0, 0, 11.6, 0.6)], n=6, jit=0.05)
                    M.blob(MOSS, (4.2, 3.6, 1.4), sub=1, jit=0.12, flat=0.3, loc=(-5.0, -3.6, 3.6), rot=(20, -25, 0))
                    M.blob(MOSS, (3.2, 2.8, 1.2), sub=1, jit=0.12, flat=0.3, loc=(4.4, 5.0, 5.4), rot=(-25, 20, 0))
                    M.rings(MAGIC, [(0, 0), (1.2, 0.9), (2.4, 0)], n=5, loc=(11.6, 0.6, 26.4))          # star at the hooked tip
    M.blob(MOSS, (5.0, 3.0, 1.2), sub=1, jit=0.12, flat=0.3, loc=(-9.0, 9.5, Z0 + 0.1))
    M.blob(MOSS, (3.4, 4.4, 1.2), sub=1, jit=0.12, flat=0.3, loc=(10.5, 4.0, Z0 + 0.1))
    # --- crooked stairs along the front, from the ground (left) up to the platform ---------------------------
    steps = 12
    x0, x1, ys = -19.0, -3.5, -16.4
    for k in range(steps):
        t = (k + 0.5) / steps
        M.box(WALL, (2.2, 6.4, 0.6), loc=(lerp(x0, x1, t), ys + rng.uniform(-0.4, 0.4), (k + 1) * (PZ + 1.5) / steps - 0.3),
              rot=(rng.uniform(-5, 5), rng.uniform(-4, 4), rng.uniform(-7, 7)))
    for sy in (-1, 1):
        M.tube(BEAM, [(x0 - 1.0, ys + sy * 2.9, 0.0), (x1 + 0.8, ys + sy * 2.9, PZ + 0.6)], 0.55, n=4)
    M.tube(BEAM, [(x0 + 0.3, ys - 3.2, 4.6), (x1 + 0.6, ys - 3.2, PZ + 5.2)], 0.4, n=4)                 # hand rail
    for t in (0.05, 0.5, 0.95):
        x, z = lerp(x0, x1, t), lerp(1.0, PZ + 1.4, t)
        M.box(BEAM, (0.7, 0.7, 4.2), loc=(x, ys - 3.2, z), base=True, rot=(0, rng.uniform(-6, 6), 0))
    M.tube(BEAM, [((x0 + x1) / 2, ys, 0), ((x0 + x1) / 2 + 0.6, ys, PZ / 2 + 0.6)], 0.8, n=4)             # mid support
    M.box(BEAM, (5.0, 4.4, 1.2), loc=(x1 + 2.4, -14.6, PZ + 0.3), base=True)                               # landing
    M.notes = "Platform at Z %.1f on four stilts (players can walk under it); stairs: 12 steps of %.1f high along the front." % ((PZ + 1.5) * SZ, (PZ + 1.5) / 12 * SZ)
    M.ref_pos = (8.0, -21.0)
    M.view_dir = (0.7, -1.4, 0.45)
    return M


if __name__ == "__main__":
    run(build)
