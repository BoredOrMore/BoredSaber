# Shared by the model scripts here: bakes ambient occlusion into vertex colour red and exports one object as .glb for
# the game (Y up, transforms applied, no cameras or lights), with flat shading for hard metal. Faces a script marks in
# an integer face attribute "glow" are written into green (1) or blue (2), for the shader to light (EnvSolid's vents);
# a script may instead pass its own green per vertex (Monolith's clouds: height in the bank), and smooth shading.
# Import it from a script run by Blender with: sys.path.append(os.path.dirname(__file__)).
import math

import bpy

AO_SAMPLES = 64
# smart UV project: faces bending more than this many degrees go to separate islands, this far apart (UV units)
UV_ANGLE_LIMIT = 66.0
UV_MARGIN = 0.02


def bake_and_export(obj, out_dir, file_name, smooth=False, green=None, unwrap=False):
	"""Bakes occlusion into red and the glow marks into green and blue, then exports obj alone to out_dir/file_name.glb
	and prints its triangle count. smooth shades it smooth instead of flat; green, one value per vertex, replaces the
	glow mark in green (blue is then 0). unwrap gives it UVs (smart project), for the checker review."""
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	mesh = obj.data
	if unwrap:
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.smart_project(angle_limit=math.radians(UV_ANGLE_LIMIT), island_margin=UV_MARGIN)
		bpy.ops.object.mode_set(mode="OBJECT")
	if smooth:
		mesh.shade_smooth()
	else:
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
	glow = mesh.attributes.get("glow")
	for poly in mesh.polygons:
		mark = glow.data[poly.index].value if glow else 0
		for loop in poly.loop_indices:
			if green:
				col.data[loop].color = (ao.data[loop].color[0], green[mesh.loops[loop].vertex_index], 0.0, 1.0)
			else:
				col.data[loop].color = (ao.data[loop].color[0], 1.0 if mark == 1 else 0.0, 1.0 if mark == 2 else 0.0, 1.0)
	mesh.color_attributes.remove(mesh.color_attributes["ao"])
	if glow:
		mesh.attributes.remove(glow)
	mesh.color_attributes.active_color = mesh.color_attributes["Col"]
	mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
	bpy.ops.export_scene.gltf(
		filepath=out_dir + "/" + file_name + ".glb",
		export_format="GLB",
		export_yup=True,
		export_apply=True,
		export_vertex_color="ACTIVE",
		export_cameras=False,
		export_lights=False,
		use_selection=True,
	)
	print("%s triangles: %d" % (file_name, sum(len(p.vertices) - 2 for p in mesh.polygons)))
