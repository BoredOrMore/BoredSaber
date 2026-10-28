#!/bin/sh
# Starts the menu benchmark (game/Benchmark.gd) on the connected headset with the game open in the song menu,
# waits for it, saves the log to bench.log and prints the per-phase table. Wear the headset (or cover its
# proximity sensor) for the whole run: with the display off nothing is rendered.
# --only resolution: just the render scale phases (about 3 minutes).
# --only msaa: just the anti-aliasing phases, in a song (about 2.5 minutes).
# --only glowb: just the glow phases, in a song (about 3.5 minutes).
# --only total: the whole look's cost, each setup in a song between no-glow phases (about 6.5 minutes).
# --only hz90: the menu and a song at 72 and 90 Hz (about 3 minutes).
# --only fog: Night City then Metal Factory in a song: all on, lighter glow, scenery flat-coloured, scenery off, all on again (about 4 minutes).
# --only reflection: Classic in a song: the floor reflection on and off (twice), the build-up sweep held on (about 2 minutes).
set -e
MODE=
if [ "$1" = "--only" ]; then MODE=$2; shift 2; fi
PKG=org.godotengine.open_saber_plus
LOG=${1:-bench.log}
adb logcat -c
adb shell "echo '$MODE' > /sdcard/Android/data/$PKG/files/benchmark"
echo "Started ${MODE:-full run} (full: about 7 minutes, resolution: about 3). Waiting for BENCH done..."
until adb logcat -d -s godot:I | grep -qE "BENCH (done|cancelled)"; do sleep 10; done
adb logcat -d -v time > "$LOG"
python3 "$(dirname "$0")/bench_report.py" "$LOG"
