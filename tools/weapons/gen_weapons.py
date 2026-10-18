"""Generate Enfleshed's melee weapon meshes in headless Blender and export FBX.

  blender -b --factory-startup --python tools/weapons/gen_weapons.py -- <repo root> [--only Sword,Spear]

Units are studs (1 Blender unit = 1 stud; import with the stud scale or let the
Studio rig script resize). Every object's origin is the weapon's grip point (where
the right hand closes), blade/head along +Z in Blender, which exports as +Y. Each
weapon exports as one FBX holding a few objects split by material (Blade, Fittings,
Grip, ...) so Studio can give each MeshPart its own Roblox material.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = Path(argv[0]) if argv else Path(__file__).resolve().parents[2]
ONLY = None
if "--only" in argv:
    ONLY = set(argv[argv.index("--only") + 1].split(","))
OUT = ROOT / "assets" / "weapons"
OUT.mkdir(parents=True, exist_ok=True)

COLORS = {  # Preview only; Studio sets the real material and colour per part.
    "Blade": (0.42, 0.43, 0.45, 1),
    "Fittings": (0.16, 0.15, 0.14, 1),
    "Grip": (0.13, 0.09, 0.07, 1),
    "Wood": (0.22, 0.15, 0.09, 1),
    "Thorn": (0.30, 0.24, 0.17, 1),
}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = COLORS.get(name, (0.5, 0.5, 0.5, 1))
    return mat


def new_object(name, bm, mat_name):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.append(material(mat_name))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def ring_loft(bm, rings, cap_start=True, cap_end=True):
    """Bridge a list of vertex rings (lists of Vector, same count) into a closed solid.
    A ring of length 1 is a point (tip)."""
    vrings = [[bm.verts.new(p) for p in ring] for ring in rings]
    for a, b in zip(vrings, vrings[1:]):
        if len(a) == 1 or len(b) == 1:
            point, ring = (a[0], b) if len(a) == 1 else (b[0], a)
            n = len(ring)
            for i in range(n):
                face = (ring[i], ring[(i + 1) % n], point)
                bm.faces.new(face if len(a) != 1 else face[::-1])
            continue
        n = len(a)
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if cap_start and len(vrings[0]) > 2:
        bm.faces.new(list(reversed(vrings[0])))
    if cap_end and len(vrings[-1]) > 2:
        bm.faces.new(vrings[-1])
    return bm


def diamond(z, width, thick, x=0.0, y=0.0):
    """Blade cross-section: edge, ridge, edge, ridge (lenticular, 4 verts)."""
    return [Vector((x + width / 2, y, z)), Vector((x, y + thick / 2, z)),
            Vector((x - width / 2, y, z)), Vector((x, y - thick / 2, z))]


def hexa(z, width, thick, flat=0.6, x=0.0, y=0.0):
    """Hexagonal blade section with a flat across the middle (reads heavier)."""
    w, t, f = width / 2, thick / 2, width / 2 * flat
    return [Vector((x + w, y, z)), Vector((x + f, y + t, z)), Vector((x - f, y + t, z)),
            Vector((x - w, y, z)), Vector((x - f, y - t, z)), Vector((x + f, y - t, z))]


def circle(z, r, n=8, x=0.0, y=0.0, sx=1.0, sy=1.0, rot=0.0):
    return [Vector((x + math.cos(rot + i * 2 * math.pi / n) * r * sx,
                    y + math.sin(rot + i * 2 * math.pi / n) * r * sy, z)) for i in range(n)]


def box(bm, size, center, chamfer=0.0):
    sx, sy, sz = (s / 2 for s in size)
    cx, cy, cz = center
    if chamfer <= 0:
        rings = [[Vector((cx + x, cy + y, cz + z)) for x, y in ((sx, sy), (-sx, sy), (-sx, -sy), (sx, -sy))]
                 for z in (-sz, sz)]
        return ring_loft(bm, rings)
    c = chamfer

    def octo(z):
        # Rectangle with its vertical edges chamfered (8-sided section).
        pts = ((sx, sy - c), (sx - c, sy), (-sx + c, sy), (-sx, sy - c),
               (-sx, -sy + c), (-sx + c, -sy), (sx - c, -sy), (sx, -sy + c))
        return [Vector((cx + px, cy + py, cz + z)) for px, py in pts]
    return ring_loft(bm, [octo(-sz), octo(sz)])


def grip_wrap(bm, z0, z1, r, bands, n=8, swell=1.08):
    """Wrapped grip: an octagonal cylinder with raised bands of leather/cord."""
    rings = []
    steps = bands * 2
    for i in range(steps + 1):
        t = i / steps
        z = z0 + (z1 - z0) * t
        mid = 1 + (swell - 1) * math.sin(math.pi * t)
        rr = r * mid * (1.07 if i % 2 else 1.0)
        rings.append(circle(z, rr, n, rot=math.pi / n))
    return ring_loft(bm, rings)


# ---------------------------------------------------------------- weapons

def sword():
    """Guard-Issue Arming Sword: plain, worn issue steel. ~3.45 studs."""
    blade = bmesh.new()
    base, length, tip = 0.42, 2.30, 0.36
    rings = [diamond(base, 0.20, 0.07)]
    for i, t in enumerate((0.0, 0.25, 0.55, 0.85, 1.0)):
        rings.append(hexa(base + 0.08 + t * length, 0.27 - 0.06 * t, 0.06 - 0.012 * t, flat=0.45))
    rings.append([Vector((0, 0, base + 0.08 + length + tip))])
    ring_loft(blade, rings)
    new_object("Blade", blade, "Blade")

    fit = bmesh.new()
    box(fit, (0.95, 0.17, 0.11), (0, 0, 0.355), chamfer=0.035)           # cross guard
    box(fit, (0.22, 0.12, 0.08), (0, 0, 0.44), chamfer=0.02)              # langet block
    ring_loft(fit, [circle(-0.31, 0.09), circle(-0.33, 0.13), circle(-0.40, 0.14),
                    circle(-0.45, 0.10), circle(-0.47, 0.05)])            # pommel
    new_object("Fittings", fit, "Fittings")

    grip = bmesh.new()
    grip_wrap(grip, -0.31, 0.30, 0.075, bands=6)
    new_object("Grip", grip, "Grip")


def greatsword():
    """Breacher's Greatsword: broad two-hander, heavy flat, long grip. ~5.2 studs.
    Origin = lead (right) hand just under the guard; the off hand sits lower."""
    blade = bmesh.new()
    base, length, tip = 0.52, 3.05, 0.42
    rings = [hexa(base, 0.30, 0.12, flat=0.5)]
    rings.append(hexa(base + 0.22, 0.30, 0.11, flat=0.5))                 # ricasso
    rings.append(hexa(base + 0.26, 0.42, 0.10, flat=0.55))                # shoulders flare
    for t in (0.15, 0.5, 0.85, 1.0):
        rings.append(hexa(base + 0.26 + t * length, 0.42 - 0.07 * t, 0.10 - 0.02 * t, flat=0.55))
    rings.append([Vector((0, 0, base + 0.26 + length + tip))])
    ring_loft(blade, rings)
    new_object("Blade", blade, "Blade")

    fit = bmesh.new()
    # Wide flat guard with down-turned ends.
    guard = [Vector((x, 0, z)) for x, z in ((-0.75, 0.30), (-0.62, 0.40), (0.62, 0.40), (0.75, 0.30),
                                            (0.70, 0.46), (0.0, 0.50), (-0.70, 0.46))]
    ring_loft(fit, [[p + Vector((0, -0.11, 0)) for p in guard], [p + Vector((0, 0.11, 0)) for p in guard]])
    for side in (-1, 1):                                                  # parrying lugs on the ricasso
        box(fit, (0.12, 0.13, 0.08), (side * 0.2, 0, 0.74), chamfer=0.02)
    ring_loft(fit, [circle(-0.92, 0.10), circle(-0.95, 0.17), circle(-1.06, 0.18),
                    circle(-1.12, 0.12), circle(-1.15, 0.05)])           # pommel
    new_object("Fittings", fit, "Fittings")

    grip = bmesh.new()
    grip_wrap(grip, -0.92, 0.41, 0.085, bands=11, swell=1.05)
    new_object("Grip", grip, "Grip")


def dagger():
    """Thorn Knife: a shed spine of the Thorn Thicket root, whittled to an edge and
    lashed to a short grip. Organic, curved, no metal. ~1.7 studs."""
    thorn = bmesh.new()
    rings = []
    steps = 7
    base, length = 0.30, 1.15
    for i in range(steps + 1):
        t = i / steps
        z = base + t * length
        curve = 0.16 * t * t                     # spine bends toward the edge side
        w = 0.20 * (1 - t) ** 0.8 + 0.02
        th = 0.10 * (1 - t) ** 0.7 + 0.015
        # Twist each section slightly so the faceting reads as grown, not milled.
        sec = diamond(z, w, th, x=-curve)
        rot = Matrix.Rotation(0.12 * math.sin(t * 5), 4, 'Z')
        sec = [rot @ (p - Vector((-curve, 0, z))) + Vector((-curve, 0, z)) for p in sec]
        rings.append(sec)
    rings.append([Vector((-0.2, 0, base + length + 0.12))])
    ring_loft(thorn, rings)
    # Root-knot collar where the spine was broken from the root.
    ring_loft(thorn, [circle(0.22, 0.08, 7), circle(0.26, 0.13, 7, rot=0.4), circle(0.32, 0.11, 7, rot=0.9),
                      circle(0.36, 0.06, 7, rot=1.3)])
    new_object("Thorn", thorn, "Thorn")

    grip = bmesh.new()
    grip_wrap(grip, -0.27, 0.23, 0.07, bands=5, n=7, swell=1.12)
    ring_loft(grip, [circle(-0.27, 0.07, 7), circle(-0.31, 0.10, 7, rot=0.5), circle(-0.36, 0.06, 7, rot=1.0),
                     [Vector((0.0, 0.0, -0.39))]])                         # knotted butt
    new_object("Grip", grip, "Grip")


def spear():
    """Pike of the Line: long ash shaft, iron socket and leaf head, butt spike.
    Origin = lead (right) hand about a third up the shaft. ~7 studs."""
    shaft = bmesh.new()
    rings = [circle(z, r, 8) for z, r in ((-2.25, 0.07), (-1.0, 0.075), (1.5, 0.072), (3.55, 0.065))]
    ring_loft(shaft, rings)
    new_object("Wood", shaft, "Wood")

    fit = bmesh.new()
    ring_loft(fit, [circle(3.45, 0.085), circle(3.55, 0.09), circle(3.95, 0.07), circle(4.02, 0.055)])  # socket
    for z in (3.62, 3.86):                                                  # socket rings
        ring_loft(fit, [circle(z - 0.025, 0.098), circle(z + 0.025, 0.098)])
    ring_loft(fit, [circle(-2.20, 0.08), circle(-2.35, 0.08), circle(-2.50, 0.04),
                    [Vector((0, 0, -2.62))]])                               # butt spike
    new_object("Fittings", fit, "Fittings")

    head = bmesh.new()
    rings = [diamond(4.0, 0.08, 0.07)]
    for z, w, th in ((4.12, 0.22, 0.07), (4.35, 0.30, 0.065), (4.65, 0.24, 0.055), (4.88, 0.12, 0.04)):
        rings.append(diamond(z, w, th))
    rings.append([Vector((0, 0, 5.05))])
    ring_loft(head, rings)
    new_object("Blade", head, "Blade")

    grip = bmesh.new()                                                      # leather grip wrap at the hands
    grip_wrap(grip, -0.35, 0.35, 0.078, bands=6, swell=1.0)
    new_object("Grip", grip, "Grip")


WEAPONS = {"Sword": sword, "Greatsword": greatsword, "Dagger": dagger, "Spear": spear}


def preview(name):
    """Workbench render of the weapon lying flat, for checking the silhouette."""
    scene = bpy.context.scene
    objs = [o for o in scene.objects if o.type == 'MESH']
    lo = Vector((min(min((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in objs),) * 3)
    hi_z = max(max((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in objs)
    lo_z = lo.z
    mid = (hi_z + lo_z) / 2
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = (hi_z - lo_z) * 1.15
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    # Look at the blade flat (from -Y), slightly rotated for some depth.
    cam.location = Vector((1.2, -10, mid + 0.6))
    direction = Vector((0, 0, mid)) - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Z').to_euler()
    scene.camera = cam
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 420
    scene.render.resolution_y = 1400
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("World")
    scene.render.filepath = str(OUT / "previews" / f"{name}.png")
    (OUT / "previews").mkdir(exist_ok=True)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def report(name):
    tris = 0
    dims = []
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        dims.append(f"{o.name} {tuple(round(v, 3) for v in o.dimensions)}")
    allz = [(o.matrix_world @ Vector(c)).z for o in bpy.context.scene.objects if o.type == 'MESH' for c in o.bound_box]
    print(f"[weapons] {name}: {tris} tris, z {min(allz):.3f}..{max(allz):.3f}; " + "; ".join(dims))


for name, build in WEAPONS.items():
    if ONLY and name not in ONLY:
        continue
    clear()
    build()
    report(name)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{name}.blend"))
    bpy.ops.export_scene.fbx(
        filepath=str(OUT / f"{name}.fbx"),
        use_selection=False,
        object_types={'MESH'},
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_NONE',
        global_scale=1.0,
        axis_forward='-Z',
        axis_up='Y',
        mesh_smooth_type='FACE',
        add_leaf_bones=False,
        bake_anim=False,
    )
    preview(name)
print("[weapons] done")
