"""Second fire study: tapered hooked tongues, moving width rails, rigid bone poses only.

Blender --background --factory-startup --python FILE -- ROOT [--stills-only]
All artwork is authored geometry and the previously approved four-color palette.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

TAU = math.tau
RINGS, SIDES, STATIONS = 33, 8, 11
PATCHES, FRAMES = 18, 48
STEP = .22
RAIL = .5


def smooth(a,b,t):
    t = max(0,min(1,(t-a)/(b-a)))
    return t*t*(3-2*t)


def bezier(points,t):
    a,b,c,d = [Vector(p) for p in points]
    return (1-t)**3*a+3*(1-t)**2*t*b+3*(1-t)*t*t*c+t**3*d


def hook(s,phase):
    # A single flowing stroke: swept base, rising crest, pointed return curl.
    curl=.35+.65*smooth(.12,.72,phase)
    crest=.18+.42*curl
    if s <= .68:
        return bezier([(0,0),(-.55,-.10),(-1.35,.02),(-1.48,crest)],s/.68)
    end = -.95 + .15*math.sin(phase*TAU)
    return bezier([(-1.48,crest),(-1.58,crest+.42*curl),(-.70,crest+.48*curl),(end,crest+.05)],(s-.68)/.32)


def profile(s):
    # Root blends into the body; a broad lower stroke narrows smoothly into a fine tip.
    return .012 + .37*(math.sin(math.pi*s)**.65)*(1-.65*s)


def phase_for(index,t):
    return (t+(index/8 if index<8 else (index-8)/10+.07))%1


def flow(index,phase,s):
    inner = index >= 8
    azimuth = index*2.3999632297
    q = (phase-.10)/.83
    surface = smooth(-.1,.27,q)
    x=1.28-(2.1 if inner else 3.45)*max(-.04,q)
    radius = (.84*math.sqrt(max(0,1-((x-.1)/1.25)**2))) if inner else .84*surface*(1-.5*smooth(.45,1.1,q))
    angle = azimuth + .20*math.sin(phase*TAU) + q*.32
    radial = Vector((0,math.cos(angle),math.sin(angle)))
    origin = Vector((x,0,0))+radial*radius
    life = smooth(0,.18,phase)*(1-smooth(.76,1,phase))
    length = .18+.82*smooth(0,.24,phase)
    stroke = hook(s,phase)
    scale = 1.1 if inner else 1.0
    center = origin + Vector((stroke.x*length*scale,0,0)) + radial*stroke.y*length*scale
    # Pull the neck thin late in its life, letting the hot hooked tip continue outward.
    neck = 1-.9*smooth(.57,.88,phase)*(1-smooth(.05,.42,s))
    return center,life*scale*neck*(1.65 if inner else 1),radial


def palette_material(out):
    colors = [(.58,.018,.002),(1,.12,.005),(1,.48,.025),(1,.85,.25)]
    image = bpy.data.images.new("ApprovedCelPalette",width=64,height=16)
    image.pixels = [v for y in range(16) for x in range(64) for v in (*colors[x//16],1)]
    image.filepath_raw = str(out/"cel_palette.png")
    image.file_format = "PNG"
    image.save()
    mat = bpy.data.materials.new("ApprovedCelBands")
    mat.diffuse_color = (*colors[1],1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    nodes.active = tex
    mat.node_tree.links.new(tex.outputs["Color"],nodes.get("Principled BSDF").inputs["Base Color"])
    return mat


def build_tongue(index,material,collection):
    name = f"Tongue_{index:02d}"
    vertices,faces = [],[]
    for ring in range(RINGS):
        s = ring/(RINGS-1)
        for side in range(SIDES):
            a = TAU*side/SIDES
            vertices.append((profile(s)*math.cos(a),s*(STATIONS-1)*STEP,
                             (.15 if index>=8 else .055)*math.sin(math.pi*s)**.7*math.sin(a)))
    for ring in range(RINGS-1):
        for side in range(SIDES):
            nextside=(side+1)%SIDES
            faces.append((ring*SIDES+side,ring*SIDES+nextside,(ring+1)*SIDES+nextside,(ring+1)*SIDES+side))
    faces.extend([tuple(reversed(range(SIDES))),tuple((RINGS-1)*SIDES+i for i in range(SIDES))])
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    collection.objects.link(obj)
    data.materials.append(material)
    uv=data.uv_layers.new(name="CelBands")
    # Bright central ridge on both faces; no large solid red reverse face.
    bands=[1,2,3,2,1,2,3,2]
    for poly in data.polygons:
        band=bands[poly.index%SIDES] if poly.index<(RINGS-1)*SIDES else 1
        for loop in poly.loop_indices: uv.data[loop].uv=((band+.5)/4,.5)
    arm=bpy.data.armatures.new(name+"_Skeleton")
    rig=bpy.data.objects.new(name+"_Rig",arm)
    collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root=arm.edit_bones.new("Root")
    root.head,root.tail=(0,0,0),(0,0,.1)
    root.use_deform=False
    for station in range(STATIONS):
        for rail,sign in (("L",-1),("R",1)):
            bone=arm.edit_bones.new(f"{rail}_{station:02d}")
            bone.head=(sign*RAIL,station*STEP,0)
            bone.tail=(sign*RAIL,station*STEP+.1,0)
            bone.parent=root
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    obj.parent=rig
    mod=obj.modifiers.new("RigidRailSkin","ARMATURE")
    mod.object=rig
    groups={bone.name:obj.vertex_groups.new(name=bone.name) for bone in arm.bones if bone.use_deform}
    for ring in range(RINGS):
        station=ring/(RINGS-1)*(STATIONS-1)
        low=min(STATIONS-2,int(station))
        amount=station-low
        for side in range(SIDES):
            idx=ring*SIDES+side
            x=vertices[idx][0]
            right=.5+x/(2*RAIL)
            for control,long_weight in ((low,1-amount),(low+1,amount)):
                for rail,cross_weight in (("L",1-right),("R",right)):
                    weight=long_weight*cross_weight
                    if weight>1e-7: groups[f"{rail}_{control:02d}"].add([idx],weight,"REPLACE")
    return obj,rig


def pose(rig,index,t):
    phase=phase_for(index,t)
    for station in range(STATIONS):
        s=station/(STATIONS-1)
        center,width,radial=flow(index,phase,s)
        a,_,_=flow(index,phase,max(0,s-.003))
        b,_,_=flow(index,phase,min(1,s+.003))
        tangent=(b-a).normalized()
        # Width lies in the flame's curling plane, not around the ball as a broad plate.
        plane_normal=Vector((0,-radial.z,radial.y))
        across=Vector((0,radial.z,-radial.y)) if index>=8 else tangent.cross(plane_normal).normalized()
        normal=across.cross(tangent).normalized()
        rotation=Matrix((across,tangent,normal)).transposed().to_4x4()
        for rail,sign in (("L",-1),("R",1)):
            bone=rig.pose.bones[f"{rail}_{station:02d}"]
            bone.matrix=Matrix.Translation(center+sign*RAIL*width*across)@rotation


def keyframe(rig,frame):
    for bone in rig.pose.bones:
        if bone.name!="Root":
            bone.keyframe_insert("location",frame=frame,group=bone.name)
            bone.keyframe_insert("rotation_quaternion",frame=frame,group=bone.name)


def camera_at(camera,position,target=(-.8,0,0)):
    camera.location=position
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("root",type=Path)
    parser.add_argument("--stills-only",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    out=args.root/"assets/vfx/studies/3d_fire_v2"
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.engine="BLENDER_WORKBENCH"
    scene.render.resolution_x,scene.render.resolution_y=720,480
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.fps=24
    scene.frame_start,scene.frame_end=1,FRAMES
    scene.view_settings.view_transform="Standard"
    shading=scene.display.shading
    shading.light="FLAT"
    shading.color_type="TEXTURE"
    shading.show_shadows=False
    shading.show_cavity=False
    shading.show_specular_highlight=False
    shading.show_object_outline=False
    shading.background_type="WORLD"
    scene.world=bpy.data.worlds.new("Charcoal")
    scene.world.color=(.025,.029,.04)
    collection=bpy.data.collections.new("HookedFlameStudy")
    scene.collection.children.link(collection)
    material=palette_material(out)
    objects,rigs=[],[]
    for index in range(PATCHES):
        obj,rig=build_tongue(index,material,collection)
        objects.append(obj);rigs.append(rig)
    for frame in range(1,FRAMES+2):
        for index,rig in enumerate(rigs):
            pose(rig,index,(frame-1)/FRAMES)
            keyframe(rig,frame)
    camdata=bpy.data.cameras.new("ReviewCamera")
    camera=bpy.data.objects.new("ReviewCamera",camdata)
    scene.collection.objects.link(camera)
    scene.camera=camera
    camdata.type="ORTHO"
    camdata.ortho_scale=7.6
    camera_at(camera,(-.8,-10,1.8))
    scene.frame_set(18)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"hooked_flame_study.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    objects[0].select_set(True);rigs[0].select_set(True)
    bpy.context.view_layer.objects.active=rigs[0]
    bpy.ops.export_scene.fbx(filepath=str(out/"single_hooked_tongue.fbx"),use_selection=True,
        object_types={"MESH","ARMATURE"},add_leaf_bones=False,bake_anim=True,
        bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,axis_forward="-Z",axis_up="Y",global_scale=.01)
    for name,position in [("side",(-.8,-10,0)),("front",(10,0,.3)),("rear",(-10,0,.3)),("oblique",(5,-8,4))]:
        camera_at(camera,position)
        scene.render.filepath=str(out/f"{name}.png")
        bpy.ops.render.render(write_still=True)
    for obj in objects[1:]:obj.hide_render=True
    camera_at(camera,(-.8,0,10))
    scene.render.filepath=str(out/"single_tongue.png")
    bpy.ops.render.render(write_still=True)
    for obj in objects:obj.hide_render=False
    if not args.stills_only:
        for mode in ("fixed","orbit","diagnostic"):
            (out/mode).mkdir(exist_ok=True)
            for frame in range(1,FRAMES+1):
                scene.frame_set(frame)
                if mode=="orbit":
                    angle=TAU*(frame-1)/FRAMES
                    camera_at(camera,(-.8+9*math.sin(angle),-9*math.cos(angle),3))
                elif mode=="diagnostic":camera_at(camera,(-.8,0,10))
                else:camera_at(camera,(-.8,-10,1.8))
                for index,obj in enumerate(objects):
                    phase=phase_for(index,(frame-1)/FRAMES)
                    life=smooth(0,.18,phase)*(1-smooth(.76,1,phase))
                    obj.hide_render=(mode=="diagnostic" and index!=0) or life<.08
                scene.render.filepath=str(out/mode/f"{frame:03d}.png")
                bpy.ops.render.render(write_still=True)
            for obj in objects:obj.hide_render=False
    report={"status":"Revised authored geometry study; not yet imported or accepted", "frames":FRAMES,"fps":24,
        "tongues":PATCHES,"deform_bones_per_tongue":STATIONS*2,"vertices_per_tongue":RINGS*SIDES,
        "palette":"Same four RGB colors as v1","animation":"Rigid bone rotations and translations only; width changes through paired rails",
        "visibility":"Hide a tongue below .08 lifecycle width to conceal the thin reset; visibility is not baked into FBX",
        "limitations":["Full-body silhouette and resetting need visual review","No performance claim","No gameplay integration"]}
    (out/"manifest.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__":main()
