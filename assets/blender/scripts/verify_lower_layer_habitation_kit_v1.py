"""Reopen habitation library, check portals, meshes, and every GLB roundtrip."""
import hashlib
import json
import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'generated/lower_layer_habitation_kit_v1'
manifest = json.loads((OUT / 'manifest.json').read_text())
hashes = json.loads((OUT / 'export_hashes.json').read_text())
assert len(manifest['assets']) == 9 and len(hashes) == 36
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'lower_layer_habitation_kit_v1.blend'))
route_samples = 0
for asset in manifest['assets']:
    collection = bpy.data.collections[asset['name']]
    assert collection.asset_data and collection.asset_data.catalog_id == 'a3e2c5c0-6b31-48db-a09a-928cae612901'
    assert asset['triangles'] < 12000
    for ob in collection.objects:
        if ob.type != 'MESH' or ob.get('Role') != 'visual':
            continue
        assert len(ob.data.materials) == 1
        assert 'UV0' in ob.data.uv_layers and 'UV1_Packed' in ob.data.uv_layers
        assert all(math.isfinite(c) for v in ob.data.vertices for c in v.co)
        mesh = bmesh.new(); mesh.from_mesh(ob.data)
        assert all(edge.is_manifold for edge in mesh.edges), ob.name
        assert mesh.calc_volume(signed=True) > 0, ob.name
        mesh.free()
    for sample in asset['samples']:
        p = sample['position']
        support = False
        for collider in asset['colliders']:
            lo = [c - s / 2 for c, s in zip(collider['center'], collider['size'])]
            hi = [c + s / 2 for c, s in zip(collider['center'], collider['size'])]
            support |= all(lo[k] - .001 <= p[k] <= hi[k] + .001 for k in (0, 1)) and abs(hi[2] - p[2]) < .08
            blocked = all(lo[k] < p[k] + 2 and hi[k] > p[k] - 2 for k in (0, 1)) and lo[2] < p[2] + 9.5 and hi[2] > p[2] + 1.6
            assert not blocked, (asset['name'], sample, collider['name'])
        assert support, (asset['name'], sample)
        route_samples += 1
    for kind in ('visual', 'collision'):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT / 'exports' / (asset['name'] + '_' + kind + '.glb')))
        imported = set(bpy.data.objects) - before
        corners = [ob.matrix_world @ Vector(p) for ob in imported if ob.type == 'MESH' for p in ob.bound_box]
        if kind == 'visual':
            bounds = asset['bounds']
        else:
            bounds = {'min': [min(c['center'][k] - c['size'][k] / 2 for c in asset['colliders']) for k in range(3)],
                      'max': [max(c['center'][k] + c['size'][k] / 2 for c in asset['colliders']) for k in range(3)]}
        for k in range(3):
            assert abs(min(c[k] for c in corners) - bounds['min'][k]) < .005, asset['name']
            assert abs(max(c[k] for c in corners) - bounds['max'][k]) < .005, asset['name']
        for ob in imported:
            bpy.data.objects.remove(ob, do_unlink=True)
for name, expected in hashes.items():
    assert hashlib.sha256((OUT / 'exports' / name).read_bytes()).hexdigest() == expected, name
report = {'passed': True, 'assets': 9, 'exports': 36, 'glb_roundtrips': 18,
          'visual_triangles': sum(a['triangles'] for a in manifest['assets']), 'route_samples': route_samples,
          'studio_verified': False, 'fbx_checked': 'Existence and content hash only; GLB geometries reimported.'}
(OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
