#!/usr/bin/env bash
# Regenerate the whole spell VFX asset library, previews and Luau manifest.
#   tools/vfx_pipeline/build_all.sh            textures + meshes + previews + manifest
#   tools/vfx_pipeline/build_all.sh --lookdev  also render the Cycles lookdev stills (~90 s)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/blender.sh" "$HERE/gen_textures.py"
"$HERE/blender.sh" "$HERE/preview_textures.py"
"$HERE/blender.sh" "$HERE/gen_meshes.py"
if [[ "${1:-}" == "--lookdev" ]]; then
  "$HERE/blender.sh" "$HERE/lookdev.py"
fi
python3 "$HERE/build_manifest.py"
