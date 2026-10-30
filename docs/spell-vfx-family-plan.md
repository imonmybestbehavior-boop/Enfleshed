# Reusable spell effects — first gallery

2026-10-18. The approved connected fireball is preserved. The next prototype is **Soul / Spirit Field**, following the user's correction; Body Burst is not being redesigned in this batch.

## Restyle existing work first

Execution update: new effect-family construction is paused in favor of the user's requested existing-art style pass. `assets/vfx/studies/style_unification_v1/` provides paired comparisons for the current 71 textures and 60 meshes, with 60 material-only GLB variants and a 13-identity palette profile. The mesh geometry and original texture alpha/frames are preserved. Texture palette changes are currently review rendering/recipes, not baked production images. See that folder's README for import limits and validation. No extra spell design or production activation is part of this pass.

Bake update: the user approved that style direction and requested the bake. All 71 source textures now have 91 unique identity-specific colored atlases, with byte-identical alpha and unchanged layouts/frames. The gallery displays baked files, and `existing_asset_baked_pass.zip` includes those atlases, 60 material variants and verification/import manifests. This supersedes the earlier review-only texture status. Production IDs, uploads and gameplay remain unchanged.

The existing custom spell work is usable. This project is a style-unification pass, not a replacement of the asset library. For every family, inspect existing meshes, UVs, alpha silhouettes, flipbooks, movement and imported templates before authoring a replacement. The user explicitly wants reuse wherever it can meet the Wind Waker-inspired direction.

Classify work in this order: **material/palette pass** (keep shape and timing), **design adjustment** (simplify noisy detail, broaden color regions, adjust silhouette/contour or secondary motion), then **rebuild only with a recorded reason** (topology, view dependence, incompatible deformation or a specifically rejected shape). Color alone may be sufficient for some assets; do not assume every asset needs a new rig. Keep originals and compare a variant in the gallery before changing production.

Existing Soul assets already include `soul_wisp` (two eyes and a mouth), `ghost_trail`, `soul_burst`, `soul_sigil`, `skull_mote`, `soul_skull` and `chain_link`. Retain their source and matching imported assets. Wisp alpha/timing, spectral trail cutouts, burst motion and sigil layouts are direct restyle candidates. The horned skull and chain are selective curse/binding motifs, not mandatory decorations for every Soul spell. This gallery's new volume is a targeted test of 3D rising motion and fading at height, not a verdict that those existing assets are bad.

`asset_reuse_inventory.json` lists the existing custom mesh/texture catalog and hashes the originals. Its dispositions are candidates, not claims that all designs have passed the new style or that every uploaded ID currently fetches. Reuse uploaded unchanged assets directly; modified texture/mesh bytes require a new verified asset and upload authorization when ready.

## Repository inventory

The editor's `MagicSchema.Forms`, server `MagicFormExecutors.Executors`, and signature components agree on eight forms. `Configuration/Spells.luau` registers nine example spells. Magic Lab can create additional definitions and nested effects; these are combinations of the existing form contracts, not additional forms. Persisted player libraries are outside this static inventory.

The current architecture already supplies normalized features, deterministic planning, palette kits, phase anchors, distance/quality policies, budgets and cleanup. `SignatureKits` generates layers for 13 visual identities: Fire, Ice, Lightning, Water, Earth, Wind, Poison, Arcane, Force, Body, Spirit, Space and Time. These are visual identities, **not 13 freely interchangeable gameplay principles**. `MagicPrincipleSpec` remains the compatibility authority. In particular, Soul/Spirit supports Field and six other humanoid-target forms, but not Manipulation.

| Existing form | Current visual construction | Proposed family | Exceptions that remain explicit |
|---|---|---|---|
| Projectile | Composer comet/core/trail plus identity kit; Fire uses `ConnectedFire` | Traveling volume | Follow actual flight, homing turns, chain/pierce/multishot and linger; Earth remains solid, Soul drifts, Fire transports and erodes |
| Beam | BeamCore, BeamAura, helix and kit beam layers | Directed stream | Instant versus channel, endpoint/contact, length/width changes; lightning branching differs from fluid flow |
| Wave | Linked crest; bespoke Body pressure cone/crescents; kit wave layers | Expanding front | Cone and radial/Sphere; repeated channels. Wave hits happen in place: visual expansion must not imply new traveling collision |
| Field | Boundary/carpet and kit ground/ambient layers | Area envelope | Fixed or surface/object placement, radius, pulse and expiry; boundary must remain legible |
| Aura | Boundary/orbit plus kit shell/ambient | Area envelope | Follow the authoritative owner/target rather than leave a stationary floor effect |
| SelfEnhancement | Linked mantle plus shell/ambient | Area envelope, body-mounted variant | Body attachments and toggle cancellation; cannot simply shrink a floor ring |
| Construct | Lattice/ambient overlays on the actual server-created object | Surface assembly | Box, Sphere, Cylinder, Wedge, Arch, Pillar, Stairs, Bridge, Custom; attachment/persistence and actual solid silhouette |
| Manipulation | Lattice/ambient around affected material/object | Surface assembly | Matter-focused Raise/Lower and real target motion; no Soul substitution |

Five construction families are the smallest useful split here. Beam and Wave have different topology and timing constraints. The envelope family shares boundary/interior motifs but still needs three placement variants. Construct and Manipulation share surface accents while retaining the actual object. Cast/Gather, Release, contact/Impact, End/dissipation and mechanic accents are cross-cutting layers, not additional gameplay forms.

| Registered example | Source | Form | Family |
|---|---|---|---|
| Fireball | Energy / Fire | Projectile | Traveling volume — approved reference |
| StoneShot | Matter / Earth | Projectile | Traveling volume |
| RecruitMagicBolt | Energy / Unawakened | Projectile | Traveling volume |
| BodyBurst | Body / BodyEnhancement | Wave | Expanding front — existing presentation retained |
| RecruitMagicDischarge | Energy / Unawakened | Wave | Expanding front, radial variant |
| LightningLance | Energy / Lightning | Beam | Directed stream |
| BurningGround | Energy / Fire | Field | Area envelope |
| BodyReinforcement | Body / BodyEnhancement | SelfEnhancement | Area envelope, body-mounted |
| StoneRaise | Matter / Earth | Manipulation | Surface assembly |

Aura and Construct are executable/editor forms without a named example in this registry. The Soul field in the gallery is an art fixture, not a tenth registered spell and not an implied damage/heal/summon ability. Machine-readable inventory and a source-preservation snapshot live in `assets/vfx/studies/effect_families_v1/inventory.json`. `audit_effect_families.py` fails if the editor, executor and family mappings diverge.

## Reuse contracts

| Responsibility | Reuse boundary | Where it belongs |
|---|---|---|
| Geometry | Connected volume; stream middle/caps; sector/radial front; boundary/interior/body envelope; surface seams | Authored asset bundles keyed by family and compatible identity, with orientation, dimensions and attachment metadata |
| Animation | Transport, branching, rise/echo, fracture/settle, phase envelope | Deterministic motion recipe, shared clock, phase-local time and bounded pose rate; geometry-specific controllers where necessary |
| Identity | Palette roles, shape language, motion vocabulary, breakup | Existing `SignatureKits`/signature selection, by Element/Expression/Principle, never spell name |
| Spell parameters | Size, range, speed, force, duration, charge, pulse and mechanic accents | Existing analyzer/feature extractor and planner; bounded visual drivers, never writes back to gameplay |
| Lifecycle | Attach/follow, phase changes, visibility, quality, allocation, fade, release | Existing SignatureRenderer/VFX sessions and asset pools; no second gameplay scheduler |

Family recipes should expose `Family`, `Identity`, `Placement`, `GeometryVariant`, `MotionVariant`, `Palette`, `PhaseEnvelope`, `VisualDrivers`, `LOD`, and `AssetBundle`. Selection is `(normalized form, compatible identity, role, phase)`, with the current recipe as fallback. A missing bundle must not remove the spell silhouette. This is a proposed runtime contract; this batch's catalog is **authoring data only**, not an active production selector.

The fireball already provides a preserved imported skin, measured poses, a 24-frame surface cycle, travel alignment, distance hiding, quality-throttled poses, fade, an active cap and bounded pooling. It does **not** provide beam endpoints, ground following, attached envelopes, field boundaries, other identity motion, or accepted impacts for every form. Its full-frame surface textures are Fire-specific; they are not a universal recoloring mask. Keep its existing controller until a replacement proves parity.

## Next representative: Soul field

Progress: the user approved the little-ghost rise and gradual fade at height, then requested that full-size wisps emerge through the ground instead of scaling up at birth. That correction is now in the gallery. A new seven-second full-effect mode adds gather/formation and dissipation around the motion, plus a clear interval and an early-end control. It reuses the existing `soul_sigil` artwork as the casting cue. The four-second sustain-only mode remains available. First-cycle births are staggered so the field does not reveal pre-aged ghosts floating in the air during formation. These additions are a local phase study, not newly approved art or gameplay timings.

Why this choice: requested Soul direction; existing `Soul → Spirit` kit and supported Field contract; tests boundary plus volume layering, which the projectile does not exercise. Later Auras can reuse the boundary/interior vocabulary with owner-following placement. SelfEnhancement needs a separate body-local composition. Do not claim a single field proves either variant.

The first study uses a five-stud radius, a stable broken circular boundary, six staggered rising primary wisps and narrower delayed echoes. The shape leans inward while its internal contour bands renew. Each primary has a rounded ghost head, two small curved eyes and an open mouth. Following user feedback, wisps retain their shape and gradually become transparent at height. The whole body and its face share the same opacity. This supersedes both the rejected shrinking and the later top-down wipe. Four color bands plus dark facial marks follow the existing teal/mint identity. No fire geometry, fire textures, AI artwork, or gameplay assets are substituted for Soul. A five-stud figure and one-stud grid make its scale inspectable.

The browser draws actual 3D surfaces from sampled geometry. Its cel quantization is a **review technique only**: Blender/browser shaders do not transfer into Roblox. Before importing Soul, author UVs and a bounded skin, bake palette bands into compatible prepared surface frames (or evaluate separate material regions), verify scale and seams, then prove the same motion with a small Studio import. Never deploy a browser-only shader assumption.

The field now has a review-only cast/expiry envelope and reuses an existing sigil. It has no Studio skin/import, contact response, terrain conformance or production placement/cleanup adapter yet. The four-second motion cycle and seven-second full review do not prescribe server duration, hit or pulse timing. The original sustain approval snapshot and requested ground-emergence revision are recorded separately.

## Batches and acceptance

1. **This batch:** inventory, reusable catalog, local 3D gallery with unchanged Fire reference and Soul Field study. Review fixed views, arbitrary orbit, pause/scrub and scale. No production activation.
2. **Soul envelope approval:** revise silhouette/motion first, then add gather, sustain and expiry. Check boundary readability at combat distance, from above/below, and with overlap. Do not multiply an unapproved shape across every form.
3. **One import proof:** bake/export the approved Soul construction; compare with the gallery in Studio. Test attach, follow, pulse, cancellation, expiry and released resources through the existing renderer. Request authorization only when a concrete new upload is ready.
4. **Envelope placements:** stationary Field, following Aura and body-mounted SelfEnhancement. Confirm orientation and clipping separately. Only then derive other identities; Fire erupts/transports, Water folds/splashes, Lightning branches/snaps, Earth fractures/settles, Soul rises/drifts/echoes.
5. **Other constructions:** directed stream (LightningLance), surface assembly (StoneRaise plus a Construct fixture), then expanding front (radial discharge; leave Body Burst untouched unless explicitly revisited). Reuse the gallery and authoring recipe instead of making a new test app per spell.
6. **Shipping pass:** representative registered/generated spells, mechanic combinations, low/high tiers, pool overflow/fallback, end/cancel/anchor removal and actual scene views. Profile allocation, body updates and rendered/GPU work separately on a less-loaded session/device before setting budgets.

The previous roughly 15 FPS empty-scene baseline was collected on the heavily loaded Surface Pro 8. It does not establish a fireball bottleneck. Existing short CPU and batch setup observations are retained as measurements, not attribution or a performance pass. This browser gallery is not a Studio benchmark.

No additional connector or external artwork is needed for this iteration. If a later paint pass needs artwork, provide the actual UV template, exact dimensions and alpha specification rather than asking for an arbitrary image sheet.

## Evidence and scope

Sources inspected: `Configuration/Spells`, `MagicSchema`, `MagicPresentation`, `Modules/MagicPrincipleSpec`, `MagicConstructGeometrySpec`, server `MagicFormExecutors`/`MagicPresentation`, VFX analyzer/composer/visual planning, `SignatureLibrary`, `SignatureKits`, `ConnectedFire`, and the three requested status documents.

Gallery validation and browser evidence are recorded in `assets/vfx/studies/effect_families_v1/VERIFICATION.md`. Server/configuration and approved fire source hashes are checked against the initial snapshot. No damage, mana, cooldown, hit, networking or production VFX source is changed by this gallery.
