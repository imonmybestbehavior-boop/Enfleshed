"""Upper Habitation + Roof Infill: bounded, stud-authored Lower Layer kit."""
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lower_layer_circulation_common as kit

OUT = kit.ROOT / 'assets/blender/generated/lower_layer_habitation_kit_v1'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
kit.ASSETS.clear()  # Also support rerunning from Blender's text editor.
kit.CURRENT = None
kit.initialize(OUT)
kit.LIB.name = 'LOWER_LAYER_HABITATION_V1'
B, S, R = kit.box, kit.socket, kit.route


def window(x, y, bottom=4, width=3, height=6, variant=0):
    # Deep timber reveal, grouped opaque panes and a real sill/header.
    B('window_reveal', (x, y + .08, bottom + height / 2), (width + .4, .48, height + .5), 'Timber', False)
    B('window_glass', (x, y - .19, bottom + height / 2), (width, .08, height), 'Glass', False)
    for edge in (-1, 1):
        B('window_jamb', (x + edge * (width / 2 + .12), y - .22, bottom + height / 2), (.24, .42, height + .5), 'PaintedTimber', False)
    B('window_mullion', (x + (.3 if variant else -.2), y - .27, bottom + height / 2), (.16, .22, height), 'PaintedTimber', False)
    B('window_sill', (x, y - .3, bottom - .22), (width + .9, .9, .35), 'CutStone', False)
    B('window_header', (x, y - .22, bottom + height + .3), (width + .65, .65, .4), 'CutStone', False)
    B('window_transom', (x, y - .29, bottom + height * .72), (width, .2, .16), 'Timber', False)


def side_window(x, y, inward):
    # Same recessed frame language as the frontal apartment bay, turned sideways.
    B('side_reveal', (x, y, 7), (.25, 4.9, 6.5), 'Timber', False)
    B('side_glass', (x + inward * .17, y, 7), (.07, 4.5, 6), 'Glass', False)
    for sign in (-1, 1):
        B('side_jamb', (x + inward * .23, y + sign * 2.37, 7), (.4, .24, 6.5), 'PaintedTimber', False)
    B('side_mullion', (x + inward * .27, y + .35, 7), (.24, .16, 6), 'PaintedTimber', False)
    B('side_transom', (x + inward * .28, y, 8.6), (.24, 4.5, .16), 'Timber', False)
    B('side_sill', (x + inward * .28, y, 3.78), (.85, 5.3, .35), 'CutStone', False)
    B('side_header', (x + inward * .24, y, 10.3), (.65, 5.1, .4), 'CutStone', False)


def frame(x, y, width=8):
    for side in (-1, 1):
        B('door_jamb', (x + side * (width / 2 + .16), y, 6), (.32, .8, 12), 'CutStone')
    B('door_lintel', (x, y, 12.35), (width + .8, .9, .6), 'CutStone')
    B('door_transom', (x, y + .15, 13.3), (width, .22, 1), 'Timber', False)


def end_wall(y, width, opening=8, offset=0):
    left, right = -width / 2, width / 2
    for a, b in ((left, offset - opening / 2), (offset + opening / 2, right)):
        if b > a:
            B('end_pier', ((a + b) / 2, y, 9), (b - a, .6, 18), 'Plaster')
    B('end_header', (0, y, 15), (width, .6, 6), 'Plaster')
    frame(offset, y, opening)


def slab(width, depth, roof=True):
    B('continuous_floor', (0, depth / 2, -.3), (width, depth, .6), 'CutStone', role='floor')
    if roof:
        B('ceiling', (0, depth / 2, 13.55), (width, depth, .6), 'Masonry', section='roof', role='ceiling')


kit.asset('U01_ApartmentWindowBay', 12, 2, 'facade', 'Grouped residential windows and masonry apron; non-enterable frontage layer.')
B('backing_wall', (0, 1, 9), (12, 2, 18), 'Plaster')
for x, width, variation in ((-3.1, 2.6, 0), (2.2, 3.4, 1)):
    window(x, -.18, 4, width, 6.5, variation)
B('bed_course', (0, -.13, 1), (12, .5, .5), 'Masonry', False)
B('head_course', (0, -.2, 16.5), (12, .65, .5), 'CutStone', False)
S('mount', (0, 0, 0), (0, -1, 0), walkable=False)

kit.asset('U02_RecessedApartmentEntry', 16, 6, 'interior', 'Recessed residential entry alcove, with closed apartment door at the back.')
slab(16, 6)
end_wall(.3, 16)
for x in (-7.7, 7.7):
    B('side_wall', (x, 3, 9), (.6, 6, 18), 'Plaster')
B('rear_wall', (0, 5.7, 9), (16, .6, 18), 'RepairPlaster')
B('apartment_door', (1.2, 5.31, 5), (4.6, .18, 10), 'PaintedTimber', False)
for x in (-1.3, 3.7):
    B('door_rear_frame', (x, 5.16, 5), (.24, .35, 10.4), 'Timber', False)
B('door_rear_header', (1.2, 5.16, 10.25), (5.2, .35, .35), 'Timber', False)
B('recessed_handle', (2.8, 5.03, 4.6), (.12, .16, .8), 'Iron', False)
S('south', (0, 0, 0), (0, -1, 0)); R('entry', [(0, 0, 0), (0, 3, 0)])

kit.asset('U03_BridgeApartment', 16, 24, 'interior', 'Enclosed through-room built across older structures; two aligned eight-stud portals.')
slab(16, 24)
end_wall(.3, 16); end_wall(23.7, 16)
for x in (-7.7, 7.7):
    B('side_wall', (x, 12, 9), (.6, 24, 18), 'Plaster')
    for y in (6, 16):
        side_window(x + (.35 if x < 0 else -.35), y, 1 if x < 0 else -1)
        side_window(x + (-.35 if x < 0 else .35), y, -1 if x < 0 else 1)
B('built_in_partition', (-5.8, 10, 6), (3.8, .45, 12), 'RepairPlaster')
S('south', (0, 0, 0), (0, -1, 0)); S('north', (0, 24, 0), (0, 1, 0))
R('through_home', [(0, 0, 0), (0, 24, 0)])

kit.asset('U04_OffsetGalleryLanding', 16, 24, 'upper', 'West-to-north offset landing with a residential backing wall.')
slab(16, 24, False)
# West portal y=8, north portal x=-3. All other edges have solid guards.
B('south_guard', (0, .3, 2), (16, .6, 4), 'Masonry')
for y, length in ((2, 4), (18, 12)):
    B('west_guard', (-7.7, y, 2), (.6, length, 4), 'Masonry')
for x, width in ((-7.5, 1), (4.5, 7)):
    B('north_guard', (x, 23.7, 2), (width, .6, 4), 'Masonry')
B('east_backing', (7.7, 12, 9), (.6, 24, 18), 'Plaster')
for y in (6, 15):
    side_window(7.35, y, -1)
    side_window(8.05, y, 1)
B('gallery_cover', (0, 12, 13.55), (16, 24, .6), 'Masonry', section='roof', role='ceiling')
S('west', (-8, 8, 0), (-1, 0, 0)); S('north', (-3, 24, 0), (0, 1, 0))
R('offset_gallery', [(-8, 8, 0), (-3, 8, 0), (-3, 24, 0)])

kit.asset('U05_ReturnCorner', 16, 16, 'upper', 'Mirrored landing joining the inhabited gallery to a stair return.')
slab(16, 16, False)
B('north_guard', (0, 15.7, 2), (16, .6, 4), 'Masonry')
B('east_guard', (7.7, 8, 2), (.6, 16, 4), 'Masonry')
for x in (-6, 6):
    B('south_guard', (x, .3, 2), (4, .6, 4), 'Masonry')
for y in (2, 14):
    B('west_guard', (-7.7, y, 2), (.6, 4, 4), 'Masonry')
S('south', (0, 0, 0), (0, -1, 0)); S('west', (-8, 8, 0), (-1, 0, 0))
R('corner', [(0, 0, 0), (0, 8, 0), (-8, 8, 0)])

kit.asset('U06_RoofAddition', 12, 12, 'roof', 'Closed background dwelling with a patched wall and residential windows; no traversal promise.')
slab(12, 12)
for x in (-5.7, 5.7):
    B('side', (x, 6, 7), (.6, 12, 14), 'RepairPlaster')
for y in (.3, 11.7):
    B('end', (0, y, 7), (12, .6, 14), 'Plaster')
window(-2.6, -.18, 4, 2.8, 5.5, 1)
B('closed_door', (2.7, -.11, 4.8), (3.6, .22, 9.6), 'PaintedTimber', False)
for x in (.7, 4.7):
    B('door_frame', (x, -.23, 4.9), (.22, .3, 9.8), 'Timber', False)
B('roof_cap', (0, 6, 14.2), (12.4, 12.4, .4), 'Zinc', section='roof')
S('mount', (0, 0, 0), (0, -1, 0), walkable=False)

kit.asset('U07_RoofParapet', 12, 1, 'roof', 'Short masonry parapet for closed roof edges.')
B('parapet', (0, .5, 1.6), (12, 1, 3.2), 'Masonry')
B('coping', (0, .5, 3.4), (12.3, 1.25, .4), 'CutStone')
S('mount', (0, 0, 0), (0, -1, 0), walkable=False)

kit.asset('U08_SteppedCorbel', 12, 6, 'support', 'Masonry wall-mounted corbel carrying an overhead human platform.')
B('wall_spine', (0, 5, 6), (12, 2, 12), 'Masonry')
for y, depth, z in ((4, 4, 5), (3, 6, 8), (3, 6, 11)):
    B('bearing_course', (0, y, z), (12, depth, 2), 'CutStone')
S('wall_mount', (0, 6, 0), (0, 1, 0), walkable=False)

kit.asset('U09_AncientTie', 4, 4, 'support', 'Tall structural tie between human construction and the ancient overhead mass.')
B('shaft', (0, 2, 12), (3, 3, 24), 'Masonry')
for z in (1, 23):
    B('seat', (0, 2, z), (4, 4, 2), 'CutStone')
S('base', (0, 0, 0), (0, -1, 0), walkable=False)

records = kit.finish_assets()
catalog_id = 'a3e2c5c0-6b31-48db-a09a-928cae612901'
(OUT / 'blender_assets.cats.txt').write_text('VERSION 1\n' + catalog_id + ':Lower Layer/Habitation:Habitation\n')
for i, a in enumerate(kit.ASSETS):
    a['collection'].asset_data.catalog_id = catalog_id
    a['collection'].asset_data.tags.new('habitation')
    display_index = {3: 6, 6: 3}.get(i, i)  # Keep the low parapet in front of the tall gallery.
    a['root'].location = ((display_index % 3) * 28, (display_index // 3) * 36, 0)
    a['collection'].instance_offset = a['root'].location
(OUT / 'manifest.json').write_text(json.dumps({'version': 1, 'units': 'stud', 'axes': 'X across, +Y inward, Z up', 'assets': records,
    'limitations': ['Closed facade and roof dwellings are explicitly non-traversable.', 'Studio physics and final mesh import require separate verification.']}, indent=2) + '\n')
(OUT / 'export_hashes.json').write_text(json.dumps({p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((OUT / 'exports').iterdir())}, indent=2) + '\n')
scene = bpy.context.scene
scene.world = bpy.data.worlds.new('Review'); scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.24, .27, .31, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .6
light = bpy.data.lights.new('ReviewLight', 'AREA'); light.energy = 120000; light.shape = 'DISK'; light.size = 80
ob = bpy.data.objects.new('ReviewLight', light); kit.REVIEW.objects.link(ob); ob.location = (20, -20, 100)
cam = bpy.data.cameras.new('Catalogue'); cam.type = 'ORTHO'; cam.ortho_scale = 125
ob = bpy.data.objects.new('Catalogue', cam); kit.REVIEW.objects.link(ob); ob.location = (135, -130, 150)
ob.rotation_euler = (Vector((28, 44, 8)) - ob.location).to_track_quat('-Z', 'Y').to_euler(); scene.camera = ob
scene.render.engine = 'CYCLES'; scene.cycles.samples = 24; scene.cycles.use_denoising = True
scene.render.resolution_x = 1500; scene.render.resolution_y = 1200; scene.render.resolution_percentage = 100
if '--render' in sys.argv:
    scene.render.filepath = str(OUT / 'catalogue.png'); bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'lower_layer_habitation_kit_v1.blend'))
print('HABITATION KIT:', len(records), 'assets;', sum(a['triangles'] for a in records), 'triangles')
