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
static const char *MARKER_PREFIX = "user://pico_room_v11_";
// Most anchors to load: a room has a floor, a ceiling, a few walls, doors, windows and furniture boxes.
static const uint32_t MAX_ANCHORS = 64;
// Load timeout handed to the runtime (unit undocumented).
static const uint64_t LOAD_TIMEOUT = 5000;
// PxrPersistLocation.Local: anchors saved on the headset.
static const uint32_t LOCATION_LOCAL = 1;
// The loaded event's type.
static const uint32_t TYPE_EVENT_ANCHOR_ENTITY_LOADED = 1200006350;
// The spatial scene filter (type 1200006362 from the runtime's code) with every surface kind (PICO's Unity SDK flags:
// unknown, floor, ceiling, wall, door, window, opening, object).
static const uint32_t TYPE_SPATIAL_SCENE_FILTER = 1200006362;
static const uint64_t ALL_SCENE_TYPES = 0xFF;
// PICO's local map (room localization) state event; the runtime logs on_local_map_state_changed with it. The probe
// loads again whenever it arrives, since anchors only load once the headset has recognised the saved room.
static const uint32_t TYPE_EVENT_LOCAL_MAP_STATE = 1200006303;
// Frames between load retries while no anchors are found (about 5 s at 72 Hz).
static const int RETRY_EVERY_FRAMES = 72 * 5;
// PICO refused to switch to its scene capture when asked the moment the session got focus (710b57e log:
// checkAppSwitchAllowed false), and allowed it after ~70 s of focus. So wait this long after focus before asking,
// and ask again if focus hasn't gone to the capture this long after, up to CAPTURE_TRIES times.
static const int CAPTURE_DELAY_FRAMES = 72 * 3;
static const int CAPTURE_CHECK_FRAMES = 72 * 5;
static const int CAPTURE_TRIES = 6;
// Below this a returned handle is an id, not a pointer xrLocateSpace could read (anchor ids were 260 and up).
static const uint64_t MIN_POINTER = 0x10000;
// PICO's own event types start here; the probe logs them raw to learn the scene capture events.
static const uint32_t FIRST_PICO_EVENT_TYPE = 1200000000;
// 64-bit words in each scratch buffer handed to a function whose struct layout isn't known yet. Big enough that a
// runtime writing a larger struct than guessed stays inside it.
static const int SCRATCH_WORDS = 64;
// One result entry as the runtime writes it (b984b09 log): OpenXR-style header (type, next), the anchor handle at
// +0x10, then the 16-byte UUID: 40 bytes, five 64-bit words.
static const int RESULT_STRIDE_WORDS = 5;
static const int RESULT_ANCHOR_WORD = 2;
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
	create_anchor_space = resolve<CreateAnchorSpace>(api, "xrCreateAnchorSpaceBD");
	locate_space = resolve<PFN_xrLocateSpace>(api, "xrLocateSpace");
	start_scene_capture = resolve<StartSpatialSceneCapture>(api, "xrStartSpatialSceneCaptureBD");
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
	focused = true;
	if (capture_started && !capture_opened) {
		// Focus came back without the capture ever taking it.
		return;
	}
	if (capture_started) {
		// Back from PICO's scene capture: the room should be recognised now.
		load_started = true;
		_start_load();
	}
}

void PicoRoomProbe::_on_state_visible() {
	focused = false;
	if (capture_started) {
		capture_opened = true;
	}
}

void PicoRoomProbe::_on_process() {
	// Bored (2026-11-02): PICO only finds the room after its scene capture, so open it first, every time.
	if (focused && !capture_opened && capture_tries < CAPTURE_TRIES) {
		capture_frames++;
		int wait = capture_started ? CAPTURE_CHECK_FRAMES : CAPTURE_DELAY_FRAMES;
		if (capture_frames >= wait) {
			capture_frames = 0;
			capture_tries++;
			UtilityFunctions::print("PicoRoom: asking for the scene capture, try ", capture_tries);
			_start_capture();
		}
		return;
	}
	if (focused && !capture_opened && !load_started) {
		UtilityFunctions::print("PicoRoom: the scene capture never opened, loading anyway");
		load_started = true;
		_start_load();
	}
	if (!load_started || found || !focused || task_id != 0) {
		return;
	}
	frames_since_load++;
	if (frames_since_load < RETRY_EVERY_FRAMES) {
		return;
	}
	_start_load();
}

void PicoRoomProbe::_start_load() {
	if (load_anchor_entity == nullptr || get_load_results == nullptr) {
		UtilityFunctions::print("PicoRoom: load functions missing, nothing to try");
		return;
	}
	const char *stage = "load";
	frames_since_load = 0;
	if (_enter_stage(stage)) {
		return;
	}
	PicoAnchorEntityLoadFilter filter = { TYPE_SPATIAL_SCENE_FILTER, nullptr, ALL_SCENE_TYPES };
	PicoAnchorEntityLoadInfo info = { 0, nullptr, MAX_ANCHORS, LOAD_TIMEOUT, LOCATION_LOCAL, &filter };
	uint64_t task = 0;
	XrResult result = load_anchor_entity(session, &info, &task);
	_leave_stage(stage);
	UtilityFunctions::print("PicoRoom: ", stage, " result ", (int64_t)result, " task ", (int64_t)task);
	task_id = XR_SUCCEEDED(result) ? task : 0;
}

void PicoRoomProbe::_start_capture() {
	if (start_scene_capture == nullptr || _enter_stage("capture")) {
		return;
	}
	// b984b09 crashed at address 0 inside this call with (session, &task): the runtime probably takes an info
	// pointer before the task id, like the load call. A zeroed info then &task works for either signature.
	uint64_t info[SCRATCH_WORDS] = {};
	uint64_t task = 0;
	XrResult result = start_scene_capture(session, info, &task);
	_leave_stage("capture");
	capture_started = XR_SUCCEEDED(result);
	UtilityFunctions::print("PicoRoom: start scene capture result ", (int64_t)result, " task ", (int64_t)task,
			" info ", dump_words(info, 2));
}

bool PicoRoomProbe::_on_event_polled(const void *p_event) {
	const XrEventDataBaseHeader *header = (const XrEventDataBaseHeader *)p_event;
	uint32_t type = (uint32_t)header->type;
	if (type < FIRST_PICO_EVENT_TYPE) {
		return false;
	}
	if (type != TYPE_EVENT_ANCHOR_ENTITY_LOADED) {
		UtilityFunctions::print("PicoRoom: event type ", (int64_t)type, " words ", dump_words(p_event, DUMP_WORDS));
		if (type == TYPE_EVENT_LOCAL_MAP_STATE && load_started && !found && task_id == 0) {
			_start_load();
		}
		return false;
	}
	const PicoEventAnchorEntityLoaded *loaded = (const PicoEventAnchorEntityLoaded *)p_event;
	UtilityFunctions::print("PicoRoom: loaded event task ", (int64_t)loaded->task_id, " result ", loaded->result,
			" total ", (int64_t)loaded->total, " words ", dump_words(p_event, 7));
	if (task_id == 0 || loaded->task_id != task_id) {
		return false;
	}
	if (loaded->total > 0) {
		_read_results();
	}
	task_id = 0;
	return false;
}

void PicoRoomProbe::_read_results() {
	if (_enter_stage("results")) {
		return;
	}
	// The results struct as the runtime fills it: OpenXR-style header, u32 capacity at +0x10, u32 count written at
	// +0x14, entries pointer at +0x18.
	static uint64_t entries[MAX_ANCHORS * RESULT_STRIDE_WORDS];
	uint64_t buffer[SCRATCH_WORDS];
	memset(entries, 0, sizeof(entries));
	memset(buffer, 0, sizeof(buffer));
	buffer[2] = MAX_ANCHORS;
	buffer[3] = (uint64_t)entries;
	XrResult result = get_load_results(session, task_id, buffer);
	_leave_stage("results");
	uint32_t count = (uint32_t)(buffer[2] >> 32);
	found = XR_SUCCEEDED(result) && count > 0;
	UtilityFunctions::print("PicoRoom: results result ", (int64_t)result, " count ", (int64_t)count);
	if (XR_FAILED(result)) {
		return;
	}
	if (_enter_stage("anchors")) {
		return;
	}
	for (uint32_t i = 0; i < count && i < MAX_ANCHORS; i++) {
		_log_anchor(entries[i * RESULT_STRIDE_WORDS + RESULT_ANCHOR_WORD]);
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
			") ", dump_words(label, 4), " flags (", (int64_t)flags_result, ") ", dump_words(flags, 4));
	uint64_t plane[SCRATCH_WORDS] = {};
	XrResult plane_result = get_plane_boundary(session, p_anchor, plane);
	UtilityFunctions::print("PicoRoom:   plane (", (int64_t)plane_result, ") ", dump_floats(plane, 16));
	uint64_t box[SCRATCH_WORDS] = {};
	XrResult box_result = get_box(session, p_anchor, box);
	UtilityFunctions::print("PicoRoom:   box (", (int64_t)box_result, ") ", dump_floats(box, 16));
	if (create_anchor_space != nullptr) {
		// Guessed like the load call: session, an OpenXR-style info with the anchor id at +0x10, then the XrSpace out.
		uint64_t info[SCRATCH_WORDS] = {};
		info[2] = p_anchor;
		uint64_t space[SCRATCH_WORDS] = {};
		XrResult space_result = create_anchor_space(session, info, space);
		UtilityFunctions::print("PicoRoom:   space (", (int64_t)space_result, ") ", dump_words(space, 2), " info ",
				dump_words(info, 4));
		Ref<OpenXRAPIExtension> api = get_openxr_api();
		if (XR_SUCCEEDED(space_result) && space[0] > MIN_POINTER && locate_space != nullptr && api.is_valid()) {
			XrSpaceLocation location = { XR_TYPE_SPACE_LOCATION };
			XrResult result = locate_space((XrSpace)space[0], (XrSpace)api->get_play_space(),
					(XrTime)api->get_predicted_display_time(), &location);
			const XrPosef &pose = location.pose;
			UtilityFunctions::print("PicoRoom:   pose (", (int64_t)result, ") flags ", (int64_t)location.locationFlags,
					" pos ", pose.position.x, " ", pose.position.y, " ", pose.position.z, " rot ", pose.orientation.x,
					" ", pose.orientation.y, " ", pose.orientation.z, " ", pose.orientation.w);
		}
	}
}
