# The player's platform frame (doc/assets/platform_frame/spec.md, game/env/TrackDeck.gd): the ring round the 2 m pad the
# player stands on, where the platform joins the track's deck. Between the pad and the ring runs the channel the
# platform's border light strips (game/floor.tscn) lie in, flush with the ring's top, so they are set into the platform
# instead of lying on it (owner, 2026-10-25: the platform should be as solid as the track and joined to it).
# The ring: four bars round the channel, their tops level with the deck (y 0), a chamfer on their outer top edge,
# standing on the platform's base (TrackDeck: the deck under the platform, PAD_DEPTH below its top).
# Origin at the pad's centre on the deck's top; x across the track, Blender y along it (Godot -z).
# Vertex colours: red is baked ambient occlusion (model_export.py). Hard metal: flat shading.
# Run headless: blender -b -P tools/models/platform_frame.py -- game/models
# Sizes in metres, matched to game/floor.tscn (the pad 2 m square, its border strips 0.08 m wide centred 0.98 m out) and
# TrackDeck.gd (PAD_DEPTH, FRAME_HALF). Made from scratch.

import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the channel's outer edge (the strips reach 1.02 m out) and the ring's outer edge, from the pad's centre; the ring's
# height (down to the base) and its chamfer
INNER = 1.02
OUTER = 1.1
HEIGHT = 0.03
CHAMFER = 0.015

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
# one bar's cross-section, from its inner bottom over its top to its outer bottom (out, height)
section = [(INNER, -HEIGHT), (INNER, 0.0), (OUTER - CHAMFER, 0.0), (OUTER, -CHAMFER), (OUTER, -HEIGHT)]
# swept round the square: at each corner the section is mitred, so the ring is one closed piece
corners = []
for k in range(4):
	ring = []
	for out, up in section:
		# a corner of the square at this out distance, in the corner's direction (diagonal)
		x = out * (1.0 if k in (0, 3) else -1.0)
		y = out * (1.0 if k in (0, 1) else -1.0)
		ring.append(bm.verts.new((x, y, up)))
	corners.append(ring)
for k in range(4):
	a = corners[k]
	b = corners[(k + 1) % 4]
	for i in range(len(section) - 1):
		bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("platform_frame")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("platform_frame", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "platform_frame")
