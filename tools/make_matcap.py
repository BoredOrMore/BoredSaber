"""Writes game/env/metal_matcap.png: a neutral grey matcap for EnvSolid's metal layer (layer 8).

A matcap is a picture of a lit sphere seen from the front; the shader looks a face up in it by the way the face points
toward the eye (its view-space normal), which gives metal its sheen without real lights (AGENTS.md "Light", rule 10).
This one is grey only: the colour comes from the scene's lights in the shader (Light rules 3 and 4). Values are
brightness 0-1, kept low (scenery stays under fixtures in the brightness order, Light rule 1):
  - a dark base,
  - a soft highlight from above and in front, as from the hall's lights over the track,
  - a broad rim toward the sphere's edge (faces seen edge-on catch the light, as polished metal does).
Run: python3 tools/make_matcap.py   (standard library only)
"""
import math
import struct
import zlib

SIZE = 128
OUT = "game/env/metal_matcap.png"
# the base, the highlight's strength and tightness and where it comes from (up and toward the eye), the rim's
BASE = 0.12
HIGHLIGHT = 0.75
HIGHLIGHT_SHARPNESS = 12.0
HIGHLIGHT_FROM = (0.0, 0.6, 0.8)
RIM = 0.3
RIM_SHARPNESS = 3.0


def shade(x: float, y: float) -> float:
	"""Brightness of the sphere at (x, y) in -1..1 (y up); past the edge, the edge's."""
	r = math.hypot(x, y)
	if r > 1.0:
		x, y, r = x / r, y / r, 1.0
	z = math.sqrt(max(0.0, 1.0 - r * r))
	length = math.sqrt(sum(c * c for c in HIGHLIGHT_FROM))
	light = [c / length for c in HIGHLIGHT_FROM]
	facing = max(0.0, x * light[0] + y * light[1] + z * light[2])
	value = BASE + HIGHLIGHT * facing ** HIGHLIGHT_SHARPNESS + RIM * (1.0 - z) ** RIM_SHARPNESS
	return min(value, 1.0)


def png(width: int, height: int, rows: list) -> bytes:
	"""An 8-bit greyscale PNG of rows (lists of 0-255)."""
	raw = b"".join(b"\x00" + bytes(row) for row in rows)
	def chunk(kind: bytes, data: bytes) -> bytes:
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
	header = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
	return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


rows = []
for j in range(SIZE):
	y = 1.0 - (j + 0.5) / SIZE * 2.0
	rows.append([round(255 * shade((i + 0.5) / SIZE * 2.0 - 1.0, y)) for i in range(SIZE)])
with open(OUT, "wb") as f:
	f.write(png(SIZE, SIZE, rows))
print("wrote %s (%dx%d)" % (OUT, SIZE, SIZE))
