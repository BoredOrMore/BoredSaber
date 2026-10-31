# Monolith's mountains (doc/assets/monolith_mountain/spec.md): low-poly faceted peaks rising out of the clouds round the
# valley, so their size reads against the clouds at their feet. Each variant is a jittered triangle grid lifted by a few
# peaks (each a cone with a concave flank) plus ridged noise for spurs and gullies, so no two have the same outline:
# a single peak, a twin peak and a long ridge, two of each (VARIANTS).
#  - monolith_mountain_<n>.glb: origin at the middle of the footprint's base, length along x, peaks up along Godot's +y.
#    The player sees the front: Blender -y, which is Godot +z after the y-up export.
# Vertex colours: red is baked ambient occlusion (dark gullies), green is the height share (0 at the base, 1 at the top
# peak) for the shader's paler tops. Flat shading (facets).
# Run headless: blender -b -P tools/models/monolith_mountain.py -- game/models
# Sizes in metres, from MonolithRig.gd (RIDGE_RINGS: up to 380 m above the valley at 950 m out). Untuned.
# Made from scratch; no outside assets.
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

sys.path.append(os.path.dirname(__file__))
import model_export  # noqa: E402

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# each variant: (length, depth, peaks as (x share along the length, height, radius share of the length, flank, skew)).
# flank shapes the slope: height = peak * (1 - distance / radius) ^ flank (below 1 a dome, above 1 a spire with concave
# flanks); skew above 0 makes the +x side steeper and the -x side longer, below 0 the other way
VARIANTS = [
	(500.0, 340.0, [(0.05, 300.0, 0.5, 1.7, 0.35)]),
	(460.0, 320.0, [(-0.12, 260.0, 0.45, 1.2, -0.3), (0.3, 140.0, 0.25, 0.9, 0.2)]),
	(600.0, 340.0, [(-0.22, 280.0, 0.38, 2.0, 0.1), (0.18, 210.0, 0.33, 1.1, -0.25)]),
	(560.0, 360.0, [(-0.28, 150.0, 0.3, 0.8, 0.0), (0.12, 310.0, 0.4, 1.6, 0.4)]),
	(900.0, 320.0, [(-0.38, 160.0, 0.22, 1.0, -0.2), (-0.12, 240.0, 0.28, 1.8, 0.3), (0.3, 190.0, 0.32, 1.2, -0.1)]),
	(800.0, 300.0, [(-0.32, 230.0, 0.3, 1.4, 0.25), (0.02, 120.0, 0.18, 0.9, 0.0), (0.33, 260.0, 0.28, 2.0, -0.35)]),
]
# the grid runs from the front edge (-depth / 2, the side the player sees) to BACK_SHARE of the depth behind the peaks
# (the back is never seen); cells along the length and the depth; vertices jitter by up to JITTER of a cell
BACK_SHARE = 0.15
CELLS = (28, 9)
JITTER = 0.25
# the height fades to 0 over this share of the footprint at every edge (no open sheet edge)
EDGE_FADE = 0.12
# the footprint is an ellipse; the depth radius of each peak is this share of its length radius
DEPTH_SHARE = 0.9
# ridged noise: spurs and gullies, this share of the local height, at this many cycles per metre; and a slow noise that
# raises shoulders and cuts notches into the outline, strongest at the summits (this share of the height there)
RIDGE_AMOUNT = 0.3
RIDGE_FREQUENCY = 1.0 / 120.0
SHOULDER_AMOUNT = 0.18
SHOULDER_FREQUENCY = 1.0 / 260.0
SEED = 47


def smoothstep(edge0, edge1, x):
	"""Returns 0 below edge0, 1 above edge1 and a smooth ramp between."""
	t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
	return t * t * (3.0 - 2.0 * t)


def height_at(x, y, length, depth, peaks, offset):
	"""Returns the mountain's height above the base at (x, y)."""
	h = 0.0
	top = 0.0
	for px, peak, radius, flank, skew in peaks:
		dx = (x - px * length) / (radius * length)
		dx *= 1.0 + skew if dx > 0.0 else 1.0 - skew
		dy = y / (radius * length * DEPTH_SHARE)
		d = math.sqrt(dx * dx + dy * dy)
		if d < 1.0:
			h = max(h, peak * (1.0 - d) ** flank)
		top = max(top, peak)
	if h <= 0.0:
		return 0.0
	p = Vector((x, y, 0.0))
	ridge = noise.ridged_multi_fractal(p * RIDGE_FREQUENCY + offset, 1.0, 2.0, 4, 1.0, 2.0)
	shoulder = noise.noise(p * SHOULDER_FREQUENCY + offset * 2.0)
	h *= 1.0 + RIDGE_AMOUNT * (ridge - 1.0) + SHOULDER_AMOUNT * shoulder * (h / top)
	fade = EDGE_FADE * length
	window = smoothstep(0.0, fade, length / 2 - abs(x)) * smoothstep(0.0, EDGE_FADE * depth, y + depth / 2)
	window *= smoothstep(0.0, EDGE_FADE * depth, depth * BACK_SHARE - y)
	return max(0.0, h * window)


def build(index, variant, rng):
	"""Returns the mesh object of one mountain: the front half of a jittered grid, each cell split along its shorter
	diagonal (no slivers)."""
	length, depth, peaks = variant
	offset = Vector((rng.uniform(0, 100), rng.uniform(0, 100), 0.0))
	bm = bmesh.new()
	cx, cy = CELLS
	y0, y1 = -depth / 2, depth * BACK_SHARE
	grid = []
	for j in range(cy + 1):
		row = []
		for i in range(cx + 1):
			x = (i / cx - 0.5) * length
			y = y0 + (y1 - y0) * j / cy
			if 0 < i < cx and 0 < j < cy:
				x += rng.uniform(-JITTER, JITTER) * length / cx
				y += rng.uniform(-JITTER, JITTER) * (y1 - y0) / cy
			row.append(bm.verts.new((x, y, height_at(x, y, length, depth, peaks, offset))))
		grid.append(row)
	for j in range(cy):
		for i in range(cx):
			a, b, c, d = grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]
			if max(v.co.z for v in (a, b, c, d)) <= 0.0:
				continue
			if (a.co - c.co).length <= (b.co - d.co).length:
				bm.faces.new((a, b, c))
				bm.faces.new((a, c, d))
			else:
				bm.faces.new((a, b, d))
				bm.faces.new((b, c, d))
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	mesh = bpy.data.meshes.new("monolith_mountain_%d" % index)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(mesh.name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def height_share(mesh):
	"""Returns each vertex's height share, 0 at the base and 1 at the top peak."""
	top = max(v.co.z for v in mesh.vertices)
	return [v.co.z / top for v in mesh.vertices]


rng = random.Random(SEED)
for i, variant in enumerate(VARIANTS):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	obj = build(i, variant, rng)
	model_export.bake_and_export(obj, OUT_DIR, obj.name, green=height_share(obj.data), unwrap=True)
