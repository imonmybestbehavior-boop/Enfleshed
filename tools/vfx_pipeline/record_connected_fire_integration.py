"""Summarize verified runtime evidence, explicitly separating CPU from graphics acceptance."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/vfx/studies/3d_fire_v4"
def payload(name):
    result=json.loads((OUT/name).read_text(encoding="utf-8"))
    assert not result.get("isError"),name
    return json.loads(next(x["text"] for x in result["content"] if x["type"]=="text"))
live=payload("live_cast_receipt.json")
assert live["PeakConnectedBodies"]==3 and live["AlignedBodySamples"]>0 and live["Final"]["Active"]==0
projectiles=[x for x in live["ProjectileAnchors"] if x["Name"]=="MagicProjectile"]
assert len(projectiles)==3 and all(all(abs(v-2.2)<.001 for v in x["Size"]) for x in projectiles)
lifecycle=payload("runtime_lifecycle_receipt.json")
assert lifecycle["Checks"]==7 and lifecycle["PoolAndBudgetsClean"]
cases=[payload(f"benchmark_{count}_High.json") for count in [0,1,4,8,12]]
foreground=[payload(f"benchmark_{count}_High_foreground.json") for count in [0,8,12]]
for case in foreground:
    assert case["RenderedFrames"]>0 and case["AfterCleanup"]["Active"]==0
for case in cases:
    assert case["AfterCleanup"]["Active"]==0 and case["AfterCleanup"]["Pooled"]<=8
    assert case["Count"]==0 or case["Fire"]["Updates"]>0
sources={}
for name in ["Signature/ConnectedFire.luau","Signature/SignatureRenderer.luau","Assets/ConnectedFireRig.rbxmx","Assets/ConnectedFirePoses.luau"]:
    path=ROOT/"src/shared/SpellVFXSystem"/name
    sources[name]=hashlib.sha256(path.read_bytes()).hexdigest()
record={"status":"runtime_integrated_scene_visible_render_performance_acceptance_pending",
    "live_casts":{"requests":3,"connected_peak":live["PeakConnectedBodies"],"aligned_samples":live["AlignedBodySamples"],
        "projectile_hit_size_studs":2.2,"active_after_cleanup":0},
    "lifecycle_checks":lifecycle,"cpu_samples":cases,"foreground_samples":foreground,"source_sha256":sources,
    "validation":["Three signature/compile/manifest tests pass","Three shipping-asset integrity tests pass",
        "Full Rojo project build passes","Seven Studio runtime lifecycle checks pass"],
    "graphics_acceptance":False,"scene_capture_usable":True,
    "scene_evidence":["foreground_scene_0.jpg","foreground_wide_0.jpg"],
    "limitations":["Earlier CPU samples ran with rendering paused; use separate foreground samples for rendered intervals",
        "The scene now visibly renders the rounded body and tapered alpha tail; lighting brightens the palette relative to the isolated preview",
        "Empty-scene, eight-body and twelve-body render intervals all average about 66.7 ms, consistent with a Studio throttle; unconstrained performance remains unverified",
        "MicroProfiler capture was unavailable; no GPU scope timing was obtained",
        "Short local Studio samples do not establish mobile or published-server performance",
        "Visible batch setup measured approximately 180 ms for eight and 72 ms for twelve; setup hitch risk remains despite eight prewarmed clones",
        "Authored body palette is fixed; custom spell color continues to tint the existing light",
        "Other forms, cast cues and impact recipes retain their existing presentation"]}
(OUT/"runtime_verification.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
lines=["# Connected fire runtime integration","",
    "The approved v4 body is connected to the existing signature projectile renderer. Selection uses the Fire visual signature and Projectile role, never a spell name or ID. Other forms and impact recipes retain their existing presentation.","",
    "One imported mesh follows the authoritative anchor's motion heading. The existing session controls distance hiding, quality throttling, fade and cleanup. Surface instances are configured in the shipped model and switched at 12 FPS; bone poses follow the shared animation clock. Direct gameplay writes to ColorMap are not required.","",
    "The runtime caps connected bodies at 12, prewarms eight pooled models across startup frames, and retains at most eight idle models. Existing signature layers remain the fallback if the skin is missing or its body budget is full. The optional light retains the existing ten-light budget. The prefab and measured poses ship under `src/shared/SpellVFXSystem/Assets/` and pass a full Rojo build.","",
    "## Verification","",
    f'Three real Fireball requests passed through the normal action router and server executor. Three connected bodies overlapped, {live["AlignedBodySamples"]} aligned body samples were observed, the server projectile size stayed 2.2 studs in all dimensions, and active body count returned to zero. This check used a normal LocalScript; direct Studio command-module caches are separate from the running game\'s caches.',"",
    "Seven additional engine checks cover width, flight alignment, distance hiding, repeated stop, cap/fallback, another form, and bounded pool/budget cleanup. Six local source/asset tests and the complete Rojo build pass. Gameplay services, damage definitions, mana, cooldowns and networking source were not changed.","",
    "## CPU sample","",
    "Each row is a three-second High-quality local Studio sample after warm-up. Script time measures connected-body updates per Heartbeat, excluding other renderer work. These are short samples with ordinary timing variation, not a scaling model.","",
    "| Active bodies | Body script ms / Heartbeat | Active lights | Active after cleanup |",
    "|---:|---:|---:|---:|"]
for c in cases: lines.append(f'| {c["Count"]} | {c["ScriptMSPerHeartbeat"]:.3f} | {c["Renderer"]["Lights"]} | {c["AfterCleanup"]["Active"]} |')
lines += ["", "These earlier CPU samples mostly ran with rendering paused. They exclude allocation and attachment costs.","",
    "## Visible scene check (2026-10-18)","",
    "The foreground captures now show the actual scene, rounded burning body, and tapered alpha-eroded tail. See `foreground_scene_0.jpg` and `foreground_wide_0.jpg`. Game lighting and bloom brighten the palette compared with the isolated preview. This confirms scene visibility, not a new user art approval or exact lighting parity.","",
    "A separate three-second series measured RenderStepped intervals, independently of Heartbeat. The first empty control was noisy and is preserved as `benchmark_0_High_foreground_initial.json`; the repeat is below.","",
    "| Bodies | Render interval mean ms | Render P95 ms | Body CPU ms / Heartbeat | Batch setup ms |",
    "|---:|---:|---:|---:|---:|"]
for c in foreground:
    lines.append(f'| {c["Count"]} | {c["RenderTiming"]["MeanMS"]:.2f} | {c["RenderTiming"]["P95MS"]:.2f} | {c["ScriptMSPerHeartbeat"]:.3f} | {c["CreationMS"]:.2f} |')
lines += ["", "All three controls settle near 66.7 ms per render callback, including the empty scene. This is consistent with a Studio throttle, so the series cannot establish unconstrained frame rate or incremental GPU cost. Simulation continued near 60 Heartbeats per second. Batch setup also showed substantial variation and a possible attachment hitch; prewarming clones alone does not establish hitch-free spawning. Every load case returned active bodies to zero and kept the idle pool at eight.","",
    "## Remaining performance gate","",
    "MicroProfiler capture did not complete. Keep unconstrained rendered performance, GPU scopes, batch setup optimization, mobile and published-place checks open. Do not claim a 60 FPS graphics pass from Heartbeat timing.","",
    "Studio's source and resource model were updated. The playtest was stopped to clear all temporary cameras, fixtures and high test-request sequence numbers. The original imported Workspace model remains untouched. Source files and the Rojo model are durable; no place was published.","",
    "Reproduce the asset export with `tools/vfx_pipeline/package_connected_fire_runtime.py` using the saved verified import. Run source checks with `tests/test_spell_vfx_signatures.py` and `tests/test_connected_fire_assets.py`; use `run_studio_client_check.py` for normal-client engine checks. Raw evidence is retained beside this report."]
(OUT/"RUNTIME_INTEGRATION.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
manifest=json.loads((OUT/"manifest.json").read_text())
manifest["status"]=record["status"]
manifest["runtime_report"]="RUNTIME_INTEGRATION.md"
manifest["limitations"]=record["limitations"]
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("Recorded visible scene and separate rendered intervals; unconstrained performance acceptance remains pending")
