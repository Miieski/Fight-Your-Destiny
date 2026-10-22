"""Convert Agent A's tundra facet pieces (Blender_Exports/Props/facets/tundra_*.json: closed convex shells) into convex
solids (one plane set per shell) -> tools/PropsTundraBuildingsSolids.luau (the data module DevTools.PropsTundraBuildings
reads). Usage: python tools/tundra_facets_to_solids.py <project root>"""
import base64, glob, json, math, os, struct, sys

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, "tools", "PropsTundraBuildingsSolids.luau")
# the cabin's 2 roof snow pieces are not used (the cabin was approved as built before the facets came: its own caps)
files = sorted(f for f in glob.glob(os.path.join(ROOT, "Blender_Exports", "Props", "facets", "tundra_*.json")) if "tundra_cabin__" not in f)

def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]

def newell(vs):
    n = [0.0, 0.0, 0.0]
    for i in range(len(vs)):
        p, q = vs[i], vs[(i+1) % len(vs)]
        n[0] += (p[1]-q[1])*(p[2]+q[2]); n[1] += (p[2]-q[2])*(p[0]+q[0]); n[2] += (p[0]-q[0])*(p[1]+q[1])
    l = math.sqrt(dot(n, n))
    return None if l < 1e-9 else (n[0]/l, n[1]/l, n[2]/l)

def key(v): return (round(v[0], 3), round(v[1], 3), round(v[2], 3))

pieces = []
for f in files:
    d = json.load(open(f))
    name = os.path.basename(f)[:-5]
    faces = d["faces"]
    # connected shells (union-find over shared vertices)
    parent = list(range(len(faces)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    owner = {}
    for i, fc in enumerate(faces):
        for v in fc["v"]:
            k = key(v)
            if k in owner:
                a, b = find(i), find(owner[k])
                if a != b: parent[a] = b
            else:
                owner[k] = i
    shells = {}
    for i in range(len(faces)):
        shells.setdefault(find(i), []).append(faces[i])
    palette, solids = [], []
    for sh in shells.values():
        verts = [v for fc in sh for v in fc["v"]]
        c = tuple(sum(v[i] for v in verts)/len(verts) for i in range(3))
        lo = tuple(min(v[i] for v in verts) for i in range(3)); hi = tuple(max(v[i] for v in verts) for i in range(3))
        planes = []
        glass = 0
        skipped = []
        for fc in sh:
            n = newell(fc["v"])
            if not n: continue
            dd = dot(n, fc["v"][0])
            if dot(n, c) > dd:  # centroid outside -> flip
                n = (-n[0], -n[1], -n[2]); dd = -dd
            if fc.get("m") == "Glass": glass += 1
            # a face that is not a face of the shell's hull (the shell is a hair concave there: a nearly coplanar
            # rim face) would cut its own shell: skip it (its neighbours' planes cover it)
            if max(dot(n, v) - dd for v in verts) > 0.01:
                skipped.append(round(max(dot(n, v) - dd for v in verts), 3)); continue
            dup = False
            for p in planes:
                if dot(p[0], n) > 0.99995 and abs(p[1]-dd) < 0.003: dup = True; break
            if dup: continue
            col = fc["c"].upper()
            if col not in palette: palette.append(col)
            planes.append((n, dd, palette.index(col)))
        # verify convexity: every vertex inside every plane
        worst = max(dot(p[0], v) - p[1] for p in planes for v in verts)
        if worst > 0.01: print("WARN non-convex", name, worst)
        if skipped: print("skipped non-hull faces", name, skipped)
        solids.append((planes, lo, hi, 1 if glass * 2 >= len(sh) else 0))
    buf = bytearray(struct.pack("<H", len(solids)))
    nplanes = 0
    for planes, lo, hi, glass in solids:
        assert len(planes) < 256
        buf += struct.pack("<BB", len(planes), glass)
        for x in lo + hi: buf += struct.pack("<h", int(round(x*1000)))
        for n, dd, ci in planes:
            buf += struct.pack("<hhhiB", int(round(n[0]*30000)), int(round(n[1]*30000)), int(round(n[2]*30000)), int(round(dd*1000)), ci+1)
            nplanes += 1
    b64 = base64.b64encode(bytes(buf)).decode()
    lines = [b64[i:i+112] for i in range(0, len(b64), 112)]
    roots = d.get("place", {}).get("icicleRoots")
    pieces.append((name, palette, lines, len(solids), nplanes, sum(1 for s in solids if s[3]), roots))

out = []
out.append("--[[")
out.append("\tPropsTundraBuildingsSolids (dev tool data) - Agent A's tundra facet pieces (Blender_Exports/Props/facets/tundra_*.json,")
out.append("\tguide E7) rebuilt as convex solids by Agent B: every piece is made of closed convex shells, and each shell becomes the")
out.append("\tintersection of its face planes (coplanar faces merged; each plane keeps its face colour), about 2 triangles per face")
out.append("\tonce built with GeometryService. Compact form: per piece a palette and a base64 blob: the solid count (u16), then per")
out.append("\tsolid the plane count (u8), a Glass flag (u8: 1 = most of its faces are Glass, the ice), the box min / max (6 x i16,")
out.append("\t1/1000 stud), then per plane nx, ny, nz (3 x i16, 1/30000), d (i32, 1/1000 stud) and the palette index (u8).")
out.append("\tOrigins and placements: each piece's `place` in its JSON (guide E7). Source of truth: tools/PropsTundraBuildingsSolids.luau;")
out.append("\tregenerate with python tools/tundra_facets_to_solids.py <project root> when the JSONs change.")
out.append("]]")
out.append("local EncodingService = game:GetService(\"EncodingService\")")
out.append("")
out.append("local Data = {}")
out.append("")
out.append("-- { solids = { { lo, hi, glass, planes = { { nx, ny, nz, d, \"#hex\" } } } } }")
out.append("local function decode(palette: { string }, b64: string): any")
out.append("\tlocal raw = EncodingService:Base64Decode(buffer.fromstring((string.gsub(b64, \"%s\", \"\"))))")
out.append("\tlocal at = 0")
out.append("\tlocal n = buffer.readu16(raw, at)")
out.append("\tat += 2")
out.append("\tlocal solids = {}")
out.append("\tfor _ = 1, n do")
out.append("\t\tlocal count, glass = buffer.readu8(raw, at), buffer.readu8(raw, at + 1)")
out.append("\t\tat += 2")
out.append("\t\tlocal b = {}")
out.append("\t\tfor k = 1, 6 do")
out.append("\t\t\tb[k] = buffer.readi16(raw, at) / 1000")
out.append("\t\t\tat += 2")
out.append("\t\tend")
out.append("\t\tlocal planes = {}")
out.append("\t\tfor _ = 1, count do")
out.append("\t\t\tlocal nx, ny, nz = buffer.readi16(raw, at) / 30000, buffer.readi16(raw, at + 2) / 30000, buffer.readi16(raw, at + 4) / 30000")
out.append("\t\t\tlocal d = buffer.readi32(raw, at + 6) / 1000")
out.append("\t\t\tlocal c = buffer.readu8(raw, at + 10)")
out.append("\t\t\tat += 11")
out.append("\t\t\ttable.insert(planes, { nx, ny, nz, d, palette[c] })")
out.append("\t\tend")
out.append("\t\ttable.insert(solids, { lo = Vector3.new(b[1], b[2], b[3]), hi = Vector3.new(b[4], b[5], b[6]), glass = glass == 1, planes = planes })")
out.append("\tend")
out.append("\treturn { solids = solids }")
out.append("end")
for name, palette, lines, ns, npl, ng, roots in pieces:
    out.append("")
    out.append("-- %s: %d solids (%d planes, %d glass)" % (name, ns, npl, ng))
    pal = ", ".join('"#%s"' % c.lstrip("#") for c in palette)
    out.append("Data.%s = decode({ %s }, [[" % (name, pal))
    out.extend(lines)
    out.append("]])")
    if roots:
        out.append("Data.%s.icicleRoots = { %s }" % (name, ", ".join("Vector3.new(%s, %s, %s)" % tuple(repr(round(x, 3)) for x in r) for r in roots)))
out.append("")
out.append("return Data")
out.append("")
open(OUT, "w", newline="\n").write("\n".join(out))
for p in pieces: print(p[0], "solids", p[3], "planes", p[4], "glass", p[5], "roots", len(p[6] or []))
print("bytes", os.path.getsize(OUT))
