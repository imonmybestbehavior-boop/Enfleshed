"""List existing custom assets as reuse candidates, without claiming art acceptance."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/effect_families_v1'
records=[]
for kind,folder,manifest,extension in [('mesh','meshes','meshes.json','glb'),('texture','textures','textures.json','file')]:
    definitions=json.loads((ROOT/'assets/vfx'/folder/manifest).read_text())
    for name,definition in definitions.items():
        path=ROOT/'assets/vfx'/folder/definition[extension]
        records.append(dict(name=name,kind=kind,path=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            proposal='Reuse shape; review material bands and contour weight' if kind=='mesh' else 'Reuse alpha, layout and timing; review palette and internal value shapes',
            usage=definition['usage'],acceptance='Reuse candidate; not a fresh visual or Studio fetch approval'))
(OUT/'asset_reuse_inventory.json').write_text(json.dumps(dict(policy='Reuse first. Rebuild only after a specific failed shape/motion requirement is recorded.',assets=records),indent=2)+'\n')
print(f'Recorded {sum(r["kind"]=="mesh" for r in records)} existing meshes and {sum(r["kind"]=="texture" for r in records)} textures as reuse candidates')
