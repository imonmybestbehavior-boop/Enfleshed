import bpy, json
from pathlib import Path
s=bpy.context.scene
shops=[c for c in bpy.data.collections if c.asset_data]
assert len(shops)==6,len(shops)
assert s.camera.name=='00 Overview'
assert len([o for o in s.objects if o.type=='CAMERA'])==7
assert all(o.dimensions.x>0 and o.dimensions.y>0 and o.dimensions.z>0 for o in s.objects if o.type=='MESH')
for c in shops:
    roots=[o for o in c.objects if o.type=='EMPTY'];assert len(roots)==1
    r=roots[0];assert all(o.parent==r for o in c.objects if o!=r)
    assert abs(c.instance_offset.x-r.location.x)<.001
    assert any('Threshold' in o.name for o in c.objects)
    assert any('Door' in o.name or 'workshop shutter' in o.name for o in c.objects)
assert any('Rear passage lintel' in o.name for o in s.objects)
result={'blender':bpy.app.version_string,'shop_collections':len(shops),'cameras':7,'meshes':sum(o.type=='MESH' for o in s.objects),'checks':['saved blend reopened','six marked collection assets','positive mesh dimensions','local collection origins and parenting','thresholds and door frames','rear passage opening','overview active'],'scope':'geometry and scene structure; no Roblox collision validation'}
Path(bpy.data.filepath).with_name('validation.json').write_text(json.dumps(result,indent=2))
print('VERIFIED',result)
