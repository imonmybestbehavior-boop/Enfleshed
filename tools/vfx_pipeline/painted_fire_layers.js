// Local layered fire motion study. Sources remain unchanged; no whole-core warping.
// WebGL evaluates independently aged flame layers using authored painted artwork.
function createLayeredFire(images) {
  const surface=document.createElement('canvas');surface.width=512;surface.height=384;
  const gl=surface.getContext('webgl',{alpha:true,premultipliedAlpha:true,preserveDrawingBuffer:true,antialias:false});
  if(!gl)throw new Error('Layered flame preview needs WebGL; no still-image fallback is substituted.');
  const vertex=`attribute vec2 position;varying vec2 uv;void main(){uv=(position+1.)*.5;gl_Position=vec4(position,0.,1.);}`;
  const fragment=`precision highp float;
  varying vec2 uv;uniform sampler2D coreTex;uniform sampler2D lickTex;uniform float clock;uniform float layerCount;
  float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
  float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.)),f.x),f.y);}
  float turbulence(vec2 p){return .57*noise(p)+.28*noise(p*2.03+7.1)+.15*noise(p*4.07+19.3);}
  vec4 over(vec4 base,vec4 top){return vec4(top.rgb*top.a+base.rgb*(1.-top.a),top.a+base.a*(1.-top.a));}
  vec4 paintedCore(vec2 p){
    vec2 q=(p-vec2(.25,0.))/1.52+.5;vec4 c=texture2D(coreTex,vec2(q.x,1.-q.y));
    float inside=step(0.,q.x)*step(q.x,1.)*step(0.,q.y)*step(q.y,1.);
    // A stable compact mass, with burning fronts revealing independent painted pockets.
    float r=length((p-vec2(.25,0.))*vec2(1.,1.06));
    float feed=turbulence(p*5.+vec2(clock*3.8,-clock*1.1));
    c.a*=inside*(1.-smoothstep(.64,.89,r));
    c.rgb*=.96+.06*feed;return c;
  }
  vec4 flame(vec2 p,float id,float front){
    float seed=hash(vec2(id,31.7)),life=.42+seed*.53;
    float generation=floor(clock/life+seed*7.);
    float age=fract(clock/life+seed*7.);
    float variation=hash(vec2(id,generation));
    float side=sin(id*2.39996+variation*.7);
    vec2 root=vec2(.38-.38*seed,side*(front>.5?.38:.53));
    // Flame roots stay near the burning mass. Tips are convected backwards and upwards.
    vec2 direction=normalize(vec2(-1.,side*.34-.12));vec2 normal=vec2(-direction.y,direction.x);
    float growth=smoothstep(0.,.19,age);
    float lengthOfFlame=(.56+seed*.65)*growth;
    float width=(.40+variation*.35)*(front>.5?.86:1.);
    vec2 d=p-root-direction*(age*.40);
    float along=dot(d,direction),crosswise=dot(d,normal);
    float v=along/max(lengthOfFlame,.001);
    if(v<0.||v>1.)return vec4(0.);
    // The curl travels along each tongue; it never bends the complete fireball.
    crosswise-=sin(v*5.6-clock*(4.+seed*3.)+id)*v*v*.10;
    float u=crosswise/width+.5;
    if(u<0.||u>1.)return vec4(0.);
    vec4 c=texture2D(lickTex,vec2(u,1.-v));
    // Strip the source's broad low-luminance haze; keep only painted fire surfaces.
    float hot=max(c.r,max(c.g,c.b));float visible=smoothstep(.18,.45,hot);
    float breakup=turbulence(p*13.+vec2(clock*7.5+id,-clock*2.3));
    float burn=1.-smoothstep(.54,.98,age);
    float erosion=smoothstep(.06+age*.30,.20+age*.30,breakup+(1.-v)*.45);
    c.a*=visible*burn*growth*erosion*(front>.5?.95:.95);
    c.rgb*=front>.5?vec3(1.,1.,.97):vec3(.96,.86,.79);
    return c;
  }
  void main(){
    vec2 p=vec2(mix(-2.05,1.3,uv.x),mix(-1.25,1.25,uv.y));vec4 result=vec4(0.);
    for(int i=0;i<12;i++){if(float(i)<layerCount)result=over(result,flame(p,float(i),0.));}
    result=over(result,paintedCore(p));
    for(int i=0;i<8;i++){if(float(i)<layerCount*.67)result=over(result,flame(p,float(i)+19.,1.));}
    // Small detached wisps: separate trajectories and dissolving lifetimes.
    for(int i=0;i<5;i++){
      float id=float(i),a=fract(clock*(.7+id*.09)+id*.219);
      vec2 center=vec2(-.4-a*1.1,sin(id*2.4)*.63-a*a*.35);
      vec2 q=(p-center)/vec2(.12,.23)+.5;
      if(q.x>0.&&q.x<1.&&q.y>0.&&q.y<1.){
        vec4 c=texture2D(lickTex,vec2(q.x,1.-q.y));
        c.a*=smoothstep(.25,.6,max(c.r,c.g))*sin(a*3.14159)*.65;
        result=over(result,c);
      }
    }
    gl_FragColor=result;
  }`;
  function compile(type,source){const shader=gl.createShader(type);gl.shaderSource(shader,source);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(shader));return shader;}
  const program=gl.createProgram();gl.attachShader(program,compile(gl.VERTEX_SHADER,vertex));gl.attachShader(program,compile(gl.FRAGMENT_SHADER,fragment));gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(program));gl.useProgram(program);
  const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);
  const attr=gl.getAttribLocation(program,'position');gl.enableVertexAttribArray(attr);gl.vertexAttribPointer(attr,2,gl.FLOAT,false,0,0);
  for(const [unit,name,image] of [[0,'coreTex',images.core],[1,'lickTex',images.flameLick]]){const texture=gl.createTexture();gl.activeTexture(gl.TEXTURE0+unit);gl.bindTexture(gl.TEXTURE_2D,texture);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,false);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.uniform1i(gl.getUniformLocation(program,name),unit);}
  const timeUniform=gl.getUniformLocation(program,'clock'),countUniform=gl.getUniformLocation(program,'layerCount');
  return {canvas:surface,render(t,count=12){gl.uniform1f(timeUniform,t);gl.uniform1f(countUniform,count);gl.viewport(0,0,surface.width,surface.height);gl.drawArrays(gl.TRIANGLES,0,6);}};
}
