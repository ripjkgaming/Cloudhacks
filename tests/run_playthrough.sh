#!/bin/bash
# Usage: tests/run_playthrough.sh <policy> [scale] [shots_dir]
# Plays a full run with the QA bot under a virtual display and prints the RESULT line.
# RES=WxH runs the game window at that size (default 1280x720), e.g. RES=800x600 or RES=2560x1080.
GODOT=${GODOT:-/tmp/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
POLICY=${1:-mixed}; SCALE=${2:-10}; SHOTS=${3:-}; RES=${RES:-1280x720}
ARGS="--bot --policy=$POLICY --scale=$SCALE"
[ -n "$SHOTS" ] && ARGS="$ARGS --shots=$SHOTS"
timeout ${TIMEOUT:-600} xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path . --rendering-driver opengl3 --resolution $RES -- $ARGS 2>&1 \
  | grep -vE "ALSA|audio_driver|All audio drivers|at: initialize|V-Sync|set_use_vsync|^\s*$"
