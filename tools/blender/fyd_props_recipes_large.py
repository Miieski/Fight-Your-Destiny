"""Prop recipes, batch 3 (large): fountain, anvil_forge (docs/model_upgrade_brief.txt section 9).

Studs, Roblox model space (x right, y up, z back, front -Z), origin = ground contact under the Studio pivot.
Current sizes / parts: docs/prop_inventory.md.
"""
import math
import random

from mathutils import Vector

import fyd_props as P
from fyd_props_recipes import _dir, _surface_hit


# ------------------------------------------------------------------------------------------------
# 01 FOUNTAIN - kit MapAssets.Hub.Fountain_A: bbox 30.00 x 22.30 x 30.00, pivot bottom centre (hub pivot
# (-46, 0.45, -70), yaw 0). Today: step cyl 30 dia y 0-1 (StoneDark), basin cyl 26 y 1-4 (Stone), rim cyl 27 y 3.8-4.6
# (StoneDark), water 23 dia (top 4.67, T 0.15), pedestal cyls 7 dia y 3-8 (Stone) and 5 dia y 7.5-11.5 (163,170,183),
# upper bowl 13 dia y 10.8-12.4 (StoneDark), upper water 11.4 dia, spout 3 dia y 12.2-16.6 (Stone), gold ring 4 dia
# y 16.4-17.2, TopCrystal Neon (95,212,255) 2.6 x 5.4 x 2.3 at y 19.6 (Attachment WaterPoint + PointLight), 4 streams
# from the bowl lips at the diagonals, 4 spout lips. Solid: basin, rim, pedestals, bowl, spout (full cylinders).
# ------------------------------------------------------------------------------------------------
def fountain():
    p = P.Prop("fountain", photo="01_fountain.png", size=(30.0, 22.3, 30.0), budget=6000, view=(-25, 24),
               view2=(160, 32), notes="kit MapAssets.Hub.Fountain_A; Hub.Decor.Village.Fountain_A; test Lineup.Hub.Fountain_A; "
                                      "keep Hub.Decor.VFX.Water_Ripple (separate part)")
    rng = random.Random(1)
    dark = p.mesh("DarkStone", "Stone", "StoneDark")
    wall = p.mesh("Wall", "StoneBlocks", "Stone")
    ped = p.mesh("Pedestal", "Stone", "Stone")
    col = p.mesh("Column", "Stone", "StonePale")
    wet = p.mesh("Wet", "Stone", "StoneMortar", shadow=False)
    moss = p.mesh("Moss", "Moss", "Moss", shadow=False)
    gold = p.mesh("Gold", "Gold", "Gold", shadow=False)
    crystal = p.mesh("Crystal", "Glow", "Diamond", shadow=False)
    low_w = p.mesh("LowerWater", "Water", "Water")
    up_w = p.mesh("UpperWater", "Water", "Water")
    stream = p.mesh("Stream", "Stream", "Water")
    foam = p.mesh("Foam", "Foam", "ClothWhite", shadow=False)
    WL, WU = 4.25, 12.3                              # water levels (0.35 / 0.25 below the rims)

    # --- tier 1: step of 16 slabs, lower wall (cut-stone texture), coping stones with chipped bevelled tops ------
    for k in range(16):
        a = k * 22.5 + rng.uniform(-1.5, 1.5)
        dark.arc_block(12.6, 15.0 + rng.uniform(-0.05, 0.08), a + 0.25, a + 22.5 - 0.25, 0.0, 1.0 + rng.uniform(-0.04, 0.03),
                       segs=2, jit=0.03, tone=rng.uniform(0.86, 1.0))
    wall.ring((0, 2.4, 0), 12.2, 13.0, 2.8, segs=48, faces=("outer", "inner"))
    for k in range(16):
        a = k * 22.5 + 11.25 + rng.uniform(-2, 2)
        dark.arc_block(12.0, 13.5 + rng.uniform(-0.06, 0.06), a + 0.3, a + 22.5 - 0.3, 3.8, 4.6 + rng.uniform(-0.06, 0.04),
                       segs=2, jit=0.04, bevel_top_inner=True, tone=rng.uniform(0.84, 1.0))
    # wet band on the coping's inner face just above the water, dark basin floor seen through the water
    wet.ring((0, WL + 0.12, 0), 11.97, 11.99, 0.26, segs=48, faces=("inner",))
    wet.cyl((0, 1.0, 0), (0, 1.15, 0), 12.2, segs=24, smooth=False, bevel=0, caps=(False, True))
    low_w.cyl((0, WL - 0.12, 0), (0, WL, 0), 12.05, segs=32, smooth=False, bevel=0)

    # --- central pedestal with carved bands, pale upper column flaring into the upper bowl -----------------------
    ped.lathe([(3.7, 1.0), (3.7, 1.6), (3.45, 1.8), (3.3, 2.2), (3.22, 7.2), (3.5, 7.45), (3.6, 7.8), (3.0, 8.0)], segs=20)
    col.lathe([(2.6, 7.95), (2.45, 8.2), (2.3, 8.6), (2.25, 10.2), (2.45, 10.6), (3.2, 10.95), (3.4, 11.1)], segs=20)
    for y, r_in, r_out, h in ((3.6, 3.24, 3.42, 0.32), (5.7, 3.23, 3.41, 0.32), (9.35, 2.25, 2.44, 0.3)):
        dark.ring((0, y, 0), r_in, r_out, h, segs=20, faces=("outer", "top", "bottom"))

    # --- tier 2: upper bowl (irregular rim), 6 carved spout lips, water, wet band -----------------------------------
    start = len(dark.verts)
    dark.lathe([(3.3, 10.8), (5.0, 11.05), (6.3, 11.5), (6.6, 11.8), (6.65, 12.45), (6.25, 12.55), (6.0, 12.1),
                (3.0, 11.85), (0.5, 11.85)], segs=24, smooth=True)
    dark.deform(lambda v: Vector((v.x, v.y + (0.05 * math.sin(5 * math.atan2(v.z, v.x)) + 0.03 * math.sin(11 * math.atan2(v.z, v.x)))
                                  if (math.hypot(v.x, v.z) > 6.1 and v.y > 12.3) else v.y, v.z)), start)
    lip = [(-0.5, 0.0), (0.5, 0.0), (0.5, 0.45), (0.25, 0.45), (0.18, 0.2), (-0.18, 0.2), (-0.25, 0.45), (-0.5, 0.45)]
    angles = [30 + 60 * k for k in range(6)]
    for th in angles:
        d = Vector((math.cos(math.radians(th)), 0, math.sin(math.radians(th))))
        cpt = d * 6.85 + Vector((0, 12.15, 0))
        dark.prism(lip, 1.15, c=tuple(cpt), rot=(0, -th + 90, 0), bevel=0.03)
    wet.ring((0, WU + 0.11, 0), 5.97, 5.99, 0.2, segs=24, faces=("inner",))
    up_w.cyl((0, WU - 0.12, 0), (0, WU, 0), 6.05, segs=24, smooth=False, bevel=0)

    # --- tier 3: spout column, gold collar, crystal -------------------------------------------------------------------
    ped.lathe([(1.7, 11.85), (1.7, 12.25), (1.45, 12.45), (1.38, 15.9), (1.55, 16.15), (1.6, 16.45), (1.2, 16.5)], segs=16)
    gold.lathe([(1.2, 16.4), (1.85, 16.4), (1.95, 16.55), (1.95, 17.05), (1.8, 17.2), (1.2, 17.2)], segs=20, smooth=False)
    crystal.cyl((0, 17.4, 0), (0, 20.6, 0), 1.15, segs=6, smooth=False, bevel=0, caps=(False, False), spin=15)
    crystal.spike((0, 20.6, 0), (0, 22.3, 0), 1.15 / math.cos(math.radians(30)) * math.cos(math.radians(30)), segs=6,
                  cap=False)
    crystal.spike((0, 17.4, 0), (0, 16.9, 0), 1.15, segs=6, cap=False)
    for th, tilt in ((70, 24), (250, 20)):  # two small side crystals
        d = Vector((math.cos(math.radians(th)), 0, math.sin(math.radians(th))))
        base = Vector((0, 17.6, 0)) + d * 0.7
        top = base + (d * math.sin(math.radians(tilt)) + Vector((0, math.cos(math.radians(tilt)), 0))) * 1.9
        crystal.cyl(tuple(base), tuple(top), 0.42, segs=6, smooth=False, bevel=0, caps=(False, False))
        crystal.spike(tuple(top), tuple(top + (top - base).normalized() * 0.7), 0.42, segs=6, cap=False)

    # --- 6 falling streams from the lips into the lower basin, foam where they land and round the spout ------------
    landings = []
    for th in angles:
        d = Vector((math.cos(math.radians(th)), 0, math.sin(math.radians(th))))
        pts, radii = [], []
        for i in range(7):
            t = i / 6
            r = 7.2 + 2.7 * t
            pts.append(tuple(d * r + Vector((0, 12.35 - (12.35 - WL + 0.05) * t * t, 0))))
            radii.append(0.3 - 0.1 * t)
        stream.tube(pts, radii, segs=5, smooth=True)
        land = d * 9.9 + Vector((0, WL + 0.03, 0))
        landings.append(land)
        foam.torus(tuple(land), 0.55, 0.13, segs=8, rsegs=3, scale=(1, 0.45, 1))
    foam.torus((0, WU + 0.03, 0), 1.75, 0.12, segs=12, rsegs=3, scale=(1, 0.45, 1))

    # --- moss lying on the step top (Studio check: no pads on the step's outer face / the plaza) ------------------------
    # Each pad is a flattened lump bent along the ring (tangential half TH, radial half RH, ~0.1 proud of the stone).
    # Even k: in the corner against the wall (inner edge just inside the wall, creeping 0.25 up it); odd k: smaller,
    # nearer the step edge. Radially everything stays within r 12.9 .. 14.8 (step edge r 14.95..15.08: no overhang).
    def wrap(az, rc, y0, th, rh, vh, creep):
        a0 = math.radians(az)

        def fn(v):
            u, h = v.z * rh, v.y * vh
            if creep:
                h += 0.25 * max(0.0, (-v.z - 0.3) / 0.7)
            ang = a0 + v.x * th / rc
            return Vector((math.cos(ang) * (rc + u), y0 + h, math.sin(ang) * (rc + u)))
        return fn

    for k in range(10):
        az = k * 36 + rng.uniform(-10, 10)
        th = rng.uniform(1.5, 1.9) if k % 2 == 0 else rng.uniform(0.9, 1.3)
        rh = rng.uniform(0.6, 0.75) if k % 2 == 0 else 0.5
        rc = 12.9 + rh if k % 2 == 0 else 14.25
        for off in (0.0, 1.5, -1.5, 3.0):   # a ray into a slab joint misses: nudge it
            hit = _surface_hit(dark, tuple(_dir(az + off, 0) * rc + Vector((0, 2.5, 0))), (0, -1, 0))  # under the coping
            if hit:
                break
        if hit:
            moss.ico((0, 0, 0), 1.0, sub=1, jit=0.08, deform=wrap(az, rc, hit[0].y - 0.05, th, rh, 0.16, k % 2 == 0),
                     tone=rng.uniform(0.72, 0.86))

    # --- colliders: today's solids, exactly (full cylinders: nobody climbs in more than today) ----------------------
    for name, y, h, dia in (("Step", 0.5, 1.0, 30.0), ("Basin", 2.5, 3.0, 26.0), ("Rim", 4.2, 0.8, 27.0),
                            ("Pedestal", 5.5, 5.0, 7.0), ("PedestalTop", 9.5, 4.0, 5.0), ("UpperBowl", 11.6, 1.6, 13.0),
                            ("Spout", 14.4, 4.4, 3.0), ("SpoutRing", 16.8, 0.8, 4.0)):
        p.collider("Cylinder", (0, y, 0), (h, dia, dia), (0, 0, 90), name=f"fountain_Collider_{name}")
    # today's 4 SpoutLip blocks (2 x 1.2 x 1.6, radial x 2, centre radius 6.4, y 11.2..12.4, at the diagonals): same
    # collision as today (they reach ~0.9 past the upper-bowl cylinder)
    for i, th in enumerate((45, 135, 225, 315)):
        d = _dir(th, 0)
        yaw = -th if th <= 180 else 360 - th
        p.collider("Block", (d.x * 6.4, 11.8, d.z * 6.4), (2.0, 1.2, 1.6), (0, yaw, 0), name=f"fountain_Collider_SpoutLip{i + 1}")
    # --- PropFX points ------------------------------------------------------------------------------------------
    p.attach("WaterLower", (0, WL, 0))
    p.attach("WaterUpper", (0, WU, 0))
    p.attach("WaterPoint", (0, 19.6, 0))   # today's TopCrystal attachment (+ its PointLight) moves to the crystal mesh
    for i, land in enumerate(landings):
        p.attach(f"Mist{i + 1}", tuple(land + Vector((0, 0.15, 0))))
    for i, (x, y, z) in enumerate(((6.5, WL + 0.05, -6.0), (-8.0, WL + 0.05, 2.5), (2.5, WU + 0.05, -3.5))):
        p.attach(f"Glint{i + 1}", (x, y, z))
    return p


# ------------------------------------------------------------------------------------------------
# 13 ANVIL_FORGE - loose parts of Hub.WeaponShop (kit MapAssets.Hub.Station_WeaponShop), stall space (pivot floor
# centre, front -Z): Forge block 4 x 3 x 4 at (10.5, 1.5, 4.0) (150,156,168), Forge top 4.6 x 0.6 x 4.6 at y 3.1
# (104,110,124), Embers 3 x 0.4 x 3 at y 3.5 Neon (255,140,40) + PointLight + Attachment FirePoint, Chimney 2 x 6 x 2 at
# (11.6, 6.0, 5.2) (104,110,124), Stump cyl 2 x 3 at (10.5, 1.0, -1.0) (128,78,48), Anvil 3 blocks (y 2.3 / 3.0 / 3.85) +
# AnvilHorn wedge at x 12.8 (92,98,110). Subset bbox 5.30 x 9.00 x 8.80 at stall-space (10.85, 4.5, 1.9).
# The prop origin = the bottom centre of that bbox = stall-space (10.85, 0, 1.9); axes = the stall's.
# ------------------------------------------------------------------------------------------------
OX, OZ = 10.85, 1.9


def _s(x, y, z):
    """Stall space -> anvil_forge prop space."""
    return (x - OX, y, z - OZ)


def anvil_forge():
    p = P.Prop("anvil_forge", photo="13_anvil_forge.png", size=(5.3, 9.0, 8.8), budget=4000, view=(-35, 18),
               view2=(140, 26), notes="sub-model of Hub.WeaponShop / Station_WeaponShop, origin = stall-space (10.85, 0, 1.9); "
                                      "replaces Forge x2, Chimney, Embers, Stump, Anvil x3, AnvilHorn")
    p.placement = {"Host": "Hub.WeaponShop (and the kit / test copies of Station_WeaponShop)",
                   "OriginInHost": [OX, 0.0, OZ], "RotationInHost": [0, 0, 0],
                   "Replaces": ["Forge", "Forge", "Chimney", "Embers", "Stump", "Anvil", "Anvil", "Anvil", "AnvilHorn"],
                   "Keep": "the Embers' PointLight (255,140,40) and Attachment FirePoint: move them to the ForgeLight / "
                           "Fire attachments of this model"}
    rng = random.Random(13)
    hearth = p.mesh("Hearth", "StoneBlocks", "Stone")
    upper = p.mesh("Upper", "StoneBlocks", "StoneDark")
    soot = p.mesh("Soot", "Plain", "#2A2522", shadow=False)
    coal = p.mesh("Coal", "Plain", "#2E2723", shadow=False)
    coals = p.mesh("Coals", "Glow", "Fire", shadow=False)
    stump = p.mesh("Stump", "Wood", "WoodTrunk")
    rings = p.mesh("StumpTop", "Wood", "WoodLight", shadow=False)
    anvil = p.mesh("Anvil", "Iron", "Iron")
    face = p.mesh("AnvilFace", "Iron", "IronWorn", shadow=False)
    wood = p.mesh("Wood", "Wood", "WoodMid", shadow=False)
    leather = p.mesh("Leather", "Cloth", "WoodDark", shadow=False)
    water = p.mesh("Water", "Water", "Water")

    # --- hearth: plinth, side / back walls, front piers and an arched opening (voussoirs), soot inside -------------
    hearth.box(_s(10.5, 0.5, 4.0), (4.0, 1.0, 4.0), bevel=0.05, drop=((0, -1, 0),))
    for x in (8.85, 12.15):
        hearth.box(_s(x, 1.9, 4.0), (0.7, 1.8, 4.0), bevel=0.04)
    hearth.box(_s(10.5, 1.9, 5.65), (2.6, 1.8, 0.7), bevel=0.04)
    for x in (9.4, 11.6):
        hearth.box(_s(x, 1.25, 2.35), (0.4, 0.5, 0.7), bevel=0.03)                      # piers below the springing
        hearth.box(_s(x + (0.0 if x < 10.5 else 0.0), 2.55, 2.35), (0.4, 0.5, 0.7), bevel=0.03)  # spandrels
    for k in range(5):  # 5 voussoirs: arch radius 0.9 - 1.25 around (10.5, 1.5) in the front face
        a0 = -180 + k * 36
        upper.arc_block(0.9, 1.25 + rng.uniform(-0.02, 0.03), a0 + 0.8, a0 + 36 - 0.8, -0.35, 0.35, c=_s(10.5, 1.5, 2.35),
                        rot=(90, 0, 0), segs=1, jit=0.015, drop_bottom=False, tone=rng.uniform(0.86, 1.0))
    soot.box(_s(10.5, 1.65, 3.1), (1.9, 1.3, 0.2), bevel=0)
    soot.box(_s(10.5, 1.02, 2.6), (1.85, 0.04, 1.2), bevel=0)
    # --- fire bed: dark stone frame, coal bed, glowing and dark coal lumps -------------------------------------------
    for c, size in (((10.5, 3.1, 2.1), (4.6, 0.6, 0.8)), ((10.5, 3.1, 5.9), (4.6, 0.6, 0.8)),
                    ((8.6, 3.1, 4.0), (0.8, 0.6, 3.0)), ((12.4, 3.1, 4.0), (0.8, 0.6, 3.0))):
        upper.box(_s(*c), size, bevel="all", jit=0.02, tone=rng.uniform(0.85, 1.0))
    coal.box(_s(10.5, 2.98, 4.0), (3.0, 0.25, 3.0), bevel=0, drop=((0, -1, 0),))
    spots = [(9.6, 3.0), (10.2, 3.2), (10.9, 2.95), (11.4, 3.4), (9.4, 3.8), (10.1, 3.95), (10.8, 3.7), (9.6, 4.55),
             (10.3, 4.6), (9.9, 5.2), (11.0, 3.15), (10.5, 3.35), (9.25, 4.2), (10.45, 4.1)]
    for i, (x, z) in enumerate(spots):
        mesh = coals if i % 3 != 2 else coal
        r = rng.uniform(0.2, 0.32)
        mesh.ico(_s(x, 3.18 + r * 0.4, z), r, scale=(1.0, 0.7, 1.0), sub=1, jit=0.14, rot=(0, rng.uniform(0, 90), 0))
    # --- chimney (tapered, cut stone) with a cap and a dark flue -----------------------------------------------------
    upper.box(_s(11.6, 6.2, 5.2), (2.0, 5.6, 2.0), taper=(0.86, 0.86), bevel=0.05, drop=((0, -1, 0),))
    upper.box(_s(11.6, 9.15, 5.2), (2.15, 0.3, 2.15), bevel="all")
    soot.box(_s(11.6, 9.31, 5.2), (1.0, 0.03, 1.0), bevel=0, drop=((0, -1, 0),))
    # --- stump: ridged bark, end grain with growth rings, root flares -------------------------------------------------
    start = len(stump.verts)
    stump.cyl(_s(10.5, 0.0, -1.0), _s(10.5, 1.96, -1.0), 1.5, segs=14, smooth=False, bevel=0, caps=(False, True))
    cx, cz = _s(10.5, 0, -1.0)[0], _s(10.5, 0, -1.0)[2]
    stump.deform(lambda v: Vector((cx + (v.x - cx) * (1.05 if round(math.atan2(v.z - cz, v.x - cx) * 14 / (2 * math.pi)) % 2 else 0.96),
                                   v.y, cz + (v.z - cz) * (1.05 if round(math.atan2(v.z - cz, v.x - cx) * 14 / (2 * math.pi)) % 2 else 0.96))),
                 start)
    rings.cyl(_s(10.5, 1.95, -1.0), _s(10.5, 2.0, -1.0), 1.42, segs=14, smooth=False, bevel=0, caps=(False, True))
    for r, y, tone in ((1.1, 2.012, 0.86), (0.75, 2.02, 1.0), (0.42, 2.028, 0.86), (0.15, 2.034, 0.8)):
        rings.cyl(_s(10.5, 2.0, -1.0), _s(10.5, y, -1.0), r, segs=12, smooth=False, bevel=0, caps=(False, True), tone=tone)
    for a in (20, 110, 200, 290):
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        base = Vector(_s(10.5, 0.45, -1.0)) + d * 1.3
        stump.spike(tuple(base), tuple(base + d * 0.75 + Vector((0, -0.45, 0))), 0.3, segs=4)
    # --- anvil: feet, waist, body with heel, polished face, horn ------------------------------------------------------
    anvil.prism([(-0.85, 0.0), (0.85, 0.0), (0.62, 0.45), (-0.62, 0.45)], 1.2, c=_s(10.4, 2.0, -1.0), bevel=0.03)
    anvil.box(_s(10.4, 2.85, -1.0), (0.75, 0.8, 0.65), taper=(1.35, 1.3), bevel=0.03)
    anvil.box(_s(10.3, 3.62, -1.0), (3.0, 0.75, 1.3), bevel="all")
    anvil.box(_s(8.95, 3.78, -1.0), (0.5, 0.42, 0.9), bevel="all")                             # heel
    anvil.cyl(_s(11.75, 3.72, -1.0), _s(12.6, 3.74, -1.0), 0.45, 0.32, segs=8, bevel=0, caps=(True, False))
    anvil.spike(_s(12.6, 3.74, -1.0), _s(13.45, 3.6, -1.0), 0.32, segs=8, cap=False)            # horn
    face.box(_s(10.25, 4.04, -1.0), (2.85, 0.1, 1.2), bevel=0.02, drop=((0, -1, 0),))
    soot.box(_s(9.0, 4.0, -1.0), (0.18, 0.02, 0.18), bevel=0, drop=((0, -1, 0),))               # hardy hole
    # --- extras: tongs against the stump, quench bucket, bellows on the hearth's left side ------------------------------
    for dz in (-0.07, 0.07):
        anvil.beam(_s(9.3, 0.02, -2.55 + dz), _s(9.75, 1.95, -2.2 + dz * 0.2), 0.08, 0.08, bevel=0)
    anvil.box(_s(9.8, 2.05, -2.18), (0.12, 0.28, 0.2), bevel=0)
    bx, bz = 12.85, 0.85
    for k in range(10):
        t = 2 * math.pi * (k + 0.5) / 10
        ca, sa = math.cos(t), math.sin(t)
        a = _s(bx + ca * 0.6, 0.0, bz + sa * 0.6)
        b = _s(bx + ca * 0.68, 1.05, bz + sa * 0.68)
        wood.beam(a, b, 2 * math.pi * 0.6 / 10 - 0.03, 0.08, up=(ca, 0, sa), bevel=0, taper=1.12, tone=rng.uniform(0.85, 1.0))
    for y in (0.25, 0.85):
        anvil.ring(_s(bx, y, bz), 0.69, 0.75, 0.1, segs=10, faces=("outer", "top", "bottom"), start=0.0)
    water.cyl(_s(bx, 0.8, bz), _s(bx, 0.9, bz), 0.62, segs=10, smooth=False, bevel=0)
    drop_shape = [(0.0, -0.7), (0.32, -0.5), (0.42, -0.05), (0.3, 0.35), (0.0, 0.55), (-0.3, 0.35), (-0.42, -0.05),
                  (-0.32, -0.5)]
    for dx in (-0.16, 0.16):
        wood.prism(drop_shape, 0.06, c=_s(8.22 + dx, 1.75, 3.6), rot=(0, 90, 0))
    leather.prism([(x * 0.9, y * 0.9) for x, y in drop_shape], 0.28, c=_s(8.22, 1.75, 3.6), rot=(0, 90, 0))
    anvil.cyl(_s(8.22, 1.75, 2.95), _s(8.22, 1.75, 2.55), 0.08, 0.05, segs=6, bevel=0)
    # --- colliders (today's solids, the chimney a little taller) and PropFX points ---------------------------------
    p.collider("Block", _s(10.5, 1.5, 4.0), (4.0, 3.0, 4.0), name="anvil_forge_Collider_Forge")
    p.collider("Block", _s(10.5, 3.1, 4.0), (4.6, 0.6, 4.6), name="anvil_forge_Collider_ForgeTop")
    p.collider("Block", _s(11.6, 6.15, 5.2), (2.0, 6.3, 2.0), name="anvil_forge_Collider_Chimney")
    p.collider("Cylinder", _s(10.5, 1.0, -1.0), (2.0, 3.0, 3.0), (0, 0, 90), name="anvil_forge_Collider_Stump")
    p.collider("Block", _s(10.4, 3.15, -1.0), (3.2, 2.3, 1.4), name="anvil_forge_Collider_Anvil")
    p.collider("Block", _s(12.8, 3.75, -1.0), (1.4, 0.9, 1.0), name="anvil_forge_Collider_Horn")
    p.collider("Cylinder", _s(bx, 0.55, bz), (1.1, 1.4, 1.4), (0, 0, 90), name="anvil_forge_Collider_Bucket")
    p.attach("Fire", _s(10.5, 3.5, 4.0))
    p.attach("ForgeLight", _s(10.5, 4.1, 3.7))
    p.attach("Sparks", _s(10.25, 4.12, -1.0))
    p.attach("Smoke", _s(11.6, 9.4, 5.2))
    return p


RECIPES = {"fountain": fountain, "anvil_forge": anvil_forge}
