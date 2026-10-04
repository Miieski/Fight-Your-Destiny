"""Plains_2_PirateShip - half-sunk wrecked pirate ship (bow up 15 degrees, stern under the sand/water)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

HULL, DARK, DECK = "Common_Wood", "Common_WoodDark", "Common_WoodLight"
CLOTH, IRON, GOLD, ROPE, FLAG = "Common_Cloth", "Common_Iron", "Common_Gold", "Common_Rope", "Hub_Banner"

KX = [-50, -40, -24, 0, 25, 40, 47, 50]
KB = [8.5, 11.5, 13.2, 13.8, 12.2, 7.6, 3.4, 0.6]
KZ = [7.0, 2.5, 0.5, 0.0, 0.5, 1.6, 4.0, 8.0]
QD_X0, QD_X1, FC_X0, FC_X1 = -50, -24, 30, 47


def interp(x, xs, ys):
    if x <= xs[0]:
        return ys[0]
    for i in range(1, len(xs)):
        if x <= xs[i]:
            return lerp(ys[i - 1], ys[i], (x - xs[i - 1]) / (xs[i] - xs[i - 1]))
    return ys[-1]


def beam(x):
    return interp(x, KX, KB)


def G(x):
    """Sheer line = main deck / gunwale height."""
    return 14.0 + 0.0013 * x * x


def ring(x):
    b, zk, g = beam(x), interp(x, KX, KZ), G(x)
    zb = zk + (g - zk) * 0.25
    return [(x, -b, g), (x, -b * 1.05, g - 3.5), (x, -b * 0.7, zb), (x, 0, zk),
            (x, b * 0.7, zb), (x, b * 1.05, g - 3.5), (x, b, g)]


def side_pt(x, t, s=-1, off=0.0):
    """Point on the hull side panel (t = 0 bilge .. 1 wale), pushed outward by off."""
    r = ring(x)
    a, b = (V(r[2]), V(r[1])) if s < 0 else (V(r[4]), V(r[5]))
    p = a.lerp(b, t)
    d = b - a
    n = V(0, d.z, -d.y).normalized()
    if n.y * s < 0:
        n = -n
    return p + n * off


def castle_top(x):
    return G(x) + (8.5 if x < 0 else 4.6)


def build():
    M = Model("Plains_2_PirateShip", target=(110, 34, 60), seed=31)
    M.clip_z = 0.0
    pose = TRS(loc=(0, 0, -5.5), rot=(7, -15, 0))
    with M.xf(m=pose):
        xs = [-50, -45, -40, -35, -30, -24, -18, -12, -6, 0, 6, 12, 18, 24, 30, 35, 40, 44, 47, 50]
        # --- hull --------------------------------------------------------------------------
        M.loft(HULL, [ring(x) for x in xs])
        for s in (-1, 1):                                                   # wale (dark band)
            M.loft(DARK, [[side_pt(x, 0.70, s, 0.45), side_pt(x, 1.0, s, 0.45),
                           side_pt(x, 1.0, s, -0.6), side_pt(x, 0.70, s, -0.6)] for x in xs])
        M.tube(DARK, [(50.3, 0, 7.5), (51.6, 0, 13), (52.4, 0, 19), (52.6, 0, 24)], [0.9, 0.9, 0.8, 0.7], n=4)  # stem
        M.tube(DARK, [(-50, 0, 6.6), (-25, 0, -0.2), (0, 0, -0.7), (25, 0, -0.2), (41, 0, 1.4), (50.3, 0, 7.5)],
               0.8, n=4)                                                    # keel
        # --- main deck planking ------------------------------------------------------------
        M.loft(DECK, [[(x, -beam(x) + 1.0, G(x) - 0.3), (x, beam(x) - 1.0, G(x) - 0.3),
                       (x, beam(x) - 1.0, G(x) + 0.3), (x, -beam(x) + 1.0, G(x) + 0.3)]
                      for x in xs if QD_X1 - 1 <= x <= FC_X0 + 1])

        # --- bulwarks (broken above the hull breach on the -Y side) ---------------------------
        def bulwark(s, x0, x1, h=2.7):
            st = [x for x in xs if x0 <= x <= x1]
            M.loft(HULL, [[(x, s * beam(x), G(x) - 0.3), (x, s * (beam(x) - 0.9), G(x) - 0.3),
                           (x, s * (beam(x) - 0.9), G(x) + h), (x, s * beam(x), G(x) + h)] for x in st])
            M.tube(DARK, [(x, s * (beam(x) - 0.45), G(x) + h) for x in st], 0.62, n=4)
        bulwark(1, -24, 30)
        bulwark(-1, -24, 12)
        bulwark(-1, 24, 30)
        # --- castles -----------------------------------------------------------------------
        for x0, x1 in ((QD_X0, QD_X1), (FC_X0, FC_X1)):
            st = [x for x in xs if x0 <= x <= x1]
            M.loft(HULL, [[(x, -beam(x), G(x) - 0.6), (x, beam(x), G(x) - 0.6),
                           (x, beam(x) * 0.96, castle_top(x)), (x, -beam(x) * 0.96, castle_top(x))] for x in st])
            M.loft(DECK, [[(x, -beam(x) * 0.96 + 0.8, castle_top(x) - 0.2), (x, beam(x) * 0.96 - 0.8, castle_top(x) - 0.2),
                           (x, beam(x) * 0.96 - 0.8, castle_top(x) + 0.3), (x, -beam(x) * 0.96 + 0.8, castle_top(x) + 0.3)]
                          for x in st])
            for s in (-1, 1):                                               # trim + rail
                M.tube(DARK, [(x, s * beam(x) * 0.97, castle_top(x) + 0.1) for x in st], 0.55, n=4)
                M.tube(DARK, [(x, s * (beam(x) * 0.96 - 0.3), castle_top(x) + 2.7) for x in st], 0.4, n=4)
                for x in st:
                    M.box(DARK, (0.6, 0.6, 2.6), loc=(x, s * (beam(x) * 0.96 - 0.3), castle_top(x)), base=True)
                M.tube(GOLD, [(x, s * (beam(x) * 1.0 + 0.1), G(x) + 0.3) for x in st], 0.4, n=4)
        # quarterdeck front rail + cabin door + stairs
        b = beam(QD_X1) * 0.96
        zt = castle_top(QD_X1)
        M.tube(DARK, [(QD_X1, -b + 0.3, zt + 2.7), (QD_X1, b - 0.3, zt + 2.7)], 0.4, n=4)
        for y in (-8, -4, 0, 4, 8):
            M.box(DARK, (0.6, 0.6, 2.6), loc=(QD_X1, y, zt), base=True)
        M.box(DARK, (0.8, 4.6, 6.8), loc=(QD_X1 + 0.2, -2.5, G(QD_X1)), base=True)
        M.box(GOLD, (1.0, 5.4, 0.6), loc=(QD_X1 + 0.2, -2.5, G(QD_X1) + 6.8), base=True)
        M.box(GOLD, (1.1, 0.6, 0.6), loc=(QD_X1 + 0.3, -1.0, G(QD_X1) + 3.4))
        for k in range(5):
            M.box(DECK, (1.7, 4.4, 1.7 * (5 - k)), loc=(QD_X1 + 0.85 + 1.7 * k, 7.6, G(QD_X1)), base=True)
        # stern: transom windows + lantern
        xt, gt = -50.3, G(-50)
        for y in (-4.6, 0, 4.6):
            M.box(GOLD, (0.7, 3.4, 4.0), loc=(xt, y, gt + 2.6), base=True)
            M.box(IRON, (0.9, 2.4, 3.0), loc=(xt, y, gt + 3.1), base=True)
        M.box(DARK, (0.6, 0.6, 5.0), loc=(-49.4, 0, castle_top(-50)), base=True)
        M.rings(GOLD, [(0, 0.6), (0.6, 1.3), (2.4, 1.3), (3.4, 0)], n=6, loc=(-49.4, 0, castle_top(-50) + 5.0))
        # steering wheel
        with M.xf(loc=(-31, 0, castle_top(-31))):
            M.box(DARK, (1.2, 1.6, 3.2), loc=(0, 0, 0), base=True, taper=0.7)
            with M.xf(loc=(0.9, 0, 3.6), rot=(0, 90, 0)):
                M.tube(DARK, [polar(2.1, 45 * i) for i in range(8)], 0.3, n=4, closed=True)
                for i in range(4):
                    M.box(DARK, (5.4, 0.36, 0.36), rot=(0, 0, 45 * i))
        # mizzen stub (snapped low)
        M.rings(DARK, [(0, 1.4), (7.0, 1.3), (9.6, 0, 0, 0.7, 0.3)], n=6, loc=(-38, 0, castle_top(-38)))
        # --- main mast: broken stub + fallen top resting on the fore mast ----------------------
        gm = G(-4)
        M.rings(DARK, [(0, 1.9), (22, 1.7), (25.5, 0, 0, 0.9, -0.5)], n=8, loc=(-4, 0, gm))
        M.rings(DARK, [(20, 1.2), (27.5, 0, 0, -0.9, 0.6)], n=5, loc=(-4, 0, gm))
        a, bb = V(3.5, 4.5, gm + 0.9), V(27.0, 1.9, 45.0)
        M.tube(DARK, [a, bb], [1.5, 1.0], n=6)
        mid = a.lerp(bb, 0.55)
        yard = V(0.25, 1, 0.1).normalized()
        M.tube(DARK, [mid - yard * 11, mid + yard * 11], 0.55, n=5)
        M.chunk(CLOTH, mid - yard * 9 - V(0, 0, 0.9), mid + yard * 9 - V(0, 0, 0.9), 1.1, n=5, jit=0.2)  # furled sail
        p0, p1 = mid - yard * 7.5 - V(0, 0, 1.2), mid - yard * 1.5 - V(0, 0, 1.2)
        M.slab(CLOTH, [p0, p1, p1 - V(-0.6, 0.3, 6.0), p0.lerp(p1, 0.6) - V(-0.5, 0, 9.5), p0 - V(-0.3, 0, 4.5)], 0.3)
        # --- fore mast with torn sail ----------------------------------------------------------
        fx, gf = 28.0, G(28.0)
        M.rings(DARK, [(0, 1.7), (36, 1.2), (47, 0.7)], n=8, loc=(fx, 0, gf))
        M.rings(HULL, [(34, 1.5), (34.8, 3.0), (37.4, 3.3), (37.4, 2.5), (35.0, 2.3)], n=8, loc=(fx, 0, gf))   # lookout nest
        yz, tilt = gf + 31.0, 0.13
        brace = TRS(loc=(fx, 0, 0), rot=(0, 0, -38)) @ TRS(loc=(-fx, 0, 0))    # yards braced round so the sail shows from the side
        with M.xf(m=brace):
            M.tube(DARK, [(fx + 0.9, -13.5, yz - 13.5 * tilt), (fx + 0.9, 13.5, yz + 13.5 * tilt)], 0.62, n=6)
            M.tube(DARK, [(fx + 0.8, -7, yz + 11.6), (fx + 0.8, 7, yz + 10.8)], 0.45, n=5)                      # top yard
            strips = [(-12.5, -7.0, [(-7.0, 17.5, 1.6), (-9.0, 13.0, 1.2), (-10.8, 15.5, 1.3), (-12.5, 10.5, 0.8)]),
                      (-7.0, -1.0, [(-1.0, 21.0, 2.6), (-3.2, 16.0, 2.0), (-5.0, 19.0, 2.3), (-7.0, 17.5, 1.9)]),
                      (-1.0, 5.5, [(5.5, 14.0, 1.8), (3.6, 17.5, 2.4), (1.4, 12.5, 1.7), (-1.0, 21.0, 2.6)]),
                      (5.5, 12.5, [(12.5, 8.0, 0.7), (10.2, 11.5, 1.2), (8.0, 7.5, 0.9), (5.5, 14.0, 1.6)])]
            for y0, y1, bottom in strips:
                pts = [(fx + 1.5, y0, yz + y0 * tilt - 0.4), (fx + 1.5, y1, yz + y1 * tilt - 0.4)]
                pts += [(fx + 1.5 + bx, y, yz + y * tilt - drop) for (y, drop, bx) in bottom]
                M.slab(CLOTH, pts, 0.3)
            M.slab(CLOTH, [(fx + 1.2, -6, yz + 11.2), (fx + 1.2, 1.5, yz + 10.7), (fx + 1.9, 0.5, yz + 5.5),
                           (fx + 1.6, -2.0, yz + 7.8), (fx + 1.8, -5.0, yz + 4.2)], 0.3)                      # topsail rag
        M.slab(FLAG, [(fx, 0.0, gf + 46.5), (fx, 0.0, gf + 41.5), (fx - 5.0, 0.6, gf + 42.4), (fx - 3.6, 0.3, gf + 43.8),
                      (fx - 8.5, 1.0, gf + 44.6), (fx - 4.4, 0.5, gf + 45.6)], 0.3)
        # --- bowsprit, figurehead, anchor -------------------------------------------------------
        M.tube(DARK, [(40, 0, G(40) + 4.6), (64, 0, G(40) + 13.5)], [1.1, 0.5], n=6)
        M.chunk(GOLD, (51.5, 0, 17.5), (55.0, 0, 20.5), 1.5, 0.9, n=5)
        M.box(GOLD, (1.0, 2.6, 1.0), loc=(52.2, 0, 15.2))
        with M.xf(loc=(40.5, -beam(40.5) - 1.4, G(40.5) - 7.5), rot=(-10, 0, 6)):
            M.box(IRON, (0.8, 0.8, 7.0), base=True)
            M.box(IRON, (0.7, 4.4, 0.7), loc=(0, 0, 6.2))
            M.box(IRON, (0.8, 3.4, 0.9), loc=(0, -1.3, 0.9), rot=(42, 0, 0))
            M.box(IRON, (0.8, 3.4, 0.9), loc=(0, 1.3, 0.9), rot=(-42, 0, 0))
            M.tube(ROPE, [(0, 0, 7.0), (0.5, 1.3, 11.5)], 0.3, n=4)
        # --- deck clutter -----------------------------------------------------------------------
        M.box(DARK, (7.5, 6.5, 0.6), loc=(9.5, 0.5, G(9.5) + 0.3), base=True)                              # hatch
        for (cx, rz) in ((-13, 6), (17, -14)):                                                             # cannons
            with M.xf(loc=(cx, 9.4, G(cx) + 0.3), rot=(0, 0, rz)):
                M.box(HULL, (3.0, 4.2, 1.3), base=True)
                M.rings(IRON, [(0, 1.0), (4.8, 0.8), (5.3, 1.0), (5.9, 1.0)], n=6, loc=(0, -2.2, 2.0), rot=(-96, 0, 0))
        for (bx, by) in ((-19.5, 8.5), (-17.0, 10.0), (3.0, -8.0)):
            M.rings(HULL, [(0, 1.3), (1.6, 1.75), (3.2, 1.3)], n=8, loc=(bx, by, G(bx) + 0.3))
            M.rings(IRON, [(1.3, 1.82), (1.9, 1.82)], n=8, loc=(bx, by, G(bx) + 0.3))
        M.box(DECK, (3.4, 3.4, 3.2), loc=(-20.5, -8.5, G(-20) + 0.3), rot=(0, 0, 18), base=True)
        # --- hull breach on the -Y side (dark patch + snapped planks + visible ribs) --------------
        hole = [(12.0, 0.55), (15.0, 0.83), (18.5, 0.94), (23.0, 0.88), (27.0, 0.62), (28.0, 0.35),
                (24.5, 0.16), (19.5, 0.06), (15.0, 0.2)]
        M.slab(IRON, [side_pt(x, t, -1, 0.14) for x, t in hole], 0.3)
        for x in (16.0, 20.0, 24.0):
            M.tube(DARK, [side_pt(x, 0.12, -1, 0.5), side_pt(x, 0.85, -1, 0.5)], 0.45, n=4)               # ribs
        rng = random.Random(4)
        for i, (x, t) in enumerate(hole):
            a = side_pt(x, t, -1, 0.3)
            c = side_pt(20.0, 0.5, -1, 1.6)
            tip = a.lerp(c, rng.uniform(0.25, 0.5))
            M.chunk(DECK, a, tip, (0.9, 0.35), (0.5, 0.25), n=4, jit=0.1, bulge=0.2)
        # --- rigging ----------------------------------------------------------------------------
        top = V(fx, 0, gf + 40)
        for s in (-1, 1):
            for x in (21.0, 34.0):
                M.tube(ROPE, [top, (x, s * (beam(x) - 0.4), G(x) + (2.7 if x < FC_X0 else 4.6))], 0.24, n=3)
        M.tube(ROPE, [V(fx, 0, gf + 45), (63, 0, G(40) + 13.2)], 0.24, n=3)
        M.tube(ROPE, [bb, V(fx, 0, gf + 33)], 0.24, n=3)
    # --- loose planks and a barrel on the sand next to the breach (world space) --------------------
    for (x, y, rz, L) in ((16, -20.5, 20, 9), (27, -19.0, -35, 7), (8, -18.5, 80, 6), (34, -20.5, 8, 8), (-4, -18.0, -15, 7)):
        M.box(DECK, (L, 1.6, 0.7), loc=(x, y, 0.0), rot=(0, 0, rz), base=True)
    M.rings(HULL, [(0, 1.3), (1.6, 1.75), (3.2, 1.3)], n=8, loc=(22, -21.0, 1.3), rot=(78, 0, 30))
    M.ref_pos = (40.0, -22.0)
    M.view_dir = (0.55, -1.5, 0.5)
    return M


if __name__ == "__main__":
    run(build)
