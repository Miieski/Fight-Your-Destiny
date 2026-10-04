"""Desert_2_OasisWell - stone well with a wooden roof frame and bucket, next to a ruined round fountain."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

STONE, STONE_D, WATER, SAND = "Desert_Sandstone", "Desert_SandstoneDark", "Desert_Water", "Desert_Sand"
WOOD, ROOF, ROPE, IRON = "Common_Wood", "Desert_Terracotta", "Common_Rope", "Common_Iron"


def build():
    M = Model("Desert_2_OasisWell", target=(40, 30, 22), seed=71)
    # ============================ WELL (left) ==================================================
    with M.xf(loc=(-11.5, 1.5, 0)):
        M.rings(STONE_D, [(0, 8.4), (0.6, 8.0)], n=10, jit=0.05, seed=1)                  # paving
        M.ring_wall(STONE, 3.7, 5.5, 0.6, 4.6, n=10, gap=1.6, jit=0.25, seed=2)           # wall blocks
        M.ring_wall(STONE_D, 3.4, 5.9, 4.6, 5.4, n=10, gap=0.8, phase=18, seed=3)         # rim
        M.cyl(WATER, 3.9, 2.6, n=10, loc=(0, 0, 0.5))                                     # water
        for sx in (-1, 1):
            M.box(WOOD, (1.1, 1.1, 15.2), loc=(sx * 5.0, 0, 0.6), base=True)              # posts
            M.tube(WOOD, [(sx * 5.0, 0, 11.6), (sx * 2.2, 0, 15.2)], 0.4, n=4)            # braces
            M.box(STONE_D, (2.2, 2.2, 1.2), loc=(sx * 5.0, 0, 0.6), base=True)
        M.tube(WOOD, [(-5.9, 0, 10.4), (5.9, 0, 10.4)], 0.75, n=6)                        # windlass
        M.tube(IRON, [(5.9, 0, 10.4), (7.0, 0, 10.4), (7.0, 0, 8.8), (8.2, 0, 8.8)], 0.26, n=4)   # crank
        M.rings(ROPE, [(0, 1.05), (2.6, 1.05)], n=6, loc=(-1.3, 0, 10.4), rot=(0, 90, 0))  # rope coil
        M.tube(ROPE, [(0.4, -0.9, 10.2), (0.6, -1.0, 4.4)], 0.2, n=4)
        # roof: beams + terracotta gable
        M.box(WOOD, (12.6, 0.9, 0.9), loc=(0, 0, 15.6))
        for sy in (-1, 1):
            M.box(WOOD, (13.4, 0.8, 0.7), loc=(0, sy * 4.4, 15.5))
        for sx in (-1, 1):
            M.box(WOOD, (0.8, 9.4, 0.7), loc=(sx * 5.0, 0, 15.6))
        M.extrude(ROOF, [(-5.6, 15.9), (5.6, 15.9), (0.5, 20.6), (-0.5, 20.6)], 14.2, axis="X")
        M.box(WOOD, (14.8, 1.0, 0.8), loc=(0, 0, 20.8))                                   # ridge beam
        # bucket + rope on the ground beside the well
        with M.xf(loc=(6.4, -6.2, 0.6), rot=(0, 0, 25)):
            M.rings(WOOD, [(0, 1.25), (2.6, 1.6)], n=8)
            M.rings(IRON, [(0.5, 1.4), (0.95, 1.46)], n=8)
            M.rings(IRON, [(1.9, 1.57), (2.3, 1.63)], n=8)
            M.rings(WATER, [(2.2, 1.3), (2.45, 1.35)], n=8)
            M.tube(IRON, [(-1.5, 0, 2.5), (-1.1, 0, 4.0), (1.1, 0, 4.0), (1.5, 0, 2.5)], 0.16, n=4)
            M.tube(ROPE, [(0, 0, 4.0), (-1.6, 0.6, 2.0), (-3.0, 1.6, 0.25), (-4.4, 3.2, 0.25)], 0.22, n=4)
    # ============================ RUINED FOUNTAIN (right) =======================================
    with M.xf(loc=(8.6, -0.6, 0)):
        M.rings(STONE_D, [(0, 10.6), (0.6, 10.2)], n=14, jit=0.04, seed=4)                # floor
        hs = [3.4, 3.4, 1.6, 0, 0, 2.2, 3.4, 3.4, 3.4, 2.6, 0, 1.4, 3.4, 3.4]
        M.ring_wall(STONE, 8.3, 9.9, 0.6, 3.4, n=14, gap=1.2, skip={3, 4, 10}, heights=hs, jit=0.15, seed=5)
        M.ring_wall(STONE_D, 8.0, 10.3, 3.4, 4.2, n=14, gap=0.6, skip={2, 3, 4, 5, 9, 10, 11}, seed=6)
        # central pedestal with a cracked upper bowl and a snapped spout
        M.rings(STONE, [(0.6, 2.9), (1.8, 2.4), (2.2, 1.7), (6.8, 1.4), (7.4, 2.2)], n=8)
        M.rings(STONE_D, [(7.4, 1.8), (8.8, 4.6), (9.0, 4.2), (8.3, 3.2)], n=8)
        M.ring_wall(STONE, 3.9, 5.0, 8.7, 9.6, n=8, skip={5, 6, 7}, gap=1.5, seed=7)
        M.rings(STONE, [(8.3, 1.1), (10.8, 0.9), (12.2, 0, 0, 0.4, 0.2)], n=6)
        # the last puddle + sand drifts inside the basin
        M.rings(WATER, [(0.6, 4.6, 3.6, -3.0, 2.6), (0.82, 4.4, 3.4, -3.0, 2.6)], n=9, jit=0.1, seed=8)
        M.blob(SAND, (5.4, 4.0, 2.2), sub=2, jit=0.06, flat=0.1, loc=(4.0, -4.4, 0.7), seed=9)
        M.blob(SAND, (4.2, 5.0, 1.6), sub=2, jit=0.06, flat=0.1, loc=(4.6, 5.0, 0.7), seed=10)
        # rubble from the broken wall
        M.block(STONE, (2.6, 1.8, 1.5), loc=(6.6, -9.4, 0.75), rot=(0, 12, 38), seed=11)
        M.block(STONE, (2.0, 1.6, 1.3), loc=(3.4, -11.6, 0.65), rot=(8, 0, 70), seed=12)
        M.block(STONE_D, (2.2, 1.5, 0.8), loc=(-7.6, 8.8, 0.4), rot=(0, 0, 15), seed=13)
        M.block(STONE, (1.8, 1.6, 1.2), loc=(-9.2, 7.0, 1.0), rot=(20, 10, 50), seed=14)
    # fallen column: three drums + capital lying toward the front right
    p0, d = V(11.5, -9.6, 1.55), V(0.83, -0.42, 0).normalized()
    side = V(-d.y, d.x, 0)
    pos = 0.0
    for k, (L, off, tilt) in enumerate(((5.0, 0.0, 0.0), (3.4, 0.5, 0.05))):
        a = p0 + d * pos + side * off
        b = a + d * L + V(0, 0, tilt * L)
        M.tube(STONE, [a, b], 1.55, n=8)
        M.tube(STONE_D, [a + d * 0.2, a + d * 0.7], 1.72, n=8)
        pos += L + 0.5
    M.block(STONE_D, (2.4, 3.8, 3.8), loc=(1.2, -6.2, 1.2), rot=(0, 0, -27), chamfer=0.15, seed=15)   # capital
    M.rings(STONE_D, [(0, 2.3), (1.5, 2.0)], n=8, loc=(9.8, -8.6, 0.0))                               # column base
    M.blob(SAND, (4.0, 2.4, 1.3), sub=2, jit=0.06, flat=0.1, loc=(14.5, -12.6, 0.1), seed=16)
    M.blob(SAND, (4.4, 3.0, 1.4), sub=2, jit=0.06, flat=0.1, loc=(-3.6, 10.2, 0.1), seed=17)
    M.ref_pos = (-1.5, -12.0)
    M.view_dir = (0.5, -1.4, 0.75)
    return M


if __name__ == "__main__":
    run(build)
