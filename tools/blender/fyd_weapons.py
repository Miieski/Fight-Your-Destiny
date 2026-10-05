"""Fight Your Destiny - weapon pipeline (docs/weapon_modeling_brief.txt), run inside Blender 5.x.

    import fyd_weapons as W
    W.make_weapon("Sword", 1, build_fn)   # one weapon: build, finalize, previews, .blend, FBX, icon, manifest

Conventions (see Blender/Weapons/README.txt):
- real scale in meters (1 stud = 0.28 m); origin = grip center (where the hand holds it);
- blade / head along +Z, the "front" of the weapon faces -Y; FBX exported with Y up, -Z forward,
  so in Roblox the blade points along +Y;
- one mesh "Weapon" with material slot 0 = "<id>_Main" (baked 512 px color / metalness / roughness,
  packed in the .blend and embedded in the FBX) and slot 1 = "<id>_Glow" (emissive parts, if any).
"""
import csv
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import fyd_icons as I

ROOT = I.ROOT
BLEND_DIR = os.path.join(ROOT, "Blender", "Weapons")
FBX_DIR = os.path.join(ROOT, "Blender_Exports", "Weapons")
ICON_DIR = os.path.join(ROOT, "Icons", "Weapons")
PREVIEW_DIR = os.path.join(ROOT, "Previews", "Weapons")
MANIFEST = os.path.join(BLEND_DIR, "weapons_manifest.csv")

STUD = 0.28
TEX = 512
LENGTH_STUDS = {"Sword": 4.5, "Spear": 8, "Heavy": 5, "Dagger": 2, "Gauntlet": 1.8, "Ranged": 5, "Magic": 6, "Whip": 6}
TRI_BUDGET = {"Gauntlet": 4000, "Magic": 4000}
CATEGORIES = ["Sword", "Spear", "Heavy", "Dagger", "Gauntlet", "Ranged", "Magic", "Whip"]
ZONES = ["Plains", "Desert", "Jungle", "Tundra", "Swamp", "Volcano", "Hell", "Heaven", "Dead", "Abyss", "Mechanical", "Void"]
NAMES = {
    "Plains": ["Iron Shortsword", "Hunter's Spear", "Stone Hammer", "Hunter's Knife", "Leather Knuckles", "Hunting Bow", "Apprentice Staff", "Vine Whip"],
    "Desert": ["Sand Scimitar", "Nomad Pike", "Obelisk Hammer", "Scorpion Dagger", "Desert Wraps", "Desert Recurve Bow", "Sandstorm Staff", "Scarab Whip"],
    "Jungle": ["Jungle Machete", "Tribal Spear", "Totem Club", "Venom Fang", "Jaguar Claws", "Poison Blowgun", "Shaman Totem Staff", "Liana Whip"],
    "Tundra": ["Frostbrand Blade", "Icicle Lance", "Glacier Axe", "Ice Shard Dagger", "Frost Knuckles", "Frostbite Crossbow", "Blizzard Staff", "Frozen Chain"],
    "Swamp": ["Rotwood Sword", "Witch Hunter Spear", "Swamp Maul", "Toad Tooth Dagger", "Mud Fists", "Plague Bow", "Cauldron Staff", "Leech Whip"],
    "Volcano": ["Magma Blade", "Obsidian Spear", "Lava Hammer", "Ember Dagger", "Magma Gauntlets", "Flame Bow", "Eruption Staff", "Lava Chain"],
    "Hell": ["Demon Blade", "Infernal Halberd", "Doom Axe", "Imp Claw Dagger", "Demon Fists", "Soulfire Crossbow", "Infernal Tome Staff", "Soul Chain"],
    "Heaven": ["Radiant Longsword", "Celestial Lance", "Judgment Hammer", "Feather Dagger", "Angelic Gauntlets", "Dawn Bow", "Seraph Staff", "Radiant Whip"],
    "Dead": ["Deathbringer Sword", "Grave Pike", "Gravedigger's Maul", "Ghoul Fang", "Bone Knuckles", "Bone Crossbow", "Lich Staff", "Spine Whip"],
    "Abyss": ["Tidal Sword", "Deepsea Trident", "Kraken Anchor", "Angler Dagger", "Pearl Gauntlets", "Harpoon Gun", "Tidecaller Staff", "Tentacle Whip"],
    "Mechanical": ["Plasma Sword", "Electro Lance", "Hydraulic Hammer", "Nano Dagger", "Power Gauntlets", "Pulse Rifle", "Tesla Coil Staff", "Electro Whip"],
    "Void": ["Voidforged Blade", "Void Piercer", "Void Maul", "Rift Dagger", "Singularity Gauntlets", "Starfall Bow", "Void Staff", "Rift Chain"],
}


def weapon_id(category, zone_index):
    zone = ZONES[zone_index - 1]
    return f"{zone.lower()}_{category.lower()}"


def file_id(category, zone_index):
    return f"{zone_index:02d}_{weapon_id(category, zone_index)}"


# ------------------------------------------------------------------------------------------------
# part materials (flat; baked into one texture set by finalize)
# ------------------------------------------------------------------------------------------------
def pm(color, metal=0.0, rough=0.5, emit=0.0, emit_color=None):
    """Flat part material, cached by its values."""
    key = f"P_{color}_{metal:.2f}_{rough:.2f}_{emit:.1f}_{emit_color}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = I.mat(key, color, metal=metal, rough=rough, coat=0.2 if metal > 0.5 else 0.1, emit=emit, emit_color=emit_color)
    m["fyd_metal"] = metal
    m["fyd_rough"] = rough
    m["fyd_emit"] = emit
    m["fyd_color"] = color
    m["fyd_emit_color"] = emit_color or color
    return m


# ------------------------------------------------------------------------------------------------
# finalize: join, triangulate, unwrap, bake, final materials
# ------------------------------------------------------------------------------------------------
def _join_parts(name):
    deps = bpy.context.evaluated_depsgraph_get()
    col = I.collection(I.SUBJECT)
    parts = []
    for ob in list(col.all_objects):
        if ob.type != "MESH" or ob.hide_render:
            continue
        oe = ob.evaluated_get(deps)
        me = bpy.data.meshes.new_from_object(oe, preserve_all_data_layers=False, depsgraph=deps)
        me.transform(oe.matrix_world)
        new = bpy.data.objects.new(ob.name + "_baked", me)
        col.objects.link(new)
        parts.append(new)
    for ob in list(col.all_objects):
        if ob not in parts:
            bpy.data.objects.remove(ob, do_unlink=True)
    target = parts[0]
    if len(parts) > 1:
        with bpy.context.temp_override(active_object=target, selected_editable_objects=parts, selected_objects=parts):
            bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


def _clean_mesh(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(ob.data.polygons)


def _select_only(ob):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def _unwrap(ob):
    _select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.015, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def _principled(m):
    return m.node_tree.nodes.get("Principled BSDF")


def _bake_pass(ob, image, value_of):
    """Bake an EMIT pass where every material emits value_of(material) -> (r, g, b)."""
    saved = []
    for slot in ob.material_slots:
        m = slot.material
        nt = m.node_tree
        bsdf = _principled(m)
        ec, es = bsdf.inputs["Emission Color"], bsdf.inputs["Emission Strength"]
        saved.append((m, tuple(ec.default_value), es.default_value))
        r, g, b = value_of(m)
        ec.default_value = (r, g, b, 1.0)
        es.default_value = 1.0
        node = nt.nodes.new("ShaderNodeTexImage")
        node.name = "FYD_BakeTarget"
        node.image = image
        nt.nodes.active = node
    _select_only(ob)
    bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
    for m, ec, es in saved:
        bsdf = _principled(m)
        bsdf.inputs["Emission Color"].default_value = ec
        bsdf.inputs["Emission Strength"].default_value = es
        node = m.node_tree.nodes.get("FYD_BakeTarget")
        if node:
            m.node_tree.nodes.remove(node)


def _new_image(name, non_color):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def _final_materials(wid, color_img, metal_img, rough_img, glow_color):
    main = bpy.data.materials.new(wid + "_Main")
    try:
        main.use_nodes = True
    except Exception:
        pass
    nt = main.node_tree
    bsdf = _principled(main)
    for i, (img, socket) in enumerate(((color_img, "Base Color"), (metal_img, "Metallic"), (rough_img, "Roughness"))):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.location = (-400, 200 - 260 * i)
        nt.links.new(node.outputs["Color"], bsdf.inputs[socket])
    glow = None
    if glow_color:
        glow = bpy.data.materials.new(wid + "_Glow")
        try:
            glow.use_nodes = True
        except Exception:
            pass
        g = _principled(glow)
        g.inputs["Base Color"].default_value = I.hexc(glow_color)
        g.inputs["Emission Color"].default_value = I.hexc(glow_color)
        g.inputs["Emission Strength"].default_value = 3.0
        g.inputs["Roughness"].default_value = 0.3
    return main, glow


def _normalize_length(ob, category):
    """Uniform scale about the origin (grip center) so the longest side is the category length."""
    target = LENGTH_STUDS[category] * STUD
    length = max(ob.dimensions)
    if length > 0:
        s = target / length
        ob.data.transform(Matrix.Scale(s, 4))
        ob.data.update()
    return target


def finalize(wid, category):
    ob = _join_parts("Weapon")
    _normalize_length(ob, category)
    tris = _clean_mesh(ob)
    _unwrap(ob)
    scn = bpy.context.scene
    engine = scn.render.engine
    scn.render.engine = "CYCLES"
    try:
        scn.cycles.samples = 1
        scn.cycles.device = "CPU"
    except Exception:
        pass
    color_img = _new_image(wid + "_color", False)
    metal_img = _new_image(wid + "_metalness", True)
    rough_img = _new_image(wid + "_roughness", True)
    lin = lambda h: I.hexc(h)[:3]
    _bake_pass(ob, color_img, lambda m: lin(m.get("fyd_color", "#808080")))
    _bake_pass(ob, metal_img, lambda m: (m.get("fyd_metal", 0.0),) * 3)
    _bake_pass(ob, rough_img, lambda m: (m.get("fyd_rough", 0.5),) * 3)
    scn.render.engine = engine
    for img in (color_img, metal_img, rough_img):
        img.pack()
    glow_colors = [s.material.get("fyd_emit_color") for s in ob.material_slots if s.material.get("fyd_emit", 0) > 0]
    glow_slots = {i for i, s in enumerate(ob.material_slots) if s.material.get("fyd_emit", 0) > 0}
    main, glow = _final_materials(wid, color_img, metal_img, rough_img, glow_colors[0] if glow_colors else None)
    me = ob.data
    indices = [1 if p.material_index in glow_slots else 0 for p in me.polygons]
    me.materials.clear()
    me.materials.append(main)
    if glow:
        me.materials.append(glow)
    me.polygons.foreach_set("material_index", indices if glow else [0] * len(indices))
    me.update()
    budget = TRI_BUDGET.get(category, 3000)
    return ob, tris, budget


# ------------------------------------------------------------------------------------------------
# previews, icon, export, manifest
# ------------------------------------------------------------------------------------------------
def _render(path, ob, rot, margin=0.08):
    ob.rotation_euler = [math.radians(a) for a in rot]
    I.frame(margin)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    I.postprocess(path)


WEAPON_WORLD_STRENGTH = 1.1  # metals need more environment to reflect than the UI icons


def previews_and_icon(ob, category, fid):
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    old_strength = bg.inputs["Strength"].default_value if bg else None
    if bg:
        bg.inputs["Strength"].default_value = WEAPON_WORLD_STRENGTH
    try:
        return _previews_and_icon(ob, category, fid)
    finally:
        if bg:
            bg.inputs["Strength"].default_value = old_strength


def _previews_and_icon(ob, category, fid):
    os.makedirs(os.path.join(PREVIEW_DIR, category), exist_ok=True)
    os.makedirs(os.path.join(ICON_DIR, category), exist_ok=True)
    tmp = os.path.join(PREVIEW_DIR, category, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    icon = os.path.join(ICON_DIR, category, fid + "_icon.png")
    # icon pose: hilt bottom-left, tip top-right
    _render(icon, ob, (0, 45, 0))
    side = os.path.join(tmp, "side.png")
    _render(side, ob, (0, 45, 90))
    back = os.path.join(tmp, "back.png")
    _render(back, ob, (0, 45, 180))
    ob.rotation_euler = (0, 0, 0)
    preview = os.path.join(PREVIEW_DIR, category, fid + "_preview.png")
    I.make_sheet([icon, side, back], preview, cols=3, cell=256)
    return icon, preview


def export_fbx(ob, category, fid):
    os.makedirs(os.path.join(FBX_DIR, category), exist_ok=True)
    path = os.path.join(FBX_DIR, category, fid + ".fbx")
    _select_only(ob)
    with bpy.context.temp_override(active_object=ob, selected_objects=[ob]):
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                                 apply_scale_options="FBX_SCALE_NONE", global_scale=1.0, axis_forward="-Z", axis_up="Y",
                                 use_mesh_modifiers=True, mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True,
                                 bake_space_transform=False, add_leaf_bones=False)
    return path


def update_manifest(row):
    fields = ["file_id", "weapon_id", "category", "zone", "zone_index", "name", "triangles", "budget", "length_m",
              "length_studs", "glow", "status", "notes"]
    rows = []
    if os.path.exists(MANIFEST):
        with open(MANIFEST, newline="", encoding="utf-8") as f:
            rows = [r for r in csv.DictReader(f) if r["file_id"] != row["file_id"]]
    rows.append(row)
    order = {c: i for i, c in enumerate(CATEGORIES)}
    rows.sort(key=lambda r: (order.get(r["category"], 99), int(r["zone_index"])))
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})


def make_weapon(category, zone_index, build, notes=""):
    zone = ZONES[zone_index - 1]
    wid = weapon_id(category, zone_index)
    fid = file_id(category, zone_index)
    I.clear_subject()
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    build()
    ob, tris, budget = finalize(wid, category)
    dims = ob.dimensions
    length = max(dims)
    os.makedirs(os.path.join(BLEND_DIR, category), exist_ok=True)
    icon, preview = previews_and_icon(ob, category, fid)
    blend = os.path.join(BLEND_DIR, category, fid + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, copy=True, compress=True)
    fbx = export_fbx(ob, category, fid)
    glow = len(ob.data.materials) > 1
    status = "ok" if tris <= budget else "over_budget"
    update_manifest({"file_id": fid, "weapon_id": wid, "category": category, "zone": zone, "zone_index": zone_index,
                     "name": NAMES[zone][CATEGORIES.index(category)], "triangles": tris, "budget": budget,
                     "length_m": f"{length:.3f}", "length_studs": f"{length / STUD:.2f}", "glow": "yes" if glow else "no",
                     "status": status, "notes": notes})
    return {"id": fid, "tris": tris, "budget": budget, "length_studs": round(length / STUD, 2),
            "dims": [round(d, 3) for d in dims], "glow": glow, "preview": preview, "icon": icon, "blend": blend, "fbx": fbx}


def lineup(category, out=None):
    paths = [os.path.join(ICON_DIR, category, file_id(category, z) + "_icon.png") for z in range(1, 13)]
    paths = [p for p in paths if os.path.exists(p)]
    out = out or os.path.join(PREVIEW_DIR, f"{category}_lineup.png")
    I.make_sheet(paths, out, cols=6, cell=256)
    return out
