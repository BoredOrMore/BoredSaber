#!/usr/bin/env bash
# Basic import/parse smoke check only. Usage: tools/run_godot_checks.sh /path/to/project
set -u
PROJECT_PATH="${1:-.}"
GODOT_BIN="${GODOT_BIN:-godot}"
command -v "$GODOT_BIN" >/dev/null 2>&1 || { echo "FAIL: Godot not found: $GODOT_BIN"; exit 127; }
echo "Godot: $("$GODOT_BIN" --version 2>&1)"
"$GODOT_BIN" --headless --path "$PROJECT_PATH" --editor --quit
status=$?
if [ "$status" -eq 0 ]; then echo "PASS: smoke check exited 0"; else echo "FAIL: exit $status"; fi
exit "$status"
