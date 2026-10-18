#!/usr/bin/env bash
# Single local/CI gate: formatting, build, and every engine-independent test suite.
# Usage: scripts/check.sh            (tools default to ~/.rokit/bin, else PATH)
# Exit code is non-zero if any step fails; every step still runs so you see all failures.
set -u
cd "$(dirname "$0")/.."
BIN="${ROKIT_BIN:-$HOME/.rokit/bin}"
tool() { if [ -x "$BIN/$1" ]; then echo "$BIN/$1"; else command -v "$1"; fi; }
LUAU="$(tool luau)"; ROJO="$(tool rojo)"; STYLUA="$(tool stylua)"
for t in "$LUAU" "$ROJO" "$STYLUA"; do
	[ -n "$t" ] || { echo "missing tool (luau/rojo/stylua); install with rokit"; exit 2; }
done
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PLACE="$WORK/check.rbxlx"
failures=()
step() {
	local name="$1"; shift
	local log="$WORK/step.log"
	if "$@" >"$log" 2>&1; then
		echo "PASS  $name"
	else
		echo "FAIL  $name"; tail -n 25 "$log" | sed 's/^/      /'
		failures+=("$name")
	fi
}

step "stylua formatting"          "$STYLUA" --check src tests
step "rojo build"                 "$ROJO" build default.project.json -o "$PLACE"
for test in tests/test_*.py; do
	step "python $(basename "$test")" env ENFLESHED_PLACE_FILE="$PLACE" python3 -I "$test"
done
for flag in "" --library-only --workflow-only --starters-only --visual-plan-only \
	--composer-only --vfx-only --forge-only --action-flow-only; do
	step "magic suite ${flag:-(main)}" python3 scripts/run_luau_magic_tests.py "$LUAU" $flag
done
step "inventory suite"            python3 scripts/run_luau_inventory_tests.py "$LUAU"
step "ui suite"                   python3 scripts/run_luau_ui_tests.py "$LUAU"
step "emergent magic audit"       python3 scripts/run_emergent_magic_audit.py "$LUAU"
step "standalone unit tests"      python3 scripts/run_luau_unit_tests.py "$LUAU"
# Self-contained specs that `require` their module directly.
for spec in $(grep -l '^local [A-Za-z]* = require("\.\./' tests/*.luau); do
	step "spec $(basename "$spec")" "$LUAU" "$spec"
done

echo
if [ ${#failures[@]} -eq 0 ]; then
	echo "All checks passed."
else
	echo "${#failures[@]} check(s) failed: ${failures[*]}"
	exit 1
fi
