# Lower Layer — Building Frontage + Storefront Kit V1

This is a reusable asset library, not another generated street or a replacement city. The generator creates twelve architectural frontage modules and twenty-one separate attachments. Existing city generation, gameplay, population, previous studies and their materials remain unchanged.

**Open:** `generated/lower_layer_frontage_kit_v1/lower_layer_frontage_kit_v1.blend`.

**Preview:** `frontages.png`, `details.png`, and `assembly.png` in that same directory. The assembly is a review scene made from collection instances; it is not installed in the game. Studio import and controller collision acceptance have not been performed here.

## Dimensional contract

- One authored Blender unit targets one Roblox stud. The first narrow shop's seam-to-seam width is 12 units: use that to verify your Studio importer scale before assembling the library.
- Standard seam widths: **12, 16, 24**. All use a **4-stud planning grid**. Width is the nominal structural seam, not the bounding box of every projecting trim element.
- Frontage origin: **front centre at finished floor**, not mesh bounding-box centre. Blender axes: X across frontage, +Y into the building, +Z up. Street is −Y. glTF converts to Y-up; Blender `(x,y,z)` becomes glTF `(x,z,−y)`.
- Standard top seam: **Z18**. F12 includes an occupied overhang up to Z30, so reserve its upper band; do not blindly stack another full module at Z18. F11 balcony braces extend about 3.7 studs below its floor: reserve that clearance when using it above a street.
- Normal wall thickness is 1.2 studs. Trim projects roughly one stud toward the street; balconies and the overhang reach approximately four studs. Plan street width from actual `bounds` in the manifest, not nominal wall position alone.
- Floors finish at Z0. Threshold finish is Z0.02. Vestibule/passage floors connect from the frontage plane to the rear socket. Shallow open rear edges must connect to another floor/room module or be deliberately closed by the assembler.
- Small foot trim may lap a structural seam by 0.04 studs. Do not stretch modules to fit arbitrary widths; combine the standard widths or author a deliberate closure piece.
- Door and portal clearances are given in `manifest.json`. Open door leaves sit outside the declared clear portal. Shuttered and blank frontages are intentionally closed. Balcony guards make F11 a terminal balcony, not an automatically passable bridge connection.

## Frontage catalogue

| ID | Module | Width | Architectural use |
| --- | --- | ---: | --- |
| F01 | Narrow shopfront | 12 | Small tenant: offset open door, deep divided display, stone apron, shared rear connection. |
| F02 | Recessed shopfront | 16 | Major/local street: masonry returns, recessed door and display, continuous recess floor. |
| F03 | Shuttered storefront | 16 | Closed tenant frontage: two unequal shutters with guides, slats, locks and headboxes. No implied through route. |
| F04 | Barred storefront | 16 | Secure shop in an alley or service street: framed grille/display with a separate open doorway. |
| F05 | Residential doorway | 12 | Residential lanes and courts: shared entry, transom, heavy crown and lower-level grilles. |
| F06 | Service entrance | 12 | Workshops and service routes: wider metal-framed opening and folded leaves. |
| F07 | Alley opening | 16 | Street-to-alley transition: thick piers, deep reveals, covered approach and 9-stud portal. |
| F08 | Through-building passage | 24 | Major street into internal circulation: 12-stud clear width, 16-stud depth, rear connection and ceiling beams. |
| F09 | Patched blank wall | 12 | Party walls and blocked branches: broad repairs, coherent exposed brick courses; intentionally opaque. |
| F10 | Window-heavy frontage | 24 | Upper housing or communal rooms: three varied window groups, genuine reveals, aprons and structural piers. |
| F11 | Balcony-front frontage | 16 | Upper residential edge: accessible door, apartment window, supported deck and continuous guard. |
| F12 | Overhang frontage | 24 | Compressed street edge: occupied upper projection, supports, upper windows and lower commercial entry/display. |

For a street, mix 12- and 16-stud tenancies with occasional 24-stud passage/window/overhang units. Avoid repeating an identical sequence or attaching every detail to every module. Recesses, portal widths and upper projections should establish the rhythm before dressing.

## Attachable details — 21 assets

- **Three awnings:** canvas, corrugated metal, retracted roll.
- **Three sign bands:** timber, steel, recessed framed panel. Blank surfaces are supplied; there are no advertisements or generated lettering in runtime exports.
- **Two hanging brackets:** braced and elbow-return.
- **Three drainpipe pieces:** 12-stud straight, elbow and offset, with endpoint sockets.
- **Two conduit bundles:** 12-stud straight and bend.
- **Two vents:** square and wide louver.
- **Two utility boxes:** fuse box and meter box.
- **Two plaster overlays:** broad and tall irregular repair boundaries.
- **Two exposed masonry overlays:** narrow and wide staggered brick patches.

Detail pivots are attachment origins. Match an awning to the frontage's `AWNING` socket and a band to `SIGN`; pipes can begin at `PIPE` and connect via their endpoint sockets. `ATTACH` marks detail mounting origin. Keep vent/box/pipe projections outside circulation clearances. Overlay meshes sit slightly proud of an opaque wall and must not conceal an intended doorway. Awning width must suit its host module.

## Recommended placement

- **Main streets:** F01/F02/F04 narrow businesses, F08 as occasional real connections, F12 above selected sections. Use F03 between active tenants so commercial occupation does not read as one uninterrupted glass strip.
- **Alleys:** F05/F06, barred F04, patched F09, and F07 at transition mouths. Use restrained vertical utilities and occasional retracted awnings.
- **Side routes:** F05/F06/F07; let entries and recesses introduce useful pauses and route choices. F09 belongs where a route genuinely terminates or a party wall exists.
- **Interiors/courtyards:** F06/F07/F08 at circulation transitions; F05 at shared residential access. F10/F11 belong on upper inhabited edges. They are architectural interfaces, not a complete room/stair kit.
- **Upper layers:** F10, F11 and F12 express occupation above street level. Keep balcony brace/headroom envelopes and the overhang's occupied upper band clear.

## Source, exports and materials

Generator: `scripts/lower_layer_frontage_kit_v1.py`.
Validator: `scripts/verify_lower_layer_frontage_kit_v1.py`.

The `.blend` contains 33 named collection assets, separated into Frontages and Attachments catalogues by `blender_assets.cats.txt`. Add the generated directory as an Asset Library in Blender Preferences, or append a named collection. Corrected collection instance offsets prevent catalogue display positions from becoming placement offsets.

Each asset has a single visual mesh with one shared PBR atlas material. UV0 addresses the atlas; `UV1_Packed` retains a unique nonoverlapping unwrap for future baking. The four shared 512-pixel maps provide base color, roughness, metalness and tangent-space normal detail. Material wear is restrained; there are no unique tenant/storytelling textures or final grime passes. The windows use opaque dark tinted glazing to avoid transparency-sorting costs.

`exports/` contains individual **GLB and FBX visual files**, plus separate collision files for all twelve frontage modules. Review lights, labels, cameras and comparison instances are excluded. GLB embeds its PBR images and uses one material primitive per visual asset. FBX is provided as an interchange fallback; importer material support can differ, so the four PNG maps are also supplied in `textures/`.

`manifest.json` is the assembly contract: widths, actual bounds, sockets, portal clearance envelopes, triangle counts, suggested uses and collision boxes. Collision coordinates use the same authored pivot as the visual export. `validation.json` records reopened-scene checks; `export_hashes.json` identifies the exact exported files that were checked.

## Validation results

Blender 5.2 reopened-scene validation passed for all 33 assets: manifold components, positive/nondegenerate geometry, UV channels, local pivots, width seams, all declared collision portals, embedded GLB textures, FBX exports and an actual GLB passage reimport with matching bounds. The complete library has **34,804 visual triangles**; individual frontages range from **924 to 4,928 triangles**. Each visual export uses one material. Rendered catalogue, detail and snapped-assembly views were inspected.

## Roblox acceptance procedure

1. Import one visual, preferably F01, into a temporary Studio place. Confirm nominal seam width **12 studs** and height **18 studs**. Apply a single consistent import scale to the complete kit; do not separately stretch visual and collision components.
2. Preserve the authored origin when making the imported hierarchy a Model. Set its pivot to the intended front-centre floor origin. If the importer recentres it, use the manifest bounds/seam locations to restore the pivot before snapping.
3. Use the visual mesh with collision disabled. Import its separate collision set, or recreate the manifest's simple boxes as anchored invisible Parts. Keep the same root transform and scale. Do not use one convex hull for an entire doorway or passage—it would close the aperture.
4. Check that imported PBR maps are assigned correctly. GLB metallic/roughness packing is exporter-managed; the original separate PNG roughness and metalness maps are available for manual SurfaceAppearance setup if needed. Verify normal-map orientation under Studio lighting. Reuse the same uploaded atlas texture IDs across assets instead of uploading duplicate copies per mesh.
5. Walk a player and the configured enemy through every open portal. Check thresholds, the F02 recess, the F08 rear connection, and F11's terminal balcony. Attach actual floor/interior modules to open rear sockets.
6. Snap 12+16+24 units side by side and inspect seams. Stack F10 above a normal 18-stud seam. Check F12 separately because its upper room occupies the next band. Test streaming, material appearance and performance before using the kit city-wide.

## Regeneration

The generator replaces its own output directory's files and clears the active Blender scene. Run it in a fresh background process rather than an unsaved working scene:

```sh
flatpak run --filesystem=/tmp org.blender.Blender --background --python-exit-code 1 \
  --python /home/deck/Projects/Enfleshed/assets/blender/scripts/lower_layer_frontage_kit_v1.py -- --render

flatpak run --filesystem=/tmp org.blender.Blender --background \
  /home/deck/Projects/Enfleshed/assets/blender/generated/lower_layer_frontage_kit_v1/lower_layer_frontage_kit_v1.blend \
  --python-exit-code 1 --python \
  /home/deck/Projects/Enfleshed/assets/blender/scripts/verify_lower_layer_frontage_kit_v1.py
```

`--output-dir` selects another destination. Without `--render`, geometry, atlas, exports, catalogue and manifest are generated without spending time on preview renders.

This is an export-ready production asset candidate with measurable assembly contracts. Final production acceptance still requires the Studio checks above; offline Blender checks cannot establish engine appearance, controller collision or target-device performance.

## Next kit

Build an **Interior Circulation + Vertical Connection Kit** next: offset vestibules, L/T junctions, shallow rooms with multiple exits, stair flights, return landings, balcony links and courtyard transitions on the same grid. It will give these entrances meaningful routes instead of leaving attractive fronts attached to empty rooms. The large ancient structural kit can then establish the enclosing macro-scale without dictating the human-scale circulation.
