# Painted fire source artwork

## Authoring workflow preference

The user prefers to generate artwork outside this project using prompts supplied here. Do not invoke image generation for additional views or revisions unless the user explicitly requests that generation. Supply a focused prompt, receive the resulting image, then inspect, preserve, preview and integrate it locally. This preference was stated on 2026-10-17; no claim about total account token/credit savings is established.

## Directional views

`animation/core_flow_front_v1.png` is the front counterpart created before that preference was stated. The user approved its look on 2026-10-17. `animation/core_flow_user_v1.png` remains the approved side animation. The user supplied `animation/core_flow_three_quarter_v1.png` as the 45° candidate. Its RGBA source bytes and 1774×887 dimensions are preserved and hashed in `directional_manifest.json`. The three-quarter candidate is close to the side-view silhouette; foreshortening and front-face visibility still need approval.

`fire_angle_review.html` compares all three eight-frame cycles at the same frame index and selects the nearest authored view as the angle slider crosses 22.5° and 67.5°. It does not fabricate intermediate perspective through distortion or crossfades. Browser verification confirmed the three-quarter and side buttons select their intended views, synchronized playback loads, and no console errors were reported during that check. Rear artwork remains pending and should be requested through a user-run prompt. No new assets were uploaded or integrated into Roblox.

The subsequent `animation/core_flow_true_side_v1.png` is the user's true 90° candidate: its bright leading rim is edge-on and the flame folds stream backward. This 1774×887 RGBA sheet is preserved byte-for-byte and now occupies the 90° review slot with approval pending. The earlier `core_flow_user_v1.png` remains in the manifest as `previous_side`; the comparison checkbox switches it back into view without changing the current frame. Its original side-angle label is under review following the user's observation that it reads closer to 45°. Browser checks confirmed both comparison states load without console errors. Original files and prior motion approval are preserved.

User-supplied originals are preserved byte-for-byte. `inspection.json` records their hashes, dimensions and alpha bounds. `fireball.png` is the initial long-tail illustration; `core.png` is the later compact core; `trail.png` and `impact.png` are the matching ribbon and impact artwork.

## Local motion review

The rear eight-frame sheet is preserved as `animation/core_flow_rear_v1.png`. The user approved its look on 2026-10-17. The angle preview now includes front, three-quarter, true side and rear, plus frame scrubbing and synchronized 2×2 comparison. All provided source sheets remain byte-for-byte intact.

`assets/vfx/generated/painted_fire_v1` contains the local padded export bundle, with validation and import notes in its README. `python tools/vfx_pipeline/build_fire_angle_review.py --packed` builds a separate preview of those exports. No uploaded IDs or Studio verification are claimed for them.

The latest user-supplied 4×2 animation sheet is preserved as `animation/core_flow_user_v1.png`, with its source hash in `animation/user_flow_manifest.json`. Run `python tools/vfx_pipeline/build_fire_flow_review.py` and open `assets/vfx/previews/fire_flow_review.html` for **plain eight-frame playback**. This is the current motion-review candidate: no shader, frame blending, added flame layers or whole-image transforms. Controls provide 6/8/12/16 fps, previous/next, frame scrubbing and backdrop contrast. The original sheet is 1774×887 RGBA, so normalized source rectangles have fractional boundaries. Production packing and the loop's visual approval remain pending.

Run `python tools/vfx_pipeline/build_painted_fire_preview.py` from the repository root. Open `assets/vfx/previews/painted_fire_preview.html` in a browser. The page is self-contained and embeds the unchanged source PNGs.

The preview combines formation, flight, ribbon and impact timing, with size/speed controls, timeline scrubbing, trail visibility and a light/dark backdrop. The initial sixteen-frame sheet `animation/core_contours_v1.png` was rejected by the user because it read as a bending/squashing illustration. It is retained as historical source and is no longer loaded by the preview. No textures have been uploaded or assigned new asset IDs.

The replacement uses `tools/vfx_pipeline/painted_fire_layers.js`, a local WebGL motion study. One compact painted core stays spatially stable while up to twelve rear and eight front flame tongues have staggered births, independent growth, backward flow, local curls, erosion, breakup and fading. Five small wisps follow independent paths. The tongues use the new image-generated `animation/flame_lick_v1.png`; exact prompt and source hash are saved. Low-alpha haze in that generated source is suppressed by the shader rather than modifying the source PNG. Whole-core pulsing, squash, rotation and flight bobbing were removed. The stationary lower comparison, flame-layer count, activity controls and motion stepping isolate the flame behavior from projectile travel.

Browser verification confirmed shader compilation, visible layered output and control operation. Final console checks and user art approval must still be assessed for each revision. This browser shader is not a Roblox module and does not establish production performance, seamless-loop quality or runtime acceptance. The same behavior must be implemented with the existing Roblox signature layers and approved animation artwork, or baked after visual approval. Ribbon and impact contour animation remain pending; source artwork and authoritative gameplay timing are preserved.

The user approved the preview timing on 2026-10-17. `motion_reference.json` records the exact phase boundaries and how to bind them to authoritative events. This approves the timing study only. In particular, the preview's travel duration must never replace actual projectile movement or hit timing.

## Next production steps

1. Review the layered motion at normal and small sizes. Tune how the ribbon joins the core and how the impact replaces flight.
2. Prepare padded project-budget exports without changing the originals. Inspect very faint alpha outside the main silhouette and retain painted edges. The source resolution exceeds the current 1024px project export budget.
3. Author evolving flame silhouettes and one-shot impact breakup. The current ribbon is not validated for seamless tiling. Use the existing signature renderer rather than a separate gameplay effect.
4. After artwork upload is authorized, publish approved exports to the intended Roblox creator, record returned image IDs, and verify callback fetch status in Studio.
5. Bind those assets to the existing compositional Fire layers. Verify cast, release, flight, collision/impact and cleanup without altering server mechanics. Capture the actual Studio result before marking the fireball complete.
