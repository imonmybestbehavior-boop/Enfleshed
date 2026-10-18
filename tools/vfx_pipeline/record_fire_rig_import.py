"""Record successful imported-rig checks without overstating the full fire effect."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"assets/vfx/studies/3d_fire_v1"

def payload(filename):
    receipt = json.loads((OUT/filename).read_text())
    assert not receipt.get("isError"), filename
    return json.loads(next(block["text"] for block in receipt["content"] if block["type"] == "text"))

inspection = payload("studio_rig_inspection.json")["Rigs"]
rig = next(entry for entry in inspection if entry["Path"] == "Workspace.single_flame_transport.Flame_00")
fetch = payload("studio_mesh_load_check.json")
assert fetch["MeshFetchOK"] and all(entry["Status"] == "Success" for entry in fetch["Statuses"])
animation = payload("studio_import_animation_verify.json")
assert animation["After"]["FrameUpdates"] > animation["Before"]["FrameUpdates"]
assert animation["MeshId"] == rig["MeshId"]
record = {"date":"2026-10-17","status":"single_imported_skin_deformation_verified",
          "mesh_id":rig["MeshId"],"texture_id":rig["TextureID"],"bones":len(rig["Bones"]),
          "imported_size":rig["Size"],"clone_scale":.01,
          "imported_export_sha256":hashlib.sha256((OUT/"imported_first_export.fbx").read_bytes()).hexdigest(),
          "visual_evidence":"studio_client_deformed_0.jpg","animation_evidence":"studio_import_animation_verify.json",
          "observed_before":animation["Before"],"observed_after":animation["After"],
          "original_import_modified":False,"runtime_integrated":False,
          "full_effect_accepted":False,"user_style_feedback":"Colors and style good; does not look like fire",
          "limitations":["CFrame pose probe excludes Blender per-bone scale","New export scale needs confirmation on next import",
                         "No full-body fire test or performance verification","Geometry needs another art pass"]}
(OUT/"imported_rig.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
print("Recorded real imported IDs, asset fetch, visible deformation and pose updates; full effect remains unaccepted")
