"""Blender lookdev stills of the Fireball and Body Burst compositions built from the generated assets.

Run:  tools/vfx_pipeline/blender.sh tools/vfx_pipeline/lookdev.py
Writes assets/vfx/previews/lookdev_fireball.png and lookdev_body_burst.png.

These are asset/composition previews rendered in Blender (Cycles), approximating Roblox additive
particles with emissive alpha cards. They are NOT captures of the Roblox renderer.
"""
import math
import os
import sys

import bpy

ROOT = None


def tex(name):
    return os.path.join(ROOT, "assets", "vfx", "textures", name + ".png")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.010, 0.013, 1)
    scene.world = world
    return scene


def import_mesh(name):
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "vfx", "meshes", name + ".glb"))
    obj = bpy.context.selected_objects[0]
    obj.rotation_mode = "XYZ"  # glTF import uses quaternions; stage with Euler angles
    return obj


def emissive(name, color, strength, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (*color, 1)
    em.inputs[1].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = alpha
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m


def solid(name, color, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def card_material(name, texture, color, strength, grid=1, frame=0, additive=True, opacity=1.0):
    """Alpha card: texture luminance x color, alpha from texture; optional flipbook frame."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    r, c = divmod(frame, grid)
    mapping.inputs["Scale"].default_value = (1 / grid, 1 / grid, 1)
    mapping.inputs["Location"].default_value = (c / grid, (grid - 1 - r) / grid, 0)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(texture, check_existing=True)
    img.extension = "CLIP"
    nt.links.new(coord.outputs["UV"], mapping.inputs[0])
    nt.links.new(mapping.outputs[0], img.inputs[0])
    tint = nt.nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs[0].default_value = 1
    tint.inputs[2].default_value = (*color, 1)
    nt.links.new(img.outputs["Color"], tint.inputs[1])
    shader = nt.nodes.new("ShaderNodeEmission" if additive else "ShaderNodeBsdfDiffuse")
    nt.links.new(tint.outputs[0], shader.inputs[0])
    if additive:
        shader.inputs[1].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    alpha = nt.nodes.new("ShaderNodeMath")
    alpha.operation = "MULTIPLY"
    alpha.inputs[1].default_value = opacity
    nt.links.new(img.outputs["Alpha"], alpha.inputs[0])
    nt.links.new(alpha.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(shader.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m


def card(material, location, size, rot=(math.pi / 2, 0, 0), aspect=1.0):
    bpy.ops.mesh.primitive_plane_add(size=1, location=location, rotation=rot)
    o = bpy.context.active_object
    o.scale = (size * aspect, size, 1)
    o.data.materials.append(material)
    return o


def camera(location, target, lens=40):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.location = location
    direction = [t - l for t, l in zip(target, location)]
    rot_quat = __import__("mathutils").Vector(direction).to_track_quat("-Z", "Y")
    cam.rotation_euler = rot_quat.to_euler()
    bpy.context.scene.camera = cam


def floor(color=(0.035, 0.03, 0.03)):
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(solid("floor", color, 0.9))


def point_light(location, color, energy, radius=0.5):
    data = bpy.data.lights.new("l", "POINT")
    data.color, data.energy, data.shadow_soft_size = color, energy, radius
    o = bpy.data.objects.new("l", data)
    o.location = location
    bpy.context.scene.collection.objects.link(o)


def fireball(out):
    reset()
    floor()
    # Blender: -Y is the travel direction here (Roblox -Z after export); fireball flies toward -X.
    center = (0, 0, 2.2)
    core = import_mesh("fire_core")
    core.location, core.scale = center, (0.55,) * 3
    core.data.materials.clear()
    core.data.materials.append(emissive("core", (1.0, 0.78, 0.4), 14))
    shell = import_mesh("flame_shell")
    shell.location, shell.scale = (0.35, 0, 2.2), (0.95, 0.95, 1.6)
    shell.rotation_euler = (0, 0, math.pi / 2)
    shell.data.materials.clear()
    shell.data.materials.append(emissive("shell", (1.0, 0.36, 0.06), 6, 0.55))
    hot = (1.0, 0.85, 0.55)
    body = (1.0, 0.42, 0.1)
    deep = (0.6, 0.11, 0.03)
    card(card_material("heart", tex("core_plasma"), (1.0, 0.62, 0.22), 5, 4, 3), (0, -0.4, 2.2), 2.6)
    for k in range(6):
        x = 0.6 + k * 0.55
        col = body if k < 3 else deep
        m = card_material(f"tongue{k}", tex("flame_tongue"), col, 5 - k * 0.6, 4, (k * 5) % 16, opacity=1 - k * 0.12)
        card(m, (x, 0.1 + k * 0.01, 2.2 + math.sin(k) * 0.15), 1.9 - k * 0.15, rot=(math.pi / 2, math.pi / 2 + 0.25 * math.sin(k * 1.7), 0))
    trail = card_material("trail", tex("trail_flame"), body, 4, opacity=0.9)
    card(trail, (4.6, 0.3, 2.2), 0.9, aspect=7.5)
    for k in range(14):
        em = card_material(f"ember{k}", tex("ember_streak"), (1, 0.62, 0.25), 8)
        card(em, (1.4 + (k * 0.73) % 4.5, 0.15, 1.6 + (k * 0.37) % 1.6), 0.28, rot=(math.pi / 2, math.pi / 2 + 0.3 * math.sin(k), 0))
    smoke = card_material("smoke", tex("smoke_billow"), (0.18, 0.15, 0.14), 1, 4, 6, additive=False, opacity=0.5)
    card(smoke, (6.5, 0.5, 2.5), 2.6)
    point_light(center, (1, 0.5, 0.2), 900, 1.0)
    # Impact preview on the right: explosion frame, shockwave ring, ground ring mesh, debris.
    ix = -7
    card(card_material("boom", tex("explosion_fire"), (1, 0.55, 0.2), 5, 8, 14), (ix, 0, 2.6), 6.2)
    card(card_material("ring", tex("shockwave_ring"), (1, 0.6, 0.3), 3, opacity=0.8), (ix, 0.3, 2.4), 8.5)
    ring = import_mesh("shockwave_ring")
    ring.location, ring.scale = (ix, 0, 0.05), (4.2, 4.2, 1)
    ring.data.materials.clear()
    ring.data.materials.append(emissive("gring", (1, 0.4, 0.1), 5, 0.6))
    for k, name in enumerate(["debris_rock_a", "debris_rock_b", "debris_rock_c"]):
        rock = import_mesh(name)
        rock.location = (ix + 2.2 * math.cos(k * 2.1), -1 + k * 0.4, 0.6 + k * 0.8)
        rock.scale = (0.45,) * 3
        rock.data.materials.clear()
        rock.data.materials.append(solid("rock", (0.08, 0.05, 0.04)))
    point_light((ix, -1.5, 2.5), (1, 0.45, 0.15), 2500, 2.0)
    camera((-1.5, -17, 4.2), (-1.5, 0, 2.2), lens=36)
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


def body_burst(out):
    reset()
    floor((0.05, 0.045, 0.04))
    # Caster silhouette (stand-in) at origin facing -Y.
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=3.6, location=(0, 1.2, 1.8))
    bpy.context.active_object.data.materials.append(solid("caster", (0.03, 0.03, 0.03)))
    cone = import_mesh("pressure_cone")
    # Mesh axis: opens along Roblox -Z == Blender +Y after import; aim it at -Y (away from caster).
    cone.rotation_euler = (0, 0, math.pi)
    cone.location = (0, 0.4, 2.0)
    cone.scale = (5.0, 7.5, 3.0)
    cone.data.materials.clear()
    cone.data.materials.append(emissive("cone", (0.85, 0.88, 0.9), 1.6, 0.22))
    air = (0.9, 0.92, 0.95)
    bone = (0.92, 0.82, 0.7)
    for k in range(3):
        y = -2.0 - k * 2.4
        m = card_material(f"front{k}", tex("pressure_wave"), air if k else bone, 2.2 - k * 0.4, 4, 4 + k * 3)
        card(m, (0, y, 2.0), 5 + k * 1.6, rot=(math.pi / 2 + 0.0, 0, 0))
    ring = import_mesh("shockwave_ring")
    ring.rotation_euler = (math.pi / 2, 0, 0)
    ring.location, ring.scale = (0, -8.2, 2.0), (4.2, 2.6, 1.0)
    ring.data.materials.clear()
    ring.data.materials.append(emissive("front", bone, 2.5, 0.55))
    for k in range(12):
        m = card_material(f"streak{k}", tex("ember_streak"), air, 3)
        card(m, (-2.5 + (k * 0.47) % 5, -3 - (k * 0.9) % 5, 0.8 + (k * 0.37) % 2.6), 0.45, rot=(0, math.pi / 2, math.pi / 2), aspect=4)
    for k, name in enumerate(["flesh_shard", "debris_rock_a", "debris_rock_c", "flesh_shard"]):
        frag = import_mesh(name)
        frag.location = (-2 + k * 1.3, -6 - k * 0.7, 1.0 + (k % 2) * 1.2)
        frag.rotation_euler = (k, k * 0.7, 0.3 * k)
        frag.scale = (0.4,) * 3
        frag.data.materials.clear()
        frag.data.materials.append(solid("frag", (0.3, 0.07, 0.06) if name == "flesh_shard" else (0.12, 0.1, 0.09), 0.5))
    for k in range(5):
        m = card_material(f"dust{k}", tex("dust_burst"), (0.4, 0.34, 0.3), 1, additive=False, opacity=0.65)
        card(m, (-3 + k * 1.5, -3 - k * 1.1, 0.9), 2.4 + k * 0.3)
    point_light((3, -6, 6), (0.95, 0.9, 0.85), 1800, 3)
    point_light((0, -2, 2), (0.8, 0.25, 0.2), 300, 1)
    camera((11, -12, 5.5), (0, -4.5, 1.8), lens=32)
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ROOT = args[0] if args else os.getcwd()
    prev = os.path.join(ROOT, "assets", "vfx", "previews")
    os.makedirs(prev, exist_ok=True)
    fireball(os.path.join(prev, "lookdev_fireball.png"))
    body_burst(os.path.join(prev, "lookdev_body_burst.png"))
