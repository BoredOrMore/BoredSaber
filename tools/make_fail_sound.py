#!/usr/bin/env python3
"""Makes fail.wav: the saber ignition (game/data/lightsaber.ogg) played backwards, so the sabers retract, then a
clean low thump as they go out. The player picked this over synthesised and Stable Audio versions.

The thump glides 130 -> 45 Hz: the Pico 4 speakers barely play below ~80 Hz, headphones still get the drop. The
file is dry (the Stinger bus adds the room) at TARGET_LUFS with true peak at most PEAK_DBTP, like the
Stable Audio sounds (tools/make_sa3_sounds.py). Needs ffmpeg. Rerun after changing a value here:
    python3 tools/make_fail_sound.py
"""
import json
import math
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "game" / "data"
RATE = 44100
TARGET_LUFS = -18.0
PEAK_DBTP = -1.0
FADE_IN_SECONDS = 0.05
# the thump starts this long into the reversed ignition, just before it ends
THUMP_START_SECONDS = 1.25
THUMP_FROM_HZ = 130.0
THUMP_TO_HZ = 45.0
THUMP_SECONDS = 0.6
THUMP_DECAY = 0.18


def ffmpeg(*args: str) -> str:
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y", *args], check=True,
                          capture_output=True, text=True).stderr


def write_thump(path: Path) -> None:
    """A sine gliding exponentially down, with a 5 ms attack: a clean sub thump with no noise."""
    out, phase = [], 0.0
    for i in range(int(THUMP_SECONDS * RATE)):
        t = i / RATE
        phase += 2 * math.pi * THUMP_FROM_HZ * (THUMP_TO_HZ / THUMP_FROM_HZ) ** (t / THUMP_SECONDS) / RATE
        out.append(min(t / 0.005, 1.0) * math.sin(phase) * math.exp(-t / THUMP_DECAY))
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(v * 32767 * 0.9)) for v in out))


with tempfile.TemporaryDirectory() as tmp:
    thump = Path(tmp) / "thump.wav"
    write_thump(thump)
    inputs = ["-i", str(DATA / "lightsaber.ogg"), "-i", str(thump)]
    mix = (f"[0:a]aresample={RATE},areverse,silenceremove=start_periods=1:start_threshold=-50dB,"
           f"afade=t=in:d={FADE_IN_SECONDS}[s];[1:a]aresample={RATE},adelay={int(THUMP_START_SECONDS * 1000)}[t];"
           f"[s][t]amix=inputs=2:normalize=0:duration=longest,highpass=f=30")
    stats = ffmpeg(*inputs, "-filter_complex", f"{mix},loudnorm=I={TARGET_LUFS}:TP={PEAK_DBTP}:print_format=json",
                   "-f", "null", "-")
    measured = json.loads(stats[stats.rindex("{"):stats.rindex("}") + 1])
    gain = min(TARGET_LUFS - float(measured["input_i"]), PEAK_DBTP - float(measured["input_tp"]))
    ffmpeg(*inputs, "-filter_complex", f"{mix},volume={gain:.2f}dB", "-ar", str(RATE), "-ac", "1",
           "-c:a", "pcm_s16le", str(DATA / "fail.wav"))
print(DATA / "fail.wav")
