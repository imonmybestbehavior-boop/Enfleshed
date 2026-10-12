"""Bounded offline rectilinear routing with limited uninterrupted runs.
Shared by surface and inter-building layout generation; never runs in Roblox.
"""
import heapq
import math

STEP = 8
DIRECTIONS = ((1, 0), (0, 1), (-1, 0), (0, -1))


def simplify(points):
    result = []
    for p in points:
        if result and p == result[-1]:
            continue
        if len(result) > 1 and (
            result[-2][0] == result[-1][0] == p[0]
            or result[-2][1] == result[-1][1] == p[1]
        ):
            result.pop()
        result.append(p)
    return result


def find_route(start, goal, clear, min_run=2, max_run=None):
    """Search direction/run states so a shortest route cannot become a long hall."""
    initial = (start[0], start[1], -1, 0)
    queue = [(0, 0, initial)]
    costs = {initial: 0}
    parents = {}
    while queue:
        _, cost, state = heapq.heappop(queue)
        if cost != costs[state]:
            continue
        x, z, heading, run = state
        if (x, z) == goal:
            path = [(x, z)]
            while state != initial:
                state = parents[state]
                path.append(state[:2])
            return list(reversed(path))
        limit = max_run or 5 + ((x // 7 + z // 11) % 3)
        near_end = abs(x - goal[0]) + abs(z - goal[1]) <= 2
        for direction, (dx, dz) in enumerate(DIRECTIONS):
            if heading >= 0 and direction == (heading + 2) % 4:
                continue
            if direction == heading and run >= limit:
                continue
            if direction != heading and heading >= 0 and run < min_run and not near_end:
                continue
            cell = (x + dx, z + dz)
            if not clear(cell):
                continue
            following = (*cell, direction, run + 1 if direction == heading else 1)
            # A weak spatial preference breaks repeated staircase patterns.
            extra = ((cell[0] // 5 * 17 + cell[1] // 7 * 13) % 7) * 0.025
            total = cost + 1 + extra + (0.15 if direction != heading else 0)
            if total < costs.get(following, math.inf):
                costs[following] = total
                parents[following] = state
                heuristic = abs(cell[0] - goal[0]) + abs(cell[1] - goal[1])
                heapq.heappush(queue, (total + heuristic, total, following))
    raise RuntimeError(f'No bounded-run route between {start} and {goal}')
