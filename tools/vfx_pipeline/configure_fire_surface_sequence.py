"""Make the saved Blender source play its UV image sequence without script handlers."""
from pathlib import Path
import sys
import json
import bpy

root=Path(sys.argv[sys.argv.index("--")+1])
out=root/"assets/vfx/studies/3d_fire_v4"
bpy.ops.wm.open_mainfile(filepath=str(out/"connected_fireball.blend"))
scene=bpy.context.scene
material=bpy.data.materials["FlowingCelContours"]
tex=next(node for node in material.node_tree.nodes if node.type=="TEX_IMAGE")
sequence=bpy.data.images.load(str(out/"flow_textures/flow_001.png"),check_existing=False)
sequence.source="SEQUENCE"
tex.image=sequence
user=tex.image_user
user.frame_start=1
user.frame_duration=24
user.use_auto_refresh=True
user.use_cyclic=True
user.driver_add("frame_offset").driver.expression="floor((frame-1)/2)+1-frame"
scene.frame_set(1);scene.frame_set(17)
bpy.context.view_layer.update()
assert user.frame_offset==-8,user.frame_offset
bpy.ops.wm.save_as_mainfile(filepath=str(out/"connected_fireball.blend"))
scene.render.filepath=str(out/"sequence_source_check.png")
bpy.ops.render.render(write_still=True)
manifest_path=out/"manifest.json"
manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["limitations"]=[item for item in manifest["limitations"] if not item.startswith("The saved blend shows one surface texture")]
manifest["blender_playback"]="Native 24-image sequence at 12 FPS synchronized to the 24 FPS bone loop"
manifest_path.write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("Saved native image-sequence playback at 12 FPS with the 24 FPS bone loop; no Python playback handler")
