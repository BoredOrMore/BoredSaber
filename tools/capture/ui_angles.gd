extends Node
## Measures every menu panel, button and line of text of the game scene as angles and distances from the player's eye
## (owner, 2026-10-27: everything the player looks at is worked out from their eye), against the limits in
## .claude/skills/vr-ui-design (section 2 and 3), and prints a Markdown report. Nothing is rendered, so the Mac
## camera's field of view plays no part.
## Run: godot --headless --path . res://tools/capture/ui_angles.tscn -- --out /tmp/ui_angles.md [--eye 1.6]

## comfort for reading and pressing: left/right, up, down (degrees from straight ahead)
const YAW_LIMIT := 30.0
const PITCH_UP := 20.0
const PITCH_DOWN := -12.0
## panel and pointer target distances (m)
const NEAR := 0.8
const FAR_READ := 2.5
const FAR_POINT := 3.0
## a pointer target's smaller side, degrees: under FAIL fails, under WARN is below the recommended 3
const TARGET_FAIL := 2.5
const TARGET_WARN := 3.0
## body text height (the font size), degrees: the main menu's playtested 28 px at scale 2.4, 2 m
const TEXT_BASE := 1.85

var eye := Vector3(0.0, 1.6, 1.0)
var rows: Array[String] = []
var problems: Array[String] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://ui_angles.md"
	if args.has("--out"):
		out = args[args.find("--out") + 1]
	if args.has("--eye"):
		eye.y = float(args[args.find("--eye") + 1])
	var game := (load("res://game/BeepSaber_Game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 120:
		await get_tree().process_frame
	var lift := eye.y - Hud.HUD_EYE.y
	if game.has_method(&"_place_menus"):
		# as on a game state change, for this eye
		game.set(&"menu_lift", lift)
		for path: NodePath in game.get(&"MENU_NODES"):
			var node := game.get_node_or_null(path) as Node3D
			if node:
				var rest: Dictionary = game.get(&"_menu_rest")
				if not rest.has(node):
					rest[node] = node.position
				node.position = rest[node] + Vector3(0.0, lift, 0.0)
	for canvas: OQ_UI2DCanvas in game.find_children("*", "OQ_UI2DCanvas", true, false):
		_canvas(game, canvas)
	for button: UIRaycastButton in game.find_children("*", "UIRaycastButton", true, false):
		_button3d(game, button)
	var report := "# Menu angles from the eye (%.2f m high)\n\n" % eye.y
	report += "Limits (vr-ui-design): within %d° left/right, %d° up, %d° down; panels %.1f-%.1f m (pointer targets to %.1f m); " % [
		YAW_LIMIT, PITCH_UP, -PITCH_DOWN, NEAR, FAR_READ, FAR_POINT]
	report += "targets at least %.1f° (%.1f° recommended); body text at least %.2f°.\n\n" % [TARGET_FAIL, TARGET_WARN, TEXT_BASE]
	report += "## Outside the limits (%d)\n\n" % problems.size() + "\n".join(problems) + "\n\n"
	report += "## Every panel\n\n| Panel | yaw | pitch | distance | width × height |\n|---|---|---|---|---|\n" + "\n".join(rows) + "\n"
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print("ui_angles OK -> ", out, " (", problems.size(), " outside the limits)")
	get_tree().quit()

## yaw (left -), pitch (up +) in degrees and distance of a world point from the eye
func _seen(point: Vector3) -> Vector3:
	var to := point - eye
	return Vector3(rad_to_deg(atan2(to.x, -to.z)), rad_to_deg(asin(to.y / to.length())), to.length())

## the angle in degrees a length (m) at a point covers from the eye
func _angle(length: float, point: Vector3) -> float:
	return rad_to_deg(2.0 * atan(length / 2.0 / (point - eye).length()))

func _canvas(game: Node, canvas: OQ_UI2DCanvas) -> void:
	var root := canvas.ui_control
	if root == null or canvas.ui_area == null:
		return
	var area := canvas.ui_area.global_transform
	var size := root.size
	var name_ := str(game.get_path_to(canvas))
	var centre := _place(area, size, size / 2.0)
	var seen := _seen(centre)
	var width: float = (_place(area, size, Vector2(size.x, size.y / 2.0)) - _place(area, size, Vector2(0, size.y / 2.0))).length()
	var height: float = (_place(area, size, Vector2(size.x / 2.0, 0)) - _place(area, size, Vector2(size.x / 2.0, size.y))).length()
	rows.append("| %s | %.1f° | %.1f° | %.2f m | %.0f° × %.0f° |" % [name_, seen.x, seen.y, seen.z, _angle(width, centre), _angle(height, centre)])
	var keyboard := name_.containsn("keyboard")
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var s := _seen(_place(area, size, corner))
		if absf(s.x) > YAW_LIMIT or s.y > PITCH_UP or (s.y < PITCH_DOWN and not keyboard):
			problems.append("- **%s**: a corner at %.0f° left/right, %.0f° up/down (panel reaches past the comfort zone)" % [name_, s.x, s.y])
			break
	if seen.z < NEAR or seen.z > FAR_READ:
		problems.append("- **%s**: %.2f m from the eye (panels %.1f-%.1f m)" % [name_, seen.z, NEAR, FAR_READ])
	if keyboard and seen.y < PITCH_DOWN:
		rows.append("| ↳ %s is a keyboard: %.0f° down is allowed for short typing if tilted to the eye |  |  |  |  |" % [name_, seen.y])
	var px_to_m: float = width / size.x
	for control: Control in root.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() and control.get_parent() != null and not _visible_below(root, control):
			continue
		var rect := control.get_global_rect()
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			continue
		var at := _place(area, size, rect.get_center())
		var label := "%s/%s" % [name_, root.get_path_to(control)]
		if control is BaseButton and not (control as BaseButton).disabled:
			var side: float = minf(rect.size.x, rect.size.y) * px_to_m
			var a := _angle(side, at)
			if a < TARGET_FAIL:
				problems.append("- **%s**: target %.1f° (at least %.1f°; %.0f px at %.2f m)" % [label, a, TARGET_FAIL, minf(rect.size.x, rect.size.y), (at - eye).length()])
			elif a < TARGET_WARN:
				problems.append("- %s: target %.1f° (under the recommended %.1f°)" % [label, a, TARGET_WARN])
		if control is Label or control is Button or control is RichTextLabel or control is LineEdit:
			var font_px := control.get_theme_font_size(&"normal_font_size" if control is RichTextLabel else &"font_size")
			var text_a := _angle(font_px * px_to_m, at)
			var text := _text_of(control)
			if text != "" and text_a < TEXT_BASE - 0.01:
				problems.append("- %s (\"%s\"): text %.2f° (%d px), under the %.2f° body baseline" % [label, text.left(30), text_a, font_px, TEXT_BASE])

## a pixel of a canvas's control (size px) on its quad, in the world
static func _place(area: Transform3D, size: Vector2, px: Vector2) -> Vector3:
	return area * Vector3(px.x / size.x - 0.5, 0.5 - px.y / size.y, 0.0)

## visible within its canvas (the canvas itself may be hidden in this state)
func _visible_below(root: Control, control: Control) -> bool:
	var node: Node = control
	while node and node != root:
		if node is CanvasItem and not (node as CanvasItem).visible:
			return false
		node = node.get_parent()
	return true

func _text_of(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is Button:
		return (control as Button).text
	if control is RichTextLabel:
		return (control as RichTextLabel).get_parsed_text()
	if control is LineEdit:
		return (control as LineEdit).placeholder_text
	return ""

func _button3d(game: Node, button: UIRaycastButton) -> void:
	var at := button.global_position
	var scale := button.global_transform.basis.get_scale()
	var side := minf(button.size.x * scale.x, button.size.y * scale.y)
	var seen := _seen(at)
	var label := str(game.get_path_to(button))
	rows.append("| %s (3D button) | %.1f° | %.1f° | %.2f m | %.1f° × %.1f° |" % [label, seen.x, seen.y, seen.z,
		_angle(button.size.x * scale.x, at), _angle(button.size.y * scale.y, at)])
	var a := _angle(side, at)
	if a < TARGET_FAIL:
		problems.append("- **%s** (3D button): target %.1f° (at least %.1f°)" % [label, a, TARGET_FAIL])
	elif a < TARGET_WARN:
		problems.append("- %s (3D button): target %.1f° (under the recommended %.1f°)" % [label, a, TARGET_WARN])
	if absf(seen.x) > YAW_LIMIT or seen.y > PITCH_UP or seen.y < PITCH_DOWN:
		problems.append("- **%s** (3D button): at %.0f° left/right, %.0f° up/down" % [label, seen.x, seen.y])
	if seen.z < NEAR or seen.z > FAR_POINT:
		problems.append("- **%s** (3D button): %.2f m away (pointer targets %.1f-%.1f m)" % [label, seen.z, NEAR, FAR_POINT])
