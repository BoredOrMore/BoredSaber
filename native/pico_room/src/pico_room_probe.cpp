#include "pico_room_probe.h"

#include <godot_cpp/classes/open_xrapi_extension.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <vector>

using namespace godot;

// Most anchors to load: a room has a floor, a ceiling, a few walls, doors, windows and furniture boxes.
static const uint32_t MAX_ANCHORS = 64;
// Load timeout handed to the runtime (unit undocumented; PICO's Unity SDK passes milliseconds-sized values).
static const uint64_t LOAD_TIMEOUT = 5000;
// PxrPersistLocation.Local: anchors saved on the headset.
static const int32_t LOCATION_LOCAL = 1;
// Frames between two checks for the load result (about 4 a second at 72 Hz).
static const int CHECK_EVERY_FRAMES = 18;
// Frames to wait for the load result before giving up (about 30 s at 72 Hz).
static const int MAX_WAIT_FRAMES = 72 * 30;
// Bytes of each runtime event to log raw.
static const int EVENT_DUMP_WORDS = 12;

/// Resolves one runtime function by name and logs whether the runtime has it.
template <typename T>
static T resolve(const Ref<OpenXRAPIExtension> &p_api, const char *p_name) {
	T function = (T)p_api->get_instance_proc_addr(p_name);
	UtilityFunctions::print("PicoRoom: fn ", p_name, function != nullptr ? " found" : " MISSING");
	return function;
}

Dictionary PicoRoomProbe::_get_requested_extensions() {
	Dictionary requested;
	requested["XR_BD_spatial_scene"] = (uint64_t)&spatial_scene;
	requested["XR_BD_room_scene"] = (uint64_t)&room_scene;
	requested["XR_BD_semi_auto_room_capture"] = (uint64_t)&semi_auto_room_capture;
	requested["XR_BD_spatial_anchor"] = (uint64_t)&spatial_anchor;
	requested["XR_BD_anchor_entity"] = (uint64_t)&anchor_entity;
	requested["XR_BD_anchor_entity_persistence"] = (uint64_t)&anchor_entity_persistence;
	requested["XR_BD_mr_management"] = (uint64_t)&mr_management;
	requested["XR_BD_async_task"] = (uint64_t)&async_task;
	return requested;
}

void PicoRoomProbe::_on_instance_created(uint64_t p_instance) {
	instance = p_instance;
	UtilityFunctions::print("PicoRoom: enabled spatial_scene ", spatial_scene, " room_scene ", room_scene,
			" semi_auto_room_capture ", semi_auto_room_capture, " spatial_anchor ", spatial_anchor, " anchor_entity ",
			anchor_entity, " anchor_entity_persistence ", anchor_entity_persistence, " mr_management ", mr_management,
			" async_task ", async_task);
	Ref<OpenXRAPIExtension> api = get_openxr_api();
	if (api.is_null()) {
		UtilityFunctions::push_error("PicoRoom: no OpenXR API");
		return;
	}
	load_anchor_entity = resolve<LoadAnchorEntity>(api, "xrLoadAnchorEntityBD");
	get_load_results = resolve<GetAnchorEntityLoadResults>(api, "xrGetAnchorEntityLoadResultsBD");
	get_scene_label = resolve<GetAnchorSceneLabel>(api, "xrGetAnchorSceneLabelBD");
	get_component_flags = resolve<GetAnchorComponentFlags>(api, "xrGetAnchorComponentFlagsBD");
	get_plane_boundary = resolve<GetAnchorPlaneBoundaryInfo>(api, "xrGetAnchorPlaneBoundaryInfoBD");
	get_box = resolve<GetAnchorBoxInfo>(api, "xrGetAnchorBoxInfoBD");
	locate_space = resolve<PFN_xrLocateSpace>(api, "xrLocateSpace");
	// Only logged, for the next step (starting a scan from inside the game).
	resolve<void *>(api, "xrStartSpatialSceneCaptureBD");
	resolve<void *>(api, "xrStartSemiAutoRoomCaptureBD");
	resolve<void *>(api, "xrStartRoomCaptureBD");
	resolve<void *>(api, "xrLoadRoomSceneBD");
	resolve<void *>(api, "xrGetBoundaryGeometryPICO");
}

void PicoRoomProbe::_on_session_created(uint64_t p_session) {
	session = p_session;
}

void PicoRoomProbe::_on_state_focused() {
	if (load_started) {
		return;
	}
	load_started = true;
	_start_load();
}

void PicoRoomProbe::_start_load() {
	if (load_anchor_entity == nullptr || get_load_results == nullptr) {
		UtilityFunctions::print("PicoRoom: load functions missing, nothing to try");
		done = true;
		return;
	}
	PxrAnchorEntityLoadInfo info = { MAX_ANCHORS, LOAD_TIMEOUT, LOCATION_LOCAL, nullptr, nullptr };
	const uint64_t handles[2] = { instance, session };
	const char *names[2] = { "instance", "session" };
	for (int i = 0; i < 2; i++) {
		uint64_t task = 0;
		XrResult result = load_anchor_entity(handles[i], &info, &task);
		UtilityFunctions::print("PicoRoom: load with ", names[i], " result ", (int64_t)result, " task ", (int64_t)task);
		if (XR_SUCCEEDED(result)) {
			handle = handles[i];
			task_id = task;
			return;
		}
	}
	done = true;
}

void PicoRoomProbe::_on_process() {
	if (!load_started || done) {
		return;
	}
	frames_waited++;
	if (frames_waited % CHECK_EVERY_FRAMES != 0) {
		return;
	}
	if (_read_results() || frames_waited >= MAX_WAIT_FRAMES) {
		if (frames_waited >= MAX_WAIT_FRAMES) {
			UtilityFunctions::print("PicoRoom: gave up waiting for the load result");
		}
		done = true;
	}
}

bool PicoRoomProbe::_read_results() {
	PxrAnchorEntityLoadResults count_query = { 0, 0, nullptr };
	XrResult result = get_load_results(handle, task_id, &count_query);
	if (result != last_result) {
		UtilityFunctions::print("PicoRoom: results count call result ", (int64_t)result, " count ",
				(int64_t)count_query.output_count);
		last_result = result;
	}
	if (XR_FAILED(result) || count_query.output_count == 0) {
		return false;
	}
	std::vector<PxrAnchorEntityLoadResult> anchors(count_query.output_count);
	PxrAnchorEntityLoadResults query = { (uint32_t)anchors.size(), 0, anchors.data() };
	result = get_load_results(handle, task_id, &query);
	UtilityFunctions::print("PicoRoom: results call result ", (int64_t)result, " count ", (int64_t)query.output_count);
	if (XR_FAILED(result)) {
		return true;
	}
	for (uint32_t i = 0; i < query.output_count && i < anchors.size(); i++) {
		_log_anchor(anchors[i].anchor);
	}
	UtilityFunctions::print("PicoRoom: done");
	return true;
}

void PicoRoomProbe::_log_anchor(uint64_t p_anchor) {
	int32_t label = -1;
	XrResult label_result = get_scene_label != nullptr ? get_scene_label(handle, p_anchor, &label) : XR_ERROR_FUNCTION_UNSUPPORTED;
	uint64_t flags = 0;
	XrResult flags_result = get_component_flags != nullptr ? get_component_flags(handle, p_anchor, &flags) : XR_ERROR_FUNCTION_UNSUPPORTED;
	UtilityFunctions::print("PicoRoom: anchor ", (int64_t)p_anchor, " label ", label, " (", (int64_t)label_result,
			") flags ", (int64_t)flags, " (", (int64_t)flags_result, ")");
	PxrAnchorPlaneBoundaryInfo plane = {};
	if (get_plane_boundary != nullptr) {
		XrResult result = get_plane_boundary(handle, p_anchor, &plane);
		UtilityFunctions::print("PicoRoom:   plane (", (int64_t)result, ") center ", plane.center[0], " ", plane.center[1],
				" ", plane.center[2], " size ", plane.width, " x ", plane.height);
	}
	PxrAnchorVolumeInfo box = {};
	if (get_box != nullptr) {
		XrResult result = get_box(handle, p_anchor, &box);
		UtilityFunctions::print("PicoRoom:   box (", (int64_t)result, ") center ", box.center[0], " ", box.center[1], " ",
				box.center[2], " extent ", box.extent[0], " ", box.extent[1], " ", box.extent[2]);
	}
	Ref<OpenXRAPIExtension> api = get_openxr_api();
	if (locate_space == nullptr || api.is_null()) {
		return;
	}
	XrSpaceLocation location = { XR_TYPE_SPACE_LOCATION };
	XrResult result = locate_space((XrSpace)p_anchor, (XrSpace)api->get_play_space(),
			(XrTime)api->get_predicted_display_time(), &location);
	const XrPosef &pose = location.pose;
	UtilityFunctions::print("PicoRoom:   pose (", (int64_t)result, ") flags ", (int64_t)location.locationFlags, " pos ",
			pose.position.x, " ", pose.position.y, " ", pose.position.z, " rot ", pose.orientation.x, " ",
			pose.orientation.y, " ", pose.orientation.z, " ", pose.orientation.w);
}

bool PicoRoomProbe::_on_event_polled(const void *p_event) {
	const XrEventDataBaseHeader *header = (const XrEventDataBaseHeader *)p_event;
	const uint32_t *words = (const uint32_t *)p_event;
	String dump;
	for (int i = 0; i < EVENT_DUMP_WORDS; i++) {
		dump += String::num_int64(words[i]) + " ";
	}
	UtilityFunctions::print("PicoRoom: event type ", (int64_t)header->type, " words ", dump);
	return false;
}
