"""Fight Your Destiny - creature pipeline (enemies, mini-bosses, bosses, pets, hub NPCs), Blender 5.x headless.

    import fyd_creatures as K
    m = K.Model("plains_boar", "Mobs", zone=1, rig="Quadruped", size=3, role="normal", name="Boar")
    body = m.part("Body")                          # parts = joints of the segmented rig
    body.ico((0, 1.8, 0), 1.0, (1.1, 0.9, 1.9), "#7A4E33", jit=0.06)
    ...
    K.make(m)                                      # .blend, FBX, JSON (rig + clips), previews, manifest row

Conventions (Blender/README.txt):
- Recipes are written in ROBLOX model space, in studs: x right, y up, z back (the model faces -Z), feet center at
  the origin. The kit converts to Blender (X = -x, Y = z, Z = y; the model faces -Y) and to meters (1 stud = 0.28 m),
  and scales the whole model so its height (or length for Serpent / long bodies) is exactly `size` studs.
- One mesh object per joint ("part"), its origin on the joint, parented to its parent part. Joint names match the
  in-game placeholders (Lib/EnemyRigs) and Config/RigClips: Body, Head, LegFL, ArmR, WingL, Seg2...
  Glowing pieces are separate "<Name>_Glow" objects (Neon in Studio).
- Colors: one 256 px palette texture per model (32 px swatches), every face UV-mapped to its swatch, one material
  "<id>_Palette" (+ "<id>_Glow" on glow objects). Flat shading, triangulated.
- Clips (fyd_creature_clips.py) are baked on the timeline at 24 fps, one marker per clip ("Walk", "Walk_loop"...).
- FBX: Y up, -Z forward, meters, no animation; object names carry the rig for Studio's
  DevTools.EnemyModels.fromImport():  "<Part>__<Parent>__<jx>_<jy>_<jz>" (joint in studs from the feet center),
  "Root__<cx>_<cy>_<cz>__<sx>_<sy>_<sz>" (hitbox), glow parts "<Name>_Glow__<Parent>__<hex>".
"""
import csv
import json
import math
import os
import random
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

import fyd_icons as I
import fyd_creature_clips as CL

ROOT = I.ROOT
STUD = 0.28
FPS = 24
PALETTE_PX = 256
SWATCH = 32
CATEGORIES = ["Mobs", "MiniBosses", "Bosses", "Pets", "NPC"]
ZONE_DIRS = {1: "01_Plains", 2: "02_Desert", 3: "03_Jungle", 4: "04_Tundra"}
BUDGET = {"Mobs": (300, 1500), "MiniBosses": (1500, 3000), "Bosses": (3000, 6000), "Pets": (200, 800), "NPC": (1000, 2500)}
MANIFEST = os.path.join(ROOT, "Blender", "models_manifest.csv")
MANIFEST_FIELDS = ["id", "category", "zone", "name", "rig", "size_studs", "size_axis", "triangles", "budget", "parts",
                   "glow_parts", "clips", "status", "blend", "fbx", "notes"]

# Roblox model space (x right, y up, z back) -> Blender (X = -x, Y = z, Z = y): a proper rotation
R2B = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def r2b(v):
    return R2B @ Vector(v)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def folder(category, zone):
    sub = ZONE_DIRS.get(zone, "Hub") if category != "NPC" else "Hub"
    return category, sub


# ------------------------------------------------------------------------------------------------
# model description (pure data until make())
# ------------------------------------------------------------------------------------------------
class Part:
    def __init__(self, model, name, parent, joint, glow=False):
        self.model, self.name, self.parent, self.joint, self.glow = model, name, parent, Vector(joint), glow
        self.prims = []

    # every primitive: center / end points in studs, Roblox model space; color "#rrggbb"
    def ico(self, c, r, s=(1, 1, 1), color="#888888", sub=1, jit=0.0, rot=(0, 0, 0)):
        if sub >= 1 and self.model.detail >= 1:
            sub = min(3, sub + 1)  # mini-bosses, bosses, NPCs: rounder shapes
        self.prims.append(("ico", dict(c=c, r=r, s=s, color=color, sub=sub, jit=jit, rot=rot)))
        return self

    def box(self, c, size, color="#888888", rot=(0, 0, 0), taper=1.0, jit=0.0):
        """Box (size x, y, z); taper < 1 shrinks the top face (+y) for wedge-like blocks."""
        cuts = self.model.detail if jit > 0 else 0  # jittered blocks become faceted slabs on big models
        self.prims.append(("box", dict(c=c, size=size, color=color, rot=rot, taper=taper, jit=jit, cuts=cuts)))
        return self

    def cone(self, a, b, r1, r2=0.0, color="#888888", segs=6, jit=0.0):
        """Cone / frustum from point a (radius r1) to point b (radius r2)."""
        segs = segs + 2 * self.model.detail if segs >= 5 else segs
        self.prims.append(("cone", dict(a=a, b=b, r1=r1, r2=r2, color=color, segs=segs, jit=jit)))
        return self

    def cyl(self, a, b, r, color="#888888", segs=6, jit=0.0):
        return self.cone(a, b, r, r, color, segs, jit)

    def disc(self, c, r, normal, depth=0.08, color="#888888", segs=8):
        n = Vector(normal).normalized()
        a, b = Vector(c) - n * depth / 2, Vector(c) + n * depth / 2
        return self.cone(tuple(a), tuple(b), r, r, color, segs)

    def mirror(self, fn):
        """Call fn(sign) for sign = -1 (left, -x) and +1 (right, +x) (symmetrical details)."""
        for sign in (-1, 1):
            fn(sign)
        return self


DETAIL = {"normal": 0, "pet": 0, "mini": 1, "npc": 1, "boss": 2}


class Model:
    def __init__(self, mid, category, zone=None, rig="Quadruped", size=3.0, size_axis="height", role="normal",
                 name="", notes="", detail=None):
        assert category in CATEGORIES, category
        self.id, self.category, self.zone, self.rig = mid, category, zone, rig
        self.size, self.size_axis, self.role, self.name, self.notes = size, size_axis, role, name or mid, notes
        self.detail = DETAIL.get(role, 0) if detail is None else detail
        self.parts = {}

    def part(self, name, parent=None, joint=(0, 0, 0)):
        assert name not in self.parts, name
        p = Part(self, name, parent, joint)
        self.parts[name] = p
        return p

    def glow(self, name, parent):
        """Emissive piece rigidly attached to `parent` (Neon in Studio); name gets the _Glow suffix."""
        p = Part(self, name + "_Glow", parent, (0, 0, 0), glow=True)
        self.parts[p.name] = p
        return p


# ------------------------------------------------------------------------------------------------
# geometry
# ------------------------------------------------------------------------------------------------
def _rot_matrix(rot):
    x, y, z = (math.radians(a) for a in rot)
    return (Matrix.Rotation(x, 4, "X") @ Matrix.Rotation(y, 4, "Y") @ Matrix.Rotation(z, 4, "Z"))


def _align_z(direction):
    """Rotation taking +Z to `direction`."""
    d = Vector(direction).normalized()
    return Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()


def _emit(kind, a, rng):
    """One primitive (Roblox space, studs) in its own bmesh (merging later avoids stale vertex references when a
    big primitive makes the target bmesh reallocate)."""
    bm = bmesh.new()
    if kind == "ico":
        bmesh.ops.create_icosphere(bm, subdivisions=a["sub"], radius=1.0)
        m = Matrix.Translation(Vector(a["c"])) @ _rot_matrix(a["rot"]) @ Matrix.Diagonal(Vector(a["s"]) * a["r"]).to_4x4()
        scale_ref = a["r"] * min(a["s"])
    elif kind == "box":
        bmesh.ops.create_cube(bm, size=1.0)
        if a.get("cuts"):
            bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=a["cuts"], use_grid_fill=True)
        if a["taper"] != 1.0:
            for v in bm.verts:
                if v.co.y > 0:
                    v.co.x *= a["taper"]
                    v.co.z *= a["taper"]
        m = Matrix.Translation(Vector(a["c"])) @ _rot_matrix(a["rot"]) @ Matrix.Diagonal(Vector(a["size"])).to_4x4()
        scale_ref = min(a["size"])
    else:  # cone
        pa, pb = Vector(a["a"]), Vector(a["b"])
        length = max(1e-4, (pb - pa).length)
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=a["segs"], radius1=a["r1"],
                              radius2=max(0.0, a["r2"]), depth=length)
        m = Matrix.Translation((pa + pb) / 2) @ _align_z(pb - pa)
        scale_ref = max(a["r1"], a["r2"])
    for v in bm.verts:
        v.co = m @ v.co
    if a.get("jit"):
        amp = a["jit"] * scale_ref
        for v in bm.verts:
            v.co += Vector((rng.uniform(-amp, amp), rng.uniform(-amp, amp), rng.uniform(-amp, amp)))
    return bm


_TMP_MESH = None


def _part_bmesh(part, colors, seed):
    """bmesh of a part in Roblox space (studs, unscaled) with material indices from `colors`."""
    global _TMP_MESH
    try:
        alive = _TMP_MESH is not None and _TMP_MESH.name in bpy.data.meshes
    except ReferenceError:  # removed by _clear_scene (no users)
        alive = False
    if not alive:
        _TMP_MESH = bpy.data.meshes.new("_prim_tmp")
    bm = bmesh.new()
    rng = random.Random(seed)
    for kind, a in part.prims:
        pb = _emit(kind, a, rng)
        col = a["color"].lower()
        if col not in colors:
            colors.append(col)
        for f in pb.faces:
            f.material_index = colors.index(col)
        _TMP_MESH.clear_geometry()
        pb.to_mesh(_TMP_MESH)
        pb.free()
        bm.from_mesh(_TMP_MESH)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return bm


def _bounds(model, colors):
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for k, part in enumerate(model.parts.values()):
        bm = _part_bmesh(part, colors, zlib.crc32(f"{model.id}/{part.name}".encode()))
        for v in bm.verts:
            for i in range(3):
                lo[i] = min(lo[i], v.co[i])
                hi[i] = max(hi[i], v.co[i])
        bm.free()
    return lo, hi


# ------------------------------------------------------------------------------------------------
# palette texture + materials
# ------------------------------------------------------------------------------------------------
def _palette(model, colors):
    name = model.id + "_palette"
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, PALETTE_PX, PALETTE_PX, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "sRGB"
    px = np.ones((PALETTE_PX, PALETTE_PX, 4), np.float32)
    per_row = PALETTE_PX // SWATCH
    assert len(colors) <= per_row * per_row, "too many colors"
    px[..., :3] = 0.5
    for i, c in enumerate(colors):
        r, col = divmod(i, per_row)
        y0 = PALETTE_PX - (r + 1) * SWATCH
        px[y0:y0 + SWATCH, col * SWATCH:(col + 1) * SWATCH, :3] = hexc(c)
    img.pixels.foreach_set(px.ravel())
    folder_path = _paths(model)["tex_dir"]
    os.makedirs(folder_path, exist_ok=True)
    img.filepath_raw = os.path.join(folder_path, name + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def _uv_of(index):
    per_row = PALETTE_PX // SWATCH
    r, col = divmod(index, per_row)
    u = (col + 0.5) * SWATCH / PALETTE_PX
    v = 1 - (r + 0.5) * SWATCH / PALETTE_PX
    return u, v


def _materials(model, img, glow_color):
    pal = bpy.data.materials.get(model.id + "_Palette") or bpy.data.materials.new(model.id + "_Palette")
    pal.use_nodes = True
    nt = pal.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.get("PaletteTex") or nt.nodes.new("ShaderNodeTexImage")
    tex.name = "PaletteTex"
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    I._set(bsdf, "Roughness", 0.62)
    I._set(bsdf, "Specular IOR Level", 0.35)
    I._set(bsdf, "Coat Weight", 0.15)
    glow = None
    if glow_color:
        glow = bpy.data.materials.get(model.id + "_Glow") or bpy.data.materials.new(model.id + "_Glow")
        glow.use_nodes = True
        gb = glow.node_tree.nodes.get("Principled BSDF")
        I._set(gb, "Base Color", I.hexc(glow_color))
        I._set(gb, "Emission Color", I.hexc(glow_color))
        I._set(gb, "Emission Strength", 3.0)
        glow.diffuse_color = I.hexc(glow_color)
    return pal, glow


# ------------------------------------------------------------------------------------------------
# build the Blender objects
# ------------------------------------------------------------------------------------------------
def _paths(model):
    cat, sub = folder(model.category, model.zone)
    return {
        "blend_dir": os.path.join(ROOT, "Blender", cat, sub),
        "tex_dir": os.path.join(ROOT, "Blender", cat, sub, "textures"),
        "export_dir": os.path.join(ROOT, "Blender_Exports", cat, sub),
        "preview_dir": os.path.join(ROOT, "Previews", cat, sub),
    }


def _clear_scene():
    for ob in list(bpy.data.objects):
        if ob.users_collection and any(c.name == I.RIG for c in ob.users_collection):
            continue
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.actions):
        for item in list(block):
            if item.users == 0:
                block.remove(item)
    scn = bpy.context.scene
    scn.timeline_markers.clear()


def materialize(model):
    """Creates the part objects (meters, Blender axes) and returns info about the result."""
    _clear_scene()
    I.collection(I.SUBJECT)
    colors = []
    lo, hi = _bounds(model, colors)
    if model.size_axis == "length":
        measured = hi.z - lo.z
    else:
        measured = hi.y - min(0.0, lo.y)
    k = model.size / max(1e-6, measured)  # studs per build unit
    colors = []
    bms = {}
    for part in model.parts.values():
        bms[part.name] = _part_bmesh(part, colors, zlib.crc32(f"{model.id}/{part.name}".encode()))
    img = _palette(model, colors)
    glow_hex = None
    for part in model.parts.values():
        if part.glow and part.prims:
            glow_hex = part.prims[0][1]["color"]
            break
    pal, glow_mat = _materials(model, img, glow_hex)

    to_m = k * STUD
    objects = {}
    for part in model.parts.values():
        bm = bms[part.name]
        if part.glow:
            # rigid piece: its own center is the "joint"
            c = Vector((0, 0, 0))
            for v in bm.verts:
                c += v.co
            part.joint = c / max(1, len(bm.verts))
        joint_b = r2b(part.joint * to_m)
        for v in bm.verts:
            v.co = r2b(v.co * to_m) - joint_b
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            u, vv = _uv_of(f.material_index)
            for loop in f.loops:
                loop[uv].uv = (u, vv)
            f.material_index = 0
            f.smooth = False
        me = bpy.data.meshes.new(part.name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(glow_mat if (part.glow and glow_mat) else pal)
        ob = bpy.data.objects.new(part.name, me)
        I.collection(I.SUBJECT).objects.link(ob)
        ob.location = joint_b
        ob.rotation_mode = "XYZ"
        objects[part.name] = ob
    bpy.context.view_layer.update()
    for part in model.parts.values():
        if part.parent:
            ob, parent = objects[part.name], objects[part.parent]
            ob.parent = parent
            ob.matrix_parent_inverse = parent.matrix_world.inverted()
    # hitbox
    size_studs = (hi - Vector((lo.x, min(0.0, lo.y), lo.z))) * k
    center_studs = (Vector((lo.x, min(0.0, lo.y), lo.z)) + hi) / 2 * k
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = r2b(Vector((v.co.x * size_studs.x, v.co.y * size_studs.y, v.co.z * size_studs.z)) * STUD)
    me = bpy.data.meshes.new("Root")
    bm.to_mesh(me)
    bm.free()
    root = bpy.data.objects.new("Root", me)
    I.collection(I.SUBJECT).objects.link(root)
    root.location = r2b(center_studs * STUD)
    root.display_type = "WIRE"
    root.hide_render = True
    tris = sum(len(o.data.polygons) for o in objects.values())
    return {"objects": objects, "root": root, "k": k, "tris": tris, "colors": colors,
            "root_center": center_studs, "root_size": size_studs}


# ------------------------------------------------------------------------------------------------
# animation: bake the family clips on the timeline
# ------------------------------------------------------------------------------------------------
def _r_euler(r):
    m = Matrix.Rotation(r[0], 3, "X") @ Matrix.Rotation(r[1], 3, "Y") @ Matrix.Rotation(r[2], 3, "Z")
    return (R2B @ m @ R2B.transposed()).to_euler("XYZ")


def model_clips(model):
    fam = CL.all_families().get(model.rig, {})
    wanted = CL.ROLE_CLIPS.get(model.role, CL.ROLE_CLIPS["normal"])
    return {name: fam[name] for name in CL.CLIP_ORDER if name in wanted and name in fam}


def bake_clips(model, info):
    clips = model_clips(model)
    scale = model.size / CL.REF_SIZE.get(model.rig, model.size)
    scn = bpy.context.scene
    scn.render.fps = FPS
    rest = {name: (ob.location.copy(), ob.rotation_euler.copy()) for name, ob in info["objects"].items()}
    animated = {j for c in clips.values() for j in c["tracks"] if j in info["objects"]}
    frame = 1
    for name, c in clips.items():
        length = max(1, round(c["length"] * FPS))
        scn.timeline_markers.new(name + ("_loop" if c["loop"] else ""), frame=frame)
        # every animated joint holds its rest pose at the clip edges (clips never bleed into each other)
        for joint in animated:
            ob = info["objects"][joint]
            ob.location, ob.rotation_euler = rest[joint]
            for f in (frame, frame + length):
                ob.keyframe_insert("location", frame=f)
                ob.keyframe_insert("rotation_euler", frame=f)
        for joint, channels in c["tracks"].items():
            ob = info["objects"].get(joint)
            if ob is None:
                continue
            loc0, rot0 = rest[joint]
            for t, v in channels.get("r", []):
                e = _r_euler(v)
                ob.rotation_euler = (rot0.x + e.x, rot0.y + e.y, rot0.z + e.z)
                ob.keyframe_insert("rotation_euler", frame=frame + t * FPS)
            ob.rotation_euler = rot0
            for t, v in channels.get("p", []):
                ob.location = loc0 + r2b(Vector(v) * scale * STUD)
                ob.keyframe_insert("location", frame=frame + t * FPS)
            ob.location = loc0
        frame += length + 12
    scn.frame_start, scn.frame_end = 1, max(2, frame - 12)
    for ob in info["objects"].values():
        ob.location, ob.rotation_euler = rest[ob.name]
    scn.frame_set(1)
    return clips, scale


# ------------------------------------------------------------------------------------------------
# outputs
# ------------------------------------------------------------------------------------------------
def _fmt(v):
    return "_".join(f"{c + 0.0:.2f}".replace("-0.00", "0.00") for c in v)


def rig_data(model, info):
    parts = []
    for p in model.parts.values():
        joint = p.joint * info["k"]
        parts.append({"name": p.name, "parent": p.parent, "joint": [round(c, 3) for c in joint], "glow": p.glow})
    return {
        "id": model.id, "rig": model.rig, "role": model.role, "size": model.size, "sizeAxis": model.size_axis,
        "rootCenter": [round(c, 3) for c in info["root_center"]], "rootSize": [round(c, 3) for c in info["root_size"]],
        "parts": parts, "triangles": info["tris"], "colors": info["colors"],
    }


def export(model, info, clips, scale):
    paths = _paths(model)
    os.makedirs(paths["export_dir"], exist_ok=True)
    objs = list(info["objects"].values()) + [info["root"]]
    # the rig in the object names (Studio keeps them as MeshPart names)
    renamed = {}
    for p in model.parts.values():
        ob = info["objects"][p.name]
        if p.glow:
            glow_hex = p.prims[0][1]["color"].lstrip("#") if p.prims else "ffffff"
            new = f"{p.name}__{p.parent or 'Root'}__{glow_hex}"
        else:
            new = f"{p.name}__{p.parent or 'Root'}__{_fmt(p.joint * info['k'])}"
        renamed[ob] = ob.name
        ob.name = new
    root = info["root"]
    renamed[root] = root.name
    root.name = f"Root__{_fmt(info['root_center'])}__{_fmt(info['root_size'])}"
    fbx = os.path.join(paths["export_dir"], model.id + ".fbx")
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_objects=objs):
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                                 apply_scale_options="FBX_SCALE_NONE", global_scale=1.0, axis_forward="-Z",
                                 axis_up="Y", use_mesh_modifiers=True, mesh_smooth_type="FACE", path_mode="COPY",
                                 embed_textures=True, bake_space_transform=False, add_leaf_bones=False,
                                 bake_anim=False)
    for ob, name in renamed.items():
        ob.name = name
    rig = rig_data(model, info)
    with open(os.path.join(paths["export_dir"], model.id + "_rig.json"), "w", encoding="utf-8") as f:
        json.dump(rig, f, indent=1)
    anims = {"id": model.id, "rig": model.rig, "scale": round(scale, 4), "fps": FPS,
             "note": "r = radians CFrame.Angles(x, y, z), p = studs at the family reference size x scale (Roblox joint space)",
             "clips": clips}
    with open(os.path.join(paths["export_dir"], model.id + "_anims.json"), "w", encoding="utf-8") as f:
        json.dump(anims, f, indent=None, separators=(",", ":"))
    return fbx


def _pivot(info):
    piv = bpy.data.objects.get("TurnPivot")
    if piv is None:
        piv = bpy.data.objects.new("TurnPivot", None)
        I.collection(I.SUBJECT).objects.link(piv)
    for ob in list(info["objects"].values()) + [info["root"]]:
        if ob.parent is None:
            mw = ob.matrix_world.copy()
            ob.parent = piv
            ob.matrix_world = mw
    return piv


def previews(model, info):
    paths = _paths(model)
    os.makedirs(paths["preview_dir"], exist_ok=True)
    tmp = os.path.join(paths["preview_dir"], "_tmp")
    os.makedirs(tmp, exist_ok=True)
    piv = _pivot(info)
    scn = bpy.context.scene
    exposure = scn.view_settings.exposure
    scn.view_settings.exposure = -0.9
    shots = []
    for i, (yaw, frame) in enumerate(((0, 1), (90, 1), (200, 1))):
        piv.rotation_euler = (0, 0, math.radians(yaw))
        scn.frame_set(frame)
        I.frame(0.06)
        path = os.path.join(tmp, f"{model.id}_{i}.png")
        scn.render.filepath = path
        bpy.ops.render.render(write_still=True)
        I.postprocess(path, outline=6, shadow=True)
        shots.append(path)
    # one action frame (the attack wind-up) if the model has clips
    attack = next((m for m in scn.timeline_markers if m.name.split("_")[0] in ("Attack1", "Shoot", "Intro", "Wave")), None)
    if attack is not None:
        piv.rotation_euler = (0, 0, math.radians(30))
        scn.frame_set(attack.frame + 9)
        I.frame(0.06)
        path = os.path.join(tmp, f"{model.id}_3.png")
        scn.render.filepath = path
        bpy.ops.render.render(write_still=True)
        I.postprocess(path, outline=6, shadow=True)
        shots.append(path)
    scn.frame_set(1)
    piv.rotation_euler = (0, 0, 0)
    scn.view_settings.exposure = exposure
    sheet = os.path.join(paths["preview_dir"], model.id + "_preview.png")
    I.make_sheet(shots, sheet, cols=len(shots), cell=320)
    # unparent from the pivot (keeps the exported hierarchy clean)
    for ob in list(piv.children):
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = mw
    bpy.data.objects.remove(piv, do_unlink=True)
    return sheet, shots[0]


def update_manifest(row):
    rows = []
    if os.path.exists(MANIFEST):
        with open(MANIFEST, newline="", encoding="utf-8") as f:
            rows = [r for r in csv.DictReader(f) if r["id"] != row["id"]]
    rows.append(row)
    order = {c: i for i, c in enumerate(CATEGORIES)}
    rows.sort(key=lambda r: (order.get(r["category"], 99), r["zone"], r["id"]))
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in MANIFEST_FIELDS})


def make(model):
    """Build -> clips -> previews -> .blend -> FBX + JSON -> manifest. Returns a summary dict."""
    if bpy.data.objects.get("IconCam") is None:
        I.setup_template(save=False)
    info = materialize(model)
    clips, scale = bake_clips(model, info)
    sheet, icon = previews(model, info)
    paths = _paths(model)
    os.makedirs(paths["blend_dir"], exist_ok=True)
    blend = os.path.join(paths["blend_dir"], model.id + ".blend")
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=blend, copy=True, compress=True)
    fbx = export(model, info, clips, scale)
    lo, hi = BUDGET[model.category]
    tris = info["tris"]
    status = "ok" if lo <= tris <= hi else ("under budget" if tris < lo else "OVER BUDGET")
    glow = [p.name for p in model.parts.values() if p.glow]
    row = {
        "id": model.id, "category": model.category, "zone": ZONE_DIRS.get(model.zone, "Hub"), "name": model.name,
        "rig": model.rig, "size_studs": model.size, "size_axis": model.size_axis, "triangles": tris,
        "budget": f"{lo}-{hi}", "parts": len(model.parts) - len(glow), "glow_parts": len(glow),
        "clips": " ".join(clips.keys()), "status": status,
        "blend": os.path.relpath(blend, ROOT).replace("\\", "/"), "fbx": os.path.relpath(fbx, ROOT).replace("\\", "/"),
        "notes": model.notes,
    }
    update_manifest(row)
    return {"id": model.id, "tris": tris, "status": status, "preview": sheet, "icon": icon, "parts": len(model.parts)}


def lineup(category, zone, ids, out=None, gap=1.5):
    """Real 3D lineup at relative scale: appends the part objects of each saved .blend side by side."""
    _clear_scene()
    if bpy.data.objects.get("IconCam") is None:
        I.setup_template(save=False)
    cat, sub = folder(category, zone)
    x = 0.0
    for mid in ids:
        path = os.path.join(ROOT, "Blender", cat, sub, mid + ".blend")
        if not os.path.exists(path):
            continue
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n not in ("IconCam", "KeyLight", "FillLight", "RimLight", "TopLight")]
        obs = [o for o in dst.objects if o is not None]
        meshes = [o for o in obs if o.type == "MESH" and o.name.split(".")[0] != "Root"]
        for o in obs:
            if o.type != "MESH" or o.name.split(".")[0] == "Root":
                continue
            I.collection(I.SUBJECT).objects.link(o)
            o.animation_data_clear()
        bpy.context.view_layer.update()
        xs = []
        for o in meshes:
            for v in o.data.vertices:
                xs.append((o.matrix_world @ v.co).x)
        if not xs:
            continue
        w = max(xs) - min(xs)
        shift = x - min(xs)
        for o in meshes:
            if o.parent is None:
                o.location.x += shift
        x += w + gap * STUD
    cam = bpy.data.objects["IconCam"]
    old_loc, old_rot = cam.location.copy(), cam.rotation_euler.copy()
    az, el = math.radians(6), math.radians(9)
    cam.location = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * 30
    I._look(cam)
    I.frame(0.04)
    out = out or os.path.join(ROOT, "Previews", cat, sub, f"{cat}_{sub}_lineup.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    scn = bpy.context.scene
    old = (scn.render.resolution_x, scn.render.resolution_y)
    scn.render.resolution_x, scn.render.resolution_y = 1600, 640
    scn.render.filepath = out
    bpy.ops.render.render(write_still=True)
    scn.render.resolution_x, scn.render.resolution_y = old
    cam.location, cam.rotation_euler = old_loc, old_rot
    I.postprocess(out, outline=4, shadow=False)
    return out
