"""Ranged V2: 12 builders, zone 1 -> 12, rebuilt from the icons (Icons/Weapons/Ranged) with more detail.
~1.4 m (5 studs) along Z. The origin is the hand grip.
- Bows: limbs along Z (top limb +Z), bow curve in the XZ plane facing the camera, string on the -X side, arrows fly
  towards +X. Muzzle = the arrow rest.
- Crossbows: stock along Z, the bolt points +Z, the prod spans X, the camera (-Y) sees the top; the trigger grip
  hangs towards +Y. Muzzle = the bolt tip.
- Guns / blowgun: barrel along Z, the muzzle points +Z, the pistol grip hangs towards -X. Muzzle = the barrel end."""
import math

import fyd_icons as I
import fyd_w2_parts as P
from fyd_weapons2 import pm, point

# ------------------------------------------------------------------------------------------------ bows
LIMB_SCALE = 1.35  # limbs are drawn thicker than real so the long thin bows stay readable (as in the icons)


def limb_points(half=0.6, depth=0.13, rc=0.0, z0=0.07, n=12, sign=1):
    """Points of one limb from the grip to the tip. sign=1 upper limb, -1 lower limb. rc = recurve (tips flick +X)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = -depth * t * t
        if rc and t > 0.75:
            x += rc * ((t - 0.75) / 0.25) ** 2
        pts.append((x, 0.0, sign * (z0 + (half - z0) * t)))
    return pts


def bow(material, half=0.6, depth=0.13, rc=0.0, r0=0.022, r1=0.008, n=12):
    tips = []
    for sign in (1, -1):
        pts = limb_points(half, depth, rc, n=n, sign=sign)
        radii = [LIMB_SCALE * (r0 + (r1 - r0) * i / n) for i in range(n + 1)]
        P.tube(pts, radii, material, segs=7, name="Limb")
        tips.append(pts[-1])
    return tips


def limb_at(t, half, depth, rc, sign):
    """Point of the limb at fraction t (same curve as limb_points)."""
    x = -depth * t * t
    if rc and t > 0.75:
        x += rc * ((t - 0.75) / 0.25) ** 2
    return (x, 0.0, sign * (0.07 + (half - 0.07) * t))


def bow_string(tips, material, r=0.005, nock=None):
    """Straight string between the tips (slightly inside them), optionally pulled to a nock point."""
    top, bot = tips
    a = (top[0] - 0.004, 0.0, top[2] - 0.012)
    b = (bot[0] - 0.004, 0.0, bot[2] + 0.012)
    pts = [a, nock, b] if nock else [a, b]
    P.tube(pts, r, material, segs=5, name="String")
    for p in (a, b):
        I.sphere(r * 1.8, material, segs=6, rings=4, loc=p, smooth=False, name="StringKnot")


def bow_grip(material, wrap=None, r=0.026, h=0.16):
    I.cyl(r, h, material, segs=12, loc=(0, 0, 0), scale=(1.15, 1, 1), bevel=0.0, smooth=False, name="Grip")
    if wrap is not None:
        pts = []
        turns = 4
        for i in range(turns * 10 + 1):
            u = i / (turns * 10)
            a = 2 * math.pi * turns * u
            pts.append((math.cos(a) * r * 1.2, math.sin(a) * r * 1.05, -0.07 + 0.14 * u))
        P.tube(pts, 0.0055, wrap, segs=5, name="GripWrap")


def tip_cap(pos, material, r=0.012, h=0.04, sign=1):
    I.cyl(r, h, material, r2=r * 0.4, segs=8, loc=(pos[0], 0, pos[2] - sign * h / 3), rot=(0 if sign > 0 else 180, 0, 0),
          bevel=0.0, smooth=False, name="TipCap")


def bow_points(tips):
    point("Tip", tips[0])
    point("Base", (0, 0, 0))
    point("Muzzle", (0.045, 0, 0.06))


# ------------------------------------------------------------------------------------------------ crossbows
def crossbow_stock(material, rail, z0=-0.5, z1=0.5, w=0.06, h=0.07):
    I.box(w, h, z1 - z0, material, loc=(0, 0, (z0 + z1) / 2), bevel=0.01, segments=2, smooth=False, name="Stock")
    I.box(w * 1.6, h * 1.1, 0.16, material, loc=(0, 0.01, z0 + 0.08), bevel=0.014, segments=2, smooth=False, name="Butt")
    I.box(0.014, 0.01, z1 - z0 - 0.12, rail, loc=(0, -h / 2 - 0.002, (z0 + z1) / 2 + 0.06), bevel=0.0, smooth=False,
          name="Rail")
    I.box(0.035, 0.11, 0.05, material, loc=(0, h / 2 + 0.045, -0.02), rot=(18, 0, 0), bevel=0.008, segments=2,
          smooth=False, name="TriggerGrip")
    I.box(0.008, 0.03, 0.012, rail, loc=(0, h / 2 + 0.012, 0.03), rot=(25, 0, 0), bevel=0.0, smooth=False, name="Trigger")


def prod(material, z=0.42, span=0.4, sweep=0.1, r0=0.022, r1=0.009, n=8):
    """Crossbow prod across X, curving back (-Z) to the tips. Returns the two tip positions."""
    tips = []
    for s in (-1, 1):
        pts, radii = [], []
        for i in range(n + 1):
            t = i / n
            pts.append((s * span * t, 0.0, z - sweep * t * t))
            radii.append(r0 + (r1 - r0) * t)
        P.tube(pts, radii, material, segs=7, name="Prod")
        tips.append(pts[-1])
    return tips


def crossbow_string(tips, material, latch_z=0.05, r=0.0035):
    left, right = tips
    P.tube([(left[0] + 0.004, 0, left[2]), (0, -0.04, latch_z), (right[0] - 0.004, 0, right[2])], r, material, segs=5,
           name="String")
    I.box(0.03, 0.012, 0.014, material, loc=(0, -0.04, latch_z), bevel=0.0, smooth=False, name="Latch")


def bolt(shaft_mat, tip_mat, z0=0.06, z1=0.6, r=0.009, fletch=None):
    I.cyl(r, z1 - z0, shaft_mat, segs=8, loc=(0, -0.045, (z0 + z1) / 2), bevel=0.0, smooth=False, name="Bolt")
    I.cyl(r * 2.2, 0.07, tip_mat, r2=0.0, segs=4, loc=(0, -0.045, z1 + 0.035), bevel=0.0, smooth=False, name="BoltTip")
    if fletch is not None:
        for s in (-1, 1):
            pts = [(0, 0), (s * 0.03, -0.01), (s * 0.03, 0.05), (0, 0.07)]
            P.plate([(x, z + z0 + 0.01) for x, z in (pts if s > 0 else list(reversed(pts)))], 0.003, fletch,
                    bevel=0.002, loc=(0, -0.045, 0), name="Fletch")
    point("Muzzle", (0, -0.045, z1 + 0.07))
    point("Tip", (0, -0.045, z1 + 0.07))
    point("Base", (0, 0, 0))


# ------------------------------------------------------------------------------------------------ guns
def pistol_grip(material, z=0.0, length=0.13, w=0.04):
    I.box(length, w, 0.05, material, loc=(-length / 2 - 0.02, 0, z), rot=(0, -12, 0), bevel=0.008, segments=2,
          smooth=False, name="PistolGrip")
    for k in range(3):
        I.box(0.004, w + 0.002, 0.046, material, loc=(-0.05 - k * 0.03, 0, z + 0.006 * k), rot=(0, -12, 0), bevel=0.0,
              smooth=False, name="GripRidge")


def trigger_guard(material, z=0.06):
    I.torus(0.03, 0.005, material, segs=14, rsegs=4, arc=180, start=180, loc=(-0.035, 0, z), rot=(90, 0, 90),
            name="TriggerGuard")
    I.box(0.006, 0.012, 0.022, material, loc=(-0.03, 0, z + 0.006), rot=(0, 20, 0), bevel=0.0, smooth=False,
          name="Trigger")


def gun_points(muzzle_z):
    point("Muzzle", (0, 0, muzzle_z))
    point("Tip", (0, 0, muzzle_z))
    point("Base", (0, 0, 0))


# ================================================================================================ builders
def plains():  # Hunting Bow: wooden longbow, leather grip, horn tip caps, linen string, arrow rest
    wood = pm("#8A5A33", rough=0.7, var=0.2, grain=True)
    leather = pm("#4A2E1A", rough=0.8, var=0.15)
    horn = pm("#E8DCC0", rough=0.5, var=0.08)
    tips = bow(wood, half=0.62, depth=0.16)
    bow_grip(leather, wrap=pm("#6B4426", rough=0.8, var=0.12))
    for tip, sign in zip(tips, (1, -1)):
        tip_cap(tip, horn, sign=sign)
    bow_string(tips, pm("#F2EAD8", rough=0.7, var=0.05))
    I.box(0.03, 0.01, 0.03, horn, loc=(-0.03, -0.02, 0.09), bevel=0.003, segments=1, smooth=False, name="ArrowRest")
    bow_points(tips)


def desert():  # Desert Recurve Bow: dark horn recurve limbs, gold tips and bands, cloth grip, turquoise gem
    horn = pm("#5A3A22", rough=0.5, var=0.15, grain=True)
    gold = pm("#E2B04A", metal=0.9, rough=0.3, var=0.08)
    cloth = pm("#E3CFA3", rough=0.85, var=0.12)
    half, depth, rc = 0.6, 0.21, 0.075
    tips = bow(horn, half=half, depth=depth, rc=rc, r0=0.024)
    bow_grip(cloth, wrap=gold)
    for tip, sign in zip(tips, (1, -1)):
        tip_cap(tip, gold, r=0.013, h=0.05, sign=sign)
    for sign in (1, -1):
        for t in (0.35, 0.65):
            I.torus(0.021, 0.006, gold, segs=12, rsegs=4, loc=limb_at(t, half, depth, rc, sign), name="LimbBand")
    P.socketed_gem(0.018, pm("#2EC4B6", rough=0.15, var=0.0), gold, (0.03, -0.012, 0.0))
    bow_string(tips, pm("#F2EAD8", rough=0.7, var=0.05))
    bow_points(tips)


def jungle():  # Poison Blowgun: bamboo tube with nodes, vine wraps, hanging feathers, glowing poison dart and vial
    bamboo = pm("#9DB04A", rough=0.55, var=0.15, grain=True)
    node = pm("#6E7F2E", rough=0.6, var=0.12)
    vine = pm("#3C8F3A", rough=0.6, var=0.15)
    wood = pm("#6E4A2A", rough=0.7, var=0.2, grain=True)
    poison = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    I.cyl(0.034, 1.25, bamboo, segs=12, loc=(0, 0, 0.215), bevel=0.0, smooth=False, name="Tube")
    for z in (-0.3, -0.05, 0.25, 0.55, 0.8):
        I.torus(0.035, 0.008, node, segs=12, rsegs=4, loc=(0, 0, z), name="Node")
    I.cyl(0.046, 0.08, wood, r2=0.034, segs=12, loc=(0, 0, -0.41), bevel=0.0, smooth=False, name="Mouthpiece")
    I.torus(0.044, 0.008, pm("#C0392B", rough=0.6, var=0.1), segs=12, rsegs=4, loc=(0, 0, -0.43), name="MouthRing")
    I.cyl(0.04, 0.05, node, segs=12, loc=(0, 0, 0.84), bevel=0.0, smooth=False, name="Muzzle")
    for k in range(5):
        I.torus(0.036, 0.006, vine, segs=12, rsegs=4, loc=(0, 0, -0.1 + k * 0.03), rot=(14 * (-1) ** k, 0, 0), name="Vine")
    I.cyl(0.008, 0.1, pm("#D9C9A0", rough=0.6, var=0.08), segs=6, loc=(0, 0, 0.9), bevel=0.0, smooth=False, name="Dart")
    I.cyl(0.016, 0.06, poison, r2=0.0, segs=6, loc=(0, 0, 0.98), bevel=0.0, smooth=False, name="DartTip")
    P.tube([(0.034, 0, 0.62), (0.055, 0, 0.615), (0.07, 0, 0.6), (0.085, 0, 0.53)], 0.004, wood, segs=5, name="Cord")
    for i, col in enumerate(("#E74C3C", "#F1C40F", "#2E86DE")):
        P.plate([(0, 0), (0.024, -0.05), (0.012, -0.12), (0.0, -0.18), (-0.012, -0.12), (-0.024, -0.05)], 0.006,
                pm(col, rough=0.6, var=0.12), bevel=0.004, loc=(0.085, 0, 0.535), rot=(0, -20 + 20 * i, 0), name="Feather")
    I.sphere(0.012, wood, segs=8, rings=5, loc=(0.085, 0, 0.53), smooth=False, name="Bead")
    I.cyl(0.024, 0.08, poison, segs=8, loc=(0.06, 0, 0.16), bevel=0.0, smooth=False, name="PoisonVial")
    I.cyl(0.017, 0.02, wood, segs=8, loc=(0.06, 0, 0.21), bevel=0.0, smooth=False, name="Cork")
    I.box(0.03, 0.012, 0.012, wood, loc=(0.045, 0, 0.16), bevel=0.0, smooth=False, name="VialStrap")
    gun_points(1.01)


def tundra():  # Frostbite Crossbow: steel and birch stock, ice prod with crystal tips, glowing ice bolt, fur
    birch = pm("#4A5D73", metal=0.3, rough=0.55, var=0.12, grain=True)
    steel = pm("#C9D3DC", metal=0.8, rough=0.3, var=0.06)
    ice = pm("#7CC8EE", rough=0.08, var=0.05)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    crossbow_stock(birch, steel)
    tips = prod(ice, z=0.42, span=0.42, sweep=0.12, r0=0.026, r1=0.01)
    I.box(0.09, 0.08, 0.06, steel, loc=(0, 0, 0.42), bevel=0.01, segments=2, smooth=False, name="ProdMount")
    for tip in tips:
        P.crystal((tip[0], 0, tip[2]), 0.014, 0.07, ice, tilt=(0, 90 if tip[0] > 0 else -90, 0))
    crossbow_string(tips, pm("#E8EEF2", rough=0.6, var=0.05))
    I.torus(0.05, 0.02, pm("#EDEAE4", rough=0.95, var=0.15, scale=120), segs=14, rsegs=6, loc=(0, 0.01, -0.3),
            scale=(0.9, 1.1, 1), name="Fur")
    for k, a in enumerate((-40, 0, 40)):
        P.crystal((0.0, -0.03, 0.44), 0.016, 0.09 + 0.03 * (k == 1), ice, tilt=(-20, a, 0))
    I.box(0.03, 0.074, 0.3, glow, loc=(0, 0, -0.08), bevel=0.0, smooth=False, name="FrostStrip")
    I.box(0.064, 0.064, 0.32, birch, loc=(0, 0, -0.08), bevel=0.008, segments=1, smooth=False, name="StockCover")
    bolt(steel, glow, z0=0.06, z1=0.62)


def swamp():  # Plague Bow: twisted dark wood, bone hooks, big rag, toxic drips, glowing string and a plague vial
    wood = pm("#4A3A2A", rough=0.85, var=0.22, grain=True)
    bone = pm("#D9CBA0", rough=0.55, var=0.1)
    rag = pm("#6E7A4A", rough=0.9, var=0.2)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    half, depth, rc = 0.6, 0.17, -0.03
    tips = bow(wood, half=half, depth=depth, rc=rc, r0=0.028, r1=0.011)
    for sign in (1, -1):
        pts = limb_points(half, depth, rc, n=8, sign=sign)
        P.tube([(p[0] + 0.016 * math.sin(i * 1.7), 0.016 * math.cos(i * 1.7), p[2]) for i, p in enumerate(pts[1:-1])],
               0.008, wood, segs=5, name="Twist")
        for i in (3, 5):
            I.sphere(0.011, toxic, segs=8, rings=5, loc=(pts[i][0] + 0.03, -0.01, pts[i][2] - 0.02), scale=(1, 0.7, 1.6),
                     smooth=False, name="Drip")
    bow_grip(rag, wrap=pm("#3E3A2E", rough=0.8, var=0.12))
    for tip, sign in zip(tips, (1, -1)):
        P.tube([(tip[0], 0, tip[2] - sign * 0.02), (tip[0] + 0.04, 0, tip[2] + sign * 0.02), (tip[0] + 0.08, 0, tip[2]),
                (tip[0] + 0.09, 0, tip[2] - sign * 0.03)], [0.016, 0.012, 0.007, 0.002], bone, segs=6, name="BoneHook")
    bow_string(tips, toxic)
    I.cyl(0.026, 0.08, toxic, segs=8, loc=(0.06, -0.01, -0.13), bevel=0.0, smooth=False, name="Vial")
    I.cyl(0.018, 0.02, bone, segs=8, loc=(0.06, -0.01, -0.08), bevel=0.0, smooth=False, name="Cork")
    P.plate([(0, 0), (0.08, -0.04), (0.07, -0.1), (0.06, -0.17), (0.03, -0.1), (0.0, -0.2), (-0.02, -0.09)], 0.006, rag,
            bevel=0.003, loc=(0.03, 0, 0.08), name="Rag")
    bow_points(tips)


def volcano():  # Flame Bow: obsidian limbs with lava veins, flame tips, rock grip, glowing string
    obs = pm("#2A2224", metal=0.3, rough=0.45, var=0.12, scale=70)
    rock = pm("#4A3834", rough=0.85, var=0.25, scale=50)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    half, depth, rc = 0.6, 0.22, 0.06
    tips = bow(obs, half=half, depth=depth, rc=rc, r0=0.026, r1=0.01)
    for sign in (1, -1):
        pts = limb_points(half, depth, rc, n=8, sign=sign)
        P.tube([(p[0], -0.03 + 0.012 * i / 8, p[2]) for i, p in enumerate(pts[1:-2])], 0.008, lava, segs=5, name="LavaVein")
    bow_grip(rock, wrap=pm("#8A1F12", rough=0.6, var=0.12))
    flame = [(0.0, 0.0), (0.03, 0.03), (0.02, 0.05), (0.045, 0.09), (0.01, 0.07), (0.0, 0.12), (-0.015, 0.06), (-0.03, 0.08),
             (-0.02, 0.03)]
    for tip, sign in zip(tips, (1, -1)):
        pts = [(x + tip[0], sign * z + tip[2] - sign * 0.02) for x, z in flame]
        P.plate(pts if sign > 0 else list(reversed(pts)), 0.016, lava, bevel=0.004, name="FlameTip")
    bow_string(tips, lava, r=0.004)
    I.ico(0.03, rock, loc=(0.03, 0, 0.0), scale=(1, 0.8, 1.3), name="Rock")
    P.gem(0.016, lava, (0.05, -0.012, 0.0), facets=8)
    bow_points(tips)


def hell():  # Soulfire Crossbow: black and red crossbow, spiked prod, demon skull front, soulfire bolt
    black = pm("#1E1414", rough=0.6, var=0.1)
    metal = pm("#6A1A16", metal=0.7, rough=0.3, var=0.12)
    edge = pm("#B23A2E", metal=0.7, rough=0.25, var=0.08)
    bone = pm("#E6D8C0", rough=0.5, var=0.1)
    soulfire = pm("#FF3A20", emit=3.0, emit_color="#FF2A10")
    crossbow_stock(black, edge)
    tips = prod(metal, z=0.42, span=0.42, sweep=0.1, r0=0.028, r1=0.01)
    for s in (-1, 1):
        for t in (0.35, 0.7):
            x, z = s * 0.42 * t, 0.42 - 0.1 * t * t
            P.spike((x, 0, z + 0.01), (x + s * 0.02, 0, z + 0.08), 0.012, edge, segs=5)
    crossbow_string(tips, pm("#FF6040", rough=0.4, var=0.05))
    I.sphere(0.05, bone, segs=12, rings=8, loc=(0, 0, 0.47), scale=(1, 0.9, 0.95), smooth=False, name="Skull")
    I.box(0.04, 0.03, 0.022, bone, loc=(0, -0.012, 0.432), bevel=0.004, segments=1, smooth=False, name="Jaw")
    for x in (-0.02, 0.02):
        I.sphere(0.011, soulfire, segs=6, rings=4, loc=(x, -0.043, 0.48), smooth=False, name="Eye")
    for s in (-1, 1):
        P.tube([(s * 0.03, 0, 0.5), (s * 0.05, 0, 0.53), (s * 0.07, 0, 0.55), (s * 0.06, 0, 0.6)],
               [0.012, 0.01, 0.008, 0.002], bone, segs=6, name="Horn")
    I.box(0.05, 0.02, 0.18, metal, loc=(0, -0.042, -0.2), bevel=0.004, segments=1, smooth=False, name="Plate")
    for z in (-0.27, -0.13):
        P.rivet((0, -0.053, z), 0.006, edge)
    bolt(black, soulfire, z0=0.06, z1=0.64)


def heaven():  # Dawn Bow: gold limbs with scalloped white wings, sun disc with rays at the grip, golden string
    white = pm("#FFFFFF", rough=0.4, var=0.05)
    gold = pm("#E8B84A", metal=0.9, rough=0.25, var=0.08)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    half, depth, rc = 0.6, 0.2, 0.05
    tips = bow(gold, half=half, depth=depth, rc=rc, r0=0.022, r1=0.009)
    for sign in (1, -1):
        pts = limb_points(half, depth, rc, n=8, sign=sign)
        inner = [(pts[i][0] + 0.012, pts[i][2]) for i in range(1, 8)]
        outer = []
        for i in range(7, 0, -1):
            w = 0.04 + 0.1 * (1 - (i - 1) / 7)
            x, z = pts[i][0], pts[i][2]
            outer.append((x + w, z + sign * 0.04))
            outer.append((x + w * 0.92, z + sign * 0.005))
            outer.append((x + w * 0.62, z - sign * 0.025))
        poly = inner + outer
        P.plate(poly if sign > 0 else list(reversed(poly)), 0.012, white, bevel=0.005, loc=(0, 0.004, 0), name="Wing")
    bow_grip(white, wrap=gold)
    I.cyl(0.06, 0.012, gold, segs=20, loc=(0.015, -0.02, 0.0), rot=(90, 0, 0), bevel=0.0, smooth=False, name="SunDisc")
    I.cyl(0.04, 0.016, sun, segs=20, loc=(0.015, -0.024, 0.0), rot=(90, 0, 0), bevel=0.0, smooth=False, name="Sun")
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        P.spike((0.015 + 0.06 * math.cos(a), -0.02, 0.06 * math.sin(a)), (0.015 + 0.085 * math.cos(a), -0.02, 0.085 * math.sin(a)),
                0.008, gold, segs=4)
    bow_string(tips, sun)
    bow_points(tips)


def dead():  # Bone Crossbow: vertebra stock, rib prod, skull front, green soul bolt
    bone = pm("#E6DCC0", rough=0.55, var=0.1)
    dark = pm("#3A3440", rough=0.75, var=0.1)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    crossbow_stock(dark, bone)
    for k in range(6):
        I.box(0.075, 0.05, 0.03, bone, loc=(0, -0.012, -0.36 + k * 0.06), bevel=0.006, segments=2, smooth=False,
              name="Vertebra")
        P.spike((0, -0.03, -0.36 + k * 0.06), (0, -0.055, -0.35 + k * 0.06), 0.008, bone, segs=4)
    tips = prod(bone, z=0.42, span=0.4, sweep=0.14, r0=0.034, r1=0.012)
    for s in (-1, 1):
        P.tube([(s * 0.05, 0, 0.4), (s * 0.12, 0, 0.385), (s * 0.18, 0, 0.36), (s * 0.24, 0, 0.3)],
               [0.012, 0.011, 0.009, 0.003], bone, segs=6, name="Rib")
    crossbow_string(tips, pm("#B8B2A0", rough=0.7, var=0.05))
    I.sphere(0.06, bone, segs=12, rings=8, loc=(0, -0.035, 0.43), scale=(1, 0.9, 0.95), smooth=False, name="Skull")
    I.box(0.05, 0.035, 0.03, bone, loc=(0, -0.055, 0.385), bevel=0.006, segments=1, smooth=False, name="Jaw")
    for x in (-0.017, 0.017):
        I.sphere(0.014, soul, segs=6, rings=4, loc=(x * 1.3, -0.084, 0.44), smooth=False, name="Eye")
    P.gem(0.02, soul, (0, -0.05, -0.12), facets=8)
    bolt(bone, soul, z0=0.06, z1=0.66)


def abyss():  # Harpoon Gun: teal-brass gun with a loaded harpoon, coiled rope, pressure tank, pistol grip (-X)
    brass = pm("#C9A04A", metal=0.85, rough=0.35, var=0.08)
    teal = pm("#3FB5C8", metal=0.65, rough=0.22, var=0.1)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4, var=0.1)
    rope = pm("#D9C9A0", rough=0.8, var=0.12, grain=True)
    glow = pm("#5FFFF0", emit=2.5, emit_color="#40F0E0")
    steel = pm("#B8C2CE", metal=0.85, rough=0.3, var=0.05)
    I.cyl(0.045, 0.7, teal, segs=14, loc=(0, 0, 0.2), bevel=0.0, smooth=False, name="Barrel")
    I.cyl(0.055, 0.07, brass, segs=14, loc=(0, 0, 0.55), bevel=0.0, smooth=False, name="Muzzle")
    I.cyl(0.012, 0.25, steel, segs=8, loc=(0, 0, 0.66), bevel=0.0, smooth=False, name="HarpoonShaft")
    I.cyl(0.04, 0.11, steel, r2=0.0, segs=4, loc=(0, 0, 0.83), bevel=0.0, smooth=False, name="HarpoonTip")
    for s in (-1, 1):
        P.spike((s * 0.012, 0, 0.78), (s * 0.055, 0, 0.73), 0.01, steel, segs=4)
    I.box(0.07, 0.06, 0.4, dark, loc=(-0.01, 0, -0.32), bevel=0.012, segments=2, smooth=False, name="Stock")
    pistol_grip(dark, z=-0.05, length=0.14)
    trigger_guard(brass, z=0.02)
    I.cyl(0.04, 0.2, brass, segs=14, loc=(0.065, 0, 0.12), bevel=0.0, smooth=False, name="Tank")
    for z in (0.03, 0.21):
        I.torus(0.04, 0.005, brass, segs=14, rsegs=4, loc=(0.065, 0, z), name="TankRing")
    I.cyl(0.02, 0.02, glow, segs=12, loc=(0.065, -0.035, 0.12), rot=(90, 0, 0), bevel=0.0, smooth=False, name="Gauge")
    for k in range(4):
        I.torus(0.05, 0.009, rope, segs=14, rsegs=4, loc=(0, 0, 0.3 + k * 0.02), name="Rope")
    for z in (-0.05, 0.4):
        I.torus(0.047, 0.007, brass, segs=14, rsegs=4, loc=(0, 0, z), name="BarrelRing")
    for x, z, r in ((0.02, -0.25, 0.018), (-0.01, -0.33, 0.014), (0.025, -0.4, 0.012)):
        I.cyl(r, r * 1.1, pm("#D8D2C0", rough=0.7, var=0.12), r2=r * 0.45, segs=6, loc=(x, -0.034, z), rot=(90, 0, 0),
              bevel=0.0, smooth=False, name="Barnacle")
    I.box(0.012, 0.094, 0.5, glow, loc=(0.0, 0, 0.2), bevel=0.0, smooth=False, name="GlowStrip")
    gun_points(0.885)


def mechanical():  # Pulse Rifle: sci-fi rifle, energy coils, cyan barrel glow, scope, magazine, pistol grip (-X)
    metal = pm("#9AA4B2", metal=0.85, rough=0.3, var=0.06)
    dark = pm("#3A3F48", metal=0.8, rough=0.35, var=0.08)
    yellow = pm("#FFC21F", rough=0.4, var=0.06)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    I.box(0.09, 0.06, 0.5, dark, loc=(0, 0, 0.05), bevel=0.012, segments=2, smooth=False, name="Body")
    for z in (-0.12, 0.0, 0.12):
        I.box(0.092, 0.004, 0.06, pm("#454B55", metal=0.8, rough=0.35, var=0.06), loc=(0, -0.03, z), bevel=0.0,
              smooth=False, name="Panel")
    I.cyl(0.024, 0.42, metal, segs=14, loc=(0, 0, 0.5), bevel=0.0, smooth=False, name="Barrel")
    for k in range(4):
        I.torus(0.033, 0.008, plasma if k % 2 == 0 else dark, segs=14, rsegs=4, loc=(0, 0, 0.36 + k * 0.06), name="Coil")
    I.cyl(0.032, 0.05, dark, segs=14, loc=(0, 0, 0.72), bevel=0.0, smooth=False, name="Muzzle")
    I.cyl(0.018, 0.02, plasma, segs=14, loc=(0, 0, 0.75), bevel=0.0, smooth=False, name="MuzzleGlow")
    I.box(0.06, 0.05, 0.32, metal, loc=(0.0, 0, -0.35), bevel=0.012, segments=2, smooth=False, name="Stock")
    I.box(0.05, 0.03, 0.12, dark, loc=(0.02, 0, -0.46), bevel=0.006, segments=1, smooth=False, name="ButtPad")
    pistol_grip(dark, z=-0.05, length=0.13)
    trigger_guard(metal, z=0.02)
    I.box(0.11, 0.04, 0.06, yellow, loc=(-0.09, 0, 0.13), rot=(0, 10, 0), bevel=0.006, segments=2, smooth=False,
          name="Magazine")
    I.box(0.006, 0.042, 0.04, plasma, loc=(-0.13, 0, 0.13), rot=(0, 10, 0), bevel=0.0, smooth=False, name="Charge")
    I.cyl(0.022, 0.16, dark, segs=12, loc=(0.075, 0, 0.1), bevel=0.0, smooth=False, name="Scope")
    I.cyl(0.016, 0.01, plasma, segs=12, loc=(0.075, 0, 0.185), bevel=0.0, smooth=False, name="ScopeLens")
    for z in (0.04, 0.16):
        I.box(0.03, 0.02, 0.015, dark, loc=(0.055, 0, z), bevel=0.0, smooth=False, name="ScopeMount")
    I.box(0.012, 0.062, 0.3, plasma, loc=(0.046, 0, 0.0), bevel=0.0, smooth=False, name="SideStrip")
    gun_points(0.76)


def void():  # Starfall Bow: dark crystal limbs with crystal fins, star tips, crystal grip, floating stars, orbit
    dark = pm("#3A2C55", metal=0.35, rough=0.15, var=0.1)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2, var=0.08)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    half, depth, rc = 0.6, 0.23, 0.07
    tips = bow(dark, half=half, depth=depth, rc=rc, r0=0.026, r1=0.01)
    for sign in (1, -1):
        pts = limb_points(half, depth, rc, n=8, sign=sign)
        for i in (2, 4, 6):
            P.crystal((pts[i][0] + 0.02, 0, pts[i][2]), 0.018, 0.085, dark, tilt=(0, 70 - sign * 15, 0))
    bow_grip(obs, wrap=glow)
    P.crystal((0.03, 0, 0.0), 0.022, 0.08, glow, tilt=(0, 90, 0))
    for tip, sign in zip(tips, (1, -1)):
        star = [(x + tip[0], z + tip[2] + sign * 0.03) for x, z in I.star_points(5, 0.05, 0.022)]
        P.plate(star, 0.014, glow, bevel=0.005, name="StarTip")
    bow_string(tips, glow, r=0.004)
    for x, z, r in ((0.12, 0.3, 0.025), (0.15, -0.22, 0.02), (0.09, 0.48, 0.016)):
        P.plate([(px + x, pz + z) for px, pz in I.star_points(5, r, r * 0.45)], 0.008, glow, bevel=0.003, name="Star")
    I.torus(0.07, 0.005, glow, segs=22, rsegs=4, loc=(0.02, 0, 0.0), rot=(75, 0, 0), name="Orbit")
    bow_points(tips)


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
