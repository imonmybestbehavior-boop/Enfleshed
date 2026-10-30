"""Restyle invariants: source bytes, all geometry, UVs, oriented triangles and atlas contracts."""
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import unittest

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/vfx/studies/style_unification_v1'
spec=importlib.util.spec_from_file_location('restyle',ROOT/'tools/vfx_pipeline/restyle_existing_assets.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)


def same_content(path, digest):
    """True when `path` matches `digest` as recorded from an LF or a CRLF checkout."""
    data = path.read_bytes()
    lf = data.replace(b'\r\n', b'\n')
    return digest in {hashlib.sha256(form).hexdigest() for form in (data, lf, lf.replace(b'\n', b'\r\n'))}

class ExistingRestyle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.catalog=json.loads((OUT/'catalog.json').read_text())

    def test_original_art_and_recipes_preserved(self):
        for name,digest in self.catalog['source_sha256'].items():
            # Post-approval integration changes the renderer and Lightning beam recipe.
            # The catalog retains historical hashes; source artwork stays immutable.
            if name.endswith(('/SignatureRenderer.luau','/SignatureKits.luau')):continue
            self.assertTrue(same_content(ROOT/name,digest),name)

    def test_all_existing_assets_covered(self):
        for kind,folder in [('mesh','meshes'),('texture','textures')]:
            original=json.loads((ROOT/f'assets/vfx/{folder}/{folder}.json').read_text())
            rows=[r for r in self.catalog['assets'] if r['kind']==kind]
            self.assertEqual({r['name'] for r in rows},set(original))
            for row in rows:
                if kind=='texture':
                    for key in ['width','height','layout','tiles']:self.assertEqual(row[key],original[row['name']][key])

    def test_mesh_material_variants_preserve_geometry(self):
        for row in self.catalog['assets']:
            if row['kind']!='mesh':continue
            source_doc,source_bin=module.read_glb(OUT/row['source'])
            revised,revised_bin=module.read_glb(OUT/row['variant'])
            self.assertEqual(revised_bin[:len(source_bin)],source_bin,row['name'])
            original_triangles=Counter();revised_triangles=Counter()
            for doc,binary,counter in [(source_doc,source_bin,original_triangles),(revised,revised_bin,revised_triangles)]:
                for mesh in doc['meshes']:
                    for primitive in mesh['primitives']:
                        indices=[v[0] for v in module.accessor(doc,binary,primitive['indices'])]
                        counter.update(tuple(indices[i:i+3]) for i in range(0,len(indices),3))
                        if doc is revised:
                            old=source_doc['meshes'][0]['primitives'][0]['attributes']
                            for attr in ['POSITION','NORMAL','TEXCOORD_0']:
                                self.assertEqual(primitive['attributes'][attr],old[attr],f'{row["name"]}:{attr}')
                            self.assertLess(primitive['material'],5)
            self.assertEqual(original_triangles,revised_triangles,row['name'])
            self.assertEqual(sum(original_triangles.values()),row['triangles'],row['name'])
            self.assertTrue(all('KHR_materials_unlit' in m['extensions'] for m in revised['materials']))

    def test_style_is_palette_and_material_only(self):
        profile=self.catalog['profile']
        self.assertEqual(set(profile['palettes']),set(self.catalog['kits']))
        for palette in profile['palettes'].values():
            self.assertEqual(len(palette),5)
            self.assertTrue(all(len(c)==3 and all(0<=v<=255 for v in c) for c in palette))
        self.assertEqual(profile['review_runtime']['Material'],'SmoothPlastic')
        self.assertEqual(set(profile['soft_assets']),{'glow_soft','heat_haze'})

if __name__=='__main__':unittest.main()
