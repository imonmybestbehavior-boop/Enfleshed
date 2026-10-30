"""Shipping skin/UV frames must retain the verified import and actual upload identities."""
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/"src/shared/SpellVFXSystem/Assets"

def item_name(item):
    return item.findtext('./Properties/string[@name="Name"]')

class ConnectedFireAssets(unittest.TestCase):
    def setUp(self):
        self.tree=ET.parse(ASSETS/"ConnectedFireRig.rbxmx").getroot()
        self.items=list(self.tree.iter("Item"))

    def test_skin_identity_and_bones(self):
        meshes=[i for i in self.items if i.get("class")=="MeshPart"]
        self.assertEqual(len(meshes),1)
        self.assertEqual(meshes[0].findtext('./Properties/Content[@name="MeshId"]/url'),"rbxassetid://135760105803974")
        self.assertEqual(meshes[0].findtext('./Properties/bool[@name="HasSkinnedMesh"]'),"true")
        bones={item_name(i) for i in self.items if i.get("class")=="Bone"}
        poses=json.loads((ROOT/"assets/vfx/studies/3d_fire_v4/pose_probe.json").read_text())
        self.assertEqual(bones,set(poses["names"])|{"Root"})
        self.assertFalse(any(i.get("class") in {"Part","Script","LocalScript"} for i in self.items))

    def test_alpha_frames_match_recorded_uploads(self):
        surfaces={item_name(i):i for i in self.items if i.get("class")=="SurfaceAppearance"}
        uploads=json.loads((ROOT/"assets/vfx/studies/3d_fire_v4/published_assets.json").read_text())["assets"]
        self.assertEqual(len(surfaces),24)
        for entry in uploads:
            surface=surfaces[f'Frame_{entry["frame"]:03d}']
            self.assertEqual(surface.findtext('./Properties/Content[@name="ColorMap"]/url'),entry["id"])
            self.assertEqual(surface.findtext('./Properties/token[@name="AlphaMode"]'),"1")

    def test_serialized_mesh_data_is_self_contained(self):
        references=[i.get("referent") for i in self.items]
        self.assertEqual(len(references),len(set(references)))
        needed={p.text for p in self.tree.iter("SharedString") if p.get("name") and p.text}
        included={p.get("md5") for p in self.tree.findall("./SharedStrings/SharedString")}
        self.assertTrue(needed<=included)

if __name__=="__main__": unittest.main()
