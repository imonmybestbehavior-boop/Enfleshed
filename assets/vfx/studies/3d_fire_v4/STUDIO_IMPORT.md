# Studio test handoff

**Current runtime status (2026-10-18):** import is complete and the reusable body is installed in the production signature renderer. Real casts, source/build and lifecycle checks pass. Foreground captures verify scene visibility. The rendered empty-scene control is limited near 15 FPS, and batch setup shows hitch risk, so performance acceptance remains open. No new manual import is needed. See `RUNTIME_INTEGRATION.md`; older pending notes below are historical.

**Update: import completed and isolated client playback visually verified.** The user imported `Workspace.connected_fireball.ConnectedFireVolume`, mesh ID `135760105803974`, with all 73 bones. Measured bind-position conversion matches within 0.000000084 studs. All 24 images load. Controlled side frames show changing core contours; front and rear screenshots retain the filled head and alpha wake. See `imported_review.json`. The original import and gameplay renderer are unchanged. The clean review is left playing in the Studio client.

The instructions and pending notes below record the earlier handoff. Manual import is no longer required. Current remaining work is gameplay integration, combat-lighting comparison, rear alpha refinement and performance/permission verification. Earlier blank scene captures resolved after the user brought Studio to the foreground; the single-mesh surface-switching method passed the subsequent visual check.

The user approved v4's Blender appearance and explicitly authorized uploading its 24 surface frames. All 24 upload IDs are recorded in `published_assets.json`; raw receipts and upload hashes are retained. The connected Studio instance is `Enfleshed-Defend-The-Walls.rbxlx`.

## Required manual step

In Studio, use the 3D Importer to import:

`C:\Users\bello\Documents\Projects\Enfleshed\assets\vfx\studies\3d_fire_v4\connected_fireball.fbx`

Preserve the skinned mesh and bones; import as a custom rig rather than converting it into an avatar. Insert it into Workspace. Keep the mesh name `ConnectedFireVolume` so the inspection script can find it. There is no need to upload the 24 PNGs manually. Do not rescale or remove bones to correct its appearance; the next inspection will determine imported scale and bind orientation.

The connected Studio MCP tools expose texture upload, asset insertion by existing ID and Luau execution, but do not expose local FBX import. Native desktop control is unavailable in this session. This is an import boundary, not a request to approve another design revision.

## Prepared and verified

- 24 real image asset IDs returned by the upload tool, matched to the reviewed files using SHA-256.
- `ReplicatedStorage.ConnectedFireV4Study`: 24 prepared SurfaceAppearance templates with transparency enabled. Existing gameplay effects are unchanged.
- Image metadata for frames 1, 12 and 24 reports image assets.
- Source translation deltas for 72 bones across 48 frames exported to `pose_probe.json`.

## Still pending

The first direct image preload reported Failure for all 24 images. A subsequent preload of the surface templates returned no callbacks, which is **not evidence of successful image loading**. Their availability must be checked again using visible textured meshes after import. Do not upload duplicates merely to address an ambiguous availability result.

After import: inspect the mesh ID, 73 bones including Root, size and bind positions; clone into an isolated client preview; test 24 FPS bone motion and 12 FPS surface-frame playback; inspect side/front/rear views, alpha erosion, palette and performance. Do not activate this in the spell renderer until these checks pass.

Roblox's [SurfaceAppearance reference](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance) marks ColorMap and ColorMapContent as Plugin Security. The proposed first test switches prepared surface instances rather than writing those properties from the gameplay animation loop. Its visual stability and cost are unverified.
