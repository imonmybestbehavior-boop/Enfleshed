"""Render the actual native-Part geometry for review; no source kit changes."""
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector
HERE = Path(__file__).resolve().parent
assembly = json.loads((HERE / 'assembly.json').read_text())
components = json.loads((HERE.parent / 'KitBlock/components.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
mats = {}
for key, value in components['materials'].items():
    material = bpy.data.materials.new(key); material.diffuse_color = (*value['base_color'], 1)
    material.use_nodes = True
    node = material.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = material.diffuse_color
    node.inputs['Roughness'].default_value = .85
    mats[key] = material
# XML keeps the actual Roblox material colours used by the assembly.
import xml.etree.ElementTree as ET
xml = ET.parse(HERE / 'District.rbxmx')
color_by_name = {}
for item in xml.iter('Item'):
    if item.get('class') == 'Part':
        props = item.find('Properties')
        name = props.findtext("string[@name='Name']")
        color = props.find("Color3[@name='Color']")
        color_by_name[name] = tuple(float(color.findtext(k)) for k in ('R','G','B'))
for p in assembly['parts']:
    if not p['visible']:
        continue
    center, size = p['center'], p['size']
    vertices = [(center[0]+x*size[0]/2,center[1]+y*size[1]/2,center[2]+z*size[2]/2) for x,y,z in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
    faces = [(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
    mesh = bpy.data.meshes.new(p['name']); mesh.from_pydata(vertices, [], faces); mesh.update()
    ob = bpy.data.objects.new(p['name'], mesh); bpy.context.collection.objects.link(ob)
    color = color_by_name[p['name']]
    material = min(mats.values(), key=lambda m: sum((m.diffuse_color[i]-color[i])**2 for i in range(3)))
    ob.data.materials.append(material)
    if 'Lamp' in p['name']:
        light = bpy.data.lights.new('Warm practical', 'POINT'); light.energy=1400;light.color=(1,.78,.52);light.shadow_soft_size=1
        source=bpy.data.objects.new('Warm practical',light);bpy.context.collection.objects.link(source);source.location=Vector(center)-Vector((0,0,.4))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=650;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Underground');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.17,.2,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.2
camera_data=bpy.data.cameras.new('StreetEye');camera=bpy.data.objects.new('StreetEye',camera_data);bpy.context.collection.objects.link(camera)
for name, position, target in [('service_preview', (-17,305,6), (-29,300,9)), ('upper_preview', (-9,96,24), (-9,125,24))]:
    if "--upper-only" in sys.argv and name != "upper_preview":
        continue
    camera.location=position
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.lens=22
    scene.camera=camera;scene.render.filepath=str(HERE/(name+'.png'))
    bpy.ops.render.render(write_still=True)
