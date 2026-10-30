"""Blender-side skinning, loop and exported-FBX validation; not a Roblox import check."""
import json
from pathlib import Path
import sys
import math
import bpy

root = Path(sys.argv[sys.argv.index("--")+1])
out = root/"assets/vfx/studies/3d_fire_v1"
bpy.ops.wm.open_mainfile(filepath=str(out/"fire_transport_study.blend"))
scene = bpy.context.scene
objects = sorted((obj for obj in scene.objects if obj.type == "MESH"),key=lambda x:x.name)
assert len(objects) == 24
for obj in objects:
    assert len(obj.material_slots) == 1
    assert len(obj.data.uv_layers) == 1
    assert any(m.type == "ARMATURE" and m.object for m in obj.modifiers)
    for vertex in obj.data.vertices:
        assert len(vertex.groups) == 1
        assert abs(sum(g.weight for g in vertex.groups)-1) < 1e-5

def sample(frame):
    scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    return [[tuple(v.co) for v in obj.evaluated_get(graph).data.vertices] for obj in objects]

first, middle, end = sample(1),sample(13),sample(49)
def distance(a,b): return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
loop_error = max(distance(a,b) for aa,bb in zip(first,end) for a,b in zip(aa,bb))
motion = [max(distance(a,b) for a,b in zip(aa,bb)) for aa,bb in zip(first,middle)]
assert loop_error < .0001, loop_error
assert min(motion) > .1, motion
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(out/"single_flame_transport.fbx"))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
assert len(meshes) == 1 and len(rigs) == 1
assert len(rigs[0].data.bones) == 22
assert rigs[0].animation_data and rigs[0].animation_data.action
assert any(m.type == "ARMATURE" for m in meshes[0].modifiers)
report = {"passed":True,"scope":"Blender source and FBX roundtrip only; Roblox import unverified",
          "patches":24,"skin_weights":"one normalized influence per vertex",
          "materials_per_patch":1,"loop_max_vertex_error":loop_error,
          "minimum_patch_vertex_motion_at_quarter_cycle":min(motion),
          "fbx_roundtrip":{"meshes":len(meshes),"rigs":len(rigs),"bones":len(rigs[0].data.bones),"animation_action":True}}
(out/"validation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report))
