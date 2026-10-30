"""Record actual import and isolated client review evidence without claiming gameplay parity."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/vfx/studies/3d_fire_v4"
def payload(name):
    receipt=json.loads((OUT/name).read_text())
    assert not receipt.get("isError"),name
    return json.loads(next(x["text"] for x in receipt["content"] if x["type"]=="text"))
imported=payload("studio_import_inspection.json")["ImportedMeshes"]
assert len(imported)==1 and imported[0]["Bones"]==73
images=payload("studio_images_loaded.json")
assert images["Loaded"]==24 and all(x["Loaded"] for x in images["Frames"])
a,b=payload("side_01_state.json"),payload("side_13_state.json")
assert (a["Frame"],a["TextureFrame"])==(1,1)
assert (b["Frame"],b["TextureFrame"])==(13,7)
for name in ["studio_side_01_0.jpg","studio_side_13_0.jpg","studio_front_13_0.jpg","studio_rear_13_0.jpg","studio_review_final_0.jpg"]:
    assert (OUT/name).exists(),name
mapping=json.loads((OUT/"bind_mapping.json").read_text())
record={"status":"imported_and_isolated_client_preview_verified", "date":"2026-10-17",
    "mesh_id":imported[0]["MeshId"],"import_path":imported[0]["Path"],"bones":73,
    "size":imported[0]["Size"],"source_fbx_sha256":hashlib.sha256((OUT/"connected_fireball.fbx").read_bytes()).hexdigest(),
    "maximum_bind_position_error":mapping["max_bind_error"],"loaded_image_frames":24,
    "playback":"One mesh, 72 bone transforms at 24 FPS and 24 preconfigured surface instances switched at 12 FPS",
    "visual_review":"Controlled side frames 1 and 13 show different core contours; front and rear views retain filled head and tail alpha erosion",
    "evidence":["studio_side_01_0.jpg","studio_side_13_0.jpg","studio_front_13_0.jpg","studio_rear_13_0.jpg","studio_review_final_0.jpg"],
    "original_import_modified":False,"gameplay_renderer_modified":False,"preview_left_playing":True,
    "limitations":["Verification is an isolated client ViewportFrame, not live combat lighting or projectile integration",
        "PreloadAsync reports Failure although all 24 ImageLabels load and sampled materials visibly render",
        "Blank background 3D captures resolved after the user brought Studio to the foreground; not evidence of a mesh or surface-swap bug",
        "Full GPU/CPU performance, texture memory, published-place permissions and multiple simultaneous effects remain unverified",
        "Transparent rear has visible stippling/overlap at close range; user acceptance of Studio result pending"]}
(OUT/"imported_review.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
published=json.loads((OUT/"published_assets.json").read_text())
published["status"]="All 24 images load; sampled surface frames visibly verified in isolated client preview"
published["verification_scope"]="ImageLabel load for all frames; controlled 3D surface samples and front/rear review; no gameplay integration"
published["preload_status"]="Failure (retained as conflicting diagnostic evidence)"
(OUT/"published_assets.json").write_text(json.dumps(published,indent=2)+"\n",encoding="utf-8")
manifest=json.loads((OUT/"manifest.json").read_text())
manifest["status"]="Blender appearance approved; imported mesh and isolated client playback verified; gameplay and profiling pending"
manifest["limitations"]=["No gameplay renderer integration, combat lighting or performance verification",
    "Direct ColorMap writes remain plugin-restricted; isolated preview switches prepared surface instances",
    "Rear alpha edges overlap/stipple in close views","No detached fragments yet"]
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("Recorded verified import, bind mapping, image loading and sampled client visuals; gameplay remains pending")
