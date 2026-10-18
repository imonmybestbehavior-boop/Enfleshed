"""Export source-space bone translations and bind positions for the v4 Studio probe."""
import json
from pathlib import Path
import sys
import bpy

root = Path(sys.argv[sys.argv.index("--")+1])
out = root / "assets/vfx/studies/3d_fire_v4"
bpy.ops.wm.open_mainfile(filepath=str(out / "connected_fireball.blend"))
rig = bpy.data.objects["ConnectedFireRig"]
names = sorted(b.name for b in rig.data.bones if b.use_deform)
bind = {name: list(rig.data.bones[name].matrix_local.translation) for name in names}
frames = []
for frame in range(1, 49):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    frames.append([[round(v, 8) for v in rig.pose.bones[name].matrix.translation-rig.data.bones[name].matrix_local.translation] for name in names])
result = {"fps": 24, "texture_fps": 12, "names": names, "bind_positions": bind,
    "frames": frames, "scope": "Source armature-space translation deltas; import-axis and scale matching must be checked in Studio"}
(out / "pose_probe.json").write_text(json.dumps(result, separators=(",", ":"))+"\n")
print(f"Exported {len(frames)} frames for {len(names)} bones; imported bind-space matching remains pending")
