"""Package verified baked texture bytes and existing mesh material variants; no uploads."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/style_unification_v1'
BAKED=OUT/'baked'
manifest=json.loads((BAKED/'manifest.json').read_text())
catalog=json.loads((OUT/'catalog.json').read_text())
ids=json.loads((ROOT/'assets/vfx/asset_ids.json').read_text())
assert json.loads((BAKED/'style_profile.json').read_text())==catalog['profile']
meshes=[]
for row in catalog['assets']:
    if row['kind']=='mesh':
        path=OUT/row['variant']
        meshes.append(dict(name=row['name'],identity=row['identity'],file=row['variant'],sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            source_recorded_id=ids.get('mesh:'+row['name']),uploaded_id=None,triangles=row['triangles'],geometry='Existing positions, normals, UVs and oriented triangles preserved'))
(BAKED/'mesh_manifest.json').write_text(json.dumps(meshes,indent=2)+'\n')
archive=OUT/'existing_asset_baked_pass.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
    seen=set()
    for entry in manifest['entries']:
        assert entry['file'] not in seen
        seen.add(entry['file']);path=BAKED/entry['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']
        bundle.write(path,entry['file'])
    for row in meshes:bundle.write(OUT/row['file'],row['file'])
    for name in ['manifest.json','mesh_manifest.json','style_profile.json','baked_contact_sheet.png']:
        bundle.write(BAKED/name,name)
    bundle.write(OUT/'BAKED_IMPORT.md','IMPORT_README.md')
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
print(f'Packaged {len(seen)} unique baked atlases and {len(meshes)} existing mesh material variants ({archive.stat().st_size/1048576:.2f} MiB); ZIP integrity verified')
