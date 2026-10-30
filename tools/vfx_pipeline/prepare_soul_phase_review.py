"""Preserve the approved sustain bytes while adding only phase metadata."""
import hashlib
import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/effect_families_v1'
parser=argparse.ArgumentParser();parser.add_argument('--ground-emergence-revision',action='store_true');args=parser.parse_args()
record_path=OUT/('ground_emergence_revision.json' if args.ground_emergence_revision else 'approved_soul_sustain.json')
paths=[OUT/f'soul.{kind}.bin' for kind in ['positions','colors','visibility']]
paths += [ROOT/'assets/vfx/textures/soul_sigil.png']
hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
if record_path.exists():
    assert json.loads(record_path.read_text())['sha256']==hashes,'Approved sustain/source artwork changed'
else:
    record_path.write_text(json.dumps(dict(instruction='User requested full-size emergence from the ground after approving the fade' if args.ground_emergence_revision else 'User: Yes that looks great. Continue',date='2026-10-18',scope='Requested ground-emergence revision; original approval snapshot is retained' if args.ground_emergence_revision else 'Rising ghost motion, faces and whole-wisp fade at height; phase envelope is a new review',sha256=hashes),indent=2)+'\n')
meta=json.loads((OUT/'soul.mesh.json').read_text())
meta['boundary_vertices']=12*9*2
meta['sustain_approval']='2026-10-18: user approved fade; ground emergence subsequently requested' if args.ground_emergence_revision else '2026-10-18: user approved rising wisps and fade at height'
(OUT/'soul.mesh.json').write_text(json.dumps(meta,separators=(',',':')))
print('Approved sustain and existing sigil hashes preserved; phase metadata ready')
