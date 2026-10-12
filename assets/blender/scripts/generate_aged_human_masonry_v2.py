import os
import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# ============================================================
# ENFLESHED
# Aged Human Masonry PBR V2
#
# Goals:
# - large irregular masonry blocks
# - uneven courses
# - irregular vertical joints
# - variable mortar width
# - individual stone coloration
# - chipped/worn joints
# - cracks biased toward joints
# - large-scale staining
# - seamless tiling
#
# Outputs:
#   color
#   normal
#   roughness
#   metalness
#   height
#   preview
#   4x4 tiled preview
# ============================================================

SIZE = 1024
SEED = 918273

ROOT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/textures/aged_human_masonry_v2"
)

os.makedirs(ROOT, exist_ok=True)

PATHS = {
    "color": os.path.join(ROOT, "aged_human_masonry_v2_color.png"),
    "normal": os.path.join(ROOT, "aged_human_masonry_v2_normal.png"),
    "roughness": os.path.join(ROOT, "aged_human_masonry_v2_roughness.png"),
    "metalness": os.path.join(ROOT, "aged_human_masonry_v2_metalness.png"),
    "height": os.path.join(ROOT, "aged_human_masonry_v2_height.png"),
    "preview": os.path.join(ROOT, "aged_human_masonry_v2_preview.png"),
    "tiled": os.path.join(ROOT, "aged_human_masonry_v2_tiled_preview.png"),
}


def clamp(v):
    return max(0, min(255, int(v)))


def tileable_noise(size, cells, seed):
    rng = random.Random(seed)

    grid = Image.new("L", (cells + 1, cells + 1))
    px = grid.load()

    for y in range(cells):
        for x in range(cells):
            px[x, y] = rng.randint(0, 255)

    for y in range(cells):
        px[cells, y] = px[0, y]

    for x in range(cells):
        px[x, cells] = px[x, 0]

    px[cells, cells] = px[0, 0]

    large = grid.resize(
        (size + 1, size + 1),
        Image.Resampling.BICUBIC,
    )

    return large.crop((0, 0, size, size))


# ============================================================
# IRREGULAR STONE LAYOUT
# ============================================================

rng = random.Random(SEED)

height = Image.new("L", (SIZE, SIZE), 72)
stone_id = Image.new("I", (SIZE, SIZE), 0)

hp = height.load()
sid = stone_id.load()

stones = []

# Deliberately uneven course heights.
course_heights = [
    156,
    205,
    132,
    184,
    168,
    179,
]

# Scale them so the pattern fills exactly one tile vertically.
factor = SIZE / sum(course_heights)
course_heights = [
    max(80, round(h * factor))
    for h in course_heights
]

# Correct rounding difference.
course_heights[-1] += SIZE - sum(course_heights)

y = 0
stone_index = 1

for row, course_h in enumerate(course_heights):

    y0 = y
    y1 = y + course_h

    # Offset each course differently.
    x = rng.randint(-220, -40)

    while x < SIZE:

        width = rng.randint(175, 340)

        # Occasionally make a deliberately oversized block.
        if rng.random() < 0.16:
            width += rng.randint(90, 190)

        x0 = x
        x1 = x + width

        mortar = rng.randint(7, 14)

        sx0 = x0 + mortar
        sx1 = x1 - mortar
        sy0 = y0 + mortar
        sy1 = y1 - mortar

        base_height = rng.randint(166, 205)

        stones.append({
            "id": stone_index,
            "x0": x0,
            "x1": x1,
            "y0": y0,
            "y1": y1,
            "sx0": sx0,
            "sx1": sx1,
            "sy0": sy0,
            "sy1": sy1,
            "height": base_height,
            "tone": rng.randint(-17, 17),
        })

        # Draw with wrapping.
        for yy in range(max(0, sy0), min(SIZE, sy1)):
            for xx_unwrapped in range(sx0, sx1):

                xx = xx_unwrapped % SIZE

                hp[xx, yy] = base_height
                sid[xx, yy] = stone_index

        stone_index += 1
        x = x1

    y = y1


# ============================================================
# CHIPPED / WORN STONE EDGES
#
# Disturbs perfectly manufactured edges.
# ============================================================

edge_noise = tileable_noise(
    SIZE,
    48,
    SEED + 10,
)

ep = edge_noise.load()

original_height = height.copy()
ohp = original_height.load()

for y in range(SIZE):
    for x in range(SIZE):

        current_id = sid[x, y]

        if current_id == 0:
            continue

        neighbors = [
            sid[(x - 1) % SIZE, y],
            sid[(x + 1) % SIZE, y],
            sid[x, (y - 1) % SIZE],
            sid[x, (y + 1) % SIZE],
        ]

        if any(n != current_id for n in neighbors):

            erosion = 12 + (ep[x, y] / 255.0) * 25

            hp[x, y] = clamp(
                ohp[x, y] - erosion
            )


# ============================================================
# MULTI-SCALE STONE SURFACE
# ============================================================

broad = tileable_noise(
    SIZE,
    9,
    SEED + 20,
)

medium = tileable_noise(
    SIZE,
    31,
    SEED + 21,
)

fine = tileable_noise(
    SIZE,
    96,
    SEED + 22,
)

bp = broad.load()
mp = medium.load()
fp = fine.load()

for y in range(SIZE):
    for x in range(SIZE):

        if sid[x, y] == 0:
            continue

        delta = (
            (bp[x, y] - 128) * 0.055
            + (mp[x, y] - 128) * 0.050
            + (fp[x, y] - 128) * 0.025
        )

        hp[x, y] = clamp(
            hp[x, y] + delta
        )


# ============================================================
# CRACKS
#
# Prefer cracks originating around mortar/stone boundaries.
# ============================================================

cracks = Image.new("L", (SIZE, SIZE), 0)
cd = ImageDraw.Draw(cracks)

crng = random.Random(SEED + 100)

boundary_candidates = []

for y in range(3, SIZE - 3, 4):
    for x in range(3, SIZE - 3, 4):

        center = sid[x, y]

        nearby = [
            sid[(x - 3) % SIZE, y],
            sid[(x + 3) % SIZE, y],
            sid[x, (y - 3) % SIZE],
            sid[x, (y + 3) % SIZE],
        ]

        if any(n != center for n in nearby):
            boundary_candidates.append((x, y))

crng.shuffle(boundary_candidates)

for start in boundary_candidates[:52]:

    x, y = start

    points = [(x, y)]

    length = crng.randint(2, 6)

    for _ in range(length):

        x += crng.randint(-22, 22)
        y += crng.randint(10, 35)

        if x < 0 or x >= SIZE or y < 0 or y >= SIZE:
            break

        points.append((x, y))

    if len(points) > 1:

        cd.line(
            points,
            fill=crng.randint(100, 185),
            width=crng.randint(1, 3),
        )


cracks = cracks.filter(
    ImageFilter.GaussianBlur(0.6)
)

cp = cracks.load()

for y in range(SIZE):
    for x in range(SIZE):

        if cp[x, y] > 0:

            hp[x, y] = clamp(
                hp[x, y]
                - cp[x, y] * 0.28
            )


# Slight smoothing prevents computer-perfect geometry.
height = height.filter(
    ImageFilter.GaussianBlur(1.0)
)

hp = height.load()


# ============================================================
# COLOR MAP
# ============================================================

color = Image.new("RGB", (SIZE, SIZE))
col = color.load()

micro_color = tileable_noise(
    SIZE,
    40,
    SEED + 200,
)

large_stain = tileable_noise(
    SIZE,
    4,
    SEED + 201,
)

mineral = tileable_noise(
    SIZE,
    13,
    SEED + 202,
)

mcp = micro_color.load()
lsp = large_stain.load()
mip = mineral.load()

stone_tones = {
    stone["id"]: stone["tone"]
    for stone in stones
}

for y in range(SIZE):
    for x in range(SIZE):

        stone = sid[x, y]

        if stone == 0:

            base_r = 54
            base_g = 50
            base_b = 43

            local_tone = 0

        else:

            local_tone = stone_tones.get(
                stone,
                0,
            )

            base_r = 103
            base_g = 94
            base_b = 80

        micro = (
            mcp[x, y] - 128
        ) * 0.075

        stain = (
            lsp[x, y] - 128
        ) * 0.105

        mineral_value = (
            mip[x, y] - 128
        ) * 0.055

        r = (
            base_r
            + local_tone
            + micro
            + stain * 0.55
            + mineral_value
        )

        g = (
            base_g
            + local_tone * 0.82
            + micro
            + stain * 0.42
            + mineral_value * 0.75
        )

        b = (
            base_b
            + local_tone * 0.62
            + micro
            + stain * 0.27
            + mineral_value * 0.48
        )

        col[x, y] = (
            clamp(r),
            clamp(g),
            clamp(b),
        )


# ============================================================
# VERTICAL WATER / SOOT STREAKS
# ============================================================

streak_mask = Image.new("L", (SIZE, SIZE), 0)
sd = ImageDraw.Draw(streak_mask)

srng = random.Random(SEED + 300)

for _ in range(22):

    x = srng.randint(0, SIZE - 1)

    width = srng.randint(5, 30)

    strength = srng.randint(18, 60)

    start_y = srng.randint(0, SIZE // 2)

    end_y = min(
        SIZE,
        start_y + srng.randint(180, 650)
    )

    sd.rectangle(
        [
            x - width,
            start_y,
            x + width,
            end_y,
        ],
        fill=strength,
    )


streak_mask = streak_mask.filter(
    ImageFilter.GaussianBlur(14)
)

sp = streak_mask.load()

for y in range(SIZE):
    for x in range(SIZE):

        amount = sp[x, y] * 0.25

        if amount <= 0:
            continue

        r, g, b = col[x, y]

        col[x, y] = (
            clamp(r - amount),
            clamp(g - amount),
            clamp(b - amount * 0.72),
        )


# ============================================================
# DARKEN CRACKS
# ============================================================

cp = cracks.load()

for y in range(SIZE):
    for x in range(SIZE):

        crack = cp[x, y]

        if crack <= 0:
            continue

        r, g, b = col[x, y]

        amount = crack * 0.18

        col[x, y] = (
            clamp(r - amount),
            clamp(g - amount),
            clamp(b - amount),
        )


# ============================================================
# NORMAL MAP
# ============================================================

normal = Image.new("RGB", (SIZE, SIZE))
np = normal.load()

NORMAL_STRENGTH = 3.1

for y in range(SIZE):
    for x in range(SIZE):

        left = hp[(x - 1) % SIZE, y]
        right = hp[(x + 1) % SIZE, y]

        up = hp[x, (y - 1) % SIZE]
        down = hp[x, (y + 1) % SIZE]

        dx = (right - left) / 255.0
        dy = (down - up) / 255.0

        nx = -dx * NORMAL_STRENGTH
        ny = -dy * NORMAL_STRENGTH
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
            clamp((nx * 0.5 + 0.5) * 255),
            clamp((ny * 0.5 + 0.5) * 255),
            clamp((nz * 0.5 + 0.5) * 255),
        )


# ============================================================
# ROUGHNESS
# ============================================================

roughness = Image.new("L", (SIZE, SIZE))
rp = roughness.load()

rough_noise = tileable_noise(
    SIZE,
    50,
    SEED + 400,
)

rnp = rough_noise.load()

for y in range(SIZE):
    for x in range(SIZE):

        if sid[x, y] == 0:
            base = 242
        else:
            base = 216

        variation = (
            rnp[x, y] - 128
        ) * 0.12

        # Wet-looking grime is only slightly less rough,
        # not glossy.
        streak_effect = (
            sp[x, y] * 0.10
        )

        rp[x, y] = clamp(
            base
            + variation
            - streak_effect
        )


# ============================================================
# METALNESS
# ============================================================

metalness = Image.new(
    "L",
    (SIZE, SIZE),
    0,
)


# ============================================================
# LIGHTING PREVIEW
# ============================================================

preview = Image.new(
    "RGB",
    (SIZE, SIZE)
)

pp = preview.load()

for y in range(SIZE):
    for x in range(SIZE):

        r, g, b = col[x, y]

        nr, ng, nb = np[x, y]

        nx = nr / 255.0 * 2.0 - 1.0
        ny = ng / 255.0 * 2.0 - 1.0
        nz = nb / 255.0 * 2.0 - 1.0

        lighting = (
            nx * -0.30
            + ny * -0.24
            + nz * 0.93
        )

        lighting = max(
            0.48,
            min(1.20, lighting)
        )

        pp[x, y] = (
            clamp(r * lighting),
            clamp(g * lighting),
            clamp(b * lighting),
        )


# ============================================================
# 4 x 4 TILING PREVIEW
# ============================================================

TILE_DISPLAY = 512

small_preview = preview.resize(
    (TILE_DISPLAY, TILE_DISPLAY),
    Image.Resampling.LANCZOS,
)

tiled = Image.new(
    "RGB",
    (
        TILE_DISPLAY * 4,
        TILE_DISPLAY * 4,
    ),
)

for ty in range(4):
    for tx in range(4):

        tiled.paste(
            small_preview,
            (
                tx * TILE_DISPLAY,
                ty * TILE_DISPLAY,
            ),
        )


# ============================================================
# SAVE
# ============================================================

color.save(PATHS["color"])
normal.save(PATHS["normal"])
roughness.save(PATHS["roughness"])
metalness.save(PATHS["metalness"])
height.save(PATHS["height"])
preview.save(PATHS["preview"])
tiled.save(PATHS["tiled"])


print("")
print("==============================================")
print(" ENFLESHED — AGED HUMAN MASONRY PBR V2")
print("==============================================")
print("")

for name, path in PATHS.items():
    print(f"{name:12s}: {path}")

print("")
print("Resolution: 1024 x 1024")
print("Tiling test: 4 x 4")
print("")
print("Generation complete.")
print("==============================================")
