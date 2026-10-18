"""Package the original painted images into a self-contained motion-review page.

Images are embedded byte-for-byte. A local WebGL layer renderer animates
independent painted flame tongues. This does not upload assets or bake a
production atlas. Roblox integration requires an approved equivalent layer
recipe or baked artwork; the browser shader is not a Roblox runtime module.
"""
import base64
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/vfx/source/painted_fire_v1"
OUT = ROOT / "assets/vfx/previews/painted_fire_preview.html"


def main():
    inspection = json.loads((SOURCE/"inspection.json").read_text())
    assets = {}
    for name in ("core", "trail", "impact"):
        entry = inspection["assets"][name]
        path = (ROOT/entry["file"]).resolve()
        if not path.is_relative_to(SOURCE.resolve()):
            raise ValueError("Source path outside approved artwork directory")
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"Source changed since inspection: {name}")
        assets[name] = "data:image/png;base64,"+base64.b64encode(data).decode("ascii")
    animation_manifest = json.loads((SOURCE/"animation/layered_manifest.json").read_text())
    atlas = (ROOT/animation_manifest["file"]).resolve()
    if not atlas.is_relative_to((SOURCE/"animation").resolve()):
        raise ValueError("Animation path outside approved artwork directory")
    atlas_data = atlas.read_bytes()
    if hashlib.sha256(atlas_data).hexdigest() != animation_manifest["sha256"]:
        raise ValueError("Animation atlas changed since inspection")
    assets["flameLick"] = "data:image/png;base64,"+base64.b64encode(atlas_data).decode("ascii")
    template = Path(__file__).with_name("painted_fire_preview.template.html").read_text(encoding="utf-8")
    if template.count("__ASSETS__") != 1:
        raise ValueError("Expected exactly one asset insertion point")
    OUT.parent.mkdir(parents=True,exist_ok=True)
    layers = Path(__file__).with_name("painted_fire_layers.js").read_text(encoding="utf-8")
    if template.count("__LAYERS__") != 1:
        raise ValueError("Expected exactly one layered renderer insertion point")
    OUT.write_text(template.replace("__ASSETS__",json.dumps(assets)).replace("__LAYERS__",layers),encoding="utf-8")
    print(f"Built {OUT}; original source pixels unchanged; no assets uploaded.")


if __name__ == "__main__":
    main()
