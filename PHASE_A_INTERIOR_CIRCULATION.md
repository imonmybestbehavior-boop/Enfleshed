# Phase A — connected building interiors

> Superseded layout details: see [Phase A hive topology](PHASE_A_HIVE_TOPOLOGY.md) for the current routes and Studio test procedure.


The street-facing architecture now contains a playable interior network across the district. **All 47 detailed buildings** have shared ground-floor circulation and four stair flights. **91 inter-building links** connect galleries at **Y 36.5 and Y 52.5**. Every building has an actual connection at both heights; no upper portal is opened without a destination.

The lower tier connects the entire set of buildings. The upper tier supplies alternate local routes. The connection graph has 45 independent cycles mathematically; that is a graph metric, not a claim of 45 separate physical corridors—shared corridor segments are merged.

## Reference and architectural direction

The architectural account in [City of Darkness Revisited](https://www.archdaily.com/493900/the-architecture-of-kowloon-walled-city-an-excerpt-from-city-of-darkness-revisited) describes adapted stairs and corridors crossing between properties at several levels. [M+ documents the connected rooftop environment](https://www.mplus.org.hk/en/magazine/exploring-kowloon-walled-city-photographic-journey/). The design response here is interconnected circulation inside occupied building volumes, rather than just a dense exterior silhouette. It is an Enfleshed interpretation, not a reconstruction of Kowloon.

## What is physically different

- Residential inner doors and sealed hall ends are removed. Both stoops feed a shared passage and stair.
- Commercial entrances still open into distinct shop bays, but those bays now connect behind the frontage and lead upstairs.
- Four return stair flights in every detailed building reach intermediate floors and the upper rooms at Y 68.5. Stairs have eight-stud treads across their width, 1.5-stud tread depth, and rises below 0.67 studs. Floor openings, return landings and guards surround the stairs.
- The three rebuilt upper floors each contain two simple rooms with real partitions and framed openings beside a gallery. These remain unfurnished prototype interiors.
- Party-wall openings lead into covered, approximately ten-stud-clear passages. These penetrate old solid block masses or cross narrow gaps between buildings. Their floors and ceilings are merged where paths overlap, and junctions are cut open rather than capped by intersecting walls.
- Existing streets, objective locations, through-buildings and roof/underground routes remain usable. They were retained where compatible; old solid geometry is explicitly cut away wherever the new circulation needs space. Existing catwalk crossings receive openings.
- Visible geometry and collision are altered together. New circulation uses visible solid floors, not invisible traversal bridges. The underground enclosure and development safety supports remain.
- Interior and passage fixtures are deduplicated and capped at 320 additional lights. No new NPC, combat, event, progression or population behavior was added.

The 47 detailed street buildings are functional; other background/infill masses are not fully modeled apartment buildings. Passages cut through those masses where the circulation network needs them. Upper rooms beyond the new accessible floors remain background architecture. The existing navigation display does not yet draw these added interior links.

## Implementation files

Added:

- `BuildingCirculation.luau`: pure geometry for shared halls, stairs, rooms, floor openings, passage shells and walkability samples.
- `SolidClipping.luau`: axis-aligned solid subtraction and a spatial index shared by assembly and tests. No runtime CSG unions.
- `BuildingCirculationRuntime.luau`: validates placement data, removes sealed prototype internals, cuts visible/collision geometry, constructs circulation, updates Part counts and adds bounded lighting.
- `BuildingConnections.luau`: fixed, inspectable building placement and link data. Routing is calculated offline, not repeatedly during gameplay.
- `scripts/export_building_placements.lua`: exports the current authoritative building placements and protected existing interiors.
- `scripts/build_building_connections.py`: regenerates the connection data from those placements, protecting stairs and existing through-buildings. Requires only the existing Python and Lua tools.
- This report.

Modified:

- `PhaseA.luau`: passes the actual placed models to the circulation assembly after the existing world is built.
- `tests/test_compression_pilot.py`: verifies the revised complete collision scene using the same clipping and source-part removal code as runtime. Checks both old and new circulation, visible supporting floors, all source-building entrances, spawn points, every new stair flight, connectivity, placement consistency and that every upper exit has a destination.
- `PHASE_A_CITY_COMPRESSION.md`: points to this newer interior pass.
- `Enfleshed.rbxlx`: rebuilt main place.

The standalone facade and tenement study assets remain architectural source models. Their transformations into functional interiors happen in the main place; opening a standalone study will still show the original study.

To regenerate after changing placements:

```sh
python3 scripts/build_building_connections.py
stylua src/server/Development/LowerLayer/BuildingConnections.luau
python3 tests/test_compression_pilot.py
rojo build default.project.json -o Enfleshed.rbxlx
```

Runtime validates the placement list against connection data so stale paths fail explicitly instead of silently connecting the wrong buildings.

## Validation and limits

Formatting, all 13 Lua test scripts, four city-wide geometry tests, Python syntax checks, Rojo 7.7.0 build, three place-reference/source checks and whitespace validation were run. The geometry checks use a four-stud-wide, nine-stud-high clearance envelope matching the configured enemy navigation size. They test floor support as well as obstruction, including the old routes and new stairs/rooms/links.

An offline architectural section was inspected. It removes exterior surfaces to show the interior and does not represent Studio lighting or a live Roblox test. The runtime `LowerLayerGraybox.PartCount` remains the authoritative assembled count. This pass increases geometry; startup time, streaming, live navigation and frame time require Studio measurement.

## Studio test circuit

1. Stop Play, reopen/sync the rebuilt **main Enfleshed.rbxlx**, and start a fresh session. Check Output for any placement-data assertion. On `Workspace.LowerLayerGraybox`, expect `InteriorConnectedBuildings = 47`, `InteriorConnections = 91`, and `InteriorCirculationLevels = "36.5, 52.5"`.
2. From the recruit area, use the cross street at **Z 1400**. The tenement centered around **X −156, Z 1424** faces this street; its front stoops are near **X −179 and −135, Z 1411**.
3. Enter either stoop. Continue through the hall to the transverse passage, turn toward the shared stair, and ascend two flights. Follow the side gallery into a connecting passage. Enter another building and descend to a different street entrance.
4. Repeat using the next floor's connection to create a different return route. Try entering through a commercial bay, climbing inside, and exiting through a residential building.
5. Walk into the small upper rooms. Check doorway width, stair guards, headroom, floor joins, lighting and whether turn choices are readable. No jumping should be required for these interior routes.
6. Lead a Nascent through an entry and up the stairs. Test turning at landings and corridor junctions, then disengage through a different building. Static geometry checks do not prove Roblox's navigation mesh follows the whole circuit.
7. Repeat with two clients and a wave active. Check frame time, startup/loading time and streamed floor availability. Revisit existing objective buildings, catwalks and underground stairs to verify the original gameplay loop still works.

No Phase B work is included.
