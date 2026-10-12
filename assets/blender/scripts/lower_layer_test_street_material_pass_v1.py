import bpy
import os
import mathutils

# ============================================================
# ENFLESHED
# Lower Layer Test Street V2 — Material Pass V1
# Blender 5.2
#
# Loads:
#   lower_layer_test_street_v2.blend
#
# Imports:
#   lower_layer_material_library_v2.blend
#
# Saves:
#   lower_layer_test_street_v2_material_pass_v1.blend
#
# IMPORTANT:
# Lighting in this file is intentionally bright for material
# inspection. It is NOT intended to represent final game
# atmosphere.
# ============================================================


# ------------------------------------------------------------
# PATHS
# ------------------------------------------------------------

ROOT = os.path.expanduser("~/Projects/Enfleshed")

STREET_FILE = os.path.join(
    ROOT,
    "assets/blender/generated/lower_layer_test_street_v2.blend"
)

MATERIAL_FILE = os.path.join(
    ROOT,
    "assets/blender/generated/lower_layer_material_library_v2.blend"
)

OUTPUT_FILE = os.path.join(
    ROOT,
    "assets/blender/generated/"
    "lower_layer_test_street_v2_material_pass_v1.blend"
)


# ------------------------------------------------------------
# OPEN ORIGINAL TEST STREET
# ------------------------------------------------------------

print("")
print("==============================================")
print(" ENFLESHED — TEST STREET MATERIAL PASS V1")
print("==============================================")
print("")
print("Opening:")
print(STREET_FILE)

bpy.ops.wm.open_mainfile(filepath=STREET_FILE)


# ------------------------------------------------------------
# REMOVE OLD MATERIAL-PASS LIGHTS
#
# This prevents duplicates if the source file ever contains
# lights from a previous inspection pass.
# ------------------------------------------------------------

for obj in list(bpy.data.objects):
    if obj.name.startswith("MATPASS_"):
        bpy.data.objects.remove(obj, do_unlink=True)


# ------------------------------------------------------------
# MATERIAL NAMES
# ------------------------------------------------------------

WANTED_MATERIALS = [
    "LL_Ancient_Dark_Stone_V2",
    "LL_Aged_Masonry_V2",
    "LL_Worn_Plaster_V2",
    "LL_Blackened_Iron_V2",
    "LL_Rusted_Patch_Metal_V2",
    "LL_Worn_Timber_V2",
    "LL_Street_Stone_V2",
    "LL_Faded_Military_Red_V2",
    "LL_Soot_Grime_V2",
    "LL_Fracture_Masonry_V2",
    "LL_Fracture_Metal_V2",
]


# ------------------------------------------------------------
# APPEND MATERIALS
# ------------------------------------------------------------

print("")
print("Importing Lower Layer V2 materials...")

with bpy.data.libraries.load(
    MATERIAL_FILE,
    link=False
) as (data_from, data_to):

    available = set(data_from.materials)

    data_to.materials = [
        name
        for name in WANTED_MATERIALS
        if name in available
    ]


# ------------------------------------------------------------
# GET MATERIALS
# ------------------------------------------------------------

def get_material(name):

    material = bpy.data.materials.get(name)

    if material is None:
        raise RuntimeError(
            "Required material was not found: " + name
        )

    return material


ANCIENT = get_material(
    "LL_Ancient_Dark_Stone_V2"
)

MASONRY = get_material(
    "LL_Aged_Masonry_V2"
)

PLASTER = get_material(
    "LL_Worn_Plaster_V2"
)

IRON = get_material(
    "LL_Blackened_Iron_V2"
)

RUST = get_material(
    "LL_Rusted_Patch_Metal_V2"
)

TIMBER = get_material(
    "LL_Worn_Timber_V2"
)

STREET = get_material(
    "LL_Street_Stone_V2"
)

RED = get_material(
    "LL_Faded_Military_Red_V2"
)

GRIME = get_material(
    "LL_Soot_Grime_V2"
)

FRACTURE_MASONRY = get_material(
    "LL_Fracture_Masonry_V2"
)

FRACTURE_METAL = get_material(
    "LL_Fracture_Metal_V2"
)


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

def normalized_name(obj):

    return (
        obj.name
        .lower()
        .replace("-", "_")
        .replace(" ", "_")
    )


def contains_any(name, terms):

    return any(
        term in name
        for term in terms
    )


def assign_material(obj, material):

    if obj.type != "MESH":
        return

    obj.data.materials.clear()
    obj.data.materials.append(material)


def deterministic_hash(text):

    total = 0

    for index, char in enumerate(text):
        total += (
            (index + 1)
            * ord(char)
        )

    return total


# ------------------------------------------------------------
# CLASSIFICATION TERMS
# ------------------------------------------------------------

ANCIENT_TERMS = [
    "ancient",
    "megastructure",
    "mega",
    "monolith",
    "pylon",
    "ancient_mass",
    "ancient_wall",
    "ancient_support",
    "ancient_rib",
]


STREET_TERMS = [
    "street",
    "road",
    "floor",
    "ground",
    "pavement",
    "courtyard_floor",
    "alley_floor",
    "passage_floor",
]


IRON_TERMS = [
    "beam",
    "railing",
    "rail",
    "catwalk",
    "support",
    "brace",
    "girder",
    "frame",
    "pipe",
    "ladder",
    "bridge",
]


RUST_TERMS = [
    "patch",
    "repair",
    "plate",
    "scrap",
    "sheet",
]


TIMBER_TERMS = [
    "wood",
    "timber",
    "door",
    "board",
    "plank",
]


RED_TERMS = [
    "military",
    "banner",
    "warning",
    "barricade",
    "checkpoint",
    "marking",
    "sign",
]


FRACTURE_TERMS = [
    "fracture",
    "broken",
    "breach",
    "rubble",
    "debris",
    "damage",
]


BUILDING_TERMS = [
    "building",
    "wall",
    "house",
    "housing",
    "room",
    "facade",
    "shop",
    "workshop",
    "habitation",
    "structure",
    "block",
    "tower",
    "upper",
    "addition",
    "interior",
]


# ------------------------------------------------------------
# COUNTERS
# ------------------------------------------------------------

counts = {
    "Ancient": 0,
    "Masonry": 0,
    "Plaster": 0,
    "Iron": 0,
    "Rust": 0,
    "Timber": 0,
    "Street": 0,
    "Red": 0,
    "Grime": 0,
    "FractureMasonry": 0,
    "FractureMetal": 0,
    "Unclassified": 0,
}


# ------------------------------------------------------------
# CLASSIFICATION
# ------------------------------------------------------------

def classify_object(obj):

    if obj.type != "MESH":
        return

    name = normalized_name(obj)


    # --------------------------------------------------------
    # DO NOT MODIFY DISPLAY / DEBUG OBJECTS
    # --------------------------------------------------------

    if contains_any(
        name,
        [
            "player",
            "reference",
            "display",
            "debug",
            "spawn",
        ],
    ):
        return


    # --------------------------------------------------------
    # ANCIENT STRUCTURE
    # --------------------------------------------------------

    if contains_any(
        name,
        ANCIENT_TERMS
    ):
        assign_material(
            obj,
            ANCIENT
        )

        counts["Ancient"] += 1
        return


    # --------------------------------------------------------
    # STREET / FLOOR
    # --------------------------------------------------------

    if contains_any(
        name,
        STREET_TERMS
    ):
        assign_material(
            obj,
            STREET
        )

        counts["Street"] += 1
        return


    # --------------------------------------------------------
    # DAMAGE / FRACTURE
    # --------------------------------------------------------

    if contains_any(
        name,
        FRACTURE_TERMS
    ):

        if contains_any(
            name,
            [
                "metal",
                "plate",
                "beam",
                "iron",
                "pipe",
            ],
        ):

            assign_material(
                obj,
                FRACTURE_METAL
            )

            counts[
                "FractureMetal"
            ] += 1

        else:

            assign_material(
                obj,
                FRACTURE_MASONRY
            )

            counts[
                "FractureMasonry"
            ] += 1

        return


    # --------------------------------------------------------
    # PATCH / REPAIR METAL
    # --------------------------------------------------------

    if contains_any(
        name,
        RUST_TERMS
    ):

        assign_material(
            obj,
            RUST
        )

        counts["Rust"] += 1
        return


    # --------------------------------------------------------
    # TIMBER
    # --------------------------------------------------------

    if contains_any(
        name,
        TIMBER_TERMS
    ):

        assign_material(
            obj,
            TIMBER
        )

        counts["Timber"] += 1
        return


    # --------------------------------------------------------
    # MILITARY ACCENT
    # --------------------------------------------------------

    if contains_any(
        name,
        RED_TERMS
    ):

        assign_material(
            obj,
            RED
        )

        counts["Red"] += 1
        return


    # --------------------------------------------------------
    # STRUCTURAL METAL
    # --------------------------------------------------------

    if contains_any(
        name,
        IRON_TERMS
    ):

        assign_material(
            obj,
            IRON
        )

        counts["Iron"] += 1
        return


    # --------------------------------------------------------
    # HUMAN ARCHITECTURE
    #
    # Controlled variation:
    #
    # 50% masonry
    # 40% plaster
    # 10% grime-darkened
    # --------------------------------------------------------

    if contains_any(
        name,
        BUILDING_TERMS
    ):

        value = (
            deterministic_hash(name)
            % 10
        )

        if value <= 4:

            assign_material(
                obj,
                MASONRY
            )

            counts["Masonry"] += 1

        elif value <= 8:

            assign_material(
                obj,
                PLASTER
            )

            counts["Plaster"] += 1

        else:

            assign_material(
                obj,
                GRIME
            )

            counts["Grime"] += 1

        return


    # --------------------------------------------------------
    # GENERIC LARGE ARCHITECTURE
    # --------------------------------------------------------

    dimensions = obj.dimensions

    largest_dimension = max(
        dimensions.x,
        dimensions.y,
        dimensions.z,
    )

    if largest_dimension >= 5.0:

        assign_material(
            obj,
            MASONRY
        )

        counts["Masonry"] += 1
        return


    counts["Unclassified"] += 1


# ------------------------------------------------------------
# APPLY MATERIALS
# ------------------------------------------------------------

print("")
print("Classifying architecture...")

mesh_count = 0

for obj in bpy.context.scene.objects:

    if obj.type == "MESH":

        mesh_count += 1

        classify_object(obj)


print("")
print("Material assignment results:")
print("")

for key, value in counts.items():

    print(
        f"{key:20s}: {value}"
    )


# ------------------------------------------------------------
# WORLD / AMBIENT LIGHT
#
# Bright on purpose.
# This is an inspection scene, not final atmosphere.
# ------------------------------------------------------------

world = bpy.context.scene.world

if world is None:

    world = bpy.data.worlds.new(
        "LowerLayerInspectionWorld"
    )

    bpy.context.scene.world = world


world.use_nodes = True

background = (
    world.node_tree.nodes.get(
        "Background"
    )
)

if background:

    background.inputs[
        "Color"
    ].default_value = (
        0.12,
        0.14,
        0.17,
        1.0,
    )

    background.inputs[
        "Strength"
    ].default_value = 0.75


# ------------------------------------------------------------
# LIGHT HELPER
# ------------------------------------------------------------

def add_area_light(
    name,
    location,
    target,
    energy,
    size,
    color,
):

    bpy.ops.object.light_add(
        type="AREA",
        location=location,
    )

    light = bpy.context.active_object

    light.name = name

    light.data.energy = energy

    light.data.shape = "DISK"

    light.data.size = size

    light.data.color = color

    direction = (
        mathutils.Vector(target)
        - light.location
    )

    light.rotation_euler = (
        direction
        .to_track_quat(
            "-Z",
            "Y"
        )
        .to_euler()
    )

    return light


# ------------------------------------------------------------
# LARGE OVERHEAD LIGHTS
#
# These illuminate the length of the city instead of relying
# on one small light source.
# ------------------------------------------------------------

add_area_light(
    "MATPASS_Overhead_West",
    (-55, 0, 115),
    (-55, 0, 0),
    22000,
    75,
    (1.0, 0.95, 0.86),
)


add_area_light(
    "MATPASS_Overhead_Center",
    (0, 0, 115),
    (0, 0, 0),
    22000,
    75,
    (1.0, 0.95, 0.86),
)


add_area_light(
    "MATPASS_Overhead_East",
    (55, 0, 115),
    (55, 0, 0),
    22000,
    75,
    (1.0, 0.95, 0.86),
)


# ------------------------------------------------------------
# SIDE FILLS
#
# Narrow alleys need horizontal illumination because upper
# structures can block overhead lighting.
# ------------------------------------------------------------

add_area_light(
    "MATPASS_Side_North",
    (0, 65, 32),
    (0, 0, 12),
    16000,
    65,
    (0.72, 0.82, 1.0),
)


add_area_light(
    "MATPASS_Side_South",
    (0, -65, 32),
    (0, 0, 12),
    16000,
    65,
    (1.0, 0.68, 0.40),
)


# ------------------------------------------------------------
# LENGTHWISE FILLS
#
# These illuminate the deep street canyons.
# ------------------------------------------------------------

add_area_light(
    "MATPASS_End_West",
    (-95, 0, 28),
    (0, 0, 10),
    14000,
    55,
    (1.0, 0.86, 0.68),
)


add_area_light(
    "MATPASS_End_East",
    (95, 0, 28),
    (0, 0, 10),
    14000,
    55,
    (0.68, 0.80, 1.0),
)


# ------------------------------------------------------------
# LOWER STREET FILLS
#
# Specifically intended to prevent the claustrophobic alleys
# and passages from becoming completely black.
# ------------------------------------------------------------

add_area_light(
    "MATPASS_StreetFill_West",
    (-40, -18, 12),
    (-10, 0, 8),
    9000,
    30,
    (1.0, 0.78, 0.55),
)


add_area_light(
    "MATPASS_StreetFill_Center",
    (5, 18, 14),
    (10, 0, 8),
    9000,
    30,
    (0.78, 0.86, 1.0),
)


add_area_light(
    "MATPASS_StreetFill_East",
    (48, -15, 14),
    (40, 0, 8),
    9000,
    30,
    (1.0, 0.78, 0.55),
)


# ------------------------------------------------------------
# RENDER SETTINGS
# ------------------------------------------------------------

scene = bpy.context.scene

scene.render.engine = (
    "BLENDER_EEVEE"
)

scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100


try:

    scene.view_settings.look = (
        "AgX - Medium High Contrast"
    )

except Exception:

    pass


# ------------------------------------------------------------
# SAVE AS NEW FILE
# ------------------------------------------------------------

os.makedirs(
    os.path.dirname(
        OUTPUT_FILE
    ),
    exist_ok=True,
)


bpy.ops.wm.save_as_mainfile(
    filepath=OUTPUT_FILE
)


# ------------------------------------------------------------
# COMPLETE
# ------------------------------------------------------------

print("")
print("==============================================")
print(" MATERIAL PASS COMPLETE")
print("==============================================")
print("")
print("Original street preserved:")
print(STREET_FILE)
print("")
print("Material-pass version:")
print(OUTPUT_FILE)
print("")
print("Inspection lighting:")
print("ENABLED")
print("")
print("Remember:")
print("This lighting is intentionally bright.")
print("It is NOT final Lower Layer atmosphere.")
print("")
print("==============================================")
