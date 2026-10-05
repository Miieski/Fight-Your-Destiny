"""Hub NPCs (docs/enemies_npcs_pets_brief.txt Part F): 8 humanoids after reference 3 (slightly big heads, readable
clothing layers, belts / straps / boots, flat colors), 1,000-2,500 triangles, clips Idle + Wave + Talk.
Roblox model space in studs, the NPC faces -Z, feet on y = 0.
"""
from fyd_creatures import Model
import fyd_creature_parts as P

GOLD = "#e0b040"


def _npc(mid, name):
    return Model(mid, "NPC", zone=None, rig="Biped", size=6, role="npc", name=name)


def hair(head, hy, hr, color, style="short"):
    if style == "short":
        head.ico((0, hy + hr * 0.35, 0.12), hr * 0.98, (1.05, 0.75, 1.0), color, sub=1, jit=0.03)
    elif style == "long":
        head.ico((0, hy + hr * 0.3, 0.15), hr * 1.02, (1.08, 0.85, 1.05), color, sub=1, jit=0.03)
        head.box((0, hy - 0.3, 0.45), (hr * 1.7, hr * 1.4, 0.4), color)
    elif style == "bald":
        pass


def beard(head, hy, hr, color, length=0.8):
    head.ico((0, hy - hr * 0.55, -hr * 0.55), hr * 0.6, (1.15, length, 0.7), color, sub=1, jit=0.04)


def guide():
    """npc_guide: tutorial guide, bright adventurer, scarf."""
    m = _npc("npc_guide", "Guide")
    b = P.biped(m, skin="#f0c49a", shirt="#2aa08a", pants="#c89a5a", boots="#6a4026", belt="#5a3a22", buckle=GOLD,
                gloves="#8a5a36")
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#d07a30")
    b["Head"].box((0, hy + hr * 0.78, 0.1), (hr * 2.3, 0.12, hr * 2.1), "#7a5a36")  # explorer hat brim
    b["Head"].cyl((0, hy + hr * 0.78, 0.1), (0, hy + hr * 1.25, 0.1), hr * 0.75, "#8a6a40", segs=8)
    b["Head"].cyl((0, hy + hr * 0.85, 0.1), (0, hy + hr * 0.97, 0.1), hr * 0.77, "#d84a3a", segs=8)  # hat band
    t = b["Torso"]
    t.box((0, 3.62, -0.05), (1.4, 0.32, 0.95), "#f08a2a", taper=0.9)  # bright scarf
    t.box((0.35, 3.25, -0.42), (0.28, 0.75, 0.08), "#f08a2a", rot=(0, 0, -10))  # scarf tail
    t.box((-0.15, 3.0, -0.4), (0.12, 1.4, 0.05), "#5a3a22", rot=(0, 0, 32))  # strap across the chest
    t.box((0, 3.1, 0.55), (1.0, 1.2, 0.5), "#8a6a40", taper=0.9)  # backpack
    t.cyl((-0.4, 3.75, 0.6), (0.4, 3.75, 0.6), 0.16, "#3a8a4a", segs=6)  # rolled blanket
    x, y, z = b["hands"]["L"]  # rolled map
    b["ArmL"].cyl((x, y + 0.05, z - 0.3), (x, y + 0.05, z + 0.3), 0.12, "#f2e6c8", segs=6)
    return m


def blacksmith():
    """npc_blacksmith: Weapon Shop, apron, hammer."""
    m = _npc("npc_blacksmith", "Blacksmith")
    b = P.biped(m, skin="#c88a60", shirt="#c88a60", pants="#4a3a30", boots="#2a2420", belt="#3a2a1e", buckle="#9aa0a8",
                gloves="#3a2a22", bulk=1.25, sleeves=False)
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#2a2420", "bald")
    beard(b["Head"], hy, hr, "#3a2a20", length=0.9)
    b["Head"].box((0, hy + 0.32, -hr * 0.85), (hr * 1.2, 0.12, 0.12), "#2a2420")  # thick brows
    t = b["Torso"]
    t.box((0, 2.75, -0.42), (1.3, 1.9, 0.1), "#6a4a2e", taper=1.0)  # leather apron
    t.box((0, 3.55, -0.44), (0.5, 0.25, 0.08), "#6a4a2e")
    t.box((0.3, 2.6, -0.5), (0.35, 0.3, 0.06), "#4a3220")  # apron pocket
    for s in (-1, 1):
        t.box((s * 0.42, 3.35, -0.2), (0.12, 0.9, 0.55), "#5a3a22")  # apron straps
    x, y, z = b["hands"]["R"]  # smithing hammer
    b["ArmR"].cyl((x, y + 0.2, z), (x, y - 0.1, z - 1.3), 0.07, "#6a4a2e", segs=5)
    b["ArmR"].box((x, y - 0.05, z - 1.3), (0.35, 0.35, 0.65), "#5a5e66")
    return m


def trainer():
    """npc_trainer: Training, bearded fighter."""
    m = _npc("npc_trainer", "Trainer")
    b = P.biped(m, skin="#d29a72", shirt="#c8402e", pants="#2a2a3a", boots="#1a1a20", belt="#e8e0d0", buckle="#e8e0d0",
                gloves="#e8e0d0", bulk=1.15, sleeves=False)
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#5a3420")
    beard(b["Head"], hy, hr, "#5a3420", length=0.75)
    b["Head"].box((0, hy + hr * 0.45, 0), (hr * 2.06, 0.16, hr * 1.95), "#c8402e")  # headband
    b["Head"].box((0.15, hy + hr * 0.4, 0.75), (0.15, 0.5, 0.06), "#c8402e", rot=(0, 0, 20))
    t = b["Torso"]
    t.box((0, 2.6, 0), (1.25, 0.25, 0.8), "#e8e0d0")  # martial belt
    for s in (-1, 1):
        t.box((s * 0.2, 2.35, -0.42), (0.1, 0.45, 0.05), "#e8e0d0", rot=(0, 0, s * 12))  # belt tails
    for s, name in ((-1, "ArmL"), (1, "ArmR")):  # wrapped forearms
        x = s * (b["ax"] + 0.1)
        for k in range(3):
            b[name].box((x, 2.55 - k * 0.2, -0.03), (0.38, 0.06, 0.38), "#e8e0d0")
    return m


def egg_keeper():
    """npc_egg_keeper: Egg Station, farmer hat with a basket of eggs."""
    m = _npc("npc_egg_keeper", "Egg Keeper")
    b = P.biped(m, skin="#f0c49a", shirt="#e8d8a0", pants="#4a6ab0", boots="#6a4a2e", belt="#4a6ab0", buckle=GOLD,
                gloves="#f0c49a")
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#c87a3a", "long")
    b["Head"].cyl((0, hy + hr * 0.7, 0.05), (0, hy + hr * 0.82, 0.05), hr * 1.6, "#e6c870", segs=10)  # straw hat
    b["Head"].cone((0, hy + hr * 0.8, 0.05), (0, hy + hr * 1.45, 0.05), hr * 0.85, hr * 0.5, "#e6c870", segs=8)
    b["Head"].cyl((0, hy + hr * 0.85, 0.05), (0, hy + hr * 0.97, 0.05), hr * 0.86, "#d84a5a", segs=8)
    t = b["Torso"]
    t.box((0, 2.95, -0.42), (1.0, 1.3, 0.08), "#4a6ab0", taper=0.8)  # overalls bib
    for s in (-1, 1):
        t.box((s * 0.35, 3.45, -0.25), (0.12, 0.8, 0.45), "#4a6ab0")
    x, y, z = b["hands"]["L"]  # basket of eggs on the arm
    b["ArmL"].cyl((x - 0.1, y + 0.1, z), (x - 0.1, y + 0.55, z), 0.45, "#a87a40", segs=8)
    for (dx, dz, c) in ((0.0, 0.0, "#f6efe0"), (0.18, 0.12, "#a8e0ff"), (-0.15, 0.15, "#f6c8d8"), (0.1, -0.18, "#c8f0a0")):
        b["ArmL"].ico((x - 0.1 + dx, y + 0.62, z + dz), 0.15, (0.85, 1.15, 0.85), c, sub=1)
    b["ArmL"].cone((x - 0.5, y + 0.55, z), (x - 0.1, y + 1.0, z), 0.04, 0.04, "#8a5a30", segs=4)  # handle
    b["ArmL"].cone((x + 0.3, y + 0.55, z), (x - 0.1, y + 1.0, z), 0.04, 0.04, "#8a5a30", segs=4)
    return m


def trophy_merchant():
    """npc_trophy_merchant: sells trophies, trader with a backpack of trophies."""
    m = _npc("npc_trophy_merchant", "Trophy Merchant")
    b = P.biped(m, skin="#c08a60", shirt="#7a3a8a", pants="#5a4630", boots="#3a2a1e", belt="#3a2a1e", buckle=GOLD,
                gloves="#5a3a22")
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#3a2a20")
    beard(b["Head"], hy, hr, "#6a6a70", length=0.6)
    b["Head"].box((0, hy + hr * 0.8, 0.05), (hr * 2.0, 0.5, hr * 1.9), "#c8402e", taper=0.85)  # trader cap
    b["Head"].ico((0, hy + hr * 1.15, 0.05), 0.12, (1, 1, 1), GOLD, sub=0)
    t = b["Torso"]
    t.box((0, 2.85, -0.05), (1.3, 1.5, 0.85), "#9a5aa8", taper=1.05)  # trader vest
    t.box((0, 3.2, 0.62), (1.3, 1.7, 0.75), "#7a5a36", taper=0.9)  # big backpack
    t.ico((0.3, 4.25, 0.62), 0.32, (1, 1, 1), "#f6efdc", sub=1)  # trophy skull on top
    t.cone((-0.35, 4.0, 0.62), (-0.55, 4.7, 0.65), 0.12, 0, "#e8e0cc", segs=4)  # trophy horn
    t.ico((0.55, 3.55, 1.05), 0.25, (1, 1, 0.6), GOLD, sub=1)  # hanging gold medal
    t.ico((-0.45, 3.3, 1.05), 0.22, (1, 1, 0.6), "#6a8ad8", sub=1)
    for s in (-1, 1):
        t.box((s * 0.42, 3.4, -0.2), (0.14, 1.0, 0.5), "#5a3a22")  # backpack straps
    x, y, z = b["hands"]["R"]  # coin pouch
    b["ArmR"].ico((x, y - 0.15, z), 0.26, (1, 1.2, 1), "#c8a050", sub=1)
    return m


def priest():
    """npc_priest: Rebirth Altar, robed, glowing staff."""
    m = _npc("npc_priest", "Priest")
    robe, trim = "#f2eee4", GOLD
    b = P.biped(m, skin="#e8c0a0", shirt=robe, pants=robe, boots="#d8cfb8", belt=trim, buckle="#8a5ae8", gloves="#e8c0a0")
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#e8e8f0", "long")
    beard(b["Head"], hy, hr, "#e8e8f0", length=1.2)
    t = b["Torso"]
    t.box((0, 1.6, 0), (1.5, 2.2, 1.1), robe, taper=0.75)  # long robe skirt
    t.box((0, 1.6, -0.56), (0.25, 2.1, 0.05), trim)  # gold trim stripe
    t.box((0, 3.6, 0.1), (1.45, 0.45, 1.05), "#8a5ae8", taper=0.85)  # purple stole
    for s in (-1, 1):
        t.box((s * 0.32, 3.0, -0.42), (0.22, 1.2, 0.05), "#8a5ae8")
    b["Head"].cone((0, hy + hr * 0.9, 0.1), (0, hy + hr * 1.9, 0.15), hr * 0.75, hr * 0.3, robe, segs=8)  # tall hat
    b["Head"].box((0, hy + hr * 1.3, -hr * 0.5), (0.25, 0.4, 0.06), trim)
    x, y, z = b["hands"]["R"]  # staff with a glowing orb
    b["ArmR"].cyl((x, y + 2.6, z), (x, y - 1.9, z), 0.1, "#8a6a3a", segs=6)
    b["ArmR"].cone((x, y + 2.6, z), (x, y + 2.9, z), 0.25, 0.15, trim, segs=6)
    orb = m.glow("Orb", "ArmR")
    orb.ico((x, y + 3.15, z), 0.32, (1, 1, 1), "#c890ff", sub=1)
    return m


def gem_merchant():
    """npc_gem_merchant: Diamond Shop, fancy coat, gem pouch."""
    m = _npc("npc_gem_merchant", "Gem Merchant")
    coat, trim = "#2a3a8a", GOLD
    b = P.biped(m, skin="#e8b890", shirt="#f2f2f6", pants="#2a2a3a", boots="#1a1a24", belt=trim, buckle="#5ad8ff",
                gloves="#f2f2f6")
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#2a2028")
    b["Head"].box((0, hy - 0.25, -hr * 0.85), (0.5, 0.08, 0.06), "#2a2028")  # thin mustache
    b["Head"].cyl((0, hy + hr * 0.75, 0.05), (0, hy + hr * 0.85, 0.05), hr * 1.4, "#1a1a24", segs=8)  # top hat
    b["Head"].cyl((0, hy + hr * 0.85, 0.05), (0, hy + hr * 1.9, 0.05), hr * 0.8, "#1a1a24", segs=8)
    b["Head"].cyl((0, hy + hr * 0.9, 0.05), (0, hy + hr * 1.05, 0.05), hr * 0.82, "#5ad8ff", segs=8)
    t = b["Torso"]
    t.box((0, 2.75, 0.05), (1.3, 2.0, 0.85), coat, taper=1.1)  # long fancy coat
    t.box((0, 2.6, 0.45), (1.1, 1.5, 0.1), coat, taper=0.8)  # coat tails
    for k in range(3):
        t.ico((0.25, 3.3 - k * 0.35, -0.44), 0.07, (1, 1, 0.5), trim, sub=0)  # gold buttons
    t.box((0, 3.6, -0.3), (0.9, 0.3, 0.5), trim, taper=0.7)  # gold collar
    x, y, z = b["hands"]["R"]  # gem pouch
    b["ArmR"].ico((x, y - 0.2, z), 0.3, (1, 1.2, 1), "#6a3a8a", sub=1)
    gems = m.glow("Gems", "ArmR")
    for (dx, c) in ((-0.1, "#5ad8ff"), (0.1, "#5ad8ff")):
        gems.ico((x + dx, y + 0.12, z), 0.1, (1, 1.3, 1), c, sub=0)
    return m


def quartermaster():
    """npc_quartermaster: Team Board / Quests, officer with a clipboard."""
    m = _npc("npc_quartermaster", "Quartermaster")
    uniform, trim = "#3a5a3a", GOLD
    b = P.biped(m, skin="#d8a880", shirt=uniform, pants="#2a3a2a", boots="#1a1a1a", belt="#3a2a1e", buckle=trim,
                gloves="#e8e0d0")
    hy, hr = b["head_y"], b["head_r"]
    hair(b["Head"], hy, hr, "#6a4a2e")
    b["Head"].box((0, hy + hr * 0.82, 0.0), (hr * 2.0, 0.35, hr * 2.0), uniform, taper=1.1)  # officer cap
    b["Head"].box((0, hy + hr * 0.72, -hr * 0.95), (hr * 1.6, 0.08, 0.4), "#1a1a1a")  # visor
    b["Head"].ico((0, hy + hr * 0.9, -hr * 1.0), 0.1, (1, 1, 0.5), trim, sub=0)
    t = b["Torso"]
    for s in (-1, 1):
        t.box((s * 0.85, 3.6, 0), (0.4, 0.1, 0.55), trim)  # epaulettes
    for k in range(2):
        t.ico((-0.3 + k * 0.18, 3.25, -0.42), 0.07, (1, 1, 0.5), "#c8402e" if k == 0 else "#3a6ad8", sub=0)  # medals
    t.box((0, 3.05, -0.4), (0.06, 0.9, 0.04), trim)
    x, y, z = b["hands"]["L"]  # clipboard
    b["ArmL"].box((x, y + 0.1, z - 0.15), (0.06, 0.8, 0.6), "#8a6a40")
    b["ArmL"].box((x - 0.04, y + 0.1, z - 0.15), (0.03, 0.7, 0.5), "#f6f2e6")
    b["ArmL"].box((x - 0.05, y + 0.48, z - 0.15), (0.05, 0.08, 0.2), "#9aa0a8")
    return m


RECIPES = {
    "npc_guide": guide,
    "npc_blacksmith": blacksmith,
    "npc_trainer": trainer,
    "npc_egg_keeper": egg_keeper,
    "npc_trophy_merchant": trophy_merchant,
    "npc_priest": priest,
    "npc_gem_merchant": gem_merchant,
    "npc_quartermaster": quartermaster,
}
