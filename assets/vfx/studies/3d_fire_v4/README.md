# Connected fireball motion study

**Runtime update (2026-10-18):** this body is integrated into fire projectile rendering, packaged for Rojo, and verified through three real server-validated casts. Pooling, cleanup, orientation and budgets pass. Foreground captures now show the body and tapered tail under game lighting. Unconstrained graphics performance and batch-spawn hitches remain open: even the empty-scene control renders near 15 FPS in this Studio session. See [RUNTIME_INTEGRATION.md](RUNTIME_INTEGRATION.md) for measurements; the study notes below describe the earlier isolated preview.

This v4 study replaces the rejected separate curled-mesh body with one closed, connected mesh. The rounded head remains filled; moving four-color contours cover the body, and transparency erodes the wake. The user approved this Blender appearance. No detached fragments are included yet.

The geometry uses 72 deforming bones with translation-only motion and at most four skin influences per vertex. The bone loop is 48 frames at 24 FPS; 24 complete RGBA UV textures play at 12 FPS. These are procedurally authored textures, not newly generated AI artwork or the previous illustration sheets.

`review.html` is the standalone fixed-camera/orbit/core-closeup player. `connected_fireball.blend` has native synchronized image-sequence playback. `connected_fireball.fbx` exports the skinned mesh and baked bone action; it does not transfer texture-sequence playback into Roblox.

Regeneration, from the project root with Blender's `--background --factory-startup --python`:

1. Run `tools/vfx_pipeline/build_connected_fireball.py -- PROJECT_ROOT`.
2. Run `tools/vfx_pipeline/configure_fire_surface_sequence.py -- PROJECT_ROOT` to configure native source playback.
3. Run `tools/vfx_pipeline/validate_connected_fireball.py -- PROJECT_ROOT`.
4. Run `tools/vfx_pipeline/package_3d_fire_review.py --version 4` with the bundled Python.

Validation checks topology after welding the UV seam, skin weights, loop closure, core texture changes, alpha coverage, seam equality and an FBX reimport. The native sequence render at frame 17 matches the manually synchronized preview to within one 8-bit channel value at one pixel. Browser pause, scrub and playback were checked. These checks do not establish visual acceptance.

This version is **imported and visually verified in an isolated Studio client preview**. One skinned mesh combines synchronized bone motion with prepared SurfaceAppearance frame switching. Controlled side frames show changing core contours; front and rear screenshots verify the volume and alpha erosion. The actual mesh ID, measurements and evidence are in `imported_review.json`. Gameplay, combat lighting and performance verification remain pending.

All 24 frames load in client ImageLabels despite the preload API reporting Failure. Sampled surface frames visibly render. Earlier blank 3D captures resolved when the user brought Studio to the foreground; do not treat those captures as evidence of a surface-switching or skinning defect. The clean preview is left playing with Pause, Side / Orbit and Close test controls. The original import and gameplay renderer are unchanged.
