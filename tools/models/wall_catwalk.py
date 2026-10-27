# Classic's wall catwalk (doc/assets/wall_catwalk/spec.md): one 8 m span of the catwalks along the tunnel's walls, its
# wall edge against the lining, a bracket down to where the wall curves in under it.
# Origin at the deck's top centre; Blender z up (Godot y up), +x toward the wall, y along the catwalk.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/wall_catwalk.py -- game/models
# Sizes in metres. Made from scratch.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the tunnel (ClassicRig): the lining's face radius (BORE_RADIUS + RIB.x / 2), its centre's height, the deck's height
LINING_RADIUS = 61.2
CENTRE_Y = 59.0
DECK_Y = 8.0
# the span: width, length, plate thickness; the edge stringers' size (wide, deep); cross bars under it every CROSS_STEP
SPAN = (3.0, 8.0, 0.05)
STRINGER = (0.1, 0.25)
CROSS_STEP = 2.0
CROSS = 0.1
# the open side: toe board height and thickness, posts every POST_STEP, rails at these heights, tube width and sides
TOE = (0.15, 0.03)
POST_STEP = 2.0
RAILS = (1.1, 0.55)
TUBE = 0.12
TUBE_SIDES = 6
# the bracket's members' size
BRACKET = 0.2


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)


def bar(bm, a, b, thick, sides=4):
	"""A bar from a to b: square (4 sides) or a scaffold tube."""
	a, b = Vector(a), Vector(b)
	d = b - a
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=thick * 0.5 * (1.414 if sides == 4 else 1.0),
		radius2=thick * 0.5 * (1.414 if sides == 4 else 1.0), depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)


def wall_x(height):
	"""Where the lining's face is, across from the deck's centre, at a height."""
	half = math.sqrt(LINING_RADIUS ** 2 - (CENTRE_Y - DECK_Y) ** 2) - SPAN[0] * 0.5
	return math.sqrt(LINING_RADIUS ** 2 - (CENTRE_Y - height) ** 2) - half


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
w, l, t = SPAN
hw, hl = w * 0.5, l * 0.5
box(bm, (w, l, t), (0.0, 0.0, -t * 0.5))
for x in (-hw + STRINGER[0] * 0.5, hw - STRINGER[0] * 0.5):
	box(bm, (STRINGER[0], l, STRINGER[1]), (x, 0.0, -t - STRINGER[1] * 0.5))
n = int(l / CROSS_STEP)
for i in range(n):
	y = -hl + CROSS_STEP * (i + 0.5)
	box(bm, (w - STRINGER[0] * 2.0, CROSS, CROSS), (0.0, y, -t - CROSS * 0.5))
# the open side (-x): toe board, posts, rails
ox = -hw + TUBE * 0.5
box(bm, (TOE[1], l, TOE[0]), (-hw + TOE[1] * 0.5, 0.0, TOE[0] * 0.5))
m = int(l / POST_STEP)
for i in range(m):
	y = -hl + POST_STEP * (i + 0.5)
	bar(bm, (ox, y, 0.0), (ox, y, RAILS[0] + TUBE * 0.5), TUBE, TUBE_SIDES)
for h in RAILS:
	bar(bm, (ox, -hl, h), (ox, hl, h), TUBE, TUBE_SIDES)
# the bracket at the span's middle: an arm under the deck out to the wall, a leg down from the open edge to the wall
# where it curves in under the deck, a brace from the leg's foot up to the arm's wall end
under = -t - STRINGER[1]
foot = DECK_Y + under
while wall_x(foot) > -hw + BRACKET * 0.5:
	foot -= 0.05
foot_z = foot - DECK_Y
leg_x = -hw + BRACKET * 0.5
bar(bm, (leg_x, 0.0, under - BRACKET * 0.5), (wall_x(DECK_Y + under), 0.0, under - BRACKET * 0.5), BRACKET)
bar(bm, (leg_x, 0.0, under), (leg_x, 0.0, foot_z), BRACKET)
bar(bm, (leg_x, 0.0, foot_z), (wall_x(DECK_Y + under), 0.0, under - BRACKET), BRACKET)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("wall_catwalk")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("wall_catwalk", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "wall_catwalk")
print("wall_catwalk leg foot", foot_z)
