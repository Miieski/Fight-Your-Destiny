"""Hell_4_DemonThrone - giant throne on a stepped dais: black stone, horned backrest, skull armrests, glowing runes."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

DARK, TILE, BORDER, BLACK, BONE = "Hell_GroundDark", "Hell_Tile", "Hell_TileBorder", "Hell_Black", "Hell_Bone"
PURPLE, CARPET, RUNE = "Hell_Purple", "Hell_Banner", "Neon_Hell_Red"
BACK = [(-11.0, 0.0), (11.0, 0.0), (13.5, 30.0), (8.5, 38.0), (4.5, 45.0), (0.0, 53.0), (-4.5, 45.0), (-8.5, 38.0), (-13.5, 30.0)]


def skull(M, sx):
    """Stylized skull on the front of an arm rest (local frame of the throne)."""
    c = V(sx * 13.0, -9.6, 17.2)
    M.blob(BONE, (3.9, 4.1, 3.6), sub=1, jit=0.04, loc=tuple(c))
    M.box(BONE, (4.6, 3.0, 2.6), loc=(c.x, c.y - 1.6, c.z - 3.6), taper=0.85)                 # jaw
    for ex in (-1, 1):
        M.box(BLACK, (1.7, 1.0, 1.7), loc=(c.x + ex * 1.6, c.y - 3.75, c.z + 0.3), rot=(0, 45, 0))
        M.box(RUNE, (0.7, 1.2, 0.7), loc=(c.x + ex * 1.6, c.y - 3.8, c.z + 0.3))
        M.cone(BONE, 0.9, 3.4, n=4, loc=(c.x + ex * 2.6, c.y + 0.2, c.z + 2.4), rot=(0, ex * 28, 0))   # little horns
    M.box(BLACK, (1.0, 1.0, 1.2), loc=(c.x, c.y - 3.9, c.z - 1.6))
    for k in (-1, 0, 1):
        M.box(BLACK, (0.35, 0.8, 1.6), loc=(c.x + k * 1.2, c.y - 3.1, c.z - 3.9))


def build():
    M = Model("Hell_4_DemonThrone", target=(50, 40, 78), seed=531)
    # --- dais: three steps (2.2 high, 3 deep) with carved borders ---------------------------------------
    M.box(DARK, (50.0, 40.0, 2.2), base=True)
    M.box(TILE, (44.0, 34.0, 2.2), loc=(0, 0, 2.2), base=True)
    M.box(DARK, (38.0, 28.0, 2.2), loc=(0, 0, 4.4), base=True)
    Z = 6.6
    for (w, d, z) in ((50.0, 40.0, 2.2), (44.0, 34.0, 4.4), (38.0, 28.0, 6.6)):                # border inlays on the treads
        for sy in (-1, 1):
            M.box(BORDER, (w - 1.6, 0.7, 0.24), loc=(0, sy * (d / 2 - 1.0), z - 0.1), base=True)
        for sx in (-1, 1):
            M.box(BORDER, (0.7, d - 1.6, 0.24), loc=(sx * (w / 2 - 1.0), 0, z - 0.1), base=True)
    for k, x in enumerate((-18.0, -12.0, 12.0, 18.0)):                                         # runes on the risers
        M.box(RUNE, (2.6, 0.6, 1.0), loc=(x, -19.9, 1.1))
        M.box(RUNE, (1.0, 0.6, 1.2), loc=(x * 0.86, -16.9, 3.3), rot=(0, 45, 0))
        M.box(RUNE, (2.0, 0.6, 1.0), loc=(x * 0.72, -13.9, 5.5))
    M.box(CARPET, (9.0, 12.5, 0.3), loc=(0, -7.8, Z), base=True)                                 # red carpet down the steps
    M.box(CARPET, (9.0, 3.4, 0.3), loc=(0, -15.4, 4.4), base=True)
    M.box(CARPET, (9.0, 3.4, 0.3), loc=(0, -18.4, 2.2), base=True)
    M.box(CARPET, (9.0, 0.3, 2.3), loc=(0, -14.0, 4.4), base=True)
    M.box(CARPET, (9.0, 0.3, 2.3), loc=(0, -17.0, 2.2), base=True)
    # --- throne ----------------------------------------------------------------------------------------------
    with M.xf(loc=(0, 4.0, Z)):
        M.block(BLACK, (21.0, 16.0, 9.5), base=True, chamfer=0.12, jit=0.0)                     # seat
        M.box(PURPLE, (15.0, 12.0, 1.3), loc=(0, -1.4, 9.5), base=True, taper=0.92)             # cushion
        M.box(RUNE, (10.0, 0.6, 1.2), loc=(0, -8.1, 5.0))
        M.box(RUNE, (1.6, 0.6, 1.6), loc=(0, -8.1, 2.4), rot=(0, 45, 0))
        for sx in (-1, 1):
            M.block(TILE, (5.6, 17.5, 15.5), loc=(sx * 13.0, -0.6, 0), base=True, chamfer=0.14, jit=0.0)   # arm rest
            M.box(BORDER, (6.0, 13.0, 0.8), loc=(sx * 13.0, 1.6, 15.5), base=True)
            skull(M, sx)
            # horns of the backrest
            M.tube(BONE, [(sx * 11.0, 9.0, 31.0), (sx * 19.0, 9.0, 37.0), (sx * 22.6, 9.0, 51.0), (sx * 18.0, 9.0, 71.4)],
                   [4.3, 3.7, 2.4, 0.0], n=6)
            M.tube(BLACK, [(sx * 12.6, 9.0, 32.2), (sx * 14.6, 9.0, 33.7)], 4.6, n=6)             # horn socket ring
            for k, (x, z, a) in enumerate(((13.4, 20.0, 78), (14.2, 27.0, 70), (9.6, 41.0, 40), (5.6, 48.0, 28))):
                M.spike(BLACK, (sx * x, 9.0, z), 1.5, 5.5, n=4, rot=(0, sx * a, 0), waist=0.2)    # spikes on the edge
        M.extrude(BLACK, BACK, 4.4, loc=(0, 9.0, 0))                                             # backrest
        M.extrude(BORDER, [(x * 0.74, 9.0 + z * 0.7) for x, z in BACK], 0.9, loc=(0, 6.6, 0))
        M.extrude(PURPLE, [(x * 0.62, 11.5 + z * 0.6) for x, z in BACK], 1.0, loc=(0, 6.3, 0))
        for k, (z, w, h) in enumerate(((17.0, 3.4, 1.0), (20.5, 1.2, 3.6), (25.0, 4.4, 1.0), (28.5, 1.2, 3.0), (32.5, 3.0, 1.0))):
            M.box(RUNE, (w, 0.8, h), loc=(0, 5.7, z))                                            # rune column
        M.box(RUNE, (3.4, 1.0, 3.4), loc=(0, 6.1, 46.5), rot=(0, 45, 0))                         # top gem
        M.box(BLACK, (4.8, 0.8, 4.8), loc=(0, 6.5, 46.5), rot=(0, 45, 0))
    # --- skull piles at the back corners of the dais (bone accents) -----------------------------------------------
    for sx in (-1, 1):
        M.blob(BONE, (2.2, 2.3, 2.0), sub=1, jit=0.05, loc=(sx * 16.0, 11.0, Z + 1.7))
        M.blob(BONE, (1.9, 2.0, 1.7), sub=1, jit=0.05, loc=(sx * 13.2, 12.2, Z + 1.4))
        M.box(BLACK, (0.8, 0.5, 0.8), loc=(sx * 16.0 - 0.8, 8.9, Z + 1.9))
        M.box(BLACK, (0.8, 0.5, 0.8), loc=(sx * 16.0 + 0.8, 8.9, Z + 1.9))
    M.ref_pos = (29.0, -15.0)
    M.view_dir = (0.6, -1.45, 0.5)
    return M


if __name__ == "__main__":
    run(build)
