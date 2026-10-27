# Neon Grid's arch parts (doc/assets/arch_parts/spec.md): the arch section (a unit piece the rig scales along each
# arch), the footing where a leg meets the grid, and the scaffold round arch C's unfinished end.
# Section: x across, y toward the arch's middle (Blender y, Godot -z... the rig maps it), z along the curve, -0.5..0.5.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/arch_parts.py -- game/models
# Sizes: the section and footing in units of their scale, the scaffold in metres. Made from scratch.
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# section: the flange ring at the +z end (how far it stands out, how thick along z), the seam (inset, width), the outer
# face's ribs (where across, how far out, how wide) and the brace's thickness
FLANGE = (0.06, 0.05)
SEAM = (0.02, 0.025)
RIBS_X = (-0.3, 0.3)
RIB = (0.06, 0.1)
BRACE = 0.07
# footing: the plinth's two steps (size, height) and the bearing plate, in units of the leg's section
STEPS = [(2.2, 0.35), (1.6, 0.35)]
PLATE = (1.15, 0.06)
# scaffold: size (across, along, height), levels, tube thickness, platform thickness; the open side is -x
SCAFFOLD = (22.0, 30.0, 40.0)
LEVELS = 4
TUBE = 0.6
DECK = 0.5


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


def export(bm, name):
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, OUT_DIR, name)
	bpy.data.objects.remove(obj)


def section():
	bm = bmesh.new()
	# the body in two halves either side of the seam (the seam a narrower band between them)
	half = 0.5 - SEAM[1] * 0.5
	for sz in (-1, 1):
		box(bm, (1.0, 1.0, half), (0.0, 0.0, sz * (SEAM[1] * 0.5 + half * 0.5)))
	box(bm, (1.0 - SEAM[0] * 2.0, 1.0 - SEAM[0] * 2.0, SEAM[1]), (0.0, 0.0, 0.0))
	# the flange at the +z end
	box(bm, (1.0 + FLANGE[0] * 2.0, 1.0 + FLANGE[0] * 2.0, FLANGE[1]), (0.0, 0.0, 0.5 - FLANGE[1] * 0.5))
	# on the outer face (-y): two ribs along the length and a diagonal brace between them
	outer = -0.5 - RIB[0] * 0.5
	for x in RIBS_X:
		box(bm, (RIB[1], RIB[0], 1.0), (x, outer, 0.0))
	strut(bm, (RIBS_X[0], outer, -0.45), (RIBS_X[1], outer, 0.45), BRACE)
	export(bm, "arch_section")


def footing():
	bm = bmesh.new()
	z = 0.0
	for size, height in STEPS:
		box(bm, (size, size, height), (0.0, 0.0, z + height * 0.5))
		z += height
	box(bm, (PLATE[0], PLATE[0], PLATE[1]), (0.0, 0.0, z + PLATE[1] * 0.5))
	export(bm, "arch_footing")


def scaffold():
	bm = bmesh.new()
	w, l, h = SCAFFOLD
	corners = [(-w * 0.5, -l * 0.5), (w * 0.5, -l * 0.5), (w * 0.5, l * 0.5), (-w * 0.5, l * 0.5)]
	for x, y in corners:
		box(bm, (TUBE, TUBE, h), (x, y, h * 0.5))
	step = h / LEVELS
	for i in range(1, LEVELS + 1):
		z = i * step
		# ledgers round three sides (the -x side, where the crane reaches over, stays open above the first level)
		for (x0, y0), (x1, y1) in zip(corners, corners[1:] + corners[:1]):
			if x0 == x1 == -w * 0.5 and i > 1:
				continue
			strut(bm, (x0, y0, z), (x1, y1, z), TUBE)
		# a working platform on every other level, not the same side each time
		if i % 2 == 1:
			side = 1 if i % 4 == 1 else -1
			box(bm, (w * 0.45, l, DECK), (side * w * 0.25, 0.0, z - DECK * 0.5))
	# diagonal braces on the two long faces, zigzagging up
	for y in (-l * 0.5, l * 0.5):
		for i in range(LEVELS):
			flip = 1 if i % 2 == 0 else -1
			strut(bm, (-w * 0.5 * flip, y, i * step), (w * 0.5 * flip, y, (i + 1) * step), TUBE * 0.8)
	export(bm, "arch_scaffold")


bpy.ops.wm.read_factory_settings(use_empty=True)
section()
footing()
scaffold()
