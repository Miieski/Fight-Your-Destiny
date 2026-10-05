"""Sword category: 12 builders, zone 1 -> 12 (more craftsmanship and detail as the zones go up).
Real scale: ~1.25 m long (4.5 studs), grip center at the origin, blade along +Z."""
import math

import fyd_icons as I
from fyd_weapon_parts import blade, blade_outline, crystal, gem, grip, guard_bar, pommel_ball, spike, strip
from fyd_weapons import pm

Z0 = 0.125  # blade root height (just above the guard)


def plains():  # Iron Shortsword: plain iron, leather grip
    iron = pm("#B9C1C9", metal=0.85, rough=0.35)
    dark = pm("#5C6168", metal=0.8, rough=0.45)
    blade(blade_outline(0.9, 0.058, taper=0.88, tip_start=0.84), 0.012, iron)
    strip(0, Z0 + 0.36, 0.55, 0.009, 0.0135, dark)
    guard_bar(0.2, dark)
    for x in (-0.1, 0.1):
        I.sphere(0.014, dark, segs=8, rings=6, loc=(x, 0, 0.11))
    grip(pm("#6B3E22", rough=0.7), wraps=5, wrap_material=pm("#4A2A16", rough=0.75))
    pommel_ball(0.026, dark)


def desert():  # Sand Scimitar: curved pale blade, gold guard, turquoise gem
    steel = pm("#DCD6C8", metal=0.85, rough=0.3)
    gold = pm("#E2B04A", metal=0.9, rough=0.3)
    blade(blade_outline(0.92, 0.058, taper=1.0, tip_start=0.8, curve=0.2, widen=0.35), 0.011, steel)
    guard_bar(0.15, gold, height=0.032)
    for x in (-0.085, 0.085):
        I.torus(0.016, 0.006, gold, segs=10, rsegs=5, loc=(x, 0, 0.125), rot=(90, 0, 0))
    gem(0.012, pm("#2EC4B6", rough=0.15), (0, -0.02, 0.11))
    grip(pm("#D2B48C", rough=0.8), wraps=6, wrap_material=pm("#B08A5A", rough=0.8))
    I.cyl(0.022, 0.05, gold, r2=0.006, segs=10, loc=(0, 0, -0.125), rot=(180, 0, 0), bevel=0.0)


def jungle():  # Jungle Machete: wide blade, wooden handle with vines, fang guard
    steel = pm("#9AA39F", metal=0.75, rough=0.45)
    pts = [(-0.022, 0.0), (0.03, 0.0), (0.05, 0.3), (0.068, 0.62), (0.072, 0.74), (0.05, 0.82), (-0.024, 0.79)]
    blade(pts, 0.012, steel)
    strip(-0.012, Z0 + 0.38, 0.62, 0.006, 0.0135, pm("#6E7774", metal=0.7, rough=0.5))
    wood = pm("#7A5230", rough=0.7)
    I.box(0.075, 0.03, 0.03, wood, loc=(0.004, 0, 0.11), bevel=0.006, segments=1)
    bone = pm("#EDE3C8", rough=0.5)
    for side in (-1, 1):
        spike((side * 0.03, 0, 0.11), (side * 0.07, 0, 0.07), 0.009, bone)
    grip(wood, r=0.018, wraps=4, wrap_material=pm("#3C8F3A", rough=0.6))
    pommel_ball(0.022, wood)
    gem(0.01, pm("#5FD45A", rough=0.3), (0, 0, -0.15))


def tundra():  # Frostbrand Blade: ice-steel blade with a glowing frost fuller, crystal guard
    ice_steel = pm("#C6E9FA", metal=0.6, rough=0.18)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    ice = pm("#A8DDF5", rough=0.12)
    blade(blade_outline(0.95, 0.066, taper=0.8, tip_start=0.8), 0.013, ice_steel)
    strip(0, Z0 + 0.4, 0.62, 0.012, 0.0145, glow)
    guard_bar(0.12, pm("#DDE6EE", metal=0.8, rough=0.3), height=0.034)
    for side in (-1, 1):
        crystal((side * 0.055, 0, 0.115), 0.016, 0.09, ice, tilt=(0, side * 65, 0))
    grip(pm("#E8EEF2", rough=0.6), wraps=5, wrap_material=pm("#9FB4C6", metal=0.7, rough=0.35))
    crystal((0, 0, -0.105), 0.02, 0.07, ice, tilt=(180, 0, 0))


def swamp():  # Rotwood Sword: serrated rusty blade, twisted branch guard, toxic gem
    rust = pm("#6F7A5A", metal=0.55, rough=0.6)
    blade(blade_outline(0.9, 0.062, taper=0.82, tip_start=0.82, serr_left=6, serr_depth=0.35), 0.012, rust)
    strip(0.006, Z0 + 0.36, 0.5, 0.008, 0.0135, pm("#4E5A3E", metal=0.5, rough=0.65))
    wood = pm("#4A3A2A", rough=0.8)
    I.tube([(-0.11, 0, 0.13), (-0.05, 0, 0.105), (0.0, 0, 0.115), (0.06, 0, 0.1), (0.12, 0, 0.135)],
           [0.01, 0.014, 0.016, 0.014, 0.008], wood, segs=8, name="Guard")
    grip(pm("#5A4636", rough=0.8), wraps=4, wrap_material=pm("#5E7A3A", rough=0.7))
    gem(0.022, pm("#7CFF4A", emit=2.5, emit_color="#6CFF30"), (0, 0, -0.125), segs=10)


def volcano():  # Magma Blade: obsidian with glowing lava cracks, rock guard with spikes
    obsidian = pm("#2A2224", metal=0.3, rough=0.25)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    rock = pm("#3B2B28", rough=0.75)
    blade(blade_outline(0.95, 0.072, taper=0.62, tip_start=0.86), 0.014, obsidian)
    for i, (z, ln, r) in enumerate(((0.22, 0.2, 18), (0.42, 0.22, -20), (0.62, 0.2, 16), (0.8, 0.12, -14))):
        strip(0.004 * (1 if i % 2 else -1), Z0 + z, ln, 0.007, 0.0155, lava, rot_y=r)
    guard_bar(0.16, rock, height=0.036)
    for side in (-1, 1):
        spike((side * 0.07, 0, 0.115), (side * 0.11, 0, 0.17), 0.012, rock)
    grip(pm("#6A1A12", rough=0.7), wraps=5, wrap_material=pm("#2A1210", rough=0.7))
    gem(0.022, lava, (0, 0, -0.125), segs=10)


def hell():  # Demon Blade: jagged red-black blade, horn guard, demon eye gem
    metal = pm("#5A1414", metal=0.7, rough=0.3)
    edge = pm("#2A0B0B", metal=0.6, rough=0.35)
    blade(blade_outline(0.95, 0.07, taper=0.75, tip_start=0.84, spikes_left=3, spike_len=0.5), 0.013, metal)
    strip(0.004, Z0 + 0.4, 0.62, 0.008, 0.0145, edge)
    bone = pm("#E3D5BA", rough=0.5)
    guard_bar(0.1, edge, height=0.036)
    for side in (-1, 1):
        I.tube([(side * 0.04, 0, 0.115), (side * 0.1, 0, 0.13), (side * 0.13, 0, 0.19), (side * 0.11, 0, 0.24)],
               [0.016, 0.013, 0.008, 0.003], bone, segs=8, name="Horn")
    eye = pm("#FF3030", emit=3.0, emit_color="#FF2020")
    gem(0.013, eye, (0, -0.02, 0.112))
    grip(pm("#1E1414", rough=0.7), wraps=5, wrap_material=pm("#7A1A1A", rough=0.6))
    pommel_ball(0.024, edge)
    for side in (-1, 1):
        spike((side * 0.015, 0, -0.13), (side * 0.035, 0, -0.17), 0.007, bone)


def heaven():  # Radiant Longsword: white-silver blade, gold fuller, feather wings, halo pommel
    silver = pm("#F2F4F8", metal=0.9, rough=0.14)
    gold = pm("#E8C25A", metal=0.9, rough=0.25)
    white = pm("#FFFFFF", rough=0.45)
    blade(blade_outline(1.0, 0.06, taper=0.86, tip_start=0.86), 0.012, silver)
    strip(0, Z0 + 0.44, 0.7, 0.01, 0.0135, gold)
    guard_bar(0.08, gold, height=0.034)
    for side in (-1, 1):
        wing = [(0.0, 0.0), (0.06, 0.02), (0.12, 0.07), (0.15, 0.13), (0.11, 0.11), (0.09, 0.08), (0.05, 0.05)]
        pts = [(side * x, z) for x, z in wing]
        if side < 0:
            pts = list(reversed(pts))
        I.extrude(pts, 0.01, white, loc=(side * 0.035, 0, 0.1), bevel=0.003, segments=1, smooth=False, name="Wing")
    grip(white, wraps=6, wrap_material=gold)
    I.torus(0.03, 0.006, gold, segs=16, rsegs=5, loc=(0, 0, -0.14), rot=(90, 0, 0))
    gem(0.016, pm("#FFE070", emit=2.5, emit_color="#FFD040"), (0, 0, -0.14))


def dead():  # Deathbringer Sword: notched bone-gray blade, vertebrae spine, ribcage guard, skull pommel, soul gem
    bonesteel = pm("#BDB6A6", metal=0.35, rough=0.55)
    bone = pm("#EFE6CC", rough=0.5)
    blade(blade_outline(0.95, 0.072, taper=0.8, tip_start=0.84, serr_left=5, serr_right=5, serr_depth=0.32), 0.013, bonesteel)
    for k in range(7):
        I.sphere(0.009, bone, segs=8, rings=5, loc=(0, 0, Z0 + 0.08 + k * 0.09), scale=(1.0, 1.25, 0.8))
    guard_bar(0.06, pm("#2E2C36", rough=0.6), height=0.034)
    for side in (-1, 1):
        for k, (r, dz) in enumerate(((0.07, 0.0), (0.058, 0.03), (0.045, 0.058))):
            I.torus(r, 0.007, bone, arc=120, start=0 if side > 0 else 60, segs=12, rsegs=5,
                    loc=(side * 0.02, 0, 0.09 + dz), rot=(90, 0, 0 if side > 0 else 180))
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    gem(0.014, soul, (0, -0.022, 0.112))
    grip(pm("#2E2C36", rough=0.7), wraps=5, wrap_material=bone)
    I.sphere(0.034, bone, segs=12, rings=8, loc=(0, 0, -0.132), scale=(1, 0.95, 1.05))
    I.box(0.04, 0.03, 0.02, bone, loc=(0, -0.006, -0.16), bevel=0.005, segments=1)
    for x in (-0.012, 0.012):
        I.sphere(0.009, soul, segs=6, rings=4, loc=(x, -0.03, -0.128))


def abyss():  # Tidal Sword: wave blade, coral guard, pearl pommel
    teal = pm("#3FB5C8", metal=0.65, rough=0.22)
    blade(blade_outline(0.92, 0.066, taper=0.9, tip_start=0.8, curve=-0.16, wave=0.18), 0.012, teal)
    for k in range(5):
        I.sphere(0.008, pm("#F4F1EA", rough=0.12), segs=8, rings=5, loc=(-0.004 - 0.012 * k * k / 4, 0, Z0 + 0.1 + k * 0.08), scale=(1, 1.3, 1))
    coral = pm("#FF7FAB", rough=0.45)
    guard_bar(0.09, pm("#1F3F6A", metal=0.5, rough=0.4), height=0.034)
    for side in (-1, 1):
        I.tube([(side * 0.04, 0, 0.11), (side * 0.08, 0, 0.13), (side * 0.1, 0, 0.17)], [0.011, 0.008, 0.004], coral, segs=7)
        I.tube([(side * 0.07, 0, 0.125), (side * 0.11, 0, 0.12)], [0.006, 0.003], coral, segs=6)
    grip(pm("#1F3F6A", rough=0.6), wraps=5, wrap_material=pm("#F4F1EA", rough=0.2))
    pommel_ball(0.028, pm("#F4F1EA", rough=0.12))
    gem(0.011, pm("#5FFFF0", emit=2.5, emit_color="#40F0E0"), (0, -0.02, 0.112))


def mechanical():  # Plasma Sword: metal hilt, glowing plasma core between two rails
    metal = pm("#9AA4B2", metal=0.85, rough=0.3)
    dark = pm("#3A3F48", metal=0.8, rough=0.35)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    blade(blade_outline(0.92, 0.05, taper=0.7, tip_start=0.86), 0.01, plasma)
    for side in (-1, 1):
        I.box(0.008, 0.016, 0.62, metal, loc=(side * 0.03, 0, Z0 + 0.31), rot=(0, side * -1.2, 0), bevel=0.002, segments=1)
    I.box(0.11, 0.05, 0.05, dark, loc=(0, 0, 0.11), bevel=0.008, segments=1, name="Guard")
    I.box(0.08, 0.052, 0.012, pm("#FFC21F", rough=0.4), loc=(0, 0, 0.1), bevel=0.0)
    for x in (-0.03, 0.0, 0.03):
        I.box(0.008, 0.054, 0.02, plasma, loc=(x, 0, 0.122), bevel=0.0)
    I.cyl(0.019, 0.2, metal, segs=12, bevel=0.0, name="Grip")
    for k in range(4):
        I.torus(0.02, 0.004, dark, segs=12, rsegs=4, loc=(0, 0, -0.075 + k * 0.05))
    I.box(0.045, 0.045, 0.045, dark, loc=(0, 0, -0.125), bevel=0.006, segments=1)


def void():  # Voidforged Blade: dark crystal blade, purple core, floating shards, crystal guard
    crystal_dark = pm("#2E2242", metal=0.35, rough=0.12)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    blade(blade_outline(1.0, 0.078, taper=0.55, tip_start=0.88), 0.016, crystal_dark, bevel=0.007)
    strip(0, Z0 + 0.42, 0.72, 0.01, 0.0175, glow)
    for side in (-1, 1):
        strip(side * 0.022, Z0 + 0.3, 0.38, 0.005, 0.017, glow, rot_y=side * -2.5)
    obs = pm("#1A1226", metal=0.3, rough=0.2)
    guard_bar(0.08, obs, height=0.04)
    for side in (-1, 1):
        crystal((side * 0.05, 0, 0.11), 0.018, 0.11, crystal_dark, tilt=(0, side * 55, 0))
        crystal((side * 0.03, 0, 0.13), 0.01, 0.06, glow, tilt=(0, side * 30, 0))
    for (x, z, s) in ((0.075, 0.26, 0.012), (-0.07, 0.4, 0.01), (0.065, 0.55, 0.008)):
        crystal((x, 0, z), s, s * 4, glow, tilt=(0, 20 if x > 0 else -20, 0))
    grip(obs, r=0.018, wraps=5, wrap_material=glow)
    crystal((0, 0, -0.105), 0.022, 0.08, crystal_dark, tilt=(180, 0, 0))
    gem(0.012, glow, (0, -0.022, 0.112))


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
