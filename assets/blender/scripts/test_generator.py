import bpy
import os

# Delete everything in the default Blender scene.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# Create a cube.
bpy.ops.mesh.primitive_cube_add(
    location=(0, 0, 1)
)

cube = bpy.context.active_object
cube.name = "ENV_GeneratorTest_Block"

# Make it rectangular instead of a default cube.
cube.scale = (4, 2, 1)

# Apply the scale so Blender treats this as the actual mesh size.
bpy.ops.object.transform_apply(
    location=False,
    rotation=False,
    scale=True
)

# Create a basic material.
material = bpy.data.materials.new(
    name="MAT_TestStone"
)

material.diffuse_color = (
    0.18,
    0.20,
    0.22,
    1.0
)

cube.data.materials.append(material)

# Bevel the edges slightly.
bevel = cube.modifiers.new(
    name="EdgeBevel",
    type='BEVEL'
)

bevel.width = 0.12
bevel.segments = 2

# Save the generated Blender file.
output_path = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/GeneratorTest.blend"
)

bpy.ops.wm.save_as_mainfile(filepath=output_path)

print("")
print("==========================================")
print("ENFLESHED GENERATOR TEST COMPLETE")
print(output_path)
print("==========================================")
