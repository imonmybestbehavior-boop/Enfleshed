"""Read the approved Blender source without saving it; export evaluated review geometry.
Blender --background --python FILE -- ROOT
"""
import array
import hashlib
import json
from pathlib import Path
import sys
import bpy

root=Path(sys.argv[sys.argv.index('--')+1])
source=root/'assets/vfx/studies/3d_fire_v4/connected_fireball.blend'
before=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
obj=bpy.data.objects['ConnectedFireVolume']
scene.frame_set(1)
deps=bpy.context.evaluated_depsgraph_get()
mesh=obj.evaluated_get(deps).to_mesh()
mesh.calc_loop_triangles()
indices=[v for tri in mesh.loop_triangles for v in tri.vertices]
uv=[[0,0] for _ in mesh.vertices]
for loop in mesh.loops: uv[loop.vertex_index]=list(mesh.uv_layers.active.data[loop.index].uv)
ys=[v.co.z for v in mesh.vertices]
factor=2.2/(max(ys)-min(ys))
count=len(mesh.vertices)
obj.evaluated_get(deps).to_mesh_clear()
positions=array.array('f')
for frame in range(1,49):
    scene.frame_set(frame)
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    assert len(mesh.vertices)==count
    for vertex in mesh.vertices:
        x,y,z=vertex.co
        positions.extend(((x+.7)*factor,z*factor+3,-y*factor))
    evaluated.to_mesh_clear()
out=root/'assets/vfx/studies/effect_families_v1'
out.mkdir(parents=True,exist_ok=True)
if sys.byteorder!='little': positions.byteswap()
(out/'fire.positions.bin').write_bytes(positions.tobytes())
record=dict(vertices=count,frames=48,fps=24,indices=indices,uv=uv,source_sha256=before,
    textures=[f'../3d_fire_v4/flow_textures/flow_{i:03d}.png' for i in range(1,25)],
    scale='2.2 stud body width; lifted 3 studs above the review floor',scope='Evaluated source skin; browser review, not a new Studio import')
(out/'fire.mesh.json').write_text(json.dumps(record,separators=(',',':')))
assert hashlib.sha256(source.read_bytes()).hexdigest()==before
print(f'Exported approved source: {count} vertices, {len(indices)//3} triangles, 48 frames; original unchanged')
