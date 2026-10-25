# The note's rounder body (doc/assets/note_round/spec.md): the glossy default look's cube (BeepCube.gdshader,
# note_gloss.gdshaderinc), with wider rounded edges than the classic mesh (game/BeepCube/BeepCubeMesh.glb, which stays
# for Classic notes), so its highlight rolls over the edges as on Beat Saber's notes (owner, 2026-10-25).
# A cube 0.5 wide in the mesh's own units (the note scales it by 0.8 in BeepCube.tscn, so 0.4 m), its edges and corners
# rounded with RADIUS. Normals are smooth and exact: each vertex's points from the nearest point of the inner box the
# rounding wraps, so the flat faces stay flat and the bevels roll.
# UVs as the classic mesh, so the emission texture's arrow and dot land on the front: the front (toward the player,
# Blender -y) and the back are projected flat, the front from the texture's top-left quarter and the back from its
# top-right, at MARK_SCALE (smaller than the classic's 1, so the arrow stays on the smaller flat face); every other
# face reads a black spot of the texture.
# Run headless: blender -b -P tools/models/note_round.py -- game/BeepCube
# Made from scratch.
import os
import sys

import bmesh
import bpy
from mathutils import Vector

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

HALF = 0.25
# 0.07 m on the note as played (0.8 scale); the classic mesh's is 0.05 (0.04 m)
RADIUS = 0.0875
SEGMENTS = 4
MARK_SCALE = 1.2
# a black spot of the texture (Blender UVs, v up), for the faces without a mark
BLANK_UV = (0.5, 0.25)

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=HALF * 2.0)
bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=RADIUS, segments=SEGMENTS, profile=0.5,
	affect="EDGES", clamp_overlap=False)
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
uv = bm.loops.layers.uv.new("UVMap")
inner = HALF - RADIUS
for face in bm.faces:
	normal = face.normal
	for loop in face.loops:
		p = loop.vert.co
		if normal.y < -0.5:
			loop[uv].uv = (0.25 - p.x * MARK_SCALE, 0.75 + p.z * MARK_SCALE)
		elif normal.y > 0.5:
			loop[uv].uv = (0.75 - p.x * MARK_SCALE, 0.75 + p.z * MARK_SCALE)
		else:
			loop[uv].uv = BLANK_UV
mesh = bpy.data.meshes.new("note_round")
bm.to_mesh(mesh)
bm.free()
mesh.shade_smooth()
normals = []
for v in mesh.vertices:
	inside = Vector([max(-inner, min(inner, c)) for c in v.co])
	normals.append((v.co - inside).normalized())
mesh.normals_split_custom_set_from_vertices(normals)
obj = bpy.data.objects.new("note_round", mesh)
bpy.context.scene.collection.objects.link(obj)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/note_round.glb", export_format="GLB", export_yup=True,
	export_apply=True, export_cameras=False, export_lights=False, use_selection=True)
print("note_round triangles: %d" % sum(len(p.vertices) - 2 for p in mesh.polygons))
