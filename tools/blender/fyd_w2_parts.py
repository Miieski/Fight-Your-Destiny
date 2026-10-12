"""Weapon V2 parts (meters, origin = grip center, blade / head along +Z, front = -Y).
Richer than fyd_weapon_parts: blades with a real cross-section (hexagonal: flat + edge bevels, or diamond: a center
ridge), spiral-wrapped grips, faceted pommels, rivets. Same proportions as the V1 parts so the models keep the look
of their icons."""
import math

import bmesh
from mathutils import Vector

import fyd_icons as I


# ------------------------------------------------------------------------------------------------
# blades
# ------------------------------------------------------------------------------------------------
def blade_edges(L, w, taper=0.85, tip_start=0.82, curve=0.0, widen=0.0, n=14, serr_right=0, serr_left=0,
                serr_depth=0.25, wave=0.0, tip_shift=None):
    """Right / left edge points (x, z) from z = 0 (guard) to the start of the tip, plus the tip (x, z).
    Same parameters as fyd_weapon_parts.blade_outline (without the back spikes)."""
    right, left = [], []
    for i in range(n + 1):
        t = tip_start * i / n
        u = t / tip_start
        half = w / 2 * (1 - (1 - taper) * u) * (1 + widen * u)
        half *= 1 + wave * math.sin(u * math.pi * 5)
        c = curve * (t ** 2) * L
        right.append([c + half, t * L])
        left.append([c - half, t * L])
    for edge, count in ((right, serr_right), (left, serr_left)):
        if count:
            for i in range(1, len(edge) - 1):
                u = i / n
                if 0.12 < u < 0.78 and i % 2 == 0:
                    mid = (right[i][0] + left[i][0]) / 2
                    edge[i][0] = edge[i][0] + (mid - edge[i][0]) * serr_depth
    tip = (curve * L if tip_shift is None else tip_shift, L)
    return right, left, tip


def blade_mesh(right, left, tip, thickness, material, z0=0.125, profile="hex", bevel=0.38, edge=0.12, x=0.0,
               name="Blade"):
    """A blade with a real cross-section between two edge point lists (same length, same z per index).
    profile "hex": flat faces with a bevel of `bevel` x half-width along both edges; "diamond": one center ridge.
    `edge` = thickness kept at the cutting edge (fraction of the full thickness)."""
    bm = bmesh.new()
    t = thickness / 2
    e = thickness * edge / 2
    rows = []
    for (xr, zr), (xl, zl) in zip(right, left):
        z = (zr + zl) / 2 + z0
        xc = (xr + xl) / 2
        if profile == "diamond":
            section = [(xr, -e), (xc, -t), (xl, -e), (xl, e), (xc, t), (xr, e)]
        else:
            half = (xr - xl) / 2
            bw = max(half * bevel, 1e-4)
            section = [(xr, -e), (xr - bw, -t), (xl + bw, -t), (xl, -e), (xl, e), (xl + bw, t), (xr - bw, t), (xr, e)]
        rows.append([bm.verts.new((x + sx, sy, z)) for sx, sy in section])
    k = len(rows[0])
    for a, b in zip(rows, rows[1:]):
        for j in range(k):
            bm.faces.new((a[j], a[(j + 1) % k], b[(j + 1) % k], b[j]))
    bm.faces.new(list(reversed(rows[0])))
    apex = bm.verts.new((x + tip[0], 0.0, tip[1] + z0))
    last = rows[-1]
    for j in range(k):
        bm.faces.new((last[j], last[(j + 1) % k], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return I._finish(bm, name, material, smooth=False, bevel=0.0)


def plate(points, thickness, material, bevel=0.01, edge=0.14, loc=(0, 0, 0), rot=(0, 0, 0), name="Plate"):
    """Any flat outline (x, z) made solid with a ground edge: flat faces inset by `bevel` meters, chamfered down to
    a thin edge (`edge` x thickness) all around. Works for concave outlines (serrations, axe beards, wings)."""
    bm = bmesh.new()
    t = thickness / 2
    e = max(thickness * edge / 2, 1e-4)
    ring = [bm.verts.new((x, -t, z)) for x, z in points]
    face = bm.faces.new(ring)
    bmesh.ops.inset_region(bm, faces=[face], thickness=bevel, depth=0.0, use_even_offset=False, use_boundary=True)
    # the original face is the inner one after the inset; the outer ring stays on the outline points
    inner = set(face.verts)
    outer = [v for v in bm.verts if v not in inner]

    def nearest(x, z):
        return min(outer, key=lambda v: (v.co.x - x) ** 2 + (v.co.z - z) ** 2)

    front_outer = [nearest(x, z) for x, z in points]
    for v in front_outer:
        v.co.y = -e
    for v in inner:
        v.co.y = -t
    # back = mirror of the front
    front_faces = list(bm.faces)
    dup = bmesh.ops.duplicate(bm, geom=front_faces + list({v for f in front_faces for v in f.verts}))
    vmap = dup["vert_map"]
    for v in [g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)]:
        v.co.y = -v.co.y
    back_outer = [vmap[v] for v in front_outer]
    n = len(front_outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front_outer[i], front_outer[j], back_outer[j], back_outer[i]))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return I._finish(bm, name, material, smooth=False, bevel=0.0, loc=loc, rot=rot)


def blade_outline(L, w, **outline):
    """The closed outline of blade_edges: up the right edge, the tip, down the left edge."""
    right, left, tip = blade_edges(L, w, **outline)
    return [tuple(p) for p in right] + [tip] + [tuple(p) for p in reversed(left)]


def blade(L, w, thickness, material, z0=0.125, profile="hex", bevel=0.36, x=0.0, **outline):
    """profile "hex": flat faces + ground edges (plate); "diamond": a center ridge (blade_mesh)."""
    if profile == "diamond":
        right, left, tip = blade_edges(L, w, **outline)
        return blade_mesh(right, left, tip, thickness, material, z0=z0, profile="diamond", x=x)
    pts = [(px + x, pz + z0) for px, pz in blade_outline(L, w, **outline)]
    return plate(pts, thickness, material, bevel=w / 2 * bevel, name="Blade")


def polygon_blade(points, thickness, material, z0=0.125, bevel=0.012, x=0.0, name="Blade"):
    """A blade from a free outline (V1 polygon blades), same ground-edge look as blade()."""
    return plate([(px + x, pz + z0) for px, pz in points], thickness, material, bevel=bevel, name=name)


def fuller(z_mid, length, width, material, x=0.0, depth=0.0035, rot_y=0.0, name="Fuller"):
    """A groove / inlay on both faces: a thin bevelled strip proud of the blade faces."""
    return I.box(width, depth, length, material, loc=(x, 0, z_mid), rot=(0, rot_y, 0), bevel=width * 0.3,
                 segments=1, smooth=False, name=name)


def inlay(x, z_mid, length, width, thickness, material, rot_y=0.0, name="Inlay"):
    """A strip through the blade, visible on both faces (glowing cores, cracks)."""
    return I.box(width, thickness, length, material, loc=(x, 0, z_mid), rot=(0, rot_y, 0), bevel=width * 0.25,
                 segments=1, smooth=False, name=name)


# ------------------------------------------------------------------------------------------------
# hilts
# ------------------------------------------------------------------------------------------------
def grip_wrapped(core, wrap, r=0.017, length=0.2, turns=5, wrap_r=None, segs=10, z=0.0, ferrule=None):
    """A grip core with a spiral wrap (leather / cord) and optional metal ferrules at both ends."""
    I.cyl(r, length, core, segs=segs, bevel=0.0, loc=(0, 0, z), name="Grip")
    wr = wrap_r or r * 0.3
    pts = []
    steps = max(12, turns * 10)
    for i in range(steps + 1):
        u = i / steps
        a = 2 * math.pi * turns * u
        pts.append((math.cos(a) * r * 1.02, math.sin(a) * r * 1.02, z - length / 2 + length * u))
    I.tube(pts, wr, wrap, segs=5, name="Wrap")
    if ferrule is not None:
        for dz in (-length / 2, length / 2):
            I.cyl(r * 1.22, length * 0.06, ferrule, segs=segs, loc=(0, 0, z + dz), bevel=r * 0.08, segments=1,
                  smooth=False, name="Ferrule")


def grip_rings(core, ring, r=0.017, length=0.2, rings=5, segs=10, z=0.0):
    """A grip with raised rings (V1 look: torus wraps), lower resolution than V1."""
    I.cyl(r, length, core, segs=segs, bevel=0.0, loc=(0, 0, z), name="Grip")
    for k in range(rings):
        I.torus(r * 1.04, r * 0.3, ring, segs=segs, rsegs=5, loc=(0, 0, z - length / 2 + (k + 0.5) * length / rings),
                name="Ring")


def guard(width, material, z=0.11, depth=0.036, height=0.028, bevel=0.006, ends=None, end_r=None):
    """Cross guard bar with chamfered edges; ends = material of the round end caps (optional)."""
    I.box(width, depth, height, material, loc=(0, 0, z), bevel=bevel, segments=2, angle=30, smooth=False, name="Guard")
    if ends is not None:
        r = end_r or height * 0.55
        for side in (-1, 1):
            I.sphere(r, ends, segs=10, rings=6, loc=(side * width / 2, 0, z), smooth=False, name="GuardEnd")


def pommel(r, material, z=-0.125, style="ball", ring=None):
    """ball: faceted sphere; disc: wheel pommel; drop: tear drop; cone: tapered cap."""
    if style == "disc":
        I.cyl(r, r * 0.7, material, segs=12, loc=(0, 0, z), rot=(90, 0, 0), bevel=r * 0.12, segments=1, smooth=False,
              name="Pommel")
    elif style == "drop":
        I.lathe([(0.0, z - r * 1.2), (r * 0.6, z - r * 0.9), (r, z - r * 0.2), (r * 0.7, z + r * 0.5), (0.0, z + r * 0.8)],
                material, segs=10, smooth=False, name="Pommel")
    elif style == "cone":
        I.cyl(r, r * 2.2, material, r2=r * 0.25, segs=10, loc=(0, 0, z), rot=(180, 0, 0), bevel=0.0, smooth=False,
              name="Pommel")
    else:
        I.sphere(r, material, segs=10, rings=7, loc=(0, 0, z), smooth=False, name="Pommel")
    if ring is not None:
        I.torus(r * 0.78, r * 0.16, ring, segs=12, rsegs=4, loc=(0, 0, z + r * 0.75), name="PommelRing")


def rivet(loc, r, material):
    return I.sphere(r, material, segs=6, rings=4, loc=loc, smooth=False, name="Rivet")


def gem(r, material, loc, facets=8, scale=(1, 1, 1)):
    """A cut gem (low-poly faceted)."""
    return I.sphere(r, material, segs=facets, rings=5, loc=loc, smooth=False, scale=scale, name="Gem")


def socketed_gem(r, gem_material, rim_material, loc, rot=(90, 0, 0)):
    """A gem in a metal rim (rim faces -Y by default)."""
    I.torus(r * 1.15, r * 0.22, rim_material, segs=12, rsegs=4, loc=loc, rot=rot, name="GemRim")
    return gem(r, gem_material, loc)


def spike(base, tip, r, material, segs=8):
    b, t = Vector(base), Vector(tip)
    d = t - b
    ob = I.cyl(r, d.length, material, r2=0.0, segs=segs, bevel=0.0, smooth=False, loc=tuple((b + t) / 2), name="Spike")
    ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return ob


def crystal(loc, r, h, material, tilt=(0, 0, 0), sides=6):
    root = I.empty("Crystal", loc=loc, rot=tilt)
    I.cyl(r, h * 0.7, material, segs=sides, loc=(0, 0, h * 0.35), bevel=0.0, smooth=False, parent=root, name="CrystalBody")
    I.cyl(r, h * 0.3, material, r2=0.0, segs=sides, loc=(0, 0, h * 0.85), bevel=0.0, smooth=False, parent=root,
          name="CrystalTip")
    I.cyl(r, h * 0.12, material, r2=r * 0.4, segs=sides, loc=(0, 0, -h * 0.06), rot=(180, 0, 0), bevel=0.0,
          smooth=False, parent=root, name="CrystalBase")
    return root
