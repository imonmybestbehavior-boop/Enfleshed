import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class CombatBattleMapTests(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def test_generator_exposes_required_builders_and_map_organization(self):
        generator = self.read("src/server/Services/MapGenerator.luau")
        for builder in ("BuildTower", "BuildWallSection", "BuildRuinedHouse", "ScatterCover", "DigMoat"):
            self.assertIn(f"function Generator.{builder}", generator)
        for folder in ("Structures", "Cover", "Props", "Spawns", "Landmarks", "Terrain"):
            self.assertIn(f'"{folder}"', generator)
        self.assertIn("Random.new(selectedSeed)", generator)
        self.assertIn('"Landmark_" .. name', generator)
        self.assertIn('"BattleSpawn_" .. index', generator)

    def test_map_replaces_studio_combat_arena_and_uses_outskirts_spawn(self):
        service = self.read("src/server/Services/CombatSandboxService.luau")
        router = self.read("src/server/Networking/ActionRouter.luau")
        dummy = self.read("src/server/Services/TrainingDummyService.luau")
        self.assertIn("MapGenerator.Generate(MapConfig.Seed)", service)
        self.assertIn("CombatBattleMap).Spawn", router)
        self.assertIn("CombatBattleMap).Spawn", dummy)
        self.assertNotIn("OpeningService", router)
        self.assertIn("Enabled = true", self.read("src/shared/Configuration/CombatBattleMap.luau"))


if __name__ == "__main__":
    unittest.main()
