"""Deterministic export preparation for the supplied painted animation sheets.

Source art is not redrawn. Fractional 4x2 cells are resampled with fixed framing
into padded 256px cells, then packed as a 1024px Grid4x4 atlas. The approved
eight-frame sequence is repeated twice to suit the existing runtime's layouts.
No per-frame fitting, new inbetweens, recoloring, uploads or runtime activation.

python tools/vfx_pipeline/pack_directional_fire.py [--validate-only]
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
VFX = ROOT / "assets/vfx"
SOURCE = VFX / "source/painted_fire_v1/animation/directional_manifest.json"
OUT = VFX / "generated/painted_fire_v1"
VIEWS = ("front", "three_quarter", "side", "rear")
CELL = 256
PADDING = 12


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_path(value):
    path = (ROOT/value).resolve()
    if not path.is_relative_to(VFX.resolve()):
        raise ValueError(f"Asset path escapes VFX directory: {value}")
    return path


def pack():
    source = json.loads(SOURCE.read_text())
    OUT.mkdir(parents=True,exist_ok=True)
    entries = {}
    for name in VIEWS:
        entry = source["views"][name]
        path = checked_path(entry["file"])
        if sha(path) != entry["sha256"]:
            raise ValueError(f"Source hash mismatch: {name}")
        with Image.open(path) as image:
            image.load()
            if image.mode != "RGBA" or entry["grid"] != [4,2] or entry["frames"] != 8:
                raise ValueError(f"Unsupported source sheet: {name}")
            frames = []
            width,height = image.width/4,image.height/2
            for index in range(8):
                x,y=(index%4)*width,(index//4)*height
                frame = image.transform((CELL-2*PADDING,CELL-2*PADDING),Image.Transform.EXTENT,
                    (x,y,x+width,y+height),Image.Resampling.BICUBIC)
                tile = Image.new("RGBA",(CELL,CELL),(255,255,255,0))
                tile.paste(frame,(PADDING,PADDING))
                frames.append(tile)
        atlas = Image.new("RGBA",(1024,1024),(255,255,255,0))
        for index in range(16):
            atlas.paste(frames[index%8],((index%4)*CELL,(index//4)*CELL))
        dest = OUT/f"fire_{name}_v1.png"
        atlas.save(dest)
        entries[name] = {"file":dest.relative_to(ROOT).as_posix(),"sha256":sha(dest),
            "source":entry["file"],"source_sha256":entry["sha256"],"size":[1024,1024],
            "grid":[4,4],"layout":"Grid4x4","frame_count":16,"unique_frames":8,
            "source_frame_map":[i%8 for i in range(16)],"fps":8,"unique_cycle_seconds":1,
            "padding_px":PADDING,"framing":"fixed source cell; no per-frame fitting",
            "angle_degrees":entry["angle_degrees"],"source_motion_approval":entry["user_motion_approval"],
            "roblox_id":None,"studio_verified":False}
    manifest = {"version":1,"status":"local_exports_pending_import_review", "assets":entries,
        "generator":"tools/vfx_pipeline/pack_directional_fire.py","generator_sha256":sha(Path(__file__)),
        "publication":"not_uploaded","runtime_activation":False,
        "remaining_art_review":[n for n,e in entries.items() if e["source_motion_approval"] != "approved"],
        "notes":["Eight source frames repeated twice; no invented animation frames.",
            "At 8 fps the visual sequence still repeats every second.",
            "Existing runtime only understands standard grids; this export deliberately uses Grid4x4.",
            "Color and silhouette design preserved; resampling and uniform padding are technical export steps.",
            "Rear three-quarter and elevation coverage remain approximations."]}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")


def validate():
    manifest = json.loads((OUT/"manifest.json").read_text())
    errors = []
    for name in VIEWS:
        entry = manifest["assets"][name]
        path = checked_path(entry["file"])
        if sha(path) != entry["sha256"] or sha(checked_path(entry["source"])) != entry["source_sha256"]:
            errors.append(f"{name}: source/export hash mismatch")
        with Image.open(path) as image:
            image.load()
            if image.mode != "RGBA" or image.size != (1024,1024):
                errors.append(f"{name}: invalid export size or mode")
            for index in range(16):
                x,y=(index%4)*CELL,(index//4)*CELL
                tile = image.crop((x,y,x+CELL,y+CELL))
                bounds = tile.getchannel("A").getbbox()
                if bounds is None or bounds[0]<PADDING or bounds[1]<PADDING or bounds[2]>CELL-PADDING or bounds[3]>CELL-PADDING:
                    errors.append(f"{name}: frame {index} missing artwork or transparent gutter")
                if index>=8:
                    source_index=index-8
                    sx,sy=(source_index%4)*CELL,(source_index//4)*CELL
                    if tile.tobytes() != image.crop((sx,sy,sx+CELL,sy+CELL)).tobytes():
                        errors.append(f"{name}: repeated cycle does not match source sequence")
        if entry["roblox_id"] is not None or entry["studio_verified"]:
            errors.append(f"{name}: export must not assert publication or Studio verification")
    if errors:
        raise ValueError("\n".join(errors))
    print("Validated 4 RGBA exports, 64 padded cells, repeated cycles and unchanged source hashes. No uploads.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate-only",action="store_true")
    args = parser.parse_args()
    if not args.validate_only:
        pack()
    validate()
