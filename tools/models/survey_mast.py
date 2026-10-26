# The survey mast with its beacon (doc/assets/survey_mast/spec.md): Neon Grid's site masts along the left, the left
# waving lasers' fixtures on top. Modelled 10 m tall; the rig scales each copy to its height.
# Origin at the base; Blender z up (Godot y up).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/survey_mast.py -- game/models
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

HEIGHT = 10.0
# the pole's width in its three sections, bottom to top, and where the joints are
POLE = (0.22, 0.18, 0.14)
JOINTS = (3.5, 7.0)
BASE = (1.0, 0.08)
# the guys: from this high, to anchors this far out, at these angles (degrees; not evenly round), this thick
GUY_FROM = 7.0
GUY_OUT = 4.0
GUY_ANGLES = (20.0, 140.0, 250.0)
GUY_THICK = 0.04
# the beacon: collar and housing (width, height)
COLLAR = (0.1, 0.3)
BEACON = (0.45, 0.4)
# the junction box (size, height up the pole, side) and the solar panel (size, height, tilt)
JUNCTION = (0.35, 0.45, 0.2)
JUNCTION_Z = 1.4
PANEL = (0.8, 0.05, 0.6)
PANEL_Z = 5.0
PANEL_TILT = 35.0


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)
	return b


def strut(bm, a, b, thick):
	"""A square bar from a to b."""
	a, b = Vector(a), Vector(b)
	d = b - a
	s = box(bm, (thick, thick, d.length), (0.0, 0.0, 0.0))
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=s["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=s["verts"], vec=(a + b) * 0.5)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
box(bm, (BASE[0], BASE[0], BASE[1]), (0.0, 0.0, BASE[1] * 0.5))
bounds = (0.0,) + JOINTS + (HEIGHT - COLLAR[1] - BEACON[1],)
for i, width in enumerate(POLE):
	z0, z1 = bounds[i], bounds[i + 1]
	box(bm, (width, width, z1 - z0), (0.0, 0.0, (z0 + z1) * 0.5))
for angle in GUY_ANGLES:
	a = math.radians(angle)
	strut(bm, (0.0, 0.0, GUY_FROM), (GUY_OUT * math.cos(a), GUY_OUT * math.sin(a), 0.0), GUY_THICK)
top = bounds[-1]
box(bm, (COLLAR[0], COLLAR[0], COLLAR[1]), (0.0, 0.0, top + COLLAR[1] * 0.5))
beacon = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=BEACON[0] * 0.5, radius2=BEACON[0] * 0.4,
	depth=BEACON[1])
bmesh.ops.translate(bm, verts=beacon["verts"], vec=(0.0, 0.0, top + COLLAR[1] + BEACON[1] * 0.5))
box(bm, JUNCTION, (POLE[0] * 0.5 + JUNCTION[2] * 0.5, 0.0, JUNCTION_Z))
panel = box(bm, PANEL, (0.0, -POLE[1] * 0.5 - 0.35, PANEL_Z))
bmesh.ops.rotate(bm, verts=panel["verts"], cent=(0.0, -POLE[1] * 0.5 - 0.35, PANEL_Z),
	matrix=Matrix.Rotation(math.radians(PANEL_TILT), 3, "X"))
strut(bm, (0.0, 0.0, PANEL_Z), (0.0, -POLE[1] * 0.5 - 0.3, PANEL_Z), 0.05)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("survey_mast")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("survey_mast", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "survey_mast")
