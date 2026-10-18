"""Phase 1.5: PvP stat caps are applied to every payload and every damage hit."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


class StatCapsWiring(unittest.TestCase):
    def test_payloads_are_capped_per_target_profile(self):
        executors = read("src/server/Services/MagicPayloadExecutors.luau")
        execute = executors[executors.index("function Payloads.execute("):]
        self.assertIn("StatCaps.profileName(casterOwner, owner)", execute)
        self.assertIn("executor(StatCaps.payload(payload, CapProfiles[profile], context.Potency), groupContext)", execute)
        self.assertIn("not hostile or CombatPolicy.allows(casterOwner, owner)", execute)

    def test_every_damage_hit_is_capped(self):
        damage = read("src/server/Services/DamageService.luau")
        cap = damage.index("incoming = StatCaps.damage(incoming, CapProfiles[capProfile])")
        self.assertLess(cap, damage.index("Status.absorb(target, incoming)"))
        self.assertGreater(cap, damage.index("Defense.resolve(attacker, targetModel, incoming, melee)"))

    def test_profiles_exist(self):
        config = read("src/shared/Configuration/SpellStatCaps.luau")
        for name in ("PvE = {}", "PvPOpen = {", "PvPRanked = {"):
            self.assertIn(name, config)


if __name__ == "__main__":
    unittest.main()
