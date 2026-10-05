"""Zone 4 - Tundra: mobs, mini-bosses, boss (docs/enemies_npcs_pets_brief.txt Part F).

Coordinates: Roblox model space in studs (x right, y up, z back, the creature faces -Z), feet on y = 0.
Palette: snow white, ice blue, deep blue, frost purple accents.
"""
from fyd_creatures import Model
import fyd_creature_parts as P

ICE, ICE_DEEP, SNOW, STEEL = "#9ed4f4", "#4a90d8", "#f2f6fa", "#b8c8d8"


def white_wolf():
    """tundra_white_wolf | Quadruped | 4 | white-blue fur."""
    m = Model("tundra_white_wolf", "Mobs", zone=4, rig="Quadruped", size=4, name="White Wolf")
    p = P.quadruped(m, "#e2ecf6", belly="#ffffff", dark="#8eaad8", body_len=1.9, body_h=0.72, body_w=0.85,
                    leg_len=1.5, leg_r=0.2, head_r=0.62, snout_len=0.85, snout_r=0.28, ears="pointy", tail="bushy",
                    head_up=0.35)
    hx, hy, hz = p["head_at"]
    for s in (-1, 1):
        p["Head"].cone((s * 0.13, hy - 0.4, hz - 1.15), (s * 0.13, hy - 0.68, hz - 1.18), 0.06, 0, P.SHINE, segs=3)
    p["Body"].box((0, p["y0"] + 0.62, -0.6), (0.5, 0.3, 1.4), "#a8c0e8", taper=0.5)
    return m


def arctic_fox():
    """tundra_arctic_fox | Quadruped | 3 | white fox, big tail."""
    m = Model("tundra_arctic_fox", "Mobs", zone=4, rig="Quadruped", size=3, name="Arctic Fox")
    p = P.quadruped(m, "#f4f6fa", belly="#ffffff", dark="#b4c4d8", body_len=1.6, body_h=0.62, body_w=0.75,
                    leg_len=1.0, leg_r=0.16, head_r=0.6, snout_len=0.7, snout_r=0.22, ears="pointy", tail="bushy",
                    head_up=0.35)
    tail = p["Tail"]
    tail.ico((0, p["y0"] + 0.1, 2.3), 0.55, (0.9, 0.85, 1.6), "#ffffff", jit=0.05)  # big fluffy tail
    tail.ico((0, p["y0"] - 0.05, 3.0), 0.35, (1, 1, 1), "#dce6f2", sub=1)
    return m


def cursed_snowman():
    """tundra_cursed_snowman | Snowman | 5 | stacked snowballs, glowing purple coal eyes, stick arms."""
    m = Model("tundra_cursed_snowman", "Mobs", zone=4, rig="Snowman", size=5, name="Cursed Snowman")
    snow, shade_, stick = "#f0f4fa", "#c8d4e4", "#6a4a2e"
    body = m.part("Body", joint=(0, 1.3, 0))
    body.ico((0, 1.3, 0), 1.3, (1, 0.95, 1), snow, sub=2, jit=0.05)
    body.ico((0, 0.5, 0), 1.15, (1, 0.4, 1), shade_, sub=1, jit=0.03)
    mid = m.part("Middle", "Body", joint=(0, 2.45, 0))
    mid.ico((0, 3.05, 0), 1.0, (1, 0.95, 1), snow, sub=2, jit=0.05)
    for k in range(3):  # coal buttons
        mid.ico((0, 3.45 - k * 0.35, -0.95), 0.12, (1, 1, 0.6), "#2a2028", sub=0)
    mid.box((0, 3.75, 0), (1.6, 0.25, 1.6), "#7a3ab8", jit=0.02)  # ragged purple scarf
    mid.box((0.45, 3.35, -0.75), (0.25, 0.8, 0.12), "#7a3ab8", rot=(0, 0, -10))
    head = m.part("Head", "Middle", joint=(0, 3.95, 0))
    head.ico((0, 4.45, 0), 0.75, (1, 0.95, 1), snow, sub=2, jit=0.05)
    head.cone((0, 4.4, -0.7), (0, 4.3, -1.35), 0.12, 0.0, "#e87a2a", segs=5)  # carrot nose
    head.cyl((0, 5.0, 0), (0, 5.75, 0.05), 0.42, "#2a2028", segs=6)  # battered top hat
    head.cyl((0, 5.0, 0), (0, 5.08, 0), 0.7, "#2a2028", segs=6)
    head.box((0, 4.15, -0.68), (0.55, 0.08, 0.06), "#2a2028")  # crooked coal grin
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.ico((s * 0.27, 4.62, -0.66), 0.12, (1, 1, 0.6), "#c050ff", sub=1)
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        arm = m.part(name, "Middle", joint=(s * 0.9, 3.25, 0))
        arm.cyl((s * 0.9, 3.25, 0), (s * 2.3, 3.7, -0.1), 0.07, stick, segs=4)
        arm.cyl((s * 1.9, 3.58, -0.08), (s * 2.25, 4.05, -0.2), 0.05, stick, segs=3)
        arm.cyl((s * 2.3, 3.7, -0.1), (s * 2.65, 3.6, -0.3), 0.04, stick, segs=3)
    return m


def ice_spirit():
    """tundra_ice_spirit | Floater | 4 | translucent blue crystals."""
    m = Model("tundra_ice_spirit", "Mobs", zone=4, rig="Floater", size=4, name="Ice Spirit")
    b = P.floater(m, "#a8dcf8", glow="#e8faff", crystals="#62b8f0")
    for (x, y, z) in ((0.7, 1.6, 0.1), (-0.6, 1.3, 0.2), (0.3, 0.8, 0.3), (-0.2, 1.9, 0.6), (0.5, 2.0, 0.5)):
        m.parts["Tail"].cone((x, y, z), (x * 1.6, y + 0.5, z + 0.3), 0.14, 0.0, "#d8f2ff", segs=4)  # ice shards
    b.ico((0, 2.65, 0.25), 0.9, (1.05, 1.0, 0.8), "#c8ecff", sub=2, jit=0.05)  # inner crystal facets
    for name, sx in (("ArmL", -1), ("ArmR", 1)):
        m.parts[name].cone((sx * 1.5, 1.95, -0.25), (sx * 1.7, 1.5, -0.45), 0.14, 0.0, "#d8f2ff", segs=4)
    return m


def polar_bear():
    """tundra_polar_bear | Quadruped | 6.5 | heavy white bear."""
    m = Model("tundra_polar_bear", "Mobs", zone=4, rig="Quadruped", size=6.5, name="Polar Bear")
    p = P.quadruped(m, "#eef0ea", belly="#f8f8f4", dark="#c8ccc4", body_len=2.2, body_h=1.1, body_w=1.2,
                    leg_len=1.3, leg_r=0.36, head_r=0.75, snout_len=0.7, snout_r=0.36, ears="round", tail="short",
                    head_up=0.15, neck=0.35, jit=0.06, paws="#d0d4cc")
    hx, hy, hz = p["head_at"]
    p["Head"].ico((0, hy - 0.2, hz - 1.35), 0.15, (1, 0.8, 0.7), "#2a2a30", sub=0)  # black nose
    for name in ("LegFL", "LegFR"):
        x = -0.66 if name == "LegFL" else 0.66
        for k in range(3):
            p[name].cone((x - 0.15 + k * 0.15, 0.2, -1.62), (x - 0.15 + k * 0.15, 0.05, -1.9), 0.05, 0, "#3a3a40", segs=3)
    return m


def swordfish():
    """tundra_swordfish | Fish | 4 | long bill, hovers."""
    m = Model("tundra_swordfish", "Mobs", zone=4, rig="Fish", size=4, name="Swordfish")
    b = P.fish(m, "#486ea8", "#d4e0f0", fin="#2e4a7a", jaw=False, teeth=False, bill=True)
    b.box((0, 2.35, 0.0), (0.06, 1.1, 1.4), "#2e4a7a", taper=0.25)  # tall sail fin
    for s_ in (-1, 1):
        b.box((s_ * 0.42, 1.3, 0.3), (0.06, 0.12, 1.2), "#9ab8e0")  # silver side stripes
    return m


def yeti():
    """tundra_yeti | Biped brute | 8 | white fur, blue face."""
    m = Model("tundra_yeti", "Mobs", zone=4, rig="Biped", size=8, name="Yeti")
    fur, face = "#eef2f6", "#6a98d8"
    b = P.biped(m, skin=face, shirt=fur, pants=fur, boots="#c8d4e0", belt=fur, buckle=fur, gloves=fur, head_r=0.66,
                bulk=1.45, jit=0.05)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy + 0.15, 0.15), hr * 1.08, (1.1, 1.05, 1.0), fur, sub=1, jit=0.06)  # fur around the face
    b["Head"].box((0, hy + 0.3, -hr * 0.8), (hr * 1.4, 0.18, 0.15), "#4a70b0")  # heavy brow
    for s in (-1, 1):
        b["Head"].cone((s * 0.2, hy - 0.35, -hr * 0.75), (s * 0.22, hy - 0.05, -hr * 0.85), 0.07, 0, P.SHINE, segs=3)
    b["Torso"].ico((0, 3.0, -0.35), 0.95, (1.3, 0.95, 0.7), "#ffffff", sub=1, jit=0.06)  # shaggy chest
    for k in range(5):  # fur tufts
        b["Torso"].cone((-0.8 + k * 0.4, 2.35, -0.5), (-0.85 + k * 0.42, 1.95, -0.55), 0.18, 0, fur, segs=4)
    for s, name in ((-1, "ArmL"), (1, "ArmR")):
        x = s * (b["ax"] + 0.12)
        for k in range(3):
            b[name].cone((x - 0.12 + k * 0.12, 1.75, -0.2), (x - 0.12 + k * 0.12, 1.45, -0.35), 0.05, 0, "#3a4a6a", segs=3)
    return m


def furious_ibex():
    """tundra_furious_ibex | Quadruped | 5 | big curved horns."""
    m = Model("tundra_furious_ibex", "Mobs", zone=4, rig="Quadruped", size=5, name="Furious Ibex")
    p = P.quadruped(m, "#a88a6a", belly="#e8dcc8", dark="#5a4632", body_len=1.7, body_h=0.75, body_w=0.85,
                    leg_len=1.6, leg_r=0.17, head_r=0.55, snout_len=0.55, snout_r=0.22, ears="pointy", tail="short",
                    head_up=0.45)
    hx, hy, hz = p["head_at"]
    head = p["Head"]
    for s in (-1, 1):  # big curved horns (3 segments)
        pts = [(s * 0.25, hy + 0.45, hz + 0.1), (s * 0.45, hy + 1.2, hz + 0.6), (s * 0.6, hy + 1.3, hz + 1.4),
               (s * 0.65, hy + 0.7, hz + 1.8)]
        for i in range(3):
            head.cone(pts[i], pts[i + 1], 0.22 - i * 0.06, 0.16 - i * 0.06, "#e0d4bc" if i % 2 == 0 else "#c8bca4", segs=5)
    head.cone((0, hy - 0.45, hz - 0.85), (0, hy - 0.95, hz - 0.8), 0.12, 0.04, "#5a4632", segs=4)  # beard
    return m


def ice_eagle():
    """tundra_ice_eagle | Bird | 4.5 | pale blue-white."""
    m = Model("tundra_ice_eagle", "Mobs", zone=4, rig="Bird", size=4.5, name="Ice Eagle")
    p = P.bird(m, "#cce0f2", wing="#8ab4e0", belly="#f4f8fc", beak="#f0d060", legs="#f0d060", wing_span=2.7)
    for k in range(3):  # icy crest
        p["Head"].cone((0, 2.4, -0.85 + k * 0.15), (0, 2.85 - k * 0.1, -0.55 + k * 0.25), 0.1, 0, "#62b8f0", segs=3)
    return m


def ice_knight():
    """tundra_ice_knight | Biped | 6 | ice-blue plate armor, sword and shield."""
    m = Model("tundra_ice_knight", "Mobs", zone=4, rig="Biped", size=6, name="Ice Knight")
    plate, dark = "#98c8ec", "#5a8ab8"
    b = P.biped(m, skin=plate, shirt=plate, pants=dark, boots=plate, belt=dark, buckle="#e8f6ff", gloves=plate)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy, 0), hr * 1.06, (1.0, 1.08, 1.02), plate, sub=1, jit=0.02)  # great helm
    b["Head"].box((0, hy + 0.05, -hr * 0.98), (hr * 1.3, 0.12, 0.08), "#1a2a3a")  # visor slit
    b["Head"].cone((0, hy + hr * 0.9, 0), (0, hy + hr * 1.6, 0.2), 0.2, 0, "#e8f6ff", segs=4)  # ice spike
    for s in (-1, 1):
        b["Torso"].ico((s * 0.92, 3.55, 0), 0.38, (1.1, 0.8, 1.1), dark, sub=1)  # pauldrons
    b["Torso"].box((0, 3.05, -0.4), (0.8, 0.9, 0.08), "#c4e4f8", taper=0.7)  # chest plate
    x, y, z = b["hands"]["L"]
    b["ArmL"].box((x - 0.12, y + 0.55, z - 0.15), (0.16, 1.7, 1.25), dark, taper=0.8)  # kite shield
    b["ArmL"].box((x - 0.22, y + 0.6, z - 0.15), (0.06, 0.9, 0.2), "#e8f6ff")
    P.sword(b["ArmR"], b["hands"]["R"], length=2.0, width=0.2, blade="#d8f0ff", hilt=dark, guard="#e8f6ff")
    return m


def frost_golem():
    """tundra_frost_golem | Golem | 9 | ice blocks with blue crystals (reference 5 recolored)."""
    m = Model("tundra_frost_golem", "Mobs", zone=4, rig="Golem", size=9, name="Frost Golem")
    g = P.golem(m, "#b8dcf4", dark="#7aaed8", glow="#62d0ff", slabs=False, jit=0.08)
    crystals = m.glow("Crystals", "Body")
    for (x, y, h) in ((0, 4.2, 1.2), (0.6, 3.9, 0.8), (-0.6, 3.9, 0.8), (0.3, 4.6, 0.6), (-0.35, 4.7, 0.6)):
        crystals.cone((x, y, 1.0), (x * 1.3, y + h, 1.4), 0.22, 0.0, "#62d0ff", segs=4)
    for (x, y) in ((-1.9, 5.7), (1.9, 5.7)):
        g["Body"].cone((x, 5.5, 0), (x * 1.1, 6.6, 0.1), 0.25, 0.0, "#e8f6ff", segs=4)  # icicle spikes on the shoulders
    return m


def frost_wolf_alpha():
    """MINI tundra_frost_wolf_alpha | Quadruped | 10 | huge white wolf with ice shards."""
    m = Model("tundra_frost_wolf_alpha", "MiniBosses", zone=4, rig="Quadruped", size=10, role="mini",
              name="Frost Wolf Alpha")
    p = P.quadruped(m, "#e6eef8", belly="#ffffff", dark="#8eaad8", body_len=2.1, body_h=0.85, body_w=0.95,
                    leg_len=1.55, leg_r=0.24, head_r=0.7, snout_len=0.9, snout_r=0.3, ears="pointy", tail="bushy",
                    head_up=0.4)
    hx, hy, hz = p["head_at"]
    y0 = p["y0"]
    for s in (-1, 1):
        p["Head"].cone((s * 0.15, hy - 0.45, hz - 1.25), (s * 0.15, hy - 0.8, hz - 1.28), 0.07, 0, P.SHINE, segs=3)
    shards = m.glow("Shards", "Body")
    for k, (x, z, h) in enumerate(((0, -1.1, 1.1), (0.3, -0.5, 0.9), (-0.3, -0.5, 0.9), (0, 0.1, 1.0), (0.25, 0.7, 0.7),
                                   (-0.25, 0.7, 0.7), (0, 1.2, 0.6))):
        shards.cone((x, y0 + 0.6, z), (x * 1.5, y0 + 0.6 + h, z + 0.35), 0.2, 0.0, "#7ad8ff", segs=4)
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.ico((s * 0.32, hy + 0.18, hz - 0.55), 0.12, (1.2, 0.7, 0.5), "#7ad8ff", sub=1)
    p["Body"].ico((0, y0 + 0.45, -1.1), 0.9, (1.15, 0.9, 0.8), "#f4f8ff", sub=1, jit=0.06)  # shaggy mane
    return m


def ice_knight_captain():
    """MINI tundra_ice_knight_captain | Biped | 10 | taller, crested helm, greatsword."""
    m = Model("tundra_ice_knight_captain", "MiniBosses", zone=4, rig="Biped", size=10, role="mini",
              name="Ice Knight Captain")
    plate, dark, trim = "#7ab4e4", "#3a6aa8", "#e8f6ff"
    b = P.biped(m, skin=plate, shirt=plate, pants=dark, boots=plate, belt=dark, buckle=trim, gloves=plate, bulk=1.2)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy, 0), hr * 1.08, (1.0, 1.1, 1.02), plate, sub=1, jit=0.02)
    b["Head"].box((0, hy + 0.05, -hr * 0.98), (hr * 1.3, 0.12, 0.08), "#10202e")
    b["Head"].box((0, hy + hr * 1.15, 0.05), (0.18, 0.75, 1.6), trim, taper=0.5)  # crest
    for s in (-1, 1):
        b["Torso"].ico((s * 1.05, 3.6, 0), 0.48, (1.15, 0.8, 1.15), dark, sub=1)
        b["Torso"].cone((s * 1.15, 3.85, 0), (s * 1.35, 4.5, 0.05), 0.15, 0, trim, segs=4)  # shoulder spikes
    b["Torso"].box((0, 3.05, -0.46), (0.9, 1.0, 0.08), trim, taper=0.7)
    b["Torso"].box((0, 2.7, 0.55), (1.5, 2.8, 0.12), "#2a4a8a", taper=1.25)  # cape
    x, y, z = b["hands"]["R"]  # greatsword
    b["ArmR"].cyl((x, y + 0.35, z), (x, y - 0.25, z - 0.1), 0.09, dark, segs=5)
    b["ArmR"].box((x, y - 0.3, z - 0.15), (0.16, 0.16, 0.9), trim)
    b["ArmR"].cone((x, y - 0.4, z - 0.25), (x, y - 0.6, z - 3.4), 0.3, 0.04, "#d8f0ff", segs=4)
    return m


def frost_king():
    """BOSS tundra_frost_king | Boss-Biped | 18 | icicle crown, ice cloak, huge ice mace."""
    m = Model("tundra_frost_king", "Bosses", zone=4, rig="BossBiped", size=18, role="boss", name="Frost King")
    robe, deep, trim, skin = "#6a9ad8", "#2a4a8a", "#e8f6ff", "#b8d4ec"
    b = P.biped(m, skin=skin, shirt=robe, pants=deep, boots=trim, belt="#c8e4f8", buckle="#62d0ff", gloves=trim,
                head_r=0.74, bulk=1.3, jit=0.05)
    hy, hr = b["head_y"], b["head_r"]
    head = b["Head"]
    head.ico((0, hy - 0.45, -0.35), 0.6, (1.2, 1.3, 0.7), trim, sub=1, jit=0.06)  # frost beard
    for k in range(5):
        head.cone((-0.4 + k * 0.2, hy - 0.9, -0.5), (-0.42 + k * 0.21, hy - 1.6, -0.55), 0.1, 0, trim, segs=3)
    crown = m.glow("Crown", "Head")
    crown.cyl((0, hy + hr * 0.7, 0), (0, hy + hr * 0.95, 0), hr * 0.95, "#8ae4ff", segs=8)
    for k in range(7):  # icicle crown spikes
        import math as _m
        a = k / 7 * 2 * _m.pi
        x, z = _m.sin(a) * hr * 0.85, -_m.cos(a) * hr * 0.85
        h = 1.2 if k == 0 else (0.9 if k in (1, 6) else 0.65)
        crown.cone((x, hy + hr * 0.9, z), (x * 1.1, hy + hr * 0.9 + h, z * 1.1), 0.14, 0.0, "#8ae4ff", segs=4)
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.box((s * 0.26, hy + 0.1, -hr * 0.95), (0.22, 0.09, 0.06), "#96f0ff")
    torso = b["Torso"]
    torso.box((0, 2.95, 0.6), (2.4, 3.6, 0.2), deep, taper=1.3, jit=0.03)  # ice cloak
    for k in range(6):  # jagged ice cloak edge
        torso.cone((-1.4 + k * 0.56, 1.25, 0.65), (-1.45 + k * 0.58, 0.45, 0.7), 0.25, 0, "#a8dcf8", segs=4)
    for s in (-1, 1):
        torso.ico((s * 1.0, 3.65, 0), 0.55, (1.2, 0.85, 1.2), trim, sub=1, jit=0.05)  # frost pauldrons
        torso.cone((s * 1.15, 3.9, 0), (s * 1.5, 4.8, 0.1), 0.2, 0, "#a8dcf8", segs=4)
    torso.box((0, 3.6, -0.05), (2.0, 0.3, 1.1), "#c8e4f8", taper=0.8)  # fur collar
    torso.box((0, 2.95, -0.47), (0.9, 1.0, 0.08), trim, taper=0.7)
    torso.box((0, 1.85, -0.5), (1.1, 1.0, 0.1), robe, taper=0.6)
    gem = m.glow("Gem", "Torso")
    gem.ico((0, 3.1, -0.55), 0.22, (1, 1, 0.5), "#62d0ff", sub=1)
    for (x, y, z, r) in ((-0.9, 3.75, -0.45, 0.32), (0.9, 3.75, -0.45, 0.32), (-0.5, 3.8, -0.55, 0.3), (0.5, 3.8, -0.55, 0.3),
                         (0.0, 3.85, -0.6, 0.3), (-1.2, 3.7, 0.3, 0.35), (1.2, 3.7, 0.3, 0.35), (0.0, 3.8, 0.55, 0.4)):
        torso.ico((x, y, z), r, (1.2, 0.8, 1.0), "#f4faff", sub=1, jit=0.07)  # frost fur on the collar
    for s in (-1, 1):  # frost bracers
        b["ArmL" if s < 0 else "ArmR"].ico((s * (b["ax"] + 0.14), 2.25, -0.04), 0.36, (1.1, 0.8, 1.1), "#f4faff", sub=1, jit=0.06)
    x, y, z = b["hands"]["R"]  # huge ice mace
    b["ArmR"].cyl((x, y + 0.4, z), (x, y - 0.3, z - 2.6), 0.13, "#5a7ab0", segs=6)
    b["ArmR"].ico((x, y - 0.45, z - 3.0), 0.8, (1, 1, 1.1), "#a8dcf8", sub=1, jit=0.08)
    b["ArmR"].ico((x, y + 0.5, z + 0.1), 0.25, (1, 1, 1), "#e8f6ff", sub=1, jit=0.05)  # pommel
    for (dx, dy, dz) in ((0.8, 0, 0), (-0.8, 0, 0), (0, 0.8, 0), (0, -0.8, 0), (0, 0, -0.9), (0.5, 0.5, -0.5)):
        b["ArmR"].cone((x + dx * 0.6, y - 0.45 + dy * 0.6, z - 3.0 + dz * 0.6),
                       (x + dx * 1.3, y - 0.45 + dy * 1.3, z - 3.0 + dz * 1.3), 0.18, 0, "#e8f6ff", segs=4)
    return m


RECIPES = {
    "tundra_white_wolf": white_wolf,
    "tundra_arctic_fox": arctic_fox,
    "tundra_cursed_snowman": cursed_snowman,
    "tundra_ice_spirit": ice_spirit,
    "tundra_polar_bear": polar_bear,
    "tundra_swordfish": swordfish,
    "tundra_yeti": yeti,
    "tundra_furious_ibex": furious_ibex,
    "tundra_ice_eagle": ice_eagle,
    "tundra_ice_knight": ice_knight,
    "tundra_frost_golem": frost_golem,
    "tundra_frost_wolf_alpha": frost_wolf_alpha,
    "tundra_ice_knight_captain": ice_knight_captain,
    "tundra_frost_king": frost_king,
}
