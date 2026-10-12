"""Dagger V2: 12 builders, zone 1 -> 12, rebuilt from the icons (Icons/Weapons/Dagger) with more detail.
~0.56 m (2 studs); the origin is the grip center; the blade points along +Z. Built around a 0.16 m grip and a
~0.3 m blade, then scaled to the category length."""
import math

import fyd_icons as I
import fyd_w2_parts as P
from fyd_weapons2 import pm, point

Z0 = 0.1  # blade root
GZ = 0.088  # guard height
GRIP = 0.16  # grip length (z -0.08 .. 0.08)
PZ = -0.095  # pommel height


def wings(material, shape, z, depth=0.008, x0=0.0):
    for s in (-1, 1):
        pts = [(s * (x0 + x), zz + z) for x, zz in shape]
        P.plate(pts if s > 0 else list(reversed(pts)), depth, material, bevel=depth * 0.45, name="Wing")


def dagger_points(tip, base_z=GZ):
    point("Tip", tip)
    point("Base", (0, 0, base_z))


def plains():  # Hunter's Knife: clip-point steel blade, brass bolster, riveted wooden handle, lanyard ring
    steel = pm("#C2C8CE", metal=0.85, rough=0.35, var=0.07, scale=160)
    dark = pm("#5C6168", metal=0.8, rough=0.45, var=0.1)
    brass = pm("#C9A04A", metal=0.85, rough=0.35, var=0.08)
    pts = [(-0.02, 0.0), (0.026, 0.0), (0.03, 0.12), (0.026, 0.2), (0.012, 0.26), (-0.01, 0.3), (-0.016, 0.25), (-0.02, 0.2)]
    P.polygon_blade(pts, 0.012, steel, z0=Z0, bevel=0.009)
    P.fuller(Z0 + 0.11, 0.17, 0.006, dark, x=-0.011, depth=0.0135)
    I.box(0.064, 0.03, 0.022, brass, loc=(0.003, 0, GZ), bevel=0.005, segments=2, smooth=False, name="Bolster")
    I.cyl(0.019, GRIP, pm("#7A4A26", rough=0.7, var=0.22, grain=True), segs=18, bevel=0.0, smooth=False, name="Grip")
    for z in (-0.04, 0.035):
        P.rivet((0, -0.018, z), 0.006, brass)
        P.rivet((0, 0.018, z), 0.006, brass)
    for z in (-0.072, 0.072):
        I.torus(0.0195, 0.004, brass, segs=18, rsegs=4, loc=(0, 0, z), name="Ferrule")
    I.cyl(0.021, 0.026, brass, r2=0.016, segs=16, loc=(0, 0, PZ + 0.006), rot=(180, 0, 0), bevel=0.0, smooth=False,
          name="Pommel")
    I.torus(0.016, 0.0035, pm("#4A2A16", rough=0.8, var=0.1), segs=16, rsegs=4, loc=(0, 0, PZ - 0.022), rot=(90, 0, 0),
            name="Lanyard")
    dagger_points((-0.01, 0, Z0 + 0.3))


def desert():  # Scorpion Dagger: curved amber stinger blade, pincer guard, segmented tail handle, turquoise gem
    amber = pm("#C07A2A", metal=0.3, rough=0.25, var=0.12, scale=90)
    chitin = pm("#7A3E16", metal=0.2, rough=0.35, var=0.12)
    gold = pm("#E2B04A", metal=0.9, rough=0.3, var=0.08)
    L, curve = 0.3, 0.3
    P.blade(L, 0.056, 0.013, amber, z0=Z0, taper=0.55, tip_start=0.72, curve=curve)
    P.inlay(0.004, Z0 + 0.1, 0.14, 0.008, 0.0165, gold, rot_y=8)
    claw = [(0.0, 0.0), (0.05, 0.01), (0.08, 0.04), (0.072, 0.075), (0.062, 0.058), (0.055, 0.045), (0.035, 0.055),
            (0.02, 0.02)]
    wings(chitin, claw, GZ - 0.012, depth=0.016, x0=0.012)
    P.guard(0.05, gold, z=GZ, depth=0.03, height=0.02)
    for k in range(4):
        I.sphere(0.021, chitin, segs=10, rings=6, loc=(0, 0, -0.06 + k * 0.04), scale=(1, 0.9, 0.85), smooth=False,
                 name="Segment")
    for k in range(3):
        I.torus(0.019, 0.004, gold, segs=10, rsegs=4, loc=(0, 0, -0.04 + k * 0.04), name="Joint")
    P.gem(0.017, pm("#2EC4B6", rough=0.15, var=0.0), (0, 0, PZ), facets=8)
    dagger_points((curve * L, 0, Z0 + L))


def jungle():  # Venom Fang: curved ivory fang with a glowing venom groove, scale collar, snake-scale grip
    ivory = pm("#DCC898", rough=0.45, var=0.12, scale=70)
    venom = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    scale = pm("#2E8B3A", rough=0.5, var=0.15)
    P.tube([(0, 0, Z0 - 0.01), (0.004, 0, Z0 + 0.04), (0.008, 0, Z0 + 0.08), (0.015, 0, Z0 + 0.125), (0.025, 0, Z0 + 0.17),
            (0.036, 0, Z0 + 0.21), (0.05, 0, Z0 + 0.25), (0.065, 0, Z0 + 0.285), (0.08, 0, Z0 + 0.31)],
           [0.03, 0.029, 0.027, 0.024, 0.02, 0.016, 0.012, 0.007, 0.002], ivory, segs=8, scale=(1, 0.7, 1), name="Fang")
    I.tube([(0.004, -0.019, Z0 + 0.03), (0.012, -0.0175, Z0 + 0.1), (0.026, -0.0135, Z0 + 0.17), (0.044, -0.009, Z0 + 0.23)],
           [0.0055, 0.005, 0.004, 0.002], venom, segs=6, name="Groove")
    I.torus(0.03, 0.01, scale, segs=10, rsegs=5, loc=(0, 0, GZ), name="Collar")
    for s in (-1, 1):
        P.spike((s * 0.025, 0, GZ), (s * 0.05, 0, GZ - 0.04), 0.008, ivory, segs=6)
    P.gem(0.012, pm("#5FD45A", rough=0.2, var=0.0), (0, -0.034, GZ), facets=8)
    P.grip_wrapped(scale, pm("#1E5A28", rough=0.6, var=0.12), r=0.018, length=GRIP, turns=4)
    P.pommel(0.022, ivory, z=PZ)
    dagger_points((0.08, 0, Z0 + 0.31))


def tundra():  # Ice Shard Dagger: faceted ice shard blade with a glowing core, crystal guard, fur-wrapped grip
    ice = pm("#7CC8EE", rough=0.08, var=0.06)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    steel = pm("#C9D3DC", metal=0.8, rough=0.3, var=0.06)
    I.cyl(0.036, 0.3, ice, r2=0.0, segs=4, loc=(0, 0, Z0 + 0.15), scale=(1, 0.45, 1), bevel=0.0, smooth=False, name="Shard")
    P.inlay(0, Z0 + 0.11, 0.17, 0.01, 0.036, glow)
    P.guard(0.06, steel, z=GZ, depth=0.03, height=0.022)
    for s in (-1, 1):
        P.crystal((s * 0.022, 0, GZ), 0.012, 0.06, ice, tilt=(0, s * 70, 0))
        P.crystal((s * 0.012, 0, GZ + 0.005), 0.008, 0.045, ice, tilt=(0, s * 35, 0))
    P.grip_wrapped(pm("#4A5D73", metal=0.3, rough=0.55, var=0.1), pm("#EDEAE4", rough=0.95, var=0.12), r=0.019,
                   length=GRIP, turns=4)
    P.crystal((0, 0, PZ + 0.01), 0.016, 0.05, ice, tilt=(180, 0, 0))
    dagger_points((0, 0, Z0 + 0.3))


def swamp():  # Toad Tooth Dagger: stained hooked tooth with barbs and toxic slime, warty toad collar, gnarled handle
    tooth = pm("#BFA868", rough=0.6, var=0.18, scale=70)
    toad = pm("#5E8A32", rough=0.6, var=0.15)
    wart = pm("#D9A43A", rough=0.5, var=0.1)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    P.tube([(0, 0, Z0 - 0.01), (-0.003, 0, Z0 + 0.04), (-0.004, 0, Z0 + 0.09), (-0.004, 0, Z0 + 0.135),
            (-0.002, 0, Z0 + 0.18), (0.008, 0, Z0 + 0.225), (0.02, 0, Z0 + 0.26), (0.045, 0, Z0 + 0.3)],
           [0.032, 0.031, 0.03, 0.027, 0.022, 0.017, 0.012, 0.002], tooth, segs=8, scale=(1, 0.6, 1), name="Tooth")
    for z in (Z0 + 0.05, Z0 + 0.11, Z0 + 0.17):
        I.cyl(0.01, 0.034, tooth, r2=0.0, segs=5, loc=(-0.036, 0, z + 0.006), rot=(0, -70, 0), bevel=0.0, smooth=False,
              name="Barb")
    for x, z, h in ((0.008, Z0 + 0.03, 2.4), (-0.012, Z0 + 0.06, 1.6)):
        I.sphere(0.009, toxic, segs=8, rings=5, loc=(x, -0.017, z), scale=(1, 0.6, h), smooth=False, name="Slime")
    I.sphere(0.044, toad, segs=12, rings=7, loc=(0, 0, GZ), scale=(1.3, 1.0, 0.6), smooth=False, name="Collar")
    for x, y in ((-0.03, -0.025), (0.022, -0.03), (0.045, -0.004), (-0.046, 0.006), (0.0, -0.04), (0.03, 0.025)):
        I.sphere(0.008, wart, segs=6, rings=4, loc=(x, y, GZ + 0.014), smooth=False, name="Wart")
    I.tube([(0, 0, -0.08), (0.004, 0, -0.03), (-0.004, 0, 0.02), (0, 0, 0.08)], 0.018, pm("#4A3A2A", rough=0.8, var=0.2,
           grain=True), segs=8, smooth=False, name="Grip")
    for k in range(3):
        I.torus(0.019, 0.005, pm("#5E7A3A", rough=0.7, var=0.12), segs=8, rsegs=4, loc=(0, 0, -0.05 + k * 0.045),
                name="Binding")
    P.gem(0.02, toxic, (0, 0, PZ), facets=10)
    dagger_points((0.045, 0, Z0 + 0.3))


def volcano():  # Ember Dagger: wavy obsidian flame blade with a lava core, flame guard, ember pommel
    obsidian = pm("#2A2224", metal=0.3, rough=0.45, var=0.12, scale=80)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    rock = pm("#4A3834", rough=0.8, var=0.22)
    P.blade(0.29, 0.07, 0.014, obsidian, z0=Z0, taper=0.5, tip_start=0.72, wave=0.14, n=16)
    P.inlay(0, Z0 + 0.11, 0.19, 0.012, 0.0185, lava)
    flames = [(-0.055, 0.0), (0.055, 0.0), (0.07, 0.035), (0.045, 0.022), (0.04, 0.055), (0.022, 0.028), (0.0, 0.065),
              (-0.022, 0.028), (-0.04, 0.055), (-0.045, 0.022), (-0.07, 0.035)]
    P.plate([(x, z + GZ - 0.022) for x, z in flames], 0.024, rock, bevel=0.006, edge=0.4, name="FlameGuard")
    P.gem(0.012, lava, (0, -0.014, GZ - 0.004), facets=8)
    P.grip_wrapped(obsidian, pm("#8A1F12", rough=0.6, var=0.12), r=0.018, length=GRIP, turns=5)
    I.ico(0.022, lava, loc=(0, 0, PZ), name="Ember")
    dagger_points((0, 0, Z0 + 0.29))


def hell():  # Imp Claw Dagger: hooked talon blade, claw guard, red eye, spiked pommel
    metal = pm("#6A1A16", metal=0.7, rough=0.3, var=0.12, scale=90)
    edge = pm("#B23A2E", metal=0.7, rough=0.25, var=0.08)
    black = pm("#1E1414", rough=0.6, var=0.1)
    L, curve = 0.29, -0.38
    P.blade(L, 0.07, 0.014, metal, z0=Z0, taper=0.3, tip_start=0.62, curve=curve, n=16)
    P.inlay(-0.012, Z0 + 0.09, 0.13, 0.008, 0.0175, edge, rot_y=-12)
    P.guard(0.06, black, z=GZ, depth=0.032, height=0.024)
    for s in (-1, 1):
        I.tube([(s * 0.026, 0, GZ), (s * 0.04, 0, GZ + 0.012), (s * 0.05, 0, GZ + 0.03), (s * 0.054, 0, GZ + 0.05),
                (s * 0.052, 0, GZ + 0.07), (s * 0.04, 0, GZ + 0.095)], [0.012, 0.011, 0.009, 0.007, 0.005, 0.001],
               edge, segs=6, smooth=False, name="Claw")
    P.socketed_gem(0.014, pm("#FF3030", emit=3.0, emit_color="#FF2020"), edge, (0, -0.017, GZ))
    P.grip_wrapped(black, pm("#7A1A1A", rough=0.6, var=0.12), r=0.018, length=GRIP, turns=5)
    P.spike((0, 0, PZ + 0.015), (0, 0, PZ - 0.05), 0.016, edge, segs=6)
    dagger_points((curve * L, 0, Z0 + L))


def heaven():  # Feather Dagger: white feather blade with a gold quill and barbs, small gold wings, halo pommel
    white = pm("#FFFFFF", rough=0.4, var=0.05)
    gold = pm("#E8B84A", metal=0.9, rough=0.25, var=0.08)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    L, curve = 0.3, 0.12
    P.blade(L, 0.095, 0.011, white, z0=Z0, taper=0.45, tip_start=0.55, curve=curve, serr_right=3, serr_left=3, n=10,
            serr_depth=0.18)
    P.inlay(0.006, Z0 + 0.12, 0.23, 0.007, 0.0145, gold, rot_y=6)
    barb = pm("#C8D2E2", rough=0.5, var=0.06)
    for k in range(4):
        z = Z0 + 0.03 + k * 0.034
        c = 0.12 * ((z - Z0) / 0.3) ** 2 * 0.3
        for side in (-1, 1):
            I.box(0.026 - k * 0.004, 0.0125, 0.0035, barb, loc=(c + side * 0.015, 0, z + 0.007), rot=(0, side * -32, 0),
                  bevel=0.0, smooth=False, name="Barb")
    wing = [(0.0, 0.0), (0.04, 0.01), (0.075, 0.04), (0.085, 0.075), (0.072, 0.066), (0.06, 0.055), (0.04, 0.05),
            (0.02, 0.025)]
    wings(gold, wing, GZ - 0.012, depth=0.01, x0=0.012)
    P.guard(0.04, gold, z=GZ, depth=0.03, height=0.022)
    P.gem(0.012, sun, (0, -0.016, GZ), facets=8)
    P.grip_wrapped(white, gold, r=0.018, length=GRIP, turns=4)
    P.pommel(0.018, gold, z=PZ)
    I.torus(0.03, 0.005, sun, segs=16, rsegs=4, loc=(0, 0, PZ - 0.035), rot=(90, 0, 0), name="Halo")
    dagger_points((curve * L, 0, Z0 + L))


def dead():  # Ghoul Fang: jagged yellowed bone blade with a soul crack, vertebra / rib guard, skull pommel
    bone = pm("#D8CBA6", rough=0.6, var=0.16, scale=70)
    dark = pm("#3A3440", rough=0.75, var=0.1)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    P.blade(0.29, 0.068, 0.015, bone, z0=Z0, taper=0.5, tip_start=0.75, serr_left=5, serr_right=5, serr_depth=0.6, n=10)
    I.tube([(0.0, 0, Z0 + 0.02), (0.008, 0, Z0 + 0.07), (-0.006, 0, Z0 + 0.12), (0.005, 0, Z0 + 0.17), (0.0, 0, Z0 + 0.21)],
           [0.006, 0.0065, 0.006, 0.005, 0.003], soul, segs=5, scale=(1, 1.6, 1), name="SoulCrack")
    for k, w in enumerate((0.07, 0.05)):
        I.box(w, 0.03, 0.016, bone, loc=(0, 0, GZ - k * 0.02), bevel=0.004, segments=2, smooth=False, name="Vertebra")
    for s in (-1, 1):
        I.tube([(s * 0.03, 0, GZ), (s * 0.045, 0, GZ + 0.008), (s * 0.055, 0, GZ + 0.02), (s * 0.06, 0, GZ + 0.05),
                (s * 0.048, 0, GZ + 0.075)], [0.008, 0.0075, 0.007, 0.005, 0.001], bone, segs=6, smooth=False, name="Rib")
    P.gem(0.012, soul, (0, -0.016, GZ), facets=8)
    P.grip_wrapped(dark, bone, r=0.018, length=GRIP, turns=4)
    I.sphere(0.03, bone, segs=10, rings=7, loc=(0, 0, PZ - 0.014), scale=(1, 0.95, 1.05), smooth=False, name="Skull")
    I.box(0.032, 0.024, 0.014, bone, loc=(0, -0.006, PZ - 0.04), bevel=0.003, segments=1, smooth=False, name="Jaw")
    for x in (-0.011, 0.011):
        I.sphere(0.0085, soul, segs=6, rings=4, loc=(x, -0.025, PZ - 0.01), smooth=False, name="Eye")
    dagger_points((0, 0, Z0 + 0.29))


def abyss():  # Angler Dagger: curved teal blade, needle-tooth guard, glowing angler lure over the blade, pearl
    teal = pm("#3FB5C8", metal=0.65, rough=0.22, var=0.1, scale=80)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4, var=0.1)
    tooth = pm("#F4F1EA", rough=0.3, var=0.05)
    glow = pm("#5FFFF0", emit=2.5, emit_color="#40F0E0")
    L, curve = 0.28, 0.18
    P.blade(L, 0.066, 0.013, teal, z0=Z0, taper=0.6, tip_start=0.7, curve=curve)
    P.inlay(0.003, Z0 + 0.1, 0.15, 0.008, 0.0165, dark, rot_y=5)
    P.guard(0.07, dark, z=GZ, depth=0.03, height=0.022)
    for x in (-0.028, -0.014, 0.0, 0.014, 0.028):
        P.spike((x, -0.008, GZ + 0.008), (x, -0.008, GZ + 0.03), 0.004, tooth, segs=5)
    I.tube([(-0.032, 0, GZ), (-0.052, 0, GZ + 0.035), (-0.065, 0, GZ + 0.08), (-0.066, 0, GZ + 0.13), (-0.06, 0, GZ + 0.17),
            (-0.045, 0, GZ + 0.2), (-0.03, 0, GZ + 0.22)], [0.006, 0.0055, 0.005, 0.0045, 0.004, 0.0035, 0.003], dark,
           segs=6, smooth=False, name="Lure")
    I.sphere(0.017, glow, segs=10, rings=6, loc=(-0.024, 0, GZ + 0.228), smooth=False, name="Bulb")
    P.grip_wrapped(dark, teal, r=0.018, length=GRIP, turns=5)
    I.sphere(0.02, pm("#F4F1EA", rough=0.12, var=0.04), segs=10, rings=6, loc=(0, 0, PZ), smooth=False, name="Pearl")
    dagger_points((curve * L, 0, Z0 + L))


def mechanical():  # Nano Dagger: tanto steel blade with a plasma edge and circuit lines, hex emitter guard, power cell
    steel = pm("#B8C2CE", metal=0.85, rough=0.25, var=0.06, scale=140)
    dark = pm("#3A3F48", metal=0.8, rough=0.35, var=0.08)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    P.polygon_blade([(-0.024, 0.0), (0.026, 0.0), (0.026, 0.22), (0.0, 0.3), (-0.024, 0.26)], 0.012, steel, z0=Z0,
                    bevel=0.008)
    I.tube([(0.028, 0, Z0 + 0.01), (0.028, 0, Z0 + 0.22), (0.001, 0, Z0 + 0.302)], 0.0045, plasma, segs=6, name="PlasmaEdge")
    for x, z0, h in ((-0.006, 0.03, 0.15), (0.008, 0.06, 0.1)):
        I.box(0.004, 0.0135, h, plasma, loc=(x, 0, Z0 + z0 + h / 2), bevel=0.0, smooth=False, name="Circuit")
        I.box(0.012, 0.0135, 0.004, plasma, loc=(x + 0.004, 0, Z0 + z0 + h), bevel=0.0, smooth=False, name="Circuit")
    for z in (0.04, 0.08, 0.12):
        I.box(0.008, 0.014, 0.012, dark, loc=(-0.025, 0, Z0 + z), bevel=0.0, smooth=False, name="Notch")
    I.cyl(0.036, 0.024, dark, segs=6, loc=(0, 0, GZ), scale=(1, 0.7, 1), bevel=0.0, smooth=False, name="HexGuard")
    I.torus(0.03, 0.004, plasma, segs=12, rsegs=4, loc=(0, 0, GZ), scale=(1, 0.75, 1), name="GuardLight")
    for s in (-1, 1):
        I.box(0.03, 0.016, 0.012, dark, loc=(s * 0.045, 0, GZ + 0.006), rot=(0, s * -25, 0), bevel=0.003, segments=1,
              smooth=False, name="Fin")
        I.sphere(0.007, plasma, segs=8, rings=5, loc=(s * 0.061, 0, GZ + 0.014), smooth=False, name="FinLight")
    I.cyl(0.018, GRIP, dark, segs=12, bevel=0.0, smooth=False, name="Grip")
    I.cyl(0.0195, 0.05, plasma, segs=12, loc=(0, 0, -0.005), bevel=0.0, smooth=False, name="Cell")
    for z in (-0.05, -0.03, 0.02, 0.05):
        I.torus(0.0185, 0.004, steel, segs=12, rsegs=4, loc=(0, 0, z), name="Rib")
    I.cyl(0.022, 0.025, steel, segs=6, loc=(0, 0, PZ + 0.008), bevel=0.0, smooth=False, name="Pommel")
    dagger_points((0, 0, Z0 + 0.3))


def void():  # Rift Dagger: dark crystal blade with a glowing rift, crystal guard, orbit ring, floating shards
    dark = pm("#3A2C55", metal=0.35, rough=0.15, var=0.1, scale=60)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2, var=0.08)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    P.blade(0.3, 0.072, 0.016, dark, z0=Z0, profile="diamond", taper=0.35, tip_start=0.66, widen=0.2)
    rift = [(0.0, 0.02), (0.008, 0.06), (-0.007, 0.1), (0.006, 0.14), (-0.004, 0.18), (0.0, 0.21)]
    for y in (-0.0085, 0.0085):
        I.tube([(x, y, Z0 + z) for x, z in rift], 0.0045, glow, segs=5, name="Rift")
    for s in (-1, 1):
        P.crystal((s * 0.02, 0, GZ), 0.014, 0.07, dark, tilt=(0, s * 75, 0))
        P.crystal((s * 0.012, 0, GZ + 0.01), 0.008, 0.05, glow, tilt=(0, s * 30, 0))
    I.torus(0.055, 0.004, glow, segs=20, rsegs=4, loc=(0, 0, GZ + 0.01), rot=(75, 0, 20), name="Orbit")
    for k in range(2):
        a = math.radians(140 + 180 * k)
        P.crystal((0.07 * math.cos(a), 0.0, Z0 + 0.12 + 0.08 * k), 0.008, 0.04, glow, tilt=(0, 20 - 40 * k, 0))
    P.grip_wrapped(obs, glow, r=0.018, length=GRIP, turns=4)
    P.crystal((0, 0, PZ + 0.015), 0.018, 0.06, dark, tilt=(180, 0, 0))
    dagger_points((0, 0, Z0 + 0.3))


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
