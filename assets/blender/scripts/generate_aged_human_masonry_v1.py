import os
import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# ============================================================
# ENFLESHED
# Aged Human Masonry PBR V1
#
# Generates:
# - Color map
# - Normal map
# - Roughness map
# - Metalness map
# - Preview image
#
# 1024x1024 seamless/tileable prototype
# ============================================================

SIZE = 1024
SEED = 481516

random.seed(SEED)

ROOT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/textures/aged_human_masonry_v1"
)

os.makedirs(ROOT, exist_ok=True)

COLOR_PATH = os.path.join(
    ROOT,
    "aged_human_masonry_color.png"
)

NORMAL_PATH = os.path.join(
    ROOT,
    "aged_human_masonry_normal.png"
)

ROUGHNESS_PATH = os.path.join(
    ROOT,
    "aged_human_masonry_roughness.png"
)

METALNESS_PATH = os.path.join(
    ROOT,
    "aged_human_masonry_metalness.png"
)

PREVIEW_PATH = os.path.join(
    ROOT,
    "aged_human_masonry_preview.png"
)


# ------------------------------------------------------------
# UTILITY
# ------------------------------------------------------------

def clamp(value, minimum=0, maximum=255):
    return max(
        minimum,
        min(maximum, int(value))
    )


def tileable_noise(size, scale, seed):
    """
    Creates smooth tileable noise using a small random grid
    that is resized with wrapping-compatible edge values.
    """

    rng = random.Random(seed)

    grid_size = max(2, scale)

    grid = Image.new(
        "L",
        (grid_size + 1, grid_size + 1)
    )

    pixels = grid.load()

    for y in range(grid_size):
        for x in range(grid_size):
            pixels[x, y] = rng.randint(0, 255)

    # Wrap horizontal edge
    for y in range(grid_size):
        pixels[grid_size, y] = pixels[0, y]

    # Wrap vertical edge
    for x in range(grid_size):
        pixels[x, grid_size] = pixels[x, 0]

    pixels[grid_size, grid_size] = pixels[0, 0]

    enlarged = grid.resize(
        (size + 1, size + 1),
        Image.Resampling.BICUBIC
    )

    return enlarged.crop(
        (0, 0, size, size)
    )


# ------------------------------------------------------------
# BASE HEIGHT MAP
# ------------------------------------------------------------

height = Image.new(
    "L",
    (SIZE, SIZE),
    145
)

height_draw = ImageDraw.Draw(height)


# ------------------------------------------------------------
# MASONRY BLOCK LAYOUT
#
# Deliberately larger, irregular blocks rather than clean
# modern bricks.
# ------------------------------------------------------------

row_height = 118

rows = math.ceil(SIZE / row_height)

mortar_width = 10

for row in range(rows):

    y0 = row * row_height
    y1 = min(
        SIZE,
        y0 + row_height
    )

    # Alternate offsets, but with irregularity.
    if row % 2 == 0:
        offset = -90
    else:
        offset = -15

    offset += random.randint(-18, 18)

    x = offset

    while x < SIZE:

        block_width = random.randint(
            175,
            280
        )

        x0 = x
        x1 = x + block_width

        stone_height = random.randint(
            155,
            205
        )

        # Block height variation.
        base_value = stone_height

        height_draw.rectangle(
            [
                x0 + mortar_width,
                y0 + mortar_width,
                x1 - mortar_width,
                y1 - mortar_width,
            ],
            fill=base_value,
        )

        x = x1


# ------------------------------------------------------------
# MORTAR CHANNELS
# ------------------------------------------------------------

for row in range(rows + 1):

    y = row * row_height

    height_draw.rectangle(
        [
            0,
            y - mortar_width // 2,
            SIZE,
            y + mortar_width // 2,
        ],
        fill=78,
    )


# ------------------------------------------------------------
# SURFACE EROSION
# ------------------------------------------------------------

broad_noise = tileable_noise(
    SIZE,
    8,
    SEED + 1
)

fine_noise = tileable_noise(
    SIZE,
    40,
    SEED + 2
)

broad_noise = ImageEnhance.Contrast(
    broad_noise
).enhance(0.8)

fine_noise = ImageEnhance.Contrast(
    fine_noise
).enhance(1.35)


hp = height.load()
bp = broad_noise.load()
fp = fine_noise.load()

for y in range(SIZE):
    for x in range(SIZE):

        value = hp[x, y]

        broad = (
            bp[x, y] - 128
        ) * 0.14

        fine = (
            fp[x, y] - 128
        ) * 0.08

        hp[x, y] = clamp(
            value + broad + fine
        )


# ------------------------------------------------------------
# CRACKS
# ------------------------------------------------------------

crack_layer = Image.new(
    "L",
    (SIZE, SIZE),
    0
)

crack_draw = ImageDraw.Draw(
    crack_layer
)

rng = random.Random(
    SEED + 50
)

for i in range(38):

    x = rng.randint(
        0,
        SIZE - 1
    )

    y = rng.randint(
        0,
        SIZE - 1
    )

    points = [
        (x, y)
    ]

    segments = rng.randint(
        2,
        6
    )

    for _ in range(segments):

        x += rng.randint(
            -28,
            28
        )

        y += rng.randint(
            14,
            48
        )

        x %= SIZE
        y %= SIZE

        points.append(
            (x, y)
        )

    # Draw only local pieces so wrap jumps do not
    # create giant diagonal lines.
    for a, b in zip(
        points[:-1],
        points[1:]
    ):

        if (
            abs(a[0] - b[0]) < 80
            and
            abs(a[1] - b[1]) < 80
        ):

            crack_draw.line(
                [a, b],
                fill=rng.randint(
                    80,
                    150
                ),
                width=rng.randint(
                    1,
                    3
                )
            )


crack_layer = crack_layer.filter(
    ImageFilter.GaussianBlur(
        radius=0.7
    )
)

cp = crack_layer.load()

for y in range(SIZE):
    for x in range(SIZE):

        crack = cp[x, y]

        if crack > 0:

            hp[x, y] = clamp(
                hp[x, y]
                - crack * 0.30
            )


# ------------------------------------------------------------
# SOFTEN HEIGHT MAP
# ------------------------------------------------------------

height = height.filter(
    ImageFilter.GaussianBlur(
        radius=1.3
    )
)


# ------------------------------------------------------------
# COLOR MAP
# ------------------------------------------------------------

color = Image.new(
    "RGB",
    (SIZE, SIZE)
)

color_pixels = color.load()
height_pixels = height.load()

color_noise = tileable_noise(
    SIZE,
    12,
    SEED + 100
)

stain_noise = tileable_noise(
    SIZE,
    5,
    SEED + 101
)

color_noise_pixels = color_noise.load()
stain_pixels = stain_noise.load()


for y in range(SIZE):
    for x in range(SIZE):

        h = height_pixels[x, y]

        variation = (
            color_noise_pixels[x, y]
            - 128
        ) * 0.12

        stain = (
            stain_pixels[x, y]
            - 128
        ) * 0.10

        # Mortar / recessed areas
        if h < 115:

            base = (
                62,
                58,
                50
            )

        else:

            base = (
                105,
                96,
                82
            )

        r = (
            base[0]
            + variation
            + stain * 0.70
        )

        g = (
            base[1]
            + variation
            + stain * 0.55
        )

        b = (
            base[2]
            + variation
            + stain * 0.35
        )

        color_pixels[x, y] = (
            clamp(r),
            clamp(g),
            clamp(b)
        )


# ------------------------------------------------------------
# GRIME / WATER STREAKS
# ------------------------------------------------------------

grime = tileable_noise(
    SIZE,
    6,
    SEED + 200
)

grime = grime.filter(
    ImageFilter.GaussianBlur(
        radius=6
    )
)

gp = grime.load()
cpix = color.load()

for y in range(SIZE):
    for x in range(SIZE):

        g = gp[x, y]

        if g < 90:

            amount = (
                90 - g
            ) * 0.12

            r, gg, b = cpix[x, y]

            cpix[x, y] = (
                clamp(r - amount),
                clamp(gg - amount),
                clamp(b - amount * 0.75),
            )


# ------------------------------------------------------------
# NORMAL MAP FROM HEIGHT
# ------------------------------------------------------------

normal = Image.new(
    "RGB",
    (SIZE, SIZE)
)

np = normal.load()
hp = height.load()

NORMAL_STRENGTH = 2.3


for y in range(SIZE):
    for x in range(SIZE):

        left = hp[
            (x - 1) % SIZE,
            y
        ]

        right = hp[
            (x + 1) % SIZE,
            y
        ]

        up = hp[
            x,
            (y - 1) % SIZE
        ]

        down = hp[
            x,
            (y + 1) % SIZE
        ]

        dx = (
            right - left
        ) / 255.0

        dy = (
            down - up
        ) / 255.0

        nx = (
            -dx
            * NORMAL_STRENGTH
        )

        ny = (
            -dy
            * NORMAL_STRENGTH
        )

        nz = 1.0

        length = math.sqrt(
            nx * nx
            + ny * ny
            + nz * nz
        )

        nx /= length
        ny /= length
        nz /= length

        np[x, y] = (
            clamp(
                (nx * 0.5 + 0.5)
                * 255
            ),
            clamp(
                (ny * 0.5 + 0.5)
                * 255
            ),
            clamp(
                (nz * 0.5 + 0.5)
                * 255
            ),
        )


# ------------------------------------------------------------
# ROUGHNESS MAP
#
# White = rough
# Black = smooth
#
# Masonry should be very rough with small variations.
# ------------------------------------------------------------

roughness = Image.new(
    "L",
    (SIZE, SIZE)
)

rp = roughness.load()

rough_noise = tileable_noise(
    SIZE,
    25,
    SEED + 300
)

rnp = rough_noise.load()


for y in range(SIZE):
    for x in range(SIZE):

        h = hp[x, y]

        noise_value = (
            rnp[x, y]
            - 128
        ) * 0.12

        if h < 115:

            base = 238

        else:

            base = 218

        rp[x, y] = clamp(
            base
            + noise_value
        )


# ------------------------------------------------------------
# METALNESS MAP
#
# Masonry contains no meaningful exposed metal.
# Completely black.
# ------------------------------------------------------------

metalness = Image.new(
    "L",
    (SIZE, SIZE),
    0
)


# ------------------------------------------------------------
# PREVIEW
# ------------------------------------------------------------

preview = Image.new(
    "RGB",
    (SIZE, SIZE)
)

pp = preview.load()

for y in range(SIZE):
    for x in range(SIZE):

        r, g, b = cpix[x, y]

        # Cheap directional light derived from normal.
        nr, ng, nb = np[x, y]

        nx = (
            nr / 255.0
        ) * 2.0 - 1.0

        ny = (
            ng / 255.0
        ) * 2.0 - 1.0

        nz = (
            nb / 255.0
        ) * 2.0 - 1.0

        # Upper-left light
        lighting = (
            nx * -0.35
            + ny * -0.25
            + nz * 0.85
        )

        lighting = max(
            0.38,
            min(
                1.25,
                lighting
            )
        )

        pp[x, y] = (
            clamp(r * lighting),
            clamp(g * lighting),
            clamp(b * lighting),
        )


# ------------------------------------------------------------
# SAVE
# ------------------------------------------------------------

color.save(
    COLOR_PATH
)

normal.save(
    NORMAL_PATH
)

roughness.save(
    ROUGHNESS_PATH
)

metalness.save(
    METALNESS_PATH
)

preview.save(
    PREVIEW_PATH
)


print("")
print("==============================================")
print(" ENFLESHED — AGED HUMAN MASONRY PBR V1")
print("==============================================")
print("")
print("Generated:")
print(COLOR_PATH)
print(NORMAL_PATH)
print(ROUGHNESS_PATH)
print(METALNESS_PATH)
print(PREVIEW_PATH)
print("")
print("Resolution:")
print(f"{SIZE} x {SIZE}")
print("")
print("==============================================")
