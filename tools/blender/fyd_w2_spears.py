"""Spear V2: 12 builders, zone 1 -> 12, rebuilt from the icons (Icons/Weapons/Spear) with more detail.
~2.24 m (8 studs); the origin is the grip center (lower third of the shaft); the head points along +Z."""
import math

import fyd_icons as I
import fyd_w2_parts as P
from fyd_weapons2 import pm, point

BUTT = -0.72  # bottom of the shaft
TOP = 1.2  # top of the shaft (the head starts here)


def shaft(material, r=0.022, bottom=BUTT, top=TOP, segs=12):
    I.cyl(r, top - bottom, material, segs=segs, loc=(0, 0, (top + bottom) / 2), bevel=0.0, smooth=False, name="Shaft")


def ring(z, material, r=0.026, t=0.007, segs=12):
    I.torus(r, t, material, segs=segs, rsegs=5, loc=(0, 0, z), name="Ring")


def socket(material, z=TOP, r=0.028, h=0.08, pins=None):
    I.cyl(r * 0.85, h, material, r2=r, segs=12, loc=(0, 0, z + h / 2 - 0.01), bevel=0.0, smooth=False, name="Socket")
    I.torus(r * 0.86, r * 0.18, material, segs=12, rsegs=4, loc=(0, 0, z - 0.008), name="SocketLip")
    if pins is not None:
        for side in (-1, 1):
            P.rivet((side * r * 0.95, 0, z + h * 0.35), r * 0.2, pins)


def butt_cap(material, r=0.027):
    I.cyl(r, 0.05, material, r2=r * 0.6, segs=12, loc=(0, 0, BUTT - 0.02), rot=(180, 0, 0), bevel=0.0, smooth=False,
          name="Butt")
    I.torus(r * 0.95, r * 0.18, material, segs=12, rsegs=4, loc=(0, 0, BUTT + 0.004), name="ButtRing")


def grip_wrap(material, z0=-0.12, z1=0.12, r=0.0235, turns=7):
    """A spiral leather / cord wrap around the shaft (the hand's place)."""
    pts = []
    steps = turns * 10
    for i in range(steps + 1):
        u = i / steps
        a = 2 * math.pi * turns * u
        pts.append((math.cos(a) * r, math.sin(a) * r, z0 + (z1 - z0) * u))
    I.tube(pts, 0.0055, material, segs=5, name="Wrap")
    for z in (z0, z1):
        I.torus(r, 0.005, material, segs=10, rsegs=4, loc=(0, 0, z), name="WrapEnd")


def leaf_head(material, L=0.34, w=0.06, z=TOP + 0.06, t=0.014):
    """Leaf-shaped head with a center ridge: widest at 40% of its length, then straight to the tip."""
    return P.blade(L, w, t, material, z0=z, profile="diamond", taper=1.0, tip_start=0.4, widen=0.9, n=8)


def head_points(top_z):
    point("Tip", (0, 0, top_z))
    point("Base", (0, 0, TOP - 0.05))


def plains():  # Hunter's Spear: iron leaf head on a wooden shaft, leather wrap
    wood = pm("#8A5A33", rough=0.7, var=0.2, grain=True)
    iron = pm("#B9C1C9", metal=0.85, rough=0.35, var=0.07, scale=140)
    dark = pm("#5C6168", metal=0.8, rough=0.45, var=0.1)
    shaft(wood)
    socket(dark, pins=dark)
    leaf_head(iron)
    grip_wrap(pm("#6B3E22", rough=0.75, var=0.15))
    butt_cap(dark)
    head_points(TOP + 0.06 + 0.34)


def desert():  # Nomad Pike: long square needle head, gold fittings, red pennant
    wood = pm("#B98B55", rough=0.65, var=0.18, grain=True)
    gold = pm("#E2B04A", metal=0.9, rough=0.3, var=0.08)
    steel = pm("#E4DED0", metal=0.55, rough=0.4, var=0.06)
    shaft(wood)
    socket(gold, pins=gold)
    I.cyl(0.03, 0.46, steel, r2=0.0, segs=4, loc=(0, 0, TOP + 0.29), bevel=0.0, smooth=False, name="Needle")
    I.cyl(0.034, 0.03, gold, r2=0.03, segs=4, loc=(0, 0, TOP + 0.075), bevel=0.0, smooth=False, name="NeedleCollar")
    for z in (TOP - 0.05, 0.6, 0.0):
        ring(z, gold)
    P.plate([(0.016, TOP - 0.08), (0.236, TOP - 0.14), (0.016, TOP - 0.22)], 0.004,
            pm("#C0392B", rough=0.7, var=0.15), bevel=0.002, name="Pennant")
    I.torus(0.0235, 0.004, gold, segs=10, rsegs=4, loc=(0, 0, TOP - 0.15), name="PennantTie")
    grip_wrap(pm("#D2B48C", rough=0.8, var=0.15))
    butt_cap(gold)
    head_points(TOP + 0.29 + 0.23)


def jungle():  # Tribal Spear: knapped flint head, vine bindings, three feathers
    wood = pm("#6E4A2A", rough=0.75, var=0.22, grain=True)
    flint = pm("#7A7D80", rough=0.4, var=0.2, scale=90)
    shaft(wood)
    I.lathe([(0.0, 0.0), (0.03, 0.03), (0.045, 0.06), (0.042, 0.12), (0.035, 0.18), (0.02, 0.25), (0.0, 0.3)], flint,
            segs=6, loc=(0, 0, TOP + 0.02), scale=(1, 0.35, 1), smooth=False, name="Flint")
    vine = pm("#3C8F3A", rough=0.6, var=0.15)
    I.tube([(math.cos(a) * 0.0235, math.sin(a) * 0.0235, TOP - 0.025 + a * 0.004) for a in
            [i * 0.6 for i in range(16)]], 0.006, vine, segs=5, name="Binding")
    for i, col in enumerate(("#2ECC40", "#E74C3C", "#F1C40F")):
        a = math.radians(-30 + 30 * i)
        P.plate([(0, 0), (0.025, 0.06), (0.012, 0.11), (0.0, 0.16), (-0.012, 0.11), (-0.025, 0.06)], 0.004,
                pm(col, rough=0.6, var=0.12), bevel=0.003, loc=(0.02 * math.sin(a), -0.012, TOP - 0.2),
                rot=(0, 160 + 15 * (i - 1), 0), name="Feather")
    I.cyl(0.004, 0.06, wood, segs=5, loc=(0.0, -0.012, TOP - 0.17), bevel=0.0, smooth=False, name="FeatherCord")
    grip_wrap(vine)
    butt_cap(flint)
    head_points(TOP + 0.32)


def tundra():  # Icicle Lance: conical ice head with a glowing core, crystal collar, round vamplate
    white = pm("#E8EEF2", rough=0.55, var=0.08)
    ice = pm("#A8DDF5", rough=0.1, var=0.05)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    steel = pm("#C9D3DC", metal=0.8, rough=0.3, var=0.06)
    shaft(white)
    I.cyl(0.07, 0.1, steel, r2=0.02, segs=16, loc=(0, 0, 0.2), rot=(180, 0, 0), bevel=0.0, smooth=False, name="Vamplate")
    I.torus(0.068, 0.006, steel, segs=16, rsegs=4, loc=(0, 0, 0.25), name="VamplateRim")
    I.cyl(0.045, 0.5, ice, r2=0.0, segs=6, loc=(0, 0, TOP + 0.25), bevel=0.0, smooth=False, name="IceHead")
    I.cyl(0.018, 0.36, glow, r2=0.0, segs=6, loc=(0, 0, TOP + 0.2), bevel=0.0, smooth=False, name="Core")
    for k in range(3):
        a = math.radians(120 * k)
        P.crystal((0.04 * math.cos(a), 0.04 * math.sin(a), TOP), 0.012, 0.09, ice,
                  tilt=(25 * math.sin(a), -25 * math.cos(a), 0))
    grip_wrap(pm("#9FB4C6", metal=0.7, rough=0.35, var=0.08), z0=-0.05, z1=0.15)
    butt_cap(steel)
    head_points(TOP + 0.5)


def swamp():  # Witch Hunter Spear: wavy rusty head with a side hook, glowing toxic vial
    wood = pm("#5A4636", rough=0.8, var=0.22, grain=True)
    rust = pm("#8E9A6E", metal=0.5, rough=0.55, var=0.18, scale=80)
    shaft(wood)
    socket(pm("#3E3A2E", metal=0.5, rough=0.6, var=0.12))
    P.blade(0.42, 0.095, 0.015, rust, z0=TOP + 0.06, taper=0.45, tip_start=0.72, wave=0.22, n=14)
    I.tube([(0.03, 0, TOP + 0.09), (0.08, 0, TOP + 0.12), (0.12, 0, TOP + 0.11), (0.15, 0, TOP + 0.05)],
           [0.014, 0.012, 0.008, 0.003], rust, segs=6, smooth=False, name="Hook")
    vial = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    I.cyl(0.022, 0.07, vial, segs=8, loc=(0.04, 0, TOP - 0.14), bevel=0.0, smooth=False, name="Vial")
    I.cyl(0.012, 0.02, pm("#3E3A2E", metal=0.5, rough=0.6), segs=8, loc=(0.04, 0, TOP - 0.095), bevel=0.0,
          smooth=False, name="Cork")
    I.torus(0.0235, 0.004, pm("#3E3A2E", metal=0.5, rough=0.6), segs=10, rsegs=4, loc=(0, 0, TOP - 0.14),
            name="VialStrap")
    grip_wrap(pm("#5E7A3A", rough=0.7, var=0.15))
    butt_cap(rust)
    head_points(TOP + 0.06 + 0.42)


def volcano():  # Obsidian Spear: wide obsidian head with a lava core, lava rings, rock spikes
    black = pm("#3A2E30", metal=0.3, rough=0.3, var=0.12, scale=70)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    rock = pm("#4A3834", rough=0.75, var=0.25, scale=50)
    shaft(black)
    socket(rock, r=0.032)
    P.blade(0.44, 0.11, 0.018, black, z0=TOP + 0.06, profile="diamond", taper=0.4, tip_start=0.62, widen=0.25, n=10)
    P.inlay(0, TOP + 0.06 + 0.17, 0.3, 0.014, 0.02, lava)
    for z in (0.3, 0.55, 0.8, 1.05):
        I.torus(0.0245, 0.006, lava, segs=12, rsegs=4, loc=(0, 0, z), rot=(8, 0, 0), name="LavaRing")
    for side in (-1, 1):
        P.spike((side * 0.025, 0, TOP + 0.02), (side * 0.09, 0, TOP - 0.08), 0.016, rock)
    grip_wrap(pm("#6A1A12", rough=0.7, var=0.15))
    butt_cap(rock)
    head_points(TOP + 0.06 + 0.44)


def hell():  # Infernal Halberd: crescent axe blade with a red edge, long top spike, back hook, demon eye
    black = pm("#1E1414", rough=0.6, var=0.12)
    metal = pm("#6A1A16", metal=0.7, rough=0.3, var=0.12, scale=80)
    edge = pm("#B23A2E", metal=0.7, rough=0.25, var=0.08)
    shaft(black)
    crescent = [(0.0, 0.0), (0.08, -0.03), (0.17, -0.1), (0.24, -0.06), (0.28, 0.06), (0.27, 0.19), (0.22, 0.29),
                (0.17, 0.24), (0.13, 0.16), (0.06, 0.15), (0.0, 0.14)]
    P.plate([(x + 0.018, z + TOP - 0.1) for x, z in crescent], 0.016, metal, bevel=0.014, name="AxeBlade")
    I.tube([(0.2, 0, TOP - 0.2), (0.27, 0, TOP - 0.12), (0.29, 0, TOP - 0.04), (0.295, 0, TOP + 0.03),
            (0.29, 0, TOP + 0.09), (0.24, 0, TOP + 0.19)], 0.009, edge, segs=6, smooth=False, name="Edge")
    I.cyl(0.032, 0.42, edge, r2=0.0, segs=4, loc=(0, 0, TOP + 0.24), bevel=0.0, smooth=False, name="TopSpike")
    I.tube([(-0.02, 0, TOP + 0.0), (-0.07, 0, TOP + 0.01), (-0.11, 0, TOP + 0.03), (-0.15, 0, TOP + 0.14)],
           [0.018, 0.015, 0.012, 0.003], edge, segs=6, smooth=False, name="Hook")
    P.socketed_gem(0.02, pm("#FF3030", emit=3.0, emit_color="#FF2020"), edge, (0.06, -0.016, TOP + 0.0))
    for k in range(3):
        P.rivet((0.03 + 0.06 * k, -0.009, TOP - 0.05), 0.006, edge)
    ring(TOP - 0.14, edge)
    grip_wrap(pm("#7A1A1A", rough=0.6, var=0.12))
    butt_cap(edge)
    head_points(TOP + 0.45)


def heaven():  # Celestial Lance: long silver head with a gold inlay, white wings, glowing halo
    white = pm("#FFFFFF", rough=0.4, var=0.05)
    gold = pm("#E8C25A", metal=0.9, rough=0.25, var=0.08)
    silver = pm("#F2F4F8", metal=0.9, rough=0.14, var=0.05, scale=140)
    shaft(white)
    socket(gold, pins=gold)
    P.blade(0.46, 0.09, 0.014, silver, z0=TOP + 0.06, profile="diamond", taper=0.55, tip_start=0.68, widen=0.2, n=10)
    P.inlay(0, TOP + 0.06 + 0.16, 0.26, 0.012, 0.0155, gold)
    wing = [(0.0, 0.0), (0.05, 0.03), (0.1, 0.09), (0.12, 0.16), (0.1, 0.14), (0.08, 0.12), (0.06, 0.1), (0.04, 0.06)]
    for side in (-1, 1):
        pts = [(side * x + side * 0.02, z + TOP - 0.02) for x, z in wing]
        P.plate(pts if side > 0 else list(reversed(pts)), 0.008, white, bevel=0.004, name="Wing")
    I.torus(0.06, 0.006, pm("#FFE070", emit=2.5, emit_color="#FFD040"), segs=20, rsegs=5, loc=(0, 0, TOP + 0.35),
            rot=(90, 0, 0), name="Halo")
    for z in (0.5, 0.0):
        ring(z, gold)
    grip_wrap(gold)
    butt_cap(gold)
    head_points(TOP + 0.06 + 0.46)


def dead():  # Grave Pike: bone spike over a vertebra stack and a skull with soul eyes, tattered rag
    dark = pm("#2E2C36", rough=0.7, var=0.12)
    bone = pm("#EFE6CC", rough=0.5, var=0.1)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    shaft(dark)
    I.cyl(0.03, 0.42, bone, r2=0.0, segs=5, loc=(0, 0, TOP + 0.24), bevel=0.0, smooth=False, name="BoneSpike")
    for k in range(3):
        I.sphere(0.022 - k * 0.003, bone, segs=8, rings=5, loc=(0, 0, TOP - 0.01 + k * 0.035), scale=(1, 1, 0.7),
                 smooth=False, name="Vertebra")
    I.sphere(0.04, bone, segs=12, rings=8, loc=(0, 0, TOP - 0.1), scale=(1, 0.95, 1.05), smooth=False, name="Skull")
    I.box(0.046, 0.034, 0.022, bone, loc=(0, -0.006, TOP - 0.135), bevel=0.005, segments=1, smooth=False, name="Jaw")
    for x in (-0.014, 0.014):
        I.sphere(0.01, soul, segs=6, rings=4, loc=(x, -0.034, TOP - 0.095), smooth=False, name="Eye")
    P.plate([(0.018, TOP - 0.13), (0.118, TOP - 0.18), (0.098, TOP - 0.31), (0.07, TOP - 0.26), (0.048, TOP - 0.25),
             (0.018, TOP - 0.33)], 0.004, pm("#4A4656", rough=0.8, var=0.2), bevel=0.002, name="Rag")
    grip_wrap(bone)
    butt_cap(bone)
    head_points(TOP + 0.45)


def abyss():  # Deepsea Trident: three barbed prongs on a crossbar, coral, pearl butt
    teal = pm("#3FB5C8", metal=0.65, rough=0.22, var=0.1, scale=70)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4, var=0.1)
    shaft(dark)
    I.box(0.2, 0.025, 0.03, teal, loc=(0, 0, TOP + 0.03), bevel=0.006, segments=2, smooth=False, name="Crossbar")
    for x, h in ((-0.09, 0.26), (0.0, 0.34), (0.09, 0.26)):
        I.cyl(0.011, h, teal, segs=6, loc=(x, 0, TOP + 0.04 + h / 2), bevel=0.0, smooth=False, name="Prong")
        I.cyl(0.02, 0.06, teal, r2=0.0, segs=4, loc=(x, 0, TOP + 0.04 + h + 0.03), bevel=0.0, smooth=False,
              name="ProngTip")
        P.spike((x, 0, TOP + 0.04 + h - 0.01), (x + (0.025 if x <= 0 else -0.025), 0, TOP + 0.04 + h - 0.05),
                0.007, teal, segs=4)
    coral = pm("#FF7FAB", rough=0.45, var=0.15)
    for side in (-1, 1):
        I.tube([(side * 0.02, 0, TOP - 0.05), (side * 0.045, 0, TOP - 0.035), (side * 0.06, 0, TOP - 0.02),
                (side * 0.08, 0, TOP + 0.03)], [0.009, 0.008, 0.006, 0.003], coral, segs=6, smooth=False, name="Coral")
    P.socketed_gem(0.016, pm("#5FFFF0", emit=2.5, emit_color="#40F0E0"), teal, (0, -0.016, TOP + 0.03))
    I.sphere(0.024, pm("#F4F1EA", rough=0.12, var=0.04), segs=12, rings=7, loc=(0, 0, BUTT - 0.03), smooth=False,
             name="Pearl")
    grip_wrap(pm("#F4F1EA", rough=0.2, var=0.04))
    head_points(TOP + 0.04 + 0.34 + 0.06)


def mechanical():  # Electro Lance: metal shaft with coils, emitter and plasma tip, battery pack
    metal = pm("#9AA4B2", metal=0.85, rough=0.3, var=0.06, scale=120)
    dark = pm("#3A3F48", metal=0.8, rough=0.35, var=0.08)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    shaft(metal, segs=12)
    I.cyl(0.03, 0.12, dark, segs=12, loc=(0, 0, TOP + 0.02), bevel=0.0, smooth=False, name="Emitter")
    for k in range(3):
        I.torus(0.031, 0.004, metal, segs=12, rsegs=4, loc=(0, 0, TOP - 0.03 + k * 0.04), name="EmitterRib")
    I.cyl(0.026, 0.36, plasma, r2=0.0, segs=8, loc=(0, 0, TOP + 0.26), bevel=0.0, smooth=False, name="PlasmaTip")
    for k in range(4):
        I.torus(0.027, 0.007, plasma if k % 2 else dark, segs=12, rsegs=4, loc=(0, 0, 0.55 + k * 0.08), name="Coil")
    I.box(0.04, 0.04, 0.06, pm("#FFC21F", rough=0.4, var=0.05), loc=(0, 0, 0.25), bevel=0.004, segments=2,
          smooth=False, name="Battery")
    I.box(0.02, 0.042, 0.008, plasma, loc=(0, 0, 0.25), bevel=0.0, smooth=False, name="BatteryLight")
    grip_wrap(dark, turns=6)
    I.box(0.04, 0.04, 0.05, dark, loc=(0, 0, BUTT - 0.02), bevel=0.005, segments=2, smooth=False, name="Butt")
    head_points(TOP + 0.26 + 0.18)


def void():  # Void Piercer: faceted crystal head with a purple core, orbit ring, floating crystals
    dark = pm("#3A2C55", metal=0.35, rough=0.15, var=0.1, scale=60)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2, var=0.08)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    shaft(obs)
    socket(dark, r=0.032, h=0.1)
    P.blade(0.5, 0.1, 0.02, dark, z0=TOP + 0.08, profile="diamond", taper=0.35, tip_start=0.7, widen=0.15, n=10)
    P.inlay(0, TOP + 0.08 + 0.2, 0.34, 0.016, 0.022, glow)
    I.torus(0.1, 0.008, glow, segs=24, rsegs=5, loc=(0, 0, TOP + 0.2), rot=(70, 0, 20), name="Orbit")
    for k in range(3):
        a = math.radians(120 * k + 30)
        P.crystal((0.13 * math.cos(a), 0.05 * math.sin(a), TOP + 0.1 + 0.06 * k), 0.016, 0.1, glow,
                  tilt=(15 * math.sin(a), -25 * math.cos(a), 0))
    for z in (0.3, 0.7):
        I.torus(0.0265, 0.007, glow, segs=12, rsegs=4, loc=(0, 0, z), name="GlowRing")
    grip_wrap(glow, turns=5)
    P.crystal((0, 0, BUTT + 0.02), 0.026, 0.11, dark, tilt=(180, 0, 0))
    head_points(TOP + 0.08 + 0.5)


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
