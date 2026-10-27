# Classic's hanging scaffold (doc/assets/hanging_scaffold/spec.md): a work platform hung on cables from the tunnel's
# ceiling, carrying the moving heads on its deck and the square bars under it.
# Origin at the deck's top centre; Blender z up (Godot y up), x across the tunnel, y the deck's depth.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/hanging_scaffold.py -- game/models
# Sizes in metres. Made from scratch.
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the deck: across, deep, plate thickness; bearers under it every BEARER_STEP (width, depth), the edge ledgers' size
DECK = (40.0, 3.0, 0.05)
BEARER_STEP = 2.5
BEARER = (0.1, 0.12)
LEDGER = 0.14
# toe boards round the deck: height, thickness
TOE = (0.15, 0.03)
# scaffold tubes: standards every STANDARD_STEP along both long edges, rails at these heights, the tube's width and sides
STANDARD_STEP = 5.0
RAILS = (1.1, 0.55)
TUBE = 0.12
TUBE_SIDES = 6
# a coupler where a standard meets the top rail (a cube this big)
COUPLER = 0.2
# the cable lugs at the deck's corners, where the rig's cables come down: x, plate size (across, thick, high)
LUG_X = 16.0
LUG = (0.3, 0.06, 0.3)


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)


def tube(bm, a, b):
	"""A six-sided scaffold tube from a to b."""
	a, b = Vector(a), Vector(b)
	d = b - a
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=TUBE_SIDES, radius1=TUBE * 0.5, radius2=TUBE * 0.5,
		depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
w, d, t = DECK
hw, hd = w * 0.5, d * 0.5
box(bm, (w, d, t), (0.0, 0.0, -t * 0.5))
# under the plate: bearers across the depth, edge ledgers along the length
n = int(w / BEARER_STEP)
for i in range(n + 1):
	x = -hw + BEARER[0] * 0.5 + (w - BEARER[0]) * i / n
	box(bm, (BEARER[0], d, BEARER[1]), (x, 0.0, -t - BEARER[1] * 0.5))
for y in (-hd + LEDGER * 0.5, hd - LEDGER * 0.5):
	box(bm, (w, LEDGER, LEDGER), (0.0, y, -t - LEDGER * 0.5))
# toe boards
for y in (-hd + TOE[1] * 0.5, hd - TOE[1] * 0.5):
	box(bm, (w, TOE[1], TOE[0]), (0.0, y, TOE[0] * 0.5))
for x in (-hw + TOE[1] * 0.5, hw - TOE[1] * 0.5):
	box(bm, (TOE[1], d, TOE[0]), (x, 0.0, TOE[0] * 0.5))
# standards, rails and couplers along both long edges; rails across both ends
inset = TUBE * 0.5
for y in (-hd + inset, hd - inset):
	m = int(w / STANDARD_STEP)
	for i in range(m + 1):
		x = -hw + inset + (w - TUBE) * i / m
		tube(bm, (x, y, 0.0), (x, y, RAILS[0] + TUBE * 0.5))
		box(bm, (COUPLER, COUPLER, COUPLER), (x, y, RAILS[0]))
	for h in RAILS:
		tube(bm, (-hw, y, h), (hw, y, h))
for x in (-hw + inset, hw - inset):
	for h in RAILS:
		tube(bm, (x, -hd, h), (x, hd, h))
# cable lugs on the long edges' top, where the cables meet the deck
for x in (-LUG_X, LUG_X):
	for y in (-hd + LUG[1] * 0.5, hd - LUG[1] * 0.5):
		box(bm, LUG, (x, y, TOE[0] + LUG[2] * 0.5))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("hanging_scaffold")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("hanging_scaffold", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "hanging_scaffold")
