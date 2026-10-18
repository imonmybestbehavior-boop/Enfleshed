"""Phase 1.2: analytics events are emitted at the right gameplay points and never trusted for gameplay."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


class TelemetryWiring(unittest.TestCase):
    def test_every_onboarding_step_is_emitted(self):
        spec = read("src/shared/Modules/TelemetrySpec.luau")
        steps = re.findall(r'^\t"(\w+)",$', spec[spec.index("Spec.Onboarding = {"):spec.index("}")], re.MULTILINE)
        server = "".join(p.read_text() for p in (ROOT / "src/server").rglob("*.luau"))
        for step in steps:
            if step == "CastSpell":
                self.assertIn('Telemetry.onboarding(player, "CastSpell")', read("src/server/Services/TelemetryService.luau"))
            elif step == "Joined":
                self.assertIn('Telemetry.onboarding(player, "Joined")', server)
            else:
                self.assertIn(f'Telemetry.onboarding(player, "{step}")', server, step)

    def test_all_analytics_calls_are_guarded(self):
        telemetry = read("src/server/Services/TelemetryService.luau")
        calls = [m.start() for m in re.finditer(r"AnalyticsService:\w+\(", telemetry)]
        self.assertGreaterEqual(len(calls), 6)
        for index in calls:
            before = telemetry[:index]
            # The nearest enclosing block opener must be safe(), not a closed one.
            self.assertGreater(before.rfind("safe(function()"), before.rfind("\tend)\n"), "AnalyticsService call outside safe()")
        for path in (ROOT / "src").rglob("*.luau"):
            if path.name != "TelemetryService.luau":
                self.assertNotIn("AnalyticsService", path.read_text(), f"{path.name} must go through TelemetryService")

    def test_mission_and_economy_events(self):
        mission = read("src/server/Services/ModeRunner.luau")
        self.assertIn("Telemetry.missionStart(participant, definition.Id, tier)", mission)
        self.assertIn('reportEnd(player, reward, saved, ok, if victory then "Victory" else "Defeat")', mission)
        self.assertIn('reportEnd(player, reward, saved, ok, "Interrupted")', mission)
        self.assertIn('Telemetry.economy(player, "Source", "Marks"', mission)
        lab = read("src/server/Services/MagicLabService.luau")
        self.assertIn('"Sink",\n\t\t\t\t\t"Marks"', lab)
        self.assertIn("Telemetry.spellCast(player, definition)", read("src/server/Services/MagicService.luau"))


if __name__ == "__main__":
    unittest.main()
