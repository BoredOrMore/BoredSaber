#!/bin/sh
# Starts the menu benchmark (game/Benchmark.gd) on the connected headset with the game open in the song menu,
# waits for it, saves the log to bench.log and prints the per-phase table. Wear the headset (or cover its
# proximity sensor) for the whole run: with the display off nothing is rendered.
set -e
PKG=org.godotengine.open_saber_plus
LOG=${1:-bench.log}
adb logcat -c
adb shell touch /sdcard/Android/data/$PKG/files/benchmark
echo "Started; about 7 minutes. Waiting for BENCH done..."
until adb logcat -d -s godot:I | grep -qE "BENCH (done|cancelled)"; do sleep 10; done
adb logcat -d -v time > "$LOG"
python3 "$(dirname "$0")/bench_report.py" "$LOG"
