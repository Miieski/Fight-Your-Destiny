"""Hell_1_SkullRock - giant skull-shaped rock rising from a lava pool: half-sunk jaw, glowing sockets, rock horns."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

ROCK, DARK, BLACK, HORN, BONE, GROUND = "Hell_Tile", "Hell_GroundDark", "Hell_Black", "Hell_Iron", "Hell_Bone", "Hell_Ground"
LAVA, HOT = "Neon_Hell_Lava", "Neon_Hell_LavaHot"
C = V(0, 4, 47)
RX, RY, RZ = 26.0, 27.0, 23.0


def surf(x, z):
    """Y of the front of the cranium at (x, z)."""
    t = 1.0 - (x / RX) ** 2 - ((z - C.z) / RZ) ** 2
    return C.y - RY * math.sqrt(max(t, 0.02))


def sp(az, el, k=1.03):
    a, e = math.radians(az), math.radians(el)
    return C + V(RX * math.cos(e) * math.cos(a), RY * math.cos(e) * math.sin(a), RZ * math.sin(e)) * k


def build():
    M = Model("Hell_1_SkullRock", target=(74, 70, 80), seed=501)
    M.clip_z = 0.0
    rng = random.Random(3)
    # --- lava pool + rubble ring --------------------------------------------------------------------
    M.rings(LAVA, [(0, 36.5, 34.5), (0.6, 36.0, 34.0)], n=14, jit=0.05, seed=1)
    for k in range(13):
        a = k * 360.0 / 13 + rng.uniform(-8, 8)
        if -125 < ((a + 180) % 360 - 180) < -55:
            continue                                               # keep the front of the jaw readable
        s = rng.uniform(6.0, 11.0)
        p = V(31.0 * math.cos(math.radians(a)), 29.5 * math.sin(math.radians(a)), 0)
        M.rock((DARK, GROUND, BLACK)[k % 3], (s, s * 0.9, s * 0.7), loc=tuple(p), seed=20 + k)
    for (x, y, s) in ((-25, -24, 5.0), (27, -22, 4.0), (-12, -30, 3.5)):
        M.rock(GROUND, (s * 1.3, s, s * 0.6), loc=(x, y, 0), seed=int(40 + x))
    # --- base rock under the skull + cranium -------------------------------------------------------------
    M.block(DARK, (38, 36, 32), loc=(0, 9, -1), base=True, chamfer=0.2, jit=0.05, seed=2)
    M.rock(GROUND, (46, 40, 22), loc=(0, 10, 0), npts=16, seed=3)
    M.blob(ROCK, (RX, RY, RZ), sub=2, jit=0.06, loc=tuple(C), seed=4)
    # --- face ------------------------------------------------------------------------------------------------
    for sx in (-1, 1):
        y0 = surf(sx * 10.5, 44) + 1.5
        M.rings(BLACK, [(0, 8.2, 7.2), (2.0, 7.4, 6.4)], n=6, loc=(sx * 10.5, y0, 44), rot=(90, 0, 0))            # socket
        M.rings(LAVA, [(0, 5.4, 4.8), (2.6, 4.6, 4.0)], n=6, loc=(sx * 10.5, y0, 44), rot=(90, 0, 0))
        M.rings(HOT, [(0, 2.4, 2.4), (3.1, 1.9, 1.9)], n=5, loc=(sx * 10.5, y0, 43.6), rot=(90, 0, 0))
        M.block(DARK, (19.5, 8.5, 6.5), loc=(sx * 11.5, -22.6, 53.6), rot=(0, -sx * 14, 0), chamfer=0.22, jit=0.04, seed=5)   # brow
        M.block(DARK, (11, 10, 8.5), loc=(sx * 17.0, -17.5, 35.0), rot=(0, sx * 10, sx * 14), chamfer=0.22, jit=0.04, seed=6)  # cheekbone
        M.icicle(LAVA, (sx * 10.5, y0 - 1.6, 38.0), 1.3, 7.5, n=4)                                                 # lava tear
        M.tube(HORN, [(sx * 21, 6, 56), (sx * 31, 5, 61), (sx * 34.5, 3, 71), (sx * 30, 0, 80)], [7.0, 5.2, 3.0, 0.0], n=6,
               jit=0.08, seed=7)                                                                                  # horn
        M.spike(HORN, (sx * 9, 2, 66.0), 2.6, 7.0, n=4, rot=(0, sx * 18, 0))
    M.block(DARK, (6.5, 6.5, 10), loc=(0, -22.0, 44.5), chamfer=0.22, jit=0.04, seed=8)                            # nasal bridge
    M.block(ROCK, (29, 13, 19), loc=(0, -17.6, 29.0), chamfer=0.16, jit=0.04, seed=9)                              # mid face
    M.extrude(BLACK, [(-4.6, 26.5), (4.6, 26.5), (0, 37.5)], 2.0, loc=(0, -24.3, 0))                               # nose hole
    M.extrude(LAVA, [(-3.0, 27.6), (3.0, 27.6), (0, 35.0)], 2.8, loc=(0, -24.4, 0))
    M.spike(HORN, (0, 0, 68.0), 3.0, 8.5, n=4, rot=(-12, 0, 0))
    for k in range(7):                                                                                           # upper teeth
        x = -10.5 + 3.5 * k
        M.box(BONE, (2.9, 3.0, 5.6 if k % 2 == 0 else 4.4), loc=(x, -22.4, 18.6), rot=(180, 0, 0), taper=0.55)
    # --- lower jaw, tilted and half sunk in the lava -----------------------------------------------------------
    with M.xf(loc=(3.0, -13.0, 3.0), rot=(-11, 0, 7)):
        M.block(DARK, (31, 27, 12), loc=(0, -2, 0), chamfer=0.2, jit=0.04, seed=10)
        for k in range(7):
            x = -10.5 + 3.5 * k
            M.box(BONE, (2.9, 3.0, 4.8 if k % 2 else 3.8), loc=(x, -13.6, 5.6), base=True, taper=0.55)
    # --- cracks on the cranium (dark and glowing) ------------------------------------------------------------------
    M.tube(BLACK, [sp(-78, 74), sp(-88, 56), sp(-72, 44), sp(-80, 31)], [0.4, 0.9, 0.8, 0.0], n=3)
    M.tube(BLACK, [sp(-20, 60), sp(-32, 42), sp(-22, 28), sp(-30, 12)], [0.4, 0.9, 0.8, 0.0], n=3)
    M.tube(LAVA, [sp(-112, 68), sp(-120, 50), sp(-106, 38), sp(-116, 24)], [0.4, 0.8, 0.7, 0.0], n=3)
    M.tube(LAVA, [sp(-150, 55), sp(-160, 38), sp(-148, 24), sp(-156, 8)], [0.4, 0.8, 0.7, 0.0], n=3)
    M.tube(LAVA, [sp(-52, 72), sp(-44, 58), sp(-56, 50)], [0.4, 0.7, 0.0], n=3)
    M.ref_pos = (27.0, -36.5)
    M.view_dir = (0.55, -1.5, 0.45)
    return M


if __name__ == "__main__":
    run(build)
