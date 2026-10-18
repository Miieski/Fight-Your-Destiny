"""Records uploaded preview-image ids (plain Python 3, no Blender needed).

    python tools/blender/fyd_props_ids.py chest rbxassetid://91198421411858 [<propId> <id> ...]
    (several images of one prop: python ... rowboat id1,id2)

Decodes each Blender_Exports/Props/preview/<propId>_mesh*.png (checks the FYDM header and the Adler-32), then writes
Blender_Exports/Props/preview/preview_ids.json and rewrites the "Uploaded ids" table of Blender/Props/README.txt
(section 11) from it.
"""
import glob
import json
import os
import struct
import sys
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PREVIEW = os.path.join(ROOT, "Blender_Exports", "Props", "preview")
IDS = os.path.join(PREVIEW, "preview_ids.json")
README = os.path.join(ROOT, "Blender", "Props", "README.txt")
TABLE_HEAD = "    propId          asset id(s)                         size        meshes / vertices / triangles"


def decode(path):
    d = open(path, "rb").read()
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        tag, body = d[pos + 4:pos + 8], d[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h = struct.unpack(">II", body[:8])
        elif tag == b"IDAT":
            idat += body
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    prev = bytearray(stride)
    payload = bytearray()
    for r in range(h):
        f = raw[r * (stride + 1)]
        line = bytearray(raw[r * (stride + 1) + 1:(r + 1) * (stride + 1)])
        if f == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        prev = line
        for x in range(w):
            payload += line[x * 4:x * 4 + 3]
    assert payload[:4] == b"FYDM", path
    n = struct.unpack("<I", payload[4:8])[0]
    body = bytes(payload[12:12 + n])
    assert zlib.adler32(body) & 0xFFFFFFFF == struct.unpack("<I", payload[8:12])[0], f"Adler-32 {path}"
    data = json.loads(body)
    return w, h, data


def main(args):
    info = json.load(open(IDS, encoding="utf-8")) if os.path.exists(IDS) else {"props": {}}
    for pid, ids in zip(args[0::2], args[1::2]):
        files = sorted(glob.glob(os.path.join(PREVIEW, f"{pid}_mesh*.png")))
        ids = [i if i.startswith("rbxassetid://") else "rbxassetid://" + i for i in ids.split(",")]
        assert len(files) == len(ids), f"{pid}: {len(files)} images, {len(ids)} ids"
        meshes = verts = tris = 0
        sizes = []
        for f in files:
            w, h, d = decode(f)
            assert d["prop"] == pid
            sizes.append([w, h])
            meshes += len(d["meshes"])
            verts += sum(len(m["v"]) // 3 for m in d["meshes"])
            tris += sum(len(m["t"]) // 3 for m in d["meshes"])
        info["props"][pid] = {"files": [os.path.basename(f) for f in files], "assetIds": ids,
                              "size": sizes[0] if len(sizes) == 1 else sizes, "meshes": meshes, "verts": verts,
                              "tris": tris}
    info["format"] = "Blender/Props/README.txt section 11 (FYDM header, RGB payload, JSON meshes in studs, uv v=0 top, CCW)"
    with open(IDS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1)
    rows = []
    for pid, e in info["props"].items():
        size = e["size"] if isinstance(e["size"][0], int) else e["size"][0]
        rows.append("    %-15s %-35s %-11s %d / %s / %s" % (pid, ", ".join(e["assetIds"]),
                    f"{size[0]} x {size[1]}", e["meshes"], f"{e['verts']:,}", f"{e['tris']:,}"))
    text = open(README, encoding="utf-8").read().split("\n")
    i = text.index(TABLE_HEAD)
    j = i + 1
    while j < len(text) and text[j].startswith("    ") and text[j].strip():
        j += 1
    text[i + 1:j] = rows
    with open(README, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(text))
    print(json.dumps(info["props"], indent=1))


if __name__ == "__main__":
    main(sys.argv[1:])
