#!/bin/bash
# Usage: tests/run_playthrough.sh <policy> [scale] [shots_dir]
# Plays a full run with the QA bot under a virtual display and prints the RESULT line.
GODOT=${GODOT:-/tmp/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
POLICY=${1:-mixed}; SCALE=${2:-10}; SHOTS=${3:-}
ARGS="--bot --policy=$POLICY --scale=$SCALE"
[ -n "$SHOTS" ] && ARGS="$ARGS --shots=$SHOTS"
timeout ${TIMEOUT:-600} xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 -- $ARGS 2>&1 \
  | grep -vE "ALSA|audio_driver|All audio drivers|at: initialize|V-Sync|set_use_vsync|^\s*$"
