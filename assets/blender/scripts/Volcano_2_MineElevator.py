"""Volcano_2_MineElevator - iron-and-timber headframe with a big wheel, cage and chains, beside a stone furnace."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

WOOD, IRON, BASALT, LIGHT, DARK = "Volcano_Wood", "Volcano_Iron", "Volcano_Basalt", "Volcano_BasaltLight", "Volcano_BasaltDark"
LAVA, ASH, EMBER = "Neon_Volcano_Lava", "Volcano_Ash", "Neon_Volcano_Ember"
HX = -15.0            # headframe centre
FX = 15.5             # furnace centre
TOPZ = 70.0


def leg(sx, sy, z):
    t = z / TOPZ
    return V(HX + sx * lerp(11.0, 6.5, t), sy * lerp(11.0, 6.5, t), z)


def build():
    M = Model("Volcano_2_MineElevator", target=(60, 44, 90), seed=411)
    # ================================ HEADFRAME ===================================================
    levels = [0.0, 18.0, 36.0, 54.0, TOPZ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.tube(WOOD, [leg(sx, sy, 0), leg(sx, sy, TOPZ)], 1.5, n=4)
            M.box(LIGHT, (4.4, 4.4, 1.6), loc=tuple(leg(sx, sy, 0)), base=True)                       # footings
    sides = [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]
    for (a, b) in sides:
        for li, z in enumerate(levels[1:]):
            M.tube(WOOD, [leg(a[0], a[1], z), leg(b[0], b[1], z)], 1.0, n=4)
        for li in range(1, 4):                                                                        # iron cross braces
            z0, z1 = levels[li], levels[li + 1]
            M.tube(IRON, [leg(a[0], a[1], z0), leg(b[0], b[1], z1)], 0.45, n=4)
            M.tube(IRON, [leg(b[0], b[1], z0), leg(a[0], a[1], z1)], 0.45, n=4)
    for sy in (-1, 1):                                                                                # back stays
        M.tube(WOOD, [V(HX - 14.5, sy * 9.0, 0), leg(-1, sy, 58.0)], 1.3, n=4)
        M.box(LIGHT, (4.4, 4.4, 1.6), loc=(HX - 14.5, sy * 9.0, 0), base=True)
    M.box(WOOD, (15.5, 15.5, 1.3), loc=(HX, 0, TOPZ), base=True)                                      # top deck
    # winding wheel (axis along Y) on two A-frames
    wz = TOPZ + 10.4
    for sy in (-1, 1):
        for sx in (-1, 1):
            M.tube(WOOD, [(HX + sx * 6.0, sy * 3.2, TOPZ + 1.0), (HX, sy * 3.2, wz)], 0.8, n=4)
    M.tube(IRON, [(HX, -4.6, wz), (HX, 4.6, wz)], 0.9, n=6)                                           # axle
    with M.xf(loc=(HX, 0, wz), rot=(90, 0, 0)):
        ring = [polar(8.4, 30.0 * i) for i in range(12)]
        for dz in (-0.9, 0.9):
            M.tube(IRON, [p + V(0, 0, dz) for p in ring], 0.55, n=4, closed=True, up=(0, 0, 1))
        M.tube(IRON, [p * 0.93 for p in ring], 0.75, n=4, closed=True, up=(0, 0, 1))                  # groove
        for i in range(6):
            M.box(IRON, (16.4, 0.7, 1.4), rot=(0, 0, 30.0 * i))
        M.rings(IRON, [(-1.4, 1.9), (1.4, 1.9)], n=8)
    # cage hanging in the shaft + chains
    cz = 9.0
    M.box(WOOD, (9.4, 9.4, 0.9), loc=(HX, 0, cz), base=True)
    M.box(IRON, (10.0, 10.0, 0.9), loc=(HX, 0, cz + 9.6), base=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.box(IRON, (0.7, 0.7, 9.0), loc=(HX + sx * 4.3, sy * 4.3, cz + 0.8), base=True)
        M.box(IRON, (0.5, 9.0, 0.5), loc=(HX + sx * 4.3, 0, cz + 4.2))                                # mid rail
    M.box(IRON, (9.0, 0.5, 0.5), loc=(HX, 4.3, cz + 4.2))
    for dx in (-0.8, 0.8):
        M.tube(IRON, [(HX + dx, 0, cz + 10.4), (HX + dx, 0, wz - 8.4)], 0.32, n=4)                    # chains
    M.tube(IRON, [(HX + 8.3, 0, wz + 1.0), (HX + 24.0, 0.5, 31.0)], 0.32, n=4)                        # hoist rope to the winch
    # shaft collar and dark pit
    M.ring_wall(LIGHT, 7.6, 10.2, 0.0, 2.6, n=10, gap=1.5, jit=0.3, seed=2, loc=(HX, 0, 0))
    M.cyl(DARK, 7.8, 0.4, n=10, loc=(HX, 0, 0))
    # ================================ FURNACE =====================================================
    with M.xf(loc=(FX, 2.5, 0)):
        M.block(BASALT, (27.0, 27.0, 20.0), base=True, chamfer=0.1, jit=0.02, taper=0.94, seed=3)
        M.block(LIGHT, (28.5, 28.5, 3.0), loc=(0, 0, 0), base=True, chamfer=0.2, jit=0.01, seed=4)   # plinth course
        M.block(LIGHT, (23.0, 23.0, 9.0), loc=(0, 0, 19.0), base=True, chamfer=0.12, jit=0.02, taper=0.82, seed=5)
        M.block(DARK, (25.5, 25.5, 2.2), loc=(0, 0, 18.4), base=True, chamfer=0.25, jit=0.01, seed=6)   # band
        # glowing mouth with an arched frame
        yf = -13.2
        mouth = [(-5.5, 2.5), (5.5, 2.5), (5.5, 8.0), (3.9, 11.4), (0, 12.8), (-3.9, 11.4), (-5.5, 8.0)]
        M.extrude(DARK, [(x * 1.42, 1.5 + (z - 2.5) * 1.3) for x, z in mouth], 2.6, loc=(0, yf, 0))
        M.extrude(LAVA, mouth, 3.0, loc=(0, yf - 0.1, 0))
        M.extrude(EMBER, [(x * 0.5, 2.5 + (z - 2.5) * 0.5) for x, z in mouth], 3.2, loc=(0, yf - 0.15, 0))
        for k in (-1, 0, 1):
            M.box(IRON, (0.7, 3.6, 10.5), loc=(k * 3.2, yf - 0.4, 2.5), base=True)                    # grate bars
        M.box(DARK, (9.0, 9.0, 1.8), loc=(0, yf - 5.0, 0), base=True)                                 # tapping trough
        M.box(LAVA, (5.0, 8.4, 0.5), loc=(0, yf - 5.0, 1.7), base=True)
        for sx in (-1, 1):                                                                            # small side vents
            M.box(EMBER, (0.6, 3.0, 2.0), loc=(sx * 13.0, -3.0, 11.0))
            M.box(EMBER, (0.6, 3.0, 2.0), loc=(sx * 13.0, 4.0, 11.0))
        # chimney with iron bands and a sooty top
        M.rings(BASALT, [(27.0, 6.6), (58.0, 4.8)], n=4, loc=(2.5, 4.0, 0), jit=0.02)
        for z in (34.0, 44.0, 54.0):
            r = lerp(6.6, 4.8, (z - 27.0) / 31.0) + 0.3
            M.rings(IRON, [(z, r), (z + 1.4, r - 0.08)], n=4, loc=(2.5, 4.0, 0))
        M.rings(ASH, [(57.0, 5.6), (60.0, 6.0), (61.5, 5.0)], n=4, loc=(2.5, 4.0, 0))
        M.rings(EMBER, [(61.0, 3.2), (61.9, 2.6)], n=4, loc=(2.5, 4.0, 0))
        # winch drum on the roof (takes the hoist rope) and a coal heap
        M.tube(WOOD, [(-9.0, -3.5, 29.4), (-9.0, 4.5, 29.4)], 2.2, n=7)
        for sy in (-3.9, 4.9):
            M.box(IRON, (5.4, 0.7, 5.4), loc=(-9.0, sy, 30.0))
        M.rock(DARK, (9.0, 8.0, 5.0), loc=(10.5, -17.0, 0), npts=14, seed=7)
        M.rock(DARK, (6.0, 5.0, 3.4), loc=(4.6, -19.5, 0), npts=12, seed=8)
    # iron pipe from the furnace to the shaft
    M.tube(IRON, [(FX - 13.0, 8.0, 12.0), (FX - 18.5, 8.0, 12.0), (FX - 18.5, 8.0, 2.0)], 1.3, n=6)
    M.anchors["WheelCentre"] = (HX, 0, wz)
    M.notes = "Wheel (iron) spins about the Blender Y axis through the WheelCentre anchor; it is part of the Volcano_Iron object."
    M.ref_pos = (0.0, -17.0)
    M.view_dir = (0.6, -1.45, 0.45)
    return M


if __name__ == "__main__":
    run(build)
