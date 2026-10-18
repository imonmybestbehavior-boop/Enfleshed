# Connected fireball motion study

This v4 study replaces the rejected separate curled-mesh body with one closed, connected mesh. The rounded head remains filled; moving four-color contours cover the body, and transparency erodes the wake. The user approved this Blender appearance. No detached fragments are included yet.

The geometry uses 72 deforming bones with translation-only motion and at most four skin influences per vertex. The bone loop is 48 frames at 24 FPS; 24 complete RGBA UV textures play at 12 FPS. These are procedurally authored textures, not newly generated AI artwork or the previous illustration sheets.

`review.html` is the standalone fixed-camera/orbit/core-closeup player. `connected_fireball.blend` has native synchronized image-sequence playback. `connected_fireball.fbx` exports the skinned mesh and baked bone action; it does not transfer texture-sequence playback into Roblox.

Regeneration, from the project root with Blender's `--background --factory-startup --python`:

1. Run `tools/vfx_pipeline/build_connected_fireball.py -- PROJECT_ROOT`.
2. Run `tools/vfx_pipeline/configure_fire_surface_sequence.py -- PROJECT_ROOT` to configure native source playback.
3. Run `tools/vfx_pipeline/validate_connected_fireball.py -- PROJECT_ROOT`.
4. Run `tools/vfx_pipeline/package_3d_fire_review.py --version 4` with the bundled Python.

Validation checks topology after welding the UV seam, skin weights, loop closure, core texture changes, alpha coverage, seam equality and an FBX reimport. The native sequence render at frame 17 matches the manually synchronized preview to within one 8-bit channel value at one pixel. Browser pause, scrub and playback were checked. These checks do not establish visual acceptance.

This version has **not been imported or tested in Studio**. The proposed Studio experiment is a skinned mesh plus synchronized ColorMap frames and SurfaceAppearance transparency. Appearance, supported playback approach, texture memory and runtime cost still need verification. The old v1 asset IDs must not be reused as v4 IDs. Gameplay remains unchanged.

The 24 frames have now been uploaded with explicit authorization, and isolated surface templates are prepared in Studio. Image loading remains unverified after a failed first fetch check. See `STUDIO_IMPORT.md` for the single manual FBX import step and remaining verification.
