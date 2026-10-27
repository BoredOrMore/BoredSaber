# The Metal Factory's piston (doc/world/SPATIAL_LAYOUT.md, doc/assets/piston_hammer/spec.md): a hammer that slams
# down onto its anvil on the beat. Two parts, so the hammer can move while the housing stays:
#  - piston_housing.glb: the cylinder hung under the header beam: a square mounting plate on top, an eight-sided
#    barrel with two reinforcing bands, and a gland collar at the bottom where the rod comes out. Origin at the top of
#    the plate (the header beam's underside), the barrel hanging down along Godot's -y.
#  - piston_hammer.glb: the rod and the hammer head as one moving part: a long eight-sided rod, a tapered neck and a
#    square head with chamfered edges. Origin at the centre of the striking face (the head's underside), so its height
#    is where the blow lands; the rod runs up along +y, long enough to stay inside the housing at full stroke.
# Vertex colours: red is baked ambient occlusion (as laser_fixture.py). Hard metal: flat shading, chamfered edges.
# Run headless: blender -b -P tools/models/piston_hammer.py -- game/models
# Sizes in metres, from the approved blockout (MetalFactoryRig.gd: HOUSING, HAMMER, ROD, HAMMER_BOTTOM, HEADER_Y,
# ANVIL). Made from scratch; no outside assets.
import math
import sys

import bmesh
import bpy

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

SIDES = 8
# housing: mounting plate (square side, thickness), barrel (radius to a corner, height), the two bands (radius, height,
# centre heights below the plate) and the gland collar (radius, height)
PLATE = (1.6, 0.2)
BARREL = (0.7, 2.6)
BAND = (0.78, 0.18)
BAND_DEPTHS = (0.7, 1.9)
GLAND = (0.42, 0.2)
# hammer: head (square side, height), the chamfer on its edges, the neck between head and rod (radius at the head,
# height) and the rod (radius, length above the neck). The rod stays inside the housing (bottom 6.0 m up, plate
# underside 8.8 m) over the whole stroke: raised, the striking face is 3.8 m up and the rod's top 8.75 m; down on the
# anvil (1.5 m) the top is at 6.45 m.
HEAD = (2.2, 1.2)
CHAMFER = 0.08
NECK = (0.55, 0.35)
ROD = (0.25, 3.4)
EDGE_BEVEL = 0.03
AO_SAMPLES = 64


def cylinder(radius, depth, z_top):
	"""An eight-sided cylinder (a corner along +x) whose top is at z_top."""
	bpy.ops.mesh.primitive_cylinder_add(vertices=SIDES, radius=radius, depth=depth, location=(0.0, 0.0, z_top - depth * 0.5))
	return bpy.context.object


def box(centre, size):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
	obj = bpy.context.object
	obj.scale = size
	bpy.ops.object.transform_apply(scale=True)
	return obj


def join(name, parts):
	bpy.ops.object.select_all(action="DESELECT")
	for part in parts:
		part.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	obj = bpy.context.object
	obj.name = name
	return obj


def bevel(obj, width):
	modifier = obj.modifiers.new("bevel", "BEVEL")
	modifier.width = width
	modifier.segments = 1
	modifier.limit_method = "ANGLE"
	modifier.angle_limit = math.radians(50.0)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.modifier_apply(modifier="bevel")


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

# the housing, hanging down from z 0 (Blender z-up becomes Godot y-up)
plate = box((0.0, 0.0, -PLATE[1] * 0.5), (PLATE[0], PLATE[0], PLATE[1]))
# only the plate is bevelled: on the eight-sided parts a bevel doubled the triangles (284) for edges too small to
# read from 7 m away
bevel(plate, EDGE_BEVEL)
barrel_top = -PLATE[1]
parts = [plate, cylinder(BARREL[0], BARREL[1], barrel_top)]
for depth in BAND_DEPTHS:
	parts.append(cylinder(BAND[0], BAND[1], barrel_top - depth + BAND[1] * 0.5))
barrel_bottom = barrel_top - BARREL[1]
parts.append(cylinder(GLAND[0], GLAND[1], barrel_bottom))
housing = join("piston_housing", parts)
bake_and_export(housing, "piston_housing")
housing_height = -(barrel_bottom - GLAND[1])
bpy.data.objects.remove(housing)

# the hammer, up from its striking face at z 0. The head's edges are chamfered so it reads as forged, not as a box.
head = box((0.0, 0.0, HEAD[1] * 0.5), (HEAD[0], HEAD[0], HEAD[1]))
bevel(head, CHAMFER)
# the neck: a cone from NECK radius on the head to the rod's radius, as a truncated eight-sided cone
bpy.ops.mesh.primitive_cone_add(vertices=SIDES, radius1=NECK[0], radius2=ROD[0], depth=NECK[1],
		location=(0.0, 0.0, HEAD[1] + NECK[1] * 0.5))
neck = bpy.context.object
rod = cylinder(ROD[0], ROD[1], HEAD[1] + NECK[1] + ROD[1])
# the rod's hidden ends are left in: its bottom is inside the neck, its top inside the housing at every stroke
hammer = join("piston_hammer", [head, neck, rod])
bm = bmesh.new()
bm.from_mesh(hammer.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(hammer.data)
bm.free()
bake_and_export(hammer, "piston_hammer")
print("housing height below the header: %.2f m; hammer from strike face to rod top: %.2f m"
		% (housing_height, HEAD[1] + NECK[1] + ROD[1]))
