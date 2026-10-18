"""Regression checks for cleanup paths that require the Roblox engine."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MagicLifecycleWiring(unittest.TestCase):
    def test_transform_baseline_is_restored_when_live_model_leaves_workspace(self):
        source = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
        restore = source[
            source.index("local function restoreTransform(") : source.index("\nlocal function getState(")
        ]
        remove = source[
            source.index("local function removeState(") : source.index("\nlocal function refreshAttributes(")
        ]

        self.assertIn("model.Parent ~= nil", restore)
        self.assertIn("model:ScaleTo(scale)", restore)
        self.assertNotIn("model:IsDescendantOf(workspace)", restore)
        self.assertIn("restoreTransform(state)", remove)


if __name__ == "__main__":
    unittest.main()
