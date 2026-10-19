#!/usr/bin/env python3
"""Bakes the Night City sky into two mask textures: a skyline of dark towers with windows, all around the track.

As with tools/bake_neon_grid_sky.py, nothing is worked out per pixel on the headset: NightCitySky.gdshader adds
mask * tint * intensity for each light group. The towers stand in two rows (near and far, the far one hazier),
lower straight ahead so the view down the track stays open. Each window stores its own random number, which the
shader uses to switch a few windows on and off over time.

Rerun after changing a value here (needs numpy and Pillow):
    python3 tools/bake_night_city_sky.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "game" / "env"
SHARP_SIZE = (4096, 768)
SOFT_SIZE = (1024, 192)
# same UV band as the Neon Grid sky: 50 degrees above the horizon to 5 below
V_TOP = 0.5 - 50.0 / 180.0
V_BOTTOM = 0.5 + 5.0 / 180.0
HAZE_SCALE = 1.5
RIM_SCALE = 1.0
BAND_SCALE = 0.25
GLOW_SCALE = 0.5
SEED = 7

SKY_HAZE = 0.25  # same as the other skies, so all share one air colour
HORIZON_SHARPNESS = 10.0
# towers: angular width range (radians) and height range (sine of elevation) for each row
NEAR_ROW = dict(width=(0.05, 0.14), height=(0.10, 0.32), shade=0.12, gap=(0.0, 0.03))
FAR_ROW = dict(width=(0.03, 0.08), height=(0.05, 0.16), shade=0.45, gap=(0.0, 0.01))
# towers straight ahead are this much lower, so the track's end stays in view
FRONT_HEIGHT = 0.35
FRONT_WIDTH = 0.6  # radians either side of straight ahead where they are lowered
# windows: size and spacing in radians across and in sine of elevation up, and the share that exists at all
WINDOW_COLUMN = 0.0075
WINDOW_ROW = 0.011
WINDOW_FILL = (0.5, 0.55)  # fraction of a cell the window covers, across and up
WINDOW_SHARE = 0.55
FAR_WINDOW_DIM = 0.5
RIM_STRENGTH = 0.5
RIM_WIDTH = 0.004
STREET_GLOW = 0.6  # light rising from the streets between the towers
STREET_SHARPNESS = 25.0
BAND_ELEVATION = 0.45
BAND_SHARPNESS = 10.0
BAND_STRENGTH = 0.15
CENTRE_GLOW = 0.35  # glow over the city straight ahead
CENTRE_WIDTH = 0.35


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def skyline(rng, row):
    """Tower edges around the full circle: a list of (start azimuth, end azimuth, height)."""
    towers = []
    az = -np.pi
    while az < np.pi:
        w = rng.uniform(*row["width"])
        h = rng.uniform(*row["height"])
        towers.append((az, az + w, h))
        az += w + rng.uniform(*row["gap"])
    return towers


def tower_heights(towers, az):
    """Height of the skyline and the index of the tower at each azimuth (-1 where there is none)."""
    height = np.zeros_like(az)
    index = np.full(az.shape, -1)
    for i, (a0, a1, h) in enumerate(towers):
        inside = (az >= a0) & (az < a1)
        # lowered as a whole, by where its middle is, so its roof stays flat
        middle = abs(0.5 * (a0 + a1))
        height[inside] = h * (FRONT_HEIGHT + (1.0 - FRONT_HEIGHT) * smoothstep(FRONT_WIDTH * 0.5, FRONT_WIDTH, middle))
        index[inside] = i
    return height, index


def windows(rng, towers, index, az, y, top, px):
    """How lit each texel is by a window, and that window's random number."""
    starts = np.array([t[0] for t in towers])
    local_x = az - starts[np.maximum(index, 0)]
    col = np.floor(local_x / WINDOW_COLUMN)
    row = np.floor(y / WINDOW_ROW)
    fx = local_x / WINDOW_COLUMN - col
    fy = y / WINDOW_ROW - row
    shape_x = smoothstep(0.0, px / WINDOW_COLUMN, fx) * (1.0 - smoothstep(WINDOW_FILL[0] - px / WINDOW_COLUMN, WINDOW_FILL[0], fx))
    shape_y = smoothstep(0.0, px / WINDOW_ROW, fy) * (1.0 - smoothstep(WINDOW_FILL[1] - px / WINDOW_ROW, WINDOW_FILL[1], fy))
    # a hash of tower, column and row gives each window its own random number
    h = np.sin(index * 127.1 + col * 311.7 + row * 74.7) * 43758.5453
    rand = h - np.floor(h)
    exists = (rand < WINDOW_SHARE) & (index >= 0) & (y > 0.004) & (y < top - WINDOW_ROW)
    # the random number fills the whole cell, so filtering at a window's edge doesn't blend it with a neighbour's
    return np.where(exists, shape_x * shape_y, 0.0), np.clip(rand / WINDOW_SHARE, 0.0, 1.0)


def masks(width, height):
    rng = np.random.default_rng(SEED)
    near, far = skyline(rng, NEAR_ROW), skyline(rng, FAR_ROW)
    u = (np.arange(width) + 0.5) / width
    v = V_TOP + (np.arange(height) + 0.5) / height * (V_BOTTOM - V_TOP)
    u, v = np.meshgrid(u, v)
    ring = np.sin(np.pi * v)
    x = np.sin(2 * np.pi * u) * ring
    y = np.cos(np.pi * v)
    z = np.cos(2 * np.pi * u) * ring
    az = np.arctan2(x, -z)
    px = max(np.pi * (V_BOTTOM - V_TOP) / height, 2 * np.pi / width)

    near_top, near_i = tower_heights(near, az)
    far_top, far_i = tower_heights(far, az)
    in_near = 1.0 - smoothstep(near_top - px, near_top + px, y)
    in_far = (1.0 - smoothstep(far_top - px, far_top + px, y)) * (1.0 - in_near)
    open_sky = 1.0 - in_near - in_far

    near_win, near_rand = windows(rng, near, near_i, az, y, near_top, px)
    far_win, far_rand = windows(rng, far, far_i, az, y, far_top, px)

    haze_sky = SKY_HAZE + np.exp(-np.abs(y) * HORIZON_SHARPNESS)
    haze = haze_sky * open_sky + NEAR_ROW["shade"] * in_near + FAR_ROW["shade"] * in_far
    lit = near_win * in_near + far_win * in_far * FAR_WINDOW_DIM
    rand = np.where(in_near > 0.5, near_rand, far_rand)
    rim = RIM_STRENGTH * (np.exp(-np.maximum(near_top - y, 0.0) / RIM_WIDTH) * in_near
                          + 0.5 * np.exp(-np.maximum(far_top - y, 0.0) / RIM_WIDTH) * in_far)
    rim += STREET_GLOW * np.exp(-np.maximum(y, 0.0) * STREET_SHARPNESS) * open_sky
    band = BAND_STRENGTH * np.exp(-np.abs(y - BAND_ELEVATION) * BAND_SHARPNESS) * open_sky
    glow = CENTRE_GLOW * np.exp(-np.abs(az) / CENTRE_WIDTH) * np.exp(-np.maximum(y, 0.0) * 6.0) * open_sky
    return dict(haze=haze, lit=lit, rand=rand, rim=rim, band=band, glow=glow)


def to_bytes(mask, scale):
    return np.clip(np.round(mask / scale * 255.0), 0, 255).astype(np.uint8)


def main():
    m = masks(*SHARP_SIZE)
    sharp = np.stack([to_bytes(m["haze"], HAZE_SCALE), to_bytes(m["lit"], 1.0), to_bytes(m["rand"], 1.0),
                      to_bytes(m["rim"], RIM_SCALE)], axis=-1)
    Image.fromarray(sharp, "RGBA").save(OUT / "night_city_sky_sharp.png", optimize=True)
    m = masks(*SOFT_SIZE)
    soft = np.stack([to_bytes(m["band"], BAND_SCALE), to_bytes(m["glow"], GLOW_SCALE), np.zeros(m["band"].shape, np.uint8)], axis=-1)
    Image.fromarray(soft, "RGB").save(OUT / "night_city_sky_soft.png", optimize=True)


if __name__ == "__main__":
    main()
