#!/bin/bash
# Headless unit checks (no display needed). Usage: tests/run_unit.sh
GODOT=${GODOT:-/tmp/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
rc=0
for t in tests/*_test.gd; do
  out=$(timeout 300 "$GODOT" --headless --path . -s "$t" 2>&1)
  echo "$out" | grep -E "^\[|FAIL|SCRIPT ERROR"
  [ $? -eq 0 ] || rc=1
  echo "$out" | grep -qE "FAIL|SCRIPT ERROR" && rc=1
done
exit $rc
