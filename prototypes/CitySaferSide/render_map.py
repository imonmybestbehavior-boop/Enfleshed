"""Locator map from the approved plan and this build's actual route records."""
import json
from pathlib import Path
H=Path(__file__).resolve().parent
D=json.loads((H/'assembly.json').read_text());P=json.loads((H.parents[1]/'docs/lower-layer-city/layout.json').read_text())
s=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1060" viewBox="0 0 1440 1060"><rect width="1440" height="1060" fill="#f4f0e7"/><style>text{font:18px DejaVu Sans,sans-serif;fill:#203232}</style>', '<text x="60" y="45" style="font-size:28px">CITY BUILD 3 · SERVICE WEAVE B + C / E / F</text>', '<text x="60" y="76">Actual built routes · gray areas reserved for later · coordinates match Roblox X/Z</text>', '<g transform="translate(70,100)">']
for a in P['areas']:
 points=' '.join(f'{x},{z}' for x,z in a['polygon'])
 color='#bad0bc' if a['id'] in 'BCEF' else '#dad7ce'
 s.append(f'<polygon points="{points}" fill="{color}"/>')
 x,z=a['polygon'][0];s.append(f'<text x="{x+12}" y="{z+26}">{a["id"]}'+(' · built' if a['id'] in 'BCEF' else ' · reserved')+'</text>')
def line(points,color,width,dash=''):
 ps=' '.join(f'{x},{z}' for x,z in points)
 s.append(f'<polyline points="{ps}" fill="none" stroke="{color}" stroke-width="{width}"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
s.append('<rect x="956" y="128" width="112" height="96" fill="#eee0bd"/>')
for r in D['ground_routes']:line(r['points'],'#fbf8ed',r['width'])
line(P['street']['points'],'#eee0bd',24)
s.append('<path d="M48 412H1004 M1036 412H1232" stroke="#42565b" stroke-width="24"/>')
for r in D['upper_routes']:line(r['points'],'#27687f',3,'6 4')
markers=[('S',1020,460),('O',1020,412),('H',1104,568)]+[(str(i+1),t['bottom'][0],t['bottom'][1]) for i,t in enumerate(D['towers'])]
for label,x,z in markers:
 s.append(f'<circle cx="{x}" cy="{z}" r="13" fill="#fff7dd" stroke="#34474c" stroke-width="2"/><text x="{x}" y="{z+6}" text-anchor="middle">{label}</text>')
s.append('</g>')
s.append('<text x="760" y="1020">5/6 Courtyard +18 · 7/8 Service weave +36</text>')
for x,y,t in [(70,890,'S  Spawn / safer-side opening pocket'),(70,920,'O  Internal wall opening → wall-side street'),(70,950,'H  Sealed underground reservation'),(70,980,'Blue dashed = upper routes; pale lines = ground'),(760,890,'1  E west stair · (432, 616) → +18'),(760,920,'2  E east stair · (584, 592) → +18'),(760,950,'3  F west stair · (952, 624) → +36'),(760,980,'4  F east stair · (1080, 544) → +36')]:s.append(f'<text x="{x}" y="{y}">{t}</text>')
s.append('</svg>');(H/'build-map.svg').write_text('\n'.join(s)+'\n')
