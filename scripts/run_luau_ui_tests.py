"""Run read-only layout geometry tests with the official Luau CLI."""
from pathlib import Path
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'src/client/UI/Grimoire.luau').read_text()
theme = (root / 'src/client/UI/GrimoireTheme.luau').read_text()
test = (root / 'tests/grimoire_layout_spec.luau').read_text()
home_source = (root / 'src/client/UI/GrimoireHomeLayout.luau').read_text()
home_test = (root / 'tests/grimoire_home_layout_spec.luau').read_text()
library_source = (root / 'src/client/UI/GrimoireLibraryLayout.luau').read_text()
library_test = (root / 'tests/grimoire_library_layout_spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='enfleshed-ui-') as directory:
    path = Path(directory) / 'layout.luau'
    prefix = 'local __GRIMOIRE_THEME_SOURCE = [====[' + theme + ']====]\n'
    prefix += 'local __GRIMOIRE_SOURCE = [====[' + source + ']====]\n'
    prefix += 'local __GRIMOIRE_HOME_LAYOUT_SOURCE = [====[' + home_source + ']====]\n'
    prefix += 'local __GRIMOIRE_LIBRARY_LAYOUT_SOURCE = [====[' + library_source + ']====]\n'
    path.write_text(prefix + test + '\n' + home_test + '\n' + library_test)
    raise SystemExit(subprocess.run([sys.argv[1], str(path)], cwd=root).returncode)
