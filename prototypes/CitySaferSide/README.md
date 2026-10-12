# City build 3 — service weave B, courtyard C, and safer E/F

The expanded assembly from the approved drawing-led city plan. **This is a separate review place**, not an update to the KitDistrict pilot or the main `Enfleshed.rbxlx`.

## Open and play

Open **Enfleshed_CitySaferSide.rbxlx** at the repository root. In Windows Studio on this machine, paste:

```text
Z:\home\deck\Projects\Enfleshed\Enfleshed_CitySaferSide.rbxlx
```

Press Play. The bottom instructions should say **CITY BUILD 3 · SERVICE WEAVE B + C/E/F**. You spawn in the small safer-side pocket beside the internal opening. Stand facing the wall: the F lanes branch to your right, and the route toward E branches left.

WASD move, Space jump, Shift sprint, Q dash; the existing camera, equipment and combat controllers are reused. This architectural review does not spawn enemies or start city missions, population, events or the old stress switch.

Use `build-map.png` for the actual route and stair locations. Its coordinates are Roblox **X/Z**, with Roblox **Y** as elevation.

## Preserved build 1 scope

- Full internal divider: **1,184 studs long, 24 thick, 42 high**, with a genuinely open **32-wide × 30-high** passage and structural lintel. It connects two parts of the city, not the future ruins.
- Full **24-wide wall-side street** from the plan. A raised footing joins the wall base to the street edge; the opposite edge meets A/B reservation walls and the new C street frontage. There is no ordinary walking gap to the development catch surface.
- **Safer E/F fabric**, following the approved routes within the approximately **896 × 280-stud** combined neighborhood envelope. This is not a copy of the three-block pilot.
- **141 frontage pieces**: 29 residential entries, 28 service entries, 28 narrow shops, 28 shuttered fronts and 28 patched blank fronts. These are not 141 fully modeled buildings. The 85 open side-entry fronts have deliberately shallow tenant rooms.
- **Ten through-building interiors**, including six split rooms with side alcoves, three ground-level inhabited through-rooms and a through-building frontage. These are on normal routes, not merely rooms attached beside them.
- **Four switchback stair towers**: two to E's +18 route and two to F's +36 route. Twelve half-height stair flights in total. The +36 towers have real intermediate return landings.
- Two connected upper routes, including an inhabited bridge room. Selected upper backing walls use 19 additional apartment-window modules.
- Continuous visible ground over hidden collision support, covered lanes, framed openings, apartment tiers, roof masses and upper background habitation. The ancient roof underside is at **Y +180**.
- A visible **sealed underground-entry hatch** at the approved location. No sewer network or hidden cross-wall bypass has been invented.
- **Build 1 baseline:** 19,104 static Parts, 484 placed kit instances and 102 mounted light fixtures. Build 2 totals are recorded below and in validation.json. Point-light shadows are disabled to keep this first larger native-Part assembly bounded.

Dangerous area A, safer area D, and the cross-wall catwalk remain unbuilt. The former C reservation is now the courtyard neighborhood; the A/B reservation remains closed. The main city and both approved kit prototypes remain untouched.

## Local fitting decisions

The planned ground-route vertices are preserved. E/F upper-route ends make small offsets to meet real stair landings: the plan's centerlines were reservations, not finished staircase footprints. Both upper routes reconnect through separate stair towers.

For stacked stairs, upper-storey treads retain the original top surfaces, riser heights and guard language, but use a thinner underside. The kit's original solid-to-base tread fill would otherwise reduce headroom over the lower flights. Source Blender kits were not changed.

Upper rail openings remove only the cap across a stair arrival; side guards remain. Window modules are omitted where they would occupy an upper circulation opening. Covered passages have actual ceilings rather than relying on the distant ancient roof.

## Streaming and authority

This place uses the existing main city's streaming settings: **enabled, minimum radius 256, target radius 768**. Startup marks the small ancient-envelope model persistent, including the enclosure, catch surface and internal divider. This preserves the underground silhouette while ordinary city Parts stream.

All existing gameplay authority remains on the server. No AI acquisition, search, pursuit, damage, progression, mission or population code was modified. Live streaming behavior and frame rate still require Studio testing; offline geometry checks cannot establish either.

## Studio checklist

1. **Confirm the correct place:** look for the new bottom instructions and spawn pocket. Cross the internal opening, inspect the wall-side street, then return. Enter the courtyard neighborhood using either offset approach.
2. **Explore F:** from the opening pocket, take the right-hand lane, pass through the split/inhabited rooms, find the sealed hatch, and follow the lower reconnecting routes.
3. **Explore E:** return to the pocket and take the left-hand route. Walk through the split-room detours, side alcoves and the through-building frontage. Check that fronts feel attached to occupied building volumes.
4. **Test both upper loops:** stair bottoms are at X/Z **(432,616)** and **(584,592)** for E; **(952,624)** and **(1080,544)** for F. Ascend one end, cross the upper route, descend the other. Test intermediate landings, camera headroom and guard joins.
5. **Test surfaces:** sprint and dash around junctions; inspect the street footing, tenant doors, room thresholds and ceiling joins. Check for apparent holes, body obstruction and flickering. Intentional stairs and upper edges should read clearly.
6. **Test restart/streaming:** respawn, traverse between far ends, then stop and restart Play. Confirm the ancient roof remains visible and nearby collision arrives reliably. Test with two clients and compare frame rate in the denser intersections.

Stop here for feedback before building D or the dangerous courtyard quarter. Do not treat the reservation wall as final city architecture.

## Validation

The final built-place checks pass:

- 340 doorway samples.
- 1,582 source-kit route samples, including stairs and through-room branches.
- 574 upper-route samples.
- Every planned E/F ground-route vertex and all four stair bases reachable from spawn through actual collision.
- 76 compiled module references resolved; one spawn; configured streaming settings present.
- Zero overlapping coplanar visible faces in the compiled place.
- Compiled Part positions, dimensions, visibility and collision flags match assembly data.
- Street-edge boundary checks, source syntax, StyLua, Rojo 7.7.0 build and whitespace checks passed.

These are offline geometric/reference tests, not Studio physics, navigation, pursuit or performance results. Previews are offline renders of the native geometry, not Studio captures.

## Limitations

The place uses native Parts reconstructed from approved kit components. It does not upload MeshParts or reproduce Blender bevels/PBR textures. The larger Part count is a deliberate test point; live performance may require geometry batching or mesh integration before broader city assembly. Streaming is configured, not performance-certified.

Interiors are prototype architectural spaces with minimal furnishing. Upper background masses are not accessible floors. The side-entry rooms are shallow; through-building circulation is supplied by the ten main interiors and the two upper loops. No final dressing or new asset pack was added.

## Files

- `build.py`: explicit E/F assembly from the approved plan and kit components; route reservations, kit placement, building volumes, floors, covers, stairs, enclosure and surface separation.
- `City.rbxmx`: generated static architecture.
- `assembly.json`: generated geometry, placements, route paths, stair endpoints and plan fingerprint.
- `review.project.json`: isolated Rojo mappings and streaming settings; reuses the approved opening bypass.
- `Server.server.luau`: persists the enclosure and starts existing action handling, without population or events.
- `Client.client.luau`: existing controller startup plus place-specific review instructions.
- `test_city.py`: actual-collision traversal, doors, boundaries, compiled geometry, streaming configuration and reference checks.
- `validation.json`: machine-readable final check results.
- `render_map.py`, `build-map.svg`, `build-map.png`: locator map of built and reserved areas.
- `render_preview.py`, `opening_preview.png`, `lane_preview.png`, `upper_preview.png`: offline visual review of the actual native Parts.
- `README.md`: scope, fitting decisions, directions, checks and limitations.

## Rebuild

From the repository root:

```sh
python3 prototypes/CitySaferSide/build.py
stylua prototypes/CitySaferSide/*.luau
rojo build prototypes/CitySaferSide/review.project.json -o Enfleshed_CitySaferSide.rbxlx
python3 prototypes/CitySaferSide/test_city.py
python3 prototypes/CitySaferSide/render_map.py
rsvg-convert -o prototypes/CitySaferSide/build-map.png prototypes/CitySaferSide/build-map.svg
stylua --check prototypes/CitySaferSide/*.luau
git diff --check
```

Spawn placement uses a serialized CFrame at (1020, -0.5, 460), with an invisible collidable 8 × 1 × 8 pad flush with the pocket floor. The compiled-place check verifies the transform and landing height. After updating the place, test both initial Play and Reset Character.

## Build 2 — courtyard neighborhood

`courtyard.py` adds only C to the existing assembly. `build.py` calls it and opens the former C reservation boundary. The original plan, E/F route geometry, kits, gameplay services, population and missions are unchanged. The filename is retained so there is one current city review place to open.

C uses the approved 112 × 96 courtyard inside a 376 × 304 neighborhood envelope. Two separate street approaches turn through building interiors before reaching the court; C3 reconnects them before the court and C4 leads into a northern tenement branch. Five ground through-interiors and one upper inhabited bridge use the existing kit. Two new switchback towers connect a covered +18 gallery overlooking the south court edge. Closed/shuttered/barred frontages, heavier masonry repairs and taller uneven upper masses distinguish C from E/F without debris props or new gameplay.

### Playtest this pass

1. Stop Play and reopen the rebuilt root `Enfleshed_CitySaferSide.rbxlx`. Confirm **CITY BUILD 3 · SERVICE WEAVE B + C/E/F**. Reset Character once to verify the fixed spawn remains correct.
2. From spawn, pass through the internal opening toward decreasing Z. Turn left along the wall street to X928; take the narrow approach north into C. Follow its bends and through-rooms to the courtyard.
3. Leave the courtyard on its east side. Follow the offset passages to the second street entrance at X1152, then return along the wall street and through the same internal opening. No extra wall bypass was added.
4. Explore the service crossing between the two approaches and the northern tenement branch. Look for blocked doors, confusing floor gaps and long unintended sightlines.
5. At (904,312) and (1184,296), climb the new stairs. Follow the +18 gallery through the bridge room and descend at the other end. Test stair headroom, guards, camera clearance and floor transitions.
6. Look upward from the court: it should reveal layered housing and ancient enclosure, not outdoor sky. Inspect windows and repaired surfaces for flickering.
7. Revisit E/F and test two clients. This native-Part review needs live streaming/frame-rate verification. There are no new enemies, danger rules or missions; “dangerous” describes architectural presentation for this pass.

### Changed files

- `courtyard.py`: bounded C geometry and route metadata.
- `build.py`, generated `City.rbxmx` and `assembly.json`: integrate C while retaining the original E/F assembly.
- `Client.client.luau`: updated location/testing label only.
- `test_city.py`: extends collision flood-fill to C, checks courtyard access with either street entrance blocked, retains compiled spawn/reference checks.
- `render_map.py` and map outputs: show built C and new stair locations.
- `render_preview.py` and courtyard preview outputs: offline views of the generated geometry.
- `validation.json`, this README, and root review place: rebuilt validation and handoff artifacts.

The two courtyard masonry piers begin above the ground-floor headers so they do not clip recessed doorways. A solid end closure joins C to the wall-street terminus; the edge validation samples this seam as well as the ordinary street edges.

Final build 2: **27,111 static Parts**, 691 kit placements, 190 frontages (49 added in C), 15 ground through-interiors, 6 stair towers, three upper routes, and 141 light fixtures.

## Build 3 — neighborhood B service/residential weave

B adds seven ground through-interiors (split workshop/service rooms and inhabited passage rooms), four side alcoves, recessed shop/service/residential fronts, an extra repair-lane dead end, and a +36 upper loop passing through an inhabited bridge room. Two independent two-storey switchback towers connect it to the ground. The built envelope is X416–840, Z64–368 (424 × 304 studs); the planned B ground-route vertices remain unchanged.

Two explicit ground connections join B and C across X840:

- North: B's (752,200) turn → (800,200) → (800,176) → C's existing (884,176) branch.
- South: B's (752,320) turn → (808,320) → (808,352) → (880,352) → (880,356) → C's existing (928,356) approach.

Only these local openings are cut into C's western building mass. Frontage slots intersecting the openings are removed, with solid backing restored around the new passage; the existing frontage sequence elsewhere is retained. The courtyard, its original routes and upper gallery remain in place. E/F and the internal divider retain their existing geometry. A and D, the sewer network, ruins, AI and missions remain outside this pass.

### Find and test B

1. Stop Play, reopen `Enfleshed_CitySaferSide.rbxlx`, and confirm **CITY BUILD 3 · SERVICE WEAVE B + C/E/F**. Spawn remains beside the internal opening.
2. Cross the opening and turn left along the wall street. Pass C's first entrance at X928. B's nearer entrance is at X752, with a second entrance farther left at X512. Both lead away from the wall into covered through-buildings.
3. Explore B's bends and workshop/tenement connections. Reach C by each of the north and south interior links, then return by the other without using the wall street.
4. Climb at (584,280) or (776,256) to the +36 gallery. Traverse the inhabited upper room and descend at the other tower. Check both flights per storey, return landings, headroom and side rails.
5. Inspect the (472,244) repair-lane dead end and the existing northern branches. They should read as deliberately closed branches, not floor gaps.
6. Revisit C and E/F, reset the character, and test with two clients. Look for flicker, delayed collision streaming and frame-rate changes. The native-Part count has increased; offline tests do not establish live performance.

### Build 3 file changes

- New `weave.py`: explicit B kit assembly and the two shared B/C portal reservations.
- `courtyard.py`: localized reservations for those connections, closure of displaced facade pockets, and mounted connection lighting.
- `build.py`: integrate B, open only B's old street reservation, and provide optional collision preflight before the slower face-separation pass.
- `test_city.py`: sample both connections end-to-end and independently test B/C connectivity without the main street.
- `Client.client.luau`: location label only; no controller/gameplay changes.
- `render_map.py`, `render_preview.py`, generated geometry/reports/map/previews, and the root place: updated assembly and review artifacts.

Optional fast geometry preflight (does not overwrite the saved place):

```sh
python3 prototypes/CitySaferSide/build.py --geometry-only /tmp/enfleshed-city-preflight.json
python3 prototypes/CitySaferSide/test_city.py --geometry-only /tmp/enfleshed-city-preflight.json
```

The ordinary rebuild and compiled-place checks above remain required for handoff.

Final build 3 totals: **37,499 static Parts**, 960 kit placements, 250 frontages, 22 ground through-interiors, 8 stair towers, 4 upper routes, and 188 light fixtures. B adds 61 fronts and seven through-interiors; one C frontage slot is replaced by the northern connection. All 48 retained C fronts and its original ground/upper route records match build 2. E/F's 4,689 collision pieces match build 2.
