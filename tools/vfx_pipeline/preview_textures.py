"""Contact sheet of the texture library, tinted and composited over a dark industrial backdrop.

Run:  tools/vfx_pipeline/blender.sh tools/vfx_pipeline/preview_textures.py
Writes assets/vfx/previews/textures_sheet.png (+ one strip per flipbook).
Additive textures are shown additively (LightEmission = 1); smoke/dust/debris alpha-blended.
"""
import json
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import write_png  # noqa: E402

TINT = {
    "Fire": (1.0, 0.55, 0.2),
    "Body": (0.95, 0.75, 0.62),
    "Neutral": (0.75, 0.85, 1.0),
    "Ice": (0.62, 0.86, 1.0),
    "Lightning": (0.78, 0.72, 1.0),
    "Water": (0.3, 0.62, 0.95),
    "Earth": (0.72, 0.55, 0.38),
    "Wind": (0.72, 0.95, 0.85),
    "Poison": (0.55, 0.9, 0.25),
    "Arcane": (0.8, 0.55, 1.0),
    "Force": (0.9, 0.92, 1.0),
    "Spirit": (0.45, 0.95, 0.85),
    "Space": (0.55, 0.45, 1.0),
    "Time": (1.0, 0.85, 0.5),
}
TEXTURE_TINT = {
    "core_plasma": "Fire", "flame_tongue": "Fire", "flame_wisp": "Fire", "ember_streak": "Fire",
    "explosion_fire": "Fire", "trail_flame": "Fire", "pressure_wave": "Body", "force_streak": "Body",
    "sinew_trail": "Body", "dust_burst": "Body", "debris_chip": "Body",
    "frost_mist": "Ice", "ice_glint": "Ice", "ice_shatter": "Ice", "frost_crack": "Ice", "ice_trail": "Ice",
    "bolt_strip": "Lightning", "arc_flicker": "Lightning", "spark_burst": "Lightning", "plasma_orb": "Lightning",
    "scorch_lichtenberg": "Lightning", "water_splash": "Water", "droplet": "Water", "ripple_ring": "Water",
    "water_orb": "Water", "water_trail": "Water", "caustics": "Water",
    "rock_burst": "Earth", "earth_fissure": "Earth", "dust_plume": "Earth", "rubble_trail": "Earth",
    "wind_swirl": "Wind", "gust_strokes": "Wind", "leaf_scrap": "Wind",
    "toxic_bubble": "Poison", "miasma": "Poison", "acid_splat": "Poison", "toxic_pool": "Poison", "drip_trail": "Poison",
    "arcane_glyphs": "Arcane", "arcane_orb": "Arcane", "arcane_burst": "Arcane", "glyph_chain": "Arcane",
    "hex_seal": "Arcane", "kinetic_burst": "Force", "ward_hex": "Force", "impact_frame": "Force",
    "soul_wisp": "Spirit", "ghost_trail": "Spirit", "soul_burst": "Spirit", "skull_mote": "Spirit", "soul_sigil": "Spirit",
    "rift_tear": "Space", "void_orb": "Space", "warp_implode": "Space", "star_mote": "Space", "shard_trail": "Space",
    "portal_rings": "Space", "clock_dial": "Time", "hourglass_mote": "Time", "time_ripple": "Time",
    "sand_trail": "Time", "gear_mote": "Time",
}
BLENDED = {"smoke_billow", "dust_burst", "debris_chip", "heat_haze"}


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        length = int.from_bytes(data[pos:pos + 4], "big")
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h = int.from_bytes(body[:4], "big"), int.from_bytes(body[4:8], "big")
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    rows = np.frombuffer(raw, np.uint8).reshape(h, 1 + w * 4)
    assert (rows[:, 0] == 0).all(), "preview reader expects filter type 0"
    return rows[:, 1:].reshape(h, w, 4).astype(np.float32) / 255


def resize(img, size):
    h, w = img.shape[:2]
    ys = (np.arange(size[1]) * h / size[1]).astype(int)
    xs = (np.arange(size[0]) * w / size[0]).astype(int)
    return img[ys][:, xs]


def backdrop(w, h):
    y = np.linspace(0, 1, h)[:, None]
    base = np.dstack([0.055 + 0.03 * y, 0.05 + 0.025 * y, 0.06 + 0.02 * y]) * np.ones((h, w, 3))
    return base


def composite(bg, tex, tint, additive):
    rgb = tex[..., :3] * np.array(tint)
    a = tex[..., 3:4]
    return bg + rgb * a if additive else bg * (1 - a) + rgb * a


def main(root):
    tdir = os.path.join(root, "assets", "vfx", "textures")
    out = os.path.join(root, "assets", "vfx", "previews")
    os.makedirs(out, exist_ok=True)
    meta = json.load(open(os.path.join(tdir, "textures.json")))
    cell = 200
    names = sorted(meta)
    cols = 7
    rows = (len(names) + cols - 1) // cols
    sheet = backdrop(cols * cell, rows * cell)
    for i, name in enumerate(names):
        tex = read_png(os.path.join(tdir, meta[name]["file"]))
        r, c = divmod(i, cols)
        tint = TINT[TEXTURE_TINT.get(name, "Neutral")]
        h, w = tex.shape[:2]
        tw, th = (cell - 20, int((cell - 20) * h / w))
        small = resize(tex, (tw, th))
        y0 = r * cell + (cell - th) // 2
        x0 = c * cell + 10
        region = sheet[y0:y0 + th, x0:x0 + tw]
        # Cel textures carry dark ink, so they are shown alpha-blended (as cel layers render in game).
        sheet[y0:y0 + th, x0:x0 + tw] = composite(region, small, tint, False)
        layout = meta[name]["layout"]
        if layout:
            n = int(layout.replace("Grid", "").split("x")[0])
            fs = h // n
            frames = [tex[(k // n) * fs:(k // n + 1) * fs, (k % n) * fs:(k % n + 1) * fs] for k in range(n * n)]
            pick = frames[:: max(1, len(frames) // 8)][:8]
            strip = backdrop(8 * 160, 160)
            for k, fr in enumerate(pick):
                strip[:, k * 160:(k + 1) * 160] = composite(
                    strip[:, k * 160:(k + 1) * 160], resize(fr, (160, 160)), tint, False)
            write_png(os.path.join(out, f"flipbook_{name}.png"),
                      np.dstack([np.clip(strip, 0, 1), np.ones(strip.shape[:2])]))
    write_png(os.path.join(out, "textures_sheet.png"), np.dstack([np.clip(sheet, 0, 1), np.ones(sheet.shape[:2])]))
    print("[vfx] wrote previews", flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0] if args else os.getcwd())
