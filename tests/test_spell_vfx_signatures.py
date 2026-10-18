"""Signature VFX layer: Luau spec + asset pipeline validation + client module syntax.

Usage: python3 tests/test_spell_vfx_signatures.py [path/to/luau]
(defaults to ~/.rokit/bin/luau; the rokit shim needs a cwd containing rokit.toml)
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUAU = os.environ.get("LUAU") or str(Path.home() / ".rokit/bin/luau")
# Modules that only run inside Roblox: compiled (syntax-checked) here, never executed.
CLIENT_ONLY = [
    "src/shared/SpellVFXSystem/Signature/SignatureRenderer.luau",
    "src/shared/SpellVFXSystem/Assets/VFXAssets.luau",
    "src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau",
    "src/client/Controllers/SpellVFXController.luau",
    "src/client/Controllers/SpellVFXShowcase.luau",
]


def run_luau(program):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as handle:
        handle.write(program)
        path = handle.name
    try:
        return subprocess.run([LUAU, path], cwd=ROOT, capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(path)


def long_string(text):
    level = 1
    while "]" + "=" * level + "]" in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[{text}]{eq}]"


class SignatureVFX(unittest.TestCase):
    def test_planner_spec(self):
        parts = ["local sources = {}"]
        for path in sorted((ROOT / "src/shared").rglob("*.luau")):
            parts.append(f"sources[{path.relative_to(ROOT).as_posix()!r}] = {long_string(path.read_text(encoding="utf-8"))}")
        parts.append(
            "env = getfenv()\n"
            "function load(path)\n"
            "  local fn = assert(loadstring(assert(sources[path], 'missing ' .. path), path))\n"
            "  setfenv(fn, env)\n"
            "  return fn()\n"
            "end\n"
        )
        parts.append((ROOT / "tests/spell_vfx_signature_spec.luau").read_text(encoding="utf-8"))
        result = run_luau("\n".join(parts))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Signature VFX:", result.stdout)

    def test_client_modules_compile(self):
        checks = []
        for rel in CLIENT_ONLY:
            text = (ROOT / rel).read_text(encoding="utf-8")
            checks.append(f"do local fn, err = loadstring({long_string(text)}, {rel!r}) assert(fn, err) end")
        checks.append('print("compiled")')
        result = run_luau("\n".join(checks))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_asset_manifest_is_current(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/vfx_pipeline/build_manifest.py")],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
        LUAU = sys.argv.pop(1)
    unittest.main()
