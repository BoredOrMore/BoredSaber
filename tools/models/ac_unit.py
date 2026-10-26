# The rooftop air-conditioning unit (doc/assets/ac_unit/spec.md): clutter on Night City's low roofs, a familiar-size cue.
# A condensing unit: a sheet-metal box on two rails, louvred long sides, a fan in a short shroud on top with a guard.
# Origin at the rails' feet, on the roof; Blender z up (Godot y up), the louvred sides face -y and +y (Godot +z, -z).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/ac_unit.py -- game/models
# Sizes in metres. Made from scratch.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

BODY = (1.2, 0.9, 1.0)
# the rails under the short ends: width, height
RAIL = (0.1, 0.12)
# the fan: its shroud's radius and height, sides
FAN_RADIUS = 0.35
FAN_DEPTH = 0.12
FAN_SIDES = 12
# the guard: bar thickness; the motor hub's radius and height
GUARD_BAR = 0.04
HUB = (0.09, 0.06)
# the louvres on the front and back: how many, how far they stand out, how thick
LOUVRES = 3
LOUVRE_OUT = 0.03
LOUVRE_THICK = 0.04


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)
	return b


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
w, d, h = BODY
top = RAIL[1] + h
for side in (-1, 1):
	box(bm, (RAIL[0], d * 1.05, RAIL[1]), (side * (w * 0.5 - RAIL[0]), 0.0, RAIL[1] * 0.5))
box(bm, (w, d, h), (0.0, 0.0, RAIL[1] + h * 0.5))
# the fan: a short open shroud standing on the top, the fan's disc low inside it (the bake darkens the well)
shroud = bmesh.ops.create_cone(bm, cap_ends=False, segments=FAN_SIDES, radius1=FAN_RADIUS, radius2=FAN_RADIUS,
	depth=FAN_DEPTH)
bmesh.ops.translate(bm, verts=shroud["verts"], vec=(0.0, 0.0, top + FAN_DEPTH * 0.5))
blades = bmesh.ops.create_circle(bm, cap_ends=True, segments=FAN_SIDES, radius=FAN_RADIUS * 0.97)
bmesh.ops.translate(bm, verts=blades["verts"], vec=(0.0, 0.0, top + 0.02))
# the guard: two bars crossing over the shroud, and the motor hub under them
for angle in (math.pi * 0.25, math.pi * 0.75):
	bar = box(bm, (FAN_RADIUS * 2.0, GUARD_BAR, GUARD_BAR), (0.0, 0.0, top + FAN_DEPTH - GUARD_BAR * 0.5))
	bmesh.ops.rotate(bm, verts=bar["verts"], cent=(0.0, 0.0, 0.0), matrix=Matrix.Rotation(angle, 3, "Z"))
hub = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=HUB[0], radius2=HUB[0], depth=HUB[1])
bmesh.ops.translate(bm, verts=hub["verts"], vec=(0.0, 0.0, top + 0.02 + HUB[1] * 0.5))
# the louvres: slats across the front and back faces
for side in (-1, 1):
	for i in range(LOUVRES):
		z = RAIL[1] + h * (0.25 + 0.5 * i / (LOUVRES - 1))
		box(bm, (w * 0.86, LOUVRE_OUT * 2.0, LOUVRE_THICK), (0.0, side * d * 0.5, z))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("ac_unit")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("ac_unit", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "ac_unit")
