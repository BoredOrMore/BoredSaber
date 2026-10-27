#!/usr/bin/env python3
"""Synthesises the Classic environment's default sky, game/data/background/stage_sky.png, so it follows the
lighting rules (AGENTS.md "Light") instead of the old photographs: a dark, low-saturation night over a concert
stage, the horizon a little lighter where haze catches the stage lights, soft drifting haze, and a few dim, small
warm and cool lamps far off along the horizon as the only points of light. The map's lights are added on top by
the sky shader (bg_0..4 masks), so this stays dark.

Equirectangular, as the sky sphere's UV: u around, v from the top (0) through the horizon (0.5) to below (1).
Standard library only; rerun after changing a value:
    python3 tools/make_stage_sky.py
"""
import math
import random
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "data" / "background" / "stage_sky.png"
WIDTH, HEIGHT = 1024, 512
TOP = (0.020, 0.022, 0.030)  # zenith: near black
HORIZON = (0.110, 0.115, 0.130)  # haze lit by the stage, nearly grey
HORIZON_SHARPNESS = 7.0
HAZE_AMOUNT = 0.9  # how much the drifting haze brightens the sky where it is thick
LAMPS = 26
LAMP_RADIUS = 0.006  # in UV
LAMP_COLORS = [(0.55, 0.50, 0.42), (0.42, 0.46, 0.55), (0.50, 0.50, 0.50)]  # warm, cool, neutral, all dim


def value_noise(seed: int, cells_u: int, cells_v: int):
    rng = random.Random(seed)
    grid = [[rng.random() for _ in range(cells_u + 1)] for _ in range(cells_v + 1)]
    for row in grid:
        row[cells_u] = row[0]  # wraps around the sphere

    def sample(u: float, v: float) -> float:
        x, y = u * cells_u, v * cells_v
        i, j = int(x) % cells_u, min(int(y), cells_v - 1)
        fx, fy = x - int(x), y - int(y)
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = grid[j][i] + (grid[j][i + 1] - grid[j][i]) * fx
        b = grid[j + 1][i] + (grid[j + 1][i + 1] - grid[j + 1][i]) * fx
        return a + (b - a) * fy
    return sample


def main() -> None:
    haze_a = value_noise(3, 12, 6)
    haze_b = value_noise(5, 24, 12)
    rng = random.Random(9)
    lamps = [(rng.random(), 0.5 - rng.uniform(0.004, 0.03), rng.choice(LAMP_COLORS), rng.uniform(0.4, 1.0))
             for _ in range(LAMPS)]
    rows = []
    for y in range(HEIGHT):
        v = (y + 0.5) / HEIGHT
        horizon = math.exp(-abs(v - 0.5) * HORIZON_SHARPNESS)
        row = bytearray([0])  # PNG filter: none
        for x in range(WIDTH):
            u = (x + 0.5) / WIDTH
            haze = (0.65 * haze_a(u, v) + 0.35 * haze_b(u, v)) * horizon
            col = [TOP[c] + (HORIZON[c] - TOP[c]) * horizon for c in range(3)]
            col = [c * (1.0 + HAZE_AMOUNT * (haze - 0.5)) for c in col]
            for lu, lv, lc, li in lamps:
                du = min(abs(u - lu), 1.0 - abs(u - lu)) * 2.0  # u spans twice the angle of v
                d2 = (du * du + (v - lv) ** 2) / (LAMP_RADIUS * LAMP_RADIUS)
                if d2 < 9.0:
                    glow = li * math.exp(-d2)
                    col = [col[c] + lc[c] * glow for c in range(3)]
            row += bytes(max(0, min(255, round(255 * c))) for c in col)  # the sky shader shows these values as they are
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    OUT.write_bytes(png)
    print(OUT, len(png), "bytes")


main()
