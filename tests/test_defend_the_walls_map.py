"""Defend the Walls siege map: built place contains the map kit, and the mode wires
wall levels, guards, the snapshot and the doors-only loss condition.
Geometry (3 spawns, 3 crossing corridors, 3 walls + doors) is checked against the
seeded layout by tests/defend_the_walls_layout_spec.luau."""
import os
import re
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICES = ROOT / "src/server/Services"
MAP_MODULES = ("Kit", "Lighting", "Village", "Corridors", "Walls", "Gate", "Props", "Baileys")


def built_place() -> Path:
    given = os.environ.get("ENFLESHED_PLACE_FILE")
    if given and Path(given).exists():
        return Path(given)
    rojo = Path.home() / ".rokit/bin/rojo"
    out = Path(tempfile.mkdtemp()) / "place.rbxlx"
    subprocess.run([str(rojo) if rojo.exists() else "rojo", "build", str(ROOT / "default.project.json"), "-o", str(out)],
                   check=True, capture_output=True)
    return out


def names(item):
    for child in item.iter("Item"):
        props = child.find("Properties")
        if props is None:
            continue
        for prop in props:
            if prop.get("name") == "Name":
                yield child.get("class"), prop.text


class DefendTheWallsMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.place = ET.parse(built_place()).getroot()
        cls.mode = (SERVICES / "DefendTheWallsService.luau").read_text()
        cls.guards = (SERVICES / "DefendTheWallsGuards.luau").read_text()
        cls.walls = (SERVICES / "DefendTheWallsMap/Walls.luau").read_text()
        cls.gate = (SERVICES / "DefendTheWallsMap/Gate.luau").read_text()
        cls.hud = (ROOT / "src/client/UI/HUD/MissionTracker.luau").read_text()
        cls.config = (ROOT / "src/shared/Configuration/DefendTheWalls.luau").read_text()

    def test_built_place_contains_map_builder_and_layout(self):
        found = set(names(self.place))
        self.assertIn(("ModuleScript", "DefendTheWallsMap"), found)
        for module in MAP_MODULES:
            self.assertIn(("ModuleScript", module), found, f"map module {module} missing from the place")
        self.assertIn(("ModuleScript", "DefendTheWallsLayout"), found)
        self.assertIn(("ModuleScript", "DefendTheWallsGuards"), found)
        self.assertIn(("ModuleScript", "DefendTheWallsAssets"), found)

    def test_lighting_is_future_and_streaming_stays_on(self):
        text = (ROOT / "default.project.json").read_text()
        self.assertIn('"Technology": "Future"', text)
        self.assertIn('"StreamingEnabled": true', text)

    def test_only_the_doors_lose_the_mission(self):
        finishes = re.findall(r"runner\.finish\(false\)", self.mode)
        self.assertTrue(finishes)
        # Every non-debug loss is guarded by the doors Humanoid.
        self.assertIn("if target == gateHealth then", self.mode)
        self.assertIn("return if gateHealth.Health <= 0 then false else nil", self.mode)
        self.assertIn("gateOwner[target] == wallLevel", self.mode)
        breach = self.mode[self.mode.index("local function breachWall"):self.mode.index("local function activeCount")]
        self.assertNotIn("finish", breach, "a breached wall must never end the mission")
        self.assertIn('SetAttribute("FinalGate", true)', self.gate)
        self.assertIn('"MissionGateway", true', self.gate)

    def test_wall_levels_snapshot_and_hud(self):
        for field in ("WallLevel", "WallCount", "WallHP", "WallMax", "GuardsAlive", "GuardsTotal",
                      "Gateway", "GatewayMax"):
            self.assertIn(f"message.{field} =", self.mode)
        self.assertIn('"WALL %d / %d"', self.hud)
        self.assertIn("message.WallHP", self.hud)
        self.assertIn("Integrity = {", self.config)
        self.assertIn('SetAttribute("DefenderSpawn"', self.mode)
        self.assertIn('GetAttribute("DefenderSpawn")', (ROOT / "src/server/Networking/ActionRouter.luau").read_text())
        # Repairs only work on the active wall or doors.
        self.assertIn("index ~= wallLevel", self.mode)

    def test_gates_are_solid_and_hittable(self):
        # Closed gates block everyone (no collision-group exemptions); players get back over by the postern prompt.
        self.assertNotIn("CollisionGroup", self.walls)
        self.assertIn('"Climb back over"', self.walls)
        self.assertIn("leaf.CanCollide = not breached", self.walls)
        # Enemy melee only hits players and CityHuman targets, so the active wall's gates carry the tag.
        self.assertIn('CollectionService:AddTag(gate, "CityHuman")', self.mode)
        self.assertIn('CollectionService:RemoveTag(gate, "CityHuman")', self.mode)
        enemy = (SERVICES / "EnemyService.luau").read_text()
        self.assertIn('Collection:HasTag(character, "CityHuman")', enemy)
        # Wall runs overlap the side blockers so nothing squeezes round the ends.
        self.assertIn("-wall.HalfWidth - 6", self.walls)

    def test_guards_are_allies_on_shared_systems_and_capped(self):
        for needle in ('"MagicAllyTarget"', '"CityHuman"', 'SetAttribute("SandboxAlignment", "Human")',
                       "Damage.apply(guard.Model", "Config.Guards.MaxTotal"):
            self.assertIn(needle, self.guards)
        self.assertNotIn("PathfindingService", self.guards, "guards must stay off the shared path budget")
        self.assertIn("squad.retreat(from, wallLevel)", self.mode)
        for key in ("PerWall", "MaxTotal", "Spearman", "Crossbowman"):
            self.assertIn(key, self.config)

    def test_world_labels_never_stack(self):
        kit = (SERVICES / "DefendTheWallsMap/Kit.luau").read_text()
        self.assertIn("sign.AlwaysOnTop, sign.MaxDistance", kit)
        self.assertIn("false, maxDistance", kit)
        for path in (SERVICES / "DefendTheWallsMap").glob("*.luau"):
            self.assertNotIn("AlwaysOnTop = true", path.read_text())

    def test_stuck_removal_targets_current_objective(self):
        self.assertIn("Config.StuckTimeout", self.mode)
        self.assertIn("entry.Order.Value", self.mode)


if __name__ == "__main__":
    unittest.main()
