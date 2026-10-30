"""Blender: combine existing restyled meshes into one vertex-colored import file."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/vfx/studies/style_unification_v1'
catalog = json.loads((OUT / 'catalog.json').read_text(encoding='utf-8'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
counts = {}
for row in catalog['assets']:
    if row['kind'] != 'mesh':
        continue
    # Packet uses original geometry and approved face bands, in Roblox Y-up space.
    packets = json.loads((OUT / row['packet']).read_text(encoding='utf-8'))
    positions, triangles, bands = [], [], []
    for packet in packets:
        offset = len(positions)
        positions.extend((p[0], -p[2], p[1]) for p in packet['positions'])
        indices = packet['indices']
        triangles.extend(tuple(offset + j for j in indices[i:i+3]) for i in range(0, len(indices), 3))
        bands.extend(packet['bands'])
    mesh = bpy.data.meshes.new(row['name'])
    mesh.from_pydata(positions, [], triangles)
    mesh.update()
    obj = bpy.data.objects.new(row['name'], mesh)
    bpy.context.collection.objects.link(obj)
    colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    palette = catalog['profile']['palettes'][row['identity']]
    for face, band in zip(mesh.polygons, bands):
        rgb = [v / 255 for v in palette[band]]
        linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
        for loop in face.loop_indices:
            colors.data[loop].color = (*linear, 1)
    # Restore original UVs and normals through original GLB accessors.
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from restyle_existing_assets import read_glb, accessor
    source, binary = read_glb(OUT / row['source'])
    prim = source['meshes'][0]['primitives'][0]
    uvs = accessor(source, binary, prim['attributes']['TEXCOORD_0'])
    uv_layer = mesh.uv_layers.new(name='UVMap')
    for loop in mesh.loops:
        uv_layer.data[loop.index].uv = uvs[loop.vertex_index]
    normals = accessor(source, binary, prim['attributes']['NORMAL'])
    mesh.normals_split_custom_set_from_vertices([(n[0], -n[2], n[1]) for n in normals])
    counts[row['name']] = len(triangles)
    assert len(triangles) == row['triangles']
bpy.ops.object.select_all(action='SELECT')
destination = OUT / 'baked/Enfleshed_Cel_Existing_Meshes.fbx'
bpy.ops.export_scene.fbx(filepath=str(destination), use_selection=True, object_types={'MESH'},
    apply_unit_scale=True, bake_space_transform=True, axis_forward='-Z', axis_up='Y',
    use_mesh_modifiers=False, mesh_smooth_type='OFF', colors_type='SRGB', bake_anim=False)
(OUT / 'baked/mesh_import_counts.json').write_text(json.dumps(counts, indent=2)+'\n', encoding='utf-8')
print(f'Exported {len(counts)} existing meshes with baked face colors to {destination}')
