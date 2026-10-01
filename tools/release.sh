#!/bin/bash
# Export Linux + Windows builds and zip them. Usage: tools/release.sh <version>
# Output: build/CYCLE-<version>-linux.zip, build/CYCLE-<version>-windows.zip
set -e
GODOT=${GODOT:-/tmp/godot/Godot_v4.3-stable_linux.x86_64}
VER=${1:?version}
cd "$(dirname "$0")/.."
rm -rf build/linux build/windows
mkdir -p build/linux build/windows
timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --path . --export-release "Linux" build/linux/CYCLE.x86_64 2>&1 | grep -E "ERROR|error" || true
timeout 300 "$GODOT" --headless --path . --export-release "Windows" build/windows/CYCLE.exe 2>&1 | grep -E "ERROR|error" || true
test -s build/linux/CYCLE.x86_64 && test -s build/windows/CYCLE.exe
rm -f build/CYCLE-$VER-*.zip
(cd build/linux && zip -q9 ../CYCLE-$VER-linux.zip CYCLE.x86_64)
(cd build/windows && zip -q9 ../CYCLE-$VER-windows.zip CYCLE.exe)
ls -la build/*.zip
