"""Persist the already-installed source correction without reserializing the place.

Only the seven verified script sources are patched; a missing FieldDynamics module
is inserted beside the other signature modules. All unrelated XML bytes survive.
Run with Studio stopped. Keeps a recoverable copy of the exact input file.
"""
from pathlib import Path
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
from xml.parsers import expat

ROOT=Path(__file__).resolve().parents[2]
PLACE=ROOT/'Enfleshed-Defend-The-Walls.rbxlx'
PREFIX='ReplicatedStorage/Shared/SpellVFXSystem/'
MODULES=['Signature/'+n for n in ['FieldDynamics','StreamBeam','PathGlyphs','SignaturePlanner','SignatureKits','SignatureRenderer']]+['Core/SpellVFXComposer']

def scan(data):
    parser=expat.ParserCreate();items=[];tags=[];records={}
    def start(tag,attrs):
        tags.append((tag,attrs))
        if tag=='Item':items.append({'class':attrs['class'],'name':'','start':parser.CurrentByteIndex})
        if tag=='ProtectedString' and attrs.get('name')=='Source':
            items[-1]['source_start']=data.index(b'>',parser.CurrentByteIndex)+1
    def chars(value):
        if items and tags[-1][0]=='string' and tags[-1][1].get('name')=='Name':items[-1]['name']+=value
    def end(tag):
        if tag=='ProtectedString' and tags[-1][1].get('name')=='Source':items[-1]['source_end']=parser.CurrentByteIndex
        if tag=='Item':
            path='/'.join(i['name'] for i in items)
            items[-1]['close']=parser.CurrentByteIndex;records[path]=items.pop()
        tags.pop()
    parser.StartElementHandler=start;parser.EndElementHandler=end;parser.CharacterDataHandler=chars
    parser.Parse(data,True);return records

def cdata(source):return b'<![CDATA['+source.replace(b']]>',b']]]]><![CDATA[>')+b']]>'

def main():
    data=PLACE.read_bytes();records=scan(data);edits=[];expected={}
    targets={PREFIX+m:ROOT/'src/shared/SpellVFXSystem'/(m+'.luau') for m in MODULES}
    targets['StarterPlayer/StarterPlayerScripts/Client/Controllers/SpellVFXController']=ROOT/'src/client/Controllers/SpellVFXController.luau'
    for path,source_path in targets.items():
        source=source_path.read_bytes().replace(b'\r\n',b'\n')
        expected[path]=source.decode('utf-8');record=records.get(path)
        if record:
            edits.append((record['source_start'],record['source_end'],cdata(source)))
        else:
            assert path==PREFIX+'Signature/FieldDynamics',f'Missing existing module: {path}'
            parent=records[PREFIX+'Signature'];assert parent['class']=='Folder'
            xml=b'<Item class="ModuleScript" referent="RBXEnfleshedFieldDynamics20261019"><Properties><string name="Name">FieldDynamics</string><ProtectedString name="Source">'+cdata(source)+b'</ProtectedString></Properties></Item>\n'
            edits.append((parent['close'],parent['close'],xml))
    revised=data
    for begin,end,value in sorted(edits,reverse=True):revised=revised[:begin]+value+revised[end:]
    oldtree=ET.fromstring(data);newtree=ET.fromstring(revised)
    def sources(tree):
        result={}
        def walk(parent,path=''):
            for item in parent.findall('Item'):
                name=item.findtext('Properties/string[@name="Name"]') or ''
                key=path+'/'+name if path else name
                source=item.find('Properties/ProtectedString[@name="Source"]')
                if source is not None:result[key]=source.text or ''
                walk(item,key)
        walk(tree);return result
    before,after=sources(oldtree),sources(newtree)
    for path,source in expected.items():assert after[path]==source,path
    for path,source in before.items():
        if path not in expected:assert after[path]==source,path
    backup=ROOT/'place-backups/Enfleshed-before-dust-lifecycle-fix-20261019.rbxlx'
    if not backup.exists():shutil.copy2(PLACE,backup)
    temp=PLACE.with_suffix('.field-save.tmp');temp.write_bytes(revised);temp.replace(PLACE)
    receipt={'place':str(PLACE),'backup':str(backup),'sources':{p:hashlib.sha256(s.encode()).hexdigest() for p,s in expected.items()},
             'unrelated_script_sources_preserved':len(before.keys()-expected.keys()),'xml_valid':True}
    (ROOT/'assets/vfx/studies/style_unification_v1/dust_saved_place.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__':main()
