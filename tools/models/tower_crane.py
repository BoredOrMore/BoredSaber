# The tower crane on Neon Grid's arch C (doc/assets/tower_crane/spec.md): a hammerhead crane building the arch's
# unfinished end. Seen from 450-800 m, so the lattice is suggested: solid cores with corner chords and a few diagonals.
# Origin at the mast's foot; Blender z up (Godot y up); the jib reaches toward -x (the track).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/tower_crane.py -- game/models
# Sizes in metres. Made from scratch.
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the mast: height, width; its core's share of the width; the corner chords' thickness; braced sections
MAST = (30.0, 2.4)
MAST_CORE = 0.55
CHORD = 0.35
MAST_SECTIONS = 4
# the jib and counter-jib (length toward -x, toward +x), their depth and width
JIB = (70.0, 22.0)
JIB_DEPTH = 2.0
JIB_WIDTH = 1.6
JIB_SECTIONS = 6
# the slewing unit at the mast's top, the cab beside it (on the -y side), the apex above, the counterweights
SLEW = (3.2, 3.2, 1.6)
CAB = (2.2, 2.0, 2.4)
APEX = 8.0
COUNTERWEIGHT = (5.0, 2.4, 3.0)
# the trolley on the jib (its place along it, 0-1) and the hook block on its cable
TROLLEY = 0.65
CABLE = 14.0
HOOK = (1.2, 1.2, 1.6)


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
h, w = MAST
r = w * 0.5 - CHORD * 0.5
# the mast: a dark core, four corner chords, a diagonal on each face of every section (alternating, so it zigzags)
box(bm, (w * MAST_CORE, w * MAST_CORE, h), (0.0, 0.0, h * 0.5))
for x, y in ((r, r), (-r, r), (-r, -r), (r, -r)):
	box(bm, (CHORD, CHORD, h), (x, y, h * 0.5))
step = h / MAST_SECTIONS
for i in range(MAST_SECTIONS):
	z0, z1 = i * step, (i + 1) * step
	flip = 1 if i % 2 == 0 else -1
	strut(bm, (-r * flip, -r, z0), (r * flip, -r, z1), CHORD * 0.7)
	strut(bm, (r, -r * flip, z0), (r, r * flip, z1), CHORD * 0.7)
top = h
# the slewing unit and the cab on one side
box(bm, SLEW, (0.0, 0.0, top + SLEW[2] * 0.5))
box(bm, CAB, (-SLEW[0] * 0.5 - CAB[0] * 0.3, -SLEW[1] * 0.5 - CAB[1] * 0.5, top + CAB[2] * 0.5))
jib_z = top + SLEW[2] + JIB_DEPTH * 0.5
# the jib and counter-jib: a core, top and bottom chords, a few diagonals on the near face
for length, sign, sections in ((JIB[0], -1, JIB_SECTIONS), (JIB[1], 1, 2)):
	box(bm, (length, JIB_WIDTH * 0.5, JIB_DEPTH * 0.5), (sign * length * 0.5, 0.0, jib_z))
	for dz in (-1, 1):
		box(bm, (length, CHORD, CHORD), (sign * length * 0.5, -JIB_WIDTH * 0.5, jib_z + dz * JIB_DEPTH * 0.5))
	seg = length / sections
	for i in range(sections):
		x0, x1 = sign * i * seg, sign * (i + 1) * seg
		dz = 1 if i % 2 == 0 else -1
		strut(bm, (x0, -JIB_WIDTH * 0.5, jib_z - dz * JIB_DEPTH * 0.5), (x1, -JIB_WIDTH * 0.5, jib_z + dz * JIB_DEPTH * 0.5), CHORD * 0.6)
# the counterweights at the counter-jib's end
box(bm, COUNTERWEIGHT, (JIB[1] - COUNTERWEIGHT[0] * 0.5, 0.0, jib_z - JIB_DEPTH * 0.5 - COUNTERWEIGHT[2] * 0.5))
# the apex and its tie bars to the jib and counter-jib
apex = (0.0, 0.0, jib_z + APEX)
box(bm, (CHORD * 2.0, CHORD * 2.0, APEX), (0.0, 0.0, jib_z + APEX * 0.5))
strut(bm, apex, (-JIB[0] * 0.6, 0.0, jib_z + JIB_DEPTH * 0.5), CHORD * 0.5)
strut(bm, apex, (JIB[1], 0.0, jib_z + JIB_DEPTH * 0.5), CHORD * 0.5)
# the trolley, the cable and the hook block
tx = -JIB[0] * TROLLEY
box(bm, (2.0, JIB_WIDTH, 0.6), (tx, 0.0, jib_z - JIB_DEPTH * 0.5 - 0.3))
strut(bm, (tx, 0.0, jib_z - JIB_DEPTH * 0.5 - 0.6), (tx, 0.0, jib_z - JIB_DEPTH * 0.5 - 0.6 - CABLE), 0.12)
box(bm, HOOK, (tx, 0.0, jib_z - JIB_DEPTH * 0.5 - 0.6 - CABLE - HOOK[2] * 0.5))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("tower_crane")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("tower_crane", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "tower_crane")
