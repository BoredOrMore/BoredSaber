# The moving-head light every laser beam leaves from (AGENTS.md "Light", rule 5: a fixture on a surface shooting a
# beam out, with a bright spot where the beam leaves it). A short barrel with a recessed lens at the front and a
# narrower cap at the back. Origin at the barrel's centre, which is the laser's pivot: the head turns around it like
# a real moving head. The lens faces Godot's -z, the way the beam runs.
# Vertex colours: red is baked ambient occlusion, green marks the lens (1) for LaserFixture.gdshader.
# Run headless: blender -b -P tools/models/laser_fixture.py -- game/models
# Sizes in metres, untuned. Made from scratch here; no outside assets.
import math
import sys

import bmesh
import bpy

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

SIDES = 12
RADIUS = 0.3
LENGTH = 0.7
# how far in from the barrel's edge the lens starts, and how deep it sits
BEZEL = 0.06
LENS_DEPTH = 0.04
# the cap at the back: how far in from the edge, and how far it sticks out
CAP_INSET = 0.05
CAP_LENGTH = 0.08
BEVEL_WIDTH = 0.012
AO_SAMPLES = 64

bpy.ops.wm.read_factory_settings(use_empty=True)
# Blender is z-up; the glTF export turns Blender's +y into Godot's -z, so the lens faces +y here
bpy.ops.mesh.primitive_cylinder_add(vertices=SIDES, radius=RADIUS, depth=LENGTH, rotation=(-math.pi / 2, 0.0, 0.0))
head = bpy.context.object
head.name = "laser_fixture"
bpy.ops.object.transform_apply(rotation=True)

mesh = head.data
bm = bmesh.new()
bm.from_mesh(mesh)
bm.faces.ensure_lookup_table()
front = max(bm.faces, key=lambda f: f.calc_center_median().y)
back = min(bm.faces, key=lambda f: f.calc_center_median().y)

# front: a bezel ring, then the lens pushed in
bmesh.ops.inset_region(bm, faces=[front], thickness=BEZEL)
bmesh.ops.translate(bm, vec=(0.0, -LENS_DEPTH, 0.0), verts=list(front.verts))
# back: a narrower cap sticking out
bmesh.ops.inset_region(bm, faces=[back], thickness=CAP_INSET)
cap = bmesh.ops.extrude_face_region(bm, geom=[back])
cap_verts = [v for v in cap["geom"] if isinstance(v, bmesh.types.BMVert)]
bmesh.ops.translate(bm, vec=(0.0, -CAP_LENGTH, 0.0), verts=cap_verts)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.faces.index_update()
lens_index = front.index
bm.to_mesh(mesh)
bm.free()

# mark the lens before the bevel changes face order: a face attribute the bevel carries over
lens_attr = mesh.attributes.new("lens", "FLOAT", "FACE")
for poly in mesh.polygons:
	lens_attr.data[poly.index].value = 1.0 if poly.index == lens_index else 0.0

bevel = head.modifiers.new("bevel", "BEVEL")
bevel.width = BEVEL_WIDTH
bevel.segments = 1
bevel.limit_method = "ANGLE"
bevel.angle_limit = math.radians(40.0)
bpy.ops.object.modifier_apply(modifier="bevel")
mesh.shade_smooth()
mesh.set_sharp_from_angle(angle=math.radians(40.0))

# bake ambient occlusion into a colour attribute
ao = mesh.color_attributes.new("ao", "BYTE_COLOR", "CORNER")
mesh.color_attributes.active_color = ao
material = bpy.data.materials.new("laser_fixture")
mesh.materials.append(material)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = AO_SAMPLES
scene.render.bake.target = "VERTEX_COLORS"
bpy.ops.object.bake(type="AO")

# the exported colour: red = occlusion, green = lens
col = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
lens_attr = mesh.attributes["lens"]
for poly in mesh.polygons:
	is_lens = lens_attr.data[poly.index].value > 0.5
	for loop in poly.loop_indices:
		occlusion = ao.data[loop].color[0]
		col.data[loop].color = (occlusion, 1.0 if is_lens else 0.0, 0.0, 1.0)
mesh.color_attributes.remove(mesh.color_attributes["ao"])
mesh.attributes.remove(mesh.attributes["lens"])
mesh.color_attributes.active_color = mesh.color_attributes["Col"]
mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index

bpy.ops.export_scene.gltf(
	filepath=OUT_DIR + "/laser_fixture.glb",
	export_format="GLB",
	export_yup=True,
	export_apply=True,
	export_vertex_color="ACTIVE",
	export_cameras=False,
	export_lights=False,
)
triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
print("laser_fixture triangles: %d" % triangles)
