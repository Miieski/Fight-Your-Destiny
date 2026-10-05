"""Part B icons: 12 zone dioramas and 48 sub-zone dioramas (docs/ui_redo_teleport_brief.txt part 2).
Every icon is a small floating island in its zone's palette with the landmark of
docs/zone_design_document.txt on top. Same template as every other icon (fyd_icons)."""
import math

import fyd_icons as I
from fyd_icon_recipes import (M, black, blue, cream, cyan, gold, gold_deep, green, leather_dark, pink, purple, red,
                              red_dark, steel, steel_dark, white, wood, wood_dark)
from fyd_icon_recipes2 import pose_all

G = 0.1  # ground height on top of an island
TILT = 14  # degrees the whole diorama leans towards the camera so its top reads

PAL = {
    "Plains": ("#6CCB46", "#8B5A2B"), "Desert": ("#F0C46A", "#C98A4A"), "Jungle": ("#3DAA45", "#6B4A2A"),
    "Tundra": ("#F2F8FF", "#8FB3D9"), "Swamp": ("#5E7A3A", "#4A3A2A"), "Volcano": ("#4A3B38", "#2C2220"),
    "Hell": ("#8A2A22", "#4A1410"), "Heaven": ("#FFFFFF", "#D8E4FF"), "Dead": ("#55525F", "#2E2C36"),
    "Abyss": ("#E6D29A", "#2C5D8A"), "Mechanical": ("#7D8590", "#4B525C"), "Void": ("#2E2242", "#1A1226"),
}


# materials ----------------------------------------------------------------------------------------------
def lava():
    return M("Lava", "#FF6A1F", rough=0.3, coat=0.3, emit=2.2, emit_color="#FF5200")


def water():
    return M("Water", "#3FA6F0", rough=0.08, coat=1.0)


def ice():
    return M("Ice", "#BFE8FF", rough=0.08, coat=1.0, emit=0.1)


def stone():
    return M("Stone2", "#9A958C", rough=0.6, coat=0.2)


def stone_dark():
    return M("StoneDark2", "#5E5A55", rough=0.65, coat=0.15)


def sand_stone():
    return M("SandStone", "#E2B66A", rough=0.6, coat=0.2)


def pyramid_stone():
    return M("PyramidStone", "#C98B3E", rough=0.6, coat=0.2)


def red_rock():
    return M("RedRock", "#C8603A", rough=0.6, coat=0.2)


def leaf():
    return M("Leaf", "#3FBF4A", rough=0.45, coat=0.4)


def leaf_dark():
    return M("LeafDark", "#2A8F3A", rough=0.45, coat=0.4)


def bone():
    return M("Bone2", "#EFE6CC", rough=0.45, coat=0.5)


def void_crystal():
    return M("VoidCrystal", "#B05BFF", rough=0.1, coat=1.0, emit=1.3, emit_color="#9B3BFF")


def slime():
    return M("Slime", "#7CFF4A", rough=0.15, coat=1.0, emit=0.8, emit_color="#5CE020")


def holo():
    return M("Holo", "#3FE6FF", rough=0.1, coat=0.6, emit=1.6, emit_color="#25D8FF")


def metal():
    return M("Metal", "#A7B0BC", metal=0.7, rough=0.35, coat=0.4)


def rust():
    return M("Rust", "#B5562A", metal=0.3, rough=0.6, coat=0.2)


def hazard():
    return M("Hazard", "#FFC21F", rough=0.4, coat=0.5)


def obsidian():
    return M("Obsidian", "#2A1E3D", rough=0.2, coat=0.8)


# building blocks ------------------------------------------------------------------------------------------
def island(zone, r=1.0):
    top, side = PAL[zone]
    I.cyl(r, 0.2, M(zone + "Top", top, rough=0.6, coat=0.25), segs=40, loc=(0, 0, 0), bevel=0.06, name="IslandTop")
    I.cyl(r * 0.32, 0.55, M(zone + "Side", side, rough=0.7, coat=0.15), r2=r * 0.96, segs=40, loc=(0, 0, -0.375),
          bevel=0.03, name="IslandSide")


def finish():
    pose_all(I.empty("Diorama", rot=(TILT, 0, 0)))


def trunk_tree(x, y, s=1.0, leaves=None, bark=None):
    I.cyl(0.08 * s, 0.5 * s, bark or wood(), segs=10, loc=(x, y, G + 0.25 * s), bevel=0.0)
    lf = leaves or leaf()
    I.sphere(0.32 * s, lf, loc=(x, y, G + 0.66 * s))
    I.sphere(0.24 * s, lf, loc=(x + 0.17 * s, y - 0.06 * s, G + 0.5 * s))
    I.sphere(0.22 * s, lf, loc=(x - 0.17 * s, y + 0.03 * s, G + 0.52 * s))


def pine(x, y, s=1.0, leaves=None, snow=False):
    I.cyl(0.06 * s, 0.25 * s, wood_dark(), segs=8, loc=(x, y, G + 0.12 * s), bevel=0.0)
    lf = leaves or leaf_dark()
    for i in range(3):
        r = (0.32 - 0.08 * i) * s
        z = G + (0.32 + 0.22 * i) * s
        I.cyl(r, 0.36 * s, lf, r2=0.0, segs=12, loc=(x, y, z), bevel=0.0, smooth=False)
        if snow:
            I.cyl(r * 0.55, 0.16 * s, white(), r2=0.0, segs=12, loc=(x, y, z + 0.1 * s), bevel=0.0, smooth=False)


def dead_tree(x, y, s=1.0, bark=None):
    b = bark or M("DeadWood", "#5A4636", rough=0.7, coat=0.1)
    I.tube([(x, y, G), (x + 0.04 * s, y, G + 0.5 * s), (x - 0.05 * s, y, G + 0.9 * s)], [0.09 * s, 0.07 * s, 0.04 * s], b, segs=8)
    I.tube([(x + 0.02 * s, y, G + 0.5 * s), (x + 0.3 * s, y, G + 0.75 * s), (x + 0.38 * s, y, G + 0.95 * s)], [0.05 * s, 0.035 * s, 0.02 * s], b, segs=8)
    I.tube([(x - 0.02 * s, y, G + 0.65 * s), (x - 0.28 * s, y, G + 0.85 * s)], [0.04 * s, 0.02 * s], b, segs=8)


def palm(x, y, s=1.0):
    top = (x + 0.15 * s, y, G + 0.85 * s)
    I.tube([(x, y, G), (x + 0.08 * s, y, G + 0.45 * s), top], [0.07 * s, 0.06 * s, 0.05 * s], wood(), segs=10)
    for k in range(6):
        a = math.radians(60 * k + 15)
        I.box(0.5 * s, 0.13 * s, 0.03 * s, leaf(), loc=(top[0] + math.cos(a) * 0.22 * s, top[1] + math.sin(a) * 0.22 * s, top[2] - 0.05 * s),
              rot=(0, 22, 60 * k + 15), bevel=0.01)
    I.sphere(0.06 * s, wood_dark(), loc=(top[0], top[1] - 0.05 * s, top[2] - 0.06 * s))


def rock(x, y, s=1.0, m=None):
    I.ico(0.25 * s, m or stone(), subdiv=1, loc=(x, y, G + 0.08 * s), scale=(1.0, 0.9, 0.7))


def water_pool(r, x=0.0, y=0.0, m=None):
    I.cyl(r, 0.05, m or water(), segs=32, loc=(x, y, G + 0.01), bevel=0.0)


def crystal(x, y, s=1.0, m=None, tilt=0.0):
    root = I.empty("Crystal", loc=(x, y, G), rot=(0, tilt, 0))
    mat = m or void_crystal()
    I.cyl(0.12 * s, 0.45 * s, mat, segs=6, loc=(0, 0, 0.22 * s), bevel=0.0, smooth=False, parent=root)
    I.cyl(0.12 * s, 0.22 * s, mat, r2=0.0, segs=6, loc=(0, 0, 0.56 * s), bevel=0.0, smooth=False, parent=root)
    return root


def cloud(x, y, z, s=1.0, m=None):
    c = m or white()
    for dx, dz, r in ((0, 0, 0.22), (0.2, -0.03, 0.17), (-0.2, -0.04, 0.16), (0.08, 0.1, 0.15)):
        I.sphere(r * s, c, loc=(x + dx * s, y, z + dz * s))


def torch(x, y, s=1.0):
    I.cyl(0.03 * s, 0.4 * s, wood_dark(), segs=8, loc=(x, y, G + 0.2 * s), bevel=0.0)
    I.sphere(0.07 * s, lava(), loc=(x, y, G + 0.44 * s), scale=(1, 1, 1.4))


def tower(x, y, r, h, wall, roof, roof_h=None):
    I.cyl(r, h, wall, segs=20, loc=(x, y, G + h / 2), bevel=0.02)
    I.cyl(r * 1.25, roof_h or r * 2.2, roof, r2=0.0, segs=20, loc=(x, y, G + h + (roof_h or r * 2.2) / 2), bevel=0.0)


def arch(x, y, s, m, w=0.8, h=0.9, t=0.14):
    """Pointed/round arch: two pillars and a half torus on top, facing the camera."""
    for side in (-1, 1):
        I.box(t * s, t * s, h * s, m, loc=(x + side * w / 2 * s, y, G + h / 2 * s), bevel=0.02)
    I.torus(w / 2 * s, t / 2 * s, m, arc=180, rsegs=10, loc=(x, y, G + h * s), rot=(90, 0, 0))


def skull(x, y, z, s=1.0):
    b = bone()
    I.sphere(0.2 * s, b, loc=(x, y, z + 0.05 * s))
    I.box(0.22 * s, 0.18 * s, 0.12 * s, b, loc=(x, y - 0.03 * s, z - 0.1 * s), bevel=0.03 * s)
    for ex in (-0.07, 0.07):
        I.sphere(0.05 * s, black(), loc=(x + ex * s, y - 0.17 * s, z + 0.03 * s))


def tombstone(x, y, s=1.0, m=None):
    mat = m or stone()
    I.box(0.28 * s, 0.1 * s, 0.3 * s, mat, loc=(x, y, G + 0.15 * s), bevel=0.02)
    I.cyl(0.14 * s, 0.1 * s, mat, segs=16, loc=(x, y, G + 0.3 * s), rot=(90, 0, 0), bevel=0.01)
    I.box(0.04 * s, 0.02 * s, 0.14 * s, stone_dark(), loc=(x, y - 0.06 * s, G + 0.26 * s), bevel=0.0)
    I.box(0.11 * s, 0.02 * s, 0.035 * s, stone_dark(), loc=(x, y - 0.06 * s, G + 0.28 * s), bevel=0.0)


def gear(x, y, z, s=1.0, m=None, rot_y=0):
    root = I.empty("Gear", loc=(x, y, z), rot=(0, rot_y, 0), scale=s)
    mat = m or metal()
    I.cyl(0.36, 0.16, mat, segs=24, rot=(90, 0, 0), bevel=0.03, parent=root)
    for i in range(8):
        a = math.radians(45 * i)
        I.box(0.15, 0.15, 0.13, mat, loc=(0.4 * math.cos(a), 0, 0.4 * math.sin(a)), rot=(0, -45 * i, 0), bevel=0.02, parent=root)
    I.cyl(0.12, 0.2, steel_dark(), segs=16, rot=(90, 0, 0), bevel=0.02, parent=root)


def throne(x, y, s, seat, trim):
    I.box(0.6 * s, 0.45 * s, 0.25 * s, seat, loc=(x, y, G + 0.12 * s), bevel=0.04)
    I.box(0.6 * s, 0.12 * s, 0.9 * s, seat, loc=(x, y + 0.2 * s, G + 0.45 * s), bevel=0.04)
    for side in (-1, 1):
        I.box(0.1 * s, 0.45 * s, 0.4 * s, trim, loc=(x + side * 0.32 * s, y, G + 0.2 * s), bevel=0.03)
        I.sphere(0.07 * s, trim, loc=(x + side * 0.32 * s, y + 0.2 * s, G + 0.95 * s))


def boat_hull(x, y, s, m, sink=0.0, rot_z=0, tilt=0):
    root = I.empty("Boat", loc=(x, y, G - sink), rot=(tilt, 0, rot_z), scale=s)
    I.extrude([(-0.6, 0.25), (0.6, 0.25), (0.45, -0.05), (-0.45, -0.05)], 0.4, m, loc=(0, 0, 0.0), rot=(0, 0, 0), bevel=0.03,
              parent=root)
    I.cyl(0.03, 0.9, wood_dark(), segs=8, loc=(0.05, 0, 0.65), bevel=0.0, parent=root)
    I.extrude([(0, 0), (0.35, 0.05), (0.3, 0.55), (0, 0.6)], 0.03, white(), loc=(0.08, 0, 0.35), bevel=0.01, parent=root)
    return root


def hill(x, y, r, h, m):
    I.sphere(r, m, loc=(x, y, G - r * 0.45), scale=(1.0, 1.0, h / r))


def stepped_pyramid(x, y, s, m, steps=4, top=None):
    for i in range(steps):
        w = (1.0 - 0.2 * i) * s
        I.box(w, w, 0.2 * s, m, loc=(x, y, G + 0.1 * s + 0.2 * s * i), bevel=0.02)
    if top is not None:
        I.box(0.3 * s, 0.3 * s, 0.25 * s, top, loc=(x, y, G + 0.2 * s * steps + 0.12 * s), bevel=0.03)


def volcano_cone(x, y, s, body, rim=None):
    I.cyl(0.75 * s, 0.9 * s, body, r2=0.25 * s, segs=24, loc=(x, y, G + 0.45 * s), bevel=0.02, smooth=False)
    I.cyl(0.24 * s, 0.06 * s, rim or lava(), segs=24, loc=(x, y, G + 0.9 * s), bevel=0.0)


# =========================================================================================================
# ZONE ICONS (12)
# =========================================================================================================
def Z_Plains():
    island("Plains")
    hill(0.3, 0.2, 0.55, 0.5, M("PlainsTop", PAL["Plains"][0]))
    # windmill
    I.box(0.28, 0.28, 0.6, white(), loc=(0.3, 0.15, G + 0.45), bevel=0.03)
    I.cyl(0.24, 0.24, M("Roof", "#8E1A20", rough=0.6, coat=0.15), r2=0.0, segs=4, loc=(0.3, 0.15, G + 0.87), rot=(0, 0, 45), bevel=0.0, smooth=False)
    for a in (0, 90, 180, 270):
        I.box(0.07, 0.03, 0.5, wood(), loc=(0.3 + 0.25 * math.sin(math.radians(a)), -0.02, G + 0.68 + 0.25 * math.cos(math.radians(a))),
              rot=(0, a, 0), bevel=0.01)
    trunk_tree(-0.45, -0.1, 0.9)
    rock(-0.1, -0.55, 0.6)
    finish()


def Z_Desert():
    island("Desert")
    I.cyl(0.72, 0.75, pyramid_stone(), r2=0.0, segs=4, loc=(0.0, 0.1, G + 0.37), rot=(0, 0, 45), bevel=0.02, smooth=False)
    I.box(0.16, 0.05, 0.22, black(), loc=(-0.22, -0.32, G + 0.12), rot=(0, 0, -45), bevel=0.01)
    I.sphere(0.2, M("Sun", "#FFD23F", rough=0.3, coat=0.5, emit=1.0, emit_color="#FFB800"), loc=(0.62, 0.2, G + 1.05))
    palm(-0.62, -0.25, 0.7)
    finish()


def Z_Jungle():
    island("Jungle")
    stepped_pyramid(0.05, 0.1, 1.0, M("TempleStone", "#8FA08A", rough=0.6, coat=0.2), top=M("TempleTop", "#6E7F69"))
    for (x, y, z) in ((-0.42, -0.42, 0.3), (0.42, -0.42, 0.45), (0.05, -0.47, 0.7)):
        I.tube([(x, y, G + 0.05), (x + 0.05, y - 0.02, G + z * 0.5), (x - 0.03, y, G + z)], 0.035, leaf_dark(), segs=6)
    trunk_tree(-0.72, 0.1, 0.8)
    finish()


def Z_Tundra():
    island("Tundra")
    I.cyl(0.7, 1.0, M("Mountain", "#7E93AE", rough=0.5, coat=0.3), r2=0.05, segs=7, loc=(-0.1, 0.15, G + 0.5), bevel=0.0, smooth=False)
    I.cyl(0.3, 0.42, white(), r2=0.02, segs=7, loc=(-0.1, 0.15, G + 0.83), bevel=0.0, smooth=False)
    crystal(0.5, -0.3, 1.3, ice(), tilt=-12)
    pine(-0.62, -0.35, 0.7, snow=True)
    finish()


def cauldron(x, y, s, brew=None):
    I.lathe([(0.0, 0.0), (0.3, 0.02), (0.42, 0.2), (0.4, 0.38), (0.34, 0.45), (0.0, 0.45)], black(), segs=28,
            loc=(x, y, G), scale=(s, s, s))
    I.cyl(0.33 * s, 0.04, brew or slime(), segs=28, loc=(x, y, G + 0.44 * s), bevel=0.0)
    for dx in (-0.12, 0.1):
        I.sphere(0.06 * s, brew or slime(), loc=(x + dx * s, y, G + 0.5 * s))
    for side in (-1, 1):
        I.cyl(0.04 * s, 0.12 * s, black(), segs=8, loc=(x + side * 0.25 * s, y, G - 0.0), bevel=0.0)


def Z_Swamp():
    island("Swamp")
    water_pool(0.6, 0.2, -0.1, M("SwampWater", "#4E6B3A", rough=0.1, coat=1.0))
    cauldron(0.15, -0.05, 1.1)
    dead_tree(-0.5, 0.2, 1.0)
    finish()


def Z_Volcano():
    island("Volcano")
    volcano_cone(0.0, 0.1, 1.1, M("VolcanoRock", "#4B3B36", rough=0.6, coat=0.2))
    I.sphere(0.12, lava(), loc=(0.05, 0.1, G + 1.15))
    I.sphere(0.08, lava(), loc=(-0.12, 0.08, G + 1.28))
    I.tube([(0.1, -0.12, G + 0.98), (0.3, -0.3, G + 0.5), (0.45, -0.45, G + 0.05)], [0.07, 0.06, 0.05], lava(), segs=8)
    finish()


def horned_gate(x, y, s, wall, horn):
    I.box(1.0 * s, 0.35 * s, 0.75 * s, wall, loc=(x, y, G + 0.37 * s), bevel=0.04)
    I.box(0.34 * s, 0.38 * s, 0.42 * s, black(), loc=(x, y - 0.02 * s, G + 0.21 * s), bevel=0.02)
    for side in (-1, 1):
        I.tube([(x + side * 0.4 * s, y, G + 0.72 * s), (x + side * 0.6 * s, y, G + 1.0 * s), (x + side * 0.5 * s, y, G + 1.3 * s)],
               [0.1 * s, 0.07 * s, 0.02 * s], horn, segs=10)


def Z_Hell():
    island("Hell")
    water_pool(0.75, 0, -0.1, lava())
    horned_gate(0.0, 0.15, 1.0, M("HellWall", "#5A1612", rough=0.6, coat=0.2), bone())
    finish()


def Z_Heaven():
    island("Heaven")
    cloud(-0.55, -0.35, G + 0.05, 1.0)
    cloud(0.6, -0.3, G + 0.0, 0.8)
    arch(0.0, 0.1, 1.0, gold(), w=0.9, h=0.85, t=0.15)
    trunk_tree(0.55, 0.3, 0.7, leaves=M("LightLeaf", "#FFF3A8", rough=0.3, coat=0.6, emit=0.4, emit_color="#FFE070"))
    finish()


def crypt(x, y, s, wall, roof):
    I.box(0.8 * s, 0.6 * s, 0.6 * s, wall, loc=(x, y, G + 0.3 * s), bevel=0.03)
    I.cyl(0.62 * s, 0.4 * s, roof, r2=0.0, segs=4, loc=(x, y, G + 0.8 * s), rot=(0, 0, 45), bevel=0.0, smooth=False)
    I.box(0.26 * s, 0.05 * s, 0.38 * s, black(), loc=(x, y - 0.3 * s, G + 0.2 * s), bevel=0.01)
    I.cyl(0.13 * s, 0.05 * s, black(), segs=16, loc=(x, y - 0.3 * s, G + 0.39 * s), rot=(90, 0, 0), bevel=0.0)
    I.box(0.05 * s, 0.05 * s, 0.25 * s, gold(), loc=(x, y, G + 1.12 * s), bevel=0.0)
    I.box(0.15 * s, 0.05 * s, 0.05 * s, gold(), loc=(x, y, G + 1.17 * s), bevel=0.0)


def Z_Dead():
    island("Dead")
    crypt(0.1, 0.15, 1.0, M("CryptWall", "#7B7787", rough=0.6), M("CryptRoof", "#3E3A4A", rough=0.75, coat=0.05))
    tombstone(-0.55, -0.3, 1.2)
    tombstone(0.62, -0.35, 0.9)
    finish()


def coral(x, y, s, m):
    for (dx, h, tilt) in ((0, 0.5, 0), (0.12, 0.35, 25), (-0.12, 0.38, -25)):
        I.cyl(0.05 * s, h * s, m, r2=0.03 * s, segs=8, loc=(x + dx * s, y, G + h * s / 2), rot=(0, tilt, 0), bevel=0.0)
        I.sphere(0.06 * s, m, loc=(x + dx * s + math.sin(math.radians(tilt)) * h * s / 2, y, G + h * s))


def trident(x, y, s, m):
    I.cyl(0.04 * s, 1.3 * s, m, segs=10, loc=(x, y, G + 0.65 * s), bevel=0.0)
    I.box(0.4 * s, 0.06 * s, 0.06 * s, m, loc=(x, y, G + 1.2 * s), bevel=0.01)
    for dx in (-0.18, 0, 0.18):
        I.cyl(0.035 * s, 0.3 * s, m, r2=0.0, segs=8, loc=(x + dx * s, y, G + 1.36 * s), bevel=0.0)


def Z_Abyss():
    island("Abyss")
    coral(-0.45, 0.0, 1.2, pink())
    coral(0.5, 0.1, 1.0, M("CoralOrange", "#FF8A3D", rough=0.4, coat=0.6))
    trident(0.05, 0.05, 1.0, gold())
    for (x, z) in ((-0.2, 0.9), (0.3, 1.1), (-0.05, 1.3)):
        I.sphere(0.05, M("Bubble", "#CFF4FF", rough=0.05, coat=1.0), loc=(x, -0.2, G + z))
    finish()


def robot_head(x, y, z, s):
    I.box(0.6 * s, 0.5 * s, 0.5 * s, metal(), loc=(x, y, z), bevel=0.08 * s)
    for ex in (-0.14, 0.14):
        I.sphere(0.08 * s, holo(), loc=(x + ex * s, y - 0.25 * s, z + 0.05 * s))
    I.box(0.3 * s, 0.05 * s, 0.06 * s, black(), loc=(x, y - 0.25 * s, z - 0.12 * s), bevel=0.01)
    I.cyl(0.02 * s, 0.25 * s, steel_dark(), segs=6, loc=(x, y, z + 0.37 * s), bevel=0.0)
    I.sphere(0.05 * s, red(), loc=(x, y, z + 0.5 * s))


def Z_Mechanical():
    island("Mechanical")
    gear(-0.3, 0.2, G + 0.55, 1.2, m=rust())
    robot_head(0.35, -0.1, G + 0.3, 1.0)
    finish()


def Z_Void():
    island("Void")
    I.cyl(0.25, 0.55, obsidian(), r2=0.18, segs=6, loc=(0.0, 0.1, G + 0.28), bevel=0.02, smooth=False)
    crystal(0.0, 0.1, 1.5, tilt=0)
    for (x, y, z, s) in ((-0.6, -0.1, 0.5, 0.5), (0.65, 0.0, 0.8, 0.4)):
        I.ico(0.2 * s / 0.5, obsidian(), subdiv=1, loc=(x, y, G + z), scale=(1, 1, 0.6))
    crystal(-0.45, -0.35, 0.6, tilt=-15)
    finish()


ZONE_ICONS = {"Plains": Z_Plains, "Desert": Z_Desert, "Jungle": Z_Jungle, "Tundra": Z_Tundra, "Swamp": Z_Swamp,
              "Volcano": Z_Volcano, "Hell": Z_Hell, "Heaven": Z_Heaven, "Dead": Z_Dead, "Abyss": Z_Abyss,
              "Mechanical": Z_Mechanical, "Void": Z_Void}


# =========================================================================================================
# SUB-ZONE ICONS (48)
# =========================================================================================================
# ---- Plains
def Plains_1():
    island("Plains")
    hill(0.0, 0.15, 0.6, 0.45, M("PlainsTop", PAL["Plains"][0]))
    I.box(0.3, 0.3, 0.7, white(), loc=(0.0, 0.15, G + 0.5), bevel=0.03)
    I.cyl(0.26, 0.26, M("Roof", "#8E1A20", rough=0.6, coat=0.15), r2=0.0, segs=4, loc=(0.0, 0.15, G + 0.98), rot=(0, 0, 45), bevel=0.0, smooth=False)
    for a in (20, 110, 200, 290):
        I.box(0.08, 0.03, 0.62, wood(), loc=(0.31 * math.sin(math.radians(a)), -0.02, G + 0.75 + 0.31 * math.cos(math.radians(a))), rot=(0, a, 0), bevel=0.01)
    for (x, y) in ((-0.6, -0.4), (0.6, -0.35)):
        I.sphere(0.07, M("Flower", "#FFD84A", rough=0.4), loc=(x, y, G + 0.05))
    finish()


def Plains_2():
    island("Plains")
    I.cyl(0.98, 0.21, M("Beach", "#F2D48A", rough=0.6), segs=40, loc=(0.0, -0.05, 0.005), bevel=0.05)
    water_pool(0.55, 0.3, -0.25)
    boat_hull(0.3, -0.15, 0.85, wood_dark(), sink=0.08, rot_z=-20, tilt=-12)
    palm(-0.5, 0.15, 0.85)
    finish()


def Plains_3():
    island("Plains")
    I.tube([(0, 0.1, G), (0.05, 0.1, G + 0.5), (0.0, 0.1, G + 0.8)], [0.2, 0.15, 0.12], wood(), segs=12)
    for (dx, dz, r) in ((0, 1.05, 0.42), (0.32, 0.85, 0.3), (-0.32, 0.88, 0.3), (0.1, 1.3, 0.28)):
        I.sphere(r, leaf_dark(), loc=(dx, 0.1, G + dz))
    pine(-0.65, -0.3, 0.6)
    pine(0.65, -0.25, 0.55)
    finish()


def Plains_4():
    island("Plains")
    I.sphere(0.75, M("CaveRock", "#7C7A80", rough=0.7, coat=0.1), loc=(0.0, 0.2, G + 0.1), scale=(1.0, 0.85, 0.8), smooth=False)
    I.sphere(0.32, black(), loc=(0.0, -0.4, G + 0.15), scale=(1.0, 0.5, 1.1))
    torch(-0.45, -0.45, 1.0)
    torch(0.45, -0.45, 1.0)
    finish()


# ---- Desert
def Desert_1():
    island("Desert")
    for side in (-1, 1):
        I.box(0.22, 0.25, 0.75, red_rock(), loc=(side * 0.38, 0.1, G + 0.37), bevel=0.04, smooth=False)
    I.box(1.0, 0.27, 0.22, red_rock(), loc=(0.0, 0.1, G + 0.82), bevel=0.05, smooth=False)
    I.sphere(0.35, M("Dune", "#E8B85E", rough=0.6), loc=(0.55, -0.35, G - 0.15), scale=(1.4, 1.0, 0.6))
    finish()


def Desert_2():
    island("Desert")
    water_pool(0.5, 0.15, -0.1)
    I.lathe([(0.0, 0.0), (0.28, 0.0), (0.3, 0.25), (0.22, 0.27), (0.0, 0.2)], sand_stone(), segs=24, loc=(-0.3, -0.1, G))
    I.cyl(0.2, 0.03, water(), segs=20, loc=(-0.3, -0.1, G + 0.24), bevel=0.0)
    palm(0.45, 0.2, 0.8)
    finish()


def Desert_3():
    island("Desert")
    for side in (-1, 1):
        I.box(0.45, 0.8, 0.8, red_rock(), loc=(side * 0.55, 0.0, G + 0.4), bevel=0.06, smooth=False)
    I.box(0.7, 0.3, 0.12, sand_stone(), loc=(0.0, 0.0, G + 0.72), bevel=0.03)
    for x in (-0.25, 0.0, 0.25):
        I.box(0.06, 0.3, 0.08, stone_dark(), loc=(x, 0.0, G + 0.82), bevel=0.01)
    finish()


def Desert_4():
    island("Desert")
    I.cyl(0.8, 0.85, pyramid_stone(), r2=0.0, segs=4, loc=(0.0, 0.15, G + 0.42), rot=(0, 0, 45), bevel=0.02, smooth=False)
    I.box(0.3, 0.1, 0.32, black(), loc=(-0.28, -0.29, G + 0.16), rot=(0, 0, -45), bevel=0.02)
    torch(-0.62, -0.25, 0.9)
    torch(0.1, -0.68, 0.9)
    finish()


# ---- Jungle
def Jungle_1():
    island("Jungle")
    trunk_tree(0.05, 0.15, 1.6, leaves=leaf_dark())
    I.box(0.35, 0.04, 0.22, wood(), loc=(0.05, -0.05, G + 0.35), bevel=0.02)
    I.box(0.05, 0.05, 0.3, wood_dark(), loc=(0.05, -0.06, G + 0.15), bevel=0.0)
    trunk_tree(-0.6, -0.3, 0.6)
    finish()


def Jungle_2():
    island("Jungle")
    I.box(1.4, 0.45, 1.0, M("Cliff", "#6F7B66", rough=0.7), loc=(0.0, 0.35, G + 0.5), bevel=0.08, smooth=False)
    I.box(0.35, 0.06, 0.95, water(), loc=(0.0, 0.11, G + 0.5), bevel=0.02)
    water_pool(0.5, 0.0, -0.3)
    trunk_tree(-0.6, 0.0, 0.6)
    trunk_tree(0.62, 0.05, 0.55)
    finish()


def Jungle_3():
    island("Jungle")
    stepped_pyramid(0.0, 0.1, 1.2, M("TempleStone", "#8FA08A", rough=0.6, coat=0.2), steps=5, top=M("TempleTop", "#6E7F69"))
    I.box(0.18, 0.1, 0.25, black(), loc=(0.0, -0.5, G + 0.13), bevel=0.02)
    for (x, y, z) in ((-0.5, -0.5, 0.4), (0.5, -0.5, 0.5)):
        I.tube([(x, y, G + 0.05), (x + 0.05, y - 0.02, G + z * 0.5), (x - 0.03, y, G + z)], 0.035, leaf_dark(), segs=6)
    finish()


def Jungle_4():
    island("Jungle")
    I.box(0.7, 0.55, 0.3, M("TempleStone", "#8FA08A", rough=0.6, coat=0.2), loc=(0.0, 0.1, G + 0.15), bevel=0.04)
    I.lathe([(0.0, 0.0), (0.2, 0.0), (0.22, 0.25), (0.15, 0.35), (0.2, 0.5), (0.0, 0.62)], gold(), segs=20, loc=(0.0, 0.1, G + 0.3))
    for ex in (-0.06, 0.06):
        I.sphere(0.035, red(), loc=(ex, -0.08, G + 0.85))
    torch(-0.55, -0.2, 1.0)
    torch(0.55, -0.2, 1.0)
    finish()


# ---- Tundra
def Tundra_1():
    island("Tundra")
    dead_tree(0.0, 0.1, 1.3, bark=M("FrostWood", "#6E6A70", rough=0.6))
    for (x, z) in ((0.25, 0.8), (0.42, 0.95), (-0.22, 0.95)):
        I.cyl(0.04, 0.2, ice(), r2=0.0, segs=6, loc=(x, 0.1, G + z), rot=(180, 0, 0), bevel=0.0, smooth=False)
    pine(-0.6, -0.3, 0.6, snow=True)
    finish()


def Tundra_2():
    island("Tundra")
    I.cyl(0.85, 0.06, ice(), segs=36, loc=(0.0, 0.0, G + 0.01), bevel=0.0)
    boat_hull(0.0, 0.05, 1.0, M("FrozenWood", "#8E8C9A", rough=0.5), sink=0.15, rot_z=25, tilt=-18)
    crystal(-0.55, -0.35, 0.7, ice())
    finish()


def Tundra_3():
    island("Tundra")
    I.cyl(0.85, 1.1, M("Mountain", "#7E93AE", rough=0.5, coat=0.3), r2=0.05, segs=7, loc=(0.0, 0.15, G + 0.55), bevel=0.0, smooth=False)
    I.cyl(0.35, 0.45, white(), r2=0.02, segs=7, loc=(0.0, 0.15, G + 0.93), bevel=0.0, smooth=False)
    I.sphere(0.24, M("CaveIce", "#2E5578", rough=0.2, coat=0.8), loc=(0.0, -0.45, G + 0.2), scale=(1.1, 0.5, 1.0))
    finish()


def Tundra_4():
    island("Tundra")
    throne(0.0, 0.1, 1.1, ice(), M("IceDark", "#7FC6F2", rough=0.1, coat=1.0))
    crystal(-0.6, 0.1, 0.9, ice())
    crystal(0.6, 0.15, 0.9, ice())
    finish()


# ---- Swamp
def Swamp_1():
    island("Swamp")
    water_pool(0.7, 0.0, -0.1, M("SwampWater", "#4E6B3A", rough=0.1, coat=1.0))
    I.tube([(-0.6, 0.1, G - 0.05), (0.0, 0.0, G + 0.2), (0.6, -0.1, G - 0.02)], [0.24, 0.22, 0.2], M("Trunk", "#6A4C35", rough=0.7), segs=14)
    I.cyl(0.21, 0.02, M("TrunkCut", "#C4A27A", rough=0.6), segs=14, loc=(0.62, -0.1, G - 0.02), rot=(0, 90, 0), bevel=0.0)
    for (x, y) in ((-0.2, -0.5), (0.35, -0.45)):
        I.cyl(0.12, 0.03, M("LilyPad", "#5BB04A", rough=0.4), segs=16, loc=(x, y, G + 0.04), bevel=0.0)
    finish()


def Swamp_2():
    island("Swamp")
    dead_tree(0.0, 0.15, 1.4)
    I.tube([(0.28, 0.15, G + 0.78), (0.28, 0.15, G + 0.3)], 0.01, M("Rope", "#C8B28A"), segs=6)
    I.tube([(0.48, 0.15, G + 0.98), (0.48, 0.15, G + 0.3)], 0.01, M("Rope", "#C8B28A"), segs=6)
    I.box(0.26, 0.1, 0.03, wood(), loc=(0.38, 0.15, G + 0.3), bevel=0.01)
    dead_tree(-0.6, -0.25, 0.6)
    finish()


def Swamp_3():
    island("Swamp")
    I.cyl(0.24, 0.9, M("WitchWall", "#6C5A7A", rough=0.6), r2=0.2, segs=10, loc=(0.0, 0.1, G + 0.45), rot=(0, 6, 0), bevel=0.02)
    I.cyl(0.36, 0.6, purple(), r2=0.0, segs=10, loc=(0.06, 0.1, G + 1.15), rot=(0, 14, 0), bevel=0.0)
    I.box(0.1, 0.04, 0.12, M("WindowGlow", "#FFD84A", emit=1.2, emit_color="#FFC000"), loc=(0.02, -0.14, G + 0.6), bevel=0.01)
    cauldron(-0.55, -0.3, 0.6)
    finish()


def Swamp_4():
    island("Swamp")
    cauldron(0.0, 0.0, 2.0)
    for (x, z) in ((-0.15, 1.15), (0.2, 1.25)):
        I.sphere(0.08, slime(), loc=(x, -0.05, G + z))
    finish()


# ---- Volcano
def Volcano_1():
    island("Volcano")
    volcano_cone(0.1, 0.25, 1.1, M("VolcanoRock", "#4B3B36", rough=0.6, coat=0.2))
    rock(-0.55, -0.35, 0.9, M("Ash", "#5A4E4A", rough=0.7))
    rock(0.55, -0.45, 0.6, M("Ash", "#5A4E4A", rough=0.7))
    finish()


def Volcano_2():
    island("Volcano")
    for side in (-1, 1):
        I.box(0.08, 0.08, 1.0, wood_dark(), loc=(-0.25 + side * 0.25, 0.1, G + 0.5), bevel=0.01)
    I.box(0.6, 0.08, 0.08, wood_dark(), loc=(-0.25, 0.1, G + 0.98), bevel=0.01)
    I.box(0.35, 0.3, 0.3, rust(), loc=(-0.25, 0.1, G + 0.35), bevel=0.03)
    I.box(0.5, 0.45, 0.55, M("Furnace", "#55443C", rough=0.6), loc=(0.45, 0.05, G + 0.27), bevel=0.05)
    I.box(0.22, 0.05, 0.2, lava(), loc=(0.45, -0.18, G + 0.22), bevel=0.02)
    I.cyl(0.08, 0.4, steel_dark(), segs=10, loc=(0.55, 0.15, G + 0.75), bevel=0.0)
    finish()


def Volcano_3():
    island("Volcano")
    I.box(1.3, 0.45, 0.95, M("VolcanoRock", "#4B3B36", rough=0.6, coat=0.2), loc=(0.0, 0.35, G + 0.47), bevel=0.06, smooth=False)
    I.box(0.35, 0.06, 0.9, lava(), loc=(0.0, 0.11, G + 0.48), bevel=0.02)
    water_pool(0.55, 0.0, -0.3, lava())
    finish()


def Volcano_4():
    island("Volcano")
    I.torus(0.62, 0.18, M("CraterRock", "#4B3B36", rough=0.6), rsegs=10, loc=(0.0, 0.05, G + 0.08), smooth=False)
    water_pool(0.5, 0.0, 0.05, lava())
    I.box(0.4, 0.3, 0.55, M("Titan", "#6E6560", rough=0.6), loc=(0.0, 0.1, G + 0.45), bevel=0.06)
    I.box(0.24, 0.22, 0.2, M("Titan", "#6E6560", rough=0.6), loc=(0.0, 0.1, G + 0.83), bevel=0.04)
    for ex in (-0.05, 0.05):
        I.sphere(0.03, lava(), loc=(ex, -0.02, G + 0.86))
    finish()


# ---- Hell
def Hell_1():
    island("Hell")
    water_pool(0.8, 0.0, -0.05, lava())
    skull(0.0, 0.1, G + 0.45, 2.6)
    finish()


def Hell_2():
    island("Hell")
    tower(0.0, 0.15, 0.22, 1.0, M("HellWall", "#5A1612", rough=0.6, coat=0.2), black(), roof_h=0.35)
    for (dx, dz) in ((0.0, 1.55), (0.12, 1.45), (-0.1, 1.48)):
        I.sphere(0.1, lava(), loc=(dx, 0.15, G + dz), scale=(1, 1, 1.6))
    I.box(0.25, 0.25, 0.3, M("HellHouse", "#3E1210", rough=0.6), loc=(-0.6, -0.25, G + 0.15), bevel=0.03)
    I.box(0.25, 0.25, 0.4, M("HellHouse", "#3E1210", rough=0.6), loc=(0.6, -0.2, G + 0.2), bevel=0.03)
    finish()


def Hell_3():
    island("Hell")
    horned_gate(0.0, 0.1, 1.2, M("HellWall", "#5A1612", rough=0.6, coat=0.2), bone())
    torch(-0.7, -0.35, 1.0)
    torch(0.7, -0.35, 1.0)
    finish()


def Hell_4():
    island("Hell")
    throne(0.0, 0.1, 1.1, M("DemonThrone", "#2A0F0E", rough=0.4, coat=0.6), red())
    for side in (-1, 1):
        I.tube([(side * 0.33, 0.32, G + 0.95), (side * 0.48, 0.32, G + 1.2), (side * 0.4, 0.32, G + 1.4)], [0.06, 0.04, 0.015], bone(), segs=8)
    water_pool(0.3, -0.6, -0.35, lava())
    finish()


# ---- Heaven
def Heaven_1():
    island("Heaven")
    trunk_tree(0.0, 0.1, 1.5, leaves=M("LightLeaf", "#FFF3A8", rough=0.3, coat=0.6, emit=0.5, emit_color="#FFE070"),
               bark=M("WhiteBark", "#EDE4D2", rough=0.4))
    cloud(-0.6, -0.3, G + 0.0, 0.8)
    cloud(0.62, -0.25, G + 0.02, 0.7)
    finish()


def Heaven_2():
    island("Heaven")
    arch(0.0, 0.1, 1.2, gold(), w=0.9, h=0.8, t=0.16)
    for x in (-0.6, -0.3, 0.0, 0.3, 0.6):
        I.sphere(0.2, white(), loc=(x, -0.3, G + 0.0))
    finish()


def Heaven_3():
    island("Heaven")
    I.box(0.9, 0.45, 0.45, white(), loc=(0.0, 0.15, G + 0.22), bevel=0.04)
    for x in (-0.45, 0.45):
        tower(x, 0.15, 0.17, 0.8, white(), gold(), roof_h=0.4)
    I.box(0.2, 0.05, 0.28, gold(), loc=(0.0, -0.08, G + 0.14), bevel=0.02)
    cloud(0.0, -0.45, G - 0.02, 0.7)
    finish()


def Heaven_4():
    island("Heaven")
    throne(0.0, 0.15, 1.1, white(), gold())
    for side in (-1, 1):
        I.extrude([(0, 0), (0.45, 0.15), (0.55, 0.55), (0.3, 0.75), (0.05, 0.5)], 0.05, white(),
                  loc=(side * 0.3, 0.38, G + 0.55), rot=(0, 0, 0 if side > 0 else 180), bevel=0.02)
    I.torus(0.15, 0.025, gold(), rsegs=6, loc=(0.0, 0.32, G + 1.15), rot=(70, 0, 0))
    finish()


# ---- Dead
def Dead_1():
    island("Dead")
    crypt(0.2, 0.2, 0.9, M("CryptWall", "#7B7787", rough=0.6), M("CryptRoof", "#3E3A4A", rough=0.75, coat=0.05))
    tombstone(-0.5, -0.1, 1.1)
    tombstone(-0.15, -0.5, 0.9)
    tombstone(0.55, -0.45, 0.8)
    finish()


def Dead_2():
    island("Dead")
    I.box(1.2, 0.35, 0.8, M("Ossuary", "#6A6670", rough=0.6), loc=(0.0, 0.35, G + 0.4), bevel=0.05)
    for row in range(2):
        for k in range(4):
            skull(-0.42 + 0.28 * k, 0.15, G + 0.25 + 0.32 * row, 0.7)
    I.torus(0.3, 0.03, gold(), rsegs=6, loc=(0.0, -0.1, G + 1.15))
    for k in range(4):
        a = math.radians(90 * k)
        I.sphere(0.05, M("Candle", "#FFD84A", emit=1.5, emit_color="#FFB000"), loc=(0.3 * math.cos(a), -0.1 + 0.3 * math.sin(a), G + 1.22))
    finish()


def Dead_3():
    island("Dead")
    for x in (-0.45, 0.45):
        I.box(0.2, 0.2, 1.1, M("CathedralStone", "#7B7787", rough=0.6), loc=(x, 0.1, G + 0.55), bevel=0.03)
        I.cyl(0.16, 0.35, M("CryptRoof", "#3E3A4A", rough=0.75, coat=0.05), r2=0.0, segs=4, loc=(x, 0.1, G + 1.27), rot=(0, 0, 45), bevel=0.0, smooth=False)
    I.box(0.7, 0.18, 0.55, M("CathedralStone", "#7B7787", rough=0.6), loc=(0.0, 0.12, G + 0.28), bevel=0.03)
    I.torus(0.22, 0.05, M("StainedGlass", "#9B4DFF", emit=0.8, emit_color="#8A2BE2"), rsegs=8, loc=(0.0, 0.02, G + 0.85), rot=(90, 0, 0))
    I.box(0.2, 0.05, 0.32, black(), loc=(0.0, 0.03, G + 0.18), bevel=0.01)
    finish()


def Dead_4():
    island("Dead")
    I.box(0.95, 0.5, 0.35, M("Sarco", "#8E8A9A", rough=0.5, coat=0.4), loc=(0.0, 0.05, G + 0.18), bevel=0.06)
    I.box(0.9, 0.45, 0.12, M("SarcoLid", "#6D697A", rough=0.5, coat=0.5), loc=(0.0, 0.05, G + 0.41), bevel=0.04)
    pts = [(-0.18, 0.0), (0.18, 0.0), (0.22, 0.16), (0.11, 0.08), (0.0, 0.2), (-0.11, 0.08), (-0.22, 0.16)]
    I.extrude(pts, 0.08, gold(), loc=(0.0, 0.05, G + 0.47), bevel=0.01)
    torch(-0.62, -0.25, 1.0)
    torch(0.62, -0.25, 1.0)
    finish()


# ---- Abyss
def Abyss_1():
    island("Abyss")
    I.torus(0.45, 0.13, pink(), arc=180, rsegs=10, loc=(0.0, 0.1, G + 0.1), rot=(90, 0, 0))
    coral(-0.65, -0.2, 0.8, M("CoralOrange", "#FF8A3D", rough=0.4, coat=0.6))
    coral(0.62, -0.25, 0.7, M("CoralPurple", "#B46BFF", rough=0.4, coat=0.6))
    finish()


def Abyss_2():
    island("Abyss")
    boat_hull(0.0, 0.1, 1.2, M("WetWood", "#5A4636", rough=0.5), sink=0.1, rot_z=15, tilt=-22)
    coral(-0.62, -0.3, 0.6, pink())
    finish()


def Abyss_3():
    island("Abyss")
    for k in range(5):
        x = -0.55 + 0.27 * k
        I.torus(0.32, 0.04, bone(), arc=180, rsegs=8, loc=(x, 0.05, G + 0.02), rot=(90, 0, 90), scale=(1.0, 1.0, 1.0 + 0.1 * (2 - abs(k - 2))))
    I.tube([(-0.75, 0.05, G + 0.1), (0.75, 0.05, G + 0.1)], 0.05, bone(), segs=8)
    skull(0.85, 0.05, G + 0.22, 1.1)
    finish()


def Abyss_4():
    island("Abyss")
    I.box(0.8, 0.45, 0.5, M("Palace", "#5FA9C9", rough=0.4, coat=0.5), loc=(0.0, 0.15, G + 0.25), bevel=0.04)
    I.sphere(0.32, M("PalaceDome", "#3D86B5", rough=0.3, coat=0.8), loc=(0.0, 0.15, G + 0.5), scale=(1, 1, 0.85))
    for x in (-0.45, 0.45):
        I.cyl(0.08, 0.7, M("Palace", "#5FA9C9"), segs=12, loc=(x, 0.0, G + 0.35), bevel=0.0)
    trident(0.0, -0.35, 0.7, gold())
    finish()


# ---- Mechanical
def Mechanical_1():
    island("Mechanical")
    I.box(1.2, 0.35, 0.12, M("Conveyor", "#3A3E45", rough=0.4), loc=(0.0, -0.2, G + 0.25), bevel=0.03)
    for x in (-0.45, 0.45):
        I.box(0.08, 0.3, 0.25, metal(), loc=(x, -0.2, G + 0.12), bevel=0.01)
    for x in (-0.3, 0.05, 0.38):
        I.box(0.16, 0.16, 0.16, M("Crate", "#C98A4A", rough=0.5), loc=(x, -0.2, G + 0.4), bevel=0.02)
    I.box(0.1, 0.1, 0.9, hazard(), loc=(0.55, 0.3, G + 0.45), bevel=0.01)
    I.box(0.7, 0.08, 0.08, hazard(), loc=(0.25, 0.3, G + 0.9), bevel=0.01)
    I.cyl(0.02, 0.3, steel_dark(), segs=6, loc=(0.0, 0.3, G + 0.73), bevel=0.0)
    gear(-0.45, 0.35, G + 0.55, 0.7, m=rust())
    finish()


def Mechanical_2():
    island("Mechanical")
    I.tube([(-0.75, 0.2, G + 0.6), (0.0, 0.2, G + 0.6), (0.75, 0.2, G + 0.6)], 0.14, rust(), segs=14)
    I.tube([(0.0, 0.2, G + 0.6), (0.0, 0.2, G + 1.1)], 0.14, rust(), segs=14)
    I.sphere(0.2, metal(), loc=(0.0, 0.2, G + 0.6))
    I.box(0.2, 0.05, 0.55, slime(), loc=(0.0, 0.0, G + 0.3), bevel=0.02)
    water_pool(0.5, 0.0, -0.3, slime())
    finish()


def Mechanical_3():
    island("Mechanical")
    I.cyl(0.4, 0.3, metal(), segs=24, loc=(0.0, 0.0, G + 0.15), bevel=0.03)
    I.cyl(0.42, 0.04, holo(), segs=24, loc=(0.0, 0.0, G + 0.32), bevel=0.0)
    I.sphere(0.32, M("HoloGlobe", "#3FE6FF", rough=0.1, coat=0.6, emit=1.0, emit_color="#25D8FF", alpha=0.6), loc=(0.0, 0.0, G + 0.72))
    I.torus(0.36, 0.015, holo(), rsegs=6, loc=(0.0, 0.0, G + 0.72), rot=(70, 0, 0))
    for x in (-0.62, 0.62):
        I.box(0.25, 0.2, 0.4, metal(), loc=(x, 0.1, G + 0.2), bevel=0.03)
        I.box(0.2, 0.03, 0.15, holo(), loc=(x, -0.01, G + 0.32), rot=(-20, 0, 0), bevel=0.0)
    finish()


def Mechanical_4():
    island("Mechanical")
    I.cyl(0.45, 0.25, metal(), segs=24, loc=(0.0, 0.1, G + 0.12), bevel=0.03)
    I.cyl(0.28, 0.75, M("ReactorGlass", "#7DFF6A", rough=0.05, coat=1.0, emit=1.8, emit_color="#3CFF2A"), segs=20, loc=(0.0, 0.1, G + 0.62), bevel=0.0)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        I.cyl(0.04, 0.8, steel_dark(), segs=8, loc=(0.32 * math.cos(a), 0.1 + 0.32 * math.sin(a), G + 0.62), bevel=0.0)
    I.cyl(0.35, 0.15, metal(), segs=24, loc=(0.0, 0.1, G + 1.05), bevel=0.03)
    I.box(0.25, 0.06, 0.06, hazard(), loc=(-0.6, -0.3, G + 0.05), bevel=0.01)
    finish()


# ---- Void
def Void_1():
    island("Void")
    I.cyl(0.18, 0.75, obsidian(), r2=0.14, segs=6, loc=(0.0, 0.1, G + 0.37), bevel=0.02, smooth=False)
    crystal(0.0, 0.1, 1.2, tilt=0).location.z = G + 0.75
    for (x, y, z) in ((-0.6, -0.2, 0.4), (0.62, -0.15, 0.6)):
        I.ico(0.16, obsidian(), subdiv=1, loc=(x, y, G + z), scale=(1, 1, 0.6))
    finish()


def Void_2():
    island("Void")
    I.tube([(0.0, 0.1, G), (0.03, 0.1, G + 0.5)], [0.1, 0.08], void_crystal(), segs=6)
    for (dx, dz, t) in ((0.0, 0.5, 0), (0.25, 0.4, 35), (-0.25, 0.42, -35), (0.1, 0.65, 15), (-0.12, 0.62, -20)):
        crystal(dx, 0.1, 0.7, tilt=t).location.z = G + dz
    crystal(-0.62, -0.3, 0.5, tilt=-10)
    crystal(0.6, -0.35, 0.45, tilt=12)
    finish()


def Void_3():
    island("Void")
    tower_root = I.empty("Broken", loc=(0.0, 0.1, 0.0), rot=(0, 10, 0))
    I.cyl(0.25, 0.85, M("VoidStone", "#4A3C5E", rough=0.5), segs=8, loc=(0.0, 0.0, G + 0.42), bevel=0.02, smooth=False, parent=tower_root)
    I.cyl(0.25, 0.3, M("VoidStone", "#4A3C5E", rough=0.5), segs=8, loc=(0.12, 0.0, G + 1.1), rot=(0, 18, 0), bevel=0.02, smooth=False, parent=tower_root)
    I.box(0.1, 0.05, 0.16, M("VoidWindow", "#E0B0FF", emit=1.2, emit_color="#C070FF"), loc=(0.0, -0.24, G + 0.55), bevel=0.01, parent=tower_root)
    for (x, z) in ((-0.55, 0.7), (0.55, 0.9)):
        I.box(0.18, 0.18, 0.18, M("VoidStone", "#4A3C5E", rough=0.5), loc=(x, -0.1, G + z), rot=(20, 30, 10), bevel=0.02)
    finish()


def Void_4():
    island("Void")
    I.torus(0.5, 0.1, obsidian(), rsegs=10, loc=(0.0, 0.1, G + 0.62), rot=(90, 0, 0))
    I.cyl(0.42, 0.04, M("VoidPortal", "#7A1FFF", rough=0.1, coat=0.6, emit=2.0, emit_color="#6A0FFF"), segs=32, loc=(0.0, 0.1, G + 0.62), rot=(90, 0, 0), bevel=0.0)
    I.sphere(0.12, M("VoidEye", "#FFE8FF", emit=2.0, emit_color="#FFC8FF"), loc=(0.0, 0.06, G + 0.62))
    crystal(-0.62, -0.25, 0.6, tilt=-12)
    crystal(0.62, -0.25, 0.6, tilt=12)
    finish()


SUBZONE_ICONS = {name: fn for name, fn in list(globals().items()) if callable(fn) and "_" in name and name.split("_")[0] in PAL
                 and name.split("_")[1].isdigit()}
