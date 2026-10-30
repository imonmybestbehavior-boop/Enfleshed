// Cosmetic review envelopes only. Future runtime playback must use authoritative phase anchors.
export const SOUL_REVIEW_SECONDS=7;
export const SOUL_REVIEW_FPS=24;
const smooth=(a,b,x)=>{const t=Math.max(0,Math.min(1,(x-a)/(b-a)));return t*t*(3-2*t);};
export function sampleSoulPhases(time,mode='full',cancelAt=null){
 const t=Math.max(0,time);
 if(mode==='sustain')return {phase:'Approved sustain',motionTime:t,body:1,boundary:1,sigil:0};
 let phase=t<.6?'Gather':t<1?'Formation':t<5?'Sustain':t<6.1?'Dissipation':'Clear';
 let body=smooth(.6,1,t)*(1-smooth(5,6,t));
 let boundary=smooth(.2,.9,t)*(1-smooth(5.15,6.1,t));
 let sigil=.8*smooth(0,.5,t)*(1-smooth(.85,1.35,t));
 if(cancelAt!==null&&t>=cancelAt){
  body*=1-smooth(cancelAt,cancelAt+.55,t);
  boundary*=1-smooth(cancelAt,cancelAt+.7,t);
  sigil*=1-smooth(cancelAt,cancelAt+.4,t);
  phase=t<cancelAt+.7?'Ending early':'Clear';
 }
 return {phase,motionTime:Math.max(0,t-.6),body,boundary,sigil};
}
