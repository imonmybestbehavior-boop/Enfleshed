"""Preserve three supplied fire images byte-for-byte and inspect their import properties.

Usage: python tools/vfx_pipeline/inspect_painted_fire.py FIREBALL TRAIL IMPACT
No pixel edits, uploads or runtime changes are performed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vfx/source/painted_fire_v1"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("fireball", "trail", "impact"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    entries = {}
    for name in ("fireball", "trail", "impact"):
        source = getattr(args, name)
        data = source.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        target = OUT / (name + ".png")
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError(f"Refusing to overwrite different source artwork: {target}")
        shutil.copyfile(source, target)
        with Image.open(target) as image:
            image.load()
            alpha = image.getchannel("A") if "A" in image.getbands() else None
            bounds = alpha.getbbox() if alpha is not None else None
            solid_bounds = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox() if alpha is not None else None
            histogram = alpha.histogram() if alpha is not None else None
            entries[name] = {
                "file": str(target.relative_to(ROOT)).replace("\\", "/"),
                "sha256": digest,
                "size": list(image.size),
                "mode": image.mode,
                "alpha_extrema": alpha.getextrema() if alpha is not None else None,
                "transparent_pixels": histogram[0] if histogram else 0,
                "partially_transparent_pixels": sum(histogram[1:255]) if histogram else 0,
                "visible_bounds": bounds,
                "bounds_alpha_at_least_16": solid_bounds,
                "padding_left_top_right_bottom": [bounds[0], bounds[1], image.width-bounds[2], image.height-bounds[3]] if bounds else None,
                "exceeds_current_1024px_project_budget": max(image.size) > 1024,
                "roblox_id": None,
                "studio_verified": False,
            }
    manifest = {
        "version": 1,
        "provenance": "User supplied images; original bytes preserved without pixel modification.",
        "status": "candidate_source_artwork",
        "assets": entries,
        "pending": ["Gameplay-sized readability review", "Export preparation", "Animation and tiling", "Upload approval for these new assets", "Studio visual verification"],
    }
    (OUT/"inspection.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
