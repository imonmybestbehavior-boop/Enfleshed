"""Shared helpers for the Enfleshed VFX asset pipeline.

Pure numpy + zlib. Runs under Blender's bundled Python (which ships numpy), so the
pipeline needs no extra installs:  flatpak run org.blender.Blender -b --python <script>

Conventions
- Textures are *grayscale luminance + alpha* (RGB equal). Roblox multiplies particle /
  beam / trail textures by their Color sequence, so one texture serves every palette.
- Noise is periodic in x, y and time, so tiles tile and flipbooks loop when asked to.
- Every generator takes an explicit seed: output is byte-for-byte reproducible.
"""
import struct
import zlib

import numpy as np

TAU = np.pi * 2


# ----------------------------------------------------------------------------- PNG I/O
def write_png(path, rgba):
    """rgba: float array (h, w, 4) in 0..1 -> 8-bit RGBA PNG."""
    data = np.clip(np.rint(rgba * 255.0), 0, 255).astype(np.uint8)
    h, w, _ = data.shape
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(kind, body):
        c = struct.pack(">I", len(body)) + kind + body
        return c + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def read_png_header(path):
    """Validate a PNG written by write_png (or any 8-bit RGBA PNG); returns (w, h)."""
    with open(path, "rb") as f:
        head = f.read(33)
    assert head[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    w, h, depth, ctype = struct.unpack(">IIBB", head[16:26])
    return w, h, depth, ctype


def gray(lum, alpha):
    """Luminance/alpha planes -> RGBA (straight alpha, grayscale)."""
    lum = np.clip(lum, 0, 1)
    return np.dstack([lum, lum, lum, np.clip(alpha, 0, 1)])


def atlas(frames, cols):
    """List of (s, s, 4) frames -> square grid atlas, row-major (Roblox flipbook order)."""
    s = frames[0].shape[0]
    rows = int(np.ceil(len(frames) / cols))
    out = np.zeros((rows * s, cols * s, 4), np.float32)
    for i, fr in enumerate(frames):
        r, c = divmod(i, cols)
        out[r * s:(r + 1) * s, c * s:(c + 1) * s] = fr
    return out


def bleed(rgba):
    """Push RGB into fully transparent texels so bilinear filtering never pulls black halos."""
    out = rgba.copy()
    a = out[..., 3]
    # Transparent texels take the frame's alpha-weighted mean colour (grayscale here).
    weight = a.sum()
    if weight > 0:
        mean = (out[..., 0] * a).sum() / weight
        mask = a < 1 / 255
        out[..., 0][mask] = mean
        out[..., 1][mask] = mean
        out[..., 2][mask] = mean
    return out


# ----------------------------------------------------------------------------- grids
def grid(size):
    """Pixel-centre coordinates: u, v in [0,1), x, y in [-1, 1] (y up)."""
    i = (np.arange(size) + 0.5) / size
    u, v = np.meshgrid(i, i)
    v = 1.0 - v
    return u, v, u * 2 - 1, v * 2 - 1


def smooth(t):
    return t * t * (3 - 2 * t)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------------------- noise
class Noise:
    """Periodic 3D gradient (Perlin) noise remapped to ~0..1, quintic fade. Coordinates are in
    lattice units; the lattice wraps every `period` cells per axis, so tiles and loops are seamless."""

    def __init__(self, seed, period=(16, 16, 16)):
        rng = np.random.default_rng(seed)
        self.period = period
        g = rng.normal(size=(period[2], period[1], period[0], 3)).astype(np.float32)
        self.grad = g / np.linalg.norm(g, axis=-1, keepdims=True)

    def __call__(self, x, y, z=0.0):
        px, py, pz = self.period
        x = np.asarray(x, np.float32)
        y = np.broadcast_to(np.asarray(y, np.float32), x.shape)
        z = np.broadcast_to(np.asarray(z, np.float32), x.shape)
        xi, yi, zi = np.floor(x), np.floor(y), np.floor(z)
        fx, fy, fz = x - xi, y - yi, z - zi
        x0 = xi.astype(np.int64) % px
        y0 = yi.astype(np.int64) % py
        z0 = zi.astype(np.int64) % pz
        g = self.grad

        def corner(dx, dy, dz):
            gg = g[(z0 + dz) % pz, (y0 + dy) % py, (x0 + dx) % px]
            return gg[..., 0] * (fx - dx) + gg[..., 1] * (fy - dy) + gg[..., 2] * (fz - dz)

        def fade(t):
            return t * t * t * (t * (t * 6 - 15) + 10)

        ux, uy, uz = fade(fx), fade(fy), fade(fz)

        def lerp(a, b, f):
            return a + (b - a) * f

        c00 = lerp(corner(0, 0, 0), corner(1, 0, 0), ux)
        c10 = lerp(corner(0, 1, 0), corner(1, 1, 0), ux)
        c01 = lerp(corner(0, 0, 1), corner(1, 0, 1), ux)
        c11 = lerp(corner(0, 1, 1), corner(1, 1, 1), ux)
        n = lerp(lerp(c00, c10, uy), lerp(c01, c11, uy), uz)
        return np.clip(0.5 + n * 0.9, 0, 1)

    def fbm(self, x, y, z=0.0, octaves=4, lacunarity=2, gain=0.5):
        """Fractal sum; lacunarity is an integer so every octave keeps the period."""
        total, amp, norm = 0.0, 1.0, 0.0
        for o in range(octaves):
            f = lacunarity ** o
            total = total + amp * self(x * f + o * 17.31, y * f + o * 9.17, z * f + o * 3.7)
            norm += amp
            amp *= gain
        return total / norm

    def ridged(self, x, y, z=0.0, octaves=4):
        total, amp, norm = 0.0, 1.0, 0.0
        for o in range(octaves):
            f = 2 ** o
            n = 1 - np.abs(self(x * f + o * 5.1, y * f + o * 2.3, z * f) * 2 - 1)
            total = total + amp * n * n
            norm += amp
            amp *= 0.5
        return total / norm


def worley(x, y, period, seed, jitter=0.9):
    """Periodic 2D cellular noise: returns F1 distance (cells), ~0..1. Billows = 1 - F1."""
    rng = np.random.default_rng(seed)
    pts = rng.random((period, period, 2)).astype(np.float32) * jitter + (1 - jitter) / 2
    xi, yi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
    fx, fy = x - xi, y - yi
    best = np.full(np.shape(x), 9.0, np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            p = pts[(yi + dy) % period, (xi + dx) % period]
            d = np.hypot(dx + p[..., 0] - fx, dy + p[..., 1] - fy)
            best = np.minimum(best, d)
    return np.clip(best, 0, 1.5)


def polar(x, y):
    return np.sqrt(x * x + y * y), np.arctan2(y, x)


# ----------------------------------------------------------------------------- strokes
def segment_distance(x, y, a, b):
    """Distance from pixel coords (x, y) to segment a-b."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    if length < 1e-12:
        return np.hypot(x - ax, y - ay), np.zeros_like(x)
    t = np.clip(((x - ax) * dx + (y - ay) * dy) / length, 0, 1)
    return np.hypot(x - (ax + dx * t), y - (ay + dy * t)), t


def draw_strokes(x, y, strokes, glow=0.0, falloff=None):
    """strokes: list of (a, b, width, intensity). Returns (core, halo) max-combined fields.
    Each segment is evaluated only inside its padded bounding box, so hundreds stay cheap."""
    core = np.zeros_like(x)
    halo = np.zeros_like(x)
    h, w = x.shape
    x0, x1 = x[0, 0], x[0, -1]
    y0, y1 = y[0, 0], y[-1, 0]
    sx = (w - 1) / (x1 - x0)
    sy = (h - 1) / (y1 - y0)
    for a, b, width, intensity in strokes:
        pad = width * 3 + glow * 3
        lo_x, hi_x = min(a[0], b[0]) - pad, max(a[0], b[0]) + pad
        lo_y, hi_y = min(a[1], b[1]) - pad, max(a[1], b[1]) + pad
        c0 = int(np.clip(np.floor((lo_x - x0) * sx), 0, w))
        c1 = int(np.clip(np.ceil((hi_x - x0) * sx) + 1, 0, w))
        ra, rb = sorted((int(np.clip(np.floor((lo_y - y0) * sy), 0, h)), int(np.clip(np.ceil((hi_y - y0) * sy) + 1, 0, h))))
        if c1 <= c0 or rb <= ra:
            continue
        xs, ys = x[ra:rb, c0:c1], y[ra:rb, c0:c1]
        d, _ = segment_distance(xs, ys, a, b)
        core[ra:rb, c0:c1] = np.maximum(core[ra:rb, c0:c1], intensity * np.clip(1 - d / max(width, 1e-6), 0, 1) ** 0.6)
        if glow > 0:
            halo[ra:rb, c0:c1] = np.maximum(halo[ra:rb, c0:c1], intensity * np.exp(-(d / glow) ** 2))
    return core, halo


def bolt(rng, start, end, roughness=0.32, depth=6, branch=0.35, width=0.012, intensity=1.0, level=0):
    """Midpoint-displacement lightning: returns stroke list (main channel + forks)."""
    start, end = np.array(start, float), np.array(end, float)
    pts = [start, end]
    for _ in range(depth):
        new = [pts[0]]
        for p, q in zip(pts[:-1], pts[1:]):
            mid = (p + q) / 2
            d = q - p
            normal = np.array([-d[1], d[0]])
            mid = mid + normal * rng.normal(0, roughness * 0.5)
            new += [mid, q]
        pts = new
    strokes = []
    n = len(pts) - 1
    for i in range(n):
        taper = 1 - 0.55 * i / n
        strokes.append((tuple(pts[i]), tuple(pts[i + 1]), width * taper, intensity))
    if level < 2:
        for i in range(2, n - 2):
            if rng.random() < branch / (n / 8):
                p = pts[i]
                direction = pts[min(n, i + 3)] - p
                angle = rng.uniform(0.35, 0.9) * rng.choice([-1, 1])
                c, s = np.cos(angle), np.sin(angle)
                direction = np.array([direction[0] * c - direction[1] * s, direction[0] * s + direction[1] * c])
                length = rng.uniform(0.25, 0.6) * np.linalg.norm(end - start) * (1 - i / n)
                tip = p + direction / (np.linalg.norm(direction) + 1e-9) * length
                strokes += bolt(rng, p, tip, roughness, max(3, depth - 2), branch * 0.6, width * 0.55,
                                intensity * 0.7, level + 1)
    return strokes


def polygon_mask(x, y, pts):
    """Convex polygon (CCW points) -> inside mask and edge distance."""
    inside = np.ones_like(x, bool)
    edge = np.full_like(x, 9.0)
    for k in range(len(pts)):
        p0, p1 = pts[k], pts[(k + 1) % len(pts)]
        nx, ny = p1[1] - p0[1], -(p1[0] - p0[0])
        ln = np.hypot(nx, ny) + 1e-9
        d = ((x - p0[0]) * nx + (y - p0[1]) * ny) / ln
        inside &= d <= 0
        edge = np.minimum(edge, -d)
    return inside, edge


# ----------------------------------------------------------------------------- cel style
def dilate(mask, radius, wrap_u=False):
    """Binary-ish max filter with a disc footprint (radius in pixels)."""
    out = mask.copy()
    r = int(np.ceil(radius))
    padded = np.pad(mask, ((r, r), (r, r)), mode="wrap" if wrap_u else "constant")
    if wrap_u:  # only U (columns) tiles; rows must not wrap
        padded[:r], padded[-r:] = 0, 0
    h, w = mask.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= radius * radius:
                out = np.maximum(out, padded[r + dy:r + dy + h, r + dx:r + dx + w])
    return out


def cel_frame(rgba, bands=(0.42, 0.72), levels=(0.38, 0.7, 1.0), alpha_cut=0.3, outline_px=3.0,
              outline_lum=0.05, inner_ink=True, wrap_u=False):
    """Cel-shade one frame: hard silhouette, flat tone bands, dark ink outline.
    Grayscale stays grayscale, so tinting still works; ink stays near-black under any tint."""
    lum, alpha = rgba[..., 0], rgba[..., 3]
    aa = 0.035
    mask = smoothstep(alpha_cut - aa, alpha_cut + aa, alpha)
    tone = np.full_like(lum, levels[0])
    for edge, level in zip(bands, levels[1:]):
        tone = np.where(lum >= edge, level, tone) * 1.0
    # Soften band steps by one AA step so bands do not alias.
    soft = np.full_like(lum, levels[0])
    for edge, (lo, hi) in zip(bands, zip(levels[:-1], levels[1:])):
        soft = soft + (hi - lo) * smoothstep(edge - 0.015, edge + 0.015, lum)
    tone = soft
    if inner_ink:
        # Thin ink line where the darkest band meets the next: reads as hand-drawn form lines.
        line = smoothstep(0.03, 0.0, np.abs(lum - bands[0])) * (mask > 0.5)
        tone = tone * (1 - 0.75 * line)
    out_alpha = mask
    if outline_px > 0:
        ring = np.clip(dilate(mask, outline_px, wrap_u) - mask, 0, 1)
        tone = np.where(ring > mask, outline_lum, tone)
        out_alpha = np.maximum(out_alpha, ring)
    # Transparent texels take the ink tone so filtering never draws a light halo around shapes.
    tone = np.where(out_alpha < 1 / 255, outline_lum, tone)
    return np.dstack([tone, tone, tone, np.clip(out_alpha, 0, 1)])


def cel_image(img, layout=None, tiles=False, **opts):
    """Apply cel_frame per flipbook frame (no bleeding across cells)."""
    if not layout:
        size = min(img.shape[:2])
        opts.setdefault("outline_px", max(1.5, size / 110))
        return cel_frame(img, wrap_u=tiles, **opts)
    n = int(layout.replace("Grid", "").split("x")[0])
    s = img.shape[0] // n
    opts.setdefault("outline_px", max(1.5, s / 90))
    out = img.copy()
    for r in range(n):
        for c in range(n):
            cell = img[r * s:(r + 1) * s, c * s:(c + 1) * s]
            out[r * s:(r + 1) * s, c * s:(c + 1) * s] = cel_frame(cell, **opts)
    return out
