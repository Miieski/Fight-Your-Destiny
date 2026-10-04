"""Desert_3_StoneBridge - giant stone bridge: flat 24-wide walkable deck at Z = 50, big arch, thick strata abutments."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

RED, LIGHT, DARK = "Desert_CanyonRed", "Desert_CanyonLight", "Desert_CanyonDark"
STONE, STONE_D, SAND = "Desert_Sandstone", "Desert_SandstoneDark", "Desert_Sand"
C4 = math.cos(math.radians(45.0))
W_IN, H_IN, HALF = 40.0, 38.0, 75.0
DECK_Z = 50.0


def w_in(z):
    if z >= H_IN:
        return 0.0
    return W_IN * math.sqrt(max(0.0, 1.0 - (z / H_IN) ** 2.5))


def build():
    M = Model("Desert_3_StoneBridge", target=(150, 30, 60), seed=81)
    # --- abutments: stacked strata, flat outer ends (they butt against the canyon walls) ----------
    zs = [0, 6, 11, 17, 22, 28, 32, 35.5, 38]
    cols = [DARK, RED, LIGHT, RED, DARK, RED, LIGHT, RED]
    grow = [1.04, 0.97, 1.03, 0.96, 1.03, 0.97, 1.02, 0.97]
    for i, (z0, z1) in enumerate(zip(zs[:-1], zs[1:])):
        for side in (-1, 1):
            secs = []
            for z in (z0, z1):
                half = (HALF - w_in(z)) / 2.0
                dy = lerp(14.3, 13.3, z / H_IN) * grow[i]
                secs.append((z, half / C4, dy / C4, side * (w_in(z) + half), 0.0))
            M.rings(cols[i], secs, n=4, jit=0.02, seed=100 + 2 * i + side)
    # --- rock span above the arch -------------------------------------------------------------------
    M.box(DARK, (150.0, 27.4, 4.0), loc=(0, 0, 38.0), base=True, taper=(1.0, 0.97))
    M.box(LIGHT, (150.0, 26.2, 2.6), loc=(0, 0, 42.0), base=True)
    M.box(RED, (150.0, 27.0, 2.0), loc=(0, 0, 44.6), base=True)
    # --- masonry arch ring on both faces (ancient builders reinforced the natural arch) ---------------
    az = [0, 9, 17, 24, 29.5, 33.5, 36.3, 38.2]
    path = [(-w_in(z) + 0.2, z) for z in az[:-1]] + [(0.0, az[-1])] + [(w_in(z) - 0.2, z) for z in reversed(az[:-1])]
    for sy in (-1, 1):
        M.tube(STONE_D, [(x, sy * 13.3, z) for x, z in path], 1.8, n=4, up=(0, 1, 0))
        M.block(STONE, (5.0, 2.6, 6.0), loc=(0, sy * 14.0, 39.2), chamfer=0.15, taper=1.25, seed=7)      # keystone
    # --- deck: one flat slab, top exactly at Z = 50 ----------------------------------------------------
    M.box(STONE, (150.0, 28.0, 3.4), loc=(0, 0, DECK_Z - 3.4), base=True)
    M.box(STONE_D, (150.0, 29.0, 1.0), loc=(0, 0, DECK_Z - 4.2), base=True)                               # cornice
    for k in range(-7, 8):                                                                                # corbels
        for sy in (-1, 1):
            M.box(STONE_D, (2.4, 1.6, 2.0), loc=(k * 10.0, sy * 14.4, DECK_Z - 6.0), base=True, taper=(1.0, 1.0))
    # --- parapets (y = 12..14 on both sides, 24 clear between them) with gaps and broken pieces --------
    segs = {-1: [(-75, -59, 3.0), (-53, -36, 3.0), (-30, -19, 1.6), (-9, 9, 3.0), (15, 33, 3.0), (47, 58, 2.0), (62, 75, 3.0)],
            1: [(-75, -62, 3.0), (-50, -31, 3.0), (-25, -6, 3.0), (2, 12, 1.4), (20, 40, 3.0), (46, 63, 3.0), (69, 75, 3.0)]}
    for sy, lst in segs.items():
        for (x0, x1, h) in lst:
            M.box(STONE, (x1 - x0, 2.0, h), loc=((x0 + x1) / 2.0, sy * 13.0, DECK_Z), base=True)
            if h >= 3.0:
                M.box(STONE_D, (x1 - x0 + 0.4, 2.5, 0.7), loc=((x0 + x1) / 2.0, sy * 13.0, DECK_Z + h), base=True)
                for x in (x0 + 1.3, x1 - 1.3):
                    if abs(x) < 73:
                        M.box(STONE_D, (2.6, 2.8, 4.6), loc=(x, sy * 13.0, DECK_Z), base=True, taper=0.85)
    # --- end pylons (obelisks) at the four corners; one is broken --------------------------------------
    for sx in (-1, 1):
        for sy in (-1, 1):
            broken = (sx == 1 and sy == -1)
            with M.xf(loc=(sx * 71.0, sy * 12.9, DECK_Z)):
                M.box(STONE_D, (4.2, 4.2, 1.6), base=True)
                if broken:
                    M.rings(STONE, [(1.6, 2.4), (5.6, 2.15), (7.0, 0, 0, 0.7, 0.4)], n=4)
                else:
                    M.rings(STONE, [(1.6, 2.4), (8.0, 1.9), (8.0, 2.3), (8.6, 2.3), (8.6, 1.7), (10.0, 0)], n=4)
                    M.box(STONE_D, (0.5, 3.0, 3.0), loc=(-sx * 1.5, 0, 4.6))
    M.chunk(STONE, (60.5, -11.4, DECK_Z + 0.9), (64.5, -10.6, DECK_Z + 0.9), 0.9, 0.7, n=4, jit=0.05, seed=3)   # fallen tip
    # --- sand drifts hugging the abutment feet (kept inside the 30-stud depth, outside the passage) -------
    for (x, y, rx, ry, s) in ((-52, -12.6, 9, 3.0, 21), (64, -12.8, 8, 2.8, 22), (50, 12.6, 9, 3.0, 23), (-65, 12.8, 8, 2.8, 24)):
        M.blob(SAND, (rx, ry, 3.0), sub=2, jit=0.06, flat=0.05, loc=(x, y, 0.1), seed=s)
    M.anchors["DeckCenterTop"] = (0, 0, DECK_Z)
    M.notes = "Deck top is flat at Z = 50 (Studio Y = 50 above the model bottom); walkway 24 wide between the parapets."
    M.ref_pos = (10.0, -6.0)
    M.view_dir = (0.6, -1.5, 0.55)
    return M


if __name__ == "__main__":
    run(build)
