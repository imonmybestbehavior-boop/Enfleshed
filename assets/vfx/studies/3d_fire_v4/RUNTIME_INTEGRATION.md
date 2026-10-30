# Connected fire runtime integration

The approved v4 body is connected to the existing signature projectile renderer. Selection uses the Fire visual signature and Projectile role, never a spell name or ID. Other forms and impact recipes retain their existing presentation.

One imported mesh follows the authoritative anchor's motion heading. The existing session controls distance hiding, quality throttling, fade and cleanup. Surface instances are configured in the shipped model and switched at 12 FPS; bone poses follow the shared animation clock. Direct gameplay writes to ColorMap are not required.

The runtime caps connected bodies at 12, prewarms eight pooled models across startup frames, and retains at most eight idle models. Existing signature layers remain the fallback if the skin is missing or its body budget is full. The optional light retains the existing ten-light budget. The prefab and measured poses ship under `src/shared/SpellVFXSystem/Assets/` and pass a full Rojo build.

## Verification

Three real Fireball requests passed through the normal action router and server executor. Three connected bodies overlapped, 470 aligned body samples were observed, the server projectile size stayed 2.2 studs in all dimensions, and active body count returned to zero. This check used a normal LocalScript; direct Studio command-module caches are separate from the running game's caches.

Seven additional engine checks cover width, flight alignment, distance hiding, repeated stop, cap/fallback, another form, and bounded pool/budget cleanup. Six local source/asset tests and the complete Rojo build pass. Gameplay services, damage definitions, mana, cooldowns and networking source were not changed.

## CPU sample

Each row is a three-second High-quality local Studio sample after warm-up. Script time measures connected-body updates per Heartbeat, excluding other renderer work. These are short samples with ordinary timing variation, not a scaling model.

| Active bodies | Body script ms / Heartbeat | Active lights | Active after cleanup |
|---:|---:|---:|---:|
| 0 | 0.000 | 0 | 0 |
| 1 | 0.073 | 1 | 0 |
| 4 | 0.313 | 4 | 0 |
| 8 | 0.219 | 8 | 0 |
| 12 | 0.322 | 10 | 0 |

These earlier CPU samples mostly ran with rendering paused. They exclude allocation and attachment costs.

## Visible scene check (2026-10-18)

The foreground captures now show the actual scene, rounded burning body, and tapered alpha-eroded tail. See `foreground_scene_0.jpg` and `foreground_wide_0.jpg`. Game lighting and bloom brighten the palette compared with the isolated preview. This confirms scene visibility, not a new user art approval or exact lighting parity.

A separate three-second series measured RenderStepped intervals, independently of Heartbeat. The first empty control was noisy and is preserved as `benchmark_0_High_foreground_initial.json`; the repeat is below.

| Bodies | Render interval mean ms | Render P95 ms | Body CPU ms / Heartbeat | Batch setup ms |
|---:|---:|---:|---:|---:|
| 0 | 66.69 | 68.20 | 0.000 | 0.00 |
| 8 | 66.66 | 69.87 | 0.423 | 179.61 |
| 12 | 66.67 | 71.11 | 0.785 | 71.58 |

All three controls settle near 66.7 ms per render callback, including the empty scene. This is consistent with a Studio throttle, so the series cannot establish unconstrained frame rate or incremental GPU cost. Simulation continued near 60 Heartbeats per second. Batch setup also showed substantial variation and a possible attachment hitch; prewarming clones alone does not establish hitch-free spawning. Every load case returned active bodies to zero and kept the idle pool at eight.

## Remaining performance gate

MicroProfiler capture did not complete. Keep unconstrained rendered performance, GPU scopes, batch setup optimization, mobile and published-place checks open. Do not claim a 60 FPS graphics pass from Heartbeat timing.

Studio's source and resource model were updated. The playtest was stopped to clear all temporary cameras, fixtures and high test-request sequence numbers. The original imported Workspace model remains untouched. Source files and the Rojo model are durable; no place was published.

Reproduce the asset export with `tools/vfx_pipeline/package_connected_fire_runtime.py` using the saved verified import. Run source checks with `tests/test_spell_vfx_signatures.py` and `tests/test_connected_fire_assets.py`; use `run_studio_client_check.py` for normal-client engine checks. Raw evidence is retained beside this report.
