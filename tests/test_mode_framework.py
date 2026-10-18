"""Phase 1.3: modes are thin definitions on ModeRunner; generic round logic lives in one place."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SERVICES = ROOT / "src/server/Services"


class ModeFramework(unittest.TestCase):
    def setUp(self):
        self.runner = (SERVICES / "ModeRunner.luau").read_text()
        self.mode = (SERVICES / "DefendTheWallsService.luau").read_text()

    def test_definition_supplies_every_required_hook(self):
        block = self.runner[self.runner.index("export type ModeDefinition = {"):self.runner.index("export type Runner")]
        required = []
        for line in block.splitlines():
            match = re.match(r"^\t(\w+): (.*?),(?: --.*)?$", line)
            if not match:
                continue
            name, kind = match.groups()
            optional = (kind.startswith("((") and kind.endswith(")?")) or re.fullmatch(r"\w+\?", kind)
            if not optional:
                required.append(name)
        self.assertIn("reward", required)
        self.assertIn("outcome", required)
        self.assertNotIn("activate", required)
        self.assertNotIn("Tier", required)
        for hook in required:
            self.assertRegex(self.mode, rf"\n\t\t{hook} = ", f"DefendTheWalls must define {hook}")

    def test_round_logic_is_not_duplicated_in_the_mode(self):
        for generic in ("Progression.commit", "Telemetry.", "FeatureFlags", "HttpService", "OnServerEvent", "beforeShutdown"):
            self.assertNotIn(generic, self.mode, f"{generic} belongs in ModeRunner")
        self.assertIn("ModeRunner.new(definition(", self.mode)

    def test_runner_preserves_round_rules(self):
        r = self.runner
        self.assertIn("table.find", (SERVICES / "MissionProgression.luau").read_text())  # receipts keep commits idempotent
        self.assertIn("Progression.commit(player.UserId, completedId, reward)", r)
        self.assertIn('if now - (lastRequest[player] or 0) < 0.3 then', r)
        self.assertIn("FeatureFlags.enabled(definition.Id, player)", r)
        self.assertIn('resetToReplay("RunsAbandoned")', r)
        # Outcome (e.g. gate destroyed) is checked before the timer; content ticks last.
        tick = r[r.index("local function tick()"):r.index("local function trackDeaths")]
        self.assertLess(tick.index("definition.outcome(runner, now)"), tick.index("now >= runner.EndAt"))
        self.assertLess(tick.index("now >= runner.EndAt"), tick.index("definition.tick(runner, now)"))

    def test_client_messages_keep_their_shape(self):
        for field in ("Kind = \"MissionState\"", "State = runner.State", "Id = runner.RoundId", "Remaining = remaining",
                      "Kind = \"MissionResult\"", "Victory = victory", "Reward = reward", "Saved = ok"):
            self.assertIn(field, self.runner)
        for field in ("message.Phase", "message.PhaseName", "message.Gateway", "message.GatewayMax", "message.Repairs",
                      "message.Enemies", "message.SpawnBudget"):
            self.assertIn(field, self.mode)


if __name__ == "__main__":
    unittest.main()
