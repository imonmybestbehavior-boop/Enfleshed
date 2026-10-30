"""Deterministic review-only Soul area geometry. No gameplay files or uploads."""
import array
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/effect_families_v1'
TAU=math.tau
ROWS,COLS=22,12
FPS,FRAMES=24,96
CONFIG=json.loads(Path(__file__).with_name('effect_families.json').read_text())['gallery']['prototype']
PALETTE=[[v/255 for v in c] for c in CONFIG['palette']]

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)

def geometry(t):
    positions,colors,indices,visibility=[],[],[],[]
    def vertex(p,c,shown=1):
        positions.extend(p);colors.extend(c);visibility.append(shown)
        return len(positions)//3-1
    def quad(a,b,c,d): indices.extend((a,b,c,a,c,d))
    # A restrained, stationary boundary. Its fixed radius is independent of wisp motion.
    for arc in range(12):
        base=len(positions)//3
        for i in range(9):
            angle=TAU*(arc/12+(i/8)*.068)
            for side in range(2):
                r=CONFIG['radius']-.10+side*.10
                vertex((r*math.cos(angle),.045,r*math.sin(angle)),PALETTE[2 if arc%3 else 3])
        for i in range(8):
            a=base+i*2;quad(a,a+1,a+3,a+2)
    # Staggered ghosts retain their silhouette and fade as their root rises past the height band.
    # A narrower delayed echo follows each primary, rather than repeating a fire surface.
    for ghost in range(6):
        angle=TAU*ghost/6
        for echo in range(2):
            age=(t/4+ghost/6-echo*.105)%1
            scale=1 if echo==0 else .47
            # Full-size ghost starts below the floor; its crown crosses ground at birth.
            altitude=-2.5*scale+age*(2.5*scale+2.45)
            opacity=1-smooth(1.55,2.4,altitude)
            if echo: opacity*=.45
            def shown(u,a=0):
                return opacity
            def point(u,a,lift=0):
                inward=.9*math.sin(math.pi*u*.82)+.23*math.sin(TAU*(u-age))
                ring=2.65-inward-.35*age
                center=(math.cos(angle)*ring,altitude+u*2.5*scale,math.sin(angle)*ring)
                radius=math.sin(math.pi*u)**.62*(.24+.46*smooth(.3,.7,u))*scale
                lateral=.22*math.sin(TAU*(u*.8-age*.35)+ghost)*scale
                radial=(radius+lift)*math.cos(a)
                tangential=(radius*.48+lift)*math.sin(a)+lateral
                return (center[0]+radial*math.cos(angle)-tangential*math.sin(angle),center[1],center[2]+radial*math.sin(angle)+tangential*math.cos(angle))
            base=len(positions)//3
            for row in range(ROWS+1):
                u=row/ROWS
                # Rounded ghost head, narrow trailing lower tip.
                for col in range(COLS+1):
                    a=TAU*col/COLS
                    p=point(u,a)
                    contour=math.sin(TAU*(u*2.3-age*1.8)+.9*math.sin(a+age*TAU))
                    band=0 if math.cos(a)<-.25 else (3 if contour>.91 and math.cos(a)>.35 else (2 if contour>.04 else 1))
                    color=PALETTE[band]
                    if echo: color=[v*.65 for v in color]
                    vertex(p,color,shown(u,a))
            for row in range(ROWS):
                for col in range(COLS):
                    a=base+row*(COLS+1)+col;quad(a,a+1,a+COLS+2,a+COLS+1)
            if not echo:
                # Tiny eyes and an open mouth hug the curved outer face, not camera billboards.
                # Faces share the whole wisp's fade; no floating face or top-down wipe.
                for face_a,face_u,wide,tall in [(-.48,.73,.16,.043),(.48,.73,.16,.043),(0,.61,.13,.038)]:
                    center_index=vertex(point(face_u,face_a,.018),(.018,.045,.055),shown(face_u,face_a))
                    edge=[]
                    for k in range(13):
                        theta=TAU*k/12
                        u=face_u+math.sin(theta)*tall
                        a=face_a+math.cos(theta)*wide
                        edge.append(vertex(point(u,a,.018),(.018,.045,.055),shown(u,a)))
                    for k in range(12): indices.extend((center_index,edge[k],edge[k+1]))
    return positions,colors,indices,visibility

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    poses=array.array('f');tints=array.array('f');visibility=array.array('f')
    for f in range(FRAMES):
        p,c,indices,v=geometry(f/FPS)
        poses.extend(p);tints.extend(c);visibility.extend(v)
    if sys.byteorder!='little': poses.byteswap();tints.byteswap();visibility.byteswap()
    (OUT/'soul.positions.bin').write_bytes(poses.tobytes())
    (OUT/'soul.colors.bin').write_bytes(tints.tobytes())
    (OUT/'soul.visibility.bin').write_bytes(visibility.tobytes())
    groups=[]
    start=12*9*2
    for ghost in range(6):
        for echo in range(2):
            count=(ROWS+1)*(COLS+1)+(0 if echo else 3*14)
            groups.append(dict(start=start,count=count,birth_seconds=((-ghost/6+echo*.105)%1)*4))
            start+=count
    assert start==len(p)//3
    record=dict(vertices=len(p)//3,boundary_vertices=12*9*2,frames=FRAMES,fps=FPS,indices=indices,recipe=CONFIG,
        groups=groups,
        positions_sha256=hashlib.sha256(poses.tobytes()).hexdigest(),
        birth='Constant-size geometry rises from below ground; world-height clipping hides the underground portion',
        disappearance='Whole-wisp smooth opacity fade at root heights 1.55 to 2.4 studs; no shrinking or height wipe',faces='Two curved eyes and a mouth on each primary; faces fade with their parent',
        status='Review geometry only; not exported, imported or activated in Studio')
    (OUT/'soul.mesh.json').write_text(json.dumps(record,separators=(',',':')))
    print(f'Soul field: {len(p)//3} vertices, {len(indices)//3} triangles, {FRAMES} poses; radius {CONFIG["radius"]} studs')

if __name__=='__main__': main()
