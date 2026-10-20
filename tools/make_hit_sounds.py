#!/usr/bin/env python3
"""Synthesises the cut sounds, so the game needs no sound files from elsewhere (no licences, tweak at will).

cut_1..cut_4: a good cut. Four takes of the same recipe so repeated cuts don't sound like one sample on loop
    (the saber's AudioStreamRandomizer also varies pitch a little). Each is a sharp click (full level within a few
    milliseconds, so it lands on the beat), a bright "slice" of filtered noise sweeping down, and a short pitched
    thump that gives the hit its weight.
bad_cut: a cut at the wrong angle or with the wrong saber: duller, lower, with a short buzz, so it reads as wrong
    without being harsh.
bomb_hit: a low boom with crackle.

Rerun after changing a value here (standard library only):
    python3 tools/make_hit_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "data"
RATE = 44100


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


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    """One-pole low-pass."""
    a = math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y = (1.0 - a) * x + a * y
        out.append(y)
    return out


def envelope(n: int, attack: float, decay: float) -> list[float]:
    """Linear attack then exponential decay, in seconds."""
    return [min(i / RATE / attack, 1.0) * math.exp(-i / RATE / decay) for i in range(n)]


def thump(n: int, start_hz: float, end_hz: float, drop: float, decay: float) -> list[float]:
    """A sine whose pitch falls from start_hz to end_hz over drop seconds."""
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = end_hz + (start_hz - end_hz) * math.exp(-t / drop)
        phase += 2.0 * math.pi * f / RATE
        out.append(math.sin(phase) * min(t / 0.002, 1.0) * math.exp(-t / decay))
    return out


def mix(*parts: tuple[list[float], float]) -> list[float]:
    n = max(len(p) for p, _ in parts)
    out = [0.0] * n
    for p, gain in parts:
        for i, s in enumerate(p):
            out[i] += s * gain
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
    print(OUT / name, f"{len(samples) / RATE:.3f} s")


def cut(take: int) -> list[float]:
    rng = random.Random(1000 + take)
    n = int(0.18 * RATE)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    # click: the first few milliseconds of raw noise, high-passed by differencing
    click = [(noise[i] - noise[i - 1]) * math.exp(-i / RATE / 0.0015) if i else 0.0 for i in range(n)]
    # slice: noise through a resonant band sweeping down, like a blade through air
    top = 6500.0 * (1.0 + 0.08 * (take - 2.5))
    sweep = [1800.0 + (top - 1800.0) * math.exp(-i / RATE / 0.03) for i in range(n)]
    slice_ = [s * e for s, e in zip(bandpass(noise, sweep, 2.5), envelope(n, 0.001, 0.035))]
    # body: a short falling thump for weight
    body = thump(n, 240.0 * (1.0 + 0.05 * (take - 2.5)), 110.0, 0.025, 0.05)
    return mix((click, 0.5), (slice_, 1.0), (body, 0.55))


for take in range(1, 5):
    save(f"cut_{take}.wav", cut(take), -3.0)

rng = random.Random(7)
n = int(0.16 * RATE)
dull = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 900.0)
buzz = [(1.0 if math.sin(2.0 * math.pi * 92.0 * i / RATE) > 0 else -1.0) for i in range(n)]
save("bad_cut.wav", mix(
    ([s * e for s, e in zip(dull, envelope(n, 0.002, 0.04))], 1.0),
    ([s * e for s, e in zip(lowpass(buzz, 1200.0), envelope(n, 0.004, 0.06))], 0.35),
    (thump(n, 160.0, 80.0, 0.03, 0.06), 0.6)), -6.0)

rng = random.Random(11)
n = int(0.45 * RATE)
crackle = [rng.uniform(-1.0, 1.0) if rng.random() < 0.08 else 0.0 for _ in range(n)]
save("bomb_hit.wav", mix(
    (thump(n, 90.0, 38.0, 0.08, 0.18), 1.0),
    ([s * e for s, e in zip(lowpass(crackle, 3000.0), envelope(n, 0.001, 0.12))], 0.6),
    ([s * e for s, e in zip(lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 400.0), envelope(n, 0.003, 0.1))], 0.8)),
    -4.0)
