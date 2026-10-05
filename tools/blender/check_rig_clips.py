"""Checksums of the rig clips (tools/blender/fyd_creature_clips.py) to compare with the Luau twin
src/ReplicatedStorage/GameSystem/Config/RigClips.luau (RigClips.checksum(family), admin command checkRigClips).

    python tools/blender/check_rig_clips.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fyd_creature_clips as CL  # noqa: E402


def checksum(clips):
    total = 0.0
    for c in clips.values():
        total += c["length"] + c.get("impact", 0)
        for channels in c["tracks"].values():
            for keys in channels.values():
                for t, v in keys:
                    total += t + v[0] + v[1] + v[2]
    return round(total, 3)


if __name__ == "__main__":
    sums = {fam: checksum(clips) for fam, clips in CL.all_families().items()}
    print("{" + ", ".join(f"{k} = {v}" for k, v in sums.items()) + "}")
