"""Phase 1.7: modules extracted from the large files stay stateless and wired."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXTRACTED = {
    "src/server/Services/MagicWorldQuery.luau": ("src/server/Services/MagicService.luau", "require(script.Parent.MagicWorldQuery)"),
    "src/server/Services/MagicConstructBuilder.luau": ("src/server/Services/MagicService.luau", "require(script.Parent.MagicConstructBuilder)"),
    "src/client/Controllers/GrimoireGeometryPreview.luau": ("src/client/Controllers/MagicLabController.luau", "require(script.Parent.GrimoireGeometryPreview)"),
    "src/client/Controllers/GrimoireConditionTreeEditor.luau": ("src/client/Controllers/MagicLabController.luau", "require(script.Parent.GrimoireConditionTreeEditor)"),
    "src/client/UI/ForgePreviewPanel.luau": ("src/client/UI/GuidedSpellForge.luau", "require(script.Parent.ForgePreviewPanel)"),
}


class ModuleBoundaries(unittest.TestCase):
    def test_extracted_modules_are_required_by_their_owner(self):
        for module, (owner, require) in EXTRACTED.items():
            self.assertTrue((ROOT / module).exists(), module)
            self.assertIn(require, (ROOT / owner).read_text(encoding="utf-8"), owner)

    def test_extracted_modules_do_not_depend_back_on_their_owner(self):
        for module, (owner, _) in EXTRACTED.items():
            source = (ROOT / module).read_text(encoding="utf-8")
            owner_name = Path(owner).stem
            self.assertNotIn(f"script.Parent.{owner_name})", source, f"{module} must not require {owner_name}")
            self.assertTrue(source.startswith("--!strict"), module)


if __name__ == "__main__":
    unittest.main()
