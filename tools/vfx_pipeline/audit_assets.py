"""Offline VFX release gate: decoded pixels, hashes, budgets, references and publication evidence.

python tools/vfx_pipeline/audit_assets.py [--require-studio]
Never makes network calls or equates an asset ID with a verified upload.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
VFX = ROOT / "assets/vfx"
STUDY = VFX / "studies/illustrated_fire_v1/manifest.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(root, value):
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Path escapes asset root: {value}")
    return path


def check_pixels(path, expected, errors, opaque=False):
    try:
        with Image.open(path) as image:
            image.load()  # decode IDAT, not only the header
            if image.mode != "RGBA" or list(image.size) != list(expected):
                errors.append(f"{path.name}: expected RGBA {expected}, got {image.mode} {image.size}")
            if max(image.size) > 1024:
                errors.append(f"{path.name}: exceeds project 1024px budget")
            if image.mode == "RGBA":
                low, high = image.getchannel("A").getextrema()
                if high == 0 or (opaque and (low, high) != (0, 255)):
                    errors.append(f"{path.name}: empty image or missing opaque silhouette/clear background")
    except (OSError, ValueError) as error:
        errors.append(f"{path.name}: decode failed: {error}")


def inspect(root=ROOT, study_path=STUDY):
    errors, warnings, assets = [], [], []
    vfx = root / "assets/vfx"
    textures = json.loads((vfx/"textures/textures.json").read_text())
    meshes = json.loads((vfx/"meshes/meshes.json").read_text())
    ids = json.loads((vfx/"asset_ids.json").read_text())
    known = set(textures) | {"mesh:"+key for key in meshes}
    for name, value in ids.items():
        if name.startswith("_"):
            continue
        if name not in known or type(value) is not int or value <= 0:
            errors.append(f"Invalid asset ID mapping: {name}")
    for name, meta in textures.items():
        path = inside(vfx/"textures",meta["file"])
        check_pixels(path, [meta["width"],meta["height"]], errors)
        assets.append({"key":name,"file":str(path.relative_to(root)).replace("\\","/"),
            "sha256":digest(path),"recorded_id":ids.get(name),"publication":"recorded_id_unverified" if name in ids else "unpublished"})
    for name, meta in meshes.items():
        for kind in ("fbx","glb"):
            path = inside(vfx/"meshes",meta[kind])
            data = path.read_bytes()
            signature = b"glTF" if kind == "glb" else b"Kaydara FBX Binary"
            if not data.startswith(signature):
                errors.append(f"{name}: invalid {kind} signature")
            assets.append({"key":"mesh:"+name,"file":str(path.relative_to(root)).replace("\\","/"),
                "sha256":digest(path),"recorded_id":ids.get("mesh:"+name),
                "publication":"recorded_id_unverified" if "mesh:"+name in ids else "unpublished_or_studio_only"})
        if not 0 < meta["triangles"] <= 20000:
            errors.append(f"{name}: triangle budget exceeded")
    # Validate named authored assets in the actual compositional recipe data.
    for rel in ["Signature/SignatureKits.luau","Signature/SignatureLibrary.luau"]:
        code = (root/"src/shared/SpellVFXSystem"/rel).read_text(encoding="utf-8")
        for field, name in re.findall(r'\b(Texture|Mesh|CoreMesh|ShellMesh|Trail|Core|Impact|Ambient|Secondary|Cast)\s*=\s*"([a-z][a-z0-9_]*)"',code):
            catalog = meshes if "Mesh" in field else textures
            if name not in catalog:
                errors.append(f"{rel}: unknown {field} asset {name}")
    study = json.loads(study_path.read_text())
    generator = inside(root,study["generator"])
    if digest(generator) != study["generator_sha256"]:
        errors.append("Study generator changed; regenerate artwork")
    for name, entry in study["assets"].items():
        path = inside(root,entry["file"])
        check_pixels(path,entry["size"],errors,opaque=True)
        if digest(path) != entry["sha256"]:
            errors.append(f"Study {name}: export hash mismatch")
        if entry["candidate_slot"] not in textures:
            errors.append(f"Study {name}: unknown candidate slot")
        if entry["frames"] not in (1,16) or len(entry["sources"]) != entry["frames"]:
            errors.append(f"Study {name}: invalid frame/source count")
        for source in entry["sources"]:
            if digest(inside(root,source["path"])) != source["sha256"]:
                errors.append(f"Study {name}: editable source hash mismatch")
        if entry["roblox_id"] is not None or entry["studio_verified"]:
            errors.append(f"Study {name}: candidate requires separate verified publication receipt")
    # Static findings are review pointers, not an assertion that every match is visible.
    patterns = r'Instance\.new\("(?:Fire|ForceField|Part|WedgePart)"\)|Enum\.Material\.(?:Neon|ForceField)|rbxasset://textures/particles/'
    placeholders = []
    for base in [root/"src/shared/SpellVFXSystem",root/"src/client/Controllers/MagicPresentationController.luau",root/"src/server/Services/MagicPresentation.luau"]:
        paths = base.rglob("*.luau") if base.is_dir() else [base]
        for path in paths:
            if not path.exists():
                continue
            for i,line in enumerate(path.read_text(encoding="utf-8").splitlines(),1):
                if re.search(patterns,line):
                    placeholders.append({"file":str(path.relative_to(root)).replace("\\","/"),"line":i,"code":line.strip(),"status":"review_visible_or_invisible_in_Studio"})
    warnings.append("Recorded IDs have not been fetched or permission-checked in Studio during this audit.")
    warnings.append("Candidate artwork is not published, bound to runtime, or visually verified in Studio.")
    return {"schema_version":1,"local_validation_passed":not errors,"release_ready":False,
        "errors":errors,"warnings":warnings,"inventory":assets,"study_assets":len(study["assets"]),
        "placeholder_review":placeholders,"studio_measurements":None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-studio",action="store_true")
    args = parser.parse_args()
    report = inspect()
    out = VFX/"manifests/local_audit.json"
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(f"VFX audit: {len(report['inventory'])} exports, {report['study_assets']} candidate textures, {len(report['errors'])} errors")
    for error in report["errors"]:
        print("ERROR",error)
    print("Studio release gate: PENDING. Report:",out)
    raise SystemExit(1 if report["errors"] or args.require_studio else 0)


if __name__ == "__main__":
    main()
