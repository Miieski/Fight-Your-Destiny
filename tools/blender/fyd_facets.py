"""Fight Your Destiny - FACET DATA of the organic accents of props batch 2 (owner task 2026-10-19).

Studio cannot import FBX here, so Agent B builds these few organic pieces from their faces: each face becomes a thin
part (a rectangle = 1 Part, any other quad / triangle = wedges), extruded INWARD by the face's thickness t, then
unioned. Everything else of batch 2 is built from parts with the fountain / well recipe (docs/prop_texture_guide.md
section A). Budget: at most 300 faces per piece; rectangles are flagged "rect": true.

    blender --background --factory-startup --python tools/blender/fyd_facets.py [-- rebirth_altar ship golem canyon_gate red_rock monuments props jungle jungle_gates jungle_ruins jungle_totems jungle_decor jungle_nature batch4
    tundra_buildings tundra_gates tundra_monuments tundra_props]

Writes Blender_Exports/Props/facets/<object>__<piece>.json and Previews/Props/batch2_<object>_facets.png.
JSON: {"object", "piece", "units": "studs", "origin": "<what (0,0,0) is>", "axes", "size" [x, y, z] (bounding box),
"bounds" {min, max}, "place" (suggested placement, optional), "notes", "faces": [{"v": [[x,y,z] x3|x4], "c": "#RRGGBB",
"m": "SmoothPlastic|Neon|Glass", "t": thickness, "rect": true?}]}. Roblox space: x right, y up, front -Z; every face
is counter-clockwise seen from OUTSIDE (normal = (v1-v0) x (v2-v0) points out); quads are planar.
Sizes come from today's parts (read from BackUP_Files/old_props_2026-10-19_pre_batch2/*.rbxm).
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import fyd_props as P  # noqa: E402

OUT_DIR = os.path.join(P.ROOT, "Blender_Exports", "Props", "facets")
MAX_FACES = 300


def tone(hex_color, k):
    h = hex_color.lstrip("#")
    rgb = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(c * k)))) for c in rgb)


def mix(hex_color, other, k):
    a = [int(hex_color.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    b = [int(other.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(int(round(x + (y - x) * k)) for x, y in zip(a, b))


def newell(pts):
    n = Vector((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class Piece:
    def __init__(self, obj, name, origin, axes="Roblox space: x right, y up, front -Z", notes="", place=None):
        self.obj, self.name, self.origin, self.axes, self.notes, self.place = obj, name, origin, axes, notes, place
        self.faces = []

    def face(self, pts, color, m="SmoothPlastic", t=0.3, out=None):
        """pts: 3 or 4 points; out: a direction (Vector) the face must look toward, or None = keep the order."""
        pts = [Vector(p) for p in pts]
        if out is not None and newell(pts).dot(Vector(out)) < 0:
            pts.reverse()
        self.faces.append({"v": pts, "c": color, "m": m, "t": t})

    def quad_or_tris(self, pts, color, m="SmoothPlastic", t=0.3, out=None):
        """A planar quad as one face; a non-planar one as 2 triangles."""
        pts = [Vector(p) for p in pts]
        n = newell(pts).normalized()
        if abs((pts[3] - pts[0]).dot(n)) < 1e-4 and abs((pts[2] - pts[0]).dot(n)) < 1e-4:
            self.face(pts, color, m, t, out)
        else:
            self.face(pts[:3], color, m, t, out)
            self.face([pts[0], pts[2], pts[3]], color, m, t, out)

    def mirrored_z(self, start=0):
        """Adds the mirror image (z -> -z) of the faces from index `start` (winding reversed: still outward)."""
        for f in list(self.faces[start:]):
            pts = [Vector((p.x, p.y, -p.z)) for p in reversed(f["v"])]
            self.faces.append(dict(f, v=pts))

    def data(self):
        faces = []
        for f in self.faces:
            pts = f["v"]
            e = {"v": [[round(c + 0.0, 3) for c in p] for p in pts], "c": f["c"], "m": f["m"], "t": round(f["t"], 3)}
            if len(pts) == 4:
                a, b, c, d = pts
                if abs((b - a).dot(d - a)) < 1e-3 * (b - a).length * (d - a).length and (c - b - (d - a)).length < 2e-3:
                    e["rect"] = True
            faces.append(e)
        allp = [p for f in self.faces for p in f["v"]]
        lo = [round(min(p[i] for p in allp), 3) for i in range(3)]
        hi = [round(max(p[i] for p in allp), 3) for i in range(3)]
        d = {"object": self.obj, "piece": self.name, "units": "studs", "origin": self.origin, "axes": self.axes,
             "size": [round(hi[i] - lo[i], 3) for i in range(3)], "bounds": {"min": lo, "max": hi},
             "faceCount": len(faces), "rectCount": sum(1 for f in faces if f.get("rect")),
             "notes": self.notes, "faces": faces}
        if self.place:
            d["place"] = self.place
        return d

    def check(self):
        """Faces <= MAX_FACES, quads planar, no degenerate face, closed convex pieces point outward."""
        problems = []
        if len(self.faces) > MAX_FACES:
            problems.append(f"{len(self.faces)} faces > {MAX_FACES}")
        for i, f in enumerate(self.faces):
            pts = f["v"]
            n = newell(pts)
            if n.length < 1e-6:
                problems.append(f"face {i} degenerate")
                continue
            if len(pts) == 4 and abs((pts[3] - pts[0]).dot(n.normalized())) > 2e-3:
                problems.append(f"face {i} quad not planar")
        return problems


# ------------------------------------------------------------------------------------------------
# geometry helpers
# ------------------------------------------------------------------------------------------------
def prism_crystal(pc, base_y, r, body_h, shoulder_h, tip_h, color, segs=6, twist=0.0, tip_off=(0.0, 0.0),
                  shoulder_k=0.5, base_k=0.85, t=0.3, flat_base=True, light=0.0):
    """Faceted crystal standing on (0, base_y, 0): a short tapered foot (radius base_k*r), a straight `segs`-sided
    prism body (rectangles), a shoulder band of trapezoids up to radius shoulder_k*r, then a pointed tip (triangles,
    apex offset by tip_off). Faces alternate two tones (facet read on Neon)."""
    angs = [math.radians(twist + 360.0 * k / segs) for k in range(segs)]

    def ring(rad, y, off=(0.0, 0.0)):
        return [Vector((rad * math.cos(a) + off[0], y, rad * math.sin(a) + off[1])) for a in angs]

    y1 = base_y + 0.12 * body_h
    y2 = base_y + body_h
    y3 = y2 + shoulder_h
    foot, b0, b1 = ring(base_k * r, base_y), ring(r, y1), ring(r, y2)
    sh = ring(shoulder_k * r, y3, (tip_off[0] * 0.4, tip_off[1] * 0.4))
    apex = Vector((tip_off[0], y3 + tip_h, tip_off[1]))
    center = Vector((0, base_y + body_h / 2, 0))
    lighter = mix(color, "#FFFFFF", 0.18 + light)
    for k in range(segs):
        j = (k + 1) % segs
        c_side = color if k % 2 == 0 else mix(color, "#FFFFFF", 0.08 + light)
        out = ((b0[k] + b0[j]) / 2 - Vector((0, y1, 0)))
        pc.face([foot[k], foot[j], b0[j], b0[k]], tone(c_side, 0.9), "Neon", t, out)
        pc.face([b0[k], b0[j], b1[j], b1[k]], c_side, "Neon", t, out)
        pc.quad_or_tris([b1[k], b1[j], sh[j], sh[k]], lighter if k % 2 == 0 else c_side, "Neon", t, out)
        pc.face([sh[k], sh[j], apex], mix(color, "#FFFFFF", 0.3 + light), "Neon", t,
                ((sh[k] + sh[j]) / 2 - Vector((0, y3, 0))) + Vector((0, 0.6, 0)))
    if flat_base:  # the foot's underside (sits on the pedestal)
        polygon_fill(pc, foot, tone(color, 0.8), "Neon", t, Vector((0, -1, 0)))
    return center


def polygon_fill(pc, ring_pts, color, m, t, normal):
    """A convex planar polygon (ring order) as quads in a fan + one triangle when needed."""
    n = len(ring_pts)
    k = 1
    while k < n - 1:
        if k + 2 < n:
            pc.face([ring_pts[0], ring_pts[k], ring_pts[k + 1], ring_pts[k + 2]], color, m, t, normal)
            k += 2
        else:
            pc.face([ring_pts[0], ring_pts[k], ring_pts[k + 1]], color, m, t, normal)
            k += 1


def boulder(pc, size, seed, color, n_pts=18, t=0.35, jit=(0.82, 1.08), top_cut=1.0):
    """Chunky low-poly boulder: convex hull of jittered points on a squashed sphere, flat bottom at y 0, faces
    tinted with the height gradient (0.82 bottom -> 1.0 top) and 3 tone steps."""
    rng = random.Random(seed)
    sx, sy, sz = size
    pts = []
    for i in range(n_pts):
        # Fibonacci sphere points, jittered, upper 85 % of the sphere
        yy = 1 - 1.85 * (i + 0.5) / n_pts
        rr = math.sqrt(max(0.0, 1 - yy * yy))
        a = i * math.pi * (3 - math.sqrt(5)) + rng.uniform(-0.25, 0.25)
        j = rng.uniform(*jit)
        y = min((yy + 0.85) / 1.85 * sy * rng.uniform(0.92, 1.04), top_cut * sy)   # top_cut < 1: a flat top facet
        pts.append(Vector((math.cos(a) * rr * j * sx / 2, y, math.sin(a) * rr * j * sz / 2)))
    for k in range(7):  # flat footprint (y = 0)
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        pts.append(Vector((math.cos(a) * sx * 0.42 * rng.uniform(0.85, 1.0), 0.0, math.sin(a) * sz * 0.42 * rng.uniform(0.85, 1.0))))
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bm.normal_update()
    center = sum(pts, Vector()) / len(pts)
    steps = (1.0, 0.93, 0.86)
    ymax = max(p.y for p in pts)
    for f in bm.faces:
        ring_pts = [l.vert.co.copy() for l in f.loops]
        c = sum(ring_pts, Vector()) / len(ring_pts)
        h = max(0.0, min(1.0, c.y / ymax))
        g = 0.82 + 0.18 * (h * h * (3 - 2 * h))
        col = tone(color, g * steps[rng.randrange(3)])
        out = c - center
        if len(ring_pts) <= 4:
            pc.quad_or_tris(ring_pts, col, "SmoothPlastic", t, out) if len(ring_pts) == 4 else pc.face(ring_pts, col,
                                                                                                     "SmoothPlastic", t, out)
        else:
            polygon_fill(pc, ring_pts, col, "SmoothPlastic", t, out)
    bm.free()


# ------------------------------------------------------------------------------------------------
# 16 REBIRTH ALTAR + 02 PORTAL GEM
# today (BackUP 16_rebirth_altar.rbxm, Station_RebirthAltar, relative to the stall pivot): Pedestal cyl 3 x 7 dia at
# y 7.5 (top 9.0), gold PedestalRing 0.8 x 8.4 dia at y 9.3 (top 9.7); main Crystal MeshPart 6.4 x 16 x 5.6 at
# (0, 21, 0) yaw 20 (y 13 .. 29), Neon 150,110,255 (renders pink); 2 small crystals 2.6 x 6.5 x 2.3 at (-3.4, 13.6, 1.0)
# and 2.4 x 6.0 x 2.1 at (3.2, 13.2, -1.2), tilted ~15 deg; 4 PillarCrystals 1.5 x 3.2 x 1.3 on the pillar caps.
# PortalFrame Accent: 1 x 1 x 0.5 Neon 255,201,60 turned 45 deg on each pillar front (z -2.2).
# ------------------------------------------------------------------------------------------------
CRYSTAL = "#966EFF"   # Hub Portal 150,110,255 = today's crystal colour (Neon: it renders pink-lavender)


def rebirth_altar():
    pieces = []
    main = Piece("rebirth_altar", "crystal_main",
                 "the centre of the crystal's FLAT BASE (put it on the top of the gold PedestalRing, y 9.7 in the "
                 "altar: today's crystal spans y 13 .. 29, the new one 9.7 .. 29.2 so it stands on the pedestal)",
                 notes="6-sided crystal, vertex radius 3.2 (6.4 x 5.5 like today), foot 0.12 of the body tapered to "
                       "85 %, body to y 13.6, shoulder band to y 16.6, apex 19.5 (offset 0.35 toward -x for a less "
                       "perfect look). Neon #966EFF = today's colour (renders pink); facets alternate +8 % white, "
                       "shoulder +18 %, tip +30 %.",
                 place={"relativeTo": "the altar pivot (Station_RebirthAltar / Hub.RebirthAltar, the Pedestal's axis)",
                        "position": [0, 9.7, 0], "orientation": [0, 20, 0]})
    prism_crystal(main, 0.0, 3.2, 13.6, 3.0, 2.9, CRYSTAL, segs=6, twist=0.0, tip_off=(-0.35, 0.2), t=0.35)
    pieces.append(main)
    smalls = [("crystal_small_1", 1.3, 5.6, 1.4, 1.2, [-3.3, 9.6, 1.1], [14, 0, 22], 15),
              ("crystal_small_2", 1.2, 5.0, 1.3, 1.1, [3.2, 9.6, -1.2], [-6, 40, -20], 75),
              ("crystal_small_3", 0.95, 3.6, 1.0, 0.9, [0.9, 9.6, 3.1], [-24, 0, -8], 40)]
    for name, r, body, sh, tip, pos, ori, twist in smalls:
        pc = Piece("rebirth_altar", name, "the centre of the crystal's flat base (its foot goes 0.3 into the gold "
                                          "ring / pedestal top)",
                   notes=f"6-sided crystal, vertex radius {r}, total height {round(body + sh + tip, 2)}; "
                         "lean it outward from the main crystal (orientation below)",
                   place={"relativeTo": "the altar pivot", "position": pos, "orientation": ori})
        prism_crystal(pc, 0.0, r, body, sh, tip, CRYSTAL, segs=6, twist=twist, tip_off=(0.12, -0.08), t=0.2, light=0.04)
        pieces.append(pc)
    # portal gem: a small brilliant on a flat back, facing -Z
    gem = Piece("portal", "portal_gem", "the centre of the gem's FLAT BACK, which lies on the pillar's front face; "
                                        "the gem looks toward -Z (out of the pillar)",
                notes="8-sided brilliant crown: 1.0 across, 0.38 deep (girdle 0.12, crown to the table at r 0.28). "
                      "Neon #FFC93C like today's Accent; scale uniformly for another size.",
                place={"relativeTo": "each PortalFrame Pillar (3 x 13 x 4.2)", "position": [0, 0.5, -2.1],
                       "orientation": [0, 0, 22.5], "replaces": "the Accent part (1 x 1 x 0.5 turned 45 deg)"})
    R, RT, ZG, ZT = 0.5, 0.28, -0.12, -0.38
    angs = [math.radians(22.5 + 45 * k) for k in range(8)]
    back = [Vector((R * math.cos(a), R * math.sin(a), 0.0)) for a in angs]
    gir = [Vector((R * math.cos(a), R * math.sin(a), ZG)) for a in angs]
    tab = [Vector((RT * math.cos(a), RT * math.sin(a), ZT)) for a in angs]
    gold = "#FFC93C"
    for k in range(8):
        j = (k + 1) % 8
        mid = (back[k] + back[j]) / 2
        gem.face([back[k], back[j], gir[j], gir[k]], tone(gold, 0.92), "Neon", 0.1, Vector((mid.x, mid.y, 0)))
        gem.face([gir[k], gir[j], tab[j], tab[k]], gold if k % 2 else mix(gold, "#FFFFFF", 0.15), "Neon", 0.1,
                 Vector((mid.x, mid.y, -0.6)))
    polygon_fill(gem, tab, mix(gold, "#FFFFFF", 0.3), "Neon", 0.1, Vector((0, 0, -1)))
    polygon_fill(gem, back, tone(gold, 0.85), "Neon", 0.1, Vector((0, 0, 1)))
    pieces.append(gem)
    return pieces


# ------------------------------------------------------------------------------------------------
# 15 SHIP (PirateShip_Wreck) - bow and stern hull sections + torn sails
# today, in the frame of the part HullLower (78 x 8 x 16, x toward the bow): HullLower x -39 .. 39, y -4 .. 4, z +-8,
# HullFlare wedges widen it to +-11.5 at y 4; HullUpper 82 x 8 x 23 (x -41 .. 41, y 4 .. 12); Deck y 12.4; Bulwarks
# y 12.4 .. 15.4 at z +-11.5, RailCap red 1.5 x 0.7 at y 15.6, red Stripe 1.2 at y 10.6; bow = 2 wedge levels to a
# point at x 53 (y -4) / 59 (y 12); SternCastle 24 x 9 x 24.6 at (-30, 17, 0) (x -42 .. -18, y 12.5 .. 21.5), Rudder
# at x -41.6; foremast at x 26, yard 30 long at y 37; main TornSail 8 x 26 at (25.2, 32.6, 0).
# ------------------------------------------------------------------------------------------------
DARK, MID, LIGHT, RED = "#703E26", "#A86238", "#D6965C", "#D4343C"
STRAKES = [(-4.0, -2.0, DARK), (-2.0, 0.0, DARK), (0.0, 2.0, DARK), (2.0, 4.0, DARK), (4.0, 6.0, MID), (6.0, 8.0, MID),
           (8.0, 10.0, MID), (10.0, 11.2, RED), (11.2, 12.4, MID), (12.4, 13.9, MID), (13.9, 15.4, MID)]
LAP, OVER, PLANK_T = 0.15, 0.2, 0.35
SHIP_ORIGIN = ("the centre of the part HullLower (78 x 8 x 16); axes = HullLower's own axes: +x toward the bow, +y "
               "up, z across (place every ship piece with HullLower.CFrame * CFrame.new(x, y, z))")


def ship_half_width(y):
    """Hull half-width of the straight mid hull at height y (today: HullFlare wedge 8 -> 11.5, then vertical)."""
    if y <= 4.0:
        return 8.0 + 3.5 * (y + 4.0) / 8.0
    return 11.5


def strake_rects(pc, plan, y_rows, stations, x_of, ext_first=0.0, ext_last=0.0, tones=None, rng=None):
    """Clinker strakes on the starboard side (z > 0): for each strake (y_bot, y_top, colour) and each station
    segment, one RECTANGLE whose top edge lies on the hull line at y_top and whose lower edge reaches 0.2 below
    y_bot, 0.15 proud of the hull line there (the strake below tucks under it). plan(s, y) -> half-width,
    x_of(s, y) -> x. Rectangles are extended by 0.12 along the run at inner joints (no gaps)."""
    for k, (yb, yt, col) in enumerate(y_rows):
        ylow = yb - (OVER if k > 0 else 0.0)
        top = [Vector((x_of(s, yt), yt, plan(s, yt))) for s in stations]
        bot = [Vector((x_of(s, ylow), ylow, plan(s, ylow) + (LAP if k > 0 else 0.0))) for s in stations]
        for i in range(len(stations) - 1):
            a, b = top[i], top[i + 1]
            e = (b - a)
            if e.length < 1e-4:
                continue
            en = e.normalized()
            v = (bot[i] + bot[i + 1]) / 2 - (a + b) / 2
            v = v - en * v.dot(en)
            e0 = ext_first if i == 0 else 0.12
            e1 = ext_last if i == len(stations) - 2 else 0.12
            a2, b2 = a - en * e0, b + en * e1
            out = Vector((-e.z, 0, e.x))
            if out.z < 0:
                out = -out
            c = col if tones is None else tone(col, tones[rng.randrange(len(tones))])
            pc.face([a2, b2, b2 + v, a2 + v], c, "SmoothPlastic", PLANK_T, out)


def planks_along_x(pc, y, x0, plan_end, z_max, width, color, normal, t, rng, tones=(1.0, 0.95, 0.9)):
    """Deck / bottom planks running along x from x0 to plan_end(z) (the hull line at the plank's middle), starboard."""
    z = 0.0
    while z < z_max - 1e-6:
        z1 = min(z + width, z_max)
        x1 = plan_end((z + z1) / 2)
        if abs(x1 - x0) > 0.05:
            pts = [Vector((x0, y, z)), Vector((x1, y, z)), Vector((x1, y, z1)), Vector((x0, y, z1))]
            pc.face(pts, tone(color, tones[rng.randrange(len(tones))]), "SmoothPlastic", t, normal)
        z = z1


def ship():
    pieces = []
    rng = random.Random(15)
    # ---------------- bow: x 39 -> the stem (x 53 at the keel, 59.6 at the rail) ----------------
    X0 = 39.0

    def tip_x(y):
        return 53.0 + 6.6 * (y + 4.0) / 19.4

    def s_plan(s, y):
        return ship_half_width(y) * (1.0 - s ** 2.2) ** 0.85

    def x_bow(s, y):
        return X0 + s * (tip_x(y) - X0)

    stations = [0.0, 0.3, 0.55, 0.75, 0.88, 0.96, 1.0]
    bow = Piece("ship", "bow_hull", SHIP_ORIGIN,
                notes="Curved bow from x 39 (where the straight mid hull ends) to the stem. 11 clinker strakes per "
                      "side, each one rectangle per station segment, its lower edge 0.15 proud over the strake below "
                      "(overlap 0.2): the stepped rowboat look. Strakes (y bottom .. top, colour) at the joint x 39, "
                      "half-width there: -4..-2 / -2..0 / 0..2 / 2..4 dark #703E26 (half-width 8.0 at y -4 -> 11.5 at "
                      "y 4, today's HullFlare), 4..6 / 6..8 / 8..10 mid #A86238, 10..11.2 red #D4343C (today's "
                      "stripe), 11.2..12.4 mid, bulwark 12.4..13.9 / 13.9..15.4 mid (half-width 11.5): build the mid "
                      "hull planks with the same rows so they line up. Deck planks (light #D6965C, 1.5 wide, top at "
                      "y 12.4, t 0.8), bottom planks at y -4, red rail cap 1.5 x 0.7 on top (y 15.4 .. 16.1), stem post "
                      "1.0 wide x 1.2 deep along the bow tip (dark). Plank thickness t 0.35 (extruded inward).",
                place={"relativeTo": "HullLower", "position": [0, 0, 0], "orientation": [0, 0, 0],
                       "replaces": "BowLower x2, BowUpper x2, BowDeck x2 (the wedges), the 2 angled bow Bulwarks"})
    start = len(bow.faces)
    strake_rects(bow, s_plan, STRAKES, stations, x_bow, ext_first=0.0, ext_last=0.0, tones=(1.0, 0.95, 0.9), rng=rng)
    # deck (top at 12.4) and bottom (y -4), starboard; planks end where the hull line reaches the plank's middle

    def end_at(y):
        def f(z):
            w = ship_half_width(y)
            if z >= w:
                return X0
            s = (1 - (z / w) ** (1 / 0.85)) ** (1 / 2.2)
            return x_bow(s, y)
        return f

    planks_along_x(bow, 12.4, X0, end_at(12.4), ship_half_width(12.4), 1.5, LIGHT, Vector((0, 1, 0)), 0.8, rng)
    planks_along_x(bow, -4.0, X0, end_at(-4.0), ship_half_width(-4.0), 1.6, DARK, Vector((0, -1, 0)), 0.35, rng)
    # red rail cap on the bulwark top, per segment, extended to close the joints
    rail = [Vector((x_bow(s, 15.4), 15.4, s_plan(s, 15.4))) for s in stations]
    for i in range(len(rail) - 1):
        a, b = rail[i], rail[i + 1]
        en = (b - a).normalized()
        across = Vector((0, 1, 0)).cross(en).normalized() * 0.75
        e0, e1 = (0.0 if i == 0 else 0.4), (0.3 if i == len(rail) - 2 else 0.4)
        a2, b2 = a - en * e0 + Vector((0, 0.7, 0)), b + en * e1 + Vector((0, 0.7, 0))
        bow.face([a2 - across, b2 - across, b2 + across, a2 + across], RED, "SmoothPlastic", 0.7, Vector((0, 1, 0)))
    bow.mirrored_z(start)
    # stem post along the tip line (centreline), facing forward
    p0, p1 = Vector((tip_x(-4.0) + 0.2, -4.0, 0.0)), Vector((tip_x(15.4) + 0.6, 16.1, 0.0))
    d = (p1 - p0).normalized()
    fwd = Vector((d.y, -d.x, 0.0))
    bow.face([p0 + Vector((0, 0, -0.5)), p1 + Vector((0, 0, -0.5)), p1 + Vector((0, 0, 0.5)), p0 + Vector((0, 0, 0.5))],
             DARK, "SmoothPlastic", 1.2, fwd)
    pieces.append(bow)

    # ---------------- stern: x -39 -> the raked transom (x -42 at the deck, -40 at the keel) ----------------
    X0S = -39.0

    def transom_x(y):
        return -42.0 + 0.12 * (12.4 - y)

    def st_plan(s, y):
        return ship_half_width(y) * (1.0 - 0.15 * s * s)

    def x_st(s, y):
        return X0S + s * (transom_x(y) - X0S)

    stern = Piece("ship", "stern_hull", SHIP_ORIGIN,
                  notes="Curved stern from x -39 (where the straight mid hull ends) to a raked transom (x -42 at the "
                        "deck, -40 at the keel), the sides narrowing to 85 %. The same 11 strake rows as the bow up to "
                        "the deck (y 12.4: the SternCastle sits on top); transom = horizontal planks on the same rows "
                        "(rectangles, full width), bottom planks at y -4. Plank t 0.35.",
                  place={"relativeTo": "HullLower", "position": [0, 0, 0], "orientation": [0, 0, 0]})
    rows = [r for r in STRAKES if r[1] <= 12.4 + 1e-6]
    start = len(stern.faces)
    strake_rects(stern, st_plan, rows, [0.0, 0.5, 1.0], x_st, ext_first=0.0, ext_last=0.12, tones=(1.0, 0.95, 0.9),
                 rng=rng)

    # bottom planks: the sides narrow to 85 % at the transom, so every plank runs to the transom bottom
    planks_along_x(stern, -4.0, X0S, lambda z: transom_x(-4.0), 0.85 * ship_half_width(-4.0) + LAP, 1.6, DARK,
                   Vector((0, -1, 0)), 0.35, rng)
    stern.mirrored_z(start)
    # transom: one full-width horizontal plank per strake row, in the raked plane, facing aft (-x)
    for k, (yb, yt, col) in enumerate(rows):
        ylow = yb - (OVER if k > 0 else 0.0)
        w = 0.85 * ship_half_width(yt) + LAP + 0.05
        pts = [Vector((transom_x(yt) - 0.02, yt, -w)), Vector((transom_x(yt) - 0.02, yt, w)),
               Vector((transom_x(ylow) - 0.02 - LAP * 0.5, ylow, w)), Vector((transom_x(ylow) - 0.02 - LAP * 0.5, ylow, -w))]
        # make it a rectangle in the raked plane: same z for top and bottom, the slant only in x / y
        stern.face(pts, tone(col, (1.0, 0.95, 0.9)[rng.randrange(3)]), "SmoothPlastic", PLANK_T, Vector((-1, 0, 0)))
    pieces.append(stern)

    # ---------------- torn sails ----------------
    def hanging_sail(pc, width, height, cols, belly, rips, holes, tatters, colors, seed):
        """Sail hanging from its top edge (the yard) along local x, belly toward -z; vertical column strips
        (rectangles in the vertical plane of each chord), torn lower edge, holes, triangular tatters."""
        r = random.Random(seed)
        xs = [-width / 2 + width * i / cols for i in range(cols + 1)]

        def zb(x):
            return -belly * (1 - (2 * x / width) ** 2)

        for i in range(cols):
            xa, xb = xs[i], xs[i + 1]
            col = colors[i % len(colors)]
            ybot = -height + rips[i]
            pa, pb = Vector((xa, 0, zb(xa))), Vector((xb, 0, zb(xb)))
            out = Vector((0, 0, -1))   # the belly / front side
            spans = [(0.0, ybot)]
            if i in holes:
                h0, h1 = holes[i]
                spans = [(0.0, h0), (h1, ybot)] if h1 > ybot else [(0.0, h0)]
            for y0, y1 in spans:
                pc.face([Vector((xa, y0, zb(xa))), Vector((xb, y0, zb(xb))), Vector((xb, y1, zb(xb))),
                         Vector((xa, y1, zb(xa)))], col, "SmoothPlastic", 0.2, out)
            if i in tatters:
                drop, frac = tatters[i]
                drop = min(drop, rips[i] + 0.8)   # no tooth below height + 0.8
                tx = xa + (xb - xa) * frac
                pc.face([Vector((xa, ybot, zb(xa))), Vector((xb, ybot, zb(xb))), Vector((tx, ybot - drop, zb(tx)))],
                        col, "SmoothPlastic", 0.2, out)

    sail_axes = "sail space: x along the yard (width), y up, the sail's belly / front toward -Z"
    main = Piece("ship", "sail_main", "the centre of the sail's TOP edge (where it is tied under the yard)",
                 axes=sail_axes,
                 notes="26 wide x 9 tall (teeth down to 9.8), belly 0.9, 12 vertical cloth panels alternating cream "
                       "#E8E2D0 / white #F5F6FA, zig-zag torn lower edge (every panel 0.4 .. 2.6 shorter, ending in a "
                       "1.0 .. 2.6 triangular tooth), 2 holes. t 0.2.",
                 place={"relativeTo": "HullLower", "position": [25.2, 36.6, 0], "orientation": [0, -90, 0],
                        "replaces": "the TornSail 0.4 x 8 x 26 under the foremast yard"})
    # zig-zag torn edge like today's sail: every panel ends in a triangular tooth, the panels at varied lengths
    rips = [2.2, 1.0, 1.8, 0.6, 2.4, 1.2, 0.4, 2.0, 1.4, 0.8, 2.6, 1.6]
    teeth = {i: (d, f) for i, (d, f) in enumerate([(1.6, 0.4), (2.2, 0.6), (1.2, 0.3), (2.4, 0.55), (1.0, 0.7),
                                                     (1.9, 0.35), (2.6, 0.5), (1.3, 0.65), (2.0, 0.4), (2.5, 0.6),
                                                     (1.1, 0.45), (1.8, 0.5)])}
    hanging_sail(main, 26.0, 9.0, 12, 0.9, rips, {3: (-2.6, -4.0), 8: (-3.6, -4.8)}, teeth, ["#E8E2D0", "#F5F6FA"], 151)
    pieces.append(main)
    rem = Piece("ship", "sail_remnant", "the centre of the remnant's TOP edge (tied under a yard)", axes=sail_axes,
                notes="6 wide x 9.5 tall remnant, 3 cream panels, very ragged (lower edge 2 .. 5 shorter), a hole and "
                      "3 tatters. t 0.2.",
                place={"relativeTo": "HullLower", "position": [25.2, 28.4, -7.5], "orientation": [0, -90, 0],
                       "replaces": "2-3 of the small TornSail pieces (5 x 11, 6 x 9, 6 x 7)"})
    hanging_sail(rem, 6.0, 9.5, 3, 0.35, [2.0, 4.8, 3.1], {0: (-3.2, -4.4)}, {0: (1.3, 0.5), 1: (0.8, 0.3), 2: (1.6, 0.6)},
                 ["#E8E2D0", "#DCD4BE"], 152)
    pieces.append(rem)
    # fallen sail draped over a rail / the fallen yard: panel A hangs outboard (-z), panel B lies inboard (+z)
    fall = Piece("ship", "sail_fallen", "the centre of the FOLD line (lay it along the rail cap or the fallen yard)",
                 axes="x along the fold line, y up; panel A hangs toward -Z (outboard), panel B lies toward +Z",
                 notes="13 wide; panel A 6.5 long hanging at 75 deg, panel B 5 long at 20 deg below horizontal; "
                       "5 panels per side alternating cream / white, ragged far edges. t 0.2.",
                 place={"relativeTo": "HullLower", "position": [17.0, 16.1, -11.5], "orientation": [0, 0, 0],
                        "replaces": "the fallen TornSail 10 x 13 over the port side"})
    r = random.Random(153)
    cols = 5
    xs = [-6.5 + 13.0 * i / cols for i in range(cols + 1)]
    for side, length, ang in ((-1, 6.5, 75.0), (1, 5.0, 20.0)):
        dvec = Vector((0, -math.sin(math.radians(ang)), side * math.cos(math.radians(ang))))
        out = Vector((0, math.cos(math.radians(ang)), side * math.sin(math.radians(ang))))
        for i in range(cols):
            L = length - r.uniform(0.0, 1.8)
            col = ("#E8E2D0", "#F5F6FA")[i % 2]
            a, b = Vector((xs[i], 0, 0)), Vector((xs[i + 1], 0, 0))
            fall.face([a, b, b + dvec * L, a + dvec * L], col, "SmoothPlastic", 0.2, out)
            if i % 2 == 0:
                tx = xs[i] + (xs[i + 1] - xs[i]) * r.uniform(0.3, 0.7)
                fall.face([a + dvec * L, b + dvec * L, Vector((tx, 0, 0)) + dvec * (L + r.uniform(0.7, 1.4))], col,
                          "SmoothPlastic", 0.2, out)
    pieces.append(fall)
    return pieces


# ------------------------------------------------------------------------------------------------
# 06 GOLEM (Golem_Statue) - rubble, shoulder boulders, chest core
# today, relative to the Plinth centre (cyl 1.5 x 36 dia, top y 0.75): Rubble MeshParts 6 x 3 x 5.5 at (-10, 1.95, -9)
# and 4.5 x 4.4 x 4.5 at (11, 2.35, 8) (CaveRock 96,92,110); Shoulder MeshParts 12 x 9.5 x 12 at (+-13, 28.95, 0.5)
# yaw +-40; ChestPlate 15 x 8.5 x 1.2 at (0, 24.05, -7.3) tilted 6.9 deg, its Rune diamond 2.6 x 2.6 Neon at z -8.0.
# ------------------------------------------------------------------------------------------------
CAVE = "#605C6E"


def golem():
    pieces = []
    for name, size, seed, pos, ori, n in (("rubble_1", (6.0, 3.0, 5.5), 61, [-10.0, 0.45, -9.0], [0, 80, 0], 16),
                                          ("rubble_2", (4.5, 4.4, 4.5), 62, [11.0, 0.45, 8.0], [0, 20, 0], 15),
                                          ("rubble_3", (3.2, 2.2, 3.0), 63, [7.5, 0.45, -10.5], [0, -35, 0], 12)):
        pc = Piece("golem", name, "the centre of the boulder's FLAT BOTTOM (y 0); sink it 0.3 into the plinth top",
                   notes=f"low-poly boulder {size[0]} x {size[1]} x {size[2]} (today's rubble size), CaveRock #605C6E "
                         "with the height gradient (x0.82 bottom .. x1.0 top) and 3 tone steps per facet. t 0.35.",
                   place={"relativeTo": "the golem Plinth centre", "position": pos, "orientation": ori})
        boulder(pc, size, seed, CAVE, n_pts=n)
        pieces.append(pc)
    for name, sign in (("shoulder_L", -1), ("shoulder_R", 1)):
        pc = Piece("golem", name, "the centre of the boulder's FLAT BOTTOM (it sits on the upper arm / torso corner)",
                   notes="shoulder boulder 12 x 9.5 x 12 (today's Shoulder size), CaveRock #605C6E, gradient + tones; "
                         "_L and _R are mirror images. t 0.4.",
                   place={"relativeTo": "the golem Plinth centre", "position": [sign * 13.0, 24.2, 0.5],
                          "orientation": [0, sign * 40, sign * -8]})
        boulder(pc, (12.0, 9.5, 12.0), 64, CAVE, n_pts=13, t=0.4, jit=(0.72, 1.12), top_cut=0.86)
        if sign < 0:
            for f in pc.faces:
                f["v"] = [Vector((-p.x, p.y, p.z)) for p in reversed(f["v"])]
        pieces.append(pc)
    core = Piece("golem", "core_crystal", "the centre of the crystal's FLAT BACK, which lies on the ChestPlate's front "
                                          "face; it looks toward -Z",
                 notes="faceted chest core 3.0 wide x 4.0 tall, 1.3 proud: hexagonal outline (points up / down), "
                       "girdle 0.3, crown facets to a table at 50 %. Neon #5FD4FF (lighter facets toward the table). "
                       "Replaces the 2.6 x 2.6 Rune diamond in the middle of the chest. t 0.2.",
                 place={"relativeTo": "the golem Plinth centre", "position": [0, 24.12, -7.89], "orientation": [6.9, 0, 0],
                        "replaces": "the centre Rune (2.6 x 2.6 x 0.5 turned 45 deg)"})
    cyan = "#5FD4FF"
    outline = [(0.0, 2.0), (1.5, 0.9), (1.5, -0.9), (0.0, -2.0), (-1.5, -0.9), (-1.5, 0.9)]
    back = [Vector((x, y, 0.0)) for x, y in outline]
    gir = [Vector((x, y, -0.3)) for x, y in outline]
    tab = [Vector((x * 0.5, y * 0.5, -1.3)) for x, y in outline]
    for k in range(6):
        j = (k + 1) % 6
        mid = (back[k] + back[j]) / 2
        core.face([back[k], back[j], gir[j], gir[k]], tone(cyan, 0.9), "Neon", 0.2, Vector((mid.x, mid.y, 0)))
        core.face([gir[k], gir[j], tab[j], tab[k]], mix(cyan, "#FFFFFF", 0.1 if k % 2 else 0.2), "Neon", 0.2,
                  Vector((mid.x, mid.y, -1.0)))
    polygon_fill(core, tab, mix(cyan, "#FFFFFF", 0.35), "Neon", 0.2, Vector((0, 0, -1)))
    polygon_fill(core, back, tone(cyan, 0.8), "Neon", 0.2, Vector((0, 0, 1)))
    pieces.append(core)
    return pieces


# ------------------------------------------------------------------------------------------------
# outputs: JSON + preview
# ------------------------------------------------------------------------------------------------
def write_piece(pc):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{pc.obj}__{pc.name}.json")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(pc.data(), f, indent=1)
    return path


def euler_matrix(ori):
    """Roblox Orientation (degrees, applied Z, then X, then Y) -> 3x3 (Roblox space)."""
    from mathutils import Matrix
    x, y, z = (math.radians(a) for a in ori)
    return Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z")


def piece_object(pc, col, offset=Vector((0, 0, 0)), rot=None, scale=1.0):
    """Blender object of a piece (Roblox studs -> Blender metres), solidified inward by the mean thickness."""
    verts, faces, colors = [], [], []
    for f in pc.faces:
        idx = []
        for p in f["v"]:
            q = (rot @ p if rot is not None else p) * scale + offset
            verts.append(tuple(P.R2B @ q * P.STUD))
            idx.append(len(verts) - 1)
        faces.append(idx)
        colors.append(f["c"])
    me = bpy.data.meshes.new(f"FAC_{pc.obj}_{pc.name}")
    me.from_pydata(verts, [], faces)
    me.update()
    mats = {}
    for c in sorted(set(colors)):
        m = bpy.data.materials.new(f"FAC_{c}")
        P._try(lambda: setattr(m, "use_nodes", True))
        b = m.node_tree.nodes.get("Principled BSDF")
        lin = tuple(P.srgb_to_linear(int(c[i:i + 2], 16) / 255) for i in (1, 3, 5))
        b.inputs["Base Color"].default_value = lin + (1,)
        b.inputs["Roughness"].default_value = 0.6
        if any(f["m"] == "Neon" and f["c"] == c for f in pc.faces):
            b.inputs["Emission Color"].default_value = lin + (1,)
            b.inputs["Emission Strength"].default_value = 1.5
        me.materials.append(m)
        mats[c] = len(me.materials) - 1
    for poly, c in zip(me.polygons, colors):
        poly.material_index = mats[c]
    ob = bpy.data.objects.new(me.name, me)
    col.objects.link(ob)
    sol = ob.modifiers.new("t", "SOLIDIFY")
    sol.thickness = sum(f["t"] for f in pc.faces) / len(pc.faces) * P.STUD * scale
    sol.offset = -1.0
    return ob


def context_boxes(boxes, col):
    class _C:
        context = boxes
    return P.build_context(_C, col)


def render_sheet(name, groups, views, out):
    """groups: list of (objects) rendered separately (one cell each), each from the given views; one PNG."""
    scn = bpy.context.scene
    cells = []
    tmp = os.path.join(P.PREVIEW_DIR, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    for gi, (objs, gviews) in enumerate(groups):
        for o in bpy.context.scene.objects:
            if o.type == "MESH" and o.name != "PropGround":
                o.hide_render = o not in objs
        for vi, (az, el) in enumerate(gviews):
            P._fit_camera(scn.camera, objs, az, el, margin=0.08)
            path = os.path.join(tmp, f"{name}_{gi}_{vi}.png")
            scn.render.filepath = path
            bpy.ops.render.render(write_still=True)
            px = P._load_rgba(path)
            a = px[..., 3:4]
            cells.append(px[..., :3] * a + P._sky(px.shape[0], px.shape[1]) * (1 - a))
            os.remove(path)
    gap = 8
    h = max(c.shape[0] for c in cells)
    width = sum(c.shape[1] for c in cells) + gap * (len(cells) + 1)
    sheet = np.ones((h + 2 * gap, width, 3)) * 0.18
    x = gap
    for c in cells:
        sheet[gap:gap + c.shape[0], x:x + c.shape[1]] = c
        x += c.shape[1] + gap
    P.T.write_png(out, P.T.to_u8(sheet))
    for o in bpy.context.scene.objects:
        o.hide_render = False
    return out


def clear_scene():
    scn = P.scene()
    P.setup_rig(scn)
    P.clear_subject(scn)
    for o in list(bpy.data.objects):
        if o.name.startswith("FAC_") or o.name.startswith("CTX_"):
            bpy.data.objects.remove(o, do_unlink=True)
    return scn


def placed(pc, col, scale=1.0):
    pl = pc.place or {}
    rot = euler_matrix(pl.get("orientation", [0, 0, 0]))
    return piece_object(pc, col, Vector(pl.get("position", [0, 0, 0])), rot, scale)


def preview_altar(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    ctx = context_boxes([((0, 7.5, 0), (7.0, 3.0, 7.0), "#686E7C", (0, 0, 0)), ((0, 9.3, 0), (8.4, 0.8, 8.4), "#FFC93C", (0, 0, 0)),
                         ((0, 3.0, 0), (20, 2.0, 20), "#969CA8", (0, 0, 0))], col)
    crystal_objs = [placed(pc, col) for pc in pieces if pc.obj == "rebirth_altar"]
    gem_pc = [pc for pc in pieces if pc.name == "portal_gem"][0]
    gem_ctx = context_boxes([((60, 0, 1.05), (3.0, 6.0, 2.1), "#969CA8", (0, 0, 0))], col)
    gem = piece_object(gem_pc, col, Vector((60, 0.5, 0)), None, 1.0)
    out = os.path.join(P.PREVIEW_DIR, "batch2_rebirth_altar_facets.png")
    return render_sheet("altar", [(crystal_objs + ctx, [(-25, 12), (150, 25)]), ([gem] + gem_ctx, [(-20, 15)])],
                        None, out)


def preview_ship(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    ctx = context_boxes([((0, 0, 0), (78, 8, 16), "#703E26", (0, 0, 0)), ((0, 8, 0), (82, 8, 23), "#A86238", (0, 0, 0)),
                         ((0, 12.4, 0), (82, 0.8, 22), "#D6965C", (0, 0, 0)), ((-30, 17, 0), (24, 9, 24.6), "#A86238", (0, 0, 0)),
                         ((26, 32.4, 0), (2.8, 40, 2.8), "#703E26", (0, 0, 0)), ((26, 37, 0), (1.5, 1.5, 30), "#703E26", (0, 0, 0)),
                         ((34, 14.6, 0), (14, 4, 23), "#A86238", (0, 0, 0)), ((2, 22, 0), (3.2, 20, 3.2), "#703E26", (0, 0, 0))], col)
    objs = [placed(pc, col) for pc in pieces]
    hull = [o for o, pc in zip(objs, pieces) if "hull" in pc.name]
    out = os.path.join(P.PREVIEW_DIR, "batch2_ship_facets.png")
    return render_sheet("ship", [(objs + ctx, [(-60, 14), (120, 18)]), (hull, [(-75, 10)])], None, out)


def preview_golem(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    g = "#969CA8"
    d = "#686E7C"
    ctx = context_boxes([((0, 0, 0), (36, 1.5, 36), d, (0, 0, 0)), ((-5.5, 2.25, -1), (8.5, 3, 11), d, (0, 0, 0)),
                         ((5.5, 2.25, -1), (8.5, 3, 11), d, (0, 0, 0)), ((-5.5, 8.25, 0), (7, 10, 8), g, (0, 0, 0)),
                         ((5.5, 8.25, 0), (7, 10, 8), g, (0, 0, 0)), ((0, 14.75, 0), (17, 5, 9.5), d, (0, 0, 0)),
                         ((0, 23.25, -0.6), (21, 12, 12.5), g, (-6.9, 0, 0)), ((0, 24.05, -7.3), (15, 8.5, 1.2), d, (-6.9, 0, 0)),
                         ((-14.8, 22.25, 0.5), (6.5, 10, 7), g, (0, 0, 8)), ((14.8, 22.25, 0.5), (6.5, 10, 7), g, (0, 0, -8)),
                         ((-16.2, 11.25, -1.2), (8.5, 12, 9), d, (0, 0, 0)), ((16.2, 11.25, -1.2), (8.5, 12, 9), d, (0, 0, 0)),
                         ((0, 32.15, -3), (7.5, 7, 7.5), g, (-20, 0, 0))], col)
    objs = [placed(pc, col) for pc in pieces]
    out = os.path.join(P.PREVIEW_DIR, "batch2_golem_facets.png")
    return render_sheet("golem", [(objs + ctx, [(-25, 12), (155, 20)])], None, out)


# ------------------------------------------------------------------------------------------------
# DESERT 03 CANYON BARRICADE GATE (MapAssets.Gates.Gate_Desert_3; game Zones.Desert.Desert_3.Gate)
# today (kit space = the gate's origin, opening centre at ground level, Barrier 24 x 16 x 2 at (0, 8, 0)): each side
# a Pillar of 6 stacked boxes (inner face x +-13.0 at every height, outer edge 27.9 -> 22.4, depth 16.9 -> 11.4, y 0 ..
# 38) + a tilted PillarCap 6 x 5 x 7 at (+-19, 39.5, 0.5); further out 4 SideRocks at x +-36, z 1.5 (15 x 8 x 14,
# 14 x 4 x 13, 13 x 7 x 12, 12 x 4 x 11; y 0 .. 23). Beam 30 x 1.8 x 1.8 at y 21.1 and the Barrier anchors (x +-12.6)
# go into the pillars' inner faces. Colours = strata: red #C55438 / orange #E88251 / dark #9C4032 ...
# ------------------------------------------------------------------------------------------------
GATE_ORIGIN = ("the gate model's origin (Gate_Desert_3 kit space: the centre of the opening at ground level; the "
               "Barrier is at (0, 8, 0)); place the piece at the gate pivot with no offset")


def _octagon(xmin, xmax, zmin, zmax, ch):
    """Rectangle with chamfered corners, ccw seen from above (+y): ch = chamfers (x0z0, x1z0, x1z1, x0z1)."""
    a, b, c, d = ch
    return [Vector((xmin + a, 0, zmin)), Vector((xmax - b, 0, zmin)), Vector((xmax, 0, zmin + b)),
            Vector((xmax, 0, zmax - c)), Vector((xmax - c, 0, zmax)), Vector((xmin + d, 0, zmax)),
            Vector((xmin, 0, zmax - d)), Vector((xmin, 0, zmin + a))]


def strata_column(pc, layers, rng, inner_x=None, cracks=4, height=40.0):
    """Layered canyon rock: one vertical-sided slab per stratum (chamfered rectangle in plan: every side face is a
    RECTANGLE), soft layers recessed (erosion grooves), a lit top ledge per layer, undersides where a layer overhangs
    the one below, thin dark crack strips on some faces. layers: (y0, y1, colour, xmin, xmax, zmin, zmax, recess).
    inner_x: the face that must stay flat at that x (the gate opening)."""
    prev = None
    faces_for_cracks = []
    for k, (y0, y1, col, xmin, xmax, zmin, zmax, rec) in enumerate(layers):
        if inner_x is not None and inner_x < 0:      # left rock: inner face = xmax
            xmax2, xmin2 = min(xmax, inner_x) - min(rec, 0.25), xmin + rec
        elif inner_x is not None:                     # right rock: inner face = xmin
            xmin2, xmax2 = max(xmin, inner_x) + min(rec, 0.25), xmax - rec
        else:
            xmin2, xmax2 = xmin + rec, xmax - rec
        zmin2, zmax2 = zmin + rec, zmax - rec
        w, d = xmax2 - xmin2, zmax2 - zmin2
        big = [rng.uniform(0.12, 0.26) * min(w, d) for _ in range(4)]
        if inner_x is not None:                       # small chamfers on the two corners of the inner face
            if inner_x < 0:
                big[1], big[2] = rng.uniform(0.2, 0.45), rng.uniform(0.2, 0.45)
            else:
                big[0], big[3] = rng.uniform(0.2, 0.45), rng.uniform(0.2, 0.45)
        poly = _octagon(xmin2, xmax2, zmin2, zmax2, big)
        lo = [p + Vector((0, y0, 0)) for p in poly]
        hi = [p + Vector((0, y1, 0)) for p in poly]
        t = max(0.0, min(1.0, (y0 + y1) / 2 / height))
        g = 0.88 + 0.12 * (t * t * (3 - 2 * t))
        cx, cz = (xmin2 + xmax2) / 2, (zmin2 + zmax2) / 2
        for i in range(8):
            j = (i + 1) % 8
            c = tone(col, g * rng.choice((1.0, 0.97, 0.94)))
            m = (lo[i] + lo[j]) / 2
            out = Vector((m.x - cx, 0, m.z - cz))
            pc.face([lo[i], lo[j], hi[j], hi[i]], c, "SmoothPlastic", 0.6, out)
            if (lo[j] - lo[i]).length > 3.0 and y1 - y0 >= 2.0:
                faces_for_cracks.append((lo[i], lo[j], y0, y1, out.normalized(), col))
        polygon_fill(pc, hi, tone(col, min(1.08, g * 1.06)), "SmoothPlastic", 0.6, Vector((0, 1, 0)))
        if prev is not None:
            pxmin, pxmax, pzmin, pzmax = prev
            if xmin2 < pxmin - 1e-3 or xmax2 > pxmax + 1e-3 or zmin2 < pzmin - 1e-3 or zmax2 > pzmax + 1e-3:
                polygon_fill(pc, lo, tone(col, 0.75), "SmoothPlastic", 0.6, Vector((0, -1, 0)))
        prev = (xmin2, xmax2, zmin2, zmax2)
    # cracks: a vertical zig-zag of 2 thin dark strips, 0.03 in front of a long face
    rng.shuffle(faces_for_cracks)
    for a, b, y0, y1, n, col in faces_for_cracks[:cracks]:
        e = (b - a).normalized()
        base = a + (b - a) * rng.uniform(0.3, 0.7) + n * 0.03
        mid_y = y0 + (y1 - y0) * rng.uniform(0.4, 0.6)
        pts = [Vector((base.x, y1 - 0.05, base.z)), Vector((base.x, mid_y, base.z)) + e * rng.uniform(-0.6, 0.6),
               Vector((base.x, y0 + 0.4, base.z)) + e * rng.uniform(-0.4, 0.4)]
        for p0, p1 in zip(pts, pts[1:]):
            wv = e * 0.14
            pc.face([p0 - wv, p0 + wv, p1 + wv, p1 - wv], tone(col, 0.5), "SmoothPlastic", 0.05, n)


def tilted_cap(pc, cx, cz, y0, size, tilt, col, rng):
    """A tilted rock block on top (today's PillarCap 6 x 5 x 7): chamfered plan, vertical sides, a sloped planar top."""
    sx, sy, sz = size
    poly = _octagon(cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2, [rng.uniform(0.6, 1.4) for _ in range(4)])
    ax, az = tilt
    lo = [p + Vector((0, y0, 0)) for p in poly]
    hi = [Vector((p.x, y0 + sy + ax * (p.x - cx) + az * (p.z - cz), p.z)) for p in poly]
    for i in range(8):
        j = (i + 1) % 8
        m = (lo[i] + lo[j]) / 2
        pc.face([lo[i], lo[j], hi[j], hi[i]], tone(col, rng.choice((1.0, 0.96, 0.92))), "SmoothPlastic", 0.6,
                Vector((m.x - cx, 0, m.z - cz)))
    polygon_fill(pc, hi, tone(col, 1.06), "SmoothPlastic", 0.6, Vector((0, 1, 0)))


def canyon_gate():
    pieces = []
    rng = random.Random(403)
    # pillar strata (y0, y1, colour, xmin, xmax, zmin, zmax, recess) from today's 6 boxes, thick layers split into bands
    L = [(0.0, 3.0, "#B84D33", -27.9, -13.0, -8.45, 8.45, 0.0), (3.0, 6.2, "#C55438", -27.9, -13.0, -8.45, 8.45, 0.35),
         (6.2, 9.0, "#C55438", -27.9, -13.0, -8.45, 8.45, 0.1), (9.0, 13.0, "#E88251", -26.8, -13.0, -7.9, 7.9, 0.6),
         (13.0, 16.5, "#C55438", -25.7, -13.0, -7.35, 7.35, 0.0), (16.5, 19.5, "#B84D33", -25.7, -13.0, -7.35, 7.35, 0.4),
         (19.5, 22.0, "#C55438", -25.7, -13.0, -7.35, 7.35, 0.1), (22.0, 26.0, "#9C4032", -24.6, -13.0, -6.8, 6.8, 0.5),
         (26.0, 29.0, "#C15237", -23.5, -13.0, -6.25, 6.25, 0.0), (29.0, 31.8, "#B04A32", -23.5, -13.0, -6.25, 6.25, 0.35),
         (31.8, 34.0, "#C15237", -23.5, -13.0, -6.25, 6.25, 0.1), (34.0, 38.0, "#E78151", -22.4, -13.0, -5.7, 5.7, 0.5)]
    R = [(0.0, 3.0, "#BA4F35", 13.0, 27.9, -8.45, 8.45, 0.0), (3.0, 6.0, "#C95639", 13.0, 27.9, -8.45, 8.45, 0.3),
         (6.0, 9.0, "#C95639", 13.0, 27.9, -8.45, 8.45, 0.05), (9.0, 13.0, "#E48050", 13.0, 26.8, -7.9, 7.9, 0.6),
         (13.0, 15.8, "#C05236", 13.0, 25.7, -7.35, 7.35, 0.0), (15.8, 19.0, "#B04A32", 13.0, 25.7, -7.35, 7.35, 0.45),
         (19.0, 22.0, "#C05236", 13.0, 25.7, -7.35, 7.35, 0.1), (22.0, 26.0, "#963E30", 13.0, 24.6, -6.8, 6.8, 0.5),
         (26.0, 28.6, "#C35337", 13.0, 23.5, -6.25, 6.25, 0.0), (28.6, 31.4, "#B24B33", 13.0, 23.5, -6.25, 6.25, 0.3),
         (31.4, 34.0, "#C35337", 13.0, 23.5, -6.25, 6.25, 0.1), (34.0, 38.0, "#E07D4E", 13.0, 22.4, -5.7, 5.7, 0.5)]
    note = ("layered canyon rock replacing today's 6 stacked Pillar boxes + PillarCap; same bounding box (outer edge "
            "27.9 at the ground -> 22.4 at y 38, depth 16.9 -> 11.4, cap to y ~42); the INNER FACE STAYS FLAT AT "
            "x = +-13.0 (the opening stays 26 wide: Barrier 24 wide, anchors at +-12.6, the Beam ends at +-15 inside the "
            "rock). 12 strata (red / dark red / orange like today's boxes), vertical rectangle sides (1 part each), "
            "soft layers recessed 0.3-0.6 (erosion grooves), a lit ledge on each step, 5 dark crack strips, a tilted "
            "cap block. t 0.6.")
    for name, layers, inner, cap_x, tilt in (("pillar_L", L, -13.0, -19.0, (0.12, -0.08)),
                                             ("pillar_R", R, 13.0, 19.0, (-0.12, -0.08))):
        pc = Piece("canyon_gate", name, GATE_ORIGIN, notes=note,
                   place={"relativeTo": "the Gate_Desert_3 / Desert_3.Gate pivot", "position": [0, 0, 0],
                          "orientation": [0, 0, 0], "replaces": "the 6 Pillar boxes and the PillarCap of this side"})
        strata_column(pc, layers, rng, inner_x=inner, cracks=5, height=42.0)
        tilted_cap(pc, cap_x, 0.5, 38.0, (6.0, 3.6, 7.0), tilt, "#E48050", rng)
        pieces.append(pc)
    for name, sx, cols in (("side_rock_L", -1, ("#BE5136", "#E58150", "#BD5136", "#913C2E")),
                           ("side_rock_R", 1, ("#C85539", "#E68150", "#BE5136", "#923C2E"))):
        c0 = 36.0 * sx
        layers = [(0.0, 4.0, tone(cols[0], 0.95), c0 - 7.5, c0 + 7.5, -5.5, 8.5, 0.0),
                  (4.0, 8.0, cols[0], c0 - 7.5, c0 + 7.5, -5.5, 8.5, 0.3),
                  (8.0, 12.0, cols[1], c0 - 7.0, c0 + 7.0, -5.0, 8.0, 0.6),
                  (12.0, 15.5, cols[2], c0 - 6.5, c0 + 6.5, -4.5, 7.5, 0.0),
                  (15.5, 19.0, tone(cols[2], 0.93), c0 - 6.5, c0 + 6.5, -4.5, 7.5, 0.35),
                  (19.0, 23.0, cols[3], c0 - 6.0, c0 + 6.0, -4.0, 7.0, 0.3)]
        pc = Piece("canyon_gate", name, GATE_ORIGIN,
                   notes="layered rock replacing today's 4 SideRock boxes of this side (centre x +-36, z 1.5; 15 x 23 x "
                         "14, 12 wide at the top); its inner edge stays at |x| >= 28.5 (0.6 from the pillar). 6 strata, "
                         "erosion grooves, ledges, 3 cracks. t 0.6.",
                   place={"relativeTo": "the Gate_Desert_3 / Desert_3.Gate pivot", "position": [0, 0, 0],
                          "orientation": [0, 0, 0], "replaces": "the 4 SideRock boxes of this side"})
        strata_column(pc, layers, rng, inner_x=None, cracks=3, height=42.0)
        pieces.append(pc)
    return pieces


def preview_canyon(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    ctx = context_boxes([((0, 8, 0.3), (24, 15, 0.9), "#A86238", (0, 0, 0)), ((0, 21.1, 0), (30, 1.8, 1.8), "#703E26", (0, 0, 0)),
                         ((0, 8, -0.8), (26, 2.2, 0.7), "#D6965C", (0, 0, 26.6)),
                         ((0, 8, -1.1), (26, 2.2, 0.7), "#D6965C", (0, 0, -26.6)),
                         ((0, 18.4, -1.5), (12, 4, 0.5), "#D6965C", (0, 0, 0))], col)
    objs = [placed(pc, col) for pc in pieces]
    out = os.path.join(P.PREVIEW_DIR, "desert_canyon_gate_facets.png")
    return render_sheet("canyon", [(objs + ctx, [(-20, 10), (150, 20)])], None, out)


# ------------------------------------------------------------------------------------------------
# DESERT 01 RED ROCK STACK (MapAssets.Desert.Mesa_Strata_A) + the Desert_3 HOODOOS
# today's parts (BackUP_Files/old_props_2026-10-20_pre_desert_nature/*.rbxm), relative to the BASE CENTRE of the
# model's bounding box (42.44 x 54.0 x 24.69; y 0 = the bottom): (name, centre, size, yaw deg, colour)
# ------------------------------------------------------------------------------------------------
MESA_PARTS = [
    ("Talus", [9.89, 2.5, -4.27], [10.0, 5.0, 6.0], -10.0, "#C45438"),
    ("Talus", [-8.11, 3.5, -4.77], [14.0, 7.0, 8.0], 8.0, "#E48050"),
    ("Strata", [-9.01, 4.5, -0.13], [21.38, 9.0, 17.73], 3.0, "#C25337"),
    ("Strata", [9.61, 4.5, -0.84], [21.84, 9.0, 19.14], 4.3, "#CA5639"),
    ("Strata", [-8.91, 11.0, -1.11], [21.13, 4.0, 20.69], -3.4, "#DF7D4E"),
    ("Strata", [8.88, 11.0, -1.29], [22.9, 4.0, 21.04], 2.8, "#E17E4F"),
    ("Strata", [-9.26, 18.5, 1.31], [21.75, 11.0, 16.85], -0.6, "#C95639"),
    ("Strata", [9.04, 18.5, 1.23], [21.7, 11.0, 17.0], -3.5, "#CA5639"),
    ("Strata", [-9.68, 26.0, 0.43], [21.53, 4.0, 19.6], -2.0, "#953D2F"),
    ("Strata", [9.22, 26.0, 1.42], [21.05, 4.0, 17.63], 4.3, "#9A3F31"),
    ("Strata", [-9.2, 33.5, 2.3], [22.99, 11.0, 16.87], -3.8, "#C25337"),
    ("Strata", [9.07, 33.5, 3.55], [22.55, 11.0, 14.37], 0.2, "#BC5035"),
    ("Strata", [-8.91, 41.0, 2.09], [22.19, 4.0, 18.29], -4.2, "#DF7D4E"),
    ("Strata", [9.31, 41.0, 3.05], [21.55, 4.0, 16.37], -2.9, "#E37F4F"),
    ("Strata", [-9.24, 46.5, 5.06], [22.11, 7.0, 13.34], -3.0, "#C75E3C"),
    ("Strata", [8.95, 46.5, 4.19], [21.57, 7.0, 15.08], 3.3, "#D1623F"),
    ("Cap", [-11.11, 51.0, 5.23], [9.0, 6.0, 8.0], 20.0, "#C45438"),
    ("Cap", [7.89, 51.0, 6.23], [7.0, 4.0, 7.0], -15.0, "#E48050"),
]
# the smallest hoodoo (Desert_3 Formations; the 5 hoodoos are this one at uniform scale 1.0 / 1.1 / 1.3 / 1.5 / 1.7)
HOODOO_PARTS_A = [
    ("Strata", [0.27, 2.6, 0.3], [7.2, 5.2, 6.48], 4.3, "#C75538"),
    ("Strata", [0.06, 6.4, -0.19], [7.36, 2.4, 6.62], 55.0, "#DF7D4E"),
    ("Strata", [0.01, 10.2, -0.11], [5.6, 5.2, 5.04], 39.6, "#BC5035"),
    ("Strata", [-0.39, 14.0, -0.51], [5.52, 2.4, 4.97], 11.1, "#963E30"),
    ("Strata", [-0.14, 17.8, -0.05], [4.0, 5.2, 3.6], 63.7, "#C65438"),
    ("Cap", [0.0, 21.8, 0.0], [8.4, 2.8, 7.6], 48.5, "#963E30"),
]
# the second hoodoo's yaws and colours on the same sizes (variant B)
HOODOO_PARTS_B = [
    ("Strata", [0.18, 2.6, 0.4], [7.2, 5.2, 6.48], 62.0, "#C25337"),
    ("Strata", [0.06, 6.4, -0.4], [7.36, 2.4, 6.62], 28.2, "#E78251"),
    ("Strata", [-0.19, 10.2, -0.39], [5.6, 5.2, 5.04], 58.6, "#C85539"),
    ("Strata", [0.44, 14.0, -0.23], [5.52, 2.4, 4.97], 12.8, "#943D2F"),
    ("Strata", [-0.44, 17.8, 0.33], [4.0, 5.2, 3.6], 42.5, "#C65438"),
    ("Cap", [0.12, 21.8, -0.18], [8.4, 2.8, 7.6], 36.8, "#963E30"),
]
ROCK_ORIGIN = ("the BASE CENTRE of today's model bounding box (centre in x / z, y 0 = the bottom), front -Z = the "
               "model's front; place at the model pivot (if the pivot is not at the base centre, offset by the "
               "difference)")


def _yaw(p, c, deg):
    """Roblox yaw about +Y through c (x' = cos x + sin z, z' = -sin x + cos z)."""
    a = math.radians(deg)
    dx, dz = p.x - c.x, p.z - c.z
    return Vector((c.x + math.cos(a) * dx + math.sin(a) * dz, p.y, c.z - math.sin(a) * dx + math.cos(a) * dz))


def _inside(poly, p):
    """Point (x, z) inside a convex ccw-from-above polygon (all at the same y)."""
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        if (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x) > 1e-6:
            return False
    return True


def strata_bands(pc, bands, rng, height, vcracks=2, hcracks=3, t=0.6):
    """Faceted strata bands: bands = (y0, y1, colour, centre (x, z), size (sx, sz), yaw, recess, chip). Each band a
    vertical-sided chamfered rectangle (chipped corners) turned by its yaw: rectangle side faces, a lit top ledge,
    an underside where it overhangs the band below, horizontal and vertical crack strips on long faces."""
    prev = None
    long_faces = []
    for (y0, y1, col, cxz, sxz, yaw, rec, chip) in bands:
        c = Vector((cxz[0], 0, cxz[1]))
        sx, sz = sxz[0] - 2 * rec, sxz[1] - 2 * rec
        ch = [rng.uniform(chip[0], chip[1]) * min(sx, sz) for _ in range(4)]
        poly = [_yaw(p, c, yaw) for p in _octagon(c.x - sx / 2, c.x + sx / 2, c.z - sz / 2, c.z + sz / 2, ch)]
        lo = [p + Vector((0, y0, 0)) for p in poly]
        hi = [p + Vector((0, y1, 0)) for p in poly]
        tt = max(0.0, min(1.0, (y0 + y1) / 2 / height))
        g = 0.88 + 0.12 * (tt * tt * (3 - 2 * tt))
        for i in range(8):
            j = (i + 1) % 8
            m = (lo[i] + lo[j]) / 2
            out = Vector((m.x - c.x, 0, m.z - c.z))
            pc.face([lo[i], lo[j], hi[j], hi[i]], tone(col, g * rng.choice((1.0, 0.97, 0.94))), "SmoothPlastic", t, out)
            if (lo[j] - lo[i]).length > 4.0:
                long_faces.append((lo[i], lo[j], y0, y1, out.normalized(), col))
        polygon_fill(pc, hi, tone(col, min(1.1, g * 1.07)), "SmoothPlastic", t, Vector((0, 1, 0)))
        if prev is not None and any(not _inside(prev, p) for p in poly):
            polygon_fill(pc, lo, tone(col, 0.72), "SmoothPlastic", t, Vector((0, -1, 0)))
        prev = poly
    rng.shuffle(long_faces)
    k = 0
    for a, b, y0, y1, n, col in long_faces:      # horizontal cracks on tall bands
        if k >= hcracks or y1 - y0 < 3.0:
            continue
        e = (b - a)
        u0, u1 = rng.uniform(0.1, 0.3), rng.uniform(0.65, 0.9)
        y = y0 + (y1 - y0) * rng.uniform(0.35, 0.65)
        p0, p1 = a + e * u0 + n * 0.03, a + e * u1 + n * 0.03
        pc.face([Vector((p0.x, y - 0.12, p0.z)), Vector((p1.x, y - 0.12, p1.z)), Vector((p1.x, y + 0.12, p1.z)),
                 Vector((p0.x, y + 0.12, p0.z))], tone(col, 0.5), "SmoothPlastic", 0.05, n)
        k += 1
    k = 0
    for a, b, y0, y1, n, col in reversed(long_faces):   # vertical zig-zag cracks
        if k >= vcracks or y1 - y0 < 2.5:
            continue
        e = (b - a).normalized()
        base = a + (b - a) * rng.uniform(0.25, 0.75) + n * 0.03
        mid_y = y0 + (y1 - y0) * rng.uniform(0.4, 0.6)
        pts = [Vector((base.x, y1 - 0.05, base.z)), Vector((base.x, mid_y, base.z)) + e * rng.uniform(-0.7, 0.7),
               Vector((base.x, y0 + 0.3, base.z)) + e * rng.uniform(-0.5, 0.5)]
        for q0, q1 in zip(pts, pts[1:]):
            wv = e * 0.14
            pc.face([q0 - wv, q0 + wv, q1 + wv, q1 - wv], tone(col, 0.5), "SmoothPlastic", 0.05, n)
        k += 1


def split_bands(parts, rng, max_band=4.5, chip=(0.06, 0.14), recess_soft=0.45):
    """Today's strata boxes -> bands: thick layers split into 2-3 sub-bands (alternating tone, a thin recessed
    erosion notch between them), thin (soft, orange) layers recessed; the envelope stays within 0.5 of the box."""
    bands = []
    for name, cpos, size, yaw, col in parts:
        if name != "Strata":
            continue
        y0, y1 = cpos[1] - size[1] / 2, cpos[1] + size[1] / 2
        h = y1 - y0
        n = max(1, int(math.ceil(h / max_band)))
        soft = h <= 4.0
        cuts = [y0 + h * i / n + (rng.uniform(-0.4, 0.4) if 0 < i < n else 0.0) for i in range(n + 1)]
        for i in range(n):
            a, b = cuts[i], cuts[i + 1]
            rec = recess_soft if soft else (0.0 if i % 2 == 0 else 0.3)
            ctone = tone(col, 1.0 if i % 2 == 0 else 0.94)
            if i > 0:   # erosion notch: a 0.5-tall band recessed a further 0.5 at the joint
                bands.append((a, a + 0.5, tone(col, 0.85), (cpos[0], cpos[2]), (size[0], size[2]), yaw, rec + 0.5, chip))
                a += 0.5
            bands.append((a, b, ctone, (cpos[0], cpos[2]), (size[0], size[2]), yaw, rec, chip))
    return bands


def cap_rock(pc, cpos, size, yaw, col, rng, tilt=(0.1, -0.06), t=0.6):
    """A cap block: chipped plan turned by yaw, two tiers (a 60 % lower tier and a smaller sloped top tier)."""
    c = Vector((cpos[0], 0, cpos[2]))
    y0 = cpos[1] - size[1] / 2
    sx, sy, sz = size
    tiers = [(y0, y0 + sy * 0.6, sx, sz, False), (y0 + sy * 0.6, y0 + sy, sx * 0.82, sz * 0.8, True)]
    for (a, b, wx, wz, sloped) in tiers:
        poly = [_yaw(p, c, yaw) for p in _octagon(c.x - wx / 2, c.x + wx / 2, c.z - wz / 2, c.z + wz / 2,
                                                  [rng.uniform(0.08, 0.16) * min(wx, wz) for _ in range(4)])]
        lo = [p + Vector((0, a, 0)) for p in poly]
        hi = [Vector((p.x, b + (tilt[0] * (p.x - c.x) + tilt[1] * (p.z - c.z) if sloped else 0.0), p.z)) for p in poly]
        for i in range(8):
            j = (i + 1) % 8
            m = (lo[i] + lo[j]) / 2
            pc.face([lo[i], lo[j], hi[j], hi[i]], tone(col, rng.choice((1.0, 0.96, 0.92))), "SmoothPlastic", t,
                    Vector((m.x - c.x, 0, m.z - c.z)))
        polygon_fill(pc, hi, tone(col, 1.07), "SmoothPlastic", t, Vector((0, 1, 0)))


def scree_pile(pc, cpos, size, yaw, col, rng, n=9, t=0.4, reach=0.0):
    """Natural scree replacing a talus WedgePart (high at the back +z, low at the front -z): convex hull of
    jittered points on the wedge's footprint and slope, faces toned by height."""
    c = Vector((cpos[0], 0, cpos[2]))
    sx, sy, sz = size
    pts = []
    for i in range(n):
        u = (i + 0.5) / n
        x = c.x - sx / 2 + sx * u + rng.uniform(-0.3, 0.3)
        pts.append(Vector((x, 0.0, c.z - sz / 2 - reach * rng.uniform(0.7, 1.0))))           # front foot
        pts.append(Vector((x, 0.0, c.z + sz / 2 - rng.uniform(0.0, 0.4))))                    # back foot
        top = sy * (0.75 + 0.25 * math.sin(math.pi * u)) * rng.uniform(0.85, 1.0)
        pts.append(Vector((x, top, c.z + sz / 2 - rng.uniform(0.3, 1.0))))                    # back crest
        pts.append(Vector((x, top * rng.uniform(0.35, 0.55), c.z - reach * 0.4 + rng.uniform(-0.6, 0.6))))   # mid slope
    pts = [_yaw(p, c, yaw) for p in pts]
    hull_faces(pc, pts, col, rng, sy, t)


def hull_faces(pc, pts, col, rng, height, t):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bm.normal_update()
    center = sum(pts, Vector()) / len(pts)
    for f in bm.faces:
        ring = [l.vert.co.copy() for l in f.loops]
        cc = sum(ring, Vector()) / len(ring)
        if all(abs(p.y) < 1e-4 for p in ring):
            continue                       # the flat bottom lies on the ground: no face
        h = max(0.0, min(1.0, cc.y / max(height, 1e-3)))
        colr = tone(col, (0.84 + 0.16 * h) * rng.choice((1.0, 0.95, 0.9)))
        out = cc - center
        if len(ring) == 3:
            pc.face(ring, colr, "SmoothPlastic", t, out)
        elif len(ring) == 4:
            pc.quad_or_tris(ring, colr, "SmoothPlastic", t, out)
        else:
            polygon_fill(pc, ring, colr, "SmoothPlastic", t, out)
    bm.free()


def small_rock(pc, cpos, size, col, rng):
    boulder_start = len(pc.faces)
    tmp = Piece(pc.obj, pc.name, pc.origin)
    boulder(tmp, size, rng.randrange(10 ** 6), col, n_pts=9, t=0.3, jit=(0.75, 1.1))
    for f in tmp.faces:
        f["v"] = [p + Vector(cpos) for p in f["v"]]
        if not all(abs(p.y - cpos[1]) < 1e-4 for p in f["v"]):
            pc.faces.append(f)


# ------------------------------------------------------------------------------------------------
# v2 (2026-10-20): NATURAL canyon rock. Each stratum = a lofted irregular ring (10 vertices: bulges and bites, no
# long straight edge) with 2-3 sloped facet rows (lean 5-15 deg), a soft bevel at the top, an uneven ledge (inset
# 0.2-1.0, crumbling spots), alcoves low on the column, runnels, per-facet tone steps. Triangles (always planar).
# The collision stays today's boxes: the visible rock stays within about 0.8 of their faces.
# ------------------------------------------------------------------------------------------------
STEPS = (1.0, 0.93, 0.86)


def _box_radius(theta, hx, hz, n=6.0):
    """Superellipse 'rounded box' radius at angle theta (local frame) for half sizes hx, hz."""
    c, s = abs(math.cos(theta)), abs(math.sin(theta))
    return 1.0 / ((c / hx) ** n + (s / hz) ** n) ** (1.0 / n)


def _ray_poly(c, d, poly):
    """Distance from c along unit d (x, z) to the polygon outline (list of Vector, y ignored); None if no hit."""
    best = None
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        ex, ez = b.x - a.x, b.z - a.z
        den = d[0] * ez - d[1] * ex
        if abs(den) < 1e-9:
            continue
        t = ((a.x - c.x) * ez - (a.z - c.z) * ex) / den
        u = ((a.x - c.x) * d[1] - (a.z - c.z) * d[0]) / den
        if t > 0 and -1e-6 <= u <= 1 + 1e-6 and (best is None or t < best):
            best = t
    return best


def natural_band(pc, y0, y1, col, cxz, sxz, yaw, rng, prev_top=None, n=10, alcoves=0, t=0.6, runnels=1,
                 lean_max=12.0, height=54.0):
    """One natural stratum. Returns its top ring (for the next band). prev_top: the band below's top ring; this
    band's foot is kept inside it (ledge 0.2-1.0) so nothing overhangs without an underside."""
    c = Vector((cxz[0], 0, cxz[1]))
    hx, hz = sxz[0] / 2, sxz[1] / 2
    a0 = math.radians(yaw)
    h = y1 - y0
    thick = h >= 5.0
    th0 = rng.uniform(0, 2 * math.pi / n)
    thetas = [th0 + 2 * math.pi * i / n + rng.uniform(-0.18, 0.18) * 2 * math.pi / n for i in range(n)]
    # per-vertex outline offsets: bulges (+0.3 .. +0.7) and bites (-0.4 .. -1.2), clamped to +-0.8 of the envelope
    base_off = [rng.choice((rng.uniform(0.2, 0.6), rng.uniform(-0.4, 0.1), rng.uniform(-1.1, -0.5))) for _ in range(n)]
    lean = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1)))
    lean = lean.normalized() * math.tan(math.radians(rng.uniform(5.0, lean_max))) if lean.length > 1e-6 else Vector()
    alc = set(rng.sample(range(n), alcoves)) if alcoves else set()
    levels = [0.0, 0.5, 1.0] if not thick else [0.0, 0.42, 0.78, 1.0]

    def ring(fy, extra_in):
        pts = []
        for i, th in enumerate(thetas):
            r = _box_radius(th, hx, hz)
            off = base_off[i] + rng.uniform(-0.25, 0.25) - extra_in
            if i in alc and 0.15 < fy < 0.9:
                off -= rng.uniform(0.8, 1.5)
            off = max(-1.6, min(0.8, off))
            lx, lz = math.cos(th) * (r + off), math.sin(th) * (r + off)
            x = c.x + math.cos(a0) * lx + math.sin(a0) * lz
            z = c.z - math.sin(a0) * lx + math.cos(a0) * lz
            dy = fy * h
            lean_off = lean * (dy - h / 2)     # the band leans: it moves out at one side, in at the other
            pts.append(Vector((x + lean_off.x, y0 + dy, z + lean_off.z)))
        return pts

    rings = []
    for li, fy in enumerate(levels):
        extra = 0.0
        if li == len(levels) - 1:
            extra = rng.uniform(0.3, 0.7)          # soft bevel at the top
        rings.append(ring(fy, extra))
    # top ledge uneven + crumbling: lower 1-2 top vertices
    for i in rng.sample(range(n), rng.randint(1, 2)):
        rings[-1][i].y -= rng.uniform(0.25, 0.6)
    # keep the foot inside the band below's top ring (ledge 0.2 .. 1.0)
    if prev_top is not None:
        pc_ = sum(prev_top, Vector()) / len(prev_top)
        for i, p in enumerate(rings[0]):
            d = Vector((p.x - pc_.x, 0, p.z - pc_.z))
            if d.length < 1e-6:
                continue
            dn = d.normalized()
            lim = _ray_poly(pc_, (dn.x, dn.z), prev_top)
            if lim is not None:
                want = min(d.length, lim - rng.uniform(0.2, 1.0))
                rings[0][i] = Vector((pc_.x + dn.x * want, p.y, pc_.z + dn.z * want))
    ctr = Vector((c.x, (y0 + y1) / 2, c.z))
    tt = max(0.0, min(1.0, (y0 + y1) / 2 / height))
    g = 0.88 + 0.12 * (tt * tt * (3 - 2 * tt))
    for li in range(len(rings) - 1):
        lo, hi = rings[li], rings[li + 1]
        for i in range(n):
            j = (i + 1) % n
            for tri in ((lo[i], lo[j], hi[j]), (lo[i], hi[j], hi[i])):
                m = sum(tri, Vector()) / 3
                out = Vector((m.x - ctr.x, 0, m.z - ctr.z))
                k = rng.choice(STEPS)
                if li == len(rings) - 2:
                    k = min(1.0, k * 1.04)            # the bevel catches light
                pc.face(list(tri), tone(col, g * k), "SmoothPlastic", t, out)
    top = rings[-1]
    tc = sum(top, Vector()) / n
    tc.y = max(p.y for p in top) - 0.1
    for i in range(n):
        j = (i + 1) % n
        pc.face([top[i], top[j], tc], tone(col, min(1.12, g * 1.08 * rng.choice((1.0, 0.95)))), "SmoothPlastic", t,
                Vector((0, 1, 0)))
    # vertical runnels: dark strips on a facet of the middle row
    for _ in range(runnels):
        li = rng.randrange(len(rings) - 1)
        i = rng.randrange(n)
        j = (i + 1) % n
        a, b, top_ = rings[li][i], rings[li][j], rings[li + 1][j]
        nrm = (b - a).cross(top_ - a)
        if nrm.length < 1e-6:
            continue
        nrm = nrm.normalized()
        if Vector((nrm.x, 0, nrm.z)).dot(Vector((a.x - ctr.x, 0, a.z - ctr.z))) < 0:
            nrm = -nrm
        u = rng.uniform(0.35, 0.65)
        p0 = a + (b - a) * u
        p1 = p0 + (top_ - b) * 0.85
        e = (b - a).normalized() * 0.18
        q = [p0 - e, p0 + e, p1 + e, p1 - e]
        q = [p + nrm * 0.03 for p in q]
        pc.face(q, tone(col, 0.62), "SmoothPlastic", 0.05, nrm)
    return top


def caprock(pc, cpos, size, yaw, col, rng, t=0.6, n_pts=16):
    """Eroded caprock: convex hull of jittered points on the cap box (turned by yaw), a weathered uneven top."""
    c = Vector((cpos[0], 0, cpos[2]))
    sx, sy, sz = size
    y0 = cpos[1] - sy / 2
    pts = []
    for i in range(n_pts):
        th = 2 * math.pi * i / n_pts + rng.uniform(-0.15, 0.15)
        r = _box_radius(th, sx / 2, sz / 2, 4.0) * rng.uniform(0.82, 1.05)
        lx, lz = math.cos(th) * r, math.sin(th) * r
        y = y0 + (sy * rng.uniform(0.55, 1.0) if i % 2 else rng.uniform(0.0, sy * 0.35))
        if i % 2:
            lx, lz = lx * 0.85, lz * 0.85
        pts.append(_yaw(Vector((c.x + lx, y, c.z + lz)), c, yaw))
    pts.append(Vector((c.x, y0 + sy, c.z)))
    pts += [_yaw(Vector((c.x + math.cos(a) * sx * 0.3, y0, c.z + math.sin(a) * sz * 0.3)), c, yaw) for a in (0.5, 2.6, 4.4)]
    tmp_h = y0 + sy
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bm.normal_update()
    center = sum(pts, Vector()) / len(pts)
    for f in bm.faces:
        ring = [l.vert.co.copy() for l in f.loops]
        cc = sum(ring, Vector()) / len(ring)
        if all(abs(p.y - y0) < 1e-4 for p in ring):
            continue
        h = max(0.0, min(1.0, (cc.y - y0) / sy))
        colr = tone(col, (0.86 + 0.18 * h) * rng.choice(STEPS))
        if len(ring) == 3:
            pc.face(ring, colr, "SmoothPlastic", t, cc - center)
        else:
            polygon_fill(pc, ring, colr, "SmoothPlastic", t, cc - center)
    bm.free()


def natural_column(pieces_out, obj, base_name, parts, rng, height, split_at, origin, note, place, n=10, t=0.6,
                   alcove_bands=2, lean_max=12.0, caps=None):
    """Bands of `parts` (today's Strata boxes, bottom to top) -> 2 pieces: <base>_lower (bands < split_at) and
    <base>_upper (the rest + caps)."""
    lower = Piece(obj, base_name + "_lower", origin, notes=note, place=place)
    upper = Piece(obj, base_name + "_upper", origin, notes=note, place=place)
    prev = None
    strata = [p for p in parts if p[0] == "Strata"]
    for k, (nm, cpos, size, yaw, col) in enumerate(strata):
        y0, y1 = cpos[1] - size[1] / 2, cpos[1] + size[1] / 2
        target = lower if k < split_at else upper
        prev = natural_band(target, y0, y1, col, (cpos[0], cpos[2]), (size[0], size[2]), yaw, rng, prev_top=prev, n=n,
                            alcoves=(rng.randint(2, 3) if k < alcove_bands else 0), t=t,
                            runnels=(2 if size[1] >= 5 else 1), lean_max=lean_max, height=height)
    for nm, cpos, size, yaw, col in (caps or []):
        caprock(upper, cpos, size, yaw, col, rng, t=t)
    pieces_out += [lower, upper]


def mesa_strata():
    rng = random.Random(601)
    pieces = []
    left = [p for p in MESA_PARTS if p[0] == "Strata" and p[1][0] < 0]
    right = [p for p in MESA_PARTS if p[0] == "Strata" and p[1][0] > 0]
    cap_l = [p for p in MESA_PARTS if p[0] == "Cap" and p[1][0] < 0]
    cap_r = [p for p in MESA_PARTS if p[0] == "Cap" and p[1][0] > 0]
    note = ("v2 natural canyon rock over today's Strata boxes (the collision stays today's boxes, invisible): each "
            "stratum an irregular 10-sided ring (bulges / bites, no straight edges), 2-3 sloped facet rows (lean "
            "5-12 deg), a soft top bevel, uneven crumbling ledges, alcoves on the 2 lowest strata, runnels, per-facet "
            "tone steps; within about 0.8 of the box faces (bites and alcoves go deeper). Triangles. t 0.6.")
    for side, parts, caps in (("L", left, cap_l), ("R", right, cap_r)):
        natural_column(pieces, "mesa_strata", f"column_{side}", parts, rng, 54.0, 4, ROCK_ORIGIN, note,
                       {"relativeTo": "the Mesa_Strata_A model (base centre)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                        "replaces": f"the 7 Strata boxes at x {'~ -9' if side == 'L' else '~ +9'} (lower = y 0 .. 28, "
                                    f"upper = y 28 .. 50 + its cap rock)"},
                       caps=caps)
    base = Piece("mesa_strata", "base_scree", ROCK_ORIGIN,
                 notes="the 2 talus wedges as natural scree piles (same width and height; the foot spills 2.6 past "
                       "today's wedge front so it shows), a sand pile #F4D07C, 5 small rocks and 3 fallen blocks "
                       "(2.2-3.4) at the foot. t 0.4.",
                 place={"relativeTo": "the Mesa_Strata_A model (base centre)", "position": [0, 0, 0],
                        "orientation": [0, 0, 0], "replaces": "the 2 Talus WedgeParts (+ new sand pile, small rocks, fallen blocks)"})
    for name, cpos, size, yaw, col in MESA_PARTS:
        if name == "Talus":
            scree_pile(base, cpos, size, yaw, col, rng, reach=2.6)
    sand = [Vector((0.8 + 4.5 * math.cos(a) * rng.uniform(0.8, 1.0), 0.0, -9.0 + 2.2 * math.sin(a) * rng.uniform(0.8, 1.0)))
            for a in [2 * math.pi * k / 9 for k in range(9)]]
    sand += [Vector((0.8 + rng.uniform(-2.0, 2.0), rng.uniform(0.9, 1.3), -8.6 + rng.uniform(-0.8, 0.8))) for _ in range(3)]
    hull_faces(base, sand, "#F4D07C", rng, 1.3, 0.3)
    for cpos, size, col in (((4.0, 0.0, -11.0), (2.4, 1.6, 2.1), "#C45438"), ((-2.8, 0.0, -11.3), (1.6, 1.1, 1.5), "#953D2F"),
                            ((16.0, 0.0, -10.4), (3.2, 2.0, 2.7), "#CA5639"), ((-17.0, 0.0, -10.6), (2.6, 1.7, 2.2), "#E17E4F"),
                            ((-1.0, 0.0, -9.6), (1.4, 1.0, 1.3), "#C25337"), ((-12.5, 0.0, -11.2), (3.4, 2.2, 2.8), "#C95639"),
                            ((11.0, 0.0, -11.4), (2.8, 1.9, 2.4), "#BC5035"), ((19.6, 0.0, -6.0), (2.2, 1.6, 2.0), "#DF7D4E")):
        small_rock(base, cpos, size, col, rng)
    pieces.append(base)
    return pieces


def hoodoo():
    rng = random.Random(602)
    pieces = []
    for name, parts in (("variant_A", HOODOO_PARTS_A), ("variant_B", HOODOO_PARTS_B)):
        note = ("v2 natural hoodoo at scale 1.0 = the smallest Desert_3 hoodoo (7.2 wide, cap 8.4 x 2.8 x 7.6, top "
                "y 23.2); the 5 hoodoos are this shape at uniform scale 1.0 / 1.1 / 1.3 / 1.5 / 1.7 (scale the "
                "coordinates and t), any turn. Irregular 9-sided strata rings, sloped facets, uneven ledges, runnels, "
                "an eroded caprock; lower = strata 1-3, upper = strata 4-5 + the cap. The collision stays today's "
                "boxes. Triangles, t 0.4.")
        place = {"relativeTo": "each Hoodoo model (base centre)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                 "scale": "1.0, 1.1, 1.3, 1.5 or 1.7 (= today's hoodoo size)", "replaces": "5 Strata boxes + the Cap"}
        natural_column(pieces, "hoodoo", name, parts, rng, 23.2, 3, "the BASE CENTRE of the hoodoo (y 0 = the bottom), front -Z",
                       note, place, n=9, t=0.4, alcove_bands=1, lean_max=10.0,
                       caps=[p for p in parts if p[0] == "Cap"])
    return pieces


def red_rock():
    return mesa_strata() + hoodoo()


def preview_red_rock_all(pieces):
    mesa = [p for p in pieces if p.obj == "mesa_strata"]
    hood = [p for p in pieces if p.obj == "hoodoo"]
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    off = 50.0
    ctx = context_boxes([((c[0] - off, c[1], c[2]), s, colr, (0, yaw, 0)) for n, c, s, yaw, colr in MESA_PARTS], col)
    objs = [piece_object(pc, col) for pc in mesa]
    hctx = context_boxes([((c[0] - 14, c[1], c[2]), s, colr, (0, yaw, 0)) for n, c, s, yaw, colr in HOODOO_PARTS_A], col)
    hobjs = []
    for pc in hood:
        dx = 0.0 if "variant_A" in pc.name else 14.0
        hobjs.append(piece_object(pc, col, Vector((dx, 0, 0))))
    out = os.path.join(P.PREVIEW_DIR, "desert_red_rock_facets.png")
    return render_sheet("redrock", [(objs + ctx, [(-15, 12)]), (objs, [(150, 18)]), (hobjs + hctx, [(-15, 10)])], None, out)


# ------------------------------------------------------------------------------------------------
# DESERT MONUMENTS (B13): organic accents. Kit space of each kit (MapAssets.Desert.<kit>), front -Z.
# ------------------------------------------------------------------------------------------------
LAPIS, TURQ, GOLD, DARKJ, SAND, SAND_D = "#2C5CC8", "#40D0C4", "#FFC93C", "#533E28", "#E2BE84", "#B89262"


def hull_into(pc, pts, colfn, t, m="SmoothPlastic", skip=None):
    """Convex hull of pts as faces; colfn(face centroid, normal) -> colour; skip(ring) -> True drops a face."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bm.normal_update()
    center = sum((Vector(p) for p in pts), Vector()) / len(pts)
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromBMesh(bm)
    for f in bm.faces:
        ring = [l.vert.co.copy() for l in f.loops]
        if skip and skip(ring):
            continue
        cc = sum(ring, Vector()) / len(ring)
        col = colfn(cc, f.normal.copy())
        if len(ring) <= 3:
            pc.face(ring, col, m, t, cc - center)
        elif len(ring) == 4:
            pc.quad_or_tris(ring, col, m, t, cc - center)
        else:
            polygon_fill(pc, ring, col, m, t, cc - center)
    bm.free()
    return tree


def surface_quad(pc, tree, origin, direction, pts2d, col, m, t, lift=0.03):
    """A small flat quad / triangle laid on a hull surface: ray from origin along direction, pts2d in the hit
    plane's (u, v) frame (u horizontal, v up-ish)."""
    hit = tree.ray_cast(Vector(origin), Vector(direction).normalized())
    if hit[0] is None:
        return False
    p, n = hit[0], hit[1].normalized()
    if n.dot(Vector(direction)) > 0:
        n = -n
    u = Vector((0, 1, 0)).cross(n)
    if u.length < 1e-6:
        u = Vector((1, 0, 0))
    u.normalize()
    v = n.cross(u).normalized()
    q = [p + n * lift + u * a + v * b for a, b in pts2d]
    pc.face(q, col, m, t, n)
    return True


def anubis():
    rng = random.Random(701)
    pieces = []
    ORIG = "the JackalStatue kit pivot (kit space: plinth base centre, front -Z); place with no offset"
    place = {"relativeTo": "the JackalStatue model", "position": [0, 0, 0], "orientation": [0, 0, 0],
             "scale": "the copy's own scale (1.0 / 1.25 / 1.5)"}
    head = Piece("anubis", "head", ORIG,
                 notes="jackal head over today's Head 2.8 x 2.8 x 3 at (0, 16.4, 2.1), Snout 1.5 x 1.3 x 2.8 at (0, 15.85, "
                       "-0.4) and the 2 Ears 0.7 x 2.6 x 0.7 at (+-0.95, 18.9, 2.2): one faceted skull + long tapered snout "
                       "(tip z -1.9), a gold nose tip, almond Neon turquoise eyes at today's eye places (+-0.7, 16.8), tall "
                       "pointed ears leaning out 6 deg with gold inner faces, a gold crown band (today's Crown, y 17.4 .. "
                       "18.1). Dark #533E28 with tone steps. The nemes lappets stay parts (B13).",
                 place=dict(place, replaces="Head, Snout, Nose, the 2 Eyes, the 2 Ears, Crown"))
    pts = []
    for y, hx, z0, z1 in ((15.1, 1.0, 0.9, 3.1), (15.7, 1.35, 0.7, 3.5), (16.6, 1.42, 0.65, 3.6), (17.4, 1.2, 0.95, 3.4),
                          (17.75, 0.85, 1.4, 3.0)):
        for sx in (-1, 1):
            pts += [(sx * hx, y, z0 + 0.2), (sx * hx * 0.9, y, z1), (sx * hx * 0.6, y, z0), (sx * hx * 0.55, y, z1 + 0.15)]
    for zz, yt, yb, w in ((0.4, 16.35, 15.2, 0.78), (-0.6, 16.15, 15.25, 0.6), (-1.5, 15.98, 15.32, 0.42),
                          (-1.88, 15.88, 15.42, 0.3)):
        for sx in (-1, 1):
            pts += [(sx * w, yt, zz), (sx * w, yb, zz)]
    tree = hull_into(head, pts, lambda cc, n: tone(DARKJ, (1.12 if n.y > 0.5 else 1.0) * rng.choice(STEPS)), 0.3)
    for sx in (-1, 1):   # eyes: almond quads on the skull front, at today's eye places
        surface_quad(head, tree, (sx * 0.72, 16.82, -3.0), (0, 0, 1),
                     [(-0.3 * sx, -0.02), (0.0, 0.14), (0.32 * sx, 0.05), (0.02, -0.12)], TURQ, "Neon", 0.08)
    # gold nose tip
    nose = [(sx * 0.32, y, z) for sx in (-1, 1) for y, z in ((15.98, -1.75), (15.62, -1.95), (15.98, -2.02), (15.6, -1.75))]
    hull_into(head, nose, lambda cc, n: tone(GOLD, rng.choice(STEPS)), 0.2)
    # mouth line: a dark strip along each side of the snout
    for sx in (-1, 1):
        surface_quad(head, tree, (sx * 3.0, 15.42, -0.6), (-sx, 0, 0), [(-1.0, -0.04), (0.9, -0.04), (0.9, 0.04), (-1.0, 0.04)],
                     "#2A1F14", "SmoothPlastic", 0.05)
    # ears: pyramids leaning out, gold inner face
    for sx in (-1, 1):
        base = [(sx * 0.55, 17.45, 1.85), (sx * 1.4, 17.45, 1.85), (sx * 1.4, 17.45, 2.55), (sx * 0.55, 17.45, 2.55)]
        tip = (sx * 1.25, 20.3, 2.35)
        ear = base + [tip, (sx * 0.95, 18.9, 1.95)]
        etree = hull_into(head, ear, lambda cc, n: tone(DARKJ, rng.choice(STEPS)), 0.25)
        surface_quad(head, etree, (sx * 0.98, 18.4, -2.0), (0, 0, 1), [(-0.28, -0.7), (0.28, -0.7), (0.0, 0.9)],
                     GOLD, "SmoothPlastic", 0.05)
    # crown band: an octagonal gold ring around the skull top
    cz, cy0, cy1 = 2.2, 17.35, 18.05
    ring_o = [Vector((1.55 * math.cos(a), 0, cz + 1.65 * math.sin(a))) for a in [math.radians(22.5 + 45 * k) for k in range(8)]]
    ring_i = [Vector((1.15 * math.cos(a), 0, cz + 1.25 * math.sin(a))) for a in [math.radians(22.5 + 45 * k) for k in range(8)]]
    for k in range(8):
        j = (k + 1) % 8
        a, b = ring_o[k], ring_o[j]
        out = (a + b) / 2 - Vector((0, 0, cz))
        head.face([a + Vector((0, cy0, 0)), b + Vector((0, cy0, 0)), b + Vector((0, cy1, 0)), a + Vector((0, cy1, 0))],
                  tone(GOLD, rng.choice(STEPS)), "SmoothPlastic", 0.25, out)
        head.face([ring_o[k] + Vector((0, cy1, 0)), ring_o[j] + Vector((0, cy1, 0)), ring_i[j] + Vector((0, cy1, 0)),
                   ring_i[k] + Vector((0, cy1, 0))], tone(GOLD, 1.0), "SmoothPlastic", 0.25, Vector((0, 1, 0)))
    pieces.append(head)
    # usekh collar: 3 bead rings sloping down over the shoulders
    col = Piece("anubis", "collar", ORIG,
                notes="broad beaded usekh collar over today's 2 Collar blocks (gold 5.2 x 1 x 3.2 at y 13.5, lapis 3.6 x 0.6 x "
                      "2.9 at y 12.8): 3 rings sloping down from the neck (y 14.1) to the shoulders (y 12.6), gold / lapis "
                      "/ turquoise, each ring a row of 16 bead facets alternating tone, a gold edge. t 0.2.",
                place=dict(place, replaces="the 2 Collar blocks"))
    cx0, cz0 = 0.0, 2.1
    rings = [(0.85, 0.95, 14.1), (1.45, 1.25, 13.75), (2.0, 1.55, 13.3), (2.55, 1.8, 12.75), (2.7, 1.88, 12.55)]
    cols_ = [GOLD, LAPIS, TURQ, GOLD]
    angs = [math.radians(360.0 * k / 16) for k in range(16)]
    for r in range(len(rings) - 1):
        (ax, az, ay), (bx, bz, by) = rings[r], rings[r + 1]
        for k in range(16):
            j = (k + 1) % 16
            pa = [Vector((cx0 + ax * math.cos(angs[i]), ay, cz0 + az * math.sin(angs[i]))) for i in (k, j)]
            pb = [Vector((cx0 + bx * math.cos(angs[i]), by, cz0 + bz * math.sin(angs[i]))) for i in (k, j)]
            c = tone(cols_[r], 1.0 if k % 2 == 0 else 0.86)
            mid = (pa[0] + pb[1]) / 2
            out = Vector((mid.x - cx0, 0.6, mid.z - cz0))
            col.face([pa[0], pa[1], pb[1]], c, "SmoothPlastic", 0.2, out)
            col.face([pa[0], pb[1], pb[0]], c, "SmoothPlastic", 0.2, out)
    pieces.append(col)
    return pieces


def sphinx():
    rng = random.Random(702)
    pieces = []
    ORIG = "the Sarcophagus_Small kit pivot (kit space: base centre, the head toward -Z); place with no offset"
    place = {"relativeTo": "the Sarcophagus_Small model", "position": [0, 0, 0], "orientation": [0, 0, 0],
             "scale": "the copy's own scale (1.0 / 1.2)"}
    head = Piece("sphinx", "head", ORIG,
                 notes="sphinx head inside today's Head 2.6 x 1.2 x 2.2 at (0, 4.5, -3.3) + Nemes 3.4 x 1 x 0.8 at (0, 4.4, "
                       "-2.2): a gold face (forehead, cheeks, chin, nose ridge, a smooth closed mouth), Neon turquoise "
                       "eyes at today's places (+-0.6, 4.75, z -4.4), a nemes headdress of 6 horizontal stripe bands "
                       "alternating gold / lapis (0.25 tall) wrapping the head from the sides round the back, a gold top, a "
                       "gold cobra (uraeus) badge on the forehead. Top y 5.6. t 0.2.",
                 place=dict(place, replaces="Head, Nemes, the 2 Eyes"))
    face = []
    for y, hx, zf in ((3.95, 0.45, -4.3), (4.25, 0.8, -4.42), (4.75, 0.95, -4.45), (5.15, 0.9, -4.4), (5.35, 0.75, -4.3)):
        for sx in (-1, 1):
            face += [(sx * hx, y, zf), (sx * hx, y, -3.4)]
    ftree = hull_into(head, face, lambda cc, n: tone(GOLD, (1.05 if n.y > 0.4 else 1.0) * rng.choice(STEPS)), 0.2)
    for sx in (-1, 1):
        surface_quad(head, ftree, (sx * 0.6, 4.75, -6.0), (0, 0, 1),
                     [(-0.2 * sx, 0.0), (0.0, 0.09), (0.22 * sx, 0.02), (0.0, -0.08)], TURQ, "Neon", 0.06)
    nose = [(sx * 0.13, y, z) for sx in (-1, 1) for y, z in ((4.75, -4.47), (4.38, -4.47), (4.4, -4.62))]
    hull_into(head, nose, lambda cc, n: tone(GOLD, 0.93), 0.1)
    surface_quad(head, ftree, (0.0, 4.2, -6.0), (0, 0, 1), [(-0.3, -0.035), (0.3, -0.035), (0.3, 0.035), (-0.3, 0.035)],
                 "#8A6A1E", "SmoothPlastic", 0.04)
    # nemes: U-shaped bands round the head (open at the face), 6 stripes + a gold top fan
    levels = [3.95, 4.2, 4.45, 4.7, 4.95, 5.2, 5.45]
    ang = [math.radians(a) for a in (-120, -90, -55, -20, 20, 55, 90, 120)]   # 0 = the back (+Z), +-120 = beside the face
    cz = -3.15
    rings_ = []
    for y in levels:
        rx = 1.62 - 0.3 * (y - 3.95) / 1.5
        rz = 1.3 - 0.2 * (y - 3.95) / 1.5
        rings_.append([Vector((rx * math.sin(a), y, cz + rz * math.cos(a))) for a in ang])
    for li in range(len(levels) - 1):
        lo, hi = rings_[li], rings_[li + 1]
        c = GOLD if li % 2 == 0 else LAPIS
        for k in range(len(ang) - 1):
            mid = (lo[k] + hi[k + 1]) / 2
            out = Vector((mid.x, 0, mid.z - cz))
            head.face([lo[k], lo[k + 1], hi[k + 1]], tone(c, rng.choice(STEPS)), "SmoothPlastic", 0.2, out)
            head.face([lo[k], hi[k + 1], hi[k]], tone(c, rng.choice(STEPS)), "SmoothPlastic", 0.2, out)
    top = rings_[-1]
    apex = Vector((0, 5.62, cz))
    for k in range(len(ang) - 1):
        head.face([top[k], top[k + 1], apex], tone(GOLD, 1.06), "SmoothPlastic", 0.2, Vector((0, 1, 0)))
    head.face([top[-1], top[0], apex], tone(GOLD, 1.06), "SmoothPlastic", 0.2, Vector((0, 1, 0)))
    # uraeus on the forehead: a small gold hood + raised head
    cobra = [(sx * w, y, z) for sx in (-1, 1) for w, y, z in ((0.22, 5.2, -4.38), (0.12, 5.6, -4.42), (0.08, 5.35, -4.55),
                                                               (0.15, 5.25, -4.25))]
    hull_into(head, cobra, lambda cc, n: tone(GOLD, rng.choice(STEPS)), 0.1)
    pieces.append(head)
    paws = Piece("sphinx", "paws", ORIG,
                 notes="2 forward-stretched paws on the lid beside the head (x +-1.75, y 3.9 .. 4.5, z -4.95 .. -1.6), gold, "
                       "rounded fronts with 3 dark toe grooves each. New (no part today). t 0.2.",
                 place=dict(place, replaces="(new)"))
    for sx in (-1, 1):
        x = sx * 1.75
        pts = []
        for z, w, h in ((-1.6, 0.45, 0.5), (-3.0, 0.45, 0.58), (-4.4, 0.47, 0.6), (-4.82, 0.38, 0.5), (-4.95, 0.25, 0.35)):
            pts += [(x - w, 3.9, z), (x + w, 3.9, z), (x - w * 0.85, 3.9 + h, z), (x + w * 0.85, 3.9 + h, z)]
        tree = hull_into(paws, pts, lambda cc, n: tone(GOLD, (1.05 if n.y > 0.5 else 0.97) * rng.choice(STEPS)), 0.2,
                         skip=lambda ring: all(abs(p.y - 3.9) < 1e-4 for p in ring))
        for dx in (-0.22, 0.0, 0.22):
            surface_quad(paws, tree, (x + dx, 4.15, -7.0), (0, 0, 1), [(-0.03, -0.18), (0.03, -0.18), (0.03, 0.18), (-0.03, 0.18)],
                         "#8A6A1E", "SmoothPlastic", 0.04)
    pieces.append(paws)
    return pieces


def column_capital():
    rng = random.Random(703)
    pc = Piece("column", "capital", "the Sandstone_Column kit pivot (kit space: base centre); place with no offset",
               notes="papyrus / lotus bell from above today's lapis band (y 19.8, radius 1.85) flaring to radius 2.75 at "
                     "y 23.2, under today's 5.6 top slab (y 23.4 .. 25.0, keep it): 12 petal ribs (alternating radius and "
                     "tone), 3 gold binding rings at the neck, the top petal row painted lapis / turquoise, a gold lip. "
                     "Replaces the 4.6 x 1 x 4.6 Capital block (and hides the shaft top above y 19.8). t 0.3.",
               place={"relativeTo": "the Sandstone_Column model", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's own scale", "replaces": "the lower Capital block 4.6 x 1 x 4.6"})
    prof = [(19.8, 1.85, 0.0), (20.5, 1.92, 0.0), (21.3, 2.1, 0.06), (22.1, 2.38, 0.1), (22.8, 2.62, 0.12), (23.25, 2.78, 0.1),
            (23.4, 2.55, 0.0)]
    n = 12
    angs = [2 * math.pi * k / n for k in range(n)]
    rings = []
    for y, r, rib in prof:
        rings.append([Vector((math.cos(a) * r * (1.0 if k % 2 == 0 else 1.0 - rib), y, math.sin(a) * r * (1.0 if k % 2 == 0 else 1.0 - rib)))
                      for k, a in enumerate(angs)])
    for li in range(len(rings) - 1):
        lo, hi = rings[li], rings[li + 1]
        for k in range(n):
            j = (k + 1) % n
            if li == len(rings) - 2:
                c = GOLD
            elif li == len(rings) - 3:
                c = LAPIS if k % 2 == 0 else TURQ
            else:
                c = tone(SAND, 1.0 if k % 2 == 0 else 0.93)
            mid = (lo[k] + hi[j]) / 2
            out = Vector((mid.x, 0, mid.z))
            pc.face([lo[k], lo[j], hi[j]], c, "SmoothPlastic", 0.3, out)
            pc.face([lo[k], hi[j], hi[k]], c, "SmoothPlastic", 0.3, out)
    for y in (20.0, 20.25, 20.5):   # binding rings: 12 vertical gold quads each, 0.12 tall, just outside the neck
        rr = 1.98
        for k in range(n):
            j = (k + 1) % n
            a = Vector((math.cos(angs[k]) * rr, y, math.sin(angs[k]) * rr))
            b = Vector((math.cos(angs[j]) * rr, y, math.sin(angs[j]) * rr))
            pc.face([a, b, b + Vector((0, 0.12, 0)), a + Vector((0, 0.12, 0))], GOLD, "SmoothPlastic", 0.1, (a + b) / 2)
    return [pc]


def broken_end():
    rng = random.Random(704)
    pc = Piece("fallen_columns", "drum_broken_end",
               "the CENTRE OF THE DRUM'S END CIRCLE; the break faces +Y (local): turn it so +Y runs along the drum "
               "axis out of the broken end",
               notes="jagged break surface for a 3.6-dia drum (radius 1.8): a chipped rim (16 points, 0.1-0.3 lower / "
                     "0.05-0.2 smaller in places), an uneven inner field (-0.3 .. +0.5), a short skirt (y -0.45 .. rim) "
                     "that sleeves over the drum end (radius 1.82), 3 dark crack strips. #D5B37C with tone steps; use "
                     "#E2BE84 for the #E2BE84 drums. t 0.3.",
               place={"relativeTo": "each broken drum end (Shaft top, the broken piece, the fallen Drums)",
                      "position": "the end centre", "orientation": "+Y along the drum axis"})
    col = "#D5B37C"
    n = 16
    rim, skirt = [], []
    for k in range(n):
        a = 2 * math.pi * k / n
        chip = rng.random() < 0.35
        r = 1.82 - (rng.uniform(0.05, 0.2) if chip else 0.0)
        y = -(rng.uniform(0.1, 0.3) if chip else rng.uniform(0.0, 0.08))
        rim.append(Vector((math.cos(a) * r, y, math.sin(a) * r)))
        skirt.append(Vector((math.cos(a) * 1.82, -0.45, math.sin(a) * 1.82)))
    inner = []
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        r = rng.uniform(0.7, 1.15)
        inner.append(Vector((math.cos(a) * r, rng.uniform(-0.3, 0.5), math.sin(a) * r)))
    ctr = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.1, 0.4), rng.uniform(-0.2, 0.2)))
    for k in range(n):
        j = (k + 1) % n
        out = Vector((rim[k].x, 0, rim[k].z))
        pc.face([skirt[k], skirt[j], rim[j]], tone(col, rng.choice(STEPS)), "SmoothPlastic", 0.3, out)
        pc.face([skirt[k], rim[j], rim[k]], tone(col, rng.choice(STEPS)), "SmoothPlastic", 0.3, out)
    for k in range(n):     # rim -> inner ring
        j = (k + 1) % n
        ik = (k // 2) % 8
        pc.face([rim[k], rim[j], inner[ik]], tone(col, 0.9 * rng.choice(STEPS)), "SmoothPlastic", 0.3, Vector((0, 1, 0)))
    for i in range(8):
        a, b = inner[i], inner[(i + 1) % 8]
        rj = rim[(2 * i + 2) % n]
        pc.face([inner[i], rj, inner[(i + 1) % 8]], tone(col, 0.88 * rng.choice(STEPS)), "SmoothPlastic", 0.3, Vector((0, 1, 0)))
        pc.face([a, b, ctr], tone(col, 0.82 * rng.choice(STEPS)), "SmoothPlastic", 0.3, Vector((0, 1, 0)))
    for _ in range(3):     # dark crack strips across the break
        k = rng.randrange(8)
        a, b = inner[k] + Vector((0, 0.04, 0)), rim[(2 * k + rng.randrange(2)) % n] + Vector((0, 0.04, 0))
        e = (b - a)
        w = Vector((-e.z, 0, e.x)).normalized() * 0.06
        pc.face([a - w, b - w, b + w, a + w], "#7A6440", "SmoothPlastic", 0.04, Vector((0, 1, 0)))
    return [pc]


def altar_gem():
    pc = Piece("altar", "gem", "the CENTRE of the gem (its girdle centre)",
               notes="cut cyan gem (octagonal brilliant: girdle 1.2 across, crown to a table 0.7 across 0.35 up, pavilion to a "
                     "culet 0.65 down), Neon #5FD4FF with lighter crown facets. Replaces today's 1.0 Neon cube gem; set it in "
                     "a gold 4-prong setting on the top tier (B13). t 0.15.",
               place={"relativeTo": "the GoldPile_A model", "position": [-0.2, 3.75, 0.2], "orientation": [0, 22.5, 0],
                      "scale": "the copy's own scale", "replaces": "the Gem 1.0 cube (#40D0C4) on the top tier; the second gem "
                                                                   "0.8 (#5FD4FF) can use it at scale 0.7"})
    R, RT, YG, YT, YC = 0.6, 0.35, 0.08, 0.35, -0.65
    cyan = "#5FD4FF"
    angs = [math.radians(22.5 + 45 * k) for k in range(8)]
    g0 = [Vector((R * math.cos(a), -YG, R * math.sin(a))) for a in angs]
    g1 = [Vector((R * math.cos(a), YG, R * math.sin(a))) for a in angs]
    tb = [Vector((RT * math.cos(a), YT, RT * math.sin(a))) for a in angs]
    cul = Vector((0, YC, 0))
    for k in range(8):
        j = (k + 1) % 8
        mid = (g0[k] + g0[j]) / 2
        pc.face([g0[k], g0[j], g1[j], g1[k]], tone(cyan, 0.9), "Neon", 0.15, Vector((mid.x, 0, mid.z)))
        pc.face([g1[k], g1[j], tb[j], tb[k]], mix(cyan, "#FFFFFF", 0.12 if k % 2 else 0.24), "Neon", 0.15,
                Vector((mid.x, 0.8, mid.z)))
        pc.face([g0[j], g0[k], cul], tone(cyan, 0.86 if k % 2 else 0.95), "Neon", 0.15, Vector((mid.x, -0.8, mid.z)))
    polygon_fill(pc, list(reversed(tb)), mix(cyan, "#FFFFFF", 0.35), "Neon", 0.15, Vector((0, 1, 0)))
    return [pc]


def monuments():
    return anubis() + sphinx() + column_capital() + broken_end() + altar_gem()


def preview_monuments(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    # Anubis: today's body parts as context (plinth, seat, legs, torso, arms, nemes lappets)
    an_ctx = [((0, 1.0, 0), (8, 2, 11), SAND_D, (0, 0, 0)), ((0, 2.3, 0), (7, 0.6, 10), SAND, (0, 0, 0)),
              ((0, 4.7, 2.2), (5.2, 4.2, 4.6), SAND, (0, 0, 0)), ((0, 6.6, 4.6), (5.6, 8, 1.2), SAND, (0, 0, 0)),
              ((-1.3, 4.75, -1.6), (1.6, 4.3, 1.6), "#8C6844", (0, 0, 0)), ((1.3, 4.75, -1.6), (1.6, 4.3, 1.6), "#8C6844", (0, 0, 0)),
              ((-1.3, 7.65, 0.2), (1.8, 1.7, 4.8), "#8C6844", (0, 0, 0)), ((1.3, 7.65, 0.2), (1.8, 1.7, 4.8), "#8C6844", (0, 0, 0)),
              ((0, 10.3, 2.1), (4.6, 6.2, 2.6), "#8C6844", (0, 0, 0)), ((-2.9, 11.1, 1.9), (1.3, 3.8, 1.3), "#8C6844", (0, 0, 0)),
              ((2.9, 11.1, 1.9), (1.3, 3.8, 1.3), "#8C6844", (0, 0, 0)), ((0, 14.6, 2.1), (1.6, 1.2, 1.6), "#8C6844", (0, 0, 0)),
              ((-1.85, 14.8, 2.4), (0.9, 4.4, 2.2), LAPIS, (0, 0, 0)), ((1.85, 14.8, 2.4), (0.9, 4.4, 2.2), LAPIS, (0, 0, 0)),
              ((-1.3, 3.0, -2.2), (1.8, 0.8, 2.6), DARKJ, (0, 0, 0)), ((1.3, 3.0, -2.2), (1.8, 0.8, 2.6), DARKJ, (0, 0, 0))]
    a_objs = context_boxes(an_ctx, col) + [piece_object(by["anubis__head"], col), piece_object(by["anubis__collar"], col)]
    sp_ctx = [((30, 0.4, 0), (5, 0.8, 10), SAND_D, (0, 0, 0)), ((30, 1.9, 0), (4, 2.2, 9), SAND, (0, 0, 0)),
              ((30, 3.45, 0), (4.3, 0.9, 9.3), GOLD, (0, 0, 0)), ((30, 4.2, 0.8), (3.0, 0.6, 6.5), "#EAB837", (0, 0, 0))]
    s_objs = context_boxes(sp_ctx, col) + [piece_object(by["sphinx__head"], col, Vector((30, 0, 0))),
                                          piece_object(by["sphinx__paws"], col, Vector((30, 0, 0)))]
    c_ctx = [((60, 12.4, 0), (3.6, 20, 3.6), SAND, (0, 0, 0)), ((60, 19.4, 0), (3.9, 0.8, 3.9), LAPIS, (0, 0, 0)),
             ((60, 24.2, 0), (5.6, 1.6, 5.6), SAND_D, (0, 0, 0))]
    c_objs = context_boxes(c_ctx, col) + [piece_object(by["column__capital"], col, Vector((60, 0, 0)))]
    d_ctx = [((90, 1.8, 0), (3.6, 3.6, 3.6), "#D5B37C", (0, 0, 0))]
    d_objs = context_boxes(d_ctx, col) + [piece_object(by["fallen_columns__drum_broken_end"], col, Vector((90, 3.6, 0))),
                                          piece_object(by["altar__gem"], col, Vector((94, 2.0, 0)))]
    out = os.path.join(P.PREVIEW_DIR, "desert_monuments_facets.png")
    return render_sheet("monuments", [(a_objs, [(-25, 10)]), (a_objs[-2:], [(-35, 8)]), (s_objs, [(-30, 22)]),
                                      (c_objs, [(-20, 12)]), (d_objs, [(-25, 30)])], None, out)


# ------------------------------------------------------------------------------------------------
# DESERT PROPS / FURNITURE / TREASURES (B14): round and organic pieces. Kit space of each kit, front -Z.
# ------------------------------------------------------------------------------------------------
CLAY, CLAY_D, CLAY_L, CREAM, DARKP = "#CC603E", "#BC5839", "#DEA46E", "#E8E2D0", "#533E28"
GOLD2 = "#E5B435"


def lathe_faces(pc, profile, n, colfn, t, xscale=1.0, chips=(), rng=None, start_angle=0.0, center=(0.0, 0.0)):
    """Faceted lathe around +Y: profile [(r, y), ...] bottom to top; colfn(seg, k) -> colour for the band between
    profile points seg and seg+1, around-index k. xscale stretches it along X (still planar). chips: [(ring, k, dy)]
    lowers one ring vertex (rim chips)."""
    angs = [start_angle + 2 * math.pi * k / n for k in range(n)]
    rings = [[Vector((center[0] + r * math.cos(a) * xscale, y, center[1] + r * math.sin(a))) for a in angs] for r, y in profile]
    for ri, k, dy in chips:
        rings[ri][k] = rings[ri][k] + Vector((0, dy, 0))
    for s in range(len(profile) - 1):
        lo, hi = rings[s], rings[s + 1]
        for k in range(n):
            j = (k + 1) % n
            mid = (lo[k] + lo[j] + hi[k] + hi[j]) / 4
            out = Vector((mid.x - center[0], 0, mid.z - center[1]))
            dr = profile[s + 1][0] - profile[s][0]
            dy = profile[s + 1][1] - profile[s][1]
            out.y = -dr / max(abs(dy) + abs(dr), 1e-6) * out.length if dr != 0 else 0.0
            if out.length < 1e-6:
                out = Vector((0, 1 if dr < 0 else -1, 0))
            if (hi[k] - hi[j]).length < 1e-6:
                pc.face([lo[k], lo[j], hi[k]], colfn(s, k), "SmoothPlastic", t, out)
            elif (lo[k] - lo[j]).length < 1e-6:
                pc.face([lo[k], hi[j], hi[k]], colfn(s, k), "SmoothPlastic", t, out)
            else:
                pc.quad_or_tris([lo[k], lo[j], hi[j], hi[k]], colfn(s, k), "SmoothPlastic", t, out)
    return rings


def tube_faces(pc, pts, radii, sides, colfn, t, cap_end=False):
    """Tube along a polyline (parallel-transport frames), sides-gon section; colfn(seg, k)."""
    pts = [Vector(p) for p in pts]
    tangents = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tangents.append((b - a).normalized())
    up = Vector((0, 1, 0)) if abs(tangents[0].y) < 0.9 else Vector((1, 0, 0))
    u = tangents[0].cross(up).normalized()
    rings = []
    for i, p in enumerate(pts):
        if i > 0:
            u = (u - tangents[i] * u.dot(tangents[i])).normalized()
        v = tangents[i].cross(u).normalized()
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        rings.append([p + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * r for k in range(sides)])
    for s in range(len(pts) - 1):
        for k in range(sides):
            j = (k + 1) % sides
            q = [rings[s][k], rings[s][j], rings[s + 1][j], rings[s + 1][k]]
            out = (q[0] + q[1]) / 2 - pts[s]
            pc.quad_or_tris(q, colfn(s, k), "SmoothPlastic", t, out)
    if cap_end:
        polygon_fill(pc, rings[-1], colfn(len(pts) - 2, 0), "SmoothPlastic", t, tangents[-1])
    return rings


def jar():
    rng = random.Random(801)
    place = {"relativeTo": "the ClayJar_A model (kit pivot = base centre)", "position": [0, 0, 0], "orientation": [0, 0, 0],
             "scale": "the copy's own scale"}
    body = Piece("jar", "body", "the ClayJar_A kit pivot (base centre, y 0 = the ground)",
                 notes="wheel-thrown terracotta jar, 14-sided lathe: foot ring, round belly (2.6 wide at y 1.3), shoulder, "
                       "neck, rolled rim (1.9 wide, top y 3.65 like today) with 2 chips; painted bands: a dark #533E28 band "
                       "0.25 on the belly and a cream line on the shoulder, as separate faces. #CC603E with tone steps. t 0.25.",
                 place=dict(place, replaces="Body, Neck, Rim"))
    prof = [(0.8, 0.0), (0.98, 0.12), (1.2, 0.55), (1.3, 1.15), (1.3, 1.45), (1.29, 1.7), (1.22, 2.05), (1.18, 2.12),
            (0.95, 2.55), (0.7, 2.78), (0.66, 3.2), (0.9, 3.32), (0.96, 3.5), (0.84, 3.65)]

    def col(s, k):
        if s == 4:
            return DARKP
        if s == 6:
            return CREAM
        if s >= 10:
            return tone(CLAY, rng.choice((1.0, 0.95)))
        return tone(CLAY if s < 8 else CLAY_D, rng.choice(STEPS))
    lathe_faces(body, prof, 14, col, 0.25, chips=[(13, 3, -0.14), (13, 9, -0.1), (12, 9, -0.05)])
    lid = Piece("jar", "lid", "the ClayJar_A kit pivot (base centre)",
                notes="a lid on the rim: a 1.9 disc (y 3.65 .. 3.75), a low dome and a round knob, top y 4.0 (+9.6 % "
                      "height). #BC5839 with a cream line. t 0.2. New (the kit has no lid; the photo shows one).",
                place=dict(place, replaces="(new, sits on the Rim)"))
    lprof = [(0.95, 3.65), (0.95, 3.75), (0.7, 3.82), (0.32, 3.86), (0.22, 3.88), (0.26, 3.95), (0.18, 4.0), (0.02, 4.0)]
    lathe_faces(lid, lprof, 14, lambda s, k: CREAM if s == 1 else tone(CLAY_D, rng.choice(STEPS)), 0.2)
    return [body, lid]


def amphora():
    rng = random.Random(802)
    place = {"relativeTo": "the ClayJar_B model (kit pivot = base centre)", "position": [0, 0, 0], "orientation": [0, 0, 0],
             "scale": "the copy's own scale"}
    body = Piece("amphora", "body", "the ClayJar_B kit pivot (base centre, y 0 = the ground)",
                 notes="amphora, 14-sided lathe on today's sizes: ring foot (2.0 wide, y 0 .. 0.8), belly 3.5 wide at y 2.3, "
                       "shoulder, neck 1.6-1.7 wide, rolled rim 2.4 wide (top y 5.2) with 2 chips. Painted: today's "
                       "turquoise #40D0C4 band (y 2.0 .. 2.6), a chequer band (dark #533E28 / cream) on the shoulder, thin "
                       "dark lines. #DEA46E with tone steps, the neck #CE9866. t 0.25.",
                 place=dict(place, replaces="Foot, Body, Band, Neck, Rim"))
    prof = [(0.95, 0.0), (1.0, 0.22), (0.7, 0.45), (0.85, 0.8), (1.45, 1.35), (1.7, 1.85), (1.75, 2.0), (1.75, 2.6),
            (1.68, 2.95), (1.55, 3.25), (1.42, 3.45), (1.18, 3.75), (0.85, 4.05), (0.8, 4.65), (1.12, 4.8), (1.2, 5.0),
            (1.05, 5.2)]

    def col(s, k):
        if s == 6:
            return TURQ
        if s in (5, 7):
            return DARKP if s == 5 else tone(CLAY_L, 0.93)
        if s == 9:
            return DARKP if k % 2 == 0 else CREAM
        if s in (12, 13):
            return tone("#CE9866", rng.choice(STEPS))
        return tone(CLAY_L, rng.choice(STEPS))
    lathe_faces(body, prof, 14, col, 0.25, chips=[(16, 2, -0.13), (16, 10, -0.1)])
    handles = Piece("amphora", "handles", "the ClayJar_B kit pivot (base centre)",
                    notes="2 curved loop handles (6-sided tube 0.35 thick) from the shoulder (y 3.6) out to 0.6 beyond the "
                          "belly line and back under the rim (y 4.75), at x +-1.5 like today's 2 Handle blocks. #DEA46E. t 0.15.",
                    place=dict(place, replaces="the 2 Handle blocks"))
    for sx in (-1, 1):
        path = [(sx * 1.25, 3.55, 0), (sx * 1.75, 3.75, 0), (sx * 1.98, 4.15, 0), (sx * 1.88, 4.6, 0), (sx * 1.45, 4.82, 0),
                (sx * 0.95, 4.72, 0)]
        tube_faces(handles, path, 0.18, 6, lambda s, k: tone(CLAY_L, rng.choice(STEPS)), 0.15)
    return [body, handles]


def throne_pieces():
    rng = random.Random(803)
    place = {"relativeTo": "the Throne_Gold model (kit pivot = dais base centre)", "position": [0, 0, 0],
             "orientation": [0, 0, 0], "scale": "the copy's own scale"}
    lions = Piece("throne", "armrest_lion", "the Throne_Gold kit pivot (dais base centre, front -Z)",
                  notes="2 gold lion armrests (left and right, mirror images) on today's arm footprint (x +-4.2, 1.6-1.9 "
                        "wide, z -2.6 .. 4.4, y 2.4 .. 6.9): a lying lion body along the arm, the head at the front with a "
                        "mane ring and a snout, 2 front legs with paws at the front corner, dark eyes. Today's Neon arm gems "
                        "(1.9 x 1.3 x 1.6 at (+-4.2, 7.35, -1.8)) stay and sit on the lions' heads as crown jewels. Gold "
                        "#FFC93C, mane #E5B435. t 0.3.",
                  place=dict(place, replaces="the 2 Arm and 2 ArmTop blocks (keep the 2 ArmGems)"))
    for sx in (-1, 1):
        x = sx * 4.2

        def P_(dx, y, z):
            return (x + dx, y, z)
        body = [P_(dx, y, z) for dx in (-0.8, 0.8) for y, z in ((2.4, -0.4), (2.4, 4.4), (5.9, 4.4), (6.25, 3.0), (6.35, 0.6),
                                                                  (6.1, -0.6), (4.2, -0.9))]
        body += [P_(dx, 6.45, z) for dx in (-0.55, 0.55) for z in (1.0, 3.6)]
        hull_into(lions, body, lambda cc, n: tone(GOLD, (1.05 if n.y > 0.5 else 1.0) * rng.choice(STEPS)), 0.3)
        mane = [P_(dx, y, z) for dx in (-0.95, 0.95) for y, z in ((5.0, -0.5), (6.75, -0.6), (5.2, -1.5), (6.6, -1.5))]
        mane += [P_(0.0, 7.0, -1.0), P_(0.0, 4.8, -1.0)]
        hull_into(lions, mane, lambda cc, n: tone(GOLD2, rng.choice(STEPS)), 0.3)
        headp = [P_(dx, y, z) for dx in (-0.6, 0.6) for y, z in ((5.35, -1.5), (6.55, -1.5), (5.4, -2.15), (6.4, -2.15))]
        headp += [P_(dx, y, -2.6) for dx in (-0.35, 0.35) for y in (5.45, 5.95)]
        htree = hull_into(lions, headp, lambda cc, n: tone(GOLD, (1.04 if n.y > 0.5 else 1.0) * rng.choice(STEPS)), 0.3)
        for ex in (-0.32, 0.32):
            surface_quad(lions, htree, (x + ex, 6.2, -5.0), (0, 0, 1), [(-0.12, 0.0), (0.0, 0.08), (0.12, 0.0), (0.0, -0.08)],
                         DARKP, "SmoothPlastic", 0.05)
        for dx in (-0.45, 0.45):
            leg = [P_(dx + ex, y, z) for ex in (-0.3, 0.3) for y, z in ((2.4, -2.55), (2.4, -1.3), (5.0, -1.1), (5.0, -1.7),
                                                                         (2.95, -2.6))]
            hull_into(lions, leg, lambda cc, n: tone(GOLD, rng.choice(STEPS)), 0.25,
                      skip=lambda ring: all(abs(p.y - 2.4) < 1e-4 for p in ring))
    feet = Piece("throne", "paw_foot", "the CENTRE OF THE PAW'S SOLE (y 0 = the floor it stands on), toes toward -Z",
                 notes="a gold lion paw foot 0.95 wide x 0.6 tall x 1.15 long: a pad block and 4 rounded toes. Put one "
                       "under each carved leg at the seat corners, on the upper dais step (y 2.4): (+-3.1, 2.4, -1.6) and "
                       "(+-3.1, 2.4, 3.6), toes toward -Z (front). t 0.2.",
                 place={"relativeTo": "the Throne_Gold model", "positions": [[-3.1, 2.4, -1.6], [3.1, 2.4, -1.6], [-3.1, 2.4, 3.6],
                                                                            [3.1, 2.4, 3.6]], "orientation": [0, 0, 0]})
    pad = [(dx, y, z) for dx in (-0.45, 0.45) for y, z in ((0.0, -0.2), (0.0, 0.55), (0.6, 0.5), (0.55, -0.15), (0.3, -0.35))]
    hull_into(feet, pad, lambda cc, n: tone(GOLD, rng.choice(STEPS)), 0.2, skip=lambda ring: all(abs(p.y) < 1e-4 for p in ring))
    for tx in (-0.34, -0.11, 0.11, 0.34):
        toe = [(tx + ex, y, z) for ex in (-0.1, 0.1) for y, z in ((0.0, -0.3), (0.0, -0.6), (0.28, -0.55), (0.3, -0.3), (0.15, -0.65))]
        hull_into(feet, toe, lambda cc, n: tone(GOLD2, rng.choice(STEPS)), 0.15,
                  skip=lambda ring: all(abs(p.y) < 1e-4 for p in ring))
    return [lions, feet]


def lamp():
    rng = random.Random(804)
    place = {"relativeTo": "the Lamp_Djinn model (kit pivot = foot base centre)", "position": [0, 0, 0],
             "orientation": [0, 0, 0], "scale": "the copy's own scale"}
    body = Piece("lamp", "body", "the Lamp_Djinn kit pivot (foot base centre, the spout toward -X)",
                 notes="genie lamp on today's sizes (keep the Foot and Stem parts): a 12-sided lathe body stretched along X "
                       "(7.0 x 2.6 x 4.0, y 1.8 .. 4.4) with today's lapis #2C5CC8 band as a ring (y 3.0 .. 3.3) and "
                       "engraved darker gold rings; a tapered curved spout to today's tip (-7.1, 4.9) - keep SmokePoint "
                       "there; a loop handle curling out to x 4.95; a domed oval lid with a gold collar (top y 5.3); 4 gold "
                       "prongs for the gem. Gold #FFC93C / #E5B435. t 0.25.",
                 place=dict(place, replaces="the 2 Body blocks, Band, Spout, SpoutTip, the 3 Handle blocks, Lid"))
    prof = [(0.55, 1.8), (1.25, 2.05), (1.75, 2.5), (2.0, 2.95), (2.0, 3.0), (2.0, 3.3), (1.92, 3.5), (1.6, 3.95),
            (1.05, 4.3), (0.85, 4.4)]

    def col(s, k):
        if s == 4:
            return LAPIS
        if s in (2, 6):
            return tone(GOLD2, 0.9)
        return tone(GOLD, rng.choice(STEPS))
    lathe_faces(body, prof, 12, col, 0.25, xscale=1.75)
    spout = [(-3.1, 3.05, 0), (-4.3, 3.3, 0), (-5.6, 3.8, 0), (-6.6, 4.4, 0), (-7.15, 4.9, 0), (-7.35, 5.15, 0)]
    tube_faces(body, spout, [0.62, 0.52, 0.42, 0.35, 0.32, 0.36], 8,
               lambda s, k: tone(GOLD if s < 4 else GOLD2, rng.choice(STEPS)), 0.2)
    handle = [(3.2, 2.55, 0), (4.3, 2.7, 0), (4.95, 3.5, 0), (4.75, 4.55, 0), (4.0, 5.0, 0), (3.2, 4.45, 0)]
    tube_faces(body, handle, 0.3, 6, lambda s, k: tone(GOLD, rng.choice(STEPS)), 0.2)
    lid = [(1.45, 4.35), (1.5, 4.5), (1.38, 4.6), (1.05, 4.95), (0.6, 5.2), (0.42, 5.3)]
    lathe_faces(body, lid, 12, lambda s, k: GOLD if s == 0 else tone(GOLD2, rng.choice(STEPS)), 0.2, xscale=1.55)
    for k in range(4):   # prongs: thin gold quads leaning out around the gem (y 5.3 .. 5.95)
        a = math.radians(45 + 90 * k)
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-d.z, 0, d.x)) * 0.08
        b0 = Vector((0, 5.28, 0)) + d * 0.36
        b1 = Vector((0, 5.95, 0)) + d * 0.5
        body.face([b0 - side, b0 + side, b1 + side, b1 - side], GOLD, "SmoothPlastic", 0.08, d)
    gem = Piece("lamp", "gem", "the Lamp_Djinn kit pivot (the gem centre is at (0, 5.8, 0), today's Knob place)",
                notes="cut turquoise gem, octagonal brilliant 1.1 across x 1.0 tall, Neon #40D0C4 (today's Knob colour) "
                      "with lighter crown facets; sits in the 4 prongs of lamp__body. t 0.12.",
                place=dict(place, replaces="the Knob (1.0 Neon cube)"))
    R, RT, YG, YT, YC = 0.55, 0.3, 0.06, 0.32, -0.62
    cyan = TURQ
    c0 = Vector((0, 5.8, 0))
    angs = [math.radians(22.5 + 45 * k) for k in range(8)]
    g0 = [c0 + Vector((R * math.cos(a), -YG, R * math.sin(a))) for a in angs]
    g1 = [c0 + Vector((R * math.cos(a), YG, R * math.sin(a))) for a in angs]
    tb = [c0 + Vector((RT * math.cos(a), YT, RT * math.sin(a))) for a in angs]
    cul = c0 + Vector((0, YC + 0.24, 0))
    for k in range(8):
        j = (k + 1) % 8
        mid = (g0[k] + g0[j]) / 2 - c0
        gem.face([g0[k], g0[j], g1[j], g1[k]], tone(cyan, 0.9), "Neon", 0.12, Vector((mid.x, 0, mid.z)))
        gem.face([g1[k], g1[j], tb[j], tb[k]], mix(cyan, "#FFFFFF", 0.12 if k % 2 else 0.25), "Neon", 0.12,
                 Vector((mid.x, 0.8, mid.z)))
        gem.face([g0[j], g0[k], cul], tone(cyan, 0.86 if k % 2 else 0.95), "Neon", 0.12, Vector((mid.x, -0.8, mid.z)))
    polygon_fill(gem, list(reversed(tb)), mix(cyan, "#FFFFFF", 0.35), "Neon", 0.12, Vector((0, 1, 0)))
    return [body, gem]


def stand():
    rng = random.Random(805)
    pc = Piece("stand", "lotus_bowl", "the Brazier_A kit pivot (base centre)",
               notes="gold lotus bowl replacing today's 3 Bowl blocks (y 3.8 .. 5.3): 8 petals (16-sided lathe, petal "
                     "centres full radius, the gaps 15 % in and the tips notched), flaring from radius 0.75 to 2.1, petal "
                     "tips curling out at the top, an engraved darker ring at y 4.2, a lapis line under the tips, a dark "
                     "floor at y 4.75 inside. Keep the Embers (Neon, y 5.1 .. 5.5) and their FirePoint. Gold #FFC93C / "
                     "#E5B435. t 0.2.",
               place={"relativeTo": "the Brazier_A model", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's own scale", "replaces": "the 3 Bowl blocks (keep Base, Stem, Embers)"})
    n = 16
    prof = [(0.75, 3.8), (0.95, 4.0), (1.0, 4.15), (1.0, 4.25), (1.45, 4.55), (1.85, 4.9), (1.95, 5.05), (2.12, 5.3)]
    angs = [2 * math.pi * k / n for k in range(n)]
    rings = []
    for ri, (r, y) in enumerate(prof):
        ring = []
        for k, a in enumerate(angs):
            gap = k % 2 == 1
            rr = r * (0.85 if (gap and ri >= 4) else 1.0)
            yy = y - (0.22 if (gap and ri == len(prof) - 1) else 0.0)
            ring.append(Vector((rr * math.cos(a), yy, rr * math.sin(a))))
        rings.append(ring)
    for s in range(len(prof) - 1):
        for k in range(n):
            j = (k + 1) % n
            q = [rings[s][k], rings[s][j], rings[s + 1][j], rings[s + 1][k]]
            mid = sum(q, Vector()) / 4
            if s == 2:
                c = tone(GOLD2, 0.85)
            elif s == 5:
                c = LAPIS
            else:
                c = tone(GOLD if k % 4 < 2 else GOLD2, rng.choice(STEPS))
            pc.quad_or_tris(q, c, "SmoothPlastic", 0.2, Vector((mid.x, -0.3, mid.z)))
    floor = [Vector((1.5 * math.cos(a), 4.75, 1.5 * math.sin(a))) for a in angs]
    polygon_fill(pc, floor, tone(GOLD2, 0.6), "SmoothPlastic", 0.15, Vector((0, 1, 0)))
    return [pc]


def desert_props():
    return jar() + amphora() + throne_pieces() + lamp() + stand()


def preview_props(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    g1 = [piece_object(by["jar__body"], col), piece_object(by["jar__lid"], col),
          piece_object(by["amphora__body"], col, Vector((-4.5, 0, 0))), piece_object(by["amphora__handles"], col, Vector((-4.5, 0, 0)))]
    s_ctx = context_boxes([((-12, 0.5, 0), (3.2, 1.0, 3.2), SAND_D, (0, 0, 0)), ((-12, 2.4, 0), (1.5, 2.8, 1.5), SAND, (0, 0, 0)),
                           ((-12, 5.3, 0), (3.0, 0.4, 3.0), "#FF8C28", (0, 0, 0))], col)
    g1 += s_ctx + [piece_object(by["stand__lotus_bowl"], col, Vector((-12, 0, 0)))]
    t_ctx = context_boxes([((0, 0.6, 0), (13, 1.2, 11), SAND_D, (0, 0, 0)), ((0, 1.8, 0.5), (11, 1.2, 9), SAND, (0, 0, 0)),
                           ((0, 3.7, 1.0), (7, 2.6, 6), GOLD2, (0, 0, 0)), ((0, 5.35, 1.0), (7.4, 0.7, 6.4), "#D64A3E", (0, 0, 0)),
                           ((0, 9.9, 4.2), (8.4, 15, 1.6), GOLD, (0, 0, 0)), ((0, 11.5, 3.3), (5, 9, 0.4), LAPIS, (0, 0, 0)),
                           ((-4.2, 7.35, -1.8), (1.9, 1.3, 1.6), TURQ, (0, 0, 0)), ((4.2, 7.35, -1.8), (1.9, 1.3, 1.6), TURQ, (0, 0, 0))], col)
    g2 = t_ctx + [piece_object(by["throne__armrest_lion"], col)]
    for pos in ((-3.1, 2.4, -1.6), (3.1, 2.4, -1.6)):
        g2.append(piece_object(by["throne__paw_foot"], col, Vector(pos)))
    l_ctx = context_boxes([((30, 0.4, 0), (3.0, 0.8, 3.0), GOLD2, (0, 45, 0)), ((30, 1.3, 0), (1.4, 1.0, 1.4), GOLD, (0, 0, 0))], col)
    g3 = l_ctx + [piece_object(by["lamp__body"], col, Vector((30, 0, 0))), piece_object(by["lamp__gem"], col, Vector((30, 0, 0)))]
    out = os.path.join(P.PREVIEW_DIR, "desert_props_facets.png")
    return render_sheet("props", [(g1, [(-20, 14)]), (g2, [(-30, 12)]), (g2[-3:-2], [(-40, 15)]), (g3, [(-25, 20)])], None, out)


# ------------------------------------------------------------------------------------------------
# JUNGLE BUILDINGS AND TEMPLES (guide section C): carved faces, soft moss drapes, hanging vines, thatch roof.
# ------------------------------------------------------------------------------------------------
JSTONE, JSTONE_M, JSTONE_D, JREC = "#848A7C", "#7B8174", "#5C645C", "#292D29"
JMOSS, JMOSS_L, JMOSS_LL, JVINE = "#589642", "#60C448", "#78D246", "#46AA3C"
THATCH, THATCH_L, JWOOD_D = "#C4A068", "#D8C080", "#703E26"


def sweep_faces(pc, sections, colfn, t, caps=True):
    """Sweep of a convex section through stations: sections[i] = list of points (same count, ordered around the
    section, a planar convex ring); colfn(strip k, interval i) -> colour. Open between the last and first point
    (that side is buried in the wall). caps: closes both ends."""
    cents = [sum(s, Vector()) / len(s) for s in sections]
    for i in range(len(sections) - 1):
        a, b = sections[i], sections[i + 1]
        for k in range(len(a) - 1):
            q = [a[k], b[k], b[k + 1], a[k + 1]]
            out = (a[k] + a[k + 1] + b[k] + b[k + 1]) / 4 - (cents[i] + cents[i + 1]) / 2
            pc.quad_or_tris(q, colfn(k, i), "SmoothPlastic", t, out)
    if caps:
        polygon_fill(pc, sections[0], colfn(0, 0), "SmoothPlastic", t, cents[0] - cents[1])
        polygon_fill(pc, sections[-1], colfn(0, len(sections) - 2), "SmoothPlastic", t, cents[-1] - cents[-2])


def brow_sections(stations, H, D, zb, xform=None):
    """stations: [(x, y centre, scale)]; section from top-back round over the front to the under-back. A heavy
    ridge: rounded top bevel, overhanging front, underside sloping back into the face."""
    prof = [(0.5, 0.0), (0.5, 0.45), (0.3, 0.88), (-0.1, 1.0), (-0.5, 0.72), (-0.5, 0.0)]
    secs = []
    for x, yc, s in stations:
        ring = [Vector((x, yc + fy * H * s, zb - fz * D * s)) for fy, fz in prof]
        if xform:
            ring = [xform(p) for p in ring]
        secs.append(ring)
    return secs


def brow_col(k, i):
    return tone(JSTONE_D, (1.0, 0.97, 0.93, 0.86, 0.72)[k])


def nose_into(pc, X, Y0, Y1, ZB, ZF, nostril):
    """Carved nose: bridge, round tip, flared wings, flat-ish underside with 2 dark nostrils. Hull of points given
    in fractions of the half width X, the height Y0..Y1 and the depth ZB (back, in the face) .. ZF (front)."""
    fr = [(0.32, 1.0, 0.0), (0.36, 0.97, 0.12), (0.42, 0.62, 0.55), (0.3, 0.24, 1.0), (0.36, 0.1, 0.9),
          (1.0, 0.2, 0.4), (0.95, 0.05, 0.3), (0.8, 0.34, 0.55), (0.5, 0.0, 0.6), (0.9, 0.0, 0.08), (1.0, 0.0, 0.0),
          (0.95, 0.35, 0.0), (0.0, 0.18, 1.0), (0.0, 1.0, 0.0)]
    pts = []
    for u, v, w in fr:
        for sgn in ((1, -1) if u > 0 else (1,)):
            pts.append(Vector((sgn * u * X, Y0 + v * (Y1 - Y0), ZB + w * (ZF - ZB))))

    def colfn(cc, n):
        if n.y < -0.45:
            return tone(JSTONE_D, 0.74)
        if n.y > 0.35:
            return JSTONE_D
        return tone(JSTONE_D, 0.93 if abs(n.x) > 0.5 else 0.97)

    tree = hull_into(pc, pts, colfn, 0.25 * X / 1.05, skip=lambda ring: all(abs(p.z - ZB) < 1e-4 for p in ring))
    a, b, lift = nostril
    for sgn in (-1, 1):
        surface_quad(pc, tree, (sgn * 0.42 * X, Y0 - 1.0, ZB + 0.45 * (ZF - ZB)), (0, 1, 0),
                     [(-a, -b), (a, -b * 0.6), (a * 0.7, b), (-a * 0.8, b * 0.8)], JREC, "SmoothPlastic", 0.1 * lift / 0.03,
                     lift)
    return tree


def carved_face():
    origin = "the Carved_Face_Block kit pivot (base centre, y 0 = the ground, front -Z)"
    place = {"relativeTo": "the Carved_Face_Block model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
             "scale": "the copy's own scale (the kit is placed at several scales: scale the union with the model)"}
    brow = Piece("face", "brow", origin, place=dict(place, replaces="the part Brow (9 x 1.4 x 1 at (0, 8.9, -2.3)); keep its "
                                                     "CanCollide on a hidden box or the union"),
                 notes="carved heavy brow ridge in one piece over both eyes: arched over each eye (peak above x = +-2.3), "
                       "dipping at the nose bridge, tapering at the temples; rounded top bevel, front 0.95 proud of the "
                       "head (overhangs the sockets and the Neon eyes), underside sloping back. #5C645C, darker underside. "
                       "Same family as temple__brow (Gate_Jungle_4), but sized to this kit: not a scaled copy.")
    st = []
    for x in (-4.6, -3.8, -2.9, -2.0, -1.0, 0.0, 1.0, 2.0, 2.9, 3.8, 4.6):
        ax = abs(x)
        arch = 0.16 * math.cos((ax - 2.3) / 2.3 * math.pi / 2) if ax <= 4.6 else 0.0
        dip = -0.14 * max(0.0, 1 - ax / 1.0)
        end = -0.22 * max(0.0, (ax - 3.6) / 1.0)
        s = 1.0 - 0.42 * max(0.0, (ax - 3.6) / 1.0) - 0.1 * max(0.0, 1 - ax / 1.0)
        st.append((x, 8.9 + arch + dip + end, s))
    sweep_faces(brow, brow_sections(st, 1.4, 1.05, -1.9), brow_col, 0.25)

    nl = Piece("face", "nose_lips", origin, place=dict(place, replaces="the Nose wedge (1.9 x 3.4 x 1.7 at (0, 5.5, -2.8)); keep "
                                                         "Mouth (dark), the 4 Teeth and the Neon eyes as parts"),
               notes="carved nose (bridge from between the eyes, round tip, flared wings 2.1 wide, 2 dark nostrils "
                     "underneath) + 2 lip rolls framing today's dark Mouth (5.6 x 1.4 at y 1.8..3.2): upper lip with a "
                     "cupid's-bow dip, fuller lower lip, both 0.55-0.6 proud, 0.76 tall, tapering into the corners. The teeth stay "
                     "parts (0.5 proud, in front of the dark mouth). Replace the flat Moss slab over the mouth by a "
                     "moss__drape patch on the cheek.")
    nose_into(nl, 1.05, 3.8, 7.4, -1.95, -3.65, (0.17, 0.11, 0.03))

    def lip(yc, H, D, fuller, bow):
        st = []
        for x in (-3.15, -2.6, -1.8, -0.9, 0.0, 0.9, 1.8, 2.6, 3.15):
            ax = abs(x)
            s = max(0.25, 1.0 - max(0.0, (ax - 1.8) / 1.35) * 0.75)
            dy = bow * (-0.08 if ax < 0.3 else (0.05 if ax < 1.2 else 0.0)) - fuller * 0.05 * max(0.0, (ax - 1.8))
            st.append((x, yc + dy, s))
        prof = [(0.5, 0.0), (0.42, 0.55), (0.1, 1.0), (-0.32, 0.8), (-0.5, 0.0)]
        secs = [[Vector((x, yc2 + fy * H * s, -1.95 - fz * D * s)) for fy, fz in prof] for x, yc2, s in st]

        def col(k, i):
            return tone(JSTONE_D, (1.0, 0.95, 0.88, 0.76)[k])
        sweep_faces(nl, secs, col, 0.15)
    lip(3.45, 0.76, 0.55, 0.0, 1.0)
    lip(1.55, 0.78, 0.6, 1.0, 0.0)
    return [brow, nl]


def temple_face():
    origin = "the Gate_Jungle_4 kit pivot (centre of the mouth opening at ground level, front -Z)"
    place = {"relativeTo": "the Gate_Jungle_4 model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
             "note": "NOT under the Barrier: these replace non-Barrier parts only"}
    br = Piece("temple", "brow", origin, place=dict(place, replaces="the 2 Brow parts (13.5 x 2.6 x 3.4 at (+-13, 35.8, -5), "
                                                      "tilted +-9 deg); keep CanCollide on 2 hidden boxes"),
               notes="2 heavy carved brow ridges, each 13.5 long, arched (0.35 up in the middle), tapering at both ends, "
                     "rounded top bevel, 3.1 proud of the Face (front at z -6.7 like today), underside sloping back; the "
                     "inner ends lower (today's +-9 deg frown). #5C645C, dark underside. The sockets, Neon GlyphEyes and "
                     "Pupils stay parts.")
    for sgn in (-1, 1):
        th = math.radians(9.0) * sgn
        ca, sa = math.cos(th), math.sin(th)
        cx = 13.0 * sgn

        def xf(p, ca=ca, sa=sa, cx=cx):
            return Vector((cx + p.x * ca - p.y * sa, 35.8 + p.x * sa + p.y * ca, p.z))
        st = []
        for x in (-6.75, -5.7, -4.0, -2.0, 0.0, 2.0, 4.0, 5.7, 6.75):
            f = abs(x) / 6.75
            st.append((x, 0.35 * (1 - f * f), 1.0 - 0.4 * max(0.0, (f - 0.75) / 0.25)))
        sweep_faces(br, brow_sections(st, 2.8, 3.1, -3.6, xf), brow_col, 0.6)
    ns = Piece("temple", "nose", origin, place=dict(place, replaces="the Nose wedge (8 x 10 x 5 at (0, 26.5, -6.5)); keep its "
                                                      "CanCollide on a hidden wedge"),
               notes="carved temple nose, the same design as face__nose_lips' nose at temple proportions (8.8 wide "
                     "wings, y 21.5..32.5, 5 proud): bridge, round tip, flared wings, 2 dark nostrils underneath.")
    nose_into(ns, 4.4, 21.5, 32.5, -4.0, -9.0, (0.75, 0.5, 0.08))
    return [br, ns]


def _clip_s(poly, top):
    out = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ina = a.y >= -1e-9 if top else a.y <= 1e-9
        inb = b.y >= -1e-9 if top else b.y <= 1e-9
        if ina:
            out.append(a)
        if ina != inb:
            k = a.y / (a.y - b.y)
            p = a + (b - a) * k
            p.y = 0.0
            out.append(p)
    clean = []
    for p in out:
        if not clean or (p - clean[-1]).length > 1e-6:
            clean.append(p)
    if len(clean) > 1 and (clean[0] - clean[-1]).length < 1e-6:
        clean.pop()
    return clean if len(clean) >= 3 else []


def _convex(pts2):
    sgn = 0
    n = len(pts2)
    for i in range(n):
        a, b, c = pts2[i], pts2[(i + 1) % n], pts2[(i + 2) % n]
        cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
        if abs(cr) < 1e-9:
            continue
        s = 1 if cr > 0 else -1
        if sgn and s != sgn:
            return False
        sgn = s
    return True


def moss_drape(name, seed, layers, notes):
    """A soft layered moss patch draped over a 90 deg edge. Built flat in (u along the edge, s across it: s > 0 on
    the TOP going back +Z, s < 0 down the FRONT face, h = height above the stone), then folded over the edge; each
    layer: an irregular rounded outline at h = base, 1-2 inner rings (homothetic about a point shifted down the
    front = a fuller drip lip at the bottom), a flat cap. Faces crossing the edge are split, and a chamfer strip
    joins the top and front halves."""
    rng = random.Random(seed)
    pc = Piece("moss", name, "the patch's own anchor: (0, 0, 0) = a point on the stone's TOP-FRONT EDGE at the patch "
               "centre; the top face is y = 0 going back (+Z), the front face is z = 0 going down (-Y)",
               place={"relativeTo": "any 90 deg stone edge (cap, cornice, brow, crown, parapet)",
                      "position": "the anchor on the edge line", "orientation": "yaw so the piece's -Z = the face's outward "
                      "normal", "scale": "uniform 0.7..1.6; 1 patch per 4-6 studs of edge; mirror X for variety"},
               notes=notes)
    LIFT = 0.02

    def emit(poly, col):
        for top in (True, False):
            part = _clip_s(poly, top)
            if not part:
                continue
            if top:
                m = [Vector((p.x, p.z + LIFT, p.y)) for p in part]
                nrm = Vector((0, 1, 0))
            else:
                m = [Vector((p.x, p.y, -(p.z + LIFT))) for p in part]
                nrm = Vector((0, 0, -1))
            if len(m) <= 4:
                pc.face(m, col, "SmoothPlastic", 0.1, nrm)
            else:
                polygon_fill(pc, m, col, "SmoothPlastic", 0.1, nrm)
            if top:
                for i in range(len(part)):
                    a, b = part[i], part[(i + 1) % len(part)]
                    if abs(a.y) < 1e-9 and abs(b.y) < 1e-9 and max(a.z, b.z) > 0.05:
                        ta, tb = Vector((a.x, a.z + LIFT, 0)), Vector((b.x, b.z + LIFT, 0))
                        fa, fb = Vector((a.x, 0, -(a.z + LIFT))), Vector((b.x, 0, -(b.z + LIFT)))
                        if a.z < 0.03:
                            pc.face([ta, tb, fb], col, "SmoothPlastic", 0.1, Vector((0, 1, -1)))
                        elif b.z < 0.03:
                            pc.face([ta, tb, fa], col, "SmoothPlastic", 0.1, Vector((0, 1, -1)))
                        else:
                            pc.quad_or_tris([ta, tb, fb, fa], col, "SmoothPlastic", 0.1, Vector((0, 1, -1)))

    for L in layers:
        cu, cs = L["c"]
        n = L["n"]
        for _ in range(50):
            a0 = rng.uniform(0, 2 * math.pi / n)
            ring = []
            for k in range(n):
                a = a0 + 2 * math.pi * k / n + rng.uniform(-0.18, 0.18)
                r = rng.uniform(0.86, 1.08)
                ring.append((cu + L["rx"] * r * math.cos(a), cs + L["ry"] * r * math.sin(a)))
            if _convex(ring):
                break
        hc = (cu + L.get("lip_u", 0.0), cs - L["ry"] * L.get("lip", 0.35))
        rings = [(1.0, 0.0)] + L["rings"]          # (homothety factor, height fraction)
        lev = []
        for f, hf in rings:
            lev.append([Vector((hc[0] + f * (u - hc[0]), hc[1] + f * (s - hc[1]), L["base"] + hf * L["H"])) for u, s in ring])
        cols = L["cols"]
        for li in range(len(lev) - 1):
            lo, hi = lev[li], lev[li + 1]
            for k in range(n):
                j = (k + 1) % n
                emit([lo[k], lo[j], hi[j], hi[k]], cols[li])
        cap = lev[-1]
        k = 1
        while k < n - 1:
            if k + 2 < n:
                emit([cap[0], cap[k], cap[k + 1], cap[k + 2]], cols[-1])
                k += 2
            else:
                emit([cap[0], cap[k], cap[k + 1]], cols[-1])
                k += 1
    return pc


def moss_pieces():
    g = (JMOSS, tone(JMOSS, 0.86), tone(JMOSS, 0.93))
    l2 = (tone(JMOSS_L, 0.9), JMOSS_L)
    l3 = (tone(JMOSS_LL, 0.92), JMOSS_LL)
    A = moss_drape("drape_A", 1101, [
        dict(c=(0.0, -0.2), rx=1.0, ry=0.9, n=10, H=0.17, base=0.0, lip=0.15, rings=[(0.8, 0.65), (0.55, 1.0)],
             cols=(g[1], g[2], g[0])),
        dict(c=(0.1, -0.25), rx=0.68, ry=0.6, n=8, H=0.11, base=0.15, lip=0.15, rings=[(0.6, 1.0)], cols=l2),
        dict(c=(-0.2, -0.78), rx=0.4, ry=0.3, n=7, H=0.09, base=0.11, lip=0.3, rings=[(0.55, 1.0)], cols=l3)],
        "soft layered moss patch, 2.0 wide, reaching 0.7 back over the top and 1.1 down the front: 3 stacked rounded "
        "layers (#589642 -> #60C448 -> #78D246), each smaller and lighter, thinning to nothing at the outline, the "
        "plateau over the edge, the light top layer a drip lobe hanging at the bottom.")
    B = moss_drape("drape_B", 1202, [
        dict(c=(0.0, -0.12), rx=0.75, ry=0.68, n=9, H=0.14, base=0.0, lip=0.2, rings=[(0.78, 0.65), (0.52, 1.0)],
             cols=(g[1], g[2], g[0])),
        dict(c=(-0.1, -0.25), rx=0.48, ry=0.42, n=7, H=0.09, base=0.12, lip=0.3, rings=[(0.58, 1.0)], cols=l2)],
        "small soft moss patch, 1.5 wide, 0.55 over the top and 0.8 down the front: 2 stacked rounded layers "
        "(#589642 -> #60C448), the plateau slightly down the front (drip lip).")
    C = moss_drape("drape_C", 1303, [
        dict(c=(0.0, -0.55), rx=1.2, ry=1.3, n=10, H=0.18, base=0.0, lip=0.2, rings=[(0.8, 0.65), (0.55, 1.0)],
             cols=(g[1], g[2], g[0])),
        dict(c=(0.2, -0.6), rx=0.8, ry=0.8, n=8, H=0.12, base=0.16, lip=0.2, rings=[(0.6, 1.0)], cols=l2),
        dict(c=(-0.3, -1.45), rx=0.45, ry=0.42, n=7, H=0.1, base=0.12, lip=0.3, rings=[(0.55, 1.0)], cols=l3)],
        "long moss drape, 2.4 wide, 0.75 over the top and 1.9 down the front (cornices, brows, the temple forehead): "
        "3 stacked rounded layers (#589642 -> #60C448 -> #78D246), the top layer a hanging drip lobe at the bottom.")
    return [A, B, C]


def vine_strand():
    rng = random.Random(1404)
    pc = Piece("vine", "strand", "the strand's own anchor: (0, 0, 0) = the TOP ATTACH POINT; it hangs down -Y, 6.0 long, "
               "leaves toward -Z (front) and the sides",
               place={"relativeTo": "under a cornice / brow / eave edge", "position": "the anchor just under the edge, "
                      "0.1-0.3 in front of the face", "orientation": "any yaw (leaves face the camera side best at 0)",
                      "scale": "uniform 0.6..1.2 (3.6..7.2 long); longer vines = 2 strands chained (the second's anchor "
                      "at the first's tip (0, -6, 0) x scale), groups of 2-3 of different lengths. Gate_Jungle_4: the 4 "
                      "Vine sticks become 2 + 1 chained strands each (13 and 8 long)."},
               notes="tapering hanging vine: a 3-sided stem 0.18 -> 0.06 thick in 5 swaying segments (#46AA3C), 9 small "
                     "leaves (0.55 x 0.32, folded on the midrib, alternating sides, #78D246 / #60C448), a 2-leaf tip.")
    ys = [0.0, -1.2, -2.4, -3.6, -4.8, -6.0]
    pts = [Vector((0.12 * math.sin(i * 1.3), y, -0.06 * math.sin(i * 0.9 + 0.5))) for i, y in enumerate(ys)]
    radii = [0.09, 0.08, 0.065, 0.05, 0.04, 0.03]

    def col(s, k):
        return tone(JVINE, (1.0, 0.93, 0.86)[k % 3])
    tube_faces(pc, pts, radii, 3, col, 0.04)

    def leaf(p, side, down, L, W, c1, c2):
        d = Vector((side * 0.8, -down, -0.35)).normalized()
        b = p + Vector((side * 0.04, 0, -0.03))
        tip = b + d * L
        perp = d.cross(Vector((0, 0, -1)))
        if perp.length < 1e-6:
            perp = Vector((1, 0, 0))
        perp.normalize()
        mid = b + d * (L * 0.42)
        fold = Vector((0, 0, -1)) * 0.05 + Vector((0, 0.03, 0))
        m1 = mid + perp * (W / 2) - fold
        m2 = mid - perp * (W / 2) - fold
        rib_n = d.cross(perp)
        if rib_n.z > 0:
            rib_n = -rib_n
        pc.face([b, m1, tip], c1, "SmoothPlastic", 0.05, rib_n)
        pc.face([b, tip, m2], c2, "SmoothPlastic", 0.05, rib_n)

    for i in range(9):
        y = -0.45 - i * 0.62
        seg = min(int(-y / 1.2), 4)
        f = (-y - 1.2 * seg) / 1.2
        p = pts[seg].lerp(pts[seg + 1], f)
        side = 1 if i % 2 == 0 else -1
        sc = 1.0 - 0.25 * (i / 8)
        leaf(p, side, rng.uniform(0.35, 0.6), 0.55 * sc, 0.32 * sc, JMOSS_LL if i % 2 else JMOSS_L, tone(JMOSS_L, 0.88))
    for side in (-1, 1):
        leaf(pts[-1], side * 0.6, 0.9, 0.42, 0.26, JMOSS_LL, tone(JMOSS_L, 0.88))
    return [pc]


def thatch_roof():
    rng = random.Random(1505)
    pc = Piece("hut", "thatch_roof", "the TribalHut_A kit pivot (base centre, y 0 = the ground, front -Z)",
               place={"relativeTo": "the TribalHut_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "keeps": "the 2 Roof wedges (the core, under the thatch) and the Ridge beam"},
               notes="layered thatch over today's roof wedges (eaves y 12.4 at z +-7.75, ridge y 19.4 at z 0): on each "
                     "slope 4 overlapping rows of straw bundles (8 bundles per row, alternating tones, each row tucked "
                     "under the one above and standing 0.4 off the slope at its bottom), a jagged fringe of straw tips "
                     "under every row (the last one hangs 0.35 past the eave), sawtooth row ends on the gables, and a "
                     "straw ridge cap beside the ridge beam with its own fringe. #C4A068 (+ #D8C080 cap).")
    L = math.hypot(7.75, 7.0)
    X0, X1 = -8.0, 8.0
    for zs in (1, -1):
        nrm = Vector((0, 7.75, 7.0 * zs)).normalized()
        dwn = Vector((0, -7.0, 7.75 * zs)).normalized()
        ridge = Vector((0, 19.4, 0))

        def P_(x, s, h):
            return Vector((x, 0, 0)) + ridge + dwn * s + nrm * h
        rows = 4
        b_prev = None
        for r in range(rows):
            b = L * (r + 1) / rows + (0.35 if r == rows - 1 else 0.0)
            a = 1.6 if r == 0 else b_prev - 0.75
            ncol = 8
            w = (X1 - X0) / ncol
            rowk = 1.0 - 0.035 * r
            for c in range(ncol):
                xa, xb = X0 + c * w, X0 + (c + 1) * w
                col = tone(THATCH, rowk * STEPS[(c + r) % 2 if rng.random() < 0.8 else 2])
                pc.face([P_(xa, a, 0.05), P_(xb, a, 0.05), P_(xb, b, 0.42), P_(xa, b, 0.42)], col, "SmoothPlastic", 0.12, nrm)
            nt = 16
            tw = (X1 - X0) / nt
            for k in range(nt):
                xa, xb = X0 + k * tw, X0 + (k + 1) * tw
                xm = (xa + xb) / 2 + rng.uniform(-0.15, 0.15)
                drop = rng.uniform(0.25, 0.45) + (0.15 if r == rows - 1 else 0.0)
                tip = P_(xm, b + drop, 0.08)
                pc.face([P_(xa, b, 0.42), P_(xb, b, 0.42), tip], tone(THATCH, rowk * 0.84), "SmoothPlastic", 0.08,
                        dwn + nrm * 0.5)
            for x, sx in ((X0, -1), (X1, 1)):
                pc.face([P_(x, a, 0.05), P_(x, b, 0.42), P_(x, b, 0.0)], tone(THATCH, 0.8), "SmoothPlastic", 0.1,
                        Vector((sx, 0, 0)))
            b_prev = b
        # ridge cap: 4 bundles from the beam's side down to the first row, with a fringe
        for c in range(4):
            xa, xb = -8.0 + c * 4.0, -8.0 + (c + 1) * 4.0
            top = [Vector((xa, 19.85, 0.6 * zs)), Vector((xb, 19.85, 0.6 * zs))]
            bot = [P_(xb, 2.2, 0.55), P_(xa, 2.2, 0.55)]
            pc.quad_or_tris([top[0], top[1], bot[0], bot[1]], tone(THATCH_L, STEPS[c % 2]), "SmoothPlastic", 0.12, nrm)
            for k in range(2):
                ta, tb = xa + k * 2.0, xa + (k + 1) * 2.0
                tip = P_((ta + tb) / 2 + rng.uniform(-0.2, 0.2), 2.2 + rng.uniform(0.35, 0.55), 0.3)
                pc.face([P_(ta, 2.2, 0.55), P_(tb, 2.2, 0.55), tip], tone(THATCH_L, 0.85), "SmoothPlastic", 0.08, dwn + nrm * 0.5)
    return [pc]


def jungle_buildings():
    return carved_face() + temple_face() + moss_pieces() + vine_strand() + thatch_roof()


def preview_jungle(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    cf = [((0, 6, 0.5), (10, 12, 5), JSTONE, (0, 0, 0)), ((0, 12.9, 0.5), (11, 2, 5.6), JSTONE_D, (0, 0, 0)),
          ((0, 14.7, 0.5), (4.4, 1.8, 5), JSTONE, (0, 0, 0)), ((0, 12.9, -2.45), (1.3, 1.3, 0.5), GOLD, (0, 0, 45)),
          ((-2.3, 7.3, -2.05), (2.8, 2, 0.5), JREC, (0, 0, 0)), ((2.3, 7.3, -2.05), (2.8, 2, 0.5), JREC, (0, 0, 0)),
          ((-2.3, 7.3, -2.25), (1.8, 1.1, 0.4), "#78FFBE", (0, 0, 0)), ((2.3, 7.3, -2.25), (1.8, 1.1, 0.4), "#78FFBE", (0, 0, 0)),
          ((0, 2.5, -2.05), (5.6, 1.4, 0.5), JREC, (0, 0, 0)), ((-5.6, 7, 0.5), (1.4, 4, 3), JSTONE_D, (0, 0, 0)),
          ((5.6, 7, 0.5), (1.4, 4, 3), JSTONE_D, (0, 0, 0)), ((-5.6, 4.4, 0.2), (1.2, 1.2, 1.2), GOLD, (0, 0, 0)),
          ((5.6, 4.4, 0.2), (1.2, 1.2, 1.2), GOLD, (0, 0, 0))]
    cf += [((x, 2.8, -2.3), (0.8, 0.8, 0.4), "#E8E2D0", (0, 0, 0)) for x in (-1.8, -0.6, 0.6, 1.8)]
    g1 = context_boxes(cf, col) + [piece_object(by["face__brow"], col), piece_object(by["face__nose_lips"], col)]
    g1.append(piece_object(by["moss__drape_A"], col, Vector((-2.8, 13.9, -2.3))))
    g1.append(piece_object(by["moss__drape_B"], col, Vector((3.4, 13.9, -2.3))))
    for x, s in ((-4.4, 0.75), (-3.7, 0.55), (4.6, 0.65)):
        g1.append(piece_object(by["vine__strand"], col, Vector((x, 11.85, -2.15)), None, s))
    ox = 40.0
    gf = [((0, 29, 1.5), (56, 22, 11), JSTONE, (0, 0, 0)), ((0, 41.6, 1.5), (58, 3.4, 12.6), JSTONE_D, (0, 0, 0)),
          ((0, 46, 2), (30, 5.4, 10), JSTONE, (0, 0, 0)), ((0, 50.7, 2), (14, 4, 9), JSTONE_D, (0, 0, 0)),
          ((-22.5, 45, 2), (9, 6, 10), JSTONE, (0, 0, 0)), ((22.5, 45, 2), (9, 6, 10), JSTONE, (0, 0, 0)),
          ((0, 45.2, -3.2), (5, 5, 1), GOLD, (0, 0, 45)), ((0, 18.5, 0.5), (28, 5, 13), JSTONE_D, (0, 0, 0)),
          ((-30.4, 27, 2), (5, 15, 8), JSTONE_D, (0, 0, 0)), ((30.4, 27, 2), (5, 15, 8), JSTONE_D, (0, 0, 0))]
    for sx in (-1, 1):
        gf += [((13 * sx, 31, -4.3), (10, 6, 1), JREC, (0, 0, 0)), ((13 * sx, 31, -4.8), (7.4, 3.4, 0.6), "#78FFBE", (0, 0, 0)),
               ((13 * sx, 31, -4.9), (1.8, 3.4, 0.7), JREC, (0, 0, 0))]
    gf = [((p[0] + ox, p[1] - 15, p[2]), s, c, r) for p, s, c, r in gf]
    off = Vector((ox, -15, 0))
    g2 = context_boxes(gf, col) + [piece_object(by["temple__brow"], col, off), piece_object(by["temple__nose"], col, off)]
    for x, nm, sc in ((-20, "drape_C", 2.2), (-8, "drape_A", 2.0), (12, "drape_B", 2.4), (24, "drape_C", 1.8)):
        g2.append(piece_object(by["moss__" + nm], col, off + Vector((x, 43.3, -4.8)), None, sc))
    for x, sc in ((-26.5, 1.9), (-24.8, 1.3), (26.5, 1.6), (5.5, 1.3), (-5.5, 1.1)):
        g2.append(piece_object(by["vine__strand"], col, off + Vector((x, 39.8, -4.4)), None, sc))
    hx = 80.0
    hb = [((5.6 * a, 2.5, 5.6 * b), (1.1, 5, 1.1), JWOOD_D, (0, 0, 0)) for a in (-1, 1) for b in (-1, 1)]
    hb += [((0, 5, 0), (14, 0.8, 14), "#A86238", (0, 0, 0)), ((0, 8.9, 0), (11, 7, 11), "#D6965C", (0, 0, 0)),
           ((0, 6.0, 0), (11.4, 0.6, 11.4), JWOOD_D, (0, 0, 0)), ((0, 12.1, 0), (11.4, 0.6, 11.4), JWOOD_D, (0, 0, 0)),
           ((0, 8.2, -5.6), (4, 5.6, 0.4), "#4A3022", (0, 0, 0)), ((0, 11.2, -5.7), (1.1, 1.1, 0.3), "#C44632", (0, 0, 45)),
           ((0, 19.5, 0), (16, 0.8, 1.2), JWOOD_D, (0, 0, 0))]
    hb = [((p[0] + hx, p[1], p[2]), s, c, r) for p, s, c, r in hb]
    g3 = context_boxes(hb, col) + [piece_object(by["hut__thatch_roof"], col, Vector((hx, 0, 0)))]
    mx = 120.0
    g4 = context_boxes([((mx, 1.5, 1.5), (9, 3, 3), JSTONE, (0, 0, 0))], col)
    for x, nm in ((-3, "drape_A"), (0, "drape_B"), (3, "drape_C")):
        g4.append(piece_object(by["moss__" + nm], col, Vector((mx + x, 3.0, 0.0))))
    out = os.path.join(P.PREVIEW_DIR, "jungle_buildings_facets.png")
    return render_sheet("jungle", [(g1, [(-28, 8)]), (g1[-7:-5], [(-60, 5)]), (g2, [(-22, 10)]), (g3, [(-35, 14)]),
                                   (g4, [(-35, 30)])], None, out)


# ------------------------------------------------------------------------------------------------
# JUNGLE GATES AND ENTRANCES (guide section C3): root arch, rock cave, totem wings, animal skulls.
# ------------------------------------------------------------------------------------------------
ROOT_D, ROOT_M, ROOT_L, ROOT_DD = "#4D3223", "#634029", "#68442C", "#422B1E"
BONE, TEAL, TRED, JLEAF_D = "#E8E2D0", "#3CAABE", "#C44632", "#289642"


def helix_path(path, radii, turns, phase, lift=0.95, start=0.0, end=1.0, n=8):
    """Points of a thin root twisting round a thick one: path / radii of the thick root (polyline), the thin one
    runs from fraction start to end of it, `turns` times round, at lift x the thick radius from its axis."""
    path = [Vector(p) for p in path]
    seg_len = [(path[i + 1] - path[i]).length for i in range(len(path) - 1)]
    total = sum(seg_len)
    out = []
    for k in range(n):
        f = start + (end - start) * k / (n - 1)
        d = f * total
        i = 0
        while i < len(seg_len) - 1 and d > seg_len[i]:
            d -= seg_len[i]
            i += 1
        g = min(d / seg_len[i], 1.0)
        c = path[i].lerp(path[i + 1], g)
        r = radii[i] + (radii[i + 1] - radii[i]) * g
        t = (path[i + 1] - path[i]).normalized()
        u = t.cross(Vector((0, 0, 1)))
        if u.length < 1e-6:
            u = Vector((1, 0, 0))
        u.normalize()
        v = t.cross(u).normalized()
        a = phase + 2 * math.pi * turns * (k / (n - 1))
        out.append(c + (u * math.cos(a) + v * math.sin(a)) * r * lift)
    return out


def bark_col(base, rng):
    def col(s, k):
        return tone(base, (0.8 if k % 3 == 1 else STEPS[(s + k) % 2]) * (0.9 + 0.1 * min(s, 4) / 4))
    return col


def knot(pc, c, r, rng, color):
    pts = [Vector(c) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized() * r * rng.uniform(0.7, 1.0)
           for _ in range(8)]
    hull_into(pc, pts, lambda cc, n: tone(color, 0.75 if n.y < 0 else 0.88), 0.25)


def root_arch_side(sgn, seed):
    rng = random.Random(seed)
    side = "L" if sgn < 0 else "R"
    pc = Piece("root_arch", f"side_{side}", "the Root_Arch_A kit pivot (centre of the passage at ground level, front -Z)",
               place={"relativeTo": "the Root_Arch_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": f"the 4 Root blocks, the RootSmall brace and the RootFoot wedge of the {'left (x < 0)' if sgn < 0 else 'right (x > 0)'} side; "
                                  "keep CanCollide with 2-3 hidden boxes along the root"},
               notes="twisted tapering root pillar: a main root (6-sided, radius 3.2 at the flared foot -> 2.1 where it "
                     "enters the crown) climbing in a curve from the soil to the crown, 2 thinner roots twisting round it, "
                     "2 small roots splaying into the soil, 2 knots; bark lines = darker face columns. #634029 / #4D3223. "
                     "The passage is kept: inner face >= |x| 12.75 below y 11, everything under the crown above y 18.")
    path = [(-19.5, -1.4, 0.4), (-17.0, 2.5, 0.0), (-16.1, 7.0, -0.3), (-15.9, 11.0, 0.2), (-14.6, 14.8, 0.0),
            (-12.0, 18.0, -0.2), (-9.0, 20.6, 0.1), (-5.5, 22.2, 0.0)]
    path = [Vector((sgn * -x, y, z)) for x, y, z in path]
    radii = [3.2, 2.9, 2.7, 2.6, 2.5, 2.4, 2.3, 2.1]
    tube_faces(pc, path, radii, 6, bark_col(ROOT_M if sgn < 0 else ROOT_D, rng), 0.5)
    for ph, turns, st, en, r0, r1, colr in ((rng.uniform(0, 6.3), 1.3, 0.02, 0.85, 0.95, 0.35, ROOT_L),
                                           (rng.uniform(0, 6.3), -1.0, 0.0, 0.62, 0.8, 0.3, ROOT_DD)):
        hp = helix_path(path, radii, turns, ph, 0.98, st, en, 8)
        rr = [r0 + (r1 - r0) * k / 7 for k in range(8)]
        tube_faces(pc, hp, rr, 4, lambda s, k, colr=colr: tone(colr, STEPS[k % 3]), 0.25, cap_end=True)
    for dz in (-1, 1):
        foot = [Vector((sgn * 17.6, 1.4, 1.6 * dz)), Vector((sgn * 20.6, 0.2, 2.8 * dz)), Vector((sgn * 23.2, -0.9, 3.6 * dz))]
        tube_faces(pc, foot, [1.2, 0.8, 0.35], 4, lambda s, k: tone(ROOT_DD, STEPS[k % 3]), 0.25)
    knot(pc, (sgn * 17.7, 5.0, -2.2), 0.7, rng, ROOT_M)
    knot(pc, (sgn * 16.6, 12.5, -2.0), 0.55, rng, ROOT_M)
    return pc


def leaf_cluster(pc, c, size, rng, n=9):
    pts = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.5, 1.0)
        pts.append(Vector(c) + Vector((math.cos(a) * size[0] * math.cos(e), math.sin(e) * size[1], math.sin(a) * size[2] * math.cos(e))))

    def col(cc, nrm):
        if nrm.y > 0.55:
            return JMOSS_LL if rng.random() < 0.6 else JMOSS_L
        if nrm.y < -0.3:
            return JLEAF_D
        return JMOSS if rng.random() < 0.5 else tone(JMOSS_L, 0.9)
    hull_into(pc, pts, col, 0.3)


def root_arch_crown():
    rng = random.Random(2202)
    pc = Piece("root_arch", "crown", "the Root_Arch_A kit pivot (centre of the passage at ground level, front -Z)",
               place={"relativeTo": "the Root_Arch_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the crown Root (12.2 x 4.4 at (0, 21.5)) and the 3 flat Moss slabs; add moss__drape_A/C on its "
                                  "front edge (anchor ~(x, 24.0, -2.0), scale 1.2) and 3-5 vine__strand under it (anchor y ~19.6, "
                                  "z -1.5, scale 0.6-1.1)"},
               notes="crown of the root arch: a thick root (radius 2.6, underside >= y 19.4 = today's passage height 19.3) "
                     "sagging slightly, a thinner root wrapped 1.5 times round it, 4 low-poly leaf clusters on top "
                     "(#78D246 / #60C448 tops, #289642 undersides).")
    path = [Vector((-8.2, 22.8, 0.1)), Vector((-4.0, 22.4, -0.1)), Vector((0.0, 22.35, 0.0)), Vector((4.0, 22.4, 0.15)),
            Vector((8.2, 22.8, 0.0))]
    radii = [2.3, 2.5, 2.6, 2.5, 2.3]
    rings = tube_faces(pc, path, radii, 6, bark_col(ROOT_DD, rng), 0.5, cap_end=True)
    polygon_fill(pc, rings[0], tone(ROOT_DD, 0.86), "SmoothPlastic", 0.5, path[0] - path[1])
    hp = helix_path(path, radii, 1.5, 0.6, 0.98, 0.05, 0.95, 9)
    tube_faces(pc, hp, [0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4], 4, lambda s, k: tone(ROOT_L, STEPS[k % 3]), 0.25,
               cap_end=True)
    for c, s in (((-5.4, 24.8, 0.3), (2.6, 1.1, 2.1)), ((-1.0, 25.1, -0.2), (2.8, 1.2, 2.3)), ((3.6, 24.9, 0.4), (2.5, 1.1, 2.0)),
                 ((6.9, 24.5, -0.1), (1.9, 1.0, 1.7))):
        leaf_cluster(pc, c, s, rng)
    return pc


def layered_rock(pc, layers, rng, base, inner_x=None, inner_top=11.0, n=10, cracks=(), bottom=False, peak=True):
    """Natural stacked rock: layers [(y0, y1, cx, cz, hx, hz)]: each a squashed jittered ring hull, a little
    offset; 3 tone steps, darker low. inner_x: clamps the points so the opening edge stays (|x| >= inner_x below
    inner_top). cracks: [(x, y, length, angle)] dark strips laid on the front (ray along +Z)."""
    trees = []
    H = max(l[1] for l in layers)
    for li, (y0, y1, cx, cz, hx, hz) in enumerate(layers):
        pts = []
        top_k = 0.8 if li == len(layers) - 1 else 0.93
        for yy, k in ((y0, 1.0), (y1, top_k)):
            a0 = rng.uniform(0, 2 * math.pi / n)
            for i in range(n):
                a = a0 + 2 * math.pi * i / n + rng.uniform(-0.12, 0.12)
                c, s = math.cos(a), math.sin(a)
                r = (abs(c) ** 3 + abs(s) ** 3) ** (-1 / 3) * rng.uniform(0.86, 1.04) * k
                x = cx + hx * r * c
                z = cz + hz * r * s
                y = yy + (rng.uniform(-0.25, 0.25) if 0 < yy < H else 0.0)
                if inner_x is not None and y <= inner_top + 0.5:
                    x = min(x, -inner_x) if inner_x > 0 and cx < 0 else (max(x, inner_x) if cx > 0 else x)
                pts.append(Vector((x, y, z)))
        if peak and li == len(layers) - 1:
            pts.append(Vector((cx + rng.uniform(-0.2, 0.2) * hx, y1 + 0.5, cz)))
        g = 0.82 + 0.18 * ((y0 + y1) / 2 / H)

        def col(cc, nrm, g=g):
            if nrm.y > 0.6:
                return tone(base, min(1.05, g + 0.08))
            return tone(base, g * rng.choice(STEPS))
        skip = (lambda ring: all(p.y < 0.05 for p in ring)) if not bottom else None
        trees.append(hull_into(pc, pts, col, 0.6, skip=skip))
    for x, y, L, ang in cracks:
        for tree in trees:
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            pts2 = [(-0.08, -L / 2), (0.08, -L / 2), (0.14 + 0.25, 0.0), (0.02 + 0.25, 0.0)]
            pts2b = [(0.02 + 0.25, 0.0), (0.14 + 0.25, 0.0), (0.12, L / 2), (-0.02, L / 2)]
            ok = surface_quad(pc, tree, (x, y, -30), (0, 0, 1), [(u * ca - v * sa, u * sa + v * ca) for u, v in pts2], JREC,
                              "SmoothPlastic", 0.1, 0.03)
            if ok:
                surface_quad(pc, tree, (x, y, -30), (0, 0, 1), [(u * ca - v * sa, u * sa + v * ca) for u, v in pts2b], JREC,
                             "SmoothPlastic", 0.1, 0.03)
                break
    return trees


CAVE_ORIGIN = "the Jaguar_Den_Rocks kit pivot (centre of the cave opening at ground level, front -Z)"


def cave_pieces():
    rng = random.Random(2303)
    out = []
    for sgn, base, H, name in ((-1, JSTONE, 13.6, "rock_L"), (1, "#7D8376", 13.0, "rock_R")):
        pc = Piece("cave", name, CAVE_ORIGIN,
                   place={"relativeTo": "the Jaguar_Den_Rocks model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                          "replaces": f"the {'left' if sgn < 0 else 'right'} Rock MeshPart; keep its CanCollide (the union or a hidden box)"},
                   notes="faceted layered boulder: 4 stacked natural layers (squashed jittered hulls, each offset a little, "
                         "the top one rounded), darker at the bottom, 3 tone steps, 3 dark cracks on the front. Its inner "
                         "face is clamped at |x| = 7.0 up to y 11.5 = today's opening (14 x 11) is kept.")
        cx = sgn * 15.0
        L = [(0.0, 3.6, cx, 3.0, 8.4, 7.8), (3.5, 7.4, cx + sgn * 0.3, 3.3, 8.0, 7.4), (7.3, 10.9, cx - sgn * 0.2, 2.8, 7.6, 7.0),
             (10.8, H, cx + sgn * 0.6, 3.4, 6.6, 6.0)]
        cr = [(cx + sgn * 2.0, 5.0, 3.0, 15), (cx - sgn * 3.5, 9.0, 2.4, -20), (cx + sgn * 4.5, 2.0, 2.0, 5)]
        layered_rock(pc, L, rng, base, inner_x=7.0, inner_top=11.0, cracks=cr)
        out.append(pc)
    pc = Piece("cave", "top_slab", CAVE_ORIGIN,
               place={"relativeTo": "the Jaguar_Den_Rocks model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the Roof and Moss MeshParts; keep the Roof's CanCollide; add moss__drape_C / A on the slab's front "
                                  "edge (anchor ~(x, 15.9, -5.6), scale 1.6-2.2) and 2-3 vine__strand"},
               notes="the big top slab: 2 stacked layers (lower 38 x 3.2 x 20, upper smaller and set back), underside "
                     "y 12.6 (>= the opening's 11, today's roof underside ~13), a soft 2-layer moss cap (#589642 -> "
                     "#60C448) on top and 9 grass tufts (3 blades each, #78D246 / #60C448).")
    L = [(12.6, 15.9, 0.0, 4.0, 19.0, 10.0), (15.8, 18.2, -0.8, 5.2, 14.5, 7.6)]
    layered_rock(pc, L, rng, JSTONE_D, n=12, bottom=True, peak=False, cracks=[(-9.0, 14.2, 2.2, 70), (6.0, 14.0, 2.0, 100)])
    # soft moss cap on the upper layer's top (y ~18.2)
    ytop = 18.2
    for cxz, (rx, rz), h0, H, cols, n, k_in in (((-0.6, 5.2), (11.0, 5.4), 0.05, 0.28, (JMOSS, tone(JMOSS, 0.9)), 10, 0.72),
                                               ((-1.6, 5.0), (6.5, 3.4), 0.31, 0.2, (JMOSS_L, tone(JMOSS_L, 0.92)), 8, 0.65)):
        a0 = rng.uniform(0, 1)
        ring = []
        for i in range(n):
            a = a0 + 2 * math.pi * i / n + rng.uniform(-0.12, 0.12)
            r = rng.uniform(0.88, 1.05)
            ring.append(Vector((cxz[0] + rx * r * math.cos(a), ytop + h0, cxz[1] + rz * r * math.sin(a))))
        c = Vector((cxz[0], ytop + h0, cxz[1]))
        inner = [c + (p - c) * k_in + Vector((0, H, 0)) for p in ring]
        for i in range(n):
            j = (i + 1) % n
            pc.face([ring[i], ring[j], inner[j], inner[i]], cols[1], "SmoothPlastic", 0.15, Vector((0, 1, 0)))
        polygon_fill(pc, inner, cols[0], "SmoothPlastic", 0.15, Vector((0, 1, 0)))
    for i in range(9):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.3, 0.95)
        base = Vector((-0.6 + 9.5 * r * math.cos(a), ytop + 0.3, 5.2 + 4.6 * r * math.sin(a)))
        for b in range(3):
            ang = rng.uniform(0, 2 * math.pi)
            d = Vector((math.cos(ang), 0, math.sin(ang)))
            w = Vector((-d.z, 0, d.x)) * 0.18
            tip = base + d * rng.uniform(0.3, 0.6) + Vector((0, rng.uniform(0.8, 1.3), 0))
            pc.face([base - w, base + w, tip], JMOSS_LL if b % 2 else JMOSS_L, "SmoothPlastic", 0.06, Vector((d.z, 0.0, -d.x)))
    out.append(pc)
    return out


def wing_into(pc, sgn, root, ang_deg=16.0, k=1.0):
    """Carved feathered totem wing (C3 / C5): a bevelled arm bar from `root` (the head's side face) outward and up
    at ang_deg, then 3 overlapping rows of pointed feathers fanning from straight down (inner) to outward (tip).
    k scales the lengths / widths (the thickness stays 0.7)."""
    ca, sa = math.cos(math.radians(ang_deg)), math.sin(math.radians(ang_deg))
    root = Vector(root)

    def W(u, v, z):
        return root + Vector((sgn * u * k * ca, v * k + u * k * sa, z))
    prof = [(0.35, -0.1), (0.5, 0.0), (0.35, 0.1), (-0.35, 0.1), (-0.5, 0.0), (-0.35, -0.1)]
    prof = [(v, z * 3.5) for v, z in prof]
    secs = [[W(u, v * 1.0, z) for v, z in prof] for u in (0.0, 3.0, 5.6)]
    for i in range(2):
        a, b = secs[i], secs[i + 1]
        for kk in range(6):
            j = (kk + 1) % 6
            q = [a[kk], b[kk], b[j], a[j]]
            mid = (a[kk] + a[j] + b[kk] + b[j]) / 4
            axis = sum(a + b, Vector()) / 12
            pc.quad_or_tris(q, tone(TEAL, (1.0, 0.93, 0.86)[kk % 3]), "SmoothPlastic", 0.3, mid - axis)
    polygon_fill(pc, secs[-1], tone(TEAL, 0.9), "SmoothPlastic", 0.3, secs[-1][0] - secs[-2][0])

    def feather(u0, length, width, z, col, tip_col=None, ang=-60.0):
        d = Vector((math.cos(math.radians(ang)), math.sin(math.radians(ang))))
        nn = Vector((-d.y, d.x))
        p = lambda s_, w: W(u0 + d.x * s_ + nn.x * w, -0.2 + d.y * s_ + nn.y * w, z)
        a1, a2 = p(0.0, -width / 2), p(0.0, width / 2)
        b1, b2 = p(length * 0.72, -width / 2), p(length * 0.72, width / 2)
        tip = p(length, 0.0)
        pc.face([a1, a2, b2, b1], col, "SmoothPlastic", 0.22, Vector((0, 0, -1)))
        pc.face([b1, b2, tip], tip_col or col, "SmoothPlastic", 0.22, Vector((0, 0, -1)))
    for i in range(5):
        feather(1.0 + i * 0.95, 2.2 + 0.25 * i, 1.0, 0.2, tone(TEAL, 0.86), GOLD, -80.0 + 12.0 * i)
    for i in range(5):
        feather(0.7 + i * 0.95, 1.6 + 0.15 * i, 0.95, -0.05, TEAL, None, -84.0 + 11.0 * i)
    for i in range(4):
        feather(0.6 + i * 1.15, 1.0, 1.0, -0.3, mix(TEAL, "#FFFFFF", 0.3), None, -75.0 + 9.0 * i)


def totem_wings():
    out = []
    for sgn in (-1, 1):
        side = "L" if sgn < 0 else "R"
        pc = Piece("totem", f"wing_{side}", "the EntryArch_Jungle kit pivot (centre of the passage at ground level, front -Z)",
                   place={"relativeTo": "the EntryArch_Jungle model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                          "replaces": f"the {'left' if sgn < 0 else 'right'} Wing (5.4 x 2.6 x 0.7 at ({sgn * 20.1}, 12.6, 0), tilted 16 deg); "
                                      "keep its CanCollide on a hidden box"},
                   notes="carved feathered totem wing on the side of the teal head: a bevelled arm bar along the top, then 3 "
                         "overlapping rows of feathers with pointed tips fanning from straight down (inner) to outward (tip) (primaries #3CAABE x0.86 "
                         "with gold tips, secondaries #3CAABE, coverts lighter), each row a little in front of the one "
                         "behind. Rises outward 16 deg like today; about 7.5 long (today 5.4), 4.5 tall, 0.7 thick.")
        wing_into(pc, sgn, (sgn * 17.65, 13.4, 0.0), 16.0, 1.0)
        out.append(pc)
    return out


SKULL_PTS = [(1.2, 1.0, 0.9), (1.2, 1.0, -0.5), (0.6, 1.3, 0.2), (0.0, 1.32, -0.4), (1.3, 0.4, -1.0), (1.1, 0.0, 0.9),
             (0.9, -0.4, -1.1), (0.55, -1.1, -1.2), (0.45, -1.4, -0.85), (0.6, -1.2, 0.2), (0.0, -1.45, -1.05)]


def skull_into(pc, R, scale, off, horns=True, rng=None):
    """Bleached animal (bull) skull, local frame: snout down -Y, face -Z, cranium 2.6 wide; R / scale / off map the
    local frame to the piece's space."""
    def xf(p):
        return R @ (Vector(p) * scale) + Vector(off)
    pts = []
    for x, y, z in SKULL_PTS:
        for s in ((1, -1) if x > 0 else (1,)):
            pts.append(xf((s * x, y, z)))

    def col(cc, n):
        ln = R.inverted() @ n
        if ln.z > 0.6:
            return tone(BONE, 0.8)
        if ln.y < -0.5:
            return tone(BONE, 0.86)
        return tone(BONE, 1.0 if ln.y > 0.3 else 0.95)
    tree = hull_into(pc, pts, col, 0.25 * scale)
    fwd = R @ Vector((0, 0, 1))
    for sx in (-1, 1):
        o = xf((sx * 0.62, 0.2, -4.0))
        surface_quad(pc, tree, o, fwd, [(-0.32 * scale, -0.22 * scale), (0.3 * scale, -0.28 * scale), (0.34 * scale, 0.2 * scale),
                                        (-0.28 * scale, 0.26 * scale)], JREC, "SmoothPlastic", 0.2 * scale, 0.03 * scale)
        o = xf((sx * 0.2, -1.05, -4.0))
        surface_quad(pc, tree, o, fwd, [(-0.1 * scale, -0.16 * scale), (0.1 * scale, -0.16 * scale), (0.0, 0.16 * scale)], JREC,
                     "SmoothPlastic", 0.12 * scale, 0.03 * scale)
    o = xf((-0.3, 0.95, -4.0))
    surface_quad(pc, tree, o, fwd, [(-0.03 * scale, -0.4 * scale), (0.04 * scale, -0.4 * scale), (0.05 * scale, 0.3 * scale),
                                    (-0.02 * scale, 0.3 * scale)], tone(BONE, 0.6), "SmoothPlastic", 0.08 * scale, 0.02 * scale)
    if horns:
        for sx in (-1, 1):
            hp = [(1.15, 0.85, -0.1), (2.0, 1.1, -0.15), (2.8, 1.7, -0.25), (3.25, 2.6, -0.35), (3.1, 3.5, -0.45), (2.7, 4.0, -0.5)]
            hp = [xf((sx * x, y, z)) for x, y, z in hp]
            tube_faces(pc, hp, [0.45 * scale, 0.4 * scale, 0.32 * scale, 0.24 * scale, 0.16 * scale, 0.07 * scale], 6,
                       lambda s, k: mix(BONE, THATCH, 0.12 * s) if s % 2 == 0 else tone(mix(BONE, THATCH, 0.12 * s), 0.88), 0.2 * scale)
    return tree


def skull_pieces():
    from mathutils import Matrix
    hz = Piece("skull", "horned", "the Gate_Jungle_2 kit pivot (centre of the passage at ground level, front -Z)",
               place={"relativeTo": "the Gate_Jungle_2 model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "Skull, the 2 SkullEyes and the 2 Horns on top of the sign (NOT Barrier children)"},
               notes="bleached horned bull skull mounted on the sign: cranium 2.6 wide, the long face pointing down, deep "
                     "dark eye sockets, 2 nasal holes, a crack, 2 curved ribbed horns (6-sided, tapering 0.45 -> 0.07, "
                     "#E8E2D0 yellowing to the tips). Sits on the SignBack top (y 24.3), snout tip above the price text.")
    skull_into(hz, Matrix.Identity(3), 1.0, (0.0, 25.75, -1.25), True)
    sm = Piece("skull", "small", "the piece's own anchor: (0, 0, 0) = the centre under the skull on the ground; the snout points -Z",
               place={"relativeTo": "Jaguar_Den_Rocks (kit pivot) and any bone pile", "position": [4.5, 0, -4.5],
                      "orientation": [0, 25, 0], "scale": 1.0, "replaces": "the Skull part (1.5 x 1.3 x 1.6) of the cave"},
               notes="the same skull lying on the ground without horns, 1.5 wide x 1.3 tall x 1.6 long (face up, snout "
                     "forward -Z): sockets and nasal holes on top.")
    rot = Matrix.Rotation(math.radians(90.0), 3, "X")
    skull_into(sm, rot, 1.5 / 2.6, (0.0, 0.0, 0.0), False)
    lo = min(p.y for f in sm.faces for p in f["v"])
    for f in sm.faces:
        f["v"] = [Vector((p.x, p.y - lo, p.z)) for p in f["v"]]
    return [hz, sm]


def jungle_gates():
    return [root_arch_side(-1, 2101), root_arch_side(1, 2102), root_arch_crown()] + cave_pieces() + totem_wings() + skull_pieces()


def preview_jungle_gates(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    extra = {f"{p.obj}__{p.name}": p for p in moss_pieces() + vine_strand()}
    g1 = [piece_object(by["root_arch__side_L"], col), piece_object(by["root_arch__side_R"], col),
          piece_object(by["root_arch__crown"], col)]
    for x, nm, s in ((-4.0, "drape_C", 1.2), (2.5, "drape_A", 1.3)):
        g1.append(piece_object(extra["moss__" + nm], col, Vector((x, 23.9, -2.0)), None, s))
    for x, s in ((-6.5, 1.0), (-2.0, 0.7), (1.5, 1.1), (5.5, 0.8)):
        g1.append(piece_object(extra["vine__strand"], col, Vector((x, 19.8, -1.2)), None, s))
    cx = 60.0
    cctx = [((cx, 8.5, 13), (15, 18, 14), JSTONE_D, (0, 0, 0)), ((cx, 5.5, 5.5), (14, 11, 6), JREC, (0, 0, 0)),
            ((cx, 0.3, 2.2), (14, 0.6, 1.2), JSTONE_D, (0, 0, 0)), ((cx - 3.0, 0.3, -6.0), (3.0, 0.5, 0.5), BONE, (0, 30, 0)),
            ((cx + 2.5, 0.3, -7.5), (2.4, 0.5, 0.5), BONE, (0, -50, 0))]
    g2 = context_boxes(cctx, col) + [piece_object(by[f"cave__{n}"], col, Vector((cx, 0, 0))) for n in ("rock_L", "rock_R", "top_slab")]
    g2.append(piece_object(by["skull__small"], col, Vector((cx + 4.5, 0, -4.5)), euler_matrix([0, 25, 0])))
    for x, nm, s in ((-8.0, "drape_C", 1.8), (5.0, "drape_A", 2.0)):
        g2.append(piece_object(extra["moss__" + nm], col, Vector((cx + x, 15.9, -5.6)), None, s))
    tx = 120.0
    tctx = []
    for sx in (-1, 1):
        x = tx + sx * 15.5
        tctx += [((x, 0.75, 0), (6.2, 1.5, 6.2), "#4A3022", (0, 0, 0)), ((x, 3.7, 0), (4.3, 4.4, 4.3), TRED, (0, 0, 0)),
                 ((x, 8.1, 0), (4.6, 4.4, 4.6), "#D6965C", (0, 0, 0)), ((x, 12.5, 0), (4.3, 4.4, 4.3), TEAL, (0, 0, 0)),
                 ((x, 16.9, 0), (4.6, 4.4, 4.6), "#68442C", (0, 0, 0))]
    tctx += [((tx, 20.6, 0), (37, 3, 3), "#703E26", (0, 0, 0))]
    g3 = context_boxes(tctx, col) + [piece_object(by["totem__wing_L"], col, Vector((tx, 0, 0))),
                                     piece_object(by["totem__wing_R"], col, Vector((tx, 0, 0)))]
    sx0 = 170.0
    sctx = [((sx0, 21.7, -1.2), (13.4, 5.2, 0.6), "#703E26", (0, 0, 0)), ((sx0, 21.7, -1.75), (12, 4, 0.5), "#A86238", (0, 0, 0)),
            ((sx0, 17.5, 0.2), (32, 3, 3.4), "#703E26", (0, 0, 0))]
    g4 = context_boxes(sctx, col) + [piece_object(by["skull__horned"], col, Vector((sx0, 0, 0)))]
    out = os.path.join(P.PREVIEW_DIR, "jungle_gates_facets.png")
    return render_sheet("jgates", [(g1, [(-25, 8)]), (g2, [(-28, 14)]), (g3, [(-20, 6)]), (g3[-1:], [(-10, 4)]), (g4[-1:], [(-25, 10)])],
                        None, out)


# ------------------------------------------------------------------------------------------------
# JUNGLE RUINS AND STONEWORK (guide section C4): broken pillar top, chipped stepping slabs, rubble, small plants.
# Many copies: every piece is kept small (<= ~70 faces).
# ------------------------------------------------------------------------------------------------
FRESH = "#A9AE9F"   # freshly broken stone face (mix of #848A7C toward white)


def _yaw_pts(pts2, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    # Roblox yaw (about +Y): x' = x cos + z sin, z' = -x sin + z cos
    return [(x * c + z * s, -x * s + z * c) for x, z in pts2]


def pillar_break():
    rng = random.Random(3101)
    pc = Piece("ruins", "pillar_break", "the Ruin_Pillar_Broken kit pivot (base centre, y 0 = the ground, front -Z)",
               place={"relativeTo": "the Ruin_Pillar_Broken model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the Break wedge (4.2 x 2.6 x 4.2 at y 9.4, turned 35 deg); keep its CanCollide on a hidden "
                                  "wedge; the 8 copies at 0.8 scale with the model (bakedScale)",
                      "fits": "a stump 4.2 square with 0.3 chamfered corners, top y 8.1"},
               notes="jagged slanted break on top of the stump: the 4.2 shaft (0.3 chamfered corners) continues from y 8.0 "
                     "and ends in a broken surface rising from ~8.4 on the low side to ~10.7 on the high side (high side "
                     "toward yaw 35 deg like today), with a jagged rim, 3 chips knocked off the edge, a lighter freshly "
                     "broken face and a dark crack down one side.")
    h, ch = 2.1, 0.3
    octa = [(h - ch, -h), (h, -h + ch), (h, h - ch), (h - ch, h), (-h + ch, h), (-h, h - ch), (-h, -h + ch), (-h + ch, -h)]
    per = []
    for i in range(8):
        a, b = octa[i], octa[(i + 1) % 8]
        per.append(a)
        if i % 2 == 1:   # long sides get a midpoint
            per.append(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2))
    dirx, dirz = math.sin(math.radians(35.0)), -math.cos(math.radians(35.0))
    chips = set(rng.sample(range(len(per)), 3))

    def top_h(x, z, rim):
        t = (x * dirx + z * dirz) / (2 * h) + 0.5
        t = max(0.0, min(1.0, t))
        y = 8.4 + 2.3 * (t * t * (3 - 2 * t))
        return y + rng.uniform(-0.28, 0.28) * (1.0 if rim else 0.6)
    y0 = 8.0
    tops = []
    for i, (x, z) in enumerate(per):
        y = top_h(x, z, True)
        if i in chips:
            y -= rng.uniform(0.5, 0.9)
        tops.append(max(y, 8.25))
    n = len(per)
    for i in range(n):
        j = (i + 1) % n
        a, b = per[i], per[j]
        out = Vector(((a[0] + b[0]) / 2, 0, (a[1] + b[1]) / 2))
        g = rng.choice(STEPS)
        pc.quad_or_tris([Vector((a[0], y0, a[1])), Vector((b[0], y0, b[1])), Vector((b[0], tops[j], b[1])),
                         Vector((a[0], tops[i], a[1]))], tone(JSTONE, g), "SmoothPlastic", 0.4, out)
    # broken surface: rim -> inner ring (55 %) -> centre
    rim = [Vector((x, tops[i], z)) for i, (x, z) in enumerate(per)]
    inner = []
    for i, (x, z) in enumerate(per):
        xi, zi = x * 0.55 + rng.uniform(-0.12, 0.12), z * 0.55 + rng.uniform(-0.12, 0.12)
        inner.append(Vector((xi, top_h(xi, zi, False), zi)))
    cen = Vector((0.0, top_h(0, 0, False) + 0.1, 0.0))
    for i in range(n):
        j = (i + 1) % n
        q = [rim[i], rim[j], inner[j], inner[i]]
        nrm = newell(q)
        pc.quad_or_tris(q, tone(FRESH, rng.choice(STEPS)), "SmoothPlastic", 0.4, Vector((0, 1, 0)) if nrm.y >= 0 else Vector((0, 1, 0)))
        pc.face([inner[i], inner[j], cen], tone(FRESH, rng.choice((1.0, 0.95, 0.9))), "SmoothPlastic", 0.4, Vector((0, 1, 0)))
    # dark crack down the front face (z = -2.1 side), two kinked strips
    for (xa, ya, xb, yb) in ((-0.6, 8.9, -0.3, 6.6), (-0.3, 6.6, -0.7, 4.4)):
        w = 0.07
        pc.face([Vector((xa - w, ya, -h - 0.02)), Vector((xa + w, ya, -h - 0.02)), Vector((xb + w, yb, -h - 0.02)),
                 Vector((xb - w, yb, -h - 0.02))], JREC, "SmoothPlastic", 0.08, Vector((0, 0, -1)))
    return pc


def chipped_outline(hx, hz, yaw, rng, chip=(0.25, 0.6), cx=0.0, cz=0.0):
    """Rectangle 2hx x 2hz with all 4 corners chipped (2 points each) + a slightly bent midpoint on each side;
    convex; yawed (deg) about the centre."""
    pts = []
    corners = [(hx, -hz), (hx, hz), (-hx, hz), (-hx, -hz)]
    for i, (x, z) in enumerate(corners):
        px, pz = corners[i - 1]
        nx, nz = corners[(i + 1) % 4]
        c1, c2 = rng.uniform(*chip), rng.uniform(*chip)
        d1 = Vector((px - x, pz - z)).normalized()
        d2 = Vector((nx - x, nz - z)).normalized()
        pts.append((x + d1.x * c1, z + d1.y * c1))
        pts.append((x + d2.x * c2, z + d2.y * c2))
        mx, mz = (x + nx) / 2, (z + nz) / 2
        o = Vector((mx, mz)).normalized()
        k = rng.uniform(0.0, 0.08)
        pts.append((mx + o.x * k, mz + o.y * k))
    return [(cx + x, cz + z) for x, z in _yaw_pts(pts, yaw)]


def slab_into(pc, outline, y_top, y_bot, base, rng, bevel=0.15, cracks=0, moss=None):
    c = Vector((sum(p[0] for p in outline) / len(outline), 0, sum(p[1] for p in outline) / len(outline)))
    outer = [Vector((x, y_top - bevel, z)) for x, z in outline]
    k = []
    top = []
    for p in outer:
        d = Vector((p.x - c.x, 0, p.z - c.z))
        f = max(0.0, 1.0 - bevel / max(d.length, 1e-6))
        top.append(Vector((c.x + d.x * f, y_top, c.z + d.z * f)))
    n = len(outer)
    polygon_fill(pc, top, tone(base, 1.0), "SmoothPlastic", 0.4, Vector((0, 1, 0)))
    for i in range(n):
        j = (i + 1) % n
        out = Vector(((outer[i].x + outer[j].x) / 2 - c.x, 0.6, (outer[i].z + outer[j].z) / 2 - c.z))
        pc.quad_or_tris([outer[i], outer[j], top[j], top[i]], tone(base, 0.95), "SmoothPlastic", 0.15, out)
        out.y = 0
        lo_i, lo_j = Vector((outer[i].x, y_bot, outer[i].z)), Vector((outer[j].x, y_bot, outer[j].z))
        pc.face([lo_i, lo_j, outer[j], outer[i]], tone(base, rng.choice((0.86, 0.82, 0.78))), "SmoothPlastic", 0.4, out)
    for _ in range(cracks):
        a = rng.uniform(0, 2 * math.pi)
        p0 = c + Vector((math.cos(a), 0, math.sin(a))) * 0.3
        p1 = p0 + Vector((math.cos(a + 0.5), 0, math.sin(a + 0.5))) * 1.3
        p2 = p1 + Vector((math.cos(a - 0.3), 0, math.sin(a - 0.3))) * 1.1
        for a_, b_ in ((p0, p1), (p1, p2)):
            d = (b_ - a_).normalized()
            w = Vector((-d.z, 0, d.x)) * 0.06
            y = y_top + 0.02
            pc.face([Vector((a_.x, y, a_.z)) - w, Vector((a_.x, y, a_.z)) + w, Vector((b_.x, y, b_.z)) + w * 0.5,
                     Vector((b_.x, y, b_.z)) - w * 0.5], JREC, "SmoothPlastic", 0.05, Vector((0, 1, 0)))
    if moss:
        (mx, mz), (rx, rz), yaw = moss
        for lay, (sc, h0, H, cols) in enumerate(((1.0, 0.02, 0.08, (JMOSS, tone(JMOSS, 0.88))), (0.6, 0.1, 0.06, (JMOSS_L, tone(JMOSS_L, 0.9))))):
            nm = 10 if lay == 0 else 8
            for _ in range(60):
                ring = []
                for i in range(nm):
                    a = 2 * math.pi * i / nm + rng.uniform(-0.2, 0.2)
                    r = rng.uniform(0.76, 1.1)
                    ring.append((rx * sc * r * math.cos(a), rz * sc * r * math.sin(a)))
                if _convex(ring):
                    break
            ring = [(mx + x + (0.25 * lay), mz + z - (0.2 * lay)) for x, z in _yaw_pts(ring, yaw)]
            cc = Vector((sum(p[0] for p in ring) / nm, y_top + h0 + H, sum(p[1] for p in ring) / nm))
            lo = [Vector((x, y_top + h0, z)) for x, z in ring]
            hi = [cc + (Vector((p.x, cc.y, p.z)) - cc) * 0.7 for p in lo]
            for i in range(nm):
                j = (i + 1) % nm
                pc.face([lo[i], lo[j], hi[j], hi[i]], cols[1], "SmoothPlastic", 0.06, Vector((0, 1, 0)))
            polygon_fill(pc, hi, cols[0], "SmoothPlastic", 0.06, Vector((0, 1, 0)))


def stepping_slabs():
    rng = random.Random(3202)
    place = {"relativeTo": "the SteppingStone_A model (kit pivot = bottom centre)", "position": [0, 0, 0], "orientation": [0, 0, 0]}
    top = Piece("ruins", "slab_top", "the SteppingStone_A kit pivot (y 0 = the pivot, sunk 1.5 into the water bed; front -Z)",
                place=dict(place, replaces="the Stone (6.4 x 1.6 x 6, turned 18 deg) and the flat Moss; keep CanCollide on a hidden "
                                           "box 6.4 x 1.6 x 6 (players hop on it: the top stays FLAT at y 1.6)"),
                notes="the upper stepping slab: an irregular cut outline (6.4 x 6 turned 18 deg like today, 4 chipped "
                      "corners, slightly bent sides), FLAT top at y 1.6 with a 0.15 bevel, 2 thin dark cracks, and a soft "
                      "2-layer moss patch lying on it (0.1-0.16 thick, #589642 -> #60C448) where today's Moss is.")
    slab_into(top, chipped_outline(3.2, 3.0, 18.0, rng), 1.6, 0.0, JSTONE, rng, 0.15, 2,
              moss=((0.8, -0.6), (1.7, 1.4), 40.0))
    low = Piece("ruins", "slab_low", "the SteppingStone_A kit pivot (y 0 = the pivot, front -Z)",
                place=dict(place, replaces="the Skirt MeshPart (7.6 x 1.5 x 7.4 at y 0.4, turned 50 deg); keep its CanCollide on "
                                           "a hidden box"),
                notes="the lower, bigger slab under it, offset and turned 50 deg: 7.4 x 7.2, top y 1.15, bottom -0.35, "
                      "chipped corners, a 0.15 bevel, 1 crack. #5C645C.")
    slab_into(low, chipped_outline(3.7, 3.6, 50.0, rng, (0.4, 0.9), 0.15, 0.1), 1.15, -0.35, JSTONE_D, rng, 0.15, 1)
    return [top, low]


def rubble_stone(name, size, seed, base, notes):
    rng = random.Random(seed)
    sx, sy, sz = (s / 2 for s in size)
    pc = Piece("ruins", name, "the piece's own anchor: (0, 0, 0) = the CENTRE of the stone's box, axes = the stone's axes",
               place={"relativeTo": "any ruin kit", "position": "the CFrame of the Rubble / Chunk part it replaces "
                      "(same centre, same rotation)", "scale": "uniform 0.4..1.2 for extra small rubble"},
               notes=notes)
    pts = []
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (-1, 1):
                p = Vector((x * sx, y * sy, z * sz))
                if rng.random() < 0.55:      # chip this corner: 3 points pulled back along the 3 edges
                    c = rng.uniform(0.18, 0.32) * min(size)
                    pts += [p - Vector((x * c, 0, 0)), p - Vector((0, y * c, 0)), p - Vector((0, 0, z * c))]
                else:
                    pts.append(p * rng.uniform(0.97, 1.0))

    def col(cc, n):
        if n.y > 0.7:
            return tone(base, 1.04)
        if n.y < -0.7:
            return tone(base, 0.75)
        return tone(base, rng.choice(STEPS) * (0.92 if abs(n.x) + abs(n.y) + abs(n.z) > 1.3 else 1.0))
    hull_into(pc, pts, col, 0.4 * min(size) / 2.4)
    return pc


def plant_tuft():
    rng = random.Random(3404)
    pc = Piece("ruins", "plant_tuft", "the piece's own anchor: (0, 0, 0) = the base of the tuft on the ground",
               place={"relativeTo": "stone joints, tread corners, slab gaps", "position": "on the ground / tread", "orientation":
                      "any yaw", "scale": "uniform 0.4..1.2", "collide": "CanCollide off"},
               notes="small grass / leaf tuft: 7 blades 0.5-0.9 tall leaning out, alternating #78D246 / #60C448 / #589642.")
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        w = Vector((-d.z, 0, d.x)) * 0.09
        b = d * 0.06
        tip = d * rng.uniform(0.25, 0.45) + Vector((0, rng.uniform(0.5, 0.9), 0))
        pc.face([b - w, b + w, tip], (JMOSS_LL, JMOSS_L, JMOSS)[i % 3], "SmoothPlastic", 0.04, Vector((d.x, 0.3, d.z)))
    return pc


def fern():
    rng = random.Random(3505)
    pc = Piece("ruins", "fern", "the piece's own anchor: (0, 0, 0) = the base of the fern on the ground",
               place={"relativeTo": "stair corners, wall feet", "position": "on the ground", "orientation": "any yaw",
                      "scale": "uniform 0.5..1.3", "collide": "CanCollide off"},
               notes="small fern: 5 arching fronds 1.1-1.4 long, each folded on its midrib (2 faces) with a bent tip "
                     "(2 more), #60C448 / #589642, darker undersides.")
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-d.z, 0, d.x))
        L = rng.uniform(1.1, 1.4)
        b = Vector((0, 0.05, 0))
        m = d * (L * 0.55) + Vector((0, 0.55, 0))
        tip = d * L + Vector((0, 0.25, 0))
        w = 0.22
        c1, c2 = (JMOSS_L, JMOSS) if i % 2 else (JMOSS, JMOSS_L)
        pc.face([b, m + side * w, m], c1, "SmoothPlastic", 0.04, Vector((0, 1, 0)))
        pc.face([b, m, m - side * w], c2, "SmoothPlastic", 0.04, Vector((0, 1, 0)))
        pc.face([m, m + side * w * 0.8, tip], c1, "SmoothPlastic", 0.04, Vector((0, 1, 0)))
        pc.face([m, tip, m - side * w * 0.8], c2, "SmoothPlastic", 0.04, Vector((0, 1, 0)))
    return pc


def jungle_ruins():
    rub = [rubble_stone("rubble_A", (2.6, 2.0, 2.4), 3301, JSTONE,
                        "chipped cut-stone rubble 2.6 x 2.0 x 2.4 (= Ruin_Wall_Broken's first Rubble): a box with ~half its "
                        "corners knocked off, 3 tone steps, lighter top. #848A7C."),
           rubble_stone("rubble_B", (3.0, 2.4, 2.6), 3302, JSTONE_D,
                        "chipped cut-stone rubble 3.0 x 2.4 x 2.6 (= Ruin_Wall_Broken's 2nd Rubble, Ruin_Stairs' Rubble 3 x 2.2 x "
                        "2.6, Ruin_Pillar_Broken's Chunk 3 x 2.4 x 3: scale Y / Z to the part). #5C645C (use #848A7C on the "
                        "stairs' rubble)."),
           rubble_stone("rubble_C", (1.4, 1.0, 1.2), 3303, JSTONE_M,
                        "small chipped stone 1.4 x 1.0 x 1.2 for extra rubble at wall feet (2-3 per kit, scale 0.6-1.2). "
                        "#7B8174.")]
    return [pillar_break()] + stepping_slabs() + rub + [plant_tuft(), fern()]


def _mat(m):
    from mathutils import Matrix
    return Matrix(((m[0], m[1], m[2]), (m[3], m[4], m[5]), (m[6], m[7], m[8])))


def preview_jungle_ruins(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    extra = {f"{p.obj}__{p.name}": p for p in moss_pieces() + vine_strand()}
    # broken pillar kit
    pctx = [((0, 0.8, 0), (6, 1.6, 6), JSTONE_D, (0, 0, 0)), ((0, 4.85, 0), (4.2, 6.5, 4.2), JSTONE, (0, 0, 0)),
            ((7.5, 2.1, 2.0), (4.2, 4.2, 6.0), "#808678", (0, 30, 0))]
    g1 = context_boxes(pctx, col) + [piece_object(by["ruins__pillar_break"], col)]
    g1.append(piece_object(by["ruins__rubble_B"], col, Vector((4.5, 1.1, -5.0)), _mat((0.64, 0.0, 0.77, 0.11, 0.99, -0.09, -0.76, 0.14, 0.64))))
    g1.append(piece_object(by["ruins__fern"], col, Vector((-3.2, 0, -3.0)), None, 0.9))
    g1.append(piece_object(extra["moss__drape_B"], col, Vector((-1.2, 1.6, -3.0)), None, 1.0))
    # stepping slabs
    sx = 30.0
    g2 = [piece_object(by["ruins__slab_low"], col, Vector((sx, 0, 0))), piece_object(by["ruins__slab_top"], col, Vector((sx, 0, 0)))]
    for x, z in ((sx + 3.4, -2.0), (sx - 3.0, 2.6)):
        g2.append(piece_object(by["ruins__plant_tuft"], col, Vector((x, 1.15, z)), None, 0.5))
    # stepped ruin block with rubble + moss drapes
    wx = 60.0
    wctx = [((wx, 0.6, 0), (20.8, 1.2, 4.4), JSTONE_D, (0, 0, 0)), ((wx + 6.5, 1.6, 0), (7, 3.2, 3.6), JSTONE, (0, 0, 0)),
            ((wx, 3.25, 0), (6, 6.5, 3.6), "#8D9384", (0, 0, 0)), ((wx - 6.5, 5.0, 0), (7, 10, 3.6), JSTONE, (0, 0, 0))]
    g3 = context_boxes(wctx, col)
    g3.append(piece_object(by["ruins__rubble_A"], col, Vector((wx + 8.6, 0.9, -3.8)), _mat((0.5, 0.0, 0.87, 0.15, 0.98, -0.09, -0.85, 0.17, 0.49))))
    g3.append(piece_object(by["ruins__rubble_B"], col, Vector((wx + 5.0, 1.1, -4.6)), _mat((0.9, -0.13, 0.42, 0.14, 0.99, 0.0, -0.42, 0.06, 0.91))))
    g3.append(piece_object(by["ruins__rubble_C"], col, Vector((wx + 2.0, 0.5, -3.4))))
    for x, y, nm in ((wx + 5.0, 3.2, "drape_A"), (wx + 8.4, 3.2, "drape_B"), (wx - 1.5, 6.5, "drape_A"), (wx + 1.8, 6.5, "drape_B"),
                     (wx - 7.5, 10.0, "drape_C")):
        g3.append(piece_object(extra["moss__" + nm], col, Vector((x, y, -1.8))))
    g3.append(piece_object(extra["vine__strand"], col, Vector((wx - 4.5, 9.9, -1.9)), None, 0.5))
    g3.append(piece_object(by["ruins__fern"], col, Vector((wx - 2.5, 1.2, -2.6)), None, 0.8))
    # rubble / plants line-up
    rx = 90.0
    g4 = [piece_object(by["ruins__rubble_A"], col, Vector((rx - 3.5, 1.0, 0))), piece_object(by["ruins__rubble_B"], col, Vector((rx, 1.2, 0))),
          piece_object(by["ruins__rubble_C"], col, Vector((rx + 3.0, 0.5, 0))), piece_object(by["ruins__plant_tuft"], col, Vector((rx + 5.0, 0, 0))),
          piece_object(by["ruins__fern"], col, Vector((rx + 7.5, 0, 0)))]
    out = os.path.join(P.PREVIEW_DIR, "jungle_ruins_facets.png")
    return render_sheet("jruins", [(g1, [(-30, 15)]), (g1[3:4], [(-30, 35)]), (g2, [(-25, 35)]), (g3, [(-25, 12)]), (g4, [(-20, 18)])],
                        None, out)


# ------------------------------------------------------------------------------------------------
# JUNGLE TOTEMS, SHRINES AND WATER (guide section C5): feather crest, tusks, horns, wings, face reliefs, shrine
# finial + gem settings, lily pads.
# ------------------------------------------------------------------------------------------------
FEATHER_O, TWOOD = "#FFAA28", "#4A3022"


def feather_crest():
    pc = Piece("totem", "feather_crest", "the Totem_B kit pivot (base centre, y 0 = the ground, front -Z)",
               place={"relativeTo": "the Totem_B model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the 3 Feather parts on top of the yellow head (top y 18.2); no collision"},
               notes="feather crest on the yellow head: a gold band (6-sided ring) and 5 fanned feathers (-36 / -18 / 0 / "
                     "18 / 36 deg; teal, orange, red centre 3.8 long, teal, orange), each a quill + a vane in 4 segments "
                     "with 2 notches per side and a darker tip; the centre one in front.")
    base_y = 18.2
    ring = [Vector((1.05 * math.cos(2 * math.pi * i / 6 + math.pi / 6), 0, 0.75 * math.sin(2 * math.pi * i / 6 + math.pi / 6))) for i in range(6)]
    for i in range(6):
        j = (i + 1) % 6
        a, b = ring[i], ring[j]
        q = [a + Vector((0, base_y - 0.05, 0)), b + Vector((0, base_y - 0.05, 0)), b + Vector((0, base_y + 0.45, 0)),
             a + Vector((0, base_y + 0.45, 0))]
        pc.face(q, tone(GOLD, (1.0, 0.9)[i % 2]), "SmoothPlastic", 0.2, (a + b) / 2)
    polygon_fill(pc, [p + Vector((0, base_y + 0.45, 0)) for p in ring], tone(GOLD, 0.95), "SmoothPlastic", 0.2, Vector((0, 1, 0)))
    specs = [(-36, 3.0, TEAL, 0.12), (-18, 3.4, FEATHER_O, 0.06), (0, 3.8, TRED, -0.05), (18, 3.4, TEAL, 0.06), (36, 3.0, FEATHER_O, 0.12)]
    for ang, L, col, z in specs:
        a = math.radians(ang)
        d = Vector((math.sin(a), math.cos(a), 0))
        nrm = Vector((d.y, -d.x, 0))
        o = Vector((math.sin(a) * 0.5, base_y + 0.3, z))

        def P2(s, w):
            return o + d * s + nrm * w
        # quill
        pc.face([P2(0.0, -0.06), P2(0.0, 0.06), P2(L * 0.95, 0.04), P2(L * 0.95, -0.04)], tone(BONE, 0.9), "SmoothPlastic", 0.12,
                Vector((0, 0, -1)))
        segs = [0.15, 0.4, 0.62, 0.82, 1.0]
        widths = [0.18, 0.42, 0.45, 0.36, 0.0]
        for side in (-1, 1):
            for k in range(4):
                s0, s1 = segs[k] * L, segs[k + 1] * L
                w0, w1 = widths[k], widths[k + 1]
                notch = 0.1 if k in (1, 2) else 0.0
                cc = tone(col, 0.72) if k == 3 else tone(col, (1.0, 0.94)[(k + (side > 0)) % 2])
                pts = [P2(s0, side * 0.04), P2(s1, side * 0.04), P2(s1, side * w1), P2(s0 + notch * L * 0.3, side * (w0 - notch * 0.0))]
                if w1 < 1e-6:
                    pc.face([pts[0], pts[1], pts[3]], cc, "SmoothPlastic", 0.12, Vector((0, 0, -1)))
                else:
                    pc.face(pts, cc, "SmoothPlastic", 0.12, Vector((0, 0, -1)))
    return pc


def _horn_tube(pc, pts, r0, r1, sides, base, t):
    n = len(pts)
    radii = [r0 + (r1 - r0) * (i / (n - 1)) ** 0.9 for i in range(n)]
    tube_faces(pc, pts, radii, sides, lambda s, k: (tone(base, 1.0 if s % 2 == 0 else 0.86) if k % 3 else tone(base, 0.93)), t)


def totem_tusks():
    pc = Piece("totem", "tusks", "the Totem_B kit pivot (base centre, front -Z)",
               place={"relativeTo": "the Totem_B model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the 2 Tusk parts of the blue bottom head; no collision"},
               notes="2 curved boar tusks from the corners of the blue head's mouth, curving forward and up, 5-sided, "
                     "tapering 0.3 -> 0.05, ribbed bone tones #E8E2D0.")
    for sx in (-1, 1):
        pts = [Vector((sx * 1.05, 2.1, -1.55)), Vector((sx * 1.2, 2.9, -2.15)), Vector((sx * 1.32, 3.9, -2.45)),
               Vector((sx * 1.3, 4.8, -2.35)), Vector((sx * 1.15, 5.4, -2.05))]
        _horn_tube(pc, pts, 0.3, 0.05, 5, BONE, 0.12)
    return pc


def figure_horns():
    pc = Piece("totem_figure", "horns", "the Totem_A kit pivot (base centre, front -Z)",
               place={"relativeTo": "the Totem_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the 2 Horn parts on the hat; no collision"},
               notes="2 curved ribbed horns from the hat's crown (3 x 2.2 x 3 at y 14), out and up, 6-sided, tapering "
                     "0.38 -> 0.06, #E8E2D0 yellowing to the tips.")
    for sx in (-1, 1):
        pts = [Vector((sx * 1.3, 14.4, 0.0)), Vector((sx * 2.1, 14.9, -0.05)), Vector((sx * 2.75, 15.8, -0.1)),
               Vector((sx * 2.9, 16.9, -0.15)), Vector((sx * 2.6, 17.7, -0.2))]
        n = len(pts)
        radii = [0.38, 0.32, 0.24, 0.15, 0.06]
        tube_faces(pc, pts, radii, 6, lambda s, k: mix(BONE, THATCH, 0.15 * s) if s % 2 == 0 else tone(mix(BONE, THATCH, 0.15 * s), 0.88), 0.15)
    return pc


def figure_wings():
    out = []
    for sgn in (-1, 1):
        side = "L" if sgn < 0 else "R"
        pc = Piece("totem_figure", f"wing_{side}", "the Totem_A kit pivot (base centre, front -Z)",
                   place={"relativeTo": "the Totem_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                          "replaces": f"the {'left' if sgn < 0 else 'right'} Wing (5 x 2.4 x 0.7 at ({sgn * 4.3}, 11.2, 0), rising 18 deg); "
                                      "keep its CanCollide on a hidden box"},
                   notes="the C3 totem-arch wing design (arm bar + 3 rows of fanned feathers, gold-tipped primaries) at "
                         "0.78 size on the tan head's side (x +-2.0), rising 18 deg like today; about 5.7 long.")
        wing_into(pc, sgn, (sgn * 2.0, 11.9, 0.0), 18.0, 0.78)
        out.append(pc)
    return out


def face_relief(name, seed, brow_tilt, arch, nose_w, notes):
    """Carved relief for a 3.4 totem head: brow ridge over today's eyes (eyes at local y +0.5, x +-0.95), a carved
    nose, 2 cheek plates. Local frame: (0,0,0) = centre of the head's FRONT face, front -Z."""
    rng = random.Random(seed)
    pc = Piece("totem", name, "the piece's own anchor: (0, 0, 0) = the CENTRE of a totem head's FRONT face; front -Z; "
               "made for a 3.4 head", place={"relativeTo": "a Totem_A / Totem_B / EntryArch head", "position":
                                            "the head's front-face centre (e.g. Totem_B blue head (0, 2.9, -1.7))",
                                            "orientation": [0, 0, 0], "scale": "uniform = head width / 3.4 (3.7 -> 1.09, 4.0 -> 1.18, 4.4 -> 1.29)",
                                            "colour": "the faces carry the TAN colour #D6965C as a placeholder: recolour to the head's own colour (x0.86 for the shaded faces)"},
               notes=notes)
    base = "#D6965C"
    st = []
    for x in (-1.5, -1.0, -0.45, 0.0, 0.45, 1.0, 1.5):
        ax = abs(x)
        y = 1.1 + arch * (1 - (ax - 0.95) ** 2 / 0.9) * (ax > 0.2) - brow_tilt * (1.5 - ax) / 1.5
        s = 1.0 - 0.35 * max(0.0, (ax - 1.1) / 0.4)
        st.append((x, y, s))
    secs = brow_sections(st, 0.42, 0.52, 0.02)
    sweep_faces(pc, secs, lambda k, i: tone(base, (1.0, 0.95, 0.9, 0.8, 0.7)[k]), 0.15)
    # nose (hull) from between the eyes down to above the mouth
    X, Y0, Y1, ZB, ZF = nose_w, -0.55, 0.85, 0.02, -0.55
    fr = [(0.35, 1.0, 0.0), (0.38, 0.9, 0.3), (0.5, 0.3, 0.85), (0.4, 0.05, 1.0), (1.0, 0.1, 0.45), (0.95, 0.0, 0.0),
          (0.6, 0.0, 0.7), (1.0, 0.35, 0.0)]
    pts = []
    for u, v, w in fr:
        for sg in (1, -1):
            pts.append(Vector((sg * u * X, Y0 + v * (Y1 - Y0), ZB + w * (ZF - ZB))))
    tree = hull_into(pc, pts, lambda cc, n: tone(base, 0.75 if n.y < -0.4 else (1.0 if n.y > 0.3 else 0.92)), 0.15,
                     skip=lambda ring: all(abs(p.z - ZB) < 1e-4 for p in ring))
    for sx in (-1, 1):
        surface_quad(pc, tree, (sx * 0.4 * X, Y0 - 1.0, ZB + 0.5 * (ZF - ZB)), (0, 1, 0),
                     [(-0.08, -0.06), (0.08, -0.06), (0.06, 0.06), (-0.06, 0.06)], TWOOD, "SmoothPlastic", 0.05, 0.02)
    # cheek plates (bevelled, 0.15 proud)
    for sx in (-1, 1):
        cx, cy = sx * 1.15, -0.35
        w, h, d, b = 0.45, 0.32, 0.15, 0.06
        f = [Vector((cx - w + b, cy - h + b, -d)), Vector((cx + w - b, cy - h + b, -d)), Vector((cx + w - b, cy + h - b, -d)),
             Vector((cx - w + b, cy + h - b, -d))]
        bk = [Vector((cx - w, cy - h, 0.02)), Vector((cx + w, cy - h, 0.02)), Vector((cx + w, cy + h, 0.02)), Vector((cx - w, cy + h, 0.02))]
        pc.face(f, tone(base, 0.97), "SmoothPlastic", 0.12, Vector((0, 0, -1)))
        for i in range(4):
            j = (i + 1) % 4
            pc.face([bk[i], bk[j], f[j], f[i]], tone(base, (0.8, 0.9, 1.0, 0.9)[i]), "SmoothPlastic", 0.1,
                    (bk[i] + bk[j]) / 2 - Vector((cx, cy, 0.5)))
    return pc


def shrine_finial():
    pc = Piece("shrine", "finial", "the Golden_Altar kit pivot (base centre, y 0 = the ground, front -Z)",
               place={"relativeTo": "the Golden_Altar model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "Idol (1.8 x 2.4 x 1.4 at (0, 6.8, 0.6)) and IdolHead; no collision (like today); the Jungle_4 "
                                  "copy scales x1.6 with the model (bakedScale)"},
               notes="the shrine's central gold finial on the GoldTop (y 5.6), centred at (0, z 0.6) like the Idol: an "
                     "8-sided lathe: a 2-step base, a tapering body with 2 engraved bands (darker #E5B435), a neck, a "
                     "round head with a crown ring, and a spike ending in a small Neon #78FFBE gem (octahedron) at y ~9.6.")
    prof = [(1.0, 5.6), (1.0, 5.85), (0.85, 5.85), (0.85, 6.1), (0.72, 6.1), (0.66, 6.7), (0.78, 6.75), (0.78, 6.95),
            (0.62, 7.0), (0.55, 7.6), (0.68, 7.65), (0.68, 7.8), (0.38, 7.85), (0.6, 8.1), (0.62, 8.45), (0.48, 8.7),
            (0.58, 8.75), (0.58, 8.9), (0.2, 8.95), (0.06, 9.45)]
    bands = {6, 10, 15, 16}

    def col(s, k):
        if s in bands:
            return GOLD2
        return tone(GOLD, (1.0, 0.93)[k % 2] * (0.9 + 0.1 * s / len(prof)))
    lathe_faces(pc, prof, 8, col, 0.2, center=(0.0, 0.6))
    top = Vector((0.0, 9.45, 0.6))
    gem = [top + Vector((0, 0.45, 0)), top + Vector((0, 0.05, 0))]
    eq = [top + Vector((0.18 * math.cos(a), 0.25, 0.18 * math.sin(a))) for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    for i in range(4):
        j = (i + 1) % 4
        mid = (eq[i] + eq[j]) / 2 - (top + Vector((0, 0.25, 0)))
        pc.face([gem[0], eq[j], eq[i]], "#78FFBE", "Neon", 0.08, mid + Vector((0, 0.3, 0)))
        pc.face([gem[1], eq[i], eq[j]], "#78FFBE", "Neon", 0.08, mid - Vector((0, 0.3, 0)))
    return pc


def gem_setting():
    pc = Piece("shrine", "gem_setting", "the piece's own anchor: (0, 0, 0) = the GEM'S CENTRE (today's Gem at (+-3, 6.5, 0))",
               place={"relativeTo": "the Golden_Altar model", "position": "(-3, 6.5, 0) and (3, 6.5, 0)", "orientation": [0, 0, 0],
                      "replaces": "the 2 Bowl parts (the Neon Gems stay as parts at their places); no collision"},
               notes="gold claw setting for the shrine's cyan gems: an 8-sided cup on a short stem (from the GoldTop at "
                     "y -0.9) with an engraved rim, and 4 tapering claws rising round the gem to y +0.22.")
    prof = [(0.75, -0.9), (0.75, -0.8), (0.42, -0.72), (0.38, -0.6), (0.6, -0.45), (0.62, -0.3), (0.5, -0.24)]
    lathe_faces(pc, prof, 8, lambda s, k: GOLD2 if s == 4 else tone(GOLD, (1.0, 0.93)[k % 2]), 0.15)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-d.z, 0, d.x))
        b0, b1 = d * 0.5 + Vector((0, -0.3, 0)), d * 0.36 + Vector((0, 0.22, 0))
        q_out = [b0 - side * 0.09, b0 + side * 0.09, b1 + side * 0.04, b1 - side * 0.04]
        pc.quad_or_tris(q_out, tone(GOLD, 0.95), "SmoothPlastic", 0.08, d)
    return pc


def lily_pad():
    rng = random.Random(4404)
    pad = Piece("pool", "lily_pad", "the piece's own anchor: (0, 0, 0) = the pad's centre ON the water surface",
                place={"relativeTo": "the Temple_Pool model", "position": "on the water: y 0.82 (today's water top 0.8), 4-6 "
                       "per pool, not closer than 1.5 to the rim", "orientation": "any yaw", "scale": "uniform 0.6..1.3",
                       "collide": "CanCollide off"},
                notes="lily pad 2.0 wide: a 12-sided disc with a V notch (fan of 10 slightly domed triangles, #46AA3C "
                      "/ #589642 alternating, lighter centre).")
    n = 12
    c = Vector((0, 0.06, 0))
    pts = [Vector((math.cos(2 * math.pi * i / n) * rng.uniform(0.95, 1.02), 0.0, math.sin(2 * math.pi * i / n) * rng.uniform(0.95, 1.02)))
           for i in range(n)]
    for i in range(n):
        if i in (0, n - 1):
            continue   # the notch: skip the 2 triangles round angle 0
        j = (i + 1) % n
        pad.face([c, pts[j], pts[i]], (JVINE, JMOSS)[i % 2], "SmoothPlastic", 0.06, Vector((0, 1, 0)))
    fl = Piece("pool", "lily_flower", "the piece's own anchor: (0, 0, 0) = the flower's base on a lily pad",
               place={"relativeTo": "a pool__lily_pad", "position": "on the pad, (0.3, 0.06, 0.2) from its centre",
                      "orientation": "any yaw", "scale": "uniform 0.8..1.2", "collide": "CanCollide off"},
               notes="small water lily: 6 pink #FF508C petals (2 faces each, tilted up 40 deg) round a gold #FFC93C "
                     "centre (4 faces).")
    for i in range(6):
        a = 2 * math.pi * i / 6
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-d.z, 0, d.x))
        b = Vector((0, 0.05, 0))
        mid = d * 0.3 + side * 0.13 * 0 + Vector((0, 0.2, 0))
        tip = d * 0.55 + Vector((0, 0.42, 0))
        w = side * 0.16
        cc = "#FF508C" if i % 2 else mix("#FF508C", "#FFFFFF", 0.25)
        fl.face([b, mid + w, tip], cc, "SmoothPlastic", 0.04, d + Vector((0, 0.6, 0)))
        fl.face([b, tip, mid - w], cc, "SmoothPlastic", 0.04, d + Vector((0, 0.6, 0)))
    top = Vector((0, 0.28, 0))
    ring = [Vector((0.12 * math.cos(a), 0.12, 0.12 * math.sin(a))) for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    for i in range(4):
        j = (i + 1) % 4
        fl.face([top, ring[j], ring[i]], GOLD, "SmoothPlastic", 0.05, (ring[i] + ring[j]) / 2 + Vector((0, 0.2, 0)))
    return [pad, fl]


def jungle_totems():
    reliefs = [face_relief("face_relief_A", 4501, 0.28, 0.0, 0.42,
                           "carved face relief, ANGRY: heavy brow ridge slanting down to the middle, a broad nose with "
                           "nostrils, 2 bevelled cheek plates. For the red / brown / red-figure heads."),
               face_relief("face_relief_B", 4502, -0.05, 0.16, 0.34,
                           "carved face relief, SURPRISED / PROUD: 2 arched brows, a narrower nose with nostrils, 2 "
                           "bevelled cheek plates. For the yellow / tan / blue heads.")]
    return ([feather_crest(), totem_tusks()] + reliefs + [figure_horns()] + figure_wings() + [shrine_finial(), gem_setting()]
            + lily_pad())


def preview_jungle_totems(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    extra = {f"{p.obj}__{p.name}": p for p in moss_pieces()}
    # Totem_B
    tb = [((0, 0.6, 0), (4.8, 1.2, 4.8), TWOOD, (0, 0, 0)), ((0, 2.9, 0), (3.4, 3.4, 3.4), TEAL, (0, 0, 0)),
          ((0, 6.3, 0), (3.7, 3.4, 3.7), "#D6965C", (0, 0, 0)), ((0, 9.7, 0), (3.4, 3.4, 3.4), TRED, (0, 0, 0)),
          ((0, 13.1, 0), (3.7, 3.4, 3.7), "#68442C", (0, 0, 0)), ((0, 16.5, 0), (3.4, 3.4, 3.4), GOLD, (0, 0, 0)),
          ((-2.7, 9.7, 0), (1.6, 2.6, 0.8), GOLD, (0, 0, 0)), ((2.7, 9.7, 0), (1.6, 2.6, 0.8), GOLD, (0, 0, 0))]
    for y, ec in ((2.9, BONE), (6.3, TWOOD), (9.7, BONE), (13.1, BONE), (16.5, TWOOD)):
        tb += [((-0.95, y + 0.5, -1.9), (0.8, 0.8, 0.3), ec, (0, 0, 0)), ((0.95, y + 0.5, -1.9), (0.8, 0.8, 0.3), ec, (0, 0, 0))]
    tb += [((0, 2.0, -1.9), (2.2, 0.6, 0.3), TWOOD, (0, 0, 0)), ((0, 8.8, -1.9), (2.2, 0.6, 0.3), TWOOD, (0, 0, 0)),
           ((0, 15.6, -1.9), (2.2, 0.6, 0.3), TRED, (0, 0, 0))]
    g1 = context_boxes(tb, col) + [piece_object(by["totem__feather_crest"], col), piece_object(by["totem__tusks"], col)]
    for y, z, s, nm in ((2.9, -1.7, 1.0, "B"), (6.3, -1.85, 1.09, "B"), (9.7, -1.7, 1.0, "A"), (13.1, -1.85, 1.09, "A"),
                        (16.5, -1.7, 1.0, "B")):
        g1.append(piece_object(by["totem__face_relief_" + nm], col, Vector((0, y, z)), None, s))
    # Totem_A
    ax = 16.0
    ta = [((0, 0.7, 0), (5.2, 1.4, 5.2), TWOOD, (0, 0, 0)), ((0, 3.4, 0), (4, 4, 4), TRED, (0, 0, 0)),
          ((0, 7.2, 0), (4.4, 3.6, 4.4), TEAL, (0, 0, 0)), ((0, 10.8, 0), (4, 3.6, 4), "#D6965C", (0, 0, 0)),
          ((0, 12.6, 0), (4.6, 0.7, 4.6), TRED, (0, 0, 0)), ((0, 14.0, 0), (3, 2.2, 3), TRED, (0, 0, 0)),
          ((0, 7.0, -2.9), (1.6, 1.4, 1.6), GOLD, (0, 0, 0)), ((0, 2.4, -2.05), (2.6, 0.7, 0.3), TWOOD, (0, 0, 0))]
    for y, ec, w, h, ex in ((4.1, BONE, 1.0, 1.0, 1.0), (8.1, GOLD, 0.9, 0.9, 1.2), (11.1, TWOOD, 0.9, 1.2, 1.0)):
        zz = -2.25 if y == 8.1 else -2.05
        ta += [((-ex, y, zz), (w, h, 0.3), ec, (0, 0, 0)), ((ex, y, zz), (w, h, 0.3), ec, (0, 0, 0))]
    ta = [((p[0] + ax, p[1], p[2]), s, c, r) for p, s, c, r in ta]
    off = Vector((ax, 0, 0))
    g2 = context_boxes(ta, col) + [piece_object(by["totem_figure__horns"], col, off), piece_object(by["totem_figure__wing_L"], col, off),
                                   piece_object(by["totem_figure__wing_R"], col, off)]
    g2.append(piece_object(by["totem__face_relief_A"], col, off + Vector((0, 3.6, -2.0)), None, 1.18))
    g2.append(piece_object(by["totem__face_relief_B"], col, off + Vector((0, 10.8 - 0.2, -2.0)), None, 1.18))
    # shrine
    sx = 40.0
    sh = [((0, 0.7, 0), (12, 1.4, 8), JSTONE_D, (0, 0, 0)), ((0, 2.1, 0), (10, 1.4, 6), JSTONE, (0, 0, 0)),
          ((0, 3.9, 0), (8, 2.2, 4.4), JSTONE, (0, 0, 0)), ((0, 3.9, -2.3), (3, 1, 0.3), "#78FFBE", (0, 0, 0)),
          ((0, 5.3, 0), (8.6, 0.6, 5), GOLD, (0, 0, 0)), ((-3.8, 3.9, -2.1), (0.5, 2.2, 0.5), GOLD, (0, 0, 0)),
          ((3.8, 3.9, -2.1), (0.5, 2.2, 0.5), GOLD, (0, 0, 0)), ((-3, 6.5, 0), (0.6, 0.6, 0.6), "#78FFBE", (45, 0, 45)),
          ((3, 6.5, 0), (0.6, 0.6, 0.6), "#78FFBE", (45, 0, 45))]
    sh = [((p[0] + sx, p[1], p[2]), s, c, r) for p, s, c, r in sh]
    g3 = context_boxes(sh, col) + [piece_object(by["shrine__finial"], col, Vector((sx, 0, 0)))]
    for gx in (-3.0, 3.0):
        g3.append(piece_object(by["shrine__gem_setting"], col, Vector((sx + gx, 6.5, 0))))
    g3.append(piece_object(extra["moss__drape_B"], col, Vector((sx - 4.5, 1.4, -4.0))))
    # pool
    px = 75.0
    po = [((0, 0.1, 0), (20, 0.2, 20), "#1E8C96", (0, 0, 0)), ((0, 0.55, 0), (20, 0.5, 20), "#30C4BE", (0, 0, 0)),
          ((0, 0.7, -11), (24, 1.4, 2), JSTONE, (0, 0, 0)), ((-11, 0.7, 0), (2, 1.4, 20), JSTONE, (0, 0, 0)),
          ((0, 0.7, 11), (24, 1.4, 2), JSTONE, (0, 0, 0)), ((11, 0.7, 0), (2, 1.4, 20), JSTONE, (0, 0, 0))]
    for cx_, cz_ in ((-11, -11), (-11, 11), (11, -11), (11, 11)):
        po += [((cx_, 1.3, cz_), (2.6, 2.6, 2.6), JSTONE_D, (0, 0, 0)), ((cx_, 2.85, cz_), (1.5, 0.5, 1.5), GOLD, (0, 0, 0))]
    po = [((p[0] + px, p[1], p[2]), s, c, r) for p, s, c, r in po]
    g4 = context_boxes(po, col)
    for (lx, lz, yaw, s) in ((-5, -4, 20, 1.0), (3, 2, 150, 1.2), (-2, 6, 260, 0.8), (6, -6, 80, 1.1), (-7, 4, 200, 0.7)):
        g4.append(piece_object(by["pool__lily_pad"], col, Vector((px + lx, 0.82, lz)), euler_matrix([0, yaw, 0]), s))
    g4.append(piece_object(by["pool__lily_flower"], col, Vector((px + 3.3, 0.88, 2.2)), None, 1.2))
    g4.append(piece_object(by["pool__lily_flower"], col, Vector((px - 4.7, 0.88, -3.8)), None, 1.0))
    out = os.path.join(P.PREVIEW_DIR, "jungle_totems_facets.png")
    return render_sheet("jtotems", [(g1, [(-20, 6)]), (g1[-5:], [(-25, 8)]), (g2, [(-20, 6)]), (g3, [(-25, 18)]), (g4, [(-25, 35)])],
                        None, out)


# ------------------------------------------------------------------------------------------------
# JUNGLE PROPS AND DECOR (guide section C6): torch flame + iron cup, human skull (skull pike + banner finial), banner
# cloth with pleats, zigzag trimmed edge and a stitched emblem, a small feather. MANY copies (torch 24, skull 14,
# banner 9): every piece is kept small; everything else of these 4 props is built from parts.
# ------------------------------------------------------------------------------------------------
IRON, EMBER_N, FLAME_N, WARM_N = "#5C626E", "#FF8C28", "#FFB648", "#FFD678"
TORCH_ORIGIN = "the Tribal_Torch kit pivot (base centre, y 0 = the ground, front -Z)"


def torch_flame():
    pc = Piece("torch", "flame", TORCH_ORIGIN,
               place={"relativeTo": "the Tribal_Torch model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "nothing: it is added on top of today's Ember (Neon #FF8C28 1.2 x 0.5 x 1.2 at y 7.9), which "
                                  "stays exactly (it holds the Attachment FirePoint at y 8.2); CanCollide off, CastShadow off"},
               notes="stylized layered flame (all Neon), rising from the coals at y 7.85 to y 8.85 (the torch grows from "
                     "8.15 to 8.85 = +8.6 %): a tall 5-sided central tongue leaning a little forward, hot yellow #FFD678 "
                     "at the base, #FFB648 in the middle, #FF8C28 at the tip, and 3 shorter 4-sided side tongues "
                     "(#FFB648 base, #FF8C28 tip) leaning outward round it at 0 / 120 / 240 deg. The base rings sit "
                     "under the coal bed (y 7.95), so no open bottom shows. The fire particles and the PointLight of "
                     "today's Decor.VFX.Fire_Torch part keep burning at the FirePoint (y 8.2) inside it.")
    prof = [(0.38, 7.85), (0.40, 8.15), (0.30, 8.45), (0.14, 8.68), (0.0, 8.85)]
    cols = (WARM_N, FLAME_N, FLAME_N, EMBER_N)

    def central():
        n = 5
        rings = []
        for i, (r, y) in enumerate(prof):
            a0 = math.radians(18.0)
            lean = Vector((0.03 * i, 0, -0.02 * i))
            rings.append([Vector((r * math.cos(a0 + 2 * math.pi * k / n), y, r * math.sin(a0 + 2 * math.pi * k / n))) + lean
                          for k in range(n)])
        for s in range(len(prof) - 1):
            lo, hi = rings[s], rings[s + 1]
            for k in range(n):
                j = (k + 1) % n
                mid = (lo[k] + lo[j]) / 2 - Vector((0, lo[k].y, 0)) - Vector((0.03 * s, 0, -0.02 * s))
                c = cols[s] if not (s == 2 and k % 2) else EMBER_N
                if s == len(prof) - 2:
                    pc.face([lo[k], lo[j], hi[0]], c, "Neon", 0.12, mid + Vector((0, 0.3, 0)))
                else:
                    pc.quad_or_tris([lo[k], lo[j], hi[j], hi[k]], c, "Neon", 0.12, mid)
    central()
    for t_i in range(3):
        a = math.radians(90.0 + 120.0 * t_i + 25.0)
        d = Vector((math.cos(a), 0, math.sin(a)))
        c0 = d * 0.36
        sp = [(0.2, 7.9, 0.0), (0.17, 8.2, 0.08), (0.0, 8.5 - 0.04 * t_i, 0.2)]
        n = 4
        rings = []
        for i, (r, y, out) in enumerate(sp):
            cc = c0 + d * out + Vector((0, y, 0))
            rings.append([cc + Vector((r * math.cos(a + math.pi / 4 + 2 * math.pi * k / n), 0, r * math.sin(a + math.pi / 4 + 2 * math.pi * k / n)))
                          for k in range(n)])
        for s in range(2):
            lo, hi = rings[s], rings[s + 1]
            for k in range(n):
                j = (k + 1) % n
                ctr = c0 + d * sp[s][2] + Vector((0, sp[s][1], 0))
                mid = (lo[k] + lo[j]) / 2 - ctr
                if s == 1:
                    pc.face([lo[k], lo[j], hi[0]], EMBER_N, "Neon", 0.1, mid + Vector((0, 0.2, 0)))
                else:
                    pc.quad_or_tris([lo[k], lo[j], hi[j], hi[k]], FLAME_N, "Neon", 0.1, mid)
    return pc


def torch_cup():
    pc = Piece("torch", "cup", TORCH_ORIGIN,
               place={"relativeTo": "the Tribal_Torch model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the Bowl (#68442C 1.9 x 0.8 x 1.9 at y 7.3, CanCollide on): keep an invisible copy of the "
                                  "Bowl for the collision, or let the cup collide"},
               notes="iron fire cup #5C626E on the carved pole head: an 8-sided bowl 1.88 wide across the flats at the rim "
                     "(today's Bowl 1.9), 0.84 at the foot (y 6.95), the rim at y 8.0 with a flat 0.14 lip ring, a dark coal bed "
                     "(#3A2E2A) inside at y 7.95 under today's Neon Ember, a darker forged band (x0.82) round the "
                     "belly, alternating facet tones, and 4 small iron claws rising 0.25 from the rim at 45 / 135 / "
                     "225 / 315 deg (they hold the coals). Turn today's Ember 45 deg about Y if its corners poke "
                     "through the rim (the FirePoint stays at y 8.2).")
    prof = [(0.42, 6.95), (0.66, 7.12), (0.86, 7.45), (1.02, 8.0), (0.88, 8.0)]

    def col(s, k):
        if s == 1:
            return tone(IRON, 0.82)
        if s == 3:
            return tone(IRON, 1.12)
        return tone(IRON, (1.0, 0.92)[k % 2])
    rings = lathe_faces(pc, prof, 8, col, 0.12, start_angle=math.pi / 8)
    polygon_fill(pc, [p + Vector((0, -0.05, 0)) for p in rings[-1]], "#3A2E2A", "SmoothPlastic", 0.1, Vector((0, 1, 0)))
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-d.z, 0, d.x))
        b = d * 0.96 + Vector((0, 7.96, 0))
        pc.face([b - side * 0.12, b + side * 0.12, d * 1.06 + Vector((0, 8.26, 0))], tone(IRON, 0.9), "SmoothPlastic", 0.06, d)
    return pc


SKULL_CRANIUM = [(0.0, 0.86, 0.05), (0.42, 0.78, -0.3), (0.42, 0.78, 0.38), (0.9, 0.36, -0.38), (0.9, 0.36, 0.32),
                 (0.5, 0.35, 0.88), (0.0, 0.12, 0.95), (0.42, 0.5, -0.84), (0.72, 0.16, -0.82), (0.8, -0.32, -0.5),
                 (0.5, -0.45, 0.55), (0.48, -0.62, -0.62), (0.36, -0.82, -0.7), (0.0, -0.84, -0.78), (0.0, -0.55, -0.9)]
SKULL_JAW = [(0.36, -0.86, -0.68), (0.0, -0.88, -0.75), (0.34, -1.2, -0.6), (0.0, -1.26, -0.7), (0.62, -0.88, -0.2),
             (0.6, -1.15, -0.15)]


def human_skull_into(pc, scale, off):
    """Stylized human skull, local frame: (0, 0, 0) = the cranium centre, face -Z, 1.8 wide, 2.1 tall (top +0.85,
    chin -1.26), 1.85 deep; scale / off map it into the piece's space."""
    off = Vector(off)

    def xf(p):
        return Vector(p) * scale + off

    def mirror(src):
        out = []
        for x, y, z in src:
            for s in ((1, -1) if x > 0 else (1,)):
                out.append(xf((s * x, y, z)))
        return out

    def col(cc, n):
        if n.y > 0.55:
            return BONE
        if n.y < -0.5:
            return tone(BONE, 0.8)
        if n.z > 0.5:
            return tone(BONE, 0.9)
        return tone(BONE, 0.95 if abs(n.x) > 0.6 else 0.98)
    tree = hull_into(pc, mirror(SKULL_CRANIUM), col, 0.2 * scale)
    jaw = hull_into(pc, mirror(SKULL_JAW), col, 0.15 * scale,
                    skip=lambda ring: all(p.y >= off.y - 0.9 * scale for p in ring))
    fwd = Vector((0, 0, 1))
    s = scale
    for sx in (-1, 1):
        # eye sockets: a dark brown socket (today's Eye colour) and a darker hollow inside, the brow side higher
        o = xf((sx * 0.38, 0.02, -3.0))
        q = [(-0.23, -0.19), (0.21, -0.2), (0.24, 0.15), (-0.2, 0.2)]
        q = [(a * -sx * s, b * s) for a, b in q]
        if sx > 0:
            q.reverse()
        surface_quad(pc, tree, o, fwd, q, TWOOD, "SmoothPlastic", 0.08 * s, 0.03 * s)
        q2 = [(-0.12, -0.12), (0.12, -0.11), (0.13, 0.08), (-0.11, 0.1)]
        q2 = [(a * -sx * s, b * s) for a, b in q2]
        if sx > 0:
            q2.reverse()
        surface_quad(pc, tree, o, fwd, q2, JREC, "SmoothPlastic", 0.06 * s, 0.06 * s)
        # nose hole: 2 halves of an upside-down heart
        o = xf((sx * 0.07, -0.3, -3.0))
        tri = [(-0.08, -0.15), (0.07, -0.13), (0.0, 0.15)]
        tri = [(a * -sx * s, b * s) for a, b in tri]
        surface_quad(pc, tree, o, fwd, tri, TWOOD, "SmoothPlastic", 0.06 * s, 0.03 * s)
    # upper teeth: a dark gum line and 5 teeth on the maxilla front
    surface_quad(pc, tree, xf((0.0, -0.74, -3.0)), fwd, [(-0.3 * s, -0.08 * s), (0.3 * s, -0.08 * s), (0.3 * s, 0.08 * s),
                                                          (-0.3 * s, 0.08 * s)], TWOOD, "SmoothPlastic", 0.05 * s, 0.03 * s)
    for i in range(5):
        x = (-0.22 + 0.11 * i)
        surface_quad(pc, tree, xf((x, -0.75, -3.0)), fwd, [(-0.04 * s, -0.065 * s), (0.04 * s, -0.065 * s), (0.04 * s, 0.065 * s),
                                                            (-0.04 * s, 0.065 * s)], tone(BONE, 1.03), "SmoothPlastic", 0.05 * s, 0.06 * s)
    # lower teeth on the jaw
    surface_quad(pc, jaw, xf((0.0, -0.95, -3.0)), fwd, [(-0.26 * s, -0.06 * s), (0.26 * s, -0.06 * s), (0.26 * s, 0.07 * s),
                                                         (-0.26 * s, 0.07 * s)], TWOOD, "SmoothPlastic", 0.05 * s, 0.03 * s)
    for i in range(4):
        x = (-0.165 + 0.11 * i)
        surface_quad(pc, jaw, xf((x, -0.95, -3.0)), fwd, [(-0.04 * s, -0.05 * s), (0.04 * s, -0.05 * s), (0.04 * s, 0.06 * s),
                                                           (-0.04 * s, 0.06 * s)], tone(BONE, 1.03), "SmoothPlastic", 0.05 * s, 0.06 * s)
    return tree


def skull_pike_skull():
    pc = Piece("skull_pike", "skull", "the SkullPike_A kit pivot (base centre of the pole, y 0 = the ground, front -Z)",
               place={"relativeTo": "the SkullPike_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "Skull (1.8 x 1.6 x 1.8 at (0.15, 7.1, 0), CanCollide on), Jaw (1.3 x 0.5 x 1.2 at (0.15, "
                                  "6.1, -0.2)) and the 2 Eyes (#4A3022); keep an invisible copy of today's Skull for the "
                                  "collision (the jaw and the eyes did not collide)"},
               notes="stylized human skull on the pike, the cranium centre at (0.15, 7.1, 0) = today's Skull centre, "
                     "1.8 wide x 2.1 tall (y 5.85 = today's jaw bottom .. 7.95) x 1.85 deep: rounded cranium with "
                     "cheekbones, a brow ridge over 2 deep eye sockets (dark brown #4A3022 = today's Eye colour, with a "
                     "darker hollow #292D29), an upside-down heart nose hole, a separate lower jaw, 5 upper and 4 "
                     "lower teeth on dark gum lines. Bone #E8E2D0, darker underneath (x0.8). The pole "
                     "top enters the skull's underside at about (0.0, 6.35).")
    human_skull_into(pc, 1.0, (0.15, 7.1, 0.0))
    return pc


BANNER_ORIGIN = "the WarBanner_A kit pivot (base centre of the pole, y 0 = the ground, front -Z)"


def banner_finial_skull():
    pc = Piece("banner", "finial_skull", BANNER_ORIGIN,
               place={"relativeTo": "the WarBanner_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the Skull (#E8E2D0 1.5 x 1.4 x 1.5 at (0, 15.6, 0), no collision) on the pole top"},
               notes="the skull_pike__skull design at 0.83 (1.5 wide like today's Skull) as the banner's carved bone "
                     "finial: the cranium centre at (0, 15.6, 0), its top at 16.31 (today 16.3), the jaw resting on the "
                     "pole top (y 14.55 .. 15.0); give the pole top a carved collar under it.")
    human_skull_into(pc, 0.83, (0.0, 15.6, 0.0))
    return pc


def decor_feather():
    pc = Piece("decor", "feather", "the piece's own anchor: (0, 0, 0) = the quill's base (the tie point); the feather "
               "points up +Y, 2.2 long, flat in the XY plane (faces look -Z)",
               place={"relativeTo": "WarBanner_A / SkullPike_A (any tie point)",
                      "position": "banner: (0.44, 15.6, 0.3) = the foot of today's Feather; skull pike: hanging from the "
                                  "jaw at (-0.45, 6.0, -0.55) and (0.75, 6.1, -0.4)",
                      "orientation": "banner: [0, 0, -25] (leans out to +X like today's Feather); hanging: [0, yaw, 180 +- 10]",
                      "scale": "banner 1.0 (= today's Feather 2.2 long); skull pike 0.38-0.45 (0.85-1.0 long)",
                      "replaces": "the banner's Feather (#FFAA28 0.5 x 2.2 x 0.2, no collision)", "collide": "CanCollide off"},
               notes="stylized feather: a cream quill (#E8E2D0 x0.9) and a vane of 4 segments per side with notches cut "
                     "between them, orange #FFAA28 (2 tones), a teal #3CAABE band, a dark tip (x0.72).")
    L = 2.2
    pc.face([(-0.035, 0.0, 0.0), (0.035, 0.0, 0.0), (0.03, L * 0.95, 0.0), (-0.03, L * 0.95, 0.0)], tone(BONE, 0.9),
            "SmoothPlastic", 0.07, Vector((0, 0, -1)))
    segs = [0.16, 0.4, 0.62, 0.82, 1.0]
    widths = [0.12, 0.27, 0.28, 0.2, 0.0]
    cols = [tone(FEATHER_O, 0.93), FEATHER_O, TEAL, tone(FEATHER_O, 0.72)]
    for side in (-1, 1):
        for k in range(4):
            s0, s1 = segs[k] * L, segs[k + 1] * L
            notch = 0.08 if k in (1, 2) else 0.0
            pts = [Vector((side * 0.035, s0, -0.005)), Vector((side * 0.035, s1, -0.005)),
                   Vector((side * widths[k + 1], s1 - 0.1 * (k < 3), -0.005)),
                   Vector((side * widths[k], s0 + notch, -0.005))]
            if widths[k + 1] < 1e-6:
                pc.face([pts[0], pts[1], pts[3]], cols[k], "SmoothPlastic", 0.06, Vector((0, 0, -1)))
            else:
                pc.face(pts, cols[k], "SmoothPlastic", 0.06, Vector((0, 0, -1)))
    return pc


def banner_cloth():
    pc = Piece("banner", "cloth", BANNER_ORIGIN,
               place={"relativeTo": "the WarBanner_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "Cloth (4.6 x 8 x 0.2 at (0, 9.2, -0.4)), ClothTail (3.3 square turned 45 deg at y 5.2), "
                                  "Stripe (#3CAABE 4.6 x 1 at y 11.6) and Emblem (#FFC93C 2 x 2 turned 45 deg at (0, 8.8, "
                                  "-0.5)); none collided"},
               notes="red #C44632 war banner, 4.6 wide, hanging from y 13.2 (under the crossbar) to a zigzag lower edge: "
                     "a flat centre field (x -1.7 .. 1.7, front at z -0.5 like today) and 2 pleats per side (ridges at x "
                     "+-2.0 standing 0.16 forward, valleys at the edges). Rows: a darker sleeve hem (x0.8) at the top, "
                     "today's cyan #3CAABE stripe (y 11.1 .. 12.1), red below. Lower edge: 7 teeth (centre point at y "
                     "2.9 = today's ClothTail tip, then 3.9 / 4.45 / 4.9 outward), every tooth edge trimmed with a gold "
                     "#FFC93C band (0.2 wide on the centre teeth, 0.09 on the narrow pleat teeth) on both sides. Stitched emblem on the centre field (front only, like "
                     "today): a dark red #8D3224 patch diamond (half-diagonal 1.58), today's gold diamond (half-diagonal "
                     "1.3, today 1.41), a small cyan centre diamond, 12 cream #E8E2D0 running stitches round the gold.")
    return banner_cloth_into(pc)


def banner_cloth_into(pc, top=13.2, tip=2.9, zf=-0.5, stripe=(12.1, 11.1, TEAL), emblem_y=8.8, base=TRED,
                      centre=TEAL, patch="#8D3224", trim=GOLD):
    """The C6 banner cloth (4.6 wide, flat centre field x +-1.7, 2 pleats per side, 7 trimmed zigzag teeth, the
    stitched diamond emblem), hanging from `top` to the centre tooth tip `tip`, front face at z `zf`."""
    T = 0.18
    dz = zf + 0.5
    st = [(-2.3, -0.5 + dz), (-2.0, -0.66 + dz), (-1.7, -0.5 + dz), (1.7, -0.5 + dz), (2.0, -0.66 + dz), (2.3, -0.5 + dz)]
    # bottom outline per panel (x, y) from its left corner to its right corner
    tip_dy = tip - 2.9
    bottoms = [[(-2.3, 5.6), (-2.15, 4.9), (-2.0, 5.3)],
               [(-2.0, 5.3), (-1.85, 4.45), (-1.7, 4.9)],
               [(-1.7, 4.9), (-1.1, 3.9), (-0.55, 4.6), (0.0, 2.9), (0.55, 4.6), (1.1, 3.9), (1.7, 4.9)],
               [(1.7, 4.9), (1.85, 4.45), (2.0, 5.3)],
               [(2.0, 5.3), (2.15, 4.9), (2.3, 5.6)]]
    bottoms = [[(x, y + tip_dy) for x, y in bot] for bot in bottoms]
    hem = tone(base, 0.8)

    def mapper(i):
        (xa, za), (xb, zb) = st[i], st[i + 1]
        n = Vector((zb - za, 0, -(xb - xa))).normalized()

        def P3(x, y, lift=0.0):
            z = za + (x - xa) / (xb - xa) * (zb - za)
            return Vector((x, y, z)) + n * lift
        return P3, n
    for i, bot in enumerate(bottoms):
        P3, n = mapper(i)
        xa, xb = st[i][0], st[i + 1][0]
        ybot = max(bot[0][1], bot[-1][1])
        if stripe:
            rows = [(top, top - 0.25, hem), (top - 0.25, stripe[0], base), (stripe[0], stripe[1], stripe[2]), (stripe[1], ybot, base)]
        else:
            rows = [(top, top - 0.25, hem), (top - 0.25, ybot, base)]
        for y0, y1, c in rows:
            pc.face([P3(xa, y1), P3(xb, y1), P3(xb, y0), P3(xa, y0)], c, "SmoothPlastic", T, n)
        # the teeth below the rectangle: convex pieces
        if len(bot) == 3:
            poly = [(xa, ybot), bot[0], bot[1], bot[2], (xb, ybot)]
            poly = [p for k, p in enumerate(poly) if k == 0 or (abs(p[0] - poly[k - 1][0]) > 1e-6 or abs(p[1] - poly[k - 1][1]) > 1e-6)]
            pts = [P3(x, y) for x, y in poly]
            if len(pts) == 3:
                pc.face(pts, base, "SmoothPlastic", T, n)
            elif len(pts) == 4:
                pc.face(pts, base, "SmoothPlastic", T, n)
            else:
                polygon_fill(pc, pts, base, "SmoothPlastic", T, n)
        else:
            for piece in ([(-1.7, 4.9), (-1.1, 3.9), (-0.55, 4.6), (-0.55, 4.9)],
                          [(-0.55, 4.9), (-0.55, 4.6), (0.0, 2.9), (0.55, 4.6), (0.55, 4.9)],
                          [(0.55, 4.9), (0.55, 4.6), (1.1, 3.9), (1.7, 4.9)]):
                pts = [P3(x, y + tip_dy) for x, y in piece]
                if len(pts) <= 4:
                    pc.face(pts, base, "SmoothPlastic", T, n)
                else:
                    polygon_fill(pc, pts, base, "SmoothPlastic", T, n)
        # gold trim along the zigzag edge, front and back (mitred offset polyline, 0.2 wide)
        w = 0.2 if len(bot) > 3 else 0.09
        segn = []
        for k in range(len(bot) - 1):
            dx, dy = bot[k + 1][0] - bot[k][0], bot[k + 1][1] - bot[k][1]
            L = math.hypot(dx, dy)
            segn.append((-dy / L, dx / L))
        off = []
        for k in range(len(bot)):
            if k == 0 or k == len(bot) - 1:
                nn = segn[0] if k == 0 else segn[-1]
                off.append((bot[k][0], bot[k][1] + w / nn[1]))
            else:
                a, b = segn[k - 1], segn[k]
                m = (a[0] + b[0], a[1] + b[1])
                ml = math.hypot(*m)
                m = (m[0] / ml, m[1] / ml)
                d = w / (m[0] * a[0] + m[1] * a[1])
                off.append((bot[k][0] + m[0] * d, bot[k][1] + m[1] * d))
        for k in range(len(bot) - 1):
            q2 = [bot[k], bot[k + 1], off[k + 1], off[k]]
            for lift, out, c in ((0.035, n, trim), (-(T + 0.035), -n, tone(trim, 0.9))):
                pc.face([P3(x, y, lift) for x, y in q2], c, "SmoothPlastic", 0.035, out)
    # stitched emblem on the centre field (plane z = -0.5, front only)
    P3, n = mapper(2)
    cy = emblem_y

    def diamond(h, lift, c, t):
        pc.face([P3(0.0, cy - h, lift), P3(h, cy, lift), P3(0.0, cy + h, lift), P3(-h, cy, lift)], c, "SmoothPlastic", t, n)
    diamond(1.58, 0.03, patch, 0.03)
    diamond(1.3, 0.06, GOLD, 0.03)
    diamond(0.38, 0.09, centre, 0.03)
    corners = [(0.0, cy - 1.44), (1.44, cy), (0.0, cy + 1.44), (-1.44, cy)]
    for k in range(4):
        a, b = corners[k], corners[(k + 1) % 4]
        d = Vector((b[0] - a[0], b[1] - a[1], 0)).normalized()
        pp = Vector((-d.y, d.x, 0))
        for f in (0.25, 0.5, 0.75):
            c = Vector((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, 0))
            q = [c - d * 0.11 - pp * 0.03, c + d * 0.11 - pp * 0.03, c + d * 0.11 + pp * 0.03, c - d * 0.11 + pp * 0.03]
            pc.face([P3(v.x, v.y, 0.06) for v in q], BONE, "SmoothPlastic", 0.03, n)
    return pc




def jungle_decor():
    return [torch_flame(), torch_cup(), skull_pike_skull(), banner_cloth(), banner_finial_skull(), decor_feather()]


def preview_jungle_decor(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    # torch (today's parts as context, minus Bowl / Skull: the cup replaces the Bowl)
    tc = [((0, 0.25, 0), (1.7, 0.5, 1.7), JSTONE, (0, 0, 0)), ((0, 3.6, 0), (0.7, 7.0, 0.7), JWOOD_D, (0, 0, 0)),
          ((0, 5.2, 0), (0.95, 0.8, 0.95), THATCH, (0, 0, 0)), ((0, 6.3, 0), (0.9, 0.9, 0.9), BONE, (0, 0, 0)),
          ((0, 6.85, 0), (1.0, 0.25, 1.0), "#68442C", (0, 0, 0)), ((0, 7.9, 0), (1.2, 0.5, 1.2), EMBER_N, (0, 45, 0))]
    g1 = context_boxes(tc, col) + [piece_object(by["torch__cup"], col), piece_object(by["torch__flame"], col)]
    # skull pike
    sx = 6.0
    sc = [((sx - 0.08, 3.3, 0), (0.5, 6.6, 0.5), JWOOD_D, (0, 0, 2.9)), ((sx, 0.2, 0), (1.4, 0.4, 1.4), JSTONE_D, (0, 0, 0))]
    off = Vector((sx, 0, 0))
    g2 = context_boxes(sc, col) + [piece_object(by["skull_pike__skull"], col, off)]
    for pos, ori, s in (((-0.45, 6.0, -0.55), (0, 20, 185), 0.42), ((0.75, 6.1, -0.4), (0, -15, 172), 0.38)):
        g2.append(piece_object(by["decor__feather"], col, off + Vector(pos), euler_matrix(ori), s))
    # banner
    bx = 13.0
    bc = [((bx, 7.5, 0), (0.6, 15.0, 0.6), JWOOD_D, (0, 0, 0)), ((bx, 13.4, 0), (5.6, 0.5, 0.5), JWOOD_D, (0, 0, 0))]
    boff = Vector((bx, 0, 0))
    g3 = context_boxes(bc, col) + [piece_object(by["banner__cloth"], col, boff), piece_object(by["banner__finial_skull"], col, boff),
                                   piece_object(by["decor__feather"], col, boff + Vector((0.44, 15.6, 0.3)), euler_matrix([0, 0, -25]))]
    out = os.path.join(P.PREVIEW_DIR, "jungle_decor_facets.png")
    return render_sheet("jdecor", [(g1, [(-25, 8)]), (g1[-2:], [(-30, 30)]), (g2, [(-25, 6)]), (g2[2:3], [(-20, 5)]),
                                   (g3, [(-20, 6)]), (g3[2:], [(35, 8)])], None, out)


# ------------------------------------------------------------------------------------------------
# JUNGLE ROCKS AND PLANTS (guide section C7): layered rock bodies + soft moss mounds with grass tufts (Mossy_Rock_S /
# M / L, Waterfall_Rock_Set), the waterfall's bevelled water and chipped basin slab, lily pads + lotus, a bamboo leaf
# spray, bush flowers / base leaves / an optional leaf clump. HUNDREDS of copies (bush 226, small rock 70): every
# piece is budgeted (see C7); everything else is parts.
# ------------------------------------------------------------------------------------------------
from mathutils import Matrix as _Mx

LOTUS, LOTUS_L, WATER, WATER_L, FOAM = "#FF508C", "#FF8DB4", "#30C4BE", "#7FE3DE", "#F5F6FA"
PALE = "#D3D9CF"   # the basin slab (today's Foam is a pale white plate; owner: "a pale slab")


def _cf(pos, rot):
    """rbxm CFrame (row-major 3x3) -> (Matrix, Vector)."""
    r = rot
    return _Mx(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8]))), Vector(pos)


def rock_layers_into(pc, cf, size, layers, rng, base, n=7, sink=None):
    """Layered faceted rock inside a MeshPart's box: layers [(v0, v1, cu, cw, ku, kw)] in fractions of the box
    (v = -0.5 .. 0.5 along local Y, cu / cw = centre offsets in fractions of X / Z, ku / kw = half-widths in
    fractions); points built in the part's local frame then moved by its CFrame. Faces darker low (kit-space
    gradient), 3 tone steps, the top of each layer a little lighter; faces under `sink` (kit y) are dropped."""
    R, P0 = cf
    sx, sy, sz = size
    trees = []
    allp = []
    bottoms = []
    for li, (v0, v1, cu, cw, ku, kw) in enumerate(layers):
        pts = []
        for vv, k in ((v0, 0.86 if li else 0.94), (v1, 0.62 if li == len(layers) - 1 else 0.95)):
            a0 = rng.uniform(0, 2 * math.pi / n)
            for i in range(n):
                a = a0 + 2 * math.pi * i / n + rng.uniform(-0.15, 0.15)
                c, s = math.cos(a), math.sin(a)
                r = (abs(c) ** 2.1 + abs(s) ** 2.1) ** (-1 / 2.1) * rng.uniform(0.86, 1.04) * k
                loc = Vector(((cu + ku * r * c) * sx, (vv + rng.uniform(-0.04, 0.04) * (0 < li or vv > v0)) * sy,
                              (cw + kw * r * s) * sz))
                pts.append(R @ loc + P0)
        bottoms.append({tuple(round(c, 4) for c in p) for p in pts[:n]})
        if li == len(layers) - 1:
            pts.append(R @ Vector(((cu + rng.uniform(-0.1, 0.1) * ku) * sx, (v1 + 0.06) * sy, cw * sz)) + P0)
        allp += pts
        trees.append(pts)
    H0 = min(p.y for p in allp)
    H1 = max(p.y for p in allp)
    out = []
    for pts, bset in zip(trees, bottoms):
        def col(cc, nrm):
            h = max(0.0, min(1.0, (cc.y - H0) / max(H1 - H0, 1e-6)))
            g = 0.8 + 0.2 * (h * h * (3 - 2 * h))
            if nrm.y > 0.65:
                return tone(base, min(1.06, g + 0.07))
            return tone(base, g * rng.choice(STEPS))
        lim = H0 + 0.05 if sink is None else sink
        out.append(hull_into(pc, pts, col, 0.5, skip=lambda ring, lim=lim, bset=bset: all(p.y <= lim for p in ring) or
                             all(tuple(round(c, 4) for c in p) in bset for p in ring)))
    return out


def rock_crack(pc, trees, origin, direction, L, ang, s=1.0):
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    pts2 = [(-0.06 * s, -L / 2), (0.06 * s, -L / 2), (0.1 * s + 0.18 * L, 0.0), (0.0 + 0.18 * L, 0.0)]
    pts2b = [(0.0 + 0.18 * L, 0.0), (0.1 * s + 0.18 * L, 0.0), (0.08 * s, L / 2), (-0.03 * s, L / 2)]
    for tree in trees:
        if surface_quad(pc, tree, origin, direction, [(u * ca - v * sa, u * sa + v * ca) for u, v in pts2], JREC,
                        "SmoothPlastic", 0.08, 0.03):
            surface_quad(pc, tree, origin, direction, [(u * ca - v * sa, u * sa + v * ca) for u, v in pts2b], JREC,
                         "SmoothPlastic", 0.08, 0.03)
            return True
    return False


def _top_hit(trees, x, z):
    best = None
    for t in trees:
        hit = t.ray_cast(Vector((x, 500.0, z)), Vector((0, -1, 0)))
        if hit[0] is not None and (best is None or hit[0].y > best[0].y):
            best = (hit[0], hit[1])
    return best


def moss_mound_into(pc, trees, cx, cz, rx, rz, yaw, rng, layers, tufts=2):
    """Soft layered moss lying ON the rock top: each layer = an irregular ring projected down onto the rock's
    facets (lifted so no rock edge pokes through) + a raised centre: a low faceted mound; the next layers smaller,
    lighter, offset toward the light. layers: [(scale, dx, dz, H, (col, col2), n)]. tufts: 3-blade grass tufts."""
    ya = math.radians(yaw)
    lift = 0.0
    for li, (k, dx, dz, H, cols, n) in enumerate(layers):
        for _ in range(60):
            ring2 = []
            for i in range(n):
                a = 2 * math.pi * i / n + rng.uniform(-0.18, 0.18)
                r = rng.uniform(0.82, 1.06)
                ring2.append((rx * k * r * math.cos(a), rz * k * r * math.sin(a)))
            if _convex(ring2):
                break
        ring = []
        c0 = _top_hit(trees, cx + dx, cz + dz)
        for x, z in ring2:
            for _ in range(12):   # stay on the rock's top: pull a point in while it falls off the side
                xx = cx + dx + x * math.cos(ya) - z * math.sin(ya)
                zz = cz + dz + x * math.sin(ya) + z * math.cos(ya)
                h = _top_hit(trees, xx, zz)
                if h is not None and (c0 is None or c0[0].y - h[0].y <= 0.45 * max(rx, rz) * k + 0.1):
                    break
                x, z = x * 0.88, z * 0.88
            if h is None:
                continue
            ring.append(Vector((xx, h[0].y + 0.06 + lift, zz)))
        if len(ring) < 3:
            continue
        # lift the rim where the rock bulges between two ring points
        for _ in range(3):
            for i in range(len(ring)):
                j = (i + 1) % len(ring)
                m = (ring[i] + ring[j]) / 2
                h = _top_hit(trees, m.x, m.z)
                if h is not None and h[0].y + 0.04 + lift > m.y:
                    d = h[0].y + 0.04 + lift - m.y
                    ring[i].y += d
                    ring[j].y += d
        c = sum(ring, Vector()) / len(ring)
        hc = _top_hit(trees, c.x, c.z)
        # a soft blanket: the rim on the rock, an inner ring 0.6 in lifted H above the rock (it follows the curve),
        # a low centre; no rock facet may poke through (each triangle is sampled, the inner ring raised if needed)
        inner = []
        for p in ring:
            q = c.lerp(p, 0.6)
            h = _top_hit(trees, q.x, q.z)
            inner.append(Vector((q.x, (h[0].y if h else q.y) + lift + 0.06 + H, q.z)))
        peak = Vector((c.x, max(p.y for p in inner) + H * 0.15, c.z))
        for _ in range(4):
            need = 0.0
            for i in range(len(ring)):
                j = (i + 1) % len(ring)
                for tri in ((ring[i], ring[j], inner[j]), (ring[i], inner[j], inner[i]), (inner[i], inner[j], peak)):
                    q = (tri[0] + tri[1] + tri[2]) / 3
                    h = _top_hit(trees, q.x, q.z)
                    if h is not None and h[0].y + 0.04 > q.y:
                        need = max(need, h[0].y + 0.04 - q.y)
            if need <= 1e-4:
                break
            need = min(need * 1.5, H)
            inner = [p + Vector((0, need, 0)) for p in inner]
            peak.y += need
        for i in range(len(ring)):
            j = (i + 1) % len(ring)
            out = (ring[i] + ring[j]) / 2 - c + Vector((0, 1.0, 0))
            pc.quad_or_tris([ring[i], ring[j], inner[j], inner[i]], cols[1], "SmoothPlastic", 0.12, out)
            pc.face([inner[i], inner[j], peak], cols[0] if i % 2 else tone(cols[0], 0.95), "SmoothPlastic", 0.12, Vector((0, 1, 0)))
        lift += H * 0.45
        if li == 0:
            top_ring, top_peak = inner, peak
    for _ in range(tufts):
        i = rng.randrange(len(top_ring))
        f = rng.uniform(0.1, 0.5)
        base = top_ring[i].lerp(top_peak, f)
        for b in range(3):
            ang = rng.uniform(0, 2 * math.pi)
            d = Vector((math.cos(ang), 0, math.sin(ang)))
            w = Vector((-d.z, 0, d.x)) * 0.09 * min(max(rx, 1.0), 2.5) ** 0.3
            tip = base + d * rng.uniform(0.15, 0.3) * min(max(rx, 1.0), 2.5) ** 0.5 + Vector((0, rng.uniform(0.35, 0.6) * min(max(rx, 1.0), 2.5) ** 0.5, 0))
            pc.face([base - w, base + w, tip], JMOSS_LL if b % 2 else JMOSS_L, "SmoothPlastic", 0.05, Vector((d.z, 0.0, -d.x)))


def _rock_piece(kit, name, origin_kit, notes, replaces):
    return Piece(kit, name, f"the {origin_kit} kit pivot (y 0 = the kit's pivot height, front -Z)",
                 place={"relativeTo": f"the {origin_kit} model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                        "replaces": replaces, "scale": "the copy's scale (bakedScale: many copies were resized part by part)"},
                 notes=notes)


def rock_s():
    rng = random.Random(6101)
    body = _rock_piece("rock_s", "body", "Mossy_Rock_S",
                       "small mossy rock, the shape of today's Rock box (4.6 x 3.0 x 4.6, y -0.2 .. 2.8): 2 stacked natural "
                       "layers (the upper one domed and offset = strata), 7-sided jittered rings, darker at the bottom "
                       "(x0.8), 3 tone steps of #848A7C, a dark crack on the front.",
                       "the look of the Rock MeshPart (keep it, Transparency 1, as the collider: option (a)); no collision on the piece")
    cf = _cf((0.0, 1.3, 0.0), (1, 0, 0, 0, 1, 0, 0, 0, 1))
    trees = rock_layers_into(body, cf, (4.6, 3.0, 4.6), [(-0.5, -0.02, 0.0, 0.0, 0.46, 0.45), (-0.06, 0.5, 0.04, -0.03, 0.47, 0.46)],
                             rng, JSTONE, n=7)
    rock_crack(body, trees, (-0.5, 1.0, -30), (0, 0, 1), 0.9, 15)
    moss = _rock_piece("rock_s", "moss", "Mossy_Rock_S",
                       "soft layered moss on the small rock's top (where today's Moss is, centre (0.2, z 0)): 2 low faceted "
                       "mounds lying on the rock facets (#589642 -> #60C448), the upper one smaller and offset, 2 grass "
                       "tufts (3 blades, #78D246 / #60C448). Built on rock_s__body.",
                       "the Moss MeshPart (CanCollide off like today)")
    moss_mound_into(moss, trees, 0.2, 0.0, 1.85, 1.75, 60, rng,
                    [(1.0, 0.0, 0.0, 0.3, (JMOSS, tone(JMOSS, 0.9)), 6), (0.55, 0.25, -0.15, 0.16, (JMOSS_L, tone(JMOSS_L, 0.92)), 4)], tufts=2)
    return [body, moss]


def rock_m():
    rng = random.Random(6202)
    body = _rock_piece("rock_m", "body", "Mossy_Rock_M",
                       "round mossy rock in today's tilted Rock box (8 x 8.5 x 8.4 at (0, 4, 0), turned 40 deg, tilted 8 deg): "
                       "3 stacked rounded layers (strata, the middle one widest = round), the top one domed, darker #5C645C base tone, 3 tone steps, "
                       "lighter tops, 2 cracks.",
                       "the look of the Rock MeshPart (keep it, Transparency 1, as the collider)")
    cf = _cf((0.0, 4.0, 0.0), (0.7586, -0.1066, 0.6428, 0.1392, 0.9903, 0.0, -0.6365, 0.0895, 0.766))
    trees = rock_layers_into(body, cf, (8.0, 8.5, 8.4), [(-0.5, -0.12, 0.0, 0.0, 0.42, 0.42), (-0.16, 0.22, -0.02, 0.03, 0.5, 0.49),
                                                         (0.18, 0.5, 0.03, 0.0, 0.46, 0.46)], rng, JSTONE_D, n=8)
    rock_crack(body, trees, (-1.2, 3.0, -30), (0, 0, 1), 1.6, 20, 1.4)
    rock_crack(body, trees, (1.6, 5.2, -30), (0, 0, 1), 1.2, -25, 1.2)
    moss = _rock_piece("rock_m", "moss", "Mossy_Rock_M",
                       "soft layered moss cap on the round rock (today's Moss centre (0.3, z 0)): 3 low faceted mounds "
                       "(#589642 -> #60C448 -> #78D246) lying on the rock, each smaller and offset, 3 grass tufts.",
                       "the Moss MeshPart (CanCollide off)")
    moss_mound_into(moss, trees, 0.3, 0.0, 3.3, 3.2, 20, rng,
                    [(1.0, 0.0, 0.0, 0.42, (JMOSS, tone(JMOSS, 0.9)), 7), (0.62, 0.4, -0.3, 0.24, (JMOSS_L, tone(JMOSS_L, 0.92)), 5),
                     (0.3, -0.5, 0.4, 0.16, (JMOSS_LL, tone(JMOSS_LL, 0.92)), 4)], tufts=3)
    return [body, moss]


def rock_l():
    rng = random.Random(6303)
    body = _rock_piece("rock_l", "body", "Mossy_Rock_L",
                       "the large mossy rock pair in today's 2 Rock boxes: the big rock 21 x 14.5 x 18 at (0, 6.8, 0) turned "
                       "20 deg (4 stacked strata layers, #848A7C) and the small one 9 x 10.5 x 9 at (8.5, 4.8, -5.5) tilted "
                       "(3 layers, darker #5C645C); 3 tone steps, darker low, 4 cracks.",
                       "the look of the 2 Rock MeshParts (keep them, Transparency 1, as the colliders)")
    big = rock_layers_into(body, _cf((0.0, 6.8, 0.0), (0.9397, 0.0, 0.342, 0.0, 1.0, 0.0, -0.342, 0.0, 0.9397)), (21.0, 14.5, 18.0),
                           [(-0.5, -0.22, 0.0, 0.0, 0.47, 0.46), (-0.25, 0.06, 0.02, -0.02, 0.5, 0.49), (0.03, 0.3, -0.03, 0.03, 0.47, 0.46),
                            (0.26, 0.5, 0.02, 0.0, 0.42, 0.41)], rng, JSTONE, n=8)
    small = rock_layers_into(body, _cf((8.5, 4.8, -5.5), (0.4938, -0.0782, 0.866, 0.2304, 0.9721, -0.0436, -0.8385, 0.221, 0.4981)),
                             (9.0, 10.5, 9.0), [(-0.5, -0.12, 0.0, 0.0, 0.44, 0.44), (-0.15, 0.22, 0.03, 0.0, 0.49, 0.48),
                                                (0.19, 0.5, -0.02, 0.02, 0.45, 0.45)], rng, JSTONE_D, n=7)
    for o, L, a, s in (((-4.0, 5.0, -40), 3.0, 15, 2.2), ((2.5, 9.5, -40), 2.4, -20, 2.0), ((-7.0, 9.0, -40), 2.0, 40, 1.8)):
        rock_crack(body, small + big, o, (0, 0, 1), L, a, s)
    rock_crack(body, small, (8.0, 4.0, -40), (0, 0, 1), 1.8, 10, 1.6)
    moss = _rock_piece("rock_l", "moss", "Mossy_Rock_L",
                       "soft layered moss on the large rocks (today's 2 Moss places: (-0.5, z 0.5) on the big rock, (8.6, z "
                       "-5.4) on the small one): 3 + 2 low faceted mounds (#589642 -> #60C448 -> #78D246) lying on the "
                       "facets, grass tufts.",
                       "the 2 Moss MeshParts (CanCollide off; the 2 Jungle_2 copies with MapFixCollide: see C7)")
    moss_mound_into(moss, big, -0.5, 0.5, 7.4, 6.4, 50, rng,
                    [(1.0, 0.0, 0.0, 0.6, (JMOSS, tone(JMOSS, 0.9)), 9), (0.6, 1.2, -0.8, 0.35, (JMOSS_L, tone(JMOSS_L, 0.92)), 7),
                     (0.3, -1.4, 1.0, 0.22, (JMOSS_LL, tone(JMOSS_LL, 0.92)), 5)], tufts=4)
    moss_mound_into(moss, small, 8.6, -5.4, 3.0, 2.9, 10, rng,
                    [(1.0, 0.0, 0.0, 0.36, (tone(JMOSS_L, 0.95), tone(JMOSS_L, 0.86)), 7), (0.55, 0.3, -0.2, 0.2, (JMOSS_LL, tone(JMOSS_LL, 0.92)), 5)],
                    tufts=2)
    return [body, moss]


WF_ORIGIN = "Waterfall_Rock_Set"


def waterfall_pieces():
    rng = random.Random(6404)
    rocks = _rock_piece("waterfall", "rocks", WF_ORIGIN,
                        "the 2 mossy rocks either side of the falls, in today's Rock boxes (left 8.5 x 8.5 x 10 at (-7.5, 3.6, "
                        "0.5) #5C645C, right 9 x 7.4 x 10 at (7.5, 3.2, 0.5) #848A7C): 3 strata layers each, cracks, plus "
                        "their soft layered moss mounds and grass tufts at today's 2 Moss places.",
                        "the look of the 2 Rock and 2 Moss MeshParts (keep the Rocks, Transparency 1, as colliders; Moss off)")
    L = rock_layers_into(rocks, _cf((-7.5, 3.6, 0.5), (0.7618, -0.0801, 0.6428, 0.1045, 0.9945, 0.0, -0.6393, 0.0672, 0.766)), (8.5, 8.5, 10.0),
                         [(-0.5, -0.12, 0.0, 0.0, 0.44, 0.44), (-0.15, 0.22, 0.02, 0.02, 0.49, 0.49), (0.19, 0.5, -0.02, 0.0, 0.45, 0.45)],
                         rng, JSTONE_D, n=7)
    R = rock_layers_into(rocks, _cf((7.5, 3.2, 0.5), (-0.342, 0.0, 0.9397, 0.0, 1.0, 0.0, -0.9397, 0.0, -0.342)), (9.0, 7.4, 10.0),
                         [(-0.5, -0.12, 0.0, 0.0, 0.44, 0.44), (-0.15, 0.22, 0.03, 0.0, 0.49, 0.48), (0.19, 0.5, 0.0, 0.03, 0.45, 0.45)],
                         rng, JSTONE, n=7)
    rock_crack(rocks, L, (-8.5, 3.0, -30), (0, 0, 1), 1.6, 15, 1.4)
    rock_crack(rocks, R, (8.5, 2.6, -30), (0, 0, 1), 1.4, -20, 1.3)
    moss_mound_into(rocks, L, -7.4, 0.6, 3.0, 3.0, 20, rng,
                    [(1.0, 0.0, 0.0, 0.36, (JMOSS, tone(JMOSS, 0.9)), 7), (0.55, 0.3, -0.3, 0.2, (JMOSS_L, tone(JMOSS_L, 0.92)), 5)], tufts=2)
    moss_mound_into(rocks, R, 7.6, 0.4, 3.0, 3.0, 70, rng,
                    [(1.0, 0.0, 0.0, 0.34, (tone(JMOSS_L, 0.95), tone(JMOSS_L, 0.86)), 7), (0.55, -0.3, -0.3, 0.18, (JMOSS_LL, tone(JMOSS_LL, 0.92)), 5)],
                    tufts=2)
    water = Piece("waterfall", "water", f"the {WF_ORIGIN} kit pivot (front -Z)",
                  place={"relativeTo": f"the {WF_ORIGIN} model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                         "replaces": "WaterTop (7.4 x 0.4 x 8 at (0, 4.7, 2)) and WaterFall (7.2 x 5 x 0.6 at (0, 2.3, -2.2), tilted "
                                     "6 deg); both CanCollide off like today. Set Transparency 0.15 on the falling sheet faces "
                                     "(today's WaterFall)", "collide": "CanCollide off"},
                  notes="the cyan water block with bevels, today's #30C4BE and size: a flat top (y 4.9, x +-3.45) with "
                        "0.25 bevels down to the block's sides and back (y 4.6), a rounded 2-band lip over the front edge "
                        "(z -2.0 -> -2.45), the falling sheet 7.2 wide down to the basin (y 0.35 at z -2.75), 4 lighter "
                        "#7FE3DE streaks on it and 2 on the top, a white #F5F6FA foam line on the lip.")
    T = 0.25
    hx, y0, y1, zf, zb = 3.7, 4.55, 4.9, -2.0, 6.0
    b = 0.25
    top = [Vector((-hx + b, y1, zf)), Vector((hx - b, y1, zf)), Vector((hx - b, y1, zb - b)), Vector((-hx + b, y1, zb - b))]
    water.face(top, WATER, "SmoothPlastic", T, Vector((0, 1, 0)))
    for sx in (-1, 1):
        water.face([Vector((sx * (hx - b), y1, zf)), Vector((sx * hx, y0, zf)), Vector((sx * hx, y0, zb)), Vector((sx * (hx - b), y1, zb - b))],
                   tone(WATER, 0.9), "SmoothPlastic", T, Vector((sx, 1, 0)))
    water.face([Vector((-hx + b, y1, zb - b)), Vector((hx - b, y1, zb - b)), Vector((hx, y0, zb)), Vector((-hx, y0, zb))],
               tone(WATER, 0.9), "SmoothPlastic", T, Vector((0, 1, 1)))
    # lip: 2 bands curving over the front edge, then the sheet
    prof = [(y1, zf), (y1 - 0.12, zf - 0.3), (y1 - 0.4, zf - 0.45), (0.35, -2.75)]
    cols = (tone(WATER, 1.08), WATER, tone(WATER, 0.95))
    for i in range(3):
        (ya, za), (yb, zb_) = prof[i], prof[i + 1]
        wa = hx - b if i == 0 else 3.6
        wb = 3.6
        q = [Vector((-wa, ya, za)), Vector((wa, ya, za)), Vector((wb, yb, zb_)), Vector((-wb, yb, zb_))]
        water.quad_or_tris(q, cols[i], "SmoothPlastic", T, Vector((0, 0.3, -1)))
    # foam line along the lip, streaks on the sheet and the top
    (ya, za), (yb, zb_) = prof[1], prof[2]
    d = Vector((0, yb - ya, zb_ - za)).normalized()
    nrm = Vector((0, d.z, -d.y)) if Vector((0, d.z, -d.y)).z < 0 else Vector((0, -d.z, d.y))
    p0 = Vector((0, ya, za)) + d * 0.05 + nrm * 0.03
    water.face([p0 + Vector((-3.4, 0, 0)), p0 + Vector((3.4, 0, 0)), p0 + Vector((3.4, 0, 0)) + d * 0.14, p0 + Vector((-3.4, 0, 0)) + d * 0.14],
               FOAM, "SmoothPlastic", 0.04, nrm)
    (ya, za), (yb, zb_) = prof[2], prof[3]
    d = Vector((0, yb - ya, zb_ - za))
    L = d.length
    d.normalize()
    nrm = Vector((0, -d.z, d.y))
    if nrm.z > 0:
        nrm = -nrm
    for x, w, f0, f1 in ((-2.4, 0.22, 0.05, 0.7), (-0.9, 0.16, 0.15, 0.95), (0.7, 0.24, 0.0, 0.8), (2.3, 0.16, 0.2, 1.0)):
        a = Vector((x, ya, za)) + d * (L * f0) + nrm * 0.03
        c = Vector((x, ya, za)) + d * (L * f1) + nrm * 0.03
        water.face([a - Vector((w / 2, 0, 0)), a + Vector((w / 2, 0, 0)), c + Vector((w / 2, 0, 0)), c - Vector((w / 2, 0, 0))],
                   WATER_L, "SmoothPlastic", 0.04, nrm)
    for x, z0, z1 in ((-1.4, 1.0, 4.6), (1.2, -0.6, 3.2)):
        water.face([Vector((x - 0.09, y1 + 0.03, z0)), Vector((x + 0.09, y1 + 0.03, z0)), Vector((x + 0.09, y1 + 0.03, z1)),
                    Vector((x - 0.09, y1 + 0.03, z1))], WATER_L, "SmoothPlastic", 0.03, Vector((0, 1, 0)))
    basin = Piece("waterfall", "basin", f"the {WF_ORIGIN} kit pivot (front -Z)",
                  place={"relativeTo": f"the {WF_ORIGIN} model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                         "replaces": "Foam (#F5F6FA 8.4 x 0.3 x 3 at (0, 0.2, -3.6), T 0.3, no collision) = the owner's 'pale slab'",
                         "collide": "CanCollide off (like today's Foam)"},
                  notes="the pale slab under the falls: a chipped pale stone slab #D3D9CF (8.4 x 3.0 footprint, top y 0.35 "
                        "like today's Foam, 0.12 bevel, chipped corners, a crack), a white foam ring (#F5F6FA, set "
                        "Transparency 0.3 like today) where the sheet lands and 3 small foam blobs.")
    slab_into(basin, chipped_outline(4.2, 1.5, 0.0, rng, chip=(0.2, 0.45), cx=0.0, cz=-3.6), 0.35, 0.0, PALE, rng, bevel=0.12, cracks=1)
    ring = []
    for i in range(8):
        a = 2 * math.pi * i / 8
        ring.append(Vector((3.0 * math.cos(a) * rng.uniform(0.9, 1.05), 0.39, -2.95 + 0.55 * math.sin(a) * rng.uniform(0.9, 1.05))))
    polygon_fill(basin, ring, FOAM, "SmoothPlastic", 0.04, Vector((0, 1, 0)))
    for x, z, r in ((-2.8, -4.1, 0.35), (1.9, -4.4, 0.3), (0.2, -3.9, 0.25)):
        c = Vector((x, 0.42, z))
        pk = c + Vector((0, 0.12, 0))
        rr = [c + Vector((r * math.cos(2 * math.pi * k / 4 + 0.4), 0, r * math.sin(2 * math.pi * k / 4 + 0.4))) for k in range(4)]
        for k in range(4):
            basin.face([rr[k], rr[(k + 1) % 4], pk], FOAM, "SmoothPlastic", 0.04, (rr[k] + rr[(k + 1) % 4]) / 2 - c + Vector((0, 0.5, 0)))
    return [rocks, water, basin]


def lily_pad_into(pc, cx, cz, y, R, base, n, rng, notch_a=0.0, veins=5):
    """Round lily pad with a V notch, a slightly domed centre, an upturned (curled) rim band and lighter veins."""
    c = Vector((cx, y + 0.06 * R / 2.6 + 0.02, cz))
    angs = [notch_a + 2 * math.pi * (i + 0.5) / n for i in range(n)]
    ring = [Vector((cx + R * math.cos(a), y, cz + R * math.sin(a))) for a in angs]
    rim = [c + (p - c) * 1.0 + Vector((math.cos(a), 0, math.sin(a))) * (0.07 * R) + Vector((0, 0.07 * R + 0.03, 0)) - Vector((0, c.y - y, 0))
           for p, a in zip(ring, angs)]
    lighter = mix(base, "#FFFFFF", 0.22)
    for i in range(n - 1):   # the notch = no face between the last and the first ring point
        j = i + 1
        pc.face([c, ring[i], ring[j]], tone(base, (1.0, 0.94)[i % 2]), "SmoothPlastic", 0.08, Vector((0, 1, 0)))
        pc.quad_or_tris([ring[i], rim[i], rim[j], ring[j]], tone(base, 0.86), "SmoothPlastic", 0.06, Vector((0, 1, 0)))
    # veins: thin lighter strips lying on every other fan triangle (in its plane)
    for v in range(veins):
        i = 1 + v * max(1, (n - 2) // veins)
        if i >= n - 1:
            break
        a, b = ring[i], ring[i + 1]
        m = (a + b) / 2
        p0 = c.lerp(m, 0.12)
        p1 = c.lerp(m, 0.85)
        side = (b - a).normalized() * 0.035 * R
        nrm = (a - c).cross(b - c).normalized()
        if nrm.y < 0:
            nrm = -nrm
        lift = nrm * 0.02
        pc.face([p0 - side + lift, p0 + side + lift, p1 + side * 0.4 + lift, p1 - side * 0.4 + lift], lighter, "SmoothPlastic", 0.03, nrm)


def lily_pieces():
    rng = random.Random(6505)
    origin = "the LilyPad_A kit pivot (y 0 = the water surface the pads float on, front -Z)"
    pads = Piece("lily", "pads", origin,
                 place={"relativeTo": "the LilyPad_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                        "replaces": "the 2 Pad cylinders (#289642 5.2 across at (0, 0.13, 0); #78D246 3.2 across at (3.4, 0.11, 1.8)); "
                                    "no collision like today", "scale": "the copy's scale (bakedScale)"},
                 notes="the 2 round lily pads at today's places and sizes, top at y 0.25 like today: a 14 / 11-sided "
                       "disc with a V notch to the centre, slightly domed, an upturned curled rim band (x0.86), 4-5 "
                       "lighter veins; big #289642, small #78D246.")
    lily_pad_into(pads, 0.0, 0.0, 0.2, 2.6, "#289642", 14, rng, notch_a=math.radians(-35), veins=5)
    lily_pad_into(pads, 3.4, 1.8, 0.18, 1.6, "#78D246", 11, rng, notch_a=math.radians(120), veins=4)
    lotus = Piece("lily", "lotus", origin,
                  place={"relativeTo": "the LilyPad_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                         "replaces": "the Bloom (#FF508C 1.3 x 0.9 x 1.3 at (0.6, 0.65, -0.5), turned 45 deg; no script, no "
                                     "collision): keep a part named Bloom if wanted (invisible) - nothing reads it",
                         "scale": "the copy's scale"},
                  notes="pink lotus in the Bloom's box (1.3 wide, y 0.2 .. 1.1): 6 outer petals opening at 35 deg (#FF508C, "
                        "the inner face lighter #FF8DB4), 5 inner petals more upright (#FF8DB4 / lighter tips), a gold "
                        "#FFC93C centre (4 faces), each petal folded along its midrib (2 faces).")
    c = Vector((0.6, 0.22, -0.5))
    for ring_i, (n, L, W, tilt, a0, cols) in enumerate(((6, 0.62, 0.26, 35, 0.0, (LOTUS, tone(LOTUS, 0.88))),
                                                       (5, 0.55, 0.22, 62, 0.35, (LOTUS_L, tone(LOTUS_L, 0.9))))):
        for i in range(n):
            a = a0 + 2 * math.pi * i / n
            d = Vector((math.cos(a), 0, math.sin(a)))
            side = Vector((-d.z, 0, d.x))
            t = math.radians(tilt)
            up = d * math.cos(t) + Vector((0, math.sin(t), 0))
            b0 = c + d * (0.08 + 0.05 * ring_i) + Vector((0, 0.04 * ring_i, 0))
            mid = b0 + up * (L * 0.5)
            tip = b0 + up * L + Vector((0, 0.06, 0))
            fold = Vector((0, -0.05, 0)) if ring_i == 0 else -d * 0.04
            for sgn, cc in ((1, cols[0]), (-1, cols[1])):
                pts = [b0, mid + side * (W / 2) * sgn + fold, tip]
                lotus.face(pts, cc, "SmoothPlastic", 0.04, up.cross(side) * -1 + Vector((0, 0.3, 0)))
    top = c + Vector((0, 0.32, 0))
    rr = [c + Vector((0.13 * math.cos(k * math.pi / 2), 0.2, 0.13 * math.sin(k * math.pi / 2))) for k in range(4)]
    for k in range(4):
        lotus.face([rr[k], rr[(k + 1) % 4], top], GOLD if k % 2 else tone(GOLD, 0.9), "SmoothPlastic", 0.05,
                   (rr[k] + rr[(k + 1) % 4]) / 2 - c)
    return [pads, lotus]


def bamboo_leaf_spray():
    rng = random.Random(6606)
    pc = Piece("bamboo", "leaf_spray", "the piece's own anchor: (0, 0, 0) = the twig's base on the cane (a node); the "
               "spray reaches out along +X and up, about 3.2 long",
               place={"relativeTo": "Bamboo_Cluster_A / Vine_Hanging_A (the thin bamboo)",
                      "position": "at a cane node: 2-3 per cane top (the leaf clusters, replacing the BambooLeaf parts), 1-2 "
                                  "small side branches lower down",
                      "orientation": "[0, yaw, 0] facing out from the cluster centre (any yaw), tilt +-15 deg",
                      "scale": "tops 0.9-1.2 (cluster), side branches 0.45-0.6; the thin bamboo 0.4-0.6",
                      "collide": "CanCollide off"},
               notes="bamboo leaf spray: a thin twig (#9ACD52 x0.86) rising out along +X, and 6 long lance leaves (2.0 "
                     "x 0.4, folded on the midrib = 2 faces each) fanning down and out from its end and its middle, "
                     "#78D246 / #60C448 / #289642 mixed (the light and dark greens of today's BambooLeaf parts).")
    tw0, tw1 = Vector((0, 0, 0)), Vector((1.3, 0.55, 0))
    pc.face([tw0 + Vector((0, -0.05, 0)), tw0 + Vector((0, 0.05, 0)), tw1 + Vector((0, 0.03, 0)), tw1 + Vector((0, -0.03, 0))],
            tone("#9ACD52", 0.86), "SmoothPlastic", 0.06, Vector((0, 0, -1)))
    leaves = [(tw1, 25, -30, 2.0), (tw1, -15, -40, 1.9), (tw1, 70, -20, 1.7), (tw1, -65, -25, 1.8),
              (tw0.lerp(tw1, 0.55), 45, -50, 1.5), (tw0.lerp(tw1, 0.55), -40, -55, 1.5)]
    cols = [(JMOSS_LL, tone(JMOSS_LL, 0.88)), (JMOSS_L, tone(JMOSS_L, 0.88)), ("#289642", tone("#289642", 0.88))]
    for i, (b, yaw, pitch, L) in enumerate(leaves):
        ya, pa = math.radians(yaw), math.radians(pitch)
        d = Vector((math.cos(pa) * math.cos(ya), math.sin(pa), math.cos(pa) * math.sin(ya)))
        side = d.cross(Vector((0, 1, 0)))
        if side.length < 1e-6:
            side = Vector((0, 0, 1))
        side.normalize()
        up = side.cross(d).normalized()
        W = 0.2 * L / 2.0
        mid = b + d * (L * 0.38) + up * 0.06
        tip = b + d * L - up * 0.12
        c1, c2 = cols[i % 3]
        pc.face([b, mid + side * W, tip], c1, "SmoothPlastic", 0.04, up)
        pc.face([b, tip, mid - side * W], c2, "SmoothPlastic", 0.04, up)
    return pc


BUSH_ORIGIN = "the Bush_Jungle_A kit pivot (y 0 = the ground, front -Z)"


def _ellip_pt(c, size, rot_deg, u, v):
    """Point + normal on an ellipsoid (centre c, full size, yaw rot_deg) at yaw angle u, elevation v (radians)."""
    rx, ry, rz = size[0] / 2, size[1] / 2, size[2] / 2
    lp = Vector((rx * math.cos(v) * math.cos(u), ry * math.sin(v), rz * math.cos(v) * math.sin(u)))
    ln = Vector((lp.x / rx ** 2, lp.y / ry ** 2, lp.z / rz ** 2)).normalized()
    R = euler_matrix([0, rot_deg, 0])
    return R @ lp + Vector(c), (R @ ln).normalized()


def bush_flowers():
    rng = random.Random(6707)
    pc = Piece("bush", "flowers", BUSH_ORIGIN,
               place={"relativeTo": "the Bush_Jungle_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the Flowers MeshPart (#FF508C 6.5 x 2.3 x 6.5 at (-0.4, 4.5, 0.6)); no collision",
                      "scale": "the copy's scale (bakedScale: 0.8 / 1.0 / 1.3)"},
               notes="4 open pink flowers (#FF508C, 5 petals each = 5 flat diamond faces, alternate petals lighter, a gold "
                     "#FFC93C centre) and 2 closed buds (3 faces, #FF508C x0.86) sitting ON today's 2 leaf clumps (big "
                     "8.5 x 5 x 8 at (0, 2.4, 0), small 5.4 x 3.6 x 5.4 at (1.6, 4.4, -1.2)), facing out along the clump "
                     "normal, 0.05 off the leaves; flowers 0.9-1.1 across.")
    clumps = [((0.0, 2.4, 0.0), (8.5 * 0.92, 5.0 * 0.92, 8.0 * 0.92), 47), ((1.6, 4.4, -1.2), (5.4 * 0.92, 3.6 * 0.92, 5.4 * 0.92), 240)]
    spots = [(0, 200, 40, 1.0), (0, 320, 30, 0.9), (1, 30, 50, 0.95), (1, 250, 35, 1.1)]
    for ci, ud, vd, s in spots:
        cc, size, rot = clumps[ci]
        p, n = _ellip_pt(cc, size, rot, math.radians(ud), math.radians(vd))
        a = n.cross(Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(a).normalized()
        ctr = p + n * 0.08
        a0 = rng.uniform(0, 2 * math.pi)
        for k in range(5):
            ang = a0 + 2 * math.pi * k / 5
            d = a * math.cos(ang) + b * math.sin(ang)
            sd = n.cross(d).normalized()
            R0, R1, W = 0.08 * s, 0.5 * s, 0.17 * s
            q = [ctr + d * R0, ctr + d * (R0 + (R1 - R0) * 0.45) + sd * W, ctr + d * R1 + n * 0.05, ctr + d * (R0 + (R1 - R0) * 0.45) - sd * W]
            m = (q[0] + q[2]) / 2
            nn = (q[1] - q[3]).cross(q[2] - q[0])
            if nn.dot(n) < 0:
                nn = -nn
            # make the quad planar: project q[2] onto the plane of q[0], q[1], q[3]
            pn = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
            q[2] = q[2] - pn * (q[2] - q[0]).dot(pn)
            pc.face(q, LOTUS if k % 2 else mix(LOTUS, "#FFFFFF", 0.18), "SmoothPlastic", 0.04, n)
        cen = [ctr + n * 0.04 + (a * math.cos(k * math.pi / 2) + b * math.sin(k * math.pi / 2)) * 0.11 * s for k in range(4)]
        pc.face(cen, GOLD, "SmoothPlastic", 0.04, n)
    for ci, ud, vd in ((0, 110, 45), (1, 140, 45)):
        cc, size, rot = clumps[ci]
        p, n = _ellip_pt(cc, size, rot, math.radians(ud), math.radians(vd))
        a = n.cross(Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(a).normalized()
        tip = p + n * 0.45
        base = [p + (a * math.cos(k * 2 * math.pi / 3) + b * math.sin(k * 2 * math.pi / 3)) * 0.14 for k in range(3)]
        for k in range(3):
            pc.face([base[k], base[(k + 1) % 3], tip], tone(LOTUS, (0.86, 0.95, 0.8)[k]), "SmoothPlastic", 0.05,
                    (base[k] + base[(k + 1) % 3]) / 2 - p + n * 0.1)
    return pc


def bush_base_leaves():
    rng = random.Random(6808)
    pc = Piece("bush", "base_leaves", BUSH_ORIGIN,
               place={"relativeTo": "the Bush_Jungle_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "nothing (added): small leaves at the foot of the bush; no collision", "scale": "the copy's scale"},
               notes="5 small leaves splayed on the ground round the big clump's foot (radius 3.6-4.3), each a flat "
                     "folded leaf (2 faces) 1.2-1.6 long, tilted up 15-25 deg, #289642 / #46AA3C.")
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-d.z, 0, d.x))
        r0 = rng.uniform(3.4, 3.8)
        L = rng.uniform(1.2, 1.6)
        t = math.radians(rng.uniform(15, 25))
        b = d * r0 + Vector((0, 0.15, 0))
        dir_ = d * math.cos(t) + Vector((0, math.sin(t), 0))
        tip = b + dir_ * L
        mid = b + dir_ * (L * 0.4)
        W = 0.28 * L / 1.4
        c1, c2 = ("#289642", tone("#289642", 0.86)) if i % 2 else (JVINE, tone(JVINE, 0.86))
        up = side.cross(dir_).normalized()
        if up.y < 0:
            up = -up
        pc.face([b, mid + side * W + up * 0.04, tip], c1, "SmoothPlastic", 0.04, up)
        pc.face([b, tip, mid - side * W + up * 0.04], c2, "SmoothPlastic", 0.04, up)
    return pc


def bush_clump():
    pc = Piece("bush", "clump", "the piece's own anchor: (0, 0, 0) = the clump's bottom centre; 2.0 wide x 1.3 tall",
               place={"relativeTo": "Bush_Jungle_A (OPTIONAL full-facet bush; see C7: keep today's leaf MeshParts first)",
                      "position": "big clump at (0, -0.1, 0), small at (1.6, 2.6, -1.2), an extra mid clump at (-1.6, 1.8, 1.4)",
                      "orientation": "any yaw", "scale": "big 4.25 (8.5 wide), small 2.7, mid 2.2 (non-uniform Y 0.9-1.1 ok)",
                      "colour": "faces carry #289642 with the height gradient; recolour to #78D246 for the top clump"},
               notes="low faceted leaf clump: hull of 11 jittered dome points + a 6-point flat foot, darker low (x0.82) "
                     "to light top, 3 tone steps; about 20 faces.")
    boulder(pc, (2.0, 1.3, 2.0), 6909, "#289642", n_pts=11, t=0.3, jit=(0.85, 1.08))
    return pc


def jungle_nature():
    return rock_s() + rock_m() + rock_l() + waterfall_pieces() + lily_pieces() + [bamboo_leaf_spray(), bush_flowers(),
                                                                                  bush_base_leaves(), bush_clump()]


def preview_jungle_nature(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    V = Vector
    g1 = [piece_object(by["rock_s__body"], col), piece_object(by["rock_s__moss"], col)]
    o = V((9, 0, 0))
    g1 += [piece_object(by["rock_m__body"], col, o), piece_object(by["rock_m__moss"], col, o)]
    o = V((32, 0, 0))
    g2 = [piece_object(by["rock_l__body"], col, o), piece_object(by["rock_l__moss"], col, o)]
    o = V((70, 0, 0))
    wctx = [((70, 2.3, 2.0), (8.0, 4.6, 8.0), JSTONE_D, (0, 0, 0))]
    g3 = context_boxes(wctx, col) + [piece_object(by[f"waterfall__{n}"], col, o) for n in ("rocks", "water", "basin")]
    o = V((95, 0, 0))
    g4 = [piece_object(by["lily__pads"], col, o), piece_object(by["lily__lotus"], col, o)]
    o = V((110, 0, 0))
    bctx = []
    for x, z, h, c in ((-1.2, -1.1, 17.0, "#91C14D"), (0.4, 1.5, 15.0, "#9ACD52"), (1.6, 0.3, 12.0, "#A2D856"), (-1.4, 0.8, 19.0, "#9ACD52")):
        bctx.append(((110 + x, h / 2 - 0.2, z), (0.9, h, 0.9), c, (0, 0, 0)))
    g5 = context_boxes(bctx, col)
    for (x, y, z, yaw, s) in ((-1.2, 16.6, -1.1, 200, 1.0), (-1.4, 18.6, 0.8, 120, 1.1), (0.4, 14.6, 1.5, 30, 1.0), (1.6, 11.6, 0.3, -40, 0.9),
                              (-1.2, 9.0, -1.1, 160, 0.5), (0.4, 7.0, 1.5, 60, 0.5)):
        g5.append(piece_object(by["bamboo__leaf_spray"], col, o + V((x, y, z)), euler_matrix([0, yaw, 0]), s))
    o = V((130, 0, 0))
    lctx = [((130, 2.4, 0), (8.5 * 0.95, 5.0 * 0.95, 8.0 * 0.95), "#289642", (0, 47, 0)), ((131.6, 4.4, -1.2), (5.4 * 0.95, 3.6 * 0.95, 5.4 * 0.95), "#78D246", (0, 240, 0))]
    g6 = context_boxes(lctx, col)
    for ob in g6:   # round the boxes so they read as clumps
        m = ob.modifiers.new("s", "SUBSURF")
        m.levels = 2
        m.render_levels = 2
    g6 += [piece_object(by["bush__flowers"], col, o), piece_object(by["bush__base_leaves"], col, o)]
    o = V((145, 0, 0))
    g7 = [piece_object(by["bush__clump"], col, o + V((0, -0.1, 0)), None, 4.25), piece_object(by["bush__clump"], col, o + V((1.6, 2.6, -1.2)), euler_matrix([0, 60, 0]), 2.7)]
    out = os.path.join(P.PREVIEW_DIR, "jungle_nature_facets.png")
    return render_sheet("jnature", [(g1, [(-25, 15)]), (g2, [(-25, 15)]), (g3, [(-20, 15)]), (g4, [(-25, 40)]), (g5, [(-20, 6)]),
                                    (g6, [(-25, 25)]), (g7, [(-25, 20)])], None, out)


# ------------------------------------------------------------------------------------------------
# HUB AND PLAINS BATCH 4 (guide section D): torch flame + iron cup re-anchored for Torch_Standing / Torch_Wall, the
# Banner_A cloth (the C6 banner design), the Flag_Pole_A / Hub_Tower flag with folds, the tower's tiled cone roof, the
# guide platform's open book, the mace spike. Everything else of batch 4 is parts.
# ------------------------------------------------------------------------------------------------
B4_RED, B4_BLUE, B4_BLUE_D, B4_GOLD = "#D4343C", "#4078D4", "#2F5CAA", "#FFC93C"


def _moved(src, obj, name, origin, dy, place, notes):
    pc = Piece(obj, name, origin, place=place, notes=notes)
    for f in src.faces:
        pc.faces.append(dict(f, v=[p + Vector((0, dy, 0)) for p in f["v"]]))
    return pc


def b4_flame():
    return _moved(torch_flame(), "b4_torch", "flame",
                  "the piece's own anchor: (0, 0, 0) = the flame's base centre (it rises 1.0 along +Y, 1.0 wide)",
                  -7.85,
                  {"relativeTo": "Torch_Standing / Torch_Wall (kit pivots)",
                   "position": "Torch_Standing: (0, 5.95, 0) (inside today's Ember ball, top of the Head at 6.05); Torch_Wall: "
                               "(0, 3.35, -1.65) (today's Ember centre 3.5 minus 0.15)",
                   "orientation": "[0, 0, 0] (upright, also on the tilted wall torch)", "scale": "standing 0.8, wall 0.7 "
                   "(times the copy's scale)", "keeps": "today's Neon Ember + Attachment FirePoint + PointLight exactly",
                   "collide": "CanCollide off, CastShadow off"},
                  "the C6 jungle torch flame re-anchored: a 5-sided central tongue #FFD678 -> #FFB648 -> #FF8C28 and 3 "
                  "side tongues, all Neon. The fire particles + light of the copy's Decor.VFX.Fire_Torch part stay at the "
                  "FirePoint inside it.")


def b4_cup():
    return _moved(torch_cup(), "b4_torch", "cup",
                  "the piece's own anchor: (0, 0, 0) = the centre of the cup's rim (the cup hangs 1.05 below, 1.88 wide "
                  "across the flats, claws rise 0.26 above)",
                  -8.0,
                  {"relativeTo": "Torch_Wall (kit pivot)", "position": "(0, 3.55, -1.6) (today's Head top)",
                   "orientation": "[0, 0, 0]", "scale": "0.58 (1.1 wide = today's Head)",
                   "replaces": "the wall torch's Head cylinder (keep it invisible as the FirePoint host if the FirePoint must "
                               "not move: FirePoint world position is the contract)"},
                  "the C6 iron fire cup (8-sided, forged band, flat lip, dark coal bed, 4 claws) re-anchored at its rim.")


def b4_banner():
    pc = Piece("b4_banner", "cloth", "the Banner_A kit pivot (base centre of the pole, y 0 = the ground, front -Z)",
               place={"relativeTo": "the Banner_A model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "Cloth (4.6 x 7 x 0.2 at (0, 8.7, -0.55)), the 2 ClothTail wedges (the V point down to y "
                                  "3.2) and Emblem (gold 2 x 2 turned 45 deg at (0, 9.2, -0.7)); all collide today: keep "
                                  "an invisible copy of the Cloth for the collision, or CanCollide off if no player can "
                                  "reach it", "scale": "the copy's own scale (1.0 / 1.5 / 1.9)"},
               notes="the C6 war-banner design in today's Banner_A colours: red #D4343C cloth from y 12.2 (under the "
                     "crossbar) to a zigzag edge of 7 gold-trimmed teeth (centre point at y 3.2 = today's tip), a flat "
                     "centre field and 2 pleats per side, a darker sleeve hem, no stripe; the stitched emblem: a dark red "
                     "patch, today's gold diamond (half-diagonal 1.3) centred at y 9.2 like today, a small red centre, 12 "
                     "cream stitches.")
    banner_cloth_into(pc, top=12.2, tip=3.2, zf=-0.65, stripe=None, emblem_y=9.2, base=B4_RED, centre=tone(B4_RED, 0.86),
                      patch=tone(B4_RED, 0.62), trim=B4_GOLD)
    return pc


def b4_flag():
    pc = Piece("b4_flag", "cloth", "the piece's own anchor: (0, 0, 0) = on the pole axis at the flag's BOTTOM edge; the flag "
               "flies along +X, 7.5 long, 3.6 tall at the pole",
               place={"relativeTo": "Flag_Pole_A / Hub_Tower", "position": "Flag_Pole_A: (0, 12.8, 0) (today's Cloth wedge: "
                      "bottom edge y 12.8, pole side x 0.2, tip x 7.7); Hub_Tower: (0, 57.1, 0)",
                      "orientation": "[0, 0, 0] (both kits fly the flag toward +X)",
                      "scale": "Flag_Pole_A 1.0 (times the copy's scale 1.0 / 1.35 / 2.2); Hub_Tower 0.72 (5.4 x 2.6 like today)",
                      "replaces": "the Cloth wedge (Flag_Pole_A, Hub_Tower); it collided: no player reaches it, CanCollide off"},
               notes="red #D4343C pennant with folds, today's right-triangle shape (vertical edge at the pole 3.6 tall, "
                     "horizontal bottom edge, the top edge falling to the tip): 5 vertical fold panels standing "
                     "alternately 0.22 forward / 0.12 back (lit / shaded tones), a darker hem band along the bottom, a "
                     "gold #FFC93C sleeve round the pole. Static like today (no PropFX: it does not wave).")
    st = [(0.2, 0.0), (1.6, 0.22), (3.1, -0.12), (4.6, 0.2), (6.1, -0.08), (7.7, 0.0)]
    H, L = 3.6, 7.7

    def ytop(x):
        return H * (1 - (x - 0.2) / (L - 0.2))
    for i in range(len(st) - 1):
        (xa, za), (xb, zb) = st[i], st[i + 1]
        n = Vector((-(zb - za), 0, (xb - xa))).normalized() * -1
        if n.z > 0:
            n = -n
        c = B4_RED if i % 2 == 0 else tone(B4_RED, 0.86)
        hem = tone(B4_RED, 0.72)
        yh = 0.28

        def Pp(x, y, xa=xa, xb=xb, za=za, zb=zb):
            return Vector((x, y, za + (x - xa) / (xb - xa) * (zb - za)))
        ya, yb = ytop(xa), ytop(xb)
        x_cut = 0.2 + (1 - yh / H) * (L - 0.2)          # where the top edge meets the hem line
        body = [(xa, yh), (min(xb, x_cut), yh)] + ([(xb, yb)] if yb > yh + 1e-4 else []) + [(xa, ya)]
        hemp = [(xa, 0.0), (xb, 0.0)] + ([(xb, min(yb, yh))] if yb > 1e-4 else []) + ([(x_cut, yh)] if x_cut < xb - 1e-4 else []) + [(xa, yh)]
        for poly, cc in ((body, c), (hemp, hem)):
            pts = [Pp(x, y) for x, y in poly]
            if len(pts) <= 4:
                pc.face(pts, cc, "SmoothPlastic", 0.1, n)
            else:
                polygon_fill(pc, pts, cc, "SmoothPlastic", 0.1, n)
    # gold sleeve round the pole (4 faces of a square tube 0.7 wide)
    for k in range(4):
        a0, a1 = math.pi / 4 + k * math.pi / 2, math.pi / 4 + (k + 1) * math.pi / 2
        p0 = Vector((0.42 * math.cos(a0), 0, 0.42 * math.sin(a0)))
        p1 = Vector((0.42 * math.cos(a1), 0, 0.42 * math.sin(a1)))
        pc.face([p0, p1, p1 + Vector((0, H + 0.1, 0)), p0 + Vector((0, H + 0.1, 0))], tone(B4_GOLD, (1.0, 0.9)[k % 2]),
                "SmoothPlastic", 0.08, (p0 + p1) / 2)
    return pc


def b4_tower_cone():
    rng = random.Random(7104)
    pc = Piece("b4_tower", "cone_roof", "the Hub_Tower kit pivot (base centre, y 0 = the ground, front -Z)",
               place={"relativeTo": "the Hub_Tower model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "replaces": "the RoofCone model (16 Facet wedges, #3D74CD .. #427CDC, y 37.6 .. 53.6, r 10 at the eave); "
                                  "keep its collision as an invisible cone or the union (players cannot reach it)"},
               notes="tiled blue cone roof: 8 rows of individual tiles from the eave (r 9.9 at y 39.3, 0.35 past the "
                     "drum's merlon ring) to the apex (y 53.4, under today's FlagPole foot 53.1): 16 tiles per row in the "
                     "5 lower rows, 8 in the 3 upper ones, each row offset half a tile, 4 % gaps, butts lifted 0.12 "
                     "(they cast a line), 3 tone steps of #4078D4, darker toward the eave; 8 darker #2F5CAA hip ribs; "
                     "a gold #FFC93C collar at the apex; the eave underside closed (#2F5CAA) down to the RoofDrum (r 7.5).")
    R0, Y0, YA = 9.9, 39.3, 53.4
    rows = 8
    s_len = 1.0 / rows

    def at(f, ang, lift=0.0):
        r = R0 * (1 - f)
        y = Y0 + (YA - Y0) * f
        return Vector((math.cos(ang) * (r + lift), y, math.sin(ang) * (r + lift)))
    for i in range(rows):
        n = 16 if i < 5 else 8
        f0 = i * s_len - (0.035 if i else 0.0)       # each row runs a little under the one below (overlap)
        f1 = min((i + 1) * s_len + 0.012, 0.985)
        off = (math.pi / n) * (i % 2)
        for k in range(n):
            a0 = off + 2 * math.pi * k / n + 0.02 * 2 * math.pi / n
            a1 = off + 2 * math.pi * (k + 1) / n - 0.02 * 2 * math.pi / n
            g = 0.86 + 0.14 * (i / (rows - 1))
            col = tone(B4_BLUE, g * rng.choice(STEPS))
            q = [at(f0, a0, 0.12), at(f0, a1, 0.12), at(f1, a1), at(f1, a0)]
            pc.face(q, col, "SmoothPlastic", 0.12, (q[0] + q[1]) / 2 - Vector((0, (q[0].y + q[2].y) / 2 - 2.0, 0)))
    # hip ribs
    for k in range(8):
        a = math.pi / 8 + 2 * math.pi * k / 8
        side = Vector((-math.sin(a), 0, math.cos(a))) * 0.16
        p0, p1 = at(0.0, a, 0.25), at(0.97, a, 0.18)
        pc.face([p0 - side, p0 + side, p1 + side * 0.6, p1 - side * 0.6], B4_BLUE_D, "SmoothPlastic", 0.15, (p0 + p1) / 2 - Vector((0, 46.0, 0)))
    # apex collar (gold, 8 faces) and eave underside (16 faces)
    for k in range(8):
        a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
        q = [Vector((0.55 * math.cos(a0), YA - 0.55, 0.55 * math.sin(a0))), Vector((0.55 * math.cos(a1), YA - 0.55, 0.55 * math.sin(a1))),
             Vector((0.4 * math.cos(a1), YA + 0.15, 0.4 * math.sin(a1))), Vector((0.4 * math.cos(a0), YA + 0.15, 0.4 * math.sin(a0)))]
        pc.face(q, tone(B4_GOLD, (1.0, 0.9)[k % 2]), "SmoothPlastic", 0.12, (q[0] + q[1]) / 2 - Vector((0, YA, 0)))
    for k in range(16):
        a0, a1 = 2 * math.pi * k / 16, 2 * math.pi * (k + 1) / 16
        q = [Vector((R0 * math.cos(a0), Y0, R0 * math.sin(a0))), Vector((R0 * math.cos(a1), Y0, R0 * math.sin(a1))),
             Vector((7.5 * math.cos(a1), Y0 + 0.3, 7.5 * math.sin(a1))), Vector((7.5 * math.cos(a0), Y0 + 0.3, 7.5 * math.sin(a0)))]
        pc.quad_or_tris(q, B4_BLUE_D, "SmoothPlastic", 0.15, Vector((0, -1, 0)))
    return pc


def b4_book():
    pc = Piece("b4_guide", "open_book", "the piece's own anchor: (0, 0, 0) = the middle of the spine on the lectern board; "
               "pages open along +-X (2.9 wide), the page height along Z (1.9), lying flat (+Y up)",
               place={"relativeTo": "Station_TutorialGuide / Hub.TutorialGuide (kit pivot)",
                      "position": "the lectern board centre: kit (-2.6, 4.4, -1.75) (today's 2 Book parts at (-3.3 / -1.9, 4.5, -1.75))",
                      "orientation": "[-15, 0, 0] when the new lectern top is slanted 15 deg toward the reader (front -Z); "
                                     "[0, 0, 0] on a flat top", "scale": 1.0,
                      "replaces": "the 2 Book parts (#F5F6FA / #E8E2D0 1.4 x 0.25 x 1.9; they collide: no need, CanCollide off)"},
               notes="readable open book: a red leather cover #8C2F2A (2 boards + spine) under 2 page blocks that curve up "
                     "from the spine (3 strips per side, #F5F6FA / #E8E2D0, edges #D8CDB0), 4 dark text lines on each page "
                     "(#4A3022), a small gold-framed picture on the right page, a red ribbon bookmark hanging over the "
                     "front edge.")
    W, D = 1.42, 0.95
    cover = "#8C2F2A"
    for sx in (-1, 1):
        pc.face([Vector((0, 0.0, -D - 0.05)), Vector((sx * (W + 0.06), 0.03, -D - 0.05)), Vector((sx * (W + 0.06), 0.03, D + 0.05)),
                 Vector((0, 0.0, D + 0.05))], tone(cover, 0.9), "SmoothPlastic", 0.06, Vector((0, 1, 0)))
    pc.face([Vector((-0.1, -0.05, -D - 0.05)), Vector((0.1, -0.05, -D - 0.05)), Vector((0.1, -0.05, D + 0.05)), Vector((-0.1, -0.05, D + 0.05))],
            cover, "SmoothPlastic", 0.06, Vector((0, -1, 0)))
    prof = [(0.0, 0.1), (0.35, 0.2), (0.95, 0.22), (W, 0.17)]   # (x from the spine, page height)
    for sx in (-1, 1):
        for i in range(3):
            (x0, y0), (x1, y1) = prof[i], prof[i + 1]
            a, b = Vector((sx * x0, y0, -D)), Vector((sx * x1, y1, -D))
            c, d = Vector((sx * x1, y1, D)), Vector((sx * x0, y0, D))
            colp = "#F5F6FA" if sx < 0 else "#EEE8D8"
            pc.face([a, b, c, d], tone(colp, (0.94, 1.0, 0.97)[i]), "SmoothPlastic", 0.05, Vector((0, 1, 0)))
            # front edge of the page block (seen by the reader)
            pc.face([Vector((sx * x0, 0.03, -D)), Vector((sx * x1, 0.03, -D)), b, a], "#D8CDB0", "SmoothPlastic", 0.04, Vector((0, 0, -1)))
        # outer edge
        pc.face([Vector((sx * W, 0.03, -D)), Vector((sx * W, 0.03, D)), Vector((sx * W, prof[-1][1], D)), Vector((sx * W, prof[-1][1], -D))],
                "#D8CDB0", "SmoothPlastic", 0.04, Vector((sx, 0, 0)))
        # 4 text lines on the flattest strip (x 0.35 .. 0.95)
        (x0, y0), (x1, y1) = prof[1], prof[2]
        for j, z in enumerate((-0.6, -0.3, 0.0, 0.3)):
            if sx > 0 and j >= 2:
                continue   # the right page has a picture lower down
            u0, u1 = 0.05, 0.92 if j % 2 == 0 else 0.7
            pa = Vector((sx * (x0 + (x1 - x0) * u0), y0 + (y1 - y0) * u0 + 0.012, z))
            pb = Vector((sx * (x0 + (x1 - x0) * u1), y0 + (y1 - y0) * u1 + 0.012, z))
            pc.face([pa, pb, pb + Vector((0, 0, 0.07)), pa + Vector((0, 0, 0.07))], "#4A3022", "SmoothPlastic", 0.01, Vector((0, 1, 0)))
    # picture on the right page (gold frame + a sky-blue inside), on the flattest strip
    (x0, y0), (x1, y1) = prof[1], prof[2]

    def on(u, z, lift):
        return Vector((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u + lift, z))
    pc.face([on(0.1, 0.05, 0.012), on(0.9, 0.05, 0.012), on(0.9, 0.75, 0.012), on(0.1, 0.75, 0.012)], B4_GOLD, "SmoothPlastic", 0.01, Vector((0, 1, 0)))
    pc.face([on(0.2, 0.15, 0.022), on(0.8, 0.15, 0.022), on(0.8, 0.65, 0.022), on(0.2, 0.65, 0.022)], "#5FD4FF", "SmoothPlastic", 0.01, Vector((0, 1, 0)))
    # ribbon bookmark: lying on the left page from the spine top, hanging over the front edge
    r0 = Vector((-0.12, 0.13, D - 0.1))
    r1 = Vector((-0.3, 0.2, -D))
    side = Vector((0.07, 0, 0))
    pc.face([r1 - side, r1 + side, r0 + side, r0 - side], "#C4403A", "SmoothPlastic", 0.02, Vector((0, 1, 0)))
    pc.face([r1 - side, r1 + side, r1 + side + Vector((0.05, -0.55, -0.08)), r1 - side + Vector((0.05, -0.55, -0.08))], "#A53630",
            "SmoothPlastic", 0.02, Vector((0, 0, -1)))
    return pc


def b4_spike():
    pc = Piece("b4_mace", "spike", "the piece's own anchor: (0, 0, 0) = the CENTRE of today's Spike box (1.1 x 2.4 x 1.0): "
               "the base at y -1.2 (on the head), the tip at y +1.2",
               place={"relativeTo": "Troll_Club (kit pivot)", "position": "each of today's 6 Spike MeshPart CFrames, exactly",
                      "orientation": "the Spike's own rotation", "scale": 1.0,
                      "replaces": "the 6 Spike MeshParts (no collision today)"},
               notes="bevelled iron spike: an 8-sided collar plate (#5C626E, 1.1 x 1.0, 0.22 tall) on the head, then a "
                     "4-sided pyramid with narrow bevelled corner faces (#969CA8 sides, lighter #B4BAC4 bevels), a short "
                     "polished tip (#C8CDD6).")
    def octo(hx, hz, b, y):
        return [Vector((hx, y, -hz + b)), Vector((hx, y, hz - b)), Vector((hx - b, y, hz)), Vector((-hx + b, y, hz)),
                Vector((-hx, y, hz - b)), Vector((-hx, y, -hz + b)), Vector((-hx + b, y, -hz)), Vector((hx - b, y, -hz))]
    r0 = octo(0.55, 0.5, 0.16, -1.2)
    r1 = octo(0.495, 0.45, 0.144, -0.98)
    r2 = octo(0.38, 0.34, 0.1, -0.92)
    r3 = octo(0.38 * 0.34, 0.34 * 0.34, 0.1 * 0.34, 0.75)
    tip = Vector((0.0, 1.2, 0.0))
    for k in range(8):
        j = (k + 1) % 8
        mid = (r0[k] + r0[j]) / 2
        out = Vector((mid.x, 0, mid.z))
        pc.face([r0[k], r0[j], r1[j], r1[k]], tone("#5C626E", (1.0, 0.9)[k % 2]), "SmoothPlastic", 0.1, out)
        pc.quad_or_tris([r1[k], r1[j], r2[j], r2[k]], "#5C626E", "SmoothPlastic", 0.1, out + Vector((0, 1.0, 0)))
        bevel = k % 2 == 1
        pc.face([r2[k], r2[j], r3[j], r3[k]], "#B4BAC4" if bevel else tone("#969CA8", (1.0, 0.9)[(k // 2) % 2]), "SmoothPlastic", 0.12,
                out + Vector((0, 0.3, 0)))
        pc.face([r3[k], r3[j], tip], "#C8CDD6", "SmoothPlastic", 0.06, out + Vector((0, 0.5, 0)))
    return pc


def batch4():
    return [b4_flame(), b4_cup(), b4_banner(), b4_flag(), b4_tower_cone(), b4_book(), b4_spike()]


def preview_batch4(pieces):
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    V = Vector
    # tower top
    tctx = [((0, 35.8, 0), (22.0, 3.6, 22.0), "#A3AAB7", (0, 0, 0)), ((0, 38.6, 0), (15.0, 2.0, 15.0), "#686E7C", (0, 0, 0)),
            ((0, 56.6, 0), (0.5, 7.0, 0.5), "#703E26", (0, 0, 0)), ((0, 60.2, 0), (0.9, 0.9, 0.9), B4_GOLD, (0, 0, 0))]
    for k in range(8):
        a = 2 * math.pi * k / 8
        tctx.append(((9.8 * math.sin(a), 38.6, -9.8 * math.cos(a)), (3.2, 2.0, 2.4), "#969CA8", (0, -math.degrees(a), 0)))
    g1 = context_boxes(tctx, col) + [piece_object(by["b4_tower__cone_roof"], col),
                                     piece_object(by["b4_flag__cloth"], col, V((0, 57.1, 0)), None, 0.72)]
    # flag pole
    fx = 30.0
    g2 = context_boxes([((fx, 8.5, 0), (0.6, 17.0, 0.6), "#703E26", (0, 0, 0)), ((fx, 0.3, 0), (1.6, 0.6, 1.6), "#969CA8", (0, 0, 0)),
                        ((fx, 17.3, 0), (1.0, 1.0, 1.0), B4_GOLD, (0, 0, 0))], col) + [piece_object(by["b4_flag__cloth"], col, V((fx, 12.8, 0)))]
    # banner
    bx = 45.0
    g3 = context_boxes([((bx, 6.5, 0), (0.6, 13.0, 0.6), "#703E26", (0, 0, 0)), ((bx, 12.4, -0.5), (5.6, 0.5, 0.5), "#703E26", (0, 0, 0)),
                        ((bx, 0.3, 0), (1.4, 0.6, 1.4), "#969CA8", (0, 0, 0)), ((bx, 13.2, 0), (0.9, 0.9, 0.9), B4_GOLD, (0, 0, 0))], col)
    g3.append(piece_object(by["b4_banner__cloth"], col, V((bx, 0, 0))))
    # torches
    sx_ = 60.0
    g4 = context_boxes([((sx_, 0.25, 0), (1.8, 0.5, 1.8), "#969CA8", (0, 0, 0)), ((sx_, 2.9, 0), (0.6, 5.2, 0.6), "#703E26", (0, 0, 0)),
                        ((sx_, 5.6, 0), (1.3, 0.9, 1.3), "#5C626E", (0, 0, 0)), ((sx_ + 4, 0.7, -0.15), (0.9, 1.4, 0.3), "#5C626E", (0, 0, 0)),
                        ((sx_ + 4, 1.7, -0.95), (0.5, 3.0, 0.5), "#703E26", (22, 0, 0)), ((sx_ + 4, 2.0, 0.2), (3.0, 4.0, 0.4), "#A3AAB7", (0, 0, 0))], col)
    g4 += [piece_object(by["b4_torch__flame"], col, V((sx_, 5.95, 0)), None, 0.8),
           piece_object(by["b4_torch__cup"], col, V((sx_ + 4, 3.55, -1.6)), None, 0.58),
           piece_object(by["b4_torch__flame"], col, V((sx_ + 4, 3.35, -1.65)), None, 0.7)]
    # lectern + book
    lx = 75.0
    g5 = context_boxes([((lx, 2.3, 0), (1.2, 3.4, 1.2), "#703E26", (0, 0, 0)), ((lx, 4.2, 0), (3.2, 0.4, 2.4), "#A86238", (-15, 0, 0))], col)
    g5.append(piece_object(by["b4_guide__open_book"], col, V((lx, 4.42, 0)), euler_matrix([-15, 0, 0])))
    # mace head with 6 spikes at today's CFrames
    mx = 90.0
    g6 = context_boxes([((mx - 0.5, 3.77, 0), (4.0, 3.2, 3.2), "#A86238", (0, 0, -4)), ((mx + 3.5, 4.07, 0), (5.0, 4.6, 4.6), "#A86238", (0, 0, -4)),
                        ((mx - 6.0, 3.37, 0), (8.0, 1.7, 1.7), "#703E26", (0, 0, -4))], col)
    spikes = [((3.8, 1.24, 0.0), (1.0, -0.07, 0.0, -0.07, -1.0, 0.0, -0.0, -0.0, -1.0)),
              ((2.61, 2.69, 2.38), (1.0, -0.07, 0.0, -0.03, -0.5, -0.87, 0.06, 0.86, -0.5)),
              ((2.61, 2.69, -2.38), (1.0, -0.07, 0.0, -0.03, -0.5, 0.87, -0.06, -0.86, -0.5)),
              ((3.8, 5.49, 2.46), (1.0, -0.07, 0.0, 0.03, 0.5, -0.87, 0.06, 0.86, 0.5)),
              ((3.8, 5.49, -2.46), (1.0, -0.07, 0.0, 0.03, 0.5, 0.87, -0.06, -0.86, 0.5)),
              ((2.61, 6.82, 0.0), (1.0, -0.07, 0.0, 0.07, 1.0, 0.0, 0.0, 0.0, 1.0))]
    from mathutils import Matrix
    for pos, r in spikes:
        R = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
        g6.append(piece_object(by["b4_mace__spike"], col, V((mx + pos[0], pos[1], pos[2])), R))
    out = os.path.join(P.PREVIEW_DIR, "batch4_facets.png")
    return render_sheet("batch4", [(g1, [(-25, 20)]), (g2, [(-20, 8)]), (g3, [(-20, 6)]), (g4, [(-30, 15)]), (g5, [(-10, 40)]),
                                   (g6, [(-30, 15)])], None, out)


# ------------------------------------------------------------------------------------------------
# TUNDRA BUILDINGS AND STRUCTURES (guide section E, owner task 2026-10-22): faceted translucent ice (cave boulders,
# the bridge's layered underside, blocks, shards, icicles), soft snow caps with an irregular edge (roof, bridge, cave
# slab, a reusable cap, a wedge drift) and the cave's stone slab. EVERY piece is made of closed convex shells
# (convex hulls; separate shells share no vertex), so Agent B can turn each shell into a convex solid (~2 tris per
# face). Kit space = the kit pivot (bottom centre at the kit origin, front -Z). Everything else is parts.
# ------------------------------------------------------------------------------------------------
T_SNOW, T_SNOW_S = "#F4F8FF", "#CEDEF6"
T_ICE, T_ICE_DEEP, T_FROST = "#96D6FA", "#54A0E8", "#D6ECFF"
T_ICE_L, T_ICE_M, T_ICE_D, T_NAVY = "#BFE9F5", "#6EC6EA", "#1E7FD6", "#234A8F"
T_ROCK, T_ROCK_D, T_WHITE = "#768096", "#4E566E", "#F2F6F8"
SNOW_WHITE = (T_SNOW, "#E1EBFA", T_SNOW_S)               # top / sides / undersides and lips
SNOW_SHADE = (T_SNOW_S, "#C2D5F0", "#B2C7E8")

# today's part frames (rbxm CFrame rotation, row-major), kit space
M_ID = (1, 0, 0, 0, 1, 0, 0, 0, 1)
M_ROOF_MAIN = (0.8572, -0.515, 0.0, 0.515, 0.8572, 0.0, 0.0, 0.0, 1.0)     # cabin -X slope (+31 deg)
M_ROOF_SMALL = (0.8572, 0.515, 0.0, -0.515, 0.8572, 0.0, 0.0, 0.0, 1.0)    # cabin +X slope (-31 deg)
M_SPAN_R = (0.9744, 0.225, 0.0, -0.225, 0.9744, 0.0, 0.0, 0.0, 1.0)        # bridge right span (-13 deg)
M_ROCK_L = (0.8208, 0.0863, 0.5646, -0.1045, 0.9945, 0.0, -0.5615, -0.059, 0.8253)
M_ROCK_R = (-0.7334, 0.0771, 0.6755, 0.1045, 0.9945, 0.0, -0.6718, 0.0706, -0.7374)


def _mat3(m):
    from mathutils import Matrix
    return Matrix(((m[0], m[1], m[2]), (m[3], m[4], m[5]), (m[6], m[7], m[8])))


def _xf(pos, m):
    """local -> kit space through a part CFrame (pos, row-major rotation)."""
    R, p = _mat3(m), Vector(pos)
    return lambda v: p + R @ Vector(v)


def _clean_ring(ring, eps=1e-4):
    """Drops repeated and collinear corners of a planar polygon ring."""
    out = list(ring)
    changed = True
    while changed and len(out) > 3:
        changed = False
        for i in range(len(out)):
            a, b, c = out[i - 1], out[i], out[(i + 1) % len(out)]
            if (b - a).length < eps or (b - a).cross(c - b).length < eps * max((b - a).length * (c - b).length, 1e-9):
                out.pop(i)
                changed = True
                break
    return out


def _hull_faces(pts):
    """Convex hull of pts -> [(ring, outward normal)], exactly coplanar triangles merged into planar polygons."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=1e-3, verts=list(bm.verts), edges=list(bm.edges), delimit=set())
    bm.normal_update()
    cen = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    out = []
    for f in bm.faces:
        ring = _clean_ring([l.vert.co.copy() for l in f.loops])
        n = newell(ring).normalized()
        if n.dot(sum(ring, Vector()) / len(ring) - cen) < 0:
            ring.reverse()
            n = -n
        out.append((ring, n))
    bm.free()
    return out


def _emit(pc, ring, n, col, m, t):
    if len(ring) == 3:
        pc.face(ring, col, m, t, n)
    elif len(ring) == 4:
        pc.quad_or_tris(ring, col, m, t, n)
    else:
        polygon_fill(pc, ring, col, m, t, n)


def shell(pc, pts, colfn, m="SmoothPlastic", t=0.3, mfn=None):
    """One closed convex shell (the hull of pts); colfn(centroid, normal) -> colour."""
    for ring, n in _hull_faces(pts):
        cc = sum(ring, Vector()) / len(ring)
        _emit(pc, ring, n, colfn(cc, n), mfn(cc, n) if mfn else m, t)


def bevel_shell(pc, pts, d, body, edge, m="SmoothPlastic", m_edge=None, t=0.3):
    """Hull of pts with every edge chamfered by about d: each hull face is inset by d in its own plane (parallel
    edges, so the chamfers are planar quads), then the hull of the inset corners. The big faces keep body(cc, n), the
    narrow chamfer / corner faces take edge(cc, n): the light crystal edges."""
    base = _hull_faces(pts)
    new, normals = [], []
    for ring, n in base:
        k = len(ring)
        dd = min(d, 0.22 * min((ring[(i + 1) % k] - ring[i]).length for i in range(k)))
        cen = sum(ring, Vector()) / k
        normals.append(n)
        for i in range(k):
            a, b, c = ring[i - 1], ring[i], ring[(i + 1) % k]
            i0, i1 = n.cross((b - a).normalized()), n.cross((c - b).normalized())
            mv = (i0 + i1) / max(1.0 + i0.dot(i1), 1e-3) * dd
            lim = 0.4 * (cen - b).length
            if mv.length > lim:
                mv = mv.normalized() * lim
            new.append(b + mv)
    for ring, n in _hull_faces(new):
        cc = sum(ring, Vector()) / len(ring)
        flat = any(n.dot(bn) > 0.99995 for bn in normals)
        _emit(pc, ring, n, body(cc, n) if flat else edge(cc, n), m if flat else (m_edge or m), t)


def shell_count(pc):
    """Connected shells (faces sharing a corner, 0.001 stud) of a piece."""
    par = list(range(len(pc.faces)))

    def f(i):
        while par[i] != i:
            par[i] = par[par[i]]
            i = par[i]
        return i
    owner = {}
    for i, fc in enumerate(pc.faces):
        for p in fc["v"]:
            k = tuple(round(c, 3) for c in p)
            if k in owner:
                par[f(i)] = f(owner[k])
            else:
                owner[k] = i
    return len({f(i) for i in range(len(pc.faces))})


def snow_colfn(scheme):
    top, side, under = scheme

    def f(cc, n):
        if n.y > 0.72:
            return top
        if n.y > 0.3:
            return mix(top, side, 0.5)
        if n.y > -0.3:
            return side
        return under
    return f


def ice_colfn(base, lo_y, hi_y, rng, light=T_ICE_L):
    """Ice faces: deeper at the bottom (x0.88), lighter / whiter toward the top, up-facing facets lighter, 2 steps."""
    def f(cc, n):
        h = max(0.0, min(1.0, (cc.y - lo_y) / max(hi_y - lo_y, 1e-6)))
        c = mix(tone(base, 0.88 + 0.12 * h), light, 0.16 * h + (0.14 if n.y > 0.55 else 0.0))
        return tone(c, rng.choice((1.0, 0.95)))
    return f


def superellipse(n_pts, rx, rz, p, rng, jr=0.0, phase=0.0, cx=0.0, cz=0.0):
    out = []
    for k in range(n_pts):
        a = phase + 2 * math.pi * (k + rng.uniform(-0.12, 0.12)) / n_pts
        c, s = math.cos(a), math.sin(a)
        r = (abs(c) ** p + abs(s) ** p) ** (-1.0 / p)
        j = 1.0 + rng.uniform(-jr, jr)
        out.append((cx + rx * c * r * j, cz + rz * s * r * j))
    return out


def lump_pts(c, hx, hy, hz, rng, n=10, drop=0.0):
    """Jittered points on a small ellipsoid (a snow drip / lump); drop: one point hanging below (a drip tip)."""
    pts = []
    for i in range(n):
        yy = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(max(0.0, 1 - yy * yy))
        a = i * 2.39996 + rng.uniform(-0.3, 0.3)
        pts.append(Vector((c[0] + math.cos(a) * rr * hx * rng.uniform(0.85, 1.05), c[1] + yy * hy * rng.uniform(0.9, 1.05),
                           c[2] + math.sin(a) * rr * hz * rng.uniform(0.85, 1.05))))
    if drop:
        pts.append(Vector((c[0] + rng.uniform(-0.2, 0.2) * hx, c[1] - hy - drop, c[2])))
    return pts


def slab_snow_into(pc, xf, hx, hz, top, sides, rng, scheme, n=22, r=0.3):
    """Soft thick snow layer on a box top (local frame of the box, top plane at local y = top, xf -> kit space): the
    TOP is exactly flat at `top` (it is the walk surface of the kept collider), a bulging rounded rim, a lip that drops
    over the edges; sides = {"-x" | "+x" | "-z" | "+z": (overhang, drop, drips)}. Drip lumps hang over the lips.
    Returns suggested icicle roots (kit space) under the lips with drips."""
    def side_w(x, z):
        wx, wz = (abs(x) / hx) ** 6, (abs(z) / hz) ** 6
        sx = sides["+x" if x > 0 else "-x"]
        sz = sides["+z" if z > 0 else "-z"]
        s = wx + wz + 1e-9
        return wx / s, wz / s, sx, sz

    tp, rim, lip = [], [], []
    for (x, z) in superellipse(n, hx - r, hz - r, 8, rng, 0.0, 0.07):
        tp.append(Vector((x, top, z)))
    for (x, z) in superellipse(n, hx, hz, 8, rng, 0.0, 0.0):
        wx, wz, sx, sz = side_w(x, z)
        ov = wx * sx[0] + wz * sz[0]
        dr = wx * sx[1] + wz * sz[1]
        ox = math.copysign(sx[0], x) * wx
        oz = math.copysign(sz[0], z) * wz
        j = rng.uniform(-0.05, 0.05)
        rim.append(Vector((x + ox * 0.85 + j * (x / hx), top - 0.38 * dr - rng.uniform(0.0, 0.05), z + oz * 0.85 + j * (z / hz))))
        lip.append(Vector((x * 0.985 + ox * 0.55, top - dr + rng.uniform(-0.06, 0.06), z * 0.985 + oz * 0.55)))
        _ = ov
    shell(pc, [xf(p) for p in tp + rim + lip], snow_colfn(scheme), t=0.3)
    roots = []
    for key, (ov, dr, drips) in sides.items():
        if drips <= 0:
            continue
        along_x = key[1] == "z"
        L = hx if along_x else hz
        sgn = 1.0 if key[0] == "+" else -1.0
        for k in range(drips):
            u = -L * 0.8 + (2 * L * 0.8) * (k + 0.5 + rng.uniform(-0.25, 0.25)) / drips
            e = (hz if along_x else hx) + ov * 0.6
            c = (u, top - dr + 0.08, sgn * e) if along_x else (sgn * e, top - dr + 0.08, u)
            ha = rng.uniform(0.45, 0.75)
            hy = rng.uniform(0.28, 0.38)
            pts = lump_pts(c, ha if along_x else 0.26, hy, 0.26 if along_x else ha, rng, n=10, drop=rng.uniform(0.12, 0.25))
            shell(pc, [xf(p) for p in pts], snow_colfn(scheme), t=0.3)
            if k < drips - 1:
                u2 = u + L * 0.8 / drips
                rt = (u2, top - dr + 0.1, sgn * (e - 0.35)) if along_x else (sgn * (e - 0.35), top - dr + 0.1, u2)
                roots.append([round(c_, 2) for c_ in xf(rt)])
    return roots


def cap_into(pc, rng, scheme, drips=0):
    """Reusable soft snow cap, normalized: footprint 1 x 1 (x, z -0.5..0.5, 4 % overhang), bottom y 0, top y 1.0."""
    pts = [Vector((x, 0.0, z)) for (x, z) in superellipse(12, 0.52, 0.52, 4, rng, 0.02)]
    pts += [Vector((x, 0.32 + rng.uniform(-0.04, 0.04), z)) for (x, z) in superellipse(12, 0.565, 0.565, 3.5, rng, 0.035, math.pi / 12)]
    pts += [Vector((x, 0.76 + rng.uniform(-0.04, 0.04), z)) for (x, z) in superellipse(10, 0.42, 0.42, 3, rng, 0.05)]
    pts += [Vector((rng.uniform(-0.12, 0.12), 1.0 - rng.uniform(0.0, 0.04), rng.uniform(-0.12, 0.12))) for _ in range(3)]
    shell(pc, pts, snow_colfn(scheme))
    for k in range(drips):
        x = -0.3 + 0.62 * k / max(drips - 1, 1) + rng.uniform(-0.04, 0.04)
        shell(pc, lump_pts((x, 0.14, -0.55), rng.uniform(0.09, 0.13), 0.2, 0.07, rng, n=9, drop=0.12), snow_colfn(scheme))


def drift_into(pc, rng, scheme):
    """Snow drift in a unit WedgePart box (x, z -0.5..0.5, y 0..1, high side +Z, low toe at -Z): a soft bulging
    slope (above the wedge's straight slope), rounded ends that sink to 0.15 of the height, a vertical back."""
    pts = []
    for k in range(9):
        x = -0.5 + k / 8
        hf = 0.15 + 0.85 * math.sqrt(max(0.0, 1 - abs(2 * x) ** 2.5))
        for (z, y) in ((0.5, 0.97), (0.28, 0.92), (0.0, 0.68), (-0.27, 0.36), (-0.44, 0.1)):
            pts.append(Vector((x * (0.98 if abs(x) > 0.45 else 1.0), (y + rng.uniform(-0.03, 0.03)) * hf,
                               z + rng.uniform(-0.02, 0.02))))
        pts += [Vector((x, 0.0, -0.5)), Vector((x, 0.0, 0.5))]
    shell(pc, pts, snow_colfn(scheme))


def icicle_pts(c, L, r, rng, sides=6):
    """A tapering icicle hanging from c (root centre): root ring, a slight swelling, a narrower ring, the tip."""
    ph = rng.uniform(0, math.pi)
    lean = (rng.uniform(-0.06, 0.06) * L, rng.uniform(-0.06, 0.06) * L)
    pts = []
    for (f, k) in ((0.0, 1.0), (0.15, 1.08), (0.5, 0.68)):
        for i in range(sides):
            a = ph + 2 * math.pi * i / sides
            pts.append(Vector((c[0] + lean[0] * f + r * k * math.cos(a), c[1] - f * L, c[2] + lean[1] * f + r * k * math.sin(a))))
    pts.append(Vector((c[0] + lean[0], c[1] - L, c[2] + lean[1])))
    return pts


def icicle_colfn(top_y, L, rng):
    def f(cc, n):
        if n.y > 0.8:
            return T_FROST
        if cc.y < top_y - 0.62 * L:
            return mix(T_ICE_L, T_WHITE, 0.45)
        return T_FROST if int((math.atan2(n.z, n.x) + math.pi) / (math.pi / 3)) % 2 == 0 else T_ICE_L
    return f


def shard_pts(base, h, r, tilt, yaw, rng, sides=5):
    """A crystal shard: a 5-sided prism from 0.3 below the ground, leaning `tilt` deg toward `yaw`, pointed tip."""
    ax = Vector((math.sin(math.radians(tilt)) * math.cos(math.radians(yaw)), math.cos(math.radians(tilt)),
                 math.sin(math.radians(tilt)) * math.sin(math.radians(yaw))))
    u = ax.cross(Vector((0, 0, 1)))
    if u.length < 1e-4:
        u = ax.cross(Vector((1, 0, 0)))
    u.normalize()
    v = ax.cross(u).normalized()
    ph = rng.uniform(0, math.pi)
    b = Vector(base)
    pts = []
    for (f, k) in ((-0.3 / h, 1.0), (0.62, 0.92)):
        for i in range(sides):
            a = ph + 2 * math.pi * i / sides + (0.15 if f > 0 else 0.0)
            pts.append(b + ax * (f * h) + (u * math.cos(a) + v * math.sin(a)) * r * k)
    pts.append(b + ax * h + u * rng.uniform(-0.05, 0.05) * r)
    return pts, b, ax, h


def boulder_local(rng, rings=((-0.93, 5, 0.8), (-0.4, 6, 1.0), (0.28, 6, 0.97), (0.78, 4, 0.64)), top=0.99):
    pts = []
    ph = 0.0
    for (y, k, r) in rings:
        ph += rng.uniform(0.3, 0.9)
        for i in range(k):
            a = ph + 2 * math.pi * (i + rng.uniform(-0.2, 0.2)) / k
            j = rng.uniform(0.9, 1.04)
            pts.append(Vector((math.cos(a) * r * j, y + rng.uniform(-0.06, 0.06), math.sin(a) * r * j)))
    pts.append(Vector((rng.uniform(-0.15, 0.15), top, rng.uniform(-0.15, 0.15))))
    return pts


def _rect8(hx, hz, ch, y, rng=None, jy=0.0, jr=0.0):
    """Rectangle with chamfered corners (8 points) at height y."""
    pts = [(hx, -hz + ch), (hx, hz - ch), (hx - ch, hz), (-hx + ch, hz), (-hx, hz - ch), (-hx, -hz + ch), (-hx + ch, -hz), (hx - ch, -hz)]
    out = []
    for (x, z) in pts:
        jx = 1 + (rng.uniform(-jr, jr) if rng else 0.0)
        out.append(Vector((x * jx, y + (rng.uniform(-jy, jy) if rng else 0.0), z * jx)))
    return out


# --- shared pieces --------------------------------------------------------------------------------------------
def t_snow_caps():
    out = []
    for name, scheme, drips, seed, col in (("cap", SNOW_WHITE, 0, 8101, "#F4F8FF"), ("cap_shade", SNOW_SHADE, 0, 8102, "#CEDEF6"),
                                           ("cap_drip", SNOW_WHITE, 3, 8103, "#F4F8FF")):
        rng = random.Random(seed)
        pc = Piece("tundra_snow", name, "the piece's own anchor: (0, 0, 0) = the bottom centre; NORMALIZED: footprint 1 x 1 "
                   "(x, z -0.5..0.5, the rim bulges 4-7 % past it), height 1",
                   place={"relativeTo": "the part it caps", "position": "the centre of that part's top face",
                          "orientation": "the part's rotation", "scale": "NON-UNIFORM (width, thickness, depth): chimney "
                          "(3.9, 0.8, 3.9) at kit (-5.5, 17.0, 5); post tops (1.1, 0.45, 1.1); scaffold deck patches (4, 0.45, 3) "
                          "/ (8.6, 0.5, 4.6); ice blocks (1.5, 0.35, 1.3)",
                          "replaces": "ChimneySnow (keep it invisible: it collides) and the flat scaffold Snow slabs (no collision)",
                          "collide": "CanCollide off, CanQuery off, CastShadow on"},
                   notes=f"soft thick snow cap, a closed convex shell: flat-ish domed top {col}, a rim that bulges out past the "
                         "footprint (irregular 12-sided outline, jittered heights), sides / undersides one and two steps darker "
                         "(snow -> shaded snow)" + (", 3 drip lumps hanging over the -Z edge (separate shells)" if drips else "")
                         + ". Use cap_shade on the #CEDEF6 objects.")
        cap_into(pc, rng, scheme, drips)
        out.append(pc)
    return out


def t_snow_drifts():
    out = []
    for name, scheme, seed in (("drift", SNOW_WHITE, 8111), ("drift_shade", SNOW_SHADE, 8112)):
        pc = Piece("tundra_snow", name, "NORMALIZED to a WedgePart box: x, z -0.5..0.5, y 0..1 (bottom centre at y 0), the high "
                   "side at +Z (against the wall), the toe at -Z, exactly like a Roblox WedgePart",
                   place={"relativeTo": "Cabin_Broken (kit pivot)",
                          "position": "each Drift wedge's CFrame moved down by half its height (the wedge's bottom centre): "
                                      "(-6.5, 0, -10.5) / (0, 0, 10.5) / (-13, 0, 0)",
                          "orientation": "the wedge's rotation: [0, 0, 0] / [0, 180, 0] / [0, 90, 0]",
                          "scale": "NON-UNIFORM = the wedge size: (9, 3.5, 5) / (20, 4, 5) / (14, 4.5, 6); extra drifts "
                                   "in the broken part about (5, 1.6, 3) and (6, 2, 3) (no collider)",
                          "replaces": "the look of the 3 Drift wedges (keep them invisible: they collide); drift_shade on the "
                                      "#CEDEF6 one (-13, 2.25, 0)", "collide": "CanCollide off"},
                   notes="snow drift: a soft convex mound bulging above the wedge slope, ends rounding down to 15 % of the "
                         "height, irregular facets; snow on top, darker toward the toe and the ends. One closed convex shell.")
        drift_into(pc, random.Random(seed), scheme)
        out.append(pc)
    return out


def t_icicles():
    rng = random.Random(8121)
    one = Piece("tundra_ice", "icicle", "the piece's own anchor: (0, 0, 0) = the centre of the root (top); it hangs 3.0 down "
                "along -Y, 0.9 across at the root",
                place={"relativeTo": "the underside it hangs from", "position": "today's Icicle root: cave (0.4, 11.2, -0.6), "
                       "(-3.2, 11.2, -0.6), (3.4, 11.2, -0.6) (roots now at the slab underside); bridge: root at the span bottom "
                       "above today's 5 Icicles (x -9 / -4 / 1 / 6 / 11, z -3 / 2.5 / -3 / 2.5 / -3); cabin / bridge snow "
                       "lips: the `icicleRoots` listed in their snow pieces",
                       "orientation": "[0, any yaw, 0]", "scale": "uniform 0.5-1.6, or Y = today's length / 3 (cave 4.2 / "
                       "3.0 / 2.6, bridge 5.0 / 4.6 / 3.4 / 3.0 / 2.6)",
                       "replaces": "each Icicle MeshPart (spike mesh 100106311518324; no collision)",
                       "collide": "CanCollide off, CanQuery off, CastShadow off (as today)"},
                notes="small tapering 6-sided icicle: root ring, a slight swelling, a narrower ring, a leaning tip. Facets "
                      "alternate #D6ECFF / #BFE9F5, the tip part #D6EFF6; Glass, Transparency 0.25. One closed convex shell.")
    shell(one, icicle_pts((0, 0, 0), 3.0, 0.45, rng), icicle_colfn(0.0, 3.0, rng), m="Glass")
    cl = Piece("tundra_ice", "icicle_cluster", "the piece's own anchor: (0, 0, 0) = the middle of the frozen root bar (top); "
               "4 icicles in a row along X (x -0.85..1.1), 3.0 / 2.1 / 1.5 / 0.9 long",
               place={"relativeTo": "the underside it hangs from", "position": "eaves and lips: between the drips of the "
                      "snow pieces (their `icicleRoots`), the cave slab front (y 10.35, z -3.2) x2, the bridge span edges",
                      "orientation": "[0, yaw along the edge, 0]", "scale": "uniform 0.5-1.2",
                      "replaces": "nothing (added)", "collide": "CanCollide off, CanQuery off, CastShadow off"},
               notes="cluster of 4 tapering icicles under a small frozen root lump (5 closed convex shells); Glass "
                     "Transparency 0.25, the colours of tundra_ice__icicle.")
    for (x, z, L, r) in ((-0.85, 0.05, 3.0, 0.42), (-0.15, -0.08, 2.1, 0.34), (0.5, 0.06, 1.5, 0.28), (1.1, -0.04, 0.9, 0.22)):
        shell(cl, icicle_pts((x, -0.05, z), L, r, rng), icicle_colfn(-0.05, L, rng), m="Glass")
    shell(cl, lump_pts((0.12, 0.0, 0.0), 1.25, 0.16, 0.36, rng, n=12), lambda cc, n: T_FROST if n.y > 0.3 else T_ICE_L, m="Glass")
    return [one, cl]


def t_ice_block():
    rng = random.Random(8131)
    pc = Piece("tundra_ice", "block", "the piece's own anchor: (0, 0, 0) = the bottom centre; 1.6 x 1.2 x 1.4",
               place={"relativeTo": "Wooden_Scaffold (kit pivot)", "position": "on the deck (top y 10.8): (4.6, 10.8, 1.6) yaw 18, "
                      "(5.9, 10.8, 2.6) yaw -25 scale 0.7, (-6.2, 10.8, -1.9) yaw 40 scale 0.85; at the cave foot "
                      "(-12.4, 0, -3.0), (11.6, 0, -3.4) scale 1.2", "orientation": "[0, yaw, 0]",
                      "scale": "uniform 0.6-1.3", "replaces": "nothing (added)", "collide": "CanCollide off"},
               notes="small ice block: a jittered box with every edge chamfered (light #BFE9F5 edges), #96D6FA body facets "
                     "lighter on top; Glass, Transparency 0.3 (edges 0.2). One closed convex shell; a cap (tundra_snow__cap, "
                     "scale (1.5, 0.35, 1.3)) may sit on top.")
    pts = []
    for (x, y, z) in ((-0.8, 0, -0.7), (0.8, 0, -0.7), (0.8, 0, 0.7), (-0.8, 0, 0.7), (-0.78, 1.2, -0.68), (0.8, 1.15, -0.7),
                      (0.76, 1.2, 0.68), (-0.8, 1.13, 0.7)):
        pts.append(Vector((x + rng.uniform(-0.05, 0.05), y + (rng.uniform(-0.04, 0.04) if y else 0.0), z + rng.uniform(-0.05, 0.05))))
    bevel_shell(pc, pts, 0.13, ice_colfn(T_ICE, 0.0, 1.2, rng), lambda cc, n: T_ICE_L, m="Glass")
    return [pc]


def t_ice_shards():
    rng = random.Random(8141)
    pc = Piece("tundra_ice", "shards", "the piece's own anchor: (0, 0, 0) = the centre of the cluster on the ground; 5 shards "
               "within about 2.4 x 2.2 tall, the tallest leaning back (+Z)",
               place={"relativeTo": "Ice_Cave_Mouth (kit pivot)", "position": "the cave foot: (-4.9, 0, -5.2) yaw 20, "
                      "(5.3, 0, -5.4) yaw -35 scale 0.8, (-11.8, 0, -2.6) scale 0.7, (12.3, 0, -1.8) yaw 150 scale 0.6",
                      "orientation": "[0, yaw, 0]", "scale": "uniform 0.5-1.0 (times the copy's scale)",
                      "replaces": "nothing (added)", "collide": "CanCollide off"},
               notes="small ice shards: 5 leaning 5-sided crystals (closed convex shells) in #96D6FA / #6EC6EA / #54A0E8, "
                     "facets alternate lighter, the tip faces #BFE9F5; Glass, Transparency 0.3. Each shard sinks 0.3 into "
                     "the ground.")
    for (bx, bz, h, r, tilt, yaw, col) in ((0.0, 0.35, 2.2, 0.36, 10, 90, T_ICE), (-0.75, -0.1, 1.55, 0.3, 24, 200, T_ICE_M),
                                           (0.7, -0.2, 1.3, 0.27, 22, -20, T_ICE_DEEP), (0.15, -0.75, 0.95, 0.24, 30, -95, T_ICE),
                                           (-0.35, 0.95, 0.7, 0.2, 35, 130, T_ICE_M)):
        pts, b, ax, hh = shard_pts((bx, 0.0, bz), h, r, tilt, yaw, rng)

        def colf(cc, n, b=b, ax=ax, hh=hh, col=col):
            if (cc - b).dot(ax) > 0.66 * hh:
                return T_ICE_L
            return col if int((math.atan2(n.z, n.x) + math.pi) / (math.pi / 2.5)) % 2 == 0 else mix(col, T_ICE_L, 0.3)
        shell(pc, pts, colf, m="Glass")
    return [pc]


# --- 02 ice cave ----------------------------------------------------------------------------------------------
def t_cave_boulders():
    out = []
    for side, pos, size, m, base, light, core, seed in (
            ("left", (-8.0, 7.2, 0.0), (8.0, 15.0, 9.0), M_ROCK_L, T_ICE_DEEP, T_ICE_L, T_NAVY, 8201),
            ("right", (8.0, 6.7, 0.0), (8.0, 14.0, 9.0), M_ROCK_R, T_ICE, mix(T_ICE_L, T_WHITE, 0.4), T_ICE_D, 8202)):
        rng = random.Random(seed)
        xf = _xf(pos, m)
        half = Vector(size) * 0.5

        def kit(v, k=0.95):
            q = xf(Vector((v.x * half.x * k, v.y * half.y * k, v.z * half.z * k)))
            return Vector((q.x, max(q.y, -0.3), q.z))
        pc = Piece("tundra_cave", f"ice_{side}", "the Ice_Cave_Mouth kit pivot (bottom centre, front -Z = the opening side)",
                   place={"relativeTo": "the Ice_Cave_Mouth model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                          "scale": "the copy's Model scale (1.0; the arena copy 1.25)",
                          "replaces": f"the look of the {side} IceRock MeshPart ({size[0]:g} x {size[1]:g} x {size[2]:g} at "
                                      f"{pos}, {base}); keep it as the invisible collider (Transparency 1)",
                          "collide": "CanCollide off on the piece"},
                   notes=f"faceted translucent ice boulder fitted to 95 % of today's IceRock box, flat bottom at y -0.3: an "
                         f"OUTER shell of big facets in {base} (deeper x0.88 at the bottom, lighter toward the top, up-facing "
                         f"facets lighter) with every edge chamfered in light {light} (the 'light edges'), Glass Transparency "
                         f"0.3 (edges 0.2); an opaque INNER core shell ({core}, SmoothPlastic, 62 % size, set low) that shows "
                         "through the glass as the inner colour gradient. 2 closed convex shells.")
        pts = [kit(v) for v in boulder_local(rng)]
        low = min(p.y for p in pts)
        pts += [Vector((p.x, -0.3, p.z)) for p in pts if p.y < low + 1.2]     # the foot sits 0.3 into the ground
        lo = min(p.y for p in pts)
        hi = max(p.y for p in pts)
        bevel_shell(pc, pts, 0.16, ice_colfn(base, lo, hi, rng), lambda cc, n, light=light: light, m="Glass")
        cpts = [kit(Vector((v.x * 0.62, v.y * 0.66 - 0.1, v.z * 0.62))) for v in
                boulder_local(rng, rings=((-0.9, 4, 0.8), (-0.2, 5, 1.0), (0.6, 4, 0.75)), top=0.95)]
        shell(pc, cpts, lambda cc, n, core=core: mix(core, base, 0.25) if n.y > 0.5 else core)
        out.append(pc)
    return out


def t_cave_slab():
    rng = random.Random(8211)
    pc = Piece("tundra_cave", "slab", "the Ice_Cave_Mouth kit pivot (bottom centre, front -Z)",
               place={"relativeTo": "the Ice_Cave_Mouth model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale",
                      "replaces": "the look of the top IceRock MeshPart (the slab, 23 x 6 x 10 #768096 at (0, 13.4, 0.5)); keep "
                                  "it as the invisible collider", "collide": "CanCollide off on the piece"},
               notes="thick slate rock slab in 2 strata: a lower darker layer #4E566E (y 10.3..12.7, its underside = the "
                     "opening's top, today 10.4) and the main layer #768096 (y 12.4..15.3) that overhangs 0.6-0.9 at the "
                     "front, its sloped top band in a lighter slate #8891A4 (the chamfer); 3 tone steps, darker low. 2 "
                     "closed convex shells.")
    lo = [Vector((x, 10.3, z)) for (x, z) in superellipse(10, 10.3, 4.3, 4, rng, 0.03, 0.2, 0.0, 0.6)]
    lo += [Vector((x, 12.7 + rng.uniform(-0.1, 0.1), z)) for (x, z) in superellipse(10, 10.9, 4.7, 4, rng, 0.03, 0.5, 0.0, 0.5)]
    shell(pc, lo, lambda cc, n: tone(T_ROCK_D, (0.92 if n.y < -0.5 else 1.0) * rng.choice(STEPS)))
    up = [Vector((x, 12.4, z)) for (x, z) in superellipse(9, 10.8, 4.6, 4, rng, 0.03, 0.1, 0.0, 0.5)]
    up += [Vector((x, 13.6 + rng.uniform(-0.15, 0.15), z)) for (x, z) in superellipse(10, 11.5, 5.1, 4, rng, 0.03, 0.4, 0.0, 0.35)]
    up += [Vector((x, 14.55 + rng.uniform(-0.1, 0.1), z)) for (x, z) in superellipse(10, 11.1, 4.75, 4, rng, 0.03, 0.05, 0.0, 0.4)]
    up += [Vector((x, 15.2 + rng.uniform(-0.08, 0.08), z)) for (x, z) in superellipse(8, 9.8, 3.9, 3.5, rng, 0.04, 0.25, 0.0, 0.5)]

    def upcol(cc, n):
        if 0.3 < n.y < 0.85:     # the sloped band round the top = the lighter chamfer
            return mix(T_ROCK, "#FFFFFF", 0.13)
        return tone(T_ROCK, (0.86 + 0.14 * max(0.0, min(1.0, (cc.y - 12.4) / 3.0))) * rng.choice(STEPS))
    shell(pc, up, upcol)
    return [pc]


def t_cave_slab_snow():
    rng = random.Random(8221)
    pc = Piece("tundra_cave", "slab_snow", "the Ice_Cave_Mouth kit pivot (bottom centre, front -Z)",
               place={"relativeTo": "the Ice_Cave_Mouth model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale",
                      "replaces": "the Snow MeshPart (20.7 x 6 x 9 at (0, 14.5, 0.5), no collision)", "collide": "CanCollide off"},
               notes="soft thick snow cap on tundra_cave__slab: a domed pillow (top y 17.3, today's snow top 17.5) whose "
                     "rim bulges 0.4-0.6 past the slab's top edge, irregular 14-sided outline; 5 drip lumps over the front "
                     "edge and 2 on each end (separate shells). Snow #F4F8FF on top -> #E1EBFA sides -> #CEDEF6 undersides. "
                     "10 closed convex shells.")
    pts = [Vector((x, 14.7, z)) for (x, z) in superellipse(14, 10.2, 4.0, 4, rng, 0.02, 0.1, 0.0, 0.45)]
    pts += [Vector((x, 15.55 + rng.uniform(-0.08, 0.08), z)) for (x, z) in superellipse(14, 10.95, 4.75, 4, rng, 0.03, 0.3, 0.0, 0.35)]
    pts += [Vector((x, 16.75 + rng.uniform(-0.08, 0.08), z)) for (x, z) in superellipse(12, 9.2, 3.4, 3, rng, 0.04, 0.0, 0.0, 0.45)]
    pts += [Vector((rng.uniform(-4, 4), 17.3 + rng.uniform(-0.06, 0.04), rng.uniform(-1.0, 1.4))) for _ in range(4)]
    shell(pc, pts, snow_colfn(SNOW_WHITE))
    for x in (-8.2, -4.5, -0.6, 3.4, 7.6):
        shell(pc, lump_pts((x + rng.uniform(-0.3, 0.3), 15.05, -4.25), rng.uniform(0.6, 0.9), rng.uniform(0.42, 0.55), 0.35, rng,
                           drop=rng.uniform(0.18, 0.3)), snow_colfn(SNOW_WHITE))
    for sx in (-1, 1):
        for z in (-1.4, 2.1):
            shell(pc, lump_pts((sx * 10.7, 15.1, z + rng.uniform(-0.3, 0.3)), 0.35, 0.42, rng.uniform(0.6, 0.8), rng,
                               drop=rng.uniform(0.15, 0.25)), snow_colfn(SNOW_WHITE))
    return [pc]


# --- 04 snow bridge -------------------------------------------------------------------------------------------
def _span_ice(pc, xf, hx, rng, cols, core, light):
    """Layered faceted ice body of one Span box (local half sizes hx x 2 x 5): 3 strata stepping inward going down
    (chamfered edges in `light`) and an opaque core."""
    hz = 5.0
    # planar rings with parallel edges (the side faces stay quads); the facets come from a few bulge / keel points
    l1 = _rect8(hx, hz, 0.35, 1.98) + _rect8(hx - 0.12, hz - 0.12, 0.35, 0.55)
    l2 = _rect8(hx - 0.3, hz - 0.35, 0.45, 0.75) + _rect8(hx - 0.7, hz - 0.75, 0.6, -0.95)
    l2 += [Vector((u * (hx - 1.5), -0.1 + rng.uniform(-0.1, 0.1), s * (hz - 0.25))) for (u, s) in ((-0.45, -1), (0.4, 1))]
    l3 = _rect8(hx - 0.9, hz - 0.95, 0.6, -0.75) + _rect8(hx - 1.8, hz - 2.05, 0.7, -1.95)
    l3 += [Vector((u * (hx - 3.0), -2.45 + rng.uniform(-0.1, 0.1), rng.uniform(-0.6, 0.6))) for u in (-1, 0.05, 1)]
    for pts, col in ((l1, cols[0]), (l2, cols[1]), (l3, cols[2])):
        bevel_shell(pc, [xf(p) for p in pts], 0.1, lambda cc, n, col=col: tone(col, rng.choice((1.0, 0.95)) * (1.04 if n.y < -0.5 else 1.0)),
                    lambda cc, n: light, m="Glass")
    cpts = _rect8(hx - 1.2, hz - 1.4, 0.6, 1.4) + _rect8(hx - 2.0, hz - 2.4, 0.6, -1.6)
    shell(pc, [xf(p) for p in cpts], lambda cc, n: core)


def t_bridge():
    rng = random.Random(8301)
    pv = {"relativeTo": "the Snow_Bridge_Section model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
          "scale": "the copy's Model scale (1.0 everywhere)"}
    mid = Piece("tundra_bridge", "ice_mid", "the Snow_Bridge_Section kit pivot (y 0 = the pivot, the span runs along X)",
                place=dict(pv, replaces="the look of the middle Span (16 x 4 x 10 #54A0E8 at (0, 5, 0)); keep it as the invisible "
                           "collider", collide="CanCollide off on the piece"),
                notes="layered blue ice underside of the middle span: 3 faceted strata stepping inward going down (top band "
                      "#74B6EC, main #54A0E8, keel #1E7FD6 hanging 0.45 below the box), every edge chamfered in light "
                      "#BFE9F5; Glass Transparency 0.25 (edges 0.2) over an opaque navy #234A8F core = the inner colour "
                      "gradient. 4 closed convex shells.")
    _span_ice(mid, _xf((0.0, 5.0, 0.0), M_ID), 8.0, rng, (mix(T_ICE_DEEP, T_ICE_L, 0.3), T_ICE_DEEP, T_ICE_D), T_NAVY, T_ICE_L)
    side = Piece("tundra_bridge", "ice_side", "the Snow_Bridge_Section kit pivot; built on the RIGHT span (+X)",
                 place=dict(pv, orientation="[0, 0, 0] for the right span; [0, 180, 0] (same kit pivot) for the left span",
                            replaces="the look of the side Spans (13 x 4 x 10 #96D6FA at (+-13.6, 3.5, 0), roll -+13 deg; the "
                            "Tundra_3 copies 10.1 deep); keep them as invisible colliders", collide="CanCollide off on the piece"),
                 notes="layered ice underside of a side span, same recipe in the side colours (top band #A2DCF8, main "
                       "#96D6FA, keel #6EC6EA), light #BFE9F5 chamfers, Glass T 0.25 over an opaque #1E7FD6 core. 4 closed "
                       "convex shells.")
    _span_ice(side, _xf((13.6, 3.5, 0.0), M_SPAN_R), 6.5, rng, (mix(T_ICE, T_ICE_L, 0.3), T_ICE, T_ICE_M), T_ICE_D, mix(T_ICE_L, T_WHITE, 0.3))
    smid = Piece("tundra_bridge", "snow_mid", "the Snow_Bridge_Section kit pivot",
                 place=dict(pv, replaces="the look of the middle SpanSnow (16.4 x 1.2 x 10.6 #F4F8FF at (0, 7.4, 0)); keep it "
                            "as the invisible collider: the walk top stays y 8.0", collide="CanCollide off on the piece"),
                 notes="soft snow on the middle span: the TOP is exactly flat at y 8.0 (= the collider top) and 0.3 inside "
                       "the edges, a bulging rim, lips rolling 1.0 down over both long edges (z +-5.5) with 4 drip lumps "
                       "each, short 0.25 bevels at the ends where it meets the side snow. #F4F8FF / #E1EBFA / #CEDEF6.")
    r1 = slab_snow_into(smid, _xf((0.0, 7.4, 0.0), M_ID), 8.2, 5.3, 0.6,
                        {"-x": (0.0, 0.25, 0), "+x": (0.0, 0.25, 0), "-z": (0.18, 1.0, 4), "+z": (0.18, 1.0, 4)}, rng, SNOW_WHITE)
    smid.place["icicleRoots"] = r1
    sside = Piece("tundra_bridge", "snow_side", "the Snow_Bridge_Section kit pivot; built on the RIGHT span (+X)",
                  place=dict(pv, orientation="[0, 0, 0] right; [0, 180, 0] left",
                             replaces="the look of the side SpanSnows (13.4 x 1.2 x 10.6 #CEDEF6 at (+-14.14, 5.84, 0), roll -+13; "
                             "the Tundra_3 copies 10.7 deep); keep them as invisible colliders: the walk tops stay exactly",
                             collide="CanCollide off on the piece"),
                  notes="soft snow on a side span in #CEDEF6 (its own colour): the top exactly on the collider's tilted top "
                        "plane (local y +0.6), lips 0.95 down over the long edges with 3 drips each, a 0.9 lip with 2 drips "
                        "over the bridge end (x 20.8), a short bevel at the inner end. The icicleRoots are for the right "
                        "span (mirror x and z for the left).")
    r2 = slab_snow_into(sside, _xf((14.1399, 5.8385, 0.0), M_SPAN_R), 6.7, 5.3, 0.6,
                        {"-x": (0.0, 0.25, 0), "+x": (0.15, 0.9, 2), "-z": (0.18, 0.95, 3), "+z": (0.18, 0.95, 3)}, rng, SNOW_SHADE)
    sside.place["icicleRoots"] = r2
    return [mid, side, smid, sside]


# --- 01 cabin roof snow ---------------------------------------------------------------------------------------
def t_cabin_roof():
    rng = random.Random(8401)
    main = Piece("tundra_cabin", "roof_snow", "the Cabin_Broken kit pivot (bottom centre, front -Z; the ridge runs along Z)",
                 place={"relativeTo": "the Cabin_Broken model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                        "scale": 1.0, "replaces": "the look of the main RoofSnow (11.6 x 1.0 x 17.6 #F4F8FF at (-5.64, 13.07, 0), "
                        "roll 31 deg); keep it as the invisible collider (its top = the piece's flat top)",
                        "collide": "CanCollide off on the piece"},
                 notes="thick soft snow on the whole -X roof slope: flat top exactly on the collider's top plane, a rim "
                       "that bulges past the gables (0.25) and rolls 1.15 down over the eave (0.45 past it, covering the "
                       "board end) with 5 drip lumps; 2 drips on each gable edge; it stops at the ridge. icicleRoots = "
                       "points under the eave lip between the drips (hang tundra_ice__icicle / cluster there).")
    main.place["icicleRoots"] = slab_snow_into(main, _xf((-5.6378, 13.0686, 0.0), M_ROOF_MAIN), 5.8, 8.8, 0.5,
                                               {"-x": (0.45, 1.15, 5), "+x": (0.0, 0.3, 0), "-z": (0.25, 0.6, 2), "+z": (0.25, 0.6, 2)},
                                               rng, SNOW_WHITE, n=24)
    small = Piece("tundra_cabin", "roof_snow_small", "the Cabin_Broken kit pivot",
                  place={"relativeTo": "the Cabin_Broken model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                         "scale": 1.0, "replaces": "the look of the small RoofSnow (6.4 x 0.9 x 6.6 #CEDEF6 at (3.61, 14.23, 5.5), "
                         "roll -31 deg); keep it as the invisible collider", "collide": "CanCollide off on the piece"},
                  notes="snow on the surviving piece of the +X slope in #CEDEF6: flat top on the collider top, a 1.0 lip "
                        "over the eave (+X) with 2 drips, a ragged lip with 2 drips on the broken front edge (z 2.2), 1 on "
                        "the back gable.")
    small.place["icicleRoots"] = slab_snow_into(small, _xf((3.612, 14.2257, 5.5), M_ROOF_SMALL), 3.2, 3.3, 0.45,
                                                {"+x": (0.4, 1.0, 2), "-x": (0.0, 0.3, 0), "-z": (0.2, 0.6, 2), "+z": (0.2, 0.5, 1)},
                                                rng, SNOW_SHADE, n=18)
    return [main, small]


def tundra_buildings():
    pieces = t_cabin_roof() + t_cave_boulders() + t_cave_slab() + t_cave_slab_snow() + t_bridge() + t_snow_caps() \
        + t_snow_drifts() + t_icicles() + t_ice_block() + t_ice_shards()
    for pc in pieces:
        pc.notes += f" [{shell_count(pc)} shells]"
    return pieces


def _glassy(ob, pc, alpha=0.8):
    """Preview only: faces whose material is Glass render see-through, like Studio: closed shells, back faces culled
    (no solidify), so only the front facets and the opaque core behind them show."""
    cols = sorted(set(f["c"] for f in pc.faces))
    glass = set(f["c"] for f in pc.faces if f["m"] == "Glass")
    if glass:
        for md in list(ob.modifiers):
            ob.modifiers.remove(md)
        for mt in ob.data.materials:
            P._try(lambda mt=mt: setattr(mt, "use_backface_culling", True))
    for i, c in enumerate(cols):
        if c in glass and i < len(ob.data.materials):
            mt = ob.data.materials[i]
            b = mt.node_tree.nodes.get("Principled BSDF")
            P._try(lambda: setattr(b.inputs["Alpha"], "default_value", alpha))
            P._try(lambda: setattr(mt, "surface_render_method", "BLENDED"))
            P._try(lambda: setattr(mt, "blend_method", "BLEND"))
    return ob


def preview_tundra_buildings(pieces):
    from mathutils import Matrix
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    by = {f"{p.obj}__{p.name}": p for p in pieces}
    V = Vector

    def put(name, off=V((0, 0, 0)), rot=None, scale=1.0):
        pc = by[name]
        return _glassy(piece_object(pc, col, off, rot, scale), pc)

    def nonuni(m, s):
        return _mat3(m) @ Matrix(((s[0], 0, 0), (0, s[1], 0), (0, 0, s[2])))
    # 1 cabin (kit space)
    W, D = "#865C42", "#5C4236"
    g1 = context_boxes([((0, 0.3, 0), (20, 0.6, 16), D, (0, 0, 0)), ((0, 4.5, 7.5), (20, 9, 1), W, (0, 0, 0)),
                        ((-9.5, 4.5, 0), (1, 9, 14), W, (0, 0, 0)), ((-6.5, 4.5, -7.5), (7, 9, 1), W, (0, 0, 0)),
                        ((6.5, 2.75, -7.5), (7, 5.5, 1), W, (0, 0, 0)), ((9.5, 2.5, 0), (1, 5, 14), W, (0, 0, 0)),
                        ((0, 7.75, -7.5), (6, 2.5, 1), D, (0, 0, 0)), ((0, 3.25, -7.2), (6, 6.5, 0.3), "#1F222B", (0, 0, 0)),
                        ((-5.5, 8.5, 5), (3.2, 17, 3.2), T_ROCK, (0, 0, 0)), ((-5.2, 12.34, 0), (12.4, 0.8, 18), D, (0, 0, 31)),
                        ((3.2, 13.54, 5.5), (7, 0.8, 7), D, (0, 0, -31)), ((0, 15.2, 0), (1.4, 1.4, 18.6), D, (0, 0, 0)),
                        ((-6.5, 5, -7.5), (3, 3, 1.2), "#1F222B", (0, 0, 0))], col)
    g1 += [put("tundra_cabin__roof_snow"), put("tundra_cabin__roof_snow_small"),
           put("tundra_snow__cap", V((-5.5, 17.0, 5.0)), nonuni(M_ID, (3.9, 0.8, 3.9)))]
    for pos, m, s, nm in (((-6.5, 0, -10.5), M_ID, (9, 3.5, 5), "drift"), ((0, 0, 10.5), (-1, 0, 0, 0, 1, 0, 0, 0, -1), (20, 4, 5), "drift"),
                          ((-13, 0, 0), (0, 0, 1, 0, 1, 0, -1, 0, 0), (14, 4.5, 6), "drift_shade")):
        g1.append(put(f"tundra_snow__{nm}", V(pos), nonuni(m, s)))
    for i, r in enumerate(by["tundra_cabin__roof_snow"].place["icicleRoots"]):
        nm = "tundra_ice__icicle_cluster" if i % 2 else "tundra_ice__icicle"
        g1.append(put(nm, V(r), euler_matrix([0, 90, 0]), 0.55 if i % 2 else 0.6))
    # 2 cave (offset +X 50)
    o = V((50, 0, 0))
    g2 = context_boxes([((50, 5.5, 1.8), (12, 11, 2), "#0F1F36", (0, 0, 0)), ((50, 7, 3.6), (18, 14, 2), T_ROCK_D, (0, 0, 0))], col)
    g2 += [put(f"tundra_cave__{n}", o) for n in ("ice_left", "ice_right", "slab", "slab_snow")]
    for (x, z, yaw, s) in ((-4.9, -5.2, 20, 1.0), (5.3, -5.4, -35, 0.8), (-11.8, -2.6, 0, 0.7), (12.3, -1.8, 150, 0.6)):
        g2.append(put("tundra_ice__shards", o + V((x, 0, z)), euler_matrix([0, yaw, 0]), s))
    for (x, L) in ((0.4, 4.2), (-3.2, 3.0), (3.4, 2.6)):
        g2.append(put("tundra_ice__icicle", o + V((x, 10.4, -0.6)), nonuni(M_ID, (1.0, L / 3.0, 1.0))))
    g2.append(put("tundra_ice__icicle_cluster", o + V((-1.6, 10.35, -2.6)), None, 0.8))
    g2.append(put("tundra_ice__icicle_cluster", o + V((2.2, 10.35, -2.9)), euler_matrix([0, 180, 0]), 0.7))
    # 3 bridge (offset +X 100)
    o = V((100, 0, 0))
    g3 = [put("tundra_bridge__ice_mid", o), put("tundra_bridge__ice_side", o), put("tundra_bridge__ice_side", o, euler_matrix([0, 180, 0])),
          put("tundra_bridge__snow_mid", o), put("tundra_bridge__snow_side", o), put("tundra_bridge__snow_side", o, euler_matrix([0, 180, 0]))]
    for (x, z, L) in ((-9, -3, 3.0), (-4, 2.5, 4.6), (1, -3, 2.6), (6, 2.5, 5.0), (11, -3, 3.4)):
        top = 3.0 if abs(x) < 8 else 1.55 + (abs(x) - 13.15) * -0.231 + 0.1
        g3.append(put("tundra_ice__icicle", o + V((x, top + 0.2, z)), nonuni(M_ID, (0.9, L / 3.0, 0.9))))
    for r in by["tundra_bridge__snow_mid"].place["icicleRoots"][::2]:
        g3.append(put("tundra_ice__icicle_cluster", o + V(r), None, 0.5))
    # 4 shared pieces line-up (offset +X 150)
    x0 = 150.0
    g4 = context_boxes([((x0, 0.5, 0), (3.2, 1.0, 3.2), T_ROCK, (0, 0, 0)), ((x0 + 6, 2.0, 2.2), (6.0, 0.4, 1.0), "#5C4236", (0, 0, 0))], col)
    g4 += [put("tundra_snow__cap", V((x0, 1.0, 0)), None, 3.4), put("tundra_snow__cap_drip", V((x0 + 4.5, 0, -1.0)), None, 2.6),
           put("tundra_snow__cap_shade", V((x0 + 8.5, 0, -1.0)), None, 2.6),
           put("tundra_snow__drift", V((x0 + 1.5, 0, 6)), nonuni(M_ID, (6, 2.2, 3.5))),
           put("tundra_snow__drift_shade", V((x0 + 8, 0, 6)), nonuni(M_ID, (5, 1.8, 3))),
           put("tundra_ice__icicle", V((x0 + 4.2, 1.8, 2.2)), None, 0.55), put("tundra_ice__icicle_cluster", V((x0 + 6.8, 1.8, 2.2)), None, 0.6),
           put("tundra_ice__block", V((x0 + 12, 0, 0.5)), None, 1.3), put("tundra_ice__shards", V((x0 + 12.5, 0, 5)), None, 1.2)]
    out = os.path.join(P.PREVIEW_DIR, "tundra_buildings_facets.png")
    return render_sheet("tundra", [(g1, [(-35, 22)]), (g2, [(-20, 12)]), (g3, [(-25, 12)]), (g4, [(-20, 15)])], None, out)


# ------------------------------------------------------------------------------------------------
# TUNDRA GATES AND ENTRANCES (guide section E8, owner task 2026-10-22): only the organic pieces the parts do badly.
# 01 / 02 are duplicated from the plains templates (entry_arch, gate_palisade) by Agent B; here: a snow cap for round
# logs (01 beams, 03 beam), the 02 roof slope snow and lintel snow, the 03 ice-rock boulders (big pillars + small side
# rocks, layered blues + snow caps), the 04 crystal spire (also the 01 foot crystals at a smaller scale). Closed convex
# shells, as the buildings group; the tundra_snow__* / tundra_ice__* pieces are reused for caps, drifts and icicles.
# ------------------------------------------------------------------------------------------------
M_PILLAR_L = (0.9198, -0.0482, -0.3894, 0.0523, 0.9986, 0.0, 0.3889, -0.0204, 0.9211)
M_PILLAR_R = (0.9198, 0.0482, 0.3894, -0.0523, 0.9986, 0.0, -0.3889, -0.0204, 0.9211)
M_GROCK_L = (0.3624, 0.0, -0.932, 0.0, 1.0, 0.0, 0.932, 0.0, 0.3624)
M_GROCK_R = (0.3624, 0.0, 0.932, 0.0, 1.0, 0.0, -0.932, 0.0, 0.3624)
_S = 1.0 / math.sqrt(3.5 * 3.5 + 3.0 * 3.0)
M_ROOF2 = (1.0, 0.0, 0.0, 0.0, 3.5 * _S, 3.0 * _S, 0.0, -3.0 * _S, 3.5 * _S)   # 02 front roof slope (x, normal, up-slope)


def t_log_cap():
    rng = random.Random(8501)
    pc = Piece("tundra_snow", "log_cap", "the piece's own anchor: (0, 0, 0) = on the AXIS of a round log 2.4 thick, at the "
               "middle of a 12-stud segment along X; the snow lies on the log's top (+Y)",
               place={"relativeTo": "the gate kit (pivot)", "position": "segments every 11 studs along each round beam, centres "
                      "on the beam axis: 01 main Beam (y 18.5, 38 long): x -12.5 / 0 / 12.5; 01 top Beam (y 25.6, d 2.0, 32 long): "
                      "x -10.5 / 0 / 10.5 at scale 0.83; 03 Beam (y 22.6, d 2.2, 34 long): x -11 / 0 / 11 at scale 0.92",
                      "orientation": "[0, 0, 0] or [0, 180, 0] alternately (variety); the beams run along X",
                      "scale": "uniform = the log diameter / 2.4 (the segments overlap 1 stud)",
                      "replaces": "BeamSnow (01: 30 x 0.8 x 2.6; 03: 30 x 0.5 x 1.6; no collision)", "collide": "CanCollide off"},
               notes="thick soft snow along the top of a round log: 3 overlapping convex mounds of different heights (an "
                     "irregular crest 0.7-0.85 above the log), a rim that bulges 0.55 past the log's sides and sinks into the "
                     "log below its widest line, 3 drip lumps over the front (-Z) side and 1 at the back. #F4F8FF / #E1EBFA / "
                     "#CEDEF6.")
    R = 1.2
    for (x0, x1, crest) in ((-6.0, -1.4, 1.95), (-2.6, 2.4, 2.05), (1.3, 6.0, 1.9)):
        pts = []
        n = 3
        for i in range(n):
            x = x0 + (x1 - x0) * i / (n - 1)
            end = 0.72 if i in (0, n - 1) else 1.0
            for (y, z) in ((0.5, 0.95), (1.05, 1.22), (crest - 0.25, 0.78), (crest, 0.25)):
                for s in (-1, 1):
                    yy = R + (y * R / 1.2 - R) * end if y > 1.0 else y * R / 1.2
                    pts.append(Vector((x + rng.uniform(-0.1, 0.1), yy + rng.uniform(-0.05, 0.05), s * z * end + rng.uniform(-0.05, 0.05))))
        shell(pc, pts, snow_colfn(SNOW_WHITE))
    for (x, z, hz) in ((-4.0, -1.15, 0.3), (0.6, -1.2, 0.3), (4.3, -1.15, 0.28), (-1.8, 1.15, 0.26)):
        shell(pc, lump_pts((x + rng.uniform(-0.4, 0.4), 0.85, z), rng.uniform(0.5, 0.75), 0.32, hz, rng, n=9, drop=rng.uniform(0.12, 0.22)),
              snow_colfn(SNOW_WHITE))
    return [pc]


def t_gate2_snow():
    rng = random.Random(8511)
    roof = Piece("tundra_gate2", "roof_snow", "the Gate_Tundra_2 kit pivot (bottom centre, front -Z); built on the FRONT slope "
                 "of the gate_palisade template's sign roof (ridge y 27.2 at z 0, eaves y 24.2 at z -3.5, x -15.5..15.5)",
                 place={"relativeTo": "the gate model (kit pivot)", "position": [0, 0, 0],
                        "orientation": "[0, 0, 0] front slope; [0, 180, 0] back slope",
                        "scale": 1.0, "replaces": "the white SignRoof look (keep the 2 SignRoof wedges as invisible colliders); "
                        "the duplicated template's tiles stay under it, recoloured blue-grey, visible at the eave",
                        "note": "if the duplicated roof is moved -0.4 in z to sit on the tundra SignRoof wedges (their ridge is "
                                "at z -0.4), move this piece the same", "collide": "CanCollide off"},
                 notes="snow on one slope of the 02 sign roof: a thick layer 0.6 over the tiles (top parallel to the slope), "
                       "the rim rolling 0.9 over the eave with 5 drip lumps, softer lips at the gable ends (1 drip each), "
                       "meeting the back slope's snow on the ridge. icicleRoots = under the eave lip.")
    slope_mid = Vector((0.0, 25.7, -1.75)) + Vector((0.0, 3.5 * _S, -3.0 * _S)) * 0.2
    roof.place["icicleRoots"] = slab_snow_into(roof, _xf(tuple(slope_mid), M_ROOF2), 15.5, 2.3, 0.6,
                                               {"-z": (0.35, 0.95, 5), "+z": (0.0, 0.45, 0), "-x": (0.25, 0.6, 1), "+x": (0.25, 0.6, 1)},
                                               rng, SNOW_WHITE, n=20)
    lint = Piece("tundra_gate2", "lintel_snow", "the Gate_Tundra_2 kit pivot",
                 place={"relativeTo": "the gate model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0], "scale": 1.0,
                        "replaces": "LintelSnow (28.8 x 0.7 x 3.6 at y 18.9, no collision)", "collide": "CanCollide off"},
                 notes="soft snow on the lintel (28.6 x 2.6 x 3.2, top y 18.6): flat-ish top at y 19.2, lips 1.25 down the "
                       "front with 4 drips and 0.9 down the back with 2; the sign posts stand through it. icicleRoots under the "
                       "front lip (keep the door opening clear: the tips must stay above y 16.2).")
    lint.place["icicleRoots"] = slab_snow_into(lint, _xf((0.0, 17.3, 0.0), M_ID), 14.3, 1.6, 1.9,
                                               {"-z": (0.15, 1.25, 4), "+z": (0.15, 0.9, 2), "-x": (0.2, 0.8, 0), "+x": (0.2, 0.8, 0)},
                                               rng, SNOW_WHITE, n=20)
    return [roof, lint]


def _layered_rock(pc, xf, half, rng, layers, snow, k=0.95, floor=-0.5):
    """Faceted rock-ice in a MeshPart box: stacked convex layers (local unit coords: (y0, r0, y1, r1, colour,
    offset)), each slightly offset, + a snow cap shell (rings (y, r) list) on the top layer. xf: local -> kit."""
    def kit(v):
        q = xf(Vector((v.x * half.x * k, v.y * half.y * k, v.z * half.z * k)))
        return Vector((q.x, max(q.y, floor), q.z))
    lo_all = None
    for (y0, r0, y1, r1, col, off, top) in layers:
        ph = rng.uniform(0, math.pi)
        pts = []
        for (y, r, n) in ((y0, r0, 7), (y1, r1, 7 if r1 > 0.3 else 5)):
            for i in range(n):
                a = ph + 2 * math.pi * (i + rng.uniform(-0.2, 0.2)) / n
                j = rng.uniform(0.9, 1.04)
                pts.append(Vector((off[0] + math.cos(a) * r * j, y + rng.uniform(-0.03, 0.03), off[1] + math.sin(a) * r * j)))
            ph += 0.45
        if top:
            pts.append(Vector((off[0] * 1.5 + top[0], top[1], off[1] * 1.5 + top[2])))
        kp = [kit(v) for v in pts]
        if lo_all is None:
            low = min(p.y for p in kp)
            kp += [Vector((p.x, floor, p.z)) for p in kp if p.y < low + 0.8]
            lo_all = floor
        ys = [p.y for p in kp]
        y_lo, y_hi = min(ys), max(ys)

        def colf(cc, n, col=col, y_lo=y_lo, y_hi=y_hi):
            h = max(0.0, min(1.0, (cc.y - y_lo) / max(y_hi - y_lo, 1e-6)))
            c = tone(col, (0.88 + 0.12 * h) * rng.choice(STEPS))
            return mix(c, "#FFFFFF", 0.1) if n.y > 0.6 else c
        shell(pc, kp, colf)
    if snow:
        ph = rng.uniform(0, math.pi)
        pts = []
        for (y, r, n, ox, oz) in snow["rings"]:
            for i in range(n):
                a = ph + 2 * math.pi * (i + rng.uniform(-0.2, 0.2)) / n
                pts.append(Vector((ox + math.cos(a) * r * rng.uniform(0.93, 1.05), y + rng.uniform(-0.03, 0.03), oz + math.sin(a) * r * rng.uniform(0.93, 1.05))))
            ph += 0.5
        pts.append(Vector(snow["top"]))
        shell(pc, [kit(v) for v in pts], snow_colfn(SNOW_WHITE))


def t_gate3_rocks():
    out = []
    specs = (("boulder_left", (-22.5, 17.5, 0.0), (17.0, 36.0, 16.0), M_PILLAR_L, T_ROCK, 8601, "Pillar"),
             ("boulder_right", (22.5, 17.5, 0.0), (17.0, 36.0, 16.0), M_PILLAR_R, T_ROCK_D, 8602, "Pillar"),
             ("rock_left", (-31.5, 6.0, -3.0), (11.0, 13.0, 11.0), M_GROCK_L, T_ROCK_D, 8611, "Rock"),
             ("rock_right", (31.5, 6.0, -3.0), (11.0, 13.0, 11.0), M_GROCK_R, T_ROCK, 8612, "Rock"))
    for name, pos, size, m, base, seed, kitname in specs:
        rng = random.Random(seed)
        big = kitname == "Pillar"
        deep, mid, light = mix(base, T_NAVY, 0.35), mix(base, "#3468B4", 0.22), mix(base, T_ICE_M, 0.2)
        if big:
            layers = ((-1.0, 0.86, -0.36, 0.98, deep, (0.0, 0.0), None),
                      (-0.42, 0.93, 0.3, 0.86, mid, (0.04, -0.02), None),
                      (0.24, 0.84, 0.72, 0.5, light, (0.06, 0.02), (0.05, 0.96, -0.04)))
            snow = {"rings": ((0.5, 0.7, 9, 0.08, 0.03), (0.74, 0.5, 8, 0.09, 0.02), (0.9, 0.24, 6, 0.1, 0.0)), "top": (0.12, 1.02, -0.02)}
        else:
            layers = ((-1.0, 0.82, -0.2, 0.98, deep, (0.0, 0.0), None),
                      (-0.28, 0.92, 0.55, 0.7, mid, (0.03, 0.03), (0.0, 0.8, 0.02)))
            snow = {"rings": ((0.35, 0.8, 8, 0.03, 0.03), (0.68, 0.48, 7, 0.04, 0.03)), "top": (0.05, 0.93, 0.0)}
        pc = Piece("tundra_gate3", name, "the Gate_Tundra_3 kit pivot (bottom centre, front -Z)",
                   place={"relativeTo": "the gate model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0], "scale": 1.0,
                          "replaces": f"the look of today's {kitname} MeshPart ({size[0]:g} x {size[1]:g} x {size[2]:g} at {pos}, {base}) "
                                      f"and its Snow MeshPart; keep the {kitname} as the invisible collider (it collides), the "
                                      "Snow had no collision", "collide": "CanCollide off"},
                   notes=f"faceted ice-rock {'pillar boulder' if big else 'side rock'} fitted to 95 % of today's {kitname} box "
                         f"(foot at y -0.5): {len(layers)} stacked convex strata in layered blues of today's {base} (deep "
                         f"{deep} at the foot, {mid}, light {light} on top), each offset a little, up-facing facets lighter; "
                         "a thick snow cap shell over the top third (#F4F8FF / #E1EBFA / #CEDEF6).")
        _layered_rock(pc, _xf(pos, m), Vector(size) * 0.5, rng, layers, snow, floor=-0.5)
        out.append(pc)
    return out


def t_gate4_spire():
    rng = random.Random(8701)
    pc = Piece("tundra_gate4", "spire", "the piece's own anchor: (0, 0, 0) = the bottom centre of the cluster (it stands on a "
               "tower cap); 10 x 18 x 10 like today's Spire mesh; the main crystal leans 4 deg toward +X",
               place={"relativeTo": "the gate model (kit pivot)", "position": "04: (-19.5, 43.0, 2.0) and (19.5, 43.0, 2.0) (on "
                      "the TowerCap tops, today's Spire meshes 10 x 18 x 10 at y 51.5); 01: the 4 foot Crystals: (-21.0, 0, -1.5) "
                      "scale 0.48 and (-19.6, 0, -3.6) scale 0.3, mirrored at +x",
                      "orientation": "04: yaw [0, -57, 0] / [0, 57, 0] (today's); 01: yaw so the lean points away from the "
                                     "passage ([0, 180, 0] on the left foot, [0, 0, 0] on the right)",
                      "scale": "04: 1.0; 01: 0.3-0.48",
                      "replaces": "04: the 2 Spire meshes (CanCollide off today, CanQuery on); 01: the 4 Crystal meshes (they "
                                  "COLLIDE today: keep them invisible as colliders)", "collide": "CanCollide off"},
               notes="big faceted crystal spire: a 6-sided main crystal (body, shoulder, tip at 17.6) with every edge "
                     "chamfered in light #D3EEF6 over #96D6FA facets, an opaque #54A0E8 core inside, and 2 smaller crystals "
                     "leaning out from its foot (#6EC6EA, #96D6FA). Glass Transparency 0.3 (edges 0.2). 4 closed convex shells.")

    def crystal(base, r, body, sh, tip, lean_deg, yaw_deg, sides=6, ph=0.0):
        ax = Vector((math.sin(math.radians(lean_deg)) * math.cos(math.radians(yaw_deg)), math.cos(math.radians(lean_deg)),
                     math.sin(math.radians(lean_deg)) * math.sin(math.radians(yaw_deg))))
        u = ax.cross(Vector((0, 0, 1)))
        u = (u if u.length > 1e-4 else ax.cross(Vector((1, 0, 0)))).normalized()
        v = ax.cross(u).normalized()
        b = Vector(base)
        pts = []
        for (h, k) in ((-0.6, 0.86), (body, 1.0), (body + sh, 0.55)):
            for i in range(sides):
                a = ph + 2 * math.pi * i / sides
                pts.append(b + ax * h + (u * math.cos(a) + v * math.sin(a)) * r * k * rng.uniform(0.96, 1.03))
        pts.append(b + ax * tip + u * 0.1 * r)
        return pts, b, ax
    main, b, ax = crystal((0.0, 0.0, 0.0), 3.1, 10.5, 3.0, 17.6, 4, 0, ph=0.3)
    bevel_shell(pc, main, 0.18, ice_colfn(T_ICE, -0.5, 17.6, rng), lambda cc, n: mix(T_ICE_L, T_WHITE, 0.3), m="Glass")
    core, _, _ = crystal((0.0, 0.3, 0.0), 1.7, 8.5, 2.0, 12.5, 4, 0, ph=0.8)
    shell(pc, core, lambda cc, n: T_ICE_DEEP if n.y < 0.5 else mix(T_ICE_DEEP, T_ICE_M, 0.3))
    for (pos, r, body, sh, tip, lean, yaw, col) in (((2.7, 0.0, 1.3), 1.5, 5.6, 1.6, 9.2, 22, 20, T_ICE_M),
                                                    ((-2.4, 0.0, -1.7), 1.2, 4.0, 1.3, 6.6, 26, 210, T_ICE)):
        pts, _, _ = crystal(pos, r, body, sh, tip, lean, yaw, sides=5, ph=rng.uniform(0, 1))
        shell(pc, pts, lambda cc, n, col=col: mix(col, T_ICE_L, 0.35) if n.y > 0.45 else tone(col, rng.choice((1.0, 0.94))), m="Glass")
    return [pc]


def tundra_gates():
    pieces = t_log_cap() + t_gate2_snow() + t_gate3_rocks() + t_gate4_spire()
    for pc in pieces:
        pc.notes += f" [{shell_count(pc)} shells]"
    return pieces


def preview_tundra_gates(pieces):
    from mathutils import Matrix
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    # the reused tundra_buildings pieces (same seeds = the same faces as their JSON)
    by = {f"{p.obj}__{p.name}": p for p in pieces + t_snow_caps() + t_snow_drifts() + t_icicles()}
    V = Vector
    D, W, WL = "#5C4236", "#865C42", "#997660"

    def put(name, off=V((0, 0, 0)), rot=None, scale=1.0):
        pc = by[name]
        return _glassy(piece_object(pc, col, off, rot, scale), pc)
    # 01 torii arch (context boxes for the logs)
    g1 = context_boxes([((-16, 1.5, 0), (8, 3, 7), T_ROCK, (0, 0, 0)), ((16, 1.5, 0), (8, 3, 7), T_ROCK, (0, 0, 0)),
                        ((-17.4, 9.0, 0), (2.4, 18, 2.4), WL, (0, 0, 0)), ((17.4, 9.0, 0), (2.4, 18, 2.4), WL, (0, 0, 0)),
                        ((-14.6, 11.5, 0), (2.6, 23, 2.6), W, (0, 0, 0)), ((14.6, 11.5, 0), (2.6, 23, 2.6), W, (0, 0, 0)),
                        ((0, 18.5, 0), (38, 2.4, 2.4), D, (0, 0, 0)), ((0, 25.6, 0), (32, 2.0, 2.0), D, (0, 0, 0)),
                        ((0, 22.2, -0.2), (15.4, 5.2, 0.6), D, (0, 0, 0)), ((0, 22.2, -0.6), (14, 4, 0.5), "#3468B4", (0, 0, 0))], col)
    for x in (-12.5, 0.0, 12.5):
        g1.append(put("tundra_snow__log_cap", V((x, 18.5, 0)), euler_matrix([0, 180 if x == 0 else 0, 0])))
    for x in (-10.5, 0.0, 10.5):
        g1.append(put("tundra_snow__log_cap", V((x, 25.6, 0)), euler_matrix([0, 0 if x == 0 else 180, 0]), 0.83))
    for sx in (-1, 1):
        g1.append(put("tundra_gate4__spire", V((sx * 21.0, 0, -1.5)), euler_matrix([0, 0 if sx > 0 else 180, 0]), 0.48))
        g1.append(put("tundra_gate4__spire", V((sx * 19.6, 0, -3.6)), euler_matrix([0, 0 if sx > 0 else 180, 0]), 0.3))
        g1.append(put("tundra_snow__cap", V((sx * 16, 3.0, 0)), _mat3(M_ID) @ Matrix(((8.4, 0, 0), (0, 0.7, 0), (0, 0, 7.3)))))
    # 02 palisade (offset +60)
    o = V((60, 0, 0))
    ctx2 = [((60, 17.3, 0), (28.6, 2.6, 3.2), D, (0, 0, 0)), ((60, 8, 0), (24, 16, 1.4), W, (0, 0, 0)),
            ((60, 21.3, -1.25), (12, 4, 0.5), "#3468B4", (0, 0, 0))]
    for (x, h, c) in ((13.2, 21, W), (15.7, 23, WL), (18.2, 22, W), (20.7, 20, WL)):
        for sx in (-1, 1):
            ctx2.append(((60 + sx * x, (2.9 + h) / 2, 0), (2.6, h - 2.9, 2.6), c, (0, 0, 0)))
    for sx in (-1, 1):
        ctx2.append(((60 + sx * 17, 1.5, 0), (10.5, 3, 7.5), T_ROCK, (0, 0, 0)))
    for s in (-1, 1):   # the template's roof slopes (blue-grey tiles)
        ctx2.append(((60, 25.7, s * 1.75), (31.0, 0.3, 4.61), "#5E6E86", (s * 40.6, 0, 0)))
    g2 = context_boxes(ctx2, col)
    g2 += [put("tundra_gate2__roof_snow", o), put("tundra_gate2__roof_snow", o, euler_matrix([0, 180, 0])), put("tundra_gate2__lintel_snow", o)]
    for (x, h) in ((13.2, 21), (15.7, 23), (18.2, 22), (20.7, 20)):
        for sx in (-1, 1):
            g2.append(put("tundra_snow__cap", o + V((sx * x, h, 0)), _mat3(M_ID) @ Matrix(((2.9, 0, 0), (0, 0.7, 0), (0, 0, 2.9)))))
    for r in by["tundra_gate2__roof_snow"].place["icicleRoots"]:
        g2.append(put("tundra_ice__icicle", o + V(r), None, 0.45))
    for (pos, m, s) in (((-17.5, 0, -6.4), M_ID, (12, 5.5, 6)), ((17.5, 0, -6.4), M_ID, (12, 5.5, 6))):
        g2.append(put("tundra_snow__drift", o + V(pos), _mat3(m) @ Matrix(((s[0], 0, 0), (0, s[1], 0), (0, 0, s[2])))))
    # 03 ice rock gate (offset +140)
    o = V((140, 0, 0))
    g3 = context_boxes([((140 - 13.7, 9.5, 0), (3.4, 19, 6), T_ROCK_D, (0, 0, 0)), ((140 + 13.7, 9.5, 0), (3.4, 19, 6), T_ROCK_D, (0, 0, 0)),
                        ((140, 22.6, 0), (34, 2.2, 2.2), D, (0, 0, 0)), ((140, 8, 0), (24, 16, 2.0), T_ICE, (0, 0, 0)),
                        ((140, 18.6, -0.6), (13.2, 5, 0.4), D, (0, 0, 0))], col)
    g3 += [put(f"tundra_gate3__{n}", o) for n in ("boulder_left", "boulder_right", "rock_left", "rock_right")]
    for x in (-11.0, 0.0, 11.0):
        g3.append(put("tundra_snow__log_cap", o + V((x, 22.6, 0)), None, 0.92))
    # 04 ice castle towers + spires (offset +220)
    o = V((220, 0, 0))
    g4 = context_boxes([((220 - 19.5, 20, 2), (15, 40, 12), T_ICE_DEEP, (0, 0, 0)), ((220 + 19.5, 20, 2), (15, 40, 12), T_ICE_DEEP, (0, 0, 0)),
                        ((220 - 19.5, 41.5, 2), (17, 3, 14), "#3468B4", (0, 0, 0)), ((220 + 19.5, 41.5, 2), (17, 3, 14), "#3468B4", (0, 0, 0)),
                        ((220, 26, 2), (24.2, 20, 8), T_ICE_DEEP, (0, 0, 0)), ((220, 37, 2), (27, 2, 9.5), "#3468B4", (0, 0, 0))], col)
    g4 += [put("tundra_gate4__spire", o + V((-19.5, 43.0, 2.0)), euler_matrix([0, -57, 0])),
           put("tundra_gate4__spire", o + V((19.5, 43.0, 2.0)), euler_matrix([0, 57, 0]))]
    out = os.path.join(P.PREVIEW_DIR, "tundra_gates_facets.png")
    return render_sheet("tgates", [(g1, [(-20, 10)]), (g2, [(-25, 15)]), (g3, [(-15, 10)]), (g4, [(-25, 12)])], None, out)


# ------------------------------------------------------------------------------------------------
# TUNDRA ICE MONUMENTS, STATUES AND SHRINES (guide section E9, owner task 2026-10-22): the faceted ice pillar shaft,
# the ice knight's helmet / pauldrons / plume, the warm brazier's glowing ribbed dome. The throne crystals reuse
# tundra_gate4__spire; caps, icicles and shards reuse tundra_snow__* / tundra_ice__*. Closed convex shells.
# ------------------------------------------------------------------------------------------------
def _ring_pts(n, r, y, ph=0.0, cx=0.0, cz=0.0, rz=None):
    rz = r if rz is None else rz
    return [Vector((cx + r * math.cos(ph + 2 * math.pi * k / n), y, cz + rz * math.sin(ph + 2 * math.pi * k / n))) for k in range(n)]


def t_pillar_shaft():
    rng = random.Random(8801)
    pc = Piece("tundra_mon", "pillar_shaft", "the Ice_Pillar kit pivot (bottom centre, front -Z)",
               place={"relativeTo": "the Ice_Pillar model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale (1.0 kit / test, 1.2 Tundra_4, 1.5 BossArenas)",
                      "replaces": "the look of the 2 crossed Shaft parts (4.6 / 4.5 square, 30 tall, y 5..35, #96D6FA + #54A0E8 "
                                  "turned 45 deg); keep them as invisible colliders", "collide": "CanCollide off"},
               notes="faceted ice shaft: an 8-sided prism with a slight entasis (r 2.45 at the foot, 2.6 in the middle, 2.3 "
                     "under the capital), the faces alternating today's two colours #96D6FA / #54A0E8 (they read as flutes), "
                     "every edge chamfered in light #D3EEF6 (the lighter edge); Glass Transparency 0.15 on the faces, 0.1 on "
                     "the edges, over an opaque #3468B4 core. The Neon chevrons are parts on the faces (guide E9). 2 closed "
                     "convex shells.")
    ph = math.pi / 8
    pts = []
    for (y, r) in ((5.0, 2.45), (6.2, 2.55), (20.0, 2.62), (33.8, 2.42), (35.0, 2.3)):
        pts += _ring_pts(8, r, y, ph)

    def body(cc, n):
        k = int(round((math.atan2(n.z, n.x) - ph) / (math.pi / 4))) % 2
        return tone(T_ICE if k == 0 else T_ICE_DEEP, 0.92 + 0.08 * max(0.0, min(1.0, (cc.y - 5) / 30)))
    bevel_shell(pc, pts, 0.2, body, lambda cc, n: mix(T_ICE_L, T_WHITE, 0.3), m="Glass")
    core = _ring_pts(8, 1.5, 5.3, ph) + _ring_pts(8, 1.5, 34.7, ph)
    shell(pc, core, lambda cc, n: "#3468B4")
    return [pc]


def t_knight_armor():
    rng = random.Random(8811)
    pc = Piece("tundra_mon", "knight_armor", "the Frozen_Knight_Statue kit pivot (bottom centre, front -Z; the knight faces -Z)",
               place={"relativeTo": "the Frozen_Knight_Statue model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale (1.0 / 1.15 / 1.2 / 1.25)",
                      "replaces": "Head (2 x 2 x 2 #5C626E at (0, 11.2, 0)), the 2 Shoulder blocks (1.8 x 1.4 x 2.4 at (+-2.7, 9.5, 0)) "
                                  "and the Plume (0.5 x 1.2 x 1.8 #BAAAEC); none collides today. Keep today's Neon Visor (1.4 x 0.3 "
                                  "at (0, 11.3, -1.02)): it stands 0.07 proud of the helm's flat front face",
                      "collide": "CanCollide off"},
               notes="great helm: an 8-sided steel helm (#5C626E, lighter #7A808C on the upper facets) with a flat front face "
                     "for today's Neon visor, a domed crown and a low crest ridge; 2 pauldrons, each a domed upper plate and a "
                     "wider lower lame (#5C626E / rim tone #7A808C), inside today's glass case (max x 3.65 < the case's 3.7); a "
                     "4-segment plume curving back from the crest in today's #BAAAEC. 9 closed convex shells.")
    steel, light = "#5C626E", "#7A808C"

    def steel_col(cc, n):
        return tone(light if n.y > 0.45 else steel, rng.choice((1.0, 0.94)))
    ph = math.pi / 8
    apo = 1.05 / math.cos(math.pi / 8)
    helm = _ring_pts(8, apo, 10.1, ph) + _ring_pts(8, apo * 1.02, 11.55, ph) + _ring_pts(8, apo * 0.82, 12.2, ph)
    helm += [Vector((0.0, 12.5, 0.15)), Vector((0.0, 12.42, -0.55)), Vector((0.0, 12.42, 0.75))]
    shell(pc, helm, steel_col)
    for sx in (-1, 1):
        cx = sx * 2.7
        top = [Vector((cx + 0.95 * math.cos(a) * rr, 9.62 + h, 1.25 * math.sin(a) * rr))
               for (h, rr) in ((0.0, 1.0), (0.35, 0.8), (0.6, 0.45)) for a in [2 * math.pi * k / 10 for k in range(10)]]
        top.append(Vector((cx + sx * 0.05, 10.32, 0.0)))
        shell(pc, top, steel_col)
        lame = [Vector((cx + sx * 0.04 + 0.9 * math.cos(a) * rr, y, 1.3 * math.sin(a) * rr))
                for (y, rr) in ((9.05, 0.97), (9.6, 1.0)) for a in [2 * math.pi * k / 10 for k in range(10)]]
        shell(pc, lame, lambda cc, n: tone(light if n.y > 0.3 else steel, 0.92))
    segs = [(Vector((0.0, 12.45, 0.1)), Vector((0.0, 13.0, 0.3))), (Vector((0.0, 13.0, 0.3)), Vector((0.0, 13.35, 0.75))),
            (Vector((0.0, 13.35, 0.75)), Vector((0.0, 13.3, 1.3))), (Vector((0.0, 13.3, 1.3)), Vector((0.0, 12.85, 1.7)))]
    for i, (a, b) in enumerate(segs):
        d = (b - a).normalized()
        side = Vector((1, 0, 0))
        up = d.cross(side).normalized()
        w, h = 0.24 - 0.03 * i, 0.32 - 0.04 * i
        pts = [p + side * sx * w + up * sy * h for p in (a - d * 0.05, b + d * 0.05) for sx in (-1, 1) for sy in (-1, 1)]
        shell(pc, pts, lambda cc, n, i=i: tone("#BAAAEC", (1.0, 0.93, 1.0, 0.88)[i] * (1.05 if n.y > 0.3 else 1.0)))
    return [pc]


def t_brazier_dome():
    rng = random.Random(8821)
    pc = Piece("tundra_mon", "brazier_dome", "the Warm_Brazier kit pivot (bottom centre)",
               place={"relativeTo": "the Warm_Brazier / WarmBrazier model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale (1.0 kit / test, 1.3 the 4 BossArenas WarmSpots)",
                      "replaces": "the look of today's EmberGlow (Neon #FF8C28 ball 4.6 at (0, 6.45, 0)) = the owner's 'yellow dome'; "
                                  "keep Embers + FirePoint and, in the arena copies, the Fire part (VFX + PointLight) exactly",
                      "collide": "CanCollide off"},
               notes="glowing ribbed dome on today's gold rim (y 6.15): a warm glass dome (Neon #FFB648, Transparency 0.35, so "
                     "today's embers / fire VFX show through it; r 3.2 at the rim -> top y 8.8, inside today's 8.75 + 0.05) in "
                     "a cage of 8 gold #FFC93C ribs (3 straight segments each) and a brass #C99A2E crown ring at the top: the "
                     "openings between the ribs are the owner's 'small windows with frames and a warm glow'. 33 closed convex "
                     "shells (1 dome + 24 rib segments + 8 crown segments).")
    prof = ((3.2, 6.15), (2.85, 7.3), (1.9, 8.25), (0.9, 8.7))
    dome = []
    for (r, y) in prof:
        dome += _ring_pts(16, r, y)
    dome.append(Vector((0.0, 8.8, 0.0)))
    shell(pc, dome, lambda cc, n: mix("#FFB648", "#FFD678", 0.35) if n.y > 0.6 else "#FFB648", m="Neon")

    def bar(a, b, w, t, col):
        d = (b - a).normalized()
        out = Vector((a.x + b.x, 0.0, a.z + b.z)).normalized()
        side = d.cross(out).normalized()
        nrm = side.cross(d).normalized()
        pts = [p + side * sx * w / 2 + nrm * sy * t / 2 for p in (a, b) for sx in (-1, 1) for sy in (-1, 1)]
        shell(pc, pts, lambda cc, n: tone(col, 1.0 if n.y > 0.2 else 0.9))
    for k in range(8):
        ang = 2 * math.pi * k / 8 + math.pi / 16
        ring = [Vector(((r + 0.06) * math.cos(ang), y, (r + 0.06) * math.sin(ang))) for (r, y) in prof]
        for i in range(3):
            bar(ring[i], ring[i + 1], 0.28, 0.16, "#FFC93C")
    crown = _ring_pts(8, 1.02, 8.72, math.pi / 8)
    for i in range(8):
        bar(crown[i], crown[(i + 1) % 8], 0.22, 0.2, "#C99A2E")
    return [pc]


def tundra_monuments():
    pieces = t_pillar_shaft() + t_knight_armor() + t_brazier_dome()
    for pc in pieces:
        pc.notes += f" [{shell_count(pc)} shells]"
    return pieces


def preview_tundra_monuments(pieces):
    from mathutils import Matrix
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    extra = t_snow_caps() + t_icicles() + t_ice_shards() + t_gate4_spire()
    by = {f"{p.obj}__{p.name}": p for p in pieces + extra}
    V = Vector

    def put(name, off=V((0, 0, 0)), rot=None, scale=1.0):
        pc = by[name]
        return _glassy(piece_object(pc, col, off, rot, scale), pc)
    # 1 pillar
    g1 = context_boxes([((0, 1.5, 0), (8, 3, 8), "#3468B4", (0, 0, 0)), ((0, 4, 0), (6.4, 2, 6.4), T_ICE_DEEP, (0, 0, 0)),
                        ((0, 36, 0), (6.4, 2, 6.4), T_ICE_DEEP, (0, 0, 0)), ((0, 38.5, 0), (8, 3, 8), "#3468B4", (0, 0, 0))], col)
    g1 += [put("tundra_mon__pillar_shaft"), put("tundra_snow__cap", V((0, 40, 0)), _mat3(M_ID) @ Matrix(((8.3, 0, 0), (0, 0.8, 0), (0, 0, 8.3))))]
    # 2 knight (offset 20)
    o = V((20, 0, 0))
    g2 = context_boxes([((20, 1, 0), (8, 2, 8), "#3468B4", (0, 0, 0)), ((19, 4, 0), (1.5, 4, 1.6), "#5C626E", (0, 0, 0)),
                        ((21, 4, 0), (1.5, 4, 1.6), "#5C626E", (0, 0, 0)), ((20, 8.1, 0), (4, 4.2, 2.2), "#686E7C", (0, 0, 0)),
                        ((17.3, 7.4, -0.5), (1.2, 3.6, 1.4), "#686E7C", (20, 0, 0)), ((22.7, 7.4, -0.5), (1.2, 3.6, 1.4), "#686E7C", (20, 0, 0)),
                        ((20, 6.3, 0), (4.2, 0.7, 2.4), "#FFC93C", (0, 0, 0)), ((20, 11.3, -1.02), (1.4, 0.3, 0.2), "#60BEFF", (0, 0, 0)),
                        ((20, 5.4, -1.7), (0.5, 6.6, 0.25), "#F5F6FA", (0, 0, 0))], col)
    g2.append(put("tundra_mon__knight_armor", o))
    for (x, z, s) in ((4.0, -2.4, 0.22), (-4.0, -2.6, 0.28)):
        g2.append(put("tundra_gate4__spire", o + V((x, 1.8, z)), euler_matrix([0, 0 if x > 0 else 180, 0]), s))
    # 3 throne (offset 40)
    o = V((40, 0, 0))
    g3 = context_boxes([((40, 0.5, 0), (9, 1, 8), "#3468B4", (0, 0, 0)), ((40, 1.5, 0.6), (7.5, 1, 6), T_ICE_DEEP, (0, 0, 0)),
                        ((40, 2.8, 0.6), (5, 1.6, 4.4), T_ICE, (0, 0, 0)), ((37, 3.8, 0.6), (1.2, 2.4, 4.2), T_ICE, (0, 0, 0)),
                        ((43, 3.8, 0.6), (1.2, 2.4, 4.2), T_ICE, (0, 0, 0)), ((40, 7.3, 2.7), (5.4, 9, 1.4), T_ICE_DEEP, (0, 0, 0)),
                        ((40, 9.6, 1.9), (0.9, 0.9, 0.5), "#60BEFF", (0, 0, 45))], col)
    for (x, y, z, yaw, s) in ((0, 11.1, 2.7, 90, 0.4), (-2.0, 11.1, 2.7, 180, 0.29), (2.0, 11.1, 2.7, 0, 0.29),
                              (-4.8, 0.0, 2.6, 180, 0.43), (4.8, 0.0, 2.6, 0, 0.43)):
        g3.append(put("tundra_gate4__spire", o + V((x, y, z)), euler_matrix([0, yaw, 0]), s))
    # 4 brazier (offset 60)
    o = V((60, 0, 0))
    g4 = context_boxes([((60, 0.6, 0), (7, 1.2, 7), T_ROCK_D, (0, 0, 0)), ((60, 1.7, 0), (5, 1, 5), T_ROCK, (0, 0, 0)),
                        ((60, 3.3, 0), (2.4, 2.2, 2.4), "#5C626E", (0, 0, 0)), ((60, 5.0, 0), (8, 1.6, 8), "#5C626E", (0, 0, 0)),
                        ((60, 5.9, 0), (8.6, 0.5, 8.6), "#FFC93C", (0, 0, 0)), ((60, 6.05, 0), (7, 0.5, 7), "#FF8C28", (0, 0, 0))], col)
    g4.append(put("tundra_mon__brazier_dome", o))
    out = os.path.join(P.PREVIEW_DIR, "tundra_monuments_facets.png")
    return render_sheet("tmon", [(g1, [(-25, 15)]), (g2, [(-25, 12)]), (g3, [(-35, 15)]), (g4, [(-30, 25)])], None, out)


# ------------------------------------------------------------------------------------------------
# TUNDRA PROPS AND DECOR (guide section E10, owner task 2026-10-22): the frozen skeleton's ice block and skull, a
# reusable soft snowball (snowmen), a carrot nose, the weapon rack's 2 ice blocks. Everything else is parts; caps,
# drifts, icicles and shards reuse tundra_snow__* / tundra_ice__*. Closed convex shells (+ a few skull detail faces).
# ------------------------------------------------------------------------------------------------
T_BONE = "#F0E8D0"


def _ice_box_block(pc, rng, pos, size, base, light, floor, k=0.95, rings=None, d=0.14):
    half = Vector(size) * 0.5
    pts = []
    for v in boulder_local(rng, rings=rings) if rings else boulder_local(rng):
        q = Vector((pos[0] + v.x * half.x * k, pos[1] + v.y * half.y * k, pos[2] + v.z * half.z * k))
        pts.append(Vector((q.x, max(q.y, floor), q.z)))
    low = min(p.y for p in pts)
    pts += [Vector((p.x, floor, p.z)) for p in pts if p.y < low + 0.4]
    lo, hi = min(p.y for p in pts), max(p.y for p in pts)
    bevel_shell(pc, pts, d, ice_colfn(base, lo, hi, rng), lambda cc, n: light, m="Glass")


def t_skeleton():
    rng = random.Random(8901)
    ice = Piece("tundra_props", "skeleton_ice", "the Bone_Pile_Ice kit pivot (bottom centre, front -Z)",
                place={"relativeTo": "the Bone_Pile_Ice model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                       "scale": "the copy's Model scale (1.0; 1.5 in the boss arena)",
                       "replaces": "the Ice MeshPart (rock mesh 7231644778, 6 x 3 x 5.5 #96D6FA T 0.4 at (0.6, 1.2, 0.4); CanCollide "
                                   "off, CanQuery on today)", "collide": "CanCollide off (as today)"},
                notes="faceted translucent ice block fitted to 95 % of today's Ice box (flat foot sunk to y -0.3): big facets "
                      "#96D6FA (deeper at the foot, lighter on top), every edge chamfered in light #BFE9F5; Glass Transparency "
                      "0.4 (edges 0.3) and NO core, so the skull, ribs and bones read inside. 1 closed convex shell.")
    _ice_box_block(ice, rng, (0.6, 1.2, 0.4), (6.0, 3.0, 5.5), T_ICE, T_ICE_L, -0.3,
                   rings=((-0.9, 6, 0.86), (-0.25, 7, 1.0), (0.45, 6, 0.9), (0.85, 4, 0.55)))
    sk = Piece("tundra_props", "skull", "the Bone_Pile_Ice kit pivot",
               place={"relativeTo": "the Bone_Pile_Ice model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale",
                      "replaces": "the Skull ball (2.4 at (0.3, 1.68, 0.2)), the 2 EyeSocket blocks and the Jaw block (all collide: "
                                  "keep them invisible as colliders)", "collide": "CanCollide off"},
               notes="the C6 stylized human skull in today's bone colour #F0E8D0: cranium hull + jaw hull, dark eye sockets "
                     "(#3E3C4E, today's colour, a darker hollow inside) at today's socket places (x -0.2 / 0.8, y 1.88), a nose "
                     "hole, a gum line with 5 upper / 4 lower teeth; scale 1.32 so it fills today's 2.4 ball (top y 2.97, chin "
                     "0.19). The detail quads are thin loose faces on the hulls.")
    tmp = Piece("tmp", "tmp", "")
    human_skull_into(tmp, 1.32, (0.3, 1.85, 0.2))
    remap = {BONE: T_BONE, TWOOD: "#3E3C4E", JREC: "#1F222B"}
    for f in tmp.faces:
        c = f["c"]
        for a, b in remap.items():
            if c == a:
                c = b
                break
        else:
            for k_ in (0.8, 0.9, 0.95, 0.98, 1.03):
                if c == tone(BONE, k_):
                    c = tone(T_BONE, k_)
        sk.faces.append(dict(f, c=c))
    return [ice, sk]


def t_snowball():
    out = []
    for name, scheme, seed in (("snowball", SNOW_WHITE, 8911), ("snowball_shade", SNOW_SHADE, 8912)):
        rng = random.Random(seed)
        pc = Piece("tundra_props", name, "the piece's own anchor: (0, 0, 0) = the CENTRE of a snowball of diameter 2 (radius 1)",
                   place={"relativeTo": "the snowman model (kit pivot)",
                          "position": "each Ball's centre: Snowman_A Base (0, 1.9, 0), Body (0, 4.7, 0), Head (0, 6.9, 0); "
                                      "Snowman_B Base (0, 1.5, 0), Body (0.15, 3.8, 0), Head (0.35, 5.6, 0)",
                          "orientation": "any yaw (vary per ball)", "scale": "uniform = the Ball's diameter / 2 (A: 2.2 / 1.65 / "
                          "1.2; B: 1.8 / 1.35 / 1.0), times the copy's scale",
                          "replaces": "the look of the Ball parts (they collide: keep them invisible as colliders); "
                                      + ("white #F4F8FF balls (A Base / Head, B Body / Head)" if scheme is SNOW_WHITE else
                                         "the shaded #CEDEF6 balls (A Body, B Base)"),
                          "collide": "CanCollide off"},
                   notes="soft low-poly snowball with subtle bumps: the convex hull of 42 points on a sphere jittered "
                         "+-4 %, slightly flattened underneath (it sits); top faces " + scheme[0] + ", sides " + scheme[1]
                         + ", underside " + scheme[2] + ". 1 closed convex shell.")
        pts = []
        n = 42
        for i in range(n):
            yy = 1 - 2 * (i + 0.5) / n
            rr = math.sqrt(max(0.0, 1 - yy * yy))
            a = i * 2.39996 + rng.uniform(-0.15, 0.15)
            j = rng.uniform(0.96, 1.04)
            y = yy * j
            if y < -0.86:
                y = -0.86 - (y + 0.86) * 0.3      # a slightly flattened seat
            pts.append(Vector((math.cos(a) * rr * j, y, math.sin(a) * rr * j)))
        shell(pc, pts, snow_colfn(scheme))
        out.append(pc)
    return out


def t_carrot():
    rng = random.Random(8921)
    pc = Piece("tundra_props", "carrot", "the piece's own anchor: (0, 0, 0) = the centre of the carrot's thick end; it points "
               "along -Z, 1.4 long, 0.44 thick at the root",
               place={"relativeTo": "the snowman model (kit pivot)",
                      "position": "Snowman_A (0, 6.9, -0.9) (today's Nose 1.4 long, centre z -1.6); Snowman_B (0.35, 5.6, -0.7)",
                      "orientation": "[0, 0, 0] (or a slight droop [-6, 0, 0])", "scale": "A 1.0, B 0.86",
                      "replaces": "the Nose block (#FF8C28, no collision)", "collide": "CanCollide off"},
               notes="carrot nose: a 6-sided tapering cone with a slight bend and 2 shallow steps (growth rings), facets "
                     "alternating #FF8C28 / #E87A1E, a darker #C8641A root face. 1 closed convex shell.")
    pts = []
    for (z, r, dy) in ((0.0, 0.22, 0.0), (-0.12, 0.215, 0.0), (-0.55, 0.16, -0.02), (-1.0, 0.09, -0.05)):
        for i in range(6):
            a = 2 * math.pi * i / 6 + 0.3
            pts.append(Vector((r * math.cos(a), dy + r * math.sin(a), z)))
    pts.append(Vector((0.02, -0.09, -1.4)))

    def col(cc, n):
        if n.z > 0.8:
            return "#C8641A"
        return "#FF8C28" if int((math.atan2(n.y, n.x) + math.pi) / (math.pi / 3)) % 2 == 0 else "#E87A1E"
    shell(pc, pts, col)
    return [pc]


def t_rack_ice():
    rng = random.Random(8931)
    pc = Piece("tundra_props", "rack_ice", "the Weapon_Rack_Frozen kit pivot (bottom centre, front -Z)",
               place={"relativeTo": "the Weapon_Rack_Frozen model (kit pivot)", "position": [0, 0, 0], "orientation": [0, 0, 0],
                      "scale": "the copy's Model scale (1.0; 1.2 Tundra_4; 1.3 boss arena)",
                      "replaces": "the 2 Ice MeshParts: the base lump (rock mesh 7231644778, 7 x 3.2 x 3.4 #96D6FA T 0.4 at (0.5, 1.3, 0)) "
                                  "and the block round the sword (mesh 2557003083, 3 x 4 x 2.6 #D6ECFF T 0.4 at (-2.4, 4.0, 0.3)); "
                                  "neither collides today", "collide": "CanCollide off (as today)"},
               notes="2 faceted translucent ice blocks fitted to 95 % of today's Ice boxes: the low base lump (#96D6FA) on the "
                     "plank base, and the tall faceted block (#D6ECFF, crystal-like, a squarer outline) frozen round the "
                     "sword; light #BFE9F5 chamfered edges; Glass Transparency 0.4, NO core (the weapons read inside). 2 "
                     "closed convex shells.")
    _ice_box_block(pc, rng, (0.5, 1.3, 0.0), (7.0, 3.2, 3.4), T_ICE, T_ICE_L, 0.3,
                   rings=((-0.9, 5, 0.86), (-0.2, 6, 1.0), (0.5, 5, 0.85), (0.88, 3, 0.5)))
    _ice_box_block(pc, rng, (-2.4, 4.0, 0.3), (3.0, 4.0, 2.6), T_FROST, mix(T_ICE_L, T_WHITE, 0.3), 2.2,
                   rings=((-0.95, 4, 1.05), (0.3, 4, 1.1), (0.85, 4, 0.7)), d=0.12)
    return [pc]


def tundra_props():
    pieces = t_skeleton() + t_snowball() + t_carrot() + t_rack_ice()
    for pc in pieces:
        pc.notes += f" [{shell_count(pc)} shells]"
    return pieces


def preview_tundra_props(pieces):
    from mathutils import Matrix
    scn = clear_scene()
    col = P.collection(P.SUBJECT, scn)
    extra = t_snow_caps() + t_icicles()
    by = {f"{p.obj}__{p.name}": p for p in pieces + extra}
    V = Vector

    def put(name, off=V((0, 0, 0)), rot=None, scale=1.0):
        pc = by[name]
        return _glassy(piece_object(pc, col, off, rot, scale), pc)
    # 1 skeleton: bones as context boxes (bone ends / ribs), the skull and the ice block
    ctx = [((-0.25, 0.63, -0.25), (5.7, 0.5, 0.5), T_BONE, (0, -15, 0)), ((0.25, 1.08, 0.0), (5.37, 0.5, 0.5), T_BONE, (0, 49, 0)),
           ((-1.0, 0.93, 2.0), (3.67, 0.4, 0.4), T_BONE, (0, -34, 0))]
    for x in (-3.0, -2.2, -1.4):
        ctx.append(((x, 1.08, -2.2), (0.3, 2.2, 0.3), T_BONE, (0, 0, 25)))
    for (x, y, z, s) in ((-3, 0.58, -1, 0.85), (0.5, 0.58, 3, 0.68), (2.5, 0.68, 0.5, 0.85), (-1.5, 0.68, 2, 0.85), (2, 1.48, -2, 0.85)):
        ctx.append(((x, y, z), (s, s, s), T_BONE, (0, 0, 0)))
    g1 = context_boxes(ctx, col) + [put("tundra_props__skull"), put("tundra_props__skeleton_ice"),
                                     put("tundra_snow__cap", V((0.2, 2.55, 0.6)), _mat3(M_ID) @ Matrix(((3.2, 0, 0), (0, 0.45, 0), (0, 0, 2.6))))]
    # 2 snowman A (offset 14) and B (offset 24)
    g2 = []
    for ox, balls, nose, ns in ((14, (("snowball", (0, 1.9, 0), 2.2), ("snowball_shade", (0, 4.7, 0), 1.65), ("snowball", (0, 6.9, 0), 1.2)), (0, 6.9, -0.9), 1.0),
                                (24, (("snowball_shade", (0, 1.5, 0), 1.8), ("snowball", (0.15, 3.8, 0), 1.35), ("snowball", (0.35, 5.6, 0), 1.0)), (0.35, 5.6, -0.7), 0.86)):
        o = V((ox, 0, 0))
        for i, (nm, c, s) in enumerate(balls):
            g2.append(put(f"tundra_props__{nm}", o + V(c), euler_matrix([0, 40 * i, 0]), s))
        g2.append(put("tundra_props__carrot", o + V(nose), None, ns))
    g2 += context_boxes([((14, 8.0, 0), (2.7, 0.3, 2.7), "#4E566E", (0, 0, 0)), ((14, 8.9, 0), (1.8, 1.6, 1.8), "#4E566E", (0, 0, 0)),
                         ((24.45, 6.9, 0), (1.7, 1.3, 1.7), "#5C626E", (0, 0, 8)), ((24.25, 4.85, 0), (2.1, 0.5, 2.1), "#BAAAEC", (0, 0, 0))], col)
    # 3 weapon rack (offset 36)
    o = V((36, 0, 0))
    g3 = context_boxes([((36, 0.25, 0), (8, 0.5, 2.4), "#5C4236", (0, 0, 0)), ((32.4, 3, 0.6), (0.6, 6, 0.6), "#5C4236", (0, 0, 0)),
                        ((39.6, 3, 0.6), (0.6, 6, 0.6), "#5C4236", (0, 0, 0)), ((36, 2.2, 0.6), (7.8, 0.4, 0.4), "#865C42", (0, 0, 0)),
                        ((36, 5.0, 0.6), (7.8, 0.4, 0.4), "#865C42", (0, 0, 0)), ((33.8, 3.2, 0.1), (0.5, 4.4, 0.15), "#F5F6FA", (-9, 0, 0)),
                        ((36.7, 5.1, -0.2), (1.7, 1.5, 0.3), "#5C626E", (-9, 0, 0)), ((38.2, 3.9, 0.1), (0.25, 7.4, 0.25), "#703E26", (-9, 0, 0)),
                        ((38.2, 7.9, -0.55), (0.6, 1.3, 0.2), "#7080CC", (-9, 0, 0))], col)
    g3.append(put("tundra_props__rack_ice", o))
    for x in (-1.0, 1.2, 3.0):
        g3.append(put("tundra_ice__icicle", o + V((x, 4.8, 0.6)), None, 0.5))
    out = os.path.join(P.PREVIEW_DIR, "tundra_props_facets.png")
    return render_sheet("tprops", [(g1, [(-30, 25)]), (g2, [(-15, 10)]), (g3, [(-20, 12)])], None, out)


def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    report = []
    for obj, fn, prev in (("rebirth_altar", rebirth_altar, preview_altar), ("ship", ship, preview_ship),
                          ("golem", golem, preview_golem), ("canyon_gate", canyon_gate, preview_canyon),
                          ("red_rock", red_rock, preview_red_rock_all), ("monuments", monuments, preview_monuments),
                          ("props", desert_props, preview_props),
                          ("jungle", jungle_buildings, preview_jungle),
                          ("jungle_gates", jungle_gates, preview_jungle_gates),
                          ("jungle_ruins", jungle_ruins, preview_jungle_ruins),
                          ("jungle_totems", jungle_totems, preview_jungle_totems),
                          ("jungle_decor", jungle_decor, preview_jungle_decor),
                          ("jungle_nature", jungle_nature, preview_jungle_nature),
                          ("batch4", batch4, preview_batch4),
                          ("tundra_buildings", tundra_buildings, preview_tundra_buildings),
                          ("tundra_gates", tundra_gates, preview_tundra_gates),
                          ("tundra_monuments", tundra_monuments, preview_tundra_monuments),
                          ("tundra_props", tundra_props, preview_tundra_props)):
        if only and obj not in only:
            continue
        pieces = fn()
        for pc in pieces:
            d = pc.data()
            report.append({"file": os.path.relpath(write_piece(pc), P.ROOT).replace("\\", "/"), "faces": d["faceCount"],
                           "rect": d["rectCount"], "size": d["size"], "bounds": d["bounds"], "problems": pc.check()})
        report.append({"preview": os.path.relpath(prev(pieces), P.ROOT).replace("\\", "/")})
    print("FACETS " + json.dumps(report))


if __name__ == "__main__":
    main()
