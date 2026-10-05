"""Pets of zones 1-4 (docs/enemies_npcs_pets_brief.txt Part F): 24 cute low-poly companions after reference 2
(the low-poly cat: big head, simple shapes, large glossy eyes, clean facets). 0.6-1.2 studs tall, 200-800
triangles, 2-4 parts each, Idle clip only (the follow script adds the walking bob). Ids `<zone>_pet<slot>` in the
slot order of Config/Pets. Roblox model space in studs, the pet faces -Z, feet on y = 0.
"""
from fyd_creatures import Model
import fyd_creature_parts as P

ZONES = {1: "plains", 2: "desert", 3: "jungle", 4: "tundra"}
BLUSH = "#f4a0a8"


def _model(zone, slot, name, rig, scale):
    mid = f"{ZONES[zone]}_pet{slot}"
    size = max(0.6, min(1.2, 0.95 * scale))
    return Model(mid, "Pets", zone=zone, rig=rig, size=size, role="pet", name=name)


def _face(head, y, z, eye_x=0.2, eye_r=0.13, nose=None, blush=True):
    P.eyes(head, eye_x, y, z, r=eye_r, depth=0.75)
    if nose:
        head.ico((0, y - 0.13, z - 0.02), 0.05, (1.2, 0.8, 0.6), nose, sub=0)
    if blush:
        for s in (-1, 1):
            head.ico((s * (eye_x + 0.1), y - 0.12, z + 0.04), 0.06, (1, 0.6, 0.3), BLUSH, sub=0)


def quad_pet(zone, slot, name, main, second, ears="pointy", tail="bushy", scale=1.0, snout=0.0, extra=None):
    """Chibi four-legged pet: Body (with stubby legs), Head, Tail."""
    m = _model(zone, slot, name, "Quadruped", scale)
    body = m.part("Body", joint=(0, 0.5, 0.15))
    body.ico((0, 0.5, 0.15), 0.42, (0.95, 0.85, 1.1), main, sub=2, jit=0.02)
    body.ico((0, 0.42, -0.05), 0.3, (0.85, 0.8, 0.7), second, sub=1)  # chest / belly
    for (x, z) in ((-0.2, -0.12), (0.2, -0.12), (-0.2, 0.42), (0.2, 0.42)):
        body.cyl((x, 0.32, z), (x, 0.05, z), 0.1, main, segs=5)
        body.ico((x, 0.05, z - 0.03), 0.11, (1, 0.6, 1.2), second, sub=0)  # paws
    head = m.part("Head", "Body", joint=(0, 0.75, -0.15))
    head.ico((0, 1.05, -0.25), 0.48, (1.0, 0.92, 0.92), main, sub=2, jit=0.02)
    head.ico((0, 0.92, -0.58), 0.22, (1.1, 0.75, 0.6), second, sub=1)  # muzzle
    if snout > 0:
        head.cone((0, 0.9, -0.6), (0, 0.86, -0.6 - snout), 0.16, 0.13, second, segs=6)
    _face(head, 1.12, -0.62, nose="#2a2026")
    if ears == "pointy":
        for s in (-1, 1):
            head.cone((s * 0.25, 1.35, -0.2), (s * 0.34, 1.68, -0.15), 0.14, 0, main, segs=3)
            head.cone((s * 0.25, 1.37, -0.24), (s * 0.32, 1.6, -0.2), 0.07, 0, BLUSH, segs=3)
    elif ears == "big":
        for s in (-1, 1):
            head.cone((s * 0.25, 1.32, -0.2), (s * 0.45, 1.95, -0.15), 0.2, 0, main, segs=3)
            head.cone((s * 0.26, 1.36, -0.25), (s * 0.42, 1.82, -0.2), 0.1, 0, second, segs=3)
    elif ears == "round":
        for s in (-1, 1):
            head.ico((s * 0.32, 1.4, -0.2), 0.13, (1, 1, 0.6), main, sub=1)
    if tail != "none":
        t = m.part("Tail", "Body", joint=(0, 0.6, 0.6))
        if tail == "bushy":
            t.ico((0, 0.75, 0.8), 0.18, (0.8, 0.8, 1.3), main, sub=1, jit=0.02)
            t.ico((0, 0.85, 0.98), 0.12, (1, 1, 1), second, sub=1)
        elif tail == "long":
            t.cone((0, 0.6, 0.6), (0, 0.95, 1.05), 0.07, 0.04, main, segs=4)
            t.ico((0, 0.98, 1.08), 0.07, (1, 1, 1), second, sub=0)
        elif tail == "curly":
            t.cone((0, 0.6, 0.6), (0, 0.72, 0.78), 0.05, 0.04, main, segs=4)
            t.ico((0, 0.76, 0.8), 0.07, (1, 1, 1), main, sub=0)
        else:  # short
            t.ico((0, 0.62, 0.62), 0.1, (1, 1, 1), main, sub=1)
    if extra:
        extra(m, body, head)
    return m


def bird_pet(zone, slot, name, main, second, beak="#f5b030", scale=1.0, extra=None):
    """Round chick: Body, Head, WingL, WingR, Tail (Idle flaps the little wings)."""
    m = _model(zone, slot, name, "Bird", scale)
    body = m.part("Body", joint=(0, 0.45, 0.05))
    body.ico((0, 0.45, 0.05), 0.42, (1, 0.95, 1), main, sub=2, jit=0.02)
    body.ico((0, 0.4, -0.18), 0.3, (0.85, 0.8, 0.6), second, sub=1)
    for s in (-1, 1):
        body.cyl((s * 0.13, 0.15, 0.05), (s * 0.13, 0.0, 0.0), 0.04, beak, segs=4)
        body.box((s * 0.13, 0.02, -0.08), (0.14, 0.04, 0.2), beak)
    head = m.part("Head", "Body", joint=(0, 0.75, -0.05))
    head.ico((0, 0.98, -0.1), 0.38, (1, 0.95, 0.95), main, sub=2, jit=0.02)
    head.cone((0, 0.92, -0.45), (0, 0.88, -0.66), 0.09, 0.0, beak, segs=4)
    _face(head, 1.04, -0.43, eye_x=0.16, eye_r=0.1)
    for name_, s in (("WingL", -1), ("WingR", 1)):
        w = m.part(name_, "Body", joint=(s * 0.38, 0.55, 0.05))
        w.ico((s * 0.45, 0.45, 0.1), 0.2, (0.45, 0.9, 1.1), second if second != main else P.shade(main, 0.9), sub=1)
    t = m.part("Tail", "Body", joint=(0, 0.5, 0.42))
    t.cone((0, 0.5, 0.42), (0, 0.62, 0.7), 0.1, 0.0, P.shade(main, 0.85), segs=4)
    if extra:
        extra(m, body, head)
    return m


def bug_pet(zone, slot, name, main, second, rig="Insect", scale=1.0, legs=3, extra=None):
    """Bug / crab / spider / scorpion: Body (+ legs), Head (Insect) or Abdomen (Arachnid) or claws (Crustacean)."""
    m = _model(zone, slot, name, rig, scale)
    body = m.part("Body", joint=(0, 0.42, 0))
    body.ico((0, 0.42, 0.05), 0.42, (1.05, 0.7, 1.1), main, sub=2, jit=0.02)
    for i in range(legs):
        z = -0.2 + i * 0.25
        for s in (-1, 1):
            body.cone((s * 0.35, 0.35, z), (s * 0.62, 0.0, z + 0.05), 0.05, 0.03, P.shade(main, 0.7), segs=4)
    head_parent = "Body"
    head_name = "Head" if rig == "Insect" else "Body"
    if rig == "Insect":
        head = m.part("Head", "Body", joint=(0, 0.5, -0.3))
        head.ico((0, 0.6, -0.45), 0.34, (1, 0.9, 0.9), P.shade(main, 0.9), sub=2, jit=0.02)
        _face(head, 0.68, -0.73, eye_x=0.15, eye_r=0.1)
    else:
        head = body
        body.ico((0, 0.62, -0.3), 0.32, (1, 0.9, 0.85), P.shade(main, 0.95), sub=2, jit=0.02)
        _face(body, 0.68, -0.58, eye_x=0.15, eye_r=0.1)
    if extra:
        extra(m, body, head)
    return m


def fish_pet(zone, slot, name, main, second, scale=1.0, extra=None):
    m = _model(zone, slot, name, "Fish", scale)
    body = m.part("Body", joint=(0, 0.5, 0))
    body.ico((0, 0.5, 0), 0.45, (0.75, 0.95, 1.1), main, sub=2, jit=0.02)
    body.ico((0, 0.35, -0.05), 0.3, (0.7, 0.5, 0.9), second, sub=1)
    body.box((0, 0.95, 0.05), (0.04, 0.25, 0.35), P.shade(main, 0.8), taper=0.4)
    _face(body, 0.6, -0.42, eye_x=0.17, eye_r=0.11)
    tail = m.part("Tail", "Body", joint=(0, 0.5, 0.42))
    tail.box((0, 0.62, 0.62), (0.04, 0.3, 0.32), P.shade(main, 0.85), rot=(35, 0, 0))
    tail.box((0, 0.38, 0.62), (0.04, 0.3, 0.32), P.shade(main, 0.85), rot=(-35, 0, 0))
    for name_, s in (("FinL", -1), ("FinR", 1)):
        f = m.part(name_, "Body", joint=(s * 0.3, 0.42, -0.05))
        f.box((s * 0.42, 0.4, 0.02), (0.22, 0.03, 0.18), P.shade(main, 0.85), rot=(0, 0, s * -25))
    if extra:
        extra(m, body, None)
    return m


def snake_pet(zone, slot, name, main, second, scale=1.0, extra=None):
    """Coiled little snake: Seg1 (coils), Head."""
    m = _model(zone, slot, name, "Serpent", scale)
    seg = m.part("Seg1", joint=(0, 0.2, 0))
    for k, (r, y) in enumerate(((0.42, 0.14), (0.33, 0.38), (0.24, 0.58))):
        for i in range(6):
            import math as _m
            a = i / 6 * 2 * _m.pi + k * 0.5
            seg.ico((_m.cos(a) * r, y, _m.sin(a) * r), 0.16 - k * 0.025, (1, 0.85, 1), main if (i + k) % 2 else second,
                    sub=1)
    head = m.part("Head", "Seg1", joint=(0, 0.65, 0))
    head.ico((0, 0.85, -0.12), 0.28, (1, 0.85, 1.1), main, sub=2, jit=0.02)
    _face(head, 0.92, -0.38, eye_x=0.13, eye_r=0.09, blush=False)
    head.cone((0, 0.78, -0.4), (0, 0.76, -0.55), 0.02, 0.01, "#d23a4a", segs=3)
    if extra:
        extra(m, seg, head)
    return m


def biped_pet(zone, slot, name, main, second, scale=1.0, extra=None):
    """Chibi standing pet: Torso (with stubby legs), Head, ArmL, ArmR."""
    m = _model(zone, slot, name, "Biped", scale)
    torso = m.part("Torso", joint=(0, 0.35, 0))
    torso.ico((0, 0.42, 0), 0.34, (1, 1, 0.9), main, sub=2, jit=0.02)
    torso.ico((0, 0.4, -0.18), 0.22, (0.85, 0.9, 0.5), second, sub=1)
    for s in (-1, 1):
        torso.ico((s * 0.15, 0.08, -0.02), 0.12, (1, 0.7, 1.2), main, sub=1)
    head = m.part("Head", "Torso", joint=(0, 0.7, 0))
    head.ico((0, 1.0, -0.02), 0.45, (1, 0.95, 0.95), main, sub=2, jit=0.02)
    head.ico((0, 0.95, -0.3), 0.27, (1.0, 0.85, 0.55), second, sub=1)  # face patch
    _face(head, 1.05, -0.43, eye_x=0.17, eye_r=0.11)
    for name_, s in (("ArmL", -1), ("ArmR", 1)):
        a = m.part(name_, "Torso", joint=(s * 0.3, 0.58, 0))
        a.cone((s * 0.32, 0.58, 0), (s * 0.42, 0.3, -0.05), 0.08, 0.07, main, segs=5)
        a.ico((s * 0.43, 0.27, -0.06), 0.08, (1, 1, 1), second, sub=0)
    if extra:
        extra(m, torso, head)
    return m


# ------------------------------------------------------------------------------------------------
# species accessories
# ------------------------------------------------------------------------------------------------
def tusks(m, body, head):
    for s in (-1, 1):
        head.cone((s * 0.12, 0.85, -0.68), (s * 0.15, 1.0, -0.74), 0.03, 0, "#f6efdc", segs=3)
    head.disc((0, 0.9, -0.71), 0.1, (0, 0, -1), 0.03, "#c07070", segs=6)


def claws(m, body, head):
    for name_, s in (("ArmL", -1), ("ArmR", 1)):
        a = m.part(name_, "Body", joint=(s * 0.35, 0.45, -0.3))
        a.cone((s * 0.35, 0.45, -0.3), (s * 0.5, 0.5, -0.6), 0.06, 0.05, P.shade(body.prims[0][1]["color"], 0.9), segs=4)
        a.ico((s * 0.55, 0.55, -0.72), 0.14, (0.9, 0.8, 1.1), body.prims[0][1]["color"], sub=1)
    for s in (-1, 1):
        body.cyl((s * 0.12, 0.7, -0.25), (s * 0.14, 0.88, -0.3), 0.025, body.prims[0][1]["color"], segs=3)


def spider_bits(m, body, head):
    abd = m.part("Abdomen", "Body", joint=(0, 0.5, 0.25))
    abd.ico((0, 0.6, 0.45), 0.36, (1, 0.9, 1.1), "#3a3036", sub=2, jit=0.02)
    for (x, z) in ((-0.12, 0.4), (0.12, 0.55), (0.0, 0.7)):
        abd.ico((x, 0.9, z), 0.06, (1, 0.4, 1), "#b04a4a", sub=0)
    for i in range(1, 2):
        for s in (-1, 1):
            body.cone((s * 0.3, 0.38, -0.35), (s * 0.55, 0.0, -0.45), 0.04, 0.02, "#2a2026", segs=4)


def stinger(m, body, head):
    claws(m, body, head)
    tail = m.part("Tail", "Body", joint=(0, 0.45, 0.4))
    tail.cone((0, 0.45, 0.4), (0, 0.8, 0.6), 0.07, 0.06, "#e0a030", segs=4)
    tail.cone((0, 0.8, 0.6), (0, 1.0, 0.45), 0.06, 0.05, "#e0a030", segs=4)
    tail.cone((0, 1.0, 0.45), (0, 0.92, 0.3), 0.05, 0.0, "#7a3e16", segs=4)


def shell(m, body, head):
    body.box((0, 0.62, 0.1), (0.03, 0.03, 0.75), "#e2b04a")
    body.ico((0, 0.25, 0.05), 0.4, (1.05, 0.2, 1.1), "#e2b04a", sub=1)
    head.cone((0, 0.75, -0.6), (0, 0.98, -0.8), 0.05, 0, "#e2b04a", segs=3)


def croc_bits(m, body, head):
    head.box((0, 0.88, -0.78), (0.3, 0.14, 0.4), "#5e8a3a")
    for s in (-1, 1):
        head.cone((s * 0.1, 0.82, -0.9), (s * 0.1, 0.76, -0.9), 0.025, 0, "#ffffff", segs=3)
    for k in range(3):
        body.cone((0, 0.85, -0.05 + k * 0.2), (0, 0.98, 0.0 + k * 0.2), 0.05, 0, "#c9d98a", segs=3)


def spots(color):
    def add(m, body, head):
        for (x, z) in ((-0.2, -0.05), (0.18, 0.2), (-0.1, 0.35), (0.22, -0.1)):
            body.ico((x, 0.85, z), 0.07, (1, 0.3, 1), color, sub=0)
        head.ico((0.18, 1.4, -0.25), 0.06, (1, 0.4, 1), color, sub=0)
    return add


def crown(m, body, head):
    for k in range(5):
        import math as _m
        a = k / 5 * 2 * _m.pi
        head.cone((_m.sin(a) * 0.14, 1.2, -0.95 + _m.cos(a) * 0.14), (_m.sin(a) * 0.16, 1.36, -0.95 + _m.cos(a) * 0.16),
                  0.05, 0, "#f1c40f", segs=3)
    head.cyl((0, 1.18, -0.95), (0, 1.24, -0.95), 0.16, "#f1c40f", segs=6)


def frog_prince():
    m = _model(3, 3, "Frog Prince", "Amphibian", 0.9)
    green, belly = "#5acb4a", "#d4f0a0"
    body = m.part("Body", joint=(0, 0.35, 0.1))
    body.ico((0, 0.35, 0.15), 0.45, (1.05, 0.7, 1.0), green, sub=2, jit=0.02)
    body.ico((0, 0.25, 0.0), 0.32, (0.95, 0.45, 0.85), belly, sub=1)
    for s in (-1, 1):
        body.ico((s * 0.38, 0.18, 0.35), 0.18, (0.8, 0.6, 1.2), green, sub=1)  # back legs
        body.box((s * 0.3, 0.02, -0.25), (0.18, 0.04, 0.16), "#f1c40f")  # feet
    head = m.part("Head", "Body", joint=(0, 0.5, -0.2))
    head.ico((0, 0.62, -0.5), 0.45, (1.0, 0.65, 0.8), green, sub=2, jit=0.02)
    P.eyes(head, 0.25, 0.92, -0.55, r=0.15, depth=0.9)
    head.box((0, 0.5, -0.86), (0.45, 0.03, 0.05), "#2a6a20")
    for s in (-1, 1):
        head.ico((s * 0.32, 0.55, -0.82), 0.06, (1, 0.6, 0.3), BLUSH, sub=0)
    crown(m, body, head)
    return m


def piranha_pal():
    def teeth(m, body, head):
        for k in range(3):
            body.cone((-0.1 + k * 0.1, 0.4, -0.48), (-0.1 + k * 0.1, 0.48, -0.5), 0.03, 0, "#ffffff", segs=3)
    return fish_pet(3, 4, "Piranha Pal", "#c0392b", "#9aa0a8", scale=0.9, extra=teeth)


def totem_spirit():
    def mask(m, torso, head):
        head.box((0, 1.0, -0.45), (0.5, 0.55, 0.08), "#a0703f", taper=0.85)
        head.box((0, 1.08, -0.5), (0.35, 0.06, 0.04), "#1fa59a")
        head.box((0, 0.88, -0.5), (0.2, 0.06, 0.04), "#1fa59a")
        glow = m.glow("Glow", "Head")
        for s in (-1, 1):
            glow.box((s * 0.12, 1.15, -0.5), (0.08, 0.05, 0.03), "#5afff0")
        for k, c in enumerate(("#d83a2a", "#f0c030", "#1fa59a")):
            head.cone((-0.12 + k * 0.12, 1.4, -0.05), (-0.18 + k * 0.18, 1.75, 0.05), 0.05, 0, c, segs=3)
    return biped_pet(3, 6, "Totem Spirit", "#a0703f", "#1fa59a", extra=mask)


def baby_yeti():
    def horns(m, torso, head):
        for s in (-1, 1):
            head.cone((s * 0.22, 1.35, -0.05), (s * 0.35, 1.6, 0.0), 0.06, 0, "#7cc8ee", segs=4)
    return biped_pet(4, 4, "Baby Yeti", "#e8f0f8", "#7cc8ee", scale=1.1, extra=horns)


def monkey_pet():
    def ears_tail(m, torso, head):
        for s in (-1, 1):
            head.ico((s * 0.45, 1.05, -0.02), 0.12, (0.5, 1, 1), "#e8c9a0", sub=1)
        torso.cone((0, 0.3, 0.25), (0, 0.65, 0.55), 0.04, 0.03, "#8a5a33", segs=4)
        torso.ico((0, 0.7, 0.57), 0.06, (1, 1, 1), "#8a5a33", sub=0)
    return biped_pet(3, 1, "Monkey", "#8a5a33", "#e8c9a0", extra=ears_tail)


def owl_ears(m, body, head):
    for s in (-1, 1):
        head.cone((s * 0.18, 1.25, -0.1), (s * 0.24, 1.42, -0.08), 0.06, 0, "#c9d3dc", segs=3)


def ice_crystal(m, body, head):
    glow = m.glow("Crystal", "Head")
    glow.cone((0, 1.3, -0.1), (0, 1.55, -0.05), 0.07, 0, "#9ae4ff", segs=4)


RECIPES = {
    # Plains
    "plains_pet1": lambda: quad_pet(1, 1, "Boar Piglet", "#e8a3a3", "#f6c8c8", ears="pointy", tail="curly", snout=0.1, extra=tusks),
    "plains_pet2": lambda: quad_pet(1, 2, "Wolf Pup", "#9aa0a8", "#e8e8e8", ears="pointy", tail="bushy", snout=0.12),
    "plains_pet3": lambda: quad_pet(1, 3, "Baby Bear", "#8a5a33", "#d9b48a", ears="round", tail="short", scale=1.1),
    "plains_pet4": lambda: bird_pet(1, 4, "Seagull Chick", "#f2f2f2", "#ffffff", beak="#f5c542", scale=0.9),
    "plains_pet5": lambda: bug_pet(1, 5, "Crab Buddy", "#e0503a", "#f5d0b0", rig="Crustacean", scale=0.9, extra=claws),
    "plains_pet6": lambda: bug_pet(1, 6, "Spider Hatchling", "#3a3036", "#b04a4a", rig="Arachnid", scale=0.85, legs=4, extra=spider_bits),
    # Desert
    "desert_pet1": lambda: quad_pet(2, 1, "Jackal Pup", "#d9a45a", "#f2dcb0", ears="big", tail="bushy", snout=0.12),
    "desert_pet2": lambda: bug_pet(2, 2, "Scorpion Cub", "#e0a030", "#7a3e16", rig="Arachnid", scale=0.95, legs=3, extra=stinger),
    "desert_pet3": lambda: quad_pet(2, 3, "Baby Croc", "#5e8a3a", "#c9d98a", ears="none", tail="long", extra=croc_bits),
    "desert_pet4": lambda: bird_pet(2, 4, "Desert Eaglet", "#8a5a33", "#f2e2c0", beak="#f0c040"),
    "desert_pet5": lambda: bug_pet(2, 5, "Scarab Beetle", "#1fa59a", "#e2b04a", rig="Insect", scale=0.85, extra=shell),
    "desert_pet6": lambda: snake_pet(2, 6, "Sand Snake", "#d9b77a", "#8a5a33"),
    # Jungle
    "jungle_pet1": monkey_pet,
    "jungle_pet2": lambda: quad_pet(3, 2, "Jaguar Cub", "#e09a2e", "#f6dcb0", ears="round", tail="long", extra=spots("#3a2414")),
    "jungle_pet3": frog_prince,
    "jungle_pet4": piranha_pal,
    "jungle_pet5": lambda: snake_pet(3, 5, "Green Viper", "#2e8b3a", "#9ad94a"),
    "jungle_pet6": totem_spirit,
    # Tundra
    "tundra_pet1": lambda: bird_pet(4, 1, "Snow Owl", "#f2f4f8", "#c9d3dc", beak="#f0c040", extra=owl_ears),
    "tundra_pet2": lambda: quad_pet(4, 2, "Arctic Fox", "#f2f4f8", "#ffffff", ears="big", tail="bushy", snout=0.1),
    "tundra_pet3": lambda: quad_pet(4, 3, "Polar Bear Cub", "#f5f5f0", "#ffffff", ears="round", tail="short", scale=1.1),
    "tundra_pet4": baby_yeti,
    "tundra_pet5": lambda: bird_pet(4, 5, "Ice Eaglet", "#7cc8ee", "#e8f0f8", beak="#f0d060", extra=ice_crystal),
    "tundra_pet6": lambda: quad_pet(4, 6, "White Wolf Pup", "#e8eef2", "#ffffff", ears="pointy", tail="bushy", snout=0.12),
}
