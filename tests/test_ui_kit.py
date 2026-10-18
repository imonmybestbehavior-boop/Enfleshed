"""Phase 1.6: UI kit exists and menus/actions are reachable with a gamepad."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


class UiKit(unittest.TestCase):
    def test_kit_modules(self):
        for name in ("Tokens", "Responsive", "InputMode", "GamepadNav"):
            self.assertTrue((ROOT / f"src/client/UI/Kit/{name}.luau").exists(), name)
        nav = read("src/client/UI/Kit/GamepadNav.luau")
        self.assertIn("root.SelectionGroup = true", nav)
        self.assertIn("Enum.KeyCode.ButtonB", nav)
        self.assertIn('GuiService:GetPropertyChangedSignal("SelectedObject")', nav)
        self.assertIn("gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets", read("src/client/UI/Kit/Responsive.luau"))

    def test_menus_register_with_gamepad_nav(self):
        lab = read("src/client/Controllers/MagicLabController.luau")
        self.assertIn("GamepadNav.open(panel, function()", lab)
        self.assertIn("GamepadNav.close(panel)", lab)
        inventory = read("src/client/UI/InventoryView.luau")
        self.assertIn("GamepadNav.open(panel, function()", inventory)
        self.assertIn("GamepadNav.close(panel)", inventory)

    def test_every_core_action_has_a_gamepad_binding(self):
        client = "".join(p.read_text() for p in (ROOT / "src/client").rglob("*.luau"))
        for key in ("ButtonSelect", "DPadDown", "ButtonR1", "DPadLeft", "DPadRight",  # menus + spells
                    "ButtonR2", "ButtonL2", "ButtonB", "ButtonY", "ButtonL3", "ButtonA"):  # combat + movement
            self.assertIn(f"Enum.KeyCode.{key}", client, key)

    def test_glyphs_cover_prompted_actions(self):
        mode = read("src/client/UI/Kit/InputMode.luau")
        for action in ("Grimoire", "Inventory", "Close", "Confirm", "CastSpell", "NextSpell"):
            self.assertIn(f"{action} = {{ Keyboard =", mode)


if __name__ == "__main__":
    unittest.main()
