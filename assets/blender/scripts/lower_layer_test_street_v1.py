import bpy
import math
import os
import random

from mathutils import Vector

random.seed(441)

OUT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/lower_layer_test_street_v1.blend"
)

# ============================================================
# ENFLESHED — LOWER LAYER TEST STREET V1
#
# GOAL:
# Test whether the modular architectural language works when
# assembled into a dense, claustrophobic Lower Layer street.
#
# This is NOT intended to be a final game-ready city section.
# It is an architectural composition / scale / material test.
# ============================================================


# ============================================================
# CLEAN SCENE
# ============================================================

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


# ============================================================
# COLLECTIONS
# ============================================================

def make_collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


GROUND = make_collection("01_GROUND")
LEFT = make_collection("02_LEFT_BUILDINGS")
RIGHT = make_collection("03_RIGHT_BUILDINGS")
OVERHEAD = make_collection("04_OVERHEAD_CITY")
TRAVERSAL = make_collection("05_TRAVERSAL")
DETAILS = make_collection("06_DETAILS")
DAMAGE = make_collection("07_DAMAGE")
ANCIENT_COL = make_collection("08_ANCIENT_STRUCTURE")
DISPLAY = make_collection("99_DISPLAY")


# ============================================================
# MATERIALS
# ============================================================

def make_material(name, color, metallic=0.0, roughness=0.8):
    m = bpy.data.materials.new(name=name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True

    bsdf = m.node_tree.nodes.get("Principled BSDF")

    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness

    return m


STONE = make_material(
    "Aged_Masonry",
    (0.17, 0.145, 0.12),
    0.0,
    0.92
)

PLASTER = make_material(
    "Dirty_Plaster",
    (0.30, 0.255, 0.205),
    0.0,
    0.94
)

DARK_PLASTER = make_material(
    "Old_Dark_Plaster",
    (0.18, 0.16, 0.14),
    0.0,
    0.95
)

IRON = make_material(
    "Blackened_Iron",
    (0.045, 0.043, 0.040),
    0.75,
    0.56
)

PATCH = make_material(
    "Old_Patch_Metal",
    (0.12, 0.10, 0.08),
    0.60,
    0.70
)

RED = make_material(
    "Faded_Military_Red",
    (0.25, 0.032, 0.022),
    0.15,
    0.78
)

WOOD = make_material(
    "Aged_Dark_Timber",
    (0.105, 0.060, 0.032),
    0.0,
    0.90
)

ANCIENT = make_material(
    "Ancient_Structure",
    (0.020, 0.022, 0.025),
    0.32,
    0.50
)

GROUND_MAT = make_material(
    "Street_Stone",
    (0.085, 0.078, 0.068),
    0.0,
    0.96
)

DIRT = make_material(
    "Accumulated_Grime",
    (0.055, 0.045, 0.035),
    0.0,
    1.0
)

LIGHT_MAT = make_material(
    "Lamp_Glass",
    (0.52, 0.31, 0.10),
    0.0,
    0.35
)


# ============================================================
# HELPERS
# ============================================================

def move_to_collection(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)

    collection.objects.link(obj)


def add_box(
    name,
    location,
    size,
    collection,
    material,
    bevel=0.08,
    rotation=(0, 0, 0)
):
    bpy.ops.mesh.primitive_cube_add(
        location=location,
        rotation=rotation
    )

    obj = bpy.context.object
    obj.name = name

    obj.scale = (
        size[0] / 2,
        size[1] / 2,
        size[2] / 2
    )

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True
    )

    move_to_collection(obj, collection)

    if material:
        obj.data.materials.append(material)

    if bevel > 0:
        mod = obj.modifiers.new(
            name="EdgeWear",
            type="BEVEL"
        )
        mod.width = bevel
        mod.segments = 2

    return obj


def add_cylinder(
    name,
    location,
    radius,
    depth,
    collection,
    material,
    vertices=12,
    rotation=(0, 0, 0)
):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation
    )

    obj = bpy.context.object
    obj.name = name

    move_to_collection(obj, collection)

    if material:
        obj.data.materials.append(material)

    return obj


# ============================================================
# BASIC BUILDING MASS
# ============================================================

def building_mass(
    name,
    x,
    y,
    z,
    width,
    depth,
    height,
    collection,
    material=STONE,
    rotation=0
):
    return add_box(
        name,
        (x, y, z + height / 2),
        (width, depth, height),
        collection,
        material,
        bevel=0.16,
        rotation=(0, 0, math.radians(rotation))
    )


# ============================================================
# FACADE FRAME
# ============================================================

def facade_frame(
    name,
    x,
    y,
    z,
    width,
    collection,
    facing=1
):
    # facing:
    #  1 = facade points toward +Y
    # -1 = facade points toward -Y

    face_y = y + facing * 0.12

    add_box(
        name + "_BOTTOM",
        (x, face_y, z + 1.0),
        (width, 0.40, 2.0),
        collection,
        IRON,
        0.04
    )

    add_box(
        name + "_TOP",
        (x, face_y, z + 15.0),
        (width, 0.40, 1.0),
        collection,
        IRON,
        0.04
    )

    for sx in (-1, 1):
        add_box(
            name + "_SIDE",
            (
                x + sx * (width / 2 - 0.35),
                face_y,
                z + 8.0
            ),
            (0.55, 0.40, 15.0),
            collection,
            IRON,
            0.04
        )


# ============================================================
# WINDOWS
# ============================================================

def window(
    name,
    x,
    y,
    z,
    collection,
    facing=1,
    width=4.5,
    height=3.8,
    barred=True
):
    fy = y + facing * 0.18

    # dark recess
    add_box(
        name + "_RECESS",
        (x, fy, z),
        (width, 0.20, height),
        collection,
        ANCIENT,
        0.02
    )

    # frame
    for sx in (-1, 1):
        add_box(
            name + "_FRAME_SIDE",
            (
                x + sx * (width / 2 + 0.16),
                fy + facing * 0.08,
                z
            ),
            (0.28, 0.25, height + 0.5),
            collection,
            IRON,
            0.02
        )

    for sz in (-1, 1):
        add_box(
            name + "_FRAME_H",
            (
                x,
                fy + facing * 0.08,
                z + sz * (height / 2 + 0.16)
            ),
            (width + 0.55, 0.25, 0.28),
            collection,
            IRON,
            0.02
        )

    if barred:
        for dx in (-1.35, 0, 1.35):
            add_box(
                name + "_BAR",
                (
                    x + dx,
                    fy + facing * 0.20,
                    z
                ),
                (0.13, 0.13, height),
                collection,
                IRON,
                0.01
            )


# ============================================================
# DOOR
# ============================================================

def door(
    name,
    x,
    y,
    z,
    collection,
    facing=1,
    width=5.5,
    height=9.0
):
    fy = y + facing * 0.22

    add_box(
        name + "_DOOR",
        (
            x,
            fy,
            z + height / 2
        ),
        (width, 0.32, height),
        collection,
        WOOD,
        0.04
    )

    for sx in (-1, 1):
        add_box(
            name + "_FRAME_SIDE",
            (
                x + sx * (width / 2 + 0.32),
                fy + facing * 0.12,
                z + height / 2
            ),
            (0.55, 0.55, height + 0.8),
            collection,
            IRON,
            0.04
        )

    add_box(
        name + "_FRAME_TOP",
        (
            x,
            fy + facing * 0.12,
            z + height + 0.25
        ),
        (width + 1.1, 0.55, 0.55),
        collection,
        IRON,
        0.04
    )


# ============================================================
# PATCH
# ============================================================

def patch(
    name,
    x,
    y,
    z,
    width,
    height,
    collection,
    facing=1,
    red=False,
    rotation=0
):
    add_box(
        name,
        (
            x,
            y + facing * 0.24,
            z
        ),
        (width, 0.18, height),
        collection,
        RED if red else PATCH,
        0.025,
        rotation=(0, math.radians(rotation), 0)
    )


# ============================================================
# BALCONY
# ============================================================

def balcony(
    name,
    x,
    y,
    z,
    width,
    collection,
    facing=1
):
    outward = facing * 2.3

    add_box(
        name + "_DECK",
        (
            x,
            y + outward,
            z
        ),
        (width, 4.5, 0.55),
        collection,
        IRON,
        0.04
    )

    rail_y = y + facing * 4.35

    add_box(
        name + "_RAIL_TOP",
        (
            x,
            rail_y,
            z + 2.2
        ),
        (width, 0.18, 0.18),
        collection,
        IRON,
        0.01
    )

    for dx in range(
        int(-width / 2 + 1),
        int(width / 2),
        3
    ):
        add_box(
            name + "_RAIL_POST",
            (
                x + dx,
                rail_y,
                z + 1.1
            ),
            (0.14, 0.14, 2.2),
            collection,
            IRON,
            0.01
        )

    # diagonal supports
    for sx in (-1, 1):
        add_box(
            name + "_SUPPORT",
            (
                x + sx * (width / 2 - 1.2),
                y + facing * 1.6,
                z - 2.0
            ),
            (0.38, 0.38, 5.3),
            collection,
            IRON,
            0.03,
            rotation=(
                math.radians(facing * 26),
                0,
                math.radians(sx * 5)
            )
        )


# ============================================================
# PIPE
# ============================================================

def vertical_pipe(
    name,
    x,
    y,
    z,
    height,
    collection,
    facing=1,
    radius=0.45
):
    fy = y + facing * 0.45

    add_cylinder(
        name,
        (x, fy, z + height / 2),
        radius,
        height,
        collection,
        IRON,
        12
    )

    for pz in (
        z + 2,
        z + height / 2,
        z + height - 2
    ):
        add_cylinder(
            name + "_CLAMP",
            (x, fy, pz),
            radius + 0.11,
            0.28,
            collection,
            PATCH,
            12
        )


# ============================================================
# BUILDING FACADE DETAIL
# ============================================================

def detail_building(
    prefix,
    x,
    street_edge_y,
    base_z,
    width,
    floors,
    collection,
    facing
):
    total_height = floors * 16

    facade_frame(
        prefix + "_FRAME",
        x,
        street_edge_y,
        base_z,
        width,
        collection,
        facing
    )

    for floor in range(floors):
        floor_z = base_z + floor * 16

        # horizontal generation seam
        if floor > 0:
            add_box(
                prefix + "_GENERATION_SEAM",
                (
                    x,
                    street_edge_y + facing * 0.20,
                    floor_z
                ),
                (width, 0.30, 0.45),
                collection,
                IRON if floor % 2 else PATCH,
                0.025
            )

        # intentionally non-uniform windows
        if width >= 14:
            offsets = (-width * 0.24, width * 0.22)
        else:
            offsets = (0,)

        for i, ox in enumerate(offsets):
            if floor == 0 and i == 0:
                continue

            window(
                prefix + "_WINDOW",
                x + ox,
                street_edge_y,
                floor_z + 8,
                collection,
                facing,
                width=3.8 + ((floor + i) % 2) * 0.7,
                height=3.4,
                barred=(floor < 2)
            )

    door(
        prefix + "_DOOR",
        x - width * 0.20,
        street_edge_y,
        base_z,
        collection,
        facing
    )

    # random historical patches
    patch(
        prefix + "_PATCH_A",
        x + width * 0.27,
        street_edge_y,
        base_z + 4.0,
        3.2,
        3.8,
        collection,
        facing,
        False,
        -4
    )

    if floors >= 2:
        patch(
            prefix + "_PATCH_B",
            x - width * 0.30,
            street_edge_y,
            base_z + 20,
            2.5,
            4.5,
            collection,
            facing,
            True,
            3
        )

    if floors >= 2:
        balcony(
            prefix + "_BALCONY",
            x + width * 0.12,
            street_edge_y,
            base_z + 16,
            min(width * 0.55, 10),
            collection,
            facing
        )

    vertical_pipe(
        prefix + "_PIPE",
        x + width * 0.39,
        street_edge_y,
        base_z,
        total_height,
        collection,
        facing,
        0.38
    )


# ============================================================
# STREET
# ============================================================

STREET_LENGTH = 145
STREET_WIDTH = 16

add_box(
    "MAIN_STREET",
    (0, 0, -0.45),
    (STREET_LENGTH, STREET_WIDTH, 0.9),
    GROUND,
    GROUND_MAT,
    0.04
)

# slightly irregular side drainage
for side in (-1, 1):
    add_box(
        "STREET_DRAIN",
        (
            0,
            side * (STREET_WIDTH / 2 - 0.8),
            -0.15
        ),
        (STREET_LENGTH, 1.1, 0.28),
        GROUND,
        IRON,
        0.02
    )


# ============================================================
# LEFT-SIDE BUILDINGS
# ============================================================

left_specs = [
    (-60, 18, 3, 14),
    (-42, 17, 4, 15),
    (-24, 19, 3, 17),
    (-4, 20, 4, 18),
    (17, 18, 3, 15),
    (36, 20, 4, 18),
    (57, 22, 5, 20),
]

LEFT_EDGE = 9.0

for i, (x, width, floors, depth) in enumerate(left_specs):
    height = floors * 16

    building_mass(
        "LEFT_BUILDING_" + str(i),
        x,
        LEFT_EDGE + depth / 2,
        0,
        width,
        depth,
        height,
        LEFT,
        STONE if i % 3 else DARK_PLASTER,
        rotation=random.uniform(-1.0, 1.0)
    )

    detail_building(
        "LEFT_" + str(i),
        x,
        LEFT_EDGE,
        0,
        width,
        floors,
        LEFT,
        -1
    )

    # upper generational addition
    if i in (1, 3, 4, 6):
        add_width = width * random.uniform(0.65, 0.9)

        building_mass(
            "LEFT_UPPER_ADDITION_" + str(i),
            x + random.uniform(-2, 2),
            LEFT_EDGE + depth * 0.55,
            height,
            add_width,
            depth * 0.78,
            random.choice((12, 16, 20)),
            LEFT,
            PLASTER if i % 2 else PATCH
        )


# ============================================================
# RIGHT-SIDE BUILDINGS
# ============================================================

right_specs = [
    (-61, 17, 4, 16),
    (-43, 19, 3, 17),
    (-23, 18, 4, 16),
    (-3, 20, 5, 18),
    (18, 19, 4, 17),
    (38, 21, 3, 19),
    (60, 20, 5, 18),
]

RIGHT_EDGE = -9.0

for i, (x, width, floors, depth) in enumerate(right_specs):
    height = floors * 16

    building_mass(
        "RIGHT_BUILDING_" + str(i),
        x,
        RIGHT_EDGE - depth / 2,
        0,
        width,
        depth,
        height,
        RIGHT,
        STONE if i % 2 else PLASTER,
        rotation=random.uniform(-1.0, 1.0)
    )

    detail_building(
        "RIGHT_" + str(i),
        x,
        RIGHT_EDGE,
        0,
        width,
        floors,
        RIGHT,
        1
    )

    if i in (0, 2, 3, 5):
        building_mass(
            "RIGHT_UPPER_ADDITION_" + str(i),
            x + random.uniform(-2, 2),
            RIGHT_EDGE - depth * 0.55,
            height,
            width * random.uniform(0.65, 0.9),
            depth * 0.75,
            random.choice((12, 16, 22)),
            RIGHT,
            DARK_PLASTER if i % 2 else PLASTER
        )


# ============================================================
# NARROW SIDE ALLEY
# ============================================================

# Branches from the main street around x = -22

ALLEY_X = -22

add_box(
    "SIDE_ALLEY_FLOOR",
    (
        ALLEY_X,
        21,
        -0.40
    ),
    (7, 27, 0.8),
    GROUND,
    GROUND_MAT,
    0.03
)

# alley side masses
building_mass(
    "ALLEY_LEFT_MASS",
    ALLEY_X - 6,
    22,
    0,
    5,
    25,
    46,
    LEFT,
    DARK_PLASTER
)

building_mass(
    "ALLEY_RIGHT_MASS",
    ALLEY_X + 6,
    23,
    0,
    5,
    27,
    54,
    LEFT,
    STONE
)

# tiny overhead room across alley
building_mass(
    "ALLEY_OVERHEAD_ROOM",
    ALLEY_X,
    25,
    22,
    15,
    9,
    11,
    OVERHEAD,
    PLASTER
)

add_box(
    "ALLEY_OVERHEAD_BOTTOM",
    (ALLEY_X, 25, 21.7),
    (16, 10, 0.7),
    OVERHEAD,
    IRON,
    0.04
)


# ============================================================
# OVER-STREET CONSTRUCTION
# ============================================================

# Major bridge/room that closes the skyline
building_mass(
    "OVER_STREET_HABITATION",
    9,
    0,
    28,
    22,
    24,
    12,
    OVERHEAD,
    DARK_PLASTER
)

add_box(
    "OVER_STREET_UNDERSIDE",
    (9, 0, 28),
    (23, 25, 0.75),
    OVERHEAD,
    IRON,
    0.04
)

# windows on both visible sides
for wx in (4, 10, 16):
    window(
        "OVERSTREET_WINDOW",
        wx,
        -12.1,
        34,
        OVERHEAD,
        -1,
        3.4,
        3.0,
        True
    )


# ============================================================
# SECOND OVERHEAD BRIDGE
# ============================================================

add_box(
    "UPPER_BRIDGE_DECK",
    (-48, 0, 21),
    (12, 23, 1.0),
    TRAVERSAL,
    IRON,
    0.05
)

for sy in (-1, 1):
    add_box(
        "UPPER_BRIDGE_RAIL",
        (
            -48,
            sy * 10.8,
            23
        ),
        (12, 0.20, 0.20),
        TRAVERSAL,
        IRON,
        0.015
    )

    for x in (-52, -48, -44):
        add_box(
            "UPPER_BRIDGE_POST",
            (
                x,
                sy * 10.8,
                22
            ),
            (0.16, 0.16, 2.0),
            TRAVERSAL,
            IRON,
            0.01
        )


# ============================================================
# ELEVATED CATWALK
# ============================================================

add_box(
    "LONG_CATWALK",
    (39, -12, 18),
    (37, 4.5, 0.65),
    TRAVERSAL,
    IRON,
    0.04
)

for sy in (-1, 1):
    rail_y = -12 + sy * 2.1

    add_box(
        "CATWALK_RAIL",
        (39, rail_y, 20),
        (37, 0.18, 0.18),
        TRAVERSAL,
        IRON,
        0.01
    )

    for x in range(23, 58, 4):
        add_box(
            "CATWALK_POST",
            (x, rail_y, 19),
            (0.14, 0.14, 2),
            TRAVERSAL,
            IRON,
            0.01
        )


# ============================================================
# STAIRS TO CATWALK
# ============================================================

for i in range(14):
    add_box(
        "CATWALK_STAIR_" + str(i),
        (
            20,
            -10 - i * 0.7,
            i * 0.62
        ),
        (6, 1.1, 0.6),
        TRAVERSAL,
        STONE,
        0.035
    )


# ============================================================
# SMALL COURTYARD / COMPRESSION BREAK
# ============================================================

# Slight widening near far end.
add_box(
    "SMALL_COURTYARD",
    (67, 0, -0.42),
    (18, 26, 0.85),
    GROUND,
    GROUND_MAT,
    0.04
)

# partial wall keeps it from becoming an open plaza
add_box(
    "COURTYARD_PARTITION",
    (70, 9, 5),
    (11, 2, 10),
    LEFT,
    STONE,
    0.14
)

add_box(
    "COURTYARD_IRON_REPAIR",
    (70, 7.9, 4.5),
    (5, 0.30, 5),
    LEFT,
    PATCH,
    0.035
)


# ============================================================
# BREACHED WALL
# ============================================================

BREACH_X = 52
BREACH_Y = 9

# side masses around a 6-stud opening
add_box(
    "BREACH_LEFT",
    (BREACH_X - 5, BREACH_Y, 7),
    (4, 2, 14),
    DAMAGE,
    STONE,
    0.13
)

add_box(
    "BREACH_RIGHT",
    (BREACH_X + 5, BREACH_Y, 7),
    (4, 2, 14),
    DAMAGE,
    STONE,
    0.13
)

add_box(
    "BREACH_TOP",
    (BREACH_X, BREACH_Y, 12.7),
    (7, 2, 3.0),
    DAMAGE,
    STONE,
    0.12,
    rotation=(0, math.radians(3), 0)
)

for i in range(5):
    add_box(
        "BREACH_REBAR_" + str(i),
        (
            BREACH_X + random.uniform(-3, 3),
            BREACH_Y - 1.1,
            random.uniform(5, 10)
        ),
        (0.13, 0.13, random.uniform(2, 4)),
        DAMAGE,
        IRON,
        0.01,
        rotation=(
            math.radians(random.uniform(-8, 8)),
            math.radians(random.uniform(-14, 14)),
            0
        )
    )


# ============================================================
# DEBRIS
# ============================================================

for i in range(14):
    sx = random.uniform(0.5, 1.8)
    sy = random.uniform(0.5, 1.5)
    sz = random.uniform(0.4, 1.3)

    add_box(
        "RUBBLE_" + str(i),
        (
            BREACH_X + random.uniform(-5, 5),
            random.uniform(4.5, 8),
            sz / 2
        ),
        (sx, sy, sz),
        DAMAGE,
        STONE if i % 4 else PATCH,
        0.04,
        rotation=(
            random.uniform(-0.4, 0.4),
            random.uniform(-0.4, 0.4),
            random.uniform(-0.8, 0.8)
        )
    )


# ============================================================
# OVERHEAD UTILITY PIPES
# ============================================================

for i, py in enumerate((-5.7, 5.9)):
    add_cylinder(
        "OVERHEAD_PIPE_" + str(i),
        (-5, py, 24),
        0.65 if i == 0 else 0.42,
        80,
        DETAILS,
        IRON,
        12,
        rotation=(0, math.radians(90), 0)
    )


# ============================================================
# HANGING CABLE-LIKE BARS
# ============================================================

for x in (-57, -35, -12, 28, 47):
    add_box(
        "UTILITY_DROP",
        (
            x,
            random.choice((-7.5, 7.5)),
            17
        ),
        (0.16, 0.16, random.uniform(7, 13)),
        DETAILS,
        IRON,
        0.01,
        rotation=(
            math.radians(random.uniform(-4, 4)),
            0,
            math.radians(random.uniform(-5, 5))
        )
    )


# ============================================================
# SIMPLE STREET LAMPS
# ============================================================

for i, x in enumerate((-58, -32, -7, 24, 48, 67)):
    side = -1 if i % 2 else 1
    y = side * 7.6

    add_box(
        "LAMP_BRACKET",
        (x, y, 9.5),
        (0.35, 2.4, 0.35),
        DETAILS,
        IRON,
        0.025
    )

    add_box(
        "LAMP_HOUSING",
        (
            x,
            y - side * 1.0,
            9.0
        ),
        (1.1, 1.1, 1.5),
        DETAILS,
        IRON,
        0.05
    )

    lamp = add_box(
        "LAMP_GLASS",
        (
            x,
            y - side * 1.0,
            8.85
        ),
        (0.7, 0.7, 0.7),
        DETAILS,
        LIGHT_MAT,
        0.03
    )

    # Actual low-cost preview light
    bpy.ops.object.light_add(
        type="POINT",
        location=(
            x,
            y - side * 1.0,
            8.8
        )
    )

    light = bpy.context.object
    light.name = "StreetLamp_Preview"
    light.data.energy = 90
    light.data.shadow_soft_size = 2.0
    light.data.color = (1.0, 0.55, 0.20)


# ============================================================
# UPPER CITY MASSING
# ============================================================

# These are deliberately simpler than street-level geometry.
# They establish the "city keeps going upward" silhouette.

upper_specs = [
    (-60, 18, 72, 18, 20, 60),
    (-42, 19, 80, 17, 22, 72),
    (-23, 18, 68, 18, 19, 52),
    (-3, 21, 85, 20, 22, 76),
    (18, 19, 75, 19, 20, 60),
    (38, 22, 80, 21, 22, 70),
    (59, 22, 90, 20, 22, 78),
]

for side in (-1, 1):
    for i, (x, w, base, depth, dummy, h) in enumerate(upper_specs):
        y = side * (12 + depth / 2)

        building_mass(
            "UPPER_CITY_MASS",
            x + random.uniform(-2, 2),
            y,
            base,
            w * random.uniform(0.85, 1.15),
            depth,
            h,
            OVERHEAD,
            DARK_PLASTER if i % 2 else STONE,
            rotation=random.uniform(-1.5, 1.5)
        )

        # Later-added smaller mass
        if i % 2 == 0:
            building_mass(
                "UPPER_CITY_ADDITION",
                x + random.uniform(-3, 3),
                y - side * 2,
                base + h,
                w * 0.65,
                depth * 0.70,
                random.uniform(18, 35),
                OVERHEAD,
                PATCH
            )


# ============================================================
# HIGH CROSS-BRIDGES
# ============================================================

for x, z in (
    (-30, 52),
    (31, 61),
    (58, 74)
):
    add_box(
        "HIGH_CITY_BRIDGE",
        (x, 0, z),
        (11, 30, 4),
        OVERHEAD,
        DARK_PLASTER,
        0.10
    )

    add_box(
        "HIGH_CITY_BRIDGE_BOTTOM",
        (x, 0, z - 2.1),
        (12, 31, 0.6),
        OVERHEAD,
        IRON,
        0.04
    )


# ============================================================
# ANCIENT MEGASTRUCTURE
# ============================================================

# Human city should feel huge, but still tiny relative to this.

for x in (-85, 85):
    add_box(
        "ANCIENT_VERTICAL_MASS",
        (x, 0, 95),
        (24, 85, 190),
        ANCIENT_COL,
        ANCIENT,
        0.40,
        rotation=(
            0,
            math.radians(random.uniform(-2, 2)),
            0
        )
    )

# distant impossible rib overhead
add_box(
    "ANCIENT_OVERHEAD_RIB",
    (5, 0, 175),
    (180, 18, 18),
    ANCIENT_COL,
    ANCIENT,
    0.50,
    rotation=(
        math.radians(2),
        0,
        math.radians(-3)
    )
)


# ============================================================
# STREET-END COMPRESSION
# ============================================================

# Break the clean infinite sightline at one end.

add_box(
    "FAR_STREET_BLOCKER",
    (77, 0, 14),
    (6, 32, 28),
    OVERHEAD,
    STONE,
    0.18,
    rotation=(0, 0, math.radians(-5))
)

# Passage through blocker
add_box(
    "FAR_PASSAGE_DARK",
    (73.8, 0, 5),
    (0.25, 7, 10),
    DETAILS,
    ANCIENT,
    0
)


# ============================================================
# GRIME / GROUND PATCHES
# ============================================================

for i in range(22):
    x = random.uniform(-68, 70)
    y = random.uniform(-6, 6)

    add_box(
        "GROUND_GRIME",
        (x, y, 0.025),
        (
            random.uniform(1.5, 5),
            random.uniform(0.5, 2.0),
            0.03
        ),
        DETAILS,
        DIRT,
        0,
        rotation=(
            0,
            0,
            random.uniform(0, math.pi)
        )
    )


# ============================================================
# HUMAN SCALE REFERENCE
# ============================================================

# 6-stud-ish reference figure.
add_cylinder(
    "PLAYER_SCALE_BODY",
    (-4, 1.5, 3.0),
    0.65,
    4.4,
    DISPLAY,
    RED,
    12
)

bpy.ops.mesh.primitive_uv_sphere_add(
    segments=16,
    ring_count=8,
    radius=0.85,
    location=(-4, 1.5, 5.6)
)

head = bpy.context.object
head.name = "PLAYER_SCALE_HEAD"
move_to_collection(head, DISPLAY)
head.data.materials.append(RED)


# ============================================================
# WORLD / LIGHTING
# ============================================================

world = bpy.context.scene.world
world.use_nodes = True

background = world.node_tree.nodes.get("Background")

if background:
    background.inputs["Color"].default_value = (
        0.008,
        0.010,
        0.014,
        1
    )
    background.inputs["Strength"].default_value = 0.22


# Broad cool ambient preview lighting
bpy.ops.object.light_add(
    type="AREA",
    location=(0, 0, 135)
)

top_light = bpy.context.object
top_light.name = "Preview_Upper_Ambient"
top_light.data.energy = 2200
top_light.data.size = 80


# entrance fill
bpy.ops.object.light_add(
    type="AREA",
    location=(-70, -25, 35)
)

fill = bpy.context.object
fill.name = "Preview_Street_Fill"
fill.data.energy = 1200
fill.data.size = 30


def point_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


point_at(fill, (-15, 0, 10))


# ============================================================
# CAMERAS
# ============================================================

# Street-level camera is the IMPORTANT one.

bpy.ops.object.camera_add(
    location=(-66, -1.5, 6.5)
)

street_cam = bpy.context.object
street_cam.name = "CAMERA_STREET_LEVEL"

point_at(
    street_cam,
    (20, 0, 8)
)

street_cam.data.lens = 32


# Elevated overview
bpy.ops.object.camera_add(
    location=(-95, -115, 105)
)

overview = bpy.context.object
overview.name = "CAMERA_OVERVIEW"

point_at(
    overview,
    (0, 0, 30)
)

overview.data.lens = 42


# Start with street-level view
bpy.context.scene.camera = street_cam


# ============================================================
# SAVE
# ============================================================

os.makedirs(
    os.path.dirname(OUT),
    exist_ok=True
)

bpy.ops.object.select_all(action="DESELECT")

bpy.ops.wm.save_as_mainfile(
    filepath=OUT
)

print("")
print("=" * 72)
print("ENFLESHED LOWER LAYER TEST STREET V1 GENERATED")
print(OUT)
print("")
print("IMPORTANT:")
print("View through CAMERA_STREET_LEVEL first.")
print("This scene is for composition/scale evaluation before texturing.")
print("=" * 72)
