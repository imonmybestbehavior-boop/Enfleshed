from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = (
    "src/server/Services/MagicService.luau",
    "src/server/Services/MagicFormExecutors.luau",
    "src/server/Services/MagicPayloadExecutors.luau",
    "src/server/Services/MagicProjectileBehaviorExecutors.luau",
    "src/server/Services/MagicTriggerExecutors.luau",
)
PROOF_SPELL_NAMES = (
    "Fireball",
    "BodyBurst",
    "StoneShot",
    "RecruitMagicBolt",
    "RecruitMagicDischarge",
    "LightningLance",
    "BurningGround",
    "BodyReinforcement",
    "StoneRaise",
)


class MagicDispatchArchitecture(unittest.TestCase):
    def test_runtime_does_not_branch_on_spell_identity(self):
        for relative_path in RUNTIME_FILES:
            source = (ROOT / relative_path).read_text(encoding="utf-8")
            with self.subTest(file=relative_path):
                self.assertIsNone(
                    re.search(r"\b(?:SpellId|spellId)\s*(?:==|~=)\s*['\"]", source),
                    "Spell IDs may identify cooldown/lifecycle records, but must not select gameplay behavior",
                )
                for spell_name in PROOF_SPELL_NAMES:
                    self.assertNotIn(
                        spell_name,
                        source,
                        f"Proof spell {spell_name} must remain data, not runtime-specific code",
                    )


if __name__ == "__main__":
    unittest.main()
