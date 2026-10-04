"""Jungle_3_StepPyramid - mossy 6-tier temple pyramid with a ground-level tunnel (40 x 26) straight through,
double stair round the gate + central upper stair, shrine with doorway, glowing glyph bands."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

STONE, STONE_D, MOSS = "Jungle_Stone", "Jungle_StoneDark", "Jungle_Moss"
GLYPH, ROOT, LEAF, GOLD = "Neon_Jungle_Glyph", "Jungle_Trunk", "Jungle_Leaf", "Jungle_Gold"

CY = 6.0                               # body centre (the stair sticks out 12 studs at the front)
HX = [60.0, 51.6, 43.2, 34.8, 26.4, 18.0]
HY = [54.0, 46.4, 38.8, 31.2, 23.6, 16.0]
TH = 9.5                               # tier height
TOP = TH * 6                           # 57
TAPER = 0.975
STAIR_W, STAIR_Y0, STAIR_Y1, STEPS = 20.0, -60.0, CY - HY[5] + 0.5, 24
TW, TUN_H = 21.2, 26.5                 # tunnel half width / height before the final squeeze (40.4 x 26.2 after it)
Z3 = 3 * TH                            # landing level = top of tier 3
XS = TW + 9.7                          # centre line of the two lower side stairs (10 wide)


def halves(M, key, x_out, hy, z0, h, taper=1.0):
    """Left and right parts of a tier, leaving the tunnel (|x| < TW) open; the inner walls stay vertical."""
    for s in (-1, 1):
        w = x_out - TW
        w_top = x_out * taper - TW
        M.box(key, (w, hy * 2, h), loc=(s * (TW + x_out) / 2.0, CY, z0), base=True, taper=(w_top / w, taper),
              top_off=(s * (x_out * taper - x_out) / 2.0, 0))


def build():
    M = Model("Jungle_3_StepPyramid", target=(120, 120, 80), seed=121)
    rng = random.Random(9)
    SX, SY, SZ = 0.972, 0.946, 0.99                 # squeeze the build into 120 x 120 x 80
    M.stack[0] = TRS(scale=(SX, SY, SZ))
    # --- tiers (the three lowest ones are split by the tunnel) ------------------------------------------------
    for i in range(6):
        z0 = i * TH
        if i < 3:
            halves(M, STONE, HX[i], HY[i], z0, TH, TAPER)
            halves(M, STONE_D, HX[i] + 0.4, HY[i] + 0.4, z0, 1.2)                                                       # foot course
            if i < 2:
                halves(M, STONE_D, HX[i] * TAPER + 0.7, HY[i] * TAPER + 0.7, z0 + TH - 1.3, 1.3)                        # cornice
            else:
                M.box(STONE, (2 * TW + 0.4, HY[i] * 2 * TAPER, Z3 - TUN_H), loc=(0, CY, TUN_H), base=True)              # tunnel roof
                M.box(STONE_D, (HX[i] * 2 * TAPER + 1.4, HY[i] * 2 * TAPER + 1.4, 1.3), loc=(0, CY, z0 + TH - 1.3), base=True)
        else:
            M.box(STONE, (HX[i] * 2, HY[i] * 2, TH), loc=(0, CY, z0), base=True, taper=TAPER)
            M.box(STONE_D, (HX[i] * 2 * TAPER + 1.4, HY[i] * 2 * TAPER + 1.4, 1.3), loc=(0, CY, z0 + TH - 1.3), base=True)   # cornice
            M.box(STONE_D, (HX[i] * 2 + 0.8, HY[i] * 2 + 0.8, 1.2), loc=(0, CY, z0), base=True)                             # foot course
    # --- gatehouses round the tunnel mouths (front and back) + glyphs inside the tunnel ---------------------------
    yf1, yf3, yb1, yb3 = CY - HY[0], CY - HY[2], CY + HY[0], CY + HY[2]
    for (y0, y1) in ((yf1 - 2.0, yf3 + 2.0), (yb3 - 2.0, yb1 + 1.0)):
        for sx in (-1, 1):
            M.box(STONE_D, (4.4, y1 - y0, Z3), loc=(sx * (TW + 2.2), (y0 + y1) / 2.0, 0), base=True)                    # jambs
        M.box(STONE_D, (2 * TW + 8.8, y1 - y0, Z3 - TUN_H), loc=(0, (y0 + y1) / 2.0, TUN_H), base=True)                 # lintel
    for (yy, sg) in ((yf1 - 2.3, -1), (yb1 + 1.3, 1)):
        M.box(GLYPH, (22.0, 0.8, 1.1), loc=(0, yy, TUN_H + 1.0))
        for sx in (-1, 1):
            M.box(GLYPH, (1.3, 0.8, 9.0), loc=(sx * (TW + 2.2), yy, 14.0))
            M.box(GLYPH, (2.4, 0.8, 2.4), loc=(sx * (TW + 2.2), yy, 22.0), rot=(0, 45, 0))
    for y in (-28.0, -8.0, 12.0, 32.0):
        for sx in (-1, 1):
            M.box(GLYPH, (0.8, 3.0, 3.6), loc=(sx * TW, y, 13.0))
    # --- glyph bands on tiers 2, 4 and 6 (skipping the stair) ------------------------------------------------
    for i in (1, 3, 5):
        zc = i * TH + TH * 0.52
        hx, hy = HX[i] * 0.989, HY[i] * 0.988
        k = 0
        x = -hx + 5.0
        while x <= hx - 5.0 + 1e-3:
            shape = ((2.6, 3.4), (3.4, 2.2), (1.6, 3.8), (3.0, 3.0))[k % 4]
            if abs(x) > (TW + 19.5 if i < 3 else STAIR_W / 2 + 4.5):
                M.box(GLYPH, (shape[0], 1.0, shape[1]), loc=(x, CY - hy, zc))
            if i >= 3 or abs(x) > TW + 6.0:
                M.box(GLYPH, (shape[0], 1.0, shape[1]), loc=(x, CY + hy, zc))
            x += 7.2
            k += 1
        y = -hy + 5.0
        while y <= hy - 5.0 + 1e-3:
            shape = ((2.6, 3.4), (3.4, 2.2), (1.6, 3.8), (3.0, 3.0))[k % 4]
            for sx in (-1, 1):
                M.box(GLYPH, (1.0, shape[0], shape[1]), loc=(sx * hx, CY + y, zc))
            y += 7.2
            k += 1
    # --- stairs: two side flights from the ground to the landing over the gate, then the central flight --------
    dy, dz = (STAIR_Y1 - STAIR_Y0) / STEPS, TOP / STEPS
    K0 = 12                                             # step index where the stair line reaches the landing (Z3)
    y12 = STAIR_Y0 + K0 * dy
    slope = TOP / (STAIR_Y1 - STAIR_Y0)
    prof = [(y12, Z3)]
    for k in range(K0, STEPS):
        prof.append((STAIR_Y0 + k * dy, (k + 1) * dz))
        prof.append((STAIR_Y0 + (k + 1) * dy, (k + 1) * dz))
    prof.append((STAIR_Y1 + 1.0, TOP))
    prof.append((STAIR_Y1 + 1.0, Z3))
    M.extrude(STONE, prof, STAIR_W, axis="X")
    low = [(STAIR_Y0, 0.0)]
    for k in range(K0):
        low.append((STAIR_Y0 + k * dy, (k + 1) * dz))
        low.append((STAIR_Y0 + (k + 1) * dy, (k + 1) * dz))
    low[-1] = (yf3 + 1.0, Z3)                           # the top tread runs onto tier 3
    low.append((yf3 + 1.0, 0.0))
    for sx in (-1, 1):
        M.extrude(STONE, low, 10.0, axis="X", loc=(sx * XS, 0, 0))
        xo = sx * (XS + 6.6)                            # outer balustrade of the side flight + serpent head
        M.extrude(STONE_D, [(STAIR_Y0 - 1.5, 0), (STAIR_Y0 - 1.5, 3.6), (y12, Z3 + 3.4), (yf3 + 1.0, Z3 + 3.4), (yf3 + 1.0, 0)],
                  3.2, axis="X", loc=(xo, 0, 0))
        M.block(STONE, (5.6, 6.4, 5.6), loc=(xo, STAIR_Y0 - 2.4, 0), base=True, chamfer=0.2, jit=0.0)
        M.box(STONE_D, (6.2, 3.0, 1.4), loc=(xo, STAIR_Y0 - 4.6, 1.2))
        for ex in (-1, 1):
            M.box(GLYPH, (0.7, 1.3, 1.1), loc=(xo + ex * 2.75, STAIR_Y0 - 3.4, 3.9))
        yy = lerp(STAIR_Y0, y12, 0.5)
        M.box(GLYPH, (0.8, 2.6, 2.6), loc=(xo + sx * 1.4, yy + 1.2, (yy - STAIR_Y0) * slope - 2.0), rot=(49, 0, 0))
        x = sx * (STAIR_W / 2 + 1.6)                    # balustrade of the central flight
        M.extrude(STONE_D, [(y12 - 1.5, Z3), (y12 - 1.5, Z3 + 3.6), (STAIR_Y1, TOP + 3.2), (STAIR_Y1 + 2.5, TOP + 3.2),
                            (STAIR_Y1 + 2.5, Z3)], 3.2, axis="X", loc=(x, 0, 0))
        for t in (0.62, 0.84):
            yy = lerp(STAIR_Y0, STAIR_Y1, t)
            M.box(GLYPH, (0.8, 2.6, 2.6), loc=(x + sx * 1.4, yy + 1.2, (yy - STAIR_Y0) * slope - 2.0), rot=(49, 0, 0))
        M.rings(GOLD, [(0, 1.5), (0.7, 1.1), (3.4, 1.4), (4.0, 0.9), (5.2, 1.2), (6.0, 0)], n=6,
                loc=(sx * (TW + 2.2), yf1 - 0.2, Z3))                                           # idols on the gate corners
    # --- shrine on the top platform ------------------------------------------------------------------------------
    with M.xf(loc=(0, CY + 2.0, TOP)):
        W, D, H = 23.0, 18.0, 13.5
        M.box(STONE_D, (W + 3, D + 3, 1.0), base=True)                                                    # plinth
        M.box(STONE_D, (W - 3, D - 3, H - 1), loc=(0, 0.5, 1.0), base=True)                               # dark interior
        for sx in (-1, 1):
            M.box(STONE, (3.2, D, H), loc=(sx * (W / 2 - 1.6), 0, 1.0), base=True, taper=(0.9, 0.97))     # side walls
            M.box(STONE, (5.4, 3.0, H), loc=(sx * (W / 2 - 4.0), -D / 2 + 1.5, 1.0), base=True)           # door jambs
            M.box(GLYPH, (1.0, 0.8, 6.5), loc=(sx * 5.7, -D / 2 - 0.2, 5.6))
            M.rings(GOLD, [(0, 1.5), (0.7, 1.1), (3.4, 1.4), (4.0, 0.9), (5.2, 1.2), (6.0, 0)], n=6,
                    loc=(sx * 9.4, -D / 2 - 2.6, 1.0))                                                    # small idols
        M.box(STONE, (W, 3.2, H), loc=(0, D / 2 - 1.6, 1.0), base=True)                                   # back wall
        M.box(STONE, (W, 3.4, 4.0), loc=(0, -D / 2 + 1.5, H - 3.0), base=True)                            # lintel
        M.box(GLYPH, (9.0, 0.8, 1.4), loc=(0, -D / 2 - 0.3, H - 0.9))
        M.box(STONE_D, (W + 3.2, D + 3.2, 2.4), loc=(0, 0, H + 1.0), base=True, taper=0.93)               # roof
        M.box(STONE, (16.0, 5.0, 4.0), loc=(0, 1.0, H + 3.4), base=True, taper=(0.9, 0.8))                # roof comb
        M.box(STONE_D, (9.0, 3.6, 2.9), loc=(0, 1.0, H + 7.4), base=True, taper=(0.8, 0.8))
        M.rings(GOLD, [(0, 3.2), (0.9, 2.8)], n=8, loc=(0, -1.4, H + 5.6), rot=(90, 0, 0))                # sun disc
        M.rings(GLYPH, [(0, 1.5), (0.5, 1.2)], n=8, loc=(0, -2.2, H + 5.6), rot=(90, 0, 0))
    # --- moss on the ledges (corners and edges) + drips ---------------------------------------------------------
    for i in range(6):
        z = (i + 1) * TH
        hx, hy = HX[i] * TAPER, HY[i] * TAPER
        ledge = (HX[i] - HX[i + 1]) if i < 5 else 6.0
        for _ in range(4 if i < 4 else 2):
            side = rng.choice((0, 1, 2, 3)) if i else rng.choice((1, 2, 3))
            L = rng.uniform(9, 20)
            t = rng.uniform(-0.75, 0.75)
            if side == 0 and i < 3:                     # keep the gate, the landing and the side stairs clear
                L = min(L, 12.0)
                if hx - L - 1.0 < TW + 19.0:
                    side = 1
                else:
                    t = (1.0 if t > 0 else -1.0) * (hx - L / 2 - 1.0) / (hx - L / 2)
            elif side == 0 and abs(t * hx) < STAIR_W / 2 + L / 2 + 5:
                t = 0.72 if t > 0 else -0.72
            if side == 2 and i < 2 and abs(t * (hx - L / 2)) < TW + 6.5 + L / 2:
                t = (1.0 if t > 0 else -1.0) * min(0.95, (TW + 6.5 + L / 2) / (hx - L / 2))
            if side in (0, 2):
                sgn = -1 if side == 0 else 1
                M.block(MOSS, (L, ledge * 0.8, 1.6), loc=(t * (hx - L / 2), CY + sgn * (hy - ledge * 0.32), z + 0.2), chamfer=0.25, jit=0.03)
                M.box(MOSS, (L * 0.3, 1.0, rng.uniform(2.5, 5.5)), loc=(t * (hx - L / 2) + rng.uniform(-2, 2), CY + sgn * (hy + 0.5), z - 2.2),
                      taper=(0.5, 1.0))
            else:
                sgn = -1 if side == 3 else 1
                M.block(MOSS, (ledge * 0.8, L, 1.6), loc=(sgn * (hx - ledge * 0.32), CY + t * (hy - L / 2), z + 0.2), chamfer=0.25, jit=0.03)
                M.box(MOSS, (1.0, L * 0.3, rng.uniform(2.5, 5.5)), loc=(sgn * (hx + 0.5), CY + t * (hy - L / 2) + rng.uniform(-2, 2), z - 2.2),
                      taper=(1.0, 0.5))
    # --- roots crawling down the steps (front-right and left side) + bushes -----------------------------------------
    def root(sx, y0, start, drift, r0):
        pts, rad = [], []
        y = y0
        pts.append((sx * (HX[start] * TAPER - 5), y, (start + 1) * TH + 0.9))
        rad.append(r0 * 0.6)
        for i in range(start, -1, -1):
            xe = sx * (HX[i] * TAPER + 1.0)
            pts.append((xe, y, (i + 1) * TH + 1.0))
            y += drift
            pts.append((sx * (HX[i] + 1.3), y, i * TH + 1.6))
            rad += [r0, r0 * 1.05]
            y += drift * 0.5
            r0 *= 1.08
        pts.append((sx * (HX[0] + 3.0), y + drift * 2, -0.5))
        rad.append(r0 * 0.5)
        M.tube(ROOT, pts, rad, n=5)
    M.clip_z = 0.0
    root(1, -30.0, 4, 2.2, 1.25)
    root(1, -24.0, 3, -1.8, 1.0)
    root(-1, 20.0, 5, 2.6, 1.3)
    root(-1, 30.0, 3, -1.5, 1.0)
    M.clip_z = None
    spots = [(1, 21.0, -31, 5), (1, 30, -22, 4), (-1, 21.5, 22, 5), (-1, 38.5, 30, 3), (1, 55, 40, 1), (-1, 56, -30, 1),
             (1, 46, -44 + CY, 2), (-1, 30, 40, 4)]
    for k, (sx, x, y, tier) in enumerate(spots):
        r = 3.6 + (k % 3) * 1.1
        M.blob(LEAF, (r * 1.2, r, r * 0.8), sub=1, jit=0.14, flat=0.3, loc=(sx * x, y, tier * TH + r * 0.4), seed=30 + k)
    M.blob(LEAF, (6.5, 6.0, 5.0), sub=2, jit=0.12, flat=0.4, loc=(21.5, -31.5, 5 * TH + 4.0), seed=50)     # crown of the root tree
    M.blob(LEAF, (6.0, 6.5, 4.6), sub=2, jit=0.12, flat=0.4, loc=(-14.5, 20.5, TOP + 3.6), seed=51)
    M.anchors["ShrineDoor"] = (0, (CY + 2.0 - 9.0) * SY, (TOP + 1.0) * SZ)
    M.anchors["TunnelFront"] = (0, (yf1 - 2.0) * SY, 0)
    M.anchors["TunnelBack"] = (0, (yb1 + 1.0) * SY, 0)
    M.notes = ("Ground-level tunnel straight through, front to back: %.1f wide x %.1f high clear, %.0f long. "
               "Stairs: two side flights (%.1f wide, 12 steps) beside the gate up to the landing at Z %.1f, then a central flight "
               "(%.1f wide, 12 steps) to the top platform at Z %.1f; steps %.2f high x %.2f deep (add invisible ramps). "
               "Shrine doorway about 9 wide x 9.4 high."
               % ((2 * TW - 0.8) * SX, TUN_H * SZ, (yb1 + 1.0 - yf1 + 2.0) * SY, 10.0 * SX, Z3 * SZ, STAIR_W * SX, TOP * SZ,
                  dz * SZ, dy * SY))
    M.ref_pos = (16.0, -64.0)
    M.view_dir = (0.75, -1.4, 0.7)
    return M


if __name__ == "__main__":
    run(build)
