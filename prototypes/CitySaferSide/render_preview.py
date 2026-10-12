"""Offline preview of actual native Parts; grouped by material to keep rendering bounded."""
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
source=next((Path(a.split('=',1)[1]) for a in sys.argv if a.startswith('--source=')),HERE/'assembly.json')
D=json.loads(source.read_text())
C=json.loads((HERE.parent/'KitBlock/components.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
materials={};meshes={}
for name,m in C['materials'].items():
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*m['base_color'],1);mat.use_nodes=True
    node=mat.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=mat.diffuse_color;node.inputs['Roughness'].default_value=.85
    materials[name]=mat;meshes[name]=([],[])
faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
for p in D['parts']:
    if not p['visible']:continue
    vs,fs=meshes[p['material']];base=len(vs);c=p['center'];s=p['size']
    vs.extend((c[0]+x*s[0]/2,c[1]+z*s[1]/2,c[2]+y*s[2]/2) for x,z,y in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)])
    fs.extend(tuple(base+i for i in f) for f in faces)
    if 'Lamp_' in p['name']:
        lamp=bpy.data.lights.new(p['name'],'POINT');lamp.energy=1400;lamp.color=(1,.78,.52);lamp.shadow_soft_size=.6
        ob=bpy.data.objects.new(p['name'],lamp);bpy.context.collection.objects.link(ob);ob.location=(c[0],c[1],c[2]-.5)
for name,(vs,fs) in meshes.items():
    if not vs:continue
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.data.materials.append(materials[name])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Underground');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.17,.2,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.2
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));bpy.context.collection.objects.link(camera);scene.camera=camera;camera.data.lens=22
for name,eye,target in [('weave',(512,365,6),(518,342,8)),('weave_gallery',(728,232,42),(754,232,43)),('courtyard',(1020,208,7),(975,155,18)),('court_lane',(928,365,6),(928,329,8)),('opening',(1020,457,7),(1020,409,16)),('lane',(1048,464,6),(1080,469,8)),('upper',(1012,584,42),(1030,584,43))]:
    requested=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--view=')),None)
    if requested and name not in requested.split(','):continue
    camera.location=eye;camera.rotation_euler=(Vector(target)-Vector(eye)).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(HERE/(name+'_preview.png'));bpy.ops.render.render(write_still=True)
