# The Metal Factory's anvil (doc/assets/anvil_base/spec.md): the block each piston's hammer slams onto
# (tools/models/piston_hammer.py). A floor plinth, a body whose top is a shelf for the diagonal laser at the corner
# nearest the player, and a strike die with chamfered edges whose top is where the hammer lands. Origin at the centre
# of its foot, on the floor; static, so one part.
# Vertex colours: red is baked ambient occlusion (as laser_fixture.py). Hard metal: flat shading.
# Run headless: blender -b -P tools/models/anvil_base.py -- game/models
# Sizes in metres. The die's top must stay MetalFactoryRig.ANVIL_TOP (1.5 m, where the hammer lands) and wider than the
# hammer's 2.2 m face; the body's top is MetalFactoryRig.ANVIL_SHELF. Made from scratch; no outside assets.
import math
import sys

import bpy

OUT_DIR = sys.argv[sys.argv.index("--") + 1]

# plinth (square side, height), body (square side, top height) and die (square side, top height), from the floor up
PLINTH = (3.6, 0.35)
BODY = (3.4, 1.2)
DIE = (2.4, 1.5)
# the die's chamfer, so it reads as forged steel and its top edge catches the light
DIE_CHAMFER = 0.06
AO_SAMPLES = 64


def box(bottom, top, side):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, (bottom + top) * 0.5))
	obj = bpy.context.object
	obj.scale = (side, side, top - bottom)
	bpy.ops.object.transform_apply(scale=True)
	return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
parts = [box(0.0, PLINTH[1], PLINTH[0]), box(PLINTH[1], BODY[1], BODY[0])]
die = box(BODY[1], DIE[1], DIE[0])
bevel = die.modifiers.new("bevel", "BEVEL")
bevel.width = DIE_CHAMFER
bevel.segments = 1
bpy.context.view_layer.objects.active = die
bpy.ops.object.modifier_apply(modifier="bevel")
parts.append(die)
bpy.ops.object.select_all(action="DESELECT")
for part in parts:
	part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
anvil = bpy.context.object
anvil.name = "anvil_base"

mesh = anvil.data
mesh.shade_flat()
ao = mesh.color_attributes.new("ao", "BYTE_COLOR", "CORNER")
mesh.color_attributes.active_color = ao
mesh.materials.append(bpy.data.materials.new("anvil_base"))
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
	filepath=OUT_DIR + "/anvil_base.glb",
	export_format="GLB",
	export_yup=True,
	export_apply=True,
	export_vertex_color="ACTIVE",
	export_cameras=False,
	export_lights=False,
	use_selection=True,
)
print("anvil_base triangles: %d" % sum(len(p.vertices) - 2 for p in mesh.polygons))
print("die top %.2f m, %.2f m wider than the hammer's face; shelf %.2f m" % (DIE[1], DIE[0] - 2.2, BODY[1]))
