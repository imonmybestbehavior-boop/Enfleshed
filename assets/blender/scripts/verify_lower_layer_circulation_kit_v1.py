"""Reopen the library and validate geometry, navigation samples and export roundtrip."""
import hashlib
import json
import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'generated/lower_layer_circulation_kit_v1'
manifest = json.loads((OUT / 'manifest.json').read_text())
assets = {a['name']: a for a in manifest['assets']}
all_assets = {**assets, **manifest['frontage_sources']}
assembly = manifest['assembly']
placements = {p['id']: p for p in assembly['placements']}
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


def rotate(p, angle):
    c, s = round(math.cos(math.radians(angle))), round(math.sin(math.radians(angle)))
    return [c * p[0] - s * p[1], s * p[0] + c * p[1], p[2]]


def world(p, point):
    return [a + b for a, b in zip(rotate(point, p['angle']), p['origin'])]


def boxes(p):
    result = []
    for c in all_assets[p['asset']]['colliders']:
        size = c['size'][:]
        if p['angle'] % 180:
            size[0], size[1] = size[1], size[0]
        center = world(p, c['center'])
        result.append({'name': p['id'] + '/' + c['name'], 'lo': [v - s / 2 for v, s in zip(center, size)], 'hi': [v + s / 2 for v, s in zip(center, size)]})
    return result


def port(p, name):
    local = next(x for x in all_assets[p['asset']]['ports'] if x['name'] == name)
    return {**local, 'position': world(p, local['position']), 'normal': rotate(local['normal'], p['angle'])}


def navigation_sample(position, colliders, label, radius=1.9):
    x, y, z = position
    supported = any(c['lo'][0] - .01 <= x <= c['hi'][0] + .01 and c['lo'][1] - .01 <= y <= c['hi'][1] + .01 and abs(c['hi'][2] - z) <= .08 for c in colliders)
    check(supported, label + ' unsupported ' + str(position))
    for c in colliders:
        # Step allowance is explicit: not a substitute for a live Humanoid test.
        intersects = c['lo'][0] < x + radius - .01 and c['hi'][0] > x - radius + .01 and c['lo'][1] < y + radius - .01 and c['hi'][1] > y - radius + .01 and c['lo'][2] < z + 9.5 and c['hi'][2] > z + 1.6
        check(not intersects, label + ' obstructed by ' + c['name'] + ' at ' + str(position))


local_samples = 0
for a in assets.values():
    p = {'id': a['name'], 'asset': a['name'], 'origin': [0, 0, 0], 'angle': 0}
    for s in a['samples']:
        navigation_sample(s['position'], boxes(p), a['name'])
        local_samples += 1
    check(a['width'] in (12, 16, 24), a['name'] + ' nonstandard width')
    check(a['triangles'] < 12000, a['name'] + ' triangle budget')
    for c in a['colliders']:
        check(min(c['size']) > 0, a['name'] + ' invalid collider')

world_boxes = [c for p in placements.values() for c in boxes(p)]
assembled_samples = 0
for p in placements.values():
    a = all_assets[p['asset']]
    closed_ports = [port(p, c['port'][1])['position'] for c in assembly['caps'] if c['port'][0] == p['id']]
    for s in a.get('samples', []):
        point = world(p, s['position'])
        if any(math.dist(point, endpoint) < 2.6 for endpoint in closed_ports):
            continue  # Deliberately closed exits are no longer part of the sample route.
        navigation_sample(point, world_boxes, p['id'])
        assembled_samples += 1
seam_samples = 0
for connection in assembly['connections']:
    pa, pb = [port(placements[v[0]], v[1]) for v in connection.values()]
    check(math.dist(pa['position'], pb['position']) < .001, 'Disconnected ports ' + str(connection))
    check(pa['normal'] == [-v for v in pb['normal']], 'Mismatched port normals')
    check(pa['width'] == pb['width'], 'Mismatched port widths')
    for distance in (-.75, -.25, 0, .25, .75):
        for lateral in (-(pa['width'] / 2 - 1.95), 0, pa['width'] / 2 - 1.95):
            n = pa['normal']
            point = [pa['position'][0] + n[0] * distance - n[1] * lateral, pa['position'][1] + n[1] * distance + n[0] * lateral, pa['position'][2]]
            navigation_sample(point, world_boxes, 'seam ' + str(connection))
            seam_samples += 1
# Check approved frontage dimensions rather than trusting hard-coded adapter claims.
for name, a in manifest['frontage_sources'].items():
    candidates = [s for s in a['sockets'] if s.get('name') == 'INTERIOR_CONNECTION']
    if candidates:
        check(math.dist(candidates[0]['position'], a['ports'][0]['position']) < .001, name + ' frontage socket drift')

bpy.ops.wm.open_mainfile(filepath=str(OUT / 'lower_layer_circulation_kit_v1.blend'))
visual_meshes = 0
for name, a in assets.items():
    collection = bpy.data.collections.get(name)
    check(collection is not None and collection.asset_data is not None, name + ' missing asset library entry')
    for ob in collection.objects:
        if ob.type != 'MESH' or ob.get('Role') != 'visual':
            continue
        visual_meshes += 1
        mesh = bmesh.new(); mesh.from_mesh(ob.data)
        check(all(edge.is_manifold for edge in mesh.edges), ob.name + ' nonmanifold component')
        check(mesh.calc_volume(signed=True) > 0, ob.name + ' invalid signed volume')
        mesh.free()
        check('UV0' in ob.data.uv_layers and 'UV1_Packed' in ob.data.uv_layers, ob.name + ' missing UV layers')
        check(all(math.isfinite(v) for vertex in ob.data.vertices for v in vertex.co), ob.name + ' nonfinite vertex')
        check(all(face.area > 1e-10 for face in ob.data.polygons), ob.name + ' zero-area face')
        check(len(ob.data.materials) == 1, ob.name + ' material count')

hashes = json.loads((OUT / 'export_hashes.json').read_text())
check(len(hashes) == 68, 'Expected 68 exports')
for name, digest in hashes.items():
    path = OUT / 'exports' / name
    check(path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == digest, name + ' export hash mismatch')
# Actual glTF reimport of every visual export; verify authored dimensions survive export.
for name, a in assets.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT / 'exports' / (name + '_visual.glb')))
    imported = set(bpy.data.objects) - before
    corners = [ob.matrix_world @ Vector(c) for ob in imported if ob.type == 'MESH' for c in ob.bound_box]
    for k in range(3):
        check(abs(min(c[k] for c in corners) - a['bounds']['min'][k]) < .005, name + ' roundtrip minimum')
        check(abs(max(c[k] for c in corners) - a['bounds']['max'][k]) < .005, name + ' roundtrip maximum')
    for ob in imported:
        bpy.data.objects.remove(ob, do_unlink=True)
report = {'passed': not errors, 'assets': len(assets), 'visual_meshes': visual_meshes, 'exports': len(hashes), 'triangles': sum(a['triangles'] for a in assets.values()), 'local_route_samples': local_samples, 'assembled_route_samples': assembled_samples, 'connection_samples': seam_samples, 'errors': errors, 'limitations': ['Static box-envelope checks do not replace Roblox Humanoid stair testing.', 'FBX files checked for hashes/existence; GLB files reimported and bounds checked.', 'Studio scale, collision setup and streaming remain manual validation.']}
(OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
assert not errors, str(len(errors)) + ' circulation checks failed'
