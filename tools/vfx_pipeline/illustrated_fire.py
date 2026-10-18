"""Original editable vector fire study. Local only; never uploads or changes live IDs.

Run with Python + Pillow: python tools/vfx_pipeline/illustrated_fire.py
SVG sources and supersampled grayscale RGBA atlases share the same cubic paths.
"""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vfx/studies/illustrated_fire_v1"
PALETTE = ["#18101f", "#a72d35", "#f25b27", "#ffb73d", "#fff0b1"]
TONES = [18, 72, 142, 206, 255]
VERSION = 1


class Drawing:
    def __init__(self):
        self.image = Image.new("RGBA", (768, 768), (255, 255, 255, 0))
        self.paths = []

    def path(self, start, curves, tone):
        points, current = [start], start
        commands = [f"M{start[0]:.3f},{start[1]:.3f}"]
        for a, b, end in curves:
            commands.append(f"C{a[0]:.3f},{a[1]:.3f} {b[0]:.3f},{b[1]:.3f} {end[0]:.3f},{end[1]:.3f}")
            for i in range(1, 33):
                t, u = i / 32, 1 - i / 32
                points.append(tuple(u**3 * current[k] + 3*u*u*t*a[k] + 3*u*t*t*b[k] + t**3*end[k] for k in (0, 1)))
            current = end
        value = TONES[tone]
        ImageDraw.Draw(self.image).polygon([(x*3, y*3) for x, y in points], fill=(value, value, value, 255))
        self.paths.append(f'<path fill="#{value:02x}{value:02x}{value:02x}" d="{" ".join(commands)} Z"/>')

    def svg(self):
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">\n' + "\n".join(self.paths) + '\n</svg>\n'

    def raster(self):
        return self.image.resize((256, 256), Image.Resampling.LANCZOS)


def tongue(d, x, y, scale, lean, tone):
    def p(a, b):
        return (x + scale*(a + lean*(1-b/100)), y + scale*b)
    d.path(p(0, 100), [
        (p(-49, 88), p(-40, 48), p(-20, 28)),
        (p(-25, 57), p(-9, 54), p(-6, 36)),
        (p(-4, 17), p(28, 10), p(16, -8)),
        (p(57, 20), p(18, 45), p(35, 59)),
        (p(47, 41), p(46, 35), p(48, 32)),
        (p(61, 69), p(40, 101), p(0, 100)),
    ], tone)


def curl(d, t, impact=False):
    # A hooked, directional comet silhouette; nested bands carry painted value detail.
    for band, sc in enumerate([1, .93, .79, .58]):
        w = math.sin(t*math.tau) * 8
        def p(x, y):
            return (128+(x-128)*sc, 132+(y-132)*sc)
        d.path(p(206, 46+w), [
            (p(170, 79), p(109, 22), p(66, 77)),
            (p(31, 120), p(57, 193), p(117, 199)),
            (p(174, 211), p(219, 174), p(220, 125)),
            (p(203, 146), p(181, 161), p(151, 158)),
            (p(189, 140), p(186, 102), p(170, 91)),
            (p(171, 121), p(142, 141), p(117, 135)),
            (p(81, 124), p(103, 80), p(134, 88)),
            (p(165, 100), p(184, 80), p(206, 46+w)),
        ], band)
    for j in range(3):
        tongue(d, 62+j*47, 23+12*(j % 2), .43, 18*math.sin(t*math.tau+j), 2+j%2)
    if impact:
        for j in range(9):
            a = j*math.tau/9 + .2
            x, y = 128+104*math.cos(a), 128+104*math.sin(a)
            tongue(d, x, y, .13, 12, 4)


def draw(kind, t):
    d = Drawing()
    if kind == "core":
        curl(d, t)
    elif kind == "impact":
        # Off-axis serrated blast: alternating hooked rays with a hollow cooling heart.
        for tone, radius in [(0,107),(1,99),(2,90),(3,68),(4,35)]:
            points = []
            for j in range(24):
                a = j*math.tau/24+.18
                r = radius*(1 if j%2 == 0 else .55)+5*math.sin(j*2.3+t*8)
                points.append((128+r*math.cos(a),128+r*math.sin(a)))
            curves = []
            for j,p in enumerate(points):
                q = points[(j+1)%len(points)]
                curves.append(((p[0]*.65+q[0]*.35,p[1]*.65+q[1]*.35),q,q))
            d.path(points[0],curves,tone)
        if kind == "impact":
            # Expand quickly, dissolve into separated fragments, then clear.
            size = max(1, round(256*(.35+.65*min(t*4, 1))))
            img = d.raster().resize((size, size), Image.Resampling.LANCZOS)
            d.image = Image.new("RGBA", (768, 768), (255,255,255,0))
            canvas = Image.new("RGBA", (256,256), (255,255,255,0))
            canvas.alpha_composite(img, ((256-size)//2, (256-size)//2))
            if t > .5:
                alpha = canvas.getchannel("A").point(lambda a: round(a*max(0, (1-t)*2)))
                canvas.putalpha(alpha)
            d.image = canvas.resize((768,768), Image.Resampling.NEAREST)
    elif kind == "tongue":
        lean = math.sin(t*math.tau)*17
        for tone, scale, yy in [(0,1.65,37),(2,1.50,42),(3,1.08,82),(4,.60,130)]:
            tongue(d, 119, yy, scale, lean, tone)
    elif kind == "trail":
        for tone, h in [(0,53),(2,45),(3,27),(4,10)]:
            d.path((0,128-h), [((65,128-h-32),(115,128+h*.2),(171,128-h*.7)),
                ((211,128-h*1.3),(231,128-h*1.5),(256,128-h)),
                ((221,128+h*.3),(195,128+h*.5),(169,128+h)),
                ((113,128+h+27),(58,128+h-22),(0,128+h))], tone)
    elif kind == "smoke":
        for j in range(5):
            x, y = 69+j*24, 165-j*15
            s = 30+5*j+6*math.sin(t*math.tau+j)
            for tone, f in [(0,1),(1,.86),(2,.56)]:
                d.path((x-s*f,y), [((x-s*f,y-s*f),(x+s*f,y-s*f),(x+s*f,y)),
                    ((x+s*f,y+s*f),(x-s*f,y+s*f),(x-s*f,y))],tone)
    elif kind == "ember":
        for tone, sc in [(0,1),(3,.70),(4,.31)]:
            d.path((128,30), [((137+sc*19,94),(150,138),(128,225)),
                ((119-sc*19,157),(112,114),(128,30))],tone)
    else:
        for j in range(6):
            a = j*math.tau/6+t*math.tau
            tongue(d,128+64*math.cos(a),94+49*math.sin(a),.40,18,2+j%3)
    return d


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    source, exports = OUT/"source", OUT/"textures"
    source.mkdir(parents=True, exist_ok=True)
    exports.mkdir(parents=True, exist_ok=True)
    entries = {}
    sheet = Image.new("RGB", (1400, 680), "#100f18")
    pen = ImageDraw.Draw(sheet)
    pen.text((28,20), "ENFLESHED / INK & CINDER / ORIGINAL VECTOR ART STUDY", fill="#fff0b1", font=ImageFont.truetype("arial.ttf",22))
    pen.text((28,55), "LOCAL ARTWORK PROOF - NOT A STUDIO CAPTURE - PUBLISHING AND RUNTIME REVIEW PENDING",fill="#a69aaa")
    for j, kind in enumerate(["core","tongue","trail","impact","smoke","ember","charge"]):
        count = 1 if kind in ("trail","ember") else 16
        grid = 1 if count == 1 else 4
        atlas = Image.new("RGBA", (grid*256,grid*256),(255,255,255,0))
        sources = []
        for i in range(count):
            # One-shots include their terminal frame; loops omit duplicate endpoint.
            t = i/(count-1) if kind == "impact" else i/count
            drawing = draw(kind,t)
            svg = source/f"{kind}_{i:02}.svg"
            svg.write_text(drawing.svg(),encoding="utf-8")
            sources.append({"path":str(svg.relative_to(ROOT)).replace("\\","/"),"sha256":sha(svg)})
            atlas.alpha_composite(drawing.raster(), ((i%grid)*256,(i//grid)*256))
        path = exports/f"ink_cinder_{kind}_v1.png"
        atlas.save(path)
        entries[kind] = {"file":str(path.relative_to(ROOT)).replace("\\","/"),"sha256":sha(path),
            "size":list(atlas.size),"frames":count,"layout":"Grid4x4" if grid==4 else None,
            "loop":kind not in ("impact",),"fps":24 if kind=="impact" else 16,
            "sources":sources,"roblox_id":None,"studio_verified":False,
            "candidate_slot":{"core":"core_plasma","tongue":"flame_tongue","trail":"trail_flame",
                "impact":"explosion_fire","smoke":"smoke_billow","ember":"ember_streak","charge":"rune_circle"}[kind]}
        frame = draw(kind,.33).raster()
        # Palette is a preview LUT; production PNG remains grayscale/multiplicatively tintable.
        pixels = frame.load()
        colors = [tuple(bytes.fromhex(c[1:])) for c in PALETTE]
        if kind == "smoke":
            colors = [(24,16,31),(56,43,61),(95,78,100),(132,112,143),(188,168,192)]
        for y in range(256):
            for x in range(256):
                lum, _, _, a = pixels[x,y]
                index = min(range(5),key=lambda k:abs(TONES[k]-lum))
                pixels[x,y] = (*colors[index],a)
        x,y = 32+(j%4)*345, 100+(j//4)*285
        sheet.paste(frame,(x,y),frame)
        pen.text((x,y+257),kind.upper(),fill="#fff0b1")
    manifest = {"schema_version":1,"version":VERSION,"generator":"tools/vfx_pipeline/illustrated_fire.py",
        "generator_sha256":sha(Path(__file__)),"status":"local_art_review_only","palette_preview":PALETTE,
        "dependencies": ["Pillow"],"assets":entries,
        "notes":["No IDs copied from existing assets; these files have not been uploaded.",
            "SVG records path design; impact scale/fade is applied by the generator during atlas assembly.",
            "Existing signature integration is deliberately gated on Studio review."]}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    sheet.save(OUT/"art_review.png")
    frames = [draw("core",i/16).raster() for i in range(16)]
    frames[0].save(OUT/"core_motion.gif",save_all=True,append_images=frames[1:],duration=63,loop=0,disposal=2)
    print(f"Authored {len(entries)} textures and {sum(len(e['sources']) for e in entries.values())} SVG frames -> {OUT}")


if __name__ == "__main__":
    main()
