"""Stat-driven appearance must come from spell data, never from spell names, IDs or randomness."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
VISUAL_FILES = sorted((ROOT / "src/shared/SpellVFXSystem/Visual").glob("*.luau")) + [
    ROOT / "src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau",
    ROOT / "src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau",
]


def code(path):
    """Source with Luau comments removed, so documentation may name what code must not use."""
    return re.sub(r"--[^\n]*", "", path.read_text())


def curated_names():
    source = (ROOT / "src/shared/Modules/GrimoireStarters.luau").read_text()
    return sorted(set(re.findall(r'^\s*Name = "([^"]+)"', source, re.MULTILINE)))


class SpellVisualIdentity(unittest.TestCase):
    def test_no_identity_or_random_inputs(self):
        names = curated_names()
        self.assertGreaterEqual(len(names), 65)
        for path in VISUAL_FILES:
            source = code(path)
            with self.subTest(file=path.name):
                self.assertNotRegex(source, r"\bSpellId\b", "Appearance must not read SpellId")
                self.assertNotRegex(source, r"\bspell\.Name\b|\bd\.Name\b|definition\.Name", "Appearance must not read spell names")
                self.assertNotRegex(source, r"math\.random|Random\.new|tick\(\)", "Variation must be seeded, not random")
                for name in names:
                    self.assertNotIn(f'"{name}"', source, f"Curated spell {name} must not be special-cased")

    def test_no_fabricated_asset_ids(self):
        for path in VISUAL_FILES:
            with self.subTest(file=path.name):
                self.assertNotIn("rbxassetid://", code(path))

    def test_visual_stage_is_pure(self):
        for path in sorted((ROOT / "src/shared/SpellVFXSystem/Visual").glob("*.luau")):
            source = code(path)
            with self.subTest(file=path.name):
                self.assertNotIn("Instance.new", source, "Analysis modules must not create instances")
                self.assertNotIn("SetAttribute", source)
                self.assertNotRegex(source, r"game:GetService|workspace", "Analysis modules must stay engine-independent")


if __name__ == "__main__":
    unittest.main()
