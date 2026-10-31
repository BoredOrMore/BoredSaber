# This file needs to be set as AutoLoad script in your Project Settings and called 'vr'
# It contains all the glue code and helper functions to make individual features work together.
extends Node

signal pose_recentered

const UI_PIXELS_TO_METER := 1.0 / 1024 # defines the (auto) size of UI elements in 3D
## CPU and GPU levels asked of the runtime while a song plays (XR_EXT_performance_settings), so it doesn't clock down
## mid-song; untuned, being measured on the Pico 4 (2026-10-31).
const PLAY_PERF_LEVEL := OpenXRInterface.PERF_SETTINGS_LEVEL_SUSTAINED_HIGH
## CPU and GPU levels asked in the menus, to save battery and heat.
const MENU_PERF_LEVEL := OpenXRInterface.PERF_SETTINGS_LEVEL_SUSTAINED_LOW

var toolkit_version := "0.4.3_dev"

var inVR := false
var active_arvr_interface_name := "Unknown"

# we use this to be position indepented of the OQ_Toolkit directory
# so make sure to always use this if instancing nodes/features via code
@onready var oq_base_dir := (get_script() as Script).get_path().get_base_dir()

###############################################################################
# VR logging systems
###############################################################################

enum VRLogType {
	INFO,
	WARNING,
	ERROR
}

class VRLogEntry:
	var type: VRLogType
	var message: String
	var times_repeated: int
	
	@warning_ignore("shadowed_variable")
	static func from(type: VRLogType, message: String, times_repeated: int) -> VRLogEntry:
		var entry := VRLogEntry.new()
		entry.type = type
		entry.message = message
		entry.times_repeated = times_repeated
		return entry

var _log_buffer: Array[VRLogEntry] = []
var _log_buffer_index := -1
var _log_buffer_count := 0

func _init_vr_log() -> void:
	for _i in range(1024):
		_log_buffer.append(VRLogEntry.from(VRLogType.INFO, "", 0))

func _append_to_log(type: VRLogType, message: String) -> void:
	if (_log_buffer.size() == 0): _init_vr_log()
	
	if _log_buffer_index >= 0 && _log_buffer[_log_buffer_index].message == message:
		_log_buffer[_log_buffer_index].times_repeated += 1
	else:
		_log_buffer_index = (_log_buffer_index+1) % _log_buffer.size()
		_log_buffer[_log_buffer_index].type = type
		_log_buffer[_log_buffer_index].message = message
		_log_buffer[_log_buffer_index].times_repeated = 1
		_log_buffer_count = min(_log_buffer_count+1, _log_buffer.size())

func log_info(s: String) -> void:
	_append_to_log(VRLogType.INFO, s);
	print(s);

func log_warning(s: String) -> void:
	_append_to_log(VRLogType.WARNING, s);
	print("WARNING: ", s);

func log_error(s: String) -> void:
	_append_to_log(VRLogType.ERROR, s);
	print("ERROR: : ", s);

func log_file_error(error: Error, filename: String, where: String) -> void:
	var message := "[color=red]Uh oh, you messed up[/color] [rainbow]real bad![/rainbow]\nError with file [color=cyan][url]%s[/url][/color] in [color=yellow]%s[/color]:\n[color=magenta]" % [filename, where]
	match error:
		ERR_FILE_ALREADY_IN_USE:
			message += "File already in use"
		ERR_FILE_BAD_DRIVE:
			message += "Bad drive"
		ERR_FILE_BAD_PATH:
			message += "Bad path"
		ERR_FILE_CANT_OPEN:
			message += "Can't open"
		ERR_FILE_CANT_READ:
			message += "Can't read"
		ERR_FILE_CANT_WRITE:
			message += "Can't write"
		ERR_FILE_CORRUPT:
			message += "File is corrupt"
		ERR_FILE_NOT_FOUND:
			message += "File not found"
		ERR_FILE_NO_PERMISSION:
			message += "No permission"
		_:
			message += "Turbo-screwed! Unrecognized error code %s" % error
	message += "[/color]"
	_append_to_log(VRLogType.ERROR, message)
	print_rich(message)


# returns the current player height based on the difference between
# the height of origin and camera; this assumes that tracking is floor level
func get_current_player_height() -> float:
	return vrCamera.global_transform.origin.y - vrOrigin.global_transform.origin.y;

###############################################################################
# Some generic useful helper functions
###############################################################################


# helper function to read and parse a JSON file and return the contents as a dictionary
# Note: if you want to use it with .json files that are part of your project you 
#       need to make sure they are exported by including *.json in the 
#       ExportSettings->Resources->Filters options
# TODO: Dictionary keys and values are currently only weak typed.
# if it's possible to make them strong-typed in the future, do that.
## Sets the display to 72 Hz (90 with Settings.refresh_90) if the headset offers it, else its highest rate, and the
## physics to the same rate.
func apply_refresh_rate() -> void:
	if not xr_interface or not xr_interface.has_method(&"get_available_display_refresh_rates"):
		return
	var fps : Array = xr_interface.get_available_display_refresh_rates()
	log_info("avaliable fps: "+str(fps))
	if fps.is_empty():
		return
	var wanted := 90.0 if Settings.refresh_90 else 72.0
	var rate: float = wanted if fps.has(wanted) else float(fps[fps.size() - 1])
	xr_interface.set_display_refresh_rate(rate)
	Engine.set_physics_ticks_per_second(int(rate))
	log_info("display refresh rate " + str(rate))

## Asks the OpenXR runtime for the CPU and GPU levels of play (`playing`) or of the menus; does nothing on other
## interfaces, and the runtime ignores it without XR_EXT_performance_settings.
func set_play_performance(playing: bool) -> void:
	var openxr := xr_interface as OpenXRInterface
	if not openxr or not openxr.is_initialized():
		return
	var level := PLAY_PERF_LEVEL if playing else MENU_PERF_LEVEL
	openxr.set_cpu_level(level)
	openxr.set_gpu_level(level)
	log_info("performance level " + str(level))

func load_json_file(filename: String) -> Dictionary:
	var save := FileAccess.open(filename, FileAccess.READ)
	if save:
		var r := JSON.parse_string(save.get_as_text()) as Dictionary
		save.close()
		return r
	else:
		log_file_error(FileAccess.get_open_error(), filename, "load_json_file in vr_autoload.gd")
		return {}

###############################################################################
# Controller Handling
###############################################################################

# Global accessors to the tracked vr objects; they will be set by the scripts attached
# to the OQ_ objects
var leftController: BeepSaberController
var rightController: BeepSaberController
var vrOrigin: XROrigin3D
var vrCamera: XRCamera3D

# these two variable point to leftController/rightController
# and are swapped when calling
var dominantController: XRController3D = rightController
var nonDominantController: XRController3D = leftController

func set_dominant_controller_left(is_left_handed: bool) -> void:
	if (is_left_handed):
		dominantController = leftController
		nonDominantController = rightController
	else:
		dominantController = rightController
		nonDominantController = leftController
		
func is_dominant_controller_left() -> bool:
	return dominantController == leftController

###############################################################################
# Global defines used across the toolkit
###############################################################################

var _need_settings_refresh := false

func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_RESUMED):
		_need_settings_refresh = true

###############################################################################
# Scene Switching Helper Logic
###############################################################################

var _active_scene_path: String # this assumes that only a single scene will ever be switched

###############################################################################
# Main Funcitonality for initialize and process
###############################################################################

var webxr_initializer: CanvasLayer
var xr_interface: XRInterface

func _on_openxr_pose_recentered() -> void:
	emit_signal("pose_recentered")

func initialize(origin: XROrigin3D, camera: XRCamera3D, left_hand: BeepSaberController, right_hand: BeepSaberController,
	render_scale: float = 1.0) -> void:
	_init_vr_log()
	
	vrOrigin = origin
	vrCamera = camera
	leftController = left_hand
	rightController = right_hand
	
	if OS.get_name() == "Web":
		var webxr := (load("res://game/scripts/webxr/webxr_initializer.tscn") as PackedScene).instantiate() as CanvasLayer
		add_child(webxr)
		webxr_initializer = webxr
		return
	
	xr_interface = XRServer.find_interface("OpenXR") as XRInterface
	if xr_interface: xr_interface.render_target_size_multiplier = render_scale
	if xr_interface and xr_interface.is_initialized():
		log_info("OpenXR initialised successfully")
		apply_refresh_rate()
		
		
		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		xr_interface.pose_recentered.connect(_on_openxr_pose_recentered)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		inVR = true
		MixedReality.set_mixed_reality(Settings.mixed_reality)

	else:
		log_info("OpenXR not initialized, please check if your headset is connected")
		inVR = false
