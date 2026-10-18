"""Assemble existing Blender renders into review GIFs and a self-contained player."""
import base64
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"assets/vfx/studies/3d_fire_v1"


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument("--version",choices=["1","2","3","4"],default="1")
    args = parser.parse_args()
    OUT = ROOT/f"assets/vfx/studies/3d_fire_v{args.version}"
    frames = {}
    durations = [10*(((i+1)*100//24)-(i*100//24)) for i in range(48)]
    for mode in ("fixed","orbit","diagnostic"):
        paths = sorted((OUT/mode).glob("*.png"))
        assert len(paths) == 48, (mode,len(paths))
        decoded = [Image.open(p).convert("RGB") for p in paths]
        decoded[0].save(OUT/f"{mode}.gif",save_all=True,append_images=decoded[1:],duration=durations,loop=0)
        frames[mode] = ["data:image/png;base64,"+base64.b64encode(p.read_bytes()).decode() for p in paths]
    sheet = Image.new("RGB",(1280,528),(24,27,35))
    draw = ImageDraw.Draw(sheet)
    for row,mode in enumerate(("fixed","diagnostic")):
        for col,index in enumerate((0,12,24,36)):
            frame = Image.open(OUT/mode/f"{index+1:03d}.png").convert("RGB").resize((320,240 if args.version=="1" else 213))
            sheet.paste(frame,(col*320,row*264+24))
            draw.text((col*320+8,row*264+8),f"{mode} / frame {index+1}",fill="white")
    sheet.save(OUT/"motion_contact_sheet.png")
    html = '''<!doctype html><html><meta charset="utf-8"><title>3D fire motion study</title>
<style>body{margin:0;background:#12151d;color:#e8edf5;font:16px system-ui}main{max-width:1320px;margin:auto;padding:24px}h1{font-size:26px;margin:0 0 8px}p{color:#b4becf;line-height:1.5}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}article{background:#202530;border-radius:12px;overflow:hidden}h2{font-size:17px;padding:0 16px}img{display:block;width:100%;aspect-ratio:4/3}button,input{margin:10px}button{background:#e8b64a;border:0;border-radius:6px;padding:10px 16px}input[type=range]{width:280px}small{color:#b4becf}details{margin-top:18px}details article{max-width:640px;margin-top:12px}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style>
<main><h1>3D fire — first motion study</h1><p>Solid skinned geometry, four painted color bands, 24 FPS. Blender preview; Roblox import is pending. Shapes are deliberately unfinished. Watch whether ridges travel through the body rather than wobble in place.</p>
<div><button id="play">Pause</button><label>Frame <input id="frame" type="range" min="0" max="47" value="0"></label><span id="counter"></span><label>Speed <select id="speed"><option value="0.5">Half</option><option value="1" selected>Normal</option></select></label></div>
<div class="grid"><article><h2>Fixed camera · body flow</h2><img id="fixed" alt="Fixed camera fire animation"></article><article><h2>Orbit · front, side, rear and elevation</h2><img id="orbit" alt="Orbiting camera fire animation"></article></div>
<details open><summary>Isolated flame · inspect the transport and reset</summary><article><img id="diagnostic" alt="One deforming flame lifecycle"></article></details>
<p>Current limitations: chunky overlapping lobes, visible faceting, simple color bands and no separate breakaway fragments yet. This is a motion construction test, not the finished concept-sheet appearance.</p></main>
<script>const frames=__FRAMES__;let playing=true,frame=0,last=performance.now(),acc=0;const slider=document.querySelector('#frame'),speed=document.querySelector('#speed');function show(){for(const mode of Object.keys(frames))document.getElementById(mode).src=frames[mode][frame];slider.value=frame;document.querySelector('#counter').textContent=`${frame+1} / 48`;}
document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'Pause':'Play';};slider.oninput=()=>{frame=+slider.value;playing=false;document.querySelector('#play').textContent='Play';show();};function tick(now){if(playing){acc+=(now-last)*Number(speed.value);if(acc>=1000/24){const steps=Math.floor(acc/(1000/24));acc%=1000/24;frame=(frame+steps)%48;show();}}last=now;requestAnimationFrame(tick);}show();requestAnimationFrame(tick);</script></html>'''
    if args.version in ("2","3","4"):
        html = html.replace("first motion study","hooked flame revision")
        html = html.replace("Solid skinned geometry, four painted color bands, 24 FPS. Blender preview; Roblox import is pending. Shapes are deliberately unfinished. Watch whether ridges travel through the body rather than wobble in place.",
            "Rebuilt tapered tongues, returning hooks and changing widths. Same approved four-color palette. 24 FPS Blender preview; this revised asset has not been imported into Roblox. The original rig test is preserved separately.")
        html = html.replace("chunky overlapping lobes, visible faceting, simple color bands and no separate breakaway fragments yet.",
            "repeated curl shapes, some visible gaps and no separate breakaway fragments yet. The full-body form still needs refinement.")
        html = html.replace("aspect-ratio:4/3","aspect-ratio:3/2")
        previous=str(int(args.version)-1)
        old = base64.b64encode((ROOT/f"assets/vfx/studies/3d_fire_v{previous}/fixed.gif").read_bytes()).decode()
        html = html.replace("</main>",'<details><summary>Previous plate construction — comparison</summary><article><img alt="Previous construction" src="data:image/gif;base64,'+old+'"></article></details></main>')
    if args.version=="3":
        html=html.replace("hooked flame revision","curls following the body")
        html=html.replace("Rebuilt tapered tongues, returning hooks and changing widths.","Flames sweep backward and curl around the body instead of flaring outward.")
        html=html.replace("Previous plate construction","Previous outward curls")
    if args.version=="4":
        html=html.replace("hooked flame revision","connected burning volume")
        html=html.replace("Rebuilt tapered tongues, returning hooks and changing widths.","One connected rounded body with flame contours flowing toward an eroding tail.")
        html=html.replace("Previous plate construction","Retired separate-piece construction")
        html=html.replace("Isolated flame · inspect the transport and reset","Close-up · flame motion across the core")
        html=html.replace("One deforming flame lifecycle","Close-up of flowing core contours")
        html=html.replace("repeated curl shapes, some visible gaps and no separate breakaway fragments yet. The full-body form still needs refinement.","tail breakup and small flame detail still need refinement. This connected-volume construction has not been verified in Roblox.")
    (OUT/"review.html").write_text(html.replace("__FRAMES__",json.dumps(frames)),encoding="utf-8")
    if args.version in ("2","3","4"):
        webroot = ROOT/"assets/vfx/previews"
        assetroot = webroot/f"fire_3d_v{args.version}"
        webframes = {}
        for mode in frames:
            destination = assetroot/mode
            destination.mkdir(parents=True,exist_ok=True)
            paths = sorted((OUT/mode).glob("*.png"))
            for path in paths: shutil.copy2(path,destination/path.name)
            webframes[mode] = [f"fire_3d_v{args.version}/{mode}/{path.name}" for path in paths]
        previous_name=f"fire_3d_v{previous}_fixed.gif"
        shutil.copy2(ROOT/f"assets/vfx/studies/3d_fire_v{previous}/fixed.gif",webroot/previous_name)
        webhtml = html.replace("data:image/gif;base64,"+old,previous_name)
        (webroot/"fire_3d_study.html").write_text(webhtml.replace("__FRAMES__",json.dumps(webframes)),encoding="utf-8")
    print("Created three 48-frame GIFs, a self-contained review player, and motion contact sheet")


if __name__ == "__main__": main()
