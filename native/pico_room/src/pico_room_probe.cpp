#include "pico_room_probe.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/open_xrapi_extension.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>

using namespace godot;

// A stage's marker is written before its private calls and removed when they return: if it is still there at the next
// launch, that stage crashed the game, so the probe skips it (and everything after it) instead of crashing on every
// launch. Bump the version with each probe build so a new build tries again.
static const char *MARKER_PREFIX = "user://pico_room_v4_";
// Most anchors to load: a room has a floor, a ceiling, a few walls, doors, windows and furniture boxes.
static const uint32_t MAX_ANCHORS = 64;
// Load timeout handed to the runtime (unit undocumented).
static const uint64_t LOAD_TIMEOUT = 5000;
// PxrPersistLocation.Local: anchors saved on the headset.
static const uint32_t LOCATION_LOCAL = 1;
// 64-bit words in each scratch buffer handed to a function whose struct layout isn't known yet. Big enough that a
// runtime writing a larger struct than guessed stays inside it.
static const int SCRATCH_WORDS = 64;
// Bytes reserved per result entry (the guessed entry is 24 bytes: anchor handle + 16-byte UUID).
static const int RESULT_STRIDE_WORDS = 8;
// 64-bit words of each buffer and event to log raw.
static const int DUMP_WORDS = 12;

/// Resolves one runtime function by name and logs whether the runtime has it.
template <typename T>
static T resolve(const Ref<OpenXRAPIExtension> &p_api, const char *p_name) {
	T function = (T)p_api->get_instance_proc_addr(p_name);
	UtilityFunctions::print("PicoRoom: fn ", p_name, function != nullptr ? " found" : " MISSING");
	return function;
}

/// Returns the first words of a buffer as hex, for the log.
static String dump_words(const void *p_data, int p_words) {
	const uint64_t *words = (const uint64_t *)p_data;
	String text;
	for (int i = 0; i < p_words; i++) {
		text += String::num_uint64(words[i], 16) + " ";
	}
	return text;
}

/// Returns the first floats of a buffer, for the log.
static String dump_floats(const void *p_data, int p_floats) {
	const float *floats = (const float *)p_data;
	String text;
	for (int i = 0; i < p_floats; i++) {
		text += String::num(floats[i], 3) + " ";
	}
	return text;
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
	UtilityFunctions::print("PicoRoom: enabled anchor_entity ", anchor_entity, " anchor_entity_persistence ",
			anchor_entity_persistence, " room_scene ", room_scene, " spatial_scene ", spatial_scene, " mr_management ",
			mr_management);
	Ref<OpenXRAPIExtension> api = get_openxr_api();
	if (api.is_null()) {
		UtilityFunctions::push_error("PicoRoom: no OpenXR API");
		return;
	}
	load_anchor_entity = resolve<LoadAnchorEntity>(api, "xrLoadAnchorEntityBD");
	get_load_results = resolve<GetAnchorEntityLoadResults>(api, "xrGetAnchorEntityLoadResultsBD");
	get_scene_label = resolve<GetAnchorValue>(api, "xrGetAnchorSceneLabelBD");
	get_component_flags = resolve<GetAnchorValue>(api, "xrGetAnchorComponentFlagsBD");
	get_plane_boundary = resolve<GetAnchorValue>(api, "xrGetAnchorPlaneBoundaryInfoBD");
	get_box = resolve<GetAnchorValue>(api, "xrGetAnchorBoxInfoBD");
	locate_space = resolve<PFN_xrLocateSpace>(api, "xrLocateSpace");
}

void PicoRoomProbe::_on_session_created(uint64_t p_session) {
	session = (XrSession)p_session;
}

bool PicoRoomProbe::_enter_stage(const char *p_stage) {
	String marker = String(MARKER_PREFIX) + p_stage;
	if (FileAccess::file_exists(marker)) {
		UtilityFunctions::print("PicoRoom: skipped stage ", p_stage, ", it crashed the game last launch");
		return true;
	}
	FileAccess::open(marker, FileAccess::WRITE).unref();
	UtilityFunctions::print("PicoRoom: stage ", p_stage);
	return false;
}

void PicoRoomProbe::_leave_stage(const char *p_stage) {
	DirAccess::remove_absolute(String(MARKER_PREFIX) + p_stage);
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
		return;
	}
	if (_enter_stage("load")) {
		return;
	}
	PicoAnchorEntityLoadInfo info = { 0, nullptr, MAX_ANCHORS, LOAD_TIMEOUT, LOCATION_LOCAL, nullptr };
	uint64_t task = 0;
	XrResult result = load_anchor_entity(session, &info, &task);
	_leave_stage("load");
	UtilityFunctions::print("PicoRoom: load result ", (int64_t)result, " task ", (int64_t)task);
	if (XR_SUCCEEDED(result)) {
		task_id = task;
	}
}

bool PicoRoomProbe::_on_event_polled(const void *p_event) {
	const XrEventDataBaseHeader *header = (const XrEventDataBaseHeader *)p_event;
	UtilityFunctions::print("PicoRoom: event type ", (int64_t)header->type, " words ", dump_words(p_event, DUMP_WORDS));
	if (task_id == 0 || results_read) {
		return false;
	}
	// The loaded event's layout isn't known: look for the task id in its first words.
	const uint64_t *words = (const uint64_t *)p_event;
	for (int i = 1; i < DUMP_WORDS; i++) {
		if (words[i] == task_id) {
			UtilityFunctions::print("PicoRoom: event carries the load task id at word ", i);
			results_read = true;
			_read_results();
			break;
		}
	}
	return false;
}

void PicoRoomProbe::_read_results() {
	if (_enter_stage("results")) {
		return;
	}
	// The results struct's layout isn't known. Fill the buffer so both likely layouts read a capacity of MAX_ANCHORS
	// and a valid array: PICO's Unity layout {u32 capacity, u32 count, entries*} at offset 0, and an OpenXR-style
	// {type, next, u32 capacity, u32 count, entries*} with the capacity at 0x10 and the pointer at 0x18.
	static uint64_t entries[MAX_ANCHORS * RESULT_STRIDE_WORDS];
	uint64_t buffer[SCRATCH_WORDS];
	memset(entries, 0, sizeof(entries));
	memset(buffer, 0, sizeof(buffer));
	buffer[0] = MAX_ANCHORS;
	buffer[1] = (uint64_t)entries;
	buffer[2] = MAX_ANCHORS;
	buffer[3] = (uint64_t)entries;
	XrResult result = get_load_results(session, task_id, buffer);
	_leave_stage("results");
	UtilityFunctions::print("PicoRoom: results result ", (int64_t)result, " buffer ", dump_words(buffer, 6));
	UtilityFunctions::print("PicoRoom: entries ", dump_words(entries, 24));
	if (XR_FAILED(result)) {
		return;
	}
	if (_enter_stage("anchors")) {
		return;
	}
	// The guessed entry: a 64-bit anchor handle, then a 16-byte UUID (24 bytes, three words).
	for (uint32_t i = 0; i < MAX_ANCHORS && entries[i * 3] != 0; i++) {
		_log_anchor(entries[i * 3]);
	}
	_leave_stage("anchors");
	UtilityFunctions::print("PicoRoom: done");
}

void PicoRoomProbe::_log_anchor(uint64_t p_anchor) {
	uint64_t label[SCRATCH_WORDS] = {};
	XrResult label_result = get_scene_label(session, p_anchor, label);
	uint64_t flags[SCRATCH_WORDS] = {};
	XrResult flags_result = get_component_flags(session, p_anchor, flags);
	UtilityFunctions::print("PicoRoom: anchor ", String::num_uint64(p_anchor, 16), " label (", (int64_t)label_result,
			") ", dump_words(label, 2), " flags (", (int64_t)flags_result, ") ", dump_words(flags, 2));
	uint64_t plane[SCRATCH_WORDS] = {};
	XrResult plane_result = get_plane_boundary(session, p_anchor, plane);
	UtilityFunctions::print("PicoRoom:   plane (", (int64_t)plane_result, ") ", dump_floats(plane, 12));
	uint64_t box[SCRATCH_WORDS] = {};
	XrResult box_result = get_box(session, p_anchor, box);
	UtilityFunctions::print("PicoRoom:   box (", (int64_t)box_result, ") ", dump_floats(box, 12));
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
