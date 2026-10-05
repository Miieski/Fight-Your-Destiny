"""Part A icon recipes, continued: Currency & HUD, Stats, Item types, Weapon categories, UI marks.
RECIPES here merges every Part A group (Menu comes from fyd_icon_recipes)."""
import math

import fyd_icons as I
from fyd_icon_recipes import (M, RECIPES as MENU_RECIPES, arrow_points, black, blue, coin, cream, cyan, gold,
                              gold_deep, green, leather, leather_dark, pink, purple, red, steel, steel_dark, sword,
                              white, wood, wood_dark)


def pose_all(root):
    """Parent every top-level subject object to root (to pose the whole icon at once)."""
    for ob in I.collection(I.SUBJECT).objects:
        if ob is not root and ob.parent is None:
            ob.parent = root
    return root


def plus_points(size=1.0, w=0.36):
    a, b = size, w / 2
    return [(-b, a), (b, a), (b, b), (a, b), (a, -b), (b, -b), (b, -a), (-b, -a), (-b, -b), (-a, -b), (-a, b), (-b, b)]


def shield_points(w=0.9, top=0.95, bottom=-1.05, steps=8):
    pts = [(-w, top), (w, top), (w, 0.15)]
    for i in range(1, steps):
        t = i / steps
        pts.append((w * math.cos(t * math.pi / 2), 0.15 + (bottom - 0.15) * math.sin(t * math.pi / 2)))
    pts.append((0, bottom))
    for i in range(steps - 1, 0, -1):
        t = i / steps
        pts.append((-w * math.cos(t * math.pi / 2), 0.15 + (bottom - 0.15) * math.sin(t * math.pi / 2)))
    pts.append((-w, 0.15))
    return pts


# ----------------------------------------------------------------------------------------------------
# CURRENCY & HUD
# ----------------------------------------------------------------------------------------------------
def Gold():
    coin()


def Diamond():
    root = I.empty("Gem", rot=(-14, 0, 8))
    I.lathe([(0, -0.95), (1.0, 0.05), (1.0, 0.14), (0.62, 0.48), (0, 0.48)], cyan(), segs=8, smooth=False,
            bevel=0.015, segments=1, parent=root)


def RebirthCredit():
    coin(segs=6, body=purple(), face=M("PurpleDeep", "#6A22C9", rough=0.3, coat=1.0), emblem=gold(), tilt=10)


def Key():
    G = gold()
    I.torus(0.42, 0.14, G, rsegs=14, loc=(-0.85, 0, 0), rot=(90, 0, 0))
    I.cyl(0.16, 0.16, gold_deep(), segs=20, loc=(-0.38, 0, 0), rot=(0, 90, 0))
    I.cyl(0.12, 1.55, G, segs=20, loc=(0.2, 0, 0), rot=(0, 90, 0))
    for x, h in ((0.72, 0.42), (0.92, 0.3)):
        I.box(0.16, 0.2, h, G, loc=(x, 0, -h / 2), bevel=0.04)
    pose_all(I.empty("Key", rot=(0, -38, 6)))


def HealthHeart():
    root = I.empty("Heart", rot=(0, 0, 10))
    I.extrude(I.heart_points(1.0), 0.6, red(), bevel=0.2, segments=4, parent=root)


def ZoneBoost():
    root = I.empty("Bolt", rot=(0, -10, 10))
    pts = [(-0.15, 1.05), (0.6, 1.05), (0.12, 0.22), (0.62, 0.22), (-0.42, -1.05), (-0.08, -0.12), (-0.55, -0.12)]
    I.extrude(pts, 0.4, M("Bolt", "#FFC21F", rough=0.25, coat=1.0, emit=0.25, emit_color="#FFB000"), bevel=0.08,
              parent=root)


# ----------------------------------------------------------------------------------------------------
# STATS
# ----------------------------------------------------------------------------------------------------
def MaxHP():
    root = I.empty("Heart", rot=(0, 0, 10))
    I.extrude(I.heart_points(1.0), 0.6, red(), bevel=0.2, segments=4, parent=root)
    I.extrude(plus_points(0.42, 0.22), 0.3, green(), loc=(0.72, -0.4, 0.62), bevel=0.06, parent=root)


def Attack():
    for ry, y in ((40, 0.1), (-40, -0.1)):
        root = I.empty("S", rot=(0, ry, 0), loc=(0, y, 0))
        sword(parent=root, length=2.6, width=0.34)


def Defense():
    root = I.empty("Shield", rot=(0, 0, 12))
    I.extrude(shield_points(0.95, 1.0, -1.1), 0.36, steel(), bevel=0.08, parent=root)
    I.extrude(shield_points(0.75, 0.82, -0.85), 0.4, blue(), bevel=0.05, parent=root)
    I.box(0.2, 0.44, 1.55, gold(), loc=(0, 0, -0.02), bevel=0.05, parent=root)
    I.box(1.25, 0.44, 0.2, gold(), loc=(0, 0, 0.3), bevel=0.05, parent=root)
    I.sphere(0.24, gold(), loc=(0, -0.2, 0.3), parent=root)


def Speed():
    L = leather()
    I.box(0.55, 0.6, 1.05, L, loc=(-0.2, 0, 0.3), bevel=0.16)
    I.box(1.25, 0.62, 0.5, L, loc=(0.18, 0, -0.33), bevel=0.2)
    I.box(1.32, 0.66, 0.14, wood_dark(), loc=(0.18, 0, -0.6), bevel=0.05)
    I.box(0.62, 0.66, 0.16, leather_dark(), loc=(-0.2, 0, 0.8), bevel=0.05)
    for i, (z, ln) in enumerate(((0.55, 0.85), (0.32, 0.75), (0.1, 0.6))):
        feather = [(0, -0.12), (ln * 0.5, -0.16), (ln, 0), (ln * 0.5, 0.16), (0, 0.12)]
        I.extrude(feather, 0.1, white(), loc=(-0.42, -0.36, z + 0.05), rot=(0, 150 + i * 16, 0), bevel=0.03)
    pose_all(I.empty("Boot", rot=(0, 0, -18)))


def Crit():
    for r, m, y in ((1.0, red(), 0.0), (0.76, white(), -0.06), (0.52, red(), -0.12), (0.26, white(), -0.18)):
        I.cyl(r, 0.18, m, segs=40, loc=(0, y, 0), rot=(90, 0, 0), bevel=0.04)
    # arrow stuck in the bullseye, coming from the front-top-right
    I.tube([(0.0, -0.2, 0.0), (0.75, -1.1, 0.75)], 0.06, wood_dark(), segs=10)
    for rot in ((0, -45, -50), (90, -45, -50)):
        I.extrude([(0, 0), (0.42, -0.16), (0.42, 0.16)], 0.03, red(), loc=(0.7, -1.04, 0.7), rot=rot, bevel=0.0)
    pose_all(I.empty("Target", rot=(0, 0, 14)))


def GoldGain():
    for i in range(3):
        I.cyl(0.62, 0.2, gold(), segs=40, loc=(-0.35 + 0.03 * i, 0, -0.75 + 0.21 * i), bevel=0.04)
    coin(loc=(-0.3, 0.1, 0.25), size=0.62, tilt=18)
    I.extrude(arrow_points(1.6, 0.3, 0.8, 0.6), 0.3, green(), loc=(0.72, -0.25, 0.0), rot=(0, -90, 0), bevel=0.06)


# ----------------------------------------------------------------------------------------------------
# ITEM TYPES
# ----------------------------------------------------------------------------------------------------
def axe(parent=None, length=2.4):
    I.cyl(0.09, length, wood(), segs=16, loc=(0, 0, 0), parent=parent)
    pts = [(0, 0.35), (0.35, 0.42), (0.75, 0.62), (0.85, 0.0), (0.75, -0.62), (0.35, -0.42), (0, -0.35)]
    I.extrude(pts, 0.14, steel(), loc=(0.05, 0, length * 0.36), bevel=0.04, parent=parent, smooth=False)
    I.box(0.24, 0.24, 0.5, steel_dark(), loc=(0, 0, length * 0.36), bevel=0.05, parent=parent)
    I.cyl(0.13, 0.12, gold(), segs=16, loc=(0, 0, -length * 0.46), parent=parent)


def Weapon():
    a = I.empty("A", rot=(0, -38, 0), loc=(0.05, 0.1, 0))
    axe(parent=a)
    s = I.empty("S", rot=(0, 38, 0), loc=(-0.05, -0.1, 0))
    sword(parent=s)


def Helmet():
    root = I.empty("Helm", rot=(0, 0, 18))
    S = steel()
    I.lathe([(0, 0.78), (0.42, 0.7), (0.68, 0.42), (0.78, 0.0), (0.78, -0.55), (0.72, -0.66), (0, -0.66)], S,
            segs=40, parent=root)
    I.box(1.0, 0.25, 0.1, black(), loc=(0, -0.66, 0.02), bevel=0.03, parent=root)
    I.box(0.16, 0.4, 1.0, steel_dark(), loc=(0, -0.62, -0.18), bevel=0.05, parent=root)
    I.torus(0.77, 0.07, gold(), rsegs=10, loc=(0, 0, -0.6), parent=root)
    for y, z, s in ((0.35, 0.95, 0.3), (0.05, 1.02, 0.32), (-0.25, 0.92, 0.27)):
        I.sphere(s, red(), loc=(0, y, z), scale=(0.55, 1.0, 1.3), parent=root)


def Chest():
    root = I.empty("Chest", rot=(0, 0, 14))
    pts = [(-1.0, 0.75), (-0.62, 0.98), (-0.3, 0.72), (0.3, 0.72), (0.62, 0.98), (1.0, 0.75), (0.88, 0.2),
           (0.72, -0.75), (0.0, -1.0), (-0.72, -0.75), (-0.88, 0.2)]
    I.extrude(pts, 0.55, steel(), bevel=0.2, segments=4, parent=root)
    I.box(0.14, 0.62, 1.4, steel_dark(), loc=(0, 0, -0.1), bevel=0.05, parent=root)
    I.extrude(I.star_points(5, 0.28, 0.12), 0.2, gold(), loc=(0, -0.3, 0.22), bevel=0.04, parent=root)
    for x in (-0.62, 0.62):
        I.sphere(0.12, gold(), loc=(x, -0.25, 0.65), parent=root)


def Legs():
    for x in (-0.38, 0.38):
        root = I.empty("Leg", loc=(x, 0, 0), rot=(0, 0, 10))
        I.box(0.5, 0.55, 1.3, steel(), loc=(0, 0, 0.25), bevel=0.18, parent=root)
        I.sphere(0.22, gold(), loc=(0, -0.22, 0.45), scale=(1, 0.7, 1), parent=root)
        I.box(0.56, 0.95, 0.36, steel_dark(), loc=(0, -0.2, -0.5), bevel=0.14, parent=root)
        I.torus(0.27, 0.05, gold(), rsegs=8, loc=(0, 0, 0.88), parent=root)


def egg(loc=(0, 0, 0), size=1.0, shell=None, spot=None, parent=None):
    root = I.empty("Egg", loc=loc, scale=size)
    if parent is not None:
        root.parent = parent
    prof = []
    for i in range(17):
        t = math.pi * i / 16
        z = -math.cos(t)
        r = math.sin(t) * (0.78 if z < 0 else 0.78 - 0.16 * z)
        prof.append((r, z * (0.95 if z < 0 else 1.15)))
    I.lathe(prof, shell or white(), segs=40, parent=root)
    for az, z, s in ((-100, 0.3, 0.2), (-60, -0.35, 0.16), (-130, -0.4, 0.14), (-80, 0.85, 0.12), (-25, 0.15, 0.13)):
        a = math.radians(az)
        r = 0.74 if z < 0.5 else 0.5
        I.sphere(s, spot or green(), loc=(r * math.cos(a), r * math.sin(a), z), parent=root)
    return root


def Egg():
    egg(shell=cream(), spot=M("Teal", "#24C4A8", rough=0.3, coat=1.0))


def Trophy():
    G = gold()
    I.lathe([(0, -0.62), (0.2, -0.62), (0.13, -0.35), (0.2, -0.25), (0.6, 0.0), (0.74, 0.4), (0.78, 0.82),
             (0.68, 0.84), (0.64, 0.5), (0, 0.45)], G, segs=40)
    for x, st in ((-0.75, 90), (0.75, -90)):
        I.torus(0.28, 0.07, G, arc=180, start=st, rsegs=10, loc=(x, 0, 0.42), rot=(90, 0, 0))
    I.box(0.9, 0.7, 0.32, wood_dark(), loc=(0, 0, -0.8), bevel=0.06)
    I.box(0.7, 0.55, 0.18, wood(), loc=(0, 0, -0.56), bevel=0.04)
    I.extrude(I.star_points(5, 0.22, 0.1), 0.12, M("TrophyStar", "#FFF1A8", rough=0.2, coat=1.0), loc=(0, -0.66, 0.35),
              bevel=0.02)


def Pet():
    O = M("PetFur", "#FF9F43", rough=0.4, coat=0.8)
    I.sphere(0.9, O, loc=(0, 0, 0), scale=(1.1, 0.95, 0.92))
    for x in (-0.62, 0.62):
        ry = 22 if x < 0 else -22
        I.cyl(0.32, 0.6, O, r2=0.02, segs=20, loc=(x, 0.05, 0.85), rot=(0, ry, 0), bevel=0.05)
        I.cyl(0.16, 0.42, pink(), r2=0.01, segs=16, loc=(x, -0.08, 0.82), rot=(0, ry, 0), bevel=0.0)
    I.sphere(0.38, white(), loc=(0, -0.62, -0.25), scale=(1.2, 0.7, 0.85))
    I.sphere(0.12, pink(), loc=(0, -0.92, -0.08), scale=(1.2, 0.8, 0.9))
    for x in (-0.34, 0.34):
        I.sphere(0.15, black(), loc=(x, -0.76, 0.18), scale=(0.85, 0.6, 1.1))
        I.sphere(0.05, white(), loc=(x - 0.04, -0.85, 0.24))
        I.sphere(0.12, M("Blush", "#FF8A8A", rough=0.5, coat=0.3), loc=(x * 1.65, -0.62, -0.12), scale=(1, 0.4, 0.7))


# ----------------------------------------------------------------------------------------------------
# WEAPON CATEGORIES (weapon posed diagonally: hilt bottom-left, tip top-right)
# ----------------------------------------------------------------------------------------------------
def Sword():
    root = I.empty("Sword", rot=(0, 45, 0))
    sword(parent=root, length=2.8, width=0.38)


def Spear():
    root = I.empty("Spear", rot=(0, 45, 0))
    I.cyl(0.13, 3.3, wood(), segs=16, loc=(0, 0, -0.25), parent=root)
    I.extrude([(0, 0), (0.38, 0.42), (0, 1.25), (-0.38, 0.42)], 0.2, steel(), loc=(0, 0, 1.38), bevel=0.05,
              smooth=False, parent=root)
    I.cyl(0.19, 0.28, gold(), segs=16, loc=(0, 0, 1.36), parent=root)
    I.cyl(0.26, 0.55, red(), r2=0.08, segs=16, loc=(0, 0, 1.0), rot=(180, 0, 0), parent=root)
    I.cyl(0.16, 0.18, gold(), segs=16, loc=(0, 0, -1.92), parent=root)


def Heavy():
    root = I.empty("Hammer", rot=(0, 40, 0))
    I.cyl(0.11, 2.6, wood(), segs=16, loc=(0, 0, -0.2), parent=root)
    I.box(1.1, 0.62, 0.66, steel(), loc=(0, 0, 1.05), bevel=0.12, parent=root)
    I.box(0.24, 0.68, 0.72, gold(), loc=(0, 0, 1.05), bevel=0.05, parent=root)
    I.cyl(0.3, 0.5, steel_dark(), r2=0.0, segs=20, loc=(-0.78, 0, 1.05), rot=(0, -90, 0), parent=root, bevel=0.0)
    I.cyl(0.14, 0.14, gold(), segs=16, loc=(0, 0, -1.5), parent=root)
    I.cyl(0.13, 0.5, leather_dark(), segs=16, loc=(0, 0, -1.15), parent=root)


def Dagger():
    root = I.empty("Dagger", rot=(0, 45, 0))
    sword(parent=root, length=1.9, width=0.42, tip=0.35, blade=M("SteelBright", "#E4EBF2", metal=0.75, rough=0.2, coat=0.7))


def Gauntlet():
    root = I.empty("Fist", rot=(0, 25, 8))
    S = steel()
    I.cyl(0.48, 0.75, steel_dark(), segs=28, loc=(0, 0, -0.75), parent=root)
    I.torus(0.5, 0.07, gold(), rsegs=8, loc=(0, 0, -0.42), parent=root)
    I.box(0.95, 0.75, 0.85, S, loc=(0, 0, 0.05), bevel=0.2, parent=root)
    for i in range(4):
        x = -0.33 + 0.22 * i
        I.box(0.2, 0.36, 0.3, S, loc=(x, -0.42, 0.28), bevel=0.07, parent=root)
        I.sphere(0.07, gold(), loc=(x, -0.6, 0.33), parent=root)
    I.box(0.25, 0.4, 0.5, S, loc=(0.55, -0.15, -0.05), rot=(0, -25, 0), bevel=0.08, parent=root)


def Ranged():
    W = wood()
    I.torus(1.2, 0.09, W, arc=140, start=110, rsegs=12, loc=(0.55, 0, 0), rot=(90, 0, 0))
    a1, a2 = math.radians(110), math.radians(250)
    p1 = (0.55 + 1.2 * math.cos(a1), 0, 1.2 * math.sin(a1))
    p2 = (0.55 + 1.2 * math.cos(a2), 0, 1.2 * math.sin(a2))
    I.tube([p1, p2], 0.025, white(), segs=8)
    I.cyl(0.13, 0.4, leather_dark(), segs=14, loc=(-0.65, 0, 0))
    for p in (p1, p2):
        I.sphere(0.12, gold(), loc=p)
    I.cyl(0.04, 2.0, wood_dark(), segs=10, loc=(-0.1, -0.05, 0), rot=(0, 90, 0), bevel=0.0)
    I.cyl(0.13, 0.32, steel(), r2=0.0, segs=12, loc=(0.98, -0.05, 0), rot=(0, 90, 0), bevel=0.0)
    for rx in (0, 90):
        I.extrude([(0, 0), (0.35, 0.12), (0.4, 0.0), (0.35, -0.12)], 0.02, red(), loc=(-1.05, -0.05, 0),
                  rot=(rx, 0, 0), bevel=0.0)
    pose_all(I.empty("Bow", rot=(0, -40, 8)))


def Magic():
    root = I.empty("Staff", rot=(0, 30, 0))
    I.cyl(0.09, 3.0, wood(), segs=16, loc=(0, 0, -0.4), parent=root)
    I.sphere(0.45, M("Orb", "#8A3BFF", rough=0.1, coat=0.6, emit=0.45, emit_color="#7A2BFF"), loc=(0, 0, 1.55),
             parent=root)
    for i in range(3):
        r = math.radians(120 * i)
        I.cyl(0.07, 0.75, gold(), r2=0.02, segs=10, loc=(0.32 * math.cos(r), 0.32 * math.sin(r), 1.35),
              rot=(-25 * math.sin(r), 25 * math.cos(r), 0), parent=root)
    I.torus(0.22, 0.07, gold(), rsegs=8, loc=(0, 0, 1.05), parent=root)
    I.cyl(0.12, 0.14, gold(), segs=14, loc=(0, 0, -1.9), parent=root)


def Whip():
    pts, radii = [], []
    n = 80
    for i in range(n):
        t = i / (n - 1)
        a = t * 3.6 * math.pi
        r = 1.0 - 0.72 * t
        pts.append((r * math.cos(a), 0.06 * math.sin(t * 9), r * math.sin(a) * 0.85))
        radii.append(0.13 - 0.085 * t)
    I.tube(pts, radii, leather(), segs=12)
    # handle continues from the outer end of the coil, down to the bottom-right
    I.tube([(1.0, 0.0, 0.0), (1.12, -0.05, -0.45), (1.22, -0.1, -1.05)], [0.15, 0.17, 0.17], leather_dark(), segs=14)
    I.torus(0.17, 0.05, gold(), rsegs=8, loc=(1.11, -0.05, -0.4), rot=(0, 15, 0))
    I.sphere(0.21, gold(), loc=(1.24, -0.1, -1.16))
    pose_all(I.empty("Whip", rot=(0, 0, 6)))


# ----------------------------------------------------------------------------------------------------
# UI MARKS
# ----------------------------------------------------------------------------------------------------
def Lock():
    root = I.empty("Lock", rot=(0, 0, 12))
    I.torus(0.42, 0.13, steel(), arc=180, rsegs=12, loc=(0, 0, 0.28), rot=(90, 0, 0), parent=root)
    for x in (-0.42, 0.42):
        I.cyl(0.13, 0.32, steel(), segs=14, loc=(x, 0, 0.14), parent=root, bevel=0.0)
    I.box(1.25, 0.6, 1.0, gold(), loc=(0, 0, -0.4), bevel=0.16, parent=root)
    I.cyl(0.13, 0.2, black(), segs=16, loc=(0, -0.28, -0.28), rot=(90, 0, 0), parent=root, bevel=0.0)
    I.box(0.1, 0.2, 0.28, black(), loc=(0, -0.28, -0.47), bevel=0.02, parent=root)


def Check():
    root = I.empty("Check", rot=(0, 0, 10))
    pts = [(-0.95, 0.12), (-0.58, 0.48), (-0.25, 0.15), (0.62, 1.02), (0.98, 0.66), (-0.25, -0.58)]
    I.extrude(pts, 0.42, green(), bevel=0.1, parent=root)


def Arrow():
    root = I.empty("Arrow", rot=(0, 0, 10))
    I.extrude(arrow_points(2.0, 0.42, 1.1, 0.8), 0.42, M("Orange", "#FF9E1F", rough=0.28, coat=1.0), bevel=0.1,
              parent=root)


def Plus():
    root = I.empty("Plus", rot=(0, 0, 10))
    I.extrude(plus_points(1.0, 0.5), 0.45, green(), bevel=0.1, parent=root)


def Close():
    root = I.empty("Close", rot=(0, 45, 10))
    I.extrude(plus_points(1.0, 0.45), 0.45, red(), bevel=0.1, parent=root)


def Star():
    root = I.empty("Star", rot=(0, 0, 10))
    I.extrude(I.star_points(5, 1.0, 0.48), 0.5, gold(), bevel=0.12, parent=root)


RECIPES = {
    "Menu": MENU_RECIPES["Menu"],
    "Currency": {"Gold": Gold, "Diamond": Diamond, "RebirthCredit": RebirthCredit, "Key": Key,
                 "HealthHeart": HealthHeart, "ZoneBoost": ZoneBoost},
    "Stats": {"MaxHP": MaxHP, "Attack": Attack, "Defense": Defense, "Speed": Speed, "Crit": Crit, "GoldGain": GoldGain},
    "Items": {"Weapon": Weapon, "Helmet": Helmet, "Chest": Chest, "Legs": Legs, "Egg": Egg, "Trophy": Trophy,
              "Pet": Pet},
    "Categories": {"Sword": Sword, "Spear": Spear, "Heavy": Heavy, "Dagger": Dagger, "Gauntlet": Gauntlet,
                   "Ranged": Ranged, "Magic": Magic, "Whip": Whip},
    "Marks": {"Lock": Lock, "Check": Check, "Arrow": Arrow, "Plus": Plus, "Close": Close, "Star": Star},
}


# ----------------------------------------------------------------------------------------------------
# EXTRA UI MARKS (used by toasts, the admin button and the phone Menu button)
# ----------------------------------------------------------------------------------------------------
def Skull():
    bone = M("Bone", "#F1E9D2", rough=0.4, coat=0.6)
    root = I.empty("Skull", rot=(0, 0, 12))
    I.sphere(0.85, bone, loc=(0, 0, 0.2), scale=(1.0, 0.95, 0.92), parent=root)
    I.box(0.95, 0.75, 0.55, bone, loc=(0, -0.12, -0.5), bevel=0.22, parent=root)
    for x in (-0.34, 0.34):
        I.sphere(0.24, black(), loc=(x, -0.72, 0.05), scale=(1.0, 0.5, 1.15), parent=root)
    I.cyl(0.11, 0.12, black(), r2=0.0, segs=3, loc=(0, -0.82, -0.25), rot=(-90, 0, 0), parent=root, bevel=0.0)
    for x in (-0.24, -0.08, 0.08, 0.24):
        I.box(0.1, 0.1, 0.18, black(), loc=(x, -0.5, -0.62), bevel=0.02, parent=root)


def Info():
    root = I.empty("Info", rot=(0, 0, 10))
    I.cyl(1.0, 0.36, blue(), segs=48, rot=(90, 0, 0), bevel=0.08, parent=root)
    I.sphere(0.17, white(), loc=(0, -0.22, 0.48), scale=(1, 0.7, 1), parent=root)
    I.box(0.3, 0.2, 0.75, white(), loc=(0, -0.2, -0.18), bevel=0.08, parent=root)


def Warning():
    root = I.empty("Warning", rot=(0, 0, 10))
    I.extrude([(-1.05, -0.8), (1.05, -0.8), (0.0, 1.0)], 0.4, M("Orange", "#FF9E1F", rough=0.28, coat=1.0),
              bevel=0.14, parent=root)
    I.box(0.2, 0.2, 0.75, black(), loc=(0, -0.2, 0.0), bevel=0.06, parent=root)
    I.sphere(0.12, black(), loc=(0, -0.22, -0.52), parent=root)


def Crown():
    root = I.empty("Crown", rot=(0, 0, 10))
    pts = [(-1.0, -0.6), (1.0, -0.6), (1.05, 0.55), (0.55, 0.05), (0.0, 0.75), (-0.55, 0.05), (-1.05, 0.55)]
    I.extrude(pts, 0.5, gold(), bevel=0.1, parent=root)
    I.box(2.1, 0.62, 0.3, gold_deep(), loc=(0, 0, -0.5), bevel=0.08, parent=root)
    for x, z in ((-1.05, 0.62), (0.0, 0.84), (1.05, 0.62)):
        I.sphere(0.13, gold(), loc=(x, 0, z), parent=root)
    for x, m in ((-0.55, red()), (0.0, cyan()), (0.55, green())):
        I.sphere(0.12, m, loc=(x, -0.33, -0.5), parent=root)


def MenuLines():
    root = I.empty("MenuLines", rot=(0, 0, 10))
    I.box(1.9, 0.4, 1.7, wood(), bevel=0.2, parent=root)
    for z in (0.45, 0.0, -0.45):
        I.box(1.25, 0.2, 0.24, gold(), loc=(0, -0.22, z), bevel=0.08, parent=root)


RECIPES["Marks"].update({"Skull": Skull, "Info": Info, "Warning": Warning, "Crown": Crown, "MenuLines": MenuLines})
