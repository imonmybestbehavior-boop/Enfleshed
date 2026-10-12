"""Blender mesh/export helpers for the Lower Layer circulation kit.
Uses the approved frontage atlas without modifying the frontage library.
"""
import json
import math
import shutil
from pathlib import Path

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
FRONTAGE=ROOT/'assets/blender/generated/lower_layer_frontage_kit_v1'
ASSETS=[]
CURRENT=None


def initialize(out):
    global OUT,PALETTE,MATS,ATLAS,LIB,REVIEW
    OUT=out
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'exports').mkdir(exist_ok=True)
    (OUT/'textures').mkdir(exist_ok=True)
    source=json.loads((FRONTAGE/'manifest.json').read_text())
    PALETTE=source['materials']
    MATS={}
    for name,p in PALETTE.items():
        material=bpy.data.materials.new('LL_'+name)
        material.diffuse_color=(*p['base_color'],1)
        MATS[name]=material
    images={}
    for channel in ['color','roughness','metalness','normal']:
        path=OUT/'textures'/f'frontage_atlas_{channel}.png'
        shutil.copy2(FRONTAGE/'textures'/path.name,path)
        image=bpy.data.images.load(str(path))
        image.colorspace_settings.name='sRGB' if channel=='color' else 'Non-Color'
        image.pack();images[channel]=image
    ATLAS=bpy.data.materials.new('LL_Circulation_Shared_PBR')
    ATLAS.use_nodes=True
    nodes=ATLAS.node_tree.nodes;links=ATLAS.node_tree.links
    shader=nodes.get('Principled BSDF')
    for channel,slot in [('color','Base Color'),('roughness','Roughness'),('metalness','Metallic')]:
        tex=nodes.new('ShaderNodeTexImage');tex.image=images[channel]
        links.new(tex.outputs['Color'],shader.inputs[slot])
    tex=nodes.new('ShaderNodeTexImage');tex.image=images['normal']
    normal=nodes.new('ShaderNodeNormalMap')
    links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs['Normal'])
    LIB=bpy.data.collections.new('LOWER_LAYER_CIRCULATION_V1');bpy.context.scene.collection.children.link(LIB)
    REVIEW=bpy.data.collections.new('00_REVIEW_ONLY');bpy.context.scene.collection.children.link(REVIEW)


def asset(name,width,depth,kind,use):
    global CURRENT
    collection=bpy.data.collections.new(name);LIB.children.link(collection)
    root=bpy.data.objects.new(name+'_ROOT',None);collection.objects.link(root)
    root['AssetId']=name;root['Units']='stud';root['Origin']='front centre finished floor; X right, Y inward, Z up'
    CURRENT={'name':name,'width':width,'depth':depth,'kind':kind,'use':use,'collection':collection,'root':root,
             'objects':[],'colliders':[],'ports':[],'routes':[],'samples':[],'roof_objects':[]}
    ASSETS.append(CURRENT)
    return CURRENT


def collider(name,center,size,role='wall'):
    CURRENT['colliders'].append({'name':name,'center':list(center),'size':list(size),'role':role})


def register(ob,name,material,section='shell'):
    ob.name=CURRENT['name']+'__'+name
    for c in list(ob.users_collection):c.objects.unlink(ob)
    CURRENT['collection'].objects.link(ob);ob.parent=CURRENT['root']
    ob.data.materials.append(MATS[material]);ob['Section']=section;ob['Role']='visual'
    CURRENT['objects'].append(ob)
    return ob


def box(name,center,size,material='Plaster',solid=True,role='wall',section='shell',bevel=.025):
    assert min(size)>0,(name,size)
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    ob=register(bpy.context.object,name,material,section);ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Edge','BEVEL');mod.width=min(bevel,min(size)*.15);mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if solid:collider(name,center,size,role)
    return ob


def rod(name,start,end,radius=.065,material='Iron'):
    a,b=Vector(start),Vector(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=radius,depth=(b-a).length,location=(a+b)/2)
    ob=register(bpy.context.object,name,material);ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return ob


def socket(name,position,normal,width=8,height=12,walkable=True):
    port={'name':name,'position':list(position),'normal':list(normal),'width':width,'height':height,'walkable':walkable}
    CURRENT['ports'].append(port)
    ob=bpy.data.objects.new(CURRENT['name']+'__PORT_'+name,None)
    CURRENT['collection'].objects.link(ob);ob.parent=CURRENT['root'];ob.location=position
    ob.empty_display_type='ARROWS';ob.empty_display_size=.8;ob['Role']='socket';ob['ClearWidth']=width
    # A slight lowered support lip avoids invisible gaps without z-fighting.
    if walkable:
        x,y,z=position;nx,ny,_=normal
        collider('ConnectionSupport_'+name,(x,y,z-.22),(.4 if nx else width,width if nx else .4,.4),'floor')
    return port


def route(name,points):
    CURRENT['routes'].append({'name':name,'points':[list(p) for p in points]})
    for a,b in zip(points,points[1:]):
        assert a[2]==b[2],'Use explicit tread samples for stairs'
        steps=max(1,math.ceil(math.dist(a,b)/.75))
        for i in range(steps+1):
            CURRENT['samples'].append({'route':name,'position':[a[k]+(b[k]-a[k])*i/steps for k in range(3)]})


def atlas_uv(ob):
    mesh=ob.data
    packed=mesh.uv_layers.new(name='UV1_Packed')
    for dst,src in zip(packed.data,mesh.uv_layers['UV0'].data):dst.uv=src.uv
    uv=mesh.uv_layers['UV0'];palette=list(PALETTE)
    for face in mesh.polygons:
        index=palette.index(mesh.materials[face.material_index].name.removeprefix('LL_'))
        col,row=index%4,index//4
        axis=max(range(3),key=lambda k:abs(face.normal[k]));axes=[k for k in range(3) if k!=axis]
        points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
        lo=[min(p[k] for p in points) for k in axes];hi=[max(p[k] for p in points) for k in axes]
        for loop,p in zip(face.loop_indices,points):
            q=[(p[k]-lo[j])/max(.00001,hi[j]-lo[j]) for j,k in enumerate(axes)]
            uv.data[loop].uv=((col+.04+.92*q[0])/4,(row+.04+.92*q[1])/4)
        face.material_index=0
    mesh.materials.clear();mesh.materials.append(ATLAS)
    mesh.uv_layers.active_index=0;mesh.uv_layers['UV0'].active_render=True


def finish_assets():
    catalogue='VERSION 1\n6130450a-ce34-4c21-ae12-accc231c1001:Lower Layer/Circulation:Circulation\n'
    (OUT/'blender_assets.cats.txt').write_text(catalogue)
    records=[]
    for a in ASSETS:
        visual=[];triangles=0
        sections={section:[ob for ob in a['objects'] if ob['Section']==section] for section in ['shell','roof']}
        for section in ['shell','roof']:
            objects=sections[section]
            if not objects:continue
            bpy.ops.object.select_all(action='DESELECT')
            for ob in objects:ob.select_set(True)
            bpy.context.view_layer.objects.active=objects[0]
            if len(objects)>1:bpy.ops.object.join()
            ob=bpy.context.object;ob.name=a['name']+'__VIS_'+section
            bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
            bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.normals_make_consistent(inside=False)
            bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015)
            bpy.ops.object.mode_set(mode='OBJECT');ob.data.uv_layers.active.name='UV0';atlas_uv(ob)
            ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
            ob['Role']='visual';ob['RecommendedCanCollide']=False;visual.append(ob)
            if section=='roof':a['roof_objects'].append(ob)
        assert triangles<12000,(a['name'],triangles)
        corners=[ob.matrix_local@Vector(c) for ob in visual for c in ob.bound_box]
        a['triangles']=triangles;a['visuals']=visual
        a['bounds']={'min':[min(c[k] for c in corners) for k in range(3)],'max':[max(c[k] for c in corners) for k in range(3)]}
        cols=[]
        for i,c in enumerate(a['colliders']):
            bpy.ops.mesh.primitive_cube_add(size=1,location=c['center']);ob=bpy.context.object
            for coll in list(ob.users_collection):coll.objects.unlink(ob)
            a['collection'].objects.link(ob);ob.parent=a['root'];ob.name=a['name']+'__COL_%03d'%i
            ob.dimensions=c['size'];bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
            ob['Role']='collision';ob.display_type='WIRE';ob.hide_render=True;cols.append(ob)
        for suffix,objects in [('visual',visual+[a['root']]),('collision',cols)]:
            bpy.ops.object.select_all(action='DESELECT')
            for ob in objects:ob.hide_set(False);ob.select_set(True)
            bpy.context.view_layer.objects.active=objects[0]
            path=OUT/'exports'/f"{a['name']}_{suffix}"
            bpy.ops.export_scene.gltf(filepath=str(path.with_suffix('.glb')),export_format='GLB',use_selection=True,export_extras=True,export_yup=True)
            bpy.ops.export_scene.fbx(filepath=str(path.with_suffix('.fbx')),use_selection=True,object_types={'MESH','EMPTY'},apply_unit_scale=False,
                                     axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,use_custom_props=True,path_mode='COPY',embed_textures=True)
        for ob in cols:ob.hide_set(True)
        a['collection'].asset_mark();meta=a['collection'].asset_data
        meta.catalog_id='6130450a-ce34-4c21-ae12-accc231c1001';meta.author='Enfleshed';meta.description=a['use']
        for tag in ['Lower Layer','circulation',a['kind']]:meta.tags.new(tag)
        records.append({k:v for k,v in a.items() if k in ['name','width','depth','kind','use','ports','routes','samples','colliders','triangles','bounds','rise','tread','clearance','compatibility']})
    return records
