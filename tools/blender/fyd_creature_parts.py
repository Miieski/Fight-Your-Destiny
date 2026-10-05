"""Shared family builders for the creature recipes (Roblox model space, studs, the creature faces -Z, feet on y = 0).

Each builder creates the segmented rig of its family (joint names of Blender/Rigs/README.txt) with low-poly faceted
shapes, and returns the parts so a recipe can add the details of its species. Colors are "#rrggbb".
Style (brief Part D): visible facets, chunky readable silhouettes, slightly big heads, big glossy dark eyes,
clothing layers / belts / boots for humanoids.
"""
import math

EYE = "#121016"
SHINE = "#f4f4f4"


def shade(hexcolor, k):
    """Darker (k < 1) or lighter (k > 1) version of a color."""
    h = hexcolor.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if k >= 1:
        r, g, b = (int(c + (255 - c) * (k - 1)) for c in (r, g, b))
    else:
        r, g, b = (int(c * k) for c in (r, g, b))
    return "#%02x%02x%02x" % tuple(max(0, min(255, c)) for c in (r, g, b))


def eyes(part, x, y, z, r=0.1, color=EYE, shine=True, depth=0.6):
    """Two glossy eyes facing -Z at (+-x, y, z)."""
    for s in (-1, 1):
        part.ico((s * x, y, z), r, (1, 1, depth), color, sub=1)
        if shine:
            part.ico((s * x + 0.3 * r, y + 0.3 * r, z - r * depth * 0.8), r * 0.3, (1, 1, 0.5), SHINE, sub=0)


# ------------------------------------------------------------------------------------------------
# QUADRUPED: Body; Head, LegFL, LegFR, LegBL, LegBR, Tail
# ------------------------------------------------------------------------------------------------
def quadruped(m, fur, belly=None, dark=None, body_len=1.8, body_h=0.9, body_w=1.0, leg_len=1.2, leg_r=0.24,
              head_r=0.75, snout_len=0.6, snout_r=0.33, ears="pointy", tail="bushy", paws=None, jit=0.05,
              head_up=0.25, neck=0.0):
    """Generic four-legged animal. Body center at height leg_len + body_h * 0.8."""
    dark = dark or shade(fur, 0.6)
    belly = belly or shade(fur, 1.25)
    paws = paws or dark
    y0 = leg_len + body_h * 0.75
    zf, zb = -body_len * 0.55, body_len * 0.6
    body = m.part("Body", joint=(0, y0, 0))
    body.ico((0, y0, 0), 1.0, (body_w, body_h, body_len), fur, jit=jit)
    body.ico((0, y0 + body_h * 0.15, zf * 0.75), 0.85, (body_w * 0.95, body_h * 0.95, 0.9), fur, jit=jit)  # chest
    body.ico((0, y0 - body_h * 0.45, 0), 0.75, (body_w * 0.8, body_h * 0.45, body_len * 0.8), belly, sub=1, jit=jit * 0.5)
    hy = y0 + head_up + neck
    hz = zf - head_r * 0.9 - neck * 0.4
    head = m.part("Head", "Body", joint=(0, y0 + 0.2, zf * 0.9))
    if neck > 0:
        head.cone((0, y0 + 0.1, zf * 0.85), (0, hy, hz + head_r * 0.3), 0.5 * body_w, 0.4 * body_w, fur, segs=6)
    head.ico((0, hy, hz), head_r, (0.95, 0.9, 1.05), fur, jit=jit * 0.8)
    if snout_len > 0:
        head.cone((0, hy - head_r * 0.2, hz - head_r * 0.7), (0, hy - head_r * 0.28, hz - head_r * 0.7 - snout_len),
                  snout_r, snout_r * 0.75, belly, segs=6)
        head.ico((0, hy - head_r * 0.22, hz - head_r * 0.72 - snout_len), snout_r * 0.45, (1, 0.8, 0.6), EYE, sub=0)
    eyes(head, head_r * 0.45, hy + head_r * 0.25, hz - head_r * 0.78, r=head_r * 0.17)
    if ears == "pointy":
        for s in (-1, 1):
            head.cone((s * head_r * 0.5, hy + head_r * 0.6, hz + head_r * 0.15),
                      (s * head_r * 0.62, hy + head_r * 1.35, hz + head_r * 0.25), head_r * 0.3, 0, dark, segs=3)
    elif ears == "round":
        for s in (-1, 1):
            head.ico((s * head_r * 0.62, hy + head_r * 0.72, hz + head_r * 0.1), head_r * 0.27, (1, 1, 0.5), dark, sub=1)
    legs = {}
    for name, x, z in (("LegFL", -1, zf), ("LegFR", 1, zf), ("LegBL", -1, zb), ("LegBR", 1, zb)):
        lx = x * body_w * 0.55
        leg = m.part(name, "Body", joint=(lx, leg_len + 0.1, z))
        leg.ico((lx * 0.98, leg_len + 0.15, z), leg_r * 1.6, (0.85, 1.2, 1.0), fur, sub=1, jit=jit)
        leg.cone((lx, leg_len + 0.05, z), (lx, leg_r * 0.8, z), leg_r, leg_r * 0.8, fur, segs=6)
        leg.ico((lx, leg_r * 0.6, z - leg_r * 0.25), leg_r * 1.05, (1, 0.6, 1.3), paws, sub=1)
        legs[name] = leg
    tail_part = None
    if tail != "none":
        tail_part = m.part("Tail", "Body", joint=(0, y0 + body_h * 0.3, zb + body_len * 0.35))
        tz = zb + body_len * 0.35
        if tail == "bushy":
            tail_part.cone((0, y0 + body_h * 0.3, tz), (0, y0 - body_h * 0.1, tz + 1.3), 0.32, 0.16, fur, segs=6, jit=0.05)
            tail_part.ico((0, y0 - body_h * 0.15, tz + 1.35), 0.22, (1, 1, 1.4), belly, sub=1)
        elif tail == "long":
            tail_part.cone((0, y0 + body_h * 0.3, tz), (0, y0 - body_h * 0.6, tz + 1.6), 0.18, 0.07, fur, segs=5)
        else:  # short
            tail_part.cone((0, y0 + body_h * 0.3, tz), (0, y0 + body_h * 0.1, tz + 0.5), 0.14, 0.05, dark, segs=4)
    return {"Body": body, "Head": head, "Tail": tail_part, **legs, "head_at": (0, hy, hz), "y0": y0}


# ------------------------------------------------------------------------------------------------
# BIPED: Torso; Head, ArmL, ArmR, LegL, LegR   (reference 3: big head, clothing layers, belts, boots)
# ------------------------------------------------------------------------------------------------
def biped(m, skin="#e8b48a", shirt="#3f7a3f", pants="#5a4632", boots="#3a2a1e", belt="#2e2218", buckle="#d8b04a",
          gloves=None, head_r=0.72, bulk=1.0, sleeves=True, jit=0.02, hand=None):
    """Humanoid of ~5.5 (before scaling). bulk > 1 = brute (wider chest, thicker arms, smaller head)."""
    gloves = gloves or skin
    hand = hand or gloves
    w = bulk
    hip_y, chest_y, neck_y = 2.1, 3.05, 3.68
    torso = m.part("Torso", joint=(0, hip_y + 0.1, 0))
    torso.box((0, hip_y + 0.2, 0), (1.0 * w, 0.5, 0.62 * w), pants)
    torso.box((0, chest_y, 0), (1.18 * w, 1.25, 0.74 * w), shirt, taper=1.12)
    torso.box((0, hip_y + 0.48, 0), (1.12 * w, 0.2, 0.7 * w), belt)
    torso.box((0, hip_y + 0.48, -0.36 * w), (0.22, 0.16, 0.06), buckle)
    hy = neck_y + head_r * 0.95
    head = m.part("Head", "Torso", joint=(0, neck_y, 0))
    head.cyl((0, neck_y - 0.12, 0), (0, neck_y + 0.25, 0), 0.19 * w, skin, segs=6)
    head.ico((0, hy, -0.02), head_r, (1.0, 1.05, 0.95), skin, sub=1, jit=jit)
    eyes(head, head_r * 0.34, hy + head_r * 0.08, -head_r * 0.86, r=head_r * 0.12)
    head.cone((0, hy - head_r * 0.12, -head_r * 0.85), (0, hy - head_r * 0.22, -head_r * 1.08), head_r * 0.13, 0.02, shade(skin, 0.9), segs=4)
    arms = {}
    ax = 0.72 * w + 0.08
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        arm = m.part(name, "Torso", joint=(s * ax, 3.48, 0))
        arm.ico((s * ax, 3.5, 0), 0.27 * w, (1, 1, 1), shirt, sub=1)  # shoulder
        arm.cone((s * ax, 3.45, 0), (s * (ax + 0.08), 2.72, 0), 0.2 * w, 0.17 * w, shirt if sleeves else skin, segs=6)
        arm.cone((s * (ax + 0.08), 2.75, 0), (s * (ax + 0.12), 2.05, -0.05), 0.16 * w, 0.14 * w, gloves, segs=6)
        arm.ico((s * (ax + 0.12), 1.92, -0.07), 0.17 * w, (1, 1.1, 1), hand, sub=1)
        arms[name] = arm
    legs = {}
    for name, s in (("LegL", -1), ("LegR", 1)):
        lx = 0.3 * w
        leg = m.part(name, "Torso", joint=(s * lx, hip_y, 0))
        leg.cone((s * lx, hip_y + 0.05, 0), (s * lx, 1.1, 0), 0.3 * w, 0.24 * w, pants, segs=6)
        leg.cone((s * lx, 1.12, 0), (s * lx, 0.42, 0), 0.23 * w, 0.21 * w, pants, segs=6)
        leg.box((s * lx, 0.25, -0.1), (0.46 * w, 0.5, 0.78 * w), boots, taper=0.85)
        legs[name] = leg
    hands = {"L": (-(ax + 0.12), 1.92, -0.07), "R": (ax + 0.12, 1.92, -0.07)}
    return {"Torso": torso, "Head": head, **arms, **legs, "head_y": hy, "head_r": head_r, "hands": hands, "ax": ax}


def sword(part, hand, length=2.2, blade="#c9ccd2", hilt="#5a3a22", guard="#b08a3a", width=0.22, curve=0.0):
    """Sword in a hanging hand, blade pointing forward and a bit down (rest pose)."""
    x, y, z = hand
    part.cyl((x, y + 0.25, z + 0.05), (x, y - 0.2, z - 0.05), 0.07, hilt, segs=5)
    part.box((x, y - 0.22, z - 0.08), (0.12, 0.12, 0.55), guard)
    tip = (x, y - 0.35 + curve, z - length)
    part.cone((x, y - 0.25, z - 0.15), tip, width, 0.02, blade, segs=4)


def axe(part, hand, length=2.4, haft="#6a4a2e", head="#9aa0a8", big=False):
    x, y, z = hand
    part.cyl((x, y + 0.3, z), (x, y - 0.1, z - length), 0.08, haft, segs=5)
    s = 1.6 if big else 1.0
    part.box((x, y - 0.05, z - length + 0.3), (0.12, 0.7 * s, 0.6 * s), head, rot=(0, 0, 0))


def club(part, hand, length=2.6, wood="#7a5a3a", spikes="#c8c0b0"):
    x, y, z = hand
    part.cone((x, y + 0.2, z), (x, y - 0.4, z - length), 0.12, 0.35, wood, segs=6, jit=0.05)
    for i in range(3):
        part.cone((x, y - 0.3, z - length * (0.7 + i * 0.1)), (x + 0.3, y - 0.1, z - length * (0.72 + i * 0.1)), 0.06, 0, spikes, segs=3)


def spear(part, hand, length=4.0, shaft="#7a5a3a", tip="#b8bcc4"):
    x, y, z = hand
    part.cyl((x, y, z + 1.0), (x, y, z - length + 1.0), 0.07, shaft, segs=5)
    part.cone((x, y, z - length + 1.0), (x, y, z - length + 0.3), 0.16, 0, tip, segs=4)


def bow(part, hand, size=2.2, wood="#6a4426", string="#e8e0c8"):
    """Bow in a hanging hand, limbs along z (vertical when the arm is raised forward)."""
    x, y, z = hand
    half = size / 2
    part.cone((x, y, z), (x, y - 0.25, z - half), 0.07, 0.04, wood, segs=4)
    part.cone((x, y, z), (x, y - 0.25, z + half), 0.07, 0.04, wood, segs=4)
    part.cyl((x, y - 0.25, z - half), (x, y - 0.25, z + half), 0.015, string, segs=3)


def staff(part, hand, length=4.2, wood="#5a3a22", top="#7cf0a0", top_r=0.3):
    x, y, z = hand
    part.cyl((x, y + 1.2, z), (x, y - length + 1.2, z), 0.09, wood, segs=5)
    part.ico((x, y + 1.35, z), top_r, (1, 1, 1), top, sub=1)


# ------------------------------------------------------------------------------------------------
# BIRD: Body; Head, WingL, WingR, Tail, LegL, LegR (built standing; the game hovers it)
# ------------------------------------------------------------------------------------------------
def bird(m, body, wing=None, belly=None, beak="#f0a030", legs="#e09030", head_r=0.48, wing_span=2.0, jit=0.04,
         bat=False):
    wing = wing or shade(body, 0.8)
    belly = belly or shade(body, 1.2)
    b = m.part("Body", joint=(0, 1.5, 0))
    b.ico((0, 1.5, 0.05), 0.75, (0.85, 0.75, 1.25), body, jit=jit)
    b.ico((0, 1.3, -0.2), 0.55, (0.75, 0.6, 0.9), belly, sub=1, jit=jit * 0.5)
    h = m.part("Head", "Body", joint=(0, 1.85, -0.75))
    h.ico((0, 2.1, -0.95), head_r, (0.9, 0.9, 1.0), body, jit=jit * 0.6)
    eyes(h, head_r * 0.48, 2.2, -0.95 - head_r * 0.75, r=head_r * 0.2)
    if bat:
        for s in (-1, 1):
            h.cone((s * 0.25, 2.4, -0.9), (s * 0.45, 2.95, -0.85), 0.16, 0, wing, segs=3)
        h.cone((0, 1.95, -1.35), (0, 1.85, -1.45), 0.12, 0.05, shade(body, 1.3), segs=4)
    else:
        h.cone((0, 2.05, -0.95 - head_r * 0.85), (0, 1.95, -0.95 - head_r * 0.85 - 0.6), 0.17, 0.0, beak, segs=4)
    wings = {}
    for name, s in (("WingL", -1), ("WingR", 1)):
        wpart = m.part(name, "Body", joint=(s * 0.55, 1.75, -0.05))
        span = wing_span
        if bat:
            wpart.box((s * (0.55 + span * 0.45), 1.72, 0.05), (span * 0.9, 0.08, 1.0), wing, taper=1.0)
            for k in range(3):
                wpart.cone((s * 0.55, 1.75, -0.1), (s * (0.55 + span * (0.5 + 0.25 * k)), 1.75, 0.4 + 0.2 * k), 0.05, 0.02, shade(wing, 0.7), segs=3)
        else:
            wpart.box((s * (0.55 + span * 0.42), 1.75, 0.05), (span * 0.85, 0.12, 0.95), wing)
            wpart.box((s * (0.55 + span * 0.62), 1.75, 0.35), (span * 0.5, 0.1, 0.7), shade(wing, 0.75))
            for k in range(3):  # primary feathers at the wing tip
                wpart.cone((s * (0.55 + span * 0.8), 1.75, 0.1 + k * 0.25), (s * (0.55 + span * 1.05), 1.75, 0.35 + k * 0.32),
                           0.1, 0.0, shade(wing, 0.7), segs=3)
        wings[name] = wpart
    t = m.part("Tail", "Body", joint=(0, 1.55, 0.8))
    t.box((0, 1.55, 1.25), (0.65, 0.1, 0.8), wing, taper=1.0)
    for k in (-1, 0, 1):
        t.cone((k * 0.2, 1.55, 1.5), (k * 0.35, 1.55, 1.95), 0.1, 0.0, shade(wing, 0.75), segs=3)
    lgs = {}
    for name, s in (("LegL", -1), ("LegR", 1)):
        lp = m.part(name, "Body", joint=(s * 0.25, 1.0, 0.1))
        lp.cyl((s * 0.25, 1.0, 0.1), (s * 0.25, 0.15, 0.1), 0.07, legs, segs=4)
        lp.box((s * 0.25, 0.08, -0.05), (0.3, 0.12, 0.45), legs)
        lgs[name] = lp
    return {"Body": b, "Head": h, **wings, "Tail": t, **lgs}


# ------------------------------------------------------------------------------------------------
# SERPENT: Seg1; Head (Seg1), Seg2 (Seg1) ... Seg6 (Seg5)
# ------------------------------------------------------------------------------------------------
def serpent(m, color, pattern, belly=None, head_r=0.62, segs=6, thick=0.55, jit=0.03, tongue="#d23a4a"):
    belly = belly or shade(color, 1.25)
    z = -1.0
    prev = None
    for i in range(1, segs + 1):
        r = thick * (1.0 - (i - 1) * 0.12)
        cz = z + (i - 1) * 1.15
        p = m.part(f"Seg{i}", prev, joint=(0, r, cz - 0.55))
        col = color if i % 2 else pattern
        p.ico((0, r, cz), r, (1.0, 0.85, 1.25), col, jit=jit)
        p.ico((0, r * 0.55, cz), r * 0.8, (0.9, 0.4, 1.1), belly, sub=1)
        if i % 2 == 0:
            p.box((0, r * 1.75, cz), (r * 0.7, 0.08, r * 1.2), pattern)
        prev = f"Seg{i}"
    h = m.part("Head", "Seg1", joint=(0, thick, -1.5))
    h.ico((0, thick * 1.15, -2.0), head_r, (1.0, 0.75, 1.35), color, jit=jit)
    eyes(h, head_r * 0.6, thick * 1.45, -2.45, r=head_r * 0.2)
    h.cone((0, thick * 0.95, -2.75), (0, thick * 0.9, -3.3), 0.05, 0.02, tongue, segs=3)
    return h


# ------------------------------------------------------------------------------------------------
# ARACHNID: Body; Abdomen, LegL1-4, LegR1-4 (+ Tail, ArmL, ArmR for the scorpion)
# ------------------------------------------------------------------------------------------------
def arachnid(m, body, abdomen=None, legs=None, eye="#e02828", leg_reach=2.4, abd_scale=1.0, jit=0.05, fangs="#d8d0b8"):
    abdomen = abdomen or body
    legs = legs or shade(body, 0.8)
    b = m.part("Body", joint=(0, 1.55, -0.5))
    b.ico((0, 1.55, -0.55), 0.85, (1.0, 0.7, 1.0), body, jit=jit)
    for k, (x, y) in enumerate(((0.22, 1.85), (-0.22, 1.85), (0.38, 1.7), (-0.38, 1.7))):
        b.ico((x, y, -1.3), 0.1 if k < 2 else 0.07, (1, 1, 0.6), eye, sub=0)
    for s in (-1, 1):
        b.cone((s * 0.22, 1.25, -1.25), (s * 0.18, 0.75, -1.4), 0.12, 0.0, fangs, segs=4)
    a = m.part("Abdomen", "Body", joint=(0, 1.75, 0.2))
    a.ico((0, 1.95 * abd_scale ** 0.3, 1.1), 1.15 * abd_scale, (1.0, 0.85, 1.15), abdomen, jit=jit)
    for i, z in enumerate((-1.0, -0.6, -0.2, 0.2)):
        for side, s in (("L", -1), ("R", 1)):
            lp = m.part(f"Leg{side}{i + 1}", "Body", joint=(s * 0.55, 1.6, z))
            knee = (s * (0.55 + leg_reach * 0.45), 2.35, z + (z * 0.4))
            foot = (s * (0.55 + leg_reach), 0.0, z + z * 0.9)
            lp.cone((s * 0.55, 1.6, z), knee, 0.13, 0.1, legs, segs=5)
            lp.cone(knee, foot, 0.1, 0.03, legs, segs=5)
    return {"Body": b, "Abdomen": a}


def crustacean(m, shell, claw=None, legs=None, jit=0.05):
    claw = claw or shell
    legs = legs or shade(shell, 0.8)
    b = m.part("Body", joint=(0, 1.3, 0))
    b.ico((0, 1.3, 0), 1.4, (1.0, 0.45, 0.75), shell, jit=jit)
    b.ico((0, 1.62, 0.05), 1.0, (1.0, 0.25, 0.7), shade(shell, 1.15), sub=1)
    for s in (-1, 1):
        b.cyl((s * 0.45, 1.6, -0.75), (s * 0.5, 2.25, -0.85), 0.07, shell, segs=4)
        b.ico((s * 0.5, 2.3, -0.88), 0.17, (1, 1, 1), EYE, sub=1)
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        ap = m.part(name, "Body", joint=(s * 1.1, 1.35, -0.7))
        ap.cone((s * 1.1, 1.35, -0.7), (s * 1.75, 1.55, -1.4), 0.25, 0.22, shell, segs=5)
        ap.ico((s * 1.95, 1.65, -1.95), 0.55, (0.9, 0.75, 1.2), claw, jit=jit)
        ap.cone((s * 2.0, 1.85, -2.3), (s * 2.0, 1.75, -2.85), 0.2, 0.0, shade(claw, 0.85), segs=4)
        ap.cone((s * 1.9, 1.45, -2.3), (s * 1.9, 1.45, -2.7), 0.14, 0.0, shade(claw, 0.85), segs=4)
    for i, z in enumerate((-0.25, 0.25, 0.75)):
        for side, s in (("L", -1), ("R", 1)):
            lp = m.part(f"Leg{side}{i + 1}", "Body", joint=(s * 1.15, 1.15, z))
            knee = (s * 2.1, 1.55, z + 0.15)
            lp.cone((s * 1.15, 1.15, z), knee, 0.11, 0.09, legs, segs=4)
            lp.cone(knee, (s * 2.55, 0.0, z + 0.35), 0.09, 0.03, legs, segs=4)
    return b


def insect(m, shell, trim="#e0b840", legs=None, horn=True, jit=0.04):
    legs = legs or shade(shell, 0.6)
    b = m.part("Body", joint=(0, 1.25, 0.2))
    b.ico((0, 1.3, 0.3), 1.3, (0.9, 0.6, 1.1), shell, jit=jit)
    b.box((0, 1.95, 0.3), (0.08, 0.06, 2.2), trim)
    b.ico((0, 0.95, 0.3), 1.0, (0.92, 0.25, 1.05), trim, sub=1)
    h = m.part("Head", "Body", joint=(0, 1.05, -0.9))
    h.ico((0, 1.05, -1.25), 0.6, (1.0, 0.7, 0.8), shade(shell, 0.85), jit=jit)
    eyes(h, 0.3, 1.2, -1.65, r=0.1)
    if horn:
        h.cone((0, 1.2, -1.6), (0, 2.0, -2.0), 0.16, 0.0, trim, segs=4)
    for i, z in enumerate((-0.5, 0.25, 1.0)):
        for side, s in (("L", -1), ("R", 1)):
            lp = m.part(f"Leg{side}{i + 1}", "Body", joint=(s * 0.9, 0.95, z))
            knee = (s * 1.75, 1.2, z + 0.1)
            lp.cone((s * 0.9, 0.95, z), knee, 0.1, 0.08, legs, segs=4)
            lp.cone(knee, (s * 2.1, 0.0, z + 0.25), 0.08, 0.03, legs, segs=4)
    return b, h


# ------------------------------------------------------------------------------------------------
# FISH: Body; Tail, FinL, FinR, Jaw (hovering)
# ------------------------------------------------------------------------------------------------
def fish(m, body, belly, fin=None, jaw=True, teeth=True, bill=False, jit=0.04):
    fin = fin or shade(body, 0.8)
    b = m.part("Body", joint=(0, 1.2, 0))
    b.ico((0, 1.2, 0), 1.0, (0.55, 0.85, 1.35), body, jit=jit)
    b.ico((0, 0.85, -0.1), 0.8, (0.5, 0.45, 1.15), belly, sub=1)
    b.box((0, 2.05, 0.15), (0.08, 0.7, 1.1), fin, taper=0.3)
    eyes(b, 0.42, 1.45, -0.95, r=0.16)
    if bill:
        b.cone((0, 1.3, -1.25), (0, 1.35, -3.4), 0.16, 0.02, shade(belly, 0.9), segs=4)
    t = m.part("Tail", "Body", joint=(0, 1.2, 1.25))
    t.cone((0, 1.2, 1.2), (0, 1.2, 1.7), 0.32, 0.18, body, segs=5)
    t.box((0, 1.45, 2.0), (0.08, 0.6, 0.7), fin, rot=(35, 0, 0))
    t.box((0, 0.95, 2.0), (0.08, 0.6, 0.7), fin, rot=(-35, 0, 0))
    for name, s in (("FinL", -1), ("FinR", 1)):
        fp = m.part(name, "Body", joint=(s * 0.48, 1.0, -0.2))
        fp.box((s * 0.8, 0.95, -0.05), (0.6, 0.06, 0.45), fin, rot=(0, 0, s * -25))
    if jaw:
        j = m.part("Jaw", "Body", joint=(0, 0.95, -0.8))
        j.box((0, 0.82, -1.2), (0.6, 0.25, 0.7), shade(belly, 0.9))
        if teeth:
            for k in range(4):
                j.cone((-0.21 + k * 0.14, 0.95, -1.5), (-0.21 + k * 0.14, 1.15, -1.5), 0.06, 0, SHINE, segs=3)
    return b


# ------------------------------------------------------------------------------------------------
# GOLEM: Body; Head, ArmL, ArmR, LegL, LegR  (references 5 / 6: boulders, slabs, glowing crystals / eyes)
# ------------------------------------------------------------------------------------------------
def golem(m, stone, dark=None, glow="#ff3a2a", moss=None, slabs=False, jit=0.07, slab_jit=0.07):
    dark = dark or shade(stone, 0.7)
    b = m.part("Body", joint=(0, 3.7, 0))
    if slabs:
        b.box((0, 4.1, 0), (3.0, 2.6, 1.9), stone, taper=1.15, jit=slab_jit)
        b.box((0, 2.85, 0), (2.2, 0.9, 1.6), dark, jit=slab_jit)
    else:
        b.ico((0, 4.1, 0), 1.6, (1.0, 0.85, 0.7), stone, jit=jit)
        b.ico((0, 2.95, 0.05), 1.05, (1.0, 0.6, 0.75), dark, jit=jit)
    for s in (-1, 1):
        b.ico((s * 1.75, 5.0, 0.05), 0.95, (1, 0.9, 1), stone, jit=jit)  # shoulder boulders
    if moss:
        b.box((-0.4, 5.45, 0.1), (2.0, 0.25, 1.6), moss, jit=0.02)
        b.ico((1.6, 5.85, 0.1), 0.45, (1, 0.5, 1), moss, sub=1, jit=0.05)
    h = m.part("Head", "Body", joint=(0, 5.2, -0.2))
    if slabs:
        h.box((0, 5.75, -0.35), (1.25, 1.0, 1.1), stone, taper=0.9, jit=0.02)
    else:
        h.ico((0, 5.75, -0.35), 0.72, (1.0, 0.85, 0.9), stone, jit=jit)
    arms = {}
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        a = m.part(name, "Body", joint=(s * 1.9, 4.8, 0))
        a.ico((s * 2.1, 3.9, 0), 0.7, (0.85, 1.25, 0.85), dark, jit=jit)
        if slabs:
            a.box((s * 2.2, 2.35, -0.05), (1.5, 1.4, 1.4), stone, jit=slab_jit)
        else:
            a.ico((s * 2.25, 2.3, -0.05), 1.0, (1, 0.95, 1), stone, jit=jit)
        arms[name] = a
    legs = {}
    for name, s in (("LegL", -1), ("LegR", 1)):
        lg = m.part(name, "Body", joint=(s * 0.85, 2.6, 0))
        if slabs:
            lg.box((s * 0.9, 1.35, 0), (1.15, 2.4, 1.15), dark, jit=slab_jit)
            lg.box((s * 0.9, 0.2, -0.15), (1.35, 0.4, 1.5), stone)
        else:
            lg.ico((s * 0.9, 1.5, 0), 0.7, (0.95, 1.3, 0.95), dark, jit=jit)
            lg.ico((s * 0.92, 0.45, -0.1), 0.6, (1.1, 0.75, 1.25), stone, jit=jit)
        legs[name] = lg
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.box((s * 0.28, 5.85, -0.92), (0.26, 0.14, 0.1), glow)
    return {"Body": b, "Head": h, **arms, **legs}


def floater(m, body, glow=None, jit=0.04, crystals=None, lamp=None):
    b = m.part("Body", joint=(0, 2.6, 0))
    b.ico((0, 2.65, 0), 0.95, (1, 1, 0.9), body, jit=jit)
    t = m.part("Tail", "Body", joint=(0, 1.9, 0))
    t.cone((0, 2.0, 0.05), (0, 0.9, 0.2), 0.62, 0.3, shade(body, 0.85), segs=6, jit=jit)
    t2 = m.part("Tail2", "Tail", joint=(0, 0.95, 0.2))
    t2.cone((0, 0.95, 0.2), (0, 0.15, 0.45), 0.3, 0.0, shade(body, 0.7), segs=5)
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        a = m.part(name, "Body", joint=(s * 0.85, 2.85, 0))
        a.cone((s * 0.85, 2.85, 0), (s * 1.45, 2.05, -0.2), 0.22, 0.12, shade(body, 0.9), segs=5)
        a.ico((s * 1.5, 1.95, -0.25), 0.2, (1, 1, 1), body, sub=1)
    if glow:
        e = m.glow("Eyes", "Body")
        for s in (-1, 1):
            e.ico((s * 0.32, 2.85, -0.85), 0.14, (1, 0.8, 0.5), glow, sub=1)
    if crystals:
        for k, (x, y, z, h) in enumerate(((0, 3.5, 0.1, 0.9), (0.45, 3.3, 0.2, 0.6), (-0.45, 3.3, 0.2, 0.6), (0, 3.0, 0.75, 0.5))):
            b.cone((x, y - 0.3, z), (x * 1.3, y + h, z + 0.1), 0.18, 0.0, crystals, segs=4)
    if lamp:
        t2.ico((0, 0.15, 0.45), 0.45, (1.4, 0.6, 1.0), lamp, sub=1)
        t2.cone((0, 0.15, 0.0), (0, 0.4, -0.6), 0.1, 0.03, lamp, segs=4)
    return b
