# Effect family gallery 01

Current pass: the user approved the Soul rise/fade motion and then requested full-size emergence from below the ground. Spawn scaling is removed. **Full effect** now reviews Gather → Formation → Sustain → Dissipation → Clear over seven seconds, reusing the existing `soul_sigil.png` for the gather cue. **Sustain only** shows the four-second wisp cycle. **End effect** previews an early cancellation and **Restart** repeats the beginning. These are cosmetic review timings, not game timings.

Open `http://127.0.0.1:8767/studies/effect_families_v1/index.html` while the local preview server is running. The gallery uses actual 3D review geometry, no remote packages or services. Only one study draws at a time; drawing is capped at 30 Hz and skips hidden pages. Pause, scrub, change speed, drag to orbit, choose fixed views, zoom with the wheel, and toggle the five-stud figure or one-stud grid.

- **Fire:** evaluated from the approved v4 `.blend`, with the existing 24 surface images. Original source, skin and runtime remain unchanged.
- **Soul Field:** rising little ghosts with faces, delayed echoes and gradual whole-wisp fading at height. Full-size geometry emerges through the floor without spawning in midair. Rise/fade motion is approved; ground emergence and phase composition are the latest review changes. Not a new gameplay spell, exported rig or uploaded asset.
- **Inventory:** eight forms, nine registered examples, five proposed construction families. See `docs/spell-vfx-family-plan.md` for mappings, exceptions and integration stages.

Regenerate from the project root:

1. Run `tools/vfx_pipeline/audit_effect_families.py` with Python **before** editing protected gameplay/fire sources. This records the source snapshot; do not overwrite it to conceal a change.
2. Run Blender in background with `--python tools/vfx_pipeline/export_gallery_fire.py -- PROJECT_ROOT`. This only reads the approved source.
3. Run `tools/vfx_pipeline/build_soul_gallery.py` with Python.
   `prepare_soul_phase_review.py --ground-emergence-revision` records/verifies this requested revision. `approved_soul_sustain.json` retains the earlier approval snapshot; it is not overwritten to claim the changed birth was already approved.
4. Serve `assets/vfx/` on loopback port 8767 (`python -m http.server 8767 --bind 127.0.0.1 --directory assets/vfx`).
5. Run `tests/test_effect_family_gallery.py` to verify coverage, data integrity, source preservation and the animation loop. Check the actual browser appearance separately.
6. Run `tests/test_soul_review_phases.mjs` with Node to verify phase boundaries, full disappearance, early cancellation and deterministic review playback.

`effect_families.json` is the authoring catalog; it is not wired into production. Binary position/color caches are little-endian float32, indexed by frame then vertex. `*.mesh.json` contains topology and counts. Six primary wisps plus six echoes and twelve boundary arcs are packed into the Soul cache; the reference mesh is the evaluated existing fire skin.

The browser quantizes Soul's palette for review. Roblox needs a separately verified baked/material implementation; no custom browser shader is assumed to transfer. There is no claim of Roblox GPU cost, production cleanup behavior for Soul, terrain conformance or finished phase coverage.
