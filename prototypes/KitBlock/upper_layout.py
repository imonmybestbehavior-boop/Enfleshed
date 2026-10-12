"""Explicit upper habitation placements for the already-tested KitBlock only."""
REMOVED_CAPS = {'cap_upper_room_north', 'cap_upper_room_east'}


def extend(placements):
    result = [p for p in placements if p['id'] not in REMOVED_CAPS]
    def add(label, asset, origin, angle=0):
        result.append({'id': label, 'asset': asset, 'origin': list(origin), 'angle': angle})
    add('rear_lane_link', 'I12_BridgeLink', (10, 102, 0), -90)
    add('return_lower_flight', 'I07_StairFlight', (34, 102, 0), -90)
    add('return_half_landing', 'I08_ReturnLanding', (66, 96, 9), -90)
    add('return_upper_flight', 'I07_StairFlight', (66, 90, 9), 90)
    add('return_top_corner', 'U05_ReturnCorner', (34, 90, 18), 90)
    add('inhabited_bridge', 'U03_BridgeApartment', (-3, 66, 18), -90)
    add('residential_gallery', 'U04_OffsetGalleryLanding', (29, 58, 18))
    add('upper_apartment_entry', 'U02_RecessedApartmentEntry', (-9, 82, 18))
    # Window tiers replace the former thin rectangle windows on the blank masses.
    for p in placements:
        if not p['asset'].startswith('F'):
            continue
        offsets = (-6, 6) if p['asset'] == 'F08_ThroughPassage' else (0,)
        for level in (18, 36):
            for index, offset in enumerate(offsets):
                sign = -1 if p['angle'] == 180 else 1
                origin = (p['origin'][0] + sign * offset, p['origin'][1] - sign * 2, level)
                add(p['id'] + '_apartment_%d_%d' % (level, index), 'U01_ApartmentWindowBay', origin, p['angle'])
    add('vestibule_roof_home', 'U06_RoofAddition', (-1, 26, 36))
    add('east_roof_home', 'U06_RoofAddition', (45, 52, 36))
    add('roof_edge_west', 'U07_RoofParapet', (-1, 38, 36))
    add('roof_edge_east', 'U07_RoofParapet', (45, 64, 36))
    add('west_overhead_corbel', 'U08_SteppedCorbel', (-58, 22, 36))
    add('east_overhead_corbel', 'U08_SteppedCorbel', (82, 102, 36))
    add('west_ancient_tie', 'U09_AncientTie', (-58, 24, 36))
    add('east_ancient_tie', 'U09_AncientTie', (82, 104, 36))
    return result


CONNECTIONS = [
    {'a': ['upper_room', 'east'], 'b': ['inhabited_bridge', 'south']},
    {'a': ['inhabited_bridge', 'north'], 'b': ['residential_gallery', 'west']},
    {'a': ['residential_gallery', 'north'], 'b': ['return_top_corner', 'west']},
    {'a': ['return_top_corner', 'south'], 'b': ['return_upper_flight', 'north']},
    {'a': ['return_upper_flight', 'south'], 'b': ['return_half_landing', 'south_right']},
    {'a': ['return_half_landing', 'south_left'], 'b': ['return_lower_flight', 'north']},
    {'a': ['return_lower_flight', 'south'], 'b': ['rear_lane_link', 'north']},
    {'a': ['upper_room', 'north'], 'b': ['upper_apartment_entry', 'south']},
]


def structure(part, group):
    """Supporting masses remain clear of the verified circulation envelopes."""
    for name, center in [('VestibuleUpperStorey', (-1, 32, 27)), ('EastUpperStorey', (45, 58, 27))]:
        part(group, name, center, (12, 12, 18), 'Plaster', True)
    part(group, 'WestSuspendedBearing', (-26, 25, 35), (76, 4, 2), 'Masonry', True)
    part(group, 'EastSuspendedBearing', (56, 105, 35), (64, 4, 2), 'Masonry', True)
    # Partial overhead structures leave glimpses of the apartment tiers and the
    # ancient ceiling. The existing ground floors and street widths stay intact.
    for x in (-52, -14, 6):
        part(group, 'StreetCrossSpan', (x, -8, 23), (6, 18, 2), 'Masonry', True)
