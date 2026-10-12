# Bounded population and street-front pass

## Result

- Ambient human target: **72**, up from nine. Hard total cap: **80**, with **eight slots reserved** for event actors. Successful live spawns depend on ground clearance and occupancy; the target is not a claim that all 72 have spawned in Studio.
- **35 major-street facades** converted into six deterministic archetypes: shops, service counters, workshops, market fronts, boarded stores and guard supply fronts.
- **29 enterable shallow interiors** and six deliberately boarded fronts. Rooms are 20–24 studs deep, with 14-stud clear entrances, overhead cover, counters, shelves and archetype-specific furnishings. Service fronts also have open counter windows. Small physical fascia signs identify their use.
- These replace ground-level solid foundation volumes inside existing housing lots. Upper housing stays in place. Conflicting old workshop/stair-tower decorations are omitted on converted lots rather than remaining inside the rooms.
- No street widening or graph changes. No new stairs or upper access: the existing through-buildings, stairs, alleys and catwalks remain the vertical/maze routes. Shop rooms are intentionally shallow destinations, not new dungeons.
- Existing visible neighborhood paving and hidden backup supports remain under the newly exposed rooms. No invisible-only shop floors were introduced.

## Population and performance

The original nine authored people/routes remain. The added plan places workers/merchants in the 29 occupied front rooms, then distributes the remaining 34 homes along street segments in round-robin order. Recruit/guard roles occupy the north/recruit area, residents/civilians the outer residential streets, and workers/merchants/civilians the central market/service streets. Static post holders and short local routines supplement the existing traveling courier and patrol; the entire population does not walk the main avenue together.

Initial/replacement spawn attempts are capped at two per 0.1-second tick. At most 24 human brains update per tick, so a full default population receives an update roughly every 0.3 seconds. Movement and danger use the existing server-owned behavior. Human pathfinding stays at two starts/second, one computation in flight, and four-second individual retry limits. Death cleanup and 90-second replacement delays remain. Events retain their separate lifecycle, participation, rewards and temporary traveling actors.

`CityLife.NPCs` exposes the target, total cap, reserved event capacity, scale and update/spawn budgets. `Workspace.LivingCity` exposes `AmbientTarget` and `LivingCount`; individual new humans expose their `District`. `Workspace.LowerLayerGraybox.StreetFronts` exposes deterministic archetype, entrance and home metadata. The same metadata drives human placement, rather than duplicating shop coordinates in population configuration.

## Files

Added:

- `src/server/Development/LowerLayer/StreetFrontage.luau`: pure deterministic lot selection, approach-clearance rejection, cavity/wall/front/furnishing geometry and room metadata.
- `src/server/Services/CityPopulationLayout.luau`: pure bounded home/role distribution using shop metadata and existing street geometry.
- `tests/test_street_frontage.lua`: checks room and entrance support, four-stud-wide/nine-stud-high access clearance, frontage containment within lots, six archetypes, 72 population slots, district coverage and event capacity.
- `CITY_STREETFRONT_PASS.md`: this report and focused test checklist.

Modified:

- `PhaseA.luau`: replaces selected solid foundations, omits conflicting legacy extensions on those lots, creates frontage geometry/signs/lights and metadata.
- `CityLife.luau`: larger bounded population and explicit update/spawn/event reserve budgets.
- `LivingCityService.luau`: consumes planned homes, throttles spawning, round-robins human updates and exposes counts; existing event creation calls retain their interface.
- `tests/test_phase_a_geometry.lua`: tests actual carved foundations/frontage obstacles against existing routes, doors, stairs and enemy spawn candidates; updates the modeled part estimate.
- `README.md`: points to this pass; the older core-loop report's nine-person count is superseded.
- `Enfleshed.rbxlx`: rebuilt generated output.

## Validation and limits

All 13 Lua tests, Rojo 7.7.0 build, the three Python built-place reference/source checks, StyLua formatting check and whitespace check pass. The frontage test measures 35 fronts, 29 accessible interiors and 455 replacement frontage Parts. Three otherwise plausible candidate entrances were rejected because their approaches intersected neighboring geometry.

Offline clearance tests include the generated static geometry, original main routes and spawn candidates. They do not simulate Humanoid movement, live crowd occupancy, streaming, or client/server performance. Studio playtesting remains required. Primitive human rigs and shallow shop furnishing placeholders are retained; there is no trading, shop economy, progression, quest change or final art. Busy areas may cause actors to wait on the unchanged pathfinding budget. No crowd-steering framework was added.

## Focused Studio checklist

1. Stop Play, reopen the newly rebuilt `Enfleshed.rbxlx` (or sync with Rojo while stopped), and start a fresh two-client server test. Finish the opening. Allow roughly ten seconds for the bounded initial population fill; inspect `LivingCity.AmbientTarget` (72) and `LivingCount` if numbers seem low.
2. Walk from the recruit area through central market streets and both outer residential streets. Check that several people are visible in occupied stretches, roles vary appropriately, merchants inhabit front rooms, and everyone is not converging on a single route. Watch for persistent blocked spawn slots or NPC crowd jams.
3. Inspect shops on both sides of major streets. Read fascia signs, compare workshop/counter/stall/supply/boarded variants, enter every reachable front room, and check the counter/shelf layout, clear doorway, lighting and solid visible floor. Boarded fronts should read as deliberately closed.
4. Sprint/dash along the original streets, alley shortcuts and catwalk/stair routes. Confirm there is no widened empty hall, new solid obstacle in the old routes, or loss of the claustrophobic layered housing silhouette. Chase an enemy through an open shop entrance and back out.
5. Force a LocalAttack and TravelIncident using the existing core-loop report's Studio controls. Confirm civilians flee, guards engage, escort actors can still spawn despite the higher ambient target, participation/rewards remain correct, and survivors resume their routines.
6. Observe two-client performance and server Output for several minutes. After human deaths and event cleanup, counts must stay capped and corpses/event actors must disappear. Reduce `NPCs.Scale` if needed for comparison; record client frame time, server frame time and navigation hesitation before changing the path budget.
