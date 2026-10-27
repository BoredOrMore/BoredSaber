# Pulse Void's props (doc/assets/dish_props/spec.md): the dish crew's kit, uneven left and right: a control room on the
# ground outside the rim ahead left, a panel repair gondola hung over the dish from the front-right mast, the calibration
# laser station at the bridge's end on the front rim (the drop's beam leaves it), and a cable tray down the front-right
# feed leg; built where they stand as one mesh (one draw call).
# Origin at the player's floor; Blender z up, Blender -y is Godot +z, x the same. The dish and leg numbers repeat
# PulseVoid's (dish_y, the legs' ends).
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/dish_props.py -- game/models
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

# the dish (PulseVoid VERTEX_Y, focal length a quarter of 500 m)
VERTEX_Y = -125.0
# the control room, on the ground outside the rim on the left, as real ones stand off the dish (owner, 2026-10-27): Godot
# x, z of its middle (286 m out); size (along x, high, along z), the ground's height (the rim's) and its foundation's
# depth, the window band (its share up the wall, height, frames), roof overhang, the roof unit
ROOM_AT = (-170.0, -230.0)
ROOM = (14.0, 6.0, 10.0)
GROUND = 0.0
BASE_DEPTH = 1.0
WINDOWS = (0.55, 1.4, 5)
FRAME = 0.15
ROOF = 0.4
ROOF_UNIT = (3.0, 1.2, 2.0)
# the panel repair gondola, hung by a cable from the front-right mast's top (PulseVoid: masts MAST_R out, MAST high, the
# front ones 20 degrees off ahead) over the dish: Godot x, z, its height over the panels; basket size, rail height
MAST_R = 258.0
MAST = 40.0
MAST_DEG = 20.0
GONDOLA_AT = (75.0, -185.0)
GONDOLA_ABOVE = 4.0
BASKET = (3.0, 1.4, 1.2)
BASKET_RAIL = 1.0
# the calibration laser station on the front rim, on the track's centre line past the bridge's end, so the drop's beam
# rises in the middle of the view: Godot x, z, its hut (along x,
# high, along z) on the rim ring's top (PulseVoid RIM_TOP), the laser's turret (radius, height); the drop's beam leaves
# its top (PulseVoid STATION)
STATION_AT = (0.0, -256.0)
RIM_TOP = 0.5
HUT = (6.0, 3.5, 5.0)
TURRET = (1.0, 1.2)
# the cable tray down the front-right leg (PulseVoid leg 0: from the 6 m cabin's underside corner, -7.4 m, to the dish
# 200 m out at 45 degrees), beside it (the leg's half width and the tray's); the tray's width, its lips, the cable
# bundle's radius, a bracket to the leg every BRACKET_STEP
LEG_TOP = (3.0 * math.sqrt(0.5), -7.4, -3.0 * math.sqrt(0.5))
LEG_REACH = 200.0
TRAY_SIDE = 1.25 + 0.8
TRAY = (0.8, 0.15)
CABLES = 0.25
BRACKET_STEP = 40.0


def dish_y(r):
	return VERTEX_Y + r * r / (4.0 * -VERTEX_Y)


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
	a, b = Vector(a), Vector(b)
	d = b - a
	r = thick * 0.5 * (1.414 if sides == 4 else 1.0)
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r, depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)


def control_room(bm):
	x, z = ROOM_AT
	w, h, d = ROOM
	floor, low = GROUND, GROUND - BASE_DEPTH
	c = godot(x, z)
	# its foundation and the room on it
	box(bm, (w, d, floor - low), c + Vector((0.0, 0.0, (floor + low) * 0.5)))
	box(bm, (w, d, h), c + Vector((0.0, 0.0, floor + h * 0.5)))
	box(bm, (w + ROOF * 2.0, d + ROOF * 2.0, ROOF), c + Vector((0.0, 0.0, floor + h + ROOF * 0.5)))
	box(bm, ROOF_UNIT, c + Vector((w * 0.2, 0.0, floor + h + ROOF + ROOF_UNIT[2] * 0.5)))
	# window frames along the face toward the track (+x, Godot) and its front (-z)
	share, wh, n = WINDOWS
	wy = floor + h * share
	for i in range(n):
		t = (i + 0.5) / n
		box(bm, (FRAME * 2.0, d * 0.8 / n, wh), c + Vector((w * 0.5 + FRAME * 0.5, (t - 0.5) * d * 0.8, wy)))
	for i in range(n - 2):
		t = (i + 0.5) / (n - 2)
		box(bm, (w * 0.8 / n, FRAME * 2.0, wh), c + Vector(((t - 0.5) * w * 0.6, d * 0.5 + FRAME * 0.5, wy)))


def gondola(bm):
	x, z = GONDOLA_AT
	p = godot(x, z, dish_y(math.hypot(x, z)) + GONDOLA_ABOVE)
	bw, bd, bh = BASKET
	box(bm, (bw, bd, bh), p + Vector((0.0, 0.0, bh * 0.5)))
	for sx in (-1, 1):
		for sy in (-1, 1):
			c = p + Vector((sx * bw * 0.5, sy * bd * 0.5, bh))
			bar(bm, c, c + Vector((0.0, 0.0, BASKET_RAIL)), 0.06)
	rim = [p + Vector((sx * bw * 0.5, sy * bd * 0.5, bh + BASKET_RAIL)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	for i in range(4):
		bar(bm, rim[i], rim[(i + 1) % 4], 0.06)
	# the hanger over the basket and the cable up to the mast's top
	hook = p + Vector((0.0, 0.0, bh + BASKET_RAIL + 2.0))
	for sx in (-1, 1):
		bar(bm, p + Vector((sx * bw * 0.5, 0.0, bh + BASKET_RAIL)), hook, 0.08)
	a = math.radians(MAST_DEG)
	top = godot(math.sin(a) * MAST_R, -math.cos(a) * MAST_R, MAST)
	bar(bm, hook, top, 0.12)


def station(bm):
	x, z = STATION_AT
	c = godot(x, z, RIM_TOP)
	box(bm, HUT, c + Vector((0.0, 0.0, HUT[1] * 0.5)))
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=TURRET[0], radius2=TURRET[0] * 0.7, depth=TURRET[1])
	bmesh.ops.translate(bm, verts=t["verts"], vec=c + Vector((0.0, 0.0, HUT[1] + TURRET[1] * 0.5)))


def cable_tray(bm):
	a = math.radians(45.0)
	top = godot(*LEG_TOP[::2], LEG_TOP[1])
	foot = godot(math.sin(a) * LEG_REACH, -math.cos(a) * LEG_REACH, dish_y(LEG_REACH))
	side = godot(math.sqrt(0.5), math.sqrt(0.5)) * TRAY_SIDE
	a0, a1 = top + side, foot + side
	d = (a1 - a0).normalized()
	across = side.normalized()
	up = d.cross(across).normalized()
	if up.z < 0.0:
		up = -up
	# the tray: a channel (floor and two lips) and the cable bundle in it
	bar(bm, a0, a1, 0.05)
	for s in (-1, 1):
		o = across * s * TRAY[0] * 0.5 + up * TRAY[1] * 0.5
		bar(bm, a0 + o, a1 + o, 0.05)
	bar(bm, a0 + up * CABLES, a1 + up * CABLES, CABLES * 2.0, 6)
	n = int((a1 - a0).length / BRACKET_STEP)
	for i in range(1, n + 1):
		p = a0.lerp(a1, i / (n + 1))
		bar(bm, p - side, p, 0.12)


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
control_room(bm)
gondola(bm)
station(bm)
cable_tray(bm)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("dish_props")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("dish_props", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "dish_props")
