# Phase A compression — first validation cluster

> Historical pilot report. The approved approach has now been extended across Phase A; see [PHASE_A_CITY_COMPRESSION.md](PHASE_A_CITY_COMPRESSION.md) for the current rollout, counts and playtest circuit.

## Scope and stopping point

This is the first controlled cluster, **not a city-wide replacement**. Its bounds are X −330…80, Z 985…1310, around S3/S4, M1/M2 and HousingThroughA (B3). The rest of Phase A retains its existing geometry approach. Wider propagation is deliberately deferred until manual Studio visual and chase testing approves this cluster.

The topology remains authoritative: all **67 existing connections**, node positions, through-buildings, stairs, upper routes, underground connections and spawn candidates are preserved. `PhaseATopology`, `RouteGeometry`, `InfillLayout`, gameplay, events, population services and navigation logic were not changed.

## What changed

Four infill lots are replaced locally. Connected residential/commercial block backs occupy previously unassigned pavement around the existing passages. Their footprints are clipped against building, route and spawn-clearance reservations, the two approved prototype footprints, and the combat release. No new road grid is created.

The approved commercial building is placed at façade origin **(−18, 0, 1100)**, facing east. The separate stone-stoop tenement is at **(−140, 0, 1152)**, also facing east toward the service lane. Both models are used without rescaling, editing their source assets, or turning every building into that family. The commercial building retains its real recessed shop bays; the tenement retains domestic windows, basement openings and supported raised entrances.

The older generated storefronts inside this pilot are suppressed, including their merchant-home metadata. This prevents the rejected vague shop openings from overlapping the authored buildings or appearing as valid homes inside newly solid masses. The population service itself and its cap/event reserve remain unchanged; it uses its existing placement fallback. This is not a population rework.

Two enclosed overbuilds connect occupied blocks over the avenue and service lane. They have supporting neighboring masses and floor/soffit structure. A higher service span frames the existing B3 upper route. These additions are **inaccessible habitation/infrastructure**, not new playable bridges or stairs with invented destinations. Existing B3 stairs and U3 catwalks supply the usable vertical route.

Continuous visible ground and hidden safety support remain. The ancient enclosure and distant structure remain untouched. Nothing replaces the map with open sky or removes the development catch floor.

## Validation circuit and purpose

- **S3 → S4:** existing larger street, with commercial frontage and overhead habitation. Its original 34-stud route strip is retained; the wider footprint provides combat space and contrast to the service passages.
- **S4 toward S9:** existing 18-stud normal/side-street route, enclosed by the surrounding blocks.
- **S3 → M1:** compressed side passage into the service network. Its nine-stud route strip remains; surrounding architectural clearance is approximately 13 studs.
- **M1 → M2:** the focused narrow lane; its existing seven-stud route strip now sits in a **nine-stud clear architectural corridor** through the covered section. Endpoints and the centerline are unchanged. Junctions and stoop approaches locally open out.
- **M2 → S4:** completes the existing parallel loop. This gives an escape/bypass when a fight occupies the main avenue; no new encounter script is needed to create that spatial choice.
- **S4 → S9 → B3 → U3:** preserves the through-building and interior stair approach to the existing upper catwalk network. B3 remains a route-producing building, not a decorative room replaced by the tenement.
- **S4 release:** an **83 × 35-stud** reserved clear rectangle, X −32…51 / Z 1000…1035, on existing visible ground. It is a bounded release rather than widening the full avenue.

No new loot, patrol placement, quests, rewards or combat behavior were introduced. Route value here means physical bypass, escape, elevation and existing interconnection; the pilot does not promise new gameplay incentives that have not been implemented.

## Files

Added:

- `src/server/Development/LowerLayer/CompressionPilot.luau`: the one-cluster manifest, four lot replacements, protected cuts, two authored placements and structural overbuilds.
- `tests/test_compression_pilot.py`: loads the actual manifest and static asset geometry and tests existing routes, stair samples, spawn envelopes, shop entry paths, tenement stoops/halls, release clearance and bounded scope.
- `PHASE_A_COMPRESSION_PILOT.md`: this report and validation circuit.

Modified:

- `src/server/Development/LowerLayer/PhaseA.luau`: assembles the local pilot, skips replaced lots/conflicting old fronts, clones the two assets at explicit transforms, and records pilot status/count metadata.
- `default.project.json`: maps the existing two static prototype models into `ServerStorage.CompressionPilotAssets`. Their files and standalone review places are unchanged.
- `Enfleshed.rbxlx`: rebuilt main place.

The `CompressionPilot` folder under `Workspace.LowerLayerGraybox` contains the two authored buildings. The root exposes `CompressionPilotBounds`, `CompressionPilotPartCount` and `CompressionPilotStatus="AwaitingStudioValidation"`. Its runtime `PartCount` includes the cloned asset Parts; older baseline-only test estimates should not be read as a measurement of this revised runtime assembly.

## Checks and manual validation

Passed: StyLua source check, all 13 existing Lua tests, three new pilot geometry tests, Rojo 7.7.0 build, three built-place reference/source tests, and whitespace validation. The new geometry check samples **every existing route**, including upper/underground paths, every emitted stair flight and every authored spawn candidate against the revised collision solids. It also checks the added building entry paths. It does not simulate Roblox navigation meshes, physics, crowd occupancy, streaming or combat.

1. Stop Play and reopen/sync the rebuilt main `Enfleshed.rbxlx`. Use a fresh session. Check Output for asset-loading errors.
2. Follow the main avenue from S3 (0,0,1200) toward S4 (0,0,1000). Inspect the commercial façade, low overbuild, block continuity and sense of enclosure. Assess sightlines at avatar height, not only from a flying camera.
3. Return via S4 → M2 (−120,0,1000) → M1 (−120,0,1200) → S3. Check the covered narrow lane, tenement stoops and whether this feels like a useful escape route. Sprint and dash both directions; look for snagging and accidental dead ends.
4. Follow S4 west toward S9, then the existing route into B3 (−260,0,1200). Walk its stairs to U3, then the catwalk. Check headroom beneath the higher service span and verify that existing upper and underground destinations remain reachable.
5. Fight in and near the S4 release. Compare maneuvering there with the narrow bypass. Test Nascent pursuit and event humans in the covered lane, shop entrances and building route. Static clearance passing does not establish that live pathfinding succeeds.
6. Check prototype doors/stoops, new block joins, NPC home occupancy, server/client frame times and streaming from two clients. Then judge whether this cluster is genuinely claustrophobic and architecturally coherent before authorizing propagation.

This stage is **awaiting Studio validation**. The geometry is denser, but the intended visual feeling, actual chase behavior and performance are not claimed as verified. No city-wide rollout is included.
