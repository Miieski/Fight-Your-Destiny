"""Fight Your Destiny - FACET DATA of the organic accents of props batch 2 (owner task 2026-10-19).

Studio cannot import FBX here, so Agent B builds these few organic pieces from their faces: each face becomes a thin
part (a rectangle = 1 Part, any other quad / triangle = wedges), extruded INWARD by the face's thickness t, then
unioned. Everything else of batch 2 is built from parts with the fountain / well recipe (docs/prop_texture_guide.md
section A). Budget: at most 300 faces per piece; rectangles are flagged "rect": true.

    blender --background --factory-startup --python tools/blender/fyd_facets.py [-- rebirth_altar ship golem canyon_gate red_rock]

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


def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    report = []
    for obj, fn, prev in (("rebirth_altar", rebirth_altar, preview_altar), ("ship", ship, preview_ship),
                          ("golem", golem, preview_golem), ("canyon_gate", canyon_gate, preview_canyon),
                          ("red_rock", red_rock, preview_red_rock_all)):
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
