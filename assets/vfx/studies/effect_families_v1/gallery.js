// Local art-review renderer. No external packages, game services or custom runtime shader contract.
import {sampleSoulPhases,SOUL_REVIEW_SECONDS,SOUL_REVIEW_FPS} from './soul_phases.mjs';
const $=id=>document.getElementById(id), canvas=$('scene');
const gl=canvas.getContext('webgl',{alpha:false,antialias:true,preserveDrawingBuffer:true});
const state={key:'fire',frame:0,playing:true,orbit:false,yaw:0,elevation:.24,span:4.6,speed:1,sequence:'full',cancelAt:null};
const cache=new Map(), owned={buffers:[],textures:[],program:null,shaders:[]};
let active=null,last=0,acc=0,disposed=false,raf=0,drag=null;
const description={
 fire:{family:'TRAVELING VOLUME',name:'Connected fireball',description:'The existing connected body, evaluated from its approved Blender source with its original 24 surface frames.',watch:'Flame contours moving over the rounded core toward the broken tail.',scope:'Approved source reference. Browser lighting differs from the game.',intent:'This reference is unchanged. The new study is isolated from gameplay.',palette:['#9b1609','#ff3b08','#ff870c','#ffdc3e']},
 soul:{family:'AREA ENVELOPE / SOUL · SPIRIT',name:'Soul field',description:'The existing Soul sigil gathers the field. Full-size little ghosts rise through the ground, then fade away at height.',watch:'Review the beginning and ending. Use Sustain only to inspect the wisps without the casting cue.',scope:'Rising motion and fading approved. Ground emergence and full-effect phases are the new review pass.',intent:'A stationary Field study. The sigil reuses existing custom artwork. No spell behavior is added.',palette:['#10464c','#2d8682','#50dcbe','#dcfff6']}
};
function shader(type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));owned.shaders.push(s);return s;}
function setup(){
 if(!gl)throw Error('WebGL is unavailable. Open this local gallery in a browser with graphics enabled.');
 const vs=shader(gl.VERTEX_SHADER,`attribute vec3 position;attribute vec3 color;attribute vec2 uv;attribute float visibility;uniform vec3 right;uniform vec3 up;uniform vec3 forward;uniform vec3 target;uniform vec2 scale;varying vec3 tint;varying vec2 texcoord;varying float shown;varying float worldY;uniform bool groundClip;void main(){vec3 p=position-target;gl_Position=vec4(dot(p,right)/scale.x,dot(p,up)/scale.y,dot(p,forward)/70.,1.);tint=color;texcoord=uv;shown=visibility;worldY=position.y;}`);
 const fs=shader(gl.FRAGMENT_SHADER,`precision mediump float;uniform sampler2D surface;uniform bool textured;uniform bool cel;uniform float layerOpacity;uniform vec3 paint;varying vec3 tint;varying vec2 texcoord;varying float shown;varying float worldY;uniform bool groundClip;void main(){if(groundClip&&worldY<.035)discard;if(shown*layerOpacity<.002)discard;vec4 c=textured?texture2D(surface,texcoord):vec4(tint,1.);if(c.a<.5)discard;if(cel&&length(c.rgb)>.15){vec3 a=vec3(.063,.275,.298),b=vec3(.176,.525,.510),d=vec3(.314,.863,.745),e=vec3(.863,1.,.965);vec3 q=a;float m=distance(c.rgb,a);float n=distance(c.rgb,b);if(n<m){q=b;m=n;}n=distance(c.rgb,d);if(n<m){q=d;m=n;}n=distance(c.rgb,e);if(n<m)q=e;c.rgb=q;}gl_FragColor=vec4(c.rgb*paint,c.a*shown*layerOpacity);}`);
 const p=gl.createProgram();gl.attachShader(p,vs);gl.attachShader(p,fs);gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(p));owned.program=p;gl.useProgram(p);
 gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.clearColor(.065,.083,.108,1);
 return {position:gl.getAttribLocation(p,'position'),color:gl.getAttribLocation(p,'color'),uv:gl.getAttribLocation(p,'uv'),visibility:gl.getAttribLocation(p,'visibility'),right:gl.getUniformLocation(p,'right'),up:gl.getUniformLocation(p,'up'),forward:gl.getUniformLocation(p,'forward'),target:gl.getUniformLocation(p,'target'),scale:gl.getUniformLocation(p,'scale'),textured:gl.getUniformLocation(p,'textured'),surface:gl.getUniformLocation(p,'surface'),cel:gl.getUniformLocation(p,'cel'),layerOpacity:gl.getUniformLocation(p,'layerOpacity'),paint:gl.getUniformLocation(p,'paint'),groundClip:gl.getUniformLocation(p,'groundClip')};
}
let loc;
function buffer(values,kind=gl.ARRAY_BUFFER,usage=gl.STATIC_DRAW){const b=gl.createBuffer();owned.buffers.push(b);gl.bindBuffer(kind,b);gl.bufferData(kind,values,usage);return b;}
function attr(b,location,size){gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.enableVertexAttribArray(location);gl.vertexAttribPointer(location,size,gl.FLOAT,false,0,0);}
function geometry(positions,colors,uv,indices,dynamic=false){return {p:buffer(positions,gl.ARRAY_BUFFER,dynamic?gl.DYNAMIC_DRAW:gl.STATIC_DRAW),c:buffer(colors,gl.ARRAY_BUFFER,dynamic?gl.DYNAMIC_DRAW:gl.STATIC_DRAW),v:buffer(new Float32Array(positions.length/3).fill(1),gl.ARRAY_BUFFER,dynamic?gl.DYNAMIC_DRAW:gl.STATIC_DRAW),u:buffer(uv),i:indices?buffer(new Uint16Array(indices),gl.ELEMENT_ARRAY_BUFFER):null,count:indices?indices.length:positions.length/3};}
function draw(mesh,mode=gl.TRIANGLES,textured=false){attr(mesh.p,loc.position,3);attr(mesh.c,loc.color,3);attr(mesh.u,loc.uv,2);attr(mesh.v,loc.visibility,1);gl.uniform1i(loc.textured,textured?1:0);if(mesh.i){gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,mesh.i);gl.drawElements(mode,mesh.count,gl.UNSIGNED_SHORT,0);}else gl.drawArrays(mode,0,mesh.count);}
async function json(path){const r=await fetch(path);if(!r.ok)throw Error(`Cannot load ${path} (${r.status})`);return r.json();}
async function floats(path){const r=await fetch(path);if(!r.ok)throw Error(`Cannot load ${path}`);return new Float32Array(await r.arrayBuffer());}
async function texture(path){
 const img=new Image();img.src=path;await img.decode();if(disposed)throw Error('Review closed');
 const tex=gl.createTexture();owned.textures.push(tex);gl.bindTexture(gl.TEXTURE_2D,tex);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,img);
 gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);return tex;
}
async function load(key){
 if(cache.has(key))return cache.get(key);
 const task=(async()=>{
  const meta=await json(`${key}.mesh.json`),positions=await floats(`${key}.positions.bin`);
  const colors=key==='soul'?await floats('soul.colors.bin'):new Float32Array(meta.vertices*3).fill(1);
  const visibility=key==='soul'?await floats('soul.visibility.bin'):null;
  if(disposed)throw Error('Review closed');
  if(positions.length!==meta.vertices*3*meta.frames)throw Error('Incomplete geometry cache');
  const uv=meta.uv?new Float32Array(meta.uv.flat()):new Float32Array(meta.vertices*2);
  const mesh=geometry(positions.subarray(0,meta.vertices*3),colors.subarray(0,meta.vertices*3),uv,meta.indices,true);
  const textures=[];
  for(const path of meta.textures||[]){
   textures.push(await texture(path));
  }
  const triangleOrder=Array.from({length:meta.indices.length/3},(_,i)=>i);
  const sigil=key==='soul'?await texture('../../textures/soul_sigil.png'):null;
  return {meta,positions,colors,visibility,mesh,textures,sigil,alphaScratch:new Float32Array(meta.vertices),triangleOrder,depths:new Float32Array(triangleOrder.length),sortedIndices:new Uint16Array(meta.indices.length)};
 })();cache.set(key,task);return task;
}
function reference(){
 const p=[],c=[];function line(a,b){p.push(...a,...b);c.push(.15,.19,.24,.15,.19,.24);}
 for(let i=-12;i<=12;i++){line([i,0,-12],[i,0,12]);line([-12,0,i],[12,0,i]);}
 return geometry(new Float32Array(p),new Float32Array(c),new Float32Array(p.length/3*2));
}
function figure(x){
 const p=[],c=[];
 function box(cx,cy,cz,w,h,d){const points=[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]];const faces=[[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]];faces.forEach((face,f)=>{for(const index of [0,1,2,0,2,3]){const v=points[face[index]];p.push(cx+v[0]*w/2,cy+v[1]*h/2,cz+v[2]*d/2);const shade=[.45,.38,.34,.53,.6,.3][f];c.push(shade*.8,shade*.88,shade);}});}
 box(x,4.5,0,1,1,1);box(x,2.9,0,1.5,2.1,.8);box(x-.43,.9,0,.62,1.8,.65);box(x+.43,.9,0,.62,1.8,.65);box(x-1.04,2.85,0,.5,1.8,.6);box(x+1.04,2.85,0,.5,1.8,.6);
 return geometry(new Float32Array(p),new Float32Array(c),new Float32Array(p.length/3*2));
}
let floor,figures,sigilPlane;
function frames(){return state.key==='soul'&&state.sequence==='full'?SOUL_REVIEW_SECONDS*SOUL_REVIEW_FPS:active.meta.frames;}
function phase(){return sampleSoulPhases(state.frame/SOUL_REVIEW_FPS,state.sequence,state.cancelAt);}
function restart(){state.frame=0;state.cancelAt=null;acc=0;if(active){$('frame').max=frames()-1;updateStatus();}}
function reset(){state.yaw=0;state.elevation=state.key==='soul'?.48:.24;state.span=state.key==='soul'?6.3:4.6;state.orbit=false;$('orbit').textContent='Orbit off';$('orbit').setAttribute('aria-pressed','false');$('viewlabel').textContent='Side view · drag to orbit';}
async function select(key){
 state.key=key;active=null;state.frame=0;state.cancelAt=null;acc=0;reset();
 $('sequence').disabled=key!=='soul';$('end').disabled=key!=='soul'||state.sequence!=='full';$('phase-note').hidden=key!=='soul';
 for(const k of ['fire','soul']){$(k).classList.toggle('selected',k===key);$(k).setAttribute('aria-pressed',String(k===key));}
 const d=description[key];for(const id of ['family','name','description','watch','scope','intent'])$(id).textContent=d[id];
 $('swatches').replaceChildren(...d.palette.map(color=>{const s=document.createElement('span');s.style.background=color;return s;}));$('status').textContent='Loading geometry…';
 try{const loaded=await load(key);if(state.key!==key||disposed)return;active=loaded;$('frame').max=frames()-1;updateStatus();}catch(error){fail(error);}
}
function updateStatus(){if(!active)return;const label=state.key==='soul'?phase().phase:'Approved reference';$('status').textContent=`${label} · ${state.playing?'Playing':'Paused'}`;$('status').dataset.phase=label;$('frame').value=state.frame;$('readout').textContent=`${label} · ${(state.frame/active.meta.fps).toFixed(2)} s · ${state.frame+1}/${frames()}`;}
function render(){
 const w=Math.max(1,Math.round(canvas.clientWidth*Math.min(devicePixelRatio,1.25))),h=Math.max(1,Math.round(canvas.clientHeight*Math.min(devicePixelRatio,1.25)));
 if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);}
 gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);if(!active)return;
 const sy=Math.sin(state.yaw),cy=Math.cos(state.yaw),se=Math.sin(state.elevation),ce=Math.cos(state.elevation);
 gl.uniform3f(loc.right,cy,0,-sy);gl.uniform3f(loc.up,-sy*se,ce,-cy*se);gl.uniform3f(loc.forward,-sy*ce,-se,-cy*ce);gl.uniform3f(loc.target,state.key==='fire'?-.9:-.5,2.3,0);gl.uniform2f(loc.scale,state.span*w/h,state.span);
 gl.uniform1i(loc.cel,0);gl.uniform1i(loc.groundClip,0);
 gl.uniform1f(loc.layerOpacity,1);gl.uniform3f(loc.paint,1,1,1);
 if($('grid').checked)draw(floor,gl.LINES);
 if($('figure').checked)draw(figures[state.key]);
 const envelope=state.key==='soul'?phase():null;
 if(envelope&&envelope.sigil>.001){
  gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,active.sigil);gl.uniform1i(loc.surface,0);
  gl.uniform3f(loc.paint,.30,.72,.63);gl.uniform1f(loc.layerOpacity,envelope.sigil);
  gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(false);draw(sigilPlane,gl.TRIANGLES,true);
  gl.disable(gl.BLEND);gl.depthMask(true);gl.uniform1f(loc.layerOpacity,1);gl.uniform3f(loc.paint,1,1,1);
 }
 const pose=envelope?Math.floor(envelope.motionTime*active.meta.fps)%active.meta.frames:state.frame;
 const n=active.meta.vertices*3,start=pose*n;
 gl.bindBuffer(gl.ARRAY_BUFFER,active.mesh.p);gl.bufferSubData(gl.ARRAY_BUFFER,0,active.positions.subarray(start,start+n));
 if(state.key==='soul'){
  gl.bindBuffer(gl.ARRAY_BUFFER,active.mesh.c);gl.bufferSubData(gl.ARRAY_BUFFER,0,active.colors.subarray(start,start+n));
  const a=pose*active.meta.vertices,boundary=active.meta.boundary_vertices;
  for(let i=0;i<active.meta.vertices;i++)active.alphaScratch[i]=active.visibility[a+i]*(i<boundary?envelope.boundary:envelope.body);
  if(state.sequence==='full')for(const group of active.meta.groups){if(envelope.motionTime+1e-6<group.birth_seconds)active.alphaScratch.fill(0,group.start,group.start+group.count);}
  gl.bindBuffer(gl.ARRAY_BUFFER,active.mesh.v);gl.bufferSubData(gl.ARRAY_BUFFER,0,active.alphaScratch);
 }
 if(active.textures.length){gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,active.textures[Math.floor(state.frame/2)%24]);gl.uniform1i(loc.surface,0);}
 gl.uniform1i(loc.cel,state.key==='soul'?1:0);gl.uniform1i(loc.groundClip,state.key==='soul'?1:0);
 if(state.key==='soul'){
  // Back-to-front transparency, including facial marks; keep the opaque reference unchanged.
  const signature=`${pose}/${state.yaw}/${state.elevation}`;
  if(active.sortSignature!==signature){
   const indices=active.meta.indices,p=active.positions,depth=active.depths;
   for(let i=0;i<depth.length;i++){let d=0;for(let k=0;k<3;k++){const v=start+indices[i*3+k]*3;d+=p[v]*(-sy*ce)+p[v+1]*(-se)+p[v+2]*(-cy*ce);}depth[i]=d;}
   active.triangleOrder.sort((a,b)=>depth[b]-depth[a]);
   let k=0;for(const triangle of active.triangleOrder){active.sortedIndices[k++]=indices[triangle*3];active.sortedIndices[k++]=indices[triangle*3+1];active.sortedIndices[k++]=indices[triangle*3+2];}
   gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,active.mesh.i);gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER,0,active.sortedIndices);active.sortSignature=signature;
  }
  gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(false);
  gl.enable(gl.CULL_FACE);gl.cullFace(gl.FRONT);
 }
 draw(active.mesh,gl.TRIANGLES,!!active.textures.length);
 gl.disable(gl.BLEND);gl.depthMask(true);gl.disable(gl.CULL_FACE);
 const error=gl.getError();if(error!==gl.NO_ERROR)throw Error(`Graphics error ${error}`);
}
function tick(now){
 if(disposed)return;const dt=Math.min((now-last)/1000,.1);last=now;
 if(!document.hidden&&active){if(state.playing){acc+=dt*state.speed;const count=Math.floor(acc*active.meta.fps);if(count){const next=state.frame+count;if(next>=frames())state.cancelAt=null;state.frame=next%frames();acc-=count/active.meta.fps;updateStatus();}}if(state.orbit)state.yaw+=dt*.35;}
 // Bound review drawing to 30 Hz, including when the animation is paused.
 if(!document.hidden&&now-(tick.drawn||0)>1000/30){try{render();tick.drawn=now;}catch(e){fail(e);return;}}
 raf=requestAnimationFrame(tick);
}
function fail(error){$('status').textContent=`Review unavailable: ${error.message}`;$('status').style.color='#ffa38f';console.error(error);}
function dispose(){if(disposed)return;disposed=true;cancelAnimationFrame(raf);if(gl){for(const b of owned.buffers)gl.deleteBuffer(b);for(const t of owned.textures)gl.deleteTexture(t);for(const s of owned.shaders)gl.deleteShader(s);if(owned.program)gl.deleteProgram(owned.program);}cache.clear();active=null;}
$('play').onclick=()=>{state.playing=!state.playing;$('play').textContent=state.playing?'Pause':'Play';updateStatus();};
$('frame').oninput=()=>{state.frame=Number($('frame').value);state.cancelAt=null;state.playing=false;acc=0;$('play').textContent='Play';updateStatus();};
$('sequence').onchange=()=>{state.sequence=$('sequence').value;$('end').disabled=state.key!=='soul'||state.sequence!=='full';restart();};
$('restart').onclick=()=>{restart();state.playing=true;$('play').textContent='Pause';updateStatus();};
$('end').onclick=()=>{if(!active||state.key!=='soul'||state.sequence!=='full')return;state.cancelAt=state.frame/SOUL_REVIEW_FPS;state.playing=true;$('play').textContent='Pause';updateStatus();};
$('speed').onchange=()=>state.speed=Number($('speed').value);
$('orbit').onclick=()=>{state.orbit=!state.orbit;$('orbit').textContent=state.orbit?'Orbit on':'Orbit off';$('orbit').setAttribute('aria-pressed',String(state.orbit));$('viewlabel').textContent=state.orbit?'Orbiting camera':'Free camera';};
$('reset').onclick=reset;
for(const [id,yaw,elevation] of [['side',0,.2],['front',Math.PI/2,.2],['top',0,1.25]])$(id).onclick=()=>{reset();state.yaw=yaw;state.elevation=elevation;$('viewlabel').textContent=id==='top'?'Above':`${id[0].toUpperCase()+id.slice(1)} view`;};
for(const key of ['fire','soul'])$(key).onclick=()=>select(key);
canvas.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);};
canvas.onpointermove=e=>{if(!drag)return;state.yaw+=(e.clientX-drag.x)*.008;state.elevation=Math.max(-.2,Math.min(1.4,state.elevation+(e.clientY-drag.y)*.006));drag={x:e.clientX,y:e.clientY};$('viewlabel').textContent='Free camera';};
canvas.onpointerup=canvas.onpointercancel=()=>drag=null;
canvas.addEventListener('wheel',e=>{e.preventDefault();state.span=Math.max(2,Math.min(12,state.span*Math.exp(e.deltaY*.001)));},{passive:false});
window.addEventListener('pagehide',dispose);
canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();dispose();fail(Error('Graphics context lost. Reload to restore the review.'));});
try{
 loc=setup();floor=reference();figures={fire:figure(-4.8),soul:figure(-6.4)};
 sigilPlane=geometry(new Float32Array([-4.6,.025,-4.6,4.6,.025,-4.6,4.6,.025,4.6,-4.6,.025,4.6]),new Float32Array(12).fill(1),new Float32Array([0,0,1,0,1,1,0,1]),[0,1,2,0,2,3]);
 const inventory=await json('inventory.json');
 for(const family of Object.values(inventory.families)){const tr=document.createElement('tr');for(const text of [family.label,family.forms.join(', '),family.motion]){const td=document.createElement('td');td.textContent=text;tr.append(td);}$('inventory').append(tr);}
 await select(new URLSearchParams(location.search).get('effect')==='fire'?'fire':'soul');raf=requestAnimationFrame(tick);
}catch(e){fail(e);}
