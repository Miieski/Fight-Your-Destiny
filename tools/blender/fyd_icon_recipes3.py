"""Kid-friendly UI icons (owner 2026-10-13: "the UI must be understandable for a 5 years old: avoid text, be more
visual"). Same template and style as the Part A icons (fyd_icons + fyd_icon_recipes / 2). Group "Ui":
Icons/Ui/<id>.png, Blender/Icons/Ui/<id>.blend. Shapes face -Y; extrude() draws in the XZ plane."""
import math

import fyd_icons as I
from fyd_icon_recipes import M, black, blue, cream, gold, gold_deep, green, red, red_dark, steel, steel_dark, white, wood
from fyd_icon_recipes2 import plus_points, pose_all


def orange():
    return M("Orange", "#FF9E1F", rough=0.28, coat=1.0)


def teal():
    return M("Teal", "#20C7B4", rough=0.3, coat=1.0)


def grey():
    return M("Grey", "#5C6470", rough=0.35, coat=0.8)


def ring_arrow(material, r=0.85, w=0.26, arc=290, start=110, head=0.5, depth=0.36, parent=None, clockwise=False):
    """A curved arrow (open ring + triangular head) in the XZ plane."""
    outer = I.circle_points(r + w / 2, n=40, start=start, arc=arc)
    inner = list(reversed(I.circle_points(r - w / 2, n=40, start=start, arc=arc)))
    I.extrude(outer + inner, depth, material, bevel=0.06, parent=parent)
    end = math.radians(start + arc)
    cx, cz = r * math.cos(end), r * math.sin(end)
    tx, tz = -math.sin(end), math.cos(end)  # tangent (counter-clockwise)
    nx, nz = math.cos(end), math.sin(end)
    tip = (cx + tx * head, cz + tz * head)
    a = (cx + nx * head * 0.6, cz + nz * head * 0.6)
    b = (cx - nx * head * 0.6, cz - nz * head * 0.6)
    I.extrude([a, tip, b], depth, material, bevel=0.06, parent=parent)


# ----------------------------------------------------------------------------------------------------
def Clock():
    root = I.empty("Clock", rot=(0, 0, 10))
    I.cyl(1.0, 0.42, gold(), segs=48, rot=(90, 0, 0), bevel=0.1, parent=root)
    I.cyl(0.8, 0.46, white(), segs=48, rot=(90, 0, 0), bevel=0.04, parent=root)
    for i in range(12):
        a = math.radians(i * 30)
        I.box(0.06, 0.06, 0.12 if i % 3 else 0.2, black(), loc=(0.66 * math.sin(a), -0.24, 0.66 * math.cos(a)),
              rot=(0, -i * 30, 0), bevel=0.01, parent=root)
    I.box(0.11, 0.08, 0.5, black(), loc=(0, -0.27, 0.22), bevel=0.03, parent=root)
    I.box(0.4, 0.08, 0.11, black(), loc=(0.18, -0.27, 0), bevel=0.03, parent=root)
    I.cyl(0.08, 0.1, red(), segs=16, rot=(90, 0, 0), loc=(0, -0.3, 0), parent=root)
    for x in (-0.62, 0.62):
        I.sphere(0.3, red(), loc=(x, 0, 0.92), scale=(1, 0.7, 0.75), parent=root)
    for x in (-0.5, 0.5):
        I.box(0.12, 0.12, 0.3, gold_deep(), loc=(x, 0, -1.0), rot=(0, 25 if x > 0 else -25, 0), parent=root)


def Gift():
    root = I.empty("Gift", rot=(0, 0, 10))
    I.box(1.7, 1.2, 1.25, red(), loc=(0, 0, -0.3), bevel=0.1, parent=root)
    I.box(1.85, 1.35, 0.38, red_dark(), loc=(0, 0, 0.42), bevel=0.1, parent=root)
    I.box(0.36, 1.28, 1.72, gold(), loc=(0, 0, -0.06), bevel=0.06, parent=root)  # ribbon around, top to bottom
    I.box(1.76, 1.28, 0.32, gold(), loc=(0, 0, -0.3), bevel=0.06, parent=root)  # ribbon around, side to side
    for side in (-1, 1):
        I.torus(0.32, 0.11, gold(), rsegs=10, loc=(side * 0.34, 0, 0.85), rot=(90, side * 20, 0),
                scale=(1, 1, 0.75), parent=root)
    I.sphere(0.18, gold_deep(), loc=(0, 0, 0.7), parent=root)


def Calendar():
    root = I.empty("Calendar", rot=(0, 0, 10))
    I.box(1.8, 0.35, 1.7, white(), loc=(0, 0, -0.1), bevel=0.12, parent=root)
    I.box(1.84, 0.4, 0.5, red(), loc=(0, -0.02, 0.62), bevel=0.12, parent=root)
    for x in (-0.5, 0.5):
        I.torus(0.18, 0.07, steel(), rsegs=10, loc=(x, 0, 0.92), rot=(0, 90, 0), parent=root)
    for r in range(3):
        for c in range(4):
            done = r * 4 + c < 6
            I.box(0.26, 0.1, 0.22, green() if done else cream(), loc=(-0.6 + c * 0.4, -0.2, 0.1 - r * 0.38),
                  bevel=0.04, parent=root)


def Ticket():
    root = I.empty("Ticket", rot=(0, 0, -12))
    pts = []
    pts += [(-1.1, -0.6), (1.1, -0.6)]
    pts += [(1.1 - 0.22 * math.sin(math.radians(a)), 0.22 * math.cos(math.radians(a)) * -1) for a in range(0, 181, 20)]
    pts += [(1.1, 0.6), (-1.1, 0.6)]
    pts += [(-1.1 + 0.22 * math.sin(math.radians(a)), 0.22 * math.cos(math.radians(a))) for a in range(0, 181, 20)]
    I.extrude(pts, 0.3, orange(), bevel=0.06, parent=root)
    I.extrude(I.star_points(5, 0.38, 0.17), 0.36, gold(), loc=(0.2, -0.04, 0), bevel=0.05, parent=root)
    for z in (-0.4, -0.15, 0.1, 0.35):
        I.box(0.06, 0.34, 0.12, gold_deep(), loc=(-0.55, 0, z), bevel=0.02, parent=root)


def Speaker():
    root = I.empty("Speaker", rot=(0, 0, 10))
    I.box(0.55, 0.6, 0.8, grey(), loc=(-0.65, 0, 0), bevel=0.1, parent=root)
    I.cyl(0.4, 0.8, grey(), r2=0.95, segs=32, rot=(0, 90, 0), loc=(-0.05, 0, 0), bevel=0.04, parent=root)
    for i, r in enumerate((0.75, 1.15)):
        arc = I.torus(r, 0.08, blue(), segs=32, rsegs=10, arc=100, start=-50, loc=(0.1, 0, 0), rot=(90, 0, 0),
                      parent=root)


def Music():
    root = I.empty("Music", rot=(0, 0, 10))
    P = M("NotePurple", "#7A3CFF", rough=0.28, coat=1.0)
    for x in (-0.55, 0.55):
        I.sphere(0.34, P, loc=(x, 0, -0.65), scale=(1.25, 0.8, 0.9), rot=(0, -25, 0), parent=root)
        I.box(0.12, 0.16, 1.45, P, loc=(x + 0.33, 0, 0.05), bevel=0.03, parent=root)
    I.box(1.25, 0.18, 0.28, P, loc=(0.33, 0, 0.72), rot=(0, -8, 0), bevel=0.05, parent=root)


def Eye():
    root = I.empty("Eye", rot=(0, 0, 8))
    I.sphere(1.0, white(), loc=(0, 0, 0), scale=(1.15, 0.5, 0.68), parent=root)
    I.cyl(0.46, 0.2, blue(), segs=40, rot=(90, 0, 0), loc=(0, -0.42, 0), bevel=0.03, parent=root)
    I.cyl(0.22, 0.24, black(), segs=32, rot=(90, 0, 0), loc=(0, -0.46, 0), bevel=0.02, parent=root)
    I.sphere(0.08, white(), loc=(-0.12, -0.6, 0.12), parent=root)


def Gamepad():
    root = I.empty("Gamepad", rot=(0, 0, 8))
    body = grey()
    I.box(1.6, 0.55, 0.9, body, loc=(0, 0, 0.05), bevel=0.3, parent=root)
    for x in (-0.75, 0.75):
        I.sphere(0.5, body, loc=(x, 0, -0.25), scale=(1, 0.55, 1.1), parent=root)
    I.box(0.48, 0.12, 0.14, black(), loc=(-0.55, -0.3, 0.05), bevel=0.03, parent=root)
    I.box(0.14, 0.12, 0.48, black(), loc=(-0.55, -0.3, 0.05), bevel=0.03, parent=root)
    for (x, z), m in zip(((0.55, 0.25), (0.8, 0.02), (0.55, -0.2), (0.3, 0.02)), (green(), red(), blue(), gold())):
        I.cyl(0.11, 0.14, m, segs=20, rot=(90, 0, 0), loc=(x, -0.3, z), parent=root)


def Keyboard():
    root = I.empty("Keyboard", rot=(-8, 0, 6))
    I.box(2.0, 0.4, 1.05, grey(), bevel=0.12, parent=root)
    for r in range(3):
        n = 6 - (1 if r == 2 else 0)
        for c in range(n):
            I.box(0.24, 0.16, 0.22, white(), loc=(-0.72 + c * 0.29 + r * 0.06, -0.2, 0.3 - r * 0.28), bevel=0.04,
                  parent=root)
    I.box(1.0, 0.16, 0.2, white(), loc=(0, -0.2, -0.42), bevel=0.04, parent=root)


def Funnel():
    root = I.empty("Funnel", rot=(0, 0, 8))
    I.cyl(0.22, 0.85, teal(), r2=1.0, segs=40, loc=(0, 0, 0.35), bevel=0.04, parent=root)  # wide at the top
    I.cyl(0.22, 0.8, teal(), segs=24, loc=(0, 0, -0.45), bevel=0.04, parent=root)
    I.torus(1.0, 0.08, M("TealDeep", "#108C80", rough=0.3, coat=1.0), segs=40, rsegs=8, loc=(0, 0, 0.78),
            parent=root)


def Sort():
    root = I.empty("Sort", rot=(0, 0, 8))
    up = [(-0.25, -0.9), (0.25, -0.9), (0.25, 0.2), (0.6, 0.2), (0.0, 0.95), (-0.6, 0.2), (-0.25, 0.2)]
    I.extrude([(x - 0.5, z) for x, z in up], 0.36, green(), bevel=0.06, parent=root)
    I.extrude([(x + 0.5, -z) for x, z in up], 0.36, orange(), bevel=0.06, parent=root)


def Dice():
    root = I.empty("Dice", rot=(20, 0, 25))
    I.box(1.4, 1.4, 1.4, white(), bevel=0.24, segments=4, parent=root)
    dot = black()
    for x, z in ((-0.35, 0.35), (0, 0), (0.35, -0.35)):
        I.sphere(0.12, dot, loc=(x, -0.68, z), scale=(1, 0.4, 1), parent=root)
    for x, z in ((-0.3, 0.3), (0.3, -0.3)):
        I.sphere(0.12, dot, loc=(0.68, x, z), scale=(0.4, 1, 1), parent=root)
    I.sphere(0.13, red(), loc=(0, 0, 0.7), scale=(1, 1, 0.4), parent=root)


def Trash():
    root = I.empty("Trash", rot=(0, 0, 8))
    I.cyl(0.62, 1.35, steel(), r2=0.78, segs=32, loc=(0, 0, -0.2), bevel=0.04, parent=root)
    for a in (-35, 0, 35):
        x = 0.62 * math.sin(math.radians(a))
        I.box(0.09, 0.09, 1.0, steel_dark(), loc=(x, -0.68 * math.cos(math.radians(a)) + 0.02, -0.2), bevel=0.02,
              parent=root)
    I.cyl(0.88, 0.16, steel_dark(), segs=32, loc=(0, 0, 0.58), bevel=0.04, parent=root)
    I.torus(0.2, 0.06, steel_dark(), rsegs=8, arc=180, loc=(0, 0, 0.66), rot=(90, 0, 0), parent=root)


def Reset():
    root = I.empty("Reset", rot=(0, 0, 8))
    ring_arrow(M("ResetBlue", "#2E9BFF", rough=0.28, coat=1.0), r=0.78, w=0.3, arc=280, start=120, head=0.48,
               depth=0.4, parent=root)


def Invite():
    root = I.empty("Invite", rot=(0, 0, 8))
    shirt = blue()
    I.sphere(0.42, M("Skin", "#FFD0A1", rough=0.45, coat=0.6), loc=(-0.3, 0, 0.55), parent=root)
    I.sphere(0.7, shirt, loc=(-0.3, 0, -0.55), scale=(1, 0.75, 0.75), parent=root)
    I.extrude(plus_points(0.5, 0.26), 0.36, green(), loc=(0.72, -0.25, 0.25), bevel=0.06, parent=root)


def MapPin():
    root = I.empty("MapPin", rot=(0, 0, 8))
    I.lathe([(0, -1.05), (0.25, -0.55), (0.6, 0.0), (0.72, 0.35), (0.62, 0.72), (0.35, 0.95), (0, 1.02)], red(),
            segs=40, parent=root)
    I.sphere(0.26, white(), loc=(0, -0.55, 0.38), scale=(1, 0.5, 1), parent=root)


def Up():
    root = I.empty("Up", rot=(0, 0, 8))
    pts = [(-0.32, -1.0), (0.32, -1.0), (0.32, 0.05), (0.8, 0.05), (0.0, 1.0), (-0.8, 0.05), (-0.32, 0.05)]
    I.extrude(pts, 0.45, green(), bevel=0.1, parent=root)


# --- pet Bonus Stats (owner 2026-10-13): Luck, the Accessory and Aura slots, "All stats" ----------------------
def Clover():
    root = I.empty("Clover", rot=(0, 0, 8))
    leaf = M("CloverGreen", "#3DCB5A", rough=0.3, coat=1.0)
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        I.sphere(0.5, leaf, loc=(0.42 * math.cos(r), 0, 0.42 * math.sin(r) + 0.15), scale=(1, 0.42, 1), parent=root)
    I.sphere(0.2, M("CloverDeep", "#1F9A3C", rough=0.3, coat=1.0), loc=(0, -0.12, 0.15), scale=(1, 0.5, 1),
             parent=root)
    I.box(0.14, 0.14, 0.9, M("CloverStem", "#1F9A3C", rough=0.35, coat=0.8), loc=(0.18, 0, -0.62), rot=(0, -20, 0),
          bevel=0.05, parent=root)


def Collar():
    root = I.empty("Collar", rot=(-25, 0, 8))
    I.torus(0.8, 0.17, red(), segs=48, rsegs=12, rot=(90, 0, 0), parent=root)
    I.box(0.3, 0.24, 0.3, gold_deep(), loc=(0, -0.05, -0.8), bevel=0.05, parent=root)
    I.sphere(0.36, gold(), loc=(0, -0.2, -1.2), parent=root)
    I.box(0.08, 0.1, 0.18, black(), loc=(0, -0.52, -1.3), bevel=0.02, parent=root)


def Aura():
    root = I.empty("Aura", rot=(0, 0, 8))
    swirl = M("AuraViolet", "#B36BFF", rough=0.2, coat=1.0, emit=0.6)
    for i, r in enumerate((0.95, 0.65, 0.36)):
        ring_arrow(swirl if i != 1 else M("AuraPink", "#FF7AD9", rough=0.2, coat=1.0, emit=0.6), r=r, w=0.16,
                   arc=250, start=40 + i * 110, head=0.0001, depth=0.3, parent=root)
    I.extrude(I.star_points(4, 0.32, 0.11), 0.3, M("AuraSpark", "#FFF3A6", rough=0.2, coat=1.0, emit=1.0),
              loc=(0, -0.3, 0), parent=root)


def AllStats():
    root = I.empty("AllStats", rot=(0, 0, 8))
    colors = ("#FF4D5A", "#FF9E1F", "#FFD23A", "#3DCB5A", "#2E9BFF", "#B36BFF")
    for i, c in enumerate(colors):
        I.extrude(I.star_points(5, 1.0 - i * 0.14, (1.0 - i * 0.14) * 0.46), 0.18,
                  M(f"Rainbow{i}", c, rough=0.25, coat=1.0), loc=(0, -0.1 * i, 0), parent=root)


RECIPES = {
    "Ui": {
        "Clock": Clock, "Gift": Gift, "Calendar": Calendar, "Ticket": Ticket, "Speaker": Speaker, "Music": Music,
        "Eye": Eye, "Gamepad": Gamepad, "Keyboard": Keyboard, "Funnel": Funnel, "Sort": Sort, "Dice": Dice,
        "Trash": Trash, "Reset": Reset, "Invite": Invite, "MapPin": MapPin, "Up": Up,
        "Clover": Clover, "Collar": Collar, "Aura": Aura, "AllStats": AllStats,
    },
}
