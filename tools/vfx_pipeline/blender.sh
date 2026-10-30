#!/usr/bin/env bash
# Run a pipeline script in headless Blender (Flatpak or native). Paths are made absolute
# because the Flatpak sandbox does not keep the caller's working directory.
#   tools/vfx_pipeline/blender.sh <script.py> [args...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$(realpath "$1")"; shift
if command -v blender >/dev/null 2>&1; then
  exec blender -b --factory-startup --python "$SCRIPT" -- "$ROOT" "$@"
fi
exec flatpak run --filesystem="$ROOT" --env=VFX_ONLY="${VFX_ONLY:-}" --env=VFX_STYLE="${VFX_STYLE:-}" org.blender.Blender -b --factory-startup --python "$SCRIPT" -- "$ROOT" "$@"
