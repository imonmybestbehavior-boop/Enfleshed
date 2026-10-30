"""Bake the approved code-native palette lookup into existing texture atlases.

Sequential, deterministic color conversion. Source alpha/layout/frames are copied unchanged.
No generative artwork, spatial filtering, new silhouettes or new animation is introduced.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/style_unification_v1'
BAKED=OUT/'baked'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def bake_frame(frame,palette,profile,soft=False,line=False):
    rgb=np.asarray(palette,dtype=np.float64)
    lum=frame[:,:,0].astype(np.float64)/255
    alpha=frame[:,:,3]
    visible=alpha>64
    cap_accent=np.count_nonzero((lum>.97)&visible)>np.count_nonzero(visible)*.12
    if soft:
        colors=rgb[0]+(rgb[2]-rgb[0])*lum[:,:,None]
    elif line:
        colors=np.broadcast_to(rgb[2],frame.shape[:2]+(3,))
    else:
        low,shadow,light,accent=profile['texture_thresholds']
        band=np.select([lum<low,lum<shadow,lum<light,lum<accent],[4,0,1,2],default=3)
        if cap_accent:band=np.where(band==3,2,band)
        colors=rgb[band]
    result=np.empty_like(frame)
    # Match JavaScript Math.round, including half-values in continuous soft falloff.
    result[:,:,:3]=np.floor(colors+.5).clip(0,255).astype(np.uint8)
    result[:,:,3]=alpha
    return result,bool(cap_accent)

def bake_atlas(source,asset,palette,profile):
    array=np.asarray(source.convert('RGBA'))
    if not np.array_equal(array[:,:,0],array[:,:,1]) or not np.array_equal(array[:,:,0],array[:,:,2]):
        raise ValueError(f'{asset["name"]}: source is not the expected grayscale palette mask')
    n=int(asset['layout'].split('Grid')[1].split('x')[0]) if asset['layout'] else 1
    h,w=array.shape[:2];fh,fw=h//n,w//n
    assert (w,h)==(asset['width'],asset['height']) and w%n==h%n==0
    result=np.empty_like(array);caps=[]
    for y in range(n):
        for x in range(n):
            frame=array[y*fh:(y+1)*fh,x*fw:(x+1)*fw]
            colored,capped=bake_frame(frame,palette,profile,asset['soft'],asset['line'])
            result[y*fh:(y+1)*fh,x*fw:(x+1)*fw]=colored;caps.append(capped)
    assert np.array_equal(result[:,:,3],array[:,:,3])
    return Image.fromarray(result),caps

def contact_sheet(entries):
    cell=180;cols=7;rows=(len(entries)+cols-1)//cols
    sheet=Image.new('RGB',(cols*cell,rows*210),(20,27,33));draw=ImageDraw.Draw(sheet)
    for i,entry in enumerate(entries):
        x=(i%cols)*cell;y=(i//cols)*210
        with Image.open(BAKED/entry['file']) as image:
            n=int(entry['layout'].split('Grid')[1].split('x')[0]) if entry['layout'] else 1
            fw,fh=image.width//n,image.height//n
            frames=[image.crop(((k%n)*fw,(k//n)*fh,(k%n+1)*fw,(k//n+1)*fh)) for k in range(n*n)]
            frame=max(frames,key=lambda f:np.count_nonzero(np.asarray(f)[:,:,3]>32))
            frame.thumbnail((156,156),Image.Resampling.LANCZOS)
            sheet.paste(frame,(x+(cell-frame.width)//2,y+(160-frame.height)//2),frame)
        draw.text((x+8,y+164),entry['name'][:24],fill=(233,227,211))
        draw.text((x+8,y+180),entry['identity'],fill=(147,177,178))
    sheet.save(BAKED/'baked_contact_sheet.png')

def main():
    catalog=json.loads((OUT/'catalog.json').read_text())
    profile=catalog['profile'];sources=[a for a in catalog['assets'] if a['kind']=='texture']
    BAKED.mkdir(parents=True,exist_ok=True)
    entries=[];primary=[]
    for asset in sources:
        path=OUT/asset['source'];source_hash=sha(path)
        with Image.open(path) as source:
            for identity in dict.fromkeys(asset['identities']):
                colored,caps=bake_atlas(source,asset,profile['palettes'][identity],profile)
                file=Path('textures')/identity/f'{identity}__{asset["name"]}.png'
                (BAKED/file).parent.mkdir(parents=True,exist_ok=True)
                colored.save(BAKED/file,compress_level=6)
                entry=dict(name=asset['name'],identity=identity,file=file.as_posix(),source=path.resolve().relative_to(ROOT).as_posix(),source_sha256=source_hash,
                    sha256=sha(BAKED/file),width=asset['width'],height=asset['height'],layout=asset['layout'],tiles=asset['tiles'],frames=len(caps),
                    soft=asset['soft'],line=asset['line'],accent_capped_frames=caps,alpha='Byte-for-byte copy of source alpha',uploaded_id=None)
                entries.append(entry)
                if identity==asset['identity']:primary.append(entry)
        assert sha(path)==source_hash
    # Preserve the approved profile used for every lookup in this package.
    (BAKED/'style_profile.json').write_text(json.dumps(profile,indent=2)+'\n')
    manifest=dict(status='Baked local textures; not uploaded or activated',source_textures=len(sources),identity_variants=len(entries),entries=entries,
        approval='User approved the existing-asset style comparison, then requested: Bake it',
        color_space='8-bit sRGB palette values with straight alpha; no resampling or frame rearrangement',
        import_notes=['Colored PNGs already contain their palette. Avoid multiplying by the previous saturated palette tint; begin with white Color and restrained emission for the import comparison.',
            'Shared source textures have identity-specific variants. Keep the identity/name mapping from this manifest.',
            'Existing runtime playback rates remain authoritative; atlas layout is unchanged.',
            'Mesh material variants and baked textures require representative Studio verification before production activation.'])
    (BAKED/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    contact_sheet(primary)
    # Browser reviews can now show the actual baked bytes rather than a runtime lookup.
    lookup={}
    for entry in entries:lookup.setdefault(entry['name'],{})[entry['identity']]='baked/'+entry['file']
    (OUT/'baked_lookup.json').write_text(json.dumps(lookup,indent=2)+'\n')
    print(f'Baked {len(entries)} identity-specific atlases from {len(sources)} existing textures. Source alpha, layout and originals preserved.')

if __name__=='__main__':main()
