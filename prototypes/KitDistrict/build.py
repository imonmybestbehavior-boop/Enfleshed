"""Explicit three-block district pilot. Reads, never rewrites, approved KitBlock."""
import copy
import hashlib
import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REFERENCE = HERE.parent / 'KitBlock'
sys.path.insert(0, str(REFERENCE))
from surface_cleanup import separate

source = json.loads((REFERENCE / 'assembly.json').read_text())
components = json.loads((REFERENCE / 'components.json').read_text())
source_xml = ET.parse(REFERENCE / 'Block.rbxmx')
source_parts = sorted((p for p in source_xml.iter('Item') if p.get('class') == 'Part'), key=lambda p: int(p.get('referent')[1:]))
assert len(source_parts) == len(source['parts'])
root = ET.Element('roblox', version='4')
model = ET.SubElement(root, 'Item', {'class': 'Model'})
ET.SubElement(ET.SubElement(model, 'Properties'), 'string', name='Name').text = 'KitDistrict'
records, nodes = [], []
blocks = [('Commercial', (0, 0), 1), ('Residential', (-40, 264), -1), ('Workshop', (0, 350), 1)]


def transform(point, offset, sign):
    return [point[0] * sign + offset[0], point[1] * sign + offset[1], point[2]]


def sync(node, p):
    props = node.find('Properties')
    props.find("string[@name='Name']").text = p['name']
    props.find("float[@name='Transparency']").text = '0' if p['visible'] else '1'
    props.find("bool[@name='CastShadow']").text = str(p['visible']).lower()
    for axis, value in zip('XYZ', (p['center'][0], p['center'][2], -p['center'][1])):
        props.find("CoordinateFrame[@name='CFrame']/" + axis).text = str(round(value, 6))
    for axis, value in zip('XYZ', (p['size'][0], p['size'][2], p['size'][1])):
        props.find("Vector3[@name='size']/" + axis).text = str(round(value, 6))
    for key in ('CanCollide', 'CanQuery'):
        props.find("bool[@name='" + key + "']").text = str(p['collision']).lower()


def append(node, p):
    node.attrib.pop('referent', None)
    sync(node, p)
    model.append(node)
    records.append(p)
    nodes.append(node)


# Remove a doorway volume from boundary walls, retaining jambs and structural headers.
# Works on source visual and hidden collision Parts together; no invisible plugs.
def carve(p, axis, plane, lo, hi, bottom, top):
    a, b = [c - s / 2 for c, s in zip(p['center'], p['size'])], [c + s / 2 for c, s in zip(p['center'], p['size'])]
    lateral = 1 - axis
    if not (a[axis] - .03 <= plane <= b[axis] + .03 and a[lateral] < hi and b[lateral] > lo and a[2] < top and b[2] > bottom):
        return [p]
    boxes = []
    if a[lateral] < lo:
        aa, bb = a[:], b[:]; bb[lateral] = lo; boxes.append((aa, bb))
    if b[lateral] > hi:
        aa, bb = a[:], b[:]; aa[lateral] = hi; boxes.append((aa, bb))
    for lower, upper in ((a[2], min(bottom, b[2])), (max(top, a[2]), b[2])):
        if upper > lower:
            aa, bb = a[:], b[:]
            aa[lateral], bb[lateral], aa[2], bb[2] = max(a[lateral], lo), min(b[lateral], hi), lower, upper
            boxes.append((aa, bb))
    return [dict(p, name=p['name'] + '_Opening_%d' % i,
                 center=[(x + y) / 2 for x, y in zip(aa, bb)], size=[y - x for x, y in zip(aa, bb)])
            for i, (aa, bb) in enumerate(boxes)]


for label, offset, sign in blocks:
    for original, xml in zip(source['parts'], source_parts):
        if original['name'].startswith(('AncientRoof', 'AncientSide', 'AncientEnd', 'CatchFloor')):
            continue
        # U02 was authored as a closed apartment alcove. Its decorative leaf
        # must not survive when this instance becomes a through passage.
        if (label in ('Commercial', 'Residential')
                and original['name'].startswith('upper_apartment_entry__VIS_')
                and 86.9 < original['center'][1] < 87.5
                and 18 < original['center'][2] < 29):
            continue
        pieces = [copy.deepcopy(original)]
        cuts = []
        if label in ('Commercial', 'Residential'):
            cuts += [(1, 110, -26, -14, 0, 12)]
        if label in ('Residential', 'Workshop'):
            cuts += [(1, -16, -66, -54, 0, 12)]
        if 'LaneBoundary' in original['name']:
            for cut in cuts:
                pieces = [piece for p in pieces for piece in carve(p, *cut)]
        if label in ('Commercial', 'Residential') and original['name'].startswith('upper_apartment_entry__'):
            pieces = [piece for p in pieces for piece in carve(p, 1, 88, -13, -5, 18, 30)]
        for p in pieces:
            p['center'] = transform(p['center'], offset, sign)
            p['name'] = label + '__' + p['name']
            append(copy.deepcopy(xml), p)


def part(name, center, size, material='Masonry', collision=True, visible=True):
    p = dict(name=name, center=list(center), size=list(size), collision=collision, visible=visible)
    node = copy.deepcopy(source_parts[0])
    for child in list(node.findall('Item')):
        node.remove(child)
    props = node.find('Properties')
    props.find("float[@name='Transparency']").text = '0' if visible else '1'
    color = props.find("Color3[@name='Color']")
    for axis, value in zip('RGB', components['materials'][material]['base_color']):
        color.find(axis).text = str(value)
    append(node, p)
    return node


for offset, sign in [((0, 0), 1), ((-40, 264), -1)]:
    for x in (-13.2, -4.8):
        part('ThroughPortalJamb', transform((x, 87.7, 24), offset, sign), (.4, .9, 12), 'CutStone')
    part('ThroughPortalLintel', transform((-9, 87.7, 30.35), offset, sign), (8.8, .9, .6), 'CutStone')

routes = []
# Two genuinely different ground paths around a solid inhabited service core.
# Endpoints coincide with the cut boundary portals. Widths are 10/12 studs.
paths = [
    ('CoveredService', [(-20, 106), (-20, 122), (-4, 122), (-4, 140), (-20, 140), (-20, 158)], 10, 0),
    ('RearService', [(-20, 116), (-44, 116), (-44, 146), (-20, 146)], 10, 0),
    ('WorkshopApproach', [(20, 276), (20, 300), (-20, 300), (-20, 312), (-60, 312), (-60, 338)], 12, 0),
    ('WorkshopBackLane', [(20, 290), (46, 290), (46, 322), (-60, 322)], 10, 0),
    ('UpperResidentialLink', [(-9, 85), (-9, 128), (-31, 128), (-31, 179)], 8, 18),
]
# Raster union prevents internal guard/wall seams at turns and intersections.
for height in (0, 18):
    cells = set()
    for name, points, width, z in paths:
        if z != height:
            continue
        for a, b in zip(points, points[1:]):
            assert a[0] == b[0] or a[1] == b[1]
            half = width // 2
            x0, x1 = min(a[0], b[0]) - half, max(a[0], b[0]) + half
            y0, y1 = min(a[1], b[1]) - half, max(a[1], b[1]) + half
            cells.update((x, y) for x in range(x0, x1) for y in range(y0, y1))
            steps = max(abs(a[0] - b[0]), abs(a[1] - b[1]))
            routes.extend([a[0] + (b[0] - a[0]) * t / steps, a[1] + (b[1] - a[1]) * t / steps, z] for t in range(steps + 1))
    # Bound connector pieces to the interface plane rather than overlapping rooms.
    if height == 0:
        cells = {(x, y) for x, y in cells if 110 <= y < 154 or 280 <= y < 334}
    else:
        cells = {(x, y) for x, y in cells if 88 <= y < 176}
    runs = {}
    for y in sorted({y for x, y in cells}):
        xs = sorted(x for x, yy in cells if yy == y)
        start = previous = xs[0]
        for x in xs[1:] + [99999]:
            if x != previous + 1:
                runs.setdefault((start, previous + 1), []).append(y)
                start = x
            previous = x
    for (left, right), ys in runs.items():
        start = previous = ys[0]
        for y in ys[1:] + [99999]:
            if y != previous + 1:
                center = ((left + right) / 2, (start + previous + 1) / 2, height - .3)
                size = (right - left, previous + 1 - start, .6)
                part('LinkDeck', center, size, 'CutStone')
                # Real corridor cover at the same clear height as the room kit.
                part('LinkCeiling', (center[0], center[1], height + 13.55),
                     (size[0] + .5, size[1] + .5, .6), 'Masonry')
                part('LinkSupport', (center[0], center[1], height - .65), (size[0] + .6, size[1] + .6, .7), visible=False)
                start = y
            previous = y
    # Merge perimeter runs; suppress only the intended four/elevated two interfaces.
    edges = {}
    for x, y in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) in cells:
                continue
            fixed = x + (dx == 1) if dx else y + (dy == 1)
            if dy and ((height == 0 and fixed in (110, 154, 280, 334)) or (height == 18 and fixed in (88, 176))):
                continue
            edges.setdefault((bool(dx), fixed), []).append(y if dx else x)
    for (vertical, fixed), values in edges.items():
        values.sort(); start = previous = values[0]
        for v in values[1:] + [99999]:
            if v != previous + 1:
                h = 13 if height == 0 else 3.4
                c = (fixed, (start + previous + 1) / 2, height + h / 2) if vertical else ((start + previous + 1) / 2, fixed, height + h / 2)
                s = (.5, previous - start + 1, h) if vertical else (previous - start + 1, .5, h)
                part('PassageWall' if height == 0 else 'GalleryParapet', c, s)
                if height == 18:
                    # A wall-backed covered gallery, with framed open bays on
                    # the other side; posts bear on its existing parapets.
                    if vertical and fixed in (-13, -35):
                        part('GalleryBacking', (c[0], c[1], height + 8.2),
                             (.5, s[1], 9.6), 'RepairPlaster')
                    else:
                        length = previous - start + 1
                        count = max(1, (length + 11) // 12)
                        for n in range(count + 1):
                            along = start + .35 + (length - .7) * n / count
                            position = (fixed, along, height + 8.4) if vertical else (along, fixed, height + 8.4)
                            part('GalleryBearing', position, (.5, .5, 10), 'CutStone')
                start = v
            previous = v

# Solid construction cores create the route splits; upper apartments explain the walls.
for name, c, s in [
    ('ServiceCore', (-24, 131, 6.5), (27, 12, 13)),
    ('WorkshopCore', (-1, 311, 20), (28, 10, 40)),
    ('WorkshopRearMass', (-40, 295, 20), (16, 22, 40)),
    ('WorkshopSideMass', (-29, 289, 20), (6, 10, 40)),
    ('WorkshopUpperMass', (-29, 300, 29), (6, 12, 22)),
    ('ResidentialOverpass', (-20, 130, 35), (70, 8, 4)),
    ('WorkshopOverpass', (-8, 320, 33), (130, 6, 3)),
]:
    part(name, c, s, 'Plaster')

# Add recognizable windowed habitation over the service cores, using the approved kit.
def asset(label, key, origin, angle=0):
    data = components['assets'][key]
    c, sn = round(math.cos(math.radians(angle))), round(math.sin(math.radians(angle)))
    def placed(p):
        x, y, z = p['center']; size = list(p['size'])
        if angle % 180:
            size[0], size[1] = size[1], size[0]
        return [c*x-sn*y+origin[0], sn*x+c*y+origin[1], z+origin[2]], size
    for i, p in enumerate(data['parts']):
        center, size = placed(p)
        part(label + '_VIS_%d' % i, center, size, p['material'], False)
    for i, p in enumerate(data['colliders']):
        center, size = placed(p)
        part(label + '_COL_%d' % i, center, size, visible=False)

# One service room is embedded into the workshop core, opening onto the new lane.
# Reuse a real kit doorway; leave the neighbouring solid masses as its structural shell.
kept_records, kept_nodes = [], []
for p, node in zip(records, nodes):
    pieces = carve(p, 0, -26, 296, 304, 0, 12) if p['name'] == 'PassageWall' else [p]
    model.remove(node)
    for piece in pieces:
        clone = copy.deepcopy(node); sync(clone, piece); model.append(clone)
        kept_records.append(piece); kept_nodes.append(clone)
records, nodes = kept_records, kept_nodes
asset('WorkshopServiceRoom', 'F06_ServiceEntry', (-26, 300, 0), 90)
routes.extend([[x, 300, 0] for x in range(-29, -19)])

asset('ServiceUpperWindows', 'U01_ApartmentWindowBay', (-24, 124, 36))
asset('WorkshopUpperWindows', 'U01_ApartmentWindowBay', (-1, 305, 18))
# All distant directions terminate against actual ancient structure, including below.
part('AncientCeiling', (-20, 215, 64), (270, 530, 8))
part('AncientCatch', (-20, 215, -14), (270, 530, 4))
for x in (-151, 111):
    part('AncientSide', (x, 215, 26), (8, 530, 76))
for y in (-46, 476):
    part('AncientEnd', (-20, y, 26), (270, 8, 76))
for x, y, z in [(-20, 115, 11), (-44, 132, 11), (-4, 132, 11), (-20, 150, 11), (20, 291, 11), (-18, 302, 11), (-55, 320, 11), (42, 316, 11), (-9, 107, 28), (-20, 128, 28), (-31, 152, 28)]:
    node = part('ConnectorLamp', (x, y, z), (.5, .5, .3), 'Zinc', False)
    lamp = ET.SubElement(node, 'Item', {'class': 'PointLight'})
    props = ET.SubElement(lamp, 'Properties')
    ET.SubElement(props, 'float', name='Brightness').text = '1.8'
    ET.SubElement(props, 'float', name='Range').text = '27'
    ET.SubElement(props, 'bool', name='Shadows').text = 'true'
    color = ET.SubElement(props, 'Color3', name='Color')
    for axis, value in zip('RGB', (1, .78, .52)):
        ET.SubElement(color, axis).text = str(value)

original = copy.deepcopy(records)
report, changed = separate(records)
for i in sorted(changed):
    if original[i]['collision']:
        p = original[i]
        part(p['name'] + '_Collision', p['center'], p['size'], visible=False)
        records[i]['collision'] = False
    sync(nodes[i], records[i])
signature = lambda ps: sorted((tuple(p['center']), tuple(p['size'])) for p in ps if p['collision'])
assert signature(original) == signature(records)
for i, p in enumerate(records):
    p['name'] = '%04d_%s' % (i, p['name'])
    sync(nodes[i], p)
ET.indent(root)
ET.ElementTree(root).write(HERE / 'District.rbxmx', encoding='utf-8', xml_declaration=True)
project = json.loads((REFERENCE / 'review.project.json').read_text())
project['name'] = 'Enfleshed_KitDistrict'
ws = project['tree']['Workspace']
ws.pop('KitBlock')
ws['KitDistrict'] = {'$path': 'District.rbxmx'}
project['tree']['ServerScriptService']['Server']['Services']['OpeningService']['$path'] = '../KitBlock/OpeningService.luau'
(HERE / 'review.project.json').write_text(json.dumps(project, indent=2) + '\n')
checkpoints = [transform(p, offset, sign) for _, offset, sign in blocks for p in source['ground_checkpoints']]
spawns = [[x, y, 0] for x, y in [(-38,-8),(-46,-8),(-54,-8),(-60,12),(-32,48),(-32,78),(-20,102),(3,102),(-2,272),(6,272),(14,272),(20,252),(-8,216),(-8,186),(-38,334),(-46,334),(-54,334),(-60,358),(-32,390),(-32,420),(-20,444),(3,444),(20,240),(-8,202),(-60,30),(-32,64),(20,244),(-32,406)]]
spawns = [[x, y + 8 if y >= 330 else y, z] for x, y, z in spawns]
(HERE / 'SpawnPoints.luau').write_text('--!strict\n-- District-only ground candidates, checked against generated collision.\nreturn {\n' + ''.join('\tVector3.new(%s, 8, %s),\n' % (x, -y) for x, y, _ in spawns) + '}\n')
project['tree']['ServerScriptService']['Server']['SpawnPoints'] = {'$path': 'SpawnPoints.luau'}
(HERE / 'review.project.json').write_text(json.dumps(project, indent=2) + '\n')
(HERE / 'assembly.json').write_text(json.dumps(dict(parts=records, blocks=blocks, routes=routes, checkpoints=checkpoints, enemy_spawns=spawns, surface_cleanup=report, reference_sha256=hashlib.sha256((REFERENCE / 'Block.rbxmx').read_bytes()).hexdigest()), indent=2) + '\n')
print('Built district:', len(records), 'Parts;', len(blocks), 'blocks; reference unchanged')
