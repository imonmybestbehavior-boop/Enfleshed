"""Verify re-imported Roblox GLB packages inside a clean Blender scene."""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


parser = argparse.ArgumentParser()
parser.add_argument("--package-dir", required=True)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
package = Path(args.package_dir)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(package / "lower_layer_storefront_street_v1_visuals.glb"))
visuals = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
assert len(visuals) == 11, len(visuals)
assert all(obj.name.startswith("VIS_") for obj in visuals)
for obj in visuals:
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles) <= 20_000, (obj.name, len(obj.data.loop_triangles))

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.import_scene.gltf(filepath=str(package / "lower_layer_storefront_street_v1_collision.glb"))
colliders = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
assert len(colliders) >= 40, len(colliders)
assert all(obj.name.startswith("COL_") for obj in colliders)
assert all(min(obj.dimensions) > 0 for obj in visuals + colliders)

all_objects = visuals + colliders
world_corners = [obj.matrix_world @ Vector(corner) for obj in all_objects for corner in obj.bound_box]
mins = [min(corner[axis] for corner in world_corners) for axis in range(3)]
maxs = [max(corner[axis] for corner in world_corners) for axis in range(3)]
dimensions = [maxs[axis] - mins[axis] for axis in range(3)]
assert 28.0 <= dimensions[0] <= 34.0, dimensions
assert 16.0 <= dimensions[1] <= 22.0, dimensions
assert 9.0 <= dimensions[2] <= 14.0, dimensions

result = {
    "blender": bpy.app.version_string,
    "visual_glb_reimported": True,
    "collision_glb_reimported": True,
    "visual_meshes": len(visuals),
    "all_visual_meshes_at_or_below_20000_triangles": True,
    "collision_meshes": len(colliders),
    "combined_bounds_meters": {"x": dimensions[0], "y": dimensions[1], "z": dimensions[2]},
    "positive_dimensions": True,
    "scope": "file integrity, names and metric bounds; Studio import and Humanoid traversal remain untested",
}
(package / "reimport_verification.json").write_text(json.dumps(result, indent=2))
print("REIMPORT VERIFIED", result)
