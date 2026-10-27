#!/usr/bin/env python3
"""Synthesises the combo sounds (ComboHud.gd), so the game needs no sound files from elsewhere.

combo_up: a bell fifth an octave down (C5) over a heavy low body (C3 with a C2 sub) when the multiplier goes up,
    ringing ~0.85 s; ComboHud raises its pitch for x4 and x8.
combo_milestone: the rising arpeggio at C5 over the same low body, with a baked room tail, ~1.9 s.
The owner asked for both to be bassy, deep and lingering (2026-10-27) and picked these from loudness-matched
variants. The low body has a 2nd harmonic so the Pico's speakers, which barely play below ~80 Hz, still carry it.
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


def body(freq: float, seconds: float, decay: float) -> list[float]:
    """A low sine hit with a 2 ms attack and a little 2nd harmonic, the weight under a chime."""
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        phase = 2 * math.pi * freq * t
        out.append(min(t / 0.002, 1.0) * (math.sin(phase) + 0.3 * math.sin(2 * phase)) * math.exp(-t / decay))
    return out


def room(dry: list[float], rt60: float, wet: float, extra: float) -> list[float]:
    """A baked tail: four feedback combs (Schroeder) through a one-pole low-pass, mixed under the dry sound."""
    n = len(dry) + int(extra * RATE)
    x = dry + [0.0] * (n - len(dry))
    acc = [0.0] * n
    for ms in (29.7, 37.1, 41.1, 43.7):
        d = int(ms / 1000 * RATE)
        g = 10 ** (-3 * (ms / 1000) / rt60)
        buf = [0.0] * n
        for i in range(n):
            buf[i] = x[i] + (g * buf[i - d] if i >= d else 0.0)
        for i in range(n):
            acc[i] += buf[i] - x[i]
    y, out = 0.0, []
    for i in range(n):
        y = 0.75 * y + 0.25 * acc[i]
        out.append(x[i] + wet * y / 4)
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


C5, C3, C2 = C6 / 2, C6 / 8, C6 / 16

up: list[float] = []
mix_at(up, bell(C5, 0.8, 0.25), 0.0, 0.7)
mix_at(up, bell(C5 * 1.5, 0.8, 0.25), 0.05, 1.0)
mix_at(up, body(C3, 0.45, 0.14), 0.0, 1.6)
mix_at(up, body(C2, 0.6, 0.2), 0.0, 1.2)
# peak level set so it is as loud as the old chime (max momentary -18.7 LUFS)
save("combo_up.wav", up, -5.2)

milestone: list[float] = []
for k, ratio in enumerate([1.0, 1.26, 1.5, 2.0]):
    mix_at(milestone, bell(C5 * ratio, 1.4, 0.45), k * 0.06, 0.8 if k < 3 else 1.0)
mix_at(milestone, body(C3, 0.7, 0.22), 0.0, 1.6)
mix_at(milestone, body(C2, 1.0, 0.35), 0.0, 1.3)
# as loud as the old arpeggio (max momentary -16.4 LUFS)
save("combo_milestone.wav", room(milestone, 1.2, 0.7, 0.3), -4.9)

save("combo_break.wav", drop(0.3), -10.0)
