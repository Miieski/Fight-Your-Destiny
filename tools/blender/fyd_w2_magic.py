"""Magic V2 (staffs): 12 builders, zone 1 -> 12, rebuilt from the icons (Icons/Weapons/Magic) with more detail.
~1.68 m (6 studs). The origin is the grip center (lower part of the shaft); the staff head (orb, crystal, object) is
at the top along +Z. Muzzle = the focus (orb / flake / tome gem) where the spells start."""
import math

import fyd_icons as I
import fyd_w2_parts as P
from fyd_weapons2 import pm, point

BUTT = -0.5  # bottom of the shaft
TOP = 0.85  # top of the shaft (the head starts here)


def shaft(material, r=0.026, bottom=BUTT, top=TOP, segs=12):
    I.cyl(r, top - bottom, material, segs=segs, loc=(0, 0, (top + bottom) / 2), bevel=0.0, smooth=False, name="Shaft")


def ring(z, material, r=0.03, t=0.008, segs=12):
    I.torus(r, t, material, segs=segs, rsegs=4, loc=(0, 0, z), name="Ring")


def grip_wrap(material, z0=-0.13, z1=0.13, r=0.028, turns=6):
    pts = []
    steps = turns * 10
    for i in range(steps + 1):
        u = i / steps
        a = 2 * math.pi * turns * u
        pts.append((math.cos(a) * r, math.sin(a) * r, z0 + (z1 - z0) * u))
    P.tube(pts, 0.006, material, segs=5, name="Wrap")
    for z in (z0, z1):
        I.torus(r, 0.006, material, segs=12, rsegs=4, loc=(0, 0, z), name="WrapEnd")


def butt_cap(material, r=0.03):
    I.cyl(r, 0.06, material, r2=r * 0.55, segs=12, loc=(0, 0, BUTT - 0.025), rot=(180, 0, 0), bevel=0.0, smooth=False,
          name="Butt")
    I.torus(r * 0.95, r * 0.17, material, segs=12, rsegs=4, loc=(0, 0, BUTT + 0.004), name="ButtRing")


def orb(r, material, z, segs=20, rings=12, x=0.0):
    return I.sphere(r, material, segs=segs, rings=rings, loc=(x, 0, z), name="Orb")


def prongs(material, z_base, z_orb, r_orb, n=3, r=0.012, spin=90.0, curl=0.35):
    """Prongs rising from the shaft top and curling around an orb (twist-free tubes)."""
    for k in range(n):
        a = math.radians(spin + 360 * k / n)
        c, s = math.cos(a), math.sin(a)
        R = r_orb + r * 1.4
        pts = [(0.02 * c, 0.02 * s, z_base), (R * 0.6 * c, R * 0.6 * s, z_orb - r_orb * 0.95),
               (R * 0.9 * c, R * 0.9 * s, z_orb - r_orb * 0.6), (R * c, R * s, z_orb),
               (R * 0.92 * c, R * 0.92 * s, z_orb + r_orb * 0.4), (R * 0.8 * c, R * 0.8 * s, z_orb + r_orb * 0.7),
               (R * curl * c, R * curl * s, z_orb + r_orb * 1.1)]
        P.tube(pts, [r, r * 0.97, r * 0.95, r * 0.85, r * 0.72, r * 0.6, r * 0.25], material, segs=7, name="Prong")


def staff_points(focus, top_z):
    point("Muzzle", focus)
    point("Tip", (0, 0, top_z))
    point("Base", (0, 0, TOP - 0.05))


def plains():  # Apprentice Staff: wooden staff, forked top holding a blue orb, leather grip, iron fittings
    wood = pm("#8A5A33", rough=0.7, var=0.2, grain=True)
    leather = pm("#4A2E1A", rough=0.8, var=0.15)
    iron = pm("#5C6168", metal=0.8, rough=0.45, var=0.1)
    shaft(wood)
    I.cyl(0.032, 0.08, wood, r2=0.026, segs=12, loc=(0, 0, TOP + 0.03), bevel=0.0, smooth=False, name="Head")
    prongs(wood, TOP + 0.06, TOP + 0.21, 0.09, n=3, r=0.018)
    orb(0.09, pm("#3A7BFF", emit=2.0, emit_color="#2A6AFF"), TOP + 0.21)
    grip_wrap(leather)
    ring(TOP - 0.02, iron)
    butt_cap(iron)
    staff_points((0, 0, TOP + 0.21), TOP + 0.33)


def desert():  # Sandstorm Staff: sandstone and gold staff, a swirling sand vortex around an amber orb, crescents
    wood = pm("#B98A5A", rough=0.75, var=0.18, grain=True)
    gold = pm("#E2B04A", metal=0.9, rough=0.3, var=0.08)
    sand = pm("#C9A060", rough=0.85, var=0.2, scale=60)
    amber = pm("#FF9A20", emit=2.4, emit_color="#FF7A10")
    shaft(wood)
    for z in (TOP - 0.04, 0.5, 0.22):
        ring(z, gold)
    I.cyl(0.045, 0.06, gold, r2=0.03, segs=12, loc=(0, 0, TOP + 0.02), bevel=0.0, smooth=False, name="Cup")
    for k, (r, z) in enumerate(((0.05, TOP + 0.08), (0.08, TOP + 0.15), (0.105, TOP + 0.23), (0.12, TOP + 0.31),
                                (0.11, TOP + 0.38))):
        I.torus(r, 0.02 - k * 0.002, sand, segs=18, rsegs=5, arc=310, start=40 * k, loc=(0, 0, z), rot=(8, -10 + 5 * k, 0),
                name="Vortex")
    orb(0.065, amber, TOP + 0.22)
    for s in (-1, 1):
        I.torus(0.05, 0.008, gold, segs=14, rsegs=4, arc=180, start=-90 if s > 0 else 90, loc=(s * 0.03, 0, TOP - 0.1),
                rot=(90, 0, 0), name="Crescent")
    P.socketed_gem(0.016, pm("#2EC4B6", rough=0.15, var=0.0), gold, (0, -0.03, TOP - 0.1))
    grip_wrap(pm("#E3CFA3", rough=0.85, var=0.12))
    butt_cap(gold)
    staff_points((0, 0, TOP + 0.22), TOP + 0.4)


def jungle():  # Shaman Totem Staff: carved totem head, feathers, hanging beads, green spirit orb
    wood = pm("#6E4A2A", rough=0.75, var=0.22, grain=True)
    carved = pm("#A0703F", rough=0.7, var=0.2, grain=True)
    spirit = pm("#7CFF8A", emit=2.4, emit_color="#40FF70")
    shaft(wood, r=0.028)
    I.lathe([(0.03, TOP - 0.18), (0.075, TOP - 0.1), (0.082, TOP + 0.0), (0.082, TOP + 0.08), (0.07, TOP + 0.13),
             (0.04, TOP + 0.16)], carved, segs=8, smooth=False, name="Totem")
    for x in (-0.03, 0.03):
        I.box(0.028, 0.018, 0.022, pm("#F5F0E1", rough=0.5), loc=(x, -0.074, TOP + 0.04), bevel=0.004, segments=1,
              smooth=False, name="Eye")
        I.box(0.011, 0.02, 0.011, pm("#1A1A1A", rough=0.5), loc=(x, -0.077, TOP + 0.04), bevel=0.0, smooth=False,
              name="Pupil")
    I.cyl(0.02, 0.06, pm("#E67E22", rough=0.5), r2=0.0, segs=4, loc=(0, -0.1, TOP - 0.01), rot=(90, 0, 0), bevel=0.0,
          smooth=False, name="Beak")
    I.box(0.07, 0.016, 0.014, pm("#C0392B", rough=0.6), loc=(0, -0.075, TOP - 0.06), bevel=0.0, smooth=False, name="Mouth")
    I.torus(0.078, 0.013, pm("#1FA59A", rough=0.6, var=0.1), segs=8, rsegs=4, loc=(0, 0, TOP - 0.1), name="Paint")
    I.torus(0.082, 0.012, pm("#C0392B", rough=0.6, var=0.1), segs=8, rsegs=4, loc=(0, 0, TOP + 0.1), name="Paint")
    prongs(wood, TOP + 0.14, TOP + 0.3, 0.075, n=2, r=0.015, spin=0)
    orb(0.075, spirit, TOP + 0.3)
    for i, col in enumerate(("#2ECC40", "#E74C3C", "#F1C40F", "#2E86DE")):
        P.plate([(0, 0), (0.03, 0.08), (0.015, 0.14), (0.0, 0.2), (-0.015, 0.14), (-0.03, 0.08)], 0.006,
                pm(col, rough=0.6, var=0.12), bevel=0.004, loc=(0, 0.02, TOP + 0.12), rot=(0, -60 + 40 * i, 0), name="Feather")
    for x in (-0.075, 0.075):
        P.tube([(x, 0, TOP - 0.1), (x * 1.1, 0, TOP - 0.17), (x * 1.2, 0, TOP - 0.24), (x * 1.1, 0, TOP - 0.34)], 0.004,
               pm("#6B3E22", rough=0.8), segs=4, name="Cord")
        for k, col in enumerate(("#E74C3C", "#F1C40F", "#F5F0E1")):
            I.sphere(0.017, pm(col, rough=0.5, var=0.06), segs=8, rings=5, loc=(x * (1.2 - 0.03 * k), 0, TOP - 0.24 - 0.04 * k),
                     smooth=False, name="Bead")
    grip_wrap(pm("#3C8F3A", rough=0.6, var=0.15), r=0.03)
    butt_cap(carved)
    staff_points((0, 0, TOP + 0.3), TOP + 0.4)


def tundra():  # Blizzard Staff: ice crystal crown around a glowing snowflake, frost rings, fur grip
    white = pm("#E8EEF2", rough=0.55, var=0.08)
    steel = pm("#C9D3DC", metal=0.8, rough=0.3, var=0.06)
    ice = pm("#7CC8EE", rough=0.08, var=0.05)
    glow = pm("#2EB8FF", emit=2.2, emit_color="#1AA8FF")
    shaft(pm("#4A5D73", metal=0.3, rough=0.55, var=0.1))
    I.cyl(0.04, 0.08, steel, r2=0.03, segs=12, loc=(0, 0, TOP + 0.02), bevel=0.0, smooth=False, name="Cup")
    for k in range(6):
        a = math.radians(60 * k)
        P.crystal((0.03 * math.cos(a), 0.03 * math.sin(a), TOP + 0.05), 0.024, 0.22 + 0.06 * (k % 2), ice,
                  tilt=(-22 * math.sin(a), 22 * math.cos(a), 0))
    flake = []
    for k in range(12):
        a = math.radians(90 + 30 * k)
        r = 0.13 if k % 2 == 0 else 0.04
        flake.append((r * math.cos(a), r * math.sin(a) + TOP + 0.2))
    P.plate(flake, 0.018, glow, bevel=0.006, loc=(0, -0.065, 0), name="Snowflake")
    for k in range(6):  # side branches of the snowflake arms
        a = math.radians(90 + 60 * k)
        c, s = math.cos(a), math.sin(a)
        for side in (-1, 1):
            b = a + side * math.radians(45)
            P.plate([(0.075 * c, TOP + 0.2 + 0.075 * s), (0.075 * c + 0.035 * math.cos(b), TOP + 0.2 + 0.075 * s + 0.035 * math.sin(b)),
                     (0.085 * c, TOP + 0.2 + 0.085 * s)], 0.014, glow, bevel=0.003, loc=(0, -0.065, 0), name="FlakeBranch")
    I.cyl(0.006, 0.05, steel, segs=6, loc=(0, -0.04, TOP + 0.2), rot=(90, 0, 0), bevel=0.0, smooth=False, name="FlakePin")
    P.crystal((0, 0, TOP + 0.08), 0.026, 0.3, ice)
    for z in (TOP - 0.05, 0.48, 0.2):
        ring(z, steel)
    grip_wrap(white, turns=5)
    P.crystal((0, 0, BUTT + 0.02), 0.026, 0.1, ice, tilt=(180, 0, 0))
    staff_points((0, -0.065, TOP + 0.2), TOP + 0.38)


def swamp():  # Cauldron Staff: crooked dark wood, a hanging cauldron bubbling green, bones and a skull
    wood = pm("#4A3A2A", rough=0.85, var=0.22, grain=True)
    iron = pm("#3E3A36", metal=0.6, rough=0.55, var=0.15)
    bone = pm("#D9CBA0", rough=0.55, var=0.1)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    P.tube([(0, 0, BUTT), (0.015, 0, -0.2), (-0.012, 0, 0.2), (0.012, 0, 0.6), (0, 0, TOP), (0.03, 0, TOP + 0.1),
            (0.06, 0, TOP + 0.14), (0.11, 0, TOP + 0.165), (0.16, 0, TOP + 0.17), (0.2, 0, TOP + 0.12)],
           [0.027, 0.027, 0.026, 0.025, 0.024, 0.022, 0.02, 0.018, 0.016, 0.012], wood, segs=8, name="Shaft")
    for k in range(4):  # chain links
        I.torus(0.008, 0.0025, iron, segs=8, rsegs=3, loc=(0.19, 0, TOP + 0.105 - k * 0.027), rot=(0, 90 * (k % 2), 0),
                name="ChainLink")
    # the inner lip drops the closing cap inside the pot, under the brew
    pot = [(0.0, -0.06), (0.05, -0.055), (0.07, -0.03), (0.075, 0.0), (0.065, 0.025), (0.058, 0.03), (0.05, 0.012),
           (0.0, 0.012)]
    I.lathe(pot, iron, segs=16, loc=(0.19, 0, TOP - 0.04), smooth=False, name="Cauldron")
    I.torus(0.06, 0.008, iron, segs=16, rsegs=4, loc=(0.19, 0, TOP - 0.01), name="CauldronRim")
    for s in (-1, 1):
        I.torus(0.012, 0.003, iron, segs=8, rsegs=3, loc=(0.19 + s * 0.072, 0, TOP - 0.015), rot=(90, 0, 0), name="Handle")
    I.sphere(0.054, toxic, segs=16, rings=6, loc=(0.19, 0, TOP - 0.014), scale=(1, 1, 0.3), smooth=False, name="Brew")
    for x, z, r in ((0.17, TOP + 0.02, 0.018), (0.21, TOP + 0.035, 0.013), (0.2, TOP + 0.07, 0.009)):
        I.sphere(r, toxic, segs=8, rings=5, loc=(x, 0, z), smooth=False, name="Bubble")
    for x in (0.15, 0.23):
        P.tube([(x, 0, TOP - 0.1), (x, 0, TOP - 0.14)], 0.006, toxic, segs=5, name="Drip")
    for s in (-1, 1):
        P.spike((0.0, 0, TOP - 0.05), (s * 0.08, 0, TOP - 0.1), 0.012, bone, segs=5)
    I.sphere(0.03, bone, segs=10, rings=7, loc=(0, -0.02, TOP - 0.02), scale=(1, 0.9, 1.05), smooth=False, name="Skull")
    for x in (-0.01, 0.01):
        I.sphere(0.006, toxic, segs=6, rings=4, loc=(x, -0.046, TOP - 0.015), smooth=False, name="Eye")
    grip_wrap(pm("#5E7A3A", rough=0.7, var=0.15))
    I.cyl(0.03, 0.06, bone, r2=0.016, segs=8, loc=(0, 0, BUTT - 0.02), rot=(180, 0, 0), bevel=0.0, smooth=False, name="Butt")
    staff_points((0.19, 0, TOP + 0.0), TOP + 0.19)


def volcano():  # Eruption Staff: obsidian staff, mini volcano with lava flows erupting a lava orb, embers
    black = pm("#2A2224", metal=0.3, rough=0.45, var=0.12, scale=70)
    rock = pm("#4A3834", rough=0.85, var=0.25, scale=45)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    shaft(black, r=0.028)
    I.cyl(0.13, 0.18, rock, r2=0.045, segs=10, loc=(0, 0, TOP + 0.06), bevel=0.0, smooth=False, name="Volcano")
    for k in range(5):
        a = math.radians(20 + 72 * k)
        I.ico(0.022, rock, loc=(0.1 * math.cos(a), 0.1 * math.sin(a), TOP + 0.0), scale=(1.2, 1.2, 0.8), name="Boulder")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        P.tube([(0.046 * math.cos(a), 0.046 * math.sin(a), TOP + 0.14), (0.07 * math.cos(a), 0.07 * math.sin(a), TOP + 0.1),
                (0.095 * math.cos(a), 0.095 * math.sin(a), TOP + 0.05), (0.125 * math.cos(a), 0.125 * math.sin(a), TOP - 0.02)],
               [0.013, 0.012, 0.01, 0.005], lava, segs=5, name="LavaFlow")
    orb(0.078, lava, TOP + 0.27)
    for x, z, r in ((0.09, TOP + 0.37, 0.022), (-0.075, TOP + 0.4, 0.018), (0.02, TOP + 0.45, 0.015)):
        I.ico(r, lava, loc=(x, 0, z), name="Ember")
    for z in (0.25, 0.45, 0.65):
        I.torus(0.0295, 0.007, lava, segs=12, rsegs=4, loc=(0, 0, z), rot=(8, 0, 0), name="LavaRing")
    grip_wrap(pm("#8A1F12", rough=0.6, var=0.12))
    butt_cap(rock)
    staff_points((0, 0, TOP + 0.27), TOP + 0.47)


def hell():  # Infernal Tome Staff: an open demonic tome on top, glowing red runes, horns, chains, demon gem
    black = pm("#1E1414", rough=0.6, var=0.1)
    metal = pm("#6A1A16", metal=0.7, rough=0.3, var=0.12)
    leather = pm("#5A1A16", rough=0.6, var=0.15, grain=True)
    page = pm("#E6D8C0", rough=0.7, var=0.08)
    rune = pm("#FF3030", emit=3.0, emit_color="#FF2020")
    shaft(black)
    I.box(0.05, 0.05, 0.09, metal, loc=(0, 0, TOP + 0.02), bevel=0.008, segments=2, smooth=False, name="Mount")
    zc = TOP + 0.17
    for s in (-1, 1):
        root = I.empty("Half", loc=(0, 0, zc), rot=(0, 0, s * -22))
        I.box(0.13, 0.014, 0.2, leather, loc=(s * 0.067, 0.0, 0.0), bevel=0.004, segments=1, smooth=False, parent=root,
              name="Cover")
        I.box(0.12, 0.02, 0.185, page, loc=(s * 0.064, -0.016, 0.0), bevel=0.003, segments=1, smooth=False, parent=root,
              name="Pages")
        for k in range(4):
            I.box(0.07 - 0.012 * (k % 2), 0.004, 0.008, rune, loc=(s * 0.064, -0.027, 0.06 - k * 0.04), bevel=0.0,
                  smooth=False, parent=root, name="Rune")
        for dz in (0.085, -0.085):
            I.box(0.02, 0.022, 0.03, metal, loc=(s * 0.125, -0.01, dz), bevel=0.003, segments=1, smooth=False, parent=root,
                  name="Corner")
        P.tube([(s * 0.1, 0, zc + 0.1), (s * 0.125, 0, zc + 0.135), (s * 0.15, 0, zc + 0.17), (s * 0.14, 0, zc + 0.24),
                (s * 0.1, 0, zc + 0.27)], [0.016, 0.014, 0.012, 0.007, 0.002], pm("#E6D8C0", rough=0.5, var=0.1), segs=6,
               name="Horn")
        for k in range(4):  # hanging chain links
            I.torus(0.007, 0.0025, metal, segs=8, rsegs=3, loc=(s * (0.12 + 0.003 * k), -0.008, zc - 0.09 - k * 0.045),
                    rot=(0, 90 * (k % 2), 0), name="ChainLink")
    I.cyl(0.012, 0.21, metal, segs=8, loc=(0, 0.004, zc), bevel=0.0, smooth=False, name="Spine")
    P.socketed_gem(0.024, rune, metal, (0, -0.02, zc + 0.13))
    for z in (0.28, 0.55):
        ring(z, metal)
    grip_wrap(pm("#7A1A1A", rough=0.6, var=0.12))
    P.spike((0, 0, BUTT + 0.02), (0, 0, BUTT - 0.09), 0.024, metal, segs=6)
    staff_points((0, -0.03, zc), zc + 0.27)


def heaven():  # Seraph Staff: white-gold staff, large wings around a sun orb with a gold ring, halo above
    white = pm("#FFFFFF", rough=0.4, var=0.05)
    gold = pm("#E8B84A", metal=0.9, rough=0.25, var=0.08)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    shaft(white)
    I.cyl(0.042, 0.08, gold, r2=0.028, segs=14, loc=(0, 0, TOP + 0.02), bevel=0.0, smooth=False, name="Cup")
    wing = [(0.0, 0.0), (0.06, 0.03), (0.14, 0.1), (0.2, 0.2), (0.22, 0.32), (0.17, 0.26), (0.16, 0.3), (0.12, 0.22),
            (0.1, 0.25), (0.07, 0.16), (0.04, 0.12)]
    for s in (-1, 1):
        pts = [(s * (x + 0.03), z + TOP + 0.05) for x, z in wing]
        P.plate(pts if s > 0 else list(reversed(pts)), 0.014, white, bevel=0.006, loc=(0, 0.01, 0), name="Wing")
    orb(0.07, sun, TOP + 0.17)
    I.torus(0.085, 0.01, gold, segs=22, rsegs=5, loc=(0, 0, TOP + 0.17), rot=(90, 0, 0), name="SunRing")
    I.torus(0.075, 0.009, sun, segs=22, rsegs=5, loc=(0, 0, TOP + 0.35), rot=(20, 0, 0), name="Halo")
    for z in (TOP - 0.05, 0.5, 0.22):
        ring(z, gold)
    grip_wrap(gold)
    butt_cap(gold)
    staff_points((0, 0, TOP + 0.17), TOP + 0.38)


def dead():  # Lich Staff: dark staff with vertebrae, a big crowned skull, bone claws holding a green soul orb
    bone = pm("#E6DCC0", rough=0.55, var=0.1)
    dark = pm("#3A3440", rough=0.75, var=0.1)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    iron = pm("#4A4A52", metal=0.6, rough=0.6, var=0.12)
    shaft(dark, r=0.028)
    for k in range(5):
        I.sphere(0.036, bone, segs=10, rings=6, loc=(0, 0, 0.25 + k * 0.11), scale=(1, 1, 0.55), smooth=False, name="Vertebra")
        for s in (-1, 1):
            P.spike((s * 0.03, 0, 0.25 + k * 0.11), (s * 0.05, 0, 0.24 + k * 0.11), 0.007, bone, segs=4)
    zs = TOP + 0.08
    I.sphere(0.095, bone, segs=14, rings=9, loc=(0, 0, zs), scale=(1, 0.95, 1.05), smooth=False, name="Skull")
    I.box(0.1, 0.07, 0.05, bone, loc=(0, -0.025, zs - 0.09), bevel=0.01, segments=2, smooth=False, name="Jaw")
    for x in (-0.03, -0.01, 0.01, 0.03):
        I.box(0.012, 0.01, 0.016, dark, loc=(x, -0.061, zs - 0.095), bevel=0.0, smooth=False, name="Tooth")
    for x in (-0.034, 0.034):
        I.sphere(0.024, dark, segs=8, rings=5, loc=(x, -0.075, zs + 0.01), scale=(1, 0.5, 1), smooth=False, name="Socket")
        I.sphere(0.016, soul, segs=8, rings=5, loc=(x, -0.085, zs + 0.01), smooth=False, name="Eye")
    I.cyl(0.07, 0.03, iron, segs=14, loc=(0, 0, zs + 0.085), bevel=0.0, smooth=False, name="CrownBand")
    for k in range(5):
        a = math.radians(-70 + 35 * k)
        P.spike((0.066 * math.sin(a), -0.066 * math.cos(a), zs + 0.09), (0.085 * math.sin(a), -0.085 * math.cos(a), zs + 0.15),
                0.014, iron, segs=4)
    prongs(bone, zs + 0.1, zs + 0.27, 0.07, n=3, r=0.014, spin=90, curl=0.2)
    orb(0.07, soul, zs + 0.27)
    for s in (-1, 1):
        P.tube([(s * 0.06, 0, zs - 0.12), (s * 0.09, 0, zs - 0.135), (s * 0.12, 0, zs - 0.16), (s * 0.13, 0, zs - 0.24)],
               [0.012, 0.011, 0.009, 0.003], bone, segs=6, name="Claw")
    grip_wrap(bone, r=0.03)
    butt_cap(iron)
    staff_points((0, 0, zs + 0.27), zs + 0.36)


def abyss():  # Tidecaller Staff: coral staff, a water orb held by curling tentacles, conch shell, pearls
    coral = pm("#E86A8A", rough=0.45, var=0.15)
    teal = pm("#3FB5C8", metal=0.65, rough=0.22, var=0.1)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4, var=0.1)
    water = pm("#5FFFF0", emit=2.2, emit_color="#40F0E0")
    pearl = pm("#F4F1EA", rough=0.12, var=0.04)
    shaft(dark)
    I.cyl(0.045, 0.08, teal, r2=0.03, segs=14, loc=(0, 0, TOP + 0.02), bevel=0.0, smooth=False, name="Cup")
    prongs(pm("#A8447A", rough=0.45, var=0.12), TOP + 0.05, TOP + 0.22, 0.08, n=4, r=0.015, spin=45, curl=0.1)
    orb(0.08, water, TOP + 0.22)
    for s in (-1, 1):
        P.tube([(s * 0.03, 0, TOP - 0.1), (s * 0.06, 0, TOP - 0.085), (s * 0.08, 0, TOP - 0.06), (s * 0.1, 0, TOP + 0.02),
                (s * 0.13, 0, TOP + 0.05)], [0.012, 0.011, 0.01, 0.007, 0.002], coral, segs=6, name="Coral")
    I.lathe([(0.0, 0.0), (0.03, 0.02), (0.04, 0.06), (0.025, 0.1), (0.0, 0.13)], pm("#F2D7B6", rough=0.4, var=0.08),
            segs=10, loc=(0.045, -0.01, TOP - 0.3), rot=(0, 25, 0), smooth=False, name="Conch")
    for z in (0.28, 0.5):
        for k in range(4):
            a = math.radians(90 * k + 45)
            I.sphere(0.011, pearl, segs=8, rings=5, loc=(0.03 * math.cos(a), 0.03 * math.sin(a), z), smooth=False,
                     name="Pearl")
    grip_wrap(teal)
    I.sphere(0.03, pearl, segs=12, rings=7, loc=(0, 0, BUTT - 0.03), smooth=False, name="PearlButt")
    staff_points((0, 0, TOP + 0.22), TOP + 0.33)


def mechanical():  # Tesla Coil Staff: metal staff with a copper coil stack, toroid top and lightning arcs
    metal = pm("#9AA4B2", metal=0.85, rough=0.3, var=0.06)
    dark = pm("#3A3F48", metal=0.8, rough=0.35, var=0.08)
    copper = pm("#C8733A", metal=0.85, rough=0.35, var=0.08)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    shaft(metal, segs=12)
    I.cyl(0.05, 0.05, dark, segs=14, loc=(0, 0, TOP + 0.01), bevel=0.0, smooth=False, name="Base")
    for k in range(6):
        I.torus(0.032 - k * 0.002, 0.008, copper, segs=14, rsegs=4, loc=(0, 0, TOP + 0.05 + k * 0.022), name="Coil")
    I.cyl(0.022, 0.14, dark, segs=12, loc=(0, 0, TOP + 0.1), bevel=0.0, smooth=False, name="Core")
    I.torus(0.065, 0.024, metal, segs=20, rsegs=8, loc=(0, 0, TOP + 0.2), name="Toroid")
    orb(0.035, plasma, TOP + 0.23)
    for k in range(3):
        a = math.radians(30 + 120 * k)
        c, s = math.cos(a), math.sin(a)
        pts = [(0.085 * c, 0.085 * s, TOP + 0.2), (0.13 * c + 0.02 * s, 0.13 * s, TOP + 0.24),
               (0.15 * c - 0.02 * s, 0.15 * s, TOP + 0.2), (0.19 * c, 0.19 * s, TOP + 0.25)]
        P.tube(pts, [0.006, 0.005, 0.004, 0.002], plasma, segs=4, name="Arc")
    for z in (0.42, 0.58):
        I.torus(0.029, 0.007, plasma, segs=12, rsegs=4, loc=(0, 0, z), name="GlowRing")
    I.box(0.05, 0.05, 0.08, pm("#FFC21F", rough=0.4, var=0.06), loc=(0, 0, 0.3), bevel=0.005, segments=2, smooth=False,
          name="Battery")
    I.box(0.03, 0.052, 0.012, plasma, loc=(0, 0, 0.3), bevel=0.0, smooth=False, name="BatteryLight")
    grip_wrap(dark, turns=5)
    I.box(0.05, 0.05, 0.05, dark, loc=(0, 0, BUTT - 0.02), bevel=0.005, segments=2, smooth=False, name="Butt")
    staff_points((0, 0, TOP + 0.23), TOP + 0.27)


def void():  # Void Staff: dark crystal staff, black-hole orb with crossed orbit rings, crystal crown, shards
    dark = pm("#3A2C55", metal=0.35, rough=0.15, var=0.1)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2, var=0.08)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    black = pm("#0E0A16", metal=0.2, rough=0.1, var=0.03)
    shaft(obs, r=0.028)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        P.crystal((0.035 * math.cos(a), 0.035 * math.sin(a), TOP + 0.0), 0.03, 0.22, dark,
                  tilt=(-30 * math.sin(a), 30 * math.cos(a), 0))
    orb(0.095, black, TOP + 0.27)
    I.torus(0.15, 0.011, glow, segs=28, rsegs=5, loc=(0, 0, TOP + 0.27), rot=(70, 0, 25), name="Orbit")
    I.torus(0.135, 0.01, glow, segs=28, rsegs=5, loc=(0, 0, TOP + 0.27), rot=(70, 0, -40), name="Orbit")
    I.torus(0.105, 0.008, glow, segs=24, rsegs=4, loc=(0, 0, TOP + 0.27), rot=(90, 0, 0), name="Horizon")
    for k in range(4):
        a = math.radians(90 * k + 20)
        P.crystal((0.21 * math.cos(a), 0.06 * math.sin(a), TOP + 0.27 + 0.13 * math.sin(a)), 0.018, 0.09, glow,
                  tilt=(20 * math.sin(a), -30 * math.cos(a), 0))
    for z in (0.25, 0.45, 0.65):
        I.torus(0.0315, 0.007, glow, segs=12, rsegs=4, loc=(0, 0, z), name="GlowRing")
    grip_wrap(glow, r=0.0305, turns=4)
    P.crystal((0, 0, BUTT + 0.02), 0.03, 0.12, dark, tilt=(180, 0, 0))
    staff_points((0, 0, TOP + 0.27), TOP + 0.42)


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
