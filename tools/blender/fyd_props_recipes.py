"""Prop recipes (docs/model_upgrade_brief.txt section 9). One function per prop id -> fyd_props.Prop.

All numbers are studs in Roblox model space (x right, y up, z back, front -Z, origin = ground contact under the
Studio pivot). The current Studio sizes come from docs/prop_inventory.md (Agent B).
"""
import math
import random

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
        t1, t2 = math.radians(82), math.radians(48)
        rr = R + 0.03
        iron.beam((x, H + rr * math.cos(t1), rr * math.sin(t1)), (x, H + rr * math.cos(t2), rr * math.sin(t2)), 0.3, 0.05,
                  up=(0, math.cos((t1 + t2) / 2), math.sin((t1 + t2) / 2)), bevel=0)
    p.collider("Block", (0, 1.0, 0), (4.4, 2.0, 2.8), name="chest_Collider_Base")
    p.collider("Cylinder", (0, 2.0, 0), (4.4, 2.8, 2.8), name="chest_Collider_Lid")
    p.attach("Sparkle", (0, 1.72, -1.52))
    p.attach("LidTop", (0, 3.47, 0))
    return p


RECIPES = {"well": well, "chest": chest}
