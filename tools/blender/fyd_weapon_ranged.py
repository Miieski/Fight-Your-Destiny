"""Ranged category: 12 builders, zone 1 -> 12. ~1.4 m (5 studs) along Z. The origin is the hand grip.
- Bows: limbs along Z (top limb +Z), bow curve in the XZ plane facing the camera, string on the -X side, arrows
  fly towards +X.
- Crossbows: stock along Z, the bolt points +Z, the prod spans X, the camera (-Y) sees the top; the trigger grip
  hangs towards +Y.
- Guns / blowgun: barrel along Z, the muzzle points +Z, the pistol grip hangs towards -X (side profile faces -Y)."""
import math

import fyd_icons as I
from fyd_weapon_parts import crystal, gem, spike
from fyd_weapons import pm


# ------------------------------------------------------------------------------------------------ bows
LIMB_SCALE = 1.35  # limbs are drawn thicker than real so the long thin bows stay readable in the icons


def limb_points(half=0.6, depth=0.13, rc=0.0, z0=0.07, n=8, sign=1):
    """Points of one limb from the grip to the tip. sign=1 upper limb, -1 lower limb. rc = recurve (tips flick +X)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = -depth * t * t
        if rc and t > 0.75:
            x += rc * ((t - 0.75) / 0.25) ** 2
        pts.append((x, 0.0, sign * (z0 + (half - z0) * t)))
    return pts


def bow(material, half=0.6, depth=0.13, rc=0.0, r0=0.022, r1=0.008, n=8):
    tips = []
    for sign in (1, -1):
        pts = limb_points(half, depth, rc, n=n, sign=sign)
        radii = [LIMB_SCALE * (r0 + (r1 - r0) * i / n) for i in range(n + 1)]
        I.tube(pts, radii, material, segs=6, name="Limb")
        tips.append(pts[-1])
    return tips


def bow_string(tips, material, r=0.005, nock=None):
    """Straight string between the tips (slightly inside them), optionally pulled to a nock point."""
    top, bot = tips
    a = (top[0] - 0.004, 0.0, top[2] - 0.012)
    b = (bot[0] - 0.004, 0.0, bot[2] + 0.012)
    pts = [a, nock, b] if nock else [a, b]
    I.tube(pts, r, material, segs=5, name="String")


def bow_grip(material, wrap=None, r=0.026, h=0.16):
    I.cyl(r, h, material, segs=10, loc=(0, 0, 0), scale=(1.15, 1, 1), bevel=0.0, name="Grip")
    if wrap is not None:
        for k in range(4):
            I.torus(r * 1.18, 0.0055, wrap, segs=10, rsegs=4, loc=(0, 0, -0.06 + k * 0.04), scale=(1.1, 1, 1))


def tip_cap(pos, material, r=0.012, h=0.04, sign=1):
    I.cyl(r, h, material, r2=r * 0.4, segs=8, loc=(pos[0], 0, pos[2] - sign * h / 3), rot=(0 if sign > 0 else 180, 0, 0),
          bevel=0.0, name="TipCap")


# ------------------------------------------------------------------------------------------------ crossbows
def crossbow_stock(material, rail, z0=-0.5, z1=0.5, w=0.06, h=0.07):
    I.box(w, h, z1 - z0, material, loc=(0, 0, (z0 + z1) / 2), bevel=0.01, segments=1, name="Stock")
    I.box(w * 1.6, h * 1.1, 0.16, material, loc=(0, 0.01, z0 + 0.08), bevel=0.014, segments=1, name="Butt")
    I.box(0.014, 0.01, z1 - z0 - 0.12, rail, loc=(0, -h / 2 - 0.002, (z0 + z1) / 2 + 0.06), bevel=0.0, name="Rail")
    I.box(0.035, 0.11, 0.05, material, loc=(0, h / 2 + 0.045, -0.02), rot=(18, 0, 0), bevel=0.008, segments=1, name="TriggerGrip")


def prod(material, z=0.42, span=0.4, sweep=0.1, r0=0.022, r1=0.009, n=6):
    """Crossbow prod across X, curving back (-Z) to the tips. Returns the two tip positions."""
    tips = []
    for s in (-1, 1):
        pts, radii = [], []
        for i in range(n + 1):
            t = i / n
            pts.append((s * span * t, 0.0, z - sweep * t * t))
            radii.append(r0 + (r1 - r0) * t)
        I.tube(pts, radii, material, segs=6, name="Prod")
        tips.append(pts[-1])
    return tips


def crossbow_string(tips, material, latch_z=0.05, r=0.0035):
    left, right = tips
    I.tube([(left[0] + 0.004, 0, left[2]), (0, -0.04, latch_z), (right[0] - 0.004, 0, right[2])], r, material, segs=5, name="String")


def bolt(shaft_mat, tip_mat, z0=0.06, z1=0.6, r=0.009, fletch=None):
    I.cyl(r, z1 - z0, shaft_mat, segs=6, loc=(0, -0.045, (z0 + z1) / 2), bevel=0.0, name="Bolt")
    I.cyl(r * 2.2, 0.07, tip_mat, r2=0.0, segs=4, loc=(0, -0.045, z1 + 0.035), bevel=0.0, smooth=False, name="BoltTip")
    if fletch is not None:
        for s in (-1, 1):
            I.extrude([(0, 0), (s * 0.03, -0.01), (s * 0.03, 0.05), (0, 0.07)] if s > 0 else
                      [(0, 0.07), (s * 0.03, 0.05), (s * 0.03, -0.01), (0, 0)], 0.003, fletch,
                      loc=(0, -0.045, z0 + 0.01), bevel=0.0, name="Fletch")


# ------------------------------------------------------------------------------------------------ guns
def pistol_grip(material, z=0.0, length=0.13, w=0.04):
    I.box(length, w, 0.05, material, loc=(-length / 2 - 0.02, 0, z), rot=(0, -12, 0), bevel=0.008, segments=1, name="PistolGrip")


def trigger_guard(material, z=0.06):
    I.torus(0.03, 0.005, material, segs=10, rsegs=4, arc=180, start=180, loc=(-0.035, 0, z), rot=(90, 0, 90), name="TriggerGuard")


# ================================================================================================ builders
def plains():  # Hunting Bow: wooden longbow, leather grip, horn tip caps, linen string
    wood = pm("#8A5A33", rough=0.7)
    leather = pm("#4A2E1A", rough=0.8)
    horn = pm("#E8DCC0", rough=0.5)
    tips = bow(wood, half=0.62, depth=0.16)
    bow_grip(leather, wrap=pm("#6B4426", rough=0.8))
    for tip, sign in zip(tips, (1, -1)):
        tip_cap(tip, horn, sign=sign)
    bow_string(tips, pm("#F2EAD8", rough=0.7))
    I.box(0.03, 0.01, 0.03, horn, loc=(-0.03, -0.02, 0.09), bevel=0.003, segments=1, name="ArrowRest")


def desert():  # Desert Recurve Bow: dark horn recurve limbs, gold tips and bands, turquoise grip gem
    horn = pm("#5A3A22", rough=0.5)
    gold = pm("#E2B04A", metal=0.9, rough=0.3)
    cloth = pm("#E3CFA3", rough=0.85)
    tips = bow(horn, half=0.6, depth=0.21, rc=0.075, r0=0.024)
    bow_grip(cloth, wrap=gold)
    for tip, sign in zip(tips, (1, -1)):
        tip_cap(tip, gold, r=0.013, h=0.05, sign=sign)
    for sign in (1, -1):
        for t in (0.35, 0.65):
            p = limb_points(0.6, 0.21, 0.075, sign=sign)[int(t * 8)]
            I.torus(0.021, 0.006, gold, segs=10, rsegs=4, loc=p, rot=(0, 0, 0))
    gem(0.018, pm("#2EC4B6", rough=0.15), (0.03, -0.012, 0.0), segs=8)
    bow_string(tips, pm("#F2EAD8", rough=0.7))


def jungle():  # Poison Blowgun: bamboo tube with nodes, vine wraps, hanging feathers, glowing poison dart and vial
    bamboo = pm("#9DB04A", rough=0.55)
    node = pm("#6E7F2E", rough=0.6)
    vine = pm("#3C8F3A", rough=0.6)
    wood = pm("#6E4A2A", rough=0.7)
    poison = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    I.cyl(0.034, 1.25, bamboo, segs=10, loc=(0, 0, 0.215), bevel=0.0, name="Tube")
    for z in (-0.3, -0.05, 0.25, 0.55, 0.8):
        I.torus(0.035, 0.008, node, segs=10, rsegs=4, loc=(0, 0, z))
    I.cyl(0.046, 0.08, wood, r2=0.034, segs=10, loc=(0, 0, -0.41), bevel=0.0, name="Mouthpiece")
    I.torus(0.044, 0.008, pm("#C0392B", rough=0.6), segs=10, rsegs=4, loc=(0, 0, -0.43))
    I.cyl(0.04, 0.05, node, segs=10, loc=(0, 0, 0.84), bevel=0.0, name="Muzzle")
    for k in range(5):
        I.torus(0.036, 0.006, vine, segs=10, rsegs=4, loc=(0, 0, -0.1 + k * 0.03), rot=(14 * (-1) ** k, 0, 0))
    I.cyl(0.008, 0.1, pm("#D9C9A0", rough=0.6), segs=6, loc=(0, 0, 0.9), bevel=0.0, name="Dart")
    I.cyl(0.016, 0.06, poison, r2=0.0, segs=6, loc=(0, 0, 0.98), bevel=0.0, smooth=False, name="DartTip")
    I.tube([(0.034, 0, 0.62), (0.07, 0, 0.6), (0.085, 0, 0.53)], 0.004, wood, segs=5, name="Cord")
    for i, col in enumerate(("#E74C3C", "#F1C40F", "#2E86DE")):
        I.extrude([(0, 0), (0.024, -0.05), (0.0, -0.18), (-0.024, -0.05)], 0.006, pm(col, rough=0.6),
                  loc=(0.085, 0, 0.535), rot=(0, -20 + 20 * i, 0), bevel=0.0, name="Feather")
    I.sphere(0.012, wood, segs=8, rings=5, loc=(0.085, 0, 0.53), name="Bead")
    I.cyl(0.024, 0.08, poison, segs=8, loc=(0.06, 0, 0.16), bevel=0.0, name="PoisonVial")
    I.cyl(0.017, 0.02, wood, segs=8, loc=(0.06, 0, 0.21), bevel=0.0, name="Cork")
    I.box(0.03, 0.012, 0.012, wood, loc=(0.045, 0, 0.16), bevel=0.0, name="VialStrap")


def tundra():  # Frostbite Crossbow: steel and birch stock, ice prod, glowing ice bolt, fur on the stock
    birch = pm("#4A5D73", metal=0.3, rough=0.55)
    steel = pm("#C9D3DC", metal=0.8, rough=0.3)
    ice = pm("#7CC8EE", rough=0.08)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    crossbow_stock(birch, steel)
    tips = prod(ice, z=0.42, span=0.42, sweep=0.12, r0=0.026, r1=0.01)
    I.box(0.09, 0.08, 0.06, steel, loc=(0, 0, 0.42), bevel=0.01, segments=1, name="ProdMount")
    for tip in tips:
        crystal((tip[0], 0, tip[2]), 0.014, 0.07, ice, tilt=(0, 90 if tip[0] > 0 else -90, 0))
    crossbow_string(tips, pm("#E8EEF2", rough=0.6))
    bolt(steel, glow, z0=0.06, z1=0.62)
    I.torus(0.05, 0.02, pm("#EDEAE4", rough=0.95), segs=12, rsegs=5, loc=(0, 0.01, -0.3), scale=(0.9, 1.1, 1), name="Fur")
    for k, a in enumerate((-40, 0, 40)):
        crystal((0.0, -0.03, 0.44), 0.016, 0.09 + 0.03 * (k == 1), ice, tilt=(-20, a, 0))
    I.box(0.03, 0.074, 0.3, glow, loc=(0, 0, -0.08), bevel=0.0, name="FrostStrip")
    I.box(0.064, 0.064, 0.32, birch, loc=(0, 0, -0.08), bevel=0.008, segments=1, name="StockCover")


def swamp():  # Plague Bow: twisted dark wood, bone hooks, big rag, toxic drips, glowing string and a plague vial
    wood = pm("#4A3A2A", rough=0.85)
    bone = pm("#D9CBA0", rough=0.55)
    rag = pm("#6E7A4A", rough=0.9)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    tips = bow(wood, half=0.6, depth=0.17, rc=-0.03, r0=0.028, r1=0.011)
    for sign in (1, -1):
        pts = limb_points(0.6, 0.17, -0.03, sign=sign)
        I.tube([(p[0] + 0.016 * math.sin(i * 1.7), 0.016 * math.cos(i * 1.7), p[2]) for i, p in enumerate(pts[1:-1])],
               0.008, wood, segs=5, name="Twist")
        for i in (3, 5):
            I.sphere(0.011, toxic, segs=8, rings=5, loc=(pts[i][0] + 0.03, -0.01, pts[i][2] - 0.02), scale=(1, 0.7, 1.6), name="Drip")
    bow_grip(rag, wrap=pm("#3E3A2E", rough=0.8))
    for tip, sign in zip(tips, (1, -1)):
        I.tube([(tip[0], 0, tip[2] - sign * 0.02), (tip[0] + 0.04, 0, tip[2] + sign * 0.02), (tip[0] + 0.08, 0, tip[2]),
                (tip[0] + 0.09, 0, tip[2] - sign * 0.03)], [0.016, 0.012, 0.007, 0.002], bone, segs=6, name="BoneHook")
    bow_string(tips, toxic)
    I.cyl(0.026, 0.08, toxic, segs=8, loc=(0.06, -0.01, -0.13), bevel=0.0, name="Vial")
    I.cyl(0.018, 0.02, bone, segs=8, loc=(0.06, -0.01, -0.08), bevel=0.0, name="Cork")
    I.extrude([(0, 0), (0.08, -0.04), (0.06, -0.17), (0.03, -0.1), (0.0, -0.2), (-0.02, -0.09)], 0.006, rag, loc=(0.03, 0, 0.08),
              bevel=0.0, name="Rag")


def volcano():  # Flame Bow: obsidian limbs with lava veins, flame tips, glowing string
    obs = pm("#2A2224", metal=0.3, rough=0.45)
    rock = pm("#4A3834", rough=0.85)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    tips = bow(obs, half=0.6, depth=0.22, rc=0.06, r0=0.026, r1=0.01)
    for sign in (1, -1):
        pts = limb_points(0.6, 0.22, 0.06, sign=sign)
        I.tube([(p[0], -0.03 + 0.012 * i / 8, p[2]) for i, p in enumerate(pts[1:-2])], 0.008, lava, segs=5, name="LavaVein")
    bow_grip(rock, wrap=pm("#8A1F12", rough=0.6))
    flame = [(0.0, 0.0), (0.03, 0.03), (0.02, 0.05), (0.045, 0.09), (0.01, 0.07), (0.0, 0.12), (-0.015, 0.06), (-0.03, 0.08), (-0.02, 0.03)]
    for tip, sign in zip(tips, (1, -1)):
        pts = [(x, sign * z) for x, z in flame]
        I.extrude(pts if sign > 0 else list(reversed(pts)), 0.016, lava, loc=(tip[0], 0, tip[2] - sign * 0.02), bevel=0.003,
                  segments=1, smooth=False, name="FlameTip")
    bow_string(tips, lava, r=0.004)
    I.ico(0.03, rock, loc=(0.03, 0, 0.0), scale=(1, 0.8, 1.3))
    gem(0.016, lava, (0.05, -0.012, 0.0), segs=8)


def hell():  # Soulfire Crossbow: black and red crossbow, spiked prod, demon skull front, soulfire bolt
    black = pm("#1E1414", rough=0.6)
    metal = pm("#6A1A16", metal=0.7, rough=0.3)
    edge = pm("#B23A2E", metal=0.7, rough=0.25)
    bone = pm("#E6D8C0", rough=0.5)
    soulfire = pm("#FF3A20", emit=3.0, emit_color="#FF2A10")
    crossbow_stock(black, edge)
    tips = prod(metal, z=0.42, span=0.42, sweep=0.1, r0=0.028, r1=0.01)
    for s in (-1, 1):
        for t in (0.35, 0.7):
            x, z = s * 0.42 * t, 0.42 - 0.1 * t * t
            spike((x, 0, z + 0.01), (x + s * 0.02, 0, z + 0.08), 0.012, edge, segs=5)
    crossbow_string(tips, pm("#FF6040", rough=0.4))
    I.sphere(0.05, bone, segs=10, rings=7, loc=(0, 0, 0.47), scale=(1, 0.9, 0.95), name="Skull")
    for x in (-0.02, 0.02):
        I.sphere(0.011, soulfire, segs=6, rings=4, loc=(x, -0.043, 0.48))
    for s in (-1, 1):
        I.tube([(s * 0.03, 0, 0.5), (s * 0.07, 0, 0.55), (s * 0.06, 0, 0.6)], [0.012, 0.008, 0.002], bone, segs=6, name="Horn")
    bolt(black, soulfire, z0=0.06, z1=0.64)
    I.box(0.05, 0.02, 0.18, metal, loc=(0, -0.042, -0.2), bevel=0.004, segments=1, name="Plate")


def heaven():  # Dawn Bow: gold limbs with scalloped white wings, sun disc at the grip, golden glowing string
    white = pm("#FFFFFF", rough=0.4)
    gold = pm("#E8B84A", metal=0.9, rough=0.25)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    depth, rc = 0.2, 0.05
    tips = bow(gold, half=0.6, depth=depth, rc=rc, r0=0.022, r1=0.009)
    for sign in (1, -1):
        pts = limb_points(0.6, depth, rc, sign=sign)
        inner = [(pts[i][0] + 0.012, pts[i][2]) for i in range(1, 8)]
        outer = []
        for i in range(7, 0, -1):
            w = 0.04 + 0.1 * (1 - (i - 1) / 7)
            x, z = pts[i][0], pts[i][2]
            outer.append((x + w, z + sign * 0.04))
            outer.append((x + w * 0.92, z + sign * 0.005))
            outer.append((x + w * 0.62, z - sign * 0.025))
        poly = inner + outer
        I.extrude(poly if sign > 0 else list(reversed(poly)), 0.012, white, loc=(0, 0.004, 0), bevel=0.002, segments=1,
                  smooth=False, name="Wing")
    bow_grip(white, wrap=gold)
    I.cyl(0.06, 0.012, gold, segs=16, loc=(0.015, -0.02, 0.0), rot=(90, 0, 0), bevel=0.0, name="SunDisc")
    I.cyl(0.04, 0.016, sun, segs=16, loc=(0.015, -0.024, 0.0), rot=(90, 0, 0), bevel=0.0, name="Sun")
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        spike((0.015 + 0.06 * math.cos(a), -0.02, 0.06 * math.sin(a)), (0.015 + 0.085 * math.cos(a), -0.02, 0.085 * math.sin(a)),
              0.008, gold, segs=4)
    bow_string(tips, sun)


def dead():  # Bone Crossbow: vertebra stock, rib prod, skull front, green soul bolt
    bone = pm("#E6DCC0", rough=0.55)
    dark = pm("#3A3440", rough=0.75)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    crossbow_stock(dark, bone)
    for k in range(6):
        I.box(0.075, 0.05, 0.03, bone, loc=(0, -0.012, -0.36 + k * 0.06), bevel=0.006, segments=1, name="Vertebra")
    tips = prod(bone, z=0.42, span=0.4, sweep=0.14, r0=0.034, r1=0.012)
    for s in (-1, 1):
        I.tube([(s * 0.05, 0, 0.4), (s * 0.18, 0, 0.36), (s * 0.24, 0, 0.3)], [0.012, 0.009, 0.003], bone, segs=6, name="Rib")
    crossbow_string(tips, pm("#B8B2A0", rough=0.7))
    I.sphere(0.06, bone, segs=10, rings=7, loc=(0, -0.035, 0.43), scale=(1, 0.9, 0.95), name="Skull")
    I.box(0.05, 0.035, 0.03, bone, loc=(0, -0.055, 0.385), bevel=0.006, segments=1, name="Jaw")
    for x in (-0.017, 0.017):
        I.sphere(0.014, soul, segs=6, rings=4, loc=(x * 1.3, -0.084, 0.44))
    bolt(bone, soul, z0=0.06, z1=0.66)
    gem(0.02, soul, (0, -0.05, -0.12), segs=8)


def abyss():  # Harpoon Gun: teal-brass gun with a loaded harpoon, coiled rope, pressure tank, pistol grip (-X)
    brass = pm("#C9A04A", metal=0.85, rough=0.35)
    teal = pm("#3FB5C8", metal=0.65, rough=0.22)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4)
    rope = pm("#D9C9A0", rough=0.8)
    glow = pm("#5FFFF0", emit=2.5, emit_color="#40F0E0")
    I.cyl(0.045, 0.7, teal, segs=12, loc=(0, 0, 0.2), bevel=0.0, name="Barrel")
    I.cyl(0.055, 0.07, brass, segs=12, loc=(0, 0, 0.55), bevel=0.0, name="Muzzle")
    I.cyl(0.012, 0.25, pm("#B8C2CE", metal=0.85, rough=0.3), segs=8, loc=(0, 0, 0.66), bevel=0.0, name="HarpoonShaft")
    I.cyl(0.04, 0.11, pm("#B8C2CE", metal=0.85, rough=0.3), r2=0.0, segs=4, loc=(0, 0, 0.83), bevel=0.0, smooth=False, name="HarpoonTip")
    for s in (-1, 1):
        spike((s * 0.012, 0, 0.78), (s * 0.055, 0, 0.73), 0.01, pm("#B8C2CE", metal=0.85, rough=0.3), segs=4)
    I.box(0.07, 0.06, 0.4, dark, loc=(-0.01, 0, -0.32), bevel=0.012, segments=1, name="Stock")
    pistol_grip(dark, z=-0.05, length=0.14)
    trigger_guard(brass, z=0.02)
    I.cyl(0.04, 0.2, brass, segs=12, loc=(0.065, 0, 0.12), bevel=0.0, name="Tank")
    I.cyl(0.02, 0.02, glow, segs=10, loc=(0.065, -0.035, 0.12), rot=(90, 0, 0), bevel=0.0, name="Gauge")
    for k in range(4):
        I.torus(0.05, 0.009, rope, segs=12, rsegs=4, loc=(0, 0, 0.3 + k * 0.02))
    for z in (-0.05, 0.4):
        I.torus(0.047, 0.007, brass, segs=12, rsegs=4, loc=(0, 0, z))
    for x, z, r in ((0.02, -0.25, 0.018), (-0.01, -0.33, 0.014), (0.025, -0.4, 0.012)):
        I.cyl(r, r * 1.1, pm("#D8D2C0", rough=0.7), r2=r * 0.45, segs=6, loc=(x, -0.034, z), rot=(90, 0, 0), bevel=0.0, smooth=False, name="Barnacle")
    I.box(0.012, 0.094, 0.5, glow, loc=(0.0, 0, 0.2), bevel=0.0, name="GlowStrip")


def mechanical():  # Pulse Rifle: sci-fi rifle, energy coils, cyan barrel glow, scope, magazine, pistol grip (-X)
    metal = pm("#9AA4B2", metal=0.85, rough=0.3)
    dark = pm("#3A3F48", metal=0.8, rough=0.35)
    yellow = pm("#FFC21F", rough=0.4)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    I.box(0.09, 0.06, 0.5, dark, loc=(0, 0, 0.05), bevel=0.012, segments=1, name="Body")
    I.cyl(0.024, 0.42, metal, segs=12, loc=(0, 0, 0.5), bevel=0.0, name="Barrel")
    for k in range(4):
        I.torus(0.033, 0.008, plasma if k % 2 == 0 else dark, segs=12, rsegs=4, loc=(0, 0, 0.36 + k * 0.06))
    I.cyl(0.032, 0.05, dark, segs=12, loc=(0, 0, 0.72), bevel=0.0, name="Muzzle")
    I.cyl(0.018, 0.02, plasma, segs=12, loc=(0, 0, 0.75), bevel=0.0, name="MuzzleGlow")
    I.box(0.06, 0.05, 0.32, metal, loc=(0.0, 0, -0.35), bevel=0.012, segments=1, name="Stock")
    I.box(0.05, 0.03, 0.12, dark, loc=(0.02, 0, -0.46), bevel=0.006, segments=1, name="ButtPad")
    pistol_grip(dark, z=-0.05, length=0.13)
    trigger_guard(metal, z=0.02)
    I.box(0.11, 0.04, 0.06, yellow, loc=(-0.09, 0, 0.13), rot=(0, 10, 0), bevel=0.006, segments=1, name="Magazine")
    I.box(0.006, 0.042, 0.04, plasma, loc=(-0.13, 0, 0.13), rot=(0, 10, 0), bevel=0.0, name="Charge")
    I.cyl(0.022, 0.16, dark, segs=10, loc=(0.075, 0, 0.1), bevel=0.0, name="Scope")
    I.cyl(0.016, 0.01, plasma, segs=10, loc=(0.075, 0, 0.185), bevel=0.0, name="ScopeLens")
    for z in (0.04, 0.16):
        I.box(0.03, 0.02, 0.015, dark, loc=(0.055, 0, z), bevel=0.0, name="ScopeMount")
    I.box(0.012, 0.062, 0.3, plasma, loc=(0.046, 0, 0.0), bevel=0.0, name="SideStrip")


def void():  # Starfall Bow: dark crystal limbs, star tips, crystal grip, glowing string, floating stars
    dark = pm("#3A2C55", metal=0.35, rough=0.15)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    tips = bow(dark, half=0.6, depth=0.23, rc=0.07, r0=0.026, r1=0.01)
    for sign in (1, -1):
        pts = limb_points(0.6, 0.23, 0.07, sign=sign)
        for i in (2, 4, 6):
            crystal((pts[i][0] + 0.02, 0, pts[i][2]), 0.018, 0.085, dark, tilt=(0, 70 - sign * 15, 0))
    bow_grip(obs, wrap=glow)
    crystal((0.03, 0, 0.0), 0.022, 0.08, glow, tilt=(0, 90, 0))
    star = I.star_points(5, 0.05, 0.022)
    for tip, sign in zip(tips, (1, -1)):
        I.extrude(star, 0.014, glow, loc=(tip[0], 0, tip[2] + sign * 0.03), bevel=0.003, segments=1, smooth=False, name="StarTip")
    bow_string(tips, glow, r=0.004)
    for x, z, r in ((0.12, 0.3, 0.025), (0.15, -0.22, 0.02), (0.09, 0.48, 0.016)):
        I.extrude(I.star_points(5, r, r * 0.45), 0.008, glow, loc=(x, 0, z), bevel=0.002, segments=1, smooth=False, name="Star")
    I.torus(0.07, 0.005, glow, segs=18, rsegs=4, loc=(0.02, 0, 0.0), rot=(75, 0, 0), name="Orbit")


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
