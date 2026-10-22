#!/usr/bin/env python3
"""Synthesises the countdown sounds, so the game needs no sound files from elsewhere (no licences, tweak at will).

countdown_tick: each of 3, 2, 1 before a song starts or resumes: a short, soft wood-block tick.
countdown_go: when the song starts: the same tick a fifth higher and longer, so it reads as "now".

Rerun after changing a value here (standard library only):
    python3 tools/make_countdown_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "data"
RATE = 44100


def tone(hz: float, seconds: float, decay: float) -> list[float]:
    """A tick: a sine with a quieter octave above, full level within 2 ms, then an exponential decay."""
    n = int(seconds * RATE)
    attack = int(0.002 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        level = min(1.0, i / attack) * math.exp(-t / decay)
        out.append(level * (math.sin(2 * math.pi * hz * t) + 0.3 * math.sin(2 * math.pi * 2 * hz * t)))
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


save("countdown_tick.wav", tone(880.0, 0.12, 0.03), -12.0)
save("countdown_go.wav", tone(1320.0, 0.3, 0.08), -9.0)
