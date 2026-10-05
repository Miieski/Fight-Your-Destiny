"""Whip & Chain category: 12 builders, zone 1 -> 12. ~1.68 m (6 studs) = handle + a stylized S-curved lash or
chain rising along +Z (it reads as a whip in the icon; Studio can swap the lash for a rope/Beam later).
The origin is the grip center of the handle."""
import math

from mathutils import Vector

import fyd_icons as I
from fyd_weapon_parts import crystal, gem, spike
from fyd_weapons import pm

HANDLE_BOT = -0.15
HANDLE_TOP = 0.15
LASH_SCALE = 1.3  # lashes drawn thicker than real so they stay readable in the icons


def path(n=18, length=1.3, amp=0.11, waves=1.2, z0=HANDLE_TOP + 0.02, phase=0.0):
    """S-curve from the top of the handle: the sideways swing grows towards the tip."""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = amp * math.sin(2 * math.pi * waves * t + phase) * (0.25 + 0.75 * t) - amp * math.sin(phase) * 0.25
        pts.append((x, 0.0, z0 + length * t))
    return pts


def lash(material, pts, r0=0.018, r1=0.004, segs=8):
    n = len(pts) - 1
    I.tube(pts, [LASH_SCALE * (r0 + (r1 - r0) * i / n) for i in range(n + 1)], material, segs=segs, name="Lash")


def handle(material, r=0.026, wrap=None, n=5):
    I.cyl(r, HANDLE_TOP - HANDLE_BOT, material, segs=10, loc=(0, 0, 0), bevel=0.0, name="Handle")
    if wrap is not None:
        for k in range(n):
            I.torus(r * 1.08, 0.006, wrap, segs=10, rsegs=4, loc=(0, 0, HANDLE_BOT + 0.03 + (k + 0.5) * (HANDLE_TOP - HANDLE_BOT - 0.06) / n),
                    rot=(12 * (-1) ** k, 0, 0), name="Wrap")


def collar(material, r=0.032, h=0.04, z=HANDLE_TOP):
    I.cyl(r, h, material, r2=r * 0.7, segs=10, loc=(0, 0, z + h / 2 - 0.01), bevel=0.0, name="Collar")


def pommel(material, r=0.032, z=HANDLE_BOT - 0.02):
    I.sphere(r, material, segs=10, rings=7, loc=(0, 0, z), name="Pommel")


def sample(pts, t):
    """Point and unit tangent at fraction t of a polyline."""
    n = len(pts) - 1
    f = min(max(t, 0.0), 0.9999) * n
    i = int(f)
    a, b = Vector(pts[i]), Vector(pts[i + 1])
    p = a.lerp(b, f - i)
    return p, (b - a).normalized()


def place(ob, p, tangent, roll=0.0):
    """Orient an object so its local Z follows the tangent, then roll it about that axis."""
    q = tangent.to_track_quat("Z", "Y")
    m = q.to_matrix().to_4x4()
    from mathutils import Matrix
    ob.matrix_world = Matrix.Translation(p) @ m @ Matrix.Rotation(math.radians(roll), 4, "Z")
    return ob


def chain(material, pts, R=0.034, r=0.009, spacing=1.45, glow=None, every=0):
    """Chain links along the path, alternating 90 degrees. Links lie in a plane that contains the tangent."""
    total = sum((Vector(pts[i + 1]) - Vector(pts[i])).length for i in range(len(pts) - 1))
    count = int(total / (R * spacing))
    for k in range(count):
        p, tan = sample(pts, k / count)
        mat = glow if (glow is not None and every and k % every == every - 1) else material
        link = I.torus(R, r, mat, segs=6, rsegs=4, scale=(1.0, 1.35, 1.0), name="Link")
        # torus lies in XY around Z: rotate so the ring plane holds the tangent (ring axis perpendicular to it)
        side = tan.cross(Vector((0, 1, 0)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        axis = side if k % 2 == 0 else tan.cross(side).normalized()
        q = axis.to_track_quat("Z", "Y")
        # make the elongated local Y follow the tangent as closely as possible
        m = q.to_matrix()
        local_y = m.col[1]
        ang = math.atan2(local_y.cross(tan).dot(axis), local_y.dot(tan))
        from mathutils import Matrix
        link.matrix_world = Matrix.Translation(p) @ m.to_4x4() @ Matrix.Rotation(ang, 4, "Z")
    return count


# ================================================================================================ builders
def plains():  # Vine Whip: green vine lash with leaves, twine-wrapped wooden handle
    wood = pm("#8A5A33", rough=0.7)
    vine = pm("#4E8A2E", rough=0.6)
    leaf = pm("#6CBF3A", rough=0.55)
    handle(wood, wrap=pm("#C9A66B", rough=0.9))
    collar(pm("#6B4426", rough=0.75))
    pts = path()
    lash(vine, pts, r0=0.02, r1=0.005)
    for t, side in ((0.18, 1), (0.36, -1), (0.55, 1), (0.74, -1), (0.9, 1)):
        p, tan = sample(pts, t)
        I.extrude([(0, 0), (0.05, 0.03), (0.08, 0.09), (0.03, 0.08)] if side > 0 else [(0, 0), (-0.03, 0.08), (-0.08, 0.09), (-0.05, 0.03)],
                  0.006, leaf, loc=tuple(p), bevel=0.0, name="Leaf")
    pommel(pm("#6B4426", rough=0.75), r=0.03)


def desert():  # Scarab Whip: braided leather lash with gold rings, gold scarab pommel, turquoise
    leather = pm("#7A4A26", rough=0.7)
    dark = pm("#4A2E1A", rough=0.8)
    gold = pm("#E2B04A", metal=0.9, rough=0.3)
    turq = pm("#2EC4B6", rough=0.15)
    handle(dark, wrap=gold, n=4)
    collar(gold)
    pts = path(amp=0.13, phase=0.4)
    lash(leather, pts, r0=0.019, r1=0.004)
    pts2 = [(x + 0.006 * math.sin(i * 2.2), 0.006 * math.cos(i * 2.2), z) for i, (x, _, z) in enumerate(pts)]
    lash(dark, pts2, r0=0.012, r1=0.003, segs=6)
    for t in (0.2, 0.45, 0.7):
        p, tan = sample(pts, t)
        ring = I.torus(LASH_SCALE * (0.019 - 0.015 * t) + 0.004, 0.007, gold, segs=10, rsegs=4)
        place(ring, p, tan)
    p, tan = sample(pts, 0.9999)
    cap = I.cyl(0.012, 0.04, gold, r2=0.004, segs=8, bevel=0.0, name="TipCap")
    place(cap, Vector(pts[-1]) + tan * 0.015, tan)
    for j, col in enumerate(("#2EC4B6", "#E2B04A", "#2EC4B6")):
        I.tube([tuple(Vector(pts[-1])), tuple(Vector(pts[-1]) + tan * 0.02 + Vector((0.02 * (j - 1), 0, 0))),
                tuple(Vector(pts[-1]) + Vector((0.035 * (j - 1), 0, -0.06)))], [0.005, 0.004, 0.002], pm(col, rough=0.6), segs=4,
               name="Tassel")
    I.sphere(0.034, pm("#1FA59A", metal=0.3, rough=0.2), segs=10, rings=6, loc=(0, 0, HANDLE_BOT - 0.03), scale=(1, 0.8, 1.2), name="Scarab")
    I.torus(0.034, 0.006, gold, segs=12, rsegs=4, loc=(0, 0, HANDLE_BOT - 0.03), rot=(90, 0, 0), scale=(1, 1.2, 1))
    gem(0.012, turq, (0, -0.03, HANDLE_TOP - 0.03), segs=8)


def jungle():  # Liana Whip: two twisted lianas, red jungle flowers, wooden handle
    wood = pm("#6E4A2A", rough=0.75)
    liana = pm("#7A5A2E", rough=0.7)
    liana2 = pm("#3C8F3A", rough=0.6)
    petal = pm("#E74C3C", rough=0.5)
    handle(wood, wrap=liana2)
    collar(wood)
    pts = path(amp=0.12, phase=0.8)
    for k, mat in enumerate((liana, liana2)):
        twist = [(x + 0.016 * math.cos(i * 1.3 + k * math.pi), 0.016 * math.sin(i * 1.3 + k * math.pi), z) for i, (x, _, z) in enumerate(pts)]
        lash(mat, twist, r0=0.018, r1=0.005, segs=6)
    for t in (0.3, 0.62, 0.88):
        p, tan = sample(pts, t)
        for j in range(5):
            a = math.radians(72 * j)
            I.sphere(0.02, petal, segs=6, rings=4, loc=(p.x + 0.026 * math.cos(a), -0.03, p.z + 0.026 * math.sin(a)), scale=(1, 0.5, 1))
        I.sphere(0.013, pm("#F1C40F", rough=0.5), segs=6, rings=4, loc=(p.x, -0.038, p.z))
    pommel(wood, r=0.03)
    for i, col in enumerate(("#2ECC40", "#F1C40F")):
        I.extrude([(0, 0), (0.016, -0.04), (0.0, -0.12), (-0.016, -0.04)], 0.004, pm(col, rough=0.6),
                  loc=(0.02, 0, HANDLE_BOT - 0.03), rot=(0, -15 + 30 * i, 0), bevel=0.0, name="Feather")


def tundra():  # Frozen Chain: steel chain with frost links, ice crystal weight, fur-wrapped steel handle
    steel = pm("#C9D3DC", metal=0.8, rough=0.3)
    dark = pm("#4A5D73", metal=0.3, rough=0.55)
    ice = pm("#7CC8EE", rough=0.08)
    glow = pm("#2EB8FF", emit=2.2, emit_color="#1AA8FF")
    handle(dark, wrap=pm("#EDEAE4", rough=0.95), n=4)
    collar(steel)
    pts = path(n=24, length=1.18, amp=0.1, phase=0.3)
    chain(steel, pts, glow=ice, every=3)
    p, tan = sample(pts, 0.9999)
    tip = Vector(pts[-1]) + tan * 0.02
    crystal(tuple(tip), 0.055, 0.22, ice, tilt=(0, math.degrees(math.atan2(tan.x, tan.z)), 0))
    I.sphere(0.034, glow, segs=10, rings=6, loc=tuple(tip + tan * 0.08 + Vector((0, -0.035, 0))), name="FrostCore")
    I.torus(0.03, 0.02, pm("#EDEAE4", rough=0.95), segs=12, rsegs=5, loc=(0, 0, HANDLE_TOP - 0.02))
    crystal((0, 0, HANDLE_BOT - 0.01), 0.022, 0.07, ice, tilt=(180, 0, 0))


def swamp():  # Leech Whip: segmented leech-body lash, toxic glowing tip with teeth, bone handle
    bone = pm("#D9CBA0", rough=0.55)
    leech = pm("#4A5A2E", rough=0.5)
    belly = pm("#7A8A4A", rough=0.5)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    handle(pm("#4A3A2A", rough=0.85), wrap=bone, n=4)
    collar(bone)
    pts = path(n=20, amp=0.12, phase=0.2)
    lash(leech, pts, r0=0.012, r1=0.004, segs=6)
    count = 13
    for k in range(count):
        p, tan = sample(pts, (k + 0.5) / count)
        r = 0.036 - 0.018 * k / count
        seg = I.sphere(r, leech if k % 2 == 0 else belly, segs=8, rings=5, scale=(1, 0.85, 1.5), name="Segment")
        place(seg, p, tan)
    p, tan = sample(pts, 0.9999)
    tip = Vector(pts[-1])
    mouth = I.sphere(0.03, toxic, segs=10, rings=6, scale=(1, 1, 0.7), name="Mouth")
    place(mouth, tip, tan)
    for j in range(5):
        a = math.radians(72 * j)
        side = tan.cross(Vector((0, 1, 0))).normalized()
        up = tan.cross(side).normalized()
        base = tip + (side * math.cos(a) + up * math.sin(a)) * 0.024
        spike(tuple(base), tuple(base + tan * 0.045), 0.007, bone, segs=4)
    pommel(toxic, r=0.026)


def volcano():  # Lava Chain: obsidian chain with glowing lava links, spiked magma ball at the end
    obs = pm("#2A2224", metal=0.3, rough=0.45)
    rock = pm("#4A3834", rough=0.85)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    handle(obs, r=0.028, wrap=pm("#8A1F12", rough=0.6), n=4)
    collar(rock)
    pts = path(n=24, length=1.12, amp=0.1, phase=0.6)
    chain(obs, pts, R=0.036, r=0.0095, glow=lava, every=2)
    p, tan = sample(pts, 0.9999)
    center = Vector(pts[-1]) + tan * 0.07
    I.ico(0.06, rock, subdiv=1, loc=tuple(center), name="MagmaBall")
    I.ico(0.045, lava, subdiv=1, loc=tuple(center + Vector((0, -0.025, 0))), name="MagmaCore")
    for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0.7, 0, 0.7), (-0.7, 0, 0.7), (0.7, 0, -0.7), (-0.7, 0, -0.7)):
        v = Vector(d).normalized()
        spike(tuple(center + v * 0.05), tuple(center + v * 0.1), 0.016, rock, segs=5)
    pommel(lava, r=0.026)


def hell():  # Soul Chain: dark red chain with red soul links, hooked blade at the end, demon-horn handle
    black = pm("#1E1414", rough=0.6)
    metal = pm("#6A1A16", metal=0.7, rough=0.3)
    edge = pm("#B23A2E", metal=0.7, rough=0.25)
    soul = pm("#FF3030", emit=3.0, emit_color="#FF2020")
    handle(black, wrap=pm("#7A1A1A", rough=0.6), n=4)
    collar(metal)
    for s in (-1, 1):
        I.tube([(s * 0.02, 0, HANDLE_TOP - 0.02), (s * 0.06, 0, HANDLE_TOP + 0.03), (s * 0.07, 0, HANDLE_TOP + 0.08)],
               [0.012, 0.008, 0.002], pm("#E6D8C0", rough=0.5), segs=6, name="Horn")
    pts = path(n=24, length=1.12, amp=0.11, phase=0.9)
    chain(metal, pts, glow=soul, every=3)
    p, tan = sample(pts, 0.9999)
    tip = Vector(pts[-1])
    hook = [(0.0, 0.0), (0.03, 0.02), (0.07, 0.07), (0.08, 0.13), (0.06, 0.17), (0.07, 0.12), (0.05, 0.08), (0.02, 0.05), (-0.01, 0.03)]
    root = I.empty("HookRoot")
    place(root, tip, tan, roll=90)
    hook = [(x * 1.8, z * 1.8) for x, z in hook]
    I.extrude(hook, 0.016, edge, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.004, segments=1, smooth=False, parent=root, name="Hook")
    I.extrude([(-x, z) for x, z in reversed(hook)], 0.016, edge, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.004, segments=1,
              smooth=False, parent=root, name="Hook")
    gem(0.016, soul, tuple(tip + Vector((0, -0.012, 0))), segs=8)
    pommel(soul, r=0.026)


def heaven():  # Radiant Whip: glowing golden light lash, white-gold winged handle, star tip
    white = pm("#FFFFFF", rough=0.4)
    gold = pm("#E8B84A", metal=0.9, rough=0.25)
    light = pm("#FFE070", emit=2.8, emit_color="#FFD040")
    handle(white, wrap=gold, n=4)
    collar(gold)
    wing = [(0.0, 0.0), (0.04, 0.02), (0.08, 0.06), (0.1, 0.12), (0.07, 0.09), (0.065, 0.11), (0.04, 0.075), (0.02, 0.05)]
    for s in (-1, 1):
        pts_w = [(s * (0.03 + x), z) for x, z in wing]
        I.extrude(pts_w if s > 0 else list(reversed(pts_w)), 0.01, white, loc=(0, 0, HANDLE_TOP - 0.05), bevel=0.002, segments=1,
                  smooth=False, name="Wing")
    pts = path(amp=0.12, phase=0.5)
    lash(light, pts, r0=0.016, r1=0.006)
    for t in (0.25, 0.5, 0.75):
        p, tan = sample(pts, t)
        ring = I.torus(LASH_SCALE * (0.016 - 0.01 * t) + 0.004, 0.006, gold, segs=10, rsegs=4)
        place(ring, p, tan)
    p, tan = sample(pts, 0.9999)
    I.extrude(I.star_points(5, 0.075, 0.032), 0.014, light, loc=tuple(Vector(pts[-1]) + tan * 0.05), bevel=0.003, segments=1,
              smooth=False, name="Star")
    pommel(gold, r=0.028)
    I.torus(0.035, 0.005, light, segs=14, rsegs=4, loc=(0, 0, HANDLE_BOT - 0.07), rot=(90, 0, 0), name="Halo")


def dead():  # Spine Whip: vertebrae lash with bone spurs and soul glow, skull pommel
    bone = pm("#E6DCC0", rough=0.55)
    dark = pm("#3A3440", rough=0.75)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    handle(dark, wrap=bone, n=4)
    collar(bone)
    pts = path(n=20, amp=0.12, phase=0.3)
    lash(soul, pts, r0=0.012, r1=0.004, segs=6)
    count = 12
    for k in range(count):
        p, tan = sample(pts, (k + 0.5) / count)
        s = 1.0 - 0.55 * k / count
        v = I.cyl(0.034 * s, 0.07 * s, bone, r2=0.028 * s, segs=8, bevel=0.0, name="Vertebra")
        place(v, p, tan)
        side = tan.cross(Vector((0, 1, 0))).normalized()
        spike(tuple(p + side * 0.028 * s), tuple(p + side * 0.07 * s - tan * 0.02), 0.011 * s, bone, segs=4)
        spike(tuple(p - side * 0.028 * s), tuple(p - side * 0.07 * s - tan * 0.02), 0.011 * s, bone, segs=4)
    I.sphere(0.04, bone, segs=10, rings=7, loc=(0, 0, HANDLE_BOT - 0.04), scale=(1, 0.95, 1.05), name="Skull")
    for x in (-0.014, 0.014):
        I.sphere(0.009, soul, segs=6, rings=4, loc=(x, -0.035, HANDLE_BOT - 0.035))


def abyss():  # Tentacle Whip: purple tentacle lash with suckers and glowing tips, coral handle, pearl
    coral = pm("#E86A8A", rough=0.45)
    flesh = pm("#8E3A8A", rough=0.45)
    sucker = pm("#F2B8D8", rough=0.4)
    glow = pm("#5FFFF0", emit=2.5, emit_color="#40F0E0")
    handle(pm("#1F3F6A", metal=0.5, rough=0.4), wrap=coral, n=4)
    collar(pm("#3FB5C8", metal=0.65, rough=0.22))
    pts = path(amp=0.13, phase=0.7)
    lash(flesh, pts, r0=0.024, r1=0.005)
    for k in range(11):
        t = 0.06 + k * 0.085
        p, tan = sample(pts, t)
        lr = LASH_SCALE * (0.024 + (0.005 - 0.024) * t)
        r = 0.013 * (1 - t * 0.6)
        I.sphere(r, sucker, segs=8, rings=5, loc=(p.x, -lr - r * 0.2, p.z), scale=(1, 0.45, 1), name="Sucker")
    for t in (0.35, 0.7):
        p, tan = sample(pts, t)
        I.sphere(0.007, glow, segs=6, rings=4, loc=(p.x + 0.02 * (1 - t), 0, p.z))
    p, tan = sample(pts, 0.9999)
    I.sphere(0.012, glow, segs=8, rings=5, loc=tuple(Vector(pts[-1])), name="GlowTip")
    for s in (-1, 1):
        I.tube([(s * 0.02, 0, HANDLE_TOP - 0.06), (s * 0.05, 0, HANDLE_TOP - 0.02), (s * 0.06, 0, HANDLE_TOP + 0.03)],
               [0.009, 0.006, 0.002], coral, segs=6, name="Coral")
    I.sphere(0.03, pm("#F4F1EA", rough=0.12), segs=10, rings=6, loc=(0, 0, HANDLE_BOT - 0.03), name="Pearl")


def mechanical():  # Electro Whip: segmented metal cable with glowing rings, electric tip, tech handle with battery
    metal = pm("#9AA4B2", metal=0.85, rough=0.3)
    dark = pm("#3A3F48", metal=0.8, rough=0.35)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    handle(dark)
    I.box(0.045, 0.045, 0.1, pm("#FFC21F", rough=0.4), loc=(0, -0.012, -0.02), bevel=0.005, segments=1, name="Battery")
    I.box(0.03, 0.01, 0.06, plasma, loc=(0, -0.036, -0.02), bevel=0.0, name="Charge")
    collar(metal, r=0.034)
    pts = path(n=20, amp=0.11, phase=0.5)
    lash(dark, pts, r0=0.013, r1=0.005, segs=6)
    count = 12
    for k in range(count):
        p, tan = sample(pts, (k + 0.5) / count)
        s = 1.0 - 0.5 * k / count
        seg = I.cyl(0.031 * s, 0.055 * s, metal, segs=8, bevel=0.0, name="Segment")
        place(seg, p, tan)
        if k % 2 == 1:
            ring = I.torus(0.032 * s, 0.007, plasma, segs=10, rsegs=4)
            place(ring, p + tan * 0.032 * s, tan)
    p, tan = sample(pts, 0.9999)
    tip = Vector(pts[-1])
    I.sphere(0.03, plasma, segs=10, rings=6, loc=tuple(tip), name="Tip")
    for a in (0, 120, 240):
        r = math.radians(a)
        side = tan.cross(Vector((0, 1, 0))).normalized()
        up = tan.cross(side).normalized()
        d = side * math.cos(r) + up * math.sin(r)
        I.tube([tuple(tip), tuple(tip + d * 0.03 + tan * 0.02), tuple(tip + d * 0.02 + tan * 0.05)], [0.004, 0.003, 0.001], plasma,
               segs=4, name="Spark")
    I.box(0.04, 0.04, 0.04, metal, loc=(0, 0, HANDLE_BOT - 0.02), bevel=0.005, segments=1, name="Pommel")


def void():  # Rift Chain: dark crystal chain with glowing rift links, crystal blade at the end, orbiting shards
    dark = pm("#3A2C55", metal=0.35, rough=0.15)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    handle(obs, wrap=glow, n=4)
    collar(dark)
    for s in (-1, 1):
        crystal((s * 0.03, 0, HANDLE_TOP - 0.01), 0.012, 0.07, dark, tilt=(0, s * 40, 0))
    pts = path(n=24, length=1.1, amp=0.11, phase=0.4)
    chain(dark, pts, glow=glow, every=2)
    p, tan = sample(pts, 0.9999)
    tip = Vector(pts[-1]) + tan * 0.02
    blade = I.cyl(0.062, 0.28, dark, r2=0.0, segs=4, scale=(1, 0.35, 1), bevel=0.0, smooth=False, name="RiftBlade")
    place(blade, tip + tan * 0.13, tan, roll=90)
    core = I.cyl(0.02, 0.2, glow, r2=0.0, segs=4, scale=(1, 1.6, 1), bevel=0.0, smooth=False, name="RiftCore")
    place(core, tip + tan * 0.11, tan, roll=90)
    orbit = I.torus(0.09, 0.007, glow, segs=18, rsegs=4, name="Orbit")
    place(orbit, tip, tan, roll=0)
    orbit.rotation_euler.x += math.radians(60)
    for k in range(3):
        a = math.radians(120 * k + 30)
        crystal((0.16 * math.cos(a), 0.0, 0.9 + 0.2 * k), 0.012, 0.05, glow, tilt=(0, 30 - 30 * k, 0))
    crystal((0, 0, HANDLE_BOT - 0.01), 0.024, 0.08, dark, tilt=(180, 0, 0))


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
