"""Run every standalone tests/test_*.lua file with the official Luau CLI.

Usage: python scripts/run_luau_unit_tests.py /path/to/luau [name-filter]
Like run_luau_magic_tests.py, each test gets a source snapshot behind a Lua
`loadfile` shim, so the tests run unchanged without a plain Lua install.
test_magic_lab.lua and test_grimoire_library.lua are run by run_luau_magic_tests.py.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SKIP = {"test_magic_lab.lua", "test_grimoire_library.lua"}

sources = ["local sources = {}"]
for path in sorted((ROOT / "src").rglob("*.luau")):
    sources.append(f"sources[{str(path.relative_to(ROOT))!r}] = [====[{path.read_text()}]====]")
prelude = "\n".join(sources) + '''
local base = getfenv()
base.loadfile = function(path, mode, environment)
    local content = sources[path]
    if not content then return nil, "Missing fixture " .. path end
    local fn, err = loadstring(content, path)
    if fn and environment then setfenv(fn, environment) end
    return fn, err
end
-- Lua 5.2-style load(chunk, name, mode, env).
base.load = function(chunk, name, mode, environment)
    local fn, err = loadstring(chunk, name)
    if fn and environment then setfenv(fn, environment) end
    return fn, err
end
base.dofile = function(path)
    return assert(base.loadfile(path))()
end
-- Read-only `io.open` over the snapshot, for tests that slice production source.
base.io = {
    open = function(path)
        local content = sources[path]
        if not content then return nil, "Missing fixture " .. path end
        return { read = function() return content end, close = function() end }
    end,
}
-- Luau's `table` library is frozen; tests may polyfill members on their own copy.
base.table = setmetatable({}, { __index = table })
'''

name_filter = sys.argv[2] if len(sys.argv) > 2 else ""
failed = []
tests = [p for p in sorted((ROOT / "tests").glob("test_*.lua")) if p.name not in SKIP and name_filter in p.name]
with tempfile.TemporaryDirectory(prefix="enfleshed-unit-") as directory:
    for test in tests:
        harness = Path(directory) / "harness.luau"
        harness.write_text(
            prelude
            + "local test = assert(loadstring([====[" + test.read_text() + "]====], " + repr(test.name) + "))\n"
            + "setfenv(test, base)\ntest()\n"
        )
        result = subprocess.run([sys.argv[1], str(harness)], cwd=ROOT, capture_output=True, text=True)
        if result.returncode != 0:
            failed.append(test.name)
            print(f"FAIL {test.name}\n{(result.stdout + result.stderr).strip()[-600:]}\n")
print(f"{len(tests) - len(failed)}/{len(tests)} standalone Luau unit tests passed")
raise SystemExit(1 if failed else 0)
