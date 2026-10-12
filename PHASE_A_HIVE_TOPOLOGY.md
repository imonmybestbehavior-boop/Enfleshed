# Phase A — Kowloon / hive topology pass

The main place now uses irregular surface circulation and bent inter-building passages. The old pilot street geometry and route-aligned building placement assumptions are retired. The 47 detailed commercial/tenement buildings remain functional architectural anchors; occupied extensions and irregular infill now shape circulation around them.

## Implemented layout

- Same neighborhood extent: visible ground roughly X −700..700 / Z 350..1750; dense building fabric X −675..675. No Phase B expansion.
- 36 rebuilt surface edges, with clear widths varying from 8 to 24 studs. Individual sections alternate between alley, covered passage, service passage, enclosed room and court.
- 28 substantial occupied building extensions occupy former straight routes. They are placed before routing, so routes must go around architecture.
- 27 bent side branches and 12 additional rejoining bypasses. Seven clear side branches rise three studs over six ordinary steps to a small landing.
- 114 entrance approaches connect the actual commercial doors and residential stoops to the irregular network.
- All 47 detailed buildings still connect through 91 upper links, retaining 45 logical graph cycles. Both connection floors, Y36.5 and Y52.5, serve every building. Shared stairs/rooms continue up to Y68.5.
- Upper link widths vary from 8 to 18 studs. Their geometry alternates enclosed halls/rooms with guarded balconies and bridges. Existing catwalk crossings remain open through new masses.
- The 36 surface edges and 91 detailed-building links contain 1,529 authored segments; the longest is 76 studs, including the approaches through the older eight buildings. This is a segment-length measurement, **not** a maximum visual sightline.
- Infill no longer reserves a district-wide lattice of straight 16-stud escape lanes. Explicit route reservations, variable setbacks, shared corners and occupied wings determine the streets.
- Visible floors and hidden ground supports remain; intentional maintenance shafts, the underground level and the ancient enclosure remain.

## Files in this pass

| File | Purpose |
| --- | --- |
| `src/shared/Configuration/PhaseATopology.luau` | Generated surface route points, per-section widths/spaces, extensions, branches and relocated surface spawn anchors. Existing gameplay node identities remain. |
| `src/server/Development/LowerLayer/BuildingSites.luau` | Stable placement data for the 45 city buildings beyond the original two study placements. Separates building anchors from obsolete straight-road fitting. |
| `scripts/hive_routing.py` | Bounded offline route search that tracks direction and run length. No runtime pathfinding dependency. |
| `scripts/build_hive_surface.py` | Reproducible structural surface layout, entrance connections, local bypasses and safe raised-branch selection. |
| `scripts/build_building_connections.py` / `BuildingConnections.luau` | Rebuild the existing 91-link graph as bent passages with width and space metadata. |
| `scripts/export_building_placements.lua` | Exports the current fixed building anchors. |
| `RouteGeometry.luau` | Visible floors, short stairs, room/passage shells, occupied wings and openings at existing elevated crossings. |
| `InfillLayout.luau` / `CityCompression.luau` | Irregular, nonoverlapping lots and occupied masses subordinate to real routes and door approaches. |
| `BuildingCirculation.luau` | Variable-width upper passages, ceilings/guards, open intersections and preserved old catwalk connections. |
| `PhaseA.luau` | Assemble the new layout, expose verification attributes and deduplicate fixtures as the number of route sections increases. |
| `src/client/Controllers/NavigationController.luau` | Draw actual route polylines and branches instead of straight node-to-node map lines. |
| `src/server/Services/CityPopulationLayout.luau` | Place existing population slots using actual segment widths and shorter usable segments. Population count, behavior and event budgets are unchanged. |
| `tests/test_hive_topology.lua` | New layout bounds, segment lengths, width/space variety and branch/elevation checks. |
| `tests/test_compression_pilot.py` | Full-scene door, route, stair, spawn, population-home and branch clearance/floor checks. |
| `tests/test_housing_infill.lua`, `test_phase_a_geometry.lua`, `test_street_frontage.lua`, `test_assignments.lua` | Validate the current layout rather than obsolete pilot/streetfront assumptions; preserve density, connectivity, reserve and clearance checks. |
| `docs/previews/hive-*-plan.png` | Offline ground-level architectural cutaways. Upper floors are removed for inspection; these are not Studio screenshots or lighting previews. |
| `Enfleshed.rbxlx` | Rebuilt main Studio place. The standalone study places are not the updated city. |

Runtime gameplay, damage, magic, enemy behavior, population/event logic and progression were not changed by this pass. Other pre-existing work in the repository remains in place.

## Validation

Passed StyLua checks, 14 Lua test scripts, four full-scene geometry tests, Python syntax checks, Rojo 7.7.0 build, three built-place reference/source checks, and `git diff --check`.

The geometry harness checked **49,805 positions** against **56,232 collidable geometry fragments**, using an approximately four-stud-wide, nine-stud-high navigation envelope and floor support checks. This fragment count excludes noncolliding visual parts, lights, enclosure and some runtime objects; `Workspace.LowerLayerGraybox.PartCount` remains the authoritative assembled count.

An offline horizontal sightline probe sampled 425 surface-route positions at Y5 in eight directions, capped at 300 studs. The median of the longest direction per position was about 104 studs; the 90th percentile was 218 studs. Junctions, clear combat areas and some overlapping passages still allow longer views. The older elevated trunks and maintenance routes also retain longer sections. The pass does not claim that every view is short or that every retained route has been replaced.

Studio is unavailable here. Live navigation, character step handling, streamed collision, lighting, startup cost, frame time and the actual feeling of a chase require Studio playtesting. Geometry increased from the previous pass; no performance claim is inferred from offline tests.

## Studio playtest

1. Stop Play and open the rebuilt **main `Enfleshed.rbxlx`** (not `Enfleshed_FacadeStudy`, `Enfleshed_TenementStudy` or `Enfleshed_StorefrontPilot`). Start a fresh session so the city regenerates from the new source.
2. In `Workspace.LowerLayerGraybox`, verify `CompressionPilotStatus = HiveTopology`, `HiveOccupiedExtensions = 28`, `HiveSideBranches = 39`, `HiveRejoiningBranches = 12`, `InteriorConnectedBuildings = 47`, and `InteriorConnections = 91`. Check Output for errors.
3. From the recruit area, move toward Z1400 and then Z1200. The route should repeatedly offset and alternate narrow/covered/wider sections. Press M: map lines should follow those bends.
4. Near X−156 / Z1424, use a tenement stoop (doors around X−179 and −135 / Z1411). Enter, follow the shared stair, climb two flights, and use the upper side gallery. Follow its turns into a different building, then descend and exit onto another ground route. Repeat on the next connection floor.
5. Explore branches and raised alcoves. Confirm all normal entrances and turns have visible floors, steps need no precision jump, and side branches can be exited. Check that wider rooms do not expose the whole next route.
6. Lead a Nascent through a ground bypass, a doorway and an interior stair. Test whether obstacles conceal what comes next without trapping the enemy or player. Pay particular attention to widened junctions and longer legacy routes.
7. Test two clients and increasing enemy waves. Check load time, frame time, streaming and crowd movement. Revisit assignment/event locations and underground entrances. Record `PartCount` and any specific sticking coordinates.

No Phase B work is included. Manual Studio validation is the next step.
