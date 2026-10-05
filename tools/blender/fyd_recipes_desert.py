"""Zone 2 - Desert: mobs, mini-bosses, boss (docs/enemies_npcs_pets_brief.txt Part F).

Coordinates: Roblox model space in studs (x right, y up, z back, the creature faces -Z), feet on y = 0.
Palette cues: sand, sandstone, gold + lapis blue (reference 7, the paper-craft pharaoh mask).
"""
from fyd_creatures import Model
import fyd_creature_parts as P

GOLD, LAPIS, SAND = "#e0b040", "#2c58c0", "#e2c890"


def scorpion():
    """desert_scorpion | Arachnid | 3.5 | tan, curved tail stinger."""
    m = Model("desert_scorpion", "Mobs", zone=2, rig="Arachnid", size=3.5, name="Scorpion")
    tan, dark = "#d4ac66", "#8a6a3a"
    p = P.arachnid(m, tan, abdomen=P.shade(tan, 0.92), legs=dark, eye=P.EYE, leg_reach=2.0, abd_scale=0.8)
    a = p["Abdomen"]
    for k in range(3):  # segmented back plates
        a.box((0, 2.35 - k * 0.05, 0.5 + k * 0.5), (1.3 - k * 0.15, 0.12, 0.35), dark)
    tail = m.part("Tail", "Abdomen", joint=(0, 2.0, 2.0))
    pts = [(0, 2.0, 2.0), (0, 2.9, 2.6), (0, 3.9, 2.5), (0, 4.5, 1.8)]
    for i in range(3):
        tail.cone(pts[i], pts[i + 1], 0.32 - i * 0.05, 0.27 - i * 0.05, tan if i % 2 == 0 else dark, segs=6)
        tail.ico(pts[i + 1], 0.3 - i * 0.05, (1, 1, 1), tan, sub=1)
    tail.cone((0, 4.5, 1.8), (0, 4.0, 1.25), 0.2, 0.0, "#3a2a18", segs=4)  # stinger
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        arm = m.part(name, "Body", joint=(s * 0.55, 1.4, -1.0))
        arm.cone((s * 0.55, 1.4, -1.0), (s * 1.0, 1.5, -1.9), 0.18, 0.15, tan, segs=5)
        arm.ico((s * 1.05, 1.55, -2.25), 0.42, (0.9, 0.7, 1.2), tan, jit=0.05)
        arm.cone((s * 0.9, 1.6, -2.55), (s * 0.75, 1.6, -2.95), 0.15, 0.0, dark, segs=4)
        arm.cone((s * 1.2, 1.6, -2.55), (s * 1.2, 1.6, -2.95), 0.15, 0.0, dark, segs=4)
    return m


def sand_snake():
    """desert_sand_snake | Serpent | 6 long | sand yellow with dark diamond pattern."""
    m = Model("desert_sand_snake", "Mobs", zone=2, rig="Serpent", size=6, size_axis="length", name="Sand Snake")
    h = P.serpent(m, "#e0c470", "#6a5228", belly="#f0e0b0")
    for s in (-1, 1):
        h.cone((s * 0.35, 1.1, -1.8), (s * 0.45, 1.2, -1.5), 0.12, 0, "#6a5228", segs=3)  # horned brows
    return m


def vulture():
    """desert_vulture | Bird | 4 | bald, dark brown, hunched."""
    m = Model("desert_vulture", "Mobs", zone=2, rig="Bird", size=4, name="Vulture")
    p = P.bird(m, "#5a3c28", wing="#4a3020", belly="#6a4a34", beak="#e8d8b0", legs="#c8a888", head_r=0.42, wing_span=2.4)
    p["Head"].ico((0, 2.1, -0.95), 0.44, (0.95, 0.95, 1.05), "#dca8a0", sub=1)  # bald pink head
    p["Body"].ico((0, 1.95, -0.55), 0.45, (1.2, 0.6, 0.8), "#e8e0d0", sub=1, jit=0.05)  # white neck ruff
    return m


def jackal():
    """desert_jackal | Quadruped | 4 | tan and black, big ears."""
    m = Model("desert_jackal", "Mobs", zone=2, rig="Quadruped", size=4, name="Jackal")
    p = P.quadruped(m, "#c89a5e", belly="#ecd6b0", dark="#2a2420", body_len=1.7, body_h=0.68, body_w=0.8,
                    leg_len=1.5, leg_r=0.18, head_r=0.58, snout_len=0.8, snout_r=0.24, ears="pointy", tail="bushy",
                    head_up=0.4)
    hx, hy, hz = p["head_at"]
    for s in (-1, 1):  # big ears
        p["Head"].cone((s * 0.32, hy + 0.35, hz + 0.1), (s * 0.52, hy + 1.3, hz + 0.25), 0.26, 0, "#2a2420", segs=3)
    p["Body"].box((0, p["y0"] + 0.55, 0.2), (0.6, 0.25, 1.8), "#3a302a", taper=0.6)  # black saddle
    return m


def crocodile():
    """desert_crocodile | Quadruped long | 7 | sandy green, jaws."""
    m = Model("desert_crocodile", "Mobs", zone=2, rig="Quadruped", size=7, size_axis="length", name="Desert Crocodile")
    skin, belly, dark = "#7e8a50", "#d8cc98", "#55603a"
    body = m.part("Body", joint=(0, 0.95, 0))
    body.ico((0, 0.95, 0), 1.0, (1.1, 0.55, 2.2), skin, jit=0.05)
    body.ico((0, 0.6, 0), 0.9, (1.0, 0.25, 2.0), belly, sub=1)
    for k in range(6):  # back scutes
        body.cone((0, 1.45, -1.6 + k * 0.6), (0, 1.75, -1.5 + k * 0.6), 0.2, 0, dark, segs=4)
    head = m.part("Head", "Body", joint=(0, 0.95, -2.0))
    head.ico((0, 1.0, -2.6), 0.75, (0.95, 0.6, 0.9), skin, jit=0.04)
    head.box((0, 1.05, -3.75), (0.95, 0.38, 1.8), skin, taper=0.85)  # upper jaw
    head.box((0, 0.7, -3.65), (0.85, 0.25, 1.6), belly)  # lower jaw
    for k in range(5):
        for s in (-1, 1):
            head.cone((s * 0.4, 0.88, -3.0 - k * 0.35), (s * 0.4, 0.72, -3.0 - k * 0.35), 0.06, 0, P.SHINE, segs=3)
    P.eyes(head, 0.32, 1.45, -2.65, r=0.14)
    for name, x, z in (("LegFL", -1, -1.4), ("LegFR", 1, -1.4), ("LegBL", -1, 1.3), ("LegBR", 1, 1.3)):
        leg = m.part(name, "Body", joint=(x * 0.9, 0.75, z))
        leg.cone((x * 0.9, 0.75, z), (x * 1.35, 0.15, z - 0.1), 0.25, 0.2, skin, segs=5)
        leg.box((x * 1.4, 0.1, z - 0.25), (0.45, 0.2, 0.6), dark)
    tail = m.part("Tail", "Body", joint=(0, 0.95, 2.1))
    tail.cone((0, 0.95, 2.0), (0, 0.6, 4.6), 0.7, 0.08, skin, segs=6, jit=0.03)
    for k in range(4):
        tail.cone((0, 1.3 - k * 0.15, 2.4 + k * 0.5), (0, 1.55 - k * 0.15, 2.5 + k * 0.5), 0.15, 0, dark, segs=4)
    return m


def nomad_bandit():
    """desert_nomad_bandit | Biped | 5.5 | turban, scarf, scimitar."""
    m = Model("desert_nomad_bandit", "Mobs", zone=2, rig="Biped", size=5.5, name="Nomad Bandit")
    b = P.biped(m, skin="#b07a54", shirt="#e6dcc0", pants="#c2a878", boots="#6a4a2e", belt="#a83a2e", buckle=GOLD)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy + hr * 0.55, 0.05), hr * 1.08, (1.1, 0.7, 1.1), "#f2ece0", sub=1, jit=0.04)  # turban
    b["Head"].ico((0, hy + hr * 0.6, -hr * 0.85), 0.14, (1, 1, 0.6), "#c03a2e", sub=0)  # turban jewel
    b["Head"].box((0, hy - 0.32, -0.55), (1.0, 0.42, 0.35), "#b03a2e")  # face scarf
    b["Torso"].box((0, 3.1, 0.05), (1.3, 0.25, 0.85), "#b03a2e", rot=(0, 0, 25))  # sash
    P.sword(b["ArmR"], b["hands"]["R"], length=2.0, width=0.24, curve=0.5, blade="#d0d4dc", hilt="#5a3a22", guard=GOLD)
    return m


def sandstone_golem():
    """desert_sandstone_golem | Golem | 8 | sandstone blocks, gold glyph glow (reference 5 recolored)."""
    m = Model("desert_sandstone_golem", "Mobs", zone=2, rig="Golem", size=8, name="Sandstone Golem")
    stone = "#d4a868"
    g = P.golem(m, stone, dark="#a87c46", glow="#ffd040", slabs=False, jit=0.08)
    glyphs = m.glow("Glyphs", "Body")
    for (x, y, h) in ((0, 4.1, 1.1), (0.55, 3.9, 0.7), (-0.55, 3.9, 0.7)):  # glowing back crystals
        glyphs.cone((x, y, 1.0), (x * 1.3, y + h, 1.35), 0.22, 0.0, "#ffd040", segs=4)
    glyphs.box((0, 4.2, -1.12), (0.5, 0.5, 0.06), "#ffd040", rot=(0, 0, 45))  # chest glyph
    return m


def royal_eagle():
    """desert_royal_eagle | Bird | 4 | golden-brown, blue crest."""
    m = Model("desert_royal_eagle", "Mobs", zone=2, rig="Bird", size=4, name="Royal Eagle")
    p = P.bird(m, "#a8703a", wing="#7a4e26", belly="#e8d8b0", beak="#f0c040", legs="#f0c040", wing_span=2.6)
    for k in range(3):  # blue crest
        p["Head"].cone((0, 2.45, -0.9 + k * 0.15), (0, 2.95 - k * 0.12, -0.6 + k * 0.25), 0.1, 0, LAPIS, segs=3)
    p["Head"].ico((0, 2.1, -0.95), 0.47, (0.9, 0.9, 1.0), "#f0ece0", sub=1)  # white head
    return m


def cliff_bandit():
    """desert_cliff_bandit | Biped | 5.5 | rope, dagger, brown wraps."""
    m = Model("desert_cliff_bandit", "Mobs", zone=2, rig="Biped", size=5.5, name="Cliff Bandit")
    b = P.biped(m, skin="#c08a60", shirt="#8a6640", pants="#6a4e30", boots="#4a3422", belt="#3a2a1a",
                gloves="#c8b490")
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy + 0.1, 0.05), hr * 1.08, (1.05, 1.0, 1.05), "#c8b490", sub=1, jit=0.03)  # head wrap
    b["Head"].box((0, hy + 0.05, -0.6), (0.95, 0.25, 0.25), "#2a2018")  # eye slit band
    P.eyes(b["Head"], hr * 0.34, hy + 0.05, -hr * 0.95, r=hr * 0.1)
    for k in range(3):  # coiled rope over the shoulder
        b["Torso"].box((0.05, 3.0, 0), (1.35, 0.12, 0.85), "#c8a868", rot=(0, 0, 35 + k * 4))
    P.sword(b["ArmR"], b["hands"]["R"], length=1.0, width=0.13, blade="#c0c4cc", hilt="#3a2a1a", guard="#7a6040")
    P.sword(b["ArmL"], b["hands"]["L"], length=1.0, width=0.13, blade="#c0c4cc", hilt="#3a2a1a", guard="#7a6040")
    return m


def mummy():
    """desert_mummy | Biped | 5.5 | cream bandages, glowing yellow eyes."""
    m = Model("desert_mummy", "Mobs", zone=2, rig="Biped", size=5.5, name="Mummy")
    wrap, shade_ = "#e6dcc0", "#b8a888"
    b = P.biped(m, skin=wrap, shirt=wrap, pants=wrap, boots=shade_, belt=shade_, buckle=shade_, gloves=wrap)
    hy, hr = b["head_y"], b["head_r"]
    for k in range(6):  # bandage bands
        b["Torso"].box((0, 2.3 + k * 0.25, 0), (1.25 + (k % 2) * 0.05, 0.08, 0.8), shade_, rot=(0, 0, (k % 2) * 8 - 4))
    for k in range(4):
        b["Head"].box((0, hy - 0.4 + k * 0.28, 0), (hr * 2.05, 0.07, hr * 1.95), shade_, rot=(0, 0, (k % 2) * 10 - 5))
    for s, name in ((-1, "ArmL"), (1, "ArmR")):
        b[name].box((s * (b["ax"] + 0.1), 2.6, 0), (0.42, 0.08, 0.42), shade_)
    b["Torso"].box((0.4, 2.0, -0.35), (0.12, 0.8, 0.04), shade_, rot=(0, 0, 10))  # hanging strip
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.ico((s * hr * 0.34, hy + hr * 0.1, -hr * 0.9), hr * 0.13, (1, 0.8, 0.5), "#ffe040", sub=1)
    return m


def giant_scarab():
    """desert_giant_scarab | Insect | 4 | blue-green shell with gold trim."""
    m = Model("desert_giant_scarab", "Mobs", zone=2, rig="Insect", size=4, name="Giant Scarab")
    P.insect(m, "#2a8a80", trim=GOLD, legs="#1a4a46")
    return m


def anubis_guard():
    """MINI desert_anubis_guard | Biped | 10 | jackal head, black and gold, spear."""
    m = Model("desert_anubis_guard", "MiniBosses", zone=2, rig="Biped", size=10, role="mini", name="Anubis Guard")
    black = "#24242c"
    b = P.biped(m, skin=black, shirt=black, pants=GOLD, boots=black, belt=GOLD, buckle=LAPIS, head_r=0.62, bulk=1.3,
                sleeves=False)
    hy, hr = b["head_y"], b["head_r"]
    head = b["Head"]
    head.cone((0, hy - 0.05, -hr * 0.6), (0, hy - 0.2, -hr * 2.3), 0.33, 0.14, black, segs=6)  # jackal snout
    head.ico((0, hy - 0.22, -hr * 2.35), 0.12, (1, 0.8, 0.8), "#101014", sub=0)
    for s in (-1, 1):
        head.cone((s * 0.32, hy + 0.35, 0.05), (s * 0.45, hy + 1.6, 0.15), 0.26, 0, black, segs=4)  # tall ears
        head.cone((s * 0.32, hy + 0.4, -0.02), (s * 0.43, hy + 1.3, 0.05), 0.15, 0, GOLD, segs=3)
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.box((s * 0.24, hy + 0.12, -hr * 0.85), (0.2, 0.07, 0.06), "#ffd040")
    b["Torso"].box((0, 3.65, 0), (2.2, 0.3, 1.25), GOLD, taper=0.8)  # broad collar
    for k in range(3):
        b["Torso"].box((0, 3.45 - k * 0.2, -0.02), (2.0 - k * 0.2, 0.08, 1.2), LAPIS if k % 2 == 0 else GOLD)
    b["Torso"].box((0, 1.9, -0.5), (0.8, 0.9, 0.08), GOLD, taper=0.7)  # kilt front
    for s, name in ((-1, "ArmL"), (1, "ArmR")):
        b[name].box((s * (b["ax"] + 0.12), 2.35, -0.02), (0.5, 0.35, 0.5), GOLD)  # bracers
    x, y, z = b["hands"]["R"]
    b["ArmR"].cyl((x, y + 2.0, z), (x, y - 2.8, z), 0.1, "#3a3a46", segs=6)  # spear held upright
    b["ArmR"].cone((x, y + 2.0, z), (x, y + 2.9, z), 0.24, 0.0, GOLD, segs=4)
    return m


def sandstorm_djinn():
    """MINI desert_sandstorm_djinn | Floater | 9 | blue-violet smoke body rising from a lamp base."""
    m = Model("desert_sandstorm_djinn", "MiniBosses", zone=2, rig="Floater", size=9, role="mini", name="Sandstorm Djinn")
    smoke = "#6a5ad8"
    b = P.floater(m, smoke, glow="#fff0a0", lamp=GOLD)
    b.ico((0, 3.55, 0.05), 0.7, (1.0, 0.5, 1.0), "#f0e8d8", sub=1, jit=0.05)  # turban
    b.ico((0, 3.6, -0.6), 0.15, (1, 1, 0.6), "#e02a6a", sub=0)
    b.ico((0, 2.2, -0.5), 0.3, (1.3, 0.6, 0.6), "#8a7ae8", sub=1)  # beard
    for k in range(4):  # swirling smoke rings
        m.parts["Tail"].box((0, 1.8 - k * 0.3, 0.1 + k * 0.08), (1.2 - k * 0.2, 0.08, 1.2 - k * 0.2), "#8a7ae8",
                            rot=(0, k * 25, 0))
    for name in ("ArmL", "ArmR"):
        s = -1 if name == "ArmL" else 1
        m.parts[name].box((s * 1.5, 1.95, -0.25), (0.35, 0.22, 0.35), GOLD)  # gold bracelets
    for (x, y, z, r) in ((0.6, 1.5, 0.4, 0.35), (-0.55, 1.2, 0.3, 0.3), (0.3, 0.8, 0.5, 0.25), (-0.2, 2.0, 0.6, 0.3),
                         (0.0, 0.5, 0.35, 0.22)):  # smoke wisps around the tail
        m.parts["Tail"].ico((x, y, z), r, (1.2, 0.8, 1.0), "#7c6ae0", sub=1, jit=0.08)
    m.parts["Body"].ico((0, 2.6, 0.35), 0.8, (1.1, 0.9, 0.7), "#5a4ac8", sub=1, jit=0.06)  # back of the smoke body
    return m


def cursed_pharaoh():
    """BOSS desert_cursed_pharaoh | Boss-Biped | 17 | gold faceted mask, blue-striped headdress (ref 7), wraps, staff."""
    m = Model("desert_cursed_pharaoh", "Bosses", zone=2, rig="BossBiped", size=17, role="boss", name="Cursed Pharaoh")
    wrap, dark = "#ddd0b0", "#a89870"
    b = P.biped(m, skin=GOLD, shirt=wrap, pants=wrap, boots=GOLD, belt=GOLD, buckle=LAPIS, gloves=wrap,
                head_r=0.78, bulk=1.25, jit=0.06)
    hy, hr = b["head_y"], b["head_r"]
    head = b["Head"]
    # nemes headdress: gold with lapis stripes, draping on the shoulders (reference 7)
    head.ico((0, hy + 0.2, 0.15), hr * 1.25, (1.15, 1.0, 1.1), GOLD, sub=1, jit=0.05)
    for k in range(6):
        head.box((0, hy + 0.85 - k * 0.32, 0.25), (hr * 2.55, 0.12, hr * 1.9), LAPIS if k % 2 == 0 else GOLD)
    for s in (-1, 1):  # side lappets in front of the shoulders
        for k in range(5):
            head.box((s * 0.85, hy - 0.5 - k * 0.3, -0.25), (0.42, 0.28, 0.25), LAPIS if k % 2 == 0 else GOLD)
    head.box((0, hy - 0.05, -hr * 0.92), (hr * 1.35, hr * 1.4, 0.2), "#f0c040", jit=0.05)  # faceted gold face plate
    head.cone((0, hy - 0.9, -hr * 0.7), (0, hy - 1.6, -hr * 0.65), 0.18, 0.1, LAPIS, segs=6)  # braided beard
    head.cone((0, hy + 1.1, -hr * 0.7), (0, hy + 1.45, -hr * 1.0), 0.14, 0.05, GOLD, segs=5)  # uraeus cobra
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.box((s * 0.3, hy + 0.12, -hr * 1.05), (0.26, 0.1, 0.06), "#50e0ff")
    torso = b["Torso"]
    torso.box((0, 3.6, -0.05), (2.3, 0.35, 1.3), GOLD, taper=0.75)  # broad collar
    for k in range(3):
        torso.box((0, 3.35 - k * 0.18, -0.03), (2.0 - k * 0.25, 0.09, 1.2), LAPIS if k % 2 == 0 else GOLD)
    for k in range(7):  # wraps
        torso.box((0, 2.2 + k * 0.18, 0), (1.55, 0.07, 0.98), dark, rot=(0, 0, (k % 2) * 8 - 4))
    torso.box((0, 1.85, -0.55), (1.0, 1.0, 0.1), GOLD, taper=0.6)  # gold apron
    torso.box((0, 1.85, -0.6), (0.3, 0.9, 0.1), LAPIS, taper=0.6)
    torso.box((0, 2.9, 0.65), (1.9, 3.4, 0.15), "#3a2a5a", taper=1.2)  # dark cape
    for s, name in ((-1, "ArmL"), (1, "ArmR")):
        arm = b[name]
        for k in range(3):
            arm.box((s * (b["ax"] + 0.1), 2.95 - k * 0.3, 0), (0.48, 0.08, 0.48), dark)
        arm.box((s * (b["ax"] + 0.14), 2.2, -0.04), (0.52, 0.32, 0.52), GOLD)
    x, y, z = b["hands"]["R"]  # crook staff
    b["ArmR"].cyl((x, y + 2.4, z), (x, y - 2.6, z), 0.12, LAPIS, segs=6)
    for k in range(5):
        b["ArmR"].cyl((x, y + 2.0 - k * 1.0, z), (x, y + 1.8 - k * 1.0, z), 0.15, GOLD, segs=6)
    b["ArmR"].cone((x, y + 2.4, z), (x, y + 3.1, z - 0.2), 0.14, 0.12, GOLD, segs=6)
    b["ArmR"].cone((x, y + 3.1, z - 0.2), (x, y + 2.9, z - 0.75), 0.12, 0.08, GOLD, segs=6)
    orb = m.glow("Orb", "ArmR")
    orb.ico((x, y + 3.2, z + 0.1), 0.3, (1, 1, 1), "#50e0ff", sub=1)
    return m


RECIPES = {
    "desert_scorpion": scorpion,
    "desert_sand_snake": sand_snake,
    "desert_vulture": vulture,
    "desert_jackal": jackal,
    "desert_crocodile": crocodile,
    "desert_nomad_bandit": nomad_bandit,
    "desert_sandstone_golem": sandstone_golem,
    "desert_royal_eagle": royal_eagle,
    "desert_cliff_bandit": cliff_bandit,
    "desert_mummy": mummy,
    "desert_giant_scarab": giant_scarab,
    "desert_anubis_guard": anubis_guard,
    "desert_sandstorm_djinn": sandstorm_djinn,
    "desert_cursed_pharaoh": cursed_pharaoh,
}
