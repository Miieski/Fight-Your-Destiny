"""Gauntlet V2: 12 builders, zone 1 -> 12, rebuilt from the icons (Icons/Weapons/Gauntlet) with more detail.
~0.5 m (1.8 studs), ONE gauntlet (right hand; mirror it in Studio for the left hand). The origin is the fist center;
the knuckles point along +Z, the forearm cuff goes down -Z, the back of the hand faces -Y (the camera), the thumb is
on the -X side. Tip = the knuckles' striking point, Base = the wrist."""
import math

import fyd_icons as I
import fyd_w2_parts as P
from fyd_weapons2 import pm, point

FINGER_X = (-0.0375, -0.0125, 0.0125, 0.0375)
KNUCKLE_Z = 0.066


def fist(back, fingers=None, knuckles=None, thumb=None, knuckle_r=0.014):
    """Closed fist: back of the hand, 4 curled two-part fingers, knuckles on the back side, thumb on -X."""
    f = fingers or back
    I.box(0.1, 0.075, 0.09, back, loc=(0, 0, 0.0), bevel=0.012, segments=2, smooth=False, name="HandBack")
    for x in FINGER_X:
        I.box(0.022, 0.07, 0.026, f, loc=(x, 0.006, 0.07), bevel=0.007, segments=2, smooth=False, name="Finger")
        I.box(0.021, 0.034, 0.036, f, loc=(x, 0.026, 0.045), bevel=0.007, segments=1, smooth=False, name="FingerTip")
        if knuckles is not None:
            I.sphere(knuckle_r, knuckles, segs=10, rings=6, loc=(x, -0.03, KNUCKLE_Z), scale=(1, 0.8, 0.8), smooth=False,
                     name="Knuckle")
    t = thumb or f
    I.box(0.03, 0.032, 0.045, t, loc=(-0.057, 0.006, 0.0), rot=(0, 22, 0), bevel=0.009, segments=1, smooth=False,
          name="Thumb")
    I.box(0.027, 0.03, 0.03, t, loc=(-0.046, 0.01, 0.035), rot=(0, 40, 0), bevel=0.008, segments=1, smooth=False,
          name="ThumbTip")


def cuff(material, top=-0.045, bottom=-0.22, r_top=0.048, r_bot=0.062, segs=16, flat=0.85):
    h = top - bottom
    I.cyl(r_bot, h, material, r2=r_top, segs=segs, loc=(0, 0, (top + bottom) / 2), scale=(1, flat, 1), bevel=0.0,
          smooth=False, name="Cuff")
    I.torus(r_bot * 0.99, 0.005, material, segs=segs, rsegs=4, loc=(0, 0, bottom + 0.003), scale=(1, flat, 1),
            name="CuffRim")


def band(z, material, r=0.05, t=0.008, segs=16, flat=0.85):
    I.torus(r, t, material, segs=segs, rsegs=4, loc=(0, 0, z), scale=(1, flat, 1), name="Band")


def plate(material, w=0.09, h=0.07, z=0.0, y=-0.04, t=0.012, rivets=None):
    """Armor plate on the back of the hand (optional corner rivets)."""
    I.box(w, t, h, material, loc=(0, y, z), bevel=t * 0.4, segments=2, smooth=False, name="Plate")
    if rivets is not None:
        for sx in (-1, 1):
            for sz in (-1, 1):
                P.rivet((sx * (w / 2 - 0.009), y - t / 2, z + sz * (h / 2 - 0.009)), 0.0045, rivets)


def gauntlet_points():
    point("Tip", (0, -0.035, KNUCKLE_Z + 0.012))
    point("Base", (0, 0, -0.05))


def plains():  # Leather Knuckles: leather wraps, iron knuckle bar with studs, laced leather cuff
    leather = pm("#6E4526", rough=0.75, var=0.2, grain=True)
    dark = pm("#3A2414", rough=0.8, var=0.15)
    iron = pm("#9AA2AA", metal=0.85, rough=0.4, var=0.1)
    fist(leather, fingers=pm("#4A2E1A", rough=0.8, var=0.15))
    I.box(0.108, 0.028, 0.03, iron, loc=(0, -0.032, KNUCKLE_Z + 0.004), bevel=0.007, segments=2, smooth=False,
          name="KnuckleBar")
    for x in FINGER_X:
        I.sphere(0.008, iron, segs=8, rings=5, loc=(x, -0.048, KNUCKLE_Z), smooth=False, name="Stud")
    for z in (-0.02, 0.02):
        I.torus(0.058, 0.007, dark, segs=16, rsegs=4, loc=(0, 0, z), scale=(1, 0.72, 1), name="Strap")
    cuff(leather)
    for z in (-0.07, -0.19):
        band(z, dark, r=0.052 + (-0.07 - z) * 0.07)
    for k in range(4):
        z = -0.09 - k * 0.026
        I.box(0.03, 0.006, 0.005, pm("#E0C9A0", rough=0.8), loc=(0, -0.05 - (-0.09 - z) * 0.05, z),
              rot=(0, 30 * (-1) ** k, 0), bevel=0.0, smooth=False, name="Lace")
    for z in (-0.09, -0.168):
        for s in (-1, 1):
            P.rivet((s * 0.018, -0.051 - (-0.09 - z) * 0.05, z), 0.004, iron)
    gauntlet_points()


def desert():  # Desert Wraps: sand cloth wraps, gold bracer, turquoise scarab on the back of the hand
    cloth = pm("#E3CFA3", rough=0.85, var=0.15, grain=True)
    cloth2 = pm("#C9AE7A", rough=0.85, var=0.15, grain=True)
    gold = pm("#E2B04A", metal=0.9, rough=0.3, var=0.08)
    fist(cloth, fingers=cloth2)
    for k, z in enumerate((-0.03, -0.005, 0.02, 0.045)):
        I.torus(0.057, 0.008, cloth2, segs=16, rsegs=4, loc=(0, 0, z), rot=(12 * (-1) ** k, 0, 0), scale=(1, 0.72, 1),
                name="Wrap")
    cuff(cloth, r_top=0.046, r_bot=0.056)
    for k in range(5):
        I.torus(0.054 - k * 0.002, 0.008, cloth2, segs=16, rsegs=4, loc=(0, 0, -0.07 - k * 0.022),
                rot=(10 * (-1) ** k, 0, 0), scale=(1, 0.85, 1), name="Wrap")
    I.cyl(0.062, 0.04, gold, segs=16, loc=(0, 0, -0.2), scale=(1, 0.85, 1), bevel=0.003, segments=1, smooth=False,
          name="Bracer")
    for z in (-0.183, -0.217):
        band(z, gold, r=0.062, t=0.004)
    P.socketed_gem(0.022, pm("#2EC4B6", rough=0.15, var=0.0), gold, (0, -0.05, -0.2))
    I.sphere(0.022, pm("#1FA59A", metal=0.3, rough=0.2, var=0.06), segs=12, rings=7, loc=(0, -0.042, 0.005),
             scale=(1, 0.5, 1.25), smooth=False, name="Scarab")
    I.box(0.004, 0.012, 0.05, gold, loc=(0, -0.052, 0.005), bevel=0.0, smooth=False, name="ScarabLine")
    for s in (-1, 1):
        for dz, ang in ((0.0, 30), (0.016, 10), (-0.016, 50)):
            I.box(0.03, 0.008, 0.006, gold, loc=(s * 0.024, -0.046, dz), rot=(0, s * ang, 0), bevel=0.0, smooth=False,
                  name="ScarabLeg")
    gauntlet_points()


def jungle():  # Jaguar Claws: rosette-spotted jaguar-fur glove with three curved claws, tooth cord on the cuff
    fur = pm("#C9802A", rough=0.8, var=0.2, scale=90)
    spot = pm("#3A2414", rough=0.8, var=0.1)
    claw = pm("#F0E6C8", rough=0.4, var=0.08)
    fist(fur, fingers=fur, knuckles=fur)

    def rosette(x, z, r, y):
        I.torus(r, r * 0.38, spot, segs=8, rsegs=3, loc=(x, y, z), rot=(90, 0, 0), scale=(1.15, 1, 1), name="Rosette")

    for x, z, r in ((-0.032, 0.024, 0.009), (0.024, -0.012, 0.008), (0.036, 0.03, 0.006), (-0.008, -0.026, 0.007)):
        rosette(x, z, r, -0.0385)
    for x, z, r in ((-0.022, -0.085, 0.009), (0.024, -0.115, 0.008), (-0.006, -0.15, 0.01), (0.03, -0.18, 0.007),
                    (-0.03, -0.195, 0.008)):
        rr = 0.048 + (-0.045 - z) / 0.175 * 0.014
        rosette(x, z, r, -math.sqrt(max(rr * rr - x * x, 0.0)) * 0.85 - 0.001)
    for x in (-0.025, 0.0, 0.025):
        P.tube([(x, -0.03, KNUCKLE_Z), (x, -0.04, KNUCKLE_Z + 0.025), (x, -0.045, KNUCKLE_Z + 0.05),
                (x, -0.042, KNUCKLE_Z + 0.075), (x, -0.035, KNUCKLE_Z + 0.1), (x, -0.012, KNUCKLE_Z + 0.13)],
               [0.009, 0.0085, 0.007, 0.0055, 0.004, 0.001], claw, segs=6, name="Claw")
    cuff(fur)
    band(-0.06, pm("#3C8F3A", rough=0.6, var=0.12), r=0.05)
    for k in range(5):
        a = math.radians(-50 + 25 * k)
        x, y = 0.06 * math.sin(a), -0.052 * math.cos(a)
        I.cyl(0.006, 0.03, claw, r2=0.0, segs=5, loc=(x, y, -0.085), rot=(180, 0, 0), bevel=0.0, smooth=False, name="Tooth")
    band(-0.068, pm("#6B3E22", rough=0.8, var=0.1), r=0.051, t=0.004)
    gauntlet_points()


def tundra():  # Frost Knuckles: steel plates, ice crystal knuckle spikes, thick fur cuff, glowing ice gem
    steel = pm("#C9D3DC", metal=0.8, rough=0.3, var=0.07)
    dark = pm("#4A5D73", metal=0.3, rough=0.55, var=0.1)
    ice = pm("#7CC8EE", rough=0.08, var=0.05)
    glow = pm("#8FE8FF", emit=2.0, emit_color="#7FE0FF")
    fist(dark, fingers=steel, knuckles=steel)
    plate(steel, w=0.092, h=0.07, z=0.0, y=-0.04, rivets=steel)
    P.gem(0.018, glow, (0, -0.05, 0.0), facets=8)
    for x in FINGER_X:
        P.crystal((x, -0.032, KNUCKLE_Z + 0.004), 0.009, 0.05, ice, tilt=(-25, 0, 0))
    cuff(steel, top=-0.05, bottom=-0.19, r_top=0.048, r_bot=0.058)
    I.torus(0.062, 0.022, pm("#EDEAE4", rough=0.95, var=0.15, scale=120), segs=16, rsegs=7, loc=(0, 0, -0.195),
            scale=(1, 0.85, 1), name="Fur")
    for s in (-1, 1):
        P.crystal((s * 0.05, 0, -0.1), 0.012, 0.06, ice, tilt=(0, s * 70, 0))
    gauntlet_points()


def swamp():  # Mud Fists: lumpy mud-crusted fist, moss, root bracer, toxic glowing blisters
    mud = pm("#4E3B28", rough=0.95, var=0.25, scale=50)
    moss = pm("#6E9A3A", rough=0.9, var=0.22, scale=60)
    root = pm("#2E2418", rough=0.85, var=0.15)
    toxic = pm("#7CFF4A", emit=2.5, emit_color="#6CFF30")
    fist(mud, fingers=mud, knuckles=mud, knuckle_r=0.017)
    for x, z, r in ((-0.03, 0.01, 0.03), (0.025, -0.02, 0.028), (0.035, 0.03, 0.022), (-0.01, 0.045, 0.024)):
        I.ico(r, mud, loc=(x, -0.032, z), scale=(1, 0.6, 1), name="MudLump")
    I.ico(0.03, moss, loc=(0.02, -0.04, 0.02), scale=(1.3, 0.4, 0.8), name="Moss")
    for x, z in ((-0.025, -0.01), (0.04, 0.0), (0.0, 0.055)):
        I.sphere(0.01, toxic, segs=8, rings=5, loc=(x, -0.05, z), scale=(1, 0.6, 1), smooth=False, name="Blister")
    cuff(mud, r_top=0.05, r_bot=0.06)
    for k in range(3):
        P.tube([(0.06 * math.cos(math.radians(a + 120 * k)), 0.05 * math.sin(math.radians(a + 120 * k)), -0.05 - a / 1800)
                for a in range(0, 361, 30)], 0.009, root, segs=6, name="Root")
    I.sphere(0.012, toxic, segs=8, rings=5, loc=(0.03, -0.055, -0.14), scale=(1, 0.6, 1.4), smooth=False, name="Blister")
    for x, z, r in ((-0.03, -0.1, 0.022), (0.02, -0.185, 0.024), (-0.015, -0.2, 0.018), (0.04, -0.08, 0.016)):
        I.ico(r, mud, loc=(x, -0.045, z), scale=(1, 0.55, 1.2), name="MudLump")
    I.ico(0.022, moss, loc=(-0.025, -0.05, -0.15), scale=(1.4, 0.4, 0.8), name="Moss")
    gauntlet_points()


def volcano():  # Magma Gauntlets: obsidian plates with lava cracks, rock knuckle spikes, molten wrist band
    black = pm("#3A2E30", metal=0.2, rough=0.6, var=0.14, scale=70)
    rock = pm("#4A3834", rough=0.85, var=0.25, scale=50)
    lava = pm("#FF6A1F", emit=3.0, emit_color="#FF5A10")
    fist(black, fingers=rock, knuckles=rock, knuckle_r=0.016)
    plate(black, w=0.096, h=0.074, z=0.0, y=-0.041)
    I.tube([(-0.044, -0.048, 0.03), (-0.025, -0.048, 0.012), (-0.03, -0.048, -0.008), (-0.008, -0.048, -0.02),
            (0.012, -0.048, 0.005), (0.03, -0.048, -0.01), (0.044, -0.048, 0.02)], 0.0045, lava, segs=5, name="Crack")
    I.tube([(-0.025, -0.048, 0.012), (-0.005, -0.048, 0.03)], [0.004, 0.0015], lava, segs=5, name="Crack")
    I.tube([(0.012, -0.048, 0.005), (0.02, -0.048, 0.032)], [0.004, 0.0015], lava, segs=5, name="Crack")
    I.tube([(-0.02, -0.052, -0.09), (-0.005, -0.054, -0.11), (-0.015, -0.056, -0.135), (0.01, -0.057, -0.16)],
           [0.005, 0.0045, 0.004, 0.002], lava, segs=5, name="CuffCrack")
    for x in FINGER_X:
        P.spike((x, -0.03, KNUCKLE_Z + 0.005), (x, -0.045, KNUCKLE_Z + 0.045), 0.011, rock, segs=6)
    cuff(black)
    I.cyl(0.058, 0.03, lava, segs=16, loc=(0, 0, -0.07), scale=(1, 0.85, 1), bevel=0.0, smooth=False, name="MoltenBand")
    for z in (-0.12, -0.17):
        band(z, rock, r=0.058, t=0.01)
    for s in (-1, 1):
        I.cyl(0.02, 0.05, rock, r2=0.0, segs=6, loc=(s * 0.065, 0, -0.14), rot=(0, s * 80, 0), bevel=0.0, smooth=False,
              name="Spike")
    gauntlet_points()


def hell():  # Demon Fists: dark red plates, curved horns on the knuckles, demon eye, spiked cuff
    metal = pm("#6A1A16", metal=0.7, rough=0.3, var=0.12, scale=80)
    black = pm("#1E1414", rough=0.6, var=0.1)
    edge = pm("#B23A2E", metal=0.7, rough=0.25, var=0.08)
    bone = pm("#E6D8C0", rough=0.5, var=0.1)
    fist(black, fingers=metal, knuckles=edge)
    plate(metal, w=0.094, h=0.072, z=0.0, y=-0.041, rivets=edge)
    P.socketed_gem(0.02, pm("#FF3030", emit=3.0, emit_color="#FF2020"), edge, (0, -0.052, 0.005))
    for x in (-0.03, 0.03):
        P.tube([(x, -0.03, KNUCKLE_Z), (x * 1.15, -0.042, KNUCKLE_Z + 0.02), (x * 1.3, -0.05, KNUCKLE_Z + 0.04),
                (x * 1.6, -0.047, KNUCKLE_Z + 0.06), (x * 1.9, -0.04, KNUCKLE_Z + 0.075), (x * 2.4, -0.02, KNUCKLE_Z + 0.09)],
               [0.014, 0.0125, 0.011, 0.0085, 0.006, 0.001], bone, segs=6, name="Horn")
    cuff(metal)
    for z in (-0.06, -0.2):
        band(z, edge, r=0.05 + (-0.06 - z) * 0.08, t=0.009)
    for k in range(5):
        a = math.radians(-60 + 30 * k)
        P.spike((0.055 * math.sin(a), -0.047 * math.cos(a), -0.13), (0.085 * math.sin(a), -0.075 * math.cos(a), -0.12),
                0.01, edge, segs=5)
    gauntlet_points()


def heaven():  # Angelic Gauntlets: white plate with gold trim, feathered wings on the cuff, glowing sun gem, halo
    white = pm("#FFFFFF", rough=0.4, var=0.05)
    gold = pm("#E8B84A", metal=0.9, rough=0.25, var=0.08)
    sun = pm("#FFE070", emit=2.5, emit_color="#FFD040")
    fist(white, fingers=white, knuckles=gold)
    plate(white, w=0.094, h=0.072, z=0.0, y=-0.041)
    I.torus(0.03, 0.006, gold, segs=16, rsegs=4, loc=(0, -0.048, 0.0), rot=(90, 0, 0), name="GemRing")
    for k in range(8):
        a = math.radians(45 * k)
        I.box(0.004, 0.006, 0.014, gold, loc=(0.042 * math.cos(a), -0.048, 0.042 * math.sin(a)),
              rot=(0, -math.degrees(a) + 90, 0), bevel=0.0, smooth=False, name="SunRay")
    P.gem(0.02, sun, (0, -0.052, 0.0), facets=10)
    cuff(white)
    for z in (-0.06, -0.21):
        band(z, gold, r=0.05 + (-0.06 - z) * 0.08, t=0.009)
    wing = [(0.0, 0.0), (0.03, -0.015), (0.055, -0.045), (0.065, -0.09), (0.045, -0.068), (0.04, -0.085), (0.025, -0.058),
            (0.012, -0.036)]
    for s in (-1, 1):
        pts = [(s * (0.05 + x), z - 0.075) for x, z in wing]
        P.plate(pts if s < 0 else list(reversed(pts)), 0.01, white, bevel=0.0045, name="Wing")
    I.torus(0.022, 0.004, sun, segs=16, rsegs=4, loc=(0, -0.05, -0.13), rot=(90, 0, 0), name="Halo")
    gauntlet_points()


def dead():  # Bone Knuckles: skeletal finger bones over a dark glove, skull, rib bracer, soul glow
    bone = pm("#E6DCC0", rough=0.55, var=0.1)
    dark = pm("#3A3440", rough=0.75, var=0.1)
    soul = pm("#7CFFB0", emit=2.5, emit_color="#60FF9A")
    fist(dark, fingers=dark, knuckles=bone, knuckle_r=0.015)
    for x in FINGER_X:
        I.cyl(0.006, 0.06, bone, segs=6, loc=(x, -0.04, 0.02), bevel=0.0, smooth=False, name="Metacarpal")
        I.sphere(0.008, bone, segs=6, rings=4, loc=(x, -0.04, -0.012), smooth=False, name="Carpal")
    I.sphere(0.026, bone, segs=12, rings=8, loc=(0, -0.04, -0.03), scale=(1, 0.6, 0.9), smooth=False, name="Skull")
    for x in (-0.009, 0.009):
        I.sphere(0.006, soul, segs=6, rings=4, loc=(x, -0.055, -0.028), smooth=False, name="Eye")
    cuff(dark)
    for k in range(4):
        z = -0.075 - k * 0.035
        I.torus(0.058 + k * 0.002, 0.007, bone, segs=14, rsegs=4, arc=200, start=-190, loc=(0, 0, z), scale=(1, 0.88, 1),
                name="Rib")
    I.box(0.012, 0.014, 0.15, bone, loc=(0, -0.056, -0.13), bevel=0.003, segments=1, smooth=False, name="Sternum")
    for z in (-0.09, -0.16):
        I.sphere(0.01, soul, segs=6, rings=4, loc=(0.03, -0.055, z), smooth=False, name="SoulOrb")
    gauntlet_points()


def abyss():  # Pearl Gauntlets: teal shell plates, ribbed scallop shell on the back, pearl knuckles, coral spikes
    teal = pm("#3FB5C8", metal=0.65, rough=0.22, var=0.1)
    dark = pm("#1F3F6A", metal=0.5, rough=0.4, var=0.1)
    pearl = pm("#F4F1EA", rough=0.12, var=0.04)
    coral = pm("#FF7FAB", rough=0.45, var=0.15)
    glow = pm("#5FFFF0", emit=2.5, emit_color="#40F0E0")
    fist(dark, fingers=teal, knuckles=pearl, knuckle_r=0.015)
    shell = [(0.0, -0.035)] + [(0.045 * math.cos(math.radians(a)), 0.045 * math.sin(math.radians(a)) + 0.005)
                               for a in range(0, 181, 15)]
    P.plate(shell, 0.012, teal, bevel=0.006, edge=0.35, loc=(0, -0.042, 0.0), name="Shell")
    for a in range(20, 180, 32):
        I.box(0.004, 0.016, 0.07, dark, loc=(0.024 * math.cos(math.radians(a)), -0.044, 0.024 * math.sin(math.radians(a)) - 0.008),
              rot=(0, 90 - a, 0), bevel=0.0, smooth=False, name="ShellRib")
    P.gem(0.014, glow, (0, -0.05, -0.022), facets=8)
    cuff(teal)
    band(-0.06, pearl, r=0.05, t=0.008)
    for k in range(6):
        a = math.radians(-75 + 30 * k)
        I.sphere(0.009, pearl, segs=8, rings=5, loc=(0.06 * math.sin(a), -0.052 * math.cos(a), -0.2), smooth=False,
                 name="Pearl")
    for s in (-1, 1):
        P.tube([(s * 0.055, 0, -0.12), (s * 0.075, 0, -0.112), (s * 0.085, 0, -0.1), (s * 0.095, 0, -0.065),
                (s * 0.115, 0, -0.05)], [0.01, 0.009, 0.008, 0.005, 0.002], coral, segs=6, name="Coral")
        P.tube([(s * 0.085, 0, -0.1), (s * 0.105, 0, -0.11)], [0.006, 0.002], coral, segs=6, name="Coral")
    gauntlet_points()


def mechanical():  # Power Gauntlets: robotic fist with pistons, glowing core, vents, battery cuff
    metal = pm("#9AA4B2", metal=0.85, rough=0.3, var=0.06)
    dark = pm("#3A3F48", metal=0.8, rough=0.35, var=0.08)
    yellow = pm("#FFC21F", rough=0.4, var=0.06)
    plasma = pm("#3FE6FF", emit=3.5, emit_color="#25D8FF")
    fist(dark, fingers=metal, knuckles=metal, knuckle_r=0.015)
    plate(metal, w=0.098, h=0.075, z=0.0, y=-0.041, rivets=dark)
    I.cyl(0.022, 0.014, plasma, segs=16, loc=(0, -0.05, 0.0), rot=(90, 0, 0), bevel=0.0, smooth=False, name="Core")
    I.torus(0.026, 0.005, dark, segs=16, rsegs=4, loc=(0, -0.05, 0.0), rot=(90, 0, 0), name="CoreRim")
    for x in FINGER_X:
        I.box(0.02, 0.012, 0.012, yellow, loc=(x, -0.04, KNUCKLE_Z + 0.004), bevel=0.002, segments=1, smooth=False,
              name="KnuckleCap")
    cuff(dark, r_top=0.05, r_bot=0.064)
    for s in (-1, 1):
        I.cyl(0.011, 0.11, metal, segs=10, loc=(s * 0.055, -0.03, -0.09), bevel=0.0, smooth=False, name="Piston")
        I.cyl(0.016, 0.04, dark, segs=10, loc=(s * 0.055, -0.03, -0.16), bevel=0.0, smooth=False, name="PistonBase")
        I.torus(0.0125, 0.003, metal, segs=10, rsegs=3, loc=(s * 0.055, -0.03, -0.14), name="PistonSeal")
    for z in (-0.08, -0.105, -0.13):
        I.box(0.05, 0.008, 0.008, dark, loc=(0, -0.055, z), bevel=0.0, smooth=False, name="Vent")
    I.box(0.04, 0.03, 0.05, yellow, loc=(0, -0.05, -0.18), bevel=0.005, segments=2, smooth=False, name="Battery")
    I.box(0.03, 0.006, 0.034, plasma, loc=(0, -0.066, -0.18), bevel=0.0, smooth=False, name="Charge")
    band(-0.215, metal, r=0.064, t=0.009)
    gauntlet_points()


def void():  # Singularity Gauntlets: dark crystal plates, a black-hole sphere with an orbit ring, floating shards
    dark = pm("#3A2C55", metal=0.35, rough=0.15, var=0.1)
    obs = pm("#2A1E3D", metal=0.3, rough=0.2, var=0.08)
    glow = pm("#B05BFF", emit=3.0, emit_color="#9B3BFF")
    black = pm("#0E0A16", metal=0.2, rough=0.1, var=0.03)
    fist(obs, fingers=dark, knuckles=dark)
    for x in FINGER_X:
        P.crystal((x, -0.03, KNUCKLE_Z + 0.004), 0.01, 0.045, dark, tilt=(-20, 0, 0))
    plate(dark, w=0.094, h=0.072, z=0.0, y=-0.041)
    I.sphere(0.03, black, segs=16, rings=9, loc=(0, -0.06, 0.0), name="Singularity")
    I.torus(0.045, 0.005, glow, segs=24, rsegs=4, loc=(0, -0.06, 0.0), rot=(65, 0, 25), name="Orbit")
    I.torus(0.033, 0.004, glow, segs=20, rsegs=4, loc=(0, -0.06, 0.0), rot=(90, 0, 0), name="Horizon")
    cuff(obs)
    for z in (-0.07, -0.15):
        band(z, glow, r=0.051 + (-0.045 - z) * 0.08, t=0.006)
    for s in (-1, 1):
        P.crystal((s * 0.055, 0, -0.12), 0.016, 0.08, dark, tilt=(0, s * 75, 0))
        P.crystal((s * 0.09, -0.02, -0.03), 0.009, 0.04, glow, tilt=(0, s * 30, 0))
    P.crystal((0.0, -0.05, -0.2), 0.012, 0.05, glow, tilt=(180, 0, 0))
    gauntlet_points()


BUILDERS = [plains, desert, jungle, tundra, swamp, volcano, hell, heaven, dead, abyss, mechanical, void]
