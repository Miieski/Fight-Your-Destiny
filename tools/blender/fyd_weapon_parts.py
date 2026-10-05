"""Shared weapon parts (meters, origin = grip center, blade/head along +Z, front = -Y)."""
import math

import fyd_icons as I
from fyd_weapons import pm


def blade_outline(L, w, taper=0.85, tip_start=0.82, curve=0.0, widen=0.0, n=10, serr_right=0, serr_left=0,
                  serr_depth=0.25, wave=0.0, spikes_left=0, spike_len=0.6):
    """Blade outline in the XZ plane from z=0 (guard) to z=L (tip). Returns a closed point list.
    taper: width kept at tip_start; curve: tip shift in x as a fraction of L (scimitar);
    widen: extra width towards the tip (machete); serr_*: number of notches on that edge;
    wave: sinusoidal edge amplitude (fraction of w); spikes_left: back spikes (demon blades)."""
    right, left = [], []
    for i in range(n + 1):
        t = tip_start * i / n
        u = t / tip_start
        half = w / 2 * (1 - (1 - taper) * u) * (1 + widen * u)
        half *= 1 + wave * math.sin(u * math.pi * 5)
        c = curve * (t ** 2) * L
        right.append([c + half, t * L])
        left.append([c - half, t * L])
    # notches: pull every other point inwards on the chosen edge (between 15% and 75% of the blade)
    for edge, count in ((right, serr_right), (left, serr_left)):
        if count:
            for i in range(1, len(edge) - 1):
                u = i / n
                if 0.12 < u < 0.78 and i % 2 == 0:
                    mid = (right[i][0] + left[i][0]) / 2
                    edge[i][0] = edge[i][0] + (mid - edge[i][0]) * serr_depth
    pts = [tuple(p) for p in right]
    pts.append((curve * L, L))
    back = [tuple(p) for p in reversed(left)]
    if spikes_left:
        spiked = []
        for i, p in enumerate(back):
            spiked.append(p)
            u = 1 - i / n
            if 0.2 < u < 0.8 and i % 3 == 1 and len([s for s in spiked if len(s) == 3]) < spikes_left:
                spiked.append((p[0] - w * spike_len, p[1] - w * 0.6, 0))
        back = [(s[0], s[1]) for s in spiked]
    return pts + back


def blade(pts, thickness, material, z0=0.125, bevel=None, x=0.0):
    return I.extrude(pts, thickness, material, loc=(x, 0, z0), bevel=thickness * 0.38 if bevel is None else bevel,
                     segments=1, angle=30, smooth=False, name="Blade")


def strip(x, z, length, width, thickness, material, rot_y=0.0):
    """Thin raised strip on both faces of a blade (fuller, glowing crack)."""
    return I.box(width, thickness, length, material, loc=(x, 0, z), rot=(0, rot_y, 0), bevel=0.0, smooth=False, name="Strip")


def grip(material, r=0.017, length=0.2, wraps=0, wrap_material=None, segs=10):
    I.cyl(r, length, material, segs=segs, bevel=0.0, name="Grip")
    for k in range(wraps):
        I.torus(r * 1.04, r * 0.28, wrap_material or material, segs=segs, rsegs=5,
                loc=(0, 0, -length / 2 + (k + 0.5) * length / wraps), name="Wrap")


def guard_bar(width, material, z=0.11, depth=0.036, height=0.028, bevel=0.006):
    return I.box(width, depth, height, material, loc=(0, 0, z), bevel=bevel, segments=1, name="Guard")


def pommel_ball(r, material, z=-0.125, segs=12):
    return I.sphere(r, material, segs=segs, rings=8, loc=(0, 0, z), name="Pommel")


def gem(r, material, loc, segs=8):
    return I.sphere(r, material, segs=segs, rings=6, loc=loc, smooth=False, name="Gem")


def spike(base, tip, r, material, segs=8):
    """Cone from base point to tip point."""
    b, t = I.Vector(base), I.Vector(tip)
    d = t - b
    ob = I.cyl(r, d.length, material, r2=0.0, segs=segs, bevel=0.0, smooth=False, loc=tuple((b + t) / 2), name="Spike")
    ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return ob


def crystal(loc, r, h, material, tilt=(0, 0, 0)):
    root = I.empty("Crystal", loc=loc, rot=tilt)
    I.cyl(r, h * 0.7, material, segs=6, loc=(0, 0, h * 0.35), bevel=0.0, smooth=False, parent=root, name="CrystalBody")
    I.cyl(r, h * 0.3, material, r2=0.0, segs=6, loc=(0, 0, h * 0.85), bevel=0.0, smooth=False, parent=root, name="CrystalTip")
    return root
