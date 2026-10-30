"""Check static Shared lookups against the built place; does not run Roblox."""
import os
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def _place_file():
    """Use ENFLESHED_PLACE_FILE, else build src into a temporary place with Rojo."""
    configured = os.environ.get("ENFLESHED_PLACE_FILE")
    if configured:
        return Path(configured)
    import atexit, shutil, subprocess, tempfile
    rojo = shutil.which("rojo") or str(Path.home() / ".rokit/bin/rojo")
    directory = tempfile.mkdtemp(prefix="enfleshed-place-")
    atexit.register(shutil.rmtree, directory, True)
    place = Path(directory) / "check.rbxlx"
    subprocess.run([rojo, "build", "default.project.json", "-o", str(place)], cwd=ROOT, check=True, capture_output=True)
    return place


PLACE_FILE = _place_file()
CHAIN = re.compile(r'Shared((?::WaitForChild\("[^"]+"\))+)')
NAME = re.compile(r':WaitForChild\("([^"]+)"\)')


def child(node, name):
    for item in node.findall('Item'):
        if item.findtext("Properties/string[@name='Name']") == name:
            return item
    raise AssertionError(f'Missing built instance: {name!r}')


class PlaceReferences(unittest.TestCase):
    def test_grimoire_transport_is_serialized_in_place(self):
        tree = ET.parse(PLACE_FILE).getroot()
        shared = child(child(tree, 'ReplicatedStorage'), 'Shared')
        remotes = child(shared, 'SandboxRemotes')
        required = {
            'ActionRequest', 'ActionFeedback', 'AerialControl',
            'MagicLabRequest', 'MagicLabResponse', 'GrimoireResponse',
            'TrainingDummyRequest', 'TrainingDummyResponse',
            'MagicPresentation', 'SpellVFX',
        }
        present = {
            item.findtext("Properties/string[@name='Name']")
            for item in remotes.findall('Item')
            if item.attrib.get('class') == 'RemoteEvent'
        }
        self.assertTrue(required.issubset(present), f'Missing serialized remotes: {sorted(required - present)}')

    def test_spell_vfx_controller_uses_built_shared_path(self):
        tree = ET.parse(PLACE_FILE).getroot()
        shared = child(child(tree, 'ReplicatedStorage'), 'Shared')
        child(shared, 'SpellVFXSystem')
        client = child(child(child(tree, 'StarterPlayer'), 'StarterPlayerScripts'), 'Client')
        controller = child(child(client, 'Controllers'), 'SpellVFXController')
        source = controller.findtext("Properties/*[@name='Source']") or ''
        self.assertIn('local Shared = ReplicatedStorage:WaitForChild("Shared")', source)
        self.assertIn('local System = Shared:WaitForChild("SpellVFXSystem")', source)

    def test_shared_module_lookups(self):
        tree = ET.parse(PLACE_FILE).getroot()
        shared = child(child(tree, 'ReplicatedStorage'), 'Shared')
        checked = 0
        for source in (ROOT / 'src').rglob('*.luau'):
            for match in CHAIN.finditer(source.read_text(encoding="utf-8")):
                with self.subTest(file=str(source.relative_to(ROOT)), lookup=match[0]):
                    node = shared
                    for name in NAME.findall(match[1]):
                        node = child(node, name)
                    self.assertIn(node.attrib['class'], {'ModuleScript', 'Folder'})
                    checked += 1
        self.assertGreater(checked, 0, 'No Shared module lookups checked')

    def test_relative_module_lookups(self):
        tree = ET.parse(PLACE_FILE).getroot()
        parents = {item: parent for parent in tree.iter() for item in parent}
        checked = 0
        for script in tree.iter('Item'):
            source = script.findtext("Properties/*[@name='Source']") or ''
            for reference in re.findall(r'require\((script(?:\.[A-Za-z_]\w*)+)\)', source):
                with self.subTest(script=script.findtext("Properties/string[@name='Name']"), reference=reference):
                    node = script
                    for name in reference.split('.')[1:]:
                        node = parents[node] if name == 'Parent' else child(node, name)
                    self.assertEqual(node.attrib['class'], 'ModuleScript')
                    checked += 1
        self.assertGreater(checked, 0, 'No relative module lookups checked')

    def test_built_scripts_match_source(self):
        tree = ET.parse(PLACE_FILE).getroot()
        for source_dir, destination in (
            ('client', ('StarterPlayer', 'StarterPlayerScripts', 'Client')),
            ('server', ('ServerScriptService', 'Server')),
            ('shared', ('ReplicatedStorage', 'Shared')),
        ):
            for source in (ROOT / 'src' / source_dir).rglob('*.luau'):
                with self.subTest(file=str(source.relative_to(ROOT))):
                    node = tree
                    for name in destination:
                        node = child(node, name)
                    relative = source.relative_to(ROOT / 'src' / source_dir)
                    # init.* is the script of its folder (e.g. Services/DefendTheWallsMap/init.luau).
                    parts = relative.parent.parts if source.name.startswith('init.') else relative.with_suffix('').parts
                    for name in parts:
                        node = child(node, name)
                    self.assertEqual(node.findtext("Properties/*[@name='Source']"), source.read_text(encoding="utf-8"))


if __name__ == '__main__':
    unittest.main()
