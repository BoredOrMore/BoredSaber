# Pulse Void's rim parts (doc/assets/rim_parts/spec.md): a segment of the dish's rim girder (48 round it) and a mast
# on the rim ahead with the platform its beacon (a waving laser) stands on (six of them, three a side).
# Segment: a unit piece (-0.5..0.5), scaled by the rig to each segment (33 m along the rim, 3 m out, 3 m deep): x along
# the rim, Blender z the dish's normal (its top at +0.5), Blender -y toward the dish's centre (the face the player sees).
# Mast: origin at its foot on the rim; Blender z up; the beacon's platform's top at MAST_HEIGHT (PulseVoid MAST.x).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/rim_parts.py -- game/models
# Sizes in metres (the segment's in units of its scale). Made from scratch.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# segment: the girder's body (how far its inner face is set back), the top lip standing proud toward the centre
# (depth, height), stiffener plates on the inner face (count, width, how far out)
BODY_BACK = 0.1
LIP = (0.15, 0.12)
STIFFENERS = 3
STIFFENER = (0.03, 0.12)
# mast: height to the beacon platform's top, the three legs' spread at the foot and the top, leg size, ring levels,
# the platform's size and thickness, the plinth on the rim
MAST_HEIGHT = 40.0
SPREAD = (3.0, 1.2)
LEG = 0.35
LEVELS = 4
BRACE = 0.2
PLATFORM = (3.0, 0.3)
PLINTH = (4.0, 1.0)


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


def export(bm, name):
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, OUT_DIR, name)
	bpy.data.objects.remove(obj)


def segment():
	bm = bmesh.new()
	# the body, its inner face (-y) set back under the lip
	box(bm, (1.0, 1.0 - BODY_BACK, 1.0), (0.0, BODY_BACK * 0.5, 0.0))
	box(bm, (1.0, LIP[0] + BODY_BACK, LIP[1]), (0.0, -0.5 - LIP[0] * 0.5 + BODY_BACK * 0.5, 0.5 - LIP[1] * 0.5))
	for i in range(STIFFENERS):
		x = -0.5 + (i + 1) / (STIFFENERS + 1)
		box(bm, (STIFFENER[0], STIFFENER[1], 1.0 - LIP[1]), (x, -0.5 + BODY_BACK - STIFFENER[1] * 0.5, -LIP[1] * 0.5))
	export(bm, "rim_segment")


def mast():
	bm = bmesh.new()
	box(bm, (PLINTH[0], PLINTH[0], PLINTH[1]), (0.0, 0.0, PLINTH[1] * 0.5))
	top = MAST_HEIGHT - PLATFORM[1]
	feet, heads = [], []
	for i in range(3):
		a = math.tau * i / 3.0
		feet.append(Vector((math.sin(a), math.cos(a), 0.0)) * SPREAD[0] + Vector((0.0, 0.0, PLINTH[1])))
		heads.append(Vector((math.sin(a), math.cos(a), 0.0)) * SPREAD[1] + Vector((0.0, 0.0, top)))
	for f, h in zip(feet, heads):
		bar(bm, f, h, LEG)
	# rings of braces between the legs, LEVELS of them up the mast
	for level in range(1, LEVELS + 1):
		t = level / (LEVELS + 1)
		ring = [f.lerp(h, t) for f, h in zip(feet, heads)]
		for i in range(3):
			bar(bm, ring[i], ring[(i + 1) % 3], BRACE)
	box(bm, (PLATFORM[0], PLATFORM[0], PLATFORM[1]), (0.0, 0.0, top + PLATFORM[1] * 0.5))
	export(bm, "rim_mast")


bpy.ops.wm.read_factory_settings(use_empty=True)
segment()
mast()
