# The stair house (doc/assets/stair_house/spec.md): the rooftop bulkhead on the player's roof, on the tower-wall side.
# A concrete hut with a roof slab, an off-centre steel door in a frame with a step, a vent pipe, a louvred vent.
# Origin at the floor under the body's middle; Blender z up (Godot y up); the door faces -y (Godot +z; the rig turns it
# to face the track). Blender x runs along the track in the rig.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/stair_house.py -- game/models
# Sizes in metres. Made from scratch.
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

BODY = (4.0, 3.0, 2.8)
# the roof slab: thickness, overhang all round, and over the door's side
SLAB = (0.15, 0.15, 0.4)
# the door: width, height, its centre along the front (off-centre toward +x), the frame's width and how far it stands out
DOOR = (0.9, 2.0, 0.9)
FRAME = (0.12, 0.06)
# the step in front of the door: width, depth, height
STEP = (1.3, 0.45, 0.15)
# the vent pipe on the roof: radius, height, where (x, y)
PIPE = (0.12, 1.0, -1.5, 1.0)
# the louvred vent on the -x end wall: width, height, how far out, its centre height
VENT = (0.8, 0.5, 0.05, 1.9)
VENT_SLATS = 3


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)
	return b


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
w, d, h = BODY
front = -d * 0.5
box(bm, (w, d, h), (0.0, 0.0, h * 0.5))
# the slab: overhanging all round, more over the door's side
box(bm, (w + SLAB[1] * 2.0, d + SLAB[1] + SLAB[2], SLAB[0]), (0.0, -(SLAB[2] - SLAB[1]) * 0.5, h + SLAB[0] * 0.5))
# the door's frame (two jambs and the head) and the door leaf a little behind it
dx = DOOR[2]
for side in (-1, 1):
	box(bm, (FRAME[0], FRAME[1], DOOR[1] + FRAME[0]), (dx + side * (DOOR[0] + FRAME[0]) * 0.5, front - FRAME[1] * 0.5,
		(DOOR[1] + FRAME[0]) * 0.5))
box(bm, (DOOR[0] + FRAME[0] * 2.0, FRAME[1], FRAME[0]), (dx, front - FRAME[1] * 0.5, DOOR[1] + FRAME[0] * 0.5))
box(bm, (DOOR[0], 0.02, DOOR[1]), (dx, front - 0.01, DOOR[1] * 0.5))
box(bm, (STEP[0], STEP[1], STEP[2]), (dx, front - STEP[1] * 0.5, STEP[2] * 0.5))
# the vent pipe on the roof's back corner
pipe = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=PIPE[0], radius2=PIPE[0], depth=PIPE[1])
bmesh.ops.translate(bm, verts=pipe["verts"], vec=(PIPE[2], PIPE[3], h + SLAB[0] + PIPE[1] * 0.5))
# the louvred vent on the -x end wall
box(bm, (VENT[2] * 2.0, VENT[0], VENT[1]), (-w * 0.5, 0.2, VENT[3]))
for i in range(VENT_SLATS):
	z = VENT[3] - VENT[1] * 0.5 + VENT[1] * (i + 0.5) / VENT_SLATS
	box(bm, (VENT[2] * 3.0, VENT[0] * 0.9, 0.03), (-w * 0.5, 0.2, z))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("stair_house")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("stair_house", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "stair_house")
