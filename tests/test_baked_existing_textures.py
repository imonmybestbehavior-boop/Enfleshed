"""Verify complete baked atlases, exact source alpha and approved palette membership."""
import hashlib
import json
from pathlib import Path
import unittest
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BAKED=ROOT/'assets/vfx/studies/style_unification_v1/baked'

class BakedExistingTextures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=json.loads((BAKED/'manifest.json').read_text())
        cls.profile=json.loads((BAKED/'style_profile.json').read_text())

    def test_complete_identity_coverage(self):
        catalog=json.loads((BAKED.parent/'catalog.json').read_text())
        expected={(r['name'],identity) for r in catalog['assets'] if r['kind']=='texture' for identity in r['identities']}
        actual=[(e['name'],e['identity']) for e in self.manifest['entries']]
        self.assertEqual(len(actual),len(set(actual)))
        self.assertEqual(set(actual),expected)
        self.assertEqual(len({name for name,_ in actual}),self.manifest['source_textures'])

    def test_source_bytes_alpha_and_atlas_contract(self):
        for e in self.manifest['entries']:
            source=ROOT/e['source'];target=BAKED/e['file']
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),e['source_sha256'],e['file'])
            self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(),e['sha256'],e['file'])
            with Image.open(source) as a,Image.open(target) as b:
                self.assertEqual(b.mode,'RGBA')
                self.assertEqual(a.size,b.size)
                self.assertEqual(b.size,(e['width'],e['height']))
                self.assertEqual(a.convert('RGBA').getchannel('A').tobytes(),b.getchannel('A').tobytes(),e['file'])
            n=int(e['layout'].split('Grid')[1].split('x')[0]) if e['layout'] else 1
            self.assertEqual(e['frames'],n*n)
            self.assertIsNone(e['uploaded_id'])

    def test_flat_palette_and_linework(self):
        for e in self.manifest['entries']:
            if e['soft']:continue
            with Image.open(BAKED/e['file']) as image:data=np.asarray(image)
            palette=np.array(self.profile['palettes'][e['identity']],dtype=np.uint8)
            # Every RGB pixel, even transparent bleed pixels, uses an approved tone.
            allowed=np.zeros(data.shape[:2],dtype=bool)
            for color in palette:allowed|=np.all(data[:,:,:3]==color,axis=2)
            self.assertTrue(np.all(allowed),e['file'])
            if e['line']:self.assertTrue(np.all(data[:,:,:3]==palette[2]),e['file'])

    def test_soft_falloff_not_posterized(self):
        for e in self.manifest['entries']:
            if not e['soft']:continue
            with Image.open(BAKED/e['file']) as image:data=np.asarray(image)
            self.assertGreater(len(np.unique(data[:,:,:3].reshape(-1,3),axis=0)),5,e['file'])

if __name__=='__main__':unittest.main()
