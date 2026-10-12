"""Separate overlapping same-facing box surfaces; retain independent collision.
Smaller architectural details keep priority over the broad backing surface.
"""

def conflicts(parts, tolerance=.002):
    faces = {}
    for index, part in enumerate(parts):
        if not part['visible']:
            continue
        for axis in range(3):
            for sign in (-1, 1):
                plane = part['center'][axis] + sign * part['size'][axis] / 2
                # Adjacent buckets are checked to avoid rounding-boundary misses.
                bucket = round(plane / tolerance)
                for adjacent in (bucket - 1, bucket, bucket + 1):
                    for other_index, other_plane in faces.get((axis, sign, adjacent), []):
                        if abs(plane - other_plane) >= tolerance:
                            continue
                        other = parts[other_index]
                        if all(min(part['center'][k] + part['size'][k] / 2, other['center'][k] + other['size'][k] / 2)
                               - max(part['center'][k] - part['size'][k] / 2, other['center'][k] - other['size'][k] / 2) > tolerance
                               for k in range(3) if k != axis):
                            yield other_index, index, axis, sign
                faces.setdefault((axis, sign, bucket), []).append((index, plane))


def separate(parts):
    before = len(list(conflicts(parts)))
    changed = set()
    for iteration in range(60):
        pairs = list(conflicts(parts))
        if not pairs:
            return {'coplanar_pairs_before': before, 'coplanar_pairs_after': 0,
                    'adjusted_visuals': len(changed), 'iterations': iteration}, changed
        adjustments = set()
        for a, b, axis, sign in pairs:
            def priority(index):
                p = parts[index]
                area = 1
                for k in range(3):
                    if k != axis:
                        area *= p['size'][k]
                return area, index
            loser = max((a, b), key=priority)
            adjustments.add((loser, axis, sign))
        for index, axis, sign in adjustments:
            part = parts[index]
            inset = min(.012, part['size'][axis] * .15)
            assert inset > .0021, ('Cannot safely separate thin surface', part['name'])
            part['center'][axis] -= sign * inset / 2
            part['size'][axis] -= inset
            changed.add(index)
    raise AssertionError('Surface separation did not converge')
