"""Zone 3 - Jungle: mobs, mini-bosses, boss (docs/enemies_npcs_pets_brief.txt Part F).

Coordinates: Roblox model space in studs (x right, y up, z back, the creature faces -Z), feet on y = 0.
References: 4 (low-poly frog: smooth big facets, large black glossy eyes), 1 (low-poly gorilla: hunched
knuckle-walking pose, huge chest and arms, faceted face).
"""
from fyd_creatures import Model
import fyd_creature_parts as P

JADE, GOLD, BONE = "#3a9a5a", "#e0b040", "#ece4cc"


def monkey():
    """jungle_monkey | Biped (simian) | 3.5 | brown fur, long arms."""
    m = Model("jungle_monkey", "Mobs", zone=3, rig="Biped", size=3.5, name="Monkey")
    fur, face = "#7a5234", "#d8a880"
    b = P.biped(m, skin=face, shirt=fur, pants=fur, boots=P.shade(fur, 0.8), belt=fur, buckle=fur, gloves=fur,
                head_r=0.82, jit=0.04)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy + 0.12, 0.12), hr * 1.02, (1.05, 1.0, 1.0), fur, sub=1, jit=0.04)  # fur cap behind the face
    for s in (-1, 1):
        b["Head"].ico((s * hr * 1.0, hy + 0.05, 0.05), hr * 0.32, (0.5, 1, 1), face, sub=1)  # round ears
    for s, name in ((-1, "ArmL"), (1, "ArmR")):  # longer arms: hands near the knees
        x = s * (b["ax"] + 0.12)
        b[name].cone((x, 2.0, -0.05), (x * 1.04, 1.2, -0.1), 0.14, 0.12, fur, segs=5)
        b[name].ico((x * 1.04, 1.05, -0.12), 0.18, (1, 1.1, 1), face, sub=1)
    b["Torso"].cone((0, 2.3, 0.35), (0, 3.6, 1.4), 0.12, 0.06, fur, segs=4)  # curly tail
    b["Torso"].ico((0, 3.75, 1.35), 0.2, (1, 1, 1), fur, sub=0)
    return m


def green_snake():
    """jungle_green_snake | Serpent | 5 long | bright green."""
    m = Model("jungle_green_snake", "Mobs", zone=3, rig="Serpent", size=5, size_axis="length", name="Green Snake")
    P.serpent(m, "#3ec83e", "#e6e050", belly="#c8f0a0", head_r=0.58)
    return m


def venomous_spider():
    """jungle_venomous_spider | Arachnid | 4 | green-black, yellow marks."""
    m = Model("jungle_venomous_spider", "Mobs", zone=3, rig="Arachnid", size=4, name="Venomous Spider")
    p = P.arachnid(m, "#1e3a1e", abdomen="#243e22", legs="#142614", eye="#f0e040")
    for (z, w) in ((0.6, 1.0), (1.1, 0.8), (1.6, 0.5)):
        p["Abdomen"].box((0, 3.0 - (z - 0.6) * 0.3, z), (w, 0.1, 0.18), "#e8d830")
    p["Abdomen"].ico((0, 2.2, 2.15), 0.25, (1, 1, 0.6), "#e8d830", sub=1)
    return m


def piranha():
    """jungle_piranha | Fish | 2.5 | silver-red, big teeth, hovers."""
    m = Model("jungle_piranha", "Mobs", zone=3, rig="Fish", size=2.5, name="Piranha")
    P.fish(m, "#b8bcc8", "#d23a3a", fin="#8a8e9a", jaw=True, teeth=True)
    return m


def toxic_frog():
    """jungle_toxic_frog | Amphibian | 3.5 | bright green with purple / yellow warning marks (reference 4)."""
    m = Model("jungle_toxic_frog", "Mobs", zone=3, rig="Amphibian", size=3.5, name="Toxic Frog")
    green, belly, purple, yellow = "#52d43a", "#d8f0a0", "#8a3ac8", "#f0d030"
    body = m.part("Body", joint=(0, 1.0, 0.2))
    body.ico((0, 1.05, 0.3), 1.0, (1.0, 0.7, 1.05), green, jit=0.03)
    body.ico((0, 0.7, 0.0), 0.8, (0.9, 0.4, 0.9), belly, sub=1)
    for (x, z, r, c) in ((-0.45, 0.55, 0.28, purple), (0.5, 0.1, 0.24, purple), (0.25, 0.85, 0.2, yellow),
                         (-0.2, -0.05, 0.18, yellow), (0.0, 0.95, 0.15, purple)):
        body.ico((x, 1.68, z), r, (1, 0.25, 1), c, sub=1)
    head = m.part("Head", "Body", joint=(0, 1.3, -0.4))
    head.ico((0, 1.45, -0.95), 0.95, (1.0, 0.62, 0.8), green, jit=0.03)
    head.box((0, 1.12, -1.6), (1.5, 0.06, 0.2), "#2a6a20")  # mouth line
    P.eyes(head, 0.62, 2.05, -1.0, r=0.36, depth=0.9)
    head.ico((0, 1.9, -0.75), 0.2, (1.4, 0.3, 1), purple, sub=1)
    for name, x, z, front in (("LegFL", -1, -0.75, True), ("LegFR", 1, -0.75, True), ("LegBL", -1, 0.75, False),
                              ("LegBR", 1, 0.75, False)):
        leg = m.part(name, "Body", joint=(x * 0.75, 0.75, z))
        if front:
            leg.cone((x * 0.75, 0.75, z), (x * 0.85, 0.15, z - 0.15), 0.18, 0.14, green, segs=5)
            leg.box((x * 0.9, 0.06, z - 0.35), (0.55, 0.1, 0.5), yellow, taper=1.0)
        else:
            leg.ico((x * 1.1, 0.55, z + 0.15), 0.5, (0.7, 0.55, 1.1), green, jit=0.03)
            leg.cone((x * 1.15, 0.35, z + 0.45), (x * 1.2, 0.1, z - 0.3), 0.18, 0.14, green, segs=5)
            leg.box((x * 1.2, 0.06, z - 0.5), (0.6, 0.1, 0.55), yellow)
    return m


def tribal_warrior():
    """jungle_tribal_warrior | Biped | 5.5 | face paint, feathers, spear."""
    m = Model("jungle_tribal_warrior", "Mobs", zone=3, rig="Biped", size=5.5, name="Tribal Warrior")
    skin = "#a86a44"
    b = P.biped(m, skin=skin, shirt=skin, pants="#c8a060", boots="#6a4a2e", belt="#6a3a22", buckle=BONE,
                sleeves=False)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].box((0, hy + 0.05, -0.62), (0.95, 0.12, 0.1), "#e8e0d0")  # face paint stripes
    b["Head"].box((0, hy - 0.2, -0.6), (0.6, 0.1, 0.1), "#c83a2e")
    for k, c in enumerate(("#d83a2a", "#f0c030", "#2a9a5a")):  # feather crown
        b["Head"].cone((-0.25 + k * 0.25, hy + hr * 0.7, 0.2), (-0.35 + k * 0.35, hy + hr * 2.0, 0.45), 0.12, 0, c, segs=3)
    b["Torso"].box((0, 3.4, -0.02), (1.3, 0.14, 0.8), "#e8e0d0")  # bone necklace
    b["Torso"].box((0, 1.95, -0.4), (0.8, 0.7, 0.08), "#c8a060", taper=0.7)
    P.spear(b["ArmR"], b["hands"]["R"], length=4.4, shaft="#7a5232", tip="#3a3a3a")
    return m


def jaguar():
    """jungle_jaguar | Quadruped | 5 | golden with black rosettes."""
    m = Model("jungle_jaguar", "Mobs", zone=3, rig="Quadruped", size=5, name="Jaguar")
    p = P.quadruped(m, "#dcaa40", belly="#f4e4b8", dark="#2a2018", body_len=2.1, body_h=0.75, body_w=0.85,
                    leg_len=1.35, leg_r=0.22, head_r=0.7, snout_len=0.4, snout_r=0.3, ears="round", tail="long",
                    head_up=0.25)
    y0 = p["y0"]
    for (x, z) in ((-0.5, -1.2), (0.45, -0.7), (-0.3, -0.2), (0.55, 0.4), (-0.55, 0.7), (0.2, 1.2), (-0.1, 0.3),
                   (0.0, -0.9)):
        p["Body"].ico((x, y0 + 0.62, z), 0.2, (1, 0.25, 1), "#2a2018", sub=0)
    for (x, z) in ((-0.82, -0.6), (0.82, 0.3), (-0.82, 0.9), (0.82, -1.0)):  # side spots
        p["Body"].ico((x, y0 + 0.1, z), 0.18, (0.25, 1, 1), "#2a2018", sub=0)
    return m


def animated_statue():
    """jungle_animated_statue | Golem | 7 | mossy idol with glowing green glyphs."""
    m = Model("jungle_animated_statue", "Mobs", zone=3, rig="Golem", size=7, name="Animated Statue")
    g = P.golem(m, "#7a8470", dark="#5a6252", glow="#60ff80", moss="#4a8a3a", slabs=True, slab_jit=0.04)
    glyphs = m.glow("Glyphs", "Body")
    for (x, y) in ((0, 4.6), (-0.6, 3.9), (0.6, 3.9)):
        glyphs.box((x, y, -0.97), (0.35, 0.35, 0.05), "#60ff80", rot=(0, 0, 45))
    g["Head"].box((0, 6.45, -0.35), (1.6, 0.35, 1.3), "#6a7460", taper=0.6)  # idol headdress
    for (x, y, z) in ((-1.1, 4.9, -0.9), (0.9, 3.6, -0.95), (1.7, 5.4, 0.3), (-1.8, 5.2, 0.4), (0.2, 3.1, -0.9)):
        g["Body"].ico((x, y, z), 0.3, (1.2, 0.7, 0.5), "#4a8a3a", sub=1, jit=0.06)  # moss clumps
    for name, sx in (("ArmL", -1), ("ArmR", 1)):
        g[name].ico((sx * 2.3, 2.9, 0.55), 0.3, (1.1, 0.8, 0.6), "#4a8a3a", sub=1, jit=0.06)
        g[name].box((sx * 2.2, 3.4, -0.62), (0.9, 0.1, 0.08), "#60ff80")
    return m


def tribal_archer():
    """jungle_tribal_archer | Biped | 5.5 | blowgun / bow (ranged)."""
    m = Model("jungle_tribal_archer", "Mobs", zone=3, rig="Biped", size=5.5, name="Tribal Archer")
    skin = "#9a603c"
    b = P.biped(m, skin=skin, shirt="#4a8a3a", pants="#b8945a", boots="#5a3e26", belt="#5a3e26", buckle=BONE,
                sleeves=False)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].box((0, hy + 0.1, -0.62), (0.95, 0.1, 0.1), "#2a9a5a")  # green face paint
    b["Head"].cone((0.2, hy + hr * 0.7, 0.2), (0.45, hy + hr * 1.8, 0.5), 0.12, 0, "#2a9a5a", segs=3)
    b["Torso"].cyl((0.3, 3.5, 0.5), (-0.2, 2.5, 0.55), 0.18, "#6a4426", segs=6)  # dart pouch
    P.bow(b["ArmL"], b["hands"]["L"], size=2.6, wood="#5a3a20")
    return m


def shaman():
    """jungle_shaman | Biped | 6 | mask, totem staff, feathers."""
    m = Model("jungle_shaman", "Mobs", zone=3, rig="Biped", size=6, name="Shaman")
    b = P.biped(m, skin="#8a5a3a", shirt="#6a3a8a", pants="#5a3a2a", boots="#3a2a1e", belt=GOLD, buckle="#2a9a5a")
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].box((0, hy, -hr * 0.85), (hr * 1.6, hr * 1.9, 0.25), "#e0c060", taper=0.8)  # wooden mask
    b["Head"].box((0, hy + 0.1, -hr * 1.0), (hr * 1.2, 0.15, 0.08), "#c83a2e")
    for s in (-1, 1):
        b["Head"].box((s * 0.22, hy + 0.25, -hr * 1.0), (0.18, 0.12, 0.06), "#1a1414")
    for k, c in enumerate(("#d83a2a", "#f0c030", "#2a9a5a", "#3a6ad8", "#d83a2a")):
        a = -0.6 + k * 0.3
        b["Head"].cone((a * 0.6, hy + hr * 0.8, 0.1), (a * 1.5, hy + hr * 2.1, 0.3), 0.12, 0, c, segs=3)
    b["Torso"].box((0, 2.5, 0.05), (1.4, 1.2, 0.9), "#5a2a7a", taper=0.9)  # robe skirt
    P.staff(b["ArmR"], b["hands"]["R"], length=4.4, wood="#5a3a22", top="#60ff80", top_r=0.32)
    x, y, z = b["hands"]["R"]
    b["ArmR"].box((x, y + 0.9, z), (0.45, 0.6, 0.45), "#c8a050", taper=0.7)  # totem head on the staff
    return m


def temple_guard():
    """jungle_temple_guard | Biped | 6.5 | stone / bronze armor, big shield."""
    m = Model("jungle_temple_guard", "Mobs", zone=3, rig="Biped", size=6.5, name="Temple Guard")
    bronze, stone = "#b07a3a", "#8a8a7a"
    b = P.biped(m, skin="#9a6a44", shirt=bronze, pants=stone, boots=bronze, belt=stone, buckle=GOLD, gloves=bronze,
                bulk=1.15)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].ico((0, hy + 0.1, 0), hr * 1.08, (1.05, 1.05, 1.05), bronze, sub=1, jit=0.03)  # helmet
    b["Head"].box((0, hy - 0.05, -hr * 0.95), (hr * 1.2, 0.3, 0.12), "#1a1414")  # visor slit
    b["Head"].box((0, hy + hr * 1.0, 0.1), (0.2, 0.5, 1.2), "#2a9a5a", taper=0.6)  # crest
    for s in (-1, 1):
        b["Torso"].box((s * 0.95, 3.6, 0), (0.6, 0.35, 0.8), stone)  # pauldrons
    x, y, z = b["hands"]["L"]
    b["ArmL"].box((x - 0.15, y + 0.7, z - 0.2), (0.2, 2.2, 1.6), stone, taper=0.9)  # big shield
    b["ArmL"].box((x - 0.27, y + 0.7, z - 0.2), (0.06, 0.6, 0.6), GOLD, rot=(45, 0, 0))
    P.sword(b["ArmR"], b["hands"]["R"], length=1.6, width=0.2, blade="#c08a40", hilt="#5a3a22", guard=stone)
    return m


def elder_jaguar():
    """MINI jungle_elder_jaguar | Quadruped | 10 | near-black with glowing gold eyes."""
    m = Model("jungle_elder_jaguar", "MiniBosses", zone=3, rig="Quadruped", size=10, role="mini", name="Elder Jaguar")
    p = P.quadruped(m, "#26222a", belly="#3a3640", dark="#141218", body_len=2.2, body_h=0.85, body_w=0.95,
                    leg_len=1.4, leg_r=0.26, head_r=0.78, snout_len=0.45, snout_r=0.34, ears="round", tail="long",
                    head_up=0.3)
    y0 = p["y0"]
    for (x, z) in ((-0.5, -1.2), (0.45, -0.7), (-0.3, -0.2), (0.55, 0.4), (-0.55, 0.7), (0.2, 1.2), (0.0, -0.9)):
        p["Body"].ico((x, y0 + 0.7, z), 0.22, (1, 0.25, 1), "#3e3846", sub=0)  # faint rosettes
    hx, hy, hz = p["head_at"]
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.ico((s * 0.36, hy + 0.2, hz - 0.62), 0.14, (1.2, 0.7, 0.5), "#ffc840", sub=1)
    for s in (-1, 1):  # fangs
        p["Head"].cone((s * 0.14, hy - 0.4, hz - 0.95), (s * 0.14, hy - 0.8, hz - 0.98), 0.07, 0, BONE, segs=3)
    p["Body"].box((0, y0 + 0.85, -0.3), (0.35, 0.25, 2.0), "#ffc840", taper=0.4)  # gold markings along the spine
    return m


def tribal_warlord():
    """MINI jungle_tribal_warlord | Biped brute | 10 | war paint, skull trophies, big axe."""
    m = Model("jungle_tribal_warlord", "MiniBosses", zone=3, rig="Biped", size=10, role="mini", name="Tribal Warlord")
    skin = "#8a5638"
    b = P.biped(m, skin=skin, shirt=skin, pants="#7a5a36", boots="#4a3422", belt="#5a2a1a", buckle=BONE,
                head_r=0.64, bulk=1.5, sleeves=False, jit=0.04)
    hy, hr = b["head_y"], b["head_r"]
    b["Head"].box((0, hy + 0.08, -hr * 0.92), (hr * 1.7, 0.18, 0.1), "#d83a2a")  # war paint
    b["Head"].box((0, hy - 0.2, -hr * 0.92), (0.12, 0.5, 0.1), "#d83a2a")
    for k, c in enumerate(("#d83a2a", "#f0c030", "#2a9a5a", "#f0c030", "#d83a2a")):  # big feather crest
        a = -0.6 + k * 0.3
        b["Head"].cone((a * 0.5, hy + hr * 0.75, 0.15), (a * 1.6, hy + hr * 2.5, 0.4), 0.14, 0, c, segs=3)
    for k in range(4):  # skull trophies on the belt
        x = -0.75 + k * 0.5
        b["Torso"].ico((x, 2.35, -0.72), 0.22, (1, 1, 0.9), BONE, sub=1)
        b["Torso"].box((x, 2.35, -0.92), (0.2, 0.06, 0.05), "#2a2018")
    for s in (-1, 1):
        b["Torso"].box((s * 1.25, 3.7, 0), (0.75, 0.4, 0.9), BONE, jit=0.04)  # bone shoulder pads
        b["Torso"].box((s * 0.5, 3.1, -0.58), (0.6, 0.1, 0.05), "#d83a2a", rot=(0, 0, s * 30))  # chest paint
    P.axe(b["ArmR"], b["hands"]["R"], length=3.2, haft="#5a3a22", head="#8a8e96", big=True)
    return m


def ancestral_gorilla():
    """BOSS jungle_ancestral_gorilla | Gorilla | 18 | reference 1: hunched knuckle-walker, huge chest and arms, faceted
    face; dark gray-brown fur, golden tribal markings, vine / stone totem bracers, glowing amber eyes."""
    m = Model("jungle_ancestral_gorilla", "Bosses", zone=3, rig="Gorilla", size=18, role="boss", name="Ancestral Gorilla")
    fur, chest, face, gold, stone = "#4a403c", "#6a5c54", "#2a2422", "#e0b040", "#8a8a7a"
    body = m.part("Body", joint=(0, 3.1, 0.3))
    body.ico((0, 3.4, 0.4), 1.75, (1.0, 0.85, 0.85), fur, jit=0.05)  # massive torso
    body.ico((0, 3.35, -0.75), 1.3, (1.1, 0.95, 0.55), chest, sub=1, jit=0.04)  # chest
    body.ico((0, 4.45, -0.2), 1.2, (1.4, 0.6, 0.9), fur, jit=0.05)  # shoulder mass
    body.ico((0, 2.3, 0.9), 1.1, (1.0, 0.7, 0.8), fur, jit=0.05)  # hips
    for s in (-1, 1):  # golden tribal markings
        body.box((s * 0.55, 3.8, -1.35), (0.5, 0.12, 0.05), gold, rot=(0, 0, s * 25))
        body.box((s * 0.55, 3.2, -1.38), (0.5, 0.12, 0.05), gold, rot=(0, 0, s * -25))
        body.box((s * 1.65, 4.2, -0.2), (0.12, 0.9, 0.6), gold)
    body.box((0, 2.7, -1.3), (0.15, 0.9, 0.05), gold)
    head = m.part("Head", "Body", joint=(0, 4.3, -0.9))
    head.ico((0, 4.55, -1.45), 0.85, (1.0, 0.9, 0.9), fur, jit=0.05)
    head.ico((0, 4.3, -2.0), 0.6, (1.2, 0.75, 0.55), face, sub=1, jit=0.03)  # faceted muzzle
    head.box((0, 4.85, -1.9), (1.3, 0.25, 0.35), face)  # heavy brow
    head.ico((0, 5.25, -1.2), 0.55, (1, 0.6, 1), fur, sub=1, jit=0.05)  # crest
    for s in (-1, 1):
        head.ico((s * 0.2, 4.2, -2.3), 0.1, (1, 0.8, 0.6), "#141210", sub=0)  # nostrils
        head.box((s * 0.45, 4.95, -1.7), (0.35, 0.08, 0.06), gold)  # forehead marks
    eye = m.glow("Eyes", "Head")
    for s in (-1, 1):
        eye.ico((s * 0.33, 4.62, -2.05), 0.13, (1.2, 0.8, 0.5), "#ffa830", sub=1)
    for name, s in (("ArmL", -1), ("ArmR", 1)):
        arm = m.part(name, "Body", joint=(s * 1.9, 4.2, -0.5))
        arm.ico((s * 2.1, 3.9, -0.6), 0.85, (0.95, 1.1, 0.95), fur, jit=0.05)  # shoulder
        arm.cone((s * 2.2, 3.5, -0.6), (s * 2.35, 1.9, -0.75), 0.75, 0.6, fur, segs=7, jit=0.04)
        arm.cone((s * 2.35, 1.95, -0.75), (s * 2.4, 0.55, -0.85), 0.62, 0.55, fur, segs=7, jit=0.04)
        arm.ico((s * 2.4, 0.4, -0.95), 0.62, (1.1, 0.7, 1.2), face, jit=0.04)  # knuckle fist
        for k in range(3):  # stone totem bracer bound with vines
            arm.box((s * 2.38, 1.6 - k * 0.38, -0.8), (1.4, 0.3, 1.35), stone if k != 1 else gold, jit=0.03)
        arm.cyl((s * 2.38, 1.9, -1.5), (s * 2.38, 0.8, -1.45), 0.07, "#3e7a2c", segs=4)
    for (x, y, z, r) in ((0.0, 4.3, 1.2, 0.7), (-1.1, 3.0, 1.0, 0.6), (1.1, 3.0, 1.0, 0.6), (-1.3, 4.6, 0.6, 0.5),
                         (1.3, 4.6, 0.6, 0.5)):  # shaggy fur tufts on the back
        body.ico((x, y, z), r, (1.0, 0.8, 0.9), "#3e3532", sub=1, jit=0.07)
    for k in range(3):  # vine sash across the chest
        body.cyl((-1.2 + k * 0.1, 4.3 - k * 0.05, -1.25), (1.2, 2.6 + k * 0.05, -1.3), 0.08, "#3e7a2c", segs=4)
    for name, s in (("LegL", -1), ("LegR", 1)):
        leg = m.part(name, "Body", joint=(s * 0.95, 2.1, 0.9))
        leg.ico((s * 1.0, 1.55, 0.9), 0.7, (0.9, 1.0, 0.95), fur, jit=0.05)
        leg.cone((s * 1.05, 1.1, 0.9), (s * 1.1, 0.25, 0.8), 0.55, 0.5, fur, segs=7)
        leg.box((s * 1.1, 0.15, 0.6), (0.85, 0.3, 1.2), face)
    return m


RECIPES = {
    "jungle_monkey": monkey,
    "jungle_green_snake": green_snake,
    "jungle_venomous_spider": venomous_spider,
    "jungle_piranha": piranha,
    "jungle_toxic_frog": toxic_frog,
    "jungle_tribal_warrior": tribal_warrior,
    "jungle_jaguar": jaguar,
    "jungle_animated_statue": animated_statue,
    "jungle_tribal_archer": tribal_archer,
    "jungle_shaman": shaman,
    "jungle_temple_guard": temple_guard,
    "jungle_elder_jaguar": elder_jaguar,
    "jungle_tribal_warlord": tribal_warlord,
    "jungle_ancestral_gorilla": ancestral_gorilla,
}
