# Lower Layer — Upper Habitation + Roof Infill Kit V1

Nine reusable assets extending the approved frontage and circulation libraries. Applied only to the separate playable KitBlock. No city rollout, gameplay changes, new AI, population or mission logic.

## Pieces

| Asset | Nominal footprint | Role |
| --- | --- | --- |
| U01 Apartment Window Bay | 12 × 2 | Two unequal framed residential windows, sill/header depth and masonry courses; closed facade |
| U02 Recessed Apartment Entry | 16 × 6 | Enterable entry alcove leading to a closed apartment door |
| U03 Bridge Apartment | 16 × 24 | Enclosed through-room with side windows, a short partition and two real 8-stud exits |
| U04 Offset Gallery Landing | 16 × 24 | Covered west-to-north connection, parapets and residential backing wall |
| U05 Return Corner | 16 × 16 | Mirrored guarded turn connecting the gallery to stairs |
| U06 Roof Addition | 12 × 12 | Closed small rooftop dwelling; background habitation, not an accessible room |
| U07 Roof Parapet | 12 × 1 | Masonry edge with a projecting coping |
| U08 Stepped Corbel | 12 × 6 | Wall-mounted masonry bearing/anchor detail |
| U09 Ancient Tie | 4 × 4 | 24-stud vertical structural tie to the overhead ancient structure |

The kit preserves the earlier material palette and uses the existing shared PBR atlas. Frontages have 18-stud floor spacing; the roof dwelling is lower, with its cap at 14.4 studs. Frames, coping and sills project beyond nominal footprints: use the manifest bounds for tight fits.

## Connection contract

One authored unit targets one Roblox stud. X is across, +Y inward, Z up. Origins are at front-centre finished floor. Walkable portals are 8 studs wide; framed doorways are 12 studs tall. Covered-route ceiling undersides are at 13.25 studs. Floors and connector support lips follow the circulation kit contract.

Use named sockets, not overall bounding-box centres. U04 has an offset north portal at local X −3 and a west portal at local Y 8. U05 is the mirrored corner needed for the stair return. These intentional offsets prevent a purely straight hallway extension.

`walkable: false` sockets on U01/U06/U07/U08/U09 are attachment references, not access routes. Their facade windows and doors are closed. Do not infer an interior from a decorative opening. U02's front alcove is accessible but its apartment door is closed; U03 is the actual through-building route.

## Applied test block

Open `Enfleshed_KitBlock.rbxlx`, not the main city place. The block now has:

- Two apartment-window tiers above its six existing street frontages.
- Rooftop dwellings and parapets over selected existing structures.
- Partial overhead cross-spans, preserving enclosure while revealing more habitation above.
- Masonry bearing members and structural ties reaching the unchanged ancient ceiling.
- An inhabited upper connection and a second stair pair returning to the rear lane.

The upper loop is: original stairs → original gallery/bridge/court → upper room → new side doorway → bridge apartment → covered residential landing → return corner → new stairs → rear lane → existing ground routes. The upper room's other new opening is an apartment entry alcove, not the return route.

The existing native-Part import approach is retained for immediate playability. Blender bevels, baked textures and final mesh shading are not represented in the `.rbxlx`; the complete mesh exports remain available separately. The flicker cleanup and explicit collision geometry remain in the builder. All previously reachable ground test cells are regression-checked, and gameplay bootstrap file hashes are checked for accidental edits.

## Outputs and sources

`assets/blender/generated/lower_layer_habitation_kit_v1/` contains the editable `.blend` asset library, catalogue image, manifest, packed/copied atlas, Blender asset catalogue metadata, validation report and 36 exports (9 visual and 9 collision assets, each in GLB and FBX).

- `scripts/lower_layer_habitation_kit_v1.py` authors and exports the kit, reusing the existing circulation mesh/export helpers without modifying the older libraries.
- `scripts/verify_lower_layer_habitation_kit_v1.py` reopens the blend, validates mesh/UV/portal data and reimports each visual and collision GLB.
- `prototypes/KitBlock/upper_layout.py` holds this test block's explicit placements, connections and overhead supporting geometry.
- `prototypes/KitBlock/ground_baseline.json` records the previously playtested ground coverage and runtime hashes.
- Existing KitBlock extraction, assembly, validation and preview tools now include this third pack.

## Rebuild

From the repository root, with Blender available:

```sh
blender --background --python-exit-code 1 --python assets/blender/scripts/lower_layer_habitation_kit_v1.py -- --render
blender --background --python-exit-code 1 --python assets/blender/scripts/verify_lower_layer_habitation_kit_v1.py
blender --background --python-exit-code 1 --python prototypes/KitBlock/extract_components.py
python3 prototypes/KitBlock/build.py
rojo build prototypes/KitBlock/review.project.json -o Enfleshed_KitBlock.rbxlx
python3 prototypes/KitBlock/test_block.py
python3 prototypes/KitBlock/test_cleanup.py
stylua --check prototypes/KitBlock/*.luau
git diff --check
```

The installed Blender here is launched through Flatpak. Rojo remains 7.7.0. Export roundtrips and static clearance checks are not Studio physics or NPC-pathfinding verification. Stop here for manual traversal/chase testing before adopting the pieces across the city.

## Validation result

The nine assets contain 8,492 visual triangles in total. All 18 visual/collision GLBs were reimported and their bounds checked; all 36 export files passed hash checks. The compiled test block contains 2,083 static Parts. Its tests pass 943 route samples, 81 seam samples and 76 static module references, retain all 4,546 baseline ground points, and establish an independent return path from the upper room. No same-facing coplanar overlaps remain under the compiled-geometry check. The existing corpse cleanup tests also pass. These results are offline checks; the new upper route still needs manual Studio testing.
