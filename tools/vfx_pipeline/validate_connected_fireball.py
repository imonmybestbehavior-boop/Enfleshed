"""Validate the connected volume, skinning, surface-frame coverage and FBX roundtrip."""
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
import numpy as np

root=Path(sys.argv[sys.argv.index("--")+1])
out=root/"assets/vfx/studies/3d_fire_v4"
bpy.ops.wm.open_mainfile(filepath=str(out/"connected_fireball.blend"))
scene=bpy.context.scene
meshes=[o for o in scene.objects if o.type=="MESH"]
assert len(meshes)==1
obj=meshes[0]
rig=next(o for o in scene.objects if o.type=="ARMATURE")
assert len(rig.data.bones)==73
assert len(obj.material_slots)==1 and len(obj.data.uv_layers)==1
maximum=0
for vertex in obj.data.vertices:
    assert 1<=len(vertex.groups)<=4
    assert abs(sum(g.weight for g in vertex.groups)-1)<1e-5
    maximum=max(maximum,len(vertex.groups))
bm=bmesh.new();bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5)
assert all(edge.is_manifold for edge in bm.edges),"Body must be a closed volume before visual tail erosion"
unvisited=set(bm.verts);components=0
while unvisited:
    components+=1
    stack=[unvisited.pop()]
    while stack:
        vertex=stack.pop()
        for edge in vertex.link_edges:
            neighbor=edge.other_vert(vertex)
            if neighbor in unvisited:unvisited.remove(neighbor);stack.append(neighbor)
assert components==1,components
bm.free()

def sample(frame):
    scene.frame_set(frame)
    data=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    return np.array([v.co[:] for v in data.vertices])

first,middle,last=sample(1),sample(13),sample(49)
loop_error=float(np.max(np.linalg.norm(first-last,axis=1)))
motion=float(np.max(np.linalg.norm(first-middle,axis=1)))
assert loop_error<1e-5 and motion>.02
for frame in range(1,50):
    scene.frame_set(frame)
    assert all(max(abs(v-1) for v in bone.scale)<1e-5 for bone in rig.pose.bones)
files=sorted((out/"flow_textures").glob("flow_*.png"))
assert len(files)==24
reference=None;core_changes=[]
for filename in files:
    image=bpy.data.images.load(str(filename),check_existing=False)
    assert tuple(image.size)==(1024,512) and image.channels==4
    pixels=np.array(image.pixels[:],dtype=np.float32).reshape(512,1024,4)
    assert np.min(pixels[:,:573,3])>.999,"Leading body must remain filled"
    assert np.min(pixels[:,650:,3])<.01,"Rear breakup must actually remove visible surface"
    assert np.max(np.abs(pixels[0]-pixels[-1]))<1e-5,"UV seam mismatch"
    core=pixels[:,150:550,:3]
    if reference is None:reference=core.copy()
    else:core_changes.append(float(np.mean(np.any(np.abs(core-reference)>.005,axis=2))))
    bpy.data.images.remove(image)
assert max(core_changes)>.1,"Surface contours must change across the core, not only at the tail"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(out/"connected_fireball.fbx"))
import_meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
import_rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
assert len(import_meshes)==1 and len(import_rigs)==1
assert len(import_rigs[0].data.bones)==73
assert import_rigs[0].animation_data and import_rigs[0].animation_data.action
report={"passed":True,"scope":"Blender and exported files only; Studio playback unverified",
    "connected_components":components,"closed_volume_after_uv_seam_weld":True,
    "mesh_count":1,"deform_bones":72,"maximum_skin_influences":maximum,
    "loop_max_vertex_error":loop_error,"quarter_cycle_max_vertex_motion":motion,
    "rgba_surface_frames":24,"leading_body_opaque_all_frames":True,"rear_erosion_all_frames":True,
    "maximum_core_pixels_changed_vs_first_frame":max(core_changes),"uv_seam_matches_all_frames":True,
    "fbx_meshes":1,"fbx_bones":73,"fbx_animation_present":True}
(out/"validation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report))
