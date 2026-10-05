"""Fight Your Destiny - shared 3D icon pipeline for Blender 5.x (run inside Blender).

One template for every icon (UI, zones, sub-zones, weapons): fixed 3/4 orthographic camera,
3-point lighting, glossy materials, then a thick dark outline and a soft drop shadow added in post
(numpy on the rendered PNG), 512x512 RGBA.

    import sys; sys.path.insert(0, r"<project>/tools/blender")
    import fyd_icons as I
    I.setup_template()                 # once per session (also saves Blender/Icons/_IconTemplate.blend)
    I.make_icon("Currency", "Gold", recipe_fn)   # clear subject, build, frame, render, outline, save

A recipe is a function that builds objects with the helpers below (box, cyl, lathe, extrude, ...).
Objects are created in the "IconSubject" collection; the rig lives in "IconRig".
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = r"C:\Users\benad\Desktop\Roblox Project\Fight Your Destiny"
PNG_DIR = os.path.join(ROOT, "Icons")
BLEND_DIR = os.path.join(ROOT, "Blender", "Icons")
TEMPLATE = os.path.join(BLEND_DIR, "_IconTemplate.blend")

SIZE = 512
RIG = "IconRig"
SUBJECT = "IconSubject"
CAM_AZIMUTH = 28.0  # degrees, camera to the front-right of the subject
CAM_ELEVATION = 18.0
MARGIN = 0.085  # fraction of the frame kept free on each side (outline + shadow live there)

OUTLINE_PX = 14
OUTLINE_COLOR = (0.09, 0.05, 0.03)
SHADOW_OFFSET = (5, -9)  # px (x right, y down is negative)
SHADOW_BLUR = 7
SHADOW_ALPHA = 0.38


# ------------------------------------------------------------------------------------------------
# colors and materials
# ------------------------------------------------------------------------------------------------
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h):
    h = h.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


def _set(node, name, value):
    sock = node.inputs.get(name)
    if sock is not None:
        try:
            sock.default_value = value
        except Exception:
            pass


def mat(name, color, metal=0.0, rough=0.38, coat=0.7, emit=0.0, emit_color=None, alpha=1.0):
    """Glossy principled material (cached by name). color: '#rrggbb'."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    _set(bsdf, "Base Color", hexc(color))
    _set(bsdf, "Metallic", metal)
    _set(bsdf, "Roughness", rough)
    _set(bsdf, "Coat Weight", coat)
    _set(bsdf, "Coat Roughness", 0.08)
    _set(bsdf, "Specular IOR Level", 0.6)
    if emit > 0:
        _set(bsdf, "Emission Color", hexc(emit_color or color))
        _set(bsdf, "Emission Strength", emit)
    if alpha < 1:
        _set(bsdf, "Alpha", alpha)
    m.diffuse_color = hexc(color)
    return m


# ------------------------------------------------------------------------------------------------
# collections / objects
# ------------------------------------------------------------------------------------------------
def collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def _finish(bm, name, material, smooth=True, bevel=0.0, segments=3, subsurf=0, loc=(0, 0, 0),
            rot=(0, 0, 0), scale=(1, 1, 1), angle=40, parent=None):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    me.update()
    ob = bpy.data.objects.new(name, me)
    collection(SUBJECT).objects.link(ob)
    if material is not None:
        me.materials.append(material)
    if bevel > 0:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        try:
            mod.harden_normals = smooth
        except Exception:
            pass
    if subsurf:
        mod = ob.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.scale = scale
    if parent is not None:
        ob.parent = parent
    return ob


def box(sx, sy, sz, material, **kw):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    kw.setdefault("bevel", min(sx, sy, sz) * 0.18)
    return _finish(bm, kw.pop("name", "Box"), material, **kw)


def cyl(r, depth, material, r2=None, segs=32, cap=True, **kw):
    """Cylinder / cone along Z, centered."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs, radius1=r,
                          radius2=r if r2 is None else r2, depth=depth)
    kw.setdefault("bevel", min(r, depth) * 0.15)
    return _finish(bm, kw.pop("name", "Cyl"), material, **kw)


def sphere(r, material, segs=32, rings=16, **kw):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return _finish(bm, kw.pop("name", "Sphere"), material, **kw)


def ico(r, material, subdiv=1, **kw):
    """Faceted rock-like sphere (flat shading by default)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    kw.setdefault("smooth", False)
    return _finish(bm, kw.pop("name", "Ico"), material, **kw)


def torus(R, r, material, segs=48, rsegs=16, arc=360.0, start=0.0, **kw):
    """Torus in the XY plane (around Z). arc < 360 makes an open ring (capped)."""
    bm = bmesh.new()
    full = arc >= 359.9
    n = segs if full else segs + 1
    rings = []
    for i in range(n):
        a = math.radians(start) + math.radians(arc) * i / segs
        c, s = math.cos(a), math.sin(a)
        ring = []
        for j in range(rsegs):
            b = 2 * math.pi * j / rsegs
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new((rr * c, rr * s, r * math.sin(b))))
        rings.append(ring)
    for i in range(n if full else n - 1):
        a_ring, b_ring = rings[i], rings[(i + 1) % n]
        for j in range(rsegs):
            bm.faces.new((a_ring[j], b_ring[j], b_ring[(j + 1) % rsegs], a_ring[(j + 1) % rsegs]))
    if not full:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, kw.pop("name", "Torus"), material, **kw)


def lathe(profile, material, segs=40, **kw):
    """Surface of revolution around Z. profile: [(radius, z), ...] from bottom to top.
    A radius of 0 closes the end with a pole."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / segs),
                                        r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(segs):
                bm.faces.new((a[0], b[i], b[(i + 1) % segs]))
        elif len(b) == 1:
            for i in range(segs):
                bm.faces.new((a[i], b[0], a[(i + 1) % segs]))
        else:
            for i in range(segs):
                bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    kw.setdefault("bevel", 0)
    return _finish(bm, kw.pop("name", "Lathe"), material, **kw)


def extrude(points, depth, material, **kw):
    """Flat shape drawn in the XZ plane (x right, z up), extruded along Y (towards the camera is -Y)."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in points]
    n = len(points)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    kw.setdefault("bevel", depth * 0.25)
    kw.setdefault("angle", 30)
    return _finish(bm, kw.pop("name", "Extrude"), material, **kw)


def star_points(n=5, r_out=1.0, r_in=0.45, rot=90.0):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot) + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def heart_points(size=1.0, steps=48):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * size, y / 17 * size))
    return pts


def circle_points(r, n=32, start=0.0, arc=360.0, cx=0.0, cz=0.0):
    full = arc >= 359.9
    count = n if full else n + 1
    return [(cx + r * math.cos(math.radians(start + arc * i / n)),
             cz + r * math.sin(math.radians(start + arc * i / n))) for i in range(count)]


def tube(points, r, material, segs=12, **kw):
    """Round tube along a polyline of 3D points (vines, ropes, whips, handles)."""
    bm = bmesh.new()
    rings = []
    pts = [Vector(p) for p in points]
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        u = d.cross(up).normalized()
        v = d.cross(u).normalized()
        rr = r[i] if isinstance(r, (list, tuple)) else r
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * j / segs) + v * math.sin(2 * math.pi * j / segs)) * rr)
                      for j in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for j in range(segs):
            bm.faces.new((a[j], a[(j + 1) % segs], b[(j + 1) % segs], b[j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, kw.pop("name", "Tube"), material, **kw)


def empty(name="Root", loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    ob = bpy.data.objects.new(name, None)
    collection(SUBJECT).objects.link(ob)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.scale = (scale, scale, scale)
    return ob


# ------------------------------------------------------------------------------------------------
# template: render settings, world, camera, lights
# ------------------------------------------------------------------------------------------------
def _cam_direction():
    az, el = math.radians(CAM_AZIMUTH), math.radians(CAM_ELEVATION)
    return Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))


def _look(ob, target=(0, 0, 0)):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def setup_template(save=True):
    scn = bpy.context.scene
    for name in ("Cube", "Light", "Camera"):
        ob = bpy.data.objects.get(name)
        if ob is not None:
            bpy.data.objects.remove(ob, do_unlink=True)
    rig = collection(RIG)
    collection(SUBJECT)

    r = scn.render
    r.engine = "BLENDER_EEVEE"
    r.resolution_x = SIZE
    r.resolution_y = SIZE
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    try:
        scn.eevee.taa_render_samples = 48
    except Exception:
        pass
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    scn.view_settings.exposure = -0.35
    scn.view_settings.gamma = 1.0

    world = bpy.data.worlds.get("IconWorld") or bpy.data.worlds.new("IconWorld")
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.55, 0.52, 0.50, 1.0)
        bg.inputs["Strength"].default_value = 0.4
    scn.world = world

    cam = bpy.data.objects.get("IconCam")
    if cam is None:
        cam = bpy.data.objects.new("IconCam", bpy.data.cameras.new("IconCam"))
        rig.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.clip_start = 0.1
    cam.data.clip_end = 200
    cam.location = _cam_direction() * 30
    _look(cam)
    scn.camera = cam

    def light(name, kind, energy, loc, size, color):
        ob = bpy.data.objects.get(name)
        if ob is None:
            ob = bpy.data.objects.new(name, bpy.data.lights.new(name, kind))
            rig.objects.link(ob)
        ob.data.energy = energy
        ob.data.color = color
        if kind == "AREA":
            ob.data.size = size
        ob.location = loc
        _look(ob)
        return ob

    light("KeyLight", "AREA", 2200, (-4.5, -6.5, 7.0), 5.0, (1.0, 0.96, 0.9))
    light("FillLight", "AREA", 700, (7.0, -4.0, 1.5), 7.0, (0.82, 0.9, 1.0))
    light("RimLight", "AREA", 2600, (3.0, 7.0, 5.0), 3.0, (1.0, 0.95, 0.85))
    light("TopLight", "AREA", 150, (0.0, 0.0, 9.0), 6.0, (1.0, 1.0, 1.0))
    if save:
        os.makedirs(BLEND_DIR, exist_ok=True)
        clear_subject()
        bpy.ops.wm.save_as_mainfile(filepath=TEMPLATE, copy=True, compress=True)
    return cam


def clear_subject():
    col = collection(SUBJECT)
    for ob in list(col.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def frame(margin=MARGIN):
    """Fit the orthographic camera to the subject (direction never changes; only scale/shift)."""
    cam = bpy.data.objects["IconCam"]
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    deps = bpy.context.evaluated_depsgraph_get()
    xs, ys = [], []
    for ob in collection(SUBJECT).all_objects:
        if ob.type != "MESH" or ob.hide_render:
            continue
        oe = ob.evaluated_get(deps)
        me = oe.to_mesh()
        mw = inv @ oe.matrix_world
        for v in me.vertices:
            p = mw @ v.co
            xs.append(p.x)
            ys.append(p.y)
        oe.to_mesh_clear()
    if not xs:
        return
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    scale = max(w, h) / (1.0 - 2 * margin)
    cam.data.ortho_scale = scale
    cam.data.shift_x = ((max(xs) + min(xs)) / 2) / scale
    cam.data.shift_y = ((max(ys) + min(ys)) / 2) / scale


# ------------------------------------------------------------------------------------------------
# post: outline + drop shadow
# ------------------------------------------------------------------------------------------------
def _shift(a, dx, dy):
    """Shift a 2D array by dx (columns) and dy (rows), padding with 0."""
    h, w = a.shape
    out = np.zeros_like(a)
    xs, xd = (0, dx) if dx >= 0 else (-dx, 0)
    ys, yd = (0, dy) if dy >= 0 else (-dy, 0)
    out[yd:h - ys if ys else h, xd:w - xs if xs else w] = a[ys:h - yd if yd else h, xs:w - xd if xd else w]
    return out


def _dilate(a, r):
    out = a.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 == 0 or d2 > r * r:
                continue
            np.maximum(out, _shift(a, dx, dy), out=out)
    return out


def _blur(a, r):
    if r <= 0:
        return a
    k = 2 * r + 1
    p = np.pad(a, r, mode="constant")
    c = np.cumsum(np.cumsum(p, axis=0), axis=1)
    c = np.pad(c, ((1, 0), (1, 0)))
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def _over(fr, fa, br, ba):
    oa = fa + ba * (1 - fa)
    safe = np.where(oa > 1e-6, oa, 1.0)
    orgb = (fr * fa[..., None] + br * (ba * (1 - fa))[..., None]) / safe[..., None]
    return orgb, oa


def postprocess(path, outline=OUTLINE_PX, color=OUTLINE_COLOR, shadow=True):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    rgb, a = px[..., :3], px[..., 3]
    ring = _dilate(a, outline) if outline > 0 else a
    ring = np.clip(_blur(ring, 1), 0, 1)
    # subject over outline
    out_rgb, out_a = _over(rgb, a, np.broadcast_to(np.array(color, np.float32), rgb.shape), ring)
    if shadow:
        sh = _blur(_shift(ring, SHADOW_OFFSET[0], SHADOW_OFFSET[1]), SHADOW_BLUR) * SHADOW_ALPHA
        out_rgb, out_a = _over(out_rgb, out_a, np.zeros_like(rgb), sh)
    res = np.concatenate([out_rgb, out_a[..., None]], axis=2).astype(np.float32)
    img.pixels.foreach_set(res.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# ------------------------------------------------------------------------------------------------
# one icon
# ------------------------------------------------------------------------------------------------
def make_icon(group, icon_id, recipe, png_path=None, blend_path=None, outline=OUTLINE_PX, margin=MARGIN):
    """Build `recipe`, frame, render, outline and save the PNG + the .blend copy. Returns paths."""
    clear_subject()
    recipe()
    frame(margin)
    png = png_path or os.path.join(PNG_DIR, group, icon_id + ".png")
    blend = blend_path or os.path.join(BLEND_DIR, group, icon_id + ".blend")
    os.makedirs(os.path.dirname(png), exist_ok=True)
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    scn = bpy.context.scene
    scn.render.filepath = png
    bpy.ops.render.render(write_still=True)
    postprocess(png, outline=outline)
    bpy.ops.wm.save_as_mainfile(filepath=blend, copy=True, compress=True)
    return {"png": png, "blend": blend}


# ------------------------------------------------------------------------------------------------
# contact sheet (for checking a group of icons at once)
# ------------------------------------------------------------------------------------------------
def make_sheet(paths, out_path, cols=4, cell=256, bg=(0.80, 0.74, 0.66)):
    rows = (len(paths) + cols - 1) // cols
    sheet = np.zeros((rows * cell, cols * cell, 4), np.float32)
    sheet[..., 0], sheet[..., 1], sheet[..., 2], sheet[..., 3] = bg[0], bg[1], bg[2], 1.0
    for i, p in enumerate(paths):
        img = bpy.data.images.load(p, check_existing=False)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        bpy.data.images.remove(img)
        px = px.reshape(h, w, 4)
        if w % cell == 0 and w // cell > 1:
            f = w // cell
            px = px.reshape(cell, f, cell, f, 4).mean(axis=(1, 3))
        elif w != cell:
            ys = (np.arange(cell) * h / cell).astype(int)
            xs = (np.arange(cell) * w / cell).astype(int)
            px = px[ys][:, xs]
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * cell
        x0 = c * cell
        a = px[..., 3:4]
        region = sheet[y0:y0 + cell, x0:x0 + cell]
        region[..., :3] = px[..., :3] * a + region[..., :3] * (1 - a)
    out = bpy.data.images.new("sheet", cols * cell, rows * cell, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return out_path
