# The rooftop antenna (doc/assets/antenna/spec.md): a TV aerial on Night City's low roofs, and scaled up, a radio mast
# on two towers' tops. A pole on a base plate, three crossbars near the top, two stays.
# Origin at the base, on the roof; Blender z up (Godot y up).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/antenna.py -- game/models
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

POLE = (0.05, 3.5)
BASE = (0.4, 0.04)
# the crossbars: length each, lowest first, their spacing and thickness, how far below the top the highest is
BARS = (1.2, 0.9, 0.6)
BAR_STEP = 0.35
BAR_THICK = 0.03
BAR_TOP_GAP = 0.15
# the stays: from this far up the pole to the base's corners, this thick
STAY_FROM = 1.6
STAY_THICK = 0.02


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)
	return b


def strut(bm, a, b, thick):
	"""A thin square bar from a to b."""
	a, b = Vector(a), Vector(b)
	d = b - a
	s = box(bm, (thick, thick, d.length), (0.0, 0.0, 0.0))
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=s["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=s["verts"], vec=(a + b) * 0.5)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
box(bm, (BASE[0], BASE[0], BASE[1]), (0.0, 0.0, BASE[1] * 0.5))
box(bm, (POLE[0], POLE[0], POLE[1]), (0.0, 0.0, POLE[1] * 0.5))
for i, length in enumerate(BARS):
	z = POLE[1] - BAR_TOP_GAP - (len(BARS) - 1 - i) * BAR_STEP
	box(bm, (length, BAR_THICK, BAR_THICK), (0.0, 0.0, z))
corner = BASE[0] * 0.5
for x, y in ((corner, corner), (-corner, -corner)):
	strut(bm, (x, y, BASE[1]), (0.0, 0.0, STAY_FROM), STAY_THICK)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("antenna")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("antenna", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "antenna")
