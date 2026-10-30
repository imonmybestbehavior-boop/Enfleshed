const $=id=>document.getElementById(id);
const canvases=[$('before'),$('after')],contexts=canvases.map(c=>c.getContext('2d',{alpha:false}));
const scratch=document.createElement('canvas'),sx=scratch.getContext('2d',{willReadFrequently:true});
let catalog,bakedLookup,row,source,bakedSource,packets,hull,frame=0,playing=true,yaw=.5,elevation=.23,last=0,acc=0,raf,disposed=false,drag=null,selection=0;
let cachedTexture=null,visible=[];
const cache=new Map();
const getJSON=async p=>{const r=await fetch(p);if(!r.ok)throw Error(`Cannot load ${p}`);return r.json();};
const rgb=c=>`rgb(${c.map(v=>Math.round(v)).join(',')})`;
function currentPalette(){return catalog.profile.palettes[$('identity').value==='All'?row.identity:$('identity').value];}
function oldPalette(){return catalog.kits[$('identity').value==='All'?row.identity:$('identity').value].palette;}
function fail(e){$('status').textContent=`Review unavailable: ${e.message}`;console.error(e);}
function assetLabel(a){return `${a.kind==='mesh'?'Mesh':'Texture'} · ${a.name}${a.ink_for?' (existing ink hull)':''}`;}
function filter(){
 visible=catalog.assets.filter(a=>($('identity').value==='All'||a.identities.includes($('identity').value))&&($('kind').value==='all'||a.kind===$('kind').value));
 $('asset').replaceChildren(...visible.map(a=>{const o=document.createElement('option');o.value=a.name+'|'+a.kind;o.textContent=assetLabel(a);return o;}));
 if(visible.length){const first=visible.find(a=>a.name==='soul_wisp')||visible[0];$('asset').value=first.name+'|'+first.kind;select(first);}
 else{$('status').textContent='No assets in this filter.';row=null;}
}
async function cached(path,type){if(!cache.has(path)){const work=type==='image'?(async()=>{const image=new Image();image.src=path;await image.decode();return image;})():getJSON(path);cache.set(path,work);if(cache.size>12)cache.delete(cache.keys().next().value);}return cache.get(path);}
async function select(a){
 const ticket=++selection;row=null;source=null;bakedSource=null;packets=null;hull=null;frame=0;acc=0;cachedTexture=null;
 $('status').textContent='Loading existing asset…';$('name').textContent=a.name;$('usage').textContent=a.usage;
 try{
  const data=await cached(a.kind==='texture'?a.source:a.packet,a.kind==='texture'?'image':'json');
  const paletteIdentity=$('identity').value==='All'?a.identity:$('identity').value;
  const bakedPath=a.kind==='texture'?bakedLookup[a.name][paletteIdentity]:null;
  const baked=a.kind==='texture'?await cached(bakedPath,'image'):null;
  let outline=null;
  if(a.kind==='mesh'&&!a.ink_for){const ink=catalog.assets.find(b=>b.kind==='mesh'&&b.ink_for===a.name);if(ink)outline=await cached(ink.packet,'json');}
  if(disposed||selection!==ticket)return;
  row=a;if(a.kind==='texture'){source=data;bakedSource=baked;}else{packets=data;hull=outline;}
  const count=a.layout?Number(a.layout.match(/\d+/)[0])**2:1;
  $('frame').max=count-1;$('frame').disabled=count===1;$('fps').disabled=count===1;$('orbit').disabled=a.kind!=='mesh';$('outline').disabled=a.kind!=='mesh'||!hull;
  $('invariants').textContent=a.kind==='texture'?`${a.width} × ${a.height} · ${count} existing frame${count===1?'':'s'} · original alpha and atlas retained`:`${a.triangles.toLocaleString()} existing triangles · same shape, UVs and orientation`;
  $('category').textContent=($('identity').value==='All'?a.identity:$('identity').value).replace('Spirit','Soul / Spirit').toUpperCase();
  $('swatches').replaceChildren(...currentPalette().map(color=>{const s=document.createElement('span');s.style.background=rgb(color);return s;}));
  $('download').hidden=false;if(a.kind==='texture'){$('download').href=bakedPath;$('download').download=bakedPath.split('/').pop();$('download').textContent=`Download baked atlas · ${paletteIdentity}`;}else{$('download').href=a.variant;$('download').download=a.name+'.glb';$('download').textContent=`Download material variant · ${a.identity}`;}
  $('status').textContent=a.kind==='texture'?'Showing actual baked PNG bytes. Original alpha, frames and source artwork are retained.':'Existing GLB geometry; face material regions and contour color revised.';
  update();
 }catch(e){if(selection===ticket)fail(e);}
}
function update(){if(!row)return;const count=row.layout?Number(row.layout.match(/\d+/)[0])**2:1;$('frame').value=frame;$('counter').textContent=row.kind==='mesh'?'Same camera · both views':`${frame+1} / ${count}`;}
function size(canvas){const w=Math.max(1,Math.round(canvas.clientWidth*Math.min(devicePixelRatio,1.3))),h=Math.max(1,Math.round(canvas.clientHeight*Math.min(devicePixelRatio,1.3)));if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}return [w,h];}
function textureFrame(){
 if(cachedTexture?.frame===frame&&cachedTexture?.name===row.name)return cachedTexture;
 const n=row.layout?Number(row.layout.match(/\d+/)[0]):1,tw=row.width/n,th=row.height/n;
 scratch.width=tw;scratch.height=th;sx.clearRect(0,0,tw,th);sx.drawImage(source,(frame%n)*tw,Math.floor(frame/n)*th,tw,th,0,0,tw,th);
 const pixels=sx.getImageData(0,0,tw,th),before=new ImageData(tw,th),old=oldPalette();
 for(let i=0;i<pixels.data.length;i+=4){const lum=pixels.data[i]/255;for(let k=0;k<3;k++)before.data[i+k]=Math.round(old.Mid[k]*lum);before.data[i+3]=pixels.data[i+3];}
 const result={name:row.name,frame,views:[document.createElement('canvas'),document.createElement('canvas')]};
 result.views.forEach((c,i)=>{c.width=tw;c.height=th;const ctx=c.getContext('2d');if(i)ctx.drawImage(bakedSource,(frame%n)*tw,Math.floor(frame/n)*th,tw,th,0,0,tw,th);else ctx.putImageData(before,0,0);});cachedTexture=result;return result;
}
function textureDraw(ctx,w,h,revised){
 const image=textureFrame().views[revised?1:0],maxW=w*.76,maxH=h*.78,fit=Math.min(maxW/image.width,maxH/image.height);
 ctx.imageSmoothingEnabled=true;ctx.drawImage(image,(w-image.width*fit)/2,(h-image.height*fit)/2,image.width*fit,image.height*fit);
}
const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
function meshDraw(ctx,w,h,revised){
 const all=packets.flatMap(p=>p.positions),lo=[0,1,2].map(k=>Math.min(...all.map(p=>p[k]))),hi=[0,1,2].map(k=>Math.max(...all.map(p=>p[k])));
 const center=lo.map((v,k)=>(v+hi[k])/2),span=Math.max(...hi.map((v,k)=>v-lo[k]))||1;
 const sy=Math.sin(yaw),cy=Math.cos(yaw),se=Math.sin(elevation),ce=Math.cos(elevation),right=[cy,0,-sy],up=[-sy*se,ce,-cy*se],forward=[-sy*ce,-se,-cy*ce],scale=Math.min(w,h)*.72/span;
 const faces=[],palette=currentPalette(),old=oldPalette(),light=[-.42,.78,.46];
 for(const [list,isInk] of [[hull&&$('outline').checked?hull:[],true],[packets,!!row.ink_for]])for(const packet of list){
  const projected=packet.positions.map(p=>{const q=p.map((v,k)=>v-center[k]);return [w/2+dot(q,right)*scale,h/2-dot(q,up)*scale,dot(q,forward)];});
  for(let i=0;i<packet.indices.length;i+=3){
   const ids=packet.indices.slice(i,i+3),normal=[0,1,2].map(k=>ids.reduce((n,id)=>n+packet.normals[id][k],0)/3);
   if(dot(normal,forward)>=.02)continue;
   const points=ids.map(id=>projected[id]),band=isInk?4:packet.bands[i/3];
   const shade=.55+.45*Math.max(0,dot(normal,light));
   const color=revised?palette[band]:(isInk?[14,10,14]:old.Mid.map(v=>v*shade));
   faces.push({points,depth:points.reduce((v,p)=>v+p[2],0)/3,color});
  }
 }
 faces.sort((a,b)=>b.depth-a.depth);
 for(const face of faces){ctx.beginPath();face.points.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.closePath();ctx.fillStyle=rgb(face.color);ctx.fill();ctx.strokeStyle=rgb(face.color);ctx.lineWidth=.45;ctx.stroke();}
}
function render(){contexts.forEach((ctx,i)=>{const [w,h]=size(canvases[i]);ctx.fillStyle='#141b21';ctx.fillRect(0,0,w,h);if(row){if(row.kind==='texture')textureDraw(ctx,w,h,!!i);else meshDraw(ctx,w,h,!!i);}});}
function tick(now){if(disposed)return;const dt=Math.min((now-last)/1000,.1);last=now;if(!document.hidden&&row){if(playing&&row.kind==='texture'&&row.layout){const fps=Number($('fps').value);acc+=dt;const count=Math.floor(acc*fps);if(count){frame=(frame+count)%(Number(row.layout.match(/\d+/)[0])**2);acc-=count/fps;update();}}if(playing&&row.kind==='mesh'&&$('orbit').checked)yaw+=dt*.32;if(now-(tick.drawn||0)>1000/24){try{render();tick.drawn=now;}catch(e){fail(e);return;}}}raf=requestAnimationFrame(tick);}
$('identity').onchange=filter;$('kind').onchange=filter;
$('asset').onchange=()=>select(visible.find(a=>a.name+'|'+a.kind===$('asset').value));
for(const [id,step] of [['previous',-1],['next',1]])$(id).onclick=()=>{const i=visible.findIndex(a=>a.name+'|'+a.kind===$('asset').value);const a=visible[(i+step+visible.length)%visible.length];if(a){$('asset').value=a.name+'|'+a.kind;select(a);}};
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pause':'Play';};
$('frame').oninput=()=>{frame=Number($('frame').value);playing=false;$('play').textContent='Play';acc=0;update();};
$('reset').onclick=()=>{yaw=.5;elevation=.23;};
for(const canvas of canvases){canvas.onpointerdown=e=>{drag=[e.clientX,e.clientY];canvas.setPointerCapture(e.pointerId);};canvas.onpointermove=e=>{if(!drag)return;yaw+=(e.clientX-drag[0])*.009;elevation=Math.max(-1.2,Math.min(1.2,elevation+(e.clientY-drag[1])*.007));drag=[e.clientX,e.clientY];};canvas.onpointerup=canvas.onpointercancel=()=>drag=null;}
window.addEventListener('pagehide',()=>{disposed=true;cancelAnimationFrame(raf);cache.clear();cachedTexture=null;source=bakedSource=packets=hull=null;scratch.width=scratch.height=1;});
try{catalog=await getJSON('catalog.json');bakedLookup=await getJSON('baked_lookup.json');for(const name of ['All',...Object.keys(catalog.profile.palettes)]){const option=document.createElement('option');option.value=name;option.textContent=name==='All'?'All identities':name==='Spirit'?'Soul / Spirit':name;$('identity').append(option);}$('identity').value='Spirit';filter();raf=requestAnimationFrame(tick);}catch(e){fail(e);}
