# Gallery verification — 2026-10-18

## Source and data

- Inventory checks agree across the editor schema, server form dispatch and family catalog: eight forms, nine registered examples, five construction families. Soul/Spirit Field is supported, but this gallery fixture is not registered as a playable spell.
- Four export/integrity tests pass: form coverage, protected source preservation, geometry/cache integrity and Soul loop/boundary behavior. The preservation check also hashes the existing 60 custom meshes and 71 textures; originals are unchanged.
- The approved `.blend` was opened read-only for evaluation. Its hash is checked before/after export and against the inventory snapshot. Fire uses 3,057 vertices, 6,016 triangles, 48 poses and its original 24 surface images.
- Soul uses 4,056 vertices, 6,744 triangles and 96 poses over four seconds, with separate color and visibility caches. Following user feedback, both the initial shrinking envelope and subsequent top-down wipe have been replaced by a gradual whole-wisp opacity fade. The test checks unchanged cross-section, equal body/face opacity, decreasing opacity with rising height, an exact four-second loop and a fixed boundary.
- JavaScript syntax check passes. No production client/server/configuration or original custom-asset file was changed by the gallery batch.

## Browser review

Latest phase/ground pass: the user approved the rise/fade revision, then explicitly requested full-size emergence from the floor. The body now has constant dimensions throughout birth and rise; it begins below the ground, with the underground portion clipped in the browser review. Its face follows the same placement and fade. First-cycle group delays prevent midair births during initial formation. Four geometry/source checks and the separate phase tests pass. The existing sigil source and all original custom assets remain unchanged.

The seven-second full preview was visually inspected at Gather (0.42 s), Sustain (3.00 s) and Clear (6.29 s). The existing Soul sigil renders on the floor during gather; the clear phase shows only the grid/scale figure. The browser error/warning log is empty. Phase tests cover formation, full-intensity sustain, zero remaining effect at expiry, early cancellation and deterministic replay. `soul_ground_phase.png` records the emerging ghosts in this pass.

The local gallery was opened and inspected in the in-app browser. Fire rendered as its connected source volume with original contour textures. Soul rendered as actual 3D wisps with mint/teal bands, small curved eye/mouth geometry and a stable floor boundary. `soul_review.png` records the paused revised study at frame 36. This is a review image, not user art approval.

Verified controls: select Fire/Soul, Pause/Play, scrub frame 36 and frame 82, Side/Front/Above, Orbit on/off, half speed, figure and grid toggles. Paused frame readout remained fixed across view changes. The browser error/warning log was empty after these checks. The figure is five studs tall and grid spacing is one stud. Both wide and narrow layouts were visually observed at the browser's natural sizes.

Drawing resources are created once per cached study, reused across frames, and deleted on page exit/context loss; the animation callback is canceled and the cache cleared. Hidden tabs skip drawing. These are browser resource-lifecycle provisions, not a test of a new Roblox Soul runtime. No new Soul controller or gameplay lifecycle exists yet.

## Limits and next review

The current disappearance smoothly fades the whole wisp, including its face, as its root rises from 1.55 to 2.4 studs. Transparent triangles are sorted back-to-front in the review renderer. This does not move damage, pulse or collision timing. Soul's browser cel treatment and floor clipping need a verified baked/material/rig equivalent before a Studio import; ordinary whole-model transparency can supply the fade. Gather/end phases exist only in the gallery. Field terrain conformance and production pool/cancel behavior are not implemented. Older screenshots and the initial approval snapshot are historical; the ground-emergence revision is recorded separately.

No new uploads, AI-generated artwork or place publication occurred. No new Studio performance claim is made. The prior heavily loaded Surface Pro 8 empty-scene result is not attributed to the fireball. Existing allocation observations remain open for a less-loaded profiling session.

The user clarified that existing custom effects are usable and should be restyled rather than discarded. The plan now prioritizes material/palette changes, then limited design adjustments, with rebuilds requiring a recorded reason. The existing Soul wisp reference is available in the gallery's expandable comparison; other custom assets remain available for reuse.
