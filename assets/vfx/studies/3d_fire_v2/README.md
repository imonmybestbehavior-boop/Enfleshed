# Hooked flame revision

This revision replaces the first study's broad flaps with tapered returning hooks. The approved four-color palette is pixel-identical to v1. It uses authored solid meshes and a UV palette; no new generated artwork or external resources were required.

## What changed

- Eighteen staggered tongues: eight silhouette tongues and ten moving body tongues.
- Swept bases, developing crests and narrowing return curls. The body tongues follow a rounded leading volume while silhouette tongues extend into the wake.
- Continuous frames through the crest. A projection-based frame had reversed at the hook; the new frame construction keeps the bend direction consistent.
- Paired width rails implement growth and narrowing through translations/rotations. No bone-scale animation is required.
- Each tongue uses 22 deformation bones, one nondeforming root, one material and at most four skin influences per vertex.
- Near-zero-width tongues are hidden in the Blender preview to conceal reset wires. This visibility rule needs a client equivalent; it is not baked into FBX.

## Review

`review.html` is a self-contained player with fixed-camera, orbit and isolated-tongue views. Its previous-construction comparison can be expanded. `fixed.gif`, `orbit.gif` and `diagnostic.gif` are portable loops. A smaller web player is served at `http://127.0.0.1:8766/fire_3d_study.html` when the existing preview server is running.

The single-tongue view deliberately keeps its camera fixed so head-to-tail displacement can be distinguished from shape deformation. The orbit uses the same animation clock as the fixed view.

Browser review: all three views loaded; pause, scrubbing to frame 18, and resumed playback were checked. `browser_review.png` records the fixed and orbit views at frame 18. The earlier all-inline web player exceeded the browser control transport limit; the served version now loads local frame files while the standalone `review.html` remains self-contained.

The shapes are more continuous and tapered, but the repeated hook motif and some open gaps remain visible. This is a new shape/motion study, not an accepted full fireball or a finished production effect. There are no separate breakaway fragments yet.

## Validation and import state

`validation.json` records normalized weights, four-influence maximum, per-tongue movement, exact loop closure, near-unit bone scale, right-handed pose matrices, and an FBX roundtrip retaining one mesh, 23 bones and an animation action. The exported palette was compared pixel-for-pixel with the approved v1 palette.

`hooked_flame_study.blend` contains the complete source. `single_hooked_tongue.fbx` is the corrected-scale minimal import candidate, with `cel_palette.png` alongside it. This revised rig has not been imported into Studio. The earlier v1 imported rig and its Studio verification remain unchanged. No new Roblox asset ID or performance claim is assigned to this revision.

The construction has 396 deformation bones across eighteen meshes. It is a study, not a demonstrated production budget. Reduce controls, instance count and distant detail after the motion and silhouette are accepted.

## Reproduce

Run `build_3d_fire_tongues.py` in Blender background mode, then `validate_3d_fire_tongues.py` in Blender. Run `package_3d_fire_review.py --version 2` with Python to assemble previews. All three tools live in `tools/vfx_pipeline/`.
