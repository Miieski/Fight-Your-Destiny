"""Prop recipes (docs/model_upgrade_brief.txt section 9). One function per prop id -> fyd_props.Prop.

All numbers are studs in Roblox model space (x right, y up, z back, front -Z, origin = ground contact under the
Studio pivot). The current Studio sizes come from docs/prop_inventory.md (Agent B).
"""
import math
import random

from mathutils import Vector

import fyd_props as P

TAN40, SIN40, COS40 = math.tan(math.radians(40)), math.sin(math.radians(40)), math.cos(math.radians(40))


# ------------------------------------------------------------------------------------------------
# 16 WELL - kit MapAssets.Hub.Well_A: bbox 11.40 x 13.20 x 9.60, pivot bottom centre, front -Z.
# Today: wall cyl 9.0 dia x 3.4, rim cyl 9.6 x 0.7 (top 3.85), water 7.0 dia (top 3.87), posts 0.9 at x +-4.2,
# crank y 8.0 along X (handle at +X), bucket 1.6 at y 5.0, red gable roof along X (eaves z +-4 / y 9.8, ridge 13.2).
# ------------------------------------------------------------------------------------------------
def well():
    p = P.Prop("well", photo="16_well.png", size=(11.4, 13.2, 9.6), budget=3500, view=(-30, 9), view2=(145, 24),
               notes="kit MapAssets.Hub.Well_A; Hub.Decor.Village.Well_A; test Lineup.Hub.Well_A")
    rng = random.Random(16)
    stones = p.mesh("Stones", "Stone", "Stone")
    rim = p.mesh("RimStones", "Stone", "StoneDark")
    mortar = p.mesh("Mortar", "Stone", "StoneMortar", shadow=False)
    moss = p.mesh("Moss", "Moss", "Moss", shadow=False)
    water = p.mesh("Water", "Water", "Water")
    timber = p.mesh("Timber", "Wood", "WoodDark")
    roof = p.mesh("Roof", "Wood", "RoofRed")
    bucket = p.mesh("Bucket", "Wood", "WoodMid", shadow=False)
    iron = p.mesh("Iron", "Iron", "Iron", shadow=False)
    rope = p.mesh("Rope", "Rope", "Rope", shadow=False)

    # --- stone ring: 3 courses of 12 irregular stones (running bond), mortar behind the joints -------------
    R_OUT, R_IN, WALL_TOP = 4.5, 3.65, 3.15
    courses = [(0.0, 1.05), (1.05, 2.10), (2.10, WALL_TOP)]
    for k, (y0, y1) in enumerate(courses):
        widths = [30.0 * (1 + rng.uniform(-0.22, 0.22)) for _ in range(12)]
        scale = 360.0 / sum(widths)
        a = k * 15.0 + rng.uniform(-4, 4)
        for w in widths:
            w *= scale
            stones.arc_block(R_IN - rng.uniform(0.0, 0.05), R_OUT + rng.uniform(-0.04, 0.07), a + 0.55, a + w - 0.55,
                             y0 + 0.025 - (0.06 if k == 0 else 0.0), y1 - 0.025, segs=1, jit=0.03,
                             tone=rng.uniform(0.86, 1.0))
            a += w
    # mortar core (visible in the joints) and the dark bottom of the shaft (seen through the water)
    mortar.ring((0, 1.6, 0), 3.69, 4.24, 3.2, segs=24, faces=("outer", "inner"), tone=0.95)
    mortar.cyl((0, 0.15, 0), (0, 0.3, 0), 3.7, segs=12, smooth=False, bevel=0, caps=(False, True))
    # rim capstones (darker, as today), 5 per side, a gap where each post rises
    for side in (0, 180):
        a = side + 6.0
        for i in range(5):
            w = 168.0 / 5
            rim.arc_block(3.45, 4.8 + rng.uniform(-0.03, 0.04), a + 0.5, a + w - 0.5, WALL_TOP + 0.02,
                          3.85 + rng.uniform(-0.03, 0.02), segs=1, jit=0.025, bevel_top_inner=True,
                          tone=rng.uniform(0.88, 1.0))
            a += w
    # flat footing stones under the posts
    for x in (-4.75, 4.75):
        stones.box((x, 0.1, 0), (1.3, 0.32, 1.25), rot=(0, rng.uniform(-8, 8), 0), jit=0.03, drop=((0, -1, 0),))
    # moss: low flat cushions half sunk into the foot of the wall, and two small tufts in joints
    for t_deg in (28, 75, 118, 205, 248, 292, 332):
        t = math.radians(t_deg + rng.uniform(-8, 8))
        r = 4.42 + rng.uniform(0.0, 0.06)
        moss.ico((r * math.cos(t), 0.02, r * math.sin(t)), rng.uniform(0.75, 1.0), scale=(1.5, 0.3, 0.42),
                 rot=(0, 90 - math.degrees(t), 0), jit=0.08, tone=rng.uniform(0.78, 0.92))
    for t_deg, y in ((-128, 1.05), (62, 2.1)):
        t = math.radians(t_deg)
        moss.ico((4.43 * math.cos(t), y, 4.43 * math.sin(t)), 0.4, scale=(1.4, 0.4, 0.25),
                 rot=(0, 90 - t_deg, 0), jit=0.06, tone=0.85)

    # --- water: translucent cyan surface 0.4 below the capstones ---------------------------------------
    water.cyl((0, 3.33, 0), (0, 3.45, 0), 3.72, segs=16, smooth=False, bevel=0)

    # --- posts, tie beams, rafters, king posts, ridge beam (all WoodDark, as today) --------------------
    for x in (-4.75, 4.75):
        timber.beam((x, -0.05, 0), (x, 9.6, 0), 0.88, 0.88, up=(0, 0, 1), taper=0.93)
        timber.beam((x, 9.725, -3.45), (x, 9.725, 3.45), 0.5, 0.45)                       # tie beam
        timber.beam((x, 9.9, 0), (x, 12.55, 0), 0.4, 0.4, up=(0, 0, 1))                   # king post
        for s in (-1, 1):                                                                  # rafters under the board
            za, zb = 3.6 * s, 0.15 * s
            timber.beam((x, 12.615 - 3.6 * TAN40, za), (x, 12.615 - 0.15 * TAN40, zb), 0.35, 0.35, bevel=0)
    timber.beam((-6.0, 12.64, 0), (6.0, 12.64, 0), 0.4, 0.4)                               # ridge beam

    # --- roof: boards, 4 rows of shingles per side, ridge cap, bargeboards ------------------------------
    YR, LS = 13.0, 5.4   # apex of the board top surface, slope length

    def roof_point(x, u, h, s):
        """x along the ridge, u = slope distance from the apex, h = offset along the roof normal, s = side."""
        return (x, YR - u * SIN40 + h * COS40, s * (u * COS40 + h * SIN40))

    for s in (-1, 1):
        n = (0, COS40, s * SIN40)
        timber.beam(roof_point(-6.0, LS / 2, -0.06, s), roof_point(6.0, LS / 2, -0.06, s), LS, 0.12, up=n)   # board
        rows = [(0.0, 1.6), (1.35, 1.6), (2.7, 1.6), (4.05, 1.35)]  # (start from the eave, length)
        for i, (a0, length) in enumerate(rows):
            u_low, u_high = LS - a0, LS - a0 - length
            if i % 2 == 0:
                spans = [(-6.0 + 1.5 * j, -4.5 + 1.5 * j) for j in range(8)]
            else:
                spans = [(-6.0, -5.25)] + [(-5.25 + 1.5 * j, -3.75 + 1.5 * j) for j in range(7)] + [(5.25, 6.0)]
            for xa, xb in spans:
                xc = (xa + xb) / 2 + rng.uniform(-0.03, 0.03)
                lift = rng.uniform(0.07, 0.11)
                top = roof_point(xc, u_high, 0.055, s)
                low = roof_point(xc + rng.uniform(-0.04, 0.04), u_low + 0.06, 0.055 + lift, s)
                # the eave row overhangs the board: it keeps its underside (Roblox meshes are single-sided)
                roof.beam(top, low, (xb - xa) - 0.06, 0.1, up=n, bevel=0, drop=() if i == 0 else ((0, -1, 0),),
                          tone=rng.uniform(0.88, 1.0))
        roof.beam(roof_point(-6.1, 0.3, 0.2, s), roof_point(6.1, 0.3, 0.2, s), 0.62, 0.12, up=n, tone=0.84)  # ridge cap
        for x in (-6.07, 6.07):  # bargeboards along the gable edges
            timber.beam(roof_point(x, 0.05, 0.08, s), roof_point(x, LS + 0.05, 0.08, s), 0.15, 0.34, up=n, bevel=0)

    # --- winch: axle through the posts, drum, wound rope, iron crank with a wooden grip (+X, as today) --
    timber.cyl((-5.42, 8.0, 0), (5.42, 8.0, 0), 0.22, segs=8)
    timber.cyl((-1.6, 8.0, 0), (1.6, 8.0, 0), 0.45, segs=10)
    for i in range(5):  # rope wound on the drum: 5 turns, alternately proud, so it reads as coils
        xa = -1.1 + i * 0.42
        rope.cyl((xa, 8.0, 0), (xa + 0.4, 8.0, 0), 0.55 + (0.035 if i % 2 else 0.0), segs=8, bevel=0,
                 caps=(i == 0, i == 4), spin=11.25 * i)
    iron.cyl((5.25, 8.0, 0), (5.45, 8.0, 0), 0.26, segs=8, bevel=0)
    iron.beam((5.5, 8.08, 0), (5.5, 7.08, 0), 0.26, 0.12, up=(1, 0, 0))
    timber.cyl((5.5, 7.16, 0), (6.08, 7.16, 0), 0.12, segs=6, bevel=0)
    for x in (-5.2, 5.2):  # iron bearing plates where the axle goes through the posts
        iron.box((x, 8.0, 0), (0.06, 0.62, 0.62), bevel=0, drop=((-1 if x > 0 else 1, 0, 0),))

    # --- rope and bucket (staves, bottom, 2 iron hoops, iron bail) -------------------------------------
    bx = 0.15
    rope.tube([(bx, 7.47, 0), (bx, 6.42, 0)], 0.07, segs=5)
    y_bot, y_top, r_bot, r_top = 4.25, 5.75, 0.66, 0.80
    for k in range(10):
        t = 2 * math.pi * (k + 0.5) / 10
        ca, sa = math.cos(t), math.sin(t)
        a = (bx + ca * (r_bot + 0.045), y_bot, sa * (r_bot + 0.045))
        b = (bx + ca * (r_top + 0.045), y_top, sa * (r_top + 0.045))
        bucket.beam(a, b, 2 * math.pi * r_bot / 10 - 0.03, 0.09, up=(ca, 0, sa), bevel=0, taper=1.2,
                    tone=rng.uniform(0.85, 1.0))
    bucket.cyl((bx, y_bot, 0), (bx, y_bot + 0.08, 0), r_bot + 0.02, segs=10, smooth=False, bevel=0)
    for yh in (4.5, 5.5):  # hoops sit ON the staves: stave outer face / cos(18 deg) (10-gon aligned with them)
        f = (yh - y_bot) / (y_top - y_bot)
        outer = r_bot + (r_top - r_bot) * f + 0.045 + 0.045 * (1 + 0.2 * f)
        r_in = outer / math.cos(math.radians(18)) + 0.005
        iron.ring((bx, yh, 0), r_in, r_in + 0.07, 0.14, segs=10, faces=("outer", "top", "bottom"), start=0.0)
    bail = [(bx + 0.86 * math.cos(math.radians(a)), 5.55 + 0.86 * math.sin(math.radians(a)), 0)
            for a in (0, 30, 60, 90, 120, 150, 180)]
    iron.tube(bail, 0.045, segs=4)

    # --- colliders (invisible Parts built by ApplyPropMeshes; same solids as today, posts at the new place)
    p.collider("Cylinder", (0, 1.7, 0), (3.4, 9.0, 9.0), (0, 0, 90), name="well_Collider_Wall")
    p.collider("Cylinder", (0, 3.5, 0), (0.7, 9.6, 9.6), (0, 0, 90), name="well_Collider_Rim")
    for x, nm in ((-4.75, "PostL"), (4.75, "PostR")):
        p.collider("Block", (x, 4.775, 0), (0.8, 9.65, 0.8), name=f"well_Collider_{nm}")
    p.collider("Cylinder", (0, 8.0, 0), (10.7, 0.6, 0.6), name="well_Collider_Axle")
    p.collider("Cylinder", (bx, 5.0, 0), (1.5, 1.7, 1.7), (0, 0, 90), name="well_Collider_Bucket")
    p.collider("Wedge", (0, 11.265, -2.07), (12.0, 3.47, 4.14), (0, 0, 0), name="well_Collider_RoofFront")
    p.collider("Wedge", (0, 11.265, 2.07), (12.0, 3.47, 4.14), (0, 180, 0), name="well_Collider_RoofBack")
    p.attach("WaterSurface", (0, 3.45, 0))
    p.attach("BucketBottom", (bx, y_bot, 0))
    p.attach("WinchAxis", (0, 8.0, 0))
    return p


# ------------------------------------------------------------------------------------------------
# 17 CHEST - kit MapAssets.Common.Chest_A: bbox 4.40 x 3.48 x 3.07 (placed copies 4.5 wide), pivot bottom centre,
# lock on -Z. Today: base 4.4 x 2.0 x 2.8 (WoodMid), half-cylinder lid r 1.4 along X at y 2.0 (WoodDark), gold bands
# at x +-1.7 (straight on the base, round on the lid), gold lock 0.8 x 1.0 at (0, 1.9, -1.45).
# ------------------------------------------------------------------------------------------------
def chest():
    p = P.Prop("chest", photo="17_chest.png", size=(4.4, 3.48, 3.07), budget=1500, view=(-32, 14), view2=(150, 28),
               notes="kit MapAssets.Common.Chest_A; Hub 2, Plains_2 2, Plains_4 1; test Lineup.Common.Chest_A")
    rng = random.Random(17)
    body = p.mesh("Body", "Wood", "WoodMid")
    lid = p.mesh("Lid", "Wood", "WoodDark")
    gold = p.mesh("Bands", "Gold", "Gold", shadow=False)
    iron = p.mesh("Iron", "Iron", "Iron", shadow=False)
    hole = p.mesh("Keyhole", "Plain", "#1E1714", shadow=False)
    W, D, H, R, T = 2.2, 1.4, 2.0, 1.4, 0.14  # half width, half depth, body height, lid radius, plank thickness
    # body: 3 horizontal planks per wall (front / back between the side walls)
    for k in range(3):
        y0 = 0.02 + k * 0.66
        yc, hh = (y0 + 0.32, 0.64) if k < 2 else (y0 + 0.34, 0.68)  # the top plank tucks under the lid
        for s in (-1, 1):
            body.box((0, yc, s * (D - T / 2)), (2 * W - 2 * T - 0.02, hh, T), grain="x", bevel="long",
                     tone=rng.uniform(0.88, 1.0))
            body.box((s * (W - T / 2), yc, 0), (T, hh, 2 * D), grain="z", bevel="long", tone=rng.uniform(0.88, 1.0))
    # lid: 7 staves around the half cylinder + two half-disc ends
    n = 7
    step = 180.0 / n
    for k in range(n):
        t = math.radians(-90 + (k + 0.5) * step)
        d = (0, math.cos(t), math.sin(t))
        rc = R - T / 2
        lid.beam((-(W - T), H + rc * d[1], rc * d[2]), ((W - T), H + rc * d[1], rc * d[2]),
                 2 * rc * math.tan(math.radians(step / 2)) - 0.03, T, up=d, tone=rng.uniform(0.86, 1.0))
    half = [(R * math.sin(math.radians(-90 + i * step)), R * math.cos(math.radians(-90 + i * step))) for i in range(n + 1)]
    for s in (-1, 1):
        lid.prism(half, T, c=(s * (W - T / 2), H, 0), rot=(0, -90, 0), bevel=0.03)
    # hidden fill: the chest looks full through the plank gaps (no light leaking into an empty box)
    body.box((0, 1.0, 0), (2 * W - 2 * T - 0.04, 1.96, 2 * D - 2 * T - 0.04), bevel=0, tone=0.6, drop=((0, -1, 0),))
    lid.cyl((-(W - T - 0.02), H, 0), ((W - T - 0.02), H, 0), R - T - 0.02, segs=8, bevel=0, smooth=False, tone=0.6)
    # gold bands: lid arcs sitting ON the stave facets (vertices at the stave corners), straps on front and back
    r_in = (R + 0.005) / math.cos(math.radians(step / 2))
    for x in (-1.55, 1.55):
        gold.arc_block(r_in, r_in + 0.07, -90, 90, -0.2, 0.2, c=(x, H, 0), segs=n, rot=(0, 0, 90), drop_bottom=False)
        for s in (-1, 1):
            gold.box((x, H / 2, s * (D + 0.03)), (0.4, H, 0.06), bevel=0, drop=((0, 0, -s),))
        for y in (0.4, 1.0, 1.6):  # rivets on the front straps
            gold.cyl((x, y, -D - 0.05), (x, y, -D - 0.11), 0.06, 0.035, segs=4, caps=(False, True), bevel=0,
                     smooth=False)
        for a in (-64, -13):  # rivets on the lid bands (front side)
            t = math.radians(a)
            rr = r_in + 0.06
            gold.cyl((x, H + rr * math.cos(t), rr * math.sin(t)), (x, H + (rr + 0.06) * math.cos(t), (rr + 0.06) * math.sin(t)),
                     0.06, 0.035, segs=4, caps=(False, True), bevel=0, smooth=False)
    # lock plate, hasp from the lid, keyhole
    gold.box((0, 1.72, -D - 0.035), (0.66, 0.8, 0.07), bevel="all", drop=((0, 0, 1),))
    gold.box((0, 2.12, -D - 0.06), (0.26, 0.5, 0.05), bevel=0, drop=((0, 0, 1),))
    hole.box((0, 1.79, -D - 0.075), (0.13, 0.13, 0.02), bevel=0, drop=((0, 0, 1),))
    hole.box((0, 1.67, -D - 0.075), (0.06, 0.2, 0.02), bevel=0, drop=((0, 0, 1),))
    # iron corner protections (L plates on each vertical edge) and two hinges at the back
    for sx in (-1, 1):
        for sz in (-1, 1):
            iron.box((sx * (W - 0.12), H / 2, sz * (D + 0.025)), (0.24, H, 0.05), bevel=0, drop=((0, 0, -sz),))
            iron.box((sx * (W + 0.025), H / 2, sz * (D - 0.12)), (0.05, H, 0.24), bevel=0, drop=((-sx, 0, 0),))
    for x in (-1.0, 1.0):
        iron.box((x, 1.72, D + 0.025), (0.3, 0.52, 0.05), bevel=0, drop=((0, 0, -1),))
        iron.cyl((x - 0.18, H, D + 0.06), (x + 0.18, H, D + 0.06), 0.08, segs=6, bevel=0)
        t = math.radians(-90 + (n - 0.5) * step)  # flat on the last (back) stave's facet
        d = Vector((0, math.cos(t), math.sin(t)))
        tan = Vector((0, -math.sin(t), math.cos(t)))
        cpt = Vector((x, H, 0)) + d * (R + 0.025)
        iron.beam(tuple(cpt - tan * 0.28), tuple(cpt + tan * 0.22), 0.3, 0.05, up=tuple(d), bevel=0)
    p.collider("Block", (0, 1.0, 0), (4.4, 2.0, 2.8), name="chest_Collider_Base")
    p.collider("Cylinder", (0, 2.0, 0), (4.4, 2.8, 2.8), name="chest_Collider_Lid")
    p.attach("Sparkle", (0, 1.72, -1.52))
    p.attach("LidTop", (0, 3.47, 0))
    return p


# ------------------------------------------------------------------------------------------------
# 05 ROWBOAT - kit MapAssets.Plains.Rowboat_Wreck: bbox 14.10 x 4.98 x 11.14, bbox centre (1.43, 2.49, 0.37), pivot
# on the ground (not under the bbox centre). Today: bottom 9 x 3.6, sides 2.4 high (one broken), bow wedges at x 6.14
# (bow toward +X), stern board, 2 benches, a loose plank, the whole boat rolled 22 deg about its long axis; the oar
# (shaft 7.57 + blade 2.0) lies beside it. No per-part CFrames in the inventory: the layout is rebuilt from the bbox
# and photo 05 (bow on the left = camera on -Z, the front: the oar lies on the -Z side, the boat leans toward it and
# its broken side is the near, low one).
# ------------------------------------------------------------------------------------------------
HULL_L = 13.7   # 2026-10-19: as long as today's hull (x -5.62 .. 8.48 with the stem and transom)


def _hull(s):
    """Hull lines at station s (0 stern .. 1 bow tip): x, half-breadth at the sheer B, at the bottom b, keel y, sheer H."""
    x = -HULL_L / 2 + HULL_L * s
    if s <= 0.4:
        B = 2.1 + 0.42 * math.sin(math.pi / 2 * s / 0.4)
    else:
        B = 2.52 * (1 - ((s - 0.4) / 0.6) ** 2)
    b = 0.6 * B
    yk = 0.25 + (1.4 * ((s - 0.75) / 0.25) ** 2 if s > 0.75 else 0.0)
    H = 3.3 + (0.3 * (0.2 - s) / 0.2 if s < 0.2 else 0.0) + 1.1 * max(0.0, (s - 0.6) / 0.4) ** 2
    return x, B, b, yk, H


def _hull_point(s, t, side, out=0.0, dy=0.0):
    x, B, b, yk, H = _hull(s)
    w = b + (B - b) * math.sin(t * math.pi / 2) + out * (B / 2.52)
    return (x, yk + (H - yk) * t + dy, side * w)


def rowboat():
    p = P.Prop("rowboat", photo="05_rowboat.png", size=(14.10, 4.98, 11.14), budget=2500, view=(25, 35),
               view2=(-150, 22), notes="kit MapAssets.Plains.Rowboat_Wreck; Hub Harbor 1 (pivot y -2.3), Plains_2 1, "
                                      "Abyss_2 4 recoloured; boat + oar = 2 objects of one model; layout rebuilt "
                                      "from bbox + photo (compare in the Studio preview)")
    rng = random.Random(5)
    hull = p.mesh("Hull", "Wood", "WoodMid")
    timber = p.mesh("Timber", "Wood", "WoodDark")
    light = p.mesh("Thwarts", "Wood", "WoodLight")
    iron = p.mesh("Iron", "Iron", "Iron", shadow=False)
    rope = p.mesh("Rope", "Rope", "Rope", shadow=False)
    stations = [0.0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.74, 0.84, 0.92, 1.0]
    # clinker strakes: 4 per side, each overlapping the one below on the outside
    for side in (-1, 1):
        for k in range(4):
            t0 = k / 4 - (0.05 if k else 0.0)
            t1 = (k + 1) / 4
            out = 0.1 * k    # clinker lap step (reads from both sides)
            pieces = [stations]
            if side == -1 and k >= 2:  # the wreck: a broken gap in the two top strakes of the near (-Z) side
                pieces = [[0.0, 0.12, 0.25, ("break", 0.36, 0.31)], [("break", 0.6, 0.66), 0.74, 0.84, 0.92, 1.0]]
            for piece in pieces:
                rows = []
                for st in piece:
                    if isinstance(st, tuple):
                        rows.append([_hull_point(st[1], t0, side, out), _hull_point(st[2], t1, side, out)])
                    else:
                        rows.append([_hull_point(st, t0, side, out), _hull_point(st, t1, side, out)])
                if side == -1:
                    rows = rows[::-1]  # keep (du x dv) pointing outward on both sides
                hull.grid(rows, thickness=0.12, sides=("top", "bottom", "u0", "u1", "v0", "v1"), smooth=False,
                          tone=(1.0 if k % 2 == 0 else 0.83) - rng.uniform(0.0, 0.04))
    # flat bottom boards, transom, keel and stem
    bottom = [[(_hull(s)[0], _hull(s)[3], z * _hull(s)[2]) for z in (1.0, 0.0, -1.0)] for s in stations[:8]]
    timber.grid(bottom, thickness=0.1, sides=("top", "bottom", "u0", "u1", "v0", "v1"), smooth=False)
    poly = [(_hull_point(0.0, t, 1)[2], _hull_point(0.0, t, 1)[1]) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
    poly += [(-a, b) for a, b in reversed(poly)]
    timber.prism(poly, 0.16, c=(_hull(0.0)[0] - 0.02, 0, 0), rot=(0, -90, 0), bevel=0.03)
    timber.beam((-6.2, 0.12, 0), (_hull(0.75)[0], 0.12, 0), 0.25, 0.25)
    timber.beam((_hull(0.75)[0], 0.12, 0), (_hull(0.92)[0], _hull(0.92)[3] - 0.05, 0), 0.25, 0.25, extend=0.1)
    timber.beam((_hull(0.92)[0], _hull(0.92)[3] - 0.05, 0), (_hull(1.0)[0] + 0.12, _hull(1.0)[4] + 0.12, 0), 0.3, 0.3,
                extend=0.08)
    # ribs inside, gunwales
    for s in (0.25, 0.42, 0.58, 0.72):
        pts = [_hull_point(s, t, -1, -0.13, 0.1 if t == 0 else 0.0) for t in (1.0, 0.5, 0.0)]
        pts += [_hull_point(s, t, 1, -0.13, 0.1 if t == 0 else 0.0) for t in (0.0, 0.5, 1.0)]
        timber.tube(pts, 0.07, segs=4, smooth=False)
    for side in (-1, 1):
        runs = [stations] if side == 1 else [[0.0, 0.12, 0.25, 0.31], [0.66, 0.74, 0.84, 0.92, 1.0]]
        for run in runs:
            timber.tube([_hull_point(s, 1.0, side, 0.12, 0.04) for s in run], 0.08, segs=4, smooth=False)
    # thwarts, oarlocks, rope coil
    for s in (0.22, 0.45, 0.68):
        x, B, b, yk, H = _hull(s)
        y = H - 0.45
        t = (y - yk) / (H - yk)
        w = b + (B - b) * math.sin(t * math.pi / 2) - 0.1
        light.box((x, y, 0), (0.8, 0.13, 2 * w), grain="z", bevel="long", tone=rng.uniform(0.9, 1.0))
    for side in (-1, 1):
        x, y, z = _hull_point(0.28, 1.0, side, 0.12, 0.12)
        iron.box((x, y + 0.02, z), (0.22, 0.08, 0.2), bevel=0, drop=((0, -1, 0),))
        for dx in (-0.08, 0.08):
            iron.box((x + dx, y + 0.18, z), (0.05, 0.3, 0.06), bevel=0, drop=((0, -1, 0),))
    xr, _, _, ykr, _ = _hull(0.8)
    rope.torus((xr, ykr + 0.12, 0.1), 0.38, 0.065, segs=8, rsegs=3)
    rope.torus((xr - 0.03, ykr + 0.24, 0.08), 0.32, 0.065, segs=8, rsegs=3)
    rope.tube([(xr - 0.3, ykr + 0.28, 0.25), (xr - 0.9, ykr + 0.35, 0.5), (_hull(0.68)[0] + 0.3, _hull(0.68)[4] - 0.3, 0.6)],
              0.06, segs=4)
    # lay the boat down: roll 22 deg about its long axis (top toward -Z, the front), resting on its bilge, then put the
    # hull's bbox centre where today's is (x 1.43, z -0.64; Agent B's measures of the old model)
    R = Matrix_rot_x(-22)
    boat = (hull, timber, light, iron, rope)
    pts = [R @ Vector(v) for m in boat for v in m.verts]
    lowest = min(q.y for q in pts)
    cx = (min(q.x for q in pts) + max(q.x for q in pts)) / 2
    cz = (min(q.z for q in pts) + max(q.z for q in pts)) / 2
    M = P.Matrix.Translation(Vector((1.43 - cx, -lowest, -0.64 - cz))) @ R
    for m in boat:
        m.transform(M)
    # loose plank on the ground behind the boat (+Z side)
    light.box((-2.6, 0.1, 4.6), (3.6, 0.2, 0.9), rot=(0, -14, 2), grain="x", bevel="long", tone=0.9)
    # the oar (a second object): LEANS on the low (-Z) gunwale, blade tip just above the ground, inside today's oar
    # extent (x -4.03 .. 5.26): only the tip comes near sloped ground, nothing lies flat to sink
    oar = p.mesh("Oar", "Wood", "WoodDark", shadow=False)
    blade = p.mesh("OarBlade", "Wood", "WoodLight", shadow=False)
    rest = M @ Vector(_hull_point(0.2, 1.0, -1, 0.12, 0.04))          # top of the near gunwale, by the stern
    a = rest + Vector((0.0, 0.25, -0.12))                             # the shaft lies on it (gunwale + radii)
    tip = Vector((5.1, 0.08, -4.55))
    d = (tip - a).normalized()
    a = a - d * 0.85                                                  # the grip end sticks out past the gunwale
    length = (tip - a).length
    b2 = a + d * (length - 2.05)                                      # blade root
    oar.cyl(tuple(a + d * 0.75), tuple(b2), 0.17, segs=6)
    oar.cyl(tuple(a), tuple(a + d * 0.78), 0.12, segs=6)                # grip
    w = d.cross(Vector((0, 1, 0))).normalized()                       # blade width: horizontal, across the oar
    n = d.cross(w)
    e = P.Matrix((d, w, n)).transposed().to_euler("ZYX")
    outline = [(0, -0.13), (0.45, -0.36), (1.6, -0.46), (1.95, -0.34), (2.05, 0), (1.95, 0.34), (1.6, 0.46),
               (0.45, 0.36), (0, 0.13)]
    blade.prism([(x - 1.0, y) for x, y in outline], 0.1, c=tuple(b2 + d * 1.0),
                rot=(math.degrees(e.x), math.degrees(e.y), math.degrees(e.z)), bevel=0.02, grain="x")
    hc = M @ Vector((0.0, 1.65, 0.0))
    p.collider("Block", tuple(hc), (HULL_L + 0.4, 3.4, 5.2), (-22, 0, 0), name="rowboat_Collider_Hull")
    o = P.Matrix((d, w, n)).transposed().to_euler("ZXY")              # Roblox Orientation (applied Z, X, then Y)
    p.collider("Cylinder", tuple((a + tip) / 2), (length, 0.34, 0.34),
               (round(math.degrees(o.x), 2), round(math.degrees(o.y), 2), round(math.degrees(o.z), 2)),
               name="rowboat_Collider_Oar")
    p.attach("Bow", tuple(M @ Vector((HULL_L / 2, 3.6, 0.0))))
    return p


def Matrix_rot_x(deg):
    return P.Matrix.Rotation(math.radians(deg), 4, "X")


# ------------------------------------------------------------------------------------------------
# 06 MINECART - kit MapAssets.Plains.Minecart_A: bbox 5.12 x 6.24 x 6.61, pivot bottom centre, long axis Z.
# Today: floor 3.6 x 0.5 x 5.6 at y 1.5, flared sides (x +-2.1, roll 10) and ends (z +-2.9, pitch 8) 3 high, all Iron;
# wheels 1.5 dia x 0.5 at (+-1.6, 0.75, +-1.8) WoodDark (they sit on Rail_Section); ore load (96,92,110) + 2 Neon nuggets.
# ------------------------------------------------------------------------------------------------
def minecart():
    p = P.Prop("minecart", photo="06_minecart.png", size=(5.12, 6.24, 6.61), budget=2500, view=(-28, 32),
               view2=(150, 24), notes="kit MapAssets.Plains.Minecart_A (Toolbox attrs SourceAssetId/SourceCreator: keep); "
                                      "Plains_4 Mine 2; wheels keep today's centres for the rails")
    rng = random.Random(6)
    body = p.mesh("Body", "Riveted", "Iron")
    frame = p.mesh("Frame", "Iron", "IronWorn")
    run = p.mesh("Running", "Iron", "Iron", shadow=False)
    hubs = p.mesh("Hubs", "Wood", "WoodDark", shadow=False)
    ore = p.mesh("Ore", "Stone", "CaveRock")
    glow = p.mesh("Crystals", "Glow", "OreGold", shadow=False)
    Y0, Y1 = 1.35, 4.5            # wall bottom / top
    XB, XT, ZB, ZT = 1.95, 2.3, 2.75, 3.1   # half sizes at the bottom / top of the flared walls
    tilt = math.degrees(math.atan2(XT - XB, Y1 - Y0))
    hgt = math.hypot(Y1 - Y0, XT - XB)
    body.box((0, 1.45, 0), (2 * XB - 0.1, 0.3, 2 * ZB - 0.1), bevel=0.04)                      # floor
    for s in (-1, 1):
        body.box((s * (XB + XT) / 2, (Y0 + Y1) / 2, 0), (0.14, hgt, 2 * ZB), rot=(0, 0, -s * tilt),
                 taper=(1.0, ZT / ZB), bevel=0.05)                                              # sides
        body.box((0, (Y0 + Y1) / 2, s * (ZB + ZT) / 2), (2 * XB, hgt, 0.14), rot=(s * tilt, 0, 0),
                 taper=(XT / XB, 1.0), bevel=0.05)                                              # ends

    def wall(f):  # half sizes of the box at height fraction f
        return XB + (XT - XB) * f, ZB + (ZT - ZB) * f

    # rim, two bands, corner posts (worn iron)
    for s in (-1, 1):
        frame.beam((s * (XT + 0.04), Y1 + 0.05, -(ZT + 0.15)), (s * (XT + 0.04), Y1 + 0.05, ZT + 0.15), 0.22, 0.22)
        frame.beam((-(XT + 0.15), Y1 + 0.05, s * (ZT + 0.04)), (XT + 0.15, Y1 + 0.05, s * (ZT + 0.04)), 0.22, 0.22)
    for yb in (2.3, 3.55):
        f = (yb - Y0) / (Y1 - Y0)
        wx, wz = wall(f)
        for s in (-1, 1):
            frame.box((s * (wx + 0.09), yb, 0), (0.05, 0.24, 2 * wz + 0.1), rot=(0, 0, -s * tilt), bevel=0,
                      drop=((-s, 0, 0),))
            frame.box((0, yb, s * (wz + 0.09)), (2 * wx + 0.1, 0.24, 0.05), rot=(s * tilt, 0, 0), bevel=0,
                      drop=((0, 0, -s),))
    for sx in (-1, 1):
        for sz in (-1, 1):
            frame.beam((sx * (XB + 0.03), Y0 - 0.05, sz * (ZB + 0.03)), (sx * (XT + 0.03), Y1, sz * (ZT + 0.03)), 0.22, 0.22,
                       up=(sx, 0, sz))
    # running gear: axles, bearings, flanged iron wheels with wooden hubs (today's centres), coupler at -Z
    for z in (-1.8, 1.8):
        run.cyl((-1.95, 0.75, z), (1.95, 0.75, z), 0.12, segs=6, bevel=0)
        for x in (-1.25, 1.25):
            run.box((x, 1.05, z), (0.3, 0.5, 0.45), bevel=0, drop=((0, 1, 0),))
        for s in (-1, 1):
            x = s * 1.6
            run.cyl((x - s * 0.14, 0.75, z), (x + s * 0.14, 0.75, z), 0.72, segs=12, bevel=0.04)          # tread
            run.cyl((x - s * 0.2, 0.75, z), (x - s * 0.13, 0.75, z), 0.8, segs=12, bevel=0, smooth=False)  # flange
            hubs.cyl((x + s * 0.1, 0.75, z), (x + s * 0.24, 0.75, z), 0.28, segs=8, bevel=0.03)
    run.box((0, 1.28, -(ZT + 0.12)), (0.32, 0.14, 0.62), bevel=0)
    run.torus((0, 1.28, -(ZT + 0.48)), 0.16, 0.05, segs=8, rsegs=3)
    # ore load: a rubble mound filling the box, rocks on top, glowing crystals
    ore.ico((0, 4.25, 0), 2.0, scale=(1.05, 0.5, 1.42), sub=2, jit=0.06)
    for x, y, z, r in ((-0.9, 4.95, -1.4, 0.55), (0.8, 5.0, -0.6, 0.6), (-0.3, 5.15, 0.6, 0.62), (1.0, 4.85, 1.7, 0.5),
                       (-1.2, 4.8, 1.9, 0.45), (0.2, 4.9, -2.2, 0.5)):
        ore.ico((x, y, z), r, scale=(1.0, 0.8, 1.0), sub=1, jit=0.15, tone=rng.uniform(0.8, 1.0),
                rot=(0, rng.uniform(0, 90), 0))
    for (x, z, ang, yaw, length, r) in ((-0.55, 0.15, 18, 30, 1.25, 0.24), (0.75, -0.95, 24, 200, 1.05, 0.22),
                                        (0.35, 1.25, 30, 110, 0.9, 0.15), (-0.95, -1.55, 26, 300, 0.8, 0.13)):
        base = Vector((x, 5.0, z))
        d = Vector((math.sin(math.radians(ang)) * math.cos(math.radians(yaw)), math.cos(math.radians(ang)),
                    math.sin(math.radians(ang)) * math.sin(math.radians(yaw))))
        top = base + d * length
        glow.cyl(tuple(base - d * 0.3), tuple(top), r, segs=6, bevel=0, smooth=False, caps=(True, False))
        glow.cyl(tuple(top), tuple(top + d * r * 1.6), r, 0.0, segs=6, bevel=0, smooth=False, caps=(False, False))
    p.collider("Block", (0, 2.95, 0), (4.6, 3.3, 6.2), name="minecart_Collider_Body")
    p.collider("Block", (0, 0.675, 0), (3.8, 1.35, 5.2), name="minecart_Collider_Wheels")
    p.attach("CrystalGlow", (0, 5.7, 0))
    p.attach("Coupler", (0, 1.28, -(ZT + 0.48)))
    return p


# ------------------------------------------------------------------------------------------------
# 07 SKULL_BONES - kit MapAssets.Plains.Bone_Pile_A: bbox 6.44 x 2.88 x 5.76, bbox centre (-0.30, 1.44, 0.46), pivot on
# the ground. Today: skull ball 2.4 at (0.3, 1.68, 0.2) facing -Z (eye sockets on -Z), jaw 1.5 x 0.9 x 1.3, 3 long bones
# (5.7 / 5.37 / 3.67 long) with ball ends, 3 ribs at z -2.2 leaning 20 / 30 / 40 deg. No per-part CFrames in the
# inventory: crossed bones under the skull, a third bone behind, ribs at the front on -X (photo 07 is a front view, so
# +X is on the image's left: the ribs on the right of the photo are at -X, leaning toward -X).
# ------------------------------------------------------------------------------------------------
def skull_bones():
    p = P.Prop("skull_bones", photo="07_skull_and_bones.png", size=(6.44, 2.88, 5.76), budget=1500, view=(-15, 24),
               view2=(160, 30), notes="kit MapAssets.Plains.Bone_Pile_A; Plains_4 8, Abyss_3 8 (recoloured), BossArenas 12; "
                                      "layout rebuilt from bbox + photo (compare in the Studio preview)")
    rng = random.Random(7)
    bone = p.mesh("Bones", "Bone", "Bone")
    aged = p.mesh("Aged", "Bone", "BoneAged", shadow=False)
    dark = p.mesh("Sockets", "Bone", "BoneSocket", shadow=False)
    sx, sy, sz = 0.3, 1.7, 0.2  # skull centre (today 0.3, 1.68, 0.2)

    def cranium(v):
        # flatter base, slightly longer back (occiput), narrower temples
        if v.y < -0.55:
            v.y = -0.55 + (v.y + 0.55) * 0.3
        if v.z > 0:
            v.z *= 1.08
        if 0.0 < v.y < 0.7 and abs(v.x) > 0.8:
            v.x *= 0.95
        return v

    bone.ico((sx, sy + 0.12, sz + 0.25), 1.18, scale=(0.95, 0.92, 1.05), sub=3, jit=0.0, deform=cranium)
    bone.box((sx, sy - 0.52, sz - 0.6), (1.0, 0.58, 0.66), taper=(1.28, 1.05), bevel="all", tone=0.95)     # maxilla
    for s in (-1, 1):
        bone.ico((sx + s * 0.37, sy + 0.42, sz - 0.8), 0.33, scale=(1.25, 0.42, 0.62), sub=1, jit=0.03,
                 rot=(0, 0, -s * 12))                                                                       # brow arcs
        bone.ico((sx + s * 0.68, sy - 0.2, sz - 0.6), 0.34, scale=(1.35, 0.6, 1.0), sub=1, jit=0.05)       # cheekbones
        dark.ico((sx + s * 0.37, sy + 0.1, sz - 0.86), 0.3, scale=(1.0, 0.92, 0.35), sub=1, jit=0.02)      # eye sockets
    dark.prism([(-0.13, 0.12), (0.13, 0.12), (0.0, -0.2)], 0.12, c=(sx, sy - 0.25, sz - 1.0))             # nasal cavity
    for i in range(6):  # upper teeth along the maxilla's front edge
        x = sx - 0.38 + i * 0.152
        aged.box((x, sy - 0.87, sz - 0.95), (0.13, 0.2, 0.14), bevel=0, drop=((0, 1, 0),), tone=rng.uniform(0.9, 1.0))
    # jaw: U-shaped mandible resting below the face, rami going up at the back, lower teeth
    jaw = [(sx + s * x, y, sz + z) for s, x, y, z in ((-1, 0.62, 1.32, 0.15), (-1, 0.62, 0.86, 0.05), (-1, 0.58, 0.76, -0.5),
                                                       (-1, 0.32, 0.7, -0.88), (1, 0.0, 0.68, -0.97), (1, 0.32, 0.7, -0.88),
                                                       (1, 0.58, 0.76, -0.5), (1, 0.62, 0.86, 0.05), (1, 0.62, 1.32, 0.15))]
    aged.tube(jaw, [0.11, 0.14, 0.15, 0.15, 0.16, 0.15, 0.15, 0.14, 0.11], segs=5, smooth=False)
    for i in range(6):
        x = sx - 0.34 + i * 0.136
        aged.box((x, 0.88, sz - 0.86), (0.12, 0.17, 0.13), bevel=0, drop=((0, -1, 0),), tone=rng.uniform(0.88, 1.0))
    # long bones: shaft + two lumpy condyles at each end (crossed under the skull + one behind)
    for a, b, r in (((2.6, 0.27, -1.0), (-2.6, 0.27, 1.5), 0.2), ((2.3, 0.27, 1.95), (-2.2, 0.27, -1.2), 0.2),
                    ((-1.0, 0.2, 3.0), (2.55, 0.2, 2.75), 0.16)):
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        side = d.cross(Vector((0, 1, 0))).normalized()
        bone.cyl(tuple(a + d * 0.3), tuple(b - d * 0.3), r, r * 0.85, segs=6, bevel=0, caps=(False, False))
        for end, sgn in ((a, 1), (b, -1)):
            for k in (-1, 1):
                c = end + d * sgn * 0.12 + side * k * r * 0.75 + Vector((0, 0.02, 0))
                aged.ico(tuple(c), r * 1.45, scale=(1.0, 0.9, 1.0), sub=1, jit=0.08, tone=rng.uniform(0.88, 1.0))
    # ribs: 5 curved ribs standing at the front (-X side), leaning toward -X like today's (20-40 deg)
    for i, (x, roll) in enumerate(((-0.75, 16), (-1.1, 22), (-1.45, 28), (-1.78, 34), (-2.08, 40))):
        pts = []
        for k in range(6):
            h = 2.3 * k / 5
            local = Vector((0.0, h, -0.38 * math.sin(math.pi * h / 2.3) + 0.15 * h / 2.3))
            rr = P.Matrix.Rotation(math.radians(roll), 3, "Z") @ local
            pts.append((x + rr.x, max(0.05, rr.y + 0.05), -2.2 + rr.z + rng.uniform(-0.05, 0.05)))
        bone.tube(pts, [0.12, 0.12, 0.11, 0.1, 0.09, 0.07], segs=5, tone=rng.uniform(0.9, 1.0))
    p.collider("Ball", (sx, sy, sz), (2.4, 2.4, 2.4), name="skull_bones_Collider_Skull")
    p.attach("Skull", (sx, sy + 1.2, sz))
    return p


# ------------------------------------------------------------------------------------------------
# 09 CLAM_PEARL - kit MapAssets.Plains.Shell_A: bbox 2.60 x 2.20 x 2.83, bbox centre (0, 1.10, 0.12), pivot bottom
# centre. Today: two pink (255,92,120) discs 2.6 dia x 0.4, the top one hinged open 42 deg at the back (+Z), a white
# pearl 0.8 at (0, 0.65, 0.2). CanCollide false, CastShadow false. Animated: the top valve opens / closes about 12 deg
# around the hinge (X axis through the "Hinge" attachment).
# ------------------------------------------------------------------------------------------------
def _scallop(hinge, rim_y, cup, ribs=7, rings=(0.1, 0.42, 0.75, 1.0), half_fan=66.0, rho=1.3, dist=1.2, up=False):
    """Grid of a scallop valve: fan from the hinge toward -Z, radial ribs (2 samples per rib), cupped below (or above
    when up=True) the rim plane y = rim_y. Rows = fan angle (u), columns = distance from the hinge (v)."""
    hx, hy, hz = hinge
    n = ribs * 2
    pts = []
    for i in range(n + 1):
        th = math.radians(-half_fan + 2 * half_fan * i / n)
        R = dist * math.cos(th) + math.sqrt(max(0.0, rho * rho - (dist * math.sin(th)) ** 2))
        rib = 0.08 if i % 2 == 0 else -0.03            # ridge / furrow
        row = []
        for f in rings:
            r = R * f * (1.0 + (0.025 if (i % 2 == 0 and f == 1.0) else 0.0))   # scalloped edge
            depth = cup * math.sin(math.pi * min(0.985, max(0.0, f))) ** 0.7
            y = rim_y + (1 if up else -1) * (depth + rib * f)
            row.append((hx + r * math.sin(th), y, hz - r * math.cos(th)))
        pts.append(row)
    return pts


def clam_pearl():
    p = P.Prop("clam_pearl", photo="09_clam_pearl.png", size=(2.6, 2.2, 2.83), budget=800, view=(-20, 30),
               view2=(160, 35), notes="kit MapAssets.Plains.Shell_A; Hub Beach 8, Plains_2 21 (scales 0.80-1.29); "
                                      "decor only (no collision, no shadow)")
    H = (0.0, 0.38, 1.25)                     # hinge (X axis)
    T = 0.06                                   # shell thickness
    # 2026-10-19 (Agent B's preview: too pale): saturated pink outside, warm light pink inside, SmoothPlastic like
    # today's parts (Plain family), a vertex-colour gradient darker at the hinge, lighter toward the rim
    low_out = p.mesh("ShellBottom", "Plain", "ClamPink", shadow=False)
    low_in = p.mesh("ShellBottomInner", "Plain", "ClamInner", shadow=False)
    top_out = p.mesh("ShellTop", "Plain", "ClamPink", pivot=H, shadow=False)
    top_in = p.mesh("ShellTopInner", "Plain", "ClamInner", pivot=H, shadow=False)
    pearl = p.mesh("Pearl", "Plain", "Pearl", shadow=False)
    hv = Vector(H)

    def gradient(lo, hi):
        return lambda v, s: lo + (hi - lo) * min(1.0, (v - hv).length / 2.5)

    lower = _scallop(H, 0.42, 0.36)
    low_in.grid(lower, thickness=T, sides=("top",), smooth=True, tone=1.0)
    low_in.shade(gradient(0.86, 1.0))
    low_out.grid(lower, thickness=T, sides=("bottom", "u0", "u1", "v0", "v1"), smooth=True, tone=1.0)
    low_out.shade(gradient(0.8, 1.0))
    n0 = len(low_out.faces)
    low_out.cyl((-0.32, H[1], H[2] + 0.05), (0.32, H[1], H[2] + 0.05), 0.12, segs=6, bevel=0, tone=0.78)   # hinge
    upper = _scallop(H, 0.46, 0.22, up=True)
    top_out.grid(upper, thickness=T, sides=("top", "u0", "u1", "v0", "v1"), smooth=True, tone=1.0)
    top_out.shade(gradient(0.8, 1.0))
    top_in.grid(upper, thickness=T, sides=("bottom",), smooth=True, tone=1.0)
    top_in.shade(gradient(0.9, 1.0))
    OPEN = 34   # rest pose (today 42): a little more closed so more pink shell shows
    open_m = (P.Matrix.Translation(Vector(H)) @ P.Matrix.Rotation(math.radians(OPEN), 4, "X")
              @ P.Matrix.Translation(-Vector(H)))
    top_out.transform(open_m)
    top_in.transform(open_m)
    pearl.ico((0.0, 0.56, 0.2), 0.4, sub=2, jit=0.0, smooth=True)
    p.attach("Hinge", H)
    p.attach("PearlGlint", (0.0, 0.92, 0.2))
    return p


# ------------------------------------------------------------------------------------------------
# 04 EGG_NEST - kit MapAssets.Plains.SeagullNest_Rock: bbox 12.29 x 10.95 x 12.29 (a 9 x 10 x 9 Toolbox rock yawed 30),
# pivot bottom centre. Today: rock (150,156,168) Hull collision; nest ring cyl 5.0 dia x 1.0 at y 9.6 (196,160,104);
# inner cyl 3.4 dia (112,62,38); 3 eggs 1.1 / 1.1 / 1.0 at y 10.4 (245,246,250) x 2 and (232,226,208).
# ------------------------------------------------------------------------------------------------
def _surface_hit(mesh, origin, direction):
    """First hit of a ray on the triangles built so far in `mesh` (prop space): (point, normal) or None."""
    from mathutils.geometry import intersect_ray_tri
    o, d = Vector(origin), Vector(direction).normalized()
    best = None
    for f in mesh.faces:
        a, b, c = (Vector(mesh.verts[i]) for i in f)
        hit = intersect_ray_tri(a, b, c, d, o, True)
        if hit is not None:
            t = (hit - o).dot(d)
            if t > 0 and (best is None or t < best[0]):
                best = (t, hit, (b - a).cross(c - a).normalized())
    return (best[1], best[2]) if best else None


def _dir(az, el):
    a, e = math.radians(az), math.radians(el)
    return Vector((math.cos(e) * math.cos(a), math.sin(e), math.cos(e) * math.sin(a)))


def egg_nest():
    p = P.Prop("egg_nest", photo="04_egg_nest.png", size=(12.29, 10.95, 12.29), budget=1500, view=(-25, 28),
               view2=(150, 40), notes="kit MapAssets.Plains.SeagullNest_Rock (Toolbox attrs SourceAssetId/SourceCreator "
                                      "on the old rock); Plains_2 Rocks 5; the rock is now our own mesh")
    rng = random.Random(4)
    rock = p.mesh("Rock", "Stone", "Stone")
    cracks = p.mesh("Cracks", "Stone", "StoneMortar", shadow=False)
    moss = p.mesh("Moss", "Moss", "Moss", shadow=False)
    ring = p.mesh("NestRing", "Straw", "Rope")
    twigs = p.mesh("Twigs", "Wood", "WoodMid", shadow=False)
    lining = p.mesh("Lining", "Straw", "WoodDark", shadow=False)
    eggs = p.mesh("Eggs", "Bone", "Pearl", shadow=False)
    egg3 = p.mesh("EggCream", "Bone", "ClothCream", shadow=False)
    spots = p.mesh("Speckles", "Plain", "Speckle", shadow=False)
    # 2026-10-19 (Agent B: the 5.1-wide ring overhung a narrow top): rock centre raised so the flat ledge at y 9.05 is
    # wide, and the ledge's own vertices pushed out to r >= 2.85 (the ring's outer radius is 2.55)
    C, TOP, LEDGE_R, SINK = Vector((0.0, 4.91, 0.0)), 9.05, 2.85, 0.12

    def ledge(v):  # flat top for the nest (local coordinates)
        if v.y > TOP - C.y:
            v.y = TOP - C.y
            r = math.hypot(v.x, v.z)
            if 1e-6 < r < LEDGE_R:
                v.x, v.z = v.x * LEDGE_R / r, v.z * LEDGE_R / r
        return v

    rock.ico(tuple(C), 5.0, scale=(1.06, 1.0, 1.04), sub=2, jit=0.09, deform=ledge)
    rock.ico((3.9, 1.9, -2.6), 2.7, scale=(1.0, 0.85, 0.9), sub=1, jit=0.12, rot=(8, 25, -10), tone=0.93)
    rock.ico((-4.0, 1.3, 2.9), 1.8, scale=(1.1, 0.8, 1.0), sub=1, jit=0.12, rot=(0, 60, 6), tone=0.97)
    # a flat ledge stone set into the top (r 2.95, top exactly at the ledge): the ring sits on it all round
    rock.cyl((0, TOP - 0.3, 0), (0, TOP, 0), 2.95, segs=12, smooth=False, bevel=0.06, caps=(False, True), tone=0.92,
             spin=7)
    rock_pts = [(x, max(y, p.floor), z) for x, y, z in rock.verts]   # as the floor clamp of make() will leave them
    # cracks: dark lines traced on the facets from the shoulders down
    for path in ([(210, 58), (214, 42), (206, 26), (212, 10), (205, -6)], [(40, 52), (47, 36), (42, 20), (50, 6)],
                 [(120, 40), (116, 28), (124, 16)]):
        pts = []
        for az, el in path:
            hit = _surface_hit(rock, tuple(C + _dir(az, el) * 9.0), tuple(-_dir(az, el)))
            if hit:
                pts.append(tuple(hit[0] + hit[1] * 0.015))
        if len(pts) >= 2:
            cracks.tube(pts, 0.07, segs=3, smooth=False)
    # moss on the shoulders and at the foot
    for az, el, r in ((15, 52, 0.75), (160, 56, 0.7), (250, 50, 0.7), (60, 3, 0.85), (185, 2, 0.8), (300, 4, 0.7)):
        for k in range(2):  # two irregular, overlapping pads per spot, lying ON the facet (local y = its normal)
            hit = _surface_hit(rock, tuple(C + _dir(az + k * 9, el - k * 6) * 9.0), tuple(-_dir(az + k * 9, el - k * 6)))
            if not hit:
                continue
            e = Vector((0, 1, 0)).rotation_difference(hit[1]).to_euler("ZYX")
            moss.ico(tuple(hit[0] + hit[1] * 0.03), r * rng.uniform(0.7, 1.0), scale=(1.8, 0.2, 0.9), sub=1, jit=0.2,
                     rot=(math.degrees(e.x), math.degrees(e.y), math.degrees(e.z)), tone=rng.uniform(0.72, 0.86))
    # the nest: woven straw ring, twigs, brown lining
    ring.torus((0, 9.55 - SINK, 0), 1.95, 0.6, segs=12, rsegs=5, scale=(1.0, 0.8, 1.0))   # bottom 8.95: into the ledge
    for i in range(14):
        a = math.radians(i * 360 / 14 + rng.uniform(-8, 8))
        rr = 1.95 + rng.uniform(0.15, 0.55)
        y = 9.55 - SINK + rng.uniform(-0.15, 0.35)
        length = rng.uniform(1.5, 2.4)
        t = Vector((-math.sin(a), rng.uniform(-0.25, 0.3), math.cos(a))).normalized()
        cpt = Vector((rr * math.cos(a), y, rr * math.sin(a)))
        twigs.cyl(tuple(cpt - t * length / 2), tuple(cpt + t * length / 2 + Vector((0, 0, 0))), rng.uniform(0.05, 0.08),
                  segs=4, bevel=0, smooth=False)
    for i in range(10):  # twig skirt from the ring's rim down onto the ledge: no gap shows from any side
        a = math.radians(i * 36 + rng.uniform(-10, 10))
        d = Vector((math.cos(a), 0, math.sin(a)))
        top_pt = d * 2.35 + Vector((0, 9.35 - SINK, 0)) + Vector((-d.z, 0, d.x)) * rng.uniform(-0.3, 0.3)
        low_pt = d * 2.95 + Vector((0, 8.98, 0)) + Vector((-d.z, 0, d.x)) * rng.uniform(-0.4, 0.4)
        twigs.cyl(tuple(top_pt), tuple(low_pt), rng.uniform(0.05, 0.07), segs=4, bevel=0, smooth=False)
    lining.lathe([(r, y - SINK) for r, y in ((0.15, 9.32), (1.0, 9.36), (1.75, 9.62), (1.78, 9.8), (1.0, 9.55), (0.15, 9.5))],
                 segs=10, smooth=False)
    # three slightly different pale eggs, with speckles
    for k, (x, z, r, tilt, yaw, mesh) in enumerate(((-0.55, -0.35, 0.53, 14, 20, eggs), (0.6, -0.2, 0.55, -10, 140, eggs),
                                                    (0.0, 0.62, 0.48, 18, 260, egg3))):
        def egg(v, r=r):
            v = Vector((v.x, v.y * 1.28, v.z))
            k2 = 1.0 - 0.16 * max(0.0, v.y / (r * 1.28))   # narrower top
            return Vector((v.x * k2, v.y, v.z * k2))
        c = Vector((x, 9.52 - SINK + r * 1.2, z))
        mesh.ico(tuple(c), r, sub=2, jit=0.0, deform=egg, rot=(tilt, yaw, 0), smooth=True)
        R3 = P._rot((tilt, yaw, 0)).to_3x3()
        for s in range(9):
            d = _dir(rng.uniform(0, 360), rng.uniform(-10, 70))
            surf = c + R3 @ egg(d * r)
            nrm = (R3 @ egg(d * r)).normalized()
            q = nrm.cross(Vector((0, 1, 0)) if abs(nrm.y) < 0.9 else Vector((1, 0, 0))).normalized()
            w = q.cross(nrm)
            sz = rng.uniform(0.05, 0.09)
            tri = [surf + nrm * 0.004 + q * sz, surf + nrm * 0.004 - q * sz * 0.5 + w * sz * 0.8,
                   surf + nrm * 0.004 - q * sz * 0.5 - w * sz * 0.8]
            spots.poly([tuple(v) for v in tri], normal=tuple(nrm))
    # collider: the true convex hull of the rock and its two boulders (CollisionFidelity Hull, like today's own hull)
    col = p.collider_mesh("Rock")
    p.notes += f"; rock collider = convex hull of {col.hull(rock_pts)} vertices"
    p.collider("Cylinder", (0, 9.6 - SINK, 0), (1.0, 5.0, 5.0), (0, 0, 90), name="egg_nest_Collider_Nest")
    p.attach("Sparkle", (0, 10.9 - SINK, 0))
    return p


# ------------------------------------------------------------------------------------------------
# 08 SCARECROW - kit MapAssets.Plains.Scarecrow_A: bbox 8.00 x 9.45 x 3.60, pivot bottom centre, front -Z.
# Today: pole 0.6 x 7 (WoodDark), arms 7 x 0.5 at y 5.4, blue shirt 2.6 x 3 x 1.4 at y 4.7 (74,108,220), hay hands at
# x +-3.4 and hay skirt at y 3.1 (236,200,96), head ball 2.2 at y 7.2 (244,226,160), brown hat (168,98,56) brim 3.6 at
# y 8.0 + crown 2.0 x 1.3, tilted 6 deg; brown eyes. Sway (client): hat and straw only (pivots = attachments).
# ------------------------------------------------------------------------------------------------
def scarecrow():
    p = P.Prop("scarecrow", photo="08_scarecrow.png", size=(8.0, 9.45, 3.6), budget=3000, view=(-12, 12),
               view2=(150, 20), notes="kit MapAssets.Plains.Scarecrow_A; Plains_1 Farm 1; sway: hat + straw meshes")
    rng = random.Random(8)
    HAT = (0.0, 8.0, 0.0)
    WL, WR, COL, HEM = (-2.95, 5.38, 0.0), (2.95, 5.38, 0.0), (0.0, 6.22, 0.0), (0.0, 3.3, 0.0)
    post = p.mesh("Post", "Wood", "WoodDark")
    shirt = p.mesh("Shirt", "Cloth", "ClothBlueAlt")
    patches = p.mesh("Patches", "Cloth", "ClothTan", shadow=False)
    head = p.mesh("Head", "Cloth", "StrawPale")
    buttons = p.mesh("Buttons", "Plain", "ButtonDark", shadow=False)
    stitches = p.mesh("Stitches", "Plain", "Thread", shadow=False)
    rope = p.mesh("Rope", "Rope", "Rope", shadow=False)
    hat = p.mesh("Hat", "Straw", "WoodMid", pivot=HAT)
    band = p.mesh("HatBand", "Cloth", "WoodDark", pivot=HAT, shadow=False)
    straw = {k: p.mesh(f"Straw{k}", "Straw", "Straw", pivot=pv, shadow=False)
             for k, pv in (("WristL", WL), ("WristR", WR), ("Collar", COL), ("Hem", HEM))}
    # rough-hewn post and crossbar
    post.beam((0, -0.05, 0), (0, 7.0, 0), 0.56, 0.56, up=(0, 0, 1), taper=0.9, jit=0.02)
    post.beam((-3.45, 5.4, 0), (3.45, 5.4, 0), 0.42, 0.42, jit=0.02)
    # shirt: elliptical torso, drooping sleeves, folds; tan patches
    shirt.lathe([(1.22, 3.25), (1.3, 3.6), (1.4, 4.6), (1.22, 5.8), (0.62, 6.2), (0.3, 6.28)], c=(0, 0, 0), segs=12,
                scale=(1, 1, 0.6), smooth=False)
    for s in (-1, 1):
        shirt.tube([(s * 1.0, 5.55, 0), (s * 1.75, 5.42, 0), (s * 2.4, 5.36, 0.02), (s * 2.95, 5.38, 0)],
                   [0.52, 0.5, 0.47, 0.44], segs=8, smooth=False)
    for x, h in ((-0.55, 1.0), (0.2, 1.2), (0.75, 0.9)):  # vertical folds on the front
        hit = _surface_hit(shirt, (x, 4.35, -3.0), (0, 0, 1))
        if hit:
            shirt.ico(tuple(hit[0]), 0.5, scale=(0.18, h * 1.5, 0.16), sub=1, jit=0.03)
    for (o, d, size, spin) in (((0.48, 4.95, -3.0), (0, 0, 1), 0.58, 8), ((2.1, 7.0, 0.1), (0, -1, 0), 0.5, -14)):
        hit = _surface_hit(shirt, o, d)
        if hit:
            pt, n = hit
            u = n.cross(Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((0, 0, 1))).normalized()
            v = n.cross(u)
            R = P.Matrix.Rotation(math.radians(spin), 3, n)
            u, v = R @ u, R @ v
            q = [pt + n * 0.03 + (u * a + v * b) * size / 2 for a, b in ((-1, -1), (1, -0.9), (0.95, 1), (-1, 0.95))]
            patches.poly([tuple(x) for x in q], normal=tuple(n))
    # burlap sack head with a gathered neck, button eyes and a stitched smile
    head.ico((0, 7.25, 0), 1.1, scale=(1.0, 1.05, 0.95), sub=2, jit=0.035, smooth=True)
    head.cyl((0, 6.15, 0), (0, 6.55, 0), 0.5, 0.64, segs=10, bevel=0)
    for s in (-1, 1):
        hit = _surface_hit(head, (s * 0.38, 7.48, -3.0), (0, 0, 1))
        if hit:
            buttons.cyl(tuple(hit[0] - hit[1] * 0.02), tuple(hit[0] + hit[1] * 0.07), 0.2, segs=8, bevel=0.02)
    smile = []
    for i in range(6):
        x = -0.5 + i * 0.2
        hit = _surface_hit(head, (x, 6.88 + 0.12 * (x / 0.5) ** 2, -3.0), (0, 0, 1))
        if hit:
            smile.append((hit[0] + hit[1] * 0.025, hit[1]))
    if len(smile) >= 2:
        stitches.tube([tuple(pt) for pt, n in smile], 0.03, segs=3, smooth=False)
        for pt, n in smile[1:-1]:  # cross stitches over the mouth line
            for ang in (40, -40):
                u = Vector((math.cos(math.radians(ang)), math.sin(math.radians(ang)), 0))
                stitches.tube([tuple(pt - u * 0.13), tuple(pt + u * 0.13)], 0.025, segs=3, smooth=False)
    # rope: belt with a knot and two ends, wrist ties, neck tie
    rope.torus((0, 3.55, 0), 1.3, 0.075, segs=12, rsegs=3, scale=(1, 1, 0.6))
    rope.ico((-0.55, 3.5, -0.74), 0.13, sub=1, jit=0.05)
    rope.tube([(-0.55, 3.45, -0.78), (-0.6, 3.1, -0.82), (-0.52, 2.75, -0.8)], 0.06, segs=4)
    rope.tube([(-0.5, 3.45, -0.78), (-0.38, 3.15, -0.82), (-0.3, 2.9, -0.8)], 0.06, segs=4)
    for s in (-1, 1):
        rope.torus((s * 2.82, 5.38, 0), 0.44, 0.06, segs=8, rsegs=3, axis="x")
    rope.torus((0, 6.35, 0), 0.6, 0.06, segs=10, rsegs=3)
    # straw: wrist bunches (outward), collar (up), hem and "pants" (down)
    for s in (-1, 1):  # a dense straw core at each wrist (today's hay hands)
        straw["WristL" if s < 0 else "WristR"].ico((s * 3.2, 5.38, 0), 0.36, scale=(1.5, 0.85, 0.85), sub=1, jit=0.12)
    straw["Hem"].torus((0, 3.3, 0), 1.2, 0.2, segs=12, rsegs=4, scale=(1, 1, 0.62))   # straw band under the belt
    for key, (cx, cy, cz), dirc, n, (l0, l1), spread in (("WristL", WL, (-1, 0, 0), 22, (0.6, 1.1), 40),
                                                         ("WristR", WR, (1, 0, 0), 22, (0.6, 1.1), 40),
                                                         ("Collar", COL, (0, 1, 0), 22, (0.4, 0.75), 78),
                                                         ("Hem", HEM, (0, -1, 0), 34, (0.6, 1.4), 30)):
        dv = Vector(dirc)
        for i in range(n):
            a = 2 * math.pi * i / n + rng.uniform(-0.2, 0.2)
            ring_r = {"Collar": 0.72, "Hem": 1.15}.get(key, 0.3)
            if key in ("Collar", "Hem"):
                base = Vector((cx + ring_r * math.cos(a), cy, cz + ring_r * 0.6 * math.sin(a)))
                outward = Vector((math.cos(a), 0, math.sin(a) * 0.6)).normalized()
                d = (dv + outward * math.tan(math.radians(rng.uniform(45 if key == "Collar" else 5, spread)))).normalized()
                length = rng.uniform(l0, l1) * (1.25 if key == "Hem" and abs(math.cos(a)) > 0.5 else 1.0)
            else:
                ortho = Vector((0, math.cos(a), math.sin(a)))
                base = Vector((cx, cy, cz)) + ortho * ring_r - dv * 0.15
                d = (dv + ortho * math.tan(math.radians(rng.uniform(5, spread)))).normalized()
                length = rng.uniform(l0, l1)
            straw[key].spike(tuple(base), tuple(base + d * length), rng.uniform(0.08, 0.13), segs=3,
                             tone=rng.uniform(0.82, 1.0))
    # worn straw hat with a dark band, tilted 6 deg like today
    start = len(hat.verts)
    hat.lathe([(0.95, 7.98), (1.85, 7.93), (1.86, 8.0), (0.95, 8.07)], segs=16, smooth=False)
    hat.deform(lambda v: Vector((v.x, v.y + 0.07 * math.sin(3 * math.atan2(v.z, v.x)) * (math.hypot(v.x, v.z) - 0.95),
                                 v.z)), start)
    hat.lathe([(1.0, 8.02), (0.98, 8.65), (0.88, 9.15), (0.55, 9.28), (0.2, 9.2)], segs=12, smooth=False)
    band.ring((0, 8.18, 0), 0.99, 1.05, 0.24, segs=12, faces=("outer", "top", "bottom"))
    tilt = (P.Matrix.Translation(Vector(HAT)) @ P.Matrix.Rotation(math.radians(-6), 4, "Z")
            @ P.Matrix.Translation(-Vector(HAT)))
    hat.transform(tilt)
    band.transform(tilt)
    p.collider("Block", (0, 3.5, 0), (0.6, 7.0, 0.6), name="scarecrow_Collider_Post")
    p.collider("Block", (0, 5.4, 0), (7.0, 0.5, 0.5), name="scarecrow_Collider_Arms")
    p.collider("Block", (0, 4.7, 0), (2.6, 3.0, 1.4), name="scarecrow_Collider_Shirt")
    p.collider("Ball", (0, 7.2, 0), (2.2, 2.2, 2.2), name="scarecrow_Collider_Head")
    for name, pt in (("HatPivot", HAT), ("StrawWristL", WL), ("StrawWristR", WR), ("StrawCollar", COL),
                     ("StrawHem", HEM)):
        p.attach(name, pt)
    return p


RECIPES = {"well": well, "chest": chest, "rowboat": rowboat, "minecart": minecart, "skull_bones": skull_bones,
           "clam_pearl": clam_pearl, "egg_nest": egg_nest, "scarecrow": scarecrow}
