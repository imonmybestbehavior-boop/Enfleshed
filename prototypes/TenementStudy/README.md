# Residential tenement frontage — single isolated prototype

Open **Enfleshed_TenementStudy.rbxlx** from the repository root in Studio. This separate review place contains one static building visible in Edit mode. Select `Workspace.Tenement` and press **F** to frame it. Press Play to walk up either stoop and enter its hall using normal Roblox controls.

## Architecture

- Approximately **92 studs wide, 36 deep and 88 high**, plus stoops projecting 13 studs toward the review street.
- Raised domestic ground floor plus four upper apartment storeys; four small, barred basement windows below the raised floor.
- Two distinct residential entry halls, offset at X −23 and +21. Six broad closed stone risers reach a 4.5-stud-high landing at each entrance. Masonry cheeks, simple continuous iron handrails, recessed jambs, transom glazing and open outer doors define the entries.
- Smaller domestic sash windows replace commercial display glazing. Upper floors repeat coherent apartment window groups, with narrower windows over an entrance and one closer paired group.
- Restrained dark masonry, deep reveals, floor courses and parapet relate it to the approved commercial family. The blank side walls are party walls intended to abut neighboring buildings.
- No retail frontage, signs, awnings, advertisements, furnishings or environmental dressing.

Each entrance leads to a real short hall with a closed inner residential door. The halls do not imply an implemented apartment complex: upper floors are visual architecture, with no internal staircase or playable apartments in this frontage study. Exterior stoops are the only stairs.

## Files

- `Tenement.rbxmx`: one editable static Model, **640 Parts**, organized into the shell, basement/raised floor, two stoop/hall assemblies and upper storeys.
- `review.project.json`: separate Rojo mapping, review ground, spawn and neutral lighting.
- `README.md`: this guide.
- Repository-root `Enfleshed_TenementStudy.rbxlx`: compiled review place.

There are no runtime scripts, procedural placement rules or dependencies on the city. The commercial prototype, main place, world generation, population, navigation and gameplay files are unchanged.

To rebuild from the repository root:

```sh
rojo build prototypes/TenementStudy/review.project.json -o Enfleshed_TenementStudy.rbxlx
```

## Review and validation

Inspect both entrances from street level and an oblique angle. Walk each stair/landing/door sequence, check the scale beside an avatar, and assess whether the raised domestic floor and basement windows clearly read as residential. Compare the whole silhouette with the approved commercial family; this should feel like another building in the same dense city.

Rojo 7.7.0 builds successfully. Static geometry checks verify positive dimensions, continuous stair/landing/hall support, three-stud-wide/nine-stud-high center-path clearance at both entries, and absence of executable scripts in the review place. All six rises are 0.75 studs with 1.5-stud treads. Offline geometry previews are not Roblox screenshots: Studio material/glass appearance and Humanoid stair movement still require manual review. No production optimization or city-wide application is included.
