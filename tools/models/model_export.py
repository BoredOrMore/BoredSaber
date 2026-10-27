# Shared by the model scripts here: bakes ambient occlusion into vertex colour red and exports one object as .glb for
# the game (Y up, transforms applied, no cameras or lights), with flat shading for hard metal. Faces a script marks in
# an integer face attribute "glow" are written into green (1) or blue (2), for the shader to light (EnvSolid's vents).
# Import it from a script run by Blender with: sys.path.append(os.path.dirname(__file__)).
import bpy

AO_SAMPLES = 64


def bake_and_export(obj, out_dir, file_name):
	"""Bakes occlusion into red and the glow marks into green and blue, then exports obj alone to out_dir/file_name.glb
	and prints its triangle count."""
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
	glow = mesh.attributes.get("glow")
	for poly in mesh.polygons:
		mark = glow.data[poly.index].value if glow else 0
		for loop in poly.loop_indices:
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
