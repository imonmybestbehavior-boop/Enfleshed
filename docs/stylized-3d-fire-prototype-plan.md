# Stylized 3D fire prototype

Date: 2026-10-17. Status: connected-volume Blender study implemented; visual acceptance and Studio verification pending.

**Current direction supersedes the curled-patch body proposal below:** after v3 the user rejected the fireball likeness and requested footage review. See `docs/fireball-reference-reset.md`. Preserve the approved palette, but rebuild around a coherent animated burning volume rather than separate C-shaped meshes. No further manual import should be requested merely to continue refining the rejected construction.

Current v4: `assets/vfx/studies/3d_fire_v4/` contains one connected animated mesh, moving UV contours, rear alpha erosion, fixed/orbit/closeup review loops and source/export validation. The source supports native texture-sequence playback. This is still a form and motion study; the surface sequence has not been implemented in Roblox, and performance has not been profiled.

Progress: the first Blender construction study is available at `assets/vfx/studies/3d_fire_v1/review.html`, with fixed-camera, orbit and isolated-flame loops. Skin weights, source loop closure and an animated single-flame FBX roundtrip pass. The current shapes remain plate-like and have not passed the concept-sheet visual target. Studio import, performance profiling and gameplay integration remain pending. The new user-supplied concept sheet is preserved at `assets/vfx/source/3d_fire_v1/concept_sheet.png`.

Import follow-up: the user imported the single-flame rig. Its mesh and texture fetch successfully; all 22 bones are present. An isolated client clone visibly deformed from source poses and advanced animation updates. See `assets/vfx/studies/3d_fire_v1/imported_rig.json`. Full-effect acceptance, Blender width-scaling parity, performance and gameplay integration remain pending. The user approved the colors/style but explicitly said the shapes do not read as fire. The next art pass must preserve the palette and revise the flame construction. The first export had a 100× scale discrepancy; subsequent export settings were corrected, with next-import validation pending.

Shape revision: `assets/vfx/studies/3d_fire_v2/` contains tapered hooked tongues, a staggered full-body study, and fixed/orbit/isolated loops. The palette is unchanged. Paired width rails remove the previous dependency on bone scaling. Source and FBX checks pass, with four skin influences maximum and an exact loop. This revision has not been imported, visually accepted or performance profiled. Repeated hook shapes and open gaps remain review points.

Directional correction: the user found v2's curls too outward-facing. `assets/vfx/studies/3d_fire_v3/` redirects the curls around the projectile shell and tapers their centerline radius toward the wake. Keep v2 for comparison. This correction changes flow direction rather than replacing the approved palette or requesting more artwork.

## Target

Create one animated 3D fireball with the graphic readability of cel-shaded adventure art and the sweeping, ornamental flame motion of illustrated anime combat. The result should be original and belong in Enfleshed's dark fantasy environments.

The central requirement is transport through the body: fresh flame forms emerge from the interior, expand over the front and flanks, stretch into the wake, curl, separate and disappear. The central surface must visibly renew. A static core surrounded by moving decorations does not meet the target.

The first deliverable is an isolated fireball study. Expansion to other spells follows only after its motion, imported appearance and cost have been demonstrated.

## Existing resources and state

- Blender 5.2 is installed. The existing Python pipeline authors and exports static meshes, UVs and Blender look-development previews.
- Studio MCP is connected. Four painted directional atlases were uploaded and verified in a client playback review. Keep these as reference and an optional comparison; more angle sheets are unnecessary for the 3D approach.
- Existing core and shell meshes are static asset experiments, not a proven flame animation rig.
- The client signature planner/renderer already owns attachment, travel direction, quality tiers, distance culling and effect cleanup. Keep the new effect within that lifecycle.
- Directional sprite integration is an unfinished, opt-in study (`Renderer.UseDirectionalSprites = false`); it has not been activated in Studio. Preserve it without treating it as the production solution.
- Server movement, collision, damage, cost and timing remain authoritative. Visible geometry must be authored custom meshes.

## Visual specification

- Start with three dominant bands: deep vermilion recesses, orange flame bodies, golden-yellow crests. Use small cream-hot accents rather than a white glowing ball.
- Use a few large interlocking curls and tapered tongues. Secondary curls should reinforce the main flow rather than add random noise.
- Give the front a compact, rounded leading volume; let flanks open into negative spaces and a broken, tapering wake.
- Favor opaque painted color shapes and restrained emission. Review with bloom disabled so bloom cannot hide weak geometry.
- Evaluate dark internal seams and selective contour accents. A thick black outline around every flame risks making it look like solid plastic.
- Use smooth temporal travel with deliberately shaped curling and snapping poses. Test stepped accents separately; do not decide an animation rate from the old eight-frame artwork.
- Form must remain readable from front, rear, side, above, below and oblique views. No view-specific image swapping in the 3D body.

## Proposed construction

Author a small family of solid, tapered flame patches in Blender. Rig each patch with a short bone chain so its base, middle and tip can deform independently. These patches form overlapping layers around a small interior volume, including the visible core surface.

Animate patches through staggered lifecycles:

1. Conceal the reset pose inside the body.
2. Grow a new ridge out of the interior, establishing a clear hot crest.
3. Move and deform that ridge over the body toward the rear; neighboring patches overlap to keep the body coherent.
4. Extend the tip into a curl, narrow the connection and transition to a separate small fragment where appropriate.
5. Collapse the fragment at the rear and recycle it while hidden. Avoid an obvious transparent crossfade through intersecting sheets.

Do not merely rotate a fixed shell or make tongues oscillate around fixed roots. The visible ridges must move between front, flank and rear regions. Fixed mesh topology cannot literally split; stage the split through overlapping authored pieces and hidden lifecycle transitions. Test those transitions from rear and elevated cameras before adding detail.

Start with one patch and two overlapping lifecycles. Only build a full surrounding set once the transport reads correctly. The exact mesh count, bone count, loop length and travel paths are prototype findings.

## Roblox implementation route

Use skinned meshes exported as FBX and test a minimal import immediately. Roblox documents imported skin weights and Bone instances that can pose the visible mesh independently of collision geometry. FBX carries rig and skinning data. Sources: [Rigging and skinning](https://create.roblox.com/docs/art/modeling/rigging), [Blender export settings](https://create.roblox.com/docs/art/modeling/export-requirements).

Preferred first test: a custom skinned flame patch driven by deterministic client bone poses, with the same motion sampled in the Blender preview. Verify this path in Studio before committing the complete asset. Baked animation clips remain an alternative if the procedural posing/import path proves inadequate.

Build the cel-like appearance from authored color regions and painted textures that can be tested in Studio. Do not assume Blender toon nodes, geometry-node evaluation, procedural materials or simulation caches transfer as working Roblox effects. A Blender beauty render is an art preview, not evidence of in-game compatibility.

Store motion controls as reusable recipe parameters: body size, flow rate, curl amount, wake length and turbulence amount. Map them through the existing normalized spell features, never through spell names. Keep the renderer client-only, attach it to the existing projectile anchor, and follow actual travel on curved paths.

## Milestones and acceptance

| Stage | Deliverable | Pass condition |
|---|---|---|
| 1. Transport study | One plain-color rigged patch, a short loop and front/side/rear views | A ridge is born inside, travels across the visible body, curls and exits; no stationary painted core |
| 2. Import proof | Same patch posed inside Studio | Skinning, scale, orientation, appearance and pose updates work; evidence saved |
| 3. Full body | A staggered set of patches, interior volume and limited breakaway pieces | Continuous renewal, believable overlap and no visible reset from an orbiting camera |
| 4. Art pass | Authored cel bands, selected accents and restrained lighting | Strong silhouette and color separation at combat distance in Enfleshed lighting |
| 5. Runtime integration | Reusable signature layer and registered imported assets | Correct travel direction; size/speed variation; impact, cancellation, expiry and cleanup work |
| 6. Cost and reuse | Measured single/multiple-projectile review and quality variants | Record real timings and counts; reduce patch/bone/detail cost while preserving the primary motion |

At each visual stage, show both an orbit and a fixed-camera loop. Include a single highlighted patch to make transport unambiguous. Stop and revise the construction if it reads as solid rubber, seaweed, rotating sculpture, or a still ball with trails.

Test small and large projectiles, slow and fast movement, homing turns, front-to-rear camera orbits, clipping near walls, and simultaneous effects. Verify that sessions, pooled meshes, pose updates, lights and connections return to baseline after cleanup. Performance budgets are to be measured, not asserted from triangle counts.

## External resources and collaboration

No additional paid service or connector is needed to start the motion study. Existing Blender, Studio and the supplied artwork are sufficient for that first step.

An externally generated concept sheet is optional and useful for agreeing on simplified flame shapes. It is a modeling reference, not a mesh, production texture or animation solution. Prefer a single clear side view plus front and rear studies over more eight-frame sprite sheets. Provide the prompt when requested; the user generates images outside this project unless they explicitly ask otherwise.

If a texture is useful after UV layout exists, provide that exact layout and a matching paint brief. Do not ask for arbitrary seamless fire textures before knowing how the geometry will use them.

If the user has an existing rigged stylized-fire asset or a VFX artist available, request the editable source, its license, and a short motion reference. Inspect it before assuming it solves this particular transport problem. Extra connections are only needed if the tested pipeline exposes a concrete missing capability.

## Next execution step

Author the plain-color single-patch transport study in Blender and export the minimal rig for a Studio import check. Use existing artwork while the optional concept-sheet preference is pending. Do not produce the complete asset library or activate the unfinished sprite route during this study.
