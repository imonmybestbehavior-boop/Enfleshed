"""Phase 1.4: the cost-weighted load budget gates new player casts and is observable."""
from pathlib import Path
import unittest

SERVICE = (Path(__file__).resolve().parents[1] / "src/server/Services/MagicService.luau").read_text()


class MagicLoadWiring(unittest.TestCase):
    def test_new_casts_check_the_load_budget_after_count_caps(self):
        execute = SERVICE[SERVICE.index("local function execute("):]
        count_cap = execute.index('Reason = "Active spell safety limit"')
        load_cap = execute.index("LoadBudget.canAdd(activeLoad(), LoadBudget.weight(definition), serverFrameMs)")
        self.assertLess(count_cap, load_cap)
        self.assertRegex(execute, r"not persistentConstruct\s+and not LoadBudget.canAdd")

    def test_frame_time_and_load_are_published(self):
        self.assertIn("serverFrameMs = LoadBudget.smooth(serverFrameMs, delta)", SERVICE)
        for attribute in ("MagicLoad", "MagicLoadLimit", "ServerFrameMs", "MagicActiveCount"):
            self.assertIn(f'workspace:SetAttribute("{attribute}"', SERVICE)


if __name__ == "__main__":
    unittest.main()
