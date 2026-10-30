# Fireball reference review and construction reset

Date: 2026-10-17. User feedback: current studies do not look like a fireball. Stop treating this as another small curl adjustment.

## Reference evidence

- [1MaFX — VFX Fire Projectile Teaser](https://www.youtube.com/watch?v=HBkIYwhedgQ). Played the video and visually inspected flight views around 0:35 and 0:45. Saved browser captures in `assets/vfx/references/fireball_review/`. These show a bright compact leading mass, connected flame body, narrower rear breakup and secondary trails. The effect is a form/motion reference, not the proposed final cel-shading treatment.
- [1MaFX — Fire Projectile VFX Breakdown](https://www.1mafx.com/blog/fire-projectile-vfx-breakdown). The creator describes a modified stretched sphere, vertex colors for glow control, a world-position-offset texture for deformation, and separate flame/smoke trail textures. This is an Unreal implementation; do not assume its material nodes transfer to Roblox.
- [ZeldapediaVideo — Red Wizzrobe (The Wind Waker)](https://www.youtube.com/watch?v=Pe1qH9dWNrs). Played and frame-stepped combat footage. Useful for the graphic, hot centers and quick irregular flame/flash shapes. The sampled sequence includes mixed combat and hit flashes; it is not a clean isolated projectile turntable, and no precise fireball shape or timing measurement should be attributed to it.
- [GameIsJustAStart — Red Wizzrobe miniboss](https://www.youtube.com/watch?v=sylgNXY6API). Sampled gameplay. It is combat reference, not evidence of the game's underlying VFX construction.

The first Wind Waker HD clip did not play reliably. Do not list it as watched. Search descriptions and thumbnails were not treated as viewed animation. No reference assets were extracted for use in the game.

## Diagnosis of the current studies

The main error is construction: the fireball was assembled from recognizable, separated curled objects. Smoother hooks and changing their direction did not fix the lack of a coherent burning volume. Repeated forms, broad opaque bands and gaps make it read as leaves, ribbons or ornament. The core is not visually dominant enough.

The approved palette is still useful. The curled-mesh body construction is rejected as the main fireball body. Preserve v1–v3 as research, not as a nearly finished effect.

## Revised visual target

1. Establish a compact rounded or slightly elongated leading volume with one readable overall silhouette.
2. Keep the front substantially filled. Restrict most holes and detached shapes to the rear, rather than separating the entire body into floating curls.
3. Make flame contours visibly renew and travel over/through this volume toward the wake. A static sphere with added trails still fails the user's requirement.
4. Use small uneven licks that stretch, thin and disappear. Retire the repeated C-shaped motif as the dominant shape.
5. Separate large, medium and small detail: leading mass first, attached flame tongues second, sparse fragments last.
6. Preserve the approved cel palette and hard color grouping while judging whether the fire reads correctly with glow disabled.

## Next implementation gate

First produce a simple connected-volume motion study, reviewed from a fixed side view and front/rear orbit. Require it to read as a burning projectile at combat distance before adding ornamental detail, another heavy rig or requesting another manual import.

The Roblox-compatible surface-flow/deformation method still needs to be chosen and tested. The reference's Unreal shader is evidence for how that author achieved the effect, not proof that the same method is available here. Do not solve this by adding a static glowing primitive or hiding the silhouette problem with bloom.

## Connected-volume study

V4 is available at `assets/vfx/studies/3d_fire_v4/review.html`. It uses one connected mesh with a filled head, translation-only bone deformation, moving complete UV texture frames and rear alpha erosion. Source loop, texture and FBX checks pass. Native Blender sequence playback matches the rendered preview. The silhouette remains smooth and rear flame detail still needs refinement; visual acceptance is pending. No v4 Studio import, texture playback or performance result is claimed. See the study README for regeneration and scope.
