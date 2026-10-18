"""Generate the Enfleshed spell texture library (particles, flipbooks, trails, runes).

Run:  tools/vfx_pipeline/blender.sh tools/vfx_pipeline/gen_textures.py
(Any Python 3 with numpy works too:  python3 tools/vfx_pipeline/gen_textures.py <repo_root>)

Every texture is grayscale luminance + straight alpha so Roblox Color sequences tint it.
Writes assets/vfx/textures/<name>.png and textures.json (metadata consumed by build_manifest.py).
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (  # noqa: E402
    TAU, Noise, atlas, bleed, bolt, cel_image, draw_strokes, gray, grid, polar, polygon_mask, smoothstep, worley,
    write_png,
)

TEXTURES = {}


def texture(name, size, layout=None, fallback="Sparkle", usage="", tiles=False):
    def wrap(fn):
        TEXTURES[name] = dict(fn=fn, size=size, layout=layout, fallback=fallback, usage=usage, tiles=tiles)
        return fn

    return wrap


def frames_of(fn, count, size, **kw):
    return [fn(i / count, i, count, size, **kw) for i in range(count)]


# ============================================================================ soft energy
@texture("glow_soft", 256, fallback="Sparkle", usage="Soft energy bloom; core halos and charge glow.")
def glow_soft(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    n = Noise(11, (8, 8, 1))
    wobble = 1 + 0.06 * (n(np.cos(a) * 2 + 4, np.sin(a) * 2 + 4) - 0.5)
    rr = r * wobble
    core = np.exp(-(rr / 0.16) ** 2)
    halo = np.exp(-(rr / 0.45) ** 2) * 0.55
    alpha = np.clip(core + halo, 0, 1) * smoothstep(1.0, 0.82, r)
    lum = np.clip(0.55 + core * 0.45, 0, 1)
    return gray(lum, alpha)


@texture("core_plasma", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame turbulent energy core; projectile hearts, charge points.")
def core_plasma(size):
    n = Noise(23, (8, 8, 8))
    w = Noise(24, (8, 8, 8))

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        z = t * 8
        # Swirl: rotate angle by radius-dependent amount that animates.
        swirl = a + (1 - r) * 2.2 + t * TAU
        px, py = np.cos(swirl) * r * 3 + 4, np.sin(swirl) * r * 3 + 4
        warp = w.fbm(px, py, z, 3)
        f = n.fbm(px + warp * 2.5, py - warp * 2.5, z, 5)
        filaments = n.ridged(px * 0.8 + warp, py * 0.8, z, 3)
        body = smoothstep(0.92, 0.25, r + (f - 0.5) * 0.45)
        hot = np.exp(-(r / 0.22) ** 2)
        lum = np.clip(0.35 + 0.45 * filaments + 0.6 * hot, 0, 1)
        alpha = np.clip(body * (0.55 + 0.45 * filaments) + hot * 0.8, 0, 1) * smoothstep(1.0, 0.85, r)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


# ============================================================================ fire
def flame_frame(t, i, count, s, n=None, w=None, lean=0.0, loop=True):
    u, v, x, _ = grid(s)
    # Upward-scrolling turbulence: exactly one lattice period per loop keeps the flipbook seamless.
    scroll = t * 8 if loop else t * 4
    z = t * 8 if loop else 0.0
    rise = v * v
    warp = (w.fbm(u * 3, v * 3 - scroll, z, 3) - 0.5) * (0.15 + 0.85 * rise)
    xx = x + warp * 0.9 - lean * rise
    # Teardrop body: rounded base swelling to v~0.22, tapering to a point near the top.
    taper = np.power(np.clip((1 - v) / 0.78, 0, 1), 1.35)
    bulb = np.sqrt(np.clip(1 - ((0.22 - v) / 0.2) ** 2, 0, 1))
    width = 0.52 * np.where(v < 0.22, bulb, taper)
    lick = n.fbm(u * 4 + warp * 2, v * 4 - scroll * 1.5, z, 5)
    body = 1 - np.abs(xx) / np.maximum(width, 1e-3)
    # Erosion grows with height: solid base, tongues that tear off toward the tip.
    erosion = (lick - 0.5) * (0.4 + 2.2 * rise)
    shape = body + erosion
    alpha = smoothstep(0.0, 0.22, shape) * smoothstep(0.0, 0.04, v)
    inner = smoothstep(0.25, 0.85, body + erosion * 0.5) * smoothstep(0.95, 0.1, v)
    lum = np.clip(0.3 + 0.55 * inner + 0.25 * (lick - 0.5) + 0.15 * (1 - v), 0, 1)
    return bleed(gray(lum, alpha))


@texture("flame_tongue", 1024, layout="Grid4x4", fallback="Fire",
         usage="Looping 16-frame irregular flame silhouette; flame shells, fire trails, fields.")
def flame_tongue(size):
    n, w = Noise(31, (8, 8, 8)), Noise(32, (8, 8, 8))
    return atlas(frames_of(flame_frame, 16, size // 4, n=n, w=w), 4)


@texture("flame_wisp", 512, fallback="Fire", usage="Single static leaning flame lick; sparse secondary flames.")
def flame_wisp(size):
    n, w = Noise(41, (8, 8, 8)), Noise(42, (8, 8, 8))
    return flame_frame(0.37, 0, 1, size, n=n, w=w, lean=0.35)


@texture("ember_streak", 128, fallback="Sparkle", usage="Hot elongated spark; set Orientation=VelocityParallel.")
def ember_streak(size):
    _, _, x, y = grid(size)
    body = np.exp(-(x / 0.12) ** 2) * np.exp(-((y) / 0.75) ** 4)
    head = np.exp(-((x / 0.18) ** 2 + ((y - 0.45) / 0.22) ** 2))
    alpha = np.clip(body * smoothstep(-1, 0.6, y) + head, 0, 1)
    lum = np.clip(0.6 + head * 0.4, 0, 1)
    return gray(lum, alpha)


@texture("smoke_billow", 1024, layout="Grid4x4", fallback="Smoke",
         usage="16-frame OneShot smoke puff that billows then thins; impact smoke, dissipation.")
def smoke_billow(size):
    n, w = Noise(51, (8, 8, 8)), Noise(52, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, _ = polar(x, y)
        grow = 0.55 + 0.4 * np.sqrt(t)
        warp = w.fbm(u * 3, v * 3, t * 2, 3) - 0.5
        cells = 1 - worley(u * 6 + warp * 0.8, v * 6 - t * 1.2 + warp * 0.8, 6, 53)
        f = n.fbm(u * 4 + warp, v * 4 - t, t * 3, 4)
        billow = np.clip(cells * 0.65 + f * 0.55, 0, 1)
        outline = r / grow + (0.55 - billow) * 0.55
        lumps = smoothstep(1.0, 0.7, outline)
        thin = 1 - smoothstep(0.35, 1.0, t)
        alpha = lumps * (0.35 + 0.65 * billow) * thin
        # Self-shadowed puffs: lit cell crowns and tops, dark undersides.
        lum = np.clip(0.22 + 0.45 * cells ** 2 + 0.18 * y + 0.1 * f, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("explosion_fire", 1024, layout="Grid8x8", fallback="Fire",
         usage="64-frame OneShot fire burst: flash -> lobed fireball -> rolling smoke -> gone.")
def explosion_fire(size):
    n, w = Noise(61, (8, 8, 16)), Noise(62, (8, 8, 16))
    lobes_noise = Noise(63, (16, 2, 2))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, a = polar(x, y)
        e = 1 - (1 - t) ** 3  # ease-out expansion
        radius = 0.22 + 0.68 * e
        lobe = lobes_noise((a / TAU + 0.5) * 16, 0.5, 0.5) - 0.5
        warp = w.fbm(u * 3, v * 3, t * 6, 3) - 0.5
        # Billow cells roll outward with the expansion.
        cu, cv = x / (0.4 + e), y / (0.4 + e)
        cells = 1 - worley(cu * 3 + 8 + warp, cv * 3 + 8 + warp - t, 8, 64)
        f = n.fbm(u * 4 + warp * 2, v * 4 + warp * 2 - t * 1.5, t * 6, 5)
        billow = np.clip(cells * 0.7 + f * 0.5, 0, 1)
        edge = radius * (1 + lobe * 0.45 * e) + (billow - 0.55) * 0.3 * radius
        body = smoothstep(edge, edge * 0.8, r)
        # Interior burns out after the peak, leaving a ring of rolling smoke.
        hollow = smoothstep(0.4, 0.95, t) * smoothstep(edge * 0.7, 0.0, r) * 0.75
        density = body * (1 - hollow) * (0.55 + 0.45 * billow)
        flash = np.exp(-(r / (0.3 + t * 1.5)) ** 2) * max(0.0, 1 - t * 7)
        # Heat: hottest at cell crowns early, cooling into soot.
        cool = smoothstep(0.1, 0.6, t)
        heat = np.clip((billow * 1.1 - cool * 0.9) * smoothstep(edge, edge * 0.4, r) + 0.15 * (1 - cool), 0, 1)
        fade = 1 - smoothstep(0.72, 1.0, t)
        alpha = np.clip(density * fade + flash, 0, 1)
        lum = np.clip(0.12 + 0.88 * heat + flash, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 64, size // 8), 8)


# ============================================================================ impact / rings
@texture("shockwave_ring", 512, fallback="Sparkle",
         usage="Thin ragged ring with inner falloff; flat ring billboards and impact fronts.")
def shockwave_ring(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    n = Noise(71, (32, 4, 1))
    rag = n.fbm((a / TAU + 0.5) * 32, r * 4, 0, 3) - 0.5
    front = 0.86 + rag * 0.05
    ring = np.exp(-((r - front) / 0.035) ** 2)
    wake = smoothstep(front - 0.35, front, r) * smoothstep(front + 0.02, front - 0.02, r) * 0.35
    alpha = np.clip(ring + wake * (0.6 + rag), 0, 1) * smoothstep(1.0, 0.95, r)
    lum = np.clip(0.55 + ring * 0.45, 0, 1)
    return gray(lum, alpha)


@texture("impact_star", 512, fallback="Sparkle", usage="Irregular radial flash for the first frames of an impact.")
def impact_star(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    rng = np.random.default_rng(81)
    rays = np.zeros_like(r)
    for _ in range(14):
        ang = rng.uniform(-np.pi, np.pi)
        length = rng.uniform(0.45, 0.98)
        width = rng.uniform(0.02, 0.07)
        d = np.angle(np.exp(1j * (a - ang)))
        rays = np.maximum(rays, np.exp(-(d / width) ** 2) * smoothstep(length, 0.0, r))
    core = np.exp(-(r / 0.2) ** 2)
    alpha = np.clip(rays * 0.9 + core, 0, 1)
    return gray(np.clip(0.7 + core * 0.3, 0, 1), alpha)


@texture("slash_arc", 512, fallback="Sparkle", usage="Crescent slash with tapered tips and fibrous streaks.")
def slash_arc(size):
    u, v, x, y = grid(size)
    r, a = polar(x, y + 0.35)
    n = Noise(91, (4, 32, 1))
    span = smoothstep(-0.05, 0.6, a) * smoothstep(np.pi + 0.05, np.pi - 0.6, a)
    thick = 0.11 * np.sin(np.clip(a, 0, np.pi))
    streak = n.fbm(r * 4, (a / np.pi) * 32, 0, 2)
    band = smoothstep(thick, 0.0, np.abs(r - 0.72)) * span
    alpha = np.clip(band * (0.5 + 0.7 * streak), 0, 1)
    lum = np.clip(0.55 + 0.45 * smoothstep(thick * 0.6, 0, np.abs(r - 0.74)), 0, 1)
    return gray(lum, alpha)


@texture("debris_chip", 128, fallback="Sparkle", usage="Angular dark fragment silhouette with a hot rim.")
def debris_chip(size):
    _, _, x, y = grid(size)
    rng = np.random.default_rng(101)
    angles = np.sort(rng.uniform(0, TAU, 7))
    radii = rng.uniform(0.45, 0.85, 7)
    pts = np.stack([np.cos(angles) * radii, np.sin(angles) * radii], 1)
    inside = np.ones_like(x, bool)
    edge = np.full_like(x, 9.0)
    for k in range(len(pts)):
        p0, p1 = pts[k], pts[(k + 1) % len(pts)]
        nx, ny = p1[1] - p0[1], -(p1[0] - p0[0])
        ln = np.hypot(nx, ny)
        d = ((x - p0[0]) * nx + (y - p0[1]) * ny) / ln
        inside &= d <= 0
        edge = np.minimum(edge, -d)
    alpha = inside * smoothstep(0.0, 0.04, edge)
    lum = 0.25 + 0.75 * smoothstep(0.12, 0.0, edge)
    return gray(lum, alpha)


# ============================================================================ trails & beams (tile on U)
def strip(size_w, size_h):
    i = (np.arange(size_w) + 0.5) / size_w
    j = (np.arange(size_h) + 0.5) / size_h
    return np.meshgrid(i, j)


@texture("trail_flame", (512, 128), fallback="Fire", tiles=True,
         usage="U-tiling ragged flame streak for Trails (TextureMode Wrap/Stretch).")
def trail_flame(size):
    u, v = strip(*size)
    n = Noise(111, (16, 4, 1))
    y = v * 2 - 1
    f = n.fbm(u * 16, v * 4, 0, 4)
    lick = n.ridged(u * 16 + 3, v * 4 + 1, 0, 3)
    width = 0.55 + (f - 0.5) * 0.7
    core = smoothstep(width, width * 0.2, np.abs(y))
    alpha = np.clip(core * (0.45 + 0.75 * lick), 0, 1)
    lum = np.clip(0.4 + 0.6 * smoothstep(0.35, 0.0, np.abs(y)) * lick, 0, 1)
    return gray(lum, alpha)


@texture("beam_energy", (512, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling filament energy for Beams; scroll with TextureSpeed.")
def beam_energy(size):
    u, v = strip(*size)
    n = Noise(121, (8, 4, 1))
    y = v * 2 - 1
    acc = np.zeros_like(u)
    for k in range(3):
        path = (n.fbm(u * 8 + k * 2.7, k * 1.3, 0, 3) - 0.5) * 1.2
        acc = np.maximum(acc, np.exp(-((y - path) / 0.08) ** 2) * (0.6 + 0.4 * k / 2))
    core = np.exp(-(y / 0.3) ** 2) * 0.35
    alpha = np.clip(acc + core, 0, 1)
    return gray(np.clip(0.55 + acc * 0.45, 0, 1), alpha)


# ============================================================================ body / force
@texture("pressure_wave", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot directional pressure crescent; compressed air front for force magic.")
def pressure_wave(size):
    n = Noise(131, (16, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        # Crescent bowing toward +Y (up in the image = direction of travel).
        e = 1 - (1 - t) ** 2.2
        cy = -0.75 + 1.25 * e
        bow = 0.55 * x * x
        d = (y - cy + bow)
        width = 0.05 + 0.18 * e
        f = n.fbm(u * 16, v * 8, t * 8, 3)
        span = smoothstep(1.0, 0.45, np.abs(x)) * (0.7 + 0.6 * (f - 0.5))
        front = np.exp(-(d / (width * 0.35)) ** 2)
        compressed = smoothstep(-width * 2.5, 0, d) * smoothstep(width * 0.3, 0, d) * 0.55
        streaks = n.ridged(u * 16, (v - e) * 2, t * 2, 2)
        trail = smoothstep(-0.9, 0, d) * smoothstep(0.0, -0.02, d) * streaks * 0.35 * (1 - e)
        alpha = np.clip((front + compressed + trail) * span, 0, 1) * (1 - smoothstep(0.65, 1.0, t))
        lum = np.clip(0.45 + front * 0.55, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("force_streak", (512, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling speed lines for Trails/Beams on force and movement magic.")
def force_streak(size):
    u, v = strip(*size)
    rng = np.random.default_rng(141)
    acc = np.zeros_like(u)
    for _ in range(9):
        yc = rng.uniform(0.15, 0.85)
        start, length = rng.uniform(0, 1), rng.uniform(0.25, 0.7)
        w = rng.uniform(0.01, 0.035)
        du = (u - start) % 1.0
        along = smoothstep(0, 0.05, du) * smoothstep(length, length * 0.3, du)
        acc = np.maximum(acc, np.exp(-((v - yc) / w) ** 2) * along)
    return gray(np.clip(0.6 + acc * 0.4, 0, 1), acc)


@texture("sinew_trail", (512, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling twisting fibrous strands; organic/body trails and tethers.")
def sinew_trail(size):
    u, v = strip(*size)
    n = Noise(151, (8, 4, 1))
    y = v * 2 - 1
    acc = np.zeros_like(u)
    for k in range(5):
        phase = k / 5 * TAU
        path = 0.55 * np.sin(u * TAU * 2 + phase) * (0.6 + 0.4 * n(u * 8, k, 0))
        acc = np.maximum(acc, np.exp(-((y - path) / 0.07) ** 2))
    tissue = n.fbm(u * 8, v * 4, 0, 3)
    alpha = np.clip(acc * (0.55 + 0.6 * tissue), 0, 1)
    return gray(np.clip(0.35 + 0.5 * acc * tissue, 0, 1), alpha)


@texture("dust_burst", 512, fallback="Smoke", usage="Heavy grit cloud with clumped edges; ground kick-up for body impacts.")
def dust_burst(size):
    u, v, x, y = grid(size)
    r, a = polar(x, y)
    n = Noise(161, (8, 8, 1))
    f = n.fbm(u * 4, v * 4, 0, 5)
    grit = n(u * 64 % 8, v * 64 % 8, 0)
    body = smoothstep(0.95, 0.3, r + (f - 0.5) * 0.6)
    alpha = np.clip(body * (0.35 + 0.65 * f) * (0.75 + 0.25 * grit), 0, 1)
    return gray(np.clip(0.3 + 0.4 * f, 0, 1), alpha)


# ============================================================================ runes
@texture("rune_circle", 1024, fallback="Sparkle",
         usage="Industrial sigil: geared outer ring, angular glyph band, inner lattice. Ground casting circles.")
def rune_circle(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    rng = np.random.default_rng(171)
    ink = np.zeros_like(r)

    def ring(radius, width):
        return np.exp(-((r - radius) / width) ** 2)

    ink = np.maximum(ink, ring(0.95, 0.008))
    ink = np.maximum(ink, ring(0.88, 0.005))
    # Gear teeth between 0.88 and 0.95.
    teeth = (np.cos(a * 48) > 0.35) & (r > 0.885) & (r < 0.94)
    ink = np.maximum(ink, teeth * 0.85)
    # Glyph band: angular strokes in 24 cells.
    cells = 24
    cell = np.floor((a / TAU + 0.5) * cells).astype(int) % cells
    local = ((a / TAU + 0.5) * cells) % 1.0
    radial = (r - 0.66) / 0.17
    band = (radial > 0) & (radial < 1)
    strokes = np.zeros_like(r)
    for c in range(cells):
        sel = band & (cell == c)
        if not sel.any():
            continue
        for _ in range(rng.integers(2, 5)):
            x0, y0, x1, y1 = rng.uniform(0.15, 0.85, 4)
            if rng.random() < 0.5:
                x1 = x0  # vertical/horizontal bias = industrial, not calligraphic
            px, py = local[sel], radial[sel]
            dx, dy = x1 - x0, y1 - y0
            tt = np.clip(((px - x0) * dx + (py - y0) * dy) / max(dx * dx + dy * dy, 1e-6), 0, 1)
            d = np.hypot(px - (x0 + dx * tt), py - (y0 + dy * tt))
            strokes[sel] = np.maximum(strokes[sel], smoothstep(0.07, 0.03, d))
    ink = np.maximum(ink, strokes)
    ink = np.maximum(ink, ring(0.64, 0.006))
    ink = np.maximum(ink, ring(0.5, 0.004) * 0.8)
    # Inner lattice: hexagram of chords.
    for k in range(6):
        ang = k * TAU / 6
        nx, ny = np.cos(ang), np.sin(ang)
        d = np.abs(x * nx + y * ny - 0.25)
        ink = np.maximum(ink, smoothstep(0.008, 0.002, d) * (r < 0.5) * 0.9)
    ink = np.maximum(ink, ring(0.08, 0.02))
    return gray(np.full_like(r, 1.0), np.clip(ink, 0, 1))


@texture("heat_haze", 256, fallback="Smoke", tiles=True,
         usage="Very low-contrast shimmer noise; faked distortion via low-opacity overlay.")
def heat_haze(size):
    u, v, _, _ = grid(size)
    n = Noise(181, (8, 8, 1))
    f = n.fbm(u * 8, v * 8, 0, 4)
    rid = n.ridged(u * 8 + 2, v * 8, 0, 3)
    return gray(np.clip(0.5 + (f - 0.5) * 0.8, 0, 1), np.clip(rid * 0.6, 0, 1))



# ============================================================================ ice
@texture("frost_mist", 1024, layout="Grid4x4", fallback="Smoke",
         usage="Looping 16-frame curling cold fog with crystalline streaks; ice auras, fields, trails.")
def frost_mist(size):
    n, w = Noise(301, (8, 8, 8)), Noise(302, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, _ = polar(x, y)
        z = t * 8
        warp = w.fbm(u * 3 + t * 8, v * 3, z, 3) - 0.5
        f = n.fbm(u * 4 + warp * 1.5 + t * 8, v * 4 + warp, z, 5)
        streak = n.ridged(u * 2 + warp + t * 8, v * 8, z, 3)
        body = smoothstep(1.0, 0.45, r + (f - 0.5) * 0.6)
        alpha = body * (0.25 + 0.6 * smoothstep(0.35, 0.8, f) + 0.25 * streak ** 3)
        lum = np.clip(0.55 + 0.3 * f + 0.35 * streak ** 4, 0, 1)
        return bleed(gray(lum, alpha * 0.85))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("ice_glint", 256, fallback="Sparkle", usage="Six-point crystalline glint with diffraction spikes; frost motes.")
def ice_glint(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    spikes = np.zeros_like(r)
    for k in range(6):
        ang = k * TAU / 6 + np.pi / 2
        d = np.abs(np.sin(a - ang)) * r
        along = np.cos(a - ang) * r
        main = np.exp(-(d / 0.012) ** 2) * smoothstep(0.95, 0.0, r) * (along > 0)
        spikes = np.maximum(spikes, main)
        # small side barbs make it read as a snow crystal, not a plain star
        for frac in (0.35, 0.6):
            for sgn in (-1, 1):
                bx, by = np.cos(ang) * frac, np.sin(ang) * frac
                ba = ang + sgn * np.pi / 3
                ex, ey = bx + np.cos(ba) * 0.18 * (1 - frac), by + np.sin(ba) * 0.18 * (1 - frac)
                core, _ = draw_strokes(x, y, [((bx, by), (ex, ey), 0.012, 0.8)])
                spikes = np.maximum(spikes, core)
    core = np.exp(-(r / 0.07) ** 2)
    halo = np.exp(-(r / 0.3) ** 2) * 0.3
    alpha = np.clip(spikes + core + halo, 0, 1)
    return gray(np.clip(0.75 + core * 0.25, 0, 1), alpha)


@texture("ice_shatter", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot burst of angular ice shards flying out and fading; ice impacts.")
def ice_shatter(size):
    rng = np.random.default_rng(311)
    shards = []
    for _ in range(26):
        ang = rng.uniform(0, TAU)
        k = rng.integers(3, 6)
        base = rng.uniform(0.08, 0.19)
        poly = []
        for j in range(k):
            pa = j / k * TAU + rng.uniform(-0.4, 0.4)
            stretch = 1.9 if j == 0 else 1.0
            poly.append((np.cos(pa) * base * stretch, np.sin(pa) * base * 0.6))
        shards.append(dict(angle=ang, speed=rng.uniform(0.45, 0.95), spin=rng.uniform(-3, 3), poly=poly,
                           start=rng.uniform(0.0, 0.18)))

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, _ = polar(x, y)
        lum = np.zeros_like(x)
        alpha = np.zeros_like(x)
        e = 1 - (1 - t) ** 2.4
        for sh in shards:
            d = sh["start"] + sh["speed"] * e
            cx, cy = np.cos(sh["angle"]) * d, np.sin(sh["angle"]) * d - 0.25 * t * t
            rot = sh["angle"] + sh["spin"] * t
            c, sn = np.cos(rot), np.sin(rot)
            scale = 1 - 0.5 * t
            pts = [(cx + (px * c - py * sn) * scale, cy + (px * sn + py * c) * scale) for px, py in sh["poly"]]
            pts = sorted(pts, key=lambda p: np.arctan2(p[1] - cy, p[0] - cx))
            inside, edge = polygon_mask(x, y, pts)
            facet = 0.55 + 0.45 * np.clip(((x - cx) * c + (y - cy) * sn) * 12, -1, 1)
            rim = smoothstep(0.012, 0.0, edge)
            alpha = np.maximum(alpha, inside * smoothstep(0, 0.004, edge))
            lum = np.maximum(lum, inside * np.clip(facet * 0.7 + rim * 0.6, 0, 1))
        flash = np.exp(-(r / (0.15 + t * 0.5)) ** 2) * max(0.0, 1 - t * 5)
        fade = 1 - smoothstep(0.6, 1.0, t)
        return bleed(gray(np.clip(lum + flash, 0, 1), np.clip(alpha * fade + flash, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("frost_crack", 1024, fallback="Smoke",
         usage="Ground decal: branching frozen crack network with feathered frost, radial falloff; ice fields.")
def frost_crack(size):
    u, v, x, y = grid(size)
    r, a = polar(x, y)
    n = Noise(321, (8, 8, 1))
    warp = (n.fbm(u * 4, v * 4, 0, 3) - 0.5) * 0.6
    f1 = worley(u * 7 + warp, v * 7 - warp, 7, 322)
    f2 = worley(u * 7 + warp + 0.37, v * 7 - warp + 0.11, 7, 322, jitter=0.95)
    edges = smoothstep(0.08, 0.0, np.abs(f1 - f2) * 2.2 + (1 - smoothstep(0.0, 0.4, f1)) * 0.0)
    fine = worley(u * 19 + warp * 2, v * 19, 19, 323)
    fine_edges = smoothstep(0.06, 0.0, np.abs(fine - worley(u * 19 + warp * 2 + 0.21, v * 19 + 0.13, 19, 323)) * 2)
    frost = n.fbm(u * 16, v * 16, 0, 4)
    ice = smoothstep(1.0, 0.25, r + (frost - 0.5) * 0.5)
    alpha = np.clip(edges * 0.95 + fine_edges * 0.45 + ice * (0.18 + 0.25 * frost), 0, 1) * ice
    lum = np.clip(0.55 + edges * 0.45 + frost * 0.15, 0, 1)
    return gray(lum, alpha)


@texture("ice_trail", (512, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling crystalline streak with faceted shards along the edge; ice trails and beams.")
def ice_trail(size):
    u, v = strip(*size)
    y = v * 2 - 1
    n = Noise(331, (16, 4, 1))
    core = np.exp(-(y / 0.18) ** 2)
    # Saw-tooth facets: shards pointing back along the trail.
    saw = ((u * 24 + n(u * 16, 0, 0) * 2) % 1.0)
    teeth = smoothstep(0.55, 0.0, np.abs(y) - (1 - saw) * 0.6) * (np.abs(y) > 0.12)
    sparkle = n.ridged(u * 16, v * 4, 0, 2) ** 6
    alpha = np.clip(core * 0.9 + teeth * 0.55 + sparkle * 0.4, 0, 1)
    lum = np.clip(0.6 + core * 0.4 + sparkle * 0.3, 0, 1)
    return gray(lum, alpha)


# ============================================================================ lightning
@texture("bolt_strip", (1024, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling forked lightning channel with glow; Beams/Trails (animate TextureSpeed for crawl).")
def bolt_strip(size):
    w, h = size
    xs = (np.arange(w) + 0.5) / w * 8 - 4
    ys = (np.arange(h) + 0.5) / h - 0.5
    x, y = np.meshgrid(xs, ys)
    rng = np.random.default_rng(341)
    strokes = []
    # Chain bolts end to end so the strip tiles: start/end at y=0 on the wrap seam.
    pts = [(-4.0, 0.0), (-2.0, rng.uniform(-0.15, 0.15)), (0.0, rng.uniform(-0.15, 0.15)),
           (2.0, rng.uniform(-0.15, 0.15)), (4.0, 0.0)]
    for a, b in zip(pts[:-1], pts[1:]):
        strokes += bolt(rng, a, b, roughness=0.18, depth=6, branch=0.5, width=0.035)
    strokes = [s for s in strokes if abs(s[0][1]) < 0.48 and abs(s[1][1]) < 0.48]
    core, halo = draw_strokes(x, y, strokes, glow=0.1)
    alpha = np.clip(core + halo * 0.55, 0, 1)
    return gray(np.clip(0.55 + core * 0.45, 0, 1), alpha)


@texture("arc_flicker", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16 distinct crackling arc clusters (random-start Loop at high framerate); lightning motes, auras.")
def arc_flicker(size):
    rng = np.random.default_rng(351)

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        strokes = []
        for _ in range(rng.integers(2, 4)):
            a0 = rng.uniform(0, TAU)
            a1 = a0 + rng.uniform(1.2, 2.6)
            r0, r1 = rng.uniform(0.1, 0.35), rng.uniform(0.55, 0.85)
            strokes += bolt(rng, (np.cos(a0) * r0, np.sin(a0) * r0), (np.cos(a1) * r1, np.sin(a1) * r1),
                            roughness=0.35, depth=5, branch=0.6, width=0.02)
        core, halo = draw_strokes(x, y, strokes, glow=0.07)
        r, _ = polar(x, y)
        alpha = np.clip(core + halo * 0.5, 0, 1) * smoothstep(1.0, 0.85, r)
        return bleed(gray(np.clip(0.6 + core * 0.4, 0, 1), alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("spark_burst", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot electrical discharge: white flash, radial forks racing out, flicker off.")
def spark_burst(size):
    rng = np.random.default_rng(361)
    forks = []
    for k in range(9):
        ang = k / 9 * TAU + rng.uniform(-0.25, 0.25)
        end = (np.cos(ang) * rng.uniform(0.7, 0.95), np.sin(ang) * rng.uniform(0.7, 0.95))
        forks.append(bolt(rng, (0, 0), end, roughness=0.3, depth=6, branch=0.5, width=0.016))

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, _ = polar(x, y)
        reach = 0.15 + 0.95 * (1 - (1 - t) ** 3)
        strokes = []
        for fk in forks:
            strokes += [st for st in fk if max(np.hypot(*st[0]), np.hypot(*st[1])) < reach]
        # Flicker: forks drop out unevenly as the discharge dies.
        keep = rng.random(len(strokes)) > t * 0.8
        strokes = [st for st, kp in zip(strokes, keep) if kp]
        core, halo = draw_strokes(x, y, strokes, glow=0.05)
        flash = np.exp(-(r / (0.18 + t * 0.4)) ** 2) * max(0.0, 1 - t * 3.5)
        fade = 1 - smoothstep(0.55, 1.0, t)
        alpha = np.clip((core + halo * 0.6) * fade + flash, 0, 1)
        return bleed(gray(np.clip(0.6 + core * 0.4 + flash, 0, 1), alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("plasma_orb", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame ball of writhing electric filaments with hot center; lightning cores.")
def plasma_orb(size):
    n = Noise(371, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, a = polar(x, y)
        z = t * 8
        fil = np.zeros_like(r)
        for k in range(3):
            g = n.ridged(np.cos(a) * r * 3 + 4 + k * 1.7, np.sin(a) * r * 3 + 4, z + k * 2.3, 3)
            fil = np.maximum(fil, g ** 6)
        shell = smoothstep(0.9, 0.6, r)
        core = np.exp(-(r / 0.18) ** 2)
        rim = np.exp(-((r - 0.72) / 0.06) ** 2) * 0.4
        alpha = np.clip(fil * shell * 1.2 + core + rim, 0, 1)
        return bleed(gray(np.clip(0.55 + fil * 0.45 + core * 0.5, 0, 1), alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("scorch_lichtenberg", 1024, fallback="Smoke",
         usage="Ground decal: branching Lichtenberg burn figure with charred core; lightning strikes/fields.")
def scorch_lichtenberg(size):
    _, _, x, y = grid(size)
    r, _ = polar(x, y)
    rng = np.random.default_rng(381)
    strokes = []
    for k in range(7):
        ang = k / 7 * TAU + rng.uniform(-0.3, 0.3)
        strokes += bolt(rng, (0, 0), (np.cos(ang) * 0.9, np.sin(ang) * 0.9), roughness=0.4, depth=7,
                        branch=0.9, width=0.01)
    core, halo = draw_strokes(x, y, strokes, glow=0.025)
    n = Noise(382, (8, 8, 1))
    char = smoothstep(0.45, 0.0, r + (n.fbm(x * 2 + 4, y * 2 + 4, 0, 4) - 0.5) * 0.3)
    alpha = np.clip(core * 0.95 + halo * 0.4 + char * 0.75, 0, 1)
    lum = np.clip(0.15 + core * 0.8 - char * 0.1, 0, 1)
    return gray(lum, alpha)


# ============================================================================ water
@texture("water_splash", 1024, layout="Grid4x4", fallback="Smoke",
         usage="16-frame OneShot crown splash: sheet rises, breaks into droplets, falls; water impacts.")
def water_splash(size):
    rng = np.random.default_rng(391)
    drops = [dict(x=rng.uniform(-0.75, 0.75), vy=rng.uniform(1.4, 2.6), vx=rng.uniform(-0.5, 0.5),
                  r=rng.uniform(0.02, 0.05)) for _ in range(28)]
    n = Noise(392, (16, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        base = -0.75
        # Crown sheet: a rising, thinning wall with a torn rim.
        height = 0.9 * np.sin(np.clip(t * 1.6, 0, 1) * np.pi / 2) * (1 - smoothstep(0.45, 0.9, t))
        rim = n.fbm(u * 16, 0.5, t * 8, 3)
        # Crown: walls rise highest around |x|~0.55 and dip in the middle, so it reads hollow.
        crown = 0.3 + 0.7 * np.exp(-((np.abs(x) - 0.55) / 0.22) ** 2)
        top = base + height * 1.35 * (0.55 + 0.6 * rim) * crown * smoothstep(1.0, 0.75, np.abs(x))
        sheet = (y > base) & (y < top)
        thick = smoothstep(0.0, 0.08, top - y) * 0.5 + smoothstep(0.06, 0.0, top - y) * 0.6
        alpha = sheet * np.clip(thick, 0, 1) * smoothstep(0.95, 0.6, np.abs(x))
        lum = sheet * (0.5 + 0.5 * smoothstep(0.08, 0.0, top - y))
        for d in drops:
            tt = t * 0.9
            px = d["x"] * (0.6 + tt) + d["vx"] * tt
            py = base + d["vy"] * tt - 3.2 * tt * tt
            if tt < 0.08 or py < base - 0.1:
                continue
            ddist = np.hypot((x - px) * 1.0, (y - py) * 0.7)
            drop = smoothstep(d["r"], d["r"] * 0.4, ddist)
            alpha = np.maximum(alpha, drop)
            lum = np.maximum(lum, drop * (0.6 + 0.4 * smoothstep(d["r"] * 0.6, 0, np.hypot(x - px + d["r"] * 0.3, y - py - d["r"] * 0.3))))
        foam = smoothstep(0.12, 0.0, np.abs(y - base)) * smoothstep(1.0, 0.3, np.abs(x)) * (n.fbm(u * 16, v * 8, t * 8, 3) > 0.45)
        alpha = np.maximum(alpha, foam * (1 - t) * 0.8)
        fade = 1 - smoothstep(0.75, 1.0, t)
        return bleed(gray(np.clip(lum + foam * 0.5, 0, 1), alpha * fade))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("droplet", 128, fallback="Sparkle", usage="Teardrop water droplet with specular highlight; VelocityParallel spray.")
def droplet(size):
    _, _, x, y = grid(size)
    # Teardrop pointing up (trailing direction when VelocityParallel).
    yy = y + 0.25
    width = np.where(yy < 0, np.sqrt(np.clip(1 - (yy / 0.45) ** 2, 0, 1)) * 0.45,
                     0.45 * np.clip(1 - yy / 0.95, 0, 1) ** 1.6)
    body = smoothstep(0.02, -0.02, np.abs(x) - width)
    hl = np.exp(-(((x + 0.12) / 0.08) ** 2 + ((yy + 0.08) / 0.1) ** 2))
    rim = smoothstep(0.08, 0.0, width - np.abs(x)) * body
    return gray(np.clip(0.45 + rim * 0.35 + hl * 0.6, 0, 1), np.clip(body * (0.55 + rim * 0.4) + hl, 0, 1))


@texture("ripple_ring", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot concentric ripples expanding and fading; flat (ground-facing) water impacts/fields.")
def ripple_ring(size):
    n = Noise(401, (16, 4, 4))

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        wob = (n((a / TAU + 0.5) * 16, r * 4, t * 4) - 0.5) * 0.03
        acc = np.zeros_like(r)
        for k in range(3):
            tk = t - k * 0.12
            if tk <= 0:
                continue
            front = 0.08 + 0.85 * (1 - (1 - tk) ** 2)
            width = 0.012 + 0.02 * tk
            acc = np.maximum(acc, np.exp(-((r + wob - front) / width) ** 2) * (1 - tk) * (1 - 0.25 * k))
        return bleed(gray(np.clip(0.6 + acc * 0.4, 0, 1), np.clip(acc, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("water_orb", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame sphere of churning water with caustic highlights and bright rim; water cores.")
def water_orb(size):
    n = Noise(411, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, a = polar(x, y)
        z = t * 8
        # Spherical-ish mapping so caustics wrap around the ball.
        k = np.sqrt(np.clip(1 - (r / 0.8) ** 2, 0, 1))
        su, sv = x / (k + 0.4) + t * 8 / 4, y / (k + 0.4)
        c1 = worley(su * 3 + 8, sv * 3 + 8, 8, 412)
        caust = smoothstep(0.25, 0.0, c1) ** 1.5 * 0.0 + smoothstep(0.18, 0.02, np.abs(c1 - worley(su * 3 + 8.3, sv * 3 + 8.1, 8, 412)))
        swirl = n.fbm(np.cos(a + r * 3 + t * TAU) * r * 3 + 4, np.sin(a + r * 3 + t * TAU) * r * 3 + 4, z, 4)
        body = smoothstep(0.82, 0.76, r)
        rim = np.exp(-((r - 0.78) / 0.035) ** 2)
        spec = np.exp(-(((x + 0.3) / 0.12) ** 2 + ((y - 0.35) / 0.08) ** 2))
        alpha = np.clip(body * (0.45 + 0.35 * swirl) + rim * 0.8 + caust * body * 0.5 + spec, 0, 1)
        lum = np.clip(0.35 + 0.3 * swirl + caust * 0.5 + rim * 0.4 + spec, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("water_trail", (512, 128), fallback="Smoke", tiles=True,
         usage="U-tiling flowing water ribbon with foam edges and streaks; water trails/beams.")
def water_trail(size):
    u, v = strip(*size)
    y = v * 2 - 1
    n = Noise(421, (16, 4, 1))
    flow = n.fbm(u * 16, v * 4, 0, 4)
    streaks = n.ridged(u * 4, v * 16 % 4 + 0.0, 0, 3)
    width = 0.7 + (flow - 0.5) * 0.4
    body = smoothstep(width, width * 0.6, np.abs(y))
    foam = smoothstep(0.18, 0.0, np.abs(np.abs(y) - width * 0.82)) * (n.fbm(u * 16 + 3, v * 4, 0, 3) > 0.5)
    alpha = np.clip(body * (0.35 + 0.35 * streaks) + foam * 0.8, 0, 1)
    lum = np.clip(0.4 + 0.35 * streaks + foam * 0.5, 0, 1)
    return gray(lum, alpha)


@texture("caustics", 512, fallback="Sparkle", tiles=True,
         usage="Tiling underwater caustic light network; water fields/ground overlays (scroll or rotate).")
def caustics(size):
    u, v, _, _ = grid(size)
    n = Noise(431, (8, 8, 1))
    warp = (n.fbm(u * 4, v * 4, 0, 3) - 0.5) * 0.5
    a = worley(u * 6 + warp, v * 6 + warp, 6, 432)
    b = worley(u * 6 + warp + 0.33, v * 6 - warp + 0.17, 6, 433)
    net = smoothstep(0.12, 0.0, np.abs(a - b))
    return gray(np.clip(0.6 + net * 0.4, 0, 1), np.clip(net * 0.9, 0, 1))



# ============================================================================ earth (batch 2)
def random_chunk(rng, base, sides=None):
    sides = sides or rng.integers(4, 7)
    return [(np.cos(j / sides * TAU + rng.uniform(-0.35, 0.35)) * base * rng.uniform(0.7, 1.2),
             np.sin(j / sides * TAU + rng.uniform(-0.35, 0.35)) * base * rng.uniform(0.7, 1.2)) for j in range(sides)]


def draw_chunk(x, y, cx, cy, poly, rot, scale, lum, alpha, light=(0.6, 0.8)):
    c, sn = np.cos(rot), np.sin(rot)
    pts = [(cx + (px * c - py * sn) * scale, cy + (px * sn + py * c) * scale) for px, py in poly]
    pts = sorted(pts, key=lambda p: np.arctan2(p[1] - cy, p[0] - cx))
    inside, edge = polygon_mask(x, y, pts)
    # Two-tone faceting: lit upper-left half, shadowed lower-right half.
    lit = ((x - cx) * -light[0] + (y - cy) * light[1]) > 0
    tone = np.where(lit, 0.92, 0.62)
    alpha = np.maximum(alpha, inside * smoothstep(0, 0.004, edge))
    lum = np.where(inside, np.maximum(lum * 0, tone), lum)
    return lum, alpha


@texture("rock_burst", 1024, layout="Grid4x4", fallback="Smoke",
         usage="16-frame OneShot: faceted rock chunks blast outward and arc down with a grit cloud; earth impacts.")
def rock_burst(size):
    rng = np.random.default_rng(601)
    chunks = [dict(a=rng.uniform(0.15, np.pi - 0.15), v=rng.uniform(0.9, 1.7), poly=random_chunk(rng, rng.uniform(0.09, 0.17)),
                   spin=rng.uniform(-4, 4)) for _ in range(16)]
    n = Noise(602, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        lum = np.zeros_like(x)
        alpha = np.zeros_like(x)
        # Grit cloud first (behind chunks).
        r = np.hypot(x * 0.8, (y + 0.72) * 1.8)
        grow = 0.2 + 0.55 * np.sqrt(t)
        f = n.fbm(u * 4, v * 4 - t, t * 3, 4)
        cloud = smoothstep(grow, grow * 0.6, r + (f - 0.5) * 0.4) * (1 - smoothstep(0.5, 1.0, t))
        alpha = np.maximum(alpha, cloud * 0.9)
        lum = np.where(cloud > 0.3, 0.2 + 0.12 * f, lum)
        for ch in chunks:
            tt = t * 1.1
            cx = np.cos(ch["a"]) * ch["v"] * tt * 0.7
            cy = -0.6 + np.sin(ch["a"]) * ch["v"] * 1.6 * tt - 2.6 * tt * tt
            if cy < -0.95:
                continue
            lum, alpha = draw_chunk(x, y, cx, cy, ch["poly"], ch["spin"] * t, 1.0, lum, alpha)
        fade = 1 - smoothstep(0.8, 1.0, t)
        return bleed(gray(lum, alpha * fade))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("earth_fissure", 1024, fallback="Smoke",
         usage="Ground decal: radial fissures splitting from an impact point with broken slab edges; earth fields/impacts.")
def earth_fissure(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    rng = np.random.default_rng(611)
    strokes = []
    for k in range(9):
        ang = k / 9 * TAU + rng.uniform(-0.2, 0.2)
        strokes += bolt(rng, (0, 0), (np.cos(ang) * rng.uniform(0.6, 0.95), np.sin(ang) * rng.uniform(0.6, 0.95)),
                        roughness=0.22, depth=6, branch=0.4, width=0.022)
    # Concentric breaks join the radials into slabs.
    for ring_r in (0.28, 0.55):
        pts = [(np.cos(t) * ring_r * rng.uniform(0.9, 1.1), np.sin(t) * ring_r * rng.uniform(0.9, 1.1))
               for t in np.linspace(0, TAU, 14)]
        for p, q in zip(pts[:-1], pts[1:]):
            if rng.random() < 0.7:
                strokes.append((p, q, 0.012, 0.8))
    core, halo = draw_strokes(x, y, strokes, glow=0.03)
    crater = smoothstep(0.2, 0.0, r)
    alpha = np.clip(core + halo * 0.6 + crater * 0.8, 0, 1) * smoothstep(1.0, 0.85, r)
    return gray(np.clip(0.1 + core * 0.35 + crater * 0.15, 0, 1), alpha)


@texture("dust_plume", 1024, layout="Grid4x4", fallback="Smoke",
         usage="16-frame OneShot heavy dust plume rising and spreading (bottom-anchored); earth casts, slams.")
def dust_plume(size):
    n, w = Noise(621, (8, 8, 8)), Noise(622, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        grow = 0.45 + 0.6 * np.sqrt(t)
        cy = -0.7 + grow * 0.55
        warp = w.fbm(u * 3, v * 3 - t, t * 2, 3) - 0.5
        cells = 1 - worley(u * 5 + warp, v * 5 - t * 1.5 + warp, 5, 623)
        f = n.fbm(u * 4 + warp, v * 4 - t, t * 3, 4)
        billow = np.clip(cells * 0.6 + f * 0.6, 0, 1)
        shape = np.hypot(x / (0.55 * grow + 0.15), (y - cy) / (0.75 * grow))
        lumps = smoothstep(1.0, 0.75, shape + (0.55 - billow) * 0.5)
        alpha = lumps * (0.4 + 0.6 * billow) * (1 - smoothstep(0.55, 1.0, t))
        lum = np.clip(0.38 + 0.45 * cells ** 2 + 0.2 * (y - cy), 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("rubble_trail", (512, 128), fallback="Smoke", tiles=True,
         usage="U-tiling dragged grit and pebbles with a dust band; earth trails, ground-skimming projectiles.")
def rubble_trail(size):
    u, v = strip(*size)
    y = v * 2 - 1
    n = Noise(631, (16, 4, 1))
    band = smoothstep(0.7, 0.2, np.abs(y) + (n.fbm(u * 16, v * 4, 0, 3) - 0.5) * 0.5)
    pebbles = smoothstep(0.35, 0.1, worley(u * 32, v * 8, 32, 632)) * (np.abs(y) < 0.8)
    alpha = np.clip(band * 0.55 + pebbles * 0.9, 0, 1)
    return gray(np.clip(0.3 + pebbles * 0.45 + band * 0.1, 0, 1), alpha)


# ============================================================================ wind (batch 2)
@texture("wind_swirl", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame spiral of tapered gust strokes; wind cores, cyclones, auras.")
def wind_swirl(size):
    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        acc = np.zeros_like(r)
        for k in range(4):
            phase = k / 4 * TAU + t * TAU
            # Logarithmic spiral arm: angle grows with radius.
            arm = np.angle(np.exp(1j * (a - phase - np.log(r + 0.05) * 2.2)))
            width = 0.12 + 0.25 * r
            stroke = smoothstep(width, 0.0, np.abs(arm)) * smoothstep(0.08, 0.2, r) * smoothstep(0.95, 0.55, r)
            taper = smoothstep(-width, width * 0.4, arm)  # sharp leading edge, feathered tail
            acc = np.maximum(acc, stroke * taper)
        return bleed(gray(np.clip(0.6 + acc * 0.4, 0, 1), np.clip(acc * 1.2, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("gust_strokes", (512, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling curved brush-stroke gusts with hooked ends; wind trails and beams.")
def gust_strokes(size):
    u, v = strip(*size)
    rng = np.random.default_rng(641)
    acc = np.zeros_like(u)
    for _ in range(7):
        yc = rng.uniform(0.2, 0.8)
        start, length = rng.uniform(0, 1), rng.uniform(0.3, 0.6)
        du = (u - start) % 1.0
        k = np.clip(du / length, 0, 1)
        path = yc + 0.12 * np.sin(k * np.pi * 1.5) * rng.choice([-1, 1]) + 0.08 * k ** 3
        width = 0.035 * np.sin(np.clip(k, 0, 1) * np.pi) ** 0.7 + 0.004
        acc = np.maximum(acc, smoothstep(width, 0, np.abs(v - path)) * (du < length))
    return gray(np.clip(0.65 + acc * 0.35, 0, 1), acc)


@texture("leaf_scrap", 256, layout="Grid2x2", fallback="Sparkle",
         usage="4 torn leaf/ash scraps (random-start flipbook) for debris caught in wind.")
def leaf_scrap(size):
    rng = np.random.default_rng(651)

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        rot = rng.uniform(0, TAU)
        c, sn = np.cos(rot), np.sin(rot)
        xr, yr = x * c - y * sn, x * sn + y * c
        width = 0.38 * np.sqrt(np.clip(1 - (yr / 0.8) ** 2, 0, 1))
        n = Noise(652 + i, (8, 8, 1))
        tear = (n.fbm(xr * 2 + 4, yr * 2 + 4, 0, 3) - 0.5) * 0.25
        leaf = smoothstep(0.02, -0.02, np.abs(xr) - width - tear)
        vein = smoothstep(0.025, 0, np.abs(xr)) * leaf
        lum = np.where(xr > 0, 0.75, 0.5) * (1 - vein * 0.6)
        return bleed(gray(lum, leaf))

    return atlas(frames_of(frame, 4, size // 2), 2)


# ============================================================================ poison (batch 2)
@texture("toxic_bubble", 256, fallback="Sparkle",
         usage="Thick-rimmed bubble with crescent highlight and dark inner pool; poison motes, boiling fields.")
def toxic_bubble(size):
    _, _, x, y = grid(size)
    r, _ = polar(x, y)
    body = smoothstep(0.82, 0.78, r)
    rim = smoothstep(0.62, 0.78, r) * body
    hl = smoothstep(0.08, 0.0, np.abs(np.hypot(x + 0.22, y - 0.22) - 0.38)) * (x < 0) * (y > 0) * body
    spec = np.exp(-(((x + 0.35) / 0.07) ** 2 + ((y - 0.35) / 0.07) ** 2))
    alpha = np.clip(body * (0.45 + rim * 0.5) + hl + spec, 0, 1)
    return gray(np.clip(0.35 + rim * 0.35 + hl * 0.5 + spec, 0, 1), alpha)


@texture("miasma", 1024, layout="Grid4x4", fallback="Smoke",
         usage="Looping 16-frame lumpy toxic gas with dripping tendrils and dark pockets; poison clouds/fields.")
def miasma(size):
    n, w = Noise(661, (8, 8, 8)), Noise(662, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, _ = polar(x, y)
        z = t * 8
        warp = w.fbm(u * 3, v * 3 + t * 8, z, 3) - 0.5
        cells = 1 - worley(u * 4 + warp + t * 4, v * 4 + warp, 4, 663)
        f = n.fbm(u * 4 + warp, v * 4, z, 4)
        drip = smoothstep(0.6, 0.9, n.ridged(u * 8, v * 2 + t * 8, z, 2)) * (y < 0)
        shape = r + (0.55 - (cells * 0.6 + f * 0.5)) * 0.6 - drip * 0.25
        body = smoothstep(0.95, 0.75, shape)
        pockets = smoothstep(0.35, 0.15, cells)
        alpha = body * (0.55 + 0.45 * f)
        lum = np.clip(0.35 + 0.45 * cells ** 2 - pockets * 0.25, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("acid_splat", 1024, layout="Grid4x4", fallback="Smoke",
         usage="16-frame OneShot viscous splat: blob flattens, flings ropy droplets, then sizzles away; poison impacts.")
def acid_splat(size):
    rng = np.random.default_rng(671)
    ropes = [dict(a=rng.uniform(0, TAU), l=rng.uniform(0.5, 0.95), w=rng.uniform(0.03, 0.06)) for _ in range(11)]
    n = Noise(672, (16, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, a = polar(x, y)
        e = 1 - (1 - t) ** 3
        lobe = (n((a / TAU + 0.5) * 16, 0.5, t * 2) - 0.5) * 0.3
        body = smoothstep(0.32 * e + 0.1 + lobe * e, 0.25 * e + 0.08, r)
        alpha = body.copy()
        for rp in ropes:
            reach = rp["l"] * e
            d = np.abs(np.angle(np.exp(1j * (a - rp["a"])))) * r
            rope = smoothstep(rp["w"] * (1 - r / max(reach, 0.01)) + 0.004, 0.0, d) * (r < reach)
            tip = smoothstep(rp["w"] * 1.4, rp["w"] * 0.6, np.hypot(x - np.cos(rp["a"]) * reach, y - np.sin(rp["a"]) * reach))
            alpha = np.maximum(alpha, np.maximum(rope, tip) * (t > 0.05))
        sizzle = smoothstep(0.55, 1.0, t)
        holes = smoothstep(0.3, 0.2, worley(u * 10, v * 10, 10, 673)) * sizzle
        alpha = alpha * (1 - holes) * (1 - smoothstep(0.8, 1.0, t))
        lum = np.clip(0.5 + 0.3 * smoothstep(0.15, 0.0, r) + 0.2 * (n.fbm(u * 8, v * 8, t, 3) - 0.5), 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("toxic_pool", 1024, fallback="Smoke",
         usage="Ground decal: irregular bubbling toxic pool with splatter rim and burst-bubble rings; poison fields.")
def toxic_pool(size):
    u, v, x, y = grid(size)
    r, a = polar(x, y)
    n = Noise(681, (8, 8, 1))
    edge = 0.62 + (n.fbm(np.cos(a) * 1.5 + 4, np.sin(a) * 1.5 + 4, 0, 4) - 0.5) * 0.45
    pool = smoothstep(edge + 0.01, edge - 0.01, r)
    rng = np.random.default_rng(682)
    splats = np.zeros_like(r)
    for _ in range(26):
        ang, dist = rng.uniform(0, TAU), rng.uniform(0.6, 0.95)
        splats = np.maximum(splats, smoothstep(rng.uniform(0.02, 0.05), 0.0,
                                               np.hypot(x - np.cos(ang) * dist, y - np.sin(ang) * dist) - 0.01))
    rings = np.zeros_like(r)
    for _ in range(9):
        ang, dist, rr = rng.uniform(0, TAU), rng.uniform(0, 0.45), rng.uniform(0.04, 0.09)
        d = np.hypot(x - np.cos(ang) * dist, y - np.sin(ang) * dist)
        rings = np.maximum(rings, smoothstep(0.012, 0.0, np.abs(d - rr)))
    swirl = n.fbm(u * 6, v * 6, 0, 4)
    alpha = np.clip(pool * 0.85 + splats + rings * pool, 0, 1)
    lum = np.clip(0.3 + swirl * 0.3 + rings * 0.5 - smoothstep(edge, edge - 0.08, r) * 0.0, 0, 1)
    return gray(lum, alpha)


@texture("drip_trail", (512, 128), fallback="Smoke", tiles=True,
         usage="U-tiling viscous ribbon with hanging drips along the lower edge; poison trails.")
def drip_trail(size):
    u, v = strip(*size)
    y = v * 2 - 1
    n = Noise(691, (16, 4, 1))
    top = 0.35 + (n.fbm(u * 16, 0.3, 0, 3) - 0.5) * 0.3
    drip_len = smoothstep(0.55, 0.85, n(u * 16 * 2, 0.7, 0)) * 0.55
    bottom = -0.3 - drip_len * np.abs(np.sin(u * TAU * 8)) ** 6
    body = (y < top) & (y > bottom)
    alpha = body * 0.9
    lum = 0.4 + 0.35 * smoothstep(top - 0.15, top, y)
    return gray(np.clip(lum, 0, 1), alpha.astype(float))



# ============================================================================ arcane / neutral (batch 3)
def glyph_strokes(rng, scale=0.7, cx=0.0, cy=0.0):
    """One angular, industrial rune: 3-5 straight strokes on a coarse grid, plus a dot or bar."""
    grid_pts = [(gx, gy) for gx in (-1, 0, 1) for gy in (-1, -0.33, 0.33, 1)]
    strokes = []
    for _ in range(rng.integers(3, 6)):
        a, b = rng.choice(len(grid_pts), 2, replace=False)
        p, q = grid_pts[a], grid_pts[b]
        strokes.append(((cx + p[0] * scale * 0.5, cy + p[1] * scale), (cx + q[0] * scale * 0.5, cy + q[1] * scale),
                        0.05 * scale, 1.0))
    return strokes


@texture("arcane_glyphs", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16 distinct angular runes (random-start flipbook, Framerate 0) for arcane motes and orbiting glyphs.")
def arcane_glyphs(size):
    rng = np.random.default_rng(801)

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        core, halo = draw_strokes(x, y, glyph_strokes(rng), glow=0.06)
        return bleed(gray(np.clip(0.7 + core * 0.3, 0, 1), np.clip(core + halo * 0.35, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("arcane_orb", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame geometric core: counter-rotating nested polygons and a star around a bright eye.")
def arcane_orb(size):
    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        strokes = []
        for k, (sides, rad, spin) in enumerate(((3, 0.82, 1), (4, 0.62, -1), (6, 0.42, 2))):
            rot = spin * t * TAU / sides
            pts = [(np.cos(j / sides * TAU + rot) * rad, np.sin(j / sides * TAU + rot) * rad) for j in range(sides)]
            for j in range(sides):
                strokes.append((pts[j], pts[(j + 1) % sides], 0.018, 1.0 - k * 0.15))
        core, halo = draw_strokes(x, y, strokes, glow=0.05)
        eye = smoothstep(0.2, 0.17, r)
        pupil = smoothstep(0.08, 0.06, np.hypot(x * 2.2, y)) 
        ring = np.exp(-((r - 0.9) / 0.02) ** 2)
        alpha = np.clip(core + halo * 0.4 + eye + ring, 0, 1)
        lum = np.clip(0.65 + core * 0.35 + eye * 0.35 - pupil * 0.9, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("arcane_burst", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot: hexagram flash, expanding polygon rings and glyph shards flung out; arcane impacts.")
def arcane_burst(size):
    rng = np.random.default_rng(811)
    shards = [dict(a=rng.uniform(0, TAU), v=rng.uniform(0.5, 0.95), seed=int(rng.integers(1 << 30))) for _ in range(8)]

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, _ = polar(x, y)
        e = 1 - (1 - t) ** 3
        strokes = []
        for k, sides in enumerate((6, 3)):
            rad = 0.15 + e * (0.85 - k * 0.2)
            rot = k * 0.5 + t
            pts = [(np.cos(j / sides * TAU + rot) * rad, np.sin(j / sides * TAU + rot) * rad) for j in range(sides)]
            for j in range(sides):
                strokes.append((pts[j], pts[(j + 1) % sides], 0.02 * (1 - t), 1.0))
        for sh in shards:
            d = sh["v"] * e
            strokes += glyph_strokes(np.random.default_rng(sh["seed"]), 0.16 * (1 - 0.5 * t),
                                     np.cos(sh["a"]) * d, np.sin(sh["a"]) * d)
        core, halo = draw_strokes(x, y, strokes, glow=0.04)
        flash = smoothstep(0.35 * (1 - t) + 0.05, 0.0, r) * max(0.0, 1 - t * 4)
        fade = 1 - smoothstep(0.65, 1.0, t)
        return bleed(gray(np.clip(0.65 + core * 0.35 + flash, 0, 1), np.clip((core + halo * 0.4) * fade + flash, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("glyph_chain", (1024, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling chain of runes between two rails; arcane beams, trails, binding tethers.")
def glyph_chain(size):
    w, h = size
    xs = (np.arange(w) + 0.5) / w * 8
    ys = (np.arange(h) + 0.5) / h - 0.5
    x, y = np.meshgrid(xs, ys)
    rng = np.random.default_rng(821)
    strokes = [((-1, -0.36), (9, -0.36), 0.02, 0.8), ((-1, 0.36), (9, 0.36), 0.02, 0.8)]
    for k in range(8):
        strokes += glyph_strokes(rng, 0.26, k + 0.5, 0.0)
    core, halo = draw_strokes(x, y, strokes, glow=0.05)
    return gray(np.clip(0.7 + core * 0.3, 0, 1), np.clip(core + halo * 0.3, 0, 1))


@texture("hex_seal", 1024, fallback="Sparkle",
         usage="Ground decal: hexagonal ward seal, spoked lattice and corner glyphs; arcane fields, wards, shields.")
def hex_seal(size):
    _, _, x, y = grid(size)
    rng = np.random.default_rng(831)
    strokes = []
    for rad, w in ((0.92, 0.012), (0.84, 0.006), (0.5, 0.008)):
        pts = [(np.cos(j / 6 * TAU) * rad, np.sin(j / 6 * TAU) * rad) for j in range(6)]
        strokes += [(pts[j], pts[(j + 1) % 6], w, 1.0) for j in range(6)]
    for j in range(6):
        a = j / 6 * TAU
        strokes.append(((np.cos(a) * 0.5, np.sin(a) * 0.5), (np.cos(a) * 0.84, np.sin(a) * 0.84), 0.006, 0.9))
        b = a + TAU / 12
        strokes += glyph_strokes(rng, 0.08, np.cos(b) * 0.68, np.sin(b) * 0.68)
    tri = [(np.cos(j / 3 * TAU + np.pi / 2) * 0.48, np.sin(j / 3 * TAU + np.pi / 2) * 0.48) for j in range(3)]
    strokes += [(tri[j], tri[(j + 1) % 3], 0.006, 0.9) for j in range(3)]
    core, halo = draw_strokes(x, y, strokes, glow=0.02)
    r, _ = polar(x, y)
    eye = smoothstep(0.1, 0.09, r) - smoothstep(0.05, 0.04, r)
    return gray(np.full_like(x, 1.0), np.clip(core + halo * 0.3 + eye, 0, 1))


# ============================================================================ force (batch 3)
@texture("kinetic_burst", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot: hard concentric shock rings with radial speed lines punching outward; force impacts.")
def kinetic_burst(size):
    rng = np.random.default_rng(841)
    lines = [(rng.uniform(0, TAU), rng.uniform(0.0, 0.25), rng.uniform(0.012, 0.03)) for _ in range(22)]

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        e = 1 - (1 - t) ** 2.5
        acc = np.zeros_like(r)
        for k in range(2):
            front = (0.2 + 0.75 * e) * (1 - 0.3 * k)
            acc = np.maximum(acc, smoothstep(0.045 * (1 - t) + 0.008, 0, np.abs(r - front)))
        for ang, delay, w in lines:
            d = np.abs(np.angle(np.exp(1j * (a - ang)))) * r
            inner = 0.25 + e * 0.5 - delay
            outer = inner + 0.35 * (1 - t)
            acc = np.maximum(acc, smoothstep(w, 0, d) * (r > inner) * (r < outer))
        flash = smoothstep(0.3, 0.0, r) * max(0.0, 1 - t * 5)
        fade = 1 - smoothstep(0.6, 1.0, t)
        return bleed(gray(np.clip(0.7 + acc * 0.3 + flash, 0, 1), np.clip(acc * fade + flash, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("ward_hex", 512, fallback="Sparkle", tiles=True,
         usage="Tiling hexagonal barrier lattice with bright cell edges; shields, wards, force fields (MeshPart/Beam).")
def ward_hex(size):
    u, v, _, _ = grid(size)
    # Hex grid distance (tileable: 4 x 2*sqrt(3) cells fit the square closely; slight stretch is fine).
    q = u * 6
    rr = v * 6 / (np.sqrt(3) / 2) / (6 / (6 * np.sqrt(3) / 2 * 2 / np.sqrt(3)))
    px, py = u * 8, v * 8 * np.sqrt(3) / 2 * 2 / np.sqrt(3)
    ax = np.stack([px, py], -1)

    def hexdist(p):
        p = np.abs(p)
        return np.maximum(p[..., 0] * 0.866 + p[..., 1] * 0.5, p[..., 1])

    sx, sy = 1.0, np.sqrt(3)
    a_ = np.stack([(px % sx) - sx / 2, (py % sy) - sy / 2], -1)
    b_ = np.stack([((px - sx / 2) % sx) - sx / 2, ((py - sy / 2) % sy) - sy / 2], -1)
    da, db = hexdist(a_[..., ::-1]), hexdist(b_[..., ::-1])
    d = np.minimum(da, db)
    edge = smoothstep(0.43, 0.48, d)
    inner = smoothstep(0.3, 0.45, d) * 0.25
    return gray(np.clip(0.6 + edge * 0.4, 0, 1), np.clip(edge * 0.95 + inner, 0, 1))


@texture("impact_frame", 512, fallback="Sparkle",
         usage="Single-frame stylized impact: jagged star-burst with ink speed wedges, for 1-2 frame hit flashes.")
def impact_frame(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    rng = np.random.default_rng(851)
    spikes = 11
    radius = np.zeros_like(r)
    base = rng.uniform(0.55, 0.95, spikes)
    for k in range(spikes):
        ang = k / spikes * TAU
        d = np.abs(np.angle(np.exp(1j * (a - ang))))
        radius = np.maximum(radius, base[k] * np.clip(1 - d / (TAU / spikes) * 1.6, 0, 1))
    radius = np.maximum(radius, 0.32)
    star = smoothstep(0.01, -0.01, r - radius)
    inner = smoothstep(0.01, -0.01, r - radius * 0.55)
    return gray(np.where(inner > 0.5, 1.0, 0.62), star)


# ============================================================================ spirit / soul (batch 3)
@texture("soul_wisp", 1024, layout="Grid4x4", fallback="Fire",
         usage="Looping 16-frame wailing ghost wisp: tattered rising flame shape with two hollow eyes and a mouth.")
def soul_wisp(size):
    n, w = Noise(861, (8, 8, 8)), Noise(862, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        body = flame_frame(t, i, count, s, n=n, w=w)[..., 3]
        # Face sits in the bulb; it sways with the flame's low-frequency warp.
        sway = (w.fbm(np.array(0.5) * 3, np.array(0.3) * 3 - t * 8, t * 8, 3) - 0.5) * 0.25
        fx, fy = x - sway, y + 0.42
        eyes = np.zeros_like(x)
        for sx in (-0.13, 0.13):
            eyes = np.maximum(eyes, smoothstep(0.075, 0.06, np.hypot((fx - sx) * 1.0, (fy - 0.05) * 0.75)))
        wail = 0.04 + 0.025 * np.sin(t * TAU)
        mouth = smoothstep(wail + 0.01, wail, np.hypot(fx * 1.6, (fy + 0.17) * 0.9))
        hollow = np.maximum(eyes, mouth) * (body > 0.5)
        lum = np.clip(0.55 + 0.4 * smoothstep(-0.9, 0.0, -np.abs(x) * 2 + 0.0) - hollow * 0.6, 0, 1)
        lum = np.where(hollow > 0.5, 0.05, lum)
        return bleed(gray(lum, body))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("ghost_trail", (512, 128), fallback="Smoke", tiles=True,
         usage="U-tiling tattered spectral ribbon with torn holes and trailing wisps; spirit trails, tethers.")
def ghost_trail(size):
    u, v = strip(*size)
    y = v * 2 - 1
    n = Noise(871, (16, 4, 1))
    f = n.fbm(u * 16, v * 4, 0, 4)
    width = 0.55 + (f - 0.5) * 0.6
    body = smoothstep(width, width * 0.7, np.abs(y))
    holes = smoothstep(0.32, 0.22, worley(u * 16, v * 3, 16, 872))
    strands = n.ridged(u * 4, v * 12 % 4, 0, 3) ** 3 * smoothstep(1.0, 0.5, np.abs(y))
    alpha = np.clip(body * (1 - holes) * 0.85 + strands * 0.4, 0, 1)
    return gray(np.clip(0.55 + 0.3 * f + strands * 0.2, 0, 1), alpha)


@texture("soul_burst", 1024, layout="Grid4x4", fallback="Smoke",
         usage="16-frame OneShot: hollow-eyed wisps tear outward from a dark core and dissolve; spirit impacts.")
def soul_burst(size):
    n, w = Noise(881, (8, 8, 8)), Noise(882, (8, 8, 8))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        r, a = polar(x, y)
        e = 1 - (1 - t) ** 2
        arms = 7
        warp = (w.fbm(u * 3, v * 3, t * 4, 3) - 0.5) * 0.6
        arm = np.cos((a + warp + r * 1.5) * arms) * 0.5 + 0.5
        reach = 0.2 + 0.75 * e
        f = n.fbm(u * 4 + warp, v * 4, t * 4, 4)
        shape = smoothstep(reach, reach * 0.5, r) * smoothstep(0.25, 0.75, arm + (f - 0.5) * 0.6)
        core = smoothstep(0.25 * (1 - t), 0.1 * (1 - t), r)
        dissolve = smoothstep(0.35, 1.0, t)
        holes = smoothstep(0.55 - dissolve * 0.5, 0.45 - dissolve * 0.5, f)
        alpha = np.clip(shape * (1 - holes * dissolve) + core, 0, 1) * (1 - smoothstep(0.85, 1.0, t))
        lum = np.clip(0.55 + 0.35 * f - core * 0.5, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("skull_mote", 256, fallback="Sparkle", usage="Stylized horned skull icon; spirit motes, curse marks, death accents.")
def skull_mote(size):
    _, _, x, y = grid(size)
    cranium = smoothstep(0.02, -0.02, np.hypot(x * 1.0, (y - 0.12) * 1.05) - 0.5)
    jaw = smoothstep(0.02, -0.02, np.maximum(np.abs(x) - 0.28, np.abs(y + 0.42) - 0.16))
    horns = np.zeros_like(x)
    for side in (-1, 1):
        hx, hy = x * side - 0.42, y - 0.35
        horn = smoothstep(0.02, -0.02, np.hypot(hx, hy) - 0.2 * np.clip(1 - (hx + 0.1) * 2.5, 0, 1)) * (hy > -0.05)
        horns = np.maximum(horns, horn * (hx > -0.1))
    head = np.clip(cranium + jaw + horns, 0, 1)
    eyes = np.zeros_like(x)
    for side in (-1, 1):
        eyes = np.maximum(eyes, smoothstep(0.02, -0.02, np.hypot((x - side * 0.19), (y - 0.05) * 1.2) - 0.13))
    nose = smoothstep(0.02, -0.02, np.abs(x) * 1.6 + (y + 0.18) * 1.2 - 0.08) * (y < -0.1) * (y > -0.26)
    teeth = (np.abs(((x + 0.28) * 7) % 1 - 0.5) < 0.08) * (np.abs(y + 0.4) < 0.12) * (np.abs(x) < 0.27)
    holes = np.clip(eyes + nose + teeth, 0, 1)
    lum = np.where(holes > 0.5, 0.05, np.where(x < 0, 0.95, 0.68))
    return gray(lum, head)


@texture("soul_sigil", 1024, fallback="Sparkle",
         usage="Ground decal: sunken eye within thorned rings and spectral script; spirit fields, curses, summons.")
def soul_sigil(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    rng = np.random.default_rng(891)
    ring = np.exp(-((r - 0.9) / 0.012) ** 2) + np.exp(-((r - 0.72) / 0.008) ** 2)
    thorns = np.zeros_like(r)
    for k in range(24):
        ang = k / 24 * TAU
        d = np.abs(np.angle(np.exp(1j * (a - ang)))) * r
        thorns = np.maximum(thorns, smoothstep(0.025 * (0.98 - r) / 0.08, 0, d) * (r > 0.9) * (r < 0.98))
    strokes = []
    for k in range(12):
        b = k / 12 * TAU
        strokes += glyph_strokes(rng, 0.06, np.cos(b) * 0.81, np.sin(b) * 0.81)
    script, _ = draw_strokes(x, y, strokes)
    eye_shape = np.abs(y) < 0.28 * np.clip(1 - (x / 0.55) ** 2, 0, 1)
    eye_line = smoothstep(0.012, 0, np.abs(np.abs(y) - 0.28 * np.clip(1 - (x / 0.55) ** 2, 0, 1))) * (np.abs(x) < 0.55)
    iris = smoothstep(0.012, 0, np.abs(r - 0.18)) + smoothstep(0.09, 0.08, r)
    alpha = np.clip(ring + thorns + script + eye_line + iris * eye_shape, 0, 1)
    return gray(np.ones_like(r), alpha)



# ============================================================================ space (batch 4)
@texture("rift_tear", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot jagged tear in space: splits open on a void, holds, seals shut; space casts/portals.")
def rift_tear(size):
    n = Noise(901, (16, 8, 1))

    def frame(t, i, count, s):
        u, v, x, y = grid(s)
        openness = np.sin(np.clip(t * 1.25, 0, 1) * np.pi) ** 0.6
        # Lens-shaped opening whose edges are ragged and lightning-like.
        jag = (n(u * 16, v * 2, 0) - 0.5) * 0.12 + (n(u * 48 % 16, v * 4, 0) - 0.5) * 0.05
        half = 0.32 * openness * np.clip(1 - (y / 0.88) ** 2, 0, 1) + jag * openness
        d = np.abs(x) - half
        void = smoothstep(0.01, -0.01, d)
        rim = smoothstep(0.035, 0.0, np.abs(d)) * (np.abs(y) < 0.9) * (openness > 0.02)
        stars = (n(u * 64 % 16, v * 64 % 8, 0) > 0.78) * void
        lum = np.where(void > 0.5, 0.03 + stars * 0.9, 1.0)
        alpha = np.clip(void + rim, 0, 1)
        lum = np.where(rim > 0.5, 1.0, lum)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("void_orb", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame black hole: dark core, bright lensed ring and spiralling accretion streaks.")
def void_orb(size):
    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        hole = smoothstep(0.31, 0.29, r)
        ring = smoothstep(0.035, 0.0, np.abs(r - 0.34))
        acc = np.zeros_like(r)
        for k in range(3):
            arm = np.angle(np.exp(1j * (a - t * TAU - k * TAU / 3 + np.log(r + 0.05) * 3.5)))
            acc = np.maximum(acc, smoothstep(0.35, 0.0, np.abs(arm)) * smoothstep(0.34, 0.45, r) * smoothstep(0.92, 0.55, r))
        lum = np.where(hole > 0.5, 0.0, np.clip(0.55 + ring * 0.45 + acc * 0.3, 0, 1))
        alpha = np.clip(hole + ring + acc * 0.85, 0, 1)
        return bleed(gray(lum, alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("warp_implode", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="16-frame OneShot: rings and debris streaks collapse inward to a point, then a sharp pop; teleports.")
def warp_implode(size):
    rng = np.random.default_rng(911)
    streaks = [(rng.uniform(0, TAU), rng.uniform(0.6, 1.0)) for _ in range(18)]

    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        collapse = np.clip(t / 0.7, 0, 1)
        acc = np.zeros_like(r)
        for k in range(3):
            rad = (0.95 - k * 0.15) * (1 - collapse ** 1.5)
            acc = np.maximum(acc, smoothstep(0.02, 0.0, np.abs(r - rad)) * (rad > 0.02))
        for ang, start in streaks:
            head = start * (1 - collapse ** 1.3)
            d = np.abs(np.angle(np.exp(1j * (a - ang)))) * r
            acc = np.maximum(acc, smoothstep(0.012, 0.0, d) * (r > head) * (r < head + 0.18) * (collapse < 0.98))
        pop_t = np.clip((t - 0.7) / 0.3, 0, 1)
        pop = smoothstep(0.03, 0.0, np.abs(r - pop_t * 0.6)) * (pop_t > 0) * (1 - pop_t)
        core = smoothstep(0.08, 0.0, r) * (t > 0.6) * (1 - pop_t)
        return bleed(gray(np.clip(0.75 + acc * 0.25, 0, 1), np.clip(acc + pop + core, 0, 1)))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("star_mote", 128, fallback="Sparkle", usage="Four-point star with long vertical spike; space motes, void sparkle.")
def star_mote(size):
    _, _, x, y = grid(size)
    star = np.maximum(smoothstep(0.06, 0.0, np.abs(x) * 4 + np.abs(y) - 0.95),
                      smoothstep(0.06, 0.0, np.abs(x) + np.abs(y) * 2.4 - 0.65))
    return gray(np.ones_like(x), np.clip(star, 0, 1))


@texture("shard_trail", (512, 128), fallback="Sparkle", tiles=True,
         usage="U-tiling stream of broken-glass reality shards with void gaps; space trails, folds.")
def shard_trail(size):
    u, v = strip(*size)
    rng = np.random.default_rng(921)
    w, h = size
    x, y = u * 8, v * 2 - 1
    lum = np.zeros_like(x)
    alpha = np.zeros_like(x)
    for _ in range(26):
        cx, cy = rng.uniform(0, 8), rng.uniform(-0.6, 0.6)
        poly = [(np.cos(j / 3 * TAU + rng.uniform(-0.4, 0.4)) * rng.uniform(0.08, 0.18) * 1.6,
                 np.sin(j / 3 * TAU + rng.uniform(-0.4, 0.4)) * rng.uniform(0.08, 0.18) * 2) for j in range(3)]
        for wrap in (-8, 0, 8):
            pts = sorted([(cx + wrap + px, cy + py) for px, py in poly],
                         key=lambda p: np.arctan2(p[1] - cy, p[0] - cx - wrap))
            inside, edge = polygon_mask(x, y, pts)
            alpha = np.maximum(alpha, inside * 1.0)
            lum = np.where(inside, np.where(edge < 0.02, 1.0, 0.15), lum)
    return gray(lum, alpha)


@texture("portal_rings", 1024, fallback="Sparkle",
         usage="Ground/portal decal: warped concentric rings around a void centre with orbiting stars; space fields.")
def portal_rings(size):
    u, v, x, y = grid(size)
    r, a = polar(x, y)
    n = Noise(931, (16, 4, 1))
    warp = (n((a / TAU + 0.5) * 16, r * 4, 0) - 0.5) * 0.05
    rings = np.zeros_like(r)
    for k, rad in enumerate((0.92, 0.78, 0.62, 0.47)):
        rings = np.maximum(rings, smoothstep(0.012 + 0.004 * k, 0.0, np.abs(r + warp * (k + 1) - rad)))
    void = smoothstep(0.36, 0.34, r)
    rng = np.random.default_rng(932)
    stars = np.zeros_like(r)
    for _ in range(18):
        ang, dist = rng.uniform(0, TAU), rng.uniform(0.4, 0.95)
        sx, sy = x - np.cos(ang) * dist, y - np.sin(ang) * dist
        stars = np.maximum(stars, smoothstep(0.03, 0.0, np.abs(sx) * 3 + np.abs(sy) - 0.03) +
                           smoothstep(0.03, 0.0, np.abs(sx) + np.abs(sy) * 3 - 0.03))
    lum = np.where(void > 0.5, 0.02, 1.0)
    return gray(lum, np.clip(rings + void * 0.95 + stars, 0, 1))


# ============================================================================ time (batch 4)
@texture("clock_dial", 1024, fallback="Sparkle",
         usage="Ground decal: broken clock face with 12 hour marks, minute ticks, numeral glyphs and two hands; time fields.")
def clock_dial(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    rng = np.random.default_rng(941)
    strokes = []
    for k in range(60):
        ang = k / 60 * TAU
        inner = 0.8 if k % 5 else 0.7
        strokes.append(((np.cos(ang) * inner, np.sin(ang) * inner), (np.cos(ang) * 0.88, np.sin(ang) * 0.88),
                        0.006 if k % 5 else 0.014, 1.0))
    for k in range(12):
        ang = k / 12 * TAU
        strokes += glyph_strokes(rng, 0.05, np.cos(ang) * 0.58, np.sin(ang) * 0.58)
    strokes.append(((0, 0), (np.cos(1.1) * 0.5, np.sin(1.1) * 0.5), 0.022, 1.0))
    strokes.append(((0, 0), (np.cos(-0.6) * 0.75, np.sin(-0.6) * 0.75), 0.012, 1.0))
    core, _ = draw_strokes(x, y, strokes)
    rims = smoothstep(0.012, 0.0, np.abs(r - 0.93)) + smoothstep(0.006, 0.0, np.abs(r - 0.9))
    # A missing wedge makes it a broken, ominous dial rather than a plain clock.
    crack = (np.angle(np.exp(1j * (a - 2.4))) > 0) & (np.angle(np.exp(1j * (a - 2.75))) < 0)
    hub = smoothstep(0.05, 0.04, r)
    alpha = np.clip((core + rims) * (~crack) + hub, 0, 1)
    return gray(np.ones_like(r), alpha)


@texture("hourglass_mote", 256, fallback="Sparkle", usage="Hourglass icon with falling sand; time motes, slow/haste marks.")
def hourglass_mote(size):
    _, _, x, y = grid(size)
    frame_bars = smoothstep(0.02, -0.02, np.maximum(np.abs(x) - 0.55, np.abs(np.abs(y) - 0.82) - 0.06))
    width = 0.08 + 0.38 * np.clip(np.abs(y) / 0.76, 0, 1) ** 1.3
    glass = smoothstep(0.02, -0.02, np.abs(x) - width) * (np.abs(y) < 0.78)
    sand_top = glass * (y > 0.12) * (y < 0.5)
    sand_bottom = glass * (y < -0.4)
    stream = smoothstep(0.02, 0, np.abs(x) - 0.02) * (y < 0.12) * (y > -0.4)
    lum = np.where(sand_top + sand_bottom + stream > 0, 1.0, 0.45)
    return gray(lum, np.clip(frame_bars + glass + stream, 0, 1))


@texture("time_ripple", 1024, layout="Grid4x4", fallback="Sparkle",
         usage="Looping 16-frame ticking ring: notched dial ring rotates in steps with trailing afterimages; time auras.")
def time_ripple(size):
    def frame(t, i, count, s):
        _, _, x, y = grid(s)
        r, a = polar(x, y)
        acc = np.zeros_like(r)
        for k, lag in enumerate((0.0, 0.04, 0.08)):
            step = np.floor((t - lag) * 12) / 12  # steps like a second hand
            ang = a - step * TAU
            notch = (np.abs(((ang / TAU) * 24) % 1 - 0.5) < 0.12)
            ring = smoothstep(0.03, 0.0, np.abs(r - 0.7)) * (1 - 0.35 * k)
            ticks = notch * (r > 0.74) * (r < 0.86) * (1 - 0.35 * k)
            acc = np.maximum(acc, np.maximum(ring, ticks))
        hand = smoothstep(0.02, 0.0, np.abs(np.angle(np.exp(1j * (a - t * TAU)))) * r) * (r < 0.62)
        alpha = np.clip(acc + hand, 0, 1)
        return bleed(gray(np.clip(0.7 + hand * 0.3, 0, 1), alpha))

    return atlas(frames_of(frame, 16, size // 4), 4)


@texture("sand_trail", (512, 128), fallback="Smoke", tiles=True,
         usage="U-tiling stream of drifting sand grains thinning at the edges; time trails, decay.")
def sand_trail(size):
    u, v = strip(*size)
    y = v * 2 - 1
    n = Noise(951, (16, 4, 1))
    grains = smoothstep(0.3, 0.1, worley(u * 48, v * 12, 48, 952))
    density = smoothstep(0.9, 0.0, np.abs(y) + (n.fbm(u * 16, v * 4, 0, 3) - 0.5) * 0.6)
    alpha = np.clip(grains * density * 1.2 + density * 0.15, 0, 1)
    return gray(np.clip(0.55 + grains * 0.4, 0, 1), alpha)


@texture("gear_mote", 256, fallback="Sparkle", usage="Spoked cog wheel; time/clockwork motes and mechanical accents.")
def gear_mote(size):
    _, _, x, y = grid(size)
    r, a = polar(x, y)
    teeth = (np.cos(a * 10) > 0.2) * (r < 0.92)
    body = smoothstep(0.76, 0.74, r) + teeth * (r > 0.7)
    hole = smoothstep(0.2, 0.18, r)
    spokes = np.zeros_like(r)
    for k in range(5):
        spokes = np.maximum(spokes, smoothstep(0.06, 0.04, np.abs(np.angle(np.exp(1j * (a - k / 5 * TAU)))) * r))
    window = (r > 0.25) & (r < 0.58) & (spokes < 0.5)
    alpha = np.clip(body, 0, 1) * (1 - hole) * (~window)
    lum = np.where(r > 0.6, 0.85, 0.6)
    return gray(lum, alpha.astype(float))


# ============================================================================ cel style
# Art direction: cel-shaded dark fantasy. Every texture is post-processed into a hard silhouette,
# flat tone bands and a near-black ink outline (see vfxlib.cel_frame). VFX_STYLE=soft skips it.
# Per-texture overrides; None = leave soft.
LINE_ART = dict(inner_ink=False, alpha_cut=0.22, outline_px=1.5)
CEL = {
    "heat_haze": None,
    "glow_soft": dict(bands=(0.6, 0.85), alpha_cut=0.12, inner_ink=False),
    "smoke_billow": dict(levels=(0.18, 0.34, 0.55), bands=(0.38, 0.6), alpha_cut=0.22),
    "dust_burst": dict(levels=(0.2, 0.36, 0.55), alpha_cut=0.25),
    "frost_mist": dict(levels=(0.45, 0.72, 1.0), alpha_cut=0.28),
    "frost_crack": LINE_ART,
    "scorch_lichtenberg": dict(LINE_ART, levels=(0.12, 0.6, 1.0), bands=(0.3, 0.6)),
    "caustics": LINE_ART,
    "rune_circle": dict(LINE_ART, alpha_cut=0.3),
    "bolt_strip": dict(inner_ink=False, alpha_cut=0.25, bands=(0.6, 0.85)),
    "arc_flicker": dict(inner_ink=False, alpha_cut=0.25, bands=(0.6, 0.85)),
    "spark_burst": dict(inner_ink=False, alpha_cut=0.25, bands=(0.6, 0.85)),
    "beam_energy": dict(inner_ink=False, alpha_cut=0.25),
    "ember_streak": dict(inner_ink=False, alpha_cut=0.25, outline_px=1.5),
    "ice_glint": dict(inner_ink=False, alpha_cut=0.3, outline_px=1.5),
    "droplet": dict(inner_ink=False, outline_px=1.5),
    "ripple_ring": dict(inner_ink=False, alpha_cut=0.25),
    "shockwave_ring": dict(inner_ink=False, alpha_cut=0.3),
    "rock_burst": dict(bands=(0.4, 0.75), levels=(0.25, 0.62, 0.95)),
    "earth_fissure": dict(LINE_ART, levels=(0.1, 0.3, 0.6), bands=(0.2, 0.4)),
    "dust_plume": dict(levels=(0.3, 0.5, 0.72), alpha_cut=0.22),
    "rubble_trail": dict(levels=(0.22, 0.4, 0.7), alpha_cut=0.3),
    "wind_swirl": dict(inner_ink=False, alpha_cut=0.3),
    "gust_strokes": dict(inner_ink=False, alpha_cut=0.3, outline_px=1.5),
    "toxic_pool": dict(levels=(0.28, 0.5, 0.85), bands=(0.45, 0.65)),
    "toxic_bubble": dict(inner_ink=False, alpha_cut=0.3),
    "arcane_glyphs": dict(inner_ink=False, alpha_cut=0.3, outline_px=2),
    "arcane_orb": dict(inner_ink=False, alpha_cut=0.3),
    "arcane_burst": dict(inner_ink=False, alpha_cut=0.3),
    "glyph_chain": dict(inner_ink=False, alpha_cut=0.3, outline_px=1.5),
    "hex_seal": LINE_ART,
    "kinetic_burst": dict(inner_ink=False, alpha_cut=0.3),
    "ward_hex": dict(LINE_ART, alpha_cut=0.3),
    "impact_frame": dict(inner_ink=False, outline_px=4),
    "soul_wisp": dict(inner_ink=False, levels=(0.05, 0.6, 1.0), bands=(0.2, 0.75)),
    "ghost_trail": dict(inner_ink=False, alpha_cut=0.3),
    "soul_burst": dict(levels=(0.1, 0.55, 0.9), bands=(0.3, 0.7)),
    "skull_mote": dict(inner_ink=False, levels=(0.05, 0.68, 0.95), bands=(0.3, 0.8), outline_px=3),
    "soul_sigil": LINE_ART,
    "rift_tear": dict(inner_ink=False, levels=(0.03, 0.5, 1.0), bands=(0.2, 0.8)),
    "void_orb": dict(inner_ink=False, levels=(0.0, 0.6, 1.0), bands=(0.2, 0.8)),
    "warp_implode": dict(inner_ink=False, alpha_cut=0.3),
    "star_mote": dict(inner_ink=False, outline_px=1.5),
    "shard_trail": dict(inner_ink=False, levels=(0.15, 0.5, 1.0), bands=(0.3, 0.7), outline_px=1.5),
    "portal_rings": dict(LINE_ART, levels=(0.02, 0.5, 1.0), bands=(0.2, 0.7)),
    "clock_dial": LINE_ART,
    "hourglass_mote": dict(inner_ink=False, levels=(0.45, 0.7, 1.0), bands=(0.5, 0.8), outline_px=2.5),
    "time_ripple": dict(inner_ink=False, alpha_cut=0.3),
    "sand_trail": dict(inner_ink=False, alpha_cut=0.3, outline_px=1.2),
    "gear_mote": dict(inner_ink=False, levels=(0.4, 0.6, 0.85), bands=(0.5, 0.7), outline_px=2.5),
}


# ============================================================================ main
def main(out):
    os.makedirs(out, exist_ok=True)
    meta_path = os.path.join(out, "textures.json")
    # Partial runs (VFX_ONLY) update their entries and keep the rest.
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta = {k: v for k, v in meta.items() if k in TEXTURES}
    only = set(os.environ.get("VFX_ONLY", "").split(",")) - {""}
    for name, spec in TEXTURES.items():
        if only and name not in only:
            continue
        img = spec["fn"](spec["size"])
        style = CEL.get(name, {})
        if os.environ.get("VFX_STYLE") != "soft" and style is not None:
            img = cel_image(img.astype(np.float32), spec["layout"], spec["tiles"], **style)
        path = os.path.join(out, name + ".png")
        write_png(path, img.astype(np.float32))
        h, w = img.shape[:2]
        meta[name] = dict(file=name + ".png", width=w, height=h, layout=spec["layout"],
                          fallback=spec["fallback"], usage=spec["usage"], tiles=spec["tiles"])
        print(f"[vfx] texture {name} {w}x{h} {spec['layout'] or ''}", flush=True)
    with open(os.path.join(out, "textures.json"), "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    root = args[0] if args else os.getcwd()
    main(os.path.join(root, "assets", "vfx", "textures"))
