# Lower Layer — three-block district pilot

A separate playable place assembled from the approved Frontage, Circulation and Upper Habitation kits. The original `Enfleshed_KitBlock.rbxlx`, kit libraries, main city and gameplay implementations are unchanged.

## Open the correct place

Stop Play, then open **Enfleshed_KitDistrict.rbxlx** at the repository root. In Windows Studio's file picker on this machine, paste:

```text
Z:\home\deck\Projects\Enfleshed\Enfleshed_KitDistrict.rbxlx
```

Press Play. You should spawn beside the brass test switch with **DISTRICT PILOT** at the bottom of the screen. This is not the main `Enfleshed.rbxlx` or the smaller `Enfleshed_KitBlock.rbxlx`.

## What was built

- Three adjoining assemblies, with the middle assembly turned 180 degrees: commercial lane, residential section, and workshop section.
- The tested block's interior routes, six ground frontages and two staircase connections are reused in each section. These are deliberately recognizable kit assemblies, not three wholly bespoke neighborhoods.
- Two new pairs of offset ground passages split around solid construction and reconnect. A separate raised residential passage links the first two sections at +18 studs.
- A shallow, enterable service room is integrated into the workshop approach using the existing service-front kit. Its doorway opens onto the lane; it is intentionally a small dead-end room.
- All three local upper loops remain. Apartment tiers reach +36, structural ties reach +60, and an enclosing ancient roof has its underside at +60. The sides and underside are enclosed too.
- Visible decks over continuous hidden support, retained architectural depth, and the previous visual-surface separation fix.
- **6,526 static Parts**, **19 ground frontages** (18 reused plus the new service room), **six stair routes / three complete stair-return loops**: each section has two separate stair routes, each comprising two half-height flights.
- Building/route geometry spans approximately **222 × 483 studs**. Authoring coordinates: X −131 to +91, Y −22.55 to +460.25; Roblox Z reverses authoring Y. The enclosing ancient shell occupies 270 × 530 studs.

## Finding the new areas

From spawn, take either the existing interior route or west rear lane to the first block's rear lane. The new ground exit is near authoring (−20, 110), or Roblox **(−20, 0, −110)**. Follow either side of the service core into the turned residential section.

Upstairs, go through the old upper-room entry alcove: it now continues to the other section instead of ending at its back wall. The upper crossing starts around Roblox **(−9, 18, −88)**.

Cross the residential section to its opposite street edge, around Roblox **(20, 0, −280)**. The branching workshop approach leads into the third section. The new service room opens onto this approach around **(−26, 0, −300)**.

## Controls and stress test

WASD move, Space jump, Shift sprint, Q dash, mouse look/aim, click melee. Existing equipment/magic controls remain available through the reused controllers.

At the brass switch near spawn, hold **F** to cycle **5 → 10 → 20 → clear**. Each change clears the previous group; these are manual test populations, not automatic waves. Shared across all players. Player death does not restart the population; a new Play session does.

The server checks switch distance, character health and a two-second interaction cooldown. It selects from 28 statically checked ground candidates, raycasts physical ground, checks body clearance and minimum spacing, and skips positions close to players. The HUD reports living/requested numbers honestly if occupied candidates prevent the full count. Enemies are distributed through the district; they use their existing detection behavior, not automatic map-wide aggro.

Existing EnemyRuntime retains its shared pathfinding budget, staggered updates and combat authority. Corpses are removed after two seconds. No progression, encounter system or AI rewrite was added.

## Focused Studio checklist

1. Explore without enemies. Walk from the first lane through both service branches, across the residential area, through both workshop branches, into the third block and back.
2. Use both stair routes in each block. Cross the new upper residential connection and return at ground level. Try the service-room entrance on the workshop approach.
3. Check floor joins, camera clearance, corners, rails and the absence of sky or flickering. These are narrower connections, not expanded plazas.
4. Test 5, then 10, then 20 Nascent. Move through multiple sections to encounter their distributed positions. Lead nearby enemies around both branches and up/down stairs; watch for hesitation, congestion and blocked doorways.
5. Kill enemies and check the living count falls and bodies disappear. Clear/restart while bodies await removal. Die and respawn, then stop and restart Play.
6. Use Studio's server-and-two-clients test. Confirm both clients see the same population and switch state. Compare frame rate/server behavior at 5 and 20 enemies, especially around stairs.

## Validation and limitations

Offline checks validate all three copies' original route samples, 13,638 previously approved ground cells, connector clearance, reachability from spawn, enemy candidates, compiled module references and visible coplanar faces. Cleanup callbacks run under the existing Lua test doubles. These checks do not simulate Roblox pathfinding, camera collision or multiplayer performance; those require Studio playtesting.

The place still uses native Parts reconstructed from the kit components, not uploaded MeshParts. Mesh bevels and atlas/PBR detail are omitted. Streaming is disabled only in this bounded pilot, as in the reference block. The 6,526-Part district needs live performance evaluation before any city-scale rollout. The section names describe their intended character; repeated kit assemblies remain visible.

## Source files

- `build.py`: explicit district placement, boundary openings, connector decks/walls, service-room assembly, enclosure, surface cleanup and project/spawn-data generation. Reads the approved block without rewriting it.
- `District.rbxmx`: generated static geometry.
- `assembly.json`: generated geometry, routes, candidates, cleanup results and reference hash used for validation.
- `review.project.json`: isolated Rojo entry points; reuses current shared code and the reference block's opening bypass.
- `Server.server.luau`: bounded 5/10/20 test switch, spawn checks and corpse ownership.
- `SpawnPoints.luau`: generated district-only spawn candidates.
- `Client.client.luau`: existing client controller startup plus district instructions and population count.
- `test_district.py`: spatial, compiled-place and reference-preservation checks.
- `test_cleanup.py`: tests actual cleanup callbacks with Lua doubles.
- `validation.json`: latest machine-readable check results.
- `render_preview.py`, `service_preview.png`, `upper_preview.png`: offline views of the actual native geometry, not Studio captures.

## Rebuild

From the repository root:

```sh
python3 prototypes/KitDistrict/build.py
stylua prototypes/KitDistrict/*.luau
rojo build prototypes/KitDistrict/review.project.json -o Enfleshed_KitDistrict.rbxlx
python3 prototypes/KitDistrict/test_district.py
python3 prototypes/KitDistrict/test_cleanup.py
stylua --check prototypes/KitDistrict/*.luau
git diff --check
```

Stop here for manual Studio playtesting before scaling this approach farther.

## Architectural completion follow-up

The two upper apartment alcoves converted to through-passages no longer retain their original closed-door panels and trim. Their rear openings now have matching full-height jambs and lintels. The third block's closed apartment alcove remains intentionally closed.

New ground connectors and the upper residential link now have actual corridor tops at 13.25 studs clear height. The raised connection has a wall-backed side and bearing posts along its open side, preserving views without reading as an unfinished roofless maze. Existing intentional balconies, courtyards and stair openings remain open; the ancient enclosure remains above them.

No routes, street widths, enemy behavior or gameplay controls changed. Tests additionally check that false door panels are absent and connector centerlines have visible ceiling coverage.
