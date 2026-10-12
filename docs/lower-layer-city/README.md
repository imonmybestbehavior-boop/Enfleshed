# Lower Layer city — drawing-led measured layout

This is the **layout proposal before full city assembly**, not new Roblox geometry. The approved KitBlock, KitDistrict, main city, asset libraries and gameplay code have not been changed. Open `city-layout.png` or `city-layout.svg` to review the plan.

## Confirmed interpretation

The courtyard side is the **more dangerous** city. The compact housing and sewer-access side is the **safer** city. These are spatial design roles, not new AI or safety rules.

The wall divides two parts of the city. Its opening is internal. It is **not** the guarded exit to the future ruins. No ruins, combat objectives, guard behaviors or pursuit changes belong to this task.

The main wall-side street is the deliberate long sightline. Local alleys should repeatedly turn, narrow, pass through buildings and reconnect. The courtyard is a contained exception, surrounded by housing, rather than evidence that the rest of the city should be open.

The sketch's cross-wall walkway is retained as a dotted reservation. Whether it is accessible across the divider, and therefore an alternative to the main choke point, is unresolved. The sewer entry also does not silently create a bypass: its underground connections remain undecided.

## Proposed measurements

These dimensions are design proposals fitted to the approved kits, **not measurements taken from the drawing or an existing built city**.

| Element | Proposed dimensions |
|---|---|
| Overall planning footprint | 1,280 × 800 studs |
| Internal wall | 1,184 long × 24 thick, 42 high |
| Wall-side street | 24 clear, along the dangerous side of the wall |
| Internal wall opening | 32-wide structural gap, X 1004–1036 |
| Small opening-side space | 56 × 40, on the safer side |
| Enclosed courtyard | 112 × 96, on the dangerous side |
| Ordinary alleys | 8–12 clear; no broad open strips between neighborhood envelopes |
| Interior through-routes | 8 clear; 12 minimum headroom |
| Frontage modules | Existing 12 / 16 / 24 widths |
| First upper connections | +18 and +36; reserve later layers at +54 |
| Background human occupation | Proposed from +90, not traversable by default |
| Ancient enclosing mass | Proposed ceiling underside about +180; side structure extends beyond the footprint |
| Underground entry | Reserve descent to −18; no tunnel network laid out yet |

Plan axes are Roblox X and Z, with low Z at the top of the image. Vertical elevation is Roblox Y. This deliberately avoids the Blender source kits' different axis convention; final placement must convert those source coordinates explicitly.

## Housing envelopes are not giant buildings

A–F are construction work areas, **not six solid blocks or six rectangular street grids**. Their colored areas represent occupied city fabric to subdivide into overlapping narrow buildings. Pale lines reserve circulation through that fabric. Unmarked space within an envelope should generally become construction, rooms, enclosed courts or inaccessible building volume—not leftover open ground.

The thin spaces between envelopes also are not automatically streets. Some will be party walls, connected building volumes or covered joins. Only declared routes receive an ordinary traversal promise.

| Area | Role | Building / route direction |
|---|---|---|
| A | Dangerous west housing | Unequal narrow residential fronts; offset interior loops; short dead ends |
| B | Dangerous service housing | Mixed service and residential entries; split rooms; connected upper habitation |
| C | Dangerous courtyard quarter | Building ring enclosing a local court; offset entrances conceal the court from the street |
| D | Safer older wall-edge housing | Tight wall-edge dwellings; lateral connection into E; inaccessible ancient recess behind |
| E | Safer dense inner housing | Packed dwellings and shared internal passages; several reconnecting ground/upper choices |
| F | Safer opening and underworks quarter | Constrained internal-wall approach, neighborhood branches and underground entry reservation |

Labels such as “safer” do not justify widening the streets or making the architecture suburban. Both halves use the same dense Lower Layer language.

## Kit-to-layout mapping

- **Wall-facing occupied fronts:** F01/F02/F04 commercial pieces mixed with F05 residential and F06 service pieces. Avoid a continuous strip of identical shops.
- **Neighborhood entries:** F05 + A01; F07 + A02; F08 + A03 when a genuine through-building passage is needed.
- **Route sequences:** combine I01 offset vestibules, I02 doglegs, I03 corners, I05 split rooms and I06 side-exit rooms. A mapped bend may be inside a room, a covered alley or a stair lobby; it must not become only a freestanding zigzag parapet.
- **Vertical transitions:** I07/I08/I09 stair assemblies. Reserve approximately 24 × 44 per switchback stair shaft before allocating neighboring rooms; +36 requires two +18 stages, not a steeper single flight. Orient and check each shaft during detailed assembly.
- **Upper connections:** I10/I12 with U03 inhabited bridges, U04 galleries and U05 return corners. Every connection needs a floor, appropriate ceiling, believable bearing structure and two usable endpoints.
- **Occupied upper/background masses:** U01 windows, U06 roof additions, U07 parapets, U08 corbels and U09 ties. Use larger ancient masses outside the detailed human fabric.
- **Closed versus open doors:** U02 is a closed apartment alcove by default. Any through-route version must remove the closed leaf and frame the actual opening, carrying forward the district fix.

Five upper route reservations join ground-connected endpoints. They are not final stair or bridge placements; the exact shafts, room footprints and headroom still require the detailed placement pass.

## Sightlines and escape topology

All ordinary ground-route segments in the proposal are at most 96 studs between mapped changes of direction; most are shorter. This is a reservation constraint, **not a claim of validated visibility**. Final building corners, covered transitions and room partitions must physically obstruct views. Do not substitute decorative props for those obstructions.

The ground network has a single declared wall crossing, through the internal opening. The reserved cross-wall catwalk is excluded from connectivity checks pending the access decision. Each neighborhood has branches, and the longer route pairs reconnect. The courtyard is connected through more than one entrance. The underground access is reachable on the safer side.

## Construction sequence after layout review

1. Establish the internal wall, its opening, wall-side street and enclosing ancient structure at the agreed scale. Build the opening's **safer-side** approach as the first anchor.
2. Build F and E as connected, occupied safer-side fabric using distinct kit sequences. Reserve sewer access without inventing its downstream connections.
3. Complete D and its route back into E. Preserve the intentional ancient recess.
4. Build the dangerous courtyard ring C and its constrained connections to the opening and wall-side street.
5. Complete B and A, filling the remaining dangerous-side fabric with interlocking buildings rather than copying the district pilot.
6. Join the upper reservations with real stair shafts, bearing structure and covered passages. Resolve the cross-wall catwalk separately before constructing an accessible crossing.
7. Audit visible ground, collision, ceilings, door openings, camera clearance and route connectivity section by section. Then assess the complete city in Studio before starting ruins or AI work.

This plan does not pick a start room, spawn position, guarded exterior gate, missions or new population rules. Those locations/systems should not be inferred from the colored areas.

## Validation performed

`validate_plan.py` checks the confirmed side assignment, bounds, axis-aligned route reservations, ordinary segment lengths, connectivity of all ground-route endpoints from the internal approach, attachment of upper stair endpoints to the ground network, absence of accidental ground crossings through the divider, preservation of the inaccessible recess, and compatibility with the existing kit width units.

It does **not** validate final building footprints, actual sightlines, stair footprints, collision, enemy pathfinding or runtime performance. No Rojo rebuild or StyLua run is needed for this planning-only change; no Luau/project/place files changed. Native-Part duplication across the whole footprint must not be assumed performant merely because the smaller district worked. Mesh reuse, collision simplicity, streaming and background representation need explicit evaluation during assembly.

## Files and reproduction

- `layout.json`: measured source proposal, role assignments, route reservations and open decisions.
- `render_plan.py`: draws the plan from that data; does not generate city geometry.
- `city-layout.svg`: scalable review drawing.
- `city-layout.png`: rendered copy for easy viewing.
- `validate_plan.py`: scoped plan/kit checks.
- `validation.json`: recorded results and limitations.
- `README.md`: interpretation, dimensions, kit mapping and build sequence.

From the repository root:

```sh
python3 docs/lower-layer-city/validate_plan.py
python3 docs/lower-layer-city/render_plan.py
rsvg-convert -o docs/lower-layer-city/city-layout.png docs/lower-layer-city/city-layout.svg
git diff --check
```
