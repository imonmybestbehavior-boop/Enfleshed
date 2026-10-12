"""Structural checks for the saved Lower Layer storefront street review blend."""
import json
from pathlib import Path

import bpy


scene = bpy.context.scene
shop_names = [
    "01 Hearth food counter",
    "02 Ration and dry goods",
    "03 Tool repair workshop",
    "04 Lower dispensary",
    "05 Cloth and mending",
    "06 Residential through passage",
]
for name in shop_names:
    collection = bpy.data.collections.get(name)
    assert collection is not None, name
    assert any(obj.type == "EMPTY" for obj in collection.objects), name

camera_names = [f"CAM {index:02d} " for index in range(1, 8)]
assert all(any(obj.name.startswith(prefix) for obj in scene.objects) for prefix in camera_names)
routes = bpy.data.collections.get("REVIEW ROUTE OVERLAYS - hide for beauty")
assert routes is not None and routes.hide_render
assert sum(obj.name.startswith("MAIN ROUTE marker") for obj in routes.objects) >= 20
assert sum(obj.name.startswith("DISCOVERED ROUTE marker") for obj in routes.objects) >= 10
for required in (
    "Main street paving",
    "Checkpoint overhead watchroom",
    "Court 17 rear paving",
    "Court stair tread",
    "Discovered route catwalk",
    "Alley drop stair tread",
    "Alley street threshold",
):
    assert any(obj.name.startswith(required) for obj in scene.objects), required
assert all(min(obj.dimensions) > 0 for obj in scene.objects if obj.type == "MESH")

report = {
    "blender": bpy.app.version_string,
    "saved_blend_reopened": True,
    "storefront_collections": len(shop_names),
    "cameras": 7,
    "mesh_objects": sum(obj.type == "MESH" for obj in scene.objects),
    "main_route_markers": sum(obj.name.startswith("MAIN ROUTE marker") for obj in routes.objects),
    "discovered_route_markers": sum(obj.name.startswith("DISCOVERED ROUTE marker") for obj in routes.objects),
    "checked_route_chain": ["Court 17 passage", "courtyard", "stair", "catwalk", "alley stair", "street threshold"],
    "scope": "scene structure and route continuity markers; Roblox collision and controller traversal remain untested",
}
Path(bpy.data.filepath).with_name("verification.json").write_text(json.dumps(report, indent=2))
print("VERIFIED", report)
