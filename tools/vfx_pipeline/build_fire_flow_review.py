"""Preserve a user-supplied 4x2 sheet and build an unmodified frame playback review.

Usage: python tools/vfx_pipeline/build_fire_flow_review.py [path/to/sheet.png]
No pixel editing, generated movement, uploads or live asset changes.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/vfx/source/painted_fire_v1/animation"
SHEET = FOLDER / "core_flow_user_v1.png"
OUTPUT = ROOT / "assets/vfx/previews/fire_flow_review.html"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source",nargs="?",type=Path)
    args = parser.parse_args()
    FOLDER.mkdir(parents=True,exist_ok=True)
    if args.source:
        data = args.source.read_bytes()
        if SHEET.exists() and SHEET.read_bytes() != data:
            raise ValueError("Refusing to replace a different source sheet")
        if args.source.resolve() != SHEET.resolve():
            shutil.copyfile(args.source,SHEET)
    data = SHEET.read_bytes()
    prior_path = FOLDER/"user_flow_manifest.json"
    prior = json.loads(prior_path.read_text()) if prior_path.exists() else {}
    source_hash = hashlib.sha256(data).hexdigest()
    with Image.open(SHEET) as image:
        image.load()
        if image.mode != "RGBA":
            raise ValueError("Expected RGBA source artwork")
        manifest = {"version":1,"provenance":"User supplied eight-frame sheet; original bytes preserved",
            "file":SHEET.relative_to(ROOT).as_posix(),"sha256":source_hash,
            "size":list(image.size),"grid":[4,2],"frames":8,"order":"row-major",
            "alpha_extrema":image.getchannel("A").getextrema(),"preview_fps":8,
            "integer_cell_boundaries":image.width%4==0 and image.height%2==0,
            "user_motion_approval":"pending","roblox_id":None,"studio_verified":False}
        if prior.get("sha256") == source_hash:
            for key in ("user_motion_approval", "approval_text"):
                if key in prior:
                    manifest[key] = prior[key]
    (FOLDER/"user_flow_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    template = Path(__file__).with_name("fire_flow_review.template.html").read_text(encoding="utf-8")
    if template.count("__SHEET__") != 1:
        raise ValueError("Expected one source-sheet insertion point")
    url = "data:image/png;base64,"+base64.b64encode(data).decode("ascii")
    OUTPUT.write_text(template.replace("__SHEET__",json.dumps(url)),encoding="utf-8")
    print(f"Preserved {SHEET}; built {OUTPUT}; no pixels modified or assets uploaded")


if __name__ == "__main__":
    main()
