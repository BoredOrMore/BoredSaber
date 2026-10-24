# The moving-head light every laser beam leaves from (AGENTS.md "Light", rule 5: a fixture on a surface shooting a
# beam out, with a bright spot where the beam leaves it). Two parts, as on a real moving head:
#  - laser_fixture.glb, the head: a short barrel with a recessed lens at the front and a narrower cap at the back.
#    Origin at the barrel's centre, the laser's pivot; it tilts there. The lens faces Godot's -z, the way the beam runs.
#  - laser_fixture_yoke.glb, the yoke: a base plate on the pedestal, a short stem, and a U whose two arms rise to the
#    head's tilt axis on either side. Same origin (the tilt axis's centre); it only turns around the vertical.
# Vertex colours: red is baked ambient occlusion, green marks the lens (1) for LaserFixture.gdshader.
# Run headless: blender -b -P tools/models/laser_fixture.py -- game/models
# Sizes in metres. The head was 0.6 m across at first; from the player's place 30 m away it read as a speck
# (Blender render from the player's eye, 2026-10-24), so it is 1.5 times that. Made from scratch; no outside assets.
import math
import sys

import bmesh
import bpy

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

SIDES = 12
SCALE = 1.5
RADIUS = 0.3 * SCALE
LENGTH = 0.7 * SCALE
# how far in from the barrel's edge the lens starts, and how deep it sits
BEZEL = 0.06 * SCALE
LENS_DEPTH = 0.04 * SCALE
# the cap at the back: how far in from the edge, and how far it sticks out
CAP_INSET = 0.05 * SCALE
CAP_LENGTH = 0.08 * SCALE
BEVEL_WIDTH = 0.012 * SCALE
# the yoke: arm thickness (across, along the beam's heading), the gap between head and arm, how high the arms
# reach above the tilt axis, the cross bar's height, the stem's size and the base plate's radius and thickness.
# The cross bar sits low enough that the head's back clears it at any tilt (half its diagonal is 0.73 m).
ARM = (0.1, 0.16)
ARM_GAP = 0.03
ARM_ABOVE = 0.1
BAR_TOP = -0.75
BAR_HEIGHT = 0.1
STEM = (0.2, 0.15)
PLATE_RADIUS = 0.4
PLATE_THICKNESS = 0.08
PLATE_SIDES = 8
AO_SAMPLES = 64


def box(name, centre, size):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
	obj = bpy.context.object
	obj.name = name
	obj.scale = size
	bpy.ops.object.transform_apply(scale=True)
	return obj


def bake_and_export(obj, file_name, lens_faces):
	"""Bakes occlusion into red and the lens mask into green, then exports obj alone."""
	mesh = obj.data
	mesh.shade_smooth()
	mesh.set_sharp_from_angle(angle=math.radians(40.0))
	ao = mesh.color_attributes.new("ao", "BYTE_COLOR", "CORNER")
	mesh.color_attributes.active_color = ao
	mesh.materials.append(bpy.data.materials.new(file_name))
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.samples = AO_SAMPLES
	scene.render.bake.target = "VERTEX_COLORS"
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.bake(type="AO")
	col = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
	lens_attr = mesh.attributes.get("lens")
	for poly in mesh.polygons:
		is_lens = lens_attr is not None and lens_attr.data[poly.index].value > 0.5
		for loop in poly.loop_indices:
			col.data[loop].color = (ao.data[loop].color[0], 1.0 if is_lens else 0.0, 0.0, 1.0)
	mesh.color_attributes.remove(mesh.color_attributes["ao"])
	if lens_attr is not None:
		mesh.attributes.remove(lens_attr)
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

# the head. Blender is z-up; the glTF export turns Blender's +y into Godot's -z, so the lens faces +y here
bpy.ops.mesh.primitive_cylinder_add(vertices=SIDES, radius=RADIUS, depth=LENGTH, rotation=(-math.pi / 2, 0.0, 0.0))
head = bpy.context.object
head.name = "laser_fixture"
bpy.ops.object.transform_apply(rotation=True)
bm = bmesh.new()
bm.from_mesh(head.data)
bm.faces.ensure_lookup_table()
front = max(bm.faces, key=lambda f: f.calc_center_median().y)
back = min(bm.faces, key=lambda f: f.calc_center_median().y)
# front: a bezel ring, then the lens pushed in
bmesh.ops.inset_region(bm, faces=[front], thickness=BEZEL)
bmesh.ops.translate(bm, vec=(0.0, -LENS_DEPTH, 0.0), verts=list(front.verts))
# back: a narrower cap sticking out
bmesh.ops.inset_region(bm, faces=[back], thickness=CAP_INSET)
cap = bmesh.ops.extrude_face_region(bm, geom=[back])
bmesh.ops.translate(bm, vec=(0.0, -CAP_LENGTH, 0.0),
		verts=[v for v in cap["geom"] if isinstance(v, bmesh.types.BMVert)])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.faces.index_update()
lens_index = front.index
bm.to_mesh(head.data)
bm.free()
# mark the lens before the bevel changes face order: a face attribute the bevel carries over
lens_attr = head.data.attributes.new("lens", "FLOAT", "FACE")
for poly in head.data.polygons:
	lens_attr.data[poly.index].value = 1.0 if poly.index == lens_index else 0.0
bevel = head.modifiers.new("bevel", "BEVEL")
bevel.width = BEVEL_WIDTH
bevel.segments = 1
bevel.limit_method = "ANGLE"
bevel.angle_limit = math.radians(40.0)
bpy.ops.object.modifier_apply(modifier="bevel")
bake_and_export(head, "laser_fixture", True)
bpy.data.objects.remove(head)

# the yoke, in Blender axes: x across (the tilt axis), y along the heading, z up
arm_x = RADIUS + ARM_GAP + ARM[0] * 0.5
arm_bottom = BAR_TOP - BAR_HEIGHT
parts = [
	box("arm_l", (-arm_x, 0.0, (ARM_ABOVE + arm_bottom) * 0.5), (ARM[0], ARM[1], ARM_ABOVE - arm_bottom)),
	box("arm_r", (arm_x, 0.0, (ARM_ABOVE + arm_bottom) * 0.5), (ARM[0], ARM[1], ARM_ABOVE - arm_bottom)),
	box("bar", (0.0, 0.0, BAR_TOP - BAR_HEIGHT * 0.5), (arm_x * 2.0 + ARM[0], ARM[1], BAR_HEIGHT)),
	box("stem", (0.0, 0.0, arm_bottom - STEM[1] * 0.5), (STEM[0], STEM[0], STEM[1])),
]
bpy.ops.mesh.primitive_cylinder_add(vertices=PLATE_SIDES, radius=PLATE_RADIUS, depth=PLATE_THICKNESS,
		location=(0.0, 0.0, arm_bottom - STEM[1] - PLATE_THICKNESS * 0.5))
parts.append(bpy.context.object)
bpy.ops.object.select_all(action="DESELECT")
for part in parts:
	part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
yoke = bpy.context.object
yoke.name = "laser_fixture_yoke"
bake_and_export(yoke, "laser_fixture_yoke", False)
# where the pedestal's top must be, below the tilt axis (ClassicRig.FIXTURE_Y uses it)
print("yoke foot below the tilt axis: %.3f m" % -(arm_bottom - STEM[1] - PLATE_THICKNESS))
