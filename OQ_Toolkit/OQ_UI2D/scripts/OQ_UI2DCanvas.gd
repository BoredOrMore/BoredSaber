@tool
extends Node3D
class_name OQ_UI2DCanvas

var ui_control: Control

@onready var viewport := $SubViewport as SubViewport
@onready var ui_area := $UIArea as Area3D
var ui_collisionshape: CollisionShape3D

@export var editor_live_update := false

@export var transparency: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

# set to true to prevent UIRayCast marker from colliding with canvas
@export var disable_collision := false
@export var update_only_on_input := false
## Metres from the panel's centre to the point it curves around, the player's eye (owner, 2026-10-27: a curved
## horseshoe menu, text the same size across a panel; 2026-10-28: curved left to right only); 0 keeps it flat. A
## curved panel is a slice of an upright cylinder bending toward the viewer on +z, keeps its width as arc length,
## and its pointer hits are mapped back along the arc (helper_UIArea).
@export var curve_radius := 0.0
## Columns of quads along a curved panel's arc (one row: it is straight up and down).
const CURVE_COLUMNS := 32
const CURVE_ROWS := 1
## Cut the panel's see-through pixels (its rounded corners, drawn by the root control's style) instead of blending
## them: alpha scissor, smoothed by MSAA's alpha to coverage, so nothing is drawn twice. Only for a panel whose
## pixels are opaque but its corners (a translucent pixel would be cut).
@export var round_corners := false

var mesh_material: StandardMaterial3D
@onready var mesh_instance := $UIArea/UIMeshInstance as MeshInstance3D


var ui_size := Vector2.ZERO

func _get_configuration_warnings() -> PackedStringArray:
	if (ui_control == null): return PackedStringArray(["Need a Control node as child."])
	return PackedStringArray()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey):
		viewport.push_input(event)
		_input_update()


func find_child_control() -> void:
	ui_control = null
	for c in get_children():
		if c is Control:
			ui_control = c
			break

func update_size() -> void:
	ui_size = ui_control.get_size()
	if (ui_area != null):
		if curve_radius > 0.0:
			_build_curve()
		else:
			ui_area.scale.x = ui_size.x * vr.UI_PIXELS_TO_METER
			ui_area.scale.y = ui_size.y * vr.UI_PIXELS_TO_METER
	if (viewport != null):
		viewport.set_size(ui_size)

## The panel's size in metres (its pixels at this canvas's scale).
func curve_size() -> Vector2:
	var scale := global_transform.basis.get_scale() if is_inside_tree() else Vector3.ONE
	return Vector2(ui_size.x * vr.UI_PIXELS_TO_METER * scale.x, ui_size.y * vr.UI_PIXELS_TO_METER * scale.y)

## A curved panel: the area works in metres (it undoes the canvas's scale), its mesh and collision a slice of a
## cylinder of curve_radius whose axis is curve_radius in front of the panel's centre (through the eye).
func _build_curve() -> void:
	var scale := global_transform.basis.get_scale()
	ui_area.transform = Transform3D(Basis.from_scale(Vector3.ONE / scale), Vector3.ZERO)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row in CURVE_ROWS + 1:
		for column in CURVE_COLUMNS + 1:
			var uv := Vector2(float(column) / CURVE_COLUMNS, float(row) / CURVE_ROWS)
			vertices.append(curve_point(uv * Vector2(ui_size)))
			uvs.append(uv)
	var indices := PackedInt32Array()
	for row in CURVE_ROWS:
		for column in CURVE_COLUMNS:
			var a := row * (CURVE_COLUMNS + 1) + column
			var b := a + CURVE_COLUMNS + 1
			indices.append_array([a, a + 1, b, b, a + 1, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.transform = Transform3D.IDENTITY
	var faces := PackedVector3Array()
	for index in indices:
		faces.append(vertices[index])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	($UIArea/UICollisionShape as CollisionShape3D).shape = shape

## A pixel of the curved panel as a point on it (in the area's metres): its x along the arc, its y straight.
func curve_point(pixel: Vector2) -> Vector3:
	var size := curve_size()
	var yaw := (pixel.x / ui_size.x - 0.5) * size.x / curve_radius
	return Vector3(curve_radius * sin(yaw), (0.5 - pixel.y / ui_size.y) * size.y, curve_radius * (1.0 - cos(yaw)))

## A point on the curved panel (in the area's metres) as a pixel of the panel (curve_point's inverse).
func curve_pixel(local: Vector3) -> Vector2:
	var size := curve_size()
	var yaw := atan2(local.x, curve_radius - local.z)
	return Vector2((yaw * curve_radius / size.x + 0.5) * ui_size.x, (0.5 - local.y / size.y) * ui_size.y)

func _hide() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()

func _show() -> void:
	if !update_only_on_input:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_input_update()
	show()

func _ready() -> void:
	mesh_material = mesh_instance.material_override as StandardMaterial3D
	mesh_material.albedo_texture = viewport.get_texture()
	# only enable transparency when necessary as it is significantly slower than non-transparent rendering
	mesh_material.transparency = transparency
	if round_corners and transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mesh_material.alpha_scissor_threshold = 0.5
		mesh_material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	
	if Engine.is_editor_hint():
		return

	find_child_control()

	if (!ui_control):
		vr.log_warning("No UI Control element found in OQ_UI2DCanvas: %s" % get_path())
		return
	
	update_size()
	
	# reparent at runtime so we render to the viewport
	ui_control.get_parent().remove_child(ui_control)
	viewport.add_child(ui_control)
	ui_control.visible = true # set visible here as it might was set invisible for editing multiple controls
	
	ui_collisionshape = $UIArea/UICollisionShape as CollisionShape3D
	
	
func _editor_update_preview() -> void:
	var preview_node := ui_control.duplicate(DUPLICATE_USE_INSTANTIATION) as Control
	preview_node.visible = true
	
	for c in viewport.get_children():
		viewport.remove_child(c)
		c.queue_free()
	
	viewport.add_child(preview_node)

func _input_update() -> void:
	if update_only_on_input:
		($update_once as UpdateViewport).update_once(viewport)
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE

func _process(_dt: float) -> void:
	
	if !Engine.is_editor_hint(): # not in edtior
		if disable_collision:
			ui_collisionshape.disabled = true
		else:
			# if we are invisible we need to disable the collision shape to avoid interaction with the UIRayCast
			ui_collisionshape.disabled = not is_visible_in_tree()
		return

	# Not sure if it is a good idea to do this in the _process but at the moment it seems to 
	# be the easiest to show the actual canvas size inside the editor
	var last := ui_control
	find_child_control()
	if (ui_control != null):
		if (last != ui_control || ui_size != ui_control.get_size()):
			#print("Editor update size of ", name);
			update_size()
			_editor_update_preview()
		elif (editor_live_update):
			_editor_update_preview()
