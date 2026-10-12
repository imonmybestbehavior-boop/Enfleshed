# Lower Layer — Interior Circulation + Vertical Connection Kit V1

A separate 17-piece library extending the approved frontage kit. It does not change the city, gameplay, navigation system, or frontage library. The connected sample is an asset review scene, not a new level generator.

## Assets

| Asset | Footprint (studs) | Purpose |
| --- | --- | --- |
| I01 Offset Vestibule | 24 × 24 | Rear shop transition with an offset dividing wall |
| I02 Dogleg Passage | 24 × 32 | Two parallel corridors linked laterally |
| I03 Corner Passage | 16 × 16 | Enclosed right-angle turn |
| I04 T Junction | 24 × 16 | Three-way interior route junction |
| I05 Split Room | 24 × 24 | Two routes around a load-bearing service core |
| I06 Side Exit Room | 24 × 24 | Divided room with three offset exits |
| I07 Stair Flight | 12 × 32 | 9-stud rise; two flights make one 18-stud story |
| I08 Return Landing | 24 × 12 | Switchback between adjacent stair flights |
| I09 Top Landing | 24 × 12 | Offset stair-to-gallery connection |
| I10 Gallery Link | 12 × 24 | Guarded upper route with a lateral exit |
| I11 Courtyard Transition | 24 × 24 | Covered entry opening into a small court |
| I12 Bridge Link | 12 × 24 | Guarded bridge with continuous deck support |
| I13 Service Alcove | 12 × 12 | Deliberate short dead end |
| A01 Residential Adapter | 12 × 4 | F05 rear opening: 5.5 to 8 studs |
| A02 Alley Adapter | 16 × 4 | F07 rear opening: 9 to 8 studs |
| A03 Passage Adapter | 16 × 4 | F08 rear opening: 12 to 8 studs |
| Z01 Portal Closure | 12 × 0.6 | Cap an unused portal |

The sample connects F08 through the offset vestibule into branching rooms, a second F05 street exit, a dogleg dead-end branch, a switchback stair, upper gallery, bridge, court, and upper room. The service core creates a local reconnecting loop. Unused upper exits are capped.

## Assembly contract

- One Blender unit targets one Roblox stud. Calibrate the Studio importer with a known 12-stud module before placing assets.
- Authoring axes: X across, +Y inward, Z up. The street faces −Y. GLB uses its normal Y-up conversion; Blender reimport restores the authoring axes.
- Origin: front-centre at finished floor. Use named port positions, not bounding-box centres, when snapping offset routes.
- Standard circulation portal: 8 studs clear width, 12 studs height. Adapter entry widths match the three specified frontage rear openings, not every frontage in the previous pack.
- Widths: 12, 16, 24 studs. Building story: 18 studs. Covered rooms have ceiling underside 13.25 studs.
- Stairs: eighteen 0.5-stud risers, 1⅓-stud treads, 24-stud run, 4-stud landings at both ends. Reserve at least 9.5 studs above the walking surface; do not stack a room ceiling through the stair volume.
- Connect coincident ports with opposing normals and matching widths. Endpoints can be offset from the module centre.
- Floors meet at their visible edges. Collision support lips overlap the connection by 0.2 studs on each side, with tops 0.02 studs below finished floor. They are reliability supports, not invisible extensions of the intended route.
- Wall/door trim may project beyond nominal footprints. Use route clearances and actual manifest bounds when fitting surrounding buildings.
- Upper edges are guarded; every unused walkable port must receive a closure or another supported route. A port is not permission to leave a fall hazard.

## Files and rebuilding

Run from any directory with Blender installed:

```sh
blender --background --python-exit-code 1 --python assets/blender/scripts/lower_layer_circulation_kit_v1.py -- --render
blender --background --python-exit-code 1 --python assets/blender/scripts/verify_lower_layer_circulation_kit_v1.py
```

The relative commands assume the repository root. On this machine the executable is launched through the Blender Flatpak.

- `scripts/lower_layer_circulation_kit_v1.py`: explicit module geometry, connected review assembly, export orchestration and previews.
- `scripts/lower_layer_circulation_common.py`: local geometry, sockets, shared atlas mapping and export helpers.
- `scripts/verify_lower_layer_circulation_kit_v1.py`: reopened library, route/connection clearance, hashes and GLB roundtrip checks.
- `generated/lower_layer_circulation_kit_v1/`: editable `.blend`, 17 visual and 17 collision assets in both GLB and FBX, manifest, checks, previews, and copied atlas textures.

The generator requires the approved frontage pack beside this pack. It copies its atlas and appends two frontage collections into the review scene; it does not modify the source pack. Generated exports embed materials/textures. No network assets or new Python dependencies are required.

## Import and visual review

1. Open the generated `.blend` and inspect `CONNECTED_SAMPLE`. Catalogue assets are positioned separately to its left. Collection assets instance at their authored origins despite their catalogue display positions.
2. `catalogue.png` and `connected_cutaway.png` hide removable ceiling meshes to expose circulation. The saved library and exports retain the ceilings.
3. Import one visual GLB/FBX into Studio. Anchor it, disable visual mesh collision, and check its scale against a 12-stud Part.
4. Use manifest collision boxes as anchored invisible Roblox Parts. Collision mesh exports are reference geometry; do not merge them into a single convex collision object that seals openings. Apply the same root transform to visuals and collision.
5. Walk through adapters and offset doors using the current character. Test both directions, sprinting, camera turns and stair ascent/descent. Check the switchback and the full 18-stud rise.
6. Test NPC traversal separately before adopting modules in world generation. Static envelope checks do not establish live Humanoid step handling or Roblox pathfinding support.
7. Review streaming and physics costs in Studio before repeating these assets across the city.

## Limits

This is an architectural asset pack, not a furnished interior pack. No doors that open, ladders, lifts, loot, AI changes, gameplay logic, or city rollout are included. Materials deliberately reuse the frontage palette; unique dressing and final weathering remain separate work. Flat box guards favour safe modular boundaries over finished railing detail. The asset/export checks are reproducible, but Studio import, character clearance and engine performance still need manual validation.

The next useful pack is **Upper Habitation + Roof Infill**: shallow apartment volumes, balcony rooms, roof additions and building-to-building connectors that give these circulation pieces occupied architectural context.
