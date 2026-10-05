"""Animation clips of the creature rig families (docs/enemies_npcs_pets_brief.txt Part E).

One clip set per rig family, written ONCE here and used twice:
  - fyd_creatures.py bakes them as keyframes on the segmented rigs of every .blend (timeline markers = clips);
  - tools/blender/gen_rig_clips.py writes the same data to src/ReplicatedStorage/GameSystem/Config/RigClips.luau,
    which the game plays on the Motor6D joints (client AnimPlayer), on the imported models and on the placeholders.

Space: ROBLOX joint space of the model facing -Z (x right, y up, z back). For a joint:
  "r" = rotation (radians) applied as CFrame.Angles(x, y, z) after the rest pose,
  "p" = offset in studs at the family reference size (REF_SIZE; the game scales it by size / REF_SIZE).
Signs: +x rotation pitches a body BACK (nose up) and swings a hanging leg / arm FORWARD; +z rotation on a right
arm lifts it sideways; a leg on the left (-x) side lifts with -z.
A clip: {"length": s, "loop": bool, "impact": s (attacks: when the hit lands), "tracks": {joint: {"r": keys, "p": keys}}}
keys = [(time, (x, y, z)), ...] sorted by time; the game interpolates smoothly between keys.
"""
import math

TAU = math.pi * 2

# family -> reference size in studs (height, or length for Serpent) the "p" offsets are written for
REF_SIZE = {
    "Quadruped": 3, "Biped": 5.5, "BossBiped": 17, "Bird": 3, "Serpent": 6, "Arachnid": 4.5, "Crustacean": 4,
    "Insect": 4, "Fish": 2.5, "Amphibian": 3.5, "Golem": 8, "Snowman": 5, "Floater": 4, "Gorilla": 18,
}


def wave(length, amp, axis=0, phase=0.0, cycles=1, steps=8, offset=(0.0, 0.0, 0.0), kind=math.sin):
    """Keys of offset + amp * kind(2 pi (cycles t / length) + phase) on one axis, sampled steps times per cycle."""
    keys = []
    n = steps * cycles
    for i in range(n + 1):
        t = length * i / n
        v = list(offset)
        v[axis] += amp * kind(TAU * cycles * t / length + phase)
        keys.append((round(t, 4), tuple(round(c, 4) for c in v)))
    return keys


def keys(*pairs):
    """keys((t, x, y, z), ...) shorthand."""
    return [(t, (x, y, z)) for (t, x, y, z) in pairs]


def merge(*tracks):
    out = {}
    for t in tracks:
        for joint, channels in t.items():
            out.setdefault(joint, {}).update(channels)
    return out


def clip(length, loop, tracks, impact=None):
    c = {"length": length, "loop": loop, "tracks": tracks}
    if impact is not None:
        c["impact"] = impact
    return c


# ------------------------------------------------------------------------------------------------
# shared builders
# ------------------------------------------------------------------------------------------------
def legs4(length, amp, lift=0.0):
    """Four legs, diagonal pairs (FL + BR, FR + BL)."""
    return {
        "LegFL": {"r": wave(length, amp, 0)},
        "LegBR": {"r": wave(length, amp, 0)},
        "LegFR": {"r": wave(length, -amp, 0)},
        "LegBL": {"r": wave(length, -amp, 0)},
    }


def many_legs(length, pairs, amp=0.35, lift=0.3, steps=8):
    """Spider / crab / insect legs LegL1.. LegR1..: alternating sweep about Y, lifted while swinging forward."""
    out = {}
    for i in range(1, pairs + 1):
        for side, sign in (("L", 1), ("R", -1)):
            phase = 0.0 if (i % 2 == 1) == (side == "L") else math.pi
            ks = []
            for k in range(steps + 1):
                t = length * k / steps
                a = TAU * t / length + phase
                up = max(0.0, math.cos(a)) * lift
                ks.append((round(t, 4), (0.0, round(amp * sign * math.sin(a), 4), round(-up if side == "L" else up, 4))))
            out[f"Leg{side}{i}"] = {"r": ks}
    return out


def curl_legs(pairs, amount=0.9):
    out = {}
    for i in range(1, pairs + 1):
        out[f"LegL{i}"] = {"r": keys((0, 0, 0, 0), (0.5, 0, 0, -amount), (1.0, 0, 0, -amount))}
        out[f"LegR{i}"] = {"r": keys((0, 0, 0, 0), (0.5, 0, 0, amount), (1.0, 0, 0, amount))}
    return out


def hit(joint, pitch=0.2, push=0.25, extra=None):
    t = {joint: {"r": keys((0, 0, 0, 0), (0.08, pitch, 0, 0), (0.3, 0, 0, 0)),
                 "p": keys((0, 0, 0, 0), (0.08, 0, 0, push), (0.3, 0, 0, 0))}}
    return merge(t, extra or {})


def spawn(joint, depth):
    return {joint: {"p": keys((0, 0, -depth, 0), (0.35, 0, depth * 0.12, 0), (0.5, 0, 0, 0))}}


# ------------------------------------------------------------------------------------------------
# families
# ------------------------------------------------------------------------------------------------
def quadruped():
    return {
        "Idle": clip(2.0, True, merge(
            {"Body": {"p": wave(2.0, 0.04, 1, phase=-math.pi / 2, offset=(0, 0.02, 0), steps=6)}},
            {"Head": {"r": keys((0, 0, 0, 0), (0.7, 0.08, 0.16, 0), (1.4, 0.03, -0.12, 0), (2.0, 0, 0, 0))}},
            {"Tail": {"r": wave(2.0, 0.35, 1, cycles=2, steps=6)}},
        )),
        "Walk": clip(0.8, True, merge(
            legs4(0.8, 0.45),
            {"Body": {"p": wave(0.8, 0.07, 1, cycles=2, offset=(0, 0.04, 0), steps=4),
                      "r": wave(0.8, 0.03, 2)}},
            {"Head": {"r": wave(0.8, 0.05, 0, cycles=2, steps=4)}},
            {"Tail": {"r": wave(0.8, 0.3, 1)}},
        )),
        "Run": clip(0.5, True, merge(
            legs4(0.5, 0.75),
            {"Body": {"p": wave(0.5, 0.12, 1, cycles=2, offset=(0, 0.08, 0), steps=4),
                      "r": wave(0.5, 0.08, 0)}},
            {"Head": {"r": wave(0.5, 0.08, 0, phase=math.pi)}},
            {"Tail": {"r": keys((0, 0.5, 0, 0), (0.5, 0.5, 0, 0))}},
        )),
        "Attack1": clip(0.8, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.4, 0.22, 0, 0), (0.5, -0.18, 0, 0), (0.8, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.4, 0, 0.1, 0.35), (0.5, 0, 0, -0.9), (0.8, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.4, -0.35, 0, 0), (0.55, 0.45, 0, 0), (0.8, 0, 0, 0))},
            "LegFL": {"r": keys((0, 0, 0, 0), (0.4, -0.4, 0, 0), (0.5, 0.45, 0, 0), (0.8, 0, 0, 0))},
            "LegFR": {"r": keys((0, 0, 0, 0), (0.4, -0.4, 0, 0), (0.5, 0.45, 0, 0), (0.8, 0, 0, 0))},
            "LegBL": {"r": keys((0, 0, 0, 0), (0.4, 0.3, 0, 0), (0.5, -0.4, 0, 0), (0.8, 0, 0, 0))},
            "LegBR": {"r": keys((0, 0, 0, 0), (0.4, 0.3, 0, 0), (0.5, -0.4, 0, 0), (0.8, 0, 0, 0))},
        }, impact=0.5),
        "Hit": clip(0.3, False, hit("Body", extra={"Head": {"r": keys((0, 0, 0, 0), (0.08, 0.25, 0, 0), (0.3, 0, 0, 0))}})),
        "Death": clip(1.0, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.6, 0, 0, 1.45), (1.0, 0, 0, 1.5)),
                     "p": keys((0, 0, 0, 0), (0.6, 0, -0.7, 0), (1.0, 0, -0.8, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.7, 0.35, 0, 0), (1.0, 0.35, 0, 0))},
            "LegFL": {"r": keys((0, 0, 0, 0), (0.6, -0.35, 0, 0))}, "LegFR": {"r": keys((0, 0, 0, 0), (0.6, -0.3, 0, 0))},
            "LegBL": {"r": keys((0, 0, 0, 0), (0.6, 0.35, 0, 0))}, "LegBR": {"r": keys((0, 0, 0, 0), (0.6, 0.3, 0, 0))},
        }),
        "Spawn": clip(0.5, False, spawn("Body", 1.2)),
        "Attack2": clip(1.2, False, {  # mini-boss pounce
            "Body": {"r": keys((0, 0, 0, 0), (0.7, 0.35, 0, 0), (0.9, -0.25, 0, 0), (1.2, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.7, 0, -0.3, 0.6), (0.85, 0, 1.2, -1.5), (0.95, 0, 0, -2.0), (1.2, 0, 0, 0))},
            "LegFL": {"r": keys((0, 0, 0, 0), (0.7, -0.5, 0, 0), (0.85, 1.0, 0, 0), (1.2, 0, 0, 0))},
            "LegFR": {"r": keys((0, 0, 0, 0), (0.7, -0.5, 0, 0), (0.85, 1.0, 0, 0), (1.2, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.7, -0.3, 0, 0), (0.9, 0.3, 0, 0), (1.2, 0, 0, 0))},
        }, impact=0.9),
        "Roar": clip(1.4, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.4, 0.35, 0, 0), (1.1, 0.35, 0, 0), (1.4, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.4, 0, 0.3, 0.2), (1.1, 0, 0.3, 0.2), (1.4, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.4, 0.5, 0, 0), (0.6, 0.45, 0.1, 0), (0.8, 0.5, -0.1, 0), (1.1, 0.5, 0, 0), (1.4, 0, 0, 0))},
            "LegFL": {"r": keys((0, 0, 0, 0), (0.4, 0.5, 0, 0), (1.1, 0.5, 0, 0), (1.4, 0, 0, 0))},
            "LegFR": {"r": keys((0, 0, 0, 0), (0.4, 0.4, 0, 0), (1.1, 0.4, 0, 0), (1.4, 0, 0, 0))},
        }),
    }


def biped():
    return {
        "Idle": clip(2.4, True, merge(
            {"Torso": {"p": wave(2.4, 0.05, 1, phase=-math.pi / 2, offset=(0, 0.03, 0), steps=6)}},
            {"Head": {"r": keys((0, 0, 0, 0), (0.8, 0.04, 0.2, 0), (1.6, 0.0, -0.15, 0), (2.4, 0, 0, 0))}},
            {"ArmL": {"r": wave(2.4, 0.05, 2, offset=(0, 0, -0.06), steps=6)}},
            {"ArmR": {"r": wave(2.4, -0.05, 2, offset=(0, 0, 0.06), steps=6)}},
        )),
        "Walk": clip(0.9, True, merge(
            {"LegL": {"r": wave(0.9, 0.6, 0)}, "LegR": {"r": wave(0.9, -0.6, 0)}},
            {"ArmL": {"r": wave(0.9, -0.45, 0)}, "ArmR": {"r": wave(0.9, 0.45, 0)}},
            {"Torso": {"p": wave(0.9, 0.08, 1, cycles=2, offset=(0, 0.04, 0), steps=4), "r": wave(0.9, 0.06, 1)}},
        )),
        "Run": clip(0.6, True, merge(
            {"LegL": {"r": wave(0.6, 0.9, 0)}, "LegR": {"r": wave(0.6, -0.9, 0)}},
            {"ArmL": {"r": wave(0.6, -0.7, 0, offset=(0.2, 0, 0))}, "ArmR": {"r": wave(0.6, 0.7, 0, offset=(0.2, 0, 0))}},
            {"Torso": {"p": wave(0.6, 0.12, 1, cycles=2, offset=(0, 0.06, 0), steps=4),
                       "r": keys((0, -0.15, 0, 0), (0.6, -0.15, 0, 0))}},
        )),
        "Attack1": clip(0.8, False, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.4, 2.5, 0, 0.2), (0.55, -0.4, 0, 0.1), (0.8, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.4, 0.4, 0, -0.3), (0.55, -0.2, 0, -0.1), (0.8, 0, 0, 0))},
            "Torso": {"r": keys((0, 0, 0, 0), (0.4, 0.15, -0.3, 0), (0.55, -0.2, 0.25, 0), (0.8, 0, 0, 0)),
                      "p": keys((0, 0, 0, 0), (0.55, 0, -0.15, -0.3), (0.8, 0, 0, 0))},
            "LegL": {"r": keys((0, 0, 0, 0), (0.45, 0.35, 0, 0), (0.8, 0, 0, 0))},
            "LegR": {"r": keys((0, 0, 0, 0), (0.45, -0.25, 0, 0), (0.8, 0, 0, 0))},
        }, impact=0.5),
        "Shoot": clip(0.8, False, {  # ranged bipeds (archers, shaman): aim, draw, release at the impact
            "ArmL": {"r": keys((0, 0, 0, 0), (0.3, 1.5, 0, 0), (0.6, 1.5, 0, 0), (0.8, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.3, 1.4, 0.0, -0.3), (0.45, 1.3, 0.5, -0.2), (0.5, 1.5, 0, 0), (0.8, 0, 0, 0))},
            "Torso": {"r": keys((0, 0, 0, 0), (0.3, 0, 0.35, 0), (0.5, 0.05, 0.35, 0), (0.8, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.3, 0, -0.3, 0), (0.6, 0, -0.3, 0), (0.8, 0, 0, 0))},
        }, impact=0.5),
        "Hit": clip(0.3, False, hit("Torso", extra={"Head": {"r": keys((0, 0, 0, 0), (0.08, 0.25, 0, 0), (0.3, 0, 0, 0))}})),
        "Death": clip(1.2, False, {
            "Torso": {"r": keys((0, 0, 0, 0), (0.8, 1.45, 0, 0), (1.2, 1.5, 0, 0)),
                      "p": keys((0, 0, 0, 0), (0.8, 0, -1.7, 0.9), (1.2, 0, -1.8, 1.0))},
            "LegL": {"r": keys((0, 0, 0, 0), (0.8, -1.2, 0, 0))}, "LegR": {"r": keys((0, 0, 0, 0), (0.8, -1.0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.6, 0.6, 0, -0.9))}, "ArmR": {"r": keys((0, 0, 0, 0), (0.6, 0.5, 0, 0.9))},
            "Head": {"r": keys((0, 0, 0, 0), (0.8, 0.3, 0.2, 0))},
        }),
        "Spawn": clip(0.5, False, spawn("Torso", 2.0)),
        "Attack2": clip(1.2, False, {  # mini-boss heavy: two-handed overhead slam
            "ArmL": {"r": keys((0, 0, 0, 0), (0.7, 2.8, 0, 0.2), (0.85, -0.3, 0, 0.1), (1.2, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.7, 2.8, 0, -0.2), (0.85, -0.3, 0, -0.1), (1.2, 0, 0, 0))},
            "Torso": {"r": keys((0, 0, 0, 0), (0.7, 0.25, 0, 0), (0.85, -0.45, 0, 0), (1.2, 0, 0, 0)),
                      "p": keys((0, 0, 0, 0), (0.85, 0, -0.45, -0.4), (1.2, 0, 0, 0))},
            "LegL": {"r": keys((0, 0, 0, 0), (0.85, 0.5, 0, 0), (1.2, 0, 0, 0))},
            "LegR": {"r": keys((0, 0, 0, 0), (0.85, -0.4, 0, 0), (1.2, 0, 0, 0))},
        }, impact=0.85),
        "Roar": clip(1.6, False, {
            "Torso": {"r": keys((0, 0, 0, 0), (0.4, 0.28, 0, 0), (1.3, 0.28, 0, 0), (1.6, 0, 0, 0)),
                      "p": keys((0, 0, 0, 0), (0.5, 0.05, 0, 0), (0.6, -0.05, 0, 0), (0.7, 0.05, 0, 0), (0.8, -0.05, 0, 0), (1.6, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.4, 0.5, 0, -1.1), (1.3, 0.5, 0, -1.1), (1.6, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.4, 0.5, 0, 1.1), (1.3, 0.5, 0, 1.1), (1.6, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.4, 0.45, 0, 0), (1.3, 0.45, 0, 0), (1.6, 0, 0, 0))},
        }),
        # hub NPCs
        "Wave": clip(1.6, True, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.3, 0.2, 0, 2.5), (0.55, 0.2, 0.3, 2.8), (0.8, 0.2, -0.2, 2.4),
                               (1.05, 0.2, 0.3, 2.8), (1.3, 0.2, 0, 2.5), (1.6, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.3, 0.05, 0, 0.12), (1.3, 0.05, 0, 0.12), (1.6, 0, 0, 0))},
            "Torso": {"r": keys((0, 0, 0, 0), (0.3, 0, 0, -0.05), (1.3, 0, 0, -0.05), (1.6, 0, 0, 0))},
        }),
        "Talk": clip(2.0, True, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.4, 0.7, 0, 0.15), (0.8, 0.95, -0.2, 0.2), (1.2, 0.6, 0, 0.1), (1.6, 0.85, 0.1, 0.2), (2.0, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.6, 0.3, 0, -0.1), (1.4, 0.45, 0, -0.15), (2.0, 0, 0, 0))},
            "Head": {"r": wave(2.0, 0.07, 0, cycles=3, steps=4)},
            "Torso": {"r": wave(2.0, 0.05, 1, steps=6)},
        }),
    }


def boss_biped():
    clips = biped()
    clips["Intro"] = dict(clips["Roar"], length=2.0)
    clips["Enrage"] = clips["Roar"]
    clips["Attack1"] = dict(clips["Attack2"], impact=0.85)  # bosses swing their big weapon with both hands
    return clips


def bird():
    flap_l = lambda length, amp: wave(length, amp, 2, offset=(0, 0, -0.1))
    flap_r = lambda length, amp: wave(length, -amp, 2, offset=(0, 0, 0.1))
    return {
        "Idle": clip(0.6, True, merge(
            {"WingL": {"r": flap_l(0.6, 0.6)}, "WingR": {"r": flap_r(0.6, 0.6)}},
            {"Body": {"p": wave(0.6, 0.15, 1, phase=math.pi)}},
            {"Tail": {"r": wave(0.6, 0.08, 0)}},
            {"Head": {"r": keys((0, 0, 0, 0), (0.3, 0.05, 0.1, 0), (0.6, 0, 0, 0))}},
        )),
        "Walk": clip(0.45, True, merge(
            {"WingL": {"r": flap_l(0.45, 0.8)}, "WingR": {"r": flap_r(0.45, 0.8)}},
            {"Body": {"p": wave(0.45, 0.2, 1, phase=math.pi), "r": keys((0, -0.15, 0, 0), (0.45, -0.15, 0, 0))}},
        )),
        "Attack1": clip(0.7, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.3, 0.3, 0, 0), (0.45, -0.5, 0, 0), (0.7, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.3, 0, 0.4, 0.4), (0.45, 0, -0.6, -1.0), (0.7, 0, 0, 0))},
            "WingL": {"r": keys((0, 0, 0, -0.1), (0.3, 0, 0, 0.7), (0.45, 0, 0.4, -0.3), (0.7, 0, 0, -0.1))},
            "WingR": {"r": keys((0, 0, 0, 0.1), (0.3, 0, 0, -0.7), (0.45, 0, -0.4, 0.3), (0.7, 0, 0, 0.1))},
            "Head": {"r": keys((0, 0, 0, 0), (0.3, 0.3, 0, 0), (0.45, -0.4, 0, 0), (0.7, 0, 0, 0))},
        }, impact=0.45),
        "Shoot": clip(0.7, False, {  # bat spit
            "Head": {"r": keys((0, 0, 0, 0), (0.3, 0.35, 0, 0), (0.45, -0.3, 0, 0), (0.7, 0, 0, 0))},
            "Body": {"p": keys((0, 0, 0, 0), (0.3, 0, 0, 0.3), (0.45, 0, 0, -0.2), (0.7, 0, 0, 0))},
            "WingL": {"r": flap_l(0.7, 0.7)}, "WingR": {"r": flap_r(0.7, 0.7)},
        }, impact=0.45),
        "Hit": clip(0.3, False, hit("Body", pitch=0.3, push=0.3)),
        "Death": clip(1.0, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.6, 0.4, 0, 1.2), (1.0, 0.4, 0, 1.4)),
                     "p": keys((0, 0, 0, 0), (0.8, 0, -3.5, 0), (1.0, 0, -3.6, 0))},
            "WingL": {"r": keys((0, 0, 0, 0), (0.5, 0, 0, 0.8))}, "WingR": {"r": keys((0, 0, 0, 0), (0.5, 0, 0, -0.3))},
        }),
        "Spawn": clip(0.5, False, merge(spawn("Body", 1.5), {"WingL": {"r": flap_l(0.5, 0.7)}, "WingR": {"r": flap_r(0.5, 0.7)}})),
    }


def serpent():
    def slither(length, amp, steps=8):
        out = {}
        for i in range(2, 7):
            out[f"Seg{i}"] = {"r": wave(length, amp, 1, phase=-i * 0.9, steps=steps)}
        out["Seg1"] = {"r": wave(length, amp * 0.5, 1, phase=-0.9, steps=steps)}
        out["Head"] = {"r": wave(length, -amp * 0.4, 1, steps=steps)}
        return out
    return {
        "Idle": clip(2.0, True, merge(slither(2.0, 0.12, steps=6),
                                      {"Head": {"r": keys((0, 0, 0, 0), (0.6, 0.12, 0.1, 0), (1.3, 0.05, -0.1, 0), (2.0, 0, 0, 0))}})),
        "Walk": clip(0.8, True, slither(0.8, 0.4)),
        "Attack1": clip(0.6, False, {
            "Seg1": {"r": keys((0, 0, 0, 0), (0.3, 0.55, 0, 0), (0.4, -0.25, 0, 0), (0.6, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.3, 0, 0.6, 0.3), (0.4, 0, 0.1, -1.3), (0.6, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.3, -0.45, 0, 0), (0.4, 0.2, 0, 0), (0.6, 0, 0, 0))},
            "Seg2": {"r": keys((0, 0, 0, 0), (0.3, -0.3, 0, 0), (0.4, 0.1, 0, 0), (0.6, 0, 0, 0))},
        }, impact=0.4),
        "Hit": clip(0.3, False, hit("Seg1", pitch=0.3, push=0.3)),
        "Death": clip(1.0, False, merge(
            {"Seg1": {"r": keys((0, 0, 0, 0), (0.6, 0, 0, 1.4), (1.0, 0, 0, 1.5))}},
            {f"Seg{i}": {"r": keys((0, 0, 0, 0), (0.7, 0, 0.3 * (-1) ** i, 0))} for i in range(2, 7)},
            {"Head": {"r": keys((0, 0, 0, 0), (0.7, 0.3, 0, 0))}},
        )),
        "Spawn": clip(0.5, False, spawn("Seg1", 1.0)),
    }


def arachnid():
    return {
        "Idle": clip(1.6, True, merge(
            {"Abdomen": {"r": wave(1.6, 0.05, 0, steps=6)}},
            {"Body": {"p": wave(1.6, 0.03, 1, steps=6)}},
            {"Tail": {"r": wave(1.6, 0.1, 0, steps=6)}},
        )),
        "Walk": clip(0.6, True, merge(many_legs(0.6, 4, 0.35, 0.35), {"Body": {"p": wave(0.6, 0.05, 1, cycles=2, steps=4)}})),
        "Attack1": clip(0.7, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.35, 0.4, 0, 0), (0.45, -0.15, 0, 0), (0.7, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.35, 0, 0.3, 0.2), (0.45, 0, 0, -0.6), (0.7, 0, 0, 0))},
            "LegL1": {"r": keys((0, 0, 0, 0), (0.35, 0, 0.3, -0.8), (0.45, 0, -0.2, 0.2), (0.7, 0, 0, 0))},
            "LegR1": {"r": keys((0, 0, 0, 0), (0.35, 0, -0.3, 0.8), (0.45, 0, 0.2, -0.2), (0.7, 0, 0, 0))},
            "Tail": {"r": keys((0, 0, 0, 0), (0.35, 0.35, 0, 0), (0.45, -0.9, 0, 0), (0.7, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.35, 0, 0.4, 0), (0.45, 0, -0.2, 0), (0.7, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.35, 0, -0.4, 0), (0.45, 0, 0.2, 0), (0.7, 0, 0, 0))},
        }, impact=0.45),
        "Hit": clip(0.3, False, hit("Body", pitch=0.2, push=0.25)),
        "Death": clip(1.0, False, merge(curl_legs(4), {
            "Body": {"r": keys((0, 0, 0, 0), (0.5, 0, 0, 2.8), (1.0, 0, 0, 3.1)), "p": keys((0, 0, 0, 0), (0.5, 0, 0.6, 0), (1.0, 0, 0.3, 0))}})),
        "Spawn": clip(0.5, False, spawn("Body", 1.2)),
        "Attack2": clip(1.2, False, {  # mini-boss: rear up and slam both front legs
            "Body": {"r": keys((0, 0, 0, 0), (0.7, 0.7, 0, 0), (0.9, -0.25, 0, 0), (1.2, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.7, 0, 0.8, 0.3), (0.9, 0, -0.2, -0.6), (1.2, 0, 0, 0))},
            "LegL1": {"r": keys((0, 0, 0, 0), (0.7, 0, 0.4, -1.0), (0.9, 0, 0, 0.3), (1.2, 0, 0, 0))},
            "LegR1": {"r": keys((0, 0, 0, 0), (0.7, 0, -0.4, 1.0), (0.9, 0, 0, -0.3), (1.2, 0, 0, 0))},
            "LegL2": {"r": keys((0, 0, 0, 0), (0.7, 0, 0.2, -0.6), (0.9, 0, 0, 0.2), (1.2, 0, 0, 0))},
            "LegR2": {"r": keys((0, 0, 0, 0), (0.7, 0, -0.2, 0.6), (0.9, 0, 0, -0.2), (1.2, 0, 0, 0))},
        }, impact=0.9),
        "Roar": clip(1.4, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.4, 0.5, 0, 0), (1.1, 0.5, 0, 0), (1.4, 0, 0, 0))},
            "LegL1": {"r": keys((0, 0, 0, 0), (0.4, 0, 0.3, -0.9), (0.6, 0, 0.5, -0.7), (0.8, 0, 0.3, -0.9), (1.4, 0, 0, 0))},
            "LegR1": {"r": keys((0, 0, 0, 0), (0.4, 0, -0.3, 0.9), (0.6, 0, -0.5, 0.7), (0.8, 0, -0.3, 0.9), (1.4, 0, 0, 0))},
        }),
    }


def crustacean():
    return {
        "Idle": clip(1.6, True, merge(
            {"ArmL": {"r": wave(1.6, 0.1, 0, steps=6)}, "ArmR": {"r": wave(1.6, -0.1, 0, steps=6)}},
            {"Body": {"p": wave(1.6, 0.04, 1, steps=6)}},
        )),
        "Walk": clip(0.5, True, merge(many_legs(0.5, 3, 0.3, 0.35), {"Body": {"r": wave(0.5, 0.06, 2)}})),
        "Attack1": clip(0.6, False, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.3, 0.9, 0, 0), (0.4, -0.4, 0, 0), (0.6, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.33, 0.7, 0, 0), (0.45, -0.3, 0, 0), (0.6, 0, 0, 0))},
            "Body": {"p": keys((0, 0, 0, 0), (0.3, 0, 0.1, 0.2), (0.4, 0, 0, -0.5), (0.6, 0, 0, 0))},
        }, impact=0.4),
        "Hit": clip(0.3, False, hit("Body", pitch=0.15, push=0.25)),
        "Death": clip(1.0, False, merge(curl_legs(3), {
            "Body": {"r": keys((0, 0, 0, 0), (0.5, 0, 0, 2.8), (1.0, 0, 0, 3.1)), "p": keys((0, 0, 0, 0), (0.5, 0, 0.5, 0), (1.0, 0, 0.2, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.5, 0.6, 0, 0))}, "ArmR": {"r": keys((0, 0, 0, 0), (0.5, 0.6, 0, 0))}})),
        "Spawn": clip(0.5, False, spawn("Body", 1.0)),
    }


def insect():
    return {
        "Idle": clip(1.6, True, {"Head": {"r": wave(1.6, 0.08, 1, steps=6)}, "Body": {"p": wave(1.6, 0.03, 1, steps=6)}}),
        "Walk": clip(0.5, True, merge(many_legs(0.5, 3, 0.3, 0.3), {"Body": {"p": wave(0.5, 0.04, 1, cycles=2, steps=4)}})),
        "Attack1": clip(0.7, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.35, 0.2, 0, 0), (0.45, -0.2, 0, 0), (0.7, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.35, 0, 0, 0.4), (0.45, 0, 0, -0.9), (0.7, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.35, 0.4, 0, 0), (0.45, -0.3, 0, 0), (0.7, 0, 0, 0))},
        }, impact=0.45),
        "Hit": clip(0.3, False, hit("Body", pitch=0.15, push=0.25)),
        "Death": clip(1.0, False, merge(curl_legs(3), {
            "Body": {"r": keys((0, 0, 0, 0), (0.5, 0, 0, 2.8), (1.0, 0, 0, 3.1)), "p": keys((0, 0, 0, 0), (0.5, 0, 0.6, 0), (1.0, 0, 0.3, 0))}})),
        "Spawn": clip(0.5, False, spawn("Body", 1.0)),
    }


def fish():
    return {
        "Idle": clip(1.2, True, {
            "Tail": {"r": wave(1.2, 0.35, 1)}, "FinL": {"r": wave(1.2, 0.3, 2, steps=6)}, "FinR": {"r": wave(1.2, -0.3, 2, steps=6)},
            "Body": {"p": wave(1.2, 0.1, 1, phase=math.pi / 2), "r": wave(1.2, -0.06, 1)},
        }),
        "Walk": clip(0.6, True, {"Tail": {"r": wave(0.6, 0.6, 1)}, "Body": {"r": wave(0.6, -0.12, 1)},
                                 "FinL": {"r": wave(0.6, 0.35, 2)}, "FinR": {"r": wave(0.6, -0.35, 2)}}),
        "Attack1": clip(0.6, False, {
            "Body": {"p": keys((0, 0, 0, 0), (0.3, 0, 0, 0.5), (0.4, 0, 0, -1.4), (0.6, 0, 0, 0)),
                     "r": keys((0, 0, 0, 0), (0.3, 0.15, 0, 0), (0.4, -0.1, 0, 0), (0.6, 0, 0, 0))},
            "Jaw": {"r": keys((0, 0, 0, 0), (0.3, 0.6, 0, 0), (0.42, 0, 0, 0), (0.6, 0, 0, 0))},
            "Tail": {"r": keys((0, 0, 0, 0), (0.3, 0, 0.6, 0), (0.4, 0, -0.6, 0), (0.6, 0, 0, 0))},
        }, impact=0.4),
        "Hit": clip(0.3, False, hit("Body", pitch=0.2, push=0.3)),
        "Death": clip(1.0, False, {"Body": {"r": keys((0, 0, 0, 0), (0.6, 0, 0, 3.0), (1.0, 0, 0, 3.1)),
                                            "p": keys((0, 0, 0, 0), (1.0, 0, -1.2, 0))},
                                   "Tail": {"r": keys((0, 0, 0, 0), (0.3, 0, 0.5, 0), (0.6, 0, -0.3, 0), (1.0, 0, 0, 0))}}),
        "Spawn": clip(0.5, False, spawn("Body", 0.8)),
    }


def amphibian():
    return {
        "Idle": clip(2.0, True, {"Body": {"p": wave(2.0, 0.04, 1, cycles=2, steps=4)},
                                 "Head": {"r": keys((0, 0, 0, 0), (0.7, 0.06, 0.1, 0), (1.4, 0.02, -0.1, 0), (2.0, 0, 0, 0))}}),
        "Walk": clip(0.6, True, {
            "Body": {"p": keys((0, 0, 0, 0), (0.15, 0, 0.5, 0), (0.3, 0, 0.8, 0), (0.45, 0, 0.4, 0), (0.6, 0, 0, 0)),
                     "r": keys((0, 0, 0, 0), (0.15, 0.15, 0, 0), (0.45, -0.1, 0, 0), (0.6, 0, 0, 0))},
            "LegBL": {"r": keys((0, 0, 0, 0), (0.15, -0.9, 0, 0), (0.45, 0.2, 0, 0), (0.6, 0, 0, 0))},
            "LegBR": {"r": keys((0, 0, 0, 0), (0.15, -0.9, 0, 0), (0.45, 0.2, 0, 0), (0.6, 0, 0, 0))},
            "LegFL": {"r": keys((0, 0, 0, 0), (0.3, 0.5, 0, 0), (0.6, 0, 0, 0))},
            "LegFR": {"r": keys((0, 0, 0, 0), (0.3, 0.5, 0, 0), (0.6, 0, 0, 0))},
        }),
        "Shoot": clip(0.7, False, {
            "Head": {"r": keys((0, 0, 0, 0), (0.35, 0.35, 0, 0), (0.45, -0.2, 0, 0), (0.7, 0, 0, 0))},
            "Body": {"p": keys((0, 0, 0, 0), (0.35, 0, 0.2, 0.15), (0.45, 0, 0, -0.2), (0.7, 0, 0, 0))},
        }, impact=0.45),
        "Hit": clip(0.3, False, hit("Body", pitch=0.2, push=0.25)),
        "Death": clip(1.0, False, {"Body": {"r": keys((0, 0, 0, 0), (0.5, 0, 0, 2.9), (1.0, 0, 0, 3.1)),
                                            "p": keys((0, 0, 0, 0), (0.4, 0, 0.6, 0), (1.0, 0, 0.3, 0))},
                                   "LegBL": {"r": keys((0, 0, 0, 0), (0.6, -0.8, 0, 0))}, "LegBR": {"r": keys((0, 0, 0, 0), (0.6, -0.8, 0, 0))}}),
        "Spawn": clip(0.5, False, spawn("Body", 1.0)),
    }


def golem():
    return {
        "Idle": clip(3.0, True, {
            "Body": {"p": wave(3.0, 0.08, 1, steps=6)},
            "ArmL": {"r": wave(3.0, 0.05, 0, steps=6)}, "ArmR": {"r": wave(3.0, -0.05, 0, steps=6)},
            "Head": {"r": keys((0, 0, 0, 0), (1.0, 0.03, 0.12, 0), (2.0, 0, -0.1, 0), (3.0, 0, 0, 0))},
        }),
        "Walk": clip(1.2, True, {
            "LegL": {"r": wave(1.2, 0.45, 0)}, "LegR": {"r": wave(1.2, -0.45, 0)},
            "ArmL": {"r": wave(1.2, -0.3, 0)}, "ArmR": {"r": wave(1.2, 0.3, 0)},
            "Body": {"r": wave(1.2, 0.06, 2), "p": wave(1.2, 0.15, 1, cycles=2, offset=(0, 0.08, 0), steps=4)},
        }),
        "Attack1": clip(1.0, False, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.5, 2.4, 0, 0.2), (0.62, -0.3, 0, 0), (1.0, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.5, -0.3, 0, 0), (0.62, 0.2, 0, 0), (1.0, 0, 0, 0))},
            "Body": {"r": keys((0, 0, 0, 0), (0.5, 0.15, -0.3, 0), (0.62, -0.25, 0.3, 0), (1.0, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.62, 0, -0.3, -0.3), (1.0, 0, 0, 0))},
        }, impact=0.6),
        "Attack2": clip(1.4, False, {
            "ArmL": {"r": keys((0, 0, 0, 0), (0.75, 2.8, 0, 0.2), (0.9, -0.4, 0, 0), (1.4, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.75, 2.8, 0, -0.2), (0.9, -0.4, 0, 0), (1.4, 0, 0, 0))},
            "Body": {"r": keys((0, 0, 0, 0), (0.75, 0.25, 0, 0), (0.9, -0.35, 0, 0), (1.4, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.9, 0, -0.5, -0.3), (1.4, 0, 0, 0))},
        }, impact=0.9),
        "Roar": clip(2.0, False, {
            "Body": {"r": keys((0, 0, 0, 0), (0.5, 0.3, 0, 0), (1.6, 0.3, 0, 0), (2.0, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.6, 0.08, 0, 0), (0.7, -0.08, 0, 0), (0.8, 0.08, 0, 0), (0.9, -0.08, 0, 0), (2.0, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.6, 0.4, 0, -1.0), (1.6, 0.4, 0, -1.0), (2.0, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.6, 0.4, 0, 1.0), (1.6, 0.4, 0, 1.0), (2.0, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.6, 0.4, 0, 0), (1.6, 0.4, 0, 0), (2.0, 0, 0, 0))},
        }),
        "Hit": clip(0.3, False, hit("Body", pitch=0.12, push=0.2)),
        "Death": clip(1.6, False, {
            "Body": {"r": keys((0, 0, 0, 0), (1.2, -1.35, 0, 0), (1.6, -1.45, 0, 0)),
                     "p": keys((0, 0, 0, 0), (1.2, 0, -2.4, -1.6), (1.6, 0, -2.6, -1.7))},
            "ArmL": {"r": keys((0, 0, 0, 0), (1.0, 1.4, 0, 0))}, "ArmR": {"r": keys((0, 0, 0, 0), (1.0, 1.2, 0, 0))},
            "LegL": {"r": keys((0, 0, 0, 0), (1.0, 0.6, 0, 0))}, "LegR": {"r": keys((0, 0, 0, 0), (1.0, 0.4, 0, 0))},
        }),
        "Spawn": clip(0.6, False, {"Body": {"p": keys((0, 0, -3.0, 0), (0.45, 0, 0.3, 0), (0.6, 0, 0, 0))}}),
        "Intro": clip(2.0, False, {}),  # filled below (= Roar)
    }


def snowman():
    return {
        "Idle": clip(2.0, True, {"Middle": {"r": wave(2.0, 0.05, 2, steps=6)}, "Head": {"r": wave(2.0, 0.15, 1, steps=6)},
                                 "ArmL": {"r": wave(2.0, 0.08, 1, steps=6)}, "ArmR": {"r": wave(2.0, -0.08, 1, steps=6)}}),
        "Walk": clip(0.8, True, {
            "Body": {"p": wave(0.8, 0.3, 1, cycles=2, steps=4, kind=lambda x: abs(math.sin(x / 2)))},
            "Middle": {"r": wave(0.8, 0.1, 2)}, "Head": {"r": wave(0.8, -0.1, 2)},
            "ArmL": {"r": wave(0.8, 0.3, 1)}, "ArmR": {"r": wave(0.8, 0.3, 1)},
        }),
        "Attack1": clip(0.8, False, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.4, 0, -0.9, 0.3), (0.55, 0, 1.2, 0), (0.8, 0, 0, 0))},
            "Middle": {"r": keys((0, 0, 0, 0), (0.4, 0, -0.35, 0), (0.55, 0, 0.4, 0), (0.8, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.4, 0.2, 0, 0), (0.55, -0.15, 0, 0), (0.8, 0, 0, 0))},
        }, impact=0.5),
        "Hit": clip(0.3, False, hit("Middle", pitch=0.2, push=0.3)),
        "Death": clip(1.2, False, {
            "Head": {"p": keys((0, 0, 0, 0), (0.3, 0, 0.6, 0), (0.9, 1.6, -3.2, 0.5), (1.2, 1.7, -3.3, 0.5)),
                     "r": keys((0, 0, 0, 0), (0.9, 0.5, 0, 1.8))},
            "Middle": {"r": keys((0, 0, 0, 0), (0.9, 0, 0, -1.0)), "p": keys((0, 0, 0, 0), (0.9, -0.8, -1.4, 0))},
        }),
        "Spawn": clip(0.5, False, spawn("Body", 1.5)),
    }


def floater():
    return {
        "Idle": clip(2.0, True, {
            "Body": {"p": wave(2.0, 0.3, 1, steps=6)},
            "Tail": {"r": wave(2.0, 0.2, 2, steps=6)}, "Tail2": {"r": wave(2.0, 0.3, 0, phase=1.0, steps=6)},
            "ArmL": {"r": wave(2.0, 0.2, 2, offset=(0, 0, -0.1), steps=6)}, "ArmR": {"r": wave(2.0, -0.2, 2, offset=(0, 0, 0.1), steps=6)},
        }),
        "Walk": clip(1.2, True, {
            "Body": {"p": wave(1.2, 0.25, 1, steps=6), "r": keys((0, -0.2, 0, 0), (1.2, -0.2, 0, 0))},
            "Tail": {"r": wave(1.2, 0.3, 2, offset=(0.3, 0, 0), steps=6)}, "Tail2": {"r": wave(1.2, 0.4, 0, offset=(0.3, 0, 0), steps=6)},
        }),
        "Shoot": clip(0.8, False, {
            "ArmL": {"r": keys((0, 0, 0, 0), (0.4, 1.3, 0, 0.2), (0.5, 1.7, 0, 0.1), (0.8, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.4, 1.3, 0, -0.2), (0.5, 1.7, 0, -0.1), (0.8, 0, 0, 0))},
            "Body": {"p": keys((0, 0, 0, 0), (0.4, 0, 0.2, 0.3), (0.5, 0, 0, -0.3), (0.8, 0, 0, 0))},
        }, impact=0.5),
        "Hit": clip(0.3, False, hit("Body", pitch=0.2, push=0.35)),
        "Death": clip(1.0, False, {"Body": {"p": keys((0, 0, 0, 0), (1.0, 0, -1.5, 0)), "r": keys((0, 0, 0, 0), (1.0, 0.5, 0.6, 0))},
                                   "Tail": {"r": keys((0, 0, 0, 0), (1.0, 0.6, 0, 0))}}),
        "Spawn": clip(0.5, False, spawn("Body", 1.5)),
    }


def gorilla():
    return {
        "Idle": clip(2.6, True, {
            "Body": {"p": wave(2.6, 0.08, 1, steps=6)},
            "Head": {"r": keys((0, 0, 0, 0), (0.9, 0.05, 0.15, 0), (1.8, 0, -0.12, 0), (2.6, 0, 0, 0))},
            "ArmL": {"r": wave(2.6, 0.05, 0, steps=6)}, "ArmR": {"r": wave(2.6, -0.05, 0, steps=6)},
        }),
        "Walk": clip(1.0, True, {
            "ArmL": {"r": wave(1.0, 0.45, 0)}, "ArmR": {"r": wave(1.0, -0.45, 0)},
            "LegL": {"r": wave(1.0, -0.4, 0)}, "LegR": {"r": wave(1.0, 0.4, 0)},
            "Body": {"r": wave(1.0, 0.07, 2), "p": wave(1.0, 0.12, 1, cycles=2, offset=(0, 0.06, 0), steps=4)},
        }),
        "Attack1": clip(1.0, False, {
            "ArmR": {"r": keys((0, 0, 0, 0), (0.5, 2.2, 0, 0.1), (0.62, -0.4, 0, 0), (1.0, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.5, 0.6, 0, 0), (0.62, -0.2, 0, 0), (1.0, 0, 0, 0))},
            "Body": {"r": keys((0, 0, 0, 0), (0.5, 0.2, -0.2, 0), (0.62, -0.3, 0.2, 0), (1.0, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.62, 0, -0.3, -0.4), (1.0, 0, 0, 0))},
        }, impact=0.6),
        "Roar": clip(2.0, False, {  # chest beating
            "Body": {"r": keys((0, 0, 0, 0), (0.35, 0.35, 0, 0), (1.6, 0.35, 0, 0), (2.0, 0, 0, 0)),
                     "p": keys((0, 0, 0, 0), (0.35, 0, 0.6, 0.2), (1.6, 0, 0.6, 0.2), (2.0, 0, 0, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (0.4, 1.3, 0, 0.5), (0.55, 0.9, 0, 0.3), (0.7, 1.3, 0, 0.5), (0.85, 0.9, 0, 0.3),
                               (1.0, 1.3, 0, 0.5), (1.15, 0.9, 0, 0.3), (1.6, 1.0, 0, 0.3), (2.0, 0, 0, 0))},
            "ArmR": {"r": keys((0, 0, 0, 0), (0.4, 0.9, 0, -0.3), (0.55, 1.3, 0, -0.5), (0.7, 0.9, 0, -0.3), (0.85, 1.3, 0, -0.5),
                               (1.0, 0.9, 0, -0.3), (1.15, 1.3, 0, -0.5), (1.6, 1.0, 0, -0.3), (2.0, 0, 0, 0))},
            "Head": {"r": keys((0, 0, 0, 0), (0.35, 0.45, 0, 0), (1.6, 0.45, 0, 0), (2.0, 0, 0, 0))},
        }),
        "Hit": clip(0.3, False, hit("Body", pitch=0.12, push=0.2)),
        "Death": clip(1.6, False, {
            "Body": {"r": keys((0, 0, 0, 0), (1.2, 0, 0, 1.35), (1.6, 0, 0, 1.45)),
                     "p": keys((0, 0, 0, 0), (1.2, 0, -1.6, 0), (1.6, 0, -1.7, 0))},
            "ArmL": {"r": keys((0, 0, 0, 0), (1.0, 0.8, 0, -0.8))}, "ArmR": {"r": keys((0, 0, 0, 0), (1.0, 0.6, 0, 0.6))},
        }),
        "Spawn": clip(0.6, False, spawn("Body", 3.0)),
    }


def all_families():
    fams = {
        "Quadruped": quadruped(), "Biped": biped(), "BossBiped": boss_biped(), "Bird": bird(), "Serpent": serpent(),
        "Arachnid": arachnid(), "Crustacean": crustacean(), "Insect": insect(), "Fish": fish(), "Amphibian": amphibian(),
        "Golem": golem(), "Snowman": snowman(), "Floater": floater(), "Gorilla": gorilla(),
    }
    for name in ("Golem", "Gorilla"):
        fams[name]["Intro"] = fams[name]["Roar"]
        fams[name]["Enrage"] = fams[name]["Roar"]
    return fams


# clip order on the Blender timeline (and the clips a role needs, brief Part E)
CLIP_ORDER = ["Idle", "Walk", "Run", "Attack1", "Shoot", "Attack2", "Hit", "Death", "Spawn", "Roar", "Intro", "Enrage", "Wave", "Talk"]
ROLE_CLIPS = {
    "normal": ["Idle", "Walk", "Run", "Attack1", "Shoot", "Hit", "Death", "Spawn"],
    "mini": ["Idle", "Walk", "Run", "Attack1", "Shoot", "Hit", "Death", "Spawn", "Attack2", "Roar"],
    "boss": ["Intro", "Idle", "Walk", "Attack1", "Hit", "Death", "Enrage"],
    "pet": ["Idle"],
    "npc": ["Idle", "Wave", "Talk"],
}
