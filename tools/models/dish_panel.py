# Pulse Void's dish panel (doc/assets/dish_panel/spec.md): one of the 672 panels of the receiving dish, its face only
# (the player sees the dish from above; the panels' edges meet their neighbours'). A raised frame round the edge, the
# face recessed inside it and split in two by a rib down the slope, so the seams read from the cabin.
# A unit piece, -0.5..0.5 each way, scaled by the rig to each ring's panel: x along the ring, Blender z the dish's
# normal (Godot y; the frame's top at +0.5), Blender y down the slope.
# Vertex colours: red is baked ambient occlusion (model_export.py).
# Run headless: blender -b -P tools/models/dish_panel.py -- game/models
# Made from scratch.
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the frame's width (of the panel's width and length), how deep the face sits under it (of the thickness), the rib's
# width (of the panel's width)
FRAME = (0.05, 0.03)
RECESS = 0.3
RIB = 0.03

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
top, face = 0.5, 0.5 - RECESS
hx, hy = 0.5, 0.5
ix, iy = hx - FRAME[0], hy - FRAME[1]
rx = RIB * 0.5
v = lambda x, y, z: bm.verts.new((x, y, z))
outer = [v(-hx, -hy, top), v(hx, -hy, top), v(hx, hy, top), v(-hx, hy, top)]
inner = [v(-ix, -iy, face), v(ix, -iy, face), v(ix, iy, face), v(-ix, iy, face)]
# the frame's slopes down into the face, wound to face +z
for i in range(4):
	j = (i + 1) % 4
	bm.faces.new((outer[i], outer[j], inner[j], inner[i]))
# the face, split by the rib: the rib's foot on the face either side of the middle, its top level with the frame
foot = [v(-rx * 2.0, -iy, face), v(rx * 2.0, -iy, face), v(rx * 2.0, iy, face), v(-rx * 2.0, iy, face)]
ridge = [v(-rx, -iy, top), v(rx, -iy, top), v(rx, iy, top), v(-rx, iy, top)]
bm.faces.new((inner[0], foot[0], foot[3], inner[3]))
bm.faces.new((foot[1], inner[1], inner[2], foot[2]))
bm.faces.new((foot[0], ridge[0], ridge[3], foot[3]))
bm.faces.new((ridge[0], ridge[1], ridge[2], ridge[3]))
bm.faces.new((ridge[1], foot[1], foot[2], ridge[2]))
for f in bm.faces:
	if f.normal.z < 0.0:
		f.normal_flip()
mesh = bpy.data.meshes.new("dish_panel")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("dish_panel", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "dish_panel")
