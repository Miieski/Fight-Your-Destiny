# Emissive masks of the V2 weapons (tools/WeaponGlow.luau). Studio's 3D Importer merges the "<id>_Glow" faces of
# each FBX into the one textured MeshPart, so the glow is given back by a SurfaceAppearance emissive mask.
# For every Blender/Weapons/<Cat>/<NN>_<id>.blend with a 2nd material: white where the glow faces are (UV space,
# same layout as the baked color map), black elsewhere, dilated a few pixels. Writes <out>/<NN>_<id>_emissive.png
# and <out>/glow_report.json (glow color, mean baked color under the mask, coverage).
#   blender -b --factory-startup --python tools/blender/weapon_emissive_masks.py -- <project root> <out folder>
# Upload the PNGs (Studio MCP upload_image), store the ids in Blender/Weapons/weapons_emissive_ids.json and
# regenerate the MASKS table of tools/WeaponGlow.luau.
import bpy, sys, os, json, glob
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
root, out_dir = args[0], args[1]
SIZE = 1024
DILATE = 3
report = {}
for path in sorted(glob.glob(os.path.join(root, "Blender", "Weapons", "*", "*.blend"))):
    name = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.wm.open_mainfile(filepath=path)
    ob = bpy.data.objects.get("Weapon")
    me = ob.data
    if len(me.materials) < 2:
        continue
    glow_mat = me.materials[1]
    uv = me.uv_layers.active.data
    me.calc_loop_triangles()
    mask = np.zeros((SIZE, SIZE), np.float32)  # row 0 = v 0 (Blender pixel order)
    n = 0
    for t in me.loop_triangles:
        if t.material_index != 1:
            continue
        n += 1
        p = np.array([uv[l].uv[:] for l in t.loops], np.float64) * SIZE - 0.5
        x0, y0 = np.floor(p.min(0)).astype(int) - 1
        x1, y1 = np.ceil(p.max(0)).astype(int) + 1
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, SIZE - 1), min(y1, SIZE - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = p
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-12:
            mask[int(round(ay)) if 0 <= ay < SIZE else y0, int(round(ax)) if 0 <= ax < SIZE else x0] = 1
            continue
        w1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / d
        w2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / d
        w3 = 1 - w1 - w2
        e = -0.5 / max(1.0, abs(d)) ** 0.5  # tiny tolerance so thin triangles still mark pixels
        inside = (w1 >= e) & (w2 >= e) & (w3 >= e)
        mask[ys[inside], xs[inside]] = 1
        # always mark the vertices too (sub-pixel slivers)
        for vx, vy in p:
            ix, iy = int(round(vx)), int(round(vy))
            if 0 <= ix < SIZE and 0 <= iy < SIZE:
                mask[iy, ix] = 1
    core = mask.copy()
    for _ in range(DILATE):
        m = mask.copy()
        m[1:, :] = np.maximum(m[1:, :], mask[:-1, :]); m[:-1, :] = np.maximum(m[:-1, :], mask[1:, :])
        m[:, 1:] = np.maximum(m[:, 1:], mask[:, :-1]); m[:, :-1] = np.maximum(m[:, :-1], mask[:, 1:])
        mask = m
    # mean baked color under the core mask
    col = next((im for im in bpy.data.images if im.name.endswith("_color")), None)
    mean = None
    if col is not None and col.size[0] == SIZE:
        px = np.empty(SIZE * SIZE * 4, np.float32)
        col.pixels.foreach_get(px)
        px = px.reshape(SIZE, SIZE, 4)
        sel = core > 0
        if sel.any():
            mean = [round(float(v), 3) for v in px[sel][:, :3].mean(0)]
    img = bpy.data.images.new(name + "_emissive", SIZE, SIZE, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((SIZE, SIZE, 4), np.float32)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = mask
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(out_dir, name + "_emissive.png")
    img.file_format = "PNG"
    img.save()
    emit = None
    bsdf = glow_mat.node_tree.nodes.get("Principled BSDF") if glow_mat.node_tree else None
    if bsdf:
        emit = [round(v, 3) for v in bsdf.inputs["Emission Color"].default_value[:3]]
    report[name] = {"glow_tris": n, "coverage": round(float(core.mean()), 5), "emit": emit, "baked_mean": mean,
                    "color_image": col.name if col else None}
with open(os.path.join(out_dir, "glow_report.json"), "w") as f:
    json.dump(report, f, indent=1)
print("RESULT", len(report))
