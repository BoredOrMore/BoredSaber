#!/usr/bin/env python3
"""Per-phase GPU table for a Benchmark run (game/Benchmark.gd), from `adb logcat -v time` text.

Matches the game's "BENCH start/end <phase>" lines to the headset's once-a-second PxrMetric lines for the game.
PxrMetric gives per-second averages, so "missed" is the share of the 72 frames a second that were not shown
(72 - FPS; its FrmEarly/FrmLate counts are mostly 0 and say little), and "s over" is the share of seconds whose average FrmGpu was over the 72 Hz budget.
Usage: tools/bench_report.py bench.log
"""
import re
import sys

PKG = "org.godotengine.open_saber_plus"
BUDGET_MS = 1000 / 72
# the first seconds after a switch still show the previous setup
SKIP_SECONDS = 2

stamp = re.compile(r"^\d\d-\d\d (\d\d):(\d\d):(\d\d)\.(\d+)")
bench = re.compile(r"BENCH (start|end) (\S+)")
metric = re.compile(r"FPS=(\d+)/(\d+),.*FrmCpu=([\d.]+)ms,FrmGpu=([\d.]+)ms.*?(?:GPUTemp=([\d.]+)C)?")


def seconds(line):
    m = stamp.match(line)
    return int(m[1]) * 3600 + int(m[2]) * 60 + int(m[3]) + float("0." + m[4]) if m else None


def main(path):
    phases, samples, open_phase = [], [], {}
    for line in open(path, errors="replace"):
        t = seconds(line)
        if t is None:
            continue
        b = bench.search(line)
        if b:
            if b[1] == "start":
                open_phase[b[2]] = t
            elif b[2] in open_phase:
                phases.append((b[2], open_phase.pop(b[2]), t))
            continue
        m = metric.search(line)
        if m and "Pkg=" + PKG in line:
            temp = re.search(r"GPUTemp=([\d.]+)C", line)
            samples.append((t, int(m[1]), int(m[2]), float(m[3]), float(m[4]), float(temp[1]) if temp else 0.0))
    if not phases:
        sys.exit("no BENCH phases in " + path)
    medians = {}
    print(f"{'phase':28} {'GPU ms':>7} {'median':>6} {'p95':>6} {'max':>6} {'missed':>7} {'s over':>7} {'CPU ms':>7} {'temp':>5} {'n':>3}")
    for name, start, end in phases:
        rows = [s for s in samples if start + SKIP_SECONDS <= s[0] <= end]
        if not rows:
            print(f"{name:28} no PxrMetric samples (display off?)")
            continue
        gpu = [r[4] for r in rows]
        late = 100 * sum(r[2] - r[1] for r in rows) / sum(r[2] for r in rows)
        over = 100 * sum(g > BUDGET_MS for g in gpu) / len(gpu)
        cpu = sum(r[3] for r in rows) / len(rows)
        ordered = sorted(gpu)
        median = ordered[len(ordered) // 2]
        p95 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.95))]
        print(f"{name:28} {sum(gpu) / len(gpu):7.2f} {median:6.2f} {p95:6.2f} {max(gpu):6.2f} {late:6.1f}% {over:6.0f}% {cpu:7.2f} {rows[-1][5]:5.1f} {len(rows):3}")
        medians[name] = median
    # a phase between two no-glow phases (glowb): its median against theirs, the headset's warming taken out
    names = [name for name, _, _ in phases]
    for i in range(1, len(names) - 1):
        before, after = names[i - 1], names[i + 1]
        if "glow_off" in before and "glow_off" in after and names[i] in medians and before in medians and after in medians:
            reference = (medians[before] + medians[after]) / 2
            print(f"{names[i]:28} {medians[names[i]] - reference:+6.2f} ms against the no-glow phases next to it ({reference:.2f})")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/dev/stdin")
