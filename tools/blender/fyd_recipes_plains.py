"""Zone 1 - Plains: mobs, mini-bosses, boss (docs/enemies_npcs_pets_brief.txt Part F).

Coordinates: Roblox model space in studs (x right, y up, z back, the creature faces -Z), feet on y = 0.
The kit rescales each model to its listed height, so the numbers here only need the right proportions.
"""
from fyd_creatures import Model
import fyd_creature_parts as P


def boar():
    """plains_boar | Quadruped | 3 | brown boar, tusks, bristle ridge (pilot)."""
    m = Model("plains_boar", "Mobs", zone=1, rig="Quadruped", size=3, role="normal", name="Boar",
              notes="pilot: conventions in Blender/README.txt")
    fur, dark, snout, hoof, ivory = "#7a4e33", "#4a2e1e", "#b9826a", "#2e2019", "#f2ead8"
    body = m.part("Body", joint=(0, 1.75, 0.1))
    body.ico((0, 1.7, 0.2), 1.0, (1.05, 0.92, 1.8), fur, jit=0.05)
    body.ico((0, 2.1, -0.75), 0.82, (1.0, 0.85, 1.1), fur, jit=0.05)  # shoulder hump
    body.ico((0, 1.25, 0.1), 0.7, (0.95, 0.5, 1.4), "#8f6146", sub=1, jit=0.03)  # lighter belly
    for i, z in enumerate((-1.2, -0.65, -0.1, 0.45, 1.0)):
        h = 0.55 - abs(i - 1.2) * 0.07
        body.cone((0, 2.45 - i * 0.06, z), (0, 2.45 - i * 0.06 + h, z + 0.28), 0.17, 0, dark, segs=4)
    head = m.part("Head", "Body", joint=(0, 2.0, -1.45))
    head.ico((0, 1.85, -2.1), 0.8, (0.85, 0.85, 1.05), fur, jit=0.04)
    head.cone((0, 1.62, -2.65), (0, 1.55, -3.25), 0.46, 0.38, snout, segs=6)
    head.disc((0, 1.55, -3.27), 0.36, (0, 0, -1), 0.06, "#3a2318", segs=6)
    head.mirror(lambda s: head.cone((s * 0.33, 1.45, -3.0), (s * 0.47, 1.98, -3.22), 0.09, 0, ivory, segs=4))
    head.mirror(lambda s: head.cone((s * 0.42, 2.4, -1.85), (s * 0.68, 2.95, -1.62), 0.23, 0, "#5e3a26", segs=3))
    head.mirror(lambda s: head.ico((s * 0.43, 2.12, -2.62), 0.12, (1, 1, 0.6), "#141016", sub=1))
    for name, x, z in (("LegFL", -0.62, -0.95), ("LegFR", 0.62, -0.95), ("LegBL", -0.62, 1.2), ("LegBR", 0.62, 1.2)):
        leg = m.part(name, "Body", joint=(x, 1.2, z))
        leg.ico((x * 0.97, 1.32, z), 0.42, (0.8, 1.0, 1.0), fur, sub=1, jit=0.04)
        leg.cone((x, 1.15, z), (x, 0.3, z), 0.27, 0.2, "#6a4330", segs=6)
        leg.cone((x, 0.32, z), (x, 0.0, z), 0.23, 0.25, hoof, segs=6)
    tail = m.part("Tail", "Body", joint=(0, 2.0, 1.9))
    tail.cone((0, 2.0, 1.9), (0, 1.72, 2.25), 0.11, 0.06, dark, segs=4)
    tail.ico((0, 1.66, 2.3), 0.12, (1, 1.3, 1), dark, sub=0)
    return m


def wild_wolf():
    """plains_wild_wolf | Quadruped | 4 | gray lean wolf, fangs."""
    m = Model("plains_wild_wolf", "Mobs", zone=1, rig="Quadruped", size=4, name="Wild Wolf")
    fur, belly = "#82848e", "#d8d8de"
    p = P.quadruped(m, fur, belly=belly, dark="#4e5058", body_len=1.9, body_h=0.72, body_w=0.85, leg_len=1.5,
                    leg_r=0.2, head_r=0.62, snout_len=0.85, snout_r=0.28, ears="pointy", tail="bushy", head_up=0.35)
    hx, hy, hz = p["head_at"]
    for s in (-1, 1):  # fangs
        p["Head"].cone((s * 0.13, hy - 0.4, hz - 1.15), (s * 0.13, hy - 0.68, hz - 1.18), 0.06, 0, P.SHINE, segs=3)
    p["Body"].box((0, p["y0"] + 0.62, -0.6), (0.5, 0.3, 1.4), "#5c5e68", taper=0.5)  # dark back ruff
    return m


def field_bandit():
    """plains_field_bandit | Biped | 5.5 | green hood, dagger, leather vest (reference 3)."""
    m = Model("plains_field_bandit", "Mobs", zone=1, rig="Biped", size=5.5, name="Field Bandit")
    hood, vest = "#3d6b3a", "#7a5434"
    b = P.biped(m, skin="#d9a27a", shirt="#56794a", pants="#4e4030", boots="#3a2a1e", belt="#2b1f15")
    hy, hr = b["head_y"], b["head_r"]
    b["Torso"].box((0, 3.0, 0), (1.26, 1.05, 0.8), vest, taper=1.1)  # leather vest
    b["Torso"].box((0.3, 3.05, -0.41), (0.08, 0.95, 0.04), "#5a3c24")  # vest strap
    b["Head"].ico((0, hy + 0.12, 0.08), hr * 1.12, (1.05, 1.0, 1.05), hood, sub=1, jit=0.03)  # hood
    b["Head"].cone((0, hy + 0.5, 0.45), (0, hy - 0.2, 1.05), 0.35, 0.05, hood, segs=4)  # hood tip
    b["Head"].box((0, hy - 0.35, -0.55), (0.95, 0.35, 0.3), "#2f3a2a")  # face scarf
    P.sword(b["ArmR"], b["hands"]["R"], length=1.0, width=0.14, blade="#b8bcc4", hilt="#3a2a1e", guard="#6a5030")
    return m


def giant_crab():
    """plains_giant_crab | Crustacean | 4 | red-orange shell facets, big claws."""
    m = Model("plains_giant_crab", "Mobs", zone=1, rig="Crustacean", size=4, name="Giant Crab")
    P.crustacean(m, "#e2683a", claw="#f08a50", legs="#b8502a")
    return m


def shipwrecked_pirate():
    """plains_shipwrecked_pirate | Biped | 5.5 | tricorn hat, torn striped shirt, cutlass."""
    m = Model("plains_shipwrecked_pirate", "Mobs", zone=1, rig="Biped", size=5.5, name="Shipwrecked Pirate")
    b = P.biped(m, skin="#d29a72", shirt="#efe6d8", pants="#3a4a6a", boots="#2a1e16", belt="#6a2a1e", buckle="#e0c050")
    hy, hr = b["head_y"], b["head_r"]
    for k in range(3):  # red stripes
        b["Torso"].box((0, 2.65 + k * 0.35, 0), (1.22 + k * 0.05, 0.12, 0.78), "#c03a32")
    b["Torso"].box((0.35, 2.75, -0.38), (0.4, 0.3, 0.05), "#d29a72")  # tear
    b["Head"].box((0, hy + hr * 0.75, 0), (1.55, 0.18, 1.45), "#22222a")  # tricorn brim
    b["Head"].box((0, hy + hr * 1.05, 0.05), (1.0, 0.45, 0.9), "#22222a", taper=0.8)
    for s in (-1, 1):
        b["Head"].cone((s * 0.6, hy + hr * 0.8, -0.3), (s * 0.95, hy + hr * 1.05, -0.55), 0.16, 0, "#22222a", segs=3)
    b["Head"].ico((0, hy - hr * 0.55, -0.45), 0.42, (1.1, 0.7, 0.6), "#5a3a26", sub=1)  # beard
    b["Head"].box((-0.25, hy + 0.08, -0.7), (0.28, 0.24, 0.05), "#141414")  # eye patch
    P.sword(b["ArmR"], b["hands"]["R"], length=2.0, width=0.2, curve=0.35, blade="#c8ccd4", hilt="#3a2a1e", guard="#d8b04a")
    return m


def aggressive_seagull():
    """plains_aggressive_seagull | Bird | 3 | white/gray gull, orange beak, hovers."""
    m = Model("plains_aggressive_seagull", "Mobs", zone=1, rig="Bird", size=3, name="Aggressive Seagull")
    p = P.bird(m, "#eef0f4", wing="#9aa0aa", belly="#ffffff", beak="#f0a030", legs="#e89a40", wing_span=2.2)
    for s in (-1, 1):  # angry brows
        p["Head"].box((s * 0.22, 2.42, -1.33), (0.28, 0.07, 0.08), "#3a3a42", rot=(0, 0, s * 20))
    p["WingL"].box((-2.25, 1.75, 0.5), (0.6, 0.11, 0.5), "#30323a")
    p["WingR"].box((2.25, 1.75, 0.5), (0.6, 0.11, 0.5), "#30323a")
    return m


def brown_bear():
    """plains_brown_bear | Quadruped | 6 | heavy brown bear, rears up to attack."""
    m = Model("plains_brown_bear", "Mobs", zone=1, rig="Quadruped", size=6, name="Brown Bear")
    p = P.quadruped(m, "#704828", belly="#8a5e3a", dark="#46301c", body_len=2.0, body_h=1.15, body_w=1.25,
                    leg_len=1.3, leg_r=0.36, head_r=0.85, snout_len=0.5, snout_r=0.38, ears="round", tail="short",
                    head_up=0.3, jit=0.06, paws="#3a2818")
    p["Body"].ico((0, p["y0"] + 0.75, -0.9), 0.95, (1.1, 0.75, 1.0), "#704828", jit=0.06)  # shoulder hump
    for name in ("LegFL", "LegFR"):
        x = -0.69 if name == "LegFL" else 0.69
        for k in range(3):  # claws
            p[name].cone((x - 0.15 + k * 0.15, 0.2, -1.55), (x - 0.15 + k * 0.15, 0.05, -1.85), 0.05, 0, "#e8e0d0", segs=3)
    return m


def forest_archer():
    """plains_forest_archer | Biped | 5.5 | green hood, bow (ranged)."""
    m = Model("plains_forest_archer", "Mobs", zone=1, rig="Biped", size=5.5, name="Forest Archer")
    b = P.biped(m, skin="#e0b088", shirt="#3e6e38", pants="#6a5236", boots="#4a3422", belt="#5a3c24", gloves="#5a3c24")
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy + 0.1, 0.06), hr * 1.1, (1.05, 1.02, 1.05), "#2e5a2c", sub=1, jit=0.03)
    b["Head"].cone((0, hy + 0.55, 0.35), (0, hy + 0.15, 1.1), 0.3, 0.04, "#2e5a2c", segs=4)
    b["Torso"].box((0, 2.95, 0.05), (1.3, 0.9, 0.85), "#2e5a2c", taper=1.15)  # cape over the shoulders
    b["Torso"].cyl((0.25, 3.6, 0.5), (-0.2, 2.6, 0.55), 0.22, "#6a4426", segs=6)  # quiver
    for k in range(3):
        b["Torso"].cone((0.2 + k * 0.08, 3.6, 0.5), (0.25 + k * 0.09, 4.1, 0.48), 0.04, 0.0, "#d8d0b8", segs=3)
    P.bow(b["ArmL"], b["hands"]["L"], size=2.6)
    return m


def giant_spider():
    """plains_giant_spider | Arachnid | 4.5 | dark purple-brown, red eyes."""
    m = Model("plains_giant_spider", "Mobs", zone=1, rig="Arachnid", size=4.5, name="Giant Spider")
    p = P.arachnid(m, "#4a2e4a", abdomen="#58385a", legs="#3a243a", eye="#e83030")
    p["Abdomen"].box((0, 3.0, 1.2), (0.5, 0.1, 1.2), "#9a5a6a")  # back marking
    p["Abdomen"].box((0, 2.95, 0.7), (0.9, 0.1, 0.25), "#9a5a6a")
    return m


def bat():
    """plains_bat | Bird (bat) | 2.5 | dark, big ears, hovers."""
    m = Model("plains_bat", "Mobs", zone=1, rig="Bird", size=2.5, name="Bat")
    p = P.bird(m, "#34283e", wing="#5a4668", belly="#4a3a56", legs="#2a2030", head_r=0.55, wing_span=2.4, bat=True)
    for s in (-1, 1):  # little fangs
        p["Head"].cone((s * 0.1, 1.82, -1.4), (s * 0.1, 1.6, -1.42), 0.05, 0, "#f0ece0", segs=3)
    return m


def miner_skeleton():
    """plains_miner_skeleton | Biped | 5.5 | bone, mining helmet with lamp, pickaxe."""
    m = Model("plains_miner_skeleton", "Mobs", zone=1, rig="Biped", size=5.5, name="Miner Skeleton")
    bone = "#e6e0cc"
    b = P.biped(m, skin=bone, shirt=bone, pants="#5a5048", boots="#3a3230", belt="#4a3a2a", sleeves=False)
    hy, hr = b["head_y"], b["head_r"]
    for k in range(4):  # ribs
        b["Torso"].box((0, 2.75 + k * 0.22, -0.38), (1.0 - k * 0.05, 0.07, 0.04), "#3a3430")
    b["Torso"].box((0, 3.05, -0.39), (0.1, 0.95, 0.04), "#3a3430")
    for s in (-1, 1):  # eye sockets
        b["Head"].ico((s * 0.24, hy + 0.05, -0.62), 0.16, (1, 1, 0.5), "#1a1414", sub=1)
    b["Head"].box((0, hy - 0.42, -0.6), (0.5, 0.12, 0.08), "#3a3430")  # teeth line
    b["Head"].box((0, hy + hr * 0.72, 0), (1.5, 0.12, 1.5), "#d8a820")  # helmet brim
    b["Head"].ico((0, hy + hr * 0.8, 0), hr * 0.95, (1.0, 0.6, 1.0), "#e0b428", sub=1)
    lamp = m.glow("Lamp", "Head")
    lamp.cyl((0, hy + hr * 0.95, -hr * 0.85), (0, hy + hr * 0.95, -hr * 1.05), 0.18, "#fff2a0", segs=6)
    x, y, z = b["hands"]["R"]  # pickaxe
    b["ArmR"].cyl((x, y + 0.2, z), (x, y - 0.2, z - 2.0), 0.07, "#6a4a2e", segs=5)
    b["ArmR"].cone((x, y - 0.1, z - 1.9), (x, y + 0.6, z - 1.7), 0.12, 0.02, "#8a8e96", segs=4)
    b["ArmR"].cone((x, y - 0.1, z - 1.9), (x, y - 0.75, z - 2.2), 0.12, 0.02, "#8a8e96", segs=4)
    return m


def cave_troll():
    """MINI plains_cave_troll | Biped brute | 10 | gray-green troll, club, bones around belt."""
    m = Model("plains_cave_troll", "MiniBosses", zone=1, rig="Biped", size=10, role="mini", name="Cave Troll")
    skin = "#7a8c74"
    b = P.biped(m, skin=skin, shirt=skin, pants="#5a4630", boots=P.shade(skin, 0.7), belt="#4a3624",
                buckle="#e8e0cc", head_r=0.62, bulk=1.5, sleeves=False, jit=0.05)
    hy, hr = b["head_y"], b["head_r"]
    b["Torso"].ico((0, 2.85, -0.25), 0.95, (1.3, 0.8, 0.9), P.shade(skin, 1.1), sub=2, jit=0.05)  # belly
    b["Torso"].ico((0, 3.45, 0.2), 1.05, (1.4, 0.75, 0.8), skin, sub=2, jit=0.05)  # hunched back
    for k in range(6):  # bones around the belt
        x = -0.75 + k * 0.3
        b["Torso"].cyl((x, 2.35, -0.6), (x + 0.05, 2.05, -0.62), 0.06, "#e8e0cc", segs=4)
        b["Torso"].ico((x + 0.05, 2.0, -0.62), 0.09, (1, 1, 1), "#e8e0cc", sub=0)
    b["Torso"].box((0, 1.95, -0.45), (0.9, 0.6, 0.12), "#6a5038", taper=0.8)  # loincloth
    b["Head"].ico((0, hy - 0.25, -0.45), 0.35, (1.2, 0.6, 0.8), P.shade(skin, 0.9), sub=1)  # big jaw
    for s in (-1, 1):
        b["Head"].cone((s * 0.18, hy - 0.2, -0.75), (s * 0.2, hy + 0.15, -0.8), 0.07, 0, "#f0e8d8", segs=3)  # tusks
        b["Head"].cone((s * 0.55, hy + 0.15, 0), (s * 0.95, hy + 0.35, 0.1), 0.18, 0, skin, segs=3)  # ears
    b["Head"].box((0, hy + 0.32, -0.62), (0.75, 0.14, 0.12), P.shade(skin, 0.6))  # brow
    P.club(b["ArmR"], b["hands"]["R"], length=3.2, wood="#6a4a2e", spikes="#d0c8b8")
    return m


def crystal_spider_matriarch():
    """MINI plains_crystal_spider_matriarch | Arachnid | 9 | teal crystals on the back, bigger fangs."""
    m = Model("plains_crystal_spider_matriarch", "MiniBosses", zone=1, rig="Arachnid", size=9, role="mini",
              name="Crystal Spider Matriarch")
    p = P.arachnid(m, "#3e3448", abdomen="#4a3e58", legs="#2e2638", eye="#40fff0", abd_scale=1.15, fangs="#f0f4f4")
    p["Body"].cone((0, 1.1, -1.3), (0, 0.5, -1.55), 0.22, 0, "#f0f4f4", segs=4)
    crystals = m.glow("Crystals", "Abdomen")
    for (x, z, h, r) in ((0, 1.0, 1.4, 0.32), (0.55, 0.7, 1.0, 0.24), (-0.55, 0.7, 1.0, 0.24), (0.35, 1.6, 0.9, 0.22),
                         (-0.35, 1.6, 0.9, 0.22), (0, 0.3, 0.8, 0.2)):
        crystals.cone((x, 2.7, z), (x * 1.4, 2.7 + h, z + 0.15), r, 0.0, "#3ee8d8", segs=4)
    p["Abdomen"].box((0, 3.05, 1.6), (0.5, 0.12, 1.2), "#5ad8c8")  # teal back marking
    p["Abdomen"].ico((0, 1.45, 1.6), 0.75, (1.0, 0.6, 1.0), "#6a5a7a", sub=1, jit=0.05)  # silk egg sac
    p["Abdomen"].prims[0][1]["sub"] = 4  # a finer faceted abdomen for the mini-boss
    p["Body"].ico((0, 1.95, -0.4), 0.55, (1.1, 0.5, 0.9), "#4a3e58", sub=1, jit=0.04)  # head plate
    for i, z in enumerate((-1.0, -0.6, -0.2, 0.2)):
        for side, s in (("L", -1), ("R", 1)):
            leg = m.parts[f"Leg{side}{i + 1}"]
            knee = (s * (0.55 + 2.4 * 0.45), 2.35, z + z * 0.4)
            leg.ico(knee, 0.2, (1, 1, 1), "#2e2638", sub=0)
            leg.cone(knee, (knee[0] + s * 0.15, knee[1] + 0.55, knee[2]), 0.08, 0, "#3ee8d8", segs=3)  # crystal spikes
            leg.cone((s * 1.3, 1.95, z), (s * 1.3, 2.3, z), 0.05, 0, "#2e2638", segs=3)
    head_crystals = m.glow("HeadCrystals", "Body")
    for (x, z, h) in ((0, -0.3, 0.7), (0.3, -0.1, 0.5), (-0.3, -0.1, 0.5)):
        head_crystals.cone((x, 2.1, z), (x * 1.3, 2.1 + h, z + 0.1), 0.15, 0.0, "#3ee8d8", segs=4)
    return m


def golem_boss():
    """BOSS plains_golem | Golem | 18 | mossy stone golem (reference 6): slabs, moss, sprout, green eyes, rune spiral."""
    m = Model("plains_golem", "Bosses", zone=1, rig="Golem", size=18, role="boss", name="Golem")
    stone, dark, moss = "#7a5a46", "#5a4232", "#5e9a3a"
    g = P.golem(m, stone, dark=dark, glow="#7cff6a", moss=moss, slabs=True)
    body = g["Body"]
    # extra slab detail, moss patches, vines
    for (x, y, z, sx, sy) in ((-0.9, 4.6, -1.0, 0.9, 0.8), (0.8, 3.7, -1.0, 1.0, 0.7), (0.0, 3.0, -0.85, 1.3, 0.4)):
        body.box((x, y, z), (sx, sy, 0.15), P.shade(stone, 1.12), jit=0.02)
    for (x, y, z) in ((-1.2, 4.9, -0.95), (0.9, 4.2, -0.95), (-0.3, 3.4, -0.9), (1.4, 5.3, -0.6)):
        body.ico((x, y, z), 0.32, (1.2, 0.8, 0.35), moss, sub=1, jit=0.05)
    for k in range(4):  # hanging vines
        x = -1.0 + k * 0.65
        body.cyl((x, 5.2, -0.97), (x + 0.1, 3.6 - k * 0.2, -1.0), 0.05, "#3e7a2c", segs=3)
    # sprout on the left shoulder (a little tree)
    body.cyl((-1.75, 5.8, 0.1), (-1.85, 6.9, 0.15), 0.08, "#6a4a2e", segs=4)
    body.ico((-1.85, 7.1, 0.15), 0.42, (1, 0.8, 1), "#7ac24a", sub=1, jit=0.06)
    body.ico((-1.6, 6.85, 0.0), 0.28, (1, 0.8, 1), "#62a83a", sub=1, jit=0.06)
    head = g["Head"]
    head.box((0, 6.3, -0.35), (1.35, 0.25, 1.15), moss, jit=0.02)  # moss cap
    head.box((0, 5.95, -0.9), (1.0, 0.18, 0.1), P.shade(stone, 0.6))  # brow
    for name in ("ArmL", "ArmR"):
        for k in range(3):
            g[name].box(((-2.2 if name == "ArmL" else 2.2), 3.3 - k * 0.5, -0.65), (1.0, 0.12, 0.08), P.shade(stone, 0.8))
    rune = m.glow("Rune", "ArmR")
    for k in range(7):  # rune spiral on the right forearm
        a = k * 0.9
        r = 0.12 + k * 0.05
        import math as _m
        rune.box((2.2 + _m.cos(a) * r, 2.45 + _m.sin(a) * r, -0.82), (0.12, 0.12, 0.05), "#7cff6a")
    chest = m.glow("Core", "Body")
    chest.ico((0, 4.3, -0.98), 0.32, (1, 1, 0.35), "#7cff6a", sub=1)
    # chunky stone details (reference 6): stacked slabs on the chest and back, knuckles, shin plates
    body.box((0, 5.35, 0.1), (3.2, 0.45, 2.0), P.shade(stone, 0.9), rot=(0, 4, 2), jit=0.03)
    body.box((0.2, 4.2, 0.95), (2.4, 1.6, 0.35), P.shade(stone, 0.85), rot=(0, -3, 0), jit=0.03)
    for (x, y) in ((-1.0, 3.9), (1.05, 4.75), (0.15, 5.0)):
        body.ico((x, y, -1.0), 0.28, (1.2, 0.8, 0.4), P.shade(stone, 1.2), sub=1, jit=0.08)
    for name, sx in (("ArmL", -1), ("ArmR", 1)):
        arm = g[name]
        for k in range(4):  # knuckles
            arm.ico((sx * (1.75 + k * 0.3), 1.6, -0.8), 0.32, (1, 1, 1.1), P.shade(stone, 0.95), sub=1, jit=0.08)
        arm.box((sx * 2.2, 3.9, -0.1), (1.6, 0.5, 1.5), P.shade(stone, 1.05), rot=(0, 0, sx * 8), jit=0.03)
        arm.ico((sx * 2.3, 3.3, 0.6), 0.35, (1.2, 0.8, 0.5), moss, sub=1, jit=0.06)
    for name, sx in (("LegL", -1), ("LegR", 1)):
        g[name].box((sx * 0.9, 1.6, -0.62), (1.0, 1.1, 0.2), P.shade(stone, 1.1), jit=0.03)
        g[name].ico((sx * 0.9, 2.2, 0.2), 0.45, (1.2, 0.7, 0.9), moss, sub=1, jit=0.06)
    return m


RECIPES = {
    "plains_boar": boar,
    "plains_wild_wolf": wild_wolf,
    "plains_field_bandit": field_bandit,
    "plains_giant_crab": giant_crab,
    "plains_shipwrecked_pirate": shipwrecked_pirate,
    "plains_aggressive_seagull": aggressive_seagull,
    "plains_brown_bear": brown_bear,
    "plains_forest_archer": forest_archer,
    "plains_giant_spider": giant_spider,
    "plains_bat": bat,
    "plains_miner_skeleton": miner_skeleton,
    "plains_cave_troll": cave_troll,
    "plains_crystal_spider_matriarch": crystal_spider_matriarch,
    "plains_golem": golem_boss,
}
