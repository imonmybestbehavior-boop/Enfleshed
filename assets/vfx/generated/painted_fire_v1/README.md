# Painted fire — local import bundle

Four 1024×1024 RGBA PNGs, one each for front, three-quarter, true side and rear. Original source artwork is unchanged. `manifest.json` links each export to its source hash and approval state. All four were uploaded through the connected Studio account with user authorization on 2026-10-17. `published_assets.json` records actual returned IDs and verification evidence. Projectile runtime integration remains pending.

## Studio playback evidence

All four ImageLabels reported `IsLoaded=true` in a Studio client playtest. The synchronized 8 FPS review advanced from 201 to 219 frame updates and from 25 to 27 completed loops during a 2.25-second observation. The captured review displays all four views without a black rectangle around the art. See `studio_playback_verify_receipt.json` and `assets/vfx/previews/studio_directional_playback_0.jpg`.

The initial raw-string `ContentProvider:PreloadAsync` checks reported `Failure` for all four IDs, including a later repeat. These receipts are preserved rather than relabeled as successful preload checks. Actual image display and client playback succeeded. Metadata confirms image assets (AssetTypeId 1) owned by Studio user 11710760568. This verifies the uploaded artwork's playback, not the moving projectile, camera-angle transitions or combat lifecycle.

## Packing and playback

Each original sheet has eight square cells in a 4×2 arrangement with fractional pixel boundaries. `tools/vfx_pipeline/pack_directional_fire.py` samples each complete source cell into a 232×232 image, places it in a 256×256 cell with a uniform 12px transparent gutter, then packs sixteen cells in a 4×4 atlas. The sequence is `0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7`: eight original frames repeated twice, without invented in-betweens. At 8 fps the visual cycle remains one second. Fixed framing preserves the source animation's movement rather than fitting each frame independently.

This standard-grid export targets the existing project's `Grid4x4` resolver. Roblox also documents custom flipbook layouts, but the current resolver does not support those. See the [ParticleEmitter reference](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) for layout, rate, random-start and blending behavior. Packing is not a proof of Studio compatibility or visual quality.

Regenerate and validate:

```powershell
python tools/vfx_pipeline/pack_directional_fire.py
python tools/vfx_pipeline/pack_directional_fire.py --validate-only
python tools/vfx_pipeline/build_fire_angle_review.py --packed
```

The validation checks decoded format/size, every frame's transparent gutter, exact repeated-frame equality, export hashes and unchanged source hashes. Local browser checks confirmed all four views load, frame stepping wraps 8→1, and no console errors were reported. `assets/vfx/previews/packed_fire_angle_review.html` is the self-contained packed-art preview.

## Remaining integration

1. Review the three-quarter view's final acceptance; the front, true side and rear have explicit motion/look approvals. Review packed exports for loss of detail or border artifacts.
2. Upload is complete; reuse the IDs in `published_assets.json`. Do not upload duplicate assets or publish a place implicitly.
3. Studio client image loading and playback are verified. Add the approved assets to the existing registry with the recorded verification scope.
4. Add the camera-angle selection layer to the existing client signature renderer, aligned to authoritative projectile velocity. Eight-frame phase must survive view changes. Use white/unmodified color multiplication for the colored artwork; existing tinting needs an explicit art decision. Avoid layering multiple opaque core sprites or random independent start frames when synchronizing viewpoints.
5. Verify near/far/mobile readability, angle transitions, cast/impact/expiry and cleanup in Studio. The browser proof is not the finished gameplay effect.

There is no separately authored 135° rear three-quarter or elevation view. The review uses discrete nearest-view selection and labels the camera angle; it does not promise continuous 3D coverage. Frame registration, brightness differences between views, phase continuity, and shader/material appearance remain Studio checks.
