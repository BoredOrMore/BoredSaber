extends Node
## Headset probe for the room-aware Mixed Reality plan (test build, not for merging).
## Logs what the OpenXR runtime tells us about the real room, tagged "RoomProbe:" in logcat.

## Seconds between room reports.
const REPORT_INTERVAL := 5.0
## How many reports to log before stopping.
const REPORT_COUNT := 12
## Pico runtime permission that the spatial entity (plane) data needs.
const SPATIAL_PERMISSION := "com.picovr.permission.SPATIAL_DATA"
## Capability singletons Godot 4.6 may register for OpenXR spatial entities.
const SPATIAL_SINGLETONS: Array[String] = [
	"OpenXRSpatialEntityExtension",
	"OpenXRSpatialPlaneTrackingCapability",
	"OpenXRSpatialAnchorCapability",
]

var _reports_left := REPORT_COUNT


## Starts the timed reports and asks for the spatial data permission.
func _ready() -> void:
	print("RoomProbe: granted permissions before request ", OS.get_granted_permissions())
	OS.request_permission(SPATIAL_PERMISSION)
	XRServer.tracker_added.connect(_on_tracker_added)
	var timer := Timer.new()
	timer.wait_time = REPORT_INTERVAL
	timer.timeout.connect(_report)
	add_child(timer)
	timer.start()


## Logs every new tracker so plane trackers show up the moment the runtime finds them.
func _on_tracker_added(tracker_name: StringName, type: int) -> void:
	print("RoomProbe: tracker added ", tracker_name, " type ", type)


## Logs the play area, the spatial capabilities and every plane the runtime reports.
func _report() -> void:
	_reports_left -= 1
	if _reports_left < 0:
		return
	print("RoomProbe: ---- report ", REPORT_COUNT - _reports_left, " ----")
	print("RoomProbe: granted permissions ", OS.get_granted_permissions())
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface == null:
		print("RoomProbe: no OpenXR interface")
		return
	print("RoomProbe: play area mode ", xr_interface.get_play_area_mode(), " points ", xr_interface.get_play_area())
	for singleton_name in SPATIAL_SINGLETONS:
		if not Engine.has_singleton(singleton_name):
			print("RoomProbe: singleton missing ", singleton_name)
			continue
		var singleton := Engine.get_singleton(singleton_name)
		var supported: Variant = "n/a"
		if singleton.has_method("is_supported"):
			supported = singleton.call("is_supported")
		elif singleton.has_method("is_spatial_anchor_supported"):
			supported = singleton.call("is_spatial_anchor_supported")
		print("RoomProbe: singleton ", singleton_name, " supported ", supported)
	var trackers := XRServer.get_trackers(XRServer.TRACKER_ANY)
	print("RoomProbe: ", trackers.size(), " trackers")
	for tracker_name: StringName in trackers:
		var tracker: XRTracker = trackers[tracker_name]
		if tracker is OpenXRPlaneTracker:
			var plane := tracker as OpenXRPlaneTracker
			var pose := plane.get_pose(&"default")
			print("RoomProbe: plane ", tracker_name, " label ", plane.get_plane_label(), " alignment ",
					plane.get_plane_alignment(), " size ", plane.get_bounds_size(), " at ",
					pose.get_adjusted_transform().origin if pose else "no pose")
		else:
			print("RoomProbe: tracker ", tracker_name, " ", tracker.get_class())
