"""Tundra_2_FrozenShip - wooden ship locked in the ice at an angle: cracked ice slabs, snow on deck, icicles."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *
import Plains_2_PirateShip as ps          # hull shape helpers (ring, side_pt, beam, G, castle_top)

HULL, DARK = "Tundra_Wood", "Tundra_Trunk"
SNOW, SHADE, ICE, ICE_D, FROST = "Tundra_Snow", "Tundra_SnowShade", "Tundra_Ice", "Tundra_IceDeep", "Tundra_Frost"
IRON = "Common_Iron"


def build():
    M = Model("Tundra_2_FrozenShip", target=(110, 40, 60), seed=211)
    M.clip_z = 0.0
    rng = random.Random(3)
    beam, G, top = ps.beam, ps.G, ps.castle_top
    xs = [-50, -45, -40, -35, -30, -24, -18, -12, -6, 0, 6, 12, 18, 24, 30, 35, 40, 44, 47, 50]
    pose = TRS(loc=(0, 0, -6.0), rot=(11, -11, 0))             # heeled toward the front, bow lifted by the ice
    with M.xf(m=pose):
        M.loft(HULL, [ps.ring(x) for x in xs])
        for s in (-1, 1):
            M.loft(DARK, [[ps.side_pt(x, 0.70, s, 0.45), ps.side_pt(x, 1.0, s, 0.45),
                           ps.side_pt(x, 1.0, s, -0.6), ps.side_pt(x, 0.70, s, -0.6)] for x in xs])
            st = [x for x in xs if -24 <= x <= 30]
            M.loft(HULL, [[(x, s * beam(x), G(x) - 0.3), (x, s * (beam(x) - 0.9), G(x) - 0.3),
                           (x, s * (beam(x) - 0.9), G(x) + 2.7), (x, s * beam(x), G(x) + 2.7)] for x in st])
            M.tube(SNOW, [(x, s * (beam(x) - 0.45), G(x) + 2.9) for x in st], 0.75, n=4)          # snow on the rail
            for x in st[1::2]:
                M.icicle(ICE, (x + 1.5, s * (beam(x) + 0.1), G(x) + 2.2), 0.55, rng.uniform(2.5, 5.0), n=4)
        M.tube(DARK, [(50.3, 0, 7.5), (51.6, 0, 13), (52.4, 0, 19), (52.6, 0, 24)], [0.9, 0.9, 0.8, 0.7], n=4)
        # snow-covered main deck
        M.loft(SNOW, [[(x, -beam(x) + 1.0, G(x) - 0.3), (x, beam(x) - 1.0, G(x) - 0.3),
                       (x, beam(x) - 1.0, G(x) + 0.9), (x, -beam(x) + 1.0, G(x) + 0.9)] for x in xs if -25 <= x <= 31])
        for (x, y, rx, ry) in ((-16, 7, 7, 4), (6, -7, 8, 4), (20, 6, 6, 4)):
            M.blob(SHADE, (rx, ry, 2.2), sub=1, jit=0.1, flat=0.1, loc=(x, y, G(x) + 0.9))        # drifts
        # castles with snow tops
        for x0, x1 in ((-50, -24), (30, 47)):
            st = [x for x in xs if x0 <= x <= x1]
            M.loft(HULL, [[(x, -beam(x), G(x) - 0.6), (x, beam(x), G(x) - 0.6),
                           (x, beam(x) * 0.96, top(x)), (x, -beam(x) * 0.96, top(x))] for x in st])
            M.loft(SNOW, [[(x, -beam(x) * 0.96 + 0.5, top(x) - 0.2), (x, beam(x) * 0.96 - 0.5, top(x) - 0.2),
                           (x, beam(x) * 0.96 - 0.5, top(x) + 1.0), (x, -beam(x) * 0.96 + 0.5, top(x) + 1.0)] for x in st])
            for s in (-1, 1):
                M.tube(DARK, [(x, s * beam(x) * 0.97, top(x) + 0.1) for x in st], 0.55, n=4)
                M.tube(DARK, [(x, s * (beam(x) * 0.96 - 0.3), top(x) + 3.2) for x in st], 0.4, n=4)
                for x in st:
                    M.box(DARK, (0.6, 0.6, 3.0), loc=(x, s * (beam(x) * 0.96 - 0.3), top(x)), base=True)
                    M.icicle(ICE, (x + 2.0, s * (beam(x) * 0.96 - 0.3), top(x) + 3.0), 0.4, rng.uniform(1.4, 2.6), n=4)
        M.box(DARK, (0.8, 4.6, 6.8), loc=(-23.8, -2.5, G(-24)), base=True)                      # cabin door
        for y in (-4.6, 0, 4.6):                                                                 # frosted stern windows
            M.box(DARK, (0.7, 3.4, 4.0), loc=(-50.3, y, G(-50) + 2.6), base=True)
            M.box(ICE_D, (0.9, 2.4, 3.0), loc=(-50.3, y, G(-50) + 3.1), base=True)
        # masts: main mast broken, fore mast standing with a frozen sail rag
        gm = G(-4)
        M.rings(DARK, [(0, 1.9), (17, 1.7), (20.5, 0, 0, 0.9, -0.5)], n=8, loc=(-4, 0, gm))
        M.rings(SNOW, [(16.2, 1.9), (17.6, 1.2)], n=8, loc=(-4, 0, gm))
        a, b = V(1.0, 5.5, gm + 1.6), V(20.0, 11.0, gm + 2.4)                                    # fallen top on the deck / rail
        M.tube(DARK, [a, b], [1.5, 1.1], n=6)
        fx, gf = 28.0, G(28.0)
        M.rings(DARK, [(0, 1.7), (36, 1.2), (49, 0.7)], n=8, loc=(fx, 0, gf))
        M.rings(HULL, [(30, 1.5), (30.8, 3.0), (33.4, 3.3), (33.4, 2.5), (31.0, 2.3)], n=8, loc=(fx, 0, gf))
        M.rings(SNOW, [(33.4, 3.2), (34.4, 2.0)], n=8, loc=(fx, 0, gf))
        brace = TRS(loc=(fx, 0, 0), rot=(0, 0, -35)) @ TRS(loc=(-fx, 0, 0))
        with M.xf(m=brace):
            yz, tilt = gf + 27.0, -0.10
            M.tube(DARK, [(fx + 0.9, -13, yz - 13 * tilt), (fx + 0.9, 13, yz + 13 * tilt)], 0.62, n=6)
            M.tube(SNOW, [(fx + 0.9, -12.5, yz - 12.5 * tilt + 0.7), (fx + 0.9, 12.5, yz + 12.5 * tilt + 0.7)], 0.6, n=4)
            for y in range(-12, 13, 3):
                M.icicle(ICE if y % 2 else ICE_D, (fx + 0.9, y, yz + y * tilt - 0.4), 0.6, rng.uniform(3.0, 8.0), n=4)
            pts = [(fx + 1.5, -11, yz - 11 * tilt - 0.4), (fx + 1.5, -2, yz - 2 * tilt - 0.4), (fx + 2.6, -1.5, yz - 13),
                   (fx + 2.2, -4.5, yz - 9.5), (fx + 2.6, -7.0, yz - 15.5), (fx + 2.0, -10.5, yz - 8)]
            M.slab(FROST, pts, 0.35)                                                              # frozen sail rag
        M.tube(DARK, [(40, 0, G(40) + 4.6), (62, 0, G(40) + 12.5)], [1.1, 0.5], n=6)             # bowsprit
        M.tube(SNOW, [(42, 0, G(40) + 6.2), (60, 0, G(40) + 12.6)], [0.9, 0.5], n=4)
        for x in (44, 48, 52, 56, 60):
            M.icicle(ICE, (x, 0, G(40) + 4.6 + (x - 40) * 0.36 - 0.6), 0.5, rng.uniform(2.5, 5.5), n=4)
        # ropes turned to ice
        topm = V(fx, 0, gf + 43)
        for s in (-1, 1):
            for x in (21.0, 34.0):
                M.tube(FROST, [topm, (x, s * (beam(x) - 0.4), G(x) + (2.7 if x < 30 else 4.6))], 0.26, n=3)
        M.tube(FROST, [V(fx, 0, gf + 47), (61, 0, G(40) + 12.4)], 0.26, n=3)
        # anchor
        with M.xf(loc=(40.5, -beam(40.5) - 1.4, G(40.5) - 7.5), rot=(-10, 0, 6)):
            M.box(IRON, (0.8, 0.8, 7.0), base=True)
            M.box(IRON, (0.7, 4.4, 0.7), loc=(0, 0, 6.2))
            M.box(IRON, (0.8, 3.4, 0.9), loc=(0, -1.3, 0.9), rot=(42, 0, 0))
            M.box(IRON, (0.8, 3.4, 0.9), loc=(0, 1.3, 0.9), rot=(-42, 0, 0))
    # --- cracked ice slabs pushed up round the hull (world space) -----------------------------------------
    slabs = [(-45, -9.5, 17, 11, 15, 24), (-27, -12.5, 20, 12, -12, 30), (-8, -13.5, 19, 12, 8, 22), (11, -13, 21, 12, -6, 34),
             (29, -11, 18, 11, 14, 26), (43, -6.5, 14, 10, 34, 30), (-40, 10.5, 16, 10, -14, -24), (-20, 13, 19, 11, 8, -30),
             (2, 13.5, 18, 11, -10, -22), (22, 12.5, 17, 10, 12, -32), (40, 8.5, 14, 10, -28, -26), (53, 0, 12, 10, 80, 26)]
    for i, (x, y, sx, sy, yaw, tip) in enumerate(slabs):
        col = (ICE, ICE_D, FROST)[i % 3]
        M.block(col, (sx, sy, 3.6), loc=(x, y, 2.4), rot=(tip, rng.uniform(-10, 10), yaw), chamfer=0.22, jit=0.05, seed=20 + i)
    for i, (x, y) in enumerate(((-32, -17.5), (16, -18), (34, 16.5), (-8, 17.5))):                   # small shards
        M.block(ICE if i % 2 else FROST, (6, 4.5, 1.6), loc=(x, y, 0.5), rot=(8, -6, 30 * i), chamfer=0.25, seed=40 + i)
    M.ref_pos = (30.0, -21.0)
    M.view_dir = (0.55, -1.5, 0.5)
    return M


if __name__ == "__main__":
    run(build)
