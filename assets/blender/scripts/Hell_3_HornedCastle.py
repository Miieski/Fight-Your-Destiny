"""Hell_3_HornedCastle - castle facade with two enormous curved demon-horn towers and a ground-level tunnel (34 x 28)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

TILE, DARK, BORDER, BLACK, IRON, BANNER = "Hell_Tile", "Hell_GroundDark", "Hell_TileBorder", "Hell_Black", "Hell_Iron", "Hell_Banner"
RED, GROUND = "Neon_Hell_Red", "Hell_Ground"
TW, TH = 17.4, 28.4                     # tunnel half width / height (34.8 x 28.4 clear)
HORN_P = [(62, -3), (66, 45), (80, 85), (97, 120), (106, 148), (102, 168), (91, 181)]      # (x, z) centre line of a horn tower
HORN_R = [24.0, 22.0, 19.0, 14.0, 9.0, 4.5, 0.0]
N = 8


def horn_ring(sx, c, t, r):
    """Octagon ring perpendicular to the tangent t (path lies in the XZ plane); flat sides face +-Y."""
    v = V(t.z, 0, -t.x)
    return [V(sx * (c.x + v.x * math.sin(a) * r), math.cos(a) * r, c.z + v.z * math.sin(a) * r)
            for a in [2 * math.pi * (j + 0.5) / N for j in range(N)]]


def battlement(M, x0, x1, y, z, key=TILE, step=7.0):
    n = max(1, int(round((x1 - x0) / step)))
    for k in range(n + 1):
        x = lerp(x0, x1, k / n)
        M.box(key, (3.6, 3.0, 4.6), loc=(x, y, z), base=True)
        M.cone(IRON, 2.3, 4.2, n=4, loc=(x, y, z + 4.6))


def build():
    M = Model("Hell_3_HornedCastle", target=(230, 60, 180), seed=521)
    M.clip_z = 0.0
    # --- keep + gatehouses (front and back) with the tunnel straight through --------------------------------
    M.gate_box(TILE, 46.0, -24.0, 24.0, 0.0, 72.0, TW, TH)
    for (y0, y1) in ((-30.0, -24.0), (24.0, 30.0)):
        M.gate_box(DARK, 27.0, y0, y1, 0.0, 44.0, TW, TH)
        M.box(BORDER, (56.0, y1 - y0 + 1.0, 1.6), loc=(0, (y0 + y1) / 2.0, 44.0), base=True)
    for sy in (-1, 1):
        M.extrude(DARK, [(-25.0, 45.6), (25.0, 45.6), (0.0, 58.0)], 4.0, loc=(0, sy * 28.0, 0))                   # gable
        M.extrude(BORDER, [(-25.0, 45.6), (-21.5, 45.6), (0.0, 54.6), (21.5, 45.6), (25.0, 45.6), (0.0, 58.0)], 4.8,
                  loc=(0, sy * 28.0, 0))
        M.box(RED, (4.2, 1.0, 4.2), loc=(0, sy * 30.2, 49.6), rot=(0, 45, 0))                                    # gable gem
        for sx in (-1, 1):
            M.cone(IRON, 2.6, 9.0, n=4, loc=(sx * 25.0, sy * 27.0, 45.6))
            M.box(RED, (1.6, 1.0, 12.0), loc=(sx * 22.2, sy * 30.2, 32.0))                                       # jamb runes
            M.box(RED, (3.0, 1.0, 3.0), loc=(sx * 22.2, sy * 30.2, 20.0), rot=(0, 45, 0))
    for y in (-16.0, 0.0, 16.0):                                                                               # glow inside the tunnel
        for sx in (-1, 1):
            M.box(RED, (0.8, 2.2, 7.0), loc=(sx * TW, y, 15.0))
    # --- upper tiers, demon eyes, spire -----------------------------------------------------------------------
    M.box(BORDER, (94.0, 50.0, 2.0), loc=(0, 0, 72.0), base=True)
    battlement(M, -44.0, -34.0, -23.5, 74.0)
    battlement(M, 34.0, 44.0, -23.5, 74.0)
    battlement(M, -44.0, -34.0, 23.5, 74.0)
    battlement(M, 34.0, 44.0, 23.5, 74.0)
    M.box(TILE, (64.0, 40.0, 30.0), loc=(0, 0, 74.0), base=True, taper=0.96)
    M.box(BORDER, (64.0, 40.0, 2.0), loc=(0, 0, 104.0), base=True)
    battlement(M, -28.0, 28.0, -18.0, 106.0, step=8.0)
    battlement(M, -28.0, 28.0, 18.0, 106.0, step=8.0)
    M.box(DARK, (38.0, 30.0, 20.0), loc=(0, 0, 106.0), base=True, taper=0.94)
    M.rings(BLACK, [(126.0, 26.0, 21.0), (129.0, 20.0, 16.0), (152.0, 0, 0)], n=4)                               # spire
    for sx in (-1, 1):
        eye = [(sx * 5.0, 86.0), (sx * 21.0, 95.5), (sx * 23.0, 89.0), (sx * 9.0, 81.5)]
        M.extrude(BLACK, [(x + sx * (1.2 if i in (1, 2) else -1.2), z + (1.4 if i < 2 else -1.4)) for i, (x, z) in enumerate(eye)],
                  1.2, loc=(0, -19.8, 0))
        M.extrude(RED, eye, 2.0, loc=(0, -20.0, 0))
        M.box(RED, (2.0, 1.2, 9.0), loc=(sx * 7.0, -15.0, 116.0))                                                # top slits
        # banners + slit windows on the keep front
        M.extrude(BANNER, [(-4.5, 66.0), (4.5, 66.0), (4.5, 36.0), (0.0, 30.0), (-4.5, 36.0)], 0.9, loc=(sx * 34.0, -24.5, 0))
        M.box(IRON, (11.0, 1.2, 1.2), loc=(sx * 34.0, -24.7, 66.4))
        M.box(BLACK, (3.0, 0.9, 3.0), loc=(sx * 34.0, -25.0, 54.0), rot=(0, 45, 0))                              # banner emblem
        M.box(RED, (2.0, 1.2, 11.0), loc=(sx * 42.5, -23.8, 54.0))
        M.box(RED, (2.0, 1.2, 9.0), loc=(sx * 10.0, -23.8, 64.5))
    M.box(RED, (2.0, 1.2, 9.0), loc=(0, -23.8, 64.5))
    M.extrude(RED, [(-3.5, 96.0), (3.5, 96.0), (0, 86.0)], 2.0, loc=(0, -20.0, 0))                               # nose slit
    # --- the two horn towers ---------------------------------------------------------------------------------------
    pts = [V(x, 0, z) for x, z in HORN_P]
    tans = [(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(len(pts))]
    for sx in (-1, 1):
        rings = [horn_ring(sx, pts[i], tans[i], HORN_R[i]) for i in range(len(pts) - 1)]
        tip = [V(sx * pts[-1].x, 0, pts[-1].z)]
        M.loft(TILE, rings[0:3])
        M.loft(DARK, rings[2:5])
        M.loft(BLACK, rings[4:6] + [tip])
        for i, key in ((2, BORDER), (4, IRON)):                                                                  # collars
            M.loft(key, [horn_ring(sx, pts[i] - tans[i] * 2.0, tans[i], HORN_R[i] * 1.09),
                         horn_ring(sx, pts[i] + tans[i] * 2.0, tans[i], HORN_R[i] * 1.07)])
        M.loft(BORDER, [horn_ring(sx, V(62.6, 0, 4.0), V(0.09, 0, 1), 25.5), horn_ring(sx, V(63.0, 0, 8.0), V(0.09, 0, 1), 24.6)])
        for (z, h) in ((20.0, 10.0), (40.0, 10.0), (60.0, 9.0), (76.0, 7.0)):                                    # slit windows
            t = (z + 3.0) / 48.0 if z < 45 else 1.0 + (z - 45.0) / 40.0
            i0 = min(int(t), 1)
            f = t - i0
            cx = lerp(HORN_P[i0][0], HORN_P[i0 + 1][0], f)
            r = lerp(HORN_R[i0], HORN_R[i0 + 1], f) * 0.924
            for dx in (-5.0, 5.0):
                M.box(RED, (2.0, 2.4, h), loc=(sx * (cx + dx), -r + 0.5, z))
        for i in (3, 4):                                                                                         # spikes on the outer curve
            c = pts[i].lerp(pts[i - 1], 0.45)
            M.spike(IRON, (sx * (c.x + HORN_R[i] * 0.95), 0, c.z), 3.4, 14.0, n=4, rot=(0, sx * 62, 0), waist=0.2)
        # buttress rocks at the foot of the tower
        M.rock(GROUND, (22, 16, 12), loc=(sx * 84, -17, 0), seed=10 + sx)
        M.rock(DARK, (14, 12, 8), loc=(sx * 96, -6, 0), seed=20 + sx)
        M.rock(GROUND, (18, 14, 10), loc=(sx * 88, 16, 0), seed=30 + sx)
    M.anchors["TunnelFront"] = (0, -30.0, 0)
    M.anchors["TunnelBack"] = (0, 30.0, 0)
    M.notes = "Ground-level tunnel on the center line, front to back: %.1f wide x %.1f high clear, 60 long." % (2 * TW, TH)
    M.ref_pos = (24.0, -36.0)
    M.view_dir = (0.45, -1.5, 0.4)
    return M


if __name__ == "__main__":
    run(build)
