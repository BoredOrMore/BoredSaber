#!/usr/bin/env python3
"""Synthesises the combo sounds (ComboHud.gd), so the game needs no sound files from elsewhere.

combo_up: a short bell "ting" when the multiplier goes up; ComboHud raises its pitch for x4 and x8.
combo_milestone: a quick rising bell arpeggio at combo milestones.
combo_break: a soft low drop when a long combo breaks; gentle on purpose, a miss is punishment enough.

Bells are a sine plus a faster-decaying partial at 2.76x (the strongest overtone of a struck bar), so they read
as a chime rather than a beep. Rerun after changing a value here (standard library only):
    python3 tools/make_combo_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "data"
RATE = 44100
C6 = 1046.5


def bell(freq: float, seconds: float, decay: float) -> list[float]:
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        attack = min(t / 0.003, 1.0)
        tone = math.sin(2 * math.pi * freq * t) * math.exp(-t / decay)
        tone += 0.35 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t / (decay * 0.3))
        out.append(attack * tone)
    return out


def mix_at(dest: list[float], src: list[float], start: float, gain: float) -> None:
    offset = int(start * RATE)
    dest.extend([0.0] * max(0, offset + len(src) - len(dest)))
    for i, v in enumerate(src):
        dest[offset + i] += v * gain


def drop(seconds: float) -> list[float]:
    # a sine falling an octave, 220 to 110 Hz, with a little soft noise for body
    rng = random.Random(1)
    out, phase, noise = [], 0.0, 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        freq = 220.0 * 0.5 ** (t / seconds)
        phase += 2 * math.pi * freq / RATE
        noise = 0.9 * noise + 0.1 * rng.uniform(-1, 1)
        attack = min(t / 0.005, 1.0)
        out.append(attack * (math.sin(phase) + 0.3 * noise) * math.exp(-t / 0.09))
    return out


def save(name: str, samples: list[float], peak_db: float) -> None:
    peak = max(abs(s) for s in samples)
    gain = 10 ** (peak_db / 20) / peak
    # 5 ms fade at the end so it never clicks
    fade = int(0.005 * RATE)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print(OUT / name, f"{len(samples) / RATE:.2f} s")


up: list[float] = []
mix_at(up, bell(C6, 0.35, 0.12), 0.0, 0.7)
mix_at(up, bell(C6 * 1.5, 0.35, 0.12), 0.05, 1.0)
save("combo_up.wav", up, -6.0)

milestone: list[float] = []
for k, ratio in enumerate([1.0, 1.26, 1.5, 2.0]):
    mix_at(milestone, bell(C6 * ratio, 0.6, 0.18), k * 0.06, 0.8 if k < 3 else 1.0)
save("combo_milestone.wav", milestone, -6.0)

save("combo_break.wav", drop(0.3), -10.0)
