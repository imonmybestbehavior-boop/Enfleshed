# Lower Layer Storefront Street V1 — Roblox import guide

This package is the first playable-scale export of the approved Blender street. It is a test section, not a replacement for the generated city.

## Files

- `lower_layer_storefront_street_v1_visuals.glb` — eleven bounded visual groups with collision disabled after import. Every individual mesh remains within Roblox's 20,000-triangle limit.
- `lower_layer_storefront_street_v1_collision.glb` — simple floors, walls, barriers and stair ramps. These become invisible collision.
- Matching `.fbx` files — fallback format if GLB import is unavailable.
- `lower_layer_storefront_street_v1_roblox_export.blend` — editable export copy. The approved review blend remains separate.
- `ConfigureImportedStreet.luau` — Command Bar setup helper.
- `export_manifest.json` and `reimport_verification.json` — geometry and file checks.

GLB is the preferred format because Roblox's current Blender guidance says it avoids FBX's additional scale configuration. The package remains authored in metres. Roblox's importer supports a **Meter** scale unit and converts that unit into studs.

## Import into a Studio test session

1. Open `/home/deck/Projects/Enfleshed/Enfleshed.rbxlx` in Roblox Studio.
2. Save a separate test copy before importing. Do not replace the current generated city yet.
3. Use **File → Import 3D** and choose `lower_layer_storefront_street_v1_visuals.glb`.
4. In the Import Preview settings:
   - enable **Import Only as a Model**;
   - enable **Insert Using Scene Position**;
   - set **World Forward** to **Front**;
   - set **World Up** to **Top**;
   - set **Scale Unit** to **Meter**;
   - leave upload disabled for this first local test unless you specifically want reusable uploaded assets.
5. Import `lower_layer_storefront_street_v1_collision.glb` using exactly the same settings.
6. In Workspace, create a Model named `StorefrontStreetPilot` and move both imported models into it without changing either model's position, rotation or scale.
7. Open **View → Command Bar**. Paste the contents of `ConfigureImportedStreet.luau` and press Enter. It anchors everything, disables visual-mesh collision, makes the collision package invisible and solid, and creates a blue test spawn plus five green shortcut markers.
8. Paste `RunStreetPilotCheck.luau` into the Command Bar. Continue only when Output prints `STREET PILOT READY`. This checks imported mesh counts, scale, anchoring, collision settings and the required route pieces.
9. Move the parent `StorefrontStreetPilot` model as one unit to an unused test area. Do not move its imported children separately. If you move it after creating the spawn and markers, they move with it.

## Scale checks before playing

With **Scale Unit: Meter**, the expected approximate Studio sizes are:

- main street clear width: **25 studs**;
- shop frontage: **14.3 studs**;
- clear door height: **7.9 studs**.

These are close to the existing 22-stud civilian streets while keeping doors human-scaled. If the imported street is dramatically larger or smaller, delete both imports and repeat the import with **Meter** selected. Do not compensate by scaling only one of the imported models.

## Focused playtest

1. Spawn or move a test character to the street entrance.
2. Walk, sprint and dash along the direct street. Confirm the checkpoint barriers create a slower exposed route without trapping the character.
3. Enter **Court 17**, continue through its rear opening, cross the courtyard and walk up the invisible ramp over the visible stair.
4. Cross the catwalk, descend the alley ramp and return to the street on the far side of the checkpoint.
5. Enter each shop. Check the threshold, camera clearance, counters, awnings and whether the shallow interiors feel useful rather than oversized.
6. Toggle **Collision fidelity** in Studio's viewport visualization. Confirm collision comes from the simple `COL_` meshes, not the detailed storefronts.
7. Test one Nascent and one civilian or guard. Confirm they can use the street and do not repeatedly choose the decorative shop interiors as through-routes.
8. Test two clients if possible and watch client/server frame time. This pilot has eleven visual meshes and a bounded set of box colliders, but its material and streaming cost still needs measurement in Studio.

Record problems by object name. Every collision object begins with `COL_`; every visual group begins with `VIS_`.

## Expected limitations

- Plain Blender materials may not exactly match their Blender appearance after import. A texture-baking pass comes after scale and traversal are accepted.
- The collision package uses smooth ramps over visible steps for reliable Humanoid movement.
- No NPC routes, event locations, shop interactions or checkpoint guards are added by this package.
- The package is not wired into the Rojo world generator and does not modify `Enfleshed.rbxlx` automatically.
- Importing and the live traversal check must be completed in Roblox Studio because mesh uploads and Studio physics are outside the offline Blender build.

Official references: [Blender to Studio import settings](https://create.roblox.com/docs/art/blender), [collision fidelity](https://create.roblox.com/docs/workspace/collisions), and [environment performance guidance](https://create.roblox.com/docs/performance-optimization/improve).
