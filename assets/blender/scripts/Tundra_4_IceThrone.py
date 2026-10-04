"""Tundra_4_IceThrone - giant throne of ice on a stepped dais, crystal spikes fanning out behind, blue-flame accents."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

ICE, ICE_D, DARK, FROST = "Tundra_Ice", "Tundra_IceDeep", "Tundra_IceDark", "Tundra_Frost"
SNOW, PURPLE, GLOW = "Tundra_Snow", "Tundra_PalePurple", "Neon_Tundra_BlueFlame"


def build():
    M = Model("Tundra_4_IceThrone", target=(36, 30, 48), seed=231)
    # --- dais: three steps (1.6 high, 2.5 deep) -----------------------------------------------------
    M.box(ICE_D, (36.0, 30.0, 1.6), base=True, taper=0.985)
    M.box(FROST, (31.0, 25.0, 1.6), loc=(0, 0.5, 1.6), base=True, taper=0.985)
    M.box(ICE_D, (26.0, 20.0, 1.6), loc=(0, 1.0, 3.2), base=True, taper=0.985)
    Z = 4.8
    for k, x in enumerate((-10.5, -6.5, 6.5, 10.5)):                                   # glowing runes on the risers
        M.box(GLOW, (2.2, 0.5, 0.8), loc=(x, -14.85, 0.8))
        M.box(GLOW, (1.6, 0.5, 0.8), loc=(x * 0.82, -11.85, 2.4))
    M.box(GLOW, (5.0, 0.5, 0.7), loc=(0, -8.85, 4.0))
    M.box(PURPLE, (6.0, 9.6, 0.25), loc=(0, -4.6, Z), base=True)                         # carpet strip
    M.box(PURPLE, (6.0, 2.6, 0.25), loc=(0, -10.6, 3.2), base=True)
    M.box(PURPLE, (6.0, 2.6, 0.25), loc=(0, -13.1, 1.6), base=True)
    # --- throne ------------------------------------------------------------------------------------------
    with M.xf(loc=(0, 3.4, Z)):
        M.block(ICE, (15.5, 11.0, 6.4), base=True, chamfer=0.14, jit=0.0)                # seat
        M.box(PURPLE, (10.4, 8.4, 0.9), loc=(0, -0.9, 6.4), base=True, taper=0.92)       # cushion
        for sx in (-1, 1):
            M.block(ICE_D, (3.6, 11.6, 11.0), loc=(sx * 7.9, -0.3, 0), base=True, chamfer=0.2, jit=0.0)    # arm rests
            M.spike(ICE, (sx * 7.9, -5.0, 10.4), 1.5, 5.5, n=4)
            M.spike(GLOW, (sx * 7.9, -2.2, 10.6), 0.9, 2.6, n=4)
            M.spike(FROST, (sx * 7.9, 3.2, 10.4), 1.7, 8.0, n=4)
        back = [(-7.6, 0), (7.6, 0), (8.8, 17), (5.2, 22), (2.6, 26), (0, 31), (-2.6, 26), (-5.2, 22), (-8.8, 17)]
        M.extrude(ICE, back, 3.2, loc=(0, 6.6, 0))
        M.extrude(DARK, [(x * 0.68, 7.5 + z * 0.62) for x, z in back], 0.8, loc=(0, 4.8, 0))               # inlay panel
        M.rings(GLOW, [(0, 0), (0.7, 1.9), (1.0, 0)], n=6, loc=(0, 4.6, 19.0), rot=(90, 0, 0))             # gem
        M.box(GLOW, (0.7, 0.5, 5.0), loc=(0, 4.45, 12.6))
        # --- crystal spikes fanning out behind the backrest (two rows) ------------------------------------
        fan = [(-66, 19, 2.5, FROST), (-44, 26, 3.0, ICE_D), (-22, 33, 3.4, ICE), (0, 38.2, 3.8, ICE_D), (22, 33, 3.4, ICE),
               (44, 26, 3.0, ICE_D), (66, 19, 2.5, FROST)]
        for ang, L, r, col in fan:
            M.spike(col, (0, 9.6, 3.6), r, L, n=5, rot=(0, ang, 0), waist=0.35)
        for ang, L, r, col in ((-55, 18, 2.2, DARK), (-33, 25, 2.6, DARK), (-11, 30, 2.8, FROST), (11, 30, 2.8, FROST),
                               (33, 25, 2.6, DARK), (55, 18, 2.2, DARK)):
            M.spike(col, (0, 12.0, 2.6), r, L, n=5, rot=(-6, ang, 0), waist=0.35)
    # --- brazier pillars at the front corners with blue flames, snow in the corners -------------------------
    for sx in (-1, 1):
        with M.xf(loc=(sx * 15.0, -12.0, 1.6)):
            M.rings(ICE, [(0, 1.9), (1.0, 1.4), (6.0, 1.1), (6.8, 2.0), (7.4, 2.0)], n=6)
            M.rings(GLOW, [(7.2, 1.5), (9.0, 1.0, 1.0, 0.2, 0), (11.6, 0, 0, -0.2, 0.2)], n=5)
        M.blob(SNOW, (3.4, 2.8, 1.2), sub=1, jit=0.1, flat=0.2, loc=(sx * 15.6, 12.4, 1.7))
        M.blob(SNOW, (2.6, 2.2, 1.0), sub=1, jit=0.1, flat=0.2, loc=(sx * 11.4, 9.6, Z + 0.1))
    M.ref_pos = (21.0, -11.0)
    M.view_dir = (0.6, -1.45, 0.55)
    return M


if __name__ == "__main__":
    run(build)
