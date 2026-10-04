"""Jungle_4_GoldenIdol - giant golden gorilla idol sitting on a carved stone pedestal, arms on knees, glyph eyes."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

GOLD, GOLD_D, GLYPH = "Jungle_Gold", "Jungle_Flower2", "Neon_Jungle_Glyph"
STONE, STONE_D, MOSS = "Jungle_Stone", "Jungle_StoneDark", "Jungle_Moss"


def build():
    M = Model("Jungle_4_GoldenIdol", target=(40, 36, 50), seed=131)
    # --- pedestal -------------------------------------------------------------------------------------
    M.box(STONE_D, (40.0, 36.0, 3.0), base=True, taper=0.97)
    M.box(STONE, (36.0, 32.0, 5.2), loc=(0, 0, 3.0), base=True, taper=0.97)
    M.box(STONE_D, (38.4, 34.4, 1.9), loc=(0, 0, 8.2), base=True)
    P = 10.1
    for k, x in enumerate((-13.5, -9.0, -4.5, 4.5, 9.0, 13.5)):                       # carved glyphs, front and back
        shape = ((2.4, 3.0), (3.0, 1.8), (1.5, 3.2))[k % 3]
        for sy in (-1, 1):
            M.box(GLYPH, (shape[0], 0.8, shape[1]), loc=(x, sy * 15.85, 5.6))
    M.rings(GLYPH, [(0, 2.3), (0.5, 1.9)], n=8, loc=(0, -15.7, 5.6), rot=(90, 0, 0))
    M.rings(STONE_D, [(0, 1.2), (0.5, 0.9)], n=8, loc=(0, -16.1, 5.6), rot=(90, 0, 0))
    for k, y in enumerate((-10.0, -5.0, 0.0, 5.0, 10.0)):
        shape = ((2.4, 3.0), (3.0, 1.8), (1.5, 3.2))[k % 3]
        for sx in (-1, 1):
            M.box(GLYPH, (0.8, shape[0], shape[1]), loc=(sx * 17.8, y, 5.6))
    for (x, y, sx_, sy_) in ((-16.5, -14.5, 6, 5), (16.0, 13.5, 7, 6), (-15.5, 14.0, 5, 6)):   # moss on the corners
        M.block(MOSS, (sx_, sy_, 1.3), loc=(x, y, P + 0.2), chamfer=0.25)
        M.box(MOSS, (sx_ * 0.4, 1.0, 3.6), loc=(x, y + (-1 if y < 0 else 1) * (17.3 - abs(y)), P - 1.6), taper=(0.5, 1.0))
    # --- body ------------------------------------------------------------------------------------------
    M.blob(GOLD, (11.5, 9.2, 8.6), sub=2, jit=0.05, flat=0.75, loc=(0, 3.4, P + 6.4), seed=1)             # hips / belly
    M.blob(GOLD, (12.2, 8.8, 10.0), sub=2, jit=0.05, loc=(0, 2.2, P + 18.6), rot=(10, 0, 0), seed=2)      # chest
    for sx in (-1, 1):
        M.blob(GOLD, (5.6, 5.6, 5.2), sub=1, jit=0.06, loc=(sx * 11.6, 1.6, P + 24.0), seed=3)            # shoulders
        M.block(GOLD_D, (7.6, 2.6, 5.6), loc=(sx * 4.9, -5.5, P + 20.2), rot=(8, 0, sx * -10), chamfer=0.25, jit=0.02)  # pectorals
    M.box(GLYPH, (3.0, 1.0, 3.0), loc=(0, -5.75, P + 11.0), rot=(0, 45, 0))                               # belly glyph
    M.box(GLYPH, (1.2, 1.0, 1.2), loc=(0, -5.9, P + 14.6), rot=(0, 45, 0))
    for sx in (-1, 1):
        M.box(GLYPH, (1.2, 1.0, 1.2), loc=(sx * 3.2, -5.4, P + 11.0), rot=(0, 45, 0))
    M.rings(GOLD_D, [(0, 10.4, 7.6), (1.6, 10.9, 8.0)], n=10, loc=(0, 3.0, P + 2.2))                      # belt
    # --- head --------------------------------------------------------------------------------------------
    with M.xf(loc=(0, -3.0, P + 31.2), rot=(8, 0, 0), scale=1.18):
        M.blob(GOLD, (6.0, 6.2, 5.6), sub=2, jit=0.05, seed=4)
        M.chunk(GOLD, (0, -2.4, 4.2), (0, 3.6, 5.6), (2.6, 2.2), (2.0, 1.8), n=5, jit=0.04, seed=5)       # sagittal crest
        M.block(GOLD_D, (10.4, 2.8, 2.2), loc=(0, -5.3, 1.9), chamfer=0.25, jit=0.02)                     # brow ridge
        M.block(GOLD_D, (6.6, 4.4, 4.6), loc=(0, -5.6, -2.2), chamfer=0.25, jit=0.02)                     # muzzle
        M.box(STONE_D, (4.4, 0.6, 0.6), loc=(0, -7.7, -3.2))                                              # mouth line
        for sx in (-1, 1):
            M.box(GLYPH, (2.3, 1.0, 1.3), loc=(sx * 2.5, -5.75, 0.3), rot=(0, sx * 10, 0))                # glyph eyes
            M.box(STONE_D, (0.7, 0.6, 0.7), loc=(sx * 1.0, -7.7, -0.9))                                   # nostrils
            M.block(GOLD_D, (1.8, 2.6, 3.0), loc=(sx * 6.2, 0.4, 0.2), chamfer=0.25, jit=0.02)            # ears
    M.rings(GOLD_D, [(0, 7.2, 6.4), (1.5, 6.6, 5.8)], n=8, loc=(0, -0.6, P + 25.6), rot=(12, 0, 0))       # collar
    # --- legs: knees up and apart, feet on the pedestal ------------------------------------------------------
    for sx in (-1, 1):
        hip, knee, ankle = V(sx * 6.8, 0.5, P + 5.2), V(sx * 12.6, -9.6, P + 10.6), V(sx * 11.4, -13.2, P + 2.6)
        M.chunk(GOLD, hip, knee, 5.2, 4.2, n=6, jit=0.05, seed=10)
        M.chunk(GOLD, knee, ankle, 3.9, 3.3, n=6, jit=0.05, seed=11)
        M.block(GOLD, (6.2, 7.0, 3.0), loc=(sx * 11.4, -14.2, P), base=True, chamfer=0.25, jit=0.02)      # foot
        M.rings(GOLD_D, [(0, 3.9), (1.5, 3.9)], n=8, loc=(sx * 11.5, -13.0, P + 2.6))                      # anklet
        # arms: shoulder -> elbow (out and down) -> wrist resting on the knee, hand hanging over it
        sh, el, wr = V(sx * 12.6, 0.6, P + 23.0), V(sx * 15.6, -3.4, P + 14.6), V(sx * 13.2, -10.6, P + 14.2)
        M.chunk(GOLD, sh, el, 4.2, 3.8, n=6, jit=0.05, seed=12)
        M.chunk(GOLD, el, wr, 4.0, 4.3, n=6, jit=0.05, seed=13)
        M.chunk(GOLD_D, wr.lerp(el, 0.34), wr.lerp(el, 0.12), 4.9, 4.9, n=6, jit=0.02, bulge=0.0, seed=14)   # bracelet
        M.block(GOLD, (5.6, 5.0, 5.0), loc=(sx * 12.8, -13.6, P + 12.2), rot=(20, 0, 0), chamfer=0.25, jit=0.02)   # hand
    M.blob(MOSS, (3.4, 3.0, 1.0), sub=1, flat=0.3, loc=(-11.6, 2.2, P + 28.8), seed=20)
    M.blob(MOSS, (2.6, 2.4, 0.9), sub=1, flat=0.3, loc=(11.2, 3.0, P + 28.6), seed=21)
    M.ref_pos = (24.0, -15.0)
    M.view_dir = (0.6, -1.45, 0.5)
    return M


if __name__ == "__main__":
    run(build)
