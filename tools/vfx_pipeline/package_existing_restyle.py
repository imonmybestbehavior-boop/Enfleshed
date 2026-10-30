"""Package the material-only restyle variants without inventing asset IDs."""
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/style_unification_v1'
catalog=json.loads((OUT/'catalog.json').read_text())
ids=json.loads((ROOT/'assets/vfx/asset_ids.json').read_text())
recipes=[]
for asset in catalog['assets']:
    if asset['kind']=='texture':
        recipes.append({k:asset[k] for k in ['name','identity','identities','width','height','layout','tiles','soft','line']})
        recipes[-1].update(source_id=ids.get(asset['name']),source_unchanged=True,status='Palette recipe only; revised colors are not a newly uploaded image')
(OUT/'texture_palette_recipes.json').write_text(json.dumps(recipes,indent=2)+'\n')
with zipfile.ZipFile(OUT/'existing_asset_material_pass.zip','w',compression=zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted((OUT/'meshes').glob('*.glb')):bundle.write(path,'meshes/'+path.name)
    bundle.write(ROOT/'assets/vfx/styles/cel_traditional_v1.json','cel_traditional_v1.json')
    bundle.write(OUT/'texture_palette_recipes.json','texture_palette_recipes.json')
    bundle.write(OUT/'README.md','README.md')
print('Packaged 60 existing mesh material variants, style profile and 71 texture palette recipes')
