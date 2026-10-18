"""Author a skinned, solid-mesh fire transport study and honest Blender previews.

Run with Blender --background --factory-startup --python this_file -- ROOT.
No image generation, texture upload, Studio modifications or gameplay changes.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

TAU = math.tau
BONES = 21
SIDES = 8
PATCHES = 24
FRAMES = 48
REST_STEP = .3


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    return mat


def trajectory(phase, s, azimuth):
    # A material ridge moves head -> flank -> wake, rather than rocking in place.
    u = phase * 1.20 - .24 + s * .48
    front = max(0, min(1, u / .32))
    radius = 1.08 * math.sin(front * math.pi / 2)
    radius *= max(.18, 1 - max(0, u-.48)*.85)
    angle = azimuth + .42*u + .18*math.sin(u*TAU)
    curl = max(0, (s-.48)/.52)
    curl_angle = curl * (3.6 + phase*1.2)
    # Curls develop toward the tip, becoming more pronounced toward the rear.
    x = 1.45 - 4.2*u + .72*curl*(1-math.cos(curl_angle))
    radius += .72*curl*math.sin(curl_angle)
    angle += .24*curl*(1-math.cos(curl_angle))
    if u < 0:
        radius = 0
        x = 1.45 + u*.6
    return Vector((x, radius*math.cos(angle), radius*math.sin(angle)))


def lifecycle(phase):
    grow = min(1, max(.001, phase/.19))
    die = min(1, max(.001, (1-phase)/.20))
    return grow*die


def build_patch(index, palette, collection):
    name = f"Flame_{index:02d}"
    vertices, faces = [], []
    for ring in range(BONES):
        s = ring/(BONES-1)
        width = .015 + 1.12 * math.sin(math.pi*s)**.75 * (1-.75*s)
        for side in range(SIDES):
            a = TAU*side/SIDES
            vertices.append((width*math.cos(a),ring*REST_STEP,.22*math.sin(math.pi*s)*math.sin(a)))
    for ring in range(BONES-1):
        for side in range(SIDES):
            nxt = (side+1)%SIDES
            faces.append((ring*SIDES+side,ring*SIDES+nxt,(ring+1)*SIDES+nxt,(ring+1)*SIDES+side))
    faces += [tuple(reversed(range(SIDES))),tuple((BONES-1)*SIDES+s for s in range(SIDES))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    mesh.materials.append(palette)
    uv = mesh.uv_layers.new(name="CelBands")
    for polygon in mesh.polygons:
        # Broad longitudinal color regions; they deform with the geometry.
        side = polygon.index % SIDES
        band = [1,2,3,2,1,0,0,0][side] if polygon.index < (BONES-1)*SIDES else 0
        for loop in polygon.loop_indices:
            uv.data[loop].uv = ((band+.5)/4,.5)
    armature = bpy.data.armatures.new(name+"_Skeleton")
    rig = bpy.data.objects.new(name+"_Rig",armature)
    collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = armature.edit_bones.new("Root")
    root.head, root.tail = (0,0,0),(0,0,.2)
    root.use_deform = False
    for ring in range(BONES):
        bone = armature.edit_bones.new(f"Flow_{ring:02d}")
        bone.head = (0,ring*REST_STEP,0)
        bone.tail = (0,(ring+1)*REST_STEP,0)
        bone.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    obj.parent = rig
    modifier = obj.modifiers.new("FlowSkin","ARMATURE")
    modifier.object = rig
    for ring in range(BONES):
        group = obj.vertex_groups.new(name=f"Flow_{ring:02d}")
        group.add(list(range(ring*SIDES,(ring+1)*SIDES)),1,"REPLACE")
    return obj,rig


def pose(rig, index, time):
    phase = (time+index/PATCHES)%1
    # Distribute tracks independently of lifecycle phase.
    azimuth = index*2.3999632297
    width = lifecycle(phase)
    for ring in range(BONES):
        s = ring/(BONES-1)
        center = trajectory(phase,s,azimuth)
        next_center = trajectory(phase,s+.015,azimuth)
        tangent = (next_center-center).normalized()
        across = Vector((0,math.sin(azimuth),-math.cos(azimuth)))
        across = (across-tangent*across.dot(tangent)).normalized()
        normal = across.cross(tangent).normalized()
        rotation = Matrix((across,tangent,normal)).transposed().to_4x4()
        # Match cross-section thickness/width; longitudinal deformation is posed by rings.
        scale = Matrix.Diagonal((width,1,width,1))
        rig.pose.bones[f"Flow_{ring:02d}"].matrix = Matrix.Translation(center) @ rotation @ scale


def keyframe(rig, frame):
    for bone in rig.pose.bones:
        if bone.name != "Root":
            bone.keyframe_insert("location",frame=frame,group=bone.name)
            bone.keyframe_insert("rotation_quaternion",frame=frame,group=bone.name)
            bone.keyframe_insert("scale",frame=frame,group=bone.name)


def camera_at(camera, position, target=(-.7,0,0)):
    camera.location = position
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root",type=Path)
    parser.add_argument("--stills-only",action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    out = args.root/"assets/vfx/studies/3d_fire_v1"
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x,scene.render.resolution_y = 640,480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.fps = 24
    scene.frame_start,scene.frame_end = 1,FRAMES
    scene.view_settings.view_transform = "Standard"
    shading = scene.display.shading
    shading.light = "FLAT"
    shading.color_type = "TEXTURE"
    shading.show_shadows = False
    shading.show_cavity = False
    shading.show_specular_highlight = False
    shading.show_object_outline = False
    shading.background_type = "WORLD"
    scene.world = bpy.data.worlds.new("Charcoal")
    scene.world.color = (.025,.029,.04)
    collection = bpy.data.collections.new("FireTransport")
    scene.collection.children.link(collection)
    colors = [(.58,.018,.002),(1,.12,.005),(1,.48,.025),(1,.85,.25)]
    texture = bpy.data.images.new("CelPalette",width=64,height=16)
    texture.pixels = [channel for y in range(16) for x in range(64) for channel in (*colors[x//16],1)]
    texture.filepath_raw = str(out/"cel_palette.png")
    texture.file_format = "PNG"
    texture.save()
    palette = material("CelPalette",colors[1])
    palette.use_nodes = True
    nodes = palette.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = texture
    tex.interpolation = "Closest"
    nodes.active = tex
    palette.node_tree.links.new(tex.outputs["Color"],nodes.get("Principled BSDF").inputs["Base Color"])
    objects,rigs = [],[]
    for index in range(PATCHES):
        obj,rig = build_patch(index,palette,collection)
        objects.append(obj)
        rigs.append(rig)
    for frame in range(1,FRAMES+2):
        time = (frame-1)/FRAMES
        for index,rig in enumerate(rigs):
            pose(rig,index,time)
            keyframe(rig,frame)
    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera",camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 7.3
    camera_at(camera,(-.6,-10,3.4))
    scene.frame_set(15)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"fire_transport_study.blend"))
    # Minimal skinned transport proof: one mesh and its rig, with baked motion.
    bpy.ops.object.select_all(action="DESELECT")
    objects[0].select_set(True)
    rigs[0].select_set(True)
    bpy.context.view_layer.objects.active = rigs[0]
    bpy.ops.export_scene.fbx(filepath=str(out/"single_flame_transport.fbx"),use_selection=True,
        object_types={"MESH","ARMATURE"},add_leaf_bones=False,bake_anim=True,
        bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,
        axis_forward="-Z",axis_up="Y",global_scale=.01)
    for index,(name,pos) in enumerate([("side",(-.6,-10,0)),("front",(10,0,.3)),("rear",(-10,0,.3)),("oblique",(5,-8,4))]):
        camera_at(camera,pos)
        scene.render.filepath = str(out/f"{name}.png")
        bpy.ops.render.render(write_still=True)
    if not args.stills_only:
        for mode in ("fixed","orbit","diagnostic"):
            (out/mode).mkdir(exist_ok=True)
            for frame in range(1,FRAMES+1):
                scene.frame_set(frame)
                if mode == "orbit":
                    a = TAU*(frame-1)/FRAMES
                    camera_at(camera,(-.7+9*math.sin(a),-9*math.cos(a),3.8))
                else:
                    camera_at(camera,(-.6,-10,2.3))
                if mode == "diagnostic":
                    for obj in objects[1:]: obj.hide_render = True
                scene.render.filepath = str(out/mode/f"{frame:03d}.png")
                bpy.ops.render.render(write_still=True)
            for obj in objects: obj.hide_render = False
    report = {"status":"Blender motion study; Studio import unverified", "frames":FRAMES,"fps":24,
        "patches":PATCHES,"deform_bones_per_patch":BONES,"vertices_per_patch":BONES*SIDES,
        "faces_per_patch":(BONES-1)*SIDES+2,"source_reference":"user concept sheet 5aa64350-9274-4053-9e5c-c0b2cc0bd615",
        "motion":"Staggered solid skinned patches born inside, advected head to flank to wake, curled and collapsed at expiry",
        "coordinates":"Blender +X is projectile forward; verify Roblox axis/scale during import",
        "limitations":["First motion construction, not final art","Simple four-band UV palette, no production textures","Not performance profiled","No Studio upload or gameplay integration"]}
    (out/"manifest.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__":
    main()
