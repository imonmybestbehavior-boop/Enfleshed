"""Reopen the generated blend in Blender, then execute this validation script.
Checks export structure, collisions, geometry and reproducible local pivots.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

out=Path(bpy.data.filepath).parent
manifest=json.loads((out/'manifest.json').read_text())
assert manifest['frontages']==12 and manifest['details']==21
assets=manifest['assets']
assert len({a['name'] for a in assets})==33
assert len([c for c in bpy.data.collections if c.asset_data])==33
assert bpy.context.scene.camera.name=='REVIEW_Frontages'
results=[]
for a in assets:
    collection=bpy.data.collections[a['name']]
    root=bpy.data.objects[a['name']+'_ROOT']
    visual=bpy.data.objects[a['name']+'__VIS']
    assert visual.parent==root
    assert (root.location-collection.instance_offset).length<1e-5
    assert visual.location.length<1e-5,(a['name'],'pivot')
    assert all(abs(v-1)<1e-5 for v in visual.scale)
    assert visual.data.uv_layers.active.name=='UV0'
    assert 'UV1_Packed' in visual.data.uv_layers
    assert len(visual.data.materials)==1
    assert all(-1e-5<=v<=1.00001 for uv in visual.data.uv_layers.active.data for v in uv.uv)
    bm=bmesh.new();bm.from_mesh(visual.data)
    assert all(e.is_manifold for e in bm.edges),(a['name'],'nonmanifold')
    assert all(f.calc_area()>1e-9 for f in bm.faces),(a['name'],'degenerate')
    assert all(math.isfinite(c) for v in bm.verts for c in v.co)
    assert bm.calc_volume(signed=True)>0
    bm.free()
    visual.data.calc_loop_triangles()
    assert len(visual.data.loop_triangles)==a['triangles']<=18000
    if a['kind']=='frontage':
        assert a['width'] in [12,16,24]
        assert a['bounds']['min'][0]>=-a['width']/2-.051,(a['name'],'left seam')
        assert a['bounds']['max'][0]<=a['width']/2+.051,(a['name'],'right seam')
        assert a['colliders']
        sockets={s['name']:s for s in a['sockets']}
        assert sockets['LEFT_SEAM']['position']==[-a['width']/2,0,0]
        assert sockets['RIGHT_SEAM']['position']==[a['width']/2,0,0]
        assert sockets['UPPER_STOREY']['position']==[0,0,18]
    for portal in a['openings']:
        l,r=portal['x']-portal['width']/2,portal['x']+portal['width']/2
        for c in a['colliders']:
            x,y,z=c['center'];w,d,h=c['size'];eps=.001
            obstruct=(x+w/2>l+eps and x-w/2<r-eps and y+d/2>portal['y0']+eps and y-d/2<portal['y1']-eps and z+h/2>.01 and z-h/2<portal['height']-eps)
            assert not obstruct,(a['name'],'blocked portal',c['name'])
    for suffix in ['visual']+(['collision'] if a['colliders'] else []):
        path=out/'exports'/f"{a['name']}_{suffix}.glb"
        data=path.read_bytes()
        magic,version,length=struct.unpack_from('<4sII',data)
        assert magic==b'glTF' and version==2 and length==len(data)
        size,kind=struct.unpack_from('<II',data,12)
        assert kind==0x4e4f534a
        gltf=json.loads(data[20:20+size])
        assert gltf.get('meshes'),a['name']
        assert not gltf.get('cameras') and not gltf.get('animations')
        assert all('uri' not in b for b in gltf['buffers'])
        for node in gltf.get('nodes',[]):
            assert not node.get('name','').startswith('REVIEW')
        if suffix=='visual':
            for mesh in gltf['meshes']:
                for primitive in mesh['primitives']:
                    assert 'TEXCOORD_0' in primitive['attributes']
            assert len(gltf['materials'])==1
            assert len(gltf.get('images',[]))>=3
            assert all('bufferView' in image for image in gltf['images'])
        assert (out/'exports'/f"{a['name']}_{suffix}.fbx").stat().st_size>1000
    results.append({'asset':a['name'],'triangles':a['triangles'],'colliders':len(a['colliders']),'portals':len(a['openings'])})
# The demonstration uses the same seam contract as manual/procedural placement.
widths={a['name']:a['width'] for a in assets}
assembly=bpy.data.collections['01_REVIEW_ASSEMBLY_INSTANCES']
for z in [0,18]:
    runs=sorted((ob.location.x-widths[ob.instance_collection.name]/2,ob.location.x+widths[ob.instance_collection.name]/2)
                for ob in assembly.objects if (ob.name.startswith('REVIEW_INSTANCE_') or ob.name.startswith('REVIEW_UPPER_')) and ob.location.z==z)
    assert runs and abs(runs[0][0]+44)<.001 and abs(runs[-1][1]-44)<.001
    assert all(abs(a[1]-b[0])<.001 for a,b in zip(runs,runs[1:])),('Assembly seam',z,runs)
# Import a real exported passage into this disposable validation session.
# Do not save: the library must retain its clean review layout.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(out/'exports/F08_ThroughPassage_visual.glb'))
imported=[ob for ob in bpy.data.objects if ob not in before and ob.type=='MESH']
assert len(imported)==1
bpy.context.view_layer.update()
corners=[ob.matrix_world@Vector(c) for ob in imported for c in ob.bound_box]
actual={'min':[min(c[k] for c in corners) for k in range(3)],'max':[max(c[k] for c in corners) for k in range(3)]}
expected=next(a['bounds'] for a in assets if a['name']=='F08_ThroughPassage')
assert all(abs(actual[side][i]-expected[side][i])<.001 for side in ['min','max'] for i in range(3)),(actual,expected)
report={'blender':bpy.app.version_string,'assets':results,'total_triangles':sum(a['triangles'] for a in assets),
        'max_asset_triangles':max(a['triangles'] for a in assets),'checks':['saved scene reopened','33 collection assets',
        'local pivots and transforms','atlas UV0 and packed UV1','embedded PBR textures and one visual material','closed manifold components','positive finite nondegenerate geometry',
        'frontage seam dimensions','collision portal clearances','self-contained GLB structure','FBX presence','GLB round-trip bounds and origin','snapped ground and upper review assembly seams'],
        'engine_test':'Not run: Studio import and live collision acceptance remain required.'}
(out/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
hashes={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((out/'exports').glob('*'))}
(out/'export_hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
print('KIT_VERIFIED',len(results),report['total_triangles'],report['max_asset_triangles'],flush=True)
