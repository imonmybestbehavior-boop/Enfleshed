import assert from 'node:assert/strict';
import {sampleSoulPhases as sample,SOUL_REVIEW_SECONDS as duration} from '../assets/vfx/studies/effect_families_v1/soul_phases.mjs';
assert.equal(duration,7);
assert.equal(sample(0).body,0);assert.equal(sample(0).boundary,0);assert.equal(sample(0).sigil,0);
assert.equal(sample(.4).phase,'Gather');assert.ok(sample(.4).sigil>0);assert.equal(sample(.4).body,0);
assert.equal(sample(.8).phase,'Formation');assert.ok(sample(.8).body>0&&sample(.8).body<1);
for(const t of [1.5,2,3.5,4.8]){assert.equal(sample(t).phase,'Sustain');assert.equal(sample(t).body,1);assert.equal(sample(t).boundary,1);assert.equal(sample(t).sigil,0);}
assert.equal(sample(5.5).phase,'Dissipation');assert.ok(sample(5.5).body>0&&sample(5.5).body<1);
for(const t of [6.2,6.9]){const p=sample(t);assert.equal(p.phase,'Clear');assert.equal(p.body+p.boundary+p.sigil,0);}
for(const t of [0,1,3.9]){const p=sample(t,'sustain');assert.equal(p.body,1);assert.equal(p.boundary,1);assert.equal(p.sigil,0);assert.equal(p.motionTime,t);}
assert.equal(sample(2,'full',2).body,1);assert.equal(sample(2.8,'full',2).body+sample(2.8,'full',2).boundary,0);
assert.deepEqual(sample(3),sample(3));
console.log('Soul phase checks pass: formation, approved sustain, clear end, early cancellation and deterministic replay.');
