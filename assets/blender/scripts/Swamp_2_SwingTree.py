"""Swamp_2_SwingTree - huge twisted dead tree with a face in the bark, crooked branches, an old rope swing, crows."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

BARK, DARK, MOSS_D, MUD = "Swamp_Bark", "Swamp_BarkDark", "Swamp_MossDark", "Swamp_Mud"
ROPE, WOOD, BONE = "Common_Rope", "Swamp_Wood", "Swamp_Bone"


def crow(M, p, yaw):
    with M.xf(loc=tuple(p), rot=(0, 0, yaw)):
        M.blob(DARK, (1.5, 2.5, 1.5), sub=1, jit=0.05, loc=(0, 0, 1.5), rot=(18, 0, 0))
        M.blob(DARK, (1.0, 1.1, 1.0), sub=1, jit=0.05, loc=(0, -1.7, 2.7))
        M.cone(BONE, 0.38, 1.3, n=4, loc=(0, -2.5, 2.6), rot=(100, 0, 0))
        M.box(DARK, (1.6, 2.6, 0.35), loc=(0, 2.6, 1.3), rot=(-20, 0, 0), taper=(1.0, 1.0))
        for sx in (-1, 1):
            M.box(BONE, (0.25, 0.25, 0.25), loc=(sx * 0.6, -2.2, 3.0))


def build():
    M = Model("Swamp_2_SwingTree", target=(80, 70, 85), seed=311)
    M.clip_z = 0.0
    M.stack[0] = TRS(scale=(0.84, 1.0, 0.91))        # fit the crown into about 85 x 65 x 85
    rng = random.Random(12)
    # --- mound, roots, twisted trunk -------------------------------------------------------------------
    M.blob(MUD, (22, 20, 4.0), sub=2, jit=0.07, flat=0.08, loc=(0, 0, 0.3), seed=1)
    for i, a in enumerate((-60, -5, 50, 110, 170, 235)):
        L = 19 + (i % 3) * 3
        M.tube(BARK, [polar(7.0, a, 9.5), polar(12.0, a + 8, 5.5), polar(L * 0.8, a + 16, 2.6), polar(L, a + 24, -0.5)],
               [3.6, 2.9, 1.9, 0.6], n=5, jit=0.08)
    M.rings(BARK, [(1, 11.5), (6, 9.2, 9.2, 0, 0, 10), (17, 7.8, 7.6, 0.4, 0, 28), (30, 7.2, 7.0, 1.6, 0.4, 48),
                   (42, 6.6, 6.4, 3.0, 1.0, 66), (52, 5.2, 5.2, 3.4, 1.4, 80)], n=9, jit=0.1, seed=2)
    # --- face in the bark (front) --------------------------------------------------------------------------
    with M.xf(loc=(0.9, -7.3, 21.0), rot=(-3, 0, 0)):
        for sx in (-1, 1):
            eye = [(sx * 1.0, 3.2), (sx * 4.6, 5.6), (sx * 5.4, 3.6), (sx * 3.6, 1.6), (sx * 1.6, 1.8)]
            M.extrude(DARK, eye, 2.4, loc=(0, 0.4, 0))
            M.box(BONE, (0.9, 0.6, 0.9), loc=(sx * 3.1, -0.85, 3.2), rot=(0, 45, 0))                       # pupil glint
            M.chunk(BARK, (sx * 0.6, -1.0, 4.2), (sx * 5.8, -1.3, 7.0), 1.3, 0.9, n=5, jit=0.1)            # brow
        M.chunk(BARK, (0, -1.6, 2.8), (0.3, -2.2, -1.6), 1.4, 1.9, n=5, jit=0.1)                           # nose
        mouth = [(-5.6, -3.4), (-3.6, -5.0), (-2.4, -4.0), (-0.8, -5.6), (0.8, -4.4), (2.4, -5.8), (3.8, -4.4), (5.8, -3.0),
                 (4.6, -7.6), (2.4, -9.2), (-0.4, -9.8), (-3.2, -8.8), (-5.0, -6.6)]
        M.extrude(DARK, mouth, 2.6, loc=(0, 0.3, 0))
    # --- the big swing branch (explicit) + its twigs ----------------------------------------------------------
    big = [V(3, 0, 41), V(15, -2.0, 47), V(28, -3.0, 49.5), V(40, -2.2, 54)]
    M.tube(BARK, big, [4.6, 3.6, 2.8, 1.8], n=6, jit=0.08, seed=3)
    out = []
    M.branch(BARK, big[-1], (1.0, 0.2, 0.5), 15, 1.7, 1, rng, out, bend=0.3)
    # other crooked branches
    for (p, d, L, r) in (((2, 1, 38), (-1.0, 0.25, 0.45), 30, 3.8), ((3, 2, 46), (-0.2, 1.0, 0.6), 24, 3.2),
                         ((3.4, 0, 49), (-0.45, -0.9, 0.75), 23, 3.0), ((3.4, 1.4, 51), (0.25, 0.1, 1.0), 20, 3.2)):
        M.branch(BARK, p, d, L, r, 2, rng, out, bend=0.38, lift=(0.0, 0.5))
    # hanging moss
    for pts, rad, depth in out:
        for i in (1, 2):
            if rng.random() < 0.6:
                p = pts[i]
                h = rng.uniform(4.0, 9.0)
                M.box(MOSS_D, (0.8, 2.4, h), loc=(p.x, p.y, p.z - h / 2.0 - rad[i] * 0.5), rot=(180, 0, rng.uniform(0, 180)),
                      taper=(1.0, 0.3))
    for t in (0.2, 0.5, 0.86):
        p = big[1].lerp(big[2], t)
        h = rng.uniform(5.0, 8.0)
        M.box(MOSS_D, (2.6, 0.8, h), loc=(p.x, p.y + 1.6, p.z - h / 2.0 - 2.0), rot=(180, 0, 0), taper=(0.3, 1.0))
    # --- the old swing ----------------------------------------------------------------------------------------
    a, b = big[1].lerp(big[2], 0.38), big[1].lerp(big[2], 0.82)
    seat = V((a.x + b.x) / 2, -7.0, 6.2)                       # hangs a little askew, as if still swaying
    half = (b.x - a.x) / 2.0
    for s, top in ((-1, a), (1, b)):
        end = seat + V(s * half * 0.92, 0, 0.3)
        M.tube(ROPE, [top - V(0, 0, 2.2), top.lerp(end, 0.5) + V(0, -0.3, 0), end], 0.34, n=4)
        M.rings(ROPE, [(0, 3.2), (1.2, 3.2)], n=6, loc=(top.x - 0.6, top.y, top.z), rot=(0, 90, 0))         # rope wrapped on the branch
    M.box(WOOD, (half * 2 + 2.4, 3.0, 0.7), loc=tuple(seat), rot=(8, 0, 0))
    M.tube(ROPE, [seat + V(-half, 0, -0.2), seat + V(-half - 0.3, 0.3, -3.6)], [0.3, 0.12], n=4)            # frayed end
    # --- crows --------------------------------------------------------------------------------------------------
    crow(M, big[1].lerp(big[2], 0.08) + V(0, 0, 3.0), 20)
    crow(M, big[2].lerp(big[3], 0.55) + V(0, 0, 2.2), -30)
    k = 0
    for pts, rad, depth in out:
        if depth == 1 and k < 3 and pts[1].x < 0:
            crow(M, pts[2] + V(0, 0, rad[2] * 0.8), 40 * k - 20)
            k += 1
    M.ref_pos = (14.0, -20.0)
    return M


if __name__ == "__main__":
    run(build)
