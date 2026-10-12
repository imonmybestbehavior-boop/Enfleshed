"""Draw the measured proposal from its source data; does not generate game geometry."""
import html
import json
from pathlib import Path
HERE = Path(__file__).resolve().parent
d = json.loads((HERE/'layout.json').read_text())
palette = {'dangerous':'#cab398', 'safer':'#b4c2b5'}
out = ['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1220" viewBox="0 0 1600 1220">', '<rect width="1600" height="1220" fill="#f4f0e7"/>', '<style>text{font-family:DejaVu Sans,sans-serif;fill:#202b2c} .small{font-size:16px}.label{font-size:19px}.title{font-size:30px;font-weight:bold}</style>']
def text(x,y,t,cls='label'):
 out.append(f'<text x="{x}" y="{y}" class="{cls}">{html.escape(t)}</text>')
def rect(x,y,w,h,fill,stroke='none'):
 out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}"/>')
def line(points,color,width,dash=''):
 points=' '.join(f'{x},{y}' for x,y in points)
 out.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="butt"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
text(56,54,'LOWER LAYER · CITY LAYOUT PROPOSAL','title')
text(56,86,'Drawing-led topology • 1,280 × 800 studs • Plan only, not a rebuilt place','label')
text(56,116,'Courtyard side: MORE DANGEROUS  /  Housing + sewer side: SAFER','label')
out.append('<g transform="translate(140,170)">')
rect(0,0,1280,800,'#313a3b')
rect(40,40,1200,720,'#6e7774')
for a in d['areas']:
 points=' '.join(f'{x},{y}' for x,y in a['polygon'])
 out.append(f'<polygon points="{points}" fill="{palette[a["side"]]}"/>')
# Thin perimeter indicates occupied envelopes, not rectangular solid building assets.
for region in ('courtyard','gate_space','structural_void'):
 x0,y0,x1,y1=d[region]['rect'];rect(x0,y0,x1-x0,y1-y0,'#eee7d7' if region!='structural_void' else '#313a3b')
line(d['street']['points'],'#f9f4e7',d['street']['width'])
for r in d['ground_routes']:line(r['points'],'#f9f4e7',r['width'])
x0,y0,x1,y1=d['wall']['rect'];g0,g1=d['wall']['opening']
rect(x0,y0,g0-x0,y1-y0,'#334b52');rect(g1,y0,x1-g1,y1-y0,'#334b52')
for r in d['upper_routes']:
 line(r['points'],'#267482',3,'8 4')
 for x,y in r['stairs']:rect(x-4,y-4,8,8,'#267482')
line(d['reserved_cross_wall_catwalk']['points'],'#9b4775',4,'4 5')
for x,y,t in [(68,88,'A'),(440,88,'B'),(848,88,'C'),(72,470,'D'),(364,466,'E'),(1168,470,'F')]:text(x,y,t,'title')
# Numeric landmarks are keyed outside the map so narrow alleys remain readable.
for n,x,y in [(1,1180,380),(2,1020,411),(3,1012,176),(4,1020,454),(5,1104,568),(6,360,404)]:
 out.append(f'<circle cx="{x}" cy="{y}" r="13" fill="#fff8e6" stroke="#34474c" stroke-width="2"/>')
 out.append(f'<text x="{x}" y="{y+6}" text-anchor="middle" class="small">{n}</text>')
out.append('<text x="80" y="646" style="fill:#f4f0e7;font-size:16px">ANCIENT</text><text x="80" y="670" style="fill:#f4f0e7;font-size:16px">RECESS</text>')
# Actual measured scale; no implication that the drawing specified a metric scale.
line([[64,760],[264,760]],'#f4f0e7',4)
for x in (64,164,264):line([[x,754],[x,766]],'#f4f0e7',2)
for x,label in [(64,'0'),(164,'100'),(264,'200 studs')]:
 out.append(f'<text x="{x}" y="789" style="fill:#f4f0e7;font-size:16px">{label}</text>')
out.append('</g>')
text(140,1010,'A–C  More dangerous neighborhoods', 'label')
text(800,1010,'D–F  Safer neighborhoods', 'label')
for x,y,t in [(140,1044,'1  Wall-side street · 24 studs clear'),(140,1074,'2  Internal opening · 32-stud wall gap'),(140,1104,'3  Enclosed courtyard · 112 × 96 studs'),(800,1044,'4  Transition pocket · 56 × 40 studs'),(800,1074,'5  Underground entry · reserve −18 level'),(800,1104,'6  Drawn catwalk · crossing access undecided')]:text(x,y,t,'small')
text(140,1148,'Pale cuts: ground route reservations   |   Blue dashed: upper links   |   Purple dotted: unresolved crossing','small')
text(140,1178,'Colored masses are housing envelopes to subdivide into interlocking buildings—not six giant blocks.','small')
out.append('</svg>')
(HERE/'city-layout.svg').write_text('\n'.join(out)+'\n')
print('Wrote city-layout.svg')
