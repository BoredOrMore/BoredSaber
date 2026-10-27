# Neon Grid's site props (doc/assets/site_props/spec.md): a shipping container behind on the left, concrete barriers
# and a pile of steel I-beams on the right, built where they stand around the player as one mesh (one draw call).
# Origin at the player's floor; Blender z up, Blender -y is Godot +z (behind the player), x the same.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/site_props.py -- game/models
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

# the container: centre on the floor (Godot x, z), size (width, height, length), its ribs and door bars
CONTAINER_AT = (-7.5, 4.0)
CONTAINER = (2.44, 2.59, 6.06)
RIBS = 9
RIB = (0.06, 0.12)
DOOR_BARS = 4
CORNER = 0.18
# cuts across the body's faces, for its occlusion
BODY_CUTS = 5
# the barriers: (Godot x, z, turn in degrees); length, height, foot and top width, the profile's knee height
BARRIERS = [(5.0, -2.0, 2.0), (5.2, -4.4, -4.0), (5.7, -7.0, 7.0)]
BARRIER = (2.0, 0.81, 0.61, 0.15, 0.25)
SLOT = (0.12, 0.06, 0.4)
# the beams: (Godot x, z, height of its bottom, turn in degrees, length); the I-profile (depth, width, flange, web)
BEAMS = [(9.6, -12.0, 0.0, 0.0, 12.0), (10.0, -12.3, 0.0, 1.5, 11.0), (10.4, -11.6, 0.0, -1.0, 12.0),
	(10.8, -12.1, 0.0, 0.5, 10.0), (9.9, -13.0, 0.3, 4.0, 9.0), (10.5, -12.4, 0.3, -6.0, 12.0), (10.2, -14.2, 0.6, 9.0, 11.0)]
I_BEAM = (0.3, 0.3, 0.03, 0.02)


def godot(x, z, y=0.0):
	"""A Godot position (x, y up, z) in Blender's axes."""
	return Vector((x, -z, y))


def box(bm, size, centre, rot=None):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	if rot is not None:
		bmesh.ops.rotate(bm, verts=b["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)
	return b


def container(bm):
	w, h, l = CONTAINER
	c = godot(*CONTAINER_AT, h * 0.5)
	# Blender: width along x, length along y
	body = box(bm, (w, l, h), c)
	# cut into a grid, so the baked occlusion varies across the big faces instead of taking their corners' (dark next
	# to the castings) all over
	edges = list({e for v in body["verts"] for e in v.link_edges})
	bmesh.ops.subdivide_edges(bm, edges=edges, cuts=BODY_CUTS, use_grid_fill=True)
	# corrugation: vertical ribs standing out of both long sides
	for side in (-1, 1):
		for i in range(RIBS):
			y = -l * 0.5 + l * (i + 0.5) / RIBS
			box(bm, (RIB[0], RIB[1], h * 0.86), c + Vector((side * (w * 0.5 + RIB[0] * 0.5), y, 0.0)))
	# the doors' locking bars at the end toward the track's far side (Blender -y... Godot +z: behind)
	door_y = -l * 0.5 - 0.03
	for i in range(DOOR_BARS):
		x = -w * 0.5 + w * (i + 0.5) / DOOR_BARS
		box(bm, (0.05, 0.05, h * 0.9), c + Vector((x, door_y, 0.0)))
	# corner castings
	for sx in (-1, 1):
		for sy in (-1, 1):
			for sz in (-1, 1):
				box(bm, (CORNER, CORNER, CORNER), c + Vector((sx * (w - CORNER) * 0.5, sy * (l - CORNER) * 0.5, sz * (h - CORNER) * 0.5)))


def barrier(bm, x, z, turn):
	length, height, foot, top, knee = BARRIER
	# the Jersey profile across the barrier (x across, z up), extruded along its length (y)
	profile = [(-foot * 0.5, 0.0), (foot * 0.5, 0.0), (foot * 0.5, 0.08), (top * 1.6, knee), (top * 0.5, height),
		(-top * 0.5, height), (-top * 1.6, knee), (-foot * 0.5, 0.08)]
	verts_a = [bm.verts.new((px, -length * 0.5, pz)) for px, pz in profile]
	verts_b = [bm.verts.new((px, length * 0.5, pz)) for px, pz in profile]
	faces = [bm.faces.new(verts_a[::-1]), bm.faces.new(verts_b)]
	n = len(profile)
	for i in range(n):
		faces.append(bm.faces.new((verts_a[i], verts_a[(i + 1) % n], verts_b[(i + 1) % n], verts_b[i])))
	rot = Matrix.Rotation(math.radians(turn), 3, "Z")
	verts = verts_a + verts_b
	bmesh.ops.rotate(bm, verts=verts, cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=verts, vec=godot(x, z))
	# the lifting slots: dark blocks sunk into the top near each end
	for end in (-1, 1):
		box(bm, (SLOT[0], SLOT[2], SLOT[1]), godot(x, z, height - SLOT[1] * 0.4) + rot @ Vector((0.0, end * length * 0.3, 0.0)), rot)


def i_beam(bm, x, z, bottom, turn, length):
	depth, width, flange, web = I_BEAM
	rot = Matrix.Rotation(math.radians(turn), 3, "Z")
	base = godot(x, z, bottom)
	for dz in (flange * 0.5, depth - flange * 0.5):
		box(bm, (width, length, flange), base + Vector((0.0, 0.0, dz)), rot)
	box(bm, (web, length, depth - 2.0 * flange), base + Vector((0.0, 0.0, depth * 0.5)), rot)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
container(bm)
for b in BARRIERS:
	barrier(bm, *b)
for b in BEAMS:
	i_beam(bm, *b)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("site_props")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("site_props", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "site_props")
