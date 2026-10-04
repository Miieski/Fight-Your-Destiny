"""Desert_4_Sarcophagus - giant golden pharaoh sarcophagus on a stepped plinth, lid ajar (feet toward the front)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

GOLD, LAPIS, TURQ = "Desert_Gold", "Desert_Lapis", "Desert_Turquoise"
STONE, STONE_D, DARK = "Desert_Sandstone", "Desert_SandstoneDark", "Desert_PyramidDark"

# half outline of the coffin (y from the feet to the head, half width)
HALF = [(-15.0, 3.7), (-13.0, 4.0), (-5.0, 5.0), (2.0, 6.0), (7.0, 7.4), (11.0, 7.4), (13.2, 5.6), (15.4, 3.8)]


def outline(sx=1.0, sy=1.0):
    right = [(w * sx, y * sy) for y, w in HALF]
    left = [(-w * sx, y * sy) for y, w in reversed(HALF)]
    return right + left


def width_at(y):
    for (y0, w0), (y1, w1) in zip(HALF[:-1], HALF[1:]):
        if y0 <= y <= y1:
            return lerp(w0, w1, (y - y0) / (y1 - y0))
    return HALF[-1][1]


def build():
    M = Model("Desert_4_Sarcophagus", target=(26, 40, 22), seed=91)
    # --- stepped plinth (steps 2.3 high, 1.8 deep) -----------------------------------------------
    M.box(STONE_D, (26.0, 40.0, 2.3), loc=(0, 0, 0), base=True, taper=0.985)
    M.box(STONE, (22.4, 36.4, 2.3), loc=(0, 0, 2.3), base=True, taper=0.985)
    M.box(STONE_D, (18.8, 32.8, 2.3), loc=(0, 0, 4.6), base=True, taper=0.985)
    Z = 6.9
    # hieroglyph inlays on the middle step + a turquoise scarab on the front
    for sx in (-1, 1):
        for k in range(7):
            y = -13.5 + k * 4.5
            col = LAPIS if k % 2 == 0 else TURQ
            M.box(col, (0.4, 1.6, 1.1 if k % 3 else 0.6), loc=(sx * 11.15, y, 3.5))
    for k, x in enumerate((-8.0, -5.0, 5.0, 8.0)):
        M.box(LAPIS if k % 2 else TURQ, (1.6, 0.4, 1.1), loc=(x, -18.15, 3.5))
    M.rings(TURQ, [(0, 1.5, 1.1), (0.5, 1.2, 0.85)], n=6, loc=(0, -18.1, 3.5), rot=(90, 0, 0))
    M.box(GOLD, (5.6, 0.35, 0.5), loc=(0, -18.2, 3.5))
    # --- coffin base ---------------------------------------------------------------------------------
    M.extrude(GOLD, outline(), 6.0, axis="Z", loc=(0, 0, Z))
    M.extrude(LAPIS, outline(1.04, 1.015), 0.9, axis="Z", loc=(0, 0, Z + 0.7))
    M.extrude(TURQ, outline(1.04, 1.015), 0.5, axis="Z", loc=(0, 0, Z + 2.5))
    M.extrude(LAPIS, outline(1.04, 1.015), 0.9, axis="Z", loc=(0, 0, Z + 4.4))
    M.extrude(DARK, outline(0.93, 0.965), 0.35, axis="Z", loc=(0, 0, Z + 5.8))        # dark inside, seen through the gap
    # --- lid, slid sideways and turned a little ---------------------------------------------------------
    with M.xf(loc=(3.3, 0.3, Z + 6.5), rot=(0, 0, 9.0)):
        M.extrude(GOLD, outline(1.02, 1.01), 2.0, axis="Z")
        M.extrude(LAPIS, outline(1.05, 1.02), 0.6, axis="Z", loc=(0, 0, 0.5))
        T = 2.0
        # body relief
        M.chunk(GOLD, (0, -12.4, T + 0.2), (0, -2.5, T + 0.5), (3.3, 2.2), (4.6, 2.9), n=8, jit=0.0, bulge=0.2, up=(0, 0, 1), seed=1)
        M.chunk(GOLD, (0, -2.5, T + 0.5), (0, 8.6, T + 0.7), (4.8, 3.0), (6.4, 3.3), n=8, jit=0.0, bulge=0.15, up=(0, 0, 1), seed=2)
        M.block(GOLD, (6.4, 2.4, 4.6), loc=(0, -13.4, T), base=True, chamfer=0.2, jit=0.0)                  # feet
        # lapis / turquoise bands over the legs
        for k, y in enumerate((-10.6, -8.0, -5.4, -2.8, -0.2)):
            w = width_at(y) * 0.93
            M.box(LAPIS if k % 2 == 0 else TURQ, (w * 2, 1.2, 2.7 + 0.12 * k), loc=(0, y, T), base=True, taper=(0.72, 1.0))
        # crossed arms + crook and flail
        for sx in (-1, 1):
            M.chunk(GOLD, (sx * 5.6, 5.6, T + 2.6), (-sx * 2.4, 3.2, T + 3.7), 1.25, 1.15, n=5, jit=0.0, bulge=0.3, seed=3)
            M.block(GOLD, (2.2, 2.0, 1.8), loc=(-sx * 2.9, 3.0, T + 4.0), chamfer=0.2, jit=0.0)             # fist
            M.tube(LAPIS if sx > 0 else TURQ, [(-sx * 2.9, 3.0, T + 4.7), (-sx * 5.0, 7.8, T + 4.4)], 0.42, n=4)
        M.tube(LAPIS, [(-5.0, 7.8, T + 4.4), (-5.6, 8.9, T + 4.4), (-4.6, 9.6, T + 4.4)], 0.42, n=4)        # crook hook
        # broad collar
        M.rings(TURQ, [(0, 6.6, 3.4), (0.7, 6.2, 3.1)], n=10, loc=(0, 7.6, T + 3.2), rot=(-6, 0, 0))
        M.rings(LAPIS, [(0, 5.0, 2.5), (0.6, 4.6, 2.2)], n=10, loc=(0, 8.2, T + 3.8), rot=(-6, 0, 0))
        # head: nemes headdress with stripes, face, beard, uraeus
        M.block(GOLD, (11.0, 6.6, 5.4), loc=(0, 12.2, T), base=True, chamfer=0.22, jit=0.0, taper=0.8)      # nemes
        for sx in (-1, 1):
            M.box(GOLD, (2.9, 5.6, 3.6), loc=(sx * 4.0, 7.6, T), base=True, taper=(0.85, 0.9))              # lappets
            for k in range(3):
                M.box(LAPIS, (3.1, 0.8, 3.75 - 0.1 * k), loc=(sx * 4.0, 5.8 + 1.7 * k, T), base=True, taper=(0.85, 1.0))
            for k in range(3):
                M.box(LAPIS, (0.8, 6.3, 5.1 - 0.9 * k), loc=(sx * (2.9 + 1.25 * k), 12.3, T + 0.3), base=True,
                      taper=(1.0, 0.85))
        M.block(GOLD, (5.6, 5.8, 2.6), loc=(0, 11.8, T + 4.6), base=True, chamfer=0.25, jit=0.0)            # face
        M.wedge(GOLD, (1.2, 2.4, 1.1), loc=(0, 11.2, T + 7.15), rot=(0, 0, 0))                              # nose
        for sx in (-1, 1):
            M.box(LAPIS, (1.9, 0.9, 0.5), loc=(sx * 1.6, 12.6, T + 7.2), rot=(0, 0, sx * 8))             # eyes
            M.box(TURQ, (2.1, 0.35, 0.4), loc=(sx * 1.6, 13.5, T + 7.2), rot=(0, 0, sx * 8))               # brows
        M.box(LAPIS, (1.2, 3.0, 1.2), loc=(0, 7.9, T + 5.9), rot=(-22, 0, 0))                               # beard
        M.box(TURQ, (1.2, 1.2, 2.6), loc=(0, 15.0, T + 5.2), base=True, taper=0.6)                          # uraeus
    # --- four small corner obelisks on the plinth ---------------------------------------------------------
    for sx in (-1, 1):
        for sy in (-1, 1):
            with M.xf(loc=(sx * 11.3, sy * 18.3, 0)):
                M.box(STONE, (3.0, 3.0, 5.4), base=True, taper=0.86)
                M.box(LAPIS, (2.75, 2.75, 0.5), loc=(0, 0, 5.4), base=True)
                M.rings(GOLD, [(5.9, 1.85), (8.2, 0)], n=4)
    M.ref_pos = (17.0, -12.0)
    M.view_dir = (0.75, -1.25, 0.95)
    return M


if __name__ == "__main__":
    run(build)
