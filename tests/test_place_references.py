"""Check static Shared lookups against the built place; does not run Roblox."""
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAIN = re.compile(r'Shared((?::WaitForChild\("[^"]+"\))+)')
NAME = re.compile(r':WaitForChild\("([^"]+)"\)')


def child(node, name):
    for item in node.findall('Item'):
        if item.findtext("Properties/string[@name='Name']") == name:
            return item
    raise AssertionError(f'Missing built instance: {name!r}')


class PlaceReferences(unittest.TestCase):
    def test_shared_module_lookups(self):
        tree = ET.parse(ROOT / 'Enfleshed.rbxlx').getroot()
        shared = child(child(tree, 'ReplicatedStorage'), 'Shared')
        checked = 0
        for source in (ROOT / 'src').rglob('*.luau'):
            for match in CHAIN.finditer(source.read_text()):
                with self.subTest(file=str(source.relative_to(ROOT)), lookup=match[0]):
                    node = shared
                    for name in NAME.findall(match[1]):
                        node = child(node, name)
                    self.assertEqual(node.attrib['class'], 'ModuleScript')
                    checked += 1
        self.assertGreater(checked, 0, 'No Shared module lookups checked')

    def test_built_scripts_match_source(self):
        tree = ET.parse(ROOT / 'Enfleshed.rbxlx').getroot()
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
                    if not source.name.startswith('init.'):
                        for name in relative.with_suffix('').parts:
                            node = child(node, name)
                    self.assertEqual(node.findtext("Properties/*[@name='Source']"), source.read_text())


if __name__ == '__main__':
    unittest.main()
