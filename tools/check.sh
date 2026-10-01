#!/bin/bash
# Parse/compile every script via Godot headless. Usage: tools/check.sh
GODOT=${GODOT:-/tmp/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
timeout 180 "$GODOT" --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error|at: " | grep -v "Compile Error: $" | awk '!seen[$0]++' | head -${1:-40}
