# A Helper to make UIs work on a Area object
extends UIRaycastTarget

# Member variables
@onready var parent := get_parent() as OQ_UI2DCanvas
@onready var viewport := parent.get_node("SubViewport") as SubViewport

var last_pos2d := Vector2(INF, INF)
## The pointer's button is down (a click or a drag in progress): every move may change the look then.
var _held := false
## The control under the pointer at the last redraw: moving within it changes nothing on screen.
var _last_hovered: Control


func ui_raycast_hit_event(pos: Vector3, click: bool, release: bool) -> void:
	# note: this transform assumes that the unscaled area is [-0.5, -0.5] to [0.5, 0.5] in size
	var local_position := to_local(pos)
	var pos2d := Vector2(local_position.x, -local_position.y)
	pos2d = pos2d + Vector2(0.5, 0.5)
	pos2d.x *= viewport.size.x
	pos2d.y *= viewport.size.y
	
	if (click || release):
		var e := InputEventMouseButton.new()
		e.pressed = click
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos2d
		e.global_position = pos2d
		
		viewport.push_input(e)
		parent._input_update()
		_held = click
	elif (last_pos2d != Vector2(INF, INF) && last_pos2d != pos2d):
		var e := InputEventMouseMotion.new()
		e.relative = pos2d - last_pos2d
		e.velocity = (pos2d - last_pos2d) / 16.0 #?? chose an arbitrary scale here for now
		e.global_position = pos2d
		e.position = pos2d
		
		viewport.push_input(e)
		# redraw (a whole SubViewport render) only when the move can change the look: another control under the
		# pointer, a button held (dragging a list or slider), or a list whose rows light up one by one
		var hovered := viewport.gui_get_hovered_control()
		if _held or hovered != _last_hovered or hovered is ItemList:
			parent._input_update()
		_last_hovered = hovered
	else:
		# a marker in the log, to line performance measurements up with pointing at this panel
		if last_pos2d == Vector2(INF, INF):
			print("Pointer on %s" % parent.name)
	last_pos2d = pos2d

## The pointer left the panel: logged, and the next hit starts a new pointing.
func ui_raycast_exit() -> void:
	print("Pointer off %s" % parent.name)
	last_pos2d = Vector2(INF, INF)
