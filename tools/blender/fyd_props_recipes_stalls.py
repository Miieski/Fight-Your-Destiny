"""Prop recipes, batch 4 (Blender half of the stalls): weapon_stall, trophy_stall, diamond_shop.

Each FBX holds ONLY the Blender pieces (awning, display items, sign, gems); Agent B rebuilds the frames in Studio.
Space = STALL space: origin = the stall pivot (floor centre), front -Z, studs (docs/prop_inventory.md "shared stall
frame"). Pieces whose current position is NOT in the inventory (the weapon stall's wall items and counter tray, the
diamond sign) carry an ANCHOR: they are modelled where the anchor part is ASSUMED to be (AssumedPosition /
AssumedRotation); ApplyPropMeshes finds the real part (by name, the copy nearest to the assumed position) and re-bases
the mesh: MeshPart.CFrame = realPart.CFrame * assumedCFrame:Inverse() * meshCFrame. So they land exactly even if the
assumption is off. Meshes without an anchor are placed at stall pivot * CFrame.new(Center).
"""
import math
import random

from mathutils import Matrix, Vector

import fyd_props as P

STALL_SIZE = (15.6, 11.11, 15.5)   # today's stall frame + awning (without the forge), for the bevel ratio


def _frame_context(p, panel="WoodMid"):
    """Today's frame (inventory "shared stall frame"), render-only."""
    for s in (-1, 1):
        p.context.append(((s * 6.55, 4.2, -3.55), (0.9, 8.4, 0.9), "WoodDark", (0, 0, 0)))
        p.context.append(((s * 6.55, 5.2, 3.55), (0.9, 10.4, 0.9), "WoodDark", (0, 0, 0)))
        p.context.append(((s * 6.55, 1.6, 0.0), (0.6, 3.2, 6.4), panel, (0, 0, 0)))
    p.context.append(((0, 1.6, -2.9), (12.4, 3.2, 1.8), panel, (0, 0, 0)))
    p.context.append(((0, 3.45, -2.9), (14.4, 0.5, 2.6), "WoodLight", (0, 0, 0)))
    p.context.append(((0, 5.6, 3.55), (13.0, 7.4, 0.5), panel, (0, 0, 0)))
    p.context.append(((0, 9.3, 3.55), (14.0, 0.6, 0.6), "WoodDark", (0, 0, 0)))


AWNING_REPLACES = [
    {"What": "awning stripes", "Count": 7, "Size": [2.23, 0.45, 11.6], "At": "y 9.6, pitch -13 (front lower)"},
    {"What": "awning fringe blocks", "Count": 7, "Size": [2.23, 1.2, 0.35], "At": "(x, 7.75, -6.75)"},
]


def _awning(p, n, color_a, color_b, name_a, name_b, seed=0):
    """Cloth awning over today's slab: back edge (z 4.55, y 10.9) -> front edge (z -6.75, y 8.3), 15.6 wide; sags
    between the back beam (z 3.55) and the front post line (z -3.55), droops on the overhang, folds across, dips
    between the posts along the front edge; a scalloped valance panel under each stripe."""
    rng = random.Random(seed)
    a = p.mesh(name_a, "Cloth", color_a, replaces=AWNING_REPLACES)
    b = p.mesh(name_b, "Cloth", color_b, replaces="(same awning as " + p.id + "_" + name_a + ")")
    W, ZB, ZF, YB, YF = 15.6, 4.55, -6.75, 10.9, 8.3
    sb, sf = (ZB - 3.55) / (ZB - ZF), (ZB + 3.55) / (ZB - ZF)
    sw = W / n

    def point(x, s):
        z = ZB + (ZF - ZB) * s
        y = YB + (YF - YB) * s
        if sb < s < sf:
            y -= 0.22 * math.sin(math.pi * (s - sb) / (sf - sb))
        over = max(0.0, (s - sf) / (1 - sf))
        y -= 0.12 * over * over + 0.24 * (1 - (x / (W / 2)) ** 2) * over
        y += 0.05 * math.sin(2 * math.pi * x / sw + 0.6) * (0.4 + 0.6 * s)
        return (x, y, z)

    rows = [0.0, sb, 0.32, 0.5, sf, 0.86, 1.0]
    scallop = [(-sw / 2, 0.0), (sw / 2, 0.0), (sw / 2, -0.62)]
    scallop += [(sw / 2 * math.cos(t), -0.62 - 0.42 * math.sin(t)) for t in
                (math.pi / 6, 2 * math.pi / 6, 3 * math.pi / 6, 4 * math.pi / 6, 5 * math.pi / 6)]
    scallop += [(-sw / 2, -0.62)]
    for i in range(n):
        x0 = -W / 2 + i * sw
        cols = [x0 + sw * k / 3 for k in range(4)]          # ascending x: (du x dv) faces up
        pts = [[point(x, s) for s in rows] for x in cols]
        m = a if i % 2 == 0 else b
        m.grid(pts, thickness=0.06, sides=("top", "bottom", "u0", "u1", "v0", "v1"), smooth=False,
               tone=rng.uniform(0.92, 1.0))
        xc = x0 + sw / 2
        top = point(xc, 1.0)
        m.prism(scallop, 0.06, c=(xc, top[1] + 0.02, ZF - 0.04), bevel=0, tone=rng.uniform(0.9, 1.0))
    p.collider("Block", (0, 9.6, -1.1), (15.6, 0.45, 11.6), (-13, 0, 0), name=f"{p.id}_Collider_Awning")
    return a, b


def _anchor(part, pos, rot=(0, 0, 0), size=None, pick="nearest"):
    return {"Part": part, "Pick": pick, "AssumedPosition": [round(float(v), 3) for v in pos],
            "AssumedRotation": [round(float(v), 3) for v in rot], "PartSize": list(size) if size else None}


def _placement(host):
    return {"Host": host, "OriginInHost": [0, 0, 0], "RotationInHost": [0, 0, 0],
            "Note": "pieces only: the frame (posts, counter, backboard) is Studio-built by Agent B; Interact, NameTag, "
                    "NpcSpot and NPC stay Studio children"}


# ------------------------------------------------------------------------------------------------
# small builders shared by the stalls
# ------------------------------------------------------------------------------------------------
def _sword(blade, gold, grip, base, length=4.4, width=0.46, up=Vector((0, 1, 0)), across=Vector((1, 0, 0)), rng=None):
    """A straight sword lying in the plane (up, across); base = the blade's bottom centre (on the guard)."""
    up, across = up.normalized(), across.normalized()
    normal = across.cross(up)
    to_world = Matrix((across, up, normal)).transposed()

    def w(x, y, z=0.0):
        return tuple(Vector(base) + to_world @ Vector((x, y, z)))

    # the blade: outline in (across, up), extruded along the normal, then a dark fuller strip on both faces
    outline = [(-width / 2, 0.0), (width / 2, 0.0), (width * 0.43, length * 0.86), (0.0, length), (-width * 0.43, length * 0.86)]
    c = Vector(base) + up * 0.0
    rot_e = to_world.to_euler("ZYX")
    blade.prism(outline, 0.13, c=tuple(c), rot=tuple(math.degrees(v) for v in (rot_e.x, rot_e.y, rot_e.z)), bevel=0.035,
                grain="y")
    for side in (-1, 1):
        f = [w(-0.05, 0.25, side * 0.068), w(0.05, 0.25, side * 0.068), w(0.05, length * 0.7, side * 0.068),
             w(-0.05, length * 0.7, side * 0.068)]
        blade.poly(f, normal=tuple(normal * side), tone=0.5)
    # guard with ball quillons, grip with a wrapped ridge, pommel (all scaled with the blade width)
    k = width / 0.46
    gold.beam(w(-0.55 * k, -0.1 * k), w(0.55 * k, -0.1 * k), 0.22 * k, 0.28 * k, up=tuple(up), bevel="long")
    for side in (-1, 1):
        gold.ico(w(side * 0.63 * k, -0.1 * k), 0.13 * k, sub=1, jit=0.0)
    gl = 0.95 * k
    pts = [w(0, -0.2 * k - gl * i / 6) for i in range(7)]
    grip.tube(pts, [(0.11 if i % 2 else 0.125) * k for i in range(7)], segs=6, smooth=False)
    gold.ico(w(0, -0.28 * k - gl), 0.16 * k, sub=1, jit=0.0)


def _brilliant(mesh, center, r, height, squash=1.0, segs=16, table=0.55, crown=0.33):
    """Faceted brilliant cut, table up, culet down: girdle radius r, total height `height`, depth scaled by squash."""
    hc, hp = height * crown, height * (1 - crown)
    prof = [(0.02, -hp), (r * 0.5, -hp * 0.48), (r, -0.03 * height), (r, 0.03 * height), (r * table, hc)]
    mesh.lathe(prof, c=center, segs=segs, smooth=False, scale=(1, 1, squash))


# ------------------------------------------------------------------------------------------------
# 14/19 WEAPON STALL - Hub.WeaponShop (kit MapAssets.Hub.Station_WeaponShop). Inventory: red (212,52,60) / cream
# (232,226,208) awning; 3 swords on the back wall (SwordBlade 0.5 x 4.4 x 0.2 (92,98,110), SwordGuard 1.6 x 0.35 x 0.35
# gold, SwordGrip (112,62,38)), Shield cyl 0.4 x 2.6 (74,108,220) + ShieldBoss 1.0 gold, AxeHead 2 x 1.8 x 0.3 +
# AxeHandle 0.4 x 5 x 0.4, DisplaySword on the counter (blade 1.6 x 0.3 x 4.6 = the "blue tray" of photo 14 + guard
# 0.5 x 0.4 x 1.4 gold). Their positions are not in the inventory: anchored (assumed from photos 14 / 19, where +X is
# on the LEFT: shield and axe at +X, swords right of the centre).
# ------------------------------------------------------------------------------------------------
def weapon_stall():
    p = P.Prop("weapon_stall", photo="19_weapon_stall.png", size=STALL_SIZE, budget=8000, tool="Studio frame (Agent B) + Blender pieces", view=(-8, 5),
               view2=(-40, 30), notes="Blender pieces of Hub.WeaponShop (awning 8 stripes, 3 swords, shield, axe, tray); "
                                      "frame by Agent B; wall items + tray anchored")
    p.placement = _placement("Hub.WeaponShop (and the kit / test copies of Station_WeaponShop)")
    _frame_context(p)
    rng = random.Random(19)
    _awning(p, 8, "ClothRed", "ClothCream", "AwningRed", "AwningCream", seed=19)
    # 3 swords on the back wall (tips up), each anchored to its SwordBlade
    for k, x in enumerate((-0.6, -2.2, -3.8)):
        anc = _anchor("SwordBlade", (x, 6.4, 3.2), size=(0.5, 4.4, 0.2))
        rep = ["SwordBlade", "SwordGuard", "SwordGrip"]
        blade = p.mesh(f"Sword{k + 1}Blade", "Iron", "Iron", shadow=False, anchor=anc, replaces=rep)
        gold = p.mesh(f"Sword{k + 1}Gold", "Gold", "Gold", shadow=False, anchor=anc, replaces="(with the blade)")
        grip = p.mesh(f"Sword{k + 1}Grip", "Cloth", "WoodDark", shadow=False, anchor=anc, replaces="(with the blade)")
        _sword(blade, gold, grip, (x, 4.2, 3.2), rng=rng)
    # round shield on the wall: planked face (blue), iron rim and rivets, gold boss (both sides: orientation-proof)
    anc = _anchor("Shield", (3.6, 6.3, 3.15), (0, 90, 0), (0.4, 2.6, 2.6))
    face = p.mesh("ShieldFace", "Planks", "ClothBlueAlt", shadow=False, anchor=anc, replaces=["Shield", "ShieldBoss"])
    rim = p.mesh("ShieldRim", "Iron", "Iron", shadow=False, anchor=anc, replaces="(with the shield)")
    boss = p.mesh("ShieldBoss", "Gold", "Gold", shadow=False, anchor=anc, replaces="(with the shield)")
    sc = Vector((3.6, 6.3, 3.15))
    face.cyl(tuple(sc + Vector((0, 0, 0.17))), tuple(sc - Vector((0, 0, 0.17))), 1.24, segs=16, smooth=False, bevel=0)
    rim.ring(tuple(sc), 1.2, 1.32, 0.42, segs=16, axis="z")
    for k in range(8):
        t = 2 * math.pi * (k + 0.5) / 8
        pt = sc + Vector((math.cos(t) * 1.02, math.sin(t) * 1.02, -0.17))
        rim.spike(tuple(pt), tuple(pt + Vector((0, 0, -0.08))), 0.07, segs=4)
    boss.ico(tuple(sc + Vector((0, 0, -0.2))), 0.42, scale=(1, 1, 0.55), sub=2, jit=0.0, smooth=True)
    boss.ring(tuple(sc + Vector((0, 0, -0.18))), 0.42, 0.55, 0.05, segs=12, axis="z", faces=("outer", "top", "bottom"))
    boss.ico(tuple(sc + Vector((0, 0, 0.2))), 0.36, scale=(1, 1, 0.5), sub=1, jit=0.0)
    # axe hanging diagonally (head up, toward +X), double-bit head so either way round reads right
    rz = -20
    R = Matrix.Rotation(math.radians(rz), 3, "Z")
    hc = Vector((2.4, 5.9, 3.15))
    head_c = hc + R @ Vector((0, 2.0, 0))
    handle = p.mesh("AxeHandle", "Wood", "WoodDark", shadow=False, anchor=_anchor("AxeHandle", tuple(hc), (0, 0, rz), (0.4, 5, 0.4)),
                    replaces=["AxeHandle"])
    head = p.mesh("AxeHead", "Iron", "IronWorn", shadow=False, anchor=_anchor("AxeHead", tuple(head_c), (0, 0, rz), (2, 1.8, 0.3)),
                  replaces=["AxeHead"])
    pts = [tuple(hc + R @ Vector((0, y, 0))) for y in (-2.5, -1.2, 0.0, 1.3, 2.45)]
    handle.tube(pts, [0.16, 0.17, 0.17, 0.16, 0.15], segs=6, smooth=False)
    bit = [(0.0, -0.32), (0.55, -0.4), (0.95, -0.85), (1.0, 0.0), (0.95, 0.85), (0.55, 0.4), (0.0, 0.32),
           (-0.55, 0.4), (-0.95, 0.85), (-1.0, 0.0), (-0.95, -0.85), (-0.55, -0.4)]
    head.prism(bit, 0.22, c=tuple(head_c), rot=(0, 0, rz), bevel=0.04, grain="x")
    # the "blue tray" on the counter: a wooden display tray with grey-blue velvet and a dagger, anchored to DisplaySword
    anc = _anchor("DisplaySword", (-3.6, 3.85, -2.9), (0, 90, 0), (1.6, 0.3, 4.6))
    tray = p.mesh("TrayWood", "Wood", "WoodDark", shadow=False, anchor=anc,
                  replaces=["DisplaySword (blade 1.6 x 0.3 x 4.6)", "DisplaySword guard (0.5 x 0.4 x 1.4)"])
    velvet = p.mesh("TrayVelvet", "Cloth", "Iron", shadow=False, anchor=anc, replaces="(with the tray)")
    dblade = p.mesh("DaggerBlade", "Iron", "Iron", shadow=False, anchor=anc, replaces="(with the tray)")
    dgold = p.mesh("DaggerGold", "Gold", "Gold", shadow=False, anchor=anc, replaces="(with the tray)")
    dgrip = p.mesh("DaggerGrip", "Cloth", "WoodDark", shadow=False, anchor=anc, replaces="(with the tray)")
    tx, ty, tz = -3.6, 3.7, -2.9
    tray.box((tx, ty + 0.06, tz), (4.7, 0.12, 1.7), bevel=0.03, drop=((0, -1, 0),))
    for dz in (-0.8, 0.8):
        tray.box((tx, ty + 0.17, tz + dz), (4.7, 0.12, 0.1), bevel=0, grain="x")
    for dx in (-2.3, 2.3):
        tray.box((tx + dx, ty + 0.17, tz), (0.1, 0.12, 1.5), bevel=0, grain="z")
    velvet.box((tx, ty + 0.15, tz), (4.5, 0.06, 1.5), bevel=0, drop=((0, -1, 0),))
    _sword(dblade, dgold, dgrip, (tx - 0.95, ty + 0.27, tz), length=2.3, width=0.34, up=Vector((1, 0, 0)),
           across=Vector((0, 0, 1)), rng=rng)
    p.attach("ShieldGlint", (3.6, 6.3, 2.9))
    return p


# ------------------------------------------------------------------------------------------------
# 18 TROPHY STALL - Hub.TrophyMerchant: green (40,124,58) / cream awning; TrophyCup (3 gold cylinders) at
# (-3.5, 3.9..5.5, -2.9); CounterSkull ball 1.5 (240,232,208) at (2.5, 4.4, -2.9) -> the brief's crystal ball.
# ------------------------------------------------------------------------------------------------
def trophy_stall():
    p = P.Prop("trophy_stall", photo="18_trophy_stall.png", size=STALL_SIZE, budget=8000, tool="Studio frame (Agent B) + Blender pieces", view=(-8, 6),
               view2=(-40, 30), notes="Blender pieces of Hub.TrophyMerchant (awning, trophy cup, crystal ball)")
    p.placement = _placement("Hub.TrophyMerchant (and the kit / test copies of Station_TrophyMerchant)")
    _frame_context(p)
    _awning(p, 7, "ClothGreen", "ClothCream", "AwningGreen", "AwningCream", seed=18)
    gold = p.mesh("Gold", "Gold", "Gold", shadow=False,
                  replaces=["TrophyCup (3 gold cylinders at (-3.5, 3.9..5.5, -2.9))"])
    wood = p.mesh("Wood", "Wood", "WoodDark", shadow=False, replaces="(trophy plinth, ball stand base)")
    ball = p.mesh("Ball", "Glass", "#CDEBF5", shadow=False, transparency=0.3,
                  replaces=["CounterSkull (ball 1.5 at (2.5, 4.4, -2.9))"])
    core = p.mesh("BallCore", "Glow", "#B39DFF", shadow=False, replaces="(inside the crystal ball)")
    # trophy: wooden plinth with a gold plaque, gold cup with two handles
    cx, cz, top = -3.5, -2.9, 3.7
    wood.box((cx, top + 0.22, cz), (1.3, 0.44, 1.0), bevel="all")
    gold.box((cx, top + 0.22, cz - 0.515), (0.8, 0.24, 0.03), bevel=0, drop=((0, 0, 1),))
    gold.lathe([(0.5, top + 0.44), (0.5, top + 0.54), (0.3, top + 0.61), (0.12, top + 0.7), (0.12, top + 0.92),
                (0.2, top + 0.98), (0.12, top + 1.06), (0.28, top + 1.15), (0.55, top + 1.45), (0.66, top + 1.85),
                (0.6, top + 1.88), (0.5, top + 1.5), (0.2, top + 1.25), (0.05, top + 1.2)], c=(cx, 0, cz), segs=16,
               smooth=True)
    for s in (-1, 1):
        gold.tube([(cx + s * 0.58, top + 1.62, cz), (cx + s * 0.95, top + 1.58, cz), (cx + s * 1.0, top + 1.32, cz),
                   (cx + s * 0.82, top + 1.18, cz), (cx + s * 0.42, top + 1.2, cz)], 0.06, segs=5)
    # crystal ball on a small gold claw stand, with a glowing core for the shimmer
    bx, bz = 2.5, -2.9
    wood.cyl((bx, top, bz), (bx, top + 0.12, bz), 0.5, segs=10, bevel=0.03)
    gold.lathe([(0.42, top + 0.12), (0.42, top + 0.2), (0.25, top + 0.28), (0.2, top + 0.36), (0.36, top + 0.46),
                (0.38, top + 0.5)], c=(bx, 0, bz), segs=12, smooth=False)
    for k in range(3):
        t = 2 * math.pi * k / 3 + 0.3
        d = Vector((math.cos(t), 0, math.sin(t)))
        base = Vector((bx, top + 0.45, bz)) + d * 0.32
        gold.tube([tuple(base), tuple(base + d * 0.32 + Vector((0, 0.3, 0))), tuple(base + d * 0.42 + Vector((0, 0.62, 0)))],
                  0.05, segs=4)  # claws hug the outside of the ball
    by = top + 1.15
    ball.ico((bx, by, bz), 0.68, sub=3, jit=0.0, smooth=True)
    core.ico((bx, by, bz), 0.3, sub=2, jit=0.06, smooth=True)
    p.attach("BallShimmer", (bx, by, bz))
    p.attach("TrophyGlint", (cx + 0.4, top + 1.7, cz - 0.5))
    return p


# ------------------------------------------------------------------------------------------------
# 20 DIAMOND SHOP - Hub.DiamondShop: blue (64,120,212) / white (245,246,250) awning; sign = SignPost 0.8 x 4.4 x 0.8 +
# SignBar 9 x 0.6 x 0.6 (gold) at y 12.2, Diamond (block 4.8 x 1.8 x 1.4 + 4 wedges, Neon 95,212,255) with DiamondGirdle
# 4.9 x 0.3 x 1.5 (Neon white) at y 16.3..19.3; 3 Cushions 2.2 x 0.5 x 1.6 (74,108,220) with 3 gems (cyan, gold, cyan) at
# x -4 / 0 / 4. The sign's x / z are not in the inventory: anchored (assumed above the stall centre).
# ------------------------------------------------------------------------------------------------
def diamond_shop():
    p = P.Prop("diamond_shop", photo="20_diamond_shop.png", size=STALL_SIZE, budget=8000, tool="Studio frame (Agent B) + Blender pieces", view=(-8, 8),
               view2=(-40, 28), notes="Blender pieces of Hub.DiamondShop (awning, diamond sign, sign bar/post, 3 gems on "
                                      "cushions); sign anchored; the Diamond Shop label stays a Studio child")
    p.placement = _placement("Hub.DiamondShop (and the kit / test copies of Station_DiamondShop)")
    _frame_context(p)
    _awning(p, 7, "ClothBlue", "ClothWhite", "AwningBlue", "AwningWhite", seed=20)
    SZ = 1.0                                      # assumed z of the sign (not in the inventory)
    G = Vector((0, 18.3, SZ))                     # assumed girdle centre (diamond spans y 16.35 .. 19.25 like today)
    centre = (0, 17.8, SZ)                        # pivot: the middle of the diamond (PropFX floats / rotates it)
    anc = _anchor("DiamondGirdle", tuple(G), (0, 0, 0), (4.9, 0.3, 1.5))
    dia = p.mesh("Diamond", "Glow", "Diamond", pivot=centre, shadow=False, anchor=anc,
                 replaces=["Diamond (block + 4 wedges)", "DiamondGirdle"])
    rim = p.mesh("DiamondRim", "Glow", "ClothWhite", pivot=centre, shadow=False, anchor=anc, replaces="(the bright rim)")
    _brilliant(dia, tuple(G), 2.45, 2.9, squash=0.31, segs=16)
    rim.lathe([(2.4, -0.12), (2.54, -0.12), (2.54, 0.12), (2.4, 0.12), (2.4, -0.12)], c=tuple(G), segs=16, smooth=False,
              scale=(1, 1, 0.31), caps=(False, False))
    # gold sign bar with finials and a moulded post up to the diamond
    sign = p.mesh("SignGold", "Gold", "Gold", shadow=False, anchor=_anchor("SignBar", (0, 12.2, SZ), (0, 0, 0), (9, 0.6, 0.6)),
                  replaces=["SignBar", "SignPost"])
    sign.beam((-4.4, 12.2, SZ), (4.4, 12.2, SZ), 0.45, 0.45)
    for s in (-1, 1):
        sign.ico((s * 4.6, 12.2, SZ), 0.32, sub=1, jit=0.0)
    sign.lathe([(0.42, 12.4), (0.42, 12.6), (0.3, 12.75), (0.26, 15.8), (0.36, 16.0), (0.5, 16.25), (0.3, 16.4)],
               c=(0, 0, SZ), segs=10, smooth=False)
    # three cushions with gold tassels, gems nested in them (cyan, gold, cyan)
    cush = p.mesh("Cushions", "Cloth", "ClothBlueAlt", shadow=False, replaces=["Cushion x3 (2.2 x 0.5 x 1.6 at x -4 / 0 / 4)"])
    tas = p.mesh("Tassels", "Gold", "Gold", shadow=False, replaces="(cushion tassels)")
    cyan = p.mesh("GemsCyan", "Glow", "Diamond", shadow=False, replaces=["the 2 cyan gems (5 Neon pieces each) at x -4 / 4"])
    yel = p.mesh("GemGold", "Glow", "OreGold", shadow=False, replaces=["the gold gem (5 Neon pieces) at x 0"])
    grims = p.mesh("GemRims", "Glow", "ClothWhite", shadow=False, replaces="(bright girdles of the 3 gems)")
    top, cz = 3.7, -2.9

    def pillow(v):  # unit sphere -> rounded-square pillow, puffier in the middle
        sx, sz = math.copysign(abs(v.x) ** 0.55, v.x), math.copysign(abs(v.z) ** 0.55, v.z)
        return Vector((sx * 1.1, v.y * 0.3 * (1.0 - 0.35 * (sx * sx + sz * sz) / 2), sz * 0.8))

    for x in (-4.0, 0.0, 4.0):
        cush.ico((x, top + 0.24, cz), 1.0, sub=2, jit=0.0, smooth=True, deform=pillow)
        for sx in (-1, 1):
            for szs in (-1, 1):
                base = Vector((x + sx * 1.03, top + 0.2, cz + szs * 0.74))
                tas.ico(tuple(base), 0.07, sub=1, jit=0.0)
                tas.spike(tuple(base), tuple(base + Vector((sx * 0.06, -0.32, szs * 0.05))), 0.075, segs=4)
        gy = top + 0.82
        _brilliant(cyan if x else yel, (x, gy, cz), 0.56, 0.86, segs=12)
        grims.lathe([(0.55, -0.035), (0.585, -0.035), (0.585, 0.035), (0.55, 0.035), (0.55, -0.035)], c=(x, gy, cz), segs=12,
                    smooth=False, caps=(False, False))
        p.attach(f"GemGlint{int(x / 4) + 2}", (x + 0.15, top + 1.0, cz - 0.2))
    p.attach("DiamondCenter", centre)
    p.attach("SignGlint", (0.8, 18.9, SZ - 0.3))
    return p


RECIPES = {"weapon_stall": weapon_stall, "trophy_stall": trophy_stall, "diamond_shop": diamond_shop}
