"""Validate actual district collision, route coverage, isolation and compiled references."""
import collections
import hashlib
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REF = HERE.parent / 'KitBlock'
sys.path.insert(0, str(REF))
from surface_cleanup import conflicts

data = json.loads((HERE / 'assembly.json').read_text())
source = json.loads((REF / 'assembly.json').read_text())
assert hashlib.sha256((REF / 'Block.rbxmx').read_bytes()).hexdigest() == data['reference_sha256']
solids = []
buckets = collections.defaultdict(list)
for p in data['parts']:
    if not p['collision']:
        continue
    lo = [c - s / 2 for c, s in zip(p['center'], p['size'])]
    hi = [c + s / 2 for c, s in zip(p['center'], p['size'])]
    item = (p['name'], lo, hi)
    solids.append(item)
    for x in range(math.floor((lo[0] - 2) / 8), math.floor((hi[0] + 2) / 8) + 1):
        for y in range(math.floor((lo[1] - 2) / 8), math.floor((hi[1] + 2) / 8) + 1):
            buckets[x, y].append(item)


def probe(point):
    x, y, z = point
    nearby = [(n, lo, hi) for n, lo, hi in buckets[math.floor(x / 8), math.floor(y / 8)] if lo[0] < x + 2 - 1e-6 and hi[0] > x - 2 + 1e-6 and lo[1] < y + 2 - 1e-6 and hi[1] > y - 2 + 1e-6]
    support = any(lo[0] - .01 <= x <= hi[0] + .01 and lo[1] - .01 <= y <= hi[1] + .01 and abs(hi[2] - z) < .09 for _, lo, hi in nearby)
    blockers = [n for n, lo, hi in nearby if lo[2] < z + 9.5 and hi[2] > z + 1.6]
    return support and not blockers, blockers or ([] if support else ['unsupported'])


errors = []
for p in data['routes'] + data['checkpoints'] + data['enemy_spawns']:
    ok, why = probe(p)
    if not ok:
        errors.append([p, why])
# Converted apartment entries must be visibly open, not only non-collidable.
for p in data['parts']:
    if ('Commercial__upper_apartment_entry__VIS_' in p['name']
            or 'Residential__upper_apartment_entry__VIS_' in p['name']):
        local_y = p['center'][1] if 'Commercial__' in p['name'] else 264 - p['center'][1]
        assert not (86.9 < local_y < 87.5 and 18 < p['center'][2] < 29), 'Leftover false door'
cover_samples = 0
for x, y, z in data['routes']:
    inside = (110.5 < y < 153.5 or 280.5 < y < 333.5) if z == 0 else 88.5 < y < 175.5
    if not inside:
        continue
    covers = [p for p in data['parts'] if p['visible']
              and 12 <= p['center'][2] - p['size'][2]/2 - z <= 18.1
              and abs(x-p['center'][0]) <= p['size'][0]/2
              and abs(y-p['center'][1]) <= p['size'][1]/2]
    assert covers, ('Missing visible corridor top', x, y, z)
    cover_samples += 1
walkable = {(x, y) for x in range(-140, 105) for y in range(-28, 465) if probe((x, y, 0))[0]}
start = (-2, -8)
reached = {start}; todo = collections.deque([start])
while todo:
    x, y = todo.popleft()
    for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        if p in walkable and p not in reached:
            reached.add(p); todo.append(p)
for p in data['checkpoints'] + data['enemy_spawns']:
    if tuple(round(v) for v in p[:2]) not in reached:
        errors.append(['Unreachable', p])
# Every previously approved ground cell must remain accessible in every placed block.
baseline = json.loads((REF / 'ground_baseline.json').read_text())['ground_cells']
for label, offset, sign in data['blocks']:
    lost = [(x * sign + offset[0], y * sign + offset[1]) for x, y in baseline if (x * sign + offset[0], y * sign + offset[1]) not in reached]
    if lost:
        errors.append(['Lost reference cells', label, len(lost), [(p, probe((*p,0))[1]) for p in lost[:5]]])
# Recheck all original module routes at each transformed placement, including stairs.
packs = ROOT / 'assets/blender/generated'
assets = {}
for name in ('circulation', 'habitation'):
    assets.update({a['name']: a for a in json.loads((packs / ('lower_layer_' + name + '_kit_v1/manifest.json')).read_text())['assets']})
module_samples = 0
for label, offset, sign in data['blocks']:
    for p in source['placements']:
        if p['asset'] not in assets:
            continue
        angle = math.radians(p['angle']); c, s = round(math.cos(angle)), round(math.sin(angle))
        capped = {v['port'][1] for v in source['caps'] if v['port'][0] == p['id']}
        caps = [port['position'] for port in assets[p['asset']]['ports'] if port['name'] in capped]
        for sample in assets[p['asset']]['samples']:
            x, y, z = sample['position']
            if any(math.dist((x,y,z), cap) < 2.6 for cap in caps):
                continue
            q = ((c*x-s*y+p['origin'][0])*sign+offset[0], (s*x+c*y+p['origin'][1])*sign+offset[1], z+p['origin'][2])
            ok, why = probe(q); module_samples += 1
            if not ok:
                errors.append([label, p['id'], q, why])
assert not list(conflicts(data['parts'])), 'Coplanar visual overlap'
compiled = ROOT / 'Enfleshed_KitDistrict.rbxlx'
reference_count = 0
assert compiled.exists(), 'Build the place before validation'
place = ET.parse(compiled).getroot()
items = list(place.iter('Item'))
assert len([i for i in items if i.get('class') == 'Part']) == len(data['parts'])
assert len([i for i in items if i.get('class') == 'SpawnLocation']) == 1
expected = {p['name']: p for p in data['parts']}
for item in items:
    if item.get('class') != 'Part':
        continue
    props = item.find('Properties')
    p = expected[props.findtext("string[@name='Name']")]
    assert (props.findtext("bool[@name='CanCollide']") == 'true') == p['collision'], p['name']
    assert (float(props.findtext("float[@name='Transparency']", '0')) < 1) == p['visible'], p['name']
    cf = props.find("CoordinateFrame[@name='CFrame']")
    size = props.find("Vector3[@name='size']")
    center = [float(cf.findtext('X')), -float(cf.findtext('Z')), float(cf.findtext('Y'))]
    dims = [float(size.findtext('X')), float(size.findtext('Z')), float(size.findtext('Y'))]
    assert all(abs(a-b) < .0001 for a,b in zip(center+dims, p['center']+p['size'])), p['name']
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
report = dict(passed=not errors, parts=len(data['parts']), ground_cells=len(reached), preserved_reference_cells=len(baseline)*3, module_samples=module_samples, connector_samples=len(data['routes']), enemy_candidates=len(data['enemy_spawns']), covered_connector_samples=cover_samples, compiled_references=reference_count, errors=errors, studio_verified=False)
(HERE / 'validation.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({**report, 'errors': errors[:15]}, indent=2))
assert not errors, '%d failed probes' % len(errors)
