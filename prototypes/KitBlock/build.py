"""Build an isolated native Roblox test block from the approved kit dimensions.
Run from any directory with Python 3, then build review.project.json with Rojo.
"""
import json
import upper_layout
import math
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PACKS = ROOT / 'assets/blender/generated'
components = json.loads((HERE / 'components.json').read_text())
manifest = json.loads((PACKS / 'lower_layer_circulation_kit_v1/manifest.json').read_text())
frontage = json.loads((PACKS / 'lower_layer_frontage_kit_v1/manifest.json').read_text())
habitation = json.loads((PACKS / 'lower_layer_habitation_kit_v1/manifest.json').read_text())
assets = {a['name']: a for a in manifest['assets'] + frontage['assets'] + habitation['assets']}
placements = list(manifest['assembly']['placements'])
placements += [
    {'id': 'narrow_shop', 'asset': 'F01_NarrowShop', 'origin': [-21, 0, 0], 'angle': 0},
    {'id': 'recessed_shop', 'asset': 'F02_RecessedShop', 'origin': [-42, 0, 0], 'angle': 0},
    {'id': 'barred_shop', 'asset': 'F04_BarredStore', 'origin': [-21, -16, 0], 'angle': 180},
    {'id': 'service_shop', 'asset': 'F06_ServiceEntry', 'origin': [-43, -16, 0], 'angle': 180},
]
placements = upper_layout.extend(placements)
root = ET.Element('roblox', version='4')
model = ET.SubElement(root, 'Item', {'class': 'Model', 'referent': 'KitBlock'})
ET.SubElement(ET.SubElement(model, 'Properties'), 'string', name='Name').text = 'KitBlock'
records = []
part_count = 0


def group(name, parent=model):
    item = ET.SubElement(parent, 'Item', {'class': 'Model'})
    ET.SubElement(ET.SubElement(item, 'Properties'), 'string', name='Name').text = name
    return item


def rotate(v, angle):
    c, s = round(math.cos(math.radians(angle))), round(math.sin(math.radians(angle)))
    return [c * v[0] - s * v[1], s * v[0] + c * v[1], v[2]]


def transform(p, center, size):
    center = [a + b for a, b in zip(rotate(center, p['angle']), p['origin'])]
    size = list(size)
    if p['angle'] % 180:
        size[0], size[1] = size[1], size[0]
    return center, size


def part(parent, name, center, size, material='Plaster', collision=False, visible=True):
    global part_count
    assert min(size) > 0, (name, size)
    part_count += 1
    record = {'name': name, 'center': list(center), 'size': list(size), 'collision': collision, 'visible': visible}
    records.append(record)
    item = ET.SubElement(parent, 'Item', {'class': 'Part', 'referent': 'P' + str(part_count)})
    props = ET.SubElement(item, 'Properties')
    ET.SubElement(props, 'string', name='Name').text = name
    for key, value in {'Anchored': True, 'CanCollide': collision, 'CanTouch': False, 'CanQuery': collision, 'CastShadow': visible, 'Locked': True}.items():
        ET.SubElement(props, 'bool', name=key).text = str(value).lower()
    ET.SubElement(props, 'float', name='Transparency').text = '0' if visible else '1'
    tokens = {'Iron': 1088, 'Zinc': 1088, 'Glass': 272, 'Timber': 512, 'PaintedTimber': 512, 'CutStone': 816, 'Masonry': 816}
    ET.SubElement(props, 'token', name='Material').text = str(tokens.get(material, 816))
    for key in ('TopSurface', 'BottomSurface'):
        ET.SubElement(props, 'token', name=key).text = '0'
    color = components['materials'][material]['base_color']
    color_node = ET.SubElement(props, 'Color3', name='Color')
    for axis, value in zip(('R', 'G', 'B'), color):
        ET.SubElement(color_node, axis).text = str(value)
    size_node = ET.SubElement(props, 'Vector3', name='size')
    for axis, value in zip(('X', 'Y', 'Z'), (size[0], size[2], size[1])):
        ET.SubElement(size_node, axis).text = str(round(value, 6))
    cf = ET.SubElement(props, 'CoordinateFrame', name='CFrame')
    for axis, value in zip(('X', 'Y', 'Z'), (center[0], center[2], -center[1])):
        ET.SubElement(cf, axis).text = str(round(value, 6))
    for row in range(3):
        for col in range(3):
            ET.SubElement(cf, 'R%d%d' % (row, col)).text = '1' if row == col else '0'
    return item


footprints = []
for p in placements:
    data = components['assets'][p['asset']]
    node = group(p['id'] + '__' + p['asset'])
    for i, visual in enumerate(data['parts']):
        center, size = transform(p, visual['center'], visual['size'])
        part(node, p['id'] + '__VIS_%03d' % i, center, size, visual['material'])
    for i, collider in enumerate(data['colliders']):
        center, size = transform(p, collider['center'], collider['size'])
        part(node, p['id'] + '__COL_%03d' % i, center, size, collision=True, visible=False)
    if p['origin'][2] == 0 and not p['asset'].startswith('Z'):
        a = assets[p['asset']]
        c, s = transform(p, [0, a['depth'] / 2, 0], [a['width'], a['depth'], 1])
        footprints.append((c[0] - s[0] / 2, c[0] + s[0] / 2, c[1] - s[1] / 2, c[1] + s[1] / 2))

extra = group('Street_Loop_And_Enclosure')
# Native connector surfaces are a bounded sample assembly, not a city generator.
# All coordinates here use the kit authoring axes: Z is height.
rectangles = [(-66, 12, -16, 0), (-66, -54, -8, 34), (-60, -26, 22, 34),
              (-38, -26, 28, 96), (-38, 10, 94, 110), (-48, -35, 8, 28)]
cells = {(x, y) for x0, x1, y0, y1 in rectangles for x in range(x0, x1) for y in range(y0, y1)}
# No tiled collision seams: merge contiguous cells into long floor strips.
runs = {}
for y in sorted({y for x, y in cells}):
    xs = sorted(x for x, yy in cells if yy == y)
    start = prev = xs[0]
    for x in xs[1:] + [10**6]:
        if x != prev + 1:
            runs.setdefault((start, prev + 1), []).append(y)
            start = x
        prev = x
for (left, right), ys in runs.items():
    first = prev = ys[0]
    for y in ys[1:] + [10**6]:
        if y != prev + 1:
            center = ((left + right) / 2, (first + prev + 1) / 2, -.28)
            size = (right - left, prev + 1 - first, .5)
            part(extra, 'StreetFloor', center, size, 'CutStone', True)
            part(extra, 'StreetSupport', (center[0], center[1], -.6), (size[0] + .5, size[1] + .5, .5), collision=True, visible=False)
            first = y
        prev = y
# Boundary walls yield to existing kit footprints, whose walls/entrances define the edge.
segments = {}
for x, y in cells:
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        if (x + dx, y + dy) in cells:
            continue
        if dx == 1 and x == 9 and 98 <= y < 106:
            continue  # New rear-lane portal; all existing floor cells remain.
        test = (x + .5 + dx * .75, y + .5 + dy * .75)
        if any(x0 - .05 <= test[0] <= x1 + .05 and y0 - .05 <= test[1] <= y1 + .05 for x0, x1, y0, y1 in footprints):
            continue
        axis = 'x' if dx else 'y'
        fixed = x + (dx == 1) if dx else y + (dy == 1)
        segments.setdefault((axis, fixed), []).append(y if dx else x)
for (axis, fixed), values in segments.items():
    values.sort(); start = prev = values[0]
    for value in values[1:] + [10**6]:
        if value != prev + 1:
            center = (fixed, (start + prev + 1) / 2, 6.5) if axis == 'x' else ((start + prev + 1) / 2, fixed, 6.5)
            size = (.5, prev - start + 1, 13) if axis == 'x' else (prev - start + 1, .5, 13)
            part(extra, 'LaneBoundary', center, size, 'Masonry', True)
            start = value
        prev = value
# End shallow tenant rooms deliberately; F02 remains a real street-to-alley shortcut.
for p in placements:
    if p['id'] in ('narrow_shop', 'barred_shop', 'service_shop'):
        a = assets[p['asset']]
        c, s = transform(p, (0, a['depth'] + .15, 6.5), (a['width'], .3, 13))
        part(extra, p['id'] + '_RearWall', c, s, 'RepairPlaster', True)
# Main street frontage gaps have tall load-bearing infill, not empty skyline.
for lo, hi in [(-34, -27), (-15, -12), (12, 17), (29, 56)]:
    part(extra, 'NorthStreetInfill', ((lo + hi) / 2, .5, 15), (hi - lo, 1, 30), 'Plaster', True)
# Upper masses sit over the frontages, preserving the circulation beneath.
for p in placements:
    if not p['asset'].startswith('F'):
        continue
    a = assets[p['asset']]
    c, s = transform(p, (0, a['depth'] / 2, 36), (a['width'], a['depth'], 36))
    part(extra, p['id'] + '_UpperBuilding', c, s, 'Plaster', True)
upper_layout.structure(part, extra)
# Enclosed ancient envelope: no sky exposure or playable falls beyond the block.
part(extra, 'AncientRoof', (12, 44, 64), (190, 180, 8), 'Masonry', True)
for x in (-83, 107):
    part(extra, 'AncientSide', (x, 44, 30), (8, 180, 68), 'Masonry', True)
for y in (-46, 134):
    part(extra, 'AncientEnd', (12, y, 30), (190, 8, 68), 'Masonry', True)
part(extra, 'CatchFloor', (12, 44, -14), (190, 180, 4), 'Masonry', True)
# A few overhead slabs compress the street without intersecting the upper loop.
part(extra, 'WestLaneSoffit', (-32, 65, 15), (14, 60, 1), 'Masonry', True)

lights = group('TestLighting')
for index, (x, y, z) in enumerate([(-2, -8, 12), (-40, -8, 12), (-23, -8, 12), (-60, 22, 12), (-32, 48, 11), (-32, 83, 11), (-10, 102, 12), (5, 27, 11), (11, 52, 11), (32, 52, 11), (29, 20, 11), (-3, 73, 11), (82, 44, 21), (40, 42, 28), (10, 46, 28), (-24, 53, 29), (-15, 75, 29), (9, 66, 29), (26, 74, 29), (26, 90, 29), (72, 96, 21), (46, 102, 12)]):
    fixture = part(lights, 'Lamp_%02d' % index, (x, y, z), (.5, .5, .3), 'Zinc')
    light = ET.SubElement(fixture, 'Item', {'class': 'PointLight'})
    properties = ET.SubElement(light, 'Properties')
    ET.SubElement(properties, 'float', name='Brightness').text = '1.8'
    ET.SubElement(properties, 'float', name='Range').text = '27'
    ET.SubElement(properties, 'bool', name='Shadows').text = 'true'
    color = ET.SubElement(properties, 'Color3', name='Color')
    for axis, value in zip(('R', 'G', 'B'), (1, .78, .52)):
        ET.SubElement(color, axis).text = str(value)

# Keep collision authoritative at the exact source dimensions. Only visual faces
# are inset where the native box conversion would otherwise draw coplanar layers.
import copy
from surface_cleanup import separate
original_parts = copy.deepcopy(records)
cleanup_report, adjusted = separate(records)
xml_parts = [item for item in root.iter('Item') if item.get('class') == 'Part']
for index in sorted(adjusted):
    record, original = records[index], original_parts[index]
    props = xml_parts[index].find('Properties')
    if original['collision']:
        part(extra, original['name'] + '_PreservedCollision', original['center'], original['size'], collision=True, visible=False)
        record['collision'] = False
        for key in ('CanCollide', 'CanQuery'):
            props.find("bool[@name='" + key + "']").text = 'false'
    size = record['size']; center = record['center']
    for axis, value in zip(('X', 'Y', 'Z'), (size[0], size[2], size[1])):
        props.find("Vector3[@name='size']/" + axis).text = str(round(value, 6))
    for axis, value in zip(('X', 'Y', 'Z'), (center[0], center[2], -center[1])):
        props.find("CoordinateFrame[@name='CFrame']/" + axis).text = str(round(value, 6))
def collision_signature(parts):
    return sorted((tuple(p['center']), tuple(p['size'])) for p in parts if p['collision'])
assert collision_signature(original_parts) == collision_signature(records), 'Cleanup must preserve collision exactly'
cleanup_report['collision_geometry_unchanged'] = True
cleanup_report['max_dimension_reduction'] = max(original_parts[i]['size'][k] - records[i]['size'][k] for i in adjusted for k in range(3))
(HERE / 'surface_validation.json').write_text(json.dumps(cleanup_report, indent=2) + '\n')
ET.indent(root)
ET.ElementTree(root).write(HERE / 'Block.rbxmx', encoding='utf-8', xml_declaration=True)
report = {'placements': placements, 'parts': records, 'part_count': part_count, 'frontage_count': 6, 'habitation_kit_assets': len(habitation['assets']),
          'connections': manifest['assembly']['connections'] + upper_layout.CONNECTIONS,
          'caps': [c for c in manifest['assembly']['caps'] if c['placement'] not in upper_layout.REMOVED_CAPS],
          'spawn': [-2, -8, 0], 'enemy_spawns': [[-38, -8, 0], [-46, -8, 0], [-54, -8, 0]],
          'ground_checkpoints': [[-2, -8, 0], [-1, 8, 0], [11, 40, 0], [-9, 58, 0], [3, 91, 0], [3, 102, 0], [-32, 90, 0], [-32, 40, 0], [-60, 28, 0], [-60, -8, 0], [-45.3, 3, 0], [-42, 17, 0]],
          'limitations': ['Native Part reconstruction omits mesh bevels and PBR atlas textures.', 'Live Roblox traversal and enemy pathfinding require Studio playtesting.']}
(HERE / 'assembly.json').write_text(json.dumps(report, indent=2) + '\n')
# Separate entry points reuse the original mechanics without starting any city systems.
services = {'$className': 'Folder'}
for file in sorted((ROOT / 'src/server/Services').glob('*.luau')):
    services[file.stem] = {'$path': 'OpeningService.luau' if file.stem == 'OpeningService' else '../../' + str(file.relative_to(ROOT))}
project = {'name': 'Enfleshed_KitBlock', 'tree': {'$className': 'DataModel',
    'ReplicatedStorage': {'Shared': {'$path': '../../src/shared'}},
    'ServerScriptService': {'Server': {'$path': 'Server.server.luau', 'Services': services, 'Networking': {'$path': '../../src/server/Networking'}, 'Development': {'$path': '../../src/server/Development'}}},
    'StarterPlayer': {'$className': 'StarterPlayer', 'StarterPlayerScripts': {'Client': {'$path': 'Client.client.luau', 'Controllers': {'$path': '../../src/client/Controllers'}}}},
    'Workspace': {'$properties': {'StreamingEnabled': False, 'FallenPartsDestroyHeight': -60}, 'KitBlock': {'$path': 'Block.rbxmx'},
        'TestSpawn': {'$className': 'SpawnLocation', '$properties': {'Anchored': True, 'Neutral': True, 'Duration': 0, 'Transparency': 1, 'CanCollide': False, 'Size': [4, .2, 4], 'Position': [-2, .1, 8]}}},
    'Lighting': {'$properties': {'Ambient': [.17, .17, .18], 'OutdoorAmbient': [.08, .08, .1], 'Brightness': 0, 'ClockTime': 0, 'GlobalShadows': True}}}}
(HERE / 'review.project.json').write_text(json.dumps(project, indent=2) + '\n')
print('Built', part_count, 'Parts; six frontages; isolated KitBlock project')
