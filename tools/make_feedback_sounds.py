#!/usr/bin/env python3
"""Synthesises the miss, low-health, fail, clear and menu sounds, so the game needs no sound files from elsewhere.

All of them share one palette so they read as one family with the combo sounds (tools/make_combo_sounds.py):
the same bell (a sine plus a faster-decaying partial at 2.76x), the same root C6 and the same soft noise.
Confirm and "on" go up, back and "off" go down (Brewster's earcons). Every file is dry: no room or reverb.

miss: a soft airy swipe, quiet on purpose; the combo break and the health bar already say it hurt.
low_health: one heartbeat (lub-dub) that loops, played while the health bar is in danger.
fail: a slow falling minor arpeggio over a low drop, for the song winding down.
clear: a rising major chord, slower and lower than the combo milestone so the two don't blur.
ui_hover: a very soft high tick, at most 30 ms, for the laser landing on a button.
ui_back: two low bell notes falling, for back and close buttons.
toggle_on / toggle_off: two quick high notes rising / falling, for switches and modifier chips.

Rerun after changing a value here (standard library only):
    python3 tools/make_feedback_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "data"
RATE = 44100
C6 = 1046.5
# semitone ratios from C
E, G, AB, F = 2 ** (4 / 12), 2 ** (7 / 12), 2 ** (8 / 12), 2 ** (5 / 12)


def bell(freq: float, seconds: float, decay: float) -> list[float]:
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        attack = min(t / 0.003, 1.0)
        tone = math.sin(2 * math.pi * freq * t) * math.exp(-t / decay)
        tone += 0.35 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t / (decay * 0.3))
        out.append(attack * tone)
    return out


def noise(seconds: float, smooth: float, seed: int) -> list[float]:
    """One-pole low-passed white noise; smooth near 1 is darker."""
    rng = random.Random(seed)
    out, y = [], 0.0
    for _ in range(int(seconds * RATE)):
        y = smooth * y + (1 - smooth) * rng.uniform(-1, 1)
        out.append(y)
    return out


def bandpass(samples: list[float], centre: list[float], q: float) -> list[float]:
    """Resonant band-pass (RBJ cookbook biquad) with a centre frequency per sample, for sweeps."""
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for x, f in zip(samples, centre):
        w = 2.0 * math.pi * f / RATE
        alpha = math.sin(w) / (2.0 * q)
        a0 = 1.0 + alpha
        b0, b2 = alpha / a0, -alpha / a0
        a1, a2 = -2.0 * math.cos(w) / a0, (1.0 - alpha) / a0
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def glide(f_from: float, f_to: float, seconds: float, decay: float) -> list[float]:
    """A sine gliding exponentially from f_from to f_to."""
    out, phase = [], 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        phase += 2 * math.pi * f_from * (f_to / f_from) ** (t / seconds) / RATE
        out.append(min(t / 0.005, 1.0) * math.sin(phase) * math.exp(-t / decay))
    return out


def mix_at(dest: list[float], src: list[float], start: float, gain: float) -> None:
    offset = int(start * RATE)
    dest.extend([0.0] * max(0, offset + len(src) - len(dest)))
    for i, v in enumerate(src):
        dest[offset + i] += v * gain


def save(name: str, samples: list[float], peak_db: float) -> None:
    peak = max(abs(s) for s in samples)
    gain = 10 ** (peak_db / 20) / peak
    # 5 ms fade at the end so it never clicks (and a loop meets silence at both ends)
    fade = int(0.005 * RATE)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print(OUT / name, f"{len(samples) / RATE:.2f} s")


# miss: noise swept down 2.4 kHz -> 700 Hz through a band-pass, swelling in and out
seconds = 0.2
n = int(seconds * RATE)
sweep = [2400.0 * (700.0 / 2400.0) ** (i / n) for i in range(n)]
miss = bandpass(noise(seconds, 0.3, 7), sweep, 1.2)
miss = [v * math.sin(math.pi * i / n) for i, v in enumerate(miss)]
save("miss.wav", miss, -16.0)

# low_health: lub-dub at 75 beats a minute (0.8 s loop), each beat a low falling thump
heart: list[float] = [0.0] * int(0.8 * RATE)
mix_at(heart, glide(90.0, 45.0, 0.16, 0.05), 0.0, 1.0)
mix_at(heart, glide(80.0, 40.0, 0.14, 0.04), 0.2, 0.7)
del heart[int(0.8 * RATE):]
save("low_health.wav", heart, -10.0)

# fail: C6 Ab5 F5 C5 falling with long tails, over an octave-and-a-half power-down
fail: list[float] = []
for k, ratio in enumerate([1.0, AB / 2, F / 2, 0.5]):
    mix_at(fail, bell(C6 * ratio, 1.0, 0.35), k * 0.14, 1.0 - 0.1 * k)
mix_at(fail, glide(440.0, 160.0, 1.4, 0.6), 0.0, 0.5)
mix_at(fail, noise(1.4, 0.98, 3), 0.0, 0.6)
save("fail.wav", fail, -8.0)

# clear: C5 G5 C6 E6 G6 rising, slower than the milestone, all ringing together at the end
clear: list[float] = []
for k, ratio in enumerate([0.5, G / 2, 1.0, E, G]):
    mix_at(clear, bell(C6 * ratio, 1.4, 0.45), k * 0.09, 0.7 if k < 4 else 1.0)
save("clear.wav", clear, -6.0)

save("ui_hover.wav", bell(C6 * 2.0, 0.03, 0.008), -20.0)

back: list[float] = []
mix_at(back, bell(C6 * G / 2, 0.15, 0.05), 0.0, 1.0)
mix_at(back, bell(C6 / 2, 0.2, 0.07), 0.06, 1.0)
save("ui_back.wav", back, -10.0)

on: list[float] = []
mix_at(on, bell(C6 * E, 0.08, 0.025), 0.0, 0.8)
mix_at(on, bell(C6 * 2.0, 0.1, 0.03), 0.035, 1.0)
save("toggle_on.wav", on, -12.0)

off: list[float] = []
mix_at(off, bell(C6 * 2.0, 0.08, 0.025), 0.0, 0.8)
mix_at(off, bell(C6 * E, 0.1, 0.03), 0.035, 1.0)
save("toggle_off.wav", off, -14.0)
