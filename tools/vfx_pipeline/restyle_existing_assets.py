"""Re-material existing GLBs and index existing texture frames for a code-native style review.

No raster artwork, silhouette, UV, triangle, or animation is generated/replaced.
Texture comparisons render the existing source pixels through the style palette in the browser.
"""
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/vfx/studies/style_unification_v1'
PROFILE=ROOT/'assets/vfx/styles/cel_traditional_v1.json'
COMPONENTS={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
COUNTS={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def read_glb(path):
    data=path.read_bytes();magic,version,total=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and total==len(data)
    offset=12;doc=None;binary=b''
    while offset<len(data):
        size,kind=struct.unpack_from('<II',data,offset);offset+=8
        chunk=data[offset:offset+size];offset+=size
        if kind==0x4e4f534a:doc=json.loads(chunk)
        elif kind==0x004e4942:binary=chunk
    return doc,binary

def accessor(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    kind,size=COMPONENTS[a['componentType']];n=COUNTS[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',n*size)
    return [list(struct.unpack_from('<'+kind*n,binary,offset+i*stride)) for i in range(a['count'])]

def write_glb(path,doc,binary):
    doc['buffers'][0]['byteLength']=len(binary)
    text=json.dumps(doc,separators=(',',':')).encode();text+=b' '*((-len(text))%4)
    binary+=b'\0'*((-len(binary))%4)
    data=struct.pack('<III',0x46546c67,2,12+8+len(text)+8+len(binary))
    data+=struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(binary),0x004e4942)+binary
    path.write_bytes(data)

def material_bands(positions,normals,indices,ink):
    if ink:return [4]*(len(indices)//3)
    light=(-.42,.78,.46);length=math.sqrt(sum(v*v for v in light));light=[v/length for v in light]
    samples=[]
    for offset in range(0,len(indices),3):
        tri=indices[offset:offset+3]
        dot=sum(sum(a*b for a,b in zip(normals[v],light)) for v in tri)/3
        a,b,c=[positions[i] for i in tri];u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
        cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
        area=math.sqrt(sum(x*x for x in cross))/2
        samples.append((dot,area))
    total=sum(a for _,a in samples) or 1
    def quantile(q):
        acc=0
        for d,a in sorted(samples):
            acc+=a
            if acc>=total*q:return d
        return samples[-1][0]
    low,lit,accent=quantile(.25),quantile(.70),quantile(.96)
    if max(d for d,_ in samples)-min(d for d,_ in samples)<.15:return [1]*len(samples)
    # Do not turn an entire tied top plane into a large cream/white highlight.
    accent_ok=sum(a for d,a in samples if d>=accent)/total<=.08
    return [0 if d<low else (1 if d<lit else (3 if accent_ok and d>=accent else 2)) for d,_ in samples]

def identities():
    source=(ROOT/'src/shared/SpellVFXSystem/Signature/SignatureKits.luau').read_text()
    body=source.split('Kits.Definitions = {',1)[1].split('-- Selection,',1)[0]
    matches=list(re.finditer(r'^\t(\w+) = \{',body,re.M));kits={};usage={}
    for i,m in enumerate(matches):
        chunk=body[m.start():matches[i+1].start() if i+1<len(matches) else body.index('\n}\n')]
        colors={key:[int(v) for v in values.split(',')] for key,values in re.findall(r'(Hi|Mid|Lo|Smoke) = Color3.fromRGB\(([^)]+)\)',chunk)}
        if not colors:continue
        assets=chunk.split('Assets = {',1)[1].split('\n\t\t},',1)[0]
        refs=re.findall(r'"([a-z][a-z0-9_]+)"',assets)
        kits[m.group(1)]=dict(palette=colors,assets=refs)
        for ref in refs:
            owners=usage.setdefault(ref,[])
            if m.group(1) not in owners:owners.append(m.group(1))
    return kits,usage

def main():
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'meshes').mkdir(exist_ok=True)
    profile=json.loads(PROFILE.read_text());kits,usage=identities()
    meshes=json.loads((ROOT/'assets/vfx/meshes/meshes.json').read_text())
    textures=json.loads((ROOT/'assets/vfx/textures/textures.json').read_text())
    records=[];source_hashes={}
    for kind,definitions in [('texture',textures),('mesh',meshes)]:
        for name,meta in sorted(definitions.items()):
            base=meta.get('ink_for',name);available=usage.get(base,[])
            identity=available[0] if available else ('Force' if name not in {'sinew_trail','flesh_shard','sinew_tendril'} else 'Body')
            row=dict(name=name,kind=kind,identities=available or [identity],identity=identity,usage=meta['usage'])
            if kind=='texture':
                path=ROOT/'assets/vfx/textures'/meta['file']
                row.update(source='../../textures/'+meta['file'],width=meta['width'],height=meta['height'],layout=meta['layout'],tiles=meta['tiles'],soft=name in profile['soft_assets'],line=name in profile['line_assets'])
            else:
                path=ROOT/'assets/vfx/meshes'/meta['glb'];doc,binary=read_glb(path)
                revised=copy.deepcopy(doc);newbin=bytearray(binary);ink=bool(meta.get('ink_for'))
                packets=[];palette=profile['palettes'][identity]
                for mi,mesh in enumerate(doc['meshes']):
                    revised['meshes'][mi]['primitives']=[]
                    for pi,primitive in enumerate(mesh['primitives']):
                        positions=accessor(doc,binary,primitive['attributes']['POSITION'])
                        normals=accessor(doc,binary,primitive['attributes']['NORMAL'])
                        indices=[v[0] for v in accessor(doc,binary,primitive['indices'])]
                        bands=material_bands(positions,normals,indices,ink);regions={}
                        for offset in range(0,len(indices),3):
                            tri=indices[offset:offset+3]
                            band=bands[offset//3]
                            regions.setdefault(band,[]).extend(tri)
                        for band,group in sorted(regions.items()):
                            newbin.extend(b'\0'*((-len(newbin))%4));offset=len(newbin)
                            payload=struct.pack('<'+'I'*len(group),*group);newbin.extend(payload)
                            vi=len(revised['bufferViews']);revised['bufferViews'].append(dict(buffer=0,byteOffset=offset,byteLength=len(payload),target=34963))
                            ai=len(revised['accessors']);revised['accessors'].append(dict(bufferView=vi,componentType=5125,count=len(group),type='SCALAR'))
                            region=copy.deepcopy(primitive);region['indices']=ai;region['material']=band
                            revised['meshes'][mi]['primitives'].append(region)
                        packets.append(dict(positions=positions,normals=normals,indices=indices,bands=bands))
                revised['materials']=[]
                for band,rgb in enumerate(palette):
                    linear=[((c/255)/12.92 if c/255<=.04045 else ((c/255+.055)/1.055)**2.4) for c in rgb]
                    revised['materials'].append(dict(name=f'{identity}_{profile["palette_order"][band]}',pbrMetallicRoughness=dict(baseColorFactor=linear+[1],metallicFactor=0,roughnessFactor=1),extensions={'KHR_materials_unlit':{}}))
                revised.setdefault('extensionsUsed',[])
                if 'KHR_materials_unlit' not in revised['extensionsUsed']:revised['extensionsUsed'].append('KHR_materials_unlit')
                revised.setdefault('extras',{}).update(restyle='Material regions only; positions, normals, UVs and all oriented triangles preserved',identity=identity)
                variant=OUT/'meshes'/meta['glb'];write_glb(variant,revised,bytes(newbin))
                # Export canonical geometry for the dependency-free browser review.
                packet_path=OUT/'meshes'/f'{name}.json';packet_path.write_text(json.dumps(packets,separators=(',',':')))
                row.update(source='../../meshes/'+meta['glb'],variant='meshes/'+meta['glb'],packet='meshes/'+packet_path.name,ink_for=meta.get('ink_for'),triangles=meta['triangles'],size=meta['size'])
            source_hashes[path.relative_to(ROOT).as_posix()]=digest(path)
            records.append(row)
    protected=[ROOT/'assets/vfx/asset_ids.json',ROOT/'src/shared/SpellVFXSystem/Signature/SignatureLibrary.luau',ROOT/'src/shared/SpellVFXSystem/Signature/SignatureKits.luau',ROOT/'src/shared/SpellVFXSystem/Signature/SignatureRenderer.luau']
    for p in protected:source_hashes[p.relative_to(ROOT).as_posix()]=digest(p)
    catalog=dict(profile=profile,kits=kits,assets=records,source_sha256=source_hashes,status='Local material/palette review variants; no production activation or uploads',texture_scope='Existing PNG pixels and alpha are rendered through palettes in the browser; original PNGs are not edited',mesh_scope='60 GLBs use face material regions; all source triangles retained. FBX/Roblox material transfer is unverified')
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
    print(f'Restyled material variants for {len(meshes)} existing meshes; indexed {len(textures)} existing textures and {len(kits)} identities for paired comparison')

if __name__=='__main__':main()
