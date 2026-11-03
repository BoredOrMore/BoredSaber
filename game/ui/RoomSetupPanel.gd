extends Panel
class_name RoomSetupPanel
## "Set up your room": before mixed reality play, the player scans the room in PICO's own screen (the headset only
## recognises the room there) and checks the outline drawn over it (Bored, 2026-11-02; wording approved 07:25Z).
## "Play without room" turns mixed reality off, so a failed scan never traps the player.

## The setup is done: the room was accepted, or mixed reality was turned off.
signal close_requested()

enum Step { ASK, SCANNING, FOUND, MISSING }

const SETUP_TITLE := "Set up your room"
const ASK_TEXT := "Press Scan room, then look around slowly until the headset finds your room. Press Back to come back here."
const SCANNING_TEXT := "Looking for your room…"
const FOUND_TITLE := "Is this your room?"
const FOUND_TEXT := "Found %s and %s. Notes will come in through the glowing frame."
const MISSING_TITLE := "Couldn't find your room"
const MISSING_TEXT := "Scan again and look around until the headset finds it."
const SCAN_TEXT := "Scan room"
const SCAN_AGAIN_TEXT := "Scan again"
const PLAY_TEXT := "Play"
const SKIP_TEXT := "Play without room"

@onready var _title := $Margin/VBox/Title as Label
@onready var _body := $Margin/VBox/Body as Label
@onready var _primary := $Margin/VBox/Buttons/Primary_Button as Button
@onready var _secondary := $Margin/VBox/Buttons/Secondary_Button as Button

var _step := Step.ASK


## Hooks up the button sounds and the room scan's answers.
func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	MixedReality.room_found.connect(_on_room_found)
	MixedReality.room_missing.connect(_on_room_missing)
	_show(Step.ASK)


## Starts the setup at its first step.
func start() -> void:
	_show(Step.ASK)


## Shows `step`'s words and buttons, and the room's outline only while the player checks it.
func _show(step: Step, walls := 0, furniture := 0) -> void:
	_step = step
	_title.text = SETUP_TITLE
	_primary.disabled = false
	_secondary.text = SKIP_TEXT
	match step:
		Step.ASK:
			_body.text = ASK_TEXT
			_primary.text = SCAN_TEXT
		Step.SCANNING:
			_body.text = SCANNING_TEXT
			_primary.text = SCAN_TEXT
			_primary.disabled = true
		Step.FOUND:
			_title.text = FOUND_TITLE
			_body.text = FOUND_TEXT % [_count(walls, "wall", "walls"), _count(furniture, "piece of furniture", "pieces of furniture")]
			_primary.text = PLAY_TEXT
			_secondary.text = SCAN_AGAIN_TEXT
		Step.MISSING:
			_title.text = MISSING_TITLE
			_body.text = MISSING_TEXT
			_primary.text = SCAN_AGAIN_TEXT
	MixedReality.show_room_outline(step == Step.FOUND)


## Returns "1 wall" or "5 walls".
static func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## Shows what the scan found, if the player is waiting for it.
func _on_room_found(pieces: Array) -> void:
	if _step != Step.SCANNING:
		return
	var walls := 0
	var furniture := 0
	for piece: Dictionary in pieces:
		walls += 1 if piece["label"] == RoomOutline.LABEL_WALL else 0
		furniture += 1 if piece["label"] == RoomOutline.LABEL_FURNITURE else 0
	_show(Step.FOUND, walls, furniture)


## Says no room was found, if the player is waiting for the scan.
func _on_room_missing() -> void:
	if _step == Step.SCANNING:
		_show(Step.MISSING)


## Scan room / Scan again, or Play once the room is found.
func _on_primary_pressed() -> void:
	if _step == Step.FOUND:
		MixedReality.show_room_outline(false)
		close_requested.emit()
		return
	_show(Step.SCANNING)
	MixedReality.scan_room()


## Scan again once the room is found, otherwise Play without room (mixed reality off).
func _on_secondary_pressed() -> void:
	if _step == Step.FOUND:
		_show(Step.SCANNING)
		MixedReality.scan_room()
		return
	Settings.mixed_reality = false
	Settings.save()
	MixedReality.set_mixed_reality(false)
	close_requested.emit()
