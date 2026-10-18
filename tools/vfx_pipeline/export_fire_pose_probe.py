"""Export source bone poses for an isolated Studio skin-deformation probe."""
import json
from pathlib import Path
import sys
import bpy

root = Path(sys.argv[sys.argv.index("--")+1])
out = root/"assets/vfx/studies/3d_fire_v1"
bpy.ops.wm.open_mainfile(filepath=str(out/"fire_transport_study.blend"))
frames = []
rig = bpy.data.objects["Flame_00_Rig"]
for frame in range(1,49):
    bpy.context.scene.frame_set(frame)
    row = []
    for index in range(21):
        loc,rot,scale = rig.pose.bones[f"Flow_{index:02d}"].matrix.decompose()
        matrix = rot.to_matrix()
        row.append([round(value,7) for value in [*loc,*[matrix[r][c] for r in range(3) for c in range(3)]]])
    frames.append(row)
(out/"pose_probe.json").write_text(json.dumps(frames,separators=(",",":")),encoding="utf-8")
print("Exported 48 rigid bone poses; per-bone scale deliberately excluded from the CFrame-only probe")
