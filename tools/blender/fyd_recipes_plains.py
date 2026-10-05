"""Zone 1 - Plains: mobs, mini-bosses, boss (docs/enemies_npcs_pets_brief.txt Part F).

Coordinates: Roblox model space in studs (x right, y up, z back, the creature faces -Z), feet on y = 0.
The kit rescales each model to its listed height, so the numbers here only need the right proportions.
"""
from fyd_creatures import Model


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


RECIPES = {
    "plains_boar": boar,
}
