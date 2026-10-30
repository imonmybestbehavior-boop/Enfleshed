"""Connected 3D fire volume with advected cel contours and rigid skin deformation.

Blender --background --factory-startup --python FILE -- ROOT [--stills-only]
The UV animation is exported as complete texture frames; no Roblox shader support is assumed.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

TAU=math.tau
ROWS,COLS=48,64
U_BONES,A_BONES=9,8
FRAMES,TEXTURE_FRAMES=48,24


def smooth(a,b,x):
    k=max(0,min(1,(x-a)/(b-a)))
    return k*k*(3-2*k)


def surface(u,a,t):
    radius=1.25*max(0,math.sin(math.pi*u))**.62*(1-.57*u)
    wave=.048*math.sin(TAU*(3*u-2*t)+3*a)+.028*math.sin(TAU*(5*u-3*t)-2*a)
    radius*=1+wave*(.45+1.8*u)
    rear=smooth(.48,.98,u)
    radius+=.10*rear*max(0,.5+.5*math.sin(5*a-TAU*(2*u-2*t)))**5
    x=1.35-4.45*u
    x-=.28*rear*math.sin(5*a-TAU*(2*u-2*t))
    side=.10*rear*math.sin(TAU*(u-t))
    return Vector((x,radius*math.cos(a)+side,radius*math.sin(a)))


def textures(out):
    directory=out/"flow_textures"
    directory.mkdir(exist_ok=True)
    # Exactly the same authored RGB stops used in the approved palette.
    palette=np.array([(.58,.018,.002,1),(1,.12,.005,1),(1,.48,.025,1),(1,.85,.25,1)],dtype=np.float32)
    u=np.linspace(0,1,1024,dtype=np.float32)[None,:]
    a=np.linspace(0,TAU,512,dtype=np.float32)[:,None]
    for frame in range(TEXTURE_FRAMES):
        t=frame/TEXTURE_FRAMES
        adv=TAU*(2*u-2*t)
        warp=1.5*np.sin(adv)+.5*np.sin(2*adv+.7*np.sin(3*a))
        field=.70*np.sin(5*a+warp)+.23*np.sin(9*a-adv*1.5)+.12*np.sin(13*a+adv*2)
        field+=1.5*np.exp(-(u/.16)**2)
        bands=np.where(field>.76,3,np.where(field>.05,2,np.where(field>-.72,1,0)))
        pixels=palette[bands]
        pixels[:,u[0]<.035,:]=palette[3]
        tear=np.sin(5*a+warp*.7)+.30*np.sin(9*a-adv)
        threshold=(u-.65)*4.3-.8
        pixels[:,:,3]=np.where(u<.56,1,(tear>threshold).astype(np.float32))
        pixels[:,u[0]>.985,3]=0
        # Force matching edge rows so the circumferential UV seam cannot flash.
        pixels[-1,:,:]=pixels[0,:,:]
        image=bpy.data.images.new(f"FireFlow_{frame+1:03d}",width=1024,height=512,alpha=True)
        image.pixels.foreach_set(pixels.reshape(-1))
        image.filepath_raw=str(directory/f"flow_{frame+1:03d}.png")
        image.file_format="PNG"
        image.save()
        bpy.data.images.remove(image)
    return [directory/f"flow_{i+1:03d}.png" for i in range(TEXTURE_FRAMES)]


def make_mesh(material):
    vertices,faces,uvs=[],[],[]
    # Duplicated seam vertices have identical position and different UVs.
    for row in range(1,ROWS):
        u=row/ROWS
        for col in range(COLS+1):
            vertices.append(tuple(surface(u,TAU*col/COLS,0)))
            uvs.append((u,col/COLS))
    for row in range(ROWS-2):
        for col in range(COLS):
            p=row*(COLS+1)+col
            faces.append((p,p+1,p+COLS+2,p+COLS+1))
    nose=len(vertices);vertices.append(tuple(surface(0,0,0)));uvs.append((0,.5))
    tail=len(vertices);vertices.append(tuple(surface(1,0,0)));uvs.append((1,.5))
    last=(ROWS-2)*(COLS+1)
    for col in range(COLS):
        faces.append((nose,col+1,col))
        faces.append((tail,last+col,last+col+1))
    mesh=bpy.data.meshes.new("ConnectedFireVolume")
    mesh.from_pydata(vertices,[],[tuple(reversed(face)) for face in faces])
    mesh.update()
    obj=bpy.data.objects.new("ConnectedFireVolume",mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(material)
    uv=mesh.uv_layers.new(name="SurfaceFlowUV")
    for poly in mesh.polygons:
        poly.use_smooth=True
        for loop in poly.loop_indices:
            uv.data[loop].uv=uvs[mesh.loops[loop].vertex_index]
    return obj,uvs


def make_rig(obj,uvs):
    data=bpy.data.armatures.new("ConnectedFireRig")
    rig=bpy.data.objects.new("ConnectedFireRig",data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root=data.edit_bones.new("Root")
    root.head,root.tail=(0,0,0),(0,0,.1)
    root.use_deform=False
    for row in range(U_BONES):
        for col in range(A_BONES):
            bone=data.edit_bones.new(f"Flow_{row:02d}_{col:02d}")
            # Independent translation controls; rest orientation is identical for all.
            p=surface(row/(U_BONES-1),TAU*col/A_BONES,0)
            bone.head=p;bone.tail=p+Vector((0,.1,0));bone.parent=root
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    obj.parent=rig
    mod=obj.modifiers.new("CoherentVolumeSkin","ARMATURE");mod.object=rig
    groups={bone.name:obj.vertex_groups.new(name=bone.name) for bone in data.bones if bone.use_deform}
    for index,(u,v) in enumerate(uvs):
        station=u*(U_BONES-1)
        low=min(U_BONES-2,int(station));du=station-low
        angle=(v%1)*A_BONES
        left=int(angle)%A_BONES;da=angle-int(angle)
        for row,wu in ((low,1-du),(low+1,du)):
            for col,wa in ((left,1-da),((left+1)%A_BONES,da)):
                if wu*wa>1e-7:groups[f"Flow_{row:02d}_{col:02d}"].add([index],wu*wa,"REPLACE")
    return rig


def pose(rig,t,frame):
    for row in range(U_BONES):
        for col in range(A_BONES):
            u,a=row/(U_BONES-1),TAU*col/A_BONES
            bone=rig.pose.bones[f"Flow_{row:02d}_{col:02d}"]
            bone.location=surface(u,a,t)-surface(u,a,0)
            bone.keyframe_insert("location",frame=frame,group=bone.name)


def camera_at(camera,position,target=(-.7,0,0)):
    camera.location=position
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("root",type=Path)
    parser.add_argument("--stills-only",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    out=args.root/"assets/vfx/studies/3d_fire_v4"
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.engine="BLENDER_EEVEE"
    scene.render.resolution_x,scene.render.resolution_y=720,480
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.fps=24
    scene.frame_start,scene.frame_end=1,FRAMES
    scene.view_settings.view_transform="Standard"
    shade=scene.display.shading
    shade.light="FLAT";shade.color_type="TEXTURE"
    shade.show_shadows=False;shade.show_cavity=False;shade.show_specular_highlight=False;shade.show_object_outline=False
    shade.background_type="WORLD"
    scene.world=bpy.data.worlds.new("Charcoal");scene.world.color=(.025,.029,.04)
    paths=textures(out)
    images=[bpy.data.images.load(str(p)) for p in paths]
    material=bpy.data.materials.new("FlowingCelContours");material.use_nodes=True
    material.diffuse_color=(1,.12,.005,1)
    tex=material.node_tree.nodes.new("ShaderNodeTexImage");tex.image=images[0]
    material.node_tree.nodes.active=tex
    nodes=material.node_tree.nodes;links=material.node_tree.links
    shader=nodes.get("Principled BSDF")
    links.new(tex.outputs["Color"],shader.inputs["Base Color"])
    links.new(tex.outputs["Color"],shader.inputs["Emission Color"])
    shader.inputs["Emission Strength"].default_value=1
    links.new(tex.outputs["Alpha"],shader.inputs["Alpha"])
    links.new(shader.outputs[0],nodes.get("Material Output").inputs["Surface"])
    material.surface_render_method="DITHERED"
    material.use_transparent_shadow=False
    obj,uvs=make_mesh(material)
    rig=make_rig(obj,uvs)
    for frame in range(1,FRAMES+2):pose(rig,(frame-1)/FRAMES,frame)
    data=bpy.data.cameras.new("ReviewCamera")
    camera=bpy.data.objects.new("ReviewCamera",data);scene.collection.objects.link(camera);scene.camera=camera
    data.type="ORTHO";data.ortho_scale=6.0
    def set_frame(frame):
        scene.frame_set(frame)
        tex.image=images[((frame-1)//2)%TEXTURE_FRAMES]
    set_frame(17)
    camera_at(camera,(-.7,-10,1.8))
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"connected_fireball.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.fbx(filepath=str(out/"connected_fireball.fbx"),use_selection=True,
        object_types={"MESH","ARMATURE"},add_leaf_bones=False,bake_anim=True,
        bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,axis_forward="-Z",axis_up="Y",global_scale=.01)
    set_frame(17)
    for name,position in [("side",(-.7,-10,0)),("front",(10,0,.2)),("rear",(-10,0,.2)),("oblique",(5,-8,4))]:
        camera_at(camera,position)
        scene.render.filepath=str(out/f"{name}.png");bpy.ops.render.render(write_still=True)
    if not args.stills_only:
        for mode in ("fixed","orbit","diagnostic"):
            (out/mode).mkdir(exist_ok=True)
            for frame in range(1,FRAMES+1):
                set_frame(frame)
                data.ortho_scale=4.7 if mode=="diagnostic" else 6.0
                if mode=="orbit":
                    angle=TAU*(frame-1)/FRAMES
                    camera_at(camera,(-.7+9*math.sin(angle),-9*math.cos(angle),2.5))
                elif mode=="diagnostic":camera_at(camera,(-.1,-10,.7),target=(-.1,0,0))
                else:camera_at(camera,(-.7,-10,1.8))
                scene.render.filepath=str(out/mode/f"{frame:03d}.png");bpy.ops.render.render(write_still=True)
    manifest={"status":"Connected-volume Blender study; not yet Studio imported or visually accepted",
        "meshes":1,"deform_bones":U_BONES*A_BONES,"frames":FRAMES,"fps":24,
        "texture_frames":TEXTURE_FRAMES,"texture_fps":12,"texture_dimensions":[1024,512],
        "appearance":"Approved four RGB colors, one filled rounded head, moving surface contours and rear deformation",
        "implementation":"Rigid bone translations plus complete UV texture frames; no custom Roblox shader assumed",
        "limitations":["Texture playback must be implemented separately from FBX bone animation",
                       "The saved blend shows one surface texture; use generator to render synchronized contour playback",
                       "Alpha tail erosion needs SurfaceAppearance transparency in Studio","No detached fragments yet","No Studio or performance verification"]}
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__":main()
