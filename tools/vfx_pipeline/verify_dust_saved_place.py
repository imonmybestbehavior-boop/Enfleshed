"""Read-only verification of the Studio save, including unrelated gameplay sources."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
def sources(path):
    result={}
    def walk(parent,path=''):
        for item in parent.findall('Item'):
            name=item.findtext('Properties/string[@name="Name"]') or ''
            key=path+'/'+name if path else name
            source=item.find('Properties/ProtectedString[@name="Source"]')
            if source is not None:result[key]=source.text or ''
            walk(item,key)
    walk(ET.parse(path).getroot());return result

place=ROOT/'Enfleshed-Defend-The-Walls.rbxlx'
backup=ROOT/'place-backups/Enfleshed-before-dust-lifecycle-fix-20261019.rbxlx'
actual,before=sources(place),sources(backup)
targets={'ReplicatedStorage/Shared/SpellVFXSystem/'+p:ROOT/'src/shared/SpellVFXSystem'/(p+'.luau')
    for p in ['Core/SpellVFXComposer','Signature/SignaturePlanner','Signature/SignatureKits','Signature/SignatureRenderer','Signature/FieldDynamics','Signature/PathGlyphs','Signature/StreamBeam']}
targets['StarterPlayer/StarterPlayerScripts/Client/Controllers/SpellVFXController']=ROOT/'src/client/Controllers/SpellVFXController.luau'
hashes={}
for path,file in targets.items():
    expected=file.read_text(encoding='utf-8')
    assert actual[path]==expected,f'Saved source differs: {path}'
    hashes[path]=hashlib.sha256(expected.encode()).hexdigest()
unchanged=0
for path,source in before.items():
    if path not in targets:
        assert actual[path]==source,f'Unrelated source changed: {path}'
        unchanged+=1
assert not any('DustRegression' in p or 'DustTrace' in p for p in actual),'Test harness persisted'
receipt={'place':str(place),'sources':hashes,'unrelated_sources_unchanged':unchanged,'fixture_absent':True,'xml_valid':True}
(ROOT/'assets/vfx/studies/style_unification_v1/dust_saved_place.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
