# Phase A — city-wide compression rollout

> Superseded layout details: see [Phase A hive topology](PHASE_A_HIVE_TOPOLOGY.md) for the current routes and Studio test procedure.


> The subsequent [interior circulation pass](PHASE_A_INTERIOR_CIRCULATION.md) turns the detailed buildings into a connected playable network. Its current counts and playtest procedure supersede the shallow-interior limitations below.

The approved pilot is now extended throughout the existing Phase A neighborhood: **X −675…675, Z 350…1750** (1,350 × 1,400 studs of architectural coverage). This is not Phase B. Existing topology, streets, eight through-buildings, stairs, upper routes, underground passages, enclosure, visible paving and hidden safety support are retained.

## Result

- **47 detailed buildings:** 10 approved commercial models and 37 approved residential tenements, including the original two pilot buildings. The 45 new placements cover all four quadrants and recruit-side streets. Models are rotated/translated without scaling or source-asset edits.
- **Five new enclosed cross-street residences**, in addition to the original pilot overbuilds. Their ends bear on paired buildings. Placement rejects conflicts with existing elevated collision geometry.
- Outside the preserved pilot, the old infill is replaced with tighter occupied footprints and upper habitation. Existing 16-stud inter-column gaps narrow to roughly nine studs; ordinary 16-stud row gaps narrow to roughly ten. Route reservations, shafts, landmarks and spawn clearances override expansion. Junctions and stoop approaches remain wider where needed.
- New tenements retain their stone stoops, raised halls and residential façade rhythm. Commercial buildings retain four unequal recessed shop bays, framed displays and real front rooms. These are shallow interiors; upstairs apartments remain inaccessible.
- The rejected legacy storefront generator is no longer used by Phase A. Its source remains for historical tests, but its openings, signs and arbitrary furnishings are absent from the active assembly. Safe commercial-room metadata is supplied to the existing population system; population caps and behavior are unchanged.
- **3,570 new manifest Parts**, plus the cloned buildings. The 47 static models contain 29,150 Parts in total. These are component counts, not the complete runtime world's Part count. `LowerLayerGraybox.PartCount` remains the authoritative assembled total. Runtime streaming settings are unchanged; performance still needs Studio measurement.

## Files

- Added `src/server/Development/LowerLayer/CityCompression.luau`: deterministic building fits along existing routes, full footprint reservations, clipped dense infill, supported overhead rooms and safe commercial homes. No new road graph.
- Modified `src/server/Development/LowerLayer/PhaseA.luau`: assembles the rollout, retains the original pilot, clones approved models, replaces legacy fronts and publishes rollout counts.
- Extended `tests/test_compression_pilot.py`: checks the actual city-wide manifest and every placed static building against route/stair/spawn clearance, shop doors, stoops, halls, merchant homes and visible supporting collision floors; also guards against shrinking coverage back to a single cluster.
- Updated `PHASE_A_COMPRESSION_PILOT.md` with the rollout pointer; added this report.
- Rebuilt `Enfleshed.rbxlx`.

The source prototypes, default project mappings, route configuration, combat, AI, events, population implementation, navigation and streaming configuration are unchanged by this rollout.

## Validation

Passed: source formatting, all 13 Lua test scripts, four city geometry tests, Rojo 7.7.0 build, three place-reference/source checks and whitespace checks. The geometry tests use actual transformed source models, including rotated stoop rails, and a spatial index to keep full-city checks bounded. All 67 graph connections remain unchanged. Legacy geometry tests still print their historical baseline estimates; those are not current world totals.

An offline Blender street view was inspected as an architectural check. It is not a Studio screenshot and does not reproduce game lighting, streaming, physics or navigation. Actual chase behavior, visual feel, streaming and multiplayer frame times remain manual Studio checks.

## Studio playtest

1. Stop Play and reopen the rebuilt main `Enfleshed.rbxlx` (not either standalone building study), or sync the current project before starting a fresh session. During Play, `Workspace.LowerLayerGraybox.CityCompression` should contain **45 models**; `CompressionPilot` contains the original two. The root attribute `CityCompressionBuildingCount` should read **47**.
2. Leave the recruit/barracks area. Inspect the residential frontage around **X −224, Z 1624** and **X −156, Z 1424**, then the commercial building near **X 32, Z 1476**. The spawn room itself is deliberately preserved.
3. Traverse the cross-city streets at **Z 1400**, **Z 1000**, and **Z 600**, on both sides of the avenue. Visit the southern street near **X 108, Z 426**. Changes should be apparent throughout this circuit, not only near the old pilot at Z 1100.
4. Enter several shop bays, climb tenement stoops, and back out into the street. Check recessed doors, floor joins, camera clearance and whether entrances read naturally. Inspect the nine/ten-stud inter-block lanes for accidental dead ends or snagging.
5. Run Nascent chases through streets, narrow lanes, existing through-buildings and upper/underground routes. Confirm spawn events and ambient humans still function. Compare crowded combat streets with the retained pilot release.
6. Test with two clients and an active enemy wave. Watch frame time, replication/loading delays and navigation hesitation as buildings stream in. This rollout increases detailed geometry substantially; static tests cannot establish acceptable live performance.

No Phase B work is included.
