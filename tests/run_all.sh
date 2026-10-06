#!/usr/bin/env bash
# Runs the headless test suite. Usage: GODOT=/path/to/godot tests/run_all.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . res://tests/check_scripts.tscn
"$GODOT" --headless --path . -s res://tests/run_tests.gd
"$GODOT" --headless --path . res://tests/smoke_test.tscn
"$GODOT" --headless --path . res://tests/all_chunks_test.tscn
echo "All headless tests passed."
