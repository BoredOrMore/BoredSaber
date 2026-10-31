# Monolith's clouds (doc/assets/monolith_cloud/spec.md): cumulus banks the player looks down on from the pillar, after
# the owner's reference (2026-10-31: layered puffs, bright tops fading into dark bodies). Each variant is one bank built
# from overlapping ellipsoids (big ones for the body, smaller bumps growing on top of them), each keeping its own surface
# so the creases between puffs stay sharp, cut flat at the bottom (the bottom is never seen, so it is dropped).
# VARIANTS give small, medium, large, towering and flat banks, so a scatter of them never repeats one shape.
#  - monolith_cloud_<n>.glb: origin at the middle of the bank's flat bottom, length along x, puffs up along Godot's +y.
# Vertex colours: red is baked ambient occlusion (dark creases between puffs), green is the height in the bank (0 at the
# bottom, 1 at the highest puff) for the shader's bright tops. Smooth shading (soft, round puffs).
# Run headless: blender -b -P tools/models/monolith_cloud.py -- game/models
# Sizes in metres, from MonolithRig.gd (CLOUD_RINGS rise 18-60 m, CLOUD_PUFF_WIDTH 40-110 m). Untuned.
# Made from scratch; no outside assets.
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
import model_export  # noqa: E402

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# each variant: (length, depth, height, where the tallest part sits along the length (-0.5 to 0.5), body ellipsoids, top
# bumps): small, medium and large banks, a towering one and a flat strip, the tallest part at a different place in each
VARIANTS = [
	(40.0, 22.0, 16.0, -0.2, 3, 7),
	(60.0, 18.0, 12.0, 0.25, 5, 8),
	(80.0, 36.0, 26.0, 0.1, 5, 10),
	(45.0, 40.0, 34.0, -0.05, 3, 10),
	(130.0, 55.0, 40.0, -0.3, 7, 14),
	(160.0, 50.0, 24.0, 0.35, 8, 12),
]
# body ellipsoids: radius as a share of the bank's height (min, max); they sit along the bank's length with their
# centres this share of the height above the bottom, the one nearest the tallest part lifted most (BODY_PEAK sets how
# much taller than the bank's ends)
BODY_RADIUS = (0.45, 0.7)
BODY_CENTRE = 0.15
BODY_PEAK = 0.6
# body ellipsoids stretch along the length to at least BODY_OVERLAP times the spacing between their centres, so the bank
# stays one piece
BODY_OVERLAP = 0.75
# top bumps: radius as a share of the radius of the puff they sit on (min, max), each on a body (BUMP_ON_BODY of them)
# or on a bump placed before it (so some bumps grow on bumps like a cauliflower), BUMP_TILT radians (min, max) off
# straight up, their centres BUMP_DEPTH of the way out to the surface (sunk in, so they merge)
BUMP_RADIUS = (0.45, 0.7)
BUMP_ON_BODY = 0.7
BUMP_TILT = (0.3, 0.9)
BUMP_DEPTH = 0.75
# ellipsoids are flattened to this share of their radius in height (cumulus tops are wider than tall)
SQUASH = 0.8
# segments round and top to bottom of each ellipsoid
SEGMENTS = (8, 5)
# the bank is cut flat this share of its height above the bottom; faces wholly below it are dropped
CUT = 0.05
SEED = 31


def ellipsoid(bm, centre, radii):
	"""Adds an ellipsoid with radii (x, y, z) at centre to bm and returns its faces."""
	geom = bmesh.ops.create_uvsphere(bm, u_segments=SEGMENTS[0], v_segments=SEGMENTS[1], radius=1.0)
	for v in geom["verts"]:
		v.co = Vector((v.co.x * radii.x, v.co.y * radii.y, v.co.z * radii.z)) + centre
	return {f for v in geom["verts"] for f in v.link_faces}


def inside(point, centre, radii):
	"""Returns whether point lies inside the ellipsoid with radii at centre."""
	d = point - centre
	return (d.x / radii.x) ** 2 + (d.y / radii.y) ** 2 + (d.z / radii.z) ** 2 < 0.98


def build(index, variant, rng):
	"""Returns the mesh object of one cloud bank: overlapping puffs, each keeping its own surface (the creases between
	them stay, for the baked occlusion), with the faces hidden inside other puffs and below the cut dropped."""
	length, depth, height, peak_at, bodies, bumps = variant
	bm = bmesh.new()
	puffs = []
	spacing = length / bodies
	for i in range(bodies):
		t = (i + 0.5) / bodies - 0.5 + rng.uniform(-0.3, 0.3) / bodies
		lift = 1.0 + BODY_PEAK * max(0.0, 1.0 - abs(t - peak_at) * 2.5)
		r = height * rng.uniform(*BODY_RADIUS) * lift * 0.7
		radii = Vector((max(r, spacing * BODY_OVERLAP), r, r * SQUASH))
		centre = Vector((t * (length - radii.x), rng.uniform(-0.2, 0.2) * depth, height * BODY_CENTRE * lift))
		puffs.append((centre, radii, ellipsoid(bm, centre, radii)))
	for i in range(bumps):
		pick = rng.randrange(bodies) if rng.random() < BUMP_ON_BODY else rng.randrange(len(puffs))
		centre, radii, _faces = puffs[pick]
		tilt = rng.uniform(*BUMP_TILT)
		side = rng.uniform(0.0, math.tau)
		on_top = centre + Vector((math.sin(tilt) * math.cos(side) * radii.x, math.sin(tilt) * math.sin(side) * radii.y,
				math.cos(tilt) * radii.z)) * BUMP_DEPTH
		r = min(radii.y, radii.z / SQUASH) * rng.uniform(*BUMP_RADIUS)
		bump = Vector((r, r, r * SQUASH))
		puffs.append((on_top, bump, ellipsoid(bm, on_top, bump)))
	cut = height * CUT
	hidden = set()
	for centre, r, faces in puffs:
		for f in faces:
			if all(v.co.z < cut for v in f.verts):
				hidden.add(f)
				continue
			for other_centre, other_r, other_faces in puffs:
				if other_faces is not faces and all(inside(v.co, other_centre, other_r) for v in f.verts):
					hidden.add(f)
					break
	bmesh.ops.delete(bm, geom=list(hidden), context="FACES")
	for v in bm.verts:
		v.co.z = max(v.co.z, cut) - cut
	mesh = bpy.data.meshes.new("monolith_cloud_%d" % index)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(mesh.name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def height_share(mesh):
	"""Returns each vertex's height in the bank, 0 at the bottom and 1 at the top."""
	top = max(v.co.z for v in mesh.vertices)
	return [max(0.0, v.co.z) / top for v in mesh.vertices]


rng = random.Random(SEED)
for i, variant in enumerate(VARIANTS):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	obj = build(i, variant, rng)
	model_export.bake_and_export(obj, OUT_DIR, obj.name, smooth=True, green=height_share(obj.data), unwrap=True)
