"""Plains_1_Windmill - stone-and-timber windmill, faceted roof, 4 lattice blades (separate objects)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fyd_common import *

STONE, STONE_D = "Common_Stone", "Common_StoneDark"
WALL, TIMBER, ROOF, WOOD = "Hub_Wall", "Hub_Timber", "Hub_Roof", "Common_Wood"
B_WOOD, B_CLOTH = "Blades:Common_Wood", "Blades:Common_Cloth"
C8 = math.cos(math.radians(22.5))


def r_at(z):
    if z <= 18:
        return lerp(12.4, 10.4, (z - 2) / 16.0)
    return lerp(9.9, 7.4, (z - 18) / 30.0)


def edge(i, z, extra=0.0):
    return polar(r_at(z) + extra, -67.5 + 45 * i, z)


def blade(M):
    """One blade pointing +Z from the hub centre, in the XZ plane (front = -Y)."""
    L = 28.0
    M.box(B_WOOD, (0.9, 0.9, L), loc=(0, 0, 0.5), base=True, taper=0.7)       # spar
    x0, x1, z0, z1 = 0.45, 6.4, 6.0, 27.0
    M.box(B_WOOD, (0.5, 0.5, z1 - z0), loc=(x1, 0, z0), base=True)            # outer rail
    M.box(B_WOOD, (0.4, 0.4, z1 - z0), loc=((x0 + x1) / 2, 0, z0), base=True)  # middle rail
    for k in range(6):
        z = lerp(z0, z1, k / 5.0)
        M.box(B_WOOD, (x1 - x0 + 0.5, 0.45, 0.45), loc=((x0 + x1) / 2, 0, z))
    # cloth: two panels, the outer one torn shorter
    M.slab(B_CLOTH, [(x0 + 0.3, 0.32, z0 + 0.4), ((x0 + x1) / 2, 0.32, z0 + 0.4),
                     ((x0 + x1) / 2, 0.32, z1 - 0.4), (x0 + 0.3, 0.32, z1 - 0.4)], 0.22)
    M.slab(B_CLOTH, [((x0 + x1) / 2, 0.32, z0 + 4.6), (x1 - 0.2, 0.32, z0 + 4.6),
                     (x1 - 0.2, 0.32, z1 - 0.4), ((x0 + x1) / 2, 0.32, z1 - 0.4)], 0.22)


def build():
    M = Model("Plains_1_Windmill", target=(40, 40, 72), seed=21)
    S = 0.966                      # overall scale so the model is 72 tall
    M.stack[0] = TRS(scale=S)
    # --- base platform + steps -------------------------------------------------------------
    M.rings(STONE_D, [(0, 16.0), (1.0, 15.6)], n=8)
    M.rings(STONE, [(1.0, 14.6), (2.0, 14.2)], n=8)
    M.box(STONE, (9.0, 4.0, 1.0), loc=(0, -15.2, 0), base=True)
    M.box(STONE_D, (11.0, 3.0, 0.5), loc=(0, -17.0, 0), base=True)
    # --- stone lower tower -----------------------------------------------------------------
    M.rings(STONE, [(2, r_at(2)), (18, r_at(18))], n=8)
    M.rings(STONE_D, [(2, r_at(2) + 0.7), (3.6, r_at(3.6) + 0.5)], n=8)            # plinth course
    rng = random.Random(5)
    for i in range(8):                                                              # protruding bricks
        for _ in range(3):
            z = rng.uniform(5.0, 15.5)
            t = rng.uniform(0.18, 0.82)
            if i == 0 and z < 12:
                continue
            a, b = edge(i, z), edge(i + 1, z)
            p = a.lerp(b, t)
            M.box(STONE_D, (2.6, 1.0, 1.3), loc=tuple(p * 0.985), rot=(0, 0, -90 + 45 * i + 22.5 - 22.5))
    # --- upper wall + timber frame ----------------------------------------------------------
    M.rings(WALL, [(18, r_at(18.01)), (48, r_at(48))], n=8)
    for z, h, ex in ((17.6, 1.2, 0.75), (32.0, 0.9, 0.35), (47.2, 1.0, 0.45)):
        zz = max(z, 18.02)
        M.rings(TIMBER, [(z, r_at(zz) + ex), (z + h, r_at(zz + h) + ex)], n=8)
    for i in range(8):
        M.tube(TIMBER, [edge(i, 18.2, 0.1), edge(i, 47.6, 0.1)], 0.55, n=4)
        # diagonal braces (alternate direction per face)
        j0, j1 = (i, i + 1) if i % 2 == 0 else (i + 1, i)
        M.tube(TIMBER, [edge(j0, 18.8, -0.12), edge(j1, 31.8, -0.12)], 0.38, n=4)
        M.tube(TIMBER, [edge(j1, 33.0, -0.12), edge(j0, 46.8, -0.12)], 0.38, n=4)
    # --- gallery (balcony) ------------------------------------------------------------------
    M.rings(WOOD, [(17.0, 14.2), (17.8, 14.4)], n=8)
    for i in range(8):
        a = -67.5 + 45 * i
        M.tube(WOOD, [polar(r_at(13.5) - 0.3, a, 13.0), polar(13.6, a, 17.0)], 0.5, n=4)    # struts
        M.box(WOOD, (0.6, 0.6, 3.4), loc=tuple(polar(13.9, a, 17.8)), rot=(0, 0, a), base=True)
        p, q = polar(13.9, a, 20.9), polar(13.9, a + 45, 20.9)
        M.tube(WOOD, [p, q], 0.32, n=4)
        M.tube(WOOD, [p - V(0, 0, 1.5), q - V(0, 0, 1.5)], 0.22, n=4)
    # --- door, windows ---------------------------------------------------------------------
    yf = -r_at(6) * C8
    M.box(TIMBER, (6.6, 2.0, 9.6), loc=(0, yf + 0.3, 2.0), base=True)
    M.box(WOOD, (4.6, 2.4, 8.2), loc=(0, yf + 0.3, 2.0), base=True)
    M.box(TIMBER, (0.5, 2.6, 8.2), loc=(0, yf + 0.3, 2.0), base=True)
    M.box(STONE_D, (8.0, 2.4, 1.2), loc=(0, yf + 0.2, 11.4), base=True, taper=(0.86, 1))  # lintel
    for i, z in ((0, 25.0), (2, 25.0), (6, 25.0), (0, 39.0), (4, 30.0)):
        a = -90 + 45 * i
        rr = r_at(z) * C8
        with M.xf(loc=tuple(polar(rr, a, z)), rot=(0, 0, a + 90)):
            M.box(TIMBER, (3.6, 1.2, 4.6), loc=(0, 0, 0))
            M.box(STONE_D, (2.4, 1.5, 3.4), loc=(0, 0, 0))
            M.box(TIMBER, (4.2, 1.6, 0.5), loc=(0, -0.2, -2.5))
    # --- cap + roof ------------------------------------------------------------------------
    M.rings(WOOD, [(48.0, 8.4), (50.0, 8.8)], n=8)
    M.rings(ROOF, [(50.0, 10.6), (51.0, 10.2), (57.0, 6.2), (65.5, 0)], n=8)
    M.rings(WOOD, [(64.2, 0.7), (67.4, 0.5), (68.6, 0)], n=4)                      # finial
    # dormer where the axle leaves the cap
    hub_y, hub_z = -11.6, 50.5
    M.box(WOOD, (4.4, 5.0, 4.4), loc=(0, -8.2, hub_z))
    M.extrude(ROOF, [(-3.0, 2.2), (3.0, 2.2), (0, 5.0)], 6.0, loc=(0, -8.0, hub_z))
    # tail pole at the back (classic post-mill steering beam)
    M.tube(WOOD, [(0, 8.0, 49.0), (0, 14.5, 36.0), (0, 16.5, 21.5)], [0.6, 0.5, 0.4], n=4)
    # --- blades (own objects, rotate about the Y axis through the hub anchor) ----------------
    with M.xf(loc=(0, hub_y, hub_z)):
        M.rings(B_WOOD, [(0, 1.5), (2.2, 1.7), (3.0, 1.2), (4.0, 0)], n=8, rot=(90, 0, 0), loc=(0, 1.6, 0))
        M.tube(B_WOOD, [(0, 1.6, 0), (0, 4.5, 0)], 0.8, n=6)                        # axle
        for k in range(4):
            with M.xf(rot=(0, 45 + 90 * k, 0)):
                blade(M)
    M.anchors["BladesHub"] = (0, hub_y * S, hub_z * S)
    M.notes = "Blades rotate about the Blender Y axis (Studio Z axis) through the BladesHub anchor."
    M.ref_pos = (9.0, -19.5)
    return M


if __name__ == "__main__":
    run(build)
