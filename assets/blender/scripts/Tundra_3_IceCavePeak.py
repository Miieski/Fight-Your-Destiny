"""Tundra_3_IceCavePeak - jagged snowy peak with a giant ice cave mouth at its base (real recess, flat back side)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

ROCK, ROCK_D, SNOW, SHADE = "Tundra_Rock", "Tundra_RockDark", "Tundra_Snow", "Tundra_SnowShade"
ICE, ICE_D, DARK = "Tundra_Ice", "Tundra_IceDeep", "Tundra_IceDark"
YB = 40.0            # flat back
CW = 17.0            # cave half width  (opening 34 wide)
CH = 31.0            # cave height      (26 clear under the middle icicles)
CAVE_BACK = 8.0      # y of the cave's back wall


def P(a_deg, z, rx, ry, cx, j=1.0):
    a = math.radians(a_deg)
    return (cx + rx * math.cos(a) * j, YB + ry * math.sin(a) * j, z)


def dring(z, rx, ry, cx, J):
    n = len(J)
    return [P(180.0 + 180.0 * i / (n - 1), z, rx, ry, cx, J[i]) for i in range(n)]


def front_y(x, rx, ry, cx):
    return YB - ry * math.sqrt(max(0.0, 1.0 - ((x - cx) / rx) ** 2))


def build():
    M = Model("Tundra_3_IceCavePeak", target=(130, 80, 110), seed=221)
    rng = random.Random(5)
    low = [(0.0, 64.0, 76.0, 0.0), (CH, 51.0, 58.0, 2.0)]
    # --- lower band: two rock masses, the cave is the gap between them ------------------------------------
    for side in (-1, 1):
        J = [1.0] + [1.0 + rng.uniform(-0.07, 0.07) for _ in range(4)]
        rings = []
        for (z, rx, ry, cx) in low:
            c = (side * CW - cx) / rx
            a0 = 360.0 - math.degrees(math.acos(c))
            a_end = 180.0 if side < 0 else 360.0
            ring = [(side * CW, YB, z)] + [P(a0 + (a_end - a0) * i / 4.0, z, rx, ry, cx, J[i]) for i in range(5)]
            rings.append(ring)
        M.loft(ROCK, rings)
        # dark strata outcrops on the mass
        for k in range(3):
            a = (205 + k * 22) if side < 0 else (335 - k * 22)
            p = Vector(P(a, 6 + k * 7, 60 - k * 4, 71 - k * 5, 0))
            M.block(ROCK_D, (15, 9, 6), loc=tuple(p), rot=(0, 0, a + 90), chamfer=0.25, jit=0.06, seed=30 + k + side)
    # --- cave lining (dark blue), back wall and ceiling -------------------------------------------------------
    fy0, fy1 = front_y(CW, 64, 76, 0), front_y(CW, 51, 58, 2)
    for side in (-1, 1):
        M.extrude(DARK, [(fy0 + 1.0, 0), (CAVE_BACK, 0), (CAVE_BACK, CH), (fy1 + 1.0, CH)], 1.0, axis="X", loc=(side * (CW - 0.4), 0, 0))
    M.box(DARK, (2 * CW + 1, 2.0, CH), loc=(0, CAVE_BACK + 0.5, 0), base=True)
    M.box(DARK, (2 * CW + 1, CAVE_BACK - fy1 + 1.5, 1.2), loc=(0, (CAVE_BACK + fy1) / 2.0, CH - 0.9), base=True)
    M.block(ICE_D, (9, 6, 12), loc=(-9.5, CAVE_BACK - 3, 0), base=True, chamfer=0.25, taper=0.5, seed=3)     # ice lumps inside
    M.block(ICE_D, (7, 5, 8), loc=(10.5, CAVE_BACK - 2.5, 0), base=True, chamfer=0.25, taper=0.5, seed=4)
    # --- brow + giant icicle teeth over the mouth -----------------------------------------------------------------
    M.block(ROCK_D, (2 * CW + 12, 7, 5.5), loc=(1, fy1 + 1.5, CH + 2.2), chamfer=0.3, jit=0.04, seed=5)
    M.block(SNOW, (2 * CW + 9, 7.5, 2.4), loc=(1, fy1 + 2.0, CH + 5.4), chamfer=0.3, jit=0.04, seed=6)
    teeth = [(-15.0, 11.0, 2.5), (-11.4, 7.5, 2.1), (-7.6, 4.8, 1.8), (-3.8, 3.6, 1.6), (0.0, 4.4, 1.8), (3.8, 3.4, 1.6),
             (7.6, 5.0, 1.9), (11.4, 8.0, 2.2), (15.0, 11.5, 2.6)]
    for i, (x, h, r) in enumerate(teeth):
        M.icicle(ICE if i % 2 == 0 else ICE_D, (x, fy1 + 0.6, CH + 0.3), r, h, n=5)
    for side in (-1, 1):                                                                      # rounded top corners
        M.hull(ICE_D, [(side * CW, fy1 - 1.5, CH), (side * CW, fy1 + 3.5, CH), (side * CW, fy1 - 1.5 - 3.0, CH - 9),
                       (side * CW, fy1 + 3.5 - 3.0, CH - 9), (side * (CW - 8), fy1 - 1.5, CH), (side * (CW - 8), fy1 + 3.5, CH)])
        for k, (dx, h) in enumerate(((5.0, 9.0), (9.5, 6.0))):                                # ice stalagmites beside the mouth
            M.spike(ICE if k else ICE_D, (side * (CW + dx), fy0 - 2.0 + k * 3.0, 0), 2.4 - 0.5 * k, h, n=5)
    # --- upper mountain: rock band, snow ledge, snowy summit ------------------------------------------------------
    J = [1.0 + rng.uniform(-0.09, 0.09) for _ in range(9)]
    M.loft(SNOW, [dring(CH, 50.0, 56.0, 2.0, J), dring(CH + 2.6, 48.0, 54.0, 2.0, J)])                        # snow ledge
    M.loft(ROCK, [dring(CH, 46.0, 52.0, 2.0, J), dring(56.0, 36.0, 41.0, 5.0, J)])
    J2 = [1.0 + rng.uniform(-0.1, 0.1) for _ in range(9)]
    M.loft(SNOW, [dring(55.0, 38.5, 44.0, 5.0, J2), dring(57.0, 36.0, 41.0, 5.0, J2), dring(79.0, 22.0, 26.0, 8.0, J2),
                  dring(97.0, 10.5, 13.0, 7.0, J2), [(6.0, YB - 5.0, 110.0)]])
    # jagged side peaks and rock fins
    for (cx, cy, r, z1, z2, zt, seed) in ((-39, YB - 21, 20, 50, 60, 74, 11), (41, YB - 19, 18, 45, 52, 63, 12),
                                          (-58, YB - 14, 12, 38, 42, 50, 13)):
        M.rings(ROCK, [(CH - 4, r, r * 0.9, cx, cy), (z1, r * 0.62, r * 0.56, cx + 1, cy + 1)], n=7, jit=0.12, seed=seed)
        M.rings(SNOW, [(z1 - 1, r * 0.68, r * 0.62, cx + 1, cy + 1), (z2, r * 0.4, r * 0.36, cx + 1.5, cy + 2),
                       (zt, 0, 0, cx + 2, cy + 3)], n=7, jit=0.12, seed=seed)
    M.chunk(ROCK_D, (24, YB - 30, 52), (33, YB - 18, 72), 6.5, 2.0, n=5, jit=0.15, seed=14)
    M.chunk(ROCK_D, (-16, YB - 34, 50), (-22, YB - 22, 66), 6.0, 2.0, n=5, jit=0.15, seed=15)
    # snow drifts at the foot
    for i, (x, y, rx, ry) in enumerate(((-44, -22, 13, 7), (45, -20, 12, 7), (-27, -31, 8, 5), (29, -30, 8, 5), (-59, 10, 5, 11),
                                        (59, 12, 5, 11))):
        M.blob(SHADE if i % 2 else SNOW, (rx, ry, 4.0), sub=2, jit=0.07, flat=0.08, loc=(x, y, 0.3), seed=40 + i)
    M.anchors["CaveMouthFloor"] = (0, fy0, 0)
    M.notes = ("Cave: real recess %.0f wide x %.0f high x %.0f deep, 26 clear under the middle icicles; back side flat."
               % (2 * CW - 1, CH - 1, CAVE_BACK - fy0))
    M.ref_pos = (24.0, -40.0)
    M.view_dir = (0.55, -1.5, 0.45)
    return M


if __name__ == "__main__":
    run(build)
