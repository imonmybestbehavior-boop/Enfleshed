"""Integration records must bind uploaded bytes and durable mesh templates correctly."""
import hashlib
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/vfx/studies/style_unification_v1'


class BakedInstall(unittest.TestCase):
    def test_receipts_bind_all_approved_bytes(self):
        entries=json.loads((OUT/'baked/manifest.json').read_text())['entries']
        uploaded=json.loads((OUT/'baked/studio_uploads/uploaded.json').read_text())
        runtime=(ROOT/'src/shared/SpellVFXSystem/Assets/StyledVFXManifest.luau').read_text()
        self.assertEqual(len(uploaded),91)
        for entry in entries:
            row=uploaded[entry['file']]
            self.assertEqual(row['sha256'],entry['sha256'])
            self.assertEqual(hashlib.sha256((OUT/'baked'/entry['file']).read_bytes()).hexdigest(),row['sha256'])
            self.assertIn(f'["{entry["identity"]}/{entry["name"]}"] = "{row["id"]}"',runtime)
            self.assertFalse(json.loads((OUT/'baked/studio_uploads'/row['receipt']).read_text()).get('isError'))

    def test_mesh_prefab_matches_actual_import(self):
        receipt=json.loads((OUT/'studio_mesh_import.json').read_text())
        imported={m['Name']:m for m in json.loads(receipt['content'][0]['text'])}
        xml=ET.parse(ROOT/'src/shared/SpellVFXSystem/Assets/CelMeshLibrary.rbxmx')
        meshes=xml.findall('.//Item[@class="MeshPart"]')
        self.assertEqual(len(meshes),60)
        for mesh in meshes:
            props=mesh.find('Properties')
            name=props.find('string[@name="Name"]').text
            row=imported[name]
            self.assertEqual(props.find('Content[@name="MeshId"]/url').text,row['MeshId'])
            for axis,value in zip('XYZ',row['Size']):
                self.assertAlmostEqual(float(props.find(f'Vector3[@name="size"]/{axis}').text),value/100)
                self.assertAlmostEqual(float(props.find(f'Vector3[@name="MeshSize"]/{axis}').text),value)

    def test_approved_connected_fire_source_unchanged(self):
        receipt=json.loads((OUT/'studio_before.json').read_text())
        before=json.loads(receipt['content'][0]['text'])['Sources']['Signature/ConnectedFire']
        self.assertEqual((ROOT/'src/shared/SpellVFXSystem/Signature/ConnectedFire.luau').read_text(encoding='utf-8'),before)


if __name__=='__main__':unittest.main()
