# The Metal Factory's machinery walls (doc/assets/wall_kit/spec.md): a kit of pieces set against the side walls'
# inner face, which the rig repeats along the hall (MetalFactoryRig.gd):
#  - wall_column.glb: an I-beam column, floor to ceiling, at every 8 m.
#  - wall_panel.glb: a framed panel set in the wall above the catwalk, with horizontal vent louvers (the vents are
#    where the "breathing" light can show later).
#  - wall_pipes.glb: three pipes side by side along the wall between two columns, on two brackets, run under the
#    catwalk (they clear the tall machine's tank below it and the catwalk above).
#  - wall_machine.glb, wall_machine_low.glb: a generator on the floor against the wall: plinth, body, ribs on its front,
#    a tank on top piped back to the wall; tall and low.
# Every piece's back is against the wall at x 0 and its front faces +x (Blender and Godot alike; the right wall's
# copies are turned half round); y in Blender (Godot -z) runs along the hall; origins at the back, centred along the
# hall, at the piece's foot (the pipes: at the bundle's middle).
# Vertex colours: red is baked ambient occlusion (model_export.py). Hard metal: flat shading.
# Run headless: blender -b -P tools/models/wall_kit.py -- game/models
# Sizes in metres, from the approved blockout (MetalFactoryRig.gd WALL_*, LEDGE_*, MACHINE_*). Made from scratch; no
# outside assets.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# column: height (floor to the ceiling slab), flange width and thickness, web thickness, depth out from the wall,
# base plate (side, thickness)
COLUMN = (19.0, 0.8, 0.12, 0.14, 0.6)
COLUMN_BASE = (1.0, 0.2)
# panel: width along the hall, height, frame bar width and depth, back plate thickness; louvers (count, length, height,
# depth) spread over the middle of the panel
PANEL = (7.2, 7.6, 0.4, 0.35, 0.1)
LOUVERS = (4, 6.0, 0.25, 0.2)
# pipes: radius, sides, length (one bay); their centres' distances out from the wall; brackets (thickness along the
# hall, offset from the middle)
PIPE = (0.3, 8, 8.0)
PIPE_OUTS = (0.4, 1.1, 1.8)
BRACKET = (0.2, 3.0)
# machine: depth out from the wall, length along the hall, plinth height; body inset and top; ribs (count, width,
# depth); tank radius (its axle along the hall, its top MACHINE_TANK_GAP above the body)
MACHINE = (3.0, 4.0, 0.4)
MACHINE_BODY_INSET = 0.2
MACHINE_TOPS = {"wall_machine": 4.4, "wall_machine_low": 2.6}
RIBS = (3, 0.25, 0.15)
TANK = (0.8, 8)


def box(bm, lo, hi):
	"""Adds a box between corners lo and hi (Blender axes)."""
	result = bmesh.ops.create_cube(bm, size=1.0)
	size = [hi[i] - lo[i] for i in range(3)]
	centre = [(hi[i] + lo[i]) * 0.5 for i in range(3)]
	bmesh.ops.scale(bm, vec=size, verts=result["verts"])
	bmesh.ops.translate(bm, vec=centre, verts=result["verts"])


def cylinder_along_y(bm, x, z, radius, length, sides, caps):
	"""Adds a cylinder whose axle runs along y (the hall), centred on y 0."""
	result = bmesh.ops.create_cone(bm, cap_ends=caps, segments=sides, radius1=radius, radius2=radius, depth=length)
	verts = result["verts"]
	bmesh.ops.rotate(bm, cent=(0.0, 0.0, 0.0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"),
			verts=verts)
	bmesh.ops.translate(bm, vec=(x, 0.0, z), verts=verts)


def column(bm):
	height, flange, flange_t, web_t, depth = COLUMN
	half = flange * 0.5
	box(bm, (0.0, -half, 0.0), (flange_t, half, height))
	box(bm, (flange_t, -web_t * 0.5, 0.0), (depth - flange_t, web_t * 0.5, height))
	box(bm, (depth - flange_t, -half, 0.0), (depth, half, height))
	side, thick = COLUMN_BASE
	box(bm, (0.0, -side * 0.5, 0.0), (side, side * 0.5, thick))


def panel(bm):
	width, height, bar, depth, plate = PANEL
	w = width * 0.5
	box(bm, (0.0, -w, 0.0), (plate, w, height))
	box(bm, (0.0, -w, 0.0), (depth, w, bar))
	box(bm, (0.0, -w, height - bar), (depth, w, height))
	box(bm, (0.0, -w, bar), (depth, -w + bar, height - bar))
	box(bm, (0.0, w - bar, bar), (depth, w, height - bar))
	count, length, louver_h, louver_d = LOUVERS
	for k in range(count):
		z = height * (k + 1) / (count + 1)
		box(bm, (plate, -length * 0.5, z - louver_h * 0.5), (plate + louver_d, length * 0.5, z + louver_h * 0.5))


def pipes(bm):
	radius, sides, length = PIPE
	for out in PIPE_OUTS:
		cylinder_along_y(bm, out, 0.0, radius, length, sides, False)
	thick, offset = BRACKET
	reach = PIPE_OUTS[-1] + radius
	for y in (-offset, offset):
		box(bm, (0.0, y - thick * 0.5, -radius), (reach, y + thick * 0.5, radius))


def machine(bm, top):
	depth, length, plinth = MACHINE
	half = length * 0.5
	box(bm, (0.0, -half, 0.0), (depth, half, plinth))
	inset = MACHINE_BODY_INSET
	front = depth - inset
	box(bm, (0.0, -half + inset, plinth), (front, half - inset, top))
	count, rib_w, rib_d = RIBS
	for k in range(count):
		y = (k - (count - 1) * 0.5) * (length - inset * 2.0) / count
		box(bm, (front, y - rib_w * 0.5, plinth + inset), (front + rib_d, y + rib_w * 0.5, top - inset))
	radius, sides = TANK
	tank_x = front * 0.5
	cylinder_along_y(bm, tank_x, top + radius, radius, length - inset * 4.0, sides, True)
	# the pipe from the tank back into the wall
	box(bm, (0.0, -0.2, top + radius - 0.2), (tank_x, 0.2, top + radius + 0.2))


bpy.ops.wm.read_factory_settings(use_empty=True)
pieces = [("wall_column", column), ("wall_panel", panel), ("wall_pipes", pipes)]
for name, top in MACHINE_TOPS.items():
	pieces.append((name, lambda bm, top=top: machine(bm, top)))
for name, build in pieces:
	bm = bmesh.new()
	build(bm)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, OUT_DIR, name)
	bpy.data.objects.remove(obj)
