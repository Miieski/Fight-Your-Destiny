"""Plains_4_GolemStatue - dormant stone golem kneeling on one knee, moss, cracks, glowing chest runes."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

BODY, LIMB, DARK = "Plains_Rock", "Plains_CaveRock", "Plains_CaveRockDark"
MOSS, RUNE = "Plains_Moss", "Neon_Plains_Ore"


def crack(M, pts, r=0.28):
    M.tube(DARK, pts, [r * 0.4] + [r] * (len(pts) - 2) + [0.0], n=3)


def build():
    M = Model("Plains_4_GolemStatue", target=(30, 22, 38), seed=51)
    M.stack[0] = TRS(scale=0.94)
    # --- plinth -------------------------------------------------------------------------------
    M.rings(LIMB, [(0, 15.5, 11.5), (1.2, 15.0, 11.0)], n=10, jit=0.04, seed=1)
    M.rings(DARK, [(1.2, 14.0, 10.2), (2.0, 13.6, 9.8)], n=10, jit=0.04, seed=1)
    Z = 2.0
    # --- legs ---------------------------------------------------------------------------------
    # left leg (+X): foot planted, knee up
    M.block(LIMB, (5.6, 8.0, 3.2), loc=(6.4, -5.6, Z), base=True, chamfer=0.2, seed=2)                 # foot
    M.chunk(LIMB, (6.4, -4.2, Z + 2.5), (6.6, -6.6, Z + 12.0), 3.0, 3.4, n=6, seed=3)                   # shin
    M.chunk(BODY, (6.6, -6.2, Z + 12.6), (5.0, 2.6, Z + 12.4), 3.9, 4.3, n=6, seed=4)                   # thigh
    M.rock(DARK, (5.0, 4.4, 4.4), loc=(6.7, -7.4, Z + 12.4), base=False, seed=5)                        # knee cap
    # right leg (-X): knee on the ground, shin back
    M.chunk(BODY, (-5.0, 2.4, Z + 12.0), (-6.6, -5.4, Z + 3.6), 4.3, 3.7, n=6, seed=6)                  # thigh
    M.chunk(LIMB, (-6.6, -4.6, Z + 2.9), (-6.4, 7.6, Z + 2.7), 3.0, 2.7, n=6, seed=7)                   # shin
    M.block(LIMB, (5.2, 3.6, 5.6), loc=(-6.4, 9.6, Z), base=True, chamfer=0.2, seed=8)                  # foot on toes
    M.rock(DARK, (5.0, 4.4, 4.2), loc=(-6.7, -6.0, Z + 2.6), base=False, seed=9)                        # knee
    # pelvis
    M.block(LIMB, (14.5, 9.0, 6.0), loc=(0, 2.6, Z + 12.8), chamfer=0.22, seed=10)
    M.block(DARK, (9.0, 7.0, 3.0), loc=(0, 1.6, Z + 16.4), chamfer=0.2, seed=11)                        # waist joint
    # --- torso (leans forward) ------------------------------------------------------------------
    with M.xf(loc=(0, 1.4, Z + 17.0), rot=(13, 0, 0)):
        M.block(BODY, (21.0, 12.5, 12.0), loc=(0, 0, 0.2), base=True, chamfer=0.2, jit=0.03, taper=1.0, seed=12)
        M.block(BODY, (13.0, 10.0, 4.0), loc=(0, 0.8, 11.6), base=True, chamfer=0.25, jit=0.03, seed=13)  # neck hump
        M.rock(LIMB, (15.0, 7.0, 9.0), loc=(0, 5.4, 6.4), base=False, seed=14)                          # back boulder
        yf = -6.3
        # chest rune plate: carved frame + glowing rune blocks
        M.box(DARK, (9.6, 0.5, 8.6), loc=(0, yf, 6.4))
        M.box(RUNE, (1.3, 0.8, 5.6), loc=(0, yf - 0.1, 6.4))
        M.box(RUNE, (1.2, 0.8, 3.4), loc=(-2.5, yf - 0.1, 7.4), rot=(0, 38, 0))
        M.box(RUNE, (1.2, 0.8, 3.4), loc=(2.5, yf - 0.1, 7.4), rot=(0, -38, 0))
        M.box(RUNE, (1.3, 0.8, 1.3), loc=(-3.0, yf - 0.1, 3.6), rot=(0, 45, 0))
        M.box(RUNE, (1.3, 0.8, 1.3), loc=(3.0, yf - 0.1, 3.6), rot=(0, 45, 0))
        # cracks on the chest
        crack(M, [(-9.6, yf + 0.12, 11.4), (-8.2, yf + 0.12, 9.2), (-8.9, yf + 0.12, 7.4), (-7.0, yf + 0.12, 5.0),
                  (-7.6, yf + 0.12, 2.6)])
        crack(M, [(9.4, yf + 0.12, 3.0), (7.6, yf + 0.12, 5.2), (8.4, yf + 0.12, 6.8), (6.4, yf + 0.12, 9.8)])
        crack(M, [(-8.2, yf + 0.12, 9.2), (-6.0, yf + 0.12, 9.8), (-5.4, yf + 0.12, 11.2)], r=0.22)
        # --- head (bowed) -------------------------------------------------------------------------
        with M.xf(loc=(0, -3.6, 13.2), rot=(16, 0, 0)):
            M.block(BODY, (8.4, 7.4, 6.6), loc=(0, 0, 0), base=True, chamfer=0.24, jit=0.03, seed=15)
            M.block(LIMB, (9.4, 2.4, 1.8), loc=(0, -3.2, 4.4), chamfer=0.25, seed=16)                    # brow
            M.block(LIMB, (5.6, 2.6, 2.6), loc=(0, -3.4, 1.0), chamfer=0.25, seed=17)                    # jaw
            for sx in (-1, 1):
                M.box(RUNE, (1.9, 0.7, 0.9), loc=(sx * 2.1, -3.75, 3.1), rot=(0, sx * 12, 0))
            M.blob(MOSS, (3.6, 3.2, 1.2), sub=1, flat=0.3, loc=(1.0, 0.6, 6.7), seed=18)
        # --- shoulders ----------------------------------------------------------------------------
        for sx in (-1, 1):
            M.rock(BODY, (9.6, 10.0, 8.6), loc=(sx * 12.6, 0.2, 9.4), base=False, npts=14, seed=20 + sx)
            M.block(DARK, (3.4, 6.0, 5.0), loc=(sx * 9.6, 0, 8.6), chamfer=0.2, seed=24)                 # joint
        M.blob(MOSS, (4.8, 4.6, 1.6), sub=1, flat=0.3, loc=(-12.6, 0.6, 13.4), seed=25)
        M.blob(MOSS, (3.6, 3.2, 1.3), sub=1, flat=0.3, loc=(13.4, 1.6, 13.2), seed=26)
        M.blob(MOSS, (6.4, 3.0, 2.2), sub=1, flat=0.3, loc=(-2.0, 6.6, 10.6), seed=27)
    # --- arms -------------------------------------------------------------------------------------
    # left arm (+X): forearm resting on the raised knee
    M.chunk(LIMB, (13.6, -3.6, Z + 24.0), (14.2, -6.6, Z + 17.0), 3.2, 3.0, n=6, seed=30)
    M.chunk(BODY, (14.0, -6.4, Z + 16.6), (8.4, -10.6, Z + 15.4), 3.5, 4.0, n=6, seed=31)
    M.block(BODY, (7.0, 6.6, 6.0), loc=(6.6, -11.6, Z + 15.6), rot=(8, 0, 30), chamfer=0.24, seed=32)   # fist
    # right arm (-X): fist planted on the ground
    M.chunk(LIMB, (-13.6, -3.4, Z + 24.0), (-14.6, -6.0, Z + 14.5), 3.2, 3.1, n=6, seed=33)
    M.chunk(BODY, (-14.6, -6.0, Z + 14.0), (-13.6, -8.4, Z + 5.4), 3.6, 4.3, n=6, seed=34)
    M.block(BODY, (7.6, 7.4, 6.4), loc=(-13.4, -8.8, Z), base=True, rot=(0, 0, -12), chamfer=0.24, seed=35)  # fist
    M.block(DARK, (8.4, 8.2, 1.4), loc=(-13.6, -7.6, Z + 6.6), rot=(0, 0, -12), chamfer=0.2, seed=36)   # wrist band
    M.block(DARK, (7.4, 7.0, 1.4), loc=(9.6, -9.6, Z + 15.4), rot=(0, 40, 30), chamfer=0.2, seed=37)
    # --- moss + cracks on the plinth, small rubble ---------------------------------------------------
    M.blob(MOSS, (3.4, 2.6, 1.0), sub=1, flat=0.3, loc=(6.2, 1.0, Z + 16.4), seed=40)
    M.blob(MOSS, (2.6, 4.2, 1.0), sub=1, flat=0.3, loc=(-6.4, 4.0, Z + 5.4), seed=41)
    M.blob(MOSS, (4.2, 3.0, 0.9), sub=1, flat=0.3, loc=(9.6, 6.0, Z + 0.3), seed=42)
    M.blob(MOSS, (3.0, 2.4, 0.8), sub=1, flat=0.3, loc=(-1.0, -8.4, Z + 0.3), seed=43)
    crack(M, [(1.5, -9.6, Z + 0.02), (0.2, -7.4, Z + 0.02), (1.8, -5.0, Z + 0.02), (0.4, -2.6, Z + 0.02)], r=0.3)
    crack(M, [(11.8, 2.0, Z + 0.02), (9.6, 3.0, Z + 0.02), (9.0, 5.4, Z + 0.02)], r=0.3)
    M.rock(LIMB, (3.2, 2.8, 2.0), loc=(11.6, -5.6, Z), seed=44)
    M.rock(BODY, (2.2, 2.0, 1.5), loc=(-3.0, -8.6, Z), seed=45)
    M.ref_pos = (19.0, -9.0)
    M.view_dir = (0.7, -1.4, 0.5)
    return M


if __name__ == "__main__":
    run(build)
