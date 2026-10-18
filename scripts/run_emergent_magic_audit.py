"""Run the emergent-magic audit suite (tests/emergent_magic_audit_spec.luau).

Usage: python3 scripts/run_emergent_magic_audit.py /path/to/luau [spec.luau]
Reuses the SpellSpec/schema fixture preamble from tests/test_magic_lab.lua and
additionally exposes src/server sources through loadfile so the real dispatch,
behavior and payload executors can be loaded with mocked Roblox services.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec_path = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "tests/emergent_magic_audit_spec.luau"
parts = ["local sources = {}"]
for folder in ("src/shared", "src/server"):
    for path in sorted((ROOT / folder).rglob("*.luau")):
        parts.append(f"sources[{str(path.relative_to(ROOT))!r}] = [====[{path.read_text()}]====]")
test = (ROOT / "tests/test_magic_lab.lua").read_text()
marker = 'local spec = load("src/shared/Modules/SpellSpec.luau")'
test = test[: test.index(marker) + len(marker)] + "\n" + spec_path.read_text()
parts.append('''local base = getfenv()
base.loadfile = function(path, mode, environment)
    local content = sources[path]
    if not content then return nil, "Missing fixture " .. path end
    local fn, err = loadstring(content, path)
    if fn and environment then setfenv(fn, environment) end
    return fn, err
end
local test = assert(loadstring([====[''' + test + ''']====], "emergent_magic_audit"))
setfenv(test, base)
test()
''')
with tempfile.TemporaryDirectory(prefix="enfleshed-audit-") as directory:
    harness = Path(directory) / "harness.luau"
    harness.write_text("\n".join(parts))
    raise SystemExit(subprocess.run([sys.argv[1], str(harness)], cwd=ROOT).returncode)
