"""Run the engine-independent inventory and item-rule specs with the official Luau CLI.

Usage: python scripts/run_luau_inventory_tests.py /path/to/luau
Shared modules are loaded through a tiny require/script shim with Roblox
datatype stubs, so production source runs unmodified.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULES = {
    "Configuration/Items": "src/shared/Configuration/Items.luau",
    "Configuration/Loot": "src/shared/Configuration/Loot.luau",
    "Configuration/MeleeProfiles": "src/shared/Configuration/MeleeProfiles.luau",
    "Modules/ItemRules": "src/shared/Modules/ItemRules.luau",
    "Modules/InventoryModel": "src/shared/Modules/InventoryModel.luau",
}
parts = ["local sources = {}"]
for name, path in MODULES.items():
    parts.append(f"sources[{name!r}] = [====[{(ROOT / path).read_text()}]====]")
parts.append((ROOT / "tests/inventory_harness.luau").read_text())
parts.append((ROOT / "tests/inventory_model_spec.luau").read_text())
with tempfile.TemporaryDirectory(prefix="enfleshed-inventory-") as directory:
    harness = Path(directory) / "harness.luau"
    harness.write_text("\n".join(parts))
    raise SystemExit(subprocess.run([sys.argv[1], str(harness)], cwd=ROOT).returncode)
