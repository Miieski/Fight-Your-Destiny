"""Recipes for the UI icons (Part A). Each recipe builds one chunky glossy object with fyd_icons.
Shapes are modeled facing -Y (the camera looks from the front-right, slightly above)."""
import math

import fyd_icons as I

M = I.mat


# palette -------------------------------------------------------------------------------------------
def gold():
    return M("Gold", "#FFC52E", metal=0.5, rough=0.22, coat=1.0)


def gold_deep():
    return M("GoldDeep", "#E8901A", metal=0.5, rough=0.28, coat=0.9)


def wood():
    return M("Wood", "#A8652F", rough=0.55, coat=0.35)


def wood_dark():
    return M("WoodDark", "#5E3519", rough=0.6, coat=0.3)


def steel():
    return M("Steel", "#CBD5E0", metal=0.75, rough=0.25, coat=0.6)


def steel_dark():
    return M("SteelDark", "#7E8A98", metal=0.75, rough=0.3, coat=0.5)


def red():
    return M("Red", "#EC2F3B", rough=0.3, coat=1.0)


def red_dark():
    return M("RedDark", "#B01E2A", rough=0.32, coat=0.9)


def white():
    return M("White", "#F7F3EA", rough=0.35, coat=0.8)


def cream():
    return M("Cream", "#F4E2B4", rough=0.45, coat=0.5)


def leather():
    return M("Leather", "#B8662C", rough=0.5, coat=0.5)


def leather_dark():
    return M("LeatherDark", "#7A3E1A", rough=0.5, coat=0.4)


def purple():
    return M("Purple", "#A24BFF", rough=0.28, coat=1.0)


def blue():
    return M("Blue", "#3A8CFF", rough=0.3, coat=1.0)


def green():
    return M("Green", "#4FD24A", rough=0.3, coat=1.0)


def pink():
    return M("Pink", "#FF7FAB", rough=0.3, coat=1.0)


def skin():
    return M("Skin", "#FFD0A1", rough=0.45, coat=0.6)


def black():
    return M("Black", "#1D1A1F", rough=0.25, coat=1.0)


def cyan():
    return M("Cyan", "#5FD6FF", rough=0.12, coat=1.0, emit=0.15)


# helpers ---------------------------------------------------------------------------------------------
def coin(loc=(0, 0, 0), size=1.0, tilt=8, parent=None, star=True, body=None, face=None, emblem=None, segs=48):
    root = I.empty("Coin", loc=loc, rot=(0, 0, tilt), scale=size)
    if parent is not None:
        root.parent = parent
    prof = [(0, -0.10), (0.78, -0.10), (0.80, -0.15), (0.96, -0.15), (1.0, -0.11), (1.0, 0.11),
            (0.96, 0.15), (0.80, 0.15), (0.78, 0.10), (0, 0.10)]
    I.lathe(prof, body or gold(), segs=segs, bevel=0.02, segments=2, rot=(90, 0, 0), parent=root, name="CoinBody",
            smooth=segs > 8)
    I.cyl(0.78, 0.206, face or gold_deep(), segs=segs, bevel=0.0, rot=(90, 0, 0), parent=root, name="CoinFace",
          smooth=segs > 8)
    if star:
        I.extrude(I.star_points(5, 0.56, 0.25), 0.09, emblem or gold(), loc=(0, -0.135, 0.0), bevel=0.025,
                  parent=root, name="CoinStar")
    return root


def arrow_points(length=2.0, shaft=0.24, head=0.62, head_len=0.75):
    x0, x1 = -length / 2, length / 2 - head_len
    return [(x0, -shaft / 2), (x1, -shaft / 2), (x1, -head / 2), (length / 2, 0), (x1, head / 2),
            (x1, shaft / 2), (x0, shaft / 2)]


def cone_toward(pos, direction_deg_xz, length, radius, material, parent=None):
    """Cone lying in the XZ plane, base at pos, pointing at angle (deg, from +X towards +Z)."""
    a = math.radians(direction_deg_xz)
    cx, cz = pos[0] + math.cos(a) * length / 2, pos[2] + math.sin(a) * length / 2
    return I.cyl(radius, length, material, r2=0.0, segs=24, bevel=0.0, loc=(cx, pos[1], cz),
                 rot=(0, 90 - direction_deg_xz, 0), parent=parent)


def sword(parent=None, blade=None, guard=None, grip=None, length=2.6, width=0.34, name="Sword", tip=0.82):
    """Longsword along +Z, grip at the bottom (rotate the parent to pose it)."""
    blade = blade or steel()
    guard = guard or gold()
    grip = grip or leather_dark()
    bl = length * 0.66
    pts = [(-width / 2, 0), (width / 2, 0), (width / 2, bl * tip), (0, bl), (-width / 2, bl * tip)]
    I.extrude(pts, width * 0.32, blade, loc=(0, 0, length * 0.06), bevel=width * 0.06, parent=parent, name=name + "Blade",
              smooth=False)
    I.box(width * 0.06, width * 0.34, bl * 0.72, steel_dark(), loc=(0, 0, length * 0.06 + bl * 0.4), bevel=0.01,
          parent=parent, name=name + "Fuller")
    I.box(width * 2.5, width * 0.5, width * 0.36, guard, loc=(0, 0, length * 0.03), bevel=width * 0.12, parent=parent,
          name=name + "Guard")
    I.cyl(width * 0.22, length * 0.22, grip, segs=16, loc=(0, 0, -length * 0.1), parent=parent, name=name + "Grip")
    I.sphere(width * 0.36, guard, segs=20, rings=12, loc=(0, 0, -length * 0.23), parent=parent, name=name + "Pommel")


# ----------------------------------------------------------------------------------------------------
# MENU
# ----------------------------------------------------------------------------------------------------
def Inventory():
    I.box(1.4, 0.85, 1.55, leather(), loc=(0, 0, 0), bevel=0.32, segments=4)
    I.box(1.44, 0.9, 0.62, leather_dark(), loc=(0, -0.02, 0.5), bevel=0.22, segments=4)
    I.box(1.0, 0.32, 0.72, leather_dark(), loc=(0, -0.42, -0.3), bevel=0.14)
    I.box(0.3, 0.12, 0.26, gold(), loc=(0, -0.5, 0.26), bevel=0.05)
    I.box(0.24, 0.1, 0.18, gold(), loc=(0, -0.6, -0.1), bevel=0.04)
    I.torus(0.32, 0.075, leather_dark(), arc=180, rsegs=12, loc=(0, 0, 0.78), rot=(90, 0, 0))
    for x in (-0.48, 0.48):
        I.box(0.14, 0.08, 1.2, leather_dark(), loc=(x, -0.45, 0.02), bevel=0.03)


def Stats():
    I.box(2.1, 0.95, 0.26, wood(), loc=(0, 0, -0.92), bevel=0.08)
    for x, h, m in ((-0.62, 0.8, green()), (0.0, 1.3, blue()), (0.62, 1.9, red())):
        I.box(0.46, 0.52, h, m, loc=(x, 0.05, -0.79 + h / 2), bevel=0.1)
    I.extrude(arrow_points(2.2, 0.26, 0.72, 0.6), 0.22, gold(), loc=(-0.05, -0.45, 0.15), rot=(0, -33, 0), bevel=0.05)


def Shop():
    I.box(2.0, 1.0, 0.9, wood(), loc=(0, 0, -0.6), bevel=0.08)
    I.box(2.25, 1.15, 0.16, wood_dark(), loc=(0, 0, -0.1), bevel=0.05)
    for x in (-1.0, 1.0):
        for y in (-0.42, 0.42):
            I.box(0.14, 0.14, 1.4, wood_dark(), loc=(x, y, 0.55), bevel=0.03)
    for i in range(6):
        x = -1.05 + 0.42 * i
        m = red() if i % 2 == 0 else white()
        I.box(0.42, 1.35, 0.2, m, loc=(x + 0.21, -0.05, 1.32), rot=(-14, 0, 0), bevel=0.04)
        I.extrude(I.circle_points(0.21, n=16, start=180, arc=180), 0.14, m, loc=(x + 0.21, -0.7, 1.2), bevel=0.03)
    coin(loc=(-0.45, -0.25, 0.25), size=0.32, tilt=10)
    coin(loc=(0.15, -0.3, 0.2), size=0.26, tilt=-10)
    I.sphere(0.2, red(), loc=(0.62, -0.25, 0.12))
    I.sphere(0.18, green(), loc=(0.85, -0.05, 0.1))


def RebirthShop():
    P = purple()
    for start in (25, 205):
        I.torus(0.95, 0.15, P, arc=135, start=start, rsegs=14, loc=(0, 0, 0), rot=(90, 0, 0))
        end = start + 135
        a = math.radians(end)
        pos = (0.95 * math.cos(a), 0, 0.95 * math.sin(a))
        cone_toward(pos, end + 90, 0.5, 0.33, P)
    I.extrude(I.star_points(5, 0.62, 0.28), 0.3, gold(), loc=(0, 0, 0), bevel=0.06)


def Pets():
    P = pink()
    I.sphere(0.6, P, loc=(0, 0, -0.42), scale=(1.25, 0.55, 0.95))
    for x, z, r in ((-0.88, 0.32, -25), (-0.33, 0.78, -8), (0.33, 0.78, 8), (0.88, 0.32, 25)):
        I.sphere(0.32, P, loc=(x, 0, z), scale=(0.9, 0.6, 1.15), rot=(0, r, 0))


def Index():
    R = red_dark()
    I.box(1.5, 0.1, 1.95, R, loc=(0, -0.22, 0), bevel=0.04)
    I.box(1.5, 0.1, 1.95, R, loc=(0, 0.22, 0), bevel=0.04)
    I.box(0.16, 0.54, 1.95, R, loc=(-0.72, 0, 0), bevel=0.06)
    I.box(1.36, 0.36, 1.82, cream(), loc=(0.04, 0, 0), bevel=0.03)
    I.box(0.42, 0.1, 0.42, gold(), loc=(0, -0.28, 0.15), rot=(0, 45, 0), bevel=0.05)
    I.sphere(0.12, cyan(), loc=(0, -0.34, 0.15), scale=(1, 0.6, 1))
    for x, z in ((-0.68, 0.9), (0.68, 0.9), (-0.68, -0.9), (0.68, -0.9)):
        I.box(0.26, 0.14, 0.26, gold(), loc=(x, -0.25, z), bevel=0.05)
    I.box(1.1, 0.04, 0.08, gold(), loc=(0, -0.28, -0.45), bevel=0.01)


def Quests():
    C = cream()
    I.box(1.45, 0.08, 1.55, C, loc=(0, 0, 0), bevel=0.03)
    for z in (0.85, -0.85):
        I.cyl(0.22, 1.75, C, segs=24, loc=(0, 0, z), rot=(0, 90, 0), bevel=0.04)
        for x in (-0.98, 0.98):
            I.sphere(0.16, wood(), loc=(x, 0, z))
    for z, w in ((0.42, 1.0), (0.12, 0.9), (-0.18, 1.0)):
        I.box(w, 0.04, 0.09, wood_dark(), loc=(-0.05, -0.05, z), bevel=0.01)
    I.cyl(0.26, 0.1, red(), segs=24, loc=(0.32, -0.08, -0.5), rot=(90, 0, 0), bevel=0.03)
    I.extrude(I.star_points(5, 0.14, 0.06), 0.06, red_dark(), loc=(0.32, -0.14, -0.5), bevel=0.01)


def _person(x, y, z, shirt, scale=1.0):
    root = I.empty("Person", loc=(x, y, z), scale=scale)
    I.lathe([(0, -1.15), (0.62, -1.15), (0.64, -0.9), (0.5, -0.58), (0.2, -0.46), (0, -0.45)], shirt, segs=32,
            parent=root, bevel=0.0)
    I.sphere(0.4, skin(), loc=(0, 0, -0.08), parent=root)
    I.sphere(0.42, wood_dark(), loc=(0, 0.06, 0.04), scale=(1.0, 0.95, 0.7), parent=root)
    for ex in (-0.13, 0.13):
        I.sphere(0.055, black(), loc=(ex, -0.37, -0.1), parent=root)
    return root


def Team():
    _person(0.5, 0.35, 0.15, green(), 0.95)
    _person(-0.42, -0.1, 0.0, blue(), 1.0)


def Settings():
    S = steel()
    I.cyl(0.78, 0.36, S, segs=40, rot=(90, 0, 0), bevel=0.05)
    for i in range(8):
        a = 360 / 8 * i
        r = math.radians(a)
        I.box(0.36, 0.34, 0.32, S, loc=(0.86 * math.cos(r), 0, 0.86 * math.sin(r)), rot=(0, -a, 0), bevel=0.06)
    I.cyl(0.36, 0.44, steel_dark(), segs=32, rot=(90, 0, 0), bevel=0.05)
    I.cyl(0.17, 0.5, black(), segs=24, rot=(90, 0, 0), bevel=0.02)


def Zones():
    C = cream()
    for i, (x, rz) in enumerate(((-0.66, 18), (0.0, -18), (0.66, 18))):
        I.box(0.68, 0.06, 1.45, C, loc=(x, 0, -0.1), rot=(0, 0, rz), bevel=0.02)
    I.cyl(0.22, 0.04, green(), segs=20, loc=(-0.62, -0.12, 0.2), rot=(90, 0, 18), bevel=0.0)
    I.cyl(0.18, 0.04, blue(), segs=20, loc=(0.02, -0.08, -0.4), rot=(90, 0, -18), bevel=0.0)
    for i in range(4):
        I.box(0.12, 0.04, 0.05, red(), loc=(-0.5 + 0.28 * i, -0.13, -0.15 - 0.06 * i), rot=(0, 20, 0), bevel=0.01)
    I.sphere(0.32, red(), loc=(0.55, -0.35, 0.72))
    I.sphere(0.12, white(), loc=(0.55, -0.62, 0.74))
    I.cyl(0.24, 0.55, red(), r2=0.0, segs=24, loc=(0.55, -0.35, 0.28), rot=(180, 0, 0), bevel=0.0)


def Hub():
    I.box(1.45, 1.2, 1.05, M("Stone", "#E9DBB8", rough=0.5, coat=0.4), loc=(0, 0, -0.42), bevel=0.06)
    I.cyl(1.25, 0.95, M("Roof", "#8E1A20", rough=0.6, coat=0.15), r2=0.0, segs=4, loc=(0, 0, 0.55), rot=(0, 0, 45),
          bevel=0.06, smooth=False)
    I.box(0.4, 0.08, 0.62, wood_dark(), loc=(0, -0.6, -0.62), bevel=0.05)
    I.sphere(0.04, gold(), loc=(0.11, -0.66, -0.62))
    for x in (-0.47, 0.47):
        I.box(0.3, 0.06, 0.3, blue(), loc=(x, -0.6, -0.28), bevel=0.03)
    I.box(0.24, 0.24, 0.55, M("StoneDark", "#9C8B6E", rough=0.5), loc=(0.4, 0.2, 0.8), bevel=0.04)
    I.cyl(0.03, 0.6, wood_dark(), segs=8, loc=(-0.0, 0, 1.25), bevel=0.0)
    I.extrude([(0, 0), (0.42, -0.12), (0, -0.26)], 0.04, gold(), loc=(0.02, 0, 1.53), bevel=0.01)


def Rewards():
    I.box(1.45, 1.45, 1.1, red(), loc=(0, 0, -0.35), bevel=0.06)
    I.box(1.6, 1.6, 0.34, red_dark(), loc=(0, 0, 0.32), bevel=0.06)
    I.box(0.3, 1.64, 1.52, gold(), loc=(0, 0, -0.18), bevel=0.04)
    I.box(1.64, 0.3, 1.52, gold(), loc=(0, 0, -0.18), bevel=0.04)
    for x, rz in ((0.34, 35), (-0.34, -35)):
        I.torus(0.32, 0.1, gold(), rsegs=12, loc=(x, 0, 0.7), rot=(90, 0, rz), scale=(1.0, 0.75, 1.0))
    I.sphere(0.17, gold(), loc=(0, 0, 0.55))


# ----------------------------------------------------------------------------------------------------
# CURRENCY & HUD
# ----------------------------------------------------------------------------------------------------
def Gold():
    coin()


RECIPES = {
    "Menu": {
        "Inventory": Inventory, "Stats": Stats, "Shop": Shop, "RebirthShop": RebirthShop, "Pets": Pets,
        "Index": Index, "Quests": Quests, "Team": Team, "Settings": Settings, "Zones": Zones, "Hub": Hub,
        "Rewards": Rewards,
    },
    "Currency": {
        "Gold": Gold,
    },
}
