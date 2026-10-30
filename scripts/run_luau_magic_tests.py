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
    parts.append(f"sources[{path.relative_to(ROOT).as_posix()!r}] = [====[{path.read_text(encoding="utf-8")}]====]")
test = (ROOT / "tests/test_magic_lab.lua").read_text(encoding="utf-8")
if "--library-only" in sys.argv:
    test = (ROOT / "tests/test_grimoire_library.lua").read_text(encoding="utf-8")
if "--workflow-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/grimoire_flow_spec.luau").read_text(encoding="utf-8")
if "--starters-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/grimoire_starters_spec.luau").read_text(encoding="utf-8")
if "--visual-plan-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_visual_plan_spec.luau").read_text(encoding="utf-8")
if "--composer-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_vfx_composer_lifecycle_spec.luau").read_text(encoding="utf-8")
if "--vfx-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_vfx_composition_spec.luau").read_text(encoding="utf-8")
if "--forge-only" in sys.argv:
    marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
    test = test[:test.index(marker) + len(marker)] + "\n" + (ROOT / "tests/spell_forge_spec.luau").read_text(encoding="utf-8")
    parts.append("getfenv().__UI_SOURCES = {}")
    for ui in sorted((ROOT / "src/client/UI").glob("*.luau")):
        parts.append(f"getfenv().__UI_SOURCES[{ui.stem!r}] = [====[" + ui.read_text(encoding="utf-8") + "]====]")
if "--action-flow-only" in sys.argv:
    test = (ROOT / "tests/magic_action_flow_spec.luau").read_text(encoding="utf-8")
service = (ROOT / "src/server/Services/MagicLabService.luau").read_text(encoding="utf-8")
codec = service[service.index("local function validateStored"):service.index("local function makePublic")]
parts.append("local codec = [====[" + codec + "]====]")
library_action = service[service.index('if action == "Library" then'):service.index('local slotIdValue = slotId(slot)')]
apply_action = service[service.index('if action == "Apply" then') + len('if action == "Apply" then'):service.index('elseif action == "Cast" then')]
parts.append("getfenv().__LIBRARY_ACTION_SOURCE = [====[" + library_action + "]====]")
parts.append("getfenv().__APPLY_ACTION_SOURCE = [====[" + apply_action + "]====]")
parts.append(
    "getfenv().__MAGIC_ACTION_FLOW_SOURCE = [====["
    + (ROOT / "src/shared/Modules/MagicActionFlow.luau").read_text(encoding="utf-8")
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
    harness.write_text("\n".join(parts), encoding="utf-8")
    raise SystemExit(subprocess.run([sys.argv[1], str(harness)], cwd=ROOT).returncode)
