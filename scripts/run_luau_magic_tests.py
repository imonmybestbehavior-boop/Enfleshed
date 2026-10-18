"""Run the engine-independent Magic Lab suite with the official Luau CLI.

Usage: python scripts/run_luau_magic_tests.py /path/to/luau
The tests use Lua's loadfile API; this runner supplies a filesystem snapshot
through loadstring/setfenv without rewriting production source or test logic.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parts = ["local sources = {}"]
for path in sorted((ROOT / "src/shared").rglob("*.luau")):
    parts.append(f"sources[{str(path.relative_to(ROOT))!r}] = [====[{path.read_text()}]====]")
test = (ROOT / "tests/test_magic_lab.lua").read_text()
if "--library-only" in sys.argv:
    test = (ROOT / "tests/test_grimoire_library.lua").read_text()
if "--workflow-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/grimoire_flow_spec.luau").read_text()
if "--starters-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/grimoire_starters_spec.luau").read_text()
if "--visual-plan-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_visual_plan_spec.luau").read_text()
if "--composer-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_vfx_composer_lifecycle_spec.luau").read_text()
if "--vfx-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_vfx_composition_spec.luau").read_text()
if "--forge-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_forge_spec.luau").read_text()
    parts.append("getfenv().__UI_SOURCES = {}")
    for ui in sorted((ROOT / "src/client/UI").glob("*.luau")):
        parts.append(f"getfenv().__UI_SOURCES[{ui.stem!r}] = [====[" + ui.read_text() + "]====]")
if "--action-flow-only" in sys.argv:
    test = (ROOT / "tests/magic_action_flow_spec.luau").read_text()
service = (ROOT / "src/server/Services/MagicLabService.luau").read_text()
codec = service[service.index("local function validateStored"):service.index("local function makePublic")]
parts.append("local codec = [====[" + codec + "]====]")
library_action = service[service.index('if action == "Library" then'):service.index('local slotIdValue = slotId(slot)')]
apply_action = service[service.index('if action == "Apply" then') + len('if action == "Apply" then'):service.index('elseif action == "Cast" then')]
parts.append("getfenv().__LIBRARY_ACTION_SOURCE = [====[" + library_action + "]====]")
parts.append("getfenv().__APPLY_ACTION_SOURCE = [====[" + apply_action + "]====]")
parts.append(
    "getfenv().__MAGIC_ACTION_FLOW_SOURCE = [====["
    + (ROOT / "src/shared/Modules/MagicActionFlow.luau").read_text()
    + "]====]"
)
parts.append('''local base = getfenv()
base.__CODEC_SOURCE = codec
base.loadfile = function(path, mode, environment)
    local content = sources[path]
    if not content then return nil, "Missing fixture " .. path end
    local fn, err = loadstring(content, path)
    if fn and environment then setfenv(fn, environment) end
    return fn, err
end
local test = assert(loadstring([====[''' + test + ''']====], "test_magic_lab.lua"))
setfenv(test, base)
test()
''')
with tempfile.TemporaryDirectory(prefix="enfleshed-luau-") as directory:
    harness = Path(directory) / "harness.luau"
    harness.write_text("\n".join(parts))
    raise SystemExit(subprocess.run([sys.argv[1], str(harness)], cwd=ROOT).returncode)
