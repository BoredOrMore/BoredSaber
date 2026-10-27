# The note track's edge (doc/assets/track_edge/spec.md, game/env/TrackDeck.gd): the curb along each side of the deck
# that houses the edge light strip, and the skirt that carries the deck down to the stage floor, so the track stops
# reading as a thin sheet floating in the air (owner, 2026-10-25). One profile extruded 1 m along the track; the game
# stretches it to the track's length (only along the extrusion, so the profile keeps its shape).
# Profile, from the deck's edge outward: a bevelled lip up from the deck, the curb's top, a channel the light strip sits
# in (its top flush with the curb's), the curb's outer bevel, its outer face, then a skirt flaring out and down.
# Built for the right side: x outward from the deck's edge, y up from the deck's top (Blender z), the extrusion along
# the track (Blender y, Godot -z), centred. The left side is the same piece turned half round.
# Only the faces that can be seen: the inner face under the deck is left open; both ends are capped (the left edge is
# this piece turned half round, so its near end is this one's far end).
# Vertex colours: red is baked ambient occlusion (model_export.py). Hard metal: flat shading.
# Run headless: blender -b -P tools/models/track_edge.py -- game/models
# Sizes in metres, matched to TrackDeck.gd (STRIP_OUT, CURB_RISE) and the strip's 0.1 m section. Made from scratch.
import os
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(__file__))
from model_export import bake_and_export

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# the profile's points (x out from the deck's edge, height above the deck's top), along its outside from the deck
PROFILE = [
	(0.0, 0.0),      # the deck's edge
	(0.03, 0.08),    # the lip's bevel up to the curb's top
	(0.10, 0.08),
	(0.10, 0.04),    # the channel: 0.1 m wide (the strip's width), 0.04 m deep, centred 0.15 m out
	(0.20, 0.04),
	(0.20, 0.08),
	(0.27, 0.08),
	(0.30, 0.05),    # the outer bevel
	(0.30, -0.35),   # the outer face
	(0.42, -0.5),    # the skirt flares out
	(0.42, -1.5),    # and goes down to the stage floor (and below it where a stage's floor is higher)
]
LENGTH = 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
near = [bm.verts.new((x, -LENGTH * 0.5, y)) for x, y in PROFILE]
far = [bm.verts.new((x, LENGTH * 0.5, y)) for x, y in PROFILE]
for i in range(len(PROFILE) - 1):
	bm.faces.new((near[i], near[i + 1], far[i + 1], far[i]))
# the end caps: the profile closed back to the deck's edge under the deck
for end in (near, far):
	bottom = bm.verts.new((0.0, end[0].co.y, PROFILE[-1][1]))
	bm.faces.new(end + [bottom])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("track_edge")
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("track_edge", mesh)
bpy.context.scene.collection.objects.link(obj)
bake_and_export(obj, OUT_DIR, "track_edge")
