"""Phase 0.6: an active mission still pays participants when the server shuts down."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


class ShutdownRewards(unittest.TestCase):
    def test_profile_hooks_run_before_the_flush(self):
        profiles = read("src/server/Services/PlayerProfileService.luau")
        close = profiles[profiles.index("game:BindToClose(function()"):]
        self.assertLess(close.index("for _, hook in shutdownHooks do"), close.index("Profiles.save(userId, true)"))
        self.assertIn("pcall(hook)", close)

    def test_mission_grants_interrupted_rewards_without_extra_writes(self):
        mission = read("src/server/Services/ModeRunner.luau")
        self.assertIn("Profiles.beforeShutdown(grantInterrupted)", mission)
        grant = mission[mission.index("local function grantInterrupted()"):mission.index("local function tick()")]
        self.assertIn('if runner.State ~= "ACTIVE" then', grant)
        self.assertIn("reward.Interrupted = true", grant)
        # Deferred: the profile flush that follows persists it; the round id keeps it idempotent.
        self.assertIn("Progression.commit(player.UserId, runner.RoundId, reward, true)", grant)
        self.assertIn("Profiles.peek(player.UserId)", grant, "never yield on a still-loading profile at shutdown")

    def test_interrupted_runs_are_not_losses(self):
        progression = read("src/server/Services/MissionProgression.luau")
        self.assertIn("elseif not reward.Interrupted then\n\t\t\trecord.Lost += 1", progression)
        self.assertIn("if deferSave then", progression)
        self.assertIn("table.find(record.Receipts, missionId)", progression)


if __name__ == "__main__":
    unittest.main()
