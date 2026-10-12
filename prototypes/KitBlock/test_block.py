"""Static traversal, built-place and isolation checks; not a Studio physics test."""
import collections
import hashlib
import json
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
data = json.loads((HERE / 'assembly.json').read_text())
pack = json.loads((ROOT / 'assets/blender/generated/lower_layer_circulation_kit_v1/manifest.json').read_text())
habitation = json.loads((ROOT / 'assets/blender/generated/lower_layer_habitation_kit_v1/manifest.json').read_text())
assets = {a['name']: a for a in pack['assets'] + habitation['assets']}
solids = []
for p in data['parts']:
    if p['collision']:
        solids.append((p['name'], [c - s / 2 for c, s in zip(p['center'], p['size'])], [c + s / 2 for c, s in zip(p['center'], p['size'])]))
errors = []


def probe(point, radius=2, height=9.5):
    x, y, z = point
    candidates = [b for b in solids if b[1][0] < x + radius and b[2][0] > x - radius and b[1][1] < y + radius and b[2][1] > y - radius]
    support = any(lo[0] - .01 <= x <= hi[0] + .01 and lo[1] - .01 <= y <= hi[1] + .01 and abs(hi[2] - z) < .09 for _, lo, hi in candidates)
    blockers = [name for name, lo, hi in candidates if lo[2] < z + height and hi[2] > z + 1.6]
    return support and not blockers, blockers if blockers else ([] if support else ['unsupported'])


def world(p, point):
    c, s = round(math.cos(math.radians(p['angle']))), round(math.sin(math.radians(p['angle'])))
    x, y, z = point
    return [c * x - s * y + p['origin'][0], s * x + c * y + p['origin'][1], z + p['origin'][2]]


sample_count = 0
for p in data['placements']:
    if p['asset'] not in assets:
        continue
    a = assets[p['asset']]
    capped = {c['port'][1] for c in data['caps'] if c['port'][0] == p['id']}
    cap_points = [port['position'] for port in a['ports'] if port['name'] in capped]
    for sample in a['samples']:
        if any(math.dist(sample['position'], cap) < 2.6 for cap in cap_points):
            continue
        point = world(p, sample['position'])
        ok, blockers = probe(point)
        if not ok:
            errors.append([p['id'], point, blockers])
        sample_count += 1

# Broad-phase rasterize ground clearance once; flood-fill real supported space.
walkable = set()
for x in range(-70, 100):
    for y in range(-30, 116):
        if probe((x, y, 0))[0]:
            walkable.add((x, y))
start = tuple(data['spawn'][:2])
assert start in walkable, 'Spawn must have supported, unobstructed ground'
reached = {start}; todo = collections.deque([start])
while todo:
    x, y = todo.popleft()
    for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        if p in walkable and p not in reached:
            reached.add(p); todo.append(p)
for p in data['ground_checkpoints'] + data['enemy_spawns']:
    if (round(p[0]), round(p[1])) not in reached:
        errors.append(['unreachable checkpoint', p, probe(p)[1]])
baseline = json.loads((HERE / 'ground_baseline.json').read_text())
lost_cells = set(map(tuple, baseline['ground_cells'])) - reached
if lost_cells:
    errors.append(['ground regression', sorted(lost_cells)])
for name, digest in baseline['runtime_hashes'].items():
    assert hashlib.sha256((HERE / name).read_bytes()).hexdigest() == digest, 'Unexpected gameplay edit: ' + name
# New street-to-stair portal must be traversable, not merely drawn on the wall.
for x in range(7, 15):
    ok, blockers = probe((x, 102, 0))
    if not ok:
        errors.append(['rear lane return portal', x, blockers])
# Every declared kit-to-kit connection is checked at and either side of its seam.
placements = {p['id']: p for p in data['placements']}
seams = 0
for connection in data['connections']:
    endpoint_points, normals = [], []
    for reference in connection.values():
        placed = placements[reference[0]]
        definition = assets.get(placed['asset']) or pack['frontage_sources'][placed['asset']]
        endpoint = next(p for p in definition['ports'] if p['name'] == reference[1])
        endpoint_points.append(world(placed, endpoint['position']))
        zero = world(placed, (0, 0, 0)); n = world(placed, endpoint['normal'])
        normals.append([n[i] - zero[i] for i in range(3)])
    assert math.dist(*endpoint_points) < .001, connection
    assert normals[0] == [-v for v in normals[1]], connection
    side = next((v for v in connection.values() if placements[v[0]]['asset'] in assets), None)
    p = placements[side[0]]
    port = next(port for port in assets[p['asset']]['ports'] if port['name'] == side[1])
    for t in (-.6, 0, .6):
        local = [v + n * t for v, n in zip(port['position'], port['normal'])]
        point = world(p, local)
        ok, blockers = probe(point)
        if not ok:
            errors.append(['blocked seam', connection, point, blockers])
        seams += 1

# Prove the upper room has an independent way back to the ground network.
# Remove the original stair from the graph: the new return must still connect.
graph = collections.defaultdict(set)
for connection in data['connections']:
    a, b = connection['a'][0], connection['b'][0]
    if 'first_flight' in (a, b):
        continue
    graph[a].add(b); graph[b].add(a)
for entrance in ('street_passage', 'residential_exit', 'rear_lane_link'):
    graph['ground'].add(entrance); graph[entrance].add('ground')
seen = {'ground'}; pending = ['ground']
while pending:
    for node in graph[pending.pop()] - seen:
        seen.add(node); pending.append(node)
assert 'upper_room' in seen, 'Upper return still depends on the original stairs'
place = ET.parse(ROOT / 'Enfleshed_KitBlock.rbxlx').getroot()
items = list(place.iter('Item'))
spawns = [i for i in items if i.get('class') == 'SpawnLocation']
assert len(spawns) == 1, 'Exactly one test spawn'
assert len([i for i in items if i.get('class') == 'Part']) == data['part_count']
server = next(i for i in items if i.get('class') == 'Script' and i.findtext('./Properties/string[@name="Name"]') == 'Server')
source = server.findtext('./Properties/*[@name="Source"]')
assert 'Sandbox.start' not in source and 'LivingCity' not in source and 'ActionRouter' in source
opening = next(i for i in items if i.get('class') == 'ModuleScript' and i.findtext('./Properties/string[@name="Name"]') == 'OpeningService')
assert 'KitBlock/review.project.json' in opening.findtext('./Properties/*[@name="Source"]')
def child(node, name):
    return next(i for i in node.findall('Item') if i.findtext("Properties/string[@name='Name']") == name)

parents = {item: parent for parent in place.iter() for item in parent}
shared = child(child(place, 'ReplicatedStorage'), 'Shared')
reference_count = 0
for script in items:
    source = script.findtext("Properties/*[@name='Source']") or ''
    for reference in re.findall(r'require\((script(?:\.[A-Za-z_]\w*)+)\)', source):
        node = script
        for name in reference.split('.')[1:]:
            node = parents[node] if name == 'Parent' else child(node, name)
        assert node.get('class') == 'ModuleScript', reference
        reference_count += 1
    for reference in re.findall(r'Shared((?::WaitForChild\("[^\"]+"\))+)', source):
        node = shared
        for name in re.findall(r':WaitForChild\("([^\"]+)"\)', reference):
            node = child(node, name)
        assert node.get('class') == 'ModuleScript'
        reference_count += 1
assert reference_count > 0
from surface_cleanup import conflicts
built_surfaces = []
for item in items:
    if item.get('class') != 'Part':
        continue
    props = item.find('Properties')
    if float(props.findtext("float[@name='Transparency']", '0')) >= 1:
        continue
    cf = props.find("CoordinateFrame[@name='CFrame']")
    size = props.find("Vector3[@name='size']")
    built_surfaces.append({'name': props.findtext("string[@name='Name']"), 'visible': True,
        'center': [float(cf.findtext('X')), -float(cf.findtext('Z')), float(cf.findtext('Y'))],
        'size': [float(size.findtext('X')), float(size.findtext('Z')), float(size.findtext('Y'))]})
assert not list(conflicts(built_surfaces)), 'Coplanar visual overlap in compiled place'
report = {'passed': not errors, 'parts': data['part_count'], 'frontages': 6, 'kit_route_samples': sample_count, 'connection_samples': seams, 'ground_cells_reachable': len(reached), 'checkpoint_count': len(data['ground_checkpoints']), 'errors': errors,
          'baseline_ground_cells_preserved': len(baseline['ground_cells']) - len(lost_cells), 'independent_upper_return': True, 'habitation_assets': len(habitation['assets']), 'compiled_coplanar_overlaps': 0, 'static_module_references': reference_count, 'studio_verified': False}
(HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
assert not errors, 'Static route validation failed'
