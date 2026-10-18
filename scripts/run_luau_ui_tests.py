"""Run read-only layout geometry tests with the official Luau CLI."""
from pathlib import Path
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
library_source = (root / 'src/client/UI/GrimoireLibraryLayout.luau').read_text()
library_test = (root / 'tests/grimoire_library_layout_spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='enfleshed-ui-') as directory:
    path = Path(directory) / 'layout.luau'
    prefix = 'local __GRIMOIRE_LIBRARY_LAYOUT_SOURCE = [====[' + library_source + ']====]\n'
    path.write_text(prefix + library_test)
    raise SystemExit(subprocess.run([sys.argv[1], str(path)], cwd=root).returncode)
