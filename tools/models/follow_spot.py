# Classic's follow spot (doc/assets/follow_spot/spec.md): the light the waving lasers leave from on the wall catwalks,
# a long can on a yoke on a tripod. Two parts, as LaserFixtures moves them (like laser_fixture.py):
#  - follow_spot.glb, the head: the barrel with the lens recessed at its front, the lamp housing at the back, a handle
#    on top. Origin at the tilt axis (the barrel's balance point); the lens faces Godot's -z, the way the beam runs.
#  - follow_spot_stand.glb, the stand: the yoke's arms up to the tilt axis either side, its post down to a collar and
#    three tripod legs to the catwalk's deck, PIVOT under the axis. Same origin; it only turns around the vertical.
# Vertex colours: red is baked ambient occlusion, green marks the lens (1) for LaserFixture.gdshader (model_export.py).
# Run headless: blender -b -P tools/models/follow_spot.py -- game/models
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

# the barrel: radius, length (Blender +y is the front, Godot -z), sides; the lens's recess from the front
RADIUS = 0.18
LENGTH = 1.0
SIDES = 12
RECESS = 0.04
# the lamp housing at the back (across, along, high), the handle on top (posts' height, bar thickness)
HOUSING = (0.3, 0.2, 0.3)
HANDLE = (0.1, 0.04)
# the stand: the tilt axis's height above the deck (ClassicRig FOLLOW_SPOT_PIVOT), the yoke's arms (thick, deep) and the
# gap to the barrel, the yoke's bottom under the axis, the collar's height over the deck, the legs' spread, tube width
PIVOT = 1.5
ARM = (0.05, 0.1)
ARM_GAP = 0.03
YOKE_BOTTOM = -0.3
COLLAR = 0.5
SPREAD = 0.6
TUBE = 0.06


def box(bm, size, centre):
	b = bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=b["verts"], vec=size)
	bmesh.ops.translate(bm, verts=b["verts"], vec=centre)
	return b


def bar(bm, a, b, thick, sides=6):
	a, b = Vector(a), Vector(b)
	d = b - a
	t = bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=thick * 0.5, radius2=thick * 0.5, depth=d.length)
	rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=t["verts"], cent=(0.0, 0.0, 0.0), matrix=rot)
	bmesh.ops.translate(bm, verts=t["verts"], vec=(a + b) * 0.5)
	return t


def export(bm, name):
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, OUT_DIR, name)
	bpy.data.objects.remove(obj)


def head():
	bm = bmesh.new()
	glow = bm.faces.layers.int.new("glow")
	half = LENGTH * 0.5
	# the barrel, open at the front, closed at the back
	bar(bm, (0.0, -half, 0.0), (0.0, half, 0.0), RADIUS * 2.0, SIDES)
	front = [f for f in bm.faces if len(f.verts) == SIDES and f.calc_center_median().y > half - 1e-4]
	bmesh.ops.delete(bm, geom=front, context="FACES_ONLY")
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	# the lens, a disc facing the front just inside the barrel
	lens = bmesh.ops.create_circle(bm, cap_ends=True, segments=SIDES, radius=RADIUS * 0.92)
	bmesh.ops.rotate(bm, verts=lens["verts"], cent=(0.0, 0.0, 0.0),
		matrix=Vector((0.0, 0.0, 1.0)).rotation_difference(Vector((0.0, 1.0, 0.0))).to_matrix())
	bmesh.ops.translate(bm, verts=lens["verts"], vec=(0.0, half - RECESS, 0.0))
	for f in {f for v in lens["verts"] for f in v.link_faces}:
		f[glow] = 1
		if f.normal.y < 0.0:
			f.normal_flip()
	box(bm, (HOUSING[0], HOUSING[1], HOUSING[2]), (0.0, -half - HOUSING[1] * 0.5, 0.0))
	# the handle: two posts on top and a bar between
	top = RADIUS + HANDLE[0]
	for y in (-half * 0.5, half * 0.5):
		box(bm, (HANDLE[1], HANDLE[1], HANDLE[0]), (0.0, y, RADIUS + HANDLE[0] * 0.5))
	box(bm, (HANDLE[1], half + HANDLE[1], HANDLE[1]), (0.0, 0.0, top))
	export(bm, "follow_spot")


def stand():
	bm = bmesh.new()
	x = RADIUS + ARM_GAP + ARM[0] * 0.5
	for s in (-1, 1):
		box(bm, (ARM[0], ARM[1], -YOKE_BOTTOM + ARM[0]), (s * x, 0.0, YOKE_BOTTOM * 0.5 + ARM[0] * 0.5))
	box(bm, (x * 2.0 + ARM[0], ARM[1], ARM[0]), (0.0, 0.0, YOKE_BOTTOM))
	collar = COLLAR - PIVOT
	bar(bm, (0.0, 0.0, YOKE_BOTTOM), (0.0, 0.0, collar), TUBE)
	box(bm, (TUBE * 2.0, TUBE * 2.0, 0.1), (0.0, 0.0, collar))
	for i in range(3):
		a = math.tau * i / 3.0
		bar(bm, (0.0, 0.0, collar), (SPREAD * math.sin(a), SPREAD * math.cos(a), -PIVOT), TUBE)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	export(bm, "follow_spot_stand")


bpy.ops.wm.read_factory_settings(use_empty=True)
head()
stand()
