"""Inventory actual form registries and registered examples; fail on uncovered forms."""
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/effect_families_v1'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def audit():
    config=json.loads(Path(__file__).with_name('effect_families.json').read_text())
    schema=(ROOT/'src/shared/Configuration/MagicSchema.luau').read_text()
    schema=schema.split('Schema.Forms = {',1)[1].split('Schema.FormOrder',1)[0]
    forms=re.findall(r'^\t(\w+) = \{',schema,re.M)
    dispatch=(ROOT/'src/server/Services/MagicFormExecutors.luau').read_text()
    executors=re.findall(r'^\t(\w+) = function',dispatch,re.M)
    assert set(forms)==set(executors)==set(config['forms']), (forms,executors)
    assignments=[f for family in config['families'].values() for f in family['forms']]
    assert len(assignments)==len(set(assignments))==len(forms)
    source=(ROOT/'src/shared/Configuration/Spells.luau').read_text()
    blocks=re.findall(r'^\t(\w+) = \{\n(.*?)(?=^\t\w+ = \{|^\}\))',source,re.M|re.S)
    spells=[]
    for key,body in blocks:
        form=re.search(r'\bForm = "(\w+)"',body).group(1)
        principle=re.search(r'Principle = "(\w+)"',body).group(1)
        expression=re.search(r'Expression = "(\w+)"',body).group(1)
        spells.append(dict(id=key,form=form,principle=principle,expression=expression,family=config['forms'][form]['family']))
    assert len(spells)==len(re.findall(r'SpellId =',source))
    protected=[ROOT/'src/server',ROOT/'src/shared/Configuration']
    paths=[p for folder in protected for p in folder.rglob('*.luau')]
    paths += [ROOT/'src/shared/SpellVFXSystem/Signature/ConnectedFire.luau',ROOT/'src/shared/SpellVFXSystem/Assets/ConnectedFireRig.rbxmx',ROOT/'src/shared/SpellVFXSystem/Assets/ConnectedFirePoses.luau',ROOT/'assets/vfx/studies/3d_fire_v4/connected_fireball.blend']
    record=dict(forms=forms,registered_spells=spells,families=config['families'],form_mapping=config['forms'],gallery=config['gallery'],source_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in paths})
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'inventory.json').write_text(json.dumps(record,indent=2)+'\n')
    print(f'Inventoried {len(forms)} forms, {len(spells)} registered spells, {len(config["families"])} construction families')
    return record

if __name__=='__main__': audit()
