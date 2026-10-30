"""Upload the generated VFX textures with the Roblox Open Cloud Assets API and record their ids.

You run this yourself; the key is read from the environment and never written anywhere.
  1. Create an API key at create.roblox.com > Open Cloud > API Keys with the
     "Assets: read + write" permission (and your IP allowed).
  2. export ROBLOX_API_KEY=...            (your key)
     export ROBLOX_CREATOR=user:12345678  (or group:98765)
  3. python3 tools/vfx_pipeline/upload_textures.py [--only name1,name2]
  4. python3 tools/vfx_pipeline/build_manifest.py

Textures are uploaded as Decals; Open Cloud returns the image asset id that ParticleEmitter
textures use. Confirm in Studio with scripts/studio_vfx_asset_check.luau. Meshes are NOT
uploaded here: Open Cloud returns a Model id, not a mesh id, so import the FBX files with
Studio's 3D Importer instead (docs/spell-vfx-assets.md).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VFX = ROOT / "assets" / "vfx"
API = "https://apis.roblox.com/assets/v1"


def request(method, url, key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"{error.code} {error.read().decode(errors='replace')}") from None


def upload(path, name, key, creator):
    kind, ident = creator.split(":", 1)
    meta = {
        "assetType": "Decal",
        "displayName": f"Enfleshed VFX {name}",
        "description": "Generated spell VFX texture (Enfleshed).",
        "creationContext": {"creator": {"userId" if kind == "user" else "groupId": ident}},
    }
    boundary = uuid.uuid4().hex
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        f"Content-Type: image/png\r\n\r\n"
    ).encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    op = request("POST", f"{API}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(30):
        if op.get("done"):
            return int(op["response"]["assetId"])
        time.sleep(2)
        op = request("GET", f"{API}/operations/{op_id}", key)
    raise RuntimeError("upload did not finish in time")


def main():
    key, creator = os.environ.get("ROBLOX_API_KEY"), os.environ.get("ROBLOX_CREATOR", "")
    if not key or not creator.startswith(("user:", "group:")):
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_CREATOR=user:<id> or group:<id> (see docstring).")
    only = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
    textures = json.loads((VFX / "textures" / "textures.json").read_text())
    ids_path = VFX / "asset_ids.json"
    ids = json.loads(ids_path.read_text()) if ids_path.exists() else {}
    for name, meta in sorted(textures.items()):
        if (only and name not in only) or (not only and isinstance(ids.get(name), int)):
            continue
        try:
            ids[name] = upload(VFX / "textures" / meta["file"], name, key, creator)
            print(f"[vfx] {name} -> {ids[name]}")
        except RuntimeError as error:
            print(f"[vfx] {name} FAILED: {error}")
        ids_path.write_text(json.dumps(ids, indent=2, sort_keys=True) + "\n")  # save progress each time
    print("Now run: python3 tools/vfx_pipeline/build_manifest.py")


if __name__ == "__main__":
    main()
