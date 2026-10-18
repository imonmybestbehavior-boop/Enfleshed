# 3D fire transport study — first construction

This is a Blender animation study, not a completed fire effect or a Roblox capture. The user's concept sheet is preserved at `assets/vfx/source/3d_fire_v1/concept_sheet.png`.

User feedback: colors and cel-shaded style approved; the geometry does not yet read as fire. Preserve the color treatment while revising the silhouettes and motion.

## Imported-rig result

The user imported the first FBX as `Workspace.single_flame_transport.Flame_00`. Studio inspection found 22 bones, mesh `rbxassetid://116032385577570`, and texture `rbxassetid://81127106843904`. Both asset fetch callbacks returned Success; CreateMeshPartAsync also succeeded. The first import was approximately 100 times larger than intended (154.50 × 44 × 600 studs). An isolated clone was scaled to 1.545 × 0.44 × 6 studs for testing. The original import was not resized or edited.

A client ViewportFrame review visibly showed the mesh posed from the Blender bone data, with its palette retained (`studio_client_deformed_0.jpg`). A time-driven sequence then advanced from 80 to 113 frame updates during a 2.2-second observation (`studio_import_animation_verify.json`). This verifies visible skin deformation and client pose updates, not the complete fire effect or runtime performance. Editor/CoreGui review captures were blank and are not successful visual proofs.

The probe intentionally omits Blender's per-bone scaling because it uses rigid CFrame poses. Birth/death width changes in the Blender study have therefore not been reproduced in Studio. The next rig must implement the shape changes using supported transforms or a revised skin/control layout; do not call the imported motion a complete visual match.

The generator's FBX export scale is corrected to 0.01 for subsequent exports. The earlier imported FBX is retained as `imported_first_export.fbx`. No reimport is needed for this first rig check; the next geometry revision should include the corrected scale.

## Review

Open `review.html` for synchronized fixed-camera, orbit and isolated-flame playback with pause, frame scrub and half speed. `fixed.gif`, `orbit.gif` and `diagnostic.gif` are portable versions. The source scene is `fire_transport_study.blend`.

The study uses 24 solid skinned flame patches, each with 21 deformation bones and one nondeforming root. Patches follow staggered head-to-flank-to-tail paths. Width grows at birth and collapses at expiry; tips develop curls. The four-color UV palette is authored data, not AI-generated artwork. All visible forms are custom meshes. No static sphere or billboard core is present.

## Findings and limitations

The construction demonstrates moving, deforming geometry and an exact loop. The current art still has broad plate-like patches, angular interlocking edges, narrow tail wires and visible gaps. It does not yet match the fluid shapes in the concept sheet. It has no separately detached fragments. Selective color bands and hidden-reset behavior need further refinement from rear/elevated views.

This intentionally dense study is not a production budget: 504 deformation bones across 24 patches. No runtime performance claim is made. Reduce the rig and instance count after finding a successful silhouette and motion path.

`validation.json` checks normalized vertex weights, one material per patch, movement across the loop, first/last-frame equality and a single-flame FBX roundtrip in Blender. It does not establish Roblox import or rendering compatibility.

The review player was opened in the in-app browser. Pause, frame scrubbing to frame 13, and resumed playback were checked. `browser_review.png` records the page at frame 13. There is no recorded user approval for this first construction's appearance.

## Minimal Studio import test

The connected Studio MCP exposes no local FBX import tool. `single_flame_transport.fbx` is a concrete minimal test file: one mesh, its skeleton, and baked animation. `cel_palette.png` is its external color texture. The user completed the first import; its observed results and limitations are recorded above and in `imported_rig.json`.

To import manually, use Studio's Home → Import control and select `single_flame_transport.fbx`. Keep the custom skeleton/skinning, inspect warnings, and import into an isolated test model. If the palette does not appear, retain the simple model for the deformation test; production material setup is a separate check. Import the baked animation through the Animation Editor if Studio does not bring it in with the model. Do not publish the place for this test. See [Roblox's importer documentation](https://create.roblox.com/docs/studio/importer).

Studio MCP inspected the bones and IDs, verified asset fetch, and displayed the posed skin in a client review. The temporary review was removed and Studio returned to Edit mode. The first imported model was preserved.

## Regeneration

Run `tools/vfx_pipeline/build_3d_fire_study.py` in Blender background mode, then `tools/vfx_pipeline/validate_3d_fire_study.py` in Blender and `tools/vfx_pipeline/package_3d_fire_review.py` in Python. The generator writes only this study folder. The optional `--stills-only` mode is for interim silhouette checks; regenerate all frames before packaging a changed study.
