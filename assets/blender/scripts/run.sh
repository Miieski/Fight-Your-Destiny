#!/bin/bash
# Usage: bash assets/blender/scripts/run.sh <LandmarkName> [more names...]   (from the repo root)
# Re-generates the FBX, the preview PNG, the stats JSON and the .blend for each landmark.
HERE="$(cd "$(dirname "$0")" && pwd)"
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
for name in "$@"; do
  "$BLENDER" --background --factory-startup --python "$HERE/$name.py" 2>&1 | grep -E "LANDMARK|size X|tris|TOTAL|PROBLEM|Error|error|Traceback|File \"|line [0-9]+" 
done
