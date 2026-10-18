"""Fight Your Destiny - PROP pipeline (hub / world props of docs/model_upgrade_brief.txt), Blender 5.x.

Runs headless (tools/blender/fyd_props_run.py) or inside the Blender MCP session (it then works in its own scene
"FYD_Props" and never touches the other scenes). Conventions: Blender/Props/README.txt (the Prop Style Guide).

    import fyd_props as P
    p = P.Prop("well", photo="16_well.png", size=(11.4, 13.2, 9.6), budget=3500, view=(-35, 14))
    stone = p.mesh("Stones", "Stone", "Stone")          # mesh "well_Stones", family Stone, palette colour Stone
    stone.arc_block(r_in=3.65, r_out=4.5, a0=0, a1=28, y0=0, y1=1.0)
    wood = p.mesh("Timber", "Wood", "WoodDark")
    wood.beam((4.75, 0, 0), (4.75, 10, 0), 0.8, 0.8)
    p.collider("Cylinder", center=(0, 1.9, 0), size=(3.85, 9.6, 9.6), rotation=(0, 0, 90))
    P.make(p)        # .blend, FBX, data JSON + PropMeshData.luau, before/after preview, manifest row

Recipes are written in ROBLOX model space, in STUDS: x right, y up, z back; the prop FACES -Z (Roblox LookVector);
the origin is the ground contact point under the Studio pivot (bottom centre for the kit props). The pipeline
converts to Blender (X = -x, Y = z, Z = y, the prop faces -Y) and to metres (1 stud = 0.28 m), like the creatures.

Geometry rules: every primitive is triangulated (no n-gons), transforms are applied (rotation 0, scale 1; the
object origin is the mesh pivot: the prop origin, or the hinge of a moving piece), normals outward, flat shading
except the round sides of cylinders / tubes / lathes. UVs are WORLD SCALE: 1 UV unit = 4 studs (= one tile of the
shared textures), grain along the long axis of each piece, a random offset per piece. Vertex colours ("Col",
byte, corner) carry only SUBTLE variation (per-piece tone, lighter bevels, darker ground contact): every important
colour change is a separate mesh with its own tint.

Export: ONE FBX per prop (Blender_Exports/Props/<id>.fbx), one mesh object per material family / tint / emissive
part, named <id>_<Part>[_Glow|_Water|_Glass], mesh colliders <id>_Collider[_<Name>]. The FBX is written so that
its numbers ARE STUDS (Studio's "Studio Default" import preset reads raw FBX numbers as studs: the weapon lesson),
no textures inside (plain colour materials; the shared textures are applied in Studio by ApplyPropMeshes from
PropMeshData.luau).
"""
import csv
import json
import math
import os
import random
import sys
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import fyd_props_textures as T  # noqa: E402

ROOT = T.ROOT
STUD = 0.28                       # metres per stud
TILE = T.STUDS_PER_TILE           # studs per texture tile (1 UV unit)
FBX_SCALE = 1.0 / (STUD * 100.0)  # Blender writes FBX in cm: x 100 / 28 -> the FBX numbers are studs
BEVEL_RATIO = 0.025               # bevel = 2.5 % of the prop's smallest overall dimension
BEVEL_MAX_PIECE = 0.25            # ... but never more than 25 % of the piece's own smallest dimension
BEVEL_MIN = 0.02                  # studs (below that a bevel is not drawn)
PROPS_DIR = os.path.join(ROOT, "Blender", "Props")
TEX_DIR = os.path.join(PROPS_DIR, "textures")
EXPORT_DIR = os.path.join(ROOT, "Blender_Exports", "Props")
PREVIEW_DIR = os.path.join(ROOT, "Previews", "Props")
PHOTO_DIR = os.path.join(ROOT, "REMAKE OBJECT", "Model_References", "Model_References")
MANIFEST = os.path.join(PROPS_DIR, "props_manifest.csv")
LUAU_DATA = os.path.join(EXPORT_DIR, "PropMeshData.luau")
SCENE = "FYD_Props"
SUBJECT = "PropSubject"
RIG = "PropRig"

# Roblox model space (x right, y up, z back) -> Blender (X = -x, Y = z, Z = y): a proper rotation
R2B = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))

# ------------------------------------------------------------------------------------------------
# palette: the CURRENT Part.Color of the models (BuildKit Kit.Palette Common / Hub / Plains, measured by
# Agent B in docs/prop_inventory.md) + a few derived shades (marked *). Hex = the colour the part must keep.
# ------------------------------------------------------------------------------------------------
PALETTE = {
    "WoodLight": "#D6965C", "WoodMid": "#A86238", "WoodDark": "#703E26", "WoodTrunk": "#804E30",
    "Iron": "#5C626E", "IronWorn": "#7A808C", "Gold": "#FFC93C", "Brass": "#C99A2E",
    "Stone": "#969CA8", "StoneDark": "#686E7C", "StoneMortar": "#545864", "StonePale": "#A3AAB7",
    "StoneBlue": "#7080CC", "CaveRock": "#605C6E",
    "Moss": "#68A848", "MossDark": "#4A8A3C",
    "ClothCream": "#E8E2D0", "ClothWhite": "#F5F6FA", "ClothRed": "#D4343C", "ClothGreen": "#287C3A",
    "ClothBlue": "#4078D4", "ClothBlueAlt": "#4A6CDC", "ClothTan": "#C4A068", "ClothOrange": "#D6965C",
    "Straw": "#ECC860", "StrawPale": "#F4E2A0", "Rope": "#C4A068",
    "Bone": "#F0E8D0", "BoneAged": "#D9CDA8", "BoneSocket": "#3E3C4E",
    "RoofRed": "#C4403A", "RoofRedDark": "#9C302C", "ClamPink": "#FF5C78", "Pearl": "#F5F6FA",
    "Water": "#34D6EC", "Lantern": "#FFD678", "Fire": "#FF8C28", "Diamond": "#5FD4FF", "OreGold": "#FFC43C",
    "Flame": "#FFB648", "ClamCream": "#F7B8B8", "Thread": "#3A2A20", "ButtonDark": "#2E2B33", "Speckle": "#9C8A70",
}

# material family -> shared texture set (Blender/Props/textures/<set>_*.png), Studio fallbacks
FAMILIES = {
    "Wood": {"set": "wood_grain", "material": "Wood", "variant": "FYD_Wood"},
    "Planks": {"set": "wood_planks", "material": "WoodPlanks", "variant": "FYD_Planks"},
    "Iron": {"set": "metal_iron", "material": "Metal", "variant": "FYD_Iron", "metal": True},
    "Gold": {"set": "metal_iron", "rough": "metal_polished_roughness.png", "material": "Metal", "variant": "FYD_Gold",
             "metal": True},
    "Riveted": {"set": "metal_riveted", "material": "Metal", "variant": "FYD_Riveted", "metal": True},
    "Stone": {"set": "stone_rough", "material": "Slate", "variant": "FYD_Stone"},
    "StoneBlocks": {"set": "stone_blocks", "material": "Cobblestone", "variant": "FYD_StoneBlocks"},
    "Moss": {"set": "stone_rough", "material": "Grass", "variant": "FYD_Moss"},
    "Cloth": {"set": "cloth_canvas", "material": "Fabric", "variant": "FYD_Cloth"},
    "Straw": {"set": "straw_woven", "material": "Fabric", "variant": "FYD_Straw"},
    "Rope": {"set": "straw_woven", "material": "Fabric", "variant": "FYD_Straw"},
    "Bone": {"set": "bone_ivory", "material": "SmoothPlastic", "variant": "FYD_Bone"},
    "Glow": {"set": None, "material": "Neon", "role": "Glow"},
    "Water": {"set": None, "material": "Glass", "role": "Water", "transparency": 0.35, "overlay": "water_ripple"},
    "Glass": {"set": None, "material": "Glass", "role": "Glass", "transparency": 0.3},
    "Plain": {"set": None, "material": "SmoothPlastic"},
    "Collider": {"set": None, "material": "SmoothPlastic", "role": "Collider", "transparency": 1.0},
}
ROLE_SUFFIX = {"Glow": "_Glow", "Water": "_Water", "Glass": "_Glass"}

MANIFEST_FIELDS = ["propId", "photo", "tool", "triangles/parts", "budget", "status", "instances updated", "notes"]
PROP_ORDER = ["fountain", "lamp_post", "crate", "barrel", "mallet", "egg_nest", "rowboat", "minecart", "skull_bones",
              "scarecrow", "clam_pearl", "laundry_rack", "anvil_forge", "weapon_stall", "lantern", "well", "chest",
              "trophy_stall", "diamond_shop"]


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color_hex(c):
    return PALETTE.get(c, c) if isinstance(c, str) else "#%02X%02X%02X" % tuple(c)


# ------------------------------------------------------------------------------------------------
# texture info (textures.json: ColorMap means for the tint compensation, uploaded asset ids)
# ------------------------------------------------------------------------------------------------
def texture_info():
    path = os.path.join(TEX_DIR, "textures.json")
    if not os.path.exists(path):
        return {"sets": {}, "assetIds": {}}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def tint_rgb(family, target_hex):
    """SurfaceAppearance.Color / BasePart.Color for a family + target colour: target / ColorMap mean, scaled
    uniformly so no channel passes 255 (keeps the hue; very light / saturated colours render a little darker)."""
    fam = FAMILIES[family]
    r, g, b = hex_rgb(target_hex)
    if not fam.get("set"):
        return (r, g, b)
    mean = texture_info().get("sets", {}).get(fam["set"], {}).get("colorMean", 0.9)
    k = min(1.0 / mean, 255.0 / max(1, r, g, b))
    return tuple(min(255, int(round(c * k))) for c in (r, g, b))


# ------------------------------------------------------------------------------------------------
# description of a prop
# ------------------------------------------------------------------------------------------------
def _rot(rot):
    x, y, z = (math.radians(a) for a in rot)
    return Matrix.Rotation(x, 4, "X") @ Matrix.Rotation(y, 4, "Y") @ Matrix.Rotation(z, 4, "Z")


def _frame(a, b, up=(0, 1, 0)):
    """4x4 matrix: local z along a->b, local y as close as possible to `up`, origin at the midpoint."""
    a, b = Vector(a), Vector(b)
    z = (b - a).normalized()
    upv = Vector(up)
    if abs(z.dot(upv.normalized())) > 0.98:
        upv = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 0, 1))
    x = upv.cross(z).normalized()
    y = z.cross(x).normalized()
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = (a + b) / 2
    return m


AXES = {"x": 0, "y": 1, "z": 2, None: None}


class Mesh:
    """One exported mesh object: a material family, one tint, primitives in prop space (studs)."""

    def __init__(self, prop, part, family, color, pivot=None, shadow=None, transparency=None):
        assert family in FAMILIES, family
        self.prop, self.part, self.family = prop, part, family
        self.role = FAMILIES[family].get("role", "Solid")
        suffix = ROLE_SUFFIX.get(self.role, "")
        self.name = f"{prop.id}_{part}" + ("" if part.endswith(suffix.lstrip("_")) and suffix else suffix)
        self.target = color_hex(color or "#FFFFFF")
        self.pivot = Vector(pivot) if pivot is not None else Vector((0, 0, 0))
        self.shadow = shadow
        self.transparency = FAMILIES[family].get("transparency", 0.0) if transparency is None else transparency
        self.verts, self.faces, self.loop_uv, self.loop_shade, self.face_smooth = [], [], [], [], []
        self.rng = random.Random(zlib.crc32(self.name.encode()))
        self.pieces = 0

    # ---------------- internals ----------------
    def _bevel_width(self, piece_min, bevel):
        if bevel in (None, "all", "long", "caps", "outer"):
            w = self.prop.bevel
        else:
            w = float(bevel)
        w = min(w, BEVEL_MAX_PIECE * piece_min)
        return w if w >= BEVEL_MIN else 0.0

    @staticmethod
    def _bevel(bm, width, select):
        if width <= 0:
            return []
        bm.normal_update()
        edges = [e for e in bm.edges if select(e)]
        if not edges:
            return []
        res = bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=1, profile=0.5,
                              affect="EDGES", clamp_overlap=True)
        return res.get("faces", [])

    @staticmethod
    def _sharp(e, deg=50.0):
        return len(e.link_faces) == 2 and e.calc_face_angle(0.0) >= math.radians(deg)

    def _commit(self, bm, matrix, grain=None, uv_mode="box", cyl_r=1.0, tone=None, jit=0.0, edge_faces=(),
                smooth_faces=(), drop=()):
        """Triangulate, UV (local frame), tone, jitter, transform into prop space and append."""
        rng = self.rng
        tag = bm.faces.layers.int.get("tag") or bm.faces.layers.int.new("tag")
        for f in edge_faces:
            if f.is_valid:
                f[tag] = 1
        for f in smooth_faces:
            if f.is_valid and f[tag] != 1:
                f[tag] = 2
        bm.normal_update()
        if drop:
            dirs = [Vector(d) for d in drop]
            kill = [f for f in bm.faces if any(f.normal.dot(d) > 0.985 for d in dirs)]
            bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
        bm.normal_update()
        uvl = bm.loops.layers.uv.get("UV")
        off = (rng.random(), rng.random())
        tone = (0.965 + rng.uniform(-0.035, 0.035)) if tone is None else tone
        face_data = []
        for f in bm.faces:
            if uv_mode == "given" and uvl is not None:
                uvs = [tuple(l[uvl].uv) for l in f.loops]
            elif uv_mode == "cyl" and abs(f.normal.z) < 0.7:
                angs = [math.atan2(l.vert.co.y, l.vert.co.x) for l in f.loops]
                if max(angs) - min(angs) > math.pi:
                    angs = [a + 2 * math.pi if a < 0 else a for a in angs]
                uvs = [(l.vert.co.z / TILE + off[0], a * cyl_r / TILE + off[1]) for l, a in zip(f.loops, angs)]
            else:
                uvs = [self._uv_box(l.vert.co, f.normal, grain, off) for l in f.loops]
            shade = min(1.0, tone + 0.06) if f[tag] == 1 else tone
            face_data.append(([l.vert.index for l in f.loops], uvs, shade, f[tag] == 2))
        if jit > 0:
            for v in bm.verts:
                v.co += Vector((rng.uniform(-jit, jit), rng.uniform(-jit, jit), rng.uniform(-jit, jit)))
        bm.verts.index_update()
        base = len(self.verts)
        for v in bm.verts:
            self.verts.append(tuple(matrix @ v.co))
        for idx, uvs, shade, smooth in face_data:
            self.faces.append(tuple(base + i for i in idx))
            self.loop_uv.extend(uvs)
            self.loop_shade.extend([shade] * len(idx))
            self.face_smooth.append(smooth)
        bm.free()
        self.pieces += 1
        return self

    @staticmethod
    def _uv_box(co, n, grain, off):
        a = max(range(3), key=lambda i: abs(n[i]))
        others = [i for i in range(3) if i != a]
        if grain is not None and grain in others:
            u_ax = grain
            v_ax = others[0] if others[1] == grain else others[1]
        elif 1 in others:
            v_ax = 1
            u_ax = others[0] if others[1] == 1 else others[1]
        else:
            u_ax, v_ax = others
        return (co[u_ax] / TILE + off[0], co[v_ax] / TILE + off[1])

    # ---------------- primitives (all in studs, prop space) ----------------
    def box(self, c, size, rot=(0, 0, 0), grain=None, bevel="all", taper=None, jit=0.0, drop=(), tone=None):
        """Box of `size` (x, y, z) centred on c. bevel: 'all' | 'long' (edges along the grain only) | 0 | width.
        taper=(sx, sz) scales the top face (+y). drop: local directions of faces to remove, e.g. ((0, -1, 0),)."""
        sx, sy, sz = size
        g = AXES[grain] if isinstance(grain, str) or grain is None else grain
        if g is None:
            g = max(range(3), key=lambda i: size[i])
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= sx
            v.co.y *= sy
            v.co.z *= sz
            if taper and v.co.y > 0:
                v.co.x *= taper[0]
                v.co.z *= taper[1]
        width = self._bevel_width(min(size), bevel) if bevel else 0.0
        axis = Vector([1.0 if i == g else 0.0 for i in range(3)])
        if bevel == "long":
            sel = lambda e: abs((e.verts[1].co - e.verts[0].co).normalized().dot(axis)) > 0.9  # noqa: E731
        else:
            sel = self._sharp
        edge_faces = self._bevel(bm, width, sel)
        m = Matrix.Translation(Vector(c)) @ _rot(rot)
        return self._commit(bm, m, grain=g, tone=tone, jit=jit, edge_faces=edge_faces, drop=drop)

    def beam(self, a, b, w, h, up=(0, 1, 0), bevel="long", taper=None, jit=0.0, drop=(), tone=None, extend=0.0):
        """Square timber from point a to point b (w across, h along `up`), grain along its length."""
        a, b = Vector(a), Vector(b)
        if extend:
            d = (b - a).normalized() * extend
            a, b = a - d, b + d
        length = (b - a).length
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= w
            v.co.y *= h
            v.co.z *= length
            if taper and v.co.z > 0:
                v.co.x *= taper
                v.co.y *= taper
        width = self._bevel_width(min(w, h), bevel) if bevel else 0.0
        if bevel == "long":
            sel = lambda e: abs((e.verts[1].co - e.verts[0].co).normalized().z) > 0.9  # noqa: E731
        else:
            sel = self._sharp
        edge_faces = self._bevel(bm, width, sel)
        return self._commit(bm, _frame(a, b, up), grain=2, tone=tone, jit=jit, edge_faces=edge_faces, drop=drop)

    def cyl(self, a, b, r, r2=None, segs=8, caps=(True, True), bevel="caps", jit=0.0, smooth=True, tone=None,
            spin=0.0):
        """Cylinder / frustum from a (radius r) to b (radius r2), grain along the axis, round sides smooth."""
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        r2 = r if r2 is None else r2
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r2, depth=length)
        if spin:
            bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(spin), 3, "Z"))
        bm.normal_update()
        drop = []
        if not caps[0]:
            drop.append((0, 0, -1))
        if not caps[1]:
            drop.append((0, 0, 1))
        sides = [f for f in bm.faces if abs(f.normal.z) < 0.7] if smooth else []
        width = self._bevel_width(min(max(r, r2), length), bevel) if (bevel and all(caps)) else 0.0
        edge_faces = self._bevel(bm, width, lambda e: self._sharp(e, 60.0))
        return self._commit(bm, _frame(a, b), grain=2, uv_mode="cyl", cyl_r=max(r, r2), tone=tone, jit=jit,
                            edge_faces=edge_faces, smooth_faces=sides, drop=drop)

    def ring(self, c, r_in, r_out, h, segs=10, axis="y", faces=("outer", "top", "bottom", "inner"), tone=None,
             smooth=True, start=None):
        """Flat band / hoop around `axis` (studs), e.g. barrel and bucket hoops, rims. For axis 'y' the corners are
        at the prop angles (measured from +x toward +z) start + k * 360 / segs (default: corners at 0 deg)."""
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UV")
        rows = {}
        # the local frame of an axis-'y' ring maps local angle t to prop angle 90 - t (same corner set, winding kept)
        t0 = math.radians(90.0 - (start or 0.0)) if axis == "y" else math.radians(start or 0.0)
        for i in range(segs):
            t = t0 + 2 * math.pi * i / segs
            ca, sa = math.cos(t), math.sin(t)
            rows[i] = [bm.verts.new((ca * r, sa * r, z)) for r, z in ((r_out, -h / 2), (r_out, h / 2), (r_in, h / 2),
                                                                      (r_in, -h / 2))]
        quads = {"outer": (0, 1), "top": (1, 2), "inner": (2, 3), "bottom": (3, 0)}
        smooth_faces = []
        for i in range(segs):
            a, b = rows[i], rows[(i + 1) % segs]
            for kind in faces:
                p, q = quads[kind]
                f = bm.faces.new((a[p], b[p], b[q], a[q]))
                for k, l in enumerate(f.loops):
                    ang = (i + (1 if l.vert in (b[p], b[q]) else 0)) / segs * 2 * math.pi
                    l[uvl].uv = (ang * r_out / TILE, l.vert.co.z / TILE + (0.0 if kind in ("outer", "inner") else
                                                                            math.hypot(l.vert.co.x, l.vert.co.y) / TILE))
                if kind in ("outer", "inner") and smooth:
                    smooth_faces.append(f)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]) if set(faces) == set(quads) else None
        up = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}[axis]
        m = _frame(Vector(c) - up * 0.5, Vector(c) + up * 0.5)
        return self._commit(bm, m, uv_mode="given", tone=tone, smooth_faces=smooth_faces)

    def torus(self, c, R, r, segs=10, rsegs=4, axis="y", arc=360.0, start=0.0, tone=None, scale=(1, 1, 1)):
        """Ring of rope / iron around `axis` ('x' | 'y' | 'z' or a direction); scale (prop axes) makes it oval."""
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UV")
        full = arc >= 359.9
        n = segs if full else segs + 1
        rings = []
        for i in range(n):
            t = math.radians(start + arc * i / segs)
            ring = []
            for j in range(rsegs):
                p = 2 * math.pi * j / rsegs
                rr = R + r * math.cos(p)
                ring.append(bm.verts.new((rr * math.cos(t), rr * math.sin(t), r * math.sin(p))))
            rings.append(ring)
        faces = []
        for i in range(n if full else n - 1):
            a, b = rings[i], rings[(i + 1) % n]
            for j in range(rsegs):
                f = bm.faces.new((a[j], b[j], b[(j + 1) % rsegs], a[(j + 1) % rsegs]))
                for l in f.loops:
                    ii = i + (1 if l.vert in b else 0)
                    jj = j + (1 if l.vert in (a[(j + 1) % rsegs], b[(j + 1) % rsegs]) else 0)
                    l[uvl].uv = (ii / segs * math.radians(arc) * R / TILE, jj / rsegs * 2 * math.pi * r / TILE)
                faces.append(f)
        if not full:
            bm.faces.new(list(reversed(rings[0])))
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        up = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}[axis] if isinstance(axis, str) \
            else Vector(axis).normalized()
        m = Matrix.Translation(Vector(c)) @ Matrix.Diagonal(Vector(scale)).to_4x4() @ _frame(-up * 0.5, up * 0.5)
        return self._commit(bm, m, uv_mode="given", tone=tone, smooth_faces=faces)

    def tube(self, points, r, segs=5, caps=True, tone=None, smooth=True):
        """Round tube along a polyline (rope, iron bails, handles). r: float or one radius per point."""
        pts = [Vector(p) for p in points]
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UV")
        rings, dist = [], [0.0]
        for i in range(1, len(pts)):
            dist.append(dist[-1] + (pts[i] - pts[i - 1]).length)
        prev_u = None
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
            u = (prev_u - d * prev_u.dot(d)).normalized() if prev_u is not None else d.cross(ref).normalized()
            prev_u = u
            v = d.cross(u).normalized()
            rr = r[i] if isinstance(r, (list, tuple)) else r
            rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * j / segs) + v * math.sin(2 * math.pi * j / segs))
                                       * rr) for j in range(segs)])
        side = []
        rr0 = r[0] if isinstance(r, (list, tuple)) else r
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            for j in range(segs):
                f = bm.faces.new((a[j], a[(j + 1) % segs], b[(j + 1) % segs], b[j]))
                for l in f.loops:
                    ii = i + (1 if l.vert in b else 0)
                    jj = j + (1 if l.vert in (a[(j + 1) % segs], b[(j + 1) % segs]) else 0)
                    l[uvl].uv = (dist[ii] / TILE, jj / segs * 2 * math.pi * rr0 / TILE)
                side.append(f)
        if caps:
            bm.faces.new(list(reversed(rings[0])))
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._commit(bm, Matrix.Identity(4), uv_mode="given", tone=tone, smooth_faces=side if smooth else ())

    def arc_block(self, r_in, r_out, a0, a1, y0, y1, c=(0, 0, 0), segs=1, bevel="outer", jit=0.0, tone=None,
                  bevel_top_inner=False, drop_bottom=True, rot=(0, 0, 0)):
        """Curved block of a ring (well stones, basin blocks): angles a0..a1 in degrees around +y, measured from
        +x toward +z. Bevels the edges of its outer face (and the inner top edge when asked). rot turns the
        whole block about c (e.g. (0, 0, 90): a band around the x axis, angle 0 = +y, 90 = +z, -90 = -z)."""
        bm = bmesh.new()
        cols = []
        for k in range(segs + 1):
            t = math.radians(a0 + (a1 - a0) * k / segs)
            ca, sa = math.cos(t), math.sin(t)
            cols.append([bm.verts.new((ca * r, y, sa * r)) for r, y in ((r_out, y0), (r_out, y1), (r_in, y1),
                                                                         (r_in, y0))])
        for k in range(segs):
            a, b = cols[k], cols[k + 1]
            bm.faces.new((a[0], a[1], b[1], b[0]))  # outer
            bm.faces.new((a[1], a[2], b[2], b[1]))  # top
            bm.faces.new((a[2], a[3], b[3], b[2]))  # inner
            bm.faces.new((a[3], a[0], b[0], b[3]))  # bottom
        bm.faces.new(list(reversed(cols[0])))
        bm.faces.new(cols[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        piece = min(r_out - r_in, y1 - y0, math.radians(abs(a1 - a0)) * r_out)
        width = self._bevel_width(piece, bevel) if bevel else 0.0
        eps = 1e-4

        def on_outer(e):
            return all(abs(math.hypot(v.co.x, v.co.z) - r_out) < 0.02 for v in e.verts) and self._sharp(e)

        def on_top_inner(e):
            return all(abs(math.hypot(v.co.x, v.co.z) - r_in) < 0.02 and abs(v.co.y - y1) < eps for v in e.verts)

        sel = (lambda e: on_outer(e) or on_top_inner(e)) if bevel_top_inner else on_outer
        edge_faces = self._bevel(bm, width, sel)
        drop = ((0, -1, 0),) if drop_bottom else ()
        return self._commit(bm, Matrix.Translation(Vector(c)) @ _rot(rot), grain=None, tone=tone, jit=jit,
                            edge_faces=edge_faces, drop=drop)

    def ico(self, c, radius, scale=(1, 1, 1), sub=1, rot=(0, 0, 0), jit=0.12, tone=None, drop_below=None,
            deform=None, smooth=False):
        """Faceted lump (moss, rocks, ore, skulls, eggs): icosphere (sub 1 = 20 faces, 2 = 80) scaled, jittered,
        then deform(Vector local) -> Vector if given."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
        for v in bm.verts:
            v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
        if jit:
            for v in bm.verts:
                v.co += Vector([self.rng.uniform(-jit, jit) * radius for _ in range(3)])
        if deform is not None:
            for v in bm.verts:
                v.co = Vector(deform(v.co.copy()))
        drop = ((0, -1, 0),) if drop_below else ()
        bm.normal_update()
        return self._commit(bm, Matrix.Translation(Vector(c)) @ _rot(rot), tone=tone, drop=drop,
                            smooth_faces=list(bm.faces) if smooth else ())

    def prism(self, points, depth, c=(0, 0, 0), rot=(0, 0, 0), bevel=0, tone=None, grain=None):
        """Flat polygon [(a, b), ...] (counter-clockwise) in the local x-y plane, extruded `depth` along local z,
        centred on c, then turned by rot. Lid ends, oar blades, plates."""
        bm = bmesh.new()
        front = [bm.verts.new((a, b, -depth / 2)) for a, b in points]
        back = [bm.verts.new((a, b, depth / 2)) for a, b in points]
        bm.faces.new(list(reversed(front)))
        bm.faces.new(back)
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((front[i], front[j], back[j], back[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        span = min(depth, max(max(p[0] for p in points) - min(p[0] for p in points),
                              max(p[1] for p in points) - min(p[1] for p in points)))
        width = self._bevel_width(span, bevel) if bevel else 0.0
        edge_faces = self._bevel(bm, width, self._sharp)
        g = AXES[grain] if isinstance(grain, str) or grain is None else grain
        return self._commit(bm, Matrix.Translation(Vector(c)) @ _rot(rot), grain=g, tone=tone, edge_faces=edge_faces)

    def grid(self, pts, thickness=0.0, sides=("top",), smooth=True, tone=None):
        """Surface through a grid of points pts[i][j] (i along u, j along v, prop space). Its front ("top") faces
        the side of (du x dv). With thickness > 0 an offset copy lies behind it (pts - n * thickness): sides picks
        what is built among "top", "bottom" (the offset surface, facing away), "u0", "u1", "v0", "v1" (the border
        strips at i = 0 / last, j = 0 / last). World-scale UVs from the arc lengths along u and v."""
        nu, nv = len(pts), len(pts[0])
        P = [[Vector(p) for p in row] for row in pts]
        N = []
        for i in range(nu):
            row = []
            for j in range(nv):
                du = P[min(i + 1, nu - 1)][j] - P[max(i - 1, 0)][j]
                dv = P[i][min(j + 1, nv - 1)] - P[i][max(j - 1, 0)]
                n = du.cross(dv)
                row.append(n.normalized() if n.length > 1e-9 else Vector((0, 1, 0)))
            N.append(row)
        Q = [[P[i][j] - N[i][j] * thickness for j in range(nv)] for i in range(nu)]
        su = [[0.0] * nv for _ in range(nu)]
        sv = [[0.0] * nv for _ in range(nu)]
        for i in range(nu):
            for j in range(nv):
                su[i][j] = su[i - 1][j] + (P[i][j] - P[i - 1][j]).length if i else 0.0
                sv[i][j] = sv[i][j - 1] + (P[i][j] - P[i][j - 1]).length if j else 0.0
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UV")
        VT = [[bm.verts.new(P[i][j]) for j in range(nv)] for i in range(nu)]
        VB = [[bm.verts.new(Q[i][j]) for j in range(nv)] for i in range(nu)] if thickness > 0 else None
        center = sum((p for row in P for p in row), Vector()) / (nu * nv)
        faces = []

        def quad(vs, uvs, outward=None):
            f = bm.faces.new(vs)
            f.normal_update()
            if outward is not None and f.normal.dot(outward) < 0:
                f.normal_flip()
            for l in f.loops:  # UVs follow the vertices (valid after a flip too)
                l[uvl].uv = uvs[vs.index(l.vert)]
            faces.append(f)

        for i in range(nu - 1):
            for j in range(nv - 1):
                ids = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
                uv = [(su[a][b] / TILE, sv[a][b] / TILE) for a, b in ids]
                if "top" in sides:
                    quad([VT[a][b] for a, b in ids], uv)
                if VB is not None and "bottom" in sides:
                    rid = list(reversed(ids))
                    quad([VB[a][b] for a, b in rid], [(su[a][b] / TILE, sv[a][b] / TILE) for a, b in rid])
        if VB is not None:
            borders = {"u0": [(0, j) for j in range(nv)], "u1": [(nu - 1, j) for j in range(nv)],
                       "v0": [(i, 0) for i in range(nu)], "v1": [(i, nv - 1) for i in range(nu)]}
            for key, line in borders.items():
                if key not in sides:
                    continue
                for (a, b), (c2, d) in zip(line, line[1:]):
                    mid = (P[a][b] + P[c2][d]) / 2
                    out = mid - center
                    s0 = su[a][b] + sv[a][b]
                    s1 = su[c2][d] + sv[c2][d]
                    quad([VT[a][b], VT[c2][d], VB[c2][d], VB[a][b]],
                         [(s0 / TILE, 0.0), (s1 / TILE, 0.0), (s1 / TILE, thickness / TILE), (s0 / TILE, thickness / TILE)],
                         outward=out)
        used = {v for f in faces for v in f.verts}
        for v in [v for v in bm.verts if v not in used]:
            bm.verts.remove(v)
        return self._commit(bm, Matrix.Identity(4), uv_mode="given", tone=tone, smooth_faces=faces if smooth else ())

    def poly(self, points, normal=None, tone=None):
        """One flat convex polygon (prop space), facing `normal` if given (decals: speckles, patches, stitches)."""
        bm = bmesh.new()
        f = bm.faces.new([bm.verts.new(Vector(p)) for p in points])
        f.normal_update()
        if normal is not None and f.normal.dot(Vector(normal)) < 0:
            f.normal_flip()
        return self._commit(bm, Matrix.Identity(4), tone=tone)

    def spike(self, base, tip, r, segs=3, cap=True, tone=None):
        """Thin pyramid from a base polygon (radius r) to a point (straw, thorns, crystal tips): segs side triangles
        (+ the base cap). No degenerate faces."""
        a, b = Vector(base), Vector(tip)
        m = _frame(a, b)
        length = (b - a).length
        bm = bmesh.new()
        ring = [bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), -length / 2))
                for i in range(segs)]
        apex = bm.verts.new((0, 0, length / 2))
        for i in range(segs):
            bm.faces.new((ring[i], ring[(i + 1) % segs], apex))
        if cap:
            bm.faces.new(list(reversed(ring)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]) if cap else None
        return self._commit(bm, m, grain=2, tone=tone)

    def deform(self, fn, start=0):
        """Applies fn(Vector prop-space) -> Vector to the vertices added since index `start` (e.g. a wavy brim)."""
        self.verts[start:] = [tuple(fn(Vector(v))) for v in self.verts[start:]]
        return len(self.verts)

    def transform(self, matrix, start=0):
        """Moves the vertices added since index `start` (default: all) by a 4x4 matrix in prop space; returns the
        new vertex count (use it as the next `start`)."""
        m = Matrix(matrix)
        self.verts[start:] = [tuple(m @ Vector(v)) for v in self.verts[start:]]
        return len(self.verts)

    def lathe(self, profile, c=(0, 0, 0), segs=10, caps=(True, True), tone=None, smooth=True, scale=(1, 1, 1),
              rot=(0, 0, 0)):
        """Surface of revolution around +y: profile [(radius, y), ...] bottom to top; scale (sx, sy, sz) makes it
        elliptical, rot turns it about c."""
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UV")
        rings, dist = [], [0.0]
        for i in range(1, len(profile)):
            dist.append(dist[-1] + math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1]))
        rmax = max(p[0] for p in profile)
        for r, y in profile:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * j / segs), y, r * math.sin(2 * math.pi * j / segs)))
                          for j in range(segs)])
        side = []
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            for j in range(segs):
                f = bm.faces.new((a[j], b[j], b[(j + 1) % segs], a[(j + 1) % segs]))
                for l in f.loops:
                    ii = i + (1 if l.vert in b else 0)
                    jj = j + (1 if l.vert in (a[(j + 1) % segs], b[(j + 1) % segs]) else 0)
                    l[uvl].uv = (jj / segs * 2 * math.pi * rmax / TILE, dist[ii] / TILE)
                side.append(f)
        if caps[0]:
            bm.faces.new(rings[0])
        if caps[1]:
            bm.faces.new(list(reversed(rings[-1])))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        m = Matrix.Translation(Vector(c)) @ _rot(rot) @ Matrix.Diagonal(Vector(scale)).to_4x4()
        return self._commit(bm, m, uv_mode="given", tone=tone, smooth_faces=side if smooth else ())

    # ---------------- stats ----------------
    def tris(self):
        return len(self.faces)

    def bounds(self):
        if not self.verts:
            return Vector((0, 0, 0)), Vector((0, 0, 0))
        a = np.array(self.verts)
        lo, hi = a.min(axis=0), a.max(axis=0)
        return Vector((lo + hi) / 2), Vector(hi - lo)


class Prop:
    def __init__(self, pid, photo, size, tool="Blender", budget=1500, view=(-30, 15), view2=None, pivot_y=0.0,
                 notes="", floor=-0.06):
        """size = the CURRENT Studio bounding box (x, y, z) in studs (footprint rule: +10 % max).
        floor: no vertex goes deeper than this below the ground contact (half-buried lumps are flattened there);
        None for props that really go below their pivot."""
        self.id, self.photo, self.size, self.tool = pid, photo, Vector(size), tool
        self.floor = floor
        self.budget, self.view, self.pivot_y, self.notes = budget, view, pivot_y, notes
        self.view2 = view2 or (view[0] + 160, 22)
        self.bevel = max(BEVEL_MIN, BEVEL_RATIO * min(size))
        self.meshes = {}
        self.colliders = []
        self.attachments = {}

    def mesh(self, part, family, color=None, pivot=None, shadow=None, transparency=None):
        m = Mesh(self, part, family, color, pivot, shadow, transparency)
        assert m.name not in self.meshes, m.name
        self.meshes[m.name] = m
        return m

    def collider_mesh(self, name=None):
        """Convex collision mesh exported in the FBX as <id>_Collider[_<name>] (invisible, CollisionFidelity Hull,
        never rendered, not in the preview PNG). Build ONE convex shape per collider mesh."""
        return self.mesh("Collider" + (f"_{name}" if name else ""), "Collider", "#FFFFFF", shadow=False)

    def collider(self, shape, center, size, rotation=(0, 0, 0), name=None):
        """Simple collider for ApplyPropMeshes (an invisible Part, not a mesh): shape Block | Cylinder | Wedge,
        Roblox Part conventions (a Cylinder's axis is its X: rotation (0, 0, 90) stands it up)."""
        self.colliders.append({"Name": name or f"{self.id}_Collider_{len(self.colliders) + 1}", "Shape": shape,
                               "Center": list(center), "Size": list(size), "Rotation": list(rotation)})

    def attach(self, name, pos):
        """Named point (studs, prop space) for PropFX: emitters, lights, sounds."""
        self.attachments[name] = list(pos)

    def tris(self):
        """Render triangles (collider meshes excluded)."""
        return sum(m.tris() for m in self.meshes.values() if m.role != "Collider")

    def bounds(self):
        pts = [v for m in self.meshes.values() if m.role != "Collider" for v in m.verts]
        a = np.array(pts)
        lo, hi = a.min(axis=0), a.max(axis=0)
        return Vector((lo + hi) / 2), Vector(hi - lo), Vector(lo), Vector(hi)


# ------------------------------------------------------------------------------------------------
# scene, rig, materials
# ------------------------------------------------------------------------------------------------
def scene():
    """Headless: the file's scene (factory objects removed). Blender MCP: a dedicated scene FYD_Props."""
    if bpy.app.background:
        scn = bpy.context.scene
        for n in ("Cube", "Light", "Camera"):
            ob = bpy.data.objects.get(n)
            if ob is not None and not ob.get("fyd_props"):
                bpy.data.objects.remove(ob, do_unlink=True)
    else:
        scn = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
        win = bpy.context.window
        if win is not None and win.scene != scn:
            win.scene = scn
    return scn


def collection(name, scn=None):
    scn = scn or bpy.context.scene
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
    if col.name not in scn.collection.children:
        scn.collection.children.link(col)
    return col


def _try(fn):
    try:
        fn()
    except Exception:
        pass


def setup_rig(scn):
    rig = collection(RIG, scn)
    collection(SUBJECT, scn)
    r = scn.render
    r.engine = "BLENDER_EEVEE"
    r.resolution_x = r.resolution_y = 512
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    _try(lambda: setattr(scn.eevee, "taa_render_samples", 32))
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    scn.view_settings.exposure = 0.0
    world = bpy.data.worlds.get("PropWorld") or bpy.data.worlds.new("PropWorld")
    _try(lambda: setattr(world, "use_nodes", True))
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.62, 0.74, 0.90, 1.0)
        bg.inputs["Strength"].default_value = 0.7
    scn.world = world

    def obj(name, data):
        ob = bpy.data.objects.get(name)
        if ob is None:
            ob = bpy.data.objects.new(name, data)
            ob["fyd_props"] = True
        if ob.name not in rig.objects:
            rig.objects.link(ob)
        return ob

    cam = obj("PropCam", bpy.data.cameras.get("PropCam") or bpy.data.cameras.new("PropCam"))
    cam.data.lens = 50
    cam.data.clip_start = 0.05
    cam.data.clip_end = 500
    scn.camera = cam
    sun = obj("PropSun", bpy.data.lights.get("PropSun") or bpy.data.lights.new("PropSun", "SUN"))
    sun.data.energy = 2.7
    sun.data.color = (1.0, 0.96, 0.88)
    _try(lambda: setattr(sun.data, "angle", math.radians(3)))
    sun.rotation_euler = (math.radians(48), 0, math.radians(-38))
    rim = obj("PropRim", bpy.data.lights.get("PropRim") or bpy.data.lights.new("PropRim", "SUN"))
    rim.data.energy = 0.9
    rim.data.color = (0.85, 0.9, 1.0)
    rim.rotation_euler = (math.radians(65), 0, math.radians(150))
    _try(lambda: setattr(rim.data, "use_shadow", False))
    ground = bpy.data.objects.get("PropGround")
    if ground is None:
        me = bpy.data.meshes.new("PropGround")
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=True, segments=48, radius=60.0)
        bm.to_mesh(me)
        bm.free()
        ground = obj("PropGround", me)
        gm = bpy.data.materials.new("PropGround")
        _try(lambda: setattr(gm, "use_nodes", True))
        b = gm.node_tree.nodes.get("Principled BSDF")
        b.inputs["Base Color"].default_value = tuple(srgb_to_linear(c / 255) for c in hex_rgb("#CEC4B2")) + (1,)
        b.inputs["Roughness"].default_value = 0.95
        me.materials.append(gm)
    else:
        obj("PropGround", ground.data)
    ground.location = (0, 0, -0.002)
    return cam


def clear_subject(scn):
    col = collection(SUBJECT, scn)
    for ob in list(col.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def _image(fname, non_color):
    path = os.path.join(TEX_DIR, fname)
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def preview_material(mesh):
    fam = FAMILIES[mesh.family]
    m = bpy.data.materials.new("PV_" + mesh.name)
    _try(lambda: setattr(m, "use_nodes", True))
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tint = tuple(srgb_to_linear(c / 255) for c in tint_rgb(mesh.family, mesh.target))
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    if fam.get("set"):
        s = fam["set"]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = _image(f"{s}_color.png", False)
        mul = nt.nodes.new("ShaderNodeVectorMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = tint
        nt.links.new(tex.outputs["Color"], mul.inputs[0])
        mul2 = nt.nodes.new("ShaderNodeVectorMath")
        mul2.operation = "MULTIPLY"
        nt.links.new(mul.outputs[0], mul2.inputs[0])
        nt.links.new(vc.outputs["Color"], mul2.inputs[1])
        nt.links.new(mul2.outputs[0], bsdf.inputs["Base Color"])
        nrm = nt.nodes.new("ShaderNodeTexImage")
        nrm.image = _image(f"{s}_normal.png", True)
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nrm.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
        rough = nt.nodes.new("ShaderNodeTexImage")
        rough.image = _image(fam.get("rough") or f"{s}_roughness.png", True)
        nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
        if fam.get("metal"):
            met = nt.nodes.new("ShaderNodeTexImage")
            met.image = _image(f"{s}_metalness.png", True)
            nt.links.new(met.outputs["Color"], bsdf.inputs["Metallic"])
        else:
            bsdf.inputs["Metallic"].default_value = 0.0
    else:
        bsdf.inputs["Base Color"].default_value = tint + (1,)
        if mesh.role == "Glow":
            bsdf.inputs["Emission Color"].default_value = tint + (1,)
            bsdf.inputs["Emission Strength"].default_value = 4.0
        elif mesh.role in ("Water", "Glass"):
            bsdf.inputs["Alpha"].default_value = 1.0 - mesh.transparency
            bsdf.inputs["Roughness"].default_value = 0.06
            _try(lambda: setattr(m, "surface_render_method", "BLENDED"))
        else:
            mul = nt.nodes.new("ShaderNodeVectorMath")
            mul.operation = "MULTIPLY"
            mul.inputs[0].default_value = tint
            nt.links.new(vc.outputs["Color"], mul.inputs[1])
            nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
    m.diffuse_color = tint + (1,)
    return m


def export_material(mesh):
    """Plain colour material for the FBX (no textures: the importer must not upload per-prop textures)."""
    rgb = tint_rgb(mesh.family, mesh.target)
    name = "%s_%02X%02X%02X" % ((mesh.family,) + tuple(rgb))
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        _try(lambda: setattr(m, "use_nodes", True))
        b = m.node_tree.nodes.get("Principled BSDF")
        lin = tuple(srgb_to_linear(c / 255) for c in rgb)
        b.inputs["Base Color"].default_value = lin + (1,)
        if mesh.role == "Glow":
            b.inputs["Emission Color"].default_value = lin + (1,)
            b.inputs["Emission Strength"].default_value = 1.0
        m.diffuse_color = lin + (1,)
    return m


def _ao(y):
    t = max(0.0, min(1.0, y / 0.9))
    return 0.82 + 0.18 * (t * t * (3 - 2 * t))


def build_object(mesh, col):
    """Mesh (prop space, studs) -> Blender object (metres, Blender axes, origin on the mesh pivot)."""
    piv_b = R2B @ mesh.pivot * STUD
    verts_b = [tuple(R2B @ (Vector(v) - mesh.pivot) * STUD) for v in mesh.verts]
    old = bpy.data.objects.get(mesh.name)  # a stale copy (earlier run / lineup) would make Blender rename ours
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)
    old_me = bpy.data.meshes.get(mesh.name)
    if old_me is not None and old_me.users == 0:
        bpy.data.meshes.remove(old_me)
    me = bpy.data.meshes.new(mesh.name)
    me.from_pydata(verts_b, [], mesh.faces)
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    flat_uv = [c for t in mesh.loop_uv for c in t]
    uv.data.foreach_set("uv", flat_uv)
    # vertex colours: piece tone x ground-contact AO x downward faces (subtle)
    shades = []
    k = 0
    for f in mesh.faces:
        p = [Vector(mesh.verts[i]) for i in f]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        down = 0.88 if n.length > 1e-9 and n.normalized().y < -0.6 else 1.0
        for i in f:
            s = mesh.loop_shade[k] * _ao(mesh.verts[i][1]) * down
            shades.append(max(0.0, min(1.0, s)))
            k += 1
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    rgba = [c for s in shades for c in (s, s, s, 1.0)]
    try:
        attr.data.foreach_set("color_srgb", rgba)
    except Exception:
        attr.data.foreach_set("color", [srgb_to_linear(c) if i % 4 != 3 else c for i, c in enumerate(rgba)])
    _try(lambda: setattr(me.color_attributes, "active_color", attr))
    me.polygons.foreach_set("use_smooth", mesh.face_smooth)
    me.update()
    me.materials.append(preview_material(mesh))
    ob = bpy.data.objects.new(mesh.name, me)
    col.objects.link(ob)
    ob.location = piv_b
    ob["fyd_family"] = mesh.family
    if mesh.family == "Collider":
        ob.display_type = "WIRE"
        ob.hide_render = True
    return ob


# ------------------------------------------------------------------------------------------------
# previews
# ------------------------------------------------------------------------------------------------
def _frame_camera(cam, objs, az, el, margin=1.08):
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ v.co for ob in objs if ob.type == "MESH" and not ob.hide_render for v in ob.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    center = (lo + hi) / 2
    radius = max((p - center).length for p in pts)
    a, e = math.radians(az), math.radians(el)
    d_r = Vector((math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e)))  # Roblox space, front = -z
    d_b = R2B @ d_r
    r = bpy.context.scene.render
    aspect = min(r.resolution_x, r.resolution_y) / max(r.resolution_x, r.resolution_y)
    fov = 2 * math.atan(math.tan(cam.data.angle / 2) * aspect)  # the narrower field of view limits the framing
    dist = radius / math.sin(fov / 2) * margin
    cam.location = center + d_b * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    return center


def _fit_camera(cam, objs, az, el, margin=0.06):
    """Lineups: the camera looks from (az, el) and its distance / lens shift are fitted so every vertex lands inside
    the frame with `margin` on each side (uses the full width of wide images)."""
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ v.co for ob in objs if ob.type == "MESH" and not ob.hide_render for v in ob.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    center = (lo + hi) / 2
    a, e = math.radians(az), math.radians(el)
    d_b = R2B @ Vector((math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e)))
    r = bpy.context.scene.render
    aspect = r.resolution_x / r.resolution_y
    th = math.tan(cam.data.angle / 2)          # horizontal (sensor fit AUTO, wide image)
    tv = th / aspect
    cam.data.shift_x = cam.data.shift_y = 0.0

    def extents(dist):
        cam.location = center + d_b * dist
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        # (matrix_world is only refreshed by a depsgraph update: build it here)
        inv = (Matrix.Translation(cam.location) @ cam.rotation_euler.to_matrix().to_4x4()).inverted()
        xs, ys = [], []
        for p in pts:
            q = inv @ p
            depth = -q.z
            if depth <= 0.01:
                return None
            xs.append(q.x / depth / th)
            ys.append(q.y / depth / tv)
        return min(xs), max(xs), min(ys), max(ys)

    near, far = 0.5, 2000.0
    for _ in range(40):
        mid = (near + far) / 2
        ext = extents(mid)
        if ext is not None and (ext[1] - ext[0]) <= 2 * (1 - margin) and (ext[3] - ext[2]) <= 2 * (1 - margin):
            far = mid
        else:
            near = mid
    ext = extents(far)
    cam.data.shift_x = (ext[0] + ext[1]) / 2 * 0.5           # shift is in units of the larger frame side
    cam.data.shift_y = (ext[2] + ext[3]) / 2 * 0.5 / aspect
    return center


def _load_rgba(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    ch = img.channels
    px = np.empty(w * h * ch, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    px = px.reshape(h, w, ch)[::-1]  # top row first
    if ch < 4:
        rgb = np.repeat(px[..., :1], 3, axis=2) if ch < 3 else px[..., :3]
        px = np.concatenate([rgb, np.ones((h, w, 1), np.float32)], axis=2)
    return px


def _resize(img, new_h):
    h, w = img.shape[:2]
    new_w = max(1, int(round(w * new_h / h)))
    ys = np.clip((np.arange(new_h) + 0.5) * h / new_h - 0.5, 0, h - 1)
    xs = np.clip((np.arange(new_w) + 0.5) * w / new_w - 0.5, 0, w - 1)
    y0, x0 = np.floor(ys).astype(int), np.floor(xs).astype(int)
    y1, x1 = np.minimum(y0 + 1, h - 1), np.minimum(x0 + 1, w - 1)
    fy, fx = (ys - y0)[:, None, None], (xs - x0)[None, :, None]
    top = img[y0][:, x0] * (1 - fx) + img[y0][:, x1] * fx
    bot = img[y1][:, x0] * (1 - fx) + img[y1][:, x1] * fx
    return top * (1 - fy) + bot * fy


def _sky(h, w):
    t = np.linspace(0, 1, h)[:, None, None]
    top, bottom = np.array([0.66, 0.84, 0.96]), np.array([0.92, 0.95, 0.97])
    return np.broadcast_to(top * (1 - t) + bottom * t, (h, w, 3)).copy()


def render_views(prop, objs, views, tmp_prefix):
    scn = bpy.context.scene
    cam = scn.camera
    paths = []
    for i, (az, el) in enumerate(views):
        _frame_camera(cam, list(objs.values()), az, el)
        path = f"{tmp_prefix}_{i}.png"
        scn.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def before_after(prop, objs):
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    tmp = os.path.join(PREVIEW_DIR, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    shots = render_views(prop, objs, [prop.view, prop.view2], os.path.join(tmp, prop.id))
    H = 512
    cells = []
    photo = os.path.join(PHOTO_DIR, prop.photo) if prop.photo else None
    if photo and os.path.exists(photo):
        cells.append(_resize(_load_rgba(photo)[..., :3], H))
    for s in shots:
        px = _load_rgba(s)
        px = _resize(px, H)
        a = px[..., 3:4]
        cells.append(px[..., :3] * a + _sky(px.shape[0], px.shape[1]) * (1 - a))
        os.remove(s)
    gap = 8
    width = sum(c.shape[1] for c in cells) + gap * (len(cells) + 1)
    sheet = np.ones((H + 2 * gap, width, 3)) * 0.18
    x = gap
    for c in cells:
        sheet[gap:gap + H, x:x + c.shape[1]] = c
        x += c.shape[1] + gap
    out = os.path.join(PREVIEW_DIR, f"{prop.id}_before_after.png")
    T.write_png(out, T.to_u8(sheet))
    return out


def lineup(name, ids, out=None, gap=2.0, az=-20, el=14):
    """Every prop .blend of `ids` side by side at real relative scale (Roblox +x), one wide render."""
    scn = scene()
    setup_rig(scn)
    clear_subject(scn)
    col = collection(SUBJECT, scn)
    x = 0.0
    placed = {}
    for pid in ids:
        path = os.path.join(PROPS_DIR, pid + ".blend")
        if not os.path.exists(path):
            continue
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n.startswith(pid + "_") and "_Collider" not in n]
        obs = [o for o in dst.objects if o is not None and o.type == "MESH"]
        for o in obs:
            col.objects.link(o)
        bpy.context.view_layer.update()
        xs = [-(o.matrix_world @ v.co).x / STUD for o in obs for v in o.data.vertices]  # Roblox x in studs
        if not xs:
            continue
        # props go toward Roblox -X: seen from the front (camera on -Z) the first id is on the LEFT
        shift = x - max(xs)
        for o in obs:
            o.location.x -= shift * STUD
            placed[o.name] = o
        x -= (max(xs) - min(xs)) + gap
    scn.render.resolution_x, scn.render.resolution_y = 1600, 640
    _fit_camera(scn.camera, list(placed.values()), az, el)
    tmp = os.path.join(PREVIEW_DIR, f"_{name}_lineup_tmp.png")
    scn.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    scn.render.resolution_x = scn.render.resolution_y = 512
    px = _load_rgba(tmp)
    a = px[..., 3:4]
    img = px[..., :3] * a + _sky(px.shape[0], px.shape[1]) * (1 - a)
    out = out or os.path.join(PREVIEW_DIR, f"{name}_lineup.png")
    T.write_png(out, T.to_u8(img))
    os.remove(tmp)
    return out


# ------------------------------------------------------------------------------------------------
# outputs: .blend, FBX, data, manifest
# ------------------------------------------------------------------------------------------------
def save_blend(prop, scn):
    os.makedirs(PROPS_DIR, exist_ok=True)
    path = os.path.join(PROPS_DIR, prop.id + ".blend")
    scn["fyd_prop"] = prop.id
    bpy.data.libraries.write(path, {scn}, path_remap="RELATIVE_ALL", fake_user=True, compress=True)
    return path


def export_fbx(prop, objs):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, prop.id + ".fbx")
    sel = list(objs.values())
    saved = {}
    for name, ob in objs.items():
        assert ob.name == name, f"object renamed by Blender: {ob.name} != {name}"
        saved[ob.name] = list(ob.data.materials)
        ob.data.materials.clear()
        ob.data.materials.append(export_material(prop.meshes[name]))
    vl = bpy.context.view_layer
    for o in vl.objects:
        o.select_set(o in sel)
    vl.objects.active = sel[0]
    try:
        with bpy.context.temp_override(active_object=sel[0], selected_objects=sel):
            bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                                     apply_scale_options="FBX_SCALE_NONE", global_scale=FBX_SCALE, axis_forward="-Z",
                                     axis_up="Y", use_mesh_modifiers=True, mesh_smooth_type="FACE",
                                     colors_type="SRGB", path_mode="STRIP", embed_textures=False,
                                     bake_space_transform=False, add_leaf_bones=False, bake_anim=False)
    finally:
        for ob in sel:
            ob.data.materials.clear()
            for m in saved[ob.name]:
                ob.data.materials.append(m)
            ob.select_set(False)
    return path


def _r3(v):
    return [round(float(c) + 0.0, 3) for c in v]


def prop_data(prop):
    center, size, lo, hi = prop.bounds()
    meshes = {}
    for m in prop.meshes.values():
        c, s = m.bounds()
        fam = FAMILIES[m.family]
        big = max(s) >= 3.0
        meshes[m.name] = {
            "Family": m.family, "Role": m.role, "Color": list(tint_rgb(m.family, m.target)), "Target": m.target,
            "Material": fam["material"], "Variant": fam.get("variant"), "Transparency": m.transparency,
            "CastShadow": bool(m.shadow if m.shadow is not None else (big and m.role == "Solid")),
            "Center": _r3(c), "Size": _r3(s), "Pivot": _r3(m.pivot), "Triangles": m.tris(),
            "Overlay": fam.get("overlay"),
        }
    return {
        "Id": prop.id, "Photo": prop.photo, "Fbx": f"Blender_Exports/Props/{prop.id}.fbx",
        "Blend": f"Blender/Props/{prop.id}.blend", "Triangles": prop.tris(), "Budget": prop.budget,
        "Units": "studs, Roblox model space (x right, y up, z back), front -Z, origin = ground contact under the pivot",
        "PivotY": prop.pivot_y, "Bounds": {"Center": _r3(center), "Size": _r3(size), "Min": _r3(lo), "Max": _r3(hi)},
        "StudioSize": _r3(prop.size), "Meshes": meshes, "Colliders": prop.colliders,
        "Attachments": {k: _r3(v) for k, v in prop.attachments.items()},
    }


def write_json(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1)


def _lua(v, ind=1):
    pad, pad0 = "\t" * ind, "\t" * (ind - 1)
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 3)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, (list, tuple)):
        if all(isinstance(x, (int, float)) for x in v):
            return "{ " + ", ".join(_lua(x) for x in v) + " }"
        return "{\n" + "".join(f"{pad}{_lua(x, ind + 1)},\n" for x in v) + pad0 + "}"
    if isinstance(v, dict):
        items = []
        for k in v:
            if v[k] is None:
                continue
            key = k if (isinstance(k, str) and k.replace("_", "a").isalnum() and not k[0].isdigit()) else f"[{json.dumps(k)}]"
            items.append(f"{pad}{key} = {_lua(v[k], ind + 1)},\n")
        return "{\n" + "".join(items) + pad0 + "}"
    raise TypeError(type(v))


def write_luau():
    """Blender_Exports/Props/PropMeshData.luau: textures + families + every exported prop (ApplyPropMeshes reads it)."""
    info = texture_info()
    ids = info.get("assetIds", {})
    textures = {}
    for s, entry in info.get("sets", {}).items():
        textures[s] = {k: ids.get(fname) for k, fname in entry.get("files", {}).items()}
        textures[s]["ColorMean"] = entry.get("colorMean")
    families = {}
    for name, f in FAMILIES.items():
        e = {"Set": f.get("set"), "Material": f["material"], "Variant": f.get("variant"), "Role": f.get("role", "Solid"),
             "Metal": bool(f.get("metal")), "Transparency": f.get("transparency"), "Overlay": f.get("overlay")}
        if f.get("rough"):
            e["RoughnessMap"] = ids.get(f["rough"])
        families[name] = e
    props = {}
    if os.path.isdir(EXPORT_DIR):
        for fn in sorted(os.listdir(EXPORT_DIR)):
            if fn.endswith(".json"):
                with open(os.path.join(EXPORT_DIR, fn), encoding="utf-8") as f:
                    d = json.load(f)
                if "Meshes" in d:
                    props[d["Id"]] = d
    data = {"Version": 1, "StudsPerTile": TILE, "Textures": textures, "Families": families, "Props": props}
    head = ("--!strict\n-- GENERATED by tools/blender/fyd_props.py (write_luau) from Blender/Props/textures/textures.json\n"
            "-- and Blender_Exports/Props/<propId>.json. Do not edit by hand: re-run the prop pipeline.\n"
            "-- Contract: Blender/Props/README.txt. Units: studs, Roblox model space, front -Z, origin = ground contact\n"
            "-- under the pivot. Color = SurfaceAppearance.Color / BasePart.Color to set (already compensated for the\n"
            "-- ColorMap mean), Target = the colour the part must look like.\n")
    with open(LUAU_DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write(head + "return " + _lua(data) + "\n")
    return LUAU_DATA


def read_manifest():
    if not os.path.exists(MANIFEST):
        return {}
    with open(MANIFEST, newline="", encoding="utf-8") as f:
        return {r["propId"]: r for r in csv.DictReader(f)}


def write_manifest(rows):
    order = {p: i for i, p in enumerate(PROP_ORDER)}
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=MANIFEST_FIELDS, lineterminator="\n")
        w.writeheader()
        for pid in sorted(rows, key=lambda p: order.get(p, 99)):
            w.writerow({k: rows[pid].get(k, "") for k in MANIFEST_FIELDS})


def update_manifest(pid, **fields):
    """Updates the given columns of one row (other columns, e.g. 'instances updated', are kept)."""
    rows = read_manifest()
    row = rows.get(pid, {"propId": pid})
    for k, v in fields.items():
        row[k.replace("_", " ") if k == "instances_updated" else k] = v
    rows[pid] = row
    write_manifest(rows)


def remove_from_manifest(pid):
    rows = read_manifest()
    if pid in rows:
        del rows[pid]
        write_manifest(rows)


# ------------------------------------------------------------------------------------------------
# Studio preview channel: the meshes encoded in a PNG (Agent B decodes it with EditableImage / EditableMesh)
# Format (Blender/Props/README.txt "Preview images"): RGBA 8-bit, width 1024, height <= 1024, alpha 255, payload
# in R, G, B (3 bytes / pixel) row-major from the top-left pixel, zero padded. Bytes 0-3 "FYDM", 4-7 JSON length
# (uint32 LE), 8-11 Adler-32 of the JSON (uint32 LE), 12.. UTF-8 JSON {"prop","version","meshes":[{"name","v","n",
# "uv","c","t"}]}: positions in studs (prop space), normals, uv (v = 0 at the TOP), colours 0..255, triangles CCW.
# ------------------------------------------------------------------------------------------------
PREVIEW_DIR_PNG = os.path.join(EXPORT_DIR, "preview")
PNG_W, PNG_MAX_H = 1024, 1024
PNG_CAPACITY = PNG_W * PNG_MAX_H * 3 - 12


def _num(x, nd):
    v = round(float(x), nd)
    return 0.0 if v == 0 else v  # no "-0.0"


def mesh_payload(ob):
    """Every corner of the exported mesh as Roblox-space data; vertices split where normal / uv / colour differ."""
    me = ob.data
    mw = ob.matrix_world
    rot = mw.to_3x3()
    uvl = me.uv_layers.active.data if me.uv_layers.active else None
    col = me.color_attributes.get("Col")
    cn = me.corner_normals
    index, v, n, uv, c, t = {}, [], [], [], [], []
    for poly in me.polygons:
        assert poly.loop_total == 3, f"{ob.name}: non-triangle face"
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            p = R2B @ (mw @ me.vertices[vi].co) / STUD
            nn = (R2B @ (rot @ cn[li].vector)).normalized()
            uu, vv = (uvl[li].uv[0], 1.0 - uvl[li].uv[1]) if uvl else (0.0, 0.0)
            if col is not None:
                cc = tuple(int(round(max(0.0, min(1.0, x)) * 255)) for x in col.data[li].color_srgb[:3])
            else:
                cc = (255, 255, 255)
            key = (vi, _num(nn.x, 3), _num(nn.y, 3), _num(nn.z, 3), _num(uu, 4), _num(vv, 4), cc)
            k = index.get(key)
            if k is None:
                k = len(index)
                index[key] = k
                v.extend((_num(p.x, 4), _num(p.y, 4), _num(p.z, 4)))
                n.extend(key[1:4])
                uv.extend(key[4:6])
                c.extend(cc)
            t.append(k)
    return {"name": ob.name, "v": v, "n": n, "uv": uv, "c": c, "t": t}


def _png_bytes(pid, meshes):
    body = json.dumps({"prop": pid, "version": 1, "meshes": meshes}, separators=(",", ":")).encode("utf-8")
    head = b"FYDM" + len(body).to_bytes(4, "little") + (zlib.adler32(body) & 0xFFFFFFFF).to_bytes(4, "little")
    return head + body


def write_preview_png(pid, objs):
    """objs: {name: object} of the prop's render meshes (colliders excluded). Returns the PNG paths written."""
    os.makedirs(PREVIEW_DIR_PNG, exist_ok=True)
    payloads = [mesh_payload(ob) for name, ob in sorted(objs.items()) if "_Collider" not in name]
    groups, cur = [], []
    for m in payloads:  # pack complete meshes per image
        if cur and len(_png_bytes(pid, cur + [m])) > PNG_CAPACITY:
            groups.append(cur)
            cur = []
        cur.append(m)
        assert len(_png_bytes(pid, [m])) <= PNG_CAPACITY, f"{m['name']} alone does not fit in one image"
    groups.append(cur)
    for old in os.listdir(PREVIEW_DIR_PNG):  # stale files of this prop
        if old.startswith(pid + "_mesh") and old.endswith(".png"):
            os.remove(os.path.join(PREVIEW_DIR_PNG, old))
    paths = []
    for i, g in enumerate(groups):
        data = _png_bytes(pid, g)
        rows = max(1, -(-len(data) // (PNG_W * 3)))
        assert rows <= PNG_MAX_H
        buf = np.zeros(rows * PNG_W * 3, np.uint8)
        buf[:len(data)] = np.frombuffer(data, np.uint8)
        rgba = np.full((rows, PNG_W, 4), 255, np.uint8)
        rgba[..., :3] = buf.reshape(rows, PNG_W, 3)
        name = f"{pid}_mesh.png" if len(groups) == 1 else f"{pid}_mesh_{i + 1}.png"
        path = os.path.join(PREVIEW_DIR_PNG, name)
        T.write_png(path, rgba)
        paths.append(path)
    return paths


def decode_preview_png(path):
    """Reference decoder (the same steps as Agent B's Luau one): returns the JSON dict, checks the Adler-32."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * img.channels, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    px = np.round(px.reshape(h, w, -1)[::-1] * 255).astype(np.uint8)  # top row first
    data = px[..., :3].reshape(-1).tobytes()
    assert data[:4] == b"FYDM", "bad magic"
    length = int.from_bytes(data[4:8], "little")
    body = data[12:12 + length]
    assert (zlib.adler32(body) & 0xFFFFFFFF) == int.from_bytes(data[8:12], "little"), "Adler-32 mismatch"
    return json.loads(body.decode("utf-8"))


def load_prop_objects(pid):
    """The render meshes of Blender/Props/<pid>.blend, appended into the subject collection of the current scene."""
    scn = scene()
    col = collection(SUBJECT, scn)
    clear_subject(scn)
    path = os.path.join(PROPS_DIR, pid + ".blend")
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(pid + "_") and "_Collider" not in n]
    objs = {}
    for o in dst.objects:
        if o is not None and o.type == "MESH":
            col.objects.link(o)
            objs[o.name] = o
    bpy.context.view_layer.update()
    return objs


def preview_png(pid):
    """--preview-png: (re)write Blender_Exports/Props/preview/<pid>_mesh*.png from the saved .blend, then decode it
    back and compare (round trip). Returns {pid, files, bytes, meshes, verts, tris}."""
    objs = load_prop_objects(pid)
    paths = write_preview_png(pid, objs)
    meshes, nbytes = [], 0
    for p in paths:
        d = decode_preview_png(p)
        assert d["prop"] == pid and d["version"] == 1
        meshes += d["meshes"]
        nbytes += os.path.getsize(p)
    names = sorted(m["name"] for m in meshes)
    assert names == sorted(objs), f"decoded meshes {names} != {sorted(objs)}"
    verts = sum(len(m["v"]) // 3 for m in meshes)
    tris = sum(len(m["t"]) // 3 for m in meshes)
    assert tris == sum(len(o.data.polygons) for o in objs.values())
    return {"id": pid, "files": [os.path.relpath(p, ROOT).replace("\\", "/") for p in paths], "bytes": nbytes,
            "meshes": len(meshes), "verts": verts, "tris": tris}


# ------------------------------------------------------------------------------------------------
# one prop
# ------------------------------------------------------------------------------------------------
def make(prop, previews=True, manifest=True):
    """Build -> previews -> .blend -> FBX -> data (JSON + PropMeshData.luau) -> manifest. Returns a summary."""
    scn = scene()
    setup_rig(scn)
    clear_subject(scn)
    col = collection(SUBJECT, scn)
    if prop.floor is not None:
        for m in prop.meshes.values():
            m.verts = [(x, max(y, prop.floor), z) for x, y, z in m.verts]
    objs = {name: build_object(m, col) for name, m in prop.meshes.items() if m.faces}
    tris = prop.tris()
    bad = [n for n, m in prop.meshes.items() if any(len(f) != 3 for f in m.faces)]
    assert not bad, f"non-triangle faces in {bad}"
    sheet = before_after(prop, objs) if previews else None
    blend = save_blend(prop, scn)
    fbx = export_fbx(prop, objs)
    pngs = write_preview_png(prop.id, objs)
    data = prop_data(prop)
    write_json(os.path.join(EXPORT_DIR, prop.id + ".json"), data)
    write_luau()
    status = "ok" if tris <= prop.budget else "OVER BUDGET"
    _, size, _, _ = prop.bounds()
    growth = [round(size[i] / prop.size[i], 3) if prop.size[i] else 0 for i in range(3)]
    n_render = sum(1 for n in objs if "_Collider" not in n)
    if manifest:
        update_manifest(prop.id, photo=prop.photo, tool=prop.tool, **{
            "triangles/parts": f"{tris} tris / {n_render} meshes" + (f" (+{len(objs) - n_render} collider)"
                                                                     if len(objs) > n_render else ""),
            "budget": f"<= {prop.budget:,} tris",
            "status": f"Blender {status}: .blend + FBX + preview done; waiting for the owner's import",
            "notes": (prop.notes + " | " if prop.notes else "") + "bbox %.2f x %.2f x %.2f (x%.2f / x%.2f / x%.2f)"
                     % (size[0], size[1], size[2], growth[0], growth[1], growth[2])})
    return {"id": prop.id, "tris": tris, "budget": prop.budget, "status": status, "meshes": {n: m.tris() for n, m in
            prop.meshes.items()}, "bbox": _r3(size), "growth": growth, "preview": sheet, "blend": blend, "fbx": fbx,
            "preview_png": pngs}
