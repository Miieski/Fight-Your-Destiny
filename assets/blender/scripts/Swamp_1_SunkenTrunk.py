"""Swamp_1_SunkenTrunk - gigantic hollow tree trunk lying half sunk at an angle: roots at one end, open hollow at the other."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

BARK, DARK, WOOD, MUD = "Swamp_Bark", "Swamp_BarkDark", "Swamp_Wood", "Swamp_Mud"
MOSS, MOSS_D, GLOW = "Swamp_Moss", "Swamp_MossDark", "Neon_Swamp_MushroomGlow"
N = 10
X_SOLID, X_END = 56.0, 82.0


def R(x):
    return lerp(17.5, 13.0, x / 90.0)


def pt(x, r, ang_deg, j=1.0):
    a = math.radians(ang_deg)
    return (x, r * j * math.cos(a), r * j * math.sin(a))


def build():
    M = Model("Swamp_1_SunkenTrunk", target=(110, 40, 45), seed=301)
    M.clip_z = 0.0
    rng = random.Random(4)
    M.stack[0] = TRS(scale=(0.965, 0.8, 1.0))       # squeeze the root fan into the footprint
    J = [1.0 + rng.uniform(-0.07, 0.07) for _ in range(N)]
    ang = [360.0 * i / N + 18 for i in range(N)]
    with M.xf(loc=(-44, 5.5, 3.0), rot=(0, -2.2, -7.5)):
        # --- solid part of the trunk ---------------------------------------------------------------
        M.loft(BARK, [[pt(x, R(x), ang[i] + x * 0.25, J[i]) for i in range(N)] for x in (-2, 14, 34, X_SOLID)])
        M.loft(DARK, [[pt(x, R(X_SOLID) - 2.4, ang[i], 1.0) for i in range(N)] for x in (X_SOLID - 0.5, X_SOLID + 0.8)])   # dark plug
        # --- hollow part: staves with a jagged broken end, dark inside ----------------------------------
        tw = X_SOLID * 0.25
        for i in range(N):
            j0, j1 = J[i], J[(i + 1) % N]
            a0, a1 = ang[i] + tw, ang[(i + 1) % N] + tw
            if a1 < a0:
                a1 += 360.0
            end = X_END + rng.uniform(-9.0, 8.0)
            xs = [X_SOLID - 1.0, (X_SOLID + end) / 2.0, end]
            for x0, x1 in zip(xs[:-1], xs[1:]):
                ro0, ro1 = R(x0), R(x1)
                tip = 2.2 if x1 == end else 0.0
                M.hull(BARK, [pt(x0, ro0, a0, j0), pt(x0, ro0, a1, j1), pt(x0, ro0 - 2.6, a0), pt(x0, ro0 - 2.6, a1),
                              pt(x1, ro1, a0, j0), pt(x1 + tip, ro1, a1, j1), pt(x1, ro1 - 2.6, a0), pt(x1 + tip, ro1 - 2.6, a1)])
                M.hull(DARK, [pt(x0, ro0 - 2.5, a0), pt(x0, ro0 - 2.5, a1), pt(x0, ro0 - 3.0, a0), pt(x0, ro0 - 3.0, a1),
                              pt(x1 - 0.6, ro1 - 2.5, a0), pt(x1 - 0.6 + tip, ro1 - 2.5, a1), pt(x1 - 0.6, ro1 - 3.0, a0),
                              pt(x1 - 0.6 + tip, ro1 - 3.0, a1)])
            # pale heartwood showing on the broken ends
            M.hull(WOOD, [pt(end - 0.2, R(end) - 0.4, a0 + 2), pt(end + 2.0, R(end) - 0.4, a1 - 2), pt(end - 0.2, R(end) - 2.3, a0 + 2),
                          pt(end + 2.0, R(end) - 2.3, a1 - 2), pt(end + 0.5, R(end) - 0.4, a0 + 2), pt(end + 2.7, R(end) - 0.4, a1 - 2),
                          pt(end + 0.5, R(end) - 2.3, a0 + 2), pt(end + 2.7, R(end) - 2.3, a1 - 2)])
            # hanging moss from the upper rim of the opening
            am = (a0 + a1) / 2.0
            if 35 < am % 360 < 145:
                p = Vector(pt(end - 1.0, R(end) - 2.8, am))
                h = rng.uniform(3.5, 7.5)
                M.box(MOSS_D, (0.9, 2.6, h), loc=(p.x, p.y, p.z - h / 2.0), taper=(1.0, 0.35), rot=(180, 0, 0))
        # --- root plate + roots at the other end -----------------------------------------------------------
        M.loft(MUD, [[pt(x, r, ang[i], J[i]) for i in range(N)] for x, r in ((-7.5, 13.0), (-5.0, 19.5), (-1.0, 20.5), (0.5, 17.0))])
        for k, th in enumerate((-14, 12, 38, 64, 90, 116, 142, 168, 194)):
            L = 16.0 + 28.0 * max(0.0, math.sin(math.radians(th)))
            th2 = th + rng.uniform(-14, 14)
            pts = [pt(-3.0, 11.0, th), pt(-8.0, L * 0.55, (th + th2) / 2), pt(-11.0 + rng.uniform(-4, 3), L * 0.85, th2),
                   pt(-9.0 + rng.uniform(-6, 4), L, th2 + rng.uniform(-10, 10))]
            M.tube(BARK, pts, [3.6, 2.6, 1.6, 0.4], n=5, jit=0.08)
            if k % 2 == 0:
                q = Vector(pts[2])
                M.tube(BARK, [q, q + V(rng.uniform(-6, -2), rng.uniform(-5, 5), rng.uniform(1, 6))], [1.3, 0.3], n=4)
            if 30 < th < 150 and k % 2:
                p = Vector(pts[2])
                h = rng.uniform(4, 8)
                M.box(MOSS_D, (0.9, 2.4, h), loc=(p.x, p.y, p.z - h / 2.0 - 1.0), taper=(1.0, 0.35), rot=(180, 0, 0))
        # --- broken branch stub, knot hole, moss, glowing mushrooms -------------------------------------------
        M.tube(BARK, [pt(30, 13, 78), pt(33, 21, 80), pt(38, 27, 74)], [4.2, 3.2, 2.4], n=6, jit=0.08)
        M.rings(WOOD, [(0, 2.2), (0.8, 1.6)], n=6, loc=pt(38.4, 27.4, 74), rot=(0, 55, 0))
        M.rings(DARK, [(0, 3.6, 2.6), (1.0, 2.8, 2.0)], n=7, loc=pt(18, R(18) - 0.6, 152), rot=(62, 0, 0))    # knot hole (front)
        for (x, a, s) in ((6, 88, 1.0), (20, 70, 1.2), (32, 104, 0.9), (46, 84, 1.1), (60, 96, 1.0), (72, 72, 0.9)):
            M.blob(MOSS, (7.0 * s, 5.0 * s, 1.6), sub=1, jit=0.12, flat=0.3, loc=pt(x, R(x) + 0.4, a), rot=(0, 0, 0))
        for (x, a, s) in ((6, 160, 1.2), (9, 150, 0.8), (11, 168, 0.9), (26, 146, 1.1), (29, 158, 0.8), (40, 164, 1.2),
                          (43, 150, 0.9), (52, 142, 1.0), (63, 158, 1.0), (66, 146, 0.7), (75, 152, 1.0), (72, 166, 0.8)):
            p = Vector(pt(x, R(x) + 0.9, a))                    # shelf mushrooms on the front flank
            M.blob(GLOW, (3.0 * s, 3.2 * s, 1.0 * s), sub=1, jit=0.08, flat=0.3, loc=tuple(p))
    # mud mound at the root end + mushrooms inside the hollow mouth (world space)
    M.blob(MUD, (17, 15, 4.5), sub=2, jit=0.08, flat=0.05, loc=(-48, 4, 0.2), seed=9)
    for (x, y, s) in ((44, -12.5, 1.0), (47, -9.5, 0.7), (33, 9.5, 0.9)):
        M.rings(WOOD, [(0, 0.5 * s), (2.6 * s, 0.4 * s)], n=5, loc=(x, y, 0))
        M.blob(GLOW, (2.0 * s, 2.0 * s, 1.1 * s), sub=1, jit=0.08, flat=0.2, loc=(x, y, 2.9 * s))
    M.notes = "Hollow end (right side, +X): the opening is about 20 wide x 14 high above the ground, 26 deep, dark inside."
    M.ref_pos = (52.0, -16.0)
    M.view_dir = (0.75, -1.4, 0.5)
    return M


if __name__ == "__main__":
    run(build)
