"""Fight Your Destiny - weapon models V2 (docs/weapons_combat_brief.txt Phase 3), run inside Blender 5.x.

Each weapon is rebuilt from its icon (Icons/Weapons/<Category>/<NN>_<id>_icon.png, a render of the V1 model) with
more detail: same silhouette, proportions, colors and glow parts, richer geometry (hexagonal / diamond blade
sections, wrapped grips, bevels, rivets), a 1024 px baked texture set with subtle color variation and baked ambient
occlusion. The convention of Blender/Weapons/README.txt is unchanged (meters, origin = grip center, head along +Z,
front = -Y, category length, FBX Y up / -Z forward).

    import fyd_weapons2 as W2
    W2.make_weapon("Sword", 1, build_fn)   # build, finalize, compare with the icon, .blend, FBX, points, manifest

The icon is NOT re-rendered (it stays the reference). Outputs per weapon:
- Blender/Weapons/<Cat>/<NN>_<id>.blend and Blender_Exports/Weapons/<Cat>/<NN>_<id>.fbx (overwritten),
- Previews/Weapons/<Cat>/<NN>_<id>_compare.png (icon | V2 render from the icon's angle) and _preview.png (3 angles),
- Blender/Weapons/weapons_v2_points.json: bounds and attachment points (Tip, Base, Muzzle, Impact) in Roblox
  studs relative to the grip (Roblox X = -Blender X, Y = Blender Z, Z = Blender Y),
- the manifest row (triangles, budget, status "v2").
Builders mark attachment points with point("Tip", (x, y, z)) in their own meters (before the length scaling).
"""
import json
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

import fyd_icons as I
import fyd_weapons as W

ROOT = I.ROOT
TEX = 1024
AO_SAMPLES = 24
AO_STRENGTH = 0.55  # how much the baked AO darkens the color map (0 = none)
POINTS_JSON = os.path.join(W.BLEND_DIR, "weapons_v2_points.json")
TRI_MIN = 800
TRI_BUDGET = {"Magic": 5000}
DEFAULT_BUDGET = 4000

_points = {}


# ------------------------------------------------------------------------------------------------
# materials: flat values + a subtle color variation baked in the color map
# ------------------------------------------------------------------------------------------------
def pm(color, metal=0.0, rough=0.5, emit=0.0, emit_color=None, var=0.12, scale=60.0, grain=False):
    """Part material. var = strength of the baked color variation (noise), scale = noise scale (1 / m),
    grain = stretch the noise along Z (wood grain, leather strips)."""
    key = f"P2_{color}_{metal:.2f}_{rough:.2f}_{emit:.1f}_{emit_color}_{var:.2f}_{scale:.0f}_{int(grain)}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = I.mat(key, color, metal=metal, rough=rough, coat=0.2 if metal > 0.5 else 0.1, emit=emit, emit_color=emit_color)
    m["fyd_metal"] = metal
    m["fyd_rough"] = rough
    m["fyd_emit"] = emit
    m["fyd_color"] = color
    m["fyd_emit_color"] = emit_color or color
    m["fyd_var"] = 0.0 if emit > 0 else var
    m["fyd_scale"] = scale
    m["fyd_grain"] = 1 if grain else 0
    return m


def point(name, loc):
    """An attachment point in the builder's meters (Tip, Base, Muzzle, Impact)."""
    _points[name] = Vector(loc)


# ------------------------------------------------------------------------------------------------
# bake
# ------------------------------------------------------------------------------------------------
def _new_image(name, non_color):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def _bake(ob, image, setup, bake_type="EMIT", samples=1):
    """setup(material, node_tree, bsdf) wires the emission for this pass and returns a cleanup function."""
    cleanups = []
    for slot in ob.material_slots:
        m = slot.material
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        cleanups.append(setup(m, nt, bsdf))
        node = nt.nodes.new("ShaderNodeTexImage")
        node.name = "FYD_BakeTarget"
        node.image = image
        nt.nodes.active = node
    W._select_only(ob)
    scn = bpy.context.scene
    scn.cycles.samples = samples
    bpy.ops.object.bake(type=bake_type, margin=8, use_clear=True)
    for slot, cleanup in zip(ob.material_slots, cleanups):
        cleanup()
        node = slot.material.node_tree.nodes.get("FYD_BakeTarget")
        if node:
            slot.material.node_tree.nodes.remove(node)


def _flat(value_of):
    def setup(m, nt, bsdf):
        ec, es = bsdf.inputs["Emission Color"], bsdf.inputs["Emission Strength"]
        saved = (tuple(ec.default_value), es.default_value)
        r, g, b = value_of(m)
        ec.default_value = (r, g, b, 1.0)
        es.default_value = 1.0

        def cleanup():
            ec.default_value, es.default_value = saved
        return cleanup
    return setup


def _color_with_noise(m, nt, bsdf):
    """Emission = base color x (1 + var x (noise - 0.5) x 2): a subtle, deterministic variation."""
    ec, es = bsdf.inputs["Emission Color"], bsdf.inputs["Emission Strength"]
    saved = (tuple(ec.default_value), es.default_value)
    base = I.hexc(m.get("fyd_color", "#808080"))
    var = float(m.get("fyd_var", 0.0))
    added = []
    if var <= 0:
        ec.default_value = base
        es.default_value = 1.0
    else:
        coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        if m.get("fyd_grain", 0):
            mapping.inputs["Scale"].default_value = (1.0, 1.0, 0.08)
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = float(m.get("fyd_scale", 60.0))
        noise.inputs["Detail"].default_value = 4.0
        ramp = nt.nodes.new("ShaderNodeMapRange")
        ramp.inputs["From Min"].default_value = 0.3
        ramp.inputs["From Max"].default_value = 0.7
        ramp.inputs["To Min"].default_value = 1.0 - var
        ramp.inputs["To Max"].default_value = 1.0 + var
        mix = nt.nodes.new("ShaderNodeVectorMath")
        mix.operation = "MULTIPLY"
        mix.inputs[0].default_value = base[:3]
        nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Value"])
        nt.links.new(ramp.outputs["Result"], mix.inputs[1])
        link = nt.links.new(mix.outputs["Vector"], ec)
        es.default_value = 1.0
        added = [coord, mapping, noise, ramp, mix]

    def cleanup():
        for node in added:
            nt.nodes.remove(node)
        ec.default_value, es.default_value = saved
    return cleanup


def _no_change(m, nt, bsdf):
    return lambda: None


def _pixels(img):
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def finalize(wid, category):
    ob = W._join_parts("Weapon")
    target = W.LENGTH_STUDS[category] * W.STUD
    length = max(ob.dimensions)
    s = target / length if length > 0 else 1.0
    ob.data.transform(Matrix.Scale(s, 4))
    ob.data.update()
    points = {k: v * s for k, v in _points.items()}
    tris = W._clean_mesh(ob)
    W._select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    scn = bpy.context.scene
    engine = scn.render.engine
    scn.render.engine = "CYCLES"
    try:
        scn.cycles.device = "CPU"
    except Exception:
        pass
    color_img = _new_image(wid + "_color", False)
    ao_img = _new_image(wid + "_ao_tmp", True)
    metal_img = _new_image(wid + "_metalness", True)
    rough_img = _new_image(wid + "_roughness", True)
    _bake(ob, color_img, _color_with_noise)
    _bake(ob, ao_img, _no_change, bake_type="AO", samples=AO_SAMPLES)
    _bake(ob, metal_img, _flat(lambda m: (m.get("fyd_metal", 0.0),) * 3))
    _bake(ob, rough_img, _flat(lambda m: (m.get("fyd_rough", 0.5),) * 3))
    scn.render.engine = engine
    # color x AO (in linear space; the emissive parts get their own material anyway)
    c, a = _pixels(color_img), _pixels(ao_img)
    shade = 1.0 - AO_STRENGTH * (1.0 - np.clip(a[..., :1], 0.0, 1.0))
    c[..., :3] *= shade
    color_img.pixels.foreach_set(c.ravel())
    color_img.update()
    bpy.data.images.remove(ao_img)
    for img in (color_img, metal_img, rough_img):
        img.pack()
    glow_colors = [sl.material.get("fyd_emit_color") for sl in ob.material_slots if sl.material.get("fyd_emit", 0) > 0]
    glow_slots = {i for i, sl in enumerate(ob.material_slots) if sl.material.get("fyd_emit", 0) > 0}
    main, glow = W._final_materials(wid, color_img, metal_img, rough_img, glow_colors[0] if glow_colors else None)
    me = ob.data
    indices = [1 if p.material_index in glow_slots else 0 for p in me.polygons]
    me.materials.clear()
    me.materials.append(main)
    if glow:
        me.materials.append(glow)
    me.polygons.foreach_set("material_index", indices if glow else [0] * len(indices))
    me.update()
    return ob, tris, points


# ------------------------------------------------------------------------------------------------
# attachment points (Roblox studs, relative to the grip origin)
# ------------------------------------------------------------------------------------------------
def _to_roblox(v):
    return [round(-v.x / W.STUD, 3), round(v.z / W.STUD, 3), round(v.y / W.STUD, 3)]


def _default_points(ob, category, points):
    verts = [v.co for v in ob.data.vertices]
    top = max(verts, key=lambda v: v.z)
    if "Tip" not in points:
        points["Tip"] = Vector((top.x, 0.0, top.z))
    if "Base" not in points:
        points["Base"] = Vector((0.0, 0.0, top.z * 0.12))
    if category in ("Ranged", "Magic") and "Muzzle" not in points:
        points["Muzzle"] = points["Tip"].copy()
    if category == "Heavy" and "Impact" not in points:
        points["Impact"] = Vector((0.0, min(v.y for v in verts), top.z * 0.82))
    return points


def save_points(wid, ob, category, points, tris):
    data = {}
    if os.path.exists(POINTS_JSON):
        with open(POINTS_JSON, encoding="utf-8") as f:
            data = json.load(f)
    xs = [-v.co.x for v in ob.data.vertices]
    ys = [v.co.z for v in ob.data.vertices]
    zs = [v.co.y for v in ob.data.vertices]
    entry = {
        "category": category,
        "triangles": tris,
        "min": [round(min(xs) / W.STUD, 3), round(min(ys) / W.STUD, 3), round(min(zs) / W.STUD, 3)],
        "max": [round(max(xs) / W.STUD, 3), round(max(ys) / W.STUD, 3), round(max(zs) / W.STUD, 3)],
    }
    for name, v in sorted(points.items()):
        entry[name] = _to_roblox(v)
    data[wid] = entry
    with open(POINTS_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(data.items())), f, indent=1)
        f.write("\n")
    return entry


# ------------------------------------------------------------------------------------------------
# compare with the icon, previews
# ------------------------------------------------------------------------------------------------
def compare_and_previews(ob, category, fid):
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    old = bg.inputs["Strength"].default_value if bg else None
    if bg:
        bg.inputs["Strength"].default_value = W.WEAPON_WORLD_STRENGTH
    try:
        folder = os.path.join(W.PREVIEW_DIR, category)
        tmp = os.path.join(folder, "_tmp")
        os.makedirs(tmp, exist_ok=True)
        line = W.OUTLINE.get(category, I.OUTLINE_PX)
        front = os.path.join(tmp, fid + "_v2.png")
        W._render(front, ob, (0, 45, 0), outline=line)
        side = os.path.join(tmp, "side.png")
        W._render(side, ob, (0, 45, 90), outline=line)
        back = os.path.join(tmp, "back.png")
        W._render(back, ob, (0, 45, 180), outline=line)
        ob.rotation_euler = (0, 0, 0)
        icon = os.path.join(W.ICON_DIR, category, fid + "_icon.png")
        compare = os.path.join(folder, fid + "_compare.png")
        I.make_sheet([icon, front], compare, cols=2, cell=384)
        preview = os.path.join(folder, fid + "_preview.png")
        I.make_sheet([front, side, back], preview, cols=3, cell=256)
        return compare, preview, front
    finally:
        if bg:
            bg.inputs["Strength"].default_value = old


def make_weapon(category, zone_index, build, notes=""):
    zone = W.ZONES[zone_index - 1]
    wid = W.weapon_id(category, zone_index)
    fid = W.file_id(category, zone_index)
    I.clear_subject()
    _points.clear()
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    build()
    ob, tris, points = finalize(wid, category)
    points = _default_points(ob, category, points)
    dims = ob.dimensions
    length = max(dims)
    compare, preview, render = compare_and_previews(ob, category, fid)
    blend = os.path.join(W.BLEND_DIR, category, fid + ".blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend, copy=True, compress=True)
    fbx = W.export_fbx(ob, category, fid)
    entry = save_points(wid, ob, category, points, tris)
    budget = TRI_BUDGET.get(category, DEFAULT_BUDGET)
    glow = len(ob.data.materials) > 1
    status = "v2" if TRI_MIN <= tris <= budget else ("v2_over_budget" if tris > budget else "v2_under_budget")
    W.update_manifest({"file_id": fid, "weapon_id": wid, "category": category, "zone": zone, "zone_index": zone_index,
                       "name": W.NAMES[zone][W.CATEGORIES.index(category)], "triangles": tris, "budget": budget,
                       "length_m": f"{length:.3f}", "length_studs": f"{length / W.STUD:.2f}",
                       "glow": "yes" if glow else "no", "status": status, "notes": notes})
    return {"id": fid, "tris": tris, "budget": budget, "status": status, "length_studs": round(length / W.STUD, 2),
            "compare": compare, "preview": preview, "render": render, "blend": blend, "fbx": fbx, "points": entry}


def lineup(category):
    """Previews/Weapons/<Category>_lineup.png: the 12 V2 renders from the icon angle."""
    folder = os.path.join(W.PREVIEW_DIR, category, "_tmp")
    paths = [os.path.join(folder, W.file_id(category, z) + "_v2.png") for z in range(1, 13)]
    paths = [p for p in paths if os.path.exists(p)]
    out = os.path.join(W.PREVIEW_DIR, f"{category}_lineup.png")
    I.make_sheet(paths, out, cols=6, cell=256)
    return out
