# The rooftop water tank (doc/assets/water_tank/spec.md): clutter on Night City's low roofs, a familiar-size cue.
# A barrel tank on a steel stand (four legs and a ring beam) with a conical lid, as on New York's roofs.
# Origin at the stand's feet, on the roof; Blender z up (Godot y up).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/water_tank.py -- game/models
# Sizes in metres. Made from scratch.
import math
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

TANK_RADIUS = 1.3
TANK_HEIGHT = 2.8
LID_HEIGHT = 0.7
STAND_HEIGHT = 2.0
SIDES = 12
LEG = 0.14
# the legs stand this far out from the middle, at the barrel's edge
LEG_OUT = 1.05
RING_BEAM = 0.18

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
# the barrel, closed at the bottom, sitting on the stand
barrel = bmesh.ops.create_cone(bm, cap_ends=True, segments=SIDES, radius1=TANK_RADIUS, radius2=TANK_RADIUS,
	depth=TANK_HEIGHT)
bmesh.ops.translate(bm, verts=barrel["verts"], vec=(0.0, 0.0, STAND_HEIGHT + TANK_HEIGHT * 0.5))
# the lid
lid = bmesh.ops.create_cone(bm, cap_ends=True, segments=SIDES, radius1=TANK_RADIUS * 1.05, radius2=0.08,
	depth=LID_HEIGHT)
bmesh.ops.translate(bm, verts=lid["verts"], vec=(0.0, 0.0, STAND_HEIGHT + TANK_HEIGHT + LID_HEIGHT * 0.5))
# the legs and the ring beam under the barrel
for i in range(4):
	a = math.pi * 0.25 + i * math.pi * 0.5
	leg = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=leg["verts"], vec=(LEG, LEG, STAND_HEIGHT))
	bmesh.ops.translate(bm, verts=leg["verts"], vec=(LEG_OUT * math.cos(a), LEG_OUT * math.sin(a), STAND_HEIGHT * 0.5))
ring = bmesh.ops.create_cone(bm, cap_ends=True, segments=SIDES, radius1=TANK_RADIUS * 0.95, radius2=TANK_RADIUS * 0.95,
	depth=RING_BEAM)
bmesh.ops.translate(bm, verts=ring["verts"], vec=(0.0, 0.0, STAND_HEIGHT - RING_BEAM * 0.5))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("water_tank")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("water_tank", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "water_tank")
