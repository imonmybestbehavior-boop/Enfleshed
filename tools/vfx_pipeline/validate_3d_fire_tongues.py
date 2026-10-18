"""Validate the v2 rigid-rail rig, loop, weights and exported FBX in Blender."""
import hashlib
import argparse
import json
import math
from pathlib import Path
import sys
import bpy

parser=argparse.ArgumentParser()
parser.add_argument("root",type=Path)
parser.add_argument("--version",choices=["2","3"],default="2")
args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
root=args.root
out=root/f"assets/vfx/studies/3d_fire_v{args.version}"
bpy.ops.wm.open_mainfile(filepath=str(out/"hooked_flame_study.blend"))
scene=bpy.context.scene
meshes=sorted((o for o in scene.objects if o.type=="MESH"),key=lambda o:o.name)
rigs=sorted((o for o in scene.objects if o.type=="ARMATURE"),key=lambda o:o.name)
assert len(meshes)==18 and len(rigs)==18
max_influences=0
for mesh in meshes:
    assert len(mesh.material_slots)==1
    for v in mesh.data.vertices:
        assert 1<=len(v.groups)<=4
        assert abs(sum(g.weight for g in v.groups)-1)<1e-5
        max_influences=max(max_influences,len(v.groups))

def sample(frame):
    scene.frame_set(frame)
    graph=bpy.context.evaluated_depsgraph_get()
    return [[tuple(v.co) for v in o.evaluated_get(graph).data.vertices] for o in meshes]

def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))

first,middle,last=sample(1),sample(13),sample(49)
loop_error=max(distance(a,b) for aa,bb in zip(first,last) for a,b in zip(aa,bb))
motion=min(max(distance(a,b) for a,b in zip(aa,bb)) for aa,bb in zip(first,middle))
assert loop_error<1e-4 and motion>.1
scale_error=0
rotation_error=0
for frame in range(1,50):
    scene.frame_set(frame)
    for rig in rigs:
        for bone in rig.pose.bones:
            scale_error=max(scale_error,max(abs(v-1) for v in bone.scale))
            rotation_error=max(rotation_error,abs(bone.matrix.to_3x3().determinant()-1))
assert scale_error<1e-5 and rotation_error<1e-4,(scale_error,rotation_error)
shell_error=None
if args.version=="3":
    sys.path.insert(0,str(root/"tools/vfx_pipeline"))
    import build_3d_fire_tongues as generator
    shell_error=0
    for index in range(18):
        for phase in (.1,.25,.5,.75,.9):
            base=generator.flow(index,phase,0)[0]
            radius=math.hypot(base.y,base.z)
            for step in range(33):
                point=generator.flow(index,phase,step/32)[0]
                shell_error=max(shell_error,math.hypot(point.y,point.z)-radius)
    assert shell_error<1e-6,shell_error
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(out/"single_hooked_tongue.fbx"))
imports=[o for o in bpy.context.scene.objects if o.type=="MESH"]
arms=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
assert len(imports)==1 and len(arms)==1
assert len(arms[0].data.bones)==23
assert arms[0].animation_data and arms[0].animation_data.action
result={"passed":True,"scope":"Blender source and FBX reimport; revised asset not Studio verified",
    "tongues":18,"deform_bones_per_tongue":22,"max_skin_influences":max_influences,
    "loop_max_vertex_error":loop_error,"minimum_quarter_cycle_vertex_motion":motion,
    "maximum_bone_scale_error":scale_error,"maximum_rotation_determinant_error":rotation_error,
    "maximum_centerline_outward_excursion":shell_error,
    "fbx_meshes":1,"fbx_bones":23,"fbx_animation_present":True,
    "export_sha256":hashlib.sha256((out/"single_hooked_tongue.fbx").read_bytes()).hexdigest()}
(out/"validation.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result))
