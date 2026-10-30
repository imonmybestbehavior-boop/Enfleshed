"""Meaningful export/coverage invariants for the isolated 3D review gallery."""
import array
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/vfx/studies/effect_families_v1'

class FamilyGallery(unittest.TestCase):
    def test_form_coverage_and_registered_examples(self):
        record=json.loads((OUT/'inventory.json').read_text())
        schema=(ROOT/'src/shared/Configuration/MagicSchema.luau').read_text().split('Schema.Forms = {',1)[1].split('Schema.FormOrder',1)[0]
        forms=re.findall(r'^\t(\w+) = \{',schema,re.M)
        self.assertEqual(set(forms),set(record['form_mapping']))
        mapped=[f for family in record['families'].values() for f in family['forms']]
        self.assertEqual(len(mapped),len(set(mapped)))
        self.assertEqual(set(mapped),set(forms))
        self.assertEqual(len(record['registered_spells']),len(re.findall('SpellId =',(ROOT/'src/shared/Configuration/Spells.luau').read_text())))
        self.assertEqual(record['gallery']['prototype']['principle'],'Soul')
        self.assertEqual(record['gallery']['prototype']['form'],'Field')

    def test_protected_source_unchanged(self):
        for name,digest in json.loads((OUT/'inventory.json').read_text())['source_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),digest,name)
        for asset in json.loads((OUT/'asset_reuse_inventory.json').read_text())['assets']:
            self.assertEqual(hashlib.sha256((ROOT/asset['path']).read_bytes()).hexdigest(),asset['sha256'],asset['name'])

    def test_geometry_caches(self):
        for key in ['fire','soul']:
            meta=json.loads((OUT/f'{key}.mesh.json').read_text())
            self.assertEqual(len(meta['indices'])%3,0)
            self.assertGreaterEqual(min(meta['indices']),0)
            self.assertLess(max(meta['indices']),meta['vertices'])
            data=array.array('f');data.frombytes((OUT/f'{key}.positions.bin').read_bytes())
            self.assertEqual(len(data),meta['vertices']*3*meta['frames'])
            self.assertTrue(all(math.isfinite(v) for v in data))
            n=meta['vertices']*3
            self.assertNotEqual(data[:n],data[n*12:n*13],f'{key} must actually animate')
            if key=='fire':
                for name in meta['textures']: self.assertTrue((OUT/name).is_file(),name)
                self.assertEqual(len(meta['textures']),24)
            else:
                self.assertEqual((OUT/'soul.colors.bin').stat().st_size,len(data)*4)

    def test_soul_loop_and_stationary_boundary(self):
        path=ROOT/'tools/vfx_pipeline/build_soul_gallery.py'
        spec=importlib.util.spec_from_file_location('soul_geometry',path)
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        p0,c0,i0,v0=mod.geometry(0)
        p4,c4,i4,v4=mod.geometry(4)
        self.assertLess(max(abs(a-b) for a,b in zip(p0,p4)),1e-8)
        self.assertLess(max(abs(a-b) for a,b in zip(c0,c4)),1e-8)
        p1,_,_,_=mod.geometry(1.3)
        boundary=12*9*2*3
        self.assertEqual(p0[:boundary],p1[:boundary])
        self.assertEqual(i0,i4)
        self.assertLess(max(abs(a-b) for a,b in zip(v0,v4)),1e-8)
        # Ghost zero keeps its cross-section and face while its whole body fades at height.
        full,_,_,_=mod.geometry(2.4)
        erased,_,_,mask=mod.geometry(3.4)
        base=12*9*2
        a=base+15*(mod.COLS+1)
        b=a+mod.COLS//2
        def diameter(p): return math.dist(p[a*3:a*3+3],p[b*3:b*3+3])
        self.assertAlmostEqual(diameter(full),diameter(erased),places=7)
        self.assertAlmostEqual(diameter(full),diameter(p0),places=7)
        # Birth is full-size below the ground; the crown starts on the floor and rises.
        self.assertLess(p0[(base+15*(mod.COLS+1))*3+1],0)
        self.assertAlmostEqual(p0[(base+mod.ROWS*(mod.COLS+1))*3+1],0,places=7)
        self.assertGreater(full[(base+mod.ROWS*(mod.COLS+1))*3+1],0)
        opacity=mask[base+2*(mod.COLS+1)]
        self.assertGreater(opacity,0)
        self.assertLess(opacity,1)
        self.assertEqual(opacity,mask[base+20*(mod.COLS+1)])
        face=base+(mod.ROWS+1)*(mod.COLS+1)
        self.assertEqual(opacity,mask[face])
        _,_,_,higher=mod.geometry(3.8)
        self.assertLess(higher[base],opacity)
        self.assertEqual((OUT/'soul.visibility.bin').stat().st_size,len(p0)//3*mod.FRAMES*4)

if __name__=='__main__': unittest.main()
