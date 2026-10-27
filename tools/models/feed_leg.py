# Pulse Void's feed leg (doc/assets/feed_leg/spec.md): one of the four lattice legs holding the feed cabin over the
# dish, from the cabin's underside corner down to the dish 150 m out, with level platforms for the floodlights (the
# diagonal lasers) along its top.
# Origin at the leg's top end, on its axis; the leg runs along Blender +y (Godot -z, the rig aims it at its foot),
# Blender z square to it, upward. The four legs are the same piece turned.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/feed_leg.py -- game/models
# Sizes in metres. Made from scratch.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the leg's ends (PulseVoid: the cabin's underside corner at 45 degrees, the dish 150 m out), so its length and slope
CABIN_HALF = 6.0
CABIN_UNDER = -0.4 - 7.0
REACH = 150.0
FOOT_Y = -125.0 + REACH * REACH / 500.0
TOP_R = CABIN_HALF * math.sqrt(0.5) * math.sqrt(2.0)
LENGTH = math.hypot(REACH - TOP_R, CABIN_UNDER - FOOT_Y)
SLOPE = math.atan2(CABIN_UNDER - FOOT_Y, REACH - TOP_R)
# the truss: a triangle, two top chords this far apart and a bottom one this far under them, chord size; zigzag bracing
# on its two sides, a panel every PANEL_STEP
WIDTH = 2.5
DEPTH = 2.5
CHORD = 0.3
PANEL_STEP = 20.0
BRACE = 0.2
# the floodlight platforms (PulseVoid FLOOD_AT, FLOOD_DECK): along the leg, level decks with their top this far over
# the leg's axis; deck size, thickness, the rail's height and tube
FLOOD_AT = (0.25, 0.5, 0.75)
FLOOD_DECK = 1.5
DECK = (2.4, 2.4, 0.2)
RAIL = (1.0, 0.08)


def bar(bm, a, b, thick):
	a, b = Vector(a), Vector(b)
	d = b - a
	r = thick * 0.5 * 1.414
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=r, radius2=r, depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)


def box(bm, size, centre, rot):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.rotate(bm, verts=b["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
hw = WIDTH * 0.5
top, under = DEPTH * 0.5, -DEPTH * 0.5
chords = [(-hw, top), (hw, top), (0.0, under)]
for x, z in chords:
	bar(bm, (x, 0.0, z), (x, LENGTH, z), CHORD)
n = max(int(LENGTH / PANEL_STEP), 1)
for i in range(n):
	ya, yb = LENGTH * i / n, LENGTH * (i + 1) / n
	for x in (-hw, hw):
		bar(bm, (x, ya, top), (0.0, yb, under), BRACE)
# the platforms: level (turned back by the leg's slope about x), on the top chords
level = Matrix.Rotation(SLOPE, 3, "X")
up = level @ Vector((0.0, 0.0, 1.0))
for t in FLOOD_AT:
	c = Vector((0.0, LENGTH * t, 0.0)) + up * (FLOOD_DECK - DECK[2] * 0.5)
	box(bm, DECK, c, level)
	# a rail round three sides, open toward the cabin (uphill)
	for x in (-DECK[0] * 0.5, DECK[0] * 0.5):
		a = c + level @ Vector((x, -DECK[1] * 0.5, 0.0))
		b = c + level @ Vector((x, DECK[1] * 0.5, 0.0))
		bar(bm, a + up * RAIL[0], b + up * RAIL[0], RAIL[1])
	a = c + level @ Vector((-DECK[0] * 0.5, DECK[1] * 0.5, 0.0))
	b = c + level @ Vector((DECK[0] * 0.5, DECK[1] * 0.5, 0.0))
	bar(bm, a + up * RAIL[0], b + up * RAIL[0], RAIL[1])
	for x in (-DECK[0] * 0.5, DECK[0] * 0.5):
		for y in (-DECK[1] * 0.5, DECK[1] * 0.5):
			p = c + level @ Vector((x, y, 0.0))
			bar(bm, p, p + up * RAIL[0], RAIL[1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("feed_leg")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("feed_leg", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "feed_leg")
print("feed_leg length", LENGTH, "slope deg", math.degrees(SLOPE))
