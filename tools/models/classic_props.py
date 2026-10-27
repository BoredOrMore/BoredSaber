# Classic's props (doc/assets/classic_props/spec.md): the crew's kit on the tunnel floor and against the right catwalk,
# uneven left and right: flight cases stacked on the left, a cable reel further on, a scissor lift on the right with
# its platform at 6 m, a ladder up to the right catwalk; built where they stand as one mesh (one draw call). And the
# tool box (its own export), one on each hanging scaffold's deck, moved with it by the rig.
# Props: origin at the player's floor; Blender z up, Blender -y is Godot +z, x the same. Tool box: origin at its foot.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/classic_props.py -- game/models
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

# the tunnel floor's top (ClassicRig FLOOR_Y)
FLOOR = -0.3
# flight cases: (Godot x, z, height of its bottom over the floor, turn in degrees, scale); size; the corner caps' size,
# the lid seam's height share and how far it stands out, the handles' size
CASES = [(-6.5, -3.0, 0.0, 4.0, 1.0), (-6.4, -3.1, 0.8, -9.0, 0.85), (-7.8, -4.2, 0.0, 17.0, 1.0)]
CASE = (1.2, 0.8, 0.8)
CAP = 0.12
SEAM = (0.7, 0.02)
HANDLE = (0.3, 0.05, 0.06)
# the cable reel: Godot x, z, turn; flange radius and thickness, the wound cable's radius, the drum's width, sides
REEL_AT = (-8.0, -12.0, 20.0)
REEL = (0.6, 0.06, 0.42, 0.6)
REEL_SIDES = 12
# the scissor lift: Godot x, z; the chassis (length along z, width, height) and its wheels (radius, width); the
# platform's height and size, the arms' stages, bar thickness, the rail's height and tube
LIFT_AT = (9.0, -16.0)
CHASSIS = (2.4, 1.2, 0.5)
WHEEL = (0.2, 0.15)
PLATFORM_Y = 6.0
PLATFORM = (2.6, 1.3, 0.2)
STAGES = 4
ARM = 0.1
LIFT_RAIL = (1.0, 0.06)
# the ladder up to the right catwalk (ClassicRig LADDER: foot on the lining's face, top at the catwalk's open edge):
# Godot foot and top (x, y), z; rail spacing and thickness, a rung every RUNG_STEP
LADDER_FOOT = (28.4, 59.0 - math.sqrt(61.2 ** 2 - 28.4 ** 2))
LADDER_TOP = (30.8, 8.0)
LADDER_Z = -30.0
LADDER = (0.5, 0.07)
RUNG_STEP = 0.35
# the tool box: length, depth, height; the lid's ridge, the handle's size
TOOL_BOX = (1.0, 0.5, 0.45)
LID = 0.05
TOOL_HANDLE = (0.4, 0.04, 0.08)


def godot(x, z, y=0.0):
	"""A Godot position (x, y up, z) in Blender's axes."""
	return Vector((x, -z, y))


def box(bm, size, centre, rot=None):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	if rot is not None:
		bmesh.ops.rotate(bm, verts=b["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)


def bar(bm, a, b, thick, sides=4):
	"""A bar from a to b: square (4 sides) or round (more)."""
	a, b = Vector(a), Vector(b)
	d = b - a
	r = thick * 0.5 * (1.414 if sides == 4 else 1.0)
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r, depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)


def disc(bm, radius, width, centre, rot, sides):
	d = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=width)
	bmesh.ops.rotate(bm, verts=d["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=d["verts"], vec=centre)


def flight_case(bm, x, z, up, turn, scale):
	w, h, d = (s * scale for s in CASE)
	rot = Matrix.Rotation(math.radians(turn), 3, "Z")
	base = godot(x, z, FLOOR + up)
	at = lambda lx, ly, lz: base + rot @ Vector((lx, ly, lz))
	box(bm, (w, d, h), at(0.0, 0.0, h * 0.5), rot)
	# the lid's seam: a band round the body
	box(bm, (w + SEAM[1] * 2.0, d + SEAM[1] * 2.0, 0.04), at(0.0, 0.0, h * SEAM[0]), rot)
	# corner caps on the top corners, a handle on each end
	c = CAP * scale
	for sx in (-1, 1):
		for sy in (-1, 1):
			box(bm, (c, c, c), at(sx * (w - c) * 0.5, sy * (d - c) * 0.5, h - c * 0.5 + 0.01), rot)
		box(bm, (HANDLE[1], HANDLE[0], HANDLE[2]), at(sx * (w * 0.5 + HANDLE[1] * 0.5), 0.0, h * 0.75), rot)


def cable_reel(bm):
	x, z, turn = REEL_AT
	r, t, wound, width = REEL
	# the reel stands on its flanges' rims, its axle along Godot z turned by `turn`
	rot = Matrix.Rotation(math.radians(turn), 3, "Z") @ Matrix.Rotation(math.pi * 0.5, 3, "X")
	axle = Matrix.Rotation(math.radians(turn), 3, "Z") @ Vector((0.0, 1.0, 0.0))
	c = godot(x, z, FLOOR + r)
	for s in (-1, 1):
		disc(bm, r, t, c + axle * s * (width - t) * 0.5, rot, REEL_SIDES)
	disc(bm, wound, width - t * 2.0, c, rot, REEL_SIDES)


def scissor_lift(bm):
	x, z = LIFT_AT
	l, w, h = CHASSIS
	base = godot(x, z, FLOOR)
	# Blender y is along the lift's length (Godot z)
	box(bm, (w, l, h), base + Vector((0.0, 0.0, WHEEL[0] + h * 0.5)))
	wheel = Matrix.Rotation(math.pi * 0.5, 3, "Y")
	for sx in (-1, 1):
		for sy in (-1, 1):
			disc(bm, WHEEL[0], WHEEL[1], base + Vector((sx * (w * 0.5 - WHEEL[1] * 0.5), sy * (l * 0.5 - 0.35), WHEEL[0])),
				wheel, 6)
	top = PLATFORM_Y - PLATFORM[2]
	bottom = WHEEL[0] + h
	pl, pw = PLATFORM[0], PLATFORM[1]
	box(bm, (pw, pl, PLATFORM[2]), base + Vector((0.0, 0.0, PLATFORM_Y - PLATFORM[2] * 0.5)))
	# the arms: crossed pairs on both long sides, STAGES of them between the chassis and the platform
	step = (top - bottom) / STAGES
	reach = l * 0.42
	for sx in (-1, 1):
		ax = sx * (w * 0.5 - ARM)
		for i in range(STAGES):
			z0, z1 = bottom + step * i, bottom + step * (i + 1)
			bar(bm, base + Vector((ax, -reach, z0)), base + Vector((ax, reach, z1)), ARM)
			bar(bm, base + Vector((ax, reach, z0)), base + Vector((ax, -reach, z1)), ARM)
	# the platform's rail: four posts and a top rail round it
	rh, rt = LIFT_RAIL
	corners = [(-pw * 0.5, -pl * 0.5), (pw * 0.5, -pl * 0.5), (pw * 0.5, pl * 0.5), (-pw * 0.5, pl * 0.5)]
	for cx, cy in corners:
		bar(bm, base + Vector((cx, cy, PLATFORM_Y)), base + Vector((cx, cy, PLATFORM_Y + rh)), rt, 6)
	for (x0, y0), (x1, y1) in zip(corners, corners[1:] + corners[:1]):
		bar(bm, base + Vector((x0, y0, PLATFORM_Y + rh)), base + Vector((x1, y1, PLATFORM_Y + rh)), rt, 6)


def ladder(bm):
	foot, top = Vector((LADDER_FOOT[0], 0.0, LADDER_FOOT[1])), Vector((LADDER_TOP[0], 0.0, LADDER_TOP[1]))
	foot.y = top.y = -LADDER_Z
	d = top - foot
	for s in (-1, 1):
		o = Vector((0.0, s * LADDER[0] * 0.5, 0.0))
		bar(bm, foot + o, top + o + d.normalized() * 0.9, LADDER[1])
	rungs = int(d.length / RUNG_STEP)
	for i in range(1, rungs):
		p = foot + d * (i / rungs)
		bar(bm, p - Vector((0.0, LADDER[0] * 0.5, 0.0)), p + Vector((0.0, LADDER[0] * 0.5, 0.0)), LADDER[1] * 0.7)


def export(bm, name):
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, OUT_DIR, name)
	bpy.data.objects.remove(obj)


def tool_box():
	bm = bmesh.new()
	l, d, h = TOOL_BOX
	box(bm, (l, d, h - LID), (0.0, 0.0, (h - LID) * 0.5))
	box(bm, (l + 0.04, d + 0.04, LID), (0.0, 0.0, h - LID * 0.5))
	for s in (-1, 1):
		box(bm, (TOOL_HANDLE[1], TOOL_HANDLE[1], TOOL_HANDLE[2]), (s * TOOL_HANDLE[0] * 0.5, 0.0, h + TOOL_HANDLE[2] * 0.5))
	box(bm, (TOOL_HANDLE[0] + TOOL_HANDLE[1], TOOL_HANDLE[1], TOOL_HANDLE[1]), (0.0, 0.0, h + TOOL_HANDLE[2]))
	export(bm, "tool_box")


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
for c in CASES:
	flight_case(bm, *c)
cable_reel(bm)
scissor_lift(bm)
ladder(bm)
export(bm, "classic_props")
tool_box()
