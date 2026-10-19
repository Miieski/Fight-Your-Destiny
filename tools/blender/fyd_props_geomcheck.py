"""Geometry identity check of the exported props against a snapshot of an earlier export (headless Blender 5.x):

    blender --background --factory-startup --python tools/blender/fyd_props_geomcheck.py -- <snapshot_dir> well chest

<snapshot_dir>/fbx/<id>.fbx and <snapshot_dir>/png/<id>_mesh*.png = the earlier export; the current files are
Blender_Exports/Props/<id>.fbx and Blender_Exports/Props/preview/<id>_mesh*.png.
- FBX: both files are imported into empty scenes; per object the vertex positions (local and world), the polygons
  (vertex indices in order) and the UVs of every corner must be EXACTLY equal.
- Preview PNG: per mesh the triangles as corner positions, in order, must be equal, and so must the normals and UVs
  of every corner. (The PNG splits vertices where the colour differs, so the vertex COUNT may change with new vertex
  colours while the triangles stay the same.)
The vertex colours and materials are expected to differ: the changed corners are counted, not reported as errors.
Prints GEOMCHECK <json>: per prop "identical": true / false and the differences.
"""
import glob
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import fyd_props as P  # noqa: E402


def fbx_geometry(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    bpy.context.view_layer.update()
    out = {}
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        uv = me.uv_layers[0].data if me.uv_layers else []
        col = me.color_attributes.get("Col") or (me.color_attributes[0] if me.color_attributes else None)
        out[ob.name] = {
            "local": [tuple(v.co) for v in me.vertices],
            "world": [tuple(ob.matrix_world @ v.co) for v in me.vertices],
            "polys": [tuple(p.vertices) for p in me.polygons],
            "uv": [tuple(d.uv) for d in uv],
            "col": [tuple(round(c, 4) for c in d.color[:3]) for d in col.data] if col is not None else [],
            "materials": [m.name for m in me.materials if m],
        }
    return out


def png_geometry(paths):
    out = {}
    for p in sorted(paths):
        for m in P.decode_preview_png(p)["meshes"]:
            v, n, uv, c, t = m["v"], m["n"], m["uv"], m["c"], m["t"]
            tris, norms, uvs, cols = [], [], [], []
            for k in range(0, len(t), 3):
                tris.append(tuple(tuple(v[3 * i:3 * i + 3]) for i in t[k:k + 3]))
                norms.append(tuple(tuple(n[3 * i:3 * i + 3]) for i in t[k:k + 3]))
                uvs.append(tuple(tuple(uv[2 * i:2 * i + 2]) for i in t[k:k + 3]))
                cols.append(tuple(tuple(c[3 * i:3 * i + 3]) for i in t[k:k + 3]))
            out[m["name"]] = {"tris": tris, "normals": norms, "uv": uvs, "col": cols, "verts": len(v) // 3}
    return out


def check(snap, pid):
    res = {"id": pid, "identical": True, "problems": [], "fbx_objects": 0, "triangles": 0, "colour_corners_changed": 0,
           "materials": {}}
    old = fbx_geometry(os.path.join(snap, "fbx", pid + ".fbx"))
    new = fbx_geometry(os.path.join(P.EXPORT_DIR, pid + ".fbx"))
    if sorted(old) != sorted(new):
        res["problems"].append(f"FBX objects differ: {sorted(set(old) ^ set(new))}")
    for name in sorted(set(old) & set(new)):
        a, b = old[name], new[name]
        res["fbx_objects"] += 1
        res["triangles"] += len(b["polys"])
        for key in ("local", "world", "polys", "uv"):
            if a[key] != b[key]:
                res["problems"].append(f"FBX {name}: {key} differ ({len(a[key])} vs {len(b[key])})")
        res["colour_corners_changed"] += sum(1 for x, y in zip(a["col"], b["col"]) if x != y)
        res["materials"][name] = [a["materials"], b["materials"]]
    old_png = png_geometry(glob.glob(os.path.join(snap, "png", pid + "_mesh*.png")))
    new_png = png_geometry(glob.glob(os.path.join(P.EXPORT_DIR, "preview", pid + "_mesh*.png")))
    if sorted(old_png) != sorted(new_png):
        res["problems"].append(f"PNG meshes differ: {sorted(set(old_png) ^ set(new_png))}")
    res["png_vertices"] = [sum(m["verts"] for m in old_png.values()), sum(m["verts"] for m in new_png.values())]
    for name in sorted(set(old_png) & set(new_png)):
        for key in ("tris", "normals", "uv"):
            if old_png[name][key] != new_png[name][key]:
                res["problems"].append(f"PNG {name}: {key} differ")
    res["identical"] = not res["problems"]
    return res


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
snapshot, ids = args[0], args[1:]
print("GEOMCHECK " + json.dumps([check(snapshot, pid) for pid in ids]))
