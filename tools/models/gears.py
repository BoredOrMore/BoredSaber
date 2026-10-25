# The Metal Factory's gears (doc/world/SPATIAL_LAYOUT.md, doc/assets/gears/spec.md), built by one toothed-wheel
# generator at three sizes:
#  - gear_ring.glb: the rings round the track (a rim with teeth, no spokes; it stands still).
#  - drive_gear_large.glb, drive_gear_small.glb: the drive gears at the far end (rim, teeth, spokes, hub); they turn.
#    Their teeth are the same size, so their counts follow their radii and they could mesh.
# Every gear faces the player: its front is Godot's +z, its origin at its centre, its axle along z. Only the front and
# the edges are built: no gear is ever seen from behind (the player stays at z 1, in front of them all).
# Vertex colours: red is baked ambient occlusion (as laser_fixture.py). Hard metal: flat shading.
# Run headless: blender -b -P tools/models/gears.py -- game/models
# Sizes in metres, from the approved blockout (MetalFactoryRig.gd RING_*, DRIVE_GEARS). Made from scratch; no outside
# assets.
import math
import sys

import bmesh
import bpy
from mathutils import Matrix

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# each gear: file name, rim's inner radius, root radius (where the teeth start), tooth height, tooth count, depth,
# and whether it has spokes and a hub
GEARS = [
	("gear_ring", 6.2, 6.8, 0.6, 12, 0.6, False),
	("drive_gear_large", 8.8, 10.0, 1.2, 24, 1.0, True),
	("drive_gear_small", 6.3, 7.5, 1.2, 18, 1.0, True),
]
# a tooth's share of its pitch at the root and at the tip (the rest is the gap), so the teeth taper
TOOTH_ROOT = 0.55
TOOTH_TIP = 0.35
# drive gears: spokes (count, width, depth) and the hub (radius, sides, depth)
SPOKES = (4, 1.2, 0.6)
HUB = (1.5, 8, 1.4)
AO_SAMPLES = 64


def wheel(bm, inner, root, tooth, teeth, depth):
	"""Adds a toothed rim to bm: front face at y 0 (Blender, the glTF export's +z), extruded to +y by depth. Each tooth
	and the gap after it make one front face from the rim's inner edge, so a tooth costs 15 triangles."""
	pitch = math.tau / teeth
	def vert(angle, radius, y):
		return bm.verts.new((radius * math.cos(angle), y, radius * math.sin(angle)))
	outer = []
	for i in range(teeth):
		centre = i * pitch
		for angle, radius in [
				(centre - pitch * TOOTH_ROOT * 0.5, root), (centre - pitch * TOOTH_TIP * 0.5, root + tooth),
				(centre + pitch * TOOTH_TIP * 0.5, root + tooth), (centre + pitch * TOOTH_ROOT * 0.5, root)]:
			outer.append((vert(angle, radius, 0.0), vert(angle, radius, depth)))
	# the rim's inner edge, a point at each tooth's centre
	inner_ring = [(vert(i * pitch, inner, 0.0), vert(i * pitch, inner, depth)) for i in range(teeth)]
	n = len(outer)
	for i in range(teeth):
		j = (i + 1) % teeth
		# front: from tooth i's centre round its second half, the gap and tooth j's first half
		path = [outer[4 * i + 2][0], outer[4 * i + 3][0], outer[4 * j][0], outer[4 * j + 1][0]]
		bm.faces.new([inner_ring[i][0]] + path + [inner_ring[j][0]])
		bm.faces.new((inner_ring[i][0], inner_ring[j][0], inner_ring[j][1], inner_ring[i][1]))
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((outer[i][1], outer[j][1], outer[j][0], outer[i][0]))
	# the tooth tips' front faces between the halves
	for i in range(teeth):
		bm.faces.new((inner_ring[i][0], outer[4 * i + 1][0], outer[4 * i + 2][0]))


def box(bm, centre, size, angle):
	"""Adds a box turned by angle about the gear's axle (Blender y)."""
	result = bmesh.ops.create_cube(bm, size=1.0)
	verts = result["verts"]
	bmesh.ops.scale(bm, vec=size, verts=verts)
	bmesh.ops.rotate(bm, cent=(0.0, 0.0, 0.0), matrix=Matrix.Rotation(angle, 3, "Y"), verts=verts)
	bmesh.ops.translate(bm, vec=centre, verts=verts)


def bake_and_export(obj, file_name):
	"""Bakes occlusion into red, then exports obj alone with flat shading."""
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	mesh = obj.data
	mesh.shade_flat()
	ao = mesh.color_attributes.new("ao", "BYTE_COLOR", "CORNER")
	mesh.color_attributes.active_color = ao
	mesh.materials.append(bpy.data.materials.new(file_name))
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.samples = AO_SAMPLES
	scene.render.bake.target = "VERTEX_COLORS"
	bpy.ops.object.bake(type="AO")
	col = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
	for loop in range(len(mesh.loops)):
		col.data[loop].color = (ao.data[loop].color[0], 0.0, 0.0, 1.0)
	mesh.color_attributes.remove(mesh.color_attributes["ao"])
	mesh.color_attributes.active_color = mesh.color_attributes["Col"]
	mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
	bpy.ops.export_scene.gltf(
		filepath=OUT_DIR + "/" + file_name + ".glb",
		export_format="GLB",
		export_yup=True,
		export_apply=True,
		export_vertex_color="ACTIVE",
		export_cameras=False,
		export_lights=False,
		use_selection=True,
	)
	print("%s triangles: %d" % (file_name, sum(len(p.vertices) - 2 for p in mesh.polygons)))


bpy.ops.wm.read_factory_settings(use_empty=True)
for name, inner, root, tooth, teeth, depth, spoked in GEARS:
	bm = bmesh.new()
	wheel(bm, inner, root, tooth, teeth, depth)
	if spoked:
		count, width, spoke_depth = SPOKES
		for k in range(count):
			# each spoke spans the hub's centre to the rim, ends hidden in both
			box(bm, (0.0, (depth - spoke_depth) * 0.5 + spoke_depth * 0.5, 0.0), (inner * 2.0, spoke_depth, width),
					math.pi * k / count)
		hub = bmesh.ops.create_cone(bm, cap_ends=True, segments=HUB[1], radius1=HUB[0], radius2=HUB[0], depth=HUB[2])
		bmesh.ops.rotate(bm, cent=(0.0, 0.0, 0.0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"),
				verts=hub["verts"])
		bmesh.ops.translate(bm, vec=(0.0, depth * 0.5, 0.0), verts=hub["verts"])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	bake_and_export(obj, name)
	bpy.data.objects.remove(obj)
