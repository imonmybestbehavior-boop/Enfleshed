"""Procedurally model the Enfleshed spell mesh library in Blender and export Roblox-ready files.

Run:  tools/vfx_pipeline/blender.sh tools/vfx_pipeline/gen_meshes.py
Writes assets/vfx/meshes/<name>.fbx and <name>.glb, assets/vfx/source/vfx_meshes.blend,
assets/vfx/meshes/meshes.json and assets/vfx/previews/meshes_sheet.png.

Coordinates are authored in Roblox space (Y up, travel direction -Z, unit ~ 1 stud) and
converted to Blender's Z-up on creation, so FBX/glTF default axis export lands them back in
Roblox orientation. Every mesh is UV-mapped so TextureID / ForceField patterns can use the
texture library. Triangle counts stay far below Roblox's 20k MeshPart limit.
"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import Noise  # noqa: E402

MESHES = {}
TAU = math.tau


def mesh(name, usage, fallback):
    def wrap(fn):
        MESHES[name] = dict(fn=fn, usage=usage, fallback=fallback)
        return fn

    return wrap


def to_blender(p):
    x, y, z = p
    return (x, -z, y)


# ----------------------------------------------------------------------------- builders
def grid_surface(rows, cols, point, wrap_u=True, cap=None):
    """Parametric surface: point(u, v) with u around (wraps) and v along. Returns verts, faces, uvs."""
    verts, uvs = [], []
    ucount = cols if wrap_u else cols + 1
    for r in range(rows + 1):
        v = r / rows
        for c in range(ucount):
            u = c / cols
            verts.append(point(u, v))
            uvs.append((u, v))
    faces = []
    for r in range(rows):
        for c in range(cols):
            c1 = (c + 1) % ucount if wrap_u else c + 1
            a, b = r * ucount + c, r * ucount + c1
            d, e = (r + 1) * ucount + c, (r + 1) * ucount + c1
            faces.append((a, b, e, d))
    return verts, faces, uvs, ucount


def build_object(name, verts, faces, uvs=None, face_uvs=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bverts = [bm.verts.new(to_blender(v)) for v in verts]
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for fi, f in enumerate(faces):
        try:
            face = bm.faces.new([bverts[i] for i in f])
        except ValueError:
            continue
        face.smooth = smooth
        for k, loop in enumerate(face.loops):
            if face_uvs is not None:
                loop[uv_layer].uv = face_uvs[fi][k]
            elif uvs is not None:
                loop[uv_layer].uv = uvs[f[k]]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def fix_seam_uvs(obj):
    """Wrapped grids share seam verts; give the closing column u = 1 instead of 0."""
    me = obj.data
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        us = [uv[li].uv[0] for li in poly.loop_indices]
        if max(us) - min(us) > 0.5:
            for li in poly.loop_indices:
                if uv[li].uv[0] < 0.5:
                    uv[li].uv[0] += 1.0


# ============================================================================ fire
@mesh("fire_core", "Turbulent lobed energy core; projectile hearts (Neon / ForceField).", "Ball")
def fire_core():
    n = Noise(201, (8, 8, 8))

    def point(u, v):
        th, ph = u * TAU, v * math.pi
        d = np.array([math.sin(ph) * math.cos(th), math.cos(ph), math.sin(ph) * math.sin(th)])
        k = float(n.fbm(np.array(d[0] * 1.6 + 4), np.array(d[1] * 1.6 + 4), d[2] * 1.6 + 4, 3))
        r = 0.78 + (k - 0.5) * 0.9
        return tuple(d * r)

    v, f, uv, _ = grid_surface(24, 32, point)
    o = build_object("fire_core", v, f, uv)
    fix_seam_uvs(o)
    weld(o)
    return o


def weld(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(obj.data)
    bm.free()


def tongue_points(length, base_r, curl, twist, seed, rows=14, cols=8):
    """Tapered, curling flame tongue along +Z (trailing direction) with a ragged cross-section."""
    n = Noise(seed, (8, 8, 1))

    def spine(v):
        return np.array([math.sin(v * math.pi * 0.9) * curl * v, math.sin(v * 2.4 + seed) * curl * 0.4 * v, v * length])

    def point(u, v):
        th = u * TAU + twist * v
        rag = 0.75 + 0.5 * float(n(np.array(u * 8), np.array(v * 4)))
        r = base_r * (1 - v) ** 0.8 * (0.55 + 0.45 * math.sin(min(1, v * 3.5) * math.pi / 2)) * rag
        # Blade-like cross-section: flattened so tongues read as sheets of flame.
        c = np.array([math.cos(th) * r, math.sin(th) * r * 0.45, 0])
        return tuple(spine(v) + c)

    return grid_surface(rows, cols, point)


@mesh("flame_tongue", "Single curling blade of flame trailing along +Z; layered around cores.", "Wedge")
def flame_tongue():
    v, f, uv, _ = tongue_points(2.0, 0.42, 0.45, 2.2, 211)
    o = build_object("flame_tongue", v, f, uv)
    fix_seam_uvs(o)
    return o


@mesh("flame_shell", "Cluster of 7 swept flame tongues around a hollow core; projectile outer shell.", "Ball")
def flame_shell():
    verts, faces, uvs = [], [], []
    rng = np.random.default_rng(221)
    for k in range(7):
        length = rng.uniform(1.3, 2.3)
        v, f, uv, _ = tongue_points(length, rng.uniform(0.28, 0.42), rng.uniform(0.2, 0.6), rng.uniform(1, 3), 230 + k, 10, 6)
        ang = k / 7 * TAU + rng.uniform(-0.3, 0.3)
        tilt = rng.uniform(0.35, 0.75)
        # Rotate the tongue's +Z spine outward/backward around the travel axis.
        ca, sa, ct, st = math.cos(ang), math.sin(ang), math.cos(tilt), math.sin(tilt)
        base = len(verts)
        for (x, y, z) in v:
            # tilt about X, then spin about Z, offset to the core surface.
            y2, z2 = y * ct - z * st, y * st + z * ct
            x3, y3 = x * ca - y2 * sa, x * sa + y2 * ca
            verts.append((x3 + ca * 0.0 - sa * 0.0, y3, z2 - 0.35))
        faces += [tuple(i + base for i in face) for face in f]
        uvs += uv
    o = build_object("flame_shell", verts, faces, uvs)
    fix_seam_uvs(o)
    return o


@mesh("comet_spike", "Projectile silhouette: blunt head, finned body tapering to a long tail (+Z).", "Ball")
def comet_spike():
    def point(u, v):
        th = u * TAU
        z = -0.6 + v * 3.0
        head = math.sqrt(max(0.0, 1 - ((v - 0.12) / 0.12) ** 2)) if v < 0.12 else 1.0
        body = 0.55 * head * (1 - max(0.0, v - 0.12) / 0.88) ** 1.4
        fins = 1 + 0.35 * max(0.0, math.cos(th * 3)) ** 6 * min(1.0, v * 4)
        return (math.cos(th) * body * fins, math.sin(th) * body * fins, z)

    v, f, uv, _ = grid_surface(20, 24, point)
    o = build_object("comet_spike", v, f, uv)
    fix_seam_uvs(o)
    weld(o)
    return o


# ============================================================================ rings / waves
@mesh("shockwave_ring", "Flat ragged band ring (XZ plane, radius 1); expanding impact fronts.", "Cylinder")
def shockwave_ring():
    n = Noise(241, (16, 1, 1))

    def point(u, v):
        th = u * TAU
        rag = float(n(np.array(u * 16), np.array(0.5)))
        r = 0.82 + v * 0.18
        y = (v * (1 - v)) * 0.28 + (rag - 0.5) * 0.08 * v
        return (math.cos(th) * r, y, math.sin(th) * r)

    v, f, uv, _ = grid_surface(4, 64, point)
    o = build_object("shockwave_ring", v, f, uv)
    fix_seam_uvs(o)
    return o


@mesh("shockwave_dome", "Open hemispherical shell with a torn rim; volumetric blast front.", "Ball")
def shockwave_dome():
    n = Noise(251, (16, 4, 1))

    def point(u, v):
        th = u * TAU
        rag = float(n(np.array(u * 16), np.array(v * 4)))
        ph = v * (math.pi / 2) * (0.92 + 0.12 * rag * v)
        return (math.cos(th) * math.sin(ph), math.cos(ph) * 0.8, math.sin(th) * math.sin(ph))

    v, f, uv, _ = grid_surface(10, 40, point)
    o = build_object("shockwave_dome", v, f, uv)
    fix_seam_uvs(o)
    weld(o)
    return o


@mesh("sigil_ring", "Industrial casting sigil: geared outer ring + segmented inner band, flat on XZ.", "Cylinder")
def sigil_ring():
    verts, faces = [], []
    face_uvs = []

    def quad_ring(r0, r1, a0, a1, y0=0.0, y1=0.04, seg=2):
        base = len(verts)
        pts = []
        for s in range(seg + 1):
            a = a0 + (a1 - a0) * s / seg
            for r in (r0, r1):
                for y in (y0, y1):
                    pts.append((math.cos(a) * r, y, math.sin(a) * r))
        verts.extend(pts)
        for s in range(seg):
            i = base + s * 4
            j = i + 4
            # top, bottom, inner, outer
            for quad in ((i + 1, i + 3, j + 3, j + 1), (i, j, j + 2, i + 2), (i, i + 1, j + 1, j), (i + 2, j + 2, j + 3, i + 3)):
                faces.append(quad)
                face_uvs.append([((verts[q][0] + 1) / 2, (verts[q][2] + 1) / 2) for q in quad])
        # end caps
        for cap in ((base, base + 2, base + 3, base + 1), (base + seg * 4, base + seg * 4 + 1, base + seg * 4 + 3, base + seg * 4 + 2)):
            faces.append(cap)
            face_uvs.append([((verts[q][0] + 1) / 2, (verts[q][2] + 1) / 2) for q in cap])

    quad_ring(0.9, 0.97, 0, TAU, seg=96)
    teeth = 36
    for k in range(teeth):
        a = k / teeth * TAU
        quad_ring(0.97, 1.03, a, a + TAU / teeth * 0.45, seg=1)
    segs = 9
    for k in range(segs):
        a = k / segs * TAU
        quad_ring(0.62, 0.78, a + 0.05, a + TAU / segs - 0.05, y0=0.0, y1=0.03, seg=6)
    quad_ring(0.45, 0.48, 0, TAU, seg=64, y1=0.02)
    return build_object("sigil_ring", verts, faces, face_uvs=face_uvs, smooth=False)


@mesh("energy_ribbon", "Twisting helical ribbon strip along +Z (length 4); beams, orbit trails, auras.", "Block")
def energy_ribbon():
    def point(u, v):
        # u across the strip (no wrap), v along.
        a = v * TAU * 1.5
        center = np.array([math.cos(a) * 0.5, math.sin(a) * 0.5, v * 4])
        width = 0.18 * math.sin(math.pi * v) ** 0.5
        normal = np.array([math.cos(a + 0.6), math.sin(a + 0.6), 0])
        return tuple(center + normal * (u - 0.5) * 2 * width)

    v, f, uv, _ = grid_surface(64, 1, point, wrap_u=False)
    return build_object("energy_ribbon", v, f, uv)


# ============================================================================ debris & body
def rock(seed, elong=(1, 1, 1)):
    rng = np.random.default_rng(seed)
    pts = rng.normal(size=(18, 3))
    pts /= np.linalg.norm(pts, axis=1, keepdims=True)
    pts *= rng.uniform(0.7, 1.0, (18, 1)) * np.array(elong)
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(to_blender(p))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    # Planar facets: flat shading, fractured look.
    for f in bm.faces:
        f.smooth = False
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x + 1) / 2, (co.z + 1) / 2)
    return bm


@mesh("debris_rock", "Fractured faceted rock chunk (3 variants: _a _b _c); impact debris.", "Block")
def debris_rock():
    objs = []
    for suffix, seed, el in (("a", 261, (1, 0.7, 0.9)), ("b", 262, (1.2, 0.5, 0.7)), ("c", 263, (0.8, 0.8, 1.1))):
        me = bpy.data.meshes.new("debris_rock_" + suffix)
        bm = rock(seed, el)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("debris_rock_" + suffix, me)
        bpy.context.scene.collection.objects.link(o)
        objs.append(o)
    return objs


@mesh("pressure_cone", "Body force cone shell opening along -Z (length 1, mouth radius 1) with torn crescent rim.", "Wedge")
def pressure_cone():
    n = Noise(271, (12, 4, 1))

    def point(u, v):
        th = u * TAU
        rag = float(n(np.array(u * 12), np.array(v * 4)))
        # Bell profile: tight throat, flaring compressed lip.
        r = 0.08 + 0.92 * v ** 0.7 * (1 + (rag - 0.5) * 0.25 * v)
        z = -v * (1 + 0.15 * math.cos(th * 2) * v)  # crescent: sides lead, top/bottom lag
        return (math.cos(th) * r, math.sin(th) * r * 0.62, z)

    v, f, uv, _ = grid_surface(10, 40, point)
    o = build_object("pressure_cone", v, f, uv)
    fix_seam_uvs(o)
    return o


@mesh("flesh_shard", "Mutated organic spindle with bulges and a hooked tip; body-magic fragments.", "Wedge")
def flesh_shard():
    n = Noise(281, (8, 8, 1))

    def point(u, v):
        th = u * TAU
        bulge = 1 + 0.35 * float(n(np.array(u * 8), np.array(v * 8)))
        r = 0.32 * math.sin(math.pi * min(1.0, v * 1.05)) ** 0.8 * bulge
        hook = 0.35 * v ** 3
        return (math.cos(th) * r + hook, math.sin(th) * r * 0.8, (v - 0.5) * 2)

    v, f, uv, _ = grid_surface(16, 12, point)
    o = build_object("flesh_shard", v, f, uv)
    fix_seam_uvs(o)
    weld(o)
    return o


@mesh("sinew_tendril", "Curling organic tube that tapers and twists; tethers, body auras, grips.", "Cylinder")
def sinew_tendril():
    n = Noise(291, (8, 8, 1))

    def point(u, v):
        th = u * TAU
        spine = np.array([math.sin(v * 3.2) * 0.6 * v, math.sin(v * 2.1 + 1) * 0.35, v * 3])
        r = 0.16 * (1 - v) ** 0.6 * (1 + 0.25 * float(n(np.array(u * 8 + v * 8), np.array(v * 8))))
        return tuple(spine + np.array([math.cos(th) * r, math.sin(th) * r, 0]))

    v, f, uv, _ = grid_surface(28, 8, point)
    o = build_object("sinew_tendril", v, f, uv)
    fix_seam_uvs(o)
    return o



# ============================================================================ ice (batch 1)
def hex_prism(base, axis, length, radius, tip, sides=6, twist=0.0, jag=None):
    """Faceted crystal: n-gon prism along `axis` with a pyramid tip. Returns verts, faces."""
    axis = np.array(axis, float)
    axis /= np.linalg.norm(axis)
    side = np.cross(axis, [0, 1, 0] if abs(axis[1]) < 0.9 else [1, 0, 0])
    side /= np.linalg.norm(side)
    up = np.cross(axis, side)
    base = np.array(base, float)
    verts, faces = [], []
    rings = [(0.0, radius * 0.85), (length * 0.15, radius), (length, radius * 0.92)]
    for (d, r) in rings:
        for k in range(sides):
            a = k / sides * TAU + twist
            jr = r * (1 + (jag[k] if jag is not None else 0))
            verts.append(tuple(base + axis * d + (side * math.cos(a) + up * math.sin(a)) * jr))
    tip_index = len(verts)
    verts.append(tuple(base + axis * (length + tip)))
    bottom = len(verts)
    verts.append(tuple(base - axis * radius * 0.2))
    for ring in range(len(rings) - 1):
        for k in range(sides):
            a, b = ring * sides + k, ring * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    top = (len(rings) - 1) * sides
    for k in range(sides):
        faces.append((top + k, top + (k + 1) % sides, tip_index))
        faces.append(((k + 1) % sides, k, bottom))
    return verts, faces


def merge_parts(parts):
    verts, faces = [], []
    for v, f in parts:
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in face) for face in f]
    return verts, faces


def planar_uvs(verts, faces):
    return [[((verts[i][0] + 1.5) / 3, (verts[i][1] + 1.5) / 3) for i in face] for face in faces]


@mesh("ice_cluster", "Faceted crystal cluster erupting from a point (Y up); ice fields, constructs, impacts.", "Wedge")
def ice_cluster():
    rng = np.random.default_rng(501)
    parts = []
    for k in range(7):
        tilt = rng.uniform(0.15, 0.75) if k else 0.05
        ang = rng.uniform(0, TAU)
        axis = (math.sin(tilt) * math.cos(ang), math.cos(tilt), math.sin(tilt) * math.sin(ang))
        length = rng.uniform(0.9, 1.6) * (1.25 if k == 0 else 1)
        parts.append(hex_prism((0, 0, 0), axis, length, rng.uniform(0.13, 0.26), rng.uniform(0.25, 0.45),
                               sides=6, twist=rng.uniform(0, 1), jag=rng.uniform(-0.15, 0.15, 6)))
    v, f = merge_parts(parts)
    return build_object("ice_cluster", v, f, face_uvs=planar_uvs(v, f), smooth=False)


@mesh("ice_spike", "Single tall faceted crystal spike along +Y; ice projectiles (rotate), pillars, lances.", "Wedge")
def ice_spike():
    v, f = hex_prism((0, 0, 0), (0, 1, 0), 2.2, 0.28, 0.7, sides=6, jag=np.array([0.1, -0.05, 0.12, -0.1, 0.05, 0.0]))
    return build_object("ice_spike", v, f, face_uvs=planar_uvs(v, f), smooth=False)


@mesh("ice_shard", "Irregular bipyramid ice fragments (variants _a _b); shatter debris.", "Wedge")
def ice_shard():
    objs = []
    for suffix, seed in (("a", 511), ("b", 512)):
        rng = np.random.default_rng(seed)
        sides = 5
        ring = [(math.cos(k / sides * TAU) * rng.uniform(0.18, 0.32), rng.uniform(-0.1, 0.1),
                 math.sin(k / sides * TAU) * rng.uniform(0.18, 0.32)) for k in range(sides)]
        verts = ring + [(rng.uniform(-0.1, 0.1), 1.0, 0), (0, -0.45, rng.uniform(-0.1, 0.1))]
        faces = [(k, (k + 1) % sides, sides) for k in range(sides)] + [((k + 1) % sides, k, sides + 1) for k in range(sides)]
        objs.append(build_object("ice_shard_" + suffix, verts, faces, face_uvs=planar_uvs(verts, faces), smooth=False))
    return objs


# ============================================================================ lightning (batch 1)
@mesh("lightning_fork", "Jagged forked bolt (square-section tubes) from +Y down to -Y, height 4; strikes, chains.", "Block")
def lightning_fork():
    import random
    rnd = random.Random(521)

    def path(a, b, depth=5, rough=0.35):
        pts = [np.array(a, float), np.array(b, float)]
        for _ in range(depth):
            new = [pts[0]]
            for p, q in zip(pts[:-1], pts[1:]):
                d = q - p
                n1 = np.cross(d, [0, 0, 1]); n2 = np.cross(d, n1)
                n1 /= np.linalg.norm(n1) + 1e-9; n2 /= np.linalg.norm(n2) + 1e-9
                mid = (p + q) / 2 + (n1 * rnd.gauss(0, 1) + n2 * rnd.gauss(0, 1)) * np.linalg.norm(d) * rough * 0.5
                new += [mid, q]
            pts = new
        return pts

    def tube(pts, r0, r1):
        verts, faces = [], []
        n = len(pts)
        for i, p in enumerate(pts):
            r = r0 + (r1 - r0) * i / (n - 1)
            for k in range(4):
                a = k / 4 * TAU + math.pi / 4
                verts.append((p[0] + math.cos(a) * r, p[1], p[2] + math.sin(a) * r))
        for i in range(n - 1):
            for k in range(4):
                a, b = i * 4 + k, i * 4 + (k + 1) % 4
                faces.append((a, b, b + 4, a + 4))
        return verts, faces

    main = path((0, 2, 0), (0, -2, 0))
    parts = [tube(main, 0.09, 0.03)]
    for idx in (5, 11, 19, 24):
        p = main[idx]
        tip = p + np.array([rnd.uniform(-1.2, 1.2), -rnd.uniform(0.6, 1.4), rnd.uniform(-1.2, 1.2)])
        parts.append(tube(path(p, tip, 4, 0.4), 0.05, 0.015))
    v, f = merge_parts(parts)
    return build_object("lightning_fork", v, f, face_uvs=planar_uvs(v, f), smooth=False)


# ============================================================================ water (batch 1)
@mesh("water_crown", "Open splash crown: wavy wall with spiky droplet tips, radius 1, height ~1.3; water impacts.", "Cylinder")
def water_crown():
    n = Noise(531, (24, 4, 1))

    def point(u, v):
        th = u * TAU
        spike = max(0.0, math.sin(th * 9)) ** 4 * 0.6
        h = 0.55 + spike + (float(n(np.array(u * 24), np.array(0.5))) - 0.5) * 0.3
        r = 0.7 + 0.3 * v + 0.12 * v * v
        y = v * h
        return (math.cos(th) * r, y, math.sin(th) * r)

    v, f, uv, _ = grid_surface(6, 72, point)
    o = build_object("water_crown", v, f, uv)
    fix_seam_uvs(o)
    return o


@mesh("water_curl", "Curling breaking-wave sheet along X (width 3), crest curling forward (-Z); water waves.", "Wedge")
def water_curl():
    def point(u, v):
        # u across the width (no wrap), v from the trough up and over the lip.
        x = (u - 0.5) * 3
        ang = v * math.pi * 1.25
        r = 0.9 * (1 - 0.35 * v)
        lip = 0.08 * math.sin(u * TAU * 3) * v
        return (x, math.sin(ang) * r + lip, -(1 - math.cos(ang)) * r * 0.9 + 0.3)

    v, f, uv, _ = grid_surface(14, 18, point, wrap_u=False)
    return build_object("water_curl", v, f, uv)



# ============================================================================ earth (batch 2)
def hull_object(name, points):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(to_blender(p))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    for f in bm.faces:
        f.smooth = False
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x + 1) / 2, (co.z + 1) / 2)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


@mesh("earth_spire", "Jagged faceted stone spire erupting along +Y (height ~2.6); earth spikes, pillars, fields.", "Wedge")
def earth_spire():
    rng = np.random.default_rng(701)
    pts = []
    for level, radius in ((0.0, 0.62), (0.45, 0.5), (1.1, 0.36), (1.8, 0.2), (2.35, 0.07)):
        for k in range(6):
            a = k / 6 * TAU + rng.uniform(-0.3, 0.3)
            r = radius * rng.uniform(0.75, 1.15)
            pts.append((math.cos(a) * r + level * 0.08, level + rng.uniform(-0.08, 0.08), math.sin(a) * r))
    pts.append((0.25, 2.6, 0.02))
    return hull_object("earth_spire", pts)


@mesh("earth_boulder", "Chunky faceted boulder (~1.6 studs) with flat fracture planes; thrown rocks, meteors.", "Ball")
def earth_boulder():
    rng = np.random.default_rng(711)
    d = rng.normal(size=(34, 3))
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    d *= rng.uniform(0.72, 0.95, (34, 1)) * np.array([1.0, 0.82, 0.95])
    # Shear off a few planes for fracture faces.
    for axis in (np.array([0.9, 0.3, 0.1]), np.array([-0.3, -0.8, 0.4])):
        axis /= np.linalg.norm(axis)
        dots = d @ axis
        d -= np.outer(np.maximum(dots - 0.62, 0), axis)
    return hull_object("earth_boulder", [tuple(p) for p in d])


@mesh("earth_slab", "Upthrust stone wall slab (W2.4 x H1.8 x D0.6) with broken top edge; earth constructs, walls.", "Block")
def earth_slab():
    rng = np.random.default_rng(721)
    pts = []
    for x in np.linspace(-1.2, 1.2, 7):
        top = 1.5 + rng.uniform(-0.3, 0.35)
        for z in (-0.3, 0.3):
            zz = z * rng.uniform(0.8, 1.1)
            pts += [(x, rng.uniform(-0.05, 0.05), zz), (x + rng.uniform(-0.08, 0.08), top, zz * 0.85)]
    return hull_object("earth_slab", pts)


# ============================================================================ wind (batch 2)
@mesh("wind_funnel", "Open twisting tornado funnel of 3 ribbon bands (height 3, top radius 1.2); cyclones, wind auras.", "Cylinder")
def wind_funnel():
    verts, faces, uvs = [], [], []
    for band in range(3):
        def point(u, v, band=band):
            # u across the ribbon, v up the funnel.
            th = band / 3 * TAU + v * TAU * 1.6 + (u - 0.5) * 0.9
            r = 0.15 + 1.05 * v ** 1.4
            y = v * 3 + (u - 0.5) * 0.25
            return (math.cos(th) * r, y, math.sin(th) * r)
        v, f, uv, _ = grid_surface(40, 2, point, wrap_u=False)
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in face) for face in f]
        uvs += uv
    return build_object("wind_funnel", verts, faces, uvs)


@mesh("wind_crescent", "Thick tapered blade crescent (span 3, flat on XZ, convex toward -Z); wind slashes, gust waves.", "Wedge")
def wind_crescent():
    def point(u, v):
        # u along the arc, v across the blade width (no wrap).
        a = (u - 0.5) * math.pi * 0.95
        width = 0.32 * math.sin(math.pi * u) ** 0.8
        r = 1.5 - (v - 0.5) * width
        return (math.sin(a) * r, (v - 0.5) * 0.06, -math.cos(a) * r + 1.1)

    v, f, uv, _ = grid_surface(3, 32, lambda u, v: point(u, v), wrap_u=False)
    return build_object("wind_crescent", v, f, uv, smooth=False)


# ============================================================================ poison (batch 2)
@mesh("poison_bubbles", "Cluster of 6 low-poly bubbles of varied size (~1.6 across); boiling poison, gas sacs.", "Ball")
def poison_bubbles():
    rng = np.random.default_rng(741)
    parts = []
    for k in range(6):
        c = rng.normal(size=3) * 0.35 * (k > 0)
        rad = rng.uniform(0.25, 0.5) if k else 0.55

        def point(u, v, c=c, rad=rad):
            th, ph = u * TAU, v * math.pi
            return (c[0] + math.sin(ph) * math.cos(th) * rad, c[1] + math.cos(ph) * rad,
                    c[2] + math.sin(ph) * math.sin(th) * rad)

        vv, ff, _, _ = grid_surface(6, 10, point)
        parts.append((vv, ff))
    v, f = merge_parts(parts)
    o = build_object("poison_bubbles", v, f, face_uvs=planar_uvs(v, f), smooth=False)
    weld(o)
    return o


@mesh("poison_thorn", "Curved barbed thorn along +Y (length 2.2) with side barbs; venom spikes, needles.", "Wedge")
def poison_thorn():
    parts = []

    def curved(base, length, radius, bend, sides=5, rows=8):
        verts, faces = [], []
        for i in range(rows + 1):
            t = i / rows
            cx = base[0] + bend * t * t
            cy = base[1] + length * t
            r = radius * (1 - t) ** 1.1 + 0.005
            for k in range(sides):
                a = k / sides * TAU
                verts.append((cx + math.cos(a) * r, cy, base[2] + math.sin(a) * r))
        for i in range(rows):
            for k in range(sides):
                a, b = i * sides + k, i * sides + (k + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        return verts, faces

    parts.append(curved((0, 0, 0), 2.2, 0.2, 0.55))
    for y, side in ((0.6, 1), (1.0, -1), (1.4, 1)):
        bx = 0.55 * (y / 2.2) ** 2
        v, f = curved((bx, y, 0), 0.45, 0.06, 0.3 * side)
        # tilt barb outward by shearing x with height
        v = [(vx + (vy - y) * 0.8 * side, vy, vz) for vx, vy, vz in v]
        parts.append((v, f))
    v, f = merge_parts(parts)
    return build_object("poison_thorn", v, f, face_uvs=planar_uvs(v, f), smooth=False)


# ============================================================================ arcane / force / spirit (batch 3)
@mesh("arcane_prism", "Elongated faceted octahedral crystal (height 2) for floating arcane cores and orbiting shards.", "Wedge")
def arcane_prism():
    pts = [(0, 1.0, 0), (0, -1.0, 0)] + [(math.cos(k / 4 * TAU) * 0.42, 0.12, math.sin(k / 4 * TAU) * 0.42) for k in range(4)]
    return hull_object("arcane_prism", pts)


@mesh("ward_dome", "Faceted geodesic hemisphere (radius 1, open base) for barriers and shields; pair with ward_hex.", "Ball")
def ward_dome():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    o = bpy.context.active_object
    o.name = "ward_dome"
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # Blender Z is Roblox Y: drop everything below the equator to open the base.
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.05], context="VERTS")
    for f in bm.faces:
        f.smooth = False
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = ((loop.vert.co.x + 1) / 2, (loop.vert.co.y + 1) / 2)
    bm.to_mesh(o.data)
    bm.free()
    return o


@mesh("soul_skull", "Low-poly horned skull (height ~1.3) facing -Z with hollow eye sockets; spirit projectiles, curses.", "Ball")
def soul_skull():
    parts = []

    def blob(center, radii, rows=6, cols=10, pinch=None):
        def point(u, v):
            th, ph = u * TAU, v * math.pi
            x = math.sin(ph) * math.cos(th) * radii[0]
            y = math.cos(ph) * radii[1]
            z = math.sin(ph) * math.sin(th) * radii[2]
            return (center[0] + x, center[1] + y, center[2] + z)
        v, f, _, _ = grid_surface(rows, cols, point)
        return v, f

    parts.append(blob((0, 0.25, 0.05), (0.5, 0.48, 0.55)))           # cranium
    parts.append(blob((0, -0.22, -0.12), (0.32, 0.2, 0.32), 4, 8))     # jaw/maxilla
    for side in (-1, 1):
        # Horns: bent tapered cones sweeping back and up.
        verts, faces = [], []
        rows = 6
        for i in range(rows + 1):
            t = i / rows
            cx = side * (0.42 + 0.35 * t)
            cy = 0.45 + 0.55 * t - 0.25 * t * t
            cz = 0.1 + 0.35 * t
            r = 0.13 * (1 - t) + 0.01
            for k in range(5):
                a = k / 5 * TAU
                verts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, cz))
        for i in range(rows):
            for k in range(5):
                a, b = i * 5 + k, i * 5 + (k + 1) % 5
                faces.append((a, b, b + 5, a + 5))
        parts.append((verts, faces))
    v, f = merge_parts(parts)
    o = build_object("soul_skull", v, f, face_uvs=planar_uvs(v, f), smooth=False)
    # Eye sockets: push two vertex groups inward on the face (-Z side).
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for vert in bm.verts:
        rx, ry, rz = vert.co.x, vert.co.z, -vert.co.y  # back to Roblox axes
        for side in (-1, 1):
            d = math.hypot(rx - side * 0.2, ry - 0.2)
            if d < 0.16 and rz < -0.2:
                vert.co.y += (0.16 - d) * 1.6  # Blender +Y is Roblox -Z... move toward the back
    bm.to_mesh(o.data)
    bm.free()
    return o


@mesh("chain_link", "Single chunky chain link (length 1, open centre); binding, control and tether chains.", "Cylinder")
def chain_link():
    def point(u, v):
        th = u * TAU
        # Stadium-shaped centre line, square-ish tube.
        s = v * TAU
        straight = 0.25
        cx = math.cos(s) * 0.28
        cy = math.sin(s) * 0.28 + (straight if math.sin(s) > 0 else -straight)
        nx, ny = math.cos(s), math.sin(s)
        r = 0.09
        return (cx + nx * math.cos(th) * r, cy + ny * math.cos(th) * r, math.sin(th) * r)

    v, f, uv, _ = grid_surface(32, 6, lambda u, v: point(u, v))
    o = build_object("chain_link", v, f, uv, smooth=False)
    fix_seam_uvs(o)
    weld(o)
    return o


# ============================================================================ space / time (batch 4)
@mesh("void_shard", "Long razor obsidian shard (height 2) with a beveled edge; space blades, rift debris.", "Wedge")
def void_shard():
    pts = [(0, 1.0, 0), (0, -1.0, 0), (0.28, -0.1, 0.05), (-0.22, 0.15, 0.04), (0.04, 0.05, 0.12), (0.0, -0.05, -0.1),
           (0.16, 0.45, 0.02), (-0.12, -0.5, 0.0)]
    return hull_object("void_shard", pts)


@mesh("rift_frame", "Jagged torn-reality loop (vertical lens, height 3) open in the middle; portals and rifts.", "Cylinder")
def rift_frame():
    n = Noise(951, (24, 4, 1))

    def point(u, v):
        th = u * TAU
        jag = (float(n(np.array(u * 24), np.array(v * 2))) - 0.5) * 0.25
        rx = 0.6 * abs(math.sin(th)) ** 0.8 + jag * 0.5
        ry = 1.5
        r = 1 + v * 0.18 + jag
        return (math.sin(th) * rx * r, math.cos(th) * ry * (1 + v * 0.06), (v - 0.5) * 0.08)

    v, f, uv, _ = grid_surface(2, 64, point)
    o = build_object("rift_frame", v, f, uv, smooth=False)
    fix_seam_uvs(o)
    return o


@mesh("chrono_gear", "Thick toothed gear (radius 1, flat on XZ) with spokes; time constructs, clockwork auras.", "Cylinder")
def chrono_gear():
    verts, faces, face_uvs = [], [], []
    teeth, segs = 14, 14 * 4
    outline = []
    for i in range(segs):
        a = i / segs * TAU
        tooth = (i % 4) in (1, 2)
        outline.append((math.cos(a) * (1.0 if tooth else 0.86), math.sin(a) * (1.0 if tooth else 0.86)))
    inner = [(math.cos(i / segs * TAU) * 0.68, math.sin(i / segs * TAU) * 0.68) for i in range(segs)]
    for y in (-0.08, 0.08):
        for (ox, oz) in outline:
            verts.append((ox, y, oz))
        for (ix, iz) in inner:
            verts.append((ix, y, iz))
    # top/bottom annulus + outer/inner walls
    for i in range(segs):
        j = (i + 1) % segs
        for layer, flip in ((0, True), (1, False)):
            base = layer * segs * 2
            o0, o1, i0, i1 = base + i, base + j, base + segs + i, base + segs + j
            faces.append((o0, o1, i1, i0) if not flip else (o0, i0, i1, o1))
        faces.append((i, j, segs * 2 + j, segs * 2 + i))
        faces.append((segs + j, segs + i, segs * 3 + i, segs * 3 + j))
    face_uvs = [[((verts[k][0] + 1) / 2, (verts[k][2] + 1) / 2) for k in face] for face in faces]
    parts_v, parts_f = verts, faces
    # Spokes
    for k in range(5):
        a = k / 5 * TAU
        ca, sa = math.cos(a), math.sin(a)
        px, pz = -sa * 0.07, ca * 0.07
        base = len(parts_v)
        quad = [(ca * 0.15 + px, sa * 0.15 + pz), (ca * 0.7 + px, sa * 0.7 + pz),
                (ca * 0.7 - px, sa * 0.7 - pz), (ca * 0.15 - px, sa * 0.15 - pz)]
        for y in (-0.05, 0.05):
            parts_v += [(qx, y, qz) for qx, qz in quad]
        box = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        for b in box:
            parts_f.append(tuple(base + q for q in b))
            face_uvs.append([((parts_v[base + q][0] + 1) / 2, (parts_v[base + q][2] + 1) / 2) for q in b])
    o = build_object("chrono_gear", parts_v, parts_f, face_uvs=face_uvs, smooth=False)
    return o


@mesh("hourglass", "Hourglass (height 2) with pillar frame and pinched glass; time constructs, slow/haste totems.", "Cylinder")
def hourglass():
    parts = []

    def lathe(profile, sides=10):
        verts, faces = [], []
        for y, r in profile:
            for k in range(sides):
                a = k / sides * TAU
                verts.append((math.cos(a) * r, y, math.sin(a) * r))
        for i in range(len(profile) - 1):
            for k in range(sides):
                a, b = i * sides + k, i * sides + (k + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        return verts, faces

    parts.append(lathe([(-0.9, 0.02), (-0.88, 0.42), (-0.5, 0.36), (-0.1, 0.07), (0.0, 0.05), (0.1, 0.07),
                        (0.5, 0.36), (0.88, 0.42), (0.9, 0.02)]))
    for y in (-0.98, 0.9):
        parts.append(lathe([(y, 0.0), (y, 0.58), (y + 0.08, 0.58), (y + 0.08, 0.0)], 12))
    for k in range(3):
        a = k / 3 * TAU
        px, pz = math.cos(a) * 0.5, math.sin(a) * 0.5
        v, f = lathe([(-0.9, 0.05), (0.9, 0.05)], 6)
        parts.append(([(vx + px, vy, vz + pz) for vx, vy, vz in v], f))
    v, f = merge_parts(parts)
    return build_object("hourglass", v, f, face_uvs=planar_uvs(v, f), smooth=False)


# Open sheets/rings get no ink hull (an inflated open shell would draw a solid dark band).
NO_INK = {"shockwave_ring", "shockwave_dome", "sigil_ring", "energy_ribbon", "pressure_cone", "water_crown",
          "water_curl", "flame_shell", "wind_funnel", "wind_crescent", "ward_dome",
          "rift_frame"}


INK_MAX = {"chain_link": 0.02, "hourglass": 0.02, "soul_skull": 0.04, "poison_thorn": 0.01, "lightning_fork": 0.012, "sinew_tendril": 0.02, "flame_tongue": 0.025, "ice_spike": 0.04}


def ink_hull(obj, thickness=0.035):
    """Inverted-hull outline: inflate along normals, flip faces. Rendered black, it draws a cel rim."""
    me = obj.data.copy()
    hull = bpy.data.objects.new(obj.name + "_ink", me)
    bpy.context.scene.collection.objects.link(hull)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    diag = max(obj.dimensions) or 1
    # Cap the rim so thin geometry (bolts, tendrils) is not swallowed by its own outline.
    offset = min(thickness * diag, INK_MAX.get(obj.name, 0.07))
    bm.normal_update()
    for vert in bm.verts:
        vert.co += vert.normal * offset
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    return hull

# ============================================================================ export & preview
def export(obj, out):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    fbx = os.path.join(out, obj.name + ".fbx")
    glb = os.path.join(out, obj.name + ".glb")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, apply_unit_scale=True, bake_space_transform=True,
                             object_types={"MESH"}, mesh_smooth_type="FACE", add_leaf_bones=False)
    bpy.ops.export_scene.gltf(filepath=glb, use_selection=True, export_format="GLB", export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    dims = [round(d, 3) for d in obj.dimensions]
    return dict(fbx=os.path.basename(fbx), glb=os.path.basename(glb), triangles=tris,
                size=[dims[0], dims[2], dims[1]])  # Roblox X, Y, Z


def preview(objs, path, hulls=None):
    """Cel preview: flat toon-coloured meshes (Workbench FLAT) with their black ink hulls."""
    hulls = hulls or {}
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_backface_culling = True
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.05, 0.045, 0.055)
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    world = bpy.data.worlds.new("w") if not scene.world else scene.world
    scene.world = world
    world.color = (0.05, 0.045, 0.055)
    cols = 7
    rows = (len(objs) + cols - 1) // cols
    for i, o in enumerate(objs):
        r, c = divmod(i, cols)
        span = max(o.dimensions) or 1
        o.scale = (2.0 / span,) * 3
        o.location = (c * 3.0 - (cols - 1) * 1.5, 0, (rows - 1) * 1.45 - r * 2.9)
        o.rotation_euler = (0.45, 0.0, 0.6)
        # Two-tone toon: lit colour on the mesh, near-black ink on its hull.
        o.color = (0.95, 0.62, 0.32, 1)
        hull = hulls.get(o.name)
        if hull:
            hull.scale, hull.location, hull.rotation_euler = o.scale, o.location, o.rotation_euler
            hull.color = (0.02, 0.015, 0.02, 1)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(cols * 3.0, rows * 2.9 * 1.6) + 0.5
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -20, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main(root):
    out = os.path.join(root, "assets", "vfx", "meshes")
    src = os.path.join(root, "assets", "vfx", "source")
    prev = os.path.join(root, "assets", "vfx", "previews")
    for d in (out, src, prev):
        os.makedirs(d, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    meta, all_objs, hulls = {}, [], {}
    for name, spec in MESHES.items():
        result = spec["fn"]()
        objs = result if isinstance(result, list) else [result]
        for o in objs:
            info = export(o, out)
            info.update(usage=spec["usage"], fallback=spec["fallback"])
            meta[o.name] = info
            all_objs.append(o)
            print(f"[vfx] mesh {o.name} tris={info['triangles']}", flush=True)
            if name not in NO_INK and o.name not in NO_INK:
                hull = ink_hull(o)
                hinfo = export(hull, out)
                hinfo.update(usage="Inverted-hull ink outline for " + o.name + " (render black, same CFrame/size x1.0).",
                             fallback=spec["fallback"], ink_for=o.name)
                meta[hull.name] = hinfo
                hulls[o.name] = hull
    with open(os.path.join(out, "meshes.json"), "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src, "vfx_meshes.blend"))
    preview(all_objs, os.path.join(prev, "meshes_sheet.png"), hulls)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0] if args else os.getcwd())
