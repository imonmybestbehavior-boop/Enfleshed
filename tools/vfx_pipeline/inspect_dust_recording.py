from pathlib import Path
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.validation-tools/video-deps'))
import imageio_ffmpeg
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[2]
out=root/'assets/vfx/studies/style_unification_v1/dust_recording';out.mkdir(exist_ok=True)
video=Path('C:/Users/bello/Videos/Screen Recordings/Screen Recording 2026-10-19 111413.mp4')
r=subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-i',str(video),'-vf','fps=1,scale=640:-1','-frames:v','100','-y',str(out/'frame_%03d.jpg')],capture_output=True,text=True)
print(r.stderr[-1800:]);r.check_returncode()
files=sorted(out.glob('frame_*.jpg'))
for batch in range(0,len(files),16):
    subset=files[batch:batch+16];thumb=Image.open(subset[0]);w,h=thumb.size
    sheet=Image.new('RGB',(w*4,(h+24)*4),'#242424');d=ImageDraw.Draw(sheet)
    for i,path in enumerate(subset):
        x=(i%4)*w;y=(i//4)*(h+24);sheet.paste(Image.open(path),(x,y+24));d.text((x+8,y+4),f'{batch+i} seconds',fill='white')
    path=out/f'contact_{batch//16}.jpg';sheet.save(path);print(path)
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-ss','10.8','-i',str(video),'-t','2','-vf','fps=8,scale=800:-1','-y',str(out/'detail_%03d.jpg')],check=True)
files=sorted(out.glob('detail_*.jpg'));w,h=Image.open(files[0]).size
sheet=Image.new('RGB',(w*4,(h+24)*4),'#242424');d=ImageDraw.Draw(sheet)
for i,path in enumerate(files):
 x=(i%4)*w;y=(i//4)*(h+24);sheet.paste(Image.open(path),(x,y+24));d.text((x+8,y+4),f'{10.8+i/8:.3f} seconds',fill='white')
sheet.save(out/'poison_detail.jpg')
