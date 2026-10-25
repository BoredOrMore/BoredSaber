# The note track's end stop (doc/assets/track_end/spec.md, game/env/TrackDeck.gd): a low block across the far end of the
# deck and its edges, which the edge light strips run into, so they end on something instead of stopping in mid-air
# (owner, 2026-10-25: "the light just disappears"). Low on purpose: it stands behind where notes and walls appear, and
# stays below the horizon (AGENTS.md "Light", rule 5: nothing in front of the horizon), so no gate frame over the track.
# A block 1 m wide (the game stretches it across the deck and both edges), its top STOP_HEIGHT above the deck with a
# chamfer on its edge facing the player, its face toward the player going down to the edges' skirt, and the skirt below.
# Origin at the middle of its face toward the player, on the deck's top; Blender -y is the game's +z (toward the
# player). The back (away from the player) is never seen and left open.
# Vertex colours: red is baked ambient occlusion (model_export.py). Hard metal: flat shading.
# Run headless: blender -b -P tools/models/track_end.py -- game/models
# Sizes in metres, matched to track_edge.py (CURB_RISE 0.08, skirt to -1.5). Made from scratch.
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

WIDTH = 1.0
# its top above the deck, the chamfer on its near top edge (along and down), its depth along the track, and how far down
# its near face goes (the edges' skirt)
STOP_HEIGHT = 0.5
CHAMFER = 0.12
DEPTH = 1.2
BOTTOM = -1.5

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
# the profile seen from the side (along the track y, height z), from the bottom of the near face up and over the top to
# the back: near face, chamfer, top
profile = [(0.0, BOTTOM), (0.0, STOP_HEIGHT - CHAMFER), (CHAMFER, STOP_HEIGHT), (DEPTH, STOP_HEIGHT), (DEPTH, BOTTOM)]
left = [bm.verts.new((-WIDTH * 0.5, y, z)) for y, z in profile]
right = [bm.verts.new((WIDTH * 0.5, y, z)) for y, z in profile]
for i in range(len(profile) - 1):
	bm.faces.new((left[i], left[i + 1], right[i + 1], right[i]))
# the two ends (seen past the edges' skirts from some angles)
bm.faces.new(left)
bm.faces.new(right)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("track_end")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("track_end", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "track_end")
