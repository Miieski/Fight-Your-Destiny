"""Checks exported props in a clean Blender (headless): re-imports Blender_Exports/Props/<id>.fbx and reopens
Blender/Props/<id>.blend, then compares them with Blender_Exports/Props/<id>.json.

    blender --background --factory-startup --python tools/blender/fyd_props_check.py -- well [more ids]

Per FBX object: name, triangles (and any non-triangle face), size in RAW FBX units (must equal the size in studs of
the JSON: the file is written in studs), colour attribute present, UV range, material. Prints PROPS_CHECK <json>.
"""
import json
import os
import sys

import bpy

ROOT = r"C:\Users\benad\Desktop\Roblox Project\Fight Your Destiny"


def check(pid):
    out = {"id": pid, "fbx": {}, "blend": {}, "problems": []}
    data_path = os.path.join(ROOT, "Blender_Exports", "Props", pid + ".json")
    with open(data_path, encoding="utf-8") as f:
        data = json.load(f)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "Blender_Exports", "Props", pid + ".fbx"))
    bpy.context.view_layer.update()
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        ngons = sum(1 for p in me.polygons if len(p.vertices) != 3)
        # Blender's importer turns the FBX centimetres into metres: raw FBX units = metres x 100
        pts = [ob.matrix_world @ v.co for v in me.vertices]
        raw = [round((max(p[i] for p in pts) - min(p[i] for p in pts)) * 100, 3) for i in range(3)]
        raw_roblox = [raw[0], raw[2], raw[1]]  # Blender X, Z, Y -> Roblox x, y, z
        uvs = [c for d in me.uv_layers[0].data for c in d.uv] if me.uv_layers else []
        entry = {"tris": len(me.polygons), "ngons": ngons, "rawSize_xyz": raw_roblox,
                 "colors": [a.name for a in me.color_attributes], "uv": [round(min(uvs), 2), round(max(uvs), 2)] if uvs else None,
                 "materials": [m.name for m in me.materials if m]}
        ref = data["Meshes"].get(ob.name)
        if ref is None:
            out["problems"].append(f"{ob.name}: not in the JSON")
        else:
            if ref["Triangles"] != len(me.polygons):
                out["problems"].append(f"{ob.name}: {len(me.polygons)} tris, JSON {ref['Triangles']}")
            if any(abs(a - b) > 0.02 for a, b in zip(raw_roblox, ref["Size"])):
                out["problems"].append(f"{ob.name}: raw size {raw_roblox} != studs {ref['Size']}")
            # low-poly contract (docs/prop_texture_guide.md): FBX material <Material>_<RRGGBB of Color>, no PBR fields,
            # white vertex colours where the data says so, a lighter-top grey gradient otherwise
            want = "%s_%02X%02X%02X" % ((ref.get("Material"),) + tuple(ref.get("Color", (0, 0, 0))))
            if entry["materials"] and entry["materials"][0].split(".")[0] != want:
                out["problems"].append(f"{ob.name}: material {entry['materials']} != {want}")
            for key in ("Variant", "NormalMap", "RoughnessMap", "MetalnessMap"):
                if ref.get(key):
                    out["problems"].append(f"{ob.name}: PBR field {key} in the JSON")
            col = me.color_attributes.get("Col") or (me.color_attributes[0] if me.color_attributes else None)
            if col is not None and ref.get("VertexColors") in ("white", "multiplier"):
                greys = [d.color_srgb[0] for d in col.data] if hasattr(col.data[0], "color_srgb") else \
                        [d.color[0] for d in col.data]
                entry["vc"] = [round(min(greys), 3), round(max(greys), 3)]
                if ref["VertexColors"] == "white" and min(greys) < 0.99:
                    out["problems"].append(f"{ob.name}: vertex colours not white ({entry['vc']})")
                if ref["VertexColors"] == "multiplier" and (min(greys) < 0.3 or max(greys) > 1.0001):
                    out["problems"].append(f"{ob.name}: vertex colours out of range ({entry['vc']})")
        if ngons:
            out["problems"].append(f"{ob.name}: {ngons} non-triangle faces")
        if not me.color_attributes:
            out["problems"].append(f"{ob.name}: no vertex colours")
        out["fbx"][ob.name] = entry
    missing = [n for n in data["Meshes"] if n not in out["fbx"]]
    if missing:
        out["problems"].append(f"missing in the FBX: {missing}")
    # the .blend reopens and holds the same meshes
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "Blender", "Props", pid + ".blend"))
    names = sorted(o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(pid + "_"))
    out["blend"] = {"scenes": [s.name for s in bpy.data.scenes], "meshes": names,
                    "images": sorted(i.filepath for i in bpy.data.images)}
    if sorted(data["Meshes"]) != names:
        out["problems"].append(f".blend meshes {names} != JSON")
    missing_img = [i.filepath for i in bpy.data.images if i.filepath and not os.path.exists(bpy.path.abspath(i.filepath))]
    if missing_img:
        out["problems"].append(f".blend missing images {missing_img}")
    return out


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
print("PROPS_CHECK " + json.dumps([check(pid) for pid in args]))
