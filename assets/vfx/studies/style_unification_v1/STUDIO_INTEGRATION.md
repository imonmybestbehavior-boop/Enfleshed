# Approved existing-asset restyle: Studio integration

The user authorized installing the approved baked library into Enfleshed on 2026-10-18. The integration adds 91 identity-specific texture variants and 60 existing mesh variants. Original artwork, atlas alpha/layout/frame order, spell definitions, damage, mana, cooldowns, hit detection, and networking sources are retained.

## Installed resources

- `baked/studio_uploads/uploaded.json` records every uploaded image ID, exact approved SHA-256, and original batch receipt. Repeated uploads are skipped; ambiguous attempts require receipt reconciliation.
- `studio_mesh_import.json` records all 60 MeshParts returned by Studio's actual FBX import. They remain single MeshParts with baked vertex color bands rather than multi-part material models.
- `src/shared/SpellVFXSystem/Assets/StyledVFXManifest.luau` selects an image by identity AND asset name. Original manifest IDs remain available for legacy callers and fallback.
- `src/shared/SpellVFXSystem/Assets/CelMeshLibrary.rbxmx` persists the imported mesh IDs, native mesh sizes, and normalized template sizes. The resolver prioritizes these templates. Runtime-owned mesh clones preserve vertex colors through pooling.
- The live library is under `ReplicatedStorage.Shared.SpellVFXSystem.Assets.CelMeshLibrary`. Before integration, module sources were captured in `studio_before.json`; the live place also keeps `ReplicatedStorage.VFXRestyleSourceBackup`.

The approved GLB face colors were transferred to FBX corner colors for Studio. No mesh positions, triangles, silhouettes, or animation were redesigned. Studio's FBX import expressed sizes at 100 times the authored units; template sizes were normalized by 0.01. Runtime placement still uses the original VFX manifest sizes. The importer route was verified against [Roblox's importer documentation](https://create.roblox.com/docs/studio/importer).

Colored images and colored meshes use white runtime multiplication. Generic mesh/light palette tokens use the approved bands, with SmoothPlastic and restrained emission. This deliberately replaces the previous full saturation/brightness boost and player color multiplication for the baked art. Original particle sizes, lifetime, speed, atlas rate, transparency envelope, and spell-driven scalars remain in their existing recipes.

`ConnectedFire.luau`, its rig, and its approved surface frames are untouched. Fire Projectile continues to select the connected fireball and filters its old duplicate artwork layers as before.

## Lightning correction requested during installation

The user requested a continuous spawn-to-end lightning connection instead of arc sprites being sent down the beam. Lightning's data-driven `Feel.BeamArc` selects `ArcBeam.luau`. Its main path endpoints stay exactly at local `(0,0,0)` and `(0,0,-range)`. Intermediate points and attached branches flicker at 18 changes per second. Solid palette-colored ribbons keep joints visible; no texture scrolling or travelling glyph emitters remain for this beam. Other elements retain their existing beam recipes.

The path follows the existing host transform and authoritative visual range. It never computes damage, raycasts for hits, or sends network messages. Segment and branch instances count against the existing trail/beam budget and disappear with the owning session.

## Verification and limits

- Local integrity suites verify all baked texture hashes, exact source alpha, unchanged atlas contracts, original source art, GLB geometry, receipt-to-runtime mapping, durable mesh IDs/sizes, and connected-fire source preservation.
- Planner specifications, Luau compilation, and a complete Rojo build pass.
- A normal Studio LocalScript checks all 91 identity/layout lookups, all 60 acquire/release/reacquire mesh cycles, and cosmetic rendering of all nine existing spell definitions. Lightning endpoints are checked across eight range changes. Resource counters return to zero after cleanup.
- The local review scene uses actual imported assets. Ice face bands, Soul faces, Fireball, StoneShot, and LightningLance were visually inspected. This fixture and its client-only lighting changes are removed by stopping the playtest.
- This is a visual/functional check, not a GPU performance benchmark. The Surface Pro's earlier loaded empty-scene baseline is not attributed to these effects. Published-place asset permissions and live server behavior require a separate published-session check.

The original bake manifests retain their historical `uploaded_id: null` fields. The separate receipt ledger and runtime manifest are authoritative for this installation; do not upload the original package again merely because those historical fields are null.

The local place file is backed up at `place-backups/Enfleshed-Defend-The-Walls-before-cel-restyle-20261018.rbxlx`. No place publication is part of this installation.

## Beam readability and smoke correction

User feedback identified spinning flame/drop sprites, travelling space/arcane motifs, and beam-ending smoke at the caster. `StreamBeam` now supplies a connected solid body in the approved Body/Light bands, with intersecting ribbons for depth and the existing strip artwork providing longitudinal flow detail. Fire flares toward the end; water stays narrower. Legacy fire core sprites are excluded from the stream role without changing the approved projectile.

`PathGlyphs` opens the existing rift atlas at fixed stations. Arcane uses fixed rune stations, each paired with the existing `rune_circle` geometric enclosure; both are emitted together with identical lifetime, fade, zero speed, and zero rotation speed. Arcane's other loose-rune particle/trail references now use the existing enclosed seal artwork. No new images are generated or uploaded.

Beam termination snapshots the latest host transform/range and places dissipation at its endpoint. The volume-host placement code now honors `Placement="End"` for radial smoke too. Cast cues do not acquire end-of-projectile or beam smoke.

`beam_final_check.json` contains the four-style normal-client regression: connected stream bodies, fixed motif positions, required rune enclosures, immediate move/range changes before smoke emission, caster-cue termination, and zero cleanup counters. It also reruns the 91 texture/60 mesh checks and all nine existing spells. `beam_streams_0.jpg` is the actual local Studio review capture. Planner checks and the Rojo build pass. These are visual and lifecycle checks, not a rendered-performance benchmark. Source backups for this correction are in `ReplicatedStorage.BeamStreamSourceBackup`; the place backup is `place-backups/Enfleshed-before-beam-stream-fixes-20261018.rbxlx`.

## Grounded motion and duplicate release explosions — 2026-10-19

The caster's Release cue previously had its own expanding artwork, independently of the hit/endpoint effect. SignaturePlanner now limits this cue to a restrained, short point light. SpellVFXComposer also removes its procedural release layers before attaching a signature: renderer disablement or budget exhaustion cannot reintroduce an explosion through fallback. This is a cosmetic change; Gather cues, hit anchors, damage and networking remain separate.

`FieldDynamics` gives the existing artwork distinct motion: 30 rooted flame contours over three cel ground bands; 24 short ripple cycles; 48 ground-facing geometric seals; two intermittent descending lightning strikes; 34 varied crystals using four existing meshes; 20 full-size spirits emerging from the ground and fading above it; one ground portal with nine rising shards; and three travelling curved gust ribbons. Quality and global budgets reduce density. Spirit Aura uses a separate outward/inward helix. Space forms open voids in place rather than transporting intact void pictures.

Arcane now has a continuous beam through its enclosed sigil stations. Time has a continuous beam between two endpoint clocks. Space beam stations release existing star motes. Existing Fire/Water connected streams and the approved Fire Projectile remain intact. No new artwork was generated or uploaded.

The real-client regression `scripts/studio_field_motion_check.luau` exercises all nine existing definitions at High/Low, with signatures both enabled and unavailable (36 release cases). It checks grounded modes, crystal variety, constant-size rising spirits, connected beams and zero tracked resources after cleanup. Results are in `field_check.json`. Planner/compilation, the seven asset-integrity/integration tests, and the Rojo build pass. These checks establish source integrity and simulation/lifecycle behavior, not rendered frame rate.

The regression was then extended to recheck termination after moving/resizing five beam styles immediately before Finish. That additional run timed out at the Studio bridge and is unverified; `field_check.json` retains the earlier successful release/field/beam-structure result. Earlier endpoint evidence remains in `beam_final_check.json` from the preceding correction.

`scripts/studio_field_motion_visual.luau` provides an isolated, selectable Studio review of fields, Spirit Aura and the beam motifs with a five-stud marker. The review ran, but this pass's native capture returned desktop wallpaper and the Studio screen-capture request timed out. The revised appearance has therefore **not** received a completed visual review. Stopping Play removes the fixture and its client-only lighting.

Sources were installed in the connected Edit place with reversible backups in `ReplicatedStorage.FieldMotionSourceBackup`. Because native window activation was unavailable, the same seven sources were persisted directly into the local place XML after stopping Play. `field_saved_place.json` records exact hashes, a pre-write backup, XML validation, and preservation of all 251 unrelated script sources, including approved connected fire. The persistence helper preserves unrelated XML bytes; it does not rebuild the map or publish it.

Motion references consulted: the author transcript for [Gabriel Aguiar's stylized fire tutorial](https://www.youtube.com/watch?v=XQlFokCzU6M), which separates contour motion/dissolve from smoke, and the author transcript for his [lightning strike tutorial](https://www.youtube.com/watch?v=XPh0jiqf0iQ), which emphasizes brief flashes and downward flow. These were transcript references, not a claim of watching the videos.

## Recorded dust-cloud correction — 2026-10-19

The user's 17-second recording showed Water rings and Earth/Poison/Arcane clouds remaining after the release-only correction. The actual `Dissipate.Smoke` emitter was then traced through a full normal-controller projectile cast. A visibility-loss reproduction emitted it only 5.64 studs from the caster, while a fully visible cast emitted it at the 72.62-stud endpoint **in addition to** the impact anchor's own cloud. The previous release fix was present in the live place; it addressed a different effect.

New burst particles in the Dissipate slot now require Role=Impact. A projectile/beam/field/aura ending can fade existing visuals but cannot create an extra hit cloud. The controller distinguishes a real end/removal from distance or selection-budget cancellation. Cancellation calls `Composer:Stop(true)`, immediately stopping its signature without invoking Finish/dissipation. Actual hit anchors retain their intended impact effects. No gameplay sources or approved fireball geometry were changed.

`dust_regression.json` records eight actual-controller cases: Water, Earth, Poison and Arcane, each with uninterrupted flight and deliberate camera culling during flight. Every case created exactly one dissipation cloud, owned by the Impact anchor at the measured endpoint (about 48 studs in this shorter regression path), and no projectile-teardown cloud. Visibility cancellation removed the active projectile session. Final sessions, emitters, meshes, lights and trails were zero; the rate counter had floating-point residue of 2.84e-14, below the test's 1e-8 tolerance. The test does not claim GPU performance. Planner tests also reject End bursts for every inventoried school/form at High and Low; compilation, the seven artwork/installation integrity tests and a Rojo build passed.

This correction was installed in Edit mode and saved through Studio after stopping the test. `dust_saved_place.json` verifies the eight current module sources, valid place XML, absence of test harnesses, and exact preservation of 250 unrelated script sources. The pre-save backup is `place-backups/Enfleshed-before-dust-lifecycle-fix-20261019.rbxlx`. The user's recording was inspected frame by frame; the corrected result is verified by the full-controller emitter trace, rather than a new captured video or a rendered-performance measurement.
