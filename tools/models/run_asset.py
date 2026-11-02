# One command per model round (owner, 2026-11-02; doc/assets/README.md, "Runner"): reads doc/assets/<asset>/spec.json,
# runs the asset's build script, reloads every .glb it wrote and checks it (triangles, size, vertex colour and no
# textures, the notes' path), renders one small contact sheet (front, side, top, three-quarter) and writes a short
# report.md, so a round costs one report and one picture to read. Also appends one line to doc/assets/runs.csv.
# Run from the repo root:
#   blender -b -P tools/models/run_asset.py -- <asset> [--variant A] [--out DIR] [--no-godot]   (dev Mac)
#   python3 tools/models/run_asset.py <asset> [...]                                            (pip bpy, cloud)
# --variant sets ASSET_VARIANT for the build script (blockouts); --out writes the .glb files there instead of the
# spec's out_dir; --no-godot skips the Godot import check. Exits 1 when any check fails.
import csv
import datetime
import json
import math
import os
import runpy
import shutil
import subprocess
import sys
import time

import bpy
import numpy
from mathutils import Matrix, Vector

ASSETS_DIR = "doc/assets"
RUNS_CSV = "doc/assets/runs.csv"
DEFAULT_OUT_DIR = "game/models"
# measured size may differ from the spec's by this share of each side
SIZE_TOLERANCE = 0.05
# the notes' path (memory rule, 2026-10-31): notes fly in from FLY_DISTANCE (Cuttable.FLY_DISTANCE, 300 m) plus a
# margin; nothing may stand inside it between these heights (Godot y, m)
NOTE_PATH_REACH = 320.0
NOTE_PATH_Y = (-5.0, 30.0)
# "standard": the corridor ahead of the player along -z, this far each side of the track's centre (m). Untuned: set
# from the track's width plus walls' reach, not from a measured rule; widen it if a stage needs more room.
NOTE_CORRIDOR_HALF_WIDTH = 6.0
# contact sheet: one square view this many pixels a side, Cycles samples per view
VIEW_PX = 320
VIEW_SAMPLES = 8
# the review look: grey from baked occlusion (vertex red) times a light from REVIEW_KEY (Blender axes: from the
# front-right and above), faces turned away at REVIEW_FACING_FLOOR, on a dark grey ground
REVIEW_BACKGROUND = 0.18
REVIEW_FACING_FLOOR = 0.3
REVIEW_KEY = (0.3, -0.5, 0.8)
VIEWS = ("front", "side", "top", "three_quarter")


def main():
	"""Runs one round for the asset named on the command line and exits 1 if any check failed."""
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	asset = args[0]
	variant = _option(args, "--variant", "")
	started = time.time()
	spec_path = os.path.join(ASSETS_DIR, asset, "spec.json")
	spec = _load_spec(spec_path)
	run_dir = os.path.join(ASSETS_DIR, asset, "run", variant) if variant else os.path.join(ASSETS_DIR, asset, "run")
	os.makedirs(run_dir, exist_ok=True)
	out_dir = _option(args, "--out", spec.get("out_dir", DEFAULT_OUT_DIR))
	os.makedirs(out_dir, exist_ok=True)
	lines = []
	build_ok = _build(spec, out_dir, variant, run_dir, lines)
	results = []
	if build_ok:
		for name in spec["outputs"]:
			results.append(_check_output(spec, name, out_dir, run_dir, lines))
		if "--no-godot" not in args and out_dir == DEFAULT_OUT_DIR:
			_godot_import(spec["outputs"], run_dir, lines)
		else:
			lines.append("NOT CHECKED godot import (--no-godot or --out outside game/models)")
	failed = not build_ok or any(line.startswith("FAIL") for line in lines)
	seconds = time.time() - started
	_write_report(spec, asset, variant, run_dir, lines, failed, seconds)
	_append_run(asset, variant, spec, results, failed, seconds)
	print("run_asset %s -> %s" % ("FAIL" if failed else "PASS", os.path.join(run_dir, "report.md")))
	sys.exit(1 if failed else 0)


def _option(args, name, default):
	"""Returns the value after `name` in args, or default."""
	return args[args.index(name) + 1] if name in args else default


def _load_spec(path):
	"""Returns the spec at path, after checking the fields a round needs; stops the run on a bad spec."""
	with open(path) as f:
		spec = json.load(f)
	for key in ("asset", "script", "outputs", "budget_tris", "note_path"):
		if key not in spec:
			sys.exit("spec %s: missing %s" % (path, key))
	if spec["note_path"] not in ("none", "standard", "all"):
		sys.exit("spec %s: note_path must be none, standard or all" % path)
	if spec["note_path"] != "none" and not spec.get("placements"):
		sys.exit("spec %s: note_path %s needs placements" % (path, spec["note_path"]))
	for name in spec["outputs"]:
		if name not in spec["budget_tris"]:
			sys.exit("spec %s: no budget_tris for %s" % (path, name))
	return spec


def _build(spec, out_dir, variant, run_dir, lines):
	"""Runs the build script in this process with out_dir as its argument; its output goes to run_dir/build.log.
	Returns whether it finished."""
	os.environ["ASSET_VARIANT"] = variant
	saved_argv = sys.argv
	sys.argv = [spec["script"], "--", out_dir]
	log_path = os.path.join(run_dir, "build.log")
	saved_out = os.dup(1)
	try:
		with open(log_path, "w") as log:
			sys.stdout.flush()
			os.dup2(log.fileno(), 1)
			runpy.run_path(spec["script"], run_name="__main__")
			sys.stdout.flush()
		ok = True
		lines.append("PASS build %s" % spec["script"])
	except BaseException as error:
		ok = False
		lines.append("FAIL build %s: %s (see build.log)" % (spec["script"], repr(error)[:200]))
	finally:
		os.dup2(saved_out, 1)
		os.close(saved_out)
		sys.argv = saved_argv
	return ok


def _check_output(spec, name, out_dir, run_dir, lines):
	"""Reloads out_dir/name.glb, checks it against the spec and renders its contact sheet. Returns its triangles."""
	path = os.path.join(out_dir, name + ".glb")
	if not os.path.exists(path):
		lines.append("FAIL %s: %s was not written" % (name, path))
		return {"name": name, "tris": 0}
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=path)
	meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
	if not meshes:
		lines.append("FAIL %s: no mesh in the .glb" % name)
		return {"name": name, "tris": 0}
	tris = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in meshes)
	budget = spec["budget_tris"][name]
	lines.append("%s %s triangles %d / budget %d" % ("PASS" if tris <= budget else "FAIL", name, tris, budget))
	low, high = _bounds(meshes)
	# Blender z up -> Godot y up: Godot size (x, y, z) = Blender (x, z, y)
	size = (high.x - low.x, high.z - low.z, high.y - low.y)
	want = spec.get("size_m", {}).get(name)
	if want:
		off = max(abs(s - w) / w for s, w in zip(size, want) if w > 0)
		lines.append("%s %s size %.2f x %.2f x %.2f m (spec %s, worst %.0f%% off)" % (
			"PASS" if off <= SIZE_TOLERANCE else "FAIL", name, size[0], size[1], size[2], want, off * 100.0))
	else:
		lines.append("NOT CHECKED %s size %.2f x %.2f x %.2f m (no size_m in spec)" % (name, *size))
	_check_colour(spec, name, meshes, lines)
	_check_note_path(spec, name, meshes, lines)
	_render_sheet(name, meshes, low, high, run_dir)
	return {"name": name, "tris": tris}


def _bounds(meshes):
	"""Returns the world-space corners (low, high) of every vertex in meshes."""
	points = [obj.matrix_world @ v.co for obj in meshes for v in obj.data.vertices]
	low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
	high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
	return low, high


def _check_colour(spec, name, meshes, lines):
	"""Checks the colour rule: vertex colour Col present and no image textures, unless the spec allows textures."""
	images = [image.name for image in bpy.data.images if image.source in ("FILE", "PACKED", "GENERATED")]
	if images and not spec.get("textures_allowed", False):
		lines.append("FAIL %s textures %s (vertex colour only; textures_allowed needs the owner's OK)" % (name, images))
	else:
		lines.append("PASS %s textures: %s" % (name, ", ".join(images) if images else "none"))
	missing = [obj.name for obj in meshes if not obj.data.color_attributes]
	if spec.get("vertex_colour", True):
		lines.append("%s %s vertex colour%s" % ("FAIL" if missing else "PASS", name,
			" missing on " + ", ".join(missing) if missing else " on every mesh"))


def _check_note_path(spec, name, meshes, lines):
	"""Checks that no triangle of any placement stands in the notes' path (vertices, edge midpoints and centre)."""
	mode = spec["note_path"]
	if mode == "none":
		lines.append("NOT CHECKED %s notes' path (note_path none: not placed in a stage)" % name)
		return
	hits = 0
	worst = ""
	for place in spec["placements"].get(name, []):
		x, y, z, yaw = place[0], place[1], place[2], place[3]
		scale = place[4] if len(place) > 4 else 1.0
		# Godot (x, y, z) and yaw about y -> Blender (x, -z, y) and yaw about z
		to_world = Matrix.Translation((x, -z, y)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(scale, 4)
		for obj in meshes:
			matrix = to_world @ obj.matrix_world
			verts = [matrix @ v.co for v in obj.data.vertices]
			for poly in obj.data.polygons:
				corners = [verts[i] for i in poly.vertices]
				samples = corners + [(a + b) * 0.5 for a, b in zip(corners, corners[1:] + corners[:1])]
				samples.append(sum(corners, Vector()) / len(corners))
				for p in samples:
					if _in_note_path(mode, p.x, p.z, -p.y):
						hits += 1
						worst = worst or "(%.1f, %.1f, %.1f)" % (p.x, p.z, -p.y)
						break
	lines.append("%s %s notes' path (%s): %d triangles inside%s" % ("FAIL" if hits else "PASS", name, mode, hits,
		", first at Godot " + worst if hits else ""))


def _in_note_path(mode, x, y, z):
	"""Returns whether the Godot point (x, y, z) lies in the notes' path for mode."""
	if y < NOTE_PATH_Y[0] or y > NOTE_PATH_Y[1]:
		return False
	if mode == "all":
		return math.hypot(x, z) < NOTE_PATH_REACH
	return abs(x) < NOTE_CORRIDOR_HALF_WIDTH and -NOTE_PATH_REACH < z < NOTE_CORRIDOR_HALF_WIDTH


def _render_sheet(name, meshes, low, high, run_dir):
	"""Renders front, side, top and three-quarter views of meshes and joins them into run_dir/<name>_contact.png."""
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.samples = VIEW_SAMPLES
	scene.cycles.device = "CPU"
	scene.render.resolution_x = VIEW_PX
	scene.render.resolution_y = VIEW_PX
	scene.render.image_settings.file_format = "PNG"
	scene.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("review")
	world.color = (REVIEW_BACKGROUND,) * 3
	scene.world = world
	material = _review_material()
	for obj in meshes:
		obj.data.materials.clear()
		obj.data.materials.append(material)
	centre = (low + high) * 0.5
	extent = max((high - low).length, 0.01)
	camera = bpy.data.objects.new("review", bpy.data.cameras.new("review"))
	scene.collection.objects.link(camera)
	scene.camera = camera
	camera.data.type = "ORTHO"
	camera.data.ortho_scale = extent * 1.1
	camera.data.clip_end = extent * 10.0
	# camera directions from the model, Blender axes: front from -y (Godot +z, the model's front), side from +x, top
	directions = {"front": Vector((0, -1, 0)), "side": Vector((1, 0, 0)), "top": Vector((0, 0.001, 1)),
		"three_quarter": Vector((1, -1, 0.8)).normalized()}
	tiles = []
	for view in VIEWS:
		camera.location = centre + directions[view] * extent * 3.0
		camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
		path = os.path.join(run_dir, "%s_%s.png" % (name, view))
		scene.render.filepath = os.path.abspath(path)
		_quietly(lambda: bpy.ops.render.render(write_still=True), os.path.join(run_dir, "render.log"))
		image = bpy.data.images.load(os.path.abspath(path))
		tiles.append(numpy.array(image.pixels[:], dtype=numpy.float32).reshape(VIEW_PX, VIEW_PX, 4))
		bpy.data.images.remove(image)
		os.remove(path)
	# image rows run bottom to top: bottom row three-quarter and top, top row front and side
	sheet = numpy.concatenate((numpy.concatenate(tiles[2:], axis=1), numpy.concatenate(tiles[:2], axis=1)), axis=0)
	out = bpy.data.images.new("contact", VIEW_PX * 2, VIEW_PX * 2, alpha=True)
	out.pixels[:] = sheet.ravel()
	out.filepath_raw = os.path.abspath(os.path.join(run_dir, name + "_contact.png"))
	out.file_format = "PNG"
	out.save()


def _quietly(action, log_path):
	"""Runs action with the process's stdout appended to log_path (Blender's render log is long)."""
	sys.stdout.flush()
	saved = os.dup(1)
	with open(log_path, "a") as log:
		os.dup2(log.fileno(), 1)
		try:
			action()
		finally:
			sys.stdout.flush()
			os.dup2(saved, 1)
			os.close(saved)


def _review_material():
	"""Returns an emissive material: the baked occlusion (vertex red) as grey, times a light from REVIEW_KEY so each
	face of a box reads apart."""
	material = bpy.data.materials.new("review")
	nodes = material.node_tree.nodes
	links = material.node_tree.links
	nodes.clear()
	attribute = nodes.new("ShaderNodeVertexColor")
	split = nodes.new("ShaderNodeSeparateColor")
	geometry = nodes.new("ShaderNodeNewGeometry")
	facing = nodes.new("ShaderNodeVectorMath")
	facing.operation = "DOT_PRODUCT"
	facing.inputs[1].default_value = Vector(REVIEW_KEY).normalized()
	light = nodes.new("ShaderNodeMapRange")
	light.inputs["To Min"].default_value = REVIEW_FACING_FLOOR
	shade = nodes.new("ShaderNodeMath")
	shade.operation = "MULTIPLY"
	emission = nodes.new("ShaderNodeEmission")
	output = nodes.new("ShaderNodeOutputMaterial")
	links.new(attribute.outputs["Color"], split.inputs["Color"])
	links.new(geometry.outputs["Normal"], facing.inputs[0])
	links.new(facing.outputs["Value"], light.inputs["Value"])
	links.new(split.outputs[0], shade.inputs[0])
	links.new(light.outputs["Result"], shade.inputs[1])
	links.new(shade.outputs[0], emission.inputs["Strength"])
	links.new(emission.outputs["Emission"], output.inputs["Surface"])
	return material


def _godot_import(outputs, run_dir, lines):
	"""Imports the project with Godot (GODOT, else godot on PATH) and fails on errors that name an output."""
	godot = os.environ.get("GODOT") or shutil.which("godot")
	if not godot:
		lines.append("NOT CHECKED godot import (set GODOT or put godot on PATH)")
		return
	before = _editor_files()
	result = subprocess.run([godot, "--headless", "--path", ".", "--import"], capture_output=True, text=True)
	_undo_editor_noise(before, outputs)
	with open(os.path.join(run_dir, "godot.log"), "w") as log:
		log.write(result.stdout + result.stderr)
	errors = [line for line in (result.stdout + result.stderr).splitlines()
		if "ERROR" in line and any(name in line for name in outputs)]
	lines.append("%s godot import%s" % ("FAIL" if errors else "PASS", ": " + errors[0][:200] if errors else ""))


def _editor_files():
	"""Returns the .uid and .import files git sees as new or changed now."""
	status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], capture_output=True,
		text=True).stdout.splitlines()
	return {line[3:] for line in status if line.endswith((".uid", ".import"))}


def _undo_editor_noise(before, outputs):
	"""Reverts the .uid and .import files the import added or rewrote (root AGENTS.md: no editor rewrites in a
	commit), keeping the outputs' own .glb.import."""
	keep = {os.path.join(DEFAULT_OUT_DIR, name + ".glb.import") for name in outputs}
	for path in _editor_files() - before - keep:
		tracked = subprocess.run(["git", "ls-files", "--error-unmatch", path], capture_output=True).returncode == 0
		if tracked:
			subprocess.run(["git", "checkout", "-q", "--", path])
		else:
			os.remove(path)


def _write_report(spec, asset, variant, run_dir, lines, failed, seconds):
	"""Writes run_dir/report.md: the verdict, the spec's status and every check on one line."""
	with open(os.path.join(run_dir, "report.md"), "w") as f:
		f.write("# %s%s: %s\n\n" % (asset, " variant " + variant if variant else "", "FAIL" if failed else "PASS"))
		f.write("Status %s, owner pick %s, %s, %.0f s\n\n" % (spec.get("status", "?"), spec.get("owner_pick") or "-",
			datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"), seconds))
		for line in lines:
			f.write("- %s\n" % line)
		f.write("\nContact sheets: %s\n" % ", ".join(name + "_contact.png" for name in spec["outputs"]))


def _append_run(asset, variant, spec, results, failed, seconds):
	"""Appends this round to RUNS_CSV: when, which asset, the git commit, triangles, verdict and seconds."""
	commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
	new = not os.path.exists(RUNS_CSV)
	with open(RUNS_CSV, "a", newline="") as f:
		writer = csv.writer(f)
		if new:
			writer.writerow(["utc", "asset", "variant", "status", "commit", "triangles", "result", "seconds"])
		writer.writerow([datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"), asset, variant,
			spec.get("status", ""), commit, " ".join("%s=%d" % (r["name"], r["tris"]) for r in results),
			"FAIL" if failed else "PASS", "%.0f" % seconds])


main()
