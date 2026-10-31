#!/usr/bin/env python3
"""Bakes the Neon Grid sky into two mask textures, so the headset only samples them.

Working the sky out per pixel (sun, stripe cuts, mountain ridge, several exp() curves) cost about 4.5 ms of
GPU a frame on the Pico 4. Everything in it is fixed except the light colours, so this writes, per sky
direction, how much of the haze and of each light group shows there; NeonGridSky.gdshader then adds
mask * tint * intensity, as the Classic sky does with its bg_0..4 maps.

The textures cover the band of the sky sphere's UV that holds all the detail (V_TOP..V_BOTTOM); the shader
clamps outside it, where every mask is flat. Rerun after changing a value here (needs numpy and Pillow):
    python3 tools/bake_neon_grid_sky.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "game" / "env"
SHARP_SIZE = (4096, 768)  # sun, mountains and horizon line: about 11 px per degree across, 14 up
SOFT_SIZE = (1024, 192)  # smooth glows
# band of the sphere's UV.y the textures cover: 50 degrees above the horizon to 5 below
# (UV.y = 0.5 - elevation / PI on Godot's SphereMesh)
V_TOP = 0.5 - 50.0 / 180.0
V_BOTTOM = 0.5 + 5.0 / 180.0
# each mask is stored divided by its scale, to fit 0..1; NeonGridSky.gdshader multiplies back
HAZE_SCALE = 1.5
SUN_SCALE = 2.0
RING_SCALE = 1.5
BAND_SCALE = 0.25
SIDE_SCALE = 0.25

# the look, as it was tuned in the per-pixel shader (untuned on the headset)
SKY_HAZE = 0.25  # same as the Classic sky, so both share one air colour
HORIZON_SHARPNESS = 10.0
BAND_ELEVATION = 0.35
BAND_SHARPNESS = 12.0
BAND_STRENGTH = 0.18
HORIZON_LINE_SHARPNESS = 40.0
HORIZON_LINE_STRENGTH = 0.8
SIDE_STRENGTH = 0.2
SUN_DIR = np.array([0.0, 0.139, -0.990])  # straight down the track, a little above the horizon
SUN_RADIUS = 0.2
SUN_STRENGTH = 0.9
SUN_GLOW = 0.35
SUN_GLOW_WIDTH = 0.15
SUN_STRIPES = 7.0  # cuts across the lower half of the sun, widening toward its bottom edge
SUN_STRIPE_GAP = 0.6
MOUNTAIN_HEIGHT = 0.15
MOUNTAIN_FRONT = 0.35  # mountains are lower straight ahead, so the sun stays in view
MOUNTAIN_SHADE = 0.3
RIM_WIDTH = 0.012
RIM_STRENGTH = 0.6
# the mountains' outline and the light along their rims blurred over this much (radians, a Gaussian's sigma), as far
# things soften in the air; the same width as the arches' soft edges (EnvSolid.gdshaderinc SHELL_BLUR_ANGLE). Untuned.
EDGE_BLUR = 0.007


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def masks(width, height):
    """Haze, sun, ring-light, band and side masks for each texel of a width x height texture."""
    u = (np.arange(width) + 0.5) / width
    v = V_TOP + (np.arange(height) + 0.5) / height * (V_BOTTOM - V_TOP)
    u, v = np.meshgrid(u, v)
    # direction of each texel on Godot's SphereMesh
    ring = np.sin(np.pi * v)
    d = np.stack([np.sin(2 * np.pi * u) * ring, np.cos(np.pi * v), np.cos(2 * np.pi * u) * ring], axis=-1)
    x, y = d[..., 0], d[..., 1]
    az = np.arctan2(x, -d[..., 2])  # 0 straight down the track
    # how far one texel reaches, for anti-aliased edges
    px = max(np.pi * (V_BOTTOM - V_TOP) / height, 2 * np.pi / width)

    haze = SKY_HAZE + np.exp(-np.abs(y) * HORIZON_SHARPNESS)
    band = BAND_STRENGTH * np.exp(-np.abs(y - BAND_ELEVATION) * BAND_SHARPNESS)
    ring_light = HORIZON_LINE_STRENGTH * np.exp(-np.abs(y) * HORIZON_LINE_SHARPNESS)
    side = np.exp(-np.abs(y) * 4.0) * SIDE_STRENGTH * smoothstep(0.2, 1.0, np.abs(x))

    r = np.linalg.norm(d - SUN_DIR, axis=-1)
    disc = 1.0 - smoothstep(SUN_RADIUS - px, SUN_RADIUS + px, r)
    sv = (y - SUN_DIR[1]) / SUN_RADIUS  # -1 at the bottom of the sun, 1 at the top
    stripes = sv * SUN_STRIPES
    spx = px / SUN_RADIUS * SUN_STRIPES
    gap = np.clip(-sv, 0.0, 1.0) * SUN_STRIPE_GAP
    cut = np.where(sv > 0.0, 1.0, smoothstep(gap - spx, gap + spx, stripes - np.floor(stripes)))
    sun = SUN_STRENGTH * (0.6 + 0.8 * (sv * 0.5 + 0.5)) * disc * cut
    sun += SUN_GLOW * np.exp(-np.maximum(r - SUN_RADIUS, 0.0) / SUN_GLOW_WIDTH)

    # whole-number frequencies of the azimuth, so the ridge line meets itself behind the player
    ridge = (0.5 + 0.5 * np.sin(az * 3.0 + 1.0)) * (0.6 + 0.4 * np.sin(az * 7.0 + 2.0)) + 0.1 * np.sin(az * 19.0)
    top = MOUNTAIN_HEIGHT * ridge * (MOUNTAIN_FRONT + (1.0 - MOUNTAIN_FRONT) * smoothstep(0.2, 1.0, np.abs(az)))
    mountain = 1.0 - smoothstep(top - px, top + px, y)
    rim = RIM_STRENGTH * np.exp(-np.maximum(top - y, 0.0) / RIM_WIDTH) * mountain
    sigma = (EDGE_BLUR / (2 * np.pi / width), EDGE_BLUR / (np.pi * (V_BOTTOM - V_TOP) / height))
    mountain, rim = blur(mountain, *sigma), blur(rim, *sigma)
    sky = 1.0 - mountain
    return {
        "haze": haze * sky + MOUNTAIN_SHADE * mountain,
        "sun": sun * sky,
        "ring": ring_light * sky + rim,
        "band": band * sky,
        "side": side * sky,
    }


def blur(mask, sigma_x, sigma_y):
    """The mask blurred by a Gaussian of sigma_x, sigma_y texels; wrapping around the circle across, clamped up and down."""
    for axis, sigma, mode in ((1, sigma_x, "wrap"), (0, sigma_y, "edge")):
        r = int(np.ceil(sigma * 3.0))
        k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
        k /= k.sum()
        pad = [(0, 0), (0, 0)]
        pad[axis] = (r, r)
        padded = np.pad(mask, pad, mode=mode)
        mask = sum(k[i] * np.take(padded, np.arange(i, i + mask.shape[axis]), axis=axis) for i in range(2 * r + 1))
    return mask


def to_bytes(mask, scale):
    return np.clip(np.round(mask / scale * 255.0), 0, 255).astype(np.uint8)


def main():
    m = masks(*SHARP_SIZE)
    sharp = np.stack([to_bytes(m["haze"], HAZE_SCALE), to_bytes(m["sun"], SUN_SCALE), to_bytes(m["ring"], RING_SCALE)], axis=-1)
    Image.fromarray(sharp, "RGB").save(OUT / "neon_grid_sky_sharp.png", optimize=True)
    m = masks(*SOFT_SIZE)
    soft = np.stack([to_bytes(m["band"], BAND_SCALE), to_bytes(m["side"], SIDE_SCALE), np.zeros_like(to_bytes(m["side"], 1.0))], axis=-1)
    Image.fromarray(soft, "RGB").save(OUT / "neon_grid_sky_soft.png", optimize=True)


if __name__ == "__main__":
    main()
