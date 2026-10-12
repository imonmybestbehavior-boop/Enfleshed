"""Extract native-Part review geometry from the approved Blender libraries.
Does not save either source blend. Bevels and baked textures are deliberately omitted.
"""
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PACKS = ROOT / 'assets/blender/generated'
frontage = json.loads((PACKS / 'lower_layer_frontage_kit_v1/manifest.json').read_text())
palette = list(frontage['materials'])
result = {'materials': frontage['materials'], 'assets': {}}
for pack in ('lower_layer_frontage_kit_v1', 'lower_layer_circulation_kit_v1', 'lower_layer_habitation_kit_v1'):
    directory = PACKS / pack
    manifest = json.loads((directory / 'manifest.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(directory / (pack + '.blend')))
    for a in manifest['assets']:
        if a['name'].startswith('D'):
            continue
        coll = bpy.data.collections.get(a['name'])
        if not coll:
            continue
        parts = []
        for ob in coll.objects:
            if ob.type != 'MESH' or ob.get('Role') != 'visual':
                continue
            mesh = ob.data
            adjacent = {v.index: set() for v in mesh.vertices}
            for e in mesh.edges:
                a0, b = e.vertices
                adjacent[a0].add(b); adjacent[b].add(a0)
            remaining = set(adjacent)
            while remaining:
                todo = [next(iter(remaining))]; component = set()
                while todo:
                    v = todo.pop()
                    if v in component:
                        continue
                    component.add(v); remaining.discard(v)
                    todo.extend(adjacent[v] - component)
                points = [ob.matrix_local @ mesh.vertices[v].co for v in component]
                lo = [min(v[k] for v in points) for k in range(3)]
                hi = [max(v[k] for v in points) for k in range(3)]
                face = next(f for f in mesh.polygons if f.vertices[0] in component)
                uv = mesh.uv_layers['UV0']
                u = sum(uv.data[i].uv.x for i in face.loop_indices) / len(face.loop_indices)
                v = sum(uv.data[i].uv.y for i in face.loop_indices) / len(face.loop_indices)
                material = palette[int(v * 4) * 4 + int(u * 4)]
                parts.append({'center': [(x + y) / 2 for x, y in zip(lo, hi)], 'size': [y - x for x, y in zip(lo, hi)], 'material': material})
        assert parts, a['name']
        for k in range(3):
            low = min(p['center'][k] - p['size'][k] / 2 for p in parts)
            high = max(p['center'][k] + p['size'][k] / 2 for p in parts)
            assert abs(low - a['bounds']['min'][k]) < .01, (a['name'], k, low)
            assert abs(high - a['bounds']['max'][k]) < .01, (a['name'], k, high)
        result['assets'][a['name']] = {'parts': parts, 'colliders': a['colliders']}
output = Path(__file__).with_name('components.json')
output.write_text(json.dumps(result, separators=(',', ':')) + '\n')
print('EXTRACTED', len(result['assets']), 'assets')
