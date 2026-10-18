"""Package front, three-quarter, side and rear sheets as a view-angle test.

No image edits, generated geometric perspective, atlas repacking or uploads.
"""
import base64
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/vfx/source/painted_fire_v1/animation"
OUT = ROOT / "assets/vfx/previews/fire_angle_review.html"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packed",action="store_true",help="Review the padded 1024px export sheets")
    args = parser.parse_args()
    manifest = json.loads((FOLDER/"directional_manifest.json").read_text())
    export_dir = ROOT/"assets/vfx/generated/painted_fire_v1"
    exports = json.loads((export_dir/"manifest.json").read_text()) if args.packed else None
    views = {}
    for name in ("front", "three_quarter", "side", "rear", "previous_side"):
        packed = args.packed and name != "previous_side"
        entry = exports["assets"][name] if packed else manifest["views"][name]
        path = (ROOT/entry["file"]).resolve()
        if not path.is_relative_to((export_dir if packed else FOLDER).resolve()):
            raise ValueError("Source path outside the approved animation directory")
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"Source content changed: {name}")
        views[name] = {"url":"data:image/png;base64,"+base64.b64encode(data).decode("ascii"),"grid":entry["grid"]}
    template = Path(__file__).with_name("fire_angle_review.template.html").read_text(encoding="utf-8")
    if template.count("__VIEWS__") != 1:
        raise ValueError("Expected one view insertion point")
    out = OUT.with_name("packed_fire_angle_review.html") if args.packed else OUT
    label = "Packed export review · 1024px sheets with uniform padding" if args.packed else "Original source-sheet review"
    out.write_text(template.replace("__VIEWS__",json.dumps(views)).replace("__EXPORT_LABEL__",label),encoding="utf-8")
    print(f"Built {out}; four directional sheets; Studio review pending.")


if __name__ == "__main__":
    main()
