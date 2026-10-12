"""Focused source-level integration contracts for the server magic route.

These checks complement pure-data SpellSpec tests. They verify that valid
authoring is wired through server validation, Form dispatch, event dispatch,
the Summon payload callback, and result feedback. Roblox physics and
replication still require Studio acceptance.
"""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def section(source: str, start: str, end: str) -> str:
    start_at = source.index(start)
    end_at = source.index(end, start_at)
    return source[start_at:end_at]


class MagicRuntimeRoutes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.magic = read("src/server/Services/MagicService.luau")
        cls.schema = read("src/shared/Configuration/MagicSchema.luau")
        cls.payloads = read("src/server/Services/MagicPayloadExecutors.luau")
        cls.summons = read("src/server/Services/SummonService.luau")

    def test_server_cast_validates_before_form_execution(self):
        cast = section(self.magic, "local function castNow(", "local function queueCast(")
        self.assertLess(cast.index("validate(player"), cast.index("execute("))
        self.assertIn('if result == "IMPOSSIBLE" or not direction then', cast)

        execution = section(self.magic, "local function execute(", "local function castNow(")
        self.assertIn("Forms.execute(definition.Form, definition, formContext)", execution)

    def test_projectile_oncast_is_distinct_from_collision_onimpact(self):
        projectile = section(
            self.magic,
            "formContext.CreateProjectile = function(d)",
            "\n\tForms.execute(definition.Form",
        )
        self.assertIn('emit(d, "OnCast", state.Character, start', projectile)
        self.assertIn('emit(d, "OnSpawn", state.Character, start', projectile)
        self.assertLess(projectile.index('emit(d, "OnCast"'), projectile.index("registerActiveEffect(projectile)"))

        impact = re.search(
            r'if hit then\s+Presentation\.impact\(hit\.Position.*?emit\(\s*d,\s*"OnImpact"',
            self.magic,
            re.DOTALL,
        )
        self.assertIsNotNone(impact, "Projectile OnImpact must be emitted only inside its server-hit branch")

    def test_object_target_allows_target_independent_summon_payload(self):
        summon_schema = section(self.schema, "\tSummon = {", "\n\t},\n}")
        self.assertIn("TargetIndependent = true", summon_schema)
        event_filter = section(self.schema, "function Schema.eventsForEffects(", "\nfunction Schema.")
        self.assertIn("payload.TargetIndependent == true", event_filter)

        context = section(self.magic, "local function context(", "\n\treturn ctx\nend")
        self.assertIn("runtimeState.AllowObjectTarget", context)
        self.assertIn("runtimeState.UsePreviousTargetSet", context)

    def test_summon_trigger_reaches_server_service_and_reports_outcome(self):
        trigger = section(self.magic, "Summon = function(payload)", "\n\t\tend,")
        self.assertIn("Summons.apply(", trigger)
        self.assertIn("resolvedPotency", trigger)
        self.assertIn("position", trigger)
        self.assertIn('if message or not created then', trigger)
        self.assertIn('if created then "SUMMONED" else "IMPOSSIBLE"', trigger)
        self.assertIn("No new summon was created", trigger)

        summon_payload = section(self.payloads, "Summon = function(payload: any, context: any)", "\n\tend,")
        self.assertIn("context.Summon(payload)", summon_payload)
        self.assertIn("function Summons.apply(", self.summons)

    def test_summon_models_have_authoritative_cleanup_routes(self):
        cleanup = section(self.summons, "function Summons.clearSpell(", "\nfunction Summons.clearDismissal(")
        owner_cleanup = section(self.summons, "function Summons.clearOwner(", "\nreturn Summons")
        self.assertIn("removeGroupAt(index)", cleanup)
        self.assertIn("removeGroupAt(index)", owner_cleanup)
        self.assertIn("record.DeathConnection", self.summons)
        self.assertIn("record.ModelAncestryConnection", self.summons)


if __name__ == "__main__":
    unittest.main()
