"""Shared helpers for the Fight Your Destiny landmark generators (Blender 5.x, headless).

Usage (one script per landmark):

    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from fyd_common import *

    def build():
        M = Model("Plains_1_Windmill", target=(40, 40, 72))
        M.box("Common_Stone", (4, 4, 2), loc=(0, 0, 0), base=True)
        return M

    if __name__ == "__main__":
        run(build)

Conventions
* 1 Blender unit = 1 Roblox stud, Z up, model front faces -Y, origin = bottom center.
* A "key" is a Kit.Palette entry, "<Set>_<Key>" (for example "Common_Wood"), optionally prefixed with
  "Neon_" for glowing parts and with "<Group>:" for an extra object group
  (for example "Blades:Common_Cloth" -> object "<FileName>_Blades__Common_Cloth").
* Every primitive is a closed solid, triangulated, with outward normals. One object per key.
"""
import bpy
import bmesh
import json
import math
import os
import random
import sys
from contextlib import contextmanager
from mathutils import Vector, Matrix, Euler

__all__ = [
    "Model", "run", "TRS", "V", "PALETTE", "math", "random", "Vector", "Matrix",
    "lerp", "polar", "smooth",
]

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
EXPORT_DIR = os.path.join(ROOT, "Blender_Exports")
PREVIEW_DIR = os.path.join(EXPORT_DIR, "previews")
BLEND_DIR = os.path.join(ROOT, "assets", "blender")
STATS_DIR = os.path.join(BLEND_DIR, "stats")

MAX_OBJECTS = 8
MAX_TRIS_PER_OBJECT = 9000

# ---------------------------------------------------------------------------------------------
# Palette: copied from tools/BuildKit.luau (Kit.Palette). The ONLY colors to use.
# ---------------------------------------------------------------------------------------------
PALETTE = {
    "Common": {
        "Wood": (168, 98, 56), "WoodDark": (112, 62, 38), "WoodLight": (214, 150, 92),
        "LogEnd": (236, 200, 96), "Stone": (150, 156, 168), "StoneDark": (104, 110, 124),
        "StoneBlue": (112, 128, 204), "Iron": (92, 98, 110), "Gold": (255, 201, 60),
        "Diamond": (95, 212, 255), "Cloth": (232, 226, 208), "White": (245, 246, 250),
        "Lantern": (255, 214, 120), "Fire": (255, 140, 40), "Rope": (196, 160, 104),
    },
    "Hub": {
        "Grass": (98, 208, 64), "Path": (226, 200, 150), "Plaza": (206, 196, 178),
        "PlazaDark": (160, 150, 136), "Roof": (196, 64, 58), "RoofBlue": (64, 120, 212),
        "Wall": (240, 228, 200), "Timber": (112, 62, 38), "Water": (52, 214, 236),
        "Banner": (212, 52, 60), "BannerAlt": (74, 108, 220), "Portal": (150, 110, 255),
    },
    "Plains": {
        "Grass": (88, 204, 52), "GrassDark": (60, 168, 48), "GrassLight": (140, 224, 84),
        "Dirt": (176, 124, 78), "Path": (218, 184, 128), "Sand": (244, 226, 160),
        "SandWet": (222, 198, 132), "Water": (40, 216, 236), "WaterDeep": (30, 160, 214),
        "Leaf": (72, 176, 62), "LeafDark": (40, 124, 58), "Pine": (36, 104, 62),
        "PineLight": (64, 140, 78), "Trunk": (128, 78, 48), "Palm": (88, 190, 80),
        "Mountain": (150, 92, 66), "MountainDark": (116, 70, 54), "Snow": (244, 246, 250),
        "Rock": (150, 156, 168), "RockBlue": (112, 128, 204), "Flower1": (255, 92, 120),
        "Flower2": (255, 214, 70), "Flower3": (160, 110, 255), "Mushroom": (232, 72, 72),
        "CaveRock": (96, 92, 110), "CaveRockDark": (62, 60, 78), "Ore": (90, 230, 255),
        "OreGold": (255, 196, 60), "Moss": (104, 168, 72), "Web": (232, 236, 240),
    },
    "Desert": {
        "Sand": (244, 208, 124), "SandLight": (252, 226, 160), "SandDark": (214, 168, 96),
        "Dune": (236, 186, 104), "Terracotta": (204, 96, 62), "CanyonRed": (196, 84, 56),
        "CanyonDark": (150, 62, 48), "CanyonLight": (228, 128, 80), "Sandstone": (226, 190, 132),
        "SandstoneDark": (184, 146, 98), "Clay": (222, 164, 110), "Water": (48, 214, 208),
        "Cactus": (76, 164, 84), "Palm": (96, 186, 76), "Trunk": (150, 104, 64),
        "DeadWood": (158, 132, 104), "Bone": (240, 232, 208), "Tent": (214, 74, 62),
        "TentAlt": (60, 150, 170), "Gold": (255, 201, 60), "Lapis": (44, 92, 200),
        "PyramidWall": (204, 160, 100), "PyramidDark": (140, 104, 68), "Turquoise": (64, 208, 196),
    },
    "Jungle": {
        "Grass": (52, 156, 60), "GrassDark": (32, 112, 54), "GrassLight": (96, 196, 72),
        "Leaf": (40, 150, 66), "LeafDark": (22, 100, 56), "LeafLight": (120, 210, 70),
        "Trunk": (104, 68, 44), "TrunkDark": (74, 48, 34), "Vine": (70, 170, 60),
        "Dirt": (128, 88, 56), "Mud": (98, 70, 48), "Water": (48, 196, 190),
        "WaterDeep": (30, 140, 150), "Stone": (132, 138, 124), "StoneDark": (92, 100, 92),
        "Moss": (88, 150, 66), "Gold": (255, 201, 60), "Glyph": (120, 255, 190),
        "Flower1": (255, 80, 140), "Flower2": (255, 170, 40), "Flower3": (190, 90, 255),
        "Bamboo": (150, 200, 80), "Totem": (196, 70, 50), "TotemAlt": (60, 170, 190),
    },
}


def _srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def parse_key(key):
    """'Blades:Neon_Plains_Ore' -> (group 'Blades', suffix 'Neon_Plains_Ore', neon True, rgb)."""
    group = ""
    if ":" in key:
        group, key = key.split(":", 1)
    suffix = key
    neon = False
    if key.startswith("Neon_"):
        neon = True
        key = key[5:]
    pset, pname = key.split("_", 1)
    if pset not in PALETTE or pname not in PALETTE[pset]:
        raise KeyError("Color '%s' is not in Kit.Palette" % key)
    return group, suffix, neon, PALETTE[pset][pname]


# ---------------------------------------------------------------------------------------------
# Small math helpers
# ---------------------------------------------------------------------------------------------
def V(*a):
    if len(a) == 1:
        return Vector(a[0])
    return Vector(a)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def polar(r, deg, z=0.0):
    a = math.radians(deg)
    return Vector((r * math.cos(a), r * math.sin(a), z))


def TRS(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    """Matrix from location, XYZ euler rotation in degrees, uniform or per-axis scale."""
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    return (Matrix.Translation(Vector(loc))
            @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
            @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))


def _frame(d, up=None):
    d = d.normalized()
    up = Vector(up) if up is not None else Vector((0, 0, 1))
    if abs(d.dot(up)) > 0.97:
        up = Vector((1, 0, 0))
    u = d.cross(up).normalized()
    v = u.cross(d).normalized()
    return u, v


# ---------------------------------------------------------------------------------------------
# Model: collects closed primitives per color key
# ---------------------------------------------------------------------------------------------
class Model:
    def __init__(self, name, target=None, seed=1, center_xy=True):
        self.name = name
        self.target = target          # (X, Y, Z) Blender studs, for the report only
        self.data = {}                # key -> ([Vector], [(i, j, k)])
        self.order = []
        self.stack = [Matrix.Identity(4)]
        self.rng = random.Random(seed)
        self.clip_z = None            # when set, primitives are cut at this world Z (and capped)
        self.center_xy = center_xy
        self.ref_pos = None           # optional (x, y) of the preview reference figure
        self.view_dir = None          # optional camera direction override
        self.notes = ""
        self.anchors = {}             # name -> (x, y, z) build-space points reported in the stats file

    # -- transform stack -------------------------------------------------------------------
    @contextmanager
    def xf(self, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, m=None):
        mat = m if m is not None else TRS(loc, rot, scale)
        self.stack.append(self.stack[-1] @ mat)
        try:
            yield
        finally:
            self.stack.pop()

    def _local(self, kw):
        m = kw.pop("m", None)
        loc = kw.pop("loc", (0, 0, 0))
        rot = kw.pop("rot", (0, 0, 0))
        scale = kw.pop("scale", 1.0)
        if kw:
            raise TypeError("unexpected arguments: %s" % list(kw))
        return m if m is not None else TRS(loc, rot, scale)

    # -- commit ----------------------------------------------------------------------------
    def _commit_bm(self, key, tb, m):
        parse_key(key)
        mat = self.stack[-1] @ m
        bmesh.ops.transform(tb, matrix=mat, verts=tb.verts[:])
        if self.clip_z is not None and tb.faces:
            zs = [v.co.z for v in tb.verts]
            if max(zs) <= self.clip_z + 1e-4:
                tb.free()
                return
            if min(zs) < self.clip_z - 1e-4:
                geom = tb.verts[:] + tb.edges[:] + tb.faces[:]
                res = bmesh.ops.bisect_plane(tb, geom=geom, dist=1e-5, plane_co=(0, 0, self.clip_z),
                                             plane_no=(0, 0, 1), clear_inner=True)
                cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
                if cut:
                    bmesh.ops.triangle_fill(tb, edges=cut, use_beauty=True)
        if not tb.faces:
            tb.free()
            return
        bmesh.ops.triangulate(tb, faces=tb.faces[:])
        bmesh.ops.dissolve_degenerate(tb, dist=1e-5, edges=tb.edges[:])
        bmesh.ops.recalc_face_normals(tb, faces=tb.faces[:])
        loose = [v for v in tb.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(tb, geom=loose, context="VERTS")
        tb.verts.index_update()
        if key not in self.data:
            self.data[key] = ([], [])
            self.order.append(key)
        verts, faces = self.data[key]
        off = len(verts)
        verts.extend(v.co.copy() for v in tb.verts)
        faces.extend(tuple(v.index + off for v in f.verts) for f in tb.faces)
        tb.free()

    def _commit(self, key, verts, faces, m):
        tb = bmesh.new()
        vs = [tb.verts.new(Vector(v)) for v in verts]
        for f in faces:
            if len(set(f)) < 3:
                continue
            try:
                tb.faces.new([vs[i] for i in f])
            except ValueError:
                pass
        self._commit_bm(key, tb, m)

    # -- primitives ------------------------------------------------------------------------
    def mesh(self, key, verts, faces, **kw):
        self._commit(key, verts, faces, self._local(kw))

    def box(self, key, size, base=False, taper=1.0, top_off=(0, 0), **kw):
        """Box. loc = center (or bottom center when base=True). taper scales the top face."""
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2]
        tx, ty = (taper, taper) if isinstance(taper, (int, float)) else taper
        z0 = 0.0 if base else -sz / 2.0
        z1 = z0 + sz
        ox, oy = top_off
        verts = [(-sx, -sy, z0), (sx, -sy, z0), (sx, sy, z0), (-sx, sy, z0),
                 (-sx * tx + ox, -sy * ty + oy, z1), (sx * tx + ox, -sy * ty + oy, z1),
                 (sx * tx + ox, sy * ty + oy, z1), (-sx * tx + ox, sy * ty + oy, z1)]
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._commit(key, verts, faces, self._local(kw))

    def loft(self, key, rings, cap0=True, cap1=True, closed=False, **kw):
        """Skin a list of rings (lists of points, all the same length; a 1-point ring is an apex).
        closed=True joins the last ring back to the first (no caps)."""
        verts, faces, idx = [], [], []
        for ring in rings:
            idx.append(list(range(len(verts), len(verts) + len(ring))))
            verts.extend(ring)
        pairs = list(zip(idx[:-1], idx[1:]))
        if closed:
            pairs.append((idx[-1], idx[0]))
            cap0 = cap1 = False
        for a, b in pairs:
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                n = len(b)
                for i in range(n):
                    faces.append((a[0], b[(i + 1) % n], b[i]))
            elif len(b) == 1:
                n = len(a)
                for i in range(n):
                    faces.append((a[i], a[(i + 1) % n], b[0]))
            else:
                n = len(a)
                for i in range(n):
                    j = (i + 1) % n
                    faces.append((a[i], a[j], b[j], b[i]))
        if cap0 and len(idx[0]) > 2:
            faces.append(tuple(reversed(idx[0])))
        if cap1 and len(idx[-1]) > 2:
            faces.append(tuple(idx[-1]))
        self._commit(key, verts, faces, self._local(kw))

    def rings(self, key, secs, n=8, phase=None, jit=0.0, seed=None, **kw):
        """Vertical loft. secs: (z, r) | (z, rx, ry) | (z, rx, ry, cx, cy) | (z, rx, ry, cx, cy, twist_deg).
        A radius of 0 makes an apex. phase (deg) rotates the polygon; default puts a flat side to -Y."""
        rng = random.Random(seed) if seed is not None else self.rng
        if phase is None:
            phase = -90.0 + 180.0 / n
        ph = math.radians(phase)
        jits = [1.0 + rng.uniform(-jit, jit) for _ in range(n)] if jit else [1.0] * n
        rings = []
        for s in secs:
            z, rx = s[0], s[1]
            ry = s[2] if len(s) > 2 and s[2] is not None else rx
            cx = s[3] if len(s) > 3 else 0.0
            cy = s[4] if len(s) > 4 else 0.0
            tw = math.radians(s[5]) if len(s) > 5 else 0.0
            if rx <= 1e-6 and ry <= 1e-6:
                rings.append([(cx, cy, z)])
            else:
                rings.append([(cx + rx * jits[i] * math.cos(ph + tw + 2 * math.pi * i / n),
                               cy + ry * jits[i] * math.sin(ph + tw + 2 * math.pi * i / n), z)
                              for i in range(n)])
        self.loft(key, rings, **kw)

    def cyl(self, key, r, h, n=8, r2=None, **kw):
        """Prism / frustum standing on its base (loc = bottom center)."""
        self.rings(key, [(0, r), (h, r if r2 is None else r2)], n=n, **kw)

    def cone(self, key, r, h, n=8, **kw):
        self.rings(key, [(0, r), (h, 0)], n=n, **kw)

    def tube(self, key, pts, radii, n=6, jit=0.0, up=None, seed=None, squash=1.0, closed=False, **kw):
        """Loft a polygon along a 3D path. radii: one number or one per point (0 = pointed end).
        squash scales the ring along its 'v' (roughly vertical) axis."""
        rng = random.Random(seed) if seed is not None else self.rng
        pts = [Vector(p) for p in pts]
        if isinstance(radii, (int, float)):
            radii = [radii] * len(pts)
        k = len(pts)
        tans = []
        for i in range(k):
            if closed:
                a, b = pts[(i - 1) % k], pts[(i + 1) % k]
            else:
                a, b = pts[max(i - 1, 0)], pts[min(i + 1, k - 1)]
            tans.append((b - a).normalized())
        u, v = _frame(tans[0], up)
        rings = []
        for i in range(k):
            t = tans[i]
            u = (u - t * u.dot(t))
            if u.length < 1e-6:
                u, _ = _frame(t, up)
            u.normalize()
            v = t.cross(u).normalized()
            r = radii[i]
            if r <= 1e-6:
                rings.append([pts[i]])
            else:
                ring = []
                for j in range(n):
                    a = 2 * math.pi * (j + 0.5) / n
                    rr = r * (1.0 + (rng.uniform(-jit, jit) if jit else 0.0))
                    ring.append(pts[i] + (u * math.cos(a) + v * math.sin(a) * squash) * rr)
                rings.append(ring)
        self.loft(key, rings, closed=closed, **kw)

    def hull(self, key, pts, **kw):
        """Convex hull of a point cloud (faceted boulder shapes)."""
        tb = bmesh.new()
        for p in pts:
            tb.verts.new(Vector(p))
        res = bmesh.ops.convex_hull(tb, input=tb.verts[:], use_existing_faces=False)
        junk = [e for e in res.get("geom_interior", []) + res.get("geom_unused", [])
                if isinstance(e, bmesh.types.BMVert)]
        if junk:
            bmesh.ops.delete(tb, geom=list(set(junk)), context="VERTS")
        self._commit_bm(key, tb, self._local(kw))

    def rock(self, key, size, npts=12, jit=0.18, flat=0.6, seed=None, base=True, **kw):
        """Random convex boulder inside size (sx, sy, sz). flat = how much of the bottom is cut flat
        (0..1 of the half height kept below the center). base=True puts it on z = 0."""
        rng = random.Random(seed) if seed is not None else self.rng
        if isinstance(size, (int, float)):
            size = (size, size, size)
        pts = []
        for _ in range(npts):
            while True:
                d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
                if 0.2 < d.length <= 1.0:
                    break
            d = d.normalized() * (1.0 + rng.uniform(-jit, jit))
            z = max(d.z, -flat)
            pts.append((d.x * size[0] / 2, d.y * size[1] / 2, z * size[2] / 2))
        zmin = min(p[2] for p in pts)
        zmax = max(p[2] for p in pts)
        # normalise the height to size z
        sc = size[2] / max(zmax - zmin, 1e-6)
        pts = [(p[0], p[1], (p[2] - zmin) * sc - (0 if base else size[2] / 2)) for p in pts]
        self.hull(key, pts, **kw)

    def block(self, key, size, chamfer=0.18, jit=0.06, seed=None, base=False, taper=1.0, **kw):
        """Chunky stone block: a box with cut corners and a little jitter (convex)."""
        rng = random.Random(seed) if seed is not None else self.rng
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        c = chamfer * min(size)
        j = jit * min(size)
        pts = []
        for ix in (-1, 1):
            for iy in (-1, 1):
                for iz in (-1, 1):
                    t = taper if iz > 0 else 1.0
                    for ax in range(3):
                        p = [ix * sx * t, iy * sy * t, iz * sz]
                        p[ax] -= (ix, iy, iz)[ax] * c
                        p = [p[0] + rng.uniform(-j, j), p[1] + rng.uniform(-j, j), p[2] + rng.uniform(-j, j)]
                        p[2] = max(-sz, min(sz, p[2])) if base else p[2]
                        pts.append((p[0], p[1], p[2] + (sz if base else 0)))
        self.hull(key, pts, **kw)

    def chunk(self, key, a, b, ra, rb=None, n=6, jit=0.12, bulge=0.35, up=None, seed=None, **kw):
        """Boulder-like limb between two points: convex hull of two jittered rings + end bulges.
        ra / rb: radius or (r_side, r_up)."""
        rng = random.Random(seed) if seed is not None else self.rng
        a, b = Vector(a), Vector(b)
        rb = ra if rb is None else rb
        ra = (ra, ra) if isinstance(ra, (int, float)) else ra
        rb = (rb, rb) if isinstance(rb, (int, float)) else rb
        d = (b - a)
        u, v = _frame(d, up)
        dn = d.normalized()
        ph = rng.uniform(0, math.pi * 2)
        pts = []
        for p, r, sgn in ((a, ra, -1), (b, rb, 1)):
            for i in range(n):
                ang = ph + 2 * math.pi * i / n
                jr = 1.0 + rng.uniform(-jit, jit)
                pts.append(p + (u * math.cos(ang) * r[0] + v * math.sin(ang) * r[1]) * jr
                           + dn * rng.uniform(-jit, jit) * min(r))
            if bulge > 0:
                pts.append(p + dn * sgn * bulge * min(r) + (u * rng.uniform(-1, 1) + v * rng.uniform(-1, 1)) * jit * min(r))
        self.hull(key, pts, **kw)

    def blob(self, key, r, sub=2, jit=0.12, flat=None, seed=None, **kw):
        """Jittered icosphere (canopies, bushes, moss). r: radius or (rx, ry, rz).
        flat: clamp the bottom at -flat * rz (0..1). loc = center."""
        rng = random.Random(seed) if seed is not None else self.rng
        if isinstance(r, (int, float)):
            r = (r, r, r)
        tb = bmesh.new()
        bmesh.ops.create_icosphere(tb, subdivisions=sub, radius=1.0)
        for v in tb.verts:
            v.co *= 1.0 + rng.uniform(-jit, jit)
            if flat is not None and v.co.z < -flat:
                v.co.z = -flat
            v.co = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2]))
        self._commit_bm(key, tb, self._local(kw))

    def extrude(self, key, profile, depth, axis="Y", **kw):
        """Extrude a 2D polygon (may be concave).
        axis 'Y': profile is (x, z), solid spans y = -depth/2 .. depth/2.
        axis 'X': profile is (y, z), solid spans x = -depth/2 .. depth/2.
        axis 'Z': profile is (x, y), solid spans z = 0 .. depth."""
        n = len(profile)
        if axis == "Y":
            a = [(p[0], -depth / 2.0, p[1]) for p in profile]
            b = [(p[0], depth / 2.0, p[1]) for p in profile]
        elif axis == "X":
            a = [(-depth / 2.0, p[0], p[1]) for p in profile]
            b = [(depth / 2.0, p[0], p[1]) for p in profile]
        else:
            a = [(p[0], p[1], 0.0) for p in profile]
            b = [(p[0], p[1], depth) for p in profile]
        verts = a + b
        faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
        self._commit(key, verts, faces, self._local(kw))

    def slab(self, key, pts, thick, **kw):
        """Planar polygon (3D points) with thickness (cloth, planks, signs)."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        nor = Vector((0, 0, 0))
        for i in range(n):
            p, q = pts[i], pts[(i + 1) % n]
            nor += Vector(((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x), (p.x - q.x) * (p.y + q.y)))
        nor.normalize()
        a = [p - nor * thick / 2 for p in pts]
        b = [p + nor * thick / 2 for p in pts]
        verts = a + b
        faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
        self._commit(key, verts, faces, self._local(kw))

    def wedge(self, key, size, **kw):
        """Ramp: base on z = 0, rises toward +Y to full height. loc = bottom center."""
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2]
        verts = [(-sx, -sy, 0), (sx, -sy, 0), (sx, sy, 0), (-sx, sy, 0), (sx, sy, sz), (-sx, sy, sz)]
        faces = [(0, 3, 2, 1), (0, 1, 4, 5), (2, 3, 5, 4), (1, 2, 4), (0, 5, 3)]
        self._commit(key, verts, faces, self._local(kw))

    def ring_wall(self, key, r_in, r_out, z0, z1, n=12, skip=(), gap=0.0, jit=0.0, phase=0.0,
                  heights=None, seed=None, **kw):
        """Circle of n trapezoid blocks (wells, basins, kerbs). skip = indices left out,
        gap = angular gap in degrees between blocks, heights = optional per-block top z."""
        rng = random.Random(seed) if seed is not None else self.rng
        m = self._local(kw)
        for i in range(n):
            if i in skip:
                continue
            a0 = math.radians(phase + 360.0 * i / n + gap / 2)
            a1 = math.radians(phase + 360.0 * (i + 1) / n - gap / 2)
            top = heights[i] if heights else z1
            top += rng.uniform(-jit, jit) if jit else 0.0
            pts = []
            for z in (z0, top):
                for r in (r_in, r_out):
                    for a in (a0, a1):
                        pts.append((r * math.cos(a), r * math.sin(a), z))
            self.hull(key, pts, m=m)

    def arc(self, key, r_in, r_out, a0, a1, depth, n=8, axis="Y", **kw):
        """Arch band in the XZ plane (axis 'Y') from angle a0 to a1 (deg), extruded by depth."""
        prof = []
        for i in range(n + 1):
            a = math.radians(lerp(a0, a1, i / n))
            prof.append((r_out * math.cos(a), r_out * math.sin(a)))
        for i in range(n, -1, -1):
            a = math.radians(lerp(a0, a1, i / n))
            prof.append((r_in * math.cos(a), r_in * math.sin(a)))
        self.extrude(key, prof, depth, axis=axis, **kw)

    # -- output ----------------------------------------------------------------------------
    def bounds(self):
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for verts, _ in self.data.values():
            for v in verts:
                for i in range(3):
                    lo[i] = min(lo[i], v[i])
                    hi[i] = max(hi[i], v[i])
        return lo, hi


# ---------------------------------------------------------------------------------------------
# Scene / objects / export / preview
# ---------------------------------------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    return scene


def _material(suffix, neon, rgb):
    name = "FYD_" + suffix
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    lin = tuple(_srgb_to_linear(c) for c in rgb) + (1.0,)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = lin
    mat.roughness = 0.9
    mat.metallic = 0.0
    try:
        mat.use_nodes = True
    except Exception:
        pass
    if mat.node_tree:
        bsdf = next((nd for nd in mat.node_tree.nodes if nd.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = lin
            bsdf.inputs["Roughness"].default_value = 0.9
            if neon:
                for nm in ("Emission Color", "Emission"):
                    if nm in bsdf.inputs:
                        bsdf.inputs[nm].default_value = lin
                        break
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = 0.45
    return mat


def make_objects(model):
    """Create one mesh object per key. Returns (objects, stats)."""
    lo, hi = model.bounds()
    shift = Vector((-(lo.x + hi.x) / 2 if model.center_xy else 0.0,
                    -(lo.y + hi.y) / 2 if model.center_xy else 0.0, -lo.z))
    coll = bpy.data.collections.new(model.name)
    bpy.context.scene.collection.children.link(coll)
    objs, stats = [], []
    for key in model.order:
        verts, faces = model.data[key]
        group, suffix, neon, rgb = parse_key(key)
        oname = "%s%s__%s" % (model.name, ("_" + group) if group else "", suffix)
        me = bpy.data.meshes.new(oname)
        me.from_pydata([tuple(v + shift) for v in verts], [], faces)
        me.validate(verbose=False)
        me.update()
        # final cleanup pass
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges[:])
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        ngons = [f for f in bm.faces if len(f.verts) > 3]
        if ngons:
            bmesh.ops.triangulate(bm, faces=ngons)
        seen, dups = set(), []
        for f in bm.faces:
            k = tuple(sorted((round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) for v in f.verts))
            if k in seen:
                dups.append(f)
            else:
                seen.add(k)
        ndup = len(dups)
        if dups:
            bmesh.ops.delete(bm, geom=dups, context="FACES")
        for f in bm.faces:
            f.smooth = False
        bm.to_mesh(me)
        ntri = len(bm.faces)
        nloose = len([v for v in bm.verts if not v.link_faces])
        nngon = len([f for f in bm.faces if len(f.verts) != 3])
        bm.free()
        if hasattr(me, "shade_flat"):
            me.shade_flat()
        me.materials.append(_material(suffix, neon, rgb))
        ob = bpy.data.objects.new(oname, me)
        coll.objects.link(ob)
        objs.append(ob)
        stats.append({"object": oname, "color": suffix, "rgb": list(rgb), "triangles": ntri,
                      "verts": len(me.vertices), "loose": nloose, "ngons": nngon, "dups_removed": ndup})
    model.shift = shift
    return objs, stats


def export_fbx(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
        mesh_smooth_type="FACE", bake_space_transform=True, add_leaf_bones=False,
        use_mesh_modifiers=True, object_types={"MESH"}, bake_anim=False,
    )


def _ref_figure(pos, coll):
    """5.5-stud tall gray reference figure (render only)."""
    mat = bpy.data.materials.new("REF_Gray")
    mat.diffuse_color = (0.2, 0.2, 0.22, 1.0)
    mat.use_nodes = True
    bsdf = next((nd for nd in mat.node_tree.nodes if nd.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.2, 0.2, 0.22, 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
    parts = [((2.0, 1.0, 4.3), 2.15), ((1.3, 1.3, 1.2), 4.9)]
    obs = []
    for (sx, sy, sz), cz in parts:
        me = bpy.data.meshes.new("REF_Figure")
        v = [(x * sx / 2, y * sy / 2, z * sz / 2) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        me.from_pydata(v, [], f)
        me.materials.append(mat)
        ob = bpy.data.objects.new("REF_Figure_5p5", me)
        ob.location = (pos[0], pos[1], cz)
        coll.objects.link(ob)
        obs.append(ob)
    return obs, coll


def _fit_camera(cam, pts, direction, res, margin=0.9):
    scene = bpy.context.scene
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    d = Vector(direction).normalized()
    rot = (-d).to_track_quat("-Z", "Y")
    cam.rotation_euler = rot.to_euler()
    right = rot @ Vector((1, 0, 0))
    upv = rot @ Vector((0, 1, 0))
    aspect = res[0] / res[1]
    th = math.tan(cam.data.angle / 2) * margin
    tv = math.tan(cam.data.angle / 2) / aspect * margin
    dist = 100.0
    for _ in range(6):
        dist = max(max((p - center).dot(d) + abs((p - center).dot(right)) / th,
                       (p - center).dot(d) + abs((p - center).dot(upv)) / tv) for p in pts)
        sx = [(p - center).dot(right) / (dist - (p - center).dot(d)) for p in pts]
        sy = [(p - center).dot(upv) / (dist - (p - center).dot(d)) for p in pts]
        center = center + right * (max(sx) + min(sx)) / 2 * dist * 0.9 + upv * (max(sy) + min(sy)) / 2 * dist * 0.9
    cam.location = center + d * dist
    cam.data.clip_start = 0.5
    cam.data.clip_end = dist * 4 + 4000
    scene.camera = cam


def _preview_stage(lo, hi):
    """Render-only ground + sun (collection PreviewOnly)."""
    coll = bpy.data.collections.get("PreviewOnly")
    if coll is None:
        coll = bpy.data.collections.new("PreviewOnly")
        bpy.context.scene.collection.children.link(coll)
    if bpy.data.objects.get("PreviewGround") is None:
        mat = bpy.data.materials.new("REF_Ground")
        lin = tuple(_srgb_to_linear(c) for c in BG_RGB) + (1.0,)
        mat.diffuse_color = lin
        mat.use_nodes = True
        nt = mat.node_tree
        for nd in list(nt.nodes):
            nt.nodes.remove(nd)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
        dif.inputs["Color"].default_value = tuple(_srgb_to_linear(c) for c in GROUND_RGB) + (1.0,)
        nt.links.new(dif.outputs[0], out.inputs[0])
        me = bpy.data.meshes.new("PreviewGround")
        s = 1500.0
        me.from_pydata([(-s, -s, -0.02), (s, -s, -0.02), (s, s, -0.02), (-s, s, -0.02)], [], [(0, 1, 2, 3)])
        me.materials.append(mat)
        coll.objects.link(bpy.data.objects.new("PreviewGround", me))
        sun = bpy.data.lights.new("PreviewSun", "SUN")
        sun.energy = 2.5
        sun.angle = math.radians(2.0)
        so = bpy.data.objects.new("PreviewSun", sun)
        so.rotation_euler = Euler((math.radians(40), 0, math.radians(32)), "XYZ")
        coll.objects.link(so)
    return coll


BG_RGB = (176, 216, 244)
GROUND_RGB = (168, 208, 238)


def render_preview(objs, path, ref_pos=None, view_dir=None, res=(800, 600), with_ref=True):
    scene = bpy.context.scene
    pts = []
    for ob in objs:
        pts.extend(ob.matrix_world @ Vector(c) for c in ob.bound_box)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    coll = _preview_stage(lo, hi)
    if with_ref and bpy.data.objects.get("REF_Figure_5p5") is None:
        if ref_pos is None:
            ref_pos = (hi.x + 4.0, lo.y + 1.0)
        _ref_figure(ref_pos, coll)
    for ob in coll.objects:
        if ob.name.startswith("REF_Figure"):
            for c in ob.bound_box:
                pts.append(Vector(c) + ob.location)
    cam = bpy.data.objects.get("PreviewCamera")
    if cam is None:
        cam_data = bpy.data.cameras.new("PreviewCamera")
        cam_data.lens = 60
        cam = bpy.data.objects.new("PreviewCamera", cam_data)
        coll.objects.link(cam)
    _fit_camera(cam, pts, view_dir or (0.95, -1.3, 0.62), res)

    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    lin_bg = tuple(_srgb_to_linear(c) for c in BG_RGB)
    world.color = lin_bg
    world.use_nodes = True
    nt = world.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    mix = nt.nodes.new("ShaderNodeMixShader")
    lp = nt.nodes.new("ShaderNodeLightPath")
    amb = nt.nodes.new("ShaderNodeBackground")
    amb.inputs[0].default_value = (0.9, 0.95, 1.0, 1.0)
    amb.inputs[1].default_value = 0.34
    cam_bg = nt.nodes.new("ShaderNodeBackground")
    cam_bg.inputs[0].default_value = lin_bg + (1.0,)
    cam_bg.inputs[1].default_value = 1.0
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(amb.outputs[0], mix.inputs[1])
    nt.links.new(cam_bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    engine = os.environ.get("FYD_ENGINE", "EEVEE")
    if engine == "EEVEE":
        try:
            scene.render.engine = "BLENDER_EEVEE"
        except TypeError:
            scene.render.engine = "BLENDER_EEVEE_NEXT"
        ee = scene.eevee
        for attr, val in (("taa_render_samples", 32), ("use_shadows", True), ("use_gtao", True),
                          ("use_raytracing", False)):
            if hasattr(ee, attr):
                try:
                    setattr(ee, attr, val)
                except Exception:
                    pass
    else:
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light = "STUDIO"
        sh.color_type = "MATERIAL"
        sh.show_shadows = True
        sh.shadow_intensity = 0.35
        sh.show_cavity = True
        sh.cavity_type = "BOTH"
        sh.show_specular_highlight = False
        scene.display.light_direction = (0.45, 0.35, 0.82)
        scene.display.render_aa = "8"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


def run(build, export=True, save=True):
    """Build -> objects -> stats -> FBX -> preview -> .blend. Extra QA views when FYD_EXTRA_DIR is set."""
    reset_scene()
    model = build()
    objs, stats = make_objects(model)
    lo = Vector((min((ob.matrix_world @ Vector(c)).x for ob in objs for c in ob.bound_box),
                 min((ob.matrix_world @ Vector(c)).y for ob in objs for c in ob.bound_box),
                 min((ob.matrix_world @ Vector(c)).z for ob in objs for c in ob.bound_box)))
    hi = Vector((max((ob.matrix_world @ Vector(c)).x for ob in objs for c in ob.bound_box),
                 max((ob.matrix_world @ Vector(c)).y for ob in objs for c in ob.bound_box),
                 max((ob.matrix_world @ Vector(c)).z for ob in objs for c in ob.bound_box)))
    size = hi - lo
    total = sum(s["triangles"] for s in stats)
    print("=" * 78)
    print("LANDMARK %s" % model.name)
    print("  size X x Y x Z = %.1f x %.1f x %.1f   (target %s)" % (size.x, size.y, size.z, model.target))
    print("  bounds lo=(%.1f, %.1f, %.1f) hi=(%.1f, %.1f, %.1f)" % (lo.x, lo.y, lo.z, hi.x, hi.y, hi.z))
    problems = []
    for s in stats:
        flag = ""
        if s["triangles"] > MAX_TRIS_PER_OBJECT:
            flag += " OVER-9000"
            problems.append("%s over 9000 triangles" % s["object"])
        if s["loose"] or s["ngons"]:
            flag += " DIRTY"
            problems.append("%s has loose verts / n-gons" % s["object"])
        print("  %-52s %6d tris  dups_removed=%d%s" % (s["object"], s["triangles"], s["dups_removed"], flag))
    print("  TOTAL %d triangles in %d objects" % (total, len(stats)))
    if len(stats) > MAX_OBJECTS:
        problems.append("more than %d objects" % MAX_OBJECTS)
    for p in problems:
        print("  PROBLEM: " + p)
    fbx = os.path.join(EXPORT_DIR, model.name + ".fbx")
    if export:
        export_fbx(objs, fbx)
    render_preview(objs, os.path.join(PREVIEW_DIR, model.name + ".png"),
                   ref_pos=model.ref_pos, view_dir=model.view_dir)
    extra = os.environ.get("FYD_EXTRA_DIR")
    if extra:
        for tag, d in (("back", (-0.9, 1.3, 0.55)), ("side", (-1.4, -0.35, 0.3)), ("top", (0.12, -0.5, 1.6)),
                       ("front", (0.0, -1.0, 0.12))):
            render_preview(objs, os.path.join(extra, "%s_%s.png" % (model.name, tag)), view_dir=d,
                           res=(640, 480))
    os.makedirs(STATS_DIR, exist_ok=True)
    with open(os.path.join(STATS_DIR, model.name + ".json"), "w") as fh:
        json.dump({"name": model.name, "target": model.target,
                   "size": [round(size.x, 1), round(size.y, 1), round(size.z, 1)],
                   "triangles": total, "objects": stats, "problems": problems,
                   "notes": model.notes,
                   "anchors": {k: [round(c, 2) for c in (Vector(v) + model.shift)]
                               for k, v in model.anchors.items()}}, fh, indent=1)
    if save:
        os.makedirs(BLEND_DIR, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, model.name + ".blend"), compress=True)
    print("=" * 78)
    return model
