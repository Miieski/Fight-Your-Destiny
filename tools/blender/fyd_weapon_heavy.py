"""Heavy category (axes, hammers, mauls): 12 builders, zone 1 -> 12. ~1.4 m (5 studs). The origin is the
grip center (low on the handle); the head is at the top along +Z, its striking faces / blades along X."""
import math

from mathutils import Matrix

import fyd_icons as I
from fyd_weapon_parts import crystal, gem, spike
from fyd_weapons import pm

BOTTOM = -0.3  # bottom of the handle (pommel below)
HEAD = 0.82  # center of the head


def handle(material, r=0.026, bottom=BOTTOM, top=HEAD + 0.06, segs=10):
    I.cyl(r, top - bottom, material, segs=segs, loc=(0, 0, (top + bottom) / 2), bevel=0.0, name="Handle")


def band(z, material, r=0.031, h=0.03, segs=10):
    I.cyl(r, h, material, segs=segs, loc=(0, 0, z), bevel=0.0, name="Band")


def wrap(material, z0=-0.14, z1=0.14, n=6, r=0.0285):
    for k in range(n):
        I.torus(r, 0.006, material, segs=10, rsegs=4, loc=(0, 0, z0 + (k + 0.5) * (z1 - z0) / n), name="Wrap")


def pommel(material, r=0.034, z=BOTTOM - 0.02, segs=10):
    I.cyl(r, 0.05, material, r2=r * 0.65, segs=segs, loc=(0, 0, z), rot=(180, 0, 0), bevel=0.0, name="Pommel")


def along_x(ob, sign=1, spin=0.0):
    """Point the object's local +Z along sign * X (spin turns it about its own axis first)."""
    loc = ob.location.copy()
    ob.matrix_world = (Matrix.Translation(loc) @ Matrix.Rotation(math.radians(90 * sign), 4, "Y")
                       @ Matrix.Rotation(math.radians(spin), 4, "Z"))
    return ob


def mirror(pts):
    """Mirror an XZ outline across the handle (x -> -x), keeping the winding."""
    return [(-x, z) for x, z in reversed(pts)]


def plains():  # Stone Hammer: rough stone block lashed to a wooden handle
    wood = pm("#8A5A33", rough=0.7)
    stone = pm("#5F5B55", rough=0.9)
    rope = pm("#C9A66B", rough=0.9)
    handle(wood)
    I.box(0.36, 0.18, 0.2, stone, loc=(0, 0, HEAD), bevel=0.04, segments=1, smooth=False, name="Stone")
    for x in (-0.05, 0.05):
        I.box(0.026, 0.192, 0.212, rope, loc=(x, 0, HEAD), bevel=0.006, segments=1, name="Lashing")
    I.torus(0.031, 0.008, rope, segs=10, rsegs=4, loc=(0, 0, HEAD - 0.12))
    wrap(pm("#6B3E22", rough=0.75))
    pommel(pm("#5C6168", metal=0.8, rough=0.45))


def desert():  # Obelisk Hammer: sandstone obelisk head with gold caps and a lapis eye
    wood = pm("#7A5230", rough=0.7)
    sand = pm("#B98A5A", rough=0.85)
    gold = pm("#E2B04A", metal=0.9, rough=0.3)
    handle(wood)
    I.box(0.16, 0.15, 0.15, sand, loc=(0, 0, HEAD), bevel=0.006, segments=1, smooth=False, name="Core")
    for s in (-1, 1):
        along_x(I.cyl(0.106, 0.12, sand, r2=0.08, segs=4, loc=(s * 0.14, 0, HEAD), bevel=0.0, smooth=False, name="Obelisk"), s, 45)
        along_x(I.cyl(0.08, 0.07, gold, r2=0.0, segs=4, loc=(s * 0.235, 0, HEAD), bevel=0.0, smooth=False, name="Cap"), s, 45)
        I.box(0.02, 0.162, 0.162, gold, loc=(s * 0.08, 0, HEAD), bevel=0.003, segments=1, name="GoldBand")
    for y in (-0.075, 0.075):
        gem(0.034, pm("#2F5FD0", metal=0.2, rough=0.15), (0, y, HEAD), segs=8)
    for z in (HEAD - 0.12, 0.45, 0.2):
        band(z, gold, r=0.029, h=0.022)
    wrap(pm("#D2B48C", rough=0.8))
    pommel(gold)


def jungle():  # Totem Club: carved totem head with thunderbird wings, painted bands, feathers
    wood = pm("#6E4A2A", rough=0.75)
    carved = pm("#A0703F", rough=0.7)
    red = pm("#C0392B", rough=0.6)
    teal = pm("#1FA59A", rough=0.6)
    handle(wood, top=0.5)
    I.lathe([(0.03, 0.45), (0.06, 0.58), (0.088, 0.72), (0.094, 0.92), (0.074, 1.0), (0.0, 1.02)], carved, segs=8,
            smooth=False, name="Totem")
    I.torus(0.088, 0.012, red, segs=8, rsegs=4, loc=(0, 0, 0.7))
    I.torus(0.093, 0.012, teal, segs=8, rsegs=4, loc=(0, 0, 0.94))
    for x in (-0.035, 0.035):  # eyes
        I.box(0.03, 0.02, 0.022, pm("#F5F0E1", rough=0.5), loc=(x, -0.088, 0.86), bevel=0.003, segments=1)
        I.box(0.012, 0.024, 0.012, pm("#1A1A1A", rough=0.5), loc=(x, -0.09, 0.86), bevel=0.0)
    beak = I.cyl(0.03, 0.08, pm("#E67E22", rough=0.5), r2=0.0, segs=4, loc=(0, -0.11, 0.8), rot=(90, 0, 0), bevel=0.0, smooth=False)
    beak.name = "Beak"
    for s in (-1, 1):
        wing = [(0.0, 0.0), (0.08, 0.05), (0.17, 0.13), (0.2, 0.2), (0.13, 0.17), (0.12, 0.12), (0.06, 0.1), (0.0, 0.08)]
        pts = [(s * (0.08 + x), z) for x, z in wing]
        I.extrude(pts if s > 0 else list(reversed(pts)), 0.02, teal if s > 0 else red, loc=(0, 0, 0.74), bevel=0.004,
                  segments=1, smooth=False, name="Wing")
    for i, col in enumerate(("#2ECC40", "#E74C3C", "#F1C40F")):
        I.extrude([(0, 0), (0.03, 0.07), (0.0, 0.17), (-0.03, 0.07)], 0.005, pm(col, rough=0.6),
                  loc=(0, 0, 0.99), rot=(0, -25 + 25 * i, 0), bevel=0.0, name="Feather")
    for s in (-1, 1):
        spike((s * 0.05, 0, 0.55), (s * 0.12, 0, 0.6), 0.012, pm("#E8DCC0", rough=0.5), segs=6)
    wrap(pm("#3C8F3A", rough=0.6))
    pommel(carved)


def tundra():  # Glacier Axe: bearded ice blade with a glowing frost edge, ice back spike, fur grip
    haft = pm("#4A5D73", metal=0.3, rough=0.55)
    ice = pm("#7CC8EE", rough=0.08)
    steel = pm("#C9D3DC", metal=0.8, rough=0.3)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    handle(haft)
    I.box(0.07, 0.062, 0.22, steel, loc=(0, 0, HEAD + 0.02), bevel=0.008, segments=1, name="Socket")
    z0 = HEAD - 0.2
    blade = [(0.0, 0.14), (0.06, 0.12), (0.13, 0.06), (0.2, -0.02), (0.27, 0.02), (0.31, 0.14), (0.32, 0.26),
             (0.29, 0.38), (0.22, 0.45), (0.15, 0.38), (0.08, 0.31), (0.0, 0.3)]
    I.extrude(blade, 0.03, ice, loc=(0.03, 0, z0), bevel=0.008, segments=1, smooth=False, name="IceBlade")
    edge = [(0.2, -0.035), (0.28, 0.005), (0.326, 0.14), (0.336, 0.26), (0.302, 0.392), (0.222, 0.465)]
    I.tube([(0.03 + x, 0, z0 + z) for x, z in edge], 0.012, glow, segs=6, name="GlowEdge")
    I.box(0.16, 0.034, 0.012, glow, loc=(0.15, 0, z0 + 0.21), rot=(0, -20, 0), bevel=0.0, name="FrostVein")
    spike((-0.03, 0, HEAD + 0.03), (-0.2, 0, HEAD - 0.02), 0.04, ice, segs=6)
    for k in range(3):
        crystal((0.0, 0.0, HEAD + 0.12), 0.016, 0.1 + 0.03 * (k == 1), ice, tilt=(0, -35 + 35 * k, 0))
    for z in (0.35, 0.1):
        band(z, steel, r=0.029, h=0.02)
    wrap(pm("#EDEAE4", rough=0.95), n=5, r=0.031)
    pommel(steel)


def swamp():  # Swamp Maul: mossy log head with rusty spiked bands, glowing toxic mushrooms
    wood = pm("#5A4636", rough=0.85)
    log = pm("#5A4630", rough=0.85)
    cut = pm("#9C8058", rough=0.8)
    rust = pm("#8A5E3A", metal=0.5, rough=0.55)
    moss = pm("#6E9A3A", rough=0.9)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    I.tube([(0, 0, BOTTOM), (0.012, 0, 0.0), (-0.01, 0, 0.3), (0.012, 0, 0.6), (0, 0, HEAD + 0.05)], 0.027, wood, segs=8, name="Handle")
    along_x(I.cyl(0.105, 0.34, log, segs=10, loc=(0, 0, HEAD), bevel=0.01, segments=1, smooth=False, name="Log"))
    for s in (-1, 1):
        along_x(I.cyl(0.09, 0.012, cut, segs=10, loc=(s * 0.171, 0, HEAD), bevel=0.0, smooth=False, name="CutFace"))
        along_x(I.torus(0.107, 0.016, rust, segs=10, rsegs=4, loc=(s * 0.12, 0, HEAD)))
        for a in (0, 120, 240):
            r = math.radians(a)
            base = (s * 0.12, 0.1 * math.sin(r), HEAD + 0.1 * math.cos(r))
            tip = (s * 0.12, 0.2 * math.sin(r), HEAD + 0.2 * math.cos(r))
            spike(base, tip, 0.024, rust, segs=6)
    for x, sx in ((-0.03, 1.6), (0.06, 1.1)):
        I.ico(0.05, moss, loc=(x, -0.02, HEAD + 0.09), scale=(sx, 1.1, 0.5))
    I.ico(0.04, moss, loc=(0.02, -0.095, HEAD + 0.02), scale=(1.4, 0.4, 1.0))
    for x, h, r in ((0.02, 0.09, 0.05), (-0.07, 0.06, 0.034)):
        I.cyl(0.012, h, pm("#E8E0C8", rough=0.6), segs=6, loc=(x, -0.03, HEAD + 0.09 + h / 2), bevel=0.0)
        I.sphere(r, toxic, segs=10, rings=5, loc=(x, -0.03, HEAD + 0.09 + h), scale=(1, 1, 0.55), name="Mushroom")
    wrap(pm("#5E7A3A", rough=0.7))
    pommel(rust)


def volcano():  # Lava Hammer: obsidian block with glowing magma cracks and a lava crater on top
    black = pm("#3A2E30", metal=0.2, rough=0.6)
    rock = pm("#4A3834", rough=0.85)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    handle(black, r=0.028)
    I.box(0.36, 0.2, 0.22, black, loc=(0, 0, HEAD), bevel=0.02, segments=1, smooth=False, name="Block")
    for s in (-1, 1):
        I.box(0.05, 0.225, 0.245, rock, loc=(s * 0.19, 0, HEAD), bevel=0.012, segments=1, smooth=False, name="Face")
    main = [(-0.16, 0.05), (-0.1, -0.01), (-0.05, 0.05), (0.01, -0.04), (0.07, 0.03), (0.16, -0.04)]
    branch = [(-0.05, 0.05), (-0.03, 0.1)], [(0.01, -0.04), (0.03, -0.1)], [(0.07, 0.03), (0.1, 0.09)]
    for y in (-0.1, 0.1):
        I.tube([(x, y, HEAD + z) for x, z in main], 0.011, lava, segs=5, name="Crack")
        for br in branch:
            I.tube([(x, y, HEAD + z) for x, z in br], [0.009, 0.004], lava, segs=5, name="Crack")
    I.cyl(0.075, 0.1, rock, r2=0.04, segs=8, loc=(0, 0, HEAD + 0.15), bevel=0.0, smooth=False, name="Crater")
    I.ico(0.036, lava, loc=(0, 0, HEAD + 0.2), scale=(1, 1, 0.7))
    for x in (-0.1, 0.1):
        I.cyl(0.03, 0.07, rock, r2=0.0, segs=6, loc=(x, 0, HEAD + 0.14), bevel=0.0, smooth=False, name="Spike")
    for z in (0.3, 0.5):
        I.torus(0.0295, 0.007, lava, segs=10, rsegs=4, loc=(0, 0, z), rot=(8, 0, 0))
    for x in (-0.08, 0.1):
        I.sphere(0.02, lava, segs=6, rings=4, loc=(x, 0, HEAD - 0.12), scale=(1, 1, 1.6), name="Drip")
    wrap(pm("#6A1A12", rough=0.7))
    pommel(rock)


def hell():  # Doom Axe: double demonic crescent blades, horns, glowing demon eye
    black = pm("#1E1414", rough=0.6)
    metal = pm("#6A1A16", metal=0.7, rough=0.3)
    edge = pm("#B23A2E", metal=0.7, rough=0.25)
    bone = pm("#E6D8C0", rough=0.5)
    handle(black, r=0.027)
    blade = [(0.0, -0.08), (0.1, -0.12), (0.19, -0.2), (0.25, -0.1), (0.28, 0.04), (0.26, 0.18), (0.2, 0.3),
             (0.11, 0.2), (0.0, 0.15)]
    for s in (-1, 1):
        pts = [(s * x, z) for x, z in blade]
        I.extrude(pts if s > 0 else list(reversed(pts)), 0.022, metal, loc=(s * 0.03, 0, HEAD - 0.02), bevel=0.006,
                  segments=1, smooth=False, name="AxeBlade")
        I.tube([(s * (0.03 + x), 0, HEAD - 0.02 + z) for x, z in ((0.19, -0.2), (0.25, -0.1), (0.28, 0.04), (0.26, 0.18), (0.2, 0.3))],
               0.01, edge, segs=6, name="Edge")
        I.tube([(s * 0.03, 0, HEAD + 0.1), (s * 0.11, 0, HEAD + 0.17), (s * 0.14, 0, HEAD + 0.27), (s * 0.1, 0, HEAD + 0.35)],
               [0.03, 0.024, 0.014, 0.003], bone, segs=6, name="Horn")
    I.box(0.075, 0.06, 0.22, black, loc=(0, 0, HEAD), bevel=0.008, segments=1, name="Socket")
    gem(0.034, pm("#FF3030", emit=3.0, emit_color="#FF2020"), (0, -0.034, HEAD + 0.02))
    I.cyl(0.02, 0.16, edge, r2=0.0, segs=4, loc=(0, 0, HEAD + 0.19), bevel=0.0, smooth=False, name="TopSpike")
    for z in (0.15, 0.4):
        for s in (-1, 1):
            spike((s * 0.02, 0, z), (s * 0.06, 0, z + 0.03), 0.01, edge, segs=5)
    wrap(pm("#7A1A1A", rough=0.6))
    pommel(edge)


def heaven():  # Judgment Hammer: white and gold warhammer, feathered wings, halo, sun gem
    white = pm("#FFFFFF", rough=0.4)
    gold = pm("#E8B84A", metal=0.9, rough=0.25)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    handle(white)
    I.box(0.15, 0.15, 0.17, gold, loc=(0, 0, HEAD), bevel=0.012, segments=1, name="Core")
    wing = [(0.0, 0.0), (0.08, 0.02), (0.15, 0.08), (0.2, 0.17), (0.22, 0.29), (0.17, 0.23), (0.16, 0.27), (0.12, 0.19),
            (0.1, 0.22), (0.06, 0.13), (0.03, 0.1)]
    for s in (-1, 1):
        along_x(I.cyl(0.085, 0.12, white, segs=12, loc=(s * 0.13, 0, HEAD), bevel=0.0, name="Face"))
        along_x(I.torus(0.084, 0.016, gold, segs=12, rsegs=4, loc=(s * 0.19, 0, HEAD)))
        along_x(I.torus(0.088, 0.012, gold, segs=12, rsegs=4, loc=(s * 0.085, 0, HEAD)))
        pts = [(s * x, z) for x, z in wing]
        I.extrude(pts if s > 0 else list(reversed(pts)), 0.014, white, loc=(s * 0.04, 0.0, HEAD + 0.06), bevel=0.003,
                  segments=1, smooth=False, name="Wing")
    gem(0.034, sun, (0, -0.078, HEAD), segs=10)
    I.cyl(0.024, 0.14, gold, r2=0.0, segs=6, loc=(0, 0, HEAD + 0.155), bevel=0.0, smooth=False, name="TopSpike")
    I.torus(0.09, 0.01, sun, segs=18, rsegs=5, loc=(0, 0, HEAD + 0.28), rot=(90, 0, 0), name="Halo")
    for z in (HEAD - 0.11, 0.45, 0.2):
        band(z, gold, r=0.03, h=0.026)
    wrap(gold)
    pommel(gold)


def dead():  # Gravedigger's Maul: tombstone head with a glowing cross, chains, skull collar, bone spikes
    dark = pm("#3A3440", rough=0.75)
    stone = pm("#6A6C78", rough=0.9)
    iron = pm("#4A4A52", metal=0.6, rough=0.7)
    bone = pm("#EFE6CC", rough=0.5)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    handle(dark)
    arc = [(0.1 + 0.1 * math.cos(math.radians(a)), 0.1 * math.sin(math.radians(a))) for a in range(-90, 91, 30)]
    I.extrude([(-0.18, -0.1)] + arc + [(-0.18, 0.1)], 0.14, stone, loc=(0, 0, HEAD), bevel=0.01, segments=1,
              smooth=False, name="Tombstone")
    I.box(0.03, 0.15, 0.212, iron, loc=(-0.18, 0, HEAD), bevel=0.005, segments=1, name="Cap")
    I.box(0.03, 0.148, 0.16, soul, loc=(0.07, 0, HEAD - 0.005), bevel=0.0, name="CrossV")
    I.box(0.11, 0.148, 0.03, soul, loc=(0.07, 0, HEAD + 0.035), bevel=0.0, name="CrossH")
    for x in (-0.07, -0.11):  # chain wrapped around the stone
        I.torus(0.11, 0.008, iron, segs=8, rsegs=4, loc=(x, 0, HEAD), rot=(0, 90, 0), scale=(1.15, 0.8, 1), name="Chain")
    I.sphere(0.055, bone, segs=10, rings=7, loc=(0, -0.012, HEAD - 0.15), scale=(1, 0.95, 1.05), name="Skull")
    I.box(0.06, 0.04, 0.03, bone, loc=(0, -0.03, HEAD - 0.205), bevel=0.006, segments=1, name="Jaw")
    for x in (-0.02, 0.02):
        I.sphere(0.013, soul, segs=6, rings=4, loc=(x, -0.06, HEAD - 0.145))
    for x in (-0.13, -0.05, 0.03):
        spike((x, 0, HEAD + 0.09), (x - 0.015, 0, HEAD + 0.18), 0.017, bone, segs=5)
    for z in (0.3, 0.05):
        band(z, iron, r=0.029, h=0.02)
    wrap(bone)
    pommel(iron)


def abyss():  # Kraken Anchor: heavy anchor (arms up) with tentacles coiling around the shank
    metal = pm("#2A5A70", metal=0.75, rough=0.3)
    teal = pm("#3FB5C8", metal=0.65, rough=0.22)
    flesh = pm("#A8447A", rough=0.45)
    glow = pm("#5FFFF0", emit=2.5, emit_color="#40F0E0")
    handle(metal, r=0.034, top=HEAD - 0.05)
    I.torus(0.2, 0.036, metal, segs=12, rsegs=6, arc=180, start=180, loc=(0, 0, HEAD + 0.14), rot=(90, 0, 0), name="Arms")
    I.box(0.11, 0.08, 0.08, metal, loc=(0, 0, HEAD - 0.06), bevel=0.012, segments=1, name="Crown")
    fluke = [(0.0, -0.03), (0.12, 0.07), (0.06, 0.08), (0.0, 0.22), (-0.06, 0.08), (-0.12, 0.07)]
    for s in (-1, 1):
        I.extrude(fluke, 0.04, teal, loc=(s * 0.2, 0, HEAD + 0.12), rot=(0, s * -20, 0), bevel=0.008, segments=1,
                  smooth=False, name="Fluke")
    I.box(0.26, 0.04, 0.04, metal, loc=(0, 0, -0.24), bevel=0.01, segments=1, name="Stock")
    I.torus(0.055, 0.015, teal, segs=12, rsegs=5, loc=(0, 0, BOTTOM - 0.055), rot=(90, 0, 0), name="Ring")
    for phase, z0, z1 in ((0, 0.2, HEAD - 0.02), (180, 0.28, HEAD + 0.02)):
        pts, radii = [], []
        n = 12
        for i in range(n + 1):
            t = i / n
            a = math.radians(phase + 540 * t)
            pts.append((0.05 * math.cos(a), 0.05 * math.sin(a), z0 + (z1 - z0) * t))
            radii.append(0.024 * (1 - t) + 0.005)
        I.tube(pts, radii, flesh, segs=6, name="Tentacle")
        for i in (3, 6, 9):
            I.sphere(0.009, glow, segs=6, rings=4, loc=(pts[i][0] * 1.4, pts[i][1] * 1.4, pts[i][2]))
    I.tube([(0.17, 0, HEAD + 0.02), (0.23, -0.03, HEAD + 0.06), (0.24, -0.04, HEAD + 0.0), (0.2, -0.04, HEAD - 0.06),
            (0.22, -0.03, HEAD - 0.1)], [0.022, 0.018, 0.013, 0.008, 0.003], flesh, segs=6, name="TentacleTip")
    gem(0.036, glow, (0, -0.045, HEAD - 0.06), segs=8)
    wrap(pm("#F4F1EA", rough=0.3), z0=-0.12, z1=0.12, n=5, r=0.0375)


def mechanical():  # Hydraulic Hammer: piston chamber, ram face, pipes, gauge, glowing core
    metal = pm("#9AA4B2", metal=0.85, rough=0.3)
    dark = pm("#3A3F48", metal=0.8, rough=0.35)
    yellow = pm("#FFC21F", rough=0.4)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    handle(metal, segs=12)
    along_x(I.cyl(0.1, 0.22, dark, segs=12, loc=(0.0, 0, HEAD), bevel=0.0, name="Chamber"))
    along_x(I.cyl(0.05, 0.08, metal, segs=12, loc=(0.14, 0, HEAD), bevel=0.0, name="Ram"))
    along_x(I.cyl(0.125, 0.05, yellow, segs=12, loc=(0.2, 0, HEAD), bevel=0.006, segments=1, name="StrikeFace"))
    along_x(I.torus(0.125, 0.012, dark, segs=12, rsegs=4, loc=(0.2, 0, HEAD)))
    for x in (-0.06, 0.04):
        I.cyl(0.018, 0.1, metal, segs=8, loc=(x, 0.03, HEAD + 0.13), bevel=0.0, name="Exhaust")
        I.cyl(0.022, 0.015, dark, segs=8, loc=(x, 0.03, HEAD + 0.18), bevel=0.0, name="ExhaustCap")
    along_x(I.cyl(0.08, 0.07, metal, r2=0.06, segs=12, loc=(-0.14, 0, HEAD), bevel=0.0, name="Engine"), -1)
    along_x(I.cyl(0.05, 0.02, plasma, segs=12, loc=(-0.18, 0, HEAD), bevel=0.0, name="CoreWindow"), -1)
    for x in (-0.07, 0.0, 0.07):
        along_x(I.torus(0.102, 0.009, metal, segs=12, rsegs=4, loc=(x, 0, HEAD)))
    I.cyl(0.035, 0.02, dark, segs=12, loc=(0.0, -0.1, HEAD), rot=(90, 0, 0), bevel=0.0, name="Gauge")
    I.cyl(0.028, 0.022, pm("#F2F2F2", rough=0.4), segs=12, loc=(0.0, -0.103, HEAD), rot=(90, 0, 0), bevel=0.0, name="Dial")
    I.tube([(0.03, 0, 0.45), (0.05, 0, 0.6), (0.06, 0, HEAD - 0.07)], 0.011, dark, segs=6, name="Pipe")
    I.tube([(-0.03, 0, 0.45), (-0.05, 0, 0.6), (-0.06, 0, HEAD - 0.07)], 0.011, dark, segs=6, name="Pipe")
    for z in (0.45, 0.62):
        I.torus(0.0275, 0.007, plasma, segs=12, rsegs=4, loc=(0, 0, z))
    I.box(0.045, 0.045, 0.07, yellow, loc=(0, 0, 0.3), bevel=0.004, segments=1, name="Battery")
    wrap(dark, n=5)
    I.box(0.045, 0.045, 0.05, dark, loc=(0, 0, BOTTOM - 0.02), bevel=0.005, segments=1, name="Pommel")


def void():  # Void Maul: big faceted dark crystal head, crystal spikes, glowing core, tilted orbit, shards
    dark = pm("#3A2C55", metal=0.35, rough=0.15)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    handle(obs, r=0.028)
    I.ico(0.15, dark, subdiv=1, loc=(0, 0, HEAD), scale=(1.5, 0.85, 1.05), name="CrystalHead")
    I.ico(0.08, glow, subdiv=1, loc=(0, -0.065, HEAD), scale=(1.5, 0.8, 1.0), name="Core")
    for s in (-1, 1):
        crystal((s * 0.17, 0, HEAD), 0.065, 0.2, dark, tilt=(0, s * 90, 0))
        crystal((s * 0.12, 0, HEAD + 0.08), 0.025, 0.14, glow, tilt=(0, s * 40, 0))
        crystal((s * 0.12, 0, HEAD - 0.08), 0.02, 0.1, dark, tilt=(0, s * 140, 0))
    crystal((0, 0, HEAD + 0.12), 0.035, 0.18, dark)
    I.torus(0.27, 0.01, glow, segs=24, rsegs=5, loc=(0, 0, HEAD), rot=(78, 0, 35), scale=(1, 0.55, 1), name="Orbit")
    for k in range(3):
        a = math.radians(120 * k + 60)
        crystal((0.3 * math.cos(a), 0.05 * math.sin(a), HEAD + 0.12 * math.sin(a)), 0.016, 0.08, glow,
                tilt=(20 * math.sin(a), -30 * math.cos(a), 0))
    for z in (0.3, 0.55):
        I.torus(0.0315, 0.007, glow, segs=10, rsegs=4, loc=(0, 0, z))
    wrap(glow, n=4, r=0.0305)
    crystal((0, 0, BOTTOM + 0.02), 0.03, 0.11, dark, tilt=(180, 0, 0))


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
