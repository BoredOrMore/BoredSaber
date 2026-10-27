# Classic's tunnel parts (doc/assets/tunnel_parts/spec.md): a rib segment (one of the 24 pieces round a rib ring) and a
# lining panel (the plate between two ribs), repeated about 1,100 times along the bore, so both stay lean.
# Both at their box's centre: x along the ring, Blender z toward the tunnel's axis (Godot y), Blender y along the bore.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/tunnel_parts.py -- game/models
# Sizes in metres. Made from scratch.
import math
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# a ring segment's length along the ring (ClassicRig: TAU * BORE_RADIUS / RIB_SEGMENTS * 1.06)
LENGTH = math.tau * 60.0 / 24 * 1.06
# rib: depth toward the axis, width along the bore (ClassicRig RIB), the flange's thickness, the web's width
RIB = (2.4, 3.0)
FLANGE = 0.3
WEB = 0.8
# the splice plate at the segment's +x end: thickness along the ring, how far it stands past the T on every side
SPLICE = (0.5, 0.15)
# lining panel: thickness (ClassicRig LINING), width along the bore (RIB_STEP), the bevelled edge's inset and drop
LINING = (0.3, 25.0)
BEVEL = (0.6, 0.06)


def prism(bm, profile, length):
	"""The profile (y, z points round it) run along x from -length/2 to length/2, open at both ends (the next segment
	covers them)."""
	a = [bm.verts.new((-length * 0.5, y, z)) for y, z in profile]
	b = [bm.verts.new((length * 0.5, y, z)) for y, z in profile]
	n = len(profile)
	caps = [bm.faces.new(a[::-1]), bm.faces.new(b)]
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bmesh.ops.delete(bm, geom=caps, context="FACES_ONLY")


def export(bm, name):
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, OUT_DIR, name)
	bpy.data.objects.remove(obj)


def rib():
	bm = bmesh.new()
	d, w = RIB
	top, under = d * 0.5, d * 0.5 - FLANGE
	# the T: the flange facing the axis, the web behind it down to the lining
	prism(bm, [(-w * 0.5, top), (w * 0.5, top), (w * 0.5, under), (WEB * 0.5, under), (WEB * 0.5, -d * 0.5),
		(-WEB * 0.5, -d * 0.5), (-WEB * 0.5, under), (-w * 0.5, under)], LENGTH)
	s = bmesh.ops.create_cube(bm, size=1.0)
	o = SPLICE[1]
	bmesh.ops.scale(bm, verts=s["verts"], vec=(SPLICE[0], w + o * 2.0, d + o))
	bmesh.ops.translate(bm, verts=s["verts"], vec=(LENGTH * 0.5 - SPLICE[0] * 0.5, 0.0, o * 0.5))
	export(bm, "tunnel_rib")


def lining():
	bm = bmesh.new()
	hx, hy = LENGTH * 0.5, LINING[1] * 0.5
	face, edge = LINING[0] * 0.5, LINING[0] * 0.5 - BEVEL[1]
	ix, iy = hx - BEVEL[0], hy - BEVEL[0]
	outer = [bm.verts.new(p) for p in ((-hx, -hy, edge), (hx, -hy, edge), (hx, hy, edge), (-hx, hy, edge))]
	inner = [bm.verts.new(p) for p in ((-ix, -iy, face), (ix, -iy, face), (ix, iy, face), (-ix, iy, face))]
	# the face toward the axis (+z) and the bevel round it, wound to face +z; the back is never seen
	bm.faces.new(inner)
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((outer[i], outer[j], inner[j], inner[i]))
	export(bm, "tunnel_lining")


bpy.ops.wm.read_factory_settings(use_empty=True)
rib()
lining()
