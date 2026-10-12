"""Prepare the Lower Layer storefront street as a Roblox import package.

Run this script with lower_layer_storefront_street_v1.blend open in Blender 5.2.
It writes a separate optimized blend plus GLB and FBX files. The source is never saved.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy


parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", default=str(Path.home() / "Projects/Enfleshed/assets/roblox/lower_layer_storefront_street_v1"))
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
output_dir = Path(args.output_dir)
output_dir.mkdir(parents=True, exist_ok=True)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0

visuals = bpy.data.collections.new("ROBLOX VISUALS - CanCollide false")
collisions = bpy.data.collections.new("ROBLOX COLLISION - Transparency 1")
scene.collection.children.link(visuals)
scene.collection.children.link(collisions)


def move_to_collection(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def source_group(obj):
    collection_names = {collection.name for collection in obj.users_collection}
    shop_groups = {
        "01 Hearth food counter": "VIS_Shop01_Hearth",
        "02 Ration and dry goods": "VIS_Shop02_Rations",
        "03 Tool repair workshop": "VIS_Shop03_Repair",
        "04 Lower dispensary": "VIS_Shop04_Dispensary",
        "05 Cloth and mending": "VIS_Shop05_Cloth",
        "06 Residential through passage": "VIS_Shop06_Court17",
    }
    for collection_name, group_name in shop_groups.items():
        if collection_name in collection_names:
            return group_name
    name = obj.name
    if name.startswith(("Court ", "Courtyard ", "Discovered route", "Catwalk ", "Alley ")):
        return "VIS_SecretRoute"
    if name.startswith(("Checkpoint ", "Guard inspection")):
        return "VIS_Checkpoint"
    if name.startswith(("Opposite ",)):
        return "VIS_OppositeStreet"
    if name.startswith(("Main street", "Uneven street")):
        return "VIS_StreetSurface"
    return "VIS_UpperBuildingsAndProps"


route_collection = bpy.data.collections.get("REVIEW ROUTE OVERLAYS - hide for beauty")
route_objects = set(route_collection.objects) if route_collection else set()

# Convert storefront lettering to mesh before removing all non-mesh review objects.
text_objects = [obj for obj in scene.objects if obj.type == "FONT" and obj not in route_objects]
if text_objects:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in text_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = text_objects[0]
    bpy.ops.object.convert(target="MESH")

groups = {}
mesh_objects = [obj for obj in scene.objects if obj.type == "MESH" and obj not in route_objects]
for obj in mesh_objects:
    groups.setdefault(source_group(obj), []).append(obj)

# Preserve world transforms before removing collection roots.
for obj in mesh_objects:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world

for obj in list(scene.objects):
    if obj in route_objects or obj.type != "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)


def join_visual_group(name, objects):
    existing = [obj for obj in objects if obj.name in bpy.data.objects]
    if not existing:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in existing:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = existing[0]
    # Converting applies the approved bevel modifiers while retaining material slots.
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    move_to_collection(joined, visuals)
    joined["RobloxRole"] = "Visual"
    joined["RecommendedCanCollide"] = False
    joined["RecommendedRenderFidelity"] = "Automatic"
    joined.data.materials.clear() if len(joined.data.polygons) == 0 else None
    return joined


visual_objects = []
for group_name in (
    "VIS_StreetSurface",
    "VIS_Shop01_Hearth",
    "VIS_Shop02_Rations",
    "VIS_Shop03_Repair",
    "VIS_Shop04_Dispensary",
    "VIS_Shop05_Cloth",
    "VIS_Shop06_Court17",
    "VIS_UpperBuildingsAndProps",
    "VIS_OppositeStreet",
    "VIS_Checkpoint",
    "VIS_SecretRoute",
):
    joined = join_visual_group(group_name, groups.get(group_name, []))
    if joined:
        visual_objects.append(joined)

collision_material = bpy.data.materials.new("COLLISION_PREVIEW_MAGENTA")
collision_material.diffuse_color = (1.0, 0.0, 0.7, 1.0)


def collider(name, location, dimensions, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move_to_collection(obj, collisions)
    obj.data.materials.append(collision_material)
    obj["RobloxRole"] = "Collision"
    obj["RecommendedTransparency"] = 1.0
    obj["RecommendedCanCollide"] = True
    obj["RecommendedCollisionFidelity"] = "Box"
    return obj


def stair_ramp(name, start, end, width, thickness=0.18):
    sx, sy, sz = start
    ex, ey, ez = end
    run = math.hypot(ex - sx, ey - sy)
    rise = ez - sz
    angle = math.atan2(rise, run)
    heading = math.atan2(ey - sy, ex - sx)
    length = math.hypot(run, rise)
    # Local X follows the stair run; rotate into heading, then pitch around local Y.
    obj = collider(
        name,
        ((sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2),
        (length, width, thickness),
        (0, -angle, heading),
    )
    return obj


# Primary walkable surfaces.
collider("COL_StreetFloor", (0, -3.65, -0.17), (31, 7.0, 0.34))
collider("COL_CourtyardFloor", (10.3, 7.0, -0.08), (7.0, 7.2, 0.22))
collider("COL_CatwalkFloor", (6.7, 8.45, 3.65), (9.2, 1.15, 0.19))
collider("COL_CourtyardLanding", (12.2, 8.5, 3.65), (2.4, 1.1, 0.19))

# Store floor, jamb and rear-wall collision. Court 17 keeps its rear exit open.
shop_centers = [-10.4, -6.2, -2.0, 3.2, 7.4, 11.6]
for index, x in enumerate(shop_centers, start=1):
    collider(f"COL_Shop{index:02d}_Floor", (x, 1.65, -0.08), (4.0, 3.6, 0.24))
    collider(f"COL_Shop{index:02d}_LeftPier", (x - 1.88, 1.65, 1.65), (0.30, 3.5, 3.3))
    collider(f"COL_Shop{index:02d}_RightPier", (x + 1.88, 1.65, 1.65), (0.30, 3.5, 3.3))
    collider(f"COL_Shop{index:02d}_Ceiling", (x, 1.6, 3.4), (4.0, 3.65, 0.24))
    if index < 6:
        collider(f"COL_Shop{index:02d}_BackWall", (x, 3.3, 1.65), (4.0, 0.28, 3.3))
    else:
        collider("COL_Court17_BackLeft", (x - 1.30, 3.3, 1.65), (1.15, 0.28, 3.3))
        collider("COL_Court17_BackRight", (x + 1.30, 3.3, 1.65), (1.15, 0.28, 3.3))
        collider("COL_Court17_BackLintel", (x, 3.3, 2.85), (1.50, 0.28, 0.9))

# Large static masses use inexpensive box collision.
for index, (x, height) in enumerate(((-10.4, 6.45), (-6.2, 7.75), (-2.0, 6.75), (3.2, 8.25), (7.4, 7.05), (11.6, 8.55)), start=1):
    collider(f"COL_NorthUpperMass{index:02d}", (x, 1.8, 3.35 + (height - 3.35) / 2), (4.0, 4.2, height - 3.35))
collider("COL_OppositeWall", (0, -8.0, 3.1), (31, 1.1, 6.2))
collider("COL_CheckpointTowerWest", (4.7, -7.0, 4.25), (2.1, 2.8, 8.5))
collider("COL_CheckpointTowerEast", (8.0, -7.0, 4.25), (2.1, 2.8, 8.5))
collider("COL_CheckpointBarrierLeft", (5.0, -4.05, 0.65), (3.0, 0.26, 1.3))
collider("COL_CheckpointBarrierRight", (8.25, -3.2, 0.65), (3.2, 0.26, 1.3), (0, 0, 0.10))
collider("COL_CourtEastWall", (14.0, 7.0, 3.1), (0.55, 7.2, 6.2))
collider("COL_CourtRearWall", (10.3, 10.65, 3.1), (7.9, 0.55, 6.2))
collider("COL_AlleyWestWall", (0.52, 4.3, 3.0), (0.42, 8.5, 6.0))
collider("COL_AlleyEastWall", (1.18, 6.3, 3.0), (0.35, 4.4, 6.0))

# Smooth invisible ramps sit over the visual stair treads for reliable Humanoid traversal.
stair_ramp("COL_CourtStairRamp", (13.15, 5.0, 0.22), (13.15, 8.1, 3.58), 1.05)
stair_ramp("COL_AlleyStairRamp", (1.85, 4.25, 0.22), (1.85, 8.25, 3.68), 1.10)

collision_objects = list(collisions.objects)
for obj in collision_objects:
    obj.hide_render = False

# Save the editable export copy before writing interchange formats.
scene["README"] = (
    "Roblox export copy. Import GLBs with Scale Unit Meter, World Forward Front, "
    "World Up Top, Insert Using Scene Position. Visuals non-colliding; collision package invisible and colliding."
)
bpy.context.preferences.filepaths.save_version = 0
export_blend = output_dir / "lower_layer_storefront_street_v1_roblox_export.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(export_blend))


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


select_only(visual_objects)
bpy.ops.export_scene.gltf(
    filepath=str(output_dir / "lower_layer_storefront_street_v1_visuals.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
bpy.ops.export_scene.fbx(
    filepath=str(output_dir / "lower_layer_storefront_street_v1_visuals.fbx"),
    use_selection=True,
    object_types={"MESH"},
    apply_scale_options="FBX_SCALE_UNITS",
    axis_forward="Z",
    axis_up="Y",
    bake_anim=False,
    add_leaf_bones=False,
)

select_only(collision_objects)
bpy.ops.export_scene.gltf(
    filepath=str(output_dir / "lower_layer_storefront_street_v1_collision.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
bpy.ops.export_scene.fbx(
    filepath=str(output_dir / "lower_layer_storefront_street_v1_collision.fbx"),
    use_selection=True,
    object_types={"MESH"},
    apply_scale_options="FBX_SCALE_UNITS",
    axis_forward="Z",
    axis_up="Y",
    bake_anim=False,
    add_leaf_bones=False,
)


def mesh_stats(objects):
    vertices = 0
    triangles = 0
    for obj in objects:
        vertices += len(obj.data.vertices)
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    return {"objects": len(objects), "vertices": vertices, "triangles": triangles}


def per_mesh_stats(objects):
    result = {}
    for obj in objects:
        obj.data.calc_loop_triangles()
        result[obj.name] = {
            "vertices": len(obj.data.vertices),
            "triangles": len(obj.data.loop_triangles),
        }
    return result


visual_mesh_stats = per_mesh_stats(visual_objects)
assert all(stats["triangles"] <= 20_000 for stats in visual_mesh_stats.values()), visual_mesh_stats


report = {
    "blender": bpy.app.version_string,
    "source": "lower_layer_storefront_street_v1.blend",
    "units": "meters",
    "recommended_studio_scale_unit": "Meter",
    "recommended_import": {
        "world_forward": "Front",
        "world_up": "Top",
        "insert_using_scene_position": True,
        "import_only_as_model": True,
    },
    "expected_scale_checks_studs": {
        "street_clear_width_approx": 25.0,
        "shop_door_clear_height_approx": 7.9,
        "shop_front_width_approx": 14.3,
    },
    "visuals": mesh_stats(visual_objects),
    "visual_meshes": visual_mesh_stats,
    "collision": mesh_stats(collision_objects),
    "visual_group_names": [obj.name for obj in visual_objects],
    "collision_object_names": [obj.name for obj in collision_objects],
    "source_scene_modified": False,
}
(output_dir / "export_manifest.json").write_text(json.dumps(report, indent=2))
print("ROBLOX EXPORT COMPLETE", report)
