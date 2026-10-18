# Spell artwork overhaul — Milestone 1

Audit performed against the working tree on 2026-10-17. This milestone delivers local art, a repeatable pipeline and release checks. It does **not** certify an imported or finished gameplay effect. Existing gameplay and client rendering remain unchanged.

## Architecture audit

| Area | Actual implementation | Assessment |
|---|---|---|
| Definitions / composition | `Configuration/Spells`, `MagicSchema`, `Modules/SpellSpec`, `SpellDefinitionValidator`; player drafts and curated starting recipes | Reuse. Do not branch on spell identity. |
| Principle contract | `MagicPrincipleSpec`: Matter, Energy, Body, Soul, Space, Time. Matter expressions include Earth/Water; Energy includes Fire/Lightning/Force/legacy Unawakened | Reuse actual principle definitions. Wind exists as a visual/element kit; it is not an additional principle. |
| Forms | Schema exposes Projectile, Beam, Wave, Field, Aura, SelfEnhancement, Construct, Manipulation | All eight have existing presentation infrastructure. Summon is not a ninth schema form. |
| Authoritative execution | `MagicService`, `MagicPayloadExecutors`, `MagicControlService`, `MagicConditions`, `SummonService`, damage/cost/strain modules | Preserve. No files in this authority path changed in this milestone. |
| Network boundary | `MagicPresentation`, `SpellVFXRelay`; presentation remotes and stamped anchors consumed by `SpellVFXController` | Reuse. Current anchors are server objects; do not add replicated particles. |
| Visual derivation | Analyzer → feature extractor / fingerprint → visual plan builder → Composer; SignaturePlanner / SignatureKits / SignatureRenderer add authored layers | Reuse this engine, not a parallel registry or renderer. Selection already follows element/expression/principle. |
| Layer vocabulary | Signature slots include Core, Shell, Trail, Ambient, Cast, Charge, Impact, Dissipate; sprites, meshes, emitters and bursts | Reusable. Source existence does not establish visual quality in Studio. |
| Asset pipeline | Python/numpy textures, Blender UV meshes, FBX/GLB exports, `.blend` source, manifest builder, upload helper and lookdev | Substantial existing work: **71 textures, 60 meshes, 191 exported files**. Reuse; older docs claiming 19 textures / 14 meshes are stale. |
| Asset IDs | `assets/vfx/asset_ids.json` has 131 mappings; generated Luau manifest consumes them | Studio preflight: all 7 sampled Fire textures failed to fetch; 3 sampled meshes instantiated. Remaining IDs unverified. |
| Client performance | Signature/composer budgets and quality tiers, distance reconciliation, 28 selected anchors in controller, mesh pools (24 per key), emitter/template pool | Reuse; live allocation/cleanup, total residency, pool reset and frame time still need measurement. |
| Projectile / beam / wave | Shared recipes and authored libraries exist; Fire has bespoke component layers | Inadequate until actual asset loading and material behavior pass art review. |
| Field / aura / self | Existing form/template layers; authoritative lifetime and area behavior exist | Reuse; character occlusion and readability remain unverified. |
| Constructs | Approved `MagicConstructGeometrySpec` registry; Box/Sphere/Cylinder/Wedge/Arch/Pillar/Stairs/Bridge/limited Custom, server placement and growth validation | Gameplay works in source. Authored visual surfaces must be fitted separately from collision; closed stone prison not demonstrated. |
| Summons | Wisp/Sentinel archetypes, roles/commands, max 3 per cast/player/spell | Functioning separate summon architecture. Five orbiting sword manifestations are **missing**, not completed by weapon FBX files or the visual chain mesh. |
| Motion | `MagicProjectileMotion` phases and server hit-detection path; summon Follow/Protect/Attack/Move/Patrol/Hold/Support/Dismiss | Reuse supported motion. A universal sword manifestation/motion contract is missing. |
| Editor | `ForgePreviewPanel` draws UI schematic from draft; `GrimoireGeometryPreview` draws debug geometry; Test Spell casts in-world | Inadequate for same-engine art preview. Keep debug overlays and replace/augment schematic art through shared composer in a later milestone. |
| Showcase | Studio-only `SpellVFXShowcase` (F8), phases/quality/parameters; offline Blender stills exist | Reuse. Neither source tests nor Blender stills establish Studio acceptance A–H. |
| Redundant paths | Composer primitive grammar plus signature layers; generic `Effects/Mesh` creates a Neon ball when no template resolves | Mark for staged retirement after authored replacement passes review. Removing all fallbacks now would hide gameplay information. |

### Remaining placeholders and integration risks

`assets/vfx/manifests/local_audit.json` includes every static candidate found in the inspected rendering paths, with file, line and code. Review each match in Studio: invisible anchors are permitted and must not be removed as if they were visible art.

Known visible-risk paths include `Assets/VFXAssets` built-in particle textures and primitive mesh fallbacks, `Core/SpellVFXComposer` primitive layer infrastructure, `Effects/Mesh`'s Neon sphere fallback, and server `MagicPresentation` surface/material choices. Signature kits replace composer layers when available, but the composer can return if a signature cannot be created. A signature's existence is not a guarantee of authored-only output at every quality tier.

Other risks: a numeric ID can reference different bytes from the local PNG; client `CreateMeshPartAsync` can fail; Studio-only templates disappear from a fresh Rojo build unless preserved/imported; pooled meshes need material/texture/child reset review; additive LightEmission can erase ink; billboard rotations can weaken silhouettes; changing atlas layout without updating metadata breaks flipbook playback; low tiers must retain boundary information. No unrestricted uploads or new gameplay templates were introduced.

## Art direction: Ink & Cinder

Original graphic fantasy artwork with a directional silhouette, an opaque dark contour, broad painted value bands and a small bright accent. Avoid a white ball surrounded by bloom. Reserve approximately 5–10% of the body for the brightest value; preserve dark interior cuts. Treat the reference works as animation/shape guidance only.

Fire uses hooked tongues and a curling comet body; water uses overlapping crests and foam cutouts; wind uses open sweeping curls and negative space; lightning uses asymmetric branches with sharp release timing; earth uses fractured slabs with painted planes. Soul uses nested drifting contours and delayed secondary motion. Body, Space and Time retain the project's actual principle contracts and use their existing kit vocabulary rather than being renamed as elements.

Palette roles map to existing signature tokens: Primary → Body/Mid, Secondary → Ember, Highlight → Hot/Hi, Shadow → Deep/Lo, Emissive → WhiteHot, dark contour → Ink, smoke → Soot/Smoke. Retain existing player tint weights and untinted highlights. Opacity belongs to the layer; color transitions belong to ColorSequence/layer timing. Palette variations must preserve luminance separation.

The new study exports **grayscale + straight alpha** artwork; the color contact sheet uses a five-color lookup palette for art review. Multiplicative Roblox tinting will not reproduce that exact lookup palette on one sprite. To achieve the same result, use the existing layered palette tokens (or split masks in a future revision) and verify the composite in Studio. The contact sheet is explicitly not evidence of final runtime color.

Use anticipation → tight formation → directional release → sustained silhouette → short impact hold → smoke/ember breakup. Proposed fireball timing: 0.12–0.25 s gather, 0.06 s release stretch, looping 16 fps body, 24 fps one-shot impact, then 0.3–0.7 s smoke. These are **cosmetic art targets**, never new cast/hit/cooldown timings. Bind playback to existing authoritative phase anchors; do not delay damage for the animation.

Current study limitations: vector/cel bands are an initial style proof, not a finished hand-painted effect; smoke needs layered motion and lower contrast in runtime; the core uses an intentionally restrained loop; the impact source design is transformed/faded during atlas assembly. Judge these at combat camera distance after import before adding more detail.

## Delivered local pipeline

- `tools/vfx_pipeline/illustrated_fire.py`: deterministic cubic path authoring, matching SVG/raster silhouettes, 3× supersampled PNG exports, 16-frame atlases, contact sheet and motion GIF. Local Pillow only; no paid services or external upload.
- `assets/vfx/studies/illustrated_fire_v1/source`: **82 editable SVG frames**.
- `assets/vfx/studies/illustrated_fire_v1/textures`: **7 original RGBA PNGs**, 1024² flipbooks / 256² single sprites.
- Study `manifest.json`: version, generator hash, source hashes, export hashes, dimensions, frame count/rate/layout, candidate existing slot, null Roblox IDs and false Studio verification.
- `audit_assets.py`: decodes existing and study PNGs, checks dimensions / budgets, mesh file signatures and reported triangle limits, known literal recipe references, ID syntax, path containment and study provenance. Emits a hashed inventory and placeholder review pointers. It does not deeply validate FBX topology/UVs, prove tile seams/loop quality, or fetch Roblox content.
- `milestone_one.ps1`: Windows entry point; invokes generation, existing manifest validation and audit in order. Existing Linux/Blender scripts remain available.

Run from the repo:

```powershell
tools/vfx_pipeline/milestone_one.ps1 -Python <python-executable>
<python-executable> -m unittest discover -s tests -p test_vfx_asset_audit.py -v
<python-executable> tools/vfx_pipeline/audit_assets.py --require-studio
```

Python needs Pillow (tested locally with Pillow 12.3.0); the existing texture generator also needs numpy (available 2.3.5). Blender 5.2 is installed at `C:\Program Files\Blender Foundation\Blender 5.2`; existing mesh generators use `bpy`/`bmesh` and keep editable `.blend` sources. The old `blender.sh` assumes a Linux launcher; use Blender's Windows executable with `--background --python tools/vfx_pipeline/gen_meshes.py -- <repo-root>` for deliberate full mesh regeneration. This milestone reused the exported mesh library rather than regenerating it unnecessarily.

The last command is an intentional failing release gate until Studio acceptance exists. Do not remove that gate to call the overhaul complete. Generation and all checks are offline; no artwork has been uploaded by this work.

## Import boundary and exact next actions

The repository's `.mcp.json` still names `/home/deck/.local/bin/roblox-studio-mcp`, a stale Linux path. During this work the user connected Studio through the global Windows configuration, which launches `%LOCALAPPDATA%/Roblox/mcp.bat`. `studio_mcp.py` successfully queried that installed MCP proxy. The connected instance is `Enfleshed-Defend-The-Walls.rbxlx`, Edit mode; PlaceId, UniverseId and CreatorId are all 0 (an unpublished local file). Rojo/Luau/StyLua remain unavailable on PATH.

**Actual Studio preflight:** `scripts/studio_vfx_preflight.luau` inspected the modules without modifying the place, decoded the existing manifest, preloaded seven Fire textures and created/destroyed three temporary unparented MeshParts. All seven texture callbacks reported `Failure`: core_plasma, flame_tongue, trail_flame, explosion_fire, smoke_billow, ember_streak, rune_circle. `PreloadAsync` itself returned normally, demonstrating why callback statuses must be checked. fire_core, flame_shell and energy_ribbon MeshParts instantiated successfully; energy_ribbon returned approximately 128.72 × 127.01 × 400 studs and needs orientation/scale/content review. There were no imported mesh templates under the expected folder. The raw MCP result is preserved in `assets/vfx/manifests/studio_preflight.json`. This is Edit-mode availability evidence, not a visual or multiplayer acceptance result.

The user explicitly approved uploading the seven candidate textures. The required local execution approval for `upload_fire_study.py` was then declined, so **the upload did not run**. No returned upload receipt or new asset IDs exist. Do not infer withdrawal of the general artwork request, and do not retry this declined upload without renewed authorization for that execution. The prepared helper serves only the seven hash-checked files over loopback and records the actual MCP receipt; it never edits live IDs or publishes a place.

1. Open the target experience in Studio under the creator account that owns it. Preserve a backup. Reuse the F8 sandbox.
2. Upload the seven **candidate** PNGs using Asset Manager to the intended creator, or authorize execution of the prepared `upload_fire_study.py --studio-id <current-id>` workflow after checking the signed-in account. The local place has no owning creator yet; do not publish the place just to solve this. Record actual image content IDs usable by ParticleEmitter, not an assumed decal/model container ID. Do not overwrite existing IDs based on their filenames. No artwork upload ran during this session.
3. In a review branch/working copy, bind candidate textures to Fire's existing signature layers through the current manifest/registry. Update metadata as well as IDs: core/tongue/impact/smoke/charge use Grid4x4; trail/ember are static. **The candidate impact differs from the old Grid8x8 explosion**, and charge is not a drop-in static rune replacement. Keep per-sprite frame lifetime consistent. Preserve current gameplay event timing.
4. Import `assets/vfx/meshes/fire_core.fbx`, `flame_shell.fbx`, `energy_ribbon.fbx`, appropriate ink hulls and impact meshes via Studio Import 3D. Check scale, normals and UVs. Put approved MeshParts under `ReplicatedStorage/VFXAssets/Meshes` with the exact registry names, or record actual mesh IDs under `mesh:<name>` in `asset_ids.json`. Save imported templates; a clean Rojo build does not upload or preserve these automatically.
5. Rebuild `tools/vfx_pipeline/build_manifest.py` after updating approved live metadata/IDs. Inspect the diff. Use `scripts/studio_vfx_asset_check.luau` on the client in Play mode to preload and diagnose. Its results are availability evidence only; inspect the actual effect too.
6. Run F8 Fireball phases and ×1/×5 casts at Low/Medium/High, near/far, default/player colors, moving camera, interrupted cast, impact and expiration. Verify that loss of a texture/mesh produces explicit diagnostics and that **no visible primitive fallback qualifies as completed art**. Capture before/after at matching camera and settings.
7. Store approval evidence separately: asset name, source SHA256, actual content ID, creator/experience, successful fetch status, Studio/place version, camera/quality, screenshots and reviewer/date. Only then activate the approved version and advance Milestone 2.

The existing Open Cloud upload helper is retained but was not exercised. Its response/container-ID assumptions must be checked against the target API and verified in Studio before trusting its output. Never print credentials or infer successful publication from a local file/recorded number.

## Incremental implementation plan

1. **Architecture + assets (this milestone):** audit, art direction, seven candidate fire assets, repeatable Windows pipeline, provenance and validation. Local work complete; publication boundary pending.
2. **First complete fireball:** import/approve study assets, bind existing Fire signature from cast through impact, remove primitive fallback output for this approved route, capture Studio evidence. No further form migration before this passes.
3. **Reusable elemental layers:** refine the existing Water/Wind/Lightning/Earth and general kit artwork. Demonstrate element substitution on one shared manifestation; keep Motion independent.
4. **Other forms:** progressively migrate the existing eight form templates. Validate boundaries, origin/termination, scale, quality reductions and cleanup after each route.
5. **Constructs/summons:** fit authored structure meshes to authoritative templates. Add an approved object manifestation contract only with matching server validation; do not silently raise summon count from 3 to 5. Sword/spear/shield/hand and closed-prison gameplay acceptance remain open.
6. **Editor:** reuse the same analyzer/planner/composer and registry for an in-world preview. Keep schematic/debug controls explicitly labeled and avoid a separate imitation renderer.
7. **Performance/polish:** measure and compare actual Studio multiplayer sessions before retiring fallback paths.

## Verification and outstanding acceptance

Measured local result: 191 existing export files audited, 7 new textures, 82 vector source frames; 0 offline audit errors; 5 new automated tests passed. Existing manifest builder passed with 71 textures / 60 meshes / 131 recorded IDs. No changes to server mechanics, networking, costs, strain, damage, cooldowns, spell schema or client runtime were made. The small manifest-validator fix rejects Python booleans masquerading as numeric asset IDs.

Full `scripts/check.sh`, Rojo build, Luau suites, Studio Play mode and visual capture were **not run** in this session; required Roblox CLI tools are unavailable on PATH. Studio Edit-mode MCP availability checks **were run**, as detailed above. This was a local pipeline change, not a gameplay migration.

| Acceptance | Current result |
|---|---|
| A illustrated fireball | Local artwork proof only; import, live binding and art review pending |
| B water slash / C lightning beam | Existing kit sources, no new Studio acceptance |
| D five flaming swords | Missing approved object manifestation path; conflicts with current summon cap |
| E stone prison | Existing construct authority; authored enclosure and collision demonstration pending |
| F element / G motion recomposition | Architectural support exists; requested live demonstrations pending |
| H multiplayer stress | **Not measured** |

For H, record Studio version/place, device, graphics tier, player count, spell mix and frequency, 60 s warmup + 120 s sample; client frame time median/p95, memory before/during/after, active sessions, emitted particle budget, mesh instances, network sent/received and cleanup after all durations. Compare baseline to the same run with approved authored VFX; repeat on a mobile device. Report actual counters and hardware, not estimated FPS. No frame time, memory or network benchmark is claimed here.
