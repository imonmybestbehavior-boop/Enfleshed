import bpy
import math
import os

OUT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/AncientThreshold_V2.blend"
)

# Clear scene
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def make_mat(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True

    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness

    return mat

ANCIENT = make_mat(
    "MAT_AncientUnknownMetal",
    (0.08, 0.095, 0.11),
    0.82,
    0.38
)

RECESS = make_mat(
    "MAT_AncientRecess",
    (0.015, 0.02, 0.025),
    0.55,
    0.5
)

HUMAN_METAL = make_mat(
    "MAT_HumanIron",
    (0.18, 0.12, 0.09),
    0.6,
    0.7
)

HUMAN = make_mat(
    "MAT_HumanReference",
    (0.7, 0.5, 0.25),
    0.0,
    0.8
)

def cube(name, loc, dims, mat, rot=(0,0,0), bevel=0):
    bpy.ops.mesh.primitive_cube_add(
        location=loc,
        rotation=rot
    )

    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = dims

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True
    )

    obj.data.materials.append(mat)

    if bevel:
        mod = obj.modifiers.new("EdgeBevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2

    return obj


# ============================================================
# SCALE
#
# Human = 6 units
# Clear opening = about 320 units high
# Clear opening = about 160 units wide
#
# More than 50 human heights of clearance.
# ============================================================

CLEAR_HEIGHT = 320
CLEAR_WIDTH = 160

PYLON_W = 36
PYLON_D = 52

LEFT = -(CLEAR_WIDTH / 2 + PYLON_W / 2)
RIGHT = -LEFT


# Huge monolithic side structures
for side, x in [("L", LEFT), ("R", RIGHT)]:

    cube(
        f"Ancient_{side}_MainPylon",
        (x, 0, CLEAR_HEIGHT / 2),
        (PYLON_W, PYLON_D, CLEAR_HEIGHT),
        ANCIENT,
        bevel=3
    )

    # Outer mass: intentionally absurd
    outer_x = x + (-28 if x < 0 else 28)

    cube(
        f"Ancient_{side}_OuterMass",
        (outer_x, 8, 135),
        (50, 70, 270),
        ANCIENT,
        bevel=4
    )

    # Long incomprehensible recessed channel
    inner_face_x = x + (PYLON_W / 2 + 0.5 if x < 0 else -(PYLON_W / 2 + 0.5))

    cube(
        f"Ancient_{side}_VerticalRecess",
        (inner_face_x, -PYLON_D / 2 - 0.4, 165),
        (3, 0.8, 220),
        RECESS,
        bevel=0.3
    )


# Huge crown masses
cube(
    "Ancient_Crown_Main",
    (0, 0, 334),
    (235, 58, 38),
    ANCIENT,
    bevel=5
)

cube(
    "Ancient_Crown_Upper",
    (-12, 7, 369),
    (275, 48, 30),
    ANCIENT,
    rot=(0, math.radians(-2), 0),
    bevel=5
)


# Irregular giant shoulder forms
cube(
    "Ancient_Shoulder_L",
    (-78, -3, 286),
    (95, 50, 30),
    ANCIENT,
    rot=(0, math.radians(-30), 0),
    bevel=3
)

cube(
    "Ancient_Shoulder_R",
    (72, -3, 294),
    (105, 50, 28),
    ANCIENT,
    rot=(0, math.radians(25), 0),
    bevel=3
)


# Inner alien ribs — deliberately not symmetrical
rib_data = [
    (-68, 80, 10, 150, -5),
    (-58, 185, 9, 135, -13),
    (-42, 278, 10, 100, -31),

    (66, 72, 11, 145, 4),
    (54, 188, 8, 140, 16),
    (38, 282, 12, 105, 34),
]

for i, (x, z, w, h, ang) in enumerate(rib_data):
    cube(
        f"Ancient_InnerRib_{i}",
        (x, -29, z),
        (w, 6, h),
        ANCIENT,
        rot=(0, math.radians(ang), 0),
        bevel=1.2
    )


# Strange inner crown instead of normal semicircular arch
cube(
    "Ancient_InnerCrown_A",
    (-22, -29, 304),
    (105, 6, 13),
    ANCIENT,
    rot=(0, math.radians(-7), 0),
    bevel=1.5
)

cube(
    "Ancient_InnerCrown_B",
    (31, -29, 317),
    (82, 6, 11),
    ANCIENT,
    rot=(0, math.radians(12), 0),
    bevel=1.4
)


# Massive foreign markings / slots
for side, x in [(-1, LEFT), (1, RIGHT)]:
    for i, z in enumerate([45, 95, 155, 225, 280]):

        cube(
            f"Ancient_Marking_{side}_{i}",
            (
                x + (-18.6 if side == -1 else 18.6),
                -26.4,
                z
            ),
            (14 + i * 2, 0.7, 3.2),
            RECESS,
            rot=(0, math.radians(side * (8 + i * 4)), 0),
            bevel=0.4
        )


# ============================================================
# TINY HUMAN CATWALK
#
# This exists specifically to show scale.
# ============================================================

CAT_Z = 62

cube(
    "Human_Catwalk",
    (0, -38, CAT_Z),
    (80, 6, 0.8),
    HUMAN_METAL,
    bevel=0.1
)

for y in (-40.8, -35.2):
    cube(
        f"Human_CatwalkRail_{y}",
        (0, y, CAT_Z + 2),
        (80, 0.22, 0.22),
        HUMAN_METAL,
        bevel=0.03
    )


# Human scale figures
for i, x in enumerate([-27, -10, 9, 28]):
    cube(
        f"REF_Human_{i}",
        (x, -38, CAT_Z + 3.4),
        (1.5, 0.9, 6),
        HUMAN,
        bevel=0.25
    )

# Human on ground
cube(
    "REF_Human_Ground",
    (0, -40, 3),
    (1.5, 0.9, 6),
    HUMAN,
    bevel=0.25
)


# Giant floor
cube(
    "REF_Floor",
    (0, 0, -2),
    (320, 150, 4),
    RECESS
)


bpy.context.scene.world.color = (0.01, 0.012, 0.016)

bpy.ops.wm.save_as_mainfile(filepath=OUT)

print("")
print("===========================================")
print("ANCIENT THRESHOLD V2 GENERATED")
print(OUT)
print("Clear height:", CLEAR_HEIGHT)
print("Clear width:", CLEAR_WIDTH)
print("Human height: 6")
print("===========================================")
