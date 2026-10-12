"""Build the bounded Lower Layer interior circulation asset library in Blender."""
import sys
import math
import json
import hashlib
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lower_layer_circulation_common as kit

OUT = kit.ROOT / 'assets/blender/generated/lower_layer_circulation_kit_v1'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
kit.initialize(OUT)
B = kit.box
S = kit.socket
R = kit.route


def wall_interval(side, lo, hi, bottom=0, top=18, material='Plaster'):
    if hi - lo < .001:
        return
    a = kit.CURRENT
    w, d = a['width'], a['depth']
    if side in ('south', 'north'):
        center = ((lo + hi) / 2, .3 if side == 'south' else d - .3, (bottom + top) / 2)
        size = (hi - lo, .6, top - bottom)
    else:
        center = (-w / 2 + .3 if side == 'west' else w / 2 - .3, (lo + hi) / 2, (bottom + top) / 2)
        size = (.6, hi - lo, top - bottom)
    B(side + '_wall', center, size, material)


def shell(ports, roof=True, wall_height=18):
    """Walls are built around real openings; never overlay doors on a solid wall."""
    a = kit.CURRENT
    w, d = a['width'], a['depth']
    B('continuous_floor', (0, d / 2, -.3), (w, d, .6), 'CutStone', role='floor')
    for side in ('south', 'north', 'west', 'east'):
        low, high = (-w / 2, w / 2) if side in ('south', 'north') else (0, d)
        openings = sorted([p for p in ports if p[0] == side], key=lambda p: p[1])
        cursor = low
        for _, center, width in openings:
            wall_interval(side, cursor, center - width / 2, top=wall_height)
            if wall_height > 12:
                wall_interval(side, center - width / 2, center + width / 2, 12, wall_height, 'Masonry')
            cursor = center + width / 2
        wall_interval(side, cursor, high, top=wall_height)
    if roof:
        B('removable_ceiling', (0, d / 2, 13.55), (w, d, .6), 'Masonry', section='roof', role='ceiling')
    normals = {'south': (0, -1, 0), 'north': (0, 1, 0), 'west': (-1, 0, 0), 'east': (1, 0, 0)}
    for side, center, width in ports:
        pos = (center, 0 if side == 'south' else d, 0) if side in ('south', 'north') else (-w / 2 if side == 'west' else w / 2, center, 0)
        S(side, pos, normals[side], width)
        # The jambs occupy the solid side of each opening, preserving clear width.
        x, y, _ = pos
        jamb_height = min(12, wall_height)
        for sign in (-1, 1):
            if side in ('south', 'north'):
                c, dim = (x + sign * (width / 2 + .12), y, jamb_height / 2), (.24, .82, jamb_height)
            else:
                c, dim = (x, y + sign * (width / 2 + .12), jamb_height / 2), (.82, .24, jamb_height)
            B(side + '_jamb', c, dim, 'CutStone')
        if wall_height > 12:
            dim = (width + .48, .86, .5) if side in ('south', 'north') else (.86, width + .48, .5)
            B(side + '_lintel', (x, y, 12.25), dim, 'CutStone')
    a['clearance'] = {'radius': 1.9, 'height': 9.5, 'portal_height': 12}


def room(name, width, depth, kind, use, ports, roof=True, wall_height=18):
    kit.asset(name, width, depth, kind, use)
    shell(ports, roof, wall_height)


room('I01_OffsetVestibule', 24, 24, 'interior', 'Offset shop-to-interior transition with a dividing wall.', [('south', -6, 8), ('north', 6, 8)])
B('partition', (-5, 12, 9), (14, .6, 18), 'RepairPlaster')
R('dogleg', [(-6, 0, 0), (-6, 6, 0), (6, 6, 0), (6, 24, 0)])
room('I02_DoglegPassage', 24, 32, 'interior', 'Parallel passages joined by a short lateral crossing.', [('south', -6, 8), ('north', 6, 8)])
for y in (6, 26):
    B('spine', (0, y, 9), (.6, 12, 18), 'Masonry')
R('offset', [(-6, 0, 0), (-6, 16, 0), (6, 16, 0), (6, 32, 0)])
room('I03_CornerPassage', 16, 16, 'interior', 'Enclosed ninety-degree corner.', [('south', 0, 8), ('east', 8, 8)])
R('corner', [(0, 0, 0), (0, 8, 0), (8, 8, 0)])
room('I04_TJunction', 24, 16, 'interior', 'Three-way room junction with framed exits.', [('south', 0, 8), ('west', 8, 8), ('east', 8, 8)])
for x in (-12, 12):
    R('branch', [(0, 0, 0), (0, 8, 0), (x, 8, 0)])
room('I05_SplitRoom', 24, 24, 'interior', 'Two paths reconnect around a structural service core.', [('south', 0, 8), ('north', 0, 8), ('east', 12, 8)])
B('load_bearing_core', (0, 12, 9), (4, 8, 18), 'Masonry')
for x in (-6, 6):
    R('core_loop', [(0, 0, 0), (0, 4, 0), (x, 4, 0), (x, 20, 0), (0, 20, 0), (0, 24, 0)])
R('side_exit', [(6, 12, 0), (12, 12, 0)])
room('I06_SideExitRoom', 24, 24, 'interior', 'Divided rear room with side entrance and offset onward route.', [('south', -6, 8), ('north', 6, 8), ('east', 8, 8)])
B('room_divider', (-5, 14, 9), (14, .6, 18), 'RepairPlaster')
R('through_room', [(-6, 0, 0), (-6, 8, 0), (6, 8, 0), (6, 24, 0)])
R('side', [(6, 8, 0), (12, 8, 0)])

kit.asset('I07_StairFlight', 12, 32, 'vertical', 'Half-story stair: use two flights and a return landing for an 18-stud rise.')
kit.CURRENT.update(rise=9, tread=24 / 18, clearance={'radius': 1.9, 'height': 9.5})
B('bottom_landing', (0, 2, -.3), (12, 4, .6), 'CutStone', role='floor')
B('top_landing', (0, 30, 8.7), (12, 4, .6), 'CutStone', role='floor')
R('bottom', [(0, 0, 0), (0, 4, 0)])
R('top', [(0, 28, 9), (0, 32, 9)])
for i in range(18):
    rise, y = (i + 1) * .5, 4 + (i + .5) * 24 / 18
    B('tread_%02d' % i, (0, y, (rise - .6) / 2), (12, 24 / 18, rise + .6), 'CutStone', role='step')
    kit.CURRENT['samples'].append({'route': 'stairs', 'position': [0, y, rise]})
    for x in (-5.75, 5.75):
        B('stair_guard', (x, y, rise + 2), (.25, 24 / 18, 4), 'Iron')
for y, z in ((2, 0), (30, 9)):
    for x in (-5.75, 5.75):
        B('landing_guard', (x, y, z + 2), (.25, 4, 4), 'Iron')
S('south', (0, 0, 0), (0, -1, 0))
S('north', (0, 32, 9), (0, 1, 0))
room('I08_ReturnLanding', 24, 12, 'vertical', 'Guarded switchback between adjacent counter-running flights.', [('south', -6, 8), ('south', 6, 8)], False, 4)
# Multiple openings on one edge have distinct socket IDs.
kit.CURRENT['ports'][0]['name'] = 'south_left'
kit.CURRENT['ports'][1]['name'] = 'south_right'
R('return', [(-6, 0, 0), (-6, 6, 0), (6, 6, 0), (6, 0, 0)])
room('I09_TopLanding', 24, 12, 'vertical', 'Offset landing connecting the stair pair to an upper route.', [('south', 0, 8), ('north', 6, 8)], False, 4)
R('landing', [(0, 0, 0), (0, 6, 0), (6, 6, 0), (6, 12, 0)])
room('I10_GalleryLink', 12, 24, 'upper', 'Guarded upper gallery with a lateral connection.', [('south', 0, 8), ('north', 0, 8), ('east', 12, 8)], False, 4)
B('back_wall', (-5.7, 12, 11), (.6, 24, 14), 'Plaster')
R('gallery', [(0, 0, 0), (0, 24, 0)])
R('gallery_side', [(0, 12, 0), (6, 12, 0)])
room('I11_CourtyardTransition', 24, 24, 'transition', 'Covered entry opens into a small guarded court with a side exit.', [('south', 0, 8), ('north', 0, 8), ('west', 16, 8)], False, 4)
for x in (-11.7, 11.7):
    B('entry_side', (x, 4, 8.5), (.6, 8, 9), 'Plaster')
B('entry_cover', (0, 4, 13.55), (24, 8, .6), 'Masonry', section='roof', role='ceiling')
R('court', [(0, 0, 0), (0, 24, 0)])
R('court_side', [(0, 16, 0), (-12, 16, 0)])
room('I12_BridgeLink', 12, 24, 'upper', 'Continuous metal bridge deck with parapets and framed ends.', [('south', 0, 8), ('north', 0, 8)], False, 4)
for y in range(2, 24, 4):
    B('deck_plate', (0, y, .012), (10.7, 3.96, .024), 'Zinc', solid=False)
R('bridge', [(0, 0, 0), (0, 24, 0)])
room('I13_ServiceAlcove', 12, 12, 'interior', 'Short enclosed dead-end branch; no gameplay or loot included.', [('south', 0, 8)])
R('alcove', [(0, 0, 0), (0, 8, 0)])
for name, width, entrance, source in [('A01_ResidentialAdapter', 12, 5.5, 'F05_ResidentialEntry'), ('A02_AlleyAdapter', 16, 9, 'F07_AlleyMouth'), ('A03_PassageAdapter', 16, 12, 'F08_ThroughPassage')]:
    room(name, width, 4, 'adapter', 'Frontage rear opening to standard eight-stud circulation port.', [('south', 0, entrance), ('north', 0, 8)])
    kit.CURRENT['compatibility'] = source
    R('adapter', [(0, 0, 0), (0, 4, 0)])
kit.asset('Z01_PortalClosure', 12, .6, 'closure', 'Solid cap for deliberately unused circulation sockets.')
B('closure', (0, .3, 9), (12, .6, 18), 'RepairPlaster')
S('mount', (0, 0, 0), (0, -1, 0), walkable=False)
records = kit.finish_assets()

# Display layout never changes the exported asset coordinates.
for i, a in enumerate(kit.ASSETS):
    a['root'].location = ((i % 5) * 38, (i // 5) * 46, 0)
    a['collection'].instance_offset = a['root'].location

frontage_manifest = json.loads((kit.FRONTAGE / 'manifest.json').read_text())
frontage_records = {a['name']: a for a in frontage_manifest['assets']}
source_parent = bpy.data.collections.new('FRONTAGE_DEMO_SOURCES')
bpy.context.scene.collection.children.link(source_parent)
with bpy.data.libraries.load(str(kit.FRONTAGE / 'lower_layer_frontage_kit_v1.blend')) as (source, target):
    target.collections = ['F08_ThroughPassage', 'F05_ResidentialEntry']
for collection in target.collections:
    source_parent.children.link(collection)
    collection.asset_clear()
source_parent.hide_render = True
source_parent.hide_viewport = True

by_name = {a['name']: a for a in records}
collections = {a['name']: a['collection'] for a in kit.ASSETS}
for c in target.collections:
    collections[c.name] = c
# Explicit sockets are verified against the approved frontage manifest in the verifier.
for name, x, depth, width in [('F08_ThroughPassage', -1, 16, 12), ('F05_ResidentialEntry', -.65, 6.25, 5.5)]:
    a = dict(frontage_records[name])
    a['ports'] = [{'name': 'rear', 'position': [x, depth, 0], 'normal': [0, 1, 0], 'width': width}]
    by_name[name] = a

placements, connections = [], []
assembly = bpy.data.collections.new('CONNECTED_SAMPLE'); kit.REVIEW.children.link(assembly)


def rotate(p, angle):
    c, s = round(math.cos(math.radians(angle))), round(math.sin(math.radians(angle)))
    return [c * p[0] - s * p[1], s * p[0] + c * p[1], p[2]]


def place(label, name, origin, angle=0):
    p = {'id': label, 'asset': name, 'origin': list(origin), 'angle': angle}
    placements.append(p)
    ob = bpy.data.objects.new(label, None); assembly.objects.link(ob)
    ob.instance_type = 'COLLECTION'; ob.instance_collection = collections[name]
    ob.location = Vector(origin) + Vector((260, 0, 0)); ob.rotation_euler.z = math.radians(angle)
    return p


def port(p, name):
    local = next(s for s in by_name[p['asset']]['ports'] if s['name'] == name)
    return {**local, 'position': [v + o for v, o in zip(rotate(local['position'], p['angle']), p['origin'])], 'normal': rotate(local['normal'], p['angle'])}


def attach(label, name, own, other, remote, angle=0):
    target = port(other, remote)
    local = next(s for s in by_name[name]['ports'] if s['name'] == own)
    offset = rotate(local['position'], angle)
    p = place(label, name, [v - q for v, q in zip(target['position'], offset)], angle)
    actual = port(p, own)
    assert actual['normal'] == [-v for v in target['normal']], (label, actual, target)
    assert actual['width'] == target['width'], (label, 'incompatible widths')
    connections.append({'a': [other['id'], remote], 'b': [label, own]})
    return p


front = place('street_passage', 'F08_ThroughPassage', (0, 0, 0))
adapter = attach('passage_adapter', 'A03_PassageAdapter', 'south', front, 'rear')
vest = attach('vestibule', 'I01_OffsetVestibule', 'south', adapter, 'north')
junction = attach('junction', 'I04_TJunction', 'south', vest, 'north')
corner = attach('left_corner', 'I03_CornerPassage', 'south', junction, 'west', 90)
rear = attach('rear_room', 'I06_SideExitRoom', 'south', corner, 'east')
res_adapter = attach('residential_adapter', 'A01_ResidentialAdapter', 'north', rear, 'north', 180)
attach('residential_exit', 'F05_ResidentialEntry', 'rear', res_adapter, 'south', 180)
split = attach('split_room', 'I05_SplitRoom', 'south', junction, 'east', -90)
dogleg = attach('dogleg', 'I02_DoglegPassage', 'north', split, 'east')
attach('ground_alcove', 'I13_ServiceAlcove', 'south', dogleg, 'south', 180)
stair1 = attach('first_flight', 'I07_StairFlight', 'south', split, 'north', -90)
turn = attach('return_landing', 'I08_ReturnLanding', 'south_left', stair1, 'north', -90)
stair2 = attach('second_flight', 'I07_StairFlight', 'south', turn, 'south_right', 90)
top = attach('upper_landing', 'I09_TopLanding', 'north', stair2, 'north', -90)
gallery = attach('gallery', 'I10_GalleryLink', 'north', top, 'south', -90)
bridge = attach('bridge', 'I12_BridgeLink', 'north', gallery, 'south', -90)
court = attach('court', 'I11_CourtyardTransition', 'north', bridge, 'south', -90)
attach('upper_alcove', 'I13_ServiceAlcove', 'south', court, 'south', 90)
attach('upper_room', 'I06_SideExitRoom', 'south', court, 'west')
used = {tuple(v) for c in connections for v in c.values()}
caps = []
for p in list(placements):
    if p['asset'].startswith('F'):
        continue
    for local in by_name[p['asset']]['ports']:
        if (p['id'], local['name']) in used:
            continue
        target = port(p, local['name'])
        normal = target['normal']
        angle = {(0, 1, 0): 0, (1, 0, 0): -90, (0, -1, 0): 180, (-1, 0, 0): 90}[tuple(normal)]
        cap = place('cap_' + p['id'] + '_' + local['name'], 'Z01_PortalClosure', target['position'], angle)
        caps.append({'port': [p['id'], local['name']], 'placement': cap['id']})

manifest = {'version': 1, 'units': 'one Blender unit targets one Roblox stud; calibrate importer',
            'axes': 'X across, +Y inward, Z up; glTF converts to X,Z,-Y',
            'assets': records, 'assembly': {'placements': placements, 'connections': connections, 'caps': caps},
            'frontage_sources': {k: v for k, v in by_name.items() if k.startswith('F')},
            'navigation_envelope': {'radius': 1.9, 'height': 9.5, 'step_clearance': 1.6},
            'note': 'Sample assembly and previews only. No city or gameplay integration.'}
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(OUT / 'export_hashes.json').write_text(json.dumps({p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((OUT / 'exports').iterdir())}, indent=2) + '\n')

# Review staging is excluded from all per-asset exports.
scene = bpy.context.scene
scene.render.engine = 'CYCLES'; scene.cycles.samples = 24
scene.render.resolution_x = 1800; scene.render.resolution_y = 1300; scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.23, .27, .32, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .6
for loc, energy, size in [((70, -40, 160), 280000, 130), ((340, 35, 130), 200000, 100)]:
    data = bpy.data.lights.new('Review_area', 'AREA'); data.energy = energy; data.shape = 'DISK'; data.size = size
    ob = bpy.data.objects.new('Review_area', data); kit.REVIEW.objects.link(ob); ob.location = loc
for name, target, location, scale in [('catalogue', (78, 78, 4), (210, -115, 215), 290), ('connected_cutaway', (275, 42, 9), (430, -130, 220), 185)]:
    data = bpy.data.cameras.new(name); data.type = 'ORTHO'; data.ortho_scale = scale
    camera = bpy.data.objects.new(name, data); kit.REVIEW.objects.link(camera); camera.location = location
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    if '--render' in sys.argv:
        for a in kit.ASSETS:
            for ob in a['roof_objects']:
                ob.hide_render = True
        kit.LIB.hide_render = name != 'catalogue'
        assembly.hide_render = name == 'catalogue'
        scene.render.filepath = str(OUT / (name + '.png')); bpy.ops.render.render(write_still=True)
kit.LIB.hide_render = False; assembly.hide_render = False
for a in kit.ASSETS:
    for ob in a['roof_objects']:
        ob.hide_render = False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'lower_layer_circulation_kit_v1.blend'))
print('CIRCULATION_GENERATED', len(records), 'assets', sum(a['triangles'] for a in records), 'triangles')
