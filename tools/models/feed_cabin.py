# Pulse Void's feed cabin and maintenance beam (doc/assets/feed_cabin/spec.md): the receiver's cabin at the dish's
# focus, under the player, with the feed horn under it aimed down at the dish, and the beam the track runs on, reaching
# forward. Seen from above and the sides, mostly looking down past the track.
# Origin at the cabin's top centre (PulseVoid CABIN_TOP under the track); Blender z up, Blender +y is Godot -z (ahead).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/feed_cabin.py -- game/models
# Sizes in metres. Made from scratch.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the cabin (PulseVoid CABIN): width, depth, height; pilasters round it every PILASTER_STEP (width, how far out)
CABIN = (12.0, 12.0, 7.0)
PILASTER_STEP = 3.0
PILASTER = (0.3, 0.15)
# the front's window band: height of its middle, the windows' size and count, their frames' depth
WINDOW_Y = -2.5
WINDOW = (2.0, 1.2)
WINDOWS = 4
FRAME = 0.12
# louvred vents on the sides: slats, their size, the lowest slat's height under the top
SLATS = 4
SLAT = (3.0, 0.12, 0.25)
SLAT_TOP = -4.5
# the roof's parapet: height, thickness
PARAPET = (0.4, 0.2)
# the feed horn under the cabin: mouth radius, throat radius, length, sides
HORN = (2.2, 0.8, 3.0, 12)
# the beam: from the cabin's front to this far ahead, width, depth; chord size; a Warren truss panel every PANEL_STEP
BEAM_END = 61.0
BEAM = (5.0, 2.5)
CHORD = 0.25
PANEL_STEP = 5.0
BRACE = 0.18
# its handrails either side: posts every POST_STEP, rails at these heights over the walkway, tube size
POST_STEP = 10.0
RAILS = (1.1, 0.55)
RAIL = 0.1


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)


def bar(bm, a, b, thick):
	a, b = Vector(a), Vector(b)
	d = b - a
	r = thick * 0.5 * 1.414
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=r, radius2=r, depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)


def cabin(bm):
	w, d, h = CABIN
	box(bm, (w, d, h), (0.0, 0.0, -h * 0.5))
	# pilasters on all four faces, skipping the corners
	n = int(w / PILASTER_STEP)
	for i in range(1, n):
		x = -w * 0.5 + PILASTER_STEP * i
		for s in (-1, 1):
			box(bm, (PILASTER[0], PILASTER[1] * 2.0, h), (x, s * d * 0.5, -h * 0.5))
			box(bm, (PILASTER[1] * 2.0, PILASTER[0], h), (s * w * 0.5, x, -h * 0.5))
	# the front's windows (+y, ahead): frames standing out, between the pilasters
	for i in range(WINDOWS):
		x = -w * 0.5 + PILASTER_STEP * (i + 0.5)
		box(bm, (WINDOW[0] + FRAME * 2.0, FRAME * 2.0, WINDOW[1] + FRAME * 2.0), (x, d * 0.5 + FRAME * 0.5, WINDOW_Y))
		box(bm, (WINDOW[0], FRAME * 2.2, WINDOW[1]), (x, d * 0.5 + FRAME * 0.4, WINDOW_Y))
	# vents on the sides: slats leaning out
	for s in (-1, 1):
		for i in range(SLATS):
			box(bm, (SLAT[1], SLAT[0], SLAT[2]), (s * (w * 0.5 + SLAT[1]), 0.0, SLAT_TOP - i * SLAT[2] * 1.6))
	# the roof's parapet, open at the front where the beam meets it
	for s in (-1, 1):
		box(bm, (PARAPET[1], d, PARAPET[0]), (s * (w * 0.5 - PARAPET[1] * 0.5), 0.0, PARAPET[0] * 0.5))
	box(bm, (w, PARAPET[1], PARAPET[0]), (0.0, -d * 0.5 + PARAPET[1] * 0.5, PARAPET[0] * 0.5))
	# the feed horn, mouth down toward the dish
	cone = bmesh.ops.create_cone(bm, cap_ends=True, segments=HORN[3], radius1=HORN[0], radius2=HORN[1], depth=HORN[2])
	bmesh.ops.translate(bm, verts=cone["verts"], vec=(0.0, 0.0, -h - HORN[2] * 0.5))


def beam(bm):
	y0, y1 = CABIN[1] * 0.5, BEAM_END
	w, depth = BEAM
	top, bottom = -CHORD * 0.5, -depth + CHORD * 0.5
	for x in (-w * 0.5 + CHORD * 0.5, w * 0.5 - CHORD * 0.5):
		for z in (top, bottom):
			bar(bm, (x, y0, z), (x, y1, z), CHORD)
	# the walkway plate between the top chords, under the track deck
	box(bm, (w - CHORD * 2.0, y1 - y0, 0.05), (0.0, (y0 + y1) * 0.5, -0.025))
	# Warren bracing on both sides, cross members under the bottom chords at each panel point
	n = int((y1 - y0) / PANEL_STEP)
	for i in range(n):
		ya, yb = y0 + (y1 - y0) * i / n, y0 + (y1 - y0) * (i + 1) / n
		za, zb = (top, bottom) if i % 2 == 0 else (bottom, top)
		for x in (-w * 0.5 + CHORD * 0.5, w * 0.5 - CHORD * 0.5):
			bar(bm, (x, ya, za), (x, yb, zb), BRACE)
		if i % 2 == 1:
			bar(bm, (-w * 0.5, yb, bottom), (w * 0.5, yb, bottom), BRACE)
	# handrails either side
	m = int((y1 - y0) / POST_STEP)
	for x in (-w * 0.5 + RAIL * 0.5, w * 0.5 - RAIL * 0.5):
		for i in range(m + 1):
			y = y0 + (y1 - y0) * i / m
			bar(bm, (x, y, 0.0), (x, y, RAILS[0]), RAIL)
		for z in RAILS:
			bar(bm, (x, y0, z), (x, y1, z), RAIL)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
cabin(bm)
beam(bm)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("feed_cabin")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("feed_cabin", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "feed_cabin")
