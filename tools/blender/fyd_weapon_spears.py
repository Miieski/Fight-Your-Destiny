"""Spear category: 12 builders, zone 1 -> 12. ~2.24 m (8 studs). The origin is the grip center (lower
third of the shaft); the head points along +Z."""
import math

import fyd_icons as I
from fyd_weapon_parts import blade, blade_outline, crystal, gem, spike, strip
from fyd_weapons import pm

BUTT = -0.72  # bottom of the shaft
TOP = 1.2  # top of the shaft (the head starts here)


def shaft(material, r=0.022, bottom=BUTT, top=TOP, segs=10):
    I.cyl(r, top - bottom, material, segs=segs, loc=(0, 0, (top + bottom) / 2), bevel=0.0, name="Shaft")


def ring(z, material, r=0.026, t=0.007, segs=10):
    I.torus(r, t, material, segs=segs, rsegs=5, loc=(0, 0, z), name="Ring")


def socket(material, z=TOP, r=0.028, h=0.08):
    I.cyl(r * 0.85, h, material, r2=r, segs=10, loc=(0, 0, z + h / 2 - 0.01), bevel=0.0, name="Socket")


def butt_cap(material, r=0.027):
    I.cyl(r, 0.05, material, r2=r * 0.6, segs=10, loc=(0, 0, BUTT - 0.02), rot=(180, 0, 0), bevel=0.0, name="Butt")


def grip_wrap(material, z0=-0.12, z1=0.12, n=6, r=0.0235):
    for k in range(n):
        I.torus(r, 0.005, material, segs=10, rsegs=4, loc=(0, 0, z0 + (k + 0.5) * (z1 - z0) / n), name="Wrap")


def leaf_head(material, L=0.34, w=0.06, z=TOP + 0.06, t=0.014):
    """Leaf-shaped head: widest at 40% of its length, then straight to the tip."""
    pts = blade_outline(L, w, taper=1.0, tip_start=0.4, widen=0.9)
    return blade(pts, t, material, z0=z)


def plains():  # Hunter's Spear
    wood = pm("#8A5A33", rough=0.7)
    iron = pm("#B9C1C9", metal=0.85, rough=0.35)
    shaft(wood)
    socket(pm("#5C6168", metal=0.8, rough=0.45))
    leaf_head(iron)
    grip_wrap(pm("#6B3E22", rough=0.75))
    butt_cap(pm("#5C6168", metal=0.8, rough=0.45))


def desert():  # Nomad Pike: long needle head, gold fittings, pennant
    wood = pm("#B98B55", rough=0.65)
    gold = pm("#E2B04A", metal=0.9, rough=0.3)
    steel = pm("#E4DED0", metal=0.55, rough=0.4)
    shaft(wood)
    socket(gold)
    I.cyl(0.03, 0.46, steel, r2=0.0, segs=4, loc=(0, 0, TOP + 0.29), bevel=0.0, smooth=False, name="Needle")
    for z in (TOP - 0.05, 0.6, 0.0):
        ring(z, gold)
    I.extrude([(0, 0), (0.22, -0.06), (0, -0.14)], 0.004, pm("#C0392B", rough=0.7), loc=(0.016, 0, TOP - 0.08), bevel=0.0, name="Pennant")
    grip_wrap(pm("#D2B48C", rough=0.8))
    butt_cap(gold)


def jungle():  # Tribal Spear: flint head, feathers, vine bindings
    wood = pm("#6E4A2A", rough=0.75)
    flint = pm("#7A7D80", rough=0.4)
    shaft(wood)
    I.lathe([(0.0, 0.0), (0.045, 0.06), (0.035, 0.18), (0.0, 0.3)], flint, segs=6, loc=(0, 0, TOP + 0.02), scale=(1, 0.35, 1),
            smooth=False, name="Flint")
    vine = pm("#3C8F3A", rough=0.6)
    for k in range(4):
        I.torus(0.0235, 0.006, vine, segs=8, rsegs=4, loc=(0, 0, TOP - 0.02 + k * 0.012))
    for i, col in enumerate(("#2ECC40", "#E74C3C", "#F1C40F")):
        a = math.radians(-30 + 30 * i)
        I.extrude([(0, 0), (0.025, 0.06), (0.0, 0.16), (-0.025, 0.06)], 0.004, pm(col, rough=0.6),
                  loc=(0.02 * math.sin(a), -0.012, TOP - 0.2), rot=(0, 160 + 15 * (i - 1), 0), bevel=0.0, name="Feather")
    grip_wrap(vine)
    butt_cap(flint)


def tundra():  # Icicle Lance: conical ice head with a glowing core, vamplate
    white = pm("#E8EEF2", rough=0.55)
    ice = pm("#A8DDF5", rough=0.1)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    steel = pm("#C9D3DC", metal=0.8, rough=0.3)
    shaft(white)
    I.cyl(0.07, 0.1, steel, r2=0.02, segs=12, loc=(0, 0, 0.2), rot=(180, 0, 0), bevel=0.0, name="Vamplate")
    I.cyl(0.045, 0.5, ice, r2=0.0, segs=6, loc=(0, 0, TOP + 0.25), bevel=0.0, smooth=False, name="IceHead")
    I.cyl(0.018, 0.36, glow, r2=0.0, segs=6, loc=(0, 0, TOP + 0.2), bevel=0.0, smooth=False, name="Core")
    for k in range(3):
        a = math.radians(120 * k)
        crystal((0.04 * math.cos(a), 0.04 * math.sin(a), TOP), 0.012, 0.09, ice, tilt=(25 * math.sin(a), -25 * math.cos(a), 0))
    grip_wrap(pm("#9FB4C6", metal=0.7, rough=0.35), z0=-0.05, z1=0.15)
    butt_cap(steel)


def swamp():  # Witch Hunter Spear: wavy rusty head with a side hook, toxic vial
    wood = pm("#5A4636", rough=0.8)
    rust = pm("#8E9A6E", metal=0.5, rough=0.55)
    shaft(wood)
    socket(pm("#3E3A2E", metal=0.5, rough=0.6))
    blade(blade_outline(0.42, 0.095, taper=0.45, tip_start=0.72, wave=0.22), 0.015, rust, z0=TOP + 0.06)
    I.tube([(0.03, 0, TOP + 0.09), (0.11, 0, TOP + 0.12), (0.15, 0, TOP + 0.05)], [0.014, 0.01, 0.004], rust, segs=6, name="Hook")
    I.cyl(0.022, 0.07, pm("#7CFF4A", emit=2.5, emit_color="#6CFF30"), segs=8, loc=(0.04, 0, TOP - 0.14), bevel=0.0, name="Vial")
    grip_wrap(pm("#5E7A3A", rough=0.7))
    butt_cap(rust)


def volcano():  # Obsidian Spear: big obsidian head with a lava core, glowing lava rings on the shaft
    black = pm("#3A2E30", metal=0.3, rough=0.3)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    rock = pm("#4A3834", rough=0.75)
    shaft(black)
    socket(rock, r=0.032)
    blade(blade_outline(0.44, 0.11, taper=0.4, tip_start=0.62, widen=0.25), 0.018, black, z0=TOP + 0.06, bevel=0.007)
    strip(0, TOP + 0.06 + 0.17, 0.3, 0.014, 0.02, lava)
    for z in (0.3, 0.55, 0.8, 1.05):
        I.torus(0.0245, 0.006, lava, segs=10, rsegs=4, loc=(0, 0, z), rot=(8, 0, 0))
    for side in (-1, 1):
        spike((side * 0.025, 0, TOP + 0.02), (side * 0.09, 0, TOP - 0.08), 0.016, rock)
    grip_wrap(pm("#6A1A12", rough=0.7))
    butt_cap(rock)


def hell():  # Infernal Halberd: crescent axe blade, long top spike, back hook, demon eye
    black = pm("#1E1414", rough=0.6)
    metal = pm("#6A1A16", metal=0.7, rough=0.3)
    edge = pm("#B23A2E", metal=0.7, rough=0.25)
    shaft(black)
    crescent = [(0.0, 0.0), (0.08, -0.03), (0.17, -0.1), (0.24, -0.06), (0.28, 0.06), (0.27, 0.19), (0.22, 0.29),
                (0.17, 0.24), (0.13, 0.16), (0.06, 0.15), (0.0, 0.14)]
    I.extrude(crescent, 0.016, metal, loc=(0.018, 0, TOP - 0.1), bevel=0.006, segments=1, smooth=False, name="AxeBlade")
    I.tube([(0.2, 0, TOP - 0.2), (0.29, 0, TOP - 0.04), (0.29, 0, TOP + 0.09), (0.24, 0, TOP + 0.19)], 0.009, edge, segs=6, name="Edge")
    I.cyl(0.032, 0.42, edge, r2=0.0, segs=4, loc=(0, 0, TOP + 0.24), bevel=0.0, smooth=False, name="TopSpike")
    I.tube([(-0.02, 0, TOP + 0.0), (-0.11, 0, TOP + 0.03), (-0.15, 0, TOP + 0.14)], [0.018, 0.012, 0.003], edge, segs=6, name="Hook")
    gem(0.02, pm("#FF3030", emit=3.0, emit_color="#FF2020"), (0.06, -0.016, TOP + 0.0))
    ring(TOP - 0.14, edge)
    grip_wrap(pm("#7A1A1A", rough=0.6))
    butt_cap(edge)


def heaven():  # Celestial Lance: long white-gold head, wings, halo ring
    white = pm("#FFFFFF", rough=0.4)
    gold = pm("#E8C25A", metal=0.9, rough=0.25)
    silver = pm("#F2F4F8", metal=0.9, rough=0.14)
    shaft(white)
    socket(gold)
    blade(blade_outline(0.46, 0.09, taper=0.55, tip_start=0.68, widen=0.2), 0.014, silver, z0=TOP + 0.06)
    strip(0, TOP + 0.06 + 0.16, 0.26, 0.012, 0.0155, gold)
    for side in (-1, 1):
        wing = [(0.0, 0.0), (0.05, 0.03), (0.1, 0.09), (0.12, 0.16), (0.08, 0.12), (0.04, 0.06)]
        pts = [(side * x, z) for x, z in wing]
        if side < 0:
            pts = list(reversed(pts))
        I.extrude(pts, 0.008, white, loc=(side * 0.02, 0, TOP - 0.02), bevel=0.002, segments=1, smooth=False, name="Wing")
    I.torus(0.06, 0.006, pm("#FFE070", emit=2.5, emit_color="#FFD040"), segs=16, rsegs=5, loc=(0, 0, TOP + 0.35), rot=(90, 0, 0), name="Halo")
    for z in (0.5, 0.0):
        ring(z, gold)
    grip_wrap(gold)
    butt_cap(gold)


def dead():  # Grave Pike: bone pike head, skull ornament, rags, soul glow
    dark = pm("#2E2C36", rough=0.7)
    bone = pm("#EFE6CC", rough=0.5)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    shaft(dark)
    I.cyl(0.03, 0.42, bone, r2=0.0, segs=5, loc=(0, 0, TOP + 0.24), bevel=0.0, smooth=False, name="BoneSpike")
    for k in range(3):
        I.sphere(0.022 - k * 0.003, bone, segs=8, rings=5, loc=(0, 0, TOP - 0.01 + k * 0.035), scale=(1, 1, 0.7))
    I.sphere(0.04, bone, segs=12, rings=8, loc=(0, 0, TOP - 0.1), scale=(1, 0.95, 1.05), name="Skull")
    for x in (-0.014, 0.014):
        I.sphere(0.01, soul, segs=6, rings=4, loc=(x, -0.034, TOP - 0.095))
    I.extrude([(0, 0), (0.1, -0.05), (0.08, -0.18), (0.03, -0.12), (0.0, -0.2)], 0.004, pm("#4A4656", rough=0.8),
              loc=(0.018, 0, TOP - 0.13), bevel=0.0, name="Rag")
    grip_wrap(bone)
    butt_cap(bone)


def abyss():  # Deepsea Trident
    teal = pm("#3FB5C8", metal=0.65, rough=0.22)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4)
    shaft(dark)
    I.box(0.2, 0.025, 0.03, teal, loc=(0, 0, TOP + 0.03), bevel=0.006, segments=1, name="Crossbar")
    for x, h in ((-0.09, 0.26), (0.0, 0.34), (0.09, 0.26)):
        I.cyl(0.011, h, teal, segs=6, loc=(x, 0, TOP + 0.04 + h / 2), bevel=0.0, smooth=False, name="Prong")
        I.cyl(0.02, 0.06, teal, r2=0.0, segs=4, loc=(x, 0, TOP + 0.04 + h + 0.03), bevel=0.0, smooth=False, name="ProngTip")
    coral = pm("#FF7FAB", rough=0.45)
    for side in (-1, 1):
        I.tube([(side * 0.02, 0, TOP - 0.05), (side * 0.06, 0, TOP - 0.02), (side * 0.08, 0, TOP + 0.03)], [0.009, 0.006, 0.003], coral, segs=6)
    gem(0.016, pm("#5FFFF0", emit=2.5, emit_color="#40F0E0"), (0, -0.016, TOP + 0.03))
    I.sphere(0.024, pm("#F4F1EA", rough=0.12), segs=10, rings=6, loc=(0, 0, BUTT - 0.03), name="Pearl")
    grip_wrap(pm("#F4F1EA", rough=0.2))


def mechanical():  # Electro Lance: metal shaft with coils, plasma tip
    metal = pm("#9AA4B2", metal=0.85, rough=0.3)
    dark = pm("#3A3F48", metal=0.8, rough=0.35)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    shaft(metal, segs=12)
    I.cyl(0.03, 0.12, dark, segs=12, loc=(0, 0, TOP + 0.02), bevel=0.0, name="Emitter")
    I.cyl(0.026, 0.36, plasma, r2=0.0, segs=8, loc=(0, 0, TOP + 0.26), bevel=0.0, smooth=False, name="PlasmaTip")
    for k in range(4):
        I.torus(0.027, 0.007, plasma if k % 2 else dark, segs=12, rsegs=4, loc=(0, 0, 0.55 + k * 0.08), name="Coil")
    I.box(0.04, 0.04, 0.06, pm("#FFC21F", rough=0.4), loc=(0, 0, 0.25), bevel=0.004, segments=1, name="Battery")
    grip_wrap(dark, n=5)
    I.box(0.04, 0.04, 0.05, dark, loc=(0, 0, BUTT - 0.02), bevel=0.005, segments=1, name="Butt")


def void():  # Void Piercer: faceted crystal blade, orbiting ring and floating crystals, purple glow
    dark = pm("#3A2C55", metal=0.35, rough=0.15)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    shaft(obs)
    socket(dark, r=0.032, h=0.1)
    blade(blade_outline(0.5, 0.1, taper=0.35, tip_start=0.7, widen=0.15), 0.02, dark, z0=TOP + 0.08, bevel=0.008)
    strip(0, TOP + 0.08 + 0.2, 0.34, 0.016, 0.022, glow)
    I.torus(0.1, 0.008, glow, segs=20, rsegs=5, loc=(0, 0, TOP + 0.2), rot=(70, 0, 20), name="Orbit")
    for k in range(3):
        a = math.radians(120 * k + 30)
        crystal((0.13 * math.cos(a), 0.05 * math.sin(a), TOP + 0.1 + 0.06 * k), 0.016, 0.1, glow,
                tilt=(15 * math.sin(a), -25 * math.cos(a), 0))
    for z in (0.3, 0.7):
        I.torus(0.0265, 0.007, glow, segs=10, rsegs=4, loc=(0, 0, z))
    grip_wrap(glow, n=4)
    crystal((0, 0, BUTT + 0.02), 0.026, 0.11, dark, tilt=(180, 0, 0))


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
