"""Magic category (staffs): 12 builders, zone 1 -> 12. ~1.68 m (6 studs). The origin is the grip center (lower
part of the shaft); the staff head (orb, crystal, object) is at the top along +Z."""
import math

import fyd_icons as I
from fyd_weapon_parts import crystal, gem, spike
from fyd_weapons import pm

BUTT = -0.5  # bottom of the shaft
TOP = 0.85  # top of the shaft (the head starts here)


def shaft(material, r=0.026, bottom=BUTT, top=TOP, segs=10):
    I.cyl(r, top - bottom, material, segs=segs, loc=(0, 0, (top + bottom) / 2), bevel=0.0, name="Shaft")


def ring(z, material, r=0.03, t=0.008, segs=10):
    I.torus(r, t, material, segs=segs, rsegs=4, loc=(0, 0, z), name="Ring")


def grip_wrap(material, z0=-0.13, z1=0.13, n=6, r=0.028):
    for k in range(n):
        I.torus(r, 0.006, material, segs=10, rsegs=4, loc=(0, 0, z0 + (k + 0.5) * (z1 - z0) / n), name="Wrap")


def butt_cap(material, r=0.03):
    I.cyl(r, 0.06, material, r2=r * 0.55, segs=10, loc=(0, 0, BUTT - 0.025), rot=(180, 0, 0), bevel=0.0, name="Butt")


def orb(r, material, z, segs=16, rings=10, x=0.0):
    return I.sphere(r, material, segs=segs, rings=rings, loc=(x, 0, z), name="Orb")


def prongs(material, z_base, z_orb, r_orb, n=3, r=0.012, spin=90.0, curl=0.35):
    """Prongs rising from the shaft top and curling around an orb."""
    for k in range(n):
        a = math.radians(spin + 360 * k / n)
        c, s = math.cos(a), math.sin(a)
        R = r_orb + r * 1.4
        pts = [(0.02 * c, 0.02 * s, z_base), (R * 0.9 * c, R * 0.9 * s, z_orb - r_orb * 0.6), (R * c, R * s, z_orb),
               (R * 0.8 * c, R * 0.8 * s, z_orb + r_orb * 0.7), (R * curl * c, R * curl * s, z_orb + r_orb * 1.1)]
        I.tube(pts, [r, r * 0.95, r * 0.85, r * 0.6, r * 0.25], material, segs=6, name="Prong")


def plains():  # Apprentice Staff: wooden staff, forked top holding a blue orb, leather grip
    wood = pm("#8A5A33", rough=0.7)
    leather = pm("#4A2E1A", rough=0.8)
    shaft(wood)
    I.cyl(0.032, 0.08, wood, r2=0.026, segs=10, loc=(0, 0, TOP + 0.03), bevel=0.0, name="Head")
    prongs(wood, TOP + 0.06, TOP + 0.21, 0.09, n=3, r=0.018)
    orb(0.09, pm("#3A7BFF", emit=2.0, emit_color="#2A6AFF"), TOP + 0.21)
    grip_wrap(leather)
    ring(TOP - 0.02, pm("#5C6168", metal=0.8, rough=0.45))
    butt_cap(pm("#5C6168", metal=0.8, rough=0.45))


def desert():  # Sandstorm Staff: sandstone and gold staff, a swirling sand vortex around an amber orb
    wood = pm("#B98A5A", rough=0.75)
    gold = pm("#E2B04A", metal=0.9, rough=0.3)
    sand = pm("#C9A060", rough=0.85)
    amber = pm("#FF9A20", emit=2.4, emit_color="#FF7A10")
    shaft(wood)
    for z in (TOP - 0.04, 0.5, 0.22):
        ring(z, gold)
    I.cyl(0.045, 0.06, gold, r2=0.03, segs=10, loc=(0, 0, TOP + 0.02), bevel=0.0, name="Cup")
    for k, (r, z) in enumerate(((0.05, TOP + 0.08), (0.08, TOP + 0.15), (0.105, TOP + 0.23), (0.12, TOP + 0.31), (0.11, TOP + 0.38))):
        I.torus(r, 0.02 - k * 0.002, sand, segs=14, rsegs=5, arc=310, start=40 * k, loc=(0, 0, z), rot=(8, -10 + 5 * k, 0), name="Vortex")
    orb(0.065, amber, TOP + 0.22)
    for s in (-1, 1):
        I.torus(0.05, 0.008, gold, segs=12, rsegs=4, arc=180, start=-90 if s > 0 else 90, loc=(s * 0.03, 0, TOP - 0.1), rot=(90, 0, 0), name="Crescent")
    gem(0.016, pm("#2EC4B6", rough=0.15), (0, -0.03, TOP - 0.1), segs=8)
    grip_wrap(pm("#E3CFA3", rough=0.85))
    butt_cap(gold)


def jungle():  # Shaman Totem Staff: big carved totem head, feathers, hanging beads, green spirit orb
    wood = pm("#6E4A2A", rough=0.75)
    carved = pm("#A0703F", rough=0.7)
    spirit = pm("#7CFF8A", emit=2.4, emit_color="#40FF70")
    shaft(wood, r=0.028)
    I.lathe([(0.03, TOP - 0.18), (0.075, TOP - 0.1), (0.082, TOP + 0.08), (0.07, TOP + 0.13), (0.04, TOP + 0.16)], carved, segs=8,
            smooth=False, name="Totem")
    for x in (-0.03, 0.03):
        I.box(0.028, 0.018, 0.022, pm("#F5F0E1", rough=0.5), loc=(x, -0.074, TOP + 0.04), bevel=0.004, segments=1)
        I.box(0.011, 0.02, 0.011, pm("#1A1A1A", rough=0.5), loc=(x, -0.077, TOP + 0.04), bevel=0.0)
    I.cyl(0.02, 0.06, pm("#E67E22", rough=0.5), r2=0.0, segs=4, loc=(0, -0.1, TOP - 0.01), rot=(90, 0, 0), bevel=0.0, smooth=False, name="Beak")
    I.box(0.07, 0.016, 0.014, pm("#C0392B", rough=0.6), loc=(0, -0.075, TOP - 0.06), bevel=0.0, name="Mouth")
    I.torus(0.078, 0.013, pm("#1FA59A", rough=0.6), segs=8, rsegs=4, loc=(0, 0, TOP - 0.1))
    I.torus(0.082, 0.012, pm("#C0392B", rough=0.6), segs=8, rsegs=4, loc=(0, 0, TOP + 0.1))
    prongs(wood, TOP + 0.14, TOP + 0.3, 0.075, n=2, r=0.015, spin=0)
    orb(0.075, spirit, TOP + 0.3)
    for i, col in enumerate(("#2ECC40", "#E74C3C", "#F1C40F", "#2E86DE")):
        I.extrude([(0, 0), (0.03, 0.08), (0.0, 0.2), (-0.03, 0.08)], 0.006, pm(col, rough=0.6),
                  loc=(0, 0.02, TOP + 0.12), rot=(0, -60 + 40 * i, 0), bevel=0.0, name="Feather")
    for x in (-0.075, 0.075):
        I.tube([(x, 0, TOP - 0.1), (x * 1.2, 0, TOP - 0.24), (x * 1.1, 0, TOP - 0.34)], 0.004, pm("#6B3E22", rough=0.8), segs=4, name="Cord")
        for k, col in enumerate(("#E74C3C", "#F1C40F", "#F5F0E1")):
            I.sphere(0.017, pm(col, rough=0.5), segs=8, rings=5, loc=(x * (1.2 - 0.03 * k), 0, TOP - 0.24 - 0.04 * k), name="Bead")
    grip_wrap(pm("#3C8F3A", rough=0.6), r=0.03)
    butt_cap(carved)


def tundra():  # Blizzard Staff: white staff, ice crystal crown around a glowing snowflake, frost rings
    white = pm("#E8EEF2", rough=0.55)
    steel = pm("#C9D3DC", metal=0.8, rough=0.3)
    ice = pm("#7CC8EE", rough=0.08)
    glow = pm("#2EB8FF", emit=2.2, emit_color="#1AA8FF")
    shaft(pm("#4A5D73", metal=0.3, rough=0.55))
    I.cyl(0.04, 0.08, steel, r2=0.03, segs=10, loc=(0, 0, TOP + 0.02), bevel=0.0, name="Cup")
    for k in range(6):
        a = math.radians(60 * k)
        crystal((0.03 * math.cos(a), 0.03 * math.sin(a), TOP + 0.05), 0.024, 0.22 + 0.06 * (k % 2), ice,
                tilt=(-22 * math.sin(a), 22 * math.cos(a), 0))
    flake = []
    for k in range(12):
        a = math.radians(90 + 30 * k)
        r = 0.13 if k % 2 == 0 else 0.04
        flake.append((r * math.cos(a), r * math.sin(a)))
    I.extrude(flake, 0.018, glow, loc=(0, -0.065, TOP + 0.2), bevel=0.003, segments=1, smooth=False, name="Snowflake")
    I.cyl(0.006, 0.05, steel, segs=6, loc=(0, -0.04, TOP + 0.2), rot=(90, 0, 0), bevel=0.0, name="FlakePin")
    crystal((0, 0, TOP + 0.08), 0.026, 0.3, ice)
    for z in (TOP - 0.05, 0.48, 0.2):
        ring(z, steel)
    grip_wrap(white, n=5)
    crystal((0, 0, BUTT + 0.02), 0.026, 0.1, ice, tilt=(180, 0, 0))


def swamp():  # Cauldron Staff: crooked dark wood, a hanging cauldron bubbling green, bones
    wood = pm("#4A3A2A", rough=0.85)
    iron = pm("#3E3A36", metal=0.6, rough=0.55)
    bone = pm("#D9CBA0", rough=0.55)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    I.tube([(0, 0, BUTT), (0.015, 0, -0.2), (-0.012, 0, 0.2), (0.012, 0, 0.6), (0, 0, TOP), (0.06, 0, TOP + 0.14),
            (0.16, 0, TOP + 0.17), (0.2, 0, TOP + 0.12)], [0.027, 0.027, 0.026, 0.025, 0.024, 0.02, 0.016, 0.012], wood, segs=8,
           name="Shaft")
    I.tube([(0.19, 0, TOP + 0.12), (0.19, 0, TOP + 0.0)], 0.004, iron, segs=4, name="Chain")
    pot = [(0.0, -0.06), (0.05, -0.055), (0.07, -0.03), (0.075, 0.0), (0.065, 0.025), (0.058, 0.03), (0.0, 0.03)]
    I.lathe(pot, iron, segs=12, loc=(0.19, 0, TOP - 0.04), name="Cauldron")
    I.torus(0.06, 0.008, iron, segs=12, rsegs=4, loc=(0.19, 0, TOP - 0.01))
    I.cyl(0.056, 0.012, toxic, segs=12, loc=(0.19, 0, TOP - 0.012), bevel=0.0, name="Brew")
    for x, z, r in ((0.17, TOP + 0.02, 0.018), (0.21, TOP + 0.035, 0.013), (0.2, TOP + 0.07, 0.009)):
        I.sphere(r, toxic, segs=8, rings=5, loc=(x, 0, z), name="Bubble")
    for x in (0.15, 0.23):
        I.tube([(x, 0, TOP - 0.1), (x, 0, TOP - 0.14)], 0.006, toxic, segs=5, name="Drip")
    for s in (-1, 1):
        spike((0.0, 0, TOP - 0.05), (s * 0.08, 0, TOP - 0.1), 0.012, bone, segs=5)
    I.sphere(0.03, bone, segs=10, rings=7, loc=(0, -0.02, TOP - 0.02), scale=(1, 0.9, 1.05), name="Skull")
    grip_wrap(pm("#5E7A3A", rough=0.7))
    I.cyl(0.03, 0.06, bone, r2=0.016, segs=8, loc=(0, 0, BUTT - 0.02), rot=(180, 0, 0), bevel=0.0, name="Butt")


def volcano():  # Eruption Staff: obsidian staff, mini volcano on top with an erupting lava orb, lava veins
    black = pm("#2A2224", metal=0.3, rough=0.45)
    rock = pm("#4A3834", rough=0.85)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    shaft(black, r=0.028)
    I.cyl(0.13, 0.18, rock, r2=0.045, segs=8, loc=(0, 0, TOP + 0.06), bevel=0.0, smooth=False, name="Volcano")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        I.tube([(0.046 * math.cos(a), 0.046 * math.sin(a), TOP + 0.14), (0.095 * math.cos(a), 0.095 * math.sin(a), TOP + 0.05),
                (0.125 * math.cos(a), 0.125 * math.sin(a), TOP - 0.02)], [0.013, 0.01, 0.005], lava, segs=5, name="LavaFlow")
    orb(0.078, lava, TOP + 0.27)
    for x, z, r in ((0.09, TOP + 0.37, 0.022), (-0.075, TOP + 0.4, 0.018), (0.02, TOP + 0.45, 0.015)):
        I.ico(r, lava, loc=(x, 0, z), name="Ember")
    for z in (0.25, 0.45, 0.65):
        I.torus(0.0295, 0.007, lava, segs=10, rsegs=4, loc=(0, 0, z), rot=(8, 0, 0))
    grip_wrap(pm("#8A1F12", rough=0.6))
    butt_cap(rock)


def hell():  # Infernal Tome Staff: an open demonic tome on top, glowing red runes, horns, chains
    black = pm("#1E1414", rough=0.6)
    metal = pm("#6A1A16", metal=0.7, rough=0.3)
    leather = pm("#5A1A16", rough=0.6)
    page = pm("#E6D8C0", rough=0.7)
    rune = pm("#FF3030", emit=3.0, emit_color="#FF2020")
    shaft(black)
    I.box(0.05, 0.05, 0.09, metal, loc=(0, 0, TOP + 0.02), bevel=0.008, segments=1, name="Mount")
    zc = TOP + 0.17
    for s in (-1, 1):
        root = I.empty("Half", loc=(0, 0, zc), rot=(0, 0, s * -22))
        I.box(0.13, 0.014, 0.2, leather, loc=(s * 0.067, 0.0, 0.0), bevel=0.004, segments=1, parent=root, name="Cover")
        I.box(0.12, 0.02, 0.185, page, loc=(s * 0.064, -0.016, 0.0), bevel=0.003, segments=1, parent=root, name="Pages")
        for k in range(4):
            I.box(0.07 - 0.012 * (k % 2), 0.004, 0.008, rune, loc=(s * 0.064, -0.027, 0.06 - k * 0.04), bevel=0.0, parent=root, name="Rune")
        I.box(0.02, 0.022, 0.03, metal, loc=(s * 0.125, -0.01, 0.085), bevel=0.003, segments=1, parent=root, name="Corner")
        I.tube([(s * 0.1, 0, zc + 0.1), (s * 0.15, 0, zc + 0.17), (s * 0.14, 0, zc + 0.24), (s * 0.1, 0, zc + 0.27)],
               [0.016, 0.012, 0.007, 0.002], pm("#E6D8C0", rough=0.5), segs=6, name="Horn")
        I.tube([(s * 0.12, 0, zc - 0.08), (s * 0.13, -0.01, zc - 0.17), (s * 0.11, -0.01, zc - 0.26)], 0.006, metal, segs=5, name="Chain")
    I.cyl(0.012, 0.21, metal, segs=8, loc=(0, 0.004, zc), bevel=0.0, name="Spine")
    gem(0.024, rune, (0, -0.02, zc + 0.13), segs=8)
    for z in (0.28, 0.55):
        ring(z, metal)
    grip_wrap(pm("#7A1A1A", rough=0.6))
    spike((0, 0, BUTT + 0.02), (0, 0, BUTT - 0.09), 0.024, metal, segs=6)


def heaven():  # Seraph Staff: white-gold staff, large wings around a sun orb, halo above
    white = pm("#FFFFFF", rough=0.4)
    gold = pm("#E8B84A", metal=0.9, rough=0.25)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    shaft(white)
    I.cyl(0.042, 0.08, gold, r2=0.028, segs=12, loc=(0, 0, TOP + 0.02), bevel=0.0, name="Cup")
    wing = [(0.0, 0.0), (0.06, 0.03), (0.14, 0.1), (0.2, 0.2), (0.22, 0.32), (0.17, 0.26), (0.16, 0.3), (0.12, 0.22),
            (0.1, 0.25), (0.07, 0.16), (0.04, 0.12)]
    for s in (-1, 1):
        pts = [(s * x, z) for x, z in wing]
        I.extrude(pts if s > 0 else list(reversed(pts)), 0.014, white, loc=(s * 0.03, 0.01, TOP + 0.05), bevel=0.003,
                  segments=1, smooth=False, name="Wing")
    orb(0.07, sun, TOP + 0.17)
    I.torus(0.085, 0.01, gold, segs=18, rsegs=5, loc=(0, 0, TOP + 0.17), rot=(90, 0, 0), name="SunRing")
    I.torus(0.075, 0.009, sun, segs=18, rsegs=5, loc=(0, 0, TOP + 0.35), rot=(20, 0, 0), name="Halo")
    for z in (TOP - 0.05, 0.5, 0.22):
        ring(z, gold)
    grip_wrap(gold)
    butt_cap(gold)


def dead():  # Lich Staff: dark staff with vertebrae, a big crowned skull, bone claws holding a green soul orb
    bone = pm("#E6DCC0", rough=0.55)
    dark = pm("#3A3440", rough=0.75)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    iron = pm("#4A4A52", metal=0.6, rough=0.6)
    shaft(dark, r=0.028)
    for k in range(5):
        I.sphere(0.036, bone, segs=8, rings=5, loc=(0, 0, 0.25 + k * 0.11), scale=(1, 1, 0.55), name="Vertebra")
    zs = TOP + 0.08
    I.sphere(0.095, bone, segs=12, rings=8, loc=(0, 0, zs), scale=(1, 0.95, 1.05), name="Skull")
    I.box(0.1, 0.07, 0.05, bone, loc=(0, -0.025, zs - 0.09), bevel=0.01, segments=1, name="Jaw")
    for x in (-0.034, 0.034):
        I.sphere(0.024, dark, segs=8, rings=5, loc=(x, -0.075, zs + 0.01), scale=(1, 0.5, 1), name="Socket")
        I.sphere(0.016, soul, segs=8, rings=5, loc=(x, -0.085, zs + 0.01))
    I.cyl(0.07, 0.03, iron, segs=10, loc=(0, 0, zs + 0.085), bevel=0.0, name="CrownBand")
    for k in range(5):
        a = math.radians(-70 + 35 * k)
        spike((0.066 * math.sin(a), -0.066 * math.cos(a), zs + 0.09), (0.085 * math.sin(a), -0.085 * math.cos(a), zs + 0.15), 0.014, iron, segs=4)
    prongs(bone, zs + 0.1, zs + 0.27, 0.07, n=3, r=0.014, spin=90, curl=0.2)
    orb(0.07, soul, zs + 0.27)
    for s in (-1, 1):
        I.tube([(s * 0.06, 0, zs - 0.12), (s * 0.12, 0, zs - 0.16), (s * 0.13, 0, zs - 0.24)], [0.012, 0.009, 0.003], bone, segs=6, name="Claw")
    grip_wrap(bone, r=0.03)
    butt_cap(iron)


def abyss():  # Tidecaller Staff: coral staff, a water orb held by curling tentacles, conch shell, pearls
    coral = pm("#E86A8A", rough=0.45)
    teal = pm("#3FB5C8", metal=0.65, rough=0.22)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4)
    water = pm("#5FFFF0", emit=2.2, emit_color="#40F0E0")
    pearl = pm("#F4F1EA", rough=0.12)
    shaft(dark)
    I.cyl(0.045, 0.08, teal, r2=0.03, segs=12, loc=(0, 0, TOP + 0.02), bevel=0.0, name="Cup")
    prongs(pm("#A8447A", rough=0.45), TOP + 0.05, TOP + 0.22, 0.08, n=4, r=0.015, spin=45, curl=0.1)
    orb(0.08, water, TOP + 0.22)
    for s in (-1, 1):
        I.tube([(s * 0.03, 0, TOP - 0.1), (s * 0.08, 0, TOP - 0.06), (s * 0.1, 0, TOP + 0.02), (s * 0.13, 0, TOP + 0.05)],
               [0.012, 0.01, 0.007, 0.002], coral, segs=6, name="Coral")
    I.lathe([(0.0, 0.0), (0.03, 0.02), (0.04, 0.06), (0.025, 0.1), (0.0, 0.13)], pm("#F2D7B6", rough=0.4), segs=8,
            loc=(0.045, -0.01, TOP - 0.3), rot=(0, 25, 0), smooth=False, name="Conch")
    for z in (0.28, 0.5):
        for k in range(4):
            a = math.radians(90 * k + 45)
            I.sphere(0.011, pearl, segs=8, rings=5, loc=(0.03 * math.cos(a), 0.03 * math.sin(a), z))
    grip_wrap(teal)
    I.sphere(0.03, pearl, segs=10, rings=6, loc=(0, 0, BUTT - 0.03), name="Pearl")


def mechanical():  # Tesla Coil Staff: metal staff with a coil stack, toroid top and lightning arcs
    metal = pm("#9AA4B2", metal=0.85, rough=0.3)
    dark = pm("#3A3F48", metal=0.8, rough=0.35)
    copper = pm("#C8733A", metal=0.85, rough=0.35)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    shaft(metal, segs=12)
    I.cyl(0.05, 0.05, dark, segs=12, loc=(0, 0, TOP + 0.01), bevel=0.0, name="Base")
    for k in range(6):
        I.torus(0.032 - k * 0.002, 0.008, copper, segs=12, rsegs=4, loc=(0, 0, TOP + 0.05 + k * 0.022))
    I.cyl(0.022, 0.14, dark, segs=10, loc=(0, 0, TOP + 0.1), bevel=0.0, name="Core")
    I.torus(0.065, 0.024, metal, segs=16, rsegs=8, loc=(0, 0, TOP + 0.2), name="Toroid")
    orb(0.035, plasma, TOP + 0.23)
    for k in range(3):
        a = math.radians(30 + 120 * k)
        c, s = math.cos(a), math.sin(a)
        pts = [(0.085 * c, 0.085 * s, TOP + 0.2), (0.13 * c + 0.02 * s, 0.13 * s, TOP + 0.24), (0.15 * c - 0.02 * s, 0.15 * s, TOP + 0.2),
               (0.19 * c, 0.19 * s, TOP + 0.25)]
        I.tube(pts, [0.006, 0.005, 0.004, 0.002], plasma, segs=4, name="Arc")
    for z in (0.42, 0.58):
        I.torus(0.029, 0.007, plasma, segs=12, rsegs=4, loc=(0, 0, z))
    I.box(0.05, 0.05, 0.08, pm("#FFC21F", rough=0.4), loc=(0, 0, 0.3), bevel=0.005, segments=1, name="Battery")
    grip_wrap(dark, n=5)
    I.box(0.05, 0.05, 0.05, dark, loc=(0, 0, BUTT - 0.02), bevel=0.005, segments=1, name="Butt")


def void():  # Void Staff: dark crystal staff, black-hole orb with crossed orbit rings, crystal crown, shards
    dark = pm("#3A2C55", metal=0.35, rough=0.15)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    black = pm("#0E0A16", metal=0.2, rough=0.1)
    shaft(obs, r=0.028)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        crystal((0.035 * math.cos(a), 0.035 * math.sin(a), TOP + 0.0), 0.03, 0.22, dark, tilt=(-30 * math.sin(a), 30 * math.cos(a), 0))
    orb(0.095, black, TOP + 0.27)
    I.torus(0.15, 0.011, glow, segs=24, rsegs=5, loc=(0, 0, TOP + 0.27), rot=(70, 0, 25), name="Orbit")
    I.torus(0.135, 0.01, glow, segs=24, rsegs=5, loc=(0, 0, TOP + 0.27), rot=(70, 0, -40), name="Orbit")
    I.torus(0.105, 0.008, glow, segs=20, rsegs=4, loc=(0, 0, TOP + 0.27), rot=(90, 0, 0), name="Horizon")
    for k in range(4):
        a = math.radians(90 * k + 20)
        crystal((0.21 * math.cos(a), 0.06 * math.sin(a), TOP + 0.27 + 0.13 * math.sin(a)), 0.018, 0.09, glow,
                tilt=(20 * math.sin(a), -30 * math.cos(a), 0))
    for z in (0.25, 0.45, 0.65):
        I.torus(0.0315, 0.007, glow, segs=10, rsegs=4, loc=(0, 0, z))
    grip_wrap(glow, n=4, r=0.0305)
    crystal((0, 0, BUTT + 0.02), 0.03, 0.12, dark, tilt=(180, 0, 0))


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
